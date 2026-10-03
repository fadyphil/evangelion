import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// What the sign-in attempt on `/login` produced.
///
/// ## WHY AN ENUM AND NOT A `bool`
///
/// `avoid_positional_boolean_parameters` is enabled in `analysis_options.yaml`,
/// and the obvious shape — `void Function(bool didLogin)` — is exactly what it
/// forbids. The first attempt satisfied the lint by suppression: this
/// repository's only `// ignore:`, justified against `06-navigation.md` §8's
/// `onResult(true)` spelling and this phase's verification line "resumes on
/// `onResult(true)`".
///
/// That justification does not hold, and the reason is not a matter of taste.
/// AGENTS.md makes `docs/agents/AGENT_CONTEXT.md` the authority which "overrides
/// any conflicting statement anywhere else in this repository, including … anything
/// under `docs/plans/`", and §4 makes zero analyzer issues the objective gate for
/// types, lints and deprecation alike. So a document that does not outrank the
/// linter cannot justify an ignore against it — and because Dart has no
/// `unnecessary_ignore` lint, an ignore nobody needs could not have been
/// *detected* either. It would have sat here looking load-bearing.
///
/// A named parameter would have satisfied the lint while keeping the `bool`:
/// `onResult(didLogin: true)`. It was rejected because the boolean is not the
/// defect. `onResult(didLogin: true)` is the same hazard as `onResult(true)` — the
/// reader still has to work out which of two flags is meant — and it would have
/// spelt the call site in a form neither document uses. An enum removes the
/// hazard and the suppression together:
///
/// ```dart
/// onResult(LoginOutcome.signedIn)   // reads as what it is
/// onResult(LoginOutcome.cancelled)
/// ```
///
/// Hiding the `bool` behind a `ValueChanged<bool>` alias would also have silenced
/// the diagnostic, but that is a rename rather than a change, which is the shape
/// of "a gate that cannot fail".
///
/// ## WHY NOT TWO CALLBACKS
///
/// A `onResult` plus, say, an `onCancel` would have sidestepped the lint too and
/// would have been strictly worse. Two callbacks means the reader has to work out
/// *which one resumes*, which is a weaker statement than "this one resumes" — and
/// "fires exactly once" is the property the guard's latch is built on (see
/// `auth_guard.dart`). One callback, one call site, one guarantee.
enum LoginOutcome {
  /// The reader signed in. Resume whatever navigation was interrupted.
  signedIn,

  /// The reader gave up. Abandon it and leave them where they are.
  cancelled,
}

/// Reports the outcome of the sign-in attempt to whoever redirected here.
///
/// `signedIn` resumes the navigation the guard interrupted; `cancelled` abandons
/// it. See [LoginOutcome] for why this is a callback carrying an enum rather than
/// one carrying a boolean.
typedef LoginResultCallback = void Function(LoginOutcome outcome);

/// Stub for `/login`. Phase 5 replaces this with the real onboarding + login
/// screen backed by `FakeAuthRepository`.
///
/// It exists so the composition root has a pre-auth entry point from Phase 0c
/// onward. It is deliberately NOT a login form: a plausible-looking form built
/// now would be thrown away by Phase 5, and every field, validator and error
/// message invented here would be work with no consumer. What it does give the
/// later phases is the shape Phase 4 wires up — a `Scaffold` with an app bar and
/// a body — and a screen that names its own route, so a screenshot or a test
/// failure says which screen it came from.
///
/// The route name comes from [AppRoutes] rather than a literal so the page and
/// the router cannot disagree about the path.
///
/// ## THE ONE CONSTRUCTOR PARAMETER, AND WHY IT IS STILL A STUB
///
/// [onResult] is the seam [AuthGuard] needs: the guard redirects an
/// unauthenticated user here and must be able to resume the navigation it
/// interrupted, or the user is stranded on the login screen with no route back
/// (`docs/plans/06-navigation.md` §8). It is a bare `void Function(bool)` and
/// nothing more — no `AuthBloc`, no `AuthRepository`, no `TextField`, no
/// validation — because all of those are Phase 5's, and a parameter this phase
/// cannot honour is worse than one it can.
///
/// `onResult` is **nullable and defaults to null** so the page still mounts as a
/// bare widget. A required parameter would make `const LoginPage()` — the form
/// `app_test.dart`, every page test and any `MaterialApp(home:)` in this repo
/// uses today — a compile error, which would force a no-op lambda into every
/// one of them.
///
/// ## THE TRAP: A NULL `onResult` IS REACHABLE FROM THE APP'S OWN ROUTE TABLE
///
/// An earlier version of this comment claimed the null case "is only reachable by
/// someone rendering the page outside a redirect". That is false, and the way it
/// is false is one line of production behaviour away.
///
/// `/login` is the one route with **no guard** — a gate in front of it would
/// redirect to itself forever — so `pushPath('/login')` builds this page with no
/// `onResult` at all. Measured on `AppRouter` with no session: the push leaves the
/// stack at `[LoginRoute, LoginRoute]` (the redirect's, then the deep link's), the
/// pushed page carries `onResult == null`, and the page that *does* carry the
/// resumable callback is the one underneath, unreachable behind it. A cold deep
/// push of `/login` — a deep link, a notification tap, a restored navigation state
/// — is the app's own route table, not somebody hand-building a widget.
///
/// `app_router_test.dart` holds the measurement, so this is a recorded fact rather
/// than a warning to remember.
///
/// So the obligation is on Phase 5 and it is not optional: **the real screen must
/// work with a null [onResult]**, because a null one is an ordinary outcome of
/// this route, not a mistake. It is not solved by giving `LoginRoute` a default
/// no-op callback here, which would make the trap invisible — a page reporting an
/// outcome to nobody would look identical to one reporting it to the guard.
///
/// Phase 5's other contract: the real screen calls [onResult] with the outcome of
/// the sign-in attempt, exactly once, and is not responsible for navigating — the
/// guard resumes, which is what makes the flow re-entrant. "Exactly once" is a
/// mechanism now, not a promise: `AuthGuard` latches, so a second call is dropped
/// rather than throwing.
@RoutePage()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.onResult});

  /// Reports the sign-in outcome back to whoever redirected here.
  ///
  /// Null means nobody redirected here — which the app's own route table can
  /// arrange. See the class doc for the measured case; the short version is that
  /// Phase 5's screen has to tolerate it.
  final LoginResultCallback? onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.login)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.login}')),
    );
  }
}
