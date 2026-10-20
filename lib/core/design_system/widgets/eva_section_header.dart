import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which of the two prototype section labels this is.
///
/// `04-widget-inventory.md` §6 consolidates the shared `SectionLabel` with the
/// feature-local `ScreenSectionHeader` into one widget with a `size` variant,
/// because the two differ in nothing a caller would want to spell.
///
/// The prototypes disagree on more than size, though, and the difference is
/// recorded rather than averaged:
///
/// | | `SectionLabel` | `ScreenSectionHeader` |
/// | --- | --- | --- |
/// | source | the prototype's `SectionLabel` → **`redesign.html:30-31`, `:422`** | the prototype's profile and home screen headings — **the redesign has no counterpart**, because the profile screen was cut |
/// | family | `F.mono` | `F.ui` |
/// | size | 9 → **10.5** | 16–17 |
/// | ink | `ink3` → **`ink2` → gold** | `ink` |
///
/// The Settings label is the one with a surviving call site — the profile screen
/// was cut — so [section] is the mono-caps form and is the default. [title] is
/// the bold UI form, for a header that introduces a screen rather than a group
/// inside one.
///
/// ## THE INK WALKED THROUGH THREE VALUES AND ONLY THE LAST ONE IS THE
/// PROTOTYPE'S
///
/// The prototype's `SectionLabel` said `T.ink3`. Decision 149 moved it to `ink2`,
/// because `ink3` measures 1.65:1 on dark glass and a heading is content, not
/// decoration — that move was a **contrast** decision and it was right. Phase
/// 4.2 moved it again, to [EvaColors.emberInk], because that is what
/// `redesign.html:31`'s `.mono b` is and gold is what the redesign's settings
/// page is made of.
///
/// It is worth being explicit that 149's argument does not survive, because it
/// is the kind of argument that gets cited later without being re-checked: gold
/// measures **6.97:1** on the worst dark surface and `emberInk` **5.54:1** in
/// light, so the label is *more* legible than the `ink2` decision 149 put it on,
/// not less. The decision 149 rejected was `ink3`, and nothing here is `ink3`.
///
/// ## SEVEN GOLD LABELS ON `/settings` IS A DESIGN CALL, NOT A TRANSCRIPTION
///
/// `redesign.html` has **seven** `.sgroup` elements (`:645`, `:649`, `:651`,
/// `:666`, `:682`, `:690`, `:696`), so `/settings` ships seven of these. This
/// said "eight" and then listed seven — the list was always right and the count
/// was not, which is the shape a claim takes when it is written from memory and
/// checked against nothing.
///
/// Whether seven gold labels stacked down one screen reads as a section index or
/// as a ransom note is a question about the composition, and the prototype is the
/// only evidence available — it chose gold for its own headings at `:39`
/// (`.rail h4`). Recorded so that a reader who thinks it is too much knows it was
/// **looked at** and not **overlooked**, and so that changing it later is a
/// decision someone makes on purpose.
///
/// **The gold is a decision, not a transcription.** The section variant's own
/// comment says so at length; the short form is that `.mono` (`:30`) says
/// `ink2`, `.mono b` (`:31`) needs a `<b>` that no `.sgroup` contains, and `:39`
/// is the prototype's mono-caps gold heading.
enum EvaSectionHeaderSize {
  /// The Settings group label: `.mono` from `redesign.html:30`, and **gold by
  /// decision** on the evidence of `:39` — not from `:31`, which does not apply.
  section,

  /// A screen title inside a body: UI sans, bold, `ink` — the prototype's profile
  /// screen heading, which **the redesign has no counterpart for**.
  title,
}

