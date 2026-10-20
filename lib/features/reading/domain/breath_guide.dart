/// The breath guide's line and where it is in its cycle.
///
/// PURE DART — Gate 1 holds `features/*/domain/` Flutter-free, so this file
/// names no `Curves` and no `AnimationController`.
library;

import 'package:evangelion/core/common/cycle_phase.dart';

/// One full breath cycle. `eva/redesign.html:174` — `animation:breath 8s
/// ease-in-out infinite`.
const Duration kBreathCycle = Duration(seconds: 8);

/// The line's narrowest scale. `eva/redesign.html:175` — `0%,100%{transform:
/// scaleX(.25);opacity:.25}`.
const double kBreathScaleMin = 0.25;

/// The line's widest scale. `eva/redesign.html:175` — `50%{transform:
/// scaleX(1);opacity:.6}`.
const double kBreathScaleMax = 1;

/// The line's faintest opacity. `eva/redesign.html:175`.
const double kBreathOpacityMin = 0.25;

/// The line's strongest opacity. `eva/redesign.html:175`.
const double kBreathOpacityMax = 0.6;

/// The line at rest — the state it is in when the animation is **not** running.
///
/// `eva/redesign.html:173-174` declares no `transform` and no `opacity` on
/// `.breath`, and CSS's `animation-fill-mode` defaults to `none` — so the
/// keyframes' values apply **only while the animation runs**.
///
/// So the line at rest is `transform: none` (a scale of 1) and `opacity: 1`:
/// **wider and more opaque than the animation's widest keyframe**, which is
/// `scaleX(1)` at `opacity:.6`.
///
/// **This is §14's end state for the line**, and it is a *rest* rather than a
/// keyframe — a frozen half would be the 50% peak, and the point of the end
/// state is that the reader is given a whole line rather than a fragment of
/// one.
const BreathPhase kBreathRest = BreathPhase(scale: 1, opacity: 1);

/// The breath guide's scale and opacity at one point in its cycle.
final class BreathPhase {
  /// The line's horizontal scale.
  final double scale;

  /// The line's opacity.
  final double opacity;

  /// Creates a phase.
  const BreathPhase({required this.scale, required this.opacity});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreathPhase &&
          runtimeType == other.runtimeType &&
          scale == other.scale &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(scale, opacity);

  @override
  String toString() => 'BreathPhase(scale: $scale, opacity: $opacity)';
}

/// The line's scale and opacity at an **eased** progress through the cycle.
///
/// [progress] is 0 at the narrowest and 1 at the widest, already eased — the
/// curve belongs to the widget, because `Curves` is Flutter and this file is
/// not. See [breathHalfProgressAt] for the other half of the pair.
///
/// **Flutter's `Curves.easeInOut` IS CSS's `ease-in-out`** — it is
/// `Cubic(0.42, 0.0, 0.58, 1.0)`, which is the exact bezier the CSS keyword
/// names — so the widget that eases the progress is applying the prototype's
/// own curve and not an approximation of it. That is why the easing lives
/// there and only the keyframes live here.
BreathPhase breathPhaseAt(double progress) {
  final double eased = progress < 0
      ? 0
      : progress > 1
      ? 1
      : progress;
  return BreathPhase(
    scale: kBreathScaleMin + (kBreathScaleMax - kBreathScaleMin) * eased,
    opacity:
        kBreathOpacityMin + (kBreathOpacityMax - kBreathOpacityMin) * eased,
  );
}

/// How far through the **current half** of the cycle [elapsed] is, 0…1.
///
/// The prototype's keyframes are at 0%, 50% and 100% — so the line expands over
/// the first half of the eight seconds and contracts over the second, and the
/// progress within a half is a straight line from 0 to 1 (or 1 to 0).
///
/// **A negative elapsed time reads as the start of the cycle**, because the
/// triangle's arithmetic would otherwise report a negative progress and the
/// widget would extrapolate a line scaled past its own minimum.
///
/// The triangle itself is `core/common/cycle_phase.dart`'s, because the
/// selah card's ring breathes on the same shape and the two must not be two
/// spellings of one number.
double breathHalfProgressAt(Duration elapsed) =>
    halfCycleProgress(cycleProgress(elapsed: elapsed, cycle: kBreathCycle));
