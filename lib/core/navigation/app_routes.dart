/// The six route paths the app ships, plus the wildcard the router falls back
/// to. Named constants rather than bare string literals at call sites, because
/// `context.router.pushNamed('/quiz')` is a typo the compiler cannot see and a
/// renamed route cannot find.
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

  /// The wildcard catch-all, `'*'`. Unmatched paths redirect through this. See
  /// the file doc for what is and is not true about the value — in particular,
  /// `'/*'` would work too, and `'*'` is here because it is the documented
  /// spelling and because it is the only path without a leading slash.
  static const String fallback = '*';
}
