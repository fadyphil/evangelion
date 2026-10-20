import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:flutter/widgets.dart' show AnimationController;

/// The time source for the LUMEN aurora.
///
/// ## WHY THIS EXISTS AT ALL, GIVEN THAT `Stopwatch` AND `DateTime` ARE BUILT IN
///
/// Because `u_time` decides what the 240 goldens record. A shader clock read
/// from `Stopwatch()` is a *different number on every run*, so every golden of
/// the aurora would have to be re-recorded after every unrelated change, and a
/// golden that has to be re-recorded is a golden nobody diffs. This is the one
/// seam in the port where "what time is it" becomes a parameter rather than a
/// fact, so a test can say `3.7 s` and get the same 1 280 000 bytes every time.
///
/// ## WHY IT EXTENDS `ChangeNotifier` RATHER THAN IMPLEMENTING `Listenable`,
/// ## AND WHY THAT SHAPE IS CHOSEN FOR WHAT IT MAKES IMPOSSIBLE
///
/// Both are "it could be otherwise", and this shape makes the unwrapped-time
/// decision **impossible to get wrong by accident**.
///
/// `AnimationController.value` is a `double` in `0..1` that a repeating
/// simulation sends back to `0` forever, and the obvious clock — `value *
/// periodSeconds` — is therefore a clock that **wraps**, which is precisely the
/// thing Task 1.4 measured and rejected. The alternative, a
/// `ValueNotifier<double>` fed by a ticker, is where that wrap would come back:
/// nothing about a `ValueNotifier` says "monotonic", and the accumulator it
/// holds would be a plain field a stop/resume could quietly reset.
///
/// The two implementations below are both monotonic by construction rather than
/// by discipline:
///
/// * [FixedLumenClock] has no accumulator at all — its time is a constructor
///   argument, so it cannot drift, wrap or resume.
/// * [TickedLumenClock] reads `AnimationController.lastElapsedDuration`, which
///   is the **ticker's** elapsed time since `start()` and is unaffected by the
///   simulation's period. A repeating controller does wrap its `value`; it does
///   not wrap this. Measured on the SDK rather than read off the docs —
///   `AnimationController._tick` assigns `elapsed` straight from the ticker and
///   `stop()`/`_startSimulation()` are the only writers.
///
/// ## WHY IT EXTENDS `ChangeNotifier` RATHER THAN IMPLEMENTING `Listenable`
///
/// A painter takes `CustomPainter.repaint`, which is a `Listenable`, and
/// `ListenableBuilder` takes one too. [FixedLumenClock] therefore has two
/// listeners it must answer (`addListener`/`removeListener`) that can never
/// fire, and implementing [Listenable] directly means writing those two methods
/// as no-ops with a comment explaining why a no-op is correct. `ChangeNotifier`
/// already answers both honestly: nothing ever notifies, because nothing ever
/// changes. `dispose()` on a fixed clock is a no-op too, which is the third
/// method this shape gets for free.
abstract class LumenClock extends ChangeNotifier {
  /// Creates a clock. Public so [TickedLumenClock] can be constructed; the
  /// subclass is what a caller should reach for.
  LumenClock();

  /// The elapsed seconds to hand the shader, as a `double`.
  ///
  /// **Unwrapped and monotonic** — see the class doc, and the `u_time` test in
  /// `lumen_canvas_test.dart`, which is what keeps that a fact rather than a
  /// paragraph.
  ///
  /// ## AND ZERO, WHEN THE READER HAS ASKED FOR REDUCED MOTION
  ///
  /// A clock that is *held at zero* reports **0**, whatever the elapsed time
  /// is. That is the one thing a `LumenClock` is allowed to do to its own
  /// monotonicity, and it is the whole of Phase 7's "a shader clock frozen at
  /// `t = 0`" (`plan:2392-2394`). See [TickedLumenClock.setReducedMotion] for
  /// why it is at zero and not at "wherever it had reached", and for the
  /// divergence it records against the prototype.
  double get seconds;

