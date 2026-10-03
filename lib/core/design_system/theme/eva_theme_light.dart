import 'package:evangelion/core/design_system/theme/eva_theme.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter/material.dart';

/// The Eva light theme.
///
/// A stable singleton for the same reason as [EvaThemeDark.theme]:
/// `MaterialApp` compares `theme` and `darkTheme` by identity, so a factory
/// would re-localise the whole tree on every rebuild of the app widget.
///
/// `darkTheme:` rather than `theme:` is the light one's job in this app. The
/// design is a dark glassmorphic system (AGENT_CONTEXT §2, decision 6); light is
/// the alternative a reader picks in Settings, not the default.
///
/// The `ThemeMode` that chooses between them is **not** Phase 5's, whatever this
/// comment used to say. `app.dart` sets `ThemeMode.dark` explicitly and still
/// does; Phase 5 delivered `core/network` and the `auth` feature, so the switch
/// belongs to the phase that lands `UserSettings`. Until then the light theme is
/// reachable only from a test that names `EvaThemeLight.theme` directly, which is
/// exactly what `eva_theme_test.dart` does.
abstract final class EvaThemeLight {
  /// The light theme, built from [EvaColors.light].
  ///
  /// `docs/plans/03-design-system.md` §5.1's light table: `canvas` #F0EEFF ·
  /// `surface` #FFFFFF · `raised` #E8E4FF · `ink` #120E28 · `ember` #D4891A, and
  /// the glass triple at black-3% / black-7% / #120E28-12%.
  static final ThemeData theme = EvaTheme.build(const EvaColors.light());
}
