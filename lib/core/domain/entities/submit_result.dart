import 'package:freezed_annotation/freezed_annotation.dart';

part 'submit_result.freezed.dart';

/// The response to `POST /api/v1/readings/:id/submit` — one answer, graded.
///
/// ## WHY IT IS IN `core/domain/` AND NOT IN `features/quiz/`
///
/// §3's placement test: **two** consumers. `quiz`'s `QuizAnswer` holds the verdict
/// for the question the reader just checked, and `/result` is handed the last one
/// as its **only** input. One consumer would have put it in `features/quiz/domain/`;
/// `ResultPage` importing `features/quiz/` is Gate 2, so the entity has to be in
/// the kernel for the same mechanical reason `Question` is —
/// `core/domain/repositories/reading_repository.dart` names it in a signature.
///
/// ## EVERY FIELD IS REQUIRED, AND NOTHING HAS A DEFAULT
///
/// Same rule as `TodayReadingMapper`, for the same reason: a default is a claim
/// about a payload this client has not seen. There is a sharper reason here.
///
/// ## **NO SUCCESSFUL SUBMIT HAS EVER REACHED THIS CLIENT**, AND THAT IS THE
/// ## WHOLE OF ITS PROVENANCE
///
/// Verified live against `HEAD = 4a1c834`, group 3. The endpoint's three
/// reachable answers are a 400, a 404 and a 409 — see AGENT_CONTEXT §5 trap 10 for
/// the exact bodies. So this shape is transcribed from
/// `src/modules/submissions/submissions.service.ts:5-13`, which is the interface
/// the backend compiles against, rather than from a captured response. Every test
/// that reads these fields is testing the client against a **declaration**.
///
/// Two consequences, both load-bearing:
///
/// * **The request body is fixed by `submissions.routes.ts:6-8`** —
///   `question_id: z.string().uuid()` and `answer: z.string().min(1)` — and the
///   `answer` is documented at `submissions.routes.ts:35` as *"Selected option
///   (A, B, C, D) or boolean"*. Both are contract, not observation.
/// * **Nothing about a `200` is guessed.** The field names, their types and their
///   order are the interface's. The *values* in any fixture are plausible, not
///   observed, and `test/support/contract_payloads.dart` says so where the JSON
///   lives.
///
/// ## [currentStreak] IS THE **THIRD** COPY OF A FIELD THAT DISAGREES WITH ITSELF
///
/// AGENT_CONTEXT §5 trap 8 measures two of them: `readings/today/*.current_streak`
/// reads `4` where `streak/summary.current_streak` reads `0`, on the same reader
/// on the same day, and neither endpoint is wrong about its own job. Recorded
/// decision 22 resolves that pair by never reconciling them.
///
/// This is the third, and `/result` draws **this** one — because it is the
/// response to the action the screen is reporting. `reading_completed` is the
/// reason that is safe: §5 trap 4 says the streak fields only move when it is
/// `true`, so this number is the one written *by the submission the reader just
/// made*, while `/`'s two were written by a read. `result_page_test.dart` asserts
/// the number on screen is this field's and not either other endpoint's, in the
/// failing direction.
///
/// ## AND [readingCompleted] IS NOT DECORATIVE
///
/// §5 trap 4 again: a single correct answer does **not** advance the streak.
/// `ResultPage` shows a streak, so a screen that drew it without reading this flag
/// would be drawing a number the backend did not change. It is carried for exactly
/// that reason, and `result_page_test.dart` pins both arms.
@freezed
final class SubmitResult with _$SubmitResult {
  /// A graded answer, as the backend's own interface declares it.
  const SubmitResult({
    required this.questionId,
    required this.isCorrect,
    required this.pointsEarned,
    required this.currentTotalPoints,
    required this.currentStreak,
    required this.longestStreak,
    required this.readingCompleted,
  });

  /// `question_id` — the question this verdict is about.
  ///
  /// **Echoed by the server, so it is a correlation key and not an input.** The
  /// request sent `question_id`; the response carries the one the service graded.
  /// Two submissions of two different questions can differ in nothing else, so this
  /// field is part of the identity — the entity's own doc's last test is that one.
  final String questionId;

  /// `is_correct` — whether the submitted answer was right.
  ///
  /// **Not nullable.** `Question.isCorrect` is nullable because "not answered" and
  /// "answered wrongly" are two different facts that arrive **together in a reading
  /// payload**. Here they are not: a `SubmitResult` exists because an answer was
  /// submitted, so "no verdict" is not a state this response can be in. A `bool?`
  /// would have been a second way to say nothing.
  final bool isCorrect;

  /// `points_earned` — what **this** answer scored.
  ///
  /// Not the running total; [currentTotalPoints] is that. `0` on a wrong answer is
  /// a real value and not an absence.
  final int pointsEarned;

  /// `current_total_points` — the reader's total after this submission.
  final int currentTotalPoints;

  /// `current_streak` — the streak **as this submission left it**.
  ///
  /// ## IT MOVES ONLY WHEN [readingCompleted] IS TRUE
  ///
  /// §5 trap 4, measured: one correct answer does not advance the streak and
  /// finishing the reading does. So this field is not "the streak, which the
  /// submission refreshed" — it is "the streak, which the submission left alone
  /// unless the reading is finished". `ResultPage` reads [readingCompleted] beside
  /// it for that reason rather than drawing this number alone.
  ///
  /// It also disagrees with the other two endpoints' copies, and deliberately:
  /// see the class doc and recorded decision 22.
  final int currentStreak;

  /// `longest_streak` — the reader's best run, as the service reports it.
  ///
  /// **Read by `/result` and reconciled with nothing.** `StreakSummary.longestStreak`
  /// is the same field from `streak/summary`, and `StreakPill`'s "your longest yet"
  /// sentence compares [currentStreak] against **this** one — both from the same
  /// response, so the comparison the screen draws is one the server made possible.
  final int longestStreak;

  /// `reading_completed` — whether this submission finished the reading.
  ///
  /// **The gate on the streak**, §5 trap 4. See [currentStreak].
  final bool readingCompleted;
}
