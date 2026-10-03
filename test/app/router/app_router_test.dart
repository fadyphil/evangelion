import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` classes, reached the same way `app_router.dart` reaches
// them: through the generated library, not through the six pages.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

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

    test('the wildcard is last', () {
      // ONE ASSERTION, not two. This used to carry a second one — "and there is
      // exactly one of it", `where(path == fallback).length == 1` — which the
      // list above already implies: a duplicate entry would have to differ from
      // the expected list. A second check on the same fact is a second thing to
      // keep in step, and reading it as an independent guard overstates what the
      // suite can see.
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
      // Everything before the wildcard, not `take(6)`. The group above already
      // established that the wildcard is last, so "everything but the last
      // entry" is the same set without a second copy of the count — and a count
      // is what goes stale when a seventh screen is ever added.
      final List<AutoRoute> realRoutes = routes.sublist(0, routes.length - 1);

      expect(realRoutes.map((AutoRoute route) => route.page.name), <String>[
        LoginRoute.name,
        HomeRoute.name,
        ReadingRoute.name,
        QuizRoute.name,
        ResultRoute.name,
        SettingsRoute.name,
      ], reason: 'the six locked screens, in route-table order');
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

    // THE MUTATION THIS WHOLE GROUP EXISTS FOR, measured against the full suite:
    // moving `RedirectRoute(path: '*')` to the front of `AppRouter.routes` turns
    // **46 tests** red. Nothing throws, no log line appears, the list-order
    // assertion above is the only other thing that notices, and every path here
    // silently becomes `/`.
    //
    // ("nine", which is what the commit message claimed, was wrong in both
    // direction and magnitude; `app_routes.dart` carries the measured number too,
    // so the record is in the repository and not only in git history.)
    test('each of the six routes resolves to itself, not to /', () {
      expect(resolve(AppRoutes.login), AppRoutes.login);
      expect(resolve(AppRoutes.home), AppRoutes.home);
      expect(resolve(AppRoutes.reading), AppRoutes.reading);
      expect(resolve(AppRoutes.quiz), AppRoutes.quiz);
      expect(resolve(AppRoutes.result), AppRoutes.result);
      expect(resolve(AppRoutes.settings), AppRoutes.settings);
      //
      // This used to be a second test, "the wildcard does not swallow the six
      // real routes", which iterated the same six paths and made the same six
      // assertions. One of the two was always redundant, and reading them
      // together suggested two independent checks where there is one.
    });

    test('an unknown path resolves to / through the wildcard', () {
      expect(resolve('/not-a-route'), AppRoutes.home);
      expect(resolve('/deeply/nested/nonsense'), AppRoutes.home);
    });

    test('so does any single unmatched segment', () {
      // THE BEHAVIOURAL HALF OF THE WILDCARD CLAIM — it replaces a
      // literal-equality check on `AppRoutes.fallback` that stood in
      // `app_routes_test.dart`. That check read `'*'` is the only spelling auto_route
      // accepts, which is false: `'/*'` is accepted too. Measured side by side
      // through the executed matcher, the two spellings agree on **every** path
      // this app has:
      //
      //   | matcher input | `fallback = '*'` | `fallback = '/*'` |
      //   |---|---|---|
      //   | `/x`                | `/`  | `/`  |
      //   | `//`                | null | null |
      //   | `''`                | null | null |
      //   | `/not-a-route`      | `/`  | `/`  |
      //   | `/login/x`          | `/`  | `/`  |
      //   | `/deeply/nested/x`  | `/`  | `/`  |
      //   | `/LOGIN`            | `/`  | `/`  |
      //   | `*` (the literal)   | `/`  | null |
      //
      // So the coverage is pinned here by execution rather than by spelling, which
      // is the only form of the claim that is worth anything: `'*'` is chosen
      // because it is the form auto_route documents and because it leaves exactly
      // one declared path outside the slash-prefixed set, not because `'/*'` is
      // broken.
      expect(resolve('/x'), AppRoutes.home);
    });

    test('a path with no segments matches nothing at all', () {
      // The half of the same measurement that is NOT a pass, and which neither
      // spelling changes. `RouteMatcher.match` strips the leading separator and
      // then has no segments left, so both `''` and `'//'` come back `null` — the
      // wildcard does not cover them, because a `*` with nothing in front of it
      // never becomes a full match. Asserted so the table above is read as the
      // whole truth and not as the flattering part of it: `resolve()` cannot be
      // used here because it asserts a match exists.
      expect(
        router.matcher.match('//'),
        isNull,
        reason: 'an empty path is not a path the wildcard rescues',
      );
      expect(
        router.matcher.match(''),
        isNull,
        reason: 'nor is the empty string',
      );
    });
  });

  group('the global transition', () {
    test('is RouteType.custom over EvaMotion.fadeSlide and EvaMotion.screen', () {
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
      // THE POP DIRECTION, WHICH IS THE ONE USERS FEEL MOST.
      //
      // `reverseTransitionDuration => routeType.reverseDuration ??
      // const Duration(milliseconds: 300)` — auto_route 11.2.0,
      // `auto_route_page.dart:231`, on `_CustomPageRouteTransitionMixin`, which
      // is the live path for `RouteType.custom`. So leaving `reverseDuration`
      // unset does not mean "same as the push": it means a literal `300` that
      // appears in no motion table in `03-design-system.md` §5.3, running on
      // every back navigation. Push would have been the §5.3 `screen` token and
      // pop would have been a framework default — the direction nobody looks at
      // in a design review is the one that ships.
      expect(
        custom.reverseDuration,
        EvaMotion.screen,
        reason:
            'a back navigation must run the same §5.3 `screen` token as the '
            'push, not auto_route\'s 300ms fallback',
      );
    });

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

    testWidgets('but a cold DEEP PUSH of /login carries a null onResult', (
      WidgetTester tester,
    ) async {
      // THE TRAP `login_page.dart`'s doc comment used to describe wrongly. It said
      // the null case "is only reachable by someone rendering the page outside a
      // redirect". `/login` is the one route with no guard — a gate in front of it
      // would redirect to itself forever — so pushing it *through the app's own
      // route table* reaches the same page with no one to report back to. That is
      // a deep link, not someone hand-building a widget, and it is why the trap is
      // stated there rather than left to be rediscovered.
      //
      // Measured on this router: the push leaves the stack at
      // `[LoginRoute, LoginRoute]` — the redirect from `/` plus the one the push
      // asked for — with exactly one `LoginPage` in the tree and no `onResult`.
      final AppRouter router = routerFor(FakeAuthStatus(authenticated: false));
      addTearDown(router.dispose);

      await tester.pumpWidget(routerHost(router));
      await pumpUntilFound(tester, find.byType(LoginPage));

      unawaited(router.pushPath<void>(AppRoutes.login));
      // WAITING ON THE STACK, NOT ON A FINDER, and that is the whole reason this
      // test is written the way it is. The login page from the redirect is already
      // on screen, so `pumpUntilFound(find.byType(LoginPage))` returns on its
      // first check — which is how the first draft of this test passed
      // `onResult == null` against nothing at all, reading the *redirect's* page,
      // which has a callback. `AutoRoutePage.child` is the page the route will
      // build, so `stack.last.child is LoginPage` says "the pushed route's page
      // exists" without consulting the thing under test.
      List<AutoRoutePage<Object?>> stack = <AutoRoutePage<Object?>>[];
      for (int frame = 0; frame < 12; frame++) {
        await tester.pump(EvaMotion.screen);
        stack = router.stack;
        if (stack.length > 1 && stack.last.child is LoginPage) {
          break;
        }
      }

      expect(
        stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[LoginRoute.name, LoginRoute.name],
        reason: "the redirect's login route, and the one the deep link pushed",
      );
      expect(router.currentPath, AppRoutes.login);
      expect(
        (stack.last.child as LoginPage).onResult,
        isNull,
        reason:
            'nobody redirected this page, so there is no resolver to resume — and '
            'Phase 5\'s real screen has to survive that, because it is one call '
            'away from a deep link or a notification tap',
      );
      // And the trap is not merely "the callback is null". The page that HAS the
      // resumable callback is the one underneath, unreachable behind a screen the
      // reader cannot get past — which is what made this worth a test rather than
      // a doc note.
      expect(
        (stack.first.child as LoginPage).onResult,
        isNotNull,
        reason: 'the guard\'s login route is still waiting for its outcome',
      );
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
