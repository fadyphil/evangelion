import 'dart:io';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store whose future fails the way an unregistered plugin's does.
///
/// **Through [SettingsLocalDataSource.over], not by substituting
/// `SharedPreferencesStorePlatform.instance`.** The reason is `AGENT_CONTEXT` §8.4:
/// reaching the platform interface means importing
/// `shared_preferences_platform_interface`, a **transitive** dependency, and
/// promoting it is a hard stop — the analyzer's `depend_on_referenced_packages` agrees.
/// It was tried first and is why `SettingsLocalDataSource` carries a four-line named
/// constructor instead of nothing.
///
/// `MissingPluginException` is the real shape: a platform with no implementation
/// completes the channel call with it, and `SharedPreferences.getInstance()` completes
/// its own future with the same object.
SettingsLocalDataSource unreachableStore() {
  final SettingsLocalDataSource store = SettingsLocalDataSource.over(
    Future<SharedPreferences>.error(
      MissingPluginException('no shared_preferences implementation'),
    ),
  );
  addTearDown(store.resetForTest);
  return store;
}

/// The value of a [Success], or a named failure saying what came back instead.
///
/// **`Result` has no throwing accessor, deliberately** — its own doc says "there is no
/// `value` getter and no `getOrNull`", because either would let a caller turn a
/// [FailureResult] into a `null` that surfaces three frames later in a widget build.
/// `valueOrElse` exists but takes a **value**, so the honest spelling is this
/// exhaustive `switch` over the sealed type: a third arm would not compile.
UserSettings unwrap(Result<UserSettings> result) => switch (result) {
  Success<UserSettings>(:final UserSettings value) => value,
  FailureResult<UserSettings>(:final Failure failure) => throw StateError(
    'expected a success and got ${failure.kind}',
  ),
};

/// `settings_repository_test` — the port, over a **real** `shared_preferences`.
///
/// ## WHY A REAL STORE AND NOT A DOUBLE
///
/// The plan asks for "a test that a written setting survives a repository re-read".
/// Two ways to write it, and one of them proves nothing:
///
/// * a hand-written double that returns whatever it was handed. A round trip through it
///   passes whether or not anything was **persisted**, because the second read asks the
///   same object that just answered the first. That is
///   `home_harness.dart`'s recorded reason for hand-writing fakes instead of
///   `mocktail` — "a mock implements whatever it is told to, so it can satisfy the port
///   and answer nothing" — wearing a persistence claim;
/// * a real `shared_preferences` behind an `InMemorySharedPreferencesStore`, with the
///   re-read going through a **second** `SettingsLocalDataSource`.
///
/// This is the second. `SharedPreferences.setMockInitialValues` installs the in-memory
/// store behind the platform interface, so `getInstance()` is a real read through the
/// package's own key prefixing and cache; and a second data source is a distinct object
/// with a distinct memoised reference to the platform singleton, which is what makes
/// "it was written" and "it was held in memory" two different claims.
///
/// ## AND EVERY TEST HERE WRITES THROUGH THE **PORT**
///
/// The constant that holds [key].
///
/// A `switch` over the four keys rather than a derived name, because the mapping from
/// value to identifier is **not** mechanical (`eva.reduced_motion` →
/// `kReducedMotionKey`) and a derived guess would be a second place to get it wrong.
String _constantFor(String key) => switch (key) {
  kThemeModeKey => 'kThemeModeKey',
  kFontStepKey => 'kFontStepKey',
  kLanguageKey => 'kLanguageKey',
  kReducedMotionKey => 'kReducedMotionKey',
  final String other => throw ArgumentError.value(
    other,
    'key',
    'an undeclared preferences key',
  ),
};

