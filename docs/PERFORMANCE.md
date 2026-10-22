# PERFORMANCE.md — the measurements, and the commands that reproduce them

Every number in this file is produced by a command you can paste. A number
without one is not a measurement, and this repository does not accept it.

**And the three kinds of number in this file are kept apart, deliberately.**
A **computed** number is labelled *computed* and shows its arithmetic. A
**measured** number carries the command that produced it. A **structural**
number — a count of call sites, a line number, a widget's pixel size — carries
its `file:line`. A number that is none of those three is not written down,
and a paragraph that mixes them is the defect this file exists to prevent.

**The device the "before" figures were taken on:** a Flutter **debug JIT** under
`flutter test` — fake async, a software rasteriser, and a machine that is not
a phone. **These are upper bounds and relative figures, not device numbers.**
The absolute widget counts are exact; the wall-clock figures are not, and the
repository's own precedent says so (`witness_sky.dart:853-857`: *"a debug JIT
under fake async, so these are **not** device numbers and should be read as an
upper bound"*).

---

## 1. The instrument

`test/support/rebuild_counter.dart` counts the widgets the framework
**rebuilt** during one frame, using the framework's own
`debugOnRebuildDirtyWidget` hook — the same hook the DevTools inspector's
`trackRebuildDirtyWidgets` service extension uses.

It counts **rebuilds**, not first builds (the hook's `builtOnce` flag
separates them), and it reports a **delta**: one pump with nothing done to it
(the baseline) against one pump after the action. The delta is what the action
cost, because two of the pages mount **ambient animation** and a raw count
would measure the ambient rather than the action.

**Why this is the right instrument.** Flutter's `Element.update` short-circuits
when the new widget is **identical** to the old one, so a rebuild stops
descending at the first unchanged subtree. The cost of a state change is
therefore decided by **how wide the thing that changed is** — and this is the
instrument that measures exactly that.

```bash
flutter test test/rebuild_isolation_budget_test.dart
```

The test **prints** the numbers and **asserts** them. The assertions are the
point: a budget fails the build, so it cannot rot.

---

## 2. The rebuild boundary — what was measured

| a reader does this | before | after | the gate |
| --- | --- | --- | --- |
| drags the Hue slider one step on `/settings` | **1,236** widgets | **27** | ≤ 40, and exactly one `WorkshopSliderRow` |
| taps a verse on `/reading` | **211** widgets | **55** | ≤ 120, and **no** `WitnessSky`, `NeuralScaffold`, `Scaffold`, `ReadingAppBar` or `SegmentedControl` |

### 2.1 What the 1,236 was

Every one of `/settings`'s thirty-three rows, rebuilt for a change to **one
number**:

```text
Container × 99, AnimatedDefaultTextStyle × 81, DefaultTextStyle × 81,
Text × 57, AnimatedContainer × 47, Builder × 45, GestureDetector × 45,
RawGestureDetector × 45, Focus × 44, SettingsTile × 31, EvaToggle × 16,
WorkshopToggleRow × 16, EvaRangeSlider × 8, WorkshopSliderRow × 8, …
```

**And it was rebuilt twice over**: once by the page's own `BlocBuilder` and
once by `SettingsScope`'s `InheritedNotifier`, which notified on every write
and woke every dependent — including the three invisible tab screens the dock
keeps alive.

### 2.2 What the 211 was

The whole screen, the sky included:

```text
RawGestureDetector × 15, GestureDetector × 14, Text × 11, …,
VerseLine × 5, _HotGlow × 5, _Reveal × 5, …,
WitnessSky × 1, _SkyStars × 1,          ← the sky (44 stars at the cap)
NeuralScaffold × 1, Scaffold × 1, LumenBackground × 1,
ReadingAppBar × 1, ReadingPill × 1, ReadingQuizCta × 1,
SegmentedControl<ReadingLanguage> × 1, BreathGuideLine × 1
```

**The sky is the most expensive thing on the screen** — **44** stars × 5
widgets, 88 shadow blurs, **at the cap** — and it had nothing to do with which
verse was selected.

> **CORRECTED 2026-10-22 — the "44 composited `Opacity` layers" was a **CAP**
> read as a **MOUNTED COUNT**, and the two are different questions.**
>
> The **44** is `UserSettings.starCount`
> (`lib/core/domain/entities/user_settings.dart:164` — the default literal; the
> field at `:370`), and it is the **ceiling on how many stars the sky may
> hold**, read through the cap seam
> (`lib/app/di/navigation_injection.dart:308` —
> `capReader: () => getIt<SettingsHandle>().settings.starCount`).
> `WitnessSky` draws **one star per lit entry**
> (`lib/core/design_system/widgets/witness_sky.dart:981` — the
> `for (final SkyEntry entry in entries) _star(entry)` loop), and a reader who
> has just opened the app has lit **none**.
>
> **Measured**, by `flutter test test/layer_census_test.dart`:
>
> | the question | the measured answer |
> | --- | --- |
> | `OpacityLayer`s mounted on `/reading` **at rest** | **6** — not 44 |
> | `OpacityLayer`s added by lighting **all 44** stars | **exactly 44** |
> | logical px² added by those 44 stars | **738.77** — **0.18 %** of the 430×932 surface, and **0.02 %** of the screen's 3,456,256 px² of composited area |
>
> **So the number was never wrong — it was the wrong KIND of number.** At the
> cap the sky really does mount forty-four composited `Opacity` layers; the
> sentence above described that cap as what a screen mounts, and it does not.
> §8 carries the whole census, and `docs/DRIFT.md` §20 records the drift.

### 2.3 The order mattered, and the measurement said so

The per-row `BlocSelector` split was landed **first**, and the number got
**worse**: 1,236 → **1,358**. Each of the twenty-eight selectors added its own
rebuild, because `BlocSelector.build` calls its builder unconditionally — so
a selector whose *parent* rebuilt rebuilds its child anyway.

**Narrowing the scope is the selectors' precondition, not their refinement.**
See `docs/adr/0024-rebuild-isolation-and-the-setstate-budget.md`, §
"Alternatives considered".

---

## 3. The open work — the GPU half

**None of the above touches the GPU.** The aurora is a full-screen fragment
shader that repaints on **every vsync** at **device** resolution, and its cost
budget is counted in **logical** pixels.

> **CORRECTED 2026-10-22 — the first sentence no longer describes the tree,
> and this file contradicted itself.** The aurora **does not** repaint on every
> vsync: `AmbientTickBudget` caps its **paint** at **30 Hz**
> (`lib/core/design_system/effects/ambient_tick_budget.dart:77`, the
> `paintEveryNTick` divisor) and `LumenScene` consults that gate **before** it
> notifies (`lib/core/design_system/effects/lumen_scene.dart:491-493`, the
> gate built at `:497`). The sentence above was written before ADR-0025 landed,
> and **§3.2 records the landing** — so the two halves of this file disagreed
> and the contradiction is the finding. The second half of the sentence — the
> budget being counted in logical pixels — is still true, and §3.1 is about it.

### 3.1 The pixel budget is in the wrong unit

`lumen_tier.dart:89` sets `kShaftsPixelBudget = 2000000` and `:170-175`
compares it against `size.width * size.height`, where `size` is
`MediaQuery.sizeOf(context)` — **logical** pixels. The cost it protects is
GPU fragments, which are **device** pixels.

On a 1080×2400 phone at dpr 2.75: **0.343 Mpx logical** against **2.592 Mpx
device**. The gate under-counts by dpr² — about **7.6×**.

At the repository's own measured rates (`lumen_tier.dart:62-70`: **2.98 ns/px**
for shapes 0–2, **5.04 ns/px** for shafts):

| case | device px | aurora alone | 60 Hz (16.7 ms) | 90 Hz (11.1 ms) | 120 Hz (8.3 ms) |
| --- | --- | --- | --- | --- | --- |
| default band (`top`) | 2.59 M | **7.7 ms** | 46 % | 69 % | **93 %** |
| `shafts` | 2.59 M | **13.1 ms** | 78 % | **118 %** | **157 %** |

> **AN UNRESOLVED CONTRADICTION — a code comment and this document disagree,
> and this file does not pick a winner.**
> `lib/core/design_system/effects/lumen_tier.dart:71-78` argues the **opposite**,
> under its own heading — "**LOGICAL PX, NOT DEVICE PX**":
>
> > "`size.width * size.height` where `size` is the viewport's `MediaQuery`
> > size — the same units `u_res` carries. `LumenCanvas` documents that
> > `u_res` is the paint rect's *logical* size (`size`, never
> > `size * devicePixelRatio`), so a gate in device px would need a DPR lookup
> > this layer has no business doing, and would disagree with the number the
> > shader actually divides by."
>
> **This file says the gate must count device pixels; that comment says the
> gate is right as it is.** Both arguments are coherent — the code's is that a
> gate must agree with the number the shader divides by, and this file's is
> that the cost the gate protects is GPU fragments, which are device pixels —
> and **a document that quietly picks a winner would be picking without
> evidence.** What settles it is a **device measurement**, and §3.4's
> instrument is what will produce one. Until then the contradiction is
> recorded, and the disagreement is between **a code comment and a document**,
> not between two documents.

### 3.2 What the tick budget already did — **LANDED**

