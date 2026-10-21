import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_draft.freezed.dart';

/// The three question types the backend's commit schema accepts.
///
/// ## WHY THIS IS AN ENUM AND NOT A `String`
///
/// `admin.routes.ts:38` types it as
/// `z.enum(['mcq', 'true_false', 'short_answer'])`, and zod **rejects**
/// anything else with a 400 before the handler runs. A `String` on this side
/// would let a typo through to the wire, where it becomes a 400 whose message
/// names a field the reader never saw.
///
/// ## THE WIRE SPELLINGS ARE SPELLED OUT, NEVER DERIVED
///
/// The `UserRole.wireValue` rule (`core/domain/entities/user_role.dart`): `.name`
/// is the Dart spelling and is **never** a wire value. `QuestionType.trueFalse.name`
/// is `'trueFalse'`, which is in **none** of the backend's three declared
/// values — a derived spelling would send a type the server stores happily and
/// no client can name.
enum QuestionType {
  /// `mcq` — a multiple-choice question with lettered options.
  mcq('mcq'),

  /// `true_false` — a two-option question.
  trueFalse('true_false'),

  /// `short_answer` — a free-text answer, with no options.
  shortAnswer('short_answer');

  const QuestionType(this.wireValue);

  /// The value this client sends as the question's `type`.
  final String wireValue;

  /// The type [wire] names, or `null` if it names none of them.
  ///
  /// **`null` and not a default**, for the reason
  /// `LeaderboardWindow.fromCode` gives: a fourth type would be a server
  /// change this client has to be told about, and quietly reporting it as
  /// `mcq` would be a wrong answer presented confidently. A `null` lets the
  /// mapper refuse the payload as a serialization failure, so the reader is
  /// told the app is behind the server rather than shown a plausible lie.
  static QuestionType? fromWire(String wire) => switch (wire) {
    'mcq' => QuestionType.mcq,
    'true_false' => QuestionType.trueFalse,
    'short_answer' => QuestionType.shortAnswer,
    _ => null,
  };
}

/// One answer option, in both of the app's languages.
///
/// ## WHY AN OBJECT AND NOT TWO STRINGS
///
/// `admin.routes.ts:41-44` types an option as `{ar: string, en: string}`, and
/// the **same shape** is what the AI draft returns
/// (`ai.service.ts:9`, `GeneratedQuestionPayload.options`) — which is why a
/// draft is editable and committable without a conversion (the design spec
/// §6.1).
///
/// The domain holds the pair, so the mapper has one place that spells
/// `{'ar': …, 'en': …}` and the question editor has one place that reads a
/// language out of an option.
@freezed
final class QuestionOption with _$QuestionOption {
  /// An option, in Arabic and in English.
  const QuestionOption({required this.ar, required this.en});

  /// The Arabic text — Smith & Van Dyck.
  final String ar;

  /// The English text — NKJV.
  final String en;
}

/// A question, hand-written or AI-drafted, ready to be committed.
///
/// ## THE SHAPE IS THE SERVER'S `commitQuestionsSchema`, FIELD FOR FIELD
///
/// `admin.routes.ts:35-50`:
///
/// ```text
/// type: 'mcq' | 'true_false' | 'short_answer'   (default 'mcq')
/// prompt_ar: string                             (min 1)
/// prompt_en: string                             (min 1)
/// options?: {A: {ar, en}, …}
/// correct_answer: string                        (min 1)
/// points_value: int                             (default 10)
/// sort_order: int                               (default 1)
/// is_approved: bool                             (default true)
/// ```
///
/// **The three defaulted fields are on the entity rather than applied at the
/// wire**, and that is what makes a draft committable without a conversion:
/// the AI endpoint returns only `type`, `prompt_ar`, `prompt_en`, `options`
/// and `correct_answer` (`ai.routes.ts:31-40`), and the draft the admin edits
/// must already carry the values the commit will send. The defaults are the
/// commit schema's own — 10, 1 and `true` — not this client's invention.
///
/// ## AND THE OPTIONS MAP IS EMPTY, NOT ABSENT, FOR A QUESTION WITH NONE
///
/// The schema's `options` is optional, and a short-answer question has none.
/// The domain carries an **empty map** rather than a `null`, so "no options" is
/// one state rather than two, and the mapper decides what the wire says about
/// it — it **omits the key**, which is how the server's own
/// `JSON.stringify(q.options || null)` stores a question with no options.
@freezed
final class QuestionDraft with _$QuestionDraft {
  /// A question ready to commit.
  const QuestionDraft({
    required this.type,
    required this.promptAr,
    required this.promptEn,
    required this.options,
    required this.correctAnswer,
    required this.pointsValue,
    required this.sortOrder,
    required this.isApproved,
  });

  /// Which kind of question this is.
  final QuestionType type;

  /// The Arabic prompt — Smith & Van Dyck.
  final String promptAr;

  /// The English prompt — NKJV.
  final String promptEn;

  /// The lettered options, empty for a question that has none.
  final Map<String, QuestionOption> options;

  /// The key of the correct option.
  ///
  /// A **letter** for a question with options. The schema types it as a plain
  /// string (`admin.routes.ts:45`) and the AI service checks it against the
  /// options it produced (`ai.service.ts:145`), so this client does not narrow
  /// it to a single letter — a short answer's `correct_answer` is the answer
  /// itself.
  final String correctAnswer;

  /// How many points the question is worth.
  final int pointsValue;

  /// The question's position among its reading's questions.
  final int sortOrder;

  /// Whether the question is approved to be served to readers.
  ///
  /// The server stores it verbatim, and the roster report counts only the
  /// **approved** questions (`admin.routes.ts:383`).
  final bool isApproved;
}
