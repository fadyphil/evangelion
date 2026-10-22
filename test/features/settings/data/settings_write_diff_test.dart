import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'counting_shared_preferences.dart';

/// The **write count** and the **stored state** of `SettingsLocalDataSource.write`.
///
/// ## WHAT THIS FILE IS FOR
///
/// `write` used to write **all twenty-nine keys on every save**. On Linux,
/// `shared_preferences_linux` re-encodes the whole map and does a **synchronous
/// whole-file write** per `setValue`, on the platform thread — and
/// `EvaRangeSlider` reports a new value on **every pointer update**, so one drag
/// of the hue slider was up to **105 saves × 29 keys = 3,045 whole-file writes**,
/// twenty-eight hundred and sixteen of which wrote a value that had not changed.
///
/// So `write` now keeps the record it last wrote and writes only the keys that
/// differ from it. **Two gates hold that claim, and both are here:
///
/// 1. **THE WRITE COUNT.** A save that changes one setting performs **one**
///    preference write, not twenty-nine. The store is instrumented — see
///    `counting_shared_preferences.dart` — and the count is *measured*, not
///    asserted from the code's shape.
/// 2. **THE STORED STATE.** The state left in the store after any sequence of
///    writes is **identical** to what the old unconditional path left. The proof
///    is a **differential test**: the old path is kept here as a reference
///    implementation, the same sequence of records is run through both, and the
///    two resulting preference maps are compared.
///
/// ## WHY THE OLD PATH LIVES **IN THIS FILE** AND NOT IN `lib/`
///
/// Because it is a **reference implementation for a test**, and `lib/` is the
/// app. Keeping it here means the production file has exactly one write path —
/// the diffing one — and the comparison is between **two implementations of the
/// same contract**, one of which is the thing that shipped.
///
/// ## AND WHY THE COUNTS ARE **MEASURED** RATHER THAN COMPUTED
///
/// Because the multiplier is the whole point of the change, and a number in a
/// doc comment is a number nobody re-measures. Every count in this file comes
/// out of the instrument.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('the write count', () {
    test(
      'the FIRST write writes every key, exactly as the old path did',
      () async {
        final (SettingsLocalDataSource store, CountingPreferences counting) =
            await countingStore();

        await store.write(const UserSettings(language: ReadingLanguage.arabic));

        expect(
          counting.writeCount,
          29,
          reason:
              'there is no previous record to diff against, so the first write must '
              'write all twenty-nine keys — the same twenty-nine the old path '
              'wrote. A first write that skipped a key would leave the store '
              'half-written, and a reader would lose that setting on the next '
              'launch.',
        );
        expect(
          counting.writtenKeys.toSet(),
          _allKeys.toSet(),
          reason:
              'and it must be the twenty-nine the store owns, and no others',
        );
      },
    );

    test('a save that changes ONE setting performs ONE write', () async {
      final (SettingsLocalDataSource store, CountingPreferences counting) =
          await countingStore();

      await store.write(const UserSettings());
      counting.reset();

      await store.write(const UserSettings(hue: 200));

      expect(
        counting.writeCount,
        1,
        reason:
            'one changed field, one preference write. This is the number the old '
            'path paid twenty-nine times over, and it is the whole of the fix.',
      );
      expect(counting.writes, <String>[
        'setInt:$kHueKey',
      ], reason: 'and it is the key that changed');
    });

    test('a save that changes NOTHING performs NO write', () async {
      final (SettingsLocalDataSource store, CountingPreferences counting) =
          await countingStore();

      await store.write(const UserSettings(hue: 200));
      counting.reset();

      await store.write(const UserSettings(hue: 200));

      expect(
        counting.writeCount,
        0,
        reason:
            'the record is the one the store already holds, so there is nothing to '
            'write. The old path wrote all twenty-nine keys for a save that '
            'changed nothing at all.',
      );
    });

    test('a DROPPED language REMOVES the key, in one write', () async {
      // The trap: a diff that only ever *writes* would leave `eva.language` in the
      // store holding the language the reader has just given up, and the store's
      // own shape would no longer agree with the value.
      final (SettingsLocalDataSource store, CountingPreferences counting) =
          await countingStore();

      await store.write(const UserSettings(language: ReadingLanguage.arabic));
      counting.reset();

      await store.write(const UserSettings());

      expect(
        counting.writes,
        <String>['remove:$kLanguageKey'],
        reason:
            'the language was chosen and then given up, so the key is removed — '
            'and it is the only write, because nothing else changed',
      );
      final SharedPreferences raw = await SharedPreferences.getInstance();
      expect(
        raw.containsKey(kLanguageKey),
        isFalse,
        reason: 'and the key is gone from the store, not left holding an empty string',
      );
    });

    test('and a CHOSEN language writes it, in one write', () async {
      final (SettingsLocalDataSource store, CountingPreferences counting) =
          await countingStore();

      await store.write(const UserSettings());
      counting.reset();

      await store.write(const UserSettings(language: ReadingLanguage.arabic));

      expect(counting.writes, <String>['setString:$kLanguageKey']);
    });

    test('and a FULL DRAG costs 133 writes, where the old path cost 3,045', () async {
      // The measured shape of a drag, from the widgets' own numbers:
      // `EvaRangeSlider.trackWidth` is 120 and `thumbSize` is 15, so the thumb
      // travels 105 px, and the hue range is 0–360 — so **every pixel of the drag
      // changes the value**, and a full drag is 105 values.
      final List<UserSettings> drag = _hueDrag(105);

      final int before = await _legacyWriteCount(drag);
      final int after = await _newWriteCount(drag);

      expect(
        before,
        3045,
        reason:
            'the old path wrote all twenty-nine keys on each of the 105 saves. This '
            'number is measured by the same instrument as the one below, so the '
            'two are comparable.',
      );
      expect(
        after,
        133,
        reason:
            'the first save still writes all twenty-nine keys — there is no '
            'previous record to diff against — and each of the remaining 104 '
            'saves writes the one key that changed.',
      );
      expect(
        after,
        lessThan(before),
        reason: 'and the fix is a reduction, not a reshuffle',
      );
    });
  });

  group('the stored state is IDENTICAL to the old path', () {
    for (final ({String name, List<UserSettings> records}) sequence
        in _sequences) {
      test('after ${sequence.name}', () async {
        final Map<String, Object> before = await _legacyState(sequence.records);
        final Map<String, Object> after = await _newState(sequence.records);

        expect(
          after,
          before,
          reason:
              'the same sequence of records through the old unconditional path and '
              'through the diffing path must leave the store holding exactly the '
              'same keys and the same values',
        );
      });
    }
  });

  group('and the sequences are not all the same shape', () {
    test('a removal really does remove a key the old path removed', () async {
      // The differential test compares maps, and a map cannot say "absent" the way
      // a key can. So the one case where absence matters is asserted on its own.
      final SharedPreferences raw = await SharedPreferences.getInstance();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SettingsLocalDataSource store = SettingsLocalDataSource();
      addTearDown(store.resetForTest);

      await store.write(const UserSettings(language: ReadingLanguage.arabic));
      await store.write(const UserSettings());

      expect(
        raw.containsKey(kLanguageKey),
        isFalse,
        reason:
            'the map comparison above already proves the two paths agree; this '
            'proves what they agree ON — the key is absent, not empty',
      );
    });
  });
}

