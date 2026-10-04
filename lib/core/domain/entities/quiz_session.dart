import 'package:equatable/equatable.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';

/// One question as the reader has interacted with it so far.
///
/// ## A SELECTION AND A VERDICT ARE SEPARATE FACTS, AND NEITHER IS A `bool` FOR
/// ## THE SAME REASON
///
/// The reader has made **zero, one or two** moves on a question, and all three
/// states are reachable and distinguishable:
///
/// | state | [selectedLetter] | [verdict] |
/// | --- | --- | --- |
/// | untouched | `null` | `null` |
/// | chosen, not checked | a letter | `null` |
/// | checked | a letter | a `SubmitResult` |
///
/// `isChecked` is a **derived** getter over [verdict] rather than a third field,
/// and that is the whole point of the shape: an answer flagged checked with no
/// verdict behind it would render a "correct" state with nothing to justify it,
/// and the flag that would be wrong is the one a reader sees. There is exactly one
/// way for an answer to be checked and the type cannot express any other.
///
/// ## AND THE **WIRE** ANSWER IS CARRIED WITHOUT BEING REVEALED
///
/// [question] is the whole [Question], including `userAnswer` and `isCorrect` —
/// which the live reading ships for an already-answered question. They are on this
/// entity and nothing here reads them: [verdict] is `null` for an
/// already-answered question, because **no submission happened in this session**,
/// and a `SubmitResult` is the only thing on this type that can turn an option
/// card green.
///
/// That is the same separation `question.dart` established for `/reading` and
/// `reading_page_test.dart` enforces for it, restated for the screen where the
/// answer **is** allowed to appear — once the reader has chosen and checked.
/// `quiz_page_test.dart` holds an `already_answered` question on screen through the
/// whole boundary and asserts `is_correct` is in neither the widget tree nor the
/// semantics tree until the reader checks something.
final class QuizAnswer extends Equatable {
  /// A question, untouched.

  const QuizAnswer({required this.question, this.selectedLetter, this.verdict});

  /// The question as the server sent it.
  final Question question;

  /// The letter the reader chose, or `null` for nothing chosen.
  ///
  /// ## NOT VALIDATED AGAINST [question]'s OPTIONS, AND THE "CANNOT HAPPEN"
  /// ## ARGUMENT WAS **WITHDRAWN**
  ///
  /// The letters come from `Question.options`' keys and the client draws one card per
  /// key, so on **one payload** a value that is not a key cannot be produced. That
  /// was the whole of the argument, and it does not survive `withQuestions`: the
  /// rebase carries a `selectedLetter` from the previous payload onto a **fresh**
  /// `Question`, and the two option maps are independent — the mapper reads
  /// `options` from whatever the wire sent, and nothing requires the re-read to agree
  /// with the read before it.
  ///
  /// So a carried letter can name an option the new payload does not have. Two
  /// things keep that harmless rather than prevented:
  ///
  /// * the card is built from the options map's keys, so a letter that is not a key is
  ///   **never drawn** — the reader sees no selection, not a wrong one;
  /// * if the question was graded before the rebase, its `verdict` is carried with it
  ///   (see [QuizSession.withQuestions]'s decision 88), so `isAnswerable` is `false`
  ///   and the stale letter is never sent.
  ///
  /// What remains is an **ungraded** stale letter: `isAnswerable` is `true`, the CTA
  /// reads "Check answer", and the press sends a letter the fresh options do not
  /// contain. `submissions.routes.ts:7` accepts it (`z.string().min(1)`) and the
  /// server grades it against its own key.
  ///
  /// **Rejected: a `selectedLetter ∈ question.options` check.** A check here would be
  /// a second answer to "which letters exist?" beside the map's own keys, and it has
  /// no safe failure — refusing to carry the letter silently discards the reader's
  /// choice, which is the one thing this rebase exists to protect, while carrying it
  /// is what §5's `z.string().min(1)` contract accepts. The backend is the validator
  /// (recorded decision 15), and the honest statement of the client's guarantee is
  /// narrower than the first draft's: **the letter is sent verbatim, and it is never
  /// drawn unless the current payload has an option by that name.**
  final String? selectedLetter;

  /// The graded answer, or `null` until one arrives.
  final SubmitResult? verdict;

  /// Whether the reader has checked this answer.
  ///
  /// **Derived from [verdict]** — see the class doc.
  bool get isChecked => verdict != null;

