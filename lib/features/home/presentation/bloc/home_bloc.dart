/// `/`'s state, and the five questions it asks.
///
/// ## WHY FOUR SECTION STATUSES AND NOT ONE
///
/// `/` asks four things: what is today's reading, how long is the streak, where
/// the light last was, and what the library holds. Three of those come from **three
/// endpoints that fail independently** — AGENT_CONTEXT §5's measured
/// inconsistency, where `streak/summary.current_streak` is `0` while
/// `readings/today/*.current_streak` is `4`, and `today_completed` is `false`
/// while `is_fully_completed` is `true` — and ADR-0022's fiction table makes the
/// fourth a local list with no endpoint at all.
///
/// A single `isLoading` would have to collapse those into one word, and any word it
/// picked would be a reconciliation — the answer §9's `StreakSummary` doc rules
/// out. So [readingStatus], [streakStatus], [lastLightStatus] and
/// [catalogueStatus] are independent, and a failure in one leaves the others on
/// screen. That is not a nicety: it is the requirement Phase 6 names — "a failed
/// **reading** fetch renders `ErrorView` with a working retry **while the streak
/// chip still renders** — not a blank panel, and not a whole-screen error."
///
/// ## AND WHY THE STREAK IS **TWO** SECTIONS
///
/// Because `/streak/summary` and `/streak` are two requests
/// (`streak.routes.ts:1-9` and `:163-172`) with different costs — the second runs
/// a subquery per scheduled day — and a chip that shows a number must not wait for
/// thirty rows to fail. The class doc above used to say "the flame"; the redesign
/// moved that number into the streak chip (`redesign.html:516`) and gave the
/// screen a **last-light card** (`:524`) that the same port's `history[0]` feeds
/// (`ADR-0022`, fiction table). Two endpoints, two statuses, and the two are
/// allowed to disagree — which is the same rule as ever, with one more subject.
///
/// ## WHY THE SESSION IS A STATUS WITH NO ERROR SURFACE
///
/// It is a fifth status because it is a fifth answer, and it is `ready` on both
/// arms. `AuthRepository.getCurrentSession` answering `Failure` is **unreachable
/// in production**: `/` is behind `AuthGuard`, which reads `AuthStatus`, which
/// reads `AuthBloc.state` — the same repository. So the failure arm produces **no
/// name** and no message, and the greeting falls back to the prototype's
/// `peace,` line without a name. `AuthBloc._onSignedOut` takes the same position
/// on the same reasoning.
///
/// The status still exists, because the branch is real code and a reader with no
/// session deserves the same greeting layout as a reader with one — just without a
/// name. `readerName` being `null` is what the widget reads.
///
/// ## AND WHY THE LIBRARY'S FAILURE ARM IS ALSO UNREACHABLE, AND ALSO KEPT
///
/// `LibraryCatalogueRepositoryImpl` returns a literal list, so `catalogueFailed`
/// cannot happen in production either — decision 26's shape exactly, and the same
/// answer: the branch is real code the port promises (`Result.left` is how a
/// books endpoint will report an outage), so it is written, tested from a fake,
/// and labelled rather than inferred.
///
/// ## NOTHING IS NULLABLE-THEN-CLEARED
///
/// [AuthState]'s doc records the hazard this shape avoids: a `String? = null`
/// parameter cannot express "clear it", so a field that must be cleared is written
/// by exactly one writer that builds the whole state. Every transition here goes
/// through one of the six writers on [HomeState], each of which rebuilds the
/// entire state, so no nullable field is ever "left alone" by accident.
library;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_last_light.dart';
import 'package:evangelion/features/home/domain/usecases/load_library_catalogue.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';

/// Where one part of `/` is in its own lifecycle.
///
/// Three values because the three states a reader can be in for a section are
/// distinguishable: nothing has been asked, an answer is on screen, or an answer
/// failed and can be asked again. A two-value enum would have to encode "loading"
/// as "no data", which is the same flag-collapse §3's ISP row forbids.
enum HomeSectionStatus {
  /// The request is open. Nothing is on screen for this section.
  loading,

