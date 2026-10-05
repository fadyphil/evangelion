import 'package:evangelion/core/domain/entities/question.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'refreshed_questions.freezed.dart';

/// A **re-read** of today's reading, reduced to the two values a quiz session can
/// refresh.
///
/// ## WHY THIS TYPE EXISTS AT ALL, AND WHY IT IS NOT `ScriptureText`
///
/// `RefreshSessionQuestions` returns it because the backend has **no
/// `GET /readings/:id`** — measured, and there is no such route in
/// `src/modules/readings/`. So the client cannot ask "has question X been answered
/// since I last looked?" and cannot refresh one question. The only thing it can do
/// is re-fetch *today's whole reading* and take the parts that changed.
///
/// Those parts are exactly two, and this type is the naming of that fact:
///
/// * [questions] — with fresh `already_answered` flags, which is the entire reason
///   the use case exists (§5 trap 3: a stale flag is a `409` the reader walked into);
/// * [readingId] — because that value **moves**. §5 trap 11 records it rolling over
///   from `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` to
///   `reading-group-3-2026-10-04` between two probes of the same endpoint. A
///   refresh that returned only questions would leave the session submitting
///   against yesterday's reading.
///
/// **Rejected: returning `ScriptureText`.** That would give the caller everything
/// again and invite it to read fields this use case exists to refresh — and it would
/// be indistinguishable from `StartSession`'s return type, which is what makes the
/// two look redundant when they are not. §3's ISP row: the client depends on the
/// smallest interface that satisfies it.
///
/// **Rejected: returning `List<Question>`.** Then the caller has nowhere to get the
/// refreshed `reading_id` and would have to read the payload again — the exact
/// redundancy this type removes.
@freezed
final class RefreshedQuestions with _$RefreshedQuestions {
  /// A re-read, narrowed to what a session can take from it.
  const RefreshedQuestions({required this.readingId, required this.questions});

  /// The reading the [questions] belong to, as the fresh payload states it.
  final String readingId;

  /// The questions, in the server's order. Not re-sorted; see
  /// `ScriptureText.questions`.
  final List<Question> questions;

  /// `questions.length`.
  int get questionCount => questions.length;

  /// [next] with a different [readingId].
  ///
  /// Exists only for this file's own assertion that the two fields are **separate
  /// parts of the identity** — a `RefreshedQuestions` that could not be told apart
  /// from one with a different id would let a caller drop the id and nothing would
  /// say so. No production caller needs it, which is stated rather than hidden: it
  /// is the witness for a property of `props`, and recorded decision 48's lesson is
  /// that a property documented in three places and asserted in one is a property
  /// with one witness.
  RefreshedQuestions copyWithReadingId(String readingId) =>
      RefreshedQuestions(readingId: readingId, questions: questions);
}
