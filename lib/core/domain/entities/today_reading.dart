import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'today_reading.freezed.dart';

/// Today's scheduled reading, narrowed to what `/`'s panel draws.
///
/// ## WHY A PROJECTION AND NOT THE RESPONSE
///
/// `GET /readings/today/{lang}` returns the whole reading: every verse object,
/// and every reflection question with its `options` map. For the live payload
/// that is five verse objects and one four-entry map, and **none of it is on
/// Home**. What the panel shows is a reference, a translation name, a verse
/// count, the first verse's text, how many questions there are and how many are
/// answered, whether the reading is finished, and two numbers.
///
/// So this is the narrow shape. The wide one belongs to `features/reading/`,
/// which Phase 7 needs in full and which already owns the `text_clean` trap
/// (AGENT_CONTEXT §5, trap 2: the key is AR-only and **absent** in English).
/// Putting the wide shape here would be §3's "nothing enters `core/domain/`
/// speculatively" run backwards — a shared entity carrying a `Map<String, String>`
/// of quiz options that no `core/domain` consumer reads.
///
/// ## THE COST, STATED
///
/// `/` and `/reading` read the same endpoint through two projections, so the
/// wire is parsed twice. That is accepted: the alternative is a wide entity in
/// the shared kernel, which every feature then depends on in full to read five
/// fields of. Phase 7 **widens** `ReadingRepository` rather than adding a second
/// adapter, so the number of adapters stays at three and the duplication is in
/// one mapper rather than in two repositories.
///
/// ## [isFullyCompleted] IS NOT DERIVED FROM THE TWO COUNTS
///
/// The bead row counts answered questions; the panel's status line reads this
/// flag. They are different facts and the server sends both, and §5 records the
/// live case where this flag and `streak/summary.today_completed` disagree with
/// each other. Deriving one from the other would have quietly picked a winner in
/// a disagreement the backend has not resolved.
///
/// ## [copyWith] IS GENERATED AND EVERY FIELD IS NON-NULLABLE
///
/// Which is why the nullable-field hazard `AuthState` still documents cannot
/// arise here: no argument on the generated `copyWith` can be `null`, so nothing
/// can be silently left behind and nothing can be silently cleared. The
/// hand-rolled `copyWith` it replaced had exactly those semantics, so no call site
/// changed. See AGENT_CONTEXT §2.1.
@freezed
final class TodayReading with _$TodayReading {
  /// A reading as `/`'s panel needs it.
  const TodayReading({
    required this.readingId,
    required this.groupId,
    required this.scheduledDate,
    required this.language,
    required this.reference,
    required this.translation,
    required this.verseCount,
    required this.firstVerseText,
    required this.questionCount,
    required this.answeredQuestionCount,
    required this.isFullyCompleted,
    required this.pointsEarnedToday,
    required this.currentStreak,
  });

  /// `reading_id`. A UUID on the live payload — and the value `POST
  /// /readings/:id/submit` is addressed by. `/` never submits, so Phase 7's quiz
  /// reads it from the *wide* projection rather than from here.
  final String readingId;

  /// `group_id`. The cohort the reading was scheduled for; `3` on the live
  /// payload, and `3` is the only group `POST` accepts (AGENT_CONTEXT §5).
  final int groupId;

  /// `scheduled_date`, as the `YYYY-MM-DD` string the wire carries.
  ///
  /// ## WHY A STRING AND NOT A `DateTime`
  ///
  /// There is **no `DateTime.parse` anywhere in this entity**, and that is the
  /// design rather than an omission. `DateTime.parse('2026-10-03')` produces
  /// **local** midnight, which is a different *instant* on every device and a
  /// different *calendar day* for a reader east or west of UTC. The payload
  /// carries a date with no zone and no time, and nothing in this app needs an
  /// instant from it — only a label, and `home_page.dart` does not even render
  /// one. Converting it would import a timezone dependency into the shared
  /// kernel to buy a value no caller uses.
  final String scheduledDate;

