/// The shared fixture for `/journey`'s screen suite.
///
/// ## WHAT THIS FILE IS
///
/// The **screen** suite (`journey_page_test.dart`) needs four things the widget
/// suite (`journey_widgets_test.dart`) does not:
///
/// * a [JourneyCubit] over **fakes that count**, so "the retry asked again" is
///   a measurement and not an inference;
/// * a **real router**, because the page navigates with `context.router` and a
///   mock router would record the call without proving the route name is real —
///   `home_navigation_test.dart` states the argument at length;
/// * a **session** the page can read, so the orb and the name line have
///   something to draw;
/// * a **history** with numbers in it, because a suite that asserted "there is a
///   rings row" would pass with every ring wrong.
///
/// ## AND WHY THE FIXTURE IS **CHOSEN** AND NOT INHERITED
///
/// The history below is not a copy of `/`'s `liveStreakHistoryEntry`: it is
/// **four** days with **different** books, so that the three derived figures
/// are distinguishable from one another and from the prototype's own
/// decoration:
///
/// | figure | the prototype's | here | why it matters |
/// | --- | --- | --- | --- |
/// | the hero number | `12` (`:589`, written at `:989`) | **41** | the prototype's is a literal written by JavaScript, and a suite that hard-codes `12` would pass against the fiction |
/// | ring 1 | `83%` (`:592`) | **50%** | two completed days of four |
/// | ring 2 | `86` (`:593`) | **25** | a bare count — and not the prototype's `86` |
/// | ring 3 | `92%` (`:594`) | **84%** | 21 correct of 25 answered |
/// | the lit stars | `0` (`:596`) | **17** | `SkyRepository.count()` |
/// | the constellations | `0` (`:596`) | **1** | the **distinct completed books** — two of the four days are John, and John counts once |
///
/// **Every one of them is different from the prototype's number**, on purpose:
/// a suite whose expectations are the prototype's literals cannot tell a
/// derived figure from a transcribed one.
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/journey/data/datasources/medal_local_data_source.dart';
import 'package:evangelion/features/journey/data/repositories/medal_repository_impl.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';
import 'package:evangelion/features/journey/domain/usecases/get_journey_reader_session.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_sky_count.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_history.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_summary.dart';
import 'package:evangelion/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../support/app_harness.dart';
import '../../support/design_system_harness.dart';

/// The reader the journey is about.
///
/// **Not "Mariam Hanna"** — that is the prototype's literal name
/// (`eva/redesign.html:587`, written again at `:992`), and a fixture that
/// repeated it would make a screen printing the prototype's fiction look
/// correct. "Ana Silva" is the same reader `/communion`'s suite uses, and the
/// monogram is **two** letters so that the orb's glyph cannot be mistaken for
/// the prototype's single `M` (`:586`).
final AuthSession journeySession = AuthSession(
  userId: '11111111-1111-1111-1111-111111111111',
  displayName: 'Ana Silva',
  email: 'ana@example.com',
  initials: 'AS',
  createdAt: DateTime.utc(2026, 10, 18),
);

