import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// A medal's name, in the table's own arm.
///
/// `eva/redesign.html:937`'s four i18n rows — `m1`, `m2`, `m3` and `m4` — and
/// the `LibraryBookCategory` precedent: **a translated string does not arrive as
/// data**, so the name is an ARB key and not a field on the enum. The enum in
/// `features/journey/domain/medal.dart` says the same thing about the medals'
/// names.
///
/// ## THE EMBLEM AND THE BLOOM ARE **NOT** LOOKED UP HERE
///
/// They are **fields on the domain's `Medal`** — `emblem` and `bloom` — and
/// they are read straight off the medal. This file owns the one thing the
/// domain cannot own, which is the **string**: the name.
///
/// The rendering decision (which of the prototype's four glyphs this client can
/// actually paint) belongs to the medal tile, which is where it is seen.
extension JourneyMedalLabel on Medal {
  /// The medal's name, from [strings].
  String label(AppLocalizations strings) => switch (this) {
    Medal.firstLight => strings.journeyMedalFirstLight,
    Medal.psalmist => strings.journeyMedalPsalmist,
    Medal.streakSeven => strings.journeyMedalStreakSeven,
    Medal.john => strings.journeyMedalJohn,
  };
}

/// U+0025, PERCENT SIGN — the Latin arm's.
const String _latinPercent = '%';

/// U+066A, ARABIC PERCENT SIGN — the Arabic arm's.
///
/// **A feature-local transform, and not one in `lib/l10n/l10n.dart`.** The
/// prototype's `N()` (`:981`) maps `%` to `٪` on the Arabic arm, and this
/// client's shared numeral helper — `AppLocalizations.digits` — is an **int**
/// helper, so it has no place for a sign.
///
/// The alternative the brief allows is "record that the Arabic arm shows `%`",
/// and that was rejected: U+0025 is in all five bundled families and U+066A is
/// in Amiri, so the correct sign is available, and a percentage written with a
/// Latin sign on an Arabic arm is a translation defect rather than a note.
///
/// The number is the shared helper's, and the sign is this one's.
const String _arabicPercent = '٪';

/// A ratio as the prototype's rings print it — `83%` on the Latin arm and
/// `٨٣٪` on the Arabic one.
///
/// **The prototype's own arithmetic**: `:592` writes `data-v="83%"` and `:987`
/// re-localises it through `N()`, which is `String(s).replace(/\d/g, …)` and
/// then `.replace(/%/g, '٪')` — the digits first and the sign second, so the
/// composed string is the digits and then the sign, in that order.
///
/// The percentage is **rounded to a whole number**, because the prototype's
/// `data-v` values are whole ("83%", "92%") and a ring that said "83.33%"
/// would be a precision the source does not have.
String journeyPercent(AppLocalizations strings, double fraction) {
  final int percent = (fraction * 100).round();
  return '${strings.digits(percent)}'
      '${strings.isArabicArm ? _arabicPercent : _latinPercent}';
}
