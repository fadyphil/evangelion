import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The two segmented controls governing `/communion`: scope (window) and metric
/// (`eva/redesign.html:620-625`, `:1460-1461`).
///
/// ## THE TWO `semanticLabel`s ARE **THE CONTROLS' OWN NAMES**
///
/// `SegmentedControl` puts its `semanticLabel` on the **track's** semantics node
/// (`segmented_control.dart`'s own doc, `:192-200`), and the control's doc is
/// explicit that the caller must supply a name that is **not one of the
/// options** — because a track named "light" and an option named "light" are two
/// activatable nodes with the identical name, and that is the exact failure
/// `segmented_control.dart` records having had.
///
/// So the metric control is named **"Ranking metric"** and the scope control
/// **"Period"** — a name for the thing that holds the options, never one of the
/// options. The scope control was previously named after the **screen**
/// ("The Communion"), which is not a collision but is a poor name: it tells a
/// screen-reader user the title of the page rather than the name of the control
/// they are on.
class CommunionSegmentedControls extends StatelessWidget {
  /// Creates the scope and metric controls.
  const CommunionSegmentedControls({
    required this.selectedWindow,
    required this.selectedMetric,
    required this.onWindowChanged,
    required this.onMetricChanged,
    super.key,
  });

  /// The active window.
  final LeaderboardWindow selectedWindow;

  /// The active metric.
  final LeaderboardMetric selectedMetric;

  /// Called when the window is changed.
  final ValueChanged<LeaderboardWindow> onWindowChanged;

  /// Called when the metric is changed.
  final ValueChanged<LeaderboardMetric> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedControl<LeaderboardWindow>(
          values: LeaderboardWindow.values,
          selected: selectedWindow,
          labelOf: (LeaderboardWindow window) => switch (window) {
            LeaderboardWindow.weekly => strings.leaderboardWindowWeekly,
            LeaderboardWindow.monthly => strings.leaderboardWindowMonthly,
            LeaderboardWindow.allTime => strings.leaderboardWindowAllTime,
          },
          onChanged: onWindowChanged,
          semanticLabel: strings.leaderboardScopeLabel,
        ),
        const SizedBox(height: EvaSpacing.sm),
        SegmentedControl<LeaderboardMetric>(
          values: LeaderboardMetric.values,
          selected: selectedMetric,
          labelOf: (LeaderboardMetric metric) => switch (metric) {
            LeaderboardMetric.light => strings.leaderboardMetricLight,
            LeaderboardMetric.streaks => strings.leaderboardMetricStreaks,
          },
          onChanged: onMetricChanged,
          semanticLabel: strings.leaderboardMetricLabel,
        ),
      ],
    );
  }
}
