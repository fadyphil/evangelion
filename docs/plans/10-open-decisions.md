# Open Decisions

What is still undecided, plus the decisions that have since been made.

**Contains §15 §16** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Architecture](02-architecture.md) · [Authority](../agents/AGENT_CONTEXT.md)

---

## 15. Open decisions

| # | Question | Default if unanswered |
| --- | --- | --- |
| 2 | Does the `SealFab` Language item open a bottom sheet or a route? | bottom sheet |
| 3 | Is `Notifications` in scope, or a stubbed toggle until a push backend exists? | stubbed toggle, persisted in settings |
| 4 | Package structure: single package vs. `core/design_system` as a separate pub package? | single package (no publish constraint yet) |

**The numbering gap is deliberate.** Decision **#1** — data source — is no longer open; it is resolved below. Original numbers are kept so that existing references to "#3" keep pointing at the notifications question.

**Decision #3 scope.** The stub is a plain `bool notificationsEnabled` on `UserSettings` ([05-domain-model.md](05-domain-model.md) §9), persisted by `SettingsRepository`. No push backend exists, so there is no permission request, no token registration, and no server-side flag in the model. It ships with the settings feature. The phase it is numbered under is tracked in [08-build-phases.md](08-build-phases.md), which still carries the pre-cut phase numbering and is being renumbered separately — the six screens in [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2 are the authority on what ships, not the phase numbers.

### Resolved

**Decision #1 — data source: the live API.** ~~Local JSON corpora~~ → **live REST API at `http://localhost:3000`**, prefix `/api/v1` ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 2). The `local` default is withdrawn.

What the resolution changes:

| Concern | Source | Seam |
| --- | --- | --- |
| Reading, questions, quiz, result | **API** — `GET /readings/today/{en,ar}`, `POST /readings/:id/submit` | `ReadingRepository` port |
| Streak | **API** — `GET /streak/summary` | `StreakRepository` port |
| Auth | **Fake.** No auth endpoint exists on the backend. | `AuthRepository` port, `FakeAuthRepository` adapter |
| Settings | **Local only** — `shared_preferences`. No settings endpoint, no sync. | `SettingsRepository` port |

Corollaries, so no one re-derives them:

- **No bundled corpora.** There is no local dataset, no `ScriptureCatalog`, no `Passage`/`PassageCategory` entity set, and no JSON asset. Delete any assumption that a scripture file exists on disk.
- **Auth is the only fake.** `FakeAuthRepository` is the *sole* adapter for `AuthRepository` today. The port is still declared in `domain` and still honoured in full, so a `DioAuthRepository` can be dropped in later without touching `domain` or `presentation` — one adapter is acceptable here because the backend endpoint does not exist yet, which is a different situation from inventing a seam around data that could have been local.
- **Settings are local.** No sync, no conflict model, no remote defaults.

---

<a id="16-recommended-architecture-change--not-applied"></a>

## 16. Recommended architecture change — superseded

**Status: RESOLVED. The recommendation below is void. Do not implement it.**

### Why it was made

The pre-cut plan defaulted to local data ([§15](#15-open-decisions) decision #1). Under that premise the per-feature `domain/repositories` + `data/{models, datasources, repositories}` triple was a **hypothetical seam**, which `codebase-design/DEEPENING.md` rules out:

> *One adapter means a hypothetical seam. Don't introduce a port unless at least two adapters are justified. A single-adapter seam is just indirection.*

Model → data source → repository impl → repository port is a pass-through: deleting the two middle files collapses the chain and no complexity reappears at any call site. The recommendation was to collapse the data tier into one deep in-process catalogue plus a handful of genuinely-doubled ports.

### Why it no longer applies

Decision #1 resolved to **a live API**, and that removes the premise. `ReadingRepository` and `StreakRepository` now each have **two justified adapters**:

| Port | Production adapter | Test adapter |
| --- | --- | --- |
| `ReadingRepository` | `DioReadingRepository` | `FakeReadingRepository` (hand-written, `bloc_test`) |
| `StreakRepository` | `DioStreakRepository` | `FakeStreakRepository` |
| `AuthRepository` | `FakeAuthRepository` (no endpoint exists yet) | in-memory fake |
| `SettingsRepository` | `LocalSettingsRepository` (`shared_preferences`) | in-memory fake |

These are not two adapters of the same kind dressed up — one is HTTP transport against a real server, the other is a deterministic in-memory double that must be substitutable for it under LSP ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §3). The seam is real, it is exercised by every cubit test, and deleting it would push transport concerns into the domain layer.

### Resolution

**The four ports stand exactly as specified in [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §3 and [05-domain-model.md](05-domain-model.md) §9.3:** `ReadingRepository`, `StreakRepository`, `AuthRepository`, `SettingsRepository`. **A single fat `EvangelionRepository` is forbidden.** No `ScriptureCatalog`, no `core/catalog/` module, no `packages/scripture` micro-package.

The one thing worth keeping from the original finding is its test: *if a new port ever ends up with a single adapter that nothing substitutes, delete it.* That is now a rule about future ports, not a description of the current ones.
