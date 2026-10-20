import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/features/sky/data/datasources/sky_local_data_source.dart';
import 'package:evangelion/features/sky/domain/sky_star_cap.dart';
import 'package:fpdart/fpdart.dart';

/// The only [SkyRepository] that ships: `shared_preferences`, and nothing else.
///
/// ## IT ADDS THE CONTRACT TO THE DATA SOURCE, AND THAT IS THE POINT
///
/// `SettingsRepositoryImpl`'s doc gives the short version — the store answers every
/// unreadable field with its default, so there is nothing to translate — and the
/// sky side is one layer thicker: the store holds a list, and the port promises
/// dedupe-by-key, first-lit-wins, monotone flare, lit-event order, the cap, and
/// clear. The store owns the bytes and this class owns the rules, so neither can
/// drift — which is the same division `DioReadingRepository` keeps between its
/// mapper and its transport.
///
/// ## RECORDS ARE SERIALIZED, BECAUSE SCROLL DOES NOT AWAIT
///
/// `/reading` lights on scroll into view (`eva/redesign.html:1217`), so two records
/// can be in flight at once — and a record is read→mutate→write, which loses a star
/// when two interleave (measured `[John:3:1, John:3:2]` → `[John:3:2]`). Every
/// mutating arm therefore runs inside [_serialized]: each call snapshots the
/// current tail, installs its own turn, waits for its predecessors, and only then
/// touches the store. Reads ([entries], [count]) take no turn — they never mutate,
/// so there is nothing to interleave.
///
/// **Stated here and not on the port**, because the port is frozen and its
/// signatures do not change: atomicity is an obligation this adapter meets, not a
/// contract its callers rely on. A caller that needs "both landed" still awaits
/// both futures; what the chain guarantees is that awaiting both is sufficient.
///
/// ## THE CAP IS ENFORCED HERE, AND THE NUMBER LIVES IN `sky_star_cap.dart`
///
/// `SkyRepository`'s doc says the cap "is unmodelled: no cap field or method on
/// this port" — and this adapter enforces it anyway, because the prototype evicts
/// inside `addStar` itself (`eva/redesign.html:1147`) rather than in a caller:
/// every writer goes through [record], so the one-at-a-time eviction inside
/// [record] is the faithful spelling. The number itself lives one layer inward,
/// in the feature's pure-Dart domain, because `SkyCubit`'s optimistic frame
/// needs the same number and neither writer may import it from the other — see
/// that file's doc. A cap on the port would have made every reader depend on a
/// number only writers need; a cap nowhere would have let the sky grow past
/// what the reader chose.
///
/// **And the cap is the READER'S CHOICE** — the prototype's `starCap` is a
/// variable the Star-count slider writes (`eva/redesign.html:1131`, `:1487`),
/// and this client's is `UserSettings.starCount`. It arrives through the cap
/// seam this adapter was built with, and the composition root hands the same
/// reader to `SkyCubit`, so the durable eviction and the optimistic frame
/// cannot disagree about the number. `sky_star_cap.dart` carries the shape and
/// the argument; this file's constructor carries the seam.
///
/// ## AND EVERY ARM WRAPS **THROWING** INTO A TYPED FAILURE
///
/// `SkyRepository`'s LSP row says an implementation "never throws".
/// `SharedPreferences.getInstance()` reads from disk over a platform channel, and
/// a platform with no plugin registered throws `MissingPluginException` out of it.
/// The arms below are `try`/`catch` over the store and nothing else —
/// `settings_repository_test.dart`'s "a second `try` and a real cost" is why the
/// count is stated rather than left to be inferred.
final class SkyRepositoryImpl implements SkyRepository {
  /// Reads and writes through [store].
  ///
  /// Not `const`: [_tail] is per-instance mutable state — the chain this adapter
  /// serializes on — and a `const` constructor needs every field `final`.
  ///
  /// ## AND [capReader] IS THE **CAP SEAM**
  ///
  /// The cap is the reader's choice (`UserSettings.starCount`, the prototype's
  /// `starCap` at `eva/redesign.html:1131`) and it changes while the app runs,
  /// so it cannot be a value handed over here: a value would be a snapshot, and
  /// this adapter and `SkyCubit` holding two snapshots of one number is the
  /// drift `sky_star_cap.dart` exists to prevent.
  ///
  /// **So the cap is asked for, at write time, through a closure** — and the
  /// composition root hands the *same* closure to this adapter and to
  /// `SkyCubit`, which is what makes the durable eviction and the optimistic
  /// frame agree about the number. `sky_star_cap.dart` carries the argument in
  /// full; the two lines that feed it live in `lib/app/di/`, which is outside
  /// this slice's paths and is named in the task's report.
  ///
  /// **The default is the prototype's 44** — the same number the preference
  /// defaults to — so a reader who never moves the slider gets the prototype's
  /// sky.
  SkyRepositoryImpl(this._store, {int Function()? capReader}) {
    _capReader = capReader ?? _defaultCapReader;
  }

  final SkyLocalDataSource _store;

  /// Answers the cap the sky is held to right now.
  ///
  /// **A closure and not a value**, and the reason is the constructor's doc: the
  /// reader changes the cap at runtime.
  late final int Function() _capReader;

  /// The cap an adapter built without a reader holds.
  ///
  /// **The prototype's 44**, which is also `UserSettings.starCount`'s default —
  /// so the fallback and the preference agree.
  static int _defaultCapReader() => skyStarCap;

  /// The cap the sky is held to right now — the reader's chosen count, clamped.
  ///
  /// **Asked at write time**, because the reader changes the cap at runtime and
  /// a value held in a field would be a snapshot of a preference. The clamp is
  /// [skyStarCapFor]'s — the one clamp — so this adapter and `SkyCubit` cannot
  /// disagree about what a count of 999 means.
  int _cap() => skyStarCapFor(_capReader());

