import 'package:dio/dio.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';

/// `GET /api/v1/streak/summary`, and nothing else.
///
/// The sibling of `ReadingRemoteDataSource`, and the same shape for the same
/// reasons: the URL is the mapper's, the exception translation is
/// `ApiErrorMapper`'s, and the body → entity translation is the mapper's. What is
/// left is one `get` and a [Response] field read.
///
/// ## WHY A SEPARATE CLASS AND NOT A SECOND METHOD
///
/// §3's SRP row is "one reason to change per file", and the two endpoints have
/// different ones: `readings/today` changes when the *reading* shape changes —
/// `text_clean` appearing in English, a questions field being added — and
/// `streak/summary` changes when the *streak* shape changes. One class with two
/// methods would have both reasons to change and no way to change one of them
/// without opening the other.
///
/// ## AND WHY IT IS NOT `DioReadingRepository`'S BUSINESS
///
/// The two repositories share structure and nothing else, which is why
/// `dio_repositories_test.dart` covers them in one file: the expensive part is the
/// "every `DioExceptionType` is a `Result`, never a throw" sweep, and duplicating
/// that sweep per class is §7's "two implementations of one invariant".
final class StreakRemoteDataSource {
  /// A data source over [dio].
  const StreakRemoteDataSource(this._dio);

  final Dio _dio;

  /// The raw body of the reader's streak summary.
  ///
  /// Throws whatever dio throws; the repository above converts every one.
  Future<Object?> summary() async {
    final Response<Object?> response = await _dio.get<Object?>(
      StreakSummaryMapper.summaryEndpoint,
    );
    return response.data;
  }
}
