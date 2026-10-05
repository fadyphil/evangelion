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
///
/// ## AND BOTH ITS RUNS GO THROUGH `arabicAware`, WHICH PHASE 8 HAD TO ADD HERE
///
/// This widget was built in Phase 3 and had **no** Arabic arm, because the only
/// screen that used it was the `/result` stub. Phase 8 built that screen, handed
/// this tile an Arabic caption and an Arabic-Indic number, and the bilingual gate
/// immediately reported:
///
///     `١٠` renders Arabic in `CormorantGaramond`, which carries no Arabic glyph at all
///     `هذه الإجابة` renders Arabic in `SpaceMono`, which carries no Arabic glyph at all
///
/// Both halves are tofu — one box per character. Neither is a `StatTile` bug in the
/// sense of a wrong constant: the widget resolved [Theme.of]'s `headlineSmall` and
/// [EvaTypography.monoCaps], both of which are Latin families, and neither has an
/// opinion about the ambient arm.
///
/// The fix is [arabicAware] on both runs rather than an `if (isArabic)` branch,
/// because both strings are the **app's own chrome** — a caption from
/// `AppLocalizationsAr` and a number `arabicIndicDigits` produced — so the ambient
/// direction is the only arm there is. This is exactly the case that helper's doc
/// names ("runs that render the app's own strings"), and it is why Phase 3 could
/// not have written it: there was no Arabic on this screen to write it for.
///
/// **Nothing changes under LTR.** `arabicAware` is the identity there, so the
/// Phase-3 goldens are unaffected and this is not a visual regression on the arm
/// that shipped.
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
    // The ambient direction, read once — see the class doc for why both runs below
    // need it and why the widget has no `isArabic` branch.
    final TextDirection direction = Directionality.of(context);
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
            style: arabicAware(
              Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
              direction,
            ),
          ),
          const SizedBox(height: stackGap),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: arabicAware(
              EvaTypography.monoCaps(colors)
                  .copyWith(color: colors.ink3, fontWeight: FontWeight.w700),
              direction,
            ),
          ),
        ],
      ),
    );
  }
}
