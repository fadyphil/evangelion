import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/material.dart';

/// Which of the three prototype buttons this is.
///
/// `eva/src/components/ds.tsx` declared `ButtonPrimary` (:222-250),
/// `ButtonSecondary` (:253-268) and `ButtonText` (:271-286) as three separate
/// components with three separate CSS blocks. `04-widget-inventory.md` §3
/// collapses them into one widget across eight surviving call sites, and this
/// enum is the collapse.
///
/// ## THE ROLE MAPPING, AND IT IS A **ROLE** MAPPING, NOT A LINE MAP
///
/// `ds.tsx` drew buttons out of a React library. `redesign.html` draws them out
/// of a static HTML page, and it has **five** button rules, not three:
///
/// | `EvaButtonVariant` | `redesign.html` | what the rule is |
/// | --- | --- | --- |
/// | `primary` | `.cta` `:381-386`, `.rcta` `:458-462` | filled gold, `999px` pill, `::after` ripple |
/// | `secondary` | **`.qnext` `:363-368`** | transparent, 1px gold rim, gold ink, pill |
/// | `ghost` | `.ghosts button` `:388-390` | transparent, `--glass-line` rim, `--ink-1` ink, pill |
///
/// The collapse is **three to three only because `redesign.html` merges `.cta`
/// and `.rcta`** (they differ in `padding` 16 vs 15 and the ripple's alpha
/// `.65` vs `.7` and its period 2.4s vs 2.2s, and in nothing a reader can
/// name), and because `ds.tsx`'s `ButtonSecondary` and `ButtonText` collapse
/// the other way — into **one** redesign rule each, from two. So this is a
/// **role** mapping: the enum answers "which of the page's three action roles
/// is this", and the citation answers "which CSS block draws that role".
///
/// `secondary` → `.qnext` is recorded as decision 1 in the Task 4.2 status
/// block. It changes the role from an `ink`-at-20% rim to a **gold** rim; see
/// [EvaButtonVariant.secondary] and [resolveButtonStyle].
enum EvaButtonVariant {
  /// Filled `ember`, `onEmber` ink, the two-part ember glow, and `.cta`'s
  /// expanding ring.
  primary,

  /// `.qnext` (`redesign.html:363-368`) — transparent, a 1px **gold** rim, gold
  /// ink, a pill, and a gold wash on hover.
  ///
  /// ## THIS IS A RE-ROLE, NOT A RECOLOUR, AND IT IS RECORDED AS ONE
  ///
  /// The widget used to draw `ds.tsx:253-268`'s `ButtonSecondary`: a 1.5px rim
  /// in `ink` at 20%, `ink` ink. The redesign has no such rule. Its two
  /// rimmed-but-unfilled pills are `.qnext` (gold rim, gold ink) and
  /// `.ghosts button` (`--glass-line` rim, `--ink-1` ink), and **`secondary`
  /// maps to the gold one** — decision 1 of the Task 4.2 status block, whose
  /// reasoning is that the redesign has exactly three action roles and this is
  /// the second.
  ///
  /// So the rim's hue and width both move, and the *shape* is a pill rather
  /// than `EvaRadii.button`. Only the **fill** is unchanged: `transparent` in
  /// `ds.tsx:260` and in `redesign.html:363`.
  secondary,

  /// `.ghosts button` (`redesign.html:388-390`) — transparent, a
  /// `--glass-line` rim, `--ink-1` ink, a pill, and gold on hover.
  ///
  /// `ds.tsx`'s `ButtonText` was `background: none; border: none` with `T.ink`
  /// and no hover at all, so the rim is new: the redesign's bare-ink pill has
  /// one, and a bare run of text in a pill-shaped box with no edge does not read
  /// as a button on any of the three surfaces this control appears on.
  ///
  /// The trailing `›` the prototype's `ButtonText` carried (`ds.tsx:283`) is
  /// [EvaButton.trailingChevron] and still is — the redesign's ghosts carry no
  /// glyph, so nothing here was invented to keep it and nothing removed it.
  ghost,
}

/// The fill, ink, rim and glow for one [EvaButtonVariant], idle and hovered.
///
/// Extracted from the widget because §6 says a widget's conditionals are not
/// where logic lives, and because the prototype's numbers are in CSS and would
/// otherwise be retyped at each of eight call sites' worth of widgets.
///
/// ## WHY THE HOVER HALF IS A FIELD AND NOT A `setState` IN THE WIDGET
///
/// `redesign.html` gives two of the three roles a `:hover` rule and they do not
/// agree: `.qnext:hover` (`:368`) is a **fill**, `.ghosts button:hover` (`:390`)
/// and `.rghost:hover` (`:465`) are an **ink**. One variant is a fill hover and
/// another is an ink hover, so whichever mechanism carried it had to carry both,
/// and a second `MouseRegion`-owned `_hovered` flag per role is exactly the
/// duplication this class exists to remove.
@immutable
class EvaButtonStyle {
  /// A button treatment.
  const EvaButtonStyle({
    required this.background,
    required this.pressedBackground,
    required this.hoverBackground,
    required this.foreground,
    required this.hoverForeground,
    required this.border,
    required this.hoverBorder,
    required this.glow,
    required this.pressedGlow,
  });

  /// The resting fill.
  final Color background;

  /// The fill while pressed. Equal to [background] where the prototype has no
  /// pressed state — see [resolveButtonStyle].
  final Color pressedBackground;

  /// The fill under the pointer. Equal to [background] wherever the prototype
  /// declares no `:hover` fill.
  final Color hoverBackground;

  /// The label's ink.
  final Color foreground;

  /// The label's ink under the pointer. Equal to [foreground] wherever the
  /// prototype declares no `:hover` ink.
  final Color hoverForeground;

  /// The resting rim, drawn by the enclosing [EvaFocusRing]. `null` is a real
  /// value: `.cta` is `border: none` (`redesign.html:381`).
  final Border? border;

  /// The rim under the pointer. Equal to [border] wherever the prototype
  /// declares no `:hover` border — which is [border] being `null`.
  final Border? hoverBorder;

  /// Shadows over the resting fill.
  final List<BoxShadow> glow;