/// The store, instrumented, and the instrument itself.
///
/// **The real store underneath** — the instrument is a *view*, not a second store —
/// so every read and write in these tests is the package's own.
Future<(SettingsLocalDataSource, CountingPreferences)> countingStore() async {
  final SharedPreferences real = await SharedPreferences.getInstance();
  final CountingPreferences counting = CountingPreferences(real);
  final SettingsLocalDataSource store = SettingsLocalDataSource.over(
    Future<SharedPreferences>.value(counting),
  );
  addTearDown(store.resetForTest);
  return (store, counting);
}

/// The write path as it was **before** the diff: every key, every time.
///
/// **A reference implementation, kept here rather than in `lib/`** — see the file
/// doc. It is a verbatim copy of the old `write` body, and it is the half of the
/// differential test that makes the comparison a comparison.
Future<void> legacyWrite(
  SharedPreferences preferences,
  UserSettings settings,
) async {
  await preferences.setString(kThemeModeKey, settings.themeMode.storedValue);
  await preferences.setInt(kFontStepKey, settings.fontStep);
  if (settings.language case final ReadingLanguage language) {
    await preferences.setString(kLanguageKey, language.code);
  } else {
    await preferences.remove(kLanguageKey);
  }
  await preferences.setBool(kReducedMotionKey, settings.reducedMotion);
  await preferences.setBool(kVeilWitnessesKey, settings.veilWitnesses);
  await preferences.setBool(kShowPodiumKey, settings.showPodium);
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

/// The preference map the **old** path leaves behind.
Future<Map<String, Object>> _legacyState(List<UserSettings> records) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  for (final UserSettings record in records) {
    await legacyWrite(preferences, record);
  }
  return _snapshotOf(preferences);
}

