import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/domain/refreshed_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/refresh_session_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'quiz_bloc.freezed.dart';

/// Where `/quiz` is in its own lifecycle.
///
/// Five values, and each is a state a reader can tell apart from the others:
/// nothing asked, a question on screen, a submit in flight, a failure, and a
/// finished session.
///
/// ## WHY "SUBMITTING" IS NOT A `bool`, AND WHY THAT MATTERS HERE MORE THAN
/// ## ANYWHERE ELSE
///
/// The alternative — one `isLoading` — has to collapse this into one word, and any
/// word it picked would be a claim the reader cannot verify. The CTA must go dead
/// for the round trip and come back **graded** or **failed**, and a single flag
/// would leave the *failure* indistinguishable from still-busy: the button greyed
/// out, forever, with no message. §5's three dead ends (trap 10) are all failures a
/// reader can be shown, and none of them is "nothing happened".
enum QuizStatus {
  /// A read is open. Nothing is on screen.
  loading,

  /// A question is on screen and the reader can act.
  ready,

  /// A submit is in flight. The question stays on screen; the CTA goes dead.
  ///
  /// **The session is deliberately kept** while this is true, for
  /// `ReadingCubit`'s reason inverted: a reader who has chosen an option must not
  /// watch the option vanish because a socket took 400ms.
  submitting,

  /// The last operation failed. [QuizState.session] says whether there is still a
  /// screen underneath.
  failed,

  /// Every question has been closed and the reader is past the last one.
  complete,
}

/// What the quiz's one button offers.
///
/// ## WHY IT IS AN **ENUM ON THE STATE** AND NOT A `bool get canSubmit`
///
/// Because there are **five** distinct answers and a reader can tell them apart.
/// `QuizScreen.tsx:124-127` is the whole of the prototype's rule:
/// `disabled={!checked && !selected}` with `{checked ? 'Next question' : 'Check
/// answer'}`, and this is that plus the two states the prototype has no state for —
/// the last question, and a session with nothing to submit at all.
///
/// A `bool` plus a separate `String` label is the shape that gets the two out of
/// step, and the whole of §14 is about a control that says one thing and does
/// another. One enum has one answer per state.
enum QuizCta {
  /// Nothing chosen. The button is dead and the reader can do nothing.
  none,

  /// Grade the chosen letter.
  check,

  /// Move to the next question.
  next,

  /// Go to `/result`.
  finish,
}

/// Everything `/quiz` can be asked. Sealed, so an unhandled event is a compile error.
///
/// ## EACH EVENT IS A `freezed` CLASS, SO NONE OF THEM CAN FORGET ITS EQUALITY
///
/// The base used to extend `Equatable` and answer `props` with `const []` — the
/// same dead-by-construction getter `HomeEvent` had, defended for the same
/// reason. Both are gone: each event below derives its `==` from its constructor,
/// so the getter that could be forgotten does not exist. See [AuthEvent] for the
/// sealed base's shape and the one deliberate oddity in it.
@freezed
sealed class QuizEvent with _$QuizEvent {
  const QuizEvent._();
}

/// The screen is opening, in [language].
@freezed
final class QuizStarted extends QuizEvent with _$QuizStarted {
  /// Creates the start-up request.
  const QuizStarted(this.language) : super._();

  /// Which arm of the corpus to ask for.
  ///
  /// **On the event and not on the bloc**, for `HomeStarted`'s reason restated:
  /// `QuizBloc` is hand-registered once for the process, so a language fixed at
  /// construction would be the language at *launch* for the rest of the run — and
  /// Phase 9's language switch is a locale change, which is the second trigger
  /// this screen has to honour.
  final ReadingLanguage language;
}

