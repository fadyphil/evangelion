import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';

/// A cohort's ranking.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/leaderboard/`
///
/// Two consumers, which is §3's placement test: `/`'s compact card reads the same
/// board as `/leaderboard`'s full list, in the same window. A port inside
/// `features/leaderboard` would have to be imported by `features/home`, which §3
/// forbids with no exceptions and `tool/verify_purity.sh` Gate 2 fails on the line.
///
/// It is a **separate port from [ReadingRepository]** rather than a method on it, and
/// §3's ISP row is the reason. `today()` is a 200 whose body carries verses and
/// questions for one reading; `board()` is a 200 carrying a ranked array whose keys are
/// inconsistent with each other (`userId` camelCase, everything else snake_case). A
/// client wanting only a ranking would have to satisfy an interface whose other method
/// names two types it does not use.
///
/// ## THE HEADERS ARE THE INTERCEPTOR'S, AND THE GROUP IS NOT THE READER'S CHOICE
///
/// `GET /api/v1/leaderboard?window=…&limit=…` takes no path parameters. The cohort
/// comes from `X-Group-Id` and the reader's own position from `X-User-Id`, both added
/// by `IdentityHeadersInterceptor`. `X-Group-Id` is **required by the server's schema** —
/// omitting it is `400 headers must have required property 'x-group-id'` — so no method
/// here can be called without it, and none takes a group argument to get it wrong.
///
/// ## WHAT AN IMPLEMENTATION OWES (§3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`. An exception crossing this
///   seam reaches `LeaderboardCubit`, where nothing catches it, and the list spins
///   forever instead of the reader being offered a retry.
/// * **Always return a [Result]**, including for success.
/// * **An unreadable body is [FailureKind.serialization]**, not a default. The server
///   speaks two different key casings in one object and could grow a fourth window;
///   `LeaderboardWindow.fromCode` returning `null` is what turns that into a refusal
///   instead of a confident wrong answer.
/// * **An empty ranking is a success with no rows.** It is the seeded backend's actual
///   answer, not a fault. See [LeaderboardBoard.rows].
abstract interface class LeaderboardRepository {
  /// The cohort ranking for [window], capped at [limit] rows.
  ///
  /// [limit] is required rather than defaulted because the two callers want
  /// genuinely different amounts — a three-row card and a fifty-row screen — and a
  /// default would let a call site silently receive the other's. It is a **string** on
  /// the wire (`type: 'string'` in the server's querystring schema, parsed with
  /// `parseInt`), which is why [LeaderboardMapper] owns the interpolation.
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  });
}
