import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:flutter/material.dart';

/// The medals strip — `eva/redesign.html:598-603`'s `<div class="medals">`.
///
/// ## IT SCROLLS, AND THAT IS **WHY**
///
/// `:410` is `.medals{display:flex;gap:12px;overflow-x:auto;padding:4px 18px
/// 12px;scrollbar-width:none}`. Four medals at 104px plus three 12px gaps are
/// **452px** — `4 × 104 + 3 × 12` — and this client's narrowest supported
/// surface is **320** wide, so the strip scrolls and the four medals are not
/// all on screen at once on a phone. That is the prototype's own behaviour and
/// the reason `overflow-x:auto` is there.
///
/// **The 452 is the tiles and the gaps, and not the strip's own padding.**
/// `:410`'s `padding:4px 18px 12px` adds 36 more, so the strip's content box
/// is 488 wide — and the golden captures at that width, because a golden that
/// showed three of the four washes would pin the wrong thing.
///
/// **The 320 is this client's, and not a prototype number.** The redesign's
/// phone frame is `:43`'s `.device{width:390px}`, and the string "320" appears
/// nowhere in `eva/redesign.html`; 320 is the narrowest width this app
/// supports, and it is the width at which the four medals cannot fit.
///
/// **No `Scrollbar`**: `:410` sets `scrollbar-width:none` and `:411` adds a
/// `::-webkit-scrollbar{display:none}`, and Flutter shows a bar only where a
/// `Scrollbar` is placed.
///
/// ## THE HOVER IS **NOT** DRAWN
///
/// `:414` is `.medal:hover{transform:translateY(-4px)}` — a pointer affordance
/// on an element that is **not a control**: the prototype's medals are
/// `<div>`s with no handler, and ADR-0022's rule is that a screen may not
/// render a hard-coded medal. There is nothing to hover *for*, so the lift is
/// not transcribed, and this is recorded here rather than left as a gap.
class JourneyMedalsStrip extends StatelessWidget {
  /// The medals to draw, in the order they are earned.
  const JourneyMedalsStrip({required this.tiles, super.key});

  /// The tiles.
  final List<JourneyMedalTile> tiles;

  /// A medal's width — `eva/redesign.html:412`'s `flex:0 0 104px`.
  static const double medalSize = 104;

  /// The gap between two medals — `eva/redesign.html:410`'s `gap:12px`.
  static const double gap = 12;

  /// The strip's top padding — `eva/redesign.html:410`'s `padding:4px 18px 12px`.
  static const double paddingTop = 4;

  /// The strip's bottom padding — `eva/redesign.html:410`'s `padding:4px 18px 12px`.
  static const double paddingBottom = 12;

  /// The strip's horizontal padding — `eva/redesign.html:410`'s `padding:4px 18px 12px`.
  static const double paddingHorizontal = 18;

  /// The strip's own height — the padding and the medal.
  static const double stripHeight = paddingTop + medalSize + paddingBottom;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: stripHeight,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        paddingHorizontal,
        paddingTop,
        paddingHorizontal,
        paddingBottom,
      ),
      itemCount: tiles.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(width: JourneyMedalsStrip.gap),
      itemBuilder: (BuildContext context, int index) => tiles[index],
    ),
  );
}

