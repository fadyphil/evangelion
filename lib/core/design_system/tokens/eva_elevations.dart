/// The Eva elevation scale — flat, everywhere.
///
/// ## THIS FILE IS A DOCUMENTED GAP, NOT A SPEC TRANSCRIPTION
///
/// `docs/plans/03-design-system.md` has **no elevation table**. §5.1 gives the
/// colour tokens, §5.2 the families, §5.3 the spacing, radii and motion, §5.4
/// the extension. Nothing anywhere in the spec — or in the React prototype §5.1
/// was extracted from — defines a z-axis: every `box-shadow` in the prototype is
/// either an `ember` glow or the single glass ambient that became
/// `EvaColors.glassShadow`.
///
/// So this file records the one value that can be stated without inventing a
/// ramp: **no Material elevation anywhere**. Layering in this design system is
/// carried by three tokens the spec *does* define:
///
/// - `line` — "the hairline colour" (§5.1). A 1px border is the separator.
/// - `glassFill` / `glassBorder` — the tint and rim of a `GlassSurface` (§5.4).
/// - `glassShadow` — the one ambient shadow, and it belongs to the glass
///   treatment rather than to a z-index.
///
/// Only the six surfaces Material still exposes an `elevation` for are named.
/// `MenuThemeData` in Flutter 3.47 has just `style` and `submenuIcon` — there is
/// no elevation to zero — so a menu token here would be a number nothing reads.
///
/// ## WHY THIS MATTERS MECHANICALLY
///
/// Material's own defaults are non-zero for every surface below: a `Card`
/// falls back to 1, a `Drawer` to 16, a `PopupMenuButton` to 8, a
/// `FloatingActionButton` to 6, and a *modal* bottom sheet to 24. A component
/// theme that does not consult this class therefore ships a drop shadow the
/// design system does not have — and on a near-black canvas a stock Material
/// shadow is not a subtle default, it is a visible grey smear. So
/// `theme/eva_theme.dart` consults this class for all of them, `none` included.
///
/// ## WHAT THE TESTS CAN AND CANNOT SEE — READ THIS BEFORE BELIEVING THEM
///
/// An earlier version of this file claimed that
/// `test/core/design_system/theme/eva_theme_test.dart` "asserts the wiring",
/// and that was an overclaim that survived a mutation audit.
///
/// Every token here is `0`. So `elevation: EvaElevations.card` and
/// `elevation: 0` compile to the *same program*: `EvaElevations.card` is the
/// canonicalised `double` zero, and the theme reads a `double`. There is no
/// run-time observable that distinguishes reading the token from writing the
/// literal, because there is nothing to distinguish — the two expressions are
/// the same value, and any test asserting otherwise would be asserting that two
/// identical programs differ. A sentinel would need a parameter that production
/// code could pass wrongly in order to be testable, which trades a documentation
/// weakness for a real API hazard.
///
/// What the suite therefore asserts, and it is worth something:
/// **every elevation-bearing `ThemeData` field resolves to `0`.** That has real
/// teeth against the failures that can actually happen — deleting the line lets
/// `null` through, and pinning Material's own default passes it straight
/// through — and it is checked over an *enumerated inventory* of the fields, so a
/// new themed surface that forgets this class is caught rather than shipped.
/// What it cannot see is whether the zero was written as `0` or read from here.
/// That is stated in the test rather than glossed over.
///
/// If a real elevation ramp is ever wanted, it needs a spec table first — see the
/// gap noted in the Phase 1 report — and with a ramp in place this whole problem
/// disappears, because the values stop being interchangeable.
abstract final class EvaElevations {
  /// `0` — the absence of elevation. Also what a component theme uses when it
  /// should be as flat as the surface behind it.
  ///
  /// Not a seventh tier of anything. It is the same zero, applied to the
  /// surfaces §5 names no role for — drawer, popup menu, bottom bar, navigation
  /// bar, modal bottom sheet — so that a component arriving in Phase 3 does not
  /// begin its life casting Material's stock shadow. It had zero readers before
  /// the Phase 1 review flagged it, which made it documentation rather than
  /// policy; `theme/eva_theme.dart` now consults it and the inventory in
  /// `eva_theme_test.dart` checks every field it was applied to.
  static const double none = 0;

  /// `0` — cards sit on the canvas behind a `line` hairline, not above it.
  static const double card = 0;

  /// `0` — the reading sanctuary is specified as "zero chrome"; its app bar is a
  /// hairline and a title, not a raised bar.
  static const double appBar = 0;

  /// `0` — a dialog is a `GlassSurface` over a scrim, tinted rather than lifted.
  static const double dialog = 0;

  /// `0` — a bottom sheet is separated by its rounded top edge and its scrim.
  static const double bottomSheet = 0;

  /// `0` — the FAB dock's buttons are tinted glass; an ember glow (see the
  /// prototype's `0 0 28px rgba(ember, .35)`) is a *border effect*, not an
  /// elevation, and it is Phase 3's `SealFab` that draws it.
  static const double floatingActionButton = 0;

  /// `0` — a snack bar is a glass panel like every other raised surface.
  static const double snackBar = 0;
}
