import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// The `/` strings that are **composed** rather than translated, and the two
/// arm-keyed reads that belong beside them.
///
/// ## WHY COMPOSITION LIVES HERE AND NOT IN A WIDGET
///
/// `redesign.html` composes its composed sentences in JS rather than in the I18N
/// table, and the three this screen needs are all that shape:
///
/// | composed | how the prototype writes it |
/// | --- | --- |
/// | `peace, {name}` | `:993` — `'سلام، مريم'` / `'peace, Mariam'`, one literal |
/// | `{n} scrolls · {n} open` | `:930` — one literal **with the numbers baked in** |
/// | `{n} seconds of silence` | `:990` — `` `${N(selahDur)} ${tr('secs')}` `` |
///
/// Two of the three cannot be transcribed literally here — the numbers are not
/// constants in this client — and the third is transcribed *without* its number for
/// the reason `homeSecondsOfSilence`'s description gives. So each is a function
/// over the table, and a function over the table is what §6 asks for rather than a
/// `'$a $b'` inside a `build` method.
///
/// ## AND WHY NOT A `{count}` PLACEHOLDER
///
/// Because `app_localizations_test.dart` fails any **non-plural** Arabic value that
/// holds Latin script, and a placeholder name is Latin: `{scrolls}` in the Arabic
/// string is the defect `auth_password_hint` would be. The three plural keys are the
/// only ones exempt and none of these three is a plural — the wording does not vary
/// with the number, only the numeral does, and `digits` is the domain function that
/// supplies it (`l10n.dart`).
///
/// ## WHY IT IS IN `features/home/` AND NOT BESIDE THE ARB
///
/// [LibraryCategory.label]'s parameter is an enum from this feature's domain, and
/// [LibraryBook.nameFor]'s is a direction. A file under `lib/l10n/` that reached
/// into a feature for either would make the shared l10n layer feature-dependent,
/// and §3's rule is that the dependency points inward.
extension HomeStringsPhrases on AppLocalizations {
  /// The greeting's mono caption for [period].
  ///
  /// `redesign.html:988` — `el('dayMono').textContent = tr(hourKey())`, where
  /// `hourKey()` (`:983-984`) returns one of `morn`, `noon`, `eve`, `vigil`.
  ///
  /// A `switch` expression over an enum and not a `Map<GreetingPeriod, String>`:
  /// §4 forbids an `if`-chain for state branching, and a map would return `null`
  /// for a member added tomorrow where a `switch` cannot.
  String greetingWord(GreetingPeriod period) => switch (period) {
    GreetingPeriod.morning => homeGreetingMorning,
    GreetingPeriod.afternoon => homeGreetingAfternoon,
    GreetingPeriod.evening => homeGreetingEvening,
    GreetingPeriod.vigil => homeGreetingVigil,
  };

  /// The family a **retry button's label** renders in, on this arm.
  ///
  /// `ErrorView` asserts that a caller passing [ErrorView.onRetry] also passes a
  /// family, because the label it renders is localized and a mono or serif face on
  /// the Arabic arm would be tofu. This is the *arm-based* rule (`isArabicArm`)
  /// rather than the direction-based one `arabicAware` uses, and the difference is
  /// the string: the retry label is the app's own (`homeRetry`), so the ambient
  /// locale decides its script, while a `Failure.message` is the **server's** and
  /// `StreakChip`'s retry tooltip follows the direction for exactly that reason.
  String get retryLabelFamily =>
      isArabicArm ? EvaTypography.arabicFamily : EvaTypography.uiFamily;

