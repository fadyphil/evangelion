import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'commit_questions.freezed.dart';

/// What committing questions needs: the reading, and the questions.
///
/// ## WHY A PARAMS CLASS AND NOT TWO POSITIONAL ARGUMENTS
///
/// [UseCase]'s `call` takes exactly **one** argument — the house convention is
/// that a use case is a callable object invoked as `usecase(params)`. An
/// operation with two inputs therefore needs a value to hold them, and §4's
/// "named parameters for anything with more than two arguments" is the same
/// rule at a different scale.
///
/// ## AND THE HAZARD IS SPECIFIC: A READING ID AND A LIST
///
/// The two fields are a `String` and a `List`, so a transposition is not
/// possible in the way `SubmitAnswerParams`' three `String`s are — but the
/// **order** of the list is, and the list's order is the questions' `sort_order`
/// on the wire. The commit body sends the questions in the order they are
/// given (`admin.routes.ts:291-311`), so the order here is the order the
/// reader will meet them.
@freezed
final class CommitQuestionsParams with _$CommitQuestionsParams {
  /// A commit.
  const CommitQuestionsParams({
    required this.readingId,
    required this.questions,
  });

  /// The reading the questions belong to.
  ///
  /// **Not validated as a UUID.** The server's own schema types it as
  /// `z.string().min(1)` (`admin.routes.ts:36`) — a bare non-empty string, not
  /// a uuid — and §5's traps 10 and 11 record that the ids this backend
  /// mints are not uuids anyway. The id is **echoed**, never authored, except
  /// by the admin who typed it.
  final String readingId;

  /// The questions to commit, in the order they should be served.
  final List<QuestionDraft> questions;
}

/// Commits questions against a reading.
///
/// ## IT ADDS NOTHING TO THE PORT, AND THAT IS THE POINT
///
/// §3's DIP row: the wire's meaning is decided once, in the mapper and the
/// error mapper. What the class buys is the **seam** — the cubit depends on
/// this, so a test can hold the commit open without writing a repository, and
/// swapping the adapter is a change to one provider rather than to every
/// caller.
final class CommitQuestions
    implements UseCase<CommitQuestionsParams, CommitResult> {
  /// Commits through [repository].
  const CommitQuestions(this._repository);

  final ServantAdminRepository _repository;

  @override
  Future<Result<CommitResult>> call(CommitQuestionsParams params) =>
      _repository.commitQuestions(
        readingId: params.readingId,
        questions: params.questions,
      );
}