  /// Shadows over the pressed fill. Empty wherever the prototype writes
  /// `box-shadow: pressed ? 'none' : …`.
  final List<BoxShadow> pressedGlow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaButtonStyle &&
          other.background == background &&
          other.pressedBackground == pressedBackground &&
          other.hoverBackground == hoverBackground &&
          other.foreground == foreground &&
          other.hoverForeground == hoverForeground &&
          other.border == border &&
          other.hoverBorder == hoverBorder &&
          listEquals(other.glow, glow) &&
          listEquals(other.pressedGlow, pressedGlow);

  @override
  int get hashCode => Object.hash(
    background,
    pressedBackground,
    hoverBackground,
    foreground,
    hoverForeground,
    border,
    hoverBorder,
    Object.hashAll(glow),
    Object.hashAll(pressedGlow),
  );
}

/// Resolves the treatment for [variant] in [colors].
///
/// ## THE TWO VALUES THAT ARE NOT THE PROTOTYPE'S
///
/// `redesign.html:381` writes `.cta`'s ink as the literal `#1c1608`, which is
/// near-black. On the light palette that is dark ink on a mid-tone amber and
/// reads as muddy rather than as a label. `03-design-system.md` §5.1 names
/// `onEmber` as `EvaButton.primary`'s foreground and Phase 1 measured both
/// pairings against WCAG 2.x (AGENT_CONTEXT §6 decision 6): `onEmber` is
/// 9.17:1 in dark and 5.41:1 in light. The token is used, and the prototype's
/// value is recorded here rather than inherited.
///
/// The second is the **ghost's ink**. `redesign.html:389` writes
/// `color: var(--ink-1)`, and `--ink-1` is `#A9B0C8` — the token this system
/// publishes as `ink2`, not `ink`. `IconActionButton` made the same
/// identification from `redesign.html:151` and `redesign.html:463`, so this is
/// the third widget to make it and the third time it has been the *secondary*
/// ink rather than the primary one.
///
/// ## WHAT IS **NOT** INVENTED FOR ANY OF THE THREE
///
/// `.cta` (`:381`) and `.qnext` (`:363`) both declare a `transition` on `all`
/// properties and only `.qnext` declares a `:hover` at all, so [primary] has no
/// hover fill and no hover ink. That is not an omission, it is the transcription:
/// [EvaButtonStyle.hoverBackground] and [EvaButtonStyle.hoverForeground] are the
/// honest identity there.
EvaButtonStyle resolveButtonStyle({
  required EvaButtonVariant variant,
  required EvaColors colors,
}) => switch (variant) {
  EvaButtonVariant.primary => EvaButtonStyle(
    // `redesign.html:381` — `background: var(--gold)`.
    background: colors.ember,
    // The pressed fill is the **old** prototype's, and deliberately so:
    // `redesign.html` has no `:active` fill for `.cta` at all — its only
    // `:active` rule is `transform: scale(.97)` (`:384`), which is paint. So
    // `emberDeep` is a surviving `ds.tsx:239` value, and "the redesign dropped
    // it" is not a reason to drop the state a reader's thumb is on.
    pressedBackground: colors.emberDeep,
    // `redesign.html:381` writes no `:hover` fill for `.cta`, so this is the
    // identity rather than an invented second value.
    hoverBackground: colors.ember,
    foreground: colors.onEmber,
    // Likewise no `:hover` ink. See [EvaButtonStyle.hoverForeground].
    hoverForeground: colors.onEmber,
    // `redesign.html:381` — `border: none`.
    border: null,
    hoverBorder: null,
    // `ds.tsx:244` —
    //   `0 0 28px rgba(ember, .35), 0 4px 14px rgba(ember, .25)`.
    //
    // **Kept, and this is the one number with no redesign line at all.** The
    // redesign's `.cta` declares no `box-shadow`; the ring it draws is the
    // `::after` (`:385`), which is a separate element rather than a shadow. So
    // the glow is a *surviving* `ds.tsx` value, kept because a filled gold
    // button that emits no light at all is a different product, and recorded
    // here rather than quietly re-attributed to a line that does not say it.
    //
    // Not an elevation ramp either: AGENT_CONTEXT §6 decision 7 froze every
    // Material elevation at 0 because the prototype has no z-axis, and this pair
    // is quoted straight out of one declaration. The second shadow's `4px`
    // offset is the only thing in the whole design system with a non-zero,
    // non-ambient shadow offset, and it exists because the prototype wrote it.
    glow: <BoxShadow>[
      BoxShadow(color: colors.ember.withValues(alpha: 0.35), blurRadius: 28),
      BoxShadow(
        color: colors.ember.withValues(alpha: 0.25),
        offset: const Offset(0, 4),
        blurRadius: 14,
      ),
    ],
    // `ds.tsx:244` — `pressed ? 'none'`.
    pressedGlow: const <BoxShadow>[],
  ),
  EvaButtonVariant.secondary => EvaButtonStyle(
    // `redesign.html:363` — `background: transparent`.
    background: Colors.transparent,
    pressedBackground: Colors.transparent,
    // `redesign.html:368` — `.qnext:hover{background: rgba(232,176,75,.12)}`.
    //
    // The prototype's `ButtonSecondary` transitioned `border-color` and nothing
    // else (`ds.tsx:264`), so this fill is new, not a transcription — and it is
    // the only hover *fill* in the redesign's five button rules.
    hoverBackground: colors.ember.withValues(alpha: 0.12),
    // `redesign.html:363` — `color: var(--gold)`. Gold ink is `emberInk`
    // rather than `ember`: a label is writing, and Decision 153's rule is that
    // `ember` fills and `emberInk` writes. `IconActionButton`'s `.iconbtn.lit`
    // (`redesign.html:154`) is the same identification on the same page.
    foreground: colors.emberInk,
    // `redesign.html:368` changes the fill and **not** the ink, so this is the
    // identity. The hover's second half — the gold rim — is not implemented;
    // see [EvaButton] on why a rim cannot change under the ring.
    hoverForeground: colors.emberInk,
    // `redesign.html:363` — `border: 1px solid rgba(232,176,75,.55)`.
    //
    // **1px**, where `ds.tsx:261` wrote 1.5px, and gold rather than
    // `ink`-at-20%. Both halves are the role change recorded on
    // [EvaButtonVariant.secondary].
    border: Border.all(
      color: colors.emberInk.withValues(alpha: kEvaButtonGoldRimAlpha),
    ),
    // Identity: `.qnext:hover` (`:368`) declares no `border-color`, unlike
    // `.pctl button:hover` (`:472`), which `.qnext` is not.
    hoverBorder: Border.all(
      color: colors.emberInk.withValues(alpha: kEvaButtonGoldRimAlpha),
    ),
    glow: const <BoxShadow>[],
    pressedGlow: const <BoxShadow>[],
  ),
  EvaButtonVariant.ghost => EvaButtonStyle(
    // `redesign.html:388` — `background: transparent`.
    background: Colors.transparent,
    pressedBackground: Colors.transparent,
    // No `:hover` fill in any of the three ghost rules (`:388-390`, `:463-465`,
    // `:470-472`), so this is the identity.
    hoverBackground: Colors.transparent,
    // `redesign.html:389` — `color: var(--ink-1)`, which is `ink2`. See the
    // class doc: this is the third widget to make that identification and the
    // third time it landed on the secondary ink.
    foreground: colors.ink2,
    // **Gold on hover, and this is a recorded divergence rather than a
    // transcription.** `redesign.html` gives the ghost role **three** hover
    // rules and they disagree:
    //
    // | line | rule | hover |
    // | --- | --- | --- |
    // | `:390` | `.ghosts button:hover` | `color: var(--ink-0)` — one step brighter |
    // | `:465` | `.rghost:hover` | `color: var(--ink-0)` — one step brighter |
    // | `:472` | `.pctl button:hover` | `color: var(--gold)`, `border-color: rgba(232,176,75,.5)` |
    //
    // All three are the same role — a transparent, `--glass-line`-rimmed,
    // `--ink-1`-inked pill with no fill — and the page gives them two different
    // answers. This widget takes **gold**, because that is the one of the three
    // that is an *accent* rather than a step up the same ramp: `--ink-0` on a
    // button already sitting on a `--void-1` page is nearly invisible, which is
    // a hover that costs nothing to look at and therefore says nothing. Gold is
    // `emberInk` for the same reason it is on `.qnext`.
    hoverForeground: colors.emberInk,
    // `redesign.html:388` — `border: 1px solid var(--glass-line)`, which is
    // [EvaColors.glassBorder]. **New**: `ds.tsx:278` was `border: 'none'`, and
    // this is the role re-mapping recorded on [EvaButtonVariant.ghost].
    border: Border.all(color: colors.glassBorder),
    // Identity — see the gold-rim note above; the rim is not implemented.
    hoverBorder: Border.all(color: colors.glassBorder),
    glow: const <BoxShadow>[],
    pressedGlow: const <BoxShadow>[],
  ),
};

