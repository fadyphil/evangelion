import 'dart:math' as math;
import 'dart:typed_data';

import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';

/// A pure-Dart reference implementation of `shaders/lumen.frag`.
///
/// ## WHY THIS EXISTS, AND WHAT IT REPLACES
///
/// The port's own plan said to compare the first rendered frame against "the
/// recorded oracle" — a capture of the original WebGL shader. **There is no
/// such artefact.** No WebGL context exists in this environment and no recorded
/// frame is committed, so the plan's oracle is unobtainable, and the two
/// available substitutes are both worse than useless:
///
/// * *Skipping the check* leaves the whole port resting on a golden. A golden
///   records whatever the shader currently does, so a wrong `setFloat` slot, a
///   doubled Y flip or a `u_res` in device pixels would be **ratified** by it —
///   which is AGENT_CONTEXT recorded decision 8's failure mode exactly.
/// * *Hand-transcribing the frame* would be the same claim with an extra step:
///   the transcription and the shader would share every mistake, because both
///   were typed by the same author from the same source.
///
/// So the oracle is replaced by a **second implementation of the same maths**,
/// written from `shaders/lumen.frag` in idiomatic Dart rather than in GLSL, and
/// the assertion is that the two agree per channel. That is a genuinely
/// independent quantity: it catches the three port-specific defects (a wrong
/// slot, a missing or doubled flip, `u_res` in the wrong units), and it is the
/// only formulation in which "wrong" means anything, because the mirror is not a
/// capture of the thing it is judging.
///
/// ## WHY IT IS **NOT** BIT-EXACT, AND WHAT IT IS INSTEAD
///
/// The shader computes in `float32` — SkSL's `float` is IEEE binary32 on every
/// backend, and `hash` amplifies its argument by **43758.5453125** before
/// `fract`. A half-ulp difference in `sin(n)` therefore arrives at `fract` as
/// ~`2.6e-3`, so the mirror's `hash` values differ from the GPU's by design and
/// the frames cannot agree to the last bit. Dart has no `float32` arithmetic to
/// reproduce the GPU's rounding, and emulating it would make this a third
/// implementation rather than a second.
///
/// The tolerance that absorbs exactly that, and nothing else, is measured by
/// `lumen_canvas_test.dart` and written down there. It is three orders of
/// magnitude tighter than the defects it exists to catch.
///
/// ## WHAT IS *NOT* MIRRORED, AND WHY
///
/// * `FlutterFragCoord()`. There is no CPU equivalent of a rasteriser's
///   interpolated vertex position, so the mirror takes the fragment coordinate
///   as an argument — **in Flutter's convention**, top-left origin and +Y down,
///   exactly what the runtime shader receives. The Y flip is then *inside* the
///   mirror, where it belongs, because a mirror that accepted already-flipped
///   input could not check the flip at all.
/// * `u_ptr` under reduced motion, `u_dots`' half-pixel rounding and every
///   backend's tone mapping. Nothing else in the shader is left out: the hash,
///   the noise, the fbm, the smoothstep, the uv construction, all four shape
///   branches including the five-iteration shafts loop, the touch glow, the
///   melt, the scanline modulation and the tone curve are all transcribed.

/// The bytes [lumenReferenceFrame] produces per channel.
///
/// One entry per RGBA pixel, four bytes each, row-major with row 0 at the
/// **top** — `ui.ImageByteFormat.rawRgba` order, so a frame from the GPU and a
/// frame from this mirror can be compared with `expect` and nothing else.
///
/// [flipY] is `false` only for the negative controls; see
/// [lumenReferenceFields].
Uint8List lumenReferenceFrame({
  required LumenUniforms uniforms,
  required int width,
  required int height,
  bool flipY = true,
}) {
  final Uint8List rgba = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final HslRgb pixel = lumenFragment(
        uniforms: uniforms,
        fragX: x + 0.5,
        fragY: y + 0.5,
        flipY: flipY,
      );
      final int offset = (y * width + x) * 4;
      rgba[offset] = _byte(pixel.r);
      rgba[offset + 1] = _byte(pixel.g);
      rgba[offset + 2] = _byte(pixel.b);
      rgba[offset + 3] = 255;
    }
  }
  return rgba;
}

