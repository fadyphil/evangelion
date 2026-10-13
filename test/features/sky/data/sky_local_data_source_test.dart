import 'dart:io';

import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/features/sky/data/datasources/sky_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SkyLocalDataSource` — the **keys** and the **defensive reads**, which is the
/// part of the sky feature a behavioural round trip cannot see.
///
/// `test/features/sky/data/sky_repository_impl_test.dart` proves the entries
/// survive. This file proves:
///
/// * the two keys are named, namespaced, and match the file that writes them — a
///   store's keys are an interface with the device and with a future migration,
///   and nothing else in the app can see them;
/// * a corrupt record is **skipped**, not fatal, so one mangled entry cannot take
///   the whole sky down — the same rule `SettingsLocalDataSource` applies per
///   field, restated here per record because the sky is a list and not four
///   scalars;
/// * `resetForTest` exists because the package's `setMockInitialValues` nullifies
///   the package's singleton completer but not **this** object's reference to it.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  SkyLocalDataSource freshStore() {
    final SkyLocalDataSource store = SkyLocalDataSource();
    addTearDown(store.resetForTest);
    return store;
  }

  SkyEntry verse({required int verse, required int at, bool flare = false}) =>
      SkyEntry(
        book: 'John',
        chapter: 3,
        verse: verse,
        isFlare: flare,
        litAt: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
      );

  group('the keys', () {
    test('are `eva.`-prefixed, distinct, and declared in this file', () {
      const List<String> keys = <String>[kSkyOrderKey, kSkyEntriesKey];
      expect(keys.toSet(), hasLength(2));
      for (final String key in keys) {
        expect(key, startsWith('eva.'), reason: '$key must be namespaced');
        expect(key, startsWith('eva.sky.'), reason: '$key must name the sky');
      }

      // **A source assertion, because a key is data and not behaviour.** No other
      // gate in this repository can see a store's keys, and the established
      // pattern for exactly this problem is `settings_local_data_source_test.dart`'s
      // key group: read the file that writes them and require the spelling.
      final String source = File(
        'lib/features/sky/data/datasources/sky_local_data_source.dart',
      ).readAsStringSync();
      for (final String key in keys) {
        expect(
          source,
          contains("'$key'"),
          reason: '$key must appear in the file',
        );
      }
    });

    test('and the write puts exactly those two keys in the store', () async {
      await freshStore().write(<SkyEntry>[
        verse(verse: 16, at: 1),
        verse(verse: 17, at: 2, flare: true),
      ]);

      final SharedPreferences raw = await SharedPreferences.getInstance();
      expect(
        raw.getKeys().where((String key) => key.startsWith('eva.')),
        hasLength(2),
        reason:
            'exactly two Eva keys exist — a third would be a leaked key nothing '
            'reads, and a missing one is a sky that silently stops persisting',
      );
    });
  });

  group('the round trip through a second instance', () {
    test('keeps lit-event order, flare, and the first instant', () async {
      final List<SkyEntry> lit = <SkyEntry>[
        verse(verse: 20, at: 20),
        verse(verse: 5, at: 10),
        verse(verse: 16, at: 1, flare: true),
      ];
      await freshStore().write(lit);

      // **A distinct object is the point** — see `settings_repository_test.dart`'s
      // file doc: a re-read through the same object proves the object held the
      // value, not that anything was persisted.
      final List<SkyEntry> back = await freshStore().read();
      expect(back, lit);
    });
  });

  group('an unreadable value is skipped, never fatal', () {
    test('a record that is not JSON is skipped and the rest still read', () async {
      final SkyLocalDataSource store = freshStore();
      await store.write(<SkyEntry>[
        verse(verse: 1, at: 1),
        verse(verse: 2, at: 2),
      ]);

      final SharedPreferences raw = await SharedPreferences.getInstance();
      final List<String> records = raw.getStringList(kSkyEntriesKey)!;
      // The second record is mangled in place: the order still names two keys,
      // but only one record decodes.
      //
      // `isNotNull`, and the unpacking below it: `getStringList` answers `null`
      // for an absent key, and this store just wrote it — so a `null` here is a
      // broken package rather than the property under test. The assertion names
      // that before the mangling does anything.
      expect(records, isNotNull);
      await raw.setStringList(kSkyEntriesKey, <String>[
        records[0],
        'not-json{',
      ]);

      final List<SkyEntry> back = await SkyLocalDataSource().read();
      addTearDown(SkyLocalDataSource().resetForTest);
      expect(back, <SkyEntry>[verse(verse: 1, at: 1)]);
    });

    test('a record of the wrong shape is skipped too', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kSkyOrderKey: <String>['John:3:1'],
        // A JSON string, but a list rather than the record map the decoder
        // reads — the shape an older build never wrote and a poking developer
        // could.
        kSkyEntriesKey: <String>['[1,2,3]'],
      });

      expect(await freshStore().read(), isEmpty);
    });

    test('an order key holding a non-list reads as an empty sky', () async {
      // The raw `get` plus `is` check, mirroring `SettingsLocalDataSource._stringAt`'s
      // measured reason: the typed `getStringList` **throws a `TypeError`** on a
      // wrong-typed value rather than answering `null`, and one corrupt key must
      // not take the whole store down.
      SharedPreferences.setMockInitialValues(<String, Object>{
        kSkyOrderKey: 44,
        kSkyEntriesKey: <String>[],
      });

      expect(await freshStore().read(), isEmpty);
    });

    test('an entries key holding a non-list reads as an empty sky', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kSkyOrderKey: <String>['John:3:1'],
        kSkyEntriesKey: 'John:3:1',
      });

      expect(await freshStore().read(), isEmpty);
    });

    test('an order entry with no record is skipped', () async {
      final SkyLocalDataSource store = freshStore();
      await store.write(<SkyEntry>[verse(verse: 1, at: 1)]);

      final SharedPreferences raw = await SharedPreferences.getInstance();
      await raw.setStringList(kSkyOrderKey, <String>['John:3:1', 'John:3:99']);

      expect(await freshStore().read(), <SkyEntry>[verse(verse: 1, at: 1)]);
    });
  });

  group('`resetForTest`, because the package reset is not enough', () {
    test('a second instance sees the CURRENT mock values, not the stale ones', () async {
      final SkyLocalDataSource first = freshStore();
      await first.write(<SkyEntry>[verse(verse: 1, at: 1)]);
      expect(await first.read(), hasLength(1));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SkyLocalDataSource second = freshStore();

      expect(
        await second.read(),
        isEmpty,
        reason:
            'the store is empty. Without `resetForTest` the memoised instance '
            'would still hold the previous store and this would read one entry.',
      );
    });
  });
}
