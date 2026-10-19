import 'package:evangelion/core/domain/entities/streak_history_entry.dart';

/// The three numbers `/journey`'s three rings draw, derived from the reader's
/// thirty-day streak history.
///
/// ## THE THREE QUANTITIES
///
/// | ring | the prototype's label | what this file derives | the unit |
/// | --- | --- | --- | --- |
/// | 1 | "verses" (`eva/redesign.html:592`; the i18n row is `:935`) | completed scheduled days ÷ history entries | a ratio in `0.0…1.0` |
/// | 2 | "quizzes" (`:593`) | Σ `answered_questions` | a **bare count** |
/// | 3 | "accuracy" (`:594`) | Σ `correct_answers` ÷ Σ `answered_questions` | a ratio in `0.0…1.0` |
///
/// **The domain does not know about strings.** The page turns a ratio into
/// text — a percentage, a count, an Arabic-Indic numeral — and this file
/// imports no Flutter, no `dio` and no `http`: `features/*/domain/` is held to
/// pure Dart by `tool/verify_purity.sh` Gate 1, and a domain file that
/// imported `package:flutter` would fail it on the line.
///
/// ## FOUR DIVERGENCES FROM THE PROTOTYPE, AND EACH ONE IS A DECISION
///
/// **1. The first ring says "verses", and the number is not verses.**
///
/// The label is the prototype's own — `data-i18n="rlVerses"` at
/// `eva/redesign.html:592`, "verses" / "آيات" at `:935` — and it is kept,
/// because a bilingual client's strings come from the ARB and the prototype's
/// i18n table is where that table comes from.
///
/// The **quantity** under it is a scheduled-day completion ratio, and it cannot
/// be anything else: **the backend counts questions and carries no verse count
/// at all.** `ScheduledDayHistoryItem` (`streak.service.ts:5-17`) declares
/// `total_questions`, `answered_questions`, `correct_answers`, `points_earned`
/// and `is_completed`, and there is no verse field in it. A "verses" ratio
/// would have to invent a denominator the wire does not carry.
///
/// So the number is honest and the **word is the prototype's** — the same shape
/// as recorded decision 27's "beads count questions": the number is true, the
/// label is the redesign's, and the difference is written down here instead of
/// being discovered by a reader who counts verses and does not find any.
///
/// ADR-0022 is the authority for the prototype's own side of it:
/// "`eva/redesign.html` contains **zero** network and storage calls … It is a
/// pure local artefact, so every number in it is invented"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:39-42`). So its
/// `data-p=".83"` (`:592`) is decoration, and the fraction this file derives
/// is a real one.
///
/// **2. The second ring is a bare count, and that is a decision, not an
/// omission.**
///
/// The prototype writes `data-v="86"` with **no** percent sign (`:593`) where
/// its neighbours write `83%` (`:592`) and `92%` (`:594`) — an inconsistency in
/// the prototype's own markup. It is **resolved deliberately** rather than
/// transcribed: a percent sign is a unit, and a count of answered questions
/// does not have one. So the second ring's value is a bare integer and the
/// percentage mark is a thing the *page* may add to rings one and three only.
///
/// **3. The ratios are over a thirty-day window, not over a lifetime.**
///
/// The history is the last **thirty** scheduled days and no more:
/// `streak.service.ts:87-95` queries them with `ORDER BY dr.scheduled_date
/// DESC` (`:93`) and `LIMIT 30` (`:94`). A ratio over that window is a
/// thirty-day ratio, and saying "thirty-day" is the difference between a
/// number the reader can act on and one that reads as a lifetime total.
///
/// **4. Division by zero is a value, not an exception.**
///
/// An empty history gives **0** for all three — never a `NaN`, never a throw.
/// A reader who has no history is a real state, not an error: "`history` is
/// empty exactly when the cohort has no scheduled reading on file, which is a
/// real state a new reader is in"
/// (`features/home/domain/usecases/load_last_light.dart:26-28`), and a `NaN`
/// reaching the ring's stroke arithmetic would draw nothing and say nothing
/// about why. The zero is the answer.
final class JourneyRings {
  /// Creates the three ring values.
  const JourneyRings({
    required this.completion,
    required this.answered,
    required this.accuracy,
    required this.answeredShare,
  });

  /// Completed scheduled days ÷ history entries. A ratio in `0.0…1.0`.
  ///
  /// "Completed" is the **server's own verdict**, not a client opinion:
  /// `StreakHistoryEntry.isCompleted` is the endpoint's `is_completed`, and
  /// `streak.service.ts:112` computes it as
  /// `totalQ > 0 && answeredQ >= totalQ`. A day with no questions is therefore
  /// never complete, and this client does not re-derive the rule.
  ///
  /// The denominator is **every** row in the window, completed or not, because
  /// the question the ring answers is "how many of the days you were given did
  /// you finish" — and a day the reader was given and did not finish is the
  /// half of the answer that makes the half meaningful.
  final double completion;

