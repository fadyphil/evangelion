# ADR-0024: A state change rebuilds its target and nothing else

- **Status:** proposed
- **Date decided:** 2026-10-20
- **Recorded:** 2026-10-20
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `docs/agents/AGENT_CONTEXT.md` §7 (the gates), §8 decisions 170–174,
  and `docs/plans/09-quality-gates.md` §13 rules 1 and 4

## Context

§13 rule 1 says **"No `setState` per frame"**, and §13 rule 4 budgets the
`BackdropFilter`s and asks for a tier that "drops to `low` on low-end devices:
no orbs, aurora only, at **30 % cost**". Neither was ever enforced against
anything, and ADR-0019 — the performance ADR — is marked *superseded by
ADR-0022*, with the note that *"`lib/` carries the old values until the plan's
Phases 2–6 land it."* Those phases landed. **The values were never checked.**

The measurement is in `docs/PERFORMANCE.md`, and it is the reason for this
decision:

| a reader does this | widgets that rebuilt, before | after |
| --- | --- | --- |
| drags the Hue slider one step on `/settings` | **1,236** | **27** |
| taps a verse on `/reading` | **211** | **55** |

Both numbers are **budgets** in `test/rebuild_isolation_budget_test.dart`, so
they cannot drift back without a red test.

The mechanism is Flutter's, and it is a single line: `Element.update`
short-circuits when the new widget is **identical** to the old one. A rebuild
stops descending the moment it re-encounters the same widget instance. So the
cost of a state change is decided entirely by **how wide the thing that changed
is** — and on this tree it was the whole screen, for a hue.

## Decision

**A state change rebuilds its target and nothing else.** Concretely:

1. **A reading page's own state lives in notifiers, not in `setState`.** The
   selected verse, the reveal frontier, the focus dim, the bookmark and the
   language arm are five `ValueNotifier`s, and each one's consumer is wrapped
   in a `ValueListenableBuilder`. **`/reading` no longer calls `setState` at
   all**, so its `build` — which carries the scaffold and the forty-four-star
   sky — does not run when a verse is tapped.

2. **`/settings` reads each row's setting through its own `BlocSelector`.**
   Thirty-three rows, each selecting the one field it shows, so a hue change
   rebuilds the hue row and nothing else.

3. **The settings scope publishes in slices.** `SettingsScope` was one
   `InheritedNotifier` over the whole thirty-field `UserSettings` and notified
   on every write, so every dependent rebuilt on every write. It now publishes
   four **slices** — witness, ritual, communion, reading — each with its own
   notifier, and each a **distinct runtime type** so `InheritedWidget`'s
   dependency granularity is per slice. The **handle** is read **without** a
   dependency, because its identity never changes.

4. **The composition root rebuilds only for what `MaterialApp` reads.** The
   four settings it consumes — `themeMode`, `language`, `fontStep` and
   `reducedMotion` — are compared against the last built values, and a write
   that touches none of them does not rebuild the shell.

5. **The rebuild boundary is a gate, not a paragraph.**
   `test/rebuild_isolation_budget_test.dart` asserts that the sky, the
   scaffold, the app bar and the language dial **do not rebuild** on a verse
   tap, and bounds the totals.

6. **And the `setState` policy is a second gate.**
   `test/setstate_budget_test.dart` holds an allowlist of the **sixteen**
   sites whose `State.build` output *is* the state, and fails on any new
   one, on any stale row, and on a scan that finds nothing at all. The key is
   a **file** plus the **multiset** of its normalised statements — a
   `file:line` key is brittle in the worst way, because any edit above a
   site moves it and the gate would cry wolf on a change that changed
   nothing.

## Alternatives considered

### `buildWhen` on the existing `BlocBuilder`s

- **Pros:** one line each; the smallest possible diff.
- **Cons:** it is all-or-nothing. Every settings write changes
  `state.settings`, so a `buildWhen` on that would never say no — and the
  question is not *whether* the page rebuilds but *which row* does.
- **Why not:** the measured number. `buildWhen` alone leaves the 1,236 at
  1,236; the row-level split is what takes it to 27.

### One `BlocSelector` per **group** rather than per **row**

- **Pros:** seven selectors instead of twenty-eight; a smaller diff.
- **Cons:** a hue change rebuilds the whole "light workshop" group — ten rows
  and their controls — rather than one.
- **Why not:** the per-row split is mechanical once the helper exists, and the
  per-group split would have left the biggest single win on the table.

### Narrowing the scope **after** the selectors

- **Pros:** the two changes are independent-looking, and the selectors alone
  are more obviously an improvement.
