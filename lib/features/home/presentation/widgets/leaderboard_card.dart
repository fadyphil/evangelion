import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/home/domain/usecases/load_leaderboard_preview.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Home's compact leaderboard: this week's top rows, and a link to the full list.
///
/// ## WHY IT ASKS FOR FIFTY AND DRAWS THREE
///
/// Not an oversight — see `kLeaderboardPreviewLimit`. The extra rows cost a few
/// kilobytes and buy `cohortSize`, because a cap that did not bind is the only
/// condition under which the cohort's size is provable. A card that asked for exactly
/// three could never say how many children there are.
///
/// ## WHY THE CARD HAS NO EMPTY STATE OF ITS OWN
///
/// It renders [LeaderboardEmptyState] — the same widget `/leaderboard` uses — because
/// the empty board is the **only** reachable state in development (scores enter Redis
/// only through a successful submission, and submission cannot succeed against the
/// memory fallback). Two copies of that copy would be two things to keep in step while
/// being read constantly.
class LeaderboardCard extends StatelessWidget {
  /// The card's body for [status], [board] and [failure].
  const LeaderboardCard({
    required this.status,
    required this.board,
    required this.failure,
    required this.onOpen,
    required this.onRetry,
    super.key,
  });

  /// Which lifecycle arm this is.
  final HomeSectionStatus status;

  /// The ranking, or `null` while loading and after a failure.
  final LeaderboardBoard? board;

  /// Why the request failed, or `null`.
  final Failure? failure;

  /// Opens `/leaderboard`.
  final VoidCallback onOpen;

  /// Re-requests the card.
  final VoidCallback onRetry;

  /// The height reserved while loading, so the card does not grow under the reader.
  ///
  /// Three rows at [LeaderboardRowTile]'s own height, plus the two header rows. A card
  /// that jumps from one line to five is the layout moving, which `today_reading_panel`
  /// records as the reason it reserves a fixed slot while loading.
  static const double loadingHeight = 132;

  @override
  Widget build(BuildContext context) {
    final LeaderboardBoard? ranked = board;
    if (status == HomeSectionStatus.failed) {
      return SizedBox(
        height: loadingHeight,
        child: ErrorView(
          // The failure's **own** message, not a string from the table. The mapper
          // writes "Could not read the leaderboard: `leaderboard[1].score` is …" and
          // inventing a sentence here would hide the field that is actually wrong.
          message: failure?.message ?? '',
          onRetry: onRetry,
          retryLabel: context.l10n.readingRetry,
          // **Required, not defaulted.** `ErrorView` throws without it because
          // `EvaButton.labelFamily` is `required` — the retry label is localized and
          // Arabic needs a family that renders it. Caught by the render test, which is
          // the only kind of test that builds this widget on the failure path.
          retryFamily: Localizations.localeOf(context).languageCode == 'ar'
              ? EvaTypography.arabicFamily
              : EvaTypography.uiFamily,
        ),
      );
    }

    if (ranked == null) {
      return const SizedBox(
        height: loadingHeight,
        child: Center(
          child: SizedBox(
            width: EvaSpacing.xl,
            height: EvaSpacing.xl,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(board: ranked, onOpen: onOpen),
          if (ranked.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: EvaSpacing.md),
              child: _EmptyStandIn(),
            )
          else ...<Widget>[
            const HairlineDivider(),
            // The three the card shows, out of the fifty it asked for.
            for (final LeaderboardRow row in ranked.rows.take(
              kLeaderboardPreviewRows,
            ))
              LeaderboardRowTile(
                row: row,
                isReader:
                    ranked.standing?.rank != null &&
                    ranked.standing!.rank == row.rank,
              ),
          ],
        ],
      ),
    );
  }
}

/// The card's title row and the link to the full list.
class _Header extends StatelessWidget {
  const _Header({required this.board, required this.onOpen});

  final LeaderboardBoard board;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: EvaSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.leaderboardCardTitle,
                  style: EvaTypography.monoCaps(colors)
                      .copyWith(color: colors.ink3),
                ),
                const SizedBox(height: EvaSpacing.xs),
                Text(
                  // "You are 3rd of 12" when the size is provable, and **just** "3rd"
                  // when it is not. A card that always printed a total would have to
                  // invent one whenever `cohortSize` is `null`, which is precisely when
                  // the list is capped and the total is unknown.
                  _standingLine(context),
                  style: text.bodyMedium?.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
          TextLink(
            label: context.l10n.leaderboardOpenFull,
            onPressed: onOpen,
            chevron: true,
          ),
        ],
      ),
    );
  }

  String _standingLine(BuildContext context) {
    final LeaderboardStanding? standing = board.standing;
    if (standing == null || standing.rank == null) {
      return context.l10n.leaderboardUnranked;
    }
    final int? cohort = board.cohortSize;
    return cohort == null ? '${standing.rank}' : '${standing.rank} / $cohort';
  }
}

/// The empty board, in the card's compact form.
///
/// [EmptyState] carries an icon and centres itself, which is a screen's worth of
/// furniture. In a card three rows tall that would push the surrounding layout around,
/// so the card states the same two strings in two lines.
///
/// **The strings are shared, not the widget** — both arms read
/// `leaderboardEmptyTitle` / `leaderboardEmptyBody`, so there is exactly one place the
/// copy can be wrong.
class _EmptyStandIn extends StatelessWidget {
  const _EmptyStandIn();

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.leaderboardEmptyTitle,
          style: text.bodyMedium?.copyWith(color: colors.ink2),
        ),
        const SizedBox(height: EvaSpacing.xs),
        Text(
          context.l10n.leaderboardEmptyBody,
          style: text.bodySmall?.copyWith(color: colors.ink3),
        ),
      ],
    );
  }
}
