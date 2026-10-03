import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_import_graph.dart';

/// The gate that keeps Phase 5's `auth` feature able to *implement* the seam
/// without dragging auto_route with it.
///
/// ## WHY THIS NEEDS A TEST AND NOT JUST A DOC COMMENT
///
/// `core/navigation/` is one of the directories `tool/verify_purity.sh` Gate 1
/// holds to no Flutter, Dio or http — and its header comment says it does so
/// because `app_routes.dart` documents the property. Gate 1 checks a file's
/// **own** directives only. It cannot see a file that is itself Flutter-free but
/// imports something that is not, which is exactly how this seam would rot: the
/// day someone reaches for `AutoRouteGuard` here to "simplify" it, the closure
/// goes Flutter-bound while every direct-import gate stays green.
///
/// The walk is the transitive version of Gate 1, and it is the same walk
/// `injection_test.dart` uses on the composition root — one implementation, two
/// entry points, so the two cannot disagree about what "Flutter-free" means.
void main() {
  group('AuthStatus', () {
    test('is one boolean a feature can implement on its own', () {
      // The interface itself, executed rather than read. A future `sealed`, or a
      // second required member, breaks this — which is the point: Phase 5 has to be
      // able to implement it from the `auth` feature with one class and no imports
      // beyond `core/`.
      expect(const _MinimalSession().isAuthenticated, isTrue);
      expect(
        const _MinimalSession(authenticated: false).isAuthenticated,
        isFalse,
      );
    });

    test('its whole import closure reaches no flutter, dio or http', () {
      const String entry = 'lib/core/navigation/auth_status.dart';
      final Set<String> reachable = reachableProjectFiles(entry);

      for (final String path in reachable) {
        expect(
          forbiddenImportUrisOf(path),
          isEmpty,
          reason:
              '$path must stay Flutter-free: the auth feature implements this '
              'seam and reaches it through `core/`, never through a router',
        );
      }

      // The strongest form of the claim: the closure is the file and nothing else,
      // because `AuthStatus` declares no import at all. One more import and this
      // fails.
      expect(reachable, <String>{entry});
    });

    test('and the walk is not vacuous: from the router the closure is many files '
        'and reaches Flutter', () {
      // THE ANTI-VACUITY HALF, and the reason the assertion above can be believed.
      // A walker that matched no directive at all would return exactly the entry
      // point for `auth_status.dart` and pass the previous test while looking at
      // nothing. Pointed at a file that *does* have edges, the same walker must
      // return several files — and must see the `package:flutter/` import that
      // `AuthStatus` is kept clear of. This is the shape `injection_test.dart`
      // uses for its own reachability list.
      final Set<String> fromRouter = reachableProjectFiles(
        'lib/app/router/app_router.dart',
      );

      expect(
        fromRouter.length,
        greaterThan(1),
        reason:
            'the router names all six generated routes, so its closure is '
            'many files — if this ever reads 1, the walk has stopped following '
            'edges and the test above is meaningless',
      );
      expect(
        fromRouter.any((String path) => forbiddenImportUrisOf(path).isNotEmpty),
        isTrue,
        reason:
            'the router genuinely is Flutter-bound, which is the whole reason '
            '`AuthStatus` lives in `core/` and the router does not',
      );
    });
  });
}

/// The smallest thing that can implement [AuthStatus] — which is the shape Phase 5
/// is asked to deliver.
final class _MinimalSession implements AuthStatus {
  const _MinimalSession({this.authenticated = true});

  final bool authenticated;

  @override
  bool get isAuthenticated => authenticated;
}
