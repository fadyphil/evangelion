import 'package:evangelion/features/result/presentation/result_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bilingual table for `/result`.
///
/// `quiz_strings_test.dart` has this suite's shape and gives its reason: **a
/// hand-written list of Arabic literals in a test is a second copy of the corpus**,
/// and decision 79 recorded four wrong ones on the first run of a list built that way.
/// So every assertion below is driven by the table's own values.
void main() {
  const ResultStrings en = ResultStrings.en();
  const ResultStrings ar = ResultStrings.ar();

  group('the two arms declare the same fields', () {
    test('and the field list names every one', () {
      expect(
        en.fields.map(((String, String) f) => f.$1).toSet(),
        ar.fields.map(((String, String) f) => f.$1).toSet(),
      );
      expect(
        en.fields,
        hasLength(10),
        reason:
            'one row per field, or the comparison '
            'above is over an incomplete set. It was 11 while a dead '
            '`noResultSuffix` was declared — the count is here precisely so a '
            'field cannot be added or dropped without the number moving',
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

      test('`${field.$1}` is free of ASCII letters on the ARABIC arm', () {
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
          reason: '`$value` contains Latin script',
        );
      });
    }
  });

  group('`messageFor`, and the three states the server can send', () {
    test('right and finished, right and not, and wrong', () {
      expect(
        en.messageFor(isCorrect: true, readingCompleted: true),
        en.completeMessage,
      );
      expect(
        en.messageFor(isCorrect: true, readingCompleted: false),
        en.partialMessage,
      );
      expect(
        en.messageFor(isCorrect: false, readingCompleted: true),
        en.incorrectMessage,
      );
      expect(
        en.messageFor(isCorrect: false, readingCompleted: false),
        en.incorrectMessage,
        reason:
            'the wrong arm ignores `reading_completed`, because finishing the '
            'reading with a wrong answer does not make the answer right',
      );
    });

    test('and the three are genuinely different sentences', () {
      expect(en.completeMessage, isNot(en.partialMessage));
      expect(en.completeMessage, isNot(en.incorrectMessage));
      expect(en.partialMessage, isNot(en.incorrectMessage));
      expect(ar.completeMessage, isNot(ar.partialMessage));
      expect(ar.completeMessage, isNot(ar.incorrectMessage));
    });
  });

  group('`streakLabelFor`, and what "longest yet" is allowed to claim', () {
    test('behind the record it says nothing extra', () {
      expect(en.streakLabelFor(current: 4, longest: 6), 'Day 4');
      expect(en.streakLabelFor(current: 77, longest: 90), 'Day 77');
    });

    test('on the record it does', () {
      expect(
        en.streakLabelFor(current: 6, longest: 6),
        'Day 6 — your longest yet',
      );
    });

    test(
      'ahead of the record it **also** does, which is why the test is `>=`',
      () {
        // `longest_streak` is what the server last computed, so a reader who has just
        // extended their run can be ahead of it. `==` would say nothing in exactly the
        // case the sentence is most true of.
        expect(
          en.streakLabelFor(current: 7, longest: 6),
          'Day 7 — your longest yet',
        );
      },
    );

    test('a streak of ZERO never claims it', () {
      // `0 >= 0` is true, and "Day 0 — your longest yet" is a sentence about a reader
      // who has not started.
      expect(en.streakLabelFor(current: 0, longest: 0), 'Day 0');
      expect(en.streakLabelFor(current: 0, longest: 6), 'Day 0');
      expect(
        en.streakLabelFor(current: 0, longest: 0),
        isNot(contains(en.longestYet)),
      );
    });

    test('and the ARABIC arm uses Arabic-Indic digits for the count', () {
      expect(ar.streakLabelFor(current: 4, longest: 6), 'اليوم ٤');
      expect(
        ar.streakLabelFor(current: 6, longest: 6),
        'اليوم ٦ — ${ar.longestYet}',
      );
    });

    test('a negative count is total rather than throwing', () {
      // Decision 40's lesson: a rendering helper that throws on a number the server
      // sent takes the rest of the row with it. `SubmitResultMapper` refuses a
      // negative streak, so this is unreachable from the wire — and "unreachable"
      // is exactly the recorded-decision-15 case, where a branch nothing can reach
      // was the thing that hid a defect.
      expect(en.streakLabelFor(current: -1, longest: 6), 'Day -1');
    });
  });

  group('`of`', () {
    test('resolves from the locale, and defaults to English', () {
      expect(ResultStrings.of(const Locale('en')), same(en));
      expect(ResultStrings.of(const Locale('ar')), same(ar));
      expect(ResultStrings.of(const Locale('fr')), same(en));
    });
  });

  group('the fields the prototype does **not** have', () {
    test('no field mentions the library, because §2 cut it', () {
      // `ResultScreen.tsx:78` writes `Back to library` and `/` is where the button
      // goes. A label naming a screen that does not exist is a §14-adjacent lie about
      // where the control leads, and `result_page_test.dart` asserts the word is
      // absent from the tree.
      for (final ((String, String) field) in en.fields) {
        expect(field.$2.toLowerCase(), isNot(contains('library')));
      }
    });

    test('and the `backHome` label is exactly `Back`', () {
      // **The divergence, pinned.** A reader comparing against `ResultScreen.tsx:78`
      // finds a different label; this is the assertion that says so in a place a
      // reviewer will run.
      expect(en.backHome, 'Back');
      expect(en.backHome, isNot('Back to library'));
    });
  });

  group('`isArabic`, derived rather than stored', () {
    test('so it cannot drift from the strings it governs', () {
      expect(en.isArabic, isFalse);
      expect(ar.isArabic, isTrue);
    });
  });
}
