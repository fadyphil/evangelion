import 'package:evangelion/core/common/app_config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// Everything the composition root can provide that is **pure Dart**.
///
/// ## WHY THIS FILE IS CALLED `core_module`
///
/// It was `lib/app/di/service_locator_module.dart` through Phase 3, when
/// registering the locator was all it did — the name described its one member.
/// `docs/plans/07-file-map.md` §7 names this file `core_module.dart` and
/// annotates it "Result, failure mapper, `AppConfig`, `AppRouter`", which is a
/// description of *core* rather than of a service locator, and the second reason
/// to change here is now `AppConfig` (Phase 5's transport, Phase 9's settings).
/// Keeping both files would have left two `@module`s split along a line with no
/// reason behind it — two names to keep in step and no reason to change either.
///
/// ## WHY `AppRouter` IS **NOT** HERE, THOUGH THE FILE MAP SAYS IT IS
///
/// `AppRouter` extends `RootStackRouter`, so registering it here would put it in
/// `injection.dart`'s transitive project-local import graph, and that graph is
/// required to be Flutter-free — `injection_test.dart` walks it and AGENT_CONTEXT
/// §6 recorded decision 4 makes the walk part of the contract. The router also
/// names all six `*Route` classes inside their features, so importing it drags in
/// `package:flutter/material.dart` through the generated route files.
///
/// The file map is therefore right about the name and out of date about the
/// contents. The router is registered by `lib/app/di/navigation_injection.dart`,
/// which is allowed to touch Flutter; the reasoning is written out there.
///
/// Registrations live in a `@module` rather than in `injection.dart` on purpose:
/// "what the graph contains" and "how the graph is bootstrapped" are two reasons
/// to change (SRP), and only the second one should ever need the generated file.
@module
abstract class CoreModule {
  /// The locator itself.
  ///
  /// Registered so a use case or adapter can declare `GetIt` as an injected
  /// dependency instead of reaching for the global. That is what makes the graph
  /// substitutable in a test — a fake can be handed the same locator through
  /// its constructor parameter and resolve the same collaborators.
  ///
  /// What the *lifetime* does not buy, and what no test in the suite can check:
  /// this provider returns `GetIt.instance`, which is itself a process-wide
  /// singleton, so `@lazySingleton` and `@factory` yield the identical object
  /// and `identical(getIt<GetIt>(), getIt)` holds either way. Registering it as
  /// a singleton is still correct — it states the intent and saves a call
  /// through the factory func — but the registration is not what makes the
  /// locator unique. `injection_test.dart` states the limitation next to the
  /// assertion it constrains, and carries a negative control proving the
  /// harness would otherwise have caught a factory.
  ///
  /// CONTRAST WITH `AppRouter`, WHICH IS THE OPPOSITE CASE. There the provider
  /// builds a *new* object per call, so the lifetime is the whole point and
  /// `@factory` would be a real bug — see `navigation_injection_test.dart`.
  @lazySingleton
  GetIt get serviceLocator => GetIt.instance;

  /// The backend base URL, from `AppConfig`.
  ///
  /// Registered under `@Named('apiBaseUrl')` rather than as a bare `String`.
  /// A locator that holds an unnamed `String` is a collision waiting to happen:
  /// the first time Phase 5 needs a second string (a header value, an endpoint
  /// path) an unnamed registration silently shadows it. Naming it means the
  /// lookup site has to say which string it wants.
  ///
  /// The `/api/v1` prefix is deliberately absent — it belongs to the endpoint
  /// definitions, not to the host.
  @lazySingleton
  @Named('apiBaseUrl')
  String get apiBaseUrl => AppConfig.apiBaseUrl;
}
