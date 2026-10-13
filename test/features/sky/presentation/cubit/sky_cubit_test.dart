import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/features/sky/domain/sky_star_cap.dart';
import 'package:evangelion/features/sky/presentation/cubit/sky_cubit.dart';
import 'package:evangelion/features/sky/presentation/cubit/sky_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockSkyRepository extends Mock implements SkyRepository {}

/// `SkyCubit` — the witness sky's only writer.
///
/// ## THE THREE THINGS THIS FILE IS ABOUT, AND NONE OF THEM IS "A STAR LIT"
///
/// 1. **The optimistic emit.** A record is announced on the frame the verse lit, so
///    a test that holds the store open and then reads `state` has proved the emit
///    came **first** — the state is already correct before the store has answered.
///    `settings_cubit_test.dart`'s "a write is announced BEFORE the store answers"
///    is the shape this mirrors, gate for gate.
/// 2. **The rollback.** A store that refuses a write must put the sky back where it
///    was, and that is the decision `SettingsCubit`'s doc argues: the state the
///    reader sees is always a state the store has confirmed, except in the one-frame
///    window between the gesture and the write.
/// 3. **The cap.** The prototype evicts the oldest star past `starCap`
///    (`eva/redesign.html:1147`), and the adapter owns the rule — so the cubit
///    proves it surfaces the eviction rather than resurrecting the evicted star on
///    its confirm re-read.
void main() {
  late _MockSkyRepository repository;

  SkyCubit build() {
    final SkyCubit cubit = SkyCubit(repository: repository);
    addTearDown(cubit.close);
    return cubit;
  }

  SkyEntry verse({required int verse, required int at, bool flare = false}) =>
      SkyEntry(
        book: 'John',
        chapter: 3,
        verse: verse,
        isFlare: flare,
        litAt: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
      );

  // mocktail needs a value of the named type to build `any()` for a positional
  // `SkyEntry`. `reading_cubit_test.dart:58` registers the same kind of value for
  // the same reason, and a real instance is the valid one — `SkyEntry` has no
  // const constructor, so it is built here rather than inlined.
  setUpAll(() {
    registerFallbackValue(
      SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 1,
        litAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      ),
    );
  });

  setUp(() {
    repository = _MockSkyRepository();
    when(() => repository.record(any())).thenAnswer(
      (Invocation inv) async =>
          Right<Failure, SkyEntry>(inv.positionalArguments[0] as SkyEntry),
    );
    when(() => repository.entries()).thenAnswer(
      (_) async => const Right<Failure, List<SkyEntry>>(<SkyEntry>[]),
    );
    when(() => repository.count())
        .thenAnswer((_) async => const Right<Failure, int>(0));
    when(() => repository.clear())
        .thenAnswer((_) async => const Right<Failure, void>(null));
  });

  group('the initial state', () {
    test('is loading, and it ALREADY holds an empty sky', () {
      final SkyCubit cubit = build();

      // **The empty list and not a null.** `SettingsState`'s doc gives the
      // measured reason for the same shape there: a screen that reads the sky on
      // every frame — `journey`'s widget draws one number — has no honest answer
      // for "there is nothing yet", so there is no "nothing yet" to represent.
      expect(cubit.state.status, SkyStatus.loading);
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.count, 0);
      expect(cubit.state.failure, isNull);
    });

    test('and the three statuses are distinguishable from "no data"', () {
      expect(SkyStatus.values, <SkyStatus>[
        SkyStatus.loading,
        SkyStatus.ready,
        SkyStatus.failed,
      ]);
    });

    test('and `count` agrees with the entries it carries', () {
      const SkyState state = SkyState(entries: <SkyEntry>[]);
      expect(state.count, state.entries.length);
    });
  });

  group('`load`', () {
    blocTest<SkyCubit, SkyState>(
      'publishes what the store holds and is ready',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 20, at: 20),
            verse(verse: 5, at: 10),
          ]),
        );
      },
      act: (SkyCubit cubit) => cubit.load(),
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[
            verse(verse: 20, at: 20),
            verse(verse: 5, at: 10),
          ],
        ),
      ],
      verify: (SkyCubit cubit) {
        expect(cubit.state.count, 2);
      },
    );

    blocTest<SkyCubit, SkyState>(
      'a failed read keeps the CONFIRMED sky and records the failure',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => const Left<Failure, List<SkyEntry>>(
            Failure(kind: FailureKind.storage, message: 'no store'),
          ),
        );
      },
      act: (SkyCubit cubit) => cubit.load(),
      expect: () => <SkyState>[
        const SkyState(
          status: SkyStatus.failed,
          entries: <SkyEntry>[],
          failure: Failure(kind: FailureKind.storage, message: 'no store'),
        ),
      ],
    );

    blocTest<SkyCubit, SkyState>(
      'a failed re-read does NOT overwrite a sky the cubit already confirmed',
      build: build,
      act: (SkyCubit cubit) async {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 1, at: 1),
          ]),
        );
        await cubit.load();
        when(() => repository.entries()).thenAnswer(
          (_) async => const Left<Failure, List<SkyEntry>>(
            Failure(kind: FailureKind.storage, message: 'the store went away'),
          ),
        );
        await cubit.load();
      },
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[verse(verse: 1, at: 1)],
        ),
        SkyState(
          status: SkyStatus.failed,
          entries: <SkyEntry>[verse(verse: 1, at: 1)],
          failure: const Failure(
            kind: FailureKind.storage,
            message: 'the store went away',
          ),
        ),
      ],
    );
  });

  group('`record` is optimistic', () {
    test('the lit verse is announced BEFORE the store answers', () async {
      final SkyCubit cubit = build();
      final Completer<Result<SkyEntry>> gate = Completer<Result<SkyEntry>>();
      when(() => repository.record(any())).thenAnswer((_) => gate.future);

      final Future<void> pending = cubit.record(verse(verse: 16, at: 1));
      expect(
        cubit.state.entries.map((SkyEntry e) => e.key),
        <String>['John:3:16'],
        reason:
            'the verse lit is answered on the frame it happened; the disk round '
            'trip is not on the critical path',
      );
      expect(
        gate.isCompleted,
        isFalse,
        reason:
            'and the store has still not answered — which is what makes the '
            'assertion above about the EMIT rather than about the write having '
            'finished',
      );

      gate.complete(Right<Failure, SkyEntry>(verse(verse: 16, at: 1)));
      await pending;
      expect(
        cubit.state.status,
        SkyStatus.ready,
        reason:
            'and the write completing is what proves the store is reachable',
      );
    });

    blocTest<SkyCubit, SkyState>(
      'a re-lit verse that changes nothing emits NOTHING and skips the store',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 16, at: 1),
          ]),
        );
      },
      act: (SkyCubit cubit) async {
        await cubit.load();
        // An ordinary re-record of an ordinary star: the first lit wins the
        // position and keeps its instant, so there is nothing to announce — the
        // `SettingsCubit.apply` no-emit rule, restated for a sky where a scroll
        // re-light fires on every pass.
        await cubit.record(verse(verse: 16, at: 2));
      },
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[verse(verse: 16, at: 1)],
        ),
      ],
      verify: (SkyCubit cubit) {
        verifyNever(() => repository.record(any()));
      },
    );

    blocTest<SkyCubit, SkyState>(
      'a flare upgrade brightens in place without moving',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 16, at: 1),
            verse(verse: 17, at: 2),
          ]),
        );
        // The confirm re-read answers the store truth — the flared star — so the
        // double stays consistent with what `record` just stored. A double that
        // kept answering the ordinary star would dim the flare on confirm, which
        // is a lying double rather than the property under test.
        when(() => repository.record(any())).thenAnswer((_) async {
          when(() => repository.entries()).thenAnswer(
            (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
              verse(verse: 16, at: 1, flare: true),
              verse(verse: 17, at: 2),
            ]),
          );
          return Right<Failure, SkyEntry>(verse(verse: 16, at: 1, flare: true));
        });
      },
      act: (SkyCubit cubit) async {
        await cubit.load();
        await cubit.record(verse(verse: 16, at: 3, flare: true));
      },
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[verse(verse: 16, at: 1), verse(verse: 17, at: 2)],
        ),
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[
            verse(verse: 16, at: 1, flare: true),
            verse(verse: 17, at: 2),
          ],
        ),
        // The confirm re-read answers the store truth, which agrees — so the
        // third emit is suppressed by value equality rather than asserted.
      ],
      verify: (SkyCubit cubit) {
        verify(() => repository.record(any())).called(1);
        final SkyState state = cubit.state;
        expect(state.entries.first.isFlare, isTrue);
        expect(state.entries.first.litAt, verse(verse: 16, at: 1).litAt);
      },
    );
  });

  group('a refused write rolls the sky back', () {
    blocTest<SkyCubit, SkyState>(
      'to the last CONFIRMED entries, not to the optimistic ones',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 1, at: 1),
          ]),
        );
        when(() => repository.record(any())).thenAnswer(
          (_) async => const Left<Failure, SkyEntry>(
            Failure(kind: FailureKind.storage, message: 'disk full'),
          ),
        );
      },
      act: (SkyCubit cubit) async {
        await cubit.load();
        await cubit.record(verse(verse: 2, at: 2));
      },
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[verse(verse: 1, at: 1)],
        ),
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[verse(verse: 1, at: 1), verse(verse: 2, at: 2)],
        ),
        // Not const — `SkyEntry` holds a `DateTime` — so the rollback arm is
        // spelled out like the other two rather than canonicalised.
        SkyState(
          status: SkyStatus.failed,
          entries: <SkyEntry>[verse(verse: 1, at: 1)],
          failure: const Failure(
            kind: FailureKind.storage,
            message: 'disk full',
          ),
        ),
      ],
      verify: (SkyCubit cubit) {
        expect(
          cubit.state.entries.map((SkyEntry e) => e.key),
          <String>['John:3:1'],
          reason:
              'the reader is put back where the store says they are. Leaving the '
              'failed star on screen would be a lie — the same reasoning as '
              '`SettingsCubit` discarding the optimistic total.',
        );
        expect(cubit.state.status, SkyStatus.failed);
        expect(cubit.state.failure?.kind, FailureKind.storage);
      },
    );
  });

  group('the cap', () {
    blocTest<SkyCubit, SkyState>(
      'a record past 44 publishes the STORE answer, not the optimistic frame',
      build: build,
      setUp: () {
        final List<SkyEntry> full = <SkyEntry>[
          for (int v = 1; v <= skyStarCap; v++) verse(verse: v, at: v),
        ];
        // The confirm re-read answers a store that evicted a DIFFERENT star than
        // the optimistic frame did — verse 1 stays, verse 2 goes. The disagreement
        // is deliberate, and it is the only shape that distinguishes "published
        // the store answer" from "published its own frame": the previous version
        // of this test had the double agree with the frame, and a mutant that
        // published the frame passed it. A double that agrees here is the
        // unfalsifiable half of the flare test's honesty note below — consistent,
        // but proving nothing about which answer was published.
        final List<SkyEntry> storeAnswered = <SkyEntry>[
          verse(verse: 1, at: 1),
          for (int v = 3; v <= skyStarCap + 1; v++) verse(verse: v, at: v),
        ];
        when(() => repository.entries())
            .thenAnswer((_) async => Right<Failure, List<SkyEntry>>(full));
        when(() => repository.record(any())).thenAnswer((_) async {
          when(() => repository.entries()).thenAnswer(
            (_) async => Right<Failure, List<SkyEntry>>(storeAnswered),
          );
          return Right<Failure, SkyEntry>(verse(verse: skyStarCap + 1, at: 45));
        });
      },
      act: (SkyCubit cubit) async {
        await cubit.load();
        await cubit.record(verse(verse: skyStarCap + 1, at: 45));
      },
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[
            for (int v = 1; v <= skyStarCap; v++) verse(verse: v, at: v),
          ],
        ),
        // The optimistic frame evicted verse 1 — and the THIRD emit below is the
        // property: the cubit publishes the store answer on top of it rather
        // than stopping at its own frame.
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[
            for (int v = 2; v <= skyStarCap + 1; v++) verse(verse: v, at: v),
          ],
        ),
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[
            verse(verse: 1, at: 1),
            for (int v = 3; v <= skyStarCap + 1; v++) verse(verse: v, at: v),
          ],
        ),
      ],
      verify: (SkyCubit cubit) {
        expect(cubit.state.entries, hasLength(skyStarCap));
        expect(
          cubit.state.entries.first.key,
          'John:3:1',
          reason:
              'the store kept verse 1 and dropped verse 2, and the published sky '
              'is the STORE answer — an optimistic frame would open with '
              '`John:3:2`. A publish-the-frame mutant fails here twice over: the '
              'third emit never fires, and the survivor is the wrong star.',
        );
        expect(cubit.state.entries.last.key, 'John:3:45');
        expect(cubit.state.status, SkyStatus.ready);
      },
    );
  });

  group('`clear`', () {
    blocTest<SkyCubit, SkyState>(
      'empties the sky: the Stars-off switch',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 1, at: 1),
            verse(verse: 2, at: 2),
          ]),
        );
      },
      act: (SkyCubit cubit) async {
        await cubit.load();
        await cubit.clear();
      },
      expect: () => <SkyState>[
        SkyState(
          status: SkyStatus.ready,
          entries: <SkyEntry>[verse(verse: 1, at: 1), verse(verse: 2, at: 2)],
        ),
        const SkyState(status: SkyStatus.ready, entries: <SkyEntry>[]),
      ],
      verify: (SkyCubit cubit) {
        verify(() => repository.clear()).called(1);
        expect(cubit.state.count, 0);
      },
    );

    blocTest<SkyCubit, SkyState>(
      'a refused clear rolls the sky back',
      build: build,
      setUp: () {
        when(() => repository.entries()).thenAnswer(
          (_) async => Right<Failure, List<SkyEntry>>(<SkyEntry>[
            verse(verse: 1, at: 1),
          ]),
        );
        when(() => repository.clear()).thenAnswer(
          (_) async => const Left<Failure, void>(
            Failure(kind: FailureKind.storage, message: 'disk full'),
          ),
        );
      },
      act: (SkyCubit cubit) async {
        await cubit.load();
        await cubit.clear();
      },
      verify: (SkyCubit cubit) {
        expect(
          cubit.state.entries.map((SkyEntry e) => e.key),
          <String>['John:3:1'],
          reason:
              'the clear did not happen, so the stars stay — a Stars-off switch '
              'that emptied the screen without emptying the store would lie until '
              'the next launch',
        );
        expect(cubit.state.status, SkyStatus.failed);
        expect(cubit.state.failure?.kind, FailureKind.storage);
      },
    );
  });
}
