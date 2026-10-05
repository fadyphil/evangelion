import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/l10n/app_localizations.dart';

/// The settings feature's derived strings.
///
/// ## WHY THIS FILE EXISTS AND WHY IT IS **NOT** IN `l10n.dart`
///
/// `l10n.dart` holds two things: the `context.l10n` lookup and the two facts about an
/// arm (`isArabicArm`, `digits`). Its own doc says which of the three kinds of string
/// each of the five deleted tables carried, and this is kind two — **composition, not
/// translation**.
///
/// It is per-feature, beside its only callers, for the reason `greetingLead` is: a
/// derivation that needs a domain type would otherwise drag `features/settings/`'s
/// imports into `lib/l10n/`.
///
/// **AND THE HALF OF THAT REASON WHICH WAS "AND THE GATE DOES NOT LOOK THERE" IS NOW
/// STALE.** This paragraph used to continue: *"`lib/l10n/` is **not** covered by
/// `tool/verify_purity.sh` — Gate 1 and Gate 2 both key off `lib/features/*` and
/// `lib/core`, so a file there is a structural blind spot in the purity gate rather
/// than a checked one."* That was **true**, it was **known to be true**, and Phase 9
/// wrote the workaround down instead of closing the hole — which is the right call
/// for a phase that was not the one to close it, and the reason the gap survived.
///
/// Phase 10 closed it (decision 123). `tool/feature_import_check.dart`'s `_ownerOf`
/// now returns `l10n` for any path under `lib/l10n/`, at any depth, and Gate 2's
/// `ok` line names the owners it examined. Negative-controlled on the tool itself: a
/// probe importing `features/quiz` and `features/reading` from `lib/l10n/` exited
/// **0** before the change and **1** after, with both lines reported.
///
/// **The placement decision below is unchanged, and the reason it was ever
/// reconsiderable has gone.** Keeping the derivation inside the feature is still
/// right — it belongs beside its only callers and it needs a type from
/// `features/settings/domain/` — but it is now right because it is the better
/// placement rather than the only permitted one, which is a materially different
/// statement and worth the difference.
///
/// ## AND THE RULE ITSELF: A LANGUAGE NAMES ITSELF IN ITS OWN SCRIPT
///
/// `LanguageName` is not a translation of "English". It is **the name that language's
/// own speakers use for it**, and both arms therefore render the same two strings:
///
/// | arm | `english` | `arabic` |
/// | --- | --- | --- |
/// | en | English | Arabic |
/// | ar | الإنجليزية | العربية |
///
/// Two consequences, each one a thing a naive implementation gets wrong:
///
/// 1. **The Arabic arm writes BOTH names in Arabic script, and that is a decision
///    with a cost.** `الإنجليزية` rather than `English`, so the two rows of the sheet
///    are readable by an Arabic reader who does not read Latin — which also means
///    `app_localizations_test.dart`'s `latinIsCorrect` set does **not** grow. An
///    earlier draft of this file claimed the opposite ("the Arabic arm holds Latin
///    script for `english`, and that is the point"), and it was wrong about this
///    repository's own gate: transliterating would have required arguing for an
///    exception to the "no English left in the Arabic arm" test.
/// 2. **This file therefore introduces no tofu and needs no `arabicAware` of its
///    own** — the widgets that render it do that (`_LanguageRow` and `SettingsPage`
///    both take the ambient family).
extension SettingsLanguageName on AppLocalizations {
  /// The name [language]'s own speakers use for it.
  String languageLabelFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => settingsLanguageEnglish,
    ReadingLanguage.arabic => settingsLanguageArabic,
  };
}
