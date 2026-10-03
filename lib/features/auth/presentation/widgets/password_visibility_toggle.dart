import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The show/hide-password control in the field's right inset.
///
/// `LoginScreen.tsx:53-62`, and the prototype's own SVG is two states of one eye —
/// so the state is carried by the **glyph** as well as by the accessible name,
/// which is §14's "colour-only state" row answered for this screen: a reader who
/// cannot see the mask change still hears the name change, and a reader who
/// cannot hear still sees the icon.
///
/// ## WHY IT IS NOT `IconActionButton`
///
/// Two reasons, both mechanical.
///
/// * **Size.** `IconActionButton`'s minimum is `size: 44` (`ds.tsx`'s tap target).
///   `EvaTextField` reserves exactly `44` of right inset for this control —
///   `kEvaTextFieldPadding`'s own doc says the 44 is the icon's 14 + the icon's
///   18 — so a 44-wide control would need `52` and would push the field's text to
///   overflow. The prototype's button is an 18px glyph inside a 52px field.
/// * **It carries its own semantics name**, which changes with the state. A
///   `Tooltip`-wrapped icon button takes a fixed tooltip, and this control needs
///   "Show password" / "Hide password". `IconActionButton.tooltip` is one string,
///   so honouring it would mean a tooltip that lies half the time.
///
/// ## §14, IN FULL
///
/// * **Named.** [visible] selects between [showLabel] and [hideLabel], and the
///   name is what a reader hears.
/// * **Focusable, with the ring.** [EvaFocusRing] carries `evaFocusRingBorder`, so
///   the 2px `ember`-at-40% band is the design system's number rather than one
///   written here.
/// * **Activatable by a reader.** `excludeSemantics: true` drops the `InkWell`'s
///   own tap action, so `onTap` is restored explicitly — the same load-bearing
///   line `EvaButton` and `TextLink` carry.
/// * **State is announced, not just drawn.** `Semantics(toggled:)` on top of the
///   name, so the reader is told the *state* and not only the control's identity.
class PasswordVisibilityToggle extends StatelessWidget {
  /// A control that shows or hides [password] according to [visible].
  const PasswordVisibilityToggle({
    required this.visible,
    required this.showLabel,
    required this.hideLabel,
    required this.onPressed,
    super.key,
  });

  /// Whether the password is currently shown.
  final bool visible;

  /// The accessible name while the password is masked.
  final String showLabel;

  /// The accessible name while the password is visible.
  final String hideLabel;

  /// What to run on activation. Always non-null — see the class doc for why a
  /// disabled copy of this control would be the wrong shape.
  final VoidCallback onPressed;

  /// The prototype's glyph size. `LoginScreen.tsx:55` — `<svg width="18" …>`.
  static const double glyphSize = 18;

  /// The tap target. Bigger than [glyphSize] and smaller than
  /// `IconActionButton`'s 44, because the field's right inset is 44 in total and
  /// the prototype's own button has no padding at all
  /// (`LoginScreen.tsx:54` — `padding: 0`).
  static const double targetSize = 28;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    return Semantics(
      button: true,
      enabled: true,
      toggled: visible,
      label: visible ? hideLabel : showLabel,
      // Load-bearing, for the reason the class doc gives and that
      // `EvaButton`/`TextLink` also carry: `excludeSemantics` removes the
      // `InkWell`'s tap along with the label, so without this line the control is
      // announced and cannot be activated.
      onTap: onPressed,
      excludeSemantics: true,
      child: EvaFocusRing(
        enabled: true,
        // `null`: the field's own rim is the ring while it is focused, and a
        // second border here would draw one the prototype does not have. See
        // `GlassSurface`'s identical argument for the same case.
        idleBorder: null,
        radius: EvaSpacing.xs,
        child: EvaInk(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(EvaSpacing.xs),
          child: SizedBox(
            width: targetSize,
            height: targetSize,
            child: Icon(
              // `Icons.visibility_off` / `Icons.visibility`, both Material's
              // spelling of the prototype's two eye states. The prototype draws
              // the "hidden" eye with a strike-through line, which
              // `visibility_off` includes.
              visible ? Icons.visibility : Icons.visibility_off,
              size: glyphSize,
              // `ds.tsx:315-316` — `right: 14, color: T.ink3`.
              color: colors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}
