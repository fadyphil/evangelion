import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/cheer_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/data/datasources/cheer_local_data_source.dart';
import 'package:evangelion/features/leaderboard/data/repositories/local_cheer_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_cheer_toast.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_countdown_line.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_podium.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_you_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../support/design_system_harness.dart';
import '../../../support/settings_harness.dart';

/// The behaviour of `/communion`, the cohort's board.
///
/// ## WHAT THIS FILE IS AND IS NOT
///
/// The overflow suite (`leaderboard_overflow_test.dart`) proves the screen **lays
/// out** at three surfaces, and the cubit suite
/// (`leaderboard_cubit_test.dart`) proves the **state machine**. Neither can say
/// what a reader is shown, and this file is the one that does: the podium's
/// geometry, the you-card's wording, the veil's effect on names *and* on
/// accessible names, the cheer's once rule, and the two arms the board has that
/// are not "a list of rows".
///
/// ## THE FIXTURE IS CHOSEN, NOT INHERITED
///
/// The board below has **five** rows and the reader is **fourth**, which is the
/// only shape that exercises the screen's two halves at once:
///
/// * the podium takes the **top three** and the list is `sorted.skip(3)` — so a
///   five-row board draws three columns and two rows, and a test expecting five
///   tiles is wrong (`eva/redesign.html:1084` builds the podium from `sorted`
///   and `:1110` builds the list from `sorted.slice(3)`);
/// * the reader is **in the list**, so the reader's own row treatment, the
///   you-card's gap line and the "the reader cannot be cheered" rule are all
///   reachable on the same board.
///
/// A reader in the podium would hide the list's reader treatment behind the
/// podium's, so the reader is deliberately placed in the list and the podium is
/// deliberately all witnesses.
const LeaderboardBoard _five = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 1280,
      currentStreak: 12,
      initials: 'PG',
      userId: 'u1',
      fullName: 'Peter George',
    ),
    LeaderboardRow(
      rank: 2,
      score: 940,
      currentStreak: 8,
      initials: 'DM',
      userId: 'u2',
      fullName: 'David Mina',
    ),
    LeaderboardRow(
      rank: 3,
      score: 610,
      currentStreak: 5,
      initials: 'MA',
      userId: 'u3',
      fullName: 'Mariam Anton',
    ),
    LeaderboardRow(
      rank: 4,
      score: 420,
      currentStreak: 4,
      initials: 'AS',
      userId: 'u4',
      fullName: 'Ana Silva',
    ),
    LeaderboardRow(
      rank: 5,
      score: 210,
      currentStreak: 2,
      initials: 'KN',
      userId: 'u5',
      fullName: 'Karim Nabil',
    ),
  ],
  standing: LeaderboardStanding(rank: 4, score: 420),
  cohortSize: 5,
);

/// A cohort long enough to **scroll**.
///
/// The five-row board above fits a 390×700 surface, so nothing on it can be
/// pushed off the screen. This one cannot: twelve rows is nine more than the
/// podium takes, and the board is meant to be read on a 320×568 phone, which is
/// the shortest viewport the app supports.
///
/// The reader is `Ana Silva` at rank 4 again, so the reader's own row is in the
/// list rather than on the podium, and the **last** row is `Ziad Habib` — the
/// one the toast used to cover.
const LeaderboardBoard _long = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 1280,
      currentStreak: 12,
      initials: 'PG',
      userId: 'u1',
      fullName: 'Peter George',
    ),
    LeaderboardRow(
      rank: 2,
      score: 940,
      currentStreak: 8,
      initials: 'DM',
      userId: 'u2',
      fullName: 'David Mina',
    ),
    LeaderboardRow(
      rank: 3,
      score: 610,
      currentStreak: 5,
      initials: 'MA',
      userId: 'u3',
      fullName: 'Mariam Anton',
    ),
    LeaderboardRow(
      rank: 4,
      score: 420,
      currentStreak: 4,
      initials: 'AS',
      userId: 'u4',
      fullName: 'Ana Silva',
    ),
    LeaderboardRow(
      rank: 5,
      score: 380,
      currentStreak: 3,
      initials: 'KN',
      userId: 'u5',
      fullName: 'Karim Nabil',
    ),
    LeaderboardRow(
      rank: 6,
      score: 340,
      currentStreak: 6,
      initials: 'TF',
      userId: 'u6',
      fullName: 'Tarek Fares',
    ),
    LeaderboardRow(
      rank: 7,
      score: 300,
      currentStreak: 9,
      initials: 'HS',
      userId: 'u7',
      fullName: 'Hala Saeed',
    ),
    LeaderboardRow(
      rank: 8,
      score: 260,
      currentStreak: 1,
      initials: 'NA',
      userId: 'u8',
      fullName: 'Nabil Adly',
    ),
    LeaderboardRow(
      rank: 9,
      score: 220,
      currentStreak: 7,
      initials: 'YE',
      userId: 'u9',
      fullName: 'Yara Emad',
    ),
    LeaderboardRow(
      rank: 10,
      score: 180,
      currentStreak: 2,
      initials: 'FS',
      userId: 'u10',
      fullName: 'Fady Shady',
    ),
    LeaderboardRow(
      rank: 11,
      score: 140,
      currentStreak: 5,
      initials: 'WF',
      userId: 'u11',
      fullName: 'Widad Fares',
    ),
    LeaderboardRow(
      rank: 12,
      score: 100,
      currentStreak: 1,
      initials: 'ZH',
      userId: 'u12',
      fullName: 'Ziad Habib',
    ),
  ],
  standing: LeaderboardStanding(rank: 4, score: 420),
  cohortSize: 12,
);