/// The reader asked to try again, in [language].
///
/// ## AND THIS IS WHAT [RefreshSessionQuestions] IS FOR
///
/// The backend has **no `GET /readings/:id`**, so the only way to learn a question's
/// current `already_answered` is to re-read today's whole reading. A retry is where
/// that happens, and it is where the **fresh** flag is taken from: §5 trap 3 is that
/// submitting an already-answered question is a **409**, and `already_answered` is
/// mapped leniently (`today_reading_mapper.dart`: absent or non-`bool` reads as
/// "not proven answered"), so a flag already on hand is only ever as fresh as the
/// last fetch.
///
/// So a 409 is not merely reported — it is **recovered from**: the retry re-reads,
/// the question comes back flagged, and the reader is offered no way to submit it
/// again. `quiz_bloc_test.dart` asserts the fresh flag rather than the cached one.
///
/// **Rejected: a retry that re-runs `StartSession`.** It would build a **new**
/// session from the fresh payload, discarding the reader's selections — and a reader
/// who mistyped their email into a long question and pressed the wrong button would
/// lose the question they were answering. Rebasing keeps the selection and takes the
/// flag; `QuizSession.withQuestions` is where that decision lives.
///
/// [language] rides along for [QuizStarted]'s reason.
@freezed
final class QuizRetried extends QuizEvent with _$QuizRetried {
  /// Creates the retry request.
  const QuizRetried(this.language) : super._();

  /// Which arm of the corpus to ask for.
  final ReadingLanguage language;
}

/// The reader chose [letter] on the current question.
///
/// ## IT REPLACES, AND THAT IS THE PROTOTYPE'S RULE
///
/// `QuizScreen.tsx:89` is `onClick={() => !checked && setSelected(opt.letter)}` —
/// `selected` is one letter or `null`, never a set. So choosing `B` after `A` moves
/// the selection rather than adding to it, and `QuizOptionCard`'s `selected` state is
/// on **at most one** card at a time. A `Set<String>` would let a reader select two
/// options and then have to guess which one the submit sends.
@freezed
final class QuizOptionSelected extends QuizEvent with _$QuizOptionSelected {
  /// Creates the selection.
  const QuizOptionSelected(this.letter) : super._();

  /// The option's letter — a key of `Question.options`, sent to
  /// `POST /readings/:id/submit` verbatim.
  ///
  /// **Not validated against the map here**, and [ReadingRepository.submitAnswer]'s
  /// doc gives the whole argument: `submissions.routes.ts:7` accepts
  /// `z.string().min(1)` and `:35` documents the value as *"Selected option (A, B,
  /// C, D) or boolean"*, so the backend is the validator. In production this value
  /// can only be a key of the map, because the cards are built from its keys.
  final String letter;
}

/// The reader asked to grade the current question.
///
/// ## IT TAKES **NO ARGUMENT**, AND THAT IS THE SAFETY
///
/// The question is the **current** one, which is state. An argument would be a
/// second way to say which question, and the two could disagree — an event carrying
/// question two while the reader is looking at question one would grade something
/// they cannot see. §5 trap 10's first row is the client's own fabricated id being
/// rejected; a mismatch of this kind would be rejected too, but the reader would be
/// told about it on the wrong question.
@freezed
final class QuizAnswerChecked extends QuizEvent with _$QuizAnswerChecked {
  /// Creates the check request.
  const QuizAnswerChecked() : super._();
}

/// The reader asked to move on.
@freezed
final class QuizAdvanced extends QuizEvent with _$QuizAdvanced {
  /// Creates the advance request.
  const QuizAdvanced() : super._();
}

/// `/quiz`'s state: a session, a cursor, and the last graded answer.
///
/// ## THE CURSOR IS HERE AND NOT ON [QuizSession]
///
/// `QuizState.currentIndex` is state, `QuizSession` is the payload, and the reader
/// is the writer. Putting the index on the session would give one class two writers
/// — its own `withAnswerAt` and an "advance" — that would have to agree about what
/// advancing means mid-question. `ReadingCubit`'s single-writer argument applies.
///
/// ## NO GENERATED `copyWith`, FOR `HomeState`'s REASON
///
/// `@Freezed(copyWith: false)`. Every `emit` in `QuizBloc` builds the whole state
/// through the constructor, because the session and the cursor arrive together and
/// a partial writer could set one without the other — the shape this file's own
/// `_emitReading` doc calls "a writer that could set one without the other is the
/// shape that lets a cursor point at a session it was not counted from". A
/// generated sentinel `copyWith` is exactly that partial writer, so it is switched
/// off rather than left available and unused.
///
/// **`toString` is declared** so freezed does not generate one. The generated one
/// would be harmless on this class — no field here is a secret — but this
/// `toString` answers a question the generated one cannot (`answered:` of
/// `questionCount`), and `bloc_test` prints a state on every mismatch.
@Freezed(copyWith: false)
final class QuizState with _$QuizState {
  /// The state a cold launch starts in.
  const QuizState({
    this.status = QuizStatus.loading,
    this.session,
    this.currentIndex = 0,
    this.failure,
    this.lastResult,
  });

