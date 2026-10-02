import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:flutter/material.dart';

/// Process entry point.
///
/// Three steps, in this order, and the order is the whole content of this file:
///
/// 1. `WidgetsFlutterBinding.ensureInitialized()` — binds the engine. First
///    because every later phase registers a dependency that talks to a platform
///    channel (`SharedPreferences`, from the Phase 5 settings repository), and a
///    channel with no binding under it throws. Doing it here means no later
///    phase has to remember to do it.
/// 2. `await configureDependencies()` — builds the object graph.
/// 3. `runApp` — first frame.
///
/// The `await` in step 2 is load-bearing and is NOT to be "cleaned up".
/// AGENT_CONTEXT §6, recorded decision 4: `configureDependencies()` is declared
/// `Future<void>` while the generated `getIt.init()` is still synchronous, so
/// `await_only_futures` would reject awaiting its result and `unawaited_futures`
/// is what rejects *dropping* this `Future<void>`. The day a module registers an
/// async dependency, `init()` becomes `Future<GetIt>` and this call site starts
/// awaiting something real — which is why the lint must be allowed to stay
/// strict rather than silenced with an `unawaited()` or an ignore comment.
///
/// This file is allowed to import `package:flutter/`: it calls `runApp`. The
/// Flutter-free rule applies to `lib/app/di/injection.dart` alone, and
/// `injection_test.dart` walks that file's whole transitive project-local
/// import graph to prove it. Keep Flutter out of `injection.dart` and this
/// arrangement survives.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const EvangelionApp());
}
