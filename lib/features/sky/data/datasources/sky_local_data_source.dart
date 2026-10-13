import 'dart:convert';

import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The lit sky, in `shared_preferences`.
///
/// ## THE SAME STORE THE SETTINGS USE, AND THAT IS LOAD-BEARING
///
/// `SettingsLocalDataSource` memoises `SharedPreferences.getInstance()` — the
/// package's process singleton — and this class memoises the same future rather
/// than opening a second store. A second store would be a second source of truth
/// for one sky, which is the drift this repository has already paid for twice.
/// The registration lives beside the settings one in `sky_module.dart` (a sibling
/// with the same permission) precisely so a reader sees the two data sources share
/// one `SharedPreferences` rather than each owning one.
///
/// ## WHY NOT THE **`shared_preferences` CACHE CLASS**
///
/// `SettingsLocalDataSource`'s doc gives the argument verbatim: the cache exists to
/// amortise a disk read per access, and this app reads the sky **once per launch**
/// plus once per confirm re-read — all local, all cheap. A second layer of
/// invalidation between the store and the entries is a second way for the drawn
/// constellation to disagree with the stored one. Deliberately rejected, for the
/// same measured reason.
///
/// ## TWO KEYS, AND THE ORDER ONE IS THE COMMIT POINT
///
/// * [kSkyOrderKey] — the entry keys in lit-event order, oldest record first.
/// * [kSkyEntriesKey] — one encoded record per entry: its key, its flare, and its
///   instant in millis.
///
/// The records are written **first** and the order **second**, so a crash between
/// the two leaves the previous order naming only previous records: the read
/// answers the old sky whole rather than a new sky with holes. An order entry with
/// no decodable record is skipped, and a record no order entry names is simply
/// never read — both directions are safe, and neither is an error.
///
/// ## WHAT AN UNREADABLE VALUE DOES HERE, AND WHY IT IS **NOT** AN ERROR
///
/// Every corrupt record is **skipped** and a corrupt key list is answered with an
/// **empty sky**. `SettingsLocalDataSource.read`'s doc gives the argument: a reader
/// whose stored value is mangled gets a working app, which is materially better
/// than an app that will not open — and `SkyRepository`'s contract reserves
/// [FailureKind] for the *store* being unreachable rather than for a value inside
/// it. A mangled preference is indistinguishable from an absent one, and a mangled
/// star is indistinguishable from an unlit one.
final class SkyLocalDataSource {
  /// A store holding nothing yet.
  SkyLocalDataSource();

  /// A store over an already-decided [preferences] future.
  ///
  /// ## A NAMED CONSTRUCTOR FOR **ONE** REASON, AND IT IS THE SETTINGS ONE
  ///
  /// `SkyRepositoryImpl`'s contract is "never throws" — a `Failure` for a store
  /// that cannot be reached — and `SharedPreferences.getInstance()` reaches the
  /// store over a **platform channel**, so the only faithful way to reach that
  /// contract is a store that fails. `settings_repository_test.dart`'s
  /// `unreachableStore` is the precedent this mirrors: the seam is one named
  /// constructor here, in the one class that owns the channel.
  ///
  /// **Named `.over` and not `@visibleForTesting`,** for the reason
  /// `SettingsLocalDataSource.over`'s doc measures: that annotation lives in
  /// `package:flutter/foundation.dart`, and `injection_test.dart` walks the import
  /// graph from `lib/app/di/injection.dart` and fails on any file in it with a
  /// **direct** `package:flutter` import. The doc comment carries the intent and
  /// the name carries it in every reader's line of sight.
  SkyLocalDataSource.over(Future<SharedPreferences> preferences)
    : _store = preferences;

  /// The memoised platform store.
  ///
  /// `null` until the first read, and reset only by [resetForTest] — the memoisation
  /// is the point, so nothing in production clears it.
  Future<SharedPreferences>? _store;

  /// The lit entries in lit-event order, with every unreadable record skipped.
  ///
  /// ## NEVER THROWS FOR A VALUE, ONLY FOR A STORE
  ///
  /// A missing key list answers an empty sky, an order entry with no decodable
  /// record is skipped, and a record that is not a record-shaped object is skipped
  /// with it. What this never does is throw for something *inside* the store —
  /// that would make one mangled star indistinguishable from an unreachable store,
  /// and `SkyRepository`'s contract reserves `FailureKind.storage` for the latter.
  /// A platform channel failure out of `_preferences` still throws, and that is
  /// what `SkyRepositoryImpl`'s `catch` turns into the typed failure.
  Future<List<SkyEntry>> read() async {
    final SharedPreferences preferences = await _preferences;
    final List<String>? order = _stringListAt(preferences, kSkyOrderKey);
    final List<String>? records = _stringListAt(preferences, kSkyEntriesKey);
    if (order == null || records == null) {
      return <SkyEntry>[];
    }
    final Map<String, SkyEntry> byKey = <String, SkyEntry>{};
    for (final String record in records) {
      final SkyEntry? entry = _decodeEntry(record);
      if (entry != null) {
        byKey[entry.key] = entry;
      }
    }
    // **The order list is the sequence, never a `litAt` sort.** `/reading` lights
    // on scroll, so an earlier verse can carry a later instant — and the port's
    // order rule says position comes from the record sequence, which is this list.
    final List<SkyEntry> sky = <SkyEntry>[];
    for (final String key in order) {
      final SkyEntry? entry = byKey[key];
      if (entry != null) {
        sky.add(entry);
      }
    }
    return sky;
  }