/// The four scheduled days the rings and the constellations are derived from.
///
/// **The arithmetic, written out, so a reader can check the screen's numbers
/// against the history without running anything:**
///
/// * **four** days in the window, so the completion ratio's denominator is 4;
/// * **two** of them completed (`is_completed: true`), so the ratio is
///   2 ÷ 4 = **50%**;
/// * `answered_questions` sums to 10 + 10 + 3 + 2 = **25** — the bare count;
/// * `correct_questions` sums to 9 + 8 + 3 + 1 = **21**, so the accuracy is
///   21 ÷ 25 = **84%**;
/// * `total_questions` sums to 10 + 10 + 6 + 4 = 30, so the count ring's
///   **arc** — which is a share, because a count has no denominator of its own
///   — is 25 ÷ 30;
/// * the **completed** days are two John days, and the two incomplete ones are
///   Psalms and Proverbs, so the distinct completed books are **{43}** and the
///   constellation count is **1**.
///
/// The two completed days share a book on purpose: a fixture whose four days
/// are four different books would give a constellation count of 2 and would
/// not prove that the count is of **distinct** books.
const List<StreakHistoryEntry> journeyHistory = <StreakHistoryEntry>[
  StreakHistoryEntry(
    readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    scheduledDate: '2026-10-18',
    bookNumber: 43,
    bookNameEn: 'John',
    bookNameAr: 'يوحنا',
    referenceEn: 'John 3:1-5',
    referenceAr: 'يوحنا 3: 1-5',
    totalQuestions: 10,
    answeredQuestions: 10,
    correctAnswers: 9,
    pointsEarned: 100,
    isCompleted: true,
  ),
  StreakHistoryEntry(
    readingId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    scheduledDate: '2026-10-17',
    bookNumber: 43,
    bookNameEn: 'John',
    bookNameAr: 'يوحنا',
    referenceEn: 'John 2:1-11',
    referenceAr: 'يوحنا 2: 1-11',
    totalQuestions: 10,
    answeredQuestions: 10,
    correctAnswers: 8,
    pointsEarned: 80,
    isCompleted: true,
  ),
  StreakHistoryEntry(
    readingId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
    scheduledDate: '2026-10-16',
    bookNumber: 19,
    bookNameEn: 'Psalms',
    bookNameAr: 'المزمور',
    referenceEn: 'Psalms 23:1-6',
    referenceAr: 'المزمور 23: 1-6',
    totalQuestions: 6,
    answeredQuestions: 3,
    correctAnswers: 3,
    pointsEarned: 30,
    isCompleted: false,
  ),
  StreakHistoryEntry(
    readingId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
    scheduledDate: '2026-10-15',
    bookNumber: 23,
    bookNameEn: 'Proverbs',
    bookNameAr: 'أمثال',
    referenceEn: 'Proverbs 3:1-12',
    referenceAr: 'أمثال 3: 1-12',
    totalQuestions: 4,
    answeredQuestions: 2,
    correctAnswers: 1,
    pointsEarned: 10,
    isCompleted: false,
  ),
];

/// The streak summary — `current_streak: 41`.
///
/// **41, and not the prototype's `12`.** `eva/redesign.html:589` carries `12` in
/// the markup and `:989` writes it in JavaScript
/// (`el('heroNum').textContent = N(12)`), so the prototype's hero is a
/// literal. ADR-0022's fiction table marks the hero number **real** and names
/// its replacement: "`GET /streak/summary` → `current_streak`". A screen
/// suite that asserted `12` would be asserting the prototype's fiction.
const StreakSummary journeySummary = StreakSummary(
  currentStreak: 41,
  longestStreak: 44,
  lastCompletedDate: '2026-10-18',
  todayStatus: StreakTodayStatus.completed,
  todayCompleted: true,
  todayScheduled: true,
  nextMilestone: 50,
  daysToMilestone: 9,
);

/// How many stars are lit in the reader's sky.
///
/// **17, and not the prototype's `0`** (`:596` writes `0` into `jSkyN` and
/// `:1187` overwrites it with the prototype's own DOM count). Ours is
/// `SkyRepository.count()`, which is real.
const int journeyStarsLit = 17;

/// The failure the failed arm reports.
///
/// **The mapper's own wording shape** — a sentence about what could not be
/// reached — so the assertion below is about the screen carrying the failure
/// through and not about a particular fixture's prose.
const Failure journeyFailure = Failure(
  kind: FailureKind.network,
  message: 'Could not reach the server.',
);

/// The session port, with a counter.
///
/// **Hand-written rather than a `mocktail` mock**, for `home_harness.dart`'s
/// reason: a mock implements whatever it is told to, so it can satisfy the
/// port and answer nothing, and a suite that agreed with itself would prove
/// nothing. This one always answers, and records how many times it was asked.
final class JourneyAuthRepository implements AuthRepository {
  /// Answers [answer] to every read.
  JourneyAuthRepository({Result<AuthSession>? answer})
    : answer = answer ?? Result<AuthSession>.of(journeySession);

