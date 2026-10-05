import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:injectable/injectable.dart';

/// The `settings` feature's registrations.
///
/// **THIS MODULE REGISTERS FOUR THINGS, ALL GENERATED.** It registered **nothing**
/// until this phase — the file existed as an empty `@module` with a doc explaining
/// that Phase 9 was coming, and the prediction in that doc was that the *cubit* would
/// have to be hand-registered rather than generated. That prediction was right and
/// half the module's registrations still are not here; see the paragraph below.
///
/// The four that *are* here are the pure-Dart half and they are here rather than in
/// `navigation_injection.dart` precisely because they are pure Dart: `injection.dart`'s
/// whole transitive project-local import graph is walked by `injection_test.dart` and
/// anything in that closure may not import Flutter, which `SettingsLocalDataSource`
/// could not do — it names `shared_preferences`.
@module
abstract class SettingsModule {
  /// The preference store.
  ///
  /// `@lazySingleton`, and the lifetime is load-bearing for the reason
  /// `AuthLocalDataSource`'s is: the store **is** the state. A factory would hand out
  /// a second store whose memoised platform instance is its own, so a reader's write
  /// through one repository would not be visible through another.
  @lazySingleton
  SettingsLocalDataSource get settingsLocalDataSource =>
      SettingsLocalDataSource();

  /// The one [SettingsRepository] that ships. Typed as the port; see the class doc.
  @lazySingleton
  SettingsRepository get settingsRepository =>
      SettingsRepositoryImpl(getIt<SettingsLocalDataSource>());

  /// Reads the reader's preferences.
  @lazySingleton
  GetSettings get getSettings => GetSettings(getIt<SettingsRepository>());

  /// Writes them.
  @lazySingleton
  UpdateSettings get updateSettings =>
      UpdateSettings(getIt<SettingsRepository>());
}
