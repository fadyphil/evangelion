import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/leaderboard/domain/leaderboard_ranking.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_app_bar.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_cheer_toast.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_countdown_line.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_podium.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_segmented_controls.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_you_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Rebuilt `/communion` (the cohort's board) against `eva/redesign.html:612-636`
/// (JS `:1055-1128`, D1-D20).
///
/// ## THE WHOLE PAGE SCROLLS, AND THE PROTOTYPE'S DOES NOT
///
/// The prototype fixes the header, the countdown and the two segmented controls
/// and scrolls only the you-card and the list (`eva/redesign.html:628`'s `.scroll`
/// wrapper). This page scrolls **everything**.
///
/// The reason is the viewport matrix (D16): at 320×568 the prototype's fixed
/// block is about 400px of a 568px-tall screen, so a fixed header would leave
/// roughly 170px for the board itself and the podium alone would fill it. A
/// screen whose whole point is the ranking is better served by letting the
/// ranking move. The prototype's split is a property of a design that assumed a
/// tall desktop window, and it is recorded here rather than silently dropped.
@RoutePage()
class CommunionPage extends StatelessWidget {
  /// Creates the communion page.
  ///
  /// [cubit] allows constructor injection for testing without configuring the locator.
  const CommunionPage({super.key, this.cubit});

  /// The cubit to render, or null to resolve from DI.
  final LeaderboardCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final LeaderboardCubit? passed = cubit;
    final LeaderboardCubit resolved = passed ?? getIt<LeaderboardCubit>();

    return BlocProvider<LeaderboardCubit>.value(
      value: resolved,
      child: const _CommunionBody(),
    );
  }
}

class _CommunionBody extends StatefulWidget {
  const _CommunionBody();

  @override
  State<_CommunionBody> createState() => _CommunionBodyState();
}

