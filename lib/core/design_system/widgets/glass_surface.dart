import 'dart:ui' show ImageFilter;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which of the three glass treatments a surface gets.
///
/// ## WHY AN ENUM AND NOT A BOOL
///
/// §13.4 counts eight blur sites across the six shipped screens and rules that
/// only **one** of them may actually blur — Home's today's-reading panel. A
/// `bool blur` would make that budget
/// invisible at every call site: `GlassSurface(blur: true)` reads as "a glass
/// surface", says nothing about which of the eight sites it is, and defaults to
/// `false` in a way a future author will flip the first time a panel "looks
/// wrong" without it. An enum makes the choice a *decision* at every call site
/// and lets the budget be stated per variant:
///
/// | screen | tier | why |
/// | --- | --- | --- |
/// | `/login` | [tint] | a full-screen field cluster; a blur buys nothing |
/// | `/reading` | [tint] | dense text; the blur is barely perceptible |
/// | `/quiz` | [tint] | four stacked cards; four `saveLayer`s over content |
/// | `/` (Home) | [blur] **only** the today's-reading panel | the only place on `/` where glass sits over the animated background |
/// | everything else | [tint] | |
///
/// **[bloom] is not on that table**, and its absence is the point of it: the
/// budget is about [blur] sites, and [bloom] is a paint that spends none. It is
/// an enum member rather than a `bool bloom` for the same reason [blur] is one —
/// the choice has to be visible in a diff and greppable — not because it is
/// budgeted. See its own doc for the four hosts it is transcribed from.
///
/// **No screen calls it yet, and that is the plan rather than an oversight:**
/// `docs/superpowers/plans/2026-10-13-lumen-redesign.md` Task 4.2 Step 3
/// restyles the 24 widgets "to the redesign's glass/gold/bloom language, **by
/// role, not by file**" — so adoption is a per-role decision inside that step
/// and there is no call site this phase can honestly name in advance. What the
/// prototype does fix is the *shape*: `.hcard` (`redesign.html:253-257`) is the
/// only one of the four hosts carrying both a wash and a seam, so what Phase
/// 4.2 moves to [bloom] is the card/panel family, not the inline controls. Until
/// then the tier is reachable only from `GlassSurface(tier: …)` directly and
/// `glass_surface_test.dart` is its only caller — so a reader who greps
/// `lib/features/` for `GlassTier.bloom` and finds nothing is looking at a
/// deliberate gap, not at a tier nobody finished.
///
/// ## **THE TOP BAR IS NOT ONE OF THEM** — corrected in Phase 6
///
/// This table used to read "the today's-reading panel **and the top bar**", and the
/// per-screen line in `09-quality-gates.md` §13 rule 4 said the same. **Both were
/// wrong**, and `ds.tsx:499-530` is the proof: `TopBar` is a `display: flex` `div`
/// with a `padding` and a `zIndex` and **no `backdropFilter` anywhere in its 32
/// lines**. The prototype deliberately leaves the bar see-through so the orbs show
/// behind it.
///
/// So the budget on `/` is **one**, not two, and
/// `glass_blur_budget_test.dart`'s ceiling for `lib/features/` moved from 2 to 1
/// with it. The rest of this file's accounting — eight prototype sites, six
/// surviving in `ds.tsx` after `PassageCard` is cut — was correct and is unchanged.
///
/// ## THE COST, STATED
///
/// [blur] is one `BackdropFilter`, and a `BackdropFilter` is one `saveLayer` plus a
/// full read-back of everything painted behind it, **per frame**. The eight
/// prototype sites would be eight of those; this enum is what keeps the number at
/// **one**. A second `.blur` is not a style choice, it is a frame budget change.
///
/// ## AND WHAT ENFORCES THAT
///
/// The first version of this doc claimed the enum was enough "because this type
/// exists so that adding one is visible in a diff". A diff is review, not a gate:
/// somebody has to notice, count, and remember that the number is one, and
/// `rg 'GlassTier.blur' lib/` hit this file and nothing else — Phase 3 could
/// write it at all eight prototype sites and every test would stay green.
///
/// `glass_blur_budget_test.dart` is the gate. It walks `lib/features/`, fails
/// above **one** occurrence, and fails closed on a missing directory, an
/// unreadable file or an empty walk. It also refuses a hand-built
/// `BackdropFilter` in a feature, because that is the same `saveLayer` with no
/// budget attached to it. And it does **not** attribute: a count is not a
/// per-screen rule, which is why `home_page_test.dart` asserts the panel's tier
/// on the rendered widget.
///
/// A runtime count cannot do this job: only the screens that exist are pumped by
/// any suite, and Phase 3 is what writes the six real screens. The sites are
/// source, not state.
enum GlassTier {
  /// A translucent fill, a hairline rim and the ambient shadow. No `saveLayer`.
  ///
  /// The default, because it is right on four of the six screens.
  tint,

