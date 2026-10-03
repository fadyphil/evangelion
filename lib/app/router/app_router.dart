import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/auth_guard.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/auth_status.dart';

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
@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
class AppRouter extends RootStackRouter {
  /// Builds the router over the current session [authStatus] and its change
  /// signal [authChanges], positionally and in that order — the order
  /// `06-navigation.md` §8 spells for `AppRouter(this._authBloc)`.
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
  @override
  RouteType get defaultRouteType => RouteType.custom(
    transitionsBuilder: EvaMotion.fadeSlide,
    duration: EvaMotion.screen,
  );

  /// The six locked routes, then the wildcard.
  ///
  /// Paths are [AppRoutes] constants, never re-spelled: `'/login'` written here
  /// and `AppRoutes.login` written there are two names for one route, and the
  /// compiler cannot see the disagreement. `AppRoutes` also documents why [home]
  /// is `'/'` rather than `''`, and why [AppRoutes.fallback] is `'*'` with no
  /// leading slash — auto_route 11.2.0 special-cases that bare literal.
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
