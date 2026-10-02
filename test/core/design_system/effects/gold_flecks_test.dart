import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    final ByteData data = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    image.dispose();
    return <int>[for (int i = 0; i < data.lengthInBytes; i++) data.getUint8(i)];
  });
  if ((bytes?.length ?? 0) == 0) {
    debugPrint('DEBUG: no bytes captured');
  } else {
    final int nonZero = bytes!.where((int b) => b != 0).length;
    debugPrint(
      'DEBUG: ${bytes.length} bytes, $nonZero non-zero, '
      'max=${bytes.reduce((int a, int b) => a > b ? a : b)}',
    );
  }
  return bytes ?? const <int>[];
}

void main() {
  group('the fleck constants are the prototype\'s', () {
    test('radius 2.5 from a 5px circle, glow reach 10px', () {
      // QuizScreen.tsx:15-16 — `width: 5, height: 5` and
      // `boxShadow: '0 0 10px #E8A33D'`.
      expect(kFleckRadius, 2.5);
      expect(kFleckGlow, 10.0);
    });

    test('travel 9px and opacity 0.85 to 0.35', () {
      // index.css:86-88.
      expect(kFleckTravel, 9.0);
      expect(kFleckOpacityHigh, 0.85);
      expect(kFleckOpacityLow, 0.35);
    });

    test('the cycle is 2s and the float clock is 20s, so ten fit in one', () {
      expect(EvaMotion.fleck, const Duration(seconds: 2));
      expect(kFloatPeriod, const Duration(seconds: 20));
      expect(GoldFlecks.flecksPerFloatCycle, 10);
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

    test('ten cycles of the float clock is one fleck cycle', () {
      expect(
        goldFleckPhase(clock: 0.1, index: 0, count: 1),
        closeTo(0.0, 1e-9),
      );
      expect(
        goldFleckPhase(clock: 0.2, index: 0, count: 1),
        closeTo(0.0, 1e-9),
      );
      expect(
        goldFleckPhase(clock: 0.15, index: 0, count: 1),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('GoldFlecks has no controller of its own', () {
    testWidgets('is a StatelessWidget', (WidgetTester tester) async {
      await tester.pumpWidget(_flecks());
      expect(tester.widget(find.byType(GoldFlecks)), isA<StatelessWidget>());
    });

    testWidgets('and the app still runs only three tickers', (
      WidgetTester tester,
    ) async {
      // The whole point of borrowing the float clock: no fourth `Ticker` for the
      // flecks. `tearDownAllTickersVerified` (implicit in testWidgets) would fail
      // this test if the painter or the widget started one.
      await tester.pumpWidget(_flecks());
      await tester.pump(const Duration(milliseconds: 100));
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

    testWidgets('the flecks rest exactly where they were told to', (
      WidgetTester tester,
    ) async {
      // One fleck, one offset, no animation: the painted bounds are the fleck's
      // radius plus its 10px glow, centred on the offset. This is what pins
      // `kFleckRadius` and `kFleckGlow` to the prototype's 5px dot and 10px
      // halo rather than to a plausible-looking number.
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
      int minX = width, maxX = -1, minY = height, maxY = -1;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (rgba[(y * width + x) * 4 + 3] <= 8) continue;
          minX = minX > x ? x : minX;
          maxX = maxX < x ? x : maxX;
          minY = minY > y ? y : minY;
          maxY = maxY < y ? y : maxY;
        }
      }
      expect(maxX, greaterThan(minX));
      expect((minX + maxX) / 2, closeTo(190, 1.0));
      expect((minY + maxY) / 2, closeTo(60, 1.0));
      // 2 * 10px of glow reach, and the glow's outer ring is below alpha 8 so the
      // measured extent is a little less than the full 20px.
      expect(maxX - minX, lessThan(20));
      expect(maxY - minY, lessThan(20));
      expect(
        maxX - minX,
        greaterThanOrEqualTo(5),
        reason: 'the solid 5px dot is always inside the halo',
      );
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
      await tester.pumpWidget(_flecks());
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
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

        // `animationsEnabled: false` so the capture is of a settled state — a
        // golden taken at a moving phase is only reproducible by accident.
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
