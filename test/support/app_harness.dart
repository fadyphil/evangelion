import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/di/navigation_injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_light.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

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
  //
  // **The pure-Dart graph is configured first, and it is no longer optional.**
  // Phase 4's `configureNavigation()` read nothing from the locator, so a router
  // test could skip the whole app graph. It reads `AuthBloc` now — the bloc cannot
  // be generated, because the only import that reaches it re-exports Flutter
  // (AGENT_CONTEXT §9, decision 11) — so the ordering `bootstrapApp` documents
  // ("graph first, router second") became load-bearing rather than advisory.
  // `navigation_injection_test.dart` asserts that dependency in the failing
  // direction, so this call is not a convenience.
  if (!getIt.isRegistered<GetIt>()) {
    await configureDependencies();
  }
  if (!getIt.isRegistered<AppRouter>()) {
    configureNavigation();
  }
  await tester.pumpWidget(EvangelionApp(locale: locale));
  await pumpUntilFound(tester, find.byType(LoginPage));

  // WHY THE ASSERTION IS HERE RATHER THAN AT EACH CALL SITE. `pumpApp` is called
  // for claims about the SHELL — the title, the localisations, the theme, the
  // absence of `home:` — and every one of those is satisfiable by an app that
  // rendered no page at all: `MaterialApp` is in the tree, its `routerConfig` is
  // non-null, and `find.byType(LoginPage)` matches nothing. `pumpUntilFound`
  // gives up silently after 12 frames, so before this assertion
  // `app_test.dart`'s "is titled Evangelion" and "runs without exceptions" both
  // passed on a blank frame.
  expect(
    find.byType(LoginPage),
    findsOneWidget,
    reason:
        'pumpApp means "the app is up and on its entry route"; a blank frame '
        'would satisfy every claim the callers make about the shell',
  );
}