`AmbientTickBudget` (ADR-0025) caps the aurora at **30 paints a second** and the
ambient's notification at **20**, counted in **ticks** and resolved from the
platform's own display (**2 and 3** at 60 Hz, **4 and 6** at 120 Hz).

- The aurora's **GPU** cost roughly halves, and the two `BackdropFilter`s that
  blur it — the dock's σ **22** and Home's σ **24** — re-run at half the rate,
  because a backdrop filter over an animating layer is re-evaluated whenever
  the layer changes.
- The witness sky's **forty-four stars** — **at the cap** (§8) — rebuild
  **three times less often**, and so do the gold flecks, the CTA's bead and its
  ripple ring.
- **The state is untouched.** The aurora's trajectory, the sky's twinkle phase
  and the flecks' phase are exactly what they were, because every clock still
  ticks at the display's rate and every consumer still reads the same number.

> **CORRECTED 2026-10-22 — that bullet is not an inventory of ripple rings,
> and three more animate without ever touching the gate.** The four consumers
> it names are the right four — the repository names them itself at
> `lib/core/design_system/effects/neural_motion.dart:103-107` — and all four
> do read the **gated** notifier `motion.repaint`
> (`lib/core/design_system/effects/neural_motion.dart:232`, gated at `:165-166`
> by the 20 Hz `notifyGate` at `:177`). **But the sentence reads as a complete
> list, and it is not:** the dock's orb ripple, the selah card's breathing
> ring (`lib/features/home/presentation/widgets/selah_card.dart:579,595`) and
> the reader's breath guide
> (`lib/features/reading/presentation/widgets/breath_guide_line.dart:76`) were
> three more that animate and **never consulted the budget**. §5 is the
> section that says what each of them costs.
>
> **ANNOTATED 2026-10-22 — one of the three has since been moved ONTO the
> budget.** The dock's orb ripple now rides the **gated** notifier
> (`lib/features/dock/presentation/widgets/lumen_dock.dart:976` —
> `super(repaint: motion.repaint)`) and carries a `RepaintBoundary` **of its
> own** (`lumen_dock.dart:900`); **§5.1** carries the measurement, and the
> painter's rate fell from one repaint per frame to one every three. **The
> reader's breath guide has not**, and §5.4 still describes it as outside the
> budget. **And the selah card's ring has a third answer**: it is still
> outside the ambient's budget — a control's own pulse is not an ambient orb
> (`selah_card.dart:536-540`) — but it is **no longer animating on a tab the
> reader cannot see**, because a per-tab `TickerMode` mutes it
> (`lib/core/design_system/widgets/eva_tab_ticker_gate.dart:154-157`).
> **§5.2** carries it.

### 3.3 The GPU fixes still open, in the order they should be landed

| # | the change | the win | the cost |
| --- | --- | --- | --- |
| 1 | **Count device pixels in the shafts gate** — `LumenTiers.resolve` takes `devicePixelRatio` | the `shafts` shape stops costing 13–15 ms/frame on a phone | **visible** to a reader who explicitly chose "shafts" (they would see "sides"); the default shape is unaffected |
| 2 | **Fold the light-mode multiply into the shader** — `lumen_background.dart:189-218` wraps the aurora in a `ColorFiltered(ColorFilter.matrix(...))`, a full-screen `saveLayer` plus a full-screen 4×5 matrix pass **per frame** | one fewer full-screen pass in light mode | none visible: the mathematics is identical, and **the goldens are the acceptance test** — if they do not come back byte-identical, the change is dropped |

**And the one that needs a decision:** rendering the aurora at **half
resolution** (`Transform.scale` + a `RepaintBoundary`, with `u_res` adjusted
to the scaled size) would cut the fragment count by **4×**. The band geometry
is normalised by `u_res`, so the aurora's *shape* is unchanged — it is only
resampled. **It is visible as a slightly softer aurora**, and it is listed here
as a decision rather than a fix.

### 3.4 The on-device measurement, which does not exist yet

> **The heading is out of date and the annotation at the end of this
> subsection says so: the instrument IS built** — `lib/core/diagnostics/`,
> with its runbook at `tool/perf/README.md`. **What does not exist yet is a
> measurement**: no profile-mode run on a reader's phone has happened, so
> this section still holds **no device numbers**.

**A `flutter test` micro-benchmark cannot see the shader's GPU cost** — the
test rasteriser is software. The on-device instrument is
`SchedulerBinding.instance.addTimingsCallback`, which reports
`buildDuration`, `rasterDuration` and `totalSpan` per frame and works in
**release** and profile (the engine batches about once a second in release).

**It is not built yet.** When it is, it is a **profile-mode** run on the
reader's phone, and the numbers land in this file beside the ones above.

> **ANNOTATED 2026-10-22 — the instrument is BUILT, and this file records
> where it lives.** The recorder is
> `lib/core/diagnostics/frame_timing_recorder.dart` (the engine adapter) over
> `lib/core/diagnostics/frame_stats.dart` (pure-Dart statistics), behind the
> compile-time flag `PERF_TRACE` (`kPerfTraceEnabled`), with its suite in
> `test/core/diagnostics/`. **The runbook is `tool/perf/README.md`** — and it
> quotes this very section as the thing that "does not exist yet", so the two
> are a matched pair. **The numbers are still not in this file**: a
> profile-mode run on a reader's phone has not happened, and **nothing here
> may be read as a device measurement** until one does. The sentence above is
> kept as the thing that was true, and annotated rather than rewritten.

**And it is the only way to confirm §3.1 on the device.** Everything above is
computed from the tree's own recorded `ns/px` figures and the device's pixel
count — which is arithmetic, and arithmetic is not a measurement.

---

## 4. The CPU work that is still open

| the change | where | the win | the cost |
| --- | --- | --- | --- |
| **The `TextTheme` is rebuilt per verse** — **CORRECTED 2026-10-22, see §6.4** | `eva_typography.dart:138-167` — `_geometry.apply(...)` plus a **fifteen**-field `copyWith` (**fifteen**, not fourteen: `displayLarge`…`labelSmall`, one per Material slot), about **30 `TextStyle` allocations per call**; `verse_line.dart:357` and `:419` call it **twice per visible verse**, and `eva_theme.dart:59` **already builds the same `TextTheme` once** into the `ThemeData` (`:85`) | ~**15 µs** per call, ~**30 µs** per verse build — **and the per-call figure is a number the test PRINTS, not one it asserts** (§6.4) | none: the theme's `TextTheme` is the Eva one, so reading it is a de-duplication |
| **The breath guide is an extra list row** | `reading_page.dart` — selecting a verse changes the list's item count, and Flutter replaces every element after the insertion point, so a tap rebuilds **two** verses rather than one | moving the guide to be a **decoration** of its anchor verse would take the tap from 55 to ~20 | **visible**: the guide's box moves, and the reading harness measures the verse rects |
| **A `GlobalKey` per verse, cleared during the build** — **REFUTED 2026-10-22: the problem does not exist** | the claim was that `_verseKeys.clear()` runs inside the builder, so the next build mints **new** keys and every visible verse is **deactivated and re-mounted**. **It does not.** The clear is inside `if (passage != null && _entranceFor != passage.readingId)` (`reading_page.dart:725`) — it runs **once per passage**, not once per build. A verse's key is minted once and cached (`reading_page.dart:987-990`), so the keys are **stable across rebuilds** and the rows are **updated**, not remounted | **nothing to fix** | and the proposed `ValueKey<int>(verse.number)` would **break** star recording: `_onScroll` needs `entry.value.currentContext` (`reading_page.dart:505-509`), and a `ValueKey` has no `currentContext` |
| **One `AnimationController` per verse line** | `verse_line.dart:455-497` | twenty tickers become one | none visible |
| **`/communion` builds every row eagerly** — **CORRECTED 2026-10-22, see §6.2** | the claim was "`communion_page.dart:154` — a non-lazy `SingleChildScrollView` … the board stops building fifty rows to show twelve". **Every number in it was wrong.** The eager loop is `communion_page.dart:405-419`, and `:154` is `Widget build(BuildContext context) {`; the scroll view is `neural_scaffold.dart:408` and the page passes `scrollable: true` (`communion_page.dart:172`); the cap is **47 rows**, not fifty — the server's limit is 50 (`leaderboard_cubit.dart:127`) and the board skips the three podium rows (`communion_page.dart:376`); the deployed cohort is **3** (`docs/BACKEND-VERIFICATION.md:199`); and "twelve" is a **test fixture** (`test/features/leaderboard/presentation/communion_page_test.dart:111,220`), not a product fact | the board stops building **47** rows to show **47** | none visible |

---

## 5. The per-vsync cost the tick budget does not cover

**What this section is.** §3.2 records the budget that *was* landed: 30 paints a
second for the aurora, 20 notifications a second for the ambient's consumers —
and it names **four** consumers it covers. **Three constructs animate outside
it**, and a **fourth** — the dock's orb ripple — has since been moved onto it
(§5.1). They are written down here because a budget that covers four consumers
and misses three others is a budget whose scope nobody has stated.

**And §5.2 was a different kind of finding**, and it is worth naming so a
reader does not count it twice: the selah ring was not outside the budget
because it repainted too often, but because it **kept animating on a tab the
reader could not see** — a defect about *visibility*, whose fix is a
`TickerMode` per tab and not a budget. **Of the four subsections below, two
are now closed (§5.1 and §5.2) and two are open (§5.3 and §5.4).**

