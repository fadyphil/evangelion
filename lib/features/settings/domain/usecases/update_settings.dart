import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// Persists [UserSettings] and reports what was persisted.
///
/// ## IT RETURNS THE STORED VALUE AND NOT `void`, AND THAT IS THE PORT'S DECISION
///
/// `SettingsRepository.save`'s contract returns a `Result<UserSettings>` rather than
/// `Result<void>`, and this use case passes that through unchanged rather than
/// narrowing it. The reason is the round trip the plan asks to be tested: "a written
/// setting survives a repository re-read" is only a *round trip* if something reports
/// what the write actually did, and a `void` would make the assertion a second call
/// whose result could differ for reasons unrelated to the write.
///
/// ## IT DOES **NOT** CLAMP, AND IT IS NOT WHERE CLAMPING LIVES
///
/// `font_size_stepper.dart`'s `clampFontStep` is the boundary that keeps a stored
/// step inside §5.2's table, and it is a `core/design_system` function — which puts it
/// out of reach of a pure-Dart use case under Gate 1. The clamp therefore happens in
/// `SettingsCubit`, which is a Flutter file and already imports the barrel.
///
/// The alternative — clamping here, by duplicating the two bounds — is rejected for
/// the reason `fontStepFromScaler`'s doc gives: "two implementations of one mapping
/// would drift, so this reads `evaScalerFor` rather than restating it." A second copy
/// of `kFontStepMin`/`kFontStepMax` in `features/settings/domain/` would be exactly
/// that, in the one layer a test is least likely to reach.
final class UpdateSettings implements UseCase<UserSettings, UserSettings> {
  /// Writes through [repository].
  const UpdateSettings(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<UserSettings>> call(UserSettings params) =>
      _repository.save(params);
}