  /// The verdict's `is_correct`, or `null` when there is no verdict.
  ///
  /// **Nullable for the reason `Question.isCorrect` is**, and the distinction is
  /// the one the quiz draws: `null` is *not yet graded* and `false` is *graded and
  /// wrong*, and the reader sees an unanswered card and a rejected card
  /// differently.
  bool? get isCorrect => verdict?.isCorrect;

  /// Whether the reader still has something to do with this question.
  ///
  /// ## THE QUESTION [isAnswerable] CANNOT ASK, AND WHY IT NEEDS A SIBLING
  ///
  /// [isAnswerable] is "may this be **submitted**", and it is `false` for three
  /// reasons: nothing chosen, already graded here, or the wire says it is answered.
  /// The reader can do nothing with the question in all three — but they also cannot
  /// **choose** on a question the wire already answers, and that is a different
  /// question from the one `isAnswerable` answers.
  ///
  /// So the two are separate, and the split is what makes `QuizState.cta`'s four
  /// arms expressible. A single predicate would have to encode "no selection yet",
  /// "graded" and "answered elsewhere" in one return value, and every caller would
  /// then have to decompose it.
  ///
  /// **`already_answered` is the wire's claim and is trusted as the server's own.**
  /// §5 trap 3 makes the consequence concrete — the alternative is a 409 — and
  /// `RefreshSessionQuestions` exists to keep the claim fresh.
  bool get isOpen => !question.alreadyAnswered && !isChecked;

  /// Whether this answer can still be submitted.
  ///
  /// ## FALSE ON BOTH `already_answered` AND [isChecked], AND BOTH ARE §5 TRAP 3
  ///
  /// A duplicate submit is a **409**, and the plan's requirement is that the client
  /// must not let a reader walk into a conflict it could have prevented. Two
  /// distinct things close an answer and the quiz closes on either:
  ///
  /// * the reader has already answered this question — the wire said so, and
  ///   `refresh` exists because that flag is only ever as fresh as the last fetch;
  /// * the reader has already checked it in this session, so there is nothing left
  ///   to send.
  ///
  /// `QuizOptionCard.enabled` reads this, and so does the bloc's handler for a
  /// selection, so the closure is not a property of the card alone.
  bool get isAnswerable =>
      !question.alreadyAnswered && selectedLetter != null && !isChecked;

  /// [next] with [letter] chosen.
  QuizAnswer withSelection(String letter) =>
      QuizAnswer(question: question, selectedLetter: letter, verdict: verdict);

  /// [next] with [result] as the verdict.
  QuizAnswer withVerdict(SubmitResult result) => QuizAnswer(
    question: question,
    selectedLetter: selectedLetter,
    verdict: result,
  );

  @override
  List<Object?> get props => <Object?>[question, selectedLetter, verdict];
}

/// Everything one visit to `/quiz` is playing against.
///
/// ## WHY THE INDEX IS **NOT** HERE
///
/// It is `QuizState.currentIndex`, not a field. The same argument as `ReadingCubit`
/// and `HomeBloc`'s `withSection`: a cursor through a list is *state*, and a reader
/// advancing is the writer. Putting it here would give this type two writers — the
/// session's own `withAnswerAt` and an "advance" method — and the two would have to
/// agree about what advancing means when the reader is mid-question.
///
/// ## [readingId] IS NOT AN IMMUTABLE FIELD OF THE QUIZ, IT IS **TODAY'S**
///
/// §5 records, measured against `HEAD = 4a1c834`: `reading_id` has already rolled
/// over once between two probes of the same endpoint, from a UUID
/// (`aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`) to a fabricated, **date-dependent**
/// `reading-group-3-2026-10-04`. `POST /readings/:id/submit` addresses the reading
/// by it, so an id captured at session start can be stale by the time the reader
/// submits. [withQuestions] is the writer that replaces it, and it is why
/// `RefreshSessionQuestions` returns an id as well as a list.
final class QuizSession extends Equatable {
  /// A session over [answers], submitting against [readingId].

  const QuizSession({required this.readingId, required this.answers});