  /// An answer is in hand. The section's data field is non-null.
  ready,

  /// The request failed. The section's `…Failure` field is non-null and the retry
  /// control is live.
  failed,
}

/// Everything `/` can be asked. Sealed, so an unhandled event is a compile error.
///
/// ## THE BASE DECLARES NOTHING ABOUT EQUALITY, AND EACH EVENT DECLARES **ALL** OF
/// ## ITS OWN
///
/// The base used to override `props` with `const []`, and this section used to
/// defend that at length: the base is unreachable, every subclass overrides
/// `props`, so the getter was dead code by construction. The defence is gone
/// because the shape is gone. Each event below is a `freezed` class in its own
/// right, and freezed **derives** `==` from the constructor — so there is no
/// `props` to forget and the classic Equatable mistake this doc used to warn about
/// (every event equal to every other, and `bloc.add` swallowing a duplicate) is
/// now a compile-time impossibility rather than a review item.
///
/// What the base still owns is the private constructor. Every event below calls
/// `super._()`, so no code outside this file can extend the set, and a fourth
/// event cannot be added without a `sealed`-class compile error at this
/// `on<…>`-less dispatch site — the same guarantee the `sealed` keyword gave
/// before.
///
/// The generated `_$HomeEvent` mixin the part file emits for this declaration is
/// **not** mixed into anything, and that is deliberate rather than an oversight.
/// See the same note on [AuthEvent].
@freezed
sealed class HomeEvent with _$HomeEvent {
  const HomeEvent._();
}

/// The reader signed out. Dispatched by the composition root, never by this feature.
///
/// **The memory half of the re-entry work.** `HomeBloc` is a process-wide
/// `registerSingleton` (`navigation_injection.dart`), so between sign-out and
/// process death it holds `readerName`, `readerInitials`, `reading`, `streak`,
/// `lastLight` and `catalogue` for a reader who no longer has a session — and
/// nothing cleared them, because `AuthBloc._onSignedOut` touches only `AuthBloc`
/// and **may not** name this event:
/// `AuthBloc` lives in `features/auth` and importing `features/home` from there is
/// Gate 2. So the dispatcher is `configureNavigation()`, which already builds both
/// blocs and is the one place allowed to know about both.
///
/// Rejected: letting the page clear itself on departure. It would drop the data the
/// screen is *about to re-request* and leave `/` showing a spinner for a frame that
/// it created, and it does nothing for a process that signs out while `/` is not on
/// screen — which is the case that actually leaks, since a route-driven clear only
/// runs when the route is alive.
@freezed
final class HomeCleared extends HomeEvent with _$HomeCleared {
  /// Creates the sign-out reset.
  const HomeCleared() : super._();
}

/// The screen is opening. Dispatched once, from `_HomeBody`'s `initState`.
///
/// Loads the greeting, the reader, the reading, the streak, the last light and the
/// library — in that order of *emission*, with all five requests in flight at
/// once.
@freezed
final class HomeStarted extends HomeEvent with _$HomeStarted {
  /// Creates the start-up request for [language].
  const HomeStarted(this.language) : super._();

  /// Which arm of the corpus to ask for.
  ///
  /// **On the event and not on the bloc, and the reason is that a `Locale` only
  /// exists in a widget.** `core/domain/` is Flutter-free (Gate 1) and the
  /// composition root has no locale either — `EvangelionApp.locale` is a
  /// constructor argument for tests and Phase 9's settings owns the real one — so
  /// the only place a `ReadingLanguage` can be resolved from a locale is the
  /// screen, and the screen is the event's sender.
  ///
  /// A constructor parameter on the bloc was the alternative and it does not work:
  /// the bloc is a `@lazySingleton`-shaped hand registration that outlives every
  /// page, so a language fixed at construction would be the language at *launch*
  /// for the rest of the process. And a private nullable field with a `!` at the
  /// retry site is the third option, which trades a read for a field that can be
  /// empty. Carrying it on both events is one parameter and no state.
  final ReadingLanguage language;
}

