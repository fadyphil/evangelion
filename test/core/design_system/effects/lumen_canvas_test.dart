import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/effects/lumen_canvas.dart';
import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_program.dart';
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/lumen_cpu_mirror.dart';

/// The rect every frame in this file is captured at.
///
/// **Logical** pixels, and `toImage` is called with the same two numbers, so
/// one capture pixel is one logical pixel. That equality is the whole basis of
/// the comparison with the CPU mirror: `FlutterFragCoord()` reports the local
/// logical position, so a mismatch in units shows up as a *shape* difference
/// between the two images rather than as a uniform brightness shift.
const Size kSurface = Size(400, 800);

/// The tolerance the frame assertions use, in 8-bit levels.
///
/// **Measured, not chosen.** With `u_str = 0` — the noise term out of the
/// picture, see the noise group below — the worst per-channel error against
/// [lumenReferenceFrame] is **1** across all 1 280 000 channels, for shapes 0,
/// 1 and 2, at 40×40, 64×128, 100×200, 390×844 and 400×800, and with the
/// scanlines, the melt and daylight each switched on in turn. One level is the
/// quantisation of the read-back itself, so this is the floor rather than a
/// slack allowance.
///
/// The three defects this exists to catch are worth their magnitudes, and each
/// is asserted as a negative control below: the float layout in `UniformSlot`
/// instead of `shaders/lumen.frag`'s declaration order is worth **247**, a
/// missing Y flip **> 100**, and device-pixel `u_res` **> 100**. So this is a
/// gate with a demonstrated failure, not a tolerance nobody checked.
const int kChannelTolerance = 1;

/// The prototype's own opening uniform table (`redesign.html:872-877`,
/// `:1502-1504`).
///
/// `u_res` is [kSurface] and `u_time` is `time`, both of which [LumenCanvas]
/// overwrites with the same values — so a test that builds a reference frame
/// and a test that captures one are describing the same frame. The
/// `u_res` default matters more than it looks: the shader divides by
/// `min(u_res.x, u_res.y)`, so a table left at `LumenUniforms.identity`'s zeroes
/// divides by zero and every `uv` is a NaN.
///
/// **`u_str` is 0 unless a test says otherwise**, and that is the single most
/// important word in this fixture. `u_str = 0` makes
/// `mix(1.0, 0.22 + 0.78·r1, 0)` exactly `1.0` in the shader *and* in the
/// mirror, which removes the one term a CPU mirror cannot reproduce — the noise
/// group's header has the measurement. Every numeric assertion that compares
/// against the mirror uses this fixture.
LumenUniforms fixture({
  int shape = 0,
  double rays = 0,
  double dots = 0,
  double melt = 0,
  double light = 0,
  double time = 3.7,
  double white = 0.22,
}) => const LumenUniforms.identity()
    .withHue(h: 258, s: 90, l: 66)
    .copyWith(
      resX: kSurface.width,
      resY: kSurface.height,
      shape: shape,
      spread: 0.42,
      rays: rays,
      pointerX: -0.25,
      pointerY: 0.75,
      pointerIntensity: 0.33,
      intensity: 0.61,
      spike: 0.4,
      melt: melt,
      white: white,
      light: light,
      dots: dots,
      time: time,
    );

/// Paints one frame and reads it back as raw RGBA.
///
/// ## WHY `tester.runAsync()` IS MANDATORY HERE, AND IT IS NOT ABOUT THE SHADER
///
/// `Picture.toImage` never completes under `flutter test`'s fake-async zone, so
/// a bare `await` does not fail — it hangs, and the test dies at the ten-minute
/// timeout with `Bad state: Cannot close sink while adding stream.` as the only
/// output. **It reproduces with no shader at all**, which is how it was
/// identified: a plain filled rect hung identically. `runAsync` steps out of the
/// fake zone for the duration and the same probe then returns in well under a
/// second.
///
/// ## WHY THE `ui.Image` IS DISPOSED HERE RATHER THAN AT THE CALL SITE
///
/// Because it cannot leak if it happens inside the only function that creates
/// one. A suite that captures many frames and disposes at the end of each test
/// body has as many `dispose()` calls as `toImage` calls only until somebody
/// adds one without adding the other.
Future<Uint8List> captureFrame(
  WidgetTester tester, {
  required LumenProgram program,
  required LumenUniforms uniforms,
  required LumenClock clock,
  Size size = kSurface,
}) async {
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    LumenCanvas(
      program: program,
      uniforms: uniforms,
      clock: clock,
    ).paint(Canvas(recorder), size);
    final ui.Image image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (data == null) {
      throw StateError('the Lumen frame produced no pixels');
    }
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('runAsync returned no pixels');
  }
  return bytes;
}

