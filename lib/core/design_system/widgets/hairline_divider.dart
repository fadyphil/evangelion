import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A 1px rule, optionally interrupted by a centred mono-caps label.
///
/// Three surviving call sites (`04-widget-inventory.md` §3): Login's "or"
/// (`LoginScreen.tsx:76-80`), and the short centred rules under each reading's
/// title (`ReadingEnScreen.tsx:42`, `ReadingArScreen.tsx:45`).
///
/// ## THE TWO PROTOTYPE RULES ARE NOT THE SAME RULE
///
/// The reading screens draw a **36px-wide** centred stub in
/// `rgba(#fff | #000, 0.12)`. Login draws a **flexible** rule either side of a
/// label in `rgba(#fff | #000, 0.08)`. So [width] is a parameter and defaults to
/// the full available width — the labelled form is the one with a call site this
/// widget exists for — and [ruleColor] is a parameter because the two alphas
/// differ by four points and picking one would quietly change a shipped screen.
///
/// `line` is the design system's hairline token (`03-design-system.md` §5.1), but
/// it is **1px of `line`**, not the prototype's white/black alpha: `line` is
/// `#1C2238` in dark, which on a `#05081A` canvas is a *very* faint rule and
/// would disappear on the near-black reading screen. The prototype's 8% white is
/// about three times that. Recorded, because "the divider IS the hairline token"
/// is true of `ThemeData.dividerColor` and is not true of this widget.
class HairlineDivider extends StatelessWidget {
  /// A rule, optionally labelled [label] in the middle.
  const HairlineDivider({this.label, this.color, this.width, super.key});

  /// The centred label. `null` draws a bare rule.
  final String? label;

  /// The rule's colour. `null` resolves to `ink` at 8% — Login's value.
  final Color? color;

  /// The rule's length. `null` fills the available width.
  final double? width;

  /// The rule's thickness, in logical px. `1` everywhere in the prototype.
  static const double thickness = 1;

  /// Gap between a label and each half of the rule. `LoginScreen.tsx:76` —
  /// `gap: 10`.
  static const double labelGap = 10;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color rule = color ?? colors.ink.withValues(alpha: 0.08);

    final Widget line = Container(height: thickness, color: rule);

    final String? text = label;
    if (text == null) {
      return SizedBox(width: width, height: thickness, child: line);
    }

    return SizedBox(
      height: EvaSpacing.lg,
      child: Row(
        children: <Widget>[
          Expanded(child: line),
          const SizedBox(width: labelGap),
          Text(
            text.toUpperCase(),
            style: EvaTypography.monoCaps(colors).copyWith(
              // `LoginScreen.tsx:78` — `color: T.ink3`.
              color: colors.ink3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: labelGap),
          Expanded(child: line),
        ],
      ),
    );
  }
}
