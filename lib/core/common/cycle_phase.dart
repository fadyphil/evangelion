/// The progress through a cycle that runs **out and back**.
///
/// PURE DART — Gate 1 holds `core/common/` Flutter-free, so this file names no
/// `Curves` and no `AnimationController`.
///
/// ## WHY IT IS SHARED
///
/// Two decorations in this app breathe on the same shape: the selah card's
/// ring (`eva/redesign.html:269-270`, an 8-second `breatheRing`) and the
/// reading screen's breath guide (`eva/redesign.html:174-175`, an 8-second
/// `breath`). **Both declare their keyframes at 0%, 50% and 100%**, so both
/// widen over the first half of the cycle and narrow over the second, and both
/// are eased with CSS's `ease-in-out` **per half**.
///
/// Two copies of that triangle would be two spellings of one number, and this
/// repository rejects that wherever it finds it. So the triangle is here, and
/// the two decorations carry only their own keyframe tables.
///
/// ## AND WHY THE **CURVE** IS NOT HERE
///
/// CSS's `ease-in-out` is `cubic-bezier(0.42, 0, 0.58, 1)`, and **Flutter's
/// `Curves.easeInOut` is exactly that bezier** — so the curve is the
/// framework's own, and applying it is a presentation concern. Both callers
/// hold the linear half progress and ease it themselves, and the number this
/// file owns is the one that would otherwise be written twice.
library;

/// The progress through [cycle] at [elapsed], 0…1.
///
/// A negative [elapsed] reads as the start of the cycle: the arithmetic would
/// otherwise report a negative progress, and a caller that eased it would draw
/// a decoration scaled past its own minimum.
double cycleProgress({required Duration elapsed, required Duration cycle}) {
  final int cycleMicroseconds = cycle.inMicroseconds;
  if (cycleMicroseconds <= 0) return 0;
  final int elapsedMicroseconds = elapsed.inMicroseconds;
  if (elapsedMicroseconds <= 0) return 0;
  return (elapsedMicroseconds % cycleMicroseconds) / cycleMicroseconds;
}

/// The progress through the **current half** of a cycle, 0…1.
///
/// A cycle whose keyframes sit at 0%, 50% and 100% runs out over the first
/// half and back over the second — so this is 0 → 1 over the first half and
/// 1 → 0 over the second, both linear.
///
/// [cycleProgress] outside 0…1 is clamped rather than extrapolated: the
/// triangle's arithmetic would otherwise report a progress above 1, and a
/// caller that eased it would scale a decoration past its own maximum.
double halfCycleProgress(double cycleProgress) {
  final double t = cycleProgress < 0
      ? 0
      : cycleProgress > 1
      ? 1
      : cycleProgress;
  return t <= 0.5 ? t * 2 : (1 - t) * 2;
}
