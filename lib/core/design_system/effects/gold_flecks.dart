import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// The celebration flecks `QuizScreen` scatters over a correct option.
///
/// Four 5px gold dots, each floating 9px up and fading while it goes, staggered
/// so the cluster shimmers rather than blinking.
///
/// ## IT HAS NO CONTROLLER OF ITS OWN
///
/// The obvious implementation is a `StatefulWidget` with one
/// `AnimationController(duration: EvaMotion.fleck)..repeat(reverse: true)` per
/// instance — and it would be a fourth ambient controller in a design system
/// whose entire §13.2 argument is that three is the number. So [GoldFlecks] is
/// the `StatelessWidget` `04-widget-inventory.md` says it is, reads the shared
/// **float** clock through [NeuralMotionScope], and derives its own 2s phase
/// from it: the float clock runs at `1 / kFloatPeriod` per second and a fleck
/// cycle is `1 / EvaMotion.fleck`, so the fleck phase is the float phase scaled
/// by `kFloatPeriod / EvaMotion.fleck` — ten fleck cycles per float cycle.
///
/// One clock, no extra ticker, and the flecks drift in step with the orbs rather
/// than against them. [GoldFlecks.kFloatPeriod] publishes that ratio.
///
/// ## `dense` HAS NO PROTOTYPE
///
/// The inventory names the flag and the prototype has no dense variant — the
/// only call sites are `QuizScreen.tsx:92-95`, four sparse flecks with delays of
/// 0 / 110 / 220 / 340ms. So the flag is given the one meaning it can have
/// without inventing geometry: a second, larger, dimmer ring around each fleck.
/// Recorded here so a later phase does not go looking for a prototype that was
/// never built.
class GoldFlecks extends StatelessWidget {
  /// Draws one fleck per entry in [offsets].
  const GoldFlecks({required this.offsets, this.dense = false, super.key});

  /// Where each fleck sits, in logical px from **this widget's** top-left.
  ///
  /// Caller-supplied because the prototype positions them relative to the option
  /// card they decorate (`QuizScreen.tsx:92-95` puts two just outside the left
  /// edge and two just outside the right), which a positioned overlay in the
  /// feature knows and a design-system widget cannot.
  final List<Offset> offsets;

  /// Adds the outer ring. See the class doc.
  final bool dense;

  /// How many fleck cycles fit in one float cycle: `20s / 2s`.
  static const int flecksPerFloatCycle = 10;

  @override
  Widget build(BuildContext context) {
    final EvaNeuralMotion motion = NeuralMotionScope.of(context);
    // §14: "every animation checks `MediaQuery.disableAnimationsOf(context)`".
    // `maybe` because a fleck can legitimately be pumped without a `MediaQuery`
    // in a preview; absent means enabled, which is the framework's own default.
    final bool animate =
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    return IgnorePointer(
      // `pointerEvents: 'none'` in the prototype (`QuizScreen.tsx:19`).
      child: ExcludeSemantics(
        // Purely decorative: the flecks sit on top of an option card whose text
        // already says it is correct, so announcing four dots would add four
        // useless nodes to the semantics tree. Explicitly excluded rather than
        // left to the default, because a `CustomPaint` childless of semantics
        // is not the same as an absent one once a caller nests something here.
        child: CustomPaint(
          size: Size.infinite,
          painter: _GoldFleckPainter(
            offsets: offsets,
            dense: dense,
            // The painter reads the clock itself rather than being handed a
            // snapshot, because a snapshot taken in `build` is only as fresh as
            // the last rebuild — and nothing rebuilds this widget per frame. The
            // first version did exactly that and the flecks sat motionless while
            // the background behind them drifted; `CustomPainter.repaint` below
            // is what makes the animation real.
            motion: motion,
            animate: animate,
            color: context.colors.ember,
          ),
        ),
      ),
    );
  }
}

/// One fleck's radius and glow, `QuizScreen.tsx:15-16`.
const double kFleckRadius = 2.5;

/// The fleck's `box-shadow: 0 0 10px` reach, in logical px.
const double kFleckGlow = 10;

/// `fleck-float`'s travel, `index.css:87` — `translateY(0) → translateY(-9px)`.
const double kFleckTravel = 9;

/// `fleck-float`'s opacity endpoints, `index.css:86-88` — `0.85 → 0.35`.
const double kFleckOpacityHigh = 0.85;
const double kFleckOpacityLow = 0.35;

/// The `dense` ring: 2.2x the fleck's radius at 28% alpha.
const double kFleckDenseScale = 2.2;
const double kFleckDenseAlpha = 0.28;

/// How far apart the flecks' phases are spread, as a fraction of one cycle.
///
/// The prototype's four delays are 0, 110, 220 and 340ms out of a 2000ms cycle —
/// a spread of `340 / 2000 = 0.17`, and they are not evenly spaced. `0.2` is
/// that spread rounded up to a clean fraction, applied evenly as `i / count`,
/// which is §13.2's own rule for staggering a shared clock.
const double kFleckPhaseSpread = 0.2;

/// The `0 → 1 → 0` triangle of `2s ease-in-out infinite alternate`.
///
/// `index.css:85-88` has two keyframes and `alternate`, i.e. there-and-back. The
/// float clock is a sawtooth, so the there-and-back is built from it here.
double goldFleckTriangle(double phase) =>
    1 - (2 * (phase % 1.0) - 1).abs().clamp(0.0, 1.0);

/// The phase of fleck [index] of [count] within one 2s cycle.
double goldFleckPhase({
  required double clock,
  required int index,
  required int count,
}) {
  if (count <= 0) return 0.0;
  final double fleckPhase = clock * GoldFlecks.flecksPerFloatCycle;
  return (fleckPhase + (index / count) * kFleckPhaseSpread) % 1.0;
}

/// Paints the flecks.
class _GoldFleckPainter extends CustomPainter {
  _GoldFleckPainter({
    required this.offsets,
    required this.dense,
    required this.motion,
    required this.animate,
    required this.color,
  }) : super(repaint: motion.repaint);

  final List<Offset> offsets;
  final bool dense;

  /// The shared clock, read at paint time. See the call site.
  final EvaNeuralMotion motion;

  /// `false` under reduced motion, which freezes the flecks at rest.
  final bool animate;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double clock = animate ? motion.floatValue : 0.0;
    for (int i = 0; i < offsets.length; i++) {
      final double triangle = goldFleckTriangle(
        goldFleckPhase(clock: clock, index: i, count: offsets.length),
      );
      final Offset centre = offsets[i] + Offset(0, -kFleckTravel * triangle);
      final double alpha =
          kFleckOpacityHigh + (kFleckOpacityLow - kFleckOpacityHigh) * triangle;

      canvas.drawCircle(
        centre,
        kFleckRadius,
        Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: centre, radius: kFleckGlow / 2),
              ),
      );
      // The solid core on top of the glow, so the fleck is a crisp dot with a
      // halo rather than a soft blob — `background: '#E8A33D'` plus
      // `box-shadow: 0 0 10px #E8A33D'`.
      canvas.drawCircle(
        centre,
        kFleckRadius,
        Paint()..color = color.withValues(alpha: alpha),
      );
      if (dense) {
        canvas.drawCircle(
          centre,
          kFleckRadius * kFleckDenseScale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: kFleckDenseAlpha * alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GoldFleckPainter oldDelegate) =>
      oldDelegate.animate != animate ||
      oldDelegate.dense != dense ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.offsets, offsets);
}