/// `--reflection-json`'s SPIR-V ID order (S), as raw `setFloat` indices in
/// [UniformSlot] (declaration) member order.
///
/// Derived, not transcribed. S was re-run on this machine (`impellerc
/// --reflection-json`: `u_res` 0–1, `u_time` 2, `u_shape` 3, `u_spread` 4,
/// `u_str` 5, `u_ptr` 6–7, `u_ptrI` 8, `u_int` 9, `u_spike` 10, `u_hue` 11–13,
/// `u_melt` 14, `u_hue2` 15–17, `u_hue3` 18–20, `u_white` 21, `u_light` 22,
/// `u_dots` 23 — see `lumen_uniforms.dart`), and each entry below is S's float
/// position for the member in that slot. Painting through this table is what
/// the deleted `LumenSlotLayout.reflectionOrder` did. It is kept here — data
/// in a test, with no production API behind it — because layout-sensitivity
/// needs a control that actually paints garbage.
const List<int> kReflectionOrderSlots = <int>[
  0, // uResX — S: u_res at 0
  1, // uResY — S: u_res at 1
  2, // uTime — S: u_time at 2
  11, // uHueX — S: u_hue at 11
  12, // uHueY — S: u_hue at 12
  13, // uHueZ — S: u_hue at 13
  15, // uHue2X — S: u_hue2 at 15
  16, // uHue2Y — S: u_hue2 at 16
  17, // uHue2Z — S: u_hue2 at 17
  18, // uHue3X — S: u_hue3 at 18
  19, // uHue3Y — S: u_hue3 at 19
  20, // uHue3Z — S: u_hue3 at 20
  9, // uInt — S: u_int at 9
  5, // uStr — S: u_str at 5
  10, // uSpike — S: u_spike at 10
  4, // uSpread — S: u_spread at 4
  3, // uShape — S: u_shape at 3
  14, // uMelt — S: u_melt at 14
  23, // uDots — S: u_dots at 23
  21, // uWhite — S: u_white at 21
  22, // uLight — S: u_light at 22
  6, // uPtrX — S: u_ptr at 6
  7, // uPtrY — S: u_ptr at 7
  8, // uPtrI — S: u_ptrI at 8
];

/// Paints one frame through an EXPLICIT raw slot table instead of
/// [UniformSlot]'s, and reads it back as raw RGBA.
///
/// Test-only: it exists for exactly one caller, the S-order negative control
/// below. The resolved values come from a real [LumenCanvas] (`resolveAt`), so
/// the only thing under test is the slot mapping — `u_res` is still the
/// logical size and `u_time` still the clock. `slots` is indexed by
/// [UniformSlot] position: `slots[UniformSlot.uShape.index]` is the `setFloat`
/// index the shape value is written to. Same `runAsync` and disposal rules as
/// [captureFrame].
Future<Uint8List> captureFrameWithRawSlots(
  WidgetTester tester, {
  required LumenProgram program,
  required LumenUniforms uniforms,
  required LumenClock clock,
  required List<int> slots,
  Size size = kSurface,
}) async {
  assert(
    slots.length == UniformSlot.values.length,
    'one raw index per UniformSlot member, got ${slots.length}',
  );
  final LumenUniforms resolved = LumenCanvas(
    program: program,
    uniforms: uniforms,
    clock: clock,
  ).resolveAt(size);
  // In `UniformSlot.values` order, so entry `i` is the value of the member at
  // `slot.index == i`. If the enum is ever reordered, this list must follow it
  // — the `shaderIndex` test and the declaration-ramp test would catch a
  // drift, but only this comment says where to look.
  final List<double> values = <double>[
    resolved.resX,
    resolved.resY,
    resolved.time,
    resolved.hue.r,
    resolved.hue.g,
    resolved.hue.b,
    resolved.hue2.r,
    resolved.hue2.g,
    resolved.hue2.b,
    resolved.hue3.r,
    resolved.hue3.g,
    resolved.hue3.b,
    resolved.intensity,
    resolved.rays,
    resolved.spike,
    resolved.spread,
    resolved.shape.toDouble(),
    resolved.melt,
    resolved.dots,
    resolved.white,
    resolved.light,
    resolved.pointerX,
    resolved.pointerY,
    resolved.pointerIntensity,
  ];
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.FragmentShader shader = program.newShader();
    for (int i = 0; i < values.length; i++) {
      shader.setFloat(slots[i], values[i]);
    }
    Canvas(recorder).drawRect(Offset.zero & size, Paint()..shader = shader);
    final ui.Image image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (data == null) {
      throw StateError('the Lumen frame produced no pixels');
    }
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('runAsync returned no pixels');
  }
  return bytes;
}

/// The reference frame for [fixture], at [size].
Uint8List referenceFrame(LumenUniforms u, {bool flipY = true}) =>
    lumenReferenceFrame(
      uniforms: u,
      width: kSurface.width.round(),
      height: kSurface.height.round(),
      flipY: flipY,
    );

/// The worst per-channel difference between a captured frame and a reference.
({int worst, int x, int y, int channel}) worstChannelError(
  Uint8List captured,
  Uint8List reference,
) {
  int worst = 0;
  int at = 0;
  for (int i = 0; i < reference.length; i++) {
    final int delta = (captured[i] - reference[i]).abs();
    if (delta > worst) {
      worst = delta;
      at = i;
    }
  }
  final int pixel = at ~/ 4;
  return (
    worst: worst,
    x: pixel % kSurface.width.round(),
    y: pixel ~/ kSurface.width.round(),
    channel: at % 4,
  );
}

