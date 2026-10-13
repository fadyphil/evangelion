import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/features/sky/domain/sky_star_cap.dart';
import 'package:evangelion/features/sky/presentation/cubit/sky_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

/// The witness sky's only writer.
///
/// ## IT IS A **`Cubit`**, NOT A `Bloc`, FOR `ReadingCubit`'S REASON
///
/// `ReadingCubit`'s doc gives it: there are no events here, every entry point is a
/// method, and `bloc.add` is not reachable from it.
///
/// ## AND IT IS REGISTERED **BY HAND**, WHICH IS THE SEVENTH TIME
///
/// `Cubit` arrives through `package:flutter_bloc/flutter_bloc.dart`, which re-exports
/// Flutter's widget layer alongside the bloc, and `bloc` is a transitive dependency
/// AGENT_CONTEXT §8.4 will not let this project promote. So there is no spelling of
/// "register this cubit" that keeps Flutter out of `injection.dart`'s closure, and
/// `lib/app/di/navigation_injection.dart` builds it — the same wall
/// `SettingsModule`'s own doc predicted before this phase existed, and the seventh
/// `Cubit`/`Bloc` to hit it after `AuthBloc`, `HomeBloc`, `ReadingCubit`,
/// `QuizBloc`, `LeaderboardCubit` and `SettingsCubit`.
///
/// **`registerSingleton`, for the reader-visible reason.** This one holds the lit
/// verses — what `journey` counts and what the constellation draws. A second
/// instance would be a second sky, and `/reading` lighting a verse through one
/// while `journey` counted the other would show a reader a star that is not there.
///
/// ## `record` AND `clear` ARE **OPTIMISTIC**, FOR `SettingsCubit`'S REASON
///
/// `SettingsCubit.apply`'s doc gives it, and the three steps are the same here:
///
/// 1. **emit first, persist second.** The verse lights on the frame it was read, so
///    the sky does not lag a disk round trip behind the scroll.
/// 2. **confirm against the store answer.** A successful write re-reads the store
///    truth — which is where the cap eviction becomes visible rather than
///    resurrected — and a page that was `loading` or `failed` becomes `ready`.
/// 3. **roll back** if the write fails, and record the failure in
///    [SkyState.failure].
///
/// **The rollback is the same decision, and the alternative fails the same way.**
/// Because step 1 emits first, a store that cannot be reached would otherwise leave
/// the reader looking at a star that is not lit and did not come back. Reverting to
/// the last known-good sky on failure is the honest answer: the state the reader
/// sees is always a state the store has confirmed, except in the window between the
/// lighting and the write, which is one frame wide.
///
/// ## A RE-LIGHT THAT CHANGES NOTHING EMITS NOTHING
///
/// A scroll re-light fires on every pass over a verse (`eva/redesign.html:1217`),
/// and most passes change nothing: the verse is already lit, ordinarily, with its
/// first instant kept. `SettingsCubit.apply`'s no-emit rule applies here with more
/// force, because the writer fires far more often than a settings toggle — an emit
/// that changes nothing is a rebuild of every sky reader that changes nothing.
class SkyCubit extends Cubit<SkyState> {
  /// Drives the witness sky through [repository].
  SkyCubit({required SkyRepository repository})
    : super(const SkyState(entries: <SkyEntry>[])) {
    _repository = repository;
  }

  late final SkyRepository _repository;

  /// The last sky the store confirmed, and the value a failed write rolls back to.
  ///
  /// **A field and not `state.entries`**, because [record] emits before it persists
  /// and so `state.entries` is the *optimistic* sky while this is the durable one.
  /// Rolling back to the optimistic sky would be a rollback to nothing. It starts
  /// empty, so a failure on the very first record rolls back to the empty sky
  /// rather than to an uninitialised field.
  List<SkyEntry> _confirmed = <SkyEntry>[];

  /// Reads the store and publishes what it holds.
  ///
  /// **Called once**, from whatever screen first needs the sky, and again by any
  /// screen that re-enters after the Stars-off switch may have run — which is the
  /// one place a second call is wanted: a reader who cleared the sky from
  /// `/settings` and navigated back to `journey` gets the empty sky without a
  /// restart.
  ///
  /// **It never empties [SkyState.entries] on failure.** See that class's doc for
  /// the reason: the last confirmed sky stays on screen, and [SkyState.status] says
  /// it is stale.
  Future<void> load() async {
    final Result<List<SkyEntry>> result = await _repository.entries();
    switch (result) {
      case Right<Failure, List<SkyEntry>>(:final List<SkyEntry> value):
        _confirmed = List<SkyEntry>.of(value);
        emit(
          SkyState(status: SkyStatus.ready, entries: _confirmed, failure: null),
        );
      case Left<Failure, List<SkyEntry>>(value: final Failure failure):
        emit(
          SkyState(
            status: SkyStatus.failed,
            entries: _confirmed,
            failure: failure,
          ),
        );
    }
  }

