import 'package:dio/dio.dart';
import 'package:evangelion/features/reading/data/mappers/streak_history_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';

/// `GET /api/v1/streak` and `GET /api/v1/streak/summary`.
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
///
/// ## AND WHY `history()` IS NOT A SECOND CLASS EITHER
///
/// **The amendment Phase 5.2 made to the paragraph above, recorded here rather
/// than left for a reader to infer.** That argument separates two *domains* — a
/// reading and a streak. `/streak` and `/streak/summary` are one domain:
/// `streak.routes.ts:163-172` builds the summary by picking fields off
/// `streakService.getUserStreak(...)`, so the two routes change for the same
/// reason and are answered by the same service method. A second data source class
/// would hold one method, one `Dio` field and a copy of this doc — §8's "prefer
/// editing an existing file over creating a new one" for a file that adds nothing.
///
/// What genuinely differs is *cost*: `/streak` runs a subquery per scheduled day
/// (`streak.service.ts:98-112`) where the summary runs none, which is why `/`'s
/// streak chip asks for [summary] and its last-light card asks for [history]
/// rather than one call answering both.
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

  /// The raw body of the reader's streak history — `history[]` and all.
  ///
  /// Throws whatever dio throws; the repository above converts every one. **The
  /// whole body is returned rather than `body['history']`** because picking the
  /// array out here would put a shape decision in the data source, and §3 puts
  /// body → entity translation in the mapper.
  Future<Object?> history() async {
    final Response<Object?> response = await _dio.get<Object?>(
      StreakHistoryMapper.historyEndpoint,
    );
    return response.data;
  }
}
