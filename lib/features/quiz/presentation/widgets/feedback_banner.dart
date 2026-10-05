import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which way an answer went. `FeedbackBanner`'s two variants.
enum FeedbackTone {
  /// A correct answer. `QuizScreen.tsx:105-117` — `hex.ok` throughout.
  ///
  /// **The only variant the prototype has**, and it is the *transcribed* one.
  ok,

  /// A wrong answer.
  ///
  /// **Written, and the inventory asked for it.** `04-widget-inventory.md` line 359
  /// declares `FeedbackBanner({required tone, required message})`, so the shape has
  /// two arms — and the prototype's banner is gated on `checked` while always
  /// painting `ok`, so a reader who got it wrong was shown a **green** banner saying
  /// nothing about why. `ds.tsx` has no second banner to copy, so `err` is this
  /// client's own: [EvaColors.err] in the four places `ok` appears.
  ///
  /// Recorded rather than shipped silently, because "the prototype had one variant
  /// and we have two" is a divergence a reviewer should check.
  err,
}

/// The banner under the options. `QuizScreen.tsx:104-119`.
///
/// ## **NOT** A `GlassSurface`, AND THE INVENTORY SAYS SO IN ITS OWN WORDS
///
/// `04-widget-inventory.md` line 54:
///
/// > "`StickyCta` (`ReadingEnScreen.tsx:80-86`) and the Quiz feedback banner …
/// > look similar but use a solid `linear-gradient` / flat `rgba(ok, 0.1)` fill with
/// > **no** `backdropFilter`. They are separate composites, not `GlassSurface`
/// > instances."
///
/// A `BackdropFilter` is a `saveLayer` plus a full read-back of everything behind it,
/// per frame, and `glass_blur_budget_test.dart`'s ceiling for `lib/features/` is
/// **1** — Home's panel. This file paints no filter, so the budget is untouched and
/// the ceiling stays where Phase 6 moved it.
///
/// ## AND THE ROW IS **NOT** CENTRED EITHER
///
/// `QuizScreen.tsx:107` is `display: 'flex', alignItems: 'center'` with no
/// `justifyContent`, so the dot and the message sit at the **start** of the row, and
/// the banner hugs its text rather than centring it. `mainAxisAlignment` is
/// therefore absent here too, and `quiz_geometry_test.dart` asserts the dot is at
/// the banner's leading edge rather than in the middle of it.
class FeedbackBanner extends StatelessWidget {
  /// A banner saying [message] in [tone]'s treatment.
  const FeedbackBanner({
    required this.tone,
    required this.message,
    this.semanticLabel,
    super.key,
  });

  /// Which way it went.
  final FeedbackTone tone;

  /// What it says. The **caller's** string — `AppLocalizations.quizVerdictCorrect` or
  /// `verdictIncorrect`, and §14's rule plus decision 78's precedent are why: a
  /// hard-coded English string in `core/` is the half-translated UI this app exists
  /// not to ship.
  final String message;

  /// The accessible name, when it must differ from [message].
  ///
  /// `null` by default, which is right: the banner is a `Text` inside the page's own
  /// reading order, and a screen reader already announces it. It exists because
  /// `FocusRing`-wrapped controls in this design system take a separate label, and
  /// **no caller needs it today** — which is recorded rather than left as a knob
  /// nothing turns.
  final String? semanticLabel;

  /// `QuizScreen.tsx:107` — `padding: '12px 16px'`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  /// `QuizScreen.tsx:106` — `borderRadius: 14`. A token: [EvaRadii.input].
  static const double radius = EvaRadii.input;

  /// `QuizScreen.tsx:105` — `marginTop: 14`.
  static const double topGap = EvaSpacing.md;

  /// `QuizScreen.tsx:108` — `gap: 10`.
  static const double gap = EvaSpacing.sm;

  /// `QuizScreen.tsx:114` — `width: 8, height: 8, borderRadius: '50%'`.
  static const double dotSize = 8;

