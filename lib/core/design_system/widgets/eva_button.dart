import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Which of the three prototype buttons this is.
///
/// `eva/src/components/ds.tsx` declares `ButtonPrimary` (:222-250),
/// `ButtonSecondary` (:253-268) and `ButtonText` (:271-286) as three separate
/// components with three separate CSS blocks. `04-widget-inventory.md` §3
/// collapses them into one widget across seven surviving call sites, and this
/// enum is the collapse.
enum EvaButtonVariant {
  /// Filled `ember`, `onEmber` ink, and the two-part ember glow.
  primary,

  /// Transparent, with a 1.5px `ink`-at-20% rim.
  secondary,

  /// Bare `ink` text, no fill and no rim — the prototype's `ButtonText`, whose
  /// trailing `›` is [EvaButton.trailingChevron] rather than part of the label.
  ghost,
}

/// The fill, ink, rim and glow for one [EvaButtonVariant].
///
/// Extracted from the widget because §6 says a widget's conditionals are not
/// where logic lives, and because the prototype's numbers are in CSS and would
/// otherwise be retyped at each of seven call sites' worth of widgets.
@immutable
class EvaButtonStyle {
  /// A button treatment.
  const EvaButtonStyle({
    required this.background,
    required this.pressedBackground,
    required this.foreground,
    required this.border,
    required this.glow,
    required this.pressedGlow,
  });

  /// The resting fill.
  final Color background;

  /// The fill while pressed. Equal to [background] where the prototype has no
  /// pressed state — see [resolveButtonStyle].
  final Color pressedBackground;

  /// The label's ink.
  final Color foreground;

  /// The resting rim, drawn by the enclosing [EvaFocusRing]. `null` is a real
  /// value: `ButtonPrimary` has `border: none`.
  final Border? border;

  /// Shadows over the resting fill.
  final List<BoxShadow> glow;

  /// Shadows over the pressed fill. Empty wherever the prototype writes
  /// `boxShadow: pressed ? 'none' : …`.
  final List<BoxShadow> pressedGlow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaButtonStyle &&
          other.background == background &&
          other.pressedBackground == pressedBackground &&
          other.foreground == foreground &&
          other.border == border &&
          listEquals(other.glow, glow) &&
          listEquals(other.pressedGlow, pressedGlow);

  @override
  int get hashCode => Object.hash(
    background,
    pressedBackground,
    foreground,
    border,
    Object.hashAll(glow),
    Object.hashAll(pressedGlow),
  );
}

/// Resolves the treatment for [variant] in [colors].
///
/// ## THE ONE VALUE THAT IS NOT THE PROTOTYPE'S
///
/// `ds.tsx:238` sets the primary label to `hex.ink` — `#EAE8F5` in dark,
/// `#120E28` in light. On the light palette that is near-black on `#D4891A`,
/// which is a *dark* ink on a mid-tone amber and reads as muddy rather than as a
/// label. `03-design-system.md` §5.1 names `onEmber` as `EvaButton.primary`'s
/// foreground and Phase 1 measured both pairings against WCAG 2.x (AGENT_CONTEXT
/// §6 decision 6): `onEmber` is 9.17:1 in dark and 5.41:1 in light. The token is
/// used, and the prototype's value is recorded here rather than inherited.
///
/// ## WHAT IS **NOT** INVENTED FOR SECONDARY AND GHOST
///
/// `ButtonSecondary` transitions `border-color` and nothing else
/// (`ds.tsx:264`); `ButtonText` transitions nothing at all. So neither has a
/// pressed fill and neither has a pressed glow — [EvaButtonStyle.pressedGlow] and
/// the `pressedBackground == background` identity are the honest transcription,
/// and the press feedback that does exist is `InkWell`'s splash.
EvaButtonStyle resolveButtonStyle({
  required EvaButtonVariant variant,
  required EvaColors colors,
}) => switch (variant) {
  EvaButtonVariant.primary => EvaButtonStyle(
    // `ds.tsx:239` — `background: pressed ? hex.emberDeep : hex.ember`.
    background: colors.ember,
    pressedBackground: colors.emberDeep,
    foreground: colors.onEmber,
    // `ds.tsx:240` — `border: 'none'`.
    border: null,
    // `ds.tsx:244` —
    //   `0 0 28px rgba(ember, .35), 0 4px 14px rgba(ember, .25)`.
    //
    // Not an elevation ramp: AGENT_CONTEXT §6 decision 7 froze every Material
    // elevation at 0 because the prototype has no z-axis, and this pair is
    // quoted straight out of one declaration in the prototype. The second
    // shadow's `4px` offset is the only thing in the whole design system with a
    // non-zero, non-ambient shadow offset, and it exists because the prototype
    // wrote it there.
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
    // `ds.tsx:260` — `background: 'transparent'`.
    background: Colors.transparent,
    pressedBackground: Colors.transparent,
    // `ds.tsx:260` — `color: T.ink`.
    foreground: colors.ink,
    // `ds.tsx:261` — `border: 1.5px solid rgba(hex.ink, 0.2)`.
    border: Border.all(color: colors.ink.withValues(alpha: 0.20), width: 1.5),
    glow: const <BoxShadow>[],
    pressedGlow: const <BoxShadow>[],
  ),
  EvaButtonVariant.ghost => EvaButtonStyle(
    // `ds.tsx:278` — `background: 'none', border: 'none'`.
    background: Colors.transparent,
    pressedBackground: Colors.transparent,
    // `ds.tsx:277-278` — `color: color ?? T.ink`. The prototype's `color` prop
    // is not carried over: nothing at a shipped call site overrides it, and a
    // `color` parameter on a design-system button is exactly the hole that lets
    // an un-tokenable colour in.
    foreground: colors.ink,
    border: null,
    glow: const <BoxShadow>[],
    pressedGlow: const <BoxShadow>[],
  ),
};