/// The reader asked to try again, for [language].
///
/// **Re-fetches only the sections that failed.** Not "re-fetches everything":
/// Phase 6's own verification says a failed reading fetch must leave the streak
/// flame rendering, and re-issuing the streak request would put it back into
/// `loading` and blank the number that was working. `home_bloc_test.dart` asserts
/// the untouched port with `verifyNever`.
///
/// [language] rides along for [HomeStarted]'s reason: the request needs it and the
/// screen is the only thing that can resolve one.
@freezed
final class HomeRetried extends HomeEvent with _$HomeRetried {
  /// Creates the retry request for [language].
  const HomeRetried(this.language) : super._();

  /// Which arm of the corpus to ask for.
  final ReadingLanguage language;
}

/// `/`'s state machine.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  /// Drives `/` through [HomeStarted] and [HomeRetried].
  ///
  /// Takes the **use cases**, not the repositories, so this file names no
  /// adapter (§3, DIP) and a test can substitute a slow one without a class of
  /// its own — which is exactly how the "which section failed" tests hold one
  /// request open.
  ///
  /// There is deliberately **no** `language` parameter here: it is on
  /// [HomeStarted] and [HomeRetried], and that file's doc gives the whole argument.
  ///
  /// [now] is injected for the reason `AuthBloc`'s fixtures use a fixed
  /// `DateTime`: the greeting's time of day has to be reachable in all 24 hours
  /// from a test, and `DateTime.now()` inside a widget gives it no way.
  HomeBloc({
    required LoadTodayReading loadTodayReading,
    required LoadStreakSummary loadStreakSummary,
    required LoadLastLight loadLastLight,
    required LoadLibraryCatalogue loadLibraryCatalogue,
    required GetReaderSession getReaderSession,
    DateTime Function()? now,
  }) : this._(
         loadTodayReading,
         loadStreakSummary,
         loadLastLight,
         loadLibraryCatalogue,
         getReaderSession,
         now ?? DateTime.now,
       );

  /// The real constructor. See the redirect's doc for why it is private.
  HomeBloc._(
    this._loadTodayReading,
    this._loadStreakSummary,
    this._loadLastLight,
    this._loadLibraryCatalogue,
    this._getReaderSession,
    this._now,
  ) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRetried>(_onRetried);
    on<HomeCleared>(_onCleared);
  }

  final LoadTodayReading _loadTodayReading;
  final LoadStreakSummary _loadStreakSummary;
  final LoadLastLight _loadLastLight;
  final LoadLibraryCatalogue _loadLibraryCatalogue;
  final GetReaderSession _getReaderSession;
  final DateTime Function() _now;

  /// Loads everything, and emits each answer as it lands.
  ///
  /// ## THE FIVE REQUESTS ARE **IN FLIGHT TOGETHER**
  ///
  /// The first version awaited them in sequence, which made the flame wait for
  /// the reading's round trip. Starting all five first and then awaiting in a
  /// fixed order gets both properties: no request waits for another to be
  /// *started*, and the emission order is deterministic — which is what lets
  /// `bloc_test`'s `expect:` be a list rather than a set.
  ///
  /// The greeting goes out **before** any of them, from the clock alone. It is
  /// the only thing on the screen that needs no network, and a reader should not
  /// wait for a socket to be told what time it is.
  ///
  /// ## NOTHING IS CAUGHT HERE, AND THAT IS A DECISION
  ///
  /// `analysis_options.yaml` enables `avoid_catching_errors` and
  /// `avoid_catches_without_on_clauses`, and the ports promise never to throw
  /// (§3, LSP). So every arm below is a `Result` and there is no `try`. If an
  /// adapter ever breaks that promise the error reaches `BlocObserver.onError` —
  /// the error console — which is strictly more useful than a "something went
  /// wrong" the reader cannot act on, and it is the same reasoning `AuthBloc`
  /// records.
  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.withGreetingPeriod(greetingPeriodFor(_now())));

    final Future<Result<AuthSession>> reader = _getReaderSession();
    final Future<Result<TodayReading>> reading = _loadTodayReading(
      event.language,
    );
    final Future<Result<StreakSummary>> streak = _loadStreakSummary();
    // The last-light card's request. `GET /streak`, not `GET /streak/summary` —
    // ADR-0022's fiction table names `history[0]` and the two endpoints are two
    // sections; see the class doc.
    final Future<Result<StreakHistoryEntry?>> lastLight = _loadLastLight();
    // The carousel's. A literal list behind a port, so it resolves on the next
    // microtask — in flight with the rest and not special-cased.
    final Future<Result<List<LibraryBook>>> catalogue = _loadLibraryCatalogue();

    _emitReader(await reader, emit);
    _emitReading(await reading, emit);
    _emitStreak(await streak, emit);
    _emitLastLight(await lastLight, emit);
    _emitCatalogue(await catalogue, emit);
  }

  /// Re-runs only the failed sections, and **emits nothing** when none failed.
  ///
  /// The silence is the assertion. `home_bloc_test.dart` pins it in the failing
  /// direction, because "nothing to retry" and "the retry silently dropped its
  /// event" are otherwise the same observable behaviour.
  Future<void> _onRetried(HomeRetried event, Emitter<HomeState> emit) async {
    final bool retryReading = state.readingStatus == HomeSectionStatus.failed;
    final bool retryStreak = state.streakStatus == HomeSectionStatus.failed;
    final bool retryLastLight =
        state.lastLightStatus == HomeSectionStatus.failed;
    // The catalogue's fourth arm, for the reason the streak's second section has
    // its own: the rule is per section and it is here rather than folded into
    // `withSection` because that method moves the three *network* sections.
    final bool retryCatalogue =
        state.catalogueStatus == HomeSectionStatus.failed;
    if (!retryReading && !retryStreak && !retryLastLight && !retryCatalogue) {
      return;
    }

    // All the retrying sections go back to `loading` in one emit, so a four-section
    // failure is one intermediate frame rather than four, and each failure is
    // cleared as it is left: an `ErrorView` cannot offer a retry for a request that
    // is open.
    emit(
      state.withSection(
        readingStatus: retryReading ? HomeSectionStatus.loading : null,
        streakStatus: retryStreak ? HomeSectionStatus.loading : null,
        lastLightStatus: retryLastLight ? HomeSectionStatus.loading : null,
        catalogueStatus: retryCatalogue ? HomeSectionStatus.loading : null,
      ),
    );

    if (retryReading) {
      _emitReading(await _loadTodayReading(event.language), emit);
    }
    if (retryStreak) {
      _emitStreak(await _loadStreakSummary(), emit);
    }
    if (retryLastLight) {
      _emitLastLight(await _loadLastLight(), emit);
    }
    if (retryCatalogue) {
      _emitCatalogue(await _loadLibraryCatalogue(), emit);
    }
  }

  void _emitReader(Result<AuthSession> result, Emitter<HomeState> emit) {
    // **Both arms land on `ready`.** See the class doc: the failure arm is
    // unreachable in production — `/` is behind the guard, and the guard reads the
    // same repository — so it renders as "no name", which is a layout the greeting
    // handles rather than an error the screen reports.
    emit(
      result.fold<HomeState>(
        (Failure _) => state.withReader(
          status: HomeSectionStatus.ready,
          name: null,
          initials: null,
        ),
        (AuthSession session) => state.withReader(
          status: HomeSectionStatus.ready,
          name: session.displayName,
          initials: session.initials,
        ),
      ),
    );
  }

  /// Emits the last-light card's section.
  ///
  /// The failure arm **clears** the pointer rather than keeping a stale reference
  /// under an error — a card naming last Tuesday's reading beside today's failure
  /// is worse than an empty card, because it looks like data.
  ///
  /// `null` on the success arm is not a failure: it is the prototype's empty state
  /// (`redesign.html:1192-1197`), which `LoadLastLight`'s doc explains — the
  /// cohort has no scheduled reading on file, and the card says so in words.
  void _emitLastLight(
    Result<StreakHistoryEntry?> result,
    Emitter<HomeState> emit,
  ) {
    emit(
      result.fold<HomeState>(
        (Failure failure) => state.withLastLight(
          status: HomeSectionStatus.failed,
          entry: null,
          failure: failure,
        ),
        (StreakHistoryEntry? entry) => state.withLastLight(
          status: HomeSectionStatus.ready,
          entry: entry,
          failure: null,
        ),
      ),
    );
  }

  /// Emits the library section.
  ///
  /// **Its failure arm is unreachable in production** while the adapter is the
  /// literal catalogue — the class doc and decision 26 are the reason it is
  /// written rather than skipped, and `home_bloc_test.dart` reaches it from a
  /// fake so that swapping in a network catalogue needs no change above here.
  void _emitCatalogue(
    Result<List<LibraryBook>> result,
    Emitter<HomeState> emit,
  ) {
    emit(
      result.fold<HomeState>(
        (Failure failure) => state.withCatalogue(
          status: HomeSectionStatus.failed,
          books: null,
          failure: failure,
        ),
        (List<LibraryBook> books) => state.withCatalogue(
          status: HomeSectionStatus.ready,
          books: books,
          failure: null,
        ),
      ),
    );
  }

  void _emitReading(Result<TodayReading> result, Emitter<HomeState> emit) {
    emit(
      result.fold<HomeState>(
        (Failure failure) => state.withReading(
          status: HomeSectionStatus.failed,
          reading: null,
          failure: failure,
        ),
        (TodayReading reading) => state.withReading(
          status: HomeSectionStatus.ready,
          reading: reading,
          failure: null,
        ),
      ),
    );
  }

  void _emitStreak(Result<StreakSummary> result, Emitter<HomeState> emit) {
    emit(
      result.fold<HomeState>(
        (Failure failure) => state.withStreak(
          status: HomeSectionStatus.failed,
          streak: null,
          failure: failure,
        ),
        (StreakSummary streak) => state.withStreak(
          status: HomeSectionStatus.ready,
          streak: streak,
          failure: null,
        ),
      ),
    );
  }

  /// Drops everything, back to the cold-launch state.
  ///
  /// **`const HomeState()`, and not a partial clear.** `HomeState`'s doc argues that
  /// a `String? = null` parameter cannot express "clear it", so every writer here
  /// builds the whole state; a partial clear would be the first writer in the file
  /// that does not. The cold-launch state is exactly the post-sign-out state, which
  /// is why there is no second constructor to invent.
  ///
  /// The greeting period is cleared with everything else, so a signed-out process
  /// retains no `readerName`, no `readerInitials`, no `reading`, no `streak`, no
  /// `lastLight` and no `catalogue` — the six fields that carry a person in.
  void _onCleared(HomeCleared event, Emitter<HomeState> emit) {
    emit(const HomeState());
  }
}