  /// A [BackdropFilter] under the same fill, rim and shadow.
  ///
  /// Reserved for a surface that sits directly over the animated background and
  /// is expected to let it show through — on `/`, that is **Home's today's-reading
  /// panel and nothing else**. See the enum's doc for why the top bar is not a
  /// second one; `ds.tsx:499-530` has no `backdropFilter` in it at all.
  blur,

  /// The `.bloom` radial wash **and** the `.hor` seam, over the same fill, rim
  /// and ambient — and **no** `saveLayer`.
  ///
  /// ## WHAT IT IS FOR, IN ONE LINE
  ///
  /// A *paint*, not a filter. §13.4's budget is a count of `BackdropFilter`s, and
  /// this tier exists so a card can have the redesign's colour without buying one:
  /// two `DecoratedBox`es and a `BoxShadow` cost nothing against the rule that
  /// [blur] is measured by. `glass_blur_budget_test.dart` finds exactly one
  /// `GlassTier.blur` line in this file and one `BackdropFilter` in this file,
  /// and both are unaffected by this member.
  ///
  /// ## THE FOUR HOSTS IT IS TRANSCRIBED FROM, MEASURED
  ///
  /// Every `.bloom` in `redesign.html` is one of four declarations, and they are
  /// **not** the same declaration:
  ///
  /// | host | inset / size | fade stop | `filter:blur()` | own `opacity` |
  /// | --- | --- | --- | --- | --- |
  /// | `.hcard` (`redesign.html:253-254`) | `left:8%` `right:8%` `bottom:-46%` `height:80%` | `68%` | `18px` | `.85` |
  /// | `.bcard` (`redesign.html:279`) | `left:6%` `right:6%` `bottom:-52%` `height:88%` | `68%` | `16px` | — |
  /// | `.medal` (`redesign.html:415`) | `left:0` `right:0` `bottom:-60%` `height:90%` | `70%` | `14px` | — |
  /// | `.podbar` (`redesign.html:299`) | `left:10%` `right:10%` `bottom:-55%` `height:90%` | `70%` | `14px` | — |
  ///
  /// All four are `radial-gradient(ellipse at 50% 100%, var(--bh, …), transparent
  /// N%)`, all four hang below their host's bottom edge by more than half their
  /// own height, and **only `.hcard` has a `.hor` seam** (`redesign.html:256-257`
  /// — `.bcard`, `.medal` and `.podbar` have none).
  ///
  /// ### WHAT ONE WIDGET PICKS OUT OF FOUR DECLARATIONS, AND WHY
  ///
  /// `.hcard`'s numbers, for two reasons that are not taste:
  ///
  /// 1. **it is the only host with a seam**, so it is the only one whose full
  ///    treatment this tier carries. The other three's hosts are a book card, a
  ///    medal and a progress bar, and those are composites rather than a
  ///    `GlassSurface` — one of them (`podbar`) is a `Stack` of several bars.
  /// 2. **`68%` rather than `70%`.** Two of the four say `70%`; the two that say
  ///    `68%` are `.hcard` and `.bcard`. The tie is broken by (1), and the
  ///    difference is two percent of a gradient — recorded here so a reader does
  ///    not assume the `70%` was overlooked.
  ///
  /// The other hosts' insets are **not** reproduced, and that is the honest
  /// reading: `left:6%`/`10%`/`0` are three different horizontal insets on hosts
  /// of three different aspect ratios, and a percentage of what is really a
  /// composition-specific box has no meaning once the box is one widget. What
  /// ships is one full-bleed wash with one fade stop.
  ///
  /// ## THE THREE SUBSTITUTIONS, EACH FOR A REASON
  ///
  /// **1. `filter:blur(18px)` → the wide transparent stop.**
  /// `09-quality-gates.md:161` already settled the general case: "The
  /// prototype's `blur(72px)` is achieved by a soft radial gradient with a wide
  /// transparent stop — visually equivalent, effectively free." `blur(18px)` here
  /// is the same trade at a smaller radius. A `MaskFilter` or an `ImageFilter`
  /// would be the alternative spelling and is refused twice over: an
  /// `ImageFilter` on a saved layer is a `saveLayer` per frame, which is exactly
  /// what this tier exists to avoid, and §13.4's gate refuses a
  /// `BackdropFilter`/`ImageFilter.blur` outside this file by name.
  ///
  /// **2. `bottom:-46%` + `overflow:hidden` → the `ClipRRect` that is already
  /// here.** The prototype's wash hangs below its host and is cut off by the
  /// host's own `overflow:hidden` (the `.hcard` rule at `redesign.html:250`
  /// carries `overflow:hidden`). The wash therefore paints full-bleed inside a
  /// clip that was already required for the corner radius — one fewer mechanism
  /// than the CSS has, and no new widget.
  ///
  /// **3. `ellipse` → a circle.** The only one of the three that is a genuine
  /// approximation rather than a substitution. CSS's `radial-gradient(ellipse …)`
  /// with no size resolves against `farthest-corner` of the box; Flutter's
  /// `RadialGradient` is circular and `radius` is in units of `rect.shortestSide`,
  /// so [kGlassBloomRadius] = 1.0 is the closest circular stand-in that still
  /// reaches the panel's full height. On a card three times wider than it is tall
  /// the wash is then a little narrower at the top than the CSS would draw it.
  /// Rejected: a `FractionalTransform` squashing the circle into an ellipse,
  /// which would be the faithful spelling and would put a second coordinate
  /// system on a decoration.
  ///
  /// ## THE DIMMERS ARE CALLER STATE, AND ARE DELIBERATELY NOT MEMBERS
  ///
  /// `redesign.html:73` sets `opacity:.55` on all four `.bloom`s in light mode,
  /// and `redesign.html:285` sets `opacity:.35` on `.bcard.sealed .bloom`. Neither
  /// is a tier: `.sealed` is a **state of a book card** (its title is dimmed at
  /// `:286` too, and it carries a lock badge), and light mode is a theme rather
  /// than a treatment. A tier member called `sealedBloom` would be a fifth value
  /// whose only meaning is "0.35 of the colour I already had", and
  /// `GlassTier`'s whole reason for being an enum is that each member is a
  /// *decision about the surface*, countable and greppable. A caller that wants a
  /// dimmed wash wraps this one in an `Opacity`, which costs a `saveLayer` — and
  /// `Opacity` is the caller's to spend, not this widget's, exactly as a blur is
  /// (§13.4 budgets saveLayers; a decorative wash must not quietly add one).
  ///
  /// ## THE SEAM, AND ITS ONE DIVERGENCE
  ///
  /// `.hor` is `height:2px` `border-radius:2px` at `bottom:20%`, spanning
  /// `left:14%` to `right:14%` — hence [kGlassSeamWidthFactor] 0.72 — with
  /// `box-shadow:0 0 14px rgba(255,255,255,.6)` (`redesign.html:256-257`).
  /// [EvaColors.light] re-points both the seam and its glow at gold
  /// (`redesign.html:72`) and at **`12px`**, not 14; this widget ships 14 in both
  /// palettes. See `seamGlow`'s doc for why that is a geometry constant rather
  /// than a per-brightness token.
  bloom,
}

