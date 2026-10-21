import 'package:freezed_annotation/freezed_annotation.dart';

part 'commit_result.freezed.dart';

/// What the commit-questions endpoint answered.
///
/// ## THE `201` BODY, FIELD FOR FIELD
///
/// `admin.routes.ts:313-316` sends `{message, question_ids: string[]}` with
/// **201**, and the schema at `:93-98` declares exactly those two keys.
///
/// The **message** is the server's own sentence — `Committed N questions for
/// reading` — and it is kept verbatim, for the reason
/// `ScheduleResult.message` gives.
///
/// The **ids** are the questions the transaction inserted, one per committed
/// question and in the order they were sent.
@freezed
final class CommitResult with _$CommitResult {
  /// The server's answer.
  const CommitResult({required this.message, required this.questionIds});

  /// The server's sentence, verbatim.
  final String message;

  /// The ids of the questions the transaction wrote, in the order sent.
  final List<String> questionIds;
}
