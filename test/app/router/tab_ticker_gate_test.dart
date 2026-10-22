/// The dock shell's **tab ticker gate** — `EvaTabTickerGate`.
///
/// ## WHAT THIS FILE CLAIMS
///
/// **A dock tab the reader cannot see must not be animating**, and the claim
/// is made three ways, because a claim made one way is a claim that can be
/// satisfied for the wrong reason:
///
/// 1. **Behaviourally** — the home tab's selah ring *freezes* while the reader
///    is on another tab, and *resumes* when the reader comes back. The ring's
///    own `AnimationController` is the witness, read off the widget.
/// 2. **Structurally** — exactly one of the shell's tab gates is muted at a
///    time, and it is the invisible one.
/// 3. **Negatively** — a page pumped **on its own** has no tabs router above
///    it, and is therefore **not muted at all**: no `TickerMode` is inserted
///    into its tree, and the ring keeps breathing.
///
/// ## WHY IT IS NOT THE CENSUS
///
/// `test/ticker_census_test.dart` owns the **budget**: "an inactive tab
/// schedules nothing", counted over the whole tree with the ambient held
/// still. This file owns the **mechanism**: which widget does the muting,
/// which tab it applies to, and what happens to a page that is not in the
/// shell at all. A budget with no mechanism test can be satisfied by a
/// different mechanism; a mechanism test with no budget can be satisfied by a
/// mechanism that does not actually stop anything.
///
/// ## AND WHY THE **TAB SWAP** IS HERE
///
/// Because muting a tab is a change to the shell's behaviour, and the shell's
/// behaviour includes the 400 ms tab transition the redesign specifies
/// (`eva/redesign.html:128` — `transition:transform .4s …`). A fix that
/// silenced the transition as a side effect would be a fix that changed a
/// pixel, and this file is where that would be caught.
library;

import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/design_system/widgets/eva_tab_ticker_gate.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/home_harness.dart';

/// How long each step of the settle window advances the clock.
///
/// Six half-second steps is three seconds — long enough for the shell's 400 ms
/// tab transition and the board's own entrance to finish, so that what is
/// left alive is what is alive on purpose.
const Duration _settleStep = Duration(milliseconds: 500);

/// How many steps the settle window runs.
const int _settleSteps = 6;

/// Lets the tree's one-shot animations finish.
Future<void> _settle(WidgetTester tester) async {
  for (int step = 0; step < _settleSteps; step++) {
    await tester.pump(_settleStep);
  }
}

/// The router the shell runs on.
AppRouter _router() {
  final AppRouter router = AppRouter(
    FakeAuthStatus(),
    ManualAuthChanges(),
    testRoleAccess(),
  );
  addTearDown(router.dispose);
  return router;
}

/// The selah ring's own controller.
///
/// Reached through the `AnimatedBuilder` that drives it
/// (`selah_card.dart:621`), because the controller is a private field of a
/// private state class and there is no other door into it.
///
/// **It has to be taken while the card is ON STAGE.** Flutter's `IndexedStack`
/// reports only its selected child as on-stage
/// (`flutter/lib/src/widgets/indexed_stack.dart` —
/// `_IndexedStackElement.debugVisitOnstageChildren`), and the default finder
/// skips off-stage widgets — so once the reader has left the home tab the
/// card is still *mounted* but the finder cannot see it. That is a fact about
/// the finder, not about the tree, and the tree is what this file measures.
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

/// Every `TickerMode` inside the shell's tab gates, **off-stage ones included**.
///
/// The off-stage half matters: the gate of the tab the reader is *not* on is
/// exactly the one whose `enabled` is `false`, and the default finder skips
/// it.
List<TickerMode> _gateModes(WidgetTester tester) => tester
    .widgetList<TickerMode>(
      find.descendant(
        of: find.byType(EvaTabTickerGate, skipOffstage: false),
        matching: find.byType(TickerMode, skipOffstage: false),
      ),
    )
    .toList();

/// A leaf with one repeating controller — the "alive" half of the control.
class _Breathing extends StatefulWidget {
  const _Breathing({super.key});

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  /// The controller under test.
  late final AnimationController controller;

  /// Builds the controller **here**, and not as a `late final` field
  /// initialiser: a `late final` initialiser runs on the first *read* of the
  /// field, and this widget's `build` never reads it — so the controller would
  /// never be created, there would be no ticker, and the control would measure
  /// a tree that had never animated.
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

void main() {
  group('the gate on a page with no tabs router', () {
    testWidgets('inserts no TickerMode at all, and mutes nothing', (
      WidgetTester tester,
    ) async {
      final GlobalKey<_BreathingState> key = GlobalKey<_BreathingState>();

      await tester.pumpWidget(
        MaterialApp(
          home: EvaTabTickerGate(
            tabIndex: DockTabs.home,
            child: _Breathing(key: key),
          ),
        ),
      );
      await tester.pump();

      // **The landmark, before the measurement.** A gate that threw would leave
      // an empty tree, and an empty tree satisfies "nothing is muted" for the
      // wrong reason.
      expect(
        find.byType(_Breathing),
        findsOneWidget,
        reason: 'the gated child has to be in the tree',
      );

      expect(
        find.descendant(
          of: find.byType(EvaTabTickerGate),
          matching: find.byType(TickerMode),
        ),
        findsNothing,
        reason:
            'a page pumped on its own has no tabs router above it, so the gate '
            'has nothing to mute and inserts no TickerMode at all. This is '
            'what keeps the standalone page suites — `pumpHome`, the board\'s '
            'own suite, the journey\'s — rendering exactly as they did before '
            'the gate existed',
      );

      final double before = key.currentState!.controller.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        key.currentState!.controller.value,
        isNot(before),
        reason: 'a standalone page is NOT muted — its animation runs',
      );
    });

    testWidgets('and the real home page, pumped bare, is not muted either', (
      WidgetTester tester,
    ) async {
      final HomeHarness home = harness();
      await pumpHome(tester, bloc: home.bloc);

      expect(
        find.byType(HomePage),
        findsOneWidget,
        reason: 'the page has to be in the tree',
      );
      expect(
        find.descendant(
          of: find.byType(EvaTabTickerGate),
          matching: find.byType(TickerMode),
        ),
        findsNothing,
        reason:
            '`pumpHome` mounts the page over a bare harness, with no tabs '
            'router above it, so the gate is inert and the tree is unchanged',
      );
    });
  });

