import 'package:equatable/equatable.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';

/// Which of a verse's two `text` fields to show.
///
/// ## ONE RULE, AND IT IS PHASE 6'S
///
/// AGENT_CONTEXT §5, trap 2 and trap 9 both say the same thing about two places:
/// `text_clean` exists **only in Arabic**, it is **absent** rather than null in
/// English, and "present but empty" is a third shape a proxy or a re-encoder can
/// produce. `today_reading_mapper.dart` established the resolution for a preview;
/// this is that resolution, in one named function, so the reading screen and `/`'s
/// panel cannot answer the question differently.
///
/// ```
/// text_clean, when it is there AND carries something  →  text_clean
/// anything else, including absence and `''`           →  text
/// ```
///
/// ## WHY IT IS A TOP-LEVEL FUNCTION AND NOT A GETTER ON ONE ENTITY
///
/// Because **two** things consume it — `Verse.displayText` and
/// `ScriptureText.toTodayReading()`'s preview — and the defect it guards against
/// is exactly the two-of-them case. `TodayReading.firstVerseText`'s doc already
/// records that the AR-only `text_clean` key is the trap; had the reading screen
/// grown its own `textClean ?? text` inline, the two spellings would have been one
/// refactor apart and the same mapper would be answering one question two ways.
/// This is the shape `fontStepFromScaler` takes for the same reason: the mapping
/// is read from the table, never restated.
///
/// A getter on `Verse` alone would have been enough until `ScriptureText` needed
/// it too; it is a function because the rule is not [Verse]'s to own.
String verseDisplayText({required String text, required String? textClean}) =>
    textClean != null && textClean.isNotEmpty ? textClean : text;

/// One verse of today's passage, in full.
///
/// ## [textClean] IS `null` FOR **ABSENCE**, NOT FOR EMPTINESS
///
/// The live English response has **no `text_clean` key at all** — verified against
/// `HEAD = 4a1c834`, and frozen in `test/support/live_payloads.dart` where the
/// absence is a real absence rather than a spelled `null`. So:
///
/// | wire | [textClean] | [displayText] |
/// | --- | --- | --- |
/// | key absent (English) | `null` | `text` |
/// | `text_clean: "…"` (Arabic) | that string | `text_clean` |
/// | `text_clean: ""` | `''` | `text` |
/// | `text_clean: 42` | `null` | `text` |
///
/// The last two rows are why the field is nullable **and** the field and the rule
/// are separate. Collapsing them — mapping `''` to `null` — would destroy the only
/// way a reader of this file could tell "the server sent no clean text" from "the
/// server sent an empty one", and the two have different causes. The rule above
/// still renders the same string for both, which is the honest outcome: there is
/// nothing to show in either case.
///
/// **Why the whole verse is on this entity while `TodayReading` keeps only a
/// string.** `/` draws a truncated preview and reads `firstVerseText`; `/reading`
/// is the sanctuary and draws every verse in full. One endpoint, two projections,
/// and §3's rule is that a second consumer promotes a type into the kernel — which
/// is what `core/domain/repositories/reading_repository.dart`'s second method does.
final class Verse extends Equatable {
  /// A verse as the wire describes it.
  const Verse({
    required this.bookNumber,
    required this.chapter,
    required this.number,
    required this.text,
    this.textClean,
  });

  /// `book_number` — `43` for John on the live payload.
  ///
  /// **Carried and never parsed against.** `reference` arrives display-formatted
  /// per language (`John 3:1-5` against `يوحنا 3: 1-5`, note the space after the
  /// Arabic colon), and the tempting move is to split it into book / chapter /
  /// verses to build a title. That is a **rejected** decision and
  /// `reading_page.dart` records the whole argument: a hand-rolled parser for a
  /// string the backend already formats is a new failure surface with no second
  /// source of truth to check it against, and `book_number` is already here as
  /// the server's own answer.
  final int bookNumber;

  /// `chapter` — `3`.
  final int chapter;

  /// `verse` — `1`…`5`.
  ///
  /// Named [number] and not [verse], because `verse` is the field's own wire name
  /// and a Dart class cannot have a member with the same name as its constructor's
  /// required parameter without shadowing at every use site.
  final int number;

  /// `text` — the verse as the server sends it, diacritics and all.
  ///
  /// ## THE SANCTUARY RENDERS **THIS**, NOT [displayText]
  ///
  /// Recorded as a decision rather than left to be discovered. `text_clean` is a
  /// *preview* string: its own name says so, and Phase 6 uses it for a 56-character
  /// one-line preview where the tashkīl are noise at 17px. `/reading` is the
  /// opposite — the full passage, 23px, `lineHeight: 2.2`
  /// (`ReadingArScreen.tsx:47`) — which is the one context in which Arabic vowel
  /// marks are legible and *are* the content a reader recites from. Stripping them
  /// there removes information rather than decoration.
  ///
  /// The second reason is structural: `text_clean` is **absent** from the English
  /// payload, so a screen that rendered the "clean" text would have to branch on
  /// which field exists per language. Rendering [text] on both arms means the
  /// scripture body has **no** language branch at all, which is also why the
  /// glyph gate can state one rule for the whole passage.
  ///
  /// **Rejected: `displayText` on both arms.** It would silently render English
  /// scripture from `text` and Arabic from `text_clean`, so the two arms of one
  /// reading would be set from different sources — invisible, and exactly the
  /// reconciliation §5 trap 8 forbids.
  ///
  /// **The cost, stated:** [textClean] is therefore carried and read by nothing on
  /// `/reading`, which is decision 39's "carried and unread" shape. `ScriptureBlock`
  /// renders `text`, and `reading_page_test.dart` asserts in the failing direction
  /// that no diacritic-stripped Arabic is on the screen while the live payload
  /// carries one for every verse.
  final String text;

