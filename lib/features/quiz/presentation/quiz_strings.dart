import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:flutter/widgets.dart';

/// The bilingual string table for `/quiz`, and the two halves of it.
///
/// ## WHY IT IS ITS OWN TABLE AND NOT A FIFTH ARM OF `ReadingStrings`
///
/// §3's feature independence: `features/quiz` may not import `features/reading`, so
/// reusing `ReadingStrings.back` would be **Gate 2**. The tables are separate by
/// rule, not by taste — the same duplication `HomeStrings` pays for the same
/// reason, and `home_strings.dart` is the precedent.
///
/// ## WHAT IS **TRANSCRIBED**, LINE BY LINE
///
/// | field | prototype |
/// | --- | --- |
/// | [checkAnswer] | `QuizScreen.tsx:127` — `Check answer` |
/// | [nextQuestion] | `QuizScreen.tsx:127` — `Next question` |
/// | [questionProgress] | `QuizScreen.tsx:67` — `Question 2 of 5` |
///
/// That is all, and the shortness is the finding: the prototype's other three strings
/// are **fake data or invented states**.
///
/// ## AND THE FOUR THAT ARE **WRITTEN**, WITH THE REASON EACH
///
/// | string | why not transcribed |
/// | --- | --- |
/// | [exit] | `QuizScreen.tsx:46-50` is a `<button>` around a bare `<svg>` cross with **no label at all** — §14's first row. The same obligation that forced `ReadingStrings.back` forces this. |
/// | [seeResults] | the prototype's CTA is `{checked ? 'Next question' : 'Check answer'}` — there is **no terminal state**, because the prototype has exactly one hard-coded question. |
/// | [verdictCorrect] / [verdictIncorrect] | `QuizScreen.tsx:116` reads "Exactly. Light — before anything else.", which describes **the prototype's own invented option set** and this client's question is a different one. Transcribing it would put a claim about the wrong passage on the screen. |
/// | [noQuestionsTitle] / [noQuestionsMessage] | `questions: []` is reachable — `today_reading_mapper.dart` **skips** an unreadable question rather than refusing the passage (recorded decision 50), and decision 70 already gates `/reading`'s CTA on `questionCount > 0`. The prototype has no such state. |
///
/// `ErrorView.retryLabel` is the precedent for all of them: a hard-coded English
/// string inside `core/` is the half-translated UI this app exists not to ship, so
/// the wording lives here and the design-system widget takes the caller's.
///
/// ## AND TWO OF THEM CARRY THE **REASON A CONTROL IS DEAD**
///
/// [alreadyAnsweredSuffix] and [unavailableSuffix] are §14's disabled row: a reader
/// has to be told *why* a control cannot be pressed, not only that it cannot.
/// `LoginPage`'s four inert social buttons (recorded decision 18) and
/// `AppTopBar`'s avatar (decision 32) are the precedent, and they are the reason
/// `/quiz` can ship a dead CTA honestly at all — see `QuizState.cta`.
final class QuizStrings {
  /// The strings for [locale].
  static QuizStrings of(Locale locale) => switch (locale.languageCode) {
    'ar' => const QuizStrings.ar(),
    _ => const QuizStrings.en(),
  };

  /// The English arm.
  const QuizStrings.en()
    : exit = 'Close',
      progress = 'Question',
      ofWord = 'of',
      checkAnswer = 'Check answer',
      nextQuestion = 'Next question',
      seeResults = 'See results',
      correctSuffix = 'correct answer',
      incorrectSuffix = 'your answer, incorrect',
      verdictCorrect = 'Correct.',
      verdictIncorrect = 'Not this time.',
      alreadyAnsweredSuffix =
          'already answered, so it cannot be submitted again',
      unavailableSuffix = 'there is no answer to show',
      retry = 'Try again',
      noQuestionsTitle = 'Nothing to reflect on',
      noQuestionsMessage = "Today's reading came with no questions to answer.";

