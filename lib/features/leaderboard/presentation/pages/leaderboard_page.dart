import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The cohort's standings for a chosen window.
@RoutePage()
class LeaderboardPage extends StatelessWidget {
  /// The full ranking.
  ///
  /// [cubit] is `null` in production, which means "resolve [LeaderboardCubit] from the
  /// locator". A parameter rather than only a lookup because a widget test cannot
  /// reach the locator without configuring the whole graph — the same arrangement as
  /// `ReadingPage.cubit` and `HomePage.bloc`.
  ///
  /// **Substitution, not initialisation.** A passed-in cubit is loaded exactly as the
  /// locator's is; see [_LeaderboardBody].
  const LeaderboardPage({super.key, this.cubit});

  /// The cubit to render.
  final LeaderboardCubit? cubit;

  @override
  Widget build(BuildContext context) {
    // Two sources for one cubit, one provider either way — see [cubit].
    final LeaderboardCubit? passed = cubit;
    final LeaderboardCubit resolved = passed ?? getIt<LeaderboardCubit>();

    return BlocProvider<LeaderboardCubit>.value(
      value: resolved,
      child: const _LeaderboardBody(),
    );
  }
}

class _LeaderboardBody extends StatefulWidget {
  const _LeaderboardBody();

  @override
  State<_LeaderboardBody> createState() => _LeaderboardBodyState();
}

class _LeaderboardBodyState extends State<_LeaderboardBody> {
  LeaderboardWindow? _requested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loads once per window, not once per build. `_requested` is what makes "dispatch
    // `load` in `didChangeDependencies`" safe — without it this would fire on every
    // inherited-widget change, which `reading_page.dart` records as the reason it
    // guards its own dispatch the same way.
    if (_requested == null) _load();
  }

  void _load() {
    final LeaderboardCubit cubit = context.read<LeaderboardCubit>();
    _requested = cubit.state.window;
    cubit.load(_requested!);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (BuildContext context, LeaderboardState state) => NeuralScaffold(
        variant: NeuralVariant.home,
        scrollable: true,
        padding: const EdgeInsets.symmetric(
          horizontal: EvaSpacing.screenHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: EvaSpacing.xxl),
            _WindowPicker(
              selected: state.window,
              onChanged: (LeaderboardWindow window) =>
                  context.read<LeaderboardCubit>().load(window),
            ),
            const SizedBox(height: EvaSpacing.xxl),
            _body(context, state),
          ],
        ),
      ),
    );
  }

  /// The window's ranking, the failure, or nothing yet.
  ///
  /// **A `switch` over the enum and then a pattern over the payload**, and no
  /// `if`-chain: §4 asks for exhaustive `switch` expressions for state branching, and
  /// the enum arm means a fourth `LeaderboardStatus` is a compile error here rather
  /// than a blank panel.
  Widget _body(
    BuildContext context,
    LeaderboardState state,
  ) => switch (state.status) {
    LeaderboardStatus.failed => ErrorView(
      // The failure's **own** message, verbatim. The mapper writes "Could not read the
      // leaderboard: `leaderboard[1].score` is …" and inventing a sentence here would
      // hide the field that is actually wrong.
      message: state.failure?.message ?? '',
      onRetry: () => context.read<LeaderboardCubit>().retry(),
      retryLabel: context.l10n.readingRetry,
      // **Required, and asserted rather than defaulted.** `ErrorView` throws without
      // it: `EvaButton.labelFamily` is `required` because the retry label is
      // localized and Arabic needs a family that renders it. Caught by the render
      // test — the screen builds fine and only asserts on the fifth frame, which
      // is exactly the class of defect a build cannot see.
      //
      // Follows the ambient locale rather than a hard-coded family, the same
      // `arabicAware` reasoning `StatTile` uses: a reader whose app is in Arabic
      // gets the Arabic family whichever way this screen was reached from.
      retryFamily: Localizations.localeOf(context).languageCode == 'ar'
          ? EvaTypography.arabicFamily
          : EvaTypography.uiFamily,
    ),
    LeaderboardStatus.loading ||
    LeaderboardStatus.ready => switch (state.board) {
      // The two arms fall through to the list, which reads `state.board` and renders
      // nothing while it is `null` — a `loading` screen and a `ready` screen with no
      // rows are the same tree, and saying so keeps the enum switch exhaustive without
      // a duplicated arm.
      null => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      final LeaderboardBoard board => _rows(context, board, state.window),
    },
  };

  Widget _rows(
    BuildContext context,
    LeaderboardBoard board,
    LeaderboardWindow window,
  ) {
    if (board.rows.isEmpty) {
      // The measured state of this endpoint, not an error. `EmptyState` is the
      // design system's own, so Home's card and this screen reach for the same widget
      // rather than one importing the other's — `injection_test.dart` Gate 2 forbids
      // that, and a second copy of this copy would be two things to keep in step.
      return EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: context.l10n.leaderboardEmptyTitle,
        message: context.l10n.leaderboardEmptyBody,
      );
    }

    // For the Arabic arm, for the reason `LeaderboardRowTile` records: the heading is
    // the app's own string and `titleMedium` is `DMSans`, which cannot render Arabic.
    final TextDirection direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          // The window comes from the **response**, so this heading cannot disagree
          // with the rows under it — the failure `LeaderboardBoard.window` exists to
          // prevent, and it is prevented here rather than trusted from the request.
          _titleFor(context, window),
          style: arabicAware(
            Theme.of(context).textTheme.titleMedium!,
            direction,
          ),
        ),
        const SizedBox(height: EvaSpacing.md),
        for (final LeaderboardRow row in board.rows)
          LeaderboardRowTile(
            row: row,
            // The reader's own row is identified by **position**, not by identity.
            // `userId` is deliberately not on `LeaderboardRow`, so this is the only
            // comparison available — and it is the right one, because the server's
            // rank is what the reader is looking for.
            isReader:
                board.standing?.rank != null &&
                board.standing!.rank == row.rank,
          ),
        const SizedBox(height: EvaSpacing.xl),
        _StandingFooter(board: board),
      ],
    );
  }

  String _titleFor(BuildContext context, LeaderboardWindow window) =>
      switch (window) {
        LeaderboardWindow.weekly => context.l10n.leaderboardWindowWeekly,
        LeaderboardWindow.monthly => context.l10n.leaderboardWindowMonthly,
        LeaderboardWindow.allTime => context.l10n.leaderboardWindowAllTime,
      };
}

