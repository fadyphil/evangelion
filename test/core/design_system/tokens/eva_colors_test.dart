import 'dart:io';
import 'dart:math' as math;

import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/sticker_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an expected `#RRGGBB` as a packed ARGB int.
///
/// WHY. Dart canonicalises const expressions, so `expect(dark.canvas,
/// const Color(0xFF05081A))` hands the matcher the very object the
/// implementation declared whenever the implementation also writes that
/// literal — the two references are identical and the assertion holds even if
/// the getter is wired to the wrong field. Comparing packed integers built
/// here keeps the expected value out of the constant pool entirely, so the
/// assertion can only pass if the number the getter produces is right.
int _argb(int r, int g, int b, [int a = 0xFF]) =>
    (a << 24) | (r << 16) | (g << 8) | b;

/// The ARGB the packed channels of [c] decode to, so every colour assertion in
/// this file reads as a number rather than as an object identity.
int _hex(Color c) => c.toARGB32();

// ---------------------------------------------------------------------------
// WCAG 2.x contrast — computed, never transcribed.
//
// The numbers in the doc comments are a record of a measurement. These functions
// ARE the measurement, and the assertions below are the guarantee: a palette edit
// that breaks a pairing fails here rather than shipping a contrast bug that only
// a manual audit would catch. Ratios are deliberately NOT hardcoded — a test that
// asserted "5.41" would go red on a palette change and would be re-captured to
// make it green, which is how the bug this replaces got in the first place.
// ---------------------------------------------------------------------------