  /// `text_clean` — the diacritic-stripped text, or `null` when the key is absent.
  ///
  /// See the class doc's table. **Never `''` for an absent key**, and `''` is a
  /// legitimate value for a present one.
  final String? textClean;

  /// What a **preview** shows: `verseDisplayText` over [text] and [textClean].
  ///
  /// This is what `/`'s panel reads, through `ScriptureText.toTodayReading()`.
  /// `/reading` reads [text] and its own doc says why.
  String get displayText => verseDisplayText(text: text, textClean: textClean);

  /// [other] with the named fields replaced.
  Verse copyWith({
    int? bookNumber,
    int? chapter,
    int? number,
    String? text,
    String? textClean,
  }) => Verse(
    bookNumber: bookNumber ?? this.bookNumber,
    chapter: chapter ?? this.chapter,
    number: number ?? this.number,
    text: text ?? this.text,
    // `textClean ?? this.textClean`, so omitting the argument keeps the current
    // value and an explicit `''` sets `''` — which means `copyWith` **cannot**
    // express "clear it back to absent". That is the nullable-field hazard
    // `AuthState.copyWith` documents, reached from a different direction: here the
    // absence is a *meaningful* wire state (§5, trap 2), so "no clean text" is not
    // the same as "leave it alone". There is no caller today, which is the honest
    // reason the hazard is written down rather than solved.
    textClean: textClean ?? this.textClean,
  );

  @override
  List<Object?> get props => <Object?>[
    bookNumber,
    chapter,
    number,
    text,
    textClean,
  ];
}

/// Today's passage **in full** — the wide projection of
/// `GET /api/v1/readings/today/{lang}`.
///
/// ## WHY THIS IS A SEPARATE TYPE FROM [TodayReading] AND NOT A REPLACEMENT
///
/// Recorded decision 23 settled the shape: **one port, one data source, one
/// mapper**, and the *narrow* projection becomes a read of the *wide* payload.
/// [toTodayReading] is that read, and `ReadingRepository.today` reaches it by
/// narrowing [this] — so `/` and `/reading` parse the wire with **one** set of
/// rules and cannot drift.
///
/// The alternative — one wide entity everywhere — would put a `List<Verse>` and a
/// `List<Question>` behind `/`'s panel, which renders a reference, a count and a
/// truncated string. That is §3's "nothing enters the kernel speculatively" run
/// the other way: `home` depending on five verse objects and a four-entry options
/// map to read three integers.
///
/// ## AND THE PORT NAMES IT, WHICH IS WHY IT IS HERE
///
/// `core/domain/repositories/reading_repository.dart` returns it from a signature,
/// so it cannot live in `features/reading/`: Gate 2 fails a `core/` → `features/`
/// import on the line. See `question.dart`'s doc for the whole argument.
final class ScriptureText extends Equatable {
  /// A passage as the wire describes it.
  const ScriptureText({
    required this.readingId,
    required this.groupId,
    required this.scheduledDate,
    required this.language,
    required this.reference,
    required this.translation,
    required this.verses,
    required this.questions,
    required this.isFullyCompleted,
    required this.pointsEarnedToday,
    required this.currentStreak,
  });

  /// `reading_id`. Phase 8's quiz addresses `POST /readings/:id/submit` by it, and
  /// §2's route table carries no `:passageId` because this **is** today's reading.
  final String readingId;

  /// `group_id` — `3` on the live payload, and the only group `POST` accepts.
  final int groupId;

  /// `scheduled_date`, as the `YYYY-MM-DD` string the wire carries, for
  /// `TodayReading.scheduledDate`'s reason: **no `DateTime.parse` anywhere**.
  final String scheduledDate;

  /// `language` — the arm this payload is in, from `ReadingLanguage.fromCode`, so a
  /// response naming a language this app does not ship never becomes an entity.
  final ReadingLanguage language;

  /// `reference` — `John 3:1-5` in English, `يوحنا 3: 1-5` in Arabic.
  ///
  /// **Rendered verbatim and never parsed.** See [Verse.bookNumber].
  final String reference;

  /// `translation` — `NKJV (New King James Version)` /
  /// `Smith & Van Dyck (فانديك)`.
  ///
  /// **Read on `/reading` and not on `/`** — it is the sanctuary's metadata row,
  /// and `home_page_test.dart` asserts it is *not* on `/`. The two screens showing
  /// different fields of the same payload is the projection working, not a leak.
  final String translation;

