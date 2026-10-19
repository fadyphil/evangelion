import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/cheer_repository.dart';
import 'package:evangelion/features/leaderboard/domain/leaderboard_ranking.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_cubit.freezed.dart';

/// Where `/communion` is in its own lifecycle.
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

/// What `/communion` is showing.
@freezed
final class LeaderboardState with _$LeaderboardState {
  /// The cold state: a request in flight for [initialWindow].
  const LeaderboardState({
    this.status = LeaderboardStatus.loading,
    this.window = LeaderboardWindow.weekly,
    this.board,
    this.failure,
    this.metric = LeaderboardMetric.light,
    this.cheered = const <String>{},
    this.readerName,
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

  /// Which of the two metrics the list is ordered by
  /// (`eva/redesign.html:623-625`).
  ///
  /// **Presentation-only, and no request.** Both values are on every row the one
  /// response carried — `score` for [LeaderboardMetric.light] and `current_streak`
  /// for [LeaderboardMetric.streaks] — so switching is [leaderboardOrder] over the
  /// board already in hand. ADR-0022 `:49` establishes that the switch is real data
  /// rather than the prototype's invented scaling.
  final LeaderboardMetric metric;

  /// The witnesses this session has already cheered, by row `userId`.
  ///
  /// The prototype declares one `Set` and never clears it
  /// (`eva/redesign.html:1066`); [LeaderboardCubit.load] mirrors the port's set into
  /// here and preserves it across window changes, so a route pop and push still
  /// shows the marks. A `Set` rather than a `List` because the only question asked
  /// of it is membership — `if(cheered.has(p.id)) return;` (`:1120`).
  final Set<String> cheered;

  /// The signed-in reader's name, for the you-card when the payload does not rank
  /// them.
  ///
  /// `null` when the auth port has no session. It is a **fallback**: a reader who
  /// appears in `leaderboard[]` is named by that row's `full_name`, which the
  /// response itself ranked (ADR-0022 `:110-113`). Never the prototype's
  /// `Mariam Hanna` (`:1055-1064`).
  final String? readerName;
}

/// Drives `/communion` through [load], [retry], [selectMetric] and [cheer].
///
/// ## AND IT IS A **`Cubit`**, NOT A `Bloc`
///
/// `ReadingCubit`'s doc gives the argument that applies here: `HomeBloc` is a `Bloc`
/// because it has four event types whose equality its tests assert. This has **no
/// events** — every operation is a method parameter, `bloc.add` is not reachable, and
/// there is no event stream to lose on a route pop.
class LeaderboardCubit extends Cubit<LeaderboardState> {
  /// Drives `/communion` over [loadLeaderboard], [getReaderSession] and
  /// [cheerRepository].
  LeaderboardCubit({
    required this.loadLeaderboard,
    required this.getReaderSession,
    required this.cheerRepository,
  }) : super(const LeaderboardState());

  /// The board request.
  final LoadLeaderboard loadLeaderboard;

  /// The reader's own name, through the legal seam for a feature that may not
  /// import `features/auth`.
  final GetBoardReaderSession getReaderSession;

  /// The session's cheers. A **port**, not a use case: there is no composition to
  /// perform between its two calls, and a pass-through use case would name the same
  /// operation twice.
  final CheerRepository cheerRepository;

  /// The server's `limit` for the full list.
  ///
  /// The **server's own default**, so this is "an unspecified request". It is not a
  /// display count: `cohortSizeOf` needs a cap that does not bind for the cohort's size
  /// to be provable, and fifty is both the server's default and far above any cohort
  /// that exists.
  static const int rowLimit = 50;

  /// The generation of the request that is currently in flight.
  ///
  /// ## WHY A GENERATION AND NOT A COMPARISON
  ///
  /// Because two window switches can be **in flight at once**, and the one that
  /// started first is not the one that answers first. Tapping "month" and then
  /// "all" fires two loads; if the monthly one resolves last, the final state is
  /// the **monthly** rows under an "all" heading.
  ///
  /// That is the exact confusion `LeaderboardBoard.window` exists to catch — and
  /// the client would be the one mislabelling it, which is the direction the
  /// entity's own doc says the field is there to prevent. And the screen would
  /// contradict itself in **two** places at once: the segmented control says
  /// "all" and the countdown — which is gated on the **response's** window —
  /// would count down to the month's boundary.
  ///
  /// A **generation counter** is the whole fix: each [load] takes the next
  /// number, and a response whose number is not the newest is **dropped**. Not
  /// compared against `state.window` — that would be a second source of truth
  /// about which request is current, and it would be wrong the moment a request
  /// for the *same* window overlapped another.
  int _generation = 0;

  /// Loads [window], preserving the metric, the cheers and the fallback name.
  ///
  /// **It empties first, and that is measured rather than cautious.** Keeping the old
  /// rows under a new window's heading would show a weekly ranking labelled "this
  /// month", which is the exact confusion `LeaderboardBoard.window` exists to catch —
  /// and it would catch it in the wrong direction, because the client would be the one
  /// that mislabelled it.
  ///
  /// **The three preserved fields are the prototype's own persistence.** `metric`,
  /// `cheered` and the reader's name are declared once outside `renderBoard`
  /// (`eva/redesign.html:1055-1066`), so a re-render keeps them; only [load] re-runs
  /// here, and clearing them would forget a cheer the reader just sent. The board, the
  /// status and the window are the three things a request owns.
  Future<void> load(LeaderboardWindow window) async {
    final int generation = ++_generation;
    emit(
      LeaderboardState(
        window: window,
        metric: state.metric,
        cheered: state.cheered,
        readerName: state.readerName,
      ),
    );
    final Future<Result<AuthSession>> reader = getReaderSession();
    final Future<Result<Set<String>>> cheers = cheerRepository.cheeredUserIds();
    final Result<LeaderboardBoard> result = await loadLeaderboard(
      LeaderboardQuery(window: window, limit: rowLimit),
    );
    final Result<AuthSession> session = await reader;
    final Result<Set<String>> sessionCheers = await cheers;

    // **The stale-response guard.** A response whose generation is not the newest
    // is dropped whole — no board, no status, no window. A reader who switches
    // from "month" to "all" must not be able to land a month of rows under an
    // "all" heading, and the screen would otherwise contradict itself in two
    // places at once: the segmented control would say "all" and the countdown —
    // which is gated on the **response's** window — would count down to the
    // month's boundary.
    if (generation != _generation) return;

    final String? readerName = switch (session) {
      Right<Failure, AuthSession>(:final AuthSession value) =>
        value.displayName,
      Left<Failure, AuthSession>() => state.readerName,
    };
    // `union` rather than replacement: a tap that landed while the request was in
    // flight is in `state.cheered`, and the read may have been taken before it.
    final Set<String> cheered = switch (sessionCheers) {
      Right<Failure, Set<String>>(:final Set<String> value) =>
        state.cheered.union(value),
      Left<Failure, Set<String>>() => state.cheered,
    };

    switch (result) {
      case Right<Failure, LeaderboardBoard>(:final LeaderboardBoard value):
        emit(
          LeaderboardState(
            status: LeaderboardStatus.ready,
            window: window,
            board: value,
            metric: state.metric,
            cheered: cheered,
            readerName: readerName,
          ),
        );
      case Left<Failure, LeaderboardBoard>(value: final failure):
        emit(
          LeaderboardState(
            status: LeaderboardStatus.failed,
            window: window,
            failure: failure,
            metric: state.metric,
            cheered: cheered,
            readerName: readerName,
          ),
        );
    }
  }

  /// The reader asked to try again, for the window on screen.
  ///
  /// One line delegating to [load], because `/communion` has exactly one request — a
  /// second spelling of `load` with nothing to distinguish the calls would be a method
  /// that exists only to be read as "retry" at the call site.
  Future<void> retry() => load(state.window);

  /// Switches the list between the two metrics, **without a request**.
  ///
  /// The ranking is [leaderboardOrder]'s; this method only records the choice. It is
  /// silent for the metric already on screen, so a rebuild that calls it in a
  /// post-frame callback cannot loop.
  void selectMetric(LeaderboardMetric metric) {
    if (state.metric == metric) return;
    emit(state.copyWith(metric: metric));
  }

  /// Cheers the witness identified by [userId], once.
  ///
  /// The prototype's guard is `if(cheered.has(p.id)) return;`
  /// (`eva/redesign.html:1120`); a repeated tap is a no-op rather than a second
  /// request. A failed cheer leaves the set untouched, so the row does not wear a mark
  /// the port refused to record.
  ///
  /// ## WHY IT RETURNS A **BOOL**
  ///
  /// Because the screen's confirmation toast must not be able to say **"cheer sent"**
  /// about a cheer that did not happen. The prototype's guard returns before *any*
  /// effect — no class, no toast (`:1120-1124`) — so a second tap on a marked row is
  /// invisible, and a toast that re-announced the cheer would be the one place the
  /// screen talks about an event it did not perform.
  ///
  /// The port is idempotent by contract ("a repeated cheer is a success, not a
  /// conflict", `cheer_repository.dart`), so the port cannot be the thing that says
  /// "no" — the **cubit** can, and it is the one that holds the mirrored set. So the
  /// answer travels back as the return value:
  ///
  /// * `true` — the cheer was recorded, and the caller may announce it;
  /// * `false` — the witness was already cheered, or the port refused it, and the
  ///   caller must stay silent.
  Future<bool> cheer(String userId) async {
    if (state.cheered.contains(userId)) return false;
    final Result<void> result = await cheerRepository.cheer(userId);
    switch (result) {
      case Right<Failure, void>():
        emit(state.copyWith(cheered: <String>{...state.cheered, userId}));
        return true;
      case Left<Failure, void>():
        // Deliberately silent, and deliberately **not** an announcement. The toast
        // is the success confirmation (`:947`), and a failure toast would be the
        // screen inventing a message the prototype never had. The unmarked row is
        // the visible answer, and the next tap is a legal retry.
        return false;
    }
  }
}
