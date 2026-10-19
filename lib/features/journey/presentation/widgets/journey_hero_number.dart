import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The hero number and the line under it — `eva/redesign.html:589-590`.
///
/// ```html
/// <div class="hero-num" id="heroNum">12</div>
/// <div class="mono" style="text-align:center;color:var(--ink-1)" data-i18n="streakSub">day streak · keep the flame</div>
/// ```
///
/// ## THE NUMBER IS **REAL**, AND THE PROTOTYPE'S IS NOT
///
/// `:989` writes `el('heroNum').textContent = N(12)` — a literal, recomposed on
/// every language change. This client's is the reader's own current streak, so
/// the digit is [streak] and nothing else. The Arabic arm reads it in
/// Arabic-Indic numerals, which is what `digits` is for.
///
/// ## THE INK, AND WHY IT IS NOT `ember`
///
/// `:399` is `color:var(--gold)` and `:400` carries the
/// `text-shadow:0 0 40px rgba(232,176,75,.45)`.
/// The prototype's `--gold` is `#E8B04B` in dark (`:14`) and `#9A7B19` in light
/// (`:58`), and the light override at `:88` is `color:#8a6d15` with
/// `text-shadow:0 0 30px rgba(154,123,25,.3)`.
///
/// **This client has no gold token**, and the nearest one is `emberInk`:
/// `#E8A33D` in dark and `#845610` in light. That is **not** the same value, and
/// the divergence is recorded rather than hidden:
///
/// | | prototype | here |
/// | --- | --- | --- |
/// | dark ink | `#E8B04B` | `#E8A33D` |
/// | light ink | `#8a6d15` (`:88`) | `#845610` |
/// | dark glow | `rgba(232,176,75,.45)`, 40px | `rgba(232,163,61,.45)`, 40px |
/// | light glow | `rgba(154,123,25,.3)`, 30px | `rgba(132,86,16,.3)`, 30px |
///
/// `emberInk` is the **writing** half of the accent (recorded decision 153:
/// "ember fills, emberInk writes"), and a 64px numeral is writing. The glow
/// takes the same colour because a text-shadow is the text's own colour
/// spreading — the prototype's shadow and its ink are the same hue, and
/// splitting them would paint a glow in a colour the numeral is not.
///
/// ## AND THE NUMERAL'S FAMILY ON THE ARABIC ARM
///
/// `font-family:var(--scr)` is EB Garamond, whose measured Arabic coverage is
/// **zero** glyphs — so an Arabic-Indic digit in it would be a tofu box. The
/// Arabic arm is therefore rendered in Amiri, by [arabicAware]. This is the
/// `streak_chip`'s own arrangement for the same number, and it is why the digit
/// transform and the family swap have to travel together.
class JourneyHeroNumber extends StatelessWidget {
  /// The reader's current streak, in days.
  const JourneyHeroNumber({required this.streak, super.key});

  /// The number the hero shows.
  final int streak;

  /// The number's size — `eva/redesign.html:399`'s `font-size:64px`.
  static const double size = 64;

  /// The number's line height — `eva/redesign.html:400`'s `line-height:1`.
  static const double lineHeight = 1;

  /// The glow's radius in dark — `eva/redesign.html:400`'s `0 0 40px`.
  static const double shadowBlurDark = 40;

  /// The glow's radius in light — `eva/redesign.html:88`'s `0 0 30px`.
  static const double shadowBlurLight = 30;

  /// The glow's alpha in dark — `eva/redesign.html:400`'s `rgba(232,176,75,.45)`.
  static const double shadowAlphaDark = 0.45;

  /// The glow's alpha in light — `eva/redesign.html:88`'s `rgba(154,123,25,.3)`.
  static const double shadowAlphaLight = 0.3;

  /// The gap above the number — `eva/redesign.html:399`'s `margin:6px 0 2px`.
  static const double gapAbove = 6;

  /// The gap below the number — `eva/redesign.html:399`'s `margin:6px 0 2px`.
  static const double gapBelow = 2;

  /// The sub-line's size — `eva/redesign.html:30`'s `font-size:10.5px`, the
  /// `.mono` rule's own size.
  static const double subLineSize = 10.5;

  /// The sub-line's Latin tracking — `eva/redesign.html:30`'s
  /// `letter-spacing:.16em`.
  ///
  /// **Transcribed as the resolved value and not as `em`.**
  /// `TextStyle.letterSpacing` is a **logical-pixel advance** and CSS's `em`
  /// is relative to the element's own font size, so `.16em` at [subLineSize]
  /// (10.5px) is **1.68**. The house's own twin of this rule —
  /// `EvaSectionHeader`'s section label — premultiplies the same `.16em` by
  /// the same 10.5px and arrives at the same number.
  static const double subLineTracking = 1.68;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: gapAbove, bottom: gapBelow),
          child: Text(
            context.l10n.digits(streak),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: arabicAware(
              EvaTypography.textTheme(colors).displayLarge!.copyWith(
                fontFamily: EvaTypography.scriptureFamily,
                fontSize: size,
                fontWeight: FontWeight.w600,
                color: colors.emberInk,
                height: lineHeight,
                shadows: <Shadow>[
                  Shadow(
                    color: colors.emberInk.withValues(
                      alpha: dark ? shadowAlphaDark : shadowAlphaLight,
                    ),
                    blurRadius: dark ? shadowBlurDark : shadowBlurLight,
                  ),
                ],
              ),
              direction,
            ),
          ),
        ),
        // `:590` — `.mono` with an inline `color:var(--ink-1)`, which overrides
        // the `.mono` rule's own `--ink-2` at `:30`. The inline colour wins
        // because it is the later declaration, and `--ink-1` is the house's
        // `ink2`.
        //
        // **The tracking is the resolved 1.68 and not the `.16em`** — see
        // [subLineTracking], which says why.
        Text(
          monoCapsText(context.l10n.journeyStreakSub, direction),
          textAlign: TextAlign.center,
          style: arabicAware(
            EvaTypography.monoCaps(colors).copyWith(
              fontSize: subLineSize,
              letterSpacing: direction == TextDirection.rtl
                  ? 0
                  : subLineTracking,
              color: colors.ink2,
            ),
            direction,
          ),
        ),
      ],
    );
  }
}
