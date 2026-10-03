import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` classes, reached the way `app_router.dart` reaches them.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

/// A session that throws, which [FakeAuthStatus] must never do.
///
/// NOT A DUPLICATE of the shared fake and not a second seam: it exists to be the
/// one thing a conforming `AuthStatus` is forbidden to be, so that
/// `auth_status.dart`'s "a throw is undefined behaviour" paragraph has a
/// measurement behind it. Sharing [FakeAuthStatus] here would defeat the point.
final class ThrowingAuthStatus implements AuthStatus {
  const ThrowingAuthStatus(this.message);

  /// The message the failure carries, so a diagnostic names the cause.
  final String message;

  @override
  bool get isAuthenticated => throw StateError(message);
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

/// The `onResult` the guard is waiting on, or a failure naming why there is none.
///
/// Read off the *rendered* `LoginPage` rather than off the `LoginRoute` object:
/// it is the same call the guard's closure makes, so the test drives the
/// production seam rather than a copy of it.
///
/// `app_router_test.dart` holds the case where the rendered page's `onResult` is
/// null — a deep push of `/login`, the one unguarded route. So this helper's
/// null check is a real precondition here, not a formality.
LoginResultCallback loginOutcomeOn(WidgetTester tester) {
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
  return onResult!;
}

/// Completes the login outcome the guard is waiting on.
///
/// [outcome] is a NAMED parameter of this test helper even though
/// [LoginResultCallback]'s own parameter is positional — the difference is made at
/// the boundary where the test hands a value in, and `LoginOutcome.signedIn`
/// reads unambiguously either way.
void completeLogin(WidgetTester tester, {required LoginOutcome outcome}) =>
    loginOutcomeOn(tester)(outcome);

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

    test('and it does not swallow a throwing seam', () {
      // `auth_status.dart` says an implementation MUST NOT throw, and says the
      // guard does not catch it if one does. The second half of that is
      // falsifiable without a Navigator, which is why this is here and not only in
      // the widget group below: a `try`/`catch` added to `decide()` for any reason
      // — "fail closed to login", "log it and carry on" — turns this red, and it is
      // a much cheaper signal than a test that has to mount a tree to notice.
      expect(
        () =>
            const AuthGuard(ThrowingAuthStatus('isAuthenticated is forbidden'))
                .decide(),
        throwsStateError,
        reason:
            'catching here would need an `// ignore:` against '
            '`avoid_catching_errors` + `avoid_catches_without_on_clauses`, and a '
            'silent redirect to login is indistinguishable from a logout',
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

        await tester.pumpWidget(routerHost(harness.router));
        await pumpUntilFound(tester, find.byType(LoginPage));

        // 1. The interrupted navigation: `/` never reached, `/login` did.
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(HomePage), findsNothing);
        expect(harness.router.currentPath, AppRoutes.login);

        // 2. The user signs in. The page reports the outcome and navigates nothing
        //    itself — the guard resumes, which is what makes the flow re-entrant.
        harness.status.authenticated = true;
        completeLogin(tester, outcome: LoginOutcome.signedIn);

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

      await tester.pumpWidget(routerHost(harness.router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      harness.status.authenticated = true;
      completeLogin(tester, outcome: LoginOutcome.cancelled);

      await pumpUntilGone(tester, find.byType(LoginPage));

      // The refusal is the whole point of the outcome: `cancelled` must NOT resume, or
      // a user who cancels the sign-in lands on the screen they were trying to
      // reach. `/` is what the router now reports — the redirect target of the
      // abandoned navigation, with no page built for it.
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(LoginPage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.home);
    });

    testWidgets('calling onResult twice is dropped, not an error', (
      WidgetTester tester,
    ) async {
      // THE REAL CRASH `LoginPage`'s "exactly once" contract did not prevent.
      //
      // `NavigationResolver` completes once: auto_route asserts `!isResolved`
      // (`auto_route_guard.dart:211`, "Make sure `resolver.next()` is only called
      // once") so the second call is an unhandled `AssertionError` in debug, and a
      // `StateError: Future already completed` in release and profile where the
      // assert compiles out. Either way it escapes a button handler.
      //
      // The trigger is ordinary, not exotic: Phase 5's sign-in control reaches for
      // `onResult` from an `onPressed` and from the surrounding form's
      // `onSubmitted`, and a double tap on a slow device does it twice. Nothing in
      // the guard, the page or this suite made "exactly once" true.
      //
      // The assertion is `returnsNormally` on the SECOND call alone. Asserting that
      // the flow still works afterwards would be a weaker and a different claim:
      // the property is that nothing escapes, not that double-signing-in is
      // supported.
      final AuthHarness harness = AuthHarness.starting();
      addTearDown(harness.release);

      await tester.pumpWidget(routerHost(harness.router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      final LoginResultCallback onResult = loginOutcomeOn(tester);
      harness.status.authenticated = true;

      expect(() => onResult(LoginOutcome.signedIn), returnsNormally);
      expect(() => onResult(LoginOutcome.signedIn), returnsNormally);
      expect(() => onResult(LoginOutcome.cancelled), returnsNormally);

      // And the first call was the one that took effect: the interrupted
      // navigation resumed and the login route is gone rather than merely covered.
      // The removal takes a transition of its own, hence the wait.
      await pumpUntilFound(tester, find.byType(HomePage));
      await pumpUntilGone(tester, find.byType(LoginPage));
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.home);
      // Nothing escaped into the framework either.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cancelled outcome after a resumed one changes nothing', (
      WidgetTester tester,
    ) async {
      // The order-dependence of the latch, which the test above leaves open: the
      // latch is one-way. A `cancelled` arriving *first* abandons the navigation
      // and a later `signedIn` is still dropped — so a retry that double-fires
      // with opposite answers cannot resurrect a navigation the reader gave up on.
      final AuthHarness harness = AuthHarness.starting();
      addTearDown(harness.release);

      await tester.pumpWidget(routerHost(harness.router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      final LoginResultCallback onResult = loginOutcomeOn(tester);
      harness.status.authenticated = true;

      expect(() => onResult(LoginOutcome.cancelled), returnsNormally);
      expect(() => onResult(LoginOutcome.signedIn), returnsNormally);
      await tester.pump();
      await tester.pump();

      expect(find.byType(HomePage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.home);
      expect(tester.takeException(), isNull);
    });

    // ==========================================================================
    // WHAT `pushAll` ACROSS THE GUARD ACTUALLY DOES, MEASURED.
    //
    // `auth_guard.dart`'s known-gap note records this, and before this group the
    // note was prose: nothing executed it, and the prose was partly wrong — it
    // claimed that resolving the first login "pops one of them and completes only
    // that navigation", which does not reproduce. Both routes land. What is
    // stranded is the *second* login redirect.
    //
    // Two scenarios, because they differ in a way that matters to whoever first
    // writes the chained push: whether the session has been established when the
    // login page answers.
    // ==========================================================================

    testWidgets('pushAll with a session: every route lands, and one login '
        'redirect is stranded under them', (WidgetTester tester) async {
      final AuthHarness harness = AuthHarness.starting();
      addTearDown(harness.release);

      await tester.pumpWidget(routerHost(harness.router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      unawaited(
        harness.router.pushAll(<PageRouteInfo<void>>[
          const QuizRoute(),
          const ResultRoute(),
        ]),
      );
      for (int frame = 0; frame < 12; frame++) {
        await tester.pump(EvaMotion.screen);
      }

      expect(
        harness.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[LoginRoute.name, LoginRoute.name],
        reason: 'one pending redirect PER route in the pushAll',
      );
      expect(
        find.byType(LoginPage),
        findsOneWidget,
        reason:
            'only the top login route has a page built for it, which is exactly '
            'why the lower redirect\'s `onResult` can never be reached',
      );

      harness.status.authenticated = true;
      completeLogin(tester, outcome: LoginOutcome.signedIn);
      for (int frame = 0; frame < 12; frame++) {
        await tester.pump(EvaMotion.screen);
      }

      expect(
        harness.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[LoginRoute.name, QuizRoute.name, ResultRoute.name],
        reason:
            'BOTH pushed routes land — completing the first resolver does complete '
            'the navigation it belonged to. What is left over is the second login '
            'redirect, underneath them',
      );
      expect(find.byType(ResultPage), findsOneWidget);
      expect(harness.router.currentPath, AppRoutes.result);
      // The stranded redirect is a route with no page: nothing on screen, and no
      // callback in the tree that could ever resume it.
      expect(
        find.byType(LoginPage),
        findsNothing,
        reason: 'a login route on the stack that no page was ever built for',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('pushAll with no session yet: the resumed routes are guarded '
        'again, and the stack grows', (WidgetTester tester) async {
      // The second half of the measurement, and the more surprising one.
      //
      // `LoginPage` reporting "signed in" does not make a session exist — only
      // `AuthStatus` does. So a login page that answers before the session is
      // established resumes the pending routes straight back into the guard, which
      // answers "redirect" a second time. `pushAll` therefore produces a stack that
      // GROWS with each answer: `[LoginRoute, QuizRoute, LoginRoute]`, and the
      // third entry is a fresh redirect for a page nobody can see.
      //
      // This is the case that makes the gap worse than "one orphan", and it is the
      // case a Phase 6 or 7 chained push hits if the session is not updated before
      // `onResult` fires — which, on a real sign-in, is a race against the bloc
      // emitting.
      final AuthHarness harness = AuthHarness.starting();
      addTearDown(harness.release);

      await tester.pumpWidget(routerHost(harness.router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      unawaited(
        harness.router.pushAll(<PageRouteInfo<void>>[
          const QuizRoute(),
          const ResultRoute(),
        ]),
      );
      for (int frame = 0; frame < 12; frame++) {
        await tester.pump(EvaMotion.screen);
      }

      // The session is deliberately NOT updated here.
      completeLogin(tester, outcome: LoginOutcome.signedIn);
      for (int frame = 0; frame < 12; frame++) {
        await tester.pump(EvaMotion.screen);
      }

      expect(
        harness.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[LoginRoute.name, QuizRoute.name, LoginRoute.name],
        reason:
            'the quiz route resumed, and then bounced off the guard once more — so '
            'the stack grew by a redirect instead of by the result page',
      );
      expect(find.byType(ResultPage), findsNothing);
      expect(harness.router.currentPath, AppRoutes.login);
      expect(tester.takeException(), isNull);
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
        await tester.pumpWidget(routerHost(harness.router));
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

      await tester.pumpWidget(routerHost(harness.router));
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
      // The guard really did run again — and exactly once. `isAuthenticated` is
      // read once per guard invocation, so this pins the count, not merely that it
      // moved. `greaterThan(readsBefore)` was the previous assertion here and it
      // was satisfied by a `decide()` that read the status twice: the count claims
      // in prose and the number in code disagreed, and only one of them was
      // enforced. A signal that never reached the router leaves this at
      // `readsBefore`, which is the check that the listenable is wired at all as
      // opposed to the redirect being a coincidence of the stub's absence.
      expect(
        harness.status.reads,
        readsBefore + 1,
        reason:
            'the re-evaluation re-entered the guard once, and the guard read the '
            'session once while doing it',
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

      await tester.pumpWidget(routerHost(harness.router));
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

      await tester.pumpWidget(routerHost(harness.router));
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

  group("a throwing AuthStatus, which is the seam's stated undefined behaviour", () {
    // `auth_status.dart` says MUST NOT throw, and says what happens when one does.
    // Until this group, that sentence had no counterpart in the code, so it read as
    // a preference rather than an obligation with a known cost.
    //
    // These are plain `test`s, not `testWidgets`, and the reason is a measurement
    // rather than a preference — see the note at the end. The short version: a
    // throw escaping the guard arrives as an *uncaught zone error*, which
    // `flutter_test` reports by failing the test outright. `tester.takeException()`
    // returns null for it, so there is no way to assert "nothing was built AND the
    // error escaped" from inside a widget test. Driving the router's own API puts
    // the failure in a `Future` the test can await instead, which keeps the claim
    // falsifiable.
    test('and the router builds nothing at all, in a plain test for a measured '
        'reason', () async {
      final AppRouter router = AppRouter(
        const ThrowingAuthStatus('isAuthenticated is undefined behaviour'),
        ManualAuthChanges(),
      );
      addTearDown(router.dispose);

      // The guarded push is where the guard is entered on this path — the same
      // `onNavigation` → `checkGuard` → `_canNavigate` → guarded-push chain the
      // cold launch walks, minus the tree.
      await expectLater(
        router.pushPath<void>(AppRoutes.settings),
        throwsStateError,
        reason:
            'the failure propagates out of the navigation rather than being '
            'converted into a redirect: nothing catches it anywhere between '
            '`onNavigation` and here',
      );

      expect(
        router.stack,
        isEmpty,
        reason:
            'NOTHING was pushed. This is the whole cost of a throwing seam: no '
            'page and no route, and on a cold launch — where this is the '
            'initial-route resolution rather than a push — a blank first frame '
            'with no route underneath to navigate away from',
      );
    });
  });
}
