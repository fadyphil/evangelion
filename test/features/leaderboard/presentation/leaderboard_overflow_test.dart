import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/core/design_system/widgets/empty_state.dart';
import 'package:evangelion/core/design_system/widgets/error_view.dart';
import 'package:evangelion/core/design_system/widgets/leaderboard_row_tile.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/cheer_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/data/datasources/cheer_local_data_source.dart';
import 'package:evangelion/features/leaderboard/data/repositories/local_cheer_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_podium.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../support/design_system_harness.dart';
import '../../../support/reading_harness.dart';
import '../../../support/settings_harness.dart';

/// The surfaces the communion screen has to survive.
final List<(String, Size)> _surfaces = <(String, Size)>[
  ('320x568', kNarrowSurface),
  ('390x844', kAmbientSurface),
  ('430x932', kGeometrySurface),
];

/// A board with the reader in the middle of six, and both totals known.
///
/// **SIX rows, and the number is load-bearing.** The podium takes the first
/// three and the list is `sorted.slice(3)` — so a three-row board lays out an
/// **empty** list, and the rows — the most overflow-prone part of the screen —
/// would never be measured at any of the three surfaces. This fixture is the
/// one that makes the matrix mean what its name says.
///
/// **The names are long on purpose.** The research report for this screen names
/// "you-card ellipsis rows" as a hazard, and an ellipsised name is a name that
/// has to fit: the row is `rank | orb | name | value`, and the name is the only
/// part that gives.
const LeaderboardBoard _board = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      userId: 'u1',
      fullName: 'Peter George',
      currentStreak: 12,
      rank: 1,
      score: 1280,
      initials: 'PG',
    ),
    LeaderboardRow(
      userId: 'u2',
      fullName: 'David Mina',
      currentStreak: 8,
      rank: 2,
      score: 940,
      initials: 'DM',
    ),
    LeaderboardRow(
      userId: 'u3',
      fullName: 'Mariam Anton',
      currentStreak: 5,
      rank: 3,
      score: 610,
      initials: 'MA',
    ),
    LeaderboardRow(
      userId: 'u4',
      fullName: 'Ana Silvia Maria de la Cruz',
      currentStreak: 4,
      rank: 4,
      score: 420,
      initials: 'AS',
    ),
    LeaderboardRow(
      userId: 'u5',
      fullName: 'Karim Nabil',
      currentStreak: 2,
      rank: 5,
      score: 210,
      initials: 'KN',
    ),
    LeaderboardRow(
      userId: 'u6',
      fullName: 'Widad Fares',
      currentStreak: 1,
      rank: 6,
      score: 120,
      initials: 'WF',
    ),
  ],
  standing: LeaderboardStanding(rank: 4, score: 420),
  cohortSize: 6,
);

/// An empty board.
const LeaderboardBoard _empty = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[],
  standing: null,
  cohortSize: 0,
);

/// The reader's session, for the you-card's fallback arm.
///
/// The **real** port shape (`signIn` takes two named strings, `UserRole` is the
/// role enum) — an implementation of a port this repository does not own would
/// compile against a stale signature and pass for a reason the screen never had.
final class _StubAuthRepo implements AuthRepository {
  const _StubAuthRepo();

  @override
  Future<Result<AuthSession>> getCurrentSession() async =>
      Result<AuthSession>.of(
        AuthSession(
          userId: 'u2',
          displayName: 'David Mina',
          email: 'david@example.com',
          initials: 'DM',
          createdAt: DateTime.utc(2026),
        ),
      );

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async => getCurrentSession();

  @override
  Future<Result<void>> signOut() async => Result<void>.of(null);
}

Future<void> _pumpPage(
  WidgetTester tester,
  LeaderboardBoard board, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final CheerRepository cheerRepo = LocalCheerRepository(
    CheerLocalDataSource(),
  );
  const GetBoardReaderSession getReader = GetBoardReaderSession(
    _StubAuthRepo(),
  );

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      size: size,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      // `settingsScope` and not a bare page: `CommunionPage` reads the veil and
      // the podium toggle through `SettingsScope.of`, which falls back to the
      // locator's `SettingsHandle` when no scope is above the context. Without
      // this wrapper the page would ask the locator for a handle that no test
      // registered, and the screen would throw before it drew a pixel.
      child: settingsScope(
        tester,
        CommunionPage(
          cubit: LeaderboardCubit(
            loadLeaderboard: LoadLeaderboard(_AnsweringRepo(board)),
            getReaderSession: getReader,
            cheerRepository: cheerRepo,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

final class _AnsweringRepo implements LeaderboardRepository {
  _AnsweringRepo(this.answer);

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
        expect(
          tester.getSize(find.byType(CommunionPage)).width,
          lessThanOrEqualTo(size.width),
        );
        // **A real landmark, and not `() => true`.** `expectNoOverflow`'s own
        // doc says the landmark is "evaluated **before** [drainOverflowErrors],
        // so a caller whose landmark is missing gets that failure rather than a
        // confusing one" — and a constant can never be missing, so it makes the
        // half of the check that says "something was actually laid out here"
        // vacuous. This file was the only one in the repository that passed a
        // constant.
        expect(
          find.byType(LeaderboardRowTile),
          findsNWidgets(3),
          reason:
              'the board has six rows: the podium takes three and the list is '
              '`slice(3)`, so three rows must be laid out — otherwise this '
              'matrix is measuring an empty list.',
        );
        expectNoOverflow(
          tester,
          somethingRendered: () =>
              find.byType(LeaderboardRowTile).evaluate().isNotEmpty,
          surface: name,
        );
      });

      testWidgets('renders the empty board without overflowing at $name', (
        WidgetTester tester,
      ) async {
        await _pumpPage(tester, _empty, size: size);
        expect(
          tester.getSize(find.byType(CommunionPage)).width,
          lessThanOrEqualTo(size.width),
        );
        // The empty arm's landmark is the empty state itself — the screen's own
        // answer to "no rows", and the thing that has to fit on 320×568.
        expect(find.byType(EmptyState), findsOneWidget);
        expectNoOverflow(
          tester,
          somethingRendered: () =>
              find.byType(EmptyState).evaluate().isNotEmpty,
          surface: name,
        );
      });
    }

    testWidgets('and a failure renders its own message, not a blank panel', (
      WidgetTester tester,
    ) async {
      final CheerRepository cheerRepo = LocalCheerRepository(
        CheerLocalDataSource(),
      );
      const GetBoardReaderSession getReader = GetBoardReaderSession(
        _StubAuthRepo(),
      );
      final LeaderboardCubit cubit = LeaderboardCubit(
        loadLeaderboard: const LoadLeaderboard(_FailingRepo()),
        getReaderSession: getReader,
        cheerRepository: cheerRepo,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          // The same reason `_pumpPage` wraps its page: `CommunionPage` reads the
          // veil and the podium toggle through `SettingsScope.of`, which falls
          // back to the locator's `SettingsHandle` when no scope is above the
          // context.
          child: settingsScope(tester, CommunionPage(cubit: cubit)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(ErrorView), findsOneWidget);
      final ErrorView view = tester.widget<ErrorView>(find.byType(ErrorView));
      expect(view.message, contains('x-group-id'));
      expectNoOverflow(
        tester,
        somethingRendered: () => find.byType(ErrorView).evaluate().isNotEmpty,
        surface: 'failure',
      );
    });
  });

  group('the screen renders podium for top rows', () {
    testWidgets('top ranked children are in podium', (
      WidgetTester tester,
    ) async {
      await _pumpPage(tester, _board, size: kAmbientSurface);
      expect(find.byType(CommunionPodium), findsOneWidget);
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
