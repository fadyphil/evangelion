import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reader's preferences, in `shared_preferences`.
///
/// ## AND NO SERVER SYNC, BECAUSE THERE IS NO SERVER ENDPOINT FOR IT
///
/// AGENT_CONTEXT §2, decision 4: "Settings are local only (`shared_preferences`). No
/// server sync." §5's endpoint table has nothing for it either — the backend serves
/// readings, questions, submissions and a streak, and `SettingsRepository` has no
/// HTTP method to call. So this file has no `Dio` in it and there is no `sync`, no
/// `lastSyncedAt` and no conflict rule. A second store would be a second source of
/// truth for every field, which is the drift this repository has already paid for
/// twice (`05-domain-model.md`'s two hex tables, and `Failure`'s excluded `details`).
///
/// ## WHY THE INSTANCE IS **LAZY** AND THE DATA SOURCE IS A SYNCHRONOUS `@module`
///
/// `SharedPreferences.getInstance()` is `async` — it reads from disk — and
/// `configureDependencies()` is called before `runApp` but must not have to be
/// awaited by `bootstrap.dart` for a *settings* store, because the app is perfectly
/// usable with the defaults while it loads.
///
/// So the future is memoised here rather than awaited in the DI graph: the first read
/// pays for it and every later one does not. **`@lazySingleton` on the data source
/// means one store for the process**, which is the same reason `AuthLocalDataSource`
/// is a singleton and the reason it is a *field* rather than a `SharedPreferences`.
///
/// ## WHY NOT THE **`shared_preferences` CACHE CLASS**
///
/// 2.5.x ships `SharedPreferencesWithCache`, which is the package's own recommendation
/// for new code. It is not used here, for one reason worth recording: this app stores
/// **twenty-nine fields** — the six Phase 9 wrote and the twenty-three Task 5.7
/// added — and reads them **once per launch**. The cache exists to avoid a disk read
/// per access, and there is nothing to amortise — a second layer of invalidation
/// between the store and the domain entity is a second way for the rendered theme to
/// disagree with the stored one.
///
/// `SharedPreferences.setMockInitialValues` is on this class and not on the async one,
/// which is why the round-trip test in `settings_repository_test.dart` can drive a
/// **real** store with a real platform-channel-shaped read and write rather than a
/// hand-written double.
///
/// ## WHAT AN UNREADABLE VALUE DOES HERE, AND WHY IT IS **NOT** AN ERROR
///
/// Every read below answers a `null` from the store with a **default**, and an
/// unrecognised stored string with the same default. `AppThemeMode.fromStored`'s own
/// doc gives the argument for the mode (`null` rather than a guess, so the caller
/// chooses) and this file is that caller.
///
/// The consequence, stated so nobody reads it as a swallowed error: **a corrupt
/// preference is indistinguishable from an absent one.** That is the deliberate
/// choice — a reader whose theme-mode string is mangled gets a working app in the
/// default palette, which is materially better than an app that will not open — and it
/// is why `SettingsRepository`'s contract reserves [FailureKind] for the *store* being
/// unreachable rather than for a value inside it.
///
/// ## THE TWENTY-THREE NEW KEYS, AND WHY ADDING THEM NEEDS **NO MIGRATION**
///
/// Task 5.7 added twenty-three fields — the Workshop's shader, sky and ritual
/// preferences. This store has **no versioning scheme and needs none**, and the
/// reason is the contract above: **every read answers an unread or untypeable key
/// with the field's own default.** There is no "this build does not know this key"
/// state, because there is no "this build knows this key" state either — the key is
/// asked for and it answers.
///
/// So the twenty-three keys are **purely additive**. A store written by a build that
/// had none of them reads as twenty-three defaults, and a store written by a build
/// that had all of them reads as itself. There is no third state to migrate
/// between, and **no migration code exists or is needed**.
///
/// ## THE **FOUR** PREFIXES, AND WHY THE PLAN NAMED THREE
///
/// | prefix | fields | why |
/// | --- | --- | --- |
/// | `eva.shader.*` | 10 | the aurora engine's own group |
/// | `eva.sky.pref.*` | 7 | **not** a bare `eva.sky.*` — `eva.sky.order` and `eva.sky.entries` are the **star-record store's** keys (`sky_local_data_source.dart`), and a reader poking at the store must be able to tell a preference from a record |
/// | `eva.ritual.*` | 6 | focus and ritual |
/// | `eva.communion.*` | 2 | **already here** from Task 5.5 — the communion group's two toggles, and this task adds **no** new communion key |
///
/// The plan named three and the code has four, and the fourth is not an invention:
/// `eva.communion.veil_witnesses` and `eva.communion.show_podium` were written by
/// Task 5.5 and are read by this file today.
///
/// ## AND **NONE** OF THE TWENTY-THREE HAS AN "ABSENT" DEFAULT
///
/// A new field whose default is "absent" — a `null`, an empty string — would need a
/// `remove` rather than a write, because a write of `''` would leave a key that says
/// "this reader chose nothing" in a form no other code writes. **Every one of the
/// twenty-three is a non-nullable `bool`, `int` or enum**, so plain writes suffice
/// and the `remove` arm of [write] stays the one the language alone needs.
final class SettingsLocalDataSource {
  /// A store holding nothing yet.
  SettingsLocalDataSource();

