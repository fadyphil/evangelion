import 'dart:io';

import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../support/project_import_graph.dart';

// The graph walk itself moved to `test/support/project_import_graph.dart` during
// the Phase 1 review. It used to be defined here, which was fine until a second
// suite needed it: `barrel_test.dart` has to walk the design-system barrel for
// the same reason this file walks the composition root, and a second copy of a
// hand-rolled import-graph walker is a second thing to keep in step — the exact
// failure mode AGENT_CONTEXT §7 documents. Every symbol this file used to own
// (`reachableProjectFiles`, `importUrisOf`, `fileNamesOf`, `flutterPrefix`)
// still exists; the private directive pattern is now `directivePattern` and is
// deliberately public, because the *reason* it stops at the closing quote rather
// than the semicolon is a finding that belongs next to the pattern, not buried in
// whichever suite happens to run first.

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

/// A `gh.<lifetime><` registration read out of `injection.config.dart`.
///
/// [type] is the registered type with any `_iNNN.` prefix stripped, and [member]
/// is the module getter the generated closure calls — both are needed, because a
/// type alone is not an identity: `@lazySingleton String get apiBaseUrl` and
/// `@lazySingleton String get phase5Header` are the same (lifetime, type) pair, so
/// a staleness check keyed on the pair alone cannot tell a regenerated config from
/// a stale one.
final class ConfiguredRegistration {
  const ConfiguredRegistration({
    required this.lifetime,
    required this.type,
    required this.member,
  });

  /// `lazySingleton`, `factory`, `singleton` — the get_it registration kind.
  final String lifetime;

  /// The registered type, e.g. `GetIt` or `String`.
  final String type;

  /// The `@module` member the generated provider body reads.
  final String member;

  /// Read off the stack frames when two of these disagree, so a failure says which
  /// side is missing which entry rather than printing two unordered sets.
  @override
  String toString() => '$lifetime<$type> $member';

  @override
  bool operator ==(Object other) =>
      other is ConfiguredRegistration &&
      other.lifetime == lifetime &&
      other.type == type &&
      other.member == member;

  @override
  int get hashCode => Object.hash(lifetime, type, member);
}

/// Every `gh.<lifetime><…>` registration in `injection.config.dart`.
///
/// WHY A PARSER, and why the shape of the generated code is load-bearing here.
///
/// `injection.config.dart` is generated and committed, so it can go stale: add a
/// provider to a `@module` and forget to re-run `build_runner`, and the file every
/// reviewer reads to learn what the graph contains keeps describing the graph as it
/// was. Measured before this test existed: adding
/// `@lazySingleton @Named('phase5Header') String get phase5Header` to
/// `core_module.dart` without regenerating left all 35 DI tests green, and the
/// config's diff showed nothing — because there was no diff, in the file nobody
/// looks at because nothing failed.
///
/// The generated shape this reads is injectable's:
///
/// ```dart
/// gh.lazySingleton<GetIt>(() => coreModule.serviceLocator);
/// gh.lazySingleton<String>(() => coreModule.apiBaseUrl, instanceName: …);
/// ```
///
/// so the body is matched whole (a registration can wrap across lines) and the
/// member comes from the `() => <moduleVar>.<member>` inside it. A change to
/// injectable's codegen stops this parser matching, and the anti-vacuity
/// assertions below turn that into a failure rather than into a silently empty
/// result — which is the failure mode a parser-based gate has by default, and the
/// one `verify_purity.sh` documents in AGENT_CONTEXT §7.
List<ConfiguredRegistration> configuredRegistrations(String source) {
  final List<ConfiguredRegistration> found = <ConfiguredRegistration>[];

  for (final String statement in source.split(';')) {
    final RegExpMatch? call = RegExp(r'gh\.(\w+)<([^>]+)>\(')
        .firstMatch(statement);
    if (call == null) {
      continue;
    }
    // `()` then the arrow — NOT `(()`. The generated body reads `() => coreModule.x`
    // when the registration fits on one line and `(\n  () => coreModule.x,` when
    // it does not, so the two opening brackets are adjacent only in the first
    // form. The first version of this pattern assumed they always were, and read
    // exactly one of the two registrations the config has — silently, because a
    // parser that matches less looks exactly like a parser that found less.
    final RegExpMatch? body = RegExp(r'\(\)\s*=>\s*\w+\.(\w+)')
        .firstMatch(statement);
    if (body == null) {
      continue;
    }
    found.add(
      ConfiguredRegistration(
        lifetime: call.group(1)!,
        // `_i174.GetIt` is how the generated file spells a type it imported under
        // an alias; the alias is noise, the identity is the bare type name.
        type: call.group(2)!.split('.').last,
        member: body.group(1)!,
      ),
    );
  }

  return found;
}