/// Where the difference was, in a form a failure message can carry.
String where(({int worst, int x, int y, int channel}) delta) =>
    '${delta.worst} levels at (${delta.x}, ${delta.y}) channel ${delta.channel}';

/// A mounted scope and the bundle it published.
typedef ScopeHarness = ({EvaNeuralMotion motion, TickedLumenClock clock});

/// Mounts a scope with its clocks running and hands back the bundle.
///
/// Its own harness rather than `evaAmbientHarness`, because those two wrappers
/// exist for *painted* backgrounds — they bring a [MaterialApp] and a
/// [MediaQuery] around the child — and a test about a clock needs neither.
/// `evaPrimitiveHarness` also defaults `ambientAnimations: false`, which is the
/// opposite of what is wanted here.
Future<ScopeHarness> pumpScope(WidgetTester tester) async {
  late EvaNeuralMotion motion;
  await tester.pumpWidget(
    NeuralMotionScope(
      animationsEnabled: true,
      child: Builder(
        builder: (BuildContext context) {
          motion = NeuralMotionScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (motion: motion, clock: motion.lumen);
}

void main() {
  group('LumenClock.fixed — the seam the goldens depend on', () {
    test('reports exactly the seconds it was given', () {
      expect(LumenClock.fixed(3.7).seconds, 3.7);
      expect(LumenClock.fixed(0).seconds, 0);
      expect(LumenClock.fixed(3600).seconds, 3600);
    });

    test('an hour in is an hour out, and it is not taken modulo anything', () {
      // THE WRAP TEST, at the value the plan names. A previous revision of this
      // plan wrapped `u_time` and the wrap was cut on measurement (Task 1.4):
      // float32 simulation of `fbm1` gave 4001 distinct outputs at both `t = 0`
      // and `t = 3600 s`, posterisation onset ≈ 10 h, and no wrap period
      // preserves the visual loop — at `T = 10 s` none of the ten `sin` terms is
      // periodic, and the smallest fully-periodic `T = 628.32 s` still leaves
      // `4.31 · 0.9 · T = 2437.2476` non-integral.
      //
      // So 3600 must survive intact, and 3600 is the value a `% 3600`, a
      // `% 100` and a float32 round-trip of the accumulator would all get wrong.
      expect(LumenClock.fixed(3600).seconds, 3600.0);
      expect(LumenClock.fixed(36000).seconds, 36000.0);
      expect(LumenClock.fixed(360000).seconds, 360000.0);
    });

    test('it is a Listenable, and it never fires', () {
      // A frozen clock that notified would repaint the aurora on nothing, and
      // "the same inputs give the same bytes" only holds while the clock
      // contributes nothing between frames.
      final LumenClock clock = LumenClock.fixed(1);
      int fired = 0;
      void listener() => fired++;
      clock.addListener(listener);
      expect(clock, isA<Listenable>());
      expect(fired, 0);
      clock.removeListener(listener);
      expect(fired, 0);
      clock.dispose();
    });
  });

  group('TickedLumenClock — production, driven by a shared controller', () {
    testWidgets('it counts real elapsed time', (WidgetTester tester) async {
      final ScopeHarness harness = await pumpScope(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(harness.clock.seconds, closeTo(2.0, 1e-6));
      await tester.pump(const Duration(seconds: 2));
      expect(harness.clock.seconds, closeTo(4.0, 1e-6));
      expect(
        harness.clock.seconds,
        harness.clock.rawElapsedSeconds,
        reason:
            'no restart yet, so the clock must be exactly the ticker\'s own '
            'elapsed reading — a `value × period` implementation would agree '
            'here too, which is why the restart case below is the one that '
            'tells the two apart',
      );
    });

    testWidgets('stopping and restarting does NOT rewind it', (
      WidgetTester tester,
    ) async {
      final ScopeHarness harness = await pumpScope(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(harness.clock.seconds, closeTo(5.0, 1e-6));

      // Exactly what a reader toggling reduced motion does.
      harness.motion.setAnimationsEnabled(enabled: false);
      await tester.pump(const Duration(seconds: 3));
      expect(
        harness.clock.rawElapsedSeconds,
        0,
        reason: 'stop() nulls lastElapsedDuration — this is the restart',
      );
      expect(
        harness.clock.seconds,
        closeTo(5.0, 1e-6),
        reason: 'a frozen clock, not a rewound one',
      );

      harness.motion.setAnimationsEnabled(enabled: true);
      // TWO pumps, and the first is not the measured second. `repeat()` is
      // called here between frames, so `Ticker.start()` leaves `_startTime`
      // null and the next frame only ESTABLISHES it (`_tick: _startTime ??=
      // timeStamp`) — that frame reads elapsed `0`, correctly. The second pump
      // is the one that advances. (The initial `pumpScope` + `pump(5 s)` above
      // needed no such frame because `repeat()` ran DURING `pumpWidget`'s
      // frame, where `start()` stamps the current frame time directly.) A
      // single pump here reading `5.0` is Ticker mechanics, not a rewind: the
      // clock is continuous, just one frame late, which at 60 fps is 16 ms of
      // the same value twice.
      await tester.pump();
      expect(
        harness.clock.seconds,
        closeTo(5.0, 1e-6),
        reason: 'the restart frame establishes the start time and reads zero',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        harness.clock.seconds,
        closeTo(6.0, 1e-6),
        reason:
            'the tick restarted from zero, so only an offset keeps u_time '
            'monotonic — without it the aurora would visibly rewind every time '
            'a reader asked for reduced motion and then took it back',
      );
    });
  });

  group('NeuralMotionScope publishes it and stops it with the other three', () {
    testWidgets('a live clock advances, and freezing stops it', (
      WidgetTester tester,
    ) async {
      final ScopeHarness harness = await pumpScope(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(harness.motion.lumen.seconds, closeTo(3.0, 1e-6));

      harness.motion.setAnimationsEnabled(enabled: false);
      await tester.pump(const Duration(seconds: 1));
      expect(harness.motion.lumen.seconds, closeTo(3.0, 1e-6));
    });
  });

  group('LumenProgram', () {
    testWidgets('loads the shader and memoises the wrapper', (
      WidgetTester tester,
    ) async {
      final LumenProgram first = await LumenProgram.load();
      final LumenProgram second = await LumenProgram.load();
      expect(
        identical(first, second),
        isTrue,
        reason:
            'the SDK memoises `FragmentProgram` itself; holding one wrapper '
            "makes this app's sharing explicit and therefore assertable",
      );
      expect(first.asset, kLumenShaderAsset);
    });

    testWidgets('each program hands out its own FragmentShader', (
      WidgetTester tester,
    ) async {
      // Why `LumenCanvas` holds one and mutates it: a second call is a second
      // uniform buffer. The SDK says so itself, on `FragmentShader`.
      final LumenProgram program = await LumenProgram.load();
      expect(identical(program.newShader(), program.newShader()), isFalse);
    });

    testWidgets('the enum order is the engine\'s own bookkeeping', (
      WidgetTester tester,
    ) async {
      // THE CHEAP LAYOUT PIN. `FragmentShader.getUniformFloat(name)` answers a
      // `UniformFloatSlot` whose `.index` is the *component* offset (0 for
      // `.x`, 1 for `.y` — which is why a naive read of it reports 0 for every
      // uniform) and whose `shaderIndex` (`VisibleForTesting` — test use is its
      // purpose) is the absolute float position `setFloat` wants. One assertion
      // per uniform, no rendering at all: if the engine ever stops laying out
      // in declaration order, this fails before any pixel test runs.
      //
      // Expected values read off `shaders/lumen.frag:34-49`, first float of
      // each uniform; verified by probe on this SDK rather than trusted from
      // the field docs.
      final LumenProgram program = await LumenProgram.load();
      final ui.FragmentShader shader = program.newShader();
      const Map<String, int> firstFloatByUniform = <String, int>{
        'u_res': 0,
        'u_time': 2,
        'u_hue': 3,
        'u_hue2': 6,
        'u_hue3': 9,
        'u_int': 12,
        'u_str': 13,
        'u_spike': 14,
        'u_spread': 15,
        'u_shape': 16,
        'u_melt': 17,
        'u_dots': 18,
        'u_white': 19,
        'u_light': 20,
        'u_ptr': 21,
        'u_ptrI': 23,
      };
      expect(firstFloatByUniform, hasLength(16));
      firstFloatByUniform.forEach((String name, int first) {
        expect(
          shader.getUniformFloat(name).shaderIndex,
          first,
          reason: '$name starts at float $first',
        );
      });
    });

    testWidgets('and the components follow the base, contiguously', (
      WidgetTester tester,
    ) async {
      // The second half of the `.index`-vs-`shaderIndex` distinction the
      // `lumen_program.dart` doc corrects: `u_hue[1]` is component offset 1 at
      // absolute float 4, and `u_res[1]` is offset 1 at float 1. A `vec3` with
      // padding would read 4 → 8 here instead of 4 → 5.
      final LumenProgram program = await LumenProgram.load();
      final ui.FragmentShader shader = program.newShader();
      expect(shader.getUniformFloat('u_hue', 1).shaderIndex, 4);
      expect(shader.getUniformFloat('u_hue', 2).shaderIndex, 5);
      expect(shader.getUniformFloat('u_res', 1).shaderIndex, 1);
      expect(shader.getUniformFloat('u_hue', 1).index, 1);
    });
  });

  group('LumenCanvas.resolveAt — what will actually be sent', () {
    testWidgets('u_res is the LOGICAL rect, and it overrides the table', (
      WidgetTester tester,
    ) async {
      // A table that claims to be something else must not win. `u_res` in device
      // pixels is a plausible-looking number — `size * devicePixelRatio` — and
      // the shader divides by `min(u_res.x, u_res.y)`, so a DPR-scaled value
      // scales the band by the DPR and clips it off the short side.
      final LumenCanvas canvas = LumenCanvas(
        program: await LumenProgram.load(),
        uniforms: const LumenUniforms.identity().copyWith(
          resX: 1200,
          resY: 2400,
        ),
        clock: LumenClock.fixed(0),
      );
      expect(canvas.resolveAt(kSurface).resX, 400);
      expect(canvas.resolveAt(kSurface).resY, 800);
    });

    testWidgets('u_time is the clock, exactly: no scale, no wrap', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      for (final double t in <double>[0, 3.7, 3600, 360000]) {
        final LumenCanvas canvas = LumenCanvas(
          program: program,
          uniforms: fixture(time: 999),
          clock: LumenClock.fixed(t),
        );
        expect(
          canvas.resolveAt(kSurface).time,
          t,
          reason:
              'the table said 999 and the clock said $t. The clock wins, and it '
              'wins exactly: no 0.30 scale (the shader does that), no '
              'reduced-motion 0.15 (that belongs to whoever owns the ticker), '
              'and no modulo.',
        );
      }
    });

    testWidgets('the other eighteen fields are the caller\'s, untouched', (
      WidgetTester tester,
    ) async {
      final LumenUniforms u = fixture(shape: 2, dots: 1);
      final LumenUniforms sent = LumenCanvas(
        program: await LumenProgram.load(),
        uniforms: u,
        clock: LumenClock.fixed(3.7),
      ).resolveAt(kSurface);
      expect(sent, u.copyWith(resX: 400, resY: 800, time: 3.7));
      expect(sent.hue, u.hue, reason: 'and the derived triple with it');
      expect(sent.hue2, u.hue2);
      expect(sent.hue3, u.hue3);
    });

    testWidgets('the clock drives its repaints, and shouldRepaint catches the '
        'rest', (WidgetTester tester) async {
      final LumenProgram program = await LumenProgram.load();
      final ScopeHarness harness = await pumpScope(tester);
      final LumenCanvas canvas = LumenCanvas(
        program: program,
        uniforms: fixture(),
        clock: harness.clock,
      );

      // The clock is the painter's `repaint`, so advancing it reaches the
      // framework's listener without a rebuild anywhere. Asserted through the
      // listener rather than through an identity check: `CustomPainter` takes
      // `repaint` as a constructor argument on this SDK and exposes no getter,
      // and "it fires" is the property that matters anyway.
      int repaints = 0;
      canvas.addListener(() => repaints++);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repaints, greaterThan(0));

      expect(
        canvas.shouldRepaint(canvas),
        isFalse,
        reason: 'an identical table is not a change',
      );
      expect(
        canvas.shouldRepaint(
          LumenCanvas(
            program: program,
            uniforms: fixture(shape: 1),
            clock: harness.clock,
          ),
        ),
        isTrue,
      );
    });
  });

  group('u_time is unwrapped — the value the GPU receives', () {
    testWidgets('at an hour the shader gets 3600 s, not 0 s', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      final Uint8List captured = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(time: 0),
        clock: LumenClock.fixed(3600),
      );

      // Two references an hour apart in the shader's own time. The frame must be
      // the first and must not be the second — which is what a wrap produces,
      // stated as an assertion rather than as a policy. `uniforms` says `0 s`
      // on purpose: the painter overrides it, and this is what proves that.
      final ({int worst, int x, int y, int channel}) atHour = worstChannelError(
        captured,
        referenceFrame(fixture(time: 3600)),
      );
      expect(
        atHour.worst,
        lessThanOrEqualTo(kChannelTolerance),
        reason: 'the painter handed the shader 3600 s — ${where(atHour)}',
      );

      final ({int worst, int x, int y, int channel}) atZero = worstChannelError(
        captured,
        referenceFrame(fixture(time: 0)),
      );
      expect(
        atZero.worst,
        greaterThan(kChannelTolerance),
        reason:
            'and NOT 0 s, which is what a `% 3600` or a wrapped accumulator '
            'would have produced — ${where(atZero)}',
      );
    });
  });

  group('determinism — the property the 240 goldens rest on', () {
    testWidgets('a fixed clock gives byte-identical frames', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      final Uint8List first = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
      );
      final Uint8List second = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
      );
      expect(
        second,
        first,
        reason:
            'two captures of the same table at the same time must agree byte '
            'for byte, or no golden of the aurora is worth recording',
      );
    });

    testWidgets('and a different time gives different bytes', (
      WidgetTester tester,
    ) async {
      // THE NEGATIVE CONTROL. Without it the test above is satisfied by a shader
      // that ignores `u_time` entirely — which is the D1 defect
      // `neural_background.dart` documents for the painted background, wearing a
      // shader's hat. If these frames were equal the golden strategy would still
      // be sound and the *clock* would be pointless, so this pair is the whole
      // argument.
      final LumenProgram program = await LumenProgram.load();
      final Uint8List at = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
      );
      final Uint8List later = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(4.37),
      );
      final ({int worst, int x, int y, int channel}) delta = worstChannelError(
        later,
        at,
      );
      expect(
        delta.worst,
        greaterThan(kChannelTolerance),
        reason:
            'advancing u_time by 0.67 s changed the frame by at most '
            '${where(delta)}',
      );
    });
  });

  group('the CPU mirror — replacing the unobtainable oracle', () {
    // ## WHY THERE IS NO RECORDED ORACLE FRAME
    //
    // The port's plan said to compare the first frame against a capture of the
    // original WebGL shader. **That artefact does not exist**: there is no WebGL
    // in this environment and no recorded frame is committed, so it can be
    // neither generated nor obtained, and a hand-transcribed "oracle" would be
    // the same claim with an extra step — both would be typed by the same author
    // from the same source, so both would share every mistake.
    //
    // It is replaced by a second **implementation** of the same maths:
    // `test/support/lumen_cpu_mirror.dart`, written in Dart from
    // `shaders/lumen.frag`. A golden cannot do this job either — it ratifies
    // whatever the shader currently does, which is AGENT_CONTEXT recorded
    // decision 8's failure mode, and the three negative controls below are the
    // demonstration that it would not have caught any of them.

    testWidgets('the frame matches the mirror, within one 8-bit level', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      final Uint8List captured = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
      );
      final ({int worst, int x, int y, int channel}) delta = worstChannelError(
        captured,
        referenceFrame(fixture()),
      );
      expect(
        delta.worst,
        lessThanOrEqualTo(kChannelTolerance),
        reason: 'worst channel error ${where(delta)} over 1 280 000 channels',
      );
    });

    for (final (int shape, String label) in <(int, String)>[
      (0, 'top'),
      (1, 'bottom'),
      (2, 'sides'),
    ]) {
      testWidgets('shape $shape ($label) matches too', (
        WidgetTester tester,
      ) async {
        final LumenProgram program = await LumenProgram.load();
        final Uint8List captured = await captureFrame(
          tester,
          program: program,
          uniforms: fixture(shape: shape),
          clock: LumenClock.fixed(3.7),
        );
        final ({int worst, int x, int y, int channel}) delta =
            worstChannelError(captured, referenceFrame(fixture(shape: shape)));
        expect(
          delta.worst,
          lessThanOrEqualTo(kChannelTolerance),
          reason:
              'shape $shape is a different branch of `main` entirely — '
              '${where(delta)}',
        );
      });
    }

    testWidgets('so do the scanlines, the melt and daylight', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      for (final (String label, LumenUniforms u) in <(String, LumenUniforms)>[
        ('scanlines', fixture(dots: 1)),
        ('melt', fixture(melt: 1)),
        ('daylight', fixture(light: 1)),
      ]) {
        final Uint8List captured = await captureFrame(
          tester,
          program: program,
          uniforms: u,
          clock: LumenClock.fixed(3.7),
        );
        final ({int worst, int x, int y, int channel}) delta =
            worstChannelError(captured, referenceFrame(u));
        expect(
          delta.worst,
          lessThanOrEqualTo(kChannelTolerance),
          reason: '$label — ${where(delta)}',
        );
      }
    });

    for (final double t in <double>[0, 11.3, 97.75]) {
      testWidgets('and it holds at t = $t s', (WidgetTester tester) async {
        // Three times, not one: a mirror agreeing only at 3.7 s would be
        // agreeing by luck of the branch's inputs.
        final LumenProgram program = await LumenProgram.load();
        final Uint8List captured = await captureFrame(
          tester,
          program: program,
          uniforms: fixture(time: t),
          clock: LumenClock.fixed(t),
        );
        final ({int worst, int x, int y, int channel}) delta =
            worstChannelError(captured, referenceFrame(fixture(time: t)));
        expect(
          delta.worst,
          lessThanOrEqualTo(kChannelTolerance),
          reason: where(delta),
        );
      });
    }
  });

  group('negative controls — the three defects this gate exists for', () {
    testWidgets('a MISSING Y flip would fail it', (WidgetTester tester) async {
      final LumenProgram program = await LumenProgram.load();
      final Uint8List captured = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(shape: 0),
        clock: LumenClock.fixed(3.7),
      );
      final ({int worst, int x, int y, int channel}) delta = worstChannelError(
        captured,
        referenceFrame(fixture(shape: 0), flipY: false),
      );
      expect(
        delta.worst,
        greaterThan(100),
        reason:
            'the unflipped reference differs from the frame by ${where(delta)}. '
            'A gate that could not tell the two apart would not be checking '
            'PORT 2 at all — and the flip is invisible to any comparison of '
            'single values, because it only changes *where* the band sits.',
      );
    });

    testWidgets('a `u_res` in DEVICE pixels would fail it', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      final Uint8List captured = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
      );
      // devicePixelRatio 3 — the framework's own default test-surface value.
      final Uint8List devicePixels = referenceFrame(
        fixture().copyWith(resX: kSurface.width * 3, resY: kSurface.height * 3),
      );
      final ({int worst, int x, int y, int channel}) delta = worstChannelError(
        captured,
        devicePixels,
      );
      expect(delta.worst, greaterThan(100), reason: where(delta));
    });

    testWidgets('and so would the wrong float layout', (
      WidgetTester tester,
    ) async {
      // THE ONE THAT FIRED, kept test-only. `--reflection-json`'s SPIR-V ID
      // order is not the order `setFloat` takes: painting through it produces
      // a frame wrong by up to 247 of 255 levels, which is what a CPU mirror
      // is for and what a golden would have recorded as a faithful render of
      // a bug. The two-layout production enum that used to paint it is
      // deleted; what remains is the raw table below — data in a test, with
      // no production API behind it — plus the check that Impeller agrees and
      // is genuinely running (a `MaskFilter.blur` circle rasterises to centre
      // byte 47 under Skia and 45 under `--enable-impeller` on lavapipe).
      final LumenProgram program = await LumenProgram.load();
      final Uint8List correct = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
      );
      final Uint8List mislaid = await captureFrameWithRawSlots(
        tester,
        program: program,
        uniforms: fixture(),
        clock: LumenClock.fixed(3.7),
        slots: kReflectionOrderSlots,
      );
      expect(
        worstChannelError(correct, referenceFrame(fixture())).worst,
        lessThanOrEqualTo(kChannelTolerance),
        reason: 'UniformSlot.index is the order that renders',
      );
      final ({int worst, int x, int y, int channel}) delta = worstChannelError(
        mislaid,
        referenceFrame(fixture()),
      );
      expect(
        delta.worst,
        greaterThan(100),
        reason:
            'the reflection order is wrong at runtime, so a painter using it '
            'would ship an aurora in colours nobody chose — silently, '
            'because nothing throws. Measured ${where(delta)}.',
      );
    });
  });

  group('the noise term — bounded, because it cannot be mirrored', () {
    // ## WHY IT IS NOT A PIXEL ASSERTION
    //
    // `fract(sin(n) · 43758.5453125)` is evaluated in `float32` by the
    // rasteriser and in `float64` here, and the 43758× multiplier makes the
    // comparison ill-conditioned: a 10⁻⁸ difference in `sin` arrives at `fract`
    // as 4 × 10⁻⁴, and `noise1` always hashes an **integer** — `floor(x)` —
    // which is precisely where `sin(n) · 43758.5453` lands nearest an integer.
    //
    // Measured, at 400×800 with `u_str = 1`: worst per-channel error **55**
    // (shape 0), **75** (sides) and **77** (shafts), with 68% of the
    // 1 280 000 channels still matching exactly. Fifty-five levels of slack
    // would be a gate that catches nothing.
    //
    // So the noise is asserted by **bounds** instead, on the GPU-vs-GPU ratio
    // of a noisy frame to a flat one. Three facts make the ratio exact rather
    // than statistical, and each was earned by a failing measurement:
    //
    // 1. **Dark mode applies no tone curve.** `shaders/lumen.frag:108` is
    //    `col = mix(emit, 1 − 0.55·em, u_light)`, so at `u_light = 0` the
    //    captured byte is `round(emit · 255)` until it saturates — the factor
    //    IS the byte ratio, with no inversion. An earlier revision of
    //    `observedNoiseFactors` inverted `col = emit/(1+emit)`, the daylight
    //    arm's curve, and read a true 0.50 as 0.21 at bright pixels; the suite
    //    failed that revision at `0.14`, and the linear model that replaced it
    //    predicts the flat frame's bytes from the mirror's exact `body`/`core`
    //    to ±0.51 levels over 71 413 pixels, so the linearity is a measurement,
    //    not a reading.
    // 2. **The rays multiplier is a per-pixel darkening.** Both `mix` factors
    //    move from `1.0` towards something smaller as `u_str` rises, with the
    //    SAME `r1`/`r2` in both frames, so `noisy ≤ flat` in reals at every
    //    pixel and — `round()` is monotonic and the rasteriser is
    //    deterministic — in bytes too. The upper bound is therefore exactly
    //    `1.0`, not a tolerance.
    // 3. **The pointwise floor is `0.1474`.** At `r1 = r2 = 0` the multiplier
    //    is `0.22 · mix(1, 0.45, 0.6) = 0.22 · 0.67`. (An earlier revision of
    //    this comment wrote `0.22 · 0.72 = 0.1584`, a mean-ish value where a
    //    minimum belongs.)
    //
    // The committed lower bound is **`0.30`, not `0.1474`, and it is
    // fixture-calibrated rather than theoretical.** Every bright pixel carries
    // additive glow and core lift, so the observed single-application minimum
    // on this fixture is **0.42** at (267, 93) — decomposing that pixel through
    // the mirror's exact band/glow split solves the true rays at `q = 0.39`,
    // under which a double application predicts **0.19** there and below
    // `0.30` at **14 245** pixels, while single application puts none below
    // `0.42`. So `0.30` separates the two hypotheses on this fixture with
    // margin on both sides; it must be re-measured, not re-derived, if the
    // fixture's time, hue, pointer or intensity ever changes. That is what
    // catches a `u_str` that arrives twice; one that never arrives is caught
    // by the moves-the-frame check and the variance check below.

    testWidgets('u_str = 1 moves the frame, within the shader\'s own bounds', (
      WidgetTester tester,
    ) async {
      final LumenProgram program = await LumenProgram.load();
      // `white: 0` isolates the rays term — see `observedNoiseFactors`.
      final LumenUniforms quiet = fixture(rays: 0, white: 0);
      final Uint8List flat = await captureFrame(
        tester,
        program: program,
        uniforms: quiet,
        clock: LumenClock.fixed(3.7),
      );
      final Uint8List noisy = await captureFrame(
        tester,
        program: program,
        uniforms: fixture(rays: 1, white: 0),
        clock: LumenClock.fixed(3.7),
      );
      expect(
        worstChannelError(noisy, flat).worst,
        greaterThan(kChannelTolerance),
        reason:
            'the rays term is live — without this the bounds below are '
            'satisfied by a frame that never varied',
      );

      final List<int> measured = observedNoiseFactors(noisy, flat, quiet);
      if (measured.isEmpty) {
        fail(
          'no pixel was bright enough to read, so the bounds would be '
          'vacuously true. The floor is a quarter of the channel range; '
          'a fixture that dark fails here rather than passing silently.',
        );
      }
      int lowest = measured.first;
      int highest = measured.first;
      for (final int hundredths in measured) {
        expect(
          hundredths / 100,
          inInclusiveRange(0.30, 1.0),
          reason:
              'observed a noise multiplier of ${hundredths / 100}. '
              'Single application reads in [0.42, 0.82] on this fixture '
              '(theory floor 0.1474 = 0.22 · 0.67 at r1 = r2 = 0); a double '
              'application predicts 0.19 at the minimum pixel and below 0.30 '
              'at 14 245 of them. Below 0.30 the rays term has been applied '
              'twice or to the wrong quantity, above 1.0 the frame got '
              'brighter, which a darkening multiplier cannot do.',
        );
        if (hundredths < lowest) lowest = hundredths;
        if (hundredths > highest) highest = hundredths;
      }
      expect(
        highest - lowest,
        greaterThan(10),
        reason:
            'the multiplier never varied by more than 0.10 across '
            '${measured.length} pixels, so the noise is a constant rather than '
            'a field',
      );
    });
  });
}

