import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/effects/lumen_canvas.dart';
import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_program.dart';
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rect the frames here are captured at.
///
/// **Logical** pixels, and `toImage` is called with the same two numbers, so
/// one capture pixel is one logical pixel.
const Size kSurface = Size(400, 800);

/// The table every frame in this file paints.
///
/// The same values the CPU-mirror suite uses, so the frame this file captures
/// is a frame that suite would also accept — this file is about the `Paint`
/// the painter hands to `drawRect`, and a nonsense table would make the
/// byte-comparison below meaningless.
LumenUniforms get _fixture => const LumenUniforms.identity()
    .withHue(h: 258, s: 90, l: 66)
    .copyWith(
      resX: kSurface.width,
      resY: kSurface.height,
      shape: 0,
      spread: 0.42,
      rays: 0,
      pointerX: -0.25,
      pointerY: 0.75,
      pointerIntensity: 0.33,
      intensity: 0.61,
      spike: 0.4,
      melt: 0,
      white: 0.22,
      light: 0,
      dots: 0,
      time: 3.7,
    );

/// A canvas that keeps the **instances** it was handed.
///
/// ## WHY A SUBCLASS AND NOT `TestRecordingCanvas` ITSELF
///
/// Because `TestRecordingCanvas.drawRect` stores `Paint.from(paint)` — a
/// **copy** — and the question this file asks is exactly whether the painter
/// hands the *same* `Paint` to `drawRect` twice. A copy cannot answer it:
/// two copies of one object and two copies of two objects look the same.
///
/// The framework's own doc for the class says as much: "In some cases it may
/// be useful to define a subclass that overrides the [Canvas] methods the
/// test is checking and squirrels away the parameters that the test
/// requires." This is that subclass.
class _PaintSpyCanvas extends TestRecordingCanvas {
  /// Every `Paint` handed to [drawRect], in order, **by identity**.
  final List<Paint> rectPaints = <Paint>[];

  @override
  void drawRect(Rect rect, Paint paint) {
    rectPaints.add(paint);
    super.drawRect(rect, paint);
  }
}

/// Paints one frame through [paint] and reads it back as raw RGBA.
///
/// ## WHY `tester.runAsync()` IS MANDATORY
///
/// Because `Picture.toImage` never completes under `flutter test`'s
/// fake-async zone — a bare `await` does not fail, it hangs, and the test
/// dies at the timeout. `runAsync` steps out of the fake zone for the
/// duration. This is the same rule `lumen_canvas_test.dart` records.
Future<Uint8List> _capture(
  WidgetTester tester,
  void Function(Canvas canvas) paint,
) async {
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final ui.Image image = await recorder.endRecording().toImage(
      kSurface.width.round(),
      kSurface.height.round(),
    );
    final ByteData? data = await image.toByteData();
    image.dispose();
    if (data == null) {
      throw StateError('the frame produced no pixels');
    }
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('runAsync returned no pixels');
  }
  return bytes;
}

/// The painter under test, with a fixed clock and a real shader.
Future<LumenCanvas> _painter(WidgetTester tester) async {
  return LumenCanvas(
    program: await LumenProgram.load(),
    uniforms: _fixture,
    clock: LumenClock.fixed(3.7),
  );
}

