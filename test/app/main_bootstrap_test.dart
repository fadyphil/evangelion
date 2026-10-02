import 'dart:io';

import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// The source of `lib/main.dart`, read as text.
///
/// WHY TEXT AND NOT A CALL. `main()` cannot be invoked from a test: it calls
/// `runApp`, which needs a live view and a running frame pipeline, and a test
/// that tried would bind the harness to a second root widget rather than assert
/// anything about the bootstrap. So the two things a test *can* observe are
/// separated: `configureDependencies()` is called for real below, and the shape
/// of `main()` — which calls it, in what order, on what — is pinned by reading
/// the file.
///
/// WHAT THAT DOES AND DOES NOT PROVE, stated plainly:
///
/// * It proves the three bootstrap calls appear, in order, in the code.
/// * It does NOT prove `main()` executes them in that order, nor that it runs at
///   all. A future `main()` that delegates to a helper would fail this test
///   while remaining perfectly correct — so treat a failure here as "re-read
///   main.dart and decide", not as "the app is broken".
/// * The `await` is *not* really guarded by this test; it is guarded by the
///   `unawaited_futures` lint, which rejects dropping this `Future<void>`
///   (AGENT_CONTEXT §6, recorded decision 4). This assertion exists so the
///   intent is visible to a reader, and so removing the `await` fails loudly
///   here as well as at the analyzer.
String _mainSource() => File('lib/main.dart').readAsStringSync();

/// [_mainSource] with comments removed and runs of whitespace collapsed, so the
/// assertions below describe the *code* rather than the indentation `dart
/// format` chose or the prose around it.
///
/// THE COMMENT STRIP IS NOT OPTIONAL, and its absence was a real bug found by
/// negative control. `main.dart`'s doc comment enumerates the three bootstrap
/// steps in the correct order, so an earlier version of this helper — which
/// searched the raw file — matched the *documentation* while the code underneath
/// ran the steps backwards. Every ordering assertion passed, the application was
/// broken, and the suite was green. This is the Phase 0b lesson in a new place:
/// a test that reads prose will happily grade the prose.
///
/// KNOWN LIMITATION: this is a regular expression, not a parser, so a `//` or
/// `/*` inside a string literal would be stripped as if it were a comment.
/// `main.dart` has no string literals today. If that ever changes, replace this
/// with an actual parse rather than tuning the pattern — the failure mode of
/// getting it wrong is a test that passes for the wrong reason, which is the
/// thing this function exists to prevent.
String _mainCode() => _mainSource()
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
    .replaceAll(RegExp(r'//[^\n]*'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

void main() {
  setUp(() async {
    // `GetIt.instance` is a process-wide singleton; each test starts clean so a
    // registration from one cannot make the next pass for the wrong reason.
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('DI is configured before anything resolves', () {
    // The observable half of the bootstrap contract, and the part that actually
    // runs. It overlaps injection_test.dart on purpose but answers a different
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

    test('registrations resolve to real values once DI has run', () async {
      await configureDependencies();

      expect(identical(getIt<GetIt>(), getIt), isTrue);
      expect(getIt<String>(instanceName: 'apiBaseUrl'), AppConfig.apiBaseUrl);
    });
  });

  group('main() bootstraps in order', () {
    test('initialises the binding, awaits DI, then runs the app', () {
      final String source = _mainCode();

      expect(
        source,
        contains('WidgetsFlutterBinding.ensureInitialized()'),
        reason: 'runApp and the plugin channels need a bound engine first',
      );
      expect(
        source,
        matches(RegExp(r'await configureDependencies\(\)')),
        reason:
            'the await is AGENT_CONTEXT §6 decision 4 — it stays valid when '
            'getIt.init() becomes Future<GetIt>',
      );
      expect(
        source,
        matches(RegExp(r'runApp\(\s*const\s+EvangelionApp\(\s*\)\s*\)')),
        reason: 'the process must end up running this app, not a stock one',
      );
    });

    test('the three bootstrap steps happen in order', () {
      // Ordering asserted separately from presence above, because "all three
      // calls exist somewhere in the file" is exactly what a bootstrap written
      // backwards also satisfies. `main.dart`'s doc claims the order *is* the
      // file, so each adjacent pair is pinned rather than just the first and
      // last.
      final String source = _mainCode();
      final int binding = source.indexOf(
        'WidgetsFlutterBinding.ensureInitialized()',
      );
      final int configure = source.indexOf('await configureDependencies()');
      final int runAppCall = source.indexOf('runApp(');

      expect(binding, isNot(-1));
      expect(configure, isNot(-1));
      expect(runAppCall, isNot(-1));

      expect(
        binding,
        lessThan(configure),
        reason:
            'a plugin-backed dependency built during DI would reach a platform '
            'channel with no binding under it',
      );
      expect(
        configure,
        lessThan(runAppCall),
        reason: 'runApp before DI means the first frame renders an empty graph',
      );
    });
  });

  group('the flutter create counter is gone', () {
    test('no stock counter code survives in main.dart', () {
      // The counter was the last of the scaffold's own code. It is checked by
      // name rather than by "main.dart is short" so the residue is named in the
      // failure message instead of just being absent.
      //
      // Scanned through [_mainCode] like everything else here, for the same
      // reason: a prose mention is not code. A future phase documenting "this
      // replaced the `MyApp` counter" describes history honestly, and failing
      // that would only teach someone to delete the comment — or to weaken this
      // assertion, which is the worse outcome.
      const List<String> residue = <String>[
        'MyApp',
        'MyHomePage',
        '_MyHomePageState',
        '_counter',
        '_incrementCounter',
        'Colors.deepPurple',
        'Flutter Demo',
      ];

      for (final String name in residue) {
        expect(
          _mainCode(),
          isNot(contains(name)),
          reason: '$name is stock scaffold code and must not come back',
        );
      }
    });
  });
}
