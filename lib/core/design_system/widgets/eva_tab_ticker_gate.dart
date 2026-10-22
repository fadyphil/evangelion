import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// Mutes the tickers of a **dock tab the reader cannot see**.
///
/// ## THE DEFECT THIS EXISTS FOR
///
/// The dock shell's three tabs live in auto_route's `_AutoTabsRouterIndexedStack`,
/// which builds a Flutter `IndexedStack` with `index: widget.activeIndex` and
/// children `KeepAliveTab(key: ValueKey(index), page: stack[index])`
/// (`auto_route-11.2.0/lib/src/router/widgets/auto_tabs_router.dart:462-495`).
///
/// **auto_route 11.2.0 emits NO `TickerMode`.** The string `TickerMode` does not
/// occur anywhere in `auto_route-11.2.0/lib/` — measured, not recalled — and the
/// inactive children get only `ExcludeSemantics` and `ExcludeFocus`
/// (`:482-488`). Flutter's own `IndexedStack` does not add one either: it wraps
/// each child in a `_VisibilityScope` (an `InheritedWidget` with no render
/// object) and an `ExcludeFocus`, and leaves the painting to
/// `RenderIndexedStack` (`flutter/lib/src/widgets/indexed_stack.dart`).
///
/// So an inactive tab stays **mounted and animating**. The home tab's selah
/// ring repeats for as long as the card is mounted
/// (`lib/features/home/presentation/widgets/selah_card.dart:595` — the
/// `_controller.repeat()`, the ring mounted unconditionally at `:484`, the
/// per-frame `AnimatedBuilder` at `:621`), and it kept breathing behind a tab
/// the reader was not on: **one live ticker over the ambient, and sixty frames
/// in a one-second window, on a screen the reader cannot see.** The gate for
/// that is `test/ticker_census_test.dart`.
///
/// ## WHY A `TickerMode` AND NOT "STOP THE CONTROLLER"
///
/// Because a muted ticker's **clock keeps running**. `Ticker.muted`'s setter
/// only unschedules the tick — it does not stop the ticker, and it does not
/// null `_startTime` (`flutter/lib/src/scheduler/ticker.dart:119-131`). The
/// framework says so in words: *"Animations driven by such tickers are not
/// paused, they just don't call their callbacks. **Time still elapses.**"*
/// (`flutter/lib/src/widgets/ticker_provider.dart`).
///
/// So the ring's value when the reader comes back is **exactly where it would
/// have been** had it kept breathing — which is the same place the *unmuted*
/// tree would have put it. **Stopping** the controller instead would reset the
/// animation's phase, and a phase reset **is** a visual change. `TickerMode` is
/// the only one of the two that changes no pixel.
///
/// ## AND WHY **NO PIXEL** CHANGES AT ALL
///
/// Because an `IndexedStack` **paints only the active child**
/// (`RenderIndexedStack`; and this repository's own motion table says so in
/// its own words — `lib/core/design_system/tokens/eva_motion.dart`: *"an
/// `IndexedStack` paints **only the active child**. The outgoing tab is not on
/// screen while the swap runs, so there is nothing to give a pose to"*). The
/// outgoing tab is not painted during the 400 ms swap, so muting it cannot
/// change a pixel.
///
/// ## WHY THE LOOKUP IS **NULLABLE**
///
/// `TabsRouterScope.of` returns `null` when there is no tabs router above the
/// context (`auto_route-11.2.0/lib/src/router/controller/controller_scope.dart:
/// 159-164`) and it does not throw. `AutoTabsRouter.of` **does** throw — it is
/// wrapped in an `assert` that fires in debug
/// (`auto_route-11.2.0/lib/src/router/widgets/auto_tabs_router.dart:150-163`).
///
/// That matters because the three tab pages are pumped **standalone** by many
/// existing suites (`test/support/home_harness.dart`'s `pumpHome`,
/// `test/features/leaderboard/presentation/communion_page_test.dart`, and the
/// journey's own harness), and a standalone page has no tabs router above it.
/// **A standalone page is not muted**: this widget returns [child] unchanged,
/// so there is no `TickerMode` in the tree at all and the page behaves exactly
/// as it did before this widget existed.
///
/// ## WHY A `ListenableBuilder` AND NOT `TabsRouterScope.of(context, watch: true)`
///
/// Because the scope's `updateShouldNotify` compares `stateHash`
/// (`controller_scope.dart:167-169`), and `stateHash` is
/// `const ListEquality().hash(_addedSegments) ^ pageCount`
/// (`routing_controller.dart:393`) — it describes the **route segments**, not
/// the active tab, so it does **not** change on a tab switch. A dependent
/// lookup on the scope would therefore not rebuild on the one event this
/// widget exists for.
///
/// `TabsRouter` is a `ChangeNotifier` (`routing_controller.dart:50`, `:634`),
/// `activeIndex` is the live index (`:699`) and `setActiveIndex` notifies
/// (`:705`). So the widget **listens to the router** and reads `activeIndex`
/// inside the builder. The scope is still read — once, for the router it
/// carries — but it is read with the **non-dependent** lookup, so the gate
/// itself never rebuilds for the scope's reasons.
///
/// ## AND WHY THE **CHILD** IS PASSED THROUGH UNCHANGED
///
/// `ListenableBuilder`'s `child` is handed to the builder, and the builder's
/// result is the only thing that changes. The page's own subtree is therefore
/// the **same widget instance** on every rebuild, and Flutter's
/// `Element.update` short-circuits on an identical widget — so **a tab switch
/// does not rebuild the page**. The gate costs one `TickerMode` and nothing
/// else, which is the property `test/rebuild_isolation_budget_test.dart`
/// holds for the rest of the tree.
///
/// ## AND WHY THE **DOCK** IS NOT MUTED
///
/// Because the dock is not in a tab. It lives in the shell's own `builder:`
/// wrapper, beside the `IndexedStack` and outside every page, so it is
/// visible on every tab and must keep animating on every tab.
///
/// ## WHY THE DESIGN SYSTEM MAY IMPORT `package:auto_route`
///
/// Because the alternative is worse, and it is worse in a way the architecture
/// can name. `lib/core/navigation/` is **pure Dart** — Gate 1 forbids Flutter
/// there — so the gate cannot live beside `DockTabs`, which is the one place
/// the tab indices are published. `lib/core/design_system/` is the shared
/// presentation surface every layer may import, and it already reaches a
/// non-framework package: `motion/eva_animate.dart` imports
/// `package:flutter_animate/flutter_animate.dart`.
///
/// The alternative — each of the three pages doing the lookup itself — would
/// put `package:auto_route` into three feature files instead of one, and
/// would copy the same seven lines three times. One widget, one import, one
/// place to look.
class EvaTabTickerGate extends StatelessWidget {
  /// Creates the gate for the tab at [tabIndex].
  const EvaTabTickerGate({
    required this.tabIndex,
    required this.child,
    super.key,
  });

  /// The index of the tab this widget is the content of.
  ///
  /// One of `DockTabs`' three — `home`, `communion`, `journey` — and the
  /// numbers are the shell's own (`lib/core/navigation/dock_tabs.dart`).
  final int tabIndex;

  /// The tab's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // **The nullable lookup, and it is the whole reason this widget is safe on
    // a standalone page.** `AutoTabsRouter.of` asserts; this returns null.
    final TabsRouterScope? scope = TabsRouterScope.of(context);
    if (scope == null) {
      // No tabs router: the page is being pumped on its own. Nothing to mute,
      // and — deliberately — **no `TickerMode` in the tree at all**, so a
      // standalone page renders exactly as it did before this widget existed.
      return child;
    }
    final TabsRouter router = scope.controller;
    return ListenableBuilder(
      // **The router, not the scope.** The scope's `stateHash` describes the
      // route segments and does not change on a tab switch; the router's
      // `activeIndex` is the fact this widget is about.
      listenable: router,
      // The child is passed through, so a tab switch does not rebuild the page.
      child: child,
      builder: (BuildContext context, Widget? inner) => TickerMode(
        enabled: router.activeIndex == tabIndex,
        child: inner ?? child,
      ),
    );
  }
}
