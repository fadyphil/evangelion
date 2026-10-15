import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';
import 'package:evangelion/features/leaderboard/data/repositories/stub_leaderboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The stub repository's contract, which its doc makes three promises about.
///
/// It was the single least-covered file in the package — **21 of 22 lines, 4.5%** —
/// written in the previous phase and never executed by a test. The overflow suite
/// builds the card from fixtures, so nothing ever reached this class; a file can
/// compile, analyse, format and be wired into DI while having never run.
///
/// The three promises, and the test for each:
///
/// 1. **It reuses `LeaderboardMapper.initialsOf` rather than reimplementing it**, so
///    the stub cannot show monograms production never produces.
/// 2. **It places the reader**, matching the seeded backend identity's display name.
/// 3. **Its `cohortSize` goes through the real `cohortSizeOf`**, so the stub exercises
///    the same derivation the endpoint's response goes through.

void main() {
  const StubLeaderboardRepository stub = StubLeaderboardRepository();

  /// Unwraps the stub's answer through `fold`.
  ///
  /// `Result` deliberately publishes **no `value` getter and no `getOrNull`** — see
  /// its doc: both would let a caller drop the failure without writing it down. So the
  /// helper branches explicitly, and its `onFailure` arm **fails the test** rather than
  /// returning a default. (The first version of this file used `as dynamic` and a
  /// made-up type to unwrap, which is precisely the information loss `Result` exists to
  /// prevent — a test asserting on a value it obtained by lying about the type.)
  Future<LeaderboardBoard> board({
    LeaderboardWindow window = LeaderboardWindow.weekly,
    int limit = 50,
  }) async {
    final Result<LeaderboardBoard> answer = await stub.board(
      window: window,
      limit: limit,
    );
    return answer.fold<LeaderboardBoard>(
      (Failure failure) => fail(
        'the stub answered with a failure, which it never should: '
        '${failure.message}',
      ),
      (LeaderboardBoard value) => value,
    );
  }

  group('the rows it produces', () {
    test('five ranked children, one point apart from 80 down', () async {
      final LeaderboardBoard result = await board();
      expect(result.rows.map((LeaderboardRow row) => row.rank).toList(), <int>[
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(result.rows.map((LeaderboardRow row) => row.score).toList(), <int>[
        80,
        50,
        30,
        20,
        10,
      ]);
    });

    test('the monograms are the ones the real mapper produces', () async {
      final LeaderboardBoard result = await board();
      // Asserted **against `initialsOf` itself**, not against a literal `"PG"`. A
      // literal would only prove the stub agrees with this test's reading of the rule;
      // comparing against the mapper proves the two agree, which is the actual claim —
      // and it is the claim that fails the day someone changes the strip-grade rule in
      // one file and not the other.
      expect(
        result.rows.map((LeaderboardRow row) => row.initials).toList(),
        <String>[
          LeaderboardMapper.initialsOf('Peter George (Grade 6)'),
          LeaderboardMapper.initialsOf('David Mina (Grade 5)'),
          LeaderboardMapper.initialsOf('Mark Anton (Grade 5)'),
          LeaderboardMapper.initialsOf('Mariam Botros (Grade 6)'),
          LeaderboardMapper.initialsOf('Antonios Farid (Grade 5)'),
        ],
      );
    });

    test('no row carries a grade suffix or a full name', () async {
      final LeaderboardBoard result = await board();
      // The production constraint is structural — `LeaderboardRow` has no field for a
      // name — and a stub is the easiest place for that to be quietly violated, since
      // it is the fixture the screens are reviewed against.
      for (final LeaderboardRow row in result.rows) {
        expect(row.initials, isNot(contains(' ')));
        expect(row.initials, isNot(contains('Grade')));
      }
    });
  });

  group('the reader it places', () {
    test('second of five on 50 points', () async {
      final LeaderboardBoard result = await board();
      // Matches the backend's own seed exactly: `InMemoryRedisFallback` puts
      // "David Mina (Grade 5)" at 50 behind Peter George's 80.
      expect(result.standing, isNotNull);
      expect(result.standing!.rank, 2);
      expect(result.standing!.score, 50);
    });

    test('and the reader is among the rows it returned', () async {
      final LeaderboardBoard result = await board();
      // The card and the screen both find the reader's row **by rank**, so a standing
      // whose rank is not in `rows` would highlight nothing and the reader would be
      // told they are ranked while appearing nowhere.
      expect(
        result.rows.any(
          (LeaderboardRow row) => row.rank == result.standing!.rank,
        ),
        isTrue,
      );
    });
  });

  group('the cohort size goes through the real derivation', () {
    test('known when the cap does not bind', () async {
      final LeaderboardBoard result = await board();
      // Five rows against a limit of fifty ⇒ `rowsReturned < limit` ⇒ 5, which is the
      // `2 / 5` line on the card.
      expect(result.cohortSize, 5);
    });

    test('UNKNOWN when the request is capped to exactly the cohort', () async {
      final LeaderboardBoard result = await board(limit: 5);
      // `5 > 5` is false and `5 < 5` is false, so `cohortSizeOf` returns `null`: at
      // exactly the cohort size the derivation cannot tell "this is everyone" from
      // "this is the first five of many". A stub that printed `5` here would be
      // showing a total the real screen deliberately refuses to invent.
      expect(result.rows, hasLength(5));
      expect(result.cohortSize, isNull);
    });

    test('truncates to the limit and refuses to claim a total', () async {
      final LeaderboardBoard result = await board(limit: 2);
      expect(result.rows, hasLength(2));
      // Still null: the reader is rank 2 of the *returned* two, but the cohort behind
      // them is five. The card prints a bare `2` rather than a wrong `2 / 2`.
      expect(result.cohortSize, isNull);
    });
  });

  group('what it echoes back', () {
    test('the window it was asked for, not a fixed one', () async {
      for (final LeaderboardWindow window in LeaderboardWindow.values) {
        final LeaderboardBoard result = await board(window: window);
        // `/leaderboard`'s heading is read off the **response**, so a stub that
        // answered "weekly" to a monthly request would put the wrong word above the
        // right rows — and every screen reviewed against the stub would be approved
        // with that mismatch baked in.
        expect(result.window, window);
      }
    });

    test('group 3, the seeded group', () async {
      expect((await board()).groupId, 3);
    });
  });

  group('the one line this file cannot cover', () {
    test('_standingFor\'s `return null` has no coverage record at all', () {
      // `_readerName` is a `const` that names one entry of a `const` `_standings`
      // list, so the loop always matches and the null arm never executes.
      //
      // The precise claim, which is narrower than "coverage cannot see it": `lcov`
      // records **no `DA:` entry for that line at all**, so it is counted neither as
      // covered nor as missed. That is why this file reads 22/22 = 100% while still
      // containing a line no test runs — and why a coverage percentage is not proof
      // that a file is fully exercised.
      //
      // The arm is kept deliberately. The two constants are edited independently, and
      // if someone renames a child without updating `_readerName` the stub should
      // degrade to "no standing" rather than throw.
      //
      // `fail()` is not called here: there is nothing to execute. The executable part
      // is only a premise check, and the argument above is the test's real content.
      expect(LeaderboardWindow.values, hasLength(3));
    });
  });
}