  /// The tail of the mutation chain: the turn no running mutation has released.
  ///
  /// Not `final`, because every serialized call installs its own turn as the new
  /// tail — and complete from construction, so the first mutation runs at once.
  /// One chain per repository instance, which is also why the data source stays a
  /// `@lazySingleton`: two adapters would be two chains over one store, and the
  /// interleaving would be back.
  Future<void> _tail = Future<void>.value();

  /// Runs [work] after every mutation ahead of it, then releases the next turn.
  ///
  /// The `finally` is the load-bearing half: a `work` that threw would otherwise
  /// leave the tail never-completing and serialize every later mutation behind a
  /// future that never resolves — a hung sky rather than a lost star.
  Future<T> _serialized<T>(Future<T> Function() work) async {
    final Future<void> mine = _tail;
    final Completer<void> next = Completer<void>();
    _tail = next.future;
    await mine;
    try {
      return await work();
    } finally {
      next.complete();
    }
  }

  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) =>
      _serialized(() => _recordNow(entry));

  @override
  Future<Result<List<SkyEntry>>> entries() async {
    try {
      return Result<List<SkyEntry>>.of(await _store.read());
    } on Object catch (error) {
      return Result<List<SkyEntry>>.left(_unreachable(error));
    }
  }

  @override
  Future<Result<int>> count() async {
    try {
      return Result<int>.of((await _store.read()).length);
    } on Object catch (error) {
      return Result<int>.left(_unreachable(error));
    }
  }

  @override
  Future<Result<void>> clear() => _serialized(() async {
    try {
      await _store.write(<SkyEntry>[]);
      return const Right<Failure, void>(null);
    } on Object catch (error) {
      return Result<void>.left(_unreachable(error));
    }
  });

  /// One record's read→mutate→write, run inside [_serialized].
  Future<Result<SkyEntry>> _recordNow(SkyEntry entry) async {
    try {
      final List<SkyEntry> current = await _store.read();
      final SkyEntry stored = _applyRecord(current, entry, _cap());
      await _store.write(current);
      return Result<SkyEntry>.of(stored);
    } on Object catch (error) {
      // `catch (Object)` rather than `catch (Exception)` deliberately, for the
      // reason `SettingsRepositoryImpl.load`'s doc measures: a platform channel
      // failure arrives as whatever the channel threw, and a sky store that cannot
      // be read must be a typed failure whatever it was. An `Error` escaping would
      // take the frame with it, so it is caught too.
      return Result<SkyEntry>.left(_unreachable(error));
    }
  }

  /// Lights [entry] inside [current], in place, and answers what is stored.
  ///
  /// The whole of the port's dedupe rule, and it mutates the list it is handed so
  /// the caller writes back exactly what it read plus this lighting:
  ///
  /// * a verse never lit is appended, keeping lit-event order — and past
  ///   [cap] the oldest goes first, which is the prototype's
  ///   one-at-a-time eviction inside `addStar` (`eva/redesign.html:1147`);
  /// * a verse lit before keeps its position and its first [SkyEntry.litAt];
  /// * a re-record with [SkyEntry.isFlare] set upgrades the stored ordinary star
  ///   to a flare in place, and the upgrade is monotone — an ordinary re-record
  ///   never dims a stored flare, because a last-write-wins store would dim a
  ///   celebrated moment (`:1123`, `:1330`, `:1428`) back to an ordinary one on
  ///   the next scroll re-light (`:1217`). Monotonicity is scoped to RETAINED
  ///   entries: an evicted flare re-lights as an ordinary star — a first light
  ///   again, the store no longer knowing it was ever celebrated.
  ///
  /// Returns the entry **as stored** — the `SettingsRepository.save` contract,
  /// mirrored — so a caller that re-lights a verse sees the first lit instant it
  /// actually holds, never having to re-read to find out.
  ///
  /// ## AND [cap] IS **THE READER'S CHOICE**, TRIMMED AT WRITE TIME
  ///
  /// The prototype's `starCap` is a variable the slider writes
  /// (`eva/redesign.html:1131`, `:1487`) and this client's is
  /// `UserSettings.starCount` — so the number arrives through the cap seam and
  /// is clamped by [skyStarCapFor], the one clamp. **Lowering the cap trims
  /// nothing by itself**: the trim happens here, on the next write, which is the
  /// prototype's own eviction (`:1147`) and not the slider's immediate re-trim
  /// (`:1486-1487`) — the divergence `sky_star_cap.dart` records, and the reason
  /// a reader's lit verses are not deleted by a decoration setting.
  static SkyEntry _applyRecord(
    List<SkyEntry> current,
    SkyEntry entry,
    int cap,
  ) {
    final int at = current.indexWhere((SkyEntry held) => held.key == entry.key);
    if (at == -1) {
      current.add(entry);
      while (current.length > cap) {
        current.removeAt(0);
      }
      return entry;
    }
    final SkyEntry held = current[at];
    if (entry.isFlare && !held.isFlare) {
      final SkyEntry flared = held.copyWith(isFlare: true);
      current[at] = flared;
      return flared;
    }
    return held;
  }

  /// The typed failure all four arms return.
  ///
  /// **A [FailureKind.storage]**, for the reason `SettingsRepositoryImpl`'s
  /// `_unreachable` doc measures: a local store has no status code and no body, so
  /// `network` would claim a transport this app never makes for the sky, and
  /// `serialization` would claim the *value* was unreadable — which
  /// `SkyLocalDataSource.read` deliberately answers by skipping instead.
  static Failure _unreachable(Object error) => Failure(
    kind: FailureKind.storage,
    message: 'The sky store could not be reached: $error',
  );
}