  /// The Arabic arm.
  ///
  /// Written, not transcribed: `HomeStrings.ar` and `ReadingStrings.ar` say the
  /// same, and the reason is that the prototype is English only. Every field is
  /// checked for Latin script by this suite, which walks [fields].
  const QuizStrings.ar()
    : exit = 'إغلاق',
      progress = 'السؤال',
      ofWord = 'من',
      checkAnswer = 'تحقق من الإجابة',
      nextQuestion = 'السؤال التالي',
      seeResults = 'اعرض النتيجة',
      correctSuffix = 'الإجابة الصحيحة',
      incorrectSuffix = 'إجابتك غير صحيحة',
      verdictCorrect = 'إجابة صحيحة.',
      verdictIncorrect = 'ليس هذه المرة.',
      alreadyAnsweredSuffix = 'تمت الإجابة عنها، فلا يمكن إرسالها مجددًا',
      unavailableSuffix = 'لا توجد إجابة لعرضها',
      retry = 'حاول مرة أخرى',
      noQuestionsTitle = 'لا شيء للتأمل فيه',
      noQuestionsMessage = 'لا تحتوي قراءة اليوم على أسئلة للإجابة عنها.';

  /// The close control's accessible name. `QuizScreen.tsx:46-50` has no label.
  final String exit;

  /// `ProgressBeads`' accessible-name prefix. See its own `semanticLabel`.
  final String progress;

  /// The word between the two counts in [questionProgress].
  ///
  /// **`ofWord` and not `of`**, because `of` is taken by the static
  /// [QuizStrings.of] locale lookup — a collision Dart rejects, which is the right
  /// outcome and the reason the field carries a slightly longer name rather than the
  /// static one being renamed.
  ///
  /// **A field and not a constant**, because the two arms genuinely differ — `of`
  /// against `من` — and a constant would have had to be a `switch` over a private
  /// anchor object to stay `const`, which is more machinery than the string is
  /// worth. `ReadingStrings._space` is a constant because both arms spell the space
  /// the same way; this is the other case, and the difference is the reason.
  final String ofWord;

  /// The CTA before the answer is graded. `QuizScreen.tsx:127`.
  final String checkAnswer;

  /// The CTA after the answer is graded, with a question still to come.
  final String nextQuestion;

  /// The CTA on the last question. **Written** — see the class doc.
  final String seeResults;

  /// Appended to the correct option's accessible name once it is revealed.
  ///
  /// **The spoiler boundary's vocabulary, and it is bilingual.** The boundary itself
  /// is `QuizPage`'s; this is the word that makes it visible to a screen reader.
  ///
  /// ## THE CITATION HERE USED TO NAME A FILE THAT **DID NOT EXIST**
  ///
  /// This doc said `quiz_accessibility_test.dart` asserts the string is in the
  /// semantics tree **only after** a check. There is no such file, and there never
  /// was — so the citation was a pointer a reader would follow and find nothing.
  ///
  /// **The claim is nevertheless real, and it is held two files over**:
  /// `quiz_page_test.dart`'s *"before the reader commits to an answer"* group asserts
  /// no node's label carries this string, and its *"and the SEMANTICS tree carries the
  /// verdict the card colours carry"* test asserts exactly one does after a check.
  /// Both read `QuizOptionCard`'s merged semantics node, which is where this string
  /// lands.
  ///
  /// **Not corrected by creating the file.** A second `/quiz` test file whose subject
  /// is a subset of `quiz_page_test.dart`'s spoiler groups would give the boundary two
  /// homes and make "nothing leaks before a check" a claim about whichever file a
  /// reader opened. §3's "one implementation of one invariant" is the rule; the fix for
  /// a wrong citation is the right citation.
  final String correctSuffix;

  /// Appended to the chosen-but-wrong option's accessible name, once revealed.
  final String incorrectSuffix;

  /// The feedback banner's text on a correct answer. **Written** — see the class doc.
  final String verdictCorrect;

  /// The feedback banner's text on a wrong answer. **Written** — see the class doc.
  final String verdictIncorrect;

