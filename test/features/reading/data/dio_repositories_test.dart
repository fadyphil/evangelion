import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/reading/data/datasources/reading_remote_data_source.dart';
import 'package:evangelion/features/reading/data/datasources/streak_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';
import 'package:evangelion/features/reading/data/repositories/dio_reading_repository.dart';
import 'package:evangelion/features/reading/data/repositories/dio_streak_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_dio.dart';
import '../../../support/live_payloads.dart';

/// The two Dio repositories, red-first (AGENT_CONTEXT §6 names the mappers and
/// `Result`/`Failure` explicitly; these are the adapters the LSP row is about).
///
/// ## THE WHOLE POINT OF THIS FILE IS THE THIRD GROUP
///
/// §3's LSP row: "Every `ReadingRepository` implementation honours the whole
/// contract, *including the non-obvious parts*: never throws across the seam,
/// always returns `Result`, treats HTTP 409 as a typed failure and never an
/// exception. A `FakeReadingRepository` must be substitutable for
/// `DioReadingRepository`."
///
/// So every [DioExceptionType] is crossed with every status bucket, and the
/// assertion on each is that a [Result] came back — never a throw. That sweep is
/// the mechanism; the happy path and the path assertions are there because a
/// repository that always failed would satisfy the sweep.
///
/// ## WHY BOTH REPOSITORIES ARE IN ONE FILE
///
/// They share the whole of their structure: one `Dio`, one `ApiErrorMapper`, one
/// `GET`, two arms. What differs is the endpoint and the projection. Splitting
/// them would duplicate the sweep — which is the one piece of this file that is
/// expensive and easy to get wrong — and §7 says two implementations of one
/// invariant is two things to keep in step.
void main() {
  setUpAll(registerRequestOptionsFallback);

  late MockAdapter adapter;
  late List<RequestOptions> sent;
  late ReadingRepository readings;
  late StreakRepository streak;

  setUp(() {
    sent = <RequestOptions>[];
    adapter = MockAdapter();
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((Invocation invocation) async {
          sent.add(invocation.positionalArguments.first as RequestOptions);
          return jsonBody('{}', 200);
        });

    final Dio dio = dioWithAdapter(adapter);
    readings = DioReadingRepository(
      dataSource: ReadingRemoteDataSource(dio),
      mapper: const TodayReadingMapper(),
      errors: const ApiErrorMapper(),
    );
    streak = DioStreakRepository(
      dataSource: StreakRemoteDataSource(dio),
      mapper: const StreakSummaryMapper(),
      errors: const ApiErrorMapper(),
    );
  });

  Future<Failure> failureOf(Future<Result<Object?>> call) async {
    final Result<Object?> result = await call;
    expect(result.isFailure, isTrue, reason: 'expected a failure, got $result');
    return (result as FailureResult<Object?>).failure;
  }

  group('ReadingRepository.today — the happy path', () {
    setUp(() {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation invocation) async {
            sent.add(invocation.positionalArguments.first as RequestOptions);
            return jsonBody(kLiveReadingEnJson, 200);
          });
    });

    test('resolves the live payload to the live entity', () async {
      final Result<TodayReading> result = await readings.today(
        language: ReadingLanguage.english,
      );

      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<TodayReading>).value,
        const TodayReading(
          readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          groupId: 3,
          scheduledDate: '2026-10-03',
          language: ReadingLanguage.english,
          reference: 'John 3:1-5',
          translation: 'NKJV (New King James Version)',
          verseCount: 5,
          firstVerseText:
              'There was a man of the Pharisees, named Nicodemus, a '
              'ruler of the Jews:',
          questionCount: 1,
          answeredQuestionCount: 1,
          isFullyCompleted: true,
          pointsEarnedToday: 10,
          currentStreak: 4,
        ),
      );
    });

    test('asks for exactly the one documented URL', () async {
      await readings.today(language: ReadingLanguage.english);

      expect(sent, hasLength(1));
      expect(sent.single.uri.path, '/api/v1/readings/today/en');
      expect(sent.single.method, 'GET');
    });

    test('and the Arabic arm changes only the path segment', () async {
      // The one thing the language parameter is allowed to change. A fixture that
      // also changed the base URL or the method would let a bug in either slip
      // through, because both tests would still see a differing request.
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation invocation) async {
            sent.add(invocation.positionalArguments.first as RequestOptions);
            return jsonBody(kLiveReadingArJson, 200);
          });

      final Result<TodayReading> result = await readings.today(
        language: ReadingLanguage.arabic,
      );

      expect(sent.single.uri.path, '/api/v1/readings/today/ar');
      expect(
        (result as Success<TodayReading>).value.firstVerseText,
        'كان إنسان من الفريسيين اسمه نيقوديموس، رئيس',
      );
    });

    test('sends all three identity headers', () async {
      // AGENT_CONTEXT §5: `X-User-Id` is not required by *this* route — it
      // answers 200 without one — but the interceptor sends it unconditionally,
      // which is correct for both endpoints and costs nothing. Asserted because
      // "it happens to work without" and "the client always sends it" are
      // different claims and only one of them is a contract.
      await readings.today(language: ReadingLanguage.english);

      expect(sent.single.headers['x-user-id'], kSeededUserId);
      expect(sent.single.headers['x-group-id'], '3');
      expect(sent.single.headers['x-user-role'], 'kid');
    });
  });

  group('StreakRepository.summary — the happy path', () {
    setUp(() {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation invocation) async {
            sent.add(invocation.positionalArguments.first as RequestOptions);
            return jsonBody(kLiveStreakSummaryJson, 200);
          });
    });

    test('resolves the live payload, disagreement and all', () async {
      final Result<StreakSummary> result = await streak.summary();

      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<StreakSummary>).value,
        const StreakSummary(
          // `0`, where `GET /readings/today/en` says `4`. Reproduced exactly, so
          // a suite that reads both cannot accidentally rely on them agreeing.
          currentStreak: 0,
          longestStreak: 6,
          lastCompletedDate: '2026-09-29',
          todayStatus: StreakTodayStatus.pending,
          todayCompleted: false,
          todayScheduled: true,
          nextMilestone: 3,
          daysToMilestone: 3,
        ),
      );
    });

    test('asks for exactly the one documented URL', () async {
      await streak.summary();

      expect(sent, hasLength(1));
      expect(sent.single.uri.path, '/api/v1/streak/summary');
      expect(sent.single.method, 'GET');
    });

    test('and sends `X-User-Id`, the one header this route actually requires', () async {
      // §5: `streak/summary` **requires** `X-User-Id` — absent is a 400 and
      // empty is a 401. `readings/today` does not. The interceptor covers both,
      // and this is the route where it matters.
      await streak.summary();

      expect(sent.single.headers['x-user-id'], kSeededUserId);
    });
  });

  group('non-2xx — every observed status, both repositories', () {
    // The eight bodies Phase 5's decision 14 measured against `HEAD = 4a1c834`.
    const List<(int, String, FailureKind)> observed =
        <(int, String, FailureKind)>[
          (
            400,
            'headers must have required property \'x-user-id\'',
            FailureKind.validation,
          ),
          (
            400,
            'body/question_id must match format "uuid"',
            FailureKind.validation,
          ),
          (
            400,
            'querystring/date must match format "date"',
            FailureKind.validation,
          ),
          (400, 'body must be object', FailureKind.validation),
          (
            401,
            'Missing user identification (X-User-Id header)',
            FailureKind.unauthorized,
          ),
          (404, 'Reading not found', FailureKind.notFound),
          (
            409,
            'This question has already been submitted by this user.',
            FailureKind.conflict,
          ),
          (415, 'Unsupported Media Type', FailureKind.validation),
          (500, 'Internal Server Error', FailureKind.server),
        ];

    for (final (int, String, FailureKind) row in observed) {
      test('${row.$1} becomes a typed failure and never a throw', () async {
        // `jsonEncode`, not string interpolation: two of the nine observed
        // messages contain double quotes (`body/question_id must match format
        // "uuid"`), and hand-built JSON wrapped around one of those is malformed
        // — which dio reports as `DioExceptionType.unknown`, so a broken fixture
        // would read as a wrong `FailureKind` rather than as a broken fixture.
        when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (Invocation _) async => jsonBody(
            jsonEncode(<String, String>{'error': row.$2, 'message': row.$2}),
            row.$1,
          ),
        );

        final Failure reading = await failureOf(
          readings.today(language: ReadingLanguage.english),
        );
        final Failure streakFailure = await failureOf(streak.summary());

        for (final Failure failure in <Failure>[reading, streakFailure]) {
          expect(failure.kind, row.$3, reason: 'status ${row.$1}');
          expect(failure.statusCode, row.$1);
          // **Verbatim.** §5 and `failure.dart`: the server's wording is a
          // contract the player can be shown, not prose to reword. A repository
          // that reworded it would fork the vocabulary away from the mapper's.
          expect(failure.message, row.$2);
        }
      });
    }
  });

  // `ApiErrorMapper`'s own two edges are **not** re-tested here: the defensive
  // `{statusCode, code, error, message}` body and a `badResponse` carrying no
  // `Response` object are both swept in `api_error_mapper_test.dart` under
  // `SYNTHETIC — defensive branch` and `transport — no response arrived`. Repeating
  // them here would be a second implementation of one invariant, which AGENT_CONTEXT
  // §7 calls the thing not to keep in step. What this file adds is the claim that
  // the *repositories* route both of them through that mapper rather than through
  // a `catch` of their own — which the groups below prove by only ever producing a
  // `Result`.

  group('every DioExceptionType is a Result, never a throw', () {
    // The sweep §3's LSP row names. One assertion per type per repository, and
    // the assertion is on the *type* of the answer rather than on its kind, so a
    // kind that changed would not hide a throw.
    const List<DioExceptionType> transport = <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.badCertificate,
      DioExceptionType.cancel,
      DioExceptionType.unknown,
    ];

    for (final DioExceptionType type in transport) {
      test('$type is a failure on both ports', () async {
        when(() => adapter.fetch(any(), any(), any())).thenThrow(
          DioException(
            type: type,
            requestOptions: RequestOptions(path: '/api/v1/readings/today/en'),
          ),
        );

        final Result<TodayReading> reading = await readings.today(
          language: ReadingLanguage.english,
        );
        final Result<StreakSummary> summary = await streak.summary();

        expect(reading.isFailure, isTrue);
        expect(summary.isFailure, isTrue);
        expect(
          reading
              .failureOrElse(
                const Failure(kind: FailureKind.unknown, message: ''),
              )
              .message,
          isNotEmpty,
          reason:
              'a transport fault must still carry a message the mapper wrote',
        );
      });
    }
  });

  group('a 200 whose body cannot be read', () {
    test('and on the STREAK endpoint an HTML body is the same kind of failure', () async {
      // The twin of the reading endpoint's row below, and it exists because the
      // streak mapper's own `startsWith('<')` arm was uncovered: a reverse proxy
      // answering `/streak/summary` with a 502 page is the *same* outage as one
      // answering `/readings/today`, and it must fail the same way rather than
      // reaching the entity as a missing field.
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (Invocation _) async => rawBody('<html><body>502</body></html>', 200),
      );

      final Failure failure = await failureOf(streak.summary());

      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('HTML'));
      expect(
        failure.message,
        contains('streak summary'),
        reason:
            'the message names which of the two endpoints answered with a '
            'page — the two requests are otherwise indistinguishable in a log',
      );
    });

    test(
      'an HTML body becomes a serialization failure naming what it was',
      () async {
        when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (Invocation _) async => rawBody('<html><body>502</body></html>', 200),
        );

        final Failure failure = await failureOf(
          readings.today(language: ReadingLanguage.english),
        );

        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains('HTML'));
      },
    );

    test(
      'an empty 200 body is a serialization failure, not a null entity',
      () async {
        when(() => adapter.fetch(any(), any(), any()))
            .thenAnswer((Invocation _) async => jsonBody('', 200));

        final Failure failure = await failureOf(streak.summary());

        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains('empty'));
      },
    );

    test('a JSON array is a serialization failure', () async {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation _) async => jsonBody('[1,2,3]', 200));

      expect(
        (await failureOf(streak.summary())).kind,
        FailureKind.serialization,
      );
    });

    test('a 200 with `{}` fails on the first key, and names it', () async {
      // The default `setUp` adapter answers `200 {}`, so this is the shape every
      // un-stubbed request in this file returns. A repository that treated an
      // empty object as an empty streak would make a broken endpoint look like a
      // reader on day zero.
      expect(sent, isEmpty);
      final Failure failure = await failureOf(streak.summary());

      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('current_streak'));
    });
  });

  group('substitutability — the LSP row, mechanically', () {
    test(
      'a fake standing in for the Dio repository drives the same code',
      () async {
        // §3: "A `FakeReadingRepository` must be substitutable for
        // `DioReadingRepository`." The substitution is compile-time for the *type*
        // and behavioural for the *contract*, so it is exercised here: a fake that
        // always answers and never throws goes through the same await the real one
        // does, and the caller cannot tell.
        final _FakeReadingRepository fake = _FakeReadingRepository();

        expect(
          await fake.today(language: ReadingLanguage.arabic),
          isA<Result<TodayReading>>(),
        );
        expect(await fake.summary(), isA<Result<StreakSummary>>());
      },
    );

    test('and the fake cannot throw either, because it is handed a Result', () {
      // The half of the contract that is not behaviour: `today` and `summary`
      // are declared on the ports to return `Future<Result<…>>`, so a
      // `DioReadingRepository` returning a bare entity is a compile error rather
      // than a review finding. Declared, not asserted — the type is the
      // assertion, and this test documents that the claim is checkable.
      final _FakeReadingRepository fake = _FakeReadingRepository();
      final ReadingRepository asPort = fake;

      expect(asPort, same(fake));
    });
  });
}