  /// A store over an already-decided [preferences] future.
  ///
  /// ## A NAMED CONSTRUCTOR FOR **ONE** REASON, AND IT IS NOT LAZINESS
  ///
  /// `SettingsRepositoryImpl`'s contract is "never throws" — a `Failure` for a store
  /// that cannot be reached — and `SharedPreferences.getInstance()` reaches the store
  /// over a **platform channel**, so the only faithful way to reach that contract is a
  /// store that fails. Reproducing that in a `test()` needs the failing future.
  ///
  /// The alternative was reaching for `shared_preferences_platform_interface` and
  /// substituting `SharedPreferencesStorePlatform.instance` — and that is a
  /// **transitive** dependency, so `AGENT_CONTEXT` §8.4 makes promoting it a hard stop
  /// and the analyzer's `depend_on_referenced_packages` says the same thing. So the seam
  /// is one named constructor here, 4 lines wide, in the one class that owns the
  /// channel.
  ///
  /// **Named `.over` and not `@visibleForTesting`,** which is the one deviation from
  /// `package:shared_preferences`' own `setMockInitialValues` and is forced by
  /// `injection_test.dart`: that test walks the import graph from
  /// `lib/app/di/injection.dart` and fails on any file in it with a **direct**
  /// `package:flutter` import — and `visibleForTesting` lives in
  /// `package:flutter/foundation.dart`. The annotation the file measured as
  /// `must stay Flutter-free`, so the doc comment above carries the intent instead and
  /// the name carries it in every reader's line of sight. The gate's own output named the
  /// file, which is a better instrument than an annotation the analyzer cannot enforce.
  SettingsLocalDataSource.over(Future<SharedPreferences> preferences)
    : _store = preferences;

  /// The memoised platform store.
  ///
  /// `null` until the first read, and reset only by [resetForTest] — the memoisation
  /// is the point, so nothing in production clears it.
  Future<SharedPreferences>? _store;

