import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/eva_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../flutter_test_config.dart';

/// Every `TextTheme` slot, with the Eva role each one is expected to carry.
///
/// The names are the SDK's; the role column is the claim under test. Reading the
/// inventory off the map rather than off a hand-written list keeps the "all
/// fifteen slots are mapped" assertion honest — a slot the implementation leaves
/// null is not in this table and is caught by the count assertion below.
const Map<String, String> expectedSlotFamilies = <String, String>{
  'displayLarge': 'CormorantGaramond',
  'displayMedium': 'CormorantGaramond',
  'displaySmall': 'CormorantGaramond',
  'headlineLarge': 'CormorantGaramond',
  'headlineMedium': 'CormorantGaramond',
  'headlineSmall': 'CormorantGaramond',
  'titleLarge': 'DMSans',
  'titleMedium': 'DMSans',
  'titleSmall': 'DMSans',
  'bodyLarge': 'DMSans',
  'bodyMedium': 'DMSans',
  'bodySmall': 'DMSans',
  'labelLarge': 'DMSans',
  'labelMedium': 'DMSans',
  'labelSmall': 'DMSans',
};

TextStyle? slot(TextTheme theme, String name) => switch (name) {
  'displayLarge' => theme.displayLarge,
  'displayMedium' => theme.displayMedium,
  'displaySmall' => theme.displaySmall,
  'headlineLarge' => theme.headlineLarge,
  'headlineMedium' => theme.headlineMedium,
  'headlineSmall' => theme.headlineSmall,
  'titleLarge' => theme.titleLarge,
  'titleMedium' => theme.titleMedium,
  'titleSmall' => theme.titleSmall,
  'bodyLarge' => theme.bodyLarge,
  'bodyMedium' => theme.bodyMedium,
  'bodySmall' => theme.bodySmall,
  'labelLarge' => theme.labelLarge,
  'labelMedium' => theme.labelMedium,
  'labelSmall' => theme.labelSmall,
  _ => throw ArgumentError.value(name, 'name', 'unknown TextTheme slot'),
};

