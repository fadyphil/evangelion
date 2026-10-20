import 'dart:ui' show PathMetric;

// ## THE TWO SKY ENUMS ARE **NOT** RE-EXPORTED, AND THAT IS THE POINT
//
// They were declared in this file until Task 5.7, and the reason they moved is
// the reason `UserSettings` needs them: `core/domain/` is **pure Dart** under
// Gate 1, so `core/domain/entities/user_settings.dart` — which now holds
// `eva.sky.pref.shape` and `eva.sky.pref.field` — could not have named an enum
// declared beside a Flutter widget.
//
// They are **imported directly** here, exactly as `sky_entry.dart` is, and
// they are **not** re-exported through the barrel. Two reasons, and the
// second is the one that decides it:
//
// 1. `barrel_test.dart` asserts that every URI the barrel exports starts with
//    `package:evangelion/core/design_system/` and contains neither
//    `features/` nor `/domain/` — so the barrel cannot export a `core/domain/`
//    path directly, and the only way to reach the enum *through* the barrel
//    would be a re-export from a design-system file.
//
// 2. A re-export from **this** file would make the two imports below
//    `unnecessary_import` — the analyzer sees the barrel already providing
//    the enums, through this very file — and `--fatal-infos` makes that an
//    error. The way out of it is a circular barrel→widget→barrel dependency,
//    which is exactly the kind of thing that bites later.
//
// So the enums are **shared-kernel entities** and they are imported the way
// every other shared-kernel entity is imported: by path. A consumer that
// names `SkyStarShape` — `features/reading`, `features/settings`, the sky's
// own tests — imports
// `package:evangelion/core/domain/entities/sky_star_shape.dart`, and the
// barrel is not involved.
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// The size multiplier each silhouette is drawn at.
///
/// `eva/redesign.html:1148` — `(big?5:3+Math.random()*2)*(starShape==='s-dot'?1:1.5)`.
/// Only the dot is unscaled, and the reason is structural rather than
/// aesthetic: the other three are shapes inscribed in the same box, so at the
/// dot's 3–5px an eight-point star is a smudge and the prototype gives it 1.5×.
extension SkyStarShapeScale on SkyStarShape {
  /// `1.0` for [SkyStarShape.dot], [kSkyShapeSizeScale] for the rest.
  double get scale => this == SkyStarShape.dot ? 1.0 : kSkyShapeSizeScale;
}

/// Where down the screen stars may sit.
///
/// **The enum moved to `core/domain/entities/sky_star_field.dart`** in Task
/// 5.7; see that file's doc for the reason. The **bands** stayed here, because
/// they are this widget's own geometry and moving them would have churned a
/// shipped file for no gain.

/// `POSRANGE` — the vertical band, in percent, each field places stars in.
///
/// `eva/redesign.html:1133` —
/// `const POSRANGE={crown:[3,17],high:[3,30],full:[3,60]}`.
///
/// **A band, not a point.** `addStar` writes
/// `top:${t0+Math.random()*(t1-t0)}%` (`:1151`), and the field handler
/// re-randomises `top` and nothing else (`:1466-1467`) — so switching to
/// *full* re-scatters a star vertically while leaving its column, its size and
/// its twinkle period alone. That is why the band is the unit this publishes and
/// not a single number per field.
const Map<SkyStarField, (double, double)> skyFieldBands =
    <SkyStarField, (double, double)>{
      SkyStarField.crown: (3, 17),
      SkyStarField.high: (3, 30),
      SkyStarField.full: (3, 60),
    };

/// The leftmost column a star may take, in percent. `eva/redesign.html:1151`.
const double kSkyStarLeftStart = 8;

/// How wide the horizontal span is, in percent. `eva/redesign.html:1151` —
/// `left:${8+Math.random()*84}%`, so the span ends at 92.
const double kSkyStarLeftSpan = 84;

/// A flare star's size in logical px — it is not randomised. `:1148`, `big?5`.
const double kSkyStarFlareSize = 5;

/// The smallest ordinary star, in logical px. `:1148`, `3+Math.random()*2`.
const double kSkyStarSizeMin = 3;

/// The spread above [kSkyStarSizeMin], in logical px. `:1148`.
const double kSkyStarSizeSpan = 2;

/// What every non-dot silhouette is multiplied by. `:1148`, `?:1.5`.
const double kSkyShapeSizeScale = 1.5;

/// The shortest twinkle period. `eva/redesign.html:1151`, `--tw:${3+…}s`.
const Duration kSkyTwinkleMin = Duration(seconds: 3);

/// The spread above [kSkyTwinkleMin]. `eva/redesign.html:1151`, `+…*4`s.
const Duration kSkyTwinkleSpan = Duration(seconds: 4);

/// `--so`'s base: `eva/redesign.html:119` — `--so:calc(.9*var(--starB,1))`.
///
/// So a star's peak opacity is `0.9 × brightness`, and the Twinkle slider's
/// `30…150` (`:670`, written as `value/100` at `:1488`) arrives here as
/// `0.3…1.5`.
const double kSkyStarBaseOpacity = 0.9;

/// `--starB`'s default. `eva/redesign.html:116` declares `--starB:1`, and
/// `:1488` writes `value/100` from a slider whose default is `100`.
const double kSkyDefaultBrightness = 1.0;

/// The dimmest a twinkling star ever gets: `eva/redesign.html:125` —
/// `0%,100%{opacity:calc(var(--so)*.35);transform:scale(1)}`.
const double kSkyTwinkleOpacityLow = 0.35;

/// The largest a twinkling star ever gets: `:125` — `transform:scale(1.45)`.
const double kSkyTwinkleScaleMax = 1.45;

/// The scale a **still** star is drawn at.
///
/// Its own constant rather than `skyStarScale(0)`, because the two frozen
/// endpoints are not the two ends of the same curve: `#sky.notwinkle .star`
/// (`:117`) and `.screen.rm .star` (`:51`) both say
/// `animation:none; opacity:var(--so)`, so a frozen star is at **full** `--so`
/// and at scale **1** — the top of the opacity range and the bottom of the
/// scale range at the same time. Reading one triangle for both would give a
/// frozen star a 1.45× scale, which is the defect this constant exists to stop.
const double kSkyTwinkleScaleRest = 1.0;

/// The constellation's `opacity`. `eva/redesign.html:1179` — `pl.setAttribute('opacity','.45')`.
const double kSkyConstellationOpacity = 0.45;

