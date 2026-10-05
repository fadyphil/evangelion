import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The app-wide reader preferences, and the only writer of them.
///
/// ## IT IS A **`Cubit`**, NOT A `Bloc`, FOR `ReadingCubit`'s REASON
///
/// `ReadingCubit`'s doc gives it: there are no events here, every entry point is a
/// method, and `bloc.add` is not reachable from it. The mistake decision 48 names —
/// every event equal, so `bloc.add` swallows a duplicate — cannot happen to a type
/// with no events.
///
/// ## AND IT IS REGISTERED **BY HAND**, which is the sixth time
///
/// `Cubit` arrives through `package:flutter_bloc/flutter_bloc.dart`, which re-exports
/// Flutter's widget layer, and `bloc` is a transitive dependency AGENT_CONTEXT §8.4
/// will not let this project promote. So there is no spelling of "register this
/// cubit" that keeps Flutter out of `injection.dart`'s closure, and
/// `lib/app/di/navigation_injection.dart` builds it — the same wall
/// `SettingsModule`'s own doc predicted before this phase existed, and the sixth
/// `Cubit`/`Bloc` to hit it after `AuthBloc`, `HomeBloc`, `ReadingCubit` and `QuizBloc`.
///
/// **`registerSingleton`, for a reason that is sharper here than on the other four.**
/// Those hold repository results. **This one holds a reader's choices** — their
/// palette, their language, their font size. A second instance would be a second set
/// of choices, and `app.dart` resolving a *different* `SettingsCubit` from the one
/// `/settings` wrote would show the reader a toggle that springs back. That is the
/// single-instance hazard `HomeBloc` documents, with a reader-visible failure instead
/// of a stale greeting.
///
/// ## [apply] IS THE ONLY WRITER, AND IT IS **OPTIMISTIC**
///
/// Every setter on this cubit funnels through [apply], which does three things in one
/// place so that no call site can skip one:
///
/// 1. **clamps** [UserSettings.fontStep] through `clampFontStep` — the boundary
///    `font_size_stepper.dart`'s doc requires, and the only place it lives now that
///    `ReadingCubit` no longer owns a step;
/// 2. **emits first, persists second.** The reader's own gesture is answered on the
///    frame it happened, so the toggle does not lag a disk round trip behind the
///    finger. This is the reason the app feels immediate and the reason the *store* is
///    not on the critical path;
/// 3. **rolls back** if the write fails, and records the failure in
///    [SettingsState.failure].
///
/// **The rollback is a decision, and the alternative was measured away.** Because
/// step 2 emits first, a store that cannot be reached would otherwise leave the reader
/// looking at a change that did not happen and did not come back. Reverting to the
/// last known-good value on failure is the honest answer: the state the reader sees is
/// always a state the store has confirmed, except in the window between the gesture
/// and the write, which is one frame wide.
///
/// **`await`, not `unawaited`.** `ReadingCubit.load` is the precedent for awaiting a
/// call whose result is not used; here the result *is* used, so the method is async
/// and the two call sites that do not care use `unawaited` explicitly rather than
/// dropping a `Future` (§4).
class SettingsCubit extends Cubit<SettingsState> {
  /// Drives the app's preferences through [getSettings] and [updateSettings].
  SettingsCubit({
    required GetSettings getSettings,
    required UpdateSettings updateSettings,
  }) : super(const SettingsState(settings: UserSettings())) {
    _getSettings = getSettings;
    _updateSettings = updateSettings;
  }

  late final GetSettings _getSettings;
  late final UpdateSettings _updateSettings;

  /// The last value the store confirmed, and the value a failed write rolls back to.
  ///
  /// **A field and not `state.settings`**, because [apply] emits before it persists
  /// and so `state.settings` is the *optimistic* value while this is the durable one.
  /// Rolling back to the optimistic value would be a rollback to nothing. It starts
  /// at the defaults, so a failure on the very first write rolls back to the defaults
  /// rather than to an uninitialised field.
  UserSettings _confirmed = const UserSettings();

