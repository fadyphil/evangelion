import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:evangelion/features/servant/presentation/pages/schedule_reading_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../servant_harness.dart';

/// A fake **port**, and not a fake use case.
final class _Repo implements ServantAdminRepository {
  _Repo(this.result);

  /// What the next call answers.
  Result<ScheduleResult> result;

  /// Every schedule the port was asked for.
  final List<ReadingSchedule> asked = <ReadingSchedule>[];

  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async {
    asked.add(schedule);
    return result;
  }

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async => const Left<Failure, CommitResult>(
    Failure(kind: FailureKind.server, message: 'not used'),
  );

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async => const Left<Failure, QuestionDraft>(
    Failure(kind: FailureKind.server, message: 'not used'),
  );
}

/// The server's answer.
const ScheduleResult result = ScheduleResult(
  message: 'Successfully scheduled reading for 1 groups',
  readingIds: <String>['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
);

void main() {
  /// Fills the form with a passage.
  Future<void> fillTheForm(
    WidgetTester tester, {
    String startVerse = '1',
    String endVerse = '5',
  }) async {
    final Finder fields = find.byType(TextField);
    // **The form is longer than the surface**, so every field is scrolled to
    // before it is typed into — a tap that misses is a warning, not a failure,
    // and a silent miss would make the test pass for the wrong reason.
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), '3');
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), '2026-10-21');
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), '43');
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), '3');
    await tester.ensureVisible(fields.at(4));
    await tester.enterText(fields.at(4), startVerse);
    await tester.ensureVisible(fields.at(5));
    // **The end chapter is left empty** — a passage that stays in one chapter
    // has no end chapter, and the server's own transform substitutes the start
    // chapter for a missing one.
    await tester.enterText(fields.at(5), '');
    await tester.ensureVisible(fields.at(6));
    await tester.enterText(fields.at(6), endVerse);
    await tester.pump();
  }

  group('the two backend behaviours the screen must state', () {
    testWidgets('are on screen, next to the AI switch', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = ScheduleReadingCubit(
        scheduleReading: ScheduleReading(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        // **A surface the whole form fits on.** The schedule form is the
        // portal's longest — nine fields, a switch, two warnings and a button —
        // and a test that has to scroll to reach the button would be testing
        // the scroll rather than the form.
        size: const Size(390, 1500),
      );

      expect(
        find.text(
          'Scheduling the same cohort and date again replaces the passage.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Scheduling the same cohort and date again with this on deletes the '
          'questions already written for that date.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the reversed range', () {
    testWidgets('is refused by the form, and nothing is asked', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = ScheduleReadingCubit(
        scheduleReading: ScheduleReading(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        // **A surface the whole form fits on.** The schedule form is the
        // portal's longest — nine fields, a switch, two warnings and a button —
        // and a test that has to scroll to reach the button would be testing
        // the scroll rather than the form.
        size: const Size(390, 1500),
      );
      await fillTheForm(tester, startVerse: '9');
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(
        find.text('The start of the passage cannot be after its end.'),
        findsOneWidget,
      );
      expect(repo.asked, isEmpty);
    });
  });

  group('a correct form', () {
    testWidgets('is sent, and the server\'s sentence is on screen', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = ScheduleReadingCubit(
        scheduleReading: ScheduleReading(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        // **A surface the whole form fits on.** The schedule form is the
        // portal's longest — nine fields, a switch, two warnings and a button —
        // and a test that has to scroll to reach the button would be testing
        // the scroll rather than the form.
        size: const Size(390, 1500),
      );
      await fillTheForm(tester);
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(repo.asked, hasLength(1));
      expect(repo.asked.single.groupIds, <int>[3]);
      expect(repo.asked.single.scheduledDate, '2026-10-21');
      expect(repo.asked.single.bookNumber, 43);
      expect(
        find.text('Successfully scheduled reading for 1 groups'),
        findsOneWidget,
      );
    });
  });

  group('the AI switch', () {
    testWidgets('reaches the port', (WidgetTester tester) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = ScheduleReadingCubit(
        scheduleReading: ScheduleReading(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        // **A surface the whole form fits on.** The schedule form is the
        // portal's longest — nine fields, a switch, two warnings and a button —
        // and a test that has to scroll to reach the button would be testing
        // the scroll rather than the form.
        size: const Size(390, 1500),
      );
      await fillTheForm(tester);
      await tester.tap(find.byType(EvaToggle));
      await tester.pump();
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(repo.asked.single.generateAiQuestions, isTrue);
    });
  });
}
