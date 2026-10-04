import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:flutter/widgets.dart';

/// The bilingual string table for `/`.
///
/// ## WHY IT IS HAND-WRITTEN, WHICH IS A COST AND NOT A SHORTCUT
///
/// `gen_l10n` needs `flutter: generate: true` in `pubspec.yaml`, and
/// AGENT_CONTEXT §8.4 makes an unlisted change a hard stop. So the table is Dart,
/// exactly as `LoginStrings` is, and it carries `LoginStrings`' own stated cost:
/// adding a language means adding a class here and **nothing checks that the two
/// arms agree in length**. What *is* checked is the property a reader would notice
/// — no English left in the Arabic arm, no empty value — by `home_strings_test.dart`,
/// which walks this file's declarations and compares both arms field by field.
///
/// ## WHERE THE ENGLISH CAME FROM, AND WHERE IT DID NOT
///
/// **Transcribed from the prototype:** the eyebrow `Continue Reading`, the two
/// button labels `Continue` and `Start reflection`, the streak subtitle, the
/// greeting word. Those are `HomeScreen.tsx:44,71,72,30` and `ds.tsx`, and each
/// carries its line in the field's doc.
///
/// **Not transcribed, because the prototype has nothing to transcribe:**
/// `streakResting`, `readingComplete`, `noQuestionsToday`, `retry`,
/// `todayReading`, `reflectionProgress`, `streakLabel`, `avatarLabel` and
/// `unavailableSuffix`. Each replaces either a hard-coded number or a claim the
/// live data can contradict, and each field says which.
///
/// ## AND NO NAME LIVES HERE
///
/// There is no `userName`, no `greeting = 'Good evening, Miriam'`. The prototype
/// hard-codes `Miriam` at `HomeScreen.tsx:27` and `MK` at `ds.tsx:516`, and there
/// is no user endpoint; the name comes from `AuthSession.displayName` through the
/// `AuthRepository` port. **A name in this file would be a defect**, and
/// `home_page_test.dart` asserts the string table has no such field.
final class HomeStrings {
  /// The strings for [locale].
  ///
  /// Falls back to [en] for anything that is not `ar`, for `LoginStrings.of`'s
  /// reason: the app declares exactly two `supportedLocales`, so the arm is
  /// unreachable through `MaterialApp.locale` and exists for a widget pumped
  /// outside one — which several suites do.
  static HomeStrings of(Locale locale) => switch (locale.languageCode) {
    'ar' => const HomeStrings.ar(),
    _ => const HomeStrings.en(),
  };

  /// The English arm.
  const HomeStrings.en()
    : wordmark = 'Evangelion',
      greetingMorning = 'Good morning',
      greetingAfternoon = 'Good afternoon',
      greetingEvening = 'Good evening',
      greetingSeparator = ', ',
      streakGlowing = 'Your streak is glowing. Keep it alive.',
      streakResting = 'Start a streak today. One reading is all it takes.',
      streakLabel = 'Streak',
      avatarLabel = 'Account',
      unavailableSuffix = 'unavailable in this build',
      todayReading = "Today's reading",
      continueReading = 'Continue reading',
      readingComplete = 'Reading complete',
      reflectionProgress = 'Reflections answered',
      noQuestionsToday = 'No reflection questions today',
      continueLabel = 'Continue',
      startReflection = 'Start reflection',
      retry = 'Try again';

  /// The Arabic arm.
  ///
  /// Written, not transcribed: the prototype is English only. Each of these is the
  /// product's own Arabic, and `home_strings_test.dart` asserts the arm contains
  /// no Latin script — the wordmark excepted, which is a product name in every
  /// language and transliterating a brand mark is a product decision
  /// (`LoginStrings.ar`'s wordmark says the same).
  const HomeStrings.ar()
    : wordmark = 'Evangelion',
      greetingMorning = 'صباح الخير',
      greetingAfternoon = 'نهار الخير',
      greetingEvening = 'مساء الخير',
      greetingSeparator = '، ',
      streakGlowing = 'سلسلتك متوهجة. حافظ عليها.',
      streakResting = 'ابدأ سلسلة اليوم. يكفي قراءة واحدة.',
      streakLabel = 'أيام متتالية',
      avatarLabel = 'الحساب',
      unavailableSuffix = 'غير متاح في هذه النسخة',
      todayReading = 'قراءة اليوم',
      continueReading = 'متابعة القراءة',
      readingComplete = 'اكتملت القراءة',
      reflectionProgress = 'أسئلة التأمل المجابة',
      noQuestionsToday = 'لا توجد أسئلة تأمل اليوم',
      continueLabel = 'متابعة',
      startReflection = 'ابدأ التأمل',
      retry = 'حاول مرة أخرى';

