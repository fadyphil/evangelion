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
///
/// ## WHY THERE IS A **SOURCE** AND NOT ONLY A TABLE
///
/// Because the prototype's uniforms change **every frame**. Its render loop
/// (`eva/redesign.html:887-912`) eases the hue at 4.5% a frame, the ambient
/// intensity at 6% and decays the spike at 0.92 — so the table a frame paints
/// is not the table the previous frame painted.
///
/// A table held in a constructor field cannot do that. The painter would have
/// to be **rebuilt** every frame to carry the new values, and a rebuilt painter
/// is a new instance, and a new instance allocates a new `FragmentShader` — the
/// per-frame uniform buffer that the class doc above exists to remove. The
/// allocation would come back through the front door.
///
/// So the table is read at **paint time**, from a [LumenUniformSource], and the
/// painter is long-lived: one instance, one shader, one uniform buffer, and the
/// values written into it change underneath it. The source is also the
/// painter's `repaint` signal, and it is the source — not the clock — because
/// the source advances **before** it notifies, and a paint that raced the
/// advance would paint the previous frame's values.
class LumenCanvas extends CustomPainter {
  /// Paints a fixed [uniforms] table with [clock]'s time.
  ///
  /// [clock] is handed straight to `CustomPainter`'s `repaint`, which is where
  /// the framework puts it on this SDK — there is no getter to override.
  ///
  /// This is the **fixed** source: the table is whatever it was at
  /// construction, and the only thing that varies is `u_time`. It is what the
  /// goldens and the frame tests use, and it is what every caller that has a
  /// table rather than a scene wants.
  ///
  /// Not `const`, unlike most [CustomPainter]s here, because [paint] holds the
  /// reused shader in a mutable field — see the class doc for why that field is
  /// worth having.
  LumenCanvas({
    required LumenProgram program,
    required LumenUniforms uniforms,
    required LumenClock clock,
  }) : this.source(
         program: program,
         source: FixedLumenUniforms(uniforms, clock),
       );

  /// Paints whatever [source] says, at paint time.
  ///
  /// The seam the mounted aurora uses. [source] is both the table and the
  /// repaint signal, so a source that advances its table and then notifies
  /// paints the frame it just computed.
  LumenCanvas.source({
    required this.program,
    required LumenUniformSource source,
  }) : _source = source,
       super(repaint: source);

  /// The table source, and the repaint signal.
  final LumenUniformSource _source;

  /// The source this painter reads its table from.
  ///
  /// Public because [shouldRepaint] compares it and because a caller holding a
  /// painter wants to know whether two painters would paint the same thing.
  LumenUniformSource get source => _source;

  /// The clock `u_time` is read from.
  ///
  /// Held by the source as well as being handed to [repaint], because [paint]
  /// needs the **value** and `repaint` needs the **notification** — and
  /// reading the value out of a `Listenable` is not a thing one can do.
  LumenClock get clock => _source.clock;

  /// The compiled shader and the float layout to write it with.
  final LumenProgram program;

  /// The one reused shader. Held, never disposed — and that is the contract.
  ///
  /// `CustomPainter` offers no disposal hook, so there is nowhere to put a
  /// `dispose()` call that the framework would honour — and none is needed to
  /// be correct: the wrapper is GC-managed, so a discarded painter takes its
  /// native peer with it rather than stranding GPU state. Eager disposal
  /// would only release sooner, which matters for long-lived holders, not for
  /// a painter the framework rebuilds away.
  ///
  /// What this field does NOT promise is cross-frame reuse by itself. The
  /// `??=` pays off only across multiple `paint()` calls on ONE instance; a
  /// painter rebuilt per notification — the `ListenableBuilder` pattern in
  /// `neural_background.dart:294-310` constructs a fresh painter every frame —
  /// allocates one buffer per frame regardless. **Whoever wires this painter
  /// must hold one `LumenCanvas` across frames to realize hard rule 2**;
  /// otherwise the rule holds in the letter and not in the spirit.
  ///
  /// The [LumenUniformSource] seam above is what makes that possible for a
  /// table that changes every frame: the painter stays the same instance and
  /// reads the new values at paint time.
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

  /// WHY THE **SOURCE** IS THE ONLY SUBSCRIPTION, AND WHY IT IS NOT A
  /// `Listenable.merge`
  ///
  /// [repaint] exists so a background that is *alive* does not re-render the
  /// page — §13.1's D1 mitigation, and `neural_background.dart`'s
  /// `ListenableBuilder` is the other end of it. A `merge` would allocate and
  /// re-subscribe every frame, which is the allocation churn the collapse to
  /// three shared controllers was meant to remove, and it would have to include
  /// the uniform table — which is an immutable value, not a notification source.
  /// The only things that change without a rebuild are time and the eased
  /// values, and both live behind the one source.