**And the arithmetic in this section is COMPUTED, not measured.** The only
per-pixel rates this repository records are the aurora's, at
`lib/core/design_system/effects/lumen_tier.dart:63-64` — **2.98 ns/px** for
shapes 0–2 and **5.04 ns/px** for shafts, measured on the aurora's own
fragment shader. **Those rates are a fragment shader's rates.** They do not
transfer to a Flutter widget's paint, and **this section does not apply them
to one.** Where a construct's cost cannot be computed from a recorded rate, the
section says so and states the **count** instead of a millisecond figure.

### 5.1 The dock's orb ripple repainted at the display rate — **LANDED: it rides the ambient's 20 Hz notifier**

| | |
| --- | --- |
| **The construct** | `_OrbRipplePainter` — the mini-orb's ripple ring, painted by a `CustomPaint` inside the dock's slot. **Unchanged by the fix** — the class is still `_OrbRipplePainter`, and the ring is still the prototype's |
| **Where** | `lib/features/dock/presentation/widgets/lumen_dock.dart:971` (the painter's class), `:976` (`super(repaint: motion.repaint)`), `:925` (the painter is built with `motion`), `:900` (the ripple's own `RepaintBoundary`) |
| **The clock** | `motion.lumen` is a `TickedLumenClock` (`lib/core/design_system/effects/neural_motion.dart:205`), and its `_onTick` calls `notifyListeners()` on **every tick** (`lib/core/design_system/effects/lumen_clock.dart:302-305`). The ticker is an `AnimationController` in `repeat()` (`neural_motion.dart:293`), so a tick is a **vsync** |
| **The gate it used to bypass** | the aurora's paint gate is `budget.paintGate` (`lib/core/design_system/effects/ambient_tick_budget.dart:125`, 30 Hz at `:77`); **before the fix** the ripple consulted **no** gate at all. **It rides the ambient's own gate now** — `motion.repaint` (`neural_motion.dart:232`), gated at `:165-166` by the 20 Hz `notifyGate` at `:177` |
| **The cost, before the fix** | **computed**: the ripple repainted at the display rate, so its repaint rate was `displayRefreshRate ÷ 30` = **2.0×** the budgeted paint rate at 60 Hz, **3.0×** at 90 Hz, **4.0×** at 120 Hz. **No millisecond figure is stated**: the aurora's `ns/px` are a fragment shader's rates and the repository records **no** per-pixel cost for a Flutter paint |
| **The cost, after the fix** | **computed**: the ripple rides the ambient's **20 Hz** notification, so at 60 Hz it asks for a repaint on **one frame in three** — which is **inside** the 30 Hz paint budget (one every two frames) and is the same rate the sky's stars and the gold flecks have paid since ADR-0025 |
| **THE MEASURED CHANGE** | **measured, by `flutter test test/painter_repaint_test.dart`**: the painter's repaint requests fell from **30 in 30 frames** (one per frame) to **10 in 30 frames** (one every three), against the ambient's ceiling of **15 paints per 30 frames** at 60 Hz. The "before" figure is reproducible in a scratch copy of the file by reversing the painter's signal — `super(repaint: motion.repaint)` → `super(repaint: clock)` and `motion: motion` → `clock: motion.lumen` — which is the raw-clock shape; the same instrument then reports **30 in 30 frames** again |
| **THE OBSERVABLE DIFFERENCE, STATED PLAINLY** | the ripple's **sampling rate** went from the display's rate to the ambient's **20 Hz**. **That is a change in smoothness**, and it is the cost of the fix. The trade is the one the app has already made twice, deliberately: the witness sky's forty-four stars (`lib/core/design_system/widgets/witness_sky.dart:898` — the `ListenableBuilder`; the listenable at `:905`) and the gold flecks (`lib/core/design_system/effects/gold_flecks.dart:183`) both ride `motion.repaint`, and ADR-0025 and §3.2 made that trade on purpose. The ripple is the same class of thing — a seconds-long ambient loop — and it was the one that missed the budget |
| **THE APPEARANCE — MEASURED, NOT ASSUMED** | the ring's **shape, colour, period, radius and stroke** are unchanged, and the reason is structural: the ring is drawn **from the clock** — `lumen_dock.dart:1002-1004` reads `motion.lumen.seconds` at paint time — and the `repaint` signal is **not an input to the picture** (`shouldRepaint` compares only `animate` and `color`, `:1023-1025`), so the same instant draws the same ring either way. **And it was measured**: the orb's painted layer was captured in the pre-fix tree and in this one at the **same frame** and the **same clock reading**, and the two captures are **byte-identical** — **57,600** bytes of the 120×120 RGBA layer, sha256 `2995d0b6b4c0c6b3bd28fd5ee695cc0c5aadb51672c8cec2046405c08f542e74` in both. (The capture is a one-off two-tree probe and the probe is **not** in the tree; it mounts the orb under the ambient harness, waits for the **27th** gated notification, and writes the probe layer's bytes and a `.meta` sidecar. **The permanent receipt is the gate below**, which measures the same three quantities on every run) |
| **The area** | **structural**: the ring is stroked inside the orb's 30 px box (`lumen_dock.dart:809`) at up to 1.6× (`lumen_dock.dart:1010`), so the stroked circle's bounding box is 30 × 1.6 = **48 logical px**. Small. **The cost is not the pixels** |
| **The containment — after the fix** | **structural**: the ripple carries a `RepaintBoundary` **of its own** (`lib/features/dock/presentation/widgets/lumen_dock.dart:900`), so its repaint stops inside the orb and never re-records the layer that owns the dock's σ **22** `BackdropFilter` (`lumen_dock.dart:314`, the sigma at `:274`) — a composited layer in the **same** dock `Stack` (`:298`). **There are now TWO `RepaintBoundary`s in `lib/`**: the aurora's own (`lib/core/design_system/effects/lumen_background.dart:219`) and this one. **Before the fix** the aurora's was the only one, and the ring's repaint was contained by nothing |
| **THE FIX — LANDED** | the painter takes the **gated** notifier — `motion.repaint` (`neural_motion.dart:232`) — instead of the raw clock, exactly as `GoldFlecks` does (`lib/core/design_system/effects/gold_flecks.dart:183`), and the ripple's `CustomPaint` sits inside a `RepaintBoundary` of its own (`lumen_dock.dart:900`) |
| **THE GATES THAT HOLD IT** | **two**, and they hold different things. `test/painter_repaint_test.dart` holds the **rate** — Part B's row `the dock orb's ripple repaints at the ambient's paint rate` (`:1064`) reads its ceiling from `AmbientTickBudget` rather than writing it down, so the ceiling moves with the budget. `test/features/dock/presentation/dock_ripple_paint_test.dart` holds the **signal** (the painter rides the gated notifier and not the raw clock), the **containment** (the ripple's own `RepaintBoundary`, and nothing between the ring and it) and the **appearance** (the ring's painted radius, alpha and ink, against numbers read out of `eva/redesign.html:230` and `:234` at test time). **And the new gate carries a negative control**: it measures a painter that rides the **raw** clock, in the same file, with the same instrument, and requires the instrument to report that painter as **over budget** — an instrument that cannot tell a gated painter from an ungated one is green about nothing |
| **WHAT WAS UNPINNED, AND WHAT IS NOT NOW** | before this change **no test in the tree would have failed if the ripple's radius, alpha, stroke or ink had changed**. **No golden renders the dock** — the tree's golden files carry no dock image — and the dock suite's own pixel probe samples three points that are **not on the ring's band** (`test/features/dock/presentation/widgets/lumen_dock_test.dart:520-524`; the samples sit **7.1**, **8.6** and **13.6** logical px from the orb's centre, and the band runs from the disc's own edge at **15** out to **24**). A change to the ring's geometry would have been invisible. The new gate measures the ring's painted radius, alpha and ink against the prototype's own numbers, and its rate against the budget it reads |

### 5.2 The selah ring repeated forever, on a tab the reader cannot see — **LANDED: a per-tab `TickerMode` mutes it**

| | |
| --- | --- |
| **The construct** | `_BreathingButton`'s ring — the selah card's 44 px breathing circle |
| **Where** | `lib/features/home/presentation/widgets/selah_card.dart:579` and `:595` (`_controller.repeat()`), `:533` (the `SingleTickerProviderStateMixin`), `:540-543` (the controller), `:484` (the ring is mounted **unconditionally** in the card's row, not gated on the silence running) |
| **The file's own admission** | `selah_card.dart:536-540`: "**A controller of its own, and the §13.2 budget is not engaged.**" — and **that sentence is still true**: the ring owns a controller of its own, and the ambient's tick budget does not reach it. **What changed is that the tab it lives on is now muted when the reader is elsewhere** |
| **Why it used to keep running off-screen** | the card is on the home tab (`lib/features/home/presentation/pages/home_page.dart:644`), and the dock shell's `AutoTabsRouter` (`lib/app/router/dock_shell_page.dart:71-72`) keeps all three tabs alive in one `IndexedStack`. auto_route 11.2.0 wraps each inactive child in `ExcludeSemantics`/`ExcludeFocus` and **nothing else** (`auto_route-11.2.0/lib/src/router/widgets/auto_tabs_router.dart:482-488`), and `rg 'TickerMode' auto_route-11.2.0/lib/` returns **zero** matches. Flutter mutes a ticker from `TickerMode` alone (`flutter/packages/flutter/lib/src/widgets/ticker_provider.dart:468-470`) |
| **The cost, before the fix** | **measured, by the parallel lane's gate**: `test/ticker_census_test.dart`'s header records the census over a one-second window — the **home** tab read **1** live ticker and **60** frames, and the **`/journey`** and **`/communion`** tabs read the **same 1 and 60**, because it is the home tab's ring. With the ambient **running**, as it does in the app, the same three rows read **3**, **3** and **3** |
| **THE FIX — LANDED** | a per-tab `TickerMode`, in one widget: `EvaTabTickerGate` (`lib/core/design_system/widgets/eva_tab_ticker_gate.dart`) reads the tabs router's `activeIndex` and wraps the tab's content in `TickerMode(enabled: router.activeIndex == tabIndex)` (`:154-157`). It is wired into the **three** tab pages — `lib/features/home/presentation/pages/home_page.dart:282` (`tabIndex: DockTabs.home`, `:287`), `lib/features/journey/presentation/pages/journey_page.dart:139` (`:143`) and `lib/features/leaderboard/presentation/pages/communion_page.dart:64` (`:68`) — and the indices come from the one place they are published (`lib/core/navigation/dock_tabs.dart:32,35,38`) |
| **WHY A `TickerMode` AND NOT "STOP THE CONTROLLER"** | a muted ticker's **clock keeps running** — `Ticker.muted` only unschedules the tick; it does not stop the ticker and it does not null `_startTime` — so the ring's value when the reader comes back is **exactly where it would have been** had it kept breathing. **Stopping** the controller would reset the animation's phase, and a phase reset **is** a visual change. The gate's own doc argues it at `eva_tab_ticker_gate.dart:30-43`, and it is the reason the fix is a `TickerMode` and not a `stop()` |
| **AND WHY NO PIXEL CHANGES** | an `IndexedStack` **paints only the active child**, so the outgoing tab is not on screen while the swap runs — and muting it cannot change a pixel (`eva_tab_ticker_gate.dart:45-53`) |
| **THE MEASURED CHANGE** | **measured, by `flutter test test/ticker_census_test.dart`**: on the `/journey` tab the census now reads **0** live tickers and **0** frames scheduled over the one-second window, against the **1** and **60** it read before, and the home tab's ring's own `AnimationController` value is **frozen** across a 500 ms pump. In the app's own configuration — the ambient running — the tree on the `/journey` tab now carries **0** tickers **over the ambient**, where it carried **1** |
| **The area** | **structural**: 44 × 44 = **1,936 logical px** (`selah_card.dart:194`), which is **0.59 %** of the 390 × 844 surface `witness_sky.dart:854` records. **The cost is the scheduled frame, not the pixels**, and no per-frame overhead is recorded in this repository |
| **WHAT IS STILL OPEN — and it is a different question** | the ring still repeats at the **display's** rate while the reader **is** on the home tab, because the fix above mutes an **inactive** tab and does nothing to an **active** one. **That is the §13.2 budget's scope, and the ring's own file says the exclusion is deliberate** — "A control's own pulse is not an ambient orb" (`selah_card.dart:536-540`). **Whether a visible control's pulse should ride the ambient's 20 Hz is a decision, not a defect**, and this section does not make it |
| **The gates that hold it** | **two**, and they hold different things. `test/ticker_census_test.dart` is the **budget**: it asserts that a tab the reader cannot see schedules **zero** frames (`:440` and `:469`), that the ring's value does not advance while its tab is inactive (`:483`), and that the app's own tree carries **0** tickers over the ambient on the `/journey` tab. **It is GREEN.** And it is **controlled in both directions**: the same file measures a leaf that owns a repeating controller and requires the instrument to *see* it (`:297`), and the home tab's own ring is the **positive control** (`:335`) — so "zero" is a number the instrument can reach and can also fail to reach. `test/app/router/tab_ticker_gate_test.dart` is the **mechanism**: that the ring **freezes** on an inactive tab and **resumes** on the way back, that exactly **one** of the three gates is muted and it is the invisible one, that a page pumped **on its own** has **no** `TickerMode` in its tree at all, and that the shell's **400 ms tab transition still runs** — because a fix that silenced the swap would be a fix that changed a pixel |

### 5.3 The pointer path never consults the paint gate

| | |
| --- | --- |
| **The construct** | `LumenScene._onPointerMoved` — the aurora's pointer tracking |
| **Where** | `lib/core/design_system/effects/lumen_scene.dart:535-537` — `notifyListeners()` **unconditionally**; the pointer is a `ValueNotifier<Offset>` (`:279`) and the scene listens to it at `:179`; the scaffold writes it on every pointer move (`lib/core/design_system/widgets/neural_scaffold.dart:284`) |
| **The gate it bypasses** | the scene's **own** tick path gates at `lumen_scene.dart:491-493` (`if (_paintGate.isDue())`), with the gate built at `:497` from `budget.paintGate`. **The pointer path is the same object and a different rule** |
| **The scene's own statement of the cost** | `lumen_scene.dart:479-482`: "**the painter's `repaint` signal is this notifier, so an ungated notification is a full re-rasterisation of the aurora at device resolution.**" The aurora's painter is repainted by the scene (`lib/core/design_system/effects/lumen_canvas.dart:108` — `super(repaint: source)`) and the source is the scene (`lib/core/design_system/effects/lumen_background.dart:181`) |
| **The cost** | **computed, from the repository's own recorded `ns/px` rates** — the one case in this section where they apply, because the aurora *is* the fragment shader they describe. On the phone §3.1 uses (1080 × 2400, dpr 2.75): the aurora is **2.592 M device px**; shapes 0–2 cost 2.592e6 × 2.98 ns = **7.72 ms** per notification and shafts 2.592e6 × 5.04 ns = **13.06 ms**. The budget admits **30** paintings a second (`ambient_tick_budget.dart:77`), i.e. one per 33.3 ms. A pointer moving at the display's rate produces **60** notifications a second, so the pointer path can add **2 × 7.72 ms = 15.4 ms/s** (shapes 0–2) or **2 × 13.06 ms = 26.1 ms/s** (shafts) of GPU time **on top of** the budgeted paint — and it is **uncapped**: a `ValueNotifier` coalesces an *unchanged* offset, but a drag changes it on every pointer event, and the event rate is the device's input rate, not the tick budget's |
| **The fix** | gate `_onPointerMoved` on the same `_paintGate` the tick path uses (`lumen_scene.dart:497`) |
| **The gate that will hold it** | `test/painter_repaint_test.dart` — Part B, the rate half (`:19-22`), is where "a painter driven by a `Listenable` repaints at most *N* times a second" belongs. **Part B exists now** and carries four rows — the dock orb's ripple (§5.1), the gold flecks, the witness sky's twinkle and its constellation painter — **and the pointer path has no row yet**, which is what this section is for |

### 5.4 The breath guide owns a private repeating controller

| | |
| --- | --- |
| **The construct** | `BreathGuideLine` — the 2 px line under the selected verse |
| **Where** | `lib/features/reading/presentation/widgets/breath_guide_line.dart:51-55` (the controller), `:76` (`_controller.repeat()`), `:53` (its duration, `kBreathCycle` = **8 s**, `lib/features/reading/domain/breath_guide.dart:11`), `:125` (the `Opacity`), `:134` (`width: double.infinity`) |
| **The scope of the cost** | **structural**: the guide is mounted only while a verse is selected (`reading_page.dart:978-980`), so it is **not** a permanent cost — it is a cost the reader pays *for as long as a verse is selected* |
| **The area** | **structural**: the guide is `BreathGuideLine.height` = **2** px (`breath_guide_line.dart:36`) and **full width**, so on the 390-wide surface `witness_sky.dart:854` records it is 390 × 2 = **780 logical px** — **0.24 %** of the surface. **The pixels are not the cost** |
| **The cost** | **the frame the controller schedules**, at the display rate, with nothing in the tick budget counting it. **No millisecond figure is stated**: the repository records no per-frame overhead for a scheduled frame, and the aurora's `ns/px` are a shader's rates and do not apply to a widget's `Opacity` |
| **The fix** | drive the guide from the shared `lumen` clock — it is a phase, and the phase arithmetic already exists as a pure function (`lib/features/reading/domain/breath_guide.dart:107`) — or give it its own `AmbientTickGate` at the paint rate |
| **The gate that will hold it** | **none yet, and the row's own suggestion is not one.** `test/ticker_census_test.dart` is a **ticker** census, and the guide is a ticker the budget does not see — but that census measures the **dock shell's three tabs**, and the guide lives on `/reading`, which is a **push route** and not a tab (`lib/app/router/dock_shell_page.dart:71-72` registers the three tabs; the redesign opens `/reading` over the shell). **So the census cannot see this widget, and the gate for it is still open** |

---

## 6. The rebuild cost no gate measures

**What this section is.** §1–§2 record the rebuild boundary and the gate that
holds it. The gate mounts **two** screens — `/reading` and `/settings` — bare
(`test/rebuild_isolation_budget_test.dart:59` and `:185`) — and the instrument
it uses **subtracts the ambient by design**
(`test/support/rebuild_counter.dart:23-33`), because two of the pages it
measures mount ambient animation and a raw count would measure the ambient
rather than the action. **That subtraction is a strength for the two screens
it covers and a blind spot for everything else**: a rebuild that the ambient
causes is invisible to it by construction, and a screen that is not mounted at
all is not measured at all.

### 6.1 The witness sky rebuilds forty-four stars twenty times a second

**The forty-four is the CAP** — `UserSettings.starCount`
(`lib/core/domain/entities/user_settings.dart:164`) — and the sky draws one
star per **lit** entry (`witness_sky.dart:981`), so a reader who has just
opened the app has lit none. **Measured** (§8): `/reading` mounts **6**
`OpacityLayer`s at rest, and lighting all forty-four adds **exactly 44**.

| | |
| --- | --- |
| **The construct** | `WitnessSky`'s `_SkyStars` — 44 stars, each a `Positioned` / `Transform.scale` / `Opacity` / `DecoratedBox` / `SizedBox` chain |
| **Where** | `lib/core/design_system/widgets/witness_sky.dart:897-918` — `Positioned.fill(child: ListenableBuilder(listenable: motion.repaint, …))`; the listenable is at `:905` and the `_SkyStars` at `:906` |
| **The gate that covers it** | the **20 Hz** notification budget — `notifyEveryNTick: 3` at 60 Hz (`lib/core/design_system/effects/ambient_tick_budget.dart:78`), applied at `neural_motion.dart:165-166` |
| **The size of the rebuild** | **structural, and the file's own**: "44 stars × 5 widgets … is ~**265 elements re-instantiated per frame**" (`witness_sky.dart:849-852`), with "forty-four composited `Opacity` layers and eighty-eight shadow blurs" (`neural_motion.dart:104-105`); the two `BoxShadow`s are at `witness_sky.dart:1037-1039` and the `Opacity` at `:1052`. **The forty-four is the CAP, not a mounted count** — it is `UserSettings.starCount` (`lib/core/domain/entities/user_settings.dart:164`), and the sky draws one star per **lit** entry (`witness_sky.dart:981`), so a reader who has just opened the app has lit none. **Measured** (§8): `/reading` mounts **6** `OpacityLayer`s at rest, and lighting all forty-four adds **exactly 44** |
| **The cost** | **computed from the repository's own measured per-frame figure**: the sky's own table (`witness_sky.dart:855-873`) measures **2,214 µs/frame** at 44 stars against **658 µs** at 0, over 120 frames in `flutter test` — a **debug JIT under fake async**, so an **upper bound** and not a device number, exactly as the file says at `:855-856`. At the gated 20 Hz that is 2,214 µs × 20 = **44.3 ms of UI-isolate time per second**; at the ungated 60 Hz it would have been 2,214 × 60 = **132.8 ms/s**. The budget is therefore worth **88.5 ms/s** on this one widget — which is the whole point of the budget, and also the whole of what the budget does not remove |
| **THE REDUCED-MOTION CLAIM IS REFUTED** | the audit claimed the rebuild continues under reduced motion "for a pixel-identical result". **It does not.** `lib/app/app.dart` — `_animationsEnabled` (`:346-352`) reads the platform's `disableAnimations` and the reader's stored preference, and it is passed as `NeuralMotionScope(animationsEnabled: …)` (`:362-363`); `neural_motion.dart:286-301` then **stops both clocks** (`float.stop(canceled: false)`, `lumen.ticker.stop(canceled: false)`). A stopped `AnimationController` does not tick, so `motion.repaint` does not fire and the `ListenableBuilder` does not rebuild. The `twinkleOn: false` branch (`witness_sky.dart:837`) is reached for the build that follows the change and then **not again** — the wake-up stops with the value. **What survives** is the *shape* of the claim: the twinkle-derived opacity and scale (`witness_sky.dart:1011,1019`) are the only things the rebuild recomputes, so a rebuild that changes nothing produces a pixel-identical tree — which is what the notification budget already caps |
| **The fix** | the sky's own file already names it: one `CustomPainter` drawing the shapes, the glows and the twinkle into a canvas on `repaint: motion.repaint`, "**exactly what `GoldFlecks` does**" (`witness_sky.dart:874-877`). That is a redesign of the widget's internals, and the file explains why it was not done here |
| **The gate that will hold it** | `test/rebuild_isolation_budget_test.dart` — the instrument is right; what it lacks is a **sky** case. The instrument's ambient subtraction (`test/support/rebuild_counter.dart:23-33`) is what makes such a case hard, and `test/ticker_census_test.dart` shows the way round it: hold the ambient still and measure the rest |

### 6.2 `/communion` builds every row eagerly and animates all of them

| | |
| --- | --- |
| **The construct** | the board's row list |
| **Where** | `lib/features/leaderboard/presentation/pages/communion_page.dart:169` — a page-wide `BlocBuilder<LeaderboardCubit, LeaderboardState>`; `:405-419` — the eager `for (final (int index, LeaderboardRow row) in listRows.indexed)` loop, inside the `Column`; the scroll view is `lib/core/design_system/widgets/neural_scaffold.dart:408` and the page passes `scrollable: true` (`communion_page.dart:172`) |
| **The cap** | **structural**: the server's limit is 50 (`lib/features/leaderboard/presentation/bloc/leaderboard_cubit.dart:127`) and the board skips the three podium rows (`communion_page.dart:376` — `sorted.skip(3).toList()`), so the page builds **≤ 47 rows** |
| **The observed shape** | **measured against the deployed backend**: **3 rows** (`docs/BACKEND-VERIFICATION.md:199`). The 47 is the **cap**, not the observed shape |
| **The per-row cost** | **structural**: one `AnimationController` per row (`lib/core/design_system/widgets/leaderboard_row_tile.dart:226-231`), with the stagger `80 + k·45` ms (`:211-212`; constants at `:191` and `:194`) and a 300 ms entrance (`:188`). For the last row (k = 46) the delay is 80 + 46 × 45 = **2,150 ms**, so that row's entrance finishes **2,450 ms** after the board is built |
| **The keys** | **structural**: the rows carry **no** `key` — the call site (`communion_page.dart:406-419`) passes none, and `LeaderboardRowTile` takes `super.key` (`leaderboard_row_tile.dart:142`) |
| **The cost** | **computed**: at the cap, **47 live tickers** and a board that is animating for **2,450 ms** after it mounts. The tickers are **one-shot** (`forward()`, not `repeat()` — `leaderboard_row_tile.dart:231`), so they do not run forever; the cost is 47 rows **built at once** and 47 entrances overlapping |
| **The fix** | build the rows lazily — a `ListView.builder` inside the scaffold's scroll view — and give each row a `ValueKey` of its `userId`, so a re-rank **updates** a row rather than remounting it |
| **The gate that will hold it** | `test/rebuild_isolation_budget_test.dart` — the instrument is right; it needs a **`/communion`** case, and the ambient must be held still to make the number mean what it says |

### 6.3 The three servant pages rebuild the whole form on every keystroke

| | |
| --- | --- |
| **The construct** | the servant portal's three forms |
| **Where** | `lib/features/servant/presentation/pages/servant_report_page.dart:118`, `lib/features/servant/presentation/pages/schedule_reading_page.dart:53`, `lib/features/servant/presentation/pages/question_authoring_page.dart:103` — a **page-wide** `BlocBuilder` **above** every controlled field |
| **The mechanism** | **structural**: a field reports every distinct keystroke (`lib/core/design_system/widgets/eva_controlled_field.dart:342-347`), the cubit emits on every report (`lib/features/servant/presentation/cubit/question_authoring_cubit.dart:376-380`; `servant_report_cubit.dart:424,429`), and the emit rebuilds the whole body above it |
| **The cost** | **computed**: the forms hold **two** controlled fields (the report, `servant_report_page.dart:194,204`), **eight** (the schedule, `schedule_reading_page.dart:150-233`) and **six** (the question editor, `question_authoring_page.dart:196-299`). Typing a forty-character answer therefore rebuilds the **whole** editor **forty times** — and the editor's own doc says why the builder is where it is: "**THE BUILDER IS **ABOVE** THE EDITOR**" (`question_authoring_page.dart:98-102`) |
| **The fix** | narrow the builder: a `BlocSelector` per field, or a per-field `ValueListenable` over the field's own slice of the state. **The controlled-field contract does not have to change** — the field already holds the text and reports it |
| **The gate that will hold it** | `test/rebuild_isolation_budget_test.dart` — one case per page, the same shape as the `/settings` case at `:181` |

### 6.4 `EvaTypography.textTheme(...)` is called from **sixteen** sites, not two

**The old row in §4 named two.** There are **sixteen** — twelve in the
features, three inside the type system itself, and the theme's own one.

| # | the group of sites | the file:line |
| --- | --- | --- |
| 1 | the verse's body style **and** its numeral style — **twice per visible verse build** (the two helpers are called at `:260` and `:287`, and each rebuilds a whole `TextTheme`) | `lib/features/reading/presentation/widgets/verse_line.dart:357`, `:419` |
| 2 | the reading app bar | `lib/features/reading/presentation/widgets/reading_app_bar.dart:225`, `:355` |
| 3 | the quiz CTA | `lib/features/reading/presentation/widgets/reading_quiz_cta.dart:165`, `:184` |
| 4 | the reading pill | `lib/features/reading/presentation/widgets/reading_pill.dart:341` |
| 5 | the greeting block | `lib/features/home/presentation/widgets/greeting_block.dart:120` |
| 6 | the library carousel | `lib/features/home/presentation/widgets/library_carousel.dart:378` |
| 7 | the streak chip | `lib/features/home/presentation/widgets/streak_chip.dart:169` |
| 8 | the journey's hero number | `lib/features/journey/presentation/widgets/journey_hero_number.dart:113` |
| 9 | the journey's identity line | `lib/features/journey/presentation/widgets/journey_identity.dart:60` |
| 10 | **the type system's own three derivations** — each rebuilds a whole `TextTheme`, and each calls it **unqualified** | `lib/core/design_system/tokens/eva_typography.dart:179` (`scriptureLatin`), `:188` (`scriptureArabic`), `:198` (`monoCaps`) |
| 11 | the theme's own — **the one that already holds the answer** | `lib/core/design_system/theme/eva_theme.dart:59`, installed at `:85` |

*(Rows 1–9 are the **twelve** feature sites: row 1 is two, rows 2 and 3 are
two each, rows 4–9 are one each — 2 + 2 + 2 + 1 + 1 + 1 + 1 + 1 + 1 = **12**.
Row 10 is the type system's own **three** — `scriptureLatin`, `scriptureArabic`
and `monoCaps` — and they are the three a scan for `EvaTypography.textTheme(`
**cannot see**, because they call it unqualified from inside the class. Row 11
is the theme's own one, and it is the one that already has the answer.
**12 + 3 + 1 = 16.**)*

| | |
| --- | --- |
| **The construct** | `EvaTypography.textTheme(EvaColors)` |
| **Where** | `lib/core/design_system/tokens/eva_typography.dart:138-167` — `_geometry.apply(...)` (15 styles) then a **fifteen**-field `copyWith` whose every field runs `serif(…)`/`ui(…)` (`:144-146`), so about **30 `TextStyle` allocations per call** |
| **The duplication** | the theme already builds the **same** `TextTheme` **once** into the `ThemeData` (`eva_theme.dart:59` → `:85`), with the families already applied |
| **The cost** | **computed**: 16 sites × ~30 allocations = **~480 `TextStyle` allocations** in a rebuild that touches all sixteen. The reader's verse list alone, at the **five** visible verses the budget test's own baseline prints (`VerseLine × 5`, `docs/PERFORMANCE.md` §2.2), rebuilds 5 × 2 = **10** of them — **~300 allocations per verse-list rebuild** |
| **The per-call figure** | **printed, not asserted**: `test/rebuild_isolation_budget_test.dart:316-320` prints `µs/call`, and the assertion at `:328` is `expect(perCall, greaterThan(0), reason: 'the measurement must have run.')` — which **cannot fail**, because a clock that ran is greater than zero. The "~15 µs per call" in §4 is therefore **one machine's printout**, not a budget; the same command on another machine prints a different number, and on the machine that measured it on 2026-10-22 it read **18.3 µs/call over 2000 calls** — a **debug JIT under fake async**, so an **upper bound** and not a device number |
| **The fix** | read the theme's `TextTheme` — `Theme.of(context).textTheme` — or hold one `TextTheme` per `EvaColors` in the scope. The theme's `TextTheme` **is** the Eva one, so this is a de-duplication and not a change of appearance |
| **THE GATES THAT HOLD IT** | **two**, and they hold different things. `test/text_theme_callsite_test.dart` is the **count**: a source scan over `lib/` finds every `textTheme(` call site — **qualified and unqualified** — and requires each one to be on a **reviewed allowlist** of **16** sites across **11** files; a **new** site is red, a **stale** allowlist row is red, and **a scan that finds nothing is red too**, because that means the matcher rotted. The same file also holds the **equality proof** — the reason de-duplicating a call site would be *safe* rather than a visual change — by diffing all **fifteen** slots field by field, for **dark × light** and **en × ar**, and requiring the diff to be empty. `test/rebuild_isolation_budget_test.dart` is the **cost**, and its assertion at `:328` has to change from `greaterThan(0)` to a **budget** for that half to hold anything |

---

## 7. The data layer

**What this section is.** The first two sections are about the frame. This one
is about the **work behind the frame** — the writes, the parses and the
requests — and it is here because a UI cost is often a data cost wearing a
different hat.

### 7.1 Every settings write rewrote all twenty-nine preference keys — **LANDED: a write now writes only the keys that changed**

| | |
| --- | --- |
| **The construct** | `SettingsLocalDataSource.write` |
| **Where** | `lib/features/settings/data/datasources/settings_local_data_source.dart:374-539` — the write, whose **every one** of the twenty-nine branches is now **conditional**; the file's own heading, "THE TWENTY-NINE WRITES", is at `:325`; the diff base is `_lastWritten` (`:186`) |
| **Who calls it** | **every** `SettingsCubit.apply` — `lib/features/settings/presentation/cubit/settings_cubit.dart:433-445` |
| **What one write costs** | **structural, and the platform's own**: `shared_preferences_linux-2.4.1/lib/shared_preferences_linux.dart:305-317` reads the **whole** map, sets the one key, and calls `_writePreferences`; `:373-399` then does `json.encode(preferences)` — **the whole map re-encoded** — and `localDataFile.writeAsStringSync(stringMap)` — a **synchronous whole-file write**. The version is pinned by `pubspec.lock:696-703` |
| **How many applies a drag makes** | **structural**: `lib/core/design_system/widgets/eva_range_slider.dart:235-251` fires `onChanged` on every `onHorizontalDragUpdate` — **once per pointer update**. The hue slider is 0…360 with step 1 (`lib/features/settings/presentation/pages/settings_page.dart:592-602`; `kHueMin`/`kHueMax` at `lib/features/settings/domain/settings_clamps.dart:107,110`), the track is **120** px (`eva_range_slider.dart:147`) and the travel is `width − thumbSize` = 120 − 15 = **105 px** (`:230`, thumb at `:164`). 360 units over 105 px is **3.43 units per pixel**, so the value changes on essentially every pixel of the drag |
| **The cost, before the fix** | **computed, and the per-write cost is an ESTIMATE**: 29 keys × ~105 pointer updates = **~3,045** whole-file writes in **one** full-width drag of the hue slider, and each write re-encodes and re-writes the **whole** preference file — so the bytes written over one drag are 3,045 × (the whole map's JSON), not 3,045 small deltas. **The cost per write is an ESTIMATE and is NOT a measurement**: this repository records no timing for `shared_preferences` on Linux, so **no millisecond figure is stated here**. The **count** is arithmetic on the repository's own numbers; the **cost** is not known here |
| **THE MEASURED CHANGE** | **measured, by `flutter test test/features/settings/data/settings_write_diff_test.dart`**: a full **105**-step hue drag went from **3,045** preference writes to **133** — the first save has no base to diff against, so it writes all **twenty-nine** keys, and each of the next **104** saves writes the **one** key that changed. A save that changes **one** setting performs **one** write; a save that changes **nothing** performs **zero** |
| **THE TWO PROPERTIES THE CHANGE HAD TO PRESERVE** | **the first write still writes every key** — a first write that skipped a key would leave the store half-written, and a reader would lose that setting on the next launch — and a **dropped** language still **removes** its key rather than writing an empty string (`eva.language` absent means "follow the platform", and `ReadingLanguage.fromCode('')` is `null`, so a written `''` would leave a key in a form no other code writes). **Both are asserted**, and the stored state after any sequence of writes is **identical** to the old unconditional path's — the proof is a **differential test** that keeps the old implementation as a reference implementation and compares the two resulting preference maps, key for key and value for value (`test/features/settings/data/settings_write_diff_test.dart`) |
| **THE FIX — LANDED** | `write` keeps the record it last wrote (`_lastWritten`, `settings_local_data_source.dart:186`) and writes only the keys that differ from it. **The invariant it rests on**: after every **successful** write the store holds exactly the record it was given, for the twenty-nine keys the class owns. **That invariant has exactly one way to break, and it is not a bug in the data source — it is a second writer** — so "the settings keys are written in exactly one place" is a load-bearing property, and `test/features/settings/data/settings_single_writer_test.dart` is the gate that holds it |
| **WHAT WAS **NOT** DONE, AND WHY — there is no debounce** | the fix does **not** coalesce or debounce the slider's writes, and it cannot: `SettingsRepository.save` returns **the stored value** (`lib/core/domain/repositories/settings_repository.dart:72` — "Persists [settings], and returns what was persisted"), the implementation returns the record it was given (`lib/features/settings/data/repositories/settings_repository_impl.dart:56-63`), and `SettingsCubit._persist` treats a successful save as **"the device holds this"** (`lib/features/settings/presentation/cubit/settings_cubit.dart:448-477` — the success arm takes **the store's answer**, not the value that was asked for, and emits it as the confirmed settings). A coalescing flush would make `save(A)` return `A` while the store holds `B` — and the cubit would then publish a value the device does not have. **The diff is what makes the drag cheap without changing the contract**; the debounce would change the contract instead |
| **THE GATES THAT HOLD IT** | **three**, and they hold different things. `test/features/settings/data/settings_write_diff_test.dart` holds the **write count** and the **stored state** — the count is *measured* by an instrumented store rather than asserted from the code's shape, and the stored state is a **differential** comparison against the old path. `test/features/settings/data/settings_single_writer_test.dart` holds the **single-writer invariant** the diff rests on. `test/features/settings/data/settings_local_data_source_test.dart` is the **round trip** — the expensive half neither of the other two may break |

### 7.2 Every response this app fetches is decoded on the UI isolate

| | |
| --- | --- |
| **The construct** | dio's response transformer |
| **Where** | `lib/core/network/dio_client.dart:78-90` — the `Dio(BaseOptions(…))` sets **no** `transformer:`, so dio's default applies |
| **What the default is** | dio **5.11.1** (`pubspec.lock:244-251`): `Transformer transformer = FusedTransformer(contentLengthIsolateThreshold: 50 * 1024)` (`dio-5.11.1/lib/src/dio_mixin.dart:50-52`). The threshold decides (`dio-5.11.1/lib/src/transformers/fused_transformer.dart:146-147`): `contentLength >= contentLengthIsolateThreshold` ⇒ an **isolate** (`:148-166`); below it ⇒ the **main** isolate (`:167-175`, the decode itself at `:172`) |
| **THE AUDIT'S `-1` IS WRONG FOR THE PINNED VERSION** | `-1` is the `FusedTransformer` **constructor's** own default (`dio-5.11.1/lib/src/transformers/fused_transformer.dart:26-28`), which `DioMixin` overrides with 50 KB. A `-1` threshold would mean "**always** on the main isolate"; the pinned dio means "**under 50 KB on the main isolate, at or over 50 KB in an isolate**". The audit's conclusion happens to survive — but for a different reason, and a document that stated the wrong reason would teach the wrong thing |
| **The bodies** | **measured against the deployed backend on 2026-10-22**: the English reading **1,496 bytes**, the leaderboard **477 bytes**, the daily report **963 bytes** (the same figure `docs/BACKEND-VERIFICATION.md:386` records). Reproduce with:<br>`curl -s -o /dev/null -w '%{size_download}\n' -H 'X-Group-Id: 3' -H 'X-User-Id: 11111111-1111-4111-8111-111111111111' 'https://evangelion-backend.vercel.app/api/v1/readings/today/en?date=2026-10-19'` |
| **The cost** | **computed**: every one of those bodies is **under 50 KB**, so every one of them is decoded **on the UI isolate**. The app itself never offloads a parse either: `rg 'compute\(\|Isolate\.' lib` returns **zero** matches |
| **The fix** | none is needed at today's body sizes. A reading's **Arabic** arm and a fifty-child board would still be a few kilobytes. The thing worth saying is that **the app's decode cost is bounded by the backend's response size and the app does not control either** |
| **The gate that will hold it** | a source-level assertion that no `transformer:` is set, or a decode-cost budget — and **the honest gate is a body-size budget** on the backend's answers, not a Flutter one |

### 7.3 Nothing is cached, and `/` refetches on every return

| | |
| --- | --- |
| **The construct** | the re-entry path |
| **Where** | `lib/features/home/presentation/pages/home_page.dart:520-522` — `didPopNext()` ⇒ `_load()`; the same shape at `lib/features/journey/presentation/pages/journey_page.dart:287-289` |
| **What one re-entry costs** | **structural**: `lib/features/home/presentation/bloc/home_bloc.dart:273-294` starts **five** loads in flight together — the bloc's own heading at `:252` says "**THE FIVE REQUESTS ARE **IN FLIGHT TOGETHER**". **Three** of the five are network calls (`GET /readings/today`, `GET /streak/summary`, `GET /streak`); **two** are local — the reader's session comes from `FakeAuthRepository` (decision 3: login is UI-only) and the catalogue is a literal behind a port (`lib/features/home/data/repositories/library_catalogue_repository_impl.dart:38-46` over a `LibraryCatalogueLocalDataSource`) |
| **What is cached** | **nothing, on the network side**: `rg -in 'memoiz\|cache\|_cached' lib/features/*/data/repositories/` returns **one** hit, and it is `FakeAuthRepository`'s **session** (`lib/features/auth/data/repositories/fake_auth_repository.dart:121-123`) — the local fake, not a response |
| **The cost** | **computed**: every return to `/` re-issues **three** network requests and re-runs the page's build. The journey page shows its **loading** arm again on every return (`journey_page.dart:282-285`); the home page does **not** — `HomeSectionStatus` **has** a `loading` value (`home_bloc.dart:90`) and `_onStarted` never emits it; it goes straight to `ready`/`failed` (`home_bloc.dart:418-432`), so the reader sees the **previous** content until the new one lands |
| **The fix** | keep the answers the page already has and re-fetch only what a return can have changed — the streak, after a quiz. The `HomeBloc` is a **process singleton** (`lib/app/di/navigation_injection.dart:365`, `registerSingleton<HomeBloc>`), so the answers it already holds are the cache, and nothing reads them on re-entry |
| **The gate that will hold it** | `test/rebuild_isolation_budget_test.dart` and a request-count assertion over a `didPopNext` — a cubit test that counts the loads a re-entry issues |

### 7.4 `ReadingCubit.load()` has no generation guard

| | |
| --- | --- |
| **The construct** | `ReadingCubit.load` |
| **Where** | `lib/features/reading/presentation/bloc/reading_cubit.dart:183-192` — the cubit awaits `loadScripture(language)` and emits whatever answers, with **no** generation counter |
| **What the other two do** | **structural**: `lib/features/leaderboard/presentation/bloc/leaderboard_cubit.dart:150` (`int _generation = 0;`), `:166` (`final int generation = ++_generation;`) and `:190` (`if (generation != _generation) return;`); `lib/features/journey/presentation/bloc/journey_cubit.dart:150,154,175` — the same three lines |
| **The cost** | **this is a CORRECTNESS issue that happens to live in the performance lane.** The reader's language switch fires two loads; if the older one answers last, the page shows the **other** language's passage under the new language's chrome — which is the exact confusion `LeaderboardBoard.window` exists to catch, and the leaderboard's own doc says why the counter is the whole fix (`leaderboard_cubit.dart:145-149`). The performance cost of the same defect is that **both** requests run and the older response's `emit` is a rebuild the reader then watches get replaced |
| **The fix** | the counter the other two cubits already have — three lines, and the leaderboard's are the worked example |
| **The gate that will hold it** | a cubit test that resolves two loads **out of order** and asserts the newer state wins. `leaderboard_cubit_test.dart` and `journey_cubit_test.dart` are the precedents |

### 7.5 What this section is not

**None of the above is a device measurement.** §3.4 is the section that names
the on-device instrument, and the instrument is **built** — the recorder is
`lib/core/diagnostics/frame_timing_recorder.dart` behind the compile-time flag
`PERF_TRACE`, and its runbook is `tool/perf/README.md`. **But no
profile-mode run on a reader's phone has happened**, and nothing in §5, §6 or
§7 may be read as one.

What §5–§7 contain is:

* **computed** numbers, labelled as such, with the arithmetic shown — and
  computed from the repository's **own** recorded rates
  (`lumen_tier.dart:63-64`'s `ns/px`, the sky's own measured µs/frame table at
  `witness_sky.dart:855-873`, the 30/20 Hz budget divisors, the structural
  counts at the `file:line` each one carries);
* **measured** numbers, each carrying the command that produced it — the
  response sizes in §7.2, the deployed cohort of 3 in §6.2, the ticker census
  in §5.2 (measured by the parallel lane's gate, whose own header carries the
  table), the ripple's repaint rate in §5.1, the `textTheme` call-site count
  in §6.4, and the settings write count in §7.1;
* and **one** estimate, labelled as an estimate: the per-write cost of a
  preference write in §7.1, where the **count** is arithmetic and the **cost
  is not known**.

**The number this file most wants and does not have** is a per-pixel cost for
the two things the aurora's `ns/px` do not describe: the dock's σ 22 backdrop
blur and a Flutter widget's own paint. **Both are unrecorded**, and this file
states the areas and the frequencies instead.

---

## 8. The layer census — what `/reading` and `/` actually mount

**What this section is.** §1–§2 count **rebuilds**; §3–§7 count **work**. This
one counts **structure** — the layers the engine actually composites, and the
area they paint — and it is the measurement that corrected §2.2.

**The instrument** is `test/support/layer_census.dart`, and the gate is
`test/layer_census_test.dart`:

```bash
flutter test test/layer_census_test.dart
```

It walks the **render-object layer tree** — the tree the engine composites,
not the widget tree — so a `BackdropFilter` *widget* is not a layer, while a
`RenderOpacity` *is* one. A route the `Overlay` has covered is `Offstage`,
owns no layer, and is not counted.

**And it carries a negative control**: the gate hands the census one filter it
cannot possibly miss and requires it to count **exactly one**, because a
census that counts nothing is a green gate over nothing.

### 8.1 The two screens, measured

| | `/reading` (430×932) | `/` (390×844) |
| --- | --- | --- |
| **mounted layers** | `OffsetLayer × 9`, `OpacityLayer × 6`, `PictureLayer × 6`, `ClipRectLayer × 1`, `TransformLayer × 1` | `PictureLayer × 11`, `OffsetLayer × 9`, **`BackdropFilterLayer × 2`**, `ClipRRectLayer × 2`, `ClipRectLayer × 2`, `OpacityLayer × 2`, `TransformLayer × 1` |
| **backdrop filters** | **0** | **2** |
| **repaint boundaries** | **15** — 8 `RenderRepaintBoundary`, 5 `RenderAnimatedOpacity`, 1 `RenderOpacity`, 1 `RenderViewport` | **11** — 7 `RenderRepaintBoundary`, 2 `RenderOpacity`, 1 `RenderViewport`, 1 `_RenderSingleChildViewport` |
| **painted area** | **3,456,256 logical px²** — **8.6 screens** of 430×932 | **2,069,580 logical px²** — **6.3 screens** of 390×844 |

Every cell is what `flutter test test/layer_census_test.dart` printed on
2026-10-22. The framework's own
`AnnotatedRegionLayer<SystemUiOverlayStyle> × 1` is mounted on both screens and
is not listed above.

**The area is the finding, not the count.** On `/reading`, **eighty-one per
cent of the composited area is full-screen layers** — the three full-screen
`RenderRepaintBoundary` layers (3 × 430×932 = 1,202,280 px², **35 %**), one of
which is the aurora's own
(`lib/core/design_system/effects/lumen_background.dart:219`), and the Material
page route's four `FadeTransition` opacities (4 × 430×932 = 1,603,040 px²,
**46 %**) — and the content, the verse rows and the app bar, is **under a
tenth**. That is the number §3.1 is arguing about: the budget counts
**logical** pixels, and the cost it protects is **device** pixels.

**And the mounted boundaries are worth naming, because a count is not
actionable.** On `/reading`, one of the three full-screen
`RenderRepaintBoundary` layers is the aurora's own
(`lib/core/design_system/effects/lumen_background.dart:219` — the app's own
boundary, the one that makes "the page above never rebuilds" a property of the
tree rather than an intention). On `/`, one of the seven is a **30×30** one —
the
dock's mini-orb, whose ripple carries its own boundary
(`lib/features/dock/presentation/widgets/lumen_dock.dart:900`; the orb's
diameter is `LumenOrb.diameter` = 30 at `:809`). Every other repaint boundary
on these two screens is the framework's own.

**These counts are a snapshot, and `rg 'RepaintBoundary' lib/' is the command
that re-checks the source side of them.** The `/` column moved while this file
was being written — the dock's ripple gained its boundary after the first
measurement — so the **7** and the **30×30** are the 2026-10-22 values.

### 8.2 The witness sky — one layer per LIT star, and the forty-four is a CAP

| the question | the measured answer |
| --- | --- |
| `OpacityLayer`s mounted on `/reading` **at rest** | **6** |
| `OpacityLayer`s added by lighting **all 44** stars | **exactly 44** |
| logical px² added by those 44 stars | **738.77** — **0.18 %** of the 430×932 surface, and **0.02 %** of the screen's 3,456,256 px² of composited area |

**And the delta is the app-controlled measurement**: the framework's four
route-transition layers are in both halves and cancel, so a Flutter change to
the page transition cannot move it.

**The forty-four is `UserSettings.starCount`**
(`lib/core/domain/entities/user_settings.dart:164`) — the **cap**, not a
mounted count. `WitnessSky` draws one star per **lit** entry
(`lib/core/design_system/widgets/witness_sky.dart:981`), and the `Opacity`
that becomes a layer is at `witness_sky.dart:1052`.

**"How many layers" and "how many pixels are being re-recorded" are different
questions**, and the sky is the cleanest proof in the tree: forty-four stars
are **forty-four composited layers** and **738.77 logical px²** between them. The
**layer count** is the budget that matters here — a composited layer is a
texture the rasteriser has to allocate and the compositor has to hand around,
and its cost does not shrink with its size — while the **area** is what §3.1's
aurora budget is about, and the stars are not what that budget is protecting.

### 8.3 `/` mounts exactly TWO backdrop filters, and `/reading` mounts NONE

| the filter | where it comes from |
| --- | --- |
| the dock's **σ 22** | `lib/features/dock/presentation/widgets/lumen_dock.dart:314` (the sigma at `:274`) — the redesign's own `backdrop-filter:blur(22px)` (`eva/redesign.html:210`), hand-built because `GlassSurface` paints a *panel* and the dock is a full-width **bar** |
| the verse-of-the-day card's **σ 24** | `lib/features/home/presentation/widgets/verse_of_the_day_card.dart:155` — `GlassTier.blur`, the design system's own spelling; the sigma is `kGlassBlurSigma` (`lib/core/design_system/widgets/glass_surface.dart:439`) |

**And what is not there.** `GlassTier.bloom` and `GlassTier.tint` build **no**
filter at all (`lib/core/design_system/widgets/glass_surface.dart:827-829` —
`GlassTier.tint => surface`, `GlassTier.bloom => surface`), so every other
glass surface on the screen is a translucent fill with no `saveLayer` — and
`GlassTier.blur` has exactly **one** consumer in `lib/`
(`verse_of_the_day_card.dart:155`).

**This is the runtime half of a source-level rule, and the two are
complementary.** `test/core/design_system/widgets/glass_blur_budget_test.dart`
caps blur **SITES** at **two** (`glass_blur_budget_test.dart:581-583`,
`hasLength(lessThanOrEqualTo(2))`), and its own header says why a source scan
is not enough — "**a site that MOUNTS more than once**". The census closes
that half: **`/` mounts exactly two**, and `/reading` mounts **none**, which
is free — the sanctuary has no glass in it, so a filter there would be a
per-frame `saveLayer` over a screen with nothing behind it to blur.

### 8.4 What this section is not

**None of the above is a device measurement.** The census counts **layers**
and **logical pixels** — quantities a device agrees with — under a software
rasteriser on a fake clock. A wall-clock bound asserted here would be a number
no device produces, so the census asserts **structure**, and the numbers it
records are **counts** and **areas**, not milliseconds. §3.4 is the section
that names the on-device instrument, and **no profile-mode run on a reader's
phone has happened**.

**And the counts are a snapshot of two screens at two sizes.** `/reading` is
measured at 430×932 and `/` at 390×844, at a device pixel ratio of 1.0, so
the logical pixels and the device pixels are the same number. A different
surface size changes the areas and may change the layer counts; the budgets in
`test/layer_census_test.dart` carry headroom for exactly that, and the
**composition** of each count is the actionable half.

---

## 9. Reproducing everything in this file

```bash
# the rebuild boundary — prints the numbers and asserts the budgets
flutter test test/rebuild_isolation_budget_test.dart

# the ticker census (§5.2) — a tab the reader cannot see schedules nothing
flutter test test/ticker_census_test.dart
flutter test test/app/router/tab_ticker_gate_test.dart

# the painter budget (§5.1, §5.3) — Part A, the inventory, and Part B, the rate
flutter test test/painter_repaint_test.dart

# the dock orb's ripple (§5.1) — the signal, the containment and the appearance
flutter test test/features/dock/presentation/dock_ripple_paint_test.dart

# the `textTheme` call sites (§6.4) — the count, the allowlist and the equality proof
flutter test test/text_theme_callsite_test.dart

# the settings write count and the stored state (§7.1)
flutter test test/features/settings/data/settings_write_diff_test.dart
flutter test test/features/settings/data/settings_single_writer_test.dart

# the layer census (§8) — the mounted layers, the painted area, the sky's cap
flutter test test/layer_census_test.dart

# the whole suite
flutter test

# the gates, including the two Python ones and the Linux build
tool/verify_all.sh --with-build
```

**And one of those WAS red, and the reason it was is the point.**
`test/ticker_census_test.dart` asserted that a tab the reader cannot see
schedules **zero** frames, and it read **one** — the home tab's selah ring
(§5.2). **It is GREEN now**: the per-tab `TickerMode` landed, and the census
reads **zero** live tickers and **zero** frames on an inactive tab.
**The gate was red on purpose** — a gate that lands green over a known defect
is the shape this repository has hit three times — and it is green now because
the **defect** is gone, **not** because the assertion was weakened. **The
census's scope is now settled**, and it is settled by what it measures: the
**three dock tabs**. The breath guide (§5.4) is a ticker the budget does not
see, and it lives on `/reading` — a push route, not a tab — so **the census
cannot see it and the gate for it is still open.**

**And the claims this file makes that are NOT measured on a device.** The
aurora's GPU cost (§3.1) is computed from the repository's own recorded
`ns/px` figures and the device's pixel count; §5.1's **cost** rows, §5.3 and
§5.4 are computed the same way, and §7.1's per-write cost is an **estimate**;
and the on-device frame timing (§3.4) has **no numbers yet** — the recorder is
built (`lib/core/diagnostics/frame_timing_recorder.dart`) and its runbook is
`tool/perf/README.md`, but no profile-mode run on a reader's phone has
happened. **All of them are marked, and none is stated as a measurement.**
**The ripple's repaint rate (§5.1) and the settings write count (§7.1) are
measured, but measured in a `flutter test` under fake async and a software
rasteriser** — the same upper-bound caveat this file's preamble records — and
neither is a device number.
