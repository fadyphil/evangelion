import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/quiz/domain/usecases/refresh_session_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';

/// The **Flutter half** of the object graph: the auth seam and the router.
///
/// ## WHY THIS IS NOT A `@MODULE` IN `injection.dart`'S GRAPH
///
/// `injection.dart` is required to be Flutter-free, and not just in the shallow
/// sense of "has no `import 'package:flutter/…'`": `injection_test.dart` walks
/// its whole transitive **project-local** import graph and fails if anything in
/// the closure imports Flutter. A generated `injection.config.dart` imports every
/// `@module` in the package, so registering the router from a module would put
/// `app_router.dart` — which names all six `*Route` classes and therefore reaches
/// `package:flutter/material.dart` through the generated route files — inside
/// that closure, and the existing gate would go red. Phase 1 found that gate
/// defeated by a single `export … show X;` line, so it is not one to route
/// around.
///
/// `AuthBloc` hits the identical wall, and the mechanism is spelled out here
/// because it is not obvious: `AuthBloc extends Bloc`, and `Bloc` arrives through
/// `package:flutter_bloc/flutter_bloc.dart`, which **re-exports Flutter's widget
/// layer** alongside the bloc. The obvious-looking import —
/// `package:bloc/bloc.dart` — is unavailable, because `bloc` is a *transitive*
/// dependency and AGENT_CONTEXT §8.4 makes promoting it a hard stop. So there is
/// no spelling of "register this bloc" that keeps Flutter out of the closure.
///
/// Both requirements are legitimate and neither may be weakened, so the graph
/// splits along the line that already exists in it: the pure-Dart half keeps its
/// generated `@InjectableInit`, and the half that genuinely needs the framework is
/// registered by hand here. `06-navigation.md` §8's requirement — "registered as a
/// factory that reads the session from the `getIt` instance" — is honoured for the
/// router; only the file differs from the plan, and `core_module.dart` says so
/// where the plan's file map would have put it.
///
/// WHAT THIS COSTS, STATED PLAINLY: **five** registrations are now written by hand
/// instead of generated (`AuthBloc`, `HomeBloc`, `ReadingCubit`, `QuizBloc` and the
/// router), so `injection.config.dart` no longer shows them in a
/// diff. That is the price of the purity gate, taken knowingly, and it is why
/// `navigation_injection_test.dart` exercises this function as behaviour —
/// presence, lifetime, identity — rather than trusting the source.
///
/// ## `HomeBloc` HITS THE SAME WALL, AND IT IS THE THIRD TIME
///
/// `HomeBloc extends Bloc`, so the mechanism above applies verbatim:
/// `package:bloc/bloc.dart` is unavailable because `bloc` is a transitive dependency
/// §8.4 will not promote, and `package:flutter_bloc/flutter_bloc.dart` re-exports
/// Flutter's widget layer. So `HomeBloc` is built here from the three **generated**
/// use cases and registered with `registerSingleton`.
///
/// **`registerSingleton`, not `registerLazySingleton`, for the same reason `AuthBloc`
/// uses it.** A lazy singleton whose factory re-ran would hand out a second bloc
/// with its own stream, subscribed to by nothing. The object is already built here,
/// so there is no factory to re-run.
///
/// **And no `language` parameter**, which is the one thing that differs from a
/// naive hand registration: the arm of the corpus arrives on `HomeStarted`, because
/// the only place a `Locale` exists is a widget and this function is not one. See
/// `HomeStarted`'s doc.
///
/// The cost is the same line the rest of this file's doc already states, now three
/// hand-registered blocs. `injection_test.dart` refuses them in the generated config
/// and `navigation_injection_test.dart` resolves them, so neither half can drift.
///
/// ## AND `ReadingCubit` HITS IT A **FOURTH** TIME — WHICH IS THE PREDICTION
/// `reading_module.dart` MADE BEFORE PHASE 7 EXISTED
///
/// `ReadingCubit extends Cubit`, so the mechanism above applies verbatim, and
/// `reading_module.dart`'s own doc said so in advance: "there is no spelling of
/// 'register this cubit' that keeps Flutter out of this graph". It is here.
///
/// ## AND IT IS A **`registerSingleton`**, LIKE THE OTHER TWO, FOR THE SAME REASON
///
/// A `@factory` here would hand out a **second** cubit with its own state, and the
/// reader's font step — which is state for the life of the cubit, because Phase 7 has
/// no `SettingsRepository` — would live in whichever instance `ReadingPage` happened
/// to resolve. The single-instance hazard `HomeBloc` documents applies here with more
/// force, because `ReadingCubit` holds something a reader set rather than something
/// refetched.
///
/// ## AND `QuizBloc` HITS IT A **FIFTH** TIME — AND ITS `lastResult` IS WHY THE
/// ## SINGLETON MATTERS MORE HERE THAN ANYWHERE ELSE
///
/// `QuizBloc extends Bloc`, so the mechanism above applies verbatim, and
/// `quiz_module.dart` said so in advance — "there is no spelling of 'register this
/// bloc' that keeps Flutter out of this graph". It is here.
///
/// **The extra stake is `QuizState.lastResult`.** §2's route table gives `/result`
/// "submit response" as its data source and `08-build-phases.md` says the screen
/// "reads the submit response held by `QuizBloc`" — so this object is the **only**
/// place that response is kept. A `@factory` would hand out a **second** bloc whose
/// `lastResult` was `null` for ever, and a reader who answered three questions and
/// pressed "See results" would arrive at a screen that cannot be built. `quiz_module`
/// registers the three use cases, all `@lazySingleton` over the same
/// `ReadingRepository`, so every bloc in the process talks to one port instance.
///
/// ## WHY `AppRouter` IS A LAZY SINGLETON AND NOT A FACTORY
///
/// `06-navigation.md` §8 warns against a second `AppRouter` existing alongside
/// the injected one "with a stale bloc". A get_it `@factory` guarantees exactly
/// that: `getIt<AppRouter>()` hands back a *new* router every call, only one of
/// which is the one `app.dart` mounted, and any other caller — a test, a future
/// screen, a debug tool — gets an object with its own `navigatorKey` and no
/// `Navigator` behind it.
///
/// Mutation-checked: rewriting this registration to a factory turns exactly the
/// identity assertions in `navigation_injection_test.dart` red, and the failure
/// prints two routers with identical `toString` — which is the whole difficulty
/// of this bug, since nothing about either object looks wrong.
///
/// ## ORDER: `AuthBloc` BEFORE `AuthStatus`, AND WHY IT IS NOT A LUCKY SEQUENCE
///
/// [AuthStatus]'s provider reads [AuthBloc] out of the locator when it resolves,
/// and `AppRouter`'s provider reads [AuthStatus]. All three are
/// `@lazySingleton`, so nothing runs during this function — the order below is
/// readability, and the real requirement is that `bootstrapApp` calls
/// `configureNavigation()` **after** `configureDependencies()`, which it does
/// (step 3 of 4, `bootstrap.dart`).
///
/// Getting that wrong has a measured cost, not a hypothetical one: re-binding
/// `AuthStatus` after the router exists leaves the router holding the previous
/// one, because the router captured it at construction. `app.dart` reads the
/// locator once, in `build`, so that dependency is visible in the shape of the
/// statement rather than hidden inside it, and
/// `navigation_injection_test.dart` asserts the re-binding case in the failing
/// direction.
///
/// ## WHAT PHASE 4 LEFT BEHIND, AND WHAT REPLACED IT
///
/// Phase 4's `AuthStatus` was `_NoSession` and its change signal was
/// `_NoAuthChanges`, both labelled as placeholders. Both are gone:
///
/// * `_NoSession` is replaced by [BlocAuthStatus], which reads `AuthBloc.state` —
///   a field read, which is exactly what `core/navigation/auth_status.dart`
///   demands of an implementation ("a pure read … cheap, never a fetch, never a
///   validation").
/// * `_NoAuthChanges` is replaced by `ReevaluateListenable.stream(authBloc.stream)`,
///   so a sign-out re-evaluates the whole stack. `_NoAuthChanges` had no
///   subscription to leak and could not accidentally start notifying; the stream
///   wrapper can, which is why `AppRouter.dispose()` disposes it (see that
///   getter's doc) rather than leaving it to the widget tree, which knows nothing
///   about a `ReevaluateListenable` it was handed.
///
/// The placeholder's pinned behaviour is worth keeping in mind as the shape to
/// copy: `navigation_injection_test.dart` subscribes, gives the event loop two
/// turns, and asserts the count is still **zero** — a signal that announces
/// nothing. The replacement is the same contract with a real source.
void configureNavigation() {
  // **Built here, not resolved from the locator** — that is what "hand-registered"
  // means. Nothing generates this registration, so nothing else will construct the
  // bloc; the three use cases *are* generated, so they are resolved from the
  // locator, which is what makes the hand-written half depend on the generated one
  // and not the other way round.
  final AuthBloc authBloc = AuthBloc(
    signIn: getIt<SignIn>(),
    getCurrentSession: getIt<GetCurrentSession>(),
    signOut: getIt<SignOut>(),
  );
  // **Built here, not resolved from the locator** — see the `HomeBloc` section for
  // why, and why it is a `registerSingleton` for the reason the `AuthBloc` comment
  // below gives.
  final HomeBloc homeBloc = HomeBloc(
    loadTodayReading: getIt<LoadTodayReading>(),
    loadStreakSummary: getIt<LoadStreakSummary>(),
    getReaderSession: getIt<GetReaderSession>(),
  );
  // **Built here, not resolved from the locator** — see the `ReadingCubit` section.
  final ReadingCubit readingCubit = ReadingCubit(
    loadScripture: getIt<LoadScripture>(),
  );

  // **Built here, not resolved from the locator** — see the `QuizBloc` section for
  // the mechanism and for why `lastResult` makes the singleton load-bearing.
  final QuizBloc quizBloc = QuizBloc(
    startSession: getIt<StartSession>(),
    refreshSessionQuestions: getIt<RefreshSessionQuestions>(),
    submitAnswer: getIt<SubmitAnswer>(),
  );

  getIt
    // `registerSingleton`, not `registerLazySingleton`: the object is already
    // built, and a lazy singleton whose factory re-ran would hand out a *second*
    // bloc with its own stream — a signal subscribed to a bloc nothing else reads,
    // which is the exact "stale bloc" hazard this file's `AppRouter` section is
    // about.
    ..registerSingleton<AuthBloc>(authBloc)
    ..registerSingleton<HomeBloc>(homeBloc)
    ..registerSingleton<ReadingCubit>(readingCubit)
    ..registerSingleton<QuizBloc>(quizBloc)
    ..registerLazySingleton<AuthStatus>(() => BlocAuthStatus(authBloc))
    ..registerLazySingleton<ReevaluateListenable>(
      () => ReevaluateListenable.stream(authBloc.stream),
    )
    ..registerLazySingleton<AppRouter>(
      () => AppRouter(getIt<AuthStatus>(), getIt<ReevaluateListenable>()),
    );

  _clearHomeStateOnSignOut(authBloc, homeBloc);
}

