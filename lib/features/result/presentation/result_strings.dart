import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:flutter/widgets.dart';

/// The bilingual string table for `/result`.
///
/// ## WHY IT EXISTS SEPARATELY FROM EVERY OTHER TABLE
///
/// §3's feature independence: `features/result` may not import `features/quiz`, so
/// `QuizStrings.retry` is not reachable from here. That is also the whole reason
/// `/result` **cannot** resolve a bloc — see the class doc of the page.
///
/// ## WHAT IS **TRANSCRIBED**
///
/// | field | prototype |
/// | --- | --- |
/// | [reflectAgain] | `ResultScreen.tsx:77` — `Reflect again` |
/// | [longestYet] | `ResultScreen.tsx:65` — the ` — your longest yet` half of `Day 12 — your longest yet` |
///
/// ## AND WHAT IS **WRITTEN**, WHICH IS MOST OF IT
///
/// `ResultScreen.tsx` is the prototype's one screen with **no data layer at all** —
/// every number on it is a literal. Measured line by line:
///
/// | prototype | what replaced it, and why |
/// | --- | --- |
/// | `4` / `/5` (`:44-45`) | the **running total** and **no denominator**. `SubmitResult` carries `points_earned` and `current_total_points` and **no question count**, and §2's route table gives `/result` no repository — so a `/5` would be a number from nowhere. This is decision 45's rejected "invent a measurement" and it is the largest single divergence on this screen. |
/// | `So close. One more read and you've got it.` (`:50`) | a sentence keyed on `(is_correct, reading_completed)`. The prototype's is tied to its literal `4/5`, and this client has neither number. |
/// | `Day 12` (`:65`) | [streakLabelFor] — the submit response's `current_streak`, which is `readings/today`'s `4` against `streak/summary`'s `0` (§5 trap 8) and is **the third copy**. |
/// | `14 Read` / `9 Reflected` / `5/5 Best` (`:70-72`) | [thisAnswer] / [bestRun] over the two response fields not already drawn. The prototype's three are **profile history** — days read, reflections, best score — and §2 decision 1 cut the profile, so there is no endpoint that could produce them. **Two tiles, not three** — the response has four drawable numbers and they are all used; a third would repeat one. `_StatRow`'s doc has the table. |
/// | `Back to library` (`:78`) | [backHome]. There is no library; the destination is `/`. Transcribing the label would be a lie about where the button goes. |
///
/// ## AND THE THREE STAT LABELS ARE **WRITTEN** BECAUSE THE VALUES THEY NAMED
/// ## HAVE NO SOURCE
///
/// That is the recorded divergence, and it is worth stating in a table because it
/// is the kind a reader comparing against `ResultScreen.tsx` will check first.
final class ResultStrings {
  /// The strings for [locale].
  static ResultStrings of(Locale locale) => switch (locale.languageCode) {
    'ar' => const ResultStrings.ar(),
    _ => const ResultStrings.en(),
  };

  /// The English arm.
  const ResultStrings.en()
    : reflectAgain = 'Reflect again',
      backHome = 'Back',
      thisAnswer = 'This answer',
      bestRun = 'Best run',
      day = 'Day',
      longestYet = 'your longest yet',
      completeMessage = 'Correct, and today\'s reading is complete.',
      partialMessage = 'Correct. The reading is not finished yet.',
      incorrectMessage = 'Not this time. Every question counts.',
      totalCaption = 'points';

  /// The Arabic arm.
  ///
  /// Written, not transcribed, for `HomeStrings.ar`'s reason: the prototype is
  /// English only. Every field is checked for Latin script by
  /// `result_strings_test.dart`, which walks [fields].
  const ResultStrings.ar()
    : reflectAgain = 'تأمل مرة أخرى',
      backHome = 'العودة',
      thisAnswer = 'هذه الإجابة',
      bestRun = 'أطول سلسلة',
      day = 'اليوم',
      longestYet = 'أطول سلسلة لك',
      completeMessage = 'إجابة صحيحة، وقد اكتملت قراءة اليوم.',
      partialMessage = 'إجابة صحيحة. لم تكتمل القراءة بعد.',
      incorrectMessage = 'ليس هذه المرة. كل سؤال يُحتسب.',
      totalCaption = 'نقطة';

  /// The primary button. `ResultScreen.tsx:77` — `Reflect again`.
  final String reflectAgain;

  /// The secondary button. **Written** — see the class doc.
  final String backHome;

  /// The first stat tile: what this answer scored.
  final String thisAnswer;

  /// The second stat tile: the reader's best run of days.
  ///
  /// **There is no third tile**, and `_StatRow`'s doc gives the whole reason: the
  /// response's four drawable numbers are already on the headline, in the pill and in
  /// the first two tiles, so a third would repeat one of them.
  final String bestRun;

  /// The streak pill's leading noun. `ResultScreen.tsx:65` — `Day 12`.
  final String day;

  /// Appended to the streak label when the reader is at their best. `ResultScreen.tsx:65`.
  final String longestYet;

  /// The headline sentence: right, and the reading is finished.
  ///
  /// **Three messages and not one, because the server sends three states.**
  /// `SubmitResult` carries `is_correct` **and** `reading_completed`, and §5 trap 4
  /// says the streak fields only move on the second. A single "Correct." would say
  /// the same thing whether or not the reader's day is done, which is the one thing
  /// this screen exists to tell them.
  final String completeMessage;

