import 'dart:io';

import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

// Not a `package:` import: `tool/` is not a library, it is the gate body that
// `verify_purity.sh` runs. Sharing it is the point — the extraction lives in one
// place, so the gate and this suite cannot disagree about what is declared.
import '../../../tool/route_check.dart';

void main() {
  /// The complete inventory of route paths `AppRoutes` declares, read from the
  /// declaration site rather than listed by hand here.
  ///
  /// WHY A PARSER. This used to be a `Map<String, String>` written in this file
  /// naming the seven constants it knew about. Dart has no reflection, so
  /// nothing can enumerate a class's statics, and that hand-written list was a
  /// second source of truth free to drift from the thing it claimed to
  /// describe: adding four constants to `AppRoutes` — a duplicate `/login`, a
  /// padded `' /quiz '`, an uppercase `/QUIZ`, a second spelling `/login/` —
  /// without touching this file left the suite green, defeating five of the
  /// seven structural invariants below, including the two whose own comments
  /// name precisely that hazard.
  ///
  /// An `AppRoutes.values` list in `lib/` would only have moved the drift from
  /// this file into production code; a constant declared outside that list
  /// would still be missing. Parsing the declarations is what applies the
  /// invariants to every route that exists, and `tool/route_check.dart` does the
  /// parsing so Gate 4 and this suite read the same bytes with the same pattern.
  ///
  /// The honest limit: Dart cannot see a constant built from an expression
  /// rather than a literal. Those are named and failed on below instead of being
  /// skipped.
  final String source = File(routesFile).readAsStringSync();
  final Map<String, String> inventory = declaredRouteValues(source);
  final List<String> declared = declaredRouteNames(source);

  group('the six locked routes', () {
    test('login is /login', () {
      expect(AppRoutes.login, '/login');
    });

    test('home is /', () {
      expect(AppRoutes.home, '/');
    });

    test('reading is /reading', () {
      expect(AppRoutes.reading, '/reading');
    });

    test('quiz is /quiz', () {
      expect(AppRoutes.quiz, '/quiz');
    });

    test('result is /result', () {
      expect(AppRoutes.result, '/result');
    });

    test('settings is /settings', () {
      expect(AppRoutes.settings, '/settings');
    });
  });

  group('the inventory is the declaration site', () {
    // `inventory` is the test's own claim about what `AppRoutes` contains. If the
    // parser were emptied — a regex that stopped matching, a file that moved —
    // every `expect` in the group below would be iterating nothing and the
    // suite would pass while asserting nothing. That is the self-comparing
    // tautology the Phase 0b mutation audit removed from `failure_test.dart`, so
    // the shape of the claim is asserted first, and the seven names are spelled
    // out rather than merely counted: a parser that quietly returned the wrong
    // seven would otherwise sail through.
    test('the parser sees every declaration, including ones it cannot read', () {
      // Anti-vacuity for the whole group below. A declaration whose initialiser
      // is not a plain literal is reported rather than dropped, because an
      // invariant that silently skips a route is worse than one that admits it
      // cannot evaluate it.
      expect(
        declared.toSet(),
        inventory.keys.toSet(),
        reason:
            'every `static const String` must be readable as a plain literal, '
            'or the invariants below do not apply to it',
      );
    });

    test('the inventory is exactly the seven declared route names', () {
      expect(declared, <String>[
        'login',
        'home',
        'reading',
        'quiz',
        'result',
        'settings',
        'fallback',
      ]);
      expect(inventory, hasLength(7));
      // `inventory.values.whereType<String>()` used to sit here, asserting that
      // all seven entries were real strings. It could not fail: `inventory` is a
      // `Map<String, String>`, so `.values` is statically `Iterable<String>` and
      // `whereType<String>()` is the identity — it returned all seven elements
      // unconditionally. The hazard it guarded is unrepresentable too; a `null`
      // in a `Map<String, String>` literal is a compile error, not a runtime
      // state, and `hasLength(7)` above already implies seven strings.
    });
  });

  group('structural invariants', () {
    test('every route except the fallback starts with a slash', () {
      for (final MapEntry<String, String> route in inventory.entries) {
        if (route.key == 'fallback') {
          continue;
        }
        expect(
          route.value.startsWith('/'),
          isTrue,
          reason: '${route.key} ("${route.value}") must be an absolute path',
        );
      }
    });

    test('the fallback is the sentinel, and the only route without a slash', () {
      // NO LITERAL-EQUALITY CHECK ON THE VALUE, and its removal is the point.
      //
      // `expect(AppRoutes.fallback, '*')` stood here, and it was the only assertion
      // in the whole repository that noticed `'*'` → `'/*'`. But `'/*'` is not
      // broken. Measured through the executed matcher — `app_router_test.dart`
      // holds the table — the two spellings produce identical results for `/x`,
      // `//`, `''`, `/not-a-route`, `/login/x`, `/deeply/nested/x` and `/LOGIN`.
      // So the check was pinning a preference and reading as a defect detector,
      // while the doc comment beside it called the alternative non-functional.
      //
      // What is worth holding here is the SHAPE, which holds whichever spelling is
      // chosen: a sentinel is not a path, so exactly one declared route may sit
      // outside the slash-prefixed set. The behavioural half — that the wildcard
      // really does cover what nothing else matches — lives in
      // `app_router_test.dart`, where it is executed.
      expect(
        inventory.entries
            .where((MapEntry<String, String> e) => !e.value.startsWith('/'))
            .map((MapEntry<String, String> e) => e.key),
        <String>['fallback'],
        reason:
            'a sentinel is not a path, so exactly one declared route may sit '
            'outside the slash-prefixed set',
      );
    });

    test('no two routes collide', () {
      // Duplicate paths would make the router's match order decide which screen
      // a user reaches, which is exactly the kind of ambiguity the router
      // cannot report — it matches the first one and silently ignores the rest.
      final Set<String> duplicates = inventory.values
          .where(
            (String path) =>
                inventory.values.where((String p) => p == path).length > 1,
          )
          .toSet();

      expect(duplicates, isEmpty, reason: 'these paths are declared twice');
    });

    test('no path carries stray whitespace', () {
      for (final MapEntry<String, String> route in inventory.entries) {
        expect(
          route.value,
          route.value.trim(),
          reason: '${route.key} is padded with whitespace',
        );
      }
    });

    test('home alone is the root, and no other path ends in a slash', () {
      // `'/'` legitimately ends in a slash — it is the root. Any *other* path
      // ending in one creates a second spelling of itself: '/login' and
      // '/login/' are distinct strings that both pass the uniqueness check and
      // never match each other, which is the worst kind of route bug to
      // diagnose, because navigation to one silently fails to find the other.
      expect(
        inventory.entries
            .where((MapEntry<String, String> e) => e.value.endsWith('/'))
            .map((MapEntry<String, String> e) => e.key),
        <String>['home'],
      );
    });

    test('every route segment is a lowercase identifier', () {
      // auto_route matches paths case-sensitively, so '/Quiz' beside '/quiz'
      // compiles, passes every check above, and 404s at runtime. Requiring the
      // shape here catches the drift while it is still a diff of one character.
      // Empty segments are skipped rather than rejected: the root's leading
      // slash and home's own trailing slash both produce one.
      final RegExp segment = RegExp(r'^[a-z][a-z0-9]*$');

      for (final MapEntry<String, String> route in inventory.entries) {
        if (route.key == 'fallback') {
          continue;
        }
        for (final String part in route.value.split('/')) {
          if (part.isEmpty) {
            continue;
          }
          expect(
            segment.hasMatch(part),
            isTrue,
            reason:
                '"$part" in ${route.key} ("${route.value}") is not a '
                'lowercase identifier',
          );
        }
      }
    });
  });
}