  /// What the next read answers with.
  Result<AuthSession> answer;

  /// How many times [getCurrentSession] has been called.
  int calls = 0;

  @override
  Future<Result<AuthSession>> getCurrentSession() async {
    calls++;
    return answer;
  }

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async => getCurrentSession();

  @override
  Future<Result<void>> signOut() async => const Right<Failure, void>(null);
}

/// The streak port, with a counter on each of its two methods.
///
/// **Two counters and not one**, because the port is two endpoints
/// (`GET /streak/summary` and `GET /streak`) and a single counter could not
/// say which of them the retry asked for again.
final class JourneyStreakRepository implements StreakRepository {
  /// Answers [summaryAnswer] and [historyAnswer].
  JourneyStreakRepository({
    Result<StreakSummary>? summaryAnswer,
    Result<List<StreakHistoryEntry>>? historyAnswer,
  }) : summaryAnswer =
           summaryAnswer ?? Result<StreakSummary>.of(journeySummary),
       historyAnswer =
           historyAnswer ?? Result<List<StreakHistoryEntry>>.of(journeyHistory);

  /// What [summary] answers with.
  Result<StreakSummary> summaryAnswer;

  /// What [history] answers with.
  Result<List<StreakHistoryEntry>> historyAnswer;

  /// How many times [summary] has been called.
  int summaryCalls = 0;

  /// How many times [history] has been called.
  int historyCalls = 0;

  /// Whether [summary] **never answers**.
  ///
  /// **The only way to hold the loading arm.** A repository that answers on the
  /// first microtask drain is past the loading arm by the time the first
  /// `pump()` returns, so the spinner would never be on screen to be asserted
  /// on. A `Completer` nobody completes is the fixture that holds it — the
  /// same shape `communion_page_test.dart`'s `_NeverRepo` has.
  bool holdSummary = false;

  @override
  Future<Result<StreakSummary>> summary() {
    summaryCalls++;
    if (holdSummary) {
      return Completer<Result<StreakSummary>>().future;
    }
    return Future<Result<StreakSummary>>.value(summaryAnswer);
  }

  @override
  Future<Result<List<StreakHistoryEntry>>> history() {
    historyCalls++;
    return Future<Result<List<StreakHistoryEntry>>>.value(historyAnswer);
  }
}

/// The sky port, with a counter on [count].
///
/// **Only [count] answers a number**, because only [count] is what `/journey`
/// asks for: the port's own doc names `journey` as the consumer of the count
/// and of nothing else. The other three methods answer so that the fake is a
/// **substitutable** `SkyRepository` — a port method a substitute cannot
/// answer is not substitutable, and it is a compile error in every caller.
final class JourneySkyRepository implements SkyRepository {
  /// Answers [answer] to every count.
  JourneySkyRepository({Result<int>? answer})
    : answer = answer ?? Result<int>.of(journeyStarsLit);

  /// What [count] answers with.
  Result<int> answer;

  /// How many times [count] has been called.
  int countCalls = 0;

  @override
  Future<Result<int>> count() async {
    countCalls++;
    return answer;
  }

  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) async =>
      Result<SkyEntry>.of(entry);

  @override
  Future<Result<List<SkyEntry>>> entries() async =>
      Result<List<SkyEntry>>.of(const <SkyEntry>[]);

  @override
  Future<Result<void>> clear() async => const Right<Failure, void>(null);
}

/// The medal port, with a counter, over the **shipped** adapter.
///
/// **The real fiction, and not a hand-written list.** The medals are ADR-0022's
/// invention and the stub data source is the one file that holds it, so a
/// screen suite that asserted four tiles against its own list would be
/// asserting its own list — the same argument `home_harness.dart` gives for the
/// library catalogue. The counter is the wrapper's, and the shelf is the
/// adapter's.
final class CountingMedalRepository implements MedalRepository {
  /// Wraps [inner], or the shipped adapter over the shipped data source.
  CountingMedalRepository([MedalRepository? inner])
    : _inner = inner ?? MedalRepositoryImpl(MedalLocalDataSource());

