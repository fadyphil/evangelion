/// The Workshop's **segmented** row — the one row shape whose layout differs.
///
/// `eva/redesign.html:653-656`, `:671-674`, `:676-679` — the workshop's three
/// segmented rows: the Curtain shape, the Star shape and the Star field.
///
/// ## WHY IT IS IN A FILE OF ITS OWN
///
/// Because it is the only row whose **layout** differs: the other four put the
/// control beside the label, and this one puts the control **under** it. The
/// measurement that forces the difference is in the class doc below, and a
/// reviewer who wants to check it should find it next to the one widget it
/// governs rather than three widgets away in a file about rows in general.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A row whose trailing control is a **segmented control**, with the label
/// **above** it.
///
/// `eva/redesign.html:653-656`, `:671-674`, `:676-679` — the workshop's three
/// segmented rows.
///
/// ## WHY THE LABEL IS **ABOVE** THE CONTROL, AND IT IS A MEASURED REASON
///
/// The prototype puts the label and the control side by side, and the client does
/// not. The arithmetic, at the 320px viewport the standing matrix uses:
///
/// * the content column is `320 − 2×24` (`EvaSpacing.xxl`) = **272px**;
/// * the row's own horizontal padding takes 4px each side (`SettingsTile.padding`,
///   `eva/redesign.html:419`) → **264px** for the row;
/// * the gap between the label and the control is 10px (`:419`);
/// * the four-segment control's **minimum** is `4 × 44 = 176px` — `:183`'s
///   `min-width:44px`, which is a tap-target floor this client does not shrink.
///
/// So the label would have `264 − 176 − 10 = 78px`, and "Curtain shape" at 14.5px
/// (`:419`) is about 88px wide: the label cannot share the row, and the only way
/// to make it fit would be to shrink a segment below the prototype's own
/// tap-target floor.
///
/// **The prototype was drawn for a desktop width**, and this is the **divergence**,
/// recorded here. The stacked row's wide control is also what makes the row fit at
/// **1.22× text scale**: four quarters of 264px is 66px each, and "SHAFTS" at
/// `11 × 1.22 = 13.4px` in the mono face is about 54px — which the wide mode's
/// `padding:12px 0` (`eva/redesign.html:189`) is what allows.
class WorkshopSegmentRow<T> extends StatelessWidget {
  /// A row titled [title] with a segmented control over [values].
  const WorkshopSegmentRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.labelFamilyOf,
    super.key,
  });

  /// The row's label, and the control's own accessible name.
  ///
  /// For [WorkshopToggleRow]'s reason: the trailing control is the only node that
  /// can name the row, and `SegmentedControl.semanticLabel` exists for the
  /// duplicate-name defect `settings_tile.dart` measures.
  final String title;

  /// Every option, in paint order.
  final List<T> values;

  /// The chosen option.
  final T selected;

  /// The label for an option.
  final String Function(T) labelOf;

  /// Reports the new selection.
  final ValueChanged<T> onChanged;

  /// The family an option's label renders in.
  ///
  /// `null` for every option of every row here, **except** the language segment,
  /// which has one Arabic option inside a Latin screen and needs Amiri for it
  /// (`eva/redesign.html:186`). See `SegmentedControl.labelFamilyOf`'s own doc for
  /// why the rule is keyed on the **option** rather than on the direction.
  final String Function(T value)? labelFamilyOf;

  @override
  Widget build(BuildContext context) => SettingsTile(
    title: title,
    // The stacked mode: the label on its own line, the control below it, full
    // width. See the class doc for the measurement that requires it.
    stacked: true,
    trailing: SegmentedControl<T>(
      values: values,
      selected: selected,
      labelOf: labelOf,
      labelFamilyOf: labelFamilyOf,
      semanticLabel: title,
      // `eva/redesign.html:188-189` — `.segp.wide{width:100%}` and
      // `.segp.wide button{padding:12px 0;font-size:11px}`.
      wide: true,
      onChanged: onChanged,
    ),
  );
}
