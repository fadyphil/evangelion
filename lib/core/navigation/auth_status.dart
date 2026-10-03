/// The one question navigation asks about the session.
///
/// ## WHY THIS IS AN INTERFACE AND NOT A `bool Function()`
///
/// Phase 4 owns routing and Phase 5 owns `AuthBloc`, and this is the seam
/// between them. A bare `bool Function()` would have been one line shorter and
/// completely unnameable: `get_it` resolves by type, and every `bool Function()`
/// in the app would satisfy one registration, so the graph could not say *which*
/// answer it was holding. Naming it makes the registration, the injection and
/// the tests all say "the session".
///
/// ## WHY IT LIVES HERE, INSTEAD OF BESIDE THE GUARD
///
/// Two consumers, which is the placement test in AGENT_CONTEXT §3: the router
/// (`lib/app/router/`) asks it, and the `auth` feature implements it in Phase 5.
/// So it is shared, and shared types live in `core/`. It is also **pure Dart**,
/// which matters twice over: `core/navigation/` is one of the directories
/// `tool/verify_purity.sh` Gate 1 holds to no Flutter, Dio or http — and the
/// guard, which has to live in `lib/app/` because it names `LoginRoute`, cannot
/// be the thing that keeps it honest.
///
/// ## WHAT IT IS NOT
///
/// It is not a security boundary and it is not a session store. There is no
/// auth endpoint on the backend (AGENT_CONTEXT §2, decision 3) — identity is
/// three headers the client sets and nothing validates them. The guard protects
/// navigation flow and nothing else. `isAuthenticated` must therefore be a plain
/// read of whatever the app currently believes, never a validation, a token
/// check or a network call.
abstract interface class AuthStatus {
  /// Whether the app currently believes it has a session.
  ///
  /// MUST be side-effect-free and cheap: the guard calls it on every navigation
  /// and again on every stack re-evaluation, so a value that had to be fetched
  /// would turn a redirect into a loading state.
  bool get isAuthenticated;
}