/// A hand-written fake over both ports, for the substitutability group.
///
/// Deliberately **not** a `Mock`: the LSP row is about a fake standing in for the
/// real adapter, and a mocktail mock implements whatever it is told to — so it
/// can satisfy the type while returning whatever the test stubs, including
/// nothing at all. A hand-written one has to answer.
final class _FakeReadingRepository
    implements ReadingRepository, StreakRepository {
  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async => Result<TodayReading>.success(
    TodayReading(
      readingId: 'fake',
      groupId: 3,
      scheduledDate: '2026-10-03',
      language: language,
      reference: 'fake',
      translation: 'fake',
      verseCount: 0,
      firstVerseText: 'fake',
      questionCount: 0,
      answeredQuestionCount: 0,
      isFullyCompleted: false,
      pointsEarnedToday: 0,
      currentStreak: 0,
    ),
  );

  @override
  Future<Result<StreakSummary>> summary() async =>
      const Result<StreakSummary>.success(
        StreakSummary(
          currentStreak: 0,
          longestStreak: 0,
          lastCompletedDate: '2026-01-01',
          todayStatus: StreakTodayStatus.pending,
          todayCompleted: false,
          todayScheduled: true,
          nextMilestone: 3,
          daysToMilestone: 3,
        ),
      );
}