/// The preference map the **new** path leaves behind.
Future<Map<String, Object>> _newState(List<UserSettings> records) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SettingsLocalDataSource store = SettingsLocalDataSource();
  addTearDown(store.resetForTest);
  for (final UserSettings record in records) {
    await store.write(record);
  }
  return _snapshotOf(await SharedPreferences.getInstance());
}

/// How many preference writes the **old** path makes over [records].
Future<int> _legacyWriteCount(List<UserSettings> records) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final CountingPreferences counting = CountingPreferences(
    await SharedPreferences.getInstance(),
  );
  for (final UserSettings record in records) {
    await legacyWrite(counting, record);
  }
  return counting.writeCount;
}

/// How many preference writes the **new** path makes over [records].
Future<int> _newWriteCount(List<UserSettings> records) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final CountingPreferences counting = CountingPreferences(
    await SharedPreferences.getInstance(),
  );
  final SettingsLocalDataSource store = SettingsLocalDataSource.over(
    Future<SharedPreferences>.value(counting),
  );
  addTearDown(store.resetForTest);
  for (final UserSettings record in records) {
    await store.write(record);
  }
  return counting.writeCount;
}

/// The store's contents, as a map.
///
/// **Keys that are absent are absent from the map**, which is how a removal is
/// compared: the old path removes `eva.language` and the new one does too, so
/// neither map carries the key.
Map<String, Object> _snapshotOf(SharedPreferences preferences) {
  final Map<String, Object> map = <String, Object>{};
  for (final String key in preferences.getKeys()) {
    final Object? value = preferences.get(key);
    if (value != null) {
      map[key] = value;
    }
  }
  return map;
}

/// A drag of the hue slider: [steps] records, each one a pixel further along.
///
/// **Every record differs from the one before it in exactly one field**, which is
/// what a drag of one slider is: the hue changes and nothing else does.
List<UserSettings> _hueDrag(int steps) => <UserSettings>[
  for (int step = 0; step < steps; step++)
    UserSettings(hue: (step * 360) ~/ steps),
];

/// The twenty-nine keys the store owns.
const List<String> _allKeys = <String>[
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

/// The sequences the differential test runs.
///
/// **Each one exercises a different part of the contract**, and the list is
/// written out rather than generated, because a generated list would be a list of
/// the same case repeated.
final List<({String name, List<UserSettings> records})>
_sequences = <({String name, List<UserSettings> records})>[
  (
    name: 'a single write',
    records: <UserSettings>[
      const UserSettings(
        themeMode: AppThemeMode.light,
        language: ReadingLanguage.arabic,
        hue: 200,
      ),
    ],
  ),
  (
    name: 'the same record twice',
    records: <UserSettings>[
      const UserSettings(hue: 200),
      const UserSettings(hue: 200),
    ],
  ),
  (
    name: 'a language chosen and then given up',
    records: <UserSettings>[
      const UserSettings(language: ReadingLanguage.arabic),
      const UserSettings(),
    ],
  ),
  (
    name: 'a language given up and then chosen again',
    records: <UserSettings>[
      const UserSettings(),
      const UserSettings(language: ReadingLanguage.english),
      const UserSettings(),
    ],
  ),
  (
    name: 'many fields at once',
    records: <UserSettings>[
      const UserSettings(),
      const UserSettings(
        themeMode: AppThemeMode.system,
        fontStep: 5,
        reducedMotion: true,
        veilWitnesses: true,
        showPodium: false,
        reach: 77,
        glow: 111,
        touchGlow: 12,
        hue: 200,
        starCount: 12,
        starBrightness: 140,
        haptics: false,
      ),
    ],
  ),
  (
    name: 'a non-default record replaced by the defaults',
    // The "REPLACES rather than merging" case: the second write must put the
    // *default* back, not leave the first write's value alone.
    records: <UserSettings>[
      const UserSettings(
        themeMode: AppThemeMode.light,
        fontStep: 5,
        language: ReadingLanguage.arabic,
        hue: 200,
      ),
      const UserSettings(),
    ],
  ),
  (name: 'a full drag of the hue slider', records: _hueDrag(105)),
];
