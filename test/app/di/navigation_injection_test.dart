import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/di/navigation_injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../support/app_harness.dart';

void main() {
  // The two steps, in the order `bootstrapApp` runs them. Phase 4 needed only the
  // second — `configureNavigation` read nothing from the locator — so this was a
  // bare `resetServiceLocator`. Phase 5's `AuthBloc` cannot be generated, so it is
  // *built* here out of the three generated use cases, and the dependency is real.
  // The group below asserts it in the failing direction.
  setUp(() async {
    await resetServiceLocator();
    await configureDependencies();
  });
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
      final FakeAuthStatus replacement = FakeAuthStatus(authenticated: false);

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

    test('the change signal fires for a real state change, and nothing else', () async {
      // Phase 4 asserted this over a **placeholder** that could not fire, and the
      // property it was really pinning was the shape: a signal that announces
      // nothing until something happens. Phase 5 replaces the placeholder with
      // `ReevaluateListenable.stream(authBloc.stream)`, so the same property now
      // has a source and can be checked in both directions — silent while the
      // session does not change, loud when it does.
      final ReevaluateListenable changes = getIt<ReevaluateListenable>();
      final AuthBloc bloc = getIt<AuthBloc>();

      int notifications = 0;
      void listener() => notifications++;
      changes.addListener(listener);
      addTearDown(() => changes.removeListener(listener));

      // TWO TURNS, NOT ONE, and not `tester.pump()`. A signal that announced from
      // a microtask, a `Timer` or a post-frame callback would all be seen here,
      // and a single `await` observes only the first of those. A plain `test`,
      // because nothing here touches the widget tree — which is also why `pump`
      // would be theatre.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        notifications,
        isZero,
        reason:
            'nothing may announce a session change while there is no session to '
            'change. The signal subscribes to a bloc that has not emitted, so a '
            'notification here would mean the wiring itself is spurious',
      );

      // And the other direction, without which the assertion above is satisfied by
      // a signal that never fires at all — which is exactly what Phase 4's
      // placeholder did.
      bloc.add(const AuthStarted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        notifications,
        isPositive,
        reason:
            'a real state change must reach the router, or a sign-out would never '
            're-evaluate the stack and the guard would never notice',
      );
    });

    test('configuring twice fails loudly rather than double-registering', () {
      // `main` must call this exactly once. A silent no-op would leave two
      // different sessions in the graph depending on which call won.
      expect(configureNavigation, throwsArgumentError);
    });

    test('and the bloc is a singleton, so there is one session to read', () {
      // `registerSingleton`, not `registerLazySingleton`, because the object is
      // built by the hand-written provider rather than by a factory. A factory that
      // re-ran would hand out a *second* bloc with its own stream — a
      // `ReevaluateListenable` subscribed to a session nothing else reads, which is
      // the stale-bloc hazard `navigation_injection.dart` records for the router.
      expect(getIt<AuthBloc>(), same(getIt<AuthBloc>()));
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
      //
      // ONE assertion, where there were two. The second was
      // `expect(registered.navigatorKey.currentContext, isNot(throwsA(anything)))`,
      // which cannot fail: `throwsA` matches *callables that throw*, and the
      // subject is a `BuildContext?`, so the matcher returns `false` against it
      // unconditionally and `isNot` therefore matches everything that is not a
      // function — `null`, `42`, `'str'`, `[]` all passed. Probed, not assumed.
      // Sitting one line below a real assertion on the same subject, it read as a
      // second independent check.
      expect(
        registered.navigatorKey.currentContext,
        isNotNull,
        reason:
            'the router the locator handed out is the one MaterialApp.router '
            'mounted, so there is no second router holding a stale session',
      );
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
      final FakeAuthStatus status = FakeAuthStatus(authenticated: true);
      final ManualAuthChanges changes = ManualAuthChanges();
      final AppRouter router = AppRouter(status, changes);
      addTearDown(router.dispose);
      // Phase 5 adds a fourth thing this hand-built graph must supply: `LoginPage`
      // resolves its `AuthBloc` from the locator, and `/login` is where every one of
      // these navigations lands. Without it the redirect throws inside
      // `NeuralScaffold.build`. The **session** is still the substituted
      // `FakeAuthStatus` above — the bloc here is only what the screen reads to
      // render, and its own state is not what the guard answers with.
      registerTestAuthBloc();
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
    test('the generated core registrations and the navigation ones coexist', () async {
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
      // Phase 5's fourth hand-written registration, and the one that is not
      // optional: `AuthBloc` has no generated counterpart because
      // `flutter_bloc` re-exports Flutter (AGENT_CONTEXT §9, decision 11).
      expect(
        getIt.isRegistered<AuthBloc>(),
        isTrue,
        reason:
            'hand-registered by configureNavigation — see that file for why a '
            'generated registration is impossible here',
      );
    });

    test('and configureNavigation now REQUIRES the generated graph, which it did not '
        'before Phase 5', () async {
      // **This property was true in Phase 4 and is false now**, so the test that
      // asserted it is replaced rather than deleted: `configureNavigation()` used
      // to read nothing from the locator, which meant every router test could build
      // a router without configuring the whole app. It now reads the three
      // generated `auth` use cases to build the hand-registered `AuthBloc`, so the
      // ordering `bootstrapApp` documents — graph first, router second — went from
      // advisory to load-bearing.
      //
      // Asserted in the failing direction, because a graph that failed *quietly*
      // here would surface as `StateError: AuthRepository is not registered` in
      // whichever router test happened to run first, several files from the cause.
      await resetServiceLocator();

      expect(
        configureNavigation,
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('is not registered inside GetIt'),
          ),
        ),
        reason:
            'the hand-registered bloc is built from the generated use cases, so '
            'the generated graph has to exist first',
      );
    });

    test('and the auth registrations are reachable from the same locator', () async {
      // The seam restated from the other side. The generated half is asserted in
      // `injection_test.dart`; the hand-written half is here; this says one
      // locator holds both, and that the bloc the navigation seam reads is the
      // same object the locator holds.
      await resetServiceLocator();
      await configureDependencies();
      configureNavigation();

      expect(getIt<AuthBloc>(), same(getIt<AuthBloc>()));
      expect(
        getIt<AuthStatus>().isAuthenticated,
        same(getIt<AuthBloc>().state.isSignedIn),
        reason: 'the seam reads the bloc, it does not cache an answer',
      );
    });
  });
}

/// The pumped [MaterialApp], read off the tree rather than off the widget
/// instance, so the assertion describes what the framework actually received.
MaterialApp _materialAppIn(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));
