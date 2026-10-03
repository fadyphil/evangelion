import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';

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
/// `AuthBloc` hits the identical wall, and the mechanism is spelled out here
/// because it is not obvious: `AuthBloc extends Bloc`, and `Bloc` arrives through
/// `package:flutter_bloc/flutter_bloc.dart`, which **re-exports Flutter's widget
/// layer** alongside the bloc. The obvious-looking import —
/// `package:bloc/bloc.dart` — is unavailable, because `bloc` is a *transitive*
/// dependency and AGENT_CONTEXT §8.4 makes promoting it a hard stop. So there is
/// no spelling of "register this bloc" that keeps Flutter out of the closure.
///
/// Both requirements are legitimate and neither may be weakened, so the graph
/// splits along the line that already exists in it: the pure-Dart half keeps its
/// generated `@InjectableInit`, and the half that genuinely needs the framework is
/// registered by hand here. `06-navigation.md` §8's requirement — "registered as a
/// factory that reads the session from the `getIt` instance" — is honoured for the
/// router; only the file differs from the plan, and `core_module.dart` says so
/// where the plan's file map would have put it.
///
/// WHAT THIS COSTS, STATED PLAINLY: four registrations are now written by hand
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
/// ## ORDER: `AuthBloc` BEFORE `AuthStatus`, AND WHY IT IS NOT A LUCKY SEQUENCE
///
/// [AuthStatus]'s provider reads [AuthBloc] out of the locator when it resolves,
/// and `AppRouter`'s provider reads [AuthStatus]. All three are
/// `@lazySingleton`, so nothing runs during this function — the order below is
/// readability, and the real requirement is that `bootstrapApp` calls
/// `configureNavigation()` **after** `configureDependencies()`, which it does
/// (step 3 of 4, `bootstrap.dart`).
///
/// Getting that wrong has a measured cost, not a hypothetical one: re-binding
/// `AuthStatus` after the router exists leaves the router holding the previous
/// one, because the router captured it at construction. `app.dart` reads the
/// locator once, in `build`, so that dependency is visible in the shape of the
/// statement rather than hidden inside it, and
/// `navigation_injection_test.dart` asserts the re-binding case in the failing
/// direction.
///
/// ## WHAT PHASE 4 LEFT BEHIND, AND WHAT REPLACED IT
///
/// Phase 4's `AuthStatus` was `_NoSession` and its change signal was
/// `_NoAuthChanges`, both labelled as placeholders. Both are gone:
///
/// * `_NoSession` is replaced by [BlocAuthStatus], which reads `AuthBloc.state` —
///   a field read, which is exactly what `core/navigation/auth_status.dart`
///   demands of an implementation ("a pure read … cheap, never a fetch, never a
///   validation").
/// * `_NoAuthChanges` is replaced by `ReevaluateListenable.stream(authBloc.stream)`,
///   so a sign-out re-evaluates the whole stack. `_NoAuthChanges` had no
///   subscription to leak and could not accidentally start notifying; the stream
///   wrapper can, which is why `AppRouter.dispose()` disposes it (see that
///   getter's doc) rather than leaving it to the widget tree, which knows nothing
///   about a `ReevaluateListenable` it was handed.
///
/// The placeholder's pinned behaviour is worth keeping in mind as the shape to
/// copy: `navigation_injection_test.dart` subscribes, gives the event loop two
/// turns, and asserts the count is still **zero** — a signal that announces
/// nothing. The replacement is the same contract with a real source.
void configureNavigation() {
  // **Built here, not resolved from the locator** — that is what "hand-registered"
  // means. Nothing generates this registration, so nothing else will construct the
  // bloc; the three use cases *are* generated, so they are resolved from the
  // locator, which is what makes the hand-written half depend on the generated one
  // and not the other way round.
  final AuthBloc authBloc = AuthBloc(
    signIn: getIt<SignIn>(),
    getCurrentSession: getIt<GetCurrentSession>(),
    signOut: getIt<SignOut>(),
  );
  getIt
    // `registerSingleton`, not `registerLazySingleton`: the object is already
    // built, and a lazy singleton whose factory re-ran would hand out a *second*
    // bloc with its own stream — a signal subscribed to a bloc nothing else reads,
    // which is the exact "stale bloc" hazard this file's `AppRouter` section is
    // about.
    ..registerSingleton<AuthBloc>(authBloc)
    ..registerLazySingleton<AuthStatus>(() => BlocAuthStatus(authBloc))
    ..registerLazySingleton<ReevaluateListenable>(
      () => ReevaluateListenable.stream(authBloc.stream),
    )
    ..registerLazySingleton<AppRouter>(
      () => AppRouter(getIt<AuthStatus>(), getIt<ReevaluateListenable>()),
    );
}

/// [AuthStatus] over an [AuthBloc].
///
/// The whole of Phase 4's four contracts is satisfied by three lines, and the
/// length is the point — see `core/navigation/auth_status.dart` for what each
/// contract costs when broken:
///
/// 1. **A pure read.** `state.isSignedIn` is a getter over an enum, so it is
///    cheap and side-effect-free. The guard calls it on every navigation *and*
///    again on every stack re-evaluation; an async answer would turn a redirect
///    into a loading state.
/// 2. **It cannot throw.** `AuthState.isSignedIn` compares an enum against a
///    constant. There is no await, no nullable dereference and no port call, so
///    the escape the guard deliberately does not catch is unreachable from here.
/// 3. **It is bound before the router resolves it**, by `configureNavigation`'s
///    order and by `bootstrapApp`'s.
/// 4. **It is not a mirror.** The answer is read from the bloc's current state on
///    every call rather than cached, so a bloc that emits between two navigations
///    is reflected immediately — which is the whole reason the signal below exists
///    alongside it.
///
/// **Contract 4 was the one the suite could not see, and the mutation is recorded
/// here because the number is the interesting part.** Freezing the answer at
/// construction — `bool get isAuthenticated => _cached`, with `_cached` set in the
/// constructor — left all 1200 tests green at the time this was written. What it
/// cost was measured: the reader signs in, `bloc.state` becomes `signedIn`, the
/// form reports `LoginOutcome.signedIn`, and the guard then asks the seam again on
/// the re-evaluation and gets the stale `false`. The stack settles back on
/// `[LoginRoute]` with `HomePage` never built.
///
/// Two assertions now hold it, both in `navigation_injection_test.dart`: the seam
/// is read in **both** directions around a real session change, and the whole loop
/// is driven end to end over these registrations. The first version of the file's
/// claim was `same(...)` on two `bool`s, which can never be false.
final class BlocAuthStatus implements AuthStatus {
  /// Reports [bloc]'s current state.
  const BlocAuthStatus(this._bloc);

  final AuthBloc _bloc;

  @override
  bool get isAuthenticated => _bloc.state.isSignedIn;
}
