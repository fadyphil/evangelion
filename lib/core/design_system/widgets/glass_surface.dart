import 'dart:ui' show ImageFilter;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which of the two glass treatments a surface gets.
///
/// ## WHY AN ENUM AND NOT A BOOL
///
/// §13.4 counts eight blur sites across the six shipped screens and rules that
/// only **two** of them may actually blur. A `bool blur` would make that budget
/// invisible at every call site: `GlassSurface(blur: true)` reads as "a glass
/// surface", says nothing about which of the eight sites it is, and defaults to
/// `false` in a way a future author will flip the first time a panel "looks
/// wrong" without it. An enum makes the choice a *decision* at every call site
/// and lets the two budgets be stated per variant:
///
/// | screen | tier | why |
/// | --- | --- | --- |
/// | `/login` | [tint] | a full-screen field cluster; a blur buys nothing |
/// | `/reading` | [tint] | dense text; the blur is barely perceptible |
/// | `/quiz` | [tint] | four stacked cards; four `saveLayer`s over content |
/// | `/` (Home) | [blur] **only** the today's-reading panel and the top bar | the only two places where glass sits over the animated background |
/// | everything else | [tint] | |
///
/// ## THE COST, STATED
///
/// [blur] is one `BackdropFilter`, and a `BackdropFilter` is one `saveLayer`
/// plus a full read-back of everything painted behind it, **per frame**. The
/// eight prototype sites would be eight of those; this enum is what keeps the
/// number at two. A seventh `.blur` is not a style choice, it is a frame budget
/// change.
///
/// ## AND WHAT ENFORCES THAT
///
/// The first version of this doc claimed the enum was enough "because this type
/// exists so that adding one is visible in a diff". A diff is review, not a gate:
/// somebody has to notice, count, and remember that the number is two, and
/// `rg 'GlassTier.blur' lib/` hit this file and nothing else — Phase 3 could
/// write it at all eight prototype sites and every test would stay green.
///
/// `glass_blur_budget_test.dart` is the gate. It walks `lib/features/`, fails
/// above **two** occurrences, names the two allowed sites (Home's
/// today's-reading panel and Home's top bar), and fails closed on a missing
/// directory, an unreadable file or an empty walk. It also refuses a
/// hand-built `BackdropFilter` in a feature, because that is the same
/// `saveLayer` with no budget attached to it.
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
  /// is expected to let it show through — Home's today's-reading panel and the
  /// top bar. Nowhere else.
  blur,
}

/// The Gaussian sigma of the [GlassTier.blur] backdrop, in logical px.
///
/// The prototype gives each of its eight sites its own radius — `8` (`Input`),
/// `12` (`QuizOption`), `16` (`StatTile`), `20` (`PassageCard` and Home's panel),
/// `24` (the Login form) — because they were eight hand-written CSS blocks.
/// Collapsing them to one widget has to collapse them to one number, and `20`
/// is the median: the two `20`s are the two surfaces that are actually allowed
/// to blur, so the blur that ships is the blur those two already had.
const double kGlassBlurSigma = 20;

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
        idleBorder: border
            ? Border.all(color: colors.glassBorder, width: 1)
            : null,
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
