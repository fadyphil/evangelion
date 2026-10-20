import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';

/// The asset key `pubspec.yaml`'s `shaders:` stanza compiles
/// `shaders/lumen.frag` to.
///
/// A constant rather than a literal at the call site because there are now two
/// places that must agree on the string — [LumenProgram.load]'s default and
/// anything that wants to load the same program by hand — and a shader that
/// failed to load reports *"unable to load asset"*, which names neither.
const String kLumenShaderAsset = 'shaders/lumen.frag';

/// The compiled `shaders/lumen.frag`.
///
/// ## WHY THIS IS A CLASS AND NOT A BARE `ui.FragmentProgram`
///
/// Two reasons, and the second is the reason it is not just a static field.
///
/// * **The shader instance.** [LumenCanvas] must reuse **one**
///   `ui.FragmentShader` across frames — see its doc — and that instance has to
///   outlive a single frame, so something has to own it. A `LumenProgram` that
///   is memoised process-wide is that something, and it is also the one place
///   that could later swap in a fallback.
/// * **The sharing is observable.** See below.
///
/// ## WHY `load` IS MEMOISED WHEN THE SDK ALREADY MEMOISES
///
/// `FragmentProgram.fromAsset` keeps a static `_shaderRegistry` keyed by the
/// asset key, so a second call is a map hit. That is an implementation detail
/// of `dart:ui`; holding a [LumenProgram] makes *this* app's sharing explicit
/// and, more usefully, makes it **observable**: `load()` returning the identical
/// instance twice is a thing a test can assert, whereas a bare
/// `fromAsset` call is indistinguishable from one that re-read the asset.
/// Keyed by asset because two asset keys are two different programs; there is
/// deliberately no second key, because production has exactly one float layout
/// and it lives in [UniformSlot], not here.
///
/// ## WHERE THE FLOAT LAYOUT WENT
///
/// An earlier revision of this file carried a `LumenSlotLayout` enum with two
/// production layouts — declaration order and `--reflection-json` order — plus
/// a `slotFor` that translated between them and a `load` that took the layout
/// as a parameter. That made `reflectionOrder` a public API for painting
/// garbage: it renders a frame wrong by up to 247 of 255 levels, silently.
/// Task 1.3b deleted it. Call sites write `slot.index` directly now — the enum
/// position IS the `setFloat` index, by construction — and the suite pins that
/// three ways: enum `index == position` for all twenty-four, per-uniform
/// `shaderIndex` from the engine's own bookkeeping, and the render test.
///
/// ## WHY THE LAYOUT IS NOT DERIVED AT LOAD TIME, AND THE MISREAD THIS
/// ## SECTION CORRECTS
///
/// It could be — the engine exposes `FragmentShader.getUniformFloat(name)` —
/// and an earlier revision of this section said it is not used because
/// `getUniformFloat('u_time').index` reads `0` for every uniform, "returning
/// the wrong index".
///
/// That reading was wrong, and the field name is why. `UniformFloatSlot.index`
/// is *"the offset into the bound uniform — 1 for `.y`, 2 for `.b`"*
/// (`painting.dart`): it is the **component** offset, so it reads `0` for every
/// single-component lookup *by design*, and `u_hue[1]` reads `1`. The real
/// `setFloat` index is the `VisibleForTesting` **`shaderIndex`** —
/// `info.index + slot.index`, the engine's own float position — and a probe
/// confirmed all sixteen uniforms read exactly the declaration positions this
/// package paints with, while `u_nope` throws `"No uniform named"` and
/// `u_res[2]` throws `"index should be less than 2"`. Name lookup and sizes
/// work; only the field choice was wrong. The engine is not broken.
///
/// The section is kept rather than deleted because the misread is the exact
/// shape of the next one: any future reader reaching for `.index` to "derive"
/// the layout will get twenty-four zeroes and, without this paragraph, will
/// conclude the engine is broken in the opposite direction. The layout is
/// still a hand-written table — [UniformSlot] — because a table can be read,
/// diffed and reviewed, and because deriving it at runtime would make the
/// painter untestable: a wrong answer would be indistinguishable from a right
/// one. The `shaderIndex` test in `lumen_canvas_test.dart` is the cheap,
/// engine-backed pin that a derived table would have been.
class LumenProgram {
  /// Wraps an already-loaded program. Private: [load] is the only way in.
  LumenProgram._(this.asset, this._program);

  /// The asset key this was loaded from, kept for [toString] and for a failure
  /// message that has to name a file.
  final String asset;

  final ui.FragmentProgram _program;

  static final Map<String, LumenProgram> _memoised = <String, LumenProgram>{};

  /// Loads — and thereafter returns — the program for [asset].
  ///
  /// `async` rather than a cached future so a **failed** load is not memoised:
  /// a cached `Future` that completed with an error would turn a transient
  /// asset-availability failure into a permanent one for the life of the
  /// process, and the only recovery would be a restart. `FragmentProgram`'s own
  /// static registry means a concurrent second caller still gets one program
  /// object out of the engine; only this wrapper is per-call.
  static Future<LumenProgram> load({String asset = kLumenShaderAsset}) async {
    final LumenProgram? memoized = _memoised[asset];
    if (memoized != null) return memoized;
    final LumenProgram loaded = LumenProgram._(
      asset,
      await ui.FragmentProgram.fromAsset(asset),
    );
    _memoised[asset] = loaded;
    return loaded;
  }

  /// The already-loaded program for [asset], or null when it is not loaded.
  ///
  /// ## WHY A **SYNCHRONOUS** PEEK AND NOT JUST `await load()`
  ///
  /// Because a background that has to `await` before it can paint shows the
  /// **fallback** for a frame or two and then swaps — a visible flash of the
  /// old design at every launch, and a golden that captured whichever of the
  /// two it happened to catch.
  ///
  /// The app loads the program during bootstrap (`lib/app/bootstrap.dart`), so
  /// by the time the first frame is built the memo is populated and this
  /// returns the program with no await and no flash. A caller that gets null
  /// has a program still in flight, and the fallback is the honest thing to
  /// paint until it arrives.
  ///
  /// **It returns the same instance [load] would.** The memo is the same map,
  /// so there is one program in the process and this is a read of it.
  static LumenProgram? loaded({String asset = kLumenShaderAsset}) =>
      _memoised[asset];

  /// A **fresh** `FragmentShader` with a zero-filled uniform buffer.
  ///
  /// "Fresh" is the point and the cost: every call allocates a new uniform
  /// buffer, which is why [LumenCanvas] calls this **once** and mutates the
  /// result. The SDK's own note on `FragmentShader` says the same thing —
  /// *"A FragmentShader can be re-used, and this is an efficient way to avoid
  /// allocating and re-initializing the uniform buffer and samplers"*.
  ui.FragmentShader newShader() => _program.fragmentShader();

  /// Names the program and its asset — the two things a
  /// `Bad state: Cannot set a uniform on a disposed shader` does not.
  @override
  String toString() => 'LumenProgram(asset: $asset)';
}