  /// The table that will actually be written for a rect of [size].
  ///
  /// Public, pure, and the seam every "what did the painter send" test reads.
  /// Making it public is not an invitation to call it from `paint` and cache the
  /// answer — `paint` is where it is called.
  @visibleForTesting
  LumenUniforms resolveAt(Size size) => source.tableAt(size);

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
  /// [repaint] already covers the source, so this only has to catch a **new**
  /// source or a new program — the two things a rebuild can carry in.
  /// [LumenUniformSource] compares by value over the table it holds and the
  /// clock it reads (see [FixedLumenUniforms.==]), and `program` compares by
  /// identity because it does not override `==`: a rebuilt painter holding the
  /// same two is the same painter as far as the engine is concerned.
  ///
  /// For the mounted aurora the source is the **scene**, whose identity is
  /// stable for the life of the app, so this returns false for a rebuild that
  /// changed nothing — and the repaint that a changed table needs comes from
  /// the scene's own notification rather than from here.
  @override
  bool shouldRepaint(LumenCanvas oldDelegate) =>
      !identical(oldDelegate.program, program) || oldDelegate.source != source;

  @override
  String toString() =>
      'LumenCanvas(program: $program, time: ${clock.seconds} s)';
}

/// Where a [LumenCanvas] reads the uniform table it paints.
///
/// ## WHY IT IS A `Listenable` AND NOT JUST A FUNCTION
///
/// Because the source is also the painter's **repaint signal**, and the two
/// have to be the same object for the frame to be right. A source advances its
/// table and *then* notifies; a paint triggered by that notification reads the
/// table the source just computed. If the repaint signal were the clock — the
/// source being merely a function of it — the paint would race the advance,
/// and which of the two won would depend on the order the listeners happened
/// to be registered in. That is a race that produces a one-frame-old aurora on
/// some machines and not on others, which is the kind of defect no assertion
/// catches.
///
/// ## WHY IT EXTENDS `Listenable` RATHER THAN INHERITING `ChangeNotifier`
///
/// A source that has no state of its own has nothing to notify about, and
/// [ChangeNotifier] would give it a listener list it never uses. [FixedLumenUniforms]
/// forwards to its clock instead, so the painter's `repaint` lands on the same
/// notifier it landed on before the seam existed.
abstract interface class LumenUniformSource extends Listenable {
  /// The clock whose seconds are the shader's `u_time`.
  ///
  /// The source owns it, because the source is what decides what `u_time` is:
  /// a fixed source reads the clock it was given, and the scene reads the
  /// clock it ticks from.
  LumenClock get clock;

  /// The table to paint for a rect of [size].
  ///
  /// Called **at paint time**, never cached. A cached answer would be the
  /// previous frame's table, which is the defect the seam exists to remove.
  LumenUniforms tableAt(Size size);
}

/// A source that never changes: one table, and a clock for its `u_time`.
///
/// The [LumenUniformSource] behind [LumenCanvas]'s ordinary constructor. It is
/// what a caller with a table rather than a scene wants, and it keeps the
/// painter's behaviour — the clock as the repaint signal, the table as the
/// constructor argument — exactly as it was before the seam existed.
final class FixedLumenUniforms implements LumenUniformSource {
  /// Holds [uniforms] and reads `u_time` from [clock].
  FixedLumenUniforms(this.uniforms, this.clock);

  /// The table every frame paints.
  final LumenUniforms uniforms;

  /// The clock `u_time` is read from.
  @override
  final LumenClock clock;

  @override
  LumenUniforms tableAt(Size size) => uniforms.copyWith(
    resX: size.width,
    resY: size.height,
    time: clock.seconds,
  );

  @override
  void addListener(VoidCallback listener) => clock.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => clock.removeListener(listener);

  /// Two fixed sources are the same when they hold the same table and the same
  /// clock.
  ///
  /// The table compares by value over all eighteen fields
  /// (`LumenUniforms.==`) and the clock by identity, because it does not
  /// override `==`. That is what makes [LumenCanvas.shouldRepaint] answer
  /// "an identical table is not a change" for two separately constructed
  /// painters, exactly as it did when the table was a constructor field.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixedLumenUniforms &&
          other.uniforms == uniforms &&
          identical(other.clock, clock);

  @override
  int get hashCode => Object.hash(uniforms, identityHashCode(clock));

  @override
  String toString() => 'FixedLumenUniforms(${uniforms.toString()})';
}
