import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/eva_elevations.dart';
import 'package:evangelion/core/design_system/tokens/eva_radii.dart';
import 'package:evangelion/core/design_system/tokens/eva_typography.dart';
import 'package:flutter/material.dart';

/// Assembles a [ThemeData] from an [EvaColors] palette.
///
/// One function, two palettes. `eva_theme_dark.dart` and `eva_theme_light.dart`
/// call it with [EvaColors.dark] and [EvaColors.light] respectively and nothing
/// else, so the two themes cannot drift: every field set here is set for both,
/// and a field only one of them set would be a bug in this file rather than in
/// the instance files.
///
/// ## WHY THERE IS A [ColorScheme] AT ALL
///
/// `docs/plans/03-design-system.md` §5.1 does not describe a `ColorScheme` — it
/// describes fourteen tokens, and `ColorScheme` has around forty fields. So every
/// field below is either (a) named directly by a token, or (b) left unset so
/// Material falls back to its own default, which is the only way to avoid
/// freezing a colour nobody chose. The mapping is annotated field by field
/// because a bare `ColorScheme(...)` with forty positional guesses would be
/// unreadable and unreviewable.
///
/// ## WHAT IS DELIBERATELY NOT SET
///
/// - `scrim`. Material's default is opaque black, which is the right scrim in
///   both brightnesses. Neither Eva token is: `canvas` is near-black in dark but
///   a pale lavender in light, where a scrim would be a white wash rather than a
///   dim.
/// - `surfaceBright`. The three surface tokens give three levels
///   (`canvas` < `surface` < `raised` in dark) and Material wants five. Leaving
///   this unset resolves it to `surface`, which is the correct answer for the
///   light palette (its `surface` *is* the brightest surface) and a deliberately
///   conservative one for the dark palette. Inventing a fifth level is exactly
///   the kind of token this phase is told not to invent.
/// - `primaryFixedDim` and friends. The `*Fixed` roles exist for dynamic colour,
///   which this app does not use (settings are local-only, AGENT_CONTEXT §2).
abstract final class EvaTheme {
  /// Builds the theme for [colors].
  ///
  /// Brightness is read from the palette rather than passed in, so a theme
  /// cannot be assembled with a brightness that disagrees with its colours.
  ///
  /// No `useMaterial3` argument: it is deprecated in Flutter 3.47 and defaults to
  /// `true` in the framework, so passing it would be both a lint failure and a
  /// second place where "are we Material 3?" is answered.
  ///
  /// No `textScaleFactor` and no scaler: the reader's font-size preference is
  /// applied by `MaterialApp.builder`, not here, so that the platform's own
  /// accessibility scaling is composed with it rather than overwritten by it.
  ///
  /// That builder line does **not** exist yet. `evaScalerFor` is exported and
  /// tested but uninstalled, because its `step` argument belongs to Phase 9's
  /// `settings_repository`; see the comment above `evaScalerFor` in
  /// `tokens/eva_typography.dart` for the full ordering and for why installing it
  /// with a hard-coded step would be worse than leaving it out.
  static ThemeData build(EvaColors colors) {
    final TextTheme textTheme = EvaTypography.textTheme(colors);

    return ThemeData(
      colorScheme: _colorScheme(colors),
      // The three surface layers, bottom to top. §5.1: "`surface`/`raised`
      // become the base layers of `GlassSurface`".
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      cardColor: colors.surface,
      // The divider IS the hairline token — §5.1: "`line` becomes the hairline
      // colour" — which is why the two are the same value rather than one
      // derived from the other.
      dividerColor: colors.line,
      dividerTheme: DividerThemeData(
        color: colors.line,
        thickness: 1.0,
        space: 1.0,
      ),
      // `ink3` is the tertiary ink, and Material's own default for a disabled
      // label is `onSurface` at 38% — a colour this palette does not have.
      disabledColor: colors.ink3,
      // `09-quality-gates.md` §14: "Focus + a 2px ember ring at 40% alpha on
      // every interactive widget". 40% is the only alpha anywhere in §5.
      // `withValues`, not `withOpacity`: the latter is deprecated in 3.47 and
      // loses 8-bit precision.
      focusColor: colors.ember.withValues(alpha: 0.40),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: colors.ink2),
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        elevation: EvaElevations.appBar,
        scrolledUnderElevation: EvaElevations.appBar,
        surfaceTintColor: colors.surface,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: EvaElevations.card,
        surfaceTintColor: null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(EvaRadii.card)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: EvaElevations.dialog,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(EvaRadii.glassForm)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.raised,
        elevation: EvaElevations.snackBar,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: colors.ember,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(EvaRadii.card)),
        ),
      ),
      // The surfaces Material still elevates by default that §5 names no role
      // for. `EvaElevations.none` is not a seventh tier of anything — it is the
      // same zero, applied to the components nobody has designed yet, so that a
      // Phase-3 drawer or bottom bar does not arrive already casting Material's
      // stock shadow on a canvas that has no shadow. Their defaults are all
      // non-zero (drawer 16, popup menu 8, bottom bar 8, modal sheet 24), and on
      // a near-black canvas a stock Material shadow is a visible grey smear
      // rather than a subtle default — the same argument
      // `eva_elevations.dart` makes for the named six.
      //
      // `bottomSheetTheme` leads the group because it is the only one here with a
      // named token already: `elevation` is `bottomSheet`, and `modalElevation` is
      // `none`. That second field is the one that bites hardest — a *modal* sheet
      // resolves it before `elevation`, so zeroing `elevation` alone leaves the
      // modal variant at Material's 24.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        elevation: EvaElevations.bottomSheet,
        modalElevation: EvaElevations.none,
        surfaceTintColor: null,
        // Only the top corners are on screen; a bottom sheet that rounds all
        // four reads as a floating card.
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(EvaRadii.heroPanel),
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(elevation: EvaElevations.none),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: EvaElevations.none,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        elevation: EvaElevations.none,
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        elevation: EvaElevations.none,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: EvaElevations.none,
      ),
      popupMenuTheme: const PopupMenuThemeData(elevation: EvaElevations.none),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: EvaElevations.floatingActionButton,
        focusElevation: EvaElevations.floatingActionButton,
        hoverElevation: EvaElevations.floatingActionButton,
        highlightElevation: EvaElevations.floatingActionButton,
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }

  /// Derives Material's [ColorScheme] from [colors].
  ///
  /// Exposed for the theme's own tests, which assert each field against a named
  /// token. Private would be more correct in isolation; public with a test is
  /// more useful than private and untested.
  static ColorScheme _colorScheme(EvaColors colors) => ColorScheme(
    brightness: _brightnessOf(colors),
    // The single accent and the ink that stays legible on it. §5.1:
    // "`onEmber` becomes `EvaButton.primary`'s foreground".
    primary: colors.ember,
    onPrimary: colors.onEmber,
    primaryContainer: colors.emberDeep,
    onPrimaryContainer: colors.onEmber,
    // Material wants a lower-emphasis second accent. The nearest Eva token is
    // `emberDeep` — it is the same hue, darker, and already the pressed fill.
    secondary: colors.emberDeep,
    onSecondary: colors.onEmber,
    // And a third, which is not an accent at all here: `ink2` is the design's
    // muted supporting tone.
    tertiary: colors.ink2,
    onTertiary: colors.surface,
    // The quiz/feedback semantic pair, §5.1, straight onto Material's error role
    // so a stock `TextField.errorText` or a stock validation colour is already
    // in the Eva palette.
    error: colors.err,
    onError: colors.onEmber,
    surface: colors.surface,
    onSurface: colors.ink,
    onSurfaceVariant: colors.ink2,
    outline: colors.ink3,
    // Material's "divider" role is precisely the hairline.
    outlineVariant: colors.line,
    // Three surface tokens, mapped onto the two ends of the container ramp.
    //
    // ## THE RAMP HAS AN ACCIDENTAL FLAT RUN, AND IT IS NOT FIXED HERE
    //
    // Material asks for five container levels between `surfaceDim` and
    // `surfaceContainerHighest`. There are three Eva surfaces, so two steps have
    // to share, and the way they share is a choice rather than a mapping:
    //
    //     lowest · low · container · high · highest
    //     canvas  ·  ↑    · surface  ·  raised · raised
    //                   └── unset, collapses to `surface`
    //
    // Leaving `surfaceContainerLow` unset resolves it to `surface`, which makes
    // `low` and `container` the same value and `high` and `highest` the same
    // value — an effective ramp of `canvas · surface · surface · raised · raised`
    // with a flat run of three in the middle and no step between `canvas` and
    // `surface` either.
    //
    // Two repairs were available and neither is in scope here. Setting
    // `low: colors.canvas` trades the middle flat run for a flat run at the
    // bottom, and invents a level. Interpolating a level is inventing a
    // *colour*, which is what §5.1 does not contain. The honest options are
    // therefore: accept the collapse and let a component that needs five levels
    // say so, or add a fourth surface token to the spec first. Phase 3 owns the
    // first component that asks.
    //
    // `surfaceBright` is left unset on purpose — see the class doc.
    surfaceDim: colors.canvas,
    surfaceContainerLowest: colors.canvas,
    // surfaceContainerLow: — see the note above.
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.raised,
    surfaceContainerHighest: colors.raised,
    // The one shadow in the system.
    shadow: colors.glassShadow,
    // The "surface" that inverts — used by Material for the inverse-toolbar
    // snackbars and tooltips. `ink` is the design's other pole, so swapping
    // surface for ink inverts the palette exactly.
    inverseSurface: colors.ink,
    onInverseSurface: colors.surface,
    inversePrimary: colors.ember,
    // Tint == surface, so Material 3's elevation tint is present and invisible.
    // A flat, hairline-separated system must not grow a primary-coloured stain
    // behind a card.
    surfaceTint: colors.surface,
  );

  /// The brightness [colors] was written for.
  ///
  /// [EvaColors.dark] and [EvaColors.light] are the only two palettes this design
  /// system has, so anything else is a programming error rather than a case to
  /// handle — hence the throw instead of a fallback.
  ///
  /// ## WHY THE CANVAS COLOUR AND NOT THE OBJECT
  ///
  /// The obvious implementation compares the instance:
  /// `identical(colors, EvaColors.dark())`. It is wrong, and it fails on the very
  /// first call that omits `const`: in Dart, `EvaColors.dark()` *without* `const`
  /// in a non-const context runs the const constructor as ordinary code and
  /// allocates a fresh object, so `identical` is false and a perfectly valid
  /// palette is rejected. `Color` overrides `==` by value, so comparing the canvas
  /// is both total and robust — it survives `copyWith`, survives a non-`const`
  /// invocation, and it reads the token that actually *is* the background, which
  /// is the property brightness is supposed to track.
  static Brightness _brightnessOf(EvaColors colors) {
    if (colors.canvas == const EvaColors.dark().canvas) {
      return Brightness.dark;
    }
    if (colors.canvas == const EvaColors.light().canvas) {
      return Brightness.light;
    }
    throw ArgumentError.value(
      colors.canvas,
      'colors',
      'canvas is neither the dark nor the light canvas, so this palette has no '
          'brightness — pass one of EvaColors.dark() / EvaColors.light(), or '
          'derive one from the canvas rather than from a colour alone',
    );
  }
}