/// The pill's corner rounding. `redesign.html:381` — `border-radius: 999px`.
///
/// ## WHY IT IS A CONSTANT HERE AND NOT [EvaRadii.chip]
///
/// The value is `999`, and so is [EvaRadii.chip] — `03-design-system.md` §5.3
/// gives "chips `999` (`Radius.circular(999)`)" and the redesign writes the same
/// number for `.dot` (`:329`), `.iconbtn` (`:151`), `.qnext` (`:363`), `.cta`
/// (`:381`), `.rcta` (`:458`), `.rghost` (`:463`) and `.pctl button` (`:470`).
/// Eight declarations, one number, and §5.3's own gloss is that 999 is not "very
/// round" but "rounder than the longest side", which is how
/// `BorderRadius.circular` is asked to mean a pill.
///
/// So this is not a second `999`; it is that number *named for the role that
/// renamed it*. `EvaRadii.chip` says chips, and the widget it was written for
/// was deleted with the passage library, while `EvaButton` is shipped on four
/// screens.
///
/// ## AND WHAT IT IS **NOT**
///
/// [EvaRadii.button] stays at `14`. That is not timidity: `login_geometry_test`
/// asserts `EvaRadii.button == 14` as a transcription claim against
/// `ds.tsx:240`, and a widget that stopped being 14 without the token moving
/// would make that harness green and false. The old `SocialAuthButton` drew its
/// own box at `EvaRadii.button` and was `login_geometry_test`'s live assertion
/// that the token means something — and the redesign's `/login` deleted that
/// widget, so the token's live assertion is `eva_radii_test.dart`'s now. The two
/// widgets disagreeing was a fact the harness could see, which is the point.
const double kEvaButtonRadius = EvaRadii.chip;

/// `.qnext`'s rim alpha. `redesign.html:363` — `1px solid rgba(232,176,75,.55)`.
///
/// Its own constant because `IconActionButton` publishes the same table for
/// `.iconbtn`'s three rims (`redesign.html:152`, `:154`), and those are **three
/// different alphas** over the same gold. One more alpha over the same gold is
/// one more number, not one more concept.
const double kEvaButtonGoldRimAlpha = 0.55;

/// The prototype's primary/secondary height. `ds.tsx:240,262` — `height: 52`.
///
/// **Kept, deliberately, against the redesign.** `redesign.html:381` gives
/// `.cta` no height at all — `padding: 16px` on an 11px label is the whole of
/// it — so the redesign's button is ~45 tall where this one is 52.
/// `login_geometry_test` asserts `kEvaButtonHeight == 52` as a transcription
/// claim against `ds.tsx:240`, and 52 is also §14's affordance. The divergence
/// is recorded on [EvaButton] rather than chased.
const double kEvaButtonHeight = 52;

/// The prototype's disabled opacity. `ds.tsx:245` — `opacity: disabled ? 0.45`.
///
/// **Kept.** `redesign.html` declares no `:disabled` rule for any of its five
/// buttons, so the redesign says nothing about a disabled control at all —
/// which is a gap in the reference, not a licence to invent a second value or to
/// ship one that is 100% opaque.
const double kEvaButtonDisabledOpacity = 0.45;

/// The prototype's chevron size. `ds.tsx:283` — `fontSize: 16, fontWeight: 700`.
///
/// Still `ds.tsx`'s, because the redesign's ghosts carry no glyph and this is
/// the one thing the old `ButtonText` had that the new one does not. Nothing
/// removed it.
const double kEvaButtonChevronSize = 16;

// ── The `.cta::after` ring ──────────────────────────────────────────────────

