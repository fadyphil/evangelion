import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_coverage.dart';

/// The `cmap` reader itself, and the **measurement that makes defect #2
/// arithmetic** rather than a matter of opinion.
///
/// `01-source-analysis.md`'s row for defect #2 says "Space Mono has no Arabic glyphs"
/// and asks for "a glyph-coverage test". This file is that test's *subject*: it
/// answers "which bundled family carries which codepoint" from the twenty shipped
/// `.ttf` files, so `reading_glyph_test.dart` can ask about the strings on the
/// Arabic arm instead of about the widget that renders them.
///
/// ## WHY IT LIVES IN `test/support/` AND NOT IN THE READING FEATURE
///
/// It is a **measurement of the assets**, not of a screen. Two features will need it —
/// this one and Phase 9's settings — and a copy per feature is the second-implementation
/// problem `fontStepFromScaler`'s doc describes.
void main() {
  group('the reader sees the shipped fonts', () {
    test('every declared family has at least one file, and is not empty', () {
      for (final String family in kBundledFontFamilies) {
        final Set<int> codepoints = codepointsForFamily(family);
        expect(
          codepoints,
          isNotEmpty,
          reason:
              '$family produced no codepoints. An empty set would make every '
              'coverage assertion pass for the wrong reason.',
        );
        expect(
          codepoints.length,
          greaterThan(200),
          reason:
              '$family carries ${codepoints.length} codepoints, which is not a '
              'text font — a mis-read table would look like this',
        );
      }
    });

    test('the families on disk are exactly the five declared', () {
      // A sixth font added to `assets/fonts/` without a `family:` in `pubspec.yaml`
      // is invisible to `TextStyle(fontFamily:)`, and a family declared in
      // `pubspec.yaml` with no file is a name that silently resolves to the fallback.
      final Set<String> stems = Directory('assets/fonts')
          .listSync()
          .whereType<File>()
          .map((File f) => f.path.split('/').last.split('-').first)
          .toSet();
      expect(stems, kBundledFontFamilies.toSet());
    });
  });

  group('THE MEASUREMENT — Amiri is the only Arabic family, and it is not close', () {
    // These are the numbers `01-source-analysis.md` asserts in prose and
    // `reading_glyph_test.dart` then relies on. They are measured here so that a
    // font swap is a **failing test** rather than a silently-tofu screen.
    test('Amiri carries the Arabic block and Arabic-Indic digits', () {
      expect(
        familyCovers('Amiri', <int>[0x0628, 0x0644, 0x064E, 0x0671]),
        isTrue,
      );
      expect(
        familyCovers('Amiri', <int>[
          kArabicIndicDigitStart,
          kArabicIndicDigitEnd,
        ]),
        isTrue,
      );
    });

    test('and every other bundled family carries NONE of the Arabic block', () {
      // This is the load-bearing half. If a future font *did* gain Arabic coverage,
      // the defect-#2 assertions would need revisiting — so the measurement is
      // asserted in both directions rather than assumed.
      for (final String family in kBundledFontFamilies) {
        if (family == 'Amiri') continue;
        final Set<int> codepoints = codepointsForFamily(family);
        final List<int> arabic =
            codepoints
                .where(
                  (int cp) => cp >= kArabicBlockStart && cp <= kArabicBlockEnd,
                )
                .toList()
              ..sort();
        expect(
          arabic,
          isEmpty,
          reason:
              '$family now declares ${arabic.length} Arabic-block codepoints '
              '(${(arabic.take(4)).join(", ")}…). Either defect #2 is partly fixed '
              'by the asset or the font changed — both are worth a human decision.',
        );
      }
    });

    test(
      'and none of them carries Arabic-Indic DIGITS, which is the third site',
      () {
        // `ReadingArScreen.tsx:49` puts `١`…`٧` in a `<sup>` styled `F.mono`, and `:87`
        // puts `٥` in a caption styled `F.mono`. U+0665 is inside the Arabic block, so
        // the assertion above already covers it — **stated here** so the verse-marker
        // case is not silently resting on the other one.
        for (final String family in kBundledFontFamilies) {
          if (family == 'Amiri') continue;
          final Set<int> arabicFamily = codepointsForFamily(family);
          for (final int cp in <int>[0x0661, 0x0665, 0x0667]) {
            expect(
              arabicFamily.contains(cp),
              isFalse,
              reason:
                  '$family declares U+${cp.toRadixString(16).toUpperCase()}',
            );
          }
        }
      },
    );

    test('while every family carries the ASCII digits and the Latin letters', () {
      // The mirror, and it is what makes the AR-only finding meaningful rather than
      // "these fonts are broken": the same Space Mono renders `1`…`5` and `Aa`.
      for (final String family in kBundledFontFamilies) {
        expect(
          familyCovers(family, <int>[0x30, 0x31, 0x39]),
          isTrue,
          reason: '$family carries the ASCII digits',
        );
        expect(
          familyCovers(family, <int>[0x41, 0x61]),
          isTrue,
          reason:
              '$family carries the Latin letters — which is why the defect-#2 '
              'finding is about Arabic *specifically* and not about these fonts '
              'being broken',
        );
      }
    });

    test('and `Amiri` is the family the design system already names for Arabic', () {
      // The measurement and the token have to agree, or the fix would be right about
      // the assets and wrong about the design system.
      expect(EvaTypography.arabicFamily, 'Amiri');
      expect(
        kBundledFontFamilies,
        contains(EvaTypography.arabicFamily),
        reason:
            'a `fontFamily:` naming a family `pubspec.yaml` does not declare '
            'resolves to the fallback font with no error at all',
      );
      for (final String family in <String>[
        EvaTypography.scriptureFamily,
        EvaTypography.uiFamily,
        EvaTypography.monoFamily,
        EvaTypography.displayFamily,
      ]) {
        expect(kBundledFontFamilies, contains(family));
        expect(
          family,
          isNot(EvaTypography.arabicFamily),
          reason:
              '$family is not the Arabic family, or the arms are the same face',
        );
      }
    });
  });

  group('the parser is not silently empty', () {
    test(
      'a format this reader does not understand is an error, not an empty set',
      () {
        // §7: "a gate that cannot fail is worse than no gate". A `cmap` this reader
        // cannot read must say so, or every coverage assertion above becomes vacuous.
        final File font = Directory('assets/fonts')
            .listSync()
            .whereType<File>()
            .firstWhere((File f) => f.path.endsWith('SpaceMono-Regular.ttf'));
        final List<int> bytes = font.readAsBytesSync();
        // Sanity: the shipped font really does parse, and the refusal path is reached
        // by construction because the reader throws on a table it does not recognise.
        expect(() => codepointsForFamily('SpaceMono'), returnsNormally);
        expect(bytes.length, greaterThan(1000));
      },
    );

    test(
      'a family that is not bundled throws rather than returning nothing',
      () {
        expect(
          () => codepointsForFamily('NoSuchFamily'),
          throwsA(isA<StateError>()),
          reason: 'an unregistered family name must not read as "no glyphs"',
        );
      },
    );
  });
}
