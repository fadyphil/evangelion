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
/// hazard — the reader goes off to the board, the server's answer changes
/// while they are away, and the journey comes back showing the numbers it
/// had.
///
/// **The trigger is the RETURN, and not the request.** A screen that is
/// covered is not stale in any way a reader can see; it is stale the moment it
/// is uncovered again. So the assertion below is a pair: nothing is re-read
/// while the journey is covered, and everything is re-read when it comes back.
///
/// ## AND THE ANSWER IS **CHANGED WHILE THE JOURNEY IS COVERED**
///
/// Which is the only way the re-read can be told apart from a re-read that
/// happened to be scheduled at the same moment: the fake is re-stubbed in the
/// gap, so the screen can only show the new number if it asked again.
library;

import 'dart:async';

import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import 'journey_harness.dart';

/// The journey's own subtree.
///
/// **Scoped on purpose.** The page is pushed over `/`, and the home screen
/// underneath is still in the tree with its own figures.
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

    // The reader goes to the board.
    unawaited(router.pushPath(AppRoutes.communion));
    await pumpUntilFound(tester, find.byType(CommunionPage));
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

    // And back again.
    router.pop();
    await pumpUntilGone(tester, find.byType(CommunionPage));
    await settleJourney(tester);

    // **Every read, and not only the one that changed.** A re-read that
    // refreshed three of the four would leave the reader with a screen that is
    // partly new and partly stale — the argument `JourneyCubit.retry`'s doc
    // gives.
    expect(
      harness.streaks.summaryCalls,
      2,
      reason: 'the journey re-reads when the reader comes back to it',
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

    unawaited(router.pushPath(AppRoutes.communion));
    await pumpUntilFound(tester, find.byType(CommunionPage));
    await settleJourney(tester);

    router.pop();
    await pumpUntilGone(tester, find.byType(CommunionPage));
    await settleJourney(tester);

    // **One journey on the stack, and it is this one.**
    expect(find.byType(JourneyPage), findsOneWidget);
    expect(router.stack.last.name, 'JourneyRoute');
    expect(
      harness.streaks.summaryCalls,
      2,
      reason: 'and the re-read went to the cubit this page holds',
    );
  });
}
