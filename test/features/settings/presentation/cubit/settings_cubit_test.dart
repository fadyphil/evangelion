import 'dart:async';

import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
// **The design system's own `CurtainShape` is HIDDEN**: see the note in
// `settings_cubit.dart`'s own import block. The design system declares a
// `CurtainShape` for the **scrim** and the domain declares one for the **aurora
// curtain**, and a file that imports both gets an ambiguous-name error.
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:evangelion/features/settings/domain/settings_clamps.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/settings_harness.dart';

/// `SettingsCubit` — the app-wide preferences' only writer.
///
/// ## THE THREE THINGS THIS FILE IS ABOUT, AND NONE OF THEM IS "A BOOLEAN FLIPPED"
///
/// 1. **The clamp.** `SettingsCubit` is the **only** place in the app where
///    `clampFontStep` is applied to a value on its way into the state, and the stored
///    value is asserted as well as the in-memory one — a clamp that only lived in the
///    cubit would still leave `99` on disk.
/// 2. **The optimistic emit.** A write is announced on the frame the reader acted, so a
///    test that awaits the setter and then reads `state` has proved the emit came
///    **first** — the state is already correct before the store has answered.
/// 3. **The rollback.** A store that refuses a write must put the reader back where they
///    were, and that is a decision `SettingsCubit`'s doc argues rather than leaves to a
///    test to discover.
void main() {
  late SettingsHarness harness;

  /// The repository a failing test swaps in.
  ///
  /// Hand-written rather than `mocktail` for the reason `app_harness.dart` records: "a
  /// mock implements whatever it is told to, so it can satisfy the port and answer
  /// nothing". It answers a failure for **every** call, which is what a store that is
  /// entirely unreachable does.
  SettingsRepository failingRepository(Failure failure) =>
      _AlwaysFailsRepository(failure);

  group('the initial state', () {
    test('is loading, and it ALREADY holds the defaults', () {
      // `loadImmediately: false`, so nothing has answered yet — the property under test
      // is what the state says *before* the store does.
      final SettingsHarness fresh = settingsHarness(loadImmediately: false);

      // **The defaults and not a null.** `SettingsState`'s doc gives the measured
      // reason: `app.dart` reads the palette on every frame and a `MaterialApp` with no
      // palette is not a state this app can render, so there is no "nothing yet" to
      // represent.
      expect(fresh.cubit.state.status, SettingsStatus.loading);
      expect(fresh.cubit.state.settings, const UserSettings());
      expect(fresh.cubit.state.failure, isNull);
    });

    test('and the two statuses are distinguishable from "no data"', () {
      // `ReadingStatus`'s doc is the argument: "loading" is not "no data", and a
      // two-value enum has to encode it as one.
      expect(SettingsStatus.values, <SettingsStatus>[
        SettingsStatus.loading,
        SettingsStatus.ready,
        SettingsStatus.failed,
      ]);
    });
  });

  group('`load`', () {
    test('publishes what the store holds and is ready', () async {
      harness = settingsHarness(
        initial: const UserSettings(
          themeMode: AppThemeMode.light,
          fontStep: 5,
          language: ReadingLanguage.arabic,
          reducedMotion: true,
        ),
      );
      await harness.cubit.load();

      expect(harness.cubit.state.status, SettingsStatus.ready);
      expect(
        harness.cubit.state.settings,
        const UserSettings(
          themeMode: AppThemeMode.light,
          fontStep: 5,
          language: ReadingLanguage.arabic,
          reducedMotion: true,
        ),
      );
      expect(harness.cubit.state.failure, isNull);
    });

    test('a failed read keeps the DEFAULTS and records the failure', () async {
      // The harness is pumped and **not** named: this arm builds its **own** cubit over
      // a failing repository, and the harness is here only for its two side effects —
      // the mock store and the locator teardown. `loadImmediately: false` and **no
      // `close()`**, because the harness's convenience load is unawaited and closing a
      // cubit underneath it makes the resolve emit into a closed bloc — measured, and it
      // surfaced as "Cannot emit new states after calling close" from a line that has
      // nothing to do with the property under test.
      settingsHarness(loadImmediately: false);
      final SettingsCubit cubit = SettingsCubit(
        getSettings: GetSettings(
          failingRepository(
            const Failure(kind: FailureKind.storage, message: 'no store'),
          ),
        ),
        updateSettings: const UpdateSettings(
          _AlwaysFailsRepository(
            Failure(
              kind: FailureKind.storage,
              message: 'the write arm is unused',
            ),
          ),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, SettingsStatus.failed);
      expect(
        cubit.state.settings,
        const UserSettings(),
        reason:
            'the app still renders, in its defaults. A `SettingsState` that emptied '
            'itself here would leave `MaterialApp` with no palette.',
      );
      expect(cubit.state.failure?.kind, FailureKind.storage);
    });

    test(
      'a failed read does NOT overwrite a value the cubit already confirmed',
      () async {
        // Seed the store with `light` so the FIRST read confirms it, and read twice
        // through the **same** cubit.
        //
        // The first version of this test built a second cubit over a failing
        // repository, which proves nothing: a fresh cubit has no confirmed value, so
        // the assertion could not distinguish "kept" from "defaulted" — and it did, by
        // failing. `GetSettings` is fixed at construction, so "the store worked at
        // launch and has since stopped" is only expressible through a repository whose
        // answer the test controls.
        harness = settingsHarness(
          initial: const UserSettings(themeMode: AppThemeMode.light),
          loadImmediately: false,
        );
        final _SwitchableRepository switchable = _SwitchableRepository(
          harness.repository,
        );
        final SettingsCubit cubit = SettingsCubit(
          getSettings: GetSettings(switchable),
          updateSettings: UpdateSettings(switchable),
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(
          cubit.state.settings.themeMode,
          AppThemeMode.light,
          reason: 'the store is reachable and holds `light`',
        );

        // Now it stops answering.
        switchable.delegate = const _AlwaysFailsRepository(
          Failure(kind: FailureKind.storage, message: 'the store went away'),
        );
        await cubit.load();

        expect(
          cubit.state.settings.themeMode,
          AppThemeMode.light,
          reason:
              'the last confirmed value is the honest answer. Blanking it back to the '
              'default would make a transient store failure undo a choice the reader '
              'made seconds ago — and nothing on screen says so.',
        );
        expect(cubit.state.status, SettingsStatus.failed);
      },
    );
  });

  group('the four setters, and the CLAMP that only lives here', () {
    test('each one changes exactly its own field', () async {
      harness = settingsHarness();
      const UserSettings before = UserSettings();

      await harness.cubit.setThemeMode(AppThemeMode.system);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.system);
      expect(harness.cubit.state.settings.fontStep, before.fontStep);

      await harness.cubit.setFontStep(5);
      expect(harness.cubit.state.settings.fontStep, 5);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.system);

      await harness.cubit.setLanguage(ReadingLanguage.arabic);
      expect(harness.cubit.state.settings.language, ReadingLanguage.arabic);
      expect(harness.cubit.state.settings.fontStep, 5);

      await harness.cubit.setReducedMotion(reduced: true);
      expect(harness.cubit.state.settings.reducedMotion, isTrue);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.system);
    });

    test('an out-of-range step is CLAMPED, in the state AND on disk', () async {
      harness = settingsHarness();

      await harness.cubit.setFontStep(0);
      expect(harness.cubit.state.settings.fontStep, kFontStepMin);
      await harness.cubit.setFontStep(99);
      expect(harness.cubit.state.settings.fontStep, kFontStepMax);

      // **The disk half, and it is the half a state-only assertion misses.** A clamp in
      // the cubit with no clamp in the store leaves `99` written, so a second app launch
      // reads `99` back — and `SettingsRepository` deliberately does not clamp, because
      // `clampFontStep` is a widget-layer function this layer cannot reach.
      //
      // Read through a **fresh** data source so the answer cannot come from the
      // cubit's own memoised store instance.
      expect(
        (await SettingsRepositoryImpl(
          SettingsLocalDataSource(),
        ).load()).successValue.fontStep,
        kFontStepMax,
      );
    });

    test('and it is the boundary the DESIGN SYSTEM names', () {
      // The requirement `clampFontStep`'s doc states: a value outside the table would
      // reach `evaScalerFor`'s `_` arm as 1.22x while the stepper's knob sat at a
      // position no step owns. Asserted against the design-system function, not against
      // a literal, so a table that moves drags this with it.
      expect(clampFontStep(0), kFontStepMin);
      expect(clampFontStep(99), kFontStepMax);
      expect(clampFontStep(3), 3);
    });

    test('setting a value it already has emits NOTHING', () async {
      // `ReadingCubit.setFontStep`'s rule, and it matters MORE here: `app.dart`
      // rebuilds the entire app on every settings emit, so an emit that changes nothing
      // is a full rebuild that changes nothing.
      // `loadImmediately: false` and an explicit `await`, so the subscription starts
      // **after** the load has announced itself. The harness's convenience load is
      // unawaited by design (`SharedPreferences` is async), and a listener attached
      // before it resolves records two `loading`/`ready` emissions that have nothing to
      // do with the property under test.
      harness = settingsHarness(loadImmediately: false);
      await harness.cubit.load();
      final List<SettingsState> seen = <SettingsState>[];
      final StreamSubscription<SettingsState> sub = harness.cubit.stream.listen(
        seen.add,
      );
      addTearDown(sub.cancel);

      await harness.cubit.setThemeMode(AppThemeMode.dark);
      expect(
        seen,
        isEmpty,
        reason: 'the default IS `dark`, so nothing changed and nothing is announced',
      );

      await harness.cubit.setThemeMode(AppThemeMode.light);
      expect(seen, hasLength(1));

      await harness.cubit.setThemeMode(AppThemeMode.light);
      expect(
        seen,
        hasLength(1),
        reason: 'and repeating it still announces nothing',
      );
    });

    test('a write is announced BEFORE the store answers', () async {
      // The optimistic emit, asserted as an ordering rather than as a value: the
      // repository holds the write open, and the state must already be correct.
      harness = settingsHarness();
      final Completer<Result<UserSettings>> gate =
          Completer<Result<UserSettings>>();
      final _GatedRepository gated = _GatedRepository(gate);
      final SettingsCubit cubit = SettingsCubit(
        getSettings: GetSettings(harness.repository),
        updateSettings: UpdateSettings(gated),
      );
      gated.inner = harness.repository;
      addTearDown(cubit.close);
      await cubit.load();

      final Future<void> pending = cubit.setThemeMode(AppThemeMode.light);
      expect(
        cubit.state.settings.themeMode,
        AppThemeMode.light,
        reason:
            'the reader\'s gesture is answered on the frame it happened; the disk '
            'round trip is not on the critical path',
      );
      expect(
        gate.isCompleted,
        isFalse,
        reason:
            'and the store has still not answered — which is what makes the assertion '
            'above about the EMIT rather than about the write having finished',
      );

      gate.complete(Result<UserSettings>.of(cubit.state.settings));
      await pending;
      expect(
        cubit.state.status,
        SettingsStatus.ready,
        reason:
            'and the write completing is what proves the store is reachable',
      );
    });
  });

  group('a refused write rolls the reader back', () {
    test('to the last CONFIRMED value, not to the optimistic one', () async {
      harness = settingsHarness();
      await harness.cubit.setThemeMode(AppThemeMode.light);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.light);

      // The cubit is rebuilt over a store that refuses the *next* write, so the
      // rollback target is a value the store has actually confirmed.
      final SettingsCubit cubit = SettingsCubit(
        getSettings: GetSettings(harness.repository),
        updateSettings: UpdateSettings(
          failingRepository(
            const Failure(kind: FailureKind.storage, message: 'disk full'),
          ),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.settings.themeMode, AppThemeMode.light);

      await cubit.setThemeMode(AppThemeMode.system);

      expect(
        cubit.state.settings.themeMode,
        AppThemeMode.light,
        reason:
            'the reader is put back where the store says they are. Rolling back to the '
            'optimistic value would be a rollback to nothing, and leaving the failed '
            'value on screen would be a lie — the same reasoning as a failed form '
            'submission discarding the optimistic total.',
      );
      expect(cubit.state.status, SettingsStatus.failed);
      expect(cubit.state.failure?.kind, FailureKind.storage);
    });

    test('and the rollback leaves the DISK untouched', () async {
      harness = settingsHarness();
      final SettingsCubit cubit = SettingsCubit(
        getSettings: GetSettings(harness.repository),
        updateSettings: UpdateSettings(
          failingRepository(
            const Failure(kind: FailureKind.storage, message: 'disk full'),
          ),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setThemeMode(AppThemeMode.system);

      expect(
        (await SettingsRepositoryImpl(
          SettingsLocalDataSource(),
        ).load()).successValue.themeMode,
        AppThemeMode.dark,
        reason:
            'the store was never written, so the next launch agrees with the rollback. '
            'A write that half-happened would disagree with both.',
      );
    });
  });

  group('the handle is a projection, not a second holder', () {
    test('it reads through to the cubit and writes through it', () async {
      harness = settingsHarness();
      final SettingsHandle handle = harness.handle;

      expect(handle.settings, harness.cubit.state.settings);
      await handle.setFontStep(4);
      expect(harness.cubit.state.settings.fontStep, 4);
      // **The table, called from the test rather than through the handle.**
      // `SettingsHandle.fontScale` was a convenience getter that restated `evaScalerFor`,
      // and it is gone: it needed `core/design_system`, which imports Flutter, and the
      // handle has to stay pure for `injection_test.dart`'s composition-root gate. So a
      // test that wants the factor reads the table directly — which is the better
      // assertion anyway, because the claim is then "this is the table's row" and not
      // "the handle agrees with itself".
      expect(
        evaScalerFor(handle.settings.fontStep).scale(1),
        closeTo(1.10, 0.0001),
      );

      await handle.setThemeMode(AppThemeMode.system);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.system);

      await handle.setLanguage(ReadingLanguage.arabic);
      expect(harness.cubit.state.settings.language, ReadingLanguage.arabic);

      await handle.setReducedMotion(reduced: true);
      expect(harness.cubit.state.settings.reducedMotion, isTrue);

      await handle.setVeilWitnesses(veiled: true);
      expect(harness.cubit.state.settings.veilWitnesses, isTrue);

      await handle.setShowPodium(shown: false);
      expect(harness.cubit.state.settings.showPodium, isFalse);
    });

    test(
      'the written step is the table\'s own row, at every position',
      () async {
        // Rewritten when `SettingsHandle.fontScale` was deleted from the pure half of the
        // split. The loop is unchanged in what it proves — **every** step the reader can
        // choose maps to the design system's row, not to a number copied into a getter —
        // and it is now a claim about `evaScalerFor` read through `handle.settings`, which
        // is the same value the app-wide `EvaTypeScale` installs.
        harness = settingsHarness();
        for (int s = kFontStepMin; s <= kFontStepMax; s++) {
          await harness.handle.setFontStep(s);
          expect(
            evaScalerFor(harness.handle.settings.fontStep).scale(1),
            closeTo(evaScalerFor(s).scale(1), 0.0001),
            reason: 'step $s',
          );
        }
      },
    );
  });

  group('the twenty-four Workshop writers', () {
    for (final _Writer writer in _writers) {
      test(
        '${writer.name} lands its value, announces ONE state, and reaches the disk',
        () async {
          harness = settingsHarness(loadImmediately: false);
          await harness.cubit.load();

          final List<SettingsState> seen = <SettingsState>[];
          final StreamSubscription<SettingsState> sub = harness.cubit.stream
              .listen(seen.add);
          addTearDown(sub.cancel);

          await writer.write(harness.cubit);

          expect(
            writer.read(harness.cubit.state.settings),
            writer.expected,
            reason: 'the value must land in the state',
          );
          expect(
            seen,
            hasLength(1),
            reason:
                'one writer is one `apply`, and `apply` emits once — the confirmed '
                'emit that follows the write is identical and the cubit suppresses it',
          );
          expect(
            writer.read(seen.single.settings),
            writer.expected,
            reason: 'and the announced state carries the value',
          );
          expect(
            writer.read(
              (await SettingsRepositoryImpl(
                SettingsLocalDataSource(),
              ).load()).successValue,
            ),
            writer.expected,
            reason: 'and the value reached the disk',
          );
        },
      );
    }
  });

  group('the eight RANGED writers clamp on the way in', () {
    for (final _RangedWriter ranged in _rangedWriters) {
      test(
        '${ranged.name} pulls an out-of-range value into its table',
        () async {
          harness = settingsHarness(loadImmediately: false);
          await harness.cubit.load();

          await ranged.low(harness.cubit);
          expect(
            ranged.read(harness.cubit.state.settings),
            ranged.min,
            reason: 'a value below the minimum must land on the minimum',
          );
          expect(
            ranged.read(
              (await SettingsRepositoryImpl(
                SettingsLocalDataSource(),
              ).load()).successValue,
            ),
            ranged.min,
            reason:
                'and the DISK half, which a state-only assertion misses: a clamp in the '
                'cubit with no clamp in the store leaves the raw value written, and a '
                'second app launch reads it back',
          );

          await ranged.high(harness.cubit);
          expect(
            ranged.read(harness.cubit.state.settings),
            ranged.max,
            reason: 'a value above the maximum must land on the maximum',
          );
          expect(
            ranged.read(
              (await SettingsRepositoryImpl(
                SettingsLocalDataSource(),
              ).load()).successValue,
            ),
            ranged.max,
          );
        },
      );
    }

    test(
      'and the SELAH is the one that lands only on multiples of five',
      () async {
        harness = settingsHarness(loadImmediately: false);
        await harness.cubit.load();

        await harness.cubit.setSelahLengthSec(63);
        expect(
          harness.cubit.state.settings.selahLengthSec,
          65,
          reason:
              'the prototype\'s only stepped slider (`eva/redesign.html:684`, '
              '`step="5"`), so 63 snaps to the nearer 65',
        );
        await harness.cubit.setSelahLengthSec(62);
        expect(harness.cubit.state.settings.selahLengthSec, 60);
      },
    );
  });

  group('`setDaylight` and the `system` arm it can never write', () {
    test('on writes `light` and off writes `dark`', () async {
      harness = settingsHarness(loadImmediately: false);
      await harness.cubit.load();

      await harness.cubit.setDaylight(daylight: true);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.light);

      await harness.cubit.setDaylight(daylight: false);
      expect(harness.cubit.state.settings.themeMode, AppThemeMode.dark);
    });

    test('and it NEVER writes `system`, so a stored `system` is narrowed on touch', () async {
      harness = settingsHarness(loadImmediately: false);
      await harness.cubit.load();

      await harness.cubit.setThemeMode(AppThemeMode.system);
      expect(
        harness.cubit.state.settings.themeMode,
        AppThemeMode.system,
        reason:
            'a stored `system` survives until the reader touches the control',
      );

      await harness.cubit.setDaylight(daylight: true);
      expect(
        harness.cubit.state.settings.themeMode,
        AppThemeMode.light,
        reason:
            'and touching it narrows the choice for good — the `system` arm becomes '
            'unreachable from the UI. That is a recorded decision, not drift.',
      );
      expect(
        (await SettingsRepositoryImpl(
          SettingsLocalDataSource(),
        ).load()).successValue.themeMode,
        AppThemeMode.light,
        reason: 'and the disk agrees',
      );
    });
  });

  group('`restoreDefaults` — the prototype\'s `resetLight`', () {
    test('resets EVERY field the prototype resets, to its literal', () async {
      harness = settingsHarness(loadImmediately: false);
      await harness.store.write(_resetSeed);
      await harness.cubit.load();

      await harness.cubit.restoreDefaults();

      for (final _ResetCase resetCase in _resetCases) {
        expect(
          resetCase.read(harness.cubit.state.settings),
          resetCase.expected,
          reason:
              '${resetCase.name} must be reset to its prototype literal '
              '(${resetCase.line})',
        );
      }
    });

    test('and changes NOTHING the prototype leaves alone', () async {
      harness = settingsHarness(loadImmediately: false);
      await harness.store.write(_resetSeed);
      await harness.cubit.load();

      await harness.cubit.restoreDefaults();

      for (final _ResetCase untouched in _untouchedCases) {
        expect(
          untouched.read(harness.cubit.state.settings),
          untouched.expected,
          reason:
              '${untouched.name} must survive the reset (${untouched.line}) — the '
              'prototype\'s handler touches neither `setCalm` nor `setHap`',
        );
      }
    });

    test('and the DISK holds the same twenty-nine fields', () async {
      harness = settingsHarness(loadImmediately: false);
      await harness.store.write(_resetSeed);
      await harness.cubit.load();

      await harness.cubit.restoreDefaults();

      final UserSettings stored = (await SettingsRepositoryImpl(
        SettingsLocalDataSource(),
      ).load()).successValue;

      for (final _ResetCase resetCase in _resetCases) {
        expect(
          resetCase.read(stored),
          resetCase.expected,
          reason:
              '${resetCase.name} must be on the disk at its prototype literal '
              '(${resetCase.line}) — the state and the store are two answers to one '
              'question and they must agree',
        );
      }
      for (final _ResetCase untouched in _untouchedCases) {
        expect(
          untouched.read(stored),
          untouched.expected,
          reason:
              '${untouched.name} must be on the disk unchanged too '
              '(${untouched.line})',
        );
      }
      expect(
        stored,
        harness.cubit.state.settings,
        reason: 'and the two records are the same record',
      );
    });

    test('and it is ONE emit and ONE write, not twenty-three', () async {
      harness = settingsHarness(loadImmediately: false);
      await harness.store.write(_resetSeed);

      final _CountingRepository counting = _CountingRepository(
        harness.repository,
      );
      final SettingsCubit cubit = SettingsCubit(
        getSettings: GetSettings(counting),
        updateSettings: UpdateSettings(counting),
      );
      addTearDown(cubit.close);
      await cubit.load();

      final List<SettingsState> seen = <SettingsState>[];
      final StreamSubscription<SettingsState> sub = cubit.stream.listen(
        seen.add,
      );
      addTearDown(sub.cancel);

      await cubit.restoreDefaults();

      expect(
        seen,
        hasLength(1),
        reason:
            'one `apply` emits once. Twenty-three would emit twenty-three times, and '
            '`app.dart` rebuilds the whole app on every settings emit',
      );
      expect(
        counting.saves,
        1,
        reason:
            'and it writes once. Twenty-three would write twenty-three times.',
      );
    });
  });
}