/// The constellation's `stroke-width`. `eva/redesign.html:1179` — `'1'`.
const double kSkyConstellationStrokeWidth = 1.0;

/// The stroke alpha in dark: `eva/redesign.html:1177` writes the **book's** own
/// hue at `.8` — `pl.dataset.dark=BOOKS[curBook].css.replace(/[\d.]+\)$/,'.8)')`.
///
/// **`:1177`, not `:1178`.** The first version cited `:1178`, which is the line
/// that *consumes* `pl.dataset.dark` (`pl.setAttribute('stroke', …)`) and is
/// where the light-mode value lives; the assignment is the line above. Both are
/// in the same three-line block and both mention the stroke, which is how a
/// citation one line off survives review — see decision 72 for the same failure
/// on a number. `citation_check.py` only checks that a line exists, never that
/// it says this.
///
/// This client has no book catalogue, so the hue is substituted — see
/// [skyConstellationStroke].
const double kSkyConstellationDarkAlpha = 0.8;

/// The stroke alpha in light: `eva/redesign.html:1178` —
/// `lightMode?'rgba(74,80,96,.6)'`.
const double kSkyConstellationLightAlpha = 0.6;

/// How long a constellation takes to draw itself on.
///
/// `eva/redesign.html:1181-1183` — `stroke-dasharray`/`stroke-dashoffset` set to
/// the path length and transitioned to `0` over `1.2s`
/// `cubic-bezier(.16,1,.3,1)`. That curve is `EvaMotion.interactiveCurve`,
/// which is why the controller below is plain and the curve is applied at paint
/// time.
const Duration kSkyConstellationDrawDuration = Duration(milliseconds: 1200);

/// The three `clip-path: polygon(…)` declarations, in percent of the star's box.
///
/// `eva/redesign.html:121-123`. [SkyStarShape.dot] is **absent on purpose**:
/// `:120` gives it `border-radius: 50%`, so its path is a circle and not one of
/// these lists. A `null` here is the record that the prototype has no polygon
/// for it, and `sky_star_layout_test.dart` asserts the absence.
const Map<SkyStarShape, List<Offset>?> skyStarPolygon =
    <SkyStarShape, List<Offset>?>{
      SkyStarShape.star: <Offset>[
        Offset(0.50, 0.00),
        Offset(0.62, 0.38),
        Offset(1.00, 0.50),
        Offset(0.62, 0.62),
        Offset(0.50, 1.00),
        Offset(0.38, 0.62),
        Offset(0.00, 0.50),
        Offset(0.38, 0.38),
      ],
      SkyStarShape.cross: <Offset>[
        Offset(0.50, 0.00),
        Offset(0.56, 0.44),
        Offset(1.00, 0.50),
        Offset(0.56, 0.56),
        Offset(0.50, 1.00),
        Offset(0.44, 0.56),
        Offset(0.00, 0.50),
        Offset(0.44, 0.44),
      ],
      SkyStarShape.diamond: <Offset>[
        Offset(0.50, 0.00),
        Offset(1.00, 0.50),
        Offset(0.50, 1.00),
        Offset(0.00, 0.50),
      ],
    };