/// The window picker.
///
/// **A `SegmentedControl` over `LeaderboardWindow.values`,** so a fourth window added
/// to the enum appears here without this file being edited — and the mapping from enum
/// to words is an exhaustive `switch`, so it would not compile until it were given one.
class _WindowPicker extends StatelessWidget {
  const _WindowPicker({required this.selected, required this.onChanged});

  final LeaderboardWindow selected;
  final ValueChanged<LeaderboardWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    return SegmentedControl<LeaderboardWindow>(
      values: LeaderboardWindow.values,
      selected: selected,
      labelOf: (LeaderboardWindow window) => switch (window) {
        LeaderboardWindow.weekly => strings.leaderboardWindowWeekly,
        LeaderboardWindow.monthly => strings.leaderboardWindowMonthly,
        LeaderboardWindow.allTime => strings.leaderboardWindowAllTime,
      },
      onChanged: onChanged,
      semanticLabel: strings.leaderboardTitle,
    );
  }
}

/// The reader's own line, under the list.
///
/// ## WHY IT IS HERE AND NOT ONLY IN THE LIST
///
/// Because the reader's row is found by **rank**, and a list of fifty is a poor place
/// to look for "where am I". On the card the reader is usually inside the three rows
/// drawn; on this screen they usually are not.
class _StandingFooter extends StatelessWidget {
  const _StandingFooter({required this.board});

  final LeaderboardBoard board;

  @override
  Widget build(BuildContext context) {
    final LeaderboardStanding? standing = board.standing;
    final EvaColors colors = context.colors;

    final TextDirection direction = Directionality.of(context);
    if (standing == null || standing.rank == null) {
      return Text(
        context.l10n.leaderboardUnranked,
        style: arabicAware(
          Theme.of(context).textTheme.bodyMedium!.copyWith(color: colors.ink2),
          direction,
        ),
      );
    }

    final int? cohort = board.cohortSize;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            context.l10n.leaderboardYourRank,
            style: arabicAware(
              Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: colors.emberInk,
                fontWeight: FontWeight.w700,
              ),
              direction,
            ),
          ),
        ),
        Text(
          // `cohortSize` is `null` whenever the request's `limit` bound, and then the
          // total is genuinely unknown — so the two states render differently rather
          // than one of them inventing a number.
          cohort == null ? '${standing.rank}' : '${standing.rank} / $cohort',
          style: EvaTypography.monoCaps(colors).copyWith(color: colors.ink),
        ),
      ],
    );
  }
}
