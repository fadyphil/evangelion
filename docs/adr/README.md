# Architecture Decision Records

Twenty-two records of the architectural decisions that shaped this client, why
each was taken, and what it cost. Each names the recorded decision in
[`docs/agents/AGENT_CONTEXT.md`](../agents/AGENT_CONTEXT.md) that it came from, so
any claim here can be traced to its source and checked.

## Why this exists

`AGENT_CONTEXT.md` holds 156 numbered decisions in chronological order, nested
under the phase that produced them. That is the right place to *record* a
decision and the wrong place to *find* one: the file is over four thousand lines
long, and reading it end to end to answer "why is `Result<T>` a typedef" is not
a reasonable thing to ask of a new contributor.

These ADRs are a curated index over that record — twenty-two architectural
decisions rather than 156 chronological entries. Each one carries the parts that
are worth keeping when the surrounding chronology is not: the constraint that
forced it, the alternatives that were rejected and why, and the consequences
nobody wanted to admit. The remaining decisions stay in `AGENT_CONTEXT.md`.

**These are backfills, with one exception.** Every one but ADR-0022 records a
decision that was already made and shipped. That record was decided on
2026-10-13 and its implementation has not landed; it is the first record here
that describes work in flight rather than work done, and it says so. On every
other record the `Date decided` field is when the decision was recorded, not the
day the file was written.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| `proposed` | Under discussion, not yet committed to. |
| `accepted` | In effect and being followed. |
| `accepted — under review` | In effect and testable **today**, but a planned change will re-examine it. Not `superseded`, because nothing has replaced it yet. |
| `superseded by ADR-NNNN` | A newer record replaced it. Always links the replacement. |
| `rejected` | Considered and declined. Kept so the option is not re-proposed. |

### What the overhaul did to the four records under review

Until 2026-10-13, ADR-0016, ADR-0017, ADR-0018 and ADR-0019 all carried
`accepted — under review` on the same reasoning: a major UI overhaul was planned
with a new prototype replacing the React reference, so each was in effect and
testable today but would be re-examined. **The overhaul has now landed as a
decision** — [`ADR-0022`](0022-full-fidelity-redesign-supersedes-0001.md), which
adopts `eva/redesign.html` and, in the same record, supersedes ADR-0001.

| ADR | Now | Why |
| --- | --- | --- |
| [0016](0016-dark-glassmorphic-design-system.md) | `superseded by ADR-0022` | the redesign brings its own palette, shader, witness sky and dock |
| [0017](0017-split-the-accent-into-a-fill-and-an-ink.md) | `superseded by ADR-0022` | the accent is replaced, so the fill/ink split and the `onEmber` divergence go with it |
| [0019](0019-performance-budget.md) | `superseded by ADR-0022` | "one blur site per screen" is a budget for a design that does not blur; this one blurs the whole viewport |
| [0018](0018-bilingual-typography-two-arms-two-questions.md) | **still `accepted — under review`** | the redesign does not touch the bilingual font resolution, so there is nothing to re-examine it against |

`superseded` means **replaced**, not **implemented**. The plan's Phases 2 through
6 carry the code across, so `lib/` still holds the superseded values today. A
green gate run says nothing about that, which is why the fiction table in
ADR-0022 exists as a document rather than as an assertion.

The scope and the measured consequences are in
[`ROADMAP.md`](../../ROADMAP.md) under **Design overhaul**. The overhaul reaches
the routing shape — two routes added, one retired — and it does **not** reach
the layer model, the ports, the dependency-injection split or the error algebra.

## Index

