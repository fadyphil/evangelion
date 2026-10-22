/// The redesign's five-slot bottom dock.
///
/// `eva/redesign.html:702-708` is the prototype's `<nav class="dock">` and
/// `:208-234` is the stylesheet that draws it. This widget is that nav: five
/// slots, one active marker, and a report of taps.
///
/// ## WHAT IT IS, AND WHAT IT IS NOT
///
/// **It draws slots and reports taps, and it knows nothing about routing.**
/// There is no route, no feature and no locator anywhere in this file, and the
/// caller's [LumenDockItem]s carry the words and the glyphs. That is what lets
/// five screens share the dock without any of them knowing about the others,
/// and it is why the item carries a [Widget] rather than an [IconData]: the
/// "today" slot is not an icon at all (`:705` is the orb), and a type that
/// could only hold an icon could not hold it.
///
/// ## THE NUMBERS, AND WHERE EACH ONE COMES FROM
///
/// | what | number | prototype |
/// | --- | --- | --- |
/// | the dock's height | 78 | `:208` |
/// | the top corner radius | 26 | `:208` |
/// | the padding | 10 top, 6 each side, 16 bottom | `:211` |
/// | the slot gap | 7 | `:216` |
/// | the glyph zone | 32 | `:218` |
/// | the icon | 20 | `:219` |
/// | the label | 10.5, weight 500, tracking .02em | `:220` |
/// | the beam | 2 wide, 14 tall when active | `:221`, `:225` |
/// | the hairline | 1.5 tall, 12% in from each side | `:213` |
/// | the backdrop blur | 22 | `:210` |
///
/// Every one of those is a public constant on [LumenDock] and every one of
/// them is asserted against the stylesheet at test time by
/// `test/features/dock/presentation/widgets/lumen_dock_test.dart`, which reads
/// `eva/redesign.html` rather than a table.
///
/// ## THE COLOURS ARE THE DESIGN SYSTEM'S, NOT THE PROTOTYPE'S
///
/// The prototype's `--gold` (`redesign.html:14`) is `EvaColors.ember` — the
/// **repaired** gold, which is not the prototype's light-mode value (decision
/// 153 changed it) — and the prototype's `--ink-2` (`:13`) is
/// [EvaColors.ink2]. The dock's own background is [EvaColors.canvas] at the
/// prototype's own alpha, and the two alphas are different: `rgba(8,10,18,.86)`
/// in dark (`:209`) and `rgba(255,255,255,.74)` in light (`:64`).
///
/// **The light arm's background is a recorded substitution.** The prototype
/// writes **white** at 74% for the light dock, and this ships [EvaColors.canvas]
/// — which is `#F0EEFF` in the light palette — at the same 74%. The app's
/// light canvas is the pale lavender its whole palette is built on, and the
/// prototype's is a warm paper (`#F5F2EA`, `redesign.html:56`); the two are
/// close enough that the dock reads the same, and the *alpha* — the number
/// that decides how much of the page shows through the glass — is the
/// prototype's own.
///
/// ## THE BLUR, AND THE BUDGET IT SPENDS
///
/// `eva/redesign.html:210` is `backdrop-filter:blur(22px)`, so the dock owns a
/// [BackdropFilter] and the sigma is the prototype's own 22 — **not** the
/// design system's `kGlassBlurSigma` (24), which is Home's panel's radius.
///
/// **This is the SECOND blur site under `lib/features/`, and it is charged to
/// the budget like any other.** `test/core/design_system/widgets/glass_blur_budget_test.dart`
/// walks `lib/` and allows **two** sites: Home's today's-reading panel and
/// this one. The gate counts **sites**, of **both spellings** — the enum and a
/// hand-built [BackdropFilter] — because a count that read only the enum would
/// have been **blind to the dock**, and a count of lines would have read the
/// dock's one site (spelled over two lines) as two.
///
/// **And the exception is about the SHAPE, not about escaping the count.**
/// `GlassSurface` paints a *panel* — a fill, a rim and a shadow, with one
/// radius on all four corners — and the dock is a full-width **bar** with its
/// own alpha (0.86 dark, 0.74 light), a hairline on its **top** edge only and
/// a radius on its **top** two corners only. A third site anywhere else is
/// still red.
///
/// ## THE ANIMATION, AND §14
///
/// Two motions, both from the prototype: the beam grows over 450ms
/// (`:221`) and the slot's ink changes colour over 250ms (`:217`), and the
/// orb's ripple runs forever on a 2.6s cycle (`:230`).
///
/// §14 requires every animation to read
/// [MediaQuery.disableAnimationsOf] and to jump straight to the end state when
/// motion is reduced, and the three are handled three different ways because
/// they are three different mechanisms: the slot's two transitions are driven
/// by one [AnimationController] the slot owns, and the ripple has **no
/// controller of its own** — it reads the app's shared clock, exactly as
/// `GoldFlecks` does, because §13.2's mitigation is that the app owns a fixed
/// number of tickers and a widget that starts its own is a new one.
///
/// ## AND THE ONE **INFINITE** ANIMATION IS ON THE **BUDGET**
///
/// The ripple is the dock's only animation that never stops, so it is the one
/// that has to be paced: it rides the app's **gated** notifier
/// (`motion.repaint`) rather than the raw clock's per-vsync notification, and
/// it carries its own [RepaintBoundary] so its repaint does not re-record the
/// dock's σ22 blur layer. ADR-0025, `docs/PERFORMANCE.md` §3.2 and §5.1.
library;

