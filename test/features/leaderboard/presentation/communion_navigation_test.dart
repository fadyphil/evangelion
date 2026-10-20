/// The board's **chevron** — where it goes now that the board is a tab.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A GROUP IN `communion_page_test.dart`
///
/// Because the chevron's behaviour is a **navigation event**: it moves the
/// dock shell's tab. `communion_page_test.dart` mounts `CommunionPage` over a
/// bare `MaterialApp` — `evaPrimitiveHarness` has no `Router` in it, so there
/// is no tabs router for the control to move, and a suite that could not move
/// it would be certifying a callback that fires and nothing else.
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
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` names, reached the same way `app_router.dart` reaches
// them: through the generated library.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
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
}

/// Mounts the **real** router on the dock shell, and returns it.
///
/// The shell is the app's own route at `/`, and its three tabs are its
/// children — so the tabs router is the only thing that can move between
/// them, and this is the only way to have one.
Future<AppRouter> mountShell(WidgetTester tester) async {
  // **The journey's cubit, before the shell is mounted.** The journey is one
  // of the shell's three tabs, so a suite that visits it needs the journey's
  // own fixture in the locator — the same arrangement
  // `home_navigation_test.dart` uses for the same reason.
  final JourneyHarness journey = journeyHarness();
  registerJourneyCubit(journey.cubit);

  final AppRouter router = AppRouter(FakeAuthStatus(), _SilentAuthChanges());
  addTearDown(router.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(routerHost(router));
  await pumpUntilFound(tester, find.byType(HomePage));

  return router;
}

/// A [ReevaluateListenable] that never notifies.
///
/// The same declaration `app_router_test.dart` and `journey_harness.dart`
/// both make, and for the same reason: `AppRouter` takes one positionally, and
/// promoting it into the shared harness would mean editing suites that own
/// the construction of the very router it exists to keep honest.
final class _SilentAuthChanges extends ReevaluateListenable {}
