/// The route paths this app declares, plus the wildcard the router falls back
/// to. Named constants rather than bare string literals at call sites, because
/// `context.router.pushNamed('/quiz')` is a typo the compiler cannot see and a
/// renamed route cannot find.
///
/// AGENT_CONTEXT §2 locks **eleven** route paths, and this file declares
/// **eight** of them today: the seven it has always locked, plus [servant],
/// which the 2026-10-21 amendment to decision 5 gave a row (ADR-0026). The
/// wildcard `'*'` is the ninth declaration and is a sentinel rather than a
/// path. The three `/servant/*` sub-routes are §2's too, and they arrive in
/// this file with the portal's own implementation — `tool/route_check.dart`
/// reads this file's declarations, so a constant that is not here is not a
/// route the structural invariants apply to.
///
/// ## THE THREE TAB PATHS ARE **DERIVED**, NOT DECLARED, AND THAT IS THE POINT
///
/// [homeTab], [communionTab] and [journeyTab] are the three paths of the dock
/// shell's children, and auto_route rejects a child path that begins with a slash
/// (`RouteCollection.fromList` throws `Sub-paths can not start with a "/"`), so
/// they are **relative** while the URLs they produce are **absolute**: the shell
/// owns the `/`, and `/communion` is the shell's `/` plus `communion`.
///
/// So the relative path is **derived from the absolute one** rather than written
/// a second time. A second literal would be two sources of truth for one value,
/// and the repository has removed three of those on purpose (AGENT_CONTEXT
/// decision 5, decision 68). These are getters rather than `static const String`
/// on purpose: `tool/route_check.dart` enumerates the `static const String`
/// declarations of this file, and a derived path is not one of them — it is
/// covered because the constant it is derived from is.
///
/// PURE DART. `core/navigation` is not `core/domain`, so a `package:flutter`
/// import would be permitted here — but it is not needed, and staying
/// Flutter-free keeps the constants readable from any layer without dragging in
/// a binding. The Phase 4 router, the Phase 5 auth guard and every page's app
/// bar title all read from this one file.
///
/// The values themselves are locked by AGENT_CONTEXT §2. Two of them are worth
/// a note:
///
/// * [home] is `'/'`, not `''`. auto_route treats an empty path as "this
///   route's parent", so `'/'` is the spelling for the app root.
/// * [fallback] is `'*'`, with no leading slash, and is the only path here that
///   lacks one. It is the catch-all form auto_route's README documents
///   (`RedirectRoute(path: '*', redirectTo: '/')`), and it is a sentinel rather
///   than a path — which is why it is named `fallback` and why the test exempts it
///   from the slash invariant.
///
/// ## WHAT IS ACTUALLY TRUE ABOUT THE WILDCARD, BECAUSE BOTH HALVES WERE WRONG
///
/// **TRUE, and load-bearing: `*` must be listed last.** auto_route matches in
/// declaration order, so a `*` at the front swallows every real route and the app
/// opens `/login` for everything. Measured against the full suite: moving
/// `RedirectRoute(path: '*')` to the front turns **46 tests** red.
///
/// **FALSE, and deleted: "auto_route only recognises the bare asterisk, so `'/*'`
/// would not work."** It works. `'/*'` is accepted by the matcher and behaves
/// identically for `/x`, `//`, `''`, `/not-a-route`, `/login/x`,
/// `/deeply/nested/x` and `/LOGIN` — `package:path`'s `split` keeps the leading
/// empty segment, so `p.split('/*')` is `['/', '*']` rather than `['*']`;
/// `matchByPath`'s `parts.length > segments.length` guard therefore admits the
/// extra segment, and `part != '*'` then lets the `*` swallow the rest.
///
/// `'*'` is kept anyway, for two reasons that are about clarity and not about
/// behaviour: it is the spelling auto_route documents, so a reader arriving from
/// the framework recognises it; and it leaves exactly one declared path outside the
/// slash-prefixed set, which is the structural invariant `app_routes_test.dart`
/// holds. The wildcard's *coverage* — the part worth pinning — is executed in
/// `app_router_test.dart` rather than compared as a string.
abstract final class AppRoutes {
  /// `/login` — onboarding and login. Pre-auth, so it is the app's entry point.
  static const String login = '/login';

