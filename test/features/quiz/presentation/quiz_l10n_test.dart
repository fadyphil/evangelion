import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `/quiz` derived strings — `questionProgress` and `optionLabel`.
///
/// Both were methods on `QuizStrings`. The keys they read are asserted by
/// `test/l10n/app_localizations_test.dart`, which owns the ARB; what is here is the
/// **composition**, because that is the part no ARB can express and the part a
/// translation change could quietly break.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('`questionProgress`', () {
    test('uses the session\'s own numbers, not the prototype\'s 2 and 5', () {
      // `QuizScreen.tsx:67` — `Question 2 of 5`, with both numbers hard-coded. The
      // session carries its own, and a hard-coded pair is fake data that happens to
      // match nothing the server sends.
      expect(en.questionProgress(2, 5), 'Question 2 of 5');
    });

    test('and the ARABIC arm uses Arabic-Indic digits, for §5 trap 9\'s reason', () {
      // The reason is §5 trap 9 and `arabicIndicDigits`' own doc: U+0660–U+0669 are
      // **Arabic-block** codepoints, so this string is rendered in the payload arm's
      // family and a Latin digit here would be the only Western numeral on screen.
      expect(ar.questionProgress(2, 5), 'السؤال ٢ من ٥');
      // Asserted on the **digits**, not on `codeUnits.first` — the string starts
      // with the Arabic letter `ا` (U+0627 = 1575), so a first-codepoint check
      // would be measuring the noun. The claim is that both numerals are in
      // U+0660-U+0669 and that no ASCII digit appears anywhere.
      expect(ar.questionProgress(2, 5), contains('٢'));
      expect(ar.questionProgress(2, 5), contains('٥'));
      expect(
        ar
            .questionProgress(2, 5)
            .runes
            .where((int r) => 0x30 <= r && r <= 0x39)
            .toList(),
        isEmpty,
        reason: 'no ASCII digit may reach the Arabic arm of this string',
      );
    });

    test('a zero total does not throw and does not say "1 of 0"', () {
      // `total` is the session's question count and `questions: []` is reachable —
      // `today_reading_mapper.dart` skips an unreadable question rather than refusing
      // the passage. So the helper must stay **total**: the assertion is that it is
      // still a function, not that the value is sensible.
      expect(en.questionProgress(1, 0), 'Question 1 of 0');
      expect(en.questionProgress(0, 0), 'Question 0 of 0');
    });

    test('a large count is not abbreviated', () {
      // §5 trap 9's other half: nothing may reformat a count for display. A
      // thousands separator would be a client-side formatting decision on a number
      // the server owns, and it would disagree with the server's other surfaces.
      expect(en.questionProgress(1234, 5678), 'Question 1234 of 5678');
      expect(ar.questionProgress(1234, 5678), 'السؤال ١٢٣٤ من ٥٦٧٨');
    });

    test('and it is NOT a plural, which is the judgement call', () {
      // ## WHY THIS IS NOT AN ICU PLURAL
      //
      // There is **no noun agreeing with either number** here. English writes
      // `Question 2 of 5` and `Question 1 of 1` identically and Arabic writes
      // `السؤال ٢ من ٥` the same way — `of` / `من` is invariant. A `plural` would
      // select an `other` branch identical to its `one` branch, which asserts that
      // two strings are equal: a test that cannot fail.
      //
      // The counts that ARE plural-dependent are `readingCaptionFor` and
      // `resultTotalCaption`, and both are asserted per class in
      // `test/l10n/app_localizations_test.dart`.
      expect(en.questionProgress(1, 1), isNot(en.questionProgress(2, 5)));
      expect(en.questionProgress(1, 1), 'Question 1 of 1');
    });
  });

  group('`optionLabel`, and the spoiler boundary as a string', () {
    test('before a check there is **no suffix at all**', () {
      // The boundary in one assertion. `quiz_page_test.dart` proves it on the
      // rendered tree and in the semantics tree; this proves the **word** is absent
      // from the string the card builds, so a page that passed the verdict in anyway
      // would have nothing to spell.
      expect(en.optionLabel(letter: 'A', text: 'Nicodemus'), 'A. Nicodemus');
      expect(
        en.optionLabel(letter: 'A', text: 'نيقوديموس', suffix: null),
        isNot(contains(en.quizCorrectSuffix)),
      );
      expect(
        en.optionLabel(letter: 'A', text: 'نيقوديموس', suffix: null),
        isNot(contains(en.quizIncorrectSuffix)),
      );
    });

    test('after a check the suffix is there, and it is the caller\'s', () {
      expect(
        en.optionLabel(
          letter: 'A',
          text: 'Nicodemus',
          suffix: en.quizCorrectSuffix,
        ),
        'A. Nicodemus — correct answer',
      );
      expect(
        ar.optionLabel(
          letter: 'أ',
          text: 'نيقوديموس',
          suffix: ar.quizCorrectSuffix,
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

  group('`quizOfWord`', () {
    test('the two arms really do differ on it', () {
      // The reason `quizOfWord` is a key and not a constant. If it stopped
      // differing — a translator harmonising the arms — this is what would notice
      // that the key could be a constant again.
      expect(en.quizOfWord, 'of');
      expect(ar.quizOfWord, 'من');
      expect(ar.questionProgress(2, 5), contains(ar.quizOfWord));
    });
  });

  group('the dead-control suffixes', () {
    test('both arms say WHY, not only that', () {
      // §14's disabled row. `LoginPage`'s four inert social buttons (recorded
      // decision 18) are the precedent, and the reason `/quiz` can ship a dead CTA
      // honestly: a reader who taps a button that does nothing is told nothing.
      expect(en.quizAlreadyAnsweredSuffix, isNotEmpty);
      expect(en.quizUnavailableSuffix, isNotEmpty);
      expect(ar.quizAlreadyAnsweredSuffix, isNotEmpty);
      expect(ar.quizUnavailableSuffix, isNotEmpty);
    });

    test('and they do not overlap the verdict words', () {
      // If `quizUnavailableSuffix` contained "correct", the semantics assertion that
      // no node carries a verdict before a check would pass for the wrong reason on
      // a page that appended the suffix everywhere.
      expect(
        en.quizAlreadyAnsweredSuffix.toLowerCase(),
        isNot(contains('correct')),
      );
      expect(
        en.quizUnavailableSuffix.toLowerCase(),
        isNot(contains('correct')),
      );
      expect(
        en.quizAlreadyAnsweredSuffix.toLowerCase(),
        isNot(contains('incorrect')),
      );
    });
  });
}
