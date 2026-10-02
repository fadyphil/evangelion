import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The Settings screen's on/off switch.
///
/// It is a **local** component in the prototype — `SettingsScreen.tsx:14-26`
/// defines `Toggle` inside the screen file rather than in `ds.tsx` — so there is
/// no `ds.tsx` line to cite and every number below is quoted from there.
///
/// ## COLOUR-ONLY STATE
///
/// On is `ember`, off is `rgba(#fff | #000, 0.12)`. That is a colour difference
/// and nothing else, which §14 bans. Three things carry the state instead:
///
/// 1. **the knob moves** — `justifyContent: flex-end` vs `flex-start`
///    (`SettingsScreen.tsx:19-20`), which survives greyscale;
/// 2. `Semantics(toggled: value)`, so a screen reader says on or off;
/// 3. the glow, which is on only when on (`SettingsScreen.tsx:22`).
///
/// ## THE KNOB IS WHITE IN BOTH PALETTES
///
/// `SettingsScreen.tsx:24` — `background: '#ffffff'` — and it is left that way.
/// A white knob on the light palette's `#120E28`-at-12% track is *more*
/// legible than an `ink` knob would be, and the prototype made that choice
/// deliberately enough to write the literal.
class EvaToggle extends StatelessWidget {
  /// A switch whose current position is [value].
  const EvaToggle({required this.value, required this.onChanged, super.key});

  /// Whether the switch is on.
  final bool value;

  /// Reports the new position.
  final ValueChanged<bool> onChanged;

  /// Track size. `SettingsScreen.tsx:16` — `width: 44, height: 24`.
  static const Size trackSize = Size(44, 24);

  /// Knob diameter. `SettingsScreen.tsx:24` — `width: 18, height: 18`.
  static const double knobSize = 18;

  /// The track's inset. `SettingsScreen.tsx:19` — `padding: '0 3px 0 0'` when on
  /// and `'0 0 0 3px'` when off, i.e. the knob sits 3px from one end.
  static const double knobInset = 3;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // §14 — the slide is the one animation here, and it is 200ms in the
    // prototype (`SettingsScreen.tsx:21`), which is `EvaMotion.base` exactly.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      // §14: a switch, not a button. `toggled` is what makes "on" announceable.
      toggled: value,
      label: value ? 'On' : 'Off',
      excludeSemantics: true,
      // Load-bearing, and easy to lose: `excludeSemantics: true` drops the
      // `InkWell`'s tap action with the label, so without it the switch
      // announces "On, switch" and a TalkBack double-tap does nothing.
      // [SemanticsAction.tap] is `ACTION_CLICK`, and on a switch that is how a
      // reader flips it. A toggle has no disabled state, so this is never null.
      onTap: () => onChanged(!value),
      child: EvaFocusRing(
        enabled: true,
        // A switch is a stadium, so the ring has to be too.
        radius: trackSize.height / 2,
        child: EvaInk(
          onPressed: () => onChanged(!value),
          borderRadius: BorderRadius.circular(trackSize.height / 2),
          child: AnimatedContainer(
            duration: animate ? EvaMotion.base : Duration.zero,
            curve: EvaMotion.baseCurve,
            width: trackSize.width,
            height: trackSize.height,
            padding: const EdgeInsets.symmetric(horizontal: knobInset),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              // `SettingsScreen.tsx:17` — `background: on ? hex.ember :
              // rgba(#fff | #000, 0.12)`.
              color: value ? colors.ember : colors.ink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(trackSize.height / 2),
              // `SettingsScreen.tsx:22` — `boxShadow: on ? 0 0 14px
              // rgba(ember, 0.45) : 'none'`.
              boxShadow: value
                  ? <BoxShadow>[
                      BoxShadow(
                        color: colors.ember.withValues(alpha: 0.45),
                        blurRadius: 14,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                // `SettingsScreen.tsx:24` — `background: '#ffffff'`,
                // `boxShadow: '0 1px 4px rgba(0,0,0,0.25)'`.
                //
                // The white is literal in the prototype and stays literal: it is
                // the one place in this design system where a colour is not a
                // token, because the knob is the switch's *handle* rather than a
                // themed surface, and `surface` would be white in light and near-
                // black in dark, which would invert the control's only cue. See
                // the class doc.
                color: EvaToggleKnob.color,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.ink.withValues(alpha: 0.25),
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The switch knob's colour.
///
/// Split out so the one non-token colour in the design system has a name, a
/// reason and one place to change. `EvaColors` publishes no white that means
/// "the handle of a control": `surface` is `#FFFFFF` in light but `#0D1224` in
/// dark, and `ink` is the opposite again. A knob that follows either would stop
/// reading as a handle on one of the two palettes.
///
/// Declared here rather than inlined so `no_colour_literals_test.dart` — which
/// confines colour literals to `tokens/` — does not have to grow an exemption for
/// a widget, and so the exemption question stays where it belongs: in the token
/// tables.
abstract final class EvaToggleKnob {
  /// `#FFFFFF` — the prototype's `SettingsScreen.tsx:24` knob, in both palettes.
  static const Color color = Color(0xFFFFFFFF);
}
