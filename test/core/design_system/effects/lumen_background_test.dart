import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The mounted aurora — the redesign's ambient layer.
///
/// ## THE FOUR THINGS THIS FILE PROVES
///
/// 1. **The aurora paints** where the reader's choices are published, and the
///    **fallback** paints everywhere else.
/// 2. **The painter is long-lived**, so the shader's uniform buffer is
///    allocated once and not once a frame.
/// 3. **The reader's choices reach the shader**, through the scene.
/// 4. **The fallback is the flat canvas**, pixel for pixel — which is the
///    prototype's own screen root (`eva/redesign.html:46`), not a degraded
///    aurora.
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
      await tester.pumpWidget(harness(const LumenBackground()));
      await tester.pump();
      expect(lumenPainter(tester), isNotNull);
      // The two shapes are **exclusive**: the aurora paints *instead of* the
      // flat canvas, never on top of it. The assertion here used to be that
      // the legacy painter was absent from the tree; the legacy painter is
      // gone with the orbs, and this is the claim that replaced it.
      expect(
        find.descendant(
          of: find.byType(LumenBackground),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('and it fills the page', (WidgetTester tester) async {
      await tester.pumpWidget(harness(const LumenBackground()));
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
      await tester.pumpWidget(harness(const LumenBackground(), publish: false));
      await tester.pump();
      expect(lumenPainter(tester), isNull);
      expect(find.byType(LumenBackground), findsOneWidget);
    });

    testWidgets('when the reader turns the aurora off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const LumenBackground(),
          preferences: const LumenPreferences(enabled: false),
        ),
      );
      await tester.pump();
      expect(lumenPainter(tester), isNull);
      expect(find.byType(LumenBackground), findsOneWidget);
    });

    testWidgets('and when reduced motion drops the tier to `off`', (
      WidgetTester tester,
    ) async {
      // `LumenTiers.resolve` makes reduced motion the **last word**: it
      // returns `off` whatever the size says and whatever the override says.
      await tester.pumpWidget(
        harness(const LumenBackground(), disableAnimations: true),
      );
      await tester.pump();
      expect(lumenPainter(tester), isNull);
      expect(find.byType(LumenBackground), findsOneWidget);
    });
  });

  group('the flat canvas, pixel for pixel', () {
    // ## THE FALLBACK IS NOT A DEGRADED AURORA — IT IS THE PROTOTYPE'S OWN
    //
    // `eva/redesign.html:46` gives every screen **one** canvas, and the
    // superseded prototype did the same thing: its screen root was
    // `background: T.canvas` and the layer above it — the orb container —
    // declared no background of its own. The old
    // design's per-screen orb groups stood in for that fill and are gone, so
    // what is left when the aurora does not paint is the fill itself — the
    // design, not a consolation prize.
    //
    // These are the pixel-level assertions the old background's suite carried
    // and this file inherits. The old subject was `NeuralTier.low`; the new
    // subject is `LumenShaderTier.off`, and the behaviour is identical: the
    // whole layer is the canvas and nothing else.
    //
    // ## PER-PIXEL, NOT "AT MOST A FEW DISTINCT BYTES"
    //
    // A distinct-count check is satisfied by a buffer of nothing but one
    // repeated byte — which paints no canvas at all. So the count is of pixels
    // that are *not* the canvas.

    /// The ambient as the shared harness mounts it, at the prototype's screen.
    Widget ambient({
      LumenShaderTier? tier,
      bool disableAnimations = false,
      bool animationsEnabled = true,
      LumenPreferences? preferences,
      ThemeData? theme,
    }) => evaAmbientHarness(
      theme: theme,
      animationsEnabled: animationsEnabled,
      disableAnimations: disableAnimations,
      child: preferences == null
          ? ambientBackground(tier: tier)
          : LumenPreferencesScope(
              preferences: preferences,
              child: ambientBackground(tier: tier),
            ),
    );

    testWidgets('the fallback paints the canvas and nothing else', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(ambient());
      await tester.pump();

      final Uint8List rgba = await backgroundPixels(tester);
      expect(
        _notCanvas(rgba, const EvaColors.dark().canvas),
        0,
        reason:
            'the fallback is the flat canvas, so every pixel of the ambient is '
            'the canvas — or something is still drawing over it',
      );
    });

    testWidgets('and reduced motion paints the same flat canvas', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(ambient(disableAnimations: true));
      await tester.pump();

      final Uint8List rgba = await backgroundPixels(tester);
      expect(
        _notCanvas(rgba, const EvaColors.dark().canvas),
        0,
        reason:
            'reduced motion drops the tier to `off`, and `off` is the canvas',
      );
    });

    testWidgets('and an explicit `full` override cannot beat reduced motion', (
      WidgetTester tester,
    ) async {
      // The override seam is a **cost** decision; the accessibility decision is
      // not overridable. `LumenTiers.resolve` says so in its own doc, and this
      // is the pixel-level consequence: the canvas paints.
      useAmbientSurface(tester);
      await tester.pumpWidget(
        ambient(tier: LumenShaderTier.full, disableAnimations: true),
      );
      await tester.pump();

      final Uint8List rgba = await backgroundPixels(tester);
      expect(
        _notCanvas(rgba, const EvaColors.dark().canvas),
        0,
        reason: 'the override cannot re-enable motion the reader switched off',
      );
    });

    testWidgets('and the aurora paints more than the fallback does', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(ambient());
      await tester.pump();
      final Uint8List fallback = await backgroundPixels(tester);

      await tester.pumpWidget(ambient(preferences: const LumenPreferences()));
      await tester.pump();
      final Uint8List aurora = await backgroundPixels(tester);

      expect(
        aurora.toString(),
        isNot(fallback.toString()),
        reason:
            'the aurora is not the canvas — and the comparison is over the '
            'whole layer, so a shader that painted nothing would fail here',
      );
    });

    testWidgets('and the fallback never repaints on a frame', (
      WidgetTester tester,
    ) async {
      useAmbientSurface(tester);
      await tester.pumpWidget(ambient());
      await tester.pump();
      final Uint8List before = await backgroundPixels(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(
        before.toString(),
        (await backgroundPixels(tester)).toString(),
        reason: 'a static canvas has nothing to repaint',
      );
    });

    testWidgets('and it asks the framework to keep nothing alive', (
      WidgetTester tester,
    ) async {
      // The old assertion was `willChange == false` on the background's own
      // `CustomPaint`. The fallback has **no `CustomPaint` at all** — it is a
      // `ColoredBox` — so the stronger claim is available: there is no layer
      // that the framework might keep alive for a repaint that never comes.
      useAmbientSurface(tester);
      await tester.pumpWidget(ambient());
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(LumenBackground),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      // And the aurora does have one, which is what makes the difference
      // observable rather than a claim about a widget that is not there.
      await tester.pumpWidget(ambient(preferences: const LumenPreferences()));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(LumenBackground),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and the aurora repaints as its clock advances', (
      WidgetTester tester,
    ) async {
      // D1 — "a repaint genuinely happens". The old suite proved it by
      // comparing the background's own pixels across a pumped interval; the
      // subject is now the aurora, and the mechanism is `u_time` rather than
      // an orb's float.
      useAmbientSurface(tester);
      await tester.pumpWidget(ambient(preferences: const LumenPreferences()));
      await tester.pump();
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
            'advancing the clock must repaint the aurora; a painter that paints '
            'once and never again is the reference implementation\'s actual '
            'behaviour',
      );
    });

    testWidgets('and a stopped clock leaves the aurora\'s pixels identical', (
      WidgetTester tester,
    ) async {
      // THE NEGATIVE CONTROL for the test above. Without it, "the pixels
      // differ" could be satisfied by anything that repaints — a theme change,
      // an antialiasing wobble. The old suite had this control against the
      // orbs' float; the clock that is stopped now is the shader's.
      //
      // **The clocks are stopped but the aurora still paints**, because the
      // tier is resolved from the *reader's* motion preference
      // (`MediaQuery.disableAnimationsOf`) and not from the scope's
      // `animationsEnabled`. The two are different switches, and the ambient
      // is what the first one governs.
      useAmbientSurface(tester);
      await tester.pumpWidget(
        ambient(
          preferences: const LumenPreferences(),
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      final Uint8List before = await backgroundPixels(tester);

      await tester.pump(const Duration(seconds: 3));
      expect(
        before.toString(),
        (await backgroundPixels(tester)).toString(),
        reason: 'a stopped clock has nothing to repaint',
      );
    });

    testWidgets('and the two themes paint different pixels', (
      WidgetTester tester,
    ) async {
      // The old suite asserted this twice — "light mode paints the light
      // aurora" and "changing the palette repaints the painter" — and both
      // claims are one here.
      //
      // **The clock is frozen, so the palette is the ONLY variable.** A
      // comparison with the clock running would differ for the clock's sake,
      // and would pass even if the theme reached the ambient nowhere.
      useAmbientSurface(tester);
      await tester.pumpWidget(
        ambient(
          preferences: const LumenPreferences(),
          theme: EvaThemeDark.theme,
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      final Uint8List dark = await backgroundPixels(tester);

      await tester.pumpWidget(
        ambient(
          preferences: const LumenPreferences(),
          theme: EvaThemeLight.theme,
          animationsEnabled: false,
        ),
      );
      await tester.pump();
      // `MaterialApp` installs an `AnimatedTheme` that lerps a theme change
      // over `kThemeAnimationDuration`, and a single zero-duration `pump()`
      // does not advance it — so the second capture would still read the
      // **previous** palette, which is the bug `golden_pairs_test.dart`'s
      // comment records.
      await tester.pump(kThemeAnimationDuration);
      final Uint8List light = await backgroundPixels(tester);

      expect(
        light.toString(),
        isNot(dark.toString()),
        reason:
            'the light canvas is multiplied into the aurora '
            '(`eva/redesign.html:60`) and the scene is retargeted for the '
            'brightness, so the two themes cannot paint the same bytes',
      );
    });

    testWidgets('and the page above the ambient is untouched too', (
      WidgetTester tester,
    ) async {
      // D1, the other half: the ambient must not dirty the subtree above it.
      // Thirty animation frames must not rebuild the content — the old suite
      // asserted this against the orbs, and the ambient is still the layer
      // that repaints every frame.
      useAmbientSurface(tester);
      await tester.pumpWidget(
        evaAmbientHarness(
          child: const LumenPreferencesScope(
            preferences: LumenPreferences(),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: LumenBackground()),
                Positioned(top: 100, left: 20, child: Text('Today\'s reading')),
              ],
            ),
          ),
        ),
      );
      final Element textElement = tester.element(find.text('Today\'s reading'));
      for (int frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        identical(textElement, tester.element(find.text('Today\'s reading'))),
        isTrue,
        reason: 'thirty animation frames must not rebuild the content above it',
      );
    });
  });

  group('the painter is long-lived', () {
    testWidgets('the shader is allocated once, however many frames paint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const LumenBackground()));
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
      await tester.pumpWidget(harness(const LumenBackground()));
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
          const LumenBackground(),
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
        harness(const LumenBackground(), preferences: const LumenPreferences()),
      );
      await tester.pump();
      expect(
        lumenPainter(tester)!.resolveAt(const Size(390, 844)).spread,
        closeTo(0.42, 1e-12),
      );

      await tester.pumpWidget(
        harness(
          const LumenBackground(),
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
            children: <Widget>[LumenBackground(), LumenBackground()],
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
          const LumenBackground(),
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
          const LumenBackground(),
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
        harness(const LumenBackground(), theme: EvaThemeLight.theme),
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
    Widget scaffold() => const NeuralScaffold(child: SizedBox.shrink());

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

/// How many pixels of [rgba] are **not** [canvas].
///
/// The red / green / blue bytes are read out of `toARGB32()` by hand rather
/// than through `Color.red`, because `toARGB32` packs **A**RRGGBB — `& 0xFF`
/// on the whole word is the *blue* channel, and getting that backwards makes a
/// correct renderer look broken.
int _notCanvas(Uint8List rgba, Color canvas) {
  final int red = (canvas.toARGB32() >> 16) & 0xFF;
  final int green = (canvas.toARGB32() >> 8) & 0xFF;
  final int blue = canvas.toARGB32() & 0xFF;
  int painted = 0;
  for (int offset = 0; offset + 3 < rgba.length; offset += 4) {
    if (rgba[offset] != red ||
        rgba[offset + 1] != green ||
        rgba[offset + 2] != blue ||
        rgba[offset + 3] != 0xFF) {
      painted++;
    }
  }
  return painted;
}
