import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/material.dart';

/// One settings row: a title on the left, a control on the right.
///
/// `redesign.html:419-421`'s `.srow`, wrapped around every row on the Settings
/// screen (`SettingsScreen.tsx:50,63,76,92,101,106,115,118`).
///
/// ## THIS ROW IS **FLAT**, AND THAT IS THE REDESIGN, NOT A REGRESSION
///
/// `.srow` is `background:none`, `border-radius:0`, `border-left:none`,
/// `border-right:none`, `border-top:none`, a single `border-bottom` hairline,
/// `padding:15px 4px` and `font-size:14.5px`. Every one of those is a
/// **deletion**, and Phase 4.2 is where they are applied: this widget used to
/// wrap its content in `GlassSurface(tint)` — a translucent fill, a full 1px
/// rim at 14px radius and the glass ambient shadow — so 28 rows on `/settings`
/// were 28 rounded panels.
///
/// The panel is gone and the reason is worth stating in the file, because
/// "the settings list lost its cards" reads like damage and is not:
/// **R3 is one of five roles the redesign defines as flat.** The same table
/// makes R4 (the metric cell), R9 (the list row), R11 (the dock item) and R17
/// (the progress dots) hairline-only. `.srow` is where that decision becomes
/// visible — a column of twenty-eight rows separated by 1px rules is the
/// redesign's own composition, and a column of twenty-eight glass panels was
/// never it.
///
/// **The blur-budget question evaporates rather than being answered.**
/// `ds.tsx:487` gave this widget `backdropFilter: blur(12px)` and §13.4's
/// per-screen table put `/settings` under "everything else → `tint`", so the
/// wrapper never blurred. With no wrapper there is no fill to budget at all,
/// and the "is this one of the eight?" question the enum existed to make
/// visible has no object here any more.
///
/// ## THE HOVER IS TRANSCRIBED, INCLUDING THE PART THAT LOOKS LIKE A BUG
///
/// `redesign.html:420` — `.srow:hover{color:var(--gold);transform:translateX(4px)}`.
/// Both halves, and the second one moves **the hairline too**, because in CSS
/// the border belongs to the element being transformed. On a 28-row screen the
/// rule slides right by 4px and leaves a 4px notch at its left end for as long
/// as the pointer is over it. That is what the prototype does; it is recorded
/// here rather than "corrected", because a correction would be a second design
/// decision made by a widget with no prototype line behind it.
class SettingsTile extends StatefulWidget {
  /// A row titled [title] with [trailing] on the right.
  const SettingsTile({
    required this.title,
    required this.trailing,
    this.onTap,
    super.key,
  });

  /// The row's label. `redesign.html:419` — `font-size:14.5px`, and no
  /// `font-weight`, so the weight is the UI face's own.
  final String title;

  /// The control. A [Widget] and not a callback, so the control brings its own
  /// semantics, its own focus node and its own §14 ring — a settings row must
  /// not own the focus of the switch inside it, or Tab lands on the row and then
  /// again on the control.
  final Widget trailing;

  /// What to run when the row itself is tapped. `null` — the common case, and
  /// the one every prototype row uses — makes the row inert and lets the
  /// trailing control take focus on its own.
  final VoidCallback? onTap;

  /// **`ds.tsx:488`'s `borderRadius: 14`, which this row no longer uses.**
  ///
  /// Kept because one other widget on `/settings` — the failure notice in
  /// `settings_page.dart` — borrows it for a `GlassSurface` that is a real
  /// glass panel and should keep its corners, and kept at `14` so that
  /// borrowing keeps working. The row itself is [BorderRadius.zero]: R3 is flat,
  /// and a focus ring and an ink response rounded to 14 around a row with no
  /// fill and no rim would draw corners the row does not have.
  static const double radius = EvaRadii.button;

  /// The row's total height floor. `ds.tsx:488` — `height: 56`.
  ///
  /// **Kept, though `redesign.html:419` has no height at all**, and the
  /// divergence is deliberate rather than an oversight: `.srow` is
  /// `padding:15px 4px` around content and nothing else, so the prototype's row
  /// is exactly `content + 30`. Dropping the floor would make this constant
  /// meaningless — and `primitives_text_scale_test.dart`, which this batch does
  /// not own, reads it as the §14 ceiling for the row at 1.22× text scale. A
  /// number two harnesses read is not this batch's to delete; the 56 is
  /// `ds.tsx`'s and it is re-composed against the new padding as
  /// [contentFloor], so a short row is **56 + 1** — the 1 being the hairline.
  static const double minHeight = 56;

