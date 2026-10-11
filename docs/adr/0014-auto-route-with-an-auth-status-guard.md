# ADR-0014: Route with auto_route behind a guard over a one-member `AuthStatus`

- **Status:** accepted
- **Date decided:** 2026-10-03
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` recorded decisions 9, 10, 12, 13

## Context

`docs/plans/06-navigation.md` §8 specifies an `AuthGuard` that takes `AuthBloc` and
redirects to `LoginRoute(onResult:)`. Recorded decision 9 records why neither
existed when routing was built: the plan's own verification for that phase — "pushes
`/` unauthenticated and asserts it redirects to `/login`" — **is unwriteable
without something that can be unauthenticated**, and pulling a half-built `AuthBloc`
forward would have made the routing phase the owner of auth state it cannot define.

## Decision

**The guard depends on `AuthStatus` — one member, `bool get isAuthenticated`, in
`lib/core/navigation/auth_status.dart` (pure Dart) — not on `AuthBloc`.**
`AuthBloc` arrived in the next phase and changed nothing here.

### Four contracts, each load-bearing

1. **`isAuthenticated` is a pure read.** Cheap, no fetch, no validation, never
   async. The guard calls it on **every navigation and again on every stack
   re-evaluation**, so a value that had to be awaited turns a redirect into a
   loading state.

2. **It must not throw, and the guard deliberately does not catch one.** A throw
   escapes `onNavigation`, the router builds nothing, and on a cold launch that is a
   **blank first frame**. Catching it would be worse than either: on a guard that is
   explicitly **not a security boundary** — there is no auth endpoint; identity is
   three headers the client sets and nothing checks them — failing closed *silently*
   is indistinguishable from a genuine logout, with nothing in the log. So the error
   is left to reach `FlutterError.onError`, which is what makes the blank frame
   diagnosable. The repository's rules make the alternative awkward rather than
   forbidden: `analysis_options.yaml:55-56` enables both `avoid_catching_errors` and
   `avoid_catches_without_on_clauses`, so catching here would need an `// ignore:`,
   and decision 13 records that the repository's only suppression was removed in this
   phase's review for exactly that reason. `auth_guard_test.dart` asserts both halves
   — that `decide()` throws, and that `router.stack` is empty afterwards.

3. **The router's provider reads `AuthStatus` at construction**, so re-binding it
   afterwards is **not** a live update. `AppRouter` takes the seam as a constructor
   parameter (`navigation_injection.dart:252-258`), and
   `navigation_injection_test.dart` asserts the re-binding case in the failing
   direction. The deeper half of this contract is that the implementation must not
   *cache* the answer: freezing it at construction left all 1200 tests green at the
   time, and the measured cost was that a reader who signed in landed back at the
   guard's stale `false` with `HomePage` never built.

4. **The change signal is replaced, not extended.**
   `ReevaluateListenable.stream(authBloc.stream)`, so a sign-out re-evaluates the
   whole stack. The placeholder it replaced is **pinned behaviourally — it must
   announce *nothing***, because a placeholder that fires is the wrong shape to copy.

### The latch is a local, not a field

`NavigationResolver` may be completed **exactly once**. auto_route asserts
`!isResolved` — `auto_route_guard.dart:211`, assertion text literally *"Make sure
`resolver.next()` is only called once"* — so a second completion is an unhandled
`AssertionError` in debug and a `StateError: Future already completed` in release.
**`AuthGuard` therefore latches inside `_redirectToLogin`**, as a local `var
resumed` rather than a field on the guard: `AppRouter._guards` allocates a **fresh
guard per route per read of `routes`**, so an instance field would be forgotten
immediately. `auth_guard_test.dart` calls the callback three times and asserts
nothing escapes.

### Two deliberate divergences from the plan

