import 'package:dio/dio.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/leaderboard/data/datasources/leaderboard_remote_data_source.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';
import 'package:evangelion/features/leaderboard/data/repositories/dio_leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/data/repositories/stub_leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:injectable/injectable.dart';

/// Whether the app answers the leaderboard from a fixed table instead of the endpoint.
///
/// ```sh
/// flutter run -d linux --dart-define=USE_STUB_LEADERBOARD=true
/// ```
///
/// ## WHY `bool.fromEnvironment` AND NOT `kDebugMode`
///
/// Because `kDebugMode` lives in `package:flutter/foundation.dart`, and this file is
/// reachable from `injection.dart` — whose whole transitive project-local import graph
/// `injection_test.dart` walks to prove it is Flutter-free. AGENT_CONTEXT §6 recorded
/// decision 4 makes that walk part of the contract, so importing the framework here to
/// ask a yes/no question about a stub would turn a documentation nicety into a gate
/// failure.
///
/// `bool.fromEnvironment` is `dart:core`. The gate stays green, the flag still defaults
/// to `false` in every build that does not name it, and the **shipped default is the
/// real endpoint** — which is the whole point of having the switch at all.
///
/// ## IT IS NOT A DEVELOPMENT MODE
///
/// There is no other flag in this app that changes which repository a screen gets, and
/// adding one is a cost paid by every future reader of the graph. The stub is opt-in per
/// run, it names itself in its own doc, and deleting it is one provider plus one import.
@module
abstract class LeaderboardModule {
  /// The cohort ranking.
  ///
  /// **The real endpoint by default.** `DioLeaderboardRepository` is the production
  /// path and the stub is unreachable unless a build names the flag above.
  ///
  /// Registered against the **port**, so `LoadLeaderboard` names neither class —
  /// the same rule `home_module.dart` follows for `DioReadingRepository`, and the
  /// reason a page or cubit never says `Stub`.
  @lazySingleton
  LeaderboardRepository get leaderboardRepository => useStubLeaderboard
      ? const StubLeaderboardRepository()
      : DioLeaderboardRepository(
          dataSource: LeaderboardRemoteDataSource(getIt<Dio>()),
          mapper: const LeaderboardMapper(),
          errors: const ApiErrorMapper(),
        );

  /// The full ranking for a chosen window.
  ///
  /// **Phase 5.2 removed the module's third registration.** `LoadLeaderboardPreview`
  /// was `/`'s weekly-top-three card, and the redesign's home (`:513-538`) has no
  /// board card at all — the board is its own screen from Task 5.5
  /// (`/communion`, `redesign.html:612-636`). The port stays, the endpoint stays,
  /// and `LoadLeaderboard` is now the only reader of either; the two windows'
  /// `?window=` parameter (`leaderboard.routes.ts:17`) is what 5.5 turns into the
  /// redesign's week / month / all control.
  @lazySingleton
  LoadLeaderboard get loadLeaderboard =>
      LoadLeaderboard(getIt<LeaderboardRepository>());
}

/// The value of the `--dart-define=USE_STUB_LEADERBOARD` flag.
///
/// `const`, so the choice is made at compile time and cannot flip between two lookups
/// of the same singleton — which is what would happen with a `bool` read through a
/// getter that re-read an environment value per call.
const bool useStubLeaderboard = bool.fromEnvironment('USE_STUB_LEADERBOARD');
