import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the prototype\'s own patterns', () {
    test('a single number is one vibration', () {
      expect(hapticPatternFor(RitualHaptic.dockTap), <int>[10]);
      expect(hapticPatternFor(RitualHaptic.fontStep), <int>[10]);
      expect(hapticPatternFor(RitualHaptic.bookmark), <int>[12]);
      expect(hapticPatternFor(RitualHaptic.verseSelected), <int>[12]);
      expect(hapticPatternFor(RitualHaptic.quizOpened), <int>[15]);
      expect(hapticPatternFor(RitualHaptic.daylightToggled), <int>[15]);
      expect(hapticPatternFor(RitualHaptic.hapticsEnabled), <int>[15]);
      expect(hapticPatternFor(RitualHaptic.streakOpened), <int>[20]);
      expect(hapticPatternFor(RitualHaptic.selahStarted), <int>[20]);
      expect(hapticPatternFor(RitualHaptic.answerCorrect), <int>[30]);
    });

    test(
      'the selah and the results share the prototype\'s three-part rhythm',
      () {
        // `eva/redesign.html:1330` and `:1445` — `haptic([30,40,30])`.
        expect(hapticPatternFor(RitualHaptic.selahCompleted), <int>[
          30,
          40,
          30,
        ]);
        expect(hapticPatternFor(RitualHaptic.resultsShown), <int>[30, 40, 30]);
      },
    );

    test('a wrong answer asks for the harder rhythm', () {
      // `eva/redesign.html:1429` — `haptic([40,60,40])`.
      expect(hapticPatternFor(RitualHaptic.answerWrong), <int>[40, 60, 40]);
    });

    test('every member has a pattern, and none is empty', () {
      for (final RitualHaptic haptic in RitualHaptic.values) {
        expect(
          hapticPatternFor(haptic),
          isNotEmpty,
          reason: '$haptic must vibrate for something',
        );
        for (final int milliseconds in hapticPatternFor(haptic)) {
          expect(
            milliseconds,
            greaterThan(0),
            reason: '$haptic carries a non-positive vibration',
          );
        }
      }
    });
  });

  group('the Flutter impact each haptic becomes', () {
    test('the shortest vibrations are ticks', () {
      // 10 ms (`:1275`, `:1396`) and 12 ms (`:1388`, `:1394`) are the
      // prototype's briefest — a click, not a bump.
      expect(hapticImpactFor(RitualHaptic.dockTap), HapticImpact.selection);
      expect(hapticImpactFor(RitualHaptic.fontStep), HapticImpact.selection);
      expect(hapticImpactFor(RitualHaptic.bookmark), HapticImpact.selection);
      expect(
        hapticImpactFor(RitualHaptic.verseSelected),
        HapticImpact.selection,
      );
    });

    test('the short bumps are light impacts', () {
      // 15 ms (`:1411`, `:1482`, `:1498`) and 20 ms (`:1320`, `:1338`).
      expect(hapticImpactFor(RitualHaptic.quizOpened), HapticImpact.light);
      expect(hapticImpactFor(RitualHaptic.daylightToggled), HapticImpact.light);
      expect(hapticImpactFor(RitualHaptic.hapticsEnabled), HapticImpact.light);
      expect(hapticImpactFor(RitualHaptic.streakOpened), HapticImpact.light);
      expect(hapticImpactFor(RitualHaptic.selahStarted), HapticImpact.light);
    });

    test('a correct answer is a medium impact', () {
      // 30 ms — `eva/redesign.html:1428`.
      expect(hapticImpactFor(RitualHaptic.answerCorrect), HapticImpact.medium);
    });

    test('a three-part rhythm is a heavy impact, because its peak is', () {
      // `haptic([30,40,30])` and `haptic([40,60,40])` have no Flutter
      // equivalent — `HapticFeedback` has no pattern API — so the strongest
      // element of the rhythm decides, and both peaks are heavy.
      expect(hapticImpactFor(RitualHaptic.selahCompleted), HapticImpact.heavy);
      expect(hapticImpactFor(RitualHaptic.resultsShown), HapticImpact.heavy);
      expect(hapticImpactFor(RitualHaptic.answerWrong), HapticImpact.heavy);
    });

    test('the impact is decided by the LONGEST vibration in the pattern', () {
      // The rule, stated on its own, so the three rows above are consequences
      // of it rather than three separate opinions.
      for (final RitualHaptic haptic in RitualHaptic.values) {
        final List<int> pattern = hapticPatternFor(haptic);
        final int peak = pattern.reduce((int a, int b) => a > b ? a : b);
        final HapticImpact expected = switch (peak) {
          <= 12 => HapticImpact.selection,
          <= 25 => HapticImpact.light,
          <= 35 => HapticImpact.medium,
          _ => HapticImpact.heavy,
        };
        expect(
          hapticImpactFor(haptic),
          expected,
          reason: '$haptic peaks at $peak ms',
        );
      }
    });
  });
}
