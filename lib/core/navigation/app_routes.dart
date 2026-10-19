/// The route paths this app declares, plus the wildcard the router falls back
/// to. Named constants rather than bare string literals at call sites, because
/// `context.router.pushNamed('/quiz')` is a typo the compiler cannot see and a
/// renamed route cannot find.
///
/// Seven of the paths are locked by AGENT_CONTEXT §2. One more is declared here
/// and not by it — [servant] — and carries its own paragraph saying so, because
/// "the seven" was this file's own headline and a reader who stopped reading there
/// would have believed the eighth route was §2's too.
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

  /// `/result` — score, streak, stat tiles.
  static const String result = '/result';

  /// `/settings` — appearance, reading, about. Local only, never synced.
  static const String settings = '/settings';

  /// `/communion` — the cohort's board over a chosen window.
  ///
  /// ## WHY IT IS A **SEVENTH** ROUTE AND NOT A TAB
  ///
  /// It is pushed, not a destination in the bottom bar, because it is reached from
  /// Home's seal dock / journey and from nowhere else — a tab would promise an equal
  /// place in the app for a screen two of seven screens can reach.
  ///
  /// Behind `_guards` like every screen after `/login`, so it cannot be entered by a
  /// deep link while signed out. See `auth_guard.dart` for what the guard actually
  /// checks — and for why that is a UX gate and **not** an authorisation one.
  static const String communion = '/communion';

  /// `/servant` — where both servant roles land. **Declared, not yet routed.**
  ///
  /// ## WHY IT EXISTS NOW, AND WHAT IT IS NOT YET
  ///
  /// `core/navigation/landing_route.dart` has to name a destination for
  /// `UserRole.viewerServant` and `UserRole.adminServant`, and a function cannot
  /// return a route this file does not declare. So the constant arrives one task
  /// ahead of the screen.
  ///
  /// ## AND IT IS STILL UNREGISTERED — STATED WITHOUT CITING DECISION 5
  ///
  /// **This paragraph deliberately cites no authority, because there is none to
  /// cite.** AGENT_CONTEXT §2 decision 5 (`AGENT_CONTEXT.md:31`, under "Locked
  /// decisions — NOT up for renegotiation") reads "**No servant/admin portal.**
  /// Those backend routes stay untested from the client", so it is the *reason
  /// the registration has not happened yet* and it is emphatically **not** a
  /// permission. An earlier draft of this comment spent one sentence doing both
  /// jobs — promising that "the portal routes themselves are registered in
  /// `app_router.dart` by the task that builds them" and citing decision 5 as
  /// the reason — which is a decision cited in support of the exact thing it
  /// forbids.
  ///
  /// The user has approved amending decision 5, and **that amendment is task 6's
  /// to write.** So the honest position for this file is the two facts that do not
  /// depend on either version of the decision:
  ///
  ///  1. `/servant` is **declared here and not registered in `app_router.dart`**.
  ///  2. **Registering it is task 5's job**, not this file's, and nothing in this
  ///     paragraph is a retroactive justification for the gap either way.
  ///
  /// **The honest consequence, which a reader will otherwise have to discover by
  /// pushing it:** `AppRouter`'s table declares seven routes and then `'*'`, and
  /// none of the seven names this path — so a navigation to `/servant` matches
  /// nothing and the wildcard redirects it to [home]. A servant therefore lands
  /// on `/` today. That is the *correct outcome* for a role with nothing extra to
  /// see, and it is a **coincidence rather than a design**: it is what the
  /// fallback does with an unknown path.
  ///
  /// **Measured, not reasoned:** driving the live matcher on
  /// `AppRouter(FakeAuthStatus(), _SilentAuthChanges())`,
  /// `router.matcher.match('/servant')` yields `name=HomeRoute`,
  /// `path=/`, **`redirectedFrom=*`** — field-for-field identical to
  /// `router.matcher.match('/not-a-route')`. It is *not* identical to
  /// `router.matcher.match('/')`, which yields the same `path` with
  /// `redirectedFrom=null`; the `*` is precisely the evidence that `/servant` is
  /// being handled by the catch-all rather than matched.
  ///
  /// No test in this repository asserts any of it, deliberately: pinning "a path
  /// that is declared but not routed lands on `/`" would ratify a placeholder as a
  /// finished screen, which is recorded decision 8's failure in its purest form.
  /// The probe is therefore cited here and thrown away, and the successor that
  /// registers the portal route replaces this paragraph.
  ///
  /// It is recorded here rather than left to be found because the alternative is
  /// worse. The day this constant is used by something other than
  /// `landingRouteFor`, the reader who has not read this paragraph will believe a
  /// servant screen exists.
  ///
  /// ## WHY IT IS NOT ONE OF THE LOCKED PATHS, AND WHY IT STILL GETS A ROW
  ///
  /// §2 locks **seven** route paths; this is the eighth declaration and now the
  /// **only** one whose value §2 does not fix. It was the second until Task 5.5
  /// moved `/communion` — then `/leaderboard` — into §2's route table, which is
  /// why `app_routes_test.dart` carries a value row for it rather than leaving it
  /// to arrive silently. The row exists so a reader has one place to look for
  /// what each declared path is, not because the value is in doubt.
  ///
  /// ## AND IT IS NOT A PERMISSION
  ///
  /// The backend parses `X-User-Role` at `identity.middleware.ts:24`, assigns it
  /// at `:31`, and never reads it again — see `core/domain/entities/user_role.dart`
  /// for the two zero-match greps that settle it. A route constant is a path in
  /// this client, not an access control on anyone.
  static const String servant = '/servant';

  /// The wildcard catch-all, `'*'`. Unmatched paths redirect through this. See
  /// the file doc for what is and is not true about the value — in particular,
  /// `'/*'` would work too, and `'*'` is here because it is the documented
  /// spelling and because it is the only path without a leading slash.
  static const String fallback = '*';
}