class _CommunionBodyState extends State<_CommunionBody> {
  LeaderboardWindow? _requested;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested == null) _load();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _load() {
    final LeaderboardCubit cubit = context.read<LeaderboardCubit>();
    _requested = cubit.state.window;
    cubit.load(_requested!);
  }

  void _showCheerToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    // `SettingsScope.of` resolves the scope first and the locator's registered handle
    // second (`settings_scope.dart`'s doc), and it is a **dependency**, so a change to
    // the veil rebuilds this body. A page that read the value once would keep
    // rendering the un-veiled names after the button was pressed.
    final SettingsHandle handle = SettingsScope.of(context);
    final UserSettings settings = handle.settings;

    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (BuildContext context, LeaderboardState state) {
        return NeuralScaffold(
          variant: NeuralVariant.home,
          scrollable: true,
          padding: EdgeInsets.zero,
          // The viewport-fixed slot — see [_toastOverlay]'s doc for why the
          // toast cannot live in the content column.
          overlay: _toastOverlay(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CommunionAppBar(
                title: strings.leaderboardTitle,
                isVeiled: settings.veilWitnesses,
                onToggleVeil: () {
                  unawaited(
                    handle.setVeilWitnesses(veiled: !settings.veilWitnesses),
                  );
                },
                onBack: () => context.router.maybePop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: EvaSpacing.screenHorizontal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // The countdown is gated on the **response's** window, never
                    // the request's — D10. `LeaderboardBoard.window` exists to
                    // catch a server that ranked a different window than the
                    // one asked for, and a line that counted down to the
                    // *requested* window's boundary while the board underneath
                    // was the *answered* window's would hide exactly that
                    // mismatch. With no board in hand there is nothing to
                    // count down to, so the line renders nothing.
                    if (state.board case final LeaderboardBoard board)
                      CommunionCountdownLine(window: board.window),
                    const SizedBox(height: EvaSpacing.sm),
                    CommunionSegmentedControls(
                      selectedWindow: state.window,
                      selectedMetric: state.metric,
                      onWindowChanged: (LeaderboardWindow window) {
                        _requested = window;
                        context.read<LeaderboardCubit>().load(window);
                      },
                      onMetricChanged: (LeaderboardMetric metric) {
                        context.read<LeaderboardCubit>().selectMetric(metric);
                      },
                    ),
                    const SizedBox(height: EvaSpacing.md),
                    _content(context, state, settings),
                  ],
                ),
              ),
              const SizedBox(height: EvaSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  /// The cheer toast, **anchored to the viewport** and **transparent to taps**.
  ///
  /// ## WHY IT IS IN THE SCAFFOLD'S `overlay` SLOT
  ///
  /// The prototype anchors the toast to the **screen root**:
  /// `eva/redesign.html:466` — `.toast{position:absolute;left:50%;bottom:110px;…}`
  /// — with the element a direct child of the screen (`:738`) and **not** of the
  /// scrolling list.
  ///
  /// Placed inside the page's own column it was inside the `SingleChildScrollView`,
  /// and a `Positioned` child contributes nothing to a `Stack`'s size, so
  /// `bottom: 30` was measured against the **content's** box rather than the
  /// viewport's. Two measured consequences, both reported by the screen suite:
  ///
  /// * **it absorbed the last row's taps.** `RenderStack.hitTestChildren` tests
  ///   the last-painted child first and stops there, so with a seven-row board a
  ///   tap on the last witness hit the toast and never reached the row — the
  ///   reader could not cheer the last witness at all while the toast was up;
  /// * **it could be off-screen.** With a twelve-row board the toast's rect was
  ///   at `y = 895` in an 844-tall viewport: the confirmation the prototype
  ///   promises was never seen, and it scrolled away with the content.
  ///
  /// `NeuralScaffold.overlay` is the viewport-fixed slot that already exists for
  /// exactly this reason (`neural_scaffold.dart`'s own doc: "anything a caller
  /// places **in** its column scrolls away with the content").
  ///
  /// ## AND WHY IT IS `IgnorePointer`
  ///
  /// The prototype's toast rule ends `pointer-events:none` (`:466`). A
  /// confirmation is a **notice**, not a control: it must never take a tap that
  /// belonged to the row under it. `IgnorePointer` does that, and it leaves the
  /// semantics tree alone — the `liveRegion` announcement is the point of the
  /// toast for a screen-reader user.
  Widget? _toastOverlay() {
    final String? message = _toastMessage;
    if (message == null) return null;
    return Stack(
      children: <Widget>[
        Positioned(
          left: 20,
          right: 20,
          // The prototype's `bottom: 110px` (`:466`) — high enough to clear the
          // bottom of the screen and the row under it.
          bottom: 110,
          child: IgnorePointer(child: CommunionCheerToast(message: message)),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    LeaderboardState state,
    UserSettings settings,
  ) => switch (state.status) {
    LeaderboardStatus.failed => ErrorView(
      message: state.failure?.message ?? '',
      onRetry: () => context.read<LeaderboardCubit>().retry(),
      // The board's **own** retry key, and not `/reading`'s: `homeRetry`,
      // `quizRetry`, `readingRetry` and `settingsRetry` are four separate keys
      // with the same value, and the repository namespaces `retry` per screen
      // on purpose. A fifth screen borrowing the fourth's key is the coupling
      // `leaderboardRetry` exists to remove.
      retryLabel: context.l10n.leaderboardRetry,
      // **`isArabicArm` and not `languageCode == 'ar'`.** The repository's
      // canonical arm test is a **prefix** test — `l10n.dart`'s own doc says
      // "so that `ar_EG` … cannot silently fall through to the Latin face" — and
      // this file was spelling the rule a second time, by hand, in a way that
      // `ar_EG` would have got wrong.
      retryFamily: context.l10n.isArabicArm
          ? EvaTypography.arabicFamily
          : EvaTypography.uiFamily,
    ),
    LeaderboardStatus.loading => const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ),
    LeaderboardStatus.ready => switch (state.board) {
      null => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      final LeaderboardBoard board => _boardContent(
        context,
        state,
        board,
        settings,
      ),
    },
  };

  Widget _boardContent(
    BuildContext context,
    LeaderboardState state,
    LeaderboardBoard board,
    UserSettings settings,
  ) {
    final AppLocalizations strings = context.l10n;

    if (board.rows.isEmpty) {
      return EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: strings.leaderboardEmptyTitle,
        message: strings.leaderboardEmptyBody,
      );
    }

    final List<LeaderboardRow> sorted = leaderboardOrder(
      board.rows,
      state.metric,
    );
    final LeaderboardRow? reader = leaderboardReaderRow(
      board.rows,
      standingRank: board.standing?.rank,
    );
    // The toggle alone. **Not** "three rows or more": the prototype's podium
    // skips a missing position rather than disappearing
    // (`eva/redesign.html:1087`'s `if(!p) return;`), so a cohort of two still
    // gets a 1st and a 2nd column. The empty cohort never reaches here — the
    // empty state takes over above.
    final bool showPodium = settings.showPodium;

    // The list is `sorted.slice(3)` — **always**, whether or not the podium is
    // drawn. The prototype slices by position and does not consult the toggle
    // (`eva/redesign.html:1084` builds the podium from `sorted`; `:1110` builds
    // the list from `sorted.slice(3)`), so hiding the podium leaves the top
    // three off the list rather than promoting them into it.
    //
    // Recorded faithfully: it is odd, and it is theirs. The alternative — showing
    // all rows when the podium is hidden — would be a *different* board, and a
    // reader who turned the podium off would see the list change underneath them.
    final List<LeaderboardRow> listRows = sorted.skip(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showPodium)
          CommunionPodium(
            topRows: sorted.take(3).toList(),
            metric: state.metric,
            isVeiled: settings.veilWitnesses,
            readerStandingRank: board.standing?.rank,
          ),
        CommunionYouCard(
          readerRow: reader,
          sortedRows: sorted,
          metric: state.metric,
          isVeiled: settings.veilWitnesses,
          // The board's **standing**, so the card can say what the server says
          // about a reader this page does not carry. `my_standing` is
          // `{rank, score}` and the endpoint's `limit` is 50, so a cohort of
          // more than fifty scored children drops the reader's own row while
          // the standing still ranks them.
          standing: board.standing,
          fallbackName: state.readerName,
        ),
        const SizedBox(height: EvaSpacing.sm),
        // The **index in the list**, which is the `k` in the prototype's
        // `80 + k·45` ms stagger (`eva/redesign.html:1126`) — the board knows
        // the stagger, so the board hands each row its own number.
        for (final (int index, LeaderboardRow row) in listRows.indexed)
          LeaderboardRowTile(
            row: row,
            isReader:
                board.standing?.rank != null &&
                board.standing!.rank == row.rank,
            displayPosition: leaderboardPositionOf(sorted, row),
            metric: state.metric,
            isVeiled: settings.veilWitnesses,
            isCheered: state.cheered.contains(row.userId),
            entranceIndex: index,
            onCheer: () {
              unawaited(_cheer(row, sorted, settings));
            },
          ),
      ],
    );
  }

  /// Cheers [row] and announces it **only if the cheer happened**.
  ///
  /// The toast is the success confirmation (`eva/redesign.html:947`), so it is
  /// shown on the cubit's answer and not on the tap. A second tap on an
  /// already-cheered row is the prototype's `if(cheered.has(p.id)) return;`
  /// (`:1120`) — it does nothing at all, and a toast that re-announced the cheer
  /// would be the screen talking about an event it did not perform.
  ///
  /// **`State.context` and not a passed-in one**, so the `mounted` check below
  /// guards the context it is used with.
  Future<void> _cheer(
    LeaderboardRow row,
    List<LeaderboardRow> sorted,
    UserSettings settings,
  ) async {
    final bool cheered = await context.read<LeaderboardCubit>().cheer(
      row.userId,
    );
    if (!cheered || !mounted) return;
    final int pos = leaderboardPositionOf(sorted, row);
    // The veil applies to the toast's name too: a voice-over user must not hear
    // what the screen is forbidden to show.
    final String name = settings.veilWitnesses
        ? context.l10n.leaderboardWitness(context.l10n.digits(pos))
        : row.fullName;
    _showCheerToast(context.l10n.leaderboardCheerSent(name));
  }
}
