import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

import 'streak_flame_row.dart';

/// The transparent bar across the top of `/`: wordmark, streak, avatar.
///
/// `ds.tsx:499-530`. Three values and one callback, **all required** — and
/// requiredness is *half* of defect #11. The other half is that each parameter is
/// **read**, which no compile-time property can enforce.
///
/// ## DEFECT #11, AND WHY "REQUIRED" IS NECESSARILY NOT SUFFICIENT
///
/// `ds.tsx:508` writes `Evangelion`, `:525` writes `MK` and `:516` writes `12` —
/// three literals in a component that is supposed to take a session. The first
/// version of this widget gave all three defaults, which is the same defect with a
/// parameter attached: a call site that forgets one silently renders the
/// prototype's value.
///
/// So there are no defaults. [wordmark], [streakDays], [streakSemanticLabel],
/// [initials], [avatarSemanticLabel], [avatarUnavailableReason] and [onAvatarTap] are
/// all **required named**.
///
/// ### "THERE IS NOWHERE TO PUT A HARD-CODED VALUE" WAS FALSE, AND HERE IS HOW
///
/// This doc used to end that sentence: *"A hard-coded value cannot be reintroduced
/// here because there is nowhere to put one."* There was a place to put one, and it
/// was the widget's own `build`: `Text('Evangelion')` renders exactly the tree
/// `Text(wordmark)` renders when the caller passes `'Evangelion'`, and
/// `AppLocalizations.homeWordmark` **is** `'Evangelion'`. Measured: replacing the
/// parameter's use with the literal passed all 1520 tests.
///
/// **Requiredness guarantees the parameter *exists* at the call site. It says nothing
/// about whether `build` reads it.** Those are different properties and only one of
/// them is compile-time, which is the whole lesson — and the same sentence, in
/// decision 33, was itself flagged as "requiredness guarantees the parameter exists,
/// not that it is read". That observation was correct and it was recorded *next to* a
/// claim that assumed the opposite, and nothing acted on it for a whole phase.
///
/// The gate is one assertion: `app_top_bar_test.dart` passes
/// `wordmark: 'ZZZ-SENTINEL'` and asserts `find.text('ZZZ-SENTINEL')`. A sentinel
/// the product cannot want is the only value that discriminates — the streak and the
/// monogram get that discrimination from the fixture disagreeing with the prototype,
/// and this is the same trick applied to the one value whose shipped and prototype
/// spellings are identical.
///
/// ## NO BLUR HERE, AND THAT IS A CORRECTION
///
/// §13 rule 4's per-screen line used to say "`/`: `.blur` on the today's-reading
/// panel **and the top bar**". `ds.tsx:499-530` has **no** `backdropFilter` — the
/// prototype's top bar is a transparent `div` over the animated background — so the
/// rule contradicted its own inventory and `GlassTier`'s doc inherited the error by
/// naming "Home's today's-reading panel and the top bar".
///
/// **One** blur site ships on `/`: the today's-reading panel. A `BackdropFilter` is
/// a `saveLayer` plus a full read-back of everything behind it, per frame, and
/// adding one to a bar the prototype deliberately leaves see-through would be the
/// "improve the design" this project forbids. `GlassTier`'s doc is corrected, and
/// `glass_blur_budget_test.dart` now bounds `lib/features/` at **one** occurrence.
///
/// ## THE COLOURS ARE **NOT** THE PROTOTYPE'S, AND THAT IS A RECORDED DIVERGENCE
///
/// `ds.tsx:521` fills the avatar with `linear-gradient(135deg, rgba('#14B8A6',
/// .5), rgba('#3B5BDB', .5))` and rims it with `rgba('#14B8A6', …)`. `#14B8A6` (teal)
/// and `#3B5BDB` (indigo) are **not tokens**: `03-design-system.md` §5.1 publishes
/// fourteen, and neither is among them. `no_colour_literals_test.dart` refuses every
/// colour in `lib/` that does not resolve through `EvaColors`, so transcribing them
/// is not available.
///
/// The substitution is named rather than smuggled, and it is **not** what this used
/// to say. The doc read "the badge is the **ink** ramp at two alphas" — and the code
/// is `[colors.ink.withValues(alpha: 0.92), colors.ink3]`, which is one `ink` at one
/// alpha plus a **different token** in the other stop. `ink3` is not an alpha of
/// `ink`; §5.1 publishes them as separate ramp entries and they differ in the light
/// palette as well as the dark one. Written out here because "two alphas" reads as a
/// deliberate two-stop ramp and there is not one.
///
/// The monogram is `canvas`, which is the highest-contrast pairing the two palettes
/// both offer and is what the prototype was reaching for with a white monogram on a
/// dark badge. The rim is `ember` at 35%, because the prototype's rim
/// is a hue that separates the badge from the bar and `ember` is the only accent in
/// §5.1.
///
/// ## THE AVATAR IS **32 VISIBLE AND 44 TAPPABLE**
///
/// `ds.tsx:520` is `width: 32, height: 32`. The visible circle is exactly that.
/// The **tap and focus box** around it is 44 — `IconActionButton`'s default and the
/// `iOSTapTargetGuideline` minimum — because §14's first row is about a control
/// having a keyboard path and an accessible name, and a 32px target is below what a
/// finger reliably hits.
///
/// The rendered appearance is unchanged by this: the extra 12 pixels are a
/// transparent box around a 32px circle, so the bar draws exactly what the
/// prototype draws. **The cost is stated:** the bar's row is 44 tall rather than the
/// prototype's 32, because a row's height is its tallest child. That is the whole
/// divergence and it is one number.
class AppTopBar extends StatelessWidget {
  /// The bar, showing [wordmark], the [streakDays]-day streak and [initials].
  const AppTopBar({
    required this.wordmark,
    required this.streakDays,
    required this.streakSemanticLabel,
    required this.initials,
    required this.avatarSemanticLabel,
    required this.avatarUnavailableReason,
    required this.onAvatarTap,
    this.streakFailureMessage,
    this.onRetryStreak,
    super.key,
  });