  /// Reads the store and publishes what it holds.
  ///
  /// **Called once**, from `app.dart`'s state before the first frame, and again by
  /// `SettingsPage` through `initState`-equivalent dispatch — which is the one place
  /// a second call is wanted: a reader who has been running the app since before this
  /// build had a language, and has navigated to `/settings` for the first time, gets
  /// their stored answer without a restart.
  ///
  /// **It never empties [SettingsState.settings].** See that class's doc for the
  /// measurement that rules the alternative out: `app.dart` reads the palette on every
  /// frame and a `MaterialApp` with no palette is not a state this app can render.
  Future<void> load() async {
    final Result<UserSettings> result = await _getSettings();
    switch (result) {
      case Success<UserSettings>(:final UserSettings value):
        _confirmed = _clamp(value);
        emit(
          state.copyWith(
            status: SettingsStatus.ready,
            settings: _confirmed,
            failure: null,
          ),
        );
      case FailureResult<UserSettings>(:final Failure failure):
        emit(
          state.copyWith(
            status: SettingsStatus.failed,
            settings: _confirmed,
            failure: failure,
          ),
        );
    }
  }

  /// Reports a new font [step].
  ///
  /// Named for the reader's control rather than "update settings", because this is
  /// `/reading`'s `Aa` control's only way in — a screen that cannot name the settings
  /// feature has to reach this cubit through a handle whose method says what the
  /// reader just did.
  Future<void> setFontStep(int step) =>
      apply((UserSettings current) => current.copyWith(fontStep: step));

  /// Reports a new palette.
  Future<void> setThemeMode(AppThemeMode mode) =>
      apply((UserSettings current) => current.copyWith(themeMode: mode));

  /// Reports a new language. **Not nullable**, so this cannot undo a choice — see
  /// [UserSettings.language] for why "follow the platform" is the *absence* of a
  /// stored value rather than a stored value, and therefore the absence of a control.
  Future<void> setLanguage(ReadingLanguage language) =>
      apply((UserSettings current) => current.copyWith(language: language));

  /// Reports a new reduce-motion preference.
  Future<void> setReducedMotion({required bool reduced}) =>
      apply((UserSettings current) => current.copyWith(reducedMotion: reduced));

  /// Applies [change] to the current settings, persists the result, and rolls back if
  /// the store refuses it.
  ///
  /// [change] takes the **current** settings and returns the edited record, rather
  /// than this method taking a whole new value, because the four setters above are
  /// four edits of one record and reading it here is what makes them composable:
  /// `apply((s) => s.copyWith(fontStep: 4))` cannot interleave two writers between
  /// the read and the write, which is the failure a read-then-write pair has.
  Future<void> apply(UserSettings Function(UserSettings) change) async {
    final UserSettings next = _clamp(change(state.settings));
    if (next == state.settings) {
      // **No emit for an unchanged value**, which is `ReadingCubit.setFontStep`'s
      // rule and the same reason: `app.dart` rebuilds the whole app on every state
      // change, so an emit that changes nothing is a full rebuild that changes
      // nothing. `freezed` derives `==` from the constructor, so this is a value
      // comparison and not a reference one.
      return;
    }
    emit(state.copyWith(settings: next, failure: null));
    await _persist(next);
  }

  /// Writes [next], keeping [SettingsState.failure] clear or rolling back.
  Future<void> _persist(UserSettings next) async {
    final Result<UserSettings> result = await _updateSettings(next);
    switch (result) {
      case Success<UserSettings>(value: final UserSettings stored):
        // **The store's answer, not [next].** `SettingsRepositoryImpl` does not
        // normalise today, so the two are equal — but a store that did normalise one
        // would otherwise leave the reader looking at a value the device does not
        // have, and the next launch would show something else.
        _confirmed = _clamp(stored);
        // A successful write proves the store is reachable, so this is also where a
        // page that was `loading` or `failed` becomes `ready` — and it is the only
        // place that can be true, because [apply] deliberately does not claim it
        // before the write answers.
        emit(
          state.copyWith(
            status: SettingsStatus.ready,
            settings: _confirmed,
            failure: null,
          ),
        );
      case FailureResult<UserSettings>(:final Failure failure):
        emit(
          state.copyWith(
            status: SettingsStatus.failed,
            settings: _confirmed,
            failure: failure,
          ),
        );
    }
  }

  /// [settings] with its font step inside §5.2's table.
  ///
  /// **The only clamp in the app**, and `ReadingCubit` used to be the other one. One
  /// boundary is the whole of the argument `font_size_stepper.dart` makes: a step
  /// outside `kFontStepMin`…`kFontStepMax` would reach `evaScalerFor`'s `_` arm as
  /// `1.22×` while the stepper's knob sat at a position no step owns.
  UserSettings _clamp(UserSettings settings) =>
      settings.copyWith(fontStep: clampFontStep(settings.fontStep));
}