  final MedalRepository _inner;

  /// How many times [shelf] has been called.
  int calls = 0;

  @override
  Future<Result<MedalShelf>> shelf() {
    calls++;
    return _inner.shelf();
  }
}

/// The fixture `/journey`'s screen suite runs against.
final class JourneyHarness {
  /// The fixture, with its cubit and the fakes behind it.
  const JourneyHarness({
    required this.cubit,
    required this.auth,
    required this.streaks,
    required this.sky,
    required this.medals,
  });

  /// The cubit the page reads.
  final JourneyCubit cubit;

  /// The session the orb and the name line come from.
  final JourneyAuthRepository auth;

  /// The streak summary and the thirty-day history.
  final JourneyStreakRepository streaks;

  /// The lit-star count.
  final JourneySkyRepository sky;

  /// The medal shelf.
  final CountingMedalRepository medals;
}

/// Builds the fixture, and registers the teardown.
///
/// [summary], [history], [stars] and [session] are the arms the screen has: a
/// failure on any of them is a failure the screen must report, and `null`
/// means the live-shaped answer above.
///
/// [holdSummary] is the **loading** arm's lever: the summary never answers, so
/// the cubit is held with its reads open — and the spinner is on screen to be
/// asserted on.
JourneyHarness journeyHarness({
  Result<AuthSession>? session,
  Result<StreakSummary>? summary,
  Result<List<StreakHistoryEntry>>? history,
  Result<int>? stars,
  MedalRepository? medals,
  bool holdSummary = false,
}) {
  final JourneyAuthRepository auth = JourneyAuthRepository(answer: session);
  final JourneyStreakRepository streaks = JourneyStreakRepository(
    summaryAnswer: summary,
    historyAnswer: history,
  )..holdSummary = holdSummary;
  final JourneySkyRepository sky = JourneySkyRepository(answer: stars);
  final CountingMedalRepository shelf = CountingMedalRepository(medals);

  final JourneyCubit cubit = JourneyCubit(
    getReaderSession: GetJourneyReaderSession(auth),
    loadStreakSummary: LoadJourneyStreakSummary(streaks),
    loadStreakHistory: LoadJourneyStreakHistory(streaks),
    loadSkyCount: LoadJourneySkyCount(sky),
    medalRepository: shelf,
  );
  addTearDown(cubit.close);

  return JourneyHarness(
    cubit: cubit,
    auth: auth,
    streaks: streaks,
    sky: sky,
    medals: shelf,
  );
}

/// Registers [cubit] in the locator, so a **routed** page resolves it.
///
/// `/journey` is reached by path — the dock's journey slot and a deep link both
/// land on it — and a path carries no arguments. So the page falls back to
/// `getIt<JourneyCubit>()`, and the locator is where that has to be.
void registerJourneyCubit(JourneyCubit cubit) {
  getIt.registerSingleton<JourneyCubit>(cubit);
  addTearDown(() => getIt.unregister<JourneyCubit>());
}

