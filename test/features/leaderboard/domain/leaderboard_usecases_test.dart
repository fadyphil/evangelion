import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// Records what it was asked for, so the assertions can be about the *request* rather
/// than about the return value — which for a pass-through is the only thing it has.
final class _RecordingRepository implements LeaderboardRepository {
  _RecordingRepository([this.answer]);

  final Result<LeaderboardBoard>? answer;
  final List<({LeaderboardWindow window, int limit})> calls =
      <({LeaderboardWindow window, int limit})>[];

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async {
    calls.add((window: window, limit: limit));
    return answer ??
        const Right<Failure, LeaderboardBoard>(
          LeaderboardBoard(
            window: LeaderboardWindow.weekly,
            groupId: 3,
            rows: <LeaderboardRow>[],
            standing: null,
            cohortSize: 0,
          ),
        );
  }
}

/// **`LoadLeaderboardPreview` was deleted in Phase 5.2, and this file is the
/// record of where its four tests went.**
///
/// The use case died with the board card: ADR-0022's redesign
/// (`eva/redesign.html:513-538`) draws a home with no board on it, and a use case
/// whose only call site was that card is a registration for a widget that no
/// longer exists (`leaderboard_module.dart`'s doc records the removal from the DI
/// side).
///
/// Three of the four tests were never about the preview. The window passes
/// through unchanged, the limit passes through unchanged, and the repository's
/// failure is returned unwrapped — those are the properties of a pass-through,
/// and `LoadLeaderboard`'s group asserts all three. Asserting them twice against
/// two use cases was the redundancy the pass-through's own doc warns about.
///
/// The fourth — "asks for more than it shows, so the cohort size is provable"
/// (`kLeaderboardPreviewLimit` 50 over `kLeaderboardPreviewRows` 3) — was
/// genuinely preview-shaped: a card that requested exactly the three rows it
/// draws gets `rowsReturned == limit`, the ambiguous case, and can render no
/// total. That decision belongs to whichever surface asks, and `/leaderboard`'s
/// page asks through `LeaderboardCubit`, whose own suite asserts the request. It
/// is not lost; it moved with the screen.
///
/// There is no "the symbol is gone" assertion here, because a test cannot
/// reference a symbol that no longer compiles — the **analyzer** is that
/// assertion, and a reader who re-adds `LoadLeaderboardPreview` will find this
/// paragraph through it.

/// A mocked auth port, for the leaderboard's own `GetBoardReaderSession`.
///
/// The use case is a `final class` and cannot be implemented from outside its
/// library; the seam is the shared port, exactly as it is in every other feature's
/// use-case suite.
class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  // `any(named: 'role')` cannot match a non-nullable enum without one of
  // these. The value is never used — mocktail only needs *a* `UserRole` to
  // know the type.
  setUpAll(() => registerFallbackValue(UserRole.kid));

  const LeaderboardBoard board = LeaderboardBoard(
    window: LeaderboardWindow.monthly,
    groupId: 3,
    rows: <LeaderboardRow>[],
    standing: null,
    cohortSize: 12,
  );

  group('LoadLeaderboard', () {
    test('passes the window and limit through unchanged', () async {
      final _RecordingRepository repository = _RecordingRepository();
      await LoadLeaderboard(repository)(
        const LeaderboardQuery(window: LeaderboardWindow.monthly, limit: 50),
      );
      expect(repository.calls, <({LeaderboardWindow window, int limit})>[
        (window: LeaderboardWindow.monthly, limit: 50),
      ]);
    });

    test("returns the repository's board byte-identical", () async {
      final _RecordingRepository repository = _RecordingRepository(
        const Right<Failure, LeaderboardBoard>(board),
      );
      expect(
        await LoadLeaderboard(repository)(
          const LeaderboardQuery(window: LeaderboardWindow.monthly, limit: 50),
        ),
        const Right<Failure, LeaderboardBoard>(board),
      );
    });

    test("and the repository's failure, unwrapped", () async {
      // The point of a use case that adds nothing: it must not reclassify. A second
      // place that decides what a failure means is a second place to forget.
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      final _RecordingRepository repository = _RecordingRepository(
        const Left<Failure, LeaderboardBoard>(failure),
      );
      expect(
        await LoadLeaderboard(repository)(
          const LeaderboardQuery(window: LeaderboardWindow.monthly, limit: 50),
        ),
        const Left<Failure, LeaderboardBoard>(failure),
      );
    });
  });

  group('GetBoardReaderSession', () {
    late _MockAuthRepository auth;

    setUp(() {
      auth = _MockAuthRepository();
      addTearDown(() => auth);
    });

    final AuthSession session = AuthSession(
      userId: '11111111-1111-1111-1111-111111111111',
      email: 'david@example.test',
      displayName: 'David Mina',
      initials: 'DM',
      createdAt: DateTime.utc(2026),
    );

    test('returns the session the port answered', () async {
      when(auth.getCurrentSession)
          .thenAnswer((_) async => Right<Failure, AuthSession>(session));

      expect(
        await GetBoardReaderSession(auth)(),
        Right<Failure, AuthSession>(session),
      );
    });

    test('and "no session" stays the port\'s failure', () async {
      // `FakeAuthRepository.getCurrentSession` answers
      // `FailureKind.unauthorized, 'Not signed in.'` when there is none. The call is
      // documented not to distinguish "no session" from "the check failed", and the
      // cubit turns both into no fallback name.
      const Failure noSession = Failure(
        kind: FailureKind.unauthorized,
        message: 'Not signed in.',
      );
      when(auth.getCurrentSession)
          .thenAnswer((_) async => const Left<Failure, AuthSession>(noSession));

      expect(
        await GetBoardReaderSession(auth)(),
        const Left<Failure, AuthSession>(noSession),
      );
    });

    test('and it asks for the *current* session, not a sign-in', () async {
      when(auth.getCurrentSession)
          .thenAnswer((_) async => Right<Failure, AuthSession>(session));

      await GetBoardReaderSession(auth)();

      verify(auth.getCurrentSession).called(1);
      verifyNever(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
          role: any(named: 'role'),
        ),
      );
    });
  });
}
