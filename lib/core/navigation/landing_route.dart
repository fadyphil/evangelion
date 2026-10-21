import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';

/// The ONE place a [UserRole] turns into a route path.
///
/// ## WHY ONE FUNCTION AND NOT TWO CALL SITES
///
/// **The first call site has arrived** — the login result handler, which lands
/// a reader who has just signed in on the route their **role** owns. The
/// second — the cold-launch target, a process that already holds a session
/// deciding its first route from the same role — has **not**, and that is
/// stated first because the argument below is about the future.
///
/// What is *not* deferred is the function — the value it computes is fixed,
/// testable, and worth fixing now precisely because the two call sites will
/// arrive **separately**, and a separation is what lets them drift.
///
/// Two moments in this app will have to answer "where does this reader land?",
/// and they are **the same question**:
///
///  * **the login result handler** — the reader signs in, `AuthBloc` reaches
///    `signedIn`, and the page lands them on `landingRouteFor(session.role)`.
///    **This is the call site that exists.** It lives in
///    `features/auth/presentation/pages/login_page.dart`'s
///    `_LoginFormState._landOnOwnRoute`, and the doc there carries the
///    measurement that says how it and the guard's resume interact;
///  * **the cold-launch target** — a process that already holds a session has to
///    decide its first route from the same role. **Not yet.** It is out of scope
///    for the portal's navigation task, and this paragraph is the receipt that
///    it was deliberately left out rather than forgotten.
///
/// A second place computing a landing route is how a role and a screen drift
/// apart: the login path grows a fourth role arm, the cold-launch path does not,
/// both compile, and the reader who signs in on one platform and cold-starts on
/// another lands on two different screens for the same role. This function is the
/// single source both call, which is also the argument for the **exhaustive**
/// `switch` below rather than a table anyone can extend.
///
/// ## ADVISORY UX, NOT A BOUNDARY — THE SAME ANSWER [RoleAccess] GIVES
///
/// Choosing where a reader lands is a **product** decision, and this function is
/// where it is written down so there is one of it. It is not access control and
/// nothing downstream treats it as such: the backend parses `X-User-Role` at
/// `src/middleware/identity.middleware.ts:24`, assigns it at `:31`, and never
/// reads it again, so
/// `rg 'user\??\.role' src/` and `rg '403' src/` both return **no matches** across
/// all **seventeen** route registrations (`core/domain/entities/user_role.dart`
/// has the full measurement). A reader who reaches a path by hand reaches
/// whatever is registered there.
///
/// The one honest caveat, and it is a real one: [AppRoutes.servant] used to be
/// **declared but not routed** — no `AutoRoute` in `app_router.dart` named it,
/// so a servant landed on [AppRoutes.home] through the `'*'` wildcard.
/// **Measured** through the live matcher rather than reasoned:
/// `router.matcher.match('/servant')` yielded `name=HomeRoute`, `path=/`,
/// **`redirectedFrom=*`** — identical field-for-field to
/// `router.matcher.match('/not-a-route')`, and **not** to
/// `router.matcher.match('/')`, whose `redirectedFrom` is `null`. The `*` is the
/// evidence that the wildcard handled the path rather than any route matching it.
///
/// **That state is over.** The four portal routes are registered in
/// `app_router.dart` now, and `/servant` names `ServantRoute`. The measurement
/// is kept because it is the receipt for the shape a *declared but unrouted*
/// path has, and because the same probe is what tells a reader that a path is
/// *routed* rather than *declared*.
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
