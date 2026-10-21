import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/data/mappers/question_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/report_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/schedule_mapper.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../servant_contract_payloads.dart';

/// The three mappers, and the **asymmetry** that is their whole job.
///
/// The wire speaks **snake_case** and the domain speaks **camelCase**, and
/// every one of these assertions is about that translation happening in the
/// right direction, in the right file, with nothing lost and nothing invented.
///
/// ## THE PAYLOADS ARE TRANSCRIPTIONS, NOT CAPTURES
///
/// They come from `test/features/servant/data/servant_contract_payloads.dart`,
/// whose header says what that means: **none of the four routes has been
/// observed from this client**, so these are the backend's **declarations**
/// (`admin.routes.ts`, `ai.routes.ts`, `ai.service.ts`), and a test that reads
/// them is a contract test rather than an integration test.
///
/// ## AND THE REQUEST BODIES ARE ASSERTED **EXACTLY**
///
/// The bodies are asserted as whole maps, key by key. The reason is zod:
/// **zod strips unknown keys**, so a key this client invented would be
/// silently dropped by the server and every test would still see a working
/// request with the field simply never arriving. An exact map is the only
/// assertion that notices.
void main() {
  group('ScheduleMapper', () {
    const ReadingSchedule schedule = ReadingSchedule(
      groupIds: <int>[3, 4],
      scheduledDate: '2026-10-21',
      bookNumber: 43,
      startChapter: 3,
      startVerse: 1,
      endChapter: 4,
      endVerse: 5,
      excludedVerses: <ExcludedVerse>[
        ExcludedVerse(chapter: 3, verse: 2),
        ExcludedVerse(chapter: 4, verse: 1),
      ],
      generateAiQuestions: true,
    );

    test('the body is the server\'s `scheduleSchema`, key for key', () {
      expect(ScheduleMapper.bodyFor(schedule), <String, Object?>{
        'group_ids': <int>[3, 4],
        'scheduled_date': '2026-10-21',
        'book_number': 43,
        'start_chapter': 3,
        'start_verse': 1,
        'end_chapter': 4,
        'end_verse': 5,
        'excluded_verses': <Map<String, Object?>>[
          <String, Object?>{'chapter': 3, 'verse': 2},
          <String, Object?>{'chapter': 4, 'verse': 1},
        ],
        'generate_ai_questions': true,
      });
    });

    test('and `end_chapter` is **omitted**, never sent as null', () {
      // The server's schema types it `z.number().int().min(1).optional()`
      // (`admin.routes.ts:14`), and `.optional()` accepts `undefined` and
      // **refuses `null`**. A literal `null` in the body is a **400**. The
      // server's own transform then defaults it to `start_chapter` (`:31-33`),
      // which is what "the passage does not cross a chapter boundary" means.
      const ReadingSchedule singleChapter = ReadingSchedule(
        groupIds: <int>[3],
        scheduledDate: '2026-10-21',
        bookNumber: 43,
        startChapter: 3,
        startVerse: 1,
        endVerse: 5,
      );

      final Map<String, Object?> body = ScheduleMapper.bodyFor(singleChapter);

      expect(body.containsKey('end_chapter'), isFalse);
      expect(body.containsKey('end_chapter'), isFalse);
    });

    test('and the excluded verses are omitted when there are none', () {
      const ReadingSchedule plain = ReadingSchedule(
        groupIds: <int>[3],
        scheduledDate: '2026-10-21',
        bookNumber: 43,
        startChapter: 3,
        startVerse: 1,
        endVerse: 5,
      );

      expect(ScheduleMapper.bodyFor(plain)['excluded_verses'], isEmpty);
    });

    test('and the endpoint carries the `/api/v1` prefix', () {
      // `core/network/dio_client.dart` says the prefix belongs to the
      // endpoint definitions, not to the host.
      expect(ScheduleMapper.endpoint, '/api/v1/admin/readings/schedule');
    });

    test('the `201` maps to a `ScheduleResult`', () {
      final Result<ScheduleResult> result = const ScheduleMapper()
          .mapScheduleResult(contractScheduleResponse());

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

    test('and a body it cannot read is a serialization failure', () {
      final Result<ScheduleResult> result = const ScheduleMapper()
          .mapScheduleResult(<String, Object?>{'message': 'ok'});

      expect(result, isA<Left<Failure, ScheduleResult>>());
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.serialization,
      );
    });
  });

  group('QuestionMapper', () {
    const QuestionDraft mcq = QuestionDraft(
      type: QuestionType.mcq,
      promptAr: 'سؤال',
      promptEn: 'A question',
      options: <String, QuestionOption>{
        'A': QuestionOption(ar: 'الخيار أ', en: 'Option A'),
        'B': QuestionOption(ar: 'الخيار ب', en: 'Option B'),
      },
      correctAnswer: 'A',
      pointsValue: 10,
      sortOrder: 1,
      isApproved: true,
    );

    test('the commit body is the server\'s `commitQuestionsSchema`', () {
      expect(
        QuestionMapper.commitBodyFor(
          readingId: 'r1',
          questions: const <QuestionDraft>[mcq],
        ),
        <String, Object?>{
          'reading_id': 'r1',
          'questions': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'mcq',
              'prompt_ar': 'سؤال',
              'prompt_en': 'A question',
              'options': <String, Object?>{
                'A': <String, Object?>{'ar': 'الخيار أ', 'en': 'Option A'},
                'B': <String, Object?>{'ar': 'الخيار ب', 'en': 'Option B'},
              },
              'correct_answer': 'A',
              'points_value': 10,
              'sort_order': 1,
              'is_approved': true,
            },
          ],
        },
      );
    });

    test('and `options` is **omitted** for a question that has none', () {
      // The schema's `options` is optional (`admin.routes.ts:44`) and the
      // server stores `JSON.stringify(q.options || null)` (`:304`) — so a
      // question with no options is stored with a **null**, and an empty object
      // would be stored as `{}`. Omitting the key is how the client says "no
      // options" the way the server's own default does.
      const QuestionDraft shortAnswer = QuestionDraft(
        type: QuestionType.shortAnswer,
        promptAr: 'سؤال',
        promptEn: 'A question',
        options: <String, QuestionOption>{},
        correctAnswer: 'A written answer',
        pointsValue: 10,
        sortOrder: 1,
        isApproved: true,
      );

      final Map<String, Object?> body = QuestionMapper.commitBodyFor(
        readingId: 'r1',
        questions: const <QuestionDraft>[shortAnswer],
      );
      final List<Object?> questions = body['questions']! as List<Object?>;
      final Map<String, Object?> question =
          questions.first! as Map<String, Object?>;

      expect(question.containsKey('options'), isFalse);
      expect(question['type'], 'short_answer');
    });

    test('and the AI body names the reading and the type', () {
      final Result<Map<String, Object?>> body =
          QuestionMapper.aiGenerateBodyFor(
            readingId: 'r1',
            type: QuestionType.trueFalse,
          );

      expect(body, isA<Right<Failure, Map<String, Object?>>>());
      // **The payload is compared with the `equals` matcher, not with `==`.**
      // `Right.operator ==` compares its payload with `==` (fp_dart
      // `either.dart:572`), and `==` on a `Map` is **identity** — so two
      // equal bodies are two unequal `Result`s. `result.dart` records the same
      // limitation for a `List` payload, and the remedy is the same: read the
      // value and let the matcher do the deep comparison.
      expect(
        body.getOrElse((_) => const <String, Object?>{}),
        <String, Object?>{'reading_id': 'r1', 'type': 'true_false'},
      );
    });

    test('and the AI route refuses a `short_answer`', () {
      // `ai.routes.ts:10` types the request's `type` as
      // `z.enum(['mcq', 'true_false'])` — a `short_answer` is a **400** there.
      // The refusal is made **before** the request, because the request would
      // be refused by the server and the client can know that without asking.
      final Result<Map<String, Object?>> body =
          QuestionMapper.aiGenerateBodyFor(
            readingId: 'r1',
            type: QuestionType.shortAnswer,
          );

      expect(body, isA<Left<Failure, Map<String, Object?>>>());
      expect(
        body
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.validation,
      );
    });

    test('and the endpoints carry the `/api/v1` prefix', () {
      expect(QuestionMapper.commitEndpoint, '/api/v1/admin/questions/commit');
      expect(
        QuestionMapper.aiGenerateEndpoint,
        '/api/v1/admin/questions/ai-generate',
      );
    });

    test('the `201` maps to a `CommitResult`', () {
      final Result<CommitResult> result = const QuestionMapper()
          .mapCommitResult(contractCommitResponse());

      expect(
        result,
        const Right<Failure, CommitResult>(
          CommitResult(
            message: 'Committed 1 questions for reading',
            questionIds: <String>['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'],
          ),
        ),
      );
    });

    test('the AI `200` maps to a draft, with the schema\'s own defaults', () {
      // The AI route returns five fields (`ai.routes.ts:31-40`) and the commit
      // schema declares three more with defaults — `points_value` 10,
      // `sort_order` 1, `is_approved` true (`admin.routes.ts:46-48`). The draft
      // carries them, which is what makes a draft **committable without a
      // conversion** (the design spec §6.1).
      final Result<QuestionDraft> result = const QuestionMapper().mapDraft(
        contractAiDraftResponse(),
      );

      expect(result, isA<Right<Failure, QuestionDraft>>());
      final QuestionDraft draft =
          (result as Right<Failure, QuestionDraft>).value;

      expect(draft.type, QuestionType.mcq);
      expect(draft.correctAnswer, 'A');
      expect(draft.pointsValue, 10);
      expect(draft.sortOrder, 1);
      expect(draft.isApproved, isTrue);
      expect(draft.options.keys, <String>['A', 'B']);
      expect(draft.options['A']?.en, 'That he came to the earth');
    });

    test('and a draft with no `options` key is refused, not read as empty', () {
      // The AI service's response schema marks `options` **required**
      // (`ai.service.ts:103`) and its own validator refuses a draft without
      // them (`:140-144`), so a draft with no options is a body **this server
      // cannot produce**. Reading it as "no options" would turn a server
      // change into a silently wrong question.
      final Result<QuestionDraft> result = const QuestionMapper().mapDraft(
        <String, Object?>{
          'reading_id': 'r1',
          'draft_question': <String, Object?>{
            'type': 'mcq',
            'prompt_ar': 'س',
            'prompt_en': 'q',
            'correct_answer': 'A',
          },
        },
      );

      expect(result, isA<Left<Failure, QuestionDraft>>());
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.serialization,
      );
    });

    test('and a draft whose `type` the client does not know is refused', () {
      // The server's union is three values, and a fourth would be a server
      // change this client has to be told about — not something to guess.
      final Result<QuestionDraft> result = const QuestionMapper().mapDraft(
        <String, Object?>{
          'reading_id': 'r1',
          'draft_question': <String, Object?>{
            'type': 'essay',
            'prompt_ar': 'س',
            'prompt_en': 'q',
            'options': <String, Object?>{},
            'correct_answer': 'A',
          },
        },
      );

      expect(result, isA<Left<Failure, QuestionDraft>>());
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.serialization,
      );
    });
  });

  group('ReportMapper', () {
    test('the path carries the query the server reads', () {
      // `admin.routes.ts:336-341` declares `group_id` and `date` as
      // querystring properties, and `:373-374` reads them with
      // `parseInt(group_id || '1', 10)`.
      expect(
        ReportMapper.pathFor(groupId: 3, date: '2026-10-21'),
        '/api/v1/servant/reports/daily?group_id=3&date=2026-10-21',
      );
    });

    test('the `200` maps to a `ServantReport`', () {
      final Result<ServantReport> result = const ReportMapper().map(
        contractDailyReportResponse(),
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

    test('and a row it cannot read fails the whole report', () {
      // The leaderboard mapper's rule, for the same reason: a skipped row
      // leaves a roster with a hole in it, and a roster that reads as
      // authoritative while being wrong is worse than an error with a retry.
      final Result<ServantReport> result = const ReportMapper().map(
        <String, Object?>{
          'group_id': 3,
          'report_date': '2026-10-21',
          'total_students': 1,
          'completed_count': 0,
          'students': <Object?>[
            <String, Object?>{'user_id': 'u1'},
          ],
        },
      );

      expect(result, isA<Left<Failure, ServantReport>>());
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: ''),
            )
            .kind,
        FailureKind.serialization,
      );
    });
  });
}