/// One medal — `eva/redesign.html:599-602`'s `<div class="medal">`.
///
/// ```html
/// <div class="medal" style="--bh:rgba(244,227,178,.5)"><div class="bloom"></div><span>✦</span>
/// <div class="mn" data-i18n="m1">first light</div></div>
/// ```
///
/// ## THE WASH IS THE DESIGN SYSTEM'S OWN
///
/// `:415` is `.medal .bloom{position:absolute;left:0;right:0;bottom:-60%;
/// height:90%;background:radial-gradient(ellipse at 50% 100%,var(--bh),
/// transparent 70%);filter:blur(14px)}` — a decoration **behind** the emblem.
///
/// This client paints it with `GlassSurface(tier: GlassTier.bloom, bloomColor:)`,
/// which is the mechanism it has for exactly that wash, and the tier's own doc
/// records the substitutions it makes for a non-`.hcard` host: one full-bleed
/// wash, one fade stop, and the host's `overflow:hidden` doing the cutting.
/// The medal's own `overflow:hidden` (`:412`) is the same clip.
///
/// **The seam is off.** `GlassTier.bloom` paints a `.hor` seam by default, and
/// `:412`'s `.medal` has **no seam** — `glass_surface.dart`'s table says so
/// ("only `.hcard` has a `.hor` seam").
///
/// **And the surface brings two things `.medal` does not declare.** The tier
/// paints the house's `glassFill` and `glassBorder` and the glass ambient
/// shadow — `ds.tsx:386`'s `0 4px 24px`, which the redesign's `.medal`
/// (`:412-413`) does not carry — and the house's **light** `--glass-fill` is
/// 4% black where the prototype's is `rgba(255,255,255,.55)` (`:57`). Those
/// are the tier's recorded substitutions and the podium's are the same ones —
/// this widget does not re-argue them, and it does not have a switch for them
/// either.
///
/// ## THE MAGENTA'S BLOOM IS **NOT** AT THE PROTOTYPE'S 50%
///
/// `:600` is `rgba(228,87,214,.5)`, and the `bloom` token is that hue at **55%**
/// (`0x8CE457D6`). The token is used, because the token reproduces the hue
/// exactly, and the alpha difference is recorded rather than hidden: the wash is
/// 55% in dark where the prototype says 50%, and 55% × 0.55 ≈ 30% in light
/// against the prototype's 50% × 0.55 ≈ 27.5%. `journey_colours.dart` carries the
/// same note.
///
/// ## THE FOUR GLYPHS, AND WHAT THEY BECAME
///
/// | medal | prototype | here | why |
/// | --- | --- | --- | --- |
/// | first light | `✦` U+2726 (`:599`) | the painted star | **in no bundled family** — measured, and `four_pointed_star.dart` is the answer |
/// | psalmist | `❧` U+2767 (`:600`) | **text in the scripture family, pinned on both arms** | in EB Garamond only; it is not Arabic content, so the Arabic arm does not tofu — and the pinned family is what makes that true |
/// | streak ×7 | `✠` U+2720 (`:601`) | the painted star | in no bundled family, and **no existing painted ornament is a cross** — so it unifies on the star |
/// | john | `☩` U+2629 (`:602`) | the painted star | the same |
///
/// **The two unifications are recorded here**, which is where they are seen.
/// A cross is a different shape from a four-pointed star, and the prototype
/// drew one — so the medallion for "streak ×7" and the one for "john" carry the
/// prototype's **colours** and this client's **shape**. There is no cross in
/// this client's painted vocabulary, and inventing one for two of four medals
/// would be a larger invention than unifying them.
class JourneyMedalTile extends StatelessWidget {
  /// A medal named [label], drawn with [emblem] over a [bloom] wash.
  const JourneyMedalTile({
    required this.label,
    required this.emblem,
    required this.bloom,
    super.key,
  });

  /// The medal's name — the localized `journeyMedal*` label.
  final String label;

  /// The mark the medal is drawn with.
  ///
  /// **The domain's enum, and not a second one.** `Medal.emblem` names the
  /// prototype's four glyphs — and this widget is where the three that cannot
  /// be painted are unified on the star. See the class doc.
  final MedalEmblem emblem;

  /// The wash behind the mark.
  ///
  /// **The domain's enum**, for the same reason: `Medal.bloom` names the
  /// prototype's four washes, and the *values* live in `journey_colours.dart`.
  final MedalBloom bloom;

  /// The emblem's size — `eva/redesign.html:413`'s `font-size:26px`.
  static const double emblemSize = 26;

  /// The name's Latin size — `eva/redesign.html:417`'s `font-size:8px`.
  static const double labelSize = 8;

  /// The name's Arabic size — `eva/redesign.html:418`'s `font-size:9.5px`.
  static const double labelSizeArabic = 9.5;