  /// `verses`, in the order the server sent them.
  ///
  /// **Not re-sorted.** `Verse.number` is carried, so the reading screen can show
  /// a gap the server left rather than a renumbering this client invented.
  final List<Verse> verses;

  /// `questions`, in `sort_order`.
  ///
  /// ## A QUESTION THIS CLIENT CANNOT READ IS **NOT** IN THIS LIST
  ///
  /// Phase 6's `TodayReadingMapper` had a count and could afford leniency: a
  /// question that is not an object, or whose `already_answered` is not a `bool`,
  /// counted as **not answered** rather than failing the reading. This type has no
  /// such room — a `Question` is an entity, so an unreadable entry has nowhere to
  /// go — and the choice is to drop it or to fail the whole passage.
  ///
  /// **Dropped.** Decision 40's argument, verbatim: the verse text is the one field
  /// a reader cannot be shown without, and every other field is a label *over*
  /// content. A malformed quiz payload should cost a question, not the scripture.
  ///
  /// **The cost, stated because it is real:** `questionCount` is now
  /// `questions.length`, so a payload of four unreadable questions reports **0**
  /// rather than 4, where Phase 6 reported 4 with `answeredQuestionCount == 0`.
  /// That is the one behavioural change in the narrow projection, every Phase-6
  /// fixture that exercises the leniency counts objects, and no Phase-6 assertion
  /// moved. The alternative — carrying a wire count beside a readable list — is two
  /// sources for one fact, which is the hazard `TodayReading.isFullyCompleted`'s doc
  /// records about the two endpoints disagreeing.
  final List<Question> questions;

  /// `is_fully_completed` — the reading endpoint's own verdict.
  ///
  /// **Not reconciled against `streak/summary.today_completed`**, which reads `false`
  /// for the same reader on the same day. See recorded decision 22 and
  /// `today_reading.dart`: each field comes from the endpoint whose job it is.
  final bool isFullyCompleted;

  /// `total_points_earned_today` — Phase 8's result screen reads it.
  final int pointsEarnedToday;

  /// `current_streak` — the **reading endpoint's** copy, `4`, against
  /// `streak/summary`'s `0`. Kept disagreeing on purpose; see [TodayReading.currentStreak].
  final int currentStreak;

  /// `verses.length`.
  int get verseCount => verses.length;

  /// `questions.length`. See [questions]'s doc for why this is not the wire count.
  int get questionCount => questions.length;

  /// How many [questions] carry `already_answered`.
  int get answeredQuestionCount =>
      questions.where((Question question) => question.alreadyAnswered).length;

  /// The first verse's [Verse.displayText], or `''` when there are no verses.
  ///
  /// **Empty rather than throwing.** §5's mapper refuses an empty `verses` list,
  /// so this is unreachable from the wire — but `ScriptureText` is constructible by
  /// hand and decision 40's lesson was precisely that a preview helper must not
  /// `substring(0, 1)` a string that can be empty. `''` costs a reader an empty
  /// line; a `RangeError` cost them the passage.
  String get firstVerseText => verses.isEmpty ? '' : verses.first.displayText;

  /// This passage as `/`'s panel reads it.
  TodayReading toTodayReading() => TodayReading(
    readingId: readingId,
    groupId: groupId,
    scheduledDate: scheduledDate,
    language: language,
    reference: reference,
    translation: translation,
    verseCount: verseCount,
    firstVerseText: firstVerseText,
    questionCount: questionCount,
    answeredQuestionCount: answeredQuestionCount,
    isFullyCompleted: isFullyCompleted,
    pointsEarnedToday: pointsEarnedToday,
    currentStreak: currentStreak,
  );

  /// [other] with the named fields replaced.
  ///
  /// The two lists are **replaced wholesale** rather than appended to. Every field
  /// is non-nullable, so `null` unambiguously means "keep the current value" and
  /// there is no sentinel in this file — which is why the nullable-field hazard
  /// `AuthState.copyWith` documents does not arise here either.
  ScriptureText copyWith({
    String? readingId,
    int? groupId,
    String? scheduledDate,
    ReadingLanguage? language,
    String? reference,
    String? translation,
    List<Verse>? verses,
    List<Question>? questions,
    bool? isFullyCompleted,
    int? pointsEarnedToday,
    int? currentStreak,
  }) => ScriptureText(
    readingId: readingId ?? this.readingId,
    groupId: groupId ?? this.groupId,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    language: language ?? this.language,
    reference: reference ?? this.reference,
    translation: translation ?? this.translation,
    verses: verses ?? this.verses,
    questions: questions ?? this.questions,
    isFullyCompleted: isFullyCompleted ?? this.isFullyCompleted,
    pointsEarnedToday: pointsEarnedToday ?? this.pointsEarnedToday,
    currentStreak: currentStreak ?? this.currentStreak,
  );

  @override
  List<Object?> get props => <Object?>[
    readingId,
    groupId,
    scheduledDate,
    language,
    reference,
    translation,
    verses,
    questions,
    isFullyCompleted,
    pointsEarnedToday,
    currentStreak,
  ];
}