  /// The stored preferences, with every unreadable field answered by its default.
  ///
  /// ## PER-FIELD DEFAULTS, AND **NEVER** A NULL
  ///
  /// There is no "nothing stored" answer and no `hasKeys` check, which is deliberate
  /// and is the reason the returned type is not nullable. A store written by a build
  /// that had fewer fields is half-written, so "is the store empty" is not a question
  /// with one useful answer — **every field is asked for itself** and answers its own
  /// default, and a store holding three of the twenty-nine keys reads as the other
  /// twenty-six ones' defaults.
  ///
  /// ## AND EVERY DEFAULT IS READ FROM **[UserSettings] ITSELF**
  ///
  /// The `defaults` below is a `const UserSettings()`, and each field's answer is
  /// `defaults.<field>`. A literal written here would be a **second copy** of a
  /// number `user_settings.dart` already owns, and "two writers must not hold two
  /// spellings of one number" is the drift this repository rejects wherever it
  /// finds it — `sky_star_cap.dart`'s whole argument is about it.
  ///
  /// **[UserSettings.language] is the one exception**, and it is not an
  /// inconsistency: its default is the *absence* of a value, so its answer is
  /// `null` and there is nothing to read a default from. The note below says why
  /// that is a third answer rather than an absence.
  ///
  /// [UserSettings.language] is the one field where that is more than tidiness,
  /// because its default **is** `null` and `null` there is a third answer ("follow
  /// the platform") rather than an absence. A `Future<UserSettings?>` would have had to
  /// invent a way to say "a theme was stored and no language was", and the field's
  /// own default already says it exactly.
  Future<UserSettings> read() async {
    final SharedPreferences preferences = await _preferences;
    // **The one place each default is spelled.** See the doc above.
    const UserSettings defaults = UserSettings();
    return UserSettings(
      themeMode:
          AppThemeMode.fromStored(
            _stringAt(preferences, kThemeModeKey) ?? '',
          ) ??
          defaults.themeMode,
      fontStep: _intAt(preferences, kFontStepKey) ?? defaults.fontStep,
      language: ReadingLanguage.fromCode(
        _stringAt(preferences, kLanguageKey) ?? '',
      ),
      reducedMotion:
          _boolAt(preferences, kReducedMotionKey) ?? defaults.reducedMotion,
      veilWitnesses:
          _boolAt(preferences, kVeilWitnessesKey) ?? defaults.veilWitnesses,
      showPodium: _boolAt(preferences, kShowPodiumKey) ?? defaults.showPodium,
      // ## THE TWENTY-THREE NEW FIELDS
      //
      // **Every one answers its own default, and the default is read from
      // [UserSettings] rather than written here.** The two enum fields go through
      // `fromStored`, which answers `null` for a value it does not know — so an
      // unrecognised stored string becomes the default and never a wrong shape.
      shaderEnabled:
          _boolAt(preferences, kShaderEnabledKey) ?? defaults.shaderEnabled,
      curtainShape:
          CurtainShape.fromStored(
            _stringAt(preferences, kCurtainShapeKey) ?? '',
          ) ??
          defaults.curtainShape,
      reach: _intAt(preferences, kReachKey) ?? defaults.reach,
      glow: _intAt(preferences, kGlowKey) ?? defaults.glow,
      touchGlow: _intAt(preferences, kTouchGlowKey) ?? defaults.touchGlow,
      hue: _intAt(preferences, kHueKey) ?? defaults.hue,
      multichromeMelt:
          _boolAt(preferences, kMultichromeMeltKey) ?? defaults.multichromeMelt,
      rayCombing: _boolAt(preferences, kRayCombingKey) ?? defaults.rayCombing,
      whiteCores: _boolAt(preferences, kWhiteCoresKey) ?? defaults.whiteCores,
      dotVeil: _boolAt(preferences, kDotVeilKey) ?? defaults.dotVeil,
      starsOn: _boolAt(preferences, kStarsOnKey) ?? defaults.starsOn,
      constellationsOn:
          _boolAt(preferences, kConstellationsOnKey) ??
          defaults.constellationsOn,
      starCount: _intAt(preferences, kStarCountKey) ?? defaults.starCount,
      starBrightness:
          _intAt(preferences, kStarBrightnessKey) ?? defaults.starBrightness,
      starShape:
          SkyStarShape.fromStored(
            _stringAt(preferences, kStarShapeKey) ?? '',
          ) ??
          defaults.starShape,
      starField:
          SkyStarField.fromStored(
            _stringAt(preferences, kStarFieldKey) ?? '',
          ) ??
          defaults.starField,
      twinkle: _boolAt(preferences, kTwinkleKey) ?? defaults.twinkle,
      focusDelaySec:
          _intAt(preferences, kFocusDelaySecKey) ?? defaults.focusDelaySec,
      selahLengthSec:
          _intAt(preferences, kSelahLengthSecKey) ?? defaults.selahLengthSec,
      breathGuide:
          _boolAt(preferences, kBreathGuideKey) ?? defaults.breathGuide,
      vespersAutoDim:
          _boolAt(preferences, kVespersAutoDimKey) ?? defaults.vespersAutoDim,
      calmMotion: _boolAt(preferences, kCalmMotionKey) ?? defaults.calmMotion,
      haptics: _boolAt(preferences, kHapticsKey) ?? defaults.haptics,
    );
  }

  /// The stored [String] at [key], or `null` — **including when it is not a String.**
  ///
  /// ## MEASURED, AND THE OBVIOUS SPELLING IS **WRONG**
  ///
  /// `SharedPreferences.getString` is `_preferenceCache[key] as String?`, so a store
  /// holding `eva.font_step: 'five'` — a value written by an older build, or by a
  /// developer poking at the store — makes `getInt` **throw a `TypeError`** rather than
  /// answer `null`. The first version of this file used the typed getters and the
  /// effect was that one corrupt key made the **whole store** unreadable: the
  /// `TypeError` propagated to `SettingsRepositoryImpl`'s `catch (Object)` and came out
  /// as `FailureKind.storage`, which is the answer for "the store is unreachable".
  ///
  /// That is the wrong answer for the wrong reason. Every other unreadable value in
  /// this file is a default — an unknown mode string, an out-of-table step, a language
  /// this build does not have — and a value of the wrong **type** is no different. So
  /// the raw `get` is used and the type is checked here, which is total for every value
  /// the platform can hand back.
  static String? _stringAt(SharedPreferences preferences, String key) {
    final Object? raw = preferences.get(key);
    return raw is String ? raw : null;
  }

