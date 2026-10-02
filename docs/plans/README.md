# Evangelion — Flutter Port Plan

Port the Figma Make React prototype in `eva/` into a production Flutter app as **37 reusable widgets** over a feature-first clean architecture, fixing **12 verified defects** in the process.

> **For agentic workers:** REQUIRED SUB-SKILL: use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan phase-by-phase. Every phase ends with `flutter analyze` clean and its widget tests green before the next phase starts.

> **Authority.** [`docs/agents/AGENT_CONTEXT.md`](../agents/AGENT_CONTEXT.md) is pasted verbatim into every sub-agent dispatch and **overrides every document in this folder**. If anything here disagrees with it, it is wrong and must be fixed here, not there. The scope below is stated for the same reason — read `AGENT_CONTEXT` §2 before reading anything else.

**Goal:** 37 reusable widgets over `features/{auth,home,reading,quiz,result,settings}` — one folder per shipped screen — each owning `domain` (pure Dart, zero Flutter imports) + `data` + `presentation`, with a shared `core/` design system.

**Architecture:** Feature-first clean architecture. Dependency direction is strictly inward: `presentation → domain ← data`. No feature may import another feature; shared UI lives in `core/design_system`.

**Tech stack:** Flutter 3.47.4 / Dart 3.13.3 · `flutter_bloc 9.1.1` · `equatable 3.0.0` · `auto_route 11.2.0` + `auto_route_generator 10.6.0` · `build_runner 2.16.1` · `get_it 9.3.0` + `injectable 3.0.0` · `dio 5.11.1` · `google_fonts 9.0.0` · `mocktail 1.0.5` · `bloc_test 10.0.0` · `shared_preferences`

---

## Locked decisions

Decided with the user. They are **not** revisited in this plan. The first three were made when the plan was written; the rest were settled afterwards and are recorded in [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, which is the authoritative list.

1. **Port the *built* React code's visual language** — dark glassmorphic, DM Sans, glows, `NeuralBackground` — **not** the flat warm-paper brief in `eva/src/imports/pasted_text/pasted-attachment.txt`. The two contradict each other; the brief explicitly bans the gradients, blur, and glows the generated code shipped.
2. **BLoC/Cubit + `auto_route`.**
3. **Full clean architecture**, all layers.
4. **Six screens. Library and Profile are cut.** No passage library, no category system, no reflection history, no user profile ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 1). Six routes, no `:passageId`, because the passage is always *today's* and the backend has no `GET /readings/:id`.
5. **Live API**, not local JSON. `http://localhost:3000`, prefix `/api/v1`, for reading / quiz / result / streak. The pre-cut plan's "bundled JSON corpora" default is withdrawn — see [§15](10-open-decisions.md#resolved), decision #1.
6. **Login is UI-only.** `FakeAuthRepository` returns a seeded session; there is **no auth endpoint on the backend** and no login call. **Settings are local only** (`shared_preferences`), with no server sync. **No servant/admin portal.**
7. **Dark glassmorphic design system** per [03-design-system.md](03-design-system.md) §5, including the five mandatory performance mitigations in [09-quality-gates.md](09-quality-gates.md) §13.

---

## Reading order

Start at **01** if you have never seen the prototype. Start at **08** if you are picking up work mid-flight.

| # | File | What it answers | Contains |
| --- | --- | --- | --- |
| 01 | [Source analysis & defects](01-source-analysis.md) | What is this prototype, and what is broken in it? | §1, §2 |
| 02 | [Architecture](02-architecture.md) | How do the layers fit, and which seams carry the leverage? | §4 |
| 03 | [Design system](03-design-system.md) | What are the tokens, fonts, and motion values? | §5 |
| 04 | [Widget inventory](04-widget-inventory.md) | Which 37 widgets exist, and what duplication does each collapse? | §3, §6 |
| 05 | [Domain model](05-domain-model.md) | What are the entities and use cases? | §9 |
| 06 | [Navigation](06-navigation.md) | How do the 6 routes, the auth guard, and transitions work? | §8 |
| 07 | [File map](07-file-map.md) | Which files get created, and where does each one live? | §7 |
| 08 | [Build phases](08-build-phases.md) | In what order do I build this? | §10 |
| 09 | [Quality gates](09-quality-gates.md) | How is it tested, kept fast, and made accessible? | §11, §13, §14 |
| 10 | [Open decisions](10-open-decisions.md) | What is still undecided? | §15, §16 |

Section numbers are preserved from the original single-file plan, so `§13` still means §13 regardless of which file you are in.

> **Archive.** [`archive/widget-plan.original.md`](archive/widget-plan.original.md) is the pre-split 1,531-line file, kept as a record of the review and revision that produced this set. It is superseded — do not implement from it. It still describes the pre-cut scope, and its phase numbers no longer match [08-build-phases.md](08-build-phases.md).

---

## The four things that matter most

1. **The prototype contradicts its own brief.** See [§1.2](01-source-analysis.md#12-brief-vs-built-code-diverge-sharply). The Figma agent shipped a design the brief explicitly bans. We port what was built, but you should know `NeuralBackground` is a departure, not a spec.
2. **12 real defects, not 12 independent bugs.** They collapse to two root causes — no state layer and no design-system layer — which is why Phase 1 and Phase 5 are load-bearing. See [§2](01-source-analysis.md#2-verified-defects-and-their-fixes). One of the twelve (the no-op category filter) is now resolved by cut rather than by a fix.
3. **The screens duplicate each other heavily.** 6 screen scaffolds, 8 blur surfaces, 4 icon buttons, and 2 ~90%-identical reading screens collapse into 4 widgets and 1 page. See [§3](04-widget-inventory.md#3-duplication-inventory).
4. **`NeuralBackground` is the performance trap.** It re-renders 60×/sec forever in the prototype, and `BackdropFilter` is a `saveLayer` per card. Both have mandated fixes. See [§13](09-quality-gates.md#13-performance).

---

## Not decided yet

Two things are still open, both tracked in [§15](10-open-decisions.md#15-open-decisions): whether the FAB Language item is a bottom sheet or a route (decision #2, default bottom sheet), and whether `Notifications` is real or a stubbed toggle until a push backend exists (decision #3, default a persisted stub).

**§16 is resolved, not pending.** [§16](10-open-decisions.md#16-recommended-architecture-change--superseded) recommended collapsing the 3-layer data tier into 2 real ports plus one deep `ScriptureCatalog`. That recommendation is **void**. It was made under the premise that data would be local; resolving the data-source question to the **live API** removed the premise, because `ReadingRepository` and `StreakRepository` each now have two genuinely different adapters — HTTP in production and a deterministic in-memory double under test. The four ports stand exactly as specified, and a single fat `EvangelionRepository` is forbidden.

The data-source question itself — local JSON vs live API — is **no longer open**: it resolved to the live API. It keeps decision number **#1** so that existing references to "#3" keep pointing at the notifications question.
