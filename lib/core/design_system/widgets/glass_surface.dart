import 'dart:ui' show ImageFilter;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which of the two glass treatments a surface gets.
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
}

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
/// backdrop blur.
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
///
/// ## THE SHADOW IS NOT AN ELEVATION
///
/// [AGENT_CONTEXT] §9 decision 7 records that every `elevation` in this design
/// system is `0` because the prototype has no z-axis — every `box-shadow` there
/// is either a zero-offset ember glow or this one glass ambient. This
/// `BoxShadow` is that ambient: it is decoration on a `DecoratedBox`, not a
/// Material elevation, and it does not reintroduce a ramp.
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
    super.key,
  });

  /// The surface's content.
  final Widget child;

  /// Tint (no `saveLayer`) or blur. See [GlassTier] for the per-screen budget.
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

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final BorderRadius borderRadius = BorderRadius.circular(radius);

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
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
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

    final Widget body = tier == GlassTier.blur ? blur : surface;

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
}
