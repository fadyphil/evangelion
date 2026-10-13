import 'dart:math' as math;

/// One float in the Lumen runtime shader's uniform buffer, named.
///
/// ## WHY THIS EXISTS AT ALL, GIVEN THAT `.frag` ALREADY DECLARES EVERY UNIFORM
///
/// `FragmentShader.setFloat(i, v)` takes an **index**, and that index is the
/// uniform's float position in the runtime buffer — which is the order the
/// shader **declares** them in. The engine lays the buffer out in declaration
/// order and says so itself (`impeller/entity/contents/runtime_effect_contents.
/// cc:290-298`): *"Uniforms are ordered in the IPLR according to their
/// declaration … Since we know that the declarations are already ordered, we
/// can track the uniform location ourselves."*
///
/// ## THE JSON DISCREPANCY, STATED SO NOBODY RE-DERIVES IT
///
/// Re-running `impellerc --reflection-json` reproduces a *different* order:
///
/// ```sh
/// # `impellerc` lives at <flutter>/bin/cache/artifacts/engine/<platform>/
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
/// That order (call it S) is real compiler output and is **not** the runtime
/// order: it is built from `shader_resources.gl_plain_uniforms` — raw SPIR-V
/// ID order (`impeller/compiler/reflector.cc:231-237`) — while the
/// iplr-embedded uniform lists go through `SortUniforms`
/// (`reflector.cc:389-432`), whose stated intent is declaration order. Painting
/// with S produces a frame wrong by up to **247 of 255** levels against the CPU
/// mirror; painting with the declaration order below gives **1**. An earlier
/// revision of this enum pinned S (misreading the sort as the runtime order),
/// and the render test caught it — so the negative control that paints S lives
/// on in `lumen_canvas_test.dart` as hard-coded raw indices, and this enum
/// will never name S again.
///
/// ## WHY `.index` IS THE SLOT AND NOTHING ENFORCES THAT
///
/// This enum is declared in slot order, so a Dart enum's built-in `index` — the
/// position in [Enum.values] — is the slot. The type system cannot help here:
/// an enum may not redeclare `index` at all.
///
/// ```text
/// error • illegal_concrete_enum_member
///        A concrete instance member named 'index' can't be declared in a class
///        that implements 'Enum'.
/// ```
///
/// So "the member written fourth is the one at slot 3" is a **convention**
/// and only the suite keeps it honest —
/// `test/core/design_system/effects/lumen_uniforms_test.dart` asserts
/// `slot.index == UniformSlot.values.indexOf(slot)` for all twenty-four, plus
/// the Task 1.2 Step 1 constants themselves, plus — cheapest of the three —
/// the engine's own per-uniform `shaderIndex` bookkeeping in
/// `lumen_canvas_test.dart`. Insert a member in the wrong place and all three
/// fail; the enum cannot be its own gate.
///
/// ## WHY EACH MEMBER REPEATS ITS UNIFORM'S NAME
///
/// [uniform] is the GLSL identifier, so a reader holding this enum next to
/// `shaders/lumen.frag` can check a name without guessing which member means
/// `u_ptrI`. The three components of one `vec3`/`vec2` carry the **same** name,
/// deliberately: they are one uniform and the repetition is the honest reading.
/// It also gives the suite a second axis — the shader's sixteen *names* — to
/// pin the slot table against, so a wrong slot is distinguishable from a
/// misspelled uniform.
enum UniformSlot {
  /// `u_res.x` — the paint rect's **logical** width, in pixels.
  uResX('u_res'),

  /// `u_res.y` — the paint rect's logical height.
  uResY('u_res'),

  /// `u_time` — accumulated seconds, already scaled by `0.30` inside the shader.
  uTime('u_time'),

  /// `u_hue.r`
  uHueX('u_hue'),

  /// `u_hue.g`
  uHueY('u_hue'),

  /// `u_hue.b`
  uHueZ('u_hue'),

  /// `u_hue2.r` — the second colour the melt oscillates between.
  uHue2X('u_hue2'),

  /// `u_hue2.g`
  uHue2Y('u_hue2'),

  /// `u_hue2.b`
  uHue2Z('u_hue2'),

  /// `u_hue3.r` — the third colour the melt oscillates between.
  uHue3X('u_hue3'),

  /// `u_hue3.g`
  uHue3Y('u_hue3'),

  /// `u_hue3.b`
  uHue3Z('u_hue3'),

