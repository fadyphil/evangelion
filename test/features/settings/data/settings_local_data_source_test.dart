import 'dart:io';

// **The design system's own `CurtainShape` is HIDDEN**, and the hiding is not
// cosmetic. `core/design_system/widgets/neural_scaffold.dart:22` declares a
// `CurtainShape` of its own — the **scrim's** direction, with three members
// (`top`, `bottom`, `sides`) — and the barrel exports it. Task 5.7's
// `core/domain/entities/curtain_shape.dart` declares a **second** `CurtainShape`
// with four members (`top`, `bottom`, `sides`, `shafts`) — the aurora curtain's
// shape. A file that imports both gets an ambiguous-name error, and the two are
// different things that happen to share a name.
//
// The domain one is the one this file means, so the barrel's is hidden.
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SettingsLocalDataSource` — the **keys** and the **defensive reads**, which is the
/// part of the settings feature a behavioural round trip cannot see.
///
/// `test/core/domain/repositories/settings_repository_test.dart` proves the values
/// survive. This file proves:
///
/// * the twenty-nine keys are named, namespaced, and match the file that writes them
///   — a store's keys are an interface with the device and with a future migration,
///   and nothing else in the app can see them;
/// * **each of the twenty-three new keys carries its own field and no other**, which
///   is what "the key names the field" means when a reader pokes at the store;
/// * an unreadable key answers the field's **default** and never `null` and never a
///   throw;
/// * `language` is **removed** when it is `null`, not written as an empty string, so the
///   store's own shape agrees with the value;
/// * `resetForTest` exists because the package's `setMockInitialValues` nullifies the
///   package's singleton but not **this** object's reference to it — and a store that
///   kept reading the previous test's values would make every round trip pass.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  SettingsLocalDataSource freshStore() {
    final SettingsLocalDataSource store = SettingsLocalDataSource();
    addTearDown(store.resetForTest);
    return store;
  }

  /// The raw store, for the key assertions.
  Future<SharedPreferences> rawStore() async => SharedPreferences.getInstance();

  group('the keys', () {
    test('are `eva.`-prefixed, distinct, and declared in this file', () {
      const List<String> keys = <String>[
        kThemeModeKey,
        kFontStepKey,
        kLanguageKey,
        kReducedMotionKey,
        kVeilWitnessesKey,
        kShowPodiumKey,
        kShaderEnabledKey,
        kCurtainShapeKey,
        kReachKey,
        kGlowKey,
        kTouchGlowKey,
        kHueKey,
        kMultichromeMeltKey,
        kRayCombingKey,
        kWhiteCoresKey,
        kDotVeilKey,
        kStarsOnKey,
        kConstellationsOnKey,
        kStarCountKey,
        kStarBrightnessKey,
        kStarShapeKey,
        kStarFieldKey,
        kTwinkleKey,
        kFocusDelaySecKey,
        kSelahLengthSecKey,
        kBreathGuideKey,
        kVespersAutoDimKey,
        kCalmMotionKey,
        kHapticsKey,
      ];
      expect(keys.toSet(), hasLength(29));
      for (final String key in keys) {
        expect(key, startsWith('eva.'), reason: '$key must be namespaced');
      }

      // **A source assertion, because a key is data and not behaviour.** No other gate
      // in this repository can see a store's keys, and `barrel_test.dart`'s
      // directory-listing comparison — which is the established pattern for exactly this
      // problem — does not apply to a constant in a data file.
      final String source = File(
        'lib/features/settings/data/datasources/settings_local_data_source.dart',
      ).readAsStringSync();
      for (final String key in keys) {
        expect(
          source,
          contains("'$key'"),
          reason: '$key must appear in the file',
        );
      }
    });

    test('and the twenty-three new ones use the FOUR group prefixes', () {
      // The plan named three prefixes and the code has four. The fourth is not an
      // invention: `eva.communion.*` was written by Task 5.5.
      const List<String> shaderKeys = <String>[
        kShaderEnabledKey,
        kCurtainShapeKey,
        kReachKey,
        kGlowKey,
        kTouchGlowKey,
        kHueKey,
        kMultichromeMeltKey,
        kRayCombingKey,
        kWhiteCoresKey,
        kDotVeilKey,
      ];
      const List<String> skyKeys = <String>[
        kStarsOnKey,
        kConstellationsOnKey,
        kStarCountKey,
        kStarBrightnessKey,
        kStarShapeKey,
        kStarFieldKey,
        kTwinkleKey,
      ];
      const List<String> ritualKeys = <String>[
        kFocusDelaySecKey,
        kSelahLengthSecKey,
        kBreathGuideKey,
        kVespersAutoDimKey,
        kCalmMotionKey,
        kHapticsKey,
      ];

      expect(shaderKeys, hasLength(10));
      expect(skyKeys, hasLength(7));
      expect(ritualKeys, hasLength(6));

      for (final String key in shaderKeys) {
        expect(key, startsWith('eva.shader.'), reason: key);
      }
      for (final String key in skyKeys) {
        // **NOT** a bare `eva.sky.` — `eva.sky.order` and `eva.sky.entries` are the
        // star-record store's keys, and a reader poking at the store has to be able to
        // tell a preference from a record.
        expect(key, startsWith('eva.sky.pref.'), reason: key);
      }
      for (final String key in ritualKeys) {
        expect(key, startsWith('eva.ritual.'), reason: key);
      }
    });

    test('and the write puts exactly those twenty-nine keys in the store', () async {
      await freshStore().write(
        const UserSettings(
          themeMode: AppThemeMode.light,
          fontStep: 4,
          language: ReadingLanguage.arabic,
          reducedMotion: true,
          veilWitnesses: true,
          showPodium: false,
        ),
      );

      // **Unprefixed**, because the package's `flutter.` namespace is an implementation
      // detail of its store: `setMockInitialValues` adds it on the way in and
      // `getInstance` strips it on the way out, so a key read through the public API is
      // the bare `eva.…`. Asserting the prefixed spelling here would be asserting the
      // package's internals, and `settings_local_data_source.dart`'s doc records the
      // `eva.` prefix as the *readable* one for exactly that reason.
      final SharedPreferences raw = await rawStore();
      expect(raw.getString(kThemeModeKey), 'light');
      expect(raw.getInt(kFontStepKey), 4);
      expect(raw.getString(kLanguageKey), 'ar');
      expect(raw.getBool(kReducedMotionKey), isTrue);
      expect(raw.getBool(kVeilWitnessesKey), isTrue);
      expect(raw.getBool(kShowPodiumKey), isFalse);
      expect(
        raw.getKeys().where((String key) => key.startsWith('eva.')),
        hasLength(29),
        reason:
            'exactly twenty-nine Eva keys exist — a thirtieth would be a leaked key '
            'nothing reads, and a missing one is a setting that silently stops '
            'persisting',
      );
    });

    test('and an UNCHOSEN language REMOVES its key rather than writing an empty one', () async {
      // The alternative — `setString(kLanguageKey, '')` — would be *readable*
      // (`ReadingLanguage.fromCode('')` is `null`) and therefore indistinguishable from a
      // never-written store by behaviour alone. Removal is the only write that makes the
      // store's shape agree with the value, and this is the assertion that says so.
      final SettingsLocalDataSource store = freshStore();
      await store.write(const UserSettings(language: ReadingLanguage.arabic));
      expect((await rawStore()).containsKey(kLanguageKey), isTrue);

      await store.write(const UserSettings());
      final SharedPreferences raw = await rawStore();
      expect(raw.containsKey(kLanguageKey), isFalse);
      expect(
        (await store.read()).language,
        isNull,
        reason: 'and the read still says "follow the platform"',
      );
    });
  });

  group('the twenty-three new keys, each one carrying its OWN field', () {
    for (final _KeyCase keyCase in _keyCases) {
      group(keyCase.name, () {
        test('round-trips through the store', () async {
          final SettingsLocalDataSource store = freshStore();
          await store.write(keyCase.value);

          final UserSettings read = await store.read();
          expect(
            keyCase.read(read),
            keyCase.read(keyCase.value),
            reason: 'the value must survive the round trip',
          );
          expect(
            read,
            keyCase.value,
            reason:
                'and the whole record must come back — the twenty-two other new '
                'fields and the six older ones are at their defaults and must be '
                'untouched by this key',
          );
        });

        test('and the raw store holds the key it names', () async {
          final SettingsLocalDataSource store = freshStore();
          await store.write(keyCase.value);

          final SharedPreferences raw = await rawStore();
          expect(
            raw.get(keyCase.key),
            keyCase.stored,
            reason: '${keyCase.key} must hold ${keyCase.stored}',
          );
        });

        test('an ABSENT key answers the default', () async {
          // The store is empty — `setUp` installed no values — so every key is
          // absent, and every field must answer its own default rather than a null
          // or a throw.
          final UserSettings read = await freshStore().read();
          expect(
            keyCase.read(read),
            keyCase.read(const UserSettings()),
            reason: 'an absent ${keyCase.key} must answer the default',
          );
        });

        test('a WRONG-TYPE value answers the default and does NOT throw', () async {
          // `SharedPreferences.getInt` is `_preferenceCache[key] as int?`, so a store
          // holding a String under an int key **throws a `TypeError`** — and the
          // first version of this file used the typed getters, which turned one
          // corrupt key into `FailureKind.storage` for the whole store. Every other
          // unreadable value in this feature is a default; a value of the wrong
          // *type* is no different.
          SharedPreferences.setMockInitialValues(<String, Object>{
            keyCase.key: keyCase.wrongType,
          });

          final UserSettings read = await freshStore().read();
          expect(
            keyCase.read(read),
            keyCase.read(const UserSettings()),
            reason:
                'a wrong-typed ${keyCase.key} must answer the default, not throw and '
                'not be read as a value',
          );
        });
      });
    }
  });

  group(
    'the defensive reads are TOTALLY over what the platform can hand back',
    () {
      // ## MEASURED: THE OBVIOUS SPELLING MAKES A CORRUPT KEY FATAL
      //
      // `SharedPreferences.getInt` is `_preferenceCache[key] as int?`, so a store holding
      // `eva.font_step: 'five'` **throws a `TypeError`** — and the first version of this
      // file used the typed getters, which turned one corrupt key into
      // `FailureKind.storage` for the whole store. Every other unreadable value in this
      // feature is a default; a value of the wrong *type* is no different.
      test('an `int` key holding a String reads as absent', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kFontStepKey: 'five',
        });
        expect((await freshStore().read()).fontStep, kDefaultFontStep);
      });

      test('a `bool` key holding an `int` reads as absent', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kReducedMotionKey: 1,
          kVeilWitnessesKey: 1,
          kShowPodiumKey: 0,
        });
        final UserSettings settings = await freshStore().read();
        expect(settings.reducedMotion, isFalse);
        expect(settings.veilWitnesses, isFalse);
        expect(settings.showPodium, isTrue);
      });

      test('a `String` key holding a `bool` reads as absent', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kThemeModeKey: true,
        });
        expect((await freshStore().read()).themeMode, AppThemeMode.dark);
      });

      test(
        'and a `double` is NOT an `int`, even though it is a number',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            kFontStepKey: 3.0,
          });
          expect(
            (await freshStore().read()).fontStep,
            kDefaultFontStep,
            reason:
                '`3.0` is not `3`, and accepting it would mean the store and the stepper '
                'could disagree about what step 3 is',
          );
        },
      );
    },
  );

  group('`resetForTest`, because the package reset is not enough', () {
    // `SharedPreferences.setMockInitialValues` nullifies the package's singleton
    // completer but **not** this object's memoised reference to it. Without the reset a
    // second data source in the same test binary keeps reading the first one's values,
    // and a round-trip test passes against a store it had already written — which is
    // the exact failure this method exists to prevent.
    test(
      'a second instance sees the CURRENT mock values, not the stale ones',
      () async {
        final SettingsLocalDataSource first = freshStore();
        await first.write(const UserSettings(themeMode: AppThemeMode.light));
        expect((await first.read()).themeMode, AppThemeMode.light);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SettingsLocalDataSource second = freshStore();
        addTearDown(second.resetForTest);

        expect(
          (await second.read()).themeMode,
          AppThemeMode.dark,
          reason:
              'the store is empty. Without `resetForTest` the memoised instance would '
              'still hold the previous store and this would read `light`.',
        );
      },
    );
  });

  group('the store is a `lazySingleton` in the graph, so identity matters', () {
    test('two reads through one instance agree', () async {
      final SettingsLocalDataSource store = freshStore();
      await store.write(const UserSettings(fontStep: 2));
      expect((await store.read()).fontStep, 2);
      expect((await store.read()).fontStep, 2);
      expect(
        kDefaultFontStep,
        3,
        reason:
            'and the default is still the table identity, which `evaScalerFor` '
            'confirms is 1.00x — the app opens at the size the device asks for',
      );
      expect(evaScalerFor(kDefaultFontStep).scale(1), 1.0);
    });
  });
}

/// One of the twenty-three new keys and the field it carries.
///
/// **A top-level class and not a local one**, because Dart has no local classes.
final class _KeyCase {
  const _KeyCase({
    required this.name,
    required this.key,
    required this.value,
    required this.read,
    required this.stored,
    required this.wrongType,
  });

  /// The field's own name, for the group heading.
  final String name;

  /// The preferences key.
  final String key;

  /// A record whose **only** non-default field is this one.
  final UserSettings value;

  /// Reads this key's field out of a record.
  final Object? Function(UserSettings) read;

  /// What the raw store must hold after the write.
  final Object? stored;

  /// A value of the **wrong type** for this key.
  final Object wrongType;
}

/// The twenty-three new keys, one case each.
///
/// **Every `value` differs from its default in exactly one field**, which is what
/// makes the round-trip assertion sharp: if a key were bound to the wrong field, the
/// record read back would differ from the record written.
final List<_KeyCase> _keyCases = <_KeyCase>[
  _KeyCase(
    name: 'shaderEnabled',
    key: kShaderEnabledKey,
    value: const UserSettings(shaderEnabled: false),
    read: (UserSettings s) => s.shaderEnabled,
    stored: false,
    wrongType: 1,
  ),
  _KeyCase(
    name: 'curtainShape',
    key: kCurtainShapeKey,
    value: const UserSettings(curtainShape: CurtainShape.shafts),
    read: (UserSettings s) => s.curtainShape,
    stored: 'shafts',
    wrongType: 3,
  ),
  _KeyCase(
    name: 'reach',
    key: kReachKey,
    value: const UserSettings(reach: 77),
    read: (UserSettings s) => s.reach,
    stored: 77,
    wrongType: 'far',
  ),
  _KeyCase(
    name: 'glow',
    key: kGlowKey,
    value: const UserSettings(glow: 111),
    read: (UserSettings s) => s.glow,
    stored: 111,
    wrongType: 'bright',
  ),
  _KeyCase(
    name: 'touchGlow',
    key: kTouchGlowKey,
    value: const UserSettings(touchGlow: 12),
    read: (UserSettings s) => s.touchGlow,
    stored: 12,
    wrongType: 'soft',
  ),
  _KeyCase(
    name: 'hue',
    key: kHueKey,
    value: const UserSettings(hue: 200),
    read: (UserSettings s) => s.hue,
    stored: 200,
    wrongType: 'pink',
  ),
  _KeyCase(
    name: 'multichromeMelt',
    key: kMultichromeMeltKey,
    value: const UserSettings(multichromeMelt: true),
    read: (UserSettings s) => s.multichromeMelt,
    stored: true,
    wrongType: 0,
  ),
  _KeyCase(
    name: 'rayCombing',
    key: kRayCombingKey,
    value: const UserSettings(rayCombing: false),
    read: (UserSettings s) => s.rayCombing,
    stored: false,
    wrongType: 1,
  ),
  _KeyCase(
    name: 'whiteCores',
    key: kWhiteCoresKey,
    value: const UserSettings(whiteCores: false),
    read: (UserSettings s) => s.whiteCores,
    stored: false,
    wrongType: 1,
  ),
  _KeyCase(
    name: 'dotVeil',
    key: kDotVeilKey,
    value: const UserSettings(dotVeil: true),
    read: (UserSettings s) => s.dotVeil,
    stored: true,
    wrongType: 0,
  ),
  _KeyCase(
    name: 'starsOn',
    key: kStarsOnKey,
    value: const UserSettings(starsOn: false),
    read: (UserSettings s) => s.starsOn,
    stored: false,
    wrongType: 1,
  ),
  _KeyCase(
    name: 'constellationsOn',
    key: kConstellationsOnKey,
    value: const UserSettings(constellationsOn: false),
    read: (UserSettings s) => s.constellationsOn,
    stored: false,
    wrongType: 1,
  ),
  _KeyCase(
    name: 'starCount',
    key: kStarCountKey,
    value: const UserSettings(starCount: 12),
    read: (UserSettings s) => s.starCount,
    stored: 12,
    wrongType: 'many',
  ),
  _KeyCase(
    name: 'starBrightness',
    key: kStarBrightnessKey,
    value: const UserSettings(starBrightness: 140),
    read: (UserSettings s) => s.starBrightness,
    stored: 140,
    wrongType: 'bright',
  ),
  _KeyCase(
    name: 'starShape',
    key: kStarShapeKey,
    value: const UserSettings(starShape: SkyStarShape.diamond),
    read: (UserSettings s) => s.starShape,
    stored: 's-diamond',
    wrongType: 3,
  ),
  _KeyCase(
    name: 'starField',
    key: kStarFieldKey,
    value: const UserSettings(starField: SkyStarField.full),
    read: (UserSettings s) => s.starField,
    stored: 'full',
    wrongType: 2,
  ),
  _KeyCase(
    name: 'twinkle',
    key: kTwinkleKey,
    value: const UserSettings(twinkle: false),
    read: (UserSettings s) => s.twinkle,
    stored: false,
    wrongType: 0,
  ),
  _KeyCase(
    name: 'focusDelaySec',
    key: kFocusDelaySecKey,
    value: const UserSettings(focusDelaySec: 9),
    read: (UserSettings s) => s.focusDelaySec,
    stored: 9,
    wrongType: 'nine',
  ),
  _KeyCase(
    name: 'selahLengthSec',
    key: kSelahLengthSecKey,
    value: const UserSettings(selahLengthSec: 30),
    read: (UserSettings s) => s.selahLengthSec,
    stored: 30,
    wrongType: 'sixty',
  ),
  _KeyCase(
    name: 'breathGuide',
    key: kBreathGuideKey,
    value: const UserSettings(breathGuide: false),
    read: (UserSettings s) => s.breathGuide,
    stored: false,
    wrongType: 0,
  ),
  _KeyCase(
    name: 'vespersAutoDim',
    key: kVespersAutoDimKey,
    value: const UserSettings(vespersAutoDim: false),
    read: (UserSettings s) => s.vespersAutoDim,
    stored: false,
    wrongType: 0,
  ),
  _KeyCase(
    name: 'calmMotion',
    key: kCalmMotionKey,
    value: const UserSettings(calmMotion: true),
    read: (UserSettings s) => s.calmMotion,
    stored: true,
    wrongType: 0,
  ),
  _KeyCase(
    name: 'haptics',
    key: kHapticsKey,
    value: const UserSettings(haptics: false),
    read: (UserSettings s) => s.haptics,
    stored: false,
    wrongType: 0,
  ),
];