/// The colour `shaders/lumen.frag` produces at one fragment.
///
/// [fragX] and [fragY] are the values `FlutterFragCoord()` returns: local,
/// logical pixels, origin at the top-left, +Y down. The shader's own flip
/// (`u_res.y - FlutterFragCoord().y`) is reproduced here, and that is the whole
/// point of taking un-flipped input.
HslRgb lumenFragment({
  required LumenUniforms uniforms,
  required double fragX,
  required double fragY,
  bool flipY = true,
}) {
  final LumenReferenceFields fields = lumenReferenceFields(
    uniforms: uniforms,
    fragX: fragX,
    fragY: fragY,
    flipY: flipY,
  );
  // `shaders/lumen.frag:105-109` — the tone curve and the daylight mix.
  final double emR = fields.emitR / (1.0 + fields.emitR);
  final double emG = fields.emitG / (1.0 + fields.emitG);
  final double emB = fields.emitB / (1.0 + fields.emitB);
  return HslRgb(
    r: _mix(fields.emitR, 1.0 - 0.55 * emR, uniforms.light),
    g: _mix(fields.emitG, 1.0 - 0.55 * emG, uniforms.light),
    b: _mix(fields.emitB, 1.0 - 0.55 * emB, uniforms.light),
  );
}

/// The three scalars and the hue a fragment is built from, before the tone
/// curve.
///
/// ## WHY THE INTERNAL VALUES ARE EXPOSED
///
/// Because `fbm1` cannot be mirrored — see the file header — and the way to
/// still say something true about the noise term is to compare the *observable*
/// against the *bounds* the shader's own arithmetic puts on it. `body` is what
/// the noise multiplies, so a caller that reads `body` with `u_str = 0` has the
/// noise-free reference it needs to bracket a noisy frame with.
///
/// That is a real capability and it is also a real hazard: this is a test
/// helper, and a `switch` here would have to be kept in step with the shader by
/// hand. There is exactly one caller and it wants three numbers.
class LumenReferenceFields {
  /// The bundle of intermediates for one fragment.
  const LumenReferenceFields({
    required this.body,
    required this.core,
    required this.emitR,
    required this.emitG,
    required this.emitB,
  });

  /// `body` — the coloured band's coverage, before `u_int` scales it.
  final double body;

  /// `core` — the narrow white-hot line at the band's centre.
  final double core;

  /// `emit.r`, after `u_int` and before the tone curve.
  final double emitR;

  /// `emit.g`.
  final double emitG;

  /// `emit.b`.
  final double emitB;
}