/// `/`'s state: four independently-loaded sections, a greeting, and a name.
///
/// ## NO GENERATED `copyWith`, AND THAT IS THE POINT
///
/// `@Freezed(copyWith: false)`. Every writer below builds the **whole** state, for
/// the reason `AuthState` gives: a `String? = null` parameter cannot express
/// "clear it", so a nullable field that must be cleared is written by a method
/// that cannot get it wrong. freezed's generated `copyWith` is a sentinel-based
/// *partial* writer — it can set [reading] without setting [readingStatus], and
/// can clear [streakFailure] on its own — which is precisely the second spelling
/// of the six writers this file already has, and the one this file's design
/// refuses.
///
/// **`==`, `hashCode` and `toString` are generated**, and `toString` is declared
/// here so freezed does not generate one. The generated `==` covers all fourteen
/// fields, which is the claim `home_bloc_test.dart`'s `HomeCleared` group asserts
/// in its `reason:` string.
@Freezed(copyWith: false)
final class HomeState with _$HomeState {
  /// The state a cold launch starts in: everything loading, nothing known.
  const HomeState({
    this.readingStatus = HomeSectionStatus.loading,
    this.streakStatus = HomeSectionStatus.loading,
    this.lastLightStatus = HomeSectionStatus.loading,
    this.catalogueStatus = HomeSectionStatus.loading,
    this.readerStatus = HomeSectionStatus.loading,
    this.greetingPeriod,
    this.readerName,
    this.readerInitials,
    this.reading,
    this.readingFailure,
    this.streak,
    this.streakFailure,
    this.lastLight,
    this.lastLightFailure,
    this.catalogue,
    this.catalogueFailure,
  });