  /// `/` — home: greeting, streak flame, today's-reading panel.
  static const String home = '/';

  /// `/reading` — the reading sanctuary, English and Arabic.
  static const String reading = '/reading';

  /// `/quiz` — the quiz, with instant per-question feedback.
  static const String quiz = '/quiz';

  /// `/settings` — appearance, reading, about. Local only, never synced.
  static const String settings = '/settings';

  /// The home tab's path **under the dock shell** — the same string without
  /// the root's leading slash, which for `'/'` is the empty string.
  ///
  /// Derived rather than declared, so there is one source of truth for the path
  /// and so that the inventory of declared paths stays a list of **absolute**
  /// URLs. See the file doc.
  static String get homeTab => home.substring(1);

  /// `/communion` — the cohort's board over a chosen window.
  ///
  /// ## IT IS A **TAB**, AND THE DOCK IS WHY
  ///
  /// The redesign's own entry for the board is the five-slot dock
  /// (`eva/redesign.html:706`, `data-r="board"`), and Phase 6's `AutoTabsRouter`
  /// makes it the second of the three real tabs — home, communion, journey.
  /// The path is the shell's `/` plus [communionTab], so the URL is `/communion`
  /// and a deep link to it lands on the board tab.
  ///
  /// Behind `_guards` like every screen after `/login`, so it cannot be entered by a
  /// deep link while signed out. See `auth_guard.dart` for what the guard actually
  /// checks — and for why that is a UX gate and **not** an authorisation one.
  static const String communion = '/communion';

  /// `/journey` — the reader's own journey: the orb, the streak, the rings, the
  /// medals and the account rows.
  ///
  /// ## IT IS A **TAB**, AND THE DOCK IS WHY
  ///
  /// **Locked:** AGENT_CONTEXT §2's table names it, because ADR-0022 restored the
  /// profile ADR-0001 cut and the redesign calls it "Journey"
  /// (`eva/redesign.html:933`).
  ///
  /// **A tab, not a pushed screen.** The redesign's own entry is the five-slot dock
  /// (`eva/redesign.html:702-708`, and the journey tab at `:707`), and Phase 6's
  /// `AutoTabsRouter` makes it the third tab. The path is the shell's `/` plus
  /// [journeyTab], so the URL is `/journey` and a deep link to it lands on the
  /// journey tab.
  ///
  /// **AND THE BACK CHEVRON IT USED TO CARRY IS GONE**, because the reason it
  /// existed is gone with it. The chevron was there because the journey was
  /// **pushed**: a pushed screen on desktop has no system back button, so the
  /// chevron was the way out. The prototype's journey is only ever a tab
  /// (`eva/redesign.html:576-583` — no chevron, a 68px spacer instead) and never
  /// needed one. The board is the prototype's other dock tab and it **does** have a
  /// chevron (`:614`) — it is reached from the journey as well as from the dock.
  ///
  /// Behind `_guards` like every screen after `/login`, so it cannot be entered by
  /// a deep link while signed out.
  static const String journey = '/journey';

  /// `/communion` as a path **under the dock shell** — the same string without
  /// the root's leading slash.
  ///
  /// Derived rather than declared, so there is one source of truth for the path.
  /// See the file doc.
  static String get communionTab => communion.substring(1);

  /// `/journey` as a path **under the dock shell** — the same string without
  /// the root's leading slash.
  ///
  /// Derived rather than declared, so there is one source of truth for the path.
  /// See the file doc.
  static String get journeyTab => journey.substring(1);

