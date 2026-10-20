import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The dock shell — the app's **tab host**.
///
/// ## WHY IT LIVES IN `lib/app/` AND NOT IN A FEATURE
///
/// Because it must name **all three** of the tab routes, and a feature may not
/// import another feature (AGENT_CONTEXT §3). `features/dock/` is a feature, and
/// `HomeRoute` / `CommunionRoute` / `JourneyRoute` are three different features'
/// routes. `lib/app/` is the one directory the architecture exempts from that
/// rule, because reaching into features to wire them up is the composition
/// root's whole job — and this file *is* composition: it is where three screens
/// become three tabs.
///
/// The alternative — an `AutoTabsRouter` inside `features/home/` — would have made
/// the home feature import the board's and the journey's routes, and §3 has no
/// exceptions.
///
/// ## WHY THE ROUTES ARE NAMED HERE AND NOT DERIVED
///
/// `AutoTabsRouter(routes: null)` would derive the children from the router's
/// route collection, and it would work. It is **not** used, because the derived
/// list is `routeCollection.routes.map((e) => PageRouteInfo(e.name))` — a list
/// built from *names*, in *declaration order*, with no way to say which route is
/// which. The tab order is load-bearing here: it is the order the dock's three
/// real slots switch in, and the order [DockTabs] names. An explicit list says
/// it, and a test can read it.
///
/// ## THE DOCK'S FIVE SLOTS ARE NOT FIVE TABS
///
/// The prototype's dock has five slots (`eva/redesign.html:702-708`) and the
/// prototype's `TABMAP` (`:1248`) maps **four** of them onto screens: `home`,
/// `read`, `today` and `board` and `journey` — with `read` and `today` being
/// **push actions** (`:1277-1279` opens the reader and the quiz rather than
/// switching a tab).
///
/// So the client has **three** tabs and **two** push actions, and the dock
/// carries all five slots. The active marker therefore maps a *tab index* to a
/// *slot index* — see [_slotForTab] — because the two numbering schemes are not
/// the same, and the prototype's own `TABMAP` is the evidence that they are not:
/// the board is slot 3 and tab 1.
///
/// ## THE DOCK HIDES ON THE READER, THE QUIZ AND THE WORKSHOP
///
/// Not by a rule — by **geometry**. The dock is inside the shell, and the reader,
/// the quiz and the workshop are root-level routes pushed **over** the shell, so
/// pushing one covers the shell and the dock with it. The prototype does it with
/// a class (`:1251` — the dock is visible on `home`, `journey` and `board` only)
/// and slides the dock away (`.dock.hide`, `:215`); here it is covered, which is
/// the same observable outcome and a different mechanism. Recorded in
/// AGENT_CONTEXT.
@RoutePage()
class DockShellPage extends StatelessWidget {
  /// Creates the shell. It takes nothing: the shell is a piece of chrome, and
  /// every destination it offers is a route the router already owns.
  const DockShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: <PageRouteInfo>[HomeRoute(), CommunionRoute(), JourneyRoute()],
      // The home tab is the one a back gesture returns to, so `maybePop()` on the
      // tabs router switches to it instead of leaving the shell. auto_route's
      // `TabsRouter.maybePop` does exactly that when `homeIndex` is set
      // (`routing_controller.dart:745`).
      homeIndex: DockTabs.home,
      // The prototype's `tab-pre` pose: the incoming tab rises 10px and scales
      // from 0.985. See `EvaMotion.tabSwap` for the one part of the prototype's
      // tab transition that auto_route's model cannot show.
      transitionBuilder: EvaMotion.tabSwap,
      builder: (BuildContext context, Widget child) {
        final TabsRouter tabs = AutoTabsRouter.of(context);

        return Stack(
          // `expand`, so the tab content fills the shell rather than taking the
          // `Stack`'s loose constraints — a `NeuralScaffold` under loose
          // constraints would size itself to its content.
          fit: StackFit.expand,
          children: <Widget>[
            child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LumenDock(
                items: _items(context),
                activeIndex: _slotForTab(tabs.activeIndex),
                onSelect: (int slot) => _select(context, tabs, slot),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The five slots, in the prototype's order.
  ///
  /// `eva/redesign.html:703-707` — home, read, today, board, journey. The
  /// labels are the redesign's own `dockHome` / `dockRead` / `dockToday` /
  /// `dockBoard` / `dockJourney` (`:931-932`).
  ///
  /// **The four line icons are Material's, and that is a recorded
  /// substitution.** The prototype draws them as inline SVG (`:703`, `:704`,
  /// `:706`, `:707`); `flutter_svg` is not an approved dependency (AGENT_CONTEXT
  /// §8.4) and hand-transcribing path data would be inventing coordinates —
  /// the failure AGENT_CONTEXT decision 18 recorded for the social marks. The
  /// Material outlines are the same four objects drawn as outlines, at the
  /// prototype's 20px box, and the dock's *structure* — five slots, this order,
  /// this active marker — is what the prototype's own code is about.
  List<LumenDockItem> _items(BuildContext context) => <LumenDockItem>[
    LumenDockItem(
      label: context.l10n.dockHome,
      glyph: const Icon(Icons.home_outlined, size: _iconSize),
    ),
    LumenDockItem(
      label: context.l10n.dockRead,
      glyph: const Icon(Icons.auto_stories_outlined, size: _iconSize),
    ),
    LumenDockItem(label: context.l10n.dockToday, glyph: const LumenOrb()),
    LumenDockItem(
      label: context.l10n.dockBoard,
      glyph: const Icon(Icons.emoji_events_outlined, size: _iconSize),
    ),
    LumenDockItem(
      label: context.l10n.dockJourney,
      glyph: const Icon(Icons.person_outline, size: _iconSize),
    ),
  ];

  /// The dock's line icons are 20 × 20.
  ///
  /// `eva/redesign.html:219` — `.dic{width:20px;height:20px;…}`.
  static const double _iconSize = 20;

  /// The dock slot that is active for [tabIndex], or `-1` for none.
  ///
  /// The two numbering schemes are different, and the prototype's own `TABMAP`
  /// (`:1248`) is the evidence: the board is **slot 3** and **tab 1**.
  static int _slotForTab(int tabIndex) => switch (tabIndex) {
    DockTabs.home => 0,
    DockTabs.communion => 3,
    DockTabs.journey => 4,
    _ => -1,
  };

  /// What a slot does when it is tapped.
  ///
  /// Three slots switch tabs; two **push** a root route over the shell, which
  /// is what hides the dock (the prototype's `read` and `today` slots, `:1277`
  /// and `:1278`, push the reader and the quiz rather than switching).
  void _select(BuildContext context, TabsRouter tabs, int slot) {
    // **A switch expression, not a statement.** The arms are side effects with
    // two different shapes — a tab switch and a route push — so the expression
    // produces the action and the statement performs it.
    final VoidCallback action = switch (slot) {
      0 => () => tabs.setActiveIndex(DockTabs.home),
      1 => () => unawaited(context.router.root.pushPath(AppRoutes.reading)),
      2 => () => unawaited(context.router.root.pushPath(AppRoutes.quiz)),
      3 => () => tabs.setActiveIndex(DockTabs.communion),
      4 => () => tabs.setActiveIndex(DockTabs.journey),
      _ => throw ArgumentError.value(slot, 'slot', 'the dock has five slots'),
    };
    action();
  }
}
