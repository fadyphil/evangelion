import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape `POST /api/v1/readings/:id/submit` answers with.
///
/// ## WHY THIS FIXTURE IS **TRANSCRIBED** AND NOT **CAPTURED**
///
/// Every other fixture in `test/support/` is a body the running backend actually
/// returned, and `live_payloads.dart` says so. **This one cannot be**, and the
/// reason is recorded in AGENT_CONTEXT §5: no successful submit is reachable
/// against `HEAD = 4a1c834`. The three responses the endpoint does give are a 400
/// (`question_id` must match `uuid`), a 404 (`QUESTION_NOT_FOUND`) and a 409
/// (already submitted) — none of which is a 200.
///
/// So the seven fields here are transcribed from `SubmitAnswerResult` in
/// `src/modules/submissions/submissions.service.ts:5-13`, the declaration the
/// backend itself compiles against, and the values are plausible rather than
/// observed. **A test that reads it is testing the client against the
/// declaration, which is the only contract available.** `contract_payloads.dart`
/// carries the same provenance note next to the JSON this file's values come from.
const SubmitResult aSubmitResult = SubmitResult(
  questionId: 'question-group-3',
  isCorrect: true,
  pointsEarned: 10,
  currentTotalPoints: 40,
  currentStreak: 4,
  longestStreak: 6,
  readingCompleted: true,
);

void main() {
  group('`SubmitResult`', () {
    test('carries all seven fields of the service interface', () {
      expect(aSubmitResult.questionId, 'question-group-3');
      expect(aSubmitResult.isCorrect, isTrue);
      expect(aSubmitResult.pointsEarned, 10);
      expect(aSubmitResult.currentTotalPoints, 40);
      expect(aSubmitResult.currentStreak, 4);
      expect(aSubmitResult.longestStreak, 6);
      expect(aSubmitResult.readingCompleted, isTrue);
    });

    test(
      'is `Equatable`, so a repeated identical response is not a state change',
      () {
        // The reason this matters is `QuizState.lastResult`: `ResultPage` is handed
        // it, and a bloc that emitted a fresh-but-equal result on every rebuild
        // would repaint `/result` for nothing. Recorded decision 77 makes the same
        // argument about a `Failure`, which is why `Failure.details` is excluded from
        // equality there and this entity simply has nothing to exclude.
        expect(aSubmitResult, aSubmitResult);
        expect(aSubmitResult.hashCode, aSubmitResult.hashCode);
        expect(aSubmitResult, equals(aSubmitResult));
      },
    );

    // One field per case, in the interface's own order, so the omission this
    // guards against — a field left out of `props` — is red per field rather than
    // "two of them differ and nobody knows which".
    for (final (String name, SubmitResult Function() build)
        in <(String, SubmitResult Function())>[
          (
            'questionId',
            () => SubmitResult(
              questionId: 'other',
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
          (
            'isCorrect',
            () => SubmitResult(
              questionId: aSubmitResult.questionId,
              isCorrect: false,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
          (
            'pointsEarned',
            () => SubmitResult(
              questionId: aSubmitResult.questionId,
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: 0,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
          (
            'currentTotalPoints',
            () => SubmitResult(
              questionId: aSubmitResult.questionId,
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: 0,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
          (
            'currentStreak',
            () => SubmitResult(
              questionId: aSubmitResult.questionId,
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: 0,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
          (
            'longestStreak',
            () => SubmitResult(
              questionId: aSubmitResult.questionId,
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: 0,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
          (
            'readingCompleted',
            () => SubmitResult(
              questionId: aSubmitResult.questionId,
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: false,
            ),
          ),
        ]) {
      test('`props` distinguishes a different $name', () {
        expect(aSubmitResult, isNot(equals(build())));
      });
    }

    test('a result is NOT equal to a different question with everything else the '
        'same', () {
      // The narrow one, and the one a `props` list built from only the numbers
      // would fail. Two submissions of two different questions can differ in
      // nothing else — same verdict, same points, same streaks, same completion —
      // and `/result` is handed the last one, so "which question is this about" has
      // to be part of the identity.
      expect(
        aSubmitResult,
        isNot(
          equals(
            SubmitResult(
              questionId: 'question-group-4',
              isCorrect: aSubmitResult.isCorrect,
              pointsEarned: aSubmitResult.pointsEarned,
              currentTotalPoints: aSubmitResult.currentTotalPoints,
              currentStreak: aSubmitResult.currentStreak,
              longestStreak: aSubmitResult.longestStreak,
              readingCompleted: aSubmitResult.readingCompleted,
            ),
          ),
        ),
      );
    });
  });
}
