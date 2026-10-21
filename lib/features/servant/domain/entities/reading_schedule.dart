import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_schedule.freezed.dart';

/// One verse the scheduled passage leaves out.
///
/// ## WHY IT IS ITS OWN TYPE AND NOT A PAIR OF INTS
///
/// `admin.routes.ts:16-28` types an excluded verse as an **object** —
/// `{chapter, verse}` — and the schema's union arm accepts a second spelling,
/// `{Chapter, Verse}`, which it transforms into the first. This client always
/// writes the lower-case spelling, so the second arm is never sent.
///
/// A `({int chapter, int verse})` record would have carried the same two
/// numbers, and it would have been a `List<({int, int})>` on the schedule —
/// which is a type a reader has to decode at every use site. A named type says
/// what it is at the point of use, and the mapper has exactly one place to
/// spell the wire shape.
@freezed
final class ExcludedVerse with _$ExcludedVerse {
  /// A verse to leave out of the passage.
  const ExcludedVerse({required this.chapter, required this.verse});

  /// The chapter the verse is in.
  final int chapter;

  /// The verse's number within its chapter.
  final int verse;
}

/// What to schedule, for one date, for one or more cohorts.
///
/// ## THE SHAPE IS THE SERVER'S `scheduleSchema`, FIELD FOR FIELD
///
/// `admin.routes.ts:8-33`:
///
/// ```text
/// group_ids: int[]            (min 1)
/// scheduled_date: 'YYYY-MM-DD'
/// book_number: int            (1..66)
/// start_chapter: int          (min 1)
/// start_verse: int            (min 1)
/// end_chapter: int?           (optional; the server defaults it to start_chapter)
/// end_verse: int              (min 1)
/// excluded_verses: {chapter, verse}[]
/// generate_ai_questions: bool  (default false)
/// ```
///
/// **No field is added and none is dropped**, because the schema is a `z.object`
/// and **zod strips unknown keys** — a key this client invented would be
/// silently discarded by the server and every test would still see a working
/// request with the field simply never arriving.
///
/// ## AND WHY `endChapter` IS NULLABLE RATHER THAN A DEFAULT
///
/// The server's own transform is `end_chapter: data.end_chapter ???
/// data.start_chapter` (`:31-33`), so a passage that does not cross a chapter
/// boundary has **no** end chapter to send. `null` here is the absence of a
/// value, and the mapper turns it into an **omitted key** rather than a
/// `null` — zod's `.optional()` accepts `undefined` and refuses `null`, so a
/// literal `null` in the body would be a **400**.
@freezed
final class ReadingSchedule with _$ReadingSchedule {
  /// A reading to schedule.
  const ReadingSchedule({
    required this.groupIds,
    required this.scheduledDate,
    required this.bookNumber,
    required this.startChapter,
    required this.startVerse,
    required this.endVerse,
    this.endChapter,
    this.excludedVerses = const <ExcludedVerse>[],
    this.generateAiQuestions = false,
  });

  /// The cohorts to schedule for. At least one — the schema's `min(1)`.
  final List<int> groupIds;

  /// The date the reading is scheduled for, `YYYY-MM-DD`.
  ///
  /// A **string**, not a `DateTime`: the server's schema is a regex over the
  /// text (`/^\d{4}-\d{2}-\d{2}$/`), and a `DateTime` would have to be
  /// formatted on the wire anyway — and a `DateTime` carries a time the server
  /// has no field for.
  final String scheduledDate;

  /// The book, 1 to 66 — `1` is Genesis, `43` is John, `66` is Revelation.
  final int bookNumber;

  /// The first chapter of the passage.
  final int startChapter;

  /// The first verse of the passage.
  final int startVerse;

  /// The last chapter, or `null` when the passage stays in one chapter.
  final int? endChapter;

  /// The last verse of the passage.
  final int endVerse;

  /// The verses to leave out of the passage.
  final List<ExcludedVerse> excludedVerses;

  /// Whether the server should generate and attach the reading's question.
  ///
  /// **The server deletes the previous questions when this is on**
  /// (`admin.routes.ts:195`), which is a fact the screen states and this
  /// entity does not hide.
  final bool generateAiQuestions;
}
