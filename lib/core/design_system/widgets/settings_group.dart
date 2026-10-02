import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A labelled group of [SettingsTile]s.
///
/// The Settings screen's structure: a section label, then a column of rows with
/// 10px between them (`SettingsScreen.tsx:45-124`). The label and the gap are the
/// whole of the widget, and they are the whole of the prototype's contribution.
///
/// **The §3.1 deletion test is DEFERRED, not passed.** This widget is on the
/// demotion watch list in `04-widget-inventory.md` §3.1 — one surviving call site,
/// below the two-call-site bar — and the same note as [EvaSectionHeader]'s applies
/// verbatim: there is no feature to demote *into* until Phase 5, so the test could
/// not be re-run honestly and is not claimed to have been.
class SettingsGroup extends StatelessWidget {
  /// A group labelled [label] containing [children].
  const SettingsGroup({required this.label, required this.children, super.key});

  /// The section label. Rendered by [EvaSectionHeader] at its default size,
  /// which is the prototype's `SectionLabel`.
  final String label;

  /// The rows, in order.
  ///
  /// A `List<Widget>` rather than a builder because §13.5 forbids `Column` over
  /// unbounded data and this data *is* bounded: it is one settings screen's
  /// worth, known at build time from the screen's own composition.
  final List<Widget> children;

  /// The gap between rows. `SettingsScreen.tsx:49,75,100,114` — `gap: 10`.
  ///
  /// 10, not `EvaSpacing.md + EvaSpacing.xs` (16). The prototype's number is not
  /// on the 4px scale and the nearest step that would be 16 is 60% further apart.
  static const double rowGap = 10;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      EvaSectionHeader(label: label),
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: rowGap),
        children[i],
      ],
    ],
  );
}