  /// Σ `answered_questions` over the window. A **bare count**.
  ///
  /// Every row counts, completed or not: a question answered on a day the
  /// reader did not finish is still a question answered, and the prototype's
  /// own second ring is a count of the same currency (`data-v="86"`, `:593`).
  final int answered;

  /// Σ `correct_answers` ÷ Σ `answered_questions`. A ratio in `0.0…1.0`.
  ///
  /// The two sums are over the same window and over every row of it, so the
  /// ratio is a **pooled** accuracy — every question the reader answered in the
  /// window weighed the same — and not a mean of per-day accuracies, which
  /// would weight a one-question day the same as a ten-question one.
  ///
  /// ## WHAT KEEPS IT INSIDE `0.0…1.0`
  ///
  /// The server's two counts are **nested**: `answered_q` counts the reader's
  /// submissions for the reading (`streak.service.ts:103`) and `correct_q`
  /// counts the same submissions with `is_correct = TRUE` added
  /// (`:104`), so `correct_q ≤ answered_q` for every row, and so for every
  /// sum. A reader's accuracy cannot exceed one, and a negative count cannot
  /// reach the wire, because both are `COUNT(*)`s.
  ///
  /// **What is not guaranteed is that the client would notice a payload that
  /// broke it.** The mapper checks *types* and not ranges
  /// (`streak_history_mapper.dart:221-226`), so a body claiming more correct
  /// answers than answered ones would be mapped, and the ratio would fall
  /// outside `0.0…1.0`. This function does **not** clamp it: a clamp would
  /// silently report a number the payload does not contain, and the ring's own
  /// arc arithmetic (`163 · (1 − p)`, `eva/redesign.html:1451`) is the place
  /// where an out-of-range fraction becomes visible.
  final double accuracy;

  /// Σ `answered_questions` ÷ Σ `total_questions`. A ratio in `0.0…1.0`.
  ///
  /// ## WHY THE COUNT RING NEEDS A **FRACTION** AND A COUNT DOES NOT
  ///
  /// Because a ring is **an arc**, and an arc is a fraction — and
  /// [answered] is a bare count with **no denominator of its own**. The
  /// prototype draws an arc on its count ring anyway (`data-p=".86"`, `:593`),
  /// but its `.86` is decoration over a hard-coded literal, and the two
  /// neighbours' `83%` and `92%` are decoration too.
  ///
  /// So this client has to put *something* on that arc, and the three candidates
  /// are: a number the payload does not contain, an empty arc that reads as
  /// broken, or **a real ratio the payload does contain**. This is the third.
  ///
  /// ## AND IT IS A **DIFFERENT QUANTITY** FROM THE NUMBER BESIDE IT
  ///
  /// The number in the middle of the ring is the **count** — 86 questions
  /// answered — and the arc is the **share** of the scheduled questions that
  /// were answered. A reader who wants the count reads the number; a reader who
  /// wants the progress reads the arc. They are not the same figure, and the
  /// difference is recorded at the widget that draws them.
  ///
  /// ## AND IT IS NOT CLAMPED, FOR [accuracy]'s REASON
  ///
  /// The server's two counts are nested (`streak.service.ts:103-104`), so
  /// `answered_q ≤ total_q` for every row the server produces. The mapper
  /// checks types and not ranges, so a body that broke it would be mapped —
  /// and this ratio would fall outside `0.0…1.0`, which the ring's own arc
  /// arithmetic (`163 · (1 − p)`) would then show.
  final double answeredShare;

  /// WHY THIS COMPARES BY VALUE
  ///
  /// Two derivations of one history are the same rings, and this type says so.
  ///
  /// The rings travel inside a bloc state, and the state is compared with
  /// `==` — so without this, a reload that produced the same numbers would
  /// look like a change and cost a rebuild for nothing. The `runtimeType`
  /// guard is the same one `Failure` carries, for the same reason: a `double`
  /// and an `int` can compare equal, and two different types must not.
  ///
  /// ## AND ALL **FOUR** FIELDS ARE COMPARED
  ///
  /// The class has four fields and the comparison has to have all four, or a
  /// ring keeps a sweep it no longer owns. The omission that was here was
  /// [answeredShare] — the count ring's **arc** — and it was not harmless:
  /// a reload that moved only the share (the same count of answered
  /// questions over a different number of scheduled ones) compared equal, so
  /// the cubit saw no change and the count ring kept its old sweep while its
  /// number beside it had moved. The number and the arc are different
  /// quantities, and both of them are state.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneyRings &&
          runtimeType == other.runtimeType &&
          completion == other.completion &&
          answered == other.answered &&
          accuracy == other.accuracy &&
          answeredShare == other.answeredShare;

  @override
  int get hashCode =>
      Object.hash(completion, answered, accuracy, answeredShare);
}

