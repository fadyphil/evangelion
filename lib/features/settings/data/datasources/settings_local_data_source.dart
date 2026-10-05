import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
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
/// truth for four fields, which is the drift this repository has already paid for
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
/// **four scalar fields** and reads them **once per launch**. The cache exists to
/// avoid a disk read per access, and there is nothing to amortise — a second layer of
/// invalidation between the store and the domain entity is a second way for the
/// rendered theme to disagree with the stored one.
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
  /// default, and a store with three of the four keys reads as the fourth one's
  /// default.
  ///
  /// [UserSettings.language] is the one field where that is more than tidiness,
  /// because its default **is** `null` and `null` there is a third answer ("follow
  /// the platform") rather than an absence. A `Future<UserSettings?>` would have had to
  /// invent a way to say "a theme was stored and no language was", and the field's
  /// own default already says it exactly.
  Future<UserSettings> read() async {
    final SharedPreferences preferences = await _preferences;
    return UserSettings(
      themeMode:
          AppThemeMode.fromStored(
            _stringAt(preferences, kThemeModeKey) ?? '',
          ) ??
          AppThemeMode.dark,
      fontStep: _intAt(preferences, kFontStepKey) ?? kDefaultFontStep,
      language: ReadingLanguage.fromCode(
        _stringAt(preferences, kLanguageKey) ?? '',
      ),
      reducedMotion: _boolAt(preferences, kReducedMotionKey) ?? false,
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