  /// `u_int` — the ambient intensity the band is multiplied by.
  uInt('u_int'),

  /// `u_str` — how strongly the fbm noise perturbs the rays. The prototype's
  /// Workshop control is labelled "Rays".
  uStr('u_str'),

  /// `u_spike` — the transient kick a hue or shape change adds to `u_int`.
  uSpike('u_spike'),

  /// `u_spread` — how far the band reaches, and how soft its edge is.
  uSpread('u_spread'),

  /// `u_shape` — `0` top, `1` bottom, `2` sides, `3` shafts.
  ///
  /// The prototype labels the same four values `['top','bottom','sides',
  /// 'shafts']` (`redesign.html:1463`) and the shader branches on them at `0.5`
  /// / `1.5` / `2.5`, so the last one has no branch of its own: it is the
  /// `else` arm.
  uShape('u_shape'),

  /// `u_melt` — `> 0.5` blends the three hues; `0` uses `u_hue` alone.
  uMelt('u_melt'),

  /// `u_dots` — the 6px scanline modulation, `> 0.5` to enable.
  uDots('u_dots'),

  /// `u_white` — how much white-hot core the band carries.
  uWhite('u_white'),

  /// `u_light` — daylight mode; `0` dark, `1` light.
  uLight('u_light'),

  /// `u_ptr.x` — pointer position, normalised by the rect's short side.
  uPtrX('u_ptr'),

  /// `u_ptr.y` — pointer position, normalised by the rect's short side, and
  /// **inverted**, because the WebGL original measures from the bottom.
  uPtrY('u_ptr'),

  /// `u_ptrI` — the peak gain of the touch glow.
  uPtrI('u_ptrI');

  const UniformSlot(this.uniform);

  /// The GLSL identifier this slot belongs to, exactly as
  /// `shaders/lumen.frag` spells it.
  final String uniform;
}

/// An sRGB triple, each channel in `0..1`.
///
/// A class and not a `(double, double, double)` record because every consumer
/// reads the channels by **name** — `uniforms.hue.r` — and a positional
/// `hue.$1` at a call site that is writing into slot 11 is a triple this app has
/// already paid for once, in a shader that did not compile.
///
/// Equality and [hashCode] are hand-written because `equatable` is gone from
/// this package (AGENT_CONTEXT decision 131) and `==` on a `List` payload is
/// identity in every implementation there was.
class HslRgb {
  /// A triple in `0..1`.
  const HslRgb({required this.r, required this.g, required this.b});

  /// Red.
  final double r;

  /// Green.
  final double g;

  /// Blue.
  final double b;

  /// All three channels decide equality.
  ///
  /// The `runtimeType` guard is [Failure]'s, kept for [Failure]'s reason: it
  /// keeps a hypothetical other `HslRgb`-shaped type from equalling this one,
  /// and keeps the pair's hash distinct from the pair `==` rejects.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HslRgb &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          g == other.g &&
          b == other.b;

  /// Agrees with `==`, for the reason on it.
  @override
  int get hashCode => Object.hash(r, g, b);

  /// Renders the channels as written, to six places, because a hue converted
  /// and printed at the default precision reads as a wrong hue.
  @override
  String toString() =>
      'HslRgb(${r.toStringAsFixed(6)}, '
      '${g.toStringAsFixed(6)}, ${b.toStringAsFixed(6)})';
}