  /// Where today's-reading panel is.
  final HomeSectionStatus readingStatus;

  /// Where the streak chip's number is.
  final HomeSectionStatus streakStatus;

  /// Where the last-light card's pointer is.
  ///
  /// **Its own status rather than a share of [streakStatus]**, because it is a
  /// different request: `streak.routes.ts:1-9` is `/streak` and `:163-172` is
  /// `/streak/summary`, and one of them can fail while the other answers. A chip
  /// that went blank because the card's thirty rows failed would be a lie about a
  /// request that succeeded.
  final HomeSectionStatus lastLightStatus;

  /// Where the carousel's books are.
  final HomeSectionStatus catalogueStatus;

  /// Where the greeting's name is. **`ready` on both arms** — see the class doc.
  final HomeSectionStatus readerStatus;

  /// The time of day, or `null` before the clock has been read.
  ///
  /// **Null rather than a default.** The redesign's word is `good evening`
  /// (`redesign.html:988` — `tr(hourKey())`) and a non-nullable default would paint
  /// that word on the first frame, before `HomeStarted` has run — a hard-coded
  /// value for exactly as long as it takes to reach the first emit.
  /// `home_page_test.dart` asserts the first frame has no greeting at all.
  final GreetingPeriod? greetingPeriod;

  /// The reader's name from the session, or `null` when there is none.
  ///
  /// **`null` is a real state, not "not yet loaded"**: `readerStatus` says which.
  final String? readerName;

