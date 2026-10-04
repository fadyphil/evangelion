import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/reading/data/datasources/reading_remote_data_source.dart';
import 'package:evangelion/features/reading/data/datasources/streak_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/submit_result_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';
import 'package:evangelion/features/reading/data/repositories/dio_reading_repository.dart';
import 'package:evangelion/features/reading/data/repositories/dio_streak_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/contract_payloads.dart';
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
      submits: const SubmitResultMapper(),
      errors: const ApiErrorMapper(),
    );
    streak = DioStreakRepository(
      dataSource: StreakRemoteDataSource(dio),
      mapper: const StreakSummaryMapper(),
      errors: const ApiErrorMapper(),
    );
  });

  /// A submit over the port, spelled once so the three submit groups below do not
  /// each restate the three arguments — and so a change to the port's parameter
  /// names is a compile error in one place rather than four.
  Future<Result<SubmitResult>> submit({
    String readingId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    String questionId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    String answer = 'A',
  }) => readings.submitAnswer(
    readingId: readingId,
    questionId: questionId,
    answer: answer,
  );

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

  group('ReadingRepository.submitAnswer — the request, which is the point', () {
    // ## WHY THIS GROUP IS THE LARGEST IN THE FILE
    //
    // The other two methods read an endpoint this client calls all day. This one
    // **cannot be verified against a running server**, because no successful submit
    // is reachable — AGENT_CONTEXT §5 trap 10, measured against `HEAD = 4a1c834`:
    // the endpoint answers `400` for the id it hands out itself, `404` for a
    // well-formed id that is not in the store, and `409` for the seeded one.
    //
    // So the request is the part that must be right, and the **only** authority for
    // it is the backend's own schema:
    //
    // ```ts
    // // src/modules/submissions/submissions.routes.ts:6-8
    // const submitSchema = z.object({
    //   question_id: z.string().uuid(),
    //   answer: z.string().min(1)
    // });
    // ```
    //
    // and the path's shape, from the same file's `fastify.post('/readings/:id/submit')`
    // with `headers: { required: ['x-user-id'] }` and a JSON body — which is why
    // §5 trap 5 (a `POST` without `Content-Type: application/json` → `415`) is a
    // live hazard for this request and not for the two `GET`s.
    //
    // `SubmitResultMapper`'s own suite holds the **response** side against the
    // service's `SubmitAnswerResult` interface. This group holds the request side
    // against the route's schema. Between them the contract is covered from both
    // ends by **declaration**, and that is the honest word for it.

    setUp(() {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation invocation) async {
            sent.add(invocation.positionalArguments.first as RequestOptions);
            return jsonBody(kContractSubmitAnswerJson, 200);
          });
    });

    test('resolves the contract body to the contract entity', () async {
      final Result<SubmitResult> result = await submit();

      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<SubmitResult>).value,
        const SubmitResult(
          questionId: 'question-group-3',
          isCorrect: true,
          pointsEarned: 10,
          currentTotalPoints: 40,
          currentStreak: 4,
          longestStreak: 6,
          readingCompleted: true,
        ),
      );
    });

    test('asks for exactly the one documented URL', () async {
      await submit(
        readingId: 'reading-group-3-2026-10-04',
        questionId: 'question-group-3',
        answer: 'B',
      );

      expect(sent, hasLength(1));
      // **The id is in the path and is whatever the server handed out.** §5 traps 10
      // and 11: it is fabricated and it is date-dependent, and it has already rolled
      // over once between two probes of `GET /readings/today/en`. The route types the
      // parameter as `description: 'Reading UUID'` — a description, not a schema —
      // so nothing validates it here and the client must not invent a check.
      expect(
        sent.single.uri.path,
        '/api/v1/readings/reading-group-3-2026-10-04/submit',
      );
      expect(sent.single.method, 'POST');
    });

    test('sends `Content-Type: application/json`, because §5 trap 5 is a 415', () async {
      // The one request in this client with a body, and therefore the only one
      // where a missing content type is a **415** rather than a harmless omission.
      // This assertion exists because dio will happily not set it if a caller ever
      // posts a bare `Map`, and the resulting 415 would read as a server fault.
      await submit();

      expect(
        sent.single.headers[Headers.contentTypeHeader],
        contains(Headers.jsonContentType),
        reason: '§5 trap 5: a POST without this is 415 Unsupported Media Type',
      );
    });

    test('and the body is exactly `{question_id, answer}` — the route schema', () async {
      // **Exactly.** `submitSchema` is a `z.object` with two keys and zod strips
      // unknown ones, so a third key would be silently dropped by the server and
      // would look correct in every test: the request "worked", the field just
      // never arrived. `SubmitAnswerResult` has seven keys and a reader could
      // plausibly send them; this assertion is what keeps that from being silent.
      await submit(
        questionId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        answer: 'A',
      );

      final Object? body = sent.single.data;
      expect(body, isA<Map<String, Object?>>());
      expect((body as Map<String, Object?>).keys.toSet(), <String>{
        'question_id',
        'answer',
      });
      expect(body['question_id'], 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(body['answer'], 'A');
    });

    test('`answer` is sent **verbatim**, because the route only says `min(1)`', () async {
      // `submissions.routes.ts:35` documents `answer` as *"Selected option
      // (A, B, C, D) or boolean"*, so a bare `'true'` is a legal value and a
      // client that validated it against the option letters would refuse a legal
      // request. Recorded decision 15's argument, applied to a different field:
      // **the backend is the validator.**
      for (final String answer in <String>[
        'A',
        'B',
        'C',
        'D',
        'true',
        'false',
      ]) {
        sent.clear();
        await submit(answer: answer);
        expect(
          ((sent.single.data as Map<String, Object?>)['answer']),
          answer,
          reason: '`$answer` is within `z.string().min(1)`',
        );
      }
    });

    test('sends `X-User-Id`, the one header this route requires', () async {
      // `submissions.routes.ts:24-27` — `required: ['x-user-id']`, and **no**
      // `x-group-id`. The interceptor sends all three unconditionally, which
      // `core/network/dio_client.dart` records as correct either way; this
      // assertion is here because a group header *missing* from this request would
      // be a different defect from the two GETs and would not show up in any of
      // their suites.
      await submit();

      expect(sent.single.headers['x-user-id'], kSeededUserId);
    });

    test('the reading id is NOT url-encoded into a different path', () async {
      // The id contains no reserved characters today. If a backend ever fabricated
      // one with a `/`, dio's `Uri` would treat the segment as a path component and
      // the request would address a different route — silently, because it is still
      // a 200-shaped request. Asserting the exact path above is what makes that
      // visible, and this case names it.
      await submit(readingId: 'reading-group-3-2026-10-04');
      expect(sent.single.uri.pathSegments, <String>[
        'api',
        'v1',
        'readings',
        'reading-group-3-2026-10-04',
        'submit',
      ]);
    });
  });

  group('submitAnswer — the three dead ends, as typed failures', () {
    // §5 trap 10's three rows, verbatim, through the adapter rather than a socket.
    // They are here rather than only in `api_error_mapper_test.dart` because the
    // claim under test is not "the status maps to a kind" — decision 14 owns that —
    // it is "**this** client, on **this** request, surfaces each of them as a typed
    // `Result` and never a throw", and that is a claim about the repository's third
    // arm.
    const List<(int, String, FailureKind)> deadEnds =
        <(int, String, FailureKind)>[
          (
            400,
            'body/question_id must match format "uuid"',
            FailureKind.validation,
          ),
          (
            404,
            'QUESTION_NOT_FOUND: Specified question does not exist.',
            FailureKind.notFound,
          ),
          (
            409,
            'This question has already been submitted by this user.',
            FailureKind.conflict,
          ),
        ];

    for (final (int, String, FailureKind) row in deadEnds) {
      test('${row.$1} `${row.$2}` is a Failure, not an exception', () async {
        when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (Invocation _) async => jsonBody(
            jsonEncode(<String, String>{'error': row.$2, 'message': row.$2}),
            row.$1,
          ),
        );

        final Failure failure = await failureOf(submit());
        expect(failure.kind, row.$3);
        expect(failure.statusCode, row.$1);
        expect(failure.message, row.$2);
      });
    }

    test('and a 409 is a `conflict` — the one the client must PREVENT, not absorb', () {
      // §5 trap 3 and the plan's Phase-8 requirement: "the quiz must disable
      // questions where `already_answered == true` rather than discovering this as
      // an error." The mapper's job is done — the 409 is typed and its message is
      // the server's — and **it is still the wrong answer**, because the reader was
      // walked into a conflict the client could have seen coming. The thing that
      // prevents it is `QuizAnswer.isAnswerable`, in the domain layer, and
      // `quiz_page_test.dart` holds it. Nothing in the repository can.
      expect(
        kindForStatus(409),
        FailureKind.conflict,
        reason:
            'this assertion is the control for the sentence above: the type is '
            'right and the behaviour is still wrong, so "the mapper handles it" '
            'must never be read as "the client prevents it".',
      );
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
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  }) async => Result<ScriptureText>.success(
    ScriptureText(
      readingId: 'fake',
      groupId: 3,
      scheduledDate: '2026-10-03',
      language: language,
      reference: 'fake',
      translation: 'fake',
      verses: const <Verse>[
        Verse(bookNumber: 43, chapter: 3, number: 1, text: 'fake'),
      ],
      questions: const <Question>[],
      isFullyCompleted: false,
      pointsEarnedToday: 0,
      currentStreak: 0,
    ),
  );

  /// The port defines [today] as a narrowing of [todayScripture], and this fake
  /// takes the same route `DioReadingRepository.today` takes rather than a second
  /// one — the substitutability assertion in this file is only meaningful if the
  /// substitute is shaped like the thing it substitutes for.
  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async =>
      (await todayScripture(language: language))
          .map((ScriptureText scripture) => scripture.toTodayReading());

  /// The third method of the port, and the one Phase 8 added.
  ///
  /// Answered rather than `unimplemented`, for this file's reason: a hand-written
  /// substitute has to be substitutable, and a bloc holding this fake would call
  /// this the moment a reader pressed "Check answer".
  @override
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  }) async => Result<SubmitResult>.success(
    SubmitResult(
      questionId: questionId,
      isCorrect: true,
      pointsEarned: 10,
      currentTotalPoints: 10,
      currentStreak: 1,
      longestStreak: 1,
      readingCompleted: true,
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