/// HSL → sRGB in `0..1`, ported from `redesign.html:879-880` **verbatim in
/// structure**.
///
/// The prototype's own one-liner, with its variable names kept so the two can be
/// read side by side:
///
/// ```js
/// function hsl2rgb(h,s,l){ s/=100;l/=100; const k=n=>(n+h/30)%12;
///   const a=s*Math.min(l,1-l);
///   const f=n=>l-a*Math.max(-1,Math.min(k(n)-3,Math.min(9-k(n),1)));
///   return [f(0),f(8),f(4)]; }
/// ```
///
/// ## WHY A VERBATIM PORT AND NOT THE TEXTBOOK ALGORITHM
///
/// The sextant version — `C`, `X`, `m`, and a six-case switch — is four lines
/// longer and about twice as fast. Neither reason matters at three calls a
/// frame, and both are the wrong reason anyway: this file's value is that a
/// reviewer can hold it against `redesign.html:879-880` and see there is
/// nothing to argue about. **A reimplementation of a prototype function is a
/// second source of truth**, and this one is twenty characters long.
///
/// The branchless shape is also what the prototype means, not an accident of
/// golf: `f(0)`, `f(8)` and `f(4)` sample the wheel at 120° apart precisely so
/// the three returned channels land in `r`, `g`, `b` order without a lookup.
///
/// ## `h` IS A HUE IN DEGREES, `s` AND `l` ARE PERCENT
///
/// Percentages, not fractions, because that is what the prototype passes and
/// what its own callers hold: `redesign.html:881` opens at
/// `{h:258,s:90,l:66}` and the hue slider posts `s:70, l:62`.
///
/// **`h` is taken modulo the wheel and is total.** JavaScript's `%` keeps the
/// dividend's sign, so the prototype's `k` returns a negative hue for a negative
/// `h`; Dart's does not. No prototype call site produces a hue outside
/// `[0, 360)`, so this is a property of the port rather than a behaviour change
/// — and it is worth stating, because the alternative repair ("match JS, take
/// the absolute value") is a bug someone would introduce trying to be faithful.
///
/// ## WHAT THIS IS NOT
///
/// Not a colour-space conversion. `hsl2rgb` in the prototype is also the name of
/// a CSS function, and the two agree; but nothing here does gamma, and the
/// shader multiplies the result straight into `fragColor` with no clamp.
HslRgb hslToRgb({required double h, required double s, required double l}) {
  final double sat = s / 100;
  final double lum = l / 100;
  double k(double n) => (n + h / 30) % 12;
  final double a = sat * math.min(lum, 1 - lum);
  double f(double n) =>
      lum - a * math.max(-1, math.min(k(n) - 3, math.min(9 - k(n), 1)));
  return HslRgb(r: f(0), g: f(8), b: f(4));
}

/// How far the band reaches, from the Workshop's "Reach" slider.
///
/// `redesign.html:1469`, one expression: `e.target.value/100`. The slider runs
/// `min="18" max="110" value="42"` (`redesign.html:658`), so the default is
/// `0.42` — which is also what the prototype writes directly at
/// `redesign.html:1502`.
///
/// **Not clamped here.** The prototype does not clamp, and a clamp would make
/// a slider bug render as a shader that ignores the user rather than as a
/// number that is visibly wrong in a control's own value.
double spreadFromReach(double slider) => slider / 100;

/// The ambient brightness multiplier, from the Workshop's "Brightness" slider.
///
/// `redesign.html:1470`, one expression: `bright=e.target.value/100`, from a
/// slider running `min="40" max="130" value="100"` (`redesign.html:659`), so
/// the default is `1.0`.
///
/// ## THIS IS **NOT** A UNIFORM, AND THAT IS THE POINT OF THE SEPARATE NAME
///
/// `bright` is a JavaScript variable (`redesign.html:884`), folded into the
/// ambient intensity at `redesign.html:891` as
/// `ambBase*bright*vesp*(focusDim?0.45:1)` and **never sent to the GPU**. There
/// is no slot for it in [UniformSlot], and there must not be one: a caller that
/// reached for `UniformSlot` here would find nothing and, worse, someone
/// eventually would add a slot for it and multiply the band by the brightness
/// twice.
double brightnessFromGlow(double slider) => slider / 100;

/// The touch glow's peak gain, from the Workshop's "Touch glow" slider.
///
/// `redesign.html:1471`: `(e.target.value/100)*0.6`, from a slider running
/// `min="0" max="100" value="55"` (`redesign.html:660`), so the default is
/// `0.33` — the prototype writes that literal itself at `redesign.html:1504`.
///
/// **The `0.6` is not a unit conversion**, which is why this is a function and
/// not the same `/100` as [spreadFromReach] and [brightnessFromGlow]. It is the
/// ceiling the glow may reach: at slider `100` the band gains `0.6`, not `1.0`.
/// A port that shared one `/100` helper across all three would be 40% too
/// bright on every tap, and the mistake is invisible because nothing clamps.
double ptrIntensityFromTouch(double slider) => (slider / 100) * 0.6;

