import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Which of the prototype's four pill definitions this is.
///
/// `04-widget-inventory.md` §3 records "4 style defs / 11 rendered" for the
/// mono-caps pill and collapses them into one widget. The four definitions, and
/// where they end up:
///
/// | definition | prototype | variant |
/// | --- | --- | --- |
/// | `CategoryChip` | `ds.tsx:326-347` | [filter] |
/// | `App.tsx` screen chips | `App.tsx:70-84` | [toggle] |
/// | `QuizScreen` frame toggle | `QuizScreen.tsx:30-38` | [toggle] |
/// | Settings language pills | `SettingsScreen.tsx:77-90` | [toggle] |
/// | `SealFAB` dock item | `ds.tsx:545-555` | [static] |
/// | `App.tsx` theme toggle | `App.tsx:58-66` | [static] |
///
/// ## WHAT IS DELIBERATELY NOT BUILT
///
/// Defect #12: "`App.tsx`'s screen switcher and `QuizScreen`'s "Frame A/B"
/// toggle exist only to let the Figma agent preview states … **Do not port**".
/// Neither is ported, and no widget here has a "frame" concept. What is
/// transcribed is the shared pill *recipe* — which those two happen to agree on
/// with the Settings language pills, which are a real call site — because the
/// inventory collapses four definitions into one widget and a widget needs a
/// style table to collapse into.
///
/// [toggle] exists for the **real** theme toggle in Settings (Phase 9), not for
/// a frame switcher.
enum EvaChipVariant {
  /// Sticker-coloured, selection turns it `ember`. `CategoryChip`.
  filter,

  /// Tinted glass menu item. No selection state at all — see
  /// [resolveChipStyle].
  static,

  /// Mono-caps pill that turns `ember` when selected. The `App.tsx` chips, the
  /// Settings language pills, and the real theme toggle.
  toggle,
}

/// The fill, rim, ink and glow for one chip.
@immutable
class EvaChipStyle {
  /// A chip treatment.
  const EvaChipStyle({
    required this.background,
    required this.foreground,
    required this.border,
    required this.dot,
    required this.dotGlow,
    required this.glow,
  });

  /// The pill's fill.
  final Color background;

  /// The label's ink, and the source of every other colour in this style.
  final Color foreground;

  /// The rim. Never null — all four prototype pills have one.
  final Border border;

  /// The leading dot's fill. `null` would be "no dot", but
  /// [EvaChip.leadingDot] is what hides the dot, so this is always a colour.
  final Color dot;

  /// The dot's shadow, or `null` for no glow.
  final BoxShadow? dotGlow;

  /// The pill's own shadow. Empty for the pills that have none.
  final List<BoxShadow> glow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaChipStyle &&
          other.background == background &&
          other.foreground == foreground &&
          other.border == border &&
          other.dot == dot &&
          other.dotGlow == dotGlow &&
          listEquals(other.glow, glow);

  @override
  int get hashCode => Object.hash(
    background,
    foreground,
    border,
    dot,
    dotGlow,
    Object.hashAll(glow),
  );
}

/// Resolves the chip treatment.
///
/// [sticker] is honoured by [EvaChipVariant.filter] only. It is ignored by the
/// other two on purpose: `App.tsx`'s chips have no colour prop at all, so a chip
/// that honoured one there would let a hue nobody chose into the Settings
/// language pills.
///
/// [EvaChipVariant.static] ignores [selected] for the same kind of reason — a
/// dock item is a menu entry, not an option, and the prototype's dock has no
/// notion of a current item. Inventing one would make a static chip look
/// selected by accident.
EvaChipStyle resolveChipStyle({
  required EvaChipVariant variant,
  required EvaColors colors,
  required bool selected,
  required Color? sticker,
}) => switch (variant) {
  EvaChipVariant.filter => _filter(
    colors: colors,
    selected: selected,
    sticker: sticker,
  ),
  EvaChipVariant.toggle => _toggle(colors: colors, selected: selected),
  EvaChipVariant.static => _static(colors: colors),
};

