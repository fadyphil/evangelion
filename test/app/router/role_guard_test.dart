import 'package:evangelion/app/router/role_guard.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:flutter_test/flutter_test.dart';

/// A seam that throws, which [RoleAccess] forbids and the guard must not hide.
///
/// NOT a duplicate of [LiveRoleAccess] and not a second seam: it exists to be
/// the one thing a conforming `RoleAccess` is forbidden to be, so that
/// `role_access.dart`'s "an implementation MUST NOT throw" paragraph has a
/// measurement behind it. The parallel is `auth_guard_test.dart`'s
/// `ThrowingAuthStatus`, and sharing the production implementation here would
/// defeat the point — the whole question is what the guard does with a seam
/// that breaks its contract.
final class ThrowingRoleAccess implements RoleAccess {
  const ThrowingRoleAccess(this.message);

  /// The message the failure carries, so a diagnostic names the cause.
  final String message;

  @override
  UserRole get role => throw StateError(message);

  @override
  bool allows(UserCapability capability) => throw StateError(message);
}

void main() {
  group('the decision, without a Navigator', () {
    // ## WHY THERE IS NO NAVIGATOR IN THIS FILE, and it is not a shortcut.
    //
    // `auth_guard_test.dart` has two groups: a pure one and a "round trip" one
    // that drives the production `AppRouter`. The round trip is missing here
    // for a **mechanical** reason and not a stylistic one — the routes that
    // carry this guard are registered in the router by the portal's own task,
    // and a guard test that invented its own router would be asserting against
    // a fiction. A router built here would be a second navigation system, and
    // the property worth holding (a reader is refused, and lands on their own
    // route) is a property of the **decision** plus the **landing route**, both
    // of which are values and are exercised below.
    //
    // What this file therefore does NOT cover, stated rather than left for a
    // reader to discover: that the router's own `pushPath` to a refused route
    // ends on the landing route. That is the router task's assertion, and it
    // belongs to the router task because the router is what it exercises.

    // The role the seam reads. A local, because the seam is a **reader**: it
    // answers from whatever the app currently believes, and the test moves
    // that belief between two calls.
    UserRole role = UserRole.kid;
    final RoleAccess access = LiveRoleAccess(() => role);

    test('a role that grants the capability allows the navigation', () {
      role = UserRole.adminServant;

      expect(
        RoleGuard(access, UserCapability.viewServantReport).decide(),
        RoleGuardDecision.allow,
      );
    });

    test('a role that does not grant it refuses', () {
      role = UserRole.kid;

      expect(
        RoleGuard(access, UserCapability.viewServantReport).decide(),
        RoleGuardDecision.redirectToLanding,
      );
    });

    test('a viewer servant may read the report and may not schedule', () {
      // The grant table's own ladder, read through the seam rather than
      // restated: a `viewer_servant` has the report and not the schedule, and
      // a guard that disagreed with `UserRole.grantsFor` would be the second
      // source of truth this repository keeps removing.
      role = UserRole.viewerServant;

      expect(
        RoleGuard(access, UserCapability.viewServantReport).decide(),
        RoleGuardDecision.allow,
      );
      expect(
        RoleGuard(access, UserCapability.scheduleReading).decide(),
        RoleGuardDecision.redirectToLanding,
      );
    });

    test('a refused navigation is sent to the reader\'s own landing route', () {
      // The refusal has a **destination**, and it is the reader's own route
      // rather than a generic one. A kid is sent to the reader's app; a
      // servant is sent to the portal's hub, which is the only page they were
      // ever going to be offered anyway. The one place a role becomes a path
      // is `landingRouteFor`, and the guard uses it rather than spelling a
      // second mapping out.
      //
      // The servant's refusal is a **scheduling** refusal, not a report one: a
      // `viewer_servant` holds `viewServantReport`, so asking them to open the
      // report would be asking a question the grant table answers "yes" to.
      role = UserRole.kid;
      final RoleGuard guard = RoleGuard(
        access,
        UserCapability.viewServantReport,
      );

      expect(guard.decide(), RoleGuardDecision.redirectToLanding);
      expect(guard.landingPath, AppRoutes.home);

      role = UserRole.viewerServant;
      final RoleGuard scheduling = RoleGuard(
        access,
        UserCapability.scheduleReading,
      );

      expect(scheduling.decide(), RoleGuardDecision.redirectToLanding);
      expect(scheduling.landingPath, AppRoutes.servant);
    });

    test('and it does not swallow a throwing seam', () {
      // `role_access.dart` says an implementation MUST NOT throw, and says
      // what happens when one does. The second half of that is falsifiable
      // without a Navigator, which is why this is here: a `try`/`catch` added
      // to the guard for any reason — "fail closed to the landing route", "log
      // it and carry on" — turns this red, and it is a much cheaper signal than
      // a test that has to mount a tree to notice.
      //
      // A caught throw would also be the **wrong** answer twice over. It would
      // need an `// ignore:` against `avoid_catching_errors` and
      // `avoid_catches_without_on_clauses`, which this repository has none of,
      // and a silent refusal is indistinguishable from a real one: the reader
      // is sent to their landing route and nothing says why.
      expect(
        () => const RoleGuard(
          ThrowingRoleAccess('allows is forbidden'),
          UserCapability.viewServantReport,
        ).decide(),
        throwsStateError,
        reason:
            'catching here would answer `false` for a role the app simply could '
            'not read, and a silent refusal is indistinguishable from a real '
            'one',
      );

      // **And the landing route is a second read of the same seam**, so it is
      // a second place a throw could be absorbed — and the second read is the
      // one that happens *after* the refusal, so a `try`/`catch` around it
      // would be a `try`/`catch` around the redirect itself. A refusal whose
      // destination cannot be computed is not a refusal; it is a navigation
      // that goes nowhere, which is the blank-frame cost this guard exists to
      // avoid.
      expect(
        () => const RoleGuard(
          ThrowingRoleAccess('role is forbidden'),
          UserCapability.viewServantReport,
        ).landingPath,
        throwsStateError,
        reason:
            'the landing route is read from the same seam, and a caught throw '
            'there would leave the reader on the screen they were refused',
      );
    });

    test('the decision follows the role, read afresh each time', () {
      // Not a snapshot. `RoleAccess` is a **reader**, not a mirror: the role is
      // chosen on the login screen and it changes, so a guard that remembered
      // its first answer would keep allowing a capability the reader has since
      // lost — and would keep refusing one they have since gained. The
      // `RoleAccess` doc records the same freeze in `BlocAuthStatus`, where all
      // 1200 tests were green while the answer went stale.
      role = UserRole.adminServant;
      final RoleGuard guard = RoleGuard(
        access,
        UserCapability.viewServantReport,
      );

      expect(guard.decide(), RoleGuardDecision.allow);

      role = UserRole.kid;

      expect(guard.decide(), RoleGuardDecision.redirectToLanding);
    });
  });
}
