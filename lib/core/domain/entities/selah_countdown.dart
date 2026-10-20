/// The selah's countdown — the prototype's own arithmetic.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// `Timer` and no `package:flutter`. The **timer** is the widget's; the
/// **counting** is this file's, and AGENT_CONTEXT §6 asks for exactly that
/// split.
library;

/// How long the selah lasts, in seconds, when the reader has chosen nothing.
///
/// `eva/redesign.html:1324` — `let selahDur=60, selahTimer=null;`.
const int kSelahDefaultSeconds = 60;

/// The selah's countdown.
///
/// ## WHY IT IS A VALUE AND NOT A TIMER
///
/// `eva/redesign.html:1335-1340` is the whole of the prototype's timer:
///
/// ```js
/// let left=selahDur;
/// el('selahCard').classList.add('active');
/// el('selahCount').style.display='inline'; el('selahCount').textContent=N(left);
/// focusDim=true; haptic(20);
/// selahTimer=setInterval(()=>{ left--; el('selahCount').textContent=N(left);
///   if(left<=0) selahStop(true); },1000);
/// ```
///
/// The **arithmetic** is a number that goes down by one a second and stops at
/// zero. That is this class. The **clock** is `setInterval`, which is a widget's
/// business — and a widget that computed the remaining seconds itself would be
/// untested logic wearing a `build` method, which is the failure AGENT_CONTEXT
/// §6 names.
///
/// ## THE COUNT IS SHOWN **BEFORE** THE FIRST TICK
///
/// The prototype paints `N(left)` — the full duration — the instant the button
/// is pressed, and only then starts decrementing. So a 60-second selah shows
/// `60` for one second and `0` at the end, and the total silence is 60 ticks
/// and not 61. [start] reproduces that, and [tick] is the one decrement.
final class SelahCountdown {
  /// A countdown of [total] seconds with [remaining] left.
  const SelahCountdown({required this.total, required this.remaining});

  /// A fresh countdown of [totalSeconds].
  ///
  /// Throws [ArgumentError] on a non-positive total: a selah of no seconds is
  /// not a state the reader can reach — the Workshop's range is 15…120
  /// (`eva/redesign.html:684`) — and a countdown that finished before it began
  /// would complete on the first tick and toast an amen nobody waited for.
  factory SelahCountdown.start(int totalSeconds) {
    if (totalSeconds <= 0) {
      throw ArgumentError.value(
        totalSeconds,
        'totalSeconds',
        'a selah lasts at least one second',
      );
    }
    return SelahCountdown(total: totalSeconds, remaining: totalSeconds);
  }

  /// How long the selah lasts, in seconds.
  final int total;

  /// How many seconds are left.
  final int remaining;

  /// Whether the silence is over.
  bool get isComplete => remaining <= 0;

  /// Whether the silence is still running.
  bool get isRunning => remaining > 0;

  /// One second later.
  ///
  /// The prototype decrements **first** and paints the new value, so the count
  /// a reader sees is always the one after the tick — which is what [remaining]
  /// is here.
  SelahCountdown tick() => SelahCountdown(
    total: total,
    remaining: remaining > 0 ? remaining - 1 : 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelahCountdown &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          remaining == other.remaining;

  @override
  int get hashCode => Object.hash(total, remaining);

  @override
  String toString() => 'SelahCountdown(total: $total, remaining: $remaining)';
}
