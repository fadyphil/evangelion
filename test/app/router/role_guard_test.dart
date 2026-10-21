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

  @override
  bool allowsRole(UserRole role, UserCapability capability) =>
      throw StateError(message);
}

/// A seam that records **what it was asked**, and answers from the grant table.
///
/// It exists to pin three things the shipped seam cannot show on its own:
/// WHICH member the guard asks, WITH WHICH role, and HOW MANY times it reads
/// the seam. `role_access.dart`'s hazard #2 is about a seam that guarantees
/// liveness and not atomicity, so the *number* of reads is the whole subject,
/// and comparing answers cannot distinguish "read once" from "read twice".
final class _SpyRoleAccess implements RoleAccess {
  _SpyRoleAccess(this._read);

  /// Where the role comes from. The seam is a **reader**, so this is a reader.
  final UserRole Function() _read;

  /// The roles [allowsRole] was handed, in the order it was handed them.
  final List<UserRole> rolesAskedAbout = <UserRole>[];

  /// The capabilities [allows] was asked about.
  ///
  /// A **separate** list from [rolesAskedAbout] on purpose: the shipped seam
  /// answers `allows` *through* `allowsRole`, so one list could not tell "the
  /// guard asked `allowsRole` with a role" from "the guard asked `allows` and
  /// the seam read the role itself".
  final List<UserCapability> capabilitiesAskedFor = <UserCapability>[];

  /// How many times the seam's role was read.
  int reads = 0;

  @override
  UserRole get role {
    reads++;
    return _read();
  }

  @override
  bool allows(UserCapability capability) {
    capabilitiesAskedFor.add(capability);
    return UserRole.grantsFor(role).contains(capability);
  }

  @override
  bool allowsRole(UserRole role, UserCapability capability) {
    rolesAskedAbout.add(role);
    return UserRole.grantsFor(role).contains(capability);
  }
}

/// A seam that grants **nothing**, whatever the table says.
///
/// It exists to prove the guard asks the SEAM for the grant rather than
/// reading `UserRole.grantsFor` itself. A guard that carried its own copy of
/// the table would allow what this seam refuses, and the two answers would
/// disagree — the "two sources of truth for one value" defect that decisions
/// 5 and 68 each removed.
final class _RefusingRoleAccess implements RoleAccess {
  const _RefusingRoleAccess();

  @override
  UserRole get role => UserRole.adminServant;

  @override
  bool allows(UserCapability capability) => false;

  @override
  bool allowsRole(UserRole role, UserCapability capability) => false;
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
    //
    // ## AND WHY THE ONE-READ PROPERTY IS STILL EXERCISED HERE
    //
    // The "exactly one read" claim is about a **navigation**, and the
    // navigation lives in `onNavigation` — which needs a `NavigationResolver`
    // and a `StackRouter`, and therefore a router. Rather than build one, the
    // guard keeps the whole decision in a value: `decideNow()` captures the
    // role ONCE and answers both the grant and the destination from that one
    // capture, and `onNavigation` is a switch over that value. So the value is
    // the navigation's decision, not a second, parallel way of making one.

    // The role the seam reads. A local, because the seam is a **reader**: it
    // answers from whatever the app currently believes, and the test moves
    // that belief between two calls.
    UserRole role = UserRole.kid;
    final RoleAccess access = LiveRoleAccess(() => role);

    test('a role that grants the capability allows the navigation', () {
      final RoleGuard guard = RoleGuard(
        access,
        UserCapability.viewServantReport,
      );

      expect(guard.decideFor(UserRole.adminServant), RoleGuardDecision.allow);
    });

    test('a role that does not grant it refuses', () {
      final RoleGuard guard = RoleGuard(
        access,
        UserCapability.viewServantReport,
      );

      expect(
        guard.decideFor(UserRole.kid),
        RoleGuardDecision.redirectToLanding,
      );
    });

    test('a viewer servant may read the report and may not schedule', () {
      // The grant table's own ladder, read through the seam rather than
      // restated: a `viewer_servant` has the report and not the schedule, and
      // a guard that disagreed with `UserRole.grantsFor` would be the second
      // source of truth this repository keeps removing.
      final RoleGuard report = RoleGuard(
        access,
        UserCapability.viewServantReport,
      );
      final RoleGuard scheduling = RoleGuard(
        access,
        UserCapability.scheduleReading,
      );

      expect(report.decideFor(UserRole.viewerServant), RoleGuardDecision.allow);
      expect(
        scheduling.decideFor(UserRole.viewerServant),
        RoleGuardDecision.redirectToLanding,
      );
    });