/// The value of a [Success], for the two disk assertions.
///
/// **An extension and not a member**, because `Result` deliberately has none: its own
/// doc says "there is no `value` getter and no `getOrNull`", because either would let a
/// caller turn a [Failure] into a `null` that surfaces three frames later. A
/// test-local extension keeps the production type's shape unchanged and still cannot
/// compile against a third arm, because the `switch` is exhaustive.
extension _SuccessValue on Result<UserSettings> {
  UserSettings get successValue => switch (this) {
    Right<Failure, UserSettings>(:final UserSettings value) => value,
    Left<Failure, UserSettings>(value: final failure) => throw StateError(
      'expected a success and got ${failure.kind}',
    ),
  };
}

/// A [SettingsRepository] that answers a failure for every call.
final class _AlwaysFailsRepository implements SettingsRepository {
  const _AlwaysFailsRepository(this._failure);

  final Failure _failure;

  @override
  Future<Result<UserSettings>> load() async =>
      Result<UserSettings>.left(_failure);

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async =>
      Result<UserSettings>.left(_failure);
}

/// A repository whose writes park until [gate] completes.
///
/// **Answers `load` for real**, through [inner], because the case under test needs a
/// `ready` cubit before the gated write. The first version made `load` a
/// `Future.error`, which is an *unhandled* asynchronous error rather than a failure, and
/// the test then read a cubit whose status had never moved off `loading` — so the
/// ordering assertion it was written for never got to run.
///
/// [inner] is a mutable field rather than a constructor argument because the harness's
/// repository does not exist until `settingsHarness()` has run, and the gate has to be
/// built before the cubit that uses it.
final class _GatedRepository implements SettingsRepository {
  _GatedRepository(this._gate);