  /// Where the quiz is.
  final QuizStatus status;

  /// The questions and the reading they submit against, or `null` while loading and
  /// after a failed **read**.
  ///
  /// **`null` on a failed read and not "the last good one."** A reader looking at
  /// stale `already_answered` flags under an error message would be shown exactly the
  /// flags this feature exists to distrust. `ReadingCubit`'s rule, and the reason a
  /// failed *submit* behaves differently: a failed submit leaves the session alone,
  /// because the flags are not in question — the reader's own selection is.
  final QuizSession? session;

  /// Which answer is on screen. Clamped to `0 … questionCount - 1` by every writer.
  final int currentIndex;

  /// Why the last operation failed, or `null`.
  final Failure? failure;

  /// The most recent graded answer, or `null` before the first successful submit.
  ///
  /// ## THIS IS `/result`'s **ONLY** INPUT, AND WHY IT LIVES HERE
  ///
  /// `08-build-phases.md` §Phase 8: "`/result` reads the submit response held by
  /// `QuizBloc` and has no repository, no use case, and no API call of its own." So
  /// the response has to live somewhere after the reader leaves `/quiz`, and this
  /// field is it.
  ///
  /// **It is passed to `ResultPage` as a constructor argument rather than read back
  /// through the locator**, because `features/result/` importing
  /// `features/quiz/` is Gate 2 — the same wall `HomeCleared` could not cross in the
  /// other direction. The hand-off is therefore a required parameter, which also
  /// makes the constraint compile-enforced: **`/result` cannot be pushed without a
  /// graded answer**, and a reader with nothing submitted has no result screen. The
  /// honest consequence is a dead CTA on `/quiz` in exactly that case, and
  /// `QuizCta.none` is where it is expressed.
  final SubmitResult? lastResult;

  /// The answer on screen, or `null` with no session.
  QuizAnswer? get currentAnswer => session?.answerAt(currentIndex);

  /// Whether the reader has anything to do at all.
  bool get isEmpty => session?.isEmpty ?? true;