import 'dart:ui' show ImageFilter;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// One slot of the dock.
@immutable
class LumenDockItem {
  /// Creates a slot.
  const LumenDockItem({
    required this.label,
    required this.glyph,
    this.semanticLabel,
  });

  /// The visible label under the glyph.
  ///
  /// The redesign's `.dlab` — `eva/redesign.html:220` — and the five words are
  /// the prototype's own i18n rows at `:931-932` (`dockHome`, `dockRead`,
  /// `dockToday`, `dockBoard`, `dockJourney`).
  ///
  /// **The string is the caller's.** The dock has no localization table of its
  /// own, because a dock whose labels it owns would be a dock that knew which
  /// screen it was on.
  final String label;

  /// The glyph. The dock draws the slot; the caller draws the glyph.
  ///
  /// The prototype's own glyphs are four SVGs at 20×20 (`:219`) and the "today"
  /// orb (`:705`), and **the dock draws neither**: the slot's *zone* is a 32px
  /// box (`:218`) and what sits in it belongs to the caller, so one dock can
  /// carry five slots for five screens without knowing what any of them
  /// navigates to.
  ///
  /// The dock does supply the **ink**: the glyph is wrapped in an [IconTheme]
  /// and a [DefaultTextStyle] carrying the slot's colour, so an [Icon] or a
  /// [Text] glyph picks up the active and inactive inks the prototype sets on
  /// `.dtab` (`:217` and `:223`).
  final Widget glyph;

  /// The accessible name, when it differs from [label].
  ///
  /// `null` — the default — means the slot announces its [label], which is
  /// what the prototype's five do (`:703-707` name each tab by its own word).
  /// A caller whose glyph carries meaning the word does not — a count, a
  /// badge — names the slot here instead of changing the visible label.
  final String? semanticLabel;
}

/// The redesign's five-slot dock.
///
/// ## THE FIVE SLOTS
///
/// `eva/redesign.html:702-708` is the prototype's `<nav class="dock">` and it
/// holds five `<button class="dtab">` in this order: **home**, **read**,
/// **today**, **board**, **journey**. The order is the prototype's and the
/// dock does not reorder it; [items] is a list because the dock draws what it
/// is given, and the prototype's order is the caller's to keep.
///
/// ## THE ACTIVE MARKER
///
/// Three things change when a slot is active, and the prototype writes all
/// three: the slot's ink becomes the gold (`:223` — `.dtab.on{color:var(--gold)}`),
/// a 14px beam appears above it (`:225` — `.dtab.on .beam{height:14px;opacity:1}`)
/// and the label goes to weight 600 (`:226` — `.dtab.on .dlab{font-weight:600}`).
///
/// **The weight changes instantly and the other two do not**, because that is
/// what the prototype declares: `.dtab`'s `transition:color .25s` (`:217`)
/// covers the ink and nothing else, and there is no transition on
/// `font-weight` anywhere in the file. A weight that interpolated would be a
/// motion the design does not have.
///
/// ## THE 78 IS A REQUEST, AND THE CALLER OWNS THE REST
///
/// The dock asks for [height] logical pixels of height, and **a parent that
/// hands its child a *tight* height keeps it** — in this Flutter, a
/// `SizedBox(height: 78)` inside a tight 568-tall parent is 568 tall, because
/// the parent's constraint wins the conflict.
///
/// So the dock must be placed where its height is free: the prototype places it
/// with `position:absolute;left:0;right:0;bottom:0` (`:208`), and the
/// Flutter spelling of that is a `Stack` with
/// `Positioned(left: 0, right: 0, bottom: 0)`, which gives the dock an
/// unbounded height and lets its own 78 stand. `Positioned(bottom: 0, …)` in a
/// `Stack` is what the app's shell does.
class LumenDock extends StatelessWidget {
  /// Creates the dock.
  const LumenDock({
    required this.items,
    required this.activeIndex,
    required this.onSelect,
    super.key,
  });

  /// The slots, in the order they are drawn.
  ///
  /// The prototype's five are at `eva/redesign.html:703-707`.
  final List<LumenDockItem> items;

  /// The index of the active slot, or -1 for none.
  ///
  /// **-1 is a state, not a mistake.** The prototype's own markup ships the
  /// dock hidden (`:702` — `class="dock hide"`) and the script shows it once a
  /// route is open, so a dock with no active slot is a shape the design has.
  final int activeIndex;

  /// Called with the tapped slot's index.
  ///
  /// The dock does not navigate; it reports. Which route a slot means is the
  /// caller's business, and this callback is the whole of the contract.
  final ValueChanged<int> onSelect;

