import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:flutter_test/flutter_test.dart';

const Question anOpenQuestion = Question(
  id: 'question-group-3',
  sortOrder: 1,
  type: 'mcq',
  prompt: 'What was the name of the man who came to Jesus by night?',
  options: <String, String>{
    'A': 'Nicodemus',
    'B': 'Paul',
    'C': 'Peter',
    'D': 'Lazarus',
  },
  pointsValue: 10,
  alreadyAnswered: false,
);

const Question aSecondQuestion = Question(
  id: 'question-group-4',
  sortOrder: 2,
  type: 'mcq',
  prompt: 'Where did Nicodemus find Jesus?',
  options: <String, String>{'A': 'In Galilee', 'B': 'In Jerusalem'},
  pointsValue: 10,
  alreadyAnswered: false,
);

/// A [Question] carrying the flags the live reading ships for an already-answered
/// question. `test/support/reading_harness.dart`'s `liveEnglishPassageQuestions` is
/// the captured body; this is the same shape hand-built so a test can put it beside
/// an open question.
const Question anAnsweredQuestion = Question(
  id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  sortOrder: 3,
  type: 'mcq',
  prompt: 'What was the name of the Pharisee who came to Jesus by night?',
  options: <String, String>{'A': 'Nicodemus', 'B': 'Paul'},
  pointsValue: 10,
  alreadyAnswered: true,
  userAnswer: 'A',
  isCorrect: true,
);

/// A verdict for [anOpenQuestion], for the rebase group.
///
/// File-level because the two refresh tests below share it and it is the pair of them
/// that makes the point: the same value, one assertion about the entity and one about
/// the predicate the bloc reads.
const SubmitResult aVerdict = SubmitResult(
  questionId: 'question-group-3',
  isCorrect: true,
  pointsEarned: 10,
  currentTotalPoints: 40,
  currentStreak: 4,
  longestStreak: 6,
  readingCompleted: false,
);