  /// What the one button offers. See [QuizCta].
  ///
  /// ## THE RULES, IN THE ORDER A READER MEETS THEM
  ///
  /// ```
  /// loading / submitting / failed / empty            → none
  /// a chosen letter on an open question              → check
  /// closed, and a question remains after it          → next
  /// closed, on the last, not yet finished            → next  (the press finishes)
  /// past the end, with a graded answer in hand       → finish
  /// closed, on the last, and nothing was submitted   → none   (see the dead end)
  /// ```
  ///
  /// The fourth row is the interesting one, and it is the live payload's own shape:
  /// §5's 2026-10-03 capture has one question with `already_answered: true`, so a
  /// reader arriving today lands on a closed question with no selection and no way to
  /// submit. The button says "next" — the only action that exists — and on the last
  /// such question it is `none` with the reason in the accessible name, because
  /// there is no `SubmitResult` for `/result` to be handed. **That dead end is real
  /// and is stated in `QuizPage`'s doc rather than papered over.**
  QuizCta get cta {
    if (status != QuizStatus.ready && status != QuizStatus.complete) {
      return QuizCta.none;
    }
    final QuizAnswer? answer = currentAnswer;
    if (answer == null) return QuizCta.none;
    if (answer.isAnswerable) return QuizCta.check;
    if (answer.isOpen) return QuizCta.none;
    if (!isLastQuestion) return QuizCta.next;
    // ## THE LAST TWO ARMS, AND THEY ARE **NOT** THE SAME QUESTION
    //
    // Both are "the reader is on the last question and it is closed". What differs
    // is whether the reader has **acknowledged the end**:
    //
    // | status | lastResult | cta | why |
    // | --- | --- | --- | --- |
    // | `ready` | non-null | **`next`** | there is still a press to make. `QuizScreen.tsx:127` labels *every* graded answer `Next question` and its press is `onFinish`, so advancing off the end **is** how the quiz finishes. |
    // | `complete` | non-null | `finish` | past the end. `/result` can be opened. |
    // | `ready` | `null` | `none` | nothing was submitted, so there is no `SubmitResult` for `ResultPage`'s **required** parameter. This is the live payload's shape — see the class doc's dead-end note. |
    //
    // **The first version returned `finish` for the second row too**, and the page
    // then labelled that button `Next question` while its action navigated — a §14
    // control that says one thing and does another, which is the whole reason
    // `QuizCta` is an enum on the state rather than a `bool` beside a `String`.
    // `quiz_page_test.dart` is what caught it: the button said "Next question", the
    // press did nothing, and `QuizStatus.complete` was **unreachable from the UI**.
    // **`lastResult` first, and the order is the point.** `complete` is reachable
    // from a session where nothing was submitted — a reading whose only question
    // arrives `already_answered` is `complete` after one press — so testing
    // `complete` first would hand out a `finish` the page cannot honour.
    if (lastResult == null) return QuizCta.none;
    return status == QuizStatus.complete ? QuizCta.finish : QuizCta.next;
  }

  /// Whether the CTA is dead because the session is **finished**, not because the
  /// reader has not chosen yet.
  ///
  /// ## 91. `QuizCta.none` IS **TWO STATES**, AND THE LABEL HAS TO TELL THEM APART
  ///
  /// `none` is returned from three places and they are not one situation:
  ///
  /// | # | reached when | the reader |
  /// | --- | --- | --- |
  /// | 1 | `status` is loading or failed | is not looking at a quiz |
  /// | 2 | the answer `isOpen` — nothing chosen yet | has a pending action: choose, then check |
  /// | 3 | the answer is closed, it is the last, and `lastResult == null` | is **done**. Nothing can be submitted and nothing was |
  ///
  /// `_Cta` renders one label for all three, and it was `checkAnswer` — which is
  /// accurate for (2) and **false** for (3). On the live payload (3) is the first
  /// frame a reader sees: §5 trap 3's capture has one question with
  /// `already_answered: true`, so the button reads "Check answer", the one action the
  /// screen cannot perform, and every other thing on screen is scripture the reader
  /// already has. Decision 85 put the reason in the **accessible** name on the
  /// reasoning that "the reader who cannot see the button is the one who needs the
  /// reason" — which holds only where a second channel exists, and here the sighted
  /// reader has none.
  ///
  /// So the visible label becomes [QuizStrings.unavailableSuffix] for (3), and stays
  /// the prototype's for (2). That is a written string on a state the prototype does
  /// not have, which is the same trade `finish` already makes.
  ///
  /// **Arm (1) is excluded deliberately**: `currentAnswer == null` means there is no
  /// question, so there is no state to name, and `_Cta` is not built for it anyway —
  /// `QuizPage._quiz` returns the empty state first.
  ///
  /// **Rejected: deriving it from `answeredCount == questionCount`.** That is the
  /// predicate decision 87 removed from `reason` for exactly this reason — it is a
  /// payload claim that is true of every finished session and of many unfinished
  /// ones, and it cannot distinguish (2) from (3) when a reader has answered some
  /// questions and has not chosen on this one.
  ///
  /// **Rejected: `label` for every `none` arm.** That would tell a reader who has
  /// simply not chosen yet that there is no answer to show — decision 87's argument,
  /// one level up: the sentence would be about a missing *choice* while describing a
  /// missing *answer*.
  ///
  /// **Not changed: `next` on a closed, ungraded question with a question after
  /// it.** The label there is "Next question" and it is **true** — the press advances.
  /// The defect above is specifically a control that names an action it cannot
  /// perform, and that one performs one.
  bool get isSessionFinished {
    final QuizAnswer? answer = currentAnswer;
    return cta == QuizCta.none && answer != null && !answer.isOpen;
  }