/// One frame of spike decay.
///
/// `redesign.html:900` is `V.spike*=0.92;`, the eleventh line of the render
/// loop and the only thing that touches the spike without a user action.
///
/// **Frame-based, not time-based, and that is a real limitation rather than a
/// transcription detail.** `0.92` is applied once per `requestAnimationFrame`, so
/// at 120Hz the spark dies in half the wall-clock time it does at 60Hz. This
/// function reproduces the prototype exactly and says so; a caller that wants a
/// duration rather than a rate has to supply one, and there is deliberately no
/// time parameter here to tempt a single global "decay" helper into existence.
///
/// Applied as `u.copyWith(spike: decaySpike(u.spike))` — the table is immutable,
/// so the loop owns the running value and this is a pure step in it.
double decaySpike(double spike) => spike * 0.92;

/// The second hue's hue angle, `h + 38` wrapped onto the wheel.
///
/// `redesign.html:902` is `hsl2rgb((curH.h+38)%360, …)`. Kept as its own
/// function so the wrap is visible and testable rather than a `%` buried in an
/// argument list.
double _hue2Degrees(double h) => (h + 38) % 360;

/// The third hue's hue angle, `h - 42` wrapped onto the wheel.
///
/// `redesign.html:903` is `hsl2rgb((curH.h-42+360)%360, …)`.
///
/// The `+ 360` exists in the prototype because JavaScript's `%` keeps the
/// dividend's sign and `h - 42` is negative for every `h` under 42°. It is kept
/// rather than tidied away so the two expressions are the same expression; in
/// Dart it is a no-op, because the operand is already positive for the
/// prototype's `[0, 360)` domain.
double _hue3Degrees(double h) => (h - 42 + 360) % 360;

/// The second hue's lightness: the base lifted by 6 points, **capped at 88**.
///
/// `redesign.html:902` is `Math.min(curH.l+6, 88)`.
///
/// The cap is the load-bearing half of that expression and it never fires at the
/// prototype's own lightness of 66, so a port that dropped it would be
/// indistinguishable until someone raised the lightness slider — and then
/// `hue2` would run to white and the melt would lose the colour it exists to
/// show. It is a separate function rather than an inline `math.min` for that
/// reason: a reader should not have to reconstruct the argument list to see
/// that there is a ceiling in it.
double _hue2Lightness(double l) => math.min(l + 6, 88);

/// The sixteen Lumen uniforms as one immutable value.
///
/// ## WHY IT IS PURE DART
///
/// Its only import is `dart:math`. Nothing here needs `package:flutter`,
/// `dart:ui`, `dio` or `http` — there is no `Color`, no `Offset` and no `Size`
/// in the sixteen uniforms, because the shader takes its resolution as `vec2`
/// and its pointer as `vec2` and knows nothing about Flutter's coordinate space.
/// That is also what lets Task 1.3's clock and a settings cubit hold one without
/// either reaching sideways.
///
/// **Honest note on the gate:** `tool/verify_purity.sh` Gate 1 scans
/// `core/domain`, `core/common`, `core/navigation` and every
/// `features/*/domain`. `core/design_system/effects/` is **not** among them, so
/// this file's Flutter-freedom is by construction and by review, not by a
/// passing gate. It is called out here rather than left as an assumption, which
/// is the recorded-decision-33 lesson applied to a property that currently has
/// no instrument.
///
/// ## THE HUE TRIPLE IS DERIVED, AND `copyWith` REFUSES TO SET IT
///
/// `hue2` and `hue3` are functions of `hue` (`redesign.html:902-903`), so a
/// `copyWith(hue: …)` would be a door to a table the prototype cannot produce —
/// three hues that agree with nothing. [withHue] is the only way to change them,
/// and it recomputes all three, and [copyWith] deliberately has no hue parameter
/// at all rather than having one that is easy to misuse.
///
/// ## WHAT `identity()` IS **NOT**
///
/// Not the prototype's own initial uniform table. `redesign.html:872-877` opens
/// with `str=1`, `spread=.42`, `shape=0`, `white=.22`, `ptr=(-10,-10)`,
/// `ptrI=.33` and the rest — but those are **Workshop defaults**: the values of
/// the sliders on `redesign.html:658-660` and the checkboxes beside them, not a
/// neutral state. An additive identity for a uniform table is every scalar at
/// zero, and that is what a caller building a table it has not decided yet
/// should get. The Workshop's defaults belong to whatever constructs the first
/// real table, and the numbers are transcribed there.
///
/// ## `slot()` IS AN INSTANCE METHOD AND THAT IS THE WHOLE REASON FOR IT
///
/// So a painter writes `uniforms.slot(UniformSlot.uHueX)` with one receiver
/// rather than `UniformSlot.uHueX.index` — the call site that appears twenty
/// times per frame reads better with the table in hand, and it costs a `this`
/// that is already in a register. It also makes "the slot is a constant and
/// never depends on the table's contents" a *claim* the suite can check, which
/// it does: a lookup that read a field would pass every constant asserted against
/// [identity] and still be wrong on the table actually painted.
class LumenUniforms {
  /// Creates a table. Every parameter defaults to [identity]'s value, so
  /// `const LumenUniforms()` **is** the identity table.
  const LumenUniforms({
    this.resX = 0,
    this.resY = 0,
    this.time = 0,
    this.shape = 0,
    this.spread = 0,
    this.rays = 0,
    this.pointerX = 0,
    this.pointerY = 0,
    this.pointerIntensity = 0,
    this.intensity = 0,
    this.spike = 0,
    this.hue = const HslRgb(r: 0, g: 0, b: 0),
    this.hue2 = const HslRgb(r: 0, g: 0, b: 0),
    this.hue3 = const HslRgb(r: 0, g: 0, b: 0),
    this.melt = 0,
    this.white = 0,
    this.light = 0,
    this.dots = 0,
  }) : assert(shape >= 0 && shape < 4, 'u_shape has four values, got $shape');

