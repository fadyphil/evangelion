import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_cubit.freezed.dart';

/// Where one part of `/reading` is in its own lifecycle.
///
/// Three values, and `HomeSectionStatus`'s doc gives the argument that applies here
/// verbatim: "loading" is **not** "no data", and a two-value enum would have to
/// encode it as one — which is how a screen ends up unable to tell "still asking"
/// from "asked and there was nothing".
enum ReadingStatus {
  /// The request is open. Nothing is on screen for the passage.
  loading,

  /// An answer is in hand. [ReadingState.scripture] is non-null.
  ready,

  /// The request failed. [ReadingState.failure] is non-null and the retry control
  /// is live.
  failed,
}

/// `/reading`'s state.
///
/// ## WHAT IS **NOT** IN HERE, AND BOTH OMISSIONS ARE DECISIONS
///
/// The plan says the cubit owns "font scale and verse numbers, which come from
/// `SettingsRepository`". Phase 7 delivers the font step and **does not** have a
/// verse-number field, and both omissions are recorded rather than quietly
/// absorbed:
///
/// * **No `SettingsRepository` in Phase 7.** `07-file-map.md:212` puts the
///   implementation in `settings/data/`, which is Phase 9, so declaring the port
///   here would be a port with **no adapter** — the exact class this repository has
///   shipped and fixed three times (Phase 5's unread `@Named('apiBaseUrl')`, its
///   dead `isValidUserId` branch, and recorded decision 22's "requiredness is not
///   use"). A promise with no payer. So [fontStep] is cubit state for the life of
///   the cubit, the `Aa` control genuinely works **within a visit**, and Phase 9
///   introduces the port and makes it durable.
/// * **No verse-number flag.** The prototype draws a `<sup>` on every verse of
///   both arms and draws **no control** for turning it off. A `bool` with no writer
///   is the dead-branch defect twice over, so `ScriptureBlock` always renders the
///   marker.
///
/// **THE COST, IN PLAIN WORDS: a reader's font size does not survive leaving
/// `/reading`.** They set it, they open the quiz, they come back, and the default is
/// back. That is the whole of what this phase does not do, and no copy, doc or test
/// in this repository claims otherwise — `reading_page_test.dart` asserts the
/// `Aa` control *changes* the rendered size and asserts nothing about surviving a
/// navigation, because there is nothing to assert.
///
/// ## AND IT IS A **`Cubit`**, NOT A `Bloc`, WHICH IS A DECISION WITH A REASON
///
/// `HomeBloc` is a `Bloc` because it has four event types and `home_bloc_test.dart`
/// spends real effort on their equality — including recorded decision 48's account
/// of an uncovered `HomeEvent` equality getter. This cubit has **no events**:
/// `load` and `setFontStep` are method parameters, and `bloc.add` is not reachable
/// from it. The mistake recorded decision 48 names — every event equal, so
/// `bloc.add` swallows a duplicate — cannot happen to a type with no events.
///
/// ## AND THERE IS **ONE** `load`, NOT A `LOAD` AND A `RETRY`
///
/// Phase 6 needs two because `/` has two independent sections and a retry must
/// re-request **only** the failed one (`home_bloc_test.dart` asserts the untouched
/// port with `verifyNever`). `/reading` has exactly one section, so a `retry` method
/// would be a second spelling of `load` with nothing to distinguish the two calls.
/// It exists as a **name** so the retry button reads as a retry, and it delegates:
/// `ReadingPage` calls [retry] from the failure view and [load] from
/// `didChangeDependencies`, and the difference between them is the reader's intent
/// rather than a different code path.
///
/// ## [copyWith] IS GENERATED, AND IT **CAN** CLEAR [scripture] AND [failure]
///
/// The hand-rolled `copyWith` this class used to declare wrote
/// `scripture ?? this.scripture`, so `null` meant "leave it alone" and the two
/// nullable fields could never be cleared through it — a hazard its own doc
/// recorded as unfixable. freezed gives every nullable field a sentinel default,
/// so `copyWith(scripture: null)` clears and omitting the argument keeps. The two
/// call sites below pass only [fontStep] and [textSizePanelOpen], so behaviour at
/// every existing call site is unchanged. See AGENT_CONTEXT §2.1.
///
/// **`toString` is generated here**, where `Equatable`'s default used to print
/// every prop. That is harmless on this class — none of its fields is a secret —
/// and the five classes in this repository that *do* declare their own are what
/// `test/core/common/secret_masking_test.dart` structurally enforces.
@freezed
final class ReadingState with _$ReadingState {
  /// A state with nothing loaded and the reader's default font step.
  const ReadingState({
    this.status = ReadingStatus.loading,
    this.scripture,
    this.failure,
    this.fontStep = ReadingCubit.defaultFontStep,
    this.textSizePanelOpen = false,
  });

  /// Where the passage request is.
  final ReadingStatus status;

  /// Today's passage, or `null` while loading and after a failure.
  ///
  /// **`null` for a failure and not "the last good one".** Leaving a stale passage
  /// on screen under an error would let a reader read yesterday's text believing it
  /// is today's, which is the one thing a reading sanctuary must not do.
  final ScriptureText? scripture;

  /// Why the last request failed, or `null`.
  final Failure? failure;

  /// The reader's font step, `kFontStepMin`…`kFontStepMax`.
  ///
  /// Survives a load and survives a failure, because it is the reader's setting and
  /// not the payload's — a retry that reset the text size would be the third way
  /// this screen could lose a reader's input to a network problem.
  final int fontStep;

