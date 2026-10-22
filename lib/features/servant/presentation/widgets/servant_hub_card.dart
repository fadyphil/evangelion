import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which of the portal's three treatments a [ServantHubCard] wears.
///
/// ## WHY THE ENUM IS **HERE** AND NOT IN THE HUB'S OWN TABLE
///
/// Because the hub's table — `ServantHubEntry` — answers **"may this reader be
/// offered this section?"**, and this enum answers **"how is this section
/// drawn?"**. Those are two different questions, and the page's own doc
/// records the shape they must not be confused with: the grant table is the
/// **one** place the policy lives, and a second copy of it would drift from the
/// first in both directions without anybody noticing.
///
/// So the **role** in the composition is a third fact, and it lives here
/// beside the two widgets that honour it. `ServantHubEntry` names *what* the
/// section is; this names *what it looks like*.
///
/// ## AND WHY THE THREE ARE **NOT THREE SIZES OF THE SAME CARD**
///
/// Because a page whose structure is a column of same-shaped cards is a
/// template, not a design — and this one has three genuinely different jobs:
///
/// * **[hero]** is the day's work. It is a **panel**: a filled, rimmed surface
///   with a mark, and the screen's largest type.
/// * **[duty]** is one of the admin's two duties. It is a **panel** too, but a
///   smaller one, with a different internal layout — the title and the glyph
///   share a line and the explanation sits underneath, at the card's own left
///   edge rather than in a column beside the mark.
/// * **[exit]** is not a section of the portal at all — it leaves the portal.
///   It is **not a panel**: it is a flat row under a rule, in the quieter inks,
///   because the reader's own app is not this portal's business and a servant
///   should not have to hunt for the way back to it.
///
/// A reader who has used the screen once should be able to say, without
/// reading, which of the three they are looking at.
enum ServantHubCardStyle {
  /// The day's primary destination — the daily report.
  hero,

  /// One of the admin servant's duties — scheduling, or authoring.
  duty,

  /// The way back to the reader's own shell.
  exit,
}

/// One destination on the servant portal's hub.
///
/// ## AND WHY IT IS **ONE WIDGET** AND NOT THREE
///
/// Because the three treatments share everything that is not the treatment:
/// the chevron, the icon, the two text runs, the focus ring, the ink response,
/// and the rule that a card's own words are its accessible name. Three
/// widgets would have been three copies of all of that, and the copies would
/// have drifted — which is the shape this repository has removed on purpose
/// more than once.
///
/// The **differences** are the enum's, and they are differences of *chrome*:
/// the panel's radius and padding and fill, the mark's size and ink, and the
/// internal layout.
class ServantHubCard extends StatelessWidget {
  /// A card in [style], titled [title], described by [description].
  const ServantHubCard({
    required this.style,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    super.key,
  });

  /// Which treatment this card wears.
  final ServantHubCardStyle style;

  /// The destination's name — the section's own title.
  final String title;

  /// One line saying what the destination is for.
  final String description;

  /// The mark that stands for the destination.
  final IconData icon;

  /// What to run when the card is tapped.
  final VoidCallback onTap;

  /// The hero panel's corner radius — [EvaRadii.heroPanel].
  ///
  /// ## WHY THE **HERO** GETS THE BIGGEST RADIUS AND NOTHING ELSE DOES
  ///
  /// `03-design-system.md` §5.3 publishes a radius per role: `14` for buttons
  /// and inputs, `18` for cards, `24` for the hero panel, `28` for the glass
  /// form. A radius is a **role** in this design system, not a size, and this
  /// card is the portal's hero panel — so it takes the hero panel's radius and
  /// the duty card takes the cards' radius.
  ///
  /// The alternative — one radius for both, chosen as the larger — was refused
  /// because it would make the duty card a hero panel with less in it, which is
  /// the shape the radius table exists to prevent.
  ///
  /// **And the duty card's radius is not written out at all**, because
  /// [GlassSurface]'s own default *is* [EvaRadii.card] — the design system's
  /// radius for cards, and this is one. A constant that names a default it
  /// does not change is a name with no reader, and this repository declines
  /// to publish those.
  static const double heroRadius = EvaRadii.heroPanel;