  /// `language`. The arm the payload is in, from `ReadingLanguage.fromCode` — so
  /// a payload naming a language this app does not ship never becomes an entity.
  final ReadingLanguage language;

  /// `reference` — `John 3:1-5` in English, `يوحنا 3: 1-5` in Arabic. Shown
  /// verbatim: the spacing difference is the server's, not a rendering defect.
  final String reference;

  /// `translation` — `NKJV (New King James Version)` or
  /// `Smith & Van Dyck (فانديك)`. Shown verbatim, including the parenthetical,
  /// because the parenthetical is the edition and a reader choosing a reading
  /// wants to know which.
  final String translation;

  /// The number of verses in the payload. `verses.length`, counted at the edge.
  ///
  /// A count rather than the verses themselves, because the panel shows no verse
  /// list and holding five objects to render a number is the projection's whole
  /// purpose failing.
  final int verseCount;

  /// The first verse's `text` — the panel's preview, truncated at the call site.
  ///
  /// ## NOT `text_clean`, AND WHY THE DIFFERENCE MATTERS HERE
  ///
  /// AGENT_CONTEXT §5, trap 2: `text_clean` exists **only** in Arabic, and the
  /// English payload has no such key at all. A preview is a *display* string, so
  /// `text_clean` is the better text where it exists — and it does not exist in
  /// English. Using it unconditionally is a `null` in the panel for every English
  /// reader, which is the trap restated. So the mapper's rule is `text_clean`
  /// when the key is present and `text` otherwise, and Phase 7 owns the field
  /// that makes the difference observable in the sanctuary.
  ///
  /// Recorded here rather than only in the mapper because the *consequence* is a
  /// preview: Arabic shows a vowel-marked text and English shows the bare one,
  /// which is a visible difference and not a defect.
  final String firstVerseText;

  /// `questions.length` — how many reflection questions this reading carries.
  ///
  /// The live payload has **one**. The prototype's bead row claimed five
  /// (`HomeScreen.tsx:65` — `total={5} completed={2} current={2}`), which
  /// described *passage* progress across the library grid that was cut; see
  /// `features/home/domain/question_progress.dart`.
  final int questionCount;

  /// How many of [questionCount] carry `already_answered == true`.
  ///
  /// Counted at the edge rather than stored as a flag, because the backend sends
  /// the array and not the number. See the class doc on why this and
  /// [isFullyCompleted] are not derived from each other.
  final int answeredQuestionCount;

  /// `is_fully_completed` — the server's own verdict that today's reading is
  /// done.
  ///
  /// `true` on the live payload, while `streak/summary.today_completed` is
  /// `false` for the same user on the same day. The panel reads this field and
  /// the top-bar flame reads `StreakSummary.currentStreak`, and **neither consults
  /// the other** — see `streak_summary.dart` for the whole of it.
  final bool isFullyCompleted;

  /// `total_points_earned_today`.
  ///
  /// Carried because Phase 8's result screen reads it and it is on this payload
  /// today; `/` renders neither it nor the streak, and `home_page_test.dart`
  /// asserts no points figure is on the screen, so a reader cannot be shown a
  /// number the panel has no use for.
  final int pointsEarnedToday;

  /// `current_streak` — **the reading endpoint's own copy**.
  ///
  /// `4` on the live payload, against `streak/summary.current_streak`'s `0`.
  ///
  /// ## WHY THIS FIELD IS HERE WHEN NOTHING READS IT
  ///
  /// Two reasons, and the second is the one that matters. First, it is on the
  /// payload and this entity is a projection of the payload, so dropping it would
  /// be a lossy projection with no stated reason. Second — and this is the real
  /// one — it is the *trap*. A future author who wants a streak on `/` will
  /// reach for the field that is already on the object in their hand, and it
  /// disagrees with the one the top bar draws by four. Keeping the disagreement
  /// visible on the type, with a doc comment saying which endpoint owns which,
  /// is cheaper than removing the field and having the wrong number reintroduced
  /// from the response by a mapper that "helpfully" keeps everything.
  final int currentStreak;
}
