/// `/`'s state, and the three questions it asks.
///
/// ## WHY TWO SECTION STATUSES AND NOT ONE
///
/// `/` asks three things: who is signed in, what is today's reading, and how long
/// is the streak. The last two come from **two endpoints that disagree with each
/// other** — AGENT_CONTEXT §5's measured inconsistency, where
/// `streak/summary.current_streak` is `0` while `readings/today/*.current_streak`
/// is `4`, and `today_completed` is `false` while `is_fully_completed` is `true`.
///
/// A single `isLoading` would have to collapse those two into one word, and any
/// word it picked would be a reconciliation — the answer §9's `StreakSummary` doc
/// rules out. So [readingStatus] and [streakStatus] are independent, and a failure
/// in one leaves the other's data on screen. That is not a nicety: it is the
/// requirement Phase 6 names — "a failed **reading** fetch renders `ErrorView`
/// with a working retry **while the streak flame still renders** — not a blank
/// panel, and not a whole-screen error."
///
/// ## WHY THE SESSION IS A STATUS WITH NO ERROR SURFACE
///
/// It is a third status because it is a third answer, and it is `ready` on both
/// arms. `AuthRepository.getCurrentSession` answering `Failure` is **unreachable
/// in production**: `/` is behind `AuthGuard`, which reads `AuthStatus`, which
/// reads `AuthBloc.state` — the same repository. So the failure arm produces **no
/// name** and no message, and the greeting falls back to the prototype's
/// `…evening.` split. `AuthBloc._onSignedOut` takes the same position on the same
/// reasoning.
///
/// The status still exists, because the branch is real code and a reader with no
/// session deserves the same greeting layout as a reader with one — just without a
/// name. `readerName` being `null` is what the widget reads.
///
/// ## NOTHING IS NULLABLE-THEN-CLEARED
///
/// [AuthState]'s doc records the hazard this shape avoids: a `String? = null`
/// parameter cannot express "clear it", so a field that must be cleared is written
/// by exactly one writer that builds the whole state. Every transition here goes
/// through one of the five writers on [HomeState], each of which rebuilds the
/// entire state, so no nullable field is ever "left alone" by accident.
library;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
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

  /// An answer is in hand. [HomeState.reading] / [HomeState.streak] is non-null.
  ready,

  /// The request failed. [HomeState.readingFailure] / [HomeState.streakFailure]
  /// is non-null and the retry control is live.
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
/// process death it holds `readerName`, `readerInitials`, `reading` and `streak`
/// for a reader who no longer has a session — and nothing cleared them, because
/// `AuthBloc._onSignedOut` touches only `AuthBloc` and **may not** name this event:
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
/// Loads the greeting, the reader, the reading and the streak — in that order of
/// *emission*, with all three requests in flight at once.
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
    required GetReaderSession getReaderSession,
    DateTime Function()? now,
  }) : this._(
         loadTodayReading,
         loadStreakSummary,
         getReaderSession,
         now ?? DateTime.now,
       );

  /// The real constructor. See the redirect's doc for why it is private.
  HomeBloc._(
    this._loadTodayReading,
    this._loadStreakSummary,
    this._getReaderSession,
    this._now,
  ) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRetried>(_onRetried);
    on<HomeCleared>(_onCleared);
  }

  final LoadTodayReading _loadTodayReading;
  final LoadStreakSummary _loadStreakSummary;
  final GetReaderSession _getReaderSession;
  final DateTime Function() _now;

  /// Loads everything, and emits each answer as it lands.
  ///
  /// ## THE THREE REQUESTS ARE **IN FLIGHT TOGETHER**
  ///
  /// The first version awaited them in sequence, which made the flame wait for
  /// the reading's round trip. Starting all three first and then awaiting in a
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

    _emitReader(await reader, emit);
    _emitReading(await reading, emit);
    _emitStreak(await streak, emit);
  }

  /// Re-runs only the failed sections, and **emits nothing** when none failed.
  ///
  /// The silence is the assertion. `home_bloc_test.dart` pins it in the failing
  /// direction, because "nothing to retry" and "the retry silently dropped its
  /// event" are otherwise the same observable behaviour.
  Future<void> _onRetried(HomeRetried event, Emitter<HomeState> emit) async {
    final bool retryReading = state.readingStatus == HomeSectionStatus.failed;
    final bool retryStreak = state.streakStatus == HomeSectionStatus.failed;
    if (!retryReading && !retryStreak) {
      return;
    }

    // Both go back to `loading` in one emit, so a two-section failure is one
    // intermediate frame rather than two, and the failure is cleared as it is
    // left: the `ErrorView` cannot offer a retry for a request that is open.
    emit(
      state.withSection(
        readingStatus: retryReading ? HomeSectionStatus.loading : null,
        streakStatus: retryStreak ? HomeSectionStatus.loading : null,
      ),
    );

    if (retryReading) {
      _emitReading(await _loadTodayReading(event.language), emit);
    }
    if (retryStreak) {
      _emitStreak(await _loadStreakSummary(), emit);
    }
  }

  void _emitReader(Result<AuthSession> result, Emitter<HomeState> emit) {
    // **Both arms land on `ready`.** See the class doc: the failure arm is
    // unreachable in production — `/` is behind the guard, and the guard reads the
    // same repository — so it renders as "no name", which is a layout the greeting
    // handles rather than an error the screen reports.
    emit(
      result.fold<HomeState>(
        onSuccess: (AuthSession session) => state.withReader(
          status: HomeSectionStatus.ready,
          name: session.displayName,
          initials: session.initials,
        ),
        onFailure: (Failure _) => state.withReader(
          status: HomeSectionStatus.ready,
          name: null,
          initials: null,
        ),
      ),
    );
  }

  void _emitReading(Result<TodayReading> result, Emitter<HomeState> emit) {
    emit(
      result.fold<HomeState>(
        onSuccess: (TodayReading reading) => state.withReading(
          status: HomeSectionStatus.ready,
          reading: reading,
          failure: null,
        ),
        onFailure: (Failure failure) => state.withReading(
          status: HomeSectionStatus.failed,
          reading: null,
          failure: failure,
        ),
      ),
    );
  }

  void _emitStreak(Result<StreakSummary> result, Emitter<HomeState> emit) {
    emit(
      result.fold<HomeState>(
        onSuccess: (StreakSummary streak) => state.withStreak(
          status: HomeSectionStatus.ready,
          streak: streak,
          failure: null,
        ),
        onFailure: (Failure failure) => state.withStreak(
          status: HomeSectionStatus.failed,
          streak: null,
          failure: failure,
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
  /// retains no `readerName`, no `readerInitials`, no `reading` and no `streak` —
  /// the four fields §5's live payloads carry a person in.
  void _onCleared(HomeCleared event, Emitter<HomeState> emit) {
    emit(const HomeState());
  }
}

/// `/`'s state: two independently-loaded sections, a greeting, and a name.
///
/// ## NO GENERATED `copyWith`, AND THAT IS THE POINT
///
/// `@Freezed(copyWith: false)`. Every writer below builds the **whole** state, for
/// the reason `AuthState` gives: a `String? = null` parameter cannot express
/// "clear it", so a nullable field that must be cleared is written by a method
/// that cannot get it wrong. freezed's generated `copyWith` is a sentinel-based
/// *partial* writer — it can set [reading] without setting [readingStatus], and
/// can clear [streakFailure] on its own — which is precisely the second spelling
/// of the five writers this file already has, and the one this file's design
/// refuses.
///
/// **`==`, `hashCode` and `toString` are generated**, and `toString` is declared
/// here so freezed does not generate one. The generated `==` covers all ten
/// fields, which is the claim `home_bloc_test.dart`'s `HomeCleared` group asserts
/// in its `reason:` string — see that test, whose wording moved from `props` to
/// "all ten fields".
@Freezed(copyWith: false)
final class HomeState with _$HomeState {
  /// The state a cold launch starts in: everything loading, nothing known.
  const HomeState({
    this.readingStatus = HomeSectionStatus.loading,
    this.streakStatus = HomeSectionStatus.loading,
    this.readerStatus = HomeSectionStatus.loading,
    this.greetingPeriod,
    this.readerName,
    this.readerInitials,
    this.reading,
    this.readingFailure,
    this.streak,
    this.streakFailure,
  });

  /// Where today's-reading panel is.
  final HomeSectionStatus readingStatus;

  /// Where the top bar's streak flame is.
  final HomeSectionStatus streakStatus;

  /// Where the greeting's name is. **`ready` on both arms** — see the class doc.
  final HomeSectionStatus readerStatus;

  /// The time of day, or `null` before the clock has been read.
  ///
  /// **Null rather than a default.** The prototype's word is `Good evening`
  /// (`HomeScreen.tsx:26`) and a non-nullable default would paint that word on the
  /// first frame, before `HomeStarted` has run — a hard-coded value for exactly as
  /// long as it takes to reach the first emit. `home_page_test.dart` asserts the
  /// first frame has no greeting at all.
  final GreetingPeriod? greetingPeriod;

  /// The reader's name from the session, or `null` when there is none.
  ///
  /// **`null` is a real state, not "not yet loaded"**: `readerStatus` says which.
  final String? readerName;

  /// The avatar monogram from the session, or `null`.
  final String? readerInitials;

  /// Today's reading, when [readingStatus] is [HomeSectionStatus.ready].
  final TodayReading? reading;

  /// Why today's reading could not be read, when it could not.
  final Failure? readingFailure;

  /// The streak summary, when [streakStatus] is [HomeSectionStatus.ready].
  final StreakSummary? streak;

  /// Why the streak summary could not be read, when it could not.
  final Failure? streakFailure;

  // `hasStreak` and `hasReading` were removed in Phase 6's coverage pass: nothing
  // read them, not the page and not a test. `home_page.dart` asks
  // `state.streak?.currentStreak` and hands `state.reading` straight to the panel,
  // so a getter that only restates `!= null` over a nullable field is a second
  // spelling of the same question and one more thing to keep in step.

  // --- the five writers ------------------------------------------------------
  //
  // Each builds the **whole** state, for the reason [AuthState] gives: a
  // `String? = null` parameter cannot express "clear it", so a nullable field that
  // must be cleared is written by a method that cannot get it wrong. These five
  // are the only writers, every one of them is total, and `@Freezed(copyWith:
  // false)` is what keeps that sentence true — a generated `copyWith` would be a
  // sixth, partial, silent writer.

  /// [next] with [period] as the greeting's time of day.
  HomeState withGreetingPeriod(GreetingPeriod period) => HomeState(
    greetingPeriod: period,
    readingStatus: readingStatus,
    streakStatus: streakStatus,
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    reading: reading,
    readingFailure: readingFailure,
    streak: streak,
    streakFailure: streakFailure,
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
    reading: reading,
    readingFailure: readingFailure,
    streak: streak,
    streakFailure: streakFailure,
  );

  /// [next] with today's-reading panel in [status], carrying [reading] or
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
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    streak: streak,
    streakFailure: streakFailure,
  );

  /// [next] with the streak flame in [status], carrying [streak] or [failure] —
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
    readerStatus: readerStatus,
    readerName: readerName,
    readerInitials: readerInitials,
    reading: reading,
    readingFailure: readingFailure,
  );

  /// [next] with the two **section** statuses set, clearing whichever failure
  /// belongs to a status being left.
  ///
  /// [readingStatus] and [streakStatus] are nullable *parameters* here, which is
  /// the §4-legal exception: `null` unambiguously means "leave this section alone",
  /// because a section's status is an enum and never null. The failures are cleared
  /// by the same rule — a section going back to `loading` cannot keep the
  /// `Failure` that put it there.
  HomeState withSection({
    HomeSectionStatus? readingStatus,
    HomeSectionStatus? streakStatus,
  }) {
    final HomeSectionStatus nextReading = readingStatus ?? this.readingStatus;
    final HomeSectionStatus nextStreak = streakStatus ?? this.streakStatus;
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
    );
  }

  @override
  String toString() =>
      'HomeState(reading: ${readingStatus.name}, streak: ${streakStatus.name}, '
      'reader: ${readerStatus.name} ${readerName ?? '-'}, '
      'period: ${greetingPeriod?.name ?? '-'})';
}
