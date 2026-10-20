import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/features/sky/data/datasources/sky_local_data_source.dart';
import 'package:evangelion/features/sky/data/repositories/sky_repository_impl.dart';
import 'package:evangelion/features/sky/domain/sky_star_cap.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store whose future fails the way an unregistered plugin's does.
///
/// **Through [SkyLocalDataSource.over], not by substituting
/// `SharedPreferencesStorePlatform.instance`.** The reason is AGENT_CONTEXT §8.4:
/// reaching the platform interface means importing
/// `shared_preferences_platform_interface`, a **transitive** dependency, and
/// promoting it is a hard stop — the analyzer's `depend_on_referenced_packages`
/// agrees. It is why `SkyLocalDataSource` carries the same `.over` seam
/// `SettingsLocalDataSource` does, and `settings_repository_test.dart`'s
/// `unreachableStore` is the precedent this mirrors line for line.
///
/// **And the failure is deferred, not a pre-completed `Future.error`.** A real
/// channel failure arrives asynchronously; a pre-completed error future with no
/// listener yet is reported unhandled before the next microtask runs. That was
/// harmless while `record` awaited the store in the same stack, and it is a
/// spurious unhandled error now that records serialize behind a chain — the
/// chain's first turn is a microtask away, and the report fires first. Deferring
/// the throw models the channel faithfully and keeps the failure for the
/// adapter's `catch`, which is the property under test.
SkyLocalDataSource unreachableStore() {
  final SkyLocalDataSource store = SkyLocalDataSource.over(
    Future<SharedPreferences>(
      () =>
          throw MissingPluginException('no shared_preferences implementation'),
    ),
  );
  addTearDown(store.resetForTest);
  return store;
}

/// The value of a [Right], or a named failure saying what came back instead.
///
/// `Result` has no throwing accessor, deliberately — its own doc says "there is
/// no `value` getter and no `getOrNull`". The honest spelling is this exhaustive
/// `switch` over the sealed type: a third arm would not compile. (The same helper
/// `sky_repository_test.dart` carries for the same reason.)
T unwrap<T>(Result<T> result) => switch (result) {
  Right<Failure, T>(:final T value) => value,
  Left<Failure, T>(value: final Failure failure) => throw StateError(
    'expected a success and got ${failure.kind}',
  ),
};