/// Where [GlassTier.bloom]'s wash has reached nothing — `redesign.html:254`'s
/// `transparent 68%`, and the substitution that replaces `filter:blur(18px)`.
///
/// Two of the four prototype hosts say `70%` (`.medal` `:415`, `.podbar`
/// `:299`); `.hcard` and `.bcard` say `68%`. See the tier's doc.
const double kGlassBloomFadeStop = 0.68;

/// The wash's radius, in units of `rect.shortestSide`.
///
/// CSS's default radial extent is `farthest-corner`; Flutter's `RadialGradient`
/// takes a radius as a fraction of the **shortest** side, so `1.0` reaches the
/// panel's full height from its bottom edge. See the tier's third substitution.
const double kGlassBloomRadius = 1.0;

/// The wash's centre — `redesign.html:254`'s `at 50% 100%`.
///
/// ## WHY IT IS `Alignment(0, 1)` AND **NOT** `Alignment(0.5, 1)`
///
/// The prototype's spelling is a `FractionalOffset`, and `FractionalOffset`
/// **extends** `Alignment` (`painting/fractional_offset.dart:54`) with
/// `const FractionalOffset(dx, dy) : super(dx * 2.0 - 1.0, dy * 2.0 - 1.0)`
/// (`:56`) — it *converts on the way in* rather than sharing a coordinate
/// space. So the two are **not** the same numbers, and the direction of the
/// mistake is not obvious either:
///
/// | prototype | as a `FractionalOffset` | as an `Alignment` |
/// | --- | --- | --- |
/// | `at 50% 100%` | `FractionalOffset(0.5, 1.0)` | `Alignment(0.0, 1.0)` |
///
/// The x **and** the y are converted. Verified at runtime rather than read off
/// the constructor, because the whole point is that it is not obvious:
///
/// ```text
/// FractionalOffset(0.5, 1.0) == Alignment(0, 1)   → true
/// FractionalOffset(0.5, 1.0) == Alignment(0.5, 1) → false
/// Alignment(0, 1)   .alongSize(Size(280, 180)) → Offset(140.0, 180.0)
/// Alignment(0.5, 1) .alongSize(Size(280, 180)) → Offset(210.0, 180.0)
/// ```
///
/// **The y was already right** — `at … 100%` is the bottom edge and `Alignment`'s
/// `y = +1` is the bottom edge (`painting/alignment.dart:367`,
/// `Alignment.bottomCenter`) — so the defect was `x` alone, and it was invisible
/// for the reason the doc above used to get wrong: `Alignment`'s `x` is
/// centre-origin, so `x = 0.5` is **75%** of the width, not half of it, and a
/// wash centred three-quarters across a card is close enough to look deliberate
/// in a small golden. `redesign.html:254` says `50%`, and `50%` of 280 is 140.
///
/// Spelled `Alignment` rather than `FractionalOffset` because
/// `RadialGradient.center` is typed `AlignmentGeometry`, and the SDK's own doc
/// for the subclass says so: "[Alignment] is better for most purposes than
/// [FractionalOffset]" (`painting/fractional_offset.dart:44-46`).
const Alignment kGlassBloomCenter = Alignment(0, 1);

