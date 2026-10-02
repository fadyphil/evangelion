import 'package:evangelion/core/design_system/effects/neural_background.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [NeuralMotionScope] around [child] and hands back the bundle.
///
/// The bundle is captured through a [Builder] rather than constructed, so the
/// test observes the object the tree publishes — which is the only one that
/// matters, since §13.2 forbids the caller from supplying its own.
Future<EvaNeuralMotion> pumpScope(
  WidgetTester tester, {
  bool animationsEnabled = true,
  Widget child = const SizedBox.expand(),
}) async {
  late EvaNeuralMotion captured;
  await tester.pumpWidget(
    NeuralMotionScope(
      animationsEnabled: animationsEnabled,
      child: Builder(
        builder: (BuildContext context) {
          captured = NeuralMotionScope.of(context);
          return child;
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group('the bundle is three controllers and a pointer', () {
    testWidgets('publishes itself to a descendant', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.float.duration, kFloatPeriod);
      expect(motion.hue.duration, kHuePeriod);
    });

    testWidgets('all three clocks are running when animations are enabled', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.float.isAnimating, isTrue);
      expect(motion.hue.isAnimating, isTrue);
      expect(motion.aurora.isAnimating, isTrue);
    });

    testWidgets('the aurora clock reverses, the others do not', (
      WidgetTester tester,
    ) async {
      // `index.css:79-81` — `aurora-drift 14s`: 0% at 0, peak at 50%, back at
      // 100%. So the band peaks at t=7s and completes a wave in 14.
      //
      // The controller runs FORWARDS and `auroraPulse` builds the triangle; §13.2
      //'s reference `repeat(reverse: true)` would instead peak at t=14s and take
      // 28s per wave. The test below pins the prototype's period, not the
      // reference snippet's.
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pump(const Duration(seconds: 7));
      expect(
        motion.auroraValue,
        closeTo(0.5, 1e-9),
        reason: 'the raw clock peaks at the half cycle',
      );
      await tester.pump(const Duration(seconds: 7));
      expect(
        motion.auroraValue,
        closeTo(0.0, 1e-9),
        reason: 'and the wave completes in 14s, not 28',
      );

      final double hue = motion.hueValue;
      await tester.pump(const Duration(milliseconds: 100));
      expect(motion.hueValue, greaterThan(hue));
    });

    testWidgets('animationsEnabled: false leaves all three stopped', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: false,
      );
      expect(motion.float.isAnimating, isFalse);
      expect(motion.hue.isAnimating, isFalse);
      expect(motion.aurora.isAnimating, isFalse);
    });

    testWidgets('flipping animationsEnabled stops the clocks in place', (
      WidgetTester tester,
    ) async {
      // `didUpdateWidget`, not a new scope: rebuilding the tree must not be the
      // thing that stops the clocks, or switching the preference back would
      // restart the ambient animation from zero instead of resuming it.
      bool enabled = true;
      late StateSetter setOuter;
      late EvaNeuralMotion captured;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuter = setState;
            return NeuralMotionScope(
              animationsEnabled: enabled,
              child: Builder(
                builder: (BuildContext inner) {
                  captured = NeuralMotionScope.of(inner);
                  return const SizedBox.expand();
                },
              ),
            );
          },
        ),
      );
      await tester.pump();
      expect(captured.float.isAnimating, isTrue);

      enabled = false;
      setOuter(() {});
      await tester.pump();
      expect(
        captured.float.isAnimating,
        isFalse,
        reason: 'a stopped background must not leave a running ticker',
      );
      expect(captured.hue.isAnimating, isFalse);

      enabled = true;
      setOuter(() {});
      await tester.pump();
      expect(captured.float.isAnimating, isTrue);
    });
  });

  group('D1 — the listenable actually fires', () {
    testWidgets('repaint notifies on every pumped frame', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      int notifications = 0;
      void bump() {
        notifications++;
      }

      motion.repaint.addListener(bump);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        notifications,
        greaterThan(0),
        reason:
            '§13.1 listens to this and the reference implementation never '
            'notified, so the background painted once and never again',
      );
    });

    testWidgets('one frame produces one notification, not four', (
      WidgetTester tester,
    ) async {
      // One merged listener rather than one per source: four controllers firing
      // four `notifyListeners` in a frame would rebuild the painter four times.
      final EvaNeuralMotion motion = await pumpScope(tester);
      int notifications = 0;
      void bump() {
        notifications++;
      }

      motion.repaint.addListener(bump);

      await tester.pump();
      notifications = 0;
      await tester.pump(const Duration(milliseconds: 16));

      expect(notifications, 1);
    });

    testWidgets('a stopped clock stops the notifications', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: false,
      );
      int notifications = 0;
      void bump() {
        notifications++;
      }

      motion.repaint.addListener(bump);
      await tester.pump(const Duration(milliseconds: 500));
      expect(notifications, 0);
    });

    testWidgets('the pointer offset is a repaint source too', (
      WidgetTester tester,
    ) async {
      // `parallax` is only worth preserving if moving the pointer repaints.
      final EvaNeuralMotion motion = await pumpScope(tester);
      int notifications = 0;
      void bump() {
        notifications++;
      }

      motion.repaint.addListener(bump);
      await tester.pump();
      notifications = 0;

      motion.pointer.value = const Offset(4, 4);
      expect(notifications, 1);
    });

    testWidgets('the clocks actually move across pumped frames', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pump();
      final double before = motion.floatValue;
      await tester.pump(const Duration(milliseconds: 500));
      expect(motion.floatValue, greaterThan(before));
      expect(motion.floatValue, lessThan(1.0));
    });
  });

  group('D1 — disposal', () {
    testWidgets('unmounting the scope disposes all three controllers', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);

      await tester.pumpWidget(const SizedBox.shrink());

      // `TickerProviderStateMixin.dispose` throws if any ticker it created is
      // still alive, and `_motion.dispose()` is what clears them — so a leak
      // would already have failed this test as an uncaught FlutterError.
      expect(tester.takeException(), isNull);

      // And the controllers are genuinely unusable afterwards. `stop()` asserts
      // `_ticker != null`, which `AnimationController.dispose` has already
      // nulled — so this is the framework reporting the disposal, not a
      // property this suite invented.
      expect(motion.float.stop, throwsA(isA<AssertionError>()));
      expect(motion.hue.stop, throwsA(isA<AssertionError>()));
      expect(motion.aurora.stop, throwsA(isA<AssertionError>()));
    });

    testWidgets('the pointer notifier is disposed too', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      void noop() {}
      expect(
        () => motion.pointer.addListener(noop),
        throwsA(isA<AssertionError>()),
        reason: 'ChangeNotifier.addListener asserts after dispose()',
      );
    });

    testWidgets('a second mount gets brand new controllers', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion first = await pumpScope(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      final EvaNeuralMotion second = await pumpScope(tester);

      expect(identical(first, second), isFalse);
      expect(identical(first.float, second.float), isFalse);
      // The stale bundle stays dead rather than quietly restarting.
      expect(first.float.stop, throwsA(isA<AssertionError>()));
    });

    testWidgets('no listener survives on the disposed notifier', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      // A notifier whose listener list outlived it would throw on dispose.
      expect(motion.notifyListeners, throwsA(isA<AssertionError>()));
    });
  });

  group('floatPhaseFor — §13.2 mitigation 2', () {
    testWidgets('stagger orbs by index over the count', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.floatPhaseFor(0, 4), 0.0);
      expect(motion.floatPhaseFor(1, 4), 0.25);
      expect(motion.floatPhaseFor(2, 4), 0.5);
      expect(motion.floatPhaseFor(3, 4), 0.75);
    });

    testWidgets('two orbs are half a cycle apart — never in lockstep', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.floatPhaseFor(0, 2), 0.0);
      expect(motion.floatPhaseFor(1, 2), 0.5);
    });

    testWidgets('a single orb rests at zero rather than dividing by zero', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.floatPhaseFor(0, 1), 0.0);
      expect(motion.floatPhaseFor(0, 1).isNaN, isFalse);
    });

    testWidgets('every real orb group produces distinct phases', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      for (final NeuralVariant variant in NeuralVariant.values) {
        final int count = orbsFor(variant).length;
        final Set<double> phases = <double>{
          for (int i = 0; i < count; i++) motion.floatPhaseFor(i, count),
        };
        expect(phases, hasLength(count), reason: variant.name);
      }
    });
  });

  group('D5 — NeuralTiers.resolve', () {
    test('an explicit tier wins outright, even a bad one', () {
      // The injection seam: a test that needs `low` must be able to ask for it
      // without arranging a viewport that resolves to `low` on its own.
      expect(
        NeuralTiers.resolve(
          size: const Size(1400, 2000),
          animationsEnabled: true,
          override: NeuralTier.low,
        ),
        NeuralTier.low,
      );
    });

    test('reduced motion wins before the size rules are consulted', () {
      // A 4K desktop is the largest viewport this app will ever see and it must
      // still be `low` if the reader asked for reduced motion.
      expect(
        NeuralTiers.resolve(
          size: const Size(3840, 2160),
          animationsEnabled: false,
        ),
        NeuralTier.low,
      );
    });

    test('reduced motion beats an explicit `high` too', () {
      // …and an override cannot re-enable motion the user switched off. The
      // override is for the *cost* decision; the accessibility decision is not
      // overridable. This is the one place `override` does not win.
      expect(
        NeuralTiers.resolve(
          size: const Size(1200, 2000),
          animationsEnabled: false,
          override: NeuralTier.high,
        ),
        isNot(NeuralTier.high),
      );
    });

    test('a narrow phone drops to low', () {
      expect(
        NeuralTiers.resolve(
          size: const Size(320, 568),
          animationsEnabled: true,
        ),
        NeuralTier.low,
      );
    });

    test('an ordinary phone is mid', () {
      expect(
        NeuralTiers.resolve(
          size: const Size(393, 852),
          animationsEnabled: true,
        ),
        NeuralTier.mid,
      );
    });

    test('a phone is mid however tall it is; a tablet is high', () {
      // `high` needs 640 on the *short* side, so no phone reaches it — which is
      // the right answer: `ORB_CONFIGS` positions orbs at absolute px offsets
      // authored for a ~390x844 window, and a phone already shows all of them.
      // `high` is the "a tablet or a desktop shows the whole composition" tier.
      expect(
        NeuralTiers.resolve(
          size: const Size(414, 896),
          animationsEnabled: true,
        ),
        NeuralTier.mid,
      );
      expect(
        NeuralTiers.resolve(
          size: const Size(1024, 1366),
          animationsEnabled: true,
        ),
        NeuralTier.high,
      );
    });

    test('the thresholds are the ones the documentation names', () {
      expect(kNarrowViewport, 360.0);
      expect(kWideViewport, 640.0);
      expect(
        NeuralTiers.resolve(
          size: const Size(360, 800),
          animationsEnabled: true,
        ),
        NeuralTier.mid,
        reason: '360 is the first width that is not narrow',
      );
      expect(
        NeuralTiers.resolve(
          size: const Size(640, 800),
          animationsEnabled: true,
        ),
        NeuralTier.high,
        reason: '640 is the first height that shows a whole orb',
      );
    });

    test('it reads the shortest side, so landscape and portrait agree', () {
      expect(
        NeuralTiers.resolve(
          size: const Size(852, 393),
          animationsEnabled: true,
        ),
        NeuralTiers.resolve(
          size: const Size(393, 852),
          animationsEnabled: true,
        ),
      );
    });

    test('every tier is reachable through the override', () {
      for (final NeuralTier tier in NeuralTier.values) {
        expect(
          NeuralTiers.resolve(
            size: const Size(393, 852),
            animationsEnabled: true,
            override: tier,
          ),
          tier,
          reason: tier.name,
        );
      }
    });
  });

  group('auroraPulse — the 0 → 1 → 0 wave of index.css:79-81', () {
    test('is 0 at the start, 1 at the half cycle, 0 at the end', () {
      expect(auroraPulse(0), 0.0);
      expect(auroraPulse(0.5), 1.0);
      expect(auroraPulse(1.0), 0.0);
    });

    test('is symmetric about the half cycle', () {
      expect(auroraPulse(0.25), closeTo(auroraPulse(0.75), 1e-12));
      expect(auroraPulse(0.1), closeTo(auroraPulse(0.9), 1e-12));
    });

    test('is periodic — a clock past 1.0 keeps waving', () {
      expect(auroraPulse(1.25), closeTo(auroraPulse(0.25), 1e-12));
      expect(auroraPulse(3.5), closeTo(auroraPulse(0.5), 1e-12));
    });

    test('never leaves [0, 1]', () {
      for (int step = 0; step <= 200; step++) {
        expect(auroraPulse(step / 50), inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