  /// The product's name. `ds.tsx:508` writes it as a literal; here it is passed, so
  /// a second wordmark in the app is a change at the call site rather than a second
  /// constant.
  ///
  /// **And it is read.** That was the gap: this parameter was `required`, and
  /// `build` rendered `Text(wordmark)` — but no test asserted the rendered text was
  /// the one passed, so hard-coding `Text('Evangelion')` here and ignoring the
  /// argument passed all 1520 tests. Requiredness guarantees the parameter *exists*;
  /// only a render-time assertion guarantees it is used. `app_top_bar_test.dart`
  /// passes a sentinel no product would want and asserts it is what appears.
  final String wordmark;

  /// The streak, from `StreakSummary.currentStreak` — **the streak endpoint's copy**.
  /// `null` while it is unknown or failed; see [streakFailureMessage].
  final int? streakDays;

  /// The announcement's prefix for [streakDays].
  final String streakSemanticLabel;

  /// Why the streak could not be read, or `null`.
  final String? streakFailureMessage;

  /// What to run when the reader asks for the streak again.
  final VoidCallback? onRetryStreak;

  /// The avatar's monogram, from `AuthSession.initials`.
  final String initials;

  /// The avatar's accessible name.
  ///
  /// `ds.tsx:519-526`'s `<button>` has **no** label at all — §14's first row, and
  /// the reason `IconActionButton.tooltip` is required. So the name is passed, and
  /// `HomePage` passes the reader's display name, falling back to
  /// `AppLocalizations.homeAvatarLabel` when there is no session.
  final String avatarSemanticLabel;

  /// Appended to [avatarSemanticLabel] while the avatar is inert.
  ///
  /// **A parameter and not a constant here**, because a second copy of
  /// `AppLocalizations.homeUnavailableSuffix` in a widget would be a second place to
  /// translate one sentence and `home_strings_test.dart` only checks the table.
  /// Required, so a caller cannot leave an inert button whose name gives no reason.
  final String avatarUnavailableReason;

  /// What to run when the reader presses the avatar.
  ///
  /// ## IT WAS `null` FOR FOUR PHASES AND **PHASE 9 MADE IT LIVE**
  ///
  /// The prototype navigates to `profile` and AGENT_CONTEXT §2 decision 1 **cut** the
  /// profile screen, so for four phases this was `null`, the avatar was rendered
  /// **disabled**, and [avatarUnavailableReason] was appended to its accessible name
  /// so a screen-reader user was told why. The parameter stays nullable — the
  /// disabled arm is still the correct rendering for a control with no destination,
  /// and `app_top_bar_test.dart` still exercises it.
  ///
  /// What changed is that **`HomePage` now passes a destination**: `/settings`, which
  /// is the nearest live route and the one the phase plan names ("`AppTopBar`'s avatar
  /// tap now opens `/settings`"). The earlier text here said inventing that would "be a
  /// product decision this phase may not make" — correct then, because there was no
  /// `/settings` to navigate to; the decision was made by the phase plan and this is
  /// its implementation, not a fresh product call.
  ///
  /// **The unavailable-reason suffix stops being appended** while the control is
  /// enabled, which is `build`'s `enabled ? avatarSemanticLabel : '… — …'` — so a
  /// reader who taps the avatar and is told "unavailable in this build" cannot happen.
  final VoidCallback? onAvatarTap;

