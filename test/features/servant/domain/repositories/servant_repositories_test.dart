import 'dart:io';

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
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// The two ports, and the contract they state.
///
/// ## WHAT IS ASSERTED HERE, AND WHAT IS ASSERTED ELSEWHERE
///
/// * **Here:** the two ports are **narrow** and **separate**, and every method
///   answers a [Result] rather than throwing.
/// * **Elsewhere** (`test/features/servant/data/repositories/`): that the shipped
///   adapters keep that promise against a real transport.
///
/// ## WHY THE PORT FILES ARE READ AS TEXT
///
/// Dart has no reflection, so "this port has exactly one method" is not
/// something a test can ask the type system at runtime. It can, however, be
/// asked of the **source**, and the source is where a port's method list lives.
///
/// The compile-time half of the same claim is in this file too: [_FakeReportRepository]
/// implements `ServantReportRepository` and declares **one** method. If the
/// report port were fat — if it carried the admin methods too — that class would
/// not compile. So the narrowness is proved twice: once by the analyzer and once
/// by the scan, and the scan is what catches a *second* method added to a port
/// later.
final class _FakeAdminRepository implements ServantAdminRepository {
  final List<String> calls = <String>[];

  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async {
    calls.add('scheduleReading');
    return const Right<Failure, ScheduleResult>(
      ScheduleResult(message: 'scheduled', readingIds: <String>['r1']),
    );
  }

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async {
    calls.add('commitQuestions');
    return const Right<Failure, CommitResult>(
      CommitResult(message: 'committed', questionIds: <String>['q1']),
    );
  }

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async {
    calls.add('generateAiDraft');
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

/// A report port fake that declares **one** method.
///
/// It compiles only because `ServantReportRepository` asks for exactly one.
final class _FakeReportRepository implements ServantReportRepository {
  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) async => const Right<Failure, ServantReport>(
    ServantReport(
      groupId: 3,
      reportDate: '2026-10-21',
      totalStudents: 0,
      completedCount: 0,
      students: <RosterStudent>[],
    ),
  );
}

/// The method names declared by a port file.
///
/// Read from the source because Dart has no reflection. The pattern is anchored
/// to `Future<Result<` so it cannot match a doc comment's prose about a
/// method — the same rule `verify_purity.sh` follows for its directives.
List<String> _declaredMethods(String path) {
  return <String>[
    for (final RegExpMatch match in RegExp(
      r'Future<Result<[^>]*>>\s+(\w+)\s*\(',
    ).allMatches(File(path).readAsStringSync()))
      match.group(1)!,
  ];
}

void main() {
  group('the two ports are narrow, and they are separate', () {
    test('the admin port carries the three admin operations', () {
      expect(
        _declaredMethods(
          'lib/features/servant/domain/repositories/servant_admin_repository.dart',
        ),
        <String>['scheduleReading', 'commitQuestions', 'generateAiDraft'],
      );
    });

    test('and the report port carries the one report operation', () {
      expect(
        _declaredMethods(
          'lib/features/servant/domain/repositories/servant_report_repository.dart',
        ),
        <String>['loadDailyReport'],
      );
    });

    test('and neither carries the other\'s operations', () {
      // The ISP claim, made mechanically: a fat port would put the report's
      // one method and the admin's three on the same interface, and every
      // consumer of one would be handed the other.
      final List<String> admin = _declaredMethods(
        'lib/features/servant/domain/repositories/servant_admin_repository.dart',
      );
      final List<String> report = _declaredMethods(
        'lib/features/servant/domain/repositories/servant_report_repository.dart',
      );

      expect(admin.toSet().intersection(report.toSet()), isEmpty);
    });
  });

  group('every port method answers a Result', () {
    test('the admin port', () async {
      final _FakeAdminRepository repository = _FakeAdminRepository();

      final Result<ScheduleResult> scheduled = await repository.scheduleReading(
        const ReadingSchedule(
          groupIds: <int>[3],
          scheduledDate: '2026-10-21',
          bookNumber: 43,
          startChapter: 3,
          startVerse: 1,
          endVerse: 5,
        ),
      );
      final Result<CommitResult> committed = await repository.commitQuestions(
        readingId: 'r1',
        questions: const <QuestionDraft>[],
      );
      final Result<QuestionDraft> drafted = await repository.generateAiDraft(
        readingId: 'r1',
        type: QuestionType.mcq,
      );

      expect(scheduled, isA<Right<Failure, ScheduleResult>>());
      expect(committed, isA<Right<Failure, CommitResult>>());
      expect(drafted, isA<Right<Failure, QuestionDraft>>());
      expect(repository.calls, <String>[
        'scheduleReading',
        'commitQuestions',
        'generateAiDraft',
      ]);
    });

    test('the report port', () async {
      final _FakeReportRepository repository = _FakeReportRepository();

      final Result<ServantReport> report = await repository.loadDailyReport(
        groupId: 3,
        date: '2026-10-21',
      );

      expect(report, isA<Right<Failure, ServantReport>>());
    });

    test('and a failure is a Result too, not an exception', () {
      // The other half of the contract (§3's LSP row): a port method that
      // answered a `Failure` is a caller that can handle it, and one that
      // threw would be a caller that cannot.
      const Failure failure = Failure(
        kind: FailureKind.validation,
        message: 'start boundary cannot be after end boundary',
      );
      const Result<ScheduleResult> refused = Left<Failure, ScheduleResult>(
        failure,
      );

      expect(refused, isA<Left<Failure, ScheduleResult>>());
      expect(refused.failureOrElse(failure), failure);
    });
  });
}