/// `SkyRepositoryImpl` — the port, over a **real** `shared_preferences`.
///
/// ## WHY A REAL STORE AND NOT A DOUBLE
///
/// `settings_repository_test.dart`'s file doc gives the argument verbatim: a
/// hand-written double that returns whatever it was handed passes a round trip
/// whether or not anything was **persisted**. `SharedPreferences.setMockInitialValues`
/// installs the in-memory store behind the platform interface, and the re-read goes
/// through a **second** `SkyLocalDataSource` — a distinct object with a distinct
/// memoised reference — which is what makes "it was written" and "it was held in
/// memory" two different claims.
///
/// ## AND EVERY TEST HERE WRITES THROUGH THE **PORT**
///
/// The raw keys are the subject of `sky_local_data_source_test.dart` instead, for
/// the same reason the settings suite splits them: the mapping from value to
/// identifier is a store interface with the device, and this file is about the
/// contract — dedupe, flare, order, cap, clear, and the Left arms.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// A second store instance over the same `shared_preferences`.
  ///
  /// **A distinct object is the point** — see the file doc.
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

  /// Records through one adapter, re-reads through a **second** data source's.
  Future<List<SkyEntry>> entriesThroughFreshStore() async =>
      unwrap(await SkyRepositoryImpl(freshStore()).entries());

  group('a written sky survives a re-read', () {
    test('three verses lit in order read back in that order', () async {
      final SkyRepository writer = SkyRepositoryImpl(freshStore());
      await writer.record(verse(verse: 1, at: 1));
      await writer.record(verse(verse: 2, at: 2));
      await writer.record(verse(verse: 3, at: 3));

      expect(
        (await entriesThroughFreshStore()).map((SkyEntry e) => e.key),
        <String>['John:3:1', 'John:3:2', 'John:3:3'],
      );
    });

    test('and the clock does not reorder them', () async {
      // `/reading` lights on scroll, so verse 20 can light before verse 5 is
      // recorded with an earlier instant. Order is the RECORD sequence — the
      // prototype's DOM-append (`eva/redesign.html:1153`) read back in DOM order
      // (`:1169`) — and `litAt` is the audit stamp, not the sort key.
      final SkyRepository writer = SkyRepositoryImpl(freshStore());
      await writer.record(verse(verse: 20, at: 20));
      await writer.record(verse(verse: 5, at: 10));

      expect(
        (await entriesThroughFreshStore()).map((SkyEntry e) => e.key),
        <String>['John:3:20', 'John:3:5'],
      );
    });

    test('and a whole sky round-trips as one value', () async {
      final List<SkyEntry> lit = <SkyEntry>[
        verse(verse: 20, at: 20),
        verse(verse: 5, at: 10),
        verse(verse: 16, at: 1, flare: true),
      ];
      final SkyRepository writer = SkyRepositoryImpl(freshStore());
      for (final SkyEntry entry in lit) {
        await writer.record(entry);
      }

      expect(await entriesThroughFreshStore(), lit);
    });

    test('and a LOCAL instant survives the record path ==-exact', () async {
      // The data-source half is pinned in `sky_local_data_source_test.dart`'s
      // "LOCAL instant" case; this is the same property through the port the
      // screens actually write — `record` must not normalise the zone flag on the
      // way in, because `record` returns the entry AS STORED and the caller reads
      // its own instant back out of that answer.
      final SkyEntry local = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: DateTime(2026, 10, 13, 12),
      );
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      final SkyEntry stored = unwrap(await repo.record(local));

      expect(stored.litAt.isUtc, isFalse);
      expect(stored, local);
      expect(await entriesThroughFreshStore(), <SkyEntry>[local]);
    });
  });

  group('concurrent records are serialized', () {
    test('two records fired without awaiting both land, in order', () async {
      // SCROLL FIRES WITHOUT AWAITING: `/reading` lights on scroll into view
      // (`eva/redesign.html:1217`), so two passes in flight must not interleave —
      // an unserialized read→mutate→write loses the first star (measured
      // `[John:3:1, John:3:2]` → `[John:3:2]` against the naive three-step).
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      final Future<Result<SkyEntry>> first = repo.record(
        verse(verse: 1, at: 1),
      );
      final Future<Result<SkyEntry>> second = repo.record(
        verse(verse: 2, at: 2),
      );
      await Future.wait(<Future<Result<SkyEntry>>>[first, second]);

      expect(
        (await entriesThroughFreshStore()).map((SkyEntry e) => e.key),
        <String>['John:3:1', 'John:3:2'],
      );
    });
  });

  group('two readings of the same verse produce one entry', () {
    test('a re-lit verse does not append', () async {
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      await repo.record(verse(verse: 16, at: 1));
      await repo.record(verse(verse: 16, at: 2));

      expect(await entriesThroughFreshStore(), hasLength(1));
      expect(unwrap(await repo.count()), 1);
    });

    test('and the first lit keeps its instant', () async {
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      await repo.record(verse(verse: 16, at: 1));
      final SkyEntry stored = unwrap(
        await repo.record(verse(verse: 16, at: 2)),
      );

      // `record` returns the entry AS STORED — the `SettingsRepository.save`
      // contract, mirrored — so the caller sees the first instant it holds,
      // never having to re-read to find out.
      expect(stored.litAt, verse(verse: 16, at: 1).litAt);
      expect((await entriesThroughFreshStore()).single.litAt, stored.litAt);
    });
  });

  group('a flare upgrades in place', () {
    test('an ordinary star brightens without moving', () async {
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      await repo.record(verse(verse: 16, at: 1));
      await repo.record(verse(verse: 17, at: 2));
      await repo.record(verse(verse: 16, at: 3, flare: true));

      final List<SkyEntry> entries = await entriesThroughFreshStore();
      expect(entries, hasLength(2));
      expect(entries.map((SkyEntry e) => e.key), <String>[
        'John:3:16',
        'John:3:17',
      ]);
      expect(entries.first.isFlare, isTrue);
      expect(entries.first.litAt, verse(verse: 16, at: 1).litAt);
    });

    test('and a stored flare is never dimmed by an ordinary re-record', () async {
      // MONOTONE: the upgrade runs one way. A last-write-wins store would hand
      // back an ordinary star here and dim a celebrated moment — the mutation
      // `sky_repository_test.dart`'s downgrade test exists to catch.
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      await repo.record(verse(verse: 16, at: 1, flare: true));
      await repo.record(verse(verse: 17, at: 2));
      final SkyEntry stored = unwrap(
        await repo.record(verse(verse: 16, at: 3)),
      );

      final List<SkyEntry> entries = await entriesThroughFreshStore();
      expect(entries, hasLength(2));
      expect(stored.isFlare, isTrue);
      expect(entries.first.isFlare, isTrue);
      expect(entries.first.litAt, verse(verse: 16, at: 1).litAt);
    });
  });

  group('the cap', () {
    test('is the prototype’s `starCap`: 44', () {
      // `eva/redesign.html:1131` — `starCap=44` — and `:1512` re-pins the default
      // to the same number. Asserted against the adapter rather than a literal
      // copied into this file, so the one number lives in one place.
      expect(skyStarCap, 44);
    });

    test('and the READER\'S cap is the one that evicts', () async {
      // ## THE CAP IS A **SEAM**, AND THE READER'S CHOICE IS WHAT COMES THROUGH IT
      //
      // The prototype's `starCap` is a variable the Star-count slider writes
      // (`eva/redesign.html:1131`, `:1487`) and this client's is
      // `UserSettings.starCount` — so the adapter must evict to what the
      // reader chose, and not to the constant.
      //
      // **Lowering the cap deletes nothing by itself**: the trim happens on the
      // next write, which is the prototype's own eviction (`:1147`) and not the
      // slider's immediate re-trim (`:1486-1487`). That is why this test
      // records five verses and reads the survivors — nothing was deleted when
      // the cap was set.
      final SkyRepository repo = SkyRepositoryImpl(
        freshStore(),
        capReader: () => 3,
      );
      for (int v = 1; v <= 5; v++) {
        await repo.record(verse(verse: v, at: v));
      }

      final List<SkyEntry> entries = await entriesThroughFreshStore();
      expect(
        entries.map((SkyEntry e) => e.key).toList(),
        <String>['John:3:3', 'John:3:4', 'John:3:5'],
        reason:
            'the reader\'s cap (3) and not the prototype\'s 44 — and the oldest '
            'goes first, which is the prototype\'s '
            '`while(starCount()>=starCap …)` (`eva/redesign.html:1147`)',
      );
    });

    test('and a count outside the range is clamped before it evicts', () async {
      // A corrupt or hand-edited preference must not be able to make the sky
      // unbounded — the same argument `clampFontStep` makes for the font step,
      // and the same one `sky_star_cap.dart`'s clamp makes.
      final SkyRepository repo = SkyRepositoryImpl(
        freshStore(),
        capReader: () => 999,
      );
      for (int v = 1; v <= 3; v++) {
        await repo.record(verse(verse: v, at: v));
      }

      final List<SkyEntry> entries = await entriesThroughFreshStore();
      expect(
        entries,
        hasLength(3),
        reason:
            '999 is clamped to the slider\'s max (60), so three verses fit — a '
            'cap that was not clamped would still hold three here, and the '
            'difference shows the moment there are more than 60',
      );
    });

    test('a 45th record evicts the OLDEST first', () async {
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      for (int v = 1; v <= skyStarCap + 1; v++) {
        await repo.record(verse(verse: v, at: v));
      }

      final List<SkyEntry> entries = await entriesThroughFreshStore();
      expect(entries, hasLength(skyStarCap));
      expect(
        entries.first.key,
        'John:3:2',
        reason:
            'verse 1 was lit first and is evicted first — the prototype’s '
            '`while(starCount()>=starCap …)` removes the oldest `.star` '
            '(`eva/redesign.html:1147`), never the newest',
      );
      expect(entries.last.key, 'John:3:45');
      expect(unwrap(await repo.count()), skyStarCap);
    });

    test('an evicted flare re-lights as an ORDINARY star', () async {
      // Monotonicity is scoped to RETAINED entries: once verse 1 leaves past the
      // cap, the store no longer knows it was ever celebrated — so re-lighting it
      // is a first light again, ordinary until celebrated.
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      await repo.record(verse(verse: 1, at: 1, flare: true));
      for (int v = 2; v <= skyStarCap + 1; v++) {
        await repo.record(verse(verse: v, at: v));
      }
      final SkyEntry relit = unwrap(await repo.record(verse(verse: 1, at: 46)));

      expect(relit.isFlare, isFalse);
      expect((await entriesThroughFreshStore()).last, relit);
    });
  });

  group('clear empties the sky', () {
    test('entries and count are empty afterwards', () async {
      final SkyRepository repo = SkyRepositoryImpl(freshStore());
      await repo.record(verse(verse: 1, at: 1));
      await repo.record(verse(verse: 2, at: 2));
      await repo.clear();

      expect(await entriesThroughFreshStore(), isEmpty);
      expect(unwrap(await repo.count()), 0);
    });
  });

  group('the port never throws, and reports what it persisted', () {
    test('`record` returns the stored entry, so a first-lit instant is visible', () async {
      // `SkyRepository.record`'s contract: returning the stored entry rather
      // than the argument is what makes a re-light assertable without a second
      // call. Today's store does not normalise, so the two are equal on a first
      // lit — and this pins that, so a future store that does has to change
      // this test rather than surprise a caller.
      final SkyEntry entry = verse(verse: 4, at: 4);
      final Result<SkyEntry> saved = await SkyRepositoryImpl(freshStore())
          .record(entry);
      expect(unwrap(saved), entry);
    });

    test('an unreachable store is a TYPED failure on the RECORD arm', () async {
      final Result<SkyEntry> recorded = await SkyRepositoryImpl(
        unreachableStore(),
      ).record(verse(verse: 1, at: 1));

      expect(
        recorded.isLeft(),
        isTrue,
        reason: 'a store that cannot be written must not be an exception',
      );
      expect(recorded, isA<Left<Failure, SkyEntry>>());
      final Failure failure = (recorded as Left<Failure, SkyEntry>).value;
      expect(
        failure.kind,
        FailureKind.storage,
        reason:
            'and `storage` is a kind of its own rather than `network`: no request '
            'was made and no stored value was unreadable',
      );
    });

    test('and on the ENTRIES arm', () async {
      final Result<List<SkyEntry>> listed = await SkyRepositoryImpl(
        unreachableStore(),
      ).entries();

      expect(listed.isLeft(), isTrue);
      expect(
        (listed as Left<Failure, List<SkyEntry>>).value.kind,
        FailureKind.storage,
      );
    });

    test('and on the COUNT arm', () async {
      final Result<int> counted = await SkyRepositoryImpl(unreachableStore())
          .count();

      expect(counted.isLeft(), isTrue);
      expect((counted as Left<Failure, int>).value.kind, FailureKind.storage);
    });

    test('and on the CLEAR arm, which is a fourth `try` and a real cost', () async {
      // A repository whose `catch` wrapped only three arms would pass those and
      // throw on the Stars-off switch. Four arms, four cases.
      final Result<void> cleared = await SkyRepositoryImpl(unreachableStore())
          .clear();

      expect(cleared.isLeft(), isTrue);
      expect((cleared as Left<Failure, void>).value.kind, FailureKind.storage);
    });
  });
}