  /// `/servant` — the servant portal's hub: the sections this role has.
  ///
  /// ## IT IS A **HUB PAGE**, NOT A TAB SHELL
  ///
  /// A `viewer_servant` has exactly **one** section — the cohort's daily roster
  /// report — and a tab bar holding one tab is chrome for nothing. So `/servant`
  /// is a page whose body is a list of the sections this role has, and it is
  /// registered in `lib/app/router/app_router.dart` beside its three
  /// sub-routes, which are **root-level absolute paths** declared in this same
  /// file rather than children of the hub: auto_route rejects a child path that
  /// begins with a slash (`RouteCollection.fromList` throws `Sub-paths can not
  /// start with a "/"`), and a **page** has no children for a path to be
  /// relative to. The dock shell's three tab paths are relative for the
  /// opposite reason: it is an `AutoTabsRouter`, and [homeTab] / [communionTab]
  /// / [journeyTab] derive their relative halves from the absolute paths they
  /// belong to.
  ///
  /// ## IT IS THE LANDING ROUTE FOR BOTH SERVANT ROLES
  ///
  /// `core/navigation/landing_route.dart` is the one place a `UserRole` turns
  /// into a path: a `kid` lands on [home] and both servant roles land here.
  /// The function was built for exactly this and had **no caller**; the portal
  /// is its first.
  ///
  /// ## WHO MAY OPEN IT — A `kid` MAY NOT, AND A `viewer_servant` MAY NOT
  /// ## SCHEDULE
  ///
  /// The grant table is `UserRole.grantsFor`, and the answers are the ones that
  /// table already gives: `viewer_servant` may read the daily report,
  /// `admin_servant` may also schedule readings and author questions, and
  /// `kid` may do none of it. A `RoleGuard` refuses a navigation whose
  /// capability the role does not grant, and it **refuses by redirecting**
  /// rather than by throwing — `AuthGuard`'s recorded reason, stated in
  /// `core/navigation/auth_status.dart`'s own words. The hub's entries are read
  /// from that same table rather than from an `if` ladder of their own, and so
  /// is the gate's answer (`core/navigation/role_access.dart:288` —
  /// `allows` is `UserRole.grantsFor(role).contains(capability)`), so the
  /// screen and the gate cannot disagree.
  ///
  /// ## AND IT IS NOT A PERMISSION
  ///
  /// The backend parses `X-User-Role` at `identity.middleware.ts:24`, assigns it
  /// at `:31`, and never reads it again — see `core/domain/entities/user_role.dart`
  /// for the two zero-match greps that settle it. A route constant is a path in
  /// this client, not an access control on anyone.
  ///
  /// ## AND IT IS ONE OF §2's LOCKED PATHS NOW
  ///
  /// It was the eighth declaration and the only one §2 did not fix, until the
  /// user **reversed** decision 5 on 2026-10-21 (ADR-0026). §2's route table
  /// carries a row for it and three rows for its sub-routes, and the row exists
  /// so a reader has one place to look for what each declared path is, not
  /// because the value is in doubt — the value was never in doubt:
  /// `app_routes_test.dart` has carried a value row for it since Task 5.5 moved
  /// `/communion` into §2's table, which is why the count in that suite's name
  /// and in its docs was a thing that had to move.
  ///
  /// ## AND WHAT IS TRUE AT **THIS** COMMIT
  ///
  /// The registration and the three sub-route constants land with the portal's
  /// own implementation
  /// (`docs/superpowers/plans/2026-10-21-servant-admin-portal.md`, Tasks 2 and
  /// 5), and this paragraph is written in the present tense of the **finished**
  /// portal rather than of this commit. The two facts that are true **now** are
  /// the two this file can be checked against: the constant is declared here,
  /// and the gate is advisory.
  static const String servant = '/servant';

  /// The wildcard catch-all, `'*'`. Unmatched paths redirect through this. See
  /// the file doc for what is and is not true about the value — in particular,
  /// `'/*'` would work too, and `'*'` is here because it is the documented
  /// spelling and because it is the only path without a leading slash.
  static const String fallback = '*';
}
