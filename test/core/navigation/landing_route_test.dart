import 'dart:io';

import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/landing_route.dart';
import 'package:flutter_test/flutter_test.dart';

// Not a `package:` import: `tool/` is not a library, it is the body Gate 4 runs.
// Sharing the parser is the point — it reads the declaration site with the same
// pattern the gate does, so this suite's completeness claim and the gate's
// `9 route declaration(s)` cannot be counting different things. §2.1 decision 8c
// sanctions a source scan over the declaration site for exactly this reason.
import '../../../tool/route_check.dart';

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
///
/// ## AND THE ONE TEST THIS SUITE DROPPED
///
/// "and the servant route is slash-prefixed like every real route" is deleted,
/// not repaired. It asserted `AppRoutes.servant.startsWith('/')` — a property of
/// a **constant owned by another file**, restated in a suite about
/// [landingRouteFor]. `app_routes_test.dart` already holds that invariant over
/// the declaration site ("every route except the fallback starts with a slash"),
/// it applies it to all nine declarations rather than to the one this suite
/// happens to name, and it fails for the identical reason. Two implementations
/// of one invariant are two things to keep in step, which is §7's own note on
/// Gate 4 and this file's opening argument against hand-written mirrors.
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
    //
    // COMPLETE, all nine, and asserted complete against the declaration site
    // below. An earlier version named seven of the nine and omitted
    // `communion` and `fallback`, which made the failure message factually
    // wrong: a landing on `/communion` would have been reported as "an
    // undeclared path" when `/communion` is very much declared. An incomplete
    // hand-written mirror of another file is the same second-source-of-truth
    // shape this file's own doc argues against, and a tenth constant would have
    // landed in the gap unnoticed.
    //
    // **AND THE NINE IS NINE AGAIN.** `/result` retired to a **modal** in
    // Phase 6, so `AppRoutes.result` no longer exists and the mirror does not
    // name it — which is what puts this set back on the number the prose above
    // has always claimed. The mirror is a mirror of the **declaration site**,
    // and the completeness test below is what holds it to that: a constant
    // added to `app_routes.dart` without being added here fails, and a
    // constant removed from there without being removed here fails the other
    // way round.
    const Set<String> declared = <String>{
      AppRoutes.login,
      AppRoutes.home,
      AppRoutes.reading,
      AppRoutes.quiz,
      AppRoutes.settings,
      AppRoutes.communion,
      // **Task 5.6 added the journey**, and the comment above's point is
      // the one it proves: a constant nobody mirrored here would have
      // landed in the gap unnoticed.
      AppRoutes.journey,
      AppRoutes.servant,
      AppRoutes.fallback,
    };

    test('every landing is one of the declared route constants', () {
      for (final UserRole role in UserRole.values) {
        expect(
          declared,
          contains(landingRouteFor(role)),
          reason: 'landingRouteFor($role) returned an undeclared path',
        );
      }
    });

    test('and the declared set is COMPLETE — read from the declaration site, '
        'not from the list above', () {
      // WHY A SOURCE SCAN. The list above is still a hand-written mirror; this
      // is what stops it drifting. Dart has no reflection, so nothing can
      // enumerate a class's statics, and `AppRoutes.values` in `lib/` would only
      // move the drift into production code — a constant declared outside that
      // list would still be missing. §2.1 decision 8c makes a source scan the
      // sanctioned technique for exactly this, and `tool/route_check.dart` is the
      // same parser Gate 4 runs, so the gate and this suite cannot disagree
      // about what is declared. It is imported the same way
      // `app_routes_test.dart` imports it, for the same reason: one extraction,
      // one pattern.
      final Map<String, String> inventory = declaredRouteValues(
        File(routesFile).readAsStringSync(),
      );

      // Every declared route must be *reachable as a landing candidate* in the
      // set above. This is deliberately NOT "every declared route is a landing" —
      // `/login` and `*` are not, and asserting that they are would be false.
      // The claim is one-directional and it is the one that matters: nothing may
      // be declared that this suite would then call undeclared.
      for (final MapEntry<String, String> route in inventory.entries) {
        expect(
          declared,
          contains(route.value),
          reason:
              '`AppRoutes.${route.key}` is "${route.value}" and is declared in '
              '`app_routes.dart`, but it is missing from the set above — add it, '
              'or a landing on it would be reported as undeclared',
        );
      }

      // And the reverse, so neither side can hide: no entry in the set that the
      // declaration site does not have. Without this, deleting a constant would
      // leave the mirror naming a path that no longer exists.
      for (final String path in declared) {
        expect(
          inventory.values,
          contains(path),
          reason:
              'the set above names "$path", which no `static const String` in '
              '`app_routes.dart` declares',
        );
      }
    });
  });
}
