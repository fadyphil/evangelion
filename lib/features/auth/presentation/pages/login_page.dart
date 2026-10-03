import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// The outcome of a sign-in attempt, reported back to whoever redirected here.
///
/// [LoginResultCallback] is a one-argument callback carrying one boolean, so
/// `onResult(true)` is unambiguous at the call site — which is the hazard
/// `avoid_positional_boolean_parameters` exists to prevent ("a bare `true` among
/// several arguments"). The lint is suppressed for exactly this one declaration
/// rather than the callback's shape being changed to a named parameter, because
/// two written requirements name the positional spelling:
///
///  * `06-navigation.md` §8 — `LoginRoute(onResult: (didLogin) => …)`, and
///  * this phase's verification — "resumes on `onResult(true)`".
///
/// A named parameter would make both read `({required didLogin})` and
/// `onResult(didLogin: true)`: the same behaviour, a spelling neither document
/// uses, and a callback the guard calls in exactly one place.
///
/// The other way to make this lint-clean — hiding the `bool` behind a
/// `ValueChanged<bool>` alias or an enum — was rejected: it silences the
/// diagnostic without changing the design, which is the shape of "a gate that
/// cannot fail".
// ignore: avoid_positional_boolean_parameters
typedef LoginResultCallback = void Function(bool didLogin);

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
/// one of them. The guard's redirect always supplies one; the null case is only
/// reachable by someone rendering the page outside a redirect.
///
/// Phase 5's contract: the real screen calls [onResult] with the outcome of the
/// sign-in attempt, exactly once, and is not responsible for navigating — the
/// guard resumes, which is what makes the flow re-entrant.
@RoutePage()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.onResult});

  /// Reports the sign-in outcome back to whoever redirected here.
  ///
  /// `true` resumes the navigation the guard interrupted; `false` abandons it
  /// and leaves the user where they are. See the class doc for why this is
  /// nullable.
  final LoginResultCallback? onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.login)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.login}')),
    );
  }
}
