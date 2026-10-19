import 'package:evangelion/core/common/result.dart';

/// The session's cheers for the cohort's witnesses.
///
/// ## THE SHAPE A REAL ENDPOINT WOULD HAVE, AND WHY THERE ISN'T ONE YET
///
/// ADR-0022's fiction table lists the prototype's cheer as **stub** with the
/// replacement named as "a POST endpoint; the prototype's is a local `Set`
/// (`redesign.html:1066`)" (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:58`).
/// The backend ships 14 routes and none of them is a cheer, so this port exists in
/// the shape such an endpoint would take — a per-reader write and a per-session read —
/// and the adapter behind it is a local set until the route arrives. Swapping it is a
/// change to one DI registration and no change to the screen
/// (ADR-0022 `:126-129`, `:207-215`).
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/leaderboard/`
///
/// Today only `/communion` reads it, so the two-consumer placement test does not
/// fire. It is here because a cheer is **not** a leaderboard fact: it is a write to
/// the reader's own session about another reader, and the moment the backend grows
/// the route the other screens that can name a witness — the Journey, the Result
/// modal — may ask the same question. Declaring it here now means that day is a new
/// consumer of an existing seam rather than a move of a feature-owned port that
/// `tool/verify_purity.sh` Gate 2 would then refuse.
///
/// ## WHAT AN IMPLEMENTATION OWES (§3, LSP)
///
/// * **Never throw.** Every fault is a [Result.failure]; a cheer that throws would
///   cross the seam into `LeaderboardCubit` and leave the row unmarked with no
///   explanation.
/// * **A repeated cheer is a success, not a conflict.** The prototype's guard is
///   `if(cheered.has(p.id)) return;` (`redesign.html:1120`), so a second POST for the
///   same witness is idempotent. The screen never sends one — the cubit checks its
///   own set first — but an endpoint that answered 409 here would make a retry after
///   a dropped response fail for the one reason a retry must not.
/// * **The read is the session's set.** No cohort argument: the reader is the
///   authenticated caller, carried by the header interceptor the way the board's
///   `X-User-Id` is.
abstract interface class CheerRepository {
  /// The witnesses this session has already cheered.
  ///
  /// The prototype declares its set once at `redesign.html:1066` and never clears
  /// it, so a re-entry shows the marks it showed before. A real GET would return the
  /// same set from the reader's row; this arm is what the cubit mirrors into its
  /// state on load.
  Future<Result<Set<String>>> cheeredUserIds();

  /// Cheers the witness identified by [userId].
  ///
  /// [userId] is the board row's `userId` — the only stable identifier the endpoint
  /// sends (`leaderboard.routes.ts` builds it from the Redis member id). It is not
  /// the cohort's ordinal, because a rank changes with every submission.
  Future<Result<void>> cheer(String userId);
}
