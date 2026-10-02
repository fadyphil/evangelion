import 'dart:io';

import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Matches an `import`, `export`, or `part` directive and captures its URI.
///
/// All three directives, not just `import`. `export` re-exposes another
/// library's whole surface to whoever imports this one, and `part` pulls a file
/// into this library's namespace, so either one makes `package:flutter/` just
/// as reachable from the composition root as a direct import does — and neither
/// trips a lint. A walk that only understands `import` reports "Flutter-free"
/// over a graph that is not.
///
/// Both quote styles, deliberately. Single quotes are the house style and
/// `prefer_single_quotes` is fatal under `--fatal-infos`, so a double-quoted
/// directive cannot reach main today — but this test must not depend on an
/// unrelated lint to stay honest, and it is the *only* check on this property.
final RegExp _directivePattern = RegExp(
  r"""^\s*(?:import|export|part)\s+(['"])([^'"]+)\1""",
  multiLine: true,
);

const String _packagePrefix = 'package:evangelion/';

const String _flutterPrefix = 'package:flutter/';

/// Package root, always with a trailing separator.
final String _rootPath = Directory.current.uri.path;

/// Walks the project-local import graph from [entry] and returns every file it
/// can reach, as a package-relative path. [entry] itself is included.
///
/// `import`, `export`, and `part` directives are all followed — see
/// [_directivePattern] — in both `package:evangelion/…` and relative forms,
/// because `@InjectableInit(preferRelativeImports: true)` makes the generated
/// config import its sibling relatively. `dart:` and external packages are not
/// followed: `get_it` and `injectable` are pure Dart and declare no Flutter
/// dependency, so the project-local closure is the whole of what this needs to
/// police.
Set<String> reachableProjectFiles(String entry) {
  final Set<String> seen = <String>{};
  final List<Uri> pending = <Uri>[Directory.current.uri.resolve(entry)];

  while (pending.isNotEmpty) {
    final Uri fileUri = pending.removeLast();
    if (!seen.add(_relativise(fileUri))) {
      continue;
    }

    final String source = File.fromUri(fileUri).readAsStringSync();
    for (final RegExpMatch match in _directivePattern.allMatches(source)) {
      // Group 2 matched a URI between matched quotes, so it cannot be null.
      final String target = match.group(2)!;

      if (target.startsWith(_packagePrefix)) {
        pending.add(
          Directory.current.uri.resolve(
            'lib/${target.substring(_packagePrefix.length)}',
          ),
        );
      } else if (!target.contains(':')) {
        // A relative import: no scheme, so it resolves against the importing
        // file. Anything with a scheme (`dart:`, `package:`) is external.
        pending.add(fileUri.resolve(target));
      }
    }
  }

  return seen;
}

/// Strips the package-root prefix so results compare as plain relative paths.
String _relativise(Uri fileUri) {
  final String path = fileUri.toFilePath();
  return path.startsWith(_rootPath) ? path.substring(_rootPath.length) : path;
}

/// The URIs named by [path]'s `import`, `export`, and `part` directives.
///
/// Directive-only on purpose. A substring scan for `package:flutter/` also
/// matches the phrase inside a doc comment that *explains* why a file is
/// Flutter-free, which is a false positive that would force the documentation
/// to be watered down to keep the gate green.
Set<String> importUrisOf(String path) => _directivePattern
    .allMatches(File(path).readAsStringSync())
    .map((RegExpMatch match) => match.group(2)!)
    .toSet();

/// Writes a throwaway import graph whose every directive is deliberately
/// non-default — a double-quoted `export`, a `part`, then a plain relative
/// `import` — and returns the directory holding it.
///
/// Built at run time rather than committed. A committed fixture would need an
/// `// ignore: prefer_single_quotes` header to survive `dart analyze`, and a
/// fixture the analyzer tolerates no longer proves the walk sees double quotes.
Directory _writeDirectiveFixture() {
  final Directory dir = Directory.systemTemp.createTempSync(
    'evangelion_import_graph',
  );
  File(
    '${dir.path}/deepest.dart',
  ).writeAsStringSync('export "package:flutter/material.dart" show Color;\n');
  File('${dir.path}/middle.dart').writeAsStringSync("part 'deepest.dart';\n");
  File('${dir.path}/entry.dart').writeAsStringSync("import 'middle.dart';\n");
  return dir;
}

/// The file names in [paths], so an assertion about *which* files were reached
/// does not depend on the temp directory's separator or location.
Set<String> fileNamesOf(Iterable<String> paths) =>
    paths.map((String path) => path.split(Platform.pathSeparator).last).toSet();

/// A `UseCase`-shaped use case, registered from `test/` rather than from `lib/`.
/// The concrete use cases arrive with the features that own them; what this
/// proves is that the `UseCase` seam composes with the locator.
final class ProbeNoParamsUseCase implements NoParamsUseCase<String> {
  const ProbeNoParamsUseCase();

  @override
  Future<Result<String>> call() async => const Result<String>.success('wired');
}

/// A type nothing registers, used to assert get_it's failure mode.
final class _NeverRegistered {}