/// `.cta::after`'s period. `redesign.html:385` — `animation: ripple 2.4s`.
const Duration kEvaButtonRipplePeriod = Duration(milliseconds: 2400);

/// `redesign.html:234` — `@keyframes ripple{0%{transform:scale(1);opacity:.8}
/// 100%{transform:scale(1.6);opacity:0}}`.
const double kEvaButtonRippleStartScale = 1;
const double kEvaButtonRippleEndScale = 1.6;
const double kEvaButtonRippleStartOpacity = 0.8;

/// The ring's own rim. `redesign.html:385` — `inset: 0`,
/// `border-radius: 999px`, `border: 1.5px solid rgba(232,176,75,.65)`.
const double kEvaButtonRippleWidth = 1.5;
const double kEvaButtonRippleAlpha = 0.65;

/// The ring's paint at one instant of its cycle, as a **pure function** of the
/// phase.
///
/// §6 requires a widget's arithmetic to live in a testable function rather than
/// in a `build`, and this is the arithmetic: two endpoints and a linear ramp
/// between them, transcribed from one CSS rule.
///
/// | `phase` | `scale` | `opacity` |
/// | --- | --- | --- |
/// | `0.0` | `1.0` | `0.8` |
/// | `0.5` | `1.3` | `0.4` |
/// | `1.0` | `1.6` | `0.0` |
///
/// [phase] is clamped to `0…1` rather than wrapped, so a caller that passes a
/// negative elapsed time gets the first frame of the cycle and one that passes
/// `1.0` gets the last — and the wrapping itself is [evaButtonRipplePhase]'s
/// job, where the decision is visible.
({double scale, double opacity}) evaButtonRippleAt(double phase) {
  final double t = phase.clamp(0.0, 1.0);
  return (
    scale:
        kEvaButtonRippleStartScale +
        (kEvaButtonRippleEndScale - kEvaButtonRippleStartScale) * t,
    opacity: kEvaButtonRippleStartOpacity * (1 - t),
  );
}

/// Where [elapsedSeconds] sits in one `2.4s` ring cycle, in `0…1`.
///
/// Wraps, because the prototype's `animation: … infinite` wraps. Reading
/// `NeuralMotionScope`'s `lumen` clock rather than a widget-owned
/// `AnimationController` is what makes that legitimate here at all — see
/// [EvaButton]'s "the ring has no ticker of its own".
double evaButtonRipplePhase(double elapsedSeconds) =>
    (elapsedSeconds * 1000 / kEvaButtonRipplePeriod.inMilliseconds) % 1.0;

