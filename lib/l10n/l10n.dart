import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// The localization layer's shared kernel: how a widget *reaches* its strings, and
/// the two facts every arm needs about itself.
///
/// ## WHAT THIS FILE IS, AFTER FIVE STRING TABLES WENT AWAY
///
/// The tables it replaces each carried three kinds of thing, and only the first is a
/// string:
///
/// 1. **strings** — 73 fields across `LoginStrings`, `HomeStrings`, `QuizStrings`,
///    `ReadingStrings` and `ResultStrings`, which are now 72 ARB keys in
///    `app_en.arb` / `app_ar.arb` and arrive as [AppLocalizations];
/// 2. **derived strings** — `greetingLead`, `questionProgress`, `optionLabel`,
///    `messageFor`, `streakLabelFor`. These are *composition*, not translation, and
///    they are per-feature: each lives beside its only callers, in
///    `features/<f>/presentation/<f>_l10n.dart`, because one of them needs a type
///    (`GreetingPeriod`) that §3 puts in `features/home/domain/`;
/// 3. **facts about the arm** — `isArabic` and the numeral rendering. Those are the
///    two members here, and they are what this file exists for.
///
/// ## WHY [isArabicArm] IS THE LOCALE AND NOT A COMPARISON AGAINST A STRING
///
/// Every one of the five tables derived its arm by comparing one of its own strings
/// against the Arabic arm's, and `ReadingStrings.isArabic` gave the argument: *"a
/// `bool` field would be a second source of truth for the same fact as the nouns
/// being Arabic, and the two could disagree. Comparing one field against the Arabic
/// arm's is the same fact read from the other side, and it cannot drift."*
///
/// That reasoning was sound and it no longer applies, because **there is no second
/// arm to compare against any more.** `AppLocalizationsAr` is generated, so the
/// string-comparison trick would have to compare a generated getter against a
/// second `AppLocalizationsAr()` — a test of the generator rather than a fact about
/// the arm, and one that breaks the moment a translator picks a value that happens
/// to equal the English one (a defensible edit to `homeStreakLabel`, say).
///
/// The locale is also the *better* source. `HomeStrings.isArabic` existed for
/// exactly one caller — `TodayReadingPanel.retryFamilyFor`, whose **failed** state
/// has no reading to read an arm from — and its own doc called the strings "the
/// weaker source". The locale is not weaker; it is the fact the question actually
/// asks.
///
/// ## AND WHY THIS IS NOT `arabicAware`
///
/// `EvaTypography.arabicAware` is the rule for **families**, it takes the ambient
/// [TextDirection], and §4 of `eva_typography.dart` is emphatic that it is for runs
/// that render the app's own chrome where "the ambient direction is the whole of
/// what the caller knows". That is a different question from "which numeral system
/// does this arm use", and the two must be allowed to answer differently — which is
/// why `eva_typography.dart`'s own doc says the per-arm `*FamilyFor` switches stay.
/// This is a numeral rule and it is keyed on the locale, on purpose.
extension EvaL10nContext on BuildContext {
  /// This context's strings.
  ///
  /// ## WHY THIS EXISTS RATHER THAN `AppLocalizations.of(context)!` AT EVERY SITE
  ///
  /// `gen_l10n` generates `static AppLocalizations? of(BuildContext)`, nullable,
  /// because a `Localizations` lookup cannot prove which delegate installed it. The
  /// generated nullability is correct and this does not hide a real case: it is
  /// unreachable in the app, which lists [AppLocalizations.delegate] in
  /// `app.dart`, and it is unreachable in a test that pumps through a harness, which
  /// mirrors `app.dart`'s delegate list.
  ///
  /// What it *does* hide is a misconfigured harness — and that is deliberate here.
  /// The old `X.of(Locale)` fell back to English for anything unrecognised, which
  /// meant a page pumped with no `Localizations` above it rendered **English** and
  /// every Arabic assertion in that suite failed with a confusing message about a
  /// missing string. Failing at the lookup, with a null-check error naming the
  /// delegate, is the better failure and it is the same bargain
  /// `home_navigation_test.dart` made when it replaced `AutoRouteAwareStateMixin`'s
  /// throwing `RouterScope.of` with a `findAncestorWidgetOfExactType` that
  /// returns null.
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppLocalizationsArm on AppLocalizations {
  /// Whether this arm is the Arabic one.
  ///
  /// **A prefix test and not `localeName == 'ar'`.** `gen_l10n` constructs
  /// `AppLocalizationsAr()` with its **default** argument from
  /// `lookupAppLocalizations`, so in practice `localeName` is exactly `'ar'` — but
  /// that is a detail of the generated file's lookup table, and `ar_EG` is a locale
  /// a real device sends. `startsWith` holds for both and cannot silently fall
  /// through to the Latin face, which is the failure mode a helper like this is
  /// supposed to be immune to.
  bool get isArabicArm => localeName.startsWith('ar');

  /// [value] in this arm's numerals.
  ///
  /// ## WHY THE NUMERAL IS SUPPLIED BY THE CALLER AND NOT BY `{count}`
  ///
  /// `gen_l10n` compiles `{count, plural, …}` by interpolating the **raw Dart
  /// `int`** — the generated arm reads literally `'$count أسئلة'` — so a plain
  /// `{count}` renders LATIN digits on the Arabic arm. That silently undoes
  /// [arabicIndicDigits], which is a domain function pinned by
  /// `arabic_digits_test.dart` and by `font_coverage_test.dart`'s glyph coverage,
  /// and it leaves every Arabic screen showing `5 questions` beside `٥`. So the
  /// ARB's plural messages take the **selector** as an `int` and the **numeral** as a
  /// `String`, and this is where the String comes from.
  ///
  /// The division is the honest one: the numeral system is a property of the *arm*,
  /// and the agreement is a property of the *wording*.
  String digits(int value) => isArabicArm ? arabicIndicDigits(value) : '$value';
}
