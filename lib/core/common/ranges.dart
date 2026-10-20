/// The arithmetic a **range input** needs, in one pure place.
///
/// ## WHY THIS FILE EXISTS, AND WHY IT IS **PURE DART**
///
/// A range input's rule is arithmetic: clamp into the range, snap to the step,
/// and turn a pointer's position into a value. AGENT_CONTEXT §6 says that
/// arithmetic must not be buried in a widget — "a widget that computes a clamp,
/// a step or a ratio inline is untested logic wearing a `build` method" — so
/// every piece of it is a top-level function here.
///
/// **AND WHY IT IS NOT BESIDE THE WIDGET THAT USES IT**, which is where
/// `clampFontStep` lives: because **two** callers need it and they may not
/// import each other.
///
/// | caller | what it needs |
/// | --- | --- |
/// | the design system's `EvaRangeSlider` | the control's own semantics — the clamp, the step, and the pointer↔value mapping |
/// | `features/settings/domain/settings_clamps.dart` | the **step** rule, because the prototype's one stepped slider (`:684`, `step="5"`) is a *preference's* range and the settings domain is pure Dart under Gate 1 |
///
/// The design system's copy was in a **Flutter-importing** file, so the
/// settings domain could not call it — and it did not, and so the step rule
/// was written twice. Two implementations of one rule is exactly the drift
/// this repository rejects wherever it finds it, and the two happened to agree
/// only because nobody had changed either.
///
/// `core/common/` is the one directory **both** may reach: it is pure Dart
/// (Gate 1 holds it Flutter-free), it is not a feature (so Gate 2 does not
/// fire on a design-system import of it), and it is not a domain (so the
/// settings domain may import it too).
///
/// **AND THE RANGES THEMSELVES ARE NOT HERE.** This file is the *mechanism*
/// and the ranges are *facts*: the eight ranges the Workshop uses are the
/// prototype's own (`eva/redesign.html:658`, `:659`, `:660`, `:661`, `:669`,
/// `:670`, `:683`, `:684`) and each lives with the field it bounds.
library;

/// Clamps [value] into `min…max`.
///
/// The two numbers are the **caller's**: this function is the mechanism and the
/// range is the fact, and the fact belongs to the field, not to the design
/// system.
int clampRangeValue(int value, int min, int max) {
  assert(min <= max, 'a range needs min <= max, got $min…$max');
  if (max < min) return min;
  return value.clamp(min, max);
}

/// Snaps [value] to the nearest multiple of [step], measured from [min], and
/// clamps the result into `min…max`.
///
/// ## THE STEP IS MEASURED FROM `min`, AND THAT IS CSS'S RULE
///
/// A CSS `input[type=range]`'s valid values are `min + n·step`, not the global
/// multiples of `step`: `redesign.html:684` is
/// `<input type="range" id="setSelahDur" min="15" max="120" step="5">`, so its
/// stops are 15, 20, 25 … 120 — and because 15 is itself a multiple of 5, that
/// set **is** the set of multiples of 5.
///
/// The distinction only shows on a range whose minimum is not a multiple of the
/// step, and there the two readings disagree; the CSS one is chosen because it
/// is the prototype's control and because it keeps [min] reachable, which the
/// global-multiple reading does not.
///
/// ## WHY THE CLAMP AND THE SNAP ARE ONE FUNCTION
///
/// Because the order matters and a caller should not have to know it: a value
/// below the minimum must be raised **to the minimum** and not to the nearest
/// step below it (which would be outside the range), and a value above the
/// maximum must be lowered **to the maximum**. Snapping first and clamping
/// after would put the minimum's own neighbour within reach, and clamping first
/// and snapping after would leave `min` unreachable on a range whose minimum is
/// not a step multiple.
int steppedRangeValue(int value, int min, int max, int step) {
  final int clamped = clampRangeValue(value, min, max);
  if (step <= 1) return clamped;
  final int offset = (((clamped - min) / step).round()) * step;
  return (min + offset).clamp(min, max);
}

/// The value a pointer at [dx] from the thumb's centre selects, over a travel
/// of [travel].
///
/// ## WHY THIS IS A FUNCTION AND NOT A LINE IN A `build` CLOSURE
///
/// AGENT_CONTEXT §6: "domain logic must not be buried inside a widget". The
/// pointer→value mapping is the calculation whose wrong answer is a slider
/// sitting at a value the reader did not choose, and it is arithmetic — so it
/// is here, testable without a widget tree.
///
/// The three steps, in the order they must happen:
///
/// 1. the pointer's offset from the thumb's **centre** is [dx];
/// 2. that is a **fraction** of the travel, clamped to `0…1` — a drag past
///    either end selects the end, and a travel of zero (a track narrower than
///    the thumb) selects the minimum rather than dividing by zero;
/// 3. the fraction is the way along the **value** range, and the value is
///    snapped to the step.
///
/// [dx] is measured from the thumb's centre rather than the track's start
/// because the thumb is centred on its value: a pointer at the track's very
/// start is half a thumb off the minimum, and treating that as the minimum
/// would make the first few pixels of the track dead.
int valueForOffset({
  required double dx,
  required double travel,
  required int min,
  required int max,
  required int step,
}) {
  final double fraction = travel <= 0 ? 0 : (dx / travel).clamp(0.0, 1.0);
  final int span = max - min;
  final int raw = span == 0 ? min : min + (fraction * span).round();
  return steppedRangeValue(raw, min, max, step);
}

/// The thumb's offset from the track's start, for [value], over a travel of
/// [travel].
///
/// **The mirror of [valueForOffset]**, and it is a separate function because
/// the two round differently on purpose: the pointer→value direction rounds the
/// **value**, and the value→pointer direction rounds the **position**. Rounding
/// the position to whole pixels would make the thumb sit a pixel off the value
/// it represents, and the thumb is the thing the reader is looking at.
///
/// A range whose [min] and [max] are equal has no travel, and the thumb sits
/// at the start.
double offsetForValue({
  required int value,
  required int min,
  required int max,
  required double travel,
}) {
  final int span = max - min;
  if (span == 0 || travel <= 0) return 0;
  final double fraction = (clampRangeValue(value, min, max) - min) / span;
  return fraction * travel;
}
