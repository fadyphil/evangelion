import 'package:evangelion/app/app.dart';
import 'package:evangelion/app/bootstrap.dart';
import 'package:evangelion/app/di/injection.dart';
// Prefixed, because this file declares its own `main`. An unprefixed import
// would be shadowed by it, and `unused_import` is fatal under --fatal-infos.
import 'package:evangelion/main.dart' as entrypoint;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// The shape of a process entry point the engine awaits.
///
/// A named typedef because `isA<Future<void> Function()>()` does not parse —
/// `void` is not accepted as a nested type argument.
typedef _AwaitedEntryPoint = Future<void> Function();

/// Executes the bootstrap, so these assertions are about behaviour.
///
/// WHY NOT `main()`. `main()` calls `runApp`, which needs a live view and a
/// running frame pipeline. A test that invoked it would attach a second root
/// widget to a binding the harness already owns, and the outcome would tell us
/// nothing about the bootstrap. `bootstrapApp` is the same three steps with the
/// one untestable step injected, which is what makes them observable.
///
/// WHY THIS FILE DOES NOT READ `lib/main.dart` AS TEXT. It used to, and the
/// suite was green while the app launched to a blank frame: an empty `main()`
/// satisfied every assertion, and so did a `main()` carrying all three calls
/// inside a string literal. A text scan grades a file, not an execution, and a
/// doc comment that *enumerates* the steps in the right order reads exactly like
/// code that runs them in the right order. Each test below is instead a mutation
/// someone can perform and watch fail.
///
/// THE THREE MUTANTS THAT WERE ACTUALLY RUN against the old suite and this one,
/// so the claim above is checkable rather than rhetorical:
///
/// | mutant | old suite (146) | this file (5) |
/// |---|---|---|
/// | `main() async {}`, calls parked in a never-called fn | 146 pass | — |
/// | `main() { runApp(const MaterialApp()); }`, calls in a string | 146 pass | — |
/// | `run()` and `await configureDependencies()` swapped | 146 pass | 2 fail |
///
/// The first two rows are why `lib/app/bootstrap.dart` exists. The third is the
/// bug the text scan existed to catch and could not: swapping the last two lines
/// of `bootstrapApp` leaves `dart analyze` clean and fails the two ordering tests
/// below.
void main() {
  setUp(() async {
    // `GetIt.instance` is a process-wide singleton; each test starts clean so a
    // registration from one cannot make the next pass for the wrong reason.
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  // STEP 1 IS DELIBERATELY UNTESTED. `WidgetsFlutterBinding.ensureInitialized()`
  // cannot be observed from a test: `flutter_test` installs a binding before the
  // suite runs, so the call is a no-op and there is nothing left to assert. An
  // "the binding exists" assertion would be unfalsifiable — and this file exists
  // because an unfalsifiable assertion about the bootstrap was believed for two
  // phases. It is guarded by the framework: a platform-channel call made before
  // a binding exists throws at runtime in the real app. Steps 2 and 3 are
  // below, and both are executable.
  group('the bootstrap steps run in order', () {
    test('run() is NOT called when DI throws — the order is executable', () async {
      // The mutation to try: swap the last two lines of `bootstrapApp` so
      // `run(const EvangelionApp())` precedes `await configureDependencies()`.
      // That is the bug a source scan existed to catch and could not. Here the
      // graph is already built (and so already registered `GetIt`), so the
      // second `configureDependencies()` throws — and the only question is
      // whether the app was already handed a first frame when it did.
      //
      // `injection.config.dart` registers `GetIt` unconditionally rather than
      // behind an `isRegistered` guard, so get_it rejects the duplicate with an
      // `ArgumentError`. Same throw `injection_test.dart` pins for a double
      // `configureDependencies()`; asserted concretely so this cannot pass on an
      // unrelated failure.
      await configureDependencies();

      bool ran = false;
      await expectLater(
        bootstrapApp(
          run: (Widget _) {
            ran = true;
          },
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        ran,
        isFalse,
        reason: 'runApp before DI means the first frame renders an empty graph',
      );
    });

    test('run() sees a built object graph, not an empty locator', () async {
      // The other half of the same ordering claim, and the half that does not
      // need an exception to observe: the locator's state is sampled *at the
      // moment `run` is called*. Under the mutation above this records `false`
      // and fails, rather than passing a `run()` that happened to be called.
      final List<bool> graphWasBuiltWhenRun = <bool>[];

      await bootstrapApp(
        run: (Widget _) {
          graphWasBuiltWhenRun.add(getIt.isRegistered<GetIt>());
        },
      );

      expect(
        graphWasBuiltWhenRun,
        hasLength(1),
        reason: 'run() is called exactly once',
      );
      expect(
        graphWasBuiltWhenRun.single,
        isTrue,
        reason:
            'configureDependencies() must complete before runApp, or the first '
            'frame renders with nothing registered',
      );
    });

    test('run() receives the app root, not a stock MaterialApp', () async {
      // What pins "the process ends up running *this* app" — and, since
      // `EvangelionApp` is a distinct type, it also pins the absence of the
      // scaffold's own `MyApp`. The previous source scan listed `MyApp` as a
      // forbidden substring; a typed assertion is the same guard that a
      // substring cannot accidentally satisfy by being quoted in a comment.
      Widget? root;

      await bootstrapApp(
        run: (Widget app) {
          root = app;
        },
      );

      expect(root, isA<EvangelionApp>());
    });
  });

  group('DI is configured before anything resolves', () {
    // The observable half of the bootstrap contract, and the part that actually
    // runs. It overlaps `injection_test.dart` on purpose but answers a different
    // question: that file asks "is the graph correct once built", this asks
    // "is there an ordering at all" — nothing is registered before
    // `configureDependencies()` runs, so a screen built too early fails loudly
    // instead of quietly finding nothing.
    test(
      'the locator is empty until configureDependencies() completes',
      () async {
        expect(
          getIt.isRegistered<GetIt>(),
          isFalse,
          reason: 'a fresh process has no registrations',
        );

        await configureDependencies();

        expect(getIt.isRegistered<GetIt>(), isTrue);
      },
    );
  });

  group('the process entry point', () {
    test('returns a Future the engine awaits, not void', () {
      // WHAT THIS PINS, precisely: `lib/main.dart` compiles, and its `main` is
      // `Future<void> Function()` rather than `void Function()`.
      //
      // WHAT IT DOES NOT PIN: that `main` *calls* `bootstrapApp`. `main`'s body
      // cannot be executed from a test for the reason this whole file is shaped
      // around — it hands the frame to `runApp`. What is pinned instead is the
      // part that is observable: the entry point returns a Future the engine
      // awaits, so a DI failure during bootstrap fails the launch instead of
      // becoming an unhandled async error behind a blank first frame.
      expect(entrypoint.main, isA<_AwaitedEntryPoint>());
    });
  });
}
