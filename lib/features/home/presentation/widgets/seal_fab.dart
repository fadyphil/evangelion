import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' show Effect;

/// The `E` speed dial — `ds.tsx:533-570`, transcribed.
///
/// ## WHAT IT IS, AND WHY IT EXISTS AGAIN
///
/// A 56×56 glass circle carrying the display-serif `E`, outlined in ember, which expands
/// into a column of pill destinations. `ds.tsx:541` places it `bottom: 28, right: 20`,
/// and it is the **only** screen that carries one.
///
/// **It was cut**, and the reason was sound: its menu was Profile, Settings and Language,
/// and by then Profile had no endpoint, Settings was already the avatar's job on `/`, and
/// Language was already a row inside `/settings`. One dead item and two duplicates, and
/// a floating control whose only unique function leads nowhere is worse than no floating
/// control.
///
/// It came back because **`/communion` became a live route with no other entry point on
/// `/`** beyond a link inside the card. Profile's slot took it.
///
/// **And the dial has three items again, since Task 5.6 — for a different reason,
/// and the paragraph above is the receipt for the first time it had two.** The
/// **journey** took the profile's *other* half: ADR-0022 restored the profile and
/// the redesign makes it a **dock tab** (`eva/redesign.html:707`), so its real
/// entry is Phase 6's dock, and until then the dial is the interim holder of the
/// destinations `/` cannot otherwise reach. It already held the board — the
/// prototype's other dock tab (`:706`) — and Settings, which the redesign's `/`
/// has no other way to reach either.
///
/// **Three items, and each goes somewhere a reader cannot otherwise reach in one
/// tap.** The count is the prototype's (`ds.tsx:537-541` — Profile, Settings,
/// Language) with Language out and the two live dock destinations in.
///
/// ## WHY IT LIVES IN `NeuralScaffold.overlay`
///
/// Because `/` scrolls, and anything placed in the page's column scrolls away with it. A
/// floating affordance that scrolls off is not a floating affordance.
class SealFab extends StatefulWidget {
  /// The dial, collapsed, over [items].
  const SealFab({required this.items, super.key});

  /// The destinations, **topmost first**.
  ///
  /// `ds.tsx:541` runs `flexDirection: 'column'` with the items before the trigger, so
  /// the first entry is the one furthest from the thumb.
  ///
  /// Every entry needs a non-empty [SealFabItem.label]: it is the pill's text, its
  /// accessible name, and the thing §14 requires to exist.
  final List<SealFabItem> items;

  @override
  State<SealFab> createState() => _SealFabState();
}

class _SealFabState extends State<SealFab> {
  /// **Collapsed on arrival**, and the reason is that `/` is a reading screen: a dial
  /// that arrives open stands over the passage the reader came for, and the one thing a
  /// floating affordance must not do is obscure content before it has been asked to.
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  // ## THE PROTOTYPE'S 40ms STAGGER IS **NOT** REPRODUCED, AND THAT IS A DELIBERATE
  // DIVERGENCE
  //
  // `ds.tsx:548` writes `animation: screen-in 200ms ease-out ${i * 40}ms both`, so the
  // pills arrive 40ms apart. Reproducing that needs a **delay**, and `EvaAnimate` has no
  // delay parameter by design: its doc says timings are the enum's job and that "there is
  // no `duration` or `curve` argument anywhere below, so a literal cannot reach an effect
  // even by accident." A per-index delay would be `40ms * i` written at a call site —
  // exactly the literal that rule exists to prevent.
  //
  // So the pills run [MotionMoment.screen] **together**: one authored moment, which is
  // also what a three-item speed dial wants. Three pills 40ms apart reads as a sequence;
  // three at once reads as one control opening.

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = Directionality.of(context);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        // `ds.tsx:541` — `bottom: 28, right: 20`.
        //
        // A `Padding` inside a corner `Align`, not a `Positioned` child of a `Stack`.
        // The prototype's `position: absolute` is expressed by `NeuralScaffold`'s own
        // stack, which is where `overlay` is placed; re-introducing one here would mean
        // reaching outside this widget for a parent that need not be a stack at all.
        padding: const EdgeInsets.only(
          right: EvaSpacing.lg,
          bottom: EvaSpacing.xxl + EvaSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (final SealFabItem item in widget.items)
              if (_open)
                Padding(
                  // `ds.tsx:542` — `gap: 8`.
                  padding: const EdgeInsets.only(bottom: EvaSpacing.sm),
                  child: EvaAnimate(
                    key: ValueKey<String>('seal-fab-item-${item.label}'),
                    // `ds.tsx:548` — `screen-in 200ms ease-out`. `screenIn` is the
                    // prototype's name for a surface arriving, which is what a pill is,
                    // so `MotionMoment.screen` is the matching moment and its duration
                    // and curve are the tokens — no literal reaches this call site.
                    effects: <Effect<dynamic>>[
                      MotionMoment.screen.fadeIn(),
                      MotionMoment.screen.slide(
                        direction == TextDirection.rtl
                            ? const Offset(0, -0.3)
                            : const Offset(0, 0.3),
                      ),
                    ],
                    child: SealFabPill(
                      label: item.label,
                      onTap: () {
                        // Close **before** navigating, so a route change never happens
                        // behind an open speed dial.
                        setState(() => _open = false);
                        item.onTap();
                      },
                    ),
                  ),
                ),
            SealFabTrigger(open: _open, onTap: _toggle),
          ],
        ),
      ),
    );
  }
}

