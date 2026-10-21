import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/commit_questions.dart';
import 'package:evangelion/features/servant/domain/usecases/generate_ai_draft.dart';
import 'package:evangelion/features/servant/presentation/cubit/question_authoring_cubit.dart';
import 'package:evangelion/features/servant/presentation/pages/question_authoring_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../servant_harness.dart';

/// A fake **port**, and not a fake use case.
final class _Repo implements ServantAdminRepository {
  _Repo();

  /// What the draft request answers.
  Result<QuestionDraft> draft = Result<QuestionDraft>.of(serverDraft);

  /// What the commit request answers.
  Result<CommitResult> commit = Result<CommitResult>.of(
    const CommitResult(
      message: 'Committed 1 questions for reading',
      questionIds: <String>['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'],
    ),
  );

  /// Every question the port was asked to commit.
  final List<List<QuestionDraft>> committed = <List<QuestionDraft>>[];

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async => draft;

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async {
    committed.add(questions);
    return commit;
  }

  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async => const Left<Failure, ScheduleResult>(
    Failure(kind: FailureKind.server, message: 'not used'),
  );
}

/// The server's draft.
const QuestionDraft serverDraft = QuestionDraft(
  type: QuestionType.mcq,
  promptAr: 'ماذا قال المسيح؟',
  promptEn: 'What did Christ say?',
  options: <String, QuestionOption>{
    'A': QuestionOption(ar: 'الخير', en: 'The good'),
    'B': QuestionOption(ar: 'الشر', en: 'The evil'),
  },
  correctAnswer: 'A',
  pointsValue: 10,
  sortOrder: 1,
  isApproved: true,
);

/// The reading the route carried.
const String readingId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

void main() {
  /// The editor, over a fresh fake and a fresh cubit.
  ({QuestionAuthoringCubit cubit, _Repo repo}) editor() {
    final _Repo repo = _Repo();
    final QuestionAuthoringCubit cubit = QuestionAuthoringCubit(
      generateAiDraft: GenerateAiDraft(repo),
      commitQuestions: CommitQuestions(repo),
    );
    addTearDown(cubit.close);
    return (cubit: cubit, repo: repo);
  }

  group('the draft', () {
    testWidgets('fills the fields', (WidgetTester tester) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        size: const Size(390, 1500),
      );

      await tester.ensureVisible(find.text('Ask for a draft'));
      await tester.tap(find.text('Ask for a draft'));
      await tester.pump();

      expect(find.text('What did Christ say?'), findsOneWidget);
      expect(find.text('ماذا قال المسيح؟'), findsOneWidget);
      expect(find.text('The good'), findsOneWidget);
    });
  });

  group('an edit', () {
    testWidgets('survives the draft that filled the fields', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        size: const Size(390, 1500),
      );

      await tester.ensureVisible(find.text('Ask for a draft'));
      await tester.tap(find.text('Ask for a draft'));
      await tester.pump();

      final Finder prompts = find.byType(TextField);
      // **The English prompt** is the second field — the reading id is the
      // first, and the type control is not a field.
      await tester.enterText(prompts.at(2), 'What did the boy say?');
      await tester.pump();

      // **The field keeps what the admin typed**, and the cubit holds it.
      expect(find.text('What did the boy say?'), findsOneWidget);
      expect(fixture.cubit.state.draft!.promptEn, 'What did the boy say?');
    });
  });

  group('the commit', () {
    testWidgets('sends the edited question', (WidgetTester tester) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        size: const Size(390, 1500),
      );

      await tester.ensureVisible(find.text('Ask for a draft'));
      await tester.tap(find.text('Ask for a draft'));
      await tester.pump();

      final Finder prompts = find.byType(TextField);
      await tester.enterText(prompts.at(2), 'What did the boy say?');
      await tester.pump();

      await tester.ensureVisible(find.text('Commit the question'));
      await tester.tap(find.text('Commit the question'));
      await tester.pump();

      expect(fixture.repo.committed, hasLength(1));
      expect(
        fixture.repo.committed.single.single.promptEn,
        'What did the boy say?',
      );
      expect(fixture.repo.committed.single.single.promptAr, 'ماذا قال المسيح؟');
      expect(find.text('Committed 1 questions for reading'), findsOneWidget);
    });

    testWidgets('is refused when there is no reading id', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit),
        size: const Size(390, 1500),
      );

      await tester.ensureVisible(find.text('Commit the question'));
      await tester.tap(find.text('Commit the question'));
      await tester.pump();

      expect(fixture.repo.committed, isEmpty);
      expect(find.text('Type the reading id first.'), findsOneWidget);
    });
  });

  group('where the reading id came from', () {
    testWidgets('is said on the screen', (WidgetTester tester) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        size: const Size(390, 1500),
      );

      expect(
        find.text(
          "There is no list of a cohort's scheduled readings, so this id is the "
          'one the schedule answered with or one you typed.',
        ),
        findsOneWidget,
      );
    });
  });
}
