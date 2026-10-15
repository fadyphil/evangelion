/// WCAG 2.1 relative-luminance contrast for every token, on every surface it can
/// actually sit on, in both themes.
///
/// ## WHY THIS IS ARITHMETIC AND NOT A RENDERED SCAN
///
/// Contrast depends on the colour **composited against the surface beneath it**, so
/// the honest question is "how legible is this run of text here". This measures the
/// tokens instead, which is a weaker claim in one way and a stronger one in another:
///
/// * weaker — it cannot see a run rendered on an unexpected backdrop;
/// * stronger — it covers **every surface in both themes**, including ones no screen
///   currently reaches, and it costs microseconds, so it runs on every commit rather
///   than on the surfaces someone remembered to render.
///
/// A rendered scan would also have to guess the backdrop, and guessing it is how a
/// contrast gate ends up confidently measuring the wrong thing.
///
/// ## AND THE 4.5:1 FLOOR IS CHECKED AGAINST **EVERY** SURFACE, NOT THE NOMINAL ONE
///
/// The first version of the idea checked each token against its own theme's `canvas`
/// and reported `ink2` at 6.26:1 — which reads like a pass. `GlassSurface` composites
/// `#0DFFFFFF` over whatever is beneath, so a run on a card is on a **lighter** surface
/// than the canvas, and the real number is 4.73:1. A token that passes on `canvas` and
/// fails on glass is the common case, because glass always moves a dark theme lighter.
/// Requiring 4.5:1 against the worst surface is what makes the gate meaningful.
///
/// ## THE KNOWN-SUBSTANDARD LIST IS A LEDGER, NOT AN EXCUSE
///
/// [knownSubstandard] records every token/surface pair that does **not** reach the
/// floor, with its measured ratio. Two assertions keep it honest:
///
/// 1. the list **must not grow** — a new failing pair fails the gate;
/// 2. a listed pair's measured ratio **must not change** — so silently darkening
///    `ember` to "fix" it, or nudging a token until the number moves, fails too.
///
/// That means the debt is countable and inert: it cannot grow, it cannot drift, and it
/// cannot be paid down without someone editing this file on purpose. A gate with an
/// unbounded allowlist is a gate with no allowlist.
library;

import 'dart:math' as math;

import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// One measured contrast, in the units WCAG 2.1 defines.
typedef Contrast = ({String token, String surface, double ratio});

