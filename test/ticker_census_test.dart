/// The ticker census, as a gate.
///
/// ## WHAT IT CLAIMS
///
/// **A dock tab the reader cannot see must not be animating.** The dock shell
/// keeps its three tabs alive in one `IndexedStack`
/// (`lib/app/router/dock_shell_page.dart:71-72`), so an inactive tab is
/// *mounted* rather than *gone* — and a mounted `AnimationController` that
/// `repeat()`s keeps asking the scheduler for frames for as long as it lives.
///
/// ## THE MECHANISM, AND IT WAS **MEASURED** BEFORE IT WAS GATED
///
/// auto_route 11.2.0's `AutoTabsRouter` keeps the inactive children in the
/// `IndexedStack` and wraps each of them in `ExcludeSemantics` and
/// `ExcludeFocus` — **and in nothing else**
/// (`auto_route-11.2.0/lib/src/router/widgets/auto_tabs_router.dart:482-488`).
/// There is **no `TickerMode` anywhere in the package**: a search of
/// `auto_route-11.2.0/lib/` for `TickerMode` returns nothing at all.
///
/// That matters because a `TickerMode(enabled: false)` is Flutter's own answer
/// to "stop animating a subtree you cannot see" — it mutes the subtree's
/// tickers, and a muted ticker is **not** scheduled and **not** counted by
/// `SchedulerBinding.transientCallbackCount` (`ticker.dart:270` and
/// `ticker.dart:145-147`). So a correctly muted tab reads **zero** live
/// tickers here, and a merely *hidden* one reads **one**.
///
/// ## THE CONCRETE OFFENDER
///
/// `lib/features/home/presentation/widgets/selah_card.dart` — the selah card's
/// 44px ring. `_controller.repeat()` at `:595` (and again at `:579` when the
/// silence starts), the ring mounted unconditionally at `:484`, and an
/// `AnimatedBuilder` at `:621` rebuilding a `Transform.scale` and a
/// `BoxShadow` (`:660`) **on every frame**.
///
/// ## THE MEASUREMENTS, AND THEY ARE THE POINT
///
/// Measured on 2026-10-22 with `flutter test`, on the tree as it stands, with
/// the ambient's own two clocks **held still** (see the note on the ambient
/// below):
///
/// | the shell is showing | live tickers | frames in a 1s window |
/// | --- | --- | --- |
/// | the **home** tab | **1** — the selah ring, and it is the visible tab's own | **60** |
/// | the **/journey** tab | **1** — the **home** tab's ring, still breathing | **60** |
/// | the **/communion** tab | **1** — the **home** tab's ring, still breathing | **60** |
///
/// With the ambient **running**, as it does in the app, the same three rows
/// read **3**, **3** and **3** — the ambient's two clocks plus the ring.
///
/// So the ring is charged to the home tab on the home tab, and it is **still
/// charged to it on the other two**, and the number that should be zero is
/// one.
///
/// ## WHY THE AMBIENT IS HELD STILL IN THE GATE
///
/// Because the ambient's two clocks are an **app-wide constant** that is
/// present on every tab equally, and a constant cannot be the answer to the
/// question. The question is *"does the INACTIVE tab schedule frames?"*, and
/// the ambient's answer is "yes, on every tab, always" — so with it running,
/// "zero frames" is unreachable and the count would have to be "two", which
/// says nothing about the ring.
///
/// Holding the ambient still is not a weakening: it **removes a known
/// constant from a measurement**, which is what a controlled measurement is.
/// The ambient's own behaviour is gated where it belongs
/// (`test/core/design_system/effects/neural_motion_test.dart` and
/// `test/core/design_system/effects/gold_flecks_test.dart` both assert the
/// app's two ambient clocks), and the **production** numbers are measured and
/// asserted in the last group of this file, so a reader sees both.
///
/// ## WHY A GATE AND NOT A BENCHMARK
///
/// A benchmark prints a number, and a printed number rots: it is a claim in a
/// file that nothing re-checks. **A budget fails the build, so it cannot
/// rot.** The whole point of this file is that the number `0` is a *rule* —
/// "an inactive tab schedules nothing" — and not an observation that happens
/// to be true today.
///
/// ## AND WHY IT IS **RED** TODAY
///
/// On purpose. A gate that lands green over a known bug is the ADR-0020 shape
/// this repository has hit three times — decision 142 records
/// `flutter build linux --release` reporting "✓ Built" for three commits
/// while the toolchain was missing entirely. **A gate must be able to go
/// red, and it must be red while the bug it names is present.**
///
/// So the assertions below are at full strength. The fix belongs to the lane
/// that lands it; this file's job is to make the failure **legible** and
/// **precise**, and to hand the next lane a number it can turn green.
library;