  /// Whether this arm is Arabic.
  ///
  /// ## WHY IT IS A COMPARISON AND NOT A STORED FIELD
  ///
  /// `ReadingStrings.isArabic` is the precedent and gives the whole argument: a
  /// `bool` field would be a second source of truth for the same fact as the nouns
  /// being Arabic, and the two could disagree. Comparing one field against the
  /// Arabic arm's is the same fact read from the other side, and it cannot drift
  /// from the strings it governs — so a translation that made `streakLabel`
  /// identical in both arms would turn this to `false`, which is the right answer
  /// for "is there any Arabic in here to render".
  ///
  /// **Added in Phase 7, for one caller.** `EvaButton.labelFamily` became required,
  /// and `TodayReadingPanel`'s **failed** state has no reading to read an arm from,
  /// so `strings` is the only thing this widget is handed that knows. See
  /// `TodayReadingPanel.retryFamilyFor`.
  ///
  /// **`streakLabel`, not `greetingSeparator`.** The separator is the one field
  /// whose doc says the arms "genuinely differ", which makes it a tempting sentinel
  /// — and it is the wrong one, because a comma's script says nothing about whether
  /// the sentence around it is Arabic. A noun does.
  bool get isArabic => streakLabel == const HomeStrings.ar().streakLabel;

  /// The product's name, in the top bar. `ds.tsx:508`.
  final String wordmark;

  /// `Good morning`, 05:00–11:59. `HomeScreen.tsx:26` writes `Good evening, `;
  /// the three words are `greeting_period.dart`'s decision and that file says so.
  final String greetingMorning;

  /// `Good afternoon`, 12:00–17:59.
  final String greetingAfternoon;

  /// `Good evening`, 18:00–04:59. The prototype's own word.
  final String greetingEvening;

  /// What follows the greeting word when a name comes after it.
  ///
  /// **A field and not a character in code**, because it is the one place the two
  /// arms genuinely differ and it is the difference a translator would otherwise
  /// have to find by reading `greetingLead`. English takes `, `; Arabic takes
  /// `، ` — U+060C ARABIC COMMA, which is a different codepoint from U+002C and
  /// renders at a different height. Substituting one for the other produces text
  /// that is right and looks wrong, which is the failure mode a bilingual string
  /// table exists to prevent.
  final String greetingSeparator;

  /// Under the greeting, when the streak is alive.
  ///
  /// `HomeScreen.tsx:30` — "Your streak is glowing. Keep it alive." Kept
  /// verbatim, and it is **conditional** where the prototype's was not: see
  /// [streakResting].
  final String streakGlowing;

  /// Under the greeting, when the streak is at zero.
  ///
  /// **Not in the prototype, and not optional.** `HomeScreen.tsx:30` is an
  /// unconditional literal, so on the live payload — `streak/summary.current_streak`
  /// is `0` — the app would tell a reader their streak is glowing while drawing a
  /// flame beside the number `0`. That is the same class of defect as the hard-coded
  /// greeting name this phase removed: a prototype string that contradicts live
  /// data.
  ///
  /// The alternative was shipping [streakGlowing] unconditionally and recording the
  /// lie; it was rejected because the number is on screen two inches away.
  final String streakResting;

  /// The streak count's accessible name, as a prefix. `StreakFlame.semanticLabel`.
  ///
  /// A prefix and not a pluralised phrase, because the announcement is composed by
  /// the row: `'$streakLabel: $count'`. Inventing Arabic dual and plural forms for
  /// "N-day streak" is a localisation decision this phase may not make, and a
  /// half-pluralised Arabic string is worse than a number beside a noun.
  final String streakLabel;