  /// The stored [int] at [key], or `null`. See [_stringAt].
  static int? _intAt(SharedPreferences preferences, String key) {
    final Object? raw = preferences.get(key);
    return raw is int ? raw : null;
  }

  /// The stored [bool] at [key], or `null`. See [_stringAt].
  static bool? _boolAt(SharedPreferences preferences, String key) {
    final Object? raw = preferences.get(key);
    return raw is bool ? raw : null;
  }

  /// Replaces the stored preferences.
  ///
  /// ## THE **TWENTY-NINE** WRITES, AND WHY **NONE** OF THEM IS A `remove`
  ///
  /// The six older keys and the twenty-three new ones are written the same way:
  /// a `set*` per field, mirroring [read] field for field. **Only [kLanguageKey] is
  /// removed rather than written**, and that is because its default is *absent* —
  /// "follow the platform" is the absence of a stored value, and writing `''` would
  /// leave a key in a form no other code writes.
  ///
  /// **None of the twenty-three new fields has an absent default.** Every one is a
  /// non-nullable `bool`, `int` or enum, so a plain write is the whole of the story
  /// and there is no `remove` arm for them. The class doc says so too, because the
  /// next field added to this store should have to answer the question rather than
  /// copy the pattern.
  Future<void> write(UserSettings settings) async {
    final SharedPreferences preferences = await _preferences;
    await preferences.setString(kThemeModeKey, settings.themeMode.storedValue);
    await preferences.setInt(kFontStepKey, settings.fontStep);
    if (settings.language case final ReadingLanguage language) {
      await preferences.setString(kLanguageKey, language.code);
    } else {
      // **A removal and not a write of `''`.** `ReadingLanguage.fromCode('')` is
      // `null`, so writing the empty string would *be* readable — but it would leave a
      // key that says "this reader chose nothing" in a form no other code writes, and
      // `SettingsLocalDataSource`'s round-trip test cannot tell it from a
      // never-written store. Removing it is the only write that makes the store's
      // own shape agree with the value.
      await preferences.remove(kLanguageKey);
    }
    await preferences.setBool(kReducedMotionKey, settings.reducedMotion);
    await preferences.setBool(kVeilWitnessesKey, settings.veilWitnesses);
    await preferences.setBool(kShowPodiumKey, settings.showPodium);
    // ## THE TWENTY-THREE NEW KEYS
    await preferences.setBool(kShaderEnabledKey, settings.shaderEnabled);
    await preferences.setString(
      kCurtainShapeKey,
      settings.curtainShape.storedValue,
    );
    await preferences.setInt(kReachKey, settings.reach);
    await preferences.setInt(kGlowKey, settings.glow);
    await preferences.setInt(kTouchGlowKey, settings.touchGlow);
    await preferences.setInt(kHueKey, settings.hue);
    await preferences.setBool(kMultichromeMeltKey, settings.multichromeMelt);
    await preferences.setBool(kRayCombingKey, settings.rayCombing);
    await preferences.setBool(kWhiteCoresKey, settings.whiteCores);
    await preferences.setBool(kDotVeilKey, settings.dotVeil);
    await preferences.setBool(kStarsOnKey, settings.starsOn);
    await preferences.setBool(kConstellationsOnKey, settings.constellationsOn);
    await preferences.setInt(kStarCountKey, settings.starCount);
    await preferences.setInt(kStarBrightnessKey, settings.starBrightness);
    await preferences.setString(kStarShapeKey, settings.starShape.storedValue);
    await preferences.setString(kStarFieldKey, settings.starField.storedValue);
    await preferences.setBool(kTwinkleKey, settings.twinkle);
    await preferences.setInt(kFocusDelaySecKey, settings.focusDelaySec);
    await preferences.setInt(kSelahLengthSecKey, settings.selahLengthSec);
    await preferences.setBool(kBreathGuideKey, settings.breathGuide);
    await preferences.setBool(kVespersAutoDimKey, settings.vespersAutoDim);
    await preferences.setBool(kCalmMotionKey, settings.calmMotion);
    await preferences.setBool(kHapticsKey, settings.haptics);
  }