/// Relative luminance, WCAG 2.1 §"relative luminance".
///
/// The piecewise transfer function, not `pow((c+0.055)/1.055, 2.4)` applied
/// unconditionally: the linear segment below 0.04045 is part of the definition, and a
/// build that skipped it mismeasures near-black. On this palette `onEmber` is
/// `#0D0A04`, which lands **inside** that segment — so the shortcut is not academic.
double _luminance(int argb) {
  double channel(double raw) {
    final double c = raw / 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final double r = channel(((argb >> 16) & 0xFF).toDouble());
  final double g = channel(((argb >> 8) & 0xFF).toDouble());
  final double b = channel((argb & 0xFF).toDouble());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Contrast ratio, WCAG 2.1 §"contrast ratio". Order-independent by construction.
double contrastRatio(int a, int b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites [source] at [alpha] over [backdrop] — the channel arithmetic
/// `BlendMode.srcOver` performs, in 8-bit space.
///
/// **8-bit, not float.** Flutter's `Color` stores 8-bit channels and the compositor
/// rounds, so measuring in float would report a ratio the screen never renders. The
/// rounding here is the same rounding.
int composite(int source, int backdrop, double alpha) {
  int mix(int shift) {
    final double s = ((source >> shift) & 0xFF) * alpha;
    final double d = ((backdrop >> shift) & 0xFF) * (1 - alpha);
    return (s + d).round().clamp(0, 255);
  }

  return (0xFF << 24) | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// The alpha channel of [argb], as a 0–1 fraction.
double alphaOf(int argb) => ((argb >> 24) & 0xFF) / 255;

/// Every surface a text run can land on, per theme, as a name → colour pair.
///
/// `glass/*` is **that theme's own** `glassFill` composited over the named surface,
/// which is what `GlassSurface` actually paints.
///
/// ## WHY THE ALPHA IS READ AND NOT ASSUMED
///
/// The first version hardcoded `0x0D / 255` — which is the **dark** theme's fill, a
/// 5% white overlay. Light's is `0x0A000000`, a 4% **black** overlay, and the
/// difference is not cosmetic: compositing black at 4% *darkens* `#E8E4FF` to
/// `#DCD8F2`, while compositing white at 5% would have *lightened* it. Using the dark
/// alpha for the light theme produced surfaces that were lighter than any the light
/// theme can render, which made `glass/raised` measure **4.69:1** for a token that the
/// real surface measures **4.18:1** — the gate cleared a value the screen never showed.
///
/// So the two themes disagree about the **direction** glass moves a surface, not just
/// the amount. Reading the alpha off the colour is the only way to get both right, and
/// hardcoding it was the same class of mistake as typing the ledger from a spreadsheet.
Map<String, int> surfacesOf(EvaColors colors) {
  final int fill = colors.glassFill.toARGB32();
  final double alpha = alphaOf(fill);
  return <String, int>{
    'canvas': colors.canvas.toARGB32(),
    'surface': colors.surface.toARGB32(),
    'raised': colors.raised.toARGB32(),
    'glass/canvas': composite(fill, colors.canvas.toARGB32(), alpha),
    'glass/raised': composite(fill, colors.raised.toARGB32(), alpha),
  };
}

/// Every token the gate measures, and the role each is expected to serve.
Map<String, int> textTokensOf(EvaColors colors) => <String, int>{
  'ink': colors.ink.toARGB32(),
  'ink2': colors.ink2.toARGB32(),
  'ink3': colors.ink3.toARGB32(),
  'ember': colors.ember.toARGB32(),
  'ok': colors.ok.toARGB32(),
  'err': colors.err.toARGB32(),
  'emberInk': colors.emberInk.toARGB32(),
  'okInk': colors.okInk.toARGB32(),
  'errInk': colors.errInk.toARGB32(),
};

/// WCAG 2.1 AA for body text.
const double bodyFloor = 4.5;

/// Tokens approved as **text** colours, and therefore required to clear [bodyFloor]
/// against every surface in both themes.
///
/// `ink3` is deliberately absent, and that absence is decision 149: its role is now
/// hairlines, dividers, decorative dots and **inactive** controls — the cases WCAG
/// exempts — and the 21 text and icon runs that used it were promoted to `ink2`.
///
/// `ember`, `ok` and `err` are absent too, and that is **not** an endorsement: `ember`
/// fails in the light theme and is the subject of an open decision. They are in
/// [knownSubstandard] instead, which is the honest place for a token that is used as
/// text and does not yet qualify.
const Set<String> approvedForText = <String>{
  'ink',
  'ink2',
  'emberInk',
  'okInk',
  'errInk',
};

/// Every measured pair below [bodyFloor], with the ratio that was measured.
///
/// Values are the **worst** surface for that token in that theme, so one entry per
/// token per theme rather than one per surface.
const List<Contrast> knownSubstandard = <Contrast>[
  // **Every value below was read out of this gate, and the light column changed twice
  // before it was right.** The first list was computed by hand against `canvas` and
  // `glass/canvas`; the gate disagreed with all of it. The second used the dark theme's
  // glass alpha for the light theme, which made light glass *lighter* than any surface
  // the light theme can render.
  //
  // Both mistakes pointed the same way — a hand-computed surface that reads brighter
  // than the real one, so the gate cleared tokens the screen never shows. The light
  // numbers moved `2.02 → 2.08`, `2.05 → 2.11`, `3.03 → 3.12`, `3.33 → 3.43` when the
  // alpha bug was fixed, and the drift assertion caught every one of them, which is
  // precisely what it is for: a stale ledger is worse than none.
  //
  // `ember`, `ok` and `err` remain here because they are still **fills** — an
  // `EvaButton` label is `onEmber` on `ember`, and a fill is not held to the text floor.
  // Their ink counterparts (`emberInk`, `okInk`, `errInk`) are in `approvedForText` and
  // clear 4.5:1 on every surface in both themes.
  //
  // `ember` in light is the one that mattered: **2.11:1** for the fill token that used
  // to paint the reader's own name in the greeting on `/`.
  (token: 'ink3', surface: 'dark glass/raised', ratio: 1.65),
  (token: 'ink3', surface: 'light glass/raised', ratio: 2.08),
  (token: 'ember', surface: 'light glass/raised', ratio: 2.11),
  (token: 'ok', surface: 'light glass/raised', ratio: 3.12),
  (token: 'err', surface: 'light glass/raised', ratio: 3.43),
];

/// The measured worst ratio for [token] across every surface in [colors].
Contrast worstOf(String theme, String token, EvaColors colors) {
  final Map<String, int> surfaces = surfacesOf(colors);
  String worstSurface = '';
  double worst = double.infinity;
  surfaces.forEach((String name, int value) {
    final double ratio = contrastRatio(textTokensOf(colors)[token]!, value);
    if (ratio < worst) {
      worst = ratio;
      worstSurface = name;
    }
  });
  return (token: token, surface: '$theme $worstSurface', ratio: worst);
}

void main() {
  final Map<String, EvaColors> themes = <String, EvaColors>{
    'dark': const EvaColors.dark(),
    'light': const EvaColors.light(),
  };

  group('the approved text tokens clear the body floor everywhere', () {
    for (final MapEntry<String, EvaColors> entry in themes.entries) {
      for (final String token in approvedForText) {
        test('${entry.key}/$token', () {
          final Contrast worst = worstOf(entry.key, token, entry.value);
          expect(
            worst.ratio,
            greaterThanOrEqualTo(bodyFloor),
            reason:
                '${entry.key}/$token measures ${worst.ratio.toStringAsFixed(2)}:1 on '
                '${worst.surface}, under the $bodyFloor:1 body-text floor. The gate '
                'checks the WORST surface, not the nominal one, because glass always '
                'moves a dark theme lighter — a token that passes on `canvas` and fails '
                'on glass is the common failure and the reason this test exists.',
          );
        });
      }
    }
  });

  group('the known-substandard ledger', () {
    test('is not empty, and is not a way to pass everything', () {
      // A ledger that listed nothing would mean every token had been fixed, which is
      // false; a ledger that listed everything would mean the gate asserts nothing.
      // Asserting it is *neither* empty nor complete is what keeps it a ledger.
      expect(knownSubstandard, isNotEmpty);
      final int total = themes.entries
          .expand((MapEntry<String, EvaColors> e) => textTokensOf(e.value).keys)
          .length;
      expect(
        knownSubstandard.length,
        lessThan(total),
        reason: 'if every token is listed, the gate is decorative',
      );
    });

    test('has not grown', () {
      // **The assertion that does the work.** Every pair below the floor must be
      // written down here, so introducing a new illegible combination fails this test
      // rather than passing quietly.
      final List<Contrast> actual = <Contrast>[];
      for (final MapEntry<String, EvaColors> entry in themes.entries) {
        for (final String token in textTokensOf(entry.value).keys) {
          if (approvedForText.contains(token)) continue;
          final Contrast worst = worstOf(entry.key, token, entry.value);
          if (worst.ratio < bodyFloor) actual.add(worst);
        }
      }

      expect(
        actual.map((Contrast c) => '${c.token}@${c.surface}').toList()..sort(),
        knownSubstandard.map((Contrast c) => '${c.token}@${c.surface}').toList()
          ..sort(),
        reason:
            'The set of token/surface pairs below $bodyFloor:1 has changed.\n'
            'A NEW entry means a new illegible combination — add it deliberately, or '
            'fix the token.\n'
            'A MISSING entry means one was fixed: delete it here in the same commit, '
            'and if it was `ink3`, `ember`, `ok` or `err`, consider promoting it into '
            '`approvedForText`.\n'
            'Measured now:\n${_describe(actual)}',
      );
    });

    test('and no recorded ratio has drifted', () {
      // Catches the quiet version: someone darkens `ember` a little to "improve" it
      // and the ledger keeps claiming the old number. The measured value must equal
      // the recorded one.
      for (final Contrast recorded in knownSubstandard) {
        final List<String> parts = recorded.surface.split(' ');
        final EvaColors colors = themes[parts.first]!;
        final Contrast actual = worstOf(parts.first, recorded.token, colors);
        expect(
          actual.ratio,
          closeTo(recorded.ratio, 0.005),
          reason:
              '${recorded.token} on ${recorded.surface} now measures '
              '${actual.ratio.toStringAsFixed(2)}:1 but the ledger records '
              '${recorded.ratio.toStringAsFixed(2)}:1. If the token changed, update '
              'this file on purpose — a stale ledger is worse than none.',
        );
      }
    });
  });

  group('the measurement itself', () {
    test('is not vacuous — known pairs measure what WCAG says they should', () {
      // Three anchors from the specification, so a bug in `_luminance` cannot make
      // every other assertion in this file pass for the wrong reason.
      expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21.0, 0.01));
      expect(contrastRatio(0xFFFFFFFF, 0xFFFFFFFF), closeTo(1.0, 0.01));
      // #767676 on white is the canonical "smallest passing grey" at 4.54:1.
      expect(contrastRatio(0xFF767676, 0xFFFFFFFF), closeTo(4.54, 0.02));
    });

    test('is symmetric', () {
      const EvaColors dark = EvaColors.dark();
      final int a = dark.ink.toARGB32();
      final int b = dark.raised.toARGB32();
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-9));
    });

    test('composites the way the compositor does', () {
      // White at 5% over black lands at 13/255 — 12.75 rounded **up** — and this
      // pins that rounding, because measuring in float would report 12.75 and disagree
      // with every pixel on screen.
      //
      // The literal is `0.05` and not `0x05`, which was the bug in the first version:
      // `0x05` is the **integer five**, so alpha came out as 5.0, every channel
      // clamped to 255, and the function returned opaque white — a test that passed a
      // nonsense alpha through a helper that never complained. A hexadecimal-looking
      // fraction is the kind of thing that reads as `0.05` to the author and `5` to
      // the compiler.
      expect(composite(0xFFFFFFFF, 0xFF000000, 0.05), 0xFF0D0D0D);
    });
  });
}

String _describe(List<Contrast> entries) => entries
    .map(
      (Contrast c) =>
          '  ${c.token} on ${c.surface}: '
          '${c.ratio.toStringAsFixed(2)}:1',
    )
    .join('\n');
