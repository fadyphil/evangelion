import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The streak pill: a flame, the day count, and the word "days".
///
/// `redesign.html:516` inside the `.streak` pill at `:238-241`. One
/// `Semantics` node, the `StreakFlameRow` argument one screen up carried over, and
/// the same three arms.
///
/// ## THE PILL
///
/// `.streak` is `border: 1px solid rgba(232,176,75,.35)`, `border-radius: 99px`,
/// `background: rgba(232,176,75,.06)`, `padding: 7px 14px 7px 11px`, `gap: 9px` and
/// `display: flex`. The gold is [EvaColors.ember] — §5.1 publishes the prototype's
/// `--gold` under that name — and the two alphas are `:238`'s, verbatim.
///
/// [EvaRadii.chip] is `999` where the prototype writes `99`, and the two are the
/// same shape here: a pill's radius only has to be at least half its longest side,
/// and this box is 33 tall. The token is used rather than a local `99` so that the
/// one place a future author looks for a pill radius is the token table.
///
/// ## THE THREE ARMS, AND WHY THE FAILED ONE IS NOT A PILL
///
/// * **`days` is non-null** — the pill, with the number in the prototype's
///   `.sn` (`F.scr 17 / 600 / gold / line-height 1`) and the unit in its `.sl`
///   (`F.mono 8.5 / .14em / uppercase / --ink-1`).
/// * **[failureMessage] is not null** — an [IconActionButton] whose tooltip and
///   accessible name are the repository's own sentence, for
///   `StreakFlameRow`'s reason: a `Failure.message` is backend wording
///   (`api_error_mapper.dart`: `decoded?.message ?? 'HTTP $status'`) and does not
///   belong in a capsule where a count belongs.
/// * **neither** — nothing is drawn. No spinner: the answer is milliseconds away
///   and a spinner would make §13's reduced-motion requirement apply to the pill for
///   no reason; no placeholder flame at `0`: that is the hard-coded value this whole
///   widget exists to remove.
///
/// ## AND NO SPACE IS RESERVED FOR THE MISSING ARMS
///
/// `StreakFlameRow` reserved `flameSize × aspect` for its loading arm, because it
/// sat in the middle of a bar where a wider row would have pushed the avatar right.
/// This chip is the **right-hand** member of a `space-between` row, so nothing to
/// its left depends on its width and there is nothing to reserve. Recorded because
/// "the old widget reserved space" reads as a house rule until a reader sees the
/// row it was needed for.
///
/// ## ONE NODE, NOT THREE
///
/// `StreakFlame` publishes its own node and the count and the unit are sibling
/// `Text`s, so a naive transcription gives a screen reader three announcements to
/// reassemble — and §14's colour-only rule is about exactly that shape. So this is
/// a single `Semantics(container: true, excludeSemantics: true)` carrying
/// `'{label}: {days} {days}'`, and the flame's own node is dropped by the
/// exclusion. `home_accessibility_test.dart` walks the tree and asserts exactly one
/// node offers the streak.
class StreakChip extends StatelessWidget {
  /// The pill for [days] — or a retry control while [failureMessage] is not.
  ///
  /// Three arms and no `isLoading` flag, for `StreakFlameRow`'s reason: the three
  /// are distinguishable and a boolean pair would make "loading and failed at once"
  /// expressible.
  const StreakChip({
    required this.days,
    required this.semanticLabel,
    required this.daysLabel,
    this.failureMessage,
    this.onRetry,
    super.key,
  });

  /// The streak length from `StreakSummary.currentStreak`, or `null` while it is
  /// unknown.
  final int? days;

  /// The announcement's prefix for [days] — `Streak`, and its Arabic pair.
  final String semanticLabel;

  /// The painted unit — `days` / `أيام`, uppercased under LTR only.
  ///
  /// **The same string is in the announcement**, because the pill's own `.sl` is
  /// dropped by `excludeSemantics` and a number with no unit is the one thing a
  /// reader is likely to repeat back. The Arabic arm therefore reads
  /// `أيام متتالية: ١٢ أيام`, which repeats the word; the prototype's own `I18N` has
  /// the same collision in `streakSub` (`:934`) and solves it by not naming the
  /// prefix.
  final String daysLabel;

  /// The streak could not be read, and this is the repository's own message.
  final String? failureMessage;

  /// What to run when the reader asks to try again.
  final VoidCallback? onRetry;

  /// The flame's height. `redesign.html:242` — `.flame{width:13px;height:17px}`.
  ///
  /// The **height** is the prototype's and the width is this widget's to compute:
  /// `StreakFlame`'s own doc records that Phase 5.2 adopts the 17 and keeps the
  /// viewBox's `16 / 20` ratio, which makes the rendered width **13.6** against the
  /// CSS's 13. The constant is here so the number is transcribed once.
  static const double flameSize = 17;