/// Advances [tester] until the journey's reads have answered.
///
/// **Not `pumpAndSettle`.** The ambient clocks under `NeuralScaffold` never
/// settle, so settling is a timeout rather than a green tick — the reason
/// `app_harness.dart` records. A fixed number of frames is the honest
/// instrument: the cubit's five reads resolve over a handful of microtask
/// turns, and four frames is more than enough.
Future<void> settleJourney(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Mounts `/journey` on the **real** router, over [harness], and returns the
/// router.
///
/// ## WHY THE REAL ROUTER AND NOT A `MaterialApp`
///
/// The page navigates: the live account rows open the board and the workshop,
/// and the board is a **tab** of the dock shell, so that row's control is a
/// **tab switch** rather than a push. `evaPrimitiveHarness` has no `Router` in
/// it, so `context.router` inside those callbacks would throw on the tap — and
/// a suite that could not tap the controls it is about would be asserting about
/// a screen no reader ever reaches.
///
/// **And a mock router would prove nothing about the route names.** The
/// failure mode this arrangement exists to catch is a route *name* that nothing
/// answers: `pushPath` on an unknown path throws several frames later, in a
/// suite about something else. The real `AppRouter` answers `/journey` and
/// `/settings`, and the assertion is on the **stack** rather than on
/// `currentPath` — `home_navigation_test.dart` gives the measurement for why.
///
/// ## AND HOW THE JOURNEY **TAB** IS SELECTED
///
/// `/journey` is a **tab** of the dock shell — `DockTabs.journey` is the third
/// of the shell's three — so the reader is put **on that tab** rather than on a
/// pushed screen. The journey is no longer pushed over `/` and it has no back
/// chevron: the prototype's journey is a dock tab too, and its app bar carries
/// a 68px spacer where the chevron would be (`eva/redesign.html:578`).
///
/// **The stack is emptied first, and `/journey` is then the FIRST navigation
/// onto it.** That order is the only one that works, and the reason is
/// measured, not reasoned:
///
/// * `pushPath('/journey')` onto a stack that already holds the shell pushes a
///   **second shell** — the board and the journey are the shell's *children*,
///   so a path push builds a whole new shell — and that second shell's own
///   tabs router starts on the **home** tab, so the journey is never on
///   screen and the app carries two docks;
/// * `replacePath('/journey')` replaces the shell, and the replacement's tabs
///   router lands on the home tab as well;
/// * switching the tab on the existing shell does work, but it needs the tabs
///   router, and the tabs router is only reachable from **inside** the tree.
///
/// So the harness pops the shell and then pushes `/journey` onto the empty
/// stack: the shell is built **once**, with the journey as its initial child,
/// and the tabs router's pending-children mechanism selects the journey tab.
/// **This is the arrangement a deep link produces** — auto_route's delegate
/// answers a deep link with `navigatePath`, and a `/journey` deep link lands on
/// the journey tab of a single shell, measured the same way.
Future<AppRouter> pumpJourney(
  WidgetTester tester,
  JourneyHarness harness, {
  Locale locale = const Locale('en'),
  Size size = kAmbientSurface,
}) async {
  registerJourneyCubit(harness.cubit);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final AppRouter router = AppRouter(FakeAuthStatus(), _SilentAuthChanges());
  addTearDown(router.dispose);

  await tester.pumpWidget(routerHost(router, locale: locale));
  await pumpUntilFound(tester, find.byType(HomePage));

  // **The stack is emptied, and this is the step that makes the push below
  // mean what it says.** The router's initial deep link is
  // `Navigator.defaultRouteName` — `'/'` — so the stack holds the shell, and
  // the shell's home tab is on screen.
  router.pop();
  await pumpUntilGone(tester, find.byType(HomePage));

  // **Not awaited.** `pushPath` returns the pushed route's *result* — a future
  // that completes when the route is **popped** — so awaiting it here would
  // wait for the reader to leave the screen they are being taken to. The
  // navigation is complete when the page is in the tree, and that is what
  // [pumpUntilFound] waits for.
  unawaited(router.pushPath(AppRoutes.journey));
  await pumpUntilFound(tester, find.byType(JourneyPage));
  await settleJourney(tester);

  return router;
}

/// A [ReevaluateListenable] that never notifies.
///
/// `ReevaluateListenable` is abstract and `AppRouter` takes one positionally,
/// so a test needs a concrete instance. It is a second declaration of the
/// private `_SilentAuthChanges` in `app_router_test.dart` — **deliberately so**,
/// for the reason that file gives: promoting it into the shared harness would
/// mean editing a Phase 2 suite's construction of the very router it exists to
/// keep honest.
final class _SilentAuthChanges extends ReevaluateListenable {}