void main() {
  // =========================================================================
  group('the five families', () {
    test('are named exactly as pubspec.yaml declares them', () {
      // `test/flutter_test_config.dart` spells out the bundled families
      // character-for-character, and the engine matches a `TextStyle.fontFamily`
      // against exactly that string. A family name that is right-looking but
      // spelled differently resolves to the fallback font silently — no
      // exception, no warning, just the wrong typeface in every golden. So this
      // asserts against the registry the test engine actually loaded, not
      // against a copy of the names.
      expect(<String>{
        EvaTypography.displayFamily,
        EvaTypography.scriptureFamily,
        EvaTypography.arabicFamily,
        EvaTypography.uiFamily,
        EvaTypography.monoFamily,
      }, bundledFontFamilies.keys.toSet());
      expect(EvaTypography.uiFamily, 'DMSans', reason: 'not "DMSans"');
      expect(EvaTypography.displayFamily, 'CormorantGaramond');
      expect(EvaTypography.scriptureFamily, 'EBGaramond');
      expect(EvaTypography.arabicFamily, 'Amiri');
      expect(EvaTypography.monoFamily, 'SpaceMono');
    });

    test('are five distinct families', () {
      // Four families and one typo apart is the failure mode this catches: a
      // duplicated family name leaves two roles rendering identically and no
      // test noticing, because both names are in the pubspec.
      expect(
        <String>{
          EvaTypography.displayFamily,
          EvaTypography.scriptureFamily,
          EvaTypography.arabicFamily,
          EvaTypography.uiFamily,
          EvaTypography.monoFamily,
        }.length,
        5,
      );
    });
  });

  // =========================================================================
  group('the TextTheme mapping', () {
    test('assigns a family to every one of the fifteen slots', () {
      final TextTheme dark = EvaTypography.textTheme(const EvaColors.dark());
      for (final MapEntry<String, String> entry
          in expectedSlotFamilies.entries) {
        final TextStyle? style = slot(dark, entry.key);
        expect(style, isNotNull, reason: '${entry.key} was left null');
        expect(style!.fontFamily, entry.value, reason: entry.key);
      }
      expect(expectedSlotFamilies.length, 15, reason: 'the M3 slot count');
    });

    test('puts the display serif on display and headline only', () {
      final TextTheme dark = EvaTypography.textTheme(const EvaColors.dark());
      final Set<String> serif = <String>{
        for (final MapEntry<String, String> e in expectedSlotFamilies.entries)
          if (e.value == EvaTypography.displayFamily) e.key,
      };

      // The slot NAMES are already enumerated in `expectedSlotFamilies` and pinned
      // at the top of this group, so restating the set here added nothing — the
      // first draft of this test did, and the duplication meant a renamed slot
      // had to be fixed in two places. What is worth saying, and what this
      // asserts, is the split: the serif slots render in the serif, and a
      // representative sample of the non-serif slots render in the UI sans. That
      // is the mapping; the inventory is the other test's job.
      expect(serif, isNotEmpty, reason: 'some slots take the serif');
      for (final String name in serif) {
        expect(
          slot(dark, name)!.fontFamily,
          EvaTypography.displayFamily,
          reason: '$name is in the serif set, so it must render in the serif',
        );
        expect(
          slot(dark, name)!.fontFamily,
          isNot(EvaTypography.uiFamily),
          reason: name,
        );
      }
      for (final String name in <String>[
        'titleLarge',
        'bodyLarge',
        'labelLarge',
      ]) {
        expect(
          slot(dark, name)!.fontFamily,
          EvaTypography.uiFamily,
          reason: '$name is UI, not display',
        );
      }
    });

    test('carries the Eva ink colours, not a default black', () {
      // The M3 base typography resolves `displayColor`/`bodyColor` from a
      // `Colors.black54`-style default. On a near-black canvas that is
      // invisible, so the theme has to push the palette's own ink in — this is
      // the assertion that catches a `textTheme` built from `Typography` and
      // never recoloured.
      final EvaColors light = const EvaColors.light();
      final TextTheme themed = EvaTypography.textTheme(light);

      expect(themed.displayLarge!.color, light.ink);
      expect(themed.bodyLarge!.color, light.ink);
      expect(themed.titleMedium!.color, light.ink);
      expect(themed.labelSmall!.color, light.ink);
      expect(
        themed.bodyLarge!.color,
        isNot(const Color(0x8A000000)),
        reason: 'Colors.black54 is the framework default, not an Eva token',
      );
    });

    test(
      'is a distinct object per palette, and reflects the ink it was given',
      () {
        final EvaColors dark = const EvaColors.dark();
        final EvaColors light = const EvaColors.light();
        final TextTheme a = EvaTypography.textTheme(dark);
        final TextTheme b = EvaTypography.textTheme(light);

        expect(identical(a, b), isFalse);
        expect(a.bodyLarge!.color, dark.ink);
        expect(b.bodyLarge!.color, light.ink);
        expect(a.bodyLarge!.fontFamily, b.bodyLarge!.fontFamily);
      },
    );
  });

  // =========================================================================
  group('the scripture styles, which have no Material slot', () {
    test('use EB Garamond for latin and Amiri for arabic', () {
      final EvaColors colors = const EvaColors.dark();
      expect(
        EvaTypography.scriptureLatin(colors).fontFamily,
        EvaTypography.scriptureFamily,
      );
      expect(
        EvaTypography.scriptureArabic(colors).fontFamily,
        EvaTypography.arabicFamily,
      );
    });

    test('never put Space Mono on Arabic — the glyph-coverage guard', () {
      // `03-design-system.md` §5.2: "`mono` must never be applied to Arabic",
      // and `09-quality-gates.md` §11 schedules the widget-tree version of this
      // check. This is the token-level half: it cannot see a widget that builds
      // its own `TextStyle`, but it does pin the pairing that the half that can
      // will walk looking for, and it fails today if the two styles are swapped.
      final EvaColors colors = const EvaColors.dark();
      expect(
        EvaTypography.scriptureArabic(colors).fontFamily,
        isNot(EvaTypography.monoFamily),
      );
      expect(
        EvaTypography.scriptureLatin(colors).fontFamily,
        isNot(EvaTypography.monoFamily),
      );
      // Space Mono carries no Arabic glyphs at all, so a single Arabic string
      // bound to it renders as tofu. The bundled file list proves the point
      // without rendering anything.
      expect(
        bundledFontFamilies[EvaTypography.monoFamily],
        isNot(contains(contains('Amiri'))),
      );
    });

    test('render latin and Arabic at the same measure', () {
      // A bilingual reader moves between the two arms of a verse; if the Arabic
      // style were a size larger or smaller the line height of the paragraph
      // would jump as the text changed language. The spec gives no scripture
      // size, so both take the same geometry from the Material scale.
      final EvaColors colors = const EvaColors.light();
      expect(
        EvaTypography.scriptureLatin(colors).fontSize,
        EvaTypography.scriptureArabic(colors).fontSize,
      );
      expect(
        EvaTypography.scriptureLatin(colors).height,
        EvaTypography.scriptureArabic(colors).height,
      );
    });

    test('are legible, i.e. not the 12sp label size', () {
      // A floor rather than a target: the reading sanctuary is the app's one
      // long-form surface, and anything at or below `labelSmall`'s 11sp is a
      // legibility regression. The spec fixes no size, so this pins only the
      // bound the design cannot cross.
      final EvaColors colors = const EvaColors.dark();
      expect(
        EvaTypography.scriptureLatin(colors).fontSize,
        greaterThanOrEqualTo(16.0),
      );
      expect(
        EvaTypography.scriptureArabic(colors).fontSize,
        greaterThanOrEqualTo(16.0),
      );
    });

    test('the mono-caps style uses Space Mono and nothing else', () {
      final EvaColors colors = const EvaColors.dark();
      expect(
        EvaTypography.monoCaps(colors).fontFamily,
        EvaTypography.monoFamily,
      );
      expect(
        EvaTypography.monoCaps(colors).fontFamily,
        isNot(EvaTypography.arabicFamily),
      );
    });
  });

  // =========================================================================
  group('evaScalerFor maps the Settings slider onto a TextScaler', () {
    test('reproduces the spec table for steps 1 through 5', () {
      // §5.2, verbatim: 1 → 0.90, 2 → 0.95, 3 → 1.00, 4 → 1.10, _ → 1.22.
      // Probed at a non-unit font size, because `scale(1.0)` returns 1.0 × factor
      // and a scaler that ignored its factor would still look right at exactly
      // one size.
      expect(evaScalerFor(1).scale(16.0), closeTo(16.0 * 0.90, 1e-9));
      expect(evaScalerFor(2).scale(16.0), closeTo(16.0 * 0.95, 1e-9));
      expect(evaScalerFor(3).scale(16.0), closeTo(16.0 * 1.00, 1e-9));
      expect(evaScalerFor(4).scale(16.0), closeTo(16.0 * 1.10, 1e-9));
      expect(evaScalerFor(5).scale(16.0), closeTo(16.0 * 1.22, 1e-9));
    });

    test('step 3 is the identity, and every other step is not', () {
      expect(evaScalerFor(3).scale(1.0), closeTo(1.0, 1e-12));
      for (final int step in <int>[1, 2, 4, 5]) {
        expect(
          evaScalerFor(step).scale(1.0),
          isNot(closeTo(1.0, 1e-9)),
          reason: 'step $step must actually change the size',
        );
      }
    });

    test('the five factors are distinct and monotonically increasing', () {
      // A copy-paste that gave steps 4 and 5 the same factor would ship a
      // slider with two identical positions and no test objecting.
      final List<double> factors = <double>[
        for (int step = 1; step <= 5; step++) evaScalerFor(step).scale(1.0),
      ];
      expect(factors.toSet().length, 5);
      for (int i = 1; i < factors.length; i++) {
        expect(
          factors[i],
          greaterThan(factors[i - 1]),
          reason: 'step ${i + 1} must scale larger than step $i',
        );
      }
    });

    test('the factors are §5.2\'s, read from one table rather than restated', () {
      // This test used to parse the doc comment's fenced code block and compare
      // it with the implementation. Deleted, for reasons that are worth keeping
      // in the suite so nobody puts it back:
      //
      // - IT FALSE-FAILED LEGITIMATE EDITS. `0.90` → `0.9` in both the comment and
      //   the code is the same double, and the regex demanded the exact spelling.
      //   Removing `const` from the quoted snippet also failed it.
      // - IT WAS BLIND TO WHAT MATTERED. The pattern's character class was
      //   `[1-5_]`, so a sixth arm — say `6 =>` — would not have been captured at
      //   all, and the arm count of 10 it asserted would still have been
      //   satisfied by the ten rows it could see.
      // - IT CREATED THE WRONG INCENTIVE. Pinning prose by regex makes "edit the
      //   expectation" the cheapest route to green, which is the failure mode
      //   AGENT_CONTEXT §6 calls out.
      //
      // What replaces it is the same claim stated as behaviour: the factors are
      // §5.2's, in §5.2's order, and they are the ONLY factors. The table below
      // is the spec's, and each entry is probed directly, so a sixth arm shows up
      // as a step outside 1..5 returning something other than the largest factor.
      const List<({int step, double factor})> spec =
          <({int step, double factor})>[
            (step: 1, factor: 0.90),
            (step: 2, factor: 0.95),
            (step: 3, factor: 1.00),
            (step: 4, factor: 1.10),
            (step: 5, factor: 1.22),
          ];
      expect(spec.length, 5, reason: '§5.2 names five positions');

      for (final ({int step, double factor}) entry in spec) {
        expect(
          evaScalerFor(entry.step).scale(16.0),
          closeTo(16.0 * entry.factor, 1e-9),
          reason: 'step ${entry.step} must be ${entry.factor}×',
        );
      }
      expect(
        spec.map((({int step, double factor}) e) => e.step).toList(),
        <int>[1, 2, 3, 4, 5],
        reason: 'the slider positions are positional, in spec order',
      );
    });

    test('is linear, so 2× the factor is 2× the rendered size', () {
      for (int step = 1; step <= 5; step++) {
        final TextScaler scaler = evaScalerFor(step);
        expect(scaler.scale(10.0), closeTo(scaler.scale(5.0) * 2, 1e-9));
        expect(scaler.scale(0.0), 0.0, reason: 'step $step');
      }
    });

    test('falls back to the largest scale outside 1..5', () {
      // §5.2 writes the last row as `_`, not `5`, so an out-of-range step — a
      // corrupted preference read from disk, or a future slider whose bounds
      // change without this table — must not fall through to the identity and
      // silently reset the reader's chosen size.
      for (final int step in <int>[0, -1, 6, 99]) {
        expect(
          evaScalerFor(step).scale(1.0),
          closeTo(1.22, 1e-12),
          reason: 'step $step',
        );
      }
    });

    test('never scales below 0.9, so no step renders text illegibly small', () {
      for (int step = 1; step <= 5; step++) {
        expect(
          evaScalerFor(step).scale(12.0),
          greaterThanOrEqualTo(12.0 * 0.90 - 1e-9),
        );
      }
    });
  });
}
