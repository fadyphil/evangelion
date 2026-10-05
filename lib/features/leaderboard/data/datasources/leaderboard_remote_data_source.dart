import 'package:dio/dio.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';

/// A data source for the cohort ranking endpoint.
///
/// The URL is the mapper's, the exception translation is `ApiErrorMapper`'s, and the
/// body → entity translation is the mapper's. What is left is one `get` and a
/// [Response] field read.
final class LeaderboardRemoteDataSource {
  /// A data source over [dio].
  const LeaderboardRemoteDataSource(this._dio);

  final Dio _dio;

  /// The raw body of the cohort ranking for [window], capped at [limit] rows.
  ///
  /// Throws whatever dio throws; the repository above converts every one.
  ///
  /// The cohort and the reader are **not** parameters: both travel as headers that
  /// `IdentityHeadersInterceptor` adds, and `X-Group-Id` is required by the server's
  /// schema, so a call made without the interceptor is a 400 rather than a ranking of
  /// everyone.
  Future<Object?> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    final Response<Object?> response = await _dio.get<Object?>(
      LeaderboardMapper.pathFor(window: window, limit: limit),
    );
    return response.data;
  }
}
