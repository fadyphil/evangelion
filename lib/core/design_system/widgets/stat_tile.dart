import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A number and its caption, in a tinted panel.
///
/// `ds.tsx:462-478`, the Result screen's three-tile row
/// (`ResultScreen.tsx:69-73`).
///
/// ## `.tint`, NOT `.blur`, DESPITE THE PROTOTYPE
///
/// `ds.tsx:469` gives this widget `backdropFilter: blur(16px)`, and §13.4 counts
/// it among the six `ds.tsx` blur sites that must collapse into `GlassSurface`.
/// But §13.4's per-screen table then says which screens may actually blur: Home's
/// today's-reading panel and Home's top bar, and "everything else → `tint`".
/// `/result` is "everything else", and its stat rows are explicitly the case §13.5
/// wraps in a `RepaintBoundary` rather than the case it spends a `saveLayer` on.
///
/// So the tile is a `GlassSurface` at [GlassTier.tint] and the prototype's blur
/// is **not** transcribed. Two rules disagree and §13.4 is the one that states a
/// budget, so it wins. Recorded rather than silently resolved: a reader
/// comparing against `ds.tsx` will find a missing blur here.
class StatTile extends StatelessWidget {
  /// A tile showing [value] over [label].
  const StatTile({required this.value, required this.label, super.key});

  /// The figure. Rendered in the display serif, as the prototype does.
  final String value;

  /// The caption under it. Mono, uppercase, `ink3` — the prototype's
  /// `F.mono, 9, 700, letterSpacing 0.12em, T.ink3` (`ds.tsx:475`).
  final String label;

  /// The prototype's radius. `ds.tsx:469` — `borderRadius: 16`. Not a token:
  /// [EvaRadii] has 14 (button/input), 18 (card/quiz option), 24 and 28, and
  /// inventing an eighteenth step for one widget is worse than naming the number
  /// where it is used.
  static const double radius = 16;

  /// `ds.tsx:470` — `padding: '14px 10px'`.
  ///
  /// Neither number is on the 4px scale — 14 is [EvaRadii.input] and 10 is not a
  /// token at all — so the prototype's own pair is transcribed literally rather
  /// than approximated with scale steps that would be wrong by 2 and 4.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 14,
  );

  /// Gap between the value and the caption. `ds.tsx:471` — `gap: 4`.
  static const double stackGap = EvaSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    return GlassSurface(
      // See the class doc for why this is `tint` and not the prototype's blur.
      tier: GlassTier.tint,
      radius: radius,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            // `ds.tsx:474` — `F.display, 24, 600, lineHeight 1`.
            //
            // `headlineSmall` is Material 3's 24sp slot, so the prototype's 24
            // lands exactly — the first widget in this phase where the phase-1
            // decision to keep M3's scale costs nothing.
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: stackGap),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: EvaTypography.monoCaps(colors)
                .copyWith(color: colors.ink3, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