  /// The gap between the three children. `redesign.html:238` — `gap: 9px`, and it
  /// is one declaration for the flame/number/unit trio rather than two.
  static const double gap = 9;

  /// The pill's padding. `redesign.html:238` — `7px 14px 7px 11px`, written
  /// top/right/bottom/**left**, so the leading pad is 11 and the trailing 14.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(11, 7, 14, 7);

  /// The rim's alpha. `redesign.html:238` — `rgba(232,176,75,.35)`.
  static const double rimAlpha = 0.35;

  /// The fill's alpha. `redesign.html:238` — `rgba(232,176,75,.06)`.
  static const double fillAlpha = 0.06;

  /// The number's size. `redesign.html:247` — `.streak .sn{font-size:17px}`.
  static const double numberSize = 17;

  /// The unit's size. `redesign.html:248` — `.streak .sl{font-size:8.5px}`.
  static const double unitSize = 8.5;

  /// The unit's tracking. `redesign.html:248` — `letter-spacing: .14em`.
  static const double unitTracking = 0.14;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final int? count = days;

    if (count != null) {
      return Semantics(
        container: true,
        label: '$semanticLabel: $count $daysLabel',
        excludeSemantics: true,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.ember.withValues(alpha: fillAlpha),
            borderRadius: const BorderRadius.all(
              Radius.circular(EvaRadii.chip),
            ),
            border: Border.all(color: colors.ember.withValues(alpha: rimAlpha)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StreakFlame(
                size: flameSize,
                // Dropped by `excludeSemantics` above; it is still the right name
                // for the widget that draws it.
                semanticLabel: semanticLabel,
              ),
              const SizedBox(width: gap),
              // `.sn` — `F.scr 17 / 600 / gold / line-height 1`. The numeral is this
              // arm's own: `N()` at `redesign.html:981` renders Arabic-Indic digits
              // on the Arabic arm, and `l10n.dart`'s `digits` is the same function.
              //
              // **`arabicAware`, and the first version was the tofu the gate
              // exists to catch.** The numeral on the Arabic arm is `٠`–`٩`
              // (U+0660–0669), and `scriptureFamily` is EB Garamond, whose
              // measured Arabic coverage is **zero** glyphs — the same measurement
              // `arabic_typography_gate.dart`'s doc opens with. The prototype gets
              // away with `F.scr` on that arm because a *browser* falls back
              // per character and this client does not, so the Arabic arm's
              // numerals render in Amiri, which carries them.
              Text(
                context.l10n.digits(count),
                style: arabicAware(
                  EvaTypography.textTheme(colors).headlineSmall!.copyWith(
                    fontFamily: EvaTypography.scriptureFamily,
                    fontSize: numberSize,
                    fontWeight: FontWeight.w600,
                    color: colors.ember,
                    height: 1,
                  ),
                  Directionality.of(context),
                ),
              ),
              const SizedBox(width: gap),
              // `.sl` — `F.mono 8.5 / .14em / uppercase / --ink-1`. `--ink-1` is the
              // prototype's middle ink and `EvaColors` has no name for it; `ink2`
              // stands for it, which `stat_tile.dart`'s doc argues for this same
              // declaration (`redesign.html:408`) and why (`ink3` is 1.65:1 on dark
              // glass where `ink2` is 4.73:1).
              //
              // `arabicAware`, and the tracking is dropped on the Arabic arm:
              // `[dir=rtl] .mono{letter-spacing:0}` (`redesign.html:135`) is the
              // prototype's own rule, and tracking on a cursive script pulls the
              // joined letterforms apart.
              Text(
                monoCapsText(daysLabel, Directionality.of(context)),
                style:
                    arabicAware(
                      EvaTypography.monoCaps(colors).copyWith(
                        fontSize: unitSize,
                        letterSpacing: unitTracking,
                        color: colors.ink2,
                      ),
                      Directionality.of(context),
                    ).copyWith(
                      letterSpacing:
                          Directionality.of(context) == TextDirection.rtl
                          ? 0
                          : unitTracking,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final String? message = failureMessage;
    if (message != null) {
      // An icon control rather than a pill with a dash in it, for
      // [StreakFlameRow]'s reason: the message is the backend's sentence and the
      // pill's job is to hold a count.
      return IconActionButton(
        icon: Icons.sync_problem_outlined,
        tooltip: message,
        tooltipFamily: arabicAwareFamily(
          Directionality.of(context),
          EvaTypography.uiFamily,
        ),
        onPressed: onRetry,
      );
    }

    return const SizedBox.shrink();
  }
}
