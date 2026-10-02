import 'package:evangelion/core/common/app_config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// Everything the composition root can provide today.
///
/// This is the one place in the codebase allowed to read the ambient
/// environment. AGENT_CONTEXT §6, recorded decision 1: the transport takes
/// `baseUrl` as a **constructor parameter**, and `AppConfig` supplies the value
/// *at the composition root only*. So nothing below may read `AppConfig` inline
/// to build a transport — it may only hand the raw value out.
///
/// Registrations live in a `@module` rather than in `injection.dart` on
/// purpose: "what the graph contains" and "how the graph is bootstrapped" are
/// two reasons to change (SRP), and only the second one should ever need the
/// generated file.
@module
abstract class ServiceLocatorModule {
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