  /// Appended to an option's accessible name when the wire says it is answered.
  final String alreadyAnsweredSuffix;

  /// Appended to the CTA's accessible name when there is nothing to submit.
  final String unavailableSuffix;

  /// `ErrorView.retryLabel`.
  final String retry;

  /// The empty state's heading.
  final String noQuestionsTitle;

  /// The empty state's body.
  final String noQuestionsMessage;

  /// `Question <current> of <total>` — `QuizScreen.tsx:67`, with the prototype's
  /// hard-coded `2` and `5` replaced by the session's own numbers.
  ///
  /// ## THE **PROTOTYPE'S** NUMBER IS A LIE AND THE ARMS USE DIFFERENT DIGITS
  ///
  /// `ReadingEnScreen.tsx:89`'s `5 questions` was the same kind of literal and
  /// `ReadingStrings.captionFor`'s doc records what happened to it. So neither number
  /// is transcribed: `current` and `total` come from the session.
  ///
  /// The Arabic arm converts to **Arabic-Indic** digits for the same reason
  /// `ReadingStrings._count` does, and with the same consequence: U+0660–U+0669 are
  /// Arabic-block codepoints and are tofu in Space Mono. This string is rendered in
  /// the payload arm's family, which is why that matters here.
  String questionProgress(int current, int total) =>
      '$progress ${_count(current)} $ofWord ${_count(total)}';

  /// An option's accessible name: the letter, the text, and any verdict.
  ///
  /// ## **THE VERDICT IS A PARAMETER AND NOT A BRANCH HERE**
  ///
  /// [suffix] is `null` before the reader has checked, and that is the whole of the
  /// spoiler boundary as a string. A method with an `if (isCorrect)` inside would be
  /// a second place the rule lives — and the rule's importance is precisely that it
  /// has one place. `QuizOptionCard` decides the suffix and this method spells it,
  /// so `quiz_page_test.dart` can assert that **no** semantics node carries one
  /// before a check and that exactly one carries it after.
  String optionLabel({
    required String letter,
    required String text,
    String? suffix,
  }) => suffix == null || suffix.isEmpty
      ? '$letter. $text'
      : '$letter. $text — $suffix';

  /// The count, in this arm's numerals.
  ///
  /// `ReadingStrings._count` verbatim, and for the same reason it exists there: the
  /// *only* difference between the arms is which digits they use, and one named
  /// function is where a reader looks for that.
  String _count(int value) => isArabic ? arabicIndicDigits(value) : '$value';

  /// Whether this arm renders Arabic-Indic numerals.
  ///
  /// **Not a stored field**, for `ReadingStrings.isArabic`'s reason: the numeral
  /// system of a count and its wording are one decision, and reading it off a string
  /// cannot drift from the strings it governs.
  bool get isArabic => checkAnswer == const QuizStrings.ar().checkAnswer;

  /// Every `(name, value)` pair, for the arm-comparison test.
  ///
  /// `home_strings_test.dart` and `reading_strings_test.dart` each have one and each
  /// gives the same reason: a hand-written list inside a test is a second declaration
  /// of the table, free to drift from it, and a field added here without a row would
  /// be invisible.
  List<(String, String)> get fields => <(String, String)>[
    ('exit', exit),
    ('progress', progress),
    ('ofWord', ofWord),
    ('checkAnswer', checkAnswer),
    ('nextQuestion', nextQuestion),
    ('seeResults', seeResults),
    ('correctSuffix', correctSuffix),
    ('incorrectSuffix', incorrectSuffix),
    ('verdictCorrect', verdictCorrect),
    ('verdictIncorrect', verdictIncorrect),
    ('alreadyAnsweredSuffix', alreadyAnsweredSuffix),
    ('unavailableSuffix', unavailableSuffix),
    ('retry', retry),
    ('noQuestionsTitle', noQuestionsTitle),
    ('noQuestionsMessage', noQuestionsMessage),
  ];
}