  /// The hero panel's inset — [EvaSpacing.lg].
  ///
  /// `20` is the design system's card padding (`03-design-system.md` §5.3,
  /// "card padding = 20") and the hero's own inset is **16** rather than 20,
  /// because the hero's mark is a 46px tile and a 20px inset around a 46px
  /// tile puts the mark further from the text than the text is from the card's
  /// edge. `16` keeps the two insets in step.
  static const double heroPadding = EvaSpacing.lg;

  /// The duty card's inset — [EvaSpacing.md].
  ///
  /// `12`, a step tighter than the hero's 16, because the duty card is smaller
  /// and its two text runs are closer to their edges.
  static const double dutyPadding = EvaSpacing.md;

  /// The hero mark's box — 46 logical px.
  ///
  /// **Not a token**, and named rather than inlined because it is a claim
  /// about the mark's proportions: the glyph inside is [heroMarkSize] and the
  /// box is the tile. The two are named together so a change to one is a
  /// visible change to the other.
  static const double heroMarkBox = 46;

  /// The hero mark's glyph — 22 logical px.
  ///
  /// **Not a token**, and the reason is the same as [heroMarkBox]'s: Material
  /// has no icon-size token, and the prototype has no icon at all on this
  /// screen (there is no servant portal in `eva/redesign.html`).
  static const double heroMarkSize = 22;

  /// The duty mark's glyph — 20 logical px.
  ///
  /// **Not a token**, for the reason [heroMarkSize] gives, and it is **two
  /// points smaller** than the hero's because the duty card's own type is
  /// smaller and a mark that outweighs its title reads as the title's
  /// decoration.
  static const double dutyMarkSize = 20;

  /// The hero panel's gold wash — the prototype's own alpha.
  ///
  /// `redesign.html:263` is `.selah.active{background:rgba(232,176,75,.06);
  /// border-color:rgba(232,176,75,.5)}` — the redesign's **own** statement of
  /// what a highlighted surface looks like, and the only one in the file. The
  /// hub's hero card is that shape: a tinted surface whose rim is the same
  /// gold, half as strong as the wash's source.
  static const double heroFillAlpha = 0.06;

  /// The hero panel's gold rim — the prototype's own alpha.
  ///
  /// `redesign.html:263`'s `border-color:rgba(232,176,75,.5)`.
  ///
  /// **AND THE RIM'S CONTRAST, MEASURED**, because a rim is the one thing on
  /// this card that is *not* legible text and therefore has no ink token
  /// behind it:
  ///
  /// | | the hero's rim against the canvas | the app's own `glassBorder` against the canvas |
  /// | --- | --- | --- |
  /// | dark | **3.21:1** | 1.01:1 |
  /// | light | **1.60:1** | 1.19:1 |
  ///
  /// **So the hero's rim is stronger than the design system's own panel rim in
  /// both palettes** — and the light figure is the honest one: **1.60:1** is
  /// under the 3:1 WCAG asks of a *component boundary*, and the light palette's
  /// panel rims have never reached it (`glassBorder` is 1.19:1 on every
  /// panel in the app).
  ///
  /// **What carries the hero in the light palette is not its rim.** It is the
  /// wash under it and the **mark's glyph**, which measures **5.26:1** against
  /// that wash (`emberInk` over the gold surface) and **8.66:1** in dark. The
  /// rim is decoration around a mark and a wash that are both legible, and
  /// the numbers are here so a reader can check that claim rather than take
  /// it.
  ///
  /// The alternative — a rim strong enough to clear 3:1 in the light palette
  /// — would need a **new token**: `ember` and `emberInk` are the only two
  /// golds the palette publishes, and `emberDeep` at full strength is a
  /// different colour in the dark palette. The design spec's *"no new
  /// tokens"* rule is what decides it, and the measurement is what says the
  /// decision is a recorded one rather than an unnoticed one.
  static const double heroBorderAlpha = 0.5;

