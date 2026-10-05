import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// The `/reading` derived string — one method, and it is the wrapper the ARB's
/// two-placeholder plural needs.
///
/// ## WHY A WRAPPER AND NOT `readingCaptionFor(count, digits(count))` AT THE CALL SITE
///
/// `readingCaptionFor` takes the ICU **selector** as an `int` and the **numeral** as
/// a `String`, for the reason `l10n.dart` gives: `gen_l10n` interpolates a raw
/// `int` and would render Latin digits on the Arabic arm. Those two arguments must
/// be the same number, and spelling that out at a call site makes it a caller's job
/// to keep them in step — the exact defect a helper exists to prevent. One method
/// takes the count once.
///
/// The alternative — and the reason this is worth a file — would be a second ARB key
/// holding a pre-formatted numeral, which would move a *number* into the
/// translation layer where a translator can edit it.
extension ReadingStringsPhrases on AppLocalizations {
  /// The sticky CTA's caption for [count] questions.
  ///
  /// ## PLURALISED BY ICU NOW, AND THE ARABIC DUAL IS NEW
  ///
  /// `ReadingEnScreen.tsx:89` hard-codes `5 questions` and the live reading carries
  /// **one** question, so the prototype's literal is false by a factor of five and a
  /// hard-coded `5` is fake data that happens to match nothing the server sends.
  ///
  /// This replaces `captionFor`'s `count == 1 ? … : …` expression, which implemented
  /// one boundary and recorded the other three Arabic agreement classes as
  /// acknowledged debt. `app_ar.arb`'s `readingCaptionFor` supplies all six, so
  /// `count` of `2` is now `٢ سؤالان` where the table returned `٢ أسئلة`. See the
  /// key's own description for why all three of that table's reasons for accepting
  /// the gap are now obsolete.
  ///
  /// ## AND THE NUMERAL IS **ARABIC-INDIC** ON THE ARABIC ARM
  ///
  /// `ReadingArScreen.tsx:86-87` writes `٥`, and it reaches the screen through
  /// [digits] — which is also why this string must be rendered in `Amiri`: **U+0665
  /// is an Arabic-block codepoint**, so it is tofu in Space Mono for the same reason
  /// the scripture is.
  ///
  /// **A count below one takes Arabic's `zero` class.** `questionCount == 0` is
  /// reachable — `TodayReadingMapper` maps an empty `questions` list rather than
  /// refusing it — and `0 questions` is the honest English for it.
  String readingCaption(int count) => readingCaptionFor(count, digits(count));
}