  group('the gate inside the dock shell', () {
    testWidgets('the visible tab animates, the invisible one does not, and it '
        'comes back', (WidgetTester tester) async {
      final AppRouter router = _router();

      await tester.pumpWidget(routerHost(router));
      await pumpUntilFound(tester, find.byType(LumenDock));
      await _settle(tester);

      // **The ring is captured while the home tab is ON STAGE.**
      final AnimationController ring = _selahRing(tester);

      // ## THE ACTIVE TAB
      //
      // The home tab is the one on screen, so its ring is the visible tab's
      // own and it must keep breathing.
      final double onHome = ring.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        ring.value,
        isNot(onHome),
        reason:
            'the home tab is the VISIBLE tab, so its selah ring animates. A '
            'gate that muted the active tab would freeze the control the '
            'reader is looking at',
      );

      // ## THE INACTIVE TAB
      //
      // The reader leaves for the board. The shell's 400 ms tab transition and
      // the board's own entrance are one-shot and are let to finish.
      await tester.tap(find.text('Communion'));
      await pumpUntilFound(tester, find.byType(CommunionPage));
      await _settle(tester);

      final double frozen = ring.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        ring.value,
        frozen,
        reason:
            'the home tab is INVISIBLE now, so its ring must not advance. The '
            'value is the ring\'s own controller\'s, so this is the ring that '
            'is frozen and not a count of something else',
      );

      // ## AND IT COMES BACK
      await tester.tap(find.text('Home'));
      await pumpUntilFound(tester, find.byType(HomePage));
      await _settle(tester);

      final double resumed = ring.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        ring.value,
        isNot(resumed),
        reason:
            'the reader is back on the home tab, so the ring animates again. '
            'A `TickerMode` that could not be undone would leave the ring '
            'frozen for the rest of the session',
      );
    });

    testWidgets('exactly one gate is muted, and it is the invisible one', (
      WidgetTester tester,
    ) async {
      final AppRouter router = _router();

      await tester.pumpWidget(routerHost(router));
      await pumpUntilFound(tester, find.byType(LumenDock));
      await _settle(tester);

      // ## ON THE HOME TAB
      //
      // One tab is mounted (auto_route's tabs router is lazy), and it is the
      // visible one, so its gate is enabled.
      final List<TickerMode> onHome = _gateModes(tester);
      expect(
        onHome,
        hasLength(1),
        reason: 'only the home tab is mounted so far',
      );
      expect(
        onHome.single.enabled,
        isTrue,
        reason: 'the visible tab is never muted',
      );

      // ## ON THE BOARD
      await tester.tap(find.text('Communion'));
      await pumpUntilFound(tester, find.byType(CommunionPage));
      await _settle(tester);

      final List<TickerMode> onBoard = _gateModes(tester);
      expect(
        onBoard,
        hasLength(2),
        reason: 'the home tab stays mounted, so both gates are in the tree',
      );
      expect(
        onBoard.where((TickerMode mode) => !mode.enabled),
        hasLength(1),
        reason:
            'exactly one gate is muted — the home tab, which the reader cannot '
            'see. Two muted gates would mean the visible one was muted too',
      );
      expect(
        onBoard.where((TickerMode mode) => mode.enabled),
        hasLength(1),
        reason: 'and the board\'s own gate is enabled, because it is on screen',
      );
    });

    testWidgets('the tab swap still runs, and it still takes 400ms', (
      WidgetTester tester,
    ) async {
      final AppRouter router = _router();

      await tester.pumpWidget(routerHost(router));
      await pumpUntilFound(tester, find.byType(LumenDock));

      await tester.tap(find.text('Communion'));
      await tester.pump();

      // **The swap's own animation**, read off the builder auto_route hands it
      // to (`EvaMotion.tabSwap` is the shell's `transitionBuilder`, and it
      // wraps the whole `IndexedStack`). It is the innermost `AnimatedBuilder`
      // above the page, because the gate's own `ListenableBuilder` is a
      // different type and does not match.
      final AnimatedBuilder swap = tester.widget<AnimatedBuilder>(
        find
            .ancestor(
              of: find.byType(CommunionPage),
              matching: find.byType(AnimatedBuilder),
            )
            .first,
      );
      final Animation<double> animation = swap.animation as Animation<double>;

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        animation.value,
        greaterThan(0.0),
        reason: 'the swap is running — it has started',
      );
      expect(
        animation.value,
        lessThan(1.0),
        reason:
            'the swap is 400ms (`EvaMotion.tabTransition`, from '
            '`eva/redesign.html:128`), so at 200ms it is half way and NOT over',
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        animation.value,
        1.0,
        reason:
            'and it is over at 400ms. A swap that finished early, or a router '
            'whose `duration` had been dropped, would fail here',
      );
    });
  });
}