  final Completer<Result<UserSettings>> _gate;

  /// The real repository behind [load]. Assigned by the test right after construction.
  late final SettingsRepository inner;

  @override
  Future<Result<UserSettings>> load() => inner.load();

  @override
  Future<Result<UserSettings>> save(UserSettings settings) => _gate.future;
}

/// A repository whose delegate the test swaps mid-run.
///
/// `GetSettings` and `UpdateSettings` are fixed at [SettingsCubit]'s construction, so
/// "the store worked at launch and has since stopped" is only expressible through a
/// repository whose answer the test controls. [delegate] is mutable for that reason and
/// the field's doc is this sentence.
final class _SwitchableRepository implements SettingsRepository {
  _SwitchableRepository(this.delegate);

  SettingsRepository delegate;

  @override
  Future<Result<UserSettings>> load() => delegate.load();

  @override
  Future<Result<UserSettings>> save(UserSettings settings) =>
      delegate.save(settings);
}

/// One of the twenty-four Workshop writers, and the field it writes.
///
/// **A top-level class and not a local one**, because Dart has no local classes.
final class _Writer {
  const _Writer({
    required this.name,
    required this.write,
    required this.read,
    required this.expected,
  });

  /// The writer's own name, for the test heading.
  final String name;

  /// The writer itself.
  final Future<void> Function(SettingsCubit) write;