/// `CategoryChip` — `ds.tsx:326-347`.
EvaChipStyle _filter({
  required EvaColors colors,
  required bool selected,
  required Color? sticker,
}) {
  // The library screen that owned sticker colours was cut, so a `filter` chip
  // with no colour is reachable by accident. Ember is the fallback because it is
  // the only accent in the system and a chip in `ink` is indistinguishable from
  // body text.
  final Color hue = selected ? colors.ember : (sticker ?? colors.ember);
  return EvaChipStyle(
    // `ds.tsx:332` — `active ? rgba(ember, 0.14) : rgba(color, 0.12)`.
    background: selected
        ? colors.ember.withValues(alpha: 0.14)
        : hue.withValues(alpha: 0.12),
    // `ds.tsx:343` — `active ? hex.ember : color`.
    foreground: hue,
    // `ds.tsx:333` — `active ? 1.5px solid rgba(ember, 0.45) : 1px solid
    // rgba(color, 0.28)`.
    border: Border.all(
      color: selected
          ? colors.ember.withValues(alpha: 0.45)
          : hue.withValues(alpha: 0.28),
      width: selected ? 1.5 : 1.0,
    ),
    // `ds.tsx:337` — `background: active ? hex.ember : color`.
    dot: hue,
    // `ds.tsx:338` — `active ? 0 0 6px rgba(ember, .7) : 0 0 5px rgba(color, .6)`.
    dotGlow: BoxShadow(
      color: hue.withValues(alpha: selected ? 0.70 : 0.60),
      blurRadius: selected ? 6 : 5,
    ),
    glow: const <BoxShadow>[],
  );
}

/// The `App.tsx` chips and the Settings language pills.
EvaChipStyle _toggle({required EvaColors colors, required bool selected}) {
  return EvaChipStyle(
    // `App.tsx:78-79` — `${hex.ember}22`, which is ember at 0x22/0xFF = 13%.
    // `SettingsScreen.tsx:82` says `rgba(ember, 0.12)` for the same pill. The two
    // prototypes disagree by one percentage point; the named-alpha form wins and
    // the disagreement is recorded in the test rather than averaged away.
    background: selected
        ? colors.ember.withValues(alpha: 0.12)
        : Colors.transparent,
    // `App.tsx:80` — `active ? hex.ember : '#6B6F94' / '#7A75A0'`. Neither
    // literal is a token; `ink3` is the token whose documented role is
    // "disabled text and the faintest decoration" (`eva_colors.dart`), which is
    // what an unselected option's ink is.
    foreground: selected ? colors.ember : colors.ink3,
    // `App.tsx:75-76` — `active ? 1.5px solid ember : 1.5px solid rgba(#fff | #000, 0.1)`.
    // `glassBorder` *is* that 10% white/black (`eva_colors.dart:76,117`).
    border: Border.all(
      color: selected ? colors.ember : colors.glassBorder,
      width: 1.5,
    ),
    dot: selected ? colors.ember : colors.ink3,
    // `ds.tsx:338`'s selected dot glow. The unselected toggle chip in
    // `App.tsx` has no dot glow at all, and none is invented.
    dotGlow: selected
        ? BoxShadow(color: colors.ember.withValues(alpha: 0.70), blurRadius: 6)
        : null,
    // `SettingsScreen.tsx:84` — `active ? 0 0 12px rgba(ember, 0.25) : none`.
    glow: selected
        ? <BoxShadow>[
            BoxShadow(
              color: colors.ember.withValues(alpha: 0.25),
              blurRadius: 12,
            ),
          ]
        : const <BoxShadow>[],
  );
}

