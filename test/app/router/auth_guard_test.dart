import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` classes, reached the way `app_router.dart` reaches them.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

/// A session this phase does not have: the answer is whatever the test says.
///
/// Mutable on purpose. The guard reads the same instance on every navigation and
/// on every stack re-evaluation, so flipping this is how a test simulates a login
/// or a logout without an `AuthBloc` — the seam Phase 5 fills.
///
/// [reads] counts how many times the guard asked. `AuthGuard` reads the status
/// exactly once per invocation, so the counter is a measurement of how many
/// times the guard ran — which is the only way to observe re-evaluation from
/// outside, since `resolver.isReevaluating` is set inside auto_route.
final class FakeAuthStatus implements AuthStatus {
  FakeAuthStatus({this.authenticated = true});

  bool authenticated;

  int reads = 0;

  @override
  bool get isAuthenticated {
    reads++;
    return authenticated;
  }
}

/// The session, its change signal, and the router over both — as one object,
/// because the three have to be the SAME objects.
///
/// A test that built a second status to flip, or a second router to navigate,
/// would not be testing this guard; it would be testing a different app. This
/// class exists because the first draft did exactly that: it constructed
/// `ManualAuthChanges()` twice, once for the field and once for the router, and
/// every sign-out test failed because `announce()` fired a listenable nothing was
/// listening to.
final class AuthHarness {
  AuthHarness._(this.status, this.changes, this.router);

  /// Builds a harness whose session starts [authenticated].
  factory AuthHarness.starting({bool authenticated = false}) {
    final FakeAuthStatus status = FakeAuthStatus(authenticated: authenticated);
    final ManualAuthChanges changes = ManualAuthChanges();

    return AuthHarness._(status, changes, AppRouter(status, changes));
  }

  final FakeAuthStatus status;
  final ManualAuthChanges changes;
  final AppRouter router;

  /// Releases the router, which disposes the signal it owns.
  void release() => router.dispose();

  /// Announces a session change, exactly as Phase 5's bloc will.
  void announce() => changes.fire();
}

/// The shell these widget tests mount.
///
/// Deliberately not `EvangelionApp`: these tests are about the guard, and
/// `EvangelionApp` hard-codes the Eva theme, the locale plumbing and — via the
/// locator — the router itself. `app_test.dart` owns the claim that the real app
/// uses the resolved router.
Widget host(AppRouter router) => MaterialApp.router(
  routerConfig: router.config(reevaluateListenable: router.authChanges),
);

/// Completes the login outcome the guard is waiting on, or fails naming the fact
/// that no login page is on screen.
///
/// Read off the *rendered* `LoginPage` rather than off the `LoginRoute` object:
/// it is the same call the guard's closure makes, so the test drives the
/// production seam rather than a copy of it. The outcome arrives as a NAMED
/// parameter of this test helper — `onResult`'s own signature is positional
/// (`LoginResultCallback`), and `avoid_positional_boolean_parameters` would fail
/// either, so the difference is made at the boundary where the test hands a value
/// in rather than at the production API the plan spells out.
void completeLogin(WidgetTester tester, {required bool didLogin}) {
  final Finder login = find.byType(LoginPage);
  expect(login, findsOneWidget, reason: 'no login page is on screen to resume');

  final LoginResultCallback? onResult = tester
      .widget<LoginPage>(login)
      .onResult;
  expect(
    onResult,
    isNotNull,
    reason: 'the guard supplies `onResult`; a null one would strand the user',
  );
  onResult!(didLogin);
}

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the decision, without a Navigator', () {
    // Red-first per AGENT_CONTEXT §6. This branch was written as
    // `resolveNext(true)` on both paths before it was read as a value, and the
    // mutation that follows — swapping the two outcomes — turns both tests here
    // red. It is the smallest unit of the guard and the only genuinely pure part.
    test('a session allows the navigation', () {
      expect(
        AuthGuard(FakeAuthStatus(authenticated: true)).decide(),
        GuardDecision.allow,
      );
    });

    test('no session sends the user to the login route', () {
      expect(
        AuthGuard(FakeAuthStatus(authenticated: false)).decide(),
        GuardDecision.redirectToLogin,
      );
    });

    test('the decision follows the session object, read afresh each time', () {
      // Not a snapshot. `AuthGuard` holds the [AuthStatus] and reads it on every
      // navigation, so a guard that cached its first answer would keep allowing
      // after a logout — which is the failure `reevaluateListenable` exists to
      // catch, and one these two decisions make visible without a Navigator.
      final FakeAuthStatus status = FakeAuthStatus(authenticated: true);
      final AuthGuard guard = AuthGuard(status);

      expect(guard.decide(), GuardDecision.allow);

      status.authenticated = false;

      expect(guard.decide(), GuardDecision.redirectToLogin);
    });
  });

  group('the round trip', () {
    // `06-navigation.md` §8's own verification for this phase, executed: push `/`
    // unauthenticated, assert it redirects to `/login`, then resume on
    // `onResult(true)` and land back on `/`.
    testWidgets(
      'push / unauthenticated, redirect, then onResult(true) resumes',
      (WidgetTester tester) async {
        final AuthHarness harness = AuthHarness.starting();
        addTearDown(harness.release);

        await tester.pumpWidget(host(harness.router));
        await pumpUntilFound(tester, find.byType(LoginPage));

        // 1. The interrupted navigation: `/` never reached, `/login` did.
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(HomePage), findsNothing);
        expect(harness.router.currentPath, AppRoutes.login);

        // 2. The user signs in. The page reports the outcome and navigates nothing
        //    itself — the guard resumes, which is what makes the flow re-entrant.
        harness.status.authenticated = true;
        completeLogin(tester, didLogin: true);

        await pumpUntilFound(tester, find.byType(HomePage));
        await pumpUntilGone(tester, find.byType(LoginPage));

        // 3. The interrupted navigation completed, and the login route is gone
        //    rather than merely covered.
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        expect(harness.router.currentPath, AppRoutes.home);
        expect(
          harness.router.stack.map((AutoRoutePage<Object?> page) => page.name),
          <String>[HomeRoute.name],
          reason:
              'the login route was removed from the stack, not left beneath',
        );
      },
    );

    testWidgets('onResult(false) abandons the navigation and does not resume', (
      WidgetTester tester,
    ) async {
      final AuthHarness harness = AuthHarness.starting();
      addTearDown(harness.release);

      await tester.pumpWidget(host(harness.router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      harness.status.authenticated = true;
      completeLogin(tester, didLogin: false);

      await pumpUntilGone(tester, find.byType(LoginPage));

      // The refusal is the whole point of the boolean: `false` must NOT resume, or
      // a user who cancels the sign-in lands on the screen they were trying to
      // reach. `/` is what the router now reports — the redirect target of the
      // abandoned navigation, with no page built for it.
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(LoginPage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.home);
    });

    testWidgets('every guarded route redirects, not just the initial one', (
      WidgetTester tester,
    ) async {
      // The guard is attached to five routes; a test that only ever exercises the
      // initial navigation proves nothing about the other four, because the initial
      // one is also the one with the most attention.
      for (final String path in <String>[
        AppRoutes.reading,
        AppRoutes.quiz,
        AppRoutes.result,
        AppRoutes.settings,
      ]) {
        final AuthHarness harness = AuthHarness.starting();
        await tester.pumpWidget(host(harness.router));
        await pumpUntilFound(tester, find.byType(LoginPage));

        unawaited(harness.router.pushPath<void>(path));
        await tester.pump();

        expect(
          harness.router.currentPath,
          AppRoutes.login,
          reason: '$path must bounce through the guard, not render',
        );
        expect(
          find.byType(HomePage),
          findsNothing,
          reason: '$path never got as far as being mounted',
        );

        harness.release();
      }
    });
  });

  group('logging out re-evaluates the whole stack', () {
    // `06-navigation.md` §8: wire `reevaluateListenable` "so logging out
    // re-evaluates the whole stack". Without it the guard only runs on a
    // *navigation*, so a signed-in user on `/settings` who signs out stays there
    // until they happen to navigate — and since the guard is not a security
    // boundary, nothing downstream catches it either.
    testWidgets('a sign-out from /settings returns to the login route', (
      WidgetTester tester,
    ) async {
      final AuthHarness harness = AuthHarness.starting(authenticated: true);
      addTearDown(harness.release);

      await tester.pumpWidget(host(harness.router));
      await pumpUntilFound(tester, find.byType(HomePage));
      unawaited(harness.router.pushPath<void>(AppRoutes.settings));
      await pumpUntilFound(tester, find.byType(SettingsPage));

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);

      // The sign-out. Nothing navigates: only the signal fires, and the
      // re-evaluation is the router's doing.
      final int readsBefore = harness.status.reads;
      harness.status.authenticated = false;
      harness.announce();
      await pumpUntilFound(tester, find.byType(LoginPage));
      await pumpUntilGone(tester, find.byType(SettingsPage));
      await pumpUntilGone(tester, find.byType(HomePage));

      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        find.byType(SettingsPage),
        findsNothing,
        reason:
            'the stack was re-evaluated, not merely navigated: a route already on '
            'screen has to be torn down, and its removal takes a transition of its '
            'own — hence the wait rather than an immediate assertion',
      );
      expect(find.byType(HomePage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.login);
      expect(
        harness.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[LoginRoute.name],
      );
      // The guard really did run again. `AuthStatus.isAuthenticated` is read
      // exactly once per guard invocation, so a signal that never reached the
      // router would leave this counter where it was — the check that the
      // listenable is wired at all, as opposed to the redirect being a
      // coincidence of the stub's absence.
      expect(
        harness.status.reads,
        greaterThan(readsBefore),
        reason: 'the guard was re-entered after the signal, not before',
      );
    });

    testWidgets('every guarded route in the stack goes, not only the top one', (
      WidgetTester tester,
    ) async {
      // The stronger half. `/` → `/quiz` → `/result` puts two guarded routes under
      // the top one; a re-evaluation that revisited only the top would leave the
      // others mounted.
      final AuthHarness harness = AuthHarness.starting(authenticated: true);
      addTearDown(harness.release);

      await tester.pumpWidget(host(harness.router));
      await pumpUntilFound(tester, find.byType(HomePage));
      unawaited(harness.router.pushPath<void>(AppRoutes.quiz));
      await pumpUntilFound(tester, find.byType(QuizPage));
      unawaited(harness.router.pushPath<void>(AppRoutes.result));
      await pumpUntilFound(tester, find.byType(ResultPage));

      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.byType(ResultPage), findsOneWidget);

      final List<String?> depthBefore = harness.router.stack
          .map((AutoRoutePage<Object?> page) => page.name)
          .toList();
      expect(depthBefore, hasLength(3), reason: 'three routes to re-evaluate');

      harness.status.authenticated = false;
      harness.announce();
      await pumpUntilFound(tester, find.byType(LoginPage));
      await pumpUntilGone(tester, find.byType(ResultPage));
      await pumpUntilGone(tester, find.byType(QuizPage));
      await pumpUntilGone(tester, find.byType(HomePage));

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(QuizPage), findsNothing);
      expect(find.byType(ResultPage), findsNothing);
      expect(find.byType(HomePage), findsNothing);
      expect(
        harness.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[LoginRoute.name],
        reason:
            'three guarded routes collapsed to one, which is what re-evaluating '
            'the WHOLE stack looks like; a re-evaluation that revisited only the '
            'top route would have left two of them underneath',
      );
    });

    testWidgets('a signal carrying no session change disturbs nothing', (
      WidgetTester tester,
    ) async {
      // The other half of the wiring. A signal that fired on every unrelated
      // emission would re-run the guard over the whole stack for no reason.
      // Phase 5's signal is the bloc's stream, so it *will* carry unrelated
      // emissions, and this pins that they are harmless.
      final AuthHarness harness = AuthHarness.starting(authenticated: true);
      addTearDown(harness.release);

      await tester.pumpWidget(host(harness.router));
      await pumpUntilFound(tester, find.byType(HomePage));
      unawaited(harness.router.pushPath<void>(AppRoutes.reading));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      harness.announce();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ReadingPage), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.reading);
    });
  });
}
