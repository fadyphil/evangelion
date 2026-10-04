import 'package:equatable/equatable.dart';

/// One reflection question, as `GET /api/v1/readings/today/{lang}` sends it.
///
/// ## WHY IT IS IN `core/domain/` AND NOT IN `features/reading/`
///
/// **Mechanically, not by preference.** `core/domain/repositories/reading_repository.dart`
/// names `ScriptureText` in a **signature**, and Dart has no way to return a type a
/// file does not import — so the entity a port returns is a file the port reaches.
/// §3's placement test puts a type used by one feature in that feature's `domain/`,
/// and this file is one feature's `domain/` right now: only `/reading` reads a
/// question, and Phase 8's `quiz` will be the second consumer that promotes it.
///
/// The alternative was measured rather than argued: keeping `Question` in
/// `features/reading/domain/` and having the port return it makes
/// `core/domain/repositories/reading_repository.dart` import `features/reading/`,
/// and `tool/verify_purity.sh` **Gate 2** fails on exactly that line —
/// "`core` must not depend on … reading". There is no seam that avoids it except
/// declaring the port twice, which is what `home` already pays for
/// `GetReaderSession` (recorded decision 25) and would now be paying twice over.
///
/// ## [isCorrect] AND [userAnswer] ARE CARRIED, AND THE READING SCREEN MUST NOT
/// RENDER THEM
///
/// **Measured live against `HEAD = 4a1c834`, group 3:** the reading response puts
/// `user_answer: "A"` and `is_correct: true` **inside the question object** of the
/// `GET /readings/today` body. The server ships the answer with the question, so
/// any client that reads today's reading already holds the answer to today's quiz.
///
/// `/reading` therefore renders **verses only**. The reading screen is the
/// sanctuary — it is the one screen where a reader is asked to sit with the text —
/// and drawing `is_correct` there would tell the reader the answer to
/// `QuizPage` before they have chosen one. `reading_page_test.dart` asserts the
/// rendered AR and EN trees contain neither the boolean nor the letter, in the
/// failing direction, with the live payload (which carries both) behind them.
///
/// The fields are **not dropped from the entity** for two reasons. Phase 8's quiz
/// needs them to disable already-answered questions (§5, trap 3), and an entity
/// that silently dropped fields the wire sends is a lossy projection with no
/// stated reason — which is the argument `today_reading.dart` makes for keeping a
/// streak it disagrees about.
///
/// **Rejected: a `Question` that does not carry them.** It would make Phase 8
/// re-parse the raw body, which is the "second place where the wire's meaning is
/// decided" §3's DIP row forbids.
final class Question extends Equatable {
  /// A question as the wire describes it.
  const Question({
    required this.id,
    required this.sortOrder,
    required this.type,
    required this.prompt,
    required this.options,
    required this.pointsValue,
    required this.alreadyAnswered,
    this.userAnswer,
    this.isCorrect,
  });

  /// `id` — a UUID on the live payload, and the value
  /// `POST /readings/:id/submit` addresses by `question_id`.
  ///
  /// **Not validated as a UUID.** §5 records that the backend *is* the validator:
  /// `POST` rejects a non-UUID `question_id` with `400 body/question_id must match
  /// format "uuid"`, and §5's in-memory fallback **fabricates** non-UUID ids
  /// (`question-group-3`) for any group other than 3. A client-side UUID check
  /// would therefore reject readings the server is happy to serve — the same
  /// argument `isValidUserId`'s recorded correction makes from the other side.
  final String id;

  /// `sort_order` — the server's own ordering. Carried, never re-sorted: a client
  /// that renumbered questions would disagree with `/result`, which reads them in
  /// the order it was given them.
  final int sortOrder;

