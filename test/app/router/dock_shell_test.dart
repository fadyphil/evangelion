import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/router/dock_shell_page.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/journey/journey_harness.dart';
import '../../support/app_harness.dart';

/// The dock shell — `lib/app/router/dock_shell_page.dart`.
///
/// ## WHY THIS FILE EXISTS AND WHAT IT IS NOT
///
/// The shell is **the phase's headline deliverable** and it is the one piece of
/// Phase 6 with no screen of its own to hang a test on: the dock is a widget,
/// the tab switch is a mechanism, and the routes are a table. Each of those
/// has its own test, and **none of them proves that the three of them are
/// wired to each other**.
///
/// So this file mounts the **real** router — the same `routerHost` the rest of
/// the router suite uses — and drives the dock the way a reader would: by
/// tapping a slot.
///
/// **It is not a test of the dock's own geometry.** `lumen_dock_test.dart` owns
/// that, against the prototype's CSS. This file is about **the wiring**: that
/// the shell hosts the three tabs, that a slot switches the right one, that a
/// push-action slot pushes a **root** route over the shell, and that the dock
/// is therefore covered.
void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  AppRouter routerFor() {
    final AppRouter router = AppRouter(
      FakeAuthStatus(),
      ManualAuthChanges(),
      testRoleAccess(),
    );
    addTearDown(router.dispose);
    return router;
  }

  testWidgets('the shell opens on the home tab, with the dock under it', (
    WidgetTester tester,
  ) async {
    final AppRouter router = routerFor();

    await tester.pumpWidget(routerHost(router));
    await pumpUntilFound(tester, find.byType(LumenDock));

    // The five slots, in the prototype's order (`eva/redesign.html:702-708`).
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Communion'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);

    // And the home tab is the one showing.
    expect(find.byType(DockShellPage), findsOneWidget);
  });

  testWidgets('the board slot switches to the communion TAB, and does not '
      'push a second shell', (WidgetTester tester) async {
    final AppRouter router = routerFor();

    await tester.pumpWidget(routerHost(router));
    await pumpUntilFound(tester, find.byType(LumenDock));

    await tester.tap(find.text('Communion'));
    await pumpUntilFound(tester, find.byType(CommunionPage));

    expect(find.byType(CommunionPage), findsOneWidget);
    // **One shell, not two.** A path push would have put a second dock shell
    // on the root stack, because the board is the shell's *child* and the path
    // matches the shell as well as the child.
    expect(find.byType(DockShellPage), findsOneWidget);
    expect(router.stack.length, 1);
  });

  testWidgets('the journey slot switches to the journey tab', (
    WidgetTester tester,
  ) async {
    // The journey page reads its cubit from the locator, and `routerHost` does
    // not register one — the journey's own harness does, and the journey's own
    // suite owns the cubit's behaviour.
    registerJourneyCubit(journeyHarness().cubit);
    final AppRouter router = routerFor();

    await tester.pumpWidget(routerHost(router));
    await pumpUntilFound(tester, find.byType(LumenDock));

    await tester.tap(find.text('Journey'));
    await pumpUntilFound(tester, find.byType(JourneyPage));

    expect(find.byType(DockShellPage), findsOneWidget);
    expect(router.stack.length, 1);
  });

  testWidgets('the read slot PUSHES the reader over the shell, which is what '
      'covers the dock', (WidgetTester tester) async {
    final AppRouter router = routerFor();

    await tester.pumpWidget(routerHost(router));
    await pumpUntilFound(tester, find.byType(LumenDock));

    await tester.tap(find.text('Read'));
    await pumpUntilFound(tester, find.byType(ReadingPage));

    expect(find.byType(ReadingPage), findsOneWidget);
    // The reader is a **root** route pushed over the shell, so the stack has
    // grown — and the shell, with the dock inside it, is underneath.
    expect(router.stack.length, 2);
    expect(router.currentPath, AppRoutes.reading);
  });

  testWidgets('the today slot pushes the quiz over the shell', (
    WidgetTester tester,
  ) async {
    final AppRouter router = routerFor();

    await tester.pumpWidget(routerHost(router));
    await pumpUntilFound(tester, find.byType(LumenDock));

    await tester.tap(find.text('Today'));
    await pumpUntilFound(tester, find.byType(QuizPage));

    expect(router.currentPath, AppRoutes.quiz);
    expect(router.stack.length, 2);
  });

  testWidgets('the dock reports the slot it was given, and the active one is '
      'the home slot', (WidgetTester tester) async {
    final AppRouter router = routerFor();

    await tester.pumpWidget(routerHost(router));
    await pumpUntilFound(tester, find.byType(LumenDock));

    final LumenDock dock = tester.widget<LumenDock>(find.byType(LumenDock));

    expect(dock.items, hasLength(5));
    expect(dock.activeIndex, 0, reason: 'the home tab is the first tab');
    // **And the mapping is the shell's, not an identity**: the board is tab 1
    // and slot 3, because the dock's five slots are not five tabs.
    expect(DockTabs.communion, 1);
    expect(DockTabs.journey, 2);
    expect(DockTabs.count, 3);
  });
}
