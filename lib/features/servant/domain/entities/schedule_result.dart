import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule_result.freezed.dart';

/// What the schedule endpoint answered.
///
/// ## THE `201` BODY, FIELD FOR FIELD
///
/// `admin.routes.ts:218-221` sends
/// `{message, reading_ids: string[]}` with **201**, and the schema at `:91-98`
/// declares exactly those two keys.
///
/// The **message** is the server's own sentence — `Successfully scheduled
/// reading for N groups`, with ` with AI-generated questions` appended when the
/// AI switch was on — and it is kept verbatim: `Failure`'s doc makes the same
/// rule about the backend's wording, and a screen that reworded it would be
/// showing the reader something the server did not say.
///
/// The **ids** are the readings the transaction created, one per cohort, in the
/// order the cohorts were sent. The questions screen needs one of them — the
/// backend has **no endpoint that lists a cohort's scheduled readings**, so
/// the id has to come from here or be typed by hand.
@freezed
final class ScheduleResult with _$ScheduleResult {
  /// The server's answer.
  const ScheduleResult({required this.message, required this.readingIds});

  /// The server's sentence, verbatim.
  final String message;

  /// The ids of the readings the transaction wrote, one per cohort.
  final List<String> readingIds;
}