void main() {
  group('`QuizAnswer`', () {
    test('starts open: nothing chosen, nothing checked, no verdict', () {
      const QuizAnswer answer = QuizAnswer(question: anOpenQuestion);
      expect(answer.selectedLetter, isNull);
      expect(answer.isChecked, isFalse);
      expect(answer.verdict, isNull);
      // And **not** a second definition of "wrong": an open question has no
      // verdict at all, which is a different fact from a wrong one. `isCorrect`
      // is therefore nullable and null here, not `false`.
      expect(answer.isCorrect, isNull);
    });

    test('a verdict is what makes it checked — not a second bool', () {
      // The whole reason there is no `checked` field. Two flags that mean the same
      // thing are two fields a writer can disagree about, and this is the phase
      // where the disagreement would be visible: an answer marked checked with no
      // verdict renders a "correct" state with nothing behind it.
      const SubmitResult verdict = SubmitResult(
        questionId: 'question-group-3',
        isCorrect: true,
        pointsEarned: 10,
        currentTotalPoints: 40,
        currentStreak: 4,
        longestStreak: 6,
        readingCompleted: false,
      );
      final QuizAnswer answer = const QuizAnswer(question: anOpenQuestion)
          .withVerdict(verdict);
      expect(answer.isChecked, isTrue);
      expect(answer.verdict, verdict);
      expect(answer.isCorrect, isTrue);
    });

    test('`isCorrect` reads a WRONG verdict as `false`, not as absent', () {
      // The distinction the nullable field exists for, and the one a
      // `verdict?.isCorrect == true` test would collapse. `false` is a graded
      // answer; `null` is an ungraded one, and the quiz draws them differently.
      const SubmitResult wrong = SubmitResult(
        questionId: 'question-group-3',
        isCorrect: false,
        pointsEarned: 0,
        currentTotalPoints: 30,
        currentStreak: 4,
        longestStreak: 6,
        readingCompleted: false,
      );
      final QuizAnswer answer = const QuizAnswer(question: anOpenQuestion)
          .withVerdict(wrong);
      expect(answer.isCorrect, isFalse);
      expect(answer.isChecked, isTrue);
    });

    test('choosing an option does not check it', () {
      final QuizAnswer answer = const QuizAnswer(question: anOpenQuestion)
          .withSelection('B');
      expect(answer.selectedLetter, 'B');
      expect(
        answer.isChecked,
        isFalse,
        reason: 'select and check are two steps',
      );
      expect(answer.verdict, isNull);
    });

    test(
      '`isAnswerable` is false once checked, and false for an already-answered '
      'question',
      () {
        const SubmitResult verdict = SubmitResult(
          questionId: 'question-group-3',
          isCorrect: true,
          pointsEarned: 10,
          currentTotalPoints: 40,
          currentStreak: 4,
          longestStreak: 6,
          readingCompleted: true,
        );
        final QuizAnswer open = const QuizAnswer(question: anOpenQuestion)
            .withSelection('A');
        expect(open.isAnswerable, isTrue);

        final QuizAnswer checked = open.withVerdict(verdict);
        expect(checked.isAnswerable, isFalse);

        // §5 trap 3's whole point: a question the reader has already answered comes
        // back as **409** if submitted, so it must be closed before the reader can
        // try — not closed after the server refuses.
        final QuizAnswer already = const QuizAnswer(
          question: anAnsweredQuestion,
        ).withSelection('B');
        expect(already.isAnswerable, isFalse);
        expect(
          already.selectedLetter,
          'B',
          reason: 'the selection still happened',
        );
      },
    );

    test('an already-answered question keeps its wire flags and gains nothing', () {
      const QuizAnswer answer = QuizAnswer(question: anAnsweredQuestion);
      expect(answer.question.alreadyAnswered, isTrue);
      expect(answer.question.userAnswer, 'A');
      expect(answer.question.isCorrect, isTrue);
      // …and **carrying** `is_correct` is not **revealing** it. The verdict is
      // null because no submission happened in this session, so `QuizOptionCard`
      // has nothing to mark correct with. `quiz_page_test.dart` asserts the
      // spoiler boundary with this exact entity on screen.
      expect(answer.verdict, isNull);
      expect(answer.isCorrect, isNull);
    });

    test(
      '`props` distinguishes the question, the selection and the verdict',
      () {
        const QuizAnswer open = QuizAnswer(question: anOpenQuestion);
        expect(
          open,
          isNot(equals(const QuizAnswer(question: aSecondQuestion))),
        );
        expect(open, isNot(equals(open.withSelection('A'))));
        expect(open.withSelection('A'), isNot(equals(open.withSelection('B'))));
        expect(
          open.withSelection('A'),
          isNot(
            equals(
              open.withVerdict(
                const SubmitResult(
                  questionId: 'question-group-3',
                  isCorrect: true,
                  pointsEarned: 10,
                  currentTotalPoints: 40,
                  currentStreak: 4,
                  longestStreak: 6,
                  readingCompleted: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  });

  group('`QuizSession`', () {
    const QuizSession aSession = QuizSession(
      readingId: 'reading-group-3-2026-10-04',
      answers: <QuizAnswer>[
        QuizAnswer(question: anOpenQuestion),
        QuizAnswer(question: anAnsweredQuestion),
      ],
    );

    test('answers and counts them', () {
      expect(aSession.questionCount, 2);
      // One question is `already_answered` on the wire, and it counts as answered.
      // That is the whole of decision 50's `answeredQuestionCount` rule applied
      // here: the flag is the server's, and the client's job is to read it.
      expect(aSession.answeredCount, 1);
    });

    test(
      'an empty session has no answers and reports zero for both counts',
      () {
        const QuizSession empty = QuizSession(
          readingId: 'reading-group-3-2026-10-04',
          answers: <QuizAnswer>[],
        );
        expect(empty.questionCount, 0);
        expect(empty.answeredCount, 0);
        expect(empty.isEmpty, isTrue);
        expect(aSession.isEmpty, isFalse);
      },
    );

    test('the answer at an index, or `null` past the end', () {
      expect(aSession.answerAt(0)?.question, anOpenQuestion);
      expect(aSession.answerAt(1)?.question, anAnsweredQuestion);
      // **Not a throw.** `QuizState.currentIndex` is a plain `int` and a future
      // event could carry one past the end; decision 40's lesson is that a `build`
      // which throws on an out-of-range read takes the screen with it.
      expect(aSession.answerAt(2), isNull);
      expect(aSession.answerAt(-1), isNull);
    });

    test('`withAnswerAt` replaces one answer and leaves the rest verbatim', () {
      // The writer the bloc uses when a submit lands. It rebuilds the whole list
      // because a `List` is immutable here, and it rebuilds it from the existing
      // answers rather than from a mutable buffer so the untouched entries are
      // provably the same objects.
      final QuizAnswer graded = aSession.answers.first.withVerdict(
        const SubmitResult(
          questionId: 'question-group-3',
          isCorrect: true,
          pointsEarned: 10,
          currentTotalPoints: 40,
          currentStreak: 4,
          longestStreak: 6,
          readingCompleted: true,
        ),
      );
      final QuizSession next = aSession.withAnswerAt(0, graded);
      expect(next.answers.first, graded);
      expect(identical(next.answers[1], aSession.answers[1]), isTrue);
      expect(next.readingId, aSession.readingId);
      expect(next.answeredCount, 2);
      expect(aSession.answeredCount, 1, reason: 'the original is untouched');
    });

    test('`withAnswerAt` out of range returns the session unchanged', () {
      final QuizSession next = aSession.withAnswerAt(7, aSession.answers.first);
      expect(next, aSession);
    });

    test('`withQuestions` replaces every answer, and **rebases** them', () {
      // The re-fetch arm, and the reason it is not `copyWith`. `RefreshSessionQuestions`
      // exists because the backend has **no `GET /readings/:id`**: the client can
      // only re-fetch *today's whole reading*, and that payload arrives with its
      // own `already_answered` flags. Rebasing onto the fresh entities is what makes
      // those flags authoritative — a reader's *selection* is kept (it is theirs and
      // it is not on the wire) while a *verdict* is dropped (it belongs to the
      // response that produced it, and the response being replaced names the
      // question this session no longer holds).
      final QuizSession rebased = aSession.withQuestions(
        readingId: 'reading-group-3-2026-10-05',
        questions: <Question>[anOpenQuestion, aSecondQuestion],
      );
      expect(rebased.readingId, 'reading-group-3-2026-10-05');
      expect(rebased.questionCount, 2);
      // The second question was `already_answered` and is now not: the **fresh**
      // flag won, which is the entire purpose of the re-fetch.
      expect(rebased.answers.last.question.alreadyAnswered, isFalse);
      expect(rebased.answers.last.verdict, isNull);
    });

    test('`withQuestions` keeps a selection the reader made on an identical '
        'question', () {
      // The other half of "rebase", and the reason it is not a plain
      // `QuizAnswer(question: fresh)`. A reader mid-question who taps retry must
      // not lose their choice; the answer text is on both payloads.
      final QuizSession withSelection = aSession.withAnswerAt(
        0,
        aSession.answers.first.withSelection('C'),
      );
      final QuizSession rebased = withSelection.withQuestions(
        readingId: withSelection.readingId,
        questions: <Question>[anOpenQuestion, anAnsweredQuestion],
      );
      expect(rebased.answers.first.selectedLetter, 'C');
      expect(rebased.answers.first.isChecked, isFalse);
    });

    // ## AND THE VERDICT IS CARRIED TOO — THE CODE WAS RIGHT AND ITS OWN TABLE
    // ## WAS WRONG
    //
    // `withQuestions`'s doc table said a carried-over answer keeps "a
    // `selectedLetter` … | nothing else", and then carried the verdict anyway. Making
    // the code match the table is green across every quiz and reading test, which is
    // what makes it a decision rather than a fix: the table is the thing that is
    // wrong.
    test('and a GRADED answer keeps its verdict across the re-fetch', () {
      final QuizSession graded = aSession.withAnswerAt(
        0,
        aSession.answers.first.withSelection('C').withVerdict(aVerdict),
      );

      // **The fresh payload still says `already_answered: false`.** That is the
      // whole shape of the hazard: the wire's flag is only as fresh as the last
      // fetch, §5 trap 3 makes the consequence a 409, and a re-fetch that returns
      // the pre-submit payload is not a defect the client can detect.
      final QuizSession rebased = graded.withQuestions(
        readingId: graded.readingId,
        questions: <Question>[anOpenQuestion, aSecondQuestion],
      );

      expect(rebased.answers.first.verdict, aVerdict);
      expect(rebased.answers.first.isChecked, isTrue);
      // The letters travel together, so this is also the assertion that the answer is
      // not re-submittable — which is `QuizState.cta`'s `check` arm and the 409.
      expect(rebased.answers.first.selectedLetter, 'C');
    });

    test('so a refresh cannot make an answered question ANSWERABLE AGAIN', () async {
      // ## THE 409, STATED AS AN INVARIANT RATHER THAN AS A STORY
      //
      // `isAnswerable` is the prevention §5 trap 3 asks for, and it is false for
      // two reasons: the wire says answered, or `isChecked`. Drop the verdict on a
      // refresh and only the second one is left — so a question the server has
      // already graded comes back with its letter still on it, `isAnswerable` is
      // true, the CTA says "Check answer", and the reader's next press is a
      // **second submit for a question the server graded**. `isAnswerable`,
      // `QuizState.cta` and the whole `already_answered` design exist to prevent
      // exactly that, and a rebase was undoing it.
      //
      // Asserted on the predicate rather than on `isChecked` because the predicate
      // is what the bloc's handler and the option card both read.
      final QuizSession graded = aSession.withAnswerAt(
        0,
        aSession.answers.first.withSelection('C').withVerdict(aVerdict),
      );
      final QuizSession rebased = graded.withQuestions(
        readingId: graded.readingId,
        questions: <Question>[anOpenQuestion, aSecondQuestion],
      );

      expect(graded.answers.first.isAnswerable, isFalse);
      expect(rebased.answers.first.isAnswerable, isFalse);
      expect(rebased.answers.first.isOpen, isFalse);
    });

    test('`props` distinguishes the reading id and the answers', () {
      expect(
        aSession,
        isNot(
          equals(
            aSession.withQuestions(
              readingId: 'other',
              questions: <Question>[anOpenQuestion, anAnsweredQuestion],
            ),
          ),
        ),
      );
      expect(
        aSession,
        isNot(
          equals(
            aSession.withQuestions(
              readingId: aSession.readingId,
              questions: <Question>[anOpenQuestion],
            ),
          ),
        ),
      );
    });
  });
}
