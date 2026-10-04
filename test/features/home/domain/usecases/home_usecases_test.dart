import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Home's three use cases — red-first (AGENT_CONTEXT §6: use cases).
///
/// ## WHY THEY ARE `final class` AND THE MOCKABLE SEAM IS THE PORT
///
/// Same shape as `auth_bloc_test.dart`: the use cases cannot be re-implemented
/// outside their library, which is deliberate — a look-alike with one method
/// changed cannot exist. So the seam is [ReadingRepository], [StreakRepository]
/// and [AuthRepository], and the bloc above is built over **real** use cases on
/// top of mocked ports. That is the composition the app has, so this file also
/// exercises the use cases on the way in.
///
/// ## WHY `GetReaderSession` IS HOME'S OWN AND NOT `auth`'s
///
/// `features/auth` already has a `GetCurrentSession` use case, and **`home` may
/// not import it**: §3 forbids a feature importing another with no exceptions and
/// Gate 2 fails on the line. So the same call is declared again on this side of
/// the boundary, over the same port.
///
/// That is duplication and it is the accepted cost of the rule, not an oversight.
/// The rejected alternative — promoting `GetCurrentSession` into
/// `core/domain/usecase/` was weighed and not taken: §3 says a feature's `domain/`
/// holds "this feature's own use cases", and a use case with exactly one
/// caller per feature is that feature's own by the same placement test that put
/// the *port* in the shared kernel. What belongs in the kernel is the thing two
/// features *ask the same question of* (`AuthRepository.getCurrentSession`), and
/// it already is.
class MockReadingRepository extends Mock implements ReadingRepository {}

class MockStreakRepository extends Mock implements StreakRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  // `any(named: 'language')` cannot match a non-nullable enum without one of
  // these. The value is never used — mocktail only needs *a* `ReadingLanguage` to
  // know the type — and it is English because that is the app's first declared
  // locale.
  setUpAll(() => registerFallbackValue(ReadingLanguage.english));

  late MockReadingRepository readings;
  late MockStreakRepository streaks;
  late MockAuthRepository auth;

  final TodayReading today = const TodayReading(
    readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    groupId: 3,
    scheduledDate: '2026-10-03',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV',
    verseCount: 5,
    firstVerseText: 'There was a man of the Pharisees',
    questionCount: 1,
    answeredQuestionCount: 1,
    isFullyCompleted: true,
    pointsEarnedToday: 10,
    currentStreak: 4,
  );

  final StreakSummary summary = const StreakSummary(
    currentStreak: 0,
    longestStreak: 6,
    lastCompletedDate: '2026-09-29',
    todayStatus: StreakTodayStatus.pending,
    todayCompleted: false,
    todayScheduled: true,
    nextMilestone: 3,
    daysToMilestone: 3,
  );

  final AuthSession session = AuthSession(
    userId: '11111111-1111-1111-1111-111111111111',
    email: 'david.mina@evangelion.app',
    displayName: 'David Mina',
    initials: 'DM',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  setUp(() {
    readings = MockReadingRepository();
    streaks = MockStreakRepository();
    auth = MockAuthRepository();

    when(() => readings.today(language: any(named: 'language')))
        .thenAnswer((_) async => Result<TodayReading>.success(today));
    when(streaks.summary)
        .thenAnswer((_) async => Result<StreakSummary>.success(summary));
    when(auth.getCurrentSession)
        .thenAnswer((_) async => Result<AuthSession>.success(session));
  });

  group('LoadTodayReading', () {
    test(
      'passes the language through and returns what the port answered',
      () async {
        final LoadTodayReading usecase = LoadTodayReading(readings);

        final Result<TodayReading> result = await usecase(
          ReadingLanguage.arabic,
        );

        expect(result, Result<TodayReading>.success(today));
        verify(() => readings.today(language: ReadingLanguage.arabic))
            .called(1);
      },
    );

    test('and a failure is the port\'s failure, unwrapped', () async {
      // The use case adds nothing, and that is the point: §3's DIP row says a
      // `domain/` file names a port and nothing else, and a use case that
      // reclassified an error would make the port's own `FailureKind` a
      // suggestion.
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      when(() => readings.today(language: any(named: 'language')))
          .thenAnswer((_) async => const Result<TodayReading>.failure(failure));

      expect(
        await LoadTodayReading(readings)(ReadingLanguage.english),
        const Result<TodayReading>.failure(failure),
      );
    });

    test('and it makes exactly one call — no retry, no prefetch', () async {
      await LoadTodayReading(readings)(ReadingLanguage.english);

      verify(() => readings.today(language: any(named: 'language'))).called(1);
    });
  });

  group('LoadStreakSummary', () {
    test('returns what the port answered', () async {
      expect(
        await LoadStreakSummary(streaks)(),
        Result<StreakSummary>.success(summary),
      );
    });

    test('and a failure is the port\'s failure', () async {
      const Failure failure = Failure(
        kind: FailureKind.serialization,
        message:
            'Could not read the streak summary: `current_streak` is absent',
      );
      when(
        streaks.summary,
      ).thenAnswer((_) async => const Result<StreakSummary>.failure(failure));

      expect(
        await LoadStreakSummary(streaks)(),
        const Result<StreakSummary>.failure(failure),
      );
    });

    test('and it is a NoParamsUseCase, not a UseCase<void, _>', () async {
      // §6 decision 3: `NoParamsUseCase` is a standalone interface, so this
      // assignment is what proves the declared shape compiles. `usecase()` with no
      // argument is the call site; a `UseCase<void, StreakSummary>` would demand
      // one.
      final Future<Result<StreakSummary>> Function() call = LoadStreakSummary(
        streaks,
      ).call;
      expect(await call(), isA<Result<StreakSummary>>());
    });
  });

  group('GetReaderSession', () {
    test('returns the session the port answered', () async {
      expect(
        await GetReaderSession(auth)(),
        Result<AuthSession>.success(session),
      );
    });

    test('and "no session" is a failure, which the bloc turns into no name', () async {
      // `FakeAuthRepository.getCurrentSession` answers
      // `FailureKind.unauthorized, 'Not signed in.'` when there is none. The port's
      // doc says the caller must not distinguish "no session" from "the check
      // failed" — and the thing `/` draws from this is a **name**, so both arms
      // render the greeting without one.
      when(auth.getCurrentSession).thenAnswer(
        (_) async => const Result<AuthSession>.failure(
          Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
        ),
      );

      final Result<AuthSession> result = await GetReaderSession(auth)();

      expect(result.isFailure, isTrue);
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.unauthorized,
      );
    });

    test('and it asks for the *current* session, not a sign-in', () async {
      await GetReaderSession(auth)();

      verify(auth.getCurrentSession).called(1);
      verifyNever(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });
}
