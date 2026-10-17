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
    // ## `gap: 6` IS THE SPACE **BETWEEN** BEADS
    //
    // `redesign.html:328` is `gap: 6px`, and a CSS `gap` is the space between
    // adjacent items — never after the last one. The widget padded **every** bead
    // when it was written against `ds.tsx:355`'s `gap: 8`, so a row measured
    // `10n + 8n` where the prototype's arithmetic was `10n + 8(n − 1)`:
    // `total: 1` rendered 18 against 10, `total: 3` rendered 54 against 46,
    // `total: 5` rendered 90 against 82. Eight pixels of dead space at the end of
    // the row, invisible left-aligned and visible the moment the row is centred
    // or sits in a `space-between` `Row` — which is exactly where it is going,
    // in a quiz header between a title and a counter.
    //
    // ## AND THE ARITHMETIC IS NO LONGER A FORMULA, BECAUSE THE PILL IS 26
    //
    // `redesign.html:330` gives `.dot.cur` `width: 26px`, so a row's width is no
    // longer `size × n` and there is nothing to write out by hand. It is
    // [progressBeadsWidth] — one function, in the widget, under test — and this
    // group measures the **rendered** row against it rather than against a second
    // copy of the formula. A second copy is the thing this test file spent its
    // whole life guarding against.
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
      );
      await tester.pump();
      return tester.getSize(find.byType(ProgressBeads)).width;
    }

    testWidgets('renders the row `progressBeadsWidth` says it should', (
      WidgetTester tester,
    ) async {
      // One current pill and `n − 1` short dots, with `n − 1` gaps.
      for (final int total in <int>[1, 2, 3, 5, 8]) {
        final List<ProgressBeadState> states = beadStates(
          total: total,
          completed: 0,
          current: 0,
        );
        expect(
          await rowWidth(tester, total: total, current: 0),
          progressBeadsWidth(states),
          reason:
              'total: $total — one 26px pill, ${total - 1} dots of '
              '${kProgressBeadSize}px and ${total - 1} gaps of '
              '${kProgressBeadGap}px. A trailing gap after the last bead is '
              '${kProgressBeadGap}px the prototype never draws.',
        );
      }
      expect(kProgressBeadSize, 8.0, reason: 'redesign.html:329 — 8×8');
      expect(kProgressBeadGap, 6.0, reason: 'redesign.html:328 — `gap: 6px`');
      expect(
        kProgressBeadCurrentWidth,
        26.0,
        reason: 'redesign.html:330 — `.dot.cur{width: 26px}`',
      );
    });

    test('the width table in `ProgressBeads`\'s doc is the function\'s own', () {
      // The loop above compares the rendered row against [progressBeadsWidth], so
      // a wrong constant moves both sides together and the **doc's table** is
      // never checked. Its `n = 8` row was `138 | 134 | −4` — two literals and a
      // delta that neither formula produces; the true row is `136 | 124 | −12`.
      //
      // `n = 8` is the row that matters: it is the only length at which the row
      // gets **narrower** than `ds.tsx`'s, because `4n − 4` finally overtakes
      // the flat 18 the 26px pill pushes out. So it is asserted against both
      // columns and against the delta the doc claims.
      const Map<int, (double old, double now)> expected =
          <int, (double, double)>{
            1: (10, 26),
            2: (28, 40),
            3: (46, 54),
            5: (82, 82),
            8: (136, 124),
          };
      for (final MapEntry<int, (double, double)> row in expected.entries) {
        final List<ProgressBeadState> states = beadStates(
          total: row.key,
          completed: 0,
          current: 0,
        );
        expect(
          progressBeadsWidth(states),
          row.value.$2,
          reason: "total: ${row.key} — the doc's `redesign.html` column",
        );
        // `ds.tsx`'s column, `10n + 8(n − 1)`, spelled out here so the delta is
        // a measured difference rather than a number copied twice.
        final double old = 10 * row.key + 8 * (row.key - 1);
        expect(
          old,
          row.value.$1,
          reason: "total: ${row.key} — `ds.tsx`'s column",
        );
        expect(
          row.value.$2 - row.value.$1,
          progressBeadsWidth(states) - old,
          reason: 'total: ${row.key} — the delta column is the difference',
        );
      }
    });

    testWidgets('a row with no current bead is `n` dots and `n − 1` gaps', (
      WidgetTester tester,
    ) async {
      // `current: -1` — the fixture's own default, and the state a quiz is in
      // **before** its payload lands. It is the case where the row's width is
      // exactly the CSS gap rule with nothing else in it, so it is the
      // arithmetic this file was written for, restated against the redesign's
      // two numbers. The argument is omitted because it *is* the default —
      // spelling it out would be `avoid_redundant_argument_values`.
      expect(
        await rowWidth(tester, total: 1),
        kProgressBeadSize,
        reason: 'there is nothing for a gap to sit between',
      );
      for (final int total in <int>[2, 3, 5]) {
        expect(
          await rowWidth(tester, total: total),
          kProgressBeadSize * total + kProgressBeadGap * (total - 1),
          reason:
              'total: $total, no pill — so the old formula, with new numbers',
        );
      }
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
