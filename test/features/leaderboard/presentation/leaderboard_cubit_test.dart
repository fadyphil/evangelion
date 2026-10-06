import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake **repository**, not a fake use case.
///
/// `LoadLeaderboard` is a `final class`, so it cannot be implemented from outside its
/// library — and that is the right constraint. The cubit is therefore driven over the
/// **real** use case, which exercises its pass-through on the way in: a use case that
/// reclassified a failure would fail here rather than being stubbed away.
final class _Repo implements LeaderboardRepository {
  _Repo(this.result);

  /// What the next call answers.
  Result<LeaderboardBoard> result;

  /// Every `(window, limit)` the cubit asked for, in order.
  final List<({LeaderboardWindow window, int limit})> queries =
      <({LeaderboardWindow window, int limit})>[];

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    queries.add((window: window, limit: limit));
    return result;
  }
}

/// A cubit over [_Repo], with the teardown registered.
({LeaderboardCubit cubit, _Repo repo}) harness(
  Result<LeaderboardBoard> answer,
) {
  final _Repo repo = _Repo(answer);
  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: LoadLeaderboard(repo),
  );
  addTearDown(cubit.close);
  return (cubit: cubit, repo: repo);
}

/// The seeded empty board — the measured state of this endpoint.
const LeaderboardBoard empty = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[],
  standing: null,
  cohortSize: 0,
);

/// Three rows, cohort provable at five.
const LeaderboardBoard populated = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(rank: 1, score: 80, initials: 'PG'),
    LeaderboardRow(rank: 2, score: 50, initials: 'DM'),
    LeaderboardRow(rank: 3, score: 30, initials: 'MA'),
  ],
  standing: LeaderboardStanding(rank: 2, score: 50),
  cohortSize: 5,
);

void main() {
  group('a cold cubit', () {
    test('is loading, on the weekly window, with nothing on screen', () {
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.success(empty),
      );
      expect(h.cubit.state.status, LeaderboardStatus.loading);
      expect(h.cubit.state.window, LeaderboardWindow.weekly);
      expect(h.cubit.state.board, isNull);
      expect(h.cubit.state.failure, isNull);
    });
  });

  group('load', () {
    test("asks for the server's own limit, not a display count", () async {
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.success(populated),
      );
      await h.cubit.load(LeaderboardWindow.monthly);

      expect(h.repo.queries.single.window, LeaderboardWindow.monthly);
      // 50 is the server's default for the querystring parameter, and a cap that did
      // **not** bind is the only condition under which `cohortSize` is provable. A
      // "however many fit" limit would make the cohort's size permanently unknowable
      // and the card would never be able to say "3rd of 12".
      expect(h.repo.queries.single.limit, LeaderboardCubit.rowLimit);
      expect(h.repo.queries.single.limit, 50);
    });

    test('and becomes ready carrying the board', () async {
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.success(populated),
      );
      await h.cubit.load(LeaderboardWindow.weekly);

      expect(h.cubit.state.status, LeaderboardStatus.ready);
      expect(h.cubit.state.board, populated);
      expect(h.cubit.state.failure, isNull);
    });

    test(
      'EMPTIES FIRST, because old rows under a new heading are a lie',
      () async {
        // The defect this prevents, stated as a state: `window` becomes monthly while
        // `board` still holds the **weekly** ranking, so a reader sees a list labelled
        // "This month" containing this week's numbers. The response is authoritative
        // about its own window — `LeaderboardBoard.window` exists for that — but it has
        // not arrived yet, and the previous window's rows are the wrong answer meanwhile.
        final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
          const Result<LeaderboardBoard>.success(populated),
        );
        await h.cubit.load(LeaderboardWindow.weekly);
        expect(h.cubit.state.board, isNotNull);

        final List<LeaderboardState> seen = <LeaderboardState>[];
        final StreamSubscription<LeaderboardState> subscription = h.cubit.stream
            .listen(seen.add);
        addTearDown(subscription.cancel);

        await h.cubit.load(LeaderboardWindow.monthly);
        await Future<void>.delayed(Duration.zero);

        expect(seen, isNotEmpty);
        expect(
          seen.first.board,
          isNull,
          reason: 'the first frame after a window change carries no rows',
        );
        expect(seen.first.window, LeaderboardWindow.monthly);
      },
    );

    test('a failure is `failed` with the failure, and no board', () async {
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.failure(failure),
      );
      await h.cubit.load(LeaderboardWindow.weekly);

      expect(h.cubit.state.status, LeaderboardStatus.failed);
      expect(h.cubit.state.failure, failure);
      expect(h.cubit.state.board, isNull);
    });

    test('and the failure does not disturb the window on screen', () async {
      // The retry has to know which window to re-request. A failed frame that cleared
      // it would make `retry()` silently fall back to `weekly` while the picker still
      // read "All time" — the client mislabelling its own request, which is the exact
      // confusion the response's own `window` field exists to catch.
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.failure(
          Failure(kind: FailureKind.timeout, message: 'The request timed out.'),
        ),
      );
      await h.cubit.load(LeaderboardWindow.allTime);

      expect(h.cubit.state.window, LeaderboardWindow.allTime);
    });
  });

  group('retry', () {
    test('re-requests the window on screen, not the default', () async {
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.success(empty),
      );
      await h.cubit.load(LeaderboardWindow.monthly);
      await h.cubit.retry();

      expect(
        h.repo.queries.map(
          (({LeaderboardWindow window, int limit}) q) => q.window,
        ),
        <LeaderboardWindow>[
          LeaderboardWindow.monthly,
          LeaderboardWindow.monthly,
        ],
      );
    });

    test('and recovers from a failure', () async {
      final ({LeaderboardCubit cubit, _Repo repo}) h = harness(
        const Result<LeaderboardBoard>.failure(
          Failure(kind: FailureKind.server, message: 'HTTP 500'),
        ),
      );
      await h.cubit.load(LeaderboardWindow.weekly);
      expect(h.cubit.state.status, LeaderboardStatus.failed);

      h.repo.result = const Result<LeaderboardBoard>.success(populated);
      await h.cubit.retry();

      expect(h.cubit.state.status, LeaderboardStatus.ready);
      expect(h.cubit.state.board, populated);
      expect(h.cubit.state.failure, isNull);
    });
  });
}
