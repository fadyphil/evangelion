import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/landing_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// [landingRouteFor] — the ONE place a role turns into a route.
///
/// ## WHY THE EXPECTATIONS ARE WRITTEN AGAINST `AppRoutes.*` AND NOT AGAINST
/// STRING LITERALS
///
/// `'/servant'` typed here and `AppRoutes.servant` typed there are two names for
/// one route, and the compiler cannot see them disagree. So every expectation
/// below names the **constant**, which makes the suite fail the moment the
/// constant's value changes and leave the landing decision in step for free. The
/// literal appears exactly once in this repository's navigation layer — in
/// `app_routes.dart` — and `app_routes_test.dart` holds its seven structural
/// invariants over the declaration site.
///
/// ## AND WHY THE LOOP IS OVER `UserRole.values` RATHER THAN THREE CASES
///
/// A fourth `UserRole` has to be impossible to ignore, and it is impossible to
/// ignore by construction here in two independent ways:
///
///  * **at compile time** — `landingRouteFor` is an exhaustive `switch`
///    expression with **no `default` arm**, so a new enum member is a compile
///    error at the `switch` and nothing else has to be done;
///  * **at test time** — every role is routed through the same expected map
///    below, and a member the map does not name cannot match it.
///
/// AGENT_CONTEXT §2.1 records that this project's exhaustiveness is load-bearing
/// rather than stylistic, and `ApiErrorMapper`'s `switch` over
/// `DioExceptionType.values` is the recorded gate. A `default` arm here would
/// have made a fourth role land on whichever screen the author had chosen to
/// make default, and it would have compiled.
///
/// ## WHAT THE SUITE DELIBERATELY DOES NOT CLAIM
///
/// `/servant` is **declared but not registered**: no `AutoRoute` in
/// `app_router.dart` names it, so today a navigation to that path falls through
/// the `'*'` wildcard and redirects to [AppRoutes.home]. That is a recorded gap,
/// not a behaviour this suite pins — pinning it would ratify a placeholder as a
/// finished screen, which is recorded decision 8's failure in its purest form.
/// The portal route belongs to the task that builds the portal, and the constant
/// exists now because [landingRouteFor] needs one value to name. The "the
/// landing is a DECLARED route" group below is the half that is true today and
/// must stay true.
void main() {
  group('a kid lands on home', () {
    test('because a kid is a reader, and the reading lives on /', () {
      expect(landingRouteFor(UserRole.kid), AppRoutes.home);
    });
  });

  group('both servant roles land on the servant route', () {
    test('a viewer servant', () {
      expect(landingRouteFor(UserRole.viewerServant), AppRoutes.servant);
    });

    test('an admin servant', () {
      expect(landingRouteFor(UserRole.adminServant), AppRoutes.servant);
    });

    test('and the two agree, so "servant" is one destination and not two', () {
      // The property a written-out pair of assertions cannot see: a later
      // revision that gave the admin a second screen would leave both individual
      // expectations green while silently making the role's landing a function of
      // privilege rather than of kind. Stated as its own test so the day it stops
      // holding, the failure names the thing that changed.
      expect(
        landingRouteFor(UserRole.viewerServant),
        landingRouteFor(UserRole.adminServant),
      );
    });
  });

  group('exhaustive over every role there is', () {
    // The expected table, named once and enumerated in BOTH directions. A map
    // that silently dropped a role would leave the loop below iterating over
    // fewer members than `UserRole.values` has, so the coverage assertion is
    // written first and the per-role comparison second.
    const Map<UserRole, String> expected = <UserRole, String>{
      UserRole.kid: AppRoutes.home,
      UserRole.viewerServant: AppRoutes.servant,
      UserRole.adminServant: AppRoutes.servant,
    };

    test('the table names every role, and only roles that exist', () {
      expect(expected.keys.toSet(), UserRole.values.toSet());
    });

    test('every role routes as the table says', () {
      for (final UserRole role in UserRole.values) {
        expect(
          landingRouteFor(role),
          expected[role],
          reason:
              'landingRouteFor($role) is not what the table says, or a role '
              'exists that the table does not name',
        );
      }
    });

    test(
      'and the two destinations are distinct, so the servant arm is live',
      () {
        // Anti-vacuity. If [AppRoutes.servant] were ever equal to [AppRoutes.home],
        // every assertion above would pass while the servant branch selected
        // nothing — the same shape as decision 143's single empty response read as
        // a property of the system. One assertion, on the constants themselves, so
        // it cannot be satisfied by the function under test.
        expect(AppRoutes.servant, isNot(AppRoutes.home));
        expect(AppRoutes.servant, isNot(AppRoutes.login));
      },
    );
  });

  group('the landing is a DECLARED route, not a string invented here', () {
    // The half of the claim that is true today. Both destinations are named by a
    // `static const String` in `app_routes.dart`, which is what Gate 4 parses and
    // what `app_routes_test.dart`'s seven structural invariants apply to. A
    // hand-typed `'/servant'` inside the `switch` would compile, would answer
    // every assertion above, and would be invisible to all of them.
    test('every landing is one of the declared route constants', () {
      const Set<String> declared = <String>{
        AppRoutes.login,
        AppRoutes.home,
        AppRoutes.reading,
        AppRoutes.quiz,
        AppRoutes.result,
        AppRoutes.settings,
        AppRoutes.servant,
      };

      for (final UserRole role in UserRole.values) {
        expect(
          declared,
          contains(landingRouteFor(role)),
          reason: 'landingRouteFor($role) returned an undeclared path',
        );
      }
    });

    test('and the servant route is slash-prefixed like every real route', () {
      // The one structural property of the new constant worth repeating here,
      // because this file is where a reader looks for what `/servant` is. The
      // full set of seven invariants lives in `app_routes_test.dart` and runs
      // over the declaration site, so this is a restatement rather than a
      // second implementation — it fails for the same reason that one does.
      expect(AppRoutes.servant.startsWith('/'), isTrue);
    });
  });
}
