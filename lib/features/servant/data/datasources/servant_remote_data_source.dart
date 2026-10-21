import 'package:dio/dio.dart';
import 'package:evangelion/features/servant/data/mappers/question_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/report_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/schedule_mapper.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';

/// The servant portal's four routes, and nothing else.
///
/// ## WHAT THIS CLASS IS
///
/// A data source for `POST /api/v1/admin/readings/schedule`,
/// `POST /api/v1/admin/questions/commit`,
/// `POST /api/v1/admin/questions/ai-generate` and
/// `GET /api/v1/servant/reports/daily`.
///
/// It **builds the request and performs the call**. It does not know what a
/// reading is, does not catch anything, and does not produce a [Failure] —
/// every one of those belongs to somebody with a reason to own it:
///
/// * the **path and the body** are the mappers', because the endpoint and the
///   shape of what it accepts are one fact about the wire, and two copies of
///   that string is how they drift;
/// * the **exception → [Failure]** translation is `ApiErrorMapper`'s, and it is
///   shared with every other repository in the app;
/// * the **body → entity** translation is the mappers' too.
///
/// So this class's whole body is four calls. That is not an unfinished class:
/// it is §3's SRP table's "one reason to change per file" applied honestly, and
/// the alternative — a data source that also knows the endpoint's shape — is
/// the file that has two reasons to change.
final class ServantRemoteDataSource {
  /// A data source over [dio].
  const ServantRemoteDataSource(this._dio);

  final Dio _dio;

  /// The raw body of the schedule answer.
  ///
  /// Throws whatever dio throws; the repository above converts every one.
  Future<Object?> schedule(ReadingSchedule schedule) async {
    final Response<Object?> response = await _dio.post<Object?>(
      ScheduleMapper.endpoint,
      data: ScheduleMapper.bodyFor(schedule),
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data;
  }

  /// The raw body of the commit answer.
  ///
  /// **`contentType` is explicit**, because a `POST` without
  /// `Content-Type: application/json` is a **415** (AGENT_CONTEXT §5, trap 5),
  /// and every request in this client with a body says so at the call site
  /// rather than leaving it to know dio.
  Future<Object?> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async {
    final Response<Object?> response = await _dio.post<Object?>(
      QuestionMapper.commitEndpoint,
      data: QuestionMapper.commitBodyFor(
        readingId: readingId,
        questions: questions,
      ),
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data;
  }

  /// The raw body of the AI draft answer.
  ///
  /// ## AND THE BODY IS **HANDED IN**, NOT BUILT HERE
  ///
  /// The request's `type` is checked against the endpoint's vocabulary
  /// **before the body exists** — `ai.routes.ts:10` accepts `mcq` and
  /// `true_false` only, and a `short_answer` is a **400** there. The check
  /// belongs to the mapper, and the mapper's answer is a `Result`, so the
  /// repository reads it first and hands over a body that is already known to
  /// be one the server will accept.
  ///
  /// This is the **only** method in the app whose body arrives rather than
  /// being built, and the asymmetry is the point: it is the one request whose
  /// validity is decided before it is made.
  Future<Object?> generateAiDraft({required Map<String, Object?> body}) async {
    final Response<Object?> response = await _dio.post<Object?>(
      QuestionMapper.aiGenerateEndpoint,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data;
  }

  /// The raw body of the daily report.
  ///
  /// The cohort and the date travel as **querystring** here, because that is
  /// where the route reads them (`admin.routes.ts:372-374`) — the report is
  /// the only one of the four routes that is a `GET`.
  Future<Object?> dailyReport({
    required int groupId,
    required String date,
  }) async {
    final Response<Object?> response = await _dio.get<Object?>(
      ReportMapper.pathFor(groupId: groupId, date: date),
    );
    return response.data;
  }
}
