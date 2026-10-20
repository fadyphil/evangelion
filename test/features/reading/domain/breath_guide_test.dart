import 'package:evangelion/features/reading/domain/breath_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the prototype\'s numbers', () {
    test('the cycle is eight seconds', () {
      // `eva/redesign.html:174` — `animation:breath 8s ease-in-out infinite`.
      expect(kBreathCycle, const Duration(seconds: 8));
    });

    test('the keyframes are the prototype\'s', () {
      // `eva/redesign.html:175` — `0%,100%{transform:scaleX(.25);opacity:.25}`
      // and `50%{transform:scaleX(1);opacity:.6}`.
      expect(kBreathScaleMin, closeTo(0.25, 1e-9));
      expect(kBreathScaleMax, closeTo(1, 1e-9));
      expect(kBreathOpacityMin, closeTo(0.25, 1e-9));
      expect(kBreathOpacityMax, closeTo(0.6, 1e-9));
    });
  });

  group('breathPhaseAt', () {
    test('at no progress the line is at its narrowest', () {
      final BreathPhase phase = breathPhaseAt(0);
      expect(phase.scale, closeTo(kBreathScaleMin, 1e-9));
      expect(phase.opacity, closeTo(kBreathOpacityMin, 1e-9));
    });

    test('at full progress the line is at its widest', () {
      final BreathPhase phase = breathPhaseAt(1);
      expect(phase.scale, closeTo(kBreathScaleMax, 1e-9));
      expect(phase.opacity, closeTo(kBreathOpacityMax, 1e-9));
    });

    test('it interpolates between the two', () {
      final BreathPhase phase = breathPhaseAt(0.5);
      expect(
        phase.scale,
        closeTo(
          kBreathScaleMin + (kBreathScaleMax - kBreathScaleMin) * 0.5,
          1e-9,
        ),
      );
      expect(
        phase.opacity,
        closeTo(
          kBreathOpacityMin + (kBreathOpacityMax - kBreathOpacityMin) * 0.5,
          1e-9,
        ),
      );
    });

    test('a progress outside 0…1 is clamped, not extrapolated', () {
      // The widget eases the progress, and a curve is free to overshoot; a
      // line that scaled past 1.0 would draw outside its own box.
      expect(breathPhaseAt(-1).scale, closeTo(kBreathScaleMin, 1e-9));
      expect(breathPhaseAt(2).scale, closeTo(kBreathScaleMax, 1e-9));
    });
  });

  group('equality', () {
    test('two phases with the same numbers are equal', () {
      expect(
        breathPhaseAt(0.5),
        const BreathPhase(scale: 0.625, opacity: 0.425),
      );
      expect(
        breathPhaseAt(0.5).hashCode,
        const BreathPhase(scale: 0.625, opacity: 0.425).hashCode,
      );
    });

    test('and two phases with different numbers are not', () {
      expect(
        breathPhaseAt(0.5),
        isNot(const BreathPhase(scale: 0.625, opacity: 0.5)),
      );
    });

    test('and it names its own numbers', () {
      // Failure output: a phase printed as `Instance of` would make a failed
      // `expect` useless.
      expect(
        breathPhaseAt(0).toString(),
        'BreathPhase(scale: 0.25, opacity: 0.25)',
      );
    });
  });

  group('breathHalfProgressAt', () {
    test('the first half expands and the second contracts', () {
      // The keyframes are at 0%, 50% and 100% — so the line is narrowest at
      // the start, widest half way through, and narrowest again at the end.
      expect(breathHalfProgressAt(Duration.zero), closeTo(0, 1e-9));
      expect(
        breathHalfProgressAt(const Duration(seconds: 4)),
        closeTo(1, 1e-9),
      );
      expect(
        breathHalfProgressAt(const Duration(seconds: 8)),
        closeTo(0, 1e-9),
      );
    });

    test('it is a triangle within each half', () {
      expect(
        breathHalfProgressAt(const Duration(seconds: 1)),
        closeTo(0.25, 1e-9),
      );
      expect(
        breathHalfProgressAt(const Duration(seconds: 2)),
        closeTo(0.5, 1e-9),
      );
      expect(
        breathHalfProgressAt(const Duration(seconds: 6)),
        closeTo(0.5, 1e-9),
      );
      expect(
        breathHalfProgressAt(const Duration(seconds: 7)),
        closeTo(0.25, 1e-9),
      );
    });

    test('the cycle repeats', () {
      expect(
        breathHalfProgressAt(const Duration(seconds: 10)),
        closeTo(breathHalfProgressAt(const Duration(seconds: 2)), 1e-9),
      );
    });

    test('a negative elapsed time reads as the start of the cycle', () {
      // The clock cannot go backwards in production, but a countdown that
      // wrapped would otherwise report a negative progress and a line scaled
      // past its own minimum.
      expect(
        breathHalfProgressAt(const Duration(seconds: -2)),
        closeTo(0, 1e-9),
      );
    });
  });
}
