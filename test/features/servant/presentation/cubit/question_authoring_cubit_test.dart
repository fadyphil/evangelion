import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/commit_questions.dart';
import 'package:evangelion/features/servant/domain/usecases/generate_ai_draft.dart';
import 'package:evangelion/features/servant/presentation/cubit/question_authoring_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// The question editor's cubit — red-first (AGENT_CONTEXT §6).
///
/// ## WHY THE MOCK IS OVER THE **PORT**
///
/// `GenerateAiDraft` and `CommitQuestions` are `final class`es, so they cannot
/// be implemented from outside their library — and that is the right
/// constraint. The cubit is therefore driven over the **real** use cases, which
/// exercise their pass-through on the way in.
class MockServantAdminRepository extends Mock
    implements ServantAdminRepository {}

/// The server's draft.
const QuestionDraft draft = QuestionDraft(
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

/// The server's answer to a commit.
const CommitResult commitResult = CommitResult(
  message: 'Committed 1 questions for reading',
  questionIds: <String>['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'],
);

/// The server's own refusal.
const Failure failure = Failure(kind: FailureKind.server, message: 'HTTP 500');

/// The reading the question belongs to.
const String readingId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

void main() {
  late MockServantAdminRepository repository;

  setUpAll(() {
    // mocktail needs a fallback for the two params objects, because
    // `captureAny()` is matched loosely against a non-nullable value.
    registerFallbackValue(
      const GenerateAiDraftParams(readingId: '', type: QuestionType.mcq),
    );
    registerFallbackValue(
      const CommitQuestionsParams(readingId: '', questions: <QuestionDraft>[]),
    );
    // And for the question type, because `any(named: 'type')` is matched
    // loosely against a non-nullable enum.
    registerFallbackValue(QuestionType.mcq);
  });

  setUp(() {
    repository = MockServantAdminRepository();
    when(
      () => repository.generateAiDraft(
        readingId: any(named: 'readingId'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => Result<QuestionDraft>.of(draft));
    when(
      () => repository.commitQuestions(
        readingId: any(named: 'readingId'),
        questions: any(named: 'questions'),
      ),
    ).thenAnswer((_) async => Result<CommitResult>.of(commitResult));
  });

  /// A cubit over the **real** use cases, with the reading id already given.
  ///
  /// The id is **typed in** rather than seeded, because a seeded state is a
  /// state the production code never builds and the reading id is the one
  /// field the admin really does fill in.
  QuestionAuthoringCubit cubitWith({String id = readingId}) {
    final QuestionAuthoringCubit cubit = QuestionAuthoringCubit(
      generateAiDraft: GenerateAiDraft(repository),
      commitQuestions: CommitQuestions(repository),
    );
    cubit.setReadingId(id);
    return cubit;
  }

  /// The questions the port was asked to commit.
  List<List<QuestionDraft>> capturedQuestions() => verify(
    () => repository.commitQuestions(
      readingId: any(named: 'readingId'),
      questions: captureAny(named: 'questions'),
    ),
  ).captured.cast<List<QuestionDraft>>();

  group('the AI draft', () {
    blocTest<QuestionAuthoringCubit, QuestionAuthoringState>(
      'the draft arrives, and it is the question on screen',
      build: cubitWith,
      seed: () => const QuestionAuthoringState(
        status: QuestionAuthoringStatus.ready,
        readingId: readingId,
      ),
      act: (QuestionAuthoringCubit cubit) => cubit.requestDraft(),
      expect: () => <QuestionAuthoringState>[
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.working,
          readingId: readingId,
        ),
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.ready,
          readingId: readingId,
          draft: draft,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.generateAiDraft(
            readingId: readingId,
            type: QuestionType.mcq,
          ),
        ).called(1);
      },
    );

    blocTest<QuestionAuthoringCubit, QuestionAuthoringState>(
      'and a failure is the server\'s own failure, with the draft kept',
      setUp: () {
        when(
          () => repository.generateAiDraft(
            readingId: any(named: 'readingId'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => const Left<Failure, QuestionDraft>(failure));
      },
      build: cubitWith,
      seed: () => const QuestionAuthoringState(
        status: QuestionAuthoringStatus.ready,
        readingId: readingId,
      ),
      act: (QuestionAuthoringCubit cubit) => cubit.requestDraft(),
      expect: () => <QuestionAuthoringState>[
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.working,
          readingId: readingId,
        ),
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.draftFailed,
          readingId: readingId,
          failure: failure,
        ),
      ],
    );

    test(
      'and a request with no reading id is refused, and nothing is asked',
      () async {
        final QuestionAuthoringCubit cubit = cubitWith(id: '');
        await cubit.requestDraft();

        expect(
          cubit.state.formError,
          QuestionAuthoringFormError.missingReadingId,
        );
        verifyNever(
          () => repository.generateAiDraft(
            readingId: any(named: 'readingId'),
            type: any(named: 'type'),
          ),
        );

        await cubit.close();
      },
    );
  });

  group('the commit', () {
    blocTest<QuestionAuthoringCubit, QuestionAuthoringState>(
      'the question is committed, and the server\'s answer is on screen',
      build: cubitWith,
      seed: () => const QuestionAuthoringState(
        status: QuestionAuthoringStatus.ready,
        readingId: readingId,
        draft: draft,
      ),
      act: (QuestionAuthoringCubit cubit) => cubit.commit(),
      expect: () => <QuestionAuthoringState>[
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.working,
          readingId: readingId,
          draft: draft,
        ),
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.ready,
          readingId: readingId,
          draft: draft,
          commitResult: commitResult,
        ),
      ],
    );

    test('and the committed question is the one on screen', () async {
      final QuestionAuthoringCubit cubit = cubitWith();
      cubit.setPromptAr('سؤال');
      cubit.setPromptEn('A question');
      cubit.setCorrectAnswer('A');
      await cubit.commit();

      final List<List<QuestionDraft>> sent = capturedQuestions();
      expect(sent, hasLength(1));
      expect(sent.single.single.promptAr, 'سؤال');
      expect(sent.single.single.promptEn, 'A question');
      expect(sent.single.single.correctAnswer, 'A');

      await cubit.close();
    });

    test('and an empty prompt is refused, and nothing is asked', () async {
      final QuestionAuthoringCubit cubit = cubitWith();
      cubit.setPromptAr('سؤال');
      // The English prompt was never written.
      await cubit.commit();

      expect(cubit.state.formError, QuestionAuthoringFormError.emptyPrompt);
      verifyNever(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      );

      await cubit.close();
    });

    test(
      'and an empty correct answer is refused, and nothing is asked',
      () async {
        final QuestionAuthoringCubit cubit = cubitWith();
        cubit.setPromptAr('سؤال');
        cubit.setPromptEn('A question');
        await cubit.commit();

        expect(
          cubit.state.formError,
          QuestionAuthoringFormError.emptyCorrectAnswer,
        );
        verifyNever(
          () => repository.commitQuestions(
            readingId: any(named: 'readingId'),
            questions: any(named: 'questions'),
          ),
        );

        await cubit.close();
      },
    );
  });

  group('the editor', () {
    test('the first thing the admin writes creates the question', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      expect(cubit.state.draft, isNull);
      cubit.setPromptEn('A question');

      expect(cubit.state.draft, isNotNull);
      expect(cubit.state.draft!.promptEn, 'A question');
      expect(cubit.state.status, QuestionAuthoringStatus.ready);

      await cubit.close();
    });

    test('an option is added under a letter, and removed again', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      cubit.addOption('A');
      expect(cubit.state.draft!.options.keys, <String>['A']);
      expect(cubit.state.draft!.options['A']!.ar, '');

      cubit.setOptionText('A', arabic: true, text: 'الخير');
      expect(cubit.state.draft!.options['A']!.ar, 'الخير');
      expect(cubit.state.draft!.options['A']!.en, '');

      cubit.setOptionText('A', arabic: false, text: 'The good');
      expect(cubit.state.draft!.options['A']!.en, 'The good');

      cubit.removeOption('A');
      expect(cubit.state.draft!.options, isEmpty);

      await cubit.close();
    });

    test('a letter that is already in use is refused', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      cubit.addOption('A');
      cubit.setOptionText('A', arabic: true, text: 'الخير');
      cubit.addOption('A');

      expect(cubit.state.draft!.options['A']!.ar, 'الخير');

      await cubit.close();
    });

    test('the points and the order are the question\'s own', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      cubit.setPointsText('20');
      cubit.setSortOrderText('3');

      expect(cubit.state.draft!.pointsValue, 20);
      expect(cubit.state.draft!.sortOrder, 3);
      expect(cubit.state.pointsText, '20');
      expect(cubit.state.sortOrderText, '3');

      await cubit.close();
    });

    test(
      'an edit forgets the last failure, because it described another question',
      () async {
        final QuestionAuthoringCubit cubit = cubitWith();
        when(
          () => repository.generateAiDraft(
            readingId: any(named: 'readingId'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => const Left<Failure, QuestionDraft>(failure));

        await cubit.requestDraft();
        expect(cubit.state.failure, failure);

        cubit.setPromptEn('A question');
        expect(cubit.state.failure, isNull);
        expect(cubit.state.status, QuestionAuthoringStatus.ready);

        await cubit.close();
      },
    );
  });
}