  /// Whether [currentAnswer] is the last one there is.
  bool get isLastQuestion {
    final QuizSession? session = this.session;
    if (session == null || session.questionCount == 0) return true;
    return currentIndex >= session.questionCount - 1;
  }

  @override
  String toString() =>
      'QuizState(${status.name}, index: $currentIndex, '
      'answered: ${session?.answeredCount ?? 0}/${session?.questionCount ?? 0})';
}

/// `/quiz`'s state machine.
///
/// ## IT TAKES THREE **USE CASES**, NOT THE REPOSITORY
///
/// §3's DIP row: this file names no adapter, no `Dio` and no mapper. It is also
/// what makes the two uses of the port distinguishable at the call site —
/// [StartSession] on entry, [RefreshSessionQuestions] on a retry — which is the
/// whole of why the second exists rather than being the first one again.
///
/// ## AND IT IS HAND-REGISTERED, WHICH IS THE **FIFTH** TIME
///
/// `lib/app/di/navigation_injection.dart` holds it, for the mechanism its own doc
/// spells out: `QuizBloc extends Bloc`, `bloc` is a transitive dependency §8.4 will
/// not promote, and `package:flutter_bloc/flutter_bloc.dart` re-exports Flutter's
/// widget layer — so there is no spelling of "register this bloc" that keeps
/// `injection.dart`'s import graph Flutter-free. A `registerSingleton`, like the
/// other four, because a factory would hand out a **second** bloc with its own
/// stream and its own `lastResult`, and `/result` is handed that field.
class QuizBloc extends Bloc<QuizEvent, QuizState> {
  /// Drives `/quiz`.
  QuizBloc({
    required StartSession startSession,
    required RefreshSessionQuestions refreshSessionQuestions,
    required SubmitAnswer submitAnswer,
  }) : this._(startSession, refreshSessionQuestions, submitAnswer);

  /// The real constructor. See the redirect's doc for why it is private.
  QuizBloc._(
    this._startSession,
    this._refreshSessionQuestions,
    this._submitAnswer,
  ) : super(const QuizState()) {
    on<QuizStarted>(_onStarted);
    on<QuizRetried>(_onRetried);
    on<QuizOptionSelected>(_onSelected);
    on<QuizAnswerChecked>(_onChecked);
    on<QuizAdvanced>(_onAdvanced);
  }

  final StartSession _startSession;
  final RefreshSessionQuestions _refreshSessionQuestions;
  final SubmitAnswer _submitAnswer;

  /// Loads today's questions for [event]'s arm.
  Future<void> _onStarted(QuizStarted event, Emitter<QuizState> emit) async {
    // ## `lastResult` IS READ **BEFORE** THE LOADING EMIT, AND THAT IS THE POINT
    //
    // This handler used to emit `const QuizState()` and then `_emitReading` built a
    // state carrying neither the result nor the index — so a `QuizStarted` arriving
    // after a grade dropped `lastResult` on the floor. That is not a corner case:
    // `_QuizBodyState.didChangeDependencies` re-dispatches `QuizStarted` on every
    // locale change, so **switching language is what sends this event**, and a reader
    // looking at a live "See results" button was moved to `QuizCta.none` — the dead
    // end — with no reason on screen.
    //
    // `_onRetried`'s doc states the rule this now obeys: *"if the handler reads what it
    // needs, it reads it **first**."* A `String? = null` parameter cannot express
    // "clear it", so the field that must survive a whole-state emit is captured before
    // the emit rather than read off `state` afterwards.
    //
    // **What this does NOT fix, stated rather than implied.** `_onStarted` also
    // **rebuilds the session**, because a fresh start refetches a language-specific
    // payload, so the cursor returns to question one with nothing selected and
    // `QuizState.cta`'s `isOpen` arm still wins. A reader who switches language is
    // therefore still on `QuizCta.none` — but with the field in hand there is a press
    // that reaches `/result` again, and `QuizState.cta`'s table says the terminal CTA
    // is `finish` *only* when `lastResult` is there. Without it, no press could ever
    // open the results for the rest of the session.
    //
    // **Rejected: making `QuizStarted` rebase instead of rebuild.** That is
    // `_onRetried`'s two arms with a different trigger, and it would change what a
    // *first* start means — `StartSession` exists to build a session, and a handler
    // that sometimes rebases is the two-writers shape this file's own docs refuse.
    // Recorded for Phase 9, where the language switch is a shipped feature.
    final SubmitResult? before = state.lastResult;
    emit(QuizState(status: QuizStatus.loading, lastResult: before));
    _emitReading(await _startSession(event.language), before, emit);
  }