/// The noise multiplier observed at every pixel bright enough to read.
///
/// Returns hundredths of a multiplier as `int`s, because that is the only way to
/// keep a list of these inside an `expect` without a matcher per entry.
///
/// ## THE RATIO IS THE BYTE RATIO, AND THAT IS THE WHOLE CONTENT
///
/// In dark mode the shader applies no tone curve (`shaders/lumen.frag:108` is
/// `col = mix(emit, 1 − 0.55·em, u_light)`), so an unsaturated captured byte is
/// `round(emit · 255)` and the multiplier follows by division — no inversion.
/// Pixels reading `255` are skipped: the byte is clamped and the true emit is
/// unknowable, so the ratio there understates by an unknown amount. Pixels
/// below 64 are skipped because one 8-bit step is then over 2% of the reading,
/// which is the precision the bounds are stated to.
///
/// ## THE PRECONDITIONS ARE ASSERTS, NOT PARAMETERS
///
/// `white` must be `0`: the white term adds `body⁴·white·I` to both frames and
/// drags the ratio below the rays multiplier at bright pixels — a confound,
/// not a signal, and `white` itself is already covered by the mirror tests at
/// `0.22`. `light` must be `0`: the daylight arm replaces the linear read with
/// `1 − 0.55·em`, which flips the monotonicity the `1.0` upper bound rests on.
/// A caller passing anything else gets bounds that mean nothing, silently, so
/// the helper refuses instead.
List<int> observedNoiseFactors(
  Uint8List noisy,
  Uint8List flat,
  LumenUniforms uniforms,
) {
  assert(
    uniforms.white == 0,
    'the white term confounds the ratio — pass white: 0 (see the doc)',
  );
  assert(
    uniforms.light == 0,
    'daylight replaces the linear read the bounds rest on (see the doc)',
  );
  const int floor = 64;
  final List<int> factors = <int>[];
  for (int y = 0; y < kSurface.height.round(); y++) {
    for (int x = 0; x < kSurface.width.round(); x++) {
      final int offset = (y * kSurface.width.round() + x) * 4;
      // 255: clamped, the true emit is unknowable — see the doc.
      if (flat[offset] < floor || flat[offset] == 255) continue;
      factors.add((noisy[offset] / flat[offset] * 100).round());
    }
  }
  return factors;
}