  /// A fresh session over [questions], each untouched.
  ///
  /// ## ONE RULE FOR "THESE QUESTIONS ARE A SESSION", IN ONE PLACE
  ///
  /// Two writers need it: `StartSession` (there is nothing yet) and
  /// `QuizBloc._onRetried` after a failed **start** (there is nothing to rebase
  /// onto). The second case was a real defect this phase found in itself — the retry
  /// re-read, took the fresh flags, and then discarded them because
  /// `state.session` was `null` and `withQuestions` is a method on a session.
  /// `quiz_bloc_test.dart`'s `a retry that has something to retry DOES re-read`
  /// asserts the session comes back.
  ///
  /// *Rejected: `QuizRetried` re-running `StartSession`.* It would leave the retry
  /// path and the entry path as two spellings of one projection, and the one that
  /// loses the reader's selection.
  factory QuizSession.fromQuestions({
    required String readingId,
    required List<Question> questions,
  }) => QuizSession(
    readingId: readingId,
    answers: <QuizAnswer>[
      for (final Question question in questions) QuizAnswer(question: question),
    ],
  );

  /// The reading `POST /api/v1/readings/:id/submit` is addressed by.
  ///
  /// ## NOT VALIDATED AS A UUID, AND THAT IS THE POINT
  ///
  /// `submissions.routes.ts:18` types the path parameter as `description: 'Reading
  /// UUID'` — a **description**, not a schema. The route validates `body.question_id`
  /// with `z.string().uuid()` and validates no part of the path. So a non-UUID id
  /// in the path is not rejected by the schema; it is rejected, if at all, by the
  /// service failing to find the reading. A client-side UUID check would reject the
  /// **only** reading this backend serves — recorded decision 15's argument, applied
  /// to a second field.
  final String readingId;

  /// The questions, in the order the server sent them.
  ///
  /// **Not re-sorted.** `Question.sortOrder` is carried for the same reason
  /// `ScriptureText.questions` is: the client does not renumber, because
  /// `/result` and the beads row both read this list in its given order and a
  /// client-side sort would be a second numbering.
  final List<QuizAnswer> answers;

  /// `answers.length`.
  int get questionCount => answers.length;

  /// How many are already answered — checked here, or flagged on the wire.
  ///
  /// Two sources, one count, and **the wire's flag is part of it**: a question
  /// arriving with `already_answered: true` is answered whether or not this session
  /// graded it. Collapsing that to "checked in this session" would render a fresh
  /// bead row over a quiz the reader has already finished.
  int get answeredCount => answers
      .where(
        (QuizAnswer answer) =>
            answer.isChecked || answer.question.alreadyAnswered,
      )
      .length;

  /// Whether there is nothing to play against.
  bool get isEmpty => answers.isEmpty;

  /// The answer at [index], or `null` when [index] is out of range.
  QuizAnswer? answerAt(int index) =>
      index < 0 || index >= answers.length ? null : answers[index];

  /// [next] with [answer] at [index] and every other entry carried verbatim.
  ///
  /// **Returns [next] itself for an out-of-range [index]** rather than throwing, for
  /// the reason [answerAt] does: a writer the bloc calls on every submit must not
  /// be able to take the screen down over an index a future event got wrong.
  QuizSession withAnswerAt(int index, QuizAnswer answer) {
    if (index < 0 || index >= answers.length) return this;
    return QuizSession(
      readingId: readingId,
      answers: <QuizAnswer>[
        for (int i = 0; i < answers.length; i++)
          if (i == index) answer else answers[i],
      ],
    );
  }

