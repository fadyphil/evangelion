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
/// verbatim: its only caller is the stub `SettingsPage`, and Phase 5 did not give
/// it a second one, so the test could not be re-run honestly and is not claimed to
/// have been. The earlier wording here cited "no feature … until Phase 5" as the
/// reason, which stopped being true when that phase closed; the reason is the call
/// sites, and the call sites are unchanged.
class SettingsGroup extends StatelessWidget {
  /// A group labelled [label] containing [children].
  const SettingsGroup({required this.label, required this.children, super.key});

  /// The section label. Rendered by [EvaSectionHeader] at its default size,
  /// which is the prototype's `SectionLabel`.
  ///
  /// **`redesign.html:422`'s label, re-pointed here and on that widget.**
  /// `.sgroup` is a `div` carrying `class="sgroup mono"` — `:645`, `:649`, `:651`,
  /// `:666`, `:682`, `:690`, `:696`, **seven** of them — and the class list means
  /// the *type* comes from `.mono` (`:30`) and the **margin** from `.sgroup`
  /// (`:422`). Phase 4.2 moved both, and the two moved for different reasons:
  ///
  /// * the **20px** top margin is `:422`'s, applied as [topGap];
  /// * the label's **gold** is a **design decision, not a transcription**.
  ///   `:30` ends `color:var(--ink-2)`, and `:31`'s `.mono b{color:var(--gold)}`
  ///   styles a `<b>` **child** — and **none of the seven `.sgroup` elements
  ///   contains one**. So the prototype's group label is `ink2` and this is not.
  ///
  /// What the gold rests on is `redesign.html:39` — `.rail h4{font-family:var
  /// (--mono);…;color:var(--gold);text-transform:uppercase}` — the prototype's
  /// own mono-caps gold heading, which is the same role as this label.
  /// `EvaSectionHeader`'s `section` variant carries the full argument; it is
  /// stated here because **this** is the widget whose doc a reader opens first.
  ///
  /// **The word "gold" is doing two jobs and they differ in light.** This widget
  /// has no label of its own — it delegates to [EvaSectionHeader]'s
  /// `section` variant — so there is one implementation, and it is
  /// [EvaColors.emberInk]. In dark that *is* `--gold` (`#E8B04B` ≈ `emberInk`
  /// `#E8A33D`); in light `emberInk` is `#845610` where `--gold` is `#9A7B19` and
  /// `ember` is `#8A6D15`. `emberInk` was chosen because it is the palette's
  /// **text** gold (decision 153: `ember` fills, `emberInk` writes) and because
  /// it is the one that clears AA as a label — 5.54:1 against `ember`'s 4.387:1.
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
  ///
  /// ## `redesign.html:422` SAYS `margin-bottom:6px` AND IS **NOT** APPLIED
  ///
  /// `.sgroup` is `margin:20px 0 6px` — 20 above the label, 6 below it. The 20
  /// **is** applied, as [topGap]. The 6 is not, and the reason is that it is not
  /// the gap between rows at all: `:422` describes the space under a *label*, and
  /// in the redesign a label sits directly above the first `.srow`, whose own
  /// `padding:15px 4px` (`:419`) supplies the separation. Applying 6 here would
  /// put a 6px gap above the first row **and** keep 10 between the rows, so the
  /// group would open with a narrower gap than it has internally.
  ///
  /// So `rowGap` keeps its `SettingsScreen.tsx` citation: 10 is that file's number
  /// and no `redesign.html` line replaces it. The divergence is recorded rather
  /// than smoothed, and the citation is re-pointed for **the label only** — which
  /// is [EvaSectionHeader]'s job, not this widget's.
  static const double rowGap = 10;

  /// The space above the label. `redesign.html:422` — `margin:20px 0 6px`, top.
  ///
  /// Re-pointed from `SettingsScreen.tsx:45-124`'s implicit layout, where this
  /// widget had no margin of its own and the column's spacing came from
  /// `SettingsPage.groupGap`.
  static const double topGap = 20;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: topGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EvaSectionHeader(label: label),
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: rowGap),
          children[i],
        ],
      ],
    ),
  );
}