/// Three prototype buttons, one widget. Eight surviving call sites.
///
/// ## EVERY INTERACTIVE STATE, AND WHERE EACH ONE COMES FROM
///
/// | state | source |
/// | --- | --- |
/// | shape (a pill) | `redesign.html:381` — `border-radius: 999px` |
/// | the expanding ring | `redesign.html:385` — `.cta::after` |
/// | fill, ink, rim, glow | [resolveButtonStyle] |
/// | hover | `redesign.html:368`, `:389`, `:472` — see the divergence recorded there |
/// | pressed fill | `ds.tsx:239` — `emberDeep`. **No redesign line**; see [resolveButtonStyle] |
/// | pressed glow removal | `ds.tsx:244`. **No redesign line** |
/// | disabled | `ds.tsx:245` — `opacity: 0.45`. **No redesign line** |
/// | focus ring | `09-quality-gates.md` §14 — not in the prototype at all |
///
/// Three rows have no `redesign.html` line and say so in the table rather than
/// inheriting a citation that does not exist. The redesign declares a `:hover`
/// and an `::after` and nothing else; a button needs a pressed state and a
/// disabled state too, and those three rows are where the page is silent.
///
/// ## THE RING HAS NO TICKER OF ITS OWN, AND THAT IS THE INTERESTING PART
///
/// `.cta::after` is `animation: ripple 2.4s … infinite` — an animation that
/// never ends and never stops while the page is mounted. The obvious
/// transcription is an `AnimationController` per button, and it would have been
/// wrong three times over:
///
/// 1. §13.2 mitigation 2 collapsed the prototype's sixty-four animations to
///    **four shared** controllers precisely so that a screen does not create
///    one per element; a ticker per `EvaButton` puts that back, eight times,
///    on four screens.
/// 2. An infinitely-repeating controller makes `pumpAndSettle` time out, and
///    twenty-odd suites across this package settle a press on a button.
/// 3. It would have to answer the platform's reduced-motion setting itself, and
///    `NeuralMotionScope` already owns that answer for every clock in the app.
///
/// So the ring **reads a clock it does not own** — `NeuralMotionScope`'s
/// `lumen`, which is monotonic and unwrapped — and derives its 2.4s cycle from
/// it through [evaButtonRipplePhase]. This is the D3 substitution `EvaNeuralMotion`
/// documents, applied one level down: the prototype's per-element period is not
/// the rate, and the rate is a divisor on a shared clock. A button that has
/// never been mounted and a button on the first frame paint the same ring, which
/// is also what makes the goldens deterministic.
///
/// ## AND THE `Stack` IS `passthrough` AND `Clip.none`, BOTH ON PURPOSE
///
/// `glass_surface.dart` records what the default fit does: `StackFit.loose` is
/// `constraints.loosen()`, and inserting it re-broke the contract every
/// `GlassSurface` consumer relies on — `StatTile` re-rendered at the width of
/// its own captions and a golden moved by 1.20%. So [StackFit.passthrough], which
/// hands the non-positioned child the incoming constraints verbatim and then
/// measures it exactly as the chain before the `Stack` did.
///
/// `Clip.none` is the other half, and it is not optional.
/// `rendering/stack.dart:718` — `if (clipBehavior != Clip.none &&
/// _hasVisualOverflow)` — is where the framework pushes that clip, and the ring
/// at `scale(1.6)` overflows its own box by definition: `inset: 0` is scale 1.0,
/// and the prototype's whole `::after` is the next 60% outward. With the default
/// `Clip.hardEdge` the ring would be cut off at the button's own edge and would
/// look like a slightly thicker border, which is a different effect from the one
/// the prototype draws.
///
/// `Clip.none` clips *nothing* else either: the only children are this
/// decoration and the label, the fill is the enclosing `AnimatedContainer`'s own
/// `BoxDecoration`, and the ink splash is clipped by [EvaInk]'s own
/// `borderRadius` — which this widget now passes, so the splash follows the pill
/// rather than a 14px corner.
///
/// ## THE LABEL TYPE IS **NOT** THE REDESIGN'S, AND THAT IS RECORDED HERE
///
/// `redesign.html:382` sets `.cta`'s label to `mono 11 / .22em / uppercase /
/// w600`, and this widget still renders `titleMedium` at `16 / w700` —
/// `ds.tsx:237`'s values. The delta is the largest between the two prototypes
/// and it is **not** applied, for three reasons that are all mechanical rather
/// than aesthetic:
///
/// 1. **It is RTL-incoherent without a branch this widget's own doc forbids.**
///    `redesign.html:383` is `[dir=rtl] .cta{font-family: var(--ui-ar);
///    letter-spacing: 0; text-transform: none; font-size: 13px}` — the prototype
///    turns the tracking and the uppercase **off** in Arabic and hands the family
///    to the caller's Arabic face. Applying `:382` unconditionally would put
///    `0.22em` of tracking and an uppercasing pass on every Arabic label, and
///    getting that right needs a direction branch inside a Tier-1 primitive —
///    which [EvaButton.labelFamily]'s doc rejects on the record, from recorded
///    decision 19.
/// 2. **The size is GEOMETRY-in-effect and two harnesses read it.** `16 → 11` is
///    a 31% narrower label, and `login_geometry_test` reads
///    `textTheme.titleMedium!.fontSize == 16` as a transcription claim against
///    `ds.tsx:237`. That row reads the **theme**, so moving this widget's own
///    label would not move it — but it means the claim the harness is making
///    ("the prototype's 16 is what renders") would stop being true of the button
///    while the harness stayed green, which is §7's "a gate that cannot fail"
///    wearing a passing gate's clothes.
/// 3. **It would invalidate goldens this batch does not own.**
///    `empty_state_{dark,light}.png`, `error_view_{dark,light}.png` and
///    `neural_scaffold_{dark,light}.png` each render an `EvaButton`, and a
///    narrower label moves all six. Task 4.2 scopes golden re-recording per
///    widget prefix, so a change here cannot be made honestly inside its scope.
///
/// So the **shape, the rim, the ink and the ring** are the redesign's, and the
/// **type** is the old prototype's. Both halves are named here rather than one
/// of them being quietly taken, because a reader comparing this widget to
/// `redesign.html:382` deserves to be told which half is missing and why.
///
/// ## REDUCED MOTION
///
/// The press transition reads `MediaQuery.disableAnimationsOf(context)`. With
/// animations off the duration is [Duration.zero], so [AnimatedContainer] applies
/// the pressed fill on the frame the press starts — the end state immediately,
/// which is what §14 asks for. There is no fade to skip; the button simply is the
/// other colour.
///
/// The **ring is not painted at all** under reduced motion, which is the same
/// answer [EvaFocusRing] gives: an infinite loop has no end state to jump to, and
/// a reader who has asked for less motion should not get one that never stops.
/// The clocks that drive it are stopped independently by `NeuralMotionScope`, so
/// the two mechanisms agree rather than one being relied on to cover the other.
///
/// The prototype's press duration is `180ms` (`ds.tsx:242`), which is not a
/// token. `EvaMotion.fast` (150ms) is the nearest and is documented as "press and
/// hover feedback on a control", so it is used rather than a literal 180.
class EvaButton extends StatefulWidget {
  /// A button labelled [label].
  const EvaButton({
    required this.label,
    this.onPressed,
    this.variant = EvaButtonVariant.primary,
    this.icon,
    this.trailingChevron = false,
    this.expanded = true,
    this.height = kEvaButtonHeight,
    this.semanticLabel,
    required this.labelFamily,
    super.key,
  });

  /// The button's text. Also its accessible name — unless [semanticLabel]
  /// overrides it, which exists for the inert-control suffix pattern and is
  /// documented there.
  final String label;

  /// What to run on activation. `null` disables the button: `ds.tsx:245`'s
  /// 45% opacity, no ink, no focus, and `Semantics(enabled: false)`.
  final VoidCallback? onPressed;

  /// Which prototype button this is.
  final EvaButtonVariant variant;

  /// A glyph before the label. Sized to the label's cap height so a 24px icon
  /// does not change the button's optical weight.
  final IconData? icon;

  /// Draws the prototype's trailing `›` (`ds.tsx:283`) — `ember`, 16, w700, and
  /// only when the label is not itself ember-coloured.
  final bool trailingChevron;

  /// Whether to fill the available width. `ds.tsx:240` sets `width: '100%'` on
  /// all three components, so this is the faithful default.
  final bool expanded;

  /// Button height. [kEvaButtonHeight] unless a caller needs otherwise.
  final double height;

  /// The node's accessible name. `null` means [label].
  ///
  /// ## WHY THE NAME CAN DIFFER FROM WHAT IS PAINTED
  ///
  /// Because a permanently-inert control must say **why** it cannot be pressed,
  /// and that sentence is not part of its design. `/login`'s two ghost pills
  /// paint `GOOGLE` and `APPLE` (`redesign.html:509`) and announce
  /// `"google — unavailable in this build"` — the suffix pattern
  /// `authUnavailableSuffix` documents, appended by the call site because two
  /// inert controls share labels and a suffix baked into the label would render
  /// twice. `Semantics(label:)` below takes this when set; nothing painted
  /// changes, and `excludeSemantics` keeps the painted text out of the node as
  /// before.
  final String? semanticLabel;

