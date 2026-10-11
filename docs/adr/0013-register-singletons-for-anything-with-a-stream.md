# ADR-0013: Register singletons for anything holding a stream; the router is a lazy singleton

- **Status:** accepted
- **Date decided:** 2026-10-03
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` recorded decisions 10, 17

## Context

Every bloc and cubit in this client is hand-registered rather than generated
(ADR-0012), which means each registration is a line someone wrote and each can be
given the wrong lifetime. Two lifetimes in this graph are load-bearing, and **both
were learned by getting them wrong first** — the trap is that neither failure looks
like a failure at the call site.

## Decision

**`registerSingleton`, never a factory, for anything holding a stream.** Six
registrations: `AuthBloc`, `HomeBloc`, `ReadingCubit`, `LeaderboardCubit`,
`QuizBloc`, `SettingsCubit` — plus `SettingsHandle`, which is a closure pair over
`SettingsCubit` and so has the same hazard.

A `@factory` here would hand out a **second** bloc with its own state and its own
stream, subscribed to by nothing. The reader would interact with whichever instance
their widget happened to resolve; the one holding the answer would be the other one.
**`QuizBloc` is where that stops being a subtlety.** `QuizState.lastResult`
(`quiz_bloc.dart:260`) is the only holder of the submit response in the process
(ADR-0015), so a second `QuizBloc` would leave `/result` permanently unbuildable — a
reader who answered three questions and pressed "See results" would arrive nowhere.
`ReadingCubit` is the next worst: it holds the reader's font step for the life of the
cubit, so a second instance is a second reading preference.

**`AppRouter` is a `registerLazySingleton`,** and the reason is sharper than the
others: a get_it `@factory` guarantees the exact hazard `06-navigation.md` §8 warns
about in the same breath. Every lookup hands back a **new** router, only one of
which is the one `app.dart` mounted, and any other caller — a test, a future
screen, a debug tool — gets an object carrying **its own `navigatorKey` and no
`Navigator` behind it**. Nothing about either object looks wrong; the failure is
that navigations go nowhere.

The dependence on the lifetime is **visible in the shape of the statement**:
`app.dart` reads the locator once, in `build` —
`final AppRouter router = getIt<AppRouter>();` (`lib/app/app.dart:220`) — rather
than behind a helper that would hide the fact that this lookup is expected to
return the *same* object every time.

`registerSingleton` rather than `registerLazySingleton` for the six blocs is itself
a choice: the object is **already built** by the time it is registered, so there is
no factory to re-run, and a lazy registration would add a re-entrancy shape for no
gain.

## Alternatives considered

### `@injectable` with a generated `registerLazySingleton`

- **Why not:** it would still be a factory under the hood, and the five-or-six hits
  at this wall are all in `flutter_bloc` rather than in the lifetime. ADR-0012
  records the generation half; this ADR is about what the hand-written half does.

### A `@factory` for `AppRouter`, which is what `06-navigation.md` §8 words

- **Why not:** recorded decision 10 calls this a deliberate divergence from the
  plan. The plan's own sentence is the warning — "do not instantiate it as a field
  in `app.dart`, or a second `AppRouter` with a stale bloc will exist alongside the
  injected one" — and a `@factory` does not avoid that, it *guarantees* it on every
  lookup. The intent is met; the mechanism is the one get_it offers.

### A `get_it` scope per route so two routers could coexist

- **Why not:** it would make the hazard a supported state rather than an impossible
  one. There is one navigator in this app.

## Consequences

### Better

- **The singleton choice is mutation-checked rather than asserted.** Rewriting the
  router's registration to a factory turns exactly the identity assertions in
  `navigation_injection_test.dart` red, and the failure prints **two routers with
  identical `toString`** — which is the whole difficulty of the bug, because there
  is nothing in either object to look at.
- **`SettingsCubit` is a singleton for a reader-visible reason.** It holds the
  reader's palette, language and font size; a second instance would be a second set
  of choices, and `app.dart` resolving a different cubit from the one `/settings`
  wrote would show a toggle that springs back.

### Worse

- **`AppRouter` cannot be reset between tests without rebuilding the graph.** It is
  the one registration whose lifetime is a singleton rather than a singleton-eager,
  which is the right trade for the app and a real cost for the suite — the reason
  `navigation_injection_test.dart` exercises it as behaviour (presence, lifetime,
  identity) rather than by inspecting the source.

### Neutral / noted

- **The registration order in `configureNavigation` is readability, not
  correctness.** All of `AuthStatus`, `ReevaluateListenable` and `AppRouter` are
  `@lazySingleton`, so nothing runs during the function. The real requirement is
  that `bootstrapApp` calls `configureDependencies()` before
  `configureNavigation()` (`lib/app/bootstrap.dart:78-79`), and that ordering is
  asserted in the failing direction — ADR-0012.
- **Getting that order wrong has a measured cost, not a hypothetical one:**
  re-binding `AuthStatus` after the router exists leaves the router holding the
  previous one, because it captured the seam at construction. `app_router.dart`
  takes `AuthStatus` and `ReevaluateListenable` as constructor parameters
  (`navigation_injection.dart:256-258`), which is what makes that capture visible
  at the call site.

## Traceability

- `AGENT_CONTEXT.md` recorded decision 17 (`registerSingleton` and *why* a factory
  re-run is the stale-bloc hazard), decision 10 (`lazySingleton` for `AppRouter`
  and the divergence from `06-navigation.md` §8)
- `AGENT_CONTEXT.md` §5 trap 11 (why `QuizBloc.lastResult` is the only holder of
  the submit response — the stake behind the singleton)
- `lib/app/di/navigation_injection.dart:170` and its six per-bloc sections;
  `:252-258` (`ReevaluateListenable`, `AppRouter` registration)
- `lib/app/app.dart:220`, `lib/app/bootstrap.dart:68-80`
- `lib/features/quiz/presentation/bloc/quiz_bloc.dart:260,318` (`lastResult` and
  the `QuizCta.none` arm)
- `docs/plans/06-navigation.md:105` (the plan wording this diverges from)
- [`docs/SEAMS.md`](../SEAMS.md) Seam 2 ("Two lifetime traps, both learned the hard way")
- ADR-0012 (why these are hand-written at all)