/// The same cohort with the reader **absent** from the payload.
///
/// `standing` is `null` and the reader's own row is not in the list, so the
/// you-card has no row to print and must fall back to the session's name — and
/// print **no value at all**, because a reader with 420 points who is not on
/// this page must not be told they have none.
const LeaderboardBoard _withoutReader = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 1280,
      currentStreak: 12,
      initials: 'PG',
      userId: 'u1',
      fullName: 'Peter George',
    ),
    LeaderboardRow(
      rank: 2,
      score: 940,
      currentStreak: 8,
      initials: 'DM',
      userId: 'u2',
      fullName: 'David Mina',
    ),
    LeaderboardRow(
      rank: 3,
      score: 610,
      currentStreak: 5,
      initials: 'MA',
      userId: 'u3',
      fullName: 'Mariam Anton',
    ),
    LeaderboardRow(
      rank: 4,
      score: 210,
      currentStreak: 2,
      initials: 'KN',
      userId: 'u5',
      fullName: 'Karim Nabil',
    ),
  ],
  standing: null,
  cohortSize: 4,
);

/// A cohort nobody has scored in.
const LeaderboardBoard _empty = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[],
  standing: null,
  cohortSize: 0,
);

/// A cohort whose **page does not carry the reader's row**, while the server's
/// standing says the reader is ranked.
///
/// The endpoint's `limit` is 50 (`LeaderboardCubit.rowLimit`), so a cohort of
/// more than fifty scored children drops the reader's own row from
/// `leaderboard[]` while `my_standing` still answers `{"rank": 51, "score":
/// 180}`. **The four rows here stand in for the fifty the page carries** —
/// what matters is that the reader's own row is not among them and that the
/// standing ranks them beyond the page.
///
/// This is the state the you-card used to read as "the reader is unranked",
/// which is a falsehood about a reader the server puts 51st.
const LeaderboardBoard _beyondThePage = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 1280,
      currentStreak: 12,
      initials: 'PG',
      userId: 'u1',
      fullName: 'Peter George',
    ),
    LeaderboardRow(
      rank: 2,
      score: 940,
      currentStreak: 8,
      initials: 'DM',
      userId: 'u2',
      fullName: 'David Mina',
    ),
    LeaderboardRow(
      rank: 3,
      score: 610,
      currentStreak: 5,
      initials: 'MA',
      userId: 'u3',
      fullName: 'Mariam Anton',
    ),
    LeaderboardRow(
      rank: 4,
      score: 210,
      currentStreak: 2,
      initials: 'KN',
      userId: 'u5',
      fullName: 'Karim Nabil',
    ),
  ],
  standing: LeaderboardStanding(rank: 51, score: 180),
  cohortSize: 60,
);

/// The same five rows, with the streaks **disagreeing** with the scores.
///
/// `eva/redesign.html:1067` invents the monthly and all-time light figures by
/// scaling the weekly one, and this client does not (ADR-0022 `:97-104`), so the
/// two metrics are ranked by two different numbers the payload already carries.
/// This fixture is the one where they rank **differently** — Karim has the
/// smallest score and the largest streak — so switching the metric moves a row
/// between the podium and the list, which is the only way to see the re-rank.
const LeaderboardBoard _streaksDisagree = LeaderboardBoard(
  window: LeaderboardWindow.weekly,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      rank: 1,
      score: 1280,
      currentStreak: 3,
      initials: 'PG',
      userId: 'u1',
      fullName: 'Peter George',
    ),
    LeaderboardRow(
      rank: 2,
      score: 940,
      currentStreak: 12,
      initials: 'DM',
      userId: 'u2',
      fullName: 'David Mina',
    ),
    LeaderboardRow(
      rank: 3,
      score: 610,
      currentStreak: 7,
      initials: 'MA',
      userId: 'u3',
      fullName: 'Mariam Anton',
    ),
    LeaderboardRow(
      rank: 4,
      score: 420,
      currentStreak: 1,
      initials: 'AS',
      userId: 'u4',
      fullName: 'Ana Silva',
    ),
    LeaderboardRow(
      rank: 5,
      score: 210,
      currentStreak: 20,
      initials: 'KN',
      userId: 'u5',
      fullName: 'Karim Nabil',
    ),
  ],
  standing: LeaderboardStanding(rank: 4, score: 420),
  cohortSize: 5,
);

/// The reader's session.
///
/// The **real** port shape (`signIn` takes two named strings, `UserRole` is the
/// role enum) — an implementation of a port this repository does not own would
/// compile against a stale signature and pass for a reason the screen never had.
///
/// The session is the reader in [_five]: `u4`, "Ana Silva". So the you-card's
/// fallback name and the reader's own row say the same thing, and a test that
/// confuses the two is confusing two facts about one reader.
final class _StubAuthRepo implements AuthRepository {
  const _StubAuthRepo();

  @override
  Future<Result<AuthSession>> getCurrentSession() async =>
      Result<AuthSession>.of(
        AuthSession(
          userId: 'u4',
          displayName: 'Ana Silva',
          email: 'ana@example.com',
          initials: 'AS',
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

/// A repository that answers with a fixed board and remembers every window.
///
/// [failFrom] is the request number from which requests start failing, so a
/// test can let the screen load successfully, break the **next** request, and
/// reach the failed arm with a window already chosen — which is the state
/// `retry` has to get right.
final class _RecordingRepo implements LeaderboardRepository {
  _RecordingRepo(this.answer, {this.failFrom = 1 << 30});

  /// The board every successful request answers with.
  LeaderboardBoard answer;

  /// Requests at or after this index fail. Large by default, so a repo succeeds.
  int failFrom;

  /// The windows requested, in order. The **first** entry is the screen's own
  /// initial load, so a window switch is asserted on the whole list rather than
  /// on its tail.
  final List<LeaderboardWindow> asked = <LeaderboardWindow>[];

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    asked.add(window);
    if (asked.length >= failFrom) {
      return const Left<Failure, LeaderboardBoard>(
        Failure(
          kind: FailureKind.network,
          message: 'Could not reach the server.',
        ),
      );
    }
    return Result<LeaderboardBoard>.of(answer);
  }
}

/// A repository that never answers.
///
/// The only way a `Future`-based cubit can be **held** in its loading arm: a
/// repository that answers on the first microtask drain is past the loading arm
/// by the time the first `pump()` returns.
final class _NeverRepo implements LeaderboardRepository {
  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) => Completer<Result<LeaderboardBoard>>().future;
}

/// The real cheer port, with a count of the writes that reached it.
///
/// The **real** [LocalCheerRepository] is what holds the once rule, so it is
/// what this counts rather than a set of its own: a fake with a `Set` of its
/// own would be a second implementation of the rule the test is about, and a
/// test that agreed with itself would prove nothing.
final class _CountingCheerRepository implements CheerRepository {
  _CountingCheerRepository()
    : _inner = LocalCheerRepository(CheerLocalDataSource());

