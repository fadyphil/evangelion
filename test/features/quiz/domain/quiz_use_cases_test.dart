import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/quiz/domain/refreshed_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/refresh_session_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [ReadingRepository] answering a fixed reading and recording what it was asked.
///
/// Hand-written for `reading_harness.dart`'s reason — a `mocktail` mock can satisfy
/// the port and answer nothing — and it records the **language** because the quiz's
/// whole arm depends on the payload arriving in the reader's language and a suite
/// that only counted calls could not tell the two apart.
/// Wraps a payload as the success a port would hand back, so a suite can write
/// `_CountingRepository(ok(twoQuestions))` rather than spelling the generic.
Result<ScriptureText> ok(ScriptureText text) =>
    Result<ScriptureText>.success(text);

final class _CountingRepository implements ReadingRepository {
  _CountingRepository(this.reading);

  Result<ScriptureText> reading;
  Result<SubmitResult> submission = const Result<SubmitResult>.success(
    SubmitResult(
      questionId: 'question-group-3',
      isCorrect: true,
      pointsEarned: 10,
      currentTotalPoints: 40,
      currentStreak: 4,
      longestStreak: 6,
      readingCompleted: true,
    ),
  );

  int calls = 0;
  final List<ReadingLanguage> asked = <ReadingLanguage>[];
  final List<({String readingId, String questionId, String answer})> sent =
      <({String readingId, String questionId, String answer})>[];

  @override
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  }) async {
    calls++;
    asked.add(language);
    return reading;
  }

  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async =>
      (await todayScripture(language: language))
          .map((ScriptureText text) => text.toTodayReading());

  @override
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  }) async {
    sent.add((readingId: readingId, questionId: questionId, answer: answer));
    return submission;
  }
}

const Verse oneVerse = Verse(
  bookNumber: 43,
  chapter: 3,
  number: 1,
  text: 'There was a man of the Pharisees, named Nicodemus,',
);

const Question anOpen = Question(
  id: 'question-group-3',
  sortOrder: 1,
  type: 'mcq',
  prompt: 'What was the name of the man who came to Jesus by night?',
  options: <String, String>{'A': 'Nicodemus', 'B': 'Paul'},
  pointsValue: 10,
  alreadyAnswered: false,
);

const Question anAnswered = Question(
  id: 'question-group-4',
  sortOrder: 2,
  type: 'mcq',
  prompt: 'Where did Nicodemus find Jesus?',
  options: <String, String>{'A': 'In Galilee', 'B': 'In Jerusalem'},
  pointsValue: 10,
  alreadyAnswered: true,
  userAnswer: 'A',
  isCorrect: true,
);

const ScriptureText twoQuestions = ScriptureText(
  readingId: 'reading-group-3-2026-10-04',
  groupId: 3,
  scheduledDate: '2026-10-04',
  language: ReadingLanguage.english,
  reference: 'John 3:1-5',
  translation: 'NKJV (New King James Version)',
  verses: <Verse>[oneVerse],
  questions: <Question>[anOpen, anAnswered],
  isFullyCompleted: false,
  pointsEarnedToday: 0,
  currentStreak: 4,
);

