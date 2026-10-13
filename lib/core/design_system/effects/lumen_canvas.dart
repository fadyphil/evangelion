import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_program.dart';
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:flutter/widgets.dart';

/// Paints the LUMEN aurora into whatever rect it is given.
///
/// ## WHY THE PAINTER OWNS `u_res` AND `u_time` AND NOT THE CALLER
///
/// Because those two are **not inputs**. They are facts about the frame being
/// painted, and a caller that supplied them would be supplying a second source
/// of truth for each:
///
/// * `u_res` has to be the rect's **logical** size. Impeller's
///   `runtime_effect.vert` passes the *untransformed local* vertex position to
///   `_fragCoord`, and `FlutterFragCoord()` returns exactly that — measured
///   here: for a 400×800 rect it spans 0→399 × 0→799, top-left origin, +Y down.
///   A device-pixel value (`size * devicePixelRatio`) is a plausible-looking
///   number the shader divides by `min(u_res.x, u_res.y)`, so the band would be
///   scaled by the DPR and clipped off the short side — a *visible* defect,
///   which is not the same as a loud one.
/// * `u_time` has to be the clock's elapsed seconds, unwrapped.
///   [LumenUniforms.time]'s own doc says the reduced-motion `0.15` scale and
///   the capped `dt` belong to whoever owns the ticker; this is whoever owns the
///   ticker, and the value it hands over is [LumenClock.seconds] and nothing
///   else.
///
/// So [resolveAt] is the one place the two are combined, it is public, and the
/// suite asserts on it directly rather than inferring it from pixels. Everything
/// else in [uniforms] is passed through untouched — the thirteen scalars and the
/// three hues are the caller's, and a painter that second-guessed them would be
/// the second source of truth this class exists to remove.
///
/// ## WHY THE TWENTY-FOUR `setFloat` CALLS ARE SPELLED OUT
///
/// A loop over `UniformSlot.values` with a `switch` returning the value would be
/// shorter and would compile the same error away. It would also be unreadable
/// next to `shaders/lumen.frag`: twenty-four lines that name the uniform they
/// write, in the shader's own names, diff against the shader when the shader
/// changes. The slot numbers never appear as literals here: each call writes
/// `UniformSlot.<member>.index`, which IS the `setFloat` index by
/// construction — the enum is declared in slot order, and the suite pins that
/// three ways (see [UniformSlot]).
///
/// ## WHY ONE `FragmentShader` AND NOT ONE PER FRAME
///
/// `program.newShader()` allocates a fresh uniform buffer every call, and
/// `paint` is called on every frame. The SDK's own note on `FragmentShader`:
/// *"A FragmentShader can be re-used, and this is an efficient way to avoid
/// allocating and re-initializing the uniform buffer and samplers."* The shader
/// is created lazily on the first paint rather than in the constructor so that a
/// painter which is built and discarded by a golden comparison that fails before
/// painting costs nothing.
class LumenCanvas extends CustomPainter {
  /// Paints [uniforms] with [clock]'s time into whatever rect it is given.
  ///
  /// [clock] is handed straight to `CustomPainter`'s `repaint`, which is where
  /// the framework puts it on this SDK — there is no getter to override.
  ///
  /// Not `const`, unlike most [CustomPainter]s here, because [paint] holds the
  /// reused shader in a mutable field — see the class doc for why that field is
  /// worth having.
  LumenCanvas({
    required this.program,
    required this.uniforms,
    required LumenClock clock,
  }) : _clock = clock,
       super(repaint: clock);

  /// The clock `u_time` is read from.
  ///
  /// Held as a field as well as being handed to [repaint], because [paint] needs
  /// the **value** and `repaint` needs the **notification** — and reading the
  /// value out of a `Listenable` is not a thing one can do.
  final LumenClock _clock;

  /// [LumenCanvas.clock]'s value. See [_clock].
  LumenClock get clock => _clock;

  /// The compiled shader and the float layout to write it with.
  final LumenProgram program;

  /// Everything except `u_res` and `u_time`, which [resolveAt] supplies.
  final LumenUniforms uniforms;

  ui.FragmentShader? _shader;

  /// The shader [paint] reuses across frames, or null before the first paint.
  ///
  /// Test-only: the suite asserts [paint] allocates exactly once no matter how
  /// many frames it paints (see the class doc on why one), and instance
  /// identity is the only witness — identical pixels cannot tell one buffer
  /// from two. Production has no reader; the field is written in [paint] and
  /// read here.
  @visibleForTesting
  ui.FragmentShader? get debugShader => _shader;