  /// `type` — `'mcq'` on every payload this client has seen.
  ///
  /// ## A STRING, NOT AN ENUM, AND THE REASON IS SCOPE
  ///
  /// §4 asks for exhaustive `switch` **expressions** over enums, and an enum here
  /// would be one member with no reader: nothing in Phase 7 branches on it, and
  /// Phase 8 is what renders a question by type. Declaring `enum QuestionType { mcq }`
  /// today would be §3's "nothing enters speculatively" with an extra step, and the
  /// server sending a second value would map as a **serialization failure** —
  /// turning "a quiz type this client cannot draw" into "the reader cannot open
  /// today's passage", which is decision 40's exact mistake.
  ///
  /// So the wire value is carried verbatim and the mapper accepts any `String`.
  /// Phase 8 adds the enumeration **at the point of rendering**, where an unknown
  /// value can become a message about the question rather than about the reading.
  final String type;

  /// `prompt` — the question text. Never rendered on `/reading`; see the class doc.
  final String prompt;

  /// `options` — a **flat** `Map` of letter to option text (§5). `A`…`D` on the
  /// live payload.
  ///
  /// ## WHY A MAP AND NOT A LIST
  ///
  /// Because the wire is a map, and a list would be a re-declaration of it with
  /// the keys moved into a field of their own — so a phase that reads the options
  /// has to decide what an unexpected key means, and a phase that has not yet read
  /// them has no business making that decision. Phase 8 owns the ordering question
  /// (`sort_order` on the *options* is not in the payload at all, so the map's own
  /// insertion order is the only ordering the server states).
  final Map<String, String> options;

  /// `points_value` — `10` on the live payload. Carried for Phase 8's result screen.
  final int pointsValue;

  /// `already_answered`.
  ///
  /// **`false` when the key is absent or is not a `bool`**, which is Phase 6's
  /// rule for the same field in the same payload and is not relaxed here: a
  /// question this client cannot prove is answered is a question the reader should
  /// still see as open. §5, trap 3 makes the consequence concrete — a
  /// `already_answered == false` question that has actually been submitted comes
  /// back as **409**, so getting this wrong is visible rather than silent.
  final bool alreadyAnswered;

  /// `user_answer` — the letter the reader already chose, or `null`.
  ///
  /// `null` for **both** shapes the live payloads carry: the unanswered question
  /// sends `"user_answer": null`, and the answered one sends `"A"`. A key the
  /// mapper cannot read as a `String` is also `null` — the same leniency
  /// [alreadyAnswered] gets, because the two fields are read from the same object
  /// and a rule that treats one strictly and the other leniently is a rule nobody
  /// can predict.
  final String? userAnswer;

  /// `is_correct` — whether that answer was right, or `null` when there is none.
  ///
  /// **Nullable, and that is the payload's shape rather than a convenience.**
  /// `AGENT_CONTEXT` §5's response shape shows `"is_correct": null` beside
  /// `"user_answer": null`, so "not answered" and "answered wrongly" are
  /// **different facts** and a `bool` would have to invent one of them. A
  /// non-`bool` maps to `null` on the same terms as [userAnswer].
  final bool? isCorrect;

  /// [other] with the named fields replaced.
  ///
  /// Not needed by any caller today, and that is why it is here anyway: the three
  /// nullable fields make this the one entity in the kernel where `copyWith`
  /// cannot express "clear it" (`copyWith(isCorrect: null)` keeps the old value),
  /// and having the hazard visible in the type is cheaper than a caller
  /// discovering it.
  Question copyWith({
    String? id,
    int? sortOrder,
    String? type,
    String? prompt,
    Map<String, String>? options,
    int? pointsValue,
    bool? alreadyAnswered,
    String? userAnswer,
    bool? isCorrect,
  }) => Question(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    type: type ?? this.type,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    pointsValue: pointsValue ?? this.pointsValue,
    alreadyAnswered: alreadyAnswered ?? this.alreadyAnswered,
    userAnswer: userAnswer ?? this.userAnswer,
    isCorrect: isCorrect ?? this.isCorrect,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    sortOrder,
    type,
    prompt,
    options,
    pointsValue,
    alreadyAnswered,
    userAnswer,
    isCorrect,
  ];
}
