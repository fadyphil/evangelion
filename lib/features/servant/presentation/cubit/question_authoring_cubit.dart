import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/usecases/commit_questions.dart';
import 'package:evangelion/features/servant/domain/usecases/generate_ai_draft.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_authoring_cubit.freezed.dart';

/// Where `/servant/questions` is in its own lifecycle.
///
/// Four values, and the two failure arms are **named after the request that
/// failed** rather than merged into one. The screen has two actions — "ask for
/// a draft" and "commit" — and a retry control has to know which one to repeat,
/// so the two failures are two states and not one state plus a memory.
///
/// "loading" is **not** "no data", and an editor that has not been written is
/// neither a request in flight nor a request that failed.
enum QuestionAuthoringStatus {
  /// The editor is on screen. There may or may not be a question in it.
  ready,

  /// A request is open.
  working,

  /// The AI draft request failed. [QuestionAuthoringState.failure] is non-null.
  draftFailed,

  /// The commit failed. [QuestionAuthoringState.failure] is non-null.
  commitFailed,
}

/// Why the question form refused to commit.
enum QuestionAuthoringFormError {
  /// No reading id was given.
  ///
  /// **There is no endpoint that lists a cohort's scheduled readings** — the
  /// design spec §6.2 says so and the backend agrees: the only route that
  /// creates a reading is the schedule route, and it answers with the id. So
  /// the id is either the one the schedule answered with or one the admin
  /// typed, and a form that committed without one would send a body the server
  /// refuses (`admin.routes.ts:36` types `reading_id` as `z.string().min(1)`).
  missingReadingId,

  /// One of the two prompts is empty.
  ///
  /// The commit schema types both as `z.string().min(1)`
  /// (`admin.routes.ts:39-40`).
  emptyPrompt,

  /// No correct answer was given.
  ///
  /// The commit schema types it as `z.string().min(1)`
  /// (`admin.routes.ts:45`).
  emptyCorrectAnswer,

  /// The points or the order is not a whole number.
  ///
  /// **The commit schema's own rule**, `admin.routes.ts:46-47`: both are
  /// `z.number().int()`, and the client's defaults — ten points, order one —
  /// are the schema's defaults rather than this client's.
  invalidNumber,
}

/// What `/servant/questions` is showing.
///
/// ## AND WHY THE `copyWith` IS **OFF**
///
/// For `AuthState`'s reason: freezed's generated `copyWith` is a *partial*
/// writer, and this state has a cross-field invariant — the status, the
/// failure, the commit result and the form error must agree with each other —
/// which a partial writer cannot express. `state.copyWith(failure: f)` would
/// leave the status saying everything is fine.
///
/// So every `emit` below builds the **whole** state, and there is no second
/// spelling of that sentence for a writer to disagree with. `QuizState` is the
/// precedent: five fields and eleven inline full constructors.
///
/// **And the invariant is four sentences**, one per pair:
///
/// * a **failed** status carries a failure, and a `ready` or `working` one
///   carries none — so the status always names the request that failed, and
///   `retry` can repeat that one and not the other;
/// * a **form error** belongs to a `ready` state, because the form refuses
///   before it asks;
/// * a **commit result** belongs to a `ready` state, because the commit
///   answered.
///
/// An **edit** keeps the first of those pairs whole — the failure and the arm
/// that names it — and drops the second and third, which are about the
/// question as it **was**. The cubit's own doc says why.
@Freezed(copyWith: false)
final class QuestionAuthoringState with _$QuestionAuthoringState {
  /// A state on the given arm.
  ///
  /// **`status` is required and not defaulted**, and that is the whole of the
  /// reason: a defaulted status would let a writer leave it out, and a writer
  /// that leaves the status out is a writer that did not say which arm of the
  /// lifecycle it is on. Every construction below names it.
  const QuestionAuthoringState({
    required this.status,
    this.readingId = '',
    this.draft,
    this.commitResult,
    this.failure,
    this.formError,
    this.pointsText = '10',
    this.sortOrderText = '1',
  });

  /// Which lifecycle arm this is.
  final QuestionAuthoringStatus status;

  /// The reading the question belongs to.
  final String readingId;

  /// The question being edited, or `null` while there is none.
  ///
  /// **`null` is the editor's empty state** and not a hole in the state: the
  /// page draws the empty editor, and the first thing the admin writes
  /// creates the draft. The entity's own `min(1)` rules are the **commit**
  /// rules, and the cubit enforces them on the way out — see
  /// [QuestionAuthoringFormError].
  final QuestionDraft? draft;

  /// What the server answered, or `null`.
  final CommitResult? commitResult;

