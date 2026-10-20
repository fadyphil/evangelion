# ADR-0019: One blur site per screen, three animation controllers app-wide, and an `EvaAnimate` wrapper

- **Status:** superseded by [ADR-0022](0022-full-fidelity-redesign-supersedes-0001.md), 2026-10-13. The LUMEN redesign replaces this decision; `lib/` carries the old values until the plan's Phases 2–6 land it.
- **Date decided:** 2026-10-05 (the blur budget: 2026-10-04)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `docs/plans/09-quality-gates.md` §13, recorded decisions 34, 135

## Context

§13 names five mandatory mitigations for the prototype's 60fps-re-rendering
`NeuralBackground`. **The two that bite hardest are the two nobody would have noticed
missing**, because both degrade silently: a per-frame `setState` rebuilds the page
behind a static-looking gradient, and a per-orb controller looks identical on screen
until the frame budget goes.

## Decision

**No `setState` per frame.** `ListenableBuilder` + `RepaintBoundary` confines the
repaint to the background layer, so the page above never rebuilds.
`neural_motion.dart:9-24` records why the class is a `ChangeNotifier` and not just a
bag of controllers: §13.1's reference reads
`ListenableBuilder(listenable: motion)` where nothing ever calls `notifyListeners()`,
so the builder never rebuilds and the mitigation degrades into a static gradient
**while every test still passes**.

**Three controllers app-wide** — float, hue, aurora (`neural_motion.dart:126-135`) —
created once above `MaterialApp.router`, published through `NeuralMotionScope`, **not
per screen and not looked up per orb**. Eight screens × 4 orbs × 2 animations is
**64** animations; this is three.

### The blur budget, and a correction worth recording because it was wrong against its own inventory

