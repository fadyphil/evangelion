import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every curve in the table must be pinned at both ends, or an animation driven
/// by it settles short of — or before — its target.
void expectProperEndpoints(Curve curve, String name) {
  expect(curve.transform(0.0), 0.0, reason: '$name.transform(0)');
  expect(curve.transform(1.0), 1.0, reason: '$name.transform(1)');
}

void main() {
  group('durations', () {
    test('are the four fixed values from the spec table', () {
      // §5.3: fast 150ms · base 200ms · screen 250ms · fleck 2000ms · aurora 14s.
      expect(EvaMotion.fast, const Duration(milliseconds: 150));
      expect(EvaMotion.base, const Duration(milliseconds: 200));
      expect(EvaMotion.screen, const Duration(milliseconds: 250));
      expect(EvaMotion.fleck, const Duration(seconds: 2));
      expect(EvaMotion.aurora, const Duration(seconds: 14));
    });

    test('are ordered fast < base < screen', () {
      // A "fast" that outlasts a "screen" transition means the two roles have
      // been crossed somewhere, and nothing else in the system would say so.
      expect(EvaMotion.fast, lessThan(EvaMotion.base));
      expect(EvaMotion.base, lessThan(EvaMotion.screen));
    });

    test('the interaction durations stay under a quarter second', () {
      // Not a spec value — a budget this phase commits to so the numbers cannot
      // drift upward one at a time. A tap feedback longer than 250ms reads as
      // lag, and `09-quality-gates.md` §13 counts each blurred surface as a
      // saveLayer, so a slow animation here is also a battery cost.
      expect(
        EvaMotion.screen,
        lessThanOrEqualTo(const Duration(milliseconds: 250)),
      );
    });

    test('the ambient durations are seconds, not milliseconds', () {
      // The two categories must not be confused. A fleck that lasts 2000ms is
      // visible motion; the spec's 2000ms is deliberate and the orb/aurora
      // entries are 7–28s. Asserting the unit is what catches a `seconds` token
      // written as `milliseconds`.
      expect(EvaMotion.fleck.inMilliseconds, 2000);
      expect(EvaMotion.aurora.inSeconds, 14);
    });
  });

  group('the per-orb duration ranges', () {
    test('are the spec endpoints', () {
      // "orbFloat 14–28s per orb", "orbHue 7–14s per orb".
      expect(EvaMotion.orbFloatMin, const Duration(seconds: 14));
      expect(EvaMotion.orbFloatMax, const Duration(seconds: 28));
      expect(EvaMotion.orbHueMin, const Duration(seconds: 7));
      expect(EvaMotion.orbHueMax, const Duration(seconds: 14));
    });

    test('have a min below a max, and a hue cycle faster than a float', () {
      // Hue has to complete often enough that the drift is seen as colour
      // breathing rather than as a colour change; a hue cycle slower than the
      // float would read as the orb drifting while its colour froze.
      expect(EvaMotion.orbFloatMin, lessThan(EvaMotion.orbFloatMax));
      expect(EvaMotion.orbHueMin, lessThan(EvaMotion.orbHueMax));
      expect(EvaMotion.orbHueMax, lessThan(EvaMotion.orbFloatMax));
      // orbFloatMin and aurora are both 14s in the spec — deliberately equal, not
      // a typo — so the bound is non-strict.
      expect(EvaMotion.orbFloatMin, lessThanOrEqualTo(EvaMotion.aurora));
    });

    test('spread evenly across orbs, endpoints included', () {
      // Four orbs across 14–28s: the first gets 14s and the last 28s, so no two
      // orbs share a duration and the field cannot pulse in lockstep
      // (`09-quality-gates.md` §13 mitigation 2).
      expect(EvaMotion.orbFloatFor(0, 4), const Duration(seconds: 14));
      expect(
        EvaMotion.orbFloatFor(3, 4),
        const Duration(seconds: 28),
        reason: 'the last orb must reach the top of the range',
      );
      expect(
        EvaMotion.orbFloatFor(1, 4),
        const Duration(microseconds: 18666666),
        reason: '14 + 14 × 1/3 s, truncated to whole microseconds',
      );
      expect(
        EvaMotion.orbFloatFor(2, 4),
        const Duration(microseconds: 23333333),
      );

      final Set<Duration> distinct = <Duration>{
        for (int i = 0; i < 4; i++) EvaMotion.orbFloatFor(i, 4),
      };
      expect(distinct.length, 4, reason: 'no two orbs may share a duration');

      // And the spread is monotonic in the index.
      for (int i = 0; i < 3; i++) {
        expect(
          EvaMotion.orbFloatFor(i + 1, 4),
          greaterThan(EvaMotion.orbFloatFor(i, 4)),
        );
        expect(
          EvaMotion.orbHueFor(i + 1, 4),
          greaterThan(EvaMotion.orbHueFor(i, 4)),
        );
      }

      expect(EvaMotion.orbHueFor(0, 4), const Duration(seconds: 7));
      expect(EvaMotion.orbHueFor(3, 4), const Duration(seconds: 14));
      expect(EvaMotion.orbHueFor(1, 4), const Duration(microseconds: 9333333));
    });

    test('collapse to the minimum for a single orb', () {
      // Division by `count - 1` would be 0/0 here. One orb is a real
      // configuration — `NeuralTier` drops to `low` with no orbs, and the
      // portrait/landscape swap can leave exactly one.
      expect(EvaMotion.orbFloatFor(0, 1), EvaMotion.orbFloatMin);
      expect(EvaMotion.orbHueFor(0, 1), EvaMotion.orbHueMin);
      expect(
        EvaMotion.orbFloatFor(0, 1),
        EvaMotion.orbFloatFor(0, 2),
        reason:
            'a lone orb and the first of two share a phase offset, so the '
            'single-orb case must agree with the spread rather than diverge',
      );
    });

    test('reject a non-positive orb count instead of returning nonsense', () {
      // A zero count is a division by zero that would surface as an
      // `UnsupportedError` from `Duration`'s own constructor on some paths and a
      // silent wrap on others. An assert pins it at the call site.
      expect(() => EvaMotion.orbFloatFor(0, 0), throwsA(isA<AssertionError>()));
      expect(() => EvaMotion.orbHueFor(0, -1), throwsA(isA<AssertionError>()));
    });
  });

  group('curves', () {
    test('every curve is pinned at 0 and 1', () {
      expectProperEndpoints(EvaMotion.fastCurve, 'fastCurve');
      expectProperEndpoints(EvaMotion.baseCurve, 'baseCurve');
      expectProperEndpoints(EvaMotion.screenCurve, 'screenCurve');
      expectProperEndpoints(EvaMotion.fleckCurve, 'fleckCurve');
      expectProperEndpoints(EvaMotion.orbFloatCurve, 'orbFloatCurve');
      expectProperEndpoints(EvaMotion.orbHueCurve, 'orbHueCurve');
      expectProperEndpoints(EvaMotion.auroraCurve, 'auroraCurve');
    });

    test('fast and base are ease-out — fast off the mark, slow to settle', () {
      // Asserted SHAPE, not identity. `expect(EvaMotion.fastCurve,
      // Curves.easeOut)` would compare the canonicalised `Curves.easeOut` against
      // itself whenever the token is written as that same constant, so it would
      // hold for any implementation that returned *a* curve. The shape is what
      // actually distinguishes ease-out: most of the distance is covered early.
      for (final MapEntry<String, Curve> entry in <String, Curve>{
        'fast': EvaMotion.fastCurve,
        'base': EvaMotion.baseCurve,
      }.entries) {
        expect(
          entry.value.transform(0.25),
          greaterThan(0.25),
          reason: entry.key,
        );
        expect(entry.value.transform(0.5), greaterThan(0.5), reason: entry.key);
        expect(
          entry.value.transform(0.5),
          closeTo(Curves.easeOut.transform(0.5), 1e-12),
          reason: '${entry.key} must be easeOut exactly, not merely ease-ish',
        );
      }
    });

    test('screen is easeOutCubic, which is steeper than easeOut', () {
      // The two numbers are `Curves.easeOutCubic` (cubic-bezier(.33, 1, .68, 1))
      // at t = 0.25 and t = 0.75, and `Curves.easeOut` at the same t. They are
      // 0.599 and 0.976 against 0.378 — far enough apart that swapping
      // `screenCurve` for `fastCurve`, or for `easeIn`, cannot pass, and pinned
      // tightly enough (1e-12) that no other shipped curve lands on them.
      expect(
        EvaMotion.screenCurve.transform(0.25),
        closeTo(0.5991595584154129, 1e-12),
      );
      expect(
        EvaMotion.screenCurve.transform(0.75),
        closeTo(0.9760727959871291, 1e-12),
      );
      expect(
        EvaMotion.screenCurve.transform(0.25),
        greaterThan(EvaMotion.fastCurve.transform(0.25)),
        reason: 'easeOutCubic must outrun easeOut early on',
      );
    });

    test('fleck is ease-out and alternates', () {
      // "fleck | 2000ms | alternate". `alternate` is a DIRECTION, not a shape —
      // in Flutter it is `AnimationController.repeat(reverse: true)`, and there
      // is no `Curves.alternate`. So the curve is the ease-out shape the brief's
      // "all curves are ease-out" rule requires, and the alternation is carried
      // by [EvaMotion.fleckAlternates] for Phase 2 to act on.
      // `Curves.easeOut` at t = 0.5 — the value that separates it from
      // easeOutCubic's 0.599 and from linear's 0.5.
      expect(EvaMotion.fleckCurve.transform(0.5), closeTo(0.68359375, 1e-12));
      expect(
        EvaMotion.fleckCurve.transform(0.5),
        isNot(closeTo(EvaMotion.screenCurve.transform(0.5), 1e-6)),
        reason: 'the fleck must not inherit the screen transition’s curve',
      );
      expect(EvaMotion.fleckAlternates, isTrue);
    });

    test('the ambient curves are easeInOut, linear as specified', () {
      // easeInOut is symmetric about the midpoint and spends the first half
      // *below* the diagonal — the property that distinguishes it from easeOut.
      for (final MapEntry<String, Curve> entry in <String, Curve>{
        'orbFloat': EvaMotion.orbFloatCurve,
        'aurora': EvaMotion.auroraCurve,
      }.entries) {
        expect(
          entry.value.transform(0.25),
          lessThan(0.25),
          reason: '${entry.key} must start slow',
        );
        expect(entry.value.transform(0.75), greaterThan(0.75));
        expect(
          entry.value.transform(0.3) + entry.value.transform(0.7),
          closeTo(1.0, 1e-12),
          reason: '${entry.key} must be symmetric',
        );
      }

      // "orbHue | 7–14s per orb | linear". A hue rotation is a rotation — easing
      // it would make the colour accelerate through hues, which reads as
      // flickering rather than as breathing.
      expect(EvaMotion.orbHueCurve.transform(0.37), closeTo(0.37, 1e-12));
      expect(EvaMotion.orbHueCurve.transform(0.0), 0.0);
      expect(EvaMotion.orbHueCurve.transform(1.0), 1.0);
    });

    test('no curve is a spring or a bounce', () {
      // "No bounce, no spring — matching the brief's motion rule." An overshooting
      // curve puts y outside [0, 1]; every curve here is monotonic and bounded.
      for (final MapEntry<String, Curve> entry in <String, Curve>{
        'fast': EvaMotion.fastCurve,
        'base': EvaMotion.baseCurve,
        'screen': EvaMotion.screenCurve,
        'fleck': EvaMotion.fleckCurve,
        'orbFloat': EvaMotion.orbFloatCurve,
        'orbHue': EvaMotion.orbHueCurve,
        'aurora': EvaMotion.auroraCurve,
      }.entries) {
        double previous = 0.0;
        for (double t = 0.0; t <= 1.0; t += 0.05) {
          final double y = entry.value.transform(t);
          expect(y, inInclusiveRange(0.0, 1.0), reason: '${entry.key} at t=$t');
          expect(
            y,
            greaterThanOrEqualTo(previous),
            reason: '${entry.key} at t=$t',
          );
          previous = y;
        }
      }
    });
  });
}
