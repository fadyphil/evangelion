import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

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

  group('the row', () {
    // ## `gap: 8` IS THE SPACE **BETWEEN** BEADS
    //
    // `ds.tsx:355` is a CSS `gap`, and a CSS gap is the space between adjacent
    // items — never after the last one. The widget padded **every** bead, so a row
    // measured `10n + 8n` where the prototype's arithmetic is `10n + 8(n − 1)`:
    // `total: 1` rendered 18 against 10, `total: 3` rendered 54 against 46,
    // `total: 5` rendered 90 against 82. Eight pixels of dead space at the end of
    // the row, invisible left-aligned and visible the moment the row is centred or
    // sits in a `space-between` `Row` — which is exactly where it is going, in a
    // quiz header between a title and a counter.
    Future<double> rowWidth(
      WidgetTester tester, {
      required int total,
      int completed = 0,
      int current = -1,
    }) async {
      await pumpPrimitive(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: ProgressBeads(
            total: total,
            completed: completed,
            current: current,
          ),
        ),
        size: kNarrowSurface,
      );
      await tester.pump();
      return tester.getSize(find.byType(ProgressBeads)).width;
    }

    /// The prototype's own arithmetic, written out rather than re-derived from the
    /// widget: `n` beads of [kProgressBeadSize] with `n − 1` gaps between them.
    double prototypeWidth(int total) =>
        kProgressBeadSize * total + kProgressBeadGap * (total - 1);

    testWidgets('renders `total` beads and `total - 1` gaps', (
      WidgetTester tester,
    ) async {
      for (final int total in <int>[1, 2, 3, 5, 8]) {
        expect(
          await rowWidth(tester, total: total),
          prototypeWidth(total),
          reason:
              'total: $total — ${kProgressBeadSize * total}px of beads plus '
              '${kProgressBeadGap * (total - 1)}px of gaps. A trailing gap after '
              'the last bead is ${kProgressBeadGap}px the prototype never draws.',
        );
      }
      expect(kProgressBeadSize, 10.0, reason: 'ds.tsx:361 — `width: 10`');
      expect(kProgressBeadGap, 8.0, reason: 'ds.tsx:355 — `gap: 8`');
    });

    testWidgets('a single bead is 10px wide, not 18', (
      WidgetTester tester,
    ) async {
      // The case that makes the arithmetic unarguable: at `total: 1` the old
      // padding was half the row's width.
      expect(
        await rowWidth(tester, total: 1),
        kProgressBeadSize,
        reason: 'there is nothing for a gap to sit between',
      );
    });

    testWidgets(
      'the label counts the beads that exist, not the caller\'s number',
      (WidgetTester tester) async {
        // L4. `beadStates` clamps `completed` into `0…total` before it shades, and
        // the label did not — so `completed: 99, total: 5` announced "Progress: 99 of
        // 5 complete" beside a row of five finished beads. On a progress row that is
        // the one number a reader is most likely to read back, so a screen reader
        // contradicting the picture directly in front of it is worse than a slightly
        // conservative count.
        await pumpPrimitive(
          tester,
          const Align(
            alignment: Alignment.topCenter,
            child: ProgressBeads(total: 5, completed: 99, current: 1),
          ),
          size: kNarrowSurface,
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Progress: 5 of 5 complete'),
          findsOneWidget,
        );

        // And the negative control, so the clamp is not "always say total".
        await pumpPrimitive(
          tester,
          const Align(
            alignment: Alignment.topCenter,
            child: ProgressBeads(total: 5, completed: 2, current: 2),
          ),
          size: kNarrowSurface,
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Progress: 2 of 5 complete'),
          findsOneWidget,
        );
        await pumpPrimitive(
          tester,
          const Align(
            alignment: Alignment.topCenter,
            child: ProgressBeads(total: 5, completed: -4, current: -1),
          ),
          size: kNarrowSurface,
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Progress: 0 of 5 complete'),
          findsOneWidget,
        );
      },
    );
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
