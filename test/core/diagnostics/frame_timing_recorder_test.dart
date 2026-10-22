import 'dart:ui' show PlatformDispatcher;

import 'package:evangelion/core/diagnostics/frame_timing_recorder.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Flutter-facing half of the frame-timing instrument.
///
/// `docs/PERFORMANCE.md` §3.4 names the instrument that does not exist yet:
/// `SchedulerBinding.instance.addTimingsCallback`, which reports
/// `buildDuration`, `rasterDuration` and `totalSpan` per frame. This is it.
///
/// ## WHAT IS BEING TESTED, AND WHY THE ENGINE PATH IS REACHABLE AT ALL
///
/// The engine's own type is `dart:ui`'s `FrameTiming`, and the engine hands it
/// out in **batches** — roughly once a second in profile mode, once every
/// 100 ms in debug. So there are two things to get right, and they are
/// different things:
///
/// * the **conversion** — the engine's `Duration`s into the two plain
///   microsecond series the statistics read; and
/// * the **registration** — the recorder's callback actually being on the
///   engine's channel.
///
/// The second one is not testable by calling a method, so it is tested by
/// **driving the engine's own channel**: `PlatformDispatcher.instance
/// .onReportTimings` is what `SchedulerBinding.addTimingsCallback` installs,
/// and calling it is exactly what the engine does when it has a batch to
/// deliver. A test that called the recorder's method directly would prove the
/// conversion and say nothing about the wiring.
///
/// **The engine's `FrameTiming` does have a public constructor** in Flutter
/// 3.47.4 — `sky_engine/lib/ui/platform_dispatcher.dart:2172`, documented as
/// "used for unit test only" — which is what makes this possible.
void main() {
  /// A frame the engine could have produced: [buildMicros] of UI-thread time
  /// and [rasterMicros] of raster-thread time.
  FrameTiming aFrame({int buildMicros = 8000, int rasterMicros = 3000}) {
    return FrameTiming(
      vsyncStart: 0,
      buildStart: 0,
      buildFinish: buildMicros,
      rasterStart: buildMicros,
      rasterFinish: buildMicros + rasterMicros,
      rasterFinishWallTime: buildMicros + rasterMicros,
    );
  }

  group('the compile-time flag', () {
    test('is off in a build that did not ask for it', () {
      // This suite is run without `--dart-define=PERF_TRACE`, so the flag is
      // `false` — which is the whole point of a compile-time flag: a normal
      // build does not pay for the instrument.
      expect(FrameTimingRecorder.kPerfTraceEnabled, isFalse);
    });

    test('and the recorder follows it by default', () {
      expect(
        FrameTimingRecorder().enabled,
        FrameTimingRecorder.kPerfTraceEnabled,
      );
    });
  });

  group('a disabled recorder', () {
    test('collects nothing at all', () {
      final FrameTimingRecorder recorder = FrameTimingRecorder(enabled: false);

      recorder.addFrame(buildMicros: 8000, rasterMicros: 3000);

      expect(recorder.buildStats.count, 0);
      expect(recorder.rasterStats.count, 0);
    });

    test('and the engine timings change nothing', () {
      final FrameTimingRecorder recorder = FrameTimingRecorder(enabled: false);

      recorder.onTimings(<FrameTiming>[aFrame()]);

      expect(recorder.buildStats.count, 0);
    });

    testWidgets('and it never attaches to the engine', (
      WidgetTester tester,
    ) async {
      final FrameTimingRecorder recorder = FrameTimingRecorder(enabled: false);

      recorder.attach();

      expect(recorder.attached, isFalse);
    });
  });

  group('an enabled recorder', () {
    test('collects the two series separately', () {
      final FrameTimingRecorder recorder = FrameTimingRecorder(enabled: true);

      recorder.addFrame(buildMicros: 8000, rasterMicros: 3000);

      expect(recorder.buildStats.count, 1);
      expect(recorder.buildStats.p50, 8000);
      expect(recorder.rasterStats.count, 1);
      expect(recorder.rasterStats.p50, 3000);
    });

    test('and reads the engine timings into them', () {
      // **The default log**, deliberately: this is the one test that leaves
      // the summary on the console, so the `debugPrint` path is exercised
      // rather than left unreached. It prints one line.
      final FrameTimingRecorder recorder = FrameTimingRecorder(enabled: true);

      recorder.onTimings(<FrameTiming>[aFrame(buildMicros: 9000)]);

      expect(recorder.buildStats.p50, 9000);
      expect(recorder.rasterStats.p50, 3000);
    });

    test('and the summary says what both series are', () {
      final FrameTimingRecorder recorder = FrameTimingRecorder(enabled: true);
      recorder.addFrame(buildMicros: 8000, rasterMicros: 3000);

      expect(
        recorder.summary,
        'build count=1 p50=8.0ms p95=8.0ms worst=8.0ms mean=8.0ms | '
        'raster count=1 p50=3.0ms p95=3.0ms worst=3.0ms mean=3.0ms',
      );
    });

    test('and it writes the summary to the log it was given', () {
      final List<String> written = <String>[];
      final FrameTimingRecorder recorder = FrameTimingRecorder(
        enabled: true,
        log: written.add,
      );
      recorder.addFrame(buildMicros: 8000, rasterMicros: 3000);

      recorder.report();

      expect(written, hasLength(1));
      expect(written.single, recorder.summary);
    });

    testWidgets('and the engine channel reaches it', (
      WidgetTester tester,
    ) async {
      final List<String> written = <String>[];
      final FrameTimingRecorder recorder = FrameTimingRecorder(
        enabled: true,
        log: written.add,
      );

      recorder.attach();
      expect(recorder.attached, isTrue);

      // **The engine's own channel.** `addTimingsCallback` installs
      // `PlatformDispatcher.onReportTimings`, and calling it is what the engine
      // does when it delivers a batch.
      PlatformDispatcher.instance.onReportTimings?.call(<FrameTiming>[
        aFrame(),
      ]);

      expect(recorder.buildStats.count, 1);
      expect(recorder.buildStats.p50, 8000);
      expect(recorder.rasterStats.p50, 3000);
      expect(written, hasLength(1));
    });

    testWidgets('and attaching twice registers one callback', (
      WidgetTester tester,
    ) async {
      final FrameTimingRecorder recorder = FrameTimingRecorder(
        enabled: true,
        log: (String message) {},
      );

      recorder.attach();
      recorder.attach();

      PlatformDispatcher.instance.onReportTimings?.call(<FrameTiming>[
        aFrame(),
      ]);

      // One sample, not two. `SchedulerBinding.addTimingsCallback` executes a
      // callback registered twice, and a doubled sample count would make every
      // percentile in the report a lie about the app.
      expect(recorder.buildStats.count, 1);
    });
  });
}