  /// The platform store, read once.
  Future<SharedPreferences> get _preferences =>
      _store ??= SharedPreferences.getInstance();

  /// Drops the memoised store, so the next read takes fresh mock values.
  ///
  /// Named `…ForTest` because the package cannot annotate an instance method's
  /// *callers*. It exists because `SharedPreferences.setMockInitialValues` nullifies
  /// the package's own singleton completer but not **this** object's reference to it —
  /// so a second data source in the same test binary would otherwise keep reading the
  /// first one's values, and a round-trip test could pass against a store it had
  /// already written.
  void resetForTest() => _store = null;
}

/// The preferences key holding [AppThemeMode.storedValue].
///
/// Prefixed `eva.` rather than `flutter.`: the package adds its own `flutter.`
/// namespace internally, and a readable prefix means a developer poking at the
/// store can tell which of the app's keys is which without decoding values.
const String kThemeModeKey = 'eva.theme_mode';

/// The preferences key holding the font step. See [kThemeModeKey].
const String kFontStepKey = 'eva.font_step';

/// The preferences key holding `ReadingLanguage.code`, **absent** when the reader has
/// made no choice. See [SettingsLocalDataSource.read].
const String kLanguageKey = 'eva.language';

/// The preferences key holding the reduce-motion preference. See [kThemeModeKey].
const String kReducedMotionKey = 'eva.reduced_motion';

/// The preferences key holding [UserSettings.veilWitnesses].
///
/// `eva.communion.…` rather than `eva.veil_witnesses`, and the namespacing is the
/// point: the field is a **board** preference that `/settings` happens to expose, so a
/// reader poking at the store can see which screen owns it. See [kThemeModeKey] for
/// the prefix rule.
const String kVeilWitnessesKey = 'eva.communion.veil_witnesses';

/// The preferences key holding [UserSettings.showPodium]. See [kVeilWitnessesKey].
const String kShowPodiumKey = 'eva.communion.show_podium';

// ---------------------------------------------------------------------------
// Task 5.7 — the Workshop's twenty-three new keys.
//
// ## EVERY KEY IS `eva.`-PREFIXED AND **NAMESPACED BY ITS GROUP**
//
// The four prefixes are `eva.shader.*` (ten), `eva.sky.pref.*` (seven),
// `eva.ritual.*` (six) — and the `eva.communion.*` pair above, which Task 5.5
// wrote and this task adds nothing to.
//
// The sub-namespace in `eva.sky.pref.*` is load-bearing: `eva.sky.order` and
// `eva.sky.entries` are the **star-record store's** keys
// (`sky_local_data_source.dart`), and a developer poking at the store has to be
// able to tell a *preference* from a *record*.
//
// ## AND EVERY DEFAULT BELOW IS THE **PROTOTYPE'S LITERAL**
//
// `eva/redesign.html` is the design source of truth. The defaults live in
// `user_settings.dart` — this file reads them from there, so there is one
// spelling of each — and the citations are the prototype's own lines.
// ---------------------------------------------------------------------------

/// The preferences key holding [UserSettings.shaderEnabled].
///
/// `eva.shader.enabled` — the Aurora engine switch. `eva/redesign.html:652`,
/// `checked`.
const String kShaderEnabledKey = 'eva.shader.enabled';

/// The preferences key holding [UserSettings.curtainShape]'s `storedValue`.
///
/// `eva.shader.shape` — the Curtain shape segment. `eva/redesign.html:654-655`,
/// `data-s="0"`.
const String kCurtainShapeKey = 'eva.shader.shape';

/// The preferences key holding [UserSettings.reach].
///
/// `eva.shader.reach` — the Reach slider. `eva/redesign.html:658`, `value="42"`.
const String kReachKey = 'eva.shader.reach';

/// The preferences key holding [UserSettings.glow].
///
/// `eva.shader.glow` — the Brightness slider. `eva/redesign.html:659`,
/// `value="100"`.
const String kGlowKey = 'eva.shader.glow';

/// The preferences key holding [UserSettings.touchGlow].
///
/// `eva.shader.touch_glow` — the Touch glow slider. `eva/redesign.html:660`,
/// `value="55"`.
const String kTouchGlowKey = 'eva.shader.touch_glow';

