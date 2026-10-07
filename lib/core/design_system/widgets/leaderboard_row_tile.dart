import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/design_system/leaderboard_l10n.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One ranked child: position, score, and a monogram in place of a name.
///
/// ## WHY IT LIVES IN THE DESIGN SYSTEM, WHICH IS A REAL COST
///
/// Two features render it — Home's compact card and `/leaderboard`'s full list — and
/// §3 forbids one feature importing another, which `injection_test.dart` Gate 2
/// enforces at the unit level. The design system is this repo's only shared widget
/// home, so that is where it goes.
///
/// **The cost is the import above.** A `core/design_system/widgets/` file that names
/// `core/domain/entities/leaderboard_board.dart` is a design-system widget that knows
/// about one product type, which is exactly what a design system is supposed not to
/// know. It is recorded here rather than hidden because the alternative — two copies of
/// one row design in two features — is a worse defect: two files to change when the row
/// changes, and a card that stops matching the screen it links to.
///
/// If a third feature needs a ranked row, the right answer is a `RankedRow` primitive
/// with no entity in its signature, not a fourth import of this one.

///
/// ## WHY THIS RENDERS A MONOGRAM AND NOT A NAME
///
/// Not a decision this widget makes — `LeaderboardRow` has no `fullName`, so there is
/// nothing to render. See that entity: the requirement is structural, and this row is
/// where it becomes visible.
///
/// ## WHY THE POSITION IS ITS OWN FIXED-WIDTH COLUMN
///
/// Because "3" and "30" are different widths, and a number that reflows as the cohort
/// grows shifts every monogram after it. A reader scanning for their own row is using
/// that column as an axis; letting it breathe destroys the one alignment the list has.
class LeaderboardRowTile extends StatelessWidget {
  /// A row for [row].
  ///
  /// [isReader] marks the reader's own row, which is the only visual difference
  /// between it and anybody else's.
  const LeaderboardRowTile({
    required this.row,
    required this.isReader,
    super.key,
  });

  /// The ranked child.
  final LeaderboardRow row;

  /// Whether this is the reader's own row.
  final bool isReader;

  /// `ds.tsx:462` — the monogram's box. Transcribed, not a token: [EvaSpacing] has no
  /// step between `lg` 16 and `xl` 20 that lands on 30.
  static const double markSize = 30;

  /// `ds.tsx:466` — the rank column.
  static const double rankWidth = 26;

  /// The reader's own row's colour: [EvaColors.ember], the streak flame's.
  ///
  ///
  /// **Inlined as `colors.ember` at each use rather than behind a helper.** A private
  /// `_readerColor()` was tried and `no_colour_literals_test.dart` refused it: the gate
  /// exists to make sure every colour under `lib/` resolves through a published token
  /// table, and a one-line alias is exactly the shape that would let a future colour
  /// arrive without passing it. The gate is right and the helper was the defect.
  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    // The ambient direction, read once — the same helper [StatTile] uses, and for the
    // same reason: a rank and a score are digits and are direction-agnostic, but the
    // reader's own row is a word and must not be forced into one order.
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      // One announcement, not four. Reading "3, PG, 80, points" gives a voice-over
      // user four fragments and no sentence.
      label: strings.leaderboardRowAnnouncement(row, isReader: isReader),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EvaSpacing.sm),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: rankWidth,
              child: Text(
                '${row.rank}',
                textAlign: TextAlign.center,
                style: EvaTypography.monoCaps(colors)
                    .copyWith(color: isReader ? colors.ember : colors.ink2),
              ),
            ),
            const SizedBox(width: EvaSpacing.md),
            Text(
              row.initials,
              textAlign: TextAlign.center,
              style: text.labelLarge!.copyWith(
                color: isReader ? colors.ember : colors.ink2,
                fontWeight: isReader ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: EvaSpacing.md),
            Expanded(
              child: Text(
                isReader ? strings.leaderboardYourRank : '',
                style: arabicAware(
                  text.bodyMedium!.copyWith(
                    color: colors.ember,
                    fontWeight: FontWeight.w700,
                  ),
                  direction,
                ),
              ),
            ),
            Text(
              '${row.score}',
              style: EvaTypography.monoCaps(colors).copyWith(color: colors.ink),
            ),
            const SizedBox(width: EvaSpacing.xs),
            Text(
              strings.leaderboardScoreLabel,
              style: EvaTypography.monoCaps(colors)
                  .copyWith(color: colors.ink2),
            ),
          ],
        ),
      ),
    );
  }
}
