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
///   lacks one. auto_route 11.2.0 special-cases the literal string `*` in
///   `RouteMatcher._match` and in `matchByPath`'s `fullMatch` guard, and its
///   README documents `RedirectRoute(path: '*', redirectTo: '/')` as the
///   catch-all form. It is a sentinel, not a path, which is why it is named
///   `fallback` and why the test exempts it from the slash invariant.
///
/// Phase 4 note: auto_route matches routes in declaration order, so `*` must be
/// listed last in the router's route list or it swallows every real route.
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

  /// The wildcard catch-all, `'*'`. Unmatched paths redirect through this;
  /// auto_route only recognises the bare asterisk, so `'/*'` would not work.
  static const String fallback = '*';
}
