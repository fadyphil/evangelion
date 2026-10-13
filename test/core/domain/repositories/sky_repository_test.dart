import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// A port with no adapter yet, over the most honest double available.
///
/// **Keyed by [SkyEntry.key], exactly as the port's doc states:** the first
/// lit wins the position and keeps its [SkyEntry.litAt], a re-record with
/// [SkyEntry.isFlare] set upgrades the stored entry to a flare in place, and
/// the upgrade is monotone — an ordinary re-record never dims a stored
/// flare. A Dart [LinkedHashMap] keeps insertion order, which is lit-event
/// order: the sequence of `record` calls, never a [SkyEntry.litAt] sort — the
/// same order `eva/redesign.html:1153` appends stars in and `:1169` reads
/// them back in.
///
/// It earned this shape: the first version here was a list that only
/// appended, and the dedupe and flare tests failed against it as assertions.
/// That failure is why the rule is stated on the port rather than assumed by
/// it, and this class is the executable half of that statement until the
/// stub adapter exists.
final class RuleSky implements SkyRepository {
  final Map<String, SkyEntry> held = <String, SkyEntry>{};

  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) async {
    final SkyEntry? stored = held[entry.key];
    if (stored == null) {
      held[entry.key] = entry;
      return Right<Failure, SkyEntry>(entry);
    }
    if (entry.isFlare && !stored.isFlare) {
      final SkyEntry flared = stored.copyWith(isFlare: true);
      held[entry.key] = flared;
      return Right<Failure, SkyEntry>(flared);
    }
    return Right<Failure, SkyEntry>(stored);
  }

  @override
  Future<Result<List<SkyEntry>>> entries() async =>
      Right<Failure, List<SkyEntry>>(List<SkyEntry>.of(held.values));

  @override
  Future<Result<int>> count() async => Right<Failure, int>(held.length);

  @override
  Future<Result<void>> clear() async {
    held.clear();
    return const Right<Failure, void>(null);
  }
}

/// A store that cannot be reached, for the Left arm only.
///
/// Every method answers `FailureKind.storage`: the device's own store is
/// unreachable, and nothing inside it was at fault. See the port's LSP row
/// for why that kind and no other.
final class FailingSky implements SkyRepository {
  static const Failure _unreachable = Failure(
    kind: FailureKind.storage,
    message: 'the sky store could not be reached',
  );

  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) async =>
      const Left<Failure, SkyEntry>(_unreachable);

  @override
  Future<Result<List<SkyEntry>>> entries() async =>
      const Left<Failure, List<SkyEntry>>(_unreachable);

  @override
  Future<Result<int>> count() async => const Left<Failure, int>(_unreachable);

  @override
  Future<Result<void>> clear() async => const Left<Failure, void>(_unreachable);
}

/// The value of a [Right], or a named failure saying what came back instead.
///
/// `Result` has no throwing accessor, deliberately — its own doc says "there
/// is no `value` getter and no `getOrNull`". The honest spelling is this
/// exhaustive `switch` over the sealed type: a third arm would not compile.
/// (The same helper `settings_repository_test.dart` carries for the same
/// reason.)
T unwrap<T>(Result<T> result) => switch (result) {
  Right<Failure, T>(:final T value) => value,
  Left<Failure, T>(value: final Failure failure) => throw StateError(
    'expected a success and got ${failure.kind}',
  ),
};

