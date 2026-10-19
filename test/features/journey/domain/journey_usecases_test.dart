import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/journey/domain/usecases/get_journey_reader_session.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_sky_count.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_history.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// The three ports `/journey` reads through, mocked.
///
/// The use cases are `final class`es and cannot be implemented from outside
/// their library, so the seam is the port — exactly as it is in every other
/// feature's use-case suite (`leaderboard_usecases_test.dart`,
/// `home_usecases_test.dart`).
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStreakRepository extends Mock implements StreakRepository {}

class _MockSkyRepository extends Mock implements SkyRepository {}

/// One scheduled day, spelled out.
///
/// A transcription of the live schema's shape (`streak.service.ts:5-17`), not a
/// recording of a live response — the rule `test/support/contract_payloads.dart`
/// states for its own fixtures. `points_earned` is 0 because the server's value
/// is the sum of `points_awarded` over the day's submissions
/// (`streak.service.ts:105`) and nothing here reads it.
const StreakHistoryEntry _oneDay = StreakHistoryEntry(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  scheduledDate: '2026-10-03',
  bookNumber: 43,
  bookNameEn: 'John',
  bookNameAr: 'يوحنا',
  referenceEn: 'John 3:1-5',
  referenceAr: 'يوحنا 3: 1-5',
  totalQuestions: 1,
  answeredQuestions: 1,
  correctAnswers: 1,
  pointsEarned: 0,
  isCompleted: true,
);

void main() {
  late _MockAuthRepository auth;
  late _MockStreakRepository streaks;
  late _MockSkyRepository sky;

  // `final` and not `const`: `DateTime` has no const constructor, so a session
  // cannot be a compile-time constant. The house spelling is the same —
  // `home_usecases_test.dart` builds its session with
  // `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`.
  final AuthSession session = AuthSession(
    userId: '11111111-1111-1111-1111-111111111111',
    email: 'david@example.test',
    displayName: 'David Mina',
    initials: 'DM',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  const StreakSummary summary = StreakSummary(
    currentStreak: 12,
    longestStreak: 30,
    lastCompletedDate: '2026-10-03',
    todayStatus: StreakTodayStatus.completed,
    todayCompleted: true,
    todayScheduled: true,
    nextMilestone: 14,
    daysToMilestone: 2,
  );

  const List<StreakHistoryEntry> history = <StreakHistoryEntry>[_oneDay];

  setUp(() {
    auth = _MockAuthRepository();
    streaks = _MockStreakRepository();
    sky = _MockSkyRepository();

    when(auth.getCurrentSession)
        .thenAnswer((_) async => Right<Failure, AuthSession>(session));
    when(streaks.summary)
        .thenAnswer((_) async => const Right<Failure, StreakSummary>(summary));
    when(streaks.history).thenAnswer(
      (_) async => const Right<Failure, List<StreakHistoryEntry>>(history),
    );
    when(sky.count).thenAnswer((_) async => const Right<Failure, int>(44));
  });

  group('GetJourneyReaderSession', () {
    test('returns the session the port answered', () async {
      expect(
        await GetJourneyReaderSession(auth)(),
        Right<Failure, AuthSession>(session),
      );
    });

    test('and "no session" stays the port\'s failure', () async {
      // `FakeAuthRepository.getCurrentSession` answers
      // `FailureKind.unauthorized, 'Not signed in.'` when there is none, and the
      // port's doc says the caller must not distinguish "no session" from "the
      // check failed". `/journey` draws a **name** and a **monogram** out of
      // this, so both arms render the screen without a name rather than one
      // arm with a name and the other with an error.
      const Failure noSession = Failure(
        kind: FailureKind.unauthorized,
        message: 'Not signed in.',
      );
      when(auth.getCurrentSession)
          .thenAnswer((_) async => const Left<Failure, AuthSession>(noSession));

      expect(
        await GetJourneyReaderSession(auth)(),
        const Left<Failure, AuthSession>(noSession),
      );
    });

    test('and it asks for the *current* session, not a sign-in', () async {
      await GetJourneyReaderSession(auth)();

      verify(auth.getCurrentSession).called(1);
      verifyNever(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });

  group('LoadJourneyStreakSummary', () {
    test('returns what the port answered', () async {
      expect(
        await LoadJourneyStreakSummary(streaks)(),
        const Right<Failure, StreakSummary>(summary),
      );
    });

    test('and a failure is the port\'s failure, unwrapped', () async {
      // The use case adds nothing, and that is the point: a second place that
      // decides what a failure means is a second place to forget. The port's
      // own `FailureKind` is a statement, not a suggestion.
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      when(streaks.summary)
          .thenAnswer((_) async => const Left<Failure, StreakSummary>(failure));

      expect(
        await LoadJourneyStreakSummary(streaks)(),
        const Left<Failure, StreakSummary>(failure),
      );
    });

    test('and it asks for the SUMMARY, not the history', () async {
      await LoadJourneyStreakSummary(streaks)();

      verify(streaks.summary).called(1);
      verifyNever(streaks.history);
    });

    test('and it is a NoParamsUseCase, not a UseCase<void, _>', () async {
      // AGENT_CONTEXT §6, recorded decision 3: `NoParamsUseCase` is a
      // standalone interface, so this assignment is what proves the declared
      // shape compiles. `usecase()` with no argument is the call site; a
      // `UseCase<void, StreakSummary>` would demand one.
      final Future<Result<StreakSummary>> Function() call =
          LoadJourneyStreakSummary(streaks).call;
      expect(await call(), isA<Result<StreakSummary>>());
    });
  });

  group('LoadJourneyStreakHistory', () {
    test('returns the rows the port answered, in the port\'s order', () async {
      final Result<List<StreakHistoryEntry>> result =
          await LoadJourneyStreakHistory(streaks)();

      expect(result.isRight(), isTrue);
      expect(
        (result as Right<Failure, List<StreakHistoryEntry>>).value,
        equals(history),
      );
    });

    test('and a failure is the port\'s failure, unwrapped', () async {
      const Failure failure = Failure(
        kind: FailureKind.serialization,
        message: 'Could not read the streak history: `history` is absent',
      );
      when(streaks.history).thenAnswer(
        (_) async => const Left<Failure, List<StreakHistoryEntry>>(failure),
      );

      expect(
        await LoadJourneyStreakHistory(streaks)(),
        const Left<Failure, List<StreakHistoryEntry>>(failure),
      );
    });

    test('and it asks for the HISTORY, not the summary', () async {
      await LoadJourneyStreakHistory(streaks)();

      verify(streaks.history).called(1);
      verifyNever(streaks.summary);
    });
  });

  group('LoadJourneySkyCount', () {
    test('returns the count the port answered', () async {
      expect(await LoadJourneySkyCount(sky)(), const Right<Failure, int>(44));
    });

    test('and a failure is the port\'s failure, unwrapped', () async {
      const Failure failure = Failure(
        kind: FailureKind.storage,
        message: 'Could not reach the sky store.',
      );
      when(sky.count)
          .thenAnswer((_) async => const Left<Failure, int>(failure));

      expect(
        await LoadJourneySkyCount(sky)(),
        const Left<Failure, int>(failure),
      );
    });

    test('and it asks for the COUNT, not the entries', () async {
      // §3's ISP row: a caller that wants one number depends on the smallest
      // interface that satisfies it, and the port says so itself —
      // `sky_repository.dart` names `count` as the member `journey` reads.
      await LoadJourneySkyCount(sky)();

      verify(sky.count).called(1);
      verifyNever(sky.entries);
    });
  });
}