- **`routerConfig(reevaluateListenable:)` belongs on the `RouterConfig`, not on
  `MaterialApp.router`,** which has no such parameter
  (`app.dart:69-72`; `docs/plans/06-navigation.md:103` words it as "in
  `MaterialApp.router`"). The plan's sentence describes an intent that cannot be
  expressed as written; the intent is met by `AppRouter.config(reevaluateListenable:)`
  (`app_router.dart:187-210`), which is what gets handed to `MaterialApp.router`.
- **`AppRouter` is a `lazySingleton`, not the plan's factory** — see ADR-0013.

`LoginResultCallback` carries a `LoginOutcome` **enum, not a `bool`** (decision 13):
`onResult(didLogin: true)` is the same hazard as `onResult(true)`, and two callbacks
would make "which one resumes?" a weaker statement than "this one resumes" — which is
the reading the latch depends on.

## Alternatives considered

### A `bool Function()` seam instead of an interface

- **Why not:** `get_it` resolves by type, and every `bool Function()` in the app
  would satisfy one registration, so the graph could not say *which* answer it was
  holding.

### Catch the throw and redirect to `/login`

- **Why not:** indistinguishable from a logout, on a guard that protects navigation
  flow and nothing else. The guard "must not grow a role check, a token validation
  or a refresh — those would be theatre that reads as defence."

### Extend the placeholder change signal instead of replacing it

- **Why not:** `_NoAuthChanges` announced nothing, and the rule is that a guard
  re-runs the whole stack on a session change. A signal that can also be told to fire
  for another reason is the shape whose second caller nobody finds.

## Consequences

### Better

- **The guard is three screens' worth of redirect logic that never imports auth.**
  `core/navigation/` is one of the directories `verify_purity.sh` Gate 1 holds to no
  Flutter, and the guard — which must live in `lib/app/` because it names
  `LoginRoute` — is not the thing keeping it honest.
- **`AppRouter` overrides `config()` rather than being handed observers at two call
  sites**, because `RootStackRouter`'s default is `const []` and
  `AutoRouteAwareStateMixin` guards on `if (_observer != null)` — so the whole
  re-entry mechanism was a **silent no-op** and `/` never re-loaded on return. That
  is `docs/SEAMS.md` Seam 5, and "the whole defect was a default nobody overrode."

### Worse

- **The blank-first-frame failure mode cannot be asserted at the widget level**, and
  `auth_status.dart` says why rather than claiming otherwise: a throw escaping the
  guard arrives as an **uncaught zone error**, which `flutter_test` reports by
  failing the test outright and `tester.takeException()` returns `null` for. So the
  honest assertion is the two that *can* be made — `decide()` throws, and
  `router.stack` is empty afterwards — and the rest is marked measured, not asserted.

### Neutral / noted

- **`reevaluateNext: false` on both branches is documented as unpinned.** Both `true`
  and `false` were tried against `auth_guard_test.dart` and both leave it green,
  because every navigation in the shipped app resumes a **single** route, which has
  no pending siblings. The distinction is a property of multi-route navigations and
  there is no production call site for one yet.
- **A `pushAll` crossing the guard leaves one orphan redirect per route**, measured
  and recorded in `auth_guard.dart`'s KNOWN GAP: the stack settles at
  `[LoginRoute, LoginRoute]` with one `LoginPage`, the first `onResult` lands both
  real routes, and the second login redirect is unreachable. The latch makes a second
  call harmless rather than making the orphan reachable.

## Traceability

- `AGENT_CONTEXT.md` recorded decisions 9 (the seam and four contracts), 10 (the two
  divergences), 12 (`NavigationResolver` completes once; the latch is a local), 13
  (the `LoginOutcome` enum and the removal of the `// ignore:`)
- `lib/core/navigation/auth_status.dart` — the four contracts and what each costs
- `lib/app/router/auth_guard.dart` — `decide()`, the latch, the KNOWN GAP
- `lib/app/router/app_router.dart:187-210` (`config()` override), `:243-264` (the
  seven routes plus the wildcard)
- `lib/app/di/navigation_injection.dart:252-258`, `lib/app/app.dart:69-72,220`
- `auto_route_guard.dart:211` in the 11.2.0 pub cache
- `docs/plans/06-navigation.md:103,105`
- `analysis_options.yaml:55-56`
- [`docs/SEAMS.md`](../SEAMS.md) Seam 5
- ADR-0013 (the router's lifetime)
