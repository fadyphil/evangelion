import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/commit_questions.dart';
import 'package:evangelion/features/servant/domain/usecases/generate_ai_draft.dart';
import 'package:evangelion/features/servant/domain/usecases/load_daily_report.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// A recording admin port, so the assertions can be about the **request**.
///
/// A pass-through use case has almost nothing to assert about its return value —
/// and what it has is already covered by the "returns the port's answer
/// byte-identical" cases. These fakes exist so the *other* half is checkable:
/// that the use case hands the port exactly what it was given, in the field the
/// port names.
final class _RecordingAdminRepository implements ServantAdminRepository {
  _RecordingAdminRepository([this.answer]);

  final Result<ScheduleResult>? answer;
  final List<String> calls = <String>[];
  ReadingSchedule? scheduled;
  String? committedReadingId;
  List<QuestionDraft>? committedQuestions;
  String? draftedReadingId;
  QuestionType? draftedType;

  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async {
    calls.add('scheduleReading');
    scheduled = schedule;
    return answer ??
        const Right<Failure, ScheduleResult>(
          ScheduleResult(message: 'ok', readingIds: <String>[]),
        );
  }

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async {
    calls.add('commitQuestions');
    committedReadingId = readingId;
    committedQuestions = questions;
    return const Right<Failure, CommitResult>(
      CommitResult(message: 'ok', questionIds: <String>[]),
    );
  }

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async {
    calls.add('generateAiDraft');
    draftedReadingId = readingId;
    draftedType = type;
    return const Right<Failure, QuestionDraft>(
      QuestionDraft(
        type: QuestionType.mcq,
        promptAr: 'س',
        promptEn: 'q',
        options: <String, QuestionOption>{},
        correctAnswer: 'A',
        pointsValue: 10,
        sortOrder: 1,
        isApproved: true,
      ),
    );
  }
}

final class _RecordingReportRepository implements ServantReportRepository {
  _RecordingReportRepository([this.answer]);

  final Result<ServantReport>? answer;
  int? groupId;
  String? date;

  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) async {
    this.groupId = groupId;
    this.date = date;
    return answer ??
        const Right<Failure, ServantReport>(
          ServantReport(
            groupId: 3,
            reportDate: '2026-10-21',
            totalStudents: 0,
            completedCount: 0,
            students: <RosterStudent>[],
          ),
        );
  }
}

void main() {
  const ReadingSchedule schedule = ReadingSchedule(
    groupIds: <int>[3],
    scheduledDate: '2026-10-21',
    bookNumber: 43,
    startChapter: 3,
    startVerse: 1,
    endVerse: 5,
  );

  const QuestionDraft draft = QuestionDraft(
    type: QuestionType.mcq,
    promptAr: 'س',
    promptEn: 'q',
    options: <String, QuestionOption>{},
    correctAnswer: 'A',
    pointsValue: 10,
    sortOrder: 1,
    isApproved: true,
  );

  group('ScheduleReading', () {
    test('hands the schedule to the port unchanged', () async {
      final _RecordingAdminRepository repository = _RecordingAdminRepository();

      await ScheduleReading(repository)(schedule);

      expect(repository.scheduled, schedule);
      expect(repository.calls, <String>['scheduleReading']);
    });

    test("returns the port's answer byte-identical", () async {
      final _RecordingAdminRepository repository = _RecordingAdminRepository(
        const Right<Failure, ScheduleResult>(
          ScheduleResult(message: 'ok', readingIds: <String>['r1']),
        ),
      );

      expect(
        await ScheduleReading(repository)(schedule),
        const Right<Failure, ScheduleResult>(
          ScheduleResult(message: 'ok', readingIds: <String>['r1']),
        ),
      );
    });

    test("and the port's failure, unwrapped", () async {
      // A use case that reclassified a failure would be a second place where
      // the wire's meaning is decided (§3, DIP).
      const Failure failure = Failure(
        kind: FailureKind.validation,
        message: 'start boundary cannot be after end boundary',
      );
      final _RecordingAdminRepository repository = _RecordingAdminRepository(
        const Left<Failure, ScheduleResult>(failure),
      );

      expect(
        await ScheduleReading(repository)(schedule),
        const Left<Failure, ScheduleResult>(failure),
      );
    });
  });

  group('CommitQuestions', () {
    test(
      'hands the reading id and the questions to the port unchanged',
      () async {
        final _RecordingAdminRepository repository =
            _RecordingAdminRepository();

        await CommitQuestions(repository)(
          const CommitQuestionsParams(
            readingId: 'r1',
            questions: <QuestionDraft>[draft],
          ),
        );

        expect(repository.committedReadingId, 'r1');
        expect(repository.committedQuestions, <QuestionDraft>[draft]);
      },
    );

    test("returns the port's answer byte-identical", () async {
      final _RecordingAdminRepository repository = _RecordingAdminRepository();

      expect(
        await CommitQuestions(repository)(
          const CommitQuestionsParams(
            readingId: 'r1',
            questions: <QuestionDraft>[draft],
          ),
        ),
        isA<Right<Failure, CommitResult>>(),
      );
    });
  });

  group('GenerateAiDraft', () {
    test('hands the reading id and the type to the port unchanged', () async {
      final _RecordingAdminRepository repository = _RecordingAdminRepository();

      await GenerateAiDraft(repository)(
        const GenerateAiDraftParams(
          readingId: 'r1',
          type: QuestionType.trueFalse,
        ),
      );

      expect(repository.draftedReadingId, 'r1');
      expect(repository.draftedType, QuestionType.trueFalse);
    });

    test("returns the port's answer byte-identical", () async {
      final _RecordingAdminRepository repository = _RecordingAdminRepository();

      expect(
        await GenerateAiDraft(repository)(
          const GenerateAiDraftParams(readingId: 'r1', type: QuestionType.mcq),
        ),
        isA<Right<Failure, QuestionDraft>>(),
      );
    });
  });

  group('LoadDailyReport', () {
    test('hands the group id and the date to the port unchanged', () async {
      final _RecordingReportRepository repository =
          _RecordingReportRepository();

      await LoadDailyReport(repository)(
        const DailyReportQuery(groupId: 3, date: '2026-10-21'),
      );

      expect(repository.groupId, 3);
      expect(repository.date, '2026-10-21');
    });

    test("returns the port's answer byte-identical", () async {
      final _RecordingReportRepository repository = _RecordingReportRepository(
        const Right<Failure, ServantReport>(
          ServantReport(
            groupId: 3,
            reportDate: '2026-10-21',
            totalStudents: 1,
            completedCount: 1,
            students: <RosterStudent>[],
          ),
        ),
      );

      expect(
        await LoadDailyReport(repository)(
          const DailyReportQuery(groupId: 3, date: '2026-10-21'),
        ),
        const Right<Failure, ServantReport>(
          ServantReport(
            groupId: 3,
            reportDate: '2026-10-21',
            totalStudents: 1,
            completedCount: 1,
            students: <RosterStudent>[],
          ),
        ),
      );
    });

    test("and the port's failure, unwrapped", () async {
      const Failure failure = Failure(
        kind: FailureKind.notFound,
        message: 'Not Found',
      );
      final _RecordingReportRepository repository = _RecordingReportRepository(
        const Left<Failure, ServantReport>(failure),
      );

      expect(
        await LoadDailyReport(repository)(
          const DailyReportQuery(groupId: 3, date: '2026-10-21'),
        ),
        const Left<Failure, ServantReport>(failure),
      );
    });
  });
}
