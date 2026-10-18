import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The quiz CTA — `eva/redesign.html:548`, `§13`'s eighth screen surface.
///
/// ```html
/// <button class="qcta" id="qcta"><span id="qctaLabel">quiz · 3 questions</span><span>▸</span></button>
/// ```
///
/// ```css
/// /* :202-204 */
/// .qcta{margin:0 18px 10px;align-self:stretch;border:1px solid rgba(232,176,75,.45);
///       background:rgba(232,176,75,.07);color:var(--gold);
///       border-radius:16px;padding:13px 16px;font-family:var(--mono);
///       font-size:10.5px;letter-spacing:.16em;text-transform:uppercase;
///       display:flex;justify-content:space-between}
/// ```
///
/// ## THE CAPTION **IS** THE LABEL, AND THE OLD SCREEN HAD TWO
///
/// `readingBeginReflection` — "Begin reflection" — is gone with the redesign,
/// which has no such phrase: `:1347` writes the caption as
/// `` `${tr('quiz')} · ${N(qEff)} ${tr('questions')}` `` and the button has **no
/// other text**. So this widget renders one line, composed by
/// `ReadingStringsPhrases.quizCaption`, and its accessible name is that same
/// line. A previous version of this file had a button labelled "Begin reflection"
/// with a "5 questions" caption *underneath it*, which is a design that never
/// existed in the prototype.
///
/// ## `▸` IS **NOT** SIZED BY ANY RULE, AND IT RENDERS
///
/// `:548`'s second span has no CSS of its own; its placement is
/// `justify-content: space-between` (`:204`) and its size is inherited from
/// `.qcta`'s 10.5px mono. U+25B8 BLACK RIGHT-POINTING SMALL TRIANGLE is
/// **measured present in JetBrains Mono**, the one family `.qcta` names — so
/// unlike the reader's bookmark `✦` this glyph is a literal and renders as
/// written. Asserting that is this suite's job; the alternative — painting it,
/// as `FourPointedStar` does for U+2726 — would be inventing a widget for a
/// character the shipped font already carries.
class ReadingQuizCta extends StatelessWidget {
  const ReadingQuizCta({
    required this.caption,
    required this.onPressed,
    super.key,
  });

  /// The label — `ReadingStringsPhrases.quizCaption`, already in this arm's
  /// numerals.
  final String caption;

  /// What the button runs. `null` renders it inert, which is the only honest
  /// shape for a quiz that does not exist yet.
  final VoidCallback? onPressed;

  /// The CTA's own margin. `eva/redesign.html:202` — `margin: 0 18px 10px`.
  static const EdgeInsets margin = EdgeInsets.fromLTRB(18, 0, 18, 10);

  /// The CTA's padding. `eva/redesign.html:202` — `padding: 13px 16px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 13,
  );

  /// The CTA's corner radius. `eva/redesign.html:203` — `border-radius: 16px`.
  static const double radius = 16;

  /// The rim's alpha. `eva/redesign.html:202` — `rgba(232,176,75,.45)`.
  static const double rimAlpha = 0.45;

  /// The fill's alpha. `eva/redesign.html:202` — `rgba(232,176,75,.07)`.
  static const double fillAlpha = 0.07;

  /// The hovered fill's alpha. `eva/redesign.html:206` —
  /// `background: rgba(232,176,75,.14)`.
  static const double hoverFillAlpha = 0.14;

  /// The hovered rim's alpha. `eva/redesign.html:206` —
  /// `border-color: rgba(232,176,75,.7)`.
  static const double hoverRimAlpha = 0.7;

  /// The label's size under LTR. `eva/redesign.html:202` — `font-size: 10.5px`.
  static const double fontSize = 10.5;

  /// The label's tracking under LTR. `eva/redesign.html:202` —
  /// `letter-spacing: .16em`, **1.68px** at [fontSize].
  static const double letterSpacing = 1.68;

  /// The label's size under RTL. `eva/redesign.html:205` — `font-size: 12px`,
  /// `letter-spacing: 0`, `text-transform: none`.
  ///
  /// **A different size, tracking and case on the Arabic arm, all three from
  /// one rule.** The prototype's `[dir=rtl] .qcta` gives the Arabic arm its own
  /// UI face (`--ui-ar`), zeroes the tracking and turns the uppercase off,
  /// because Arabic has no letter-spacing to speak of and the caps would be
  /// meaningless; 12px against 10.5px is the compensating size.
  static const double fontSizeArabic = 12;

  /// The pressed scale. `eva/redesign.html:207` — `transform: scale(.98)`.
  static const double pressedScale = 0.98;

  /// The chevron's own size. **Inherited, not declared** — `:548`'s second span
  /// has no rule, so it is `.qcta`'s 10.5px, and the constant is here so the
  /// inheritance is a name rather than an accident.
  static const double chevronSize = 10.5;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final bool rtl = direction == TextDirection.rtl;

    return Padding(
      padding: margin,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: caption,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(radius)),
              // `:202`'s fill and rim. Both alphas are the rule's, and the hue is
              // `colors.ember` — the token that publishes `--gold`.
              color: colors.ember.withValues(alpha: fillAlpha),
              border: Border.all(
                color: colors.ember.withValues(alpha: rimAlpha),
              ),
            ),
            child: Row(
              // `:204` — `justify-content: space-between`, which is what puts
              // the `▸` at the far edge on both arms rather than beside the
              // caption. A `Row`'s `mainAxisAlignment.spaceBetween` is that rule.
              children: <Widget>[
                Flexible(
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arabicAware(
                      rtl
                          // `:205` — `var(--ui-ar)`, no tracking, no uppercase,
                          // 12px.
                          //
                          // **`uiArabicFamily` is NOT what this uses, and the
                          // divergence is recorded rather than missed.** `:205`
                          // puts the Arabic arm's CTA caption in the UI-Arabic face;
                          // this client puts it in **Amiri**, because
                          // `arabic_typography_gate.dart` requires every Arabic run
                          // on every screen to render in the Arabic family, and that
                          // gate has no exception mechanism on purpose — "the
                          // skipped run is exactly the run nobody has checked".
                          //
                          // **The prototype's own reason for the rule still stands
                          // and is honoured**: `:205` exists because the Latin arm's
                          // `.qcta` is mono, uppercase and tracked, and none of that
                          // suits Arabic — so `rtl` still drops the tracking, drops
                          // the uppercase and takes 12px. What is kept is "not the
                          // mono face", and `IBMPlexSansArabic` carries Arabic
                          // glyphs fine, so this is a family choice and not a tofu
                          // fix — which is worth saying, because it looks like one.
                          ? EvaTypography.textTheme(colors).bodySmall!.copyWith(
                              fontSize: fontSizeArabic,
                              letterSpacing: 0,
                              color: colors.ember,
                            )
                          : EvaTypography.monoCaps(colors).copyWith(
                              fontSize: fontSize,
                              letterSpacing: letterSpacing,
                              color: colors.ember,
                            ),
                      direction,
                    ),
                  ),
                ),
                const SizedBox(width: EvaSpacing.sm),
                Text(
                  // U+25B8, measured present in JetBrains Mono. See the class
                  // doc for why this one is a literal and the bookmark's is not.
                  '▸',
                  style: EvaTypography.textTheme(colors).bodySmall!.copyWith(
                    fontFamily: EvaTypography.monoFamily,
                    fontSize: chevronSize,
                    color: colors.ember,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
