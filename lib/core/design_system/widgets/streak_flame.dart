import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The streak flame that sits beside a day count.
///
/// ## THE PATH IS THE PROTOTYPE'S, CHARACTER FOR CHARACTER
///
/// `eva/src/components/ds.tsx:513-514` draws a `<svg viewBox="0 0 16 20">` with
/// one `<path>` and no other element. The `d` attribute is transcribed into
/// [flamePath] unchanged — every curve command, every coordinate. Re-deriving a
/// flame shape from a description would be a different flame.
///
/// ## SIZE
///
/// [size] is the **height**, and the width follows the viewBox's `16:20` ratio,
/// so the whole box scales uniformly and the path cannot be distorted. The
/// prototype renders the svg at `width="14" height="18"`
/// (`ds.tsx:513`) — 0.778 of its height rather than the viewBox's 0.8. The 2%
/// difference is the viewBox's own horizontal padding (the path spans x 2…14 of
/// a 16-wide box), and scaling the box uniformly rather than reproducing the
/// element's pixel box is the choice that keeps the shape honest at any size.
///
/// ## SEMANTICS
///
/// The flame is not decoration: it is the icon for a streak, and it sits next to
/// a number that means "days". It therefore carries a label, unlike
/// [SunBurst] or [GoldFlecks]. The default is English because Phase 2 has no
/// string table; Phase 3 and Phase 6 pass a localised one.
class StreakFlame extends StatelessWidget {
  /// A flame of [size] logical px tall, filled with `ember`.
  const StreakFlame({this.size = 18, this.semanticLabel = 'Streak', super.key});

  /// Height in logical px. Width is [size] × `16 / 20`.
  final double size;

  /// The accessible name. See the class doc for why this is not decoration.
  final String semanticLabel;

  /// The prototype's box width-to-height ratio, `viewBox="0 0 16 20"`.
  static const double aspect = 16 / 20;

  /// The width [size] implies.
  double get width => size * aspect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: size,
        child: CustomPaint(painter: _FlamePainter(context.colors.ember)),
      ),
    );
  }
}

/// The flame's outline, in the prototype's own viewBox units.
///
/// Transcribed from `ds.tsx:514`'s `d` attribute. Kept in viewBox units so the
/// painter can scale the canvas rather than rescale 40 numbers — a rescale is
/// where a transcription goes wrong.
final Path flamePath = Path()
  ..moveTo(8, 0)
  ..cubicTo(8, 0, 4, 5, 4, 9)
  ..cubicTo(4, 10.5, 4.5, 12, 6, 13)
  ..cubicTo(5.5, 11, 6.5, 9, 8, 8)
  ..cubicTo(9, 10, 9.5, 11, 9, 13)
  ..cubicTo(10.5, 12, 11, 10.5, 11, 9)
  ..cubicTo(11, 7, 10, 5, 10, 5)
  ..cubicTo(11.5, 6.5, 12, 9, 12, 11)
  ..cubicTo(12, 14.5, 10.5, 17, 8, 19)
  ..cubicTo(5.5, 17, 4, 14.5, 4, 11)
  ..cubicTo(4, 10.5, 4.05, 10, 4.1, 9.5)
  ..cubicTo(2.5, 11, 2, 13, 2, 15)
  ..cubicTo(2, 17.8, 4.7, 20, 8, 20)
  ..cubicTo(11.3, 20, 14, 17.8, 14, 15)
  ..cubicTo(14, 10, 8, 0, 8, 0)
  ..close();

class _FlamePainter extends CustomPainter {
  const _FlamePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 20);
    canvas.drawPath(flamePath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.color != color;
}
