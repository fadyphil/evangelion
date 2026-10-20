import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
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
/// `SettingsRepository`". **Neither of them is here**, and both omissions are
/// recorded rather than quietly absorbed:
///
/// * **No `SettingsRepository`.** `07-file-map.md:212` puts the implementation in
///   `settings/data/`, so declaring the port here would be a port with **no
///   adapter** — the exact class this repository has shipped and fixed three times
///   (Phase 5's unread `@Named('apiBaseUrl')`, its dead `isValidUserId` branch, and
///   recorded decision 22's "requiredness is not use"). A promise with no payer.
///   **And the font scale did not come back to the cubit when the adapter
///   landed.** It is `UserSettings.fontStep`, persisted and installed app-wide at
///   `MaterialApp.builder`; `ReadingCubit.setFontStep` and `ReadingState.fontStep`
///   are **deleted**, because a cubit holding a second copy of a preference is the
///   "two sources of truth for one fact" defect, and it would have disagreed with
///   `app.dart` for the one window between the reader's gesture and the store's
///   write. `reading_cubit_test.dart` asserts that they are gone.
/// * **No verse-number flag.** The prototype draws a `<sup>` on every verse of
///   both arms and draws **no control** for turning it off. A `bool` with no writer
///   is the dead-branch defect twice over, so `ScriptureBlock` always renders the
///   marker.
///
/// **THE COST, IN PLAIN WORDS, AND WHAT IT IS NOW.** A reader's font size did not
/// survive leaving `/reading` — that was the cost of the omission, and it was the
/// cost for as long as the step lived in this cubit. They set it, they opened the
/// quiz, they came back, and the default was back. The step is durable now, so
/// they set it, they open the quiz, they come back, and it is still set: the
/// durable store is the app's, and this cubit never had a second copy of it.
///
/// ## [ReadingState.copyWith] IS GENERATED AND IT NOW HAS **FOUR** FIELDS
///
/// The hand-written `copyWith` this class used to declare wrote
/// `scripture ?? this.scripture`, so `null` meant "leave it alone" and the two
/// nullable fields could never be cleared through it — a hazard its own doc
/// recorded as unfixable. freezed gives every nullable field a sentinel default,
/// so `copyWith(scripture: null)` clears and omitting the argument keeps.
///
/// `toString` is generated here, where `Equatable`'s default used to print
/// every prop. That is harmless on this class — none of its fields is a secret —
/// and the five classes in this repository that *do* declare their own are what
/// `test/core/common/secret_masking_test.dart` structurally enforces.
///
/// ## AND IT IS A **`Cubit`**, NOT A `Bloc`, WHICH IS A DECISION WITH A REASON
///
/// `HomeBloc` is a `Bloc` because it has four event types and `home_bloc_test.dart`
/// spends real effort on their equality — including recorded decision 48's account
/// of an uncovered `HomeEvent` equality getter. This cubit has **no events**:
/// `load`, `retry` and `toggleTextSizePanel` are called directly, and `bloc.add`
/// is not reachable from it. The mistake recorded decision 48 names — every event
/// equal, so `bloc.add` swallows a duplicate — cannot happen to a type with no
/// events.
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
/// so `copyWith(scripture: null)` clears and omitting the argument keeps. The one
/// call site below passes only [textSizePanelOpen], so behaviour at every
/// existing call site is unchanged. See AGENT_CONTEXT §2.1.
///
/// **`toString` is generated here**, where `Equatable`'s default used to print
/// every prop. That is harmless on this class — none of its fields is a secret —
/// and the five classes in this repository that *do* declare their own are what
/// `test/core/common/secret_masking_test.dart` structurally enforces.
@freezed
final class ReadingState with _$ReadingState {
  /// A state with nothing loaded and the `Aa` disclosure closed.
  const ReadingState({
    this.status = ReadingStatus.loading,
    this.scripture,
    this.failure,
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
  /// `textSizePanelOpen` is a property of **this visit** and nothing more, and the
  /// class doc's first section is what makes the boundary visible now that the step it
  /// used to sit beside is a persisted preference: a disclosure is a property of the
  /// screen and a font size is a property of the reader, and `reading_page_test.dart`
  /// asserts both claims in opposite directions — that the panel opens and closes
  /// here, and that the step survives leaving.
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
  /// Drives `/reading` through [load], [retry] and [toggleTextSizePanel].
  ReadingCubit({required this.loadScripture}) : super(const ReadingState());

  /// The seam. See the class doc.
  final LoadScripture loadScripture;

  /// Loads today's passage in [language].
  ///
  /// [language] is a parameter and **not** a constructor argument, for
  /// `HomeStarted`'s reason: the cubit is registered once for the process, so a
  /// language fixed at construction would be the language at *launch* for the rest
  /// of the run — and `/reading` is the screen Phase 9's language switch rebuilds
  /// under.
  ///
  /// **It empties first, and that is measured rather than cautious.** Phase 6 found
  /// the alternative on `/`: leaving the previous reading on screen while the next
  /// request is in flight renders the other arm's passage under this arm's chrome.
  Future<void> load(ReadingLanguage language) async {
    emit(_loading());
    final Result<ScriptureText> result = await loadScripture(language);
    switch (result) {
      case Right<Failure, ScriptureText>(:final ScriptureText value):
        emit(_ready(value));
      case Left<Failure, ScriptureText>(value: final failure):
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

  /// The state while [load] is in flight: nothing on screen, same disclosure.
  /// Opens or closes the `Aa` disclosure. See [ReadingState.textSizePanelOpen].
  void toggleTextSizePanel() =>
      emit(state.copyWith(textSizePanelOpen: !state.textSizePanelOpen));

  ReadingState _loading() =>
      ReadingState(textSizePanelOpen: state.textSizePanelOpen);

  /// The state once [passage] is in hand.
  ReadingState _ready(ScriptureText passage) => ReadingState(
    status: ReadingStatus.ready,
    scripture: passage,
    textSizePanelOpen: state.textSizePanelOpen,
  );

  /// The state after [failure].
  ReadingState _failed(Failure failure) => ReadingState(
    status: ReadingStatus.failed,
    failure: failure,
    textSizePanelOpen: state.textSizePanelOpen,
  );
}