  /// Reads the written field out of a record.
  final Object? Function(UserSettings) read;

  /// The value the writer must land.
  final Object? expected;
}

/// One of the eight **ranged** writers, and the table it must land in.
final class _RangedWriter {
  const _RangedWriter({
    required this.name,
    required this.low,
    required this.high,
    required this.min,
    required this.max,
    required this.read,
  });

  /// The writer's own name, for the test heading.
  final String name;

  /// A call that writes a value **below** the range.
  final Future<void> Function(SettingsCubit) low;

  /// A call that writes a value **above** the range.
  final Future<void> Function(SettingsCubit) high;

  /// The prototype's `min`.
  final int min;

  /// The prototype's `max`.
  final int max;

  /// Reads the written field out of a record.
  final int Function(UserSettings) read;
}

/// One field of the reset: what it must become, or what it must stay, and the
/// prototype line it is transcribed from.
final class _ResetCase {
  const _ResetCase(this.name, this.read, this.expected, this.line);

  /// The field's own name.
  final String name;

  /// Reads the field out of a record.
  final Object? Function(UserSettings) read;

  /// The value the field must hold afterwards.
  final Object? expected;

  /// The prototype's own line, so **every** row of the table carries its citation.
  final String line;
}

/// The twenty-four writers, each with a value that **differs from its default**.
///
/// **A value that differs is the whole point**: `apply` announces nothing when the
/// value does not change, so a writer tested with the default would prove only
/// that it did nothing.
final List<_Writer> _writers = <_Writer>[
  _Writer(
    name: 'setShaderEnabled',
    write: (SettingsCubit c) => c.setShaderEnabled(enabled: false),
    read: (UserSettings s) => s.shaderEnabled,
    expected: false,
  ),
  _Writer(
    name: 'setCurtainShape',
    write: (SettingsCubit c) => c.setCurtainShape(CurtainShape.shafts),
    read: (UserSettings s) => s.curtainShape,
    expected: CurtainShape.shafts,
  ),
  _Writer(
    name: 'setReach',
    write: (SettingsCubit c) => c.setReach(60),
    read: (UserSettings s) => s.reach,
    expected: 60,
  ),
  _Writer(
    name: 'setGlow',
    write: (SettingsCubit c) => c.setGlow(120),
    read: (UserSettings s) => s.glow,
    expected: 120,
  ),
  _Writer(
    name: 'setTouchGlow',
    write: (SettingsCubit c) => c.setTouchGlow(10),
    read: (UserSettings s) => s.touchGlow,
    expected: 10,
  ),
  _Writer(
    name: 'setHue',
    write: (SettingsCubit c) => c.setHue(200),
    read: (UserSettings s) => s.hue,
    expected: 200,
  ),
  _Writer(
    name: 'setMultichromeMelt',
    write: (SettingsCubit c) => c.setMultichromeMelt(melting: true),
    read: (UserSettings s) => s.multichromeMelt,
    expected: true,
  ),
  _Writer(
    name: 'setRayCombing',
    write: (SettingsCubit c) => c.setRayCombing(combing: false),
    read: (UserSettings s) => s.rayCombing,
    expected: false,
  ),
  _Writer(
    name: 'setWhiteCores',
    write: (SettingsCubit c) => c.setWhiteCores(white: false),
    read: (UserSettings s) => s.whiteCores,
    expected: false,
  ),
  _Writer(
    name: 'setDotVeil',
    write: (SettingsCubit c) => c.setDotVeil(veiled: true),
    read: (UserSettings s) => s.dotVeil,
    expected: true,
  ),
  _Writer(
    name: 'setStarsOn',
    write: (SettingsCubit c) => c.setStarsOn(on: false),
    read: (UserSettings s) => s.starsOn,
    expected: false,
  ),
  _Writer(
    name: 'setConstellationsOn',
    write: (SettingsCubit c) => c.setConstellationsOn(on: false),
    read: (UserSettings s) => s.constellationsOn,
    expected: false,
  ),
  _Writer(
    name: 'setStarCount',
    write: (SettingsCubit c) => c.setStarCount(20),
    read: (UserSettings s) => s.starCount,
    expected: 20,
  ),
  _Writer(
    name: 'setStarBrightness',
    write: (SettingsCubit c) => c.setStarBrightness(130),
    read: (UserSettings s) => s.starBrightness,
    expected: 130,
  ),
  _Writer(
    name: 'setStarShape',
    write: (SettingsCubit c) => c.setStarShape(SkyStarShape.star),
    read: (UserSettings s) => s.starShape,
    expected: SkyStarShape.star,
  ),
  _Writer(
    name: 'setStarField',
    write: (SettingsCubit c) => c.setStarField(SkyStarField.full),
    read: (UserSettings s) => s.starField,
    expected: SkyStarField.full,
  ),
  _Writer(
    name: 'setTwinkle',
    write: (SettingsCubit c) => c.setTwinkle(twinkling: false),
    read: (UserSettings s) => s.twinkle,
    expected: false,
  ),
  _Writer(
    name: 'setFocusDelaySec',
    write: (SettingsCubit c) => c.setFocusDelaySec(9),
    read: (UserSettings s) => s.focusDelaySec,
    expected: 9,
  ),
  _Writer(
    name: 'setSelahLengthSec',
    write: (SettingsCubit c) => c.setSelahLengthSec(30),
    read: (UserSettings s) => s.selahLengthSec,
    expected: 30,
  ),
  _Writer(
    name: 'setBreathGuide',
    write: (SettingsCubit c) => c.setBreathGuide(on: false),
    read: (UserSettings s) => s.breathGuide,
    expected: false,
  ),
  _Writer(
    name: 'setVespersAutoDim',
    write: (SettingsCubit c) => c.setVespersAutoDim(on: false),
    read: (UserSettings s) => s.vespersAutoDim,
    expected: false,
  ),
  _Writer(
    name: 'setCalmMotion',
    write: (SettingsCubit c) => c.setCalmMotion(calm: true),
    read: (UserSettings s) => s.calmMotion,
    expected: true,
  ),
  _Writer(
    name: 'setHaptics',
    write: (SettingsCubit c) => c.setHaptics(on: false),
    read: (UserSettings s) => s.haptics,
    expected: false,
  ),
  _Writer(
    name: 'setDaylight',
    write: (SettingsCubit c) => c.setDaylight(daylight: true),
    read: (UserSettings s) => s.themeMode,
    expected: AppThemeMode.light,
  ),
];

