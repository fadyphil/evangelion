import 'package:dio/dio.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';

/// `GET /api/v1/readings/today/{lang}`, and nothing else.
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
/// * the **body → entity** translation is the mapper's.
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
}