import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/journey/journey_harness.dart';
import 'support/app_harness.dart';
import 'support/ticker_census.dart';

/// The window every measurement in this file is taken over.
///
/// Sixty 16ms steps is one second of wall clock, and it is **explicitly
/// pumped** rather than settled: `pumpAndSettle` times out against a
/// repeating ticker, and that timeout is this defect seen from the other
/// side. See `test/support/ticker_census.dart`.
const int _windowFrames = 60;

/// How long each step of the window advances the clock.
const Duration _windowStep = Duration(milliseconds: 16);

/// How long to let the tree's own one-shot animations finish.
///
/// Six half-second steps is three seconds, and it is long enough for the
/// journey tab's 1.3s entrance (and the shell's 400ms tab transition) to
/// complete, so the only thing left alive is what is alive on purpose.
const int _settleSteps = 6;

const Duration _settleStep = Duration(milliseconds: 500);

/// The dock shell, with the ambient's own clocks **held still**.
///
/// `routerHost` mounts `NeuralMotionScope` above `MaterialApp.router`, and the
/// scope's `child` is public — so the harness's tree is reused verbatim and
/// only the scope's `animationsEnabled` is overridden. Nothing else about the
/// shell changes: the same router, the same routes, the same dock.
///
/// **Why the override is a measurement and not a change**: the ambient's two
/// clocks are on every tab equally, and a constant cannot answer "does the
/// INACTIVE tab schedule frames?". See this file's header.
Widget _shellWithoutAmbient(AppRouter router) {
  final Widget host = routerHost(router);
  final NeuralMotionScope scope = host as NeuralMotionScope;
  return NeuralMotionScope(animationsEnabled: false, child: scope.child);
}

/// The router the shell runs on, and the journey cubit the journey tab needs.
AppRouter _router() {
  final AppRouter router = AppRouter(
    FakeAuthStatus(),
    ManualAuthChanges(),
    testRoleAccess(),
  );
  addTearDown(router.dispose);
  // The journey page resolves its cubit from the locator, and the dock shell
  // does not register one — the journey's own harness does, and the journey's
  // own suite owns the cubit's behaviour.
  registerJourneyCubit(journeyHarness().cubit);
  return router;
}

/// Lets the tree's one-shot animations finish.
Future<void> _settle(WidgetTester tester) async {
  for (int step = 0; step < _settleSteps; step++) {
    await tester.pump(_settleStep);
  }
}

/// The selah ring's own controller.
///
/// Reached through the `AnimatedBuilder` that drives it
/// (`selah_card.dart:621`), because the controller is a private field of a
/// private state class and there is no other door into it.
///
/// **It has to be taken while the card is ON STAGE.** `IndexedStack` in
/// Flutter 3.47 reports only its selected child as on-stage
/// (`widgets/indexed_stack.dart` — `_IndexedStackElement
/// .debugVisitOnstageChildren`), and the default finder skips off-stage
/// widgets — so once the reader has left the home tab the card is still
/// *mounted* but the finder cannot see it. That is a fact about the finder,
/// not about the tree, and the tree is what the census measures.
AnimationController _selahRing(WidgetTester tester) {
  final AnimatedBuilder builder = tester.widget<AnimatedBuilder>(
    find
        .descendant(
          of: find.byType(SelahCard),
          matching: find.byType(AnimatedBuilder),
        )
        .first,
  );
  return builder.animation as AnimationController;
}

/// A widget with no controller of its own — the "dead" half of the control.
class _QuietLeaf extends StatefulWidget {
  const _QuietLeaf();

