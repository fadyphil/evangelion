import 'package:dio/dio.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/core/network/dio_client.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
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
/// to change here is now the transport. Keeping both files would have left two
/// `@module`s split along a line with no reason behind it — two names to keep in
/// step and no reason to change either.
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
/// ## AND WHY `AuthBloc` IS NOT HERE EITHER
///
/// `flutter_bloc` re-exports the framework's widget layer alongside the bloc, and
/// `bloc` itself is a transitive dependency this project may not promote to a
/// direct one (AGENT_CONTEXT §9, decision 11). Registering `AuthBloc` from a
/// `@module` would put `package:flutter/material.dart` inside
/// `injection.dart`'s graph. It is registered by hand in `navigation_injection.dart`,
/// beside the router.
///
/// So this module is **Flutter-free by construction** and stays so. The gate is
/// not a comment: `injection_test.dart` walks the whole transitive project-local
/// graph from `injection.dart` and fails on any Flutter import it reaches.
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
  /// singleton, so `@lazySingleton` and `@factory` yield the identical object and
  /// `identical(getIt<GetIt>(), getIt)` holds either way. Registering it as a
  /// singleton is still correct — it states the intent and saves a call through
  /// the factory func — but the registration is not what makes the locator
  /// unique. `injection_test.dart` states the limitation next to the assertion it
  /// constrains, and carries a negative control proving the harness would
  /// otherwise have caught a factory.
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
  /// the first time this graph needs a second string (a header value, an endpoint
  /// path) an unnamed registration silently shadows it. Naming it means the
  /// lookup site has to say which string it wants.
  ///
  /// The `/api/v1` prefix is deliberately absent — it belongs to the endpoint
  /// definitions, not to the host.
  ///
  /// ## AND IT IS ACTUALLY CONSUMED, WHICH IT WAS NOT
  ///
  /// The first version of this file registered the name and then ignored it:
  /// [apiClient] read `AppConfig.apiBaseUrl` inline, so nothing ever asked the
  /// locator which string it wanted and the paragraph above — "naming it means the
  /// lookup site has to say which string it wants" — described a lookup that did not
  /// exist. A registration with no consumer is documentation with a dependency
  /// resolver attached, and it is worse than not registering at all, because the
  /// naming reads as a guarantee.
  ///
  /// So [apiClient] now **takes the URL as a parameter** and get_it injects the named
  /// registration into it. That is also the shape `dio_client.dart` demands: its doc
  /// requires that "every input is a parameter and this file never names `AppConfig`
  /// at all", and reading the constant inline in the provider was the one place that
  /// broke the rule. The composition root supplies the value; it no longer supplies it
  /// by reaching past its own registration.
  @lazySingleton
  @Named('apiBaseUrl')
  String get apiBaseUrl => AppConfig.apiBaseUrl;

  /// The one `Dio` the app talks to.
  ///
  /// `@lazySingleton` and not `@factory`, and here the lifetime **is** the point:
  /// an interceptor holds a subscription-free but stateful identity, and two
  /// clients would mean two identities the app could disagree with — the same
  /// hazard `navigation_injection.dart` records for the router.
  ///
  /// ## THIS IS WHERE THE TWO HALVES OF THE DECISION-2 SPLIT MEET
  ///
  /// [AppConfig] supplies transport (base URL, timeouts) and
  /// `kSeedUserId` / `kSeedGroupId` / `kSeedUserRole` supply identity, and this is
  /// the only line in the app that touches both. That is deliberate: it is the one
  /// place the two facts have to agree, and having it be a single expression
  /// means a deployment that overrides the host cannot forget to supply an
  /// identity, and a seed that stops being a UUID fails here rather than on the
  /// wire.
  ///
  /// A `lib/core/` module reaching into `features/auth/data/` is legal —
  /// `tool/verify_purity.sh` Gate 2 exempts `lib/app/` for exactly this reason —
  /// and it is recorded here rather than left to be rediscovered as a layering
  /// question. The alternative, a second module, would move the meeting point
  /// somewhere less obvious without making it any safer.
  ///
  /// ## AND IT IS EXERCISED, WHICH IT WAS NOT
  ///
  /// `injection_test.dart` resolved the **string** `lazySingleton<Dio> apiClient` in
  /// the generated file's text, which is not behaviour, and nothing in the suite
  /// resolved `getIt<Dio>()` at all. Replacing both timeouts with
  /// `const Duration(days: 1)` therefore left all 1200 tests green. The test now
  /// resolves the client and reads `options.baseUrl`, `options.connectTimeout`,
  /// `options.receiveTimeout` and the interceptor list off it, so the transport
  /// configuration is a fact about the graph the app really builds.
  ///
  /// ## WHY THE TIMEOUTS ARE READ INLINE AND THE BASE URL IS NOT
  ///
  /// Because the base URL has a **named registration that must be consumed** and the
  /// timeouts do not. Adding `@Named('connectTimeout')` / `@Named('receiveTimeout')`
  /// would be the same defect as an unread `@Named('apiBaseUrl')`: two more names in
  /// the locator with exactly one reader each, and `AppConfig` is the transport's one
  /// home (recorded decision 16), so `core_module.dart` reading it is the documented
  /// meeting point rather than a leak.
  @lazySingleton
  Dio apiClient(@Named('apiBaseUrl') String baseUrl) => buildApiDio(
    baseUrl: baseUrl,
    identity: const IdentityHeadersInterceptor(
      userId: kSeedUserId,
      groupId: kSeedGroupId,
      role: kSeedUserRole,
    ),
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
  );

  /// The API error mapper.
  ///
  /// `@lazySingleton` over a `const`-constructible stateless class, so the
  /// registration costs nothing and every repository can take the same instance —
  /// which matters only for the seam, not for the behaviour.
  @lazySingleton
  ApiErrorMapper get apiErrorMapper => const ApiErrorMapper();
}
