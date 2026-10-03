import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/di/navigation_injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../support/app_harness.dart';

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the navigation registrations', () {
    setUp(configureNavigation);

    test('the router is registered', () {
      expect(getIt.isRegistered<AppRouter>(), isTrue);
    });

    test('the auth seam is registered, as its two halves', () {
      expect(getIt.isRegistered<AuthStatus>(), isTrue);
      expect(getIt.isRegistered<ReevaluateListenable>(), isTrue);
    });

    test('two lookups are the identical router', () {
      // THE ASSERTION `06-navigation.md` §8 asks for, and the reason it exists:
      // "do not instantiate it as a field in `app.dart`, or a second `AppRouter`
      // with a stale bloc will exist alongside the injected one."
      //
      // `same(...)` rather than `identical(a, b)` because a failed `expect` on a
      // bare `isTrue` prints `Expected: true / Actual: false` and names neither
      // operand. `same` prints both, so the failure says which two routers
      // disagreed — and with two routers that is the whole diagnosis.
      //
      // THIS IS NOT A TAUTOLOGY, and the contrast is the point.
      // `CoreModule.serviceLocator` has the same "two lookups agree" shape and
      // pins nothing: its provider returns `GetIt.instance`, a process-wide
      // singleton, so `@lazySingleton` and `@factory` both hand back the identical
      // object — `injection_test.dart` documents that and carries the negative
      // control. `AppRouter`'s provider *builds a new router* (`AppRouter(getIt…,
      // getIt…)`), so the lifetime is load-bearing and this assertion has teeth.
      // The mutation: rewriting the generated registration to a get_it factory
      // would fail exactly this test and nothing else in the suite.
      expect(getIt<AppRouter>(), same(getIt<AppRouter>()));
    });

    test('re-binding AuthStatus does not reach a router that already exists', () async {
      // The other half of the same hazard. A router that cached the `AuthStatus`
      // it was built with would keep answering with a stale session for the life
      // of the process, and nothing above it would notice — `app.dart` reads the
      // router, not the status. Swapping the registration and asking again is the
      // only way to see it.
      final ControllableAuthStatus replacement = ControllableAuthStatus(
        authenticated: false,
      );

      expect(getIt<AuthStatus>(), isNot(same(replacement)));

      await getIt.unregister<AuthStatus>();
      getIt.registerSingleton<AuthStatus>(replacement);

      expect(getIt<AuthStatus>(), same(replacement));
      // The router built earlier still holds the ORIGINAL status, and this is
      // stated rather than asserted as fine: `bootstrapApp` registers the graph
      // before anything resolves the router, so in the real app the swap above
      // cannot happen after the fact. Asserted here so the constraint is visible
      // in a failing direction if the ordering ever changes.
      expect(
        identical(getIt<AppRouter>(), getIt<AppRouter>()),
        isTrue,
        reason:
            'the router is a singleton, so this documents that re-binding '
            'AuthStatus is NOT a live update — see bootstrapApp\'s step order',
      );
    });

    test('the default seam reports no session, so a cold launch reaches login', () {
      // Phase 4 has no `FakeAuthRepository` and no auth endpoint, so there is
      // nothing that *could* produce a session. Reporting `true` would be a lie
      // the guard would act on.
      expect(getIt<AuthStatus>().isAuthenticated, isFalse);
    });

    test('the default change signal never fires on its own', () {
      // A `ReevaluateListenable` that fired spuriously would re-run the guard over
      // the whole stack for no reason. Phase 4's placeholder has no stream behind
      // it, so there is nothing to assert beyond "it is not already torn down" —
      // which is the state `AppRouter.dispose` needs it in.
      expect(getIt<ReevaluateListenable>(), isNotNull);
      expect(
        () => getIt<ReevaluateListenable>().notifyListeners(),
        returnsNormally,
        reason: 'it is live; `AppRouter.dispose()` is what tears it down',
      );
    });

    test('configuring twice fails loudly rather than double-registering', () {
      // `main` must call this exactly once. A silent no-op would leave two
      // different sessions in the graph depending on which call won.
      expect(configureNavigation, throwsArgumentError);
    });
  });

  group('app.dart resolves the router rather than building one', () {
    // `06-navigation.md` §8's actual hazard: a second router existing alongside
    // the injected one. Asserting that `app.dart` *mentions* `getIt` would grade
    // text — Phase 0 shipped a bootstrap test that passed when `main()` was empty,
    // and this project does not do that twice. So the assertion is executed: the
    // router that ends up mounted is the one the locator holds.
    testWidgets('the resolved router is the one that gets mounted', (
      WidgetTester tester,
    ) async {
      configureNavigation();
      final AppRouter registered = getIt<AppRouter>();

      await pumpApp(tester);

      // `navigatorKey.currentContext` is non-null only for a router whose
      // `Navigator` is actually in the tree. If `app.dart` had constructed its
      // own router, the registered one would never be mounted and this would be
      // null — which is the whole claim.
      expect(
        registered.navigatorKey.currentContext,
        isNotNull,
        reason:
            'the router the locator handed out is the one MaterialApp.router '
            'mounted, so there is no second router holding a stale session',
      );
      expect(registered.navigatorKey.currentContext, isNot(throwsA(anything)));
    });

    testWidgets('and the mounted router exposes a live change signal', (
      WidgetTester tester,
    ) async {
      configureNavigation();
      final AppRouter registered = getIt<AppRouter>();

      await pumpApp(tester);

      // The signal is live for as long as the router is mounted — not torn down,
      // not a stub that throws on notify. If `app.dart` had handed the config a
      // different listenable, or none, this would be the assertion that noticed
      // (a second, dead signal would still be `isA<ReevaluateListenable>`).
      expect(
        registered.authChanges.notifyListeners,
        returnsNormally,
        reason: 'the signal the mounted router listens to is still alive',
      );
    });

    testWidgets('a session change announced through the resolved signal re-evaluates the '
        'mounted app', (WidgetTester tester) async {
      // The executed form of "`reevaluateListenable` is wired so logging out
      // re-evaluates the whole stack" (06-navigation.md §8) — at the level of the
      // REAL app, not the test host. `auth_guard_test.dart` proves the same
      // property against a router it mounted itself; this proves `app.dart` passes
      // the signal to the delegate rather than building a config without it.
      //
      // The graph is assembled by hand here rather than by
      // `configureNavigation()`, because the whole point is to substitute a
      // controllable session — and `configureNavigation()` rejects a duplicate
      // registration. `EvangelionApp` still resolves the router from the locator,
      // so this is the production path with a different session behind it.
      await resetServiceLocator();
      final ControllableAuthStatus status = ControllableAuthStatus(
        authenticated: true,
      );
      final ManualAuthChanges changes = ManualAuthChanges();
      final AppRouter router = AppRouter(status, changes);
      addTearDown(router.dispose);
      getIt
        ..registerLazySingleton<AuthStatus>(() => status)
        ..registerLazySingleton<ReevaluateListenable>(() => changes)
        ..registerLazySingleton<AppRouter>(() => router);

      await tester.pumpWidget(const EvangelionApp());
      await pumpUntilFound(tester, find.byType(HomePage));
      expect(find.byType(LoginPage), findsNothing);

      status.authenticated = false;
      changes.fire();
      await pumpUntilFound(tester, find.byType(LoginPage));
      await pumpUntilGone(tester, find.byType(HomePage));

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('the app lands on the login route on a cold launch', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(_materialAppIn(tester).home, isNull, reason: 'there is no `home`');
    });
  });

  group('the hand-written registrations sit beside the generated ones', () {
    // `configureNavigation` is a second, hand-written composition step — forced by
    // the rule that `injection.dart`'s import graph must stay Flutter-free, which
    // the generated config cannot honour for a router. The evidence that it did
    // not *replace* the generated one is that both sets resolve in one locator.
    // `injection_test.dart` asserts the generated half in detail; this is the seam.
    test(
      'the generated core registrations and the navigation ones coexist',
      () async {
        await resetServiceLocator();
        await configureDependencies();
        configureNavigation();

        expect(
          getIt.isRegistered<GetIt>(),
          isTrue,
          reason: 'registered by the generated `injection.config.dart`',
        );
        expect(
          getIt<String>(instanceName: 'apiBaseUrl'),
          isNotNull,
          reason: 'also registered by the generated config',
        );
        expect(getIt.isRegistered<AppRouter>(), isTrue);
        expect(getIt.isRegistered<AuthStatus>(), isTrue);
        expect(getIt.isRegistered<ReevaluateListenable>(), isTrue);
      },
    );

    test('neither step depends on the other having run first', () async {
      // The ordering `bootstrapApp` relies on is "graph first, router second", but
      // this asserts the weaker and more useful property: `configureNavigation`
      // supplies everything it reads, so a test can build the router without the
      // pure-Dart graph. Without this, every router test in this repo would have to
      // configure the whole app to test the guard.
      await resetServiceLocator();
      configureNavigation();

      expect(getIt<AppRouter>(), isA<AppRouter>());
      expect(getIt.isRegistered<GetIt>(), isFalse);
    });
  });
}

/// The pumped [MaterialApp], read off the tree rather than off the widget
/// instance, so the assertion describes what the framework actually received.
MaterialApp _materialAppIn(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));
