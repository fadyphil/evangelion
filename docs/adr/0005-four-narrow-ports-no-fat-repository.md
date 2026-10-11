# ADR-0005: Declare four narrow repository ports; a fat repository is forbidden

- **Status:** accepted
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §3, the ISP and DIP rows

## Context

The pre-cut plan proposed `domain/repositories` → `data/{models, datasources,
repositories}` → port, a four-file chain per feature. Under the plan's own default
of local data that chain was a pass-through with two hypothetical files in the
middle. The data source then became a live API, which changes the argument.

## Decision

Four narrow ports, declared in `core/domain/repositories/`:
`ReadingRepository`, `StreakRepository`, `AuthRepository`, `SettingsRepository`.
**A single fat `EvangelionRepository` is forbidden.** Clients depend on the smallest
interface that satisfies them, and every adapter registers **against its port**,
never the concrete class, so no bloc and no page ever names
`DioReadingRepository`.

`leaderboard_repository.dart` states the ISP argument in its own header: `today()`
is a 200 whose body carries verses and questions for one reading, `board()` is a 200
carrying a ranked array whose keys are inconsistent with each other. A client
wanting only a ranking would have to satisfy an interface whose other method names
two types it does not use.

## Alternatives considered

### One `EvangelionRepository` for the whole backend

- **Why not:** it is the ISP row restated. Every client then depends on the whole
  surface, and each new endpoint widens an interface four features already hold.

### Keep the plan's model → data source → repository impl → port chain

- **Why not:** `docs/plans/10-open-decisions.md` §16 gives the argument in its own
  words — "Model → data source → repository impl → repository port is a
  pass-through: deleting the two middle files collapses the chain and no complexity
  reappears at any call site." That was written *under* the local-data premise, and
  §16 records that the premise is gone: `ReadingRepository` and `StreakRepository`
  now each have two justified adapters, one HTTP transport against a real server and
  one deterministic in-memory double that must be substitutable for it under LSP
  (`FakeReadingRepository`, `FakeStreakRepository`, both hand-written for `bloc_test`).

### Introduce a port per data source rather than per concern

- **Why not:** that is the same chain by another route, and it puts a port at the
  file boundary instead of the capability boundary.

## Consequences

### Better

- Substituting a fake is a change to one provider body and nothing else.
  `home_module.dart:96` registers `ReadingRepository get readingRepository =>
  DioReadingRepository(...)` — the port is the return type, and `injection_test.dart`
  asserts the generated text registers the ports and never the concretes, in the
  failing direction.
- Every cubit test is exercising the real seam, so the LSP contract is not a claim
  in a doc but something ~2500 tests depend on.

### Worse

- **Four files that read almost identically, and a fifth.** Each port re-states the
  "never throws, always returns `Result`" contract in its own words rather than
  inheriting it, because nothing in Dart inherits a doc comment across files. The
  cost is drift risk, and it is paid in documentation rather than in code.
- `ReadingRepository` is the widest of the four and has three methods: `today()`
  (`:96`) is defined in terms of the wide `todayScripture()` (`:110`), because two
  implementations of them independently would have two answers for one payload —
  `dio_repositories_test.dart` asserts the delegation in the failing direction.

### Neutral / noted

- **The rule worth keeping from the superseded recommendation:**
  *if a new port ever ends up with a single adapter that nothing substitutes,
  delete it.* `docs/plans/10-open-decisions.md` §16 says this is "now a rule about
  future ports, not a description of the current ones."
- **§3 declares four ports; `lib/core/domain/repositories/` holds five.** The fifth
  is `LeaderboardRepository`, added when the leaderboard feature landed and
  justified by the placement test (ADR-0004). This is a feature arriving after the
  decision rather than a contradiction of it, and it is recorded here rather than
  left for the next reader to discover as a mismatch.
- **`FakeAuthRepository` is the sole adapter for one of the four** and that is
  acceptable — see ADR-0002 and `docs/plans/10-open-decisions.md` §15's corollary.

## Traceability

- `AGENT_CONTEXT.md` §3, SOLID table, ISP and DIP rows; "Feature independence"
- `AGENT_CONTEXT.md` decision 49 (`ReadingRepository` has two methods and the wide one is the port)
- `AGENT_CONTEXT.md` decision 89 (`/quiz` has no data layer, and that is why the port has three methods)
- `docs/plans/10-open-decisions.md` §16, "Why it was made" and "Resolution"
- `docs/plans/10-open-decisions.md` §15, the adapter table
- `lib/core/domain/repositories/leaderboard_repository.dart:40`, the fifth port and its ISP argument
- `lib/app/di/modules/home_module.dart:96`, a port-typed registration
- [`docs/SEAMS.md`](../SEAMS.md) Seam 3, for the full data path
