import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_history_entry.freezed.dart';

/// One scheduled day from `GET /api/v1/streak`'s `history[]`.
///
/// ## WHAT THIS IS FOR, AND THE ADR THAT NAMED IT
///
/// ADR-0022's fiction table has one row for `/`'s **last-light card**
/// (`redesign.html:524`): *real* — "`GET /streak` → `history[0]`, **unused by the
/// client today**" — and the same record's Consequences make it the source for
/// "`last light`, the Journey rings, and any per-book completion". Before this
/// entity existed the card had no data at all: `ADR-0001` cut the library and the
/// profile, and the last-light card went with the library.
///
/// `history[0]` is the endpoint's own ordering, not a client-side sort:
/// `streak.service.ts:88-96` queries the last **30** scheduled readings with
/// `ORDER BY dr.scheduled_date DESC`, so index 0 is the most recent scheduled day —
/// today's reading when the cohort has one, otherwise the last day before today.
/// There is no `?date=` for this call and no page parameter, so "the last light" is
/// exactly that row and nothing else.
///
/// ## WHY A ROW ENTITY AND NOT A `StreakHistory`
///
/// `/`'s card renders one reference. A wrapper object holding the same list would
/// be a second name for `List<StreakHistoryEntry>` and a place to put the response's
/// nine scalars — which are **`StreakSummary`'s projection of the same service
/// call** (`streak.routes.ts:163-172` returns `getUserStreak(...)`'s fields minus
/// `history` and `today_date`), so carrying them here would be two fields for one
/// fact and two places for the two endpoints to disagree. `StreakSummary` keeps
/// them; this keeps the row.
///
/// ## WHY IT IS IN `core/domain/`
///
/// §3's placement test is two or more consumers, and the ADR names both: `/`
/// renders the reference (Task 5.2) and `/journey` derives its rings from
/// `is_completed` per book (Task 5.6). A port or entity inside `features/home`
/// would make the second consumer import the first, which §3 forbids with no
/// exceptions and `tool/verify_purity.sh` Gate 2 fails on the line.
///
/// ## WHAT THE CARD DOES **NOT** RENDER, AND WHY
///
/// No verse text. The row carries a reference, a book name and four counters; the
/// prototype's card drew a 64-character excerpt of the verse (`redesign.html:1203`)
/// because it holds the whole Bible in a literal (`BOOKS` at `:1004-1031`).
/// `GET /streak` has no verse body and no `GET /readings/:id` exists
/// (AGENT_CONTEXT §2), so a card that showed text would be showing a sentence this
/// client cannot source. The card shows the pointer.
@freezed
final class StreakHistoryEntry with _$StreakHistoryEntry {
  /// A scheduled day, as the endpoint's `history[]` reports it.
  const StreakHistoryEntry({
    required this.readingId,
    required this.scheduledDate,
    required this.bookNumber,
    required this.bookNameEn,
    required this.bookNameAr,
    required this.referenceEn,
    required this.referenceAr,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.correctAnswers,
    required this.pointsEarned,
    required this.isCompleted,
  });

  /// `reading_id` — the UUID `POST /readings/:id/submit` is addressed by.
  ///
  /// Carried for the identity it is and **not** for a call this client makes yet:
  /// the readings endpoint has no `GET /readings/:id`
  /// (AGENT_CONTEXT §2's route note), so nothing can ask for this row's passage.
  final String readingId;

  /// `scheduled_date`, as the `YYYY-MM-DD` string the wire carries.
  ///
  /// **A `String` and not a `DateTime`, for the reason `TodayReading.scheduledDate`
  /// records**: the payload carries a date with no zone and no time, and
  /// `DateTime.parse` would produce a *local* midnight — a different instant on
  /// every device. **No consumer compares them yet.** `/journey` derives its three
  /// rings from this history and **does not read the date** — the rings are
  /// ratios and a count, and a ratio over a window the server already ordered
  /// needs no comparison. The forward reference that named a calendar here was
  /// written for a screen that has no calendar, and it is withdrawn rather than
  /// left for a reader to go looking for the comparison.
  final String scheduledDate;

  /// `book_number` — 1 to 66, the Bible's canonical order.
  ///
  /// The **join key** for per-book completion: `/journey`'s rings ask "how much of
  /// *this book*", and the only field on this row that names a book in a way that
  /// survives translation is this one. `book_name_en` / `book_name_ar` are the
  /// server's strings for the same book and differ between the two arms.
  final int bookNumber;

  /// `book_name_en` — the server's English name for [bookNumber].
  ///
  /// Shown verbatim, and **not** as a substitute for the local catalogue: ADR-0022
  /// records that the *catalogue* is invented while per-book passage text is real,
  /// and this name is the payload's, so a card that needed a name and reached for
  /// `LibraryBook` instead would be mixing two sources that agree today and are
  /// free to diverge tomorrow.
  final String bookNameEn;

  /// `book_name_ar` — the server's Smith & Van Dyck name for [bookNumber].
  final String bookNameAr;

  /// `reference.en` — `Psalms 23:1-6` in English, built by
  /// `streak.service.ts:120-124`.
  ///
  /// Carried **per arm** rather than as one string the mapper has to pick, because
  /// the endpoint sends both and the endpoint is not localised: `GET /streak` has
  /// no `?lang=`. The pick is the caller's, for the reason
  /// `TodayReading.reference` is one string only — there the request *was* per arm.
  /// `redesign.html:1202` makes the same split in JS (`b.ar` or `b.name`).
  final String referenceEn;

  /// `reference.ar` — `المزمور ٢٣: ١-٦`, from the same two lines.
  final String referenceAr;

  /// `total_questions` — the approved questions this scheduled day carries.
  final int totalQuestions;

  /// `answered_questions` — how many of them this reader has submitted.
  final int answeredQuestions;

  /// `correct_answers` — how many of those submissions were right.
  ///
  /// The numerator Journey's accuracy tile divides (`correct ÷ answered`) and the
  /// one field on this row that is a **claim about the reader** rather than about
  /// the schedule.
  final int correctAnswers;

  /// `points_earned` — the sum of `points_awarded` over the same submissions.
  final int pointsEarned;

  /// `is_completed` — the server's own verdict for this day.
  ///
  /// `streak.service.ts:112` computes it as `totalQ > 0 && answeredQ >= totalQ`, so
  /// a scheduled day with **no** questions is never completed. That is the
  /// endpoint's rule and it is carried rather than re-derived: the same arithmetic
  /// lives in `streak.service.ts:153-169` for `current_streak`, and a client that
  /// derived it would be a second implementation of a server rule that can change.
  final bool isCompleted;
}
