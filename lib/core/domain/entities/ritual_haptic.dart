/// The haptics the redesign's ritual asks for, and the Flutter impact each one
/// becomes.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// `HapticFeedback` and no `package:flutter`. The Flutter side is
/// `core/design_system/haptics.dart`, which is the only place that calls the
/// platform.
library;

/// A haptic the prototype asks for.
///
/// The members are named by **intent**, not by duration, because two different
/// moments can ask for the same vibration and a call site should read as the
/// moment rather than as a number.
enum RitualHaptic {
  /// `haptic(10)` — `eva/redesign.html:1275`, the dock's tab.
  dockTap,

  /// `haptic(10)` — `eva/redesign.html:1396`, the `Aa` buttons.
  fontStep,

  /// `haptic(12)` — `eva/redesign.html:1394`, the bookmark.
  bookmark,

  /// `haptic(12)` — `eva/redesign.html:1388`, opening a verse.
  verseSelected,

  /// `haptic(15)` — `eva/redesign.html:1411`, opening the quiz.
  quizOpened,

  /// `haptic(15)` — `eva/redesign.html:1482`, the daylight switch.
  daylightToggled,

  /// `haptic(15)` — `eva/redesign.html:1498`, the haptics switch itself.
  hapticsEnabled,

  /// `haptic(20)` — `eva/redesign.html:1320`, the streak chip.
  streakOpened,

  /// `haptic(20)` — `eva/redesign.html:1338`, beginning the selah.
  selahStarted,

  /// `haptic(30)` — `eva/redesign.html:1428`, a correct answer.
  answerCorrect,

  /// `haptic([30,40,30])` — `eva/redesign.html:1330`, the selah's end.
  selahCompleted,

  /// `haptic([40,60,40])` — `eva/redesign.html:1429`, a wrong answer.
  answerWrong,

  /// `haptic([30,40,30])` — `eva/redesign.html:1445`, the results.
  resultsShown,
}

/// The Flutter impact a haptic becomes.
///
/// `package:flutter/services.dart`'s `HapticFeedback` offers exactly four
/// named impulses, and this enum is the mapping's target: it is what the
/// design system's haptics helper switches on.
enum HapticImpact {
  /// `HapticFeedback.selectionClick()` — a tick.
  selection,

  /// `HapticFeedback.lightImpact()` — a soft bump.
  light,

  /// `HapticFeedback.mediumImpact()` — a firmer bump.
  medium,

  /// `HapticFeedback.heavyImpact()` — a long buzz.
  heavy,
}

/// The prototype's own pattern for [haptic], in milliseconds.
///
/// **`navigator.vibrate` takes a duration or a list of durations**, and the
/// prototype uses both: a single number for most moments and a three-part
/// rhythm for the two that are *events* rather than *acknowledgements*.
List<int> hapticPatternFor(RitualHaptic haptic) => switch (haptic) {
  RitualHaptic.dockTap => const <int>[10],
  RitualHaptic.fontStep => const <int>[10],
  RitualHaptic.bookmark => const <int>[12],
  RitualHaptic.verseSelected => const <int>[12],
  RitualHaptic.quizOpened => const <int>[15],
  RitualHaptic.daylightToggled => const <int>[15],
  RitualHaptic.hapticsEnabled => const <int>[15],
  RitualHaptic.streakOpened => const <int>[20],
  RitualHaptic.selahStarted => const <int>[20],
  RitualHaptic.answerCorrect => const <int>[30],
  RitualHaptic.selahCompleted => const <int>[30, 40, 30],
  RitualHaptic.answerWrong => const <int>[40, 60, 40],
  RitualHaptic.resultsShown => const <int>[30, 40, 30],
};

/// The Flutter impact [haptic] becomes.
///
/// ## WHY THE MAPPING IS BY **MAGNITUDE** AND NOT BY CALL SITE
///
/// The prototype's `haptic(p)` is `navigator.vibrate(p)` (`eva/redesign.html:
/// 914`) — a **duration** in milliseconds, or a list of durations. Flutter's
/// `HapticFeedback` has no duration argument at all: it offers four *named*
/// impulses whose lengths are the platform's business
/// (`selectionClick`, `lightImpact`, `mediumImpact`, `heavyImpact`).
///
/// So a duration has to become a name, and the only defensible rule is
/// **magnitude**: the prototype's 10 ms and 12 ms are clicks, its 15–25 ms are
/// bumps, its 30 ms is a firm bump, and its 40 ms and 60 ms are buzzes. A
/// per-call-site table would be a second table of the same thirteen moments,
/// and the two would drift.
///
/// ## AND A PATTERN BECOMES ITS **STRONGEST** ELEMENT
///
/// `HapticFeedback` cannot express a rhythm — there is no pattern API, and
/// `HapticFeedback.vibrate()` asks the platform for its *default* vibration
/// rather than a list. The prototype's two rhythms are `[30,40,30]`
/// (`:1330`, `:1445`) and `[40,60,40]` (`:1307`, `:1429`), and both peak above
/// the 30 ms that maps to a medium impact, so both become a heavy impact.
///
/// **This is a loss and it is recorded as one:** the three-part rhythm — two
/// buzzes with a pause — becomes one buzz. The *strength* survives; the
/// *rhythm* does not, because the platform API this client may use
/// (`package:flutter/services.dart`, §8.4 forbids a dependency) cannot carry
/// it.
HapticImpact hapticImpactFor(RitualHaptic haptic) {
  final List<int> pattern = hapticPatternFor(haptic);
  int peak = 0;
  for (final int milliseconds in pattern) {
    if (milliseconds > peak) peak = milliseconds;
  }
  return switch (peak) {
    <= 12 => HapticImpact.selection,
    <= 25 => HapticImpact.light,
    <= 35 => HapticImpact.medium,
    _ => HapticImpact.heavy,
  };
}