- **Cons:** **it does not work.** `BlocSelector.build` calls its builder
  unconditionally, so a selector whose *parent* rebuilt rebuilds its child
  anyway. With the coarse scope still notifying, the page rebuilt and every
  row with it — and the measurement got **worse**, 1,236 → 1,358, because each
  of the twenty-eight selectors added its own rebuild.
- **Why not:** this was measured, in that order, and the number went the wrong
  way. The scope narrowing is not a refinement of the selector split; it is
  its **precondition**.

### A `CustomPainter` for the witness sky, as `witness_sky.dart` itself proposes

- **Pros:** the file's own measured table puts the sky at 2,214 µs/frame at
  forty-four stars, and the file names the fix.
- **Cons:** a painter's shapes are not widget-tree nodes, so every finder in
  the file's suite would have to become a golden — and that suite is currently
  the only thing that can see a star at all.
- **Why not:** it is a **redesign of the widget's internals**, and it is not
  needed for the boundary this ADR decides. The sky's problem was never its
  own frame cost — it was that it **rebuilt at all** when something else
  changed, and that is now a gate.

### Lowering the frame rate of the aurora, or rendering it at reduced resolution

- **Pros:** both are large GPU wins, and §13 rule 4 asked for the first.
- **Cons:** the first changes the motion's cadence, the second resamples the
  image. Both are visible, and this ADR is about a boundary that is not.
- **Why not:** they are **GPU** decisions and this ADR is about **rebuilds**.
  They are recorded in `docs/PERFORMANCE.md` as the open work, with the
  measured cost that justifies them.

## Consequences

### Better

- A hue change rebuilds **27** widgets instead of **1,236**; a verse tap
  rebuilds **55** instead of **211**.
- The **forty-four-star sky** no longer rebuilds when the reader taps a verse.
  It is the most expensive thing on the screen, and it has nothing to do with
  which verse is selected.
- The three **invisible tab screens** the dock keeps alive no longer rebuild
  when a setting changes.
- The **whole application** no longer rebuilds when a setting changes — the
  composition root's guard means a hue change does not touch the shell at all.
- The boundary is **enforceable**: `test/rebuild_isolation_budget_test.dart`
  fails the build if it moves.

### Worse

- **`/settings` is now twenty-eight selectors deep.** More widgets, and a
  reader of the file has to know that `_SettingRow` is the reason a row
  rebuilds alone.
- **`/reading` holds five notifiers and disposes five.** A `ValueNotifier` that
  outlives its `State` keeps its listeners alive, so the disposal is not
  optional.
- **The row cache is a cache.** `_verseRows` holds a widget per built verse,
  and a row that changes is rebuilt and the entry replaced. It is cleared when
  the passage changes, because a row holds its key.
- **The breath guide still costs a list rebuild.** It is an **extra row**, so
  selecting a verse changes the list's item count and Flutter replaces every
  element after the insertion point. That is why a tap rebuilds two verses and
  not one. Moving the guide to be a **decoration** of its anchor verse would
  fix it — and would move the guide's box, which the reading harness measures.
  It is recorded in `docs/PERFORMANCE.md` as the open work.

### Neutral / noted

- **No pixel changed.** The goldens did not move, and the full suite is green.
- **`Adam`/`eq` and the `TextTheme` are untouched.** `EvaTypography.textTheme`
  is still recomputed per verse build where the theme already holds the
  answer; the measurement is in `docs/PERFORMANCE.md` and the fix is recorded
  there, not here.
- **The ambient's own cost is untouched.** The aurora still repaints on every
  vsync, and its pixel budget is still counted in logical pixels. Both are GPU
  problems, and both are open.

## Traceability

- `docs/agents/AGENT_CONTEXT.md` §8 decisions 170–174
- `docs/plans/09-quality-gates.md` §13 rules 1 and 4
- `docs/adr/0019-performance-budget.md` — the decision this one enforces
- `docs/adr/0020-a-gate-that-cannot-fail-is-worse-than-no-gate.md`
- `docs/PERFORMANCE.md` — the measurements and the commands that reproduce them
- `test/rebuild_isolation_budget_test.dart` — the rebuild-boundary gate
- `test/setstate_budget_test.dart` — the `setState` allowlist gate
- `test/support/rebuild_counter.dart` — the instrument
- `lib/app/settings_scope.dart` — the slices
- `lib/features/settings/presentation/pages/settings_page.dart` — `_SettingRow`
- `lib/features/reading/presentation/pages/reading_page.dart` — the notifiers
  and the row cache
- `lib/app/app.dart` — the composition root's guard
