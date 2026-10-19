import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/cheer_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

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

/// A repository whose answers come back **in the order the test says**, not in
/// the order they were asked for.
///
/// `_Repo` above answers in the order it was asked, so it can never reach the
/// state this fake exists for: two requests in flight at once, the older one
/// answering last.
final class _OutOfOrderRepo implements LeaderboardRepository {
  /// The pending answer for each window, keyed by the window that was asked for.
  final Map<LeaderboardWindow, Completer<Result<LeaderboardBoard>>> pending =
      <LeaderboardWindow, Completer<Result<LeaderboardBoard>>>{};

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) {
    final Completer<Result<LeaderboardBoard>> completer =
        Completer<Result<LeaderboardBoard>>();
    pending[window] = completer;
    return completer.future;
  }
}

/// The cheer port over one in-memory set, with a configurable failure arm.
final class _Cheers implements CheerRepository {
  _Cheers({
    Set<String>? stored,
    this.writeFails = false,
    this.readFails = false,
  }) : stored = stored ?? <String>{};

  final Set<String> stored;
  bool writeFails;
  bool readFails;

  /// Every id the cubit actually sent to the port, including refused ones.
  final List<String> attempts = <String>[];

  @override
  Future<Result<Set<String>>> cheeredUserIds() async {
    if (readFails) {
      return const Left<Failure, Set<String>>(
        Failure(kind: FailureKind.network, message: 'Could not read cheers.'),
      );
    }
    return Result<Set<String>>.of(Set<String>.of(stored));
  }

  @override
  Future<Result<void>> cheer(String userId) async {
    attempts.add(userId);
    if (writeFails) {
      return const Left<Failure, void>(
        Failure(kind: FailureKind.server, message: 'HTTP 500'),
      );
    }
    stored.add(userId);
    return const Right<Failure, void>(null);
  }
}

/// The auth port, with the two write arms unreachable from this screen.
final class _Auth implements AuthRepository {
  _Auth(this.result);

  Result<AuthSession> result;

  @override
  Future<Result<AuthSession>> getCurrentSession() async => result;

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async => result;

  @override
  Future<Result<void>> signOut() async => const Right<Failure, void>(null);
}

/// The seeded session, so a resolved reader name is the app's real fallback and not
/// the prototype's hard-coded `Mariam Hanna`.
final AuthSession session = AuthSession(
  userId: '11111111-1111-1111-1111-111111111111',
  email: 'david@example.test',
  displayName: 'David Mina',
  initials: 'DM',
  createdAt: DateTime.utc(2026),
);

/// A cubit over the three fakes, with the teardown registered.
({LeaderboardCubit cubit, _Repo repo, _Cheers cheers, _Auth auth}) harness(
  Result<LeaderboardBoard> answer, {
  Set<String>? cheered,
  bool cheerWriteFails = false,
  bool cheerReadFails = false,
  Result<AuthSession>? authAnswer,
}) {
  final _Repo repo = _Repo(answer);
  final _Cheers cheers = _Cheers(
    stored: cheered,
    writeFails: cheerWriteFails,
    readFails: cheerReadFails,
  );
  final _Auth auth = _Auth(authAnswer ?? Right<Failure, AuthSession>(session));
  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: LoadLeaderboard(repo),
    getReaderSession: GetBoardReaderSession(auth),
    cheerRepository: cheers,
  );
  addTearDown(cubit.close);
  return (cubit: cubit, repo: repo, cheers: cheers, auth: auth);
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
    LeaderboardRow(
      rank: 1,
      score: 80,
      initials: 'PG',
      userId: 'peter',
      fullName: 'Peter George (Grade 6)',
      currentStreak: 7,
    ),
    LeaderboardRow(
      rank: 2,
      score: 50,
      initials: 'DM',
      userId: 'david',
      fullName: 'David Mina (Grade 5)',
      currentStreak: 12,
    ),
    LeaderboardRow(
      rank: 3,
      score: 30,
      initials: 'MA',
      userId: 'mark',
      fullName: 'Mark Anton (Grade 5)',
      currentStreak: 3,
    ),
  ],
  standing: LeaderboardStanding(rank: 2, score: 50),
  cohortSize: 5,
);

/// A board the **all-time** window answered with.
///
/// It has to be a *different* board from [_monthly] and not merely a different
/// `window` field, so that a stale response landing on screen is visible as
/// the wrong rows rather than as a label.
const LeaderboardBoard _allTime = LeaderboardBoard(
  window: LeaderboardWindow.allTime,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 900,
      initials: 'PG',
      userId: 'peter',
      fullName: 'Peter George (Grade 6)',
      currentStreak: 7,
    ),
  ],
  standing: LeaderboardStanding(rank: 1, score: 900),
  cohortSize: 5,
);

