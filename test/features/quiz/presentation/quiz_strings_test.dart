import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/quiz/presentation/quiz_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bilingual table for `/quiz`.
///
/// `home_strings_test.dart` and `reading_strings_test.dart` have this suite's shape
/// and both give the same reason for it: **a hand-written list of Arabic literals in
/// a test is a second copy of the corpus**, and the failure then reads as "the
/// widget rendered the wrong string" rather than "the test typed the wrong string".
/// Decision 79 recorded four wrong Arabic literals on the first run of a list built
/// that way.
///
/// So every assertion below is driven by [QuizStrings]'s own values or by the table
/// it is compared against, and the one place a literal appears is a place where the
/// literal **is** the claim.
void main() {
  const QuizStrings en = QuizStrings.en();
  const QuizStrings ar = QuizStrings.ar();

  group('the two arms declare the same fields', () {
    test('and the field list names every one', () {
      // The comparison is the property a reader would notice; the completeness is
      // what makes the comparison total. A field added to the table without a row
      // here would be invisible, which is the drift `home_strings_test.dart`'s
      // `fields` accessor exists to prevent.
      expect(
        en.fields.map(((String, String) f) => f.$1).toSet(),
        ar.fields.map(((String, String) f) => f.$1).toSet(),
      );
      expect(
        en.fields,
        hasLength(15),
        reason:
            'one row per field, or the comparison '
            'above is over an incomplete set',
      );
    });

    for (final ((String, String) field) in en.fields) {
      test('`${field.$1}` is non-empty on both arms', () {
        expect(field.$2, isNotEmpty);
        expect(
          ar.fields.firstWhere(((String, String) f) => f.$1 == field.$1).$2,
          isNotEmpty,
        );
      });
    }
  });

  group('the ARABIC arm carries no Latin script', () {
    // The whole reason decision 79 exists. `containsLatinLetters` is the check, and
    // it is deliberately **not** `containsArabic` — the failure this suite exists to
    // prevent is English left in the Arabic arm, not a missing translation.
    for (final ((String, String) field) in en.fields) {
      test('`${field.$1}` is free of ASCII letters', () {
        final String value = ar.fields
            .firstWhere(((String, String) f) => f.$1 == field.$1)
            .$2;
        expect(
          value.codeUnits.where(
            (int unit) =>
                (unit >= 0x41 && unit <= 0x5A) ||
                (unit >= 0x61 && unit <= 0x7A),
          ),
          isEmpty,
          reason:
              '`$value` contains Latin script. The Arabic arm is checked by '
              '`arabic_typography_test.dart` for its FAMILY; this is the other half '
              '— a string that is Arabic but was mistyped as English would pass it.',
        );
      });
    }
  });

  group('`questionProgress`', () {
    test('uses the session\'s own numbers, not the prototype\'s 2 and 5', () {
      expect(en.questionProgress(2, 5), 'Question 2 of 5');
      // The prototype's literal happens to match here, so a second case with
      // different numbers is the one that holds it.
      expect(en.questionProgress(1, 1), 'Question 1 of 1');
      expect(en.questionProgress(7, 12), 'Question 7 of 12');
    });

    test(
      'and the ARABIC arm uses Arabic-Indic digits, for §5 trap 9\'s reason',
      () {
        // U+0660–U+0669 are Arabic-block codepoints, so a Western digit beside Arabic
        // text is a mixed-numeral line rather than a wrong number. `arabic_digits`'s
        // doc is the argument and `font_coverage_test.dart` is the gate.
        expect(ar.questionProgress(2, 5), 'السؤال ٢ من ٥');
        expect(ar.questionProgress(1, 1), 'السؤال ١ من ١');
      },
    );

    test('a zero total does not throw and does not say "1 of 0"', () {
      // `questionCount == 0` is reachable (recorded decision 50: an unreadable
      // question is **skipped**, so all four can be). The empty state renders
      // instead of this string, and the assertion is that the helper is still total.
      expect(en.questionProgress(1, 0), 'Question 1 of 0');
      expect(en.questionProgress(0, 0), 'Question 0 of 0');
    });

    test('a large count is not abbreviated', () {
      expect(en.questionProgress(1234, 5678), 'Question 1234 of 5678');
      expect(ar.questionProgress(1234, 5678), 'السؤال ١٢٣٤ من ٥٦٧٨');
    });
  });

  group('`optionLabel`, and the spoiler boundary as a string', () {
    test('before a check there is **no suffix at all**', () {
      // The boundary in one assertion. `quiz_page_test.dart` proves it on the
      // rendered tree and in the semantics tree; this proves the **word** is absent
      // from the string the card builds, so a page that passed the verdict in
      // anyway would have nothing to spell.
      expect(en.optionLabel(letter: 'A', text: 'Nicodemus'), 'A. Nicodemus');
      expect(
        en.optionLabel(letter: 'A', text: 'نيقوديموس', suffix: null),
        isNot(contains(en.correctSuffix)),
      );
      expect(
        en.optionLabel(letter: 'A', text: 'نيقوديموس', suffix: null),
        isNot(contains(en.incorrectSuffix)),
      );
    });

    test('after a check the suffix is there, and it is the caller\'s', () {
      expect(
        en.optionLabel(
          letter: 'A',
          text: 'Nicodemus',
          suffix: en.correctSuffix,
        ),
        'A. Nicodemus — correct answer',
      );
      expect(
        ar.optionLabel(
          letter: 'أ',
          text: 'نيقوديموس',
          suffix: ar.correctSuffix,
        ),
        'أ. نيقوديموس — الإجابة الصحيحة',
      );
    });

    test('an EMPTY suffix is treated as no suffix', () {
      // `String?` with `null` meaning "nothing" and `''` meaning "nothing" would
      // leave a caller that computed `''` producing `'A. Nicodemus — '`, which is a
      // visible trailing dash on every option. Coalesced here, once.
      expect(
        en.optionLabel(letter: 'A', text: 'Nicodemus', suffix: ''),
        'A. Nicodemus',
      );
    });

    test('the letter comes from the wire and is NOT validated', () {
      // §5 trap 10: the id the server hands out is `question-group-3`, and the
      // option keys come from the same payload. A client that checked the letter
      // would reject a request the backend accepts.
      expect(en.optionLabel(letter: 'Z', text: 'x'), 'Z. x');
      expect(en.optionLabel(letter: '', text: 'x'), '. x');
    });
  });

  group('`of`', () {
    test('resolves from the locale, and defaults to English', () {
      // `LoginStrings.of`'s rule, and the reason `app.dart` declaring exactly two
      // `supportedLocales` makes the default unreachable in production.
      expect(QuizStrings.of(const Locale('en')), same(en));
      expect(QuizStrings.of(const Locale('ar')), same(ar));
      expect(QuizStrings.of(const Locale('fr')), same(en));
      expect(QuizStrings.of(const Locale('en', 'US')), same(en));
    });

    test('and the two arms really do differ on it', () {
      // The reason `ofWord` is a field and not a constant. If it stopped differing
      // — a translator harmonising them — this test is what would notice that the
      // field could be a constant again.
      expect(en.ofWord, 'of');
      expect(ar.ofWord, 'من');
      expect(ar.questionProgress(2, 5), contains(ar.ofWord));
    });
  });

  group('the dead-control suffixes', () {
    test('both arms say WHY, not only that', () {
      // §14's disabled row. `LoginPage`'s four inert social buttons (recorded
      // decision 18) are the precedent, and the reason `/quiz` can ship a dead CTA
      // honestly: a reader who taps a button that does nothing is told nothing.
      expect(en.alreadyAnsweredSuffix, isNotEmpty);
      expect(en.unavailableSuffix, isNotEmpty);
      expect(ar.alreadyAnsweredSuffix, isNotEmpty);
      expect(ar.unavailableSuffix, isNotEmpty);
    });

    test('and they do not overlap the verdict words', () {
      // If `unavailableSuffix` contained "correct", the semantics assertion that
      // no node carries a verdict before a check would pass for the wrong reason on
      // a page that appended the suffix everywhere.
      expect(
        en.alreadyAnsweredSuffix.toLowerCase(),
        isNot(contains('correct')),
      );
      expect(en.unavailableSuffix.toLowerCase(), isNot(contains('correct')));
      expect(
        en.alreadyAnsweredSuffix.toLowerCase(),
        isNot(contains('incorrect')),
      );
    });
  });

  group('the family rule, which the table does **not** decide', () {
    test('no field carries a family, because the direction decides it', () {
      // Recorded decision 74: `arabicAware` resolves the arm from the ambient
      // `TextDirection` and **no constructor gained an argument**. A string table
      // with a family on it would be the second mechanism, and decision 75 records
      // that unifying the two means deleting one.
      for (final ((String, String) field) in en.fields) {
        expect(field.$2, isNot(contains(EvaTypography.arabicFamily)));
        expect(field.$2, isNot(contains(EvaTypography.uiFamily)));
        expect(field.$2, isNot(contains(EvaTypography.monoFamily)));
        expect(field.$2, isNot(contains(EvaTypography.displayFamily)));
      }
    });

    test('and `isArabic` is derived, so it cannot drift from the strings', () {
      expect(en.isArabic, isFalse);
      expect(ar.isArabic, isTrue);
    });
  });
}
