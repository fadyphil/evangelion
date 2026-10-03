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
