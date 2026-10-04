import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// "That did not work, and here is the way to try again."
///
/// **The prototype has neither this widget nor [EmptyState]** —
/// `04-widget-inventory.md` §6 says so, and it is true: `eva/src` contains no
/// error state at all, because the prototype has no data layer that can fail.
/// Every screen renders a hardcoded payload, so there was nothing to design a
/// failure for.
///
/// ## WHY IT IS NOT AN `EmptyState` WITH AN ERROR COLOUR
///
/// Because an error is a **different kind of state**, and §14's colour-only rule
/// is about exactly this: `EmptyState` is `ink3`/`ink2` and says nothing is here
/// yet, which is a normal condition. An error is abnormal, it needs an icon that
/// differs in *shape* from an empty state's, it needs `Semantics(liveRegion:)` so
/// a screen reader announces it when it arrives, and it must offer a retry. Those
/// are four differences, not a palette swap, and a single widget parameterised by
/// colour would have hidden all four.
///
/// ## AND WHY THE MESSAGE IS NOT INVENTED HERE
///
/// [message] is required and has no default. The failure messages this app
/// shows come from `ApiErrorMapper` in `core/network` — Phase 5 built it, and its
/// `Failure.message` is deliberately the only source, so a second English string
/// invented in the design system would be a second thing to translate and a third
/// thing to keep in step with the mapper. The mapper is unit-tested against
/// bodies captured from the live server, so a wording change in `error_view.dart`
/// would break a test rather than silently fork the vocabulary.
class ErrorView extends StatelessWidget {
  /// An error view saying [message], optionally offering [onRetry].
  const ErrorView({
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.retryFamily,
    super.key,
  });

  /// What went wrong, in the mapper's words.
  final String message;

  /// What to run when the reader asks to try again. `null` hides the action —
  /// right for an error that retrying cannot fix, such as a malformed response.
  final VoidCallback? onRetry;

  /// The action's label. Required whenever [onRetry] is set.
  ///
  /// A parameter rather than a literal because the app is bilingual and there is
  /// no string table yet; a hard-coded English string in the design system is the
  /// half-translated UI Phase 5 exists to prevent. [assert]ed rather than
  /// defaulted, because an unlabelled button is the §14 gap this file exists to
  /// close.
  final String? retryLabel;

  /// The family [retryLabel] renders in.
  ///
  /// ## WHY A TIER-2 WIDGET HAS TO KNOW ABOUT SCRIPT, AND WHAT THAT COST
  ///
  /// `EvaButton.labelFamily` is **required** — recorded decision 66 says it is and
  /// the parameter was optional, which is the W1 finding: a nullable knob means the
  /// compiler is silent at every call site that forgets it, and the value it falls
  /// back to is `titleMedium`'s, which is **DM Sans**, which carries no Arabic at
  /// all. So "required" propagated here, and a design-system widget cannot be asked
  /// for a locale it does not resolve — the alternative, resolving the arm from
  /// `Localizations` inside `EvaButton`, is what `EvaButton`'s own doc rejects.
  ///
  /// **[retryLabel] is the app's own localized string, so this is not defensive.**
  /// Both shipped call sites pass `ReadingStrings.of(locale).retry` /
  /// `HomeStrings.of(locale).retry`, and on the Arabic arm that is Arabic text
  /// going into a button whose only family knob is this one.
  ///
  /// Nullable-and-[assert]ed rather than required, and that is **not** a retreat from
  /// requiredness: Dart cannot express "required only when `onRetry` is set", and
  /// [retryLabel] — the same shape of obligation on the same button — is already
  /// handled this way. The [assert] in [build] is what turns the omission into a
  /// debug crash rather than a tofu box in production.
  final String? retryFamily;

  /// The icon's box. See [EmptyState.iconBox]; no prototype value.
  static const double iconBox = EvaSpacing.huge * 2;

  /// The icon's size inside that box.
  static const double iconSize = EvaSpacing.xxxl + EvaSpacing.md;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    assert(
      onRetry == null || retryLabel != null,
      'an ErrorView with a retry action needs a retryLabel — an unlabelled '
      'button is the §14 gap this widget exists to close',
    );
    // **Paired with [retryLabel], and for the same reason with the opposite
    // failure.** A retry label is the app's own localized string, so on the Arabic
    // arm it needs Amiri; without this the button falls back to `titleMedium`'s
    // family and renders six tofu boxes on the one screen where something has
    // already gone wrong.
    assert(
      onRetry == null || retryFamily != null,
      'an ErrorView with a retry action needs a retryFamily — `EvaButton'
      '.labelFamily` is required, and the label it renders is localized',
    );

    return Semantics(
      // A failure that arrives after the screen has settled has to be announced,
      // or a screen-reader user finds out from the retry button being there.
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(EvaSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: iconBox,
                  height: iconBox,
                  child: Icon(
                    // A warning triangle, not a plain circle: the shape differs
                    // from [EmptyState]'s icon, so the two states are told apart
                    // without colour — §14's rule, applied by form.
                    Icons.error_outline,
                    size: iconSize,
                    // `err` is the token §5.1 reserves for exactly this, and it
                    // is paired with the shape and the live region, so it is never
                    // the only signal.
                    color: colors.err,
                  ),
                ),
                const SizedBox(height: EvaSpacing.lg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  // `titleMedium` rather than a display slot, for the reason
                  // [EmptyState.titleStyle] gives: 57sp at 1.22× on a 320px screen
                  // is four lines.
                  style: Theme.of(context).textTheme.titleMedium!
                      .copyWith(color: colors.ink),
                ),
                if (onRetry case final VoidCallback retry) ...<Widget>[
                  const SizedBox(height: EvaSpacing.xl),
                  EvaButton(
                    label: retryLabel ?? 'Retry',
                    // `?? EvaTypography.uiFamily` rather than `!`, because the
                    // [assert] above runs in **debug** only and a release build that
                    // reached this line would otherwise fail to compile rather than
                    // render — and `retryLabel ?? 'Retry'` on this line is itself the
                    // English fallback, so the English family is the consistent
                    // answer for it.
                    labelFamily: retryFamily ?? EvaTypography.uiFamily,
                    onPressed: retry,
                    expanded: false,
                    variant: EvaButtonVariant.secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
