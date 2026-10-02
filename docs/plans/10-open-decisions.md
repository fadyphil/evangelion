# Open Decisions

What is still undecided, plus the one architecture change recommended but **not** applied.

**Contains §15 §16** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Architecture](02-architecture.md)

---

## 15. Open decisions

| # | Question | Default if unanswered |
| --- | --- | --- |
| 1 | Data source: local JSON corpora, or a live API? The plan assumes local datasources behind repository interfaces so a remote adapter can be added without touching the domain or presentation layers. | local |
| 2 | Does the `SealFab` Language item open a bottom sheet or a route? | bottom sheet |
| 3 | Is `Notifications` in scope, or a stubbed toggle until a push backend exists? | stubbed toggle, persisted in settings |
| 4 | Package structure: single package vs. `core/design_system` as a separate pub package? | single package (no publish constraint yet) |

## 16. Recommended architecture change — NOT applied

This is the one finding from review that was **not** folded in, because it rewrites the data layer rather than fixing a defect. It needs an explicit decision.

### The problem

Open decision #1 defaults to local data. That makes the per-feature `domain/repositories` + `data/{models, datasources, repositories}` triple a **hypothetical seam** for `library`, `reading`, and `quiz` — exactly the case `codebase-design/DEEPENING.md` rules out:

> *One adapter means a hypothetical seam. Don't introduce a port unless at least two adapters are justified. A single-adapter seam is just indirection.*

`PassageModel` → `PassageDataSource` → `PassageRepositoryImpl` → `PassageRepository` is a pass-through. Deleting the two middle files collapses the chain and no complexity reappears at any call site — it fails the deletion test. Measured cost: **20 data files + 6 domain interfaces for what is one JSON decode.**

### The proposed shape

| Concern | Dependency category | Seam | Adapters |
| --- | --- | --- | --- |
| Scripture, passages, questions | in-process (bundled JSON asset) | **none** — one deep `core/catalog/scripture_catalog.dart` | n/a |
| Auth | remote but owned | `AuthRepository` port | `DioAuthRepository` + `FakeAuthRepository` |
| Progress / reflections | local-substitutable | `ProgressRepository` port | `DriftProgressRepository` + `InMemoryProgressRepository` |
| Settings | local-substitutable | `SettingsRepository` port | `LocalSettingsRepository` + in-memory fake |

Every remaining seam has two adapters, so each one earns its keep. `ScriptureCatalog` is genuinely deep — it hides asset loading, JSON decoding, index building, and language fallback behind three methods — and living in `core/` it also resolves a cross-feature dependency that the current plan satisfies with three parallel repositories.

### Trade-off

- **Net effect:** 20 data files → 7. Three repository interfaces → one deep module. Better testability (real ports, swappable adapters).
- **Cost:** if a remote API is genuinely planned, the current uniform shape is more consistent. And `ScriptureCatalog` in `core/` is slightly unusual placement for domain content — the alternative is a `packages/scripture` micro-package, which is overkill at this size.

**Status: awaiting a decision. The plan as written uses the current 3-layer data tier.**