  /// The name's Latin tracking — `eva/redesign.html:417`'s
  /// `letter-spacing:.12em`.
  ///
  /// **Transcribed as the resolved value and not as `em`.**
  /// `TextStyle.letterSpacing` is a **logical-pixel advance** and CSS's `em`
  /// is relative to the element's own font size, so `.12em` at [labelSize]
  /// (8px) is **0.96**.
  static const double labelTracking = 0.96;

  /// The name's gap above the medal's bottom edge —
  /// `eva/redesign.html:417`'s `bottom:8px`.
  static const double labelInset = 8;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return SizedBox.square(
      dimension: JourneyMedalsStrip.medalSize,
      child: GlassSurface(
        tier: GlassTier.bloom,
        // `:412`'s `.medal` has no padding of its own — the emblem is centred
        // and the name is absolutely positioned at the bottom.
        padding: EdgeInsets.zero,
        // `:412`'s `.medal` has no `.hor` seam; only `.hcard` has one.
        seam: false,
        bloomColor: _bloomColour(colors),
        child: Stack(
          children: <Widget>[
            // `:413`'s `display:grid;place-items:center` — the emblem, centred.
            Center(child: _emblem(colors)),
            // `:417`'s `.mn` — `position:absolute;bottom:8px;left:0;right:0;
            // text-align:center`, and `:416`'s `.medal span{position:relative}`
            // is what puts the emblem above the absolutely positioned name.
            Positioned(
              left: 0,
              right: 0,
              bottom: labelInset,
              child: Text(
                monoCapsText(label, direction),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: arabicAware(
                  EvaTypography.monoCaps(colors).copyWith(
                    fontSize: direction == TextDirection.rtl
                        ? labelSizeArabic
                        : labelSize,
                    letterSpacing: direction == TextDirection.rtl
                        ? 0
                        : labelTracking,
                    color: colors.ink2,
                  ),
                  direction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The wash this medal is painted with.
  ///
  /// **The magenta is the token** — `EvaColors.bloom` — and the other three are
  /// the transcriptions in `journey_colours.dart`. See the class doc for the
  /// alpha difference the token's 55% makes against the prototype's 50%.
  Color _bloomColour(EvaColors colors) => switch (bloom) {
    MedalBloom.cream => journeyBloomCream,
    MedalBloom.magenta => colors.bloom,
    MedalBloom.amber => journeyBloomAmber,
    MedalBloom.blue => journeyBloomBlue,
  };

  /// The mark.
  ///
  /// **The unification is here**, because this is where it is seen.
  ///
  /// | the domain's emblem | prototype | painted |
  /// | --- | --- | --- |
  /// | `fourPointedStar` | `✦` U+2726 (`:599`) | the star |
  /// | `fleuron` | `❧` U+2767 (`:600`) | the fleuron, as text in the scripture family |
  /// | `malteseCross` | `✠` U+2720 (`:601`) | **the star** |
  /// | `crossOfSaintJohn` | `☩` U+2629 (`:602`) | **the star** |
  Widget _emblem(EvaColors colors) => switch (emblem) {
    // The four-pointed star — painted, because U+2726 is in no bundled family.
    MedalEmblem.fourPointedStar => FourPointedStar(
      size: JourneyMedalTile.emblemSize,
      color: colors.ink,
    ),
    // **The family is PINNED, and not `arabicAware`.** `❧` is not Arabic
    // content, so the Arabic arm does not need to swap to a script face — and
    // swapping it would be wrong anyway, because the whole point of the pinned
    // family is that the glyph is in it.
    MedalEmblem.fleuron => Text(
      '❧',
      style: TextStyle(
        fontFamily: EvaTypography.scriptureFamily,
        fontSize: JourneyMedalTile.emblemSize,
        color: colors.ink,
      ),
    ),
    // **The two crosses unify on the painted star.** U+2720 and U+2629 are in
    // no bundled family, and **no existing painted ornament is a cross** — so
    // a cross would have to be invented, and a new painted shape for two of
    // four medals is a larger invention than unifying them. The prototype's
    // *colours* are kept; the *shape* is this client's.
    MedalEmblem.malteseCross || MedalEmblem.crossOfSaintJohn => FourPointedStar(
      size: JourneyMedalTile.emblemSize,
      color: colors.ink,
    ),
  };
}
