import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';

/// The reader's streak, as the outside world reports it.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/home/`
///
/// Two consumers, which is §3's placement test: `/`'s streak chip reads
/// [StreakSummary.currentStreak], and `/result` reads the same summary for its
/// streak tile and its [StreakFlame]. A port inside `features/home` would
/// have to be imported by `features/result`, which §3 forbids with no exceptions
/// and Gate 2 fails on the line.
///
/// It is a **separate port from [ReadingRepository]** rather than a method on it,
/// and §3's ISP row is the reason: they are two endpoints, two payloads and two
/// failure modes. `today()` is a 200 whose body carries verses and questions;
/// `summary()` is a 200 carrying eight scalars and a `today_status` vocabulary. A
/// client that wanted only the streak would have to satisfy an interface whose
/// other method names a type it does not use — which is exactly the fat
/// `EvangelionRepository` §3 forbids by name.
///
/// ## THE ENDPOINT AND THE HEADERS DIFFER, AND THAT IS NOT AN ACCIDENT
///
/// `GET /api/v1/streak` and `GET /api/v1/streak/summary` are the **two** endpoints
/// that **require** `X-User-Id`: absent is a 400 and empty is a 401 (AGENT_CONTEXT
/// §5, re-verified in Phase 5's decision 14; `streak.routes.ts:100-103` for the
/// summary, `:1-9` for the history route). `GET /readings/today/{lang}` does not
/// require it at all — 200 without it. The interceptor sends all three headers on
/// every request unconditionally, which is correct for all three and costs nothing,
/// so **nothing in this port varies by endpoint** and no caller has to remember
/// which route needs what.
///
/// ## WHAT AN IMPLEMENTATION OWES (§3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`. An exception crossing
///   this seam reaches `HomeBloc`, where nothing catches it, and the chip spins
///   forever instead of the reader being offered a retry.
/// * **Always return a [Result]**, including for success.
/// * **An unreadable `today_status` is `FailureKind.serialization`,** not a
///   default. `StreakTodayStatus.fromCode` returns `null` for a value outside its
///   four, and the reason is on that function: defaulting would report *nothing
///   done today* for a server that said something this client does not
///   understand.
/// * **A row of [history] that cannot be read is the same kind of failure,** and
///   the whole array fails with it: thirty rows where the fourth is malformed is a
///   response this client cannot partly believe, and `history[0]` — the one row
///   `/` renders — is the row that must be right.
abstract interface class StreakRepository {
  /// The reader's streak summary.
  ///
  /// `GET /api/v1/streak/summary`. No parameters: the endpoint identifies the
  /// reader by the `X-User-Id` header the interceptor adds, and there is no
  /// `?date=` — a summary of *today* has no date to choose.
  Future<Result<StreakSummary>> summary();

  /// The reader's last 30 scheduled days, most recent first.
  ///
  /// `GET /api/v1/streak` — the sibling of [summary] and, on the wire, its
  /// **parent**: `streak.routes.ts:163-172` returns `getUserStreak(...)` minus
  /// `history` and `today_date`, so the two responses cannot disagree about a
  /// scalar. The response adds `history[]` and the endpoint costs a subquery per
  /// row (`streak.service.ts:98-112`), which is why it is not the endpoint
  /// [summary] uses.
  ///
  /// ## WHAT CALLS IT, AND WHY IT IS A SEPARATE METHOD
  ///
  /// `/`'s **last-light card** (`redesign.html:524`), which ADR-0022's fiction
  /// table resolves to "`GET /streak` → `history[0]`", and `/journey`'s rings
  /// (Task 5.6). It is its own method rather than a widened [summary] return type
  /// for §3's ISP row again: a caller that wants the chip's number must not have
  /// to pay for thirty rows, and the server does not offer the two in one payload.
  ///
  /// ## THE ORDER IS THE SERVER'S
  ///
  /// `streak.service.ts:88-96` — `ORDER BY dr.scheduled_date DESC LIMIT 30` — so
  /// index 0 is "the last light" and this port does not sort, does not filter and
  /// does not trim. An implementation that reordered would make "the most recent
  /// scheduled day" a client opinion, and the streak itself is computed from this
  /// same order server-side (`streak.service.ts:153-169`).
  Future<Result<List<StreakHistoryEntry>>> history();
}