  /// The row's vertical padding. `redesign.html:419` — `padding: 15px 4px`.
  ///
  /// Named beside [padding] and not inline in it because [contentFloor] is
  /// `const` and reads it, and `EdgeInsets.vertical` is a property access that
  /// cannot be evaluated in a constant expression — so folding the 15 into the
  /// subtraction would mean writing `26` in two places and hoping.
  static const double verticalPadding = 15;

  /// The horizontal padding. `redesign.html:419` — `padding: 15px 4px`.
  static const double horizontalPadding = EvaSpacing.xs;

  /// `redesign.html:419` — `padding: 15px 4px`, replacing `ds.tsx:488`'s
  /// `'0 16px'`.
  ///
  /// Neither number is on the 4px scale — 15 is not a token at all — so the
  /// prototype's pair is transcribed literally, as [StatTile]'s `14px 10px` is.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: horizontalPadding,
    vertical: verticalPadding,
  );

  /// [minHeight] less **both** vertical paddings, so the row's **content** is at
  /// least 56 − 30. See [minHeight] for why the floor is still here at all.
  ///
  /// `2 *`, not `verticalPadding`: the first version of this constant subtracted
  /// one of them and produced a row **one whole padding** too tall, which no
  /// test caught, because the floor was only ever asserted as a constant and
  /// never against a measured height. `surfaces_test.dart` now measures the row
  /// as well as asserting the constant, which is what makes the arithmetic
  /// load-bearing.
  ///
  /// **The rendered total is 57, not 56, and the extra pixel is the hairline.**
  /// `BoxDecoration.padding` is the border's dimensions, so `RenderDecoratedBox`
  /// lays its child out inside the 1px bottom edge and the row is
  /// `max(content, 26) + 30 + 1`. A border that took no space would be painted
  /// outside the box and clipped.
  static const double contentFloor = minHeight - 2 * verticalPadding;

  /// The row's title size. `redesign.html:419` — `font-size:14.5px`.
  ///
  /// Not a Material slot: `bodyLarge` is 16 and `bodyMedium` is 14, and the
  /// prototype's number is 14.5. §5.2's rule that sizes come from Material 3
  /// yields to a transcription that names its own number — the same exception
  /// [StatTile]'s `radius: 16` and [SettingsTile]'s `padding` already make.
  static const double titleSize = 14.5;

  /// The hairline. `redesign.html:419` — `border-bottom:1px solid
  /// rgba(255,255,255,.06)`.
  ///
  /// [EvaColors.ink] at `.06`, which in dark is `#EAE8F5` at 6% against the
  /// prototype's `#FFFFFF` at 6%, and in light is `#120E28` at 6%. The light
  /// half is a **choice**: `.srow` has no light-mode override anywhere in
  /// `redesign.html`, so a literal reading leaves the rule white-on-cream and
  /// invisible. The nearest prototype statement about a settings row's hairline
  /// in light is `:68` — `.sact{border-bottom-color:rgba(20,22,30,.08)}` — and it
  /// re-points it at ink. `.06` rather than `.08` because `.sact` is a different
  /// rule (`:439`, 15px type, a settings *action* row) and borrowing its alpha
  /// across to `.srow` would be borrowing the whole declaration.
  static const double hairlineAlpha = 0.06;

  /// The row's **rendered** height floor — [minHeight] plus the hairline, in
  /// logical px. **57.**
  ///
  /// ## WHY THIS EXISTS AT ALL, AND WHY IT IS NOT THE OLD GATE'S NUMBER
  ///
  /// `primitives_text_scale_test.dart` asserts this row's rendered height against
  /// a published floor, because a row that cannot grow is where a type-scale change
  /// has to be caught. Phase 4.2 changed the row's composition — `padding:15px 4px`
  /// around content, per `redesign.html:419`, where it used to be a panel around
  /// `minHeight - 16` — and with it the rendered floor moved from **56 to 57**.
  /// The gate was pointed at [minHeight] and went red with `57.0 > 56.0`, which is
  /// the gate working: it measures, so a number that stops being true turns it red
  /// rather than letting a row grow unnoticed.
  ///
  /// It could not be answered by relaxing the assertion, because the claim is
  /// "1.22× text does not push the row past its floor" and the floor had moved.
  /// So the floor is **named here**, where the composition that produced it lives,
  /// and the gate reads it.
  ///
  /// ## THE `+ 1`, AND WHY IT IS NOT A NAMED CONSTANT
  ///
  /// It is the hairline. `BoxDecoration.padding` is the border's dimensions, so
  /// `RenderDecoratedBox` lays its child out **inside** the edge — a border that
  /// took no space would be painted outside the box and clipped — and a row with
  /// the `border-bottom` below is one pixel taller than the same row without it.
  ///
  /// There is deliberately no `hairlineWidth` constant beside this one. The width
  /// is `BorderSide`'s **default** (`redesign.html:419`'s `1px` is that default),
  /// so naming it would mean either passing a redundant argument — which
  /// `avoid_redundant_argument_values` refuses, and `CONTRIBUTING.md` §review
  /// forbids answering with a `// ignore:` — or publishing a constant with no
  /// reader but this line, which is the token-table bloat `seamGlow`'s doc
  /// declines. So the pixel is written here, once, and `primitives_text_scale_
  /// test.dart`'s `renderedFloor - minHeight == 1` assertion is what keeps it
  /// tied to the border rather than drifting into a magic number.
  ///
  /// **57 is not a rounding.** `.srow`'s own row in the prototype is
  /// `content + 30` with no floor at all; the 56 is `ds.tsx:488`'s, kept because
  /// two harnesses read it, and the extra pixel is the rule the redesign adds on
  /// top. See [minHeight] for why the 56 could not simply be deleted.
  static const double renderedFloor = minHeight + 1;

  /// The hover slide. `redesign.html:420` — `transform:translateX(4px)`.
  static const double hoverShift = 4;

  /// The hover duration. `redesign.html:419` — `transition:.2s`, which is
  /// [EvaMotion.base] exactly, so no rounding was needed.
  static const Duration hoverDuration = EvaMotion.base;

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  /// Whether the pointer is over the row — `redesign.html:420`'s `:hover`.
  ///
  /// A per-widget flag rather than a shared one, for [EvaButton]'s reason: a
  /// global "something is hovered" is a second source of truth that a screen
  /// with three rows has to keep honest.
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool interactive = widget.onTap != null;
    // §14: the hover's two animations both collapse to the end state on the
    // frame the pointer arrives, rather than being a second decision about
    // which of them still runs.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    final Widget row = AnimatedContainer(
      // `.srow{transition:.2s}` (`:419`) covers both the colour and the
      // transform, so both are 200ms.
      duration: animate ? SettingsTile.hoverDuration : Duration.zero,
      curve: EvaMotion.baseCurve,
      transform: Matrix4.translationValues(
        SettingsTile.hoverShift * (_hovered ? 1 : 0),
        0,
        0,
      ),
      // The bottom hairline and **nothing else** — no fill, no rim, no radius.
      // See the class doc for why the loss of the panel is the redesign.
      decoration: BoxDecoration(
        border: Border(
          // **No `width:`** — `BorderSide`'s default **is** `redesign.html:419`'s
          // `1px`, so passing it would be an argument the lints call redundant,
          // and `CONTRIBUTING.md` forbids answering that with a `// ignore:`. The
          // number is not lost: [renderedFloor] adds it to the row's height,
          // because `BoxDecoration.padding` is the border's dimensions.
          bottom: BorderSide(
            color: colors.ink.withValues(alpha: SettingsTile.hairlineAlpha),
          ),
        ),
      ),
      child: Padding(
        padding: SettingsTile.padding,
        child: ConstrainedBox(
          // `contentFloor` so the **total** is the prototype's 56 rather than 56 + 30.
          // See [SettingsTile.minHeight].
          constraints: const BoxConstraints(
            minHeight: SettingsTile.contentFloor,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                // ## `excludeSemantics` ON THE **TITLE**, AND IT IS NOT THE ROW'S
                // `excludeSemantics: false` BEING REVERSED
                //
                // The row's own `Semantics` keeps `excludeSemantics: false` on purpose
                // — the comment at the return below says why, and the reasoning stands:
                // a tappable row *contains* a control, and dropping the subtree would
                // leave a screen reader with a button that does nothing. What was wrong
                // is that **this** `Text` then contributed [SettingsTile.title] a second
                // time. Measured on `/settings`'s language row:
                //
                // ```text
                // lbl="Default language|Default language|English"  tap=true  btn=true
                // ```
                //
                // A name said twice, and — worse — the row was the **only** node carrying
                // the reader's current language, so the duplicate was not merely untidy,
                // it was three announced words where one was needed.
                //
                // Excluding **only this `Text`** is the smallest fix that keeps both
                // halves: the title's glyphs are still painted and still readable, and
                // `trailing`'s own node — a nested control, or the current-value text —
                // survives to be announced alongside the row's name.
                child: ExcludeSemantics(
                  child: AnimatedDefaultTextStyle(
                    // ## `animate ? hoverDuration : Duration.zero`, AND THE ORDER IS
                    // THE WHOLE ARGUMENT
                    //
                    // This read `animate ? Duration.zero : SettingsTile.hoverDuration`,
                    // which is **inverted**, and every other animation in this
                    // repository has always had it the other way round:
                    // [SettingsTile]'s own `AnimatedContainer` twenty lines above,
                    // `eva_button.dart`'s press, `segmented_control.dart`'s thumb.
                    //
                    // Measured before the fix: **0 ms with animations on** — so
                    // `redesign.html:419`'s `transition:.2s` was lost on the one
                    // thing in the row that changes *colour* — and **200 ms under
                    // reduced motion**, which is §14 inverted:
                    // `09-quality-gates.md:184` requires a disabled animation to
                    // "jump straight to the end state", and 200 ms of transition is
                    // the exact opposite.
                    //
                    // The colour does have to transition (`:419`), and the style
                    // lives here rather than on the `Text` so that it can.
                    duration: animate
                        ? SettingsTile.hoverDuration
                        : Duration.zero,
                    curve: EvaMotion.baseCurve,
                    // `arabicAware` here for the same reason as
                    // [EvaSectionHeader]: the row's title is painted by this
                    // widget, so this widget decides the family. Under LTR it is
                    // the identity function, so every existing Latin assertion is
                    // untouched.
                    //
                    // The style lives on the `AnimatedDefaultTextStyle` and the
                    // `Text` below inherits it. Setting both is a bug that looks
                    // like redundancy: an explicit `Text.style` wins over the
                    // ambient default, so the hover colour would snap instead of
                    // transitioning and the animation would be painting nothing.
                    style: arabicAware(
                      Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: SettingsTile.titleSize,
                        color: _hovered ? colors.emberInk : colors.ink,
                      ),
                      Directionality.of(context),
                    ),
                    child: Text(widget.title),
                  ),
                ),
              ),
              const SizedBox(width: EvaSpacing.md),
              widget.trailing,
            ],
          ),
        ),
      ),
    );

    if (!interactive) {
      return _wrapHover(row);
    }

    return _wrapHover(
      Semantics(
        button: true,
        label: widget.title,
        // `excludeSemantics: false` on purpose, unlike every other interactive
        // widget here: a tappable settings row *contains* a control, and dropping
        // the subtree would leave a screen reader with a button that does nothing
        // when activated.
        child: EvaFocusRing(
          // ## `radius: 0`, AND THE ARGUMENT IS THE FIX — NOT THE INK's
          //
          // `EvaInk` below is told `BorderRadius.zero` and this was not, so the
          // ring drew its **default**, `EvaFocusRing`'s `EvaRadii.button` = 14,
          // around a row that has no corners. The class doc says exactly this:
          // "a focus ring and an ink response rounded to 14 around a row with no
          // fill and no rim would draw corners the row does not have" — and the
          // code fixed the ink and not the ring, which is the more visible of the
          // two: the ring is the thing that appears on keyboard focus, so the
          // defect was on screen exactly when §14 is looking.
          //
          // **`radius: 0`, not `BorderRadius.zero`.** `EvaFocusRing`'s parameter
          // is a `double` radius, so the same value is spelled the same way as
          // `EvaInk`'s sibling argument rather than in a different type.
          radius: 0,
          child: EvaInk(
            onPressed: widget.onTap,
            // `BorderRadius.zero`, not [SettingsTile.radius]: the ring and the
            // ink follow the row, and the row has no corners. See the constant's
            // doc for why `14` survives on the class at all.
            borderRadius: BorderRadius.zero,
            child: row,
          ),
        ),
      ),
    );
  }

  /// The hover region, and **only** the hover region.
  ///
  /// Split out so both return paths below get it and neither can forget: a
  /// `MouseRegion` that exists on the tappable path and not the inert one would
  /// make "hovering a row" mean two different things on the same screen.
  Widget _wrapHover(Widget child) => MouseRegion(
    onEnter: (PointerEnterEvent _) => _setHovered(true),
    onExit: (PointerExitEvent _) => _setHovered(false),
    child: child,
  );
}
