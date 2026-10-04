import 'package:dio/dio.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/reading/data/datasources/reading_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';

/// The live [ReadingRepository].
///
/// ## WHY IT LIVES IN `features/reading/` AND NOT IN `features/home/`
///
/// Two consumers, so §3 puts the *port* in `core/domain/` — and the *adapter*
/// follows the port's **domain**, not the first screen that needed it. `/reading`
/// is the sanctuary for exactly this payload and Phase 7 widens this very class,
/// so an adapter called `DioReadingRepository` living under `features/home` would
/// be a file whose name says reading and whose location says home.
///
/// That decision is recorded in `AGENT_CONTEXT` §9 as a new one, because
/// `07-file-map.md` and `08-build-phases.md` disagree about it: the file map puts
/// both real adapters in `reading/data/` and names **no** streak adapter at all
/// (an inventory gap — there are three adapters, not the two it lists), while
/// Phase 7 claims it owns "the remote data source (`GET /readings/today/{lang}`)
/// and its mapper". Both cannot be true of the same file, so the data sources,
/// mappers and adapters are created **now** for the narrow projection and Phase 7
/// **widens** them. `07-file-map.md` is not edited — AGENT_CONTEXT §8.6 gives
/// `docs/plans/` a dedicated owner.
///
/// ## THE BODY IS TWO ARMS, AND THAT IS THE WHOLE OF THE CONTRACT
///
/// ```dart
/// try   → Result.failure(errors.fromDioException(e))   // transport, or non-2xx
/// body  → mapper.map(body)                              // 2xx that cannot be read
/// ```
///
/// §3's LSP row: never throws, always returns a `Result`. There is no third arm
/// for "something else went wrong" because there is no third thing, and adding
/// one would be a `catch` that hides the two that exist. `analysis_options.yaml`
/// enables `avoid_catching_errors` and `avoid_catches_without_on_clauses`, so the
/// one `on` clause below is deliberate and narrow.
///
/// ## AND IT IS REGISTERED AGAINST THE PORT
///
/// `home_module.dart` provides `ReadingRepository`, never `DioReadingRepository`.
/// A concrete-typed registration would put this class into the graph as a
/// dependency of every use case, and swapping the adapter would become a change to
/// each of them — the same argument `auth_module.dart` makes for
/// `FakeAuthRepository`.
final class DioReadingRepository implements ReadingRepository {
  /// A repository over [dataSource], projecting with [mapper] and translating
  /// faults with [errors].
  ///
  /// All three are named and required, and none of them is resolved from the
  /// locator here: §3's DIP row says no `domain/` file names `Dio`, and a
  /// repository that reached for the global would be untestable over a fixture.
  const DioReadingRepository({
    required this.dataSource,
    required this.mapper,
    required this.errors,
  });

  /// Where the request goes. Injected rather than built, so a test can drive this
  /// repository over a fake adapter and so the endpoint path has exactly one home.
  final ReadingRemoteDataSource dataSource;

  /// Body → entity. `const`, and shared by every `DioReadingRepository`.
  final TodayReadingMapper mapper;

  /// Exception → [Failure]. `const`, and the one place a status becomes a kind.
  final ApiErrorMapper errors;

  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async {
    try {
      final Object? body = await dataSource.today(language);
      return mapper.map(body);
    } on DioException catch (error) {
      // Every transport fault and every non-2xx arrives here. §5 records that a
      // *missing* `X-User-Id` is a **400**, not a 401, so nothing below may
      // distinguish "unauthenticated" from "bad request" — the status decides the
      // kind and the body decides the message, both in `ApiErrorMapper`.
      return Result<TodayReading>.failure(errors.fromDioException(error));
    }
  }
}
