import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:evangelion/features/quiz/domain/answer_haptic.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/contract_payloads.dart';

/// [answerHapticFor] — red-first (AGENT_CONTEXT §6: domain logic is TDD'd, not
/// buried in a widget).
///
/// ## THE PROTOTYPE'S TWO HAPTICS, AND WHY THEY ARE TWO
///
/// `eva/redesign.html:1428` — a correct answer: `haptic(30)`, a firm bump.
/// `eva/redesign.html:1429` — a wrong one: `haptic([40,60,40])`, a buzz.
///
/// **The rhythm is lost and the strength survives**, and that loss is
/// `core/domain/entities/ritual_haptic.dart`'s recorded one: `HapticFeedback` has
/// no pattern API, so a pattern becomes its strongest element. This suite
/// asserts the **observable consequence** — which platform impulse each verdict
/// becomes — and not the enum's identity, because the millisecond counts belong
/// to the vocabulary and the vocabulary has its own suite.
void main() {
  /// The question every fixture grades.
  const Question question = Question(
    id: 'question-group-3',
    sortOrder: 1,
    type: 'mcq',
    prompt: 'Who was born in Bethlehem?',
    options: <String, String>{'A': 'David', 'B': 'Mary'},
    pointsValue: 10,
    alreadyAnswered: false,
  );

  group('a graded answer', () {
    test('a correct one becomes the prototype\'s firm bump', () {
      const QuizAnswer answer = QuizAnswer(
        question: question,
        selectedLetter: 'A',
        verdict: contractSubmitAnswerFixture,
      );

      expect(answerHapticFor(answer), RitualHaptic.answerCorrect);
      // `:1428` — `haptic(30)`, and 30 ms is a medium impact under the
      // magnitude rule `ritual_haptic.dart` records.
      expect(hapticImpactFor(answerHapticFor(answer)!), HapticImpact.medium);
    });

    test('and a wrong one becomes the prototype\'s buzz', () {
      const QuizAnswer answer = QuizAnswer(
        question: question,
        selectedLetter: 'A',
        verdict: contractWrongAnswerFixture,
      );

      expect(answerHapticFor(answer), RitualHaptic.answerWrong);
      // `:1429` — `haptic([40,60,40])`, whose peak of 60 ms is a heavy impact.
      expect(hapticImpactFor(answerHapticFor(answer)!), HapticImpact.heavy);
    });
  });

  group('an answer that is not graded', () {
    test('asks for nothing at all', () {
      // **The chosen-but-unchecked answer.** The reader has picked a letter and
      // has not pressed "Check answer", so there is no verdict and no haptic —
      // the prototype grades on the tap (`:1423`'s one-shot `pick`), and this
      // client grades on the second press, so the first press must be silent.
      const QuizAnswer answer = QuizAnswer(
        question: question,
        selectedLetter: 'A',
      );

      expect(answerHapticFor(answer), isNull);
    });

    test('and neither does a question that was answered elsewhere', () {
      // §5 trap 3: the wire says this question is already answered, so the
      // client never grades it and never asks for a verdict. A haptic here
      // would fire on a load, which is not a check.
      const Question answered = Question(
        id: 'question-group-3',
        sortOrder: 1,
        type: 'mcq',
        prompt: 'Who was born in Bethlehem?',
        options: <String, String>{'A': 'David', 'B': 'Mary'},
        pointsValue: 10,
        alreadyAnswered: true,
        userAnswer: 'A',
        isCorrect: true,
      );
      const QuizAnswer answer = QuizAnswer(question: answered);

      expect(answerHapticFor(answer), isNull);
    });

    test('and neither does an answer that is not there', () {
      expect(answerHapticFor(null), isNull);
    });
  });
}