    test('and the grant comes from the SEAM, not from a table the guard '
        'carries', () {
      // The guard asks the seam, and the seam answers — the seam is where the
      // grant table lives, and a guard that read `UserRole.grantsFor` itself
      // would be a second copy of the policy, free to drift from the first.
      //
      // The seam here grants NOTHING, and the role it holds is the one the
      // table grants everything to. So a guard that asked the table would
      // allow, and only a guard that asks the seam refuses.
      const RoleGuard guard = RoleGuard(
        _RefusingRoleAccess(),
        UserCapability.submitQuiz,
      );

      expect(
        guard.decideFor(UserRole.kid),
        RoleGuardDecision.redirectToLanding,
        reason:
            'the seam refuses it, so the guard must refuse it — a guard that '
            'answered from the table would have allowed a capability the seam '
            'does not grant',
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

      final ({RoleGuardDecision decision, String landingPath}) refused = guard
          .decideNow();

      expect(refused.decision, RoleGuardDecision.redirectToLanding);
      expect(refused.landingPath, AppRoutes.home);

      role = UserRole.viewerServant;
      final RoleGuard scheduling = RoleGuard(
        access,
        UserCapability.scheduleReading,
      );

      final ({RoleGuardDecision decision, String landingPath}) servant =
          scheduling.decideNow();

      expect(servant.decision, RoleGuardDecision.redirectToLanding);
      expect(servant.landingPath, AppRoutes.servant);
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
          ThrowingRoleAccess('allowsRole is forbidden'),
          UserCapability.viewServantReport,
        ).decideFor(UserRole.kid),
        throwsStateError,
        reason:
            'catching here would answer `false` for a role the app simply could '
            'not read, and a silent refusal is indistinguishable from a real '
            'one',
      );

      // **And the CAPTURE throws too.** The role the guard reasons about is
      // read from the seam, so a seam that cannot be read leaves the guard
      // with nothing to reason about — and a refusal it invented would be a
      // destination computed from a role that was never there.
      //
      // The *second* read this test used to pin is gone, and the reason is
      // the whole point of the change: the landing route is computed from the
      // role the guard already captured, so there is no second read that
      // could be swallowed, and no second read that could disagree.
      expect(
        () => const RoleGuard(
          ThrowingRoleAccess('role is forbidden'),
          UserCapability.viewServantReport,
        ).decideNow(),
        throwsStateError,
        reason:
            'the capture is a read of the same seam, and a throw there must '
            'escape rather than become a refusal with a destination',
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

      expect(guard.decideNow().decision, RoleGuardDecision.allow);

      role = UserRole.kid;

      expect(guard.decideNow().decision, RoleGuardDecision.redirectToLanding);
    });
  });

  group('the role is read ONCE per decision', () {
    // ## THIS IS THE PROPERTY THE SEAM'S OWN HAZARD #2 ASKS FOR
    //
    // `role_access.dart`'s hazard #2: a seam built on a reader guarantees
    // liveness and NOT atomicity, so two reads in one decision can be handed
    // two roles if the app emits in between. The remedy it names is to capture
    // the role once — and to ask the SEAM for the grant rather than reading
    // the table, which is what `RoleAccess.allowsRole` exists for.
    //
    // The seam below is the "the app emitted in between" case made literal: it
    // answers `kid` on its first read and `adminServant` on its second. A
    // guard that reads twice gets a refusal computed against `kid` and a
    // destination computed against `adminServant`, and sends a child to a
    // servant's page.

    test('the grant and the landing come from the SAME role', () {
      int reads = 0;
      final RoleAccess flipping = LiveRoleAccess(() {
        reads++;
        return reads == 1 ? UserRole.kid : UserRole.adminServant;
      });
      final RoleGuard guard = RoleGuard(
        flipping,
        UserCapability.viewServantReport,
      );

      final ({RoleGuardDecision decision, String landingPath}) outcome = guard
          .decideNow();

      expect(
        reads,
        1,
        reason:
            'the seam must be read exactly once per decision — two reads can be '
            'handed two roles if the app emits in between',
      );
      expect(
        outcome.decision,
        RoleGuardDecision.redirectToLanding,
        reason:
            'the grant was asked for the role that was read, and a kid holds no '
            'servant report',
      );
      expect(
        outcome.landingPath,
        AppRoutes.home,
        reason:
            "and the destination is THAT role's route — a second read would have "
            "sent the child to a servant's hub",
      );
    });

    test('and the guard asks the seam about the role it captured', () {
      final _SpyRoleAccess spy = _SpyRoleAccess(() => UserRole.kid);
      final RoleGuard guard = RoleGuard(spy, UserCapability.viewServantReport);

      guard.decideNow();

      expect(
        spy.rolesAskedAbout,
        <UserRole>[UserRole.kid],
        reason:
            'the grant is asked of the seam with the role the guard captured, '
            'so the answer is the seam\'s answer about THAT role',
      );
      expect(
        spy.capabilitiesAskedFor,
        isEmpty,
        reason:
            '`allows` reads the role itself, so asking it would be a second '
            'read — the guard asks `allowsRole` with the role it already has',
      );
      expect(spy.reads, 1, reason: 'one capture, one read');
    });
  });
}