/// The preferences key holding [UserSettings.hue].
///
/// `eva.shader.hue` — the Hue slider. `eva/redesign.html:661`, `value="312"`.
const String kHueKey = 'eva.shader.hue';

/// The preferences key holding [UserSettings.multichromeMelt].
///
/// `eva.shader.melt` — the Multichrome melt switch. `eva/redesign.html:662`.
const String kMultichromeMeltKey = 'eva.shader.melt';

/// The preferences key holding [UserSettings.rayCombing].
///
/// `eva.shader.rays` — the Ray combing switch. `eva/redesign.html:663`,
/// `checked`.
const String kRayCombingKey = 'eva.shader.rays';

/// The preferences key holding [UserSettings.whiteCores].
///
/// `eva.shader.white` — the White cores switch. `eva/redesign.html:664`, `checked`.
const String kWhiteCoresKey = 'eva.shader.white';

/// The preferences key holding [UserSettings.dotVeil].
///
/// `eva.shader.dots` — the Dot veil switch. `eva/redesign.html:665`.
const String kDotVeilKey = 'eva.shader.dots';

/// The preferences key holding [UserSettings.starsOn].
///
/// `eva.sky.pref.stars_on` — the Stars switch. `eva/redesign.html:667`, `checked`.
const String kStarsOnKey = 'eva.sky.pref.stars_on';

/// The preferences key holding [UserSettings.constellationsOn].
///
/// `eva.sky.pref.constellations` — the Constellations switch.
/// `eva/redesign.html:668`, `checked`.
const String kConstellationsOnKey = 'eva.sky.pref.constellations';

/// The preferences key holding [UserSettings.starCount].
///
/// `eva.sky.pref.count` — the Star count slider. `eva/redesign.html:669`,
/// `value="44"`.
const String kStarCountKey = 'eva.sky.pref.count';

/// The preferences key holding [UserSettings.starBrightness].
///
/// `eva.sky.pref.brightness` — the Star brightness slider. `eva/redesign.html:670`,
/// `value="100"`.
const String kStarBrightnessKey = 'eva.sky.pref.brightness';

/// The preferences key holding [UserSettings.starShape]'s `storedValue`.
///
/// `eva.sky.pref.shape` — the Star shape segment. `eva/redesign.html:672-673`,
/// `data-v="s-dot"`.
const String kStarShapeKey = 'eva.sky.pref.shape';

/// The preferences key holding [UserSettings.starField]'s `storedValue`.
///
/// `eva.sky.pref.field` — the Star field segment. `eva/redesign.html:677-678`,
/// `data-v="crown"`.
const String kStarFieldKey = 'eva.sky.pref.field';

/// The preferences key holding [UserSettings.twinkle].
///
/// `eva.sky.pref.twinkle` — the Twinkle switch. `eva/redesign.html:681`, `checked`.
const String kTwinkleKey = 'eva.sky.pref.twinkle';

/// The preferences key holding [UserSettings.focusDelaySec].
///
/// `eva.ritual.focus_delay` — the Focus delay slider. `eva/redesign.html:683`,
/// `value="4"`. The unit is seconds.
const String kFocusDelaySecKey = 'eva.ritual.focus_delay';

/// The preferences key holding [UserSettings.selahLengthSec].
///
/// `eva.ritual.selah_length` — the Selah length slider. `eva/redesign.html:684`,
/// `value="60"`, `step="5"`. The unit is seconds.
const String kSelahLengthSecKey = 'eva.ritual.selah_length';

/// The preferences key holding [UserSettings.breathGuide].
///
/// `eva.ritual.breath` — the Breath guide switch. `eva/redesign.html:685`,
/// `checked`.
const String kBreathGuideKey = 'eva.ritual.breath';

/// The preferences key holding [UserSettings.vespersAutoDim].
///
/// `eva.ritual.vespers` — the Vespers auto-dim switch. `eva/redesign.html:686`,
/// `checked`.
const String kVespersAutoDimKey = 'eva.ritual.vespers';

/// The preferences key holding [UserSettings.calmMotion].
///
/// `eva.ritual.calm` — the Calm motion switch. `eva/redesign.html:688`.
const String kCalmMotionKey = 'eva.ritual.calm';

/// The preferences key holding [UserSettings.haptics].
///
/// `eva.ritual.haptics` — the Haptics switch. `eva/redesign.html:689`, `checked`.
const String kHapticsKey = 'eva.ritual.haptics';