  /// `ds.tsx:514` — `gap: 14` between the streak group and the avatar.
  static const double trailingGap = 14;

  /// The wordmark's tracking. `ds.tsx:507` — `letterSpacing: '-0.01em'`.
  static const double wordmarkLetterSpacing = -0.01;

  /// The avatar's visible diameter. `ds.tsx:520` — `width: 32, height: 32`.
  static const double avatarDiameter = 32;

  /// The avatar's tap and focus box. See the class doc.
  static const double avatarTapTarget = 44;

  /// The avatar's rim width. `ds.tsx:522` — `outline: 1.5px solid`.
  static const double avatarRimWidth = 1.5;

  /// The avatar rim's alpha. See the class doc's colour note — the prototype's is
  /// `rgba('#14B8A6', isDark ? 0.4 : 0.6)` and that hue is not a token.
  static const double avatarRimAlpha = 0.35;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool enabled = onAvatarTap != null;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            wordmark,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              // `ds.tsx:506` — `F.display, 24, 600, ink`. `headlineSmall` is 24sp in
              // Material 3, which is the prototype's number exactly; see
              // `eva_typography.dart` for why the sizes come from the SDK.
              fontWeight: FontWeight.w600,
              color: colors.ink,
              letterSpacing: wordmarkLetterSpacing,
            ),
          ),
        ),
        StreakFlameRow(
          days: streakDays,
          semanticLabel: streakSemanticLabel,
          failureMessage: streakFailureMessage,
          onRetry: onRetryStreak,
        ),
        const SizedBox(width: trailingGap),
        // The 44-wide box around the 32 circle. `Center` so the visible badge
        // stays centred in it, which is what keeps the rendered bar identical to
        // the prototype's.
        SizedBox(
          width: avatarTapTarget,
          height: avatarTapTarget,
          child: Center(
            child: _Avatar(
              initials: initials,
              semanticLabel: enabled
                  ? avatarSemanticLabel
                  : '$avatarSemanticLabel — $avatarUnavailableReason',
              enabled: enabled,
              onTap: onAvatarTap,
            ),
          ),
        ),
      ],
    );
  }
}

/// The round monogram badge. `ds.tsx:519-526`.
///
/// Private so the only way to draw one is through [AppTopBar], which is what makes
/// `AppTopBar`'s "no defaults" claim enforceable: there is no other spelling of an
/// avatar in this feature.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final String initials;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    final Widget badge = Container(
      width: AppTopBar.avatarDiameter,
      height: AppTopBar.avatarDiameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // The prototype's gradient, in this design system's ink ramp. See
        // `AppTopBar`'s colour section for why the hue is not the prototype's.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.ink.withValues(alpha: 0.92), colors.ink3],
        ),
        border: Border.all(
          color: colors.ember.withValues(alpha: AppTopBar.avatarRimAlpha),
          width: AppTopBar.avatarRimWidth,
        ),
      ),
      child: Text(
        initials,
        // `ds.tsx:525` — `F.ui 11 / 700`, white on dark in the dark palette and
        // `#120E28` on light. `canvas` is the nearest token that is legible on the
        // ink ramp in **both** palettes, which is the property the prototype's
        // two-value conditional was reaching for.
        style: Theme.of(context).textTheme.labelMedium!
            .copyWith(fontWeight: FontWeight.w700, color: colors.canvas),
      ),
    );

    if (!enabled) {
      // No focus ring, no tap, and the name carries the reason. Same shape as
      // `SocialAuthButton`: an inert control that explains itself.
      return Semantics(
        button: true,
        enabled: false,
        label: semanticLabel,
        excludeSemantics: true,
        child: Opacity(opacity: 0.45, child: badge),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      // `excludeSemantics: true` drops the `InkWell`'s tap action along with the
      // badge's own subtree, so the action has to be re-attached — the same trap
      // `IconActionButton` documents.
      onTap: onTap,
      child: EvaFocusRing(
        enabled: true,
        idleBorder: null,
        // Circular, so the ring is a circle. `EvaFocusRing`'s default radius is a
        // button's 14, which on a 32px badge would draw a squircle inside a circle.
        radius: AppTopBar.avatarDiameter / 2,
        child: EvaInk(
          onPressed: onTap,
          borderRadius: BorderRadius.circular(AppTopBar.avatarDiameter / 2),
          child: badge,
        ),
      ),
    );
  }
}
