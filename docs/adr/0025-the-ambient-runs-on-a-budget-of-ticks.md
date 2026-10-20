# ADR-0025: The ambient paints and notifies on a budget of ticks

- **Status:** proposed
- **Date decided:** 2026-10-20
- **Recorded:** 2026-10-20
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `docs/agents/AGENT_CONTEXT.md` §8 decision 175,
  `docs/plans/09-quality-gates.md` §13 rule 4, and `docs/adr/0019-performance-budget.md`

## Context

The ambient is the app's most expensive layer, and it had **no budget at
all**. Two things ran on **every vsync**:

- the **aurora** — a full-screen fragment shader, re-rasterised at **device**
  resolution. On a 1080×2400 phone that is **2.6 M fragments a frame**, and at
  the repository's own measured rate (`lumen_tier.dart:62-70`, **2.98 ns/px**)
  the default band costs **7.7 ms** — **46 % of a 60 Hz frame** and **93 % of a
  90 Hz one**;
- the **notification** that rebuilds the witness sky's **forty-four stars** — 44
  × 5 widgets, so about **265 elements re-instantiated per frame**, with **44
  composited `Opacity` layers** and **88 shadow blurs** — plus the gold flecks,
  the CTA's breathing bead and the CTA's ripple ring.

§13 rule 4 asked for exactly this and it was never built: *"a `NeuralTier`
derived from `MediaQuery` size and platform frame budget drops to `low` on
low-end devices: no orbs, aurora only, at **30 % cost**."* `LumenTiers` has no
such member, and the ambient's cost is not a **pixel** cost at all — it is a
**frame-rate** cost, and nothing in the tree counted frames.

## Decision

**The ambient paints at thirty times a second and notifies at twenty, and both
are counted in TICKS rather than in time.**

The budget is `AmbientTickBudget`, and it carries two **divisors** — the aurora
paints every *N*ᵗʰ tick and the ambient notifies every *N*ᵗʰ tick — resolved
from the platform's own display: **2 and 3 at 60 Hz**, 4 and 6 at 120 Hz.

**And the budget gates the PAINT and the NOTIFICATION, never the STATE.** The
eased ambient, the eased hue and the decaying spike advance on **every** tick,
with the prototype's per-frame constants untouched.

## Alternatives considered

### Converting the per-frame eases to per-second, and capping the *state*

- **Pros:** one mechanism rather than two; the state and the paint would be
  capped together.
- **Cons:** **it is a divergence from the prototype.** `redesign.html:891-892`'s
  `ambI += (base-ambI)*0.06` is a **per-frame** constant, and the prototype's
  own `dt` is used for the *auto hue* and the *time accumulator*, never for the
  eases. `lumen_scene_test.dart` asserts one frame's ease to **twelve decimal
  places**, and that assertion is right.
- **Why not:** the budget does not need it. Capping the *paint* while the
  *state* runs at full rate leaves the aurora's trajectory **exactly** what it
  was, and the change is invisible — a slow-drifting gradient at 30 Hz is
  indistinguishable from one at 60 Hz.

### Gating on a **time interval**

- **Pros:** the obvious reading of "thirty times a second".
- **Cons:** every clock available is wrong for one reason or another. A **wall
  clock** can go backwards, and a gate that goes backwards stops firing. A
  **`Stopwatch`** measures real time, and a real-time gate makes every
  **golden** that depends on the ambient **non-deterministic** — the frame that
  captured it would depend on how fast the machine ran.
  **`SchedulerBinding.currentFrameTimeStamp`** asserts that a frame is in
  progress, and the ambient's notification can arrive **outside** one — the
  clock's `setReducedMotion` is called from a `WidgetsBindingObserver`
  callback, and that is not a frame. And the **shader clock's own elapsed
  time** is **one frame behind** the float clock's, because the two tickers
  tick in sequence and the float ticks first.
- **Why not:** all four were **tried**, and the last two are in this
  repository's history: the `currentFrameTimeStamp` version failed
  `lumen_canvas_test.dart` with *"`_currentFrameTimeStamp != null`: is not
  true"*, and the shader-clock version failed the gold flecks' golden because
  the captured phase was a frame stale.