  /// The hero mark's rim — a little under the panel's own.
  ///
  /// **Written, not transcribed**: the prototype's `.selah.active` has no mark
  /// in it, so there is no number to transcribe. It is the panel's rim alpha
  /// less a tenth, because the mark's rim sits *inside* the panel and a mark
  /// ruled as strongly as the panel's own edge would read as a second border
  /// around the same shape.
  ///
  /// **AND IT IS A **DECORATION**, measured: the mark's rim against the
  /// hero's own surface is **2.45:1** in dark and **1.42:1** in light — and
  /// the mark is identified by its **glyph**, which measures **8.66:1** and
  /// **5.26:1** against that surface. A faint rule around a legible mark is a
  /// frame; a faint rule around nothing would be the defect.
  static const double heroMarkBorderAlpha = 0.42;

  /// The gap between the hero's mark and its text.
  static const double heroGap = EvaSpacing.md;

  /// The gap between the duty card's mark and its title.
  static const double dutyGap = EvaSpacing.sm;

  /// The gap between the duty card's first row and its explanation.
  static const double dutyDescriptionGap = EvaSpacing.sm;

  /// The gap between the exit row's mark and its text.
  static const double exitGap = EvaSpacing.md;

  /// The gap between the exit row's title and the chevron.
  static const double exitChevronGap = EvaSpacing.sm;