/// The `SealFAB` dock item — `ds.tsx:545-555`.
EvaChipStyle _static({required EvaColors colors}) => EvaChipStyle(
  // `ds.tsx:548` — `rgba(#fff | #000, 0.08)`. Written as the palette's own
  // ink at 8% rather than as `glassFill`, which is 5% in dark: the dock item is
  // *not* a `GlassSurface` and does not share its fill.
  background: colors.ink.withValues(alpha: 0.08),
  // `ds.tsx:547` — `color: T.ink`.
  foreground: colors.ink,
  // `ds.tsx:549` — `1px solid rgba(#fff | #000, 0.12)`.
  border: Border.all(color: colors.ink.withValues(alpha: 0.12), width: 1.0),
  dot: colors.ink,
  dotGlow: null,
  // `ds.tsx:553` — `0 8px 24px rgba(#000, 0.35)`.
  glow: <BoxShadow>[
    BoxShadow(
      color: colors.ink.withValues(alpha: 0.35),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ],
);

/// Chip padding. `ds.tsx:331,545` — `'5px 12px'`; `App.tsx:61` — `'6px 14px'`.
/// The `5/12` form is used because two of the four definitions use it.
const EdgeInsets kEvaChipPadding = EdgeInsets.symmetric(
  horizontal: EvaSpacing.md,
  vertical: 5,
);

/// The leading dot's diameter. `ds.tsx:336` — `width: 6, height: 6`.
const double kEvaChipDotSize = 6;

/// Gap between the dot and the label. `ds.tsx:330` — `gap: 6`.
const double kEvaChipDotGap = 6;

/// The mono-caps pill, collapsing four prototype definitions into one.
///
/// §14's "mono-caps chips … are non-focusable `div`s" is fixed here by
/// construction: this is a [Semantics] node with `button: true` and `selected`,
/// wrapped around an [EvaInk], wrapped in an [EvaFocusRing].
///
/// ## COLOUR-ONLY STATE, AND WHAT ACTUALLY DIFFERS
///
/// The prototype distinguishes selected from unselected by colour on every
/// channel it has. §14 bans that. So the selected state differs by **three**
/// non-colour things as well as by hue:
///
/// 1. the leading dot goes from a hollow ring to a solid disc
///    ([EvaChipStyle.dot] plus the dot's own border — see below),
/// 2. the rim thickens from 1px to 1.5px,
/// 3. a check glyph appears before the label.
///
/// (1) and (3) are additions. The prototype has no *selected* chip at any call
/// site that ships — `App.tsx`'s chips and `QuizScreen`'s frame toggle are both
/// defect #12 dev scaffolding — so there is no shipped screen whose appearance
/// they change.
class EvaChip extends StatelessWidget {
  /// A pill labelled [label].
  const EvaChip({
    required this.label,
    this.variant = EvaChipVariant.toggle,
    this.color,
    this.selected = false,
    this.onSelected,
    this.leadingDot = true,
    super.key,
  });

  /// The chip's text, and its accessible name.
  final String label;

  /// Which prototype pill this is.
  final EvaChipVariant variant;

  /// A sticker colour for [EvaChipVariant.filter]. Ignored by the other
  /// variants — see [resolveChipStyle].
  final Color? color;

  /// Whether this chip is the chosen one.
  final bool selected;

  /// Reports a toggle. `null` makes the chip inert — a static chip that is not a
  /// control, which is what [EvaChipVariant.static] usually is.
  final ValueChanged<bool>? onSelected;

  /// Whether to draw the leading dot. The prototype's `CategoryChip` and every
  /// `App.tsx` chip have one; the Settings language pills do not.
  final bool leadingDot;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final EvaChipStyle style = resolveChipStyle(
      variant: variant,
      colors: colors,
      selected: selected,
      sticker: color,
    );
    final bool interactive = onSelected != null;
    // One closure, two consumers. The tap action is published on the semantics
    // node *and* handed to the ink, and writing it twice is how the two drift —
    // and when they drift, the half a screen reader uses is the half that is
    // missing.
    final VoidCallback? activate = interactive
        ? () => onSelected!(!selected)
        : null;

    final Widget pill = Container(
      padding: kEvaChipPadding,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(EvaRadii.chip),
        border: style.border,
        boxShadow: style.glow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (leadingDot) ...<Widget>[
            _Dot(
              style: style,
              // Solid when **selected**, hollow when not — so the dot's *fill*
              // differs and §14's colour-only ban is met by shape, not hue.
              //
              // The exception is [EvaChipVariant.filter]: `ds.tsx:337` fills the
              // dot with the sticker colour in **both** states and changes only
              // its colour, so a hollow-then-solid dot there would be a shape the
              // prototype never drew. Its non-colour signal is the rim
              // thickening (1px → 1.5px) plus `Semantics(selected:)`.
              filled: variant == EvaChipVariant.filter || selected,
              isSelected: selected,
            ),
            const SizedBox(width: kEvaChipDotGap),
          ],
          // The check is the icon half of §14's "pair colour with an icon".
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: EvaSpacing.xs),
              child: Icon(
                Icons.check,
                size: kEvaChipDotSize + EvaSpacing.sm,
                color: style.foreground,
              ),
            ),
          Flexible(
            child: Text(
              // Flutter has no `text-transform`, so the prototype's
              // `textTransform: 'uppercase'` (`ds.tsx:343`) is applied to the
              // string. Locale-independent, which matters: `toUpperCase` in Dart
              // does not consult a locale, and the two languages this app ships
              // are the only ones it has to be right for.
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // `ds.tsx:341-344` — `F.mono, 10, 700, letterSpacing 0.10em,
              // textTransform: uppercase`.
              //
              // `labelSmall` + the mono family. §5.2 names no size for `mono`,
              // and Phase 1 decision 5 forbids restating the framework's scale,
              // so the slot is chosen for "the smallest label in the system"
              // rather than the prototype's 10sp being invented as a literal.
              // Uppercasing is `TextTransform.uppercase` rather than a
              // `letterSpacing`: no tracking value is invented for it either.
              style: EvaTypography.monoCaps(
                colors,
              ).copyWith(color: style.foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      // §14's exact prescription for this widget.
      selected: selected,
      label: label,
      excludeSemantics: true,
      // Load-bearing, and easy to lose: `excludeSemantics: true` drops the
      // `InkWell`'s tap action with the label, so without this the chip announces
      // as a button — and announces *which* one it is, via `selected:` — and a
      // TalkBack double-tap does nothing. [SemanticsAction.tap] is
      // `ACTION_CLICK`. `null` for an inert chip, so a chip that is not a control
      // cannot be activated by one.
      onTap: activate,
      child: EvaFocusRing(
        enabled: interactive,
        idleBorder: style.border,
        // A pill's rim is already round all the way round, so the ring has to be
        // too — a 14px ring on a 999px pill would draw a rounded rectangle
        // around a stadium.
        radius: EvaRadii.chip,
        child: EvaInk(
          onPressed: activate,
          borderRadius: BorderRadius.circular(EvaRadii.chip),
          child: pill,
        ),
      ),
    );
  }
}

/// The leading dot.
///
/// **The `filled` / outline distinction is the non-colour half of §14's
/// colour-only ban.** An unselected toggle chip draws a ring — a transparent
/// disc with a 1px rim — and a selected one draws a solid disc. That difference
/// survives greyscale, colour-blindness and a screen reader that reports nothing
/// but shape.
class _Dot extends StatelessWidget {
  const _Dot({
    required this.style,
    required this.filled,
    required this.isSelected,
  });

  final EvaChipStyle style;

  /// Whether the disc is solid rather than a ring.
  final bool filled;

  /// Whether the chip is selected. Only used to decide the dot's rim colour when
  /// it is hollow, so an unselected chip's dot reads as "not the accent".
  final bool isSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: kEvaChipDotSize,
    height: kEvaChipDotSize,
    decoration: BoxDecoration(
      color: filled ? style.dot : Colors.transparent,
      shape: BoxShape.circle,
      // A ring needs a rim. Without this the unselected dot is invisible, which
      // is a *different* §14 failure: a decorative element that disappears is
      // not decoration, it is a layout hole.
      border: filled
          ? null
          : Border.all(
              color: isSelected ? style.dot : style.foreground,
              width: 1,
            ),
      boxShadow: style.dotGlow == null ? null : <BoxShadow>[style.dotGlow!],
    ),
  );
}