void main() {
  setUp(() async {
    // `GetIt.instance` is a process-wide singleton, so each test starts from a
    // clean slate instead of inheriting the previous registration set.
    await getIt.reset();
    await configureDependencies();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('configureDependencies', () {
    test('leaves the locator usable', () {
      expect(getIt.isRegistered<GetIt>(), isTrue);
    });

    test(
      'is repeatable after a reset, so tests can rebuild the graph',
      () async {
        await getIt.reset();

        await expectLater(configureDependencies(), completes);
        expect(getIt.isRegistered<GetIt>(), isTrue);
      },
    );

    test('registering twice without a reset fails loudly', () async {
      // `setUp` already configured the graph. get_it rejects a duplicate type,
      // which is the behaviour wanted here: `main` must call this exactly once,
      // and a double call is a bug rather than a silent no-op.
      await expectLater(configureDependencies(), throwsA(anything));
    });
  });

  group('the service locator itself', () {
    test('resolves to the same instance the app uses', () {
      expect(identical(getIt<GetIt>(), getIt), isTrue);
    });

    test('two lookups are the identical instance', () {
      expect(identical(getIt<GetIt>(), getIt<GetIt>()), isTrue);
    });

    test('nothing is registered for an unregistered type', () {
      expect(getIt.get<_NeverRegistered>, throwsA(isA<StateError>()));
    });
  });

  group('AppConfig is provided at the composition root, never injected', () {
    test('the base URL resolves, and it is AppConfig.apiBaseUrl', () {
      // `AppConfig` is `abstract final` with statics, so there is no instance to
      // register. The composition root hands out its *values* instead, and the
      // transport takes them as constructor parameters (AGENT_CONTEXT §6,
      // recorded decision 1) so a malformed `--dart-define` stays unit-testable.
      expect(getIt<String>(instanceName: 'apiBaseUrl'), AppConfig.apiBaseUrl);
    });

    test('two lookups are the identical instance', () {
      expect(
        identical(
          getIt<String>(instanceName: 'apiBaseUrl'),
          getIt<String>(instanceName: 'apiBaseUrl'),
        ),
        isTrue,
      );
    });

    test('it is tagged, so an unnamed String cannot collide with it', () {
      expect(
        getIt.get<String>,
        throwsA(isA<StateError>()),
        reason: 'an unnamed String must not resolve to the base URL',
      );
    });
  });

  group('a UseCase-shaped use case resolves through the same locator', () {
    setUp(() {
      getIt.registerLazySingleton<NoParamsUseCase<String>>(
        ProbeNoParamsUseCase.new,
      );
    });

    test('two lookups are the identical instance', () {
      expect(
        identical(
          getIt<NoParamsUseCase<String>>(),
          getIt<NoParamsUseCase<String>>(),
        ),
        isTrue,
      );
    });

    test(
      'resolving through the seam yields a Result, not a bare value',
      () async {
        final NoParamsUseCase<String> usecase =
            getIt<NoParamsUseCase<String>>();

        expect(await usecase(), const Result<String>.success('wired'));
      },
    );
  });

  group('the composition root is Flutter-free', () {
    test('no file it transitively imports pulls in package:flutter', () {
      // The claim "configureDependencies() does not need a binding" is only
      // worth something if it is enforced. This walks the whole project-local
      // import graph from the entry point, so a later phase cannot quietly add
      // a Flutter import underneath it and silently break every plain-Dart
      // composition test.
      final Set<String> reachable = reachableProjectFiles(
        'lib/app/di/injection.dart',
      );

      // Asserted before anything about the contents, so the loop below cannot
      // pass by walking nothing.
      expect(reachable, isNotEmpty);

      // WHAT THIS DOES AND DOES NOT PROVE. It proves the walk followed edges:
      // a walker that matched no directive at all would return the entry point
      // alone and fail here. It does NOT prove these particular imports are
      // *optional* — none of them are. `injection.dart` calls `getIt.init()`,
      // whose signature lives in the generated config, so deleting that import
      // is a compile error and this list can never catch it. A guard that
      // cannot fail is worse than no guard, because it reads as verified
      // defence; the next test is the reachable half of this property.
      expect(
        reachable,
        containsAll(<String>[
          'lib/app/di/injection.dart',
          'lib/app/di/injection.config.dart',
          'lib/app/di/service_locator_module.dart',
          'lib/core/common/app_config.dart',
        ]),
        reason:
            'the walk must actually reach the generated config, '
            'otherwise this test is vacuous',
      );

      for (final String path in reachable) {
        expect(
          importUrisOf(path)
              .where((String uri) => uri.startsWith(_flutterPrefix)),
          isEmpty,
          reason: '$path must stay Flutter-free',
        );
      }
    });

    test('and the shared kernel it resolves against is Flutter-free too', () {
      final Set<String> reachable = reachableProjectFiles(
        'lib/core/domain/usecase/usecase.dart',
      );

      expect(reachable, isNotEmpty);
      for (final String path in reachable) {
        expect(
          importUrisOf(path)
              .where((String uri) => uri.startsWith(_flutterPrefix)),
          isEmpty,
          reason: '$path must stay Flutter-free',
        );
      }
    });

    test('the walk follows export, part and double-quoted directives', () {
      // The reachable anti-vacuity half. The production graph above uses only
      // single-quoted `import`s, so it cannot prove the walker sees the other
      // forms — and a walker that does not see them is exactly how an
      // `export 'package:flutter/material.dart';` slipped through this suite
      // while every test stayed green. This fixture is built out of nothing but
      // the forms production code does not use, so it fails the moment the
      // directive pattern narrows again.
      final Directory fixture = _writeDirectiveFixture();
      addTearDown(() => fixture.deleteSync(recursive: true));

      final Set<String> reachable = reachableProjectFiles(
        '${fixture.uri.path}/entry.dart',
      );

      expect(
        fileNamesOf(reachable),
        containsAll(<String>['entry.dart', 'middle.dart', 'deepest.dart']),
        reason:
            'every directive form must be followed, not just single-quoted '
            'imports',
      );

      // And the assertion the purity test is built on must see the Flutter
      // import that arrived through them.
      expect(
        importUrisOf('${fixture.uri.path}/deepest.dart'),
        contains('${_flutterPrefix}material.dart'),
      );
    });
  });
}