  // --- Geometry ------------------------------------------------------------
  //
  // Every number below is the prototype's, and every one of them is asserted
  // against `eva/redesign.html` at test time.

  /// The dock's height — `eva/redesign.html:208`, `height:78px`.
  static const double height = 78;

  /// The radius of the dock's two top corners — `:208`, `border-radius:26px 26px 0 0`.
  ///
  /// **Only the top two.** The prototype's shorthand is four values and the
  /// last two are zero, so the dock's bottom edge is square.
  static const double topRadius = 26;

  /// The dock's top padding — `:211`, `padding:10px 6px 16px`.
  static const double paddingTop = 10;

  /// The dock's left and right padding — `:211`, the `6px` of the same shorthand.
  static const double paddingHorizontal = 6;

  /// The dock's bottom padding — `:211`, the `16px` of the same shorthand.
  static const double paddingBottom = 16;

  /// The gap between a slot's glyph and its label — `:216`, `.dtab{… gap:7px}`.
  static const double slotGap = 7;

  /// The height of the box a slot's glyph sits in — `:218`, `.dtab .zone{height:32px}`.
  static const double zoneHeight = 32;

  /// The prototype's icon size — `:219`, `.dic{width:20px;height:20px}`.
  ///
  /// **Published for the caller's benefit and not used here**, because the dock
  /// does not draw the glyph. The four SVG icons are 20×20 and the orb is 30
  /// (`:228`), so the zone (32) is the only size the dock owns; a caller
  /// drawing an icon draws it at this.
  static const double iconSize = 20;

  /// The label's size — `:220`, `.dlab{font-size:10.5px}`.
  static const double labelSize = 10.5;

  /// The label's tracking, in em — `:220`, `.dlab{letter-spacing:.02em}`.
  ///
  /// **In em and not in pixels**, because the prototype writes it in em and
  /// the conversion is the caller's claim: the label's own size multiplies it.
  /// `:135` zeroes it in RTL (`[dir=rtl] .mono,[dir=rtl] .dlab{letter-spacing:0}`),
  /// and that is honoured too.
  static const double labelTrackingEm = 0.02;

  /// The beam's width — `:221`, `.beam{… width:2px;…}`.
  static const double beamWidth = 2;

  /// The beam's height when its slot is active — `:225`, `.dtab.on .beam{height:14px}`.
  static const double beamHeight = 14;

  /// The hairline's height — `:213`, `.dock::before{… height:1.5px;…}`.
  static const double hairlineHeight = 1.5;

  /// The hairline's inset from each side, as a fraction — `:213`,
  /// `.dock::before{… left:12%;right:12%;…}`.
  static const double hairlineInset = 0.12;

  /// The backdrop blur's sigma — `:210`, `backdrop-filter:blur(22px)`.
  static const double blurSigma = 22;

  /// The dark background's alpha — `:209`, `background:rgba(8,10,18,.86)`.
  static const double backgroundAlphaDark = 0.86;

  /// The light background's alpha — `:64`,
  /// `.screen[data-mode=light] .pill,.screen[data-mode=light] .dock{background:rgba(255,255,255,.74)}`.
  static const double backgroundAlphaLight = 0.74;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // **The brightness decides the alpha**, and the two are different: 86% in
    // dark (`:209`) and 74% in light (`:64`). The light dock is more
    // transparent because the light canvas is nearly white and the blur has
    // less to hide.
    final bool light = Theme.of(context).brightness == Brightness.light;
    final double alpha = light ? backgroundAlphaLight : backgroundAlphaDark;
    const BorderRadius radius = BorderRadius.vertical(
      top: Radius.circular(topRadius),
    );

