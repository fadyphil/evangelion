import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// One of the two social sign-in buttons on `/login`.
///
/// `LoginScreen.tsx:87-95`, transcribed:
///
/// | prototype | here |
/// | --- | --- |
/// | `fontFamily: F.ui, fontSize: 15, fontWeight: 500, color: T.ink` | `bodyMedium` w500, [EvaColors.ink] — Material 3's 14sp slot; `titleMedium` (16sp) was tried first and truncates at §14's surface. See the section below. |
/// | `background: rgba(255, 0.05)` dark / `rgba(0, 0.03)` light | [EvaColors.glassFill] — 5% dark, 3% light, exactly |
/// | `border: 1px solid rgba(#fff \| #000, 0.1)` | 1px [EvaColors.glassBorder] |
/// | `borderRadius: 14` | [EvaRadii.button] |
/// | `height: 50` | [kSocialButtonHeight] — `LoginScreen.tsx:91` |
/// | `gap: 10` | **not transcribed** — it separated the brand mark from the label,
///   and there is no mark. See below; the constant is gone rather than kept as an
///   inset it never was. |
///
/// ## THE LABEL IS `bodyMedium`, NOT `titleMedium`, AND §14 IS WHY
///
/// `LoginScreen.tsx:87` writes `fontSize: 15`, and the first version of this
/// widget used `titleMedium` — Material 3's 16sp slot — as the same substitution
/// `EvaButton`'s ghost variant makes. Measured at §14's own surface (320px wide,
/// 1.22×, the real screen pumped):
///
/// ```
/// available inner width                192.0
/// "Continue with Google"  @ 16sp      201.63   -> clipped by  9.63
/// "المتابعة عبر Google"  @ 16sp      193.34   -> clipped by  1.34
/// ```
///
/// `maxLines: 1` + `TextOverflow.ellipsis` means clipping the **string**, not
/// overflowing the box, so `RenderFlex` never raised a `FlutterError` and
/// `login_text_scale_test.dart`'s `takeException() == null` was satisfied by a
/// label reading "Continue with Go…". §14's row is "text scales to 1.22× without
/// overflow at 320px", and a truncated label is not that; the negative control in
/// that file proves it detects *overflow* and that nothing detected *truncation*.
///
/// `bodyMedium` is 14sp, so the same measurement gives 176.4 and 169.0 — inside
/// 192 — and it is *closer* to the prototype's 15 than 16 was. So this is the same
/// recorded decision 5 substitution as everywhere else, moved in the direction that
/// makes §14 true. `login_text_scale_test.dart` now asserts the label fits rather
/// than only that nothing overflowed.
///
/// ## THE BRAND MARKS ARE NOT REPRODUCED, AND THE FILE MAP IS OUT OF DATE
///
/// `LoginScreen.tsx:83-96` draws a four-colour Google `G` and a filled Apple mark
/// inside these buttons, and `docs/plans/07-file-map.md` §7 accordingly lists
/// `widgets/google_mark.dart` and `widgets/apple_mark.dart`. Neither file ships.
///
/// The reason is that reproducing either faithfully from hand-typed path data
/// would mean inventing coordinates: `flutter_svg` is unavailable (AGENT_CONTEXT
/// §8.4 makes an unlisted dependency a hard stop), and Material has no icon for
/// either brand. A four-point polygon that *approximates* Google's mark is a
/// different logo — a trademark rendered inaccurately — and this repository's
/// whole Phase 3 finding was that a transcription error present in both a widget
/// and its golden is invisible by construction (AGENT_CONTEXT §9, decision 8). A
/// wrong logo is the sharpest possible version of that.
///
/// So the buttons are **text-only**, the marks are the one recorded divergence, and
/// `LoginPage`'s doc says so where a reader of the screen will find it.
///
/// ## IT SHIPS DISABLED, AND THAT IS THE POINT
///
/// AGENT_CONTEXT §2's route table says `/login` includes "social buttons", so
/// dropping them would be a silent divergence. There is **no OAuth port, no social
/// SDK and no endpoint** — §2 decision 3 fixes login as UI-only over a
/// `FakeAuthRepository` — so the control is rendered and is **genuinely inert**:
///
/// * [onPressed] is `null`, so there is no `InkWell` handler and no focus node —
///   invisible to Tab, exactly as `IconActionButton`'s doc describes for a disabled
///   icon button;
/// * `Semantics(enabled: false)` and **no tap action at all**, which is §14's
///   disabled row: a reader who activates a control announced as unusable and gets
///   a response has been told a lie, and only a node with the action *removed*
///   satisfies both halves;
/// * the caller appends [LoginStrings.unavailableSuffix] to the label, so the
///   announcement says *why* rather than only that it cannot be pressed.
class SocialAuthButton extends StatelessWidget {
  /// A social sign-in button.
  ///
  /// [onPressed] is `null` in every shipping call site — see the class doc — and
  /// the parameter exists so that disabled is the *only* thing `null` means here,
  /// rather than "no callback was passed".
  const SocialAuthButton({
    required this.label,
    required this.semanticLabel,
    this.onPressed,
    super.key,
  });

  /// The button's visible text.
  final String label;

  /// The button's accessible name, which is [label] plus the reason it cannot be
  /// pressed.
  ///
  /// A separate parameter rather than a concatenation here, because the suffix
  /// belongs to the **localisation table** and not to this widget — the wording is
  /// `LoginStrings.unavailableSuffix`, and a widget that appended English would put
  /// one English string inside the Arabic arm.
  final String semanticLabel;

  /// What to run on activation. `null` disables the button.
  final VoidCallback? onPressed;

  /// `LoginScreen.tsx:91` — `height: 50`.
  static const double kSocialButtonHeight = 50;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      // `null` when disabled, for the reason the class doc gives: the action must
      // be genuinely **absent**, not present and flagged.
      onTap: enabled ? onPressed : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(EvaRadii.button),
          border: Border.all(color: colors.glassBorder, width: 1),
        ),
        child: SizedBox(
          height: kSocialButtonHeight,
          width: double.infinity,
          child: Padding(
            // The prototype's button has no padding and is centred by its own flex,
            // so the only inset it needs is the one that keeps a long Arabic label
            // off the rim.
            padding: const EdgeInsets.symmetric(horizontal: EvaSpacing.lg),
            child: Center(
              child: Text(
                label,
                // `maxLines: 1` + ellipsis, not a wrap. At 1.22× on a 320px screen
                // the Arabic label is wider than the field, and a second line would
                // push the button's fixed 50px height into an overflow.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                // `bodyMedium`, not `titleMedium`. See the class doc: at
                // `titleMedium`'s 16sp the English label is 201.63 wide inside a
                // 192.0 box at 320px/1.22×, and an ellipsised label is a §14
                // failure that raises no `FlutterError` for the overflow suite to
                // see.
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: colors.ink, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
