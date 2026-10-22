import 'package:evangelion/core/diagnostics/frame_stats.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Collects the engine's per-frame timings and summarises them.
///
/// ## WHAT THIS IS FOR
///
/// `docs/PERFORMANCE.md` §3.4 names the on-device instrument that does not
/// exist yet:
///
/// > "The on-device measurement, which does not exist yet … the instrument is
/// > `SchedulerBinding.instance.addTimingsCallback`, which reports
/// > `buildDuration`, `rasterDuration` and `totalSpan` per frame and works in
/// > release and profile … **It is not built yet.**"
///
/// This is it. The engine hands out a **batch** of `FrameTiming`s — and
/// **how often** is a measured fact, not a recollection: the framework's own
/// `SchedulerBinding.addTimingsCallback` doc says the data is "reported
/// approximately once a second in release mode and approximately once every
/// 100ms in debug and profile builds", and a profile-mode run on this machine
/// **measured 86 batches in ten seconds** (about one every 116 ms, carrying
/// about seven frames each at 60 Hz). This recorder turns each batch into two
/// series of plain microseconds and summarises them.
///
/// ## WHY IT IS **OPT-IN** AND WHY THE FLAG IS A **COMPILE-TIME CONSTANT**
///
/// A frame-timing channel is not free: the engine keeps the timing data
/// alive and hands it over, and a reader who never asked for it should not
/// pay for it. So the instrument is behind
/// [kPerfTraceEnabled] — `bool.fromEnvironment('PERF_TRACE')` — which is a
/// **compile-time constant**. In a build without `--dart-define=PERF_TRACE=true`
/// the flag is `false`, the branch that constructs the recorder is folded away
/// by the compiler, and **the instrument costs nothing at all**.
///
/// `enabled` is a **constructor parameter** rather than a read of the constant
/// inside the class, so that a test can exercise **both** arms: a recorder
/// that collects and a recorder that does not. A single-arm instrument is a
/// half-tested instrument.
///
/// ## WHY THE ARITHMETIC IS IN A **DIFFERENT FILE**
///
/// `frame_stats.dart` is **pure Dart**. `FrameTiming` is a `dart:ui` type, so
/// anything that speaks in it is a Flutter file, and a statistics type that
/// can only be built by the engine has nothing a unit test can hand it. The
/// split is what makes the percentile arithmetic testable at all.
///
/// ## WHAT IT DOES **NOT** MEASURE
///
/// * **Not the GPU's cost of the aurora.** `rasterDuration` is the time the
///   raster thread spent turning a layer tree into pixels; on a desktop it is
///   a software or GL rasteriser, and on a phone it is a different pipeline
///   again. A desktop number is **directional**, never a device budget.
/// * **Not the total latency a reader perceives.** That is `totalSpan`,
///   which this recorder does not collect — a deliberate omission, because
///   `totalSpan` is dominated by the **vsync wait**, and a number that
///   includes a wait is a number about the display's refresh rate as much as
///   about the app.
/// * **Not anything at all in a normal build.** See the flag above.
final class FrameTimingRecorder {
  /// Creates a recorder.
  ///
  /// **[enabled] defaults to [kPerfTraceEnabled]** — the compile-time flag —
  /// so a build that did not ask for the instrument does not have one.
  ///
  /// **The parameter is `bool?` and the field is `bool`, and that is not an
  /// accident.** A non-nullable parameter defaulting to a constant would make
  /// `enabled: false` **redundant** to `avoid_redundant_argument_values` —
  /// the analyzer compares the argument against the default's *value*, and the
  /// default's value is `false` in every build that did not set the flag. So
  /// the one arm a test must be able to force — the **off** arm — would be the
  /// one arm the analyzer refuses to let a test write. The nullable parameter
  /// and the `??` below are what keep both arms writable, and the field is
  /// still a plain non-nullable `bool`.
  ///
  /// [log] is where the summary is written. It is a parameter so that a test
  /// can capture the summary instead of printing it, and so that the console
  /// is not the only place a report can go.
  FrameTimingRecorder({bool? enabled, this.log = _writeToConsole})
    : enabled = enabled ?? kPerfTraceEnabled;

