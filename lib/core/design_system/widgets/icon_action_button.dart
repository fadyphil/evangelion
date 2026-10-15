import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A square, borderless, icon-only button — **or**, with [pilled], the redesign's
/// 30px glass pill.
///
/// Four surviving call sites (`04-widget-inventory.md` §3) — ReadingEn's back,
/// ReadingAr's back, Quiz's close, Settings' back — plus the `Aa` and bookmark
/// controls Phase 7 composes.
///
/// ## THE REDESIGN SPLITS THIS WIDGET IN TWO, AND BOTH HALVES SHIP HERE
///
/// `redesign.html:149-155` publishes two different controls that the React
/// prototype drew as the same `<button>`:
///
/// ```css
/// .chev{color:var(--ink-1);font-size:16px;cursor:pointer;transition:transform .3s,color .2s;background:none;border:none;padding:4px 6px}  /* :149 */
/// .chev:hover{color:var(--ink-0)}                                                                                                       /* :150 */
/// .iconbtn{background:none;border:1px solid var(--glass-line);border-radius:99px;color:var(--ink-1);width:30px;height:30px;…}        /* :151 */
/// .iconbtn:hover{color:var(--gold);border-color:rgba(232,176,75,.5)}                                                                    /* :152 */
/// .iconbtn:active{transform:scale(.9)}                                                                                                  /* :153 */
/// .iconbtn.lit{color:var(--gold);border-color:rgba(232,176,75,.6);box-shadow:0 0 12px rgba(232,176,75,.35)}                          /* :154 */
/// .iconbtn svg{width:15px;height:15px;stroke:currentColor;…}                                                                          /* :155 */
/// ```
///
/// One is a **bare glyph with no box at all** — `.chev`, the appbar's back arrow —
/// and the other is a **30px glass pill with a 1px rim**, `.iconbtn`, the appbar's
/// utility cluster (bookmark `:544`, communion `:581`, settings `:582`, veil
/// `:616`). They differ in three visible ways and agree on none of them: fill, rim,
/// and glyph ink on hover. So [pilled] is a parameter and the **default is
/// `.chev`**.
///
/// **Why the default is `.chev` and not the pill.** All four surviving call sites are
/// `.chev` in the redesigned reference — reading `:542`, quiz `:564`, settings
/// `:640`, communion `:614` — and the pill's hosts are the `/` and `/journey`
/// appbars, which are Phase 5.2 and 5.6 screens. Defaulting to the pill would restyle
/// four delivered screens to a role they do not have yet, and the icon buttons are
/// the one control a harness measures (`quiz_geometry_test.dart:146`,
/// `reading_geometry_test.dart:955`), so the mistake would be a silent geometry
/// change wearing a paint change's clothes.
///
/// ## THE BOX IS 44 AND THE PILL IS 30, AND NEITHER NUMBER IS NEGOTIABLE
///
/// 44 is `iOSTapTargetGuideline`'s minimum *and* the React prototype's
/// (`SettingsScreen.tsx:39`, `ReadingEnScreen.tsx:14`, `QuizScreen.tsx:46`), and it
/// is asserted rendered by two harnesses. So the pill is a **30px silhouette inside
/// the existing 44px box** and not a smaller button: `Center` does the inset, the
/// hit area is untouched, and `quiz_geometry_test.dart`'s `44 ±0.5` keeps meaning
/// what it meant. The redesign's own `.chev` (`:149`, `padding: 4px 6px` on a 16px
/// glyph) is the same shape — a small target inside a comfortable one — so this is
/// faithful rather than a compromise.
///
/// ## NO `Stack`. THE `StackFit` TRAP, AND WHY IT WAS AVOIDED BY CONSTRUCTION
///
/// `glass_surface.dart` records what a `Stack` with the default
/// `StackFit.loose` does: it loosens the constraints the content was receiving,
/// shrink-wrapped `StatTile`'s three cells to the width of their own captions, and
/// moved a golden by 1.20%. The rim here needs no stack at all — a 30px circle is
/// one `DecoratedBox`, and its rim and glow are two fields of the same
/// `BoxDecoration` — so the trap is not avoided correctly, it is **not reachable**.
/// `Center` is the only wrapper between the [SizedBox] and the paint, and it hands
/// its child loose constraints, which is exactly what a circle wants.
///
/// ## THE ACCESSIBLE NAME IS NOT OPTIONAL, AND IS NOT A SECOND PARAMETER
///
/// §14's first row: "Icon-only buttons (back, close, bookmark, `Aa`) have no
/// accessible name". [tooltip] is **required** and feeds *both* the [Tooltip] and
/// `Semantics(label:)`, rather than being two parameters that can disagree. A
/// button whose tooltip says "Close" and whose semantics say "Dismiss" is worse
/// than an unnamed one in at least one of the two surfaces a reader uses.
///
/// [lit] deliberately adds no semantics of its own, and that is the point: in the
/// redesign it is a two-state toggle's **ON** state — `bmBtn` toggles it
/// (`redesign.html:1394`) and `veilBtn` mirrors the veil setting into it
/// (`:1493`) — so the state a reader needs is "pressed or not", which the control's
/// own pressed state and its name already carry. A second flag announced here would
/// be a state the widget cannot see.
///
/// The prototype's buttons are all bare `<button>`s with an inline `<svg>` and no
/// label at all (`SettingsScreen.tsx:39-41`, `ReadingEnScreen.tsx:14-16`,
/// `QuizScreen.tsx:46-50`), so every string here is one the shipped screens have
/// to supply. There is no sensible default and none is invented.
class IconActionButton extends StatefulWidget {
  /// A button showing [icon], named [tooltip].
  const IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.tooltipFamily,
    this.onPressed,
    this.size = 44,
    this.iconSize,
    this.pilled = false,
    this.lit = false,
    super.key,
  }) : assert(
         !lit || pilled,
         '`lit` is `.iconbtn.lit` (redesign.html:154) and there is no '
         '`.chev.lit` — the lit state is a property of the pill. Pass '
         '`pilled: true` as well, or drop `lit`.',
       );

  /// The glyph. Material's [IconData] — `Icons.arrow_back`, `Icons.close`, and so
  /// on. A caller supplies it because the icon *is* the call site's meaning and
  /// four different sites need four different arrows; a design-system widget
  /// that chose the glyph would be choosing the navigation model.
  final IconData icon;

  /// The accessible name, and the [Tooltip]'s text.
  final String tooltip;

  /// The family the **tooltip's visible text** renders in.
  ///
  /// ## WHY THIS PARAMETER EXISTS AT ALL, AND IT IS THE SAME FINDING AS
  /// ## `EvaButton.labelFamily`'S — ONE PHASE, TWO SITES
  ///
  /// The prototype's four buttons are bare `<button>`s with an inline `<svg>` and
  /// **no label of any kind** (`SettingsScreen.tsx:39-41`,
  /// `ReadingEnScreen.tsx:14-16`, `QuizScreen.tsx:46-50`), so §14's requirement for
  /// an accessible name on an icon-only control forced three Arabic strings into
  /// this widget that the prototype never wrote. `reading_controls.dart` supplies
  /// all three, and they render where a reader can see them.
  ///
  /// **`Tooltip(message: tooltip)` with no `textStyle`**, which is what this was,
  /// makes Flutter resolve `null` to `ThemeData.textTheme.bodyMedium` — measured
  /// **DMSans** on **both** themes, which carries no Arabic glyph at all. Measured
  /// on the real shipped `ReadingPage` at `Locale('ar')` with the long press held
  /// open: `TOOLTIP "رجوع"` (4 tofu), `"حجم الخط"` (7), and
  /// `"إشارة مرجعية — غير متاح في هذه النسخة"` (**19** codepoints).
  ///
  /// **And the phase's own glyph gate could not see any of it**, for two independent
  /// reasons that both had to be fixed: `renderedRuns()` walked the already-painted
  /// tree and a `Tooltip` paints nothing until a gesture (the probe found **zero**
  /// tooltip `Text` widgets), and `_isArabic` sampled four codepoints that
  /// `رجوع` contains none of. So the prototype's nine Arabic sites were the **floor**,
  /// not the ceiling — `reading_glyph_test.dart`'s table is **nine** rows of which
  /// **eight** were tofu, and three of those eight are these.
  ///
  /// ## WHY IT IS **REQUIRED**, AND NOT NULLABLE
  ///
  /// Because it does not affect the button at all — it affects a `Text` the design
  /// system builds, and a caller that omits it gets `bodyMedium` **silently**. The
  /// compiler asking is the entire value, the same argument as `EvaButton`'s, and
  /// `reading_glyph_test.dart`'s painted-tooltip enumeration is what proves the
  /// answer reached the engine rather than merely being passed.
  ///
  /// **Rejected: resolving it from the locale inside this widget.** `EvaButton`'s doc
  /// rejects it for the shared reason — a Tier-1 primitive branching on
  /// `Localizations.localeOf` puts `/login`'s English label and an Arabic one on one
  /// invisible code path. §14's lesson from recorded decision 19 is that a
  /// locale-derived style has to be passed in and asserted at a call site.
  final String tooltipFamily;

  /// What to run on activation. `null` disables it — invisible to Tab, to the
  /// ink and to `Semantics(enabled:)`.
  final VoidCallback? onPressed;

  /// The tap target's edge length.
  ///
  /// 44 is `ds.tsx`'s literal (`SettingsScreen.tsx:39` — `width: 44, height:
  /// 44`; `ReadingEnScreen.tsx:14`; `QuizScreen.tsx:46`), and it is also
  /// `iOSTapTargetGuideline`'s minimum, so one number satisfies both the
  /// prototype and the platform guideline rather than the prototype being
  /// overridden to satisfy one and silently failing the other.
  final double size;

  /// The glyph's size. Defaults to [size] minus a quarter for a bare `.chev`
  /// — the React prototype's own proportion, 20px in a 44px box
  /// (`SettingsScreen.tsx:40`) and 18px for the heavier close
  /// (`QuizScreen.tsx:47`) — and to [pillIconSize] inside a [pilled] pill.
  final double? iconSize;

  /// Whether this is the redesign's `.iconbtn` pill rather than its `.chev` glyph.
  ///
  /// `false` — the default — paints no fill and no rim, which is `redesign.html:149`'s
  /// `background: none; border: none` and the React prototype's
  /// `SettingsScreen.tsx:39` with the same words.
  ///
  /// ## THE OLD COMMENT POINTED AT THE WRONG FILE, AND `redesign.html` FIXES IT
  ///
  /// The line this parameter replaced read "No rim. `ds.tsx:39` —
  /// `background: 'none', border: 'none'`". **`ds.tsx:39` is not a button.** It is
  /// the light row of `ds.tsx`'s palette table — `canvas: '#F0EEFF', surface:
  /// '#FFFFFF'` — and the claim is really `SettingsScreen.tsx:39`. It resolved, which
  /// is all `citation_check.py` asks for: AGENT_CONTEXT's recorded decision 8 says
  /// so outright, "a citation can resolve and still be about the wrong line", and
  /// this is that case, live, in a shipped widget. `redesign.html:149` is now the
  /// citation and it is the *design* source rather than a transcription of it, so the
  /// number has somewhere to come from when the React prototype is not there.
  final bool pilled;

  /// Whether the pill is in its **on** state.
  ///
  /// `redesign.html:154` — `.iconbtn.lit`: gold ink, a gold rim at 60%, and
  /// `0 0 12px rgba(232,176,75,.35)`. Not a highlight: the prototype toggles the
  /// class on `bmBtn` (`:1394`) and mirrors the veil setting onto `veilBtn`
  /// (`:1493`), so this is "this thing is on" and the caller's `onPressed` is where
  /// that fact lives. Requires [pilled], because `.chev` has no lit state — see the
  /// constructor's assert.
  final bool lit;

  /// The pill's diameter. `redesign.html:151` — `width: 30px, height: 30px`.
  static const double pillSize = 30;

  /// The pill's rim width. `redesign.html:151` — `border: 1px solid
  /// var(--glass-line)`, which is [EvaColors.glassBorder].
  ///
  /// Named here rather than passed to [Border.all] on the `rim` switch below,
  /// because that switch's three arms all take `Border.all`'s own default width
  /// of `1.0` — this constant *is* `1`, so writing it at those call sites would
  /// only restate the default. What keeps the number honest is
  /// `controls_test.dart`, which asserts this constant and not the rendered rim.
  static const double pillRimWidth = 1;

  /// The glyph inside a pill. `redesign.html:155` — `.iconbtn svg{width:15px;
  /// height:15px}`.
  static const double pillIconSize = 15;

  /// How far a pressed pill shrinks. `redesign.html:153` —
  /// `.iconbtn:active{transform: scale(.9)}`.
  static const double pressedScale = 0.9;

  /// The lit pill's glow. `redesign.html:154` — `box-shadow: 0 0 12px
  /// rgba(232,176,75,.35)`; the alpha is the other half of [litGlowAlpha].
  static const double litGlowBlur = 12;

  /// The lit pill's glow alpha. `redesign.html:154`.
  static const double litGlowAlpha = 0.35;

  /// The hover rim's alpha. `redesign.html:152` — `border-color:
  /// rgba(232,176,75,.5)`, and it is *not* the lit rim's 60% (`:154`), which is why
  /// the two are separate numbers and not one "gold rim".
  static const double hoverRimAlpha = 0.5;

  /// The lit rim's alpha. `redesign.html:154`.
  static const double litRimAlpha = 0.6;

  /// The hover transition's curve — `--e-spring`, `redesign.html:18`.
  ///
  /// The duration is [EvaMotion.base] rather than a constant here, because
  /// `redesign.html:151`'s `.2s` **is** that token's 200ms — the same reasoning
  /// [EvaToggle] uses for `.25s` and [EvaMotion.screen]. One number, one home.
  ///
  /// The same curve [EvaToggle.knobCurve] transcribes, reached from two files. It is
  /// spelled twice rather than put in `eva_motion.dart` for the reason that file's
  /// own doc gives for its two families: a third named curve belongs beside the
  /// widgets that quote the prototype's line for it, and the prototype is the source
  /// for both.
  static const Curve hoverCurve = Cubic(0.34, 1.56, 0.64, 1);

  @override
  State<IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<IconActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool enabled = widget.onPressed != null;
    // §14 — both animations on this control answer to the platform's reduced-motion
    // setting, the same rule `EvaButton`'s pressed fill follows.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    // `.iconbtn.lit` (:154) is declared **after** `.iconbtn:hover` (:152) and both
    // selectors carry one class plus one pseudo-class, so the later rule wins: a
    // hovered lit pill stays lit. Read off the cascade rather than decided by taste.
    final bool gold = widget.lit || (_hovered && widget.pilled);

    final Border? rim = switch ((widget.lit, _hovered && widget.pilled)) {
      (true, _) => Border.all(
        color: colors.ember.withValues(alpha: IconActionButton.litRimAlpha),
      ),
      (false, true) => Border.all(
        color: colors.ember.withValues(alpha: IconActionButton.hoverRimAlpha),
      ),
      // `redesign.html:151`'s idle rim is `var(--glass-line)`, which is
      // [EvaColors.glassBorder]. `null` is `.chev`'s `border: none` (`:149`) — not a
      // transparent border, because a transparent one still takes a layout decision
      // about its width and this widget's non-pill half has no rim at all.
      //
      // No `width:` on any of the three arms: [IconActionButton.pillRimWidth] is
      // `1`, which is `Border.all`'s own default, so writing it out would say
      // nothing the default does not already say.
      (false, false) =>
        widget.pilled ? Border.all(color: colors.glassBorder) : null,
    };

    final Icon icon = Icon(
      widget.icon,
      size:
          widget.iconSize ??
          (widget.pilled
              ? IconActionButton.pillIconSize
              : widget.size * 0.4545),
      // `redesign.html:151` — `color: var(--ink-1)` idle; `:152` and `:154` both
      // turn it gold on hover and when lit; and for a bare glyph `:150` turns it to
      // `--ink-0`. So the *hover* ink is a property of the role, and that is the
      // second visible difference between the two halves of this widget.
      //
      // Gold ink is `emberInk` rather than `ember`: an icon is writing, and
      // Decision 153's rule is that `ember` fills and `emberInk` writes — in light,
      // `ember` measures 2.05:1 on a pale row.
      color: switch ((enabled, gold, _hovered, widget.pilled)) {
        // Disabled wins over everything, as it did before: the enabled flag is in
        // the semantics and the ink is gone.
        (false, _, _, _) => colors.ink3,
        (_, true, _, _) => colors.emberInk,
        (_, _, true, false) => colors.ink,
        _ => colors.ink2,
      },
    );

    return MouseRegion(
      // `redesign.html:150` and `:152` are both hover rules, and the widget is a
      // `StatefulWidget` for exactly this and nothing else — there is no other
      // per-frame state in it, and the alternative was `EvaInk`'s `onHighlightChanged`
      // being read as a hover signal, which it is not (it is press).
      //
      // Cleared when the pointer leaves, never on disable, because a disabled control
      // cannot be hovered *or* dismissed by hover and `Tooltip` still wraps it.
      onEnter: (PointerEnterEvent _) => _setHovered(true),
      onExit: (PointerExitEvent _) => _setHovered(false),
      child: Tooltip(
        message: widget.tooltip,
        // The one line that reaches the engine. **`Tooltip` has no `textStyle`
        // default**, which is the whole defect: `null` resolves to the theme's
        // `bodyMedium`, and a design-system widget that renders a caller's string in a
        // family the caller never chose is a widget with a missing parameter.
        textStyle: TextStyle(fontFamily: widget.tooltipFamily),
        child: Semantics(
          button: true,
          enabled: enabled,
          // §14's first row, closed: the same string that names the tooltip.
          label: widget.tooltip,
          excludeSemantics: true,
          // Load-bearing, and easy to lose: `excludeSemantics: true` drops the
          // `InkWell`'s tap action along with the label, so without this the
          // button carries a name a screen reader can read and **no way to press
          // it** — a TalkBack double-tap is `ACTION_CLICK` =
          // [SemanticsAction.tap]. `null` when disabled, because the action must be
          // genuinely absent rather than present and flagged.
          onTap: enabled ? widget.onPressed : null,
          child: EvaFocusRing(
            enabled: enabled,
            // No rim in the ring's own slot. The pill's rim is 30px wide inside a
            // 44px box (see the class doc), so it cannot be an `idleBorder` here —
            // that paints on the *outer* box, which would draw a 44px rim and take
            // the hover and lit states with it. Two rims on one control is one too
            // many. Left at the parameter's `null` default for that reason.
            //
            // Square. A ring on a circle would need a different radius, and the ring
            // goes around the **tap target** in both roles — which is a square box —
            // not around the pill inside it. `EvaRadii.button` is the default too.
            child: EvaInk(
              onPressed: widget.onPressed,
              onHighlightChanged: _setPressed,
              // The ink has to be clipped to the box, or a splash escapes a 44px
              // button and paints over whatever is beside it.
              borderRadius: BorderRadius.circular(EvaRadii.button),
              child: AnimatedScale(
                // `redesign.html:153`. **Paint only, and the pill only**: `:153` is
                // `.iconbtn:active`, and `.chev` has no pressed transform — its
                // `transition: transform .3s` (:149) is the hover ink's, not a scale.
                // A `ScaleTransition`-free `AnimatedScale` at 1.0 is also the reason
                // the existing 44px goldens are byte-identical after this change:
                // `RenderTransform` scales paint, never layout, so
                // `quiz_geometry_test.dart`'s rendered 44 and
                // `reading_geometry_test.dart`'s `.dy` read the same numbers.
                scale: widget.pilled && _pressed
                    ? IconActionButton.pressedScale
                    : 1,
                duration: animate ? EvaMotion.base : Duration.zero,
                curve: IconActionButton.hoverCurve,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Center(
                    child: widget.pilled
                        ? AnimatedContainer(
                            duration: animate ? EvaMotion.base : Duration.zero,
                            curve: IconActionButton.hoverCurve,
                            width: IconActionButton.pillSize,
                            height: IconActionButton.pillSize,
                            decoration: BoxDecoration(
                              // `redesign.html:151` — `background: none`, so there
                              // is **no fill field at all** here: the pill is a rim
                              // and a glyph. Writing `color:` would be a second
                              // spelling of the same absence.
                              shape: BoxShape.circle,
                              border: rim,
                              // `redesign.html:154` — `box-shadow: 0 0 12px
                              // rgba(232,176,75,.35)`, on the lit pill only.
                              boxShadow: widget.lit
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: colors.ember.withValues(
                                          alpha: IconActionButton.litGlowAlpha,
                                        ),
                                        blurRadius:
                                            IconActionButton.litGlowBlur,
                                      ),
                                    ]
                                  : const <BoxShadow>[],
                            ),
                            child: icon,
                          )
                        : icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }
}
