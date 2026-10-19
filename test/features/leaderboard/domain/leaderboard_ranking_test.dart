import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/domain/leaderboard_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

/// A row with only the fields the ranking arithmetic reads made explicit.
LeaderboardRow row({
  required int rank,
  required int score,
  required int streak,
  String name = 'Reader',
}) => LeaderboardRow(
  rank: rank,
  score: score,
  initials: 'R',
  userId: 'u$rank',
  fullName: name,
  currentStreak: streak,
);

/// Five rows whose score order and streak order deliberately disagree.
///
/// The server order is rank 1…5 by score. The streak values make the streak order
/// 3, 5, 1, 4, 2 — so a sort that accidentally kept server order, or sorted by rank,
/// cannot pass.
final List<LeaderboardRow> five = <LeaderboardRow>[
  row(rank: 1, score: 100, streak: 30, name: 'Peter George'),
  row(rank: 2, score: 80, streak: 10, name: 'David Mina'),
  row(rank: 3, score: 60, streak: 70, name: 'Mark Anton'),
  row(rank: 4, score: 40, streak: 20, name: 'John Samir'),
  row(rank: 5, score: 20, streak: 40, name: 'Ana Silva'),
];

void main() {
  group('the metric value', () {
    test('light is the row score', () {
      expect(leaderboardValueOf(five[0], LeaderboardMetric.light), 100);
    });

    test('streaks is the row currentStreak', () {
      expect(leaderboardValueOf(five[0], LeaderboardMetric.streaks), 30);
    });
  });

  group('the display order', () {
    test('under light it is the server order, untouched', () {
      expect(
        leaderboardOrder(
          five,
          LeaderboardMetric.light,
        ).map((LeaderboardRow r) => r.rank).toList(),
        <int>[1, 2, 3, 4, 5],
      );
    });

    test('under streaks it is currentStreak descending', () {
      expect(
        leaderboardOrder(
          five,
          LeaderboardMetric.streaks,
        ).map((LeaderboardRow r) => r.rank).toList(),
        <int>[3, 5, 1, 4, 2],
      );
    });

    test('under streaks, ties break by the original server rank ascending', () {
      final List<LeaderboardRow> tied = <LeaderboardRow>[
        row(rank: 2, score: 90, streak: 12),
        row(rank: 1, score: 100, streak: 12),
        row(rank: 4, score: 40, streak: 12),
        row(rank: 3, score: 50, streak: 12),
      ];
      expect(
        leaderboardOrder(
          tied,
          LeaderboardMetric.streaks,
        ).map((LeaderboardRow r) => r.rank).toList(),
        <int>[1, 2, 3, 4],
      );
    });

    test('does not mutate the list it was handed', () {
      final List<LeaderboardRow> original = List<LeaderboardRow>.of(five);
      leaderboardOrder(five, LeaderboardMetric.streaks);
      expect(five, original);
    });

    test('an empty board is an empty order', () {
      expect(
        leaderboardOrder(const <LeaderboardRow>[], LeaderboardMetric.streaks),
        isEmpty,
      );
    });
  });

  group('the display position', () {
    test('is the index in the order plus one, not the server rank', () {
      final List<LeaderboardRow> ordered = leaderboardOrder(
        five,
        LeaderboardMetric.streaks,
      );
      // Mark Anton is server rank 3 and leads the streak board.
      expect(leaderboardPositionOf(ordered, five[2]), 1);
      // David Mina is server rank 2 and is last by streak.
      expect(leaderboardPositionOf(ordered, five[1]), 5);
    });

    test('is zero for a row that is not in the order', () {
      expect(
        leaderboardPositionOf(
          leaderboardOrder(five, LeaderboardMetric.light),
          row(rank: 9, score: 1, streak: 1),
        ),
        0,
      );
    });
  });

  group('the reader row', () {
    test('is found by the standing rank, not by display position', () {
      expect(
        leaderboardReaderRow(five, standingRank: 3)?.fullName,
        'Mark Anton',
      );
    });

    test('is null when the reader has no standing', () {
      expect(leaderboardReaderRow(five, standingRank: null), isNull);
    });

    test('is null when the rank is not in the payload', () {
      expect(leaderboardReaderRow(five, standingRank: 12), isNull);
    });
  });

  group('the gap line', () {
    test('names the witness one display position above under light', () {
      final List<LeaderboardRow> ordered = leaderboardOrder(
        five,
        LeaderboardMetric.light,
      );
      final LeaderboardGap? gap = leaderboardGapFor(
        ordered: ordered,
        readerPosition: 2,
        metric: LeaderboardMetric.light,
      );
      expect(gap, isNotNull);
      expect(gap!.aboveName, 'Peter George');
      expect(gap.abovePosition, 1);
      expect(gap.gap, 20);
      // 20 / 15 = 1.33 → 2 verses, and never zero.
      expect(gap.verses, 2);
    });

    test('rounds the verse hint up and floors it at one', () {
      final List<LeaderboardRow> ordered = leaderboardOrder(
        five,
        LeaderboardMetric.light,
      );
      final LeaderboardGap? gap = leaderboardGapFor(
        ordered: ordered,
        readerPosition: 2,
        metric: LeaderboardMetric.light,
      );
      // 100 - 80 = 20; ceil(20 / 15) = 2. The floor is exercised by a 1-point gap.
      final List<LeaderboardRow> close = <LeaderboardRow>[
        row(rank: 1, score: 81, streak: 1),
        row(rank: 2, score: 80, streak: 1),
      ];
      final LeaderboardGap? tight = leaderboardGapFor(
        ordered: close,
        readerPosition: 2,
        metric: LeaderboardMetric.light,
      );
      expect(gap!.verses, 2);
      expect(tight!.verses, 1);
    });

    test('under streaks it carries the gap and NO verse hint', () {
      final List<LeaderboardRow> ordered = leaderboardOrder(
        five,
        LeaderboardMetric.streaks,
      );
      // Mark Anton leads with 70; Ana Silva is second with 40 → gap 30.
      final LeaderboardGap? gap = leaderboardGapFor(
        ordered: ordered,
        readerPosition: 2,
        metric: LeaderboardMetric.streaks,
      );
      expect(gap, isNotNull);
      expect(gap!.aboveName, 'Mark Anton');
      expect(gap.gap, 30);
      expect(
        gap.verses,
        isNull,
        reason: 'the ÷15 constant is the light economy, not a streak economy',
      );
    });

    test('at display position one there is no line', () {
      expect(
        leaderboardGapFor(
          ordered: leaderboardOrder(five, LeaderboardMetric.light),
          readerPosition: 1,
          metric: LeaderboardMetric.light,
        ),
        isNull,
      );
    });

    test('a position outside the order never invents a witness', () {
      expect(
        leaderboardGapFor(
          ordered: leaderboardOrder(five, LeaderboardMetric.light),
          readerPosition: 6,
          metric: LeaderboardMetric.light,
        ),
        isNull,
      );
    });
  });

  group('the reset countdown', () {
    test('weekly is the next local Monday at midnight', () {
      // Wednesday 21 October 2026, noon → Monday 26 October, 4d 12h.
      final Duration? left = resetLeftFor(
        LeaderboardWindow.weekly,
        DateTime(2026, 10, 21, 12),
      );
      expect(left, const Duration(days: 4, hours: 12));
    });

    test('weekly on a Monday is SEVEN days, not zero', () {
      // The prototype's `((7-day)%7)||7` (`redesign.html:1073`): a board reset at
      // 00:00 today is already the new week, so the next one is a week away.
      final Duration? left = resetLeftFor(
        LeaderboardWindow.weekly,
        DateTime(2026, 10, 19, 9, 15),
      );
      expect(left, const Duration(days: 6, hours: 14, minutes: 45));
    });

    test('weekly crosses a month boundary', () {
      // Sunday 1 November 2026 → Monday 2 November.
      final Duration? left = resetLeftFor(
        LeaderboardWindow.weekly,
        DateTime(2026, 11, 1, 6),
      );
      expect(left, const Duration(hours: 18));
    });

    test('monthly is the first of next month at midnight', () {
      final Duration? left = resetLeftFor(
        LeaderboardWindow.monthly,
        DateTime(2026, 9, 30, 18),
      );
      expect(left, const Duration(hours: 6));
    });

    test('monthly rolls the year in December', () {
      final Duration? left = resetLeftFor(
        LeaderboardWindow.monthly,
        DateTime(2026, 12, 31, 23),
      );
      expect(left, const Duration(hours: 1));
    });

    test('all_time has no reset at all', () {
      expect(
        resetLeftFor(LeaderboardWindow.allTime, DateTime(2026, 10, 19)),
        isNull,
      );
    });
  });
}