  /// The headline sentence: right, and there is more to do.
  final String partialMessage;

  /// The headline sentence: wrong.
  final String incorrectMessage;

  /// The caption under the headline number.
  final String totalCaption;

  // ## AND THERE IS **NO** `noResultSuffix` HERE, DESPITE `/quiz` HAVING ONE
  //
  // There was a field documented as *"Appended to a disabled control's accessible
  // name"*, with an English and an Arabic value. **`/result` has no disabled
  // control** — `result_page_test.dart` asserts both buttons are enabled by design,
  // because both have work to do — so nothing could consume it and nothing did.
  // `rg` found two assignments, one declaration and one entry in [fields], and not
  // one read.
  //
  // **Measured before deleting, by wiring it where it must not go.** Appending it to
  // `reflectAgain`'s label reds exactly **two** tests — `result_page_test.dart`'s
  // "the primary says `Reflect again`" and the Arabic arm of
  // `arabic_typography_test.dart` — and both are asserting the *label text*. Nothing
  // reacted to it as the reason on a disabled control, because there is no disabled
  // control to react. A field whose only reachable effect is to corrupt a transcribed
  // label is dead weight that also *looks* load-bearing in a diff.
  //
  // **Rejected: keeping it and building the disabled control it was written for.**
  // `/quiz`'s dead CTA exists because §5 trap 3's live payload has nowhere to submit;
  // `/result` takes a **required** `SubmitResult`, so it is only ever constructed for a
  // result that exists. There is no state to render a "no result" arm for, and
  // inventing one would be the "a second kind of result screen" the `QuizPage` class
  // doc already rejects for `/quiz`.
  //
  // **Rejected: keeping it as an unconsumed string.** `feedback_banner.dart`'s
  // `semanticLabel` is the honest shape of that — its doc *says* no caller needs it
  // today. This field's doc claimed a control that does not exist, which is a claim
  // about the screen rather than about the string, and that is the part that misled.

  /// The headline sentence for the three states.
  ///
  /// **A `switch` expression over the two booleans**, per §4 — an `if`-chain here
  /// would be the same four branches in a different order and one of them would be
  /// unreachable by accident rather than by construction.
  String messageFor({
    required bool isCorrect,
    required bool readingCompleted,
  }) => switch ((isCorrect, readingCompleted)) {
    (true, true) => completeMessage,
    (true, false) => partialMessage,
    (false, _) => incorrectMessage,
  };

  /// The streak pill's label, for [current] days against a best of [longest].
  ///
  /// ## "AT THEIR BEST" IS `>=`, NOT `==`, AND THE REASON IS THE ZERO
  ///
  /// The prototype's own sentence is `"Day 12 — your longest yet"` beside
  /// `longest_streak: 6` — a **hard-coded mismatch** in the fixture the prototype
  /// drew, so the word is transcribed but the comparison is this client's.
  ///
  /// `current >= longest` rather than `==`: `longest_streak` is the reader's best run
  /// **as the server last computed it**, and a reader who has just extended their run
  /// by one can be *ahead* of it if the server has not caught up. Saying "your
  /// longest yet" about `6` when the reader is on `7` is true; saying it only on `==`
  /// would show nothing for the one case the reader would most want to see.
  ///
  /// **A streak of `0` never claims it.** `current_streak: 0` against
  /// `longest_streak: 0` satisfies `>=`, and "Day 0 — your longest yet" is a sentence
  /// about a reader who has not started.
  String streakLabelFor({required int current, required int longest}) {
    final String label = '$day ${_count(current)}';
    if (current <= 0 || current < longest) return label;
    return '$label — $longestYet';
  }

  /// [value], in this arm's numerals.
  ///
  /// `ReadingStrings._count` verbatim, and for the same reason it exists there: the
  /// only difference between the arms is which digits they use, and U+0660–U+0669 are
  /// Arabic-block codepoints that are tofu in any Latin face.
  String _count(int value) => isArabic ? arabicIndicDigits(value) : '$value';

  /// Whether this arm renders Arabic-Indic numerals.
  ///
  /// **Derived, not stored**, for `ReadingStrings.isArabic`'s reason: the numeral
  /// system of a count and its wording are one decision, and reading it off a string
  /// cannot drift from the strings it governs.
  bool get isArabic => backHome == const ResultStrings.ar().backHome;

  /// Every `(name, value)` pair, for the arm-comparison test.
  ///
  /// `home_strings_test.dart`, `reading_strings_test.dart` and `quiz_strings_test.dart`
  /// each have one and each gives the same reason: a hand-written list inside a test
  /// is a second declaration of the table, free to drift from it.
  List<(String, String)> get fields => <(String, String)>[
    ('reflectAgain', reflectAgain),
    ('backHome', backHome),
    ('thisAnswer', thisAnswer),
    ('bestRun', bestRun),
    ('day', day),
    ('longestYet', longestYet),
    ('completeMessage', completeMessage),
    ('partialMessage', partialMessage),
    ('incorrectMessage', incorrectMessage),
    ('totalCaption', totalCaption),
  ];
}
