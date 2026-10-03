import 'package:auto_route/auto_route.dart';
// `LoginRoute` lives in the generated router library, not in `login_page.dart`:
// the page declares `LoginPage`, and `@RoutePage()` is what turns it into a route.
// See `app_router.dart` for why that is a separate library.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
// `LoginOutcome` is not in the generated library — the generator re-exports
// nothing, it only names the page's own types. `LoginRoute` comes from the `.gr`
// library because the generator declares it; the enum the callback carries is
// declared by hand in the page.
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';

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
/// and only the top one carries a page. Measured against `AppRouter` in
/// `auth_guard_test.dart`, which is the only place any of this is asserted:
///
///  * `pushAll([QuizRoute(), ResultRoute()])` while unauthenticated leaves the
///    stack at `[LoginRoute, LoginRoute]` — and exactly **one** `LoginPage` in
///    the tree, because the lower login route never had a page built for it.
///  * The first `onResult(LoginOutcome.signedIn)` then lands **both** routes:
///    `[LoginRoute, QuizRoute, ResultRoute]`, with `/result` on screen. So the
///    first resolver really is completed and the navigation it belonged to really
///    does complete — an earlier version of this comment claimed that resolving
///    the first "pops one of them and completes only that navigation", and that
///    does not reproduce.
///  * What is left over is the **second** login redirect: no page holds its
///    `onResult`, so nothing in the app can reach it, and the only thing that
///    still can is re-entering the first guard's seam.
///
/// The latch in [_redirectToLogin] does not fix that and is not meant to — it
/// makes a second call harmless rather than making the orphan reachable.
/// `reevaluateNext: false` versus `true` changes nothing here; both were measured.
///
/// Nothing in this phase calls `pushAll` across the guard, so this is a note for
/// the phase that first does (Phase 6 or 7, when home/reading/quiz start chaining
/// pushes) rather than a fix invented here.
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
        _redirectToLogin(resolver);
    }
  }

  /// Pushes `/login` and leaves this navigation **pending** until it answers.
  ///
  /// ## THE LATCH, AND WHY IT LIVES HERE
  ///
  /// A [NavigationResolver] may be completed exactly once. auto_route asserts
  /// `!isResolved` — `auto_route_guard.dart:211`, the assertion text is literally
  /// "Make sure `resolver.next()` is only called once" — so a second completion is
  /// an unhandled `AssertionError` in debug and a `StateError: Future already
  /// completed` in release and profile, where the assert compiles out. Either way
  /// it is an error escaping a button handler, which is the worst place for one.
  ///
  /// The trigger is a sign-in control, and Phase 5 shipped one: `LoginPage`'s
  /// "Sign in" button and the form's `onSubmitted` both reach for it, as does a
  /// double tap while the first call is still settling. They do not yet reach
  /// *this* guard — `LoginPage` reports through an `onResult` callback and
  /// navigates nowhere, deliberately, because wiring the router into the page is
  /// not that page's job. So the latch is protecting a navigation that does not
  /// exist yet, and this comment previously said a button's `onPressed` "both
  /// reach for it" as though it already did. The two facts are both true and it
  /// matters which: the guard is already correct for the case, and the case is
  /// one line away rather than one phase away.
  ///
  /// Nothing in the guard, the page or the tests makes "exactly once" true on its
  /// own — `LoginPage` stated it as a contract for a future author, and a
  /// contract is not a mechanism. The difference matters because the failure is
  /// not exotic: it is the ordinary consequence of a user being in a hurry, and
  /// it would only ever show up in the field.
  ///
  /// So it is a mechanism now, and it lives in this method because this method
  /// owns the resolver: the latch and the thing it protects have the same
  /// lifetime, which is *this navigation*. Latching on the [AuthGuard] instance
  /// would not do — `AppRouter._guards` allocates a fresh guard per route per read
  /// of `routes`, so an instance field would be forgotten immediately.
  ///
  /// Dropping the second call rather than throwing is also what makes the seam
  /// safe to *call* twice from a test: `auth_guard_test.dart` calls it three times
  /// — signed in, signed in again, then cancelled — and asserts that nothing
  /// escapes and that the FIRST answer is the one that took effect, which is the
  /// only form of this property that can be verified.
  void _redirectToLogin(NavigationResolver resolver) {
    var resumed = false;
    resolver.redirectUntil(
      LoginRoute(
        onResult: (LoginOutcome outcome) {
          if (resumed) {
            return;
          }
          resumed = true;
          resolver.resolveNext(
            outcome == LoginOutcome.signedIn,
            reevaluateNext: false,
          );
        },
      ),
    );
  }
}
