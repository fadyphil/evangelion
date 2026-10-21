import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
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

  /// How many times the port was asked for a draft.
  int draftRequests = 0;

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async {
    draftRequests++;
    return draft;
  }

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

/// The cubit, with the page's reports counted.
///
/// **A spy, and not a mock**: the question is *which* of the cubit's writers
/// the page called, and a subclass that records the call and then does the
/// real thing answers it without replacing the cubit's behaviour. A mock
/// would have to answer `state` as well, and the state is what the page
/// renders.
final class _SpyCubit extends QuestionAuthoringCubit {
  _SpyCubit({required super.generateAiDraft, required super.commitQuestions});

  /// Every edit the page reported, in the page's own words.
  final List<String> reported = <String>[];

  @override
  void setPointsText(String text) {
    reported.add('points: $text');
    super.setPointsText(text);
  }

  @override
  void setSortOrderText(String text) {
    reported.add('order: $text');
    super.setSortOrderText(text);
  }
}

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

  /// The editor, painted and **settled**.
  ///
  /// ## WHY THE EXTRA PUMP IS **NOT** OPTIONAL
  ///
  /// The editor's one-sided sync writes the state's `pointsText` ('10') and
  /// `sortOrderText` ('1') into their two controllers on its **first**
  /// rebuild — the controllers start empty and the state does not. **Each
  /// write is reported to the cubit as an edit**, and the cubit's edit writer
  /// drops the failure and the form error with the edit they described.
  ///
  /// So an answer that arrives in the *same frame* as the editor's first
  /// rebuild is erased before the reader can read it. A test that presses the
  /// button on the first frame is measuring that race rather than the screen,
  /// and a person never does — the first frame is long gone by the time a
  /// finger lands.
  ///
  /// The extra pump is therefore the screen's own settling. **The race itself
  /// is a finding**, recorded in the report; it is not papered over here,
  /// because nothing in `lib/` is changed to make a line coverable.
  Future<void> pumpEditor(
    WidgetTester tester,
    Widget page, {
    Locale locale = const Locale('en'),
  }) async {
    await pumpServant(
      tester,
      page,
      locale: locale,
      size: const Size(390, 1500),
    );
    await tester.pump();
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

  group('the page\'s own writes', () {
    testWidgets('are not reported to the cubit as edits', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo();
      final _SpyCubit cubit = _SpyCubit(
        generateAiDraft: GenerateAiDraft(repo),
        commitQuestions: CommitQuestions(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: cubit, readingId: readingId),
        size: const Size(390, 1500),
      );
      await tester.pump();
      await tester.pump();

      // **The editor's one-sided sync writes the state's `pointsText` ('10')
      // and `sortOrderText` ('1') into two controllers that start empty**,
      // and that write is the page's own — a write the page made on purpose
      // is not something the reader did. Reported as an edit, it told the
      // cubit the reader had typed, and the cubit's edit writer dropped the
      // server's refusal with the edit it invented.
      expect(cubit.reported, isEmpty);
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

  // ## THE STATES THE ADMIN CAN REACH, AND THE TWO ARMS OF EACH
  //
  // A screen that says something is a screen that says it in **two**
  // languages, and a message that exists in only one of them is a message half
  // the readers never see. So every state below is asserted in **both** arms:
  // the English sentence, and then the same state repainted in Arabic.
  //
  // **The repaint is the same widget**, so the state under test is the state
  // the first arm produced — not a second, freshly-mounted screen.
  group('the failure', () {
    testWidgets('is the server\'s own sentence, with a retry', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      fixture.repo.draft = const Left<Failure, QuestionDraft>(
        Failure(
          kind: FailureKind.server,
          message: 'The AI service is not configured.',
        ),
      );

      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
      );
      await tester.ensureVisible(find.text('Ask for a draft'));
      await tester.tap(find.text('Ask for a draft'));
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      // **The server's own sentence**, verbatim.
      expect(find.text('The AI service is not configured.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        locale: otherArmFor(const Locale('en')),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('The AI service is not configured.'), findsOneWidget);
      // **And the retry is named in the reader's own language.**
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
    });

    testWidgets(
      'the server sent is still on screen after the editor\'s first rebuild',
      (WidgetTester tester) async {
        final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
        fixture.repo.draft = const Left<Failure, QuestionDraft>(
          Failure(
            kind: FailureKind.server,
            message: 'The AI service is not configured.',
          ),
        );

        await pumpServant(
          tester,
          QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
          size: const Size(390, 1500),
        );

        // **The request is asked for in the first frame**, so the server's
        // answer lands **before the editor's first rebuild** — the window in
        // which the editor's own write happens, and the window in which the
        // answer has to survive it.
        unawaited(fixture.cubit.requestDraft());
        await tester.pump();
        await tester.pump();

        // **The server's own sentence, still on screen.** The editor's
        // one-sided sync writes the state's `pointsText` and `sortOrderText`
        // into two controllers that start empty, and a write the page made on
        // purpose is not something the reader did: reported as an edit, it
        // took the failure with it, and the refusal was gone before the
        // reader could read it.
        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.text('The AI service is not configured.'), findsOneWidget);
        expect(fixture.cubit.state.failure, isNotNull);
      },
    );

    testWidgets(
      'and it survives the editor being opened over a cubit that holds it',
      (WidgetTester tester) async {
        final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
        fixture.repo.draft = const Left<Failure, QuestionDraft>(
          Failure(
            kind: FailureKind.server,
            message: 'The AI service is not configured.',
          ),
        );

        // **The cubit is a singleton** — `navigation_injection.dart` says so
        // and gives the reason: a second instance would be a second draft.
        // So a reader who left `/servant/questions` and came back finds the
        // editor over the cubit that still holds the refusal.
        fixture.cubit.setReadingId(readingId);
        await fixture.cubit.requestDraft();
        expect(fixture.cubit.state.failure, isNotNull);

        await pumpServant(
          tester,
          QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
          size: const Size(390, 1500),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.text('The AI service is not configured.'), findsOneWidget);
        expect(fixture.cubit.state.failure, isNotNull);
      },
    );

    testWidgets('and the retry asks for a draft again', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      fixture.repo.draft = const Left<Failure, QuestionDraft>(
        Failure(kind: FailureKind.server, message: 'The AI service is down.'),
      );

      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
      );
      await tester.ensureVisible(find.text('Ask for a draft'));
      await tester.tap(find.text('Ask for a draft'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();

      // **The draft request, twice** — the failure named the request that
      // failed, so the retry repeats that one.
      expect(fixture.repo.draftRequests, 2);
    });
  });

  group('the options', () {
    testWidgets('are added under the first free letter, and removed again', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
      );

      await tester.ensureVisible(find.text('Add an option'));
      await tester.tap(find.text('Add an option'));
      await tester.pump();

      // **The letter is the option's key**, because the commit body carries the
      // options as a map keyed by it.
      expect(fixture.cubit.state.draft!.options.keys, <String>['A']);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // **And the two halves of the option are the question's.**
      final Finder fields = find.byType(TextField);
      await tester.ensureVisible(fields.at(3));
      await tester.enterText(fields.at(3), 'الخير');
      await tester.ensureVisible(fields.at(4));
      await tester.enterText(fields.at(4), 'The good');
      await tester.pump();

      expect(fixture.cubit.state.draft!.options['A']!.ar, 'الخير');
      expect(fixture.cubit.state.draft!.options['A']!.en, 'The good');

      // **And the option is taken away again.**
      await tester.ensureVisible(find.text('Remove'));
      await tester.tap(find.text('Remove'));
      await tester.pump();

      expect(fixture.cubit.state.draft!.options, isEmpty);
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('and the editor names its two fields in both languages', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
      );
      await tester.ensureVisible(find.text('Add an option'));
      await tester.tap(find.text('Add an option'));
      await tester.pump();

      expect(find.text('OPTION IN ARABIC'), findsOneWidget);
      expect(find.text('OPTION IN ENGLISH'), findsOneWidget);

      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        locale: otherArmFor(const Locale('en')),
      );

      expect(find.text('الخيار بالعربية'), findsOneWidget);
      expect(find.text('الخيار بالإنجليزية'), findsOneWidget);
      expect(find.text('احذف'), findsOneWidget);
    });
  });

  group('the question\'s type', () {
    testWidgets('a short answer has no options, and the screen says so', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
      );

      // **The type is the admin's choice**, and the screen changes with it: a
      // short answer has no options to offer.
      await tester.ensureVisible(find.text('SHORT ANSWER'));
      await tester.tap(find.text('SHORT ANSWER'));
      await tester.pump();

      expect(fixture.cubit.state.draft!.type, QuestionType.shortAnswer);
      expect(
        find.text('A short-answer question has no options.'),
        findsOneWidget,
      );
      expect(find.text('Add an option'), findsNothing);

      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit, readingId: readingId),
        locale: otherArmFor(const Locale('en')),
      );

      expect(
        find.text('سؤال الإجابة القصيرة لا يحتاج خيارات.'),
        findsOneWidget,
      );
    });
  });

  group('the refusals', () {
    /// Fills the reading id, and nothing else.
    Future<void> typeTheReadingId(WidgetTester tester) async {
      final Finder fields = find.byType(TextField);
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), readingId);
      await tester.pump();
    }

    /// Presses the commit button.
    Future<void> commit(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Commit the question'));
      await tester.tap(find.text('Commit the question'));
      await tester.pump();
    }

    testWidgets(
      'a question with one language is refused, and nothing is sent',
      (WidgetTester tester) async {
        final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
        await pumpEditor(tester, QuestionAuthoringPage(cubit: fixture.cubit));
        await typeTheReadingId(tester);
        await commit(tester);

        expect(find.text('The question needs both languages.'), findsOneWidget);
        expect(fixture.repo.committed, isEmpty);

        await pumpEditor(
          tester,
          QuestionAuthoringPage(cubit: fixture.cubit),
          locale: otherArmFor(const Locale('en')),
        );

        expect(find.text('السؤال يحتاج إلى اللغتين.'), findsOneWidget);
      },
    );

    testWidgets(
      'a question with no correct answer is refused, and nothing is sent',
      (WidgetTester tester) async {
        final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
        await pumpEditor(tester, QuestionAuthoringPage(cubit: fixture.cubit));
        await typeTheReadingId(tester);
        final Finder fields = find.byType(TextField);
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), 'سؤال');
        await tester.ensureVisible(fields.at(2));
        await tester.enterText(fields.at(2), 'A question');
        await tester.pump();
        await commit(tester);

        expect(find.text('Say which answer is correct.'), findsOneWidget);
        expect(fixture.repo.committed, isEmpty);

        await pumpEditor(
          tester,
          QuestionAuthoringPage(cubit: fixture.cubit),
          locale: otherArmFor(const Locale('en')),
        );

        expect(find.text('حدّد الإجابة الصحيحة.'), findsOneWidget);
      },
    );

    testWidgets(
      'a points value that is not a whole number is refused, and nothing is sent',
      (WidgetTester tester) async {
        final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
        await pumpEditor(tester, QuestionAuthoringPage(cubit: fixture.cubit));
        await typeTheReadingId(tester);
        final Finder fields = find.byType(TextField);
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), 'سؤال');
        await tester.ensureVisible(fields.at(2));
        await tester.enterText(fields.at(2), 'A question');
        await tester.ensureVisible(fields.at(3));
        await tester.enterText(fields.at(3), 'A');
        await tester.ensureVisible(fields.at(4));
        await tester.enterText(fields.at(4), 'ten');
        await tester.pump();
        await commit(tester);

        expect(find.text('That is not a whole number.'), findsOneWidget);
        expect(fixture.repo.committed, isEmpty);

        await pumpEditor(
          tester,
          QuestionAuthoringPage(cubit: fixture.cubit),
          locale: otherArmFor(const Locale('en')),
        );

        expect(find.text('هذا ليس عددًا صحيحًا.'), findsOneWidget);
      },
    );

    testWidgets('a question with no reading id is refused, in both languages', (
      WidgetTester tester,
    ) async {
      final ({QuestionAuthoringCubit cubit, _Repo repo}) fixture = editor();
      await pumpEditor(tester, QuestionAuthoringPage(cubit: fixture.cubit));
      await commit(tester);

      expect(find.text('Type the reading id first.'), findsOneWidget);
      expect(fixture.repo.committed, isEmpty);

      await pumpEditor(
        tester,
        QuestionAuthoringPage(cubit: fixture.cubit),
        locale: otherArmFor(const Locale('en')),
      );

      expect(find.text('اكتب معرّف القراءة أولًا.'), findsOneWidget);
    });
  });
}