/// Sign-out empties `/`'s state, and **this function is why**.
///
/// ## THE RETENTION, MEASURED
///
/// `HomeBloc` is a `registerSingleton` above, so it lives for the whole process.
/// `_onStarted` puts a reader's `displayName`, `initials`, today's `reading` and the
/// `streak` into it, and nothing took them out: `AuthBloc._onSignedOut` emits
/// `AuthState.signedOut` and stops there. A signed-out process therefore held a
/// person's display name, their monogram, and their reading history in memory
/// indefinitely — and it is not only a hygiene point, because `/` is the screen a
/// **second** signed-in reader would land on and `HomeStarted`'s first emit copies
/// the previous reader's fields forward.
///
/// ## WHY IT LIVES HERE AND NOT IN `AuthBloc`
///
/// The obvious fix is for `AuthBloc` to clear it, and it is forbidden twice over:
/// `AuthBloc` is in `features/auth` and `HomeBloc` is in `features/home`, so naming
/// it is a cross-feature import — **Gate 2**, and the same wall the `HomeBloc`
/// section above spent a paragraph on. The reverse direction is equally closed.
///
/// `lib/app/` is the one directory Gate 2 exempts (decision 16) and this function
/// already has **both** blocs in hand: it built them two lines above. So the seam
/// is one subscription in the composition root, which is the only place that is
/// allowed to know about both features — and is the place a reader looks for
/// cross-feature wiring.
///
/// ## NOT DISPOSED, DELIBERATELY
///
/// The subscription outlives the call, like the blocs it joins: both are
/// process-wide, so there is nothing shorter for it to be scoped to. `Bloc.stream`
/// closes when the bloc does, and the locator is reset between tests rather than
/// between users.
///
/// **Not a `ReevaluateListenable`** the way the router's change signal is. That one
/// exists to re-run the guard, and a guard re-run on sign-*in* is what resumes the
/// interrupted navigation — this one has no router work to do, only memory to
/// release, and routing the same event through a second signal would have given the
/// router a second reason to rebuild the stack.
/// ## AND IT FIRES ON `signedOut`, **NOT** ON `!isSignedIn` — measured
///
/// The first version wrote `if (!state.isSignedIn)`. `AuthSessionStatus` has **four**
/// values — `unknown`, `signedOut`, `signingIn`, `signedIn` — so `!isSignedIn` is
/// also true of `signingIn`, and `AuthSubmitted` emits exactly that on its way to
/// `signedIn`. The clear therefore ran **in the middle of every successful sign-in**,
/// blanking `/` three emits before the greeting resolved. The test written for the
/// opposite direction (`a sign-IN does not`) is what caught it, which is the argument
/// for writing both directions of a new listener.
///
/// `status == AuthSessionStatus.signedOut` is the one transition that means "there is
/// no session and there will not be one".
void _clearHomeStateOnSignOut(AuthBloc auth, HomeBloc home) {
  auth.stream.listen((AuthState state) {
    if (state.status == AuthSessionStatus.signedOut) {
      home.add(const HomeCleared());
    }
  });
}