  /// Lights [entry], idempotently by [SkyEntry.key].
  ///
  /// The optimistic half of the contract this class's doc states: the lighting is
  /// announced on the frame it happened, and the store is asked second. A re-light
  /// that changes nothing — an ordinary re-record of an already ordinary star —
  /// emits nothing and never reaches the store, which is the `SettingsCubit.apply`
  /// no-emit rule restated for a writer that fires on every scroll pass.
  Future<void> record(SkyEntry entry) async {
    final List<SkyEntry> next = _withRecord(state.entries, entry);
    if (identical(next, state.entries)) {
      // **Identity and not equality, and the helper guarantees it.** `_withRecord`
      // returns its input list itself when nothing changed, so this is a value
      // comparison made cheap: `freezed` derives `==` over the list contents, but
      // reaching it would allocate the comparison on every scroll pass for an
      // answer that is almost always "nothing".
      return;
    }
    emit(state.copyWith(entries: next, failure: null));
    await _confirmRecord(entry);
  }

  /// Empties the sky: the Stars-off `clearStars()`
  /// (`eva/redesign.html:1135-1136`).
  ///
  /// Clearing an already empty sky emits nothing and never reaches the store — the
  /// same no-op rule as [record], for the same reason: the Stars-off switch fires
  /// this on every toggle, and a write that changes nothing is a failure surface
  /// with no reader-visible effect.
  Future<void> clear() async {
    if (state.entries.isEmpty) {
      return;
    }
    emit(state.copyWith(entries: <SkyEntry>[], failure: null));
    final Result<void> result = await _repository.clear();
    switch (result) {
      case Right<Failure, void>():
        // **No re-read, and the asymmetry with [_confirmRecord] is deliberate.**
        // A clear is total: the store holds nothing afterwards, so success *is*
        // the store answer. A record's answer is one entry while the sky is a
        // list — the cap may have evicted another — so only that arm re-reads.
        _confirmed = <SkyEntry>[];
        emit(
          state.copyWith(
            status: SkyStatus.ready,
            entries: <SkyEntry>[],
            failure: null,
          ),
        );
      case Left<Failure, void>(value: final Failure failure):
        emit(
          state.copyWith(
            status: SkyStatus.failed,
            entries: _confirmed,
            failure: failure,
          ),
        );
    }
  }

  /// Confirms a recorded [entry] against the store, keeping [SkyState.failure]
  /// clear or rolling back.
  Future<void> _confirmRecord(SkyEntry entry) async {
    final Result<SkyEntry> saved = await _repository.record(entry);
    switch (saved) {
      case Right<Failure, SkyEntry>():
        // **The store's sky, not the optimistic frame.** `SkyRepository.record`
        // answers the one stored entry, but the sky is a list and the cap may
        // have evicted another star to make room for it — so the confirm re-reads
        // the whole sky rather than reconciling one entry. A cubit that published
        // its own frame here would resurrect the evicted star until the next load.
        final Result<List<SkyEntry>> reread = await _repository.entries();
        switch (reread) {
          case Right<Failure, List<SkyEntry>>(:final List<SkyEntry> value):
            // A successful write proves the store is reachable, so this is also
            // where a cubit that was `loading` or `failed` becomes `ready` — and
            // it is the only place that can be true, because [record] deliberately
            // does not claim it before the write answers.
            _confirmed = List<SkyEntry>.of(value);
            emit(
              state.copyWith(
                status: SkyStatus.ready,
                entries: _confirmed,
                failure: null,
              ),
            );
          case Left<Failure, List<SkyEntry>>(value: final Failure failure):
            emit(
              state.copyWith(
                status: SkyStatus.failed,
                entries: _confirmed,
                failure: failure,
              ),
            );
        }
      case Left<Failure, SkyEntry>(value: final Failure failure):
        emit(
          state.copyWith(
            status: SkyStatus.failed,
            entries: _confirmed,
            failure: failure,
          ),
        );
    }
  }

  /// The optimistic lighting [record] announces before the store answers.
  ///
  /// The same rule `SkyRepositoryImpl` enforces, restated for the one frame the
  /// store has not answered yet: appends keep lit-event order, re-lights keep the
  /// first instant, flares upgrade in place and never downgrade, and past
  /// [skyStarCap] the oldest goes first. The number is shared with the adapter
  /// through `sky_star_cap.dart` so the two spellings cannot disagree about it;
  /// the confirm re-read is what heals any other disagreement.
  ///
  /// Returns its input list **itself** when nothing changed, so [record] can tell
  /// "nothing" by identity rather than by walking the list.
  static List<SkyEntry> _withRecord(List<SkyEntry> current, SkyEntry entry) {
    final int at = current.indexWhere((SkyEntry held) => held.key == entry.key);
    if (at == -1) {
      final List<SkyEntry> next = List<SkyEntry>.of(current)..add(entry);
      while (next.length > skyStarCap) {
        next.removeAt(0);
      }
      return next;
    }
    final SkyEntry held = current[at];
    if (entry.isFlare && !held.isFlare) {
      final List<SkyEntry> next = List<SkyEntry>.of(current);
      next[at] = held.copyWith(isFlare: true);
      return next;
    }
    return current;
  }
}
