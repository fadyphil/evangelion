import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// RED-FIRST — `FontSizeStepper`'s clamping, and `SegmentedControl`'s selection
/// model. Both are calculations the prototype never had to express: the
/// prototype's font size is an uncontrolled `<input type="range" min=1 max=5>`
/// (`SettingsScreen.tsx:66`) and its theme picker is three buttons whose state
/// lives in a `useState` the browser clamps for free.
///
/// Phase 3's gate — "`SegmentedControl` selects via keyboard" — needs a keyboard
/// model to be a model, so it is written down first and tested.
void main() {
  group('clampFontStep', () {
    test('the prototype range is 1…5', () {
      expect(kFontStepMin, 1);
      expect(kFontStepMax, 5);
    });

    test('passes an in-range step through untouched', () {
      for (int step = 1; step <= 5; step++) {
        expect(clampFontStep(step), step);
      }
    });

    test('clamps below the minimum', () {
      expect(clampFontStep(0), 1);
      expect(clampFontStep(-1), 1);
      expect(clampFontStep(-9999), 1);
    });

    test('clamps above the maximum', () {
      expect(clampFontStep(6), 5);
      expect(clampFontStep(9999), 5);
    });

    test(
      'every int resolves to the five steps, so no value escapes the table',
      () {
        // `evaScalerFor` sends every out-of-range step to 1.22×. A persisted
        // preference of 0 or 99 must therefore land on a step the *stepper* can
        // also show, or the slider and the text would disagree about where the
        // knob is.
        final Set<int> reached = <int>{
          for (int step = -10; step <= 15; step++) clampFontStep(step),
        };
        expect(reached, <int>{1, 2, 3, 4, 5});
      },
    );
  });

  group('fontStepFromScaler — the inverse of evaScalerFor', () {
    test('agrees with evaScalerFor on every step', () {
      for (int step = kFontStepMin; step <= kFontStepMax; step++) {
        expect(fontStepFromScaler(evaScalerFor(step)), step);
      }
    });

    test('reads a linear scaler by its scale factor at 1.0', () {
      // `TextScaler.linear(x).scale(1.0) == x` is the identity the mapping
      // relies on; if the SDK ever made it non-linear, this fails rather than
      // returning a plausible wrong step.
      expect(fontStepFromScaler(const TextScaler.linear(0.90)), 1);
      expect(fontStepFromScaler(const TextScaler.linear(1.22)), 5);
    });

    test('an unrecognised scale reads as the largest step, never as zero', () {
      // Same reasoning as `evaScalerFor`'s `_` arm: a corrupted preference reads
      // as "largest" rather than silently resetting the reader's chosen size.
      expect(fontStepFromScaler(const TextScaler.linear(1.5)), 5);
      expect(fontStepFromScaler(TextScaler.noScaling), 3);
    });
  });

  group('nextSelection', () {
    const List<String> three = <String>['Light', 'Dark', 'System'];

    test('moves forward one step and wraps', () {
      expect(nextSelection(values: three, selected: 'Dark', step: 1), 'System');
      expect(
        nextSelection(values: three, selected: 'System', step: 1),
        'Light',
      );
    });

    test('moves back one step and wraps', () {
      expect(nextSelection(values: three, selected: 'Dark', step: -1), 'Light');
      expect(
        nextSelection(values: three, selected: 'Light', step: -1),
        'System',
      );
    });

    test('is a no-op on a single value', () {
      expect(
        nextSelection(
          values: const <String>['Only'],
          selected: 'Only',
          step: 1,
        ),
        'Only',
      );
      expect(
        nextSelection(
          values: const <String>['Only'],
          selected: 'Only',
          step: -1,
        ),
        'Only',
      );
    });

    test('is a no-op on an empty list rather than a range error', () {
      expect(
        nextSelection(values: const <String>[], selected: 'x', step: 1),
        isNull,
      );
    });

    test('a selected value outside the list snaps to the nearest end', () {
      // Reachable when a persisted setting names a value a rebuilt enum no
      // longer has. Returning null would leave the control with nothing drawn;
      // snapping keeps it usable.
      expect(nextSelection(values: three, selected: 'Sepia', step: 1), 'Light');
      expect(
        nextSelection(values: three, selected: 'Sepia', step: -1),
        'System',
      );
    });

    test('works on any type, not just String', () {
      // The widget is `SegmentedControl<T>` so `AppThemeMode` and
      // `ScriptureLanguage` both work without a second widget.
      expect(
        nextSelection(values: const <int>[10, 20, 30], selected: 10, step: 1),
        20,
      );
    });

    test('is its own inverse on a two-value list', () {
      expect(
        nextSelection(
          values: const <bool>[false, true],
          selected: false,
          step: 1,
        ),
        isTrue,
      );
      expect(
        nextSelection(
          values: const <bool>[false, true],
          selected: true,
          step: -1,
        ),
        isFalse,
      );
    });
  });

  group('the selection model and the direction', () {
    const List<String> three = <String>['EN', 'AR', 'FR'];

    test('right-arrow moves forward in LTR and back in RTL', () {
      // §14 requires arrow keys to work, and an RTL screen has to reverse what
      // "forward" means or ArrowRight walks the options backwards.
      expect(
        selectionStepFor(direction: TextDirection.ltr, logicalKeyForward: true),
        1,
      );
      expect(
        selectionStepFor(direction: TextDirection.rtl, logicalKeyForward: true),
        -1,
      );
      expect(
        selectionStepFor(
          direction: TextDirection.ltr,
          logicalKeyForward: false,
        ),
        -1,
      );
      expect(
        selectionStepFor(
          direction: TextDirection.rtl,
          logicalKeyForward: false,
        ),
        1,
      );
    });

    test('the wrap covers every value exactly once per lap', () {
      List<String> cursor = three;
      for (int lap = 0; lap < three.length; lap++) {
        cursor = <String>[
          nextSelection(values: three, selected: cursor.first, step: 1)!,
        ];
      }
      expect(cursor.first, three.first);
      expect(cursor, hasLength(1));
    });
  });
}
