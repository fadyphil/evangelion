import 'package:evangelion/l10n/app_localizations.dart';

/// The `/quiz` strings that are **composed** rather than translated.
///
/// Both were methods on `QuizStrings`.
///
/// ## AND WHY THE CRUMB IS AN EXTENSION METHOD AND NOT AN ARB KEY, MEASURED
///
/// * [quizCrumb] composes the appbar's centred crumb out of
///   [AppLocalizations.quizRefraction] and the payload's own `reference`. The
///   second half is server text — a reading the client does not translate, quote or
///   reformat — so an ARB placeholder would put it inside a message whose Arabic
///   arm is checked for Latin script and whose numerals are the arm's own
///   (decision 102/103). The composition lives here, the `home_l10n.dart`
///   precedent, and the citation is `eva/redesign.html:1348` —
///   `` `${tr('refraction')} · ${bookTitle(b)}` `` — the prototype's own composed
///   string, written in JavaScript and never an I18N row either.
/// * [optionLabel] is punctuation around caller-supplied text, and its `suffix` is
///   `null` before the reader has checked — which is the whole of the spoiler
///   boundary as a string.
///
/// ## AND WHY THERE IS NO `questionProgress` ANY MORE
///
/// The composed `Question <current> of <total>` line was the old chrome's progress
/// surface, and the redesign's quiz screen has none of it: the screen's markup
/// (`eva/redesign.html:562-574`) carries the appbar, the `.dots` row, the prompt,
/// the options and the CTA, and no count sentence. The progress the screen still
/// shows is the beads row, whose accessible name is [AppLocalizations.quizProgress]
/// — a semantics-only string, never painted, which is why the Arabic gate declines
/// to declare it. `quizOfWord` died with the composition.
extension QuizStringsPhrases on AppLocalizations {
  /// The appbar crumb: `Refraction · <reference>`.
  ///
  /// `eva/redesign.html:565` draws it centred in the `.ttl` slot;
  /// `:1348` fills it from the reader's passage. The client's second half is
  /// `QuizSession.reference`'s honest equivalent — the server's `reference`,
  /// verbatim — and the separator is the prototype's own `·` (U+00B7), on both
  /// arms, because `:1348` interpolates one literal for both.
  String quizCrumb(String reference) => '$quizRefraction · $reference';

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