  /// The initials from the session, or `null`.
  ///
  /// **No avatar reads them on this screen any more.** The redesign's home has no
  /// avatar (`:514-517` is the whole greeting) and the phase plan's 5.2 does not
  /// draw one, but the session's `initials` is still carried because `/journey`
  /// (Task 5.6) names the reader with it and rebuilding the state a phase earlier
  /// than the field has a reader would be the §5 forward reference this file
  /// already warns about — see the removed `hasStreak` note below.
  final String? readerInitials;

  /// Today's reading, when [readingStatus] is [HomeSectionStatus.ready].
  final TodayReading? reading;

  /// Why today's reading could not be read, when it could not.
  final Failure? readingFailure;

  /// The streak summary, when [streakStatus] is [HomeSectionStatus.ready].
  final StreakSummary? streak;

  /// Why the streak summary could not be read, when it could not.
  final Failure? streakFailure;

  /// The most recent scheduled day, when [lastLightStatus] is
  /// [HomeSectionStatus.ready].
  ///
  /// **Null while `ready` is a real state**, not a hole: it is the cohort having
  /// no scheduled reading on file, which `LoadLastLight` and the card both render
  /// in words (`redesign.html:1194`, "no light received yet").
  final StreakHistoryEntry? lastLight;

  /// Why the last light could not be read, when it could not.
  final Failure? lastLightFailure;

  /// The carousel's books, when [catalogueStatus] is [HomeSectionStatus.ready].
  final List<LibraryBook>? catalogue;

  /// Why the catalogue could not be read, when it could not.
  ///
  /// Unreachable while the adapter is a literal list; see the class doc.
  final Failure? catalogueFailure;

  // `hasStreak` and `hasReading` were removed in Phase 6's coverage pass: nothing
  // read them, not the page and not a test. `home_page.dart` asks
  // `state.streak?.currentStreak` and hands `state.reading` straight to the card,
  // so a getter that only restates `!= null` over a nullable field is a second
  // spelling of the same question and one more thing to keep in step.

  // --- the six writers ------------------------------------------------------
  //
  // Each builds the **whole** state, for the reason [AuthState] gives: a
  // `String? = null` parameter cannot express "clear it", so a nullable field that
  // must be cleared is written by a method that cannot get it wrong. These six
  // are the only writers, every one of them is total, and `@Freezed(copyWith:
  // false)` is what keeps that sentence true — a generated `copyWith` would be a
  // seventh, partial, silent writer.