  @override
  State<_QuietLeaf> createState() => _QuietLeafState();
}

class _QuietLeafState extends State<_QuietLeaf> {
  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 10, height: 10),
  );
}

/// A widget with one repeating controller — the "alive" half of the control.
class _BreathingLeaf extends StatefulWidget {
  const _BreathingLeaf();

  @override
  State<_BreathingLeaf> createState() => _BreathingLeafState();
}

class _BreathingLeafState extends State<_BreathingLeaf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Builds the controller **here**, and not as a `late final` field
  /// initialiser.
  ///
  /// A `late final` initialiser runs on the first *read* of the field, and
  /// this widget's `build` never reads it — so the controller would never be
  /// created, there would be no ticker, and the control would measure a tree
  /// that had never animated. That is the failure a control has to rule out
  /// on its own account.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 10, height: 10),
  );
}

void main() {
  group('the instrument', () {
    // ## WHY THIS GROUP EXISTS
    //
    // A measurement that cannot tell alive from dead is not a measurement. The
    // two rows below are the instrument's own calibration, and the **dead** row
    // comes first on purpose: **a scan that finds NOTHING is a failure, not a
    // pass**, and the only way to know a zero is a real zero is to have seen
    // the same instrument report a non-zero on a tree that is demonstrably
    // animating.

    testWidgets('a leaf with no controller schedules nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _QuietLeaf());
      await tester.pump();

      // **The landmark, before the measurement.** A tree that never mounted
      // would read zero tickers and zero frames too, and would satisfy this
      // row for the wrong reason — so the leaf is proved to be in the tree
      // first.
      expect(
        find.byType(_QuietLeaf),
        findsOneWidget,
        reason:
            'the leaf has to be in the tree, or "nothing is scheduling" is '
            'being measured on a tree that was never mounted',
      );

      final TickerCensus census = await censusFrames(
        tester,
        frames: _windowFrames,
        step: _windowStep,
      );

      expect(
        census.liveTickers,
        0,
        reason:
            'the control for the row below: a widget with no controller has '
            'no ticker, and the framework counts tickers rather than widgets',
      );
      expect(
        census.framesScheduled,
        0,
        reason:
            'and it schedules no frames at all. `tester.pump()` only renders '
            'when a frame was requested, so a tree that asks for nothing '
            'produces nothing — this is the "nothing", not "few"',
      );
    });

    testWidgets('and a leaf with a repeating controller schedules frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _BreathingLeaf());
      await tester.pump();

      expect(
        find.byType(_BreathingLeaf),
        findsOneWidget,
        reason: 'the leaf has to be in the tree for its controller to exist',
      );

      final TickerCensus census = await censusFrames(
        tester,
        frames: _windowFrames,
        step: _windowStep,
      );

      expect(
        census.liveTickers,
        1,
        reason:
            'one controller, one transient callback. A second would be a '
            'second ticker, and the point of the row is that the instrument '
            'can see a controller at all',
      );
      expect(
        census.framesScheduled,
        _windowFrames,
        reason:
            'a repeating ticker asks for a frame on every pump, so the window '
            'produced one frame per step. This is the "something" that the '
            'row above is the absence of',
      );
    });
  });

  group('the dock shell', () {
    testWidgets('the home tab schedules frames — the positive control', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS ROW IS NOT OPTIONAL
      //
      // A gate that asserts "zero" is satisfiable by a broken instrument, a
      // tree that never mounted, and a suite that measured nothing. This row
      // is the one that says **the instrument can see a ticker when there is
      // one**, on **this** shell, and it is the reason the row below cannot
      // pass vacuously.
      final AppRouter router = _router();

      await tester.pumpWidget(_shellWithoutAmbient(router));
      await pumpUntilFound(tester, find.byType(LumenDock));
      await _settle(tester);

      final TickerCensus census = await censusFrames(
        tester,
        frames: _windowFrames,
        step: _windowStep,
      );

      expect(
        census.liveTickers,
        1,
        reason:
            'the home tab is the VISIBLE tab, and the selah ring '
            '(lib/features/home/presentation/widgets/selah_card.dart) is its '
            'own: one controller, one transient callback. The ambient is held '
            'still for this measurement (see the file header), so this one '
            'ticker is the ring and nothing else',
      );
      expect(
        census.framesScheduled,
        _windowFrames,
        reason:
            'and it asks for a frame on every pump, so the window produced '
            'one frame per step. This is the positive control for the gate '
            'below: if this row ever reads zero, the instrument is not '
            'looking, and the gate below would be passing for the wrong '
            'reason',
      );
    });

    testWidgets('and an INACTIVE tab schedules nothing — THE GATE', (
      WidgetTester tester,
    ) async {
      final AppRouter router = _router();

      await tester.pumpWidget(_shellWithoutAmbient(router));
      await pumpUntilFound(tester, find.byType(LumenDock));
      await _settle(tester);

      // The ring is captured while the home tab is ON STAGE, because the
      // finder cannot see an off-stage card (see `_selahRing`).
      final AnimationController ring = _selahRing(tester);

      // The precondition, and it is a precondition rather than an assertion
      // about the bug: the ring must be alive BEFORE the switch, or the gate
      // below would be green because nothing was ever animating.
      expect(
        liveTickerCount,
        1,
        reason:
            'the home tab is showing and the selah ring is its own. If this '
            'reads zero the ring was never ticking and the gate below is '
            'measuring nothing',
      );

      // The reader leaves for the journey tab. The dock's own slot, and the
      // shell's 400ms tab transition, are one-shot and are let to finish.
      await tester.tap(find.text('Journey'));
      await pumpUntilFound(tester, find.byType(JourneyPage));
      await _settle(tester);

      final TickerCensus census = await censusFrames(
        tester,
        frames: _windowFrames,
        step: _windowStep,
      );

      // ## THE DIRECT CHECK, AND WHY IT IS NOT THE COUNT
      //
      // The count is the framework's tally; it says a ticker is alive but not
      // which one. This says **the ring itself**, read off the ring's own
      // controller: while its tab is inactive the ring's value must not
      // advance, because a controller that is not ticking does not move.
      //
      // It is a **behavioural** check rather than a check of the tree's
      // `TickerMode`, so it does not prescribe HOW the fix is made — a
      // controller that is stopped outright satisfies it just as a muted one
      // does.
      final double frozen = ring.value;
      await tester.pump(const Duration(milliseconds: 500));
      final double moved = ring.value;

      // ## EVERYTHING IS MEASURED BEFORE ANYTHING IS ASSERTED
      //
      // A `testWidgets` stops at its first failed expectation, so three
      // assertions in a row would report one number and hide the other two.
      // The numbers are therefore measured first and **printed into the first
      // failure message**, so one red row carries the whole measurement and
      // the next lane does not have to guess which of the three it is
      // looking at.
      expect(
        census.liveTickers,
        0,
        reason:
            'THE GATE. A dock tab the reader cannot see must schedule NO '
            'frames.\n'
            'MEASURED, on the /journey tab: ${census.describe()}, and the '
            'home tab\'s selah ring advanced $frozen → $moved.\n'
            'The ring is the offender: the tree carries exactly one ticker '
            'over the ambient, and the ring — and only the ring — is '
            'demonstrably still being ticked. Its `AnimationController` '
            '`repeat()`s for as long as the card is mounted '
            '(lib/features/home/presentation/widgets/selah_card.dart:595, the '
            'ring mounted unconditionally at :484, the per-frame '
            '`AnimatedBuilder` at :621).\n'
            'THE CAUSE is that auto_route 11.2.0\'s `AutoTabsRouter` keeps '
            'the three tabs alive in one `IndexedStack` and wraps the '
            'inactive children in `ExcludeSemantics` and `ExcludeFocus` ONLY '
            '(auto_route-11.2.0/lib/src/router/widgets/auto_tabs_router.dart'
            ':482-488). It emits NO `TickerMode` — the string does not occur '
            'anywhere in auto_route 11.2.0 — so nothing mutes the ring\'s '
            'ticker, and it keeps asking the scheduler for frames behind a '
            'tab the reader is not on.\n'
            'THE FIX is to mute the inactive tab, the way Flutter\'s own '
            '`TabBarView` and `PageView` do — a `TickerMode(enabled: false)` '
            'around each inactive child. A muted ticker is not scheduled and '
            'not counted (ticker.dart:270), so that fix turns this row green '
            'without touching the instrument. DO NOT weaken the budget.',
      );
      expect(
        census.framesScheduled,
        0,
        reason:
            'THE GATE, in frames. Over a fixed one-second window the '
            'scheduler produced ${census.framesScheduled} frames while the '
            'reader was on the /journey tab, and every one of them was the '
            'home tab\'s selah ring still breathing behind an invisible tab.\n'
            'The window is pumped EXPLICITLY and never settled: '
            '`pumpAndSettle` times out against a repeating ticker, and that '
            'timeout is this same defect seen from the other side. The '
            'expectation is ZERO and not "few" — a tab that is off screen '
            'and asking for a frame is a tab that is costing the reader '
            'battery and the frame budget for nothing.',
      );
      expect(
        moved,
        frozen,
        reason:
            'the home tab\'s selah ring is still advancing while the reader '
            'is on the /journey tab ($frozen → $moved). Its '
            '`AnimationController` is still being ticked, so the ring is '
            'still scaling and still casting its `BoxShadow` '
            '(selah_card.dart:640-666) — sixty times a second, for a control '
            'nobody can see. The same `TickerMode` that the count above '
            'needs fixes this one.',
      );
    });
  });

  group('the app\'s own tree, with the ambient running', () {
    // ## WHY THE LAST GROUP EXISTS
    //
    // The gate above holds the ambient's two clocks still, so that "zero" is
    // a reachable number. This group is the **production** shape of the same
    // claim, and it is here so that a reader is never left thinking the
    // gate's configuration is the app's configuration. It is not a different
    // claim: the ambient is a constant on every tab, so the ring's excess is
    // the same excess.

    testWidgets('the ambient is a constant, and the ring is not', (
      WidgetTester tester,
    ) async {
      final AppRouter router = _router();
      final Widget host = routerHost(router);

      // The ambient's own contribution, **measured rather than assumed**: a
      // scope with nothing under it. This is the number the app's own two
      // clocks make.
      await tester.pumpWidget(
        const NeuralMotionScope(child: SizedBox.shrink()),
      );
      await tester.pump();
      final int ambient = liveTickerCount;
      expect(
        ambient,
        greaterThan(0),
        reason:
            'the ambient scope owns the app\'s two shared clocks, and they '
            'are running. A zero here means the measurement is wrong, not '
            'that the app is quiet',
      );

      await tester.pumpWidget(host);
      await pumpUntilFound(tester, find.byType(LumenDock));
      await _settle(tester);
      final int onHome = liveTickerCount;

      await tester.tap(find.text('Journey'));
      await pumpUntilFound(tester, find.byType(JourneyPage));
      await _settle(tester);
      final int onJourney = liveTickerCount;

      expect(
        onHome - ambient,
        1,
        reason:
            'on the home tab the ring is the visible tab\'s own, so the tree '
            'carries exactly one ticker over the ambient',
      );
      expect(
        onJourney - ambient,
        0,
        reason:
            'THE GATE, in the app\'s own configuration. On the /journey tab '
            'the tree must carry NO ticker over the ambient — the journey '
            'tab owns none of its own (its rings row is a one-shot entrance '
            'that has finished) — and it carries ${onJourney - ambient}.\n'
            'MEASURED: the ambient alone is $ambient live ticker(s), the '
            'shell on the home tab is $onHome, and the shell on the '
            '/journey tab is $onJourney.\n'
            'The cause and the fix are the ones the gate above names: '
            'auto_route 11.2.0\'s `AutoTabsRouter` emits no `TickerMode` for '
            'the inactive children (auto_tabs_router.dart:482-488), so '
            'nothing mutes them, and the home tab\'s selah ring '
            '(lib/features/home/presentation/widgets/selah_card.dart:595) '
            'keeps repeating behind a tab the reader is not on.',
      );
    });
  });
}
