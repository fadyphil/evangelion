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
/// `ResultScreen.tsx:8-17`: fourteen rays at `i * (360 / 14)` degrees, inner
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

/// Every ray's inner radius. `ResultScreen.tsx:11` — `const inner = 26`.
const double sunBurstInnerRadius = 26;

/// The even-indexed rays' outer radius. `ResultScreen.tsx:11`.
const double sunBurstOuterRadiusEven = 46;

/// The odd-indexed rays' outer radius. `ResultScreen.tsx:11`.
const double sunBurstOuterRadiusOdd = 39;

/// The even-indexed rays' stroke width. `ResultScreen.tsx:15`.
const double sunBurstWidthEven = 2.5;

/// The odd-indexed rays' stroke width. `ResultScreen.tsx:15`.
const double sunBurstWidthOdd = 1.5;

/// One of the five ember flecks scattered over the burst.
///
/// `ResultScreen.tsx:20-24`.
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

/// The burst's five flecks, `ResultScreen.tsx:20-24`, in source order.
const List<SunBurstFleck> sunBurstFlecks = <SunBurstFleck>[
  SunBurstFleck(centre: Offset(28, 18), radius: 2.5, alpha: 0.9),
  SunBurstFleck(centre: Offset(72, 16), radius: 2, alpha: 0.7),
  SunBurstFleck(centre: Offset(80, 60), radius: 2, alpha: 0.8),
  SunBurstFleck(centre: Offset(16, 64), radius: 2.5, alpha: 0.6),
  SunBurstFleck(centre: Offset(64, 82), radius: 2, alpha: 0.7),
];

/// The three concentric discs, `ResultScreen.tsx:18-20`, in source order.
///
/// `[radius, alpha]` per disc: `r24 @0.9`, `r18 @0.6`, and an `r30` halo at
/// `#F5C84C` at 12% — note the third is *behind* the other two in the SVG but is
/// larger, so painting it first is what makes it a halo.
const List<List<double>> sunBurstDiscs = <List<double>>[
  <double>[30, 0.12],
  <double>[24, 0.9],
  <double>[18, 0.6],
];

/// The celebration burst on the Result screen.
///
/// Fourteen rays, three discs and five flecks, transcribed from
/// `eva/src/components/ds.tsx:4-27` (`ResultScreen.tsx`'s `SunBurst`) into a
/// `CustomPaint` over a `viewBox="0 0 100 100"`.
///
/// ## COLOURS
///
/// The rays and the discs are `#F5C84C`, which is [StickerSlot.sun] — the one
/// prototype colour in this widget that the design system already publishes. The
/// five flecks are `emberHex`, i.e. [EvaColors.ember], and that is why they are a
/// different colour from the rays in the prototype (`ResultScreen.tsx:22-26`).
///
/// ## THE GLOW IS NOT HERE
///
/// `ResultScreen.tsx:34` wraps the burst in
/// `filter: drop-shadow(0 0 36px rgba(#F5C84C, 0.55))`. That is a property of the
/// **container**, not of the svg — `SunBurst` is the svg, so the glow belongs to
/// whatever places it (Phase 8's `ResultPage`) and adding it here would invent a
/// shape the prototype does not have.
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