  /// The family [label] renders in.
  ///
  /// ## IT IS **REQUIRED**, AND THAT IS THE WHOLE POINT OF IT
  ///
  /// It shipped optional and nullable, and one call site in four passed it. The
  /// fallback the parameter's own doc called "the ordinary case" is `titleMedium`'s
  /// family — **DM Sans** — which carries no Arabic glyph at all. So the parameter
  /// did nothing for the three call sites that did not use it, the compiler was
  /// silent at each of them, and Phase 8's quiz CTA and Phase 9's settings CTA would
  /// have shipped tofu in Arabic for the same reason.
  ///
  /// **Required is the fix and it is a compiler fix, not a review fix.** The
  /// alternative — resolving the family from `Localizations.localeOf` inside this
  /// widget — is what the "Rejected" note below rejects, and it stays rejected; see
  /// that note, which is unchanged and still right. A locale read here would make a
  /// Tier-1 primitive branch on an inherited widget, so `/login`'s English label and
  /// an Arabic one would travel the same code path and the branch would be invisible
  /// in review. §14's lesson from recorded decision 19 is that a locale-derived
  /// style has to be **passed in and asserted at a call site**, and "required" is
  /// what forces the pass.
  ///
  /// Every `EvaButton(` call site in `lib/` now names its family — ten of them
  /// after Phase 5.1 put the redesigned `/login`'s CTA and two ghost pills on
  /// the list — and `ErrorView` — which builds one — grew a `retryFamily` for
  /// the same reason.
  ///
  /// ## WHY THIS EXISTS, AND IT IS BECAUSE OF A MEASURED FACT
  ///
  /// `ds.tsx:237` writes `fontFamily: F.ui` on `ButtonPrimary`, i.e. **DM Sans**. §5.2
  /// and `reading_glyph_test.dart`'s coverage check both establish that DM Sans
  /// carries **no Arabic glyphs at all** — the same fact `01-source-analysis.md`'s
  /// defect **#2** is about, except that #2 names `ReadingArScreen.tsx:35` and `:86`
  /// and not the *button*.
  ///
  /// So `/reading`'s Arabic arm renders `ابدأ التأمل` through this widget and would
  /// render six tofu boxes without an override. That makes this parameter a
  /// **fourth site of defect #2**, in a shared component rather than in a screen,
  /// and `reading_glyph_test.dart` reads the family off the rendered `Text` rather
  /// than trusting that a caller remembered.
  ///
  /// ## AND IT IS A **FAMILY**, NOT A `TextStyle`
  ///
  /// A `TextStyle` parameter would let a caller set a size, a weight or a colour
  /// and silently win against `resolveButtonStyle`'s foreground — which is the
  /// "caller-chosen font size is how a 12sp label ends up on a 52px pill" hazard
  /// `TextLink`'s doc records for exactly this widget family. The family is the one
  /// thing a caller legitimately needs to differ, and nothing else moves.
  ///
  /// **Rejected: reading the locale inside this widget.** That would make a
  /// Tier-1 primitive branch on `Localizations.localeOf`, so `/login`'s English
  /// label would go through the same code path as an Arabic one and the branch
  /// would be invisible in review. §14's own lesson from recorded decision 19 is
  /// that a locale-derived style is exactly the kind of thing that has to be passed
  /// in and asserted at a call site.
  final String labelFamily;

  @override
  State<EvaButton> createState() => _EvaButtonState();
}

class _EvaButtonState extends State<EvaButton> {
  /// Press tracking.
  ///
  /// An `InkWell` reports it through `onHighlightChanged`, which is why the
  /// press *fill* is a separate concern from the ink splash: the prototype
  /// changes both (`ds.tsx:239,244`) and they are not the same mechanisms.
  bool _pressed = false;