  /// Every scalar at zero and every hue at black — the named identity.
  ///
  /// A redirecting constructor rather than a second set of defaults, because two
  /// lists of defaults would be two places to forget one. The suite asserts the
  /// two are equal, which is what keeps the name honest.
  const LumenUniforms.identity() : this();

  /// `u_res.x` — the paint rect's logical width in pixels.
  ///
  /// **Logical, not device.** Impeller's `runtime_effect.vert` passes the
  /// untransformed local vertex position, so this is the `Size` the rect was
  /// asked to cover and not `size * devicePixelRatio`. The shader divides by
  /// `min(u_res.x, u_res.y)` to normalise, so a device-pixel value here would
  /// scale the band by the DPR and clip it off the short side.
  final double resX;

  /// `u_res.y` — the paint rect's logical height in pixels. See [resX].
  final double resY;

  /// `u_time` — accumulated seconds.
  ///
  /// The prototype accumulates it at a capped `dt` and scales by `0.15` under
  /// reduced motion (`redesign.html:887-888`). The clock that accumulates it,
  /// and the reduced-motion scale, belong to whoever owns the ticker; this is
  /// the value, not the rule.
  final double time;

  /// `u_shape` — `0` top, `1` bottom, `2` sides, `3` shafts.
  ///
  /// An `int` and not a `double` because the prototype's own control is
  /// `segp('shapeSeg', v=>{ const s=+v; … })` indexing
  /// `['top','bottom','sides','shafts']` with it (`redesign.html:1462-1463`) — a
  /// discrete choice, not a dial. Carrying it as a `double` would make `2.5`
  /// expressible, and the shader's `< 0.5 / < 1.5 / < 2.5` ladder would then
  /// mean something no caller intended.
  final int shape;

  /// `u_spread` — see [spreadFromReach].
  final double spread;

  /// `u_str` — the ray-detail strength, `0` for flat rays and `1` for fully
  /// noise-perturbed ones.
  ///
  /// Named for the Workshop's control rather than for the GLSL abbreviation:
  /// `u_str` is four letters of nothing, while the shader says plainly what it
  /// is when it mixes `0.22+0.78*r1` in by this much.
  final double rays;

  /// `u_ptr.x` — the pointer, normalised by the rect's short side and offset so
  /// the rect's centre is `0`.
  ///
  /// Normalised rather than in pixels because the shader compares it against
  /// `uv`, which is itself normalised by the same short side.
  final double pointerX;

  /// `u_ptr.y` — the pointer's vertical position, **inverted**.
  ///
  /// The prototype computes `ptrY=(r.height/2-(e.clientY-r.top))/mn`
  /// (`redesign.html:919`): it measures up from the bottom, because `uv` does.
  final double pointerY;

  /// `u_ptrI` — the touch glow's gain. See [ptrIntensityFromTouch].
  final double pointerIntensity;

  /// `u_int` — the ambient intensity, before [spike] is added inside the shader.
  ///
  /// The prototype eases `ambI` towards `ambBase*bright*vesp*(focusDim?0.45:1)`
  /// at 6% a frame (`redesign.html:891-892`) and opens at `0.15`
  /// (`redesign.html:884`). This is the destination that easing is heading for.
  final double intensity;