/// The prototype's primary/secondary height. `ds.tsx:240,262` — `height: 52`.
const double kEvaButtonHeight = 52;

/// The prototype's disabled opacity. `ds.tsx:245` — `opacity: disabled ? 0.45`.
const double kEvaButtonDisabledOpacity = 0.45;

/// The prototype's chevron size. `ds.tsx:283` — `fontSize: 16, fontWeight: 700`.
const double kEvaButtonChevronSize = 16;

/// Three prototype buttons, one widget. Seven surviving call sites.
///
/// ## EVERY INTERACTIVE STATE, AND WHERE EACH ONE COMES FROM
///
/// | state | source |
/// | --- | --- |
/// | pressed fill | `ds.tsx:239` — `emberDeep` |
/// | pressed glow removal | `ds.tsx:244` |
/// | disabled | `ds.tsx:245` — `opacity: 0.45` |
/// | focus ring | `09-quality-gates.md` §14 — not in the prototype at all |
/// | hover | **not in the prototype.** `InkWell`'s hover tint, no Eva value |
///
/// ## REDUCED MOTION
///
/// The press transition is the only animation here, and it reads
/// `MediaQuery.disableAnimationsOf(context)`. With animations off the duration
/// is [Duration.zero], so [AnimatedContainer] applies the pressed fill on the
/// frame the press starts — the end state immediately, which is what §14 asks
/// for. There is no fade to skip; the button simply is the other colour.
///
/// The prototype's duration is `180ms` (`ds.tsx:242`), which is not a token.
/// `EvaMotion.fast` (150ms) is the nearest and is documented as "press and hover
/// feedback on a control", so it is used rather than a literal 180.
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
    super.key,
  });

  /// The button's text. Also its accessible name — there is no separate
  /// `semanticLabel`, because a button whose name can disagree with its text is
  /// the §14 gap in a different shape.
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

  @override
  State<EvaButton> createState() => _EvaButtonState();
}

class _EvaButtonState extends State<EvaButton> {
  /// Press tracking.
  ///
  /// An `InkWell` reports it through `onHighlightChanged`, which is why the
  /// press *fill* is a separate concern from the ink splash: the prototype
  /// changes both (`ds.tsx:239,244`) and they are not the same mechanism.
  bool _pressed = false;

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

    final Widget? leading = switch (widget.icon) {
      final IconData glyph => Padding(
        padding: const EdgeInsets.only(right: EvaSpacing.sm),
        child: Icon(
          glyph,
          size: kEvaButtonChevronSize + EvaSpacing.xs,
          color: style.foreground,
        ),
      ),
      null => null,
    };

    final Widget text = Text(
      widget.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: switch (widget.variant) {
        // `ds.tsx:237` — `fontSize: 16, fontWeight: 700,
        // letterSpacing: '0.01em'`. The letter spacing is dropped: §5.2 gives
        // `mono` no tracking value and `03-design-system.md` names none for
        // `ui`, so adding 0.01em would be inventing one.
        //
        // `titleMedium` is Material 3's 16sp slot, so the prototype's 16 lands
        // exactly.
        EvaButtonVariant.primary => _labelStyle(
          context,
          style.foreground,
          FontWeight.w700,
        ),
        // `ds.tsx:259` — `fontSize: 16, fontWeight: 600`.
        EvaButtonVariant.secondary => _labelStyle(
          context,
          style.foreground,
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
          style.foreground,
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
              color: colors.ember,
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
        color: _pressed ? style.pressedBackground : style.background,
        borderRadius: BorderRadius.circular(EvaRadii.button),
        // The rim is the [EvaFocusRing]'s `idleBorder`, not here, so that a
        // focused button carries exactly one border and the ring is the spec.
        boxShadow: _pressed ? style.pressedGlow : style.glow,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: style.foreground),
        child: Opacity(
          // `ds.tsx:245` — `opacity: disabled ? 0.45 : 1`.
          opacity: enabled ? 1 : kEvaButtonDisabledOpacity,
          child: label,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      // The label text is already the accessible name; leaving it in the tree
      // as well makes a screen reader read "Sign in, Sign in".
      excludeSemantics: true,
      child: EvaFocusRing(
        // `EvaInk` is disabled below when `onPressed` is null, and the two must
        // agree or Tab would stop on a control that cannot be activated.
        enabled: enabled,
        idleBorder: style.border,
        radius: EvaRadii.button,
        child: EvaInk(
          onPressed: widget.onPressed,
          onHighlightChanged: (bool value) {
            if (value == _pressed) return;
            setState(() => _pressed = value);
          },
          child: body,
        ),
      ),
    );
  }

  TextStyle _labelStyle(
    BuildContext context,
    Color foreground,
    FontWeight weight,
  ) =>
      Theme.of(context).textTheme.titleMedium!
          .copyWith(color: foreground, fontWeight: weight);
}
