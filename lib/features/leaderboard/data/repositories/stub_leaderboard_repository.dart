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
/// ## WHY IT EXISTS, WHICH IS NOT "THE BACKEND IS DOWN"
///
/// The endpoint is **up and wired** — `DioLeaderboardRepository` is the default and
/// this class is opt-in. The leaderboard is empty because scores only enter Redis via
/// `leaderboardService.recordScore`, called from `submissions.service.ts:105` on a
/// *successful* submission — and submission cannot succeed against the memory
/// fallback, because `POST /submissions` validates `reading_id` and `question_id` as
/// UUIDs while the fallback mints `reading-group-3-2026-10-04`. Measured empty board:
///
/// ```json
/// {"group_id":3,"window":"weekly","total_ranked":0,"my_standing":null,"leaderboard":[]}
/// ```
///
/// So the empty state is not an edge case to be developed around — it is the **only**
/// state reachable until the submission path is fixed, and a screen designed solely
/// against it would never show a rank, a monogram or a `cohortSize`. This class makes
/// those states reviewable now.
///
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

    return Result<LeaderboardBoard>.success(
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