  /// Re-reads, and takes the fresh `already_answered` flags off it.
  ///
  /// ## SILENT WHEN NOTHING FAILED, AND THE SILENCE IS THE ASSERTION
  ///
  /// `home_bloc_test.dart` pins the same property for `HomeRetried` and gives the
  /// reason: "nothing to retry" and "the retry silently dropped its event" are
  /// otherwise the same observable behaviour. Here it is also a **request** question
  /// — a retry that re-read on every accidental dispatch would put a `GET` on the
  /// wire for nothing.
  Future<void> _onRetried(QuizRetried event, Emitter<QuizState> emit) async {
    if (state.status != QuizStatus.failed) return;

    // ## THE SESSION AND THE INDEX ARE CAPTURED **BEFORE** THE LOADING EMIT
    //
    // This was a real defect, and it is the same shape as recorded decision 15's
    // dead branch: `emit(state.withSection(status: loading))` **replaces** `state`,
    // and a handler that reads `state` after its own emit is reading the state it
    // just wrote. The loading emit carries no session, so every later read of
    // `state.session` was `null` — the re-read went out, the fresh flags came back,
    // and the reader's selection was dropped on the floor. Measured by
    // `quiz_bloc_test.dart`'s `the reader's own choice survives the re-read`.
    //
    // `HomeBloc._onRetried` has the same emit-then-read shape and gets away with it
    // only because `withSection` leaves the untouched section's data on the new
    // state; here the loading emit is a whole new `QuizState`, so nothing survives
    // it. The rule is the one `AuthState`'s doc states about a single
    // writer: if the handler reads what it needs, it reads it **first**.
    final QuizSession? before = state.session;
    final int beforeIndex = state.currentIndex;

    emit(QuizState(status: QuizStatus.loading, lastResult: state.lastResult));

    final Result<RefreshedOutcome> refreshed = await _refreshSessionQuestions(
      event.language,
    );
    switch (refreshed) {
      case Success<RefreshedOutcome>(:final RefreshedOutcome value):
        emit(
          QuizState(
            status: QuizStatus.ready,
            // **Rebased onto the old session when there is one, and built fresh when
            // there is not.** The second arm is the retry after a failed *start*:
            // `before` is `null` there, and the first version of this handler used
            // `state.session?.withQuestions(…)` alone, so it re-read, took the fresh
            // flags — and threw them away, leaving `ready` with no session. A `GET`
            // on the wire, two states emitted, and nothing on screen.
            // `quiz_bloc_test.dart` asserts the session is back, in the failing
            // direction, because "the retry happened" is not the claim — "the retry
            // produced a session" is.
            session: before == null
                ? QuizSession.fromQuestions(
                    readingId: value.readingId,
                    questions: value.questions,
                  )
                : before.withQuestions(
                    readingId: value.readingId,
                    questions: value.questions,
                  ),
            // **Clamped.** A re-read can come back **shorter** than the session:
            // `today_reading_mapper.dart` *skips* an unreadable question rather than
            // refusing the passage (recorded decision 50), so a payload of four
            // unreadable questions reports none. Clamping is cheaper than an index
            // that points at nothing, and `answerAt` is total anyway — so this is
            // belt and braces, and the comment is here because the belt is the thing
            // a reader would otherwise delete.
            currentIndex: _clamp(beforeIndex, value.questionCount),
            lastResult: state.lastResult,
          ),
        );
      case FailureResult<RefreshedOutcome>(:final Failure failure):
        // **The session is dropped**, unlike a failed submit. A failed *read* means
        // the flags on screen are the ones we cannot vouch for any more, and
        // `ReadingCubit`'s rule is that a stale passage must not sit under an error.
        emit(QuizState(status: QuizStatus.failed, failure: failure));
    }
  }

