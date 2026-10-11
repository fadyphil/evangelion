import 'package:dio/dio.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/leaderboard/data/datasources/leaderboard_remote_data_source.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';

/// A [LeaderboardRepository] over the live endpoint.
///
/// ## THE BODY IS TWO ARMS, AND THAT IS THE WHOLE OF THE CONTRACT
///
/// ```dart
/// try   → Result.left(errors.fromDioException(e))   // transport, or non-2xx
/// body  → mapper.map(body)                              // 2xx that cannot be read
/// ```
///
/// §3's LSP row: never throws, always returns a `Result`. There is no third arm for
/// "something else went wrong" because there is no third thing, and adding one would
/// be a `catch` that hides the two that exist. `analysis_options.yaml` enables
/// `avoid_catching_errors` and `avoid_catches_without_on_clauses`, so the one `on`
/// clause below is deliberate and narrow.
///
/// ## WHY THERE IS NO SHARED `_run` HELPER
///
/// `DioReadingRepository` records the same decision: three two-line arms that a reader
/// can compare by eye are worth more than a generic wrapper, and the day a fourth port
/// needs a different fault policy the helper becomes the thing every repository has to
/// work around.
final class DioLeaderboardRepository implements LeaderboardRepository {
  /// A repository over [dataSource], projecting with [mapper] and translating faults
  /// with [errors].
  const DioLeaderboardRepository({
    required this.dataSource,
    required this.mapper,
    required this.errors,
  });

  /// Where the request goes. Injected rather than built, so the endpoint path has
  /// exactly one home and a test can drive this repository over a fixture mapper.
  final LeaderboardRemoteDataSource dataSource;

  /// Body → entity. `const`, and shared by every `DioLeaderboardRepository`.
  final LeaderboardMapper mapper;

  /// Exception → [Failure]. `const`, and the one place a status becomes a kind.
  final ApiErrorMapper errors;

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    try {
      final Object? body = await dataSource.board(window: window, limit: limit);
      return mapper.map(body, limit: limit);
    } on DioException catch (error) {
      return Result<LeaderboardBoard>.left(errors.fromDioException(error));
    }
  }
}
