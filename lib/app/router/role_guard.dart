import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/landing_route.dart';
import 'package:evangelion/core/navigation/role_access.dart';

/// What [RoleGuard] decided about a navigation.
///
/// ## WHY IT IS NOT `AuthGuard`'s `GuardDecision`
///
/// Because the router will import both files, and two enums with one name are
/// an ambiguous import the moment a third file wants either. The names are
/// apart on purpose: the two guards answer two different questions, and a
/// reader of the router's route list has to be able to tell which one they
/// are looking at.
enum RoleGuardDecision {
  /// The reader's role grants the capability. Let the navigation through.
  allow,

  /// It does not. Send the reader to their own landing route.
  redirectToLanding,
}

/// The gate on the servant portal's routes, beside `AuthGuard`.
///
/// ## WHAT IT PROTECTS: AN **ACCIDENT**, NOT AN ATTACK
///
/// [RoleAccess.allows] answers a **UI question** — *"should this screen be
/// offered to this reader?"* — and never a security one, *"may this request be
/// made?"*. The two are not the same question with different words, and the
/// wire settles which one this client can answer: the backend parses
/// `X-User-Role` at `src/middleware/identity.middleware.ts:24`, assigns it at
/// `:31`, and never reads it again, so there is **no server-side answer to the
/// second question** for this client to ask. Every endpoint answers whoever
/// sends a user id.
///
/// So a passing `allows` means *"this screen was chosen sensibly for this
/// reader"*, never *"this reader is allowed to be here"*. What the guard buys
/// is that a child is not dropped onto a scheduling screen that makes no sense
/// for them, and that a viewer servant is not shown a control that reports
/// nothing. It buys no property an attacker would have to defeat, because
/// there is nothing on the server to defeat: the header is set by the client,
/// the client is the attacker's own device, and the request succeeds whatever
/// role it claims. `core/navigation/role_access.dart` carries the whole
/// measurement; this file repeats the shape of it and not the whole of it.
///
/// ## WHY IT REFUSES BY **REDIRECTING** RATHER THAN BY THROWING
///
/// For `AuthGuard`'s recorded reason: a throw escapes `onNavigation`, the
/// router builds nothing, and a cold launch gets a blank first frame with no
/// route underneath to navigate away from.
///
/// And a refusal needs a **destination**, because a refusal is a decision
/// about a screen and a decision has an outcome. The destination is the
/// reader's own landing route — `landingRouteFor`, the one place in this
/// client where a role becomes a path — so a kid who is refused lands on the
/// reader's app, and a viewer servant who is refused lands on the portal's
/// hub, which is the only page they were ever going to be offered anyway. A
/// generic "go home" would have sent a servant out of the portal they were
/// working in.
///
/// ## AND IT DOES NOT CATCH A THROWING SEAM
///
/// [RoleAccess] says an implementation MUST NOT throw, and says what happens
/// when one does: the error escapes `onNavigation` and reaches
/// `FlutterError.onError`, which is what makes it diagnosable. This file
/// catches nothing — `analysis_options.yaml` enables `avoid_catching_errors`
/// and `avoid_catches_without_on_clauses`, and `AuthGuard` deliberately does
/// not catch either.
///
/// Absorbing it would also be the **wrong** answer twice over. A `try`/`catch`
/// here would answer `false` for a role the app simply could not read, and a
/// silent `false` is indistinguishable from a real refusal: the reader is sent
/// to their landing route and nothing anywhere says why. §7's rule that a gate
/// has to be able to fail applies to a decision as much as to a check.
///
/// ## AND IT DOES NOT CACHE ITS ANSWER
///
/// [RoleAccess] is a **reader**, not a mirror: it answers from whatever the
/// app currently believes, on every call. The role is chosen on the login
/// screen, so it changes — a guard that remembered its first answer would keep
/// allowing a capability the reader has since lost, and would keep refusing
/// one they have since gained. `decide()` asks the seam every time.
///
/// ## AND THE ROLE IS READ TWICE, WHICH IS THE SEAM'S OWN LIMIT
///
/// `decide()` asks `allows` — which reads the role — and the landing path
/// asks the role again. `role_access.dart` records that a seam built on a
/// reader guarantees liveness and not atomicity: two reads can be handed two
/// roles if the app emits in between, and it names the remedy for a guard that
/// must reason about one reader consistently.
///
/// The consequence here is bounded and worth naming rather than leaving
/// implicit: a refusal computed against one role can send the reader to
/// another role's route. Both candidates are a valid landing route for some
/// role, and the landing navigation re-reads the role, so the reader ends up
/// somewhere that is theirs. The alternative — capturing the role once and
/// reading the grant table directly — would mean the guard stopped asking the
/// seam the question the seam exists to answer, and `role_access.dart` says
/// out loud that this guard is that seam's consumer.
///
/// ## AND THE REDIRECT **REPLACES** RATHER THAN STACKS
///
/// `replacePath` and not `pushPath`, because the landing route is a **start**
/// and not a step. A `pushPath` would leave a second copy of the reader's own
/// landing route on the stack whenever they were already there, and the back
/// arrow would go from `/` to `/`. The cost of the replace is that the page
/// the reader was on is taken with it — stated here rather than discovered
/// later.
class RoleGuard extends AutoRouteGuard {
  /// Gates a navigation on whether the reader's role grants [_capability].
  const RoleGuard(this._access, this._capability);

  /// The seam this guard asks. A reader, never a copy of a role.
  final RoleAccess _access;

  /// The capability the guarded route needs.
  final UserCapability _capability;

  /// The guard's decision, as a value.
  ///
  /// Split out of [onNavigation] so the branch can be exercised without a
  /// `Navigator`, which is the only part of this class that is genuinely pure.
  /// The round trip it drives is exercised end to end where the routes that
  /// carry this guard are registered.
  RoleGuardDecision decide() => _access.allows(_capability)
      ? RoleGuardDecision.allow
      : RoleGuardDecision.redirectToLanding;

  /// Where a refused navigation sends the reader.
  ///
  /// The reader's own landing route, and therefore the reader's own app: `/`
  /// for a child, the portal's hub for either servant role. Read from the
  /// seam rather than spelled out here, so the guard and the sign-in path
  /// cannot land the same role on two different screens.
  String get landingPath => landingRouteFor(_access.role);

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    switch (decide()) {
      case RoleGuardDecision.allow:
        resolver.resolveNext(true, reevaluateNext: false);
      case RoleGuardDecision.redirectToLanding:
        _redirectToLanding(resolver, router);
    }
  }

  /// Aborts the refused navigation and puts the reader on their landing route.
  ///
  /// `reevaluateNext: false` on the abort, for `AuthGuard`'s reason: the
  /// pending routes of the same navigation event belong to a navigation that
  /// is not happening, and re-pushing them would carry the refusal into a
  /// second route.
  void _redirectToLanding(NavigationResolver resolver, StackRouter router) {
    final String path = landingPath;

    resolver.resolveNext(false, reevaluateNext: false);
    unawaited(router.replacePath<void>(path));
  }
}