  /// The avatar's accessible name when the session has no name to read.
  ///
  /// `ds.tsx:525` renders the monogram `MK` inside a `<button>` with **no label at
  /// all** — §14's first row, and defect #11. So the button is named, and when there
  /// is a session the name is better than a noun: `HomePage` passes the display
  /// name and falls back to this.
  final String avatarLabel;

  /// Appended to the avatar's name while the control is inert.
  ///
  /// The same wording, and the same reasoning, as `LoginStrings`' own field: a
  /// screen reader should be told **why** the control cannot be pressed, not only
  /// that it cannot.
  final String unavailableSuffix;

  /// The panel's accessible name. `GlassSurface.semanticLabel`.
  final String todayReading;

  /// `CONTINUE READING`, `HomeScreen.tsx:44`.
  ///
  /// **Conditional**, because the live reading is finished
  /// (`is_fully_completed: true`) and the prototype's literal would then be false.
  /// See [readingComplete]; this is the *status* line the panel's `isFullyCompleted`
  /// drives, which is the one consumer the measured inconsistency (§5) gives it.
  final String continueReading;

  /// The eyebrow when `is_fully_completed` is true. Not in the prototype.
  final String readingComplete;

  /// `ProgressBeads.semanticLabel`'s prefix.
  ///
  /// The prototype's beads described **passage** progress across a cut grid
  /// (`HomeScreen.tsx:65` — `total={5} completed={2} current={2}`); these count
  /// reflection questions, which is what the live payload carries. `ProgressBeads`
  /// appends "N of M complete" itself.
  final String reflectionProgress;

  /// In place of the bead row when a reading carries no questions.
  ///
  /// **A decision, recorded rather than left to an accident.** `ProgressBeads`
  /// clamps `total` to `0` and returns `SizedBox.shrink()`, so a reading with no
  /// questions would render *nothing* between the reference and the buttons — a
  /// gap that looks like a rendering bug and reads as "there is nothing here" with
  /// no way to tell that from a layout failure. This line says which it is.
  final String noQuestionsToday;

  /// The primary CTA. `HomeScreen.tsx:71` — `ButtonPrimary`.
  ///
  /// Kept as the prototype's, deliberately: it names an **action** (open today's
  /// reading) and that action is available whether or not the reading is finished.
  /// The state-dependent string is the eyebrow above, which is what actually
  /// changes.
  final String continueLabel;

  /// The secondary CTA. `HomeScreen.tsx:72` — `ButtonText`, "Start reflection".
  final String startReflection;

  /// `ErrorView.retryLabel`. There is no prototype error state at all —
  /// `eva/src` has none, because it has no data layer that can fail — so this is
  /// written, and it says what it does rather than "Retry".
  final String retry;

  /// The greeting's first word, for [period].
  ///
  /// Not a getter over a map, because the switch is exhaustive over the enum and a
  /// `Map<GreetingPeriod, String>` lookup would return `null` for a member added
  /// tomorrow. §4 forbids `if`-chains for state branching; a `switch` *expression*
  /// is the answer.
  String greetingWord(GreetingPeriod period) => switch (period) {
    GreetingPeriod.morning => greetingMorning,
    GreetingPeriod.afternoon => greetingAfternoon,
    GreetingPeriod.evening => greetingEvening,
  };

  /// The greeting's lead-in — the prototype's `…evening, ` / `…evening.` split.
  ///
  /// `HomeScreen.tsx:26-27` renders `<span ink>Good evening, </span>` and then the
  /// name in a second, ember-coloured span. So the lead-in ends in a separator
  /// (see [greetingSeparator]) when a name follows, and the sentence is closed
  /// with a full stop when one does not — which is a case this phase makes
  /// reachable, because the name now comes from the session and there may not be
  /// one.
  ///
  /// The closing mark is `.` on both arms. Arabic uses the same codepoint; what
  /// differs is the *placement* convention for a trailing full stop after a short
  /// phrase, which is a typographic setting no string table carries, so inventing a
  /// different character would have been a guess dressed as a translation.
  String greetingLead(GreetingPeriod period, {required bool hasName}) {
    final String word = greetingWord(period);
    return hasName ? '$word$greetingSeparator' : '$word.';
  }
}