  /// Why the request failed, or `null`.
  final Failure? failure;

  /// Why the form refused to commit, or `null`.
  final QuestionAuthoringFormError? formError;

  /// The point value, as the admin typed it.
  ///
  /// **The text is the truth, and the draft's number is its last parsed
  /// value.** The two are one fact in two shapes, and the rule is which one
  /// answers: a half-typed `1` on its way to `12` is a string and not a whole
  /// number, so the text is what the form holds and the number is what the
  /// draft last understood. The commit parses the text and **refuses** when it
  /// cannot, so a number is never sent that the field does not show.
  final String pointsText;

  /// The question's place among its reading's questions, as the admin typed it.
  ///
  /// [pointsText] for the reason.
  final String sortOrderText;
}

/// Drives `/servant/questions` through [requestDraft] and [commit].
///
/// ## AND IT TAKES ITS **USE CASES**, NEVER ITS REPOSITORY
///
/// §3's DIP row, and its mirror: no presentation file names a repository. The
/// cubit depends on [GenerateAiDraft] and [CommitQuestions], so a test drives
/// the real use cases over a fake port.
///
/// ## AND AN **EDIT** CHANGES THE QUESTION AND NOTHING ELSE
///
/// Every writer below that answers something the reader did is an **edit**,
/// and an edit has **one** rule, in four parts:
///
/// * **The server's failure stays.** It is the server's answer about the
///   request it answered, and the reader correcting a field is not the server
///   changing its mind. A refusal that vanished because the reader typed
///   would be a refusal the reader never got to read — and the page's own
///   one-sided sync is a write the page made on purpose, so it is not an
///   edit either.
/// * **The status stays.** The status names **which** request failed, and
///   [retry] reads it to know which request to repeat — so a failure that
///   kept its message but lost its arm would be retried as the wrong request.
/// * **The form's own refusal goes.** The reader is correcting it, and a
///   message that outlives the field it is about is a message about something
///   else.
/// * **The commit result goes.** It described the question as it **was**.
///
/// **A NEW REQUEST REPLACES THE OUTCOME.** The `working` state and the two
/// answers that follow it belong to the attempt that is being made now, and
/// they carry no failure from the last one.
class QuestionAuthoringCubit extends Cubit<QuestionAuthoringState> {
  /// Drives the editor over [generateAiDraft] and [commitQuestions].
  QuestionAuthoringCubit({
    required this.generateAiDraft,
    required this.commitQuestions,
  }) : super(
         const QuestionAuthoringState(status: QuestionAuthoringStatus.ready),
       );

  /// The AI draft request.
  final GenerateAiDraft generateAiDraft;

  /// The commit request.
  final CommitQuestions commitQuestions;

  /// The blank question the editor starts from.
  ///
  /// **The commit schema's own defaults**, `admin.routes.ts:46-48` — ten
  /// points, order one, approved — and not this client's invention. The
  /// entity's doc says the same thing about the three defaulted fields, and
  /// the reason they are on the entity rather than at the wire is that a
  /// draft is committable without a conversion.
  static const QuestionDraft blankDraft = QuestionDraft(
    type: QuestionType.mcq,
    promptAr: '',
    promptEn: '',
    options: <String, QuestionOption>{},
    correctAnswer: '',
    pointsValue: 10,
    sortOrder: 1,
    isApproved: true,
  );

