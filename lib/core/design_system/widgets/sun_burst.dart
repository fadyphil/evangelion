import 'dart:math' as math;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// One ray of [SunBurst].
@immutable
class SunBurstRay {
  /// Creates a ray. All four values are in the burst's 100x100 viewBox units.
  const SunBurstRay({
    required this.index,
    required this.inner,
    required this.outer,
    required this.width,
  });

  /// The ray's ordinal, `i` in `Array.from({ length: 14 }).map((_, i) => …)`.
  /// Carried rather than recomputed from a list position so a ray keeps its own
  /// geometry if the list is ever filtered or reordered.
  final int index;

  /// Where the ray starts, as a distance from the burst's centre.
  final double inner;

  /// Where the ray ends, as a distance from the burst's centre.
  final double outer;

  /// Stroke width.
  final double width;

  /// The ray's start point on a 100x100 box.
  Offset get start => _point(inner);

  /// The ray's end point on a 100x100 box.
  Offset get end => _point(outer);

  Offset _point(double radius) =>
      Offset(50 + radius * math.cos(_angle), 50 + radius * math.sin(_angle));

  double get _angle => index * (2 * math.pi / sunBurstRayCount);
}

/// How many rays the burst has. `ResultScreen.tsx:9` — `Array.from({ length: 14 })`.
const int sunBurstRayCount = 14;

/// The prototype's ray table, rebuilt as a list of [SunBurstRay].
///
/// `ResultScreen.tsx:7-15`: fourteen rays at `i * (360 / 14)` degrees, inner
/// radius 26 for all of them, outer 46 on even indices and 39 on odd, stroke
/// `#F5C84C`, width 2.5 on even and 1.5 on odd, round caps.
///
/// The alternating outer radius and stroke width are what make it a sunburst
/// rather than a starburst, so they are computed rather than flattened into
/// fourteen literals — and [sunBurstRays] is a pure function so both can be
/// asserted without a widget.
List<SunBurstRay> sunBurstRays() => <SunBurstRay>[
  for (int i = 0; i < sunBurstRayCount; i++)
    SunBurstRay(
      index: i,
      inner: sunBurstInnerRadius,
      outer: i.isEven ? sunBurstOuterRadiusEven : sunBurstOuterRadiusOdd,
      width: i.isEven ? sunBurstWidthEven : sunBurstWidthOdd,
    ),
];

/// Every ray's inner radius. `ResultScreen.tsx:9` — `const inner = 26`.
const double sunBurstInnerRadius = 26;

/// The even-indexed rays' outer radius. `ResultScreen.tsx:9`.
const double sunBurstOuterRadiusEven = 46;

/// The odd-indexed rays' outer radius. `ResultScreen.tsx:9`.
const double sunBurstOuterRadiusOdd = 39;

/// The even-indexed rays' stroke width. `ResultScreen.tsx:13`.
const double sunBurstWidthEven = 2.5;

/// The odd-indexed rays' stroke width. `ResultScreen.tsx:13`.
const double sunBurstWidthOdd = 1.5;

/// One of the five ember flecks scattered over the burst.
///
/// `ResultScreen.tsx:19-24`.
@immutable
class SunBurstFleck {
  /// Creates a fleck at [centre] with the prototype's radius and alpha.
  const SunBurstFleck({
    required this.centre,
    required this.radius,
    required this.alpha,
  });

  /// Centre on the 100x100 box.
  final Offset centre;

  /// Radius.
  final double radius;

  /// Fill alpha.
  final double alpha;
}

/// The burst's five flecks, `ResultScreen.tsx:19-24`, in source order.
const List<SunBurstFleck> sunBurstFlecks = <SunBurstFleck>[
  SunBurstFleck(centre: Offset(28, 18), radius: 2.5, alpha: 0.9),
  SunBurstFleck(centre: Offset(72, 16), radius: 2, alpha: 0.7),
  SunBurstFleck(centre: Offset(80, 60), radius: 2, alpha: 0.8),
  SunBurstFleck(centre: Offset(16, 64), radius: 2.5, alpha: 0.6),
  SunBurstFleck(centre: Offset(64, 82), radius: 2, alpha: 0.7),
];

/// The three concentric discs, `ResultScreen.tsx:16-18`, largest first.
///
/// `[radius, alpha]` per disc: the r30 halo at `#F5C84C` / 12%, then `r24` at
/// 90%, then `r18` at 60%.
///
/// ## THE ORDER CARRIES NO COLOUR MEANING, AND THE PREVIOUS COMMENT WAS WRONG
///
/// This used to say "note the third is *behind* the other two in the SVG but is
/// larger, so painting it first is what makes it a halo". Both halves of that
/// were wrong:
///
/// - **The premise.** SVG has no z-index; it paints in document order. The
///   prototype's order is `r24 @0.9`, `r18 @0.6`, `r30 @0.12`
///   (`ResultScreen.tsx:16-18`), so the r30 halo is **last** and therefore
///   **on top**, not behind.
/// - **The conclusion.** All three discs are the same colour, `#F5C84C`. Alpha
///   compositing of a single colour over itself is commutative, so the visible
///   result does not depend on the order at all. Measured: restoring the
///   prototype's document order changes **173 of 480,000** pixels in
///   `sun_burst_dark.png`, and the per-channel deltas go in *both* directions
///   (±1 to ±13 on scattered antialiased edge pixels) — the signature of 8-bit
///   rounding, not of a different colour.
///
/// The same is true of the rays, which the prototype also paints before the
/// discs (`:7-15` then `:16-18`) and this painter paints after: a 12% `#F5C84C`
/// wash over a full-strength `#F5C84C` ray leaves the ray exactly unchanged.
/// Painting the rays first moves 118 of 480,000 pixels, again only rounding.
///
/// The order is kept because largest-first is the readable one and it is free.
/// It is **not** kept because it makes a halo, and nothing should be built on
/// the belief that it does.
const List<List<double>> sunBurstDiscs = <List<double>>[
  <double>[30, 0.12],
  <double>[24, 0.9],
  <double>[18, 0.6],
];