  /// [next] with [period] as the greeting's time of day.
  HomeState withGreetingPeriod(GreetingPeriod period) => HomeState(
    greetingPeriod: period,
    readingStatus: readingStatus,
    streakStatus: streakStatus,
    lastLightStatus: lastLightStatus,
    catalogueStatus: catalogueStatus,
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    reading: reading,
    readingFailure: readingFailure,
    streak: streak,
    streakFailure: streakFailure,
    lastLight: lastLight,
    lastLightFailure: lastLightFailure,
    catalogue: catalogue,
    catalogueFailure: catalogueFailure,
  );

  /// [next] with the reader resolved to [name] and [initials], or to neither.
  HomeState withReader({
    required HomeSectionStatus status,
    required String? name,
    required String? initials,
  }) => HomeState(
    readerStatus: status,
    readerName: name,
    readerInitials: initials,
    greetingPeriod: greetingPeriod,
    readingStatus: readingStatus,
    streakStatus: streakStatus,
    lastLightStatus: lastLightStatus,
    catalogueStatus: catalogueStatus,
    reading: reading,
    readingFailure: readingFailure,
    streak: streak,
    streakFailure: streakFailure,
    lastLight: lastLight,
    lastLightFailure: lastLightFailure,
    catalogue: catalogue,
    catalogueFailure: catalogueFailure,
  );

  /// [next] with today's-reading card in [status], carrying [reading] or
  /// [failure] — exactly one of which is non-null.
  HomeState withReading({
    required HomeSectionStatus status,
    required TodayReading? reading,
    required Failure? failure,
  }) => HomeState(
    readingStatus: status,
    reading: reading,
    readingFailure: failure,
    greetingPeriod: greetingPeriod,
    streakStatus: streakStatus,
    lastLightStatus: lastLightStatus,
    catalogueStatus: catalogueStatus,
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    streak: streak,
    streakFailure: streakFailure,
    lastLight: lastLight,
    lastLightFailure: lastLightFailure,
    catalogue: catalogue,
    catalogueFailure: catalogueFailure,
  );

  /// [next] with the streak chip in [status], carrying [streak] or [failure] —
  /// exactly one of which is non-null.
  HomeState withStreak({
    required HomeSectionStatus status,
    required StreakSummary? streak,
    required Failure? failure,
  }) => HomeState(
    streakStatus: status,
    streak: streak,
    streakFailure: failure,
    greetingPeriod: greetingPeriod,
    readingStatus: readingStatus,
    lastLightStatus: lastLightStatus,
    catalogueStatus: catalogueStatus,
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    reading: reading,
    readingFailure: readingFailure,
    lastLight: lastLight,
    lastLightFailure: lastLightFailure,
    catalogue: catalogue,
    catalogueFailure: catalogueFailure,
  );

  /// [next] with the last-light card in [status], carrying [entry] or [failure] —
  /// at most one of which is non-null.
  HomeState withLastLight({
    required HomeSectionStatus status,
    required StreakHistoryEntry? entry,
    required Failure? failure,
  }) => HomeState(
    lastLightStatus: status,
    lastLight: entry,
    lastLightFailure: failure,
    greetingPeriod: greetingPeriod,
    readingStatus: readingStatus,
    streakStatus: streakStatus,
    catalogueStatus: catalogueStatus,
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    reading: reading,
    readingFailure: readingFailure,
    streak: streak,
    streakFailure: streakFailure,
    catalogue: catalogue,
    catalogueFailure: catalogueFailure,
  );