/// The intermediates for one fragment. See [LumenReferenceFields].
LumenReferenceFields lumenReferenceFields({
  required LumenUniforms uniforms,
  required double fragX,
  required double fragY,
  bool flipY = true,
}) {
  final double resX = uniforms.resX;
  final double resY = uniforms.resY;
  final double shortest = math.min(resX, resY);

  // `shaders/lumen.frag:58` — PORT 2, the Y flip.
  //
  // `flipY: false` is **only** for the negative controls in
  // `lumen_canvas_test.dart`: it removes the flip so a test can assert that a
  // frame built without it does *not* match the GPU. A reference that cannot be
  // wrong is not a reference, and the flip is the one thing in the whole port
  // that a unit test can most easily be wrong about in both directions at once.
  final double fcX = fragX;
  final double fcY = flipY ? resY - fragY : fragY;
  final double uvX = (fcX - 0.5 * resX) / shortest;
  final double uvY = (fcY - 0.5 * resY) / shortest;

  final double t = uniforms.time * 0.30;
  final double halfH = (resY / shortest) * 0.5;
  final double halfW = (resX / shortest) * 0.5;

  double d = 0.0;
  double rc = uvX;
  double body = 0.0;
  double core = 0.0;

  if (uniforms.shape < 3) {
    // `shaders/lumen.frag:65-76`
    if (uniforms.shape == 0) {
      d = (halfH - 0.05) - uvY;
      rc = uvX + d * 0.22;
    } else if (uniforms.shape == 1) {
      d = uvY - (-halfH + 0.05);
      rc = uvX - d * 0.22;
    } else {
      d = halfW - uvX.abs();
      rc = uvY + d * 0.22;
    }
    final double spread = uniforms.spread * (1.0 + 0.08 * math.sin(t * 0.8));
    final double env = math.exp(-(d * d) / (spread * spread));
    core = math.exp(-(d * d) / 0.0045);
    final double r1 = lumenReferenceFbm1(rc * 5.0 + t * 0.9);
    final double r2 = lumenReferenceFbm1(rc * 11.0 - t * 0.5 + 7.3);
    final double rays =
        _mix(1.0, 0.22 + 0.78 * r1, uniforms.rays) *
        _mix(1.0, 0.45 + 0.55 * r2, uniforms.rays * 0.6);
    final double edge = uniforms.shape > 1
        ? lumenReferenceFall(uvY.abs(), 0.95, 1.7)
        : lumenReferenceFall(uvX.abs(), 0.95, 1.7);
    body =
        env *
        rays *
        (0.85 + 0.15 * math.sin(t * 2.2 + rc * 9.0 + d * 3.0)) *
        edge;
  } else {
    // `shaders/lumen.frag:77-93` — the five-iteration shafts loop. Written out
    // rather than recursed so the `k` index reads the way the GLSL reads.
    final double depth = halfH - uvY;
    double acc = 0.0;
    for (int k = 0; k < 5; k++) {
      final double fk = k.toDouble();
      final double cx =
          -0.9 +
          fk * 0.45 +
          0.12 * math.sin(t * 0.35 + fk * 2.3) +
          0.10 * (lumenReferenceFbm1(fk * 9.1 + t * 0.18) - 0.5);
      final double tilt = 0.22 * math.sin(t * 0.21 + fk * 1.9);
      final double x = uvX - tilt * depth * 0.5;
      final double w = 0.05 + 0.04 * lumenReferenceFbm1(fk * 3.3 + 1.0);
      double g = math.exp(-((x - cx) * (x - cx)) / (w * w));
      g *= _mix(
        1.0,
        0.55 + 0.45 * lumenReferenceFbm1(x * 16.0 + fk * 31.0 + t * 0.4),
        uniforms.rays,
      );
      final double len =
          (0.8 + 0.6 * lumenReferenceFbm1(fk * 17.7 + t * 0.12)) * halfH * 1.5;
      acc += g * lumenReferenceFall(depth, 0.0, len);
    }
    final double shim = 0.85 + 0.15 * math.sin(t * 2.2 + uvX * 9.0);
    body = acc * shim * 0.85 * lumenReferenceFall(uvX.abs(), 1.1, 1.9);
    d = depth;
    rc = uvX;
  }

  // `shaders/lumen.frag:94-95`
  final double dx = uvX - uniforms.pointerX;
  final double dy = uvY - uniforms.pointerY;
  final double pd = math.sqrt(dx * dx + dy * dy);
  body += math.exp(-(pd * pd) / 0.07) * uniforms.pointerIntensity;

  // `shaders/lumen.frag:96`
  final double intensity = uniforms.intensity + uniforms.spike;

  // `shaders/lumen.frag:97-104`
  HslRgb hue = uniforms.hue;
  if (uniforms.melt > 0.5) {
    final double m1 = math
        .pow(0.5 + 0.5 * math.sin(t * 0.35 + rc * 1.3 + d * 0.7), 1.4)
        .toDouble();
    final double m2 = math
        .pow(0.5 + 0.5 * math.sin(t * 0.28 + rc * 1.7 - d * 0.5 + 2.1), 1.4)
        .toDouble();
    final double m3 = math
        .pow(0.5 + 0.5 * math.sin(t * 0.22 - rc * 1.1 + d * 0.9 + 4.2), 1.4)
        .toDouble();
    final double ws = m1 + m2 + m3 + 1e-4;
    hue = HslRgb(
      r:
          (uniforms.hue.r * m1 + uniforms.hue2.r * m2 + uniforms.hue3.r * m3) /
          ws,
      g:
          (uniforms.hue.g * m1 + uniforms.hue2.g * m2 + uniforms.hue3.g * m3) /
          ws,
      b:
          (uniforms.hue.b * m1 + uniforms.hue2.b * m2 + uniforms.hue3.b * m3) /
          ws,
    );
  }

  // `shaders/lumen.frag:105`
  final double body4 = body * body * body * body;
  final double white =
      body4 * uniforms.white * intensity * (1.0 - uniforms.light);
  double red =
      hue.r * body * intensity + hue.r * core * 0.7 * intensity + white;
  double green =
      hue.g * body * intensity + hue.g * core * 0.7 * intensity + white;
  double blue =
      hue.b * body * intensity + hue.b * core * 0.7 * intensity + white;

  // `shaders/lumen.frag:106` — PORT 2, site 2. The scanline grid is built from
  // the flipped `_fc`, which is the WebGL original's `gl_FragCoord`, so it is
  // built from `fcX`/`fcY` here rather than from `fragX`/`fragY`.
  if (uniforms.dots > 0.5) {
    final double gx = _fract(fcX / 6.0) - 0.5;
    final double gy = _fract(fcY / 6.0) - 0.5;
    final double len = math.sqrt(gx * gx + gy * gy);
    final double scale = _mix(
      1.0,
      0.70 + 0.30 * lumenReferenceFall(len, 0.15, 0.45),
      0.35,
    );
    red *= scale;
    green *= scale;
    blue *= scale;
  }

  // `shaders/lumen.frag:107-109`
  return LumenReferenceFields(
    body: body,
    core: core,
    emitR: red,
    emitG: green,
    emitB: blue,
  );
}

