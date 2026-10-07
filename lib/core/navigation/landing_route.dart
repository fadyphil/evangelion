import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';

/// The ONE place a [UserRole] turns into a route path.
///
/// ## WHY ONE FUNCTION AND NOT TWO CALL SITES
///
/// There are two moments in this app that have to answer "where does this reader
/// land?", and they are **the same question**:
///
///  * **the login result handler** — the reader signs in, `AuthBloc` reaches
///    `signedIn`, and the router resumes the navigation the guard interrupted;
///  * **the cold-launch target** — a process that already holds a session has to
///    decide its first route from the same role.
///
/// A second place computing a landing route is how a role and a screen drift
/// apart: the login path grows a fourth role arm, the cold-launch path does not,
/// both compile, and the reader who signs in on one platform and cold-starts on
/// another lands on two different screens for the same role. This function is the
/// single source both call, which is also the argument for the **exhaustive**
/// `switch` below rather than a table anyone can extend.
///
/// **Neither call site exists yet at this commit.** Nothing in `lib/` calls this,
/// for the same reason `user_role.dart` records about its two conversions: the
/// screens and the role picker that would ask belong to later tasks, and the
/// absence is the task boundary rather than dead code. What is *not* deferred is
/// the function — the value it computes is fixed, testable, and worth fixing now
/// precisely because the two call sites will arrive separately.
///
/// ## ADVISORY UX, NOT A BOUNDARY — THE SAME ANSWER [RoleAccess] GIVES
///
/// Choosing where a reader lands is a **product** decision, and this function is
/// where it is written down so there is one of it. It is not access control and
/// nothing downstream treats it as such: the backend parses `X-User-Role` at
/// `identity.middleware.ts:24`, assigns it at `:31`, and never reads it again, so
/// `rg 'user??\.role' src/` and `rg '403' src/` both return **no matches** across
/// all **seventeen** route registrations (`core/domain/entities/user_role.dart`
/// has the full measurement). A reader who reaches a path by hand reaches
/// whatever is registered there.
///
/// The one honest caveat, and it is a real one: [AppRoutes.servant] is
/// **declared but not routed** — no `AutoRoute` in `app_router.dart` names it
/// yet, so today a servant lands on [AppRoutes.home] through the `'*'`
/// wildcard. **Measured** through the live matcher rather than reasoned:
/// `router.matcher.match('/servant')` returns `['/']`, identically to
/// `router.matcher.match('/')`. That is a placeholder state, not this
/// function's answer, and it is recorded in both files rather than left to be
/// discovered.
///
/// ## WHY A `kid` LANDS ON `/` AND NOT ON A SERVANT SCREEN
///
/// Because a kid is a reader, and the reading lives on `/`. A viewer servant is
/// **also** a reader — `UserRole.grantsFor` gives both servant roles
/// [UserCapability.readOwnReading], [UserCapability.submitQuiz] and
/// [UserCapability.viewCohortLeaderboard] — so sending a servant somewhere they
/// cannot read today's passage would be a strange product, and one the backend
/// would let them do anyway.
///
/// ## WHY AN EXHAUSTIVE `switch` WITH **NO `default` ARM**
///
/// Because a fourth [UserRole] must be a **compile error** rather than a route
/// somebody picked by accident. A `default` arm is the shape that hides this:
/// the new role compiles, lands wherever the author defaulted it, and no test
/// fails because every existing role still routes correctly.
///
/// AGENT_CONTEXT §2.1 records that this project's exhaustiveness is load-bearing
/// rather than stylistic — `Result<T>`'s sealed arms and `ApiErrorMapper`'s
/// `switch` over `DioExceptionType.values` are the recorded gates — and this is
/// the third instance of the same rule in a `switch` expression. §4 makes it
/// mandatory in any case: exhaustive `switch` **expressions** over enums, no
/// `if`-chains for state branching.
///
/// ## AND WHY THE TWO SERVANT ROLES SHARE ONE ARM
///
/// Written `||`-joined so the fact is in the code and not only in this comment:
/// "servant" is one kind of reader, and giving the admin a second landing would
/// make the destination a function of privilege within a role — which is a
/// product decision nobody has taken. Two separate arms would be equally
/// exhaustive and equally compile-safe, so this is a readability choice; the
/// property it states is pinned by `landing_route_test.dart`, which asserts the
/// two roles' landings are equal so a future split has to be a visible act.
///
/// *Rejected: a `Map<UserRole, String>`.* Legal, and worse: a map is extendable,
/// so a fourth role added by insertion would compile with no error anywhere,
/// which is exactly the outcome the exhaustive `switch` exists to prevent.
///
/// PURE DART — `core/navigation/` is held to no Flutter, Dio or http by Gate 1.
String landingRouteFor(UserRole role) => switch (role) {
  UserRole.kid => AppRoutes.home,
  UserRole.viewerServant || UserRole.adminServant => AppRoutes.servant,
};