void main() {
  group('`StartSession`', () {
    test('is a `UseCase` over a `ReadingLanguage`', () {
      // §3's DIP row, as a **type** assertion: `QuizBloc` depends on this interface
      // and nothing below it names a repository, a mapper or `Dio`.
      expect(
        const StartSession(_NeverReadingRepository()),
        isA<UseCase<ReadingLanguage, QuizSession>>(),
      );
    });

    test(
      'turns the wide payload into a session, keeping the reading id',
      () async {
        final _CountingRepository repository = _CountingRepository(
          ok(twoQuestions),
        );
        final StartSession useCase = StartSession(repository);

        final Result<QuizSession> result = await useCase(
          ReadingLanguage.english,
        );

        expect(result.isSuccess, isTrue);
        final QuizSession session = (result as Success<QuizSession>).value;
        expect(session.readingId, 'reading-group-3-2026-10-04');
        expect(session.questionCount, 2);
        expect(session.answeredCount, 1, reason: 'the wire flag counts');
        expect(session.answers.first.question, anOpen);
        expect(session.answers.first.isChecked, isFalse);
        expect(session.answers.last.question, anAnswered);
        expect(
          session.answers.last.verdict,
          isNull,
          reason:
              'the wire says it was answered; this session did not grade it',
        );
      },
    );

    test('asks the port for the language it was given, in that arm', () async {
      final _CountingRepository repository = _CountingRepository(
        ok(twoQuestions),
      );

      await StartSession(repository)(ReadingLanguage.arabic);

      expect(repository.asked, <ReadingLanguage>[ReadingLanguage.arabic]);
    });

    test('and a failed read is passed through byte-for-byte', () async {
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'Could not reach the server.',
      );
      final StartSession useCase = StartSession(
        _CountingRepository(const Result<ScriptureText>.failure(failure)),
      );

      final Result<QuizSession> result = await useCase(ReadingLanguage.english);

      expect(result.isFailure, isTrue);
      expect(
        (result as FailureResult<QuizSession>).failure,
        failure,
        reason:
            'a use case that reclassified an error would be a second place '
            'where the wire\'s meaning is decided (§3, DIP)',
      );
    });

    test(
      'a reading with NO questions yields an empty session, not a failure',
      () async {
        // §3's rule and `today_reading_mapper.dart`'s own: an unreadable question is
        // **skipped**, so `questionCount == 0` is reachable for a payload that was
        // otherwise perfect. `QuizPage` renders the empty state; `StartSession` must
        // not invent a failure for it.
        final StartSession useCase = StartSession(
          _CountingRepository(
            ok(
              const ScriptureText(
                readingId: 'reading-group-3-2026-10-04',
                groupId: 3,
                scheduledDate: '2026-10-04',
                language: ReadingLanguage.english,
                reference: 'John 3:1-5',
                translation: 'NKJV',
                verses: <Verse>[oneVerse],
                questions: <Question>[],
                isFullyCompleted: false,
                pointsEarnedToday: 0,
                currentStreak: 0,
              ),
            ),
          ),
        );

        final Result<QuizSession> result = await useCase(
          ReadingLanguage.english,
        );

        expect(result.isSuccess, isTrue);
        expect((result as Success<QuizSession>).value.isEmpty, isTrue);
      },
    );
  });

  group('`RefreshSessionQuestions`, and the reason it exists', () {
    test('is a `UseCase` returning **only** an id and the questions', () {
      expect(
        const RefreshSessionQuestions(_NeverReadingRepository()),
        isA<UseCase<ReadingLanguage, RefreshedQuestions>>(),
      );
    });

    test('RE-FETCHES: it does not read anything the caller already had', () async {
      // ## THE FALSIFYING SHAPE FOR THE WHOLE USE CASE
      //
      // The obvious implementation — "return the cached `already_answered` flags" —
      // would answer this test with `repository.calls == 0`, which is the trap the
      // backend's missing endpoint sets. So the assertion is on the **call count**
      // and the flag comes from the **second** payload, not the first.
      //
      // `already_answered` flips `false → true` between the two reads. A
      // cache-trusting implementation would report the first payload's value and
      // this test would be red; so would one that re-fetched but ignored the fresh
      // entity, which is why both halves are asserted.
      _CountingRepository repository = _CountingRepository(ok(twoQuestions));

      final RefreshSessionQuestions useCase = RefreshSessionQuestions(
        repository,
      );
      final Result<RefreshedQuestions> first = await useCase(
        ReadingLanguage.english,
      );
      expect(first.isSuccess, isTrue);
      expect(
        (first as Success<RefreshedQuestions>).value.questions.map(
          (Question q) => q.alreadyAnswered,
        ),
        <bool>[false, true],
        reason: 'the FIRST payload: the second question is flagged',
      );

      // The reader answers the open question elsewhere — a second device, or the
      // server itself — and the cached flag is now wrong.
      repository = _CountingRepository(
        ok(
          const ScriptureText(
            readingId: 'reading-group-3-2026-10-04',
            groupId: 3,
            scheduledDate: '2026-10-04',
            language: ReadingLanguage.english,
            reference: 'John 3:1-5',
            translation: 'NKJV (New King James Version)',
            verses: <Verse>[oneVerse],
            questions: <Question>[
              Question(
                id: 'question-group-3',
                sortOrder: 1,
                type: 'mcq',
                prompt:
                    'What was the name of the man who came to Jesus by night?',
                options: <String, String>{'A': 'Nicodemus', 'B': 'Paul'},
                pointsValue: 10,
                alreadyAnswered: true,
                userAnswer: 'A',
                isCorrect: true,
              ),
              anAnswered,
            ],
            isFullyCompleted: true,
            pointsEarnedToday: 10,
            currentStreak: 4,
          ),
        ),
      );
      final RefreshSessionQuestions second = RefreshSessionQuestions(
        repository,
      );
      final Result<RefreshedQuestions> refreshed = await second(
        ReadingLanguage.english,
      );

      expect(repository.calls, 1, reason: 'a request went out');
      final RefreshedQuestions value =
          (refreshed as Success<RefreshedQuestions>).value;
      expect(
        value.questions.first.alreadyAnswered,
        isTrue,
        reason:
            'the FRESH flag, which the cached one did not have. This is the whole '
            'of what the re-fetch buys.',
      );
    });

    test(
      'and it returns the reading id too, because that value **moves**',
      () async {
        // §5 trap 11: `reading_id` has already rolled over between two probes of the
        // same endpoint, from a UUID to a fabricated date-dependent string. A refresh
        // that returned only questions would leave the session submitting against a
        // stale reading — which is a 404 whose message names a *question*.
        final _CountingRepository repository = _CountingRepository(
          ok(
            const ScriptureText(
              readingId: 'reading-group-3-2026-10-05',
              groupId: 3,
              scheduledDate: '2026-10-05',
              language: ReadingLanguage.english,
              reference: 'John 3:1-5',
              translation: 'NKJV',
              verses: <Verse>[oneVerse],
              questions: <Question>[anOpen],
              isFullyCompleted: false,
              pointsEarnedToday: 0,
              currentStreak: 4,
            ),
          ),
        );

        final Result<RefreshedQuestions> result = await RefreshSessionQuestions(
          repository,
        )(ReadingLanguage.english);

        expect(
          (result as Success<RefreshedQuestions>).value.readingId,
          'reading-group-3-2026-10-05',
        );
      },
    );

    test('a failed re-read is passed through unchanged', () async {
      const Failure failure = Failure(
        kind: FailureKind.timeout,
        message: 'The request timed out.',
      );
      final Result<RefreshedQuestions> result = await RefreshSessionQuestions(
        _CountingRepository(const Result<ScriptureText>.failure(failure)),
      )(ReadingLanguage.english);

      expect(result.isFailure, isTrue);
      expect((result as FailureResult<RefreshedQuestions>).failure, failure);
    });

    test('`RefreshedQuestions` is two fields and nothing else', () {
      // The type exists because the re-fetch is **wider** than "the questions": the
      // backend has no `GET /readings/:id`, so refreshing one question means
      // re-reading the whole payload, and that payload's `reading_id` is part of
      // what has to survive. Naming the pair is what stops a caller re-reading the
      // payload a second time to get the other half — which is the redundancy this
      // type was created to remove.
      const RefreshedQuestions value = RefreshedQuestions(
        readingId: 'r',
        questions: <Question>[anOpen],
      );
      expect(value.readingId, 'r');
      expect(value.questions, hasLength(1));
      expect(value.questionCount, 1);
      expect(value, isNot(equals(value.copyWithReadingId('other'))));
    });
  });

  group('`SubmitAnswer`', () {
    test('is a `UseCase` over one params object, and not three arguments', () {
      // §4: "Named parameters for anything with more than two arguments" — and a
      // `UseCase`'s `call` takes exactly one, so a three-value operation needs a
      // value class. `SubmitAnswerParams` is it, and the assertion is that the call
      // site cannot accidentally swap the reading id for the letter: both are
      // `String` and only the field names tell them apart.
      expect(
        const SubmitAnswer(_NeverReadingRepository()),
        isA<UseCase<SubmitAnswerParams, SubmitResult>>(),
      );
    });

    test('passes all three values to the port, verbatim', () async {
      final _CountingRepository repository = _CountingRepository(
        ok(twoQuestions),
      );

      final Result<SubmitResult> result = await SubmitAnswer(repository)(
        const SubmitAnswerParams(
          readingId: 'reading-group-3-2026-10-04',
          questionId: 'question-group-3',
          answer: 'B',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(repository.sent.single, (
        readingId: 'reading-group-3-2026-10-04',
        questionId: 'question-group-3',
        answer: 'B',
      ));
    });

    test('`answer` is NOT validated against the letters A–D', () async {
      // `submissions.routes.ts:35` documents it as *"Selected option (A, B, C, D) or
      // boolean"*, and `:7` accepts `z.string().min(1)`. A client that checked the
      // letters would refuse a legal request, which is recorded decision 15's
      // argument about `X-User-Id` applied to a second field.
      final _CountingRepository repository = _CountingRepository(
        ok(twoQuestions),
      );

      for (final String answer in <String>[
        'A',
        'B',
        'C',
        'D',
        'true',
        'false',
      ]) {
        await SubmitAnswer(repository)(
          SubmitAnswerParams(readingId: 'r', questionId: 'q', answer: answer),
        );
      }

      expect(
        repository.sent.map(
          (({String answer, String questionId, String readingId}) t) =>
              t.answer,
        ),
        <String>['A', 'B', 'C', 'D', 'true', 'false'],
      );
    });

    test(
      'a 409-shaped failure is passed through as a typed `Result`',
      () async {
        // §5 trap 3, and the reason the bloc has a failure arm at all. The *typing* is
        // `ApiErrorMapper`'s job; what this asserts is that nothing between the port
        // and the use case turns it into an exception or rewords it.
        const Failure conflict = Failure(
          kind: FailureKind.conflict,
          message: 'This question has already been submitted by this user.',
          statusCode: 409,
        );
        final _CountingRepository repository = _CountingRepository(
          ok(twoQuestions),
        )..submission = const Result<SubmitResult>.failure(conflict);

        final Result<SubmitResult> result = await SubmitAnswer(repository)(
          const SubmitAnswerParams(
            readingId: 'r',
            questionId: 'q',
            answer: 'A',
          ),
        );

        expect(result.isFailure, isTrue);
        expect((result as FailureResult<SubmitResult>).failure, conflict);
      },
    );

    test('`SubmitAnswerParams` puts each value in one field and nothing else', () {
      // The hazard this class exists to prevent, asserted directly: with three
      // positional `String`s at the call site, `(readingId, questionId, answer)`
      // and `(questionId, readingId, answer)` are the same program and only the
      // names differ. A wrong-but-well-typed submission is invisible to every
      // assertion this repository makes.
      const SubmitAnswerParams params = SubmitAnswerParams(
        readingId: 'reading-id',
        questionId: 'question-id',
        answer: 'A',
      );
      expect(params.readingId, 'reading-id');
      expect(params.questionId, 'question-id');
      expect(params.answer, 'A');
      expect(
        params,
        isNot(
          equals(
            const SubmitAnswerParams(
              readingId: 'question-id',
              questionId: 'reading-id',
              answer: 'A',
            ),
          ),
        ),
      );
    });
  });
}

/// A `ReadingRepository` that throws if any of its methods is reached.
///
/// It exists so the three `isA<UseCase<…>>` assertions above are about the **type
/// seam** and not about a working fake: if a use case reached for the port in its
/// constructor, these would throw rather than quietly pass.
final class _NeverReadingRepository implements ReadingRepository {
  const _NeverReadingRepository();

  @override
  Future<Result<TodayReading>> today({required ReadingLanguage language}) =>
      throw UnimplementedError('today');

  @override
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  }) => throw UnimplementedError('todayScripture');

  @override
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  }) => throw UnimplementedError('submitAnswer');
}