  /// How far the exit row's chevron is nudged down to sit on the title's
  /// line.
  ///
  /// **Two pixels, and it is half a difference rather than a design number.**
  /// The title is 14px type in a line box about 20px tall and the chevron's
  /// box is 16px, so top-aligning the two puts the chevron's centre 2px above
  /// the title's. Half the difference is the whole correction.
  static const double exitGlyphOffset = 2;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return switch (style) {
      ServantHubCardStyle.hero => _hero(context, colors, direction),
      ServantHubCardStyle.duty => _duty(context, colors, direction),
      ServantHubCardStyle.exit => _exit(context, colors, direction),
    };
  }

  /// The day's primary destination: a tinted panel, a mark, and the day's work.
  Widget _hero(
    BuildContext context,
    EvaColors colors,
    TextDirection direction,
  ) => GlassSurface(
    // [GlassTier.tint] — which is [GlassSurface]'s own default, so it is
    // not written out here — and **never** [GlassTier.blur]: §13.4's
    // budget is **one** blur in `lib/features/` and the home screen's
    // today's-reading panel has it. A second one would be a frame-budget
    // change wearing a style change's clothes.
    radius: heroRadius,
    padding: const EdgeInsets.all(heroPadding),
    // **THE GOLD WASH AND THE GOLD RIM, FROM THE REDESIGN'S OWN RULE.**
    // `redesign.html:263`.
    //
    // **`EvaColors.ember` and not `emberInk`**, and the reason is decision
    // 153's own split: *"ember fills, emberInk writes."* A wash and a rim are
    // **fills** — they are the surface, not the writing on it — and
    // `emberInk` is the palette's darker gold, which exists so that gold can
    // clear AA **as text** on a pale ground. A rim is not text.
    //
    // The two are the same value in **dark** (`ember` and `emberInk` are both
    // `#E8A33D` there), so this changes the light palette only — and it
    // changes it in the direction that matters: `emberInk`'s `#845610` at 6%
    // over the light canvas is a warm grey, and at 50% it is a thin brown
    // line, so the hero panel read as a slightly stained card rather than as
    // a gold one. `ember`'s `#D4891A` is the palette's **fill** gold, and it
    // carries the same hue the dark palette's does.
    fill: colors.ember.withValues(alpha: heroFillAlpha),
    borderColor: colors.ember.withValues(alpha: heroBorderAlpha),
    onTap: onTap,
    // **The empty string, not the title.** The card's own children name it,
    // and `GlassSurface`'s doc says so: a surface whose child draws a title
    // and a line is *already* named by them, and naming it again repeats
    // all of it.
    semanticLabel: '',
    child: Row(
      children: <Widget>[
        _Mark(
          icon: icon,
          box: heroMarkBox,
          glyphSize: heroMarkSize,
          radius: EvaRadii.button,
          // **THE GLYPH IS `emberInk` AND THE TILE'S RIM IS `ember`,** and
          // that split is decision 153's own rule rather than a taste: a
          // glyph is *writing* and a rim is a *surface*. The two are the same
          // value in dark, so this moves the light palette only — and it
          // moves it because `ember`'s `#D4891A` measures about 2:1 against
          // the light canvas, which is under the 3:1 that WCAG asks of a
          // meaningful glyph, while `emberInk`'s `#845610` measures 5.54:1.
          ink: colors.emberInk,
          rim: colors.ember.withValues(alpha: heroMarkBorderAlpha),
        ),
        const SizedBox(width: heroGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                // **The display serif, at the size of a heading.** The
                // portal's hero is the one place on this screen that says
                // something in the app's own voice — the same voice as the
                // reader's greeting on `/` — and the duty cards below it
                // are the app's working voice.
                style: arabicAware(
                  Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontFamily: EvaTypography.scriptureFamily,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                  direction,
                ),
              ),
              const SizedBox(height: EvaSpacing.xs),
              Text(
                description,
                style: arabicAware(
                  Theme.of(context).textTheme.bodyMedium!,
                  direction,
                ).copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(width: EvaSpacing.sm),
        // **THE HERO'S POINTER IS GOLD.** The hero is the day's one primary
        // destination, and its chevron says so in the accent the panel is
        // already washed with.
        _Chevron(color: colors.emberInk),
      ],
    ),
  );

  /// One of the admin's duties: a smaller panel, and a different layout.
  Widget _duty(
    BuildContext context,
    EvaColors colors,
    TextDirection direction,
  ) => GlassSurface(
    // **The radius is [GlassSurface]'s own default, which is
    // [EvaRadii.card]** — the design system's radius for cards, and this
    // is one. It is not written out because writing it out would be an
    // argument that matches the default, and the lints are right about
    // that; the constant that *is* written out is [heroRadius], because
    // the hero panel's radius is a different one.
    padding: const EdgeInsets.all(dutyPadding),
    onTap: onTap,
    semanticLabel: '',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            // **A bare glyph, and not a marked tile.** The hero's mark is a
            // 46px ruled box because the hero is a panel; the duty card is
            // a panel too, and a ruled box inside a ruled panel is one
            // border around another border. So the duty's mark is the
            // glyph itself, and the card's own rim is the frame.
            Icon(icon, size: dutyMarkSize, color: colors.ink2),
            const SizedBox(width: dutyGap),
            Expanded(
              child: Text(
                title,
                style: arabicAware(
                  Theme.of(context).textTheme.titleSmall!
                      .copyWith(fontWeight: FontWeight.w600, color: colors.ink),
                  direction,
                ),
              ),
            ),
            const SizedBox(width: EvaSpacing.sm),
            _Chevron(color: colors.ink2),
          ],
        ),
        const SizedBox(height: dutyDescriptionGap),
        // **At the card's own left edge, and not in a column beside the
        // mark.** That is the whole difference between this card and the
        // hero: the hero's words sit in a column beside its mark, and this
        // one's sit under its title, aligned to the panel.
        Text(
          description,
          style: arabicAware(
            Theme.of(context).textTheme.bodySmall!,
            direction,
          ).copyWith(color: colors.ink2),
        ),
      ],
    ),
  );

  /// The way back to the reader's own shell — a flat row, and not a panel.
  Widget _exit(
    BuildContext context,
    EvaColors colors,
    TextDirection direction,
  ) => Semantics(
    button: true,
    // The empty string, for the reason the panels' is empty: the row's own
    // words name it.
    label: '',
    child: EvaFocusRing(
      // **Zero, and not a radius.** The row has no corners of its own —
      // the rule above it is the screen's, not the row's — so a ring
      // rounded to the card radius would draw corners the row does not
      // have. `SettingsTile` makes the same argument for the same reason.
      radius: 0,
      child: EvaInk(
        onPressed: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: EvaSpacing.md),
          child: Row(
            // **THE ROW'S OWN FIRST LINE, AND NOT THE MIDDLE OF THE BLOCK.**
            // The exit row carries a title and a line under it, and a mark
            // and a chevron centred against that whole block float between
            // the two lines — which reads as a control that belongs to
            // neither. Aligned to the top, they belong to the title, and the
            // title is what they are about.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: dutyMarkSize, color: colors.ink2),
              const SizedBox(width: exitGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: arabicAware(
                        Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: colors.ink2),
                        direction,
                      ),
                    ),
                    const SizedBox(height: EvaSpacing.xs),
                    Text(
                      description,
                      style: arabicAware(
                        Theme.of(context).textTheme.bodySmall!,
                        direction,
                      ).copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: exitChevronGap),
              // **THE CHEVRON IS **NUDGED DOWN** BY HALF THE DIFFERENCE**
              // between its box and the title's line box. The title is 14px
              // type and its line box is about 20px tall; the chevron's box
              // is 16px. Top-aligned, the chevron's centre would sit 2px
              // above the title's, and 2px is the kind of difference that
              // reads as a mistake rather than as a measurement.
              Padding(
                padding: const EdgeInsets.only(top: exitGlyphOffset),
                child: _Chevron(color: colors.ink2),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The card's mark: a ruled square holding a glyph.
///
/// ## AND WHY IT IS **ITS OWN WIDGET** AND NOT A PRIVATE ONE
///
/// Because the hero's mark and the duty card's mark are **not the same
/// thing** — one is a 46px ruled tile, the other is a bare 20px glyph — and a
/// private helper that drew both would need a flag for every property it has,
/// which is the shape a `variant` enum exists to prevent.
///
/// It is **private** rather than public because it is the hero's mark only:
/// the duty card draws its own bare glyph, so this widget has exactly one
/// caller, and a private widget cannot be an orphan (§ the orphan gate's
/// inventory holds public classes only).
class _Mark extends StatelessWidget {
  const _Mark({
    required this.icon,
    required this.box,
    required this.glyphSize,
    required this.radius,
    required this.ink,
    required this.rim,
  });

  /// The glyph.
  final IconData icon;

  /// The tile's side.
  final double box;

  /// The glyph's size.
  final double glyphSize;

  /// The tile's corner radius.
  final double radius;

  /// The glyph's ink.
  final Color ink;

  /// The tile's rim.
  final Color rim;

  @override
  Widget build(BuildContext context) => Container(
    width: box,
    height: box,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: rim),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: glyphSize, color: ink),
  );
}

/// The trailing glyph of a card that opens something.
///
/// ## AND WHY IT **FLIPS** ON THE ARABIC ARM
///
/// Material's chevrons do not flip by themselves, and a chevron that points
/// the wrong way in a right-to-left screen is the same class of defect as
/// an Arabic run drawn in a Latin face: the layout assumes a direction it
/// does not have. So the glyph is chosen from the ambient direction — the
/// same rule `SettingsTile`'s own callers follow, and the reason the hub's
/// own chevron was a private widget there.
///
/// ## AND WHY THE INK IS **THE CALLER'S**
///
/// Because a chevron is a **meaningful glyph**, not a decoration, and the
/// design system has one ink for those: `IconActionButton` draws an enabled
/// glyph in `ink2` and only falls to `ink3` when the control is **disabled**.
///
/// **And `ink3` is not an option here**, measured: `ink3` is **1.65:1** on
/// dark glass and **2.08:1** on light glass, and
/// `text_contrast_gate_test.dart` carries both numbers on its
/// known-substandard ledger — which is the ledger of the pairs that are
/// *allowed* to be that faint, not a list of pairs nobody has looked at. A
/// chevron is the whole card's affordance, and an affordance nobody can see
/// is not an affordance.
///
/// The hero's chevron is **gold** — `emberInk`, which is the palette's gold
/// that clears AA as a mark (5.54:1 in light, 6.97:1 in dark) — because the
/// hero is the day's one primary destination and its pointer says so.
class _Chevron extends StatelessWidget {
  /// A chevron in [color].
  const _Chevron({required this.color});

  /// The glyph's ink.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? Icons.chevron_left : Icons.chevron_right,
      size: EvaSpacing.lg,
      color: color,
    );
  }
}