/// The eight ranged writers and the prototype's table each one lands in.
final List<_RangedWriter> _rangedWriters = <_RangedWriter>[
  _RangedWriter(
    name: 'setReach',
    low: (SettingsCubit c) => c.setReach(0),
    high: (SettingsCubit c) => c.setReach(999),
    min: kReachMin,
    max: kReachMax,
    read: (UserSettings s) => s.reach,
  ),
  _RangedWriter(
    name: 'setGlow',
    low: (SettingsCubit c) => c.setGlow(0),
    high: (SettingsCubit c) => c.setGlow(999),
    min: kGlowMin,
    max: kGlowMax,
    read: (UserSettings s) => s.glow,
  ),
  _RangedWriter(
    name: 'setTouchGlow',
    low: (SettingsCubit c) => c.setTouchGlow(-5),
    high: (SettingsCubit c) => c.setTouchGlow(999),
    min: kTouchGlowMin,
    max: kTouchGlowMax,
    read: (UserSettings s) => s.touchGlow,
  ),
  _RangedWriter(
    name: 'setHue',
    low: (SettingsCubit c) => c.setHue(-1),
    high: (SettingsCubit c) => c.setHue(400),
    min: kHueMin,
    max: kHueMax,
    read: (UserSettings s) => s.hue,
  ),
  _RangedWriter(
    name: 'setStarCount',
    low: (SettingsCubit c) => c.setStarCount(-1),
    high: (SettingsCubit c) => c.setStarCount(999),
    min: kStarCountMin,
    max: kStarCountMax,
    read: (UserSettings s) => s.starCount,
  ),
  _RangedWriter(
    name: 'setStarBrightness',
    low: (SettingsCubit c) => c.setStarBrightness(0),
    high: (SettingsCubit c) => c.setStarBrightness(999),
    min: kStarBrightnessMin,
    max: kStarBrightnessMax,
    read: (UserSettings s) => s.starBrightness,
  ),
  _RangedWriter(
    name: 'setFocusDelaySec',
    low: (SettingsCubit c) => c.setFocusDelaySec(0),
    high: (SettingsCubit c) => c.setFocusDelaySec(99),
    min: kFocusDelaySecMin,
    max: kFocusDelaySecMax,
    read: (UserSettings s) => s.focusDelaySec,
  ),
  _RangedWriter(
    name: 'setSelahLengthSec',
    low: (SettingsCubit c) => c.setSelahLengthSec(0),
    high: (SettingsCubit c) => c.setSelahLengthSec(999),
    min: kSelahLengthSecMin,
    max: kSelahLengthSecMax,
    read: (UserSettings s) => s.selahLengthSec,
  ),
];

