import 'dart:typed_data';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// One frame of elapsed time at 60fps, for counting what a frame does.
const Duration kFrame = Duration(milliseconds: 16);

Widget _probe({
  NeuralVariant variant = NeuralVariant.home,
  NeuralTier? tier,
  ThemeData? theme,
  bool disableAnimations = false,
}) => evaAmbientHarness(
  theme: theme,
  disableAnimations: disableAnimations,
  child: ambientBackground(variant: variant, tier: tier),
);

/// The byte at [index] of an RGBA buffer.
int _channel(Uint8List rgba, int pixel, int channel) =>
    rgba[(pixel * 4) + channel];

void main() {
  group('structure', () {
    testWidgets('is a RepaintBoundary around a Listener around the paint', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());

      expect(
        find.byType(NeuralBackground),
        findsOneWidget,
        reason: 'the background is a widget, not a Scaffold body',
      );
      expect(_boundaryFinder(tester), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NeuralBackground),
          matching: find.byType(Listener),
        ),
        findsOneWidget,
        reason:
            'parallax needs a pointer source. Scoped to the background '
            'because MaterialApp brings listeners of its own.',
      );
    });

    testWidgets('is not a stateful widget and holds no setState', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      final NeuralBackground background = tester.widget(
        find.byType(NeuralBackground),
      );
      expect(background, isA<StatelessWidget>());
      expect(background, isNot(isA<StatefulWidget>()));
    });

    testWidgets('paints inside the given box rather than sizing itself', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      expect(
        tester.getSize(find.byType(NeuralBackground)),
        kAmbientSurface,
        reason:
            'a background must fill whatever box it is given and never '
            'influence the page layout',
      );
    });
  });

  group('D1 — no per-frame rebuild', () {
    testWidgets('NeuralBackground.build does not re-run across 60 frames', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      final Widget before = backgroundBoundaryInstance(tester);

      for (int frame = 0; frame < 60; frame++) {
        await tester.pump(kFrame);
      }

      // THE REBUILD COUNT. `backgroundBoundaryInstance` is the widget object
      // `NeuralBackground.build` returned, so it is re-created only if `build`
      // ran again. Sixty frames of animation, zero rebuilds.
      expect(
        identical(before, backgroundBoundaryInstance(tester)),
        isTrue,
        reason: '60 animation frames must not re-enter NeuralBackground.build',
      );
    });

    testWidgets('the page above the background is untouched too', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(
        evaAmbientHarness(
          child: const Stack(
            children: <Widget>[
              Positioned.fill(
                child: NeuralBackground(variant: NeuralVariant.home),
              ),
              Positioned(top: 100, left: 20, child: Text('Today\'s reading')),
            ],
          ),
        ),
      );
      final Element textElement = tester.element(find.text('Today\'s reading'));
      for (int frame = 0; frame < 30; frame++) {
        await tester.pump(kFrame);
      }
      expect(
        identical(textElement, tester.element(find.text('Today\'s reading'))),
        isTrue,
      );
    });

    testWidgets('but the ListenableBuilder DOES rebuild — that is §13.1', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      final CustomPaint before = backgroundPaintInstance(tester);

      await tester.pump(kFrame);

      expect(
        identical(before, backgroundPaintInstance(tester)),
        isFalse,
        reason:
            '§13.1 puts a ListenableBuilder in here and it must actually '
            'run; a builder that never rebuilds is the D1 defect wearing a '
            'different hat',
      );
    });

    testWidgets('the painter is a single object per rebuild, not a new tree', (
      WidgetTester tester,
    ) async {
      // `CustomPainter.repaint` is `@protected`, so the subscription cannot be
      // read from here — the pixel tests above are the proof that the repaint
      // path is live. What this pins is the cheaper half: exactly one
      // `CustomPaint` in the subtree, so the ListenableBuilder is rebuilding a
      // painter and not a scaffold.
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      await tester.pump(kFrame);
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(backgroundPaintInstance(tester).painter, isNotNull);
    });

    testWidgets('and that one CustomPaint sizes itself to nothing', (
      WidgetTester tester,
    ) async {
      // Split out from the count above because it is a different claim.
      //
      // `CustomPaint.size` is a **non-nullable field that defaults to
      // `Size.zero`** and that `NeuralBackground` never sets, so this asserts a
      // framework default, not a decision this widget made. It is still worth
      // pinning: `SizedBox(size: ...)` here would make the painter's box come
      // from a value that nothing else in the subtree constrains, and a
      // background that then painted at its own size instead of filling the page
      // would leave every other assertion in this file green.
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      await tester.pump(kFrame);
      expect(backgroundPaintInstance(tester).size, Size.zero);
    });
  });

  group('D1 — a repaint genuinely happens', () {
    testWidgets('the pixels change when the ticker advances', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      await tester.pump(kFrame);
      final Uint8List before = await backgroundPixels(tester);

      await tester.pump(const Duration(seconds: 3));
      final Uint8List after = await backgroundPixels(tester);

      expect(before.length, after.length, reason: 'same surface, same layer');
      expect(
        List<int>.generate(
          before.length,
          (int i) => i,
        ).where((int i) => before[i] != after[i]),
        isNotEmpty,
        reason:
            'advancing the ticker must repaint the background; a painter '
            'that paints once and never again is the reference '
            "implementation's actual behaviour",
      );
    });

    testWidgets('and it changes on every single frame, not occasionally', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe());
      final List<Uint8List> samples = <Uint8List>[];
      for (int frame = 0; frame < 6; frame++) {
        samples.add(await backgroundPixels(tester));
        await tester.pump(kFrame);
      }
      for (int i = 1; i < samples.length; i++) {
        expect(
          samples[i].toString() == samples[i - 1].toString(),
          isFalse,
          reason: 'frame $i was identical to frame ${i - 1}',
        );
      }
    });

    testWidgets('a stopped background does NOT change', (
      WidgetTester tester,
    ) async {
      // The negative control for the test above: with the clocks off, the pixels
      // must be identical. Without it, "the pixels differ" could be satisfied by
      // anything that repaints — a theme change, a cursor, an antialiasing
      // wobble.
      useAmbientSurface(tester);
      await tester.pumpWidget(
        evaAmbientHarness(
          animationsEnabled: false,
          child: ambientBackground(variant: NeuralVariant.home),
        ),
      );
      await tester.pump(kFrame);
      final Uint8List before = await backgroundPixels(tester);
      await tester.pump(const Duration(seconds: 3));
      final Uint8List after = await backgroundPixels(tester);
      expect(before.toString(), after.toString());
    });

    testWidgets('the pointer moves the orbs — parallax is live', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      late EvaNeuralMotion motion;
      await tester.pumpWidget(
        evaAmbientHarness(
          child: Builder(
            builder: (BuildContext context) {
              motion = NeuralMotionScope.of(context);
              return ambientBackground(variant: NeuralVariant.home);
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        motion.pointer.value,
        Offset.zero,
        reason: 'nothing has moved the pointer yet',
      );

      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: const Offset(195, 422));
      await gesture.moveTo(const Offset(380, 800));
      await tester.pump(kFrame);

      // The bundle is read directly. An earlier version of this test compared
      // pixels before and after the move, which passed even with `onPointerMove`
      // never called — the `pump(kFrame)` in between let the background animate,
      // so the pixels differed for a reason that had nothing to do with the
      // pointer. A test that cannot fail on the bug it names is not a test.
      expect(motion.pointer.value, isNot(Offset.zero));
      expect(
        motion.pointer.value.dx,
        closeTo(
          pointerOffsetFor(
            size: kAmbientSurface,
            local: const Offset(380, 800),
          ).dx,
          1e-6,
        ),
      );
      await gesture.removePointer();
    });

    testWidgets(
      'and the pointer is clamped to the the prototype box / ±12 box',
      (WidgetTester tester) async {
        useAmbientSurface(tester);
        late EvaNeuralMotion motion;
        await tester.pumpWidget(
          evaAmbientHarness(
            child: Builder(
              builder: (BuildContext context) {
                motion = NeuralMotionScope.of(context);
                return ambientBackground(variant: NeuralVariant.home);
              },
            ),
          ),
        );
        final TestGesture gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(const Offset(10000, 10000));
        await tester.pump(kFrame);
        expect(motion.pointer.value.dx, lessThanOrEqualTo(kPointerSpanX / 2));
        expect(motion.pointer.value.dy, lessThanOrEqualTo(kPointerSpanY / 2));
        await gesture.removePointer();
      },
    );
  });

  group('D5 — NeuralTier.low renders zero orb layers', () {
    testWidgets('the whole layer is the canvas colour', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(tier: NeuralTier.low));
      await tester.pump(const Duration(seconds: 2));

      final Uint8List rgba = await backgroundPixels(tester);
      final Color canvas = const EvaColors.dark().canvas;
      const int pixelCount = 390 * 844;
      expect(rgba.length, pixelCount * 4);

      int painted = 0;
      for (int pixel = 0; pixel < pixelCount; pixel++) {
        final bool matches =
            _channel(rgba, pixel, 0) == _red(canvas) &&
            _channel(rgba, pixel, 1) == _green(canvas) &&
            _channel(rgba, pixel, 2) == _blue(canvas) &&
            _channel(rgba, pixel, 3) == 0xFF;
        if (!matches) painted++;
      }
      expect(
        painted,
        0,
        reason:
            '`low` means no orbs and no aurora — every pixel must be the '
            'canvas, or something is still drawing',
      );
    });

    testWidgets('zero orb layers on every variant', (
      WidgetTester tester,
    ) async {
      for (final NeuralVariant variant in NeuralVariant.values) {
        useAmbientSurface(tester);
        await tester.pumpWidget(_probe(variant: variant, tier: NeuralTier.low));
        await tester.pump(const Duration(seconds: 1));
        final Uint8List rgba = await backgroundPixels(tester);
        final Color canvas = const EvaColors.dark().canvas;
        int painted = 0;
        for (
          int pixel = 0;
          pixel < kAmbientSurface.width * kAmbientSurface.height;
          pixel++
        ) {
          final bool matches =
              _channel(rgba, pixel, 0) == _red(canvas) &&
              _channel(rgba, pixel, 1) == _green(canvas) &&
              _channel(rgba, pixel, 2) == _blue(canvas) &&
              _channel(rgba, pixel, 3) == 0xFF;
          if (!matches) painted++;
        }
        expect(
          painted,
          0,
          reason:
              '${variant.name} at low painted over $painted pixels; `low` is the '
              'canvas and nothing else. The assertion is per-pixel rather than '
              '"at most four distinct byte values", because a buffer of nothing '
              'but one repeated byte satisfies a distinct-count check while '
              'painting no canvas at all — moving the `tier == low` early return '
              'above `canvas.drawRect` left that version green.',
        );
      }
    });

    testWidgets('a low background never repaints on a frame', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(tier: NeuralTier.low));
      await tester.pump(kFrame);
      final Uint8List before = await backgroundPixels(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(before.toString(), (await backgroundPixels(tester)).toString());
    });

    testWidgets('mid draws more than low does', (WidgetTester tester) async {
      // Proves `low` is not simply "the widget renders nothing".
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(tier: NeuralTier.low));
      await tester.pump(const Duration(seconds: 2));
      final Uint8List low = await backgroundPixels(tester);

      await tester.pumpWidget(_probe(tier: NeuralTier.mid));
      await tester.pump(const Duration(seconds: 2));
      final Uint8List mid = await backgroundPixels(tester);

      expect(low.toString(), isNot(mid.toString()));
    });

    testWidgets('`low` does not ask the framework to keep the layer alive', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(tier: NeuralTier.low));
      expect(
        backgroundPaintInstance(tester).willChange,
        isFalse,
        reason: 'nothing about a static canvas is about to change',
      );

      await tester.pumpWidget(_probe(tier: NeuralTier.high));
      expect(backgroundPaintInstance(tester).willChange, isTrue);
    });
  });

  group('D5 — reduced motion', () {
    testWidgets('disableAnimations collapses the background to the canvas', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(disableAnimations: true));
      await tester.pump(const Duration(seconds: 2));
      final Uint8List rgba = await backgroundPixels(tester);
      final Color canvas = const EvaColors.dark().canvas;
      for (int pixel = 0; pixel < 390 * 844; pixel++) {
        expect(
          _channel(rgba, pixel, 0) == _red(canvas) &&
              _channel(rgba, pixel, 1) == _green(canvas) &&
              _channel(rgba, pixel, 2) == _blue(canvas),
          isTrue,
          reason: 'pixel $pixel is not the canvas',
        );
      }
    });

    testWidgets('an explicit high tier cannot override reduced motion', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(
        _probe(tier: NeuralTier.high, disableAnimations: true),
      );
      final Uint8List rgba = await backgroundPixels(tester);
      expect(_channel(rgba, 0, 0), _red(const EvaColors.dark().canvas));
      expect(_channel(rgba, 0, 1), _green(const EvaColors.dark().canvas));
      expect(_channel(rgba, 0, 2), _blue(const EvaColors.dark().canvas));
    });
  });

  group('D2 — the variants paint different things', () {
    testWidgets('settings does not paint the profile orbs', (
      WidgetTester tester,
    ) async {
      // The behavioural half of D2: the table says violet+cyan and the pixels
      // had better agree. The colour test in `neural_orbs_test.dart` proves the
      // table; this proves the table reaches the screen.
      useAmbientSurface(tester);
      await tester.pumpWidget(
        _probe(variant: NeuralVariant.settings, tier: NeuralTier.high),
      );
      await tester.pump(const Duration(seconds: 2));
      final Uint8List settings = await backgroundPixels(tester);

      await tester.pumpWidget(
        _probe(variant: NeuralVariant.login, tier: NeuralTier.high),
      );
      await tester.pump(const Duration(seconds: 2));
      final Uint8List login = await backgroundPixels(tester);

      // Login's first orb is #6C3FE8 and Settings' is also #6C3FE8, but the rest
      // of the composition differs, so the layers cannot be identical.
      expect(settings.toString(), isNot(login.toString()));
    });

    testWidgets('the reading arms differ from each other', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(
        _probe(variant: NeuralVariant.readingEn, tier: NeuralTier.high),
      );
      await tester.pump(const Duration(seconds: 2));
      final Uint8List en = await backgroundPixels(tester);

      await tester.pumpWidget(
        _probe(variant: NeuralVariant.readingAr, tier: NeuralTier.high),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(en.toString(), isNot((await backgroundPixels(tester)).toString()));
    });
  });

  group('theming', () {
    testWidgets('light mode paints the light aurora', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(
        _probe(theme: EvaThemeLight.theme, tier: NeuralTier.high),
      );
      await tester.pump(const Duration(seconds: 2));
      final Uint8List light = await backgroundPixels(tester);

      await tester.pumpWidget(
        _probe(theme: EvaThemeDark.theme, tier: NeuralTier.high),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        light.toString(),
        isNot((await backgroundPixels(tester)).toString()),
      );
    });

    testWidgets('changing the palette repaints the painter', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(theme: EvaThemeDark.theme));
      final CustomPaint before = backgroundPaintInstance(tester);
      await tester.pumpWidget(_probe(theme: EvaThemeLight.theme));
      expect(
        identical(before, backgroundPaintInstance(tester)),
        isFalse,
        reason: 'a new palette is a new EvaColors and must repaint',
      );
    });

    testWidgets('changing the variant repaints the painter', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(_probe(variant: NeuralVariant.login));
      final CustomPaint before = backgroundPaintInstance(tester);
      await tester.pumpWidget(_probe(variant: NeuralVariant.result));
      expect(identical(before, backgroundPaintInstance(tester)), isFalse);
    });
  });

  group('§13.1 — the seven goldens per theme', () {
    // 7 variants x 2 themes = 14. `NeuralTier.high` is passed explicitly so the
    // goldens do not silently change shape if the size thresholds are ever
    // retuned: a golden that captures "mid" today and "low" tomorrow is a
    // re-recorded image with no diff anyone reads.
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      for (final NeuralVariant variant in NeuralVariant.values) {
        testWidgets('NeuralBackground ${variant.name} on $label', (
          WidgetTester tester,
        ) async {
          useAmbientSurface(tester);
          await tester.pumpWidget(
            _probe(variant: variant, tier: NeuralTier.high, theme: theme),
          );
          await pumpAmbientPhase(tester, const Duration(seconds: 3));
          await expectLater(
            find.byType(NeuralBackground),
            matchesGoldenFile(
              'goldens/neural_background_${variant.name}_$label.png',
            ),
          );
        });
      }
    }
  });
}

/// The red / green / blue bytes of [color].
///
/// Read out of `toARGB32()` by hand rather than through `Color.red`, because
/// `toARGB32` packs **A**RRGGBB — `& 0xFF` on the whole word is the *blue*
/// channel, and getting that backwards makes a correct renderer look broken.
int _red(Color color) => (color.toARGB32() >> 16) & 0xFF;
int _green(Color color) => (color.toARGB32() >> 8) & 0xFF;
int _blue(Color color) => color.toARGB32() & 0xFF;

Finder _boundaryFinder(WidgetTester tester) => find.descendant(
  of: find.byType(NeuralBackground),
  matching: find.byType(RepaintBoundary),
);