/// A label above a block of content.
///
/// **The §3.1 deletion test is DEFERRED, not passed.** `04-widget-inventory.md`
/// §3.1 puts this widget on the demotion watch list: the Library and Profile cuts
/// left it with **one** shared call site, below the two-call-site bar §3.1 sets,
/// and says "Phase 1 must re-run the deletion test on all six and demote whatever
/// complexity does not reappear — most likely to a private `_`-prefixed widget
/// inside the feature that owns the single call site".
///
/// Phase 1 did not re-run it and no phase since has either, because **there is
/// still nowhere to put the result**: all four watch-list widgets below are used
/// only by the stub `SettingsPage`, and moving one into a feature that does not
/// use it would be inventing a call site to satisfy a rule rather than satisfying
/// the rule. Phase 5 built `features/auth/` and gave this widget no second caller
/// — the login screen needs a heading, not a section label — so the earlier
/// version of this comment, which said "no feature exists until Phase 5", stopped
/// being true at the end of that phase without this paragraph being updated.
/// It ships public, with the deferral recorded here rather than a passing claim
/// attached to it. Re-run it when `SettingsScreen` lands and the page it is
/// demoted into actually imports the widget.
///
/// Four of the six watch-list entries are in this phase — `SettingsGroup`,
/// `EvaSectionHeader`, `TextLink`, `ProgressBeads` — and all four say the same
/// thing here. `AvatarBadge` shipped in Phase 2 with the same note.
class EvaSectionHeader extends StatelessWidget {
  /// A header labelled [label], optionally with [trailing] on the right.
  const EvaSectionHeader({
    required this.label,
    this.size = EvaSectionHeaderSize.section,
    this.trailing,
    super.key,
  });

  /// The header's text.
  final String label;

  /// Which of the two prototype labels this is.
  final EvaSectionHeaderSize size;

  /// A control on the right — the prototype's screen headers put a "See all"-style
  /// affordance there. `null` for the Settings group labels.
  final Widget? trailing;

  /// The [EvaSectionHeaderSize.section] label's size. `redesign.html:30` —
  /// `font-size:10.5px`.
  ///
  /// Was `9` under the prototype's `SectionLabel`, and `12` in practice: the widget
  /// drew
  /// [EvaTypography.monoCaps], which is `labelMedium`'s geometry, so the shipped
  /// label was neither prototype number until Phase 4.2 named one.
  static const double sectionSize = 10.5;

  /// The [EvaSectionHeaderSize.section] label's tracking. `redesign.html:30` —
  /// `letter-spacing:.16em`.
  static const double sectionTracking = 0.16;