  /// A clock frozen at [seconds], for tests and goldens.
  ///
  /// A factory rather than a named constructor on the abstract class so that
  /// `LumenClock.fixed(3.7)` reads as "a lumen clock, fixed" at a call site
  /// typed as [LumenClock], which is the type a painter holds. Nothing about the
  /// painter's contract says a clock is ever live, so a test should not have to
  /// know which of the two it got.
  factory LumenClock.fixed(double seconds) = FixedLumenClock;
}

/// A [LumenClock] that never moves.
///
/// ## WHY IT IS NOT `const`, AND WHY THAT DOES NOT MATTER
///
/// `ChangeNotifier` has no const constructor — it allocates a listener list —
/// so neither does this. The one place const would have paid was a `static
/// const` golden fixture, and a golden's whole point is that its time is
/// *stated at the call site* where a reader can see it change. A shared frozen
/// clock would put `3.7` in one file and the reason for it in another.
///
/// ## WHY IT NOTIFIES NOBODY
///
/// Because a painter that repainted on a frozen clock would repaint on nothing,
/// and the goldens' determinism argument is "the same inputs produce the same
/// bytes" — which holds only if the clock contributes nothing between frames.
/// The inherited `notifyListeners` is simply never called.
final class FixedLumenClock extends LumenClock {
  /// Freezes the clock at [seconds].
  FixedLumenClock(this.seconds);

  /// The frozen time, returned unchanged for the life of the clock.
  @override
  final double seconds;

  @override
  String toString() => 'FixedLumenClock($seconds s)';
}

/// A [LumenClock] driven by a shared [AnimationController].
///
/// ## WHY A BORROWED CONTROLLER AND NOT ITS OWN
///
/// `NeuralMotionScope` already creates three `AnimationController`s on one
/// `TickerProviderStateMixin`, all with `AnimationBehavior.preserve`. A fourth
/// ticker mechanism — a `Timer.periodic`, a `Stream.periodic`, a persistent
/// frame callback — would be a second way for the app to burn frames, and §13's
/// collapse of sixty-four animations to three was about exactly that. So the
/// scope builds this from a controller it owns and disposes it in the same place
/// as the other three, and this class only reads it.
///
/// ## WHY `lastElapsedDuration` AND NOT `value * period`
///
/// Because `value` wraps. See the class doc on [LumenClock]: a repeating
/// controller's `value` returns to `0` at the end of every cycle, so
/// `value * periodSeconds` is a sawtooth, and `u_time` for the aurora must not
/// be one. `lastElapsedDuration` is the ticker's own elapsed time since `start()`
/// and is unaffected by the simulation's period.
///
/// ## WHY THE OFFSET, GIVEN `lastElapsedDuration` IS ALREADY MONOTONIC
///
/// Because `stop()` sets `lastElapsedDuration` to `null` and the next
/// `repeat()` sets it back to `Duration.zero` (`AnimationController._tick`,
/// `stop` and `_startSimulation`). So a clock that simply read it would jump
/// **back to zero** every time the reader asked for reduced motion and then
/// took it back — a visible rewinding of the aurora, and, for a
/// `LumenUniforms` value with `==` over all eighteen fields, a spurious change
/// every time. [rawElapsedSeconds] going *backwards* is the signal, and
/// [_offsetSeconds] is what makes the sum continuous across it.
///
/// The other three shared controllers have the same restart and nobody has
/// ever noticed, because their periods are 20 s, 12 s and 14 s and restarting
/// one lands on a plausible-looking phase. `u_time` is the one number that is
/// read by a golden, so it is the one that has to be right.
final class TickedLumenClock extends LumenClock {
  /// Reads [ticker]'s elapsed time, and listens to it for repaints.
  ///
  /// [ticker] is public because the holder has to be able to stop and start it —
  /// [EvaNeuralMotion.setAnimationsEnabled] does, for reduced motion — and a
  /// clock that could be neither stopped nor restarted would not be the clock
  /// the app runs on.
  TickedLumenClock({required this.ticker}) {
    ticker.addListener(_onTick);
  }

