import 'package:flutter/animation.dart';

/// The Eva motion table — durations and curves in one place.
///
/// `docs/plans/03-design-system.md` §5.3:
///
/// | Token | Duration | Curve |
/// | --- | --- | --- |
/// | `fast` | 150ms | `easeOut` |
/// | `base` | 200ms | `easeOut` |
/// | `screen` | 250ms | `easeOutCubic` |
/// | `fleck` | 2000ms | `alternate` |
/// | `orbFloat` | 14–28s per orb | `easeInOut` |
/// | `orbHue` | 7–14s per orb | `linear` |
/// | `aurora` | 14s | `easeInOut` |
///
/// and, immediately after: "All curves are ease-out. No bounce, no spring."
///
/// WHY THE AMBIENT ANIMATIONS ARE NOT `AnimationController`s HELD HERE. There
/// are three shared controllers app-wide — float, hue, aurora
/// (`09-quality-gates.md` §13, mitigation 2) — and they live in a
/// `TickerProviderStateMixin` host mounted above `MaterialApp.router`, published
/// through an inherited scope. That is Phase 2's `NeuralMotionScope`. This file
/// holds only the numbers and the shapes, which is why it has no `Ticker` and no
/// `vsync`: a `SingleTickerProvider` here would re-introduce exactly the
/// per-orb controller explosion that mitigation 2 exists to remove.
///
/// WHY `fleck`'s "alternate" IS A FLAG AND NOT A CURVE. Flutter has no
/// `Curves.alternate`. There-and-back is a *direction*, expressed as
/// `AnimationController.repeat(reverse: true)`, and it is orthogonal to the
/// easing shape. So [fleckCurve] carries the ease-out shape the brief's rule
/// requires and [fleckAlternates] carries the direction for Phase 2 to act on.
/// Collapsing the two into one token would have meant inventing a curve.
abstract final class EvaMotion {
  // --- Durations -----------------------------------------------------------

  /// `150ms` — press and hover feedback on a control.
  static const Duration fast = Duration(milliseconds: 150);

  /// `200ms` — a state change on an element already on screen.
  static const Duration base = Duration(milliseconds: 200);

  /// `250ms` — a screen-level transition.
  static const Duration screen = Duration(milliseconds: 250);

  /// `2000ms` — one full there-and-back cycle of a `GoldFlecks` fleck.
  static const Duration fleck = Duration(seconds: 2);

  /// `14s` — one full aurora cycle.
  static const Duration aurora = Duration(seconds: 14);

  /// `14s` — the shortest an orb's float cycle may run.
  ///
  /// §5.3 gives `orbFloat` as the range `14–28s per orb`, not a single value, so
  /// the range is the token and [orbFloatFor] spreads it. There is no single
  /// "orbFloat duration" to expose, and exposing the minimum alone would quietly
  /// collapse the range.
  static const Duration orbFloatMin = Duration(seconds: 14);

  /// `28s` — the longest an orb's float cycle may run.
  static const Duration orbFloatMax = Duration(seconds: 28);

  /// `7s` — the shortest an orb's hue cycle may run.
  static const Duration orbHueMin = Duration(seconds: 7);

  /// `14s` — the longest an orb's hue cycle may run.
  static const Duration orbHueMax = Duration(seconds: 14);

  // --- Curves --------------------------------------------------------------

  /// `easeOut` — with [fast].
  static const Curve fastCurve = Curves.easeOut;

  /// `easeOut` — with [base].
  static const Curve baseCurve = Curves.easeOut;

  /// `easeOutCubic` — with [screen]. Steeper than [fastCurve]: a whole screen
  /// arriving needs more of its motion spent early than a button tinting does.
  static const Curve screenCurve = Curves.easeOutCubic;

  /// `easeOut` — with [fleck]; see [fleckAlternates] for the direction.
  static const Curve fleckCurve = Curves.easeOut;

  /// `easeInOut` — with the orb float cycles.
  static const Curve orbFloatCurve = Curves.easeInOut;

  /// `linear` — with the orb hue cycles. A hue *rotation* eased would
  /// accelerate through the colour wheel and read as flicker, not breathing.
  static const Curve orbHueCurve = Curves.linear;

  /// `easeInOut` — with [aurora].
  static const Curve auroraCurve = Curves.easeInOut;

  /// Whether a fleck animation should run there-and-back rather than restarting.
  ///
  /// The `alternate` column of the §5.3 table. Phase 2 reads this to choose
  /// `repeat(reverse: true)` over `repeat()`.
  static const bool fleckAlternates = true;

  // --- Per-orb spread ------------------------------------------------------

  /// The float duration of the [index]-th of [count] orbs.
  ///
  /// SPREAD ACROSS THE SPEC RANGE, ENDPOINTS INCLUDED. §5.3 gives `14–28s per
  /// orb` and nothing else, so this is the one place a formula had to be chosen:
  /// the even spread, so orb 0 runs [orbFloatMin] and orb `count - 1` runs
  /// [orbFloatMax]. The alternative — one duration for every orb — is precisely
  /// the lockstep pulse `09-quality-gates.md` §13 mitigation 2 forbids, and a
  /// random spread is untestable, which is the other half of why this is even.
  ///
  /// Phase 2 derives the *phase* offset the same way (`index / count`); only the
  /// duration lives here.
  static Duration orbFloatFor(int index, int count) =>
      _spread(index, count, orbFloatMin, orbFloatMax);

  /// The hue-rotation duration of the [index]-th of [count] orbs. The even
  /// spread of §5.3's `7–14s per orb` range; see [orbFloatFor].
  static Duration orbHueFor(int index, int count) =>
      _spread(index, count, orbHueMin, orbHueMax);

  /// Even spread of `[min, max]` across `count` slots, `min` at index 0 and
  /// `max` at `count - 1`.
  ///
  /// A single orb collapses to [min] rather than dividing by `count - 1 == 0`.
  /// One orb is a real configuration: `NeuralTier` drops to `low` with no orbs
  /// at all, and a narrow window can leave exactly one.
  static Duration _spread(int index, int count, Duration min, Duration max) {
    assert(count > 0, 'orb count must be positive, got $count');
    if (count == 1) return min;
    final int micros =
        min.inMicroseconds +
        (max.inMicroseconds - min.inMicroseconds) * index ~/ (count - 1);
    return Duration(microseconds: micros);
  }
}