  /// [next] with the carousel in [status], carrying [books] or [failure] — exactly
  /// one of which is non-null.
  HomeState withCatalogue({
    required HomeSectionStatus status,
    required List<LibraryBook>? books,
    required Failure? failure,
  }) => HomeState(
    catalogueStatus: status,
    catalogue: books,
    catalogueFailure: failure,
    greetingPeriod: greetingPeriod,
    readingStatus: readingStatus,
    streakStatus: streakStatus,
    lastLightStatus: lastLightStatus,
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    reading: reading,
    readingFailure: readingFailure,
    streak: streak,
    streakFailure: streakFailure,
    lastLight: lastLight,
    lastLightFailure: lastLightFailure,
  );

  /// [next] with the **section** statuses set, clearing whichever failure
  /// belongs to a status being left.
  ///
  /// The four statuses are nullable *parameters* here, which is the §4-legal
  /// exception: `null` unambiguously means "leave this section alone", because a
  /// section's status is an enum and never null. The failures are cleared by the
  /// same rule — a section going back to `loading` cannot keep the `Failure` that
  /// put it there, and a section going to `ready` cannot keep one either.
  ///
  /// ## AND WHY THE CATALOGUE IS IN HERE NOW
  ///
  /// It used to be a fourth section with a **private writer of its own**, because
  /// the board card that shared this method's name would have made `withSection` a
  /// method that moved three of five sections. All five are the same rule now —
  /// one failed section is a retry and four are four retries — so one method says
  /// it, and the alternative is five methods that differ only in which field they
  /// copy.
  HomeState withSection({
    HomeSectionStatus? readingStatus,
    HomeSectionStatus? streakStatus,
    HomeSectionStatus? lastLightStatus,
    HomeSectionStatus? catalogueStatus,
  }) {
    final HomeSectionStatus nextReading = readingStatus ?? this.readingStatus;
    final HomeSectionStatus nextStreak = streakStatus ?? this.streakStatus;
    final HomeSectionStatus nextLastLight =
        lastLightStatus ?? this.lastLightStatus;
    final HomeSectionStatus nextCatalogue =
        catalogueStatus ?? this.catalogueStatus;
    return HomeState(
      greetingPeriod: greetingPeriod,
      readerStatus: readerStatus,
      readerName: readerName,
      readerInitials: readerInitials,
      readingStatus: nextReading,
      reading: nextReading == HomeSectionStatus.ready ? reading : null,
      readingFailure: nextReading == HomeSectionStatus.failed
          ? readingFailure
          : null,
      streakStatus: nextStreak,
      streak: nextStreak == HomeSectionStatus.ready ? streak : null,
      streakFailure: nextStreak == HomeSectionStatus.failed
          ? streakFailure
          : null,
      lastLightStatus: nextLastLight,
      lastLight: nextLastLight == HomeSectionStatus.ready ? lastLight : null,
      lastLightFailure: nextLastLight == HomeSectionStatus.failed
          ? lastLightFailure
          : null,
      catalogueStatus: nextCatalogue,
      catalogue: nextCatalogue == HomeSectionStatus.ready ? catalogue : null,
      catalogueFailure: nextCatalogue == HomeSectionStatus.failed
          ? catalogueFailure
          : null,
    );
  }

  @override
  /// ## WHY `catalogue` IS COUNTED AND NOT PRINTED
  ///
  /// The catalogue is a list of six `LibraryBook`s — each carrying a name per arm,
  /// a category, a wash and a count — and a failure message that renders all of it
  /// stops being readable. `catalogueStatus` plus the row count is enough to tell
  /// "the carousel is ready and empty" from "the carousel is ready with six
  /// scrolls", which is the only question a failing assertion is asking of it.
  ///
  /// The last light is printed as **its arm**, not its two, for the reason
  /// `toString` is hand-written at all: a generated one would print all fourteen
  /// fields, including the Arabic book names, and be unreadable.
  String toString() =>
      'HomeState(reading: ${readingStatus.name}, streak: ${streakStatus.name}, '
      'lastLight: ${lastLightStatus.name} '
      '${lastLight?.referenceEn ?? (lastLight == null ? '-' : 'empty')}, '
      'catalogue: ${catalogueStatus.name} ${catalogue?.length ?? '-'}, '
      'reader: ${readerStatus.name} ${readerName ?? '-'}, '
      'period: ${greetingPeriod?.name ?? '-'})';
}
