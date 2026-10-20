import 'package:evangelion/core/common/cycle_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cycleProgress', () {
    test('it is 0 at the start and climbs to 1 over the cycle', () {
      expect(
        cycleProgress(
          elapsed: Duration.zero,
          cycle: const Duration(seconds: 8),
        ),
        closeTo(0, 1e-9),
      );
      expect(
        cycleProgress(
          elapsed: const Duration(seconds: 4),
          cycle: const Duration(seconds: 8),
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('it repeats', () {
      expect(
        cycleProgress(
          elapsed: const Duration(seconds: 10),
          cycle: const Duration(seconds: 8),
        ),
        closeTo(0.25, 1e-9),
      );
    });

    test('a negative elapsed time reads as the start', () {
      expect(
        cycleProgress(
          elapsed: const Duration(seconds: -2),
          cycle: const Duration(seconds: 8),
        ),
        closeTo(0, 1e-9),
      );
    });

    test(
      'a cycle of no length reads as the start rather than dividing by zero',
      () {
        expect(
          cycleProgress(
            elapsed: const Duration(seconds: 1),
            cycle: Duration.zero,
          ),
          closeTo(0, 1e-9),
        );
      },
    );
  });

  group('halfCycleProgress', () {
    test('it runs up over the first half and down over the second', () {
      expect(halfCycleProgress(0), closeTo(0, 1e-9));
      expect(halfCycleProgress(0.25), closeTo(0.5, 1e-9));
      expect(halfCycleProgress(0.5), closeTo(1, 1e-9));
      expect(halfCycleProgress(0.75), closeTo(0.5, 1e-9));
      expect(halfCycleProgress(1), closeTo(0, 1e-9));
    });

    test('a progress outside 0…1 is clamped, not extrapolated', () {
      expect(halfCycleProgress(-1), closeTo(0, 1e-9));
      expect(halfCycleProgress(2), closeTo(0, 1e-9));
    });
  });
}
