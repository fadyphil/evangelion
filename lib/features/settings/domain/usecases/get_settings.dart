import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The reader's stored preferences.
///
/// ## WHAT IT ADDS: NOTHING, AND THAT IS THE POINT
///
/// `LoadScripture`'s doc says the same thing at greater length for the reading side:
/// §3's DIP row makes a use case that reclassified an error or reshaped an entity a
/// **second** place where the store's meaning is decided, and `SettingsLocalDataSource`
/// is already it.
///
/// What this class buys is the **seam**. `SettingsCubit` depends on a use case rather
/// than on a `SettingsRepository`, so a test can hold the read open, or hand back a
/// repository that fails, without a class of its own — `auth_usecases_test.dart`'s
/// hand-written fake over the port is the precedent.
///
/// ## IT IS A [NoParamsUseCase] AND NOT A `UseCase<void, …>`
///
/// `usecase.dart` documents why the two are not related by inheritance: Dart's
/// function subtyping rejects the override outright, and the only "fix" — a `void`
/// parameter with a default — makes `usecase()` fail at the call site. There is
/// nothing to pass, so this is the [NoParamsUseCase] half of the vocabulary and the
/// call site reads `getSettings()`.
final class GetSettings implements NoParamsUseCase<UserSettings> {
  /// Reads through [repository].
  const GetSettings(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<UserSettings>> call() => _repository.load();
}