  /// `u_spike` — the transient kick, added to [intensity] by the shader.
  ///
  /// Set by user actions (`redesign.html:1463` uses `0.4` on a shape change,
  /// `redesign.html:1474` uses `0.3` on melt, `redesign.html:1482` uses `0.4`
  /// on daylight) and decayed every frame by [decaySpike].
  final double spike;

  /// `u_hue` — the band's own colour.
  final HslRgb hue;

  /// `u_hue2` — the second colour the melt oscillates between. Derived; see the
  /// class doc.
  final HslRgb hue2;

  /// `u_hue3` — the third colour the melt oscillates between. Derived; see the
  /// class doc.
  final HslRgb hue3;

  /// `u_melt` — `> 0.5` melts the three hues together; `0` paints `hue` alone.
  ///
  /// A threshold rather than a weight because the prototype sends
  /// `meltOn?1:0` (`redesign.html:1474`) and the shader branches on `u_melt>0.5`
  /// — an interpolated melt is not a thing this shader has.
  final double melt;

  /// `u_white` — how much white-hot core the band carries, over the coloured
  /// body. The Workshop default is `0.22` and the control is a checkbox, so the
  /// only two values that occur are `0.22` and `0`.
  final double white;

  /// `u_light` — `0` dark, `1` daylight. A `double` because the shader mixes on
  /// it rather than branching (`redesign.html:1480` sends `0` or `1`, and the
  /// prototype has no third state).
  final double light;

  /// `u_dots` — the 6px scanline modulation, `> 0.5` to enable. Same threshold
  /// shape as [melt] and for the same reason.
  final double dots;

  /// The `setFloat` index for [slot].
  ///
  /// Twenty-four possible results and no dependence on anything in this table;
  /// see the class doc for why this is a method rather than a static and what
  /// that costs.
  int slot(UniformSlot slot) => slot.index;

  /// A copy with the given scalars replaced.
  ///
  /// **There is no hue parameter, on purpose** — see the class doc. Fifteen
  /// scalars, all non-nullable, so the usual "cannot set a field back to `null`"
  /// limitation of a nullable-parameter copy does not apply to any of them; a
  /// caller wanting zero writes `0`.
  LumenUniforms copyWith({
    double? resX,
    double? resY,
    double? time,
    int? shape,
    double? spread,
    double? rays,
    double? pointerX,
    double? pointerY,
    double? pointerIntensity,
    double? intensity,
    double? spike,
    double? melt,
    double? white,
    double? light,
    double? dots,
  }) => LumenUniforms(
    resX: resX ?? this.resX,
    resY: resY ?? this.resY,
    time: time ?? this.time,
    shape: shape ?? this.shape,
    spread: spread ?? this.spread,
    rays: rays ?? this.rays,
    pointerX: pointerX ?? this.pointerX,
    pointerY: pointerY ?? this.pointerY,
    pointerIntensity: pointerIntensity ?? this.pointerIntensity,
    intensity: intensity ?? this.intensity,
    spike: spike ?? this.spike,
    hue: hue,
    hue2: hue2,
    hue3: hue3,
    melt: melt ?? this.melt,
    white: white ?? this.white,
    light: light ?? this.light,
    dots: dots ?? this.dots,
  );

  /// A copy whose three hues are the ones derived from `h`, `s`, `l`.
  ///
  /// `hue` is [hslToRgb] of the request; `hue2` is `+38°` with the lightness
  /// lifted and capped at 88; `hue3` is `-42°` at the base lightness
  /// (`redesign.html:901-903`). Every other field is carried over untouched.
  ///
  /// The eighteen fields are threaded by hand rather than through [copyWith],
  /// which is the price of [copyWith] not accepting a hue: the alternative was
  /// a `copyWith(hue:)` that let a caller break the invariant this method
  /// exists to maintain. One repetition, in one place, for a guarantee.
  ///
  /// ## IT SNAPS WHERE THE PROTOTYPE EASES, AND THAT IS THE DIVERGENCE
  ///
  /// `redesign.html:894-896` walks `curH` towards `tgtH` at 4.5% a frame, with
  /// the shortest-arc correction `((tgtH.h-curH.h+540)%360)-180` so a hue change
  /// across 0° does not sweep the long way round. This method has no frames —
  /// it is a pure function of its arguments — so it holds the **destination**,
  /// and the table a caller paints is the one the prototype converges to.
  ///
  /// The interpolation belongs to whoever owns the clock, which is the point of
  /// it being a separate object. What is deliberately *not* re-implemented here
  /// is the shortest-arc correction: with no current hue there is no arc to
  /// choose, and a caller interpolating between two `LumenUniforms` should carry
  /// that arithmetic with the thing that knows about frames. The suite names
  /// this snap so the claim is a fact about the code rather than a paragraph in
  /// a comment.
  LumenUniforms withHue({
    required double h,
    required double s,
    required double l,
  }) => LumenUniforms(
    resX: resX,
    resY: resY,
    time: time,
    shape: shape,
    spread: spread,
    rays: rays,
    pointerX: pointerX,
    pointerY: pointerY,
    pointerIntensity: pointerIntensity,
    intensity: intensity,
    spike: spike,
    hue: hslToRgb(h: h, s: s, l: l),
    hue2: hslToRgb(h: _hue2Degrees(h), s: s, l: _hue2Lightness(l)),
    hue3: hslToRgb(h: _hue3Degrees(h), s: s, l: l),
    melt: melt,
    white: white,
    light: light,
    dots: dots,
  );