/// The seam's width as a fraction of the surface — `redesign.html:256`'s
/// `left:14%;right:14%`.
const double kGlassSeamWidthFactor = 0.72;

/// The seam's height, `redesign.html:256`'s `height:2px`.
const double kGlassSeamHeight = 2;

/// The seam's corner rounding, `redesign.html:256`'s `border-radius:2px`.
///
/// ## NAMED BESIDE [kGlassSeamHeight] DESPITE BEING THE SAME NUMBER
///
/// `height:2px` and `border-radius:2px` are two separate declarations on
/// `redesign.html:256` and they happen to read alike today. They are different
/// properties, and `glass_surface_test.dart` asserts them as two so that a
/// change to one cannot ride along on the other — a gate that compares them to
/// each other (`expect(radius.group(1), height.group(1))`) only pins that the
/// *prototype* still says the same thing twice, which is a claim about
/// `redesign.html` and not about this widget. Splitting them here is what lets
/// that test stay honest: if the prototype's two numbers diverge, the two
/// constants diverge with them and nothing has to be edited to allow it.
const double kGlassSeamCornerRadius = 2;

/// Where the seam sits — `redesign.html:256`'s `bottom:20%`.
///
/// ## THE SIGN FLIPS, AND THAT IS THE WHOLE OF IT
///
/// Three coordinate conventions meet on this one line and **none of them
/// agrees with the other two**:
///
/// | convention | "the top edge" | "the bottom edge" |
/// | --- | --- | --- |
/// | CSS `bottom:20%` | — | measured **upwards from the bottom edge** |
/// | `FractionalOffset` | `dy = 0` | `dy = 1` (`painting/fractional_offset.dart:97-121`) |
/// | `Alignment` | `y = −1` | `y = +1` (`painting/alignment.dart:349`, `:367`) |
///
/// A CSS `bottom` fraction `b` is therefore
///
/// ```text
/// CSS bottom:20%  → FractionalOffset dy = 1 − b = 0.8  → Alignment y = 2(0.8) − 1 = 0.6
/// ```
///
/// and the value here is `2(1 − b) − 1 = 1 − 2b`. The constant shipped as
/// `-1 + 2 × 0.20` = **−0.6**, which is `−(1 − 2b)`: the exact mirror. Because
/// `b = 0.20` is small the result still *looked* plausible — a bar in the panel,
/// the right width, the right colour — and it was only its 19.8% offset **from
/// the top** that gave it away. Verified at runtime, seam top on a 280 × 180
/// panel: `Alignment(0, −0.6)` → `y = 35.6`, `Alignment(0, 0.6)` → `y = 142.4`.
///
/// ## AND THE `0.4px` THIS COSTS, STATED RATHER THAN ROUNDED AWAY
///
/// `Align` maps its alignment onto the **free** space (`H − h`), not onto `H`,
/// so a `bottom`-derived constant lands `b · h` below the CSS position: `0.2 ×
/// 2 = 0.4px` on a 180-tall panel. Sub-pixel, one fifth of the seam's own
/// thickness, and it does not grow — it is `b · h` on every panel, which is
/// 0.4px on the 280 × 180 goldens. The alternative (a `Positioned` driven by a
/// `LayoutBuilder`) would be exact and would take the fractional position into
/// `build`, so the two pixels are paid for the simpler tree.
///
/// Verified against the rendered rect rather than re-derived from this formula,
/// which is the only way to catch a sign error in a formula like this one.
const Alignment kGlassSeamAlignment = Alignment(0, 0.6);

/// The seam's glow radius — `redesign.html:257`'s `0 0 14px`.
///
/// A `BoxShadow.blurRadius` on a `DecoratedBox`: a paint, so it costs nothing
/// against §13.4's `saveLayer` budget. It is deliberately **not** a
/// [MaskFilter], which would blur the shape itself and is neither cheaper nor
/// what the CSS says.
const double kGlassSeamGlowBlur = 14;

