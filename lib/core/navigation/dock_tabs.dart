/// The three **real tabs** of the dock shell, by index.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A CONSTANT ON THE SHELL
///
/// `lib/app/router/dock_shell_page.dart` is the composition root's file, and a
/// feature may not import it — not because of Gate 2, which exempts `lib/app/`,
/// but because a feature reaching into the composition root is the dependency
/// direction the whole architecture is built against. The board's own "open the
/// board" row and the journey's own rows both need to name a tab, and they are
/// features.
///
/// So the **indices** live here, in the same place as [AppRoutes]: pure Dart, in
/// `core/navigation/`, read by more than one layer.
///
/// ## WHY INDICES AT ALL
///
/// Because auto_route's tab API is an index: `TabsRouter.setActiveIndex(int)`.
/// There is no name-based equivalent, and a path is not one either — the tab
/// routes are matched as *children* of the shell, and their paths are relative
/// (`AppRoutes.communionTab`), so `/communion` is not a path the tabs router
/// matches on its own.
///
/// ## THE ORDER IS LOAD-BEARING, AND A TEST PINS IT
///
/// The order here is the order of the shell's `routes:` list, and the dock's
/// three real slots switch in that order. `app_router_test.dart` asserts that
/// the shell's children are home, communion, journey **in that order**, so the
/// two cannot drift apart without a test going red.
abstract final class DockTabs {
  /// The home tab — the first, and the one a back gesture returns to.
  static const int home = 0;

  /// The cohort's board — the second.
  static const int communion = 1;

  /// The reader's journey — the third.
  static const int journey = 2;

  /// How many tabs there are.
  static const int count = 3;
}