§13.4's per-screen line said `/` blurs on the panel **and the top bar**. The
prototype's `TopBar` was a flex `div` with a `padding` and a `zIndex` and **no
`backdropFilter` in its 32 lines** — the prototype deliberately leaves the bar
see-through so the orbs show behind it, and the redesign's own app bar is the same
shape (`.appbar` and `.abrow`, `redesign.html:142-143`: a padded flex row with no
backdrop filter; the redesign's home carries no app bar at all). **One** blur ships, on the
panel. A `BackdropFilter` is a `saveLayer` plus a full read-back of everything behind
it, per frame, and adding one to a surface the prototype deliberately leaves
see-through is exactly the "improve the design" this project forbids.
`glass_blur_budget_test.dart`'s ceiling for `lib/features/` moved from **2 to 1** so a
second site is red.

**`kGlassBlurSigma` is `24`** (`glass_surface.dart:131`, asserted at
`glass_surface_test.dart:209`) — the superseded prototype's own `blur(24px)` on Home's
hero panel. The earlier justification was wrong on all three counts: the two radii were
swapped (the panel is `24`, the prototype's FAB button was `20`); **`20` was never the
median** — the prototype had **nine** blur sites, measuring
`8, 12, 12, 16, 16, 20, 20, 24, 24`, and the
median is **16**; and **no `20` site survives at all**, because `PassageCard` and
`SealFAB` were cut with the screens that used them. **Only one site blurs, so there is
nothing to compromise.**

**And the design reference's own home card blurs `12`, not `24`** — `.hcard`'s
`backdrop-filter:blur(12px)` (`redesign.html:250`). The two sides differ, and **the
client is on the prototype's side**: `24` is the number this ADR decided, and the
reference says something else. The prototype's `20` on its dial button has **no
counterpart at all** — the redesign draws no dial — which is the second half of why no
`20` site survives.
Rejected as well: keeping `20` as a "recorded divergence", since the only two arguments
available were the median and the surviving-`20`, and both are false; and an upper bound
for performance, since a `BackdropFilter` costs one `saveLayer` whatever the sigma and
§13.4's rule is about the **count**.

### The lesson the blur correction bought

**A correction to a gate has to reach every string the gate can print.** The first
correction reached the assertion (`<= 1`) and the first failure message, and missed
the test's **name** and a **second** failure message — both still saying "two sites"
and "Home's top bar may blur". The gate was tripped deliberately to read the output,
and the message a developer reads when planting a blur in a design-system primitive
named a precedent that did not exist
(`glass_blur_budget_test.dart:113-123`).

### `EvaAnimate` exists because the package reads no accessibility flag

`grep -r disableAnimations` over the whole of `flutter_animate` **returns nothing**.
§14 requires every animation to check `MediaQuery.disableAnimationsOf(context)` and,
when disabled, jump straight to the end state — and recorded decision 124 was written
for a single site that forgot. So **using the package directly makes every call site a
fresh violation, invisibly.** `EvaAnimate`
(`lib/core/design_system/motion/eva_animate.dart`) is what closes the gap, and it is
**mandatory rather than preferred**.

It also owns two defaults this app has already rejected: `Animate.defaultDuration` is a
literal `300ms` and `Animate.defaultCurve` is `Curves.linear`.
`installPackageDefaults()` overwrites both from the composition root, before DI and
before any widget exists (`bootstrap.dart:77`), so even a forgotten wrapper degrades
to the app's own curve. Timings come from `MotionMoment`'s factories rather than from
widget parameters, so **a literal cannot reach an effect even by accident**.

**It also owns the achievement spring.** The package's complete effect surface was
extracted from the 4.5.2 tarball and contains **no** `spring*`, **no** `elastic*` and
**no** `*Staggered`: it animates with `Curve`s, never with physics. Recorded decision
134 then measured that the obvious escape hatch does not work either —
`EffectEntry.buildAnimation` wraps whatever controller it is handed in
`Interval(begin / duration, end / duration)`, and a spring's value leaves `[0,1]` by
design, which trips `ParametricCurve`'s `t >= 0.0 && t <= 1.0` assertion. A spring
routed through `Animate` does not merely lose its overshoot, it **throws**. So
`EvaMotion.achievementSpring` is for widgets that drive their own controller with
`animateWith(SpringSimulation(…))`, and `achievementCurve` is for `Animate`-driven
effects; the two are matched on overshoot so they feel like one family.

## Alternatives considered

### A per-screen `NeuralMotionScope`

- **Why not:** §13.2 says it explicitly — the controllers live in a single
  `StatefulWidget` above `MaterialApp.router`, published through an inherited scope,
  **not recreated per screen and not looked up from `BuildContext` inside each
  `NeuralBackground`**. A per-screen scope is the 64-animation shape with fewer
  classes.

### Median of the eight radii as the shipped sigma

- **Why not:** it is 16, not 20, and it is a compromise between radii that do not
  co-exist. Only one site blurs.

### Use `flutter_animate` directly with a call-site `disableAnimationsOf` check

- **Why not:** it would work, and it would be eight call sites each carrying a check
  the package cannot enforce — so the ninth, added by whoever adds a screen next, would
  not carry it.

### `Curves.elasticOut` for the achievement

- **Why not:** measured overshoot **27.5%** — a quarter again over the target reads as
  a glitch on a flame meant to look like it caught. `Curves.easeOutBack` measures
  **8.7%** and is what ships.

## Consequences

### Better

- **The budget is a gate with a per-directory ceiling**, not a convention, and it fails
  closed: a scanned directory missing, a file unreadable, or an **empty walk** each
  fail rather than report a count of zero (`glass_blur_budget_test.dart:101-111`).
- **Reduced motion substitutes the end state rather than removing the widget.** A
  transitions builder's job is to wrap the page, and swapping the subtree for a reader
  who asked for *less* motion rather than *no* widget is the wrong trade.

### Worse

- **`EvaAnimate` is mandatory**, so `flutter_animate` cannot be used without it. A
  future reviewer who finds the package attractive will find the wrapper in the way
  and has to read this ADR to learn why.
- **The prototype's per-orb float and hue periods cannot be honoured.** With three
  controllers there is no way to represent twenty-two distinct periods; one clock has
  one rate. `neural_motion.dart:35-40` records this as D3 rather than leaving it to be
  rediscovered.

### Neutral / noted

- **`kGlassBlurSigma` is asserted as a literal** because a sigma cannot be read back
  off a `BackdropFilter` (`glass_surface_test.dart:187`) — the same shape as ADR-0016's
  elevation problem, with a different reason.
- **Two bugs in `EvaAnimate` were invisible to reading the code and are now pinned**:
  `_play()` did not reset to `0` before `animateTo(1.0)`, so a trigger change replayed
  nothing; and `Animate.initState` ends in `Future.delayed(Duration.zero)`, leaving a
  real `Timer` a bare `tester.pump()` does not drain.

## Traceability

- `AGENT_CONTEXT.md` recorded decision 34 (one blur site; the sigma is 24 and the
  three wrong justifications), decision 135 (the accessibility flag; the defaults),
  decision 134 (the spring path does not work), decision 124 (the single site that
  forgot the rule)
- `docs/plans/09-quality-gates.md` §13 (five mitigations), §13.2 (three controllers),
  §13.4 (the blur budget and the corrected per-screen line), §14 (reduced motion)
- `lib/core/design_system/effects/neural_motion.dart:9-24,35-40,126-135,334-349`
- `lib/core/design_system/widgets/glass_surface.dart:131,235-236`
- `lib/core/design_system/motion/eva_animate.dart` — the wrapper and its two reasons
- `lib/app/bootstrap.dart:75-77` (`installPackageDefaults`, before DI)
- `test/core/design_system/widgets/glass_surface_test.dart:187,209`,
  `test/core/design_system/widgets/glass_blur_budget_test.dart:101-123`
- the superseded prototype's home hero panel (`blur(24px)`), its `TopBar` and its FAB
  button — the three receipts this ADR's blur correction was measured against. The
  design reference's own counterparts are the home card's
  `backdrop-filter:blur(12px)` (`redesign.html:250`) and the app bar's padded flex row
  (`.appbar` / `.abrow`, `redesign.html:142-143`); it draws no dial.
- ADR-0011 (why the pin is exact, and the two costs of the package),
  ADR-0016 (the system these mitigate)