void main() {
  group('the one reused Paint', () {
    testWidgets('the SAME object is handed to drawRect on every paint', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS IS THE GATE, AND NOT A BEHAVIOURAL ONE
      //
      // The claim is an **allocation** claim: the painter must not build a
      // `Paint` per frame. No amount of comparing pixels can witness it —
      // two `Paint` objects with the same fields draw the same pixels — so
      // the witness has to be the **identity** of the object the painter
      // handed over.
      //
      // And the identity is observable without reflection: `drawRect` is a
      // method on `Canvas`, and `Canvas` is an interface, so a test double
      // can be given the painter and asked which `Paint` it received.
      //
      // **This test fails if the allocation comes back**: two paints, two
      // `Paint` objects, and `identical` is false.
      final LumenCanvas canvas = await _painter(tester);

      final _PaintSpyCanvas first = _PaintSpyCanvas();
      canvas.paint(first, kSurface);
      final _PaintSpyCanvas second = _PaintSpyCanvas();
      canvas.paint(second, kSurface);

      expect(first.rectPaints, hasLength(1));
      expect(second.rectPaints, hasLength(1));
      expect(
        identical(first.rectPaints.first, second.rectPaints.first),
        isTrue,
        reason:
            'the painter allocated a second Paint for the second frame. The '
            'painter is long-lived by design (LumenBackground holds one '
            'instance across frames), so the Paint can live exactly as long '
            'as the painter does.',
      );
    });

    testWidgets('and it is the painter\'s own, not a copy', (
      WidgetTester tester,
    ) async {
      // The `Paint` the painter holds is a **field**, so it is the same
      // object on every paint of the same painter — and a **different**
      // painter has a different one. Without the second half, a painter that
      // shared one `Paint` across the whole app would pass this file.
      final LumenCanvas canvas = await _painter(tester);
      final LumenCanvas other = await _painter(tester);

      final _PaintSpyCanvas mine = _PaintSpyCanvas();
      canvas.paint(mine, kSurface);
      final _PaintSpyCanvas theirs = _PaintSpyCanvas();
      other.paint(theirs, kSurface);

      expect(
        identical(mine.rectPaints.first, theirs.rectPaints.first),
        isFalse,
        reason:
            'each painter owns its Paint — a shared one would be a second '
            'source of truth for a mutable drawing description',
      );
    });

    testWidgets('and every field of it is the one a fresh Paint() has', (
      WidgetTester tester,
    ) async {
      // ## WHY THE FIELD LIST IS WRITT OUT RATHER THAN "THE SAME"
      //
      // Because "the same" is a claim about **every** field, and a `Paint`
      // carries a dozen: a reuse that set one of them — and forgot that a
      // fresh `Paint()` would not have had it — would change the screen
      // while every other field still matched. So each field is compared
      // against a freshly constructed `Paint()`, one by one.
      //
      // The shader is the **one** field that is meant to differ from the
      // default, and it is checked separately below.
      final LumenCanvas canvas = await _painter(tester);
      final _PaintSpyCanvas spy = _PaintSpyCanvas();
      canvas.paint(spy, kSurface);

      final Paint used = spy.rectPaints.first;
      final Paint fresh = Paint();

      expect(used.isAntiAlias, fresh.isAntiAlias, reason: 'isAntiAlias');
      expect(used.color, fresh.color, reason: 'color');
      expect(used.blendMode, fresh.blendMode, reason: 'blendMode');
      expect(used.style, fresh.style, reason: 'style');
      expect(used.strokeWidth, fresh.strokeWidth, reason: 'strokeWidth');
      expect(used.strokeCap, fresh.strokeCap, reason: 'strokeCap');
      expect(used.strokeJoin, fresh.strokeJoin, reason: 'strokeJoin');
      expect(
        used.strokeMiterLimit,
        fresh.strokeMiterLimit,
        reason: 'strokeMiterLimit',
      );
      expect(used.filterQuality, fresh.filterQuality, reason: 'filterQuality');
      expect(used.maskFilter, fresh.maskFilter, reason: 'maskFilter');
      expect(used.colorFilter, fresh.colorFilter, reason: 'colorFilter');
      expect(used.imageFilter, fresh.imageFilter, reason: 'imageFilter');
    });

    testWidgets('and the one field that is set is the frame\'s shader', (
      WidgetTester tester,
    ) async {
      final LumenCanvas canvas = await _painter(tester);
      final _PaintSpyCanvas spy = _PaintSpyCanvas();
      canvas.paint(spy, kSurface);

      expect(
        identical(spy.rectPaints.first.shader, canvas.debugShader),
        isTrue,
        reason:
            'the Paint carries the very shader the painter wrote its uniforms '
            'into — a second shader would be a second uniform buffer, which is '
            'the thing the painter exists to avoid',
      );
    });

    testWidgets('and the frame is byte-identical to a fresh Paint\'s', (
      WidgetTester tester,
    ) async {
      // ## THE PIXEL-IDENTITY PROOF, AS BYTES
      //
      // Two frames of the **same** shader and the **same** uniform values,
      // differing in nothing but the `Paint` object: one through the
      // painter's reused `Paint`, one through a `Paint()` built on the spot
      // exactly as the old code did.
      //
      // If the reuse changed anything on the screen, these two pictures would
      // differ. They are compared **byte for byte**, not by a tolerance.
      final LumenCanvas canvas = await _painter(tester);

      final Uint8List reused = await _capture(
        tester,
        (Canvas c) => canvas.paint(c, kSurface),
      );

      final ui.FragmentShader shader = canvas.debugShader!;
      final Uint8List fresh = await _capture(
        tester,
        (Canvas c) =>
            c.drawRect(Offset.zero & kSurface, Paint()..shader = shader),
      );

      expect(
        fresh,
        reused,
        reason:
            'the reused Paint and a fresh Paint draw the same bytes — that is '
            'what "pixel-identical" means here, and it is the whole claim',
      );
    });
  });
}
