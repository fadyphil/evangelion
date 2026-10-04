import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

// The generated `*Route` classes, and the ONLY bridge to the six features.
//
// auto_route_generator emits `app_router.gr.dart` as a separate library named
// after this file rather than as a `part` of it, so this one import is what puts
// `LoginRoute` / `HomeRoute` / … in scope. The router does not import the six
// pages themselves: `@RoutePage()` on each page is what produces its route, and
// the generated library is already the reference to both. Six unused page
// imports is what the first draft had, and it is the shape a reader would read as
// "the router knows the widgets".
//
// Losing this import is six `undefined_identifier` errors — the cheap way to find
// out that the router and its routes have come apart.
import 'app_router.gr.dart';

/// The app's six routes plus the catch-all, with the global transition and the
/// auth gate installed.
///
/// ## WHY IT LIVES IN `lib/app/` AND NOT IN `lib/core/navigation/`
///
/// Because moving it there is a **gate violation**, and the violation is not in
/// this file — it is in the file the generator writes beside it.
///
/// auto_route_generator names its output after the router's own file. A router at
/// `lib/core/navigation/app_router.dart` therefore produces
/// `lib/core/navigation/app_router.gr.dart`, and that generated library imports
/// `package:flutter/material.dart` and all six `features/*/…/…_page.dart`.
/// `tool/verify_purity.sh` scans the files in a pure-Dart directory, so both gates
/// fire at once.
///
/// Measured, not assumed — the router was relocated, `build_runner` was re-run,
/// and `verify_purity.sh` reported **7 violations**: one Gate 1 (`app_router.gr.
/// dart:26: import 'package:flutter/material.dart'`) and six Gate 2 (`core must
/// not depend on auth / home / quiz / reading / result / settings`). Gate 1 is the
/// load-bearing one here: the router source itself imports no Flutter, so without
/// the generator's output in the directory the check would stay green and the
/// directory's documented purity would simply become a lie.
///
/// `lib/app/` is the one directory Gate 2 exempts, because the composition root is
/// *supposed* to reach into features to wire them up. `core/navigation/` keeps
/// `AppRoutes` and `AuthStatus`, both pure Dart — and that is what its own
/// `app_routes.dart` doc comment claims, in those words.
///
/// ## THE AUTH SEAM, AND WHY IT IS TWO PARAMETERS
///
/// [authStatus] answers "may this route be entered"; [authChanges] says when the
/// answer changed. Splitting them is deliberate: the answer is read on every
/// navigation, and the signal is handed to `MaterialApp.router` as the
/// `reevaluateListenable` of the `RouterConfig` that `AppRouter.config()` builds,
/// where it re-runs the guard over the whole stack. Neither mentions `AuthBloc`,
/// which is Phase 5's. See `core/navigation/auth_status.dart`.
///
/// ## WHY THE ROUTER IS NEVER A FIELD OF `app.dart`
///
/// `06-navigation.md` §8: it takes the session by constructor, so a second
/// instance built by hand in `app.dart` would sit alongside the injected one
/// holding a stale answer, and nothing would say which is live. It is registered
/// in `lib/app/di/navigation_injection.dart` and resolved from the locator
/// instead — see that file for why the registration is not a `@module`.
///
/// ## WHY `*` IS LAST
///
/// auto_route matches in **declaration order**, so `RedirectRoute(path: '*')`
/// listed first swallows every real route and the app opens `/login` for
/// everything. `app_routes.dart` says the same thing about the value; this is
/// where the ordering has to be kept, and `app_router_test.dart` asserts it on
/// the live route list rather than on a hand-written copy of it.
///
/// Measured, and the number is worth having in the repository rather than only in
/// git history: moving the wildcard to the front turns **46 tests** red. An earlier
/// commit message claimed nine, which was wrong in both direction and magnitude.
@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
class AppRouter extends RootStackRouter {
  /// Builds the router over the current session [authStatus] and its change
  /// signal [authChanges], positionally and in that order — the order
  /// `06-navigation.md` §8 spells for `AppRouter(this._authBloc)`.
  ///
  /// ## THE `AutoRouteObserver` IS NOT OPTIONAL, AND IT WAS MISSING
  ///
  /// `RootStackRouter`'s default `navigatorObservers` is
  /// `AutoRouterDelegate.defaultNavigatorObserversBuilder`, which returns
  /// `const []`. So **this router installed no `NavigatorObserver` at all**, and
  /// anything relying on one was silently inert: `AutoRouteAwareStateMixin`'s
  /// `didChangeDependencies` does
  /// `_observer = RouterScope.of(context).firstObserverOfType<AutoRouteObserver>()`
  /// and then `if (_observer != null)`. A `null` observer is not an error — it is
  /// a no-op, which is the worst shape of defect.
  ///
  /// That is how `/` came to never re-load on re-entry. `AutoRouteObserver` is what
  /// turns a `Navigator`'s push and pop into `didPushNext()` / `didPopNext()` on
  /// the route underneath, and with none installed, no page could be told it had
  /// been covered and uncovered. Phase 6 added the one observer the app needs;
  /// `home_navigation_test.dart` drives a real push/pop and asserts the re-fetch,
  /// which is the proof that it is wired rather than present.
  AppRouter(this._authStatus, this._authChanges);

