import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [NeuralMotionScope] around [child] and hands back the bundle.
///
/// The bundle is captured through a [Builder] rather than constructed, so the
/// test observes the object the tree publishes — which is the only one that
/// matters, since §13.2 forbids the caller from supplying its own.
///
/// [animationsEnabled] is `bool?` here for the same reason it is on the widget:
/// `null` means "let the platform decide", which is the default every test in
/// this file was relying on before H4 and must keep getting.
Future<EvaNeuralMotion> pumpScope(
  WidgetTester tester, {
  bool? animationsEnabled = true,
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

/// The number of tickers the scheduler currently has callbacks registered for.
///
/// `SchedulerBinding.transientCallbackCount` is the closest thing the framework
/// exposes to "how many animations are running", and it is exact: a running
/// `Ticker` registers one transient callback per frame for itself, so two
/// running clocks read `2` and two stopped clocks read `0`. Measured in this
/// suite, and the negative controls are the tests either side of the reduced-
/// motion group.
///
/// This is a stronger witness than `isAnimating`, which only says what one
/// controller was told — a ticker can be scheduled without the controller
/// reporting it, and a leaked third ticker has no controller to ask about.
int get _tickers => SchedulerBinding.instance.transientCallbackCount;

void main() {
  group('the bundle is two clocks and a pointer', () {
    testWidgets('publishes itself to a descendant', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.float.duration, kFloatPeriod);
      expect(motion.lumen.ticker.duration, kLumenClockPeriod);
    });

    testWidgets('both clocks are running when animations are enabled', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      expect(motion.float.isAnimating, isTrue);
      expect(motion.lumen.ticker.isAnimating, isTrue);
      await tester.pump();
      expect(
        _tickers,
        2,
        reason:
            'the control for the reduced-motion group below: two running '
            'clocks register two transient callbacks, and this is the number '
            'that goes to zero when the platform asks for reduced motion',
      );
    });

    testWidgets('both clocks run forward, and neither wraps', (
      WidgetTester tester,
    ) async {
      // The old suite asserted the aurora's triangle wave and the hue clock's
      // forward sweep. Both of those clocks are gone with the orbs — the aurora
      // band they drove is the LUMEN shader's, and the shader reads `u_time`
      // instead of a triangle — and what survives is the pair that is left.
      //
      // The float clock is the flecks' and the witness sky's twinkle; the
      // shader clock is `u_time`. Both are unwrapped in the sense that matters:
      // the float clock's `value` grows inside its 20s cycle, and the shader
      // clock's seconds are monotonic by construction.
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pump(const Duration(seconds: 1));
      final double float = motion.floatValue;
      final double seconds = motion.lumen.seconds;

      await tester.pump(const Duration(seconds: 1));
      expect(motion.floatValue, greaterThan(float));
      expect(
        motion.lumen.seconds,
        greaterThan(seconds),
        reason: '`u_time` is monotonic — it never wraps',
      );
    });

    testWidgets('animationsEnabled: false leaves both clocks stopped', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: false,
      );
      expect(motion.float.isAnimating, isFalse);
      expect(motion.lumen.ticker.isAnimating, isFalse);
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
      expect(captured.lumen.ticker.isAnimating, isFalse);

      enabled = true;
      setOuter(() {});
      await tester.pump();
      expect(captured.float.isAnimating, isTrue);
    });
  });

  group('H4 — the platform\'s own reduced-motion signal reaches the clock', () {
    // THE DEFECT. `NeuralMotionScope` sat above `MaterialApp`, its doc claimed
    // `AccessibilityFeatures.disableAnimations` "cannot reach it either", and it
    // was right about the `MediaQuery` and wrong about the platform signal —
    // `platformDispatcher` is not part of the widget tree and is reachable from
    // anywhere. Measured before the fix, with `disableAnimations: true` set on
    // the dispatcher: float 0.05 → 0.1, hue 0.0833 → 0.1667, aurora 0.0714 →
    // 0.1429 after one second, and all three still `isAnimating == true`. The
    // *painted* result honoured reduced motion, because the ambient collapses
    // the layer to the canvas via `MediaQuery`; the *clock* did not.

    void useReducedMotionPlatform(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('the signal is genuinely reachable outside any widget tree', (
      WidgetTester tester,
    ) async {
      // The premise of the whole fix, asserted on its own: no `pumpWidget`, no
      // tree at all. If this ever stops being true the honest fix is a
      // composition-root parameter, not this scope's default.
      useReducedMotionPlatform(tester);
      expect(
        tester.platformDispatcher.accessibilityFeatures.disableAnimations,
        isTrue,
      );
    });

    testWidgets('and NO ticker is running under it', (
      WidgetTester tester,
    ) async {
      useReducedMotionPlatform(tester);
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: null,
      );
      await tester.pump();

      expect(motion.float.isAnimating, isFalse);
      expect(motion.lumen.ticker.isAnimating, isFalse);
      expect(
        _tickers,
        0,
        reason:
            'two tickers burning frames under a background that paints none '
            'of them is the exact cost §13 exists to remove, and '
            'isAnimating alone would not catch a ticker the controllers lost '
            'track of',
      );
      expect(
        SchedulerBinding.instance.hasScheduledFrame,
        isFalse,
        reason: 'nothing at all is asking for another frame',
      );
    });

    testWidgets('the clocks are frozen, not merely stopped-and-waiting', (
      WidgetTester tester,
    ) async {
      useReducedMotionPlatform(tester);
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: null,
      );
      await tester.pump();
      final double float0 = motion.floatValue;
      final double seconds0 = motion.lumen.seconds;

      await tester.pump(const Duration(seconds: 1));

      expect(motion.floatValue, float0);
      // The shader clock is **held at zero** under reduced motion, which is a
      // different answer from "stopped where it had reached" — see
      // `lumen_clock.dart`'s `TickedLumenClock.setReducedMotion`.
      expect(motion.lumen.seconds, seconds0);
    });

    testWidgets('with the signal off, both run — the negative control', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: null,
      );
      await tester.pump();
      expect(motion.float.isAnimating, isTrue);
      expect(_tickers, 2);
    });

    testWidgets('an explicit true overrides the platform', (
      WidgetTester tester,
    ) async {
      // `animationsEnabled` is a parameter and the composition root owns it; the
      // default resolves the signal, the parameter states an answer. Saying so
      // matters because a later phase replaces the default with `UserSettings` and
      // a reader's stored choice has to beat the OS. **Phase 9**, not Phase 5: the
      // settings repository is Phase 9's, and Phase 5 delivered `core/network` and
      // the `auth` feature. This line used to credit Phase 5, which had already
      // landed when it was written.
      useReducedMotionPlatform(tester);
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pump();
      expect(motion.float.isAnimating, isTrue);
      expect(_tickers, 2);
    });

    testWidgets('an OS toggle mid-session stops the clocks', (
      WidgetTester tester,
    ) async {
      // Without the `WidgetsBindingObserver` the signal would be honoured at
      // first mount only — half a fix wearing a whole fix's name.
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: null,
      );
      await tester.pump();
      expect(motion.float.isAnimating, isTrue);
      expect(_tickers, 2);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();

      expect(motion.float.isAnimating, isFalse);
      expect(_tickers, 0, reason: 'and the tickers go with them');
    });

    testWidgets('and toggling it back restarts them', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: null,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      expect(motion.float.isAnimating, isFalse);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      await tester.pump();
      expect(motion.float.isAnimating, isTrue);
      expect(motion.lumen.ticker.isAnimating, isTrue);
    });

    testWidgets('an explicit value opts out of the observer entirely', (
      WidgetTester tester,
    ) async {
      // Symmetry with `initState`: an app that states its own answer is not
      // asking the OS, so an OS toggle must not push into clocks the composition
      // root deliberately holds still.
      final EvaNeuralMotion motion = await pumpScope(
        tester,
        animationsEnabled: false,
      );
      await tester.pump();
      expect(motion.float.isAnimating, isFalse);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      expect(
        motion.float.isAnimating,
        isFalse,
        reason: 'the explicit `false` still wins after the OS says "animate"',
      );
    });
  });

  group('D1 — the listenable actually fires', () {
    testWidgets('repaint notifies at least once across three pumped frames', (
      WidgetTester tester,
    ) async {
      // Retitled. The old name — "notifies on every pumped frame" — was not what
      // it checked: `greaterThan(0)` is satisfied by a listener that fires once
      // and then never again, which is the D1 defect it exists to catch. The
      // per-frame property is asserted exactly, by the next test; this one says
      // only "the thing fires at all", which is the claim `greaterThan(0)`
      // actually supports.
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

    testWidgets('so a listener that fires once is caught here, not above', (
      WidgetTester tester,
    ) async {
      // The tightened form: three pumped frames must produce three
      // notifications, not one. A "notify only on the first frame ever"
      // mutation — which leaves `greaterThan(0)` green — fails this.
      final EvaNeuralMotion motion = await pumpScope(tester);
      int notifications = 0;
      void bump() {
        notifications++;
      }

      motion.repaint.addListener(bump);

      await tester.pump();
      notifications = 0;
      await tester.pump(const Duration(milliseconds: 16));
      expect(notifications, 1, reason: 'frame 1 of 3');
      await tester.pump(const Duration(milliseconds: 16));
      expect(notifications, 2, reason: 'frame 2 of 3');
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        notifications,
        3,
        reason:
            'frame 3 of 3 — a listener that stops after the first frame is the '
            'defect this whole group is about, and it has to be a failure here',
      );
    });

    testWidgets('one frame produces one notification, not two', (
      WidgetTester tester,
    ) async {
      // One merged listener rather than one per source: two controllers firing
      // two `notifyListeners` in a frame would rebuild the painter twice.
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

    testWidgets('the pointer offset repaints the scene', (
      WidgetTester tester,
    ) async {
      // ## THE POINTER MOVED INTO THE SCENE, AND THE CLAIM MOVED WITH IT
      //
      // The old assertion was that the bundle's own `repaint` listable fired
      // when the pointer moved, because the old `pointer` notifier was one of
      // the bundle's five merged sources. The pointer now belongs to the
      // **scene** — the shader's own `u_ptr` — and the scene is what the
      // painter listens to. So the claim is now: moving the pointer notifies
      // the scene, and the scene is the aurora's repaint signal.
      //
      // Asserting it on the *bundle* instead would be a claim about a wiring
      // that no longer exists, and asserting nothing at all would leave the
      // touch glow — the Workshop's own "Touch glow" control — unasserted.
      final EvaNeuralMotion motion = await pumpScope(tester);
      int notifications = 0;
      void bump() {
        notifications++;
      }

      motion.lumenScene.addListener(bump);
      await tester.pump();
      notifications = 0;

      motion.lumenScene.pointer.value = const Offset(4, 4);
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
    testWidgets('unmounting the scope disposes both controllers', (
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
      expect(motion.lumen.ticker.stop, throwsA(isA<AssertionError>()));
    });

    testWidgets('the pointer notifier is disposed too', (
      WidgetTester tester,
    ) async {
      final EvaNeuralMotion motion = await pumpScope(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      void noop() {}
      expect(
        () => motion.lumenScene.pointer.addListener(noop),
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

  group('LumenTiers.resolve — the tier is the shader tier', () {
    // ## WHY THERE IS ONE GROUP AND NOT TWO
    //
    // The old suite had two: `NeuralTiers.resolve` (a *cost* tier) and
    // `NeuralTiers.resolveShader` (the shader's tier). They are one function
    // now — `LumenTiers.resolve` returns a `LumenShaderTier` — so the two
    // groups are one, and the three pairs that asserted the *same* call twice
    // are one assertion each. What is left is every distinct rule.
    //
    // ## THE RULES, IN ONE PLACE
    //
    // | rule | source |
    // | --- | --- |
    // | reduced motion is the last word | the reader's, and it beats the override |
    // | the override replaces the *size* decision | the caller's cost decision |
    // | a viewport narrower than [kNarrowViewport] is `off` | `eva/redesign.html:46` — one canvas for every screen |
    // | over [kShaftsPixelBudget] logical px, the shafts go | the measured 5.04 ns/px |

    test('an explicit tier wins outright, even a bad one', () {
      // The injection seam: a test that needs `off` must be able to ask for it
      // without arranging a viewport that resolves to `off` on its own.
      expect(
        LumenTiers.resolve(
          size: const Size(1400, 2000),
          animationsEnabled: true,
          override: LumenShaderTier.off,
        ),
        LumenShaderTier.off,
      );
    });

    test('reduced motion wins before the size rules are consulted', () {
      // A 4K desktop is the largest viewport this app will ever see and it must
      // still be `off` if the reader asked for reduced motion.
      expect(
        LumenTiers.resolve(
          size: const Size(3840, 2160),
          animationsEnabled: false,
        ),
        LumenShaderTier.off,
      );
    });

    test('reduced motion beats an explicit `full` too', () {
      // …and an override cannot re-enable motion the user switched off. The
      // override is for the *cost* decision; the accessibility decision is not
      // overridable. This is the one place `override` does not win.
      expect(
        LumenTiers.resolve(
          size: const Size(1200, 2000),
          animationsEnabled: false,
          override: LumenShaderTier.full,
        ),
        isNot(LumenShaderTier.full),
      );
      // And it is `off`, not merely "not full" — the flat canvas paints.
      expect(
        LumenTiers.resolve(
          size: const Size(1200, 2000),
          animationsEnabled: false,
          override: LumenShaderTier.full,
        ),
        LumenShaderTier.off,
      );
    });

    test('a narrow phone drops to `off`', () {
      expect(
        LumenTiers.resolve(size: const Size(320, 568), animationsEnabled: true),
        LumenShaderTier.off,
      );
    });

    test('an ordinary phone gets the full shader', () {
      expect(
        LumenTiers.resolve(size: const Size(393, 852), animationsEnabled: true),
        LumenShaderTier.full,
      );
    });

    test('a phone is `full` however tall it is; a tablet is `full` too', () {
      // The old tiers were `low` / `mid` / `high` and counted **orb layers** —
      // and the shader's decision never read the difference. `mid` and `high`
      // both meant "the shader is on, and the shafts are governed by the pixel
      // budget", and the budget is one rule for every viewport. So a phone and
      // a tablet now resolve the same way, and the rule that separates them is
      // pixels, not a tier name.
      expect(
        LumenTiers.resolve(size: const Size(414, 896), animationsEnabled: true),
        LumenShaderTier.full,
      );
      expect(
        LumenTiers.resolve(
          size: const Size(1024, 1366),
          animationsEnabled: true,
        ),
        LumenShaderTier.full,
      );
    });

    test('the thresholds are the ones the documentation names', () {
      expect(kNarrowViewport, 360.0);
      expect(
        LumenTiers.resolve(size: const Size(360, 800), animationsEnabled: true),
        LumenShaderTier.full,
        reason: '360 is the first width that is not narrow',
      );
      expect(
        LumenTiers.resolve(size: const Size(359, 800), animationsEnabled: true),
        LumenShaderTier.off,
        reason: 'and 359 is the last width that is',
      );
    });

    test('it reads the shortest side, so landscape and portrait agree', () {
      expect(
        LumenTiers.resolve(size: const Size(852, 393), animationsEnabled: true),
        LumenTiers.resolve(size: const Size(393, 852), animationsEnabled: true),
      );
    });

    test('every tier is reachable through the override', () {
      for (final LumenShaderTier tier in LumenShaderTier.values) {
        expect(
          LumenTiers.resolve(
            size: const Size(393, 852),
            animationsEnabled: true,
            override: tier,
          ),
          tier,
          reason: tier.name,
        );
      }
    });

    test('`off` means the shader stays off', () {
      expect(
        LumenTiers.resolve(
          size: const Size(393, 852),
          animationsEnabled: true,
          override: LumenShaderTier.off,
        ),
        LumenShaderTier.off,
      );
    });

    test('a 1080p desktop loses shafts but keeps the shader', () {
      // 1920 x 1080 = 2.07 Mpx — the first common viewport over budget.
      expect(
        LumenTiers.resolve(
          size: const Size(1920, 1080),
          animationsEnabled: true,
        ),
        LumenShaderTier.noShafts,
      );
    });

    test(
      'a 4K frame with animations on still paints — just without shafts',
      () {
        expect(
          LumenTiers.resolve(
            size: const Size(3840, 2160),
            animationsEnabled: true,
          ),
          LumenShaderTier.noShafts,
        );
      },
    );

    test('exactly 2 Mpx keeps shafts; one row more loses them', () {
      expect(
        LumenTiers.resolve(
          size: const Size(2000, 1000),
          animationsEnabled: true,
        ),
        LumenShaderTier.full,
      );
      expect(
        LumenTiers.resolve(
          size: const Size(2001, 1000),
          animationsEnabled: true,
        ),
        LumenShaderTier.noShafts,
      );
    });

    test('the pixel gate is one rule, not one per tier', () {
      // A tall narrow window over budget: 600 x 3400 = 2.04 Mpx. Under the old
      // tiers this was a `mid` viewport, and the gate was still the same rule —
      // which is why the tier that separated the two is gone.
      expect(
        LumenTiers.resolve(
          size: const Size(600, 3400),
          animationsEnabled: true,
        ),
        LumenShaderTier.noShafts,
      );
    });

    test('the budget is two million logical px', () {
      expect(kShaftsPixelBudget, 2000000);
    });

    test(
      'an explicit `full` override re-enables the shader on a narrow viewport',
      () {
        // The override seam: the cost decision belongs to the caller.
        expect(
          LumenTiers.resolve(
            size: const Size(320, 568),
            animationsEnabled: true,
            override: LumenShaderTier.full,
          ),
          LumenShaderTier.full,
        );
      },
    );

    test('an explicit `off` override keeps the shader off on a desktop', () {
      expect(
        LumenTiers.resolve(
          size: const Size(1920, 1080),
          animationsEnabled: true,
          override: LumenShaderTier.off,
        ),
        LumenShaderTier.off,
      );
    });
  });
}