  /// The prototype's `marginBottom: 10`, which is
  /// [EvaSpacing.md] + [EvaSpacing.xs].
  static const double bottomGap = EvaSpacing.md + EvaSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    final Text header = Text(
      // The prototype's `textTransform: 'uppercase'`. Flutter's `Text`
      // has no `textTransform`, so the transform is applied to the string. It is
      // applied **here** rather than inside the style switch because it changes
      // the glyphs, not the style, and a header that measured differently per
      // variant would be a layout surprise.
      size == EvaSectionHeaderSize.section ? label.toUpperCase() : label,
      // ## `arabicAware` WRAPS **BOTH** ARMS, AND ONLY NOW DOES IT MATTER
      //
      // The Arabic typography gate reads the *painted* family of every Arabic run, and
      // for six phases this widget was only ever pumped with Latin text: `SettingsGroup`
      // is the sole caller and `/settings` was a stub. Phase 9 wrote the screen, and the
      // gate immediately reported `SpaceMono المظهر` — a section header painting Arabic
      // in the mono-caps family, because `monoCaps` names SpaceMono and nothing asked
      // for Amiri.
      //
      // The swap belongs **here** rather than at the call site for the same reason
      // `reading_text_scale.dart` had to be deleted rather than composed at the call
      // site: this widget owns the text, so it owns the family that renders it. A
      // caller that remembered to wrap would be a per-call-site tax on a rule that is
      // not the caller's to remember.
      style: arabicAware(switch (size) {
        // `redesign.html:30` — `.mono{font-family:var(--mono);font-size:10.5px;
        // letter-spacing:.16em;text-transform:uppercase;color:var(--ink-2)}`.
        //
        // ## THE COLOUR IS A **DESIGN DECISION**, NOT A TRANSCRIPTION — AND THE
        // CITATION THIS USED TO GIVE DOES NOT SAY IT
        //
        // This block used to read "the gold is `:31`'s" — `.mono
        // b{color:var(--gold);font-weight:600}` — which was **not** a
        // transcription and was not verifiable:
        //
        // * `redesign.html` has **seven** `<div class="sgroup mono">` elements
        //   (`:645`, `:649`, `:651`, `:666`, `:682`, `:690`, `:696`).
        // * **None contains a `<b>`.** Measured: zero matches over those seven.
        //   `:31` styles a `<b>` **child**, so here it has no subject at all.
        // * `:30` therefore applies unmodified, and it ends
        //   `color:var(--ink-2)`. The label was **`ink2`** in the prototype and
        //   Phase 4.2 **changed** it.
        //
        // A citation that resolves and is about the wrong line is exactly what
        // `eva_text_field.dart:300-305` refuses to accept, so the old sentence is
        // replaced rather than softened.
        //
        // **What the gold rests on instead.** `redesign.html:39` —
        // `.rail h4{font-family:var(--mono);font-size:10px;letter-spacing:.2em;
        // color:var(--gold);text-transform:uppercase;margin-bottom:8px}` — is the
        // prototype's own **mono-caps gold section heading**, and a `.sgroup`
        // label is that same role in another part of the screen. So the design
        // language is **mono caps in gold mark section structure** (§5.1 makes
        // gold the structural accent, and `:420` gives the same gold to a hovered
        // `.srow`). Painting the section label that way **widens `:39`'s role**,
        // deliberately; it is not a reading of `:31`.
        //
        // Stated here because a reader who knows only `:30` will fairly ask why
        // the prototype's `ink2` is not what this paints, and because if the
        // decision is reversed the thing to change is **this paragraph**, not
        // `:31`.
        //
        // `letterSpacing` is the em value **premultiplied by the size**, because
        // Flutter's is a logical-pixel advance and CSS's is relative to the
        // element's own font: `.16em` at 10.5px is 1.68. `EvaTypography.monoCaps`
        // deliberately leaves Material's `labelMedium` tracking alone (§5.2 gives
        // `mono` no tracking), which is why this reads as a much wider label than
        // the 0.5 that slot carries.
        //
        // **AND IT IS **ZERO** UNDER RTL**, which is `eva/redesign.html:135`:
        // `[dir=rtl] .mono{letter-spacing:0}`. Task 5.7 found this by
        // comparison rather than by reading — the Workshop's own version chip
        // follows `:135` (the prototype's `.mono` tracking is zeroed under RTL
        // everywhere, and the chip is a `.mono` span), and the group headers
        // under it did not, so **one screen was rendering two `.mono` runs two
        // different ways**. The prototype's rule is one rule for the whole
        // `.mono` class, and the tracking is zeroed under RTL.
        //
        // **It IS ALSO THE RIGHT THING FOR THE SCRIPT.** Under RTL this label
        // is Arabic, and Arabic script does not take letter-spacing well — the
        // prototype's own zeroing is a typographic decision and not only a
        // mirror one.
        //
        // `weight: w400`, because `:30` declares no weight on the element this
        // widget paints, and the prototype **is** explicit about weight when it
        // wants one (`:39` declares none for `.rail h4`; `:185` `.segp
        // button.on` does). Silence there is `normal`, and the redesign's small
        // mono labels are quiet — the `600` on `:31` belongs to a `<b>` this
        // label is not.
        EvaSectionHeaderSize.section => EvaTypography.monoCaps(colors).copyWith(
          fontSize: sectionSize,
          letterSpacing: Directionality.of(context) == TextDirection.rtl
              ? 0
              : sectionSize * sectionTracking,
          color: colors.emberInk,
          fontWeight: FontWeight.w400,
        ),
        // The prototype's profile-screen heading — `F.ui, 16, 700, color: T.ink`.
        // `titleMedium`
        // is Material 3's 16sp slot, so the prototype's 16 lands exactly. **Kept,
        // not re-pointed**: the redesign has no screen-title role, because the
        // profile screen it belonged to was cut.
        EvaSectionHeaderSize.title =>
          Theme.of(context).textTheme.titleMedium!
              .copyWith(color: colors.ink, fontWeight: FontWeight.w700),
      }, Directionality.of(context)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final Widget? control = trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: control == null
          ? header
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: header),
                const SizedBox(width: EvaSpacing.sm),
                // `Flexible`, not a bare child. `RenderFlex` hands an **inflexible**
                // child unbounded width when the row has a flex child, so a
                // `trailing` widget laid out at its intrinsic width came out
                // 336 wide on a 320 screen and overflowed by 24px. Found by
                // `surfaces_test.dart`, not by reading the code.
                Flexible(child: control),
              ],
            ),
    );
  }
}
