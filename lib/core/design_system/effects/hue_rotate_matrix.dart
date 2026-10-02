import 'dart:math' as math;
import 'dart:ui' show ColorFilter;

/// The Rec.709 luma weights the hue-rotation matrix is built from.
///
/// Named because the matrix below writes `0.213` / `0.715` / `0.072` in nine
/// places, and a reader who does not already know that those three numbers are
/// the luma coefficients will assume they are arbitrary.
const double _kRed = 0.213;
const double _kGreen = 0.715;
const double _kBlue = 0.072;

/// The 4x5 colour matrix that rotates hue by [turns] full turns.
///
/// [turns] is in **turns**, not degrees: 1.0 is a full 360° rotation, which is
/// the unit `hue-cycle`'s keyframes speak (`hue-rotate(0deg) →
/// hue-rotate(360deg)`, `eva/src/index.css:61-63`). Degrees would put a `360`
/// where every call site naturally has a 0..1 clock.
///
/// This is the textbook Rec.709 hue-rotation matrix, transcribed verbatim from
/// `docs/plans/09-quality-gates.md` §13.3 — the same twenty numbers, in the same
/// order, so this file and the plan cannot disagree about what "the exact
/// matrix" means. Row-major, the layout `ColorFilter.matrix` expects.
///
/// ## WHY A COLOUR MATRIX AND NOT `ImageFilter.hueRotation`
///
/// §13.3 gives two reasons and both still hold. `ImageFilter.hueRotation` is
/// not available on every Flutter platform this app builds for, and the
/// prototype's companion `blur(72px)` — a 72-pixel blur on a 280–500px orb, per
/// orb, per frame — would cost a full-screen render target every frame. The
/// orb's 72px softness is instead a wide transparent stop on its radial
/// gradient, which is visually equivalent and effectively free.
List<double> hueRotateMatrix(double turns) {
  final double hue = turns * 2 * math.pi;
  final double c = math.cos(hue);
  final double s = math.sin(hue);
  return <double>[
    _kRed + c * 0.787 - s * _kRed,
    _kGreen - c * _kGreen - s * _kGreen,
    _kBlue - c * _kBlue + s * 0.928,
    0,
    0,
    _kRed - c * _kRed + s * 0.143,
    _kGreen + c * 0.285 + s * 0.140,
    _kBlue - c * _kBlue - s * 0.283,
    0,
    0,
    _kRed - c * _kRed - s * 0.787,
    _kGreen - c * _kGreen + s * _kGreen,
    _kBlue + c * 0.928 + s * _kBlue,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// [hueRotateMatrix] as a [ColorFilter], ready for `Paint.colorFilter`.
///
/// `Paint.colorFilter` is applied *after* the paint's shader, so this works on
/// the orb's `RadialGradient` without the gradient having to know about hue:
/// the painter builds one gradient from the orb's declared colour and lets this
/// filter move it around the wheel.
///
/// Takes a signed [turns]. Negative is the `hue-cycle-rev` direction
/// (`hue-rotate(360deg) → hue-rotate(0deg)`, `index.css:64-67`), and it is a
/// sign flip rather than a second matrix because `hue-rotate(-θ)` and
/// `hue-rotate(360° - θ)` are the same matrix: the coefficients depend on
/// `cos` and `sin` alone, and those satisfy `cos(2π - θ) = cos θ` and
/// `sin(2π - θ) = -sin θ`. `hue_rotate_matrix_test.dart` asserts that equality
/// rather than the stronger and *false* claim that the two matrices are exact
/// inverses — this is SVG's `feColorMatrix type="hueRotate"` approximation, not
/// an orthogonal rotation, and `R(t)·R(-t)` misses the identity by ~5e-5.
ColorFilter hueRotateFilter(double turns) =>
    ColorFilter.matrix(hueRotateMatrix(turns));
