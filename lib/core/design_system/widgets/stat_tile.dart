import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A number and its caption, in a tinted panel.
///
/// **Split provenance, deliberately, and Phase 4.2 moved only one half.**
///
/// | | prototype | re-pointed? |
/// | --- | --- | --- |
/// | the panel | radius 16, padding `14px 10px`, `tint` | **no** |
/// | the type | `F.display, 24, 600` and `F.mono, 9, 700, 0.12em` → **`redesign.html:407-408`** | **yes** |
///
/// ## WHY THE PANEL STAYS AND THE TYPE GOES
///
/// The redesign does not restyle this tile — it **replaces** it. `.ringbox`
/// (`redesign.html:403-409`) is a `CustomPaint` ring with a stroked arc, a value
/// and a label, and Phase 6.2 is when `/result` **became** a modal.
/// There is no `.ringbox` panel to transcribe because there is no panel: it is a
/// circle with a gap in it.
///
/// So the honest move is to split the widget's provenance rather than pretend the
/// redesign has an answer for all of it. The **glass panel** stays on the
/// prototype's own panel because that is where it still comes from — and nothing
/// ever
/// deleted it, because the redesign's ring was **never ported**: a ring needs a
/// denominator the submit response does not carry (AGENT_CONTEXT decision 93),
/// so Phase 6.2's modal draws this tile's panel instead. The **type** is
/// re-pointed to `redesign.html:407-408`, because that is where the redesign
/// *does* state a value for the same two lines of text — same words, smaller,
/// mono, quieter — and a prototype number that exists is a prototype number.
///
/// The result is a tile that is the redesign's lettering inside Phase 2's panel,
/// and that is stated here rather than left for a reader to infer from the two
/// citations. `stat_tile_{dark,light}.png` move because of the type alone; the
/// panel is the prototype's to the pixel.
///
/// ## `.tint`, NOT `.blur`, DESPITE THE PROTOTYPE
///
/// The prototype gives this widget `backdropFilter: blur(16px)`, and §13.4
/// counts
/// it among the six prototype blur sites that must collapse into `GlassSurface`.
/// But §13.4's per-screen table then says which screens may actually blur: Home's
/// today's-reading panel and Home's top bar, and "everything else → `tint`".
/// `/result` is "everything else", and its stat rows are explicitly the case §13.5
/// wraps in a `RepaintBoundary` rather than the case it spends a `saveLayer` on.
///
/// So the tile is a `GlassSurface` at [GlassTier.tint] and the prototype's blur
/// is **not** transcribed. Two rules disagree and §13.4 is the one that states a
/// budget, so it wins. Recorded rather than silently resolved: a reader
/// comparing against the prototype will find a missing blur here.
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

  /// The figure. **Mono, 11px** — `redesign.html:407`'s `.ringbox .rv`, which is
  /// `font-family:var(--mono);font-size:11px;color:var(--ink-0)` and declares no
  /// `font-weight`, so the weight is normal.
  ///
  /// Was the display serif at 24 w600, which is what
  /// `headlineSmall` gave it. The redesign replaces the whole figure: where the
  /// old tile shouted a number in a 24px serif, `.ringbox` reads it out quietly
  /// in mono next to the arc. See the class doc for why the panel survives this
  /// change and the figure does not.
  final String value;

  /// The caption under it. **Mono, 8.5px, `.14em`, uppercase** —
  /// `redesign.html:408`'s `.ringbox .rl`. Was `F.mono, 9, 700, 0.12em, T.ink3`
  /// and, since decision 149, `ink2`.
  ///
  /// ## THE INK IS `ink2` AND `:408` SAYS `--ink-1`, WHICH IS NOT A TOKEN
  ///
  /// `redesign.html:408` ends `color:var(--ink-1)`. `EvaColors` has no `ink1`: it
  /// publishes `ink`, `ink2` and `ink3`, which map onto `--ink-0`, `--ink-2` and
  /// a §5.1-only tertiary that the redesign has no counterpart for. The middle ink
  /// of the prototype's three therefore **cannot be named here**, and `ink2`
  /// stands.
  ///
  /// Standing rather than moving, because decision 149 already moved this exact
  /// run once and for a reason that still holds: `ink3` is 1.65:1 on dark glass,
  /// and `ink2` is 4.73:1. Picking `ink` because it is "the one above `ink2`"
  /// would make the caption brighter than the value above it and invert the
  /// hierarchy the redesign is establishing. Recorded, not silently resolved.
  final String label;

  /// The prototype's radius — `borderRadius: 16`. Not a token:
  /// [EvaRadii] has 14 (button/input), 18 (card/quiz option), 24 and 28, and
  /// inventing an eighteenth step for one widget is worse than naming the number
  /// where it is used.
  ///
  /// **Kept** through Phase 4.2 even though the tile's type was re-pointed: the
  /// radius belongs to the prototype's panel half of the split, and the redesign has
  /// no radius for a ring.
  static const double radius = 16;

  /// The prototype's `padding: '14px 10px'`.
  ///
  /// Neither number is on the 4px scale — 14 is [EvaRadii.input] and 10 is not a
  /// token at all — so the prototype's own pair is transcribed literally rather
  /// than approximated with scale steps that would be wrong by 2 and 4.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 14,
  );

  /// Gap between the value and the caption. The prototype's `gap: 4`.
  ///
  /// **Kept** from the prototype's half of the split. `.ringbox` puts `margin-top`
  /// on `.rv` (`:407`) and `.rl` (`:408`) rather than a flex `gap` on a shared
  /// parent — `margin-top:-34px` to pull the value up into the ring, and `16px`
  /// above the label — so there is no one gap token to move and re-deriving one
  /// from two different margins would be inventing it.
  static const double stackGap = EvaSpacing.xs;

  /// The figure's size. `redesign.html:407` — `font-size:11px`.
  static const double valueSize = 11;

  /// The caption's size. `redesign.html:408` — `font-size:8.5px`.
  static const double labelSize = 8.5;

  /// The caption's tracking. `redesign.html:408` — `letter-spacing:.14em`.
  ///
  /// **Premultiplied by [labelSize] into a logical-pixel value where it is used**,
  /// because Flutter's `letterSpacing` is an absolute advance and CSS's `em` is
  /// relative to the element's own font. `.14em` at 8.5px is **1.19**.
  static const double labelTracking = 0.14;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // The ambient direction, read once — see the class doc for why both runs below
    // need it and why the widget has no `isArabic` branch.
    final TextDirection direction = Directionality.of(context);
    return GlassSurface(
      // Left at [GlassTier.tint], which is [GlassSurface]'s own default — see the
      // class doc for why this is `tint` and not the prototype's blur.
      radius: radius,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            // `redesign.html:407` — `font-family:var(--mono);font-size:11px`,
            // no `font-weight`, `color:var(--ink-0)`.
            //
            // **No `headlineSmall` any more.** The old style took M3's 24sp slot
            // and then overrode the family to the display serif, which is how a
            // 24px serif got here in the first place; there is no slot that
            // yields mono at 11, so this is `monoCaps`' family with the prototype's
            // own size and the slot's `w400` — the weight `monoCaps` inherits from
            // `labelMedium` and `:407`'s silence agrees with.
            style: arabicAware(
              EvaTypography.monoCaps(colors).copyWith(
                fontSize: valueSize,
                // `:407` declares **no** `letter-spacing`, so it is `normal` —
                // written out rather than left inherited, because
                // [EvaTypography.monoCaps] carries `labelMedium`'s **0.5** and
                // `.mono`'s `.16em` is not this element's anyway. Same reasoning
                // as the weight: the redesign states a weight where it wants one
                // (`:185`, `:31`) and this is not one of those rules.
                letterSpacing: 0,
                color: colors.ink,
                fontWeight: FontWeight.w400,
              ),
              direction,
            ),
          ),
          const SizedBox(height: stackGap),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            // `redesign.html:408` — `font-family:var(--mono);font-size:8.5px;
            // letter-spacing:.14em;text-transform:uppercase`. The
            // `text-transform` is the widget's own, as everywhere else here.
            style: arabicAware(
              EvaTypography.monoCaps(colors).copyWith(
                fontSize: labelSize,
                letterSpacing: labelSize * labelTracking,
                // [EvaColors.ink2], and the class doc says why `:408`'s
                // `--ink-1` cannot be spelled and why 149's `ink3` is still wrong.
                color: colors.ink2,
                fontWeight: FontWeight.w400,
              ),
              direction,
            ),
          ),
        ],
      ),
    );
  }
}