/// `SettingsRepository` is the contract under test, so writing the raw keys directly
/// would bypass the one thing being asserted. The raw keys are the subject of
/// `test/features/settings/data/settings_local_data_source_test.dart` instead.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// A second store instance over the same `shared_preferences`.
  ///
  /// **A distinct object is the point** — see the file doc.
  SettingsLocalDataSource freshStore() {
    final SettingsLocalDataSource store = SettingsLocalDataSource();
    addTearDown(store.resetForTest);
    return store;
  }

  /// Loads through a store nobody has written to.
  Future<Result<UserSettings>> loadThroughFreshStore() =>
      SettingsRepositoryImpl(freshStore()).load();

  group('the default install', () {
    test('an empty store IS `UserSettings()`, field for field', () async {
      expect(unwrap(await loadThroughFreshStore()), const UserSettings());
    });

    test('and the default is DARK, step 3, no language, motion on', () async {
      // Spelled out rather than compared to `UserSettings()`, because "the default is
      // the default" is a tautology and this is the claim that matters: the app opens
      // dark (§5.1's dark-first product decision), at the table's identity, following
      // the device's language, with animation.
      const UserSettings defaults = UserSettings();
      expect(defaults.themeMode, AppThemeMode.dark);
      expect(defaults.fontStep, kDefaultFontStep);
      expect(defaults.fontStep, 3);
      expect(evaScalerFor(defaults.fontStep).scale(1), 1.0);
      expect(
        defaults.language,
        isNull,
        reason: 'null is "follow the platform"',
      );
      expect(defaults.reducedMotion, isFalse);
    });
  });

  group('a written setting survives a re-read — the plan requirement', () {
    // ## ONE CASE PER FIELD, NOT ONE CASE PER "it round-trips"
    //
    // A single `save(nonDefault)` / `load()` / `expect(equal)` passes with **one** of
    // the four fields persisting, because the other three round-trip through their
    // defaults and the comparison is on the whole record. Four fields, four cases, and
    // the case name names the field — which is what makes a failure readable.
    const List<({String field, UserSettings value})> cases =
        <({String field, UserSettings value})>[
          (
            field: 'themeMode',
            value: UserSettings(themeMode: AppThemeMode.light),
          ),
          (field: 'fontStep', value: UserSettings(fontStep: 5)),
          (
            field: 'language',
            value: UserSettings(language: ReadingLanguage.arabic),
          ),
          (field: 'reducedMotion', value: UserSettings(reducedMotion: true)),
        ];

    for (final ({String field, UserSettings value}) entry in cases) {
      test(
        '${entry.field} survives, read back through a SECOND store',
        () async {
          final Result<UserSettings> saved = await SettingsRepositoryImpl(
            freshStore(),
          ).save(entry.value);
          expect(
            saved.isSuccess,
            isTrue,
            reason: 'the write itself must succeed',
          );

          expect(
            unwrap(await loadThroughFreshStore()),
            entry.value,
            reason:
                'every other field is at its default and this one is not, so this case '
                'cannot pass on the strength of the other three',
          );
        },
      );
    }

    test('and a whole non-default record round-trips as one value', () async {
      const UserSettings everything = UserSettings(
        themeMode: AppThemeMode.system,
        fontStep: 1,
        language: ReadingLanguage.arabic,
        reducedMotion: true,
      );
      await SettingsRepositoryImpl(freshStore()).save(everything);

      expect(unwrap(await loadThroughFreshStore()), everything);
    });

    test('and a second write REPLACES rather than merging', () async {
      final SettingsRepository writer = SettingsRepositoryImpl(freshStore());
      await writer.save(
        const UserSettings(
          themeMode: AppThemeMode.light,
          fontStep: 5,
          language: ReadingLanguage.arabic,
          reducedMotion: true,
        ),
      );
      await writer.save(const UserSettings(themeMode: AppThemeMode.system));

      final UserSettings after = unwrap(await loadThroughFreshStore());
      expect(after.themeMode, AppThemeMode.system);
      expect(
        after.fontStep,
        kDefaultFontStep,
        reason:
            'a merge would leave 5. The store is written field by field and the '
            'entity is replaced whole, so this is a real assertion about write.',
      );
      expect(
        after.language,
        isNull,
        reason:
            'and `language` is REMOVED rather than written empty — see '
            '`SettingsLocalDataSource.write` on why a removal and not an empty string',
      );
    });
  });

  group('an UNREADABLE value is a default, not a failure', () {
    // `SettingsRepository`'s contract reserves a `Failure` for the store being
    // unreachable, and says why: a reader whose preference is mangled has a working app
    // with default settings, which is materially different from an app that cannot read
    // its store at all.
    test('an unknown theme-mode string falls back to dark', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kThemeModeKey: 'DARK', // capitalised, and therefore not `dark`
      });
      expect(
        unwrap(await loadThroughFreshStore()).themeMode,
        AppThemeMode.dark,
      );
    });

    test(
      'a font step outside the table is read AS STORED — the cubit clamps it',
      () async {
        // **Deliberately not clamped here**, for the reason the boundary's own doc gives:
        // `clampFontStep` needs `EvaTypography`, which is Flutter, and this layer is not.
        // So the store hands back what it holds and `SettingsCubit` — the one boundary —
        // clamps on the way in. Asserting the clamp HERE would be asserting another
        // layer's job; `settings_cubit_test.dart` asserts it there.
        SharedPreferences.setMockInitialValues(<String, Object>{
          kFontStepKey: 99,
        });
        final UserSettings settings = unwrap(await loadThroughFreshStore());
        expect(settings.fontStep, 99);
        expect(
          clampFontStep(settings.fontStep),
          kFontStepMax,
          reason:
              'and the design-system boundary agrees it is out of the table',
        );
      },
    );

    test('a language code this build does not have is `null`, not english', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kLanguageKey: 'fr', // a real language, not one this app ships
      });
      expect(
        unwrap(await loadThroughFreshStore()).language,
        isNull,
        reason:
            '`null` means "follow the platform", which is a defensible answer; '
            'defaulting to English would silently override a device that says '
            'otherwise',
      );
    });

    test('a key of the WRONG TYPE is a default too', () async {
      // `getInt` on a `String` value: the platform store answers `null` rather than
      // throwing, so a version-skewed store cannot take the app down.
      SharedPreferences.setMockInitialValues(<String, Object>{
        kFontStepKey: 'five',
      });
      expect(unwrap(await loadThroughFreshStore()).fontStep, kDefaultFontStep);
    });

    test('and a half-written store keeps what it has', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kThemeModeKey: 'light',
        // the other three never written
      });
      final UserSettings settings = unwrap(await loadThroughFreshStore());
      expect(settings.themeMode, AppThemeMode.light);
      expect(settings.fontStep, kDefaultFontStep);
      expect(settings.language, isNull);
      expect(settings.reducedMotion, isFalse);
    });
  });

  group('the raw keys are namespaced, and the file declares the four', () {
    // The plan's file map says nothing about key names, so this is the one place they
    // are pinned — and it is a *source* assertion as well as a behavioural one, because
    // a store's keys are an interface with the device and with a future migration and
    // nothing else in the app can see them.
    const List<String> keys = <String>[
      kThemeModeKey,
      kFontStepKey,
      kLanguageKey,
      kReducedMotionKey,
    ];

    test('they are distinct and `eva.`-prefixed', () {
      expect(keys.toSet(), hasLength(4));
      for (final String key in keys) {
        expect(key, startsWith('eva.'), reason: '$key must be namespaced');
      }
    });

    test('and the file that writes them declares all four', () {
      final String source = File(
        'lib/features/settings/data/datasources/settings_local_data_source.dart',
      ).readAsStringSync();
      // The **name** of the constant, read out of the value — so the assertion cannot
      // pass by matching the value against itself and cannot rot when the prefix
      // changes. The list is written out above rather than discovered, because a
      // declaration that moved out of the file is the failure this is for.
      for (final String key in keys) {
        final String name = key.split('.').last;
        expect(
          source,
          contains('const String ${_constantFor(key)} ='),
          reason:
              '`$key` must be declared as a named constant in the file that writes it',
        );
        expect(
          source,
          contains("'$key'"),
          reason: 'and the constant must carry the key it is named for',
        );
        expect(name, isNotEmpty);
      }
    });
  });

  group('the port never throws, and reports what it persisted', () {
    test(
      '`save` returns the stored value, so a normalising store is visible',
      () async {
        // `SettingsRepository.save`'s contract: returning the stored value rather than
        // `void` is what makes a write round-trip assertable. Today's implementation does
        // not normalise, so the two are equal — and this pins that, so a future store that
        // does has to change this test rather than surprise a caller.
        const UserSettings value = UserSettings(fontStep: 4);
        final Result<UserSettings> saved = await SettingsRepositoryImpl(
          freshStore(),
        ).save(value);
        expect(unwrap(saved), value);
      },
    );

    test('an unreachable store is a TYPED failure on the READ arm', () async {
      // ## THE `MissingPluginException` PATH, AND IT IS REACHABLE IN PRODUCTION
      //
      // `SharedPreferences` reads from disk over a platform channel and a platform with
      // no plugin registered completes the call with `MissingPluginException`. Nothing
      // above this layer catches it, so an implementation that let it escape would take
      // the app down on a reader's first frame instead of rendering the defaults.
      final Result<UserSettings> loaded = await SettingsRepositoryImpl(
        unreachableStore(),
      ).load();

      expect(
        loaded.isFailure,
        isTrue,
        reason: 'a store that cannot be read must not be an exception',
      );
      expect(loaded, isA<FailureResult<UserSettings>>());
      final Failure failure = (loaded as FailureResult<UserSettings>).failure;
      expect(
        failure.kind,
        FailureKind.storage,
        reason:
            'and `storage` is a kind of its own rather than `network`: no request was '
            'made and no stored value was unreadable',
      );
      expect(failure.message, contains('preferences'));
    });

    test(
      'and on the WRITE arm, which is a second `try` and a real cost',
      () async {
        // A repository whose `catch` wrapped only `load` would pass the read case and
        // throw on the reader's first tap. Two `try` blocks, two cases.
        final Result<UserSettings> saved = await SettingsRepositoryImpl(
          unreachableStore(),
        ).save(const UserSettings(fontStep: 4));

        expect(saved.isFailure, isTrue);
        expect(
          (saved as FailureResult<UserSettings>).failure.kind,
          FailureKind.storage,
        );
      },
    );
  });
}
