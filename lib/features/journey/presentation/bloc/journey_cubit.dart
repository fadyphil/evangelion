import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/journey/domain/journey_rings.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';
import 'package:evangelion/features/journey/domain/usecases/get_journey_reader_session.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_sky_count.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_history.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_summary.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'journey_cubit.freezed.dart';

/// Where `/journey` is in its own lifecycle.
///
/// Three values, and `LeaderboardStatus`'s doc gives the argument that applies here
/// verbatim: "loading" is **not** "no data", and a two-value enum would have to
/// encode it as one — a reader would be told their streak is zero while the
/// request is still open.
enum JourneyStatus {
  /// The reads are open. Nothing is on screen for the journey yet.
  loading,

  /// Every read has answered. [JourneyState.summary] is non-null.
  ready,

  /// One of the reads failed. [JourneyState.failure] is non-null and the retry
  /// control is live.
  failed,
}

/// What `/journey` is showing.
@freezed
final class JourneyState with _$JourneyState {
  /// The cold state: the reads are in flight.
  const JourneyState({
    this.status = JourneyStatus.loading,
    this.session,
    this.summary,
    this.rings,
    this.constellations = 0,
    this.starsLit = 0,
    this.shelf,
    this.failure,
  });

  /// Which lifecycle arm this is.
  final JourneyStatus status;

  /// The signed-in reader, or `null` if the session could not be read.
  ///
  /// **The one load whose failure is absorbed.** The screen is behind the auth
  /// guard, so a reader who reaches it is signed in; a session that will not read
  /// is a defensive arm, and the honest answer to it is "we do not know your
  /// name" — which the card shows as a fallback — rather than a blank screen
  /// over a number the reader is entitled to.
  final AuthSession? session;

  /// The streak summary, or `null` while loading and after a failure.
  ///
  /// The **hero number** is [StreakSummary.currentStreak] — the prototype's `12`
  /// (`eva/redesign.html:589`) is a literal written by JavaScript (`:989`), and
  /// ADR-0022's fiction table marks the hero number **real**:
  /// `GET /streak/summary` → `current_streak`.
  final StreakSummary? summary;

  /// The three ring quantities, or `null` while loading and after a failure.
  ///
  /// **Derived, never transcribed** — see `journey_rings.dart` for the formulas
  /// and for the three divergences they carry.
  final JourneyRings? rings;

  /// The distinct completed books behind the "constellations" count.
  ///
  /// **A proxy**, and the derivation's doc says what it gives up: the prototype
  /// counts books whose **final verse** was lit (`eva/redesign.html:1132`), and
  /// this client has no book-completion record.
  final int constellations;

  /// How many stars are lit in the reader's sky.
  ///
  /// **Real** — `SkyRepository.count()`, the port whose own doc already named
  /// `journey` as the consumer of it.
  final int starsLit;

  /// The reader's medals, or `null` while loading and after a failure.
  final MedalShelf? shelf;

  /// Why the reads failed, or `null`.
  final Failure? failure;
}

/// Drives `/journey` through [load] and [retry].
///
/// ## AND IT IS A **`Cubit`, NOT A `Bloc`**
///
/// `ReadingCubit`'s doc gives the argument that applies here: `HomeBloc` is a
/// `Bloc` because it has four event types whose equality its tests assert. This
/// has **no events** — every operation is a method parameter, `bloc.add` is not
/// reachable, and there is no event stream to lose on a route pop.
class JourneyCubit extends Cubit<JourneyState> {
  /// Drives the screen over the five reads it needs.
  JourneyCubit({
    required this.getReaderSession,
    required this.loadStreakSummary,
    required this.loadStreakHistory,
    required this.loadSkyCount,
    required this.medalRepository,
  }) : super(const JourneyState());

  /// The reader's own session, for the name and the monogram.
  final GetJourneyReaderSession getReaderSession;

  /// The streak summary, for the hero number.
  final LoadJourneyStreakSummary loadStreakSummary;

  /// The thirty-day history, for the rings and the constellations.
  final LoadJourneyStreakHistory loadStreakHistory;

  /// How many stars are lit, for the sky line.
  final LoadJourneySkyCount loadSkyCount;