  /// [next] rebuilt from a **fresh** set of [questions] and [readingId].
  ///
  /// ## WHY THIS REBASES RATHER THAN REPLACES, AND WHY IT IS NOT `copyWith`
  ///
  /// `RefreshSessionQuestions` exists because the backend has **no
  /// `GET /readings/:id`** — verified, and there is no route for one. The only way
  /// to learn a question's current `already_answered` is to re-fetch *today's whole
  /// reading*, which means the client cannot refresh **one** question. It can only
  /// take the whole payload and decide what survives it:
  ///
  /// | carried over | why |
  /// | --- | --- |
  /// | a [selectedLetter] whose `question.id` still exists | the reader's choice. It is not on the wire at all and it is theirs. |
  /// | a [QuizAnswer.verdict] whose `question.id` still exists | the server's grading of *that letter*. See below. |
  /// | nothing else | a [Question] is rebuilt from the fresh payload, so every wire field on it — `already_answered`, `userAnswer`, `isCorrect` — is the fresh one. |
  ///
  /// ## 88. THE VERDICT IS **CARRIED**, AND THE TABLE THAT SAID OTHERWISE WAS
  /// ## WRONG — THE 409 IS THE PROOF
  ///
  /// This table used to read "a `selectedLetter` … | **nothing else** — a `verdict`
  /// belongs to the response that produced it", one line above code that carried the
  /// verdict anyway. Deleting the carry makes the code match its own documentation and
  /// is green across every quiz and reading test, which is exactly why this is a
  /// decision and not a fix: the two halves were in conflict and one of them had to
  /// give.
  ///
  /// The carry is correct, and the argument is the one `isAnswerable` already makes:
  ///
  /// > a duplicate submit is a **409**, and the client must not let a reader walk into
  /// > a conflict it could have prevented.
  ///
  /// A `SubmitResult` is a fact about **the answer the reader gave**, not about the
  /// HTTP response that delivered it. `POST …/submit` graded `(question-group-3, 'C')`
  /// and said so; re-reading the passage does not un-grade it, and no second request
  /// will ever revise it. Dropping it on a rebase makes the session claim the question
  /// is unanswered while the letter is still on it, and the consequences run the wrong
  /// way on every axis:
  ///
  /// * `isChecked` goes false, so `isOpen` goes true;
  /// * `isAnswerable` goes **true**, so `QuizState.cta` returns the `check` arm and the
  ///   button reads "Check answer";
  /// * the reader presses it, and the server answers **409** — the exact outcome
  ///   `isAnswerable`, `QuizState.cta` and the whole `already_answered` design exist
  ///   to prevent;
  /// * and the card visibly un-grades in front of the reader, taking back a green or a
  ///   mark they were just shown.
  ///
  /// **The wire's flag cannot be relied on to prevent this, and the rebase is where
  /// that shows.** `already_answered` is only as fresh as the last fetch, and
  /// `RefreshSessionQuestions` re-reads precisely because it is not fresh — but a
  /// re-read can legitimately return the **pre-submit** payload for a question, and
  /// there is no client-side signal that distinguishes "not yet answered" from
  /// "answered after the response this re-read overtook". This client *knows* it
  /// graded the question; that knowledge is the only thing standing between the reader
  /// and a 409.
  ///
  /// **Rejected: honouring the table and dropping the verdict.** It converts a
  /// locally-known fact into a request the server will refuse, and it is reachable:
  /// the mapper *skips* unreadable questions (recorded decision 50) so a re-fetch can
  /// come back shorter, and `reading_id` rolls at midnight (§5 trap 11) — either
  /// shifts the payload out from under the cursor. The planted mutation was green
  /// before `quiz_session_test.dart` asserted the carry, and reds two tests after.
  ///
  /// **Rejected: keeping the verdict but ignoring the fresh `already_answered`.**
  /// The two are not in conflict — a graded answer is by definition answered — but
  /// preferring either over the other would be a second precedence rule, and
  /// [QuizAnswer.isAnswerable]'s `!alreadyAnswered && !isChecked` already states the
  /// one that applies.
  ///
  /// **The limit, stated honestly:** a question the fresh payload **no longer
  /// contains** loses everything, verdict included, because the switch has no entry for
  /// it. That is not this row's rule — it is `answers` being built from the fresh list
  /// — and it is the correct outcome: a question the server did not send is not on
  /// screen to be re-submitted.
  ///
  /// **A session with fewer questions than before is possible and is not an
  /// error.** `today_reading_mapper.dart` *skips* an unreadable question rather than
  /// refusing the passage (recorded decision 50), so a re-fetch can genuinely come
  /// back shorter. The reader's position is clamped by the caller, which is the
  /// only writer, and clamping a cursor is a smaller failure than an index that
  /// points at nothing.
  QuizSession withQuestions({
    required String readingId,
    required List<Question> questions,
  }) {
    final Map<String, QuizAnswer> previous = <String, QuizAnswer>{
      for (final QuizAnswer answer in answers) answer.question.id: answer,
    };
    return QuizSession(
      readingId: readingId,
      answers: <QuizAnswer>[
        for (final Question question in questions)
          switch (previous[question.id]) {
            final QuizAnswer answer => QuizAnswer(
              question: question,
              selectedLetter: answer.selectedLetter,
              verdict: answer.verdict,
            ),
            null => QuizAnswer(question: question),
          },
      ],
    );
  }

  @override
  List<Object?> get props => <Object?>[readingId, answers];
}