  /// Whether this build collects frame timings.
  ///
  /// **A compile-time constant**, so the branch that uses it is folded away
  /// in a build that did not set it. The build flag is:
  ///
  /// ```sh
  /// flutter run -d linux --profile --dart-define=PERF_TRACE=true
  /// ```
  static const bool kPerfTraceEnabled = bool.fromEnvironment('PERF_TRACE');

  /// Whether this recorder collects anything.
  ///
  /// **Never null**, whatever the parameter was: `null` means "this build's
  /// flag", which resolves to a `bool` before the constructor returns.
  final bool enabled;

  /// Where the summary is written.
  final void Function(String message) log;

  /// The build-thread durations, in microseconds.
  final List<int> _buildMicros = <int>[];

  /// The raster-thread durations, in microseconds.
  final List<int> _rasterMicros = <int>[];

  /// Whether this recorder is on the engine's channel.
  bool _attached = false;

  /// Whether this recorder is on the engine's channel.
  bool get attached => _attached;

  /// The statistics over the build-thread samples.
  ///
  /// **Copied and sorted on every read**, which is wasteful and correct: the
  /// sort is what makes the percentiles right, and the copy is what stops a
  /// caller from mutating the samples underneath the statistics. The cost is
  /// paid **about nine times a second** in profile mode, on a list of a few
  /// thousand integers.
  FrameStats get buildStats =>
      FrameStats(label: 'build', samples: _buildMicros);

  /// The statistics over the raster-thread samples.
  FrameStats get rasterStats =>
      FrameStats(label: 'raster', samples: _rasterMicros);

  /// The one-line summary of both series.
  String get summary => '${buildStats.describe()} | ${rasterStats.describe()}';

  /// Records one frame's two durations, in microseconds.
  ///
  /// **The public sink**, so that anything holding this recorder can feed it a
  /// frame without knowing about the engine. A disabled recorder **ignores**
  /// the frame: that is the whole of what "off" means.
  void addFrame({required int buildMicros, required int rasterMicros}) {
    if (!enabled) return;
    _buildMicros.add(buildMicros);
    _rasterMicros.add(rasterMicros);
  }

  /// Takes a batch of engine timings, records them, and writes the summary.
  ///
  /// **This is the callback the engine is given**, and the summary is written
  /// here rather than on a timer because the engine's own batching already is
  /// the clock. **Measured on this machine, 2026-10-22, profile mode: 86
  /// batches in ten seconds**, so the summary is a **rolling total printed
  /// about nine times a second** in profile mode and about once a second in
  /// release mode. Every line is the whole session up to that point, so the
  /// **last line of a session is the session's own summary**.
  void onTimings(List<FrameTiming> timings) {
    if (!enabled) return;
    for (final FrameTiming timing in timings) {
      addFrame(
        buildMicros: timing.buildDuration.inMicroseconds,
        rasterMicros: timing.rasterDuration.inMicroseconds,
      );
    }
    report();
  }

  /// Registers this recorder on the engine's timings channel.
  ///
  /// **Idempotent**, and it has to be: `SchedulerBinding.addTimingsCallback`
  /// executes a callback that is registered twice, and a doubled sample count
  /// would make every percentile in the report a lie about the app.
  ///
  /// A disabled recorder does not register at all, so the engine's channel
  /// stays empty in a build that did not ask for the instrument.
  void attach() {
    if (!enabled || _attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(onTimings);
  }

  /// Writes the current summary to [log].
  void report() {
    log(summary);
  }

  /// The default log: the console, through `debugPrint`.
  ///
  /// **`debugPrint` and not `print`** — `print` is banned in this repository
  /// (`avoid_print`), and `debugPrint` is **throttled**, which matters here
  /// because the summary is written about nine times a second in profile mode.
  static void _writeToConsole(String message) {
    debugPrint(message);
  }
}
