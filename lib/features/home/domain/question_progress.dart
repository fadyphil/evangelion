/// The bead index that is "the one to do next", for a reading's questions.
///
/// ## WHY THE PROTOTYPE'S `total={5} completed={2} current={2}` IS NOT SMALLER
///
/// `HomeScreen.tsx:65` writes exactly that, and it describes **passage** progress
/// across the four-card library grid that AGENT_CONTEXT §2 decision 1 cut. There
/// is no passage grid, no passage has five steps, and the live reading carries
/// **one** reflection question.
///
/// So the row counts questions:
///
/// | `ProgressBeads` | source |
/// | --- | --- |
/// | `total` | `TodayReading.questionCount` |
/// | `completed` | `TodayReading.answeredQuestionCount` |
/// | `current` | [firstUnansweredQuestionIndex] |
///
/// ## THE CLAMP IS **CURRENTLY UNOBSERVABLE**, and that is measured
///
/// The first version of this file claimed the clamp keeps a bead reading as
/// "current" when every question is answered. **It does not**, and the reason is
/// `beadStateAt`'s own rule: `done = i < completed; curr = i === current && !done`
/// — the `i < completed` branch is taken first, so with `completed == total` every
/// bead is `done` whichever index is passed as `current`. Measured over both
/// candidates, `beadStates(total: 3, completed: 3, current: 3)` and
/// `… current: 2` return the identical three `done` states. The wrong claim is
/// deleted rather than reworded, per §9's "fix the doc or delete the claim".
///
/// ## SO WHY IS THE CLAMP HERE
///
/// Because `ProgressBeads` **deliberately does not clamp `current`** — its own doc
/// says so: "clamping would invent a 'current' bead that the caller never asked
/// for". So an out-of-range `current` is the one input that widget is documented
/// to let through, harmless *only* because `beadStates` compares `i === current`
/// for an `i` it generates itself and therefore never matches. A future widget
/// that indexed a row by `current` — to animate, to scroll, to announce "question
/// 3 of 3" — would read `3` on a three-bead row and reach past its end.
///
/// That is a forward-looking argument, not a present one, and it is labelled as
/// such. The alternative was deleting the function and passing
/// `current: reading.answeredQuestionCount` straight through, which renders
/// identically and is one line shorter; it was rejected because the *clamp* is the
/// part of the expression that is a decision, and a decision written as an
/// unclamped field read is a decision nobody can see.
int firstUnansweredQuestionIndex({required int answered, required int total}) {
  if (total <= 0) {
    return -1;
  }
  final int done = answered.clamp(0, total);
  return done >= total ? total - 1 : done;
}