  /// The reader's medals, for the strip and the count.
  ///
  /// **A port and not a use case**, and the rule is stated here rather than
  /// inherited from a different screen.
  ///
  /// `LeaderboardCubit`'s cheer is a port for a reason that does **not** transfer
  /// here: that port has **two** methods, and a use case over it would be the
  /// right shape. This one has **one**, and a pass-through use case over a single
  /// method would name the same operation twice.
  ///
  /// **So the rule is the house's, not the leaderboard's:** a **use case** exists
  /// for each operation a feature performs over a **shared** port, so the feature
  /// names *which* operation it wants and the four above are the house's pattern
  /// from `features/home/`. A **feature-local** port is taken directly — there is
  /// nothing to compose between the port and the call, and the port is already
  /// this feature's own.
  final MedalRepository medalRepository;

  /// The generation of the reads that are currently in flight.
  ///
  /// **The same guard `/communion` got in Task 5.5**, and for the same reason:
  /// two loads can be open at once, and the one that started first is not the
  /// one that answers first. A reader who taps retry twice must not land the
  /// first answer under the second attempt's heading.
  int _generation = 0;

  /// Reads everything the screen draws.
  Future<void> load() async {
    final int generation = ++_generation;
    emit(state.copyWith(status: JourneyStatus.loading, failure: null));

    // **All five start together.** The screen is one column of figures, and a
    // reader watching it should see it arrive as one thing rather than as a
    // half-drawn column that fills in.
    final Future<Result<AuthSession>> session = getReaderSession();
    final Future<Result<StreakSummary>> summary = loadStreakSummary();
    final Future<Result<List<StreakHistoryEntry>>> history =
        loadStreakHistory();
    final Future<Result<int>> stars = loadSkyCount();
    final Future<Result<MedalShelf>> medals = medalRepository.shelf();

    final Result<AuthSession> sessionResult = await session;
    final Result<StreakSummary> summaryResult = await summary;
    final Result<List<StreakHistoryEntry>> historyResult = await history;
    final Result<int> starsResult = await stars;
    final Result<MedalShelf> medalsResult = await medals;

    // **The stale-response guard.** A load whose generation is not the newest is
    // dropped whole — no status, no figures, no failure.
    if (generation != _generation) return;

    // **The first failure, in a stated order, is the screen's failure.** The
    // order is the order the figures appear in the prototype's column
    // (`eva/redesign.html:589` the hero, `:592-594` the rings, `:596` the sky,
    // `:597-603` the medals), so the message a reader sees names the topmost
    // thing that could not be drawn.
    //
    // **The session is NOT in that list**, and the reason is in the state: it is
    // a fallback, not a figure. A session that will not read costs the reader
    // their name; a summary that will not read costs them their streak.
    final Failure? failure =
        _failure(summaryResult) ??
        _failure(historyResult) ??
        _failure(starsResult) ??
        _failure(medalsResult);
    if (failure != null) {
      emit(state.copyWith(status: JourneyStatus.failed, failure: failure));
      return;
    }

    final List<StreakHistoryEntry> rows = historyResult.fold(
      (Failure _) => const <StreakHistoryEntry>[],
      (List<StreakHistoryEntry> value) => value,
    );

    emit(
      state.copyWith(
        status: JourneyStatus.ready,
        session: sessionResult.fold(
          (Failure _) => state.session,
          (AuthSession value) => value,
        ),
        summary: summaryResult.fold(
          (Failure _) => null,
          (StreakSummary value) => value,
        ),
        rings: deriveJourneyRings(rows),
        constellations: countCompletedBooks(rows),
        starsLit: starsResult.fold((Failure _) => 0, (int value) => value),
        shelf: medalsResult.fold(
          (Failure _) => null,
          (MedalShelf value) => value,
        ),
        failure: null,
      ),
    );
  }

  /// Reads everything again.
  ///
  /// The retry control's whole job, and it re-requests **everything** rather
  /// than the one thing that failed: the four content reads are cheap, the
  /// screen is one column, and a retry that fixed three of four would leave a
  /// reader with a screen that is partly new and partly stale.
  Future<void> retry() => load();

  /// The failure [result] carries, or `null` when it succeeded.
  ///
  /// A generic fold rather than a `cast`, because `Either` has no `cast` and a
  /// `dynamic` would be a hole in a file that has no `dynamic` in it.
  static Failure? _failure<T>(Result<T> result) =>
      result.fold((Failure failure) => failure, (T _) => null);
}
