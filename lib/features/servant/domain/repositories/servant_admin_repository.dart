import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';

/// The three things an admin servant does to a reading.
///
/// ## WHY THIS IS A PORT AND NOT A METHOD ON A BIGGER ONE
///
/// §3's ISP row: "a single fat `EvangelionRepository` is **forbidden**", and the
/// portal's two capabilities are separate jobs with separate consumers —
/// scheduling and authoring are the admin servant's, reading the daily report
/// is the **viewer** servant's too. A viewer servant never schedules, and a
/// port that carried the scheduling methods would hand it three it must not
/// call.
///
/// The report half is [ServantReportRepository].
///
/// ## AND WHY IT LIVES IN `features/servant/domain/` AND NOT IN `core/domain/`
///
/// §3's placement test: *"used by exactly one feature → that feature's
/// `domain/`; used by two or more → `core/domain/`"*. The `servant` feature is
/// the only consumer of this port — the `kid`'s shell needs neither half of it —
/// so putting it in the shared kernel would be speculative. The shared kernel
/// holds what two features need; this is what one feature needs.
///
/// ## THE CONTRACT EVERY METHOD HERE KEEPS
///
/// §3's LSP row: **never throws across the seam, always returns a [Result]**.
/// There is no third arm for "something else went wrong", because there is no
/// third thing — a transport fault and a non-2xx response are both a
/// [Failure], and a body that cannot be read is a [Failure] too.
abstract interface class ServantAdminRepository {
  /// Schedules [schedule] for its cohorts and date.
  ///
  /// The server answers **201** with a message and one reading id per cohort.
  Future<Result<ScheduleResult>> scheduleReading(ReadingSchedule schedule);

  /// Commits [questions] against the reading [readingId].
  ///
  /// The server answers **201** with a message and one question id per
  /// committed question.
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  });

  /// Asks the server for a drafted question about the reading [readingId].
  ///
  /// The server answers **200** with the draft. The draft's own shape is the
  /// commit body's shape, so it is editable and committable without a
  /// conversion.
  ///
  /// **The server's AI route accepts two of the three question types** — `mcq`
  /// and `true_false` (`ai.routes.ts:10`) — and a `short_answer` is a **400**
  /// there. The refusal is the adapter's, because it is the adapter that knows
  /// the endpoint's vocabulary; the port states the domain's, which is wider.
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  });
}
