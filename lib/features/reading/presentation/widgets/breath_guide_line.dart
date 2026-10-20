import 'package:evangelion/core/common/cycle_phase.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/reading/domain/breath_guide.dart';
import 'package:flutter/material.dart';

/// The breath guide — the line that breathes under the reader's chosen verse.
///
/// `eva/redesign.html:173-175`:
///
/// ```css
/// .breath{height:2px;margin:0 0 14px;border-radius:2px;
///   background:linear-gradient(90deg,transparent,var(--gold),transparent);
///   animation:breath 8s ease-in-out infinite}
/// @keyframes breath{0%,100%{transform:scaleX(.25);opacity:.25}50%{transform:scaleX(1);opacity:.6}}
/// ```
///
/// ## WHERE IT IS DRAWN
///
/// The prototype's `setBreathUnder(p)` (`:1372-1376`) removes every existing
/// `.breath` and puts a new one **after** the verse `p` — the verse the reader
/// has selected, or the one they left off at. So the guide belongs to **one**
/// verse at a time, and the reading screen owns which.
///
/// ## AND THE **CURVE** IS CSS'S `ease-in-out`
///
/// Flutter's `Curves.easeInOut` is `Cubic(0.42, 0.0, 0.58, 1.0)` — the exact
/// bezier the CSS keyword `ease-in-out` names — so the client applies the
/// prototype's own curve and not an approximation of it. The **numbers** are
/// `features/reading/domain/breath_guide.dart`'s, because a decoration's
/// arithmetic is not a widget's business.
class BreathGuideLine extends StatefulWidget {
  /// The line.
  const BreathGuideLine({super.key});

  /// The line's height. `eva/redesign.html:173` — `height:2px`.
  static const double height = 2;

  /// The line's rounding. `eva/redesign.html:173` — `border-radius:2px`.
  static const double radius = 2;

  /// The gap under the line. `eva/redesign.html:173` — `margin: 0 0 14px`.
  static const double bottomGap = 14;

  @override
  State<BreathGuideLine> createState() => _BreathGuideLineState();
}

class _BreathGuideLineState extends State<BreathGuideLine>
    with SingleTickerProviderStateMixin {
  /// The line's clock.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kBreathCycle,
  );

  /// Whether the line is breathing.
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **Not in [initState]** — `MediaQuery.disableAnimationsOf` is an
    // inherited-widget lookup and Flutter forbids one before `initState`
    // completes.
    _sync();
  }

  /// Breathes the line, or holds it still under reduced motion.
  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop(canceled: false);
      _running = false;
      return;
    }
    if (_running) return;
    _controller.repeat();
    _running = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // ## THE END STATE, AND WHY IT IS **NOT** A KEYFRAME
        //
        // §14 asks a reduced-motion reader for "the end state", and for a
        // *repeating* animation the end state is the state the element is in
        // when the animation is not running. CSS's `animation-fill-mode`
        // defaults to `none` — so the keyframes' values apply **only while the
        // animation runs** — and `:173-174` declares no `transform` and no
        // `opacity` on `.breath` at all.
        //
        // So the line at rest is `transform: none` (a scale of 1) and
        // `opacity: 1`: **wider and more opaque than the animation's widest
        // keyframe**, which is `scaleX(1)` at `opacity:.6`.
        //
        // **And the prototype's own reduced-motion rules do not cover this
        // element.** `:48-50` kills eleven selectors, and `.breath` is not one
        // of them — so the prototype's breath guide keeps breathing under
        // reduced motion. This client honours §14 instead, and the divergence
        // is recorded here.
        final BreathPhase phase = _running
            ? breathPhaseAt(
                Curves.easeInOut.transform(
                  halfCycleProgress(_controller.value),
                ),
              )
            : kBreathRest;

        return Padding(
          padding: const EdgeInsets.only(bottom: BreathGuideLine.bottomGap),
          child: Transform.scale(
            // CSS's `transform-origin` defaults to `50% 50%`, which is
            // `Transform.scale`'s own default.
            scale: phase.scale,
            child: Opacity(
              opacity: phase.opacity,
              child: SizedBox(
                // **The full width of the verse column**, and not the width of
                // its content: the prototype's `.breath` is a `<div>` — a
                // block element — and a block element fills its container. A
                // Flutter `Container` with no child sizes itself to **nothing**
                // under the list's loose cross-axis constraint, so the guide
                // would have been invisible.
                width: double.infinity,
                height: BreathGuideLine.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(BreathGuideLine.radius),
                    // `:173` — `linear-gradient(90deg,transparent,var(--gold),
                    // transparent)`. The gold is this palette's `ember`.
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        colors.ember,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