  /// Records the reader's letter, and issues **no** request.
  ///
  /// Selecting is local (`QuizScreen.tsx:89`'s `setSelected`); only `check` reaches
  /// the network. The `isOpen` guard is the same one `check` uses — a closed
  /// question has no selectable options, so this only ever fires if an event arrives
  /// from somewhere the card's `enabled` does not govern.
  void _onSelected(QuizOptionSelected event, Emitter<QuizState> emit) {
    final QuizAnswer? answer = state.currentAnswer;
    if (state.status != QuizStatus.ready || answer == null) return;
    if (!answer.isOpen) return;
    // `isAnswerable` already excludes a re-tap of the same letter, so the unchanged
    // state is never emitted — §4's "no emit when unchanged".
    if (!answer.isAnswerable && answer.selectedLetter == event.letter) return;
    emit(
      QuizState(
        status: QuizStatus.ready,
        session: state.session!.withAnswerAt(
          state.currentIndex,
          answer.withSelection(event.letter),
        ),
        currentIndex: state.currentIndex,
        lastResult: state.lastResult,
      ),
    );
  }

  /// Grades the current answer.
  ///
  /// ## THE 409 IS **PREVENTED HERE**, AND THE GATE IS `isAnswerable`
  ///
  /// §5 trap 3: a duplicate submit is
  /// `409 This question has already been submitted by this user.` The client must not
  /// let the reader walk into a conflict it could have prevented, and the
  /// prevention has to be here as well as on the card: an event can arrive from a
  /// keyboard shortcut, a test, or a future gesture, and none of them consults
  /// `QuizOptionCard.enabled`.
  ///
  /// `isAnswerable` is false for **three** distinct reasons and each is a real
  /// "do not send this": nothing chosen, already graded in this session, or the wire
  /// said it is already answered. **Checking a graded question twice is the exact
  /// shape of the 409** — a reader tapping the button twice on a slow connection is
  /// the most likely way to produce one — so it is refused rather than sent and
  /// caught.
  ///
  /// ## AND A FAILED SUBMIT **KEEPS** THE SESSION, WHERE A FAILED READ DOES NOT
  ///
  /// The reader's selection is still true and the passage has not changed, so a
  /// blank screen with an error would hide a question they were mid-way through. It
  /// is the inverse of [QuizState.session]'s rule, and the reason for the asymmetry
  /// is exactly which claim is in doubt: a failed read invalidates the *flags*, a
  /// failed submit invalidates nothing the reader can see.
  Future<void> _onChecked(
    QuizAnswerChecked event,
    Emitter<QuizState> emit,
  ) async {
    final QuizAnswer? answer = state.currentAnswer;
    if (state.status != QuizStatus.ready || answer == null) return;
    if (!answer.isAnswerable) return;

    final QuizSession session = state.session!;
    emit(
      QuizState(
        status: QuizStatus.submitting,
        session: session,
        currentIndex: state.currentIndex,
        lastResult: state.lastResult,
      ),
    );

    final Result<SubmitResult> result = await _submitAnswer(
      SubmitAnswerParams(
        readingId: session.readingId,
        questionId: answer.question.id,
        answer: answer.selectedLetter!,
      ),
    );

    switch (result) {
      case Success<SubmitResult>(:final SubmitResult value):
        emit(
          QuizState(
            status: QuizStatus.ready,
            session: session.withAnswerAt(
              state.currentIndex,
              answer.withVerdict(value),
            ),
            currentIndex: state.currentIndex,
            lastResult: value,
          ),
        );
      case FailureResult<SubmitResult>(:final Failure failure):
        emit(
          QuizState(
            status: QuizStatus.failed,
            session: session,
            currentIndex: state.currentIndex,
            failure: failure,
            lastResult: state.lastResult,
          ),
        );
    }
  }

