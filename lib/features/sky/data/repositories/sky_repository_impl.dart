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
/// ## AND IT WRAPS **THROWING** INTO A TYPED FAILURE, WHICH IS THE REST
///
/// `SkyRepository`'s LSP row says an implementation "never throws".
/// `SharedPreferences.getInstance()` reads from disk over a platform channel, and
/// a platform with no plugin registered throws `MissingPluginException` out of it.
/// All four arms of this class are `try`/`catch` over the store and nothing else —
/// `settings_repository_test.dart`'s "a second `try` and a real cost" is why the
/// count is stated rather than left to be inferred.
///
/// ## THE CAP IS ENFORCED HERE, AND THE NUMBER LIVES IN `sky_star_cap.dart`
///
/// `SkyRepository`'s doc says the cap "is unmodelled: no cap field or method on
/// this port" — and this adapter enforces it anyway, because the prototype evicts
/// inside `addStar` itself (`eva/redesign.html:1147`) rather than in a caller: every
/// writer goes through [record], so the one-at-a-time eviction inside [record] is
/// the faithful spelling. The number itself lives one layer inward, in the
/// feature's pure-Dart domain, because `SkyCubit`'s optimistic frame needs the same
/// number and neither writer may import it from the other — see that file's doc.
/// A cap on the port would have made every reader depend on a number only writers
/// need; a cap nowhere would have let the sky grow past the `44` the slider
/// re-trims to (`eva/redesign.html:1486-1487`).
final class SkyRepositoryImpl implements SkyRepository {
  /// Reads and writes through [store].
  const SkyRepositoryImpl(this._store);

  final SkyLocalDataSource _store;

  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) async {
    try {
      final List<SkyEntry> current = await _store.read();
      final SkyEntry stored = _applyRecord(current, entry);
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
  Future<Result<void>> clear() async {
    try {
      await _store.write(<SkyEntry>[]);
      return const Right<Failure, void>(null);
    } on Object catch (error) {
      return Result<void>.left(_unreachable(error));
    }
  }

  /// Lights [entry] inside [current], in place, and answers what is stored.
  ///
  /// The whole of the port's dedupe rule, and it mutates the list it is handed so
  /// the caller writes back exactly what it read plus this lighting:
  ///
  /// * a verse never lit is appended, keeping lit-event order — and past
  ///   [skyStarCap] the oldest goes first, which is the prototype's
  ///   one-at-a-time eviction inside `addStar` (`eva/redesign.html:1147`);
  /// * a verse lit before keeps its position and its first [SkyEntry.litAt];
  /// * a re-record with [SkyEntry.isFlare] set upgrades the stored ordinary star
  ///   to a flare in place, and the upgrade is monotone — an ordinary re-record
  ///   never dims a stored flare, because a last-write-wins store would dim a
  ///   celebrated moment (`:1123`, `:1330`, `:1428`) back to an ordinary one on
  ///   the next scroll re-light (`:1217`).
  ///
  /// Returns the entry **as stored** — the `SettingsRepository.save` contract,
  /// mirrored — so a caller that re-lights a verse sees the first lit instant it
  /// actually holds, never having to re-read to find out.
  static SkyEntry _applyRecord(List<SkyEntry> current, SkyEntry entry) {
    final int at = current.indexWhere((SkyEntry held) => held.key == entry.key);
    if (at == -1) {
      current.add(entry);
      while (current.length > skyStarCap) {
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
