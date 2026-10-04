import 'package:dio/dio.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/reading/data/mappers/submit_result_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';

/// `GET /api/v1/readings/today/{lang}` and `POST /api/v1/readings/:id/submit`,
/// and nothing else.
///
/// ## WHY THE DATA SOURCE IS THIS THIN
///
/// It builds the URL and performs the call. It does not know what a reading is,
/// does not catch anything, and does not produce a [Failure] — every one of those
/// belongs to somebody with a reason to own it:
///
/// * the **path** is [TodayReadingMapper]'s, because the endpoint and its `{lang}`
///   segment are one fact about the wire and two copies of a string is how they
///   drift;
/// * the **exception → [Failure]** translation is `ApiErrorMapper`'s, and it is
///   shared with the streak repository and every port Phase 7–8 adds;
/// * the **body → entity** translation is the mapper's — [TodayReadingMapper]'s
///   for the read and [SubmitResultMapper]'s for the write, which is why the
///   second one lives beside the first rather than inside a `quiz/data/` that
///   `08-build-phases.md` says must not exist.
///
/// So this class's whole body is one `get`. That is not an unfinished class: it is
/// the §3 SRP table's "one reason to change per file" applied honestly, and the
/// alternative — a data source that also knows the endpoint's shape — is the file
/// that has two reasons to change.
///
/// ## WHY THERE IS NO `?date=`
///
/// AGENT_CONTEXT §2's route table fixes the passage as always *today's*, and §5
/// records that `?date=` must be exactly `YYYY-MM-DD` or it is rejected. There is
/// no reading this client can render other than the current one, so a parameter
/// with no valid caller is a parameter nothing keeps in step.
final class ReadingRemoteDataSource {
  /// A data source over [dio].
  const ReadingRemoteDataSource(this._dio);

  final Dio _dio;

  /// The raw body of today's reading in [language].
  ///
  /// Throws whatever dio throws. That is not this class's contract — the
  /// repository above it converts every one of them — and a `try` here would be a
  /// second, partial answer to the same question.
  Future<Object?> today(ReadingLanguage language) async {
    final Response<Object?> response = await _dio.get<Object?>(
      TodayReadingMapper.pathFor(language),
    );
    return response.data;
  }

  /// The raw body of a graded answer, for [questionId] on [readingId].
  ///
  /// ## WHY IT IS A `post` AND NOT A `get` WITH A QUERY
  ///
  /// The endpoint is `POST /api/v1/readings/:id/submit` and the two values the
  /// route names are in **two different places**: `readingId` in the path and
  /// `question_id` in the body. So there is no single-query spelling, and a
  /// data source that put the question in the URL would be inventing a route.
  ///
  /// ## AND WHY THE BODY IS EXACTLY `{question_id, answer}`
  ///
  /// `submissions.routes.ts:6-8` is a `z.object` with those two keys, and **zod
  /// strips unknown keys** — so a third key would be silently dropped and every
  /// test would still see a working request with the field simply never arrived.
  /// `SubmitResult` has seven keys and a reader could plausibly send them; the
  /// assertion in `dio_repositories_test.dart` that the key set is exactly these
  /// two is what keeps that from being silent.
  ///
  /// **No client-side validation of either value**, and `reading_repository.dart`'s
  /// [ReadingRepository.submitAnswer] gives the whole argument: the route declares
  /// `question_id: z.string().uuid()` and `answer: z.string().min(1)`, while the
  /// path's `'Reading UUID'` is a *description*. §5 traps 10 and 11 record that the
  /// `reading_id` the backend serves is a fabricated non-UUID that has already
  /// rolled over once between two probes, so a UUID check here would reject the
  /// only reading this client can be given.
  ///
  /// **`contentType: Headers.jsonContentType` is explicit**, because §5 trap 5: a
  /// `POST` without `Content-Type: application/json` is a **415**, and this is the
  /// only request in the client with a body. dio sets it for a `Map`, and naming it
  /// makes the 415 hazard visible at the call site rather than a thing to know
  /// about dio.
  Future<Object?> submit({
    required String readingId,
    required String questionId,
    required String answer,
  }) async {
    final Response<Object?> response = await _dio.post<Object?>(
      SubmitResultMapper.submitPathFor(readingId),
      data: <String, Object?>{'question_id': questionId, 'answer': answer},
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data;
  }
}