  /// Moves the cursor on by exactly one.
  ///
  /// ## THE `isOpen` GUARD IS WHAT MAKES "NEXT" NOT "SKIP"
  ///
  /// The mutation this prevents is an advance that ignored the question's own state:
  /// a reader who had chosen but not checked would be carried past an unanswered
  /// question, and `answeredCount` would be short at the end with nothing on screen
  /// to explain the gap. The guard is the **one** question — "is this question still
  /// the reader's to answer?" — and it has exactly the two answers that matter.
  ///
  /// A **closed** question is advanceable, and must be: the live payload's question
  /// arrives answered, so a reader who cannot move past it is stuck on a screen with
  /// no working control at all.
  ///
  /// Off the end it emits [QuizStatus.complete] and **clamps the index to the last
  /// answer** — an index past the end has no `QuizAnswer` to render, and the
  /// alternative is a screen that throws on its own state.
  void _onAdvanced(QuizAdvanced event, Emitter<QuizState> emit) {
    if (state.status != QuizStatus.ready &&
        state.status != QuizStatus.complete) {
      return;
    }
    final QuizAnswer? answer = state.currentAnswer;
    if (answer == null) return;
    if (answer.isOpen) return;

    final QuizSession? session = state.session;
    if (session == null) return;

    final int next = state.currentIndex + 1;
    final int clamped = _clamp(next, session.questionCount);
    final bool past = next >= session.questionCount;

    emit(
      QuizState(
        status: past ? QuizStatus.complete : QuizStatus.ready,
        session: session,
        currentIndex: clamped,
        lastResult: state.lastResult,
      ),
    );
  }

  /// Emits `ready` with [value] as the session, or `failed` with it.
  ///
  /// **One writer, and that is why the cursor is passed.** `HomeBloc`'s doc gives the
  /// argument for a single writer per state — a `String? = null` parameter cannot
  /// express "clear it", so a field that must be cleared is written by a method that
  /// cannot get it wrong. Here the session and the index always arrive together, and a
  /// writer that could set one without the other is the shape that lets a cursor
  /// point at a session it was not counted from.
  ///
  /// [lastResult] is a **parameter and not read off `state`**, for the reason
  /// [_onStarted]'s doc gives: this method is called after an `await`, by which time
  /// `state` is whatever the last emit left behind, and the whole point is that the
  /// result must not be re-read from a state this call is in the middle of replacing.
  void _emitReading(
    Result<QuizSession> result,
    SubmitResult? lastResult,
    Emitter<QuizState> emit,
  ) {
    emit(
      result.fold<QuizState>(
        onSuccess: (QuizSession value) => QuizState(
          status: QuizStatus.ready,
          session: value,
          lastResult: lastResult,
        ),
        onFailure: (Failure failure) =>
            QuizState(status: QuizStatus.failed, failure: failure),
      ),
    );
  }

  /// [index] clamped into `0 … count - 1`, and `0` for an empty list.
  ///
  /// **A helper and not `clamp`'s own contract**, because `int.clamp(0, -1)` throws
  /// for an empty range — and an empty session is reachable (`questions: []` maps,
  /// it is not refused). `count == 0 → 0` is the answer: `answerAt(0)` is `null` and
  /// every reader of it already handles `null`.
  static int _clamp(int index, int count) =>
      count <= 0 ? 0 : index.clamp(0, count - 1);
}

/// The two values [RefreshSessionQuestions] hands back, named at the call site.
///
/// **A private alias rather than a use of `RefreshedQuestions` directly**, and the
/// reason is worth one line: this file is the reader of that type's shape, and
/// naming the outcome it depends on is what makes "this handler reads a `readingId`
/// and a `questions` list" a sentence you can check rather than infer. It adds one
/// line and no behaviour.
typedef RefreshedOutcome = RefreshedQuestions;
