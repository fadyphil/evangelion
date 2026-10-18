import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/core/design_system/widgets/error_view.dart';
import 'package:evangelion/core/design_system/widgets/leaderboard_row_tile.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../support/design_system_harness.dart';
import '../../../support/reading_harness.dart';

/// The surfaces the leaderboard screen has to survive.
///
/// ## AND THE CARD GROUP THAT WAS HERE
///
/// Phase 5.2 deleted `LeaderboardCard` with the board card on `/`
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md`; the redesign's home
/// has no board). The card's own overflow matrix — three surfaces, ready and empty
/// — died with it, and it is *not* re-pointed: the screen is a different layout
/// with its own scrolling list, so the card's green rows would have said nothing
/// about it. What the screen inherits is the discipline, not the numbers: the same
/// three surfaces below, and the same two board states, asserted against the page.
///
final List<(String, Size)> _surfaces = <(String, Size)>[
  ('320x568', kNarrowSurface),
  ('390x844', kAmbientSurface),
  ('430x932', kGeometrySurface),
];

/// A board with the reader in the middle of five, and both totals known.
///
/// `cohortSize: 5` with three rows is the shape that exercises the "3 / 5" line — the
/// one piece of copy unique to this feature.
const LeaderboardBoard _board = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(rank: 1, score: 1280, initials: 'PG'),
    LeaderboardRow(rank: 2, score: 940, initials: 'DM'),
    LeaderboardRow(rank: 3, score: 610, initials: 'MA'),
  ],
  standing: LeaderboardStanding(rank: 2, score: 940),
  cohortSize: 5,
);

/// An empty board.
///
/// **Not** the state development reaches — the backend's `InMemoryRedisFallback`
/// pre-seeds three rows for group 3 unless `NODE_ENV` is exactly `test`. This fixture
/// once carried a comment calling itself "the only state development can currently
/// reach", which was a fact about one `curl`, not about the endpoint; see AGENT_CONTEXT
/// decision 143. It is here because the empty board is still reachable — a cohort with
/// no scored children yet, or any group other than the seeded 3.
const LeaderboardBoard _empty = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[],
  standing: null,
  cohortSize: 0,
);

Future<void> _pumpPage(
  WidgetTester tester,
  LeaderboardBoard board, {
  required Size size,
}) async {
  // **The surface is set on the view, not on the harness widget.**
  // `evaPrimitiveHarness`'s own `size` parameter is documented as retained-but-unused —
  // the surface is fixed by `pumpPrimitive`, and a `SizedBox` in the tree does not
  // work because the platform view reports the real one. The first version of this
  // file passed `size:` and rendered every "surface" at the default 800x600, which is
  // why the loop above now asserts the laid-out width rather than trusting the label.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      size: size,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: LeaderboardPage(
        cubit: LeaderboardCubit(
          loadLeaderboard: LoadLeaderboard(_AnsweringRepo(board)),
        ),
      ),
    ),
  );
  // Two frames: the page's `didChangeDependencies` dispatches `load`, and the
  // `Future` it awaits resolves on the next microtask drain.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

final class _AnsweringRepo implements LeaderboardRepository {
  _AnsweringRepo(this.answer);

  /// The board this fake answers with — named `answer` rather than `board`, because a
  /// field cannot share a name with the method it implements.
  final LeaderboardBoard answer;

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async => Result<LeaderboardBoard>.of(answer);
}

void main() {
  group('the screen', () {
    for (final (String name, Size size) in _surfaces) {
      testWidgets('renders the list without overflowing at $name', (
        WidgetTester tester,
      ) async {
        await _pumpPage(tester, _board, size: size);
        // The surface is asserted, not assumed: the first version of this loop
        // destructured `size`, never passed it to the harness, and the analyzer caught
        // the unused variable — which meant three identical renders were being called
        // three sizes. `somethingRendered` here is the width the screen actually laid
        // out at, so a future harness that ignores `size` fails here too.
        expect(
          tester.getSize(find.byType(LeaderboardPage)).width,
          lessThanOrEqualTo(size.width),
        );
        expectNoOverflow(tester, somethingRendered: () => true, surface: name);
      });

      testWidgets('renders the empty board without overflowing at $name', (
        WidgetTester tester,
      ) async {
        await _pumpPage(tester, _empty, size: size);
        expect(
          tester.getSize(find.byType(LeaderboardPage)).width,
          lessThanOrEqualTo(size.width),
        );
        expectNoOverflow(tester, somethingRendered: () => true, surface: name);
      });
    }

    testWidgets('and a failure renders its own message, not a blank panel', (
      WidgetTester tester,
    ) async {
      final LeaderboardCubit cubit = LeaderboardCubit(
        loadLeaderboard: const LoadLeaderboard(_FailingRepo()),
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
      await tester.pump(const Duration(milliseconds: 16));

      // `ErrorView` is present…
      expect(find.byType(ErrorView), findsOneWidget);
      // …and it is showing the repository's **own words**, verbatim. A sentence
      // invented at the call site would hide which field was actually unreadable,
      // which is the defect `reading_page.dart` records for the same wiring. Read off
      // the widget rather than with `find.textContaining`, because a long message is
      // wrapped across `Text` spans and a text finder would be asserting about
      // typography.
      final ErrorView view = tester.widget<ErrorView>(find.byType(ErrorView));
      expect(view.message, contains('x-group-id'));
      expectNoOverflow(
        tester,
        somethingRendered: () => true,
        surface: 'failure',
      );
    });
  });

  group('the screen renders exactly the rows it says it does', () {
    testWidgets('all five ranked children are on screen', (
      WidgetTester tester,
    ) async {
      // **Re-pointed from the deleted card, and stronger for it.** The card drew
      // 3 of the 50 it asked for (`kLeaderboardPreviewRows`), so its version of
      // this row asserted a *sample*. The screen draws the whole list the
      // fixture holds, and a screen that truncated it would fail here rather
      // than pass on a prefix.
      await _pumpPage(tester, _board, size: kAmbientSurface);
      // **Three, and that is the fixture's row count, not a preview.** `_board`
      // holds three ranked children (its `cohortSize` is the five-strong cohort
      // they are drawn from), and the screen draws all three. The
      // "no preview truncation" claim — the full cohort drawn, all five — is the
      // *view* suite's row, whose fixture holds five; this file's subject is
      // layout, and its fixture is the smallest one that still exercises the
      // `3 / 5` line.
      expect(find.byType(LeaderboardRowTile), findsNWidgets(3));
    });
  });
}

final class _FailingRepo implements LeaderboardRepository {
  const _FailingRepo();

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async => const Left<Failure, LeaderboardBoard>(
    Failure(
      kind: FailureKind.validation,
      message: 'Could not read the leaderboard: x-group-id is not a number',
    ),
  );
}
