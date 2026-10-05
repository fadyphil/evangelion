import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
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
/// * the four keys are named, namespaced, and match the file that writes them — a
///   store's keys are an interface with the device and with a future migration, and
///   nothing else in the app can see them;
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
      ];
      expect(keys.toSet(), hasLength(4));
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

    test('and the write puts exactly those four keys in the store', () async {
      await freshStore().write(
        const UserSettings(
          themeMode: AppThemeMode.light,
          fontStep: 4,
          language: ReadingLanguage.arabic,
          reducedMotion: true,
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
      expect(
        raw.getKeys().where((String key) => key.startsWith('eva.')),
        hasLength(4),
        reason:
            'exactly four Eva keys exist — a fifth would be a leaked key nothing reads, '
            'and a missing one is a setting that silently stops persisting',
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
        });
        expect((await freshStore().read()).reducedMotion, isFalse);
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
