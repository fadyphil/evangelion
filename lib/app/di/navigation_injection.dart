import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/navigation/auth_status.dart';

/// The **Flutter half** of the object graph: the auth seam and the router.
///
/// ## WHY THIS IS NOT A `@MODULE` IN `injection.dart`'S GRAPH
///
/// `injection.dart` is required to be Flutter-free, and not just in the shallow
/// sense of "has no `import 'package:flutter/…'`": `injection_test.dart` walks
/// its whole transitive **project-local** import graph and fails if anything in
/// the closure imports Flutter. A generated `injection.config.dart` imports every
/// `@module` in the package, so registering the router from a module would put
/// `app_router.dart` — which names all six `*Route` classes and therefore reaches
/// `package:flutter/material.dart` through the generated route files — inside
/// that closure, and the existing gate would go red. Phase 1 found that gate
/// defeated by a single `export … show X;` line, so it is not one to route
/// around.
///
/// Both requirements are otherwise legitimate and neither may be weakened, so
/// the graph splits along the line that already exists in it: the pure-Dart half
/// keeps its generated `@InjectableInit`, and the half that genuinely needs the
/// framework is registered by hand here. `06-navigation.md` §8's requirement —
/// "registered as a factory that reads the session from the `getIt` instance" —
/// is honoured; only the file differs from the plan, and `core_module.dart` says
/// so where the plan's file map would have put it.
///
/// WHAT THIS COSTS, STATED PLAINLY: three registrations are now written by hand
/// instead of generated, so `injection.config.dart` no longer shows them in a
/// diff. That is the price of the purity gate, taken knowingly, and it is why
/// `navigation_injection_test.dart` exercises this function as behaviour —
/// presence, lifetime, identity — rather than trusting the source.
///
/// ## WHY `AppRouter` IS A LAZY SINGLETON AND NOT A FACTORY
///
/// `06-navigation.md` §8 warns against a second `AppRouter` existing alongside
/// the injected one "with a stale bloc". A get_it `@factory` guarantees exactly
/// that: `getIt<AppRouter>()` hands back a *new* router every call, only one of
/// which is the one `app.dart` mounted, and any other caller — a test, a future
/// screen, a debug tool — gets an object with its own `navigatorKey` and no
/// `Navigator` behind it.
///
/// Mutation-checked: rewriting this registration to a factory turns exactly the
/// identity assertions in `navigation_injection_test.dart` red, and the failure
/// prints two routers with identical `toString` — which is the whole difficulty
/// of this bug, since nothing about either object looks wrong.
///
/// The one sharp edge: the provider reads [AuthStatus] from the locator at
/// **construction** time, so re-registering `AuthStatus` after the router exists
/// would leave the router holding the previous one. Phase 5 must therefore
/// register the bloc-backed `AuthStatus` *before* anything resolves `AppRouter`,
/// which `bootstrapApp`'s ordering already guarantees. The consequence is
/// asserted in `navigation_injection_test.dart` rather than left to this comment.
///
/// ## WHAT PHASE 5 REPLACES
///
/// Both of the first two registrations are placeholders, and both are labelled as
/// such at their declarations. Phase 5 replaces [AuthStatus] with one reading
/// `AuthBloc.state`, and replaces the listenable with
/// `ReevaluateListenable.stream(authBloc.stream)` so a sign-out re-evaluates the
/// stack. Nothing in `app_router.dart`, `auth_guard.dart` or `app.dart` changes
/// to do it — that is the whole point of the seam.
///
/// ## THE PLACEHOLDERS ARE PINNED BEHAVIOURALLY, BECAUSE THEY ARE THE TEMPLATE
///
/// Two properties of `_NoAuthChanges` are asserted by *executing* it rather than
/// by reading it, and both are properties the Phase 5 replacement must keep:
///
///  * **it never announces anything.** `navigation_injection_test.dart` subscribes,
///    gives the event loop two turns, and asserts the count is still zero. An
///    earlier version of that test asserted only that the object was non-null and
///    alive while its name claimed silence, so a placeholder that fired on
///    construction passed. That matters because `ReevaluateListenable.stream(…)` is
///    a different shape with the same contract, and a placeholder that fires is the
///    wrong shape to copy.
///  * **`AuthStatus` reports no session**, so a cold launch reaches `/login`. Phase
///    5's replacement must not report `true` before its bloc says so, because the
///    guard acts on that answer.
///
/// And one property of the seam they do NOT own, which is worth stating because it
/// is the one that bites: `AuthGuard` latches its redirect's `onResult`, so a
/// sign-in control that fires twice — an `onPressed` plus the form's
/// `onSubmitted`, or a double tap — is harmless. See `auth_guard.dart`. Phase 5
/// therefore does not have to make "exactly once" true at the call site, though it
/// should still try.
void configureNavigation() {
  getIt
    ..registerLazySingleton<AuthStatus>(_NoSession.new)
    ..registerLazySingleton<ReevaluateListenable>(_NoAuthChanges.new)
    ..registerLazySingleton<AppRouter>(
      () => AppRouter(getIt<AuthStatus>(), getIt<ReevaluateListenable>()),
    );
}

/// Phase 4's [AuthStatus]: there is no session, ever.
///
/// Not a stub pretending otherwise. AGENT_CONTEXT §2, decision 3 fixes login as
/// UI-only over a `FakeAuthRepository`, and that repository is Phase 5's — so
/// today there is nothing that *could* produce a session, and reporting one would
/// be a lie the guard would then act on.
///
/// It is also the state a cold launch is in anyway: `/` is the initial route, the
/// guard asks this, gets `false`, and redirects to `/login` — which is the app's
/// documented entry point. So the app opens on the login screen for the right
/// reason rather than by a special case.
final class _NoSession implements AuthStatus {
  const _NoSession();

  @override
  bool get isAuthenticated => false;
}

/// Phase 4's auth-change signal: nothing ever changes, so nothing re-evaluates.
///
/// A bare [ReevaluateListenable] rather than `ReevaluateListenable.stream(...)`
/// over a stream nothing writes to. Both would be equally silent today; this one
/// has no subscription to leak, and it cannot accidentally start notifying
/// before Phase 5 wires the real signal.
///
/// `AppRouter.dispose()` disposes it, which is why it is safe for the router to
/// own one — see that getter's doc comment.
final class _NoAuthChanges extends ReevaluateListenable {}
