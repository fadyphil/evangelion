import 'package:dio/dio.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/reading/data/datasources/streak_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';

/// The live [StreakRepository].
///
/// ## WHY IT LIVES IN `features/reading/data/` AND NOT IN `features/home/`
///
/// A **decision, and the file map is now stale because of it.** The port belongs
/// to `core/domain/` because two features read it (§3). The *adapter* has no such
/// rule, so it follows the port's domain — which is `reading`, the feature whose
/// Phase 7 widens both of these classes. `07-file-map.md` §7 lists
/// `DioReadingRepository` and `SettingsRepository` under `reading/data/` and
/// `FakeAuthRepository` under `auth/data/`, and **names no streak adapter at
/// all**: an inventory gap, and after this phase the app has **three** adapters
/// where the document says two. The document is not edited (AGENT_CONTEXT §8.6
/// gives `docs/plans/` a dedicated owner); the corrected inventory is recorded in
/// `AGENT_CONTEXT` §9 instead, because a reader comparing the code against the
/// document needs to know which of the two is wrong and why.
///
/// The alternative — a third `features/home/data/`, or a `features/shared/data/`
/// — was rejected: `shared` is not a feature, so Gate 2 has no rule about it, and
/// a directory whose only content is "the two adapters two features share" is the
/// shared kernel with none of §3's placement test behind it.
///
/// ## THE SAME TWO ARMS AS ITS SIBLING
///
/// `DioReadingRepository`'s doc says the whole of it; this class has nothing to
/// add. What it does add is that this endpoint is the one that **requires**
/// `X-User-Id` (absent → 400, empty → 401), while `readings/today` does not — so
/// this adapter's 401 arm is reachable in a way its sibling's is not, and
/// `dio_repositories_test.dart` sweeps both over the same nine observed statuses
/// for exactly that reason.
final class DioStreakRepository implements StreakRepository {
  /// A repository over [dataSource], projecting with [mapper] and translating
  /// faults with [errors].
  const DioStreakRepository({
    required this.dataSource,
    required this.mapper,
    required this.errors,
  });

  /// Where the request goes. Injected rather than built, for
  /// `DioReadingRepository`'s reasons — and the endpoint path has exactly one home.
  final StreakRemoteDataSource dataSource;

  /// Body → entity. `const`, and shared by every `DioStreakRepository`.
  final StreakSummaryMapper mapper;

  /// Exception → [Failure]. `const`, and the one place a status becomes a kind.
  final ApiErrorMapper errors;

  @override
  Future<Result<StreakSummary>> summary() async {
    try {
      final Object? body = await dataSource.summary();
      return mapper.map(body);
    } on DioException catch (error) {
      return Result<StreakSummary>.failure(errors.fromDioException(error));
    }
  }
}
