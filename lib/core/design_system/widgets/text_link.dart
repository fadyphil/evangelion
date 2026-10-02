import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// An inline text button, optionally `ember` and optionally with a chevron.
///
/// One surviving shared call site: Login's "Create account"
/// (`LoginScreen.tsx:70-72`). That button is `ui 14 / 600` in `ember` with no
/// chevron; `ButtonText` ("Forgot password?") is `ui 15 / 500` in `ink` **with**
/// the chevron (`ds.tsx:271-286`).
///
/// ## WHY THIS IS SEPARATE FROM `EvaButton.ghost`
///
/// Because the two differ in exactly the two things a caller would want to change
/// and cannot: the **size** (`labelLarge` vs `titleMedium` — the prototype's 15
/// vs 14) and the **chevron**, which `ButtonText` appends as part of the
/// component and `EvaButton` exposes as a flag. Collapsing them would mean
/// `EvaButton` grew a font-size parameter, and a design-system button with a
/// caller-chosen font size is how a 12sp label ends up on a 52px pill.
///
/// ## WHY IT CARRIES ITS OWN FOCUS RING RATHER THAN BEING AN `EvaButton`
///
/// It is a control, so §14 applies to it exactly as it applies to a button. The
/// only reason it is not an `EvaButton` is typography, and saying so is cheaper
/// than a `Variant`-per-size enum.
class TextLink extends StatelessWidget {
  /// A link labelled [label].
  const TextLink({
    required this.label,
    this.onPressed,
    this.color,
    this.chevron = false,
    super.key,
  });

  /// The link's text and accessible name.
  final String label;

  /// What to run on activation. `null` disables it.
  final VoidCallback? onPressed;

  /// The label's colour. `null` resolves to `ink` — `ds.tsx:278`'s
  /// `color: color ?? T.ink`. `ember` is the call site's choice
  /// (`LoginScreen.tsx:70`), not a default, because "this link is the primary
  /// action" is a per-screen decision.
  final Color? color;

  /// Whether to append the prototype's `›`.
  ///
  /// `ds.tsx:283` appends it only when no explicit `color` was passed — i.e. the
  /// chevron belongs to the neutral variant. Here the flag is explicit for the
  /// same reason the colour is: a rule that fires from a *different* parameter
  /// than the one it controls is a rule nobody can predict.
  ///
  /// ## THE CHEVRON'S COLOUR IS `ember`, NOT THE LINK'S INK
  ///
  /// `ds.tsx:283` writes `color: hex.ember` on the `›`, and [EvaButton]'s
  /// transcription of the same glyph reads [EvaColors.ember] too. This one read
  /// [ink] — the link's own colour — which is not one of the eight declared
  /// divergences and therefore was simply a transcription error: one prototype
  /// glyph, two colours, one phase.
  ///
  /// What is *not* changed is the coupling the prototype had, because this widget
  /// replaced it: the prototype gates the chevron's **presence** on the absence
  /// of an explicit colour, which no Flutter parameter spelling can express, so
  /// `chevron` is its own flag here. The colour is the prototype's.
  ///
  /// No shipped screen changes: the one call site with a chevron is the neutral
  /// variant (`ButtonText`), whose ink is `ink` and whose chevron is `ember`
  /// either way.
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color ink = color ?? colors.ink;
    final bool enabled = onPressed != null;

    final Widget body = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: ink,
              // `ds.tsx:277` — `fontWeight: 500`; `LoginScreen.tsx:70` —
              // `fontWeight: 600`. Six hundred is the call site's emphasis and
              // 500 is the component's, so 600 is used: a link that is the only
              // action on a row is emphasised, and the neutral variant at 500 is
              // a one-word change if that proves wrong.
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (chevron)
          Padding(
            padding: const EdgeInsets.only(left: EvaSpacing.xs),
            child: Icon(
              Icons.chevron_right,
              size: EvaSpacing.lg,
              color: colors.ember,
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // Disabled links keep their ink. A 45% opacity on a 14sp label is the
      // prototype's button rule (`ds.tsx:245`) and it fails contrast where the
      // ink is already `ink2`; the semantics flag and the absent ink carry it.
      excludeSemantics: true,
      // Load-bearing, and easy to lose: `excludeSemantics: true` drops the
      // `InkWell`'s tap action along with the label, so without this the link is
      // announced and cannot be activated — a TalkBack double-tap is
      // `ACTION_CLICK` = [SemanticsAction.tap]. `null` when disabled, because a
      // disabled control's action must be genuinely absent rather than present
      // and flagged.
      onTap: enabled ? onPressed : null,
      child: EvaFocusRing(
        enabled: enabled,
        radius: EvaSpacing.xs,
        child: EvaInk(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(EvaSpacing.xs),
          child: body,
        ),
      ),
    );
  }
}
