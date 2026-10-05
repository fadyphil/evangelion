import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'submit_answer.freezed.dart';

/// What one submission needs: the reading, the question, and the letter.
///
/// ## WHY A PARAMS CLASS AND NOT THREE `String`s
///
/// [UseCase]'s `call` takes exactly **one** argument — the house convention is that
/// a use case is a callable object invoked as `usecase(params)`. A three-value
/// operation therefore needs a value, and §4's "named parameters for anything with
/// more than two arguments" is the same rule at a different scale: it is about
/// stopping a reader from having to remember which of three positions is which.
///
/// ## AND THE HAZARD IS SPECIFIC, NOT GENERAL
///
/// All three fields are `String`, and two of them are **ids**. A submission built
/// with the arguments transposed —
/// `(questionId: readingId, readingId: questionId)` — is a well-typed program that
/// sends a reading's id as a question's id and a question's id as a reading's id.
/// Against this backend it happens to be harmless today (§5 trap 10: a non-UUID
/// `question_id` is a `400` before anything is looked up), which is exactly why it
/// must be caught by a **type** rather than by a live response.
///
/// **Two assertions, in two files, because there are two writers.** This class is
/// one of them: `quiz_use_cases_test.dart` asserts that `SubmitAnswer` hands the port
/// each field it was given, verbatim — which catches a transposition *inside this
/// file* and says nothing about who filled the fields. `QuizBloc` is the other, and
/// its assertion is `quiz_bloc_test.dart`'s "sends exactly the contract triple, in
/// the session's arm", which reads the repository's record of the three values and
/// compares the whole record at once.
///
/// That second assertion used to be deferred to a file that did not exist, and the
/// version in its place asserted only that the bloc was a bloc; the planted
/// transposition at the `SubmitAnswerParams` call site was green across the whole
/// suite. Both halves are load-bearing and only the use-case half was real.
///
/// **Nothing here is validated.** `submissions.routes.ts:6-8` validates
/// `question_id: z.string().uuid()` and `answer: z.string().min(1)`; `:18` types the
/// path parameter as a *description*, not a schema. The backend is the validator
/// (recorded decision 15), and §5 traps 10 and 11 record that the `reading_id` it
/// serves is a fabricated, date-dependent non-UUID — so a UUID check here would
/// reject the only reading this client is ever given.
@freezed
final class SubmitAnswerParams with _$SubmitAnswerParams {
  /// One submission.
  const SubmitAnswerParams({
    required this.readingId,
    required this.questionId,
    required this.answer,
  });

  /// The reading `POST /api/v1/readings/:id/submit` is addressed by.
  ///
  /// Today's, and it is read off the reading response rather than configured:
  /// §2's route table carries no `:passageId` because there is no library to browse.
  final String readingId;

  /// The `question_id` body field.
  final String questionId;

  /// The `answer` body field — *"Selected option (A, B, C, D) or boolean"*, per
  /// `submissions.routes.ts:35`. Sent verbatim, and see [SubmitAnswer]'s doc.
  final String answer;
}

/// Grades one answer.
///
/// ## IT ADDS NOTHING TO THE PORT, AND THAT IS THE POINT
///
/// §3's DIP row: a use case that reclassified an error or reshaped an entity would
/// be a **second** place where the wire's meaning is decided, and
/// `ApiErrorMapper` plus `SubmitResultMapper` are already it. What the class buys
/// is the **seam** — `QuizBloc` depends on this, so a test can hold the submit open
/// without writing a repository, and swapping the adapter is a change to one
/// provider in `home_module.dart` rather than to every caller. `LoadScripture`'s
/// doc gives the same argument at greater length and this is the third instance.
///
/// ## AND A 409 IS **TYPED HERE AND PREVENTED UPSTREAM**
///
/// §5 trap 3: submitting an already-answered question is
/// `409 This question has already been submitted by this user.` This class passes
/// that through as `FailureKind.conflict` with the server's own message, which is
/// required by §3's LSP row and is **not** the prevention. The prevention is
/// `QuizAnswer.isAnswerable`, in the domain layer, which closes the question before a
/// request exists — because by the time this method is reached the reader has
/// already pressed the button. `dio_repositories_test.dart` asserts both claims
/// next to each other, so "the mapper handles it" is never readable as "the client
/// prevents it".
final class SubmitAnswer implements UseCase<SubmitAnswerParams, SubmitResult> {
  /// Submits through [repository].
  const SubmitAnswer(this._repository);

  final ReadingRepository _repository;

  @override
  Future<Result<SubmitResult>> call(SubmitAnswerParams params) =>
      _repository.submitAnswer(
        readingId: params.readingId,
        questionId: params.questionId,
        answer: params.answer,
      );
}
