import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ambient's **frame budget** — the divisors, and the gate that paces them.
///
/// ## WHY A BUDGET AND NOT A CONSTANT
///
/// The ambient is the app's most expensive layer: a full-screen fragment
/// shader re-rasterised at device resolution, and a notification that rebuilds
/// the witness sky's forty-four stars. §13 rule 4 asked for a tier that
/// *"drops to `low` on low-end devices: no orbs, aurora only, at **30 % cost**"*
/// and `LumenTiers` never grew one.
///
/// ## AND WHY IT COUNTS **FRAMES** AND NOT TIME
///
/// Because every clock available here is wrong for one reason or another, and
/// the reasons are recorded in `ambient_tick_budget.dart`'s class doc. The
/// short version: a wall clock can go backwards, a `Stopwatch` makes the
/// goldens non-deterministic, the frame timestamp asserts that a frame is in
/// progress, and the shader clock's own elapsed time is a frame behind the
/// float clock's. **A frame count has none of those problems** — and the
/// ambient's notification is already one per frame.
void main() {
  group('the budget', () {
    test('a 60Hz display paints the aurora at 30Hz and notifies at 20Hz', () {
      final AmbientTickBudget budget = AmbientTickBudget.resolve(
        displayRefreshRate: 60,
      );
      expect(budget.paintEveryNTick, 2, reason: '60 / 30');
      expect(budget.notifyEveryNTick, 3, reason: '60 / 20');
    });

    test('a 120Hz display is capped the same way', () {
      // **The cap, and not a division.** A 120 Hz panel could paint four times
      // as often as a 60 Hz one, and the budget is what stops the ambient
      // from taking the invitation.
      final AmbientTickBudget budget = AmbientTickBudget.resolve(
        displayRefreshRate: 120,
      );
      expect(budget.paintEveryNTick, 4, reason: '120 / 30');
      expect(budget.notifyEveryNTick, 6, reason: '120 / 20');
    });

    test('a display slower than the budget is left alone', () {
      // A 24 Hz panel is already below the aurora's 30 Hz, and throttling it
      // further would be a cost with no benefit.
      final AmbientTickBudget budget = AmbientTickBudget.resolve(
        displayRefreshRate: 24,
      );
      expect(budget.paintEveryNTick, 1, reason: '24 / 30 rounds to 1');
      expect(budget.notifyEveryNTick, 1, reason: '24 / 20 rounds to 1');
    });

    test('it names its two divisors', () {
      // The `toString` is a **diagnostic**, and the repository's convention is
      // that a diagnostic is asserted rather than hoped for — an unasserted
      // `toString` is a line nobody reads and a branch nobody exercises.
      final AmbientTickBudget budget = AmbientTickBudget.resolve(
        displayRefreshRate: 60,
      );
      expect(budget.toString(), contains('2'));
      expect(budget.toString(), contains('3'));
    });

    test('a nonsense refresh rate falls back rather than dividing by zero', () {
      for (final double rate in <double>[0, -1, double.nan, double.infinity]) {
        final AmbientTickBudget budget = AmbientTickBudget.resolve(
          displayRefreshRate: rate,
        );
        expect(
          budget.paintEveryNTick,
          greaterThanOrEqualTo(1),
          reason:
              'a divisor of zero would mean "never", and a budget that '
              'never paints is a black screen. Rate: $rate',
        );
        expect(budget.notifyEveryNTick, greaterThanOrEqualTo(1));
      }
    });
  });

  group('the gate', () {
    test('a divisor of one fires every frame', () {
      final AmbientTickGate gate = AmbientTickGate(1);
      expect(gate.isDue(), isTrue);
      expect(gate.isDue(), isTrue);
      expect(gate.isDue(), isTrue);
    });

    test('a divisor of two fires on the first frame and every other after', () {
      final AmbientTickGate gate = AmbientTickGate(2);
      // **The first frame always fires**, because the thing it gates has to be
      // drawn once whatever the budget says.
      expect(gate.isDue(), isTrue, reason: 'the first frame');
      expect(gate.isDue(), isFalse, reason: 'the second frame');
      expect(gate.isDue(), isTrue, reason: 'the third frame');
      expect(gate.isDue(), isFalse);
      expect(gate.isDue(), isTrue);
    });

    test('a divisor of three fires on the first and every third after', () {
      final AmbientTickGate gate = AmbientTickGate(3);
      expect(gate.isDue(), isTrue, reason: 'the first frame');
      expect(gate.isDue(), isFalse);
      expect(gate.isDue(), isFalse);
      expect(gate.isDue(), isTrue, reason: 'the fourth frame');
    });

    test('and it is a count, so the same sequence repeats', () {
      // **The determinism is the point.** A gate over *time* would make every
      // golden that depends on the ambient depend on how fast the machine ran.
      final AmbientTickGate first = AmbientTickGate(3);
      final AmbientTickGate second = AmbientTickGate(3);
      for (int frame = 0; frame < 20; frame++) {
        expect(
          first.isDue(),
          second.isDue(),
          reason: 'two gates with the same divisor must agree on every frame',
        );
      }
    });
  });
}