### Gating on a **frame count**

- **Pros:** exact, reproducible, and it is the unit the thing being budgeted is
  **already counted in** — the ambient's notification is already one per
  frame, and the scene's tick is already one per frame. A golden that depends
  on the ambient is therefore **deterministic**.
- **Cons:** the divisor is tied to the display's refresh rate, so a 60 Hz
  panel and a 120 Hz panel get different divisors.
- **Why not:** it is what this ADR decided. The divisor is **resolved from the
  display**, so the *rate* is the same on every panel — the cap is the thing
  that matters, and a 120 Hz panel simply wastes less.

### Lowering the divisor to a fixed number, whatever the display

- **Pros:** one constant.
- **Cons:** a 30 Hz panel would run the ambient at 20 Hz, and a 144 Hz one at
  20 Hz, for no reason.
- **Why not:** the display is the thing that decides how often a frame *can* be
  painted, and the budget's job is to cap it, not to fix it.

## Consequences

### Better

- The aurora's **GPU** cost roughly halves on a 60 Hz panel, and the two
  `BackdropFilter`s that blur it — the dock's σ **22** and Home's σ **24** —
  re-run at half the rate, because a backdrop filter over an animating layer is
  re-evaluated whenever the layer changes.
- The witness sky's **forty-four stars** rebuild **three times less often**, and
  so do the gold flecks, the CTA's bead and its ripple ring.
- The **state** is untouched: the aurora's trajectory, the sky's twinkle phase
  and the flecks' phase are **exactly** what they were, because every clock
  still ticks at the display's rate and every consumer still reads the same
  number.
- The budget is a **value**, and it is **asserted**: `ambient_tick_budget_test.dart`
  pins the divisors, the gate's sequence, and that two gates with the same
  divisor agree on every frame.

### Worse

- **A golden must ask for an un-budgeted scope.** The budget decides *which
  tick* a frame is captured on, and a golden captures a **design** — so
  `evaAmbientHarness` takes a `budget` and the witness sky's goldens pass
  `kNoAmbientBudget`. **A golden that captured a budgeted frame would move
  every time the budget did.**
- **Four suites that encoded the old contract changed.** The gold flecks'
  "the pixels move as the clock runs", the background's "the aurora repaints as
  its clock advances", the motion suite's D1 rows and the scene's notification
  row. The D1 rows are about the **coalescing** — two clocks, one
  notification — and they now pass an un-budgeted scope so the budget is not a
  second thing in the way; the budget has **its own** rows.
- **The ambient's rendering lags its state by up to two ticks.** That is the
  price, and it is the price of a slow gradient.

### Neutral / noted

- **No pixel changed.** The goldens did not move, and the full suite is green.
- **The reduced-motion path is untouched.** The clocks stop under reduced
  motion, and the budget only ever makes a notification *rarer* — so a reader
  who has asked for stillness gets less of it, not more.
- **The aurora's pixel budget is still in logical pixels** and the shafts
  shape is still 8.7× the cost of the default one. That is a separate
  decision, it is **visible** to a reader who chose "shafts", and it is
  recorded as open in `docs/PERFORMANCE.md` §3.

## Traceability

- `docs/agents/AGENT_CONTEXT.md` §8 decision 175
- `docs/plans/09-quality-gates.md` §13 rule 4 — the "30 % cost" this implements
- `docs/adr/0019-performance-budget.md` — the decision this one implements
- `docs/adr/0024-rebuild-isolation-and-the-setstate-budget.md` — the rebuild
  boundary, which is the other half of the frame's cost
- `docs/PERFORMANCE.md` §3 — the measurements this rests on
- `lib/core/design_system/effects/ambient_tick_budget.dart` — the budget and
  the gate
- `lib/core/design_system/effects/lumen_scene.dart` — the paint gate
- `lib/core/design_system/effects/neural_motion.dart` — the notify gate
- `test/core/design_system/effects/ambient_tick_budget_test.dart` — the rows
