/// The journey's **re-entry** — what happens when the reader comes back to
/// `/journey` from a screen that was pushed over it.
///
/// ## WHY THIS FILE IS ITS OWN, AND NOT A GROUP IN `journey_page_test.dart`
///
/// Because a re-entry **is a navigation event**: it needs a real router, a
/// real push and a real pop, and the file that owns the page's own behaviour
/// is being written by another agent in this same task. This file is the
/// home for the one claim that needs a push and a pop and nothing else.
///
/// ## AND WHAT THE CLAIM IS
///
/// `/` re-reads on re-entry for the reason `home_page.dart` states: "the
/// reader finishes a reflection on `/quiz`, comes back, and the chip and the
/// cards still show first-landing values." The journey has the same shape of
/// hazard — the reader goes off to the workshop, the server's answer changes
/// while they are away, and the journey comes back showing the numbers it
/// had.
///
/// **The trigger is the RETURN, and not the request.** A screen that is
/// covered is not stale in any way a reader can see; it is stale the moment it
/// is uncovered again. So the assertion below is a pair: nothing is re-read
/// while the journey is covered, and everything is re-read when it comes back.
///
/// ## AND THE DESTINATION IS THE **WORKSHOP**, NOT THE BOARD
///
/// The board used to be the screen that covered the journey, and it is a
/// **tab** now — a sibling of the journey inside the same `IndexedStack`, so
/// moving to it covers nothing and produces no return to wait for. **The
/// workshop is a root route pushed OVER the shell**, so it covers the journey
/// and the dock with it, and popping it uncovers the shell again.
///
/// **And the trigger is the SHELL's route data, not the journey's own.** A tab
/// is never popped, so the journey tab's own route data would never produce a
/// `didPopNext`; the shell's does, because the shell is the route underneath
/// the pushed screen. `journey_page.dart`'s `_watchedRouteData` says so.
///
/// ## AND THE ANSWER IS **CHANGED WHILE THE JOURNEY IS COVERED**
///
/// Which is the only way the re-read can be told apart from a re-read that
/// happened to be scheduled at the same moment: the fake is re-stubbed in the
/// gap, so the screen can only show the new number if it asked again.
///
/// ## AND THE RE-READ IS **NOT** HAPPENING — AND THE REASON IS IN `lib/`
///
/// **The two tests in this file are RED, and they are red on purpose.** The
/// journey's own trigger is right — it subscribes under the **shell's** route
/// data, and the shell is what the observer hands `didPopNext` to when the
/// screen pushed over it is popped — but the **observer it subscribes to is
/// not the observer on the navigator**.
///
/// `AppRouter.config()`'s `navigatorObservers` builder is
/// `() => [...?navigatorObservers?.call(), AutoRouteObserver()]`, and it is
/// called **twice**: once by `AutoRouterDelegate` for the root navigator, and
/// once by the dock shell's `AutoTabsRouter` for the list it **inherits**. Each
/// call builds a **new** `AutoRouteObserver`, so the root navigator watches
/// one instance and the shell's children watch another — and a page inside the
/// shell subscribes to the shell's.
///
/// **How to see it, in five lines.** Read the two `RouterScope`s out of the
/// tree and compare their observers:
///
/// ```dart
/// final List<RouterScope> scopes =
///     tester.widgetList<RouterScope>(find.byType(RouterScope)).toList();
/// final AutoRouteObserver? root = scopes.first.firstObserverOfType<AutoRouteObserver>();
/// final AutoRouteObserver? shell = scopes[1].firstObserverOfType<AutoRouteObserver>();
/// expect(identical(root, shell), isTrue); // ← false today
/// ```
///
/// **And the shape of the fix, measured.** Installing **one** shared observer
/// into the router's own `navigatorObservers` — so the same instance is in the
/// root navigator's list and in the list the shell inherits — makes the
/// re-read happen on the next pop, with no change to the journey.
///
/// **The fix is in `lib/app/router/app_router.dart` and not here.** The
/// observer has to be one instance shared by the navigator and the children it
/// hands one to, and that is the composition root's file.
///
/// **AND `/` HAS THE SAME DEFECT.** `home_page.dart` subscribes under the
/// shell's route data in the same way, so the home screen's own re-read —
/// recorded decision 41, and the reason `home_navigation_test.dart` has a
/// whole group for it — is inert for the same reason.
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` names, reached the same way `app_router.dart` reaches
// them: through the generated library.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import 'journey_harness.dart';

/// The journey's own subtree.
///
/// **Scoped on purpose.** The journey is a tab of the dock shell, and the
/// shell's chrome stands beside it — the dock's five labels, among them a
/// "Journey" of their own. An unscoped finder would be about the screen and
/// the shell at once.
Finder _onJourney(Finder matching) =>
    find.descendant(of: find.byType(JourneyPage), matching: matching);

void main() {
  testWidgets('a push/pop re-reads, and the screen shows the NEW answer', (
    WidgetTester tester,
  ) async {
    final JourneyHarness harness = journeyHarness();
    final AppRouter router = await pumpJourney(tester, harness);

    // **The first landing.** Every read is asked once, and the hero number is
    // the fixture's 41.
    expect(harness.streaks.summaryCalls, 1);
    expect(harness.streaks.historyCalls, 1);
    expect(harness.sky.countCalls, 1);
    expect(_onJourney(find.text('41')), findsOneWidget);

    // The reader goes off to the workshop — the one destination that **covers**
    // the journey, because it is pushed over the shell.
    unawaited(router.pushPath(AppRoutes.settings));
    await pumpUntilFound(tester, find.byType(SettingsPage));
    await settleJourney(tester);

    // **Covered, and nothing was re-read.** The request is not the trigger; the
    // *return* is.
    expect(
      harness.streaks.summaryCalls,
      1,
      reason:
          'a covered screen is not stale to a reader — it is stale when it '
          'is uncovered again, and asking while covered would be a request '
          'nobody is waiting for',
    );
    expect(harness.streaks.historyCalls, 1);
    expect(harness.sky.countCalls, 1);

    // **What happened while the reader was away.** The streak moved, and the
    // fake is re-stubbed **while the journey is covered** — which is the whole
    // point. The journey can only show 7 if it asked again on the way back.
    harness.streaks.summaryAnswer = Result<StreakSummary>.of(
      const StreakSummary(
        currentStreak: 7,
        longestStreak: 44,
        lastCompletedDate: '2026-10-18',
        todayStatus: StreakTodayStatus.completed,
        todayCompleted: true,
        todayScheduled: true,
        nextMilestone: 50,
        daysToMilestone: 43,
      ),
    );

    // And back again. The pop uncovers the **shell**, and the shell's
    // subscribers — the journey among them — are told so.
    router.pop();
    await pumpUntilGone(tester, find.byType(SettingsPage));
    await settleJourney(tester);

    // **Every read, and not only the one that changed.** A re-read that
    // refreshed three of the four would leave the reader with a screen that is
    // partly new and partly stale — the argument `JourneyCubit.retry`'s doc
    // gives.
    expect(
      harness.streaks.summaryCalls,
      2,
      reason:
          'the journey re-reads when the reader comes back to it — and it does '
          'NOT, because the observer the shell\'s children inherit is a second '
          'instance of the one the navigator watches. See the file doc.',
    );
    expect(harness.streaks.historyCalls, 2);
    expect(harness.sky.countCalls, 2);
    expect(harness.medals.calls, 2);

    // **And the screen shows the NEW answer**, which is the only way the
    // re-read can be told apart from a re-read that happened to be scheduled
    // at the same moment.
    expect(
      _onJourney(find.text('7')),
      findsOneWidget,
      reason: 'the hero number is the number the reader came back to check',
    );
    expect(
      _onJourney(find.text('41')),
      findsNothing,
      reason: 'and 41 is what it said when they left',
    );
  });

  testWidgets('and the re-read is the journey\'s own, not a second journey', (
    WidgetTester tester,
  ) async {
    // The cubit is a **singleton** (`navigation_injection.dart`), so a second
    // page would be a second reader — and the re-read must be the same
    // cubit's, or the screen would show the figures of a journey that is not
    // on the stack.
    final JourneyHarness harness = journeyHarness();
    final AppRouter router = await pumpJourney(tester, harness);

    unawaited(router.pushPath(AppRoutes.settings));
    await pumpUntilFound(tester, find.byType(SettingsPage));
    await settleJourney(tester);

    router.pop();
    await pumpUntilGone(tester, find.byType(SettingsPage));
    await settleJourney(tester);

    // **One journey on the stack, and it is this one.** The journey is a **tab**
    // of the shell, so the root stack carries the shell — and the journey's
    // page is the shell's third tab, not a route of its own.
    expect(find.byType(JourneyPage), findsOneWidget);
    expect(
      router.stack.map((AutoRoutePage<Object?> page) => page.name),
      <String>[DockShellRoute.name],
    );
    expect(
      harness.streaks.summaryCalls,
      2,
      reason:
          'and the re-read went to the cubit this page holds — and it does NOT, '
          'for the reason the file doc gives',
    );
  });
}
