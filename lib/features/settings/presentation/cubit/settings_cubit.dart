import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
// The barrel is imported for `clampFontStep` — the font step's clamp, which the
// design system owns beside the widget that draws the track.
//
// **AND THERE IS NO LONGER A `CurtainShape` TO HIDE.** The design system used
// to declare one of its own, beside `NeuralScaffold` — the **scrim's**
// direction, with three members — and Task 5.7's
// `core/domain/entities/curtain_shape.dart` declared a second one with four
// members, so every file that imported both the barrel and the entity had to
// write `hide CurtainShape`.
//
// **They are now one.** The prototype has a single `data-shape` attribute with
// four values (`eva/redesign.html:1463`), read by two rules — the shader's
// `u_shape` and the `.scrim` overrides (`:114`, `:115`) — and the client now
// has one type for it, in the shared kernel. The scrim's ramps stayed in
// `neural_scaffold.dart`, where they are.
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/settings_clamps.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

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
      case Right<Failure, UserSettings>(:final UserSettings value):
        _confirmed = _clamp(value);
        emit(
          state.copyWith(
            status: SettingsStatus.ready,
            settings: _confirmed,
            failure: null,
          ),
        );
      case Left<Failure, UserSettings>(value: final failure):
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

  // ---------------------------------------------------------------------------
  // Task 5.7 — the Workshop's twenty-three field writers. (`setDaylight` and
  // `restoreDefaults` are the two that are not a *field* writer, and they stand
  // outside this block.)
  //
  // ## EVERY ONE OF THEM FUNNELS THROUGH [apply]
  //
  // One emit, one write, and the clamp applied on the way in — and **none of them
  // writes a field directly.** A writer that emitted its own state would skip the
  // clamp and would skip the rollback, and the two are the whole of this cubit's
  // contract: the reader's gesture is answered on the frame it happened, and a
  // store that refuses it puts them back where they were.
  //
  // ## AND THE NAMES ARE FIXED, because other code is written against them
  //
  // `SettingsHandle` is the widget-facing projection of this cubit and
  // `/reading` writes the sky preferences through it, so a rename here is a rename
  // there. The names say what the reader *did* — `setStarsOn`, not
  // `setStars` — because the handle's method is the reader's gesture, not a field
  // assignment.
  //
  // ## AND EACH ONE'S RANGE IS THE **PROTOTYPE'S**
  //
  // The eight ranged values are clamped by [apply] through `_clamp`, which is the
  // app's only clamp boundary. The ranges themselves live in
  // `features/settings/domain/settings_clamps.dart`, beside the prototype lines
  // they are transcribed from.
  // ---------------------------------------------------------------------------

  /// Turns the aurora engine on or off. `eva/redesign.html:652`.
  Future<void> setShaderEnabled({required bool enabled}) =>
      apply((UserSettings current) => current.copyWith(shaderEnabled: enabled));

  /// Sets the shape the aurora curtain takes. `eva/redesign.html:654-655`.
  Future<void> setCurtainShape(CurtainShape shape) =>
      apply((UserSettings current) => current.copyWith(curtainShape: shape));

  /// Sets how far the aurora band reaches. `eva/redesign.html:658` — 18-110.
  Future<void> setReach(int reach) =>
      apply((UserSettings current) => current.copyWith(reach: reach));

  /// Sets the aurora's brightness. `eva/redesign.html:659` — 40-130.
  Future<void> setGlow(int glow) =>
      apply((UserSettings current) => current.copyWith(glow: glow));

  /// Sets how brightly the aurora answers a touch. `eva/redesign.html:660` —
  /// 0-100.
  Future<void> setTouchGlow(int touchGlow) =>
      apply((UserSettings current) => current.copyWith(touchGlow: touchGlow));

  /// Sets the aurora's hue, in degrees. `eva/redesign.html:661` — 0-360.
  Future<void> setHue(int hue) =>
      apply((UserSettings current) => current.copyWith(hue: hue));

  /// Turns the multichrome melt on or off. `eva/redesign.html:662`.
  Future<void> setMultichromeMelt({required bool melting}) => apply(
    (UserSettings current) => current.copyWith(multichromeMelt: melting),
  );

  /// Turns the ray combing on or off. `eva/redesign.html:663`.
  Future<void> setRayCombing({required bool combing}) =>
      apply((UserSettings current) => current.copyWith(rayCombing: combing));

  /// Turns the white cores on or off. `eva/redesign.html:664`.
  Future<void> setWhiteCores({required bool white}) =>
      apply((UserSettings current) => current.copyWith(whiteCores: white));

  /// Turns the dot veil on or off. `eva/redesign.html:665`.
  Future<void> setDotVeil({required bool veiled}) =>
      apply((UserSettings current) => current.copyWith(dotVeil: veiled));

  /// Turns the witness sky on or off. `eva/redesign.html:667`.
  Future<void> setStarsOn({required bool on}) =>
      apply((UserSettings current) => current.copyWith(starsOn: on));

  /// Turns the constellation on or off. `eva/redesign.html:668`.
  Future<void> setConstellationsOn({required bool on}) =>
      apply((UserSettings current) => current.copyWith(constellationsOn: on));

  /// Sets how many stars the witness sky holds. `eva/redesign.html:669` — 0-60.
  Future<void> setStarCount(int count) =>
      apply((UserSettings current) => current.copyWith(starCount: count));

  /// Sets how bright the stars are. `eva/redesign.html:670` — 30-150.
  Future<void> setStarBrightness(int brightness) => apply(
    (UserSettings current) => current.copyWith(starBrightness: brightness),
  );

  /// Sets the silhouette every star is drawn in. `eva/redesign.html:672-673`.
  Future<void> setStarShape(SkyStarShape shape) =>
      apply((UserSettings current) => current.copyWith(starShape: shape));

  /// Sets the vertical band the stars sit in. `eva/redesign.html:677-678`.
  Future<void> setStarField(SkyStarField field) =>
      apply((UserSettings current) => current.copyWith(starField: field));

  /// Turns the twinkle on or off. `eva/redesign.html:681`.
  Future<void> setTwinkle({required bool twinkling}) =>
      apply((UserSettings current) => current.copyWith(twinkle: twinkling));

  /// Sets how long the reader must be idle before the screen dims, in seconds.
  /// `eva/redesign.html:683` — 2-15.
  Future<void> setFocusDelaySec(int seconds) =>
      apply((UserSettings current) => current.copyWith(focusDelaySec: seconds));

  /// Sets how long the selah lasts, in seconds. `eva/redesign.html:684` — 15-120,
  /// in steps of five.
  Future<void> setSelahLengthSec(int seconds) => apply(
    (UserSettings current) => current.copyWith(selahLengthSec: seconds),
  );

  /// Turns the breath guide on or off. `eva/redesign.html:685`.
  Future<void> setBreathGuide({required bool on}) =>
      apply((UserSettings current) => current.copyWith(breathGuide: on));

  /// Turns the vespers auto-dim on or off. `eva/redesign.html:686`.
  Future<void> setVespersAutoDim({required bool on}) =>
      apply((UserSettings current) => current.copyWith(vespersAutoDim: on));

  /// Turns the calm motion on or off. `eva/redesign.html:688`.
  Future<void> setCalmMotion({required bool calm}) =>
      apply((UserSettings current) => current.copyWith(calmMotion: calm));

  /// Turns the haptics on or off. `eva/redesign.html:689`.
  Future<void> setHaptics({required bool on}) =>
      apply((UserSettings current) => current.copyWith(haptics: on));

  /// Turns the daylight palette on or off.
  ///
  /// ## THE MAPPING, AND IT IS **NARROWER** THAN [AppThemeMode]
  ///
  /// On writes [AppThemeMode.light]; off writes [AppThemeMode.dark]. The
  /// prototype's control is a two-state toggle (`eva/redesign.html:650`) and it has
  /// no third state.
  ///
  /// ## THE CUBIT'S HALF OF A **PRODUCT CONSEQUENCE**
  ///
  /// [AppThemeMode]'s `system` arm — "the reader asked to follow the OS" — becomes
  /// **unreachable from the UI**, because this method is the UI's only writer of the
  /// theme and it never writes `system`.
  ///
  /// **[setThemeMode] still exists and can still write `system`** — it is the
  /// programmatic writer, and the store's contract is not this method's business.
  /// What is unreachable is the *reader-facing* way to choose it: the redesign's
  /// theme group holds one control, the Daylight toggle (`eva/redesign.html:649-650`),
  /// and the Phase-9 three-segment Light/Dark/System picker is gone.
  ///
  /// **A reader whose stored value is `system` keeps it until they touch the
  /// control**, and touching it narrows the choice to `light` or `dark` for good.
  /// This client has no way to select `system` again.
  ///
  /// The narrowing is a **recorded decision**, not drift: the prototype has no
  /// `system` arm to lose, and the orchestrator's decision protects the stored
  /// value as an existing reader choice until the reader touches the control. The
  /// control's own half of this record lives with the control.
  Future<void> setDaylight({required bool daylight}) => apply(
    (UserSettings current) => current.copyWith(
      themeMode: daylight ? AppThemeMode.light : AppThemeMode.dark,
    ),
  );

  /// Restores the prototype's "nocturne defaults" — in **ONE** apply, and so in
  /// one emit and one write.
  ///
  /// ## WHAT IT RESETS, FIELD BY FIELD, EACH WITH ITS PROTOTYPE LINE
  ///
  /// The prototype's handler is `eva/redesign.html:1499-1525`.
  ///
  /// | field | reset to | prototype |
  /// | --- | --- | --- |
  /// | `shaderEnabled` | `true` | :1500 |
  /// | `reach` | `42` | :1502 |
  /// | `glow` | `100` | :1503 |
  /// | `touchGlow` | `55` | :1504 |
  /// | `curtainShape` | `top` | :1505 |
  /// | `multichromeMelt` | `false` | :1506 |
  /// | `rayCombing` | `true` | :1507 |
  /// | `whiteCores` | `true` | :1508 |
  /// | `dotVeil` | `false` | :1509 |
  /// | `starsOn` | `true` | :1510 |
  /// | `constellationsOn` | `true` | :1511 |
  /// | `starCount` | `44` | :1512 |
  /// | `starBrightness` | `100` | :1513 |
  /// | `starShape` | `dot` | :1514 |
  /// | `starField` | `crown` | :1515 |
  /// | `twinkle` | `true` | :1516 |
  /// | `focusDelaySec` | `4` | :1517 |
  /// | `selahLengthSec` | `60` | :1518 |
  /// | `breathGuide` | `true` | :1519 |
  /// | `vespersAutoDim` | `true` | :1520 |
  /// | `veilWitnesses` | `false` | :1521 |
  /// | `showPodium` | `true` | :1522 |
  /// | `hue` | `312` | :1523 — see the substitution below |
  ///
  /// ## WHAT IT DOES **NOT** RESET, AND THE SET IS **NOT** EMPTY
  ///
  /// The prototype's handler touches none of these, and neither does this client.
  ///
  /// | field | why not |
  /// | --- | --- |
  /// | `language` | `:1499-1525` never touches it; it is an existing reader choice |
  /// | `themeMode` | **the prototype DOES reset the daylight** (`:1501`, `u_light=0`) and this client does **not** — see below |
  /// | `fontStep` | `:1499-1525` never touches it; the Type size is the reader's reading size |
  /// | `reducedMotion` | `:1499-1525` never touches it; it is an accessibility choice |
  /// | `calmMotion` | `:1499-1525` never touches it, **even though it is a new field** — the prototype deliberately preserves it |
  /// | `haptics` | `:1499-1525` never touches it, **even though it is a new field** |
  ///
  /// ## THE **THREE** DELIBERATE DEPARTURES FROM THE PROTOTYPE
  ///
  /// 1. **`themeMode` is not reset.** The prototype resets the daylight to dark
  ///    (`:1501`). This client's `themeMode` is a **three-state** enum whose
  ///    `system` arm the prototype has no word for, and the orchestrator's decision
  ///    protects it as an existing reader choice. **Recorded at the action row,
  ///    citing `:1501`.**
  /// 2. **`calmMotion` is not reset**, although it is a new field. The prototype
  ///    leaves it — its handler touches neither `setCalm` nor `setHap` — because it
  ///    is a comfort choice. **Recorded.**
  /// 3. **`haptics` is not reset**, for the same reason. **Recorded.**
  ///
  /// ## AND THE **HUE** SUBSTITUTION
  ///
  /// The prototype's reset restores the **current book's** hue (`:1523`,
  /// `BOOKS[curBook].hsl.h`). **This client has no per-book hue**, so the reset
  /// uses the **declared control default** of `312` (`:661`) — the value the
  /// slider shows a reader and the value the field itself defaults to. The
  /// substitution is recorded at the field and here.
  ///
  /// ## AND IT IS **ONE** APPLY, NOT TWENTY-THREE
  ///
  /// [apply] emits once and persists once. Twenty-three calls would emit
  /// twenty-three times and write twenty-three times, and `app.dart` rebuilds the
  /// whole app on every settings emit — so the difference is not a tidiness
  /// question but a frame-count one.
  Future<void> restoreDefaults() => apply(
    (UserSettings current) => current.copyWith(
      shaderEnabled: true,
      reach: 42,
      glow: 100,
      touchGlow: 55,
      curtainShape: CurtainShape.top,
      multichromeMelt: false,
      rayCombing: true,
      whiteCores: true,
      dotVeil: false,
      starsOn: true,
      constellationsOn: true,
      starCount: 44,
      starBrightness: 100,
      starShape: SkyStarShape.dot,
      starField: SkyStarField.crown,
      twinkle: true,
      focusDelaySec: 4,
      selahLengthSec: 60,
      breathGuide: true,
      vespersAutoDim: true,
      veilWitnesses: false,
      showPodium: true,
      hue: 312,
    ),
  );

  /// Applies [change] to the current settings, persists the result, and rolls back if
  /// the store refuses it.
  ///
  /// [change] takes the **current** settings and returns the edited record, rather
  /// than this method taking a whole new value, because every writer above is one
  /// edit of one record and reading it here is what makes them composable:
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
      case Right<Failure, UserSettings>(value: final UserSettings stored):
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
      case Left<Failure, UserSettings>(value: final failure):
        emit(
          state.copyWith(
            status: SettingsStatus.failed,
            settings: _confirmed,
            failure: failure,
          ),
        );
    }
  }

  /// [settings] with every ranged value inside its own table.
  ///
  /// **The only clamp in the app**, and `ReadingCubit` used to be the other one. One
  /// boundary is the whole of the argument `font_size_stepper.dart` makes: a step
  /// outside `kFontStepMin`…`kFontStepMax` would reach `evaScalerFor`'s `_` arm as
  /// `1.22×` while the stepper's knob sat at a position no step owns.
  ///
  /// ## AND THE **EIGHT** WORKSHOP RANGES JOIN IT HERE
  ///
  /// The eight clamps have **two homes, and the split is §3's placement test
  /// rather than a convenience**: seven live in
  /// `features/settings/domain/settings_clamps.dart` — pure Dart, pure
  /// functions, each with the prototype's own `min`/`max` beside it — and the
  /// **star count's** lives in `core/domain/entities/user_settings.dart`, with
  /// the field it bounds, because the sky feature clamps the same number where
  /// it becomes a cap and a feature may not import another feature.
  ///
  /// All eight are applied **here** and nowhere else, for the reason above: a
  /// second boundary is a second table, and a value could then be legal on one
  /// side of it and not the other.
  ///
  /// This is also where a **stored** value is caught: [load] reads the store and
  /// clamps what it read, so a hand-edited preference cannot reach a slider that
  /// has no position for it — the same argument `clampFontStep`'s doc makes about
  /// `evaScalerFor`.
  UserSettings _clamp(UserSettings settings) => settings.copyWith(
    fontStep: clampFontStep(settings.fontStep),
    reach: clampReach(settings.reach),
    glow: clampGlow(settings.glow),
    touchGlow: clampTouchGlow(settings.touchGlow),
    hue: clampHue(settings.hue),
    starCount: clampStarCount(settings.starCount),
    starBrightness: clampStarBrightness(settings.starBrightness),
    focusDelaySec: clampFocusDelaySec(settings.focusDelaySec),
    selahLengthSec: clampSelahLengthSec(settings.selahLengthSec),
  );
}
