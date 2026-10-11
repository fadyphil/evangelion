# ADR-0002: Read from the live API; auth stays UI-only and settings stay local

- **Status:** accepted
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2 decisions 2, 3, 4

## Context

The pre-cut plan defaulted to local data: JSON corpora on disk, a
`ScriptureCatalog`, a `Passage`/`PassageCategory` entity set. Then the backend
existed, and reading it turned out to be the smaller and more honest option. Four
data concerns, four answers, each with a reason rather than a default.

## Decision

| Concern | Source | Seam |
| --- | --- | --- |
| Reading, questions, quiz, result | **live API** at `http://localhost:3000`, prefix `/api/v1` | `ReadingRepository` |
| Streak | **live API** — `GET /streak/summary` | `StreakRepository` |
| Auth | **`FakeAuthRepository`**, seeded session | `AuthRepository` |
| Settings | **local only** — `shared_preferences` (`pubspec.yaml:54`), no server sync | `SettingsRepository` |

There are no bundled corpora, no `ScriptureCatalog`, no JSON asset, and no
`Passage` or `PassageCategory` entity set anywhere in `lib/`. Auth makes no network
call because **there is no auth endpoint on the backend** — identity is an HTTP
header, not a login (§5). Settings never sync because there is no settings
endpoint, so there is no conflict model to design.

## Alternatives considered

### Keep the local-corpus default and the `ScriptureCatalog`

- **Why not:** the whole recommendation built on the premise that the data was
  local. `docs/plans/10-open-decisions.md` §16 calls the per-feature
  model → data source → repository impl → port chain under that premise a
  **hypothetical seam**, quoting the rule: *"One adapter means a hypothetical seam.
  Don't introduce a port unless at least two adapters are justified."* With a live
  API the premise is gone and `ReadingRepository` and `StreakRepository` each have
  two justified adapters.

### Implement a real auth repository once someone might add login

- **Why not:** nothing to implement against. §2 decision 3 is a locked decision and
  §5's endpoint list is the evidence.

### Persist settings server-side for multi-device parity

- **Why not:** no endpoint, and inventing one is a backend change. The backend is a
  read-only sibling project (§8 constraint 2).

## Consequences

### Better

- Every screen has a data source that can be measured against a running server,
  which is why `docs/BACKEND-VERIFICATION.md` exists and §5's traps are stated as
  facts rather than guesses.
- **One adapter for `AuthRepository` is acceptable here and nowhere else.**
  `docs/plans/10-open-decisions.md` §15 puts the distinction exactly: `FakeAuthRepository`
  is the *sole* adapter "because the backend endpoint does not exist yet, which is a
  different situation from inventing a seam around data that could have been local."
  The port is still declared in `core/domain/` and honoured in full, so a
  `DioAuthRepository` can be dropped in later without touching `domain/` or
  `presentation/`.

### Worse

- Six `try` blocks across four repositories have to become `Result` returns by hand.
  Measured today: `lib/features/settings/data/repositories/settings_repository_impl.dart` (2),
  `lib/features/reading/data/repositories/dio_reading_repository.dart` (2),
  `lib/features/reading/data/repositories/dio_streak_repository.dart` (1),
  `lib/features/leaderboard/data/repositories/dio_leaderboard_repository.dart` (1).
- The client inherits every server trap verbatim. Two of them are traps the client
  cannot fix: `text_clean` exists only in the Arabic arm, and `reading_id` is
  date-stamped.

### Neutral / noted

- **§5's endpoint list says four; the client uses five.** The leaderboard endpoint
  is not in §5's "Endpoints this client uses" block, which predates the feature.
  `docs/DRIFT.md` §5 already records "7 routes, 5 endpoints". This ADR does not
  restate §5's count, because it is a count nobody re-checks.
- **No successful submit has ever been observed against a client-reachable
  reading** (§5 trap 10), so every submit fixture in `test/` is a transcription
  from `submissions.service.ts`, not a capture. `test/support/contract_payloads.dart`
  says so in its own header.

## Traceability

- `AGENT_CONTEXT.md` §2 decisions 2, 3, 4
- `AGENT_CONTEXT.md` §5, identity headers and trap 10
- `docs/plans/10-open-decisions.md` §15, "Resolved — Decision #1" and its corollary list
- `docs/plans/10-open-decisions.md` §16, "Why it no longer applies"
- [`docs/BACKEND-VERIFICATION.md`](../BACKEND-VERIFICATION.md)
- `docs/DRIFT.md` §4 and §5
