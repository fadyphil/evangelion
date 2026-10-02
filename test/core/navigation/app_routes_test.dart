import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// The complete inventory of route paths the app ships, as `name -> path`.
///
/// Deliberately declared *here* rather than as a `values` list on [AppRoutes].
/// Dart has no reflection, so an invariant over "every route" needs an
/// enumeration somewhere, and a production list would be a second source of
/// truth for values this file already pins exactly — free to drift from the
/// constants it claims to enumerate. Holding it in the test costs nothing at
/// runtime and makes a seventh route an explicit edit here, which is the point:
/// a new route should be added to the inventory deliberately, not slip past a
/// gate that stopped looking at it.
///
/// THE LIMIT OF THAT CHOICE, stated plainly: adding a constant to [AppRoutes]
/// without adding it to [_inventory] leaves this file green and stops the
/// collision invariant from covering that route. The value assertions below
/// still cover the six locked routes, so nothing silently changes value — but
/// Phase 4, which adds the real router, must extend this inventory.
const Map<String, String> _inventory = <String, String>{
  'login': AppRoutes.login,
  'home': AppRoutes.home,
  'reading': AppRoutes.reading,
  'quiz': AppRoutes.quiz,
  'result': AppRoutes.result,
  'settings': AppRoutes.settings,
  'fallback': AppRoutes.fallback,
};

void main() {
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

  group('structural invariants', () {
    // The inventory is the test's own claim about what AppRoutes contains. If
    // AppRoutes were emptied, every `expect` above would be comparing against
    // null and the suite would pass while asserting nothing — the same
    // self-comparing tautology the Phase 0b mutation audit removed from
    // failure_test.dart. Asserting the shape of the claim first means the rest
    // of this group has to be talking about seven real strings.
    test('the inventory is seven entries and every path is a real string', () {
      expect(_inventory, hasLength(7));
      expect(
        _inventory.values.whereType<String>(),
        hasLength(7),
        reason: 'a null or non-String path would make the group below vacuous',
      );
    });

    test('every route except the fallback starts with a slash', () {
      for (final MapEntry<String, String> route in _inventory.entries) {
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

    test('the fallback is the wildcard, and the only route without a slash', () {
      expect(AppRoutes.fallback, '*');
      expect(
        _inventory.entries
            .where((MapEntry<String, String> e) => !e.value.startsWith('/'))
            .map((MapEntry<String, String> e) => e.key),
        <String>['fallback'],
        reason:
            'auto_route matches RedirectRoute(path: "*") literally, so exactly '
            'one path may sit outside the slash-prefixed set',
      );
    });

    test('no two routes collide', () {
      // Duplicate paths would make the router's match order decide which screen
      // a user reaches, which is exactly the kind of ambiguity the router
      // cannot report — it matches the first one and silently ignores the rest.
      final Set<String> duplicates = _inventory.values
          .where(
            (String path) =>
                _inventory.values.where((String p) => p == path).length > 1,
          )
          .toSet();

      expect(duplicates, isEmpty, reason: 'these paths are declared twice');
    });

    test('no path carries stray whitespace', () {
      for (final MapEntry<String, String> route in _inventory.entries) {
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
        _inventory.entries
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

      for (final MapEntry<String, String> route in _inventory.entries) {
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
