import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';

/// The one question the auth feature asks the outside world.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/auth/`
///
/// Two consumers, which is the placement test in AGENT_CONTEXT §3: `auth` owns
/// the implementation and the `LoginPage`, and `app` owns the navigation guard
/// that asks whether a session exists (AGENT_CONTEXT §9, decision 9). A port in
/// either feature would have to be imported *across* a feature boundary, which
/// AGENT_CONTEXT §3 forbids with no exceptions and `tool/verify_purity.sh`
/// Gate 2 would fail on the line.
///
/// PURE DART — `core/domain/` is held to no Flutter, Dio or http by Gate 1 — so
/// the guard's dependency stays a one-member interface rather than a bloc.
///
/// ## THE THREE METHODS, AND WHY THERE IS NO `refresh`
///
/// `signIn` and `signOut` are the two halves of a session's life, and
/// `getCurrentSession` is what a cold launch asks ("is anybody already signed
/// in?") so `AuthBloc` can restore rather than force the form. There is no
/// refresh, no token exchange and no logout-everywhere, because there is
/// nothing to refresh: AGENT_CONTEXT §2, decision 3 fixes login as UI-only over
/// a `FakeAuthRepository`, and AGENT_CONTEXT §5 says identity is three headers
/// that nothing validates.
///
/// A future real backend adds those here, in this one file, and no other layer
/// changes. That is what "the port stays real" has to mean for it to be worth
/// anything.
///
/// ## WHAT AN IMPLEMENTATION OWES (AGENT_CONTEXT §3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`. An exception crossing
///   this seam reaches `LoginPage`'s event handler and becomes an unhandled
///   error rather than an error message a player can read.
/// * **Always return a [Result]**, including for success — there is no overload
///   that returns a bare value, so "did this handle the error arm?" is answered
///   by the type rather than by review.
/// * **A bad `X-User-Id` is a typed `Failure`, not an exception.** The backend
///   does not check the shape at all (D2), so a malformed id is the client's own
///   bug and has to surface as something a caller can act on.
abstract interface class AuthRepository {
  /// Signs in with [email] and [password].
  ///
  /// [email] and [password] are **required named** parameters rather than a
  /// params object: `avoid_positional_boolean_parameters` is not the reason —
  /// two strings side by side are not booleans — it is that `(a, b)` at a call
  /// site says nothing about which is which, and a `SignInParams` record would
  /// add a type whose only job is to name two strings.
  ///
  /// The contract when there is no auth endpoint is the interesting part:
  /// `FakeAuthRepository` validates the credentials with
  /// `features/auth/domain`'s rules and returns `Result.failure` for anything
  /// they reject, so the failure path is real code rather than a branch nothing
  /// can reach.
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  });

  /// The session in hand, if there is one.
  ///
  /// A cold launch asks this before showing the form. `Result.failure` means
  /// "no session" **or** "the check itself failed", and the caller must not
  /// distinguish them: with a fake there is no failure mode, and a real adapter
  /// would have to invent one to make the difference matter.
  Future<Result<AuthSession>> getCurrentSession();

  /// Ends the session.
  ///
  /// Returns `Result<void>` rather than `Future<void>` so a failure is
  /// expressible at all. Today it cannot fail, and that is stated by
  /// `FakeAuthRepository` rather than pretended around: a `Future<void>` would
  /// have made "sign out failed" unrepresentable, which is the state a reader
  /// would eventually hit and find silently swallowed.
  Future<Result<void>> signOut();
}
