import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/servant/data/datasources/servant_remote_data_source.dart';
import 'package:evangelion/features/servant/data/mappers/question_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/report_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/schedule_mapper.dart';
import 'package:evangelion/features/servant/data/repositories/dio_servant_admin_repository.dart';
import 'package:evangelion/features/servant/data/repositories/dio_servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_dio.dart';
import '../servant_contract_payloads.dart';

/// The two Dio adapters over the servant portal's four routes.
///
/// ## WHAT IS ASSERTED HERE
///
/// * the **exact path and body** of each of the four requests — because zod
///   **strips unknown keys** and a body the server silently narrows is a
///   request that looks correct and is not;
/// * that a repository **never throws** across its seam: every fault is a
///   [Result.failure], and the failure's kind and message are the ones the
///   server's status and body decide.
///
/// ## AND THE BODIES ARE **TRANSCRIPTIONS**
///
/// The responses come from `test/features/servant/data/servant_contract_payloads.dart`,
/// whose header says what that means: **none of these four routes has been
/// observed from this client**, so the shapes are the backend's declarations.
void main() {
  setUpAll(registerRequestOptionsFallback);

  const ReadingSchedule schedule = ReadingSchedule(
    groupIds: <int>[3],
    scheduledDate: '2026-10-21',
    bookNumber: 43,
    startChapter: 3,
    startVerse: 1,
    endVerse: 5,
  );

  const QuestionDraft question = QuestionDraft(
    type: QuestionType.mcq,
    promptAr: 'سؤال',
    promptEn: 'A question',
    options: <String, QuestionOption>{
      'A': QuestionOption(ar: 'الخيار أ', en: 'Option A'),
    },
    correctAnswer: 'A',
    pointsValue: 10,
    sortOrder: 1,
    isApproved: true,
  );

  late MockAdapter adapter;
  late List<RequestOptions> sent;
  late ServantAdminRepository admin;
  late ServantReportRepository report;

  setUp(() {
    sent = <RequestOptions>[];
    adapter = MockAdapter();
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((Invocation invocation) async {
          sent.add(invocation.positionalArguments.first as RequestOptions);
          return jsonBody('{}', 200);
        });

    final Dio dio = dioWithAdapter(adapter);
    admin = DioServantAdminRepository(
      dataSource: ServantRemoteDataSource(dio),
      scheduleMapper: const ScheduleMapper(),
      questionMapper: const QuestionMapper(),
      errors: const ApiErrorMapper(),
    );
    report = DioServantReportRepository(
      dataSource: ServantRemoteDataSource(dio),
      mapper: const ReportMapper(),
      errors: const ApiErrorMapper(),
    );
  });

  /// Answers the next request with [body] and [status].
  void answerWith(String body, int status) {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((Invocation invocation) async {
          sent.add(invocation.positionalArguments.first as RequestOptions);
          return jsonBody(body, status);
        });
  }

  group('scheduleReading', () {
    test('posts to the schedule endpoint, with the snake_case body', () async {
      answerWith(kContractScheduleResponseJson, 201);

      await admin.scheduleReading(schedule);

      expect(sent, hasLength(1));
      expect(sent.single.method, 'POST');
      expect(sent.single.uri.path, '/api/v1/admin/readings/schedule');
      expect(sent.single.data, <String, Object?>{
        'group_ids': <int>[3],
        'scheduled_date': '2026-10-21',
        'book_number': 43,
        'start_chapter': 3,
        'start_verse': 1,
        'end_verse': 5,
        'excluded_verses': <Map<String, Object?>>[],
        'generate_ai_questions': false,
      });
    });

    test('and sends `Content-Type: application/json`, because a POST without it is a 415', () async {
      answerWith(kContractScheduleResponseJson, 201);

      await admin.scheduleReading(schedule);

      expect(
        sent.single.headers[Headers.contentTypeHeader],
        contains(Headers.jsonContentType),
      );
    });

    test('and the `201` resolves to a `ScheduleResult`', () async {
      answerWith(kContractScheduleResponseJson, 201);

      final Result<ScheduleResult> result = await admin.scheduleReading(
        schedule,
      );

      expect(
        result,
        const Right<Failure, ScheduleResult>(
          ScheduleResult(
            message: 'Successfully scheduled reading for 1 groups',
            readingIds: <String>['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
          ),
        ),
      );
    });
  });

  group('commitQuestions', () {
    test('posts to the commit endpoint, with the question body', () async {
      answerWith(kContractCommitResponseJson, 201);

      await admin.commitQuestions(
        readingId: 'r1',
        questions: const <QuestionDraft>[question],
      );

      expect(sent, hasLength(1));
      expect(sent.single.method, 'POST');
      expect(sent.single.uri.path, '/api/v1/admin/questions/commit');
      expect(sent.single.data, <String, Object?>{
        'reading_id': 'r1',
        'questions': <Map<String, Object?>>[
          <String, Object?>{
            'type': 'mcq',
            'prompt_ar': 'سؤال',
            'prompt_en': 'A question',
            'options': <String, Object?>{
              'A': <String, Object?>{'ar': 'الخيار أ', 'en': 'Option A'},
            },
            'correct_answer': 'A',
            'points_value': 10,
            'sort_order': 1,
            'is_approved': true,
          },
        ],
      });
    });

    test('and the `201` resolves to a `CommitResult`', () async {
      answerWith(kContractCommitResponseJson, 201);

      final Result<Object?> result = await admin.commitQuestions(
        readingId: 'r1',
        questions: const <QuestionDraft>[question],
      );

      expect(
        result,
        const Right<Failure, Object?>(
          CommitResult(
            message: 'Committed 1 questions for reading',
            questionIds: <String>['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'],
          ),
        ),
      );
    });
  });

  group('generateAiDraft', () {
    test('posts to the AI endpoint, with the reading and the type', () async {
      answerWith(kContractAiDraftResponseJson, 200);

      await admin.generateAiDraft(readingId: 'r1', type: QuestionType.mcq);

      expect(sent, hasLength(1));
      expect(sent.single.method, 'POST');
      expect(sent.single.uri.path, '/api/v1/admin/questions/ai-generate');
      expect(sent.single.data, <String, Object?>{
        'reading_id': 'r1',
        'type': 'mcq',
      });
    });

    test('and the `200` resolves to a draft', () async {
      answerWith(kContractAiDraftResponseJson, 200);

      final Result<QuestionDraft> result = await admin.generateAiDraft(
        readingId: 'r1',
        type: QuestionType.mcq,
      );

      expect(result, isA<Right<Failure, QuestionDraft>>());
      final QuestionDraft draft =
          (result as Right<Failure, QuestionDraft>).value;
      expect(draft.type, QuestionType.mcq);
      expect(draft.correctAnswer, 'A');
    });

    test('and a `short_answer` never reaches the transport', () async {
      // `ai.routes.ts:10` types the request's `type` as
      // `z.enum(['mcq', 'true_false'])` — a `short_answer` is a **400** there.
      // The client knows that without asking, so the request is never made.
      final Result<QuestionDraft> result = await admin.generateAiDraft(
        readingId: 'r1',
        type: QuestionType.shortAnswer,
      );

      expect(result, isA<Left<Failure, QuestionDraft>>());
      expect(
        (result as Left<Failure, QuestionDraft>).value.kind,
        FailureKind.validation,
      );
      expect(sent, isEmpty, reason: 'no request may have been made');
    });
  });

  group('loadDailyReport', () {
    test('gets the report endpoint, with the group and the date', () async {
      answerWith(kContractDailyReportResponseJson, 200);

      await report.loadDailyReport(groupId: 3, date: '2026-10-21');

      expect(sent, hasLength(1));
      expect(sent.single.method, 'GET');
      expect(sent.single.uri.path, '/api/v1/servant/reports/daily');
      expect(sent.single.uri.queryParameters, <String, String>{
        'group_id': '3',
        'date': '2026-10-21',
      });
    });

    test('and the `200` resolves to a `ServantReport`', () async {
      answerWith(kContractDailyReportResponseJson, 200);

      final Result<ServantReport> result = await report.loadDailyReport(
        groupId: 3,
        date: '2026-10-21',
      );

      expect(
        result,
        const Right<Failure, ServantReport>(
          ServantReport(
            groupId: 3,
            reportDate: '2026-10-21',
            totalStudents: 2,
            completedCount: 1,
            students: <RosterStudent>[
              RosterStudent(
                userId: '11111111-1111-1111-1111-111111111111',
                fullName: 'David Mina',
                preferredLang: 'en',
                totalPoints: 40,
                currentStreak: 4,
                pointsEarnedToday: 10,
                completedToday: true,
                questionsProgress: '3/5',
              ),
              RosterStudent(
                userId: '22222222-2222-2222-2222-222222222222',
                fullName: 'Peter George',
                preferredLang: 'ar',
                totalPoints: 25,
                currentStreak: 2,
                pointsEarnedToday: 0,
                completedToday: false,
                questionsProgress: '0/0',
              ),
            ],
          ),
        ),
      );
    });
  });

  group('a repository never throws across its seam', () {
    // §3's LSP row, and the whole point of the `try` in each method: a
    // transport fault and a non-2xx response are both a `Result.failure`, and
    // the failure carries the **server's own message**.
    const List<(int, String, FailureKind)> statuses =
        <(int, String, FailureKind)>[
          (400, 'Bad Request', FailureKind.validation),
          (404, 'Not Found', FailureKind.notFound),
          (409, 'Conflict', FailureKind.conflict),
          (500, 'Database Error', FailureKind.server),
        ];

    for (final (int status, String error, FailureKind kind) in statuses) {
      test('a $status on the schedule route is a typed failure', () async {
        answerWith(
          '{"error":"$error","message":"start boundary cannot be after end boundary"}',
          status,
        );

        final Result<ScheduleResult> result = await admin.scheduleReading(
          schedule,
        );

        expect(result, isA<Left<Failure, ScheduleResult>>());
        final Failure failure = (result as Left<Failure, ScheduleResult>).value;
        expect(failure.kind, kind);
        expect(failure.statusCode, status);
        expect(
          failure.message,
          'start boundary cannot be after end boundary',
          reason: "the server's own words, never reworded",
        );
      });
    }

    test('a transport fault is a failure, not an exception', () async {
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException.connectionError(
          requestOptions: RequestOptions(
            path: '/api/v1/admin/readings/schedule',
          ),
          reason: 'no socket',
        ),
      );

      final Result<ScheduleResult> result = await admin.scheduleReading(
        schedule,
      );

      expect(result, isA<Left<Failure, ScheduleResult>>());
      expect(
        (result as Left<Failure, ScheduleResult>).value.kind,
        FailureKind.network,
      );
    });

    test('and the commit route says the same', () async {
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException.connectionError(
          requestOptions: RequestOptions(
            path: '/api/v1/admin/questions/commit',
          ),
          reason: 'no socket',
        ),
      );

      final Result<CommitResult> result = await admin.commitQuestions(
        readingId: 'r1',
        questions: const <QuestionDraft>[question],
      );

      expect(result, isA<Left<Failure, CommitResult>>());
      expect(
        (result as Left<Failure, CommitResult>).value.kind,
        FailureKind.network,
      );
    });

    test('and the AI route says the same', () async {
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException.connectionError(
          requestOptions: RequestOptions(
            path: '/api/v1/admin/questions/ai-generate',
          ),
          reason: 'no socket',
        ),
      );

      final Result<QuestionDraft> result = await admin.generateAiDraft(
        readingId: 'r1',
        type: QuestionType.mcq,
      );

      expect(result, isA<Left<Failure, QuestionDraft>>());
      expect(
        (result as Left<Failure, QuestionDraft>).value.kind,
        FailureKind.network,
      );
    });

    test('and the report route says the same', () async {
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/servant/reports/daily'),
          reason: 'no socket',
        ),
      );

      final Result<ServantReport> result = await report.loadDailyReport(
        groupId: 3,
        date: '2026-10-21',
      );

      expect(result, isA<Left<Failure, ServantReport>>());
      expect(
        (result as Left<Failure, ServantReport>).value.kind,
        FailureKind.network,
      );
    });

    test(
      'and a 2xx body that cannot be read is a serialization failure',
      () async {
        answerWith('{"message":"ok"}', 201);

        final Result<ScheduleResult> result = await admin.scheduleReading(
          schedule,
        );

        expect(result, isA<Left<Failure, ScheduleResult>>());
        expect(
          (result as Left<Failure, ScheduleResult>).value.kind,
          FailureKind.serialization,
        );
      },
    );
  });
}
