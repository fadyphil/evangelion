import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_test/flutter_test.dart';

/// The number of tickers that are **alive and scheduling frames**, right now.
///
/// ## WHY THIS NUMBER, AND NOT `AnimationController.isAnimating`
///
/// `SchedulerBinding.transientCallbackCount` is the framework's own tally of
/// the transient callbacks registered for the next frame, and **a running
/// `Ticker` registers exactly one of them for itself**. So the count is the
/// number of animations that are actually waking the scheduler up.
///
/// It is a **stronger** witness than `isAnimating`, for two reasons the
/// repository has already leaned on (`neural_motion_test.dart:51-63`,
/// `gold_flecks_test.dart:234-268`, `witness_sky_test.dart:708-714`):
///
/// * `isAnimating` answers for **one** controller. A leaked third ticker has
///   no controller anybody can ask, and a controller that was told to stop can
///   still have a scheduled callback.
/// * `isAnimating` is `_ticker.isActive`, and **`isActive` is true even for a
///   MUTED ticker** (`ticker.dart:141-150`, and `animation_controller.dart:
///   438-450` says so in words). A muted ticker is one a disabled
///   `TickerMode` has silenced, and it is precisely the thing a gate about
///   "is this animation still burning frames" must be able to see.
///
/// **That last point is the whole reason this instrument exists.** The
/// framework's own answer to "stop animating a subtree you cannot see" is
/// `TickerMode(enabled: false)`, and a muted ticker is **not** counted here —
/// because `Ticker.shouldScheduleTick` is `!muted && isActive && !scheduled`
/// (`ticker.dart:270`) and a muted ticker's callback is unscheduled
/// (`ticker.dart:145-147`). So a tree that is correctly muted reads **zero**
/// here, and a tree that is merely *hidden* reads **one**.
///
/// ## WHY THE COUNT IS A LEVEL AND NOT A RATE
///
/// Because the question is "how many animations are alive", and a rate would
/// answer a different question. The frames half of [TickerCensus] is the rate.
int get liveTickerCount => SchedulerBinding.instance.transientCallbackCount;

/// What the framework was doing, over a fixed window of pumped frames.
///
/// ## THE TWO HALVES, AND WHY THEY ARE NOT THE SAME NUMBER
///
/// * [liveTickers] is a **level**: how many animations are alive at the end of
///   the window.
/// * [framesScheduled] is a **count**: how many frames the scheduler actually
///   produced while the window was pumped.
///
/// A level of zero implies a count of zero — nothing alive means nothing
/// scheduling — but the reverse is not true, and the two are kept because they
/// fail differently. A tree with **no** live tickers but a frame still
/// requested (a one-shot `setState`, a `scheduleWarmUpFrame`) produces a
/// frame or two and then goes quiet; a tree with a live ticker produces a
/// frame on **every** pump, forever. A gate that wants "nothing is
/// scheduling frames while this tab is idle" wants the **count**, and a gate
/// that wants "this screen animates" wants the **level**.
///
/// ## WHY A COUNT OF FRAMES AND NOT A COUNT OF `pump()` CALLS
///
/// Because `tester.pump()` produces a frame **only if one was requested**
/// (`flutter_test/lib/src/binding.dart:2257` — `if (hasScheduledFrame)`). A
/// `pump()` on an idle tree is a no-op that advances the clock and returns.
/// So the number of `pump()` calls is a number the *test* chose, and the
/// number of frames is a number the *tree* chose — and the second is the one
/// that answers "is anything animating".
final class TickerCensus {
  /// A census of one window.
  const TickerCensus({
    required this.liveTickers,
    required this.framesScheduled,
  });

  /// How many tickers were alive and scheduling frames at the end of the
  /// window.
  ///
  /// **Sampled at the END of the window**, and that is the right place to
  /// sample it: a ticker that is alive is alive for the whole window, and one
  /// that is not is not alive for any of it, so the level is constant across
  /// the window for every tree that is not changing its mind.
  ///
  /// See [liveTickerCount] for what this counts and what it deliberately does
  /// not count.
  final int liveTickers;

  /// How many frames the scheduler actually produced while the window was
  /// pumped.
  final int framesScheduled;

  /// The census as one readable line, for a failure message.
  String describe() =>
      '$liveTickers live ticker(s), $framesScheduled frame(s) scheduled';
}

/// Runs [frames] fixed pumps of [step] and reports what the scheduler did.
///
/// ## WHY **NOT** `pumpAndSettle` — AND WHY THE TIMEOUT **IS** THE SYMPTOM
///
/// `pumpAndSettle` pumps until the scheduler has nothing left to do, and it
/// **times out against a repeating ticker** — the ticker always has another
/// frame queued, so "settled" never arrives. That timeout is not an
/// inconvenience to work around here; **it is the defect this instrument
/// exists to measure**. A tab that is off screen and still breathing its ring
/// makes `pumpAndSettle` hang, and a test that reaches for `pumpAndSettle`
/// to find out why is about to learn the same thing this census reports in
/// numbers.
///
/// So the window is **explicit**: a fixed number of pumps, each of a fixed
/// duration. The result is a number rather than a hang, and the number is
/// comparable between two runs of the same window.
///
/// ## HOW THE FRAME COUNT IS TAKEN, AND WHY IT DOES NOT FEED THE SCHEDULER
///
/// A **post-frame callback that re-registers itself**. `addPostFrameCallback`
/// only appends to a list — it does **not** call `scheduleFrame`
/// (`scheduler/binding.dart:818-836`) — so the counter cannot make the
/// scheduler produce a frame the tree did not ask for. Each frame the
/// scheduler produces flushes the list, the callback fires once, and it puts
/// itself back for the next frame.
///
/// The re-registration lands in the *next* frame's list rather than the
/// current one, because the scheduler clears the list before invoking it
/// (`scheduler/binding.dart:1350-1351`), so the count is exactly one per
/// frame and never two.
///
/// ## WHAT A ZERO MEANS
///
/// **Zero frames over the window means nothing in the tree asked for a
/// frame.** It is the strongest form of the claim: not "few frames", not
/// "fewer than before" — *none*. A test that wants "this tab is idle" wants
/// this number, and it is the reason the window is pumped explicitly rather
/// than settled.
Future<TickerCensus> censusFrames(
  WidgetTester tester, {

  /// How many frames to pump.
  ///
  /// **Required, and not defaulted**, because the window is part of the
  /// measurement: "60 frames" and "600 frames" are different claims, and a
  /// caller that has not stated which one it is measuring has not measured
  /// anything. Sixty 16ms steps is one second of wall clock, and it is the
  /// window this repository's gate uses.
  required int frames,

  /// How much clock each pump advances.
  ///
  /// Required for the same reason as [frames]: the window is a number of
  /// steps **and** a step size, and both of them belong in the report.
  required Duration step,
}) async {
  int produced = 0;

  void countFrame(Duration _) {
    produced++;
    SchedulerBinding.instance.addPostFrameCallback(countFrame);
  }

  // Registered before the first pump, so the first frame the window produces
  // is counted. It does not schedule a frame of its own.
  SchedulerBinding.instance.addPostFrameCallback(countFrame);

  for (int frame = 0; frame < frames; frame++) {
    await tester.pump(step);
  }

  return TickerCensus(liveTickers: liveTickerCount, framesScheduled: produced);
}
