import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/core/design_system/widgets/error_view.dart';
import 'package:evangelion/core/design_system/widgets/leaderboard_row_tile.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/widgets/leaderboard_card.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The behaviour of the two leaderboard surfaces that the overflow suite does not
/// reach, and the cubit tests cannot reach at all.
///
/// ## WHAT IS BEING ASSERTED, AND WHY IT IS NOT COSMETIC
///
/// The overflow suite proves these widgets **lay out**. This file proves what they
/// **say** and what they **do**, and every assertion below is one where the rendered
/// value is the feature's entire value:
///
/// * `cohortSize == null` must print a bare rank, and `cohortSize == 5` must print
///   `2 / 5`. These are two different strings on the same line, and the branch between
///   them is the ZCARD contract from AGENT_CONTEXT decision 136. A widget that always
///   printed a total would have to invent one exactly when the list is capped and the
///   total is unknown.
/// * The reader's row is found by **rank position**, because `LeaderboardRow` has no
///   `userId` to compare — so the highlighting is asserted against the tile's own
///   `isReader`, not against a name.
/// * Tapping a window segment must re-request. The cubit tests prove `load` works; only
///   a widget test can prove the control is *wired to it*.
///
/// Copy that is only about appearance — a heading's wording, a font, a colour — is
/// deliberately absent, and `find.text` is never used to assert a full sentence.

/// Five ranked children, the reader second.
const LeaderboardBoard _five = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(rank: 1, score: 1280, initials: 'PG'),
    LeaderboardRow(rank: 2, score: 940, initials: 'DM'),
    LeaderboardRow(rank: 3, score: 610, initials: 'MA'),
    LeaderboardRow(rank: 4, score: 420, initials: 'JS'),
    LeaderboardRow(rank: 5, score: 210, initials: 'AK'),
  ],
  standing: LeaderboardStanding(rank: 2, score: 940),
  cohortSize: 5,
);

/// The same five with the cohort size **unprovable** — the request's cap bound, so
/// `total_ranked` equals the row count and the true total is unknown.
const LeaderboardBoard _uncapped = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(rank: 1, score: 1280, initials: 'PG'),
    LeaderboardRow(rank: 2, score: 940, initials: 'DM'),
    LeaderboardRow(rank: 3, score: 610, initials: 'MA'),
  ],
  standing: LeaderboardStanding(rank: 2, score: 940),
  cohortSize: null,
);

/// A cohort nobody has scored in, with the reader absent from it.
const LeaderboardBoard _unranked = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[],
  standing: null,
  cohortSize: 0,
);

/// `standing` present but `rank` null — the reader is in the group and has no score.
///
/// Distinct from [_unranked] on purpose: the entity allows it, the endpoint emits it
/// when `my_standing` carries a score with no rank, and the UI must not print "null".
const LeaderboardBoard _rankless = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[LeaderboardRow(rank: 1, score: 1280, initials: 'PG')],
  standing: LeaderboardStanding(rank: null, score: 0),
  cohortSize: 1,
);

/// Every string the tree actually rendered.
///
/// Read off the widgets rather than with `find.text`, so an assertion here is about
/// *what the reader is shown* and never about which `Text` widget or style carried it.
List<String> _shown(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text text) => text.data ?? '')
    .toList();

