import 'package:evangelion/features/result/presentation/result_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `/result` derived strings — `messageFor` and `streakLabelFor`.
///
/// Both were methods on `ResultStrings`. The keys are asserted by
/// `test/l10n/app_localizations_test.dart`; what is here is the composition, and both
/// are **decisions about the payload** — which is a Dart type, not a translation.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('`messageFor`, and the three states the server can send', () {
    test('right and finished, right and not, and wrong', () {
      // `SubmitResult` carries `is_correct` **and** `reading_completed`, and §5 trap
      // 4 says the streak fields only move on the second. A single "Correct." would
      // say the same thing whether or not the reader's day is done, which is the one
      // thing this screen exists to tell them.
      expect(
        en.messageFor(isCorrect: true, readingCompleted: true),
        en.resultCompleteMessage,
      );
      expect(
        en.messageFor(isCorrect: true, readingCompleted: false),
        en.resultPartialMessage,
      );
      expect(
        en.messageFor(isCorrect: false, readingCompleted: true),
        en.resultIncorrectMessage,
      );
    });

    test('and the three are genuinely different sentences', () {
      // If any two collapsed to the same value, the third state would be
      // indistinguishable on screen and the screen would lose the thing it exists to
      // say. Asserted by value rather than by identity, because the keys are
      // generated strings and only their content is a claim.
      final List<String> messages = <String>[
        en.resultCompleteMessage,
        en.resultPartialMessage,
        en.resultIncorrectMessage,
      ];
      expect(messages.toSet().length, 3);
      // And the wrong answer ignores `readingCompleted` entirely — a wrong answer on
      // a finished reading is still just wrong, and branching on the second boolean
      // there would invent a fourth sentence the server cannot produce.
      expect(
        en.messageFor(isCorrect: false, readingCompleted: true),
        en.messageFor(isCorrect: false, readingCompleted: false),
      );
    });

    test('and the Arabic arm routes to the same three keys', () {
      expect(
        ar.messageFor(isCorrect: true, readingCompleted: true),
        ar.resultCompleteMessage,
      );
      expect(
        ar.messageFor(isCorrect: false, readingCompleted: true),
        ar.resultIncorrectMessage,
      );
    });
  });

  group('`streakLabelFor`, and what "longest yet" is allowed to claim', () {
    test('behind the record it says nothing extra', () {
      // §5 trap 8: `readings/today`'s `4` against `streak/summary`'s `0`. The pill
      // is the **third** copy of a streak number in this app and the only one that
      // carries a claim about the reader's record.
      expect(
        en.streakLabelFor(current: 4, longest: 6),
        'Day 4',
        reason: 'and not `Day 4 — your longest yet`',
      );
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
        // `longest_streak` is the reader's best run **as the server last computed it**,
        // and a reader who has just extended their run by one can be *ahead* of it if
        // the server has not caught up. Saying "your longest yet" about `6` when the
        // reader is on `7` is true; saying it only on `==` would show nothing for the
        // one case the reader would most want to see.
        expect(
          en.streakLabelFor(current: 7, longest: 6),
          'Day 7 — your longest yet',
        );
      },
    );

    test('a streak of ZERO never claims it', () {
      // `current_streak: 0` against `longest_streak: 0` satisfies `>=`, and
      // "Day 0 — your longest yet" is a sentence about a reader who has not started.
      expect(en.streakLabelFor(current: 0, longest: 0), 'Day 0');
    });

    test('a negative count is total rather than throwing', () {
      // A rendering helper that throws on a number the server sent is the defect
      // decision 40 measures: the exception leaves `build` and takes the rest of the
      // row with it. `arabicIndicDigits` is total for the same reason.
      expect(en.streakLabelFor(current: -1, longest: 6), 'Day -1');
    });

    test('and the ARABIC arm uses Arabic-Indic digits for the count', () {
      // §5 trap 9 / `arabic_digits.dart`'s doc: U+0660 to U+0669 are Arabic-block
      // codepoints that are tofu in any Latin face.
      expect(ar.streakLabelFor(current: 4, longest: 6), 'اليوم ٤');
      expect(
        ar.streakLabelFor(current: 7, longest: 6),
        'اليوم ٧ — أطول سلسلة لك',
      );
      expect(ar.streakLabelFor(current: 0, longest: 0), 'اليوم ٠');
    });

    test(
      'and it is NOT a plural, which is the judgement call on this screen',
      () {
        // ## WHY `resultDay` STAYS A BARE NOUN
        //
        // The pill is a **label form** — `Day 12`, `اليوم ١٢` — not a count phrase.
        // English `Day 12` is correct for every count including one, and Arabic
        // `اليوم` with an Arabic-Indic numeral is the conventional label too.
        //
        // Making it a plural would render `Days 12` in English — **altering a
        // transcribed prototype string** (`ResultScreen.tsx:65`) to fix nothing, and
        // changing the pill's visual shape on every screen that shows a streak.
        //
        // The count on this screen that genuinely needed a plural was the score
        // caption, and `resultTotalCaption` is it — asserted per class in
        // `test/l10n/app_localizations_test.dart`. `readingCaptionFor` is the other.
        expect(en.streakLabelFor(current: 1, longest: 6), 'Day 1');
        expect(en.streakLabelFor(current: 2, longest: 6), 'Day 2');
        expect(
          en.streakLabelFor(current: 1, longest: 6),
          isNot(en.streakLabelFor(current: 2, longest: 6)),
          reason:
              'the count still differentiates — what does not change is the NOUN, '
              'which is the whole claim',
        );
      },
    );
  });

  group('the fields the prototype does **not** have', () {
    test('the `resultBackHome` label is exactly `Back`', () {
      // The prototype's label is `Back to library` (`ResultScreen.tsx:78`) and there
      // IS no library — AGENT_CONTEXT §2 decision 1 cut it, and the destination is
      // `/`. Transcribing the label would be a lie about where the button goes.
      expect(en.resultBackHome, 'Back');
      expect(en.resultBackHome, isNot(contains('library')));
      expect(ar.resultBackHome, isNot(contains('library')));
    });

    test('no field mentions the library, because §2 cut it', () {
      // The three prototype tiles are profile history — days read, reflections, best
      // score — and no endpoint could produce them.
      for (final String key in <String>[
        'resultReflectAgain',
        'resultBackHome',
        'resultThisAnswer',
        'resultBestRun',
        'resultDay',
        'resultLongestYet',
      ]) {
        expect(
          en.resultsFor(key),
          isNot(contains('library')),
          reason: 'en.$key mentions the library',
        );
      }
    });
  });
}

extension on AppLocalizationsEn {
  /// Reads one of this suite's keys off the generated class. A `switch` rather than a
  /// `Map` so a renamed key is a compile error instead of a silent `null`.
  String resultsFor(String key) => switch (key) {
    'resultReflectAgain' => resultReflectAgain,
    'resultBackHome' => resultBackHome,
    'resultThisAnswer' => resultThisAnswer,
    'resultBestRun' => resultBestRun,
    'resultDay' => resultDay,
    'resultLongestYet' => resultLongestYet,
    _ => throw StateError('no key named $key'),
  };
}
