import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter_test/flutter_test.dart';

/// RED-FIRST — `ProgressBeads`' three bead states, extracted from the widget.
///
/// `eva/src/components/ds.tsx:350-370` computes each bead from three integers in
/// a closure, with no name for the outcome. Collapsing it into a widget without
/// naming the outcome leaves the arithmetic untestable, so it is named here.
void main() {
  group('beadStateAt', () {
    test('a bead before `completed` is done', () {
      expect(
        beadStateAt(index: 0, total: 5, completed: 3, current: 3),
        ProgressBeadState.done,
      );
      expect(
        beadStateAt(index: 2, total: 5, completed: 3, current: 3),
        ProgressBeadState.done,
      );
    });

    test('the bead at `current` is current, unless it is already done', () {
      // `ds.tsx:358` — `const curr = i === current && !done`. The `&& !done`
      // is load-bearing: with `completed: 2, current: 1` the prototype shows
      // bead 1 as *done*, because a finished bead never un-finishes.
      expect(
        beadStateAt(index: 3, total: 5, completed: 1, current: 3),
        ProgressBeadState.current,
      );
      expect(
        beadStateAt(index: 1, total: 5, completed: 2, current: 1),
        ProgressBeadState.done,
      );
    });

    test('every other bead is upcoming', () {
      expect(
        beadStateAt(index: 4, total: 5, completed: 1, current: 3),
        ProgressBeadState.upcoming,
      );
      expect(
        beadStateAt(index: 0, total: 5, completed: 0, current: 0),
        ProgressBeadState.current,
      );
      expect(
        beadStateAt(index: 1, total: 5, completed: 0, current: 0),
        ProgressBeadState.upcoming,
      );
    });

    test('is a total-length row of states, whatever the numbers say', () {
      // The widget renders `total` beads and needs a state for each, so an
      // out-of-range index has to resolve to something renderable rather than
      // throw in a build method. `upcoming` is the honest answer: a bead that
      // does not exist yet has not been reached.
      expect(
        beadStateAt(index: 9, total: 3, completed: 3, current: 3),
        ProgressBeadState.upcoming,
      );
    });

    test('clamps a `completed` beyond `total` rather than shading beads that '
        'do not exist', () {
      // The prototype would happily return `done` for every index, which for
      // `total: 0` is the empty row and for `total: 3, completed: 9` is a row
      // where the `i < completed` test is true for indices the loop never runs.
      final List<ProgressBeadState> row = beadStates(
        total: 3,
        completed: 9,
        current: 9,
      );
      expect(row, hasLength(3));
      expect(row, everyElement(ProgressBeadState.done));
    });

    test('clamps a negative `completed`', () {
      expect(
        beadStates(total: 3, completed: -4, current: -1),
        <ProgressBeadState>[
          ProgressBeadState.upcoming,
          ProgressBeadState.upcoming,
          ProgressBeadState.upcoming,
        ],
      );
    });

    test('a `total` of zero is the empty row, not a crash', () {
      // `QuizHeader` renders before the payload arrives, so `total: 0` is a real
      // state and a single `done` bead would be a lie about progress.
      expect(beadStates(total: 0, completed: 0, current: 0), isEmpty);
      expect(
        beadStateAt(index: 0, total: 0, completed: 0, current: 0),
        ProgressBeadState.upcoming,
      );
    });

    test('a negative `total` is clamped to zero', () {
      expect(beadStates(total: -2, completed: 1, current: 0), isEmpty);
    });

    test('completed beads are exactly the first `completed` of the row', () {
      final List<ProgressBeadState> row = beadStates(
        total: 5,
        completed: 2,
        current: 3,
      );
      final List<int> done = <int>[
        for (int i = 0; i < row.length; i++)
          if (row[i] == ProgressBeadState.done) i,
      ];
      expect(done, <int>[0, 1]);
    });

    test('at most one bead is `current`', () {
      for (int total = 0; total <= 6; total++) {
        for (int completed = -1; completed <= total + 1; completed++) {
          for (int current = -1; current <= total + 1; current++) {
            final List<ProgressBeadState> row = beadStates(
              total: total,
              completed: completed,
              current: current,
            );
            expect(
              row
                  .where(
                    (ProgressBeadState s) => s == ProgressBeadState.current,
                  )
                  .length,
              lessThanOrEqualTo(1),
              reason: 'total=$total completed=$completed current=$current',
            );
          }
        }
      }
    });

    test('`done` always wins over `current` at the same index', () {
      // The prototype's `i === current && !done` (`ds.tsx:358`) means a bead is
      // never both, and the enum makes that a compile-time-shaped statement
      // rather than a boolean nobody reads.
      for (int total = 0; total <= 5; total++) {
        for (int completed = 0; completed <= total; completed++) {
          for (int current = 0; current < total; current++) {
            expect(
              beadStateAt(
                index: current,
                total: total,
                completed: completed,
                current: current,
              ),
              current < completed
                  ? ProgressBeadState.done
                  : ProgressBeadState.current,
              reason: 'total=$total completed=$completed current=$current',
            );
          }
        }
      }
    });
  });

  group('the enum', () {
    test('has exactly the three prototype bead looks', () {
      expect(ProgressBeadState.values, <ProgressBeadState>[
        ProgressBeadState.done,
        ProgressBeadState.current,
        ProgressBeadState.upcoming,
      ]);
    });
  });
}
