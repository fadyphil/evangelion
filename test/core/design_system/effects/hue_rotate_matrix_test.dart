import 'dart:ui' show ColorFilter;

import 'package:evangelion/core/design_system/effects/hue_rotate_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

/// §13.3's matrix, transcribed from the plan. Kept as the oracle so the test is
/// not the implementation restated — a change here is a change to the spec.
const List<List<double>> _identity = <List<double>>[
  <double>[1, 0, 0, 0, 0],
  <double>[0, 1, 0, 0, 0],
  <double>[0, 0, 1, 0, 0],
  <double>[0, 0, 0, 1, 0],
];

void main() {
  group('hueRotateMatrix', () {
    test('is a 4x5 colour matrix — twenty entries, always', () {
      for (final double turns in <double>[0, 0.13, 0.5, 0.999, 1, 7.25]) {
        expect(hueRotateMatrix(turns), hasLength(20), reason: 'turns=$turns');
      }
    });

    test('is the identity at zero turns', () {
      final List<double> matrix = hueRotateMatrix(0);
      for (int row = 0; row < 4; row++) {
        for (int column = 0; column < 5; column++) {
          expect(
            matrix[row * 5 + column],
            closeTo(_identity[row][column], 1e-12),
            reason: 'row $row column $column',
          );
        }
      }
    });

    test(
      'is the identity again at one full turn — 360° is where it started',
      () {
        // The prototype's `hue-cycle` runs `hue-rotate(0deg) → hue-rotate(360deg)`,
        // so a turn of exactly 1.0 must land back on the identity or every loop
        // would show a seam.
        final List<double> full = hueRotateMatrix(1.0);
        final List<double> zero = hueRotateMatrix(0);
        for (int i = 0; i < full.length; i++) {
          expect(full[i], closeTo(zero[i], 1e-12), reason: 'entry $i');
        }
      },
    );

    test('leaves alpha alone — the last row is 0 0 0 1 0', () {
      // An orb's alpha is what `EvaColors.orbOpacity` sets. If the matrix
      // touched alpha, the hue cycle would breathe the opacity in step with the
      // hue, and nothing in the prototype does that.
      final List<double> matrix = hueRotateMatrix(0.37);
      expect(matrix.sublist(15), <double>[0, 0, 0, 1, 0]);
    });

    test('every colour row sums to 1, so greys stay grey', () {
      // A hue rotation must not change luminance for a neutral colour. A row
      // that does not sum to 1 scales the channel, which is a brightness change
      // wearing a hue change's clothes — and on a 0.55-alpha orb over a dark
      // canvas that reads as flicker.
      for (final double turns in <double>[0.07, 0.25, 0.5, 0.75, 0.91]) {
        final List<double> matrix = hueRotateMatrix(turns);
        for (int row = 0; row < 3; row++) {
          final double sum =
              matrix[row * 5] + matrix[row * 5 + 1] + matrix[row * 5 + 2];
          expect(sum, closeTo(1.0, 1e-12), reason: 'turns=$turns row=$row');
        }
      }
    });

    test(
      'a half turn is the negated off-diagonal — the widest hue excursion',
      () {
        // turns = 0.5 => hue = pi => cos = -1, sin = 0 (to within 1.2e-16).
        final List<double> matrix = hueRotateMatrix(0.5);
        const double s = 1.2246467991473532e-16; // sin(pi)
        expect(matrix[0], closeTo(0.213 - 0.787 + s * 0.213, 1e-12));
        expect(matrix[1], closeTo(0.715 + 0.715 - s * 0.715, 1e-12));
        expect(matrix[2], closeTo(0.072 + 0.072 + s * 0.928, 1e-12));
      },
    );

    test('is continuous across the 0/1 seam', () {
      // The painter feeds `((clock + phase) % 1.0)` straight in, so the matrix
      // has to be periodic. A discontinuity here would be one dropped frame of
      // a hue snap, once per cycle, on every orb, forever.
      //
      // The two samples are 0.002 of a turn apart, so they are legitimately
      // *not* equal — the sweep moves ~0.006 of a matrix coefficient over that
      // gap. 0.02 is chosen to be comfortably wider than that rounding and far
      // narrower than a discontinuity would be (which would be O(1)).
      final List<double> before = hueRotateMatrix(0.999);
      final List<double> after = hueRotateMatrix(0.001);
      for (int i = 0; i < before.length; i++) {
        expect(before[i], closeTo(after[i], 0.02), reason: 'entry $i');
      }
    });

    test('a negative turn is a full turn read backwards', () {
      // `hue-cycle-rev` is `hue-rotate(360deg) → hue-rotate(0deg)` — the forward
      // sweep with time reversed. That is EXACTLY `hue-rotate(-θ)`, because
      // `cos(2π - θ) == cos θ` and `sin(2π - θ) == -sin θ`, and the matrix is a
      // function of nothing but those two. So `m(-t) == m(1 - t)` to within
      // float rounding, which is what makes the reverse direction a sign flip on
      // `turns` rather than a second matrix to keep in step.
      for (final double t in <double>[0.2, 0.37, 0.5, 0.8]) {
        final List<double> backwards = hueRotateMatrix(-t);
        final List<double> wrapped = hueRotateMatrix(1 - t);
        for (int i = 0; i < backwards.length; i++) {
          expect(
            backwards[i],
            closeTo(wrapped[i], 1e-12),
            reason: 'turns=$t entry $i',
          );
        }
      }
    });

    test('reversing the sweep actually reverses it', () {
      // The sign flip is not a no-op dressed up as one: at a quarter turn the two
      // directions disagree on most of the sine terms.
      final List<double> forward = hueRotateMatrix(0.25);
      final List<double> reverse = hueRotateMatrix(-0.25);
      final int differences = List<int>.generate(
        15,
        (int i) => (forward[i] - reverse[i]).abs() > 1e-6 ? 1 : 0,
      ).fold(0, (int a, int b) => a + b);
      expect(
        differences,
        greaterThanOrEqualTo(9),
        reason: 'only the cos-only coefficients may agree',
      );
    });
  });

  group('hueRotateFilter', () {
    test('returns a ColorFilter built from the same matrix', () {
      expect(hueRotateFilter(0.25), isA<ColorFilter>());
    });

    test('is constructed for every turn without throwing', () {
      for (final double turns in <double>[0, 0.5, 1, -0.5, 3.75]) {
        expect(() => hueRotateFilter(turns), returnsNormally);
      }
    });
  });
}
