import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/features/sky/data/datasources/sky_local_data_source.dart';
import 'package:evangelion/features/sky/data/repositories/sky_repository_impl.dart';
import 'package:evangelion/features/sky/domain/sky_star_cap.dart';
import 'package:evangelion/features/sky/presentation/cubit/sky_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repository that keeps the sky and **never answers a write**.
///
/// **The point is the silence.** `SkyCubit.record` emits the optimistic frame
/// *before* it asks the store, and the confirm that follows replaces the frame
/// with the store's answer — so a repository whose `record` never completes is
/// what leaves the **optimistic frame** on screen, which is the half of the
/// cap this file compares against the durable eviction.
///
/// A mock that answered immediately would publish the store's answer instead,
/// and the comparison would be a tautology: the frame would be compared with
/// itself.
final class _SilentRepository implements SkyRepository {
  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) =>
      Completer<Result<SkyEntry>>().future;

  @override
  Future<Result<List<SkyEntry>>> entries() async =>
      const Right<Failure, List<SkyEntry>>(<SkyEntry>[]);

  @override
  Future<Result<int>> count() async => const Right<Failure, int>(0);

  @override
  Future<Result<void>> clear() async => const Right<Failure, void>(null);
}

/// The witness sky's cap — the rule both writers enforce.
///
/// ## THE THREE CLAIMS THIS FILE MAKES, AND NONE OF THEM IS "44 IS A NUMBER"
///
/// 1. **The default is the prototype's** (`eva/redesign.html:1131`), and the
///    preference's own default is the *same* number — the two spellings that
///    cannot be one declaration (`core/domain/` may not name `features/sky/`)
///    are pinned here instead.
/// 2. **The clamp is the cap's rule** — the reader's range, transcribed from
///    the slider, applied to whatever a writer is told.
/// 3. **The two writers agree.** The durable eviction and the optimistic frame
///    are asked the same question with the same cap, and they must answer the
///    same way — which is the whole reason the cap is a seam and not two
///    numbers.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  SkyEntry verse({required int verse, required int at}) => SkyEntry(
    book: 'John',
    chapter: 3,
    verse: verse,
    litAt: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
  );

  group('the default', () {
    test('is the prototype\'s `starCap`: 44', () {
      // `eva/redesign.html:1131` — `starCap=44` — and `:1512` re-pins the
      // control's default to the same number.
      expect(skyStarCap, 44);
    });

    test('and the PREFERENCE\'s default is the same number', () {
      // **The two spellings that cannot be one declaration.**
      // `UserSettings.starCount`'s default lives in `core/domain/`, and this
      // constant lives in `features/sky/domain/` — and AGENT_CONTEXT §3, Gate 2
      // forbids `core/domain/` from naming a feature, so they cannot be one
      // declaration. A test is the only honest way to keep them in step: this
      // one fails the moment either moves.
      expect(
        const UserSettings().starCount,
        skyStarCap,
        reason:
            'the preference\'s default and the cap\'s default are one number '
            'written in two places, and this is what keeps them one number',
      );
    });
  });

  group('the clamp', () {
    test('keeps a chosen count inside the slider\'s range', () {
      // `eva/redesign.html:669` — `min="0" max="60" value="44"`.
      expect(skyStarCapFor(0), 0);
      expect(skyStarCapFor(44), 44);
      expect(skyStarCapFor(60), 60);
    });

    test('and pulls a count from outside it back in', () {
      // A corrupt or hand-edited store must not be able to make the sky
      // unbounded — the same argument `clampFontStep` makes for the font step.
      expect(skyStarCapFor(-5), kStarCountMin);
      expect(skyStarCapFor(999), kStarCountMax);
    });

    test('and the range is the prototype\'s slider', () {
      expect(kStarCountMin, 0);
      expect(kStarCountMax, 60);
    });
  });

  group('the two writers', () {
    test('the eviction and the optimistic frame agree on the cap', () async {
      // ## THE SHAPE, IN ONE ASSERTION
      //
      // `sky_star_cap.dart`'s whole argument is that **two writers must not
      // hold two spellings of one number** — the durable eviction
      // (`SkyRepositoryImpl`) and the optimistic frame (`SkyCubit`) are the two
      // writers, and the cap seam is what makes them one number rather than
      // two. This is the assertion that the seam works: the same cap reader
      // given to both, and the same survivors on both sides.
      const int cap = 3;
      int reader() => cap;

      // The durable half: a real store, a real write, a real eviction.
      final SkyLocalDataSource store = SkyLocalDataSource();
      addTearDown(store.resetForTest);
      final SkyRepositoryImpl durable = SkyRepositoryImpl(
        store,
        capReader: reader,
      );
      for (int v = 1; v <= 5; v++) {
        await durable.record(verse(verse: v, at: v));
      }
      final List<String> evicted = switch (await durable.entries()) {
        Right<Failure, List<SkyEntry>>(:final List<SkyEntry> value) =>
          value.map((SkyEntry e) => e.key).toList(),
        Left<Failure, List<SkyEntry>>(value: final Failure failure) =>
          throw StateError('expected a success and got ${failure.kind}'),
      };

      // The optimistic half: a store that never answers, so the frame the
      // cubit published stays on screen.
      final SkyCubit cubit = SkyCubit(
        repository: _SilentRepository(),
        capReader: reader,
      );
      addTearDown(cubit.close);
      for (int v = 1; v <= 5; v++) {
        // **Not awaited**: the confirm never answers, so awaiting it would
        // hang the test rather than show the frame.
        unawaited(cubit.record(verse(verse: v, at: v)));
      }

      expect(
        cubit.state.entries.map((SkyEntry e) => e.key).toList(),
        evicted,
        reason:
            'the optimistic frame and the durable eviction answer the same '
            'question the same way — the cap is one number, asked through one '
            'seam, and the two writers cannot disagree about it',
      );
      expect(
        evicted,
        <String>['John:3:3', 'John:3:4', 'John:3:5'],
        reason:
            'and the answer itself: past the cap the OLDEST goes first — the '
            'prototype\'s `while(starCount()>=starCap …)` removes the oldest '
            '`.star` (`eva/redesign.html:1147`), never the newest',
      );
    });

    test('and the default cap is the prototype\'s 44', () async {
      // A writer built without a reader is a sky with default settings, and
      // the preference's default is the same number — so the fallback and the
      // preference agree and no reader is asked for.
      final SkyLocalDataSource store = SkyLocalDataSource();
      addTearDown(store.resetForTest);
      final SkyRepositoryImpl durable = SkyRepositoryImpl(store);
      for (int v = 1; v <= skyStarCap + 1; v++) {
        await durable.record(verse(verse: v, at: v));
      }
      final Result<List<SkyEntry>> held = await durable.entries();
      expect(switch (held) {
        Right<Failure, List<SkyEntry>>(:final List<SkyEntry> value) =>
          value.length,
        Left<Failure, List<SkyEntry>>(value: final Failure failure) =>
          throw StateError('expected a success and got ${failure.kind}'),
      }, skyStarCap);
    });
  });
}
