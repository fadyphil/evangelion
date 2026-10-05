import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// The `/quiz` strings that are **composed** rather than translated.
///
/// Both were methods on `QuizStrings`.
///
/// ## AND WHY NEITHER IS AN ARB KEY, MEASURED
///
/// * [questionProgress] reads `Question <current> of <total>` — `QuizScreen.tsx:67`.
///   It is **not** an ICU plural and the reason is that there is no noun agreeing
///   with either number: English writes `Question 2 of 5` and `Question 1 of 1`
///   identically, and Arabic writes `السؤال ٢ من ٥` the same way. The `of` is
///   invariant. A `plural` here would select an `other` branch identical to the
///   `one` branch, which asserts that two strings are equal — a test that cannot
///   fail. It also needs the numerals, which a `plural` selector cannot carry (see
///   [AppLocalizationsArm.digits]).
/// * [optionLabel] is punctuation around caller-supplied text, and its `suffix` is
///   `null` before the reader has checked — which is the whole of the spoiler
///   boundary as a string.
extension QuizStringsPhrases on AppLocalizations {
  /// `Question <current> of <total>` — `QuizScreen.tsx:67`, with the prototype's
  /// hard-coded `2` and `5` replaced by the session's own numbers.
  ///
  /// ## THE **PROTOTYPE'S** NUMBER IS A LIE AND THE ARMS USE DIFFERENT DIGITS
  ///
  /// `ReadingEnScreen.tsx:89`'s `5 questions` was the same kind of literal and
  /// `readingCaptionFor`'s description records what happened to it. So neither number
  /// is transcribed: `current` and `total` come from the session.
  ///
  /// The Arabic arm renders both in **Arabic-Indic** digits, which is what
  /// [digits] is for, and which is also why this string must be rendered in the
  /// payload arm's family: U+0660–U+0669 are Arabic-block codepoints and are tofu in
  /// Space Mono for exactly the reason the scripture is.
  String questionProgress(int current, int total) =>
      '$quizProgress ${digits(current)} $quizOfWord ${digits(total)}';

  /// An option's accessible name: the letter, the text, and any verdict.
  ///
  /// ## **THE VERDICT IS A PARAMETER AND NOT A BRANCH HERE**
  ///
  /// [suffix] is `null` before the reader has checked, and that is the whole of the
  /// spoiler boundary as a string. A method with an `if (isCorrect)` inside would be
  /// a second place the rule lives — and the rule's importance is precisely that it
  /// has one place. `QuizOptionCard` decides the suffix and this method spells it, so
  /// `quiz_page_test.dart` can assert that **no** semantics node carries one before a
  /// check and that exactly one carries it after a check.
  String optionLabel({
    required String letter,
    required String text,
    String? suffix,
  }) => suffix == null || suffix.isEmpty
      ? '$letter. $text'
      : '$letter. $text — $suffix';
}
