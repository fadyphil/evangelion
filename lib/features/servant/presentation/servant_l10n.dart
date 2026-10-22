/// The servant portal's **derived** strings — the ones that are composition
/// rather than translation.
///
/// `lib/l10n/l10n.dart` divides a feature's strings into three kinds, and this
/// file is the second: strings that are *built* from the reader's own locale
/// rather than looked up in the ARB. The third kind — the numerals — lives in
/// `l10n.dart` itself, and the first kind — the prose — is in the ARB with the
/// rest of the app's.
///
/// It is a separate file for the reason `features/home/presentation/
/// home_l10n.dart` and `features/leaderboard/presentation/leaderboard_l10n.dart`
/// are separate files: a derived string belongs beside its only callers, and
/// `home_l10n.dart` needs a type (`GreetingPeriod`) that §3 puts in
/// `features/home/domain/`. This one needs no type, and it is still its own
/// file because the **hub is its only caller** and a shared file would be a
/// shared file for one sentence.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The day [date] falls on, in the reader's own language.
///
/// ## AND WHY THE PATTERN IS **THE LOCALE'S OWN**
///
/// Because `intl` ships a **date pattern per locale**, and the two arms of this
/// app write the same day in two different — and each in its own right —
/// ways. Measured on `intl` 0.20.3, against the pattern table this reads:
///
/// ```text
/// en  MMMMEEEEd -> "EEEE, MMMM d"  -> Wednesday, October 21
/// ar  MMMMEEEEd -> "EEEE، d MMMM"  -> الأربعاء، ٢١ أكتوبر
/// ```
///
/// **Two things are visible there and both of them are the reason.** The
/// English arm puts the month first and the Arabic arm puts the day first —
/// which is not an inconsistency, it is each language writing a date the way
/// that language writes one, and a client that forced one order on both would
/// be writing an English date in Arabic. And the **separator is the locale's
/// own**: the Arabic pattern carries '،' and the English one ',', where a
/// hand-written pattern literal would have put an ASCII comma in both.
///
/// The rejected alternative — `DateFormat('EEEE, d MMMM', locale)`, one
/// pattern for both arms — was refused on exactly that ground, and it is worth
/// saying that it was **not refused on taste**: it produced
/// "الأربعاء, ٢١ أكتوبر", with an English comma in an Arabic sentence, and
/// "Wednesday, 21 October", which is not how either language writes a date.
///
/// ## AND WHY **NO YEAR**
///
/// The portal's sections are about **one day** — the daily report is the
/// roster *for a day* (`admin.routes.ts:341` types the querystring's `date`),
/// and the schedule form picks the day a cohort reads. A year on a screen
/// whose whole subject is the current week is noise, and it is the noise that
/// makes a line too long to fit at 320px — the surface the viewport matrix
/// gate measures.
///
/// `intl`'s `MMMMEEEEd` is the **year-less** member of that family;
/// `yMMMMEEEEd` is its sibling with the year, and it is the one the hub does
/// not want.
///
/// The **year matters** on the report screen, where a reader is looking back
/// at last month, and the report screen has a **date field** that says so.
///
/// ## AND WHY THE LOCALE DATA IS **ALREADY THERE**
///
/// `DateFormat` throws `LocaleDataException` for a locale whose symbols have
/// not been loaded — measured: *"Locale data has not been initialized, call
/// `initializeDateFormatting(<locale>)`."* — and **Flutter installs it**,
/// from `GlobalMaterialLocalizations.load`.
///
/// **And the tables it installs are FLUTTER'S, not `intl`'s.** That is not a
/// detail, because the two tables differ in a way this screen shows:
///
/// * `flutter_localizations`'s own `loadDateIntlDataIfNotLoaded` walks **its**
///   `generated_date_localizations.dart` and feeds it to `intl` through
///   `initializeDateFormattingCustom` — **for every locale at once**, the
///   first time any Material localisation loads.
/// * Flutter's `ar` table carries **`ZERODIGIT: '٠'`** and a `DATEFORMATS` of
///   `['EEEE، d MMMM y', 'd MMMM y', …]`.
/// * `intl`'s **own** `ar` table has **no `ZERODIGIT`**, so a program that
///   called `intl`'s `initializeDateFormatting` itself would write
///   "الأربعاء، 21 أكتوبر" — with **ASCII digits** — where this app
///   writes "الأربعاء، ٢١ أكتوبر".
///
/// **So the Arabic-Indic digits on the hub's date are Flutter's table, not
/// `intl`'s**, and the app's whole numeral rule (`arabicIndicDigits`, the
/// `digits()` helper) agrees with them because they are the same digits.
///
/// The dependency is therefore not a hidden one: it is the same dependency
/// `MaterialLocalizations.of(context)` has — the app installs that delegate
/// (`AppLocalizations.localizationsDelegates` is `gen-l10n`'s own list, and
/// it includes the Material trio), and the portal's own test harness installs
/// it too (`servant_harness.dart`'s `kServantLocalizationsDelegates`).
///
/// **And it is pinned by a test**, which is the only thing that keeps a
/// dependency honest: `servant_home_page_test.dart`'s "the masthead names the
/// day" case renders the hub in **both** arms and asserts the exact string of
/// each — the Arabic one with its Arabic-Indic digits and its Arabic comma.
///
/// The rejected alternative — `MaterialLocalizations.formatMediumDate` — is
/// the one that needs no locale data at all, and it writes "Thu, Oct 22"
/// beside "الخميس، ٢٢ أكتوبر": an abbreviated English weekday against a full
/// Arabic one, on a screen that is bilingual.
String servantDayLabel(BuildContext context, DateTime date) =>
    DateFormat.MMMMEEEEd(Localizations.localeOf(context).toString())
        .format(date);