/// The sRGB electro-optical transfer function, per WCAG 2.x §Relative luminance.
///
/// The 0.03928 threshold and the 12.92 divisor are the standard's own; the
/// threshold is `0.04045` in the older text but WCAG rounds it down to keep the
/// two descriptions of the segment continuous, and no token in this palette is
/// anywhere near it.
double _linearise(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// The WCAG relative luminance of an opaque colour, 0.0 (black) to 1.0 (white).
double _relativeLuminance(Color c) {
  assert(
    c.a == 1.0,
    'luminance is only defined for opaque colours; '
    '${_hex(c).toRadixString(16)} has alpha ${c.a}',
  );
  return 0.2126 * _linearise(c.r) +
      0.7152 * _linearise(c.g) +
      0.0722 * _linearise(c.b);
}

/// The WCAG contrast ratio between two opaque colours, from 1.0 to 21.0.
double _contrastRatio(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG 2.x AA for body text. 4.5:1.
const double _wcagAA = 4.5;

/// WCAG 2.x AA for large text (>=18pt, or >=14pt bold) and for UI components.
/// 3:1.
const double _wcagAALarge = 3.0;

/// A foreground/background pairing that the design system relies on.
typedef _Pairing = ({String name, String where, Color on, Color against});

/// `#rrggbb`, for a failure message. `toARGB32()` is the house discipline — the
/// deprecated `value` is forbidden by AGENT_CONTEXT §4 — so the hex is built
/// here rather than read off a getter that no longer exists.
String _css(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// A pairing the theme wires, that does **not** clear WCAG AA, with the measured
/// ratio it was left at.
///
/// [floor] is the honest number as of this review, asserted from both sides: a
/// drop below it is an unrecorded regression, and a rise above AA means the entry
/// is stale. See the group doc for why these are listed rather than fixed.
typedef _KnownGap = ({
  String name,
  String why,
  Color on,
  Color against,
  double floor,
  bool largeTextOnly,
});

/// The sub-AA pairings this phase inherited, read off the palette itself.
///
/// MEASURED, not estimated. Dark has none among the pairings the theme wires:
/// every dark body-text combination clears 5.4:1. Light has seven, and the
/// pattern is legible — the light palette's chromatic tokens (`ok`, `err`,
/// `ember`) were authored against the dark canvas and are dark-ish pastels that
/// lose contrast when they move to a near-white one.
///
/// Read off [palette] rather than written as hexes, so an entry cannot go stale
/// behind a token edit: the [floor] is the recorded measurement and the pair is
/// the live one, and it is their disagreement that fails.
///
/// THE ONE THAT IS NOT JUST "LARGE TEXT ONLY". `emberDeep/onEmber` (3.75:1) and
/// the four `ok`/`err`-on-light-surface pairings clear AA-large (3:1), so they
/// are recorded as large-text-only and may be used at >=18pt, >=14pt bold, or as
/// a non-text indicator alongside a label. `ember/raised` (2.30:1) — the snack-bar
/// ACTION colour, wired at `eva_theme.dart` as `actionTextColor: colors.ember`
/// over `backgroundColor: colors.raised` — does NOT clear even 3:1 in light, so
/// it cannot be called large-text-only at all. It is flagged
/// `largeTextOnly: false` to keep that distinction from being lost in a list of
/// numbers. Phase 3 owns the snack bar and must give its action a readable
/// colour; this phase may not change a token to do it.
List<_KnownGap> _knownGapsFor(EvaColors palette) =>
    palette.canvas == const EvaColors.dark().canvas
    ? const <_KnownGap>[]
    : <_KnownGap>[
        (
          name: 'canvas/ok',
          why: 'the success semantic on the light canvas',
          on: palette.ok,
          against: palette.canvas,
          floor: 3.67,
          largeTextOnly: true,
        ),
        (
          name: 'surface/ok',
          why: 'a correct answer inside a card',
          on: palette.ok,
          against: palette.surface,
          floor: 4.19,
          largeTextOnly: true,
        ),
        (
          name: 'raised/ok',
          why: 'a correct answer on glass',
          on: palette.ok,
          against: palette.raised,
          floor: 3.39,
          largeTextOnly: true,
        ),
        (
          name: 'canvas/err',
          why: 'an error message on the light canvas',
          on: palette.err,
          against: palette.canvas,
          floor: 4.04,
          largeTextOnly: true,
        ),
        (
          name: 'raised/err',
          why: 'an error message on glass',
          on: palette.err,
          against: palette.raised,
          floor: 3.73,
          largeTextOnly: true,
        ),
        (
          name: 'emberDeep/onEmber',
          why: 'ColorScheme.onPrimaryContainer — the pressed-fill pairing',
          on: palette.onEmber,
          against: palette.emberDeep,
          floor: 3.74,
          largeTextOnly: true,
        ),
        (
          name: 'raised/ember',
          why:
              'the snack-bar ACTION colour — below 3:1, so NOT large-text-only',
          on: palette.ember,
          against: palette.raised,
          floor: 2.29,
          largeTextOnly: false,
        ),
      ];

/// Every value [EvaColors] carries, by name.
///
/// Used as the unit of comparison for the `copyWith` and `lerp` claims: "no
/// other field changed" and "every field moved to `other`" are both statements
/// about the *whole* set, and spelling them out field by field in the
/// assertions is what makes a forgotten field in `lerp` a test failure instead
/// of a silently frozen token during a theme transition.
Map<String, Object> _snapshot(EvaColors c) => <String, Object>{
  'canvas': c.canvas.toARGB32(),
  'surface': c.surface.toARGB32(),
  'raised': c.raised.toARGB32(),
  'ink': c.ink.toARGB32(),
  'ink2': c.ink2.toARGB32(),
  'ink3': c.ink3.toARGB32(),
  'line': c.line.toARGB32(),
  'ember': c.ember.toARGB32(),
  'emberDeep': c.emberDeep.toARGB32(),
  'onEmber': c.onEmber.toARGB32(),
  'ok': c.ok.toARGB32(),
  'err': c.err.toARGB32(),
  'orbOpacity': c.orbOpacity,
  'auroraOpacity': c.auroraOpacity,
  'glassFill': c.glassFill.toARGB32(),
  'glassBorder': c.glassBorder.toARGB32(),
  'glassShadow': c.glassShadow.toARGB32(),
  // Decision 153's three accent inks. They were **absent from this snapshot**
  // while being present on the class, which is why `every token is reachable
  // through copyWith` could not see them: the probe table below is checked
  // against `snapshotKeys`, so a token missing from the snapshot is a token the
  // walk silently does not cover. Found while adding the three `bloom` tokens.
  'emberInk': c.emberInk.toARGB32(),
  'okInk': c.okInk.toARGB32(),
  'errInk': c.errInk.toARGB32(),
  // Phase 4 — `GlassTier.bloom`'s palette, transcribed from `redesign.html`.
  'seam': c.seam.toARGB32(),
  'seamGlow': c.seamGlow.toARGB32(),
  'bloom': c.bloom.toARGB32(),
  // …and the light-mode dimmer `redesign.html:73` declares as `opacity:.55`.
  // It is in the snapshot for the same reason the three accent inks above had to
  // be: `t = 1 reproduces the other palette exactly` is a whole-map comparison,
  // so a token missing here is a token that comparison silently cannot see.
  'bloomOpacity': c.bloomOpacity,
  for (final StickerSlot slot in StickerSlot.values)
    'sticker.${slot.name}': c.sticker[slot]!.toARGB32(),
};

/// The 31 names [_snapshot] produces — twenty-four tokens plus the seven sticker
/// slots. If the snapshot and this list ever drift, a `copyWith` "nothing else
/// changed" assertion would silently start comparing fewer fields than it claims
/// to. The count is asserted where it matters; this list is the readable
/// inventory, and it said "18" for a long while.
const List<String> snapshotKeys = <String>[
  'canvas',
  'surface',
  'raised',
  'ink',
  'ink2',
  'ink3',
  'line',
  'ember',
  'emberDeep',
  'onEmber',
  'ok',
  'err',
  'orbOpacity',
  'auroraOpacity',
  'glassFill',
  'glassBorder',
  'glassShadow',
  'emberInk',
  'okInk',
  'errInk',
  'seam',
  'seamGlow',
  'bloom',
  'bloomOpacity',
  'sticker.sky',
  'sticker.lavender',
  'sticker.pink',
  'sticker.coral',
  'sticker.teal',
  'sticker.leaf',
  'sticker.sun',
];

/// The names of every key whose value differs between two snapshots, in the
/// snapshot's own key order. The unit of every "nothing else changed" claim.
List<String> _changedKeys(
  Map<String, Object> before,
  Map<String, Object> after,
) => <String>[
  for (final String key in before.keys)
    if (before[key] != after[key]) key,
];

void main() {
  // =========================================================================
  // BYTE-PIN INVENTORY, RECORDED SO THE NEXT READER DOES NOT RECOUNT WRONG.
  //
  // The two spec tests below pin 42 colours as packed hexes — 18 per palette
  // (canvas, surface, raised, ink, ink2, ink3, line, ember, emberDeep, onEmber,
  // ok, err, glassFill, glassBorder, glassShadow, seam, seamGlow, bloom) plus
  // the 6 Decision-153 ink pins (emberInk, okInk, errInk × dark/light). The 6
  // opacity expects (orb/aurora/bloom × dark/light) bring the two tests to 48
  // expect() calls. The plan's "34 hexes" counted total expect() calls (17 × 2:
  // 15 colours + 2 opacities) and mislabelled them hexes; its "23 single-line +
  // 9 split-line" breakdown reads 23 only because a repo-wide `expect(_hex`
  // grep also catches the lerp interior test's 2.
  group('the dark palette', () {
    test('carries every dark token value from the spec', () {
      final EvaColors dark = const EvaColors.dark();

      expect(_hex(dark.canvas), _argb(0x05, 0x08, 0x1A), reason: 'canvas');
      expect(_hex(dark.surface), _argb(0x0D, 0x12, 0x24), reason: 'surface');
      expect(_hex(dark.raised), _argb(0x14, 0x1A, 0x2E), reason: 'raised');
      expect(_hex(dark.ink), _argb(0xEA, 0xE8, 0xF5), reason: 'ink');
      expect(_hex(dark.ink2), _argb(0x8A, 0x8F, 0xAD), reason: 'ink2');
      expect(_hex(dark.ink3), _argb(0x42, 0x46, 0x69), reason: 'ink3');
      expect(_hex(dark.line), _argb(0x1C, 0x22, 0x38), reason: 'line');
      expect(_hex(dark.ember), _argb(0xE8, 0xA3, 0x3D), reason: 'ember');
      expect(
        _hex(dark.emberDeep),
        _argb(0xC7, 0x7F, 0x1F),
        reason: 'emberDeep',
      );
      expect(_hex(dark.onEmber), _argb(0x0D, 0x0A, 0x04), reason: 'onEmber');
      expect(_hex(dark.ok), _argb(0x4E, 0xCC, 0xA3), reason: 'ok');
      expect(_hex(dark.err), _argb(0xFF, 0x6B, 0x6B), reason: 'err');
      // Decision 153 — in dark the accent inks ARE the accents, pinned here so
      // a future ink edit fails in the spec test, not just in the contrast gate.
      expect(
        _hex(dark.emberInk),
        _argb(0xE8, 0xA3, 0x3D),
        reason: 'emberInk — #E8A33D, the accent itself in dark',
      );
      expect(
        _hex(dark.okInk),
        _argb(0x4E, 0xCC, 0xA3),
        reason: 'okInk — #4ECCA3, the accent itself in dark',
      );
      expect(
        _hex(dark.errInk),
        _argb(0xFF, 0x6B, 0x6B),
        reason: 'errInk — #FF6B6B, the accent itself in dark',
      );

      expect(dark.orbOpacity, 0.55, reason: 'orbOpacity');
      expect(dark.auroraOpacity, 0.18, reason: 'auroraOpacity');
      // `redesign.html:73` dims the wash in **light only**, so dark is 1.0 — an
      // absence of a rule, asserted rather than defaulted.
      expect(
        dark.bloomOpacity,
        1.0,
        reason:
            'bloomOpacity — dark is undimmed; the .55 is light\'s, '
            'redesign.html:73',
      );

      expect(
        _hex(dark.glassFill),
        _argb(0xFF, 0xFF, 0xFF, 0x0D),
        reason: 'glassFill — rgba(255,255,255,0.05)',
      );
      expect(
        _hex(dark.glassBorder),
        _argb(0xFF, 0xFF, 0xFF, 0x14),
        reason: 'glassBorder — rgba(255,255,255,0.08)',
      );
      expect(
        _hex(dark.glassShadow),
        _argb(0x00, 0x00, 0x00, 0x59),
        reason: 'glassShadow — rgba(0,0,0,0.35)',
      );

      // Phase 4 — the `.hor` seam and the `.bloom` wash, from `redesign.html`.
      // These are **not** `03-design-system.md` §5.1 values: §5.1 publishes
      // fourteen tokens per brightness and names no seam and no wash. They are
      // transcribed from the redesign reference, which is the design source of
      // truth for the surfaces they paint, and each pin carries the line it came
      // from so a wrong citation is a wrong number.
      expect(
        _hex(dark.seam),
        _argb(0xFF, 0xFF, 0xFF, 0xD9),
        reason: 'seam — rgba(255,255,255,.85), redesign.html:257',
      );
      expect(
        _hex(dark.seamGlow),
        _argb(0xFF, 0xFF, 0xFF, 0x99),
        reason: 'seamGlow — rgba(255,255,255,.6), redesign.html:257',
      );
      expect(
        _hex(dark.bloom),
        _argb(0xE4, 0x57, 0xD6, 0x8C),
        reason: 'bloom — rgba(228,87,214,.55), redesign.html:254',
      );
    });

    test('wires the two opacity tokens that were dead in the prototype', () {
      // §5.1 marks `orbOpacity` and `auroraOpacity` "(was dead — wire it)". The
      // only thing this phase can prove is that they are non-default and
      // actually differ per brightness; whether the Phase 2 painter reads them
      // is that phase's assertion.
      expect(
        const EvaColors.dark().orbOpacity,
        isNot(const EvaColors.dark().auroraOpacity),
      );
      expect(
        const EvaColors.dark().orbOpacity,
        isNot(const EvaColors.light().orbOpacity),
      );
      expect(
        const EvaColors.dark().auroraOpacity,
        isNot(const EvaColors.light().auroraOpacity),
      );
    });
  });

  group('the light palette', () {
    test('carries every light token value from the spec', () {
      final EvaColors light = const EvaColors.light();

      expect(_hex(light.canvas), _argb(0xF0, 0xEE, 0xFF), reason: 'canvas');
      expect(_hex(light.surface), _argb(0xFF, 0xFF, 0xFF), reason: 'surface');
      expect(_hex(light.raised), _argb(0xE8, 0xE4, 0xFF), reason: 'raised');
      expect(_hex(light.ink), _argb(0x12, 0x0E, 0x28), reason: 'ink');
      expect(_hex(light.ink2), _argb(0x5A, 0x54, 0x80), reason: 'ink2');
      expect(_hex(light.ink3), _argb(0x9B, 0x97, 0xB8), reason: 'ink3');
      expect(_hex(light.line), _argb(0xD5, 0xD0, 0xEF), reason: 'line');
      expect(_hex(light.ember), _argb(0xD4, 0x89, 0x1A), reason: 'ember');
      expect(
        _hex(light.emberDeep),
        _argb(0xB5, 0x6C, 0x0C),
        reason: 'emberDeep',
      );
      expect(
        _hex(light.onEmber),
        _argb(0x3A, 0x1E, 0x00),
        reason:
            'onEmber — #3A1E00, NOT the spec\'s #FFF8EE; see the contrast '
            'group below and the EvaColors.light doc comment',
      );
      expect(_hex(light.ok), _argb(0x1A, 0x8C, 0x6A), reason: 'ok');
      expect(_hex(light.err), _argb(0xD6, 0x3B, 0x3B), reason: 'err');
      // Decision 153 — in light these are darker than the fills, and they are
      // the whole reason the tokens exist.
      expect(
        _hex(light.emberInk),
        _argb(0x84, 0x56, 0x10),
        reason: 'emberInk — #845610, the light gold ink',
      );
      expect(
        _hex(light.okInk),
        _argb(0x14, 0x6C, 0x52),
        reason: 'okInk — #146C52, the light success ink',
      );
      expect(
        _hex(light.errInk),
        _argb(0xB7, 0x26, 0x26),
        reason: 'errInk — #B72626, the light error ink',
      );

      expect(light.orbOpacity, 0.18, reason: 'orbOpacity');
      expect(light.auroraOpacity, 0.10, reason: 'auroraOpacity');

      expect(
        _hex(light.glassFill),
        _argb(0x00, 0x00, 0x00, 0x0A),
        reason: 'glassFill — rgba(0,0,0,0.03)',
      );
      expect(
        _hex(light.glassBorder),
        _argb(0x00, 0x00, 0x00, 0x14),
        reason: 'glassBorder — rgba(0,0,0,0.07)',
      );
      expect(
        _hex(light.glassShadow),
        _argb(0x12, 0x0E, 0x28, 0x1F),
        reason: 'glassShadow — rgba(18,14,40,0.12), NOT the brief’s #221C15',
      );

      // Phase 4 — the light `.hor`, `redesign.html:72`:
      // `linear-gradient(90deg,transparent,rgba(154,123,25,.8),transparent)`
      // over `box-shadow:0 0 12px rgba(154,123,25,.5)`.
      expect(
        _hex(light.seam),
        _argb(0x9A, 0x7B, 0x19, 0xCC),
        reason: 'seam — rgba(154,123,25,.8), redesign.html:72',
      );
      expect(
        _hex(light.seamGlow),
        _argb(0x9A, 0x7B, 0x19, 0x80),
        reason: 'seamGlow — rgba(154,123,25,.5), redesign.html:72',
      );
      // …and the wash is the SAME value light uses as dark, because
      // `redesign.html:73` dims `.bloom` with `opacity:.55` and never re-hues
      // it. The dimmer is `bloomOpacity` and it IS per-brightness — which is
      // what makes the shared hue below correct rather than accidental.
      expect(
        _hex(light.bloom),
        _argb(0xE4, 0x57, 0xD6, 0x8C),
        reason:
            'bloom — rgba(228,87,214,.55), redesign.html:254; light dims it '
            'with opacity, redesign.html:73',
      );
      expect(
        light.bloomOpacity,
        0.55,
        reason:
            'bloomOpacity — `opacity:.55` on all four `.bloom`s, '
            'redesign.html:73. NOT caller state: a caller-state dimmer that no '
            'caller sets leaves the card family light-mode-wrong the moment it '
            'lands',
      );
    });
  });

  group('the two palettes are genuinely different', () {
    test('every colour and opacity token differs, except the stickers and the wash', () {
      final Map<String, Object> dark = _snapshot(const EvaColors.dark());
      final Map<String, Object> light = _snapshot(const EvaColors.light());

      expect(dark.keys, light.keys, reason: 'same token set on both sides');

      final List<String> shared = <String>[
        for (final String key in dark.keys)
          if (dark[key] == light[key]) key,
      ];
      expect(shared, <String>[
        // …and the bloom wash, for a DIFFERENT and stronger reason: the
        // prototype's own light override (`redesign.html:73`) dims `.bloom`
        // with `opacity:.55` and never touches the `--bh` colour, so light and
        // dark wash the same hue. The dimmer is a **separate** token
        // (`bloomOpacity`, 1.0 / 0.55) precisely because this one is not — so the
        // exception below is about the hue alone and the light palette is not
        // shipping the wash at full strength.
        //
        // It leads the list because that is `_snapshot`'s own key order, and the
        // assertion compares the list — so a token added to `_snapshot` in the
        // wrong place shows up here rather than being absorbed.
        'bloom',
        // The OTHER values permitted to match are the seven stickers: §5.1
        // publishes one palette with no light variant.
        'sticker.sky',
        'sticker.lavender',
        'sticker.pink',
        'sticker.coral',
        'sticker.teal',
        'sticker.leaf',
        'sticker.sun',
      ], reason: 'a shared token means one theme ships the wrong colour');
      expect(shared.length, 8);
    });

    // =====================================================================
    // `bloomOpacity` — the light-mode wash dimmer, and the token this group
    // exists for.
    //
    // It is the one per-brightness float whose **omission from `lerp` is
    // invisible**: `EvaColors`'s constructor is `required`, but `this.bloomOpacity`
    // satisfies a dropped argument, so the row compiles, the whole-suite green
    // stays green, and the wash arrives in a light theme at full strength. The
    // mutation below is the proof that the tests here can see it.
    // =====================================================================
    group('bloomOpacity is the prototype\'s light-mode dimmer', () {
      test('1.0 dark / 0.55 light, and the .55 is redesign.html:73\'s', () {
        // Read against the prototype rather than against a literal, so a change
        // to `redesign.html` shows up here and not as a mysterious golden diff
        // in `glass_surface_test.dart`.
        final List<String> html = File('eva/redesign.html').readAsLinesSync();

        expect(html[72], contains('.bloom{opacity:.55}'));
        expect(const EvaColors.dark().bloomOpacity, 1.0);
        expect(const EvaColors.light().bloomOpacity, 0.55);

        // …and the token is a **number**, not a colour: the prototype's dimmer
        // is `opacity:`, not a re-hued `--bh`, which is why `bloom` above is
        // shared and this is not.
        expect(html[72], contains('opacity:.55'), reason: 'an opacity, not a hue');
        expect(
          html[72],
          isNot(contains('--bh')),
          reason:
              'if the prototype ever re-hued the wash instead of dimming it, '
              'the exception on `bloom` above would be wrong and the dimmer '
              'would belong inside the colour',
        );
      });

      test('and it is the THIRD per-brightness float, all three lerped', () {
        // The claim `seamGlow`'s doc's corrected premise now rests on. Written
        // as an inventory rather than as three hand-written expectations, so a
        // fourth per-brightness float arriving without a doc update is visible
        // here and not three months later in a review of that doc.
        final Map<String, double> darkFloats = <String, double>{
          'orbOpacity': const EvaColors.dark().orbOpacity,
          'auroraOpacity': const EvaColors.dark().auroraOpacity,
          'bloomOpacity': const EvaColors.dark().bloomOpacity,
        };
        final EvaColors mid = const EvaColors.dark().lerp(
          const EvaColors.light(),
          0.5,
        );

        for (final String key in darkFloats.keys) {
          expect(snapshotKeys, contains(key), reason: '$key must be snapshotted');
        }
        expect(
          mid.bloomOpacity,
          closeTo((darkFloats['bloomOpacity']! + 0.55) / 2, 1e-9),
          reason: 'the third float is lerped like the first two',
        );
        expect(
          mid.bloomOpacity,
          greaterThan(const EvaColors.light().bloomOpacity),
          reason:
              'and lands strictly between the endpoints — 1.0 and 0.55 cannot '
              'be interior at either, so this is what a `lerp` that kept '
              '`this` cannot satisfy',
        );
      });

      test('MUTATION PROOF — two mutations, and only one of them compiles', () {
        // Not a runtime check; a record of what was done to prove the tests
        // above are load-bearing. Both mutations were applied to `EvaColors`
        // .lerp and `eva_colors_test.dart` was run.
        //
        // **1. Delete the `bloomOpacity:` row entirely.**
        //
        // ```text
        // lib/core/design_system/tokens/eva_colors.dart:499:21: Error:
        //   Required named parameter 'bloomOpacity' must be provided.
        // ```
        //
        // A **compile error**, not a silent always-dark. The plan's Step 2 for
        // this token says an `lerp` omission "makes the token silently
        // always-dark", and that is **false for this class**: every field of
        // `EvaColors`'s constructor is `required`, so a dropped row cannot
        // compile. The premise holds for a class whose constructor defaults its
        // fields, and `EvaColors` is explicitly the opposite — its own doc says
        // "Every field is required rather than defaulted… a palette that
        // silently picks up a default is a palette where 'which colour is
        // this?' has two answers." So the compiler is already the gate here,
        // and the instruction's fear is not this class's failure mode.
        //
        // **2. Keep the row but lerp it to itself** —
        // `d(bloomOpacity, bloomOpacity)` instead of
        // `d(bloomOpacity, other.bloomOpacity)`.
        //
        // This one **compiles**, and it is the real failure: the wash arrives in
        // a light theme at 1.0. Red on `eva_colors_test.dart`:
        //
        // - `t = 1 reproduces the other palette exactly` — whole-map compare,
        //   light's 0.55 vs the lerped 1.0.
        // - `the midpoint sits genuinely between the endpoints` and `the
        //   midpoint is strictly interior, not one endpoint in disguise` —
        //   both name `bloomOpacity` explicitly.
        // - `and it is the THIRD per-brightness float, all three lerped`.
        //
        // **Not** red, and worth recording: `the two palettes are genuinely
        // different`, because that test reads two `EvaColors` constructors and
        // never calls `lerp`. "These two palettes differ" and "a transition
        // between them interpolates" are different claims, and only the second
        // is about `lerp`.
        //
        // Both mutations were reverted. `expect(snapshotKeys,
        // contains('bloomOpacity'))` below is the standing reminder that the
        // *snapshot* is what made mutation 2 observable at all: without the key,
        // the `t = 1` comparison would have compared 30 fields and reported
        // success.
        expect(snapshotKeys, contains('bloomOpacity'));
      });
    });

    test('both palettes carry the shared sticker map', () {
      expect(
        _snapshot(const EvaColors.dark())['sticker.sky'],
        _snapshot(const EvaColors.light())['sticker.sky'],
      );
      for (final EvaColors palette in <EvaColors>[
        const EvaColors.dark(),
        const EvaColors.light(),
      ]) {
        expect(
          palette.sticker.keys.toSet(),
          StickerSlot.values.toSet(),
          reason: 'a slot missing from one palette throws during lerp',
        );
      }
    });
  });

  // =========================================================================
  group("GlassTier.bloom's palette — seam, seamGlow, bloom", () {
    // These three are not `03-design-system.md` §5.1 tokens. §5.1 publishes
    // fourteen per brightness and names no seam and no wash; they are
    // transcribed from `eva/redesign.html`, which is the design source of truth
    // for the cards they paint. Their values are pinned above; what this group
    // asserts is the *reason* the palette looks the way it does, because a
    // well-formed hex nobody can account for is a colour that will be "tidied"
    // by the next reader.

    test('the seam is white in dark and gold in light, from two overrides', () {
      // `redesign.html:257` (base) and `:72` (`[data-mode=light]`). The alpha is
      // a separate claim from the hue, so both are stated: `.85`/`.8` for the
      // seam and `.6`/`.5` for its glow.
      expect(const EvaColors.dark().seam, const Color(0xD9FFFFFF));
      expect(const EvaColors.light().seam, const Color(0xCC9A7B19));
      expect(const EvaColors.dark().seamGlow, const Color(0x99FFFFFF));
      expect(const EvaColors.light().seamGlow, const Color(0x809A7B19));
      // The glow is a **lower** alpha than the seam it glows, in both palettes:
      // `rgba(…, .6)` behind `rgba(…, .85)` and `rgba(…, .5)` behind `rgba(…, .8)`.
      expect(
        const EvaColors.dark().seamGlow.a,
        lessThan(const EvaColors.dark().seam.a),
      );
      expect(
        const EvaColors.light().seamGlow.a,
        lessThan(const EvaColors.light().seam.a),
      );
    });

    test('the wash is one hue in both palettes, because light dims it', () {
      // The counterfactual matters: a test that only asserted equality would pass
      // if the token were forgotten in the light constructor and defaulted to the
      // dark value. `EvaColors.light()` is a required-parameter constructor with
      // no defaults, so a forgotten field is a compile error — and this asserts
      // the *value* the light palette declares rather than the dark one it
      // happens to equal.
      expect(const EvaColors.light().bloom, const Color(0x8CE457D6));
      expect(const EvaColors.dark().bloom, const Color(0x8CE457D6));
      // `rgba(228,87,214,.55)` — the `--bh` default in `redesign.html:254`.
      expect(const EvaColors.dark().bloom.a, closeTo(0.55, 0.005));
    });

    test('a per-host `--bh` is a caller parameter, not a token', () {
      // The claim that decides the widget's shape, asserted against the
      // reference rather than against this repository's taste. `glass_surface_test`
      // walks every `--bh` occurrence in the file; here the claim is only that
      // the two host elements already disagree, so no single token can serve
      // both.
      final String html = File('eva/redesign.html').readAsStringSync();

      // `#votdCard` (`:519`) and `#lastCard` (`:524`) are the two `.hcard`s.
      expect(html, contains('id="votdCard" style="--bh:rgba(228,87,214,.55)"'));
      expect(html, contains('id="lastCard" style="--bh:rgba(232,176,75,.35)"'));
      // …and the medals: FOUR declarations, THREE new hues. `:600` is deliberately
      // not asserted here, because it is not a new hue — `rgba(228,87,214,.5)`
      // is the default's own hue at a lower alpha. That omission used to be
      // papered over by a comment claiming "the four medals each carry their
      // own", which is the same over-claim the doc above it makes and the same
      // shape of error: four things declared, three asserted, the gap described
      // as if it were not a gap.
      expect(html, contains('class="medal" style="--bh:rgba(244,227,178,.5)"'));
      expect(html, contains('class="medal" style="--bh:rgba(217,142,50,.5)"'));
      expect(html, contains('class="medal" style="--bh:rgba(79,116,255,.5)"'));
      // The fourth one IS in the file, and its absence from the three above is
      // the point: it repeats `:254`'s hue, which is why a single `bloom` token
      // cannot reach it at `.5`. So it is asserted as the *repeat* rather than
      // as a fourth hue — which is a stronger claim, because it would fail if
      // the prototype's fourth medal were given a hue of its own.
      expect(html, contains('class="medal" style="--bh:rgba(228,87,214,.5)"'));
      expect(
        const EvaColors.dark().bloom,
        const Color(0x8CE457D6),
        reason:
            'so `:600` differs from the token in **alpha only**, which is the '
            'reason a caller parameter exists rather than a hue list',
      );
    });
  });

  // =========================================================================
  group('contrast — the pairings the design system actually relies on', () {
    // WHY THIS GROUP IS COMPUTED RATHER THAN TRANSCRIBED. `eva_colors.dart`
    // documented `onEmber` as "chosen so it clears WCAG AA against its own
    // accent at both sizes". It did not. Measured, the spec's light `#FFF8EE` on
    // light `#D4891A` is **2.69:1** — below AA-large (3:1), let alone AA (4.5:1)
    // — so the doc comment asserted a guarantee the code did not provide, and a
    // prose claim is not something any test can catch. These assertions ARE the
    // guarantee: the ratios are recomputed from the palette on every run, so a
    // palette edit that breaks a pairing is a test failure rather than a defect
    // that only a manual audit would find.
    //
    // The lists below are deliberately NOT the full cross-product of the palette.
    // A pairing nobody renders is not a guarantee the design system makes. What is
    // listed is what `eva_theme.dart` actually wires together:
    //
    // - `mustClearAA` — pairings a reader reads body-sized text through.
    // - `knownBelowAA` — pairings the theme DOES wire and that do NOT clear AA.
    //   The user ruled on `onEmber` only and this phase may not change any other
    //   token, so these are neither fixed nor forgotten: each carries a measured
    //   floor, and the entry fails if it falls further or if it silently starts
    //   clearing AA (which would mean the allowlist is stale).
    // - `wcagExempt` — pairings WCAG 1.4.3 exempts by name.

    for (final ({String name, EvaColors palette}) t
        in <({String name, EvaColors palette})>[
          (name: 'dark', palette: const EvaColors.dark()),
          (name: 'light', palette: const EvaColors.light()),
        ]) {
      test('${t.name}: every body-text pairing clears WCAG AA (4.5:1)', () {
        // `onEmber` is the point of the token: it is `EvaButton.primary`'s
        // foreground and `ColorScheme.onPrimary`, so it is the ink a reader
        // actually reads on the accent in both modes.
        final List<_Pairing> must = <_Pairing>[
          (
            name: 'ember/onEmber',
            where: 'the accent fill',
            on: t.palette.onEmber,
            against: t.palette.ember,
          ),
          (
            name: 'canvas/ink',
            where: 'body and headline text',
            on: t.palette.ink,
            against: t.palette.canvas,
          ),
          (
            name: 'surface/ink',
            where: 'text on a card or dialog',
            on: t.palette.ink,
            against: t.palette.surface,
          ),
          (
            name: 'raised/ink',
            where: 'snack-bar body text',
            on: t.palette.ink,
            against: t.palette.raised,
          ),
          (
            name: 'canvas/ink2',
            where: 'captions',
            on: t.palette.ink2,
            against: t.palette.canvas,
          ),
          (
            name: 'surface/ink2',
            where: 'captions on a card',
            on: t.palette.ink2,
            against: t.palette.surface,
          ),
          (
            name: 'raised/ink2',
            where: 'captions on glass',
            on: t.palette.ink2,
            against: t.palette.raised,
          ),
          (
            name: 'surface/err',
            where: 'an error message on a card',
            on: t.palette.err,
            against: t.palette.surface,
          ),
        ];
        expect(must, isNotEmpty, reason: 'the table has to have rows');

        for (final _Pairing pair in must) {
          final double ratio = _contrastRatio(pair.on, pair.against);
          expect(
            ratio,
            greaterThanOrEqualTo(_wcagAA),
            reason:
                '${t.name} ${pair.name} (${pair.where}) measures '
                '${ratio.toStringAsFixed(2)}:1 — '
                '${_css(pair.on)} on ${_css(pair.against)}',
          );
        }
      });

      test('${t.name}: each known sub-AA pairing is still where it was left', () {
        // NOT A GATE. These pairings are below AA by a decision recorded in
        // AGENT_CONTEXT §6 (Phase 1 review), and this phase may not move the
        // tokens they involve. What this asserts is that they have not MOVED —
        // neither silently worse (the floor) nor silently fixed (the ceiling,
        // which would mean the entry is stale and should be deleted).
        final List<_KnownGap> gaps = _knownGapsFor(t.palette);
        expect(
          gaps.length,
          t.name == 'dark' ? 0 : 7,
          reason: 'the sub-AA inventory is exhaustive for this palette',
        );

        for (final _KnownGap gap in gaps) {
          final double ratio = _contrastRatio(gap.on, gap.against);
          final String where = '${gap.name} (${gap.why})';

          expect(
            ratio,
            greaterThanOrEqualTo(gap.floor),
            reason:
                '${t.name} $where fell to ${ratio.toStringAsFixed(2)}:1, below '
                'its recorded floor of ${gap.floor.toStringAsFixed(2)}:1',
          );
          expect(
            ratio,
            lessThan(_wcagAA),
            reason:
                '${t.name} $where now measures ${ratio.toStringAsFixed(2)}:1 and '
                'clears AA — delete the entry rather than leaving a stale gap',
          );
          if (gap.largeTextOnly) {
            expect(
              ratio,
              greaterThanOrEqualTo(_wcagAALarge),
              reason:
                  '${t.name} $where is recorded as large-text-only, so it must '
                  'still clear 3:1 — otherwise it is usable at NO size',
            );
          } else {
            expect(
              ratio,
              lessThan(_wcagAALarge),
              reason:
                  '${t.name} $where is flagged as not large-text-only; if it now '
                  'clears 3:1, promote it rather than leaving a false flag',
            );
          }
        }
      });
    }

    test('the ember/onEmber pairing is recorded, not just gated', () {
      // The gate above passes for any ratio above 4.5, including one so dark it
      // looks accidental. These two are the numbers quoted in `eva_colors.dart`,
      // asserted with a tolerance so an unrelated re-derivation shows up as a
      // diff instead of being silently absorbed.
      expect(
        _contrastRatio(
          const EvaColors.dark().onEmber,
          const EvaColors.dark().ember,
        ),
        closeTo(9.17, 0.05),
      );
      expect(
        _contrastRatio(
          const EvaColors.light().onEmber,
          const EvaColors.light().ember,
        ),
        closeTo(5.41, 0.05),
      );
    });

    test('light onEmber is legible on the light surfaces, not only on ember', () {
      // `onEmber` is also `ColorScheme.onPrimaryContainer` and
      // `onSecondary`. Had it stayed a light value it would have vanished on the
      // light canvas the moment it appeared anywhere but on the accent itself —
      // which is exactly what the spec's #FFF8EE did: 1.08:1 on #F0EEFF.
      const EvaColors light = EvaColors.light();
      for (final MapEntry<String, Color> bg in <String, Color>{
        'canvas': light.canvas,
        'surface': light.surface,
        'raised': light.raised,
      }.entries) {
        expect(
          _contrastRatio(light.onEmber, bg.value),
          greaterThanOrEqualTo(_wcagAA),
          reason: 'light onEmber on ${bg.key}',
        );
      }
    });

    test('the spec\'s light onEmber would have failed this gate', () {
      // THE ANTI-VACUITY HALF. Without it a `_contrastRatio` that returned 21 for
      // everything would pass every assertion in this group. So the known-bad
      // value goes through the same code path and has to fail. If this stops
      // failing, either the arithmetic broke or the token did.
      const Color specOnEmber = Color(0xFFFFF8EE);
      const Color lightEmber = Color(0xFFD4891A);

      expect(
        _contrastRatio(specOnEmber, lightEmber),
        lessThan(_wcagAALarge),
        reason: '2.69:1 fails AA-large, which is why the token changed',
      );
      expect(_contrastRatio(specOnEmber, lightEmber), lessThan(_wcagAA));
      // And darkening it *while it stays light* is worse, not better: the ratio
      // falls toward `ember`'s own luminance. This is the detail that makes
      // "just darken it a little" the wrong repair, and why the token had to cross
      // over to a dark ink instead of sliding a few percent darker.
      expect(
        _contrastRatio(const Color(0xFFF0D8A0), lightEmber),
        lessThan(_contrastRatio(specOnEmber, lightEmber)),
        reason:
            'a slightly darker cream is a worse foreground, not a better one',
      );
      expect(
        _contrastRatio(const Color(0xFFD09040), lightEmber),
        lessThan(1.1),
        reason: 'this is ember\'s own luminance — the minimum of the curve',
      );
      expect(
        _contrastRatio(const Color(0xFF3A1E00), lightEmber),
        greaterThan(_contrastRatio(const Color(0xFF603000), lightEmber)),
        reason:
            'the ratio only recovers once the ink crosses ember\'s luminance',
      );
    });

    test('the WCAG-exempt pairings are exempt by name, not by convenience', () {
      // WCAG 1.4.3 exempts "text that is part of an inactive user interface
      // component" and "pure decoration". Both of these are named cases, so
      // asserting them is a design claim rather than a tolerance: `ink3` is the
      // disabled ink (it is `ThemeData.disabledColor`) and `line` is the hairline
      // that separates surfaces without carrying information. Neither may become
      // load-bearing while passing through here.
      for (final ({String name, EvaColors palette}) t
          in <({String name, EvaColors palette})>[
            (name: 'dark', palette: const EvaColors.dark()),
            (name: 'light', palette: const EvaColors.light()),
          ]) {
        expect(
          _contrastRatio(t.palette.ink3, t.palette.canvas),
          lessThan(_contrastRatio(t.palette.ink, t.palette.canvas)),
          reason:
              '${t.name} ink3 must stay the faintest ink against the canvas — in '
              'dark it is darker than ink, in light it is lighter, but either way '
              'it must read as more withdrawn than the primary ink',
        );
        expect(
          _contrastRatio(t.palette.ink3, t.palette.canvas),
          lessThan(_wcagAA),
          reason:
              '${t.name} ink3 is asserted as an AA-exempt disabled ink; if '
              'it clears AA, that exemption is no longer the reason it passes',
        );
        expect(
          _contrastRatio(t.palette.line, t.palette.canvas),
          lessThan(_wcagAALarge),
          reason:
              '${t.name} line is asserted as a decorative hairline, which '
              'WCAG treats as pure decoration — a contrast-carrying divider '
              'would need 3:1',
        );
      }
    });
  });

  // =========================================================================
  group('copyWith replaces exactly what it is handed', () {
    test('with no arguments returns an equal, distinct instance', () {
      final EvaColors dark = const EvaColors.dark();
      final EvaColors copy = dark.copyWith();

      expect(_snapshot(copy), _snapshot(dark));
      expect(
        identical(copy, dark),
        isFalse,
        reason: 'a fresh object, not this',
      );
    });

    test('changes one token and leaves the other twenty-nine untouched', () {
      final EvaColors dark = const EvaColors.dark();
      // Built through a runtime expression so the replacement cannot be the
      // canonicalised `ink` object `dark.ink` already holds.
      final Color replacement = const Color.fromARGB(0xFF, 0x11, 0x22, 0x33);
      final EvaColors copy = dark.copyWith(ink: replacement);

      final Map<String, Object> before = _snapshot(dark);
      final Map<String, Object> after = _snapshot(copy);

      expect(after['ink'], _hex(replacement));
      final List<String> changed = <String>[
        for (final String key in before.keys)
          if (before[key] != after[key]) key,
      ];
      expect(changed, <String>[
        'ink',
      ], reason: 'copyWith that touches a second field is a field-mixup bug');
      // …and the snapshot really is the whole surface.
      expect(before.keys.toList(), snapshotKeys);
    });

    test('honours a zero opacity rather than treating it as absent', () {
      // The `?? this.x` idiom is only correct if a *zero* is distinguishable
      // from *not passed*. `orbOpacity: 0` is a legitimate value — a fully
      // opaque-free background — so a `!= null` guard that mishandles 0 would
      // silently keep the old 0.55.
      final EvaColors copy = const EvaColors.dark().copyWith(orbOpacity: 0);
      expect(copy.orbOpacity, 0);
      expect(copy.auroraOpacity, const EvaColors.dark().auroraOpacity);

      final EvaColors zeroed = const EvaColors.dark().copyWith(
        auroraOpacity: 0,
      );
      expect(zeroed.auroraOpacity, 0);
    });

    test('replaces the sticker map wholesale, not key by key', () {
      final Map<StickerSlot, Color> replacement = <StickerSlot, Color>{
        for (final StickerSlot slot in StickerSlot.values)
          slot: const Color(0xFF000001),
      };
      final EvaColors copy = const EvaColors.dark().copyWith(
        sticker: replacement,
      );

      expect(copy.sticker, replacement);
      for (final StickerSlot slot in StickerSlot.values) {
        expect(copy.sticker[slot], replacement[slot]);
      }
    });

    test('a copyWith on a CUSTOM sticker map does not revert to stock', () {
      // THE ALIASING MUTATION THIS EXISTS FOR. `sticker ?? this.sticker` and
      // `sticker ?? EvaStickerPalette.colors` are the same statement whenever
      // `this.sticker` IS the stock map — which is the case for
      // `EvaColors.dark()` and `EvaColors.light()`, so the existing aliasing
      // tests could not tell them apart. Write `sticker ?? EvaStickerPalette.colors`
      // into `copyWith` and every other test in this file stays green.
      //
      // The difference only appears on a palette carrying a map the caller chose,
      // which is exactly what a `copyWith(sticker: …)` produces. So the case is
      // built the way production would build it: a custom map, then an unrelated
      // `copyWith` on top of it.
      final Map<StickerSlot, Color> custom = <StickerSlot, Color>{
        for (final StickerSlot slot in StickerSlot.values)
          slot: const Color(0xFF000002),
      };
      final EvaColors withCustom = const EvaColors.dark().copyWith(
        sticker: custom,
      );
      expect(withCustom.sticker, custom, reason: 'precondition');

      // No arguments at all.
      expect(
        withCustom.copyWith().sticker,
        custom,
        reason: 'a bare copyWith must preserve the caller\'s map, not reset it',
      );
      // An unrelated field changed.
      final EvaColors withBoth = withCustom.copyWith(
        ink: const Color(0xFF112233),
      );
      expect(withBoth.sticker, custom);
      for (final StickerSlot slot in StickerSlot.values) {
        expect(
          withBoth.sticker[slot],
          const Color(0xFF000002),
          reason: 'slot ${slot.name} reverted to stock',
        );
      }
      // …and explicitly against the shared constant, so a failure names which of
      // the two maps was wrong rather than just "not equal".
      expect(
        identical(withBoth.sticker, EvaStickerPalette.colors),
        isFalse,
        reason: 'reverting to the shared stock map is the mutation',
      );
      expect(
        identical(withCustom.copyWith().sticker, EvaStickerPalette.colors),
        isFalse,
      );

      // The light palette behaves identically, so the mutation is not
      // dark-specific.
      expect(
        const EvaColors.light().copyWith(sticker: custom).copyWith().sticker,
        custom,
      );
    });

    test('every token is reachable through copyWith', () {
      // Walks the whole surface: mutating one token at a time must produce
      // exactly one changed key. A token that `copyWith` silently ignores — a
      // parameter the implementation declares but never consumes — shows up
      // here as a zero-length change list, which is the failure this catches.
      final EvaColors base = const EvaColors.dark();
      final Map<String, Object> baseSnapshot = _snapshot(base);

      // A colour no palette entry uses, so "changed" cannot be confused with
      // "replaced by an equal value".
      Color probe(int n) => Color(0xFF000000 | n);

      final Map<String, EvaColors> probes = <String, EvaColors>{
        'canvas': base.copyWith(canvas: probe(0x11)),
        'surface': base.copyWith(surface: probe(0x12)),
        'raised': base.copyWith(raised: probe(0x13)),
        'ink': base.copyWith(ink: probe(0x14)),
        'ink2': base.copyWith(ink2: probe(0x15)),
        'ink3': base.copyWith(ink3: probe(0x16)),
        'line': base.copyWith(line: probe(0x17)),
        'ember': base.copyWith(ember: probe(0x18)),
        'emberDeep': base.copyWith(emberDeep: probe(0x19)),
        'onEmber': base.copyWith(onEmber: probe(0x1A)),
        'ok': base.copyWith(ok: probe(0x1B)),
        'err': base.copyWith(err: probe(0x1C)),
        'glassFill': base.copyWith(glassFill: probe(0x1D)),
        'glassBorder': base.copyWith(glassBorder: probe(0x1E)),
        'glassShadow': base.copyWith(glassShadow: probe(0x1F)),
        // Decision 153's three accent inks. Absent until Phase 4 added them to
        // [_snapshot] — which is the point of the `snapshotKeys` equality below:
        // it is the check that turns "a token nobody walks" into a red.
        'emberInk': base.copyWith(emberInk: probe(0x20)),
        'okInk': base.copyWith(okInk: probe(0x21)),
        'errInk': base.copyWith(errInk: probe(0x22)),
        // Phase 4's `.hor` / `.bloom` palette.
        'seam': base.copyWith(seam: probe(0x23)),
        'seamGlow': base.copyWith(seamGlow: probe(0x24)),
        'bloom': base.copyWith(bloom: probe(0x25)),
        'orbOpacity': base.copyWith(orbOpacity: 0.11),
        'auroraOpacity': base.copyWith(auroraOpacity: 0.12),
        // The third per-brightness float, and the one whose `lerp` omission is
        // the easiest to write: `EvaColors`'s constructor is `required`, so a
        // `lerp` that leaves the row out still compiles — `this.bloomOpacity`
        // satisfies it — and the token would arrive in a light theme at 1.0.
        'bloomOpacity': base.copyWith(bloomOpacity: 0.77),
      };

      // Twenty-four mutable tokens: twenty-one colours and the three opacities.
      // The sticker map is covered by its own test above.
      expect(
        probes.keys.toSet(),
        snapshotKeys.where((String key) => !key.startsWith('sticker.')).toSet(),
      );

      for (final MapEntry<String, EvaColors> probe in probes.entries) {
        expect(_changedKeys(baseSnapshot, _snapshot(probe.value)), <String>[
          probe.key,
        ], reason: 'copyWith(${probe.key}: …) must change exactly that token');
      }
    });
  });

  // =========================================================================
  group('lerp interpolates rather than picking an endpoint', () {
    test('t = 0 reproduces this palette exactly', () {
      final EvaColors dark = const EvaColors.dark();
      final Map<String, Object> start = _snapshot(dark);
      final Map<String, Object> blended = _snapshot(
        dark.lerp(const EvaColors.light(), 0),
      );

      final List<String> wrong = <String>[
        for (final String key in start.keys)
          if (start[key] != blended[key]) key,
      ];
      expect(wrong, isEmpty, reason: 't=0 must be the identity on `this`');
    });

    test('t = 1 reproduces the other palette exactly', () {
      // THE LOAD-BEARING ENDPOINT. This is what catches a `lerp` that ignores
      // `t`, always returns `this`, or — the subtle one — a `lerp` that drops a
      // field from its constructor call. A dropped field keeps its value from
      // `this` and therefore *looks* right at t = 0 and wrong only here.
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();

      expect(_snapshot(dark.lerp(light, 1)), _snapshot(light));
      expect(_snapshot(light.lerp(dark, 1)), _snapshot(dark));
    });

    test('t = 0 on a palette lerped with itself reproduces itself', () {
      // Explicitly requested, and it is not redundant with the t=0 case above:
      // `lerp(this, 0)` with a lerp that compared `other == null` but then read
      // `other.x` off an unsound path is the classic self-lerp crash, and with a
      // lerp that skipped work when `other == this` this proves the skip is
      // value-correct rather than merely fast.
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();

      for (final EvaColors palette in <EvaColors>[dark, light]) {
        expect(
          _snapshot(palette.lerp(palette, 0)),
          _snapshot(palette),
          reason: 'self-lerp at t=0 must be the identity',
        );
        expect(_snapshot(palette.lerp(palette, 1)), _snapshot(palette));
        expect(_snapshot(palette.lerp(palette, 0.5)), _snapshot(palette));
      }
    });

    test('the midpoint sits genuinely between the endpoints', () {
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();
      final EvaColors mid = dark.lerp(light, 0.5);

      for (final String name in <String>[
        'canvas',
        'ink',
        'ember',
        'err',
        'glassShadow',
        // Phase 4's `.hor` pair — the two tokens whose light values differ from
        // their dark ones in BOTH hue and alpha, so a lerp that pinned either
        // would show up here.
        'seam',
        'seamGlow',
      ]) {
        final Color from = _colorNamed(dark, name);
        final Color to = _colorNamed(light, name);
        final Color at = _colorNamed(mid, name);
        expect(
          at.r,
          closeTo((from.r + to.r) / 2, 0.01),
          reason: '$name.r at t=0.5',
        );
        expect(
          at.g,
          closeTo((from.g + to.g) / 2, 0.01),
          reason: '$name.g at t=0.5',
        );
        expect(
          at.b,
          closeTo((from.b + to.b) / 2, 0.01),
          reason: '$name.b at t=0.5',
        );
        expect(
          at.a,
          closeTo((from.a + to.a) / 2, 0.01),
          reason: '$name.a at t=0.5',
        );
      }

      expect(
        mid.orbOpacity,
        closeTo((dark.orbOpacity + light.orbOpacity) / 2, 1e-9),
      );
      expect(
        mid.auroraOpacity,
        closeTo((dark.auroraOpacity + light.auroraOpacity) / 2, 1e-9),
      );
      // The one whose omission is silent. `t = 1` above already catches a dropped
      // row, but this states the *shape* of the claim — three per-brightness
      // floats, all lerped — rather than leaving the reader to infer it from a
      // whole-map comparison they have to trust.
      expect(
        mid.bloomOpacity,
        closeTo((dark.bloomOpacity + light.bloomOpacity) / 2, 1e-9),
      );
    });

    test('the midpoint is strictly interior, not one endpoint in disguise', () {
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();
      final EvaColors mid = dark.lerp(light, 0.5);

      // `canvas`: dark #05081A → light #F0EEFF. A lerp that clamped, snapped or
      // quantised would land exactly on one of these.
      expect(_hex(mid.canvas), isNot(_hex(dark.canvas)));
      expect(_hex(mid.canvas), isNot(_hex(light.canvas)));
      expect(
        _hex(mid.canvas),
        isNot(anyOf(_hex(dark.surface), _hex(light.surface))),
        reason: 'a value copied from the wrong field',
      );

      // The doubles are the cheapest interior proof because they need no channel
      // decoding: 0.55 → 0.18 cannot be interior at 0.55 or at 0.18. And 1.0 →
      // 0.55 cannot be interior at either end, which is the case that would fail
      // for a `lerp` that silently kept `this` — exactly what a dropped
      // `bloomOpacity` row does.
      expect(mid.orbOpacity, greaterThan(light.orbOpacity));
      expect(mid.orbOpacity, lessThan(dark.orbOpacity));
      expect(mid.auroraOpacity, greaterThan(light.auroraOpacity));
      expect(mid.auroraOpacity, lessThan(dark.auroraOpacity));
      expect(mid.bloomOpacity, greaterThan(light.bloomOpacity));
      expect(mid.bloomOpacity, lessThan(dark.bloomOpacity));
    });

    test('t is honoured monotonically across the whole range', () {
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();

      double opacityAt(double t) => dark.lerp(light, t).orbOpacity;
      expect(opacityAt(0), closeTo(dark.orbOpacity, 1e-12));
      expect(opacityAt(0.25), closeTo(dark.orbOpacity - 0.25 * 0.37, 1e-9));
      expect(opacityAt(0.5), closeTo(dark.orbOpacity - 0.5 * 0.37, 1e-9));
      expect(opacityAt(0.75), closeTo(dark.orbOpacity - 0.75 * 0.37, 1e-9));
      expect(opacityAt(1), closeTo(light.orbOpacity, 1e-12));

      for (double t = 0; t < 1; t += 0.1) {
        expect(
          opacityAt(t),
          greaterThan(opacityAt(t + 0.1)),
          reason: 'dark→light must decrease monotonically; failed at t=$t',
        );
      }

      // And the colour channels follow the same ordering, which a lerp that
      // only interpolated the doubles would not.
      double greenAt(double t) => dark.lerp(light, t).ink.g;
      for (double t = 0; t < 1; t += 0.1) {
        expect(greenAt(t), greaterThan(greenAt(t + 0.1)));
      }
    });

    test('interpolates the alpha channel of the glass tokens', () {
      // `glassFill`, `glassBorder` and `glassShadow` are the only tokens with a
      // non-opaque alpha, so a lerp that interpolated RGB and pinned alpha to
      // 255 — the default when `t` is applied per-channel on a 0xAARRGGBB int —
      // would render glass as an opaque slab mid-transition and pass every
      // opaque-colour assertion above.
      //
      // CORRECTED IN PHASE 4: they were **not** the only such tokens. `seam`,
      // `seamGlow` and `bloom` are three more, and this test's own doc claimed
      // exhaustiveness it did not have — the same defect class as a `_snapshot`
      // missing a field, in a paragraph rather than in a table.
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();
      final EvaColors mid = dark.lerp(light, 0.5);

      expect(
        mid.glassFill.a,
        closeTo((dark.glassFill.a + light.glassFill.a) / 2, 0.01),
      );
      expect(
        mid.glassBorder.a,
        closeTo((dark.glassBorder.a + light.glassBorder.a) / 2, 0.01),
      );
      expect(
        mid.glassShadow.a,
        closeTo((dark.glassShadow.a + light.glassShadow.a) / 2, 0.01),
      );
      expect(mid.glassFill.a, lessThan(1.0), reason: 'not fully opaque');

      // The six translucent tokens, walked rather than listed, so a seventh is
      // covered by being added.
      for (final String name in <String>[
        'glassFill',
        'glassBorder',
        'glassShadow',
        'seam',
        'seamGlow',
        'bloom',
      ]) {
        expect(
          _colorNamed(mid, name).a,
          closeTo(
            (_colorNamed(dark, name).a + _colorNamed(light, name).a) / 2,
            0.01,
          ),
          reason: '$name.a must interpolate, not snap',
        );
      }

      expect(
        dark.glassFill.a,
        closeTo(0x0D / 0xFF, 1e-9),
        reason: 'dark glassFill is rgba(255,255,255,0.05)',
      );
      expect(
        dark.glassShadow.a,
        closeTo(0x59 / 0xFF, 1e-9),
        reason: 'dark glassShadow is rgba(0,0,0,0.35)',
      );
    });

    test('interpolates every sticker slot into a map of its own', () {
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();
      final EvaColors mid = dark.lerp(light, 0.5);

      expect(
        mid.sticker.keys.toSet(),
        StickerSlot.values.toSet(),
        reason: 'a slot dropped here throws on the next lerp',
      );
      expect(
        identical(mid.sticker, dark.sticker),
        isFalse,
        reason: 'lerp must not alias either endpoint’s map',
      );
      expect(identical(mid.sticker, light.sticker), isFalse);

      // The palette is one palette (§5.1 gives no light variant), so a correct
      // interpolation returns those exact values at every t. A lerp that
      // *dropped* the sticker block would leave `this`’s map in place, which is
      // indistinguishable by value here — hence the aliasing assertions above,
      // which are what actually catch that mutation.
      for (final StickerSlot slot in StickerSlot.values) {
        expect(
          mid.sticker[slot],
          dark.sticker[slot],
          reason: 'slot ${slot.name} is shared, so it must be unchanged',
        );
      }

      // THE ALIASING HAZARD, ASSERTED DIRECTLY. Both palettes point at the one
      // `const EvaStickerPalette.colors` instance, so a lerp that reused
      // `this.sticker` instead of building a fresh map would hand every caller a
      // handle on the shared constant — and the first write through it would
      // repaint all seven stickers, in both themes, for the rest of the process.
      // Writing through the interpolated map must therefore leave both
      // endpoints untouched. (The interpolated map itself is a plain mutable
      // literal, exactly as `03-design-system.md` §5.4 writes it; the property
      // that matters is that nobody shares it.)
      mid.sticker[StickerSlot.sun] = const Color(0xFF00FF00);
      expect(
        dark.sticker[StickerSlot.sun],
        const Color(0xFFF5C84C),
        reason: 'writing through an interpolated map must not touch the source',
      );
      expect(light.sticker[StickerSlot.sun], const Color(0xFFF5C84C));
      expect(mid.sticker[StickerSlot.sun], const Color(0xFF00FF00));
    });

    test('a custom bloom still interpolates, which is the only way to see it', () {
      // **A GAP THIS GROUP HAD, FOUND BY MUTATION.** Both stock palettes declare
      // the *same* `bloom` — `redesign.html:73` dims the wash with an opacity and
      // never re-hues it — so on the stock pair `c(bloom, other.bloom)` and a bare
      // `bloom` produce identical results at every `t`. Writing `bloom: bloom`
      // into `lerp` therefore leaves **every other test in this file green**,
      // including `t = 1 reproduces the other palette exactly` and the
      // alpha-interpolation walk, because the field it drops is one that happens
      // to agree with itself.
      //
      // The witness is a palette the caller built, which is exactly what
      // `copyWith(bloom: …)` produces and the only shape in which the two
      // spellings differ. Same mechanism as the sticker-map aliasing assertions
      // above, and for the same reason: the palette is one palette, so a correct
      // interpolation is indistinguishable from a dropped field by value.
      final EvaColors custom = const EvaColors.dark().copyWith(
        bloom: const Color(0xFF00FF00),
      );
      expect(custom.bloom, const Color(0xFF00FF00), reason: 'precondition');

      final EvaColors mid = custom.lerp(const EvaColors.light(), 0.5);
      expect(mid.bloom, isNot(custom.bloom), reason: 'the field never moved');
      expect(mid.bloom, isNot(const EvaColors.light().bloom));
      expect(
        mid.bloom,
        Color.lerp(const Color(0xFF00FF00), const EvaColors.light().bloom, 0.5),
      );

      // …and the stock pair still satisfies both spellings, which is why it is
      // not the witness.
      expect(
        const EvaColors.dark().lerp(const EvaColors.light(), 0.5).bloom,
        const EvaColors.dark().bloom,
        reason:
            'dark and light agree, so nothing here could ever distinguish them',
      );
    });

    test('a null other returns this unchanged at every t, including t = 1', () {
      // `lerp(null, t)` is how `ThemeData` asks for "no blend", and it is the
      // one path where an implementation can be sloppy about `t`. Returning a
      // *blend* would be impossible (there is nothing to blend toward) but
      // returning a `copyWith`-with-nulls copy is not — so assert on values
      // across the range, not just on non-nullness.
      final EvaColors dark = const EvaColors.dark();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(_snapshot(dark.lerp(null, t)), _snapshot(dark), reason: 't=$t');
      }
    });

    test('is symmetric, to within the 8-bit quantisation', () {
      // Symmetric modulo rounding: `Color.lerp` computes `a * (1 - t) + b * t` on
      // doubles and then rounds each channel to 8 bits, and that arithmetic is
      // not exactly associative — `dark.lerp(light, 0.3)` and
      // `light.lerp(dark, 0.7)` can land one unit apart on a channel that sits
      // on a rounding boundary (`ink.g` does). A tolerance of one 8-bit step is
      // therefore the strongest claim that is actually true of the framework,
      // and it is still far stronger than "both are non-null": a lerp that
      // ignored `t`, clamped it, or always returned `this` is off by hundreds.
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();
      final EvaColors forward = dark.lerp(light, 0.3);
      final EvaColors backward = light.lerp(dark, 0.7);

      final Map<String, Object> a = _snapshot(forward);
      final Map<String, Object> b = _snapshot(backward);

      expect(
        a.keys.toSet(),
        b.keys.toSet(),
        reason: 'the token SETS must match exactly',
      );

      for (final String key in a.keys) {
        if (a[key] is double) {
          expect(a[key], closeTo(b[key]! as double, 1e-9), reason: key);
        } else {
          expect(
            (a[key]! as int) - (b[key]! as int),
            anyOf(lessThanOrEqualTo(1), greaterThanOrEqualTo(-1)),
            reason: '$key differs by more than one 8-bit step',
          );
        }
      }
    });
  });

  // =========================================================================
  group('the extension contract', () {
    test('survives a ThemeData round trip', () {
      // This is the whole reason the type extends ThemeExtension rather than
      // being a plain value: `ThemeData.lerp` reaches into its extension list
      // and needs `copyWith` + `lerp` to behave. Reading it back off a real
      // theme is what proves the list registration works, not just that the two
      // methods exist.
      final ThemeData theme = ThemeData(
        brightness: Brightness.dark,
        extensions: const <ThemeExtension<dynamic>>[EvaColors.dark()],
      );
      final EvaColors? resolved = theme.extension<EvaColors>();

      expect(resolved, isNotNull);
      expect(_snapshot(resolved!), _snapshot(const EvaColors.dark()));
    });

    test('is interpolated by ThemeData.lerp, not just by direct calls', () {
      final ThemeData from = ThemeData(
        brightness: Brightness.dark,
        extensions: const <ThemeExtension<dynamic>>[EvaColors.dark()],
      );
      final ThemeData to = ThemeData(
        brightness: Brightness.dark,
        extensions: const <ThemeExtension<dynamic>>[EvaColors.light()],
      );
      final ThemeData blended = ThemeData.lerp(from, to, 1);

      expect(
        _snapshot(blended.extension<EvaColors>()!),
        _snapshot(const EvaColors.light()),
        reason: 't=1 must land wholly on the destination extension',
      );
    });

    test('is usable as a const value, so themes can be const', () {
      // `prefer_const_constructors` is fatal here, so this is as much a lint
      // assertion as a behavioural one: if the constructors lost `const`, the
      // analyzer would reject the const expressions below.
      //
      // TWO SEPARATE const declarations, deliberately. The first draft of this
      // read `identical(dark, dark)` — one binding, compared with itself, which
      // is `true` for any `x` whatsoever and therefore asserted nothing. What is
      // actually under test is Dart's const canonicalisation: two *distinct
      // const expressions* that evaluate to the same constant object are
      // `identical`. That claim is falsifiable in a way the tautology was not —
      // drop `const` from either constructor and the analyzer rejects the const
      // context rather than the identity changing at run time, which is the
      // point: the property being protected is a compile-time one.
      const EvaColors dark = EvaColors.dark();
      const EvaColors light = EvaColors.light();

      expect(
        identical(const EvaColors.dark(), const EvaColors.dark()),
        isTrue,
        reason: 'two const expressions of the same value are one object',
      );
      expect(
        identical(const EvaColors.light(), const EvaColors.light()),
        isTrue,
      );
      // And the two palettes are still distinct objects, so canonicalisation is
      // not collapsing everything into one.
      expect(
        identical(const EvaColors.dark(), const EvaColors.light()),
        isFalse,
      );

      // The declared locals resolve to those same canonical instances, which is
      // what makes `EvaThemeDark.theme` stable across reads.
      expect(identical(dark, const EvaColors.dark()), isTrue);
      expect(identical(light, const EvaColors.light()), isTrue);
    });
  });
}

/// Reads one token off [c] by its spec name, so a name-keyed expectation table
/// can drive the interpolation assertions.
Color _colorNamed(EvaColors c, String name) => switch (name) {
  'canvas' => c.canvas,
  'surface' => c.surface,
  'raised' => c.raised,
  'ink' => c.ink,
  'ink2' => c.ink2,
  'ink3' => c.ink3,
  'line' => c.line,
  'ember' => c.ember,
  'emberDeep' => c.emberDeep,
  'onEmber' => c.onEmber,
  'ok' => c.ok,
  'err' => c.err,
  'emberInk' => c.emberInk,
  'okInk' => c.okInk,
  'errInk' => c.errInk,
  'seam' => c.seam,
  'seamGlow' => c.seamGlow,
  'bloom' => c.bloom,
  'glassFill' => c.glassFill,
  'glassBorder' => c.glassBorder,
  'glassShadow' => c.glassShadow,
  _ => throw ArgumentError.value(name, 'name', 'unknown token'),
};