  /// `QuizScreen.tsx:108` — `border: '1px solid rgba(ok, .3)'`.
  static const double borderAlpha = 0.3;

  /// `QuizScreen.tsx:107` — `background: rgba(ok, isDark ? .1 : .08)`.
  static const double darkFillAlpha = 0.1;
  static const double lightFillAlpha = 0.08;

  /// `QuizScreen.tsx:117` — `boxShadow: 0 0 24px rgba(ok, .18)`.
  static const double glowBlur = 24;
  static const double glowAlpha = 0.18;

  /// `QuizScreen.tsx:114` — `boxShadow: 0 0 10px rgba(ok, .8)` on the dot.
  static const double dotGlowBlur = 10;
  static const double dotGlowAlpha = 0.8;

  /// `QuizScreen.tsx:116` — `F.ui, fontSize 14, fontWeight 500`.
  static const double fontSize = 14;

  /// `QuizScreen.tsx:116` — `fontWeight: 500`.
  static const FontWeight fontWeight = FontWeight.w500;

  /// The ink for [tone]. `ds.tsx`'s `ok` / `err`, which `EvaColors` publishes.
  static Color inkFor(FeedbackTone tone, EvaColors colors) =>
      tone == FeedbackTone.ok ? colors.ok : colors.err;

  /// The fill alpha on [brightness]. `QuizScreen.tsx:107`.
  ///
  /// ## **NO `tone` PARAMETER**, AND THE REASON IT WAS DELETED
  ///
  /// This took a `FeedbackTone` and ignored it — `err` and `ok` got the same two
  /// numbers because `ds.tsx` publishes no second banner and inventing a third value
  /// here would be a design decision this file does not own. That reasoning is sound
  /// and it was carried by a **required parameter nothing read**, which is the exact
  /// shape `_StatRow` had in this same phase and which §7's "a parameter every caller
  /// must supply and none of them can act on" is about: the call site passes a value
  /// that means nothing, and a reader cannot tell whether it matters.
  ///
  /// So the parameter is gone and the shared-alpha fact lives here, in the only place
  /// that owns it. If a second banner ever arrives from `ds.tsx`, the alpha comes
  /// back with it — as a value read from the design source, not as a parameter
  /// nothing reads.
  ///
  /// `quiz_geometry_test.dart` asserts the two numbers against `QuizScreen.tsx:107`
  /// and asserts that `build` passes **no** tone — which is what "the parameter is
  /// gone" has to mean if it is to mean anything.
  static double fillAlphaFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkFillAlpha : lightFillAlpha;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color ink = inkFor(tone, colors);
    final Brightness brightness = Theme.of(context).brightness;

    final Widget banner = DecoratedBox(
      decoration: BoxDecoration(
        color: ink.withValues(alpha: fillAlphaFor(brightness)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ink.withValues(alpha: borderAlpha)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ink.withValues(alpha: glowAlpha),
            blurRadius: glowBlur,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: <Widget>[
            // `QuizScreen.tsx:114` — `flexShrink: 0`, so the dot is never
            // squeezed by a long Arabic label at 1.22×.
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: ink,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ink.withValues(alpha: dotGlowAlpha),
                    blurRadius: dotGlowBlur,
                  ),
                ],
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Text(
                message,
                // `QuizScreen.tsx:116` — `F.ui, 14, 500, T.ink`.
                //
                // **The ambient arm, not the payload arm.** This string is the app's
                // own chrome — a sentence the client wrote about the reader's answer
                // — and there is no scripture behind it, so decision 75's table puts
                // it on `arabicAware`. `QuizOptionCard` takes a `ReadingLanguage`
                // and this does not, and the difference is the whole of the seam.
                style: arabicAware(
                  Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: colors.ink,
                  ),
                  Directionality.of(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final String? label = semanticLabel;
    if (label == null) return banner;
    return Semantics(label: label, child: banner);
  }
}
