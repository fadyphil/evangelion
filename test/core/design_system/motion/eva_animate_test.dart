import 'package:evangelion/core/design_system/motion/eva_animate.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

/// The controller the built `Animate` is reading.
///
/// This reaches **state, not appearance**. §14's requirement is that the animation does
/// not run, which is a fact about a controller's value over time — observable without
/// comparing a single pixel, which is why these are behaviour tests.
AnimationController controllerOf(WidgetTester tester) =>
    tester.widget<Animate>(find.byType(Animate)).controller!;

/// Pumps an [EvaAnimate] with animations on or off.
///
/// ## THE EXTRA `pump()` IS LOAD-BEARING
///
/// `Animate.initState` calls `_restart()`, which ends in
/// `Future.delayed(widget.delay, …)` — and `Future.delayed` creates a `Timer` even for
/// `Duration.zero`. One therefore hangs off **every** `Animate` in the tree until a
/// frame turns past it, and a test body that ends first fails with *"A Timer is still
/// pending even after the widget tree was disposed"*. The failure surfaces against
/// whichever test ran next, which is how a real problem gets misfiled as flakiness.
///
/// It also lets [EvaAnimate]'s own `addPostFrameCallback` run, so the controller has
/// actually started by the time the assertions look at it.
///
/// ## WHY THE PUMP IS `1ms` AND NOT `pump()`
///
/// Measured: a bare `await tester.pump()` does **not** drain it, because a zero-length
/// pump does not advance the fake clock and the timer is already due *at* the current
/// time. `pump(const Duration(milliseconds: 1))` advances past it. Two of the tests
/// here were failing with the pending-timer assertion until that changed, and the
/// failure pointed at whichever test ran next rather than at the pump.
Future<void> pumpEva(
  WidgetTester tester, {
  required bool disableAnimations,
  List<Effect> effects = const <Effect>[],
  Object? trigger,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: EvaAnimate(
          effects: effects.isEmpty
              ? <Effect>[MotionMoment.routine.fadeIn()]
              : effects,
          trigger: trigger,
          child: const Text('x', textDirection: TextDirection.ltr),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  group('MotionMoment', () {
    test('every factory stamps its own duration and curve', () {
      // The property that makes a literal impossible at a call site: no factory takes a
      // timing, so a `null` here would mean a timing was *lost* rather than defaulted.
      expect(MotionMoment.values, hasLength(4));
      for (final MotionMoment moment in MotionMoment.values) {
        final List<Effect> effects = <Effect>[
          moment.fadeIn(),
          moment.fadeOut(),
          moment.slide(const Offset(0, 8)),
          moment.scaleFrom(0.94),
          moment.shake(),
          moment.saturate(end: MotionMoment.desaturated),
        ];
        for (final Effect effect in effects) {
          expect(effect.duration, moment.duration, reason: '$moment');
          expect(effect.curve, moment.curve, reason: '$moment');
        }
      }
    });

    test('routine is expo over EvaMotion.base', () {
      expect(MotionMoment.routine.duration, EvaMotion.base);
      expect(MotionMoment.routine.curve, EvaMotion.interactiveCurve);
    });

    test('screen is longer than routine, on the same curve', () {
      // Distinct because a 250ms surface transition and a 200ms button are different
      // amounts of time, not the same one rounded.
      expect(
        MotionMoment.screen.duration,
        greaterThan(MotionMoment.routine.duration),
      );
      expect(MotionMoment.screen.curve, MotionMoment.routine.curve);
    });

    test('only the achievement moments overshoot', () {
      expect(momentOvershoots(MotionMoment.achievement), isTrue);
      expect(momentOvershoots(MotionMoment.achievementExit), isTrue);
      expect(momentOvershoots(MotionMoment.routine), isFalse);
      expect(momentOvershoots(MotionMoment.screen), isFalse);
    });

    test('achievement exit is faster than the entrance, on the same curve', () {
      expect(
        MotionMoment.achievementExit.duration,
        lessThan(MotionMoment.achievement.duration),
      );
      // Same curve on the way out, so the departure reads as the same event.
      expect(
        MotionMoment.achievementExit.curve,
        MotionMoment.achievement.curve,
      );
    });

    test('the desaturated level is a number strictly between 0 and 1', () {
      // 0.0 reads as *disabled*; a broken streak should read as *lost*. Simplifying
      // this to 0.0 stops the flame looking like a flame.
      expect(MotionMoment.desaturated, greaterThan(0.0));
      expect(MotionMoment.desaturated, lessThan(1.0));
    });

    test('scaleFrom takes a floor the package can actually render', () {
      // `ScaleEffect._normalizeScale` floors at `minScale`, so `0.0` is not a usable
      // begin value.
      final ScaleEffect effect = MotionMoment.routine.scaleFrom(0.94);
      expect((effect.begin as Offset).dx, 0.94);
      expect(ScaleEffect.minScale, greaterThan(0.0));
    });
  });

  group('installPackageDefaults', () {
    test('replaces linear and a 300ms literal with this app\'s tokens', () {
      // Before: `Animate.defaultCurve` is `Curves.linear`, used nowhere else in this
      // app, and `defaultDuration` is a literal 300ms matching no token.
      installPackageDefaults();
      expect(Animate.defaultCurve, EvaMotion.interactiveCurve);
      expect(Animate.defaultDuration, EvaMotion.base);
      expect(Animate.defaultCurve, isNot(Curves.linear));
    });
  });

  group('reduced motion', () {
    testWidgets('jumps straight to the end state and never moves', (
      WidgetTester tester,
    ) async {
      await pumpEva(tester, disableAnimations: true);
      final AnimationController controller = controllerOf(tester);

      expect(controller.value, 1.0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        controller.value,
        1.0,
        reason: 'a reduced-motion reader must see no motion at all',
      );
      await tester.pump(const Duration(seconds: 2));
      expect(controller.value, 1.0);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('still builds the wrapper, so the subtree keeps its shape', (
      WidgetTester tester,
    ) async {
      // Decision 124 rejected `return child` for the route transition: a transitions
      // builder's job is to wrap the page, and swapping the subtree for a reader who
      // asked for *less* motion rather than *no* widget is the wrong trade. The same
      // reasoning applies here, so the `Animate` must still exist — and the child must
      // still be inside it, which is the part `return child` would have broken.
      //
      // The effect list itself is not assertable from outside: `Animate` takes
      // `effects` in its constructor and keeps them in a private `_entries`, with no
      // public getter. Asserting the structure is also the stronger claim, since a
      // wrapper that existed but wrapped nothing would be equally wrong.
      await pumpEva(tester, disableAnimations: true);
      expect(find.byType(Animate), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Animate), matching: find.text('x')),
        findsOneWidget,
      );
    });

    testWidgets('does not animate from the end value', (
      WidgetTester tester,
    ) async {
      // The opposite failure: setting 1.0 and *then* animating from it looks identical
      // for one frame and then moves.
      await pumpEva(tester, disableAnimations: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controllerOf(tester).isAnimating, isFalse);
    });
  });

  group('when motion is enabled', () {
    testWidgets('starts at 0 and reaches 1', (WidgetTester tester) async {
      await pumpEva(tester, disableAnimations: false);
      final AnimationController controller = controllerOf(tester);
      expect(
        controller.value,
        0.0,
        reason: 'an entrance begins at its begin value, not the default 1.0',
      );
      await tester.pumpAndSettle();
      expect(controller.value, 1.0);
    });

    testWidgets('the controller outlasts its longest effect', (
      WidgetTester tester,
    ) async {
      // The package computes each effect's `Interval` as `begin / controller.duration`.
      // A controller shorter than an effect divides by the wrong total and the effect
      // finishes early — silently.
      await pumpEva(
        tester,
        disableAnimations: false,
        effects: <Effect>[MotionMoment.screen.fadeIn()],
      );
      expect(controllerOf(tester).duration, EvaMotion.screen);
    });

    testWidgets('a routine effect is quicker than a screen one', (
      WidgetTester tester,
    ) async {
      await pumpEva(
        tester,
        disableAnimations: false,
        effects: <Effect>[MotionMoment.routine.fadeIn()],
      );
      expect(controllerOf(tester).duration, EvaMotion.base);
    });
  });

  group('trigger', () {
    testWidgets('replays when it changes', (WidgetTester tester) async {
      await pumpEva(tester, disableAnimations: false, trigger: 'initial');
      final AnimationController controller = controllerOf(tester);
      await tester.pumpAndSettle();
      expect(controller.value, 1.0);

      await pumpEva(tester, disableAnimations: false, trigger: 'changed');
      expect(controller.value, lessThan(1.0), reason: 'back to the start');
      await tester.pumpAndSettle();
      expect(controller.value, 1.0);
    });

    testWidgets('does NOT replay when nothing changed', (
      WidgetTester tester,
    ) async {
      // The regression this parameter exists to prevent. Home re-fetches on every
      // `didPopNext` and on every locale change, and a naive "restart on every build"
      // turns a streak celebration into a flicker.
      await pumpEva(tester, disableAnimations: false, trigger: 'same');
      final AnimationController controller = controllerOf(tester);
      await tester.pumpAndSettle();
      expect(controller.value, 1.0);

      // Rebuild with an identical trigger, as a parent rebuild would.
      await pumpEva(tester, disableAnimations: false, trigger: 'same');
      expect(
        controller.value,
        1.0,
        reason: 'an unchanged trigger must leave a settled animation settled',
      );
    });

    testWidgets('a null trigger never replays', (WidgetTester tester) async {
      await pumpEva(tester, disableAnimations: false);
      final AnimationController controller = controllerOf(tester);
      await tester.pumpAndSettle();
      expect(controller.value, 1.0);
      await pumpEva(tester, disableAnimations: false);
      expect(controller.value, 1.0);
    });
  });
}