/// A board the **monthly** window answered with.
const LeaderboardBoard _monthly = LeaderboardBoard(
  window: LeaderboardWindow.monthly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 42,
      initials: 'MA',
      userId: 'mark',
      fullName: 'Mark Anton (Grade 5)',
      currentStreak: 3,
    ),
  ],
  standing: LeaderboardStanding(rank: 1, score: 42),
  cohortSize: 5,
);

void main() {
  group('a cold cubit', () {
    test('is loading, light, uncheered, on the weekly window', () {
      final h = harness(const Right<Failure, LeaderboardBoard>(empty));
      expect(h.cubit.state.status, LeaderboardStatus.loading);
      expect(h.cubit.state.window, LeaderboardWindow.weekly);
      expect(h.cubit.state.board, isNull);
      expect(h.cubit.state.failure, isNull);
      expect(h.cubit.state.metric, LeaderboardMetric.light);
      expect(h.cubit.state.cheered, isEmpty);
      expect(h.cubit.state.readerName, isNull);
    });
  });

  group('load', () {
    test("asks for the server's own limit, not a display count", () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      await h.cubit.load(LeaderboardWindow.monthly);

      expect(h.repo.queries.single.window, LeaderboardWindow.monthly);
      // 50 is the server's default for the querystring parameter, and a cap that did
      // **not** bind is the only condition under which `cohortSize` is provable.
      expect(h.repo.queries.single.limit, LeaderboardCubit.rowLimit);
      expect(h.repo.queries.single.limit, 50);
    });

    test('and becomes ready carrying the board', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
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
        // "This month" containing this week's numbers.
        final h = harness(const Right<Failure, LeaderboardBoard>(populated));
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
      final h = harness(const Left<Failure, LeaderboardBoard>(failure));
      await h.cubit.load(LeaderboardWindow.weekly);

      expect(h.cubit.state.status, LeaderboardStatus.failed);
      expect(h.cubit.state.failure, failure);
      expect(h.cubit.state.board, isNull);
    });

    test('and the failure does not disturb the window on screen', () async {
      final h = harness(
        const Left<Failure, LeaderboardBoard>(
          Failure(kind: FailureKind.timeout, message: 'The request timed out.'),
        ),
      );
      await h.cubit.load(LeaderboardWindow.allTime);

      expect(h.cubit.state.window, LeaderboardWindow.allTime);
    });

    test('mirrors the session\'s cheers into the state', () async {
      final h = harness(
        const Right<Failure, LeaderboardBoard>(populated),
        cheered: <String>{'peter'},
      );
      await h.cubit.load(LeaderboardWindow.weekly);

      expect(h.cubit.state.cheered, <String>{'peter'});
    });

    test('and keeps the cheered marks the reader just sent', () async {
      // `cheered` is declared once outside the render (`:1066`) and a scope change
      // must not clear it. The port's read answers the same set, and the cubit must
      // not drop an in-flight cheer because the read raced it.
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      await h.cubit.load(LeaderboardWindow.weekly);
      await h.cubit.cheer('mark');

      await h.cubit.load(LeaderboardWindow.monthly);

      expect(h.cubit.state.cheered, contains('mark'));
    });

    test(
      'a later failed cheer read preserves the set already in hand',
      () async {
        final h = harness(
          const Right<Failure, LeaderboardBoard>(populated),
          cheered: <String>{'peter'},
        );
        await h.cubit.load(LeaderboardWindow.weekly);
        expect(h.cubit.state.cheered, <String>{'peter'});

        h.cheers.readFails = true;
        await h.cubit.load(LeaderboardWindow.monthly);

        expect(h.cubit.state.cheered, <String>{'peter'});
      },
    );

    test('resolves the reader\'s name through the auth port', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      await h.cubit.load(LeaderboardWindow.weekly);

      expect(h.cubit.state.readerName, 'David Mina');
    });

    test(
      'and an unreadable session leaves it null, never the prototype name',
      () async {
        final h = harness(
          const Right<Failure, LeaderboardBoard>(populated),
          authAnswer: const Left<Failure, AuthSession>(
            Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
          ),
        );
        await h.cubit.load(LeaderboardWindow.weekly);

        expect(h.cubit.state.readerName, isNull);
      },
    );
  });

  group('two requests in flight at once', () {
    // ## WHY THIS GROUP EXISTS
    //
    // A reader who taps "month" and then "all" fires **two** loads, and the one
    // that started first is not the one that answers first. Without a guard the
    // cubit would render the **monthly** rows under an "all" heading — the exact
    // confusion `LeaderboardBoard.window` exists to catch, produced by the client
    // rather than caught by it.
    //
    // The repository here answers in the order the **test** says, which is the
    // whole point: a fake that always answers in the order it was asked cannot
    // reach this state at all.
    test(
      'the stale response is dropped, not rendered under the new heading',
      () async {
        final _OutOfOrderRepo repo = _OutOfOrderRepo();
        final _Cheers cheers = _Cheers();
        final _Auth auth = _Auth(Right<Failure, AuthSession>(session));
        final LeaderboardCubit cubit = LeaderboardCubit(
          loadLeaderboard: LoadLeaderboard(repo),
          getReaderSession: GetBoardReaderSession(auth),
          cheerRepository: cheers,
        );
        addTearDown(cubit.close);

        unawaited(cubit.load(LeaderboardWindow.monthly));
        await Future<void>.delayed(Duration.zero);
        unawaited(cubit.load(LeaderboardWindow.allTime));
        await Future<void>.delayed(Duration.zero);

        expect(repo.pending.keys, hasLength(2));

        // The **all-time** answer lands first.
        repo.pending[LeaderboardWindow.allTime]!.complete(
          const Right<Failure, LeaderboardBoard>(_allTime),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, LeaderboardStatus.ready);
        expect(cubit.state.board?.window, LeaderboardWindow.allTime);

        // And now the **monthly** one — the stale one.
        repo.pending[LeaderboardWindow.monthly]!.complete(
          const Right<Failure, LeaderboardBoard>(_monthly),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.board?.window,
          LeaderboardWindow.allTime,
          reason:
              'the stale monthly response was dropped, so the board under the "all" '
              'heading is still the all-time board',
        );
        expect(
          cubit.state.window,
          LeaderboardWindow.allTime,
          reason: 'and the heading did not move either',
        );
        expect(cubit.state.status, LeaderboardStatus.ready);
      },
    );
  });

  group('retry', () {
    test('re-requests the window on screen, not the default', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(empty));
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
      final h = harness(
        const Left<Failure, LeaderboardBoard>(
          Failure(kind: FailureKind.server, message: 'HTTP 500'),
        ),
      );
      await h.cubit.load(LeaderboardWindow.weekly);
      expect(h.cubit.state.status, LeaderboardStatus.failed);

      h.repo.result = const Right<Failure, LeaderboardBoard>(populated);
      await h.cubit.retry();

      expect(h.cubit.state.status, LeaderboardStatus.ready);
      expect(h.cubit.state.board, populated);
      expect(h.cubit.state.failure, isNull);
    });
  });

  group('selectMetric', () {
    test('switches the metric without a request', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      await h.cubit.load(LeaderboardWindow.weekly);

      h.cubit.selectMetric(LeaderboardMetric.streaks);

      expect(h.cubit.state.metric, LeaderboardMetric.streaks);
      expect(h.repo.queries, hasLength(1));
    });

    test('is silent for the metric already on screen', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      final List<LeaderboardState> seen = <LeaderboardState>[];
      final StreamSubscription<LeaderboardState> subscription = h.cubit.stream
          .listen(seen.add);
      addTearDown(subscription.cancel);

      h.cubit.selectMetric(LeaderboardMetric.light);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    test('survives a window change, on every emit', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      h.cubit.selectMetric(LeaderboardMetric.streaks);

      final List<LeaderboardState> seen = <LeaderboardState>[];
      final StreamSubscription<LeaderboardState> subscription = h.cubit.stream
          .listen(seen.add);
      addTearDown(subscription.cancel);

      await h.cubit.load(LeaderboardWindow.monthly);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isNotEmpty);
      expect(
        seen.every(
          (LeaderboardState s) => s.metric == LeaderboardMetric.streaks,
        ),
        isTrue,
        reason: 'the first frame must not snap the control back to light',
      );
    });
  });

  group('cheer', () {
    test('marks a witness once, and asks the port once', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      await h.cubit.load(LeaderboardWindow.weekly);

      await h.cubit.cheer('peter');
      await h.cubit.cheer('peter');

      expect(h.cubit.state.cheered, <String>{'peter'});
      expect(h.cheers.attempts, <String>['peter']);
    });

    test('a failed cheer marks nothing and can be retried', () async {
      final h = harness(
        const Right<Failure, LeaderboardBoard>(populated),
        cheerWriteFails: true,
      );
      await h.cubit.load(LeaderboardWindow.weekly);

      await h.cubit.cheer('peter');
      expect(h.cubit.state.cheered, isEmpty);

      h.cheers.writeFails = false;
      await h.cubit.cheer('peter');
      expect(h.cubit.state.cheered, <String>{'peter'});
      expect(h.cheers.attempts, <String>['peter', 'peter']);
    });

    test('keeps cheering other witnesses', () async {
      final h = harness(const Right<Failure, LeaderboardBoard>(populated));
      await h.cubit.load(LeaderboardWindow.weekly);

      await h.cubit.cheer('peter');
      await h.cubit.cheer('mark');

      expect(h.cubit.state.cheered, <String>{'peter', 'mark'});
      expect(h.cheers.attempts, <String>['peter', 'mark']);
    });
  });
}
