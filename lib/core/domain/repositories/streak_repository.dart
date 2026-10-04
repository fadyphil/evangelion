import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';

/// The reader's streak, as the outside world reports it.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/home/`
///
/// Two consumers, which is §3's placement test: `/`'s top-bar flame reads
/// [StreakSummary.currentStreak], and Phase 8's `/result` reads the same summary
/// for its streak tile and its `StreakPill`. A port inside `features/home` would
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
/// `GET /api/v1/streak/summary` is the one endpoint that **requires**
/// `X-User-Id`: absent is a 400 and empty is a 401 (AGENT_CONTEXT §5, re-verified
/// in Phase 5's decision 14). `GET /readings/today/{lang}` does not require it at
/// all — 200 without it. The interceptor sends all three headers on every request
/// unconditionally, which is correct for both and costs nothing, so **nothing in
/// this port varies by endpoint** and no caller has to remember which route
/// needs what.
///
/// ## WHAT AN IMPLEMENTATION OWES (§3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`. An exception crossing
///   this seam reaches `HomeBloc`, where nothing catches it, and the flame spins
///   forever instead of the reader being offered a retry.
/// * **Always return a [Result]**, including for success.
/// * **An unreadable `today_status` is `FailureKind.serialization`,** not a
///   default. `StreakTodayStatus.fromCode` returns `null` for a value outside its
///   four, and the reason is on that function: defaulting would report *nothing
///   done today* for a server that said something this client does not
///   understand.
abstract interface class StreakRepository {
  /// The reader's streak summary.
  ///
  /// `GET /api/v1/streak/summary`. No parameters: the endpoint identifies the
  /// reader by the `X-User-Id` header the interceptor adds, and there is no
  /// `?date=` — a summary of *today* has no date to choose.
  Future<Result<StreakSummary>> summary();
}