  /// Hover tracking.
  ///
  /// `redesign.html` gives two of the three roles a `:hover` rule and one of
  /// them is a *fill*, so this is not `InkWell`'s highlight — it is the pointer
  /// being over the control, and `IconActionButton` tracks it the same way for
  /// the same prototype family.
  ///
  /// Cleared when the pointer leaves and **never** on disable: a disabled
  /// control cannot be hovered, and [EvaButtonStyle.hoverBackground] is a
  /// paint, not an interaction.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final EvaButtonStyle style = resolveButtonStyle(
      variant: widget.variant,
      colors: colors,
    );
    final bool enabled = widget.onPressed != null;
    // §14 — every animation checks this. See the class doc.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    // The hovered treatment is chosen here rather than in three places, because
    // `.qnext` hovers its **fill** and `.ghosts button` hovers its **ink** — see
    // [EvaButtonStyle]. Read as one pair so a variant cannot take one half and
    // drop the other.
    final EvaButtonStyle shown = switch ((_hovered, enabled, _pressed)) {
      // Pressed outranks hovered: the prototype's `.cta:active` (`:384`) and
      // `.qnext:hover` (`:368`) can both be true at once, and the press is the
      // one the reader's finger is holding.
      (false, _, true) => style,
      (true, true, false) => EvaButtonStyle(
        background: style.hoverBackground,
        pressedBackground: style.hoverBackground,
        hoverBackground: style.hoverBackground,
        foreground: style.hoverForeground,
        hoverForeground: style.hoverForeground,
        border: style.hoverBorder,
        hoverBorder: style.hoverBorder,
        glow: style.glow,
        pressedGlow: style.pressedGlow,
      ),
      _ => style,
    };

    final Widget? leading = switch (widget.icon) {
      final IconData glyph => Padding(
        padding: const EdgeInsets.only(right: EvaSpacing.sm),
        child: Icon(
          glyph,
          size: kEvaButtonChevronSize + EvaSpacing.xs,
          color: shown.foreground,
        ),
      ),
      null => null,
    };

    final Widget text = Text(
      widget.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      // The colour comes from the **shown** style, so a hovered ghost inks gold
      // in the text and not only in the resolved `BoxDecoration`. The family and
      // the weight below are the old prototype's — see the class doc's "THE LABEL
      // TYPE IS NOT THE REDESIGN'S".
      style: switch (widget.variant) {
        // `ds.tsx:237` — `fontSize: 16, fontWeight: 700,
        // letterSpacing: '0.01em'`. The letter spacing is dropped: §5.2 gives
        // `mono` no tracking value and `03-design-system.md` names none for
        // `ui`, so adding 0.01em would be inventing one.
        //
        // `titleMedium` is Material 3's 16sp slot, so the prototype's 16 lands
        // exactly. `redesign.html:382`'s `mono 11 / .22em / uppercase / w600`
        // is **not** applied; the class doc gives the three mechanical reasons
        // and `login_geometry_test`'s `dsClaims` row for `ds.tsx:237` is the
        // claim that would quietly stop being true of this widget.
        EvaButtonVariant.primary => _labelStyle(
          context,
          shown.foreground,
          FontWeight.w700,
        ),
        // `ds.tsx:259` — `fontSize: 16, fontWeight: 600`, kept for the same
        // reason as the primary's 16.
        EvaButtonVariant.secondary => _labelStyle(
          context,
          shown.foreground,
          FontWeight.w600,
        ),
        // `ds.tsx:277` — `fontSize: 15, fontWeight: 500`.
        //
        // Recorded: `labelLarge` is Material 3's **14**sp slot, so this is the
        // one button size that does not land on the prototype's number. The slot
        // was chosen because it is the slot for "a label on a control" and §5.2
        // fixes no size; 15 invented as a literal would be a second source for
        // one number.
        EvaButtonVariant.ghost => _labelStyle(
          context,
          shown.foreground,
          FontWeight.w500,
        ),
      },
    );

    final Widget? trailing = widget.trailingChevron
        ? Padding(
            padding: const EdgeInsets.only(left: EvaSpacing.xs),
            child: Icon(
              // The prototype's `›` is a glyph inside the same button
              // (`ds.tsx:283`) — a chevron, not a right-pointing triangle, and
              // not an arrow. `chevron_right` is the Material equivalent;
              // `Icon` cannot be given a weight, so the prototype's `w700` is
              // carried by the icon's own optical weight instead.
              Icons.chevron_right,
              size: kEvaButtonChevronSize,
              color: colors.emberInk,
            ),
          )
        : null;

    // A `Row(mainAxisSize: min)` with **one** flexible child still hands that
    // child the whole available width: `RenderFlex` distributes the free space
    // to the flex child and there are no inflexible siblings to measure against.
    // So `expanded: false` with a bare label measured 280 and the button came out
    // as wide as the screen it was supposed to shrink-wrap inside. A lone label
    // therefore gets no row at all — and a `Flexible` with no `Flex` above it is
    // an outright error ("Incorrect use of ParentDataWidget"), so the wrapper
    // cannot simply be made unconditional.
    final Widget label = leading == null && trailing == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ?leading,
              Flexible(child: text),
              ?trailing,
            ],
          );

    final Widget content = DefaultTextStyle.merge(
      style: TextStyle(color: shown.foreground),
      child: Opacity(
        // `ds.tsx:245` — `opacity: disabled ? 0.45 : 1`.
        opacity: enabled ? 1 : kEvaButtonDisabledOpacity,
        child: label,
      ),
    );

    // `.cta::after` (`redesign.html:385`) — and only `.cta::after`. Neither
    // `.qnext` (`:363-368`) nor `.ghosts button` (`:388-390`) nor `.rghost`
    // (`:463-465`) nor `.pctl button` (`:470-472`) declares one, so the ring
    // belongs to the filled role alone and not to "buttons".
    //
    // **Not painted at all under reduced motion**, and not "painted frozen":
    // §14 asks an animation to jump to its end state, and an infinite loop has
    // no end state, so the honest reading of "jump to the end" here is "do not
    // start". `NeuralMotionScope` stops the clock that drives it independently,
    // so the two agree.
    final bool rippled =
        animate && enabled && widget.variant == EvaButtonVariant.primary;
    // Read once, here, so the clock is touched in one place — and read at all
    // only when a ring will actually be painted.
    final Listenable? repaint = rippled
        ? NeuralMotionScope.of(context).repaint
        : null;

    final Widget body = AnimatedContainer(
      duration: animate ? EvaMotion.fast : Duration.zero,
      curve: EvaMotion.fastCurve,
      width: widget.expanded ? double.infinity : null,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: EvaSpacing.xl),
      // `null` unless expanded. `Container(alignment: …)` wraps its child in an
      // `Align` with both factors null, which expands to the **maximum** incoming
      // constraint — so an alignment on an un-expanded button defeats
      // shrink-wrapping entirely and the button came out 320 wide on a 320 screen.
      // The label is already centred by its own `textAlign`.
      alignment: widget.expanded ? Alignment.center : null,
      decoration: BoxDecoration(
        color: _pressed ? shown.pressedBackground : shown.background,
        // `redesign.html:381` — `border-radius: 999px`. **Not** `EvaRadii.button`;
        // see that constant's doc for why the token stays at 14.
        borderRadius: const BorderRadius.all(Radius.circular(kEvaButtonRadius)),
        // The rim is the [EvaFocusRing]'s `idleBorder`, not here, so that a
        // focused button carries exactly one border and the ring is the spec.
        boxShadow: _pressed ? shown.pressedGlow : shown.glow,
      ),
      // ## THE `Stack`, AND WHY IT IS HERE AT ALL
      //
      // `.cta::after` is `position: absolute; inset: 0` — an element *over*
      // the button's own box, not a property of it. Flutter has no `::after`,
      // and the two widgets that can express one are a `Stack` (needs the fit
      // argued out, and does) and a second decoration on the same
      // `BoxDecoration` (cannot scale).
      //
      // `StackFit.passthrough` is load-bearing and is argued in the class doc
      // against the measured `StatTile` regression in `glass_surface.dart`.
      // `Clip.none` is load-bearing for the other half of the same reason: at
      // `scale(1.6)` the ring overflows its own box, and `rendering/stack.dart`
      // pushes a clip for exactly that case under the default.
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (repaint != null)
            Positioned.fill(
              // `IgnorePointer` because the ring is drawn *over* the button's
              // own area: without it the ripple would swallow taps aimed at the
              // label. `Positioned` because `Transform.scale` needs a box, and
              // this one is the button's box rather than a computed guess at it.
              child: IgnorePointer(
                child: ListenableBuilder(
                  listenable: repaint,
                  builder: (BuildContext context, Widget? _) =>
                      _RippleRing(colors: colors),
                ),
              ),
            ),
          content,
        ],
      ),
    );

    return MouseRegion(
      // The pointer signal for the two `:hover` rules `redesign.html` gives this
      // role — see [EvaButtonStyle]. `IconActionButton` is the precedent, and it
      // records why the alternative is wrong: `EvaInk`'s `onHighlightChanged` is
      // a *press*, and reading it as a hover is a different bug.
      onEnter: (PointerEnterEvent _) => _setHovered(true),
      onExit: (PointerExitEvent _) => _setHovered(false),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel ?? widget.label,
        // The label text is already the accessible name; leaving it in the tree
        // as well makes a screen reader read "Sign in, Sign in".
        excludeSemantics: true,
        // `excludeSemantics: true` also drops the `InkWell`'s own tap action — so
        // this line is load-bearing, not decoration. §14's second row is "every
        // interactive widget is keyboard **and** screen-reader activatable", and a
        // TalkBack double-tap maps to `ACTION_CLICK` = [SemanticsAction.tap], which
        // only this node carries: without it the button reads out as a button and
        // does nothing when the reader activates it. `enabled ? … : null` because
        // a disabled control's action must be genuinely **absent** — the
        // `enabled: false` flag above is what announces it, and a flag plus an
        // action is a control that announces itself as unusable and then works.
        onTap: enabled ? widget.onPressed : null,
        child: EvaFocusRing(
          // `EvaInk` is disabled below when `onPressed` is null, and the two must
          // agree or Tab would stop on a control that cannot be activated.
          enabled: enabled,
          idleBorder: shown.border,
          // The ring paints on the **outer** box, which is the button's box —
          // so without this the focus indicator would be a 14px-cornered square
          // around a pill, which is the one shape in the design system nothing
          // else has.
          radius: kEvaButtonRadius,
          child: EvaInk(
            onPressed: widget.onPressed,
            // The splash follows the pill rather than a rectangle. It did not
            // before this widget was a pill: `EvaInk`'s own default is `null`,
            // which clips to nothing, and a 14px corner on a 999px pill is the
            // splash leaving the control sideways.
            borderRadius: const BorderRadius.all(
              Radius.circular(kEvaButtonRadius),
            ),
            onHighlightChanged: (bool value) {
              if (value == _pressed) return;
              setState(() => _pressed = value);
            },
            child: body,
          ),
        ),
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  TextStyle _labelStyle(
    BuildContext context,
    Color foreground,
    FontWeight weight,
  ) => Theme.of(context).textTheme.titleMedium!.copyWith(
    color: foreground,
    fontWeight: weight,
    // The one line `reading_glyph_test.dart` reads the rendered family back off, so
    // it is the only place the knob reaches the engine. Non-nullable now, so there
    // is no `copyWith(fontFamily: null)` subtlety left to reason about: the caller's
    // family, always.
    fontFamily: widget.labelFamily,
  );
}