  /// The reading id changed.
  void setReadingId(String id) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: id,
      draft: state.draft,
      failure: state.failure,
      pointsText: state.pointsText,
      sortOrderText: state.sortOrderText,
    ),
  );

  /// The question's type changed.
  void setType(QuestionType type) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: state.readingId,
      draft: (state.draft ?? blankDraft).copyWith(type: type),
      failure: state.failure,
      pointsText: state.pointsText,
      sortOrderText: state.sortOrderText,
    ),
  );

  /// The Arabic prompt changed.
  void setPromptAr(String text) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: state.readingId,
      draft: (state.draft ?? blankDraft).copyWith(promptAr: text),
      failure: state.failure,
      pointsText: state.pointsText,
      sortOrderText: state.sortOrderText,
    ),
  );

  /// The English prompt changed.
  void setPromptEn(String text) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: state.readingId,
      draft: (state.draft ?? blankDraft).copyWith(promptEn: text),
      failure: state.failure,
      pointsText: state.pointsText,
      sortOrderText: state.sortOrderText,
    ),
  );

  /// The correct answer changed.
  void setCorrectAnswer(String answer) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: state.readingId,
      draft: (state.draft ?? blankDraft).copyWith(correctAnswer: answer),
      failure: state.failure,
      pointsText: state.pointsText,
      sortOrderText: state.sortOrderText,
    ),
  );

  /// The point value changed.
  void setPointsText(String text) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: state.readingId,
      draft: _draftWithPoints(text),
      failure: state.failure,
      pointsText: text,
      sortOrderText: state.sortOrderText,
    ),
  );

  /// The question's place among its reading's questions changed.
  void setSortOrderText(String text) => emit(
    QuestionAuthoringState(
      status: state.status,
      readingId: state.readingId,
      draft: _draftWithOrder(text),
      failure: state.failure,
      pointsText: state.pointsText,
      sortOrderText: text,
    ),
  );

  /// The draft, with the point value the text last parsed to.
  ///
  /// **The draft keeps the last value it understood**, so a half-typed number
  /// does not become the draft's number. The commit parses the text again and
  /// refuses when it cannot, so nothing half-typed is ever sent.
  QuestionDraft _draftWithPoints(String text) {
    final QuestionDraft draft = state.draft ?? blankDraft;
    final int? points = int.tryParse(text.trim());
    if (points == null) return draft;
    return draft.copyWith(pointsValue: points);
  }

  /// The draft, with the order the text last parsed to.
  QuestionDraft _draftWithOrder(String text) {
    final QuestionDraft draft = state.draft ?? blankDraft;
    final int? order = int.tryParse(text.trim());
    if (order == null) return draft;
    return draft.copyWith(sortOrder: order);
  }

  /// An option was added, under [letter].
  ///
  /// **The letter is the caller's**, because the page is the one that owns the
  /// option's editor and its controllers, and the first free letter is a fact
  /// about the editor rather than about the question. A letter that is already
  /// in use is refused, so a second tap on "add" cannot overwrite an option.
  void addOption(String letter) {
    final QuestionDraft draft = state.draft ?? blankDraft;
    if (draft.options.containsKey(letter)) return;
    emit(
      QuestionAuthoringState(
        status: state.status,
        readingId: state.readingId,
        draft: draft.copyWith(
          options: <String, QuestionOption>{
            ...draft.options,
            letter: const QuestionOption(ar: '', en: ''),
          },
        ),
        failure: state.failure,
        pointsText: state.pointsText,
        sortOrderText: state.sortOrderText,
      ),
    );
  }

  /// The option under [letter] was removed.
  void removeOption(String letter) {
    final QuestionDraft? draft = state.draft;
    if (draft == null) return;
    if (!draft.options.containsKey(letter)) return;
    emit(
      QuestionAuthoringState(
        status: state.status,
        readingId: state.readingId,
        draft: draft.copyWith(
          options: <String, QuestionOption>{
            for (final MapEntry<String, QuestionOption> entry
                in draft.options.entries)
              if (entry.key != letter) entry.key: entry.value,
          },
        ),
        failure: state.failure,
        pointsText: state.pointsText,
        sortOrderText: state.sortOrderText,
      ),
    );
  }

  /// One of an option's two texts changed.
  ///
  /// [arabic] says **which** of the option's two texts changed, because an
  /// option holds a pair (`admin.routes.ts:41-44`) and a method that took one
  /// string could not say which half it meant.
  void setOptionText(
    String letter, {
    required bool arabic,
    required String text,
  }) {
    final QuestionDraft? draft = state.draft;
    if (draft == null) return;
    final QuestionOption? option = draft.options[letter];
    if (option == null) return;
    emit(
      QuestionAuthoringState(
        status: state.status,
        readingId: state.readingId,
        draft: draft.copyWith(
          options: <String, QuestionOption>{
            ...draft.options,
            letter: arabic
                ? option.copyWith(ar: text)
                : option.copyWith(en: text),
          },
        ),
        failure: state.failure,
        pointsText: state.pointsText,
        sortOrderText: state.sortOrderText,
      ),
    );
  }

  /// Asks the server for a drafted question about the reading.
  ///
  /// ## AND THE DRAFT **REPLACES** THE QUESTION ON SCREEN
  ///
  /// It is a draft, and the admin edits it after — so a hand-written question
  /// that was on screen is replaced, not merged. The replacement is the
  /// server's answer and not a merge of two answers.
  Future<void> requestDraft() async {
    final String readingId = state.readingId.trim();
    if (readingId.isEmpty) {
      _refuse(QuestionAuthoringFormError.missingReadingId);
      return;
    }
    if (state.status == QuestionAuthoringStatus.working) return;

    emit(
      QuestionAuthoringState(
        status: QuestionAuthoringStatus.working,
        readingId: state.readingId,
        draft: state.draft,
        pointsText: state.pointsText,
        sortOrderText: state.sortOrderText,
      ),
    );
    final Result<QuestionDraft> result = await generateAiDraft(
      GenerateAiDraftParams(
        readingId: readingId,
        // The type of the question on screen, or the schema's own default.
        // The AI route accepts two of the three types
        // (`ai.routes.ts:10`), and the adapter is the one that refuses the
        // third — see `DioServantAdminRepository.generateAiDraft`.
        type: state.draft?.type ?? QuestionType.mcq,
      ),
    );
    switch (result) {
      case Right<Failure, QuestionDraft>(:final QuestionDraft value):
        emit(
          QuestionAuthoringState(
            status: QuestionAuthoringStatus.ready,
            readingId: state.readingId,
            draft: value,
            pointsText: state.pointsText,
            sortOrderText: state.sortOrderText,
          ),
        );
      case Left<Failure, QuestionDraft>(value: final Failure failure):
        emit(
          QuestionAuthoringState(
            status: QuestionAuthoringStatus.draftFailed,
            readingId: state.readingId,
            draft: state.draft,
            failure: failure,
            pointsText: state.pointsText,
            sortOrderText: state.sortOrderText,
          ),
        );
    }
  }

  /// Commits the question on screen.
  ///
  /// ## AND THE **REFUSAL** COMES FIRST
  ///
  /// The commit schema's own `min(1)` rules are checked here, and the request
  /// is not made when one of them is broken: the server would have refused it
  /// with a body that names a field the admin never saw.
  Future<void> commit() async {
    final String readingId = state.readingId.trim();
    if (readingId.isEmpty) {
      _refuse(QuestionAuthoringFormError.missingReadingId);
      return;
    }
    final QuestionDraft? draft = state.draft;
    if (draft == null ||
        draft.promptAr.trim().isEmpty ||
        draft.promptEn.trim().isEmpty) {
      _refuse(QuestionAuthoringFormError.emptyPrompt);
      return;
    }
    if (draft.correctAnswer.trim().isEmpty) {
      _refuse(QuestionAuthoringFormError.emptyCorrectAnswer);
      return;
    }
    final int? points = int.tryParse(state.pointsText.trim());
    final int? order = int.tryParse(state.sortOrderText.trim());
    if (points == null || order == null) {
      _refuse(QuestionAuthoringFormError.invalidNumber);
      return;
    }
    if (state.status == QuestionAuthoringStatus.working) return;

    emit(
      QuestionAuthoringState(
        status: QuestionAuthoringStatus.working,
        readingId: state.readingId,
        draft: state.draft,
        pointsText: state.pointsText,
        sortOrderText: state.sortOrderText,
      ),
    );
    final Result<CommitResult> result = await commitQuestions(
      CommitQuestionsParams(
        readingId: readingId,
        questions: <QuestionDraft>[draft],
      ),
    );
    switch (result) {
      case Right<Failure, CommitResult>(:final CommitResult value):
        emit(
          QuestionAuthoringState(
            status: QuestionAuthoringStatus.ready,
            readingId: state.readingId,
            draft: state.draft,
            commitResult: value,
            pointsText: state.pointsText,
            sortOrderText: state.sortOrderText,
          ),
        );
      case Left<Failure, CommitResult>(value: final Failure failure):
        emit(
          QuestionAuthoringState(
            status: QuestionAuthoringStatus.commitFailed,
            readingId: state.readingId,
            draft: state.draft,
            failure: failure,
            pointsText: state.pointsText,
            sortOrderText: state.sortOrderText,
          ),
        );
    }
  }

  /// Asks again, for the same thing.
  ///
  /// **The failed request is named by the status**, which is why the two
  /// failures are two arms: a retry control that repeated the wrong request
  /// would answer a question the admin did not ask again.
  Future<void> retry() async {
    if (state.status == QuestionAuthoringStatus.commitFailed) {
      await commit();
      return;
    }
    await requestDraft();
  }

  /// The refusal, and nothing else.
  ///
  /// **A NEW ATTEMPT, AND THE OUTCOME BELONGS TO IT.** The form refused
  /// before the request was made, so this is a fresh answer about a fresh
  /// attempt — and it replaces the last one, the server's failure included.
  /// The server's failure is *not* dropped by an **edit** (see the class
  /// doc), because an edit is not an attempt.
  void _refuse(QuestionAuthoringFormError error) => emit(
    QuestionAuthoringState(
      status: QuestionAuthoringStatus.ready,
      readingId: state.readingId,
      draft: state.draft,
      formError: error,
      pointsText: state.pointsText,
      sortOrderText: state.sortOrderText,
    ),
  );
}
