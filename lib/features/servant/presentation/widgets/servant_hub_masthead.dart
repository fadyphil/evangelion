import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The portal's masthead: where the reader is, who they are, and which day it
/// is.
///
/// ## AND WHY IT IS **THREE LINES** AND NOT ONE
///
/// Because the three facts are three different kinds, and the screen has to
/// answer all three before a reader can act on any of them:
///
/// * **the place** — this is the servant portal, and not the reading app;
/// * **the standing** — a viewer servant is offered one section and an admin
///   servant three, so a screen that did not say which role is looking at it
///   could not explain why the cards below differ;
/// * **the day** — the report is *today's* report, and the schedule form picks
///   a day of its own.
///
/// **And the day is last**, because it is the least surprising of the three: a
/// reader who has just signed in knows what day it is, and a reader who has
/// not is looking at a portal that names the day for them.
///
/// ## AND WHY THEY ARE **NOT** ON ONE LINE
///
/// Because the place and the standing are one thought and the day is another,
/// and because the standing and the day **do not fit on one line** at the
/// narrowest surface the app supports.
///
/// **Measured, at 320×568**, in this repository's own fonts, by rendering the
/// masthead and measuring the two runs:
///
/// | text scale | the standing | the day | one line, with the separator |
/// | --- | --- | --- | --- |
/// | 1.0 | 99.8px | 162.1px | **273.8px** |
/// | 1.22 | 121.4px | 196.5px | **330.0px** |
///
/// **And the content column at 320 is 288px** — 320 less the scaffold's
/// **16px** horizontal gutter a side (`NeuralScaffold`'s default padding is
/// `EdgeInsets.symmetric(horizontal: EvaSpacing.lg)`).
///
/// So the pair fits at the default text scale with **14px to spare**, and it
/// is **42px over** at the reader's largest one — which is §14's rule, and the
/// reason the two are on separate lines.
///
/// **A single line would have been the worst kind of defect**: invisible at
/// 390 and at 1.0×, and a truncated line — the reader's own words deleted —
/// at 320 with the reader's font at maximum.
///
/// Stacked, each line is short enough to fit at 320 in **both** arms, and the
/// Arabic arm is the *shorter* one: `الأربعاء، ٢١ أكتوبر` is narrower than
/// `Wednesday, October 21`.
class ServantHubMasthead extends StatelessWidget {
  /// The masthead for the portal.
  const ServantHubMasthead({
    required this.title,
    required this.roleLabel,
    required this.dayLabel,
    super.key,
  });

  /// The portal's own name — the place the reader is.
  final String title;

  /// The reader's standing in it.
  final String roleLabel;

  /// The day, written in the reader's own language.
  final String dayLabel;

  /// The gap between the place and the standing.
  ///
  /// **Written, not transcribed**: `eva/redesign.html` draws no servant portal
  /// and therefore has no masthead to measure. `4` is [EvaSpacing.xs], and it
  /// is a step tighter than the gap below it because the place and the
  /// standing are one thought — *this place, and who you are in it* — while
  /// the day below is a separate fact.
  static const double placeGap = EvaSpacing.xs;

  /// The gap between the standing and the day.
  ///
  /// `2` — tighter still, and the reason is the same one: the standing and
  /// the day are a pair of *metadata*, and the place above them is a heading.
  static const double standingGap = 2;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: arabicAware(
            // **The display serif, and the app's own headline size.**
            // `headlineSmall` is 24 and the greeting on `/` is 23 in the same
            // family (`greeting_block.dart`'s `nameSize`), so the portal's
            // title is the app's own scale and not a number invented here.
            text.headlineSmall!.copyWith(
              fontFamily: EvaTypography.scriptureFamily,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
            direction,
          ),
        ),
        const SizedBox(height: placeGap),
        Text(
          roleLabel,
          style: arabicAware(
            // **The accent, in the accent's own ink.** `emberInk` is the
            // design system's gold that clears AA as a label — 6.97:1 in dark
            // and 5.54:1 in light — and the standing is the one line on this
            // screen that is *about the reader*, so it is the one line that
            // wears the accent.
            text.titleSmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.emberInk,
            ),
            direction,
          ),
        ),
        const SizedBox(height: standingGap),
        Text(
          dayLabel,
          style: arabicAware(
            text.bodyMedium!,
            direction,
          ).copyWith(color: colors.ink2),
        ),
      ],
    );
  }
}
