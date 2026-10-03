import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/di/navigation_injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The navigation graph plus the root widget, as one fixture.
///
/// ## WHY A HARNESS AND NOT A `setUp` IN EACH SUITE
///
/// `EvangelionApp` resolves `AppRouter` out of the locator, so pumping it without
/// the graph registered throws `StateError: AppRouter is not registered` — and
/// that is the *point* of the app's design, so a suite cannot route around it by
/// building a router of its own. Three suites need the same steps (register,
/// pump, settle) and getting the first subtly wrong is how two routers end up in
/// a test, which is the exact hazard `app.dart`'s doc comment is about.
///
/// Same reasoning `test/support/project_import_graph.dart` records: one copy of a
/// fixture, so the copies cannot drift.
Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
  // Guarded, because `configureNavigation()` rejects a duplicate registration and
  // a suite that already configured the graph — `navigation_injection_test.dart` —
  // would otherwise fail here for a reason that has nothing to do with what it is
  // testing. The guard is on *presence*, not on a flag, so it cannot paper over a
  // graph that is missing the router: `isRegistered` would be false and the call
  // would happen.
  if (!getIt.isRegistered<AppRouter>()) {
    configureNavigation();
  }
  await tester.pumpWidget(EvangelionApp(locale: locale));
  await pumpUntilFound(tester, find.byType(LoginPage));
}

/// Advances [tester] in screen-transition steps until [finder] matches.
///
/// ## WHY NOT `pumpAndSettle`, WHICH IS THE OBVIOUS TOOL
///
/// It times out, and the reason is structural rather than incidental:
/// `NeuralMotionScope` hosts three `repeat()`ing `AnimationController`s
/// (float, hue, aurora — `09-quality-gates.md` §13 mitigation 2), so the
/// scheduler always has another frame queued and "settled" never arrives. The
/// same lesson Phase 2 learned about themes in reverse: the fix is not to pump
/// less, it is to pump a *known amount*.
///
/// The step is [EvaMotion.screen] — 250ms, the length of the route transition
/// the router actually runs, so each pump covers exactly one transition rather
/// than an arbitrary slice of it.
///
/// ## WHY A BOUNDED LOOP RATHER THAN A FIXED NUMBER OF PUMPS
///
/// A cold launch needs two frames (mount, then the guard's asynchronous redirect
/// pushes the login route); resuming a redirect after `onResult(true)` needs
/// three (the stack updates, then the incoming page mounts, then the login route
/// finishes animating out). Hard-coding either count would be a number that is
/// wrong the moment auto_route changes when a removal animation starts — and a
/// wrong constant here fails as a flaky "expected LoginPage, found none" in a
/// suite three files away from the cause.
///
/// [limit] is 12 frames — 3 seconds, three orders of magnitude past any of the
/// sequences above — and the caller asserts on the finder afterwards, so a
/// give-up is a test failure rather than a silent pass.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int limit = 12,
}) async {
  for (int frame = 0; frame < limit; frame++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(EvaMotion.screen);
  }
}

/// Advances [tester] until [finder] no longer matches.
///
/// The mirror of [pumpUntilFound], and needed for the same reason: a redirect
/// that resumes *removes* a route, and the removal takes a transition of its own,
/// so asserting `findsNothing` one frame after the resume would read a
/// still-animating page as a failure.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int limit = 12,
}) async {
  for (int frame = 0; frame < limit; frame++) {
    if (finder.evaluate().isEmpty) {
      return;
    }
    await tester.pump(EvaMotion.screen);
  }
}

/// The auth-change signal, fired by hand.
///
/// `ReevaluateListenable` rather than `ReevaluateListenable.stream(...)` over a
/// `StreamController`, and the difference is the point: what the router consumes
/// is a `Listenable`, so a test that drives `notifyListeners` directly exercises
/// the whole production contract with nothing in between. Phase 5's real signal
/// is the bloc's stream wrapped in auto_route's own factory.
///
/// It also removes the `close_sinks` dance a `StreamController` would need: a
/// controller created in one place and closed in another is two places to forget,
/// and forgetting one leaks a listener into whichever test runs next.
final class ManualAuthChanges extends ReevaluateListenable {
  /// Announces that the session changed.
  void fire() => notifyListeners();
}

/// A session a test can flip, standing in for Phase 5's `AuthBloc`-backed one.
final class ControllableAuthStatus implements AuthStatus {
  ControllableAuthStatus({this.authenticated = true});

  bool authenticated;

  @override
  bool get isAuthenticated => authenticated;
}

/// The decision every guard on [router] is currently making.
///
/// Read off the live `routes` getter, because that is what the router itself
/// builds on every navigation. `AppRouter` has no public accessor for its guards,
/// and reaching them through the route table is also the only way to see the
/// *per-route* instances — one test's worth of the "`routes` is a getter, so each
/// read makes fresh guards" behaviour the class doc describes.
List<GuardDecision> guardDecisionsOf(AppRouter router) => router.routes
    .expand((AutoRoute route) => route.guards)
    .cast<AuthGuard>()
    .map((AuthGuard guard) => guard.decide())
    .toList();

/// Empties the locator, so each test starts from a clean registration set.
///
/// `GetIt.instance` is a process-wide singleton, so a registration made by one
/// test is visible to every test that runs after it unless something resets it.
/// Called from `setUp` *and* `tearDown`: `setUp` alone leaves a graph behind for
/// whichever suite happens to be collected next, and `configureNavigation()`
/// rejects a duplicate registration, so the failure would surface somewhere
/// unrelated.
Future<void> resetServiceLocator() => getIt.reset();
