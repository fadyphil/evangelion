import 'dart:async';

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

/// **THE OTHER READING**, and the one the admin types while a request is open.
///
/// **A DIFFERENT READING, AND NOT A MALFORMED ONE.** The defect is about a
/// question about one passage being stored against another reading, so the
/// id has to be a **real** one — a typo would be a different defect, and a
/// test that proved the wrong one would be a test about nothing.
const String otherReadingId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

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
        // **AND THE DRAFT REMEMBERS THE READING IT WAS ASKED FOR** — that is
        // what lets the commit refuse to send it against another one.
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.ready,
          readingId: readingId,
          draft: draft,
          draftReadingId: readingId,
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

  // ## THE ANSWER THAT LANDS UNDER A FORM THAT **MOVED ON**
  //
  // `requestDraft` is a **READ** — the ai-generate route writes nothing: it
  // selects the reading, extracts the verses, calls the AI and returns the
  // draft (`ai.routes.ts:47-110`). So its answer is a **picture of the form's
  // result**, and the house's rule is that a read's answer goes when the form
  // moves on.
  //
  // **AND THE READING ID AND THE **TYPE** ARE BOTH PART OF THE REQUEST.** The
  // request names a reading and a type (`ai.routes.ts:10` accepts two of the
  // three), and **both** are editable while the request is open — the reading
  // id is a field and the type is a control, and neither is disabled while
  // the request is in flight. A comparison that forgot the type would be
  // incomplete, and the defect it would leave is the same one.
  group('the draft that lands under a form that moved on', () {
    /// The request, held open until the test releases it.
    ///
    /// **A HELD ANSWER, BECAUSE A PORT THAT ANSWERS AT ONCE CANNOT PRODUCE
    /// THIS ORDER AT ALL.** The defect is a **timing** defect: the form moves
    /// on **before** the answer exists.
    ///
    /// The three members are the cubit, the **held** answer, and the request's
    /// own future — the last one because the test has to **await** the
    /// request's completion, and the request cannot complete until the answer
    /// is released.
    ({
      QuestionAuthoringCubit cubit,
      Completer<Result<QuestionDraft>> answer,
      Future<void> pending,
    })
    openRequest() {
      final Completer<Result<QuestionDraft>> answer =
          Completer<Result<QuestionDraft>>();
      when(
        () => repository.generateAiDraft(
          readingId: any(named: 'readingId'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) => answer.future);
      final QuestionAuthoringCubit cubit = cubitWith();
      final Future<void> pending = cubit.requestDraft();
      expect(cubit.state.status, QuestionAuthoringStatus.working);
      return (cubit: cubit, answer: answer, pending: pending);
    }

    test('is not applied, because the reading id is another one', () async {
      final ({
        QuestionAuthoringCubit cubit,
        Completer<Result<QuestionDraft>> answer,
        Future<void> pending,
      })
      fixture = openRequest();

      // **THE ADMIN CORRECTS THE READING ID WHILE THE REQUEST IS OPEN.**
      fixture.cubit.setReadingId(otherReadingId);

      fixture.answer.complete(Result<QuestionDraft>.of(draft));
      await fixture.pending;

      // **AND THE DRAFT IS NOT THE QUESTION ON SCREEN.** The draft is a
      // question about the FIRST reading's passage, and the form names the
      // second — and the commit would send the first reading's question
      // against the second reading's id.
      expect(
        fixture.cubit.state.draft?.promptEn,
        isNot(draft.promptEn),
        reason:
            'the request asked for one reading and the form names another, so '
            'the answer describes a form that is not on screen',
      );
      // **AND THE EDITOR IS BACK ON ITS ARM**, so the admin presses again.
      expect(fixture.cubit.state.status, QuestionAuthoringStatus.ready);

      await fixture.cubit.close();
    });

    test('and the type is part of the request\'s identity too', () async {
      final ({
        QuestionAuthoringCubit cubit,
        Completer<Result<QuestionDraft>> answer,
        Future<void> pending,
      })
      fixture = openRequest();

      // **THE ADMIN CHANGES THE QUESTION'S TYPE WHILE THE REQUEST IS OPEN.**
      // The type is in the request (`ai.routes.ts:10`), and the control that
      // offers it is not disabled while the request is in flight.
      fixture.cubit.setType(QuestionType.trueFalse);

      fixture.answer.complete(Result<QuestionDraft>.of(draft));
      await fixture.pending;

      // **AND THE DRAFT IS NOT THE QUESTION ON SCREEN** — a draft of one type
      // is not the draft of another.
      expect(
        fixture.cubit.state.draft?.promptEn,
        isNot(draft.promptEn),
        reason:
            'the request asked for one type and the form names another, so '
            'the answer describes a form that is not on screen',
      );
      expect(fixture.cubit.state.status, QuestionAuthoringStatus.ready);

      await fixture.cubit.close();
    });
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

    blocTest<QuestionAuthoringCubit, QuestionAuthoringState>(
      'and a failed commit is the server\'s own failure, with the question kept',
      setUp: () {
        when(
          () => repository.commitQuestions(
            readingId: any(named: 'readingId'),
            questions: any(named: 'questions'),
          ),
        ).thenAnswer((_) async => const Left<Failure, CommitResult>(failure));
      },
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
        // **The question is kept**, because the question on screen is the one
        // the server refused, and a form that emptied itself on a refusal
        // would make the admin write it a second time.
        const QuestionAuthoringState(
          status: QuestionAuthoringStatus.commitFailed,
          readingId: readingId,
          draft: draft,
          failure: failure,
        ),
      ],
    );

    test(
      'and a points value that is not a whole number is refused, and nothing '
      'is asked',
      () async {
        final QuestionAuthoringCubit cubit = cubitWith();
        cubit.setPromptAr('سؤال');
        cubit.setPromptEn('A question');
        cubit.setCorrectAnswer('A');
        // **Half-typed, not wrong.** `1` on its way to `12` is a string, and
        // the commit parses the text and refuses when it cannot.
        cubit.setPointsText('ten');
        await cubit.commit();

        expect(cubit.state.formError, QuestionAuthoringFormError.invalidNumber);
        // **And the draft keeps the last value it understood** — the draft's
        // number is 10, because `ten` never parsed.
        expect(cubit.state.draft!.pointsValue, 10);
        expect(cubit.state.pointsText, 'ten');
        verifyNever(
          () => repository.commitQuestions(
            readingId: any(named: 'readingId'),
            questions: any(named: 'questions'),
          ),
        );

        await cubit.close();
      },
    );

    // ## THE COMMIT AGAINST A DRAFT THAT BELONGS TO **ANOTHER READING**
    //
    // **THIS IS THE WRITE HALF, AND IT IS THE ONE THAT MATTERS.** The read's
    // half drops a draft that lands under a form that moved on — but even with
    // that fixed, an admin can have a draft for reading A on screen, change
    // the reading id to B, and commit: **B's id with A's question**, a
    // question about one passage stored against another reading.
    //
    // **A REFUSAL IS BETTER THAN A WRONG WRITE**, and the refusal has to be
    // **visible** — the admin is told why.
    test('a draft that belongs to another reading is refused, and nothing is '
        'asked', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      // **THE DRAFT IS ASKED FOR, AND IT ARRIVES.** The request names the
      // reading the form named, so the draft is the form's own.
      await cubit.requestDraft();
      expect(cubit.state.draft, draft);

      // **AND THE ADMIN CHANGES THE READING.** The reading id is a field
      // and it is editable while the form is open.
      cubit.setReadingId(otherReadingId);

      await cubit.commit();

      // **SO THE COMMIT IS REFUSED**, and the admin is told why.
      expect(
        cubit.state.formError,
        QuestionAuthoringFormError.draftForAnotherReading,
      );
      // **AND NOTHING WAS ASKED** — a wrong write is worse than no write.
      verifyNever(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      );
      // **AND THE QUESTION IS STILL ON SCREEN**, because a refusal that
      // emptied the form would make the admin write it a second time.
      expect(cubit.state.draft, draft);

      await cubit.close();
    });

    test(
      'and a question the admin wrote is committed against any reading',
      () async {
        // **THE COUNTER, AND IT IS WHAT MAKES THE RULE A RULE AND NOT A BAN.**
        // The refusal is about a **draft** — a question the AI wrote about one
        // reading's passage. A question the **admin** wrote is the admin's, and
        // the admin may commit it against whatever reading they meant.
        final QuestionAuthoringCubit cubit = cubitWith();
        cubit.setPromptAr('سؤال');
        cubit.setPromptEn('A question');
        cubit.setCorrectAnswer('A');
        await cubit.commit();

        expect(cubit.state.formError, isNull);
        expect(capturedQuestions().single.single.promptEn, 'A question');

        await cubit.close();
      },
    );
  });

  group('the retry', () {
    test('after a failed commit, it commits the same question again', () async {
      when(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      ).thenAnswer((_) async => const Left<Failure, CommitResult>(failure));
      final QuestionAuthoringCubit cubit = cubitWith();
      cubit.setPromptAr('سؤال');
      cubit.setPromptEn('A question');
      cubit.setCorrectAnswer('A');
      await cubit.commit();
      expect(cubit.state.status, QuestionAuthoringStatus.commitFailed);

      when(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      ).thenAnswer((_) async => Result<CommitResult>.of(commitResult));
      await cubit.retry();

      // **The commit, and not the draft** — the failure named the request that
      // failed, and a retry that repeated the wrong one would answer a
      // question the admin did not ask again.
      expect(cubit.state.status, QuestionAuthoringStatus.ready);
      expect(cubit.state.commitResult, commitResult);
      verify(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      ).called(2);
      verifyNever(
        () => repository.generateAiDraft(
          readingId: any(named: 'readingId'),
          type: any(named: 'type'),
        ),
      );

      await cubit.close();
    });

    test('after a failed draft, it asks for a draft again', () async {
      when(
        () => repository.generateAiDraft(
          readingId: any(named: 'readingId'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => const Left<Failure, QuestionDraft>(failure));
      final QuestionAuthoringCubit cubit = cubitWith();
      await cubit.requestDraft();
      expect(cubit.state.status, QuestionAuthoringStatus.draftFailed);

      when(
        () => repository.generateAiDraft(
          readingId: any(named: 'readingId'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => Result<QuestionDraft>.of(draft));
      await cubit.retry();

      expect(cubit.state.status, QuestionAuthoringStatus.ready);
      expect(cubit.state.draft, draft);
      verify(
        () => repository.generateAiDraft(
          readingId: any(named: 'readingId'),
          type: any(named: 'type'),
        ),
      ).called(2);
      verifyNever(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      );

      await cubit.close();
    });
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

    test('the question\'s type is the one the admin chose', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      // **The type is a question, and a question has one.** The control that
      // offers it is the editor's, and the type it carries is the one the
      // commit body will send (`admin.routes.ts:38`).
      cubit.setType(QuestionType.trueFalse);

      expect(cubit.state.draft!.type, QuestionType.trueFalse);
      expect(cubit.state.status, QuestionAuthoringStatus.ready);

      // **And the rest of the question is untouched**, because the type is one
      // field and not a new question.
      cubit.setPromptEn('A question');
      cubit.setType(QuestionType.shortAnswer);
      expect(cubit.state.draft!.type, QuestionType.shortAnswer);
      expect(cubit.state.draft!.promptEn, 'A question');

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

    test('an edit keeps the server\'s failure, because the reader did not cause it', () async {
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

      // **The server's answer is still on screen.** The reader corrected a
      // field; the server has not said anything new, and a refusal that
      // vanished because the reader typed would be a refusal the reader
      // never got to read.
      expect(cubit.state.failure, failure);
      // **And the arm that names the request stays.** The status is what
      // `retry` reads to know **which** request to repeat, so a failure
      // that kept its message but lost its arm would be retried as the
      // wrong request.
      expect(cubit.state.status, QuestionAuthoringStatus.draftFailed);

      await cubit.close();
    });

    test('and a failed commit keeps its own arm through an edit', () async {
      when(
        () => repository.commitQuestions(
          readingId: any(named: 'readingId'),
          questions: any(named: 'questions'),
        ),
      ).thenAnswer((_) async => const Left<Failure, CommitResult>(failure));
      final QuestionAuthoringCubit cubit = cubitWith();
      cubit.setPromptAr('سؤال');
      cubit.setPromptEn('A question');
      cubit.setCorrectAnswer('A');
      await cubit.commit();
      expect(cubit.state.status, QuestionAuthoringStatus.commitFailed);

      cubit.setPromptEn('Another question');

      // **The commit's own arm**, and not the draft's: the two failures are
      // two states, and an edit that moved the state from one to the other
      // would make the retry answer a question the admin did not ask again.
      expect(cubit.state.status, QuestionAuthoringStatus.commitFailed);
      expect(cubit.state.failure, failure);

      await cubit.close();
    });

    test(
      'and the retry after an edit still repeats the failed request',
      () async {
        when(
          () => repository.commitQuestions(
            readingId: any(named: 'readingId'),
            questions: any(named: 'questions'),
          ),
        ).thenAnswer((_) async => const Left<Failure, CommitResult>(failure));
        final QuestionAuthoringCubit cubit = cubitWith();
        cubit.setPromptAr('سؤال');
        cubit.setPromptEn('A question');
        cubit.setCorrectAnswer('A');
        await cubit.commit();
        expect(cubit.state.status, QuestionAuthoringStatus.commitFailed);

        // **An edit, and then the retry.** The edit must not have moved the
        // request the retry repeats.
        cubit.setPromptEn('Another question');
        await cubit.retry();

        verify(
          () => repository.commitQuestions(
            readingId: any(named: 'readingId'),
            questions: any(named: 'questions'),
          ),
        ).called(2);
        verifyNever(
          () => repository.generateAiDraft(
            readingId: any(named: 'readingId'),
            type: any(named: 'type'),
          ),
        );

        await cubit.close();
      },
    );

    test('and an edit clears the form\'s own refusal', () async {
      final QuestionAuthoringCubit cubit = cubitWith();
      cubit.setPromptAr('سؤال');
      // The English prompt was never written, so the form refuses.
      await cubit.commit();
      expect(cubit.state.formError, QuestionAuthoringFormError.emptyPrompt);

      cubit.setPromptEn('A question');

      // **The form's own refusal goes**, because the reader is correcting
      // it — and it is a *different* refusal from the server's, and the two
      // are told apart.
      expect(cubit.state.formError, isNull);

      await cubit.close();
    });

    // ## THE **COMMIT RESULT** AND THE **EDIT**
    //
    // **A WRITE'S ANSWER REPORTS A WRITE THAT HAPPENED, AND IT STAYS.** The
    // commit is a **write**: the questions are in the database whether or not
    // the form is edited afterwards, so a keystroke that came after the
    // commit does not undo it.
    test('an edit keeps the commit result, because it reports a write that happened', () async {
      final QuestionAuthoringCubit cubit = cubitWith();
      cubit.setPromptAr('سؤال');
      cubit.setPromptEn('A question');
      cubit.setCorrectAnswer('A');
      await cubit.commit();
      expect(cubit.state.commitResult, commitResult);

      cubit.setPromptEn('Another question');

      // **THE SERVER'S ANSWER IS STILL ON SCREEN.** The questions are in the
      // database, and the admin corrected a field — the server has not said
      // anything new, and a confirmation that vanished because the reader
      // typed would be a confirmation the reader never got to read.
      expect(
        cubit.state.commitResult,
        commitResult,
        reason:
            'the commit is a write, and a write that happened is not undone by '
            'a keystroke that came after it',
      );
      // **AND THE ARM THAT NAMES IT STAYS** — the status is what the screen
      // reads to know which request answered.
      expect(cubit.state.status, QuestionAuthoringStatus.ready);

      await cubit.close();
    });
  });

  // ## THE CUBIT TAKES **EVERY** KEYSTROKE
  //
  // `lib/core/design_system/widgets/eva_controlled_field.dart` says it: **the
  // cubit must take every keystroke**, or the screen and the state disagree
  // and the field cannot tell which of them is right.
  //
  // **AND A REFUSAL IS NOT A TEMPORARY MISMATCH BUT A PERMANENT ONE.** The
  // field's third guard — *the controlled value must have moved* — means a
  // value the state kept is never written back, so the character the reader
  // typed stays on the screen for ever while the state does not have it.
  //
  // **SO THE RULE IS ABOUT EVERY WRITER, AND NOT ABOUT THE ONES THE PAGE
  // HAPPENS TO REACH.** A writer that can refuse is a writer the mechanism's
  // safety does not hold for, whether or not the page can reach it today —
  // and the option writer **could** refuse: it returned early when the
  // question had no option under the letter.
  group('the cubit takes every keystroke', () {
    test('a keystroke for a letter with no option is taken, and the option is '
        'created', () async {
      final QuestionAuthoringCubit cubit = cubitWith();
      // The question exists, and it has no options at all.
      cubit.setPromptEn('A question');

      // **A LETTER THAT HAS NO OPTION.** The reader typed under the letter
      // "A", so the question gets an option "A" — and the state holds what
      // the reader wrote.
      cubit.setOptionText('A', arabic: true, text: 'الخير');

      expect(
        cubit.state.draft!.options.keys,
        <String>['A'],
        reason:
            'the keystroke was refused, so the field would be showing a '
            'character the state does not have — and the field\'s own guard '
            'means the character is never written back, so the two would '
            'disagree permanently',
      );
      expect(cubit.state.draft!.options['A']!.ar, 'الخير');
      expect(
        cubit.state.draft!.options['A']!.en,
        '',
        reason:
            'the other half of the pair is the reader\'s to write, not ours',
      );

      await cubit.close();
    });

    test('and a keystroke when there is no question at all is taken', () async {
      final QuestionAuthoringCubit cubit = cubitWith();

      // **NO QUESTION AT ALL.** The state\'s own rule is that "the first thing
      // the admin writes creates the draft", and every other writer in this
      // cubit has always done it that way.
      expect(cubit.state.draft, isNull);

      cubit.setOptionText('A', arabic: false, text: 'The good');

      expect(cubit.state.draft, isNotNull);
      expect(cubit.state.draft!.options['A']!.en, 'The good');

      await cubit.close();
    });

    test('and every writer takes the text it is given', () async {
      // **THE TABLE IS THE CLAIM, AND EVERY ROW IS A NAMED WRITER.** A claim
      // about "the writers" is a claim about a set of specific things, so the
      // set is written down here — and a writer added to the cubit without a
      // row here is a writer this test does not speak for, which is a gap a
      // reader can see rather than one they have to trust.
      final List<
        ({
          String name,
          void Function(QuestionAuthoringCubit cubit) write,
          String? Function(QuestionAuthoringState state) read,
          String expected,
        })
      >
      writers =
          <
            ({
              String name,
              void Function(QuestionAuthoringCubit cubit) write,
              String? Function(QuestionAuthoringState state) read,
              String expected,
            })
          >[
            (
              name: 'setReadingId',
              write: (QuestionAuthoringCubit c) => c.setReadingId('a-reading'),
              read: (QuestionAuthoringState s) => s.readingId,
              expected: 'a-reading',
            ),
            (
              name: 'setPromptAr',
              write: (QuestionAuthoringCubit c) => c.setPromptAr('سؤال'),
              read: (QuestionAuthoringState s) => s.draft?.promptAr,
              expected: 'سؤال',
            ),
            (
              name: 'setPromptEn',
              write: (QuestionAuthoringCubit c) => c.setPromptEn('A question'),
              read: (QuestionAuthoringState s) => s.draft?.promptEn,
              expected: 'A question',
            ),
            (
              name: 'setCorrectAnswer',
              write: (QuestionAuthoringCubit c) => c.setCorrectAnswer('A'),
              read: (QuestionAuthoringState s) => s.draft?.correctAnswer,
              expected: 'A',
            ),
            (
              name: 'setPointsText',
              write: (QuestionAuthoringCubit c) => c.setPointsText('20'),
              read: (QuestionAuthoringState s) => s.pointsText,
              expected: '20',
            ),
            (
              name: 'setSortOrderText',
              write: (QuestionAuthoringCubit c) => c.setSortOrderText('3'),
              read: (QuestionAuthoringState s) => s.sortOrderText,
              expected: '3',
            ),
            (
              name: 'setType',
              // **A CONTROL AND NOT A FIELD**, and it is in the table because the
              // rule is the same one: the reader's input is taken, not refused.
              write: (QuestionAuthoringCubit c) =>
                  c.setType(QuestionType.trueFalse),
              read: (QuestionAuthoringState s) => s.draft?.type.name,
              expected: 'trueFalse',
            ),
            (
              name: 'setOptionText',
              // **THE ONE THAT USED TO REFUSE.** A letter with no option is the
              // case the refusal rejected, and the option is created here.
              write: (QuestionAuthoringCubit c) =>
                  c.setOptionText('A', arabic: true, text: 'الخير'),
              read: (QuestionAuthoringState s) => s.draft?.options['A']?.ar,
              expected: 'الخير',
            ),
          ];

      for (final ({
            String name,
            void Function(QuestionAuthoringCubit cubit) write,
            String? Function(QuestionAuthoringState state) read,
            String expected,
          })
          writer
          in writers) {
        // **A FRESH CUBIT FOR EVERY WRITER**, so one writer's draft cannot be
        // the next writer's reason for anything.
        final QuestionAuthoringCubit cubit = cubitWith();

        writer.write(cubit);

        expect(
          writer.read(cubit.state),
          writer.expected,
          reason:
              '${writer.name} did not take the reader\'s input. A writer that '
              'refuses leaves the field showing a character the state does not '
              'have, and the field\'s own guard means the character is never '
              'written back — so the two disagree permanently.',
        );

        await cubit.close();
      }
    });
  });
}