  /// Retargets the hue, and sets [spike] when one is supplied.
  ///
  /// `redesign.html:883` in full: `function setTargetHue(hsl,spike){ tgtH={...hsl};
  /// if(spike&&V)V.spike=spike; }`.
  ///
  /// ## WHY [spike] IS OPTIONAL AND NOT DEFAULTED TO ZERO
  ///
  /// Because half the prototype's callers omit it. The shape control calls
  /// `setTargetHue` and then sets `V.spike=.4` on the next line itself
  /// (`redesign.html:1462-1463`), and so do the shader toggle (`redesign.html:1468`)
  /// and daylight (`redesign.html:1482`). Reading "absent" as "zero" would cut a
  /// spark those callers had just raised, at four call sites, and the symptom
  /// would be a slightly less satisfying transition rather than anything
  /// obviously broken. Absent means **do not touch**.
  LumenUniforms setTargetHue({
    required double h,
    required double s,
    required double l,
    double? spike,
  }) {
    final LumenUniforms retargeted = withHue(h: h, s: s, l: l);
    return spike == null ? retargeted : retargeted.copyWith(spike: spike);
  }

  /// All eighteen fields decide equality.
  ///
  /// This is a value object, and a value object whose `==` is identity can only
  /// be compared by holding on to the instance that built it — which is no
  /// comparison at all across a frame boundary. Hand-written for the reason
  /// [HslRgb] is; see AGENT_CONTEXT decision 131 for why `equatable` is gone
  /// rather than restored.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LumenUniforms &&
          runtimeType == other.runtimeType &&
          resX == other.resX &&
          resY == other.resY &&
          time == other.time &&
          shape == other.shape &&
          spread == other.spread &&
          rays == other.rays &&
          pointerX == other.pointerX &&
          pointerY == other.pointerY &&
          pointerIntensity == other.pointerIntensity &&
          intensity == other.intensity &&
          spike == other.spike &&
          hue == other.hue &&
          hue2 == other.hue2 &&
          hue3 == other.hue3 &&
          melt == other.melt &&
          white == other.white &&
          light == other.light &&
          dots == other.dots;

  /// Agrees with `==`, over the same eighteen fields.
  ///
  /// `Object.hash` takes up to twenty positional arguments and there are
  /// eighteen, so this needs no list — and a list would reintroduce the
  /// identity-on-`List` hazard decision 131 is about.
  @override
  int get hashCode => Object.hash(
    resX,
    resY,
    time,
    shape,
    spread,
    rays,
    pointerX,
    pointerY,
    pointerIntensity,
    intensity,
    spike,
    hue,
    hue2,
    hue3,
    melt,
    white,
    light,
    dots,
  );

  /// Names every field, because eighteen of them printed as
  /// `Instance of 'LumenUniforms'` makes a failed `expect` useless.
  @override
  String toString() =>
      'LumenUniforms(resX: $resX, resY: $resY, time: $time, shape: $shape, '
      'spread: $spread, rays: $rays, pointerX: $pointerX, '
      'pointerY: $pointerY, pointerIntensity: $pointerIntensity, '
      'intensity: $intensity, spike: $spike, hue: $hue, hue2: $hue2, '
      'hue3: $hue3, melt: $melt, white: $white, light: $light, dots: $dots)';
}