/// [AuthStatus] over an [AuthBloc].
///
/// The whole of Phase 4's four contracts is satisfied by three lines, and the
/// length is the point — see `core/navigation/auth_status.dart` for what each
/// contract costs when broken:
///
/// 1. **A pure read.** `state.isSignedIn` is a getter over an enum, so it is
///    cheap and side-effect-free. The guard calls it on every navigation *and*
///    again on every stack re-evaluation; an async answer would turn a redirect
///    into a loading state.
/// 2. **It cannot throw.** `AuthState.isSignedIn` compares an enum against a
///    constant. There is no await, no nullable dereference and no port call, so
///    the escape the guard deliberately does not catch is unreachable from here.
/// 3. **It is bound before the router resolves it**, by `configureNavigation`'s
///    order and by `bootstrapApp`'s.
/// 4. **It is not a mirror.** The answer is read from the bloc's current state on
///    every call rather than cached, so a bloc that emits between two navigations
///    is reflected immediately — which is the whole reason the signal below exists
///    alongside it.
///
/// **Contract 4 was the one the suite could not see, and the mutation is recorded
/// here because the number is the interesting part.** Freezing the answer at
/// construction — `bool get isAuthenticated => _cached`, with `_cached` set in the
/// constructor — left all 1200 tests green at the time this was written. What it
/// cost was measured: the reader signs in, `bloc.state` becomes `signedIn`, the
/// form reports `LoginOutcome.signedIn`, and the guard then asks the seam again on
/// the re-evaluation and gets the stale `false`. The stack settles back on
/// `[LoginRoute]` with `HomePage` never built.
///
/// Two assertions now hold it, both in `navigation_injection_test.dart`: the seam
/// is read in **both** directions around a real session change, and the whole loop
/// is driven end to end over these registrations. The first version of the file's
/// claim was `same(...)` on two `bool`s, which can never be false.
final class BlocAuthStatus implements AuthStatus {
  /// Reports [bloc]'s current state.
  const BlocAuthStatus(this._bloc);

  final AuthBloc _bloc;

  @override
  bool get isAuthenticated => _bloc.state.isSignedIn;
}