/// `hash` — `shaders/lumen.frag:50`.
double lumenReferenceHash(double n) => _fract(math.sin(n) * 43758.5453125);

/// `noise1` — `shaders/lumen.frag:51`.
double lumenReferenceNoise1(double x) {
  final double i = x.floorToDouble();
  final double raw = _fract(x);
  final double f = raw * raw * (3.0 - 2.0 * raw);
  return _mix(lumenReferenceHash(i), lumenReferenceHash(i + 1.0), f);
}

/// `fbm1` — `shaders/lumen.frag:52`.
double lumenReferenceFbm1(double x) =>
    0.55 * lumenReferenceNoise1(x) +
    0.30 * lumenReferenceNoise1(x * 2.17 + 13.7) +
    0.15 * lumenReferenceNoise1(x * 4.31 + 37.3);

/// `fall` — `shaders/lumen.frag:53`.
double lumenReferenceFall(double x, double a, double b) =>
    1.0 - _smoothstep(a, b, x);

double _fract(double x) => x - x.floorToDouble();

double _mix(double x, double y, double a) => x + (y - x) * a;

/// GLSL's `smoothstep`, which clamps `t` rather than the result.
double _smoothstep(double e0, double e1, double x) {
  final double t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

/// One 0..1 channel as the byte a capture will read.
///
/// **Round, and clamp.** `round(c * 255)` is what every float-to-8-bit
/// conversion in the rasteriser does, and the clamp matters because the shader
/// writes `fragColor` with no clamp of its own — `lumen_uniforms_test.dart`
/// bounds `hslToRgb`'s output but not this shader's, and `u_light` at 1 makes
/// `1.0 - 0.55*em` overshoot the unit interval for a negative channel.
int _byte(double channel) {
  final int value = (channel * 255.0).round();
  return value < 0
      ? 0
      : value > 255
      ? 255
      : value;
}