  final AuthStatus _authStatus;
  final ReevaluateListenable _authChanges;

  /// The listenable `MaterialApp.router` must be given so a session change
  /// re-evaluates the stack.
  ///
  /// Exposed on the router rather than resolved separately in `app.dart` so
  /// there is exactly one object that knows both halves of the auth seam. A
  /// `ReevaluateListenable` is a `ChangeNotifier`, and nothing in Flutter
  /// disposes one handed to `RouterConfig` — [dispose] does it here instead, so
  /// the `AuthBloc` subscription behind it cannot outlive the router.
  ReevaluateListenable get authChanges => _authChanges;

  /// Every screen arrives with the Eva fade and 8px slide.
  ///
  /// `RouteType.custom` rather than a per-route `CustomRoute`: this is the one
  /// place the transition is declared, so no screen can be pushed with a
  /// different one by omission.
  ///
  /// `EvaMotion.screen`, not a new `screenDuration` — `06-navigation.md` §8 names
  /// `EvaMotion.screenDuration`, which does not exist and must not:
  /// `EvaMotion.screen` is already 250ms and is §5.3's `screen` token, so a
  /// second constant would be the same number twice. `EvaMotion.fadeSlide`
  /// carries the same reasoning for the curve.
  ///
  /// ## WHY `reverseDuration` IS STATED RATHER THAN INHERITED
  ///
  /// Leaving it out does not mean "the pop runs at the push's duration". auto_route
  /// resolves it on the live path for a custom route —
  /// `reverseTransitionDuration => routeType.reverseDuration ?? const
  /// Duration(milliseconds: 300)` (`auto_route_page.dart:231`, on
  /// `_CustomPageRouteTransitionMixin`) — so an unset `reverseDuration` is a
  /// literal **300ms** that appears in no motion table in `03-design-system.md`
  /// §5.3. The push would have been the `screen` token and the pop a framework
  /// default, which is the shape of defect nobody catches in review because the
  /// direction that was not looked at is the direction nobody performs.
  ///
  /// Back navigation is also the direction a reader feels most, because it is the
  /// one they chose rather than the one the app did to them. §5.3 gives `screen`
  /// as "a screen-level transition", which does not distinguish the two directions,
  /// so the honest reading is that both run the same token.
  ///
  /// `06-navigation.md` §80 — §8 — omits `reverseDuration` too, so this is a plan
  /// defect faithfully implemented rather than an oversight; the plan is not the
  /// authority (AGENT_CONTEXT §0), and where the two disagree on a number this
  /// file follows the motion table.
  @override
  RouteType get defaultRouteType => RouteType.custom(
    transitionsBuilder: EvaMotion.fadeSlide,
    duration: EvaMotion.screen,
    reverseDuration: EvaMotion.screen,
  );

  /// ## THE `AutoRouteObserver` IS NOT OPTIONAL, AND IT WAS MISSING
  ///
  /// `RootStackRouter.config()`'s own default for `navigatorObservers` is
  /// `AutoRouterDelegate.defaultNavigatorObserversBuilder`, which returns
  /// `const []`. So **this router installed no `NavigatorObserver` at all**, and
  /// anything relying on one was silently inert: `AutoRouteAwareStateMixin`'s
  /// `didChangeDependencies` does
  /// `_observer = RouterScope.of(context).firstObserverOfType<AutoRouteObserver>()`
  /// and then guards on `if (_observer != null)`. A `null` observer is not an
  /// error there — it is a no-op, which is the worst shape of defect: the code
  /// reads as wired and is not.
  ///
  /// That is how `/` came to never re-load on re-entry. `AutoRouteObserver` is what
  /// turns the `Navigator`'s push and pop into `didPushNext()` / `didPopNext()` on
  /// the route underneath, and with none installed no page could be told it had been
  /// covered and uncovered.
  ///
  /// **Overridden rather than handed in at the two `config()` call sites**, because
  /// the whole defect was a default nobody overrode: `app.dart` and
  /// `test/support/app_harness.dart` both call `router.config(reevaluateListenable:
  /// …)` and neither mentioned observers. A parameter passed at a call site is one
  /// a future call site forgets; a default replaced here cannot be forgotten.
  /// `home_navigation_test.dart` drives a real push/pop and asserts the re-fetch,
  /// which is the proof that it is wired rather than merely present.
  ///
  /// A caller-supplied [navigatorObservers] is honoured and this one is **added**,
  /// not substituted — an observer is additive (a `NavigatorObserver` sees events,
  /// it does not own them), so replacing the list would silently un-subscribe
  /// whatever the caller installed.
  @override
  RouterConfig<UrlState> config({
    DeepLinkTransformer? deepLinkTransformer,
    DeepLinkBuilder? deepLinkBuilder,
    String? navRestorationScopeId,
    WidgetBuilder? placeholder,
    NavigatorObserversBuilder? navigatorObservers,
    bool includePrefixMatches = !kIsWeb,
    bool Function(String? location)? neglectWhen,
    bool rebuildStackOnDeepLink = false,
    Listenable? reevaluateListenable,
    Clip clipBehavior = Clip.hardEdge,
  }) => super.config(
    deepLinkTransformer: deepLinkTransformer,
    deepLinkBuilder: deepLinkBuilder,
    navRestorationScopeId: navRestorationScopeId,
    placeholder: placeholder,
    navigatorObservers: () => <NavigatorObserver>[
      ...?navigatorObservers?.call(),
      AutoRouteObserver(),
    ],
    includePrefixMatches: includePrefixMatches,
    neglectWhen: neglectWhen,
    rebuildStackOnDeepLink: rebuildStackOnDeepLink,
    reevaluateListenable: reevaluateListenable,
    clipBehavior: clipBehavior,
  );