/// FNV-1a over [key]'s UTF-16 code units.
///
/// ## WHY NOT `String.hashCode`
///
/// Because `String.hashCode` is **not guaranteed stable across runs or
/// platforms** — the SDK documents no such guarantee, and `dart2js` computes it
/// differently from the VM. Everything below derives a star's geometry from this
/// function, so an unstable hash is a sky that rearranges itself between two
/// launches of the same build, and a golden captured on one machine that cannot
/// be reproduced on another.
///
/// The alternative is randomness, which is what the prototype does: `addStar`
/// calls `Math.random()` three times per star (`:1148`, `:1151`) and stores the
/// result on the element. That is not available here, because a
/// [SkyEntry] carries a verse and an instant and nothing about where on the
/// screen it should sit — the star it becomes is a **function of its key**, and
/// re-running that function must give the same answer. See
/// [skyStarLayoutFor]'s doc for what that buys and what it costs.
int skyStarHash(String key) {
  int hash = 0x811C9DC5;
  for (final int unit in key.codeUnits) {
    hash ^= unit;
    // `& 0xFFFFFFFF` because Dart's `int` is a 64-bit signed value on the VM
    // and this multiplication overflows it otherwise, which would make the
    // result platform-dependent — the exact property this function exists to
    // remove.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// The [channel]-th independent `0.0 ≤ u < 1.0` draw from [seed].
///
/// Four channels, one seed, because one star needs four independent draws and
/// re-hashing the key four times would make "channel 2 is independent of
/// channel 0" an accident of the key rather than of the function. The mix is
/// the murmur3 finaliser: FNV-1a over a short ASCII key leaves the low bits
/// poorly distributed, and two of these channels are multiplied by a small
/// number before use.
double skyStarUnit(int seed, int channel) {
  int x = (seed + channel * 0x9E3779B9) & 0xFFFFFFFF;
  x ^= x >>> 16;
  x = (x * 0x85EBCA6B) & 0xFFFFFFFF;
  x ^= x >>> 13;
  x = (x * 0xC2B2AE35) & 0xFFFFFFFF;
  x ^= x >>> 16;
  // 24 bits, so the quotient is exactly representable and two hosts cannot
  // disagree in the last bit of a double.
  return (x & 0xFFFFFF) / 0x1000000;
}

/// One star's geometry, all of it a pure function of its key.
///
/// [immutable] because it is handed to a painter and to a `Positioned` and
/// neither of them may see it change underfoot; there is no `copyWith` because
/// every field is computed in one place — [skyStarLayoutFor].
@immutable
class SkyStarLayout {
  /// Creates a layout. Every field is produced by [skyStarLayoutFor]; this
  /// constructor exists so that function can be one expression.
  const SkyStarLayout({
    required this.leftPercent,
    required this.topPercent,
    required this.size,
    required this.twinklePeriod,
  });

  /// Where the star's **left edge** sits, in percent of the sky's width.
  ///
  /// The left edge and not its centre, because `eva/redesign.html:1151` writes
  /// `left:…%` and `:1173` then reads `offsetLeft + offsetWidth/2` for the
  /// constellation. Centring here would move every star half its own size.
  final double leftPercent;

  /// Where the star's **top edge** sits, in percent of the sky's height.
  final double topPercent;

  /// The star's edge in logical px — the box is square, as `:1151` declares.
  final double size;

  /// This star's own `--tw`, as a [Duration].
  final Duration twinklePeriod;
}

/// Where the star for [key] sits, and how it behaves.
///
/// ## THE DETERMINISM RULE, IN ONE SENTENCE
///
/// **The same key gives the same star, and changing [field] moves `topPercent`
/// and nothing else.**
///
/// Both halves are the prototype's. `addStar` (`:1143-1153`) draws its three
/// random numbers once, at the moment the star is created, and stores them on
/// the element — so a star that is already on screen does not move. And the
/// field handler (`:1466-1467`) writes `s.style.top` and **only** `s.style.top`,
/// re-randomising the vertical band and leaving the column, the size and the
/// period exactly as they were.
///
/// ## WHAT THE DIVERGENCE COSTS, STATED RATHER THAN LEFT
///
/// The prototype's column and size are drawn *once per star and then fixed*,
/// which means two stars lit a minute apart can sit at the same column. Here
/// every star's column is a function of its key, so **every pair of distinct
/// keys is distinct with overwhelming probability** and the sky is better
/// distributed than the prototype's — at the cost of no longer reproducing the
/// occasional coincidence. That is a deliberate improvement rather than a
/// transcription slip, and it is recorded here so a reader comparing against
/// `eva/redesign.html` does not read it as one.
///
/// *Rejected: storing the draws on the entry.* `SkyEntry` is
/// `core/domain/` and frozen; four geometry fields on it would make a domain
/// entity carry a screen position, and the deterministic function is one line
/// of arithmetic instead.
SkyStarLayout skyStarLayoutFor({
  required String key,
  required SkyStarShape shape,
  required SkyStarField field,
  required bool isFlare,
}) {
  final int seed = skyStarHash(key);
  final (double bandLo, double bandHi) = skyFieldBands[field]!;
  final double baseSize = isFlare
      ? kSkyStarFlareSize
      : kSkyStarSizeMin + skyStarUnit(seed, 2) * kSkyStarSizeSpan;
  return SkyStarLayout(
    leftPercent: kSkyStarLeftStart + skyStarUnit(seed, 0) * kSkyStarLeftSpan,
    topPercent: bandLo + skyStarUnit(seed, 1) * (bandHi - bandLo),
    size: baseSize * shape.scale,
    twinklePeriod:
        kSkyTwinkleMin +
        Duration(
          microseconds: (skyStarUnit(seed, 3) * kSkyTwinkleSpan.inMicroseconds)
              .round(),
        ),
  );
}

/// The `0 → 1 → 0` triangle of `eva/redesign.html:125`'s `twk` keyframes.
///
/// The keyframes are `0%,100%` at one end and `50%` at the other, so the shape
/// is a triangle rather than a ramp; the shared float clock is a sawtooth, so
/// the triangle is built from it — the same construction
/// `gold_fleck_triangle` uses for `fleck-float`, and for the same reason.
double skyTwinkleTriangle(double phase) =>
    1 - (2 * (phase % 1.0) - 1).abs().clamp(0.0, 1.0);

/// Where a star with [period] is in its own twinkle cycle, given the shared
/// float clock at [clock].
///
/// ## §13.2's COLLAPSE, WITH A PER-STAR DIVISOR
///
/// The app has four shared ambient clocks and adding a fifth per star would put
/// 44 tickers under a background that is already the frame budget's largest
/// item. So the twinkle is derived from the shared **float** clock, exactly as
/// `GoldFlecks` derives its fleck phase — but where the flecks share one
/// divisor, every star here has its own `--tw` between 3 and 7 seconds, so the
/// divisor is the star's own period:
///
/// ```text
/// cycles per float cycle = kFloatPeriod / period      // 20s / 3s … 20s / 7s
/// ```
///
/// The **rate** is faithful, because [clock] advances linearly: a star at 5s
/// over a 20s clock completes four cycles per float cycle and therefore four
/// five-second twinkles per twenty real seconds. `gold_flecks_test.dart`
/// asserts its ratio as a *derivation* for exactly the reason this cannot be a
/// third literal here.
double skyTwinklePhase({required double clock, required Duration period}) {
  if (period.inMicroseconds <= 0) return 0.0;
  return (clock * kFloatPeriod.inMicroseconds / period.inMicroseconds) % 1.0;
}

/// The opacity a star paints at: `--so` scaled by [triangle].
///
/// `eva/redesign.html:125` — `opacity: calc(var(--so)*.35)` at the ends and
/// `opacity: var(--so)` at the middle, where `--so` is `0.9 × brightness`.
double skyStarOpacity({required double brightness, required double triangle}) =>
    kSkyStarBaseOpacity *
    brightness *
    (kSkyTwinkleOpacityLow + (1 - kSkyTwinkleOpacityLow) * triangle);

/// The scale a twinkling star paints at.
///
/// `eva/redesign.html:125` — `transform: scale(1)` → `scale(1.45)`.
double skyStarScale(double triangle) =>
    kSkyTwinkleScaleRest +
    (kSkyTwinkleScaleMax - kSkyTwinkleScaleRest) * triangle;

/// The silhouette [shape] cuts out of [rect].
///
/// ## THE DOT IS A CIRCLE, AND THAT IS THE WHOLE OF `:120`
///
/// `.star.s-dot{border-radius:50%}` (`eva/redesign.html:120`) is a rounded box,
/// not a `clip-path`. Transcribing it as one of the polygon point lists would
/// produce an octagon at every size other than the one it was measured on, so
/// [SkyStarShape.dot] has no entry in [skyStarPolygon] and this function builds
/// an oval instead. `witness_sky_layout_test.dart` asserts the corner is
/// **outside** the dot's path, which is the assertion a polygon cannot pass.
Path skyStarPathFor(SkyStarShape shape, Rect rect) {
  final List<Offset>? polygon = skyStarPolygon[shape];
  if (polygon == null) {
    return Path()..addOval(rect);
  }
  final Path path = Path()
    ..moveTo(
      rect.left + polygon.first.dx * rect.width,
      rect.top + polygon.first.dy * rect.height,
    );
  for (final Offset point in polygon.skip(1)) {
    path.lineTo(
      rect.left + point.dx * rect.width,
      rect.top + point.dy * rect.height,
    );
  }
  return path..close();
}

/// Whether [shape]'s prototype mechanism is a `clip-path` rather than a
/// `border-radius`.
///
/// `true` for [SkyStarShape.star], [SkyStarShape.cross] and
/// [SkyStarShape.diamond]; `false` for [SkyStarShape.dot].
///
/// **The one place the two prototype mechanisms are named.** The star layer
/// branches on this, and it has to: the three polygons are clipped and lose
/// their halo, the dot is rounded and keeps it. See [SkyStarClipper]'s doc for
/// why the two differ.
bool skyClipsPaint(SkyStarShape shape) => shape != SkyStarShape.dot;

/// Clips a star's box to its silhouette.
///
/// ## THE ONE FLAG THIS PUBLISHES, AND WHY IT IS NOT JUST `!= dot`
///
/// The prototype uses **two different mechanisms** for its four shapes
/// (`eva/redesign.html:120-123`), and they behave differently — which is the
/// whole of the star layer's branch:
///
/// | class | mechanism | clips its own paint? |
/// | --- | --- | --- |
/// | `s-dot` | `border-radius: 50%` | no — it rounds the border box, and the shadow follows that rounded outline |
/// | `s-star` / `s-cross` / `s-diamond` | `clip-path: polygon(…)` | **yes** — the element's whole rendering, and an outer shadow lives outside the border box |
///
/// A `CustomClipper` rather than a `ShapeBorder` decoration because
/// `clip-path: polygon(…)` is a clip and not a shape: it has to wrap a
/// `paint()`, not replace one.
@immutable
class SkyStarClipper extends CustomClipper<Path> {
  /// Clips to [shape].
  const SkyStarClipper(this.shape);

  /// The silhouette to cut.
  final SkyStarShape shape;

  @override
  Path getClip(Size size) => skyStarPathFor(shape, Offset.zero & size);

  @override
  bool shouldReclip(covariant SkyStarClipper oldClipper) =>
      oldClipper.shape != shape;
}

/// The star's own ink.
///
/// ## A SUBSTITUTION, AND IT IS NAMED
///
/// `eva/redesign.html:119` is `background: #fff` and `:77` is
/// `background: #4A5060`. **Neither is a token**, and
/// `no_colour_literals_test.dart` refuses every colour in `lib/` that does not
/// resolve through `EvaColors` — so the values are transcribed into the two
/// tokens that occupy the same role:
///
/// | prototype | here | why |
/// | --- | --- | --- |
/// | dark `#fff` | `EvaColors.dark().ink` — `#EAE8F5` | the darkest palette's brightest ink; on a near-black canvas it is what `#fff` was reaching for |
/// | light `#4A5060` | `EvaColors.light().ink2` — `#5A5480` | a muted blue-grey, which is what `#4A5060` is; `ink` in light is `#120E28`, far darker than the prototype's star |
///
/// Recorded as a substitution rather than added as a fifteenth colour token,
/// which would be a design-system change in a task that does not own it — the
/// reasoning is decision 63's, for the Arabic band.
Color skyStarFill(EvaColors colors, Brightness brightness) =>
    brightness == Brightness.dark ? colors.ink : colors.ink2;

/// The star's halo — **the dot's only**, and the reason is [skyClipsPaint].
///
/// `eva/redesign.html:1137-1142` returns two `box-shadow`s from `starShadows`:
/// in light, `rgba(74,80,96,.4)` at `6px`/`12px` (or `10px`/`20px` for a
/// flare); in dark, **the current ambient hue lightened by 22 points**, at
/// `8px`/`16px` (or `14px`/`30px`).
///
/// `addStar` writes them onto **every** class (`:1152`), and only the dot's
/// survive: `border-radius: 50%` rounds the border box so the shadow follows
/// the rounded outline, while the three `clip-path: polygon(…)` classes are
/// clipped to a region **inside** the border box and an outer shadow is drawn
/// outside the border edge only (CSS Backgrounds 3 §6.1.1) — so the two never
/// overlap. These two radii are therefore also exactly what a **flare**
/// contributes on a polygon shape: the wide halo at a fixed 5px (`:1148`),
/// with nothing behind it.
///
/// The dark half cannot be transcribed: `curH` is the LUMEN background's
/// breathing hue, which this client does not read from a decorative widget and
/// which would make a star's colour a function of an animation clock. The
/// substitution is `ember` — §5.1's single accent and the decision-31
/// precedent for "a hue separating this thing from that one". The light half
/// is `ink2` at the prototype's own `0.4`, which is both a token and the same
/// grey-blue `#4A5060` at the same alpha.
Color skyStarGlow(EvaColors colors, Brightness brightness) =>
    brightness == Brightness.dark
    ? colors.ember
    : colors.ink2.withValues(alpha: 0.4);

/// The two `box-shadow` blur radii, near then far.
///
/// `eva/redesign.html:1138-1142`. Returned as a pair rather than a `List` so the
/// two radii cannot be transposed at a call site: the near one is what touches
/// the star and the far one is what makes the halo, and swapping them produces
/// a star that is still plausible.
(double, double) skyStarGlowRadii({
  required bool isFlare,
  required Brightness brightness,
}) {
  if (brightness == Brightness.light) {
    return isFlare ? (10, 20) : (6, 12);
  }
  return isFlare ? (14, 30) : (8, 16);
}

/// The polyline's ink.
///
/// `eva/redesign.html:1177-1178` stores the **current book's** hue at `.8` and
/// uses `rgba(74,80,96,.6)` in light mode. There is no book catalogue behind
/// this client — ADR-0022's fiction table records the catalogue as a stub — so
/// the book's hue is substituted by `ember` at its own `.8`, and the light mode
/// keeps the prototype's value through `ink2` at `.6`.
Color skyConstellationStroke(EvaColors colors, Brightness brightness) =>
    brightness == Brightness.dark
    ? colors.ember.withValues(alpha: kSkyConstellationDarkAlpha)
    : colors.ink2.withValues(alpha: kSkyConstellationLightAlpha);

/// The constellation's points: every star's centre, **in lit-event order**.
///
/// `eva/redesign.html:1173` — `stars.map(s => [s.offsetLeft + s.offsetWidth/2,
/// s.offsetTop + s.offsetHeight/2])`, where `stars` is
/// `[...sky.querySelectorAll('.star')]` (`:1169`), i.e. **DOM order**, i.e. the
/// order `addStar` appended them (`:1153`).
///
/// That order is the whole contract. `SkyRepository` promises its list is the
/// record sequence rather than a `litAt` sort (see `SkyEntry.litAt`'s doc), and
/// this function reads it as given — a constellation that sorted by timestamp
/// would be a different constellation on a device whose clock ticked across two
/// records.
///
/// **Fewer than two stars draws nothing** (`:1170`, `if(stars.length<2) return`),
/// which is why the empty case returns `[]` rather than a one-point path.
List<Offset> skyConstellationPoints({
  required List<SkyEntry> entries,
  required Size size,
  required SkyStarShape shape,
  required SkyStarField field,
}) {
  if (entries.length < 2) return const <Offset>[];
  return <Offset>[
    for (final SkyEntry entry in entries)
      () {
        final SkyStarLayout layout = skyStarLayoutFor(
          key: entry.key,
          shape: shape,
          field: field,
          isFlare: entry.isFlare,
        );
        return Offset(
          layout.leftPercent / 100 * size.width + layout.size / 2,
          layout.topPercent / 100 * size.height + layout.size / 2,
        );
      }(),
  ];
}

/// The witness sky: one star per lit verse, and the constellation they make.
///
/// ## WHAT IT RENDERS AND WHAT IT DELIBERATELY DOES NOT
///
/// Four things, in the prototype's own paint order:
///
/// 1. the stars — one per [entries] entry, at [skyStarLayoutFor]'s position,
///    in [shape], twinkling at [twinkle] and scaled by [brightness];
/// 2. the glow each star carries (`starShadows`, `:1137-1142`);
/// 3. the constellation polyline, in lit-event order, drawn on once the second
///    star arrives (`:1167-1185`);
/// 4. a flare's **resting** appearance — a fixed 5px and the wide halo —
///    which is all that survives the prototype's one-shot.
///
/// **It holds no cap.** `eva/redesign.html:1147` evicts the oldest star past
/// `starCap`, and `SkyCubit` does exactly that (`sky_star_cap.dart`'s 44). A
/// cap here would be a second implementation of a number that already has one,
/// and a caller handed fifty entries would get a sky silently truncated at a
/// boundary the prototype and the cubit agree on and this widget does not.
/// Rendering what it is given is also what makes the widget testable against
/// the list rather than against a limit.
///
/// **It has no trigger.** The prototype draws the constellation when the last
/// verse of a book is seen, once per book, 400ms later (`:1156-1158`). Which
/// book, and whether this is its last verse, is the reader's knowledge and not a
/// decorative widget's; Phase 5 owns that wiring. What this owns is the *once*:
/// the draw-on runs a single time, when a constellation first becomes possible.
///
/// ## THE FLARE'S ONE-SHOT IS **NOT** REPRODUCED, AND THAT IS A DECISION
///
/// `eva/redesign.html:124` gives `.star.flare` a second animation —
/// `flare .9s var(--e-light) 1` — whose keyframes (`:126`) run
/// `box-shadow: 0 0 0 0 rgba(255,255,255,.9)` → `0 0 0 22px rgba(255,255,255,0)`.
///
/// Two reasons not to run it. It **terminates at nothing**: the end state is a
/// transparent shadow, so §14's "jump straight to the end state" leaves a flare
/// indistinguishable from an ordinary star, and the thing that actually persists
/// is `starShadows(true)` — the fixed 5px and the wide halo, both of which *are*
/// reproduced here. And each star's flare starts when *that* star is added, so
/// a faithful port needs one controller per star; §13.2 collapses ambient
/// controllers to four for the whole app, and forty-four one-shot controllers
/// under a decorative layer is the same mistake with a smaller number in front
/// of it. What a reader sees in the prototype after 900ms is what is rendered
/// here from the first frame.
///
/// ## IT READS THE CUBIT THROUGH ITS CALLER, NOT ITSELF
///
/// This widget lives in `core/design_system/` and takes [entries] as a
/// parameter. It does **not** import `SkyCubit`, and cannot: AGENT_CONTEXT §3
/// says no feature may be reached from `lib/core/`, and
/// `tool/verify_purity.sh` Gate 2 fails the line. Three screens read the sky —
/// `/reading`, `/quiz` and `/journey` — so a widget inside `features/sky/` would
/// force all three to import it, which is the same rule from the other side.
///
/// The seam is therefore the list. `SkyEntry` is already in the shared kernel
/// (`core/domain/entities/sky_entry.dart`, written for these three consumers),
/// so a caller may hand over `SkyState.entries` — the record sequence, oldest
/// first — and nothing else about the cubit crosses the boundary. **Phase 5 owns
/// that wiring**, and it is where the question of where the cubit lives for
/// three features at once gets answered; this file records the constraint
/// rather than the answer.
///
/// ## SEMANTICS
///
/// Decorative and excluded, like `SunBurst` and `GoldFlecks`: the sky says
/// nothing a reader needs announced, and `journey`'s counters (`:1186-1189`)
/// carry the counts in text beside it. `pointer-events: none` is `:116` and is
/// [IgnorePointer] here — a full-bleed layer that ate taps would make every
/// control under it dead.
class WitnessSky extends StatefulWidget {
  /// The sky, filling whatever box it is given.
  ///
  /// **Fills, and does not choose its own box.** `#sky` is
  /// `position:absolute; inset:0` (`:116`), so the prototype's container is the
  /// whole screen and nothing else; a caller places this where it gets bounded
  /// constraints — a `Stack`, a `Positioned.fill`, a `SizedBox` — and the
  /// percentages resolve against that box.
  ///
  /// **An unbounded box THROWS, and the assertion names the fix.** This is the
  /// corrected version of a claim that said the sky "paints nothing rather than
  /// throwing", with a `size.isFinite` guard written to make that true. Both
  /// were false and the guard was unreachable: `Stack` itself asserts on
  /// unbounded constraints **before** any child of it builds, so the guard could
  /// not be reached and measured 25 cascading `FlutterError`s instead of the one
  /// the framework raises.
  ///
  /// The framework's own message is the better behaviour here — it names the
  /// fix ("wrap the Stack in a widget that provides finite height and width
  /// constraints") and a caller who gets it has learned something a silent
  /// nothing would have hidden. `witness_sky_test.dart`'s "an unbounded box
  /// throws and names the fix" holds it.
  const WitnessSky({
    required this.entries,
    this.brightness = kSkyDefaultBrightness,
    this.twinkle = true,
    this.shape = SkyStarShape.dot,
    this.field = SkyStarField.crown,
    this.showConstellation = true,
    super.key,
  }) : assert(
         brightness > 0,
         'brightness is --starB (eva/redesign.html:116), which the Twinkle '
         'slider writes as value/100 over 30…150 — so it is 0.3…1.5 and never '
         'zero. A zero would erase the sky rather than dim it.',
       );

  /// The lit sky, **in lit-event order**.
  ///
  /// The order is the constellation's, not a convenience: see
  /// [skyConstellationPoints]. Any number of entries is rendered.
  final List<SkyEntry> entries;

  /// `--starB`. `1.0` is the prototype's default (`:116`); `0.3…1.5` is the
  /// slider's range (`:670`, `:1488`).
  final double brightness;

  /// Whether stars twinkle. `false` is `#sky.notwinkle` (`:117`), and every star
  /// then sits at full `--so` and at scale 1 — see [kSkyTwinkleScaleRest].
  final bool twinkle;

  /// Which silhouette every star is drawn in. The default is `s-dot`
  /// (`:1131`, re-pinned at `:1514`).
  final SkyStarShape shape;

  /// Which vertical band stars sit in. The default is `crown` (`:1131`).
  final SkyStarField field;

  /// Whether the constellation is drawn. `false` is the Constellations switch
  /// off, which **removes the `svg` entirely** (`eva/redesign.html:1484-1485`)
  /// rather than hiding it.
  final bool showConstellation;

  @override
  State<WitnessSky> createState() => _WitnessSkyState();
}

class _WitnessSkyState extends State<WitnessSky>
    with SingleTickerProviderStateMixin {
  /// The draw-on, and the **only** controller this widget owns.
  ///
  /// `eva/redesign.html:1181-1183` transitions `stroke-dashoffset` from the
  /// path length to `0` over 1.2s. It is a one-shot per constellation, not an
  /// ambient loop, so it is outside §13.2's collapse — but it is still exactly
  /// one, because the sky is one layer and a second controller per star is the
  /// flare's rejected design (see [WitnessSky]'s doc).
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: kSkyConstellationDrawDuration,
    // `preserve`, for `EvaNeuralMotion`'s reason: these run forever elsewhere and
    // `AnimationBehavior.normal` would collapse them under reduced motion.
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    // Post-frame rather than inline, so the first frame is painted with the
    // constellation already off the line and then drawn — the same ordering
    // `EvaAnimate` uses, and the reason a reader never sees a finished line
    // appear for a frame before it starts moving.
    WidgetsBinding.instance.addPostFrameCallback((_) => _playDrawOn());
  }

  @override
  void didUpdateWidget(WitnessSky oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ## THE REPLAY RULE, IN ONE CONDITION
    //
    // **Play when the constellation first becomes drawable.** That is one
    // predicate and two of its terms, and both halves of it are measured
    // failures without it:
    //
    // - `entries.length >= 2` — `:1170`'s own guard. `/reading` lights verses on
    //   scroll, so a reader who opens the screen with **one** stored star and
    //   scrolls to a second crosses this boundary *after* mount. Arming only in
    //   `initState` left the controller at 0 and `extractPath(0, 0)` drew
    //   nothing, forever: measured, growing 1 → 2 entries produced a buffer
    //   byte-identical to a sky built with `showConstellation: false`.
    // - `!oldWidget.showConstellation && widget.showConstellation` — the
    //   prototype's switch removes the `svg` outright (`:1484-1485`), and a later
    //   `drawConstellation()` appends a fresh one that draws itself on again.
    //
    // **And a third or later star does NOT replay.** This is the deliberate
    // half. `:1156-1158` draws once per book, when the last verse is lit — not
    // once per star — so growth *extends* the line rather than restarting it,
    // and a line a reader is watching is never yanked back to nothing because
    // they scrolled. The painter re-reads its `points` on every repaint, so an
    // extension is simply the same draw-on finishing against a longer path.
    if (!_constellationDrawable) return;
    final bool firstStarToMakeItPossible = _isDrawable(oldWidget) == false;
    final bool switchCameBack =
        !oldWidget.showConstellation && widget.showConstellation;
    if (firstStarToMakeItPossible || switchCameBack) {
      _playDrawOn();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _playDrawOn() {
    if (!mounted) return;
    if (!_constellationDrawable) return;
    if (_reducedMotion) {
      // §14: "jump straight to the end state" — `eva_animate.dart:156-163`'s
      // rule, and `kAlwaysCompleteAnimation` on the route transition for the
      // same reason (decision 124). **Setting the value rather than forwarding**
      // is the part that matters: `forward()` would leave a `repeat`-less but
      // still-ticking controller under a sky that has already reached its end
      // state, which is measured as a fifth `transientCallbackCount` where the
      // app's whole ambient budget is four (§13.2).
      _draw.value = 1.0;
      return;
    }
    _draw
      ..value = 0.0
      ..forward();
  }

  bool get _constellationDrawable =>
      widget.showConstellation && widget.entries.length >= 2;

  static bool _isDrawable(WitnessSky w) =>
      w.showConstellation && w.entries.length >= 2;

  /// Whether this sky must not animate, as [build] last resolved it.
  ///
  /// **A field and not a `context` read inside [_playDrawOn], and the reason is
  /// mechanical rather than stylistic.** The draw-on is armed from `initState`'s
  /// post-frame callback and from `didUpdateWidget`; neither is a place that may
  /// call `dependOnInheritedWidgetOfExactType` — `didUpdateWidget` runs before
  /// the subtree is rebuilt, and registering a dependency there is the very
  /// thing AGENT_CONTEXT §35 records Flutter asserting on ("was called before
  /// `_HomeBodyState.initState()` completed"). `build` is the legal point, so it
  /// resolves the flag and stashes it here, and the two arming sites read the
  /// field.
  ///
  /// **`initState`'s post-frame callback runs after the first `build`**, so the
  /// value is populated by then — which is the only ordering this needs, and
  /// `_playDrawOn` also runs from `didUpdateWidget` where a `build` has always
  /// happened first.
  bool _reducedMotion = false;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Brightness brightness = Theme.of(context).brightness;
    final EvaNeuralMotion motion = NeuralMotionScope.of(context);
    // §14: "every animation checks `MediaQuery.disableAnimationsOf(context)`".
    // `maybe` because the sky can legitimately be pumped without a `MediaQuery`
    // in a preview; absent means enabled, which is the framework's own default,
    // and is `GoldFlecks`' rule for the same layer.
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Stashed for [_playDrawOn], which is armed from `initState` and
    // `didUpdateWidget` where no `dependOnInheritedWidgetOfExactType` may be
    // called. See the field's doc.
    _reducedMotion = reduced;
    final bool twinkleOn = widget.twinkle && !reduced;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = constraints.biggest;
            return Stack(
              children: <Widget>[
                // ## WHAT THIS COSTS, MEASURED, AND WHY IT IS NOT FIXED HERE
                //
                // The twinkle is derived from the shared float clock, so **every
                // frame rebuilds every star** — 44 stars × 5 widgets
                // (`Positioned` / `Transform.scale` / `Opacity` / `DecoratedBox` /
                // `SizedBox`, plus the `ClipPath` on the three clipped shapes) is
                // ~265 elements re-instantiated per frame.
                //
                // Measured on the 390×844 ambient surface over 120 frames in
                // `flutter test` — a debug JIT under fake async, so these are
                // **not** device numbers and should be read as an upper bound:
                //
                // | stars | µs/frame | vs 0 stars | per star |
                // | --- | --- | --- | --- |
                // | 0 | 658 | — | — |
                // | 11 | 1750 | +1092 | 99 |
                // | 44 | 2214 | +1556 | **35** |
                //
                // **The marginal cost of a star FALLS as the count rises** (99µs
                // at 11, 35µs at 44), which is the signature of a fixed per-frame
                // cost plus a cheap per-star one — so 44 stars is not 4× the
                // 11-star case, and the cliff the finding predicted is not there.
                //
                // The same table with the clock **stopped** reads 564µs at 44
                // stars, so roughly **two thirds of the cost is repaint rather
                // than rebuild**; and `twinkle: false` — an identical widget tree
                // with a constant alpha — reads 1721µs, which puts the 44
                // `Opacity` saveLayers at about half of what remains.
                //
                // **Why none of that is fixed here.** The fix is one
                // `CustomPainter` drawing the shapes, the glows and the twinkle
                // into a canvas on `repaint: motion.repaint` — exactly what
                // `GoldFlecks` does, and the reason its flecks need no per-fleck
                // rebuild. That is a **redesign of this widget's internals**, not
                // a cheap half, and it has a visible consequence: a painter's
                // shapes are not widget-tree nodes, so every finder in this
                // file's suite would have to become a golden — and this suite is
                // currently the only thing that can see a star at all (the B1
                // shape regression was invisible in every other assertion).
                // Phase 5 mounted the reader and did not pay for it. The
                // measurement is recorded; the redesign is not.
                //
                // **Two cheap-looking changes, both measured as not worth it.**
                // Hoisting the `Stack` out of the `ListenableBuilder` does
                // nothing: the children are the same widget instances, so
                // `Element.update` short-circuits on `identical(newWidget,
                // oldWidget)` and the rebuild is already down to the two values
                // that actually change. A `RepaintBoundary` per star is *worse*:
                // every star changes every frame, so each becomes a layer
                // invalidated immediately, and 44 of them are composited per frame
                // where one is composited now.
                Positioned.fill(
                  child: ListenableBuilder(
                    // The twinkle is derived from the shared float clock, so
                    // this is where a star's opacity and scale are recomputed.
                    // One listener for the whole sky rather than one per star:
                    // `Listenable.merge` would allocate every build and
                    // re-subscribe the builder every build, which is the churn
                    // `neural_motion.dart`'s `repaint` getter exists to remove.
                    listenable: motion.repaint,
                    builder: (BuildContext context, Widget? _) => _SkyStars(
                      entries: widget.entries,
                      size: size,
                      colors: colors,
                      brightness: brightness,
                      motion: motion,
                      twinkleOn: twinkleOn,
                      shape: widget.shape,
                      field: widget.field,
                      brightnessScale: widget.brightness,
                    ),
                  ),
                ),
                if (_constellationDrawable)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SkyConstellationPainter(
                        points: skyConstellationPoints(
                          entries: widget.entries,
                          size: size,
                          shape: widget.shape,
                          field: widget.field,
                        ),
                        stroke: skyConstellationStroke(colors, brightness),
                        opacity: reduced ? 1.0 : kSkyConstellationOpacity,
                        drawOn: _draw,
                        drawOnEnabled: !reduced,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The star layer, rebuilt whenever the shared clock advances.
///
/// Its own `Stack` because `Positioned` must be a **direct** child of one, and
/// `build` above cannot return them directly — the `ListenableBuilder` in
/// between is what makes the twinkle real and it is not a `Stack`.
class _SkyStars extends StatelessWidget {
  const _SkyStars({
    required this.entries,
    required this.size,
    required this.colors,
    required this.brightness,
    required this.motion,
    required this.twinkleOn,
    required this.shape,
    required this.field,
    required this.brightnessScale,
  });

  final List<SkyEntry> entries;
  final Size size;
  final EvaColors colors;
  final Brightness brightness;
  final EvaNeuralMotion motion;
  final bool twinkleOn;
  final SkyStarShape shape;
  final SkyStarField field;
  final double brightnessScale;

  @override
  Widget build(BuildContext context) {
    // `hardEdge` for `eva/redesign.html:116`'s `overflow:hidden`, and it is
    // [Stack]'s own default. Without it the halo of a star in the last 8% of the
    // columns would reach past the screen's right edge and the punch-hole at `:501`;
    // with it the sky is clipped to its own box, which is what the prototype's
    // container does.
    return Stack(
      children: <Widget>[for (final SkyEntry entry in entries) _star(entry)],
    );
  }

  /// The [Key] on the star's box for [entry].
  ///
  /// **One key per [SkyEntry.key], and it is there because a test has to be able
  /// to say "the star for John:3:16".** The finder that used to say it — a
  /// `find.byType(ClipPath)` — stopped working the moment [skyClipsPaint] was
  /// corrected, and that is the measurement worth recording: `s-dot` reaches its
  /// circle through `border-radius: 50%` (`eva/redesign.html:120`) and is
  /// therefore **not** clip-pathed at all, so a `ClipPath` finder answered
  /// **zero** stars for the *default* shape and broke four suites for a change
  /// that was right.
  ///
  /// A test that reads a widget's internals is coupled to them, and this key is
  /// the decoupling: it is the star's identity, not its mechanism.
  static Key starKeyFor(SkyEntry entry) =>
      ValueKey<String>('sky-star:${entry.key}');

  Widget _star(SkyEntry entry) {
    final SkyStarLayout layout = skyStarLayoutFor(
      key: entry.key,
      shape: shape,
      field: field,
      isFlare: entry.isFlare,
    );
    // The frozen star sits at full `--so` and at scale 1 — the two ends of two
    // different ranges, which is why the triangle and the scale are resolved
    // separately. See [kSkyTwinkleScaleRest].
    final double triangle = twinkleOn
        ? skyTwinkleTriangle(
            skyTwinklePhase(
              clock: motion.floatValue,
              period: layout.twinklePeriod,
            ),
          )
        : 1.0;
    final double scale = twinkleOn
        ? skyStarScale(triangle)
        : kSkyTwinkleScaleRest;
    final Color fill = skyStarFill(colors, brightness);
    final (double near, double far) = skyStarGlowRadii(
      isFlare: entry.isFlare,
      brightness: brightness,
    );
    final Color glow = skyStarGlow(colors, brightness);
    final double sizePx = layout.size;

    // The fill + halo, boxed. One method so the two branches below cannot
    // drift apart in any field but [circle] — which is the *only* difference
    // between the dot's element and the other three's.
    Widget paint({required bool circle}) => DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: glow, blurRadius: near),
          BoxShadow(color: glow, blurRadius: far),
        ],
      ),
      child: SizedBox.square(key: starKeyFor(entry), dimension: sizePx),
    );

    return Positioned(
      left: layout.leftPercent / 100 * size.width,
      top: layout.topPercent / 100 * size.height,
      child: Transform.scale(
        // `alignment` is left null, which centres the scale — CSS's default
        // `transform-origin: 50% 50%`, and the only origin `:125` can mean.
        scale: scale,
        child: Opacity(
          opacity: skyStarOpacity(
            brightness: brightnessScale,
            triangle: triangle,
          ),
          // ## THE ORDER OF THESE TWO IS THE WHOLE SHAPE
          //
          // `DecoratedBox` paints `color` **and** `boxShadow` in its own
          // `paint()`, at its own layer. So a `ClipPath` **below** it clips a
          // child that has not painted yet: the decoration covers the full
          // square and the polygon cuts nothing. That was this tree, and it
          // rendered all three polygons as byte-identical solid squares
          // (measured `lit=72 box=[131..138]x[16..24]`, top row 8/8 lit, where
          // an apex should be one pixel) while every test stayed green.
          //
          // `ClipPath` **above** it clips the decoration's whole `paint()`
          // output, which is what the prototype's two mechanisms do — and they
          // do it with opposite results, which is why this is a branch and not
          // a uniform `ClipPath`:
          //
          // | class | prototype mechanism | what it clips | what survives |
          // | --- | --- | --- | --- |
          // | `s-dot` | `border-radius: 50%` (`:120`) | rounds the **border box**, so the shadow follows the rounded outline | fill **and** halo |
          // | `s-star` / `s-cross` / `s-diamond` | `clip-path: polygon(…)` (`:121-123`) | the element's whole rendering to a region **inside** the border box | fill only |
          //
          // The second row is not a subtlety this port invents. An **outer**
          // `box-shadow` is drawn *outside the border edge only* — "it is
          // clipped inside the border-box of the element" (CSS Backgrounds 3
          // §6.1.1) — and `clip-path` clips the element's entire rendering,
          // background and border included (MDN, `clip-path`). A polygon
          // inscribed in the border box and a shadow lying outside it do not
          // overlap, so `s-star` in the prototype has **no glow at all**, and
          // that is reproduced here rather than smoothed over.
          //
          // The prototype still *declares* `starShadows` on those elements
          // (`:1152`); it declares it and the clip-path throws it away. The
          // declaration is kept below for the same reason and with the same
          // honesty.
          child: skyClipsPaint(shape)
              ? ClipPath(
                  clipper: SkyStarClipper(shape),
                  child: paint(circle: false),
                )
              : paint(circle: true),
        ),
      ),
    );
  }
}

/// Paints the constellation polyline.
///
/// Reads the draw-on [Animation] at paint time rather than being handed a
/// snapshot, for `gold_flecks.dart`'s reason: nothing rebuilds a `CustomPaint`
/// per frame, and `CustomPainter.repaint` is what makes the animation real
/// without a rebuild.
class _SkyConstellationPainter extends CustomPainter {
  _SkyConstellationPainter({
    required this.points,
    required this.stroke,
    required this.opacity,
    required this.drawOn,
    required this.drawOnEnabled,
  }) : super(repaint: drawOn);

  final List<Offset> points;
  final Color stroke;
  final double opacity;

  /// The draw-on clock; `repaint` above.
  final Animation<double> drawOn;

  /// `false` under reduced motion, which paints the finished line.
  final bool drawOnEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    // The same rule as `_SkyStars.build`: nothing to paint is nothing to
    // divide, and `lumen_canvas.dart:145` is where the idiom is.
    if (points.length < 2 || size.isEmpty) return;
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    // `eva/redesign.html:1181-1182` sets `stroke-dasharray` and
    // `stroke-dashoffset` to the path's total length and transitions the offset
    // to `0`. `extractPath` is the same drawing without a length division per
    // frame, and it degrades identically: at progress 1 it returns every
    // metric whole, which is the finished line.
    final double t = drawOnEnabled
        ? EvaMotion.interactiveCurve.transform(drawOn.value.clamp(0.0, 1.0))
        : 1.0;
    final Path drawn = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      drawn.addPath(metric.extractPath(0.0, metric.length * t), Offset.zero);
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kSkyConstellationStrokeWidth
        ..color = stroke.withValues(alpha: stroke.a * opacity),
    );
  }

  @override
  bool shouldRepaint(_SkyConstellationPainter oldDelegate) =>
      oldDelegate.opacity != opacity ||
      oldDelegate.stroke != stroke ||
      oldDelegate.drawOnEnabled != drawOnEnabled ||
      !listEquals(oldDelegate.points, points);
}
