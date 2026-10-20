import 'dart:ui' as ui;

/// How often the ambient layer is allowed to **paint** and to **notify**.
///
/// ## WHY THIS EXISTS
///
/// The ambient is the app's most expensive layer and it had **no budget at
/// all**. Two things ran on **every vsync**:
///
/// * the **aurora** — a full-screen fragment shader, re-rasterised at device
///   resolution, which on a 1080×2400 phone is **2.6 M fragments a frame**;
/// * the **notification** that rebuilds the witness sky's **forty-four stars**,
///   their forty-four composited `Opacity` layers and their eighty-eight
///   shadow blurs.
///
/// §13 rule 4 asked for exactly this and it was never built: *"a `NeuralTier`
/// derived from `MediaQuery` size and platform frame budget drops to `low` on
/// low-end devices: no orbs, aurora only, at **30 % cost**."* `LumenTiers` has
/// no such member, and the divisors below are the 30 % it named.
///
/// ## WHY IT IS A **FRAME COUNT** AND NOT A TIME INTERVAL
///
/// Because a time interval needs a **clock**, and every clock available here
/// is wrong for one reason or another:
///
/// * `DateTime.now()` is a **wall clock** — it can go backwards, and a gate
///   that goes backwards stops firing.
/// * `Stopwatch` measures **real** time, and a real-time gate makes every
///   **golden** that depends on the ambient **non-deterministic**: the frame
///   that captured it would depend on how fast the machine ran.
/// * `SchedulerBinding.currentFrameTimeStamp` **asserts that a frame is in
///   progress**, and the ambient's notification can arrive outside one.
/// * The **shader clock's** own elapsed time is **one frame behind** the
///   float clock, because the two tickers tick in sequence and the float
///   ticks first — so a gate reading it lags by a frame.
///
/// **A frame count has none of those problems.** It is exact, it is
/// reproducible, and it is the unit the thing being budgeted is already
/// counted in: the ambient's notification is already **one per frame**, and
/// the scene's tick is already **one per frame**.
///
/// ## AND WHY THE MOTION IS **NOT** AFFECTED
///
/// The budget caps **how often the frame is painted**, not **how far the
/// motion advances**. The eased values are advanced on every tick, with the
/// prototype's per-frame constants untouched — so the aurora's trajectory is
/// **exactly** what it was, and only the painting is rarer.
///
/// **And the alternative was rejected on the prototype's own terms.** Capping
/// the *state* and converting the per-frame eases to per-second would have
/// been a **divergence from the prototype**: `redesign.html:891-892`'s
/// `ambI += (base-ambI)*0.06` is a per-frame constant, and the prototype's
/// own `dt` is used for the *auto hue* and the *time accumulator*, never for
/// the eases. `lumen_scene_test.dart` asserts one frame's ease to twelve
/// decimal places, and that assertion is right.
final class AmbientTickBudget {
  /// Creates a budget from the two divisors.
  const AmbientTickBudget({
    required this.paintEveryNTick,
    required this.notifyEveryNTick,
  });

  /// The budget for a display that refreshes at [displayRefreshRate].
  ///
  /// **A cap, and not a division.** A display slower than the budget is left
  /// alone — a 24 Hz panel is already below the aurora's 30 Hz, and
  /// throttling it further would be a cost with no benefit.
  ///
  /// **The divisors are rounded, and that is what a divisor is for.** At 60 Hz
  /// the aurora's divisor is **2** (thirty paints a second) and the sky's is
  /// **3** (twenty a second). At 90 Hz they are 3 and 5. At 120 Hz, 4 and 6.
  static AmbientTickBudget resolve({required double displayRefreshRate}) {
    if (!displayRefreshRate.isFinite || displayRefreshRate <= 0) {
      return const AmbientTickBudget(paintEveryNTick: 2, notifyEveryNTick: 3);
    }
    return AmbientTickBudget(
      paintEveryNTick: _divisorFor(displayRefreshRate, targetHz: 30),
      notifyEveryNTick: _divisorFor(displayRefreshRate, targetHz: 20),
    );
  }

  /// The divisor that turns [displayRefreshRate] into [targetHz].
  ///
  /// **Rounded to the nearest whole frame**, and clamped to at least one — a
  /// divisor of zero would mean "never", and a budget that never paints is a
  /// black screen.
  static int _divisorFor(
    double displayRefreshRate, {
    required double targetHz,
  }) {
    final double divisor = displayRefreshRate / targetHz;
    if (!divisor.isFinite || divisor < 1) return 1;
    return divisor.round().clamp(1, 1000);
  }

  /// How many frames pass between two aurora repaints.
  ///
  /// **One means "every frame"** — no budget at all, which is what a caller
  /// that wants the old behaviour passes.
  final int paintEveryNTick;

  /// How many frames pass between two ambient notifications.
  final int notifyEveryNTick;

  /// The budget for the platform's own display.
  ///
  /// **And the platform's, and not a constant**, because the *display* is the
  /// thing that decides how often a frame can be painted. A 120 Hz panel can
  /// paint four times as often as a 60 Hz one, and the budget is what stops
  /// the ambient from taking the invitation.
  ///
  /// **The first display**, because a phone has one and a desktop has a
  /// primary; the alternative — the *fastest* of them — would let a 240 Hz
  /// monitor pull the whole app's ambient up with it.
  static AmbientTickBudget resolveForPlatform() {
    final Iterable<ui.Display> displays =
        ui.PlatformDispatcher.instance.displays;
    if (displays.isEmpty) {
      return const AmbientTickBudget(paintEveryNTick: 2, notifyEveryNTick: 3);
    }
    return resolve(displayRefreshRate: displays.first.refreshRate);
  }

  /// The gate the aurora's painter is paced by.
  AmbientTickGate get paintGate => AmbientTickGate(paintEveryNTick);

  /// The gate the ambient's notification is paced by.
  AmbientTickGate get notifyGate => AmbientTickGate(notifyEveryNTick);

  @override
  String toString() =>
      'AmbientTickBudget(paint: every $paintEveryNTick frame(s), '
      'notify: every $notifyEveryNTick frame(s))';
}

/// A gate over a **frame count**: *"is it this frame?"*.
///
/// ## WHY IT IS A CLASS AND NOT A COMPARISON IN THE CALLER
///
/// Because the counter carries **state**, and a counter with state in it is a
/// counter that gets written twice. This is the one definition, and both
/// budgets use it.
///
/// ## AND WHY THE **FIRST** FRAME ALWAYS FIRES
///
/// Because the thing it gates has to be drawn **once** whatever the budget
/// says. A gate that swallowed the first frame would leave the aurora black
/// until the second one.
final class AmbientTickGate {
  /// Creates a gate that fires every [everyNthFrame] frames.
  AmbientTickGate(this.everyNthFrame)
    : assert(everyNthFrame >= 1, 'a gate that never fires is a black screen');

  /// How many frames pass between two firings.
  final int everyNthFrame;

  /// How many frames since the last firing.
  int _count = 0;

  /// Whether this frame is due, and counts it.
  bool isDue() {
    final bool due = _count == 0;
    _count = (_count + 1) % everyNthFrame;
    return due;
  }
}
