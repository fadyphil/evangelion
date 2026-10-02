import 'package:evangelion/core/design_system/theme/eva_theme.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter/material.dart';

/// The Eva dark theme.
///
/// A stable singleton rather than a factory method, for one concrete reason:
/// `MaterialApp` compares its `theme` and `darkTheme` **by identity** when
/// deciding whether to re-localise the tree. A `static ThemeData get theme`
/// rebuilding on every access would therefore rebuild — and re-localise — the
/// whole app on every rebuild of the app widget, which on a six-screen app with
/// a bilingual `TextTheme` is not free.
///
/// Everything about *what* the theme contains lives in [EvaTheme.build]; this
/// file's whole job is to name which palette it is built from.
abstract final class EvaThemeDark {
  /// The dark theme, built from [EvaColors.dark].
  ///
  /// `docs/plans/03-design-system.md` §5.1's dark table: `canvas` #05081A ·
  /// `surface` #0D1224 · `raised` #141A2E · `ink` #EAE8F5 · `ember` #E8A33D, and
  /// the glass triple at white-5% / white-8% / black-35%.
  static final ThemeData theme = EvaTheme.build(const EvaColors.dark());
}