/// Every lifetime-annotated provider declared by a `@module` under [moduleDir].
///
/// The counterpart to [configuredRegistrations], and it exists because the
/// staleness direction that matters is *this one*: a provider with no registration
/// is the stale config. Checking only the other direction — every `gh.` line has a
/// provider — would pass on exactly the mutation this test is for, since the stale
/// config's existing entries all still have providers.
List<ConfiguredRegistration> declaredProviders(String moduleDir) {
  final List<ConfiguredRegistration> found = <ConfiguredRegistration>[];
  final RegExp lifetime = RegExp(r'@(lazySingleton|factory|singleton)');
  final RegExp declaration = RegExp(
    r'^\s*(?:@\w+\s+)*([A-Z][\w<>?, ]*?)\s+(?:get\s+)?(\w+)\s*(?:\(|=>|;|=)',
  );

  for (final File module
      in Directory(moduleDir)
          .listSync()
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final List<String> lines = module.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      // Comments first. `core_module.dart` discusses `@factory` and
      // `@lazySingleton` in its own doc comment — `What the *lifetime* does not
      // buy, and what no test in the suite can check` — and a parser that reads
      // annotations out of prose invents a `factory` registration that does not
      // exist. The same class of defect as Gate 1's "anchored to a directive
      // keyword, never a bare substring", and the reason that is a rule.
      if (lines[i].trimLeft().startsWith('//')) {
        continue;
      }
      final RegExpMatch? annotation = lifetime.firstMatch(lines[i]);
      if (annotation == null) {
        continue;
      }
      // The declaration is the next non-annotation, non-comment line: injectable
      // puts the annotations on their own lines above the member.
      for (final String line in lines.skip(i + 1)) {
        final String trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('//') ||
            trimmed.startsWith('@')) {
          continue;
        }
        final RegExpMatch? match = declaration.firstMatch(line);
        if (match != null) {
          found.add(
            ConfiguredRegistration(
              lifetime: annotation.group(1)!,
              type: match.group(1)!.trim(),
              member: match.group(2)!,
            ),
          );
        }
        break;
      }
    }
  }

  return found;
}

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
      // `setUp` already configured the graph. get_it rejects a duplicate type
      // with an `ArgumentError` naming the type, which is the behaviour wanted
      // here: `main` must call this exactly once, and a double call is a bug
      // rather than a silent no-op.
      //
      // Asserted concretely rather than as `throwsA(anything)`, which matches
      // every throwable in existence — including the `StateError` a *missing*
      // registration raises and the `TypeError` a mistyped one raises. It would
      // have passed just as happily if `configureDependencies` were broken in a
      // completely unrelated way, which makes it a very poor way to say "a
      // double call is rejected here and nowhere else".
      //
      // **The type named is not pinned.** The first version of this asserted
      // `contains('GetIt is already registered')`, because `CoreModule`'s
      // `serviceLocator` happened to be the first registration. Phase 5 added
      // `AuthModule`'s five providers and the first name became
      // `AuthLocalDataSource` — so the assertion was really pinning *registration
      // order*, which is generated output rather than a contract. What is
      // contractual is that the rejection names **some** already-registered type,
      // and that it is an `ArgumentError` rather than a silent no-op.
      await expectLater(
        configureDependencies(),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message.toString(),
            'message',
            allOf(contains('is already registered'), contains('inside GetIt')),
          ),
        ),
      );
    });
  });

  group('the service locator itself', () {
    test('resolves to the same instance the app uses', () {
      // WHAT THIS PINS: the registered *value* is `getIt` itself, so a use case
      // declaring `GetIt` as a dependency gets the app's locator.
      //
      // WHAT IT DOES NOT PIN: the `@lazySingleton` lifetime on
      // `ServiceLocatorModule.serviceLocator`. The provider returns
      // `GetIt.instance`, which is already a process-wide singleton, so
      // rewriting the generated registration to `gh.factory` hands back the
      // identical object and this assertion holds either way. The
      // "what this suite cannot see" group below is the negative control for
      // exactly that claim.
      // `same(...)` rather than `identical(a, b)`: a failed `expect` on a bare
      // `isTrue` prints "Expected: true / Actual: false" and names neither
      // operand, which is the least diagnostic form this suite has. `same` prints
      // both sides, so a failure says *which* two objects disagreed.
      expect(getIt<GetIt>(), same(getIt));
    });

    test('two lookups are the identical instance', () {
      expect(getIt<GetIt>(), same(getIt<GetIt>()));
    });

    test('nothing is registered for an unregistered type', () {
      expect(getIt.get<_NeverRegistered>, throwsA(isA<StateError>()));
    });
  });

  group('what this suite cannot see: the registration lifetime', () {
    // The identity assertions in this file read like they pin the
    // `@lazySingleton` annotations in `modules/core_module.dart`. They do
    // not, and the reason deserves a test rather than a comment nobody re-reads.
    // Rewriting the generated `gh.lazySingleton<GetIt>(…)` to `gh.factory<GetIt>(…)`
    // leaves the whole suite green, because the provider returns
    // `GetIt.instance`; doing the same to the `apiBaseUrl` registration also
    // leaves it green, because `AppConfig.apiBaseUrl` is a compile-time constant.
    // Both values are the identical object under either lifetime.
    //
    // get_it 9.x exposes no lifetime introspection — `isRegistered` answers
    // presence, not kind — so there is no graph-side assertion to add. What
    // these two tests establish is the other half of the claim: that the
    // limitation is in the *values*, not in identity. Without them the identity
    // assertions above read as a lifetime gate; with them they read as what they
    // are, a value-identity check.
    //
    // They keep `identical(...)` rather than the `same(...)` used elsewhere in
    // this file: `isNot(...)` has no `same` counterpart, and the point of the
    // pair is to demonstrate the difference between the two registration kinds
    // using the function the rest of the suite is measured against.
    test(
      'a factory registration IS distinguishable, so identical() has teeth',
      () {
        int calls = 0;
        getIt.registerFactory<int>(() => ++calls);

        expect(getIt<int>(), isNot(getIt<int>()));
        expect(
          getIt<int>(),
          3,
          reason: 'a factory builds a new value per lookup',
        );
      },
    );

    test('a singleton registration yields one instance for every lookup', () {
      int calls = 0;
      getIt.registerLazySingleton<int>(() => ++calls);

      expect(identical(getIt<int>(), getIt<int>()), isTrue);
      expect(getIt<int>(), 1, reason: 'the factory func runs exactly once');
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
      // Same caveat as the `GetIt` lookup above, for the same reason:
      // `AppConfig.apiBaseUrl` is a `static const`, so the provider returns the
      // same canonicalised String under `@lazySingleton` or `@factory`. This
      // pins the value, not the lifetime.
      expect(
        getIt<String>(instanceName: 'apiBaseUrl'),
        same(getIt<String>(instanceName: 'apiBaseUrl')),
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
        getIt<NoParamsUseCase<String>>(),
        same(getIt<NoParamsUseCase<String>>()),
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
          'lib/app/di/modules/core_module.dart',
          'lib/core/common/app_config.dart',
        ]),
        reason:
            'the walk must actually reach the generated config, '
            'otherwise this test is vacuous',
      );

      for (final String path in reachable) {
        expect(
          importUrisOf(path)
              .where((String uri) => uri.startsWith(flutterPrefix)),
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
              .where((String uri) => uri.startsWith(flutterPrefix)),
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
      final Directory fixture = writeDirectiveFixture();
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
        contains('${flutterPrefix}material.dart'),
      );
    });
  });

  group('the generated config is not stale', () {
    // Phase 4's deliverable was seven `@module` files and one generated
    // `injection.config.dart`, and nothing checked the relationship between them.
    // `injection_test.dart` proved the *generated* graph works; it could not notice
    // that the graph had moved on and the file had not.
    //
    // BOTH DIRECTIONS, because either alone is defeatable. "Every `gh.` line has a
    // provider" passes on the stale config — its entries all still have providers.
    // "Every provider has a `gh.` line" is the direction that catches it. Asserting
    // both also keeps the first one honest as an anti-typo check rather than
    // pretending to be a staleness detector.
    const String configPath = 'lib/app/di/injection.config.dart';
    const String moduleDir = 'lib/app/di/modules';

    test('every registration in the config has an annotated provider', () {
      final List<ConfiguredRegistration> configured = configuredRegistrations(
        File(configPath).readAsStringSync(),
      );
      final List<ConfiguredRegistration> declared = declaredProviders(
        moduleDir,
      );

      // Anti-vacuity, before either side is compared. A parser that stopped
      // matching would return two empty lists and `expect(configured,
      // containedIn(declared))` would pass on an empty comparison — the shape of
      // bug `verify_purity.sh` documents and the reason every scan there asserts
      // it can see something first.
      expect(
        configured,
        isNotEmpty,
        reason:
            'the config was read and its registrations parsed; if this fails, '
            'injectable\'s output shape changed and every comparison below is '
            'comparing nothing',
      );
      expect(declared, isNotEmpty);

      expect(
        configured,
        everyElement(isIn(declared)),
        reason:
            'the config registers nothing the `@module` files do not declare — a '
            'hand-edited or half-regenerated config would name a provider that no '
            'longer exists',
      );
    });

    test('every annotated provider appears in the config, so the config is not '
        'stale', () {
      final List<ConfiguredRegistration> configured = configuredRegistrations(
        File(configPath).readAsStringSync(),
      );
      final List<ConfiguredRegistration> declared = declaredProviders(
        moduleDir,
      );

      expect(
        configured,
        isNotEmpty,
        reason: 'same anti-vacuity guard as the previous test',
      );
      expect(
        declared,
        everyElement(isIn(configured)),
        reason:
            'a provider added to a `@module` without re-running `build_runner` is '
            'the staleness this exists for: the runtime graph would not have it, '
            'and the committed config — the file a reviewer reads to learn what the '
            'graph contains — would still say it does not',
      );
    });

    test('the nine current registrations are the ones the config actually names', () {
      // Spelled out rather than counted, for the reason
      // `app_routes_test.dart` gives: a parser that quietly returned entries of
      // the wrong shape would sail through a length check.
      //
      // The full inventory, so a reader learns what the graph contains from a
      // failing diff rather than by opening the generated file. Phase 5 added
      // five `AuthModule` providers (`authLocalDataSource`, `authRepository`,
      // `signIn`, `getCurrentSession`, `signOut`) and two `CoreModule` ones
      // (`apiClient`, `apiErrorMapper`) to the two that were there.
      expect(
        configuredRegistrations(File(configPath).readAsStringSync())
            .map((ConfiguredRegistration r) => r.toString()),
        <String>[
          'lazySingleton<AuthLocalDataSource> authLocalDataSource',
          'lazySingleton<AuthRepository> authRepository',
          'lazySingleton<SignIn> signIn',
          'lazySingleton<GetCurrentSession> getCurrentSession',
          'lazySingleton<SignOut> signOut',
          'lazySingleton<GetIt> serviceLocator',
          'lazySingleton<Dio> apiClient',
          'lazySingleton<ApiErrorMapper> apiErrorMapper',
          'lazySingleton<String> apiBaseUrl',
        ],
      );
    });

    test('and the auth providers are registered against the PORT, not the fake', () {
      // `auth_module.dart` returns `AuthRepository` rather than
      // `FakeAuthRepository` so a real adapter is a change to one provider body
      // and nothing else. The generated config is where that decision becomes
      // observable: `gh.lazySingleton<AuthRepository>` is the assertion, and a
      // future edit that widens it to the concrete type turns this red rather
      // than making every use case part of the swap.
      expect(
        configuredRegistrations(File(configPath).readAsStringSync()),
        contains(
          const ConfiguredRegistration(
            lifetime: 'lazySingleton',
            type: 'AuthRepository',
            member: 'authRepository',
          ),
        ),
      );
      expect(
        File(configPath).readAsStringSync(),
        isNot(contains('FakeAuthRepository')),
      );
    });

    test('and the config names none of the hand-registered navigation types', () {
      // The collision gap, closed by name. `configureNavigation()` registers
      // `AuthStatus`, `ReevaluateListenable` and `AppRouter` at run time, and
      // `navigation_injection_test.dart` proves that doing it twice fails loudly
      // with an `ArgumentError` — but only for the *hand-written* half. If any of
      // those three ever also appeared in the generated graph, the collision would
      // be between two registrations that neither test can see: get_it's
      // duplicate-type check fires on the second registration whichever it came
      // from, so the failure would surface in whichever composition step ran
      // second, not in the file that caused it.
      final String config = File(configPath).readAsStringSync();

      for (final String type in <String>[
        'AppRouter',
        'AuthStatus',
        'ReevaluateListenable',
        // Phase 5's fourth. `AuthBloc` is a bloc, and the only import that reaches
        // it — `package:flutter_bloc/flutter_bloc.dart` — re-exports Flutter's
        // widget layer; `package:bloc/bloc.dart` is unavailable because `bloc` is
        // a transitive dependency AGENT_CONTEXT §8.4 will not let this project
        // promote. So there is no spelling of "generate this registration" that
        // keeps `injection.dart`'s graph Flutter-free, which is exactly why it is
        // hand-registered alongside the router. See `navigation_injection.dart`.
        'AuthBloc',
      ]) {
        expect(
          config,
          isNot(contains(type)),
          reason:
              '$type is registered by hand in `navigation_injection.dart` and '
              'must not also be generated — see that file for why it cannot be',
        );
      }
    });
  });
}
