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
/// The dispatch spells this `FractionalOffset(0.5, 1.0)`. `Alignment` **extends**
/// `FractionalOffset`, so the two are the same coordinates; `RadialGradient`'s
/// parameter is typed `AlignmentGeometry`, which is why the declaration is
/// spelled `Alignment` here.
const Alignment kGlassBloomCenter = Alignment(0.5, 1);

/// The seam's width as a fraction of the surface — `redesign.html:256`'s
/// `left:14%;right:14%`.
const double kGlassSeamWidthFactor = 0.72;

/// The seam's height, `redesign.html:256`'s `height:2px`.
const double kGlassSeamHeight = 2;

/// Where the seam sits — `redesign.html:256`'s `bottom:20%`, which in an
/// [Alignment] is `-1 + 2 × 0.20`.
const Alignment kGlassSeamAlignment = Alignment(0, -0.6);

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
  /// (`:519`), `#lastCard` (`:524`) and four medals (`:599-602`), and
  /// `style.setProperty('--bh', …)` in the two loops that build book cards
  /// (`:1312`, `:1315`). `glass_surface_test.dart` walks all thirteen and fails
  /// on a fourth shape, because a fourth shape is a global definition and a
  /// global definition is something a token table *could* express.
  ///
  /// And the values genuinely disagree: `#votdCard` washes with
  /// `rgba(228,87,214,.55)` and `#lastCard` with `rgba(232,176,75,.35)`, and the
  /// four medals carry four more hues. A `bloom` token is a *default*, in
  /// precisely the sense `var(--bh, …)` is a default — which is what
  /// [EvaColors.bloom] is, and the only thing it claims to be.
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
          // A `Stack` sizes to its largest **non-positioned** child, and the only
          // one here is the content — both decoration layers are `Positioned`,
          // and they are the first children so they paint *behind* it. A tint or
          // a blur surface therefore measures exactly what it measured before the
          // bloom existed, which is why no golden had to be re-captured;
          // `glass_surface_test.dart` asserts that size so a future change to
          // this stack has to notice.
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
                borderRadius: const BorderRadius.all(Radius.circular(2)),
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