  final CheerRepository _inner;

  /// Every id the screen asked to cheer, in order.
  final List<String> asked = <String>[];

  @override
  Future<Result<Set<String>>> cheeredUserIds() => _inner.cheeredUserIds();

  @override
  Future<Result<void>> cheer(String userId) {
    asked.add(userId);
    return _inner.cheer(userId);
  }
}

/// Advances [tester] until the board has arrived.
///
/// **Not `pumpAndSettle`.** The loading arm draws a `CircularProgressIndicator`,
/// which repeats forever, so settling is a timeout rather than a green tick.
/// A fixed number of frames is the honest instrument here: the cubit's own
/// chain (`loadLeaderboard`, then the session, then the cheer set) resolves over
/// three microtask turns, and four frames is more than enough.
Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Advances [tester] past the podium's entrance animation.
///
/// The podium's bars are drawn inside a `Transform.scale` that runs for 600 ms,
/// so a bar measured while it is still growing is a bar on its way up. The
/// measurement this file takes is of the **painted** box (see [_paintedSize]),
/// so the animation has to be finished before the number means anything.
Future<void> _settlePastPodium(WidgetTester tester) async {
  await _settle(tester);
  // **1000ms, and the number is not round.** The podium's three columns each
  // grow for 600ms from their own delay (120 / 200 / 280ms —
  // `eva/redesign.html:1097`), so the last one finishes at 280 + 600 = **880ms**
  // and the spring overshoots on the way. 800ms was inside that window, and a
  // measurement taken there is a measurement of the animation rather than of
  // the podium at rest.
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump();
}

/// The box a reader sees, after any ancestor `Transform` has scaled it.
///
/// `RenderBox.size` is the **layout** size, and the podium's bar is laid out at
/// its full height and then scaled down by the entrance animation — so the
/// layout size would report the bar's final height while the reader is looking
/// at a bar that is still growing. The painted size is what `localToGlobal`
/// reports, because it walks the whole ancestor transform chain.
Size _paintedSize(WidgetTester tester, Finder finder) {
  final RenderBox box = tester.renderObject<RenderBox>(finder);
  final Offset topLeft = box.localToGlobal(Offset.zero);
  final Offset bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
  );
  return Size(bottomRight.dx - topLeft.dx, bottomRight.dy - topLeft.dy);
}

/// The podium's three columns, left to right.
///
/// The prototype's order is **2nd, 1st, 3rd** (`eva/redesign.html:1085`'s
/// `order=[{i:1,…},{i:0,…},{i:2,…}]`), so the leftmost column is the second
/// place and the middle one is the first. Each column is a `Column`, and the
/// podium's own `Row` and `Stack` are not, so the match is exactly three.
Finder _podiumColumns() => find.descendant(
  of: find.byType(CommunionPodium),
  matching: find.byType(Column),
);

/// The orb inside one podium column.
///
/// The orbs are the `Container`s whose decoration is a `BoxDecoration` with
/// `shape: BoxShape.circle`; the bars are the ones whose decoration has a
/// `borderRadius`. The two are told apart by their decoration rather than by
/// their order, because the order inside a column is an implementation detail.
Container _orbOf(WidgetTester tester, Finder column) => tester
    .widgetList<Container>(
      find.descendant(of: column, matching: find.byType(Container)),
    )
    .firstWhere((Container container) {
      final Decoration? decoration = container.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    });

/// The bar inside one podium column.
Container _barOf(WidgetTester tester, Finder column) => tester
    .widgetList<Container>(
      find.descendant(of: column, matching: find.byType(Container)),
    )
    .firstWhere((Container container) {
      final Decoration? decoration = container.decoration;
      return decoration is BoxDecoration && decoration.borderRadius != null;
    });

/// The row tile's own box — the outermost `Container` inside it.
///
/// The tile's other `Container` is the monogram orb, so the first one in tree
/// order is the row's own box, which is where the reader's gold rail is drawn.
Container _rowBoxOf(WidgetTester tester, Finder tile) => tester
    .widgetList<Container>(
      find.descendant(of: tile, matching: find.byType(Container)),
    )
    .first;

/// The monogram orb inside one row tile.
Container _rowOrbOf(WidgetTester tester, Finder tile) => tester
    .widgetList<Container>(
      find.descendant(of: tile, matching: find.byType(Container)),
    )
    .firstWhere((Container container) {
      final Decoration? decoration = container.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    });

/// The text of the countdown line.
String _countdownText(WidgetTester tester) =>
    tester
        .widget<Text>(
          find.descendant(
            of: find.byType(CommunionCountdownLine),
            matching: find.byType(Text),
          ),
        )
        .data ??
    '';

/// Every string the you-card rendered.
List<String> _youCardText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(CommunionYouCard),
        matching: find.byType(Text),
      ),
    )
    .map((Text text) => text.data ?? '')
    .toList();