  /// The six locked routes, then the wildcard.
  ///
  /// Paths are [AppRoutes] constants, never re-spelled: `'/login'` written here
  /// and `AppRoutes.login` written there are two names for one route, and the
  /// compiler cannot see the disagreement. `AppRoutes` also documents why [home]
  /// is `'/'` rather than `''`, and why [AppRoutes.fallback] is the bare `'*'`
  /// sentinel with no leading slash.
  ///
  /// ## WHAT IS AND IS NOT TRUE ABOUT THAT SENTINEL, because both halves were
  /// wrong here once
  ///
  /// TRUE, and load-bearing: **`*` must be last** (see below).
  ///
  /// FALSE, and deleted: "auto_route only recognises the bare asterisk, so `'/*'`
  /// would not work". It works. `'/*'` is accepted by the matcher and behaves
  /// identically for `/x`, `//`, `''`, `/not-a-route`, `/login/x`,
  /// `/deeply/nested/x` and `/LOGIN` — the whole measured table is in
  /// `app_router_test.dart`, which asserts the wildcard's coverage by executing the
  /// matcher instead of by comparing the spelling. `'*'` is used because it is the
  /// form auto_route documents and because it leaves exactly one declared path
  /// outside the slash-prefixed set, not because `'/*'` is broken.
  ///
  /// Of the six, `/login` is the only unguarded one: it is the app's entry point,
  /// and a gate in front of it would redirect to itself forever. The wildcard is
  /// unguarded too, which is deliberate — an unknown path redirects to `/`, which
  /// bounces through the guard and lands on the login screen when there is no
  /// session (`06-navigation.md` §8).
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(path: AppRoutes.login, page: LoginRoute.page),
    AutoRoute(path: AppRoutes.home, page: HomeRoute.page, guards: _guards),
    AutoRoute(
      path: AppRoutes.reading,
      page: ReadingRoute.page,
      guards: _guards,
    ),
    AutoRoute(path: AppRoutes.quiz, page: QuizRoute.page, guards: _guards),
    AutoRoute(path: AppRoutes.result, page: ResultRoute.page, guards: _guards),
    AutoRoute(
      path: AppRoutes.settings,
      page: SettingsRoute.page,
      guards: _guards,
    ),
    RedirectRoute(path: AppRoutes.fallback, redirectTo: AppRoutes.home),
  ];

  /// A fresh guard per route, all over the same session.
  ///
  /// The getter is re-read whenever the matcher rebuilds, so this allocates one
  /// guard per guarded route per read. That is free — [AuthGuard] is a two-field
  /// object holding only the [AuthStatus] — and it buys one property worth having:
  /// no guard can end up reading a different session from its neighbours.
  /// `app_router_test.dart` pins that property by flipping one session and
  /// checking every guard's decision moved with it.
  List<AutoRouteGuard> get _guards => <AutoRouteGuard>[AuthGuard(_authStatus)];

  /// Releases the [ReevaluateListenable] this router was given, then itself.
  ///
  /// The signal is disposed here rather than left to the widget tree because
  /// nothing in Flutter owns it: `RouterConfig` does not dispose the listenable
  /// it is handed, and `Router`'s teardown knows nothing about it. Phase 5's
  /// signal wraps an `AuthBloc` subscription, so an undisposed one would be a
  /// live stream feeding a dead delegate.
  @override
  void dispose() {
    _authChanges.dispose();
    super.dispose();
  }
}