/// The Gaussian sigma of the [GlassTier.blur] backdrop, in logical px.
///
/// ## THE PROTOTYPE'S EIGHT RADII, CORRECTED, AND THE MEDIAN WAS NEVER 20
///
/// Measured in `eva/src`, site by site:
///
/// | prototype site | radius | ships? |
/// | --- | --- | --- |
/// | `Input` (`ds.tsx:311`) | 8 | `[EvaTextField]` — tint |
/// | `QuizOption` (`ds.tsx:439`) | 12 | `/quiz` — tint |
/// | `SettingsTile` (`ds.tsx:486`) | 12 | `/settings` — tint |
/// | `StatTile` (`ds.tsx:468`) | 16 | `/result` — tint |
/// | `SealFAB` dock item (`ds.tsx:550`) | 16 | **cut** with the profile screen |
/// | `PassageCard` (`ds.tsx:382`) | 20 | **cut** with the library |
/// | `SealFAB` button (`ds.tsx:561`) | 20 | **cut** with the profile screen |
/// | Login form (`LoginScreen.tsx:40`) | 24 | `/login` — tint |
/// | Home panel (`HomeScreen.tsx:39`) | 24 | **`/` — the one site that blurs** |
///
/// **This doc was wrong three ways and all three are corrected here.** It read
/// "`20` (`PassageCard` and Home's panel), `24` (the FAB button)" — the FAB button is
/// `20`, Home's panel is `24`, and the two are swapped. It then read "collapsing them
/// to one widget has to collapse them to one number, and `20` is the median" — and
/// `20` is not the median of its own list either: sorted, `8, 12, 12, 16, 16, 20, 20,
/// 24`, and the median is **16**. Finally it read "the one `20` that survives **is**
/// Home's panel" — no `20` site survives at all, since `PassageCard` and `SealFAB`
/// are both cut with the screens that used them.
///
/// A "correction" paragraph sat under all of it, and it repeated the falsehood:
/// decision 34 in `AGENT_CONTEXT.md` still says the blur that ships is the blur
/// Home's panel had. It was not — it was `20` against the panel's `24`.
///
/// ## AND `24` IS NOW THE RIGHT NUMBER, NOT A NEW ONE
///
/// The whole reason to pick a compromise was that eight hand-written CSS radii had
/// to become one widget. **Only one site blurs**, so there is nothing to compromise:
/// the surviving site's prototype radius is `24`, and the budget that makes this the
/// only one is the same §13.4 rule that was enforced here. Taking the prototype's own
/// number is what makes "the blur that ships is the blur Home's panel had" **true**
/// rather than aspirational.
///
/// Rejected: keeping `20` and calling it a recorded divergence. That would have
/// needed a *reason*, and the only reasons available were the median (false) and the
/// surviving-`20` (false). A divergence with no argument behind it is a number
/// nobody will defend in review.
///
/// Rejected: an upper bound on sigma for performance. A `BackdropFilter` is one
/// `saveLayer` plus a read-back **per frame** whatever the sigma is, and §13's rule
/// is about the *count* of those, not their radius. `20` versus `24` is not a frame
/// budget change and §13.4 does not name a number for it.
const double kGlassBlurSigma = 24;

/// The one true surface: a translucent fill, a hairline rim, and optionally a
/// backdrop blur or the redesign's `.bloom` wash.
///
/// Collapses the eight glass sites in `eva/src/components/ds.tsx` plus two
/// inline ones into one widget (`04-widget-inventory.md` §3). The recipe is the
/// prototype's, with the numbers resolved through tokens rather than repeated:
///
/// | prototype | token |
/// | --- | --- |
/// | `background: rgba(#fff \| #000, 0.05 \| 0.03)` | [EvaColors.glassFill] |
/// | `border: 1px solid rgba(#fff \| #000, 0.08)` | [EvaColors.glassBorder] |
/// | `boxShadow: 0 4px 24px rgba(#000, 0.35 \| 0.08)` | [EvaColors.glassShadow] |
/// | `backdropFilter: blur(Npx)` | [GlassTier.blur] + [kGlassBlurSigma] |
/// | `.bloom` radial wash | [GlassTier.bloom] + [EvaColors.bloom] + [bloomColor] |
/// | `.hor` seam | [EvaColors.seam] / [EvaColors.seamGlow] + [kGlassSeamGlowBlur] |
///
/// ## THE SHADOW IS NOT AN ELEVATION
///
/// [AGENT_CONTEXT] §9 decision 7 records that every `elevation` in this design
/// system is `0` because the prototype has no z-axis — every `box-shadow` there
/// is either a zero-offset ember glow or this one glass ambient. This
/// `BoxShadow` is that ambient: it is decoration on a `DecoratedBox`, not a
/// Material elevation, and it does not reintroduce a ramp. The seam's glow is the
/// same kind of object for the same reason — a paint on a `DecoratedBox`, and a
/// per-element one rather than a global ambient.
class GlassSurface extends StatelessWidget {
  /// A glass panel around [child].
  const GlassSurface({
    required this.child,
    this.tier = GlassTier.tint,
    this.radius = EvaRadii.card,
    this.padding = const EdgeInsets.all(EvaSpacing.card),
    this.border = true,
    this.onTap,
    this.semanticLabel,
    this.bloomColor,
    super.key,
  });