  /// WHY [clock] IS THE ONLY SUBSCRIPTION, AND WHY IT IS NOT A
  /// `Listenable.merge`
  ///
  /// [repaint] exists so a background that is *alive* does not re-render the
  /// page — §13.1's D1 mitigation, and `neural_background.dart`'s
  /// `ListenableBuilder` is the other end of it. A `merge` would allocate and
  /// re-subscribe every frame, which is the allocation churn the collapse to
  /// three shared controllers was meant to remove, and it would have to include
  /// the uniform table — which is an immutable value, not a notification source.
  /// The only thing that changes without a rebuild is time, and time is the
  /// clock.

  /// The table that will actually be written for a rect of [size].
  ///
  /// Public, pure, and the seam every "what did the painter send" test reads.
  /// Making it public is not an invitation to call it from `paint` and cache the
  /// answer — `paint` is where it is called.
  @visibleForTesting
  LumenUniforms resolveAt(Size size) => uniforms.copyWith(
    resX: size.width,
    resY: size.height,
    time: clock.seconds,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // `drawRect` with an empty rect is a no-op on both renderers, but the
    // uniform writes are not: `min(u_res.x, u_res.y)` would be `0` and every
    // `uv` a division by zero. Nothing to paint is also nothing to divide.
    if (size.isEmpty) return;

    final LumenUniforms resolved = resolveAt(size);
    final ui.FragmentShader shader = _shader ??= program.newShader();

    shader
      // `u_res` — the LOGICAL size. See the class doc.
      ..setFloat(UniformSlot.uResX.index, resolved.resX)
      ..setFloat(UniformSlot.uResY.index, resolved.resY)
      // `u_time` — the clock's elapsed seconds, unwrapped. See
      // `LumenUniforms.time` and `lumen_canvas_test.dart`.
      ..setFloat(UniformSlot.uTime.index, resolved.time)
      ..setFloat(UniformSlot.uShape.index, resolved.shape.toDouble())
      ..setFloat(UniformSlot.uSpread.index, resolved.spread)
      ..setFloat(UniformSlot.uStr.index, resolved.rays)
      ..setFloat(UniformSlot.uPtrX.index, resolved.pointerX)
      ..setFloat(UniformSlot.uPtrY.index, resolved.pointerY)
      ..setFloat(UniformSlot.uPtrI.index, resolved.pointerIntensity)
      ..setFloat(UniformSlot.uInt.index, resolved.intensity)
      ..setFloat(UniformSlot.uSpike.index, resolved.spike)
      ..setFloat(UniformSlot.uHueX.index, resolved.hue.r)
      ..setFloat(UniformSlot.uHueY.index, resolved.hue.g)
      ..setFloat(UniformSlot.uHueZ.index, resolved.hue.b)
      ..setFloat(UniformSlot.uMelt.index, resolved.melt)
      ..setFloat(UniformSlot.uHue2X.index, resolved.hue2.r)
      ..setFloat(UniformSlot.uHue2Y.index, resolved.hue2.g)
      ..setFloat(UniformSlot.uHue2Z.index, resolved.hue2.b)
      ..setFloat(UniformSlot.uHue3X.index, resolved.hue3.r)
      ..setFloat(UniformSlot.uHue3Y.index, resolved.hue3.g)
      ..setFloat(UniformSlot.uHue3Z.index, resolved.hue3.b)
      ..setFloat(UniformSlot.uWhite.index, resolved.white)
      ..setFloat(UniformSlot.uLight.index, resolved.light)
      ..setFloat(UniformSlot.uDots.index, resolved.dots);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  /// Whether a change to any of the three inputs means a repaint is needed.
  ///
  /// [repaint] already covers the clock, so this only has to catch a **new**
  /// uniform table or a new program — the two things a rebuild can carry in.
  /// `uniforms` compares by value over all eighteen fields
  /// (`LumenUniforms.==`), and `program`/`clock` compare by identity because
  /// neither overrides `==`: a rebuilt painter holding the same two is the same
  /// painter as far as the engine is concerned.
  @override
  bool shouldRepaint(LumenCanvas oldDelegate) =>
      !identical(oldDelegate.program, program) ||
      !identical(oldDelegate.clock, clock) ||
      oldDelegate.uniforms != uniforms;

  @override
  String toString() =>
      'LumenCanvas(program: $program, time: ${clock.seconds} s)';
}
