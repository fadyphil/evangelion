/// The board's **chevron** — where it goes now that the board is a tab — and
/// the board's **clearance under the dock**, which is the other thing a tab
/// has to get right.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A GROUP IN `communion_page_test.dart`
///
/// Because the chevron's behaviour is a **navigation event**: it moves the
/// dock shell's tab. `communion_page_test.dart` mounts `CommunionPage` over a
/// bare `MaterialApp` — `evaPrimitiveHarness` has no `Router` in it, so there
/// is no tabs router for the control to move, and a suite that could not move
/// it would be certifying a callback that fires and nothing else.
///
/// **And the same is true of the clearance.** The board is a **tab** of the
/// dock shell, so the 78px dock is painted **over** the board's bottom edge —
/// and a board mounted on its own has no dock over it, so a suite that
/// mounted the page alone would measure a screen no reader ever sees. The
/// clearance is therefore measured **on the real router**, with the real dock
/// really there.
///
/// ## AND WHAT THE BEHAVIOUR IS NOW
///
/// The board is the dock shell's **second tab**, so there is nothing to pop:
/// the board's own route is never popped, and the root stack holds only the
/// shell. What the chevron means is **"the tab I was on before this one"** —
/// `TabsRouter.previousIndex` — and **home is the floor**, because the
/// previous index is `null` before the first tab change.
///
/// The prototype does the same thing with two branches
/// (`eva/redesign.html:1282`): `boardEntry==='push' ? pop('journey') :
/// tab('home')` — pushed from the journey it returns to the journey; reached
/// from the dock, it returns home. **The client's previous-tab rule is the
/// one-branch form of that**, because the reader's previous tab *is* the
/// journey when they came from the journey.
///
/// ## AND THE ASSERTION IS THE **TAB**, NOT THE CALLBACK
///
/// A control that called a callback would pass a test that only watched the
/// callback. The claim here is about where the reader ends up, so the claim is
/// read off the tabs router's **active index** — and the root stack is
/// asserted too, because a chevron that pushed a second shell would leave the
/// index right and the app with two docks.
library;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` names, reached the same way `app_router.dart` reaches
// them: through the generated library.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/leaderboard/data/datasources/cheer_local_data_source.dart';
import 'package:evangelion/features/leaderboard/data/repositories/local_cheer_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../support/app_harness.dart';
import '../../../support/design_system_harness.dart';
import '../../journey/journey_harness.dart';

/// The dock shell's tabs router, read from the tree.
///
/// **The index, and not the presence of a page.** The tabs router keeps every
/// tab's page in the tree — the inactive ones inside the `IndexedStack`'s
/// offstage children — so "the board is on screen" is not "a `CommunionPage`
/// exists": the home page is still there after the reader moves to the board.
/// The index is the only thing that says which screen is in front.
///
/// **`skipOffstage: false`, and it is load-bearing.** An inactive tab's page
/// is offstage, and `find.byType` skips offstage widgets by default — so the
/// default finder would find **nothing** exactly when the reader has left the
/// home tab, and the helper would throw on the very tab switch it exists to
/// measure.
///
/// The scope is read from the **home** page, because the home tab is the one
/// this suite knows is built from the first frame, and it stays in the tree
/// after the reader leaves it.
TabsRouter _tabs(WidgetTester tester) => TabsRouterScope.of(
  tester.element(find.byType(HomePage, skipOffstage: false)),
)!.controller;

/// The board's back chevron.
Finder _chevron() => find.descendant(
  of: find.byType(CommunionAppBar),
  matching: find.byIcon(Icons.arrow_back_ios_new),
);

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the board\'s chevron', () {
    testWidgets('returns to the PREVIOUS tab, and pops nothing', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await mountShell(tester);

      // **The reader comes from the journey.** The journey is a tab of the
      // shell, so it needs its cubit in the locator — and the journey's own
      // harness is the fixture that provides one.
      _tabs(tester).setActiveIndex(DockTabs.journey);
      await pumpUntilFound(tester, find.byType(JourneyPage));

      // And then to the board — the way the journey's own trophy and its
      // account row get there.
      _tabs(tester).setActiveIndex(DockTabs.communion);
      await pumpUntilFound(tester, find.byType(CommunionPage));

      expect(_tabs(tester).activeIndex, DockTabs.communion);
      expect(
        _tabs(tester).previousIndex,
        DockTabs.journey,
        reason: 'the reader came from the journey, so the previous tab is it',
      );
      // **The board is the tab in front**, so its app bar — and the chevron on
      // it — are on screen and not offstage.
      expect(find.byType(CommunionPage), findsOneWidget);
      expect(find.byType(CommunionAppBar), findsOneWidget);

      // **The chevron.**
      await tester.tap(_chevron());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ## THE TAB ACTUALLY CHANGED
      //
      // **The index, and not "a callback fired".** A control that called
      // `_goBack` and did nothing else would leave the reader on the board,
      // and only the index says they are not.
      expect(
        _tabs(tester).activeIndex,
        DockTabs.journey,
        reason:
            'the board is a tab, so its chevron goes back to the tab the reader '
            'came from — and the reader came from the journey',
      );

      // ## AND NOTHING WAS PUSHED OR POPPED
      //
      // The old behaviour was a pop, and the board was a pushed screen. The
      // board is a **tab** now, so there is nothing to pop: the root stack
      // still holds the one shell, and the app has one dock.
      expect(
        router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name],
        reason:
            'a tab switch moves the tabs router, not the root stack — a second '
            'shell here would be a second dock',
      );
      // **And the board is still there, offstage** — a tab is not a push, so
      // nothing was torn down to get here.
      expect(find.byType(CommunionPage, skipOffstage: false), findsOneWidget);
    });

    testWidgets('and from the home tab it returns home', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await mountShell(tester);

      // **Reached from the dock's board slot**, which is the prototype's other
      // branch: `boardEntry==='push' ? pop('journey') : tab('home')`
      // (`eva/redesign.html:1282`).
      _tabs(tester).setActiveIndex(DockTabs.communion);
      await pumpUntilFound(tester, find.byType(CommunionPage));

      expect(_tabs(tester).previousIndex, DockTabs.home);

      await tester.tap(_chevron());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        _tabs(tester).activeIndex,
        DockTabs.home,
        reason: 'the previous tab was home, so the previous tab is home',
      );
      expect(
        router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name],
      );
    });
  });

  group('the board as a TAB, and the dock over its bottom', () {
    testWidgets('the LAST witness is not behind the dock', (
      WidgetTester tester,
    ) async {
      // **The real router, and the real dock.** A board mounted on its own has
      // no dock over it, so a suite that mounted the page alone would be
      // measuring a screen no reader ever sees.
      await mountShell(tester, size: kNarrowSurface, board: _twelveWitnesses);

      // **On the board tab**, the way the dock's own board slot reaches it.
      _tabs(tester).setActiveIndex(DockTabs.communion);
      await pumpUntilFound(tester, find.byType(CommunionPage));
      await pumpUntilFound(tester, find.text(_lastWitnessName));
      await _settlePastTheEntrances(tester);

      // **Scrolled to the end**, which is where the last witness lives.
      await _scrollTheBoardToItsEnd(tester);

      // ## THE TWO BOXES, READ BACK
      //
      // **The row's own box**, and not the text inside it: the claim is about
      // the row, and a name is a few pixels narrower than the band it sits in.
      final Rect row = _lastWitnessRect(tester);
      final Rect dock = tester.getRect(find.byType(LumenDock));

      // **And the two numbers are printed**, so the failure says where they
      // were rather than only that one of them was wrong.
      debugPrint('COMMUNION last witness $row — dock $dock');

      expect(
        row.bottom,
        lessThanOrEqualTo(dock.top),
        reason:
            'the last witness is painted at $row and the dock covers '
            '${dock.top}–${dock.bottom}. A row whose bottom is under the '
            'dock\'s top edge is a row the reader cannot read and cannot '
            'cheer.',
      );
    });
  });
}

/// Mounts the **real** router on the dock shell, and returns it.
///
/// The shell is the app's own route at `/`, and its three tabs are its
/// children — so the tabs router is the only thing that can move between
/// them, and this is the only way to have one.
///
/// [size] is the surface, and [board] is the cohort the board tab shows. The
/// board is **registered before the shell is mounted**, because `routerHost`
/// registers the *empty* board's cubit only when there is none — and the
/// empty board is exactly what a clearance measurement must not be made on.
Future<AppRouter> mountShell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  LeaderboardBoard? board,
}) async {
  // **The journey's cubit, before the shell is mounted.** The journey is one
  // of the shell's three tabs, so a suite that visits it needs the journey's
  // own fixture in the locator — the same arrangement
  // `home_navigation_test.dart` uses for the same reason.
  final JourneyHarness journey = journeyHarness();
  registerJourneyCubit(journey.cubit);

  // **And the board's**, for the same reason and one step earlier: the board
  // is the shell's second tab, so the shell builds it.
  if (board != null) {
    _registerBoardCubit(board);
  }

  final AppRouter router = AppRouter(
    FakeAuthStatus(),
    _SilentAuthChanges(),
    testRoleAccess(),
  );
  addTearDown(router.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(routerHost(router));
  await pumpUntilFound(tester, find.byType(HomePage));

  return router;
}

/// The name of the **last** witness on the board — the one the dock covered.
const String _lastWitnessName = 'Ziad Habib';

/// A cohort of **twelve**, so the board has to scroll.
///
/// **Twelve, and the number is load-bearing.** The podium takes the first
/// three and the list is `sorted.slice(3)` (`eva/redesign.html:1110`), so nine
/// rows have to scroll on a 320×568 screen — and the **last** of them is the
/// row the dock used to paint over. A five-row board fits the viewport, and
/// nothing on it can be pushed under anything.
const List<String> _cohort = <String>[
  'Peter George',
  'David Mina',
  'Mariam Anton',
  'Ana Silva',
  'Karim Nabil',
  'Tarek Fares',
  'Hala Saeed',
  'Nabil Adly',
  'Yara Emad',
  'Fady Shady',
  'Widad Fares',
  'Ziad Habib',
];

/// The board those twelve make.
///
/// The reader is **Ana Silva at rank 4** — in the list rather than on the
/// podium, so the list's reader treatment and the ordinary row treatment are
/// both on screen at once.
final LeaderboardBoard _twelveWitnesses = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    for (final (int index, String name) in _cohort.indexed)
      LeaderboardRow(
        rank: index + 1,
        score: 1300 - index * 100,
        currentStreak: 12 - index,
        initials: '${name[0]}${name.split(' ').last[0]}',
        userId: 'u${index + 1}',
        fullName: name,
      ),
  ],
  standing: const LeaderboardStanding(rank: 4, score: 1000),
  cohortSize: 12,
);

/// A repository that answers with a fixed board.
final class _FixedBoardRepository implements LeaderboardRepository {
  const _FixedBoardRepository(this.answer);

  /// The board every request answers with.
  final LeaderboardBoard answer;

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async => Result<LeaderboardBoard>.of(answer);
}

/// The reader's session, for the you-card's fallback arm.
///
/// **The real port shape** — a hand-written implementation of a port this
/// repository does not own would compile against a stale signature and pass
/// for a reason the screen never had.
final class _StubAuthRepo implements AuthRepository {
  const _StubAuthRepo();

  @override
  Future<Result<AuthSession>> getCurrentSession() async =>
      Result<AuthSession>.of(
        AuthSession(
          userId: 'u4',
          displayName: 'Ana Silva',
          email: 'ana@example.com',
          initials: 'AS',
          createdAt: DateTime.utc(2026),
        ),
      );

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async => getCurrentSession();

  @override
  Future<Result<void>> signOut() async => const Right<Failure, void>(null);
}

/// Registers the [LeaderboardCubit] `/communion` resolves, over [board].
///
/// **Before the shell is mounted**, because `routerHost` registers the empty
/// board's cubit only when there is none — and the empty board is exactly what
/// this suite must not measure.
void _registerBoardCubit(LeaderboardBoard board) {
  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: LoadLeaderboard(_FixedBoardRepository(board)),
    getReaderSession: const GetBoardReaderSession(_StubAuthRepo()),
    cheerRepository: LocalCheerRepository(CheerLocalDataSource()),
  );
  getIt.registerSingleton<LeaderboardCubit>(cubit);
  addTearDown(() => getIt.unregister<LeaderboardCubit>());
  addTearDown(cubit.close);
}

/// Advances [tester] past the board's entrance animations.
///
/// **A fixed number of frames and not `pumpAndSettle`** — the shared clocks
/// under `NeuralScaffold` never settle. The last row's own entrance is the
/// one that matters: its delay is `80 + 8·45` = 440ms and its transition is
/// 300ms, so it is still moving at 740ms — and it **translates** the row by
/// 10px while it does, which a `getRect` would read as a row that is ten
/// pixels higher than it is.
Future<void> _settlePastTheEntrances(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump();
}

/// Scrolls the board's own column to its end.
///
/// **The scroll view's own extent, and not a drag.** The scaffold's scroll
/// view uses `BouncingScrollPhysics` (the prototype's `overflowY: 'auto'`),
/// and a drag long enough to reach the end of the content **overshoots** it —
/// the list springs past its own end and the row under test ends up hundreds
/// of pixels above the viewport.
Future<void> _scrollTheBoardToItsEnd(WidgetTester tester) async {
  final Finder scrollables = find.descendant(
    of: find.byType(CommunionPage),
    matching: find.byType(Scrollable),
  );
  expect(
    scrollables,
    findsOneWidget,
    reason: 'the board has one scrollable — its own column',
  );
  final ScrollableState scrollable = tester.state<ScrollableState>(scrollables);
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

/// The **last** witness's own box, as the reader sees it.
Rect _lastWitnessRect(WidgetTester tester) {
  final Finder row = find.ancestor(
    of: find.text(_lastWitnessName),
    matching: find.byType(LeaderboardRowTile),
  );
  expect(row, findsOneWidget, reason: 'the last witness is on the board');
  // **The row's own box, and not the text inside it.** The tile's outermost
  // `Container` is the row's own box — the tile's other `Container` is the
  // monogram orb — and the claim is about the row, not about a name that sits
  // a few pixels inside it.
  final Container box = tester
      .widgetList<Container>(
        find.descendant(of: row, matching: find.byType(Container)),
      )
      .first;
  return tester.getRect(find.byWidget(box));
}

/// A [ReevaluateListenable] that never notifies.
///
/// The same declaration `app_router_test.dart` and `journey_harness.dart`
/// both make, and for the same reason: `AppRouter` takes one positionally, and
/// promoting it into the shared harness would mean editing suites that own
/// the construction of the very router it exists to keep honest.
final class _SilentAuthChanges extends ReevaluateListenable {}
