import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `servant` feature's entities, and the shapes the backend's four routes
/// expect them to carry.
///
/// ## WHY THESE ASSERTIONS ARE ABOUT THE **DOMAIN** AND NOT ABOUT THE WIRE
///
/// The wire's spelling is the mapper's business, and
/// `test/features/servant/data/mappers/servant_mappers_test.dart` holds it. What
/// this file holds is the other half: that the domain carries **every field the
/// endpoint needs**, so the mapper never has to invent one and never has to drop
/// one.
///
/// The field lists below are transcribed from the backend's own schemas —
/// `scheduleSchema` at `admin.routes.ts:8-33`, `commitQuestionsSchema` at
/// `:35-50`, `aiGenerateSchema` at `ai.routes.ts:8-11` and the roster query at
/// `admin.routes.ts:401-422` — and the transcription is stated here rather than
/// implied, because a fixture whose provenance is a declaration must not sit in a
/// file that claims to have been recorded.
///
/// ## AND THE FREEZED EQUALITY OF EVERY TYPE HERE IS HELD BY A SHARED GATE
///
/// `test/core/common/freezed_structural_equality_test.dart` asserts, over the
/// **whole** converted set, that two structurally-equal instances compare equal
/// and that changing any one field makes them unequal. This file therefore does
/// not repeat that work: it asserts what the entities *carry*.
void main() {
  group('ReadingSchedule', () {
    test('carries every field the schedule endpoint expects', () {
      const ReadingSchedule schedule = ReadingSchedule(
        groupIds: <int>[3, 4],
        scheduledDate: '2026-10-21',
        bookNumber: 43,
        startChapter: 3,
        startVerse: 1,
        endChapter: 3,
        endVerse: 5,
        excludedVerses: <ExcludedVerse>[ExcludedVerse(chapter: 3, verse: 2)],
        generateAiQuestions: true,
      );

      expect(schedule.groupIds, <int>[3, 4]);
      expect(schedule.scheduledDate, '2026-10-21');
      expect(schedule.bookNumber, 43);
      expect(schedule.startChapter, 3);
      expect(schedule.startVerse, 1);
      expect(schedule.endChapter, 3);
      expect(schedule.endVerse, 5);
      expect(schedule.excludedVerses, <ExcludedVerse>[
        const ExcludedVerse(chapter: 3, verse: 2),
      ]);
      expect(schedule.generateAiQuestions, isTrue);
    });

    test('and `endChapter` is optional, because the server defaults it', () {
      // `admin.routes.ts:31-33`: the schema's transform writes
      // `end_chapter: data.end_chapter ?? data.start_chapter`, so a passage that
      // does not cross a chapter boundary says nothing about the end chapter.
      // A `null` here is **the absence of a value**, not a chapter number.
      const ReadingSchedule schedule = ReadingSchedule(
        groupIds: <int>[3],
        scheduledDate: '2026-10-21',
        bookNumber: 43,
        startChapter: 3,
        startVerse: 1,
        endVerse: 5,
      );

      expect(schedule.endChapter, isNull);
    });

    test('and the excluded verses and the AI switch have defaults', () {
      // The two fields the schedule body always carries. `excluded_verses`
      // defaults to `[]` on the server (`admin.routes.ts:28`) and
      // `generate_ai_questions` to `false` (`:29`), and a domain object that
      // had to be told both would make every caller repeat the server's own
      // defaults.
      const ReadingSchedule schedule = ReadingSchedule(
        groupIds: <int>[3],
        scheduledDate: '2026-10-21',
        bookNumber: 43,
        startChapter: 3,
        startVerse: 1,
        endVerse: 5,
      );

      expect(schedule.excludedVerses, isEmpty);
      expect(schedule.generateAiQuestions, isFalse);
    });
  });

  group('ExcludedVerse', () {
    test('carries the chapter and the verse', () {
      const ExcludedVerse excluded = ExcludedVerse(chapter: 3, verse: 2);

      expect(excluded.chapter, 3);
      expect(excluded.verse, 2);
    });
  });

  group('QuestionDraft', () {
    test('round-trips its options', () {
      const QuestionDraft draft = QuestionDraft(
        type: QuestionType.mcq,
        promptAr: 'ماذا يُعلّمنا النصّ؟',
        promptEn: 'What does the text show?',
        options: <String, QuestionOption>{
          'A': QuestionOption(ar: 'الخيار أ', en: 'Option A'),
          'B': QuestionOption(ar: 'الخيار ب', en: 'Option B'),
        },
        correctAnswer: 'A',
        pointsValue: 10,
        sortOrder: 1,
        isApproved: true,
      );

      expect(draft.options.keys, <String>['A', 'B']);
      expect(draft.options['A']?.ar, 'الخيار أ');
      expect(draft.options['A']?.en, 'Option A');
      expect(draft.options['B']?.ar, 'الخيار ب');
      expect(draft.options['B']?.en, 'Option B');
    });

    test('and an option carries both languages', () {
      const QuestionOption option = QuestionOption(ar: 'صحيح', en: 'True');

      expect(option.ar, 'صحيح');
      expect(option.en, 'True');
    });

    test('and the draft carries the three fields the commit body needs', () {
      // `points_value`, `sort_order` and `is_approved` are the commit schema's
      // own defaults (`admin.routes.ts:46-48`) — 10, 1 and `true` — and they
      // are on the entity rather than applied at the wire so that **a draft is
      // committable without a conversion** (the design spec §6.1).
      const QuestionDraft draft = QuestionDraft(
        type: QuestionType.trueFalse,
        promptAr: 'سؤال',
        promptEn: 'A question',
        options: <String, QuestionOption>{},
        correctAnswer: 'A',
        pointsValue: 10,
        sortOrder: 1,
        isApproved: true,
      );

      expect(draft.pointsValue, 10);
      expect(draft.sortOrder, 1);
      expect(draft.isApproved, isTrue);
    });
  });

  group('QuestionType', () {
    test('spells its wire value out per member', () {
      // The `UserRole.wireValue` rule (`core/domain/entities/user_role.dart`):
      // `.name` is the Dart spelling and is **never** a wire value. The backend's
      // union is `mcq | true_false | short_answer`
      // (`admin.routes.ts:38`), and `trueFalse.name` is `'trueFalse'`, which is
      // in none of them.
      expect(QuestionType.mcq.wireValue, 'mcq');
      expect(QuestionType.trueFalse.wireValue, 'true_false');
      expect(QuestionType.shortAnswer.wireValue, 'short_answer');
    });

    test('and decodes a wire value back', () {
      expect(QuestionType.fromWire('mcq'), QuestionType.mcq);
      expect(QuestionType.fromWire('true_false'), QuestionType.trueFalse);
      expect(QuestionType.fromWire('short_answer'), QuestionType.shortAnswer);
    });

    test('and refuses a value the backend never sends', () {
      // `null` and not a default: a fourth type would be a server change this
      // client has to be told about, and quietly reporting it as `mcq` would be
      // a wrong answer presented confidently. `LeaderboardWindow.fromCode` sets
      // the precedent.
      expect(QuestionType.fromWire('TRUE_FALSE'), isNull);
      expect(QuestionType.fromWire('essay'), isNull);
      expect(QuestionType.fromWire(''), isNull);
    });
  });

  group('ScheduleResult', () {
    test('carries the message and the reading ids', () {
      const ScheduleResult result = ScheduleResult(
        message: 'Successfully scheduled reading for 1 groups',
        readingIds: <String>['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
      );

      expect(result.message, 'Successfully scheduled reading for 1 groups');
      expect(result.readingIds, <String>[
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      ]);
    });

    test('and the ids are a list of strings', () {
      const ScheduleResult result = ScheduleResult(
        message: 'ok',
        readingIds: <String>['a', 'b'],
      );

      expect(result.readingIds, everyElement(isA<String>()));
      expect(result.readingIds, hasLength(2));
    });
  });

  group('CommitResult', () {
    test('carries the message and the question ids', () {
      const CommitResult result = CommitResult(
        message: 'Committed 1 questions for reading',
        questionIds: <String>['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'],
      );

      expect(result.message, 'Committed 1 questions for reading');
      expect(result.questionIds, <String>[
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      ]);
    });
  });

  group('ServantReport', () {
    test('carries the totals and the roster', () {
      const ServantReport report = ServantReport(
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
        ],
      );

      expect(report.groupId, 3);
      expect(report.reportDate, '2026-10-21');
      expect(report.totalStudents, 2);
      expect(report.completedCount, 1);
      expect(report.students, hasLength(1));
    });
  });

  group('RosterStudent', () {
    test("keeps the server's progress string verbatim", () {
      // `admin.routes.ts:412` builds it as `` `${answeredQ}/${totalQ}` `` — a
      // **string**, not two numbers. The domain keeps it as the server's own
      // token so the row can draw "3/5" exactly as the server wrote it, and so
      // no client-side arithmetic can disagree with the server's count.
      const RosterStudent student = RosterStudent(
        userId: '11111111-1111-1111-1111-111111111111',
        fullName: 'David Mina',
        preferredLang: 'en',
        totalPoints: 40,
        currentStreak: 4,
        pointsEarnedToday: 10,
        completedToday: true,
        questionsProgress: '3/5',
      );

      expect(student.questionsProgress, '3/5');
    });

    test('and carries the rest of the row', () {
      const RosterStudent student = RosterStudent(
        userId: '22222222-2222-2222-2222-222222222222',
        fullName: 'Peter George',
        preferredLang: 'ar',
        totalPoints: 25,
        currentStreak: 2,
        pointsEarnedToday: 0,
        completedToday: false,
        questionsProgress: '0/0',
      );

      expect(student.userId, '22222222-2222-2222-2222-222222222222');
      expect(student.fullName, 'Peter George');
      expect(student.preferredLang, 'ar');
      expect(student.totalPoints, 25);
      expect(student.currentStreak, 2);
      expect(student.pointsEarnedToday, 0);
      expect(student.completedToday, isFalse);
    });
  });
}
