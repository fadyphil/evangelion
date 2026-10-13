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

/// Which float index `FragmentShader.setFloat` actually takes for a uniform.
///
/// ## READ THIS BEFORE CHANGING ANYTHING HERE, BECAUSE IT CONTRADICTS
/// `lumen_uniforms.dart`'s DOC AND THE MEASUREMENT IS THE WHOLE POINT
///
/// [UniformSlot] is `impellerc --reflection-json`'s order — the front end's
/// SPIR-V `DecorationLocation` sort — and re-running that command here
/// reproduces it exactly:
///
/// ```sh
/// FL=<flutter>/bin/cache/artifacts/engine/linux-x64
/// "$FL/impellerc" --sksl --runtime-stage-gles --iplr --sl=/tmp/u.iplr \
///   --spirv=/tmp/u.spirv --reflection-json=/tmp/u.json \
///   --input=shaders/lumen.frag --input-type=frag \
///   --include=shaders --include="$FL/shader_lib"
/// ```
///
/// ```text
/// 0-1  u_res     2  u_time  3  u_shape  4  u_spread  5  u_str
/// 6-7  u_ptr     8  u_ptrI  9  u_int    10 u_spike
/// 11-13 u_hue   14 u_melt  15-17 u_hue2 18-20 u_hue3 21 u_white 22 u_light 23 u_dots
/// ```
///
/// **That order is not the order `setFloat` indexes.** Measured against an
/// independently written CPU implementation of the same shader maths
/// (`test/support/lumen_cpu_mirror.dart`), at 400×800 logical with the noise
/// term switched off:
///
/// | layout | worst per-channel error, 1 280 000 channels |
/// | --- | --- |
/// | [reflectionOrder] (`UniformSlot`) | **247** |
/// | [declarationOrder] (`shaders/lumen.frag:34-49`) | **1** |
///
/// One 8-bit step across the whole frame is a round trip, not a coincidence:
/// the same number came out of shapes 0, 1 and 2, of the scanline, melt and
/// daylight variants, and of five rect sizes from 40×40 to 400×800.
///
/// **Both renderers agree, and Impeller was actually running.** The default
/// `flutter test` path passes `--enable-software-rendering --skia-deterministic-rendering`
/// to `flutter_tester`; `--enable-impeller` replaces that with `--enable-impeller`
/// (`packages/flutter_tools/lib/src/test/flutter_tester_device.dart:114-116`).
/// Running the same comparison under that flag gives the *same* verdict — so
/// this is not a Skia-only quirk — and the flag is genuinely engaging a
/// different rasteriser: a `MaskFilter.blur` circle rasterises to centre byte
/// **47** under Skia and **45** under Impeller on the same machine.
/// (`--enable-impeller` runs on lavapipe here, so it is slow; it is a real
/// Impeller context, not a fallback.)
///
/// **So `UniformSlot` describes the reflection and the runtime buffer describes
/// the source.** Task 1.2 owns `lumen_uniforms.dart` and this task does not
/// change its table; what follows is the correction being *used*, not made.
/// Reconciling the two — most likely by correcting `UniformSlot` and deleting
/// this enum — is the next change that should touch that file, and it should
/// cite this table.
enum LumenSlotLayout {
  /// `shaders/lumen.frag:34-49` — the order the sixteen uniforms are declared.
  ///
  /// The default, because it is the order `setFloat` indexes on both renderers
  /// measured above. **Not** a preference: a wrong default renders the aurora in
  /// colours nobody chose, silently, and every golden of it would be a faithful
  /// record of a bug.
  declarationOrder,

  /// `impellerc --reflection-json`'s order, which is what [UniformSlot]
  /// enumerates.
  ///
  /// Present so the two tables can be told apart by a test rather than by
  /// memory, and so `lumen_uniforms_test.dart`'s twenty-four slot assertions
  /// remain about something reachable from production code. Painting with it is
  /// what produces the 247/255 frame.
  reflectionOrder,
}

/// `LumenSlotLayout.declarationOrder`'s twenty-four slots, in [UniformSlot]
/// order.
///
/// A table and not arithmetic because `u_hue`, `u_hue2` and `u_hue3` are
/// `vec3` and therefore occupy **three** consecutive floats with no padding
/// (measured: the shader renders correctly with these and not with a std140
/// four-float stride, which is the same measurement `lumen_uniforms_test.dart`
/// records for the other table), and because "the slot is a constant" is a
/// claim a test can check rather than an invariant the type system holds.
///
/// ## WHY THIS IS NOT DERIVED FROM `shaders/lumen.frag` AT LOAD TIME
///
/// It could be — the engine exposes `FragmentShader.getUniformFloat(name)`,
/// whose index is computed by walking `_uniformInfo` in order — and it is
/// still not used, because on this SDK it returns **0 for every uniform**:
/// `getUniformFloat('u_time').index`, `getUniformFloat('u_hue').index` and
/// `getUniformFloat('u_dots').index` all read `0`. (`_getUniformFloatInfo`'s
/// size half works — `getUniformFloat('u_res', 2)` correctly throws
/// "index should be less than 2" — so the name lookup is not absent, it is
/// returning the wrong index.) A layout that silently reads back as all-zeros
/// is worse than a table that can be read, diffed and reviewed, and reading it
/// at runtime would also make the painter untestable: a wrong answer would be
/// indistinguishable from a right one.
const List<int> kLumenDeclarationSlots = <int>[
  0, // u_res.x
  1, // u_res.y
  2, // u_time
  16, // u_shape — declared tenth of sixteen
  15, // u_spread
  13, // u_str
  21, // u_ptr.x
  22, // u_ptr.y
  23, // u_ptrI
  12, // u_int
  14, // u_spike
  3, // u_hue.r
  4, // u_hue.g
  5, // u_hue.b
  17, // u_melt
  6, // u_hue2.r
  7, // u_hue2.g
  8, // u_hue2.b
  9, // u_hue3.r
  10, // u_hue3.g
  11, // u_hue3.b
  19, // u_white
  20, // u_light
  18, // u_dots
];

