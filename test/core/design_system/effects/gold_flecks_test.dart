import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The layer the pixel and golden assertions read.
///
/// `find.byType(RepaintBoundary).first` is not usable here: `MaterialApp` brings
/// several boundaries of its own and the first one is not the layer holding the
/// sparkle. Capturing it yields an entirely transparent buffer, which reads as
/// "the painter drew nothing" — a false negative that looks exactly like a real
/// one.
const Key _layerKey = ValueKey<String>('flecks-layer');

const List<Offset> _quizFlecks = <Offset>[
  Offset(-10, 12),
  Offset(-15, 36),
  Offset(356, 8),
  Offset(362, 30),
];

Widget _flecks({
  List<Offset> offsets = _quizFlecks,
  bool dense = false,
  ThemeData? theme,
  bool disableAnimations = false,
  bool animationsEnabled = true,
}) => evaAmbientHarness(
  theme: theme,
  disableAnimations: disableAnimations,
  animationsEnabled: animationsEnabled,
  child: RepaintBoundary(
    key: _layerKey,
    child: SizedBox(
      width: 380,
      height: 120,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GoldFlecks(offsets: offsets, dense: dense),
          ),
        ],
      ),
    ),
  ),
);

/// Reads the layer the harness put around the flecks.
///
/// A boundary of our own rather than "the first `RepaintBoundary` in the tree":
/// `MaterialApp` brings several and the first one is not the layer holding the
/// sparkle, which reads as an entirely transparent buffer and looks exactly like
/// "the painter drew nothing".
Future<List<int>> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_layerKey));
  final List<int>? bytes = await tester.runAsync<List<int>>(() async {
    final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
    final ByteData? data = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ));
    image.dispose();
    if (data == null) {
      throw StateError('the flecks layer produced no byte data');
    }
    return <int>[for (int i = 0; i < data.lengthInBytes; i++) data.getUint8(i)];
  });
  // Failing closed rather than returning an empty list: an empty buffer
  // satisfies every "the pixels differ" comparison in this file vacuously, and
  // reads as "the painter drew nothing" — which is indistinguishable from a real
  // regression until you know the capture failed.
  if (bytes == null || bytes.isEmpty) {
    throw StateError(
      'the flecks layer produced ${bytes?.length ?? 0} bytes; a capture that '
      'returned nothing cannot support any assertion in this file',
    );
  }
  return bytes;
}

/// The alpha channel at ([x], [y]) in a [_pixels] buffer of [width] columns.
///
/// Alpha and not colour: the fleck's glow fades to fully transparent, and a
/// fleck off the edge of the box is still drawn — only its alpha tells us so.
int _alphaAt(List<int> rgba, int width, int x, int y) =>
    rgba[((y * width) + x) * 4 + 3];

