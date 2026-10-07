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
/// Because a card three rows tall cannot afford a screen's worth of furniture — see
/// [_EmptyStandIn] for what it draws instead.
///
/// ## A CORRECTION: THIS DOC ONCE CLAIMED THE EMPTY BOARD WAS THE ONLY REACHABLE STATE
///
/// It said the card renders "the same widget `/leaderboard` uses", naming a class
/// called `LeaderboardEmptyState` that **does not exist anywhere in `lib/`**, and
/// justified itself by asserting the leaderboard is always empty in development.
///
/// Both halves were wrong. `/leaderboard` uses the design system's `EmptyState`, not
/// this card's private `_EmptyStandIn`, so the two were never the same widget. And the
/// backend's `InMemoryRedisFallback` **constructor pre-seeds three children into group
/// 3** unless `NODE_ENV` is exactly `test` (`src/redis/client.ts:5-33`), so a dev
/// server answers with three real rows and the reader at **rank 2**.
///
/// The claim survived because it was written from **one** `curl` that returned
/// `total_ranked: 0` and never re-probed — see AGENT_CONTEXT decision 143. The lesson
/// generalises past this widget: *an empty response is a fact about a process, never a
/// property of a system.*
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
    // Read once for both runs below, for the reason `LeaderboardRowTile` records:
    // these are the **app's own** strings — a caption from the table and a rank the
    // reader is looking for — so the ambient direction is the only arm there is.
    //
    // **Without this the Arabic arm renders tofu.** `monoCaps` is `SpaceMono`, a
    // Latin-only face, so the card's title came out as one box per character; the
    // two `bodySmall`/`bodyMedium` runs below it came out in `DMSans`, which is not
    // the Arabic face either. `arabic_typography_test.dart` caught all four the
    // moment this card was placed on `/`.
    final TextDirection direction = Directionality.of(context);

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
                  style: arabicAware(
                    EvaTypography.monoCaps(colors).copyWith(color: colors.ink3),
                    direction,
                  ),
                ),
                const SizedBox(height: EvaSpacing.xs),
                Text(
                  // "You are 3rd of 12" when the size is provable, and **just** "3rd"
                  // when it is not. A card that always printed a total would have to
                  // invent one whenever `cohortSize` is `null`, which is precisely when
                  // the list is capped and the total is unknown.
                  _standingLine(context),
                  style: arabicAware(
                    text.bodyMedium?.copyWith(color: colors.ink2) ??
                        DefaultTextStyle.of(context).style,
                    direction,
                  ),
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
    // Same reason as `_Header`: these two runs were `DMSans` on the Arabic arm.
    final TextDirection direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.leaderboardEmptyTitle,
          style: arabicAware(
            text.bodyMedium?.copyWith(color: colors.ink2) ??
                DefaultTextStyle.of(context).style,
            direction,
          ),
        ),
        const SizedBox(height: EvaSpacing.xs),
        Text(
          context.l10n.leaderboardEmptyBody,
          style: arabicAware(
            text.bodySmall?.copyWith(color: colors.ink3) ??
                DefaultTextStyle.of(context).style,
            direction,
          ),
        ),
      ],
    );
  }
}
