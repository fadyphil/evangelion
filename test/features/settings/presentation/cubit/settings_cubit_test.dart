import 'dart:async';

import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

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

      gate.complete(Result<UserSettings>.success(cubit.state.settings));
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
}

/// The value of a [Success], for the two disk assertions.
///
/// **An extension and not a member**, because `Result` deliberately has none: its own
/// doc says "there is no `value` getter and no `getOrNull`", because either would let a
/// caller turn a [FailureResult] into a `null` that surfaces three frames later. A
/// test-local extension keeps the production type's shape unchanged and still cannot
/// compile against a third arm, because the `switch` is exhaustive.
extension _SuccessValue on Result<UserSettings> {
  UserSettings get successValue => switch (this) {
    Success<UserSettings>(:final UserSettings value) => value,
    FailureResult<UserSettings>(:final Failure failure) => throw StateError(
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
      Result<UserSettings>.failure(_failure);

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async =>
      Result<UserSettings>.failure(_failure);
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
