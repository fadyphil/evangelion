import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mounted aurora — the redesign's ambient layer.
///
/// ## THE THREE THINGS THIS FILE PROVES
///
/// 1. **The aurora paints** where the reader's choices are published, and the
///    **fallback** paints everywhere else.
/// 2. **The painter is long-lived**, so the shader's uniform buffer is
///    allocated once and not once a frame.
/// 3. **The reader's choices reach the shader**, through the scene.
void main() {
  /// The aurora's painter, or null when the fallback is painting.
  LumenCanvas? lumenPainter(WidgetTester tester) {
    for (final CustomPaint paint in tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    )) {
      final CustomPainter? painter = paint.painter;
      if (painter is LumenCanvas) return painter;
    }
    return null;
  }

  Widget harness(
    Widget child, {
    LumenPreferences? preferences,
    bool publish = true,
    bool disableAnimations = false,
    ThemeData? theme,
  }) => NeuralMotionScope(
    animationsEnabled: !disableAnimations,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? EvaThemeDark.theme,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: publish
              ? LumenPreferencesScope(
                  preferences: preferences ?? const LumenPreferences(),
                  child: child,
                )
              : child,
        ),
      ),
    ),
  );

  setUpAll(() async {
    // The program is a **process-wide** memo (`LumenProgram.loaded`), so one
    // load serves the whole file — and it is the only way the aurora can
    // paint, because the ambient reads the memo rather than awaiting.
    await LumenProgram.load();
  });

  group('the aurora paints', () {
    testWidgets('where the reader\'s choices are published', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const LumenBackground(variant: NeuralVariant.home)),
      );
      await tester.pump();
      expect(lumenPainter(tester), isNotNull);
      expect(find.byType(NeuralBackground), findsNothing);
    });

    testWidgets('and it fills the page', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(const LumenBackground(variant: NeuralVariant.home)),
      );
      await tester.pump();
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(LumenBackground),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.painter, isA<LumenCanvas>());
      expect(paint.isComplex, isTrue);
      expect(paint.willChange, isTrue);
    });
  });

  group('the fallback paints', () {
    testWidgets('when no choices are published', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          publish: false,
        ),
      );
      await tester.pump();
      expect(lumenPainter(tester), isNull);
      expect(find.byType(NeuralBackground), findsOneWidget);
    });

    testWidgets('when the reader turns the aurora off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          preferences: const LumenPreferences(enabled: false),
        ),
      );
      await tester.pump();
      expect(lumenPainter(tester), isNull);
      expect(find.byType(NeuralBackground), findsOneWidget);
    });

    testWidgets('and when reduced motion drops the tier to `low`', (
      WidgetTester tester,
    ) async {
      // `NeuralTiers.resolve` makes reduced motion the **last word**: it
      // returns `low` whatever the size says, and `low` maps to `off`.
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(lumenPainter(tester), isNull);
      expect(find.byType(NeuralBackground), findsOneWidget);
    });
  });

  group('the painter is long-lived', () {
    testWidgets('the shader is allocated once, however many frames paint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const LumenBackground(variant: NeuralVariant.home)),
      );
      await tester.pump();
      final LumenCanvas canvas = lumenPainter(tester)!;

      await tester.pump(const Duration(milliseconds: 16));
      final ui.FragmentShader? first = canvas.debugShader;
      expect(first, isNotNull, reason: 'the first paint allocates it');

      for (int frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        identical(canvas.debugShader, first),
        isTrue,
        reason:
            'twenty frames later and the shader is the same instance — a '
            'painter rebuilt per frame would have allocated twenty buffers',
      );
    });

    testWidgets('and the painter instance itself does not change', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const LumenBackground(variant: NeuralVariant.home)),
      );
      await tester.pump();
      final LumenCanvas canvas = lumenPainter(tester)!;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(lumenPainter(tester), canvas), isTrue);
    });
  });

  group('the reader\'s choices reach the shader', () {
    testWidgets('through the scene', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          preferences: const LumenPreferences(
            reach: 110,
            touchGlow: 100,
            rayCombing: false,
            whiteCores: false,
            dotVeil: true,
            shape: CurtainShape.sides,
          ),
        ),
      );
      await tester.pump();
      final LumenUniforms table = lumenPainter(tester)!
          .resolveAt(const Size(390, 844));
      expect(table.spread, closeTo(1.1, 1e-12));
      expect(table.pointerIntensity, closeTo(0.6, 1e-12));
      expect(table.rays, 0);
      expect(table.white, 0);
      expect(table.dots, 1);
      expect(table.shape, 2);
    });

    testWidgets('and a change to one of them moves the table', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          preferences: const LumenPreferences(),
        ),
      );
      await tester.pump();
      expect(
        lumenPainter(tester)!.resolveAt(const Size(390, 844)).spread,
        closeTo(0.42, 1e-12),
      );

      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          preferences: const LumenPreferences(reach: 60),
        ),
      );
      await tester.pump();
      expect(
        lumenPainter(tester)!.resolveAt(const Size(390, 844)).spread,
        closeTo(0.6, 1e-12),
      );
    });
  });

  group('the scene is app-global', () {
    testWidgets('two mounted backgrounds share one scene', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const Column(
            children: <Widget>[
              LumenBackground(variant: NeuralVariant.home),
              LumenBackground(variant: NeuralVariant.quiz),
            ],
          ),
        ),
      );
      await tester.pump();
      final List<CustomPaint> paints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((CustomPaint p) => p.painter is LumenCanvas)
          .toList();
      expect(paints, hasLength(2));
      final LumenUniformSource first =
          (paints.first.painter! as LumenCanvas).source;
      final LumenUniformSource second =
          (paints.last.painter! as LumenCanvas).source;
      expect(identical(first, second), isTrue);
    });

    testWidgets('and the aurora\'s state survives a screen change', (
      WidgetTester tester,
    ) async {
      // The prototype's eased values live in one closure behind one canvas
      // (`eva/redesign.html:881-912`), so they survive a screen change.
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          preferences: const LumenPreferences(hue: 12),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final double easing = lumenPainter(tester)!
          .resolveAt(const Size(390, 844))
          .hue
          .r;

      // A different screen, the same app.
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.quiz),
          preferences: const LumenPreferences(hue: 12),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final double after = lumenPainter(tester)!
          .resolveAt(const Size(390, 844))
          .hue
          .r;
      expect(after, closeTo(easing, 1e-12));
    });
  });

  group('daylight', () {
    // The prototype MULTIPLIES its canvas into the light background:
    // `eva/redesign.html:60` — `.screen[data-mode=light] canvas{mix-blend-mode:multiply}`.
    //
    // Without that, the shader's daylight arm paints an **opaque white
    // sheet**: `shaders/lumen.frag:116` is
    // `col=mix(emit, vec3(1.0)-0.55*em, u_light)`, and with `u_light=1` and
    // no band (`emit=0`) that is `vec3(1.0)` — white, alpha 1. The reader's
    // light canvas would be erased, and every card that distinguishes
    // `canvas` from `surface` would lose the ground it stands on.
    //
    // So the client's daylight aurora is multiplied by the canvas colour,
    // which is what the prototype's `multiply` amounts to: the backdrop
    // under an opaque canvas is the canvas colour.
    testWidgets('the light canvas survives the aurora', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const LumenBackground(variant: NeuralVariant.home),
          theme: EvaThemeLight.theme,
        ),
      );
      await tester.pump();

      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(
            find.descendant(
              of: find.byType(LumenBackground),
              matching: find.byType(RepaintBoundary),
            ),
          );
      final Size size = boundary.size;
      final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
        final ui.Image image = boundary.toImageSync();
        final ByteData? data = await image.toByteData();
        image.dispose();
        if (data == null) {
          throw StateError('the ambient layer produced no pixels');
        }
        return data.buffer.asUint8List();
      });
      expect(bytes, isNotNull);

      // The **bottom** of the screen: the `top` shape's band is at the top
      // (`shaders/lumen.frag:74` — `d=(halfH-0.05)-uv.y` with `uv.y` +Y up),
      // so the bottom carries no band and is the canvas.
      final int offset =
          ((size.height - 5).round() * size.width.round() +
              (size.width ~/ 2).round()) *
          4;
      expect(
        bytes![offset],
        lessThan(250),
        reason:
            'the light canvas is #F0EEFF (240), and the aurora must multiply '
            'into it rather than paint white over it — the prototype\'s '
            '`mix-blend-mode:multiply` (`eva/redesign.html:60`)',
      );
    });
  });

  group('the pointer', () {
    // The pointer is tracked by the **screen root** — `NeuralScaffold` — and
    // not by the background, because the prototype tracks it on `#screen`
    // (`eva/redesign.html:916`) and a listener in the background layer would
    // only see the moves the content above it does not absorb.
    Widget scaffold() => const NeuralScaffold(
      variant: NeuralVariant.home,
      child: SizedBox.shrink(),
    );

    testWidgets('a hover puts the glow where the pointer is', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(scaffold()));
      await tester.pump();
      final LumenScene scene = lumenPainter(tester)!.source as LumenScene;
      expect(scene.pointer.value, kLumenNoPointer);

      final Offset centre = tester.getCenter(find.byType(NeuralScaffold));
      await tester.sendEventToBinding(
        PointerHoverEvent(pointer: 1, position: centre),
      );
      await tester.pump();
      expect(scene.pointer.value.dx, closeTo(0, 1e-6));
      expect(scene.pointer.value.dy, closeTo(0, 1e-6));
    });

    testWidgets('and a drag moves it too', (WidgetTester tester) async {
      // `onPointerMove` as well as `onPointerHover`: a touch is a drag, and
      // the Workshop's control is called "Touch glow".
      await tester.pumpWidget(harness(scaffold()));
      await tester.pump();
      final LumenScene scene = lumenPainter(tester)!.source as LumenScene;

      final TestGesture gesture = await tester.startGesture(
        const Offset(100, 300),
      );
      await gesture.moveTo(const Offset(250, 500));
      await tester.pump();
      // The normalisation is the shader's own — centred and divided by the
      // **short** side (`eva/redesign.html:918-919`) — so the expectation is
      // computed from the surface the test is running on rather than from a
      // hard-coded one.
      final Size size = tester.getSize(find.byType(NeuralScaffold));
      expect(
        scene.pointer.value.dx,
        closeTo((250 - size.width / 2) / size.shortestSide, 1e-6),
      );
      expect(
        scene.pointer.value.dy,
        closeTo((size.height / 2 - 500) / size.shortestSide, 1e-6),
      );
    });

    testWidgets('and a finger lifting puts it back', (
      WidgetTester tester,
    ) async {
      // The prototype's `pointerleave` (`eva/redesign.html:921`) puts the
      // pointer back at `(-10, -10)`. Flutter's `Listener` has no
      // `onPointerExit` on this SDK, and the **touch** case — a finger
      // lifting — is an `onPointerUp`.
      await tester.pumpWidget(harness(scaffold()));
      await tester.pump();
      final LumenScene scene = lumenPainter(tester)!.source as LumenScene;

      final TestGesture gesture = await tester.startGesture(
        const Offset(100, 300),
      );
      await gesture.moveTo(const Offset(250, 500));
      await tester.pump();
      expect(scene.pointer.value, isNot(kLumenNoPointer));

      await gesture.up();
      await tester.pump();
      expect(scene.pointer.value, kLumenNoPointer);
    });
  });
}
