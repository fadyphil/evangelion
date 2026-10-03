import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/di/navigation_injection.dart';
import 'package:flutter/widgets.dart';

/// The process bootstrap, with its one untestable step injected.
///
/// Four steps, in this order, and the order is the whole content of this
/// function:
///
/// 1. `WidgetsFlutterBinding.ensureInitialized()` — binds the engine. First
///    because later phases register dependencies that talk to a platform channel
///    (`SharedPreferences`, from the Phase 5 settings repository), and a channel
///    with no binding under it throws.
/// 2. `await configureDependencies()` — builds the pure-Dart object graph.
/// 3. `configureNavigation()` — registers the auth seam and the router. Second
///    because `AppRouter`'s provider reads `AuthStatus` out of the locator as it
///    constructs, and the whole graph has to be in place before anything
///    resolves it; `bootstrapApp`'s ordering test is what keeps that true.
/// 4. `run(const EvangelionApp())` — first frame.
///
/// WHY `run` IS A PARAMETER. `runApp` needs a live view and a running frame
/// pipeline, so a test cannot call it: calling it inside `flutter_test` would
/// attach a second root widget to a binding the test harness already owns and
/// assert nothing about the bootstrap. Passing the function in instead turns
/// steps 2–4 into ordinary, executable code — a test can observe that `run` was
/// called, what it received, and — by making DI throw — that it was *not* called
/// before DI succeeded.
///
/// The previous arrangement was the opposite: the ordering lived in `main()` and
/// a test read `lib/main.dart` as text. That graded a file, not an execution, and
/// a `main()` whose body was empty — an app that launches to a blank frame —
/// left the whole suite green. It was also defeated by moving the three calls
/// inside a string literal. See `main_bootstrap_test.dart`, which now asserts
/// these three lines *execute* in this order, and documents the one-line swap
/// that proves the assertions have teeth.
///
/// WHAT IS *NOT* OBSERVABLE HERE, stated plainly: step 1. `ensureInitialized()`
/// is a no-op inside `flutter_test`, which has already installed a binding, so
/// no assertion in this suite can observe it running. It is guarded by the
/// framework rather than by a test — a platform-channel call made before a
/// binding exists throws at runtime in the real app, which is the failure this
/// step prevents.
///
/// The `await` in step 2 is load-bearing and is NOT to be "cleaned up".
/// AGENT_CONTEXT §6, recorded decision 4: `configureDependencies()` is declared
/// `Future<void>` while the generated `getIt.init()` is still synchronous, so
/// `await_only_futures` would reject awaiting its result and `unawaited_futures`
/// is what rejects *dropping* this `Future<void>`. The day a module registers an
/// async dependency, `init()` becomes `Future<GetIt>` and this call site starts
/// awaiting something real — which is why the lint must be allowed to stay strict
/// rather than silenced with an `unawaited()` or an ignore comment.
///
/// This file is allowed to import `package:flutter/`: it calls `run`, and it
/// calls `configureNavigation`, which registers the router. The Flutter-free rule
/// applies to `lib/app/di/injection.dart` alone, and `injection_test.dart` walks
/// that file's whole transitive project-local import graph to prove it. The two
/// halves of the graph are separate steps because of exactly that rule — see
/// `navigation_injection.dart`.
///
/// Step 3 is synchronous and deliberately not awaited. Nothing in
/// `configureNavigation` is async, and `unawaited_futures` exists to make the day
/// something *does* become async a compile error rather than a dropped future —
/// the same reasoning `injection.dart` records for `getIt.init()`.
Future<void> bootstrapApp({required void Function(Widget) run}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  configureNavigation();
  run(const EvangelionApp());
}