/// One destination in the open dial.
@immutable
class SealFabItem {
  /// A destination labelled [label] that runs [onTap].
  const SealFabItem({required this.label, required this.onTap});

  /// The destination's name, in the reader's language.
  ///
  /// Simultaneously the pill's text and its accessible name, which is why it is required
  /// and why §14 treats an empty one as a defect rather than a style.
  final String label;

  /// Navigates.
  final VoidCallback onTap;
}

/// The 56×56 circle.
///
/// Public so a test can tap it without reaching for a descendant.
class SealFabTrigger extends StatelessWidget {
  /// The thumb, showing an [open] dial.
  const SealFabTrigger({required this.open, required this.onTap, super.key});

  /// Whether the dial is expanded — the name and the `expanded` flag both change with it.
  final bool open;

  /// Opens or closes the dial.
  final VoidCallback onTap;

  /// `ds.tsx:559-560` — `width: 56, height: 56, borderRadius: '50%'`.
  ///
  /// Not a token: this is a size rather than a step on a scale, and a 56px circle has no
  /// meaning as a spacing value.
  static const double diameter = 56;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      // **`container: true`, and a correction about why.**
      //
      // Added while chasing a semantics fault that turned out to have a different
      // cause: the pills were at **opacity 0**, and `RenderOpacity` drops semantics for
      // a fully transparent subtree, so the fix was a pump rather than a container.
      // Deleting `container: true` leaves every test green, which means **no test here
      // requires it.**
      //
      // It stays, and the honest reason is defensive rather than proven: a `Semantics`
      // node without `container` merges into the nearest ancestor that can hold
      // semantics, so sibling pills *can* become one control — and a speed dial whose
      // items cannot be reached individually is not a menu. Describing this as "a test
      // caught it" would be the third retracted claim in this file's neighbourhood.
      container: true,
      button: true,
      expanded: open,
      // **A name that says what activating does**, per §14. The prototype gives this
      // button no accessible name at all — its content is the text `E` — which is the
      // same defect `SegmentedControl`'s track shipped with.
      label: open ? context.l10n.sealFabClose : context.l10n.sealFabOpen,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // `ds.tsx:561` — `outline: 1.5px solid rgba(hex.ember, 0.6)`.
            //
            // **`emberInk`, not `ember`** — decision 153. A 1.5px outline on the pale
            // canvas is a drawn line the reader has to resolve, and light `ember`
            // measures 2.11:1 there. The fill token is for fills.
            border: Border.all(
              color: colors.emberInk.withValues(alpha: 0.6),
              width: 1.5,
            ),
            // `ds.tsx:562` — `0 0 30px rgba(ember, 0.3), 0 8px 20px rgba(#000, .35)`.
            // Only the ember bloom is stated here; the drop belongs to the surface.
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ember.withValues(alpha: 0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: ClipOval(
            // The **fill comes from [GlassSurface]**, and only the geometry and the
            // ember rim are stated here.
            //
            // ## AND IT IS THE **`tint`** TIER, NOT `blur`, AGAINST THE PROTOTYPE
            //
            // `ds.tsx:559-561` blurs this circle at `blur(20px)` and the pill at
            // `blur(16px)`. Both are dropped.
            //
            // **§13.4 budgets ONE blur site per screen and `/` has already spent it** on
            // the passage panel (`HomeScreen.tsx:39`). `glass_blur_budget_test.dart`
            // counts `GlassTier.blur` and failed this file twice: first for two raw
            // `BackdropFilter`s, then for two accounted ones. The budget is about cost —
            // a `BackdropFilter` is a save layer, two more of them on the screen a reader
            // spends the most time on is a real price on low-end hardware — and it is a
            // decision with a number in it rather than a preference.
            //
            // So the dial reads as glass from what is left: a translucent fill, the
            // prototype's hairline rim, and the ember bloom. A 56px circle over an
            // animated background loses very little to the missing blur, and it costs no
            // save layer.
            //
            // Raising the budget to three was available and was **not** taken: §13.4's
            // count is a deliberate act and a floating affordance is a poor reason to
            // spend it on.
            child: GlassSurface(
              // `GlassTier.tint` — `GlassSurface`'s own default, so no `tier:` is
              // passed, which is the whole of the argument above: this pill is one
              // of the eight sites the budget refuses.
              radius: diameter / 2,
              padding: EdgeInsets.zero,
              // The rim above is the outline. `GlassSurface`'s own hairline would be a
              // second border on the same edge.
              border: false,
              child: Center(
                child: Text(
                  'E',
                  style: arabicAware(
                    Theme.of(context).textTheme.headlineSmall!.copyWith(
                      // `ds.tsx:564` — `F.display, 22, w600, color: T.ink`.
                      //
                      // `arabicAware` is the **identity** here and the comment says why:
                      // `E` is a Latin letter in both arms. It is the product's initial,
                      // not a word, so asking the Arabic face to draw it would be the
                      // wrong call dressed as the right one.
                      fontFamily: EvaTypography.displayFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                      height: 1,
                    ),
                    direction,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination pill.
///
/// Public so a test can count the open dial's items structurally, rather than by their
/// labels — which would be a text assertion dressed as a structural one, and would pass
/// with three identical labels.
class SealFabPill extends StatelessWidget {
  /// A pill labelled [label] that runs [onTap].
  const SealFabPill({required this.label, required this.onTap, super.key});

  /// The destination's name, and its accessible name.
  final String label;

  /// Runs the destination.
  final VoidCallback onTap;

  /// `ds.tsx:545-551` — `F.ui, 14, w600, T.ink`, `rgba(fff|000, 0.08)`,
  /// `blur(16px)`, `1px solid rgba(fff|000, 0.12)`, `borderRadius: 999`,
  /// `padding: '8px 18px'`, `boxShadow: 0 8px 24px rgba(#000, 0.35)`.
  ///
  /// `borderRadius: 999` is transcribed as [radius] rather than as the number, because
  /// 999 is not a radius anyone can hold in their head and the intent — fully round — is
  /// what has to survive.
  static const double radius = 999;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      // `container: true` for the reason the trigger's doc gives.
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(radius),
            // `ds.tsx:549` — `1px solid rgba(fff|000, 0.12)`, which is
            // `glassBorder` in both palettes.
            border: Border.all(color: colors.glassBorder),
            // `ds.tsx:551` — `0 8px 24px rgba(#000, 0.35)`.
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.glassShadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            // `GlassTier.tint` is `GlassSurface`'s own default, so no `tier:` is passed — for
            // the reason the trigger's doc gives: `/`'s one blurred site is the
            // passage panel, and a pill does not get a second one.
            child: GlassSurface(
              radius: radius,
              // `ds.tsx:550` — `padding: '8px 18px'`. 18 is `md` plus `xs` on the
              // 4px scale and 8 is `sm`, so both land on tokens without rounding.
              padding: const EdgeInsets.symmetric(
                horizontal: EvaSpacing.md + EvaSpacing.xs,
                vertical: EvaSpacing.sm,
              ),
              // The `BoxDecoration` above already carries the fill, the rim and the
              // drop; this surface contributes the blur and nothing that draws twice.
              border: false,
              child: Text(
                label,
                style: arabicAware(
                  Theme.of(context).textTheme.bodyMedium!.copyWith(
                    // `ds.tsx:546-547` — `F.ui, 14, w600`.
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                  direction,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