/// `SkyRepository` — the port, over a hand fake.
///
/// Red-first per AGENT_CONTEXT §6 ("use cases" argue the same way a port's
/// contract does: the behaviour is the thing, and the fake is where it is
/// pinned until the adapter exists). Six behaviours, one per contract arm in
/// the port's doc: lit-event order (including out-of-order records), one
/// entry per verse, flare upgrades in place, flare monotonicity, clear
/// empties, and the Left arm propagates.
void main() {
  SkyRepository sky() => RuleSky();

  SkyEntry verse({required int verse, required int at, bool flare = false}) =>
      SkyEntry(
        book: 'John',
        chapter: 3,
        verse: verse,
        isFlare: flare,
        litAt: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
      );

  group('recorded entries come back in lit-event order', () {
    test('three verses lit in order read back in that order', () async {
      final SkyRepository repo = sky();
      await repo.record(verse(verse: 1, at: 1));
      await repo.record(verse(verse: 2, at: 2));
      await repo.record(verse(verse: 3, at: 3));

      expect(unwrap(await repo.entries()).map((SkyEntry e) => e.key), <String>[
        'John:3:1',
        'John:3:2',
        'John:3:3',
      ]);
    });

    test('and the clock does not reorder them', () async {
      // `/reading` lights on scroll, so verse 20 can light before verse 5 is
      // recorded with an earlier instant. Order is the RECORD sequence — the
      // prototype's DOM-append (`eva/redesign.html:1153`) read back in DOM
      // order (`:1169`), evicting oldest-first (`:1147`) — and `litAt` is the
      // audit stamp, not the sort key. A litAt-sorting store would answer
      // `John:3:5` first and fail this.
      final SkyRepository repo = sky();
      await repo.record(verse(verse: 20, at: 20));
      await repo.record(verse(verse: 5, at: 10));

      expect(unwrap(await repo.entries()).map((SkyEntry e) => e.key), <String>[
        'John:3:20',
        'John:3:5',
      ]);
    });
  });

  group('two readings of the same verse produce one entry', () {
    test('a re-lit verse does not append', () async {
      final SkyRepository repo = sky();
      await repo.record(verse(verse: 16, at: 1));
      await repo.record(verse(verse: 16, at: 2));

      expect(unwrap(await repo.entries()), hasLength(1));
      expect(unwrap(await repo.count()), 1);
    });

    test('and the first lit keeps its instant', () async {
      // The constellation draws in lit-event order
      // (`eva/redesign.html:1153` appended, `:1169` read back), so a re-read
      // must not move the star: the stored entry keeps the FIRST `litAt`.
      final SkyRepository repo = sky();
      await repo.record(verse(verse: 16, at: 1));
      final SkyEntry stored = unwrap(
        await repo.record(verse(verse: 16, at: 2)),
      );

      // `record` returns the entry AS STORED — the `SettingsRepository.save`
      // contract, mirrored — so the caller sees the first instant it holds,
      // never having to re-read to find out.
      expect(stored.litAt, verse(verse: 16, at: 1).litAt);
      expect(unwrap(await repo.entries()).single.litAt, stored.litAt);
    });
  });

  group('a flare upgrades in place', () {
    test('an ordinary star brightens without moving', () async {
      // Read (`addStar(false)`, `eva/redesign.html:1217`), then celebrated
      // (`addStar(true)`, `:1123`, `:1330`, `:1428`): one star that
      // brightens, never two stars and never a star that jumps to the end of
      // the polyline.
      final SkyRepository repo = sky();
      await repo.record(verse(verse: 16, at: 1));
      await repo.record(verse(verse: 17, at: 2));
      await repo.record(verse(verse: 16, at: 3, flare: true));

      final List<SkyEntry> entries = unwrap(await repo.entries());
      expect(entries, hasLength(2));
      expect(entries.map((SkyEntry e) => e.key), <String>[
        'John:3:16',
        'John:3:17',
      ]);
      expect(entries.first.isFlare, isTrue);
      expect(entries.first.litAt, verse(verse: 16, at: 1).litAt);
    });

    test(
      'and a stored flare is never dimmed by an ordinary re-record',
      () async {
        // MONOTONE: the upgrade runs one way. A last-write-wins store would
        // hand back an ordinary star here and dim a celebrated moment — the
        // mutation this test exists to catch, observed red against exactly
        // that variant and reverted.
        final SkyRepository repo = sky();
        await repo.record(verse(verse: 16, at: 1, flare: true));
        await repo.record(verse(verse: 17, at: 2));
        final SkyEntry stored = unwrap(
          await repo.record(verse(verse: 16, at: 3)),
        );

        final List<SkyEntry> entries = unwrap(await repo.entries());
        expect(entries, hasLength(2));
        expect(entries.map((SkyEntry e) => e.key), <String>[
          'John:3:16',
          'John:3:17',
        ]);
        expect(stored.isFlare, isTrue);
        expect(entries.first.isFlare, isTrue);
        expect(entries.first.litAt, verse(verse: 16, at: 1).litAt);
      },
    );
  });

  group('clear empties the sky', () {
    test('entries and count are empty afterwards', () async {
      final SkyRepository repo = sky();
      await repo.record(verse(verse: 1, at: 1));
      await repo.record(verse(verse: 2, at: 2));
      await repo.clear();

      expect(unwrap(await repo.entries()), isEmpty);
      expect(unwrap(await repo.count()), 0);
    });
  });

  group('an unreachable store is a typed failure on every arm', () {
    test('record, entries, count and clear all propagate the Left', () async {
      // The one fault a local store has: `FailureKind.storage` — the
      // device-side taxonomy the port names, not `network` (no request was
      // made) and not `serialization` (no value was misread). `RuleSky`
      // stays green; this fake exists so the failure arm is asserted rather
      // than assumed.
      final SkyRepository repo = FailingSky();

      final Result<SkyEntry> recorded = await repo.record(
        verse(verse: 1, at: 1),
      );
      expect(recorded.isLeft(), isTrue);
      expect(
        (recorded as Left<Failure, SkyEntry>).value.kind,
        FailureKind.storage,
      );

      final Result<List<SkyEntry>> listed = await repo.entries();
      expect(listed.isLeft(), isTrue);
      expect(
        (listed as Left<Failure, List<SkyEntry>>).value.kind,
        FailureKind.storage,
      );

      final Result<int> counted = await repo.count();
      expect(counted.isLeft(), isTrue);
      expect((counted as Left<Failure, int>).value.kind, FailureKind.storage);

      final Result<void> cleared = await repo.clear();
      expect(cleared.isLeft(), isTrue);
      expect((cleared as Left<Failure, void>).value.kind, FailureKind.storage);
    });
  });
}