/// The entrance's opacity for one row tile, or `1` when the row is at rest.
///
/// The fade's `Opacity` is the **outermost** one in the tile, so it is the
/// first in tree order; and it is **gone** once the row has arrived, which is
/// the point of dropping it (an `Opacity` at 1.0 is still a composited layer,
/// and a board can carry fifty of them).
double _entranceOpacity(WidgetTester tester, Finder tile) {
  final Finder fades = find.descendant(
    of: tile,
    matching: find.byType(Opacity),
  );
  if (fades.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(fades.first).opacity;
}

/// Pumps `/communion` over [repo] and returns the settings the screen reads.
///
/// The `settingsScope` wrapper is **not** optional. `CommunionPage` reads the
/// veil and the podium toggle through `SettingsScope.of`, which falls back to
/// the locator's registered handle when no scope is above the context — and
/// that fallback is **not watched**, so a page pumped bare would never rebuild
/// when the veil was turned on. The wrapper is what makes the veil toggle a
/// screen behaviour rather than a settings value.
Future<SettingsHarness> _pumpCommunion(
  WidgetTester tester,
  LeaderboardRepository repo, {
  UserSettings? settings,
  CheerRepository? cheerRepository,
  Size size = kAmbientSurface,
}) async {
  final SettingsHarness harness = settingsHarness(
    initial: settings,
    // Loaded here rather than left to the harness's own unawaited call, so the
    // settings the first frame reads are the seeded ones and not the defaults.
    loadImmediately: false,
  );
  await harness.cubit.load();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: LoadLeaderboard(repo),
    getReaderSession: const GetBoardReaderSession(_StubAuthRepo()),
    cheerRepository:
        cheerRepository ?? LocalCheerRepository(CheerLocalDataSource()),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      size: size,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: settingsScope(tester, CommunionPage(cubit: cubit)),
    ),
  );
  await _settle(tester);
  return harness;
}