  /// The surface's content.
  final Widget child;

  /// Tint (no `saveLayer`), blur, or the `.bloom` wash. See [GlassTier] for the
  /// per-screen budget and for why the wash is a tier rather than a flag.
  final GlassTier tier;

  /// Corner rounding. [EvaRadii.card] by default; the prototype's sites range
  /// from 14 (`Input`) to 28 (the Login form), and the caller overrides.
  final double radius;

  /// Inset around [child]. Defaults to [EvaSpacing.card] — `03-design-system.md`
  /// §5.3, "card padding = 20".
  final EdgeInsets padding;

  /// Whether to draw the 1px [EvaColors.glassBorder] rim. Off is for surfaces
  /// that sit on a background of their own and would double the edge.
  final bool border;

  /// Makes the surface tappable and announces it as a button.
  ///
  /// A tappable surface is a `Material` + `InkWell`, not a `GestureDetector`:
  /// §14 requires every interactive node to be keyboard-activatable, and an
  /// `InkWell` inside a `Material` gives that plus the ink response the rest of
  /// the system has.
  final VoidCallback? onTap;

  /// The accessible name for the surface.
  ///
  /// Required whenever [onTap] is set — asserted rather than defaulted, because
  /// an unnamed button is precisely the §14 gap this widget exists to close.
  /// Left null when the surface is not interactive, so a purely decorative panel
  /// does not add a node to the semantics tree at all.
  final String? semanticLabel;

  /// The wash's colour — the prototype's per-host `--bh`, `redesign.html:254`'s
  /// `var(--bh, …)`. `null` means [EvaColors.bloom], which is that `var()`
  /// fallback.
  ///
  /// ## WHY THIS IS A PARAMETER AND NOT A TOKEN, MEASURED
  ///
  /// Because in `redesign.html` `--bh` has **13** occurrences and **none** of
  /// them is a global definition. Every one is either a read
  /// (`var(--bh, …)` on `:254`, `var(--bh)` on `:279`, `:299`, `:415`) or an
  /// inline declaration on a host element — `style="--bh:…"` on `#votdCard`
  /// (`:519`), `#lastCard` (`:524`), the four medals (`:599-602`) **and the
  /// `.podbar` template's own `.bloom` div (`:1094`)**, plus
  /// `style.setProperty('--bh', …)` in the two loops that build book cards
  /// (`:1312`, `:1315`). That is **nine** inline declarations, and the ninth is
  /// the one this list originally left out: `:1094` writes
  /// `style="--bh:${p.gl}"` on the `.bloom` **inside** `.podbar`, so it is
  /// neither a `var()` read nor a `setProperty` call and a reader scanning for
  /// those two shapes walks straight past it.
  /// `glass_surface_test.dart` walks all thirteen and fails on a fourth shape,
  /// because a fourth shape is a global definition and a global definition is
  /// something a token table *could* express.
  ///
  /// And the values genuinely disagree: `#votdCard` washes with
  /// `rgba(228,87,214,.55)` and `#lastCard` with `rgba(232,176,75,.35)`, and
  /// three of the four medals carry a hue the default does not (`#f4e3b2`,
  /// `#d98e32`, `#4f74ff`). **The fourth (`:600`) does not** — it is the
  /// default's own hue at `.5` instead of `.55`, so the medals are four
  /// declarations and *three* new hues, which is what the numbers are and not a
  /// tidier-sounding four. The alpha difference is itself the argument for a
  /// parameter: `:600` is not reachable by any colour token that also has to
  /// serve `:254`'s default.
  ///
  /// A `bloom` token is a *default*, in precisely the sense `var(--bh, …)` is a
  /// default — which is what [EvaColors.bloom] is, and the only thing it claims
  /// to be.
  ///
  /// ## AND WHY THERE IS NO `bool bloom` BESIDE IT
  ///
  /// Because [tier] already is the switch. Two parameters that mean one thing
  /// (`tier == GlassTier.bloom` and a `bool bloom`) can contradict each other,
  /// and a caller that sets the colour and forgets the flag gets a colour that
  /// is never painted — which is the failure mode a `GlassSurface(bloomColor: …)`
  /// has to not have. The tier is also the parameter this widget's whole argument
  /// is built on: it is what makes a treatment greppable at the call site and
  /// countable in a gate, and a `bool` beside it would be the invisible version
  /// of the thing the enum was introduced to stop.
  ///
  /// Ignored on every other tier, deliberately: the wash belongs to
  /// [GlassTier.bloom] and nowhere else, so this parameter alone cannot turn a
  /// tint panel into a blooming one.
  final Color? bloomColor;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    // The tier is the only switch. `bloomColor` on its own paints nothing, so
    // there is no way to reach the wash without asking for it in the diff.
    final bool bloomed = tier == GlassTier.bloom;