  /// The controller this clock reads. Owned by whoever created it;
  /// [NeuralMotionScope] creates it and disposes it.
  final AnimationController ticker;

  /// Seconds accumulated before the most recent restart of [ticker].
  double _offsetSeconds = 0;

  /// [ticker]'s own elapsed reading at the last observation.
  double _lastRawSeconds = 0;

  /// Whether the clock is **held at zero** because the reader asked for
  /// reduced motion.
  ///
  /// ## WHY A FLAG AND NOT A RESET
  ///
  /// Because the freeze is a *reporting* rule and not a destruction of
  /// history. The elapsed time is the clock's own; the reduced-motion
  /// decision is the reader's, and it decides what the **shader** is told,
  /// not how much time has passed. So the accumulator keeps its value and the
  /// reported `u_time` is pinned to zero — which is what makes "turn it off
  /// again" hand back the aurora the reader had, rather than a state the app
  /// has never been in.
  ///
  /// ## WHY ZERO AND NOT "WHEREVER IT HAD REACHED"
  ///
  /// Because a freeze at the value it had is a function of **how long the app
  /// has been running** and of **when the reader toggled the setting**. The
  /// same reader on the same screen would then see two different frames, and
  /// a golden recorded under reduced motion would be a function of when the
  /// suite ran. At zero it is a function of the setting and of nothing else —
  /// the still image every reader and every session sees, and the frame a
  /// reduced-motion golden can be recorded against.
  ///
  /// ## AND THE PROTOTYPE ANSWERS DIFFERENTLY, WHICH IS RECORDED
  ///
  /// `eva/redesign.html:888` is
  /// `timeAcc+=dt*(reduceMotion?0.15:1)` — the prototype **scales** its
  /// accumulator by `0.15` under reduced motion, so its `u_time` keeps
  /// *advancing*, slowly. The client **freezes** it. The plan records that as
  /// a divergence rather than a port (`plan:2004-2007`: "the client freezes
  /// the clock instead, which is a different answer to the same question").
  ///
  /// ## WHY IT IS NOT CALLED "FROZEN"
  ///
  /// Because [FixedLumenClock] is already "a clock frozen at [seconds]"
  /// (this file's own words), and one file cannot use one word for two
  /// opposites. This is a *held-at-zero* clock, and the reason it is held is
  /// the reader's request.
  bool _reducedMotion = false;

  /// Whether the clock is held at zero — the reduced-motion state.
  ///
  /// False for a clock that is simply running, and false for a
  /// [FixedLumenClock], which is a different thing entirely.
  bool get reducedMotion => _reducedMotion;

  /// Holds the clock's reported time at **zero**, or lets it run again.
  ///
  /// ## IT NOTIFIES, AND THE NOTIFICATION IS LOAD-BEARING
  ///
  /// The painter's repaint signal is the scene, and the scene's frame signal
  /// is this clock's notification (`lumen_scene.dart:439-449`). A hold that
  /// did not notify would leave the **last animated frame on the screen**:
  /// the aurora would keep the `u_time` it had when the reader asked for
  /// reduced motion, which is the exact thing the hold exists to stop. The
  /// notification is also what carries the held value into the scene's table,
  /// so the frame that is painted is the `t = 0` one.
  ///
  /// ## A HOLD THAT IS ALREADY IN FORCE IS A NO-OP
  ///
  /// So a caller may state the decision without asking whether it was
  /// already stated — which is what [EvaNeuralMotion.setAnimationsEnabled]
  /// does, since it is called on every change of the answer and on the
  /// scope's first build.
  void setReducedMotion({required bool reducedMotion}) {
    if (_reducedMotion == reducedMotion) return;
    _reducedMotion = reducedMotion;
    notifyListeners();
  }