void main() {
  group('the loading arm', () {
    testWidgets('shows a spinner, and no rows and no error', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _NeverRepo());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LeaderboardRowTile), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
      // The countdown is gated on a board being in hand, and there is none.
      expect(find.byType(CommunionCountdownLine), findsNothing);
    });
  });

  group('the podium', () {
    testWidgets('the columns run 2nd, 1st, 3rd from left to right', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));
      final Finder columns = _podiumColumns();
      expect(columns, findsNWidgets(3));

      // `eva/redesign.html:1085` — `order=[{i:1,cls:'p2'},{i:0,cls:'p1'},{i:2,cls:'p3'}]`.
      // The names are read off the rendered columns, so the assertion is about
      // the screen and not about the order the rows happen to be in.
      expect(
        find.descendant(of: columns.at(0), matching: find.text('David Mina')),
        findsOneWidget,
        reason: 'the leftmost column is the SECOND place',
      );
      expect(
        find.descendant(of: columns.at(1), matching: find.text('Peter George')),
        findsOneWidget,
        reason: 'the middle column is the FIRST place',
      );
      expect(
        find.descendant(of: columns.at(2), matching: find.text('Mariam Anton')),
        findsOneWidget,
        reason: 'the rightmost column is the THIRD place',
      );
    });

    testWidgets('the bars are 84, 112 and 64 pixels tall', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));
      await _settlePastPodium(tester);
      final Finder columns = _podiumColumns();

      // `eva/redesign.html:1085` — `{i:1,…,h:84}`, `{i:0,…,h:112}`, `{i:2,…,h:64}`.
      final List<double> heights = <double>[
        for (int index = 0; index < 3; index++)
          _paintedSize(
            tester,
            find.byWidget(_barOf(tester, columns.at(index))),
          ).height,
      ];

      expect(heights[0], closeTo(84, 0.01));
      expect(heights[1], closeTo(112, 0.01));
      expect(heights[2], closeTo(64, 0.01));
    });

    testWidgets('the orbs are 40, 46 and 36 pixels across', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));
      await _settlePastPodium(tester);
      final Finder columns = _podiumColumns();

      // `eva/redesign.html:1085` — `{i:1,…,o:40}`, `{i:0,…,o:46}`, `{i:2,…,o:36}`.
      final List<double> widths = <double>[
        for (int index = 0; index < 3; index++)
          _paintedSize(
            tester,
            find.byWidget(_orbOf(tester, columns.at(index))),
          ).width,
      ];

      expect(widths[0], closeTo(40, 0.01));
      expect(widths[1], closeTo(46, 0.01));
      expect(widths[2], closeTo(36, 0.01));
    });
  });

  group('the you-card', () {
    testWidgets('names the reader, their position and their value', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));
      final Finder card = find.byType(CommunionYouCard);

      // `eva/redesign.html:1103` prints the reader's name, `:1102` the position
      // and `:1104` the value.
      expect(
        find.descendant(of: card, matching: find.text('Ana Silva · you')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('420')),
        findsOneWidget,
      );
    });

    testWidgets('names the witness above and the exact gap', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));

      // `eva/redesign.html:1105-1106` — the gap is to the witness **one place
      // above** (Mariam Anton, 610) and not to the leader: 610 − 420 = 190, and
      // the prototype's `Math.max(1, Math.ceil(gap/15))` is 13 verses.
      expect(
        find.descendant(
          of: find.byType(CommunionYouCard),
          matching: find.text(
            'Mariam Anton holds 190 more light · pass with ≈13 verses',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to the session name and prints no value', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_withoutReader));
      final Finder card = find.byType(CommunionYouCard);

      expect(
        find.descendant(of: card, matching: find.text('Ana Silva · you')),
        findsOneWidget,
        reason: 'the reader is not in the payload, so the session names them',
      );
      expect(
        find.descendant(of: card, matching: find.text('Not ranked yet')),
        findsOneWidget,
      );

      // **No number at all.** A reader the payload does not rank has no metric
      // value this card could print, and a fabricated `0` would tell a reader
      // with 420 points that they have none.
      final List<String> shown = _youCardText(tester);
      expect(
        shown,
        isNotEmpty,
        reason:
            'the you-card rendered no text at all, so "it printed no number" '
            'would be true of an empty card rather than of a card that '
            'declined to invent one.',
      );
      expect(
        shown.any((String text) => RegExp(r'^\d+$').hasMatch(text)),
        isFalse,
        reason:
            'the you-card printed a number for a reader the payload does not '
            'rank. "Never fabricate rank/value" is the rule; a `0` is a '
            'fabrication.',
      );
    });

    testWidgets('the reader the page does not carry keeps the server\'s rank', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_beyondThePage));
      final Finder card = find.byType(CommunionYouCard);

      // **The server's rank, which is a real number.** The page carries the
      // top of the cohort and the reader is 51st, so their own row is not on
      // it — but the server ranks them, and the card says so instead of
      // claiming they are unranked.
      expect(
        find.descendant(of: card, matching: find.text('51')),
        findsOneWidget,
      );
      // **And the server's score**, which under the `light` metric is the
      // light metric's own number (`my_standing` is `{rank, score}`).
      expect(
        find.descendant(of: card, matching: find.text('180')),
        findsOneWidget,
      );
    });

    testWidgets('on the streak board the same reader is unranked ON IT', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_beyondThePage));
      await tester.tap(find.text('STREAKS'));
      await _settle(tester);
      final Finder card = find.byType(CommunionYouCard);

      // **No position and no value.** The standing carries no streak, so the
      // client cannot place the reader on a streak board, and a number it
      // cannot compute is a number it may not print.
      expect(
        find.descendant(of: card, matching: find.text('51')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('180')),
        findsNothing,
      );
      // **And the card says the reader is unranked — on this board.** The
      // metric's own name is what scopes the claim: the reader IS ranked on
      // the light board, which is the board the server ranked them on.
      expect(
        find.descendant(
          of: card,
          matching: find.text('Not ranked yet · streaks'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the fallback monogram follows the mapper\'s token rule', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: const CommunionYouCard(
            readerRow: null,
            sortedRows: <LeaderboardRow>[],
            metric: LeaderboardMetric.light,
            isVeiled: false,
            fallbackName: 'Ana Maria Silva',
          ),
        ),
      );
      await tester.pump();

      // `LeaderboardMapper.initialsOf` takes the **first and the last**
      // token, so a three-word name reads `AS` and not `AM` — the family
      // name is the one that tells two children apart. The card's fallback
      // is a replication of that rule, and the card and the row must not
      // disagree about one person.
      expect(find.text('AS'), findsOneWidget);
      expect(find.text('AM'), findsNothing);
    });
  });

  group('the countdown line', () {
    testWidgets('the weekly line names a duration', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));

      expect(find.byType(CommunionCountdownLine), findsOneWidget);
      expect(
        _countdownText(tester),
        matches(RegExp(r'^resets in ≈\d+d \d+h$')),
        reason: '`eva/redesign.html:1082` composes the days and the hours',
      );
    });

    testWidgets('the monthly line names a duration', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five.copyWith(window: LeaderboardWindow.monthly)),
      );

      expect(find.byType(CommunionCountdownLine), findsOneWidget);
      expect(
        _countdownText(tester),
        matches(RegExp(r'^resets in ≈\d+d \d+h$')),
      );
    });

    testWidgets('the all-time window says there is no reset', (
      WidgetTester tester,
    ) async {
      final _RecordingRepo repo = _RecordingRepo(
        _five.copyWith(window: LeaderboardWindow.allTime),
      );
      await _pumpCommunion(tester, repo);

      await tester.tap(find.text('ALL'));
      await _settle(tester);

      expect(repo.asked.last, LeaderboardWindow.allTime);
      // `eva/redesign.html:1081` — `ms == null ? tr('noReset')`.
      expect(_countdownText(tester), 'no reset · the sky remembers');
    });

    testWidgets('the line follows the RESPONSE window, not the requested one', (
      WidgetTester tester,
    ) async {
      final _RecordingRepo repo = _RecordingRepo(
        _five.copyWith(window: LeaderboardWindow.allTime),
      );
      await _pumpCommunion(tester, repo);

      // The screen asked for the **weekly** board and the server answered the
      // all-time one. A line that counted down to the *requested* window would
      // have named a duration over a board that is not that window's — which is
      // exactly the mismatch `LeaderboardBoard.window` exists to catch.
      expect(repo.asked, <LeaderboardWindow>[LeaderboardWindow.weekly]);
      expect(_countdownText(tester), 'no reset · the sky remembers');
    });
  });

  group('the veil', () {
    testWidgets('hides every other witness and leaves the reader alone', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five),
        settings: const UserSettings(veilWitnesses: true),
      );

      // `eva/redesign.html:1070` — `witness ${N(idx+1)}`. The podium's columns
      // are 1st, 2nd and 3rd, and the list's bottom row is the fifth.
      expect(find.text('witness 1'), findsOneWidget);
      expect(find.text('witness 2'), findsOneWidget);
      expect(find.text('witness 3'), findsOneWidget);
      expect(find.text('witness 5'), findsOneWidget);

      expect(find.text('Peter George'), findsNothing);
      expect(find.text('David Mina'), findsNothing);
      expect(find.text('Mariam Anton'), findsNothing);
      expect(find.text('Karim Nabil'), findsNothing);

      // **The reader is never veiled** — the prototype checks the reader
      // *before* the veil (`:1069-1070`), and a reader hiding from themselves
      // is not a privacy control.
      expect(find.text('witness 4'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LeaderboardRowTile),
          matching: find.text('Ana Silva · you'),
        ),
        findsOneWidget,
      );

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(CommunionPage).evaluate().isNotEmpty,
        surface: 'the veiled board',
      );
    });

    testWidgets("a veiled witness's monogram becomes a painted hollow star", (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five),
        settings: const UserSettings(veilWitnesses: true),
      );
      final Finder tiles = find.byType(LeaderboardRowTile);

      // `eva/redesign.html:1072` — `monogram()` returns the hollow `✧` for a
      // veiled witness, and U+2727 is in no bundled family, so it is painted.
      final FourPointedStar star = tester.widget<FourPointedStar>(
        find.descendant(of: tiles.last, matching: find.byType(FourPointedStar)),
      );
      expect(star.outline, isTrue);
      expect(
        find.descendant(
          of: tiles.first,
          matching: find.byType(FourPointedStar),
        ),
        findsNothing,
        reason: "the reader's own monogram is never veiled",
      );
    });

    testWidgets("a veiled row's accessible name cannot leak the name", (
      WidgetTester tester,
    ) async {
      // `try`/`finally` around the semantics handle, and **not** `addTearDown`:
      // a handle disposed after the body returns is the binding's "a
      // SemanticsHandle was active at the end of the test", which says nothing
      // about the label.
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpCommunion(
          tester,
          _RecordingRepo(_five),
          settings: const UserSettings(veilWitnesses: true),
        );

        // The announcement follows the rendered name, so a voice-over user
        // cannot hear what the screen is forbidden to show.
        //
        // **The middle of the sentence is matched, not spelled.** The row's
        // announcement is `leaderboardRowSemantics`, and that message carries
        // the row's two numbers — the points and the streak count — so the
        // exact wording is the string table's business and not this test's.
        // What this test is about is the **identity** half: the witness is
        // named by their position and never by their name.
        expect(
          find.bySemanticsLabel('210 points, 2 streaks, witness 5, rank 5'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('Karim')), findsNothing);

        // The reader's own row still announces their monogram and says so.
        expect(
          find.bySemanticsLabel(
            '420 points, 4 streaks, AS, rank 4, that is you',
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'the app-bar button turns the veil on and the screen rebuilds',
      (WidgetTester tester) async {
        final SettingsHarness harness = await _pumpCommunion(
          tester,
          _RecordingRepo(_five),
        );
        expect(find.text('Peter George'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await _settle(tester);

        expect(harness.settings.veilWitnesses, isTrue);
        expect(find.text('Peter George'), findsNothing);
        expect(find.text('witness 1'), findsOneWidget);
      },
    );

    testWidgets('the toast names the veiled witness, not their name', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five),
        settings: const UserSettings(veilWitnesses: true),
      );

      await tester.tap(find.text('witness 5'));
      await _settle(tester);

      // The toast is a **spoken** name as much as a painted one, so the veil
      // has to reach it: a voice-over user must not hear what the screen is
      // forbidden to show.
      expect(find.text('cheer sent to witness 5'), findsOneWidget);
      expect(find.text('cheer sent to Karim Nabil'), findsNothing);
    });
  });

  group('the cheer', () {
    testWidgets('a tap on another witness shows the toast and marks the row', (
      WidgetTester tester,
    ) async {
      // `try`/`finally` around the semantics handle: a handle disposed after
      // the body returns is the binding's "a SemanticsHandle was active at the
      // end of the test", which says nothing about the announcement.
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final _CountingCheerRepository cheers = _CountingCheerRepository();
        await _pumpCommunion(
          tester,
          _RecordingRepo(_five),
          cheerRepository: cheers,
        );

        await tester.tap(find.text('Karim Nabil'));
        await _settle(tester);

        expect(cheers.asked, <String>['u5']);
        expect(find.byType(CommunionCheerToast), findsOneWidget);
        // `eva/redesign.html:1122` — `cheerSent` names the witness.
        expect(find.text('cheer sent to Karim Nabil'), findsOneWidget);

        // The toast is **announced**, not just painted: it is a confirmation
        // that arrives after the reader's tap, and a screen-reader user would
        // otherwise never know it happened.
        final List<SemanticsData> live = semanticsTree(tester)
            .where((SemanticsData data) => data.flagsCollection.isLiveRegion)
            .toList();
        expect(
          live.any(
            (SemanticsData data) =>
                data.label.contains('cheer sent to Karim Nabil'),
          ),
          isTrue,
          reason: 'the toast is wrapped in `Semantics(liveRegion: true)`',
        );

        // **The mark is state, not an effect.** It is a gold ring on the orb
        // (`eva/redesign.html:327`'s `.brow.cheered .borb`) and it outlives the
        // toast.
        final Container orb = _rowOrbOf(
          tester,
          find.byType(LeaderboardRowTile).last,
        );
        final BoxDecoration decoration = orb.decoration as BoxDecoration;
        final Border ring = decoration.border! as Border;
        expect(
          ring.top.color,
          EvaThemeDark.theme.extension<EvaColors>()!.emberInk,
        );
        expect(ring.top.width, 1.5);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'the toast is dismissed after 1800 ms and the mark outlives it',
      (WidgetTester tester) async {
        final _CountingCheerRepository cheers = _CountingCheerRepository();
        await _pumpCommunion(
          tester,
          _RecordingRepo(_five),
          cheerRepository: cheers,
        );

        await tester.tap(find.text('Karim Nabil'));
        await _settle(tester);
        expect(find.byType(CommunionCheerToast), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1900));
        await tester.pump();
        expect(find.byType(CommunionCheerToast), findsNothing);

        // The ring is still there: the cheer is a fact about the session, and
        // the toast is only how it was announced.
        final Container orb = _rowOrbOf(
          tester,
          find.byType(LeaderboardRowTile).last,
        );
        final BoxDecoration decoration = orb.decoration as BoxDecoration;
        final Border ring = decoration.border! as Border;
        expect(ring.top.width, 1.5);
      },
    );

    testWidgets('a second tap on the same witness does not cheer again', (
      WidgetTester tester,
    ) async {
      final _CountingCheerRepository cheers = _CountingCheerRepository();
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five),
        cheerRepository: cheers,
      );

      await tester.tap(find.text('Karim Nabil'));
      await _settle(tester);
      expect(cheers.asked, <String>['u5']);

      // The toast is let go before the second tap. It is drawn over the bottom
      // of the list, so a tap that landed on it would never reach the row —
      // and the assertion below would then pass because the tap went
      // nowhere, not because the once rule held.
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump();
      expect(find.byType(CommunionCheerToast), findsNothing);

      await tester.tap(find.text('Karim Nabil'));
      await _settle(tester);

      // `eva/redesign.html:1120` — `if(cheered.has(p.id)) return;`. The port is
      // asked once, however many times the row is tapped, and the screen does
      // not announce a cheer it did not perform.
      expect(cheers.asked, <String>['u5']);
      expect(find.byType(CommunionCheerToast), findsNothing);
    });

    testWidgets(
      'the toast is anchored to the viewport and never swallows a row\'s tap',
      (WidgetTester tester) async {
        // A board long enough to scroll, on a surface short enough to need it.
        final _CountingCheerRepository cheers = _CountingCheerRepository();
        await _pumpCommunion(
          tester,
          _RecordingRepo(_long),
          cheerRepository: cheers,
        );
        await _settlePastPodium(tester);

        // Cheer a witness whose row is on screen, and **do not scroll**: the
        // toast must be visible right here, not at the far end of the content.
        await tester.tap(find.text('Karim Nabil'));
        await _settle(tester);
        expect(find.byType(CommunionCheerToast), findsOneWidget);

        // ## AND IT IS **IN THE VIEWPORT**
        //
        // `eva/redesign.html:466` anchors the toast to the screen root
        // (`position:absolute; bottom:110px`), and the element is a child of the
        // screen (`:738`) — not of the scrolling list. Anchored to the content
        // instead, it sat below the fold: the confirmation the prototype
        // promises was never seen.
        final Rect screen = tester.getRect(find.byType(CommunionPage));
        final Rect toast = tester.getRect(find.byType(CommunionCheerToast));
        expect(
          screen.contains(toast.topLeft) && screen.contains(toast.bottomRight),
          isTrue,
          reason:
              'the toast left the viewport: the screen is $screen and the toast '
              'is $toast. A confirmation the reader cannot see is not a '
              'confirmation.',
        );

        // ## AND IT **CANNOT BE TAPPED**
        //
        // The prototype's toast rule ends `pointer-events:none` (`:466`). A
        // confirmation is a notice, not a control: it must never take a tap that
        // belonged to the row under it.
        expect(
          tester
              .widgetList<IgnorePointer>(
                find.ancestor(
                  of: find.byType(CommunionCheerToast),
                  matching: find.byType(IgnorePointer),
                ),
              )
              .where((IgnorePointer pointer) => pointer.ignoring),
          isNotEmpty,
          reason:
              'the toast is not ignoring pointers, so it can swallow a tap. '
              '`RenderStack.hitTestChildren` tests the last-painted child first '
              'and stops there, so a toast over the last row makes that row '
              'uncheerable for as long as the toast is up.',
        );

        // ## AND THE LAST ROW IS STILL CHEERABLE WHILE THE TOAST IS UP
        //
        // This is the user-visible half of the same defect. Anchored to the
        // content, the toast sat over the **last** row and took its taps, so a
        // reader could not cheer the last witness in the list at all.
        // `ensureVisible` and not a drag: the scaffold's scroll view uses
        // `BouncingScrollPhysics` (the prototype's `overflowY: 'auto'`), and a
        // drag long enough to reach the end of the content **overshoots** it —
        // the list springs past its own end and the row under test ends up
        // hundreds of pixels above the viewport.
        final String lastName = _long.rows.last.fullName;
        await tester.ensureVisible(find.text(lastName));
        await _settle(tester);

        await tester.tap(find.text(lastName));
        await _settle(tester);
        expect(
          cheers.asked,
          contains(_long.rows.last.userId),
          reason:
              'the tap on the last row did not reach the row. The toast is '
              'over it and it is eating the tap.',
        );
      },
    );

    testWidgets("the reader's own row cannot be cheered", (
      WidgetTester tester,
    ) async {
      final _CountingCheerRepository cheers = _CountingCheerRepository();
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five),
        cheerRepository: cheers,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(LeaderboardRowTile),
          matching: find.text('Ana Silva · you'),
        ),
      );
      await _settle(tester);

      // `eva/redesign.html:1119` — only a row that is not the reader gets an
      // `onclick`, so the reader's row has no tap target at all.
      expect(cheers.asked, isEmpty);
      expect(find.byType(CommunionCheerToast), findsNothing);
    });
  });

  group('the empty state', () {
    testWidgets('an empty cohort renders the empty state, not a blank panel', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_empty));

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No scores yet'), findsOneWidget);
      expect(find.byType(CommunionPodium), findsNothing);
      expect(find.byType(LeaderboardRowTile), findsNothing);
      expect(find.byType(CommunionYouCard), findsNothing);
    });
  });

  group('the failure arm', () {
    testWidgets('a failed load renders the error view with its own message', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(
        tester,
        // The very first request fails, so the screen never reaches the board.
        _RecordingRepo(_five, failFrom: 1),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      final ErrorView view = tester.widget<ErrorView>(find.byType(ErrorView));
      expect(view.message, contains('Could not reach the server.'));
      expect(find.byType(LeaderboardRowTile), findsNothing);
      // The countdown is gated on a board being in hand, and a failure has none.
      expect(find.byType(CommunionCountdownLine), findsNothing);
    });

    testWidgets('retry re-requests the failed window', (
      WidgetTester tester,
    ) async {
      final _RecordingRepo repo = _RecordingRepo(_five, failFrom: 2);
      await _pumpCommunion(tester, repo);
      expect(repo.asked, <LeaderboardWindow>[LeaderboardWindow.weekly]);

      await tester.tap(find.text('MONTH'));
      await _settle(tester);
      expect(repo.asked, <LeaderboardWindow>[
        LeaderboardWindow.weekly,
        LeaderboardWindow.monthly,
      ]);
      expect(find.byType(ErrorView), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await _settle(tester);

      // **The window on screen, not a reset to weekly.** A retry that forgot
      // it would show the reader a ranking for a different period than the one
      // they selected.
      expect(repo.asked, hasLength(3));
      expect(repo.asked.last, LeaderboardWindow.monthly);
    });
  });

  group('the controls', () {
    testWidgets('the window control re-requests with the chosen window', (
      WidgetTester tester,
    ) async {
      final _RecordingRepo repo = _RecordingRepo(_five);
      await _pumpCommunion(tester, repo);
      expect(repo.asked, <LeaderboardWindow>[LeaderboardWindow.weekly]);

      await tester.tap(find.text('MONTH'));
      await _settle(tester);

      expect(repo.asked, <LeaderboardWindow>[
        LeaderboardWindow.weekly,
        LeaderboardWindow.monthly,
      ]);
    });

    testWidgets('the metric control re-ranks without a new request', (
      WidgetTester tester,
    ) async {
      final _RecordingRepo repo = _RecordingRepo(_streaksDisagree);
      await _pumpCommunion(tester, repo);
      final Finder tiles = find.byType(LeaderboardRowTile);
      expect(repo.asked, hasLength(1));

      // Under `light` the board is the wire order: Karim is fifth, so he is in
      // the list, and Peter is first, so he is in the podium.
      expect(
        find.descendant(of: tiles, matching: find.text('Karim Nabil')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tiles, matching: find.text('Peter George')),
        findsNothing,
      );

      await tester.tap(find.text('STREAKS'));
      await _settle(tester);

      // The metric is **presentation-only** (`eva/redesign.html:623-625`): both
      // numbers are on every row the one response carried, so switching is a
      // re-rank of the board already in hand.
      expect(repo.asked, hasLength(1));
      expect(
        find.descendant(of: tiles, matching: find.text('Peter George')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tiles, matching: find.text('Karim Nabil')),
        findsNothing,
      );
    });
  });

  group('the podium toggle', () {
    testWidgets('hiding the podium leaves the top three off the list', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(
        tester,
        _RecordingRepo(_five),
        settings: const UserSettings(showPodium: false),
      );

      expect(find.byType(CommunionPodium), findsNothing);
      // **The count, not just the absence.** The list is `sorted.slice(3)`
      // whether or not the podium is drawn (`eva/redesign.html:1084` and
      // `:1110`), so a five-row board still shows two rows and the top three
      // are absent from the list rather than promoted into it.
      expect(find.byType(LeaderboardRowTile), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(LeaderboardRowTile),
          matching: find.text('Peter George'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(LeaderboardRowTile),
          matching: find.text('Ana Silva · you'),
        ),
        findsOneWidget,
      );
    });
  });

  group("the reader's own row", () {
    testWidgets('carries a gold rail on its leading edge', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));
      final Finder readerTile = find.ancestor(
        of: find.text('Ana Silva · you'),
        matching: find.byType(LeaderboardRowTile),
      );
      expect(readerTile, findsOneWidget);

      final Container box = _rowBoxOf(tester, readerTile);
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      final Border rail = decoration.border! as Border;

      // `eva/redesign.html:325` — `box-shadow:inset 3px 0 0 var(--gold)`.
      // Flutter's `BoxShadow` has no inset variant, so the rail is a 3px
      // leading `Border` on the row's own box, and the RTL arm mirrors it.
      expect(rail.left.width, 3);
      expect(
        rail.left.color,
        EvaThemeDark.theme.extension<EvaColors>()!.emberInk,
      );
    });

    testWidgets("carries the 'you' suffix on its own name", (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));

      // `eva/redesign.html:1116` — `${dispName(p,idx)}${p.id==='you'?` ·
      // ${tr('you')}`:''}`.
      expect(
        find.descendant(
          of: find.byType(LeaderboardRowTile),
          matching: find.text('Ana Silva · you'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CommunionYouCard),
          matching: find.text('Ana Silva · you'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the rows\' entrance', () {
    testWidgets('the list rows fade in and rise, on the prototype\'s stagger', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _RecordingRepo(_five));
      final Finder tiles = find.byType(LeaderboardRowTile);
      expect(tiles, findsNWidgets(2));

      // **Nothing has entered yet.** `eva/redesign.html:1126` delays the first
      // row by 80ms, and the board has been on screen for less than that.
      expect(_entranceOpacity(tester, tiles.at(0)), 0);
      expect(_entranceOpacity(tester, tiles.at(1)), 0);

      // The **stagger**: the first row's transition has begun and the second's
      // has not, because the delays are 80ms and 125ms (`80 + k·45`).
      //
      // **The window is walked, not guessed.** It is 45ms wide, and a clock
      // that landed outside it would make this an assertion about the test's
      // timing rather than about the row.
      bool staggered = false;
      for (int step = 0; step < 24 && !staggered; step++) {
        await tester.pump(const Duration(milliseconds: 8));
        staggered =
            _entranceOpacity(tester, tiles.at(0)) > 0 &&
            _entranceOpacity(tester, tiles.at(1)) == 0;
      }
      expect(
        staggered,
        isTrue,
        reason:
            'the second row must not have entered before the first — the '
            'prototype staggers the list by 45ms a row (`eva/redesign.html:1126`).',
      );

      // **And at rest the row is the row.** The fade's wrapper is gone, so
      // the board carries no composited layers.
      await tester.pump(const Duration(milliseconds: 600));
      expect(_entranceOpacity(tester, tiles.at(0)), 1);
      expect(_entranceOpacity(tester, tiles.at(1)), 1);
    });
  });
}
