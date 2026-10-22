import 'package:evangelion/core/diagnostics/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// The statistics over a series of frame durations.
///
/// `FrameStats` is the **pure** half of the frame-timing instrument: it takes
/// plain microsecond integers and knows nothing about Flutter, `dart:ui` or
/// the engine. That is what makes the arithmetic testable at all — a
/// `FrameTiming` can only be produced by the engine, so a statistics type that
/// spoke in `FrameTiming` would have nothing to assert against.
///
/// ## WHY THE PERCENTILES ARE **NEAREST-RANK**
///
/// A percentile has more than one definition and the choice is not cosmetic:
/// "the 95th percentile" of twenty samples is the 19th or the 20th under
/// nearest-rank and interpolation, and the two disagree by a whole sample.
/// **Nearest-rank is the one that answers the question a frame budget asks** —
/// "how long did the slowest 5 % of frames take" — because it always returns a
/// sample that was actually measured. An interpolated percentile returns a
/// number that no frame produced, and a budget read off it is a budget read
/// off a fiction.
void main() {
  group('an empty series', () {
    late FrameStats stats;

    setUp(() {
      stats = FrameStats(label: 'build', samples: const <int>[]);
    });

    test('has no samples', () {
      expect(stats.count, 0);
    });

    test('reports zero for every statistic, rather than throwing', () {
      // A recorder that has seen no frames is a **normal** state, not an
      // error: the engine reports the first batch about a second after the
      // app starts. Throwing here would make the instrument crash a normal
      // app.
      expect(stats.p50, 0);
      expect(stats.p95, 0);
      expect(stats.worst, 0);
      expect(stats.mean, 0.0);
    });

    test('and still describes itself', () {
      expect(
        stats.describe(),
        'build count=0 p50=0.0ms p95=0.0ms worst=0.0ms mean=0.0ms',
      );
    });
  });

  group('a single sample', () {
    late FrameStats stats;

    setUp(() {
      stats = FrameStats(label: 'build', samples: const <int>[8000]);
    });

    test('is every percentile, because there is nothing to rank', () {
      expect(stats.count, 1);
      expect(stats.p50, 8000);
      expect(stats.p95, 8000);
      expect(stats.worst, 8000);
      expect(stats.mean, 8000.0);
    });
  });

  group('twelve samples, in the order they arrived', () {
    late FrameStats stats;

    setUp(() {
      stats = FrameStats(
        label: 'build',
        samples: const <int>[
          8000,
          12000,
          4000,
          20000,
          16000,
          10000,
          12000,
          14000,
          18000,
          20000,
          6000,
          9000,
        ],
      );
    });

    test('counts every sample', () {
      expect(stats.count, 12);
    });

    test('the median is the sixth sample of the sorted series', () {
      // Sorted: 4000 6000 8000 9000 10000 12000 12000 14000 16000 18000
      //         20000 20000
      // Nearest-rank at 50 % of twelve is the sixth.
      expect(stats.p50, 12000);
    });

    test('the 95th percentile is the slowest of the slowest five percent', () {
      // Nearest-rank at 95 % of twelve is ceil(11.4) = 12 — the last sample.
      expect(stats.p95, 20000);
    });

    test('the worst sample is the maximum', () {
      expect(stats.worst, 20000);
    });

    test('the mean is the arithmetic mean', () {
      // 149000 / 12 = 12416.666…
      expect(stats.mean, 149000 / 12);
    });

    test('and the summary reads as one stable line', () {
      expect(
        stats.describe(),
        'build count=12 p50=12.0ms p95=20.0ms worst=20.0ms mean=12.4ms',
      );
    });
  });

  group('the samples are ranked, not taken in the order they arrived', () {
    test('a shuffled series gives the same statistics as a sorted one', () {
      final FrameStats shuffled = FrameStats(
        label: 'raster',
        samples: const <int>[20000, 4000, 12000, 6000, 8000],
      );
      final FrameStats sorted = FrameStats(
        label: 'raster',
        samples: const <int>[4000, 6000, 8000, 12000, 20000],
      );

      expect(shuffled.p50, sorted.p50);
      expect(shuffled.p95, sorted.p95);
      expect(shuffled.worst, sorted.worst);
      expect(shuffled.mean, sorted.mean);
    });

    test('and an even count takes the lower of the two middle samples', () {
      // Four samples: nearest-rank at 50 % is the second, not the average of
      // the second and the third.
      final FrameStats stats = FrameStats(
        label: 'raster',
        samples: const <int>[4000, 8000, 12000, 16000],
      );

      expect(stats.p50, 8000);
      expect(stats.p95, 16000);
      expect(stats.mean, 10000.0);
    });
  });

  group('the summary is stable', () {
    test('two statistics over the same samples read identically', () {
      const List<int> samples = <int>[4000, 8000, 12000, 16000];

      expect(
        FrameStats(label: 'build', samples: samples).describe(),
        FrameStats(label: 'build', samples: samples).describe(),
      );
    });

    test('and the label is part of it, so a line says what it measures', () {
      expect(
        FrameStats(label: 'raster', samples: const <int>[1000]).describe(),
        startsWith('raster '),
      );
    });
  });
}
