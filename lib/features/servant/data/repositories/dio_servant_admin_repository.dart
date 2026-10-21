import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/servant/data/datasources/servant_remote_data_source.dart';
import 'package:evangelion/features/servant/data/mappers/question_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/schedule_mapper.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:fpdart/fpdart.dart';

/// The live [ServantAdminRepository].
///
/// ## THE BODY IS TWO ARMS, AND THAT IS THE WHOLE OF THE CONTRACT
///
/// ```dart
/// try   → Result.left(errors.fromDioException(e))   // transport, or non-2xx
/// body  → mapper.map(body)                          // 2xx that cannot be read
/// ```
///
/// §3's LSP row: never throws, always returns a `Result`. There is no third arm
/// for "something else went wrong" because there is no third thing, and adding
/// one would be a `catch` that hides the two that exist.
/// `analysis_options.yaml` enables `avoid_catching_errors` and
/// `avoid_catches_without_on_clauses`, so the one `on` clause below is
/// deliberate and narrow.
///
/// ## AND WHY THERE IS NO SHARED `_run` HELPER
///
/// `DioReadingRepository` records the same decision: three two-line arms that a
/// reader can compare by eye are worth more than a generic wrapper, and the day
/// a fourth port needs a different fault policy the helper becomes the thing
/// every repository has to work around.
///
/// ## AND IT IS REGISTERED AGAINST THE **PORT**
///
/// `servant_module.dart` provides `ServantAdminRepository`, never
/// `DioServantAdminRepository`. A concrete-typed registration would put this
/// class into the graph as a dependency of every use case, and swapping the
/// adapter would become a change to each of them.
final class DioServantAdminRepository implements ServantAdminRepository {
  /// A repository over [dataSource], projecting with [scheduleMapper] and
  /// [questionMapper] and translating faults with [errors].
  ///
  /// All four are named and required, and none of them is resolved from the
  /// locator here: §3's DIP row says no `domain/` file names `Dio`, and a
  /// repository that reached for the global would be untestable over a fixture.
  const DioServantAdminRepository({
    required this.dataSource,
    required this.scheduleMapper,
    required this.questionMapper,
    required this.errors,
  });

  /// Where the request goes. Injected rather than built, so the endpoint paths
  /// have exactly one home and a test can drive this repository over a fixture
  /// mapper.
  final ServantRemoteDataSource dataSource;

  /// The schedule body → [ScheduleResult] projection.
  final ScheduleMapper scheduleMapper;

  /// The question body → [CommitResult] and the draft → [QuestionDraft]
  /// projection.
  ///
  /// **One mapper for two bodies**, for the reason `question_mapper.dart` gives:
  /// the two are one subject — a question, and the shapes it travels in — and
  /// the draft's option shape is the commit's option shape.
  final QuestionMapper questionMapper;

  /// Exception → [Failure]. `const`, and the one place a status becomes a kind.
  final ApiErrorMapper errors;

  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async {
    try {
      final Object? body = await dataSource.schedule(schedule);
      return scheduleMapper.mapScheduleResult(body);
    } on DioException catch (error) {
      return Result<ScheduleResult>.left(errors.fromDioException(error));
    }
  }

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async {
    try {
      final Object? body = await dataSource.commitQuestions(
        readingId: readingId,
        questions: questions,
      );
      return questionMapper.mapCommitResult(body);
    } on DioException catch (error) {
      return Result<CommitResult>.left(errors.fromDioException(error));
    }
  }

  /// ## AND THE ONE REQUEST THAT IS **REFUSED BEFORE IT IS MADE**
  ///
  /// The AI route accepts two of the three question types
  /// (`ai.routes.ts:10`), and the mapper knows which two. So the body is built
  /// first, and a refusal comes back as a [Failure] **without a request having
  /// been made** — the server would have answered `400`, and the client knows
  /// that without asking.
  ///
  /// The failure's kind is [FailureKind.validation], which is what the server's
  /// own answer would have been.
  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async {
    final Result<Map<String, Object?>> body = QuestionMapper.aiGenerateBodyFor(
      readingId: readingId,
      type: type,
    );
    if (body case Left<Failure, Map<String, Object?>>(value: final failure)) {
      return Result<QuestionDraft>.left(failure);
    }
    try {
      final Object? raw = await dataSource.generateAiDraft(
        // The gate above has proved there is no failure arm to take, so this
        // fallback is unreachable — and §4 forbids a `!` that is not provably
        // non-null. `LeaderboardMapper` records the same shape.
        body: body.getOrElse((_) => const <String, Object?>{}),
      );
      return questionMapper.mapDraft(raw);
    } on DioException catch (error) {
      return Result<QuestionDraft>.left(errors.fromDioException(error));
    }
  }
}