  /// Replaces the stored sky, records first and order second.
  ///
  /// **Records first, because the order list is the commit point.** A crash between
  /// the two writes leaves the previous order naming only previous records, so the
  /// next read answers the old sky whole rather than a new sky with holes. The
  /// reverse order would leave the new order naming records that never landed.
  Future<void> write(List<SkyEntry> entries) async {
    final SharedPreferences preferences = await _preferences;
    await preferences.setStringList(kSkyEntriesKey, <String>[
      for (final SkyEntry entry in entries) _encodeEntry(entry),
    ]);
    await preferences.setStringList(kSkyOrderKey, <String>[
      for (final SkyEntry entry in entries) entry.key,
    ]);
  }

  /// The stored [List] of [String] at [key], or `null` — **including when it is
  /// not one.**
  ///
  /// ## MEASURED ON THE SETTINGS SIDE, AND THE OBVIOUS SPELLING IS **WRONG**
  ///
  /// `SharedPreferences.getStringList` is `_preferenceCache[key] as List<String>?`,
  /// so a store holding `eva.sky.order: 44` — a value written by an older build, or
  /// by a developer poking at the store — makes the typed getter **throw a
  /// `TypeError`** rather than answer `null`. `SettingsLocalDataSource._stringAt`'s
  /// doc measures the effect: one corrupt key would make the **whole store**
  /// unreadable, and the `TypeError` would come out as `FailureKind.storage`, which
  /// is the answer for "the store is unreachable". So the raw `get` is used and the
  /// type is checked here, which is total for every value the platform can hand
  /// back.
  static List<String>? _stringListAt(
    SharedPreferences preferences,
    String key,
  ) {
    final Object? raw = preferences.get(key);
    return raw is List<String> ? raw : null;
  }

  /// One entry as one JSON record: its key segments, its flare, and its instant.
  ///
  /// The instant rides as millis plus its `isUtc` flag, so the decode is exact: a
  /// `DateTime` compares its zone flag in `==`, and decoding every instant as UTC
  /// would make a local noon unequal to itself after a round trip.
  static String _encodeEntry(SkyEntry entry) => jsonEncode(<String, Object>{
    'book': entry.book,
    'chapter': entry.chapter,
    'verse': entry.verse,
    'isFlare': entry.isFlare,
    'litAt': entry.litAt.millisecondsSinceEpoch,
    'utc': entry.litAt.isUtc,
  });

  /// The inverse of [_encodeEntry], or `null` for anything that is not one.
  ///
  /// Every field is asked for itself with an `is` check — the same total-over-the-
  /// platform rule as [_stringListAt] — so a record of the wrong shape, a field of
  /// the wrong type, and a string that is not JSON at all are all one answer: skip
  /// it. `jsonDecode`'s only fault here is `FormatException`, which is caught where
  /// it happens rather than two layers up where it would read as a store fault.
  static SkyEntry? _decodeEntry(String record) {
    final Object? decoded;
    try {
      decoded = jsonDecode(record);
    } on FormatException catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final Map<String, Object?> fields = decoded;
    final Object? book = fields['book'];
    final Object? chapter = fields['chapter'];
    final Object? verse = fields['verse'];
    final Object? isFlare = fields['isFlare'];
    final Object? litAt = fields['litAt'];
    final Object? utc = fields['utc'];
    if (book is! String ||
        chapter is! int ||
        verse is! int ||
        isFlare is! bool ||
        litAt is! int ||
        utc is! bool) {
      return null;
    }
    return SkyEntry(
      book: book,
      chapter: chapter,
      verse: verse,
      isFlare: isFlare,
      litAt: DateTime.fromMillisecondsSinceEpoch(litAt, isUtc: utc),
    );
  }

  /// The platform store, read once.
  Future<SharedPreferences> get _preferences =>
      _store ??= SharedPreferences.getInstance();

  /// Drops the memoised store, so the next read takes fresh mock values.
  ///
  /// Named `…ForTest` for the reason `SettingsLocalDataSource.resetForTest`'s doc
  /// measures: the package cannot annotate an instance method's *callers*, and
  /// `SharedPreferences.setMockInitialValues` nullifies the package's own singleton
  /// completer but not **this** object's reference to it.
  void resetForTest() => _store = null;
}

/// The preferences key holding the entry keys in lit-event order.
///
/// Prefixed `eva.sky.` rather than `flutter.`: the package adds its own `flutter.`
/// namespace internally, and a readable prefix means a developer poking at the
/// store can tell which of the app's keys is which without decoding values — the
/// same convention `kThemeModeKey` records, namespaced one deeper for the sky.
const String kSkyOrderKey = 'eva.sky.order';

/// The preferences key holding the encoded entry records. See [kSkyOrderKey].
const String kSkyEntriesKey = 'eva.sky.entries';