/// The record the reset is tested against: **every** field the prototype resets
/// differs from its reset value, and **every** field it leaves alone is set to
/// something the reset must not touch.
///
/// **Every ranged value is inside its table**, so the reset's result is not a
/// question about the clamp: a value the clamp would move could not tell a reset
/// from a clamp.
const UserSettings _resetSeed = UserSettings(
  // ## D9.1 — the twenty-three the prototype's handler resets.
  shaderEnabled: false,
  reach: 60,
  glow: 110,
  touchGlow: 20,
  curtainShape: CurtainShape.shafts,
  multichromeMelt: true,
  rayCombing: false,
  whiteCores: false,
  dotVeil: true,
  starsOn: false,
  constellationsOn: false,
  starCount: 10,
  starBrightness: 120,
  starShape: SkyStarShape.diamond,
  starField: SkyStarField.full,
  twinkle: false,
  focusDelaySec: 9,
  selahLengthSec: 30,
  breathGuide: false,
  vespersAutoDim: false,
  veilWitnesses: true,
  showPodium: false,
  hue: 100,
  // ## D9.2 — the six the prototype's handler leaves alone.
  language: ReadingLanguage.arabic,
  themeMode: AppThemeMode.system,
  fontStep: 5,
  reducedMotion: true,
  calmMotion: true,
  haptics: false,
);