Future<void> _pumpCard(
  WidgetTester tester, {
  required HomeSectionStatus status,
  required LeaderboardBoard? board,
  Failure? failure,
  VoidCallback? onOpen,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: LeaderboardCard(
        status: status,
        board: board,
        failure: failure,
        onOpen: onOpen ?? () {},
        onRetry: onRetry ?? () {},
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
}

Future<LeaderboardCubit> _pumpPage(
  WidgetTester tester,
  LeaderboardRepository repo,
) async {
  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: LoadLeaderboard(repo),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: LeaderboardPage(cubit: cubit),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  return cubit;
}

/// Answers with a fixed board and remembers every window it was asked for.
///
/// [failFrom] is the index from which requests start failing, so a test can let the
/// page load successfully, then break the next request and reach the **failed** arm
/// with a window already chosen — which is the state `retry` has to get right.
final class _RecordingRepo implements LeaderboardRepository {
  _RecordingRepo(this.answer, {this.failFrom = 1 << 30});

  LeaderboardBoard answer;

  /// Requests at or after this index fail. Large by default, so a repo succeeds.
  int failFrom;

  /// The windows requested, in order. The **first** entry is the page's own initial
  /// load, so window switching is asserted on the whole list rather than on its tail.
  final List<LeaderboardWindow> asked = <LeaderboardWindow>[];

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    asked.add(window);
    if (asked.length >= failFrom) {
      return const Result<LeaderboardBoard>.failure(
        Failure(
          kind: FailureKind.network,
          message: 'Could not reach the server.',
        ),
      );
    }
    return Result<LeaderboardBoard>.success(answer);
  }
}

void main() {
  group('the card states the cohort size only when it is provable', () {
    testWidgets('prints "rank / cohort" when the size is known', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, status: HomeSectionStatus.ready, board: _five);
      // The whole point of the `2 / 5` line, so it is asserted exactly.
      expect(_shown(tester), contains('2 / 5'));
    });

    testWidgets('prints a BARE rank when the size is unknown', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        status: HomeSectionStatus.ready,
        board: _uncapped,
      );
      final List<String> shown = _shown(tester);
      // "2" alone. Asserted as the absence of the total rather than the presence of
      // the string "2", because "2" also occurs as the rank column and as row scores —
      // the claim under test is specifically that no total is invented.
      expect(shown.any((String text) => text.contains('/')), isFalse);
      expect(shown, isNot(contains('2 / 3')));
      expect(shown, contains('2'));
    });

    testWidgets('says "not ranked" when standing is null', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        status: HomeSectionStatus.ready,
        board: _unranked,
      );
      expect(_shown(tester), contains('Not ranked yet'));
    });

    testWidgets('says "not ranked" when rank is null but standing is not', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        status: HomeSectionStatus.ready,
        board: _rankless,
      );
      // The literal `null` must never reach the screen: the entity allows
      // `rank: null` and `'${standing.rank}'` would print "null".
      expect(_shown(tester), contains('Not ranked yet'));
      expect(_shown(tester).any((String t) => t.contains('null')), isFalse);
    });
  });

  group('the card reserves its slot while loading', () {
    testWidgets('shows a spinner, and no rows or error', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, status: HomeSectionStatus.loading, board: null);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LeaderboardRowTile), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
      // The reserved slot is what stops the surrounding layout jumping when the
      // answer lands. It is read off the **declaring** widget, because
      // `evaPrimitiveHarness` hands its child a tight 600pt and a laid-out
      // measurement would report the harness, not the reservation — which is exactly
      // what the first version of this assertion did and why it read 600.
      expect(
        tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .map((SizedBox box) => box.height)
            .where((double? height) => height == LeaderboardCard.loadingHeight),
        isNotEmpty,
      );
    });
  });

  group("the card's failure arm", () {
    testWidgets("shows the failure's OWN words, not an invented sentence", (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        status: HomeSectionStatus.failed,
        board: null,
        failure: const Failure(
          kind: FailureKind.validation,
          message:
              'Could not read the leaderboard: `leaderboard[1].score` is not a '
              'number',
        ),
      );
      final ErrorView view = tester.widget<ErrorView>(find.byType(ErrorView));
      expect(view.message, contains('leaderboard[1].score'));
      // `ErrorView` throws without a family, and Arabic needs a different one.
      expect(view.retryFamily, isNotNull);
    });

    testWidgets('retry re-requests the card', (WidgetTester tester) async {
      int retries = 0;
      await _pumpCard(
        tester,
        status: HomeSectionStatus.failed,
        board: null,
        failure: const Failure(kind: FailureKind.network, message: 'offline'),
        onRetry: () => retries++,
      );
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(retries, 1);
    });
  });

  group('the card marks the reader row by RANK, not by identity', () {
    testWidgets('the tile whose rank matches standing is the reader', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, status: HomeSectionStatus.ready, board: _five);
      final List<LeaderboardRowTile> tiles = tester
          .widgetList<LeaderboardRowTile>(find.byType(LeaderboardRowTile))
          .toList();
      // Three drawn of the five ranked, per `kLeaderboardPreviewRows`.
      expect(tiles, hasLength(3));
      expect(tiles.map((LeaderboardRowTile t) => t.isReader).toList(), <bool>[
        false,
        true,
        false,
      ]);
    });

    testWidgets('no tile is the reader when standing is null', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        status: HomeSectionStatus.ready,
        board: _unranked,
      );
      // The empty board draws no tiles at all, so the branch that matters is a
      // non-empty cohort the reader is absent from.
      final LeaderboardBoard elsewhere = _five.copyWith(standing: null);
      await _pumpCard(
        tester,
        status: HomeSectionStatus.ready,
        board: elsewhere,
      );
      expect(
        tester
            .widgetList<LeaderboardRowTile>(find.byType(LeaderboardRowTile))
            .every((LeaderboardRowTile tile) => !tile.isReader),
        isTrue,
      );
    });
  });

  group('the card opens the full list', () {
    testWidgets('the link fires onOpen', (WidgetTester tester) async {
      int opens = 0;
      await _pumpCard(
        tester,
        status: HomeSectionStatus.ready,
        board: _five,
        onOpen: () => opens++,
      );
      await tester.tap(find.text('See all'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(opens, 1);
    });
  });

  group('the screen renders every row, not the card three', () {
    testWidgets('all five ranked children are on screen', (
      WidgetTester tester,
    ) async {
      await _pumpPage(tester, _RecordingRepo(_five));
      // The card draws 3 out of 50; this screen is the full list. A screen that
      // reused the card's `take(3)` would silently truncate the ranking.
      expect(find.byType(LeaderboardRowTile), findsNWidgets(5));
    });

    testWidgets('an empty cohort shows the empty state, not a blank list', (
      WidgetTester tester,
    ) async {
      await _pumpPage(tester, _RecordingRepo(_unranked));
      expect(find.byType(LeaderboardRowTile), findsNothing);
      expect(_shown(tester), contains('No scores yet'));
    });
  });

  group('the standing footer states the cohort size too', () {
    testWidgets('"rank / cohort" when known', (WidgetTester tester) async {
      await _pumpPage(tester, _RecordingRepo(_five));
      expect(_shown(tester), contains('2 / 5'));
    });

    testWidgets('a bare rank when unknown', (WidgetTester tester) async {
      await _pumpPage(tester, _RecordingRepo(_uncapped));
      expect(_shown(tester).any((String text) => text.contains('/')), isFalse);
    });

    testWidgets('"not ranked" when the reader has no standing', (
      WidgetTester tester,
    ) async {
      // A cohort with rows, but the reader absent — so the footer has to answer even
      // though the list above it is not empty.
      await _pumpPage(tester, _RecordingRepo(_five.copyWith(standing: null)));
      expect(_shown(tester), contains('Not ranked yet'));
    });
  });

  group('the window control re-requests, it does not filter locally', () {
    testWidgets('tapping Month asks the repository for monthly', (
      WidgetTester tester,
    ) async {
      final _RecordingRepo repo = _RecordingRepo(_five);
      await _pumpPage(tester, repo);
      // The page's own initial load is the first entry; a control that only
      // re-labelled the existing rows would leave this list at one long entry.
      expect(repo.asked, <LeaderboardWindow>[LeaderboardWindow.weekly]);

      await tester.tap(find.text('MONTH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(repo.asked, <LeaderboardWindow>[
        LeaderboardWindow.weekly,
        LeaderboardWindow.monthly,
      ]);
    });

    testWidgets('the heading follows the window that was requested', (
      WidgetTester tester,
    ) async {
      await _pumpPage(
        tester,
        _RecordingRepo(_five.copyWith(window: LeaderboardWindow.allTime)),
      );
      await tester.tap(find.text('ALL TIME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // "All time" is both a segment label and a heading, so this asserts the count
      // grew rather than that the word appeared — the first is the behaviour.
      // `SegmentedControl` renders labels through `label.toUpperCase()`, so the
      // segment and the heading are compared **case-insensitively** rather than
      // hard-coding the transform here.
      expect(
        _shown(tester).where((String t) => t.toUpperCase() == 'ALL TIME'),
        hasLength(2),
      );
    });

    testWidgets('retry re-requests the FAILED window, not the default', (
      WidgetTester tester,
    ) async {
      // Three weekly and month succeed, then allTime fails — the third request. The
      // screen ends in the failed arm with **allTime** chosen.
      final _RecordingRepo repo = _RecordingRepo(_five, failFrom: 3);
      await _pumpPage(tester, repo);
      await tester.tap(find.text('MONTH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('ALL TIME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(ErrorView), findsOneWidget);
      expect(repo.asked, hasLength(3));

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(repo.asked, hasLength(4));
      // **The window on screen, not a reset to weekly.** `retry` is
      // `load(state.window)`, and `state.window` is what the reader last chose. A
      // retry that forgot it would show the reader a ranking for a different period
      // than the one they selected — the exact mismatch `LeaderboardBoard.window`
      // exists to prevent.
      expect(repo.asked.last, LeaderboardWindow.allTime);
    });
  });

  group('a row announces one sentence, and never a name', () {
    // `try`/`finally` around every semantics test, and **not** `addTearDown`.
    //
    // `ensureSemantics` returns a handle the binding requires to be disposed before
    // the body returns. A bare `handle.dispose()` after the `expect` is never reached
    // when the expectation fails, and `addTearDown` runs too late to count — so both
    // forms replaced the real failure with the binding's "a SemanticsHandle was
    // active at the end of the test", which says nothing about the label. `finally`
    // disposes on **both** paths, so a wrong label reports a wrong label.
    testWidgets('rank, initials and points in a single label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpPage(tester, _RecordingRepo(_five));
        expect(
          find.bySemanticsLabel('1280 points, PG, rank 1'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets("the reader's row says so", (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpPage(tester, _RecordingRepo(_five));
        expect(
          find.bySemanticsLabel('940 points, DM, rank 2, that is you'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the payload carries full_name but the label cannot leak it', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpPage(tester, _RecordingRepo(_five));
        // The wire sends `full_name: "Peter George (Grade 6)"`; `LeaderboardRow` has
        // no field to put it in, so a voice-over user cannot **hear** what the screen
        // is forbidden to show. Asserting the absence proves the structural claim
        // holds at the one place it could leak.
        expect(find.bySemanticsLabel(RegExp('George')), findsNothing);
      } finally {
        handle.dispose();
      }
    });
  });
}
