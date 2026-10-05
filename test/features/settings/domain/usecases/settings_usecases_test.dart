import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GetSettings` and `UpdateSettings` — the two use cases, which add **nothing**.
///
/// ## WHY A FILE WITH NO BEHAVIOUR OF ITS OWN IS WORTH WRITING
///
/// `LoadScripture`'s doc states the argument for a use case at length: §3's DIP row
/// makes a use case that reclassified an error or reshaped an entity a **second** place
/// where the store's meaning is decided, so the seam is bought for the **substitution**
/// and not for the logic. `SettingsCubit` is what tests substitute.
///
/// So these cases assert three properties and each one is a property of the **seam**:
///
/// 1. **they are the vocabulary's right halves** — `GetSettings` is a
///    [NoParamsUseCase] (there is nothing to pass) and `UpdateSettings` is a
///    `UseCase` (there is);
/// 2. **they pass through unchanged**, including the failure arm. A use case that
///    swallowed a `FailureResult` or re-wrapped it would make the port's contract a
///    lie, and the assertion is on the *same instance* rather than on equality so it
///    cannot pass on a copy;
/// 3. **a test can substitute them**, which is the property the cubit's own tests rely
///    on — asserted here by *doing* it.
/// A port that answers what it is told, and counts.
///
/// Hand-written rather than `mocktail` for `app_harness.dart`'s stated reason: "a
/// mock implements whatever it is told to, so it can satisfy the port and answer
/// nothing". This one always answers.
class RecordingSettingsRepository implements SettingsRepository {
  /// What [load] answers.
  Result<UserSettings> onLoad = const Result<UserSettings>.success(
    UserSettings(),
  );

  /// What [save] answers.
  Result<UserSettings> onSave = const Result<UserSettings>.success(
    UserSettings(),
  );

  /// How many times each method was called.
  int loads = 0;
  int saves = 0;

  /// What [save] was handed, in order.
  final List<UserSettings> saved = <UserSettings>[];

  @override
  Future<Result<UserSettings>> load() async {
    loads++;
    return onLoad;
  }

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async {
    saves++;
    saved.add(settings);
    return onSave;
  }
}

void main() {
  const Failure boom = Failure(
    kind: FailureKind.storage,
    message: 'the store went away',
  );

  group('`GetSettings` is a `NoParamsUseCase`, and passes through', () {
    test('the call site is `getSettings()`, with nothing to pass', () async {
      final RecordingSettingsRepository repository =
          RecordingSettingsRepository();
      final GetSettings useCase = GetSettings(repository);

      final Result<UserSettings> result = await useCase();

      expect(repository.loads, 1);
      expect(result.isSuccess, isTrue);
    });

    test('and it is NOT a `UseCase<void, …>`', () {
      // `usecase.dart` spells out why: Dart's function subtyping rejects the override,
      // and the only "fix" — `call([void params])` — makes `useCase()` fail at the call
      // site with "1 positional argument expected". So the two interfaces are unrelated
      // by design, and this is the assertion that the use case is on the right side of
      // the split.
      expect(
        GetSettings(RecordingSettingsRepository()),
        isA<NoParamsUseCase<UserSettings>>(),
      );
      expect(
        GetSettings(RecordingSettingsRepository()),
        isNot(isA<UseCase<void, UserSettings>>()),
      );
    });

    test('a failure is returned UNCHANGED, same instance', () async {
      final RecordingSettingsRepository repository =
          RecordingSettingsRepository()
            ..onLoad = const Result<UserSettings>.failure(boom);
      final Result<UserSettings> result = await GetSettings(repository)();

      expect(result.isFailure, isTrue);
      expect(
        (result as FailureResult<UserSettings>).failure,
        boom,
        reason:
            'the SAME instance. A re-wrapped failure would change the answer for a '
            'caller that matched on identity, and `Failure` excludes `details` from '
            'equality so a copy would still compare equal — which is why this reads '
            'the value and not a rebuilt `Failure`.',
      );
    });
  });

  group('`UpdateSettings` is a `UseCase`, and returns what was persisted', () {
    test('it hands the record to the port and takes the answer back', () async {
      final RecordingSettingsRepository repository =
          RecordingSettingsRepository();
      const UserSettings next = UserSettings(
        themeMode: AppThemeMode.light,
        fontStep: 5,
        language: ReadingLanguage.arabic,
        reducedMotion: true,
      );
      repository.onSave = const Result<UserSettings>.success(next);

      final Result<UserSettings> result = await UpdateSettings(repository)(
        next,
      );

      expect(repository.saves, 1);
      expect(repository.saved, <UserSettings>[next]);
      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<UserSettings>).value,
        next,
        reason:
            'the port returns `UserSettings` rather than `void` so a write round trip is '
            'assertable — a `void` would make "what did it actually save" unanswerable '
            'without a second read',
      );
    });

    test('it does NOT clamp — the cubit is that boundary', () {
      // Asserted in the failing direction. `UpdateSettings`'s own doc says the clamp
      // lives in `SettingsCubit` because `clampFontStep` is a widget-layer function a
      // pure-Dart use case cannot reach under Gate 1 — so a clamp here would be a
      // **second** copy of the table, which is exactly what `fontStepFromScaler`'s doc
      // rejects ("two implementations of one mapping would drift").
      final RecordingSettingsRepository repository =
          RecordingSettingsRepository();
      const UserSettings outOfRange = UserSettings(fontStep: 99);

      UpdateSettings(repository)(outOfRange);

      expect(
        repository.saved.single.fontStep,
        99,
        reason: 'passed through verbatim; `settings_cubit_test.dart` owns the clamp',
      );
    });

    test('a failure is returned UNCHANGED', () async {
      final RecordingSettingsRepository repository =
          RecordingSettingsRepository()
            ..onSave = const Result<UserSettings>.failure(boom);

      final Result<UserSettings> result = await UpdateSettings(repository)(
        const UserSettings(),
      );

      expect(result.isFailure, isTrue);
      expect((result as FailureResult<UserSettings>).failure, boom);
    });
  });

  group('the seam is substitutable, which is the whole reason these exist', () {
    test('a second implementation can stand in for the port', () async {
      // `AGENT_CONTEXT` §3's LSP row: a `SettingsRepository` implementation is
      // substitutable for any other because both arms of the contract — never throwing,
      // always returning a `Result` — are enforced by the type. This is that row
      // exercised rather than quoted.
      final RecordingSettingsRepository fake = RecordingSettingsRepository()
        ..onLoad = const Result<UserSettings>.success(
          UserSettings(themeMode: AppThemeMode.system),
        );
      final RecordingSettingsRepository other = RecordingSettingsRepository();

      final List<SettingsRepository> ports = <SettingsRepository>[fake, other];
      final List<AppThemeMode> answered = <AppThemeMode>[];
      for (final SettingsRepository port in ports) {
        final Result<UserSettings> result = await GetSettings(port)();
        answered.add((result as Success<UserSettings>).value.themeMode);
      }

      expect(answered, <AppThemeMode>[AppThemeMode.system, AppThemeMode.dark]);
      expect(fake.loads, 1);
      expect(other.loads, 1);
    });
  });
}
