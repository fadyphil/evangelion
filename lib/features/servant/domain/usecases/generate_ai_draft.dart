import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generate_ai_draft.freezed.dart';

/// What an AI draft needs: the reading, and the kind of question.
///
/// ## WHY THE TYPE IS PART OF THE PARAMS AND NOT CHOSEN BY THE SERVER
///
/// `ai.routes.ts:10` types the request's `type` as
/// `z.enum(['mcq', 'true_false']).default('mcq')` — so the server **has** a
/// default, and a client that omitted the key would get an `mcq`.
///
/// The type is still named here, because "draft a multiple-choice question" and
/// "draft a true/false question" are different requests and a caller that
/// cannot say which one it wants cannot tell the two answers apart.
@freezed
final class GenerateAiDraftParams with _$GenerateAiDraftParams {
  /// A draft request.
  const GenerateAiDraftParams({required this.readingId, required this.type});

  /// The reading the question is about.
  ///
  /// **Not validated as a UUID** — see `CommitQuestionsParams.readingId`.
  final String readingId;

  /// The kind of question to draft.
  final QuestionType type;
}

/// Asks the server for a drafted question.
///
/// ## IT ADDS NOTHING TO THE PORT, AND THAT IS THE POINT
///
/// §3's DIP row: the wire's meaning is decided once, in the mapper and the
/// error mapper. What the class buys is the **seam**.
///
/// ## AND THE PORT IS WIDER THAN THE ENDPOINT
///
/// The domain has three question types and the AI route accepts **two**. The
/// port states the domain's vocabulary and the adapter narrows it, because the
/// adapter is the one that knows what the endpoint accepts — a fact about the
/// wire, not about the domain.
final class GenerateAiDraft
    implements UseCase<GenerateAiDraftParams, QuestionDraft> {
  /// Drafts through [repository].
  const GenerateAiDraft(this._repository);

  final ServantAdminRepository _repository;

  @override
  Future<Result<QuestionDraft>> call(GenerateAiDraftParams params) =>
      _repository.generateAiDraft(
        readingId: params.readingId,
        type: params.type,
      );
}