    return SizedBox(
      height: height,
      child: Stack(
        // `Clip.none` so the orb's ripple may leave the dock, as it does in the
        // prototype: `.orbmini::after` scales to 1.6× (`:234`) and the dock
        // declares no `overflow:hidden`.
        clipBehavior: Clip.none,
        children: <Widget>[
          // ## THE BLURRED BACKDROP
          //
          // `eva/redesign.html:210` — `backdrop-filter:blur(22px)`. It is the
          // **first** child so that it reads the page behind the dock, and it
          // is clipped to the dock's rounded corners so the blur does not
          // bleed past them — which is the one thing the prototype gets from
          // its own `border-radius` for free.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // ## THE TINT
          //
          // `rgba(8,10,18,.86)` in dark (`:209`), `rgba(255,255,255,.74)` in
          // light (`:64`) — the canvas at the prototype's own alpha. The
          // 1px top border is `:209`'s `border-top:1px solid rgba(255,255,255,.08)`
          // and `:65`'s light `border-top-color:rgba(20,22,30,.1)`; it is
          // [EvaColors.glassBorder], which is the design system's own 1px
          // glass rim, white at 8% in dark and black at 8% in light.
          //
          // **A `BoxDecoration` cannot carry a rounded border AND a top-only
          // border** — the framework asserts that a radius needs a uniform
          // `Border` — so the rounding is the [ClipRRect] above and the
          // decoration below is square-cornered.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.canvas.withValues(alpha: alpha),
                border: Border(top: BorderSide(color: colors.glassBorder)),
              ),
            ),
          ),
          // ## THE SLOTS
          Padding(
            padding: const EdgeInsets.fromLTRB(
              paddingHorizontal,
              paddingTop,
              paddingHorizontal,
              paddingBottom,
            ),
            child: Row(
              // `align-items:stretch` — `:211`. Every slot is the full height
              // of the content box, which is what puts the beam at the top of
              // the dock rather than at the top of the glyph.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int index = 0; index < items.length; index++)
                  Expanded(
                    child: _LumenDockSlot(
                      item: items[index],
                      active: index == activeIndex,
                      onTap: () => onSelect(index),
                    ),
                  ),
              ],
            ),
          ),
          // ## THE `::before` HAIRLINE
          //
          // `eva/redesign.html:213-214` — `top:-1px;left:12%;right:12%;
          // height:1.5px;border-radius:2px;` over a gold gradient with a 14px
          // glow.
          //
          // **The prototype's `top:-1px` is a negative offset and Flutter's
          // [Positioned] refuses one** (it asserts `top >= 0`). The rule
          // positions the pseudo-element at `-1px` because the dock's own
          // `border-top` is 1px, so the hairline sits *on* the border line
          // rather than above it; this draws it at the dock's top edge, over
          // the same 1px band, which is the same place.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: hairlineHeight,
            child: FractionallySizedBox(
              // 12% in from each side, so 76% of the width.
              widthFactor: 1 - 2 * hairlineInset,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      // `rgba(232,176,75,.55)` — `:214`.
                      colors.ember.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    // `box-shadow:0 0 14px rgba(232,176,75,.45)` — `:214`.
                    BoxShadow(
                      color: colors.ember.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The redesign's five-slot dock's one slot.
///
/// **Private, and the state is the reason.** A slot owns an
/// [AnimationController] for its beam and its ink, and a controller needs a
/// [State] to live in.
class _LumenDockSlot extends StatefulWidget {
  const _LumenDockSlot({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final LumenDockItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_LumenDockSlot> createState() => _LumenDockSlotState();
}

class _LumenDockSlotState extends State<_LumenDockSlot>
    with SingleTickerProviderStateMixin {
  /// The slot's one controller, over the **longest** of its two transitions.
  ///
  /// 450ms is the beam's (`:221`); the ink's is 250ms (`:217`) and is derived
  /// from the same value rather than owning a second controller. The initial
  /// value is the slot's state, so a dock that opens on a slot shows that
  /// slot's beam at once — the prototype has no entrance animation for it.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: EvaMotion.dockBeam,
    value: widget.active ? 1.0 : 0.0,
  );

  /// Whether the reader has asked for reduced motion.
  ///
  /// **Read in [build] and remembered**, because [didUpdateWidget] cannot read
  /// an inherited widget safely while the tree is building — and the value it
  /// needs is the one from the last build, which is at most one frame stale
  /// and is refreshed by the rebuild the change itself causes.
  bool _reduceMotion = false;

  /// Whether the slot is being pressed.
  ///
  /// `.dtab:active{transform:scale(.94)}` — `:227`. **No transition**, because
  /// the prototype declares none on the scale: the slot shrinks and springs
  /// back, which is a different motion from the beam's.
  bool _pressed = false;

  /// The scale a pressed slot shrinks to — `:227`'s `scale(.94)`.
  static const double pressScale = 0.94;

  @override
  void didUpdateWidget(_LumenDockSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (_reduceMotion) {
      // §14 — jump straight to the end state. `stop()` does not notify, so
      // this is safe to call while the tree is building, and the rendered
      // value comes from `widget.active` rather than from the controller.
      _controller.stop();
      return;
    }
    if (widget.active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    // §14 — the reader can turn reduced motion OFF again, and the controller
    // was **frozen** while it was on. A frozen controller holds whatever value
    // it had, and that value can be the **opposite** of the slot's current
    // state: a slot that became active while motion was reduced was frozen at
    // 0.0, so the moment motion comes back the marker would be **inverted** —
    // the active slot in the inactive ink and the other way round.
    //
    // So the flip **resynchronises** the controller and then animates it: the
    // end state is the current one, and the reader sees the beam grow rather
    // than a jump.
    if (reduceMotion != _reduceMotion) {
      if (reduceMotion) {
        _controller.stop();
      } else {
        _controller.value = widget.active ? 0.0 : 1.0;
        if (widget.active) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      }
    }
    _reduceMotion = reduceMotion;
    if (_reduceMotion && _controller.isAnimating) {
      // The reader asked for reduced motion while the beam was growing. The
      // rendered value already ignores the controller, so stopping it here is
      // only about not burning frames on a motion nobody can see.
      _controller.stop();
    }

    return Semantics(
      // §14 — a slot is a button, and the prototype's five are `<button>`s
      // (`:703-707`).
      button: true,
      selected: widget.active,
      // The accessible name. The caller's `semanticLabel` when it gave one,
      // and the visible label otherwise.
      label: widget.item.semanticLabel ?? widget.item.label,
      child: EvaFocusRing(
        child: EvaInk(
          onPressed: widget.onTap,
          onHighlightChanged: (bool pressed) {
            if (pressed == _pressed) return;
            setState(() => _pressed = pressed);
          },
          child: ExcludeSemantics(
            // The visible label and the glyph are **excluded** from the
            // semantics tree, because the node above already carries the
            // slot's name and the two together would read "Home, Home".
            // `GlassSurface` is the precedent for the shape — a [Semantics]
            // around an [EvaInk] — and `EvaToggle`'s doc records the same
            // trade for the switch.
            child: _LumenSlotScope(
              active: widget.active,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  final double t = _reduceMotion
                      ? (widget.active ? 1.0 : 0.0)
                      : _controller.value;
                  // ## THE PRESS
                  //
                  // `.dtab:active{transform:scale(.94)}` — `:227`. **No
                  // transition**, because the prototype declares none on the
                  // scale: the slot shrinks under the finger and springs back,
                  // which is a different motion from the beam's. CSS scales
                  // about the element's centre, which is [Transform.scale]'s
                  // default alignment.
                  return Transform.scale(
                    scale: _pressed ? pressScale : 1.0,
                    child: Stack(
                      // `Alignment.center` and not the default `topStart`: the
                      // prototype's `.dtab` is `justify-content:center` (`:216`),
                      // so the glyph and the label sit in the middle of the
                      // slot's height. The beam is `Positioned`, so the
                      // alignment does not move it.
                      alignment: Alignment.center,
                      children: <Widget>[
                        // ## THE BEAM
                        //
                        // `:221-222` — `position:absolute;top:0;width:2px;
                        // height:0;border-radius:2px;background:linear-gradient
                        // (180deg,var(--gold),transparent);box-shadow:0 0 10px
                        // var(--gold)`, and `:225` — `.dtab.on .beam{height:14px;
                        // opacity:1}`.
                        //
                        // The height is the only part that grows, and the
                        // opacity is a **separate 300ms** (`:222`), which is why
                        // the two are derived from one value rather than being
                        // one number.
                        Positioned(top: 0, child: _beam(colors, t)),
                        // ## THE GLYPH AND THE LABEL
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          // `stretch` and not the default `center`: the
                          // prototype's `.dlab` is a block, so the label has the
                          // slot's whole width and its own `text-align` decides
                          // where the word sits inside it. A centred child would
                          // take only its own width, and the ellipsis below
                          // would never have anything to cut.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: LumenDock.slotGap,
                          children: <Widget>[
                            // `.dtab .zone{height:32px;display:grid;
                            // place-items:center}` — `:218`.
                            SizedBox(
                              height: LumenDock.zoneHeight,
                              child: Center(child: widget.item.glyph),
                            ),
                            _label(context, colors, t),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The slot's beam, at the progress [t].
  Widget _beam(EvaColors colors, double t) {
    // The height runs on `--e-light` over 450ms (`:221`); the opacity is its
    // own 300ms (`:222`).
    final double height =
        LumenDock.beamHeight * EvaMotion.interactiveCurve.transform(t);
    final double opacity =
        (t *
                EvaMotion.dockBeam.inMilliseconds /
                EvaMotion.dockFade.inMilliseconds)
            .clamp(0.0, 1.0);
    return SizedBox(
      width: LumenDock.beamWidth,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LumenDock.beamWidth),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              // The beam's own opacity (`:221`'s `opacity:0`) is applied to
              // the ink rather than through an [Opacity] widget, because an
              // [Opacity] is a `saveLayer` and this is a 2px bar drawn on every
              // frame of the beam's growth.
              colors.ember.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
          boxShadow: <BoxShadow>[
            // `box-shadow:0 0 10px var(--gold)` — `:222`, at the gold's own
            // strength rather than at an alpha.
            BoxShadow(
              color: colors.ember.withValues(alpha: opacity),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  /// The slot's label, at the progress [t].
  Widget _label(BuildContext context, EvaColors colors, double t) {
    final TextDirection direction = Directionality.of(context);
    // The ink's own 250ms (`:217`), with the house's ease-out on it.
    final double inkProgress = EvaMotion.fastCurve.transform(
      (t * EvaMotion.dockBeam.inMilliseconds / EvaMotion.dockInk.inMilliseconds)
          .clamp(0.0, 1.0),
    );
    // `Color.lerp` returns null only when one of its ends is null, and both
    // are tokens read off the palette — so the `!` is provable here.
    final Color ink = Color.lerp(colors.ink2, colors.ember, inkProgress)!;

    return Text(
      widget.item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: ink,
        // `:220` inherits the body's `var(--ui)` — Inter — and `:134` re-points
        // the whole dock at `var(--ui-ar)` in RTL. **Amiri and not
        // `IBMPlexSansArabic`**, because this repository's own Arabic gate
        // (`test/support/arabic_typography_gate.dart`) requires every rendered
        // Arabic run to be in [EvaTypography.arabicFamily]; the prototype's
        // `--ui-ar` is the redesign's chrome face and the gate is this
        // client's rule.
        fontFamily: arabicAware(
          const TextStyle(fontFamily: EvaTypography.uiFamily),
          direction,
        ).fontFamily,
        fontSize: LumenDock.labelSize,
        // `:226` — `.dtab.on .dlab{font-weight:600}`. **Instant**, because
        // the prototype transitions the colour and not the weight.
        fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
        // `:220`'s `.02em`, and `:135`'s `[dir=rtl] .dlab{letter-spacing:0}`.
        letterSpacing: direction == TextDirection.rtl
            ? 0
            : LumenDock.labelTrackingEm * LumenDock.labelSize,
        // **A line height the prototype does not declare, and it is here for
        // §14.** The browser's `normal` is about 1.21, which puts the slot's
        // content at 51.7 of the 52 available — and §14's 1.22× text scale
        // would push it to 54.5 and overflow the dock's fixed 78px by 2.5px
        // on every phone at the reader's own preferred text size. `height: 1.0`
        // fits it, and the ink is unchanged: a line box is a box, and the
        // glyphs sit in the middle of it either way.
        height: 1.0,
      ),
    );
  }
}

/// Publishes whether the slot a subtree sits in is the active one.
///
/// **Private, and it exists for one widget.** [LumenOrb] draws a bigger glow
/// when its slot is active (`:233` — `.dtab.on .orbmini{box-shadow:0 0 22px…}`)
/// and [LumenOrb]'s public API is fixed at a size and nothing else, so the
/// state has to travel down through the tree rather than through a parameter.
class _LumenSlotScope extends InheritedWidget {
  const _LumenSlotScope({required this.active, required super.child});

  /// Whether this slot is the active one.
  final bool active;

  /// Whether the calling subtree is inside the active slot.
  ///
  /// **False when there is no scope at all**, which is the case for an orb
  /// standing on its own: an inactive orb is the right answer for a widget
  /// that is not in a dock, and it is the same answer the prototype gives a
  /// `.orbmini` that is not inside a `.dtab.on`.
  static bool maybeActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LumenSlotScope>()?.active ??
      false;

  @override
  bool updateShouldNotify(_LumenSlotScope oldWidget) =>
      oldWidget.active != active;
}

/// The "today" orb — the redesign's mini sun.
///
/// `eva/redesign.html:228-234` is the prototype's `.orbmini`, and `:705` is
/// the markup that puts it in the dock's third slot.
///
/// ## THE STAR IS PAINTED, NOT TYPED
///
/// The prototype writes the mark as a character — `<span class="orbmini"
/// id="orbEl">✦</span>` (`:705`) — and a browser draws it because a browser
/// has the whole system font library. **This client does not:** U+2726 is in
/// no bundled family (measured over all nineteen `.ttf`s by
/// `test/support/font_coverage.dart`), so the character would be a tofu box.
/// The shape is drawn by [FourPointedStar] instead, which is the same decision
/// `selah_card.dart` and `/reading`'s bookmark button already made.
///
/// ## THE RIPPLE HAS NO CONTROLLER OF ITS OWN
///
/// `.orbmini::after` is `animation:ripple 2.6s var(--e-out) infinite`
/// (`:230`) — the dock's one **infinite** animation, and therefore the one
/// that must not start a ticker of its own: §13.2's mitigation is that the
/// app owns a fixed number of clocks, and a widget that starts its own is a
/// new one. So the orb reads the app's shared LUMEN clock, exactly as
/// `GoldFlecks` reads the shared float clock, and takes its 2.6s phase from
/// it.
///
/// **The shared clock is monotonic**, which is what makes the phase
/// continuous: `seconds % 2.6` is the CSS animation's own progress, restarting
/// at the same 2.6s boundary the prototype's restarts at.
///
/// ## AND IT RIDES THE **BUDGET**, NOT THE RAW CLOCK
///
/// The clock the orb reads is the shared LUMEN clock, and the clock's **own
/// notification** is the thing that must not be the painter's repaint signal:
/// `TickedLumenClock._onTick` calls `notifyListeners()` on **every vsync**
/// (`lumen_clock.dart:302-305`). The painter therefore rides the app's
/// **gated** notifier — `motion.repaint` (`neural_motion.dart:232`), which
/// fires at most once every `notifyEveryNTick` frames — exactly as the gold
/// flecks and the witness sky's stars do. The ripple's own `RepaintBoundary`
/// keeps that repaint off the dock's σ22 blur layer.
///
/// The two are the same trade, made once here and once for the sky and the
/// flecks: ADR-0025, `docs/PERFORMANCE.md` §3.2, and §5.1 for the ripple
/// itself. **The shape, the colour, the period and the radius are the
/// prototype's and are unchanged** — the phase is still read from the clock
/// at paint time, and the clock still ticks at the display's rate. What
/// changes is **how often the ring is redrawn**: 60 times a second becomes 20.
///
/// ## THE TWO SUBSTITUTIONS, AND WHY
///
/// * **The inner highlight is [EvaColors.emberSheen]** — white at 28%, and
///   the **same value in both palettes** (the design system publishes it that
///   way deliberately). The prototype's centre stop is `#fff6` — white at
///   **40%** — in dark (`:229`) and **opaque** `#fff` in light (`:87`). So the
///   shipped highlight is weaker in dark and much weaker in light, and the
///   reason it is not stronger is that **no token is white in both
///   palettes**: [EvaColors.surface] is white in light and near-black in
///   dark, [EvaColors.ink] is the other way round, and [EvaColors.seam] is
///   white in dark and *gold* in light. [EvaColors.emberSheen] is the design
///   system's own "inner highlight on a gold fill" and the only one that
///   works on both.
///
/// * **The star's ink is [EvaColors.onEmber]** — the prototype's `#1c1608`
///   (`:228`), a near-black brown on the gold. `onEmber` is dark in **both**
///   palettes and is the token whose job is exactly this: legible ink on top
///   of the accent.
class LumenOrb extends StatelessWidget {
  /// Creates the orb.
  const LumenOrb({this.size = LumenOrb.diameter, super.key});

  /// The prototype's orb — `eva/redesign.html:228`, `width:30px;height:30px`.
  static const double diameter = 30;

  /// The orb's diameter.
  final double size;

  /// The gradient's radius, as a fraction of the orb's shortest side.
  ///
  /// **CSS's `farthest-corner`, computed.** `eva/redesign.html:229` writes
  /// `radial-gradient(circle at 35% 30%, …)` with no ending-shape size, which
  /// CSS resolves to the farthest corner from the gradient's centre. The orb
  /// is a square, so the radius is the distance from `(0.35s, 0.30s)` to
  /// `(s, s)`: `√((1−0.35)² + (1−0.30)²) = √0.9125 ≈ 0.95525`, and the
  /// fraction is the same at every size.
  static const double gradientRadius = 0.95525;

  /// The star's size — `eva/redesign.html:228`, `.orbmini{… font-size:12px}`.
  ///
  /// The mark is a character in the prototype, so its box is its font size.
  static const double starSize = 12;

  /// The ripple's period, in seconds — `eva/redesign.html:230`,
  /// `animation:ripple 2.6s var(--e-out) infinite`.
  ///
  /// **Derived from the motion token and not written out**, so the number the
  /// prototype states and the number the widget spends cannot drift apart.
  static final double ripplePeriodSeconds =
      EvaMotion.dockRipple.inMilliseconds / 1000.0;

  /// The ripple's phase, `0..1`, at [seconds] of elapsed time.
  ///
  /// **The modulo is the CSS animation's own restart.** The prototype's
  /// keyframes run `0%{transform:scale(1);opacity:.8}` to
  /// `100%{transform:scale(1.6);opacity:0}` (`:234`) and then begin again, so
  /// the phase wrapping is the design and not an artefact of the arithmetic.
  static double ripplePhase(double seconds) =>
      (seconds % ripplePeriodSeconds) / ripplePeriodSeconds;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool active = _LumenSlotScope.maybeActive(context);
    // §14 — the ripple is a motion, so it reads the flag. A reader who has
    // asked for reduced motion gets the ring at rest, which is what the
    // prototype's own `.screen.rm` does (`:50` — `animation:none!important`).
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final EvaNeuralMotion motion = NeuralMotionScope.of(context);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // `radial-gradient(circle at 35% 30%,#fff6,var(--gold) 50%,#a97a1e
              // 90%)` — `:229`. The centre is `Alignment(-0.3, -0.4)`, which is
              // 35% and 30% of the box.
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: gradientRadius,
                colors: <Color>[
                  colors.emberSheen,
                  colors.ember,
                  colors.emberDeep,
                ],
                stops: const <double>[0, 0.5, 0.9],
              ),
              boxShadow: <BoxShadow>[
                // `box-shadow:0 0 14px rgba(232,176,75,.55)` — `:229` — and
                // `:233`'s `0 0 22px rgba(232,176,75,.8)` when the slot is
                // active.
                BoxShadow(
                  color: colors.ember.withValues(alpha: active ? 0.8 : 0.55),
                  blurRadius: active ? 22 : 14,
                ),
              ],
            ),
            child: Center(
              child: FourPointedStar(size: starSize, color: colors.onEmber),
            ),
          ),
          // ## THE RIPPLE
          //
          // `.orbmini::after{content:"";position:absolute;inset:0;
          // border-radius:50%;border:1.2px solid rgba(232,176,75,.6);
          // animation:ripple 2.6s var(--e-out) infinite}` — `:230`.
          Positioned.fill(
            child: IgnorePointer(
              // `pointer-events:none` in the prototype's spirit: the ring is
              // decoration over a control, and it must not take a tap.
              child: RepaintBoundary(
                // ## THE RIPPLE'S OWN **BOUNDARY**
                //
                // The ring is the dock's only per-frame repaint, and the
                // dock's first child is a σ **22** `BackdropFilter`
                // (`:314`, sigma at `:274`) — a composited layer in the **same**
                // `Stack` (`:298`). Without a boundary between the ripple and
                // the root, the ring's repaint re-records the layer that owns
                // that blur, so a decorative ring costs the dock a σ22
                // re-rasterisation every time it moves.
                //
                // **There was exactly one `RepaintBoundary` in `lib/` before
                // this one** — the aurora's (`lumen_background.dart:219`) —
                // and it wraps the aurora, not the page above it, so nothing
                // contained the ripple's repaint. `docs/PERFORMANCE.md` §5.1
                // records the same fact: "there is **no** `RepaintBoundary`
                // between the ripple and the root".
                //
                // **A `RepaintBoundary` changes WHEN things repaint, not WHAT
                // they look like.** It does not clip — the ring still leaves
                // the orb's box, as `:234`'s `scale(1.6)` requires, because
                // both `Stack`s declare `clipBehavior: Clip.none` and this
                // boundary is an `OffsetLayer` rather than a `ClipRectLayer`.
                child: CustomPaint(
                  painter: _OrbRipplePainter(
                    motion: motion,
                    color: colors.ember.withValues(alpha: 0.6),
                    animate: animate,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the orb's ripple ring.
///
/// ## THE SIGNAL IS THE **BUDGETED** ONE
///
/// The painter's `repaint` listenable is `motion.repaint` — the **gated**
/// notifier (`neural_motion.dart:232`), which fires at most once every
/// `notifyEveryNTick` frames (`ambient_tick_budget.dart:78` — **20 Hz** at
/// 60 Hz) — and **not** the raw LUMEN clock.
///
/// **The raw clock notifies on every vsync.** `TickedLumenClock._onTick` calls
/// `notifyListeners()` on every tick (`lumen_clock.dart:302-305`), so a
/// painter holding it as its `repaint` signal is repainted **once per frame**:
/// measured at **30 repaint requests in 30 frames** against a budget of **15**
/// (`docs/PERFORMANCE.md` §5.1, and the gate in `test/painter_repaint_test.dart`).
///
/// The gated notifier is the one the **gold flecks** (`gold_flecks.dart:183`)
/// and the **witness sky's stars** (`witness_sky.dart:898-917`) already ride,
/// and it is the same trade ADR-0025 and `docs/PERFORMANCE.md` §3.2 made for
/// them: "the witness sky's forty-four stars rebuild **three times less
/// often**". The ripple is the same class of thing — seconds-long decorative
/// ambient motion — and it was the one that missed the budget.
///
/// ## WHAT THIS CHANGES AND WHAT IT DOES NOT
///
/// **The sampling rate, and only the sampling rate.** The shape, the colour,
/// the period and the radius are the prototype's and are untouched: the
/// painter still reads the phase from the clock **at paint time**, and the
/// clock still ticks at the display's rate, so the ring's picture at any
/// instant is the picture the per-frame painter would have drawn at that
/// instant. **The reader sees the same ring, sampled three times less often**
/// — which is the smoothness cost, and it is the cost the sky and the flecks
/// already pay.
class _OrbRipplePainter extends CustomPainter {
  _OrbRipplePainter({
    required this.motion,
    required this.color,
    required this.animate,
  }) : super(repaint: motion.repaint);

  /// The shared motion bundle, read at paint time.
  ///
  /// **The painter reads it rather than being handed a snapshot**, because a
  /// snapshot taken in `build` is only as fresh as the last rebuild — and
  /// nothing rebuilds this widget per frame. `GoldFlecks`' painter is the
  /// precedent, and it is also where the **gated** notifier comes from:
  /// `super(repaint: motion.repaint)` (`gold_flecks.dart:183`).
  final EvaNeuralMotion motion;

  /// The ring's ink — `rgba(232,176,75,.6)`, `:230`.
  final Color color;

  /// Whether the ripple runs. `false` under reduced motion.
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    // **The clock's own elapsed seconds**, read at paint time.
    //
    // `motion.lumen` is the shared `TickedLumenClock`
    // (`neural_motion.dart:205`), and its `seconds` is the monotonic reading
    // (`lumen_clock.dart:284-289`) — the one the aurora reads too. It is read
    // here and not snapshotted in `build`, so the ring's phase is always the
    // phase at the moment it is painted, whatever rate that turns out to be.
    final double phase = animate
        ? LumenOrb.ripplePhase(motion.lumen.seconds)
        : 0.0;
    // `--e-out` — `:18`'s `cubic-bezier(0,0,.2,1)`, transcribed in
    // [EvaMotion.dockRippleCurve].
    final double eased = EvaMotion.dockRippleCurve.transform(phase);
    // `@keyframes ripple{0%{transform:scale(1);opacity:.8}
    // 100%{transform:scale(1.6);opacity:0}}` — `:234`.
    final double scale = 1 + 0.6 * eased;
    final double opacity = 0.8 * (1 - eased);
    canvas.drawCircle(
      size.center(Offset.zero),
      (size.shortestSide / 2) * scale,
      Paint()
        ..style = PaintingStyle.stroke
        // `border:1.2px solid rgba(232,176,75,.6)` — `:230`.
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: color.a * opacity),
    );
  }

  @override
  bool shouldRepaint(_OrbRipplePainter oldDelegate) =>
      oldDelegate.animate != animate || oldDelegate.color != color;
}
