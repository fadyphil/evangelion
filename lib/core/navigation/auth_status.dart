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
/// (`lib/app/router/`) asks it, and **the composition root** supplies the
/// implementation — `BlocAuthStatus` in `lib/app/di/navigation_injection.dart`. So
/// it is shared, and shared types live in `core/`.
///
/// This paragraph used to say the `auth` feature implements it, and named Phase 5
/// as the phase that would. **The `auth` feature does not implement it and never
/// did** — `features/auth/` has no reference to `AuthStatus`; the implementation is
/// in `lib/app/di/`, beside the four hand-written registrations, because it needs
/// `AuthBloc`, which cannot be generated (recorded decision 17). So the sentence
/// cited a consumer that does not exist, and it is precisely §3's own placement
/// test that would have caught it: the type has one real reader and one real
/// implementer, and neither is `features/auth/`.
///
/// It is also **pure Dart**, which matters twice over: `core/navigation/` is one of
/// the directories `tool/verify_purity.sh` Gate 1 holds to no Flutter, Dio or http —
/// and the guard, which has to live in `lib/app/` because it names `LoginRoute`,
/// cannot be the thing that keeps it honest.
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
  ///
  /// ## A THROW IS UNDEFINED BEHAVIOUR, AND IT IS NOT CAUGHT
  ///
  /// This paragraph is the obligation, stated so it cannot be read as a
  /// preference: **an implementation MUST NOT throw.** The obvious reading of the
  /// sentence above — "cheap, so it will not block" — is worth spelling out
  /// because the guard calls this on a path with no recovery, and there is
  /// measured evidence of what happens when it throws.
  ///
  /// A getter that throws escapes `AuthGuard.onNavigation`, then `checkGuard`, then
  /// `_canNavigate`, then the guarded push, and is never converted into anything.
  /// The result is **no navigation at all**: an empty stack, no page built, and —
  /// on the cold launch, where this is the initial-route resolution rather than a
  /// push — a blank first frame.
  ///
  /// `auth_guard_test.dart` measures the part that can be measured without the
  /// harness fighting back: it drives `pushPath` directly and asserts that the
  /// failure comes out of the `Future` *and* that `router.stack` is empty. The
  /// cold-launch blank frame is measured but NOT asserted, and the reason is worth
  /// recording because it is the harness's, not the app's: a throw escaping the
  /// guard arrives as an **uncaught zone error**, which `flutter_test` reports by
  /// failing the test outright, and `tester.takeException()` returns `null` for
  /// it. So the widget-level form of this claim cannot be made falsifiable — the
  /// test would either fail (proving only that it throws) or have to swallow the
  /// error, which trips the binding's own "unexpected additional errors" assertion.
  /// In a real app the same error reaches `FlutterError.onError`, i.e. the error
  /// console, which is what makes the blank frame diagnosable rather than silent.
  ///
  /// `AuthGuard` does **not** catch it, and that is a decision rather than an
  /// omission:
  ///
  ///  * `analysis_options.yaml` enables both `avoid_catching_errors` and
  ///    `avoid_catches_without_on_clauses`. Catching here would need an `ignore`,
  ///    and this repository's one existing `// ignore:` was removed in Phase 4's
  ///    review for exactly that reason — a suppression justified against a document
  ///    that does not outrank the linter. This would be the second.
  ///  * Failing closed *silently* is worse than failing loudly here. "Redirect to
  ///    login" would be indistinguishable from a genuine logout: the reader cannot
  ///    sign in, or rather can sign in and land straight back at the guard's answer,
  ///    with nothing in the log. A blank frame with the exception delivered to
  ///    `FlutterError.onError` is strictly easier to diagnose.
  ///  * The guard is explicitly **not a security boundary** (§2, decision 3: there
  ///    is no auth endpoint and identity is three unchecked headers), so failing
  ///    closed buys no security and costs diagnosability.
  ///
  /// The obligation therefore sits with the implementation, and in practice it is
  /// Phase 5's: `AuthBloc.state` cannot throw, so a conforming implementation is a
  /// field read and this paragraph is about what a *non*-conforming one would cost.
  bool get isAuthenticated;
}