/// The three ring values, derived from the reader's streak history.
///
/// ## WHAT IT READS, AND WHAT IT DOES NOT
///
/// It reads **three** things off each row: `is_completed`, `answered_questions`
/// and `correct_answers`. It does not read `total_questions`, `points_earned`,
/// the reference, the book name or the date — and it does not sort, filter or
/// trim the list. The order is the server's (`scheduled_date DESC`,
/// `streak.service.ts:93`) and this function has no opinion about it.
///
/// ## WHY IT IS A PURE FUNCTION IN THE DOMAIN
///
/// Because the derivation is **domain logic**, and the plan's widget exemption
/// does not extend to it: "domain logic must not be buried inside a widget"
/// (AGENT_CONTEXT §6). A widget that computed a completion ratio inline would
/// be untested logic wearing a `build` method, and no gate in this repository
/// could see it.
///
/// ## AND WHY IT IS NOT A `Result`
///
/// Because there is nothing to fail. The history arrives as a `Result` at the
/// port, and this function is reached only once it is a list; a ratio over a
/// list is always a number. The **zero** case is a value, not a failure —
/// see the class doc's fourth divergence.
JourneyRings deriveJourneyRings(List<StreakHistoryEntry> history) {
  int completed = 0;
  int answered = 0;
  int correct = 0;
  int total = 0;

  for (final StreakHistoryEntry entry in history) {
    if (entry.isCompleted) {
      completed++;
    }
    answered += entry.answeredQuestions;
    correct += entry.correctAnswers;
    total += entry.totalQuestions;
  }

  final int days = history.length;
  return JourneyRings(
    // `0.0` and not `0`: the two arms of a conditional expression must have
    // the same type, and `int` and `double` do not have one between them.
    completion: days == 0 ? 0.0 : completed / days,
    answered: answered,
    accuracy: answered == 0 ? 0.0 : correct / answered,
    // The **share** of the scheduled questions that were answered — the count
    // ring's arc, which the count itself cannot supply.
    answeredShare: total == 0 ? 0.0 : answered / total,
  );
}

/// The number of **distinct books** among the completed scheduled days — the
/// proxy for the prototype's "constellations".
///
/// ## WHAT THE PROTOTYPE COUNTS
///
/// The sky line draws two numbers (`eva/redesign.html:596`): `jSkyN`, the lit
/// stars, and `jSkyC`, the constellations. The second is
/// `Object.keys(constDone).length` (`:1188`), where `constDone` (`:1132`) is
/// an object **keyed by book** and is set when the reader reaches the **last
/// verse of that book** (`:1156-1157`).
///
/// ## WHY THIS CLIENT CANNOT COUNT THAT
///
/// **There is no book-completion record.** The sky store persists the verse
/// keys, a flare flag and a lit-at stamp, and the sky is capped at **44**
/// stars (`eva/redesign.html:1131`), with the cap enforced by evicting the
/// oldest star (`:1147`). A book whose stars are evicted loses its
/// constellation — so "the books the reader finished" is a number the client
/// cannot reproduce from the sky, and the prototype's own count is a
/// consequence of its DOM's lifetime.
///
/// ## SO THIS IS A PROXY, AND NAMED AS ONE
///
/// The count is the distinct `book_number` values among the **completed**
/// history entries. `book_number` is the join key for per-book completion and
/// the only field on the row that names a book in a way that survives
/// translation (`streak_history_entry.dart:85-90`), and `is_completed` is the
/// server's own verdict on the day.
///
/// ## WHAT THE PROXY GIVES UP
///
/// It counts **books the reader finished a scheduled day of**, not books the
/// reader read to the end. Concretely:
///
/// * a book with one completed scheduled day counts, whether or not the reader
///   ever reached its last verse;
/// * a book the reader read to its last verse on a day that was **not**
///   completed — because that day's questions were not all answered — does not
///   count at all.
///
/// The two definitions are different questions, and the endpoint answers the
/// second one about *questions* and the first one about *days*; neither is the
/// prototype's question about *verses*. The proxy is stated here so that a
/// reader of the number knows which of the three it is.
///
/// ADR-0022's fiction table agrees about the **source**: "Sealed books
/// `:1032` | **rule stub, data real** | per-book completion from `GET /streak`
/// `history`"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:60`). The
/// per-book completion is meant to come from this history, and this is the only
/// per-book data the wire carries.
///
/// ## AND IT IS A THIRTY-DAY NUMBER TOO
///
/// The same window as the rings: the history is at most thirty scheduled days
/// (`streak.service.ts:87-95`), so this is a count over that window.
int countCompletedBooks(List<StreakHistoryEntry> history) {
  final Set<int> books = <int>{};

  for (final StreakHistoryEntry entry in history) {
    if (entry.isCompleted) {
      books.add(entry.bookNumber);
    }
  }

  return books.length;
}
