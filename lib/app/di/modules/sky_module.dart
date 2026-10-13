import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/features/sky/data/datasources/sky_local_data_source.dart';
import 'package:evangelion/features/sky/data/repositories/sky_repository_impl.dart';
import 'package:injectable/injectable.dart';

/// The `sky` feature's registrations.
///
/// ## WHAT IS HERE, AND WHAT IS NOT, AND WHY THE LINE IS WHERE IT IS
///
/// **Here:** the store and the repository. Both are pure Dart — `SkyLocalDataSource`
/// names `shared_preferences`, which is a package import rather than a
/// `package:flutter` one, so both are reachable from `injection.dart`'s graph
/// without violating the Flutter-free rule AGENT_CONTEXT §6 recorded decision 4
/// makes part of the contract. `SettingsModule` is the precedent that measured
/// this first: it registers a `shared_preferences` data source from a `@module`
/// and `injection_test.dart` stays green.
///
/// **Not here:** [`SkyCubit`]. `flutter_bloc` re-exports the framework's widget
/// layer alongside the bloc, and `bloc` itself is a transitive dependency this
/// project may not promote to a direct one — so a provider here would put
/// `package:flutter/material.dart` inside the composition root's closure. It is
/// registered by hand from `lib/app/di/navigation_injection.dart`, the
/// Flutter-permitted half of the graph, which is the fix already taken six times
/// over for every other cubit and bloc in the app.
///
/// ## THE STORE IS THE SETTINGS STORE, AND THAT IS STATED PLAINLY
///
/// Both data sources memoise `SharedPreferences.getInstance()` — the package's
/// process singleton — so the sky and the settings share one `SharedPreferences`
/// instance rather than each owning one. Registering the sky's data source here,
/// beside the settings one in lifetime if not in file, is what makes that sharing
/// reviewable: a second store would be a second source of truth for one sky.
///
/// ## THE REPOSITORY IS REGISTERED **AGAINST THE PORT**
///
/// [skyRepository] returns `SkyRepository`, not `SkyRepositoryImpl`. That is the
/// substitution ADR-0022 depends on: when a real endpoint arrives for the
/// starfield's "a stars table", this provider's body changes and **nothing else in
/// the app does** — no cubit, no page names `SkyRepositoryImpl`.
@module
abstract class SkyModule {
  /// The lit-sky store.
  ///
  /// `@lazySingleton`, and the lifetime is load-bearing for the reason
  /// `AuthLocalDataSource`'s is: the store **is** the state. A factory would hand
  /// out a second store whose memoised platform instance is its own, so a verse
  /// lit through one repository would not be visible through another.
  @lazySingleton
  SkyLocalDataSource get skyLocalDataSource => SkyLocalDataSource();

  /// The one [SkyRepository] that ships. Typed as the port; see the class doc.
  @lazySingleton
  SkyRepository get skyRepository =>
      SkyRepositoryImpl(getIt<SkyLocalDataSource>());
}
