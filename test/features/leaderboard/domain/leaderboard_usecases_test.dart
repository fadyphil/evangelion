import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/home/domain/usecases/load_leaderboard_preview.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what it was asked for, so the assertions can be about the *request* rather
/// than about the return value — which for a pass-through is the only thing it has.
final class _RecordingRepository implements LeaderboardRepository {
  _RecordingRepository([this.answer]);

  final Result<LeaderboardBoard>? answer;
  final List<({LeaderboardWindow window, int limit})> calls =
      <({LeaderboardWindow window, int limit})>[];

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    calls.add((window: window, limit: limit));
    return answer ??
        const Result<LeaderboardBoard>.success(
          LeaderboardBoard(
            window: LeaderboardWindow.weekly,
            groupId: 3,
            rows: <LeaderboardRow>[],
            standing: null,
          ),
        );
  }
}

void main() {
  const LeaderboardBoard board = LeaderboardBoard(
    window: LeaderboardWindow.monthly,
    groupId: 3,
    rows: <LeaderboardRow>[],
    standing: null,
  );

  group('LoadLeaderboard', () {
    test('passes the window and limit through unchanged', () async {
      final _RecordingRepository repository = _RecordingRepository();
      await LoadLeaderboard(repository)(
        const LeaderboardQuery(window: LeaderboardWindow.monthly, limit: 50),
      );
      expect(repository.calls, <({LeaderboardWindow window, int limit})>[
        (window: LeaderboardWindow.monthly, limit: 50),
      ]);
    });

    test("returns the repository's board byte-identical", () async {
      final _RecordingRepository repository = _RecordingRepository(
        const Result<LeaderboardBoard>.success(board),
      );
      expect(
        await LoadLeaderboard(repository)(
          const LeaderboardQuery(window: LeaderboardWindow.monthly, limit: 50),
        ),
        const Result<LeaderboardBoard>.success(board),
      );
    });

    test("and the repository's failure, unwrapped", () async {
      // The point of a use case that adds nothing: it must not reclassify. A second
      // place that decides what a failure means is a second place to forget.
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      final _RecordingRepository repository = _RecordingRepository(
        const Result<LeaderboardBoard>.failure(failure),
      );
      expect(
        await LoadLeaderboard(repository)(
          const LeaderboardQuery(window: LeaderboardWindow.monthly, limit: 50),
        ),
        const Result<LeaderboardBoard>.failure(failure),
      );
    });
  });

  group('LoadLeaderboardPreview', () {
    test('asks for weekly, three rows, and nothing else', () async {
      final _RecordingRepository repository = _RecordingRepository();
      await LoadLeaderboardPreview(repository)();
      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.window, LeaderboardWindow.weekly);
      expect(repository.calls.single.limit, 3);
    });

    test('and 3 is a wire number, so it is a named constant', () async {
      // Not "whatever the card happens to fit". Asserting the constant's value keeps a
      // later change to the card from silently changing the request.
      expect(kLeaderboardPreviewLimit, 3);
    });

    test("returns the repository's board unchanged", () async {
      final _RecordingRepository repository = _RecordingRepository(
        const Result<LeaderboardBoard>.success(board),
      );
      expect(
        await LoadLeaderboardPreview(repository)(),
        const Result<LeaderboardBoard>.success(board),
      );
    });

    test('and its failure unchanged', () async {
      const Failure failure = Failure(
        kind: FailureKind.timeout,
        message: 'The request timed out.',
      );
      final _RecordingRepository repository = _RecordingRepository(
        const Result<LeaderboardBoard>.failure(failure),
      );
      expect(
        await LoadLeaderboardPreview(repository)(),
        const Result<LeaderboardBoard>.failure(failure),
      );
    });
  });
}