/// The compiled `shaders/lumen.frag`, plus the float layout to write it with.
///
/// ## WHY THIS IS A CLASS AND NOT A BARE `ui.FragmentProgram`
///
/// Two reasons, and the second is the reason it is not just a static field.
///
/// * **The layout.** A `ui.FragmentProgram` knows nothing about float indices;
///   `slotFor` is what turns a [UniformSlot] into the number `setFloat` wants,
///   and where that number comes from is the whole subject of
///   [LumenSlotLayout]. Holding the two apart would put a `layout` parameter on
///   every paint instead of on one constructor.
/// * **The shader instance.** [LumenCanvas] must reuse **one**
///   `ui.FragmentShader` across frames — see its doc — and that instance has to
///   outlive a single frame, so something has to own it. A `LumenProgram` that
///   is memoised process-wide is that something, and it is also the one place
///   that could later swap in a fallback.
///
/// ## WHY `load` IS MEMOISED WHEN THE SDK ALREADY MEMOISES
///
/// `FragmentProgram.fromAsset` keeps a static `_shaderRegistry` keyed by the
/// asset key, so a second call is a map hit. That is an implementation detail
/// of `dart:ui`; holding a [LumenProgram] makes *this* app's sharing explicit
/// and, more usefully, makes it **observable**: `load()` returning the identical
/// instance twice is a thing a test can assert, whereas a bare
/// `fromAsset` call is indistinguishable from one that re-read the asset.
/// Keyed by `(asset, layout)` because the layout is part of what a program
/// means here — [kLumenShaderAsset] under [LumenSlotLayout.reflectionOrder] and
/// under [LumenSlotLayout.declarationOrder] are two different painters' worth of
/// behaviour out of one compiled blob.
class LumenProgram {
  /// Wraps an already-loaded program. Private: [load] is the only way in, so
  /// nobody can hold a program whose layout was never decided.
  LumenProgram._(this.asset, this.layout, this._program);

  /// The asset key this was loaded from, kept for [toString] and for a failure
  /// message that has to name a file.
  final String asset;

  /// Which float layout [slotFor] answers in.
  final LumenSlotLayout layout;

  final ui.FragmentProgram _program;

  static final Map<(String, LumenSlotLayout), LumenProgram> _memoised =
      <(String, LumenSlotLayout), LumenProgram>{};

  /// Loads — and thereafter returns — the program for [asset] under [layout].
  ///
  /// `async` rather than a cached future so a **failed** load is not memoised:
  /// a cached `Future` that completed with an error would turn a transient
  /// asset-availability failure into a permanent one for the life of the
  /// process, and the only recovery would be a restart. `FragmentProgram`'s own
  /// static registry means a concurrent second caller still gets one program
  /// object out of the engine; only this wrapper is per-call.
  static Future<LumenProgram> load({
    String asset = kLumenShaderAsset,
    LumenSlotLayout layout = LumenSlotLayout.declarationOrder,
  }) async {
    final LumenProgram? memoized = _memoised[(asset, layout)];
    if (memoized != null) return memoized;
    final LumenProgram loaded = LumenProgram._(
      asset,
      layout,
      await ui.FragmentProgram.fromAsset(asset),
    );
    _memoised[(asset, layout)] = loaded;
    return loaded;
  }

  /// A **fresh** `FragmentShader` with a zero-filled uniform buffer.
  ///
  /// "Fresh" is the point and the cost: every call allocates a new uniform
  /// buffer, which is why [LumenCanvas] calls this **once** and mutates the
  /// result. The SDK's own note on `FragmentShader` says the same thing —
  /// *"A FragmentShader can be re-used, and this is an efficient way to avoid
  /// allocating and re-initializing the uniform buffer and samplers"*.
  ui.FragmentShader newShader() => _program.fragmentShader();

  /// The `setFloat` index for [slot] under [layout].
  ///
  /// A method on the program rather than a free function or an extension so the
  /// painter cannot accidentally use the layout of a program it does not hold,
  /// and so "the slot does not depend on the table's contents" stays checkable:
  /// `lumen_uniforms_test.dart` asserts the equivalent for `UniformSlot`, and
  /// this test asserts it here for the layout that is actually painted.
  int slotFor(UniformSlot slot) => switch (layout) {
    LumenSlotLayout.declarationOrder => kLumenDeclarationSlots[slot.index],
    LumenSlotLayout.reflectionOrder => slot.index,
  };

  /// Names the program, its asset and its layout — the three things a
  /// `Bad state: Cannot set a uniform on a disposed shader` does not.
  @override
  String toString() => 'LumenProgram(asset: $asset, layout: ${layout.name})';
}
