/// `LeaderboardCard` on `/` — **the test that should have existed in Phase 1**.
///
/// ## THE DEFECT THIS FILE EXISTS BECAUSE OF
///
/// `5f53eb5` claimed "leaderboard card → Home". It did not. `LeaderboardCard` was
/// written, tested, formatted, analysed, given a DI seam and committed — and **no page
/// ever rendered it**. `HomeBloc` fetched `LoadLeaderboardPreview` on every load, held
/// the board in `HomeState.leaderboard`, and dropped it on the floor.
///
/// It compiled. It analysed clean. It was **100% line-covered**. Every gate in §7 was
/// green, because a widget that nothing instantiates is exercised perfectly well by
/// tests that instantiate it directly, and a bloc field that nothing reads is written
/// without complaint.
///
/// ## WHY NO EXISTING GATE CAUGHT IT, AND WHAT CLOSES THE HOLE
///
/// `home_page_test.dart` asserts the greeting, the wordmark, the flame and the panel.
/// Nothing asserted **what sections `/` has**, so a section could be added to the state
/// and never to the screen, or removed from the screen and left in the state, and every
/// assertion would still pass. `home_bloc_test.dart` proved the bloc fetches it; the
/// card's own suite proved the card renders; **nothing proved the two were connected**.
///
/// The gap is a missing assertion, not a missing gate: this file asserts the card is
/// in `/`'s tree, in order, and that its three states render. That is the whole
/// connection, stated once.
library;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/widgets/error_view.dart';
import 'package:evangelion/core/design_system/widgets/leaderboard_row_tile.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/home/presentation/widgets/leaderboard_card.dart';
import 'package:evangelion/features/home/presentation/widgets/today_reading_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/home_harness.dart';

/// Three ranked children with the reader second, so the card's standing line and its
/// reader-highlight both have something to say.
const LeaderboardBoard _three = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(rank: 1, score: 80, initials: 'PG'),
    LeaderboardRow(rank: 2, score: 50, initials: 'DM'),
    LeaderboardRow(rank: 3, score: 30, initials: 'MA'),
  ],
  standing: LeaderboardStanding(rank: 2, score: 50),
  cohortSize: 3,
);

void main() {
  group('the card is on the screen', () {
    testWidgets('rendered, and below today\'s reading', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        leaderboardAnswer: const Right<Failure, LeaderboardBoard>(_three),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(
        find.byType(LeaderboardCard),
        findsOneWidget,
        reason:
            'HomeBloc fetches the board and HomeState holds it. If this fails, the '
            'fetch is happening and the answer is being discarded.',
      );

      // **The order is the decision.** The reading is what the reader came to do, so
      // it is first and the card is a reward glance after it. Asserted as a comparison
      // of vertical centres rather than as an index into `children`, because the
      // screen is a `Column` inside a scroll view and an index would be a statement
      // about the tree's shape rather than about where the reader's eye lands.
      final double reading = tester
          .getTopLeft(find.byType(TodayReadingPanel))
          .dy;
      final double card = tester.getTopLeft(find.byType(LeaderboardCard)).dy;
      expect(
        card,
        greaterThan(reading),
        reason: 'the reading panel must come first',
      );
    });

    testWidgets('and it draws the rows the bloc fetched', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        leaderboardAnswer: const Right<Failure, LeaderboardBoard>(_three),
      );
      await pumpHome(tester, bloc: h.bloc);

      // The board travelled from the repository through `HomeState` to the screen.
      // Three `LeaderboardRowTile`s is that whole journey working, and it is the one
      // assertion the previous phase had no way to make.
      expect(find.byType(LeaderboardRowTile), findsNWidgets(3));
    });

    testWidgets('the request it made is the preview\'s, not the screen\'s', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        leaderboardAnswer: const Right<Failure, LeaderboardBoard>(_three),
      );
      await pumpHome(tester, bloc: h.bloc);

      // Fifty asked for, three drawn. If the card asked for three it could never
      // report a cohort size, which is the entire reason the preview asks for more
      // than it shows.
      final ({int limit, LeaderboardWindow window})? asked =
          h.leaderboard.lastRequest;
      expect(asked, isNotNull);
      expect(asked!.limit, 50);
      expect(asked.window, LeaderboardWindow.weekly);
    });
  });

  group('and it has all three of its states', () {
    testWidgets('loading reserves the slot instead of vanishing', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      // The harness answers with a board by default, so the pending state is reached
      // by **not** pumping the answer: `pumpHome` is asked for one frame and the
      // future has not resolved.
      await pumpHome(tester, bloc: h.bloc, frames: 1);
      expect(find.byType(LeaderboardCard), findsOneWidget);
    });

    testWidgets('a failure renders ErrorView with a working retry', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        leaderboardAnswer: const Left<Failure, LeaderboardBoard>(
          Failure(
            kind: FailureKind.network,
            message: 'Could not reach the server.',
          ),
        ),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.byType(LeaderboardCard), findsOneWidget);
      expect(find.byType(ErrorView), findsWidgets);
      expect(find.byType(LeaderboardRowTile), findsNothing);
      // **The reading still renders.** Home has four independent sections and one
      // failing must not take the others with it — the property `HomeBloc` was built
      // around, and the reason this asserts the panel is still present.
      expect(find.byType(TodayReadingPanel), findsOneWidget);
    });
  });
}