  /// Whether the `Aa` disclosure is showing.
  ///
  /// ## WHY IT IS STATE AND NOT A `StatefulWidget`'s FIELD
  ///
  /// Because **the reader's step changes this cubit's state, and a control held
  /// outside the cubit would be rebuilt by it** — `ReadingPage`'s `build` runs on
  /// every state change, so a panel held in `ReadingControls`' own `State` would be
  /// re-created, and therefore reset, by the reader dragging the stepper inside it.
  /// Closing the panel under the reader's finger is the failure this prevents.
  ///
  /// ## AND IT IS DELIBERATELY **NOT** A PREFERENCE
  ///
  /// `textSizePanelOpen` is a property of this visit and nothing more, and keeping it
  /// in the same state object as [fontStep] — which *would* be a preference in Phase
  /// 9 — is the reason that boundary is visible. `reading_page_test.dart` asserts the
  /// panel opens and closes and asserts **nothing** about surviving a navigation,
  /// because there is nothing to assert.
  final bool textSizePanelOpen;
}

/// `/reading`'s state machine.
///
/// ## TAKES THE **USE CASE**, NOT THE REPOSITORY
///
/// §3's DIP row: no `domain/` file names an adapter, and a test that wants to hold
/// the request open substitutes a slow [LoadScripture] rather than writing a class
/// of its own. [ReadingCubit] is registered by hand from
/// `lib/app/di/navigation_injection.dart` because `flutter_bloc` re-exports
/// Flutter's widget layer and `bloc` is a transitive dependency §8.4 will not let
/// this project promote — the third time that wall has been hit, after the router
/// and `AuthBloc`.
class ReadingCubit extends Cubit<ReadingState> {
  /// Drives `/reading` through [load] and [setFontStep].
  ReadingCubit({required this.loadScripture}) : super(const ReadingState());

  /// The seam. See the class doc.
  final LoadScripture loadScripture;

  /// The step a reader who has never touched the control gets.
  ///
  /// **3, and asserted rather than assumed.** `03-design-system.md` §5.2's table
  /// maps `3 → 1.00`, so the identity: the default install renders at the
  /// platform's own size and the `Aa` control moves away from it in both
  /// directions. A default of `1` would mean the sanctuary opens at `0.90×` for
  /// everyone.
  static const int defaultFontStep = 3;

  /// Loads today's passage in [language].
  ///
  /// [language] is a parameter and **not** a constructor argument, for
  /// `HomeStarted`'s reason: the cubit is registered once for the process, so a
  /// language fixed at construction would be the language at *launch* for the rest
  /// of the run — and `/reading` is the screen Phase 9's language switch will
  /// rebuild under.
  ///
  /// **It empties first, and that is measured rather than cautious.** Phase 6 found
  /// the alternative on `/`: leaving the previous reading on screen while the next
  /// request is in flight renders the other arm's passage under this arm's chrome.
  Future<void> load(ReadingLanguage language) async {
    emit(_loading());
    final Result<ScriptureText> result = await loadScripture(language);
    switch (result) {
      case Success<ScriptureText>(:final ScriptureText value):
        emit(_ready(value));
      case FailureResult<ScriptureText>(:final Failure failure):
        emit(_failed(failure));
    }
  }

  /// The reader asked to try again, in [language].
  ///
  /// **A name, not a code path.** See the class doc: `/reading` has one section, so
  /// this is [load]. It exists so the failure view's control reads as a retry
  /// rather than as a re-entry, and so the intent is visible at the call site
  /// instead of being inferred from which method the page happened to be in.
  Future<void> retry(ReadingLanguage language) => load(language);

  /// Reports a new font step.
  ///
  /// **Clamped** through `clampFontStep`, so a corrupted value cannot reach
  /// `evaScalerFor`'s `_` arm as something the stepper's knob does not own — the
  /// boundary's own doc states that requirement and Phase 9's persisted setting is
  /// the input it exists for.
  ///
  /// **No emit when the step is unchanged**, which is what keeps
  /// `FontSizeStepper`'s drag from rebuilding the whole passage on every frame:
  /// the track reports continuously, and [ReadingState]'s `==` is generated from
  /// its five fields, so an identical state is not a state change.
  void setFontStep(int step) {
    final int clamped = clampFontStep(step);
    if (clamped == state.fontStep) return;
    emit(state.copyWith(fontStep: clamped));
  }

  /// The state while [load] is in flight: nothing on screen, same font step.
  /// Opens or closes the `Aa` disclosure. See [ReadingState.textSizePanelOpen].
  void toggleTextSizePanel() =>
      emit(state.copyWith(textSizePanelOpen: !state.textSizePanelOpen));

  ReadingState _loading() => ReadingState(
    fontStep: state.fontStep,
    textSizePanelOpen: state.textSizePanelOpen,
  );

  /// The state once [passage] is in hand.
  ReadingState _ready(ScriptureText passage) => ReadingState(
    status: ReadingStatus.ready,
    scripture: passage,
    fontStep: state.fontStep,
    textSizePanelOpen: state.textSizePanelOpen,
  );

  /// The state after [failure].
  ReadingState _failed(Failure failure) => ReadingState(
    status: ReadingStatus.failed,
    failure: failure,
    fontStep: state.fontStep,
    textSizePanelOpen: state.textSizePanelOpen,
  );
}