/// The app shell the router and guard suites mount.
///
/// Deliberately not `EvangelionApp`: those suites are about the router and the
/// guard, and `EvangelionApp` resolves the router **from the locator**, so using it
/// would replace the substituted router under test with the injected one. A shell
/// keeps each assertion pointing at one thing, and `app_test.dart` owns the claim
/// that the real app uses the resolved router.
///
/// ## IT DOES INSTALL THE EVA THEME, BECAUSE A ROUTE MUST RENDER
///
/// Phase 4's shell could be a bare `MaterialApp.router`, because the six stub pages
/// were a `Scaffold` and an `AppBar`. Phase 5's `/login` is a real screen and
/// `context.colors` asserts that `EvaColors` is on the theme
/// (`eva_colors.dart:294`), so a bare `MaterialApp` fails with
/// "EvaColors is missing from this ThemeData" **inside `NeuralScaffold.build`**.
///
/// The same two-palette, dark-first arrangement `app.dart` uses, so what these
/// suites render is what the app renders. That is not a change of subject: a route
/// that cannot mount is not a route, and the alternative — stubbing `/login` back
/// out of the router — would leave the router untested against the only screen it
/// really has.
///
/// It was `host` in `auth_guard_test.dart` and `routerHost` in
/// `app_router_test.dart`: the same widget, the same doc comment, two names.
/// One name, here, beside the other shared fixture.
///
/// ## IT REGISTERS THE `AuthBloc`, AND THAT IS A SIDE EFFECT WORTH NAMING
///
/// Every route a router can land on includes `/login`, and `LoginPage` resolves its
/// bloc from the locator — so mounting the real router mounts a real `LoginPage`,
/// and a locator without an `AuthBloc` throws `StateError: AuthBloc is not
/// registered` **inside `build`**. Registering it here rather than in each of the
/// twelve call sites keeps the two together: a shell that cannot mount the routes
/// it exists to route to is not a shell.
///
/// It is registration and not `configureNavigation()`, because these suites
/// substitute their own `AuthStatus` and listenable and that function rejects a
/// duplicate registration. `registerTestAuthBloc` supplies exactly the one piece
/// they do not own, and `addTearDown`s it.
Widget routerHost(AppRouter router, {Locale? locale}) {
  if (!getIt.isRegistered<AuthBloc>()) {
    registerTestAuthBloc();
  }
  // **The same obligation, one route over.** Phase 6 made `/` resolve its
  // `HomeBloc` from the locator for the reason `LoginPage` resolves its `AuthBloc`:
  // a page that created its own would have one set of repository results per mount,
  // and a retry has to be able to replace them. So every router test that can land
  // on `/` needs a `HomeBloc` in the graph, and the two registrations live together
  // so a third page cannot be added without the next reader seeing this line.
  if (!getIt.isRegistered<HomeBloc>()) {
    registerTestHomeBloc();
  }
  // **The third registration, for the same reason.** `ReadingPage` resolves its
  // `ReadingCubit` from the locator exactly as `HomePage` resolves its `HomeBloc` and
  // `LoginPage` its `AuthBloc`, so a router test that lands on `/reading` needs one in
  // the graph or the page throws a `StateError` out of `build`. Adding it here rather
  // than at each call site is the point of the paragraph above.
  if (!getIt.isRegistered<ReadingCubit>()) {
    registerTestReadingCubit();
  }
  // `NeuralMotionScope` above the app, for the same reason `app.dart` mounts it
  // there: §13.2 mitigation 2 puts the three shared ambient controllers in ONE
  // `TickerProviderStateMixin` host above `MaterialApp`, so a screen never
  // constructs one and there is nothing for it to forget to dispose.
  //
  // It is also **why these suites cannot use `pumpAndSettle`**: three `repeat()`ing
  // controllers mean "settled" never arrives. They use [pumpUntilFound] instead,
  // which is the whole reason that helper exists.
  return NeuralMotionScope(
    child: MaterialApp.router(
      routerConfig: router.config(reevaluateListenable: router.authChanges),
      theme: EvaThemeLight.theme,
      darkTheme: EvaThemeDark.theme,
      themeMode: ThemeMode.dark,
      // Phase 6 needs the app's own delegate trio and locale pair, and for the same
      // reason the theme is installed above: `HomePage` reads
      // `Localizations.localeOf(context)` to resolve the `ReadingLanguage` the
      // reading is requested in, and a `MaterialApp` with no
      // `localizationsDelegates` installs no `_LocalizationsScope` at all — so
      // `Localizations.localeOf` **throws** rather than returning a default.
      //
      // The pair is `app.dart`'s, not a convenient one: `supportedLocales` must list
      // `ar` or `MaterialApp` resolves it back to `en`, which is the harness bug
      // `login_harness.dart` already records.
      //
      // **`locale` is Phase 6's addition, and it is a parameter rather than a
      // `Localizations` wrapper for a measured reason.** `MaterialApp` installs its
      // own `_LocalizationsScope` as a **descendant** of anything wrapped around it,
      // so a `Localizations` widget above this one is shadowed and silently
      // ineffective — a wrapper that looks like it works and does not. With
      // [locale] null the app resolves the platform locale, which is every existing
      // caller's situation, so the default changes nothing for them.
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
    ),
  );
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
///
/// Mutable on purpose. The guard reads the same instance on every navigation and
/// on every stack re-evaluation, so flipping this is how a test simulates a
/// login or a logout without a bloc — the seam Phase 5 fills.
///
/// ## ONE FAKE, THREE SUITES, AND THE `reads` COUNTER IS WHY
///
/// This started as three near-identical classes — this one, plus a private copy in
/// `app_router_test.dart` and another in `auth_guard_test.dart`. The only things
/// that differed were the fields each suite happened to touch. [reads] is what
/// earns the merge: a test that wants to know whether the guard ran at all has no
/// other observable, so the counter belongs to the shared fake rather than to one
/// suite's copy of it.
final class FakeAuthStatus implements AuthStatus {
  FakeAuthStatus({this.authenticated = true});

  /// What the app currently believes. Flip it to simulate a sign-in or a sign-out.
  bool authenticated;

  /// How many times the guard has asked [isAuthenticated].
  ///
  /// A measurement of how many times the guard ran, which is the only way to
  /// observe re-evaluation from outside a guard: `resolver.isReevaluating` is set
  /// inside auto_route.
  int reads = 0;

  @override
  bool get isAuthenticated {
    reads++;
    return authenticated;
  }
}

/// Registers the `AuthBloc` [LoginPage] resolves, and returns it.
///
/// ## WHY A SEPARATE STEP
///
/// `LoginPage` resolves its bloc from the locator when the router builds it — a
/// page that created its own would have one session per mount, and the navigation
/// guard reads the *locator's*. So every test that mounts the real `LoginPage`
/// through `AppRouter` needs an `AuthBloc` in the graph.
///
/// The router suites (`app_router_test.dart`, `auth_guard_test.dart`) register
/// `AuthStatus`, `ReevaluateListenable` and `AppRouter` **by hand**, because the
/// whole point of those suites is to substitute a controllable session — and
/// `configureNavigation()` rejects a duplicate registration. They therefore cannot
/// call it, and this is the one piece of the graph they have to supply themselves.
///
/// **Built inside the caller's zone**, which for a `testWidgets` means inside the
/// test body: a bloc created in `setUp` does not deliver its events into the fake
/// async zone `tester.pump()` drains. `login_page_test.dart` records the
/// measurement.
AuthBloc registerTestAuthBloc() {
  final FakeAuthRepository repository = FakeAuthRepository(
    AuthLocalDataSource(),
  );
  final AuthBloc bloc = AuthBloc(
    signIn: SignIn(repository),
    getCurrentSession: GetCurrentSession(repository),
    signOut: SignOut(repository),
  );
  getIt.registerSingleton<AuthBloc>(bloc);
  addTearDown(() => getIt.unregister<AuthBloc>());
  addTearDown(bloc.close);
  return bloc;
}

/// Registers the `HomeBloc` [HomePage] resolves, and returns it.
///
/// The `HomeBloc` twin of [registerTestAuthBloc], over the same three fake ports,
/// and for the same two reasons: `HomePage` resolves its bloc from the locator, and
/// a bloc created in `setUp` does not deliver its events into the fake-async zone
/// `tester.pump()` drains (`login_harness.dart` records the measurement).
///
/// Built over **fakes**, not the live adapters, and that is what keeps the router
/// suites about the router: `HomePage` reaching `DioReadingRepository` in a widget
/// test would either open a socket to `localhost:3000` or fail, and a suite about
/// which route is on top would then depend on whether a backend happens to be
/// running.
///
/// No `Dio`, so this file stays importable from a suite that must not pull the
/// network stack into the graph it is asserting on.
HomeBloc registerTestHomeBloc() {
  final HomeBloc bloc = HomeBloc(
    loadTodayReading: LoadTodayReading(_FakeReadingRepository()),
    loadStreakSummary: LoadStreakSummary(_FakeStreakRepository()),
    getReaderSession: GetReaderSession(
      FakeAuthRepository(AuthLocalDataSource()),
    ),
  );
  getIt.registerSingleton<HomeBloc>(bloc);
  addTearDown(() => getIt.unregister<HomeBloc>());
  addTearDown(bloc.close);
  return bloc;
}

/// Registers the `ReadingCubit` [ReadingPage] resolves, and returns it.
///
/// The third of the three, and the first whose state a **reader** sets rather than a
/// repository fills: the font step lives for the life of the cubit because Phase 7 has
/// no `SettingsRepository` (see `reading_cubit.dart`). That is also why this is a
/// `registerSingleton` and not a factory — the same single-instance hazard
/// `registerTestHomeBloc`'s doc gives.
ReadingCubit registerTestReadingCubit() {
  final ReadingCubit cubit = ReadingCubit(
    loadScripture: LoadScripture(_FakeReadingRepository()),
  );
  getIt.registerSingleton<ReadingCubit>(cubit);
  addTearDown(() => getIt.unregister<ReadingCubit>());
  addTearDown(cubit.close);
  return cubit;
}

/// A [ReadingRepository] that answers a fixed reading.
///
/// Hand-written rather than a `mocktail` mock for the reason the LSP row in
/// `home_bloc_test.dart` gives: a mock implements whatever it is told to, so it can
/// satisfy the port and answer nothing. This one always answers, which is what
/// `routerHost`'s callers need — they are about the route, not about the payload.
final class _FakeReadingRepository implements ReadingRepository {
  @override
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  }) async => const Result<ScriptureText>.failure(
    Failure(
      kind: FailureKind.network,
      message: 'No reading: this harness does not open a socket.',
    ),
  );

  /// Narrowing, exactly as `DioReadingRepository.today` does — the port defines
  /// [today] in terms of [todayScripture], and a fake that answered the narrow
  /// method by a second route would be the one implementation in the tree that
  /// does not.
  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async =>
      (await todayScripture(language: language))
          .map((ScriptureText scripture) => scripture.toTodayReading());
}

/// The [StreakRepository] twin of [_FakeReadingRepository].
final class _FakeStreakRepository implements StreakRepository {
  @override
  Future<Result<StreakSummary>> summary() async =>
      const Result<StreakSummary>.failure(
        Failure(
          kind: FailureKind.network,
          message: 'No streak: this harness does not open a socket.',
        ),
      );
}

/// Empties the locator, so each test starts from a clean registration set.
///
/// `GetIt.instance` is a process-wide singleton, so a registration made by one
/// test is visible to every test that runs after it unless something resets it.
/// Called from `setUp` *and* `tearDown`: `setUp` alone leaves a graph behind for
/// whichever suite happens to be collected next, and `configureNavigation()`
/// rejects a duplicate registration, so the failure would surface somewhere
/// unrelated.
Future<void> resetServiceLocator() => getIt.reset();