| ADR | Title | Status | Decided |
| --- | --- | --- | --- |
| [0001](0001-six-screens-library-and-profile-cut.md) | Ship six screens; cut the library and the profile | **superseded by ADR-0022** | 2026-10-02 |
| [0002](0002-live-api-is-the-only-data-source.md) | Read from the live API; auth stays UI-only and settings stay local | accepted | 2026-10-02 |
| [0003](0003-strict-three-layer-clean-architecture.md) | Keep three layers with strictly inward dependency direction | accepted | 2026-10-02 |
| [0004](0004-shared-kernel-in-core-domain.md) | Put types two or more features consume in the shared kernel | accepted | 2026-10-02 |
| [0005](0005-four-narrow-ports-no-fat-repository.md) | Declare four narrow repository ports; a fat repository is forbidden | accepted | 2026-10-02 |
| [0006](0006-result-is-either-failure-t.md) | `Result<T>` is a typedef for `Either<Failure, T>` via fpdart | accepted | 2026-10-02 |
| [0007](0007-failure-stays-hand-written.md) | Keep `Failure` hand-written and exclude `details` from equality | accepted | 2026-10-05 |
| [0008](0008-adopt-freezed-for-states-and-entities.md) | Use freezed for bloc states, events and domain entities | accepted | 2026-10-05 |
| [0009](0009-whole-state-writers-on-the-largest-states.md) | Disable `copyWith` on the three largest states and write whole states | accepted | 2026-10-05 |
| [0010](0010-arb-and-gen-l10n-replace-string-tables.md) | Replace the hand-rolled string tables with ARB and gen_l10n | accepted | 2026-10-05 |
| [0011](0011-pin-the-dependency-set.md) | Pin the dependency set; every addition needs approval | accepted | 2026-10-05 |
| [0012](0012-split-the-di-graph-to-keep-one-half-flutter-free.md) | Split the DI graph across two files so one stays Flutter-free | accepted | 2026-10-02 |
| [0013](0013-register-singletons-for-anything-with-a-stream.md) | Register singletons for anything holding a stream; the router is a lazy singleton | accepted | 2026-10-03 |
| [0014](0014-auto-route-with-an-auth-status-guard.md) | Route with auto_route behind a guard over a one-member `AuthStatus` | accepted | 2026-10-03 |
| [0015](0015-result-is-not-deep-linkable.md) | Accept that `/result` cannot be deep-linked | accepted | 2026-10-04 |
| [0016](0016-dark-glassmorphic-design-system.md) | One dark glassmorphic design system with five bundled families and zero elevation | **superseded by ADR-0022** | 2026-10-02 |
| [0017](0017-split-the-accent-into-a-fill-and-an-ink.md) | Split the accent into a fill and an ink; diverge `onEmber` from spec for WCAG | **superseded by ADR-0022** | 2026-10-02 |
| [0018](0018-bilingual-typography-two-arms-two-questions.md) | Resolve the Arabic family with one function plus per-arm switches | **accepted — under review** | 2026-10-04 |
| [0019](0019-performance-budget.md) | One blur site per screen, three animation controllers app-wide | **superseded by ADR-0022** | 2026-10-04 |
| [0020](0020-a-gate-that-cannot-fail-is-worse-than-no-gate.md) | Treat a gate that cannot fail as worse than no gate | accepted | 2026-10-07 |
| [0021](0021-tdd-for-domain-and-behaviour-tests-for-widgets.md) | Test-drive the domain; test alongside the widgets | accepted | 2026-10-02 |
| [0022](0022-full-fidelity-redesign-supersedes-0001.md) | Ship the LUMEN redesign at full fidelity, and supersede ADR-0001 | accepted | 2026-10-13 |

## Reading order

If you are new to this codebase, read these five in order. Between them they
cover every seam where the answer to a question changes shape.

1. **[0003](0003-strict-three-layer-clean-architecture.md)** — why the layers
   point inward and what that forbids.
2. **[0004](0004-shared-kernel-in-core-domain.md)** — the placement test, which
   is the rule that decides where a new type goes.
3. **[0005](0005-four-narrow-ports-no-fat-repository.md)** — the ports and why
   every adapter registers against the interface rather than the class.
4. **[0006](0006-result-is-either-failure-t.md)** — the error algebra at every
   repository boundary, including what adopting `fpdart` cost.
5. **[0020](0020-a-gate-that-cannot-fail-is-worse-than-no-gate.md)** — the
   verification regime the rest of the repository is built around.

[`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) is the map.
[`docs/SEAMS.md`](../SEAMS.md) is the depth. This directory is the reasoning.

## Writing a new record

Copy [`template.md`](template.md) and fill it in. Three rules this repository
holds every ADR to:

- **Every factual claim carries a `file:line`, a decision number, or a
  measurement.** A claim about a number is a claim about a specific thing.
  `docs/DRIFT.md` is a catalogue of figures that were correct when written and
  rotted silently afterwards, because prose cannot fail a test.
- **A rejected alternative with no recorded reason is not a rejected
  alternative.** If nothing was considered, write "no alternative was
  considered" — that is an honest entry and belongs in the file.
- **Backfills are marked.** If you are recording a decision that was made before
  the ADR existed, the `Date decided` field is when it was made, not the day you
  wrote it down.
