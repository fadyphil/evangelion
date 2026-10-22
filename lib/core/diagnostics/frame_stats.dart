/// The statistics of **one series** of frame durations, in microseconds.
///
/// ## WHY THIS FILE IS **PURE DART**
///
/// It is the half of the frame-timing instrument that can be *tested*.
///
/// The engine's own type, `dart:ui`'s `FrameTiming`, is a `dart:ui` type, so
/// anything that speaks in it is a Flutter file — and a statistics type that
/// can only be built by the engine has nothing a unit test can hand it. This
/// file therefore takes **plain `int` microseconds**, which any test can
/// write, and the Flutter-facing half (`frame_timing_recorder.dart`) is the
/// adapter that converts the engine's numbers into these.
///
/// **This is also why the brief's premise needed checking.** `FrameTiming`
/// *does* have a public factory constructor in Flutter 3.47.4
/// (`sky_engine/lib/ui/platform_dispatcher.dart:2172`, documented as "used for
/// unit test only"), so the adapter **is** reachable from a test — but only
/// because that constructor exists, and the statistics do not depend on it
/// either way.
///
/// ## WHY A **SERIES** AND NOT A WHOLE REPORT
///
/// A report is two series — the build thread's time and the raster thread's —
/// and they answer different questions. `buildDuration` is the UI thread
/// deciding what the frame looks like; `rasterDuration` is the raster thread
/// turning that into pixels. A frame that misses its budget can miss it on
/// either side, and a single blended number cannot say which.
///
/// So this type is **one labelled series**, and the recorder holds two of them.
/// Blending them would also make the number mean less: the two are measured
/// on different threads, and their sum is not a duration anything experienced.
///
/// ## WHY THE PERCENTILES ARE **NEAREST-RANK**
///
/// A percentile has more than one definition and the choice is not cosmetic.
/// "The 95th percentile" of twenty samples is the 19th under nearest-rank and
/// something between the 19th and the 20th under interpolation.
///
/// **Nearest-rank is the one that answers the question a frame budget asks** —
/// *"how long did the slowest five percent of frames take"* — because it always
/// returns a sample that was actually measured. An interpolated percentile
/// returns a number no frame ever produced, and a budget read off it is a
/// budget read off a fiction.
///
/// ## AND THE FRAMEWORK'S OWN SUMMARISER USES A **DIFFERENT** RULE
///
/// `package:flutter_test`'s `FrameTimingSummarizer` takes the sample at
/// `data[((data.length - 1) * p).round()]` — a rounded linear index, which
/// is neither nearest-rank nor interpolation. For twenty samples the two
/// rules agree; for **twelve** they do not: nearest-rank puts the 95th
/// percentile at the twelfth sample and the rounded index puts it at the
/// eleventh.
///
/// **This is recorded rather than matched, because a reader who compares a
/// number from here with a number from `flutter_test` must be able to find
/// the difference.** The rule here is the one that returns a measured sample.
final class FrameStats {
  /// The statistics over [samples], labelled [label].
  ///
  /// The samples are **copied and sorted**, so the caller's list is not
  /// aliased and cannot be changed underneath the statistics, and so the order
  /// the frames arrived in is irrelevant to every number below.
  factory FrameStats({required String label, required Iterable<int> samples}) =>
      FrameStats._(label, List<int>.of(samples)..sort());

  const FrameStats._(this.label, this._sorted);

  /// What this series measures — `build` or `raster`.
  ///
  /// **Part of the value, not decoration.** A summary line that does not say
  /// what it measures is a line nobody can read six minutes later, and the two
  /// series in a report differ by an order of magnitude on a shader-heavy
  /// screen.
  final String label;

  /// The samples, ascending. Never handed out — the statistics are the API.
  final List<int> _sorted;

  /// How many samples the series holds.
  int get count => _sorted.length;

  /// The median — the 50th percentile, nearest-rank.
  int get p50 => _percentile(50);

  /// The 95th percentile, nearest-rank.
  ///
  /// **The number a frame budget is read off.** The median hides the tail, and
  /// the tail is what a reader notices: a screen that is smooth on average and
  /// stutters once a second is a screen whose 95th percentile is over budget.
  int get p95 => _percentile(95);

  /// The slowest sample.
  int get worst => _sorted.isEmpty ? 0 : _sorted.last;

  /// The arithmetic mean.
  ///
  /// **A `double`, because a mean of integers is usually not one.** Rounding it
  /// to a whole microsecond would be a rounding of a number that is already
  /// a rounding.
  double get mean {
    if (_sorted.isEmpty) return 0;
    int total = 0;
    for (final int sample in _sorted) {
      total += sample;
    }
    return total / _sorted.length;
  }

  /// A one-line, stable summary of the series.
  ///
  /// **Stable** means the same samples always produce the same string, so a
  /// line can be compared with a line from another run, another machine or
  /// another build. **One line** because a summary that wraps is a summary
  /// that a `grep` cannot find.
  ///
  /// The unit is **milliseconds with one decimal**, because the number a
  /// reader compares against is a frame budget — 16.7 ms at 60 Hz, 8.3 ms at
  /// 120 Hz — and microseconds would make them count digits.
  String describe() =>
      '$label count=$count p50=${_millis(p50)} p95=${_millis(p95)} '
      'worst=${_millis(worst)} mean=${_millis(mean)}';

  /// The [percentile]-th percentile, nearest-rank.
  ///
  /// The rank is `ceil(percentile × n / 100)`, so the result is the
  /// `rank`-th smallest sample. **[percentile] must be in `1…100`**, and the
  /// two this class uses are 50 and 95.
  ///
  /// An empty series has no percentile, and **zero** is the answer rather than
  /// an exception: a recorder that has seen no frames is a normal state, not
  /// an error.
  int _percentile(int percentile) {
    if (_sorted.isEmpty) return 0;
    final int rank = (percentile * _sorted.length / 100).ceil();
    return _sorted[rank - 1];
  }

  /// A duration in microseconds, rendered as milliseconds with one decimal.
  static String _millis(num micros) =>
      '${(micros / 1000).toStringAsFixed(1)}ms';
}