/// The twenty-three fields the prototype's `resetLight` resets, and the literal
/// each one must land on.
///
/// ## AND WHY THERE IS **NO** SINGLE `UserSettings` LITERAL FOR THE EXPECTED RECORD
///
/// `avoid_redundant_argument_values` refuses a `UserSettings(...)` whose arguments
/// equal the declared defaults — and every one of the twenty-three reset literals
/// **is** a declared default. So the expected record cannot be written as a
/// constructor call, and the two ways around it are both bad:
///
/// * `const UserSettings()` — **vacuous**. Both sides would be the same object, and
///   the test could not fail. `user_settings_test.dart` says this in its own words:
///   "the declared defaults ARE those literals, so the two sides could never
///   differ and the test could not fail".
/// * a `copyWith` over the defaults — the same vacuity by another route.
///
/// So the expectation is **the table**, twenty-three rows and six rows, each naming
/// its field so a failure names the field that moved. Between them the twenty-nine
/// rows cover every field of the record, and the "the disk holds the same record"
/// test closes the loop on the store.
final List<_ResetCase> _resetCases = <_ResetCase>[
  _ResetCase(
    'shaderEnabled',
    (UserSettings s) => s.shaderEnabled,
    true,
    'eva/redesign.html:1500',
  ),
  _ResetCase(
    'reach',
    (UserSettings s) => s.reach,
    42,
    'eva/redesign.html:1502',
  ),
  _ResetCase('glow', (UserSettings s) => s.glow, 100, 'eva/redesign.html:1503'),
  _ResetCase(
    'touchGlow',
    (UserSettings s) => s.touchGlow,
    55,
    'eva/redesign.html:1504',
  ),
  _ResetCase(
    'curtainShape',
    (UserSettings s) => s.curtainShape,
    CurtainShape.top,
    'eva/redesign.html:1505',
  ),
  _ResetCase(
    'multichromeMelt',
    (UserSettings s) => s.multichromeMelt,
    false,
    'eva/redesign.html:1506',
  ),
  _ResetCase(
    'rayCombing',
    (UserSettings s) => s.rayCombing,
    true,
    'eva/redesign.html:1507',
  ),
  _ResetCase(
    'whiteCores',
    (UserSettings s) => s.whiteCores,
    true,
    'eva/redesign.html:1508',
  ),
  _ResetCase(
    'dotVeil',
    (UserSettings s) => s.dotVeil,
    false,
    'eva/redesign.html:1509',
  ),
  _ResetCase(
    'starsOn',
    (UserSettings s) => s.starsOn,
    true,
    'eva/redesign.html:1510',
  ),
  _ResetCase(
    'constellationsOn',
    (UserSettings s) => s.constellationsOn,
    true,
    'eva/redesign.html:1511',
  ),
  _ResetCase(
    'starCount',
    (UserSettings s) => s.starCount,
    44,
    'eva/redesign.html:1512',
  ),
  _ResetCase(
    'starBrightness',
    (UserSettings s) => s.starBrightness,
    100,
    'eva/redesign.html:1513',
  ),
  _ResetCase(
    'starShape',
    (UserSettings s) => s.starShape,
    SkyStarShape.dot,
    'eva/redesign.html:1514',
  ),
  _ResetCase(
    'starField',
    (UserSettings s) => s.starField,
    SkyStarField.crown,
    'eva/redesign.html:1515',
  ),
  _ResetCase(
    'twinkle',
    (UserSettings s) => s.twinkle,
    true,
    'eva/redesign.html:1516',
  ),
  _ResetCase(
    'focusDelaySec',
    (UserSettings s) => s.focusDelaySec,
    4,
    'eva/redesign.html:1517',
  ),
  _ResetCase(
    'selahLengthSec',
    (UserSettings s) => s.selahLengthSec,
    60,
    'eva/redesign.html:1518',
  ),
  _ResetCase(
    'breathGuide',
    (UserSettings s) => s.breathGuide,
    true,
    'eva/redesign.html:1519',
  ),
  _ResetCase(
    'vespersAutoDim',
    (UserSettings s) => s.vespersAutoDim,
    true,
    'eva/redesign.html:1520',
  ),
  _ResetCase(
    'veilWitnesses',
    (UserSettings s) => s.veilWitnesses,
    false,
    'eva/redesign.html:1521',
  ),
  _ResetCase(
    'showPodium',
    (UserSettings s) => s.showPodium,
    true,
    'eva/redesign.html:1522',
  ),
  _ResetCase('hue', (UserSettings s) => s.hue, 312, 'eva/redesign.html:1523'),
];

