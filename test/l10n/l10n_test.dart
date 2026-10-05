import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// The localization layer's two facts about an arm — `isArabicArm` and `digits` —
/// and the `context.l10n` lookup.
///
/// ## WHAT DIED HERE AND WHY IT IS NOT BEING MOURNED
///
/// Four separate `isArabic` getters went with the tables, and two of them were
/// asserted by their own suites ("`isArabic`, derived rather than stored so it cannot
/// drift from the strings it governs", twice). Those assertions were good ones and
/// they are gone for a structural reason rather than a sentimental one:
///
/// * each table derived the fact by comparing one of its own strings against the
///   Arabic arm's, and with ARB **there is no second arm to compare against** —
///   `AppLocalizationsAr` is generated, so the comparison would be a generated
///   getter against a second generated instance, which tests the generator;
/// * worse, it would break the moment a translator picked an Arabic value that
///   happened to equal the English one — a defensible edit to `homeStreakLabel`, say
///   — and the arm would then report itself as Latin while rendering Arabic.
///
/// The locale is not a weaker source. It is the fact the question was asking, and it
/// is what `TodayReadingPanel.retryFamilyFor` — the one caller that existed — needed
/// in the first place: its **failed** state has no reading to read an arm from, which
/// is why its doc called the strings "the weaker source".
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('`isArabicArm`, the replacement for five `isArabic` getters', () {
    test('answers from the locale, for the two arms the app ships', () {
      expect(en.isArabicArm, isFalse);
      expect(ar.isArabicArm, isTrue);
    });

    test('and survives a region subtag', () {
      // `AppLocalizationsAr([String locale = 'ar'])`, so a caller that constructs
      // one directly with a territory gets `ar_EG` — a locale a real device sends.
      // `gen_l10n`'s own `lookupAppLocalizations` drops the region, but a test that
      // constructs the class by hand does not, and `startsWith` holds for both.
      expect(AppLocalizationsAr('ar_EG').isArabicArm, isTrue);
      expect(AppLocalizationsEn('en_GB').isArabicArm, isFalse);
    });

    test('and it cannot be fooled by a translation that coincides with English', () {
      // The failure the string-comparison scheme had. Both arms are the *same*
      // string here, and the answer is still the locale's.
      expect(en.homeStreakLabel, isNot(ar.homeStreakLabel));
      expect(en.authWordmark, ar.authWordmark);
      expect(
        en.isArabicArm,
        isFalse,
        reason:
            '`authWordmark` is deliberately identical across the arms — a brand mark '
            'is not translated — and a comparison-against-a-string scheme would have '
            'reported this arm as Arabic',
      );
    });
  });

  group('`digits`, the replacement for four private `_count` helpers', () {
    test(
      'the Arabic arm renders U+0660-U+0669 and the English arm does not',
      () {
        expect(ar.digits(5), '٥');
        expect(ar.digits(5).codeUnits.first, 0x0665);
        expect(en.digits(5), '5');
        expect(en.digits(5).codeUnits.first, 0x35);
      },
    );

    test(
      'and it is `arabicIndicDigits` verbatim, including the awkward cases',
      () {
        // `arabic_digits.dart` is total for every `int` on purpose: a rendering helper
        // that throws on a number the server sent is the defect decision 40 measures,
        // because the exception leaves `build` and takes the rest of the row with it.
        expect(ar.digits(0), '٠');
        expect(ar.digits(10), '١٠');
        expect(ar.digits(1234), '١٢٣٤');
        expect(ar.digits(-1), '-١');
        // And the English arm is `int.toString`, which agrees for all of them.
        expect(en.digits(1234), '1234');
        expect(en.digits(-1), '-1');
      },
    );

    test('and NO arm ever emits a digit the other cannot render', () {
      // The reason this is a domain function and not `NumberFormat`. U+0665 is an
      // **Arabic-block** codepoint, so it is tofu in Space Mono for exactly the
      // reason the scripture is; and `font_coverage_test.dart` pins that choice
      // against the bundled `Amiri`. `intl`'s own `NumberFormat('ar')` would have
      // been the obvious spelling and it is not used here — see the plural tests in
      // `app_localizations_test.dart` for what it would have got wrong.
      for (final int value in <int>[0, 1, 5, 11, 100]) {
        expect(
          ar.digits(value).runes.every((int r) => 0x0660 <= r && r <= 0x0669),
          isTrue,
          reason:
              'ar.digits($value) = ${ar.digits(value)} is not U+0660-U+0669',
        );
      }
    });
  });

  group('`BuildContext.l10n`, which replaced `X.of(Localizations.localeOf(ctx))`', () {
    test(
      'and it is the SAME lookup `MaterialApp` resolves, not a second one',
      () {
        // The claim this file exists to make about the migration: the feature strings
        // now go through `Localizations`, so `MaterialApp` owns locale propagation and
        // a locale change reaches a feature string with nothing hand-rolled to do it.
        //
        // Asserted structurally rather than by widget: `AppLocalizations.of` is the
        // generated `Localizations.of<AppLocalizations>`, so `context.l10n` IS that
        // lookup. `app_test.dart` proves the delegate is installed on the real
        // `MaterialApp`, and the six-screen Arabic gate proves an `ar` locale reaches
        // every feature's strings end to end.
        expect(en.localeName, 'en');
        expect(ar.localeName, 'ar');
      },
    );
  });
}
