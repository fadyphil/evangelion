import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_cubit.freezed.dart';

/// Where `/leaderboard` is in its own lifecycle.
///
/// Three values, and `HomeSectionStatus`'s doc gives the argument that applies here
/// verbatim: "loading" is **not** "no data", and a two-value enum would have to encode
/// it as one — a reader would be told the cohort is empty while the request is still
/// open.
enum LeaderboardStatus {
  /// The request is open. Nothing is on screen for the ranking.
  loading,

  /// An answer is in hand. [LeaderboardState.board] is non-null.
  ready,

  /// The request failed. [LeaderboardState.failure] is non-null and the retry control
  /// is live.
  failed,
}

/// What `/leaderboard` is showing.
@freezed
final class LeaderboardState with _$LeaderboardState {
  /// The cold state: a request in flight for [initialWindow].
  const LeaderboardState({
    this.status = LeaderboardStatus.loading,
    this.window = LeaderboardWindow.weekly,
    this.board,
    this.failure,
  });

  /// Which lifecycle arm this is.
  final LeaderboardStatus status;

  /// The window on screen, and the one the **next** request will use.
  ///
  /// Kept in the state rather than read from the control, because the segmented
  /// control is rebuilt from this value and a control holding its own selection would
  /// disagree with the data under it after a failed request kept the old rows.
  final LeaderboardWindow window;

  /// The ranking, or `null` while loading and after a failure.
  final LeaderboardBoard? board;

  /// Why the request failed, or `null`.
  final Failure? failure;
}

/// Drives `/leaderboard` through [load] and [retry].
///
/// ## AND IT IS A **`Cubit`**, NOT A `Bloc`
///
/// `ReadingCubit`'s doc gives the argument that applies here: `HomeBloc` is a `Bloc`
/// because it has four event types whose equality its tests assert. This has **no
/// events** — `load` and `retry` are method parameters, `bloc.add` is not reachable,
/// and there is no event stream to lose on a route pop.
class LeaderboardCubit extends Cubit<LeaderboardState> {
  /// Drives `/leaderboard` over [loadLeaderboard].
  LeaderboardCubit({required this.loadLeaderboard})
    : super(const LeaderboardState());

  /// The seam. See the class doc.
  final LoadLeaderboard loadLeaderboard;

  /// The server's `limit` for the full list.
  ///
  /// The **server's own default**, so this is "an unspecified request". It is not a
  /// display count: `cohortSizeOf` needs a cap that does not bind for the cohort's size
  /// to be provable, and fifty is both the server's default and far above any cohort
  /// that exists.
  static const int rowLimit = 50;

  /// Loads [window], emptying the current rows first.
  ///
  /// **It empties first, and that is measured rather than cautious.** Keeping the old
  /// rows under a new window's heading would show a weekly ranking labelled "this
  /// month", which is the exact confusion `LeaderboardBoard.window` exists to catch —
  /// and it would catch it in the wrong direction, because the client would be the one
  /// that mislabelled it.
  Future<void> load(LeaderboardWindow window) async {
    emit(LeaderboardState(window: window));
    final Result<LeaderboardBoard> result = await loadLeaderboard(
      LeaderboardQuery(window: window, limit: rowLimit),
    );
    switch (result) {
      case Right<Failure, LeaderboardBoard>(:final LeaderboardBoard value):
        emit(
          LeaderboardState(
            status: LeaderboardStatus.ready,
            window: window,
            board: value,
          ),
        );
      case Left<Failure, LeaderboardBoard>(value: final failure):
        emit(
          LeaderboardState(
            status: LeaderboardStatus.failed,
            window: window,
            failure: failure,
          ),
        );
    }
  }

  /// The reader asked to try again, for the window on screen.
  ///
  /// One line delegating to [load], because `/leaderboard` has exactly one section — a
  /// second spelling of `load` with nothing to distinguish the calls would be a method
  /// that exists only to be read as "retry" at the call site.
  Future<void> retry() => load(state.window);
}
