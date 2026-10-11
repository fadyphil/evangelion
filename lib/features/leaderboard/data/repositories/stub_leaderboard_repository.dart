import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';

/// A [LeaderboardRepository] that answers from a fixed table, for working on the
/// screens before the cohort can score.
///
/// ## THIS IS STUB DATA AND IT SAYS SO, IN THREE PLACES
///
/// The names below are the backend's own seeded fixtures (`memory_db.ts`), so the
/// monograms on screen are the ones real data produces. Everything else is invented:
/// the scores, the ranks, the cohort size.
///
/// ## WHY IT EXISTS — AND A CORRECTION
///
/// **First draft of this file claimed the leaderboard "is empty and always will be in
/// dev"**, on the grounds that scores only enter Redis via `recordScore` on a
/// successful submission, and submission cannot succeed against the memory fallback
/// because the schemas require UUIDs the fallback does not mint.
///
/// **That was wrong.** `InMemoryRedisFallback`'s **constructor** pre-seeds three
/// children into group 3's weekly, monthly and all-time ZSETs unless `NODE_ENV` is
/// exactly `test` (`src/redis/client.ts:5-33`) — `seedUsers` is Peter George 80, David
/// Mina 50, Mark Anton 30, i.e. the seeded identity at **rank 2 with 50 points**. So a
/// normally-started dev server answers with three real rows, and the earlier empty
/// response this claim was built on came from a process running in a mode that skips the
/// seed.
///
/// The claim was load-bearing twice over: it justified this file *and* it was the stated
/// reason `cohortSize` looked untestable. Measured against a running server:
///
/// ```json
/// {"group_id":3,"window":"weekly","total_ranked":3,
///  "my_standing":{"rank":2,"score":50},
///  "leaderboard":[{"userId":"2222…","score":80,"rank":1,…}]}
/// ```
///
/// Three rows against `limit=50`, so `rowsReturned < limit` and **`cohortSize` is 3** —
/// the card prints `2 / 3` off live data, which is the case the ZCARD rule exists for.
///
/// ## WHAT IT IS STILL FOR
///
/// The seed is **group 3 only** and it is **frozen** — the scores cannot move without a
/// working submission path, so the reader's rank is always 2 and the app can never show
/// the states that matter most: someone dropping in rank, a tie, a `rank: null`
/// unranked reader, or a cohort larger than `limit`. This class answers all of those on
/// demand, which is what makes the screens reviewable before the submission path is
/// fixed.

/// ## HOW IT IS SWITCHED ON, AND WHY IT CANNOT LEAK INTO A RELEASE
///
/// By `--dart-define=USE_STUB_LEADERBOARD=true` only, read through `bool.fromEnvironment`
/// in `leaderboard_module.dart`. Not `kDebugMode`, because that would mean importing
/// `package:flutter/foundation.dart` into the DI graph, and `tool/verify_purity.sh`
/// Gate 1 holds the injection half Flutter-free. `fromEnvironment` is `dart:core`, so
/// the gate stays green and the flag still defaults to `false` in every build that
/// does not name it.
///
/// ## IT IS NOT AN HTTP FAKE
///
/// Nothing here touches dio, so a screen developed against this table has exercised
/// zero of the network path. The mapper's 30-odd refusals — an HTML body from a
/// proxy, an unknown window, a `6.0` score — are covered by
/// `leaderboard_mapper_test.dart` against real fixtures instead, because a stub
/// repository cannot produce a malformed payload.
final class StubLeaderboardRepository implements LeaderboardRepository {
  /// Creates the stub. Stateless and `const`.
  const StubLeaderboardRepository();

  /// The invented standings, highest first.
  ///
  /// The names are the backend's fixtures so the monograms match production; the
  /// scores are chosen to put the seeded reader (`David Mina`, `kSeedUserId`) in
  /// **third**, because third is the interesting case: it is inside the card's three
  /// rows *and* below them, so a card that slices wrongly and a screen that does not
  /// both look wrong.
  static const List<({String name, int score})> _standings =
      <({String name, int score})>[
        (name: 'Peter George (Grade 6)', score: 80),
        (name: 'David Mina (Grade 5)', score: 50),
        (name: 'Mark Anton (Grade 5)', score: 30),
        (name: 'Mariam Botros (Grade 6)', score: 20),
        (name: 'Antonios Farid (Grade 5)', score: 10),
      ];

  /// The reader this stub places, matching the seeded identity's display name.
  static const String _readerName = 'David Mina (Grade 5)';

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    final List<LeaderboardRow> all = <LeaderboardRow>[
      for (int index = 0; index < _standings.length; index++)
        LeaderboardRow(
          rank: index + 1,
          score: _standings[index].score,
          // The **same** rule as the real mapper, not a copy of it. A second
          // implementation of "strip the grade, take first and last" is free to drift,
          // and then the stub would be showing monograms production never produces.
          initials: LeaderboardMapper.initialsOf(_standings[index].name),
        ),
    ];

    final List<LeaderboardRow> page = all.take(limit).toList();

    return Result<LeaderboardBoard>.of(
      LeaderboardBoard(
        window: window,
        groupId: 3,
        rows: page,
        standing: _standingFor(all),
        cohortSize: LeaderboardMapper.cohortSizeOf(
          reportedTotal: page.length,
          rowsReturned: page.length,
          limit: limit,
        ),
      ),
    );
  }

  /// The reader's own row, if it is among the standings.
  ///
  /// `null` when it is not — the same shape as a child who has never scored, so the
  /// "you are not ranked yet" path is reachable by changing one line of this stub
  /// rather than only by the empty board.
  LeaderboardStanding? _standingFor(List<LeaderboardRow> all) {
    for (final ({int rank, String name, int score}) entry
        in <({int rank, String name, int score})>[
          for (int i = 0; i < _standings.length; i++)
            (rank: i + 1, name: _standings[i].name, score: _standings[i].score),
        ]) {
      if (entry.name == _readerName) {
        return LeaderboardStanding(rank: entry.rank, score: entry.score);
      }
    }
    return null;
  }
}