    final DecoratedBox surface = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: borderRadius,
        border: border ? Border.all(color: colors.glassBorder, width: 1) : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.glassShadow,
            // `ds.tsx:386` — `0 4px 24px`. The offset is non-zero here, which is
            // the one shadow in the prototype that is not a zero-offset glow;
            // it is still the glass ambient and not an elevation ramp.
            offset: const Offset(0, 4),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipRRect(
        // The clip, not `clipBehavior` on the `Material`: the corner radius is a
        // parameter here, and a `Material` with a non-zero elevation-less
        // shape would round its *shadow* too.
        //
        // It is also the `.bloom` overflow clip — `redesign.html:250`'s
        // `overflow:hidden` on `.hcard`, which is what cuts the prototype's
        // `bottom:-46%` wash off. See [GlassTier.bloom]'s second substitution.
        borderRadius: borderRadius,
        child: Stack(
          // ## THE FIT, AND WHY IT IS NOT THE DEFAULT
          //
          // The contract every existing consumer relies on: **the `Padding`
          // receives the constraints this `GlassSurface` was given, unchanged.**
          // Before the bloom existed the chain was
          // `DecoratedBox > ClipRRect > Padding`, and both of those pass
          // constraints through untouched — so a consumer that handed the surface
          // a tight box got a tight box all the way down, and one that handed it
          // loose constraints got content that sized to itself.
          //
          // `StackFit.loose` — the **default** — is `constraints.loosen()`, and
          // inserting this `Stack` under it broke that contract for every
          // consumer. Measured on `StatTile` (`stat_tile.dart:84`), which is an
          // `Expanded` inside a `Row` — so its cell is a *tight* 320 ÷ 3 ≈ 106.67
          // by 72, while its child is a `Column(mainAxisSize: MainAxisSize.min)`
          // that shrink-wraps to its own caption:
          //
          // | build | the inner `Padding` |
          // | --- | --- |
          // | `9c64579`, `ClipRRect > Padding` | `Size(106.67, 72.0)` |
          // | `143dc56`, `ClipRRect > Stack` (loose) | `Size(50.8, 72.0)`, `89.3`, `54.3` |
          // | `ClipRRect > Stack(passthrough)` | `Size(106.67, 72.0)` |
          //
          // — three panels quietly re-drawn to the width of their own text, and
          // `goldens/stat_tile_{dark,light}.png` diffed by **2177px (1.20%)**.
          //
          // ## WHY IT WAS NOT SEEN, WHICH IS THE PART WORTH KEEPING
          //
          // Two gates both looked at the wrong number, and neither could fail.
          //
          // 1. The comment this replaced claimed "a tint or a blur surface
          //    therefore measures exactly what it measured before the bloom
          //    existed, which is why no golden had to be re-captured". False. It
          //    survived the fixture in `glass_surface_test.dart`, which pins a
          //    `SizedBox(width: 40, height: 20)` child — a child whose own
          //    constraints are *tight*, so loosening the ones above it changed
          //    nothing about it and the golden stayed byte-identical by luck.
          // 2. The test beside it asserted `tester.getSize(find.byType
          //    (GlassSurface))` — the **outer** box, which the child determines,
          //    and which the same lucky fixture fixed at `Size(80, 60)` under
          //    either fit. Both numbers were true and neither was the one that
          //    moved. `glass_surface_test.dart` now measures the content itself,
          //    under a fixture whose answer *does* depend on the fit.
          //
          // ## WHY A FIT AND NOT A CONDITIONAL TREE
          //
          // `passthrough` hands non-positioned children `constraints` verbatim
          // (`rendering/stack.dart`'s `_computeSize`), so the `Padding` sees
          // exactly what it saw before the bloom and the `Stack` then measures the
          // `Padding` — the pre-bloom chain, on all three tiers. Building the
          // `Stack` only when `bloomed` was the other candidate and was rejected on
          // the SDK's own source (`rendering/stack.dart`, and not on taste):
          // `RenderStack.paint` pushes a clip only when `_hasVisualOverflow` is
          // set, and that flag is raised **solely by positioned children** — which
          // a tint or blur surface has none of. So the `Stack` costs such a panel
          // one `RenderStack` and nothing else, and keeping one tree means the
          // bloom's ordering claim stays a property of the same `Stack` every tier
          // is built from.
          fit: StackFit.passthrough,
          // The two decoration layers are `Positioned` and come first, so they
          // paint *behind* the content; both are `Positioned.fill`, so neither
          // contributes to the size this `Stack` measures.
          children: <Widget>[
            if (bloomed) ..._wash(colors, bloomColor ?? colors.bloom),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    final Widget blur = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: kGlassBlurSigma,
          sigmaY: kGlassBlurSigma,
        ),
        // `clipBehavior` on the `BackdropFilter`, because the filter reads
        // everything painted behind it and would otherwise blur past the corner.
        child: ClipRRect(borderRadius: borderRadius, child: surface),
      ),
    );

