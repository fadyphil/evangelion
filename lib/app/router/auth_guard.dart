import 'package:auto_route/auto_route.dart';
// `LoginRoute` lives in the generated router library, not in `login_page.dart`:
// the page declares `LoginPage`, and `@RoutePage()` is what turns it into a route.
// See `app_router.dart` for why that is a separate library.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/navigation/auth_status.dart';

/// What [AuthGuard] decided about a navigation.
enum GuardDecision {
  /// There is a session. Let the navigation through.
  allow,

  /// There is no session. Send the user to the login route.
  redirectToLogin,
}

/// The navigation gate on every route except `/login`.
///
/// ## WHAT IT PROTECTS: NAVIGATION FLOW, AND NOTHING ELSE
///
/// `docs/plans/06-navigation.md` §8 is explicit — "the guard protects nothing
/// but navigation flow". There is **no auth endpoint on the backend**
/// (AGENT_CONTEXT §2, decision 3): identity is three headers the client sets and
/// nothing checks them, and `X-User-Role` is decorative even to the server. So a
/// redirect here is a UX affordance, never a security boundary, and this class
/// must not grow a role check, a token validation or a refresh — those would be
/// theatre that reads as defence.
///
/// ## WHY IT ASKS AN [AuthStatus] INSTEAD OF AN `AuthBloc`
///
/// `06-navigation.md` §8 shows the guard reading `AuthBloc` directly, and Phase 4
/// cannot do that: `AuthBloc` is Phase 5's deliverable, and `06-navigation.md`'s
/// own verification for this phase — "pushes `/` unauthenticated and asserts it
/// redirects to `/login`" — is unwriteable without *something* that can be
/// unauthenticated. Pulling a half-built `AuthBloc` forward would have made
/// Phase 4 the owner of auth state it cannot define.
///
/// So the guard depends on [AuthStatus], one method, declared in
/// `core/navigation/auth_status.dart` and pure Dart. Phase 5 supplies the
/// implementation and changes nothing here. See that file for the placement
/// argument and for the contract an implementation must honour.
///
/// ## THE REDIRECT IS RESUMABLE, OR IT IS A TRAP
///
/// `redirectUntil` pushes `/login` and leaves the original navigation
/// **unresolved**. If the guard never completed the resolver, the user's
/// attempt to reach `/` simply vanished and cancelling the login form would
/// strand them on a screen with no route back. `LoginPage.onResult` is what
/// closes it: `true` resumes the interrupted navigation, `false` abandons it.
///
/// `reevaluateNext: false` on both branches. `06-navigation.md` §8 shows the flag
/// without explaining it, so the reasoning is recorded here.
///
/// `resolveNext(…, reevaluateNext: true)` tells auto_route to re-push the
/// *pending* routes of the same navigation event once the resolver completes.
/// Inside `redirectUntil` — where the resolver stays pending until the login page
/// answers — that is a re-entry into this guard from inside this guard. `false`
/// keeps the resume to the one route that was interrupted.
///
/// **WHAT THIS SUITE DOES NOT PIN**, stated because a doc comment that reads like
/// a verified claim is the defect this project keeps repeating: `false` and `true`
/// were both tried against `auth_guard_test.dart` and both leave it green, because
/// every navigation in this phase resumes a *single* route, which has no pending
/// siblings to re-push. The distinction is a property of multi-route
/// navigations, and there is no production call site for one yet — see the known
/// gap below.
///
/// ## KNOWN GAP, RECORDED SO IT IS NOT REDISCOVERED
///
/// A `pushAll` that crosses this guard leaves **one pending redirect per route**,
/// and only the top one is resumable: measured, `pushAll([QuizRoute(),
/// ResultRoute()])` while unauthenticated leaves the stack at
/// `[LoginRoute, LoginRoute]`, and resolving the first `onResult` pops one of them
/// and completes only that navigation — the other stays stuck with an unresolved
/// resolver, and nothing in the app can reach its `onResult`. The difference
/// between `reevaluateNext` false and true does not change this; both were
/// measured. Nothing in this phase calls `pushAll` across the guard, so it is a
/// note for the phase that first does (Phase 6 or 7, when home/reading/quiz start
/// chaining pushes) rather than a fix invented here.
class AuthGuard extends AutoRouteGuard {
  /// Gates navigation on the current [AuthStatus].
  const AuthGuard(this._status);

  final AuthStatus _status;

  /// The guard's decision, as a value.
  ///
  /// Split out of [onNavigation] so the branch can be exercised without a
  /// `Navigator`, which is the only part of this class that is genuinely pure.
  /// The round trip it drives — including the `false` case, which must *not*
  /// resume — is covered end to end in `auth_guard_test.dart`.
  GuardDecision decide() => _status.isAuthenticated
      ? GuardDecision.allow
      : GuardDecision.redirectToLogin;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    switch (decide()) {
      case GuardDecision.allow:
        resolver.resolveNext(true, reevaluateNext: false);
      case GuardDecision.redirectToLogin:
        resolver.redirectUntil(
          LoginRoute(
            onResult: (bool didLogin) =>
                resolver.resolveNext(didLogin, reevaluateNext: false),
          ),
        );
    }
  }
}