void main() {
  group('the fleck constants are the prototype\'s', () {
    test('radius 2.5 from a 5px circle, glow reach 10px', () {
      // QuizScreen.tsx:15-16 — `width: 5, height: 5` and
      // `boxShadow: '0 0 10px #E8A33D'`.
      expect(kFleckRadius, 2.5);
      expect(kFleckGlow, 10.0);
    });

    test('travel 9px and opacity 0.85 to 0.35', () {
      // index.css:86-87.
      expect(kFleckTravel, 9.0);
      expect(kFleckOpacityHigh, 0.85);
      expect(kFleckOpacityLow, 0.35);
    });

    test('the cycle is 2s and the float clock is 20s, so ten fit in one', () {
      expect(EvaMotion.fleck, const Duration(seconds: 2));
      expect(kFloatPeriod, const Duration(seconds: 20));
      expect(GoldFlecks.flecksPerFloatCycle, 10);
    });

    test('and the count is DERIVED from those two, not a third literal', () {
      // The hole this closes. `flecksPerFloatCycle` is the multiplier
      // `goldFleckPhase` applies to the float clock, so the fleck rate is
      // `float rate × that number`. Asserting the three numbers side by side
      // leaves the multiplication unchecked: `EvaMotion.fleck` 2s → 4s,
      // `kFloatPeriod` 20s → 40s and `flecksPerFloatCycle` 10 → 20 all at once
      // leaves the whole Phase 2 suite green, goldens included, because
      // `clock × 20` over a 40s clock is the same phase as `clock × 10` over a
      // 20s one. Only a derived assertion can see that.
      expect(
        GoldFlecks.flecksPerFloatCycle,
        kFloatPeriod.inMicroseconds ~/ EvaMotion.fleck.inMicroseconds,
      );
    });

    test('so retiming one of the three is a failure, not a silent no-op', () {
      // The same derivation, phrased as the change it forbids: any one of the
      // three moving alone leaves the fleck period wrong, which is exactly the
      // state three independent literals cannot distinguish from correct.
      final int derived =
          kFloatPeriod.inMicroseconds ~/ EvaMotion.fleck.inMicroseconds;
      expect(
        GoldFlecks.flecksPerFloatCycle,
        derived,
        reason:
            'the fleck cycle is kFloatPeriod / flecksPerFloatCycle seconds, so '
            'it must equal EvaMotion.fleck — retiming the fleck without '
            'retiming the float clock (or the reverse) leaves the two '
            'disagreeing and no golden moves, because the product is what the '
            'pixels see',
      );
      expect(
        Duration(
          microseconds:
              kFloatPeriod.inMicroseconds ~/ GoldFlecks.flecksPerFloatCycle,
        ),
        EvaMotion.fleck,
      );
    });
  });

  group('goldFleckTriangle — 2s ease-in-out infinite alternate', () {
    test('is 0 at the start, 1 at the half cycle, 0 at the end', () {
      expect(goldFleckTriangle(0), 0.0);
      expect(goldFleckTriangle(0.5), 1.0);
      expect(goldFleckTriangle(1.0), 0.0);
    });

    test('is symmetric and periodic', () {
      expect(goldFleckTriangle(0.2), closeTo(goldFleckTriangle(0.8), 1e-12));
      expect(goldFleckTriangle(1.25), closeTo(goldFleckTriangle(0.25), 1e-12));
    });

    test('never leaves [0, 1]', () {
      for (int step = 0; step <= 100; step++) {
        expect(goldFleckTriangle(step / 25), inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('goldFleckPhase', () {
    test('stagger spreads the flecks over a fifth of the cycle', () {
      // The prototype's four delays are 0 / 110 / 220 / 340ms of 2000ms — a
      // spread of 0.17, rounded to the clean 0.2 this publishes.
      expect(kFleckPhaseSpread, 0.2);
      expect(goldFleckPhase(clock: 0, index: 0, count: 4), 0.0);
      expect(
        goldFleckPhase(clock: 0, index: 3, count: 4),
        closeTo(0.15, 1e-12),
      );
    });

    test('a single fleck has no offset', () {
      expect(
        goldFleckPhase(clock: 0.3, index: 0, count: 1),
        closeTo(0.3 * 10 % 1.0, 1e-9),
      );
    });

    test('no fleck count does not divide by zero', () {
      expect(goldFleckPhase(clock: 0.5, index: 0, count: 0), 0.0);
    });

    test('one FLOAT cycle is ten fleck cycles — `flecksPerFloatCycle`', () {
      // Retitled. The old name said "ten cycles of the float clock is one fleck
      // cycle", which is inverted by a factor of ten in each direction: ten
      // float cycles is *one hundred* fleck cycles, and what the code actually
      // does is the other way round — one float cycle contains ten fleck cycles,
      // because the fleck cycle is a tenth of the float clock.
      expect(
        goldFleckPhase(clock: 0.1, index: 0, count: 1),
        closeTo(0.0, 1e-9),
        reason:
            'a tenth of the float clock is one whole fleck cycle, so phase 0',
      );
      expect(
        goldFleckPhase(clock: 0.2, index: 0, count: 1),
        closeTo(0.0, 1e-9),
        reason: 'two whole fleck cycles, so phase 0 again',
      );
      expect(
        goldFleckPhase(clock: 0.15, index: 0, count: 1),
        closeTo(0.5, 1e-9),
        reason: 'half a fleck cycle from the start of the second one',
      );
      expect(
        goldFleckPhase(clock: 1.0, index: 0, count: 1),
        closeTo(0.0, 1e-9),
        reason: 'ten fleck cycles in one float cycle — back to the start',
      );
    });
  });

  group('GoldFlecks has no controller of its own', () {
    testWidgets('is a StatelessWidget', (WidgetTester tester) async {
      await tester.pumpWidget(_flecks());
      expect(tester.widget(find.byType(GoldFlecks)), isA<StatelessWidget>());
    });

    testWidgets('and adds no fourth ticker to the app\'s three', (
      WidgetTester tester,
    ) async {
      // The whole point of borrowing the float clock. The old version of this
      // test was `expect(tester.takeException(), isNull)` under the name "the app
      // still runs only three tickers" — vacuous, because a fourth ticker that
      // ran cleanly would also throw nothing.
      //
      // `SchedulerBinding.transientCallbackCount` is the witness: a running
      // `Ticker` registers exactly one transient callback per frame for itself,
      // so three running clocks read `3`. That makes the claim falsifiable in the
      // way the name promises — a `GoldFlecks` that spun up its own
      // `AnimationController` would push this to 4.
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_flecks());
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        SchedulerBinding.instance.transientCallbackCount,
        3,
        reason:
            'the three shared ambient clocks and nothing else — a fourth would '
            'be a per-fleck controller, which is what §13.2 collapses away',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the painter', () {
    testWidgets('draws, and the pixels move as the clock runs', (
      WidgetTester tester,
    ) async {
      // THE D1 SHAPE, IN A SECOND WIDGET. The painter used to be handed a
      // `clock` snapshot taken in `build`, so it painted once and never again
      // while the background behind it drifted — a motionless sparkle. The fix is
      // `CustomPainter(repaint: motion.repaint)` plus reading the clock at paint
      // time, and this assertion is what says it worked.
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_flecks());
      await tester.pump();
      final List<int> before = await _pixels(tester);

      await tester.pump(const Duration(milliseconds: 500));
      final List<int> after = await _pixels(tester);

      expect(before.toString(), isNot(after.toString()));
    });

    testWidgets('a stopped clock freezes them', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_flecks(animationsEnabled: false));
      await tester.pump();
      final List<int> before = await _pixels(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(before.toString(), (await _pixels(tester)).toString());
    });

    testWidgets('dense adds something', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_flecks(animationsEnabled: false));
      await tester.pump();
      final List<int> sparse = await _pixels(tester);

      await tester.pumpWidget(_flecks(animationsEnabled: false, dense: true));
      await tester.pump();
      expect(sparse.toString(), isNot((await _pixels(tester)).toString()));
    });

    testWidgets('moving the offsets moves the pixels', (
      WidgetTester tester,
    ) async {
      // The real observable for `shouldRepaint`: a repainted painter puts the
      // sparkle somewhere else, and a painter that is not repainted leaves the
      // pixels where they were. Comparing `CustomPaint` identity across two
      // `pumpWidget` calls proves nothing — a whole new tree means a new painter
      // whether or not `shouldRepaint` ever runs.
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _flecks(
          offsets: const <Offset>[Offset(60, 60)],
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      final List<int> before = await _pixels(tester);

      await tester.pumpWidget(
        _flecks(
          offsets: const <Offset>[Offset(240, 30)],
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      expect(
        before.toString(),
        isNot((await _pixels(tester)).toString()),
        reason:
            'the flecks are frozen, so the only thing that can move them is '
            'the offsets',
      );
    });

    testWidgets('the ink is exactly the prototype\'s 5px dot', (
      WidgetTester tester,
    ) async {
      // Renamed and tightened. The old name claimed this pinned both
      // `kFleckRadius` and `kFleckGlow`, and asserted only the bracket
      // `5 ≤ maxX - minX < 20` — which admits any glow radius from 2.5px to
      // 10px, i.e. anything.
      //
      // What is actually true, and measured: the painted bounds are **exactly
      // 6x6** with `kFleckGlow` at 10 and at 40, because the glow's shader is
      // sampled inside `drawCircle(centre, kFleckRadius, …)` and so never reaches
      // a pixel outside the dot — `createShader`'s rectangle is a coordinate
      // space, not a clip. The 6 is the 5px dot plus one column of antialiasing
      // on each side, and that pins `kFleckRadius` to 2.5 within half a pixel.
      //
      // `kFleckGlow` is pinned as a constant by the constants test and has no
      // design-visible effect as the painter is written; `gold_flecks.dart` says
      // so where the shader is built.
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _flecks(
          offsets: const <Offset>[Offset(190, 60)],
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      final List<int> rgba = await _pixels(tester);
      const int width = 380;
      const int height = 120;
      int minX = width, maxX = -1, minY = height, maxY = -1, inked = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (_alphaAt(rgba, width, x, y) == 0) continue;
          inked++;
          minX = minX > x ? x : minX;
          maxX = maxX < x ? x : maxX;
          minY = minY > y ? y : minY;
          maxY = maxY < y ? y : maxY;
        }
      }
      expect(inked, greaterThan(0), reason: 'nothing was painted at all');
      expect(
        maxX - minX + 1,
        6,
        reason:
            'the 5px dot plus one antialiased column each side — a radius of 5 '
            'would measure 12 here and a radius of 1.25 would measure 4',
      );
      expect(maxY - minY + 1, 6, reason: 'a circle, so as tall as it is wide');
      expect(
        (minX + maxX) / 2,
        closeTo(190, 0.5),
        reason: 'centred on the offset',
      );
      expect((minY + maxY) / 2, closeTo(60, 0.5));
    });

    testWidgets('an empty fleck list paints nothing and does not divide', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flecks(offsets: const <Offset>[]));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('flecks outside the box are still painted', (
      WidgetTester tester,
    ) async {
      // `QuizScreen.tsx:94` puts two at x = 356…362 inside a card that is ~350
      // wide, i.e. deliberately off the right edge. Clipping them would lose two
      // of the prototype's four.
      //
      // The old version asserted `find.byType(CustomPaint) findsWidgets` plus
      // `takeException() == null`, which cannot fail on that: `CustomPaint` is
      // in the tree whether or not anything is drawn, and clipping raises
      // nothing. Measured: clipping the painter to the card width left it green.
      //
      // What is observable is ink at the off-card coordinates, so this reads the
      // pixels there.
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _flecks(
          // One extra fleck in the middle, purely as the control below: all four
          // of the prototype's own offsets sit outside a 380px box on one axis
          // (`x = -10, -15` are past the left edge entirely, `356, 362` are past
          // the ~350px card), so there is no in-card fleck to compare against.
          offsets: const <Offset>[
            Offset(-10, 12),
            Offset(-15, 36),
            Offset(356, 8),
            Offset(362, 30),
            Offset(190, 60),
          ],
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      final List<int> rgba = await _pixels(tester);

      for (final Offset offCard in const <Offset>[
        Offset(356, 8),
        Offset(362, 30),
      ]) {
        // A 5px dot centred here covers roughly x ± 2, y ± 2; sample the column
        // at the fleck's own x so a fleck parked exactly on it cannot miss.
        final int x = offCard.dx.round();
        final int y = offCard.dy.round();
        int inked = 0;
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            if (_alphaAt(rgba, 380, x + dx, y + dy) > 0) inked++;
          }
        }
        expect(
          inked,
          greaterThan(0),
          reason:
              'no ink within 2px of the fleck at ($x, $y) — a clip to the ~350px '
              'option card would drop it, and that is the bug this names',
        );
      }

      // The control: a fleck in the middle of the box, so the loop above cannot
      // pass on a painter that drew nothing anywhere.
      int insideInk = 0;
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          if (_alphaAt(rgba, 380, 190 + dx, 60 + dy) > 0) insideInk++;
        }
      }
      expect(
        insideInk,
        greaterThan(0),
        reason: 'the control fleck at (190, 60)',
      );
    });
  });

  group('reduced motion — §14', () {
    testWidgets('disableAnimations freezes the flecks at rest', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_flecks(disableAnimations: true));
      await tester.pump();
      final List<int> before = await _pixels(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(
        before.toString(),
        (await _pixels(tester)).toString(),
        reason: 'a reader who asked for reduced motion gets a still sparkle',
      );
    });

    testWidgets('and the rest state is the un-offset, fully opaque fleck', (
      WidgetTester tester,
    ) async {
      // The fleck's "end state" in CSS terms is 9px up at 0.35 alpha — a
      // mid-transition pose, not a resting one. §14's rule is about transitions
      // reaching their target; an ambient loop has no target, so the frozen state
      // is the neutral one. See the implementation note on the clock.
      tester.view.physicalSize = const Size(380, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_flecks(disableAnimations: true));
      await tester.pump();
      final List<int> reduced = await _pixels(tester);

      await tester.pumpWidget(_flecks(animationsEnabled: false));
      await tester.pump();
      expect(reduced.toString(), (await _pixels(tester)).toString());
    });
  });

  group('semantics', () {
    testWidgets('is excluded outright — the flecks say nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flecks());
      expect(
        find.descendant(
          of: find.byType(GoldFlecks),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('never takes a pointer', (WidgetTester tester) async {
      await tester.pumpWidget(_flecks());
      expect(
        find.descendant(
          of: find.byType(GoldFlecks),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tap passes straight through', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        evaAmbientHarness(
          child: SizedBox(
            width: 380,
            height: 120,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => taps++,
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
                const Positioned.fill(child: GoldFlecks(offsets: _quizFlecks)),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(GoldFlecks)));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('theming', () {
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      testWidgets('goldens on $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(380, 120);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // NOT settled, and the comment used to claim it was. It passed
        // `animationsEnabled: false` — the default `true` — while saying "so the
        // capture is of a settled state". The golden is captured at a *moving*
        // phase and is still reproducible, because `AnimationController.value`
        // is a pure function of elapsed time and `pump(400ms)` puts the clock at
        // exactly one value. What would not be reproducible is a capture with no
        // fixed duration at all.
        await tester.pumpWidget(_flecks(theme: theme));
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(
          find.byType(CustomPaint).first,
          matchesGoldenFile('goldens/gold_flecks_$label.png'),
        );
      });
    }
  });
}
