# ADR-0004: Put types two or more features consume in the shared kernel

- **Status:** accepted
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §3, "Shared kernel"

## Context

Six screens read the same handful of types. Without a shared kernel,
`features/home`, `features/reading` and `features/quiz` would each need their own
`ReadingRepository`, which forces cross-feature imports and trips Gate 2 — and a
gate failure is a design signal here, not noise to be suppressed.

## Decision

**Placement test: used by exactly one feature → that feature's `domain/`. Used by
two or more → `core/domain/`. Nothing enters `core/domain/` speculatively.**

`core/domain/` holds the four declared ports plus the entities two or more screens
read, and it is **pure Dart** — no Flutter, no Dio. `features/<f>/domain/` holds
only that feature's own use cases, which depend on the ports from `core/domain/`.

The test is applied, not assumed. `leaderboard_repository.dart` states its own
reason for living there: `/`'s compact card and `/leaderboard`'s full list read the
same board in the same window, and a port inside `features/leaderboard` would have
to be imported by `features/home`, which §3 forbids with no exceptions.

## Alternatives considered

### Let each feature declare the types it reads

- **Why not:** it is the cross-feature import, and Gate 2 fails on it. There is no
  version of this that does not break the purity gate.

### Promote use cases to `core/domain/` as the "shared" surface

- **Why not:** weighed and not taken. `features/<f>/domain/` holds *this feature's
  own* use cases; `greetingWord` needs `GreetingPeriod`, which the placement test
  puts in `features/home/domain/`, so a shared file of derived strings would make
  the shared kernel feature-dependent. This is §3 that forbids it, not a gate —
  `tool/feature_import_check.dart` skips a path whose owner is neither `features/*`
  nor `core`, and **would not have caught it**.

### Put the ports in `core/domain/` but let blocs name concrete adapters

- **Why not:** that is the seam the whole DI split exists to hold. See ADR-0005.

## Consequences

### Better

- `core/domain/` is provably pure Dart, and Gate 1 proves it rather than asserting
  it — including for the **generated** parts. A part file has no imports of its own,
  so its surface is its host library's, and eleven `.freezed.dart` files live inside
  the pure-Dart directories today (counted 2026-10-11; §7 records ten, written
  before the leaderboard entity landed).
- The placement test is auditable: a type in `core/domain/` is there because a
  second feature reads it, and the reason is usually written in the file.

### Worse

- **A type the kernel does not need is a permanent coupling.** Nothing in
  `core/domain/` may know a feature's name, so the `leaderboardBoard` entity is a
  product type living in the place that is allowed to know about no product types.
- **The kernel is not a place to anticipate.** "Nothing enters speculatively" is a
  rule that reads as an invitation until the first agent treats it as one; the gate
  cannot detect a speculatively-placed type, because the type is genuinely
  dependency-free.

### Neutral / noted

- **`injection_test.dart` asserts the generated DI config against the `@module`
  files in both directions**, so adding a provider without re-running `build_runner`
  is a failing test rather than a silently stale committed file — the check at
  `injection_test.dart:527` (the config registers nothing the modules do not
  declare) and its counterpart at `:551` (a provider added without regenerating is
  caught).
- **A recorded claim that has rotted: "the six `@module` files are committed and
  empty"** (recorded decision 11, a Phase 4 statement). Measured 2026-10-11: there
  are **eight** files in `lib/app/di/modules/` — `auth_`, `core_`, `home_`,
  `leaderboard_`, `quiz_`, `reading_`, `result_`, `settings_module.dart` — and
  **most carry providers**; only `result_module.dart` has none. The *property* the
  decision was about is intact and asserted both ways; the count and the adjective
  are not. `result_module.dart:29` still records why an empty `@module` is correct
  there, and `settings_module.dart:12` records the same history for a file that was
  empty until Phase 9.

## Traceability

- `AGENT_CONTEXT.md` §3, "Shared kernel — `core/domain/`" and the placement test
- `AGENT_CONTEXT.md` decision 25 (`home` re-declares `GetCurrentSession` over the shared port, and why that duplication is the accepted price of §3)
- `AGENT_CONTEXT.md` decision 102 (Gate 2 would not have caught a feature-dependent shared file)
- `AGENT_CONTEXT.md` decision 100 and decision 156's audit, for the generated parts
- `AGENT_CONTEXT.md` recorded decision 11 — and its count is stale, as noted above
- `lib/core/domain/repositories/leaderboard_repository.dart`, for the placement test applied
- `test/app/di/injection_test.dart:527,551`
