import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/domain/library_catalogue_repository.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_last_light.dart';
import 'package:evangelion/features/home/domain/usecases/load_library_catalogue.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/home_harness.dart';

/// Home's five use cases — red-first (AGENT_CONTEXT §6: use cases).
///
/// ## WHY THEY ARE `final class` AND THE MOCKABLE SEAM IS THE PORT
///
/// Same shape as `auth_bloc_test.dart`: the use cases cannot be re-implemented
/// outside their library, which is deliberate — a look-alike with one method
/// changed cannot exist. So the seam is [ReadingRepository], [StreakRepository]
/// and [AuthRepository] — plus the catalogue port, whose seam is the same shape
/// with one deliberate difference recorded where the group is — and the bloc
/// above is built over **real** use cases on top of mocked ports. That is the
/// composition the app has, so this file also exercises the use cases on the way
/// in.
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

class MockLibraryCatalogueRepository extends Mock
    implements LibraryCatalogueRepository {}

void main() {
  // `any(named: 'language')` cannot match a non-nullable enum without one of
  // these. The value is never used — mocktail only needs *a* `ReadingLanguage` to
  // know the type — and it is English because that is the app's first declared
  // locale.
  setUpAll(() => registerFallbackValue(ReadingLanguage.english));

  late MockReadingRepository readings;
  late MockStreakRepository streaks;
  late MockAuthRepository auth;
  late MockLibraryCatalogueRepository catalogue;

  const TodayReading today = TodayReading(
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

  const StreakSummary summary = StreakSummary(
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
    catalogue = MockLibraryCatalogueRepository();

    when(() => readings.today(language: any(named: 'language')))
        .thenAnswer((_) async => Result<TodayReading>.of(today));
    when(streaks.summary)
        .thenAnswer((_) async => Result<StreakSummary>.of(summary));
    // The port's second method, stubbed beside its sibling: an unstubbed
    // mocktail method returns `null` typed as the future, which fails as
    // "type 'Null' is not a subtype of …" two frames inside the use case rather
    // than as a missing stub — the least readable failure in this file, and the
    // reason the default is here and not at the two tests that care.
    when(streaks.history).thenAnswer(
      (_) async => Result<List<StreakHistoryEntry>>.of(
        const <StreakHistoryEntry>[liveStreakHistoryEntry],
      ),
    );
    when(auth.getCurrentSession)
        .thenAnswer((_) async => Result<AuthSession>.of(session));
    when(catalogue.books).thenAnswer((_) async => Result.of(liveCatalogue));
  });

  group('LoadTodayReading', () {
    test(
      'passes the language through and returns what the port answered',
      () async {
        final LoadTodayReading usecase = LoadTodayReading(readings);

        final Result<TodayReading> result = await usecase(
          ReadingLanguage.arabic,
        );

        expect(result, Result<TodayReading>.of(today));
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
          .thenAnswer((_) async => const Left<Failure, TodayReading>(failure));

      expect(
        await LoadTodayReading(readings)(ReadingLanguage.english),
        const Left<Failure, TodayReading>(failure),
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
        Result<StreakSummary>.of(summary),
      );
    });

    test('and a failure is the port\'s failure', () async {
      const Failure failure = Failure(
        kind: FailureKind.serialization,
        message:
            'Could not read the streak summary: `current_streak` is absent',
      );
      when(streaks.summary)
          .thenAnswer((_) async => const Left<Failure, StreakSummary>(failure));

      expect(
        await LoadStreakSummary(streaks)(),
        const Left<Failure, StreakSummary>(failure),
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
      expect(await GetReaderSession(auth)(), Result<AuthSession>.of(session));
    });

    test('and "no session" is a failure, which the bloc turns into no name', () async {
      // `FakeAuthRepository.getCurrentSession` answers
      // `FailureKind.unauthorized, 'Not signed in.'` when there is none. The port's
      // doc says the caller must not distinguish "no session" from "the check
      // failed" — and the thing `/` draws from this is a **name**, so both arms
      // render the greeting without one.
      when(auth.getCurrentSession).thenAnswer(
        (_) async => const Left<Failure, AuthSession>(
          Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
        ),
      );

      final Result<AuthSession> result = await GetReaderSession(auth)();

      expect(result.isLeft(), isTrue);
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

  group('LoadLastLight', () {
    test('takes the FIRST row, which is the server\'s own "last"', () async {
      // `streak.service.ts:88-96` orders by `scheduled_date DESC`, so
      // `history[0]` is the reader's most recent scheduled day and the use
      // case takes it without a sort. A client sort here would be a second
      // opinion about "last", and one that could disagree with the chip the
      // reader just looked at.
      final Result<StreakHistoryEntry?> result = await LoadLastLight(streaks)();

      expect(result.isRight(), isTrue);
      expect(
        (result as Right<Failure, StreakHistoryEntry?>).value,
        liveStreakHistoryEntry,
      );
    });

    test('an EMPTY history is a null SUCCESS, not a failure', () async {
      // `redesign.html:1192-1197` is the prototype's own empty state — `—` in
      // the eyebrow, `noLight` in the body, and the tap removed. A reader who
      // has never read is in a real state, and an error arm for it would put
      // an `ErrorView` where the prototype draws a sentence.
      when(streaks.history).thenAnswer(
        (_) async =>
            Result<List<StreakHistoryEntry>>.of(const <StreakHistoryEntry>[]),
      );

      final Result<StreakHistoryEntry?> result = await LoadLastLight(streaks)();

      expect(result.isRight(), isTrue);
      expect((result as Right<Failure, StreakHistoryEntry?>).value, isNull);
    });

    test('and a FAILED history stays failed — the defect this use case had', () async {
      // ## THE BUG, MEASURED
      //
      // `LoadLastLight` originally returned
      // `rows.getOrElse((_) => const []).firstOrNull`, which turned a
      // `Result.left` into `Result.of(null)` — so a failed `GET /streak`
      // reached the bloc as *ready with no light*, and the card rendered its
      // empty state ("no light received yet") for a request that had failed.
      // `home_bloc_test.dart`'s "a failed LAST LIGHT" group asked for `failed`
      // and read `ready`.
      //
      // `Result.map` is the fix: the left arm is carried through unchanged,
      // which is the whole of what "a repository never throws and always
      // returns a `Result`" means at this seam. The row below is the regression
      // test, and it is a test rather than a comment because the failure mode
      // is exactly the kind a refactor re-introduces — `getOrElse` reads as the
      // simpler spelling of the same idea.
      when(streaks.history).thenAnswer(
        (_) async => const Left<Failure, List<StreakHistoryEntry>>(
          Failure(
            kind: FailureKind.network,
            message: 'Could not reach the server.',
          ),
        ),
      );

      final Result<StreakHistoryEntry?> result = await LoadLastLight(streaks)();

      expect(result.isLeft(), isTrue);
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.network,
        reason:
            'the port\'s failure, unwrapped — a network failure that arrived as '
            'an empty success is the defect this group exists to keep dead',
      );
    });
  });

  group('LoadLibraryCatalogue', () {
    test('returns what the port answered, unwrapped', () async {
      final Result<List<LibraryBook>> result = await LoadLibraryCatalogue(
        catalogue,
      )();

      expect(result.isRight(), isTrue);
      expect(
        (result as Right<Failure, List<LibraryBook>>).value,
        // **`equals`, not `same`** — and that is a decision the audit gate made
        // for a good reason: `LibraryBook` is a freezed type, so its equality is
        // *structural*, and asserting identity would couple this test to the
        // const-canonicalisation of the fixture list rather than to the
        // pass-through's behaviour. The claim is "the same books in the same"
        // order, which `equals` states and `same` over-constrains.
        equals(liveCatalogue),
      );
    });

    test('and the failure arm is asserted even though it is unreachable', () async {
      // The use case is a pass-through, so the failure arm is the port's — and
      // the shipped adapter is a literal list that *cannot* fail
      // (`library_catalogue_repository_impl.dart`). Asserted anyway, for
      // decision 26's shape: the section exists now so the books endpoint can
      // arrive without building the state machine twice, and the day it stops
      // being literal is the day this arm is the one that matters. Deleting the
      // test because the arm is unreachable today would be deleting the
      // contract the future adapter has to meet.
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      when(catalogue.books).thenAnswer(
        (_) async => const Left<Failure, List<LibraryBook>>(failure),
      );

      final Result<List<LibraryBook>> result = await LoadLibraryCatalogue(
        catalogue,
      )();

      expect(result.isLeft(), isTrue);
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.network,
      );
    });
  });
}
