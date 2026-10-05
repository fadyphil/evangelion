import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// One settings row: a title on the left, a control on the right.
///
/// `ds.tsx:481-496`, wrapped around every row on the Settings screen
/// (`SettingsScreen.tsx:50,63,76,92,101,106,115,118`).
///
/// ## `.tint`, FOR THE SAME REASON AS `StatTile`
///
/// `ds.tsx:487` gives this widget `backdropFilter: blur(12px)`; §13.4's
/// per-screen table puts `/settings` in "everything else → `tint`". The tile is
/// a `GlassSurface` at [GlassTier.tint].
///
/// ## THE PROTOTYPE'S `height: 56` IS A **MINIMUM** HERE, NOT A FIXED HEIGHT
///
/// `ds.tsx:488` — `height: 56`. A fixed 56 is a §14 hazard and the task's
/// "no fixed height anywhere" rule: the title is `bodyLarge` (16sp), which is
/// 19.5sp at the 1.22× the section mandates, and its line box is ~29px — plus
/// [trailing], which for [SegmentedControl] is a 3-option control that is wider
/// and shorter than the row and would be clipped. So the constraint is a
/// `minHeight` and the row grows.
///
/// The cost is stated: on a device not scaling text, the row is exactly 56 as the
/// prototype drew it, and the visual difference only appears for a reader who
/// asked for larger text — which is the point.
class SettingsTile extends StatelessWidget {
  /// A row titled [title] with [trailing] on the right.
  const SettingsTile({
    required this.title,
    required this.trailing,
    this.onTap,
    super.key,
  });

  /// The row's label. `ds.tsx:493` — `F.ui, 15, 500, T.ink`.
  final String title;

  /// The control. A [Widget] and not a callback, so the control brings its own
  /// semantics, its own focus node and its own §14 ring — a settings row must
  /// not own the focus of the switch inside it, or Tab lands on the row and then
  /// again on the control.
  final Widget trailing;

  /// What to run when the row itself is tapped. `null` — the common case, and the
  /// one every prototype row uses — makes the row inert and lets the trailing
  /// control take focus on its own.
  final VoidCallback? onTap;

  /// The prototype's radius. `ds.tsx:488` — `borderRadius: 14`, which is
  /// [EvaRadii.button].
  static const double radius = EvaRadii.button;

  /// The prototype's row height, used as a floor. `ds.tsx:488` — `height: 56`.
  static const double minHeight = 56;

  /// `ds.tsx:488` — `padding: '0 16px'`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.lg,
    vertical: EvaSpacing.sm,
  );

  @override
  Widget build(BuildContext context) {
    final bool interactive = onTap != null;

    final Widget row = GlassSurface(
      tier: GlassTier.tint,
      radius: radius,
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight - EvaSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(
              // ## `excludeSemantics` ON THE **TITLE**, AND IT IS NOT THE ROW'S
              // `excludeSemantics: false` BEING REVERSED
              //
              // The row's own `Semantics` keeps `excludeSemantics: false` on purpose
              // — the comment at the return below says why, and the reasoning stands:
              // a tappable row *contains* a control, and dropping the subtree would
              // leave a screen reader with a button that does nothing. What was wrong
              // is that **this** `Text` then contributed [title] a second time. Measured
              // on `/settings`'s language row:
              //
              // ```text
              // lbl="Default language|Default language|English"  tap=true  btn=true
              // ```
              //
              // A name said twice, and — worse — the row was the **only** node carrying
              // the reader's current language, so the duplicate was not merely untidy,
              // it was three announced words where one was needed.
              //
              // Excluding **only this `Text`** is the smallest fix that keeps both
              // halves: the title's glyphs are still painted and still readable, and
              // `trailing`'s own node — a nested control, or the current-value text —
              // survives to be announced alongside the row's name.
              child: ExcludeSemantics(
                child: Text(
                  title,
                  // `arabicAware` here for the same reason as `EvaSectionHeader`: the
                  // row's title is painted by this widget, so this widget decides the
                  // family. Under LTR it is the identity function, so every existing
                  // Latin assertion is untouched.
                  style: arabicAware(
                    Theme.of(context).textTheme.bodyLarge!
                        .copyWith(fontWeight: FontWeight.w500),
                    Directionality.of(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: EvaSpacing.md),
            trailing,
          ],
        ),
      ),
    );

    if (!interactive) {
      return row;
    }

    return Semantics(
      button: true,
      label: title,
      // `excludeSemantics: false` on purpose, unlike every other interactive
      // widget here: a tappable settings row *contains* a control, and dropping
      // the subtree would leave a screen reader with a button that does nothing
      // when activated.
      child: EvaFocusRing(
        enabled: true,
        radius: radius,
        child: EvaInk(
          onPressed: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: row,
        ),
      ),
    );
  }
}
