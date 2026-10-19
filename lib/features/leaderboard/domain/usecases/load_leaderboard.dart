import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'load_leaderboard.freezed.dart';

/// What to rank: a window, and how much of it to ask for.
///
/// A freezed params object rather than two positional parameters on `call`, because
/// `(window, limit)` are two different kinds of value and a caller writing
/// `load(LeaderboardWindow.weekly, 50)` has to remember which is which. The
/// single-enum case stays positional by contrast — see `LoadTodayReading`.
///
/// `limit` is a parameter of the request rather than a constant here because the
/// **server's** default is not the client's to fix: `leaderboard_module.dart`'s
/// `rowLimit` is the server's own `limit=50`, so "unspecified" is the honest
/// request. It used to be there for a second caller — `features/home/`'s
/// `LoadLeaderboardPreview`, the board card on `/` — and **ADR-0022 deleted that
/// card**, so the parameter has one caller now.
@freezed
final class LeaderboardQuery with _$LeaderboardQuery {
  /// A query for [window] capped at [limit] rows.
  const LeaderboardQuery({required this.window, required this.limit});

  /// Which stretch of time to rank over.
  final LeaderboardWindow window;

  /// The server's `limit` querystring parameter.
  final int limit;
}

/// The full cohort ranking for a window.
///
/// ## WHAT IT ADDS: NOTHING, AND THAT IS THE POINT
///
/// One port call and one return. §3's DIP row makes a use case that reclassified an
/// error or reshaped an entity a **second** place where the wire's meaning is decided,
/// and the mapper already refuses everything this could usefully refuse. `LeaderboardMapper`
/// keeps that knowledge in one file, and a failure returned here is the port's failure
/// byte-identical — which `home_usecases_test.dart` asserts for the sibling ports and
/// `leaderboard_usecases_test.dart` asserts here.
///
/// ## WHY THE SCREEN OWNS THIS, AND WHERE THE OTHER CALLER WENT
///
/// `features/leaderboard/` holds this use case. It used to have a **second** one —
/// `features/home/`'s `LoadLeaderboardPreview`, for the board card on `/` — and a
/// feature may not import another (§3, Gate 2), so the shared port in
/// `core/domain` is what let both features ask for the same board.
///
/// **ADR-0022 deleted the card** ("the board card's title, whose screen now owns its
/// copy"), and with it the second use case. There is no "shared leaderboard use
/// case" a third location could own, because a shared *use case* is a shared
/// *feature* — and the port in `core/domain` is what a future second caller would
/// use.
final class LoadLeaderboard
    implements UseCase<LeaderboardQuery, LeaderboardBoard> {
  /// Loads the ranking through [repository].
  const LoadLeaderboard(this._repository);

  final LeaderboardRepository _repository;

  @override
  Future<Result<LeaderboardBoard>> call(LeaderboardQuery params) =>
      _repository.board(window: params.window, limit: params.limit);
}
