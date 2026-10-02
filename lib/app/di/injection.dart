import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// The application's single service locator.
///
/// Plain `GetIt.instance`, not a bespoke subclass: the only reason to subclass
/// a locator is to intercept lookups, and nothing here does. It is `final` at
/// top level so there is one instance and no way to rebind the name.
final GetIt getIt = GetIt.instance;

/// Builds the object graph.
///
/// Call this once, before `runApp`. `throwOnMissingDependencies` is on so a
/// registration whose dependencies were never registered fails the build rather
/// than the first screen that happens to need it.
///
/// **Flutter-free by construction.** `get_it` and `injectable` are pure Dart,
/// this file imports nothing from `package:flutter/`, and neither does anything
/// it reaches. So composition is unit-testable without
/// `WidgetsFlutterBinding.ensureInitialized()`.
///
/// `injection_test.dart` walks the transitive project-local import graph to keep
/// that true. The walk follows `import`, `export` and `part` directives in both
/// quote styles, because all three make the named library part of this file's
/// own surface. An earlier version of that walk matched `import` only, and an
/// `export 'package:flutter/material.dart';` planted in a reachable file left
/// the whole suite green. The walk is now negative-controlled by a fixture built
/// out of exactly the directive forms production code does not use, so it fails
/// the moment the pattern narrows again.
///
/// The generated `init()` is an **extension** emitted into the sibling
/// `injection.config.dart`, which is why this file and that file cannot be the
/// same one. That generated file is committed on purpose: it makes every
/// registration reviewable in a diff, instead of hiding them in a build cache.
@InjectableInit(preferRelativeImports: true, throwOnMissingDependencies: true)
Future<void> configureDependencies() async {
  // `init()` is generated, and in injectable 3.x it is synchronous until some
  // module registers an async dependency — at which point its signature becomes
  // `Future<GetIt>` and this call site must start awaiting.
  //
  // The result is deliberately not awaited. `await_only_futures` rejects
  // awaiting a `GetIt` today, and `unawaited_futures` will reject *dropping* a
  // `Future<GetIt>` the day that happens — so the transition is a compile error
  // a human has to resolve, never a silently discarded future.
  getIt.init();
}
