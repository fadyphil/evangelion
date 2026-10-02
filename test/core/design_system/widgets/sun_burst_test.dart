import 'dart:math' as math;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

Widget _burst({ThemeData? theme, double size = 96}) => evaAmbientHarness(
  theme: theme,
  child: SizedBox(
    width: 160,
    height: 160,
    child: Center(child: SunBurst(size: size)),
  ),
);

void main() {
  group('the ray table is the prototype\'s', () {
    // ResultScreen.tsx:7-15.
    test('fourteen rays', () {
      expect(sunBurstRayCount, 14);
      expect(sunBurstRays(), hasLength(14));
    });

    test('inner radius 26 for every ray', () {
      for (final SunBurstRay ray in sunBurstRays()) {
        expect(ray.inner, 26.0, reason: 'ray ${ray.index}');
      }
    });

    test('outer radius alternates 46 / 39 on even / odd indices', () {
      for (final SunBurstRay ray in sunBurstRays()) {
        expect(
          ray.outer,
          ray.index.isEven ? 46.0 : 39.0,
          reason: 'ray ${ray.index}',
        );
      }
    });

    test('stroke width alternates 2.5 / 1.5 the same way', () {
      for (final SunBurstRay ray in sunBurstRays()) {
        expect(
          ray.width,
          ray.index.isEven ? 2.5 : 1.5,
          reason: 'ray ${ray.index}',
        );
      }
    });

    test('rays start at i * (360 / 14) degrees, measured from three o\'clock', () {
      // `ResultScreen.tsx:8` — `const a = (i * (360 / 14) * Math.PI) / 180`,
      // consumed by `cos`/`sin`, so angle 0 is +x and the burst sweeps in the
      // direction +y is on screen. Fourteen rays do NOT include 90°:
      // 3 x 25.714° is 77.14° and 4 x 25.714° is 102.86°, which is part of why
      // the burst reads as a sunburst and not as a clock face.
      // `atan2` answers in (-pi, pi], so every ray past six o'clock comes back
      // negative and comparing raw would fail on ray 8 with both numbers being
      // the same angle. Normalised first, then compared.
      double normalise(double radians) =>
          (radians % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      for (final SunBurstRay ray in sunBurstRays()) {
        final double expected = ray.index * 2 * math.pi / 14;
        final double actual = normalise(
          math.atan2(ray.start.dy - 50, ray.start.dx - 50),
        );
        expect(actual, closeTo(expected, 1e-9), reason: 'ray ${ray.index}');
      }
      expect(sunBurstRays().first.start, const Offset(76, 50));
    });

    test('every ray starts at radius 26 and ends at its own radius', () {
      for (final SunBurstRay ray in sunBurstRays()) {
        final Offset start = ray.start - const Offset(50, 50);
        final Offset end = ray.end - const Offset(50, 50);
        expect(start.distance, closeTo(26, 1e-9), reason: 'ray ${ray.index}');
        expect(end.distance, closeTo(ray.outer, 1e-9));
      }
    });

    test('the rays sweep the whole circle evenly, exactly once', () {
      // Renamed and rewritten. The old test collected the fourteen start angles
      // into a `Set` and asserted `hasLength(14)` — which is the same assertion
      // as "no two rays share an angle" directly below it, duplicated, and it
      // never checked "once": fourteen distinct angles clustered in one arc of a
      // degree would satisfy it.
      //
      // What "exactly once, evenly" actually means is that the gaps between
      // *consecutive* angles around the circle are all `2π / 14`. That is a
      // stronger and genuinely different claim, and it is what the prototype's
      // `i * (360 / 14)` produces.
      const double step = 2 * math.pi / 14;
      final List<double> sorted = <double>[
        for (final SunBurstRay ray in sunBurstRays())
          math.atan2(ray.start.dy - 50, ray.start.dx - 50),
      ]..sort();
      for (int i = 0; i < sorted.length; i++) {
        final double gap = i == sorted.length - 1
            ? sorted.first + 2 * math.pi - sorted.last
            : sorted[i + 1] - sorted[i];
        expect(
          gap,
          closeTo(step, 1e-9),
          reason: 'gap $i of 14 — a ray missing from a quadrant shows here',
        );
      }
    });

    test('no two rays share an angle', () {
      final List<Offset> starts = <Offset>[
        for (final SunBurstRay ray in sunBurstRays()) ray.start,
      ];
      expect(starts.toSet(), hasLength(14));
    });
  });

  group('the discs and flecks are the prototype\'s', () {
    test('three discs — r30 at 12%, r24 at 90%, r18 at 60%', () {
      // ResultScreen.tsx:16-18. The name used to read "r30 at 12% behind r24 at
      // 90% and r18 at 60%", repeating a claim about the SVG that was false: SVG
      // paints in document order, so the prototype's r30 halo is last and on top.
      // It also implied the order mattered, which it does not — all three discs
      // are `#F5C84C`, and compositing one colour over itself is commutative.
      // `sun_burst.dart`'s doc carries the measurement (173 of 480,000 pixels,
      // both directions, rounding only).
      expect(sunBurstDiscs, hasLength(3));
      expect(sunBurstDiscs[0], <double>[30, 0.12]);
      expect(sunBurstDiscs[1], <double>[24, 0.9]);
      expect(sunBurstDiscs[2], <double>[18, 0.6]);
    });

    test('the discs nest, so the radii are an increasing set', () {
      // The one property of the list the painter actually depends on: each disc
      // is drawn over the one before it, so a list out of order would put a
      // smaller disc over a larger one and the 90% disc would win the centre.
      expect(
        sunBurstDiscs.map((List<double> d) => d[0]),
        orderedEquals(
          <double>[...sunBurstDiscs.map((List<double> d) => d[0])]
            ..sort((double a, double b) => b.compareTo(a)),
        ),
      );
    });

    test('five flecks at their exact centres, radii and alphas', () {
      // ResultScreen.tsx:19-24. Every fleck's radius is pinned: the first version
      // asserted radii for flecks 0 and 3 only, so 1, 2 and 4 could be any
      // plausible-looking number and every golden stayed green.
      expect(sunBurstFlecks, hasLength(5));
      expect(sunBurstFlecks[0].centre, const Offset(28, 18));
      expect(sunBurstFlecks[0].radius, 2.5);
      expect(sunBurstFlecks[0].alpha, 0.9);
      expect(sunBurstFlecks[1].centre, const Offset(72, 16));
      expect(sunBurstFlecks[1].radius, 2.0);
      expect(sunBurstFlecks[1].alpha, 0.7);
      expect(sunBurstFlecks[2].centre, const Offset(80, 60));
      expect(sunBurstFlecks[2].radius, 2.0);
      expect(sunBurstFlecks[2].alpha, 0.8);
      expect(sunBurstFlecks[3].centre, const Offset(16, 64));
      expect(sunBurstFlecks[3].radius, 2.5);
      expect(sunBurstFlecks[3].alpha, 0.6);
      expect(sunBurstFlecks[4].centre, const Offset(64, 82));
      expect(sunBurstFlecks[4].radius, 2.0);
      expect(sunBurstFlecks[4].alpha, 0.7);
    });

    test('every fleck sits inside the 100x100 box', () {
      for (final SunBurstFleck fleck in sunBurstFlecks) {
        expect(fleck.centre.dx, inInclusiveRange(0, 100));
        expect(fleck.centre.dy, inInclusiveRange(0, 100));
      }
    });

    test('the ray colour is the sticker palette\'s sun', () {
      // `#F5C84C` is `StickerSlot.sun` — the one prototype colour here the
      // design system already publishes.
      expect(EvaStickerPalette.of(StickerSlot.sun).toARGB32(), 0xFFF5C84C);
    });
  });

  group('the widget', () {
    testWidgets('is square at the inventory\'s default 96', (
      WidgetTester tester,
    ) async {
      const SunBurst burst = SunBurst();
      expect(burst.size, 96.0);
      await tester.pumpWidget(_burst());
      expect(tester.getSize(find.byType(SunBurst)), const Size.square(96));
    });

    testWidgets('honours a custom size', (WidgetTester tester) async {
      await tester.pumpWidget(_burst(size: 40));
      expect(tester.getSize(find.byType(SunBurst)), const Size.square(40));
    });

    testWidgets('is decorative and says nothing', (WidgetTester tester) async {
      // The score and the stat tiles carry the meaning; a "celebration" node
      // would be read out as noise on every Result visit.
      await tester.pumpWidget(_burst());
      expect(
        find.descendant(
          of: find.byType(SunBurst),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('paints one CustomPaint', (WidgetTester tester) async {
      await tester.pumpWidget(_burst());
      expect(
        find.descendant(
          of: find.byType(SunBurst),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a palette change repaints the painter', (
      WidgetTester tester,
    ) async {
      // The burst reads `sun` and `ember` from `EvaColors`, so a theme switch is
      // the one thing that has to invalidate it.
      await tester.pumpWidget(_burst());
      final CustomPaint before = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(SunBurst),
          matching: find.byType(CustomPaint),
        ),
      );
      await tester.pumpWidget(_burst(theme: EvaThemeLight.theme));
      expect(
        identical(
          before,
          tester.widget<CustomPaint>(
            find.descendant(
              of: find.byType(SunBurst),
              matching: find.byType(CustomPaint),
            ),
          ),
        ),
        isFalse,
      );
    });

    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await tester.pumpWidget(_burst(theme: theme));
        await tester.pump();
        await expectLater(
          find.byType(SunBurst),
          matchesGoldenFile('goldens/sun_burst_$label.png'),
        );
      });
    }
  });
}