  /// The greeting's second line: `peace` and the reader's first name.
  ///
  /// `redesign.html:993` — `'سلام، مريم'` / `'peace, Mariam'`. The name is the
  /// **session's**, and a name is not translatable, so the word and the separator
  /// are the table's and this function joins them.
  ///
  /// ## WHY THE NAME IS ITS **FIRST** TOKEN
  ///
  /// Because the prototype's is: `hiName` says `Mariam` where the journey's own
  /// `jName` (`:992`) says `Mariam Hanna`. `AuthSession.displayName` is the whole
  /// name (`David Mina`), so joining it verbatim would paint "peace, David Mina"
  /// under a 23px headline where the prototype paints four characters.
  ///
  /// [firstNameOf] is that decision, and it is a pure function with its own tests
  /// rather than an `indexOf(' ')` at this call site.
  String peaceWith(String? name) => name == null
      ? homePeace
      : '$homePeace$homeGreetingSeparator${firstNameOf(name)}';

  /// `{n} seconds of silence`. `redesign.html:990`, in this arm's numerals.
  String selahSeconds(int seconds) =>
      '${digits(seconds)} $homeSecondsOfSilence';

  /// `{n} scrolls · {n} open`. `redesign.html:930`'s literal, with live counts.
  ///
  /// [open] is derived from the catalogue's `sealed` flags by the carousel, not
  /// passed as a total minus something here — `LibraryCatalogueRepository.books`'s
  /// doc is why the order may not be sorted, and a subtraction would be a second
  /// claim about the same list.
  String scrollsOpen({required int scrolls, required int open}) =>
      '${digits(scrolls)} $homeScrolls · ${digits(open)} $homeOpenBooks';

  /// `{n} verses`. `redesign.html:1313`'s `N(b.en.length)` and `tr('verses')`.
  String verseCount(int count) => '${digits(count)} $homeVerses';
}

/// The reader's first name out of a session's display name.
///
/// `AuthSession.displayName` is `David Mina` (`auth_local_data_source.dart`'s seed)
/// and `redesign.html:993` greets the reader by first name alone, so the split
/// happens here — a pure function, because §6 requires the logic a widget uses to
/// be testable and `HomePage`'s only clock-like input is already injected for a
/// worse reason.
///
/// ## THE THREE ARMS IT HAS TO SURVIVE
///
/// * **One token** — `Mariam` is `Mariam`. `split` gives a one-element list and the
///   answer is the whole string.
/// * **Leading or trailing space** — trimmed before the split, so `' David '` is
///   not `' '`. `AuthSession.displayName` is whatever the backend sent and nothing
///   in the client trims it.
/// * **No space at all** — `MariamHanna` is one token and stays whole; inventing a
///   camel-case split would be guessing at a name.
///
/// It returns the **whole** string when there is no space, which is the one case
/// where the prototype's rendering cannot be reproduced from this client's data and
/// the honest result is the longer word.
String firstNameOf(String displayName) {
  final String trimmed = displayName.trim();
  final int space = trimmed.indexOf(' ');
  return space <= 0 ? trimmed : trimmed.substring(0, space);
}

/// A category's label, in the table's own arm.
extension LibraryCategoryLabel on LibraryCategory {
  /// `redesign.html:1036` — `CATS[category][li()]`, which is the six-element
  /// `Map<String, [String, String]>` this becomes.
  String label(AppLocalizations strings) => switch (this) {
    LibraryCategory.poetry => strings.homeCategoryPoetry,
    LibraryCategory.gospel => strings.homeCategoryGospel,
    LibraryCategory.torah => strings.homeCategoryTorah,
    LibraryCategory.prophets => strings.homeCategoryProphets,
    LibraryCategory.history => strings.homeCategoryHistory,
    LibraryCategory.apocalypse => strings.homeCategoryApocalypse,
  };
}

/// The arm-keyed reads on a catalogue entry.
extension LibraryBookArm on LibraryBook {
  /// The book's name in [direction]'s script.
  ///
  /// `redesign.html:1313` — `lang==='ar' ? b.arName : b.name` — and the same pick
  /// at `:1202` for the last-light card's reference. **By direction and not by
  /// locale**: the app ships two locales and only `ar` resolves to RTL, so the
  /// direction the engine already resolved is the whole of the answer
  /// (`arabicAwareFamily`'s doc argues the same point for families).
  String nameFor(TextDirection direction) =>
      direction == TextDirection.rtl ? nameAr : nameEn;
}
