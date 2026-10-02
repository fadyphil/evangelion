import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A square, borderless, icon-only button.
///
/// Four surviving call sites (`04-widget-inventory.md` §3) — ReadingEn's back,
/// ReadingAr's back, Quiz's close, Settings' back — plus the `Aa` and bookmark
/// controls Phase 7 composes.
///
/// ## THE ACCESSIBLE NAME IS NOT OPTIONAL, AND IS NOT A SECOND PARAMETER
///
/// §14's first row: "Icon-only buttons (back, close, bookmark, `Aa`) have no
/// accessible name". [tooltip] is **required** and feeds *both* the [Tooltip] and
/// `Semantics(label:)`, rather than being two parameters that can disagree. A
/// button whose tooltip says "Close" and whose semantics say "Dismiss" is worse
/// than an unnamed one in at least one of the two surfaces a reader uses.
///
/// The prototype's four buttons are all `<button>`s with an inline `<svg>` and
/// no label at all (`SettingsScreen.tsx:39-41`, `ReadingEnScreen.tsx:14-16`,
/// `QuizScreen.tsx:46-50`), so every string here is one the shipped screens have
/// to supply. There is no sensible default and none is invented.
class IconActionButton extends StatelessWidget {
  /// A button showing [icon], named [tooltip].
  const IconActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 44,
    this.iconSize,
    super.key,
  });

  /// The glyph. Material's [IconData] — `Icons.arrow_back`, `Icons.close`, and so
  /// on. A caller supplies it because the icon *is* the call site's meaning and
  /// four different sites need four different arrows; a design-system widget
  /// that chose the glyph would be choosing the navigation model.
  final IconData icon;

  /// The accessible name, and the [Tooltip]'s text.
  final String tooltip;

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

  /// The glyph's size. Defaults to [size] minus a quarter, which is the
  /// prototype's own proportion: 20px in a 44px box (`SettingsScreen.tsx:40`) and
  /// 18px in a 44px box for the heavier close (`QuizScreen.tsx:47`).
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        // §14's first row, closed: the same string that names the tooltip.
        label: tooltip,
        excludeSemantics: true,
        // Load-bearing, and easy to lose: `excludeSemantics: true` drops the
        // `InkWell`'s tap action along with the label, so without this the
        // button carries a name a screen reader can read and **no way to press
        // it** — a TalkBack double-tap is `ACTION_CLICK` =
        // [SemanticsAction.tap]. `null` when disabled, because the action must be
        // genuinely absent rather than present and flagged.
        onTap: enabled ? onPressed : null,
        child: EvaFocusRing(
          enabled: enabled,
          // No rim. `ds.tsx:39` — `background: 'none', border: 'none'`.
          idleBorder: null,
          // Square. A ring on a circle would need a different radius, and every
          // one of the four call sites is a square box.
          radius: EvaRadii.button,
          child: EvaInk(
            onPressed: onPressed,
            // The ink has to be clipped to the box, or a splash escapes a 44px
            // button and paints over whatever is beside it.
            borderRadius: BorderRadius.circular(EvaRadii.button),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize ?? size * 0.4545,
                  // `ds.tsx:39-40` — `color: T.ink2`. Dimmed when disabled, so
                  // "cannot be pressed" is not signalled by colour alone either:
                  // the enabled flag is in the semantics, and the ink is gone.
                  color: enabled ? colors.ink2 : colors.ink3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