/// The six fields the prototype's `resetLight` leaves alone.
final List<_ResetCase> _untouchedCases = <_ResetCase>[
  _ResetCase(
    'language',
    (UserSettings s) => s.language,
    ReadingLanguage.arabic,
    'eva/redesign.html:1499-1525',
  ),
  _ResetCase(
    'themeMode',
    (UserSettings s) => s.themeMode,
    AppThemeMode.system,
    'eva/redesign.html:1501',
  ),
  _ResetCase(
    'fontStep',
    (UserSettings s) => s.fontStep,
    5,
    'eva/redesign.html:1499-1525',
  ),
  _ResetCase(
    'reducedMotion',
    (UserSettings s) => s.reducedMotion,
    true,
    'eva/redesign.html:1499-1525',
  ),
  _ResetCase(
    'calmMotion',
    (UserSettings s) => s.calmMotion,
    true,
    'eva/redesign.html:1499-1525',
  ),
  _ResetCase(
    'haptics',
    (UserSettings s) => s.haptics,
    false,
    'eva/redesign.html:1499-1525',
  ),
];

/// A repository that counts its writes.
///
/// **The count is the assertion the brief's "one write, not twenty-three" needs**,
/// and a `Future` returned by a spy would not have been: the number of writes is
/// what has to be observed, not the number of emissions.
final class _CountingRepository implements SettingsRepository {
  _CountingRepository(this.inner);

  /// The real repository behind [load] and [save].
  final SettingsRepository inner;

  /// How many times [save] has been called.
  int saves = 0;

  @override
  Future<Result<UserSettings>> load() => inner.load();

  @override
  Future<Result<UserSettings>> save(UserSettings settings) {
    saves++;
    return inner.save(settings);
  }
}