/// The celebration burst on the Result screen.
///
/// Fourteen rays, three discs and five flecks, transcribed from
/// `eva/src/screens/ResultScreen.tsx:4-27` into a
/// `CustomPaint` over a `viewBox="0 0 100 100"`.
///
/// ## COLOURS
///
/// The rays and the discs are `#F5C84C`, which is [StickerSlot.sun] — the one
/// prototype colour in this widget that the design system already publishes. The
/// five flecks are `emberHex`, i.e. [EvaColors.ember], and that is why they are a
/// different colour from the rays in the prototype (`ResultScreen.tsx:19-24`).
///
/// ## THE GLOW IS NOT HERE, AND `.bigring` IS WHAT REPLACES IT
///
/// `ResultScreen.tsx:38` wraps the burst in
/// `filter: drop-shadow(0 0 36px rgba(#F5C84C, 0.55))`. That is a property of the
/// **container**, not of the svg — `SunBurst` is the svg, so the glow belongs to
/// whatever places it (the result card) and adding it here would invent a
/// shape the prototype does not have.
///
/// ## THIS WIDGET IS **SUPERSEDED**, AND NOT AT ALL — PHASE 6.2 WAS TO DELETE IT
///
/// `eva/redesign.html`'s result modal has no sun burst. Its mark is `.bigring`
/// (`:447-452`): a 132×132 box, an `svg` rotated `-90deg`, two `circle`s at
/// `stroke-width: 8` with round caps, a `.bgc` track at `rgba(255,255,255,.08)`,
/// an `.fgc` arc drawing itself on over 1s from `stroke-dashoffset: 339`, and the
/// score as a `.val` label in the middle at `font-size: 34px`.
///
/// **A faithful restyle would therefore have deleted this widget — and the glow
/// with it.** `.bigring` declares no `box-shadow` and no `filter` at all: a
/// progress ring is a precise instrument and does not glow. So the honest
/// statement of what happens next is not "this widget gets restyled in Phase 4"
/// but **"this widget stops existing in Phase 6.2"**, and nothing in Task 4.2
/// changed it for that reason.
///
/// **AND PHASE 6.2 KEPT IT, SO THAT PREDICTION WAS WRONG.** The ring was never
/// ported — it needs a denominator, and the submit response carries none
/// (AGENT_CONTEXT decision 93) — so the modal has no `.bigring` to draw and the
/// client's own burst is what the reader sees. `result_sheet.dart` records the
/// choice in its own words: removing it "would have been a second, unrecorded
/// divergence". The two 40/80 glows on `SealMonogram` are the closest thing this
/// design system has to a
/// celebration glow, and `ResultScreen.tsx:4-27` — fourteen rays, three discs,
/// five flecks — is still the only ray table the prototype has. **Nothing here is
/// transcribed from `.bigring`** and nothing here should be read as if it were:
/// the two marks are a burst and a ring, and the resemblance is a coincidence of
/// both being round and gold.
///
/// ## SEMANTICS
///
/// Decorative, and excluded explicitly: the screen's meaning is carried by the
/// score and the stat tiles beside it, and a "celebration" node that says
/// nothing would be read out as noise on every Result visit.
class SunBurst extends StatelessWidget {
  /// A burst [size] logical px square.
  const SunBurst({this.size = 96, super.key});

  /// Width and height in logical px.
  final double size;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _SunBurstPainter(colors)),
      ),
    );
  }
}

class _SunBurstPainter extends CustomPainter {
  const _SunBurstPainter(this.colors);

  final EvaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // `viewBox="0 0 100 100"` scaled to whatever box the widget got.
    canvas.scale(size.width / 100, size.height / 100);
    final Color sun = EvaStickerPalette.of(StickerSlot.sun);

    for (final List<double> disc in sunBurstDiscs) {
      canvas.drawCircle(
        const Offset(50, 50),
        disc[0],
        Paint()..color = sun.withValues(alpha: disc[1]),
      );
    }

    final Paint rayPaint = Paint()
      ..color = sun
      ..strokeCap = StrokeCap.round;
    for (final SunBurstRay ray in sunBurstRays()) {
      canvas.drawLine(ray.start, ray.end, rayPaint..strokeWidth = ray.width);
    }

    final Paint fleckPaint = Paint()..color = colors.ember;
    for (final SunBurstFleck fleck in sunBurstFlecks) {
      canvas.drawCircle(
        fleck.centre,
        fleck.radius,
        fleckPaint..color = colors.ember.withValues(alpha: fleck.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_SunBurstPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