  /// Folds a fresh [ticker] reading into the running total.
  ///
  /// A reading that went *backwards* since the last observation is a restart:
  /// `stop()` nulls `lastElapsedDuration` and the next `repeat()` resets it to
  /// `Duration.zero` (`AnimationController.stop`, `_startSimulation`). The whole
  /// of the previous reading is taken into the offset **before** it is
  /// overwritten, so no part of the elapsed time is lost.
  ///
  /// Called from two places — [_onTick] and [seconds] — because `stop()`
  /// notifies **neither** listeners nor this clock: it writes
  /// `_lastElapsedDuration` and stops the ticker without a tick, so a clock
  /// that only absorbed restarts on notification would read `0` for the whole
  /// stopped window instead of the frozen total. The check is idempotent — an
  /// absorbed restart leaves `_lastRawSeconds` at the new reading, so the
  /// second of the two call sites to observe it is a no-op — which is what
  /// makes observing from a getter safe rather than double-counting.
  void _noteRaw(double raw) {
    if (raw < _lastRawSeconds) {
      _offsetSeconds += _lastRawSeconds;
    }
    _lastRawSeconds = raw;
  }

  /// [_offsetSeconds] plus [ticker]'s current elapsed reading.
  ///
  /// **Monotonic.** The two components cannot both move in opposite
  /// directions: within one run of the ticker the raw reading only grows, and
  /// across a restart the raw reading collapses to zero while the offset
  /// absorbs the whole of it before that happens.
  ///
  /// Reads — and therefore may absorb — the ticker on every call, for the
  /// reason [_noteRaw] gives: between `stop()` and the next `repeat()` no tick
  /// fires, so only a read observes the backward jump. A pure getter would
  /// report the stopped window as `0` and rewind the aurora every time a
  /// reader asked for reduced motion.
  ///
  /// ## AND ZERO, WHEN THE CLOCK IS HELD
  ///
  /// The hold short-circuits **before** the accumulator is touched, and the
  /// order is load-bearing rather than tidy. A held read that went through
  /// [_noteRaw] would fold the ticker's own reading — which is `0` while the
  /// ticker is stopped — into [_lastRawSeconds] and lose the distinction
  /// between "the ticker was stopped" and "the clock was never running". The
  /// elapsed time is *preserved* while the clock is held: it stays in
  /// [_lastRawSeconds] until the ticker is restarted, and the restart is what
  /// folds it into [_offsetSeconds]. That is what makes the resume land on
  /// the phase the reader had rather than on a fresh one.
  @override
  double get seconds {
    if (_reducedMotion) return 0;
    final double raw = rawElapsedSeconds;
    _noteRaw(raw);
    return _offsetSeconds + raw;
  }

  /// [ticker]'s own elapsed reading in seconds, or `0` while it is stopped.
  ///
  /// Public because the restart arithmetic is the only interesting thing this
  /// class does, and a test that can only observe the *sum* cannot tell a clock
  /// that resumed from zero from one that resumed correctly.
  double get rawElapsedSeconds {
    final Duration? elapsed = ticker.lastElapsedDuration;
    if (elapsed == null) return 0;
    return elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _onTick() {
    _noteRaw(rawElapsedSeconds);
    notifyListeners();
  }

  @override
  void dispose() {
    // The subscription first, for the reason `EvaNeuralMotion.dispose` gives:
    // disposing a controller clears its listeners, and clearing this one first
    // stops a notification reaching a half-disposed notifier.
    ticker.removeListener(_onTick);
    super.dispose();
  }

  @override
  String toString() =>
      'TickedLumenClock(seconds: $seconds, raw: '
      '${rawElapsedSeconds}s, offset: ${_offsetSeconds}s, '
      'reducedMotion: $_reducedMotion)';
}
