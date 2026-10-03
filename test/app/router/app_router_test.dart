import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` classes, reached the same way `app_router.dart` reaches
// them: through the generated library, not through the six pages.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

/// A session this phase does not have: the answer is whatever the test says.
///
/// Mutable on purpose — the guard reads the same instance on every navigation, so
/// flipping this is how a test simulates a login or a logout without a bloc.
final class FakeAuthStatus implements AuthStatus {
  FakeAuthStatus({this.authenticated = true});

  bool authenticated;

  @override
  bool get isAuthenticated => authenticated;
}

/// A signal nothing ever writes to.
///
/// Paired with a mutable [FakeAuthStatus] that is all these tests need: the
/// *stack* re-evaluation is driven by the listenable, and that is
/// `auth_guard_test.dart`'s subject.
final class _SilentAuthChanges extends ReevaluateListenable {}

/// A router over a [FakeAuthStatus].
///
/// Built directly rather than resolved from the locator, so a test can state what
/// the session is without touching the object graph. `AppRouter`'s registration
/// is exercised in `navigation_injection_test.dart`.
AppRouter routerFor(
  FakeAuthStatus status, {
  ReevaluateListenable? authChanges,
}) => AppRouter(status, authChanges ?? _SilentAuthChanges());

/// The app shell these widget tests mount.
///
/// Deliberately not `EvangelionApp`: these tests are about the router, and
/// `EvangelionApp` hard-codes the Eva theme, the locale plumbing and — via the
/// locator — the router itself. A shell keeps each assertion pointing at one
/// thing, and `app_test.dart` owns the claim that the real app uses the resolved
/// router.
Widget routerHost(AppRouter router) => MaterialApp.router(
  routerConfig: router.config(reevaluateListenable: router.authChanges),
);

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the route table', () {
    // THE SUBJECT OF THIS GROUP IS THE **ORDER**, not the contents.
    //
    // `AppRoutes`' values are pinned by `app_routes_test.dart` and every path
    // below is read off `AppRoutes` rather than re-spelled, so what is left is the
    // one thing a per-path assertion cannot see: that `*` is *last*.
    final AppRouter router = AppRouter(FakeAuthStatus(), _SilentAuthChanges());
    late List<AutoRoute> routes;

    setUp(() {
      // Read the live getter, never a hand-written copy. A copy is a second source
      // of truth free to drift from the thing it describes — the exact failure
      // `app_routes_test.dart` documents for its own first draft.
      routes = router.routes;
    });

    test('the wildcard is last, and it is the only one', () {
      expect(
        routes.map((AutoRoute route) => route.path),
        <String>[
          AppRoutes.login,
          AppRoutes.home,
          AppRoutes.reading,
          AppRoutes.quiz,
          AppRoutes.result,
          AppRoutes.settings,
          AppRoutes.fallback,
        ],
        reason:
            'declaration order IS match order; anything after `*` is '
            'unreachable',
      );
      expect(
        routes
            .where((AutoRoute route) => route.path == AppRoutes.fallback)
            .length,
        1,
        reason: 'a second `*` would be dead weight at best',
      );
    });

    test('the wildcard is a redirect to /, not a page', () {
      final RedirectRoute fallback = routes.last as RedirectRoute;

      expect(fallback.redirectTo, AppRoutes.home);
      // The wildcard carries auto_route's own "no builder" sentinel rather than a
      // null page, so the claim is made against the six real page names instead of
      // against `null` — which would have been an assertion about the framework's
      // internals that could change without anything here breaking.
      expect(
        fallback.page.name,
        isNot(
          anyOf(
            LoginRoute.name,
            HomeRoute.name,
            ReadingRoute.name,
            QuizRoute.name,
            ResultRoute.name,
            SettingsRoute.name,
          ),
        ),
        reason: 'the bare asterisk has no page to build; it redirects',
      );
    });

    test('the six real routes are pages, each named by AppRoutes', () {
      expect(routes.take(6).map((AutoRoute route) => route.page.name), <String>[
        LoginRoute.name,
        HomeRoute.name,
        ReadingRoute.name,
        QuizRoute.name,
        ResultRoute.name,
        SettingsRoute.name,
      ]);
    });

    test('only /login is unguarded', () {
      // Read as a map rather than "the first six minus one", so a guard removed
      // from a middle route fails here instead of shifting a count.
      final Map<String, int> guardCounts = <String, int>{
        for (final AutoRoute route in routes) route.path: route.guards.length,
      };

      expect(guardCounts[AppRoutes.login], 0, reason: 'the entry point');
      for (final String guarded in <String>[
        AppRoutes.home,
        AppRoutes.reading,
        AppRoutes.quiz,
        AppRoutes.result,
        AppRoutes.settings,
      ]) {
        expect(guardCounts[guarded], 1, reason: '$guarded is behind the guard');
      }
      expect(
        guardCounts[AppRoutes.fallback],
        0,
        reason:
            'unguarded on purpose: an unknown path redirects to /, which bounces '
            'through AuthGuard and lands on login when there is no session',
      );
    });

    test('every guard reads the one session, not a snapshot of it', () {
      // `routes` is a getter, so a guard is built per read. If one of them
      // captured a *copy* of the session instead of the object, the two halves of
      // this test would disagree — and the symptom in the app would be "some
      // routes redirect and some do not", which is a miserable bug to diagnose.
      final FakeAuthStatus status = FakeAuthStatus(authenticated: false);
      final AppRouter live = AppRouter(status, _SilentAuthChanges());

      List<GuardDecision> decisionsOf(AppRouter subject) => subject.routes
          .expand((AutoRoute route) => route.guards)
          .cast<AuthGuard>()
          .map((AuthGuard guard) => guard.decide())
          .toList();

      expect(decisionsOf(live), isNotEmpty);
      expect(decisionsOf(live).toSet(), <GuardDecision>{
        GuardDecision.redirectToLogin,
      }, reason: 'no session yet');

      status.authenticated = true;

      expect(decisionsOf(live).toSet(), <GuardDecision>{
        GuardDecision.allow,
      }, reason: 'flipping the shared session must flip every guard at once');
    });
  });

  group('matching, which is where the ORDER is observable', () {
    // The list-order assertion above is structural. These are the same claim
    // executed: auto_route's `RouteMatcher._match` walks `collection.routes` in
    // order, takes the first config that matches, and follows a `RedirectRoute`
    // by re-matching its target. So a `*` at the front turns EVERY match into a
    // redirect to `/`, and these assertions are what notice.
    final AppRouter router = AppRouter(FakeAuthStatus(), _SilentAuthChanges());

    String? resolve(String rawPath) {
      final List<RouteMatch>? matches = router.matcher.match(rawPath);
      expect(matches, isNotNull, reason: 'nothing matched $rawPath at all');
      return matches!.single.path;
    }

    test('each of the six routes resolves to itself', () {
      expect(resolve(AppRoutes.login), AppRoutes.login);
      expect(resolve(AppRoutes.home), AppRoutes.home);
      expect(resolve(AppRoutes.reading), AppRoutes.reading);
      expect(resolve(AppRoutes.quiz), AppRoutes.quiz);
      expect(resolve(AppRoutes.result), AppRoutes.result);
      expect(resolve(AppRoutes.settings), AppRoutes.settings);
    });

    test('an unknown path resolves to / through the wildcard', () {
      expect(resolve('/not-a-route'), AppRoutes.home);
      expect(resolve('/deeply/nested/nonsense'), AppRoutes.home);
    });

    test('the wildcard does not swallow the six real routes', () {
      // The mutation that turns this red is moving `RedirectRoute(path: '*')` to
      // the front of `AppRouter.routes`: nothing throws, no log line appears, the
      // list-order assertion above is the only other thing that notices, and
      // every path here silently becomes `/`.
      for (final String path in <String>[
        AppRoutes.login,
        AppRoutes.home,
        AppRoutes.reading,
        AppRoutes.quiz,
        AppRoutes.result,
        AppRoutes.settings,
      ]) {
        expect(resolve(path), path, reason: '$path must not be redirected');
      }
    });
  });

  group('the global transition', () {
    test(
      'is RouteType.custom over EvaMotion.fadeSlide and EvaMotion.screen',
      () {
        final RouteType type = AppRouter(
          FakeAuthStatus(),
          _SilentAuthChanges(),
        ).defaultRouteType;

        expect(type, isA<CustomRouteType>());
        final CustomRouteType custom = type as CustomRouteType;
        expect(custom.transitionsBuilder, same(EvaMotion.fadeSlide));
        expect(
          custom.duration,
          EvaMotion.screen,
          reason:
              'not a new `screenDuration` — the existing token IS the duration, and '
              'two constants for one number is two things to keep in step',
        );
      },
    );

    test("and it is not Material's default transition", () {
      // Without this, "it is custom" and "it happens to render the same" are
      // indistinguishable, and swapping in `RouteType.material()` would leave the
      // assertion above green.
      expect(
        AppRouter(FakeAuthStatus(), _SilentAuthChanges()).defaultRouteType,
        isNot(const RouteType.material()),
      );
    });
  });

  group('landing', () {
    testWidgets('a cold launch without a session ends on the login route', (
      WidgetTester tester,
    ) async {
      final AppRouter router = routerFor(FakeAuthStatus(authenticated: false));
      addTearDown(router.dispose);

      await tester.pumpWidget(routerHost(router));
      await tester.pump();

      // The URL has already moved to /login after ONE frame, while the login page
      // itself has not been built yet — the guard's redirect resolves the route
      // synchronously and the page arrives with the next frame. Asserting the URL
      // before any pump would be asserting on a router nothing has told yet, and
      // waiting for the page first would be asserting the outcome twice.
      expect(router.currentPath, AppRoutes.login);

      await pumpUntilFound(tester, find.byType(LoginPage));
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('a cold launch with a session ends on the home route', (
      WidgetTester tester,
    ) async {
      final AppRouter router = routerFor(FakeAuthStatus());
      addTearDown(router.dispose);

      await tester.pumpWidget(routerHost(router));
      await pumpUntilFound(tester, find.byType(HomePage));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(router.currentPath, AppRoutes.home);
    });
  });

  group('a cold push of /result', () {
    // Phase 4's second verification line: "a router test that a cold push of
    // `/result` renders `EmptyState` rather than calling the API".
    //
    // **THE FIRST HALF OF THAT SENTENCE IS NOT TRUE OF THIS PHASE**, and the
    // difference is worth stating rather than engineering around. `/result` is
    // still the Phase-0c stub: `Scaffold` + `AppBar` + a `Text`. `EmptyState`
    // exists (`core/design_system/widgets/empty_state.dart`, goldened in Phase 3)
    // but no page uses it — `08-build-phases.md` Phase 10 is what wires `EmptyState`
    // into every async page, and retrofitting it here would be Phase 4 writing a
    // screen, which the phase forbids. So this pins what the route ACTUALLY
    // renders, and dates it.
    //
    // The second half is true, and structurally so: `core/network` is Phase 5's,
    // so there is no client in the graph for a data-driven screen to call with.
    // `navigation_injection_test.dart` pins that graph is exactly what Phase 4
    // declares.
    testWidgets('builds the Phase-0c stub, which is a placeholder, not an '
        'EmptyState', (WidgetTester tester) async {
      final AppRouter router = routerFor(FakeAuthStatus());
      addTearDown(router.dispose);

      await tester.pumpWidget(routerHost(router));
      await pumpUntilFound(tester, find.byType(HomePage));

      unawaited(router.pushPath<void>(AppRoutes.result));
      await pumpUntilFound(tester, find.byType(ResultPage));

      expect(router.currentPath, AppRoutes.result);
      expect(find.byType(ResultPage), findsOneWidget);
      expect(
        find.byType(EmptyState),
        findsNothing,
        reason:
            'the stub renders `Placeholder for /result`. Phase 10 owns the swap '
            'to EmptyState and this assertion is what will notice it happen',
      );
      expect(find.text('Placeholder for ${AppRoutes.result}'), findsOneWidget);
    });
  });

  group('disposal', () {
    test('disposing the router disposes the auth signal it owns', () {
      // The reason `AppRouter.dispose` exists. `ReevaluateListenable` is a
      // `ChangeNotifier`, and the one `MaterialApp.router` is handed is not owned
      // by anything the framework tears down: `RouterConfig` does not dispose it,
      // and `Router`'s teardown knows nothing about it. Phase 5's signal wraps an
      // `AuthBloc` subscription, so an undisposed one is a live stream feeding a
      // dead delegate.
      final _SilentAuthChanges changes = _SilentAuthChanges();
      final AppRouter router = AppRouter(FakeAuthStatus(), changes);

      router.dispose();

      expect(
        changes.notifyListeners,
        throwsA(isA<FlutterError>()),
        reason: 'ChangeNotifier throws once disposed — that is the signal',
      );
    });
  });
}