/// `.cta::after` (`redesign.html:385`), as a widget.
///
/// ```css
/// .cta::after{content:"";position:absolute;inset:0;border-radius:999px;
///   border:1.5px solid rgba(232,176,75,.65);animation:ripple 2.4s var(--e-out) infinite}
/// ```
///
/// ## WHY IT IS A SEPARATE WIDGET AND NOT A FIELD
///
/// A `BoxDecoration` has one `border` and many `boxShadow`s, and **no shadow
/// scales**. The ring's whole effect is `scale(1 → 1.6)` about the button's
/// centre while its alpha falls to zero, and the only Flutter primitive that
/// does that without moving layout is a transform on a box the size of the
/// button's — which is what this is. `Paint` does not take a matrix, so this is
/// not a `CustomPainter` either.
///
/// ## WHY IT READS THE CLOCK ITSELF
///
/// Because the `ListenableBuilder` that drives it wraps *this* and nothing
/// else: a listener on `EvaNeuralMotion.repaint` placed around the button's
/// content would rebuild the label, the glyph and the opacity every frame to
/// change one decoration. Eight buttons on a screen rebuilding their labels at
/// 60fps to animate a 1.5px ring is §13's churn coming back one level down.
///
/// So the tree is `ListenableBuilder > _RippleRing`, and `_RippleRing` reads
/// `NeuralMotionScope.of(context).lumen.seconds` and converts it through
/// [evaButtonRipplePhase] and [evaButtonRippleAt]. The arithmetic is two pure
/// functions at module scope precisely so that it can be tested without a
/// widget, a scope, a ticker or a frame.
///
/// ## THE `--e-out` EASING IS **NOT** APPLIED, AND THAT IS RECORDED
///
/// `redesign.html:385` writes `animation: ripple 2.4s var(--e-out)` and
/// `--e-out` is a cubic-bezier (`redesign.html:18`). The two endpoints are
/// transcribed exactly and the ramp between them is **linear**, because
/// `evaButtonRippleAt` is linear and an easing would have to be a third
/// parameter of a function whose two ends the prototype states as constants.
///
/// It is a small difference over a 2.4s loop on a ring that spends most of its
/// life below 20% alpha. It is recorded because a reader comparing this to
/// `:385` should not have to notice it, and because `EvaMotion` publishes a
/// family of curves for exactly this and adding one here for a 2.4s
/// ambient loop would be a fifth curve in a table whose doc says a curve
/// belongs beside the widget that quotes the prototype's line for it.
class _RippleRing extends StatelessWidget {
  const _RippleRing({required this.colors});

  /// The palette, for the ring's own rim.
  final EvaColors colors;

  @override
  Widget build(BuildContext context) {
    final ({double scale, double opacity}) ring = evaButtonRippleAt(
      evaButtonRipplePhase(NeuralMotionScope.of(context).lumen.seconds),
    );
    return Transform.scale(
      // `redesign.html:234` — `0%{transform: scale(1)}`, `100%{transform:
      // scale(1.6)}`, about the element's own centre.
      //
      // **`alignment` is left at its default on purpose.** `Transform.scale`'s
      // default *is* `Alignment.center`, and the prototype's `transform-origin`
      // for a `position: absolute; inset: 0` element is the element's centre, so
      // the default is the faithful value — and `avoid_redundant_argument_values`
      // is the analyzer agreeing that writing it would say nothing the default
      // does not already say.
      scale: ring.scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(kEvaButtonRadius),
          ),
          // `border: 1.5px solid rgba(232,176,75,.65)` — the alpha multiplied by
          // the keyframe's `opacity`, because the two are the same channel: the
          // prototype fades the **element**, and a Flutter `Opacity` is a
          // separate widget per frame, so the product is taken here instead. One
          // colour, one alpha, no second node.
          border: Border.all(
            color: colors.emberInk.withValues(
              alpha: kEvaButtonRippleAlpha * ring.opacity,
            ),
            width: kEvaButtonRippleWidth,
          ),
        ),
      ),
    );
  }
}