    final Widget body = switch (tier) {
      GlassTier.tint => surface,
      GlassTier.blur => blur,
      GlassTier.bloom => surface,
    };

    if (onTap == null) {
      return body;
    }
    assert(
      semanticLabel != null,
      'a tappable GlassSurface needs a semanticLabel — an unnamed button is '
      'the §14 gap this widget closes',
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      child: EvaFocusRing(
        // §14's focus row applies to this surface like any other interactive
        // widget, and Phase 2 shipped it without one — the `InkWell` below had no
        // focus node of its own, so Tab never reached the surface at all. Phase 3
        // owns the ring; this is its first application to an already-shipped
        // widget, and `focus_ring_gate_test.dart` counts it.
        enabled: true,
        // `null`, deliberately — and this line is the whole of M4's fix. Phase 3
        // first passed `Border.all(colors.glassBorder, width: 1)` here, which is
        // *the same border at the same 1px inset* that the `DecoratedBox` above
        // already paints, so `onTap: null → () {}` double-drew the rim on every
        // interactive panel. The focus ring is supposed to **replace** the idle
        // border in the same band (see `EvaFocusRing`), and this surface already
        // owns its resting border in its own decoration — so the ring's idle state
        // has nothing to add, and [border] is honoured exactly once.
        //
        // Losing nothing: the 2px ember ring is *wider* than the 1px rim it
        // covers, so a focused panel still shows it completely.
        idleBorder: null,
        radius: radius,
        child: EvaInk(
          onPressed: onTap,
          borderRadius: borderRadius,
          child: body,
        ),
      ),
    );
  }

  /// [GlassTier.bloom]'s two paint layers, in painting order: the wash, then the
  /// seam over it.
  ///
  /// Every widget here is either a `DecoratedBox` or positions one. Nothing in
  /// this list reads the backdrop, so nothing in it can become a `saveLayer` —
  /// which is the entire difference between this tier and [GlassTier.blur], and
  /// the reason §13.4's gate is unaffected by this file growing a third tier.
  ///
  /// [bloomColour] is already resolved by the caller — [bloomColor] if given,
  /// [EvaColors.bloom] otherwise — so this method makes no decision about colour.
  List<Widget> _wash(EvaColors colors, Color bloomColour) => <Widget>[
    // `.bloom` — `redesign.html:253-254`.
    Positioned.fill(
      // `pointer-events:none`, transcribed. `RenderDecoratedBox` does not absorb
      // hits today, so this is belt-and-braces rather than a fix — but the CSS
      // says it and a decoration that starts absorbing a tap on a card's padding
      // is exactly the kind of regression nothing else here would catch.
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: kGlassBloomCenter,
              radius: kGlassBloomRadius,
              colors: <Color>[bloomColour, Colors.transparent],
              // `transparent 68%` — the whole of the substituted
              // `filter:blur(18px)`.
              stops: const <double>[0, kGlassBloomFadeStop],
              // Past the last stop there is nothing left of the gradient, and
              // `clamp` is what says so — the alternative tiles the colour back.
              tileMode: TileMode.clamp,
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
    // `.hor` — `redesign.html:256-257`, and the light override at `:72`.
    Positioned.fill(
      child: IgnorePointer(
        // `Align` and not `Positioned(bottom: …)`: the seam sits at a *fraction*
        // of the surface (`bottom:20%`) and `Positioned` takes logical px only.
        // `Align` also loosens the constraints its child receives, which is what
        // lets `FractionallySizedBox` pin the width at 72% while the height stays
        // the prototype's 2px — give the same widget a tight height and it would
        // stretch the bar to the full panel.
        child: Align(
          alignment: kGlassSeamAlignment,
          child: FractionallySizedBox(
            widthFactor: kGlassSeamWidthFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(kGlassSeamCornerRadius),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Colors.transparent,
                    colors.seam,
                    Colors.transparent,
                  ],
                  // Written out rather than left null. `null` is Flutter's
                  // "even evenly" spelling and would paint identically; being
                  // explicit is what lets a test read the three stops off the
                  // gradient the way the prototype's three colour stops are read
                  // off `:257`.
                  stops: const <double>[0, 0.5, 1],
                ),
                // `box-shadow:0 0 14px rgba(255,255,255,.6)`. A PAINT: one
                // `BoxShadow` on a `DecoratedBox`, not a `saveLayer`, which is
                // why the seam is allowed to glow at all under §13.4.
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.seamGlow,
                    blurRadius: kGlassSeamGlowBlur,
                  ),
                ],
              ),
              child: const SizedBox(height: kGlassSeamHeight),
            ),
          ),
        ),
      ),
    ),
  ];
}
