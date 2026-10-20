# PERFORMANCE.md — the measurements, and the commands that reproduce them

Every number in this file is produced by a command you can paste. A number
without one is not a measurement, and this repository does not accept it.

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

```
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

```
RawGestureDetector × 15, GestureDetector × 14, Text × 11, …,
VerseLine × 5, _HotGlow × 5, _Reveal × 5, …,
WitnessSky × 1, _SkyStars × 1,          ← the forty-four-star sky
NeuralScaffold × 1, Scaffold × 1, LumenBackground × 1,
ReadingAppBar × 1, ReadingPill × 1, ReadingQuizCta × 1,
SegmentedControl<ReadingLanguage> × 1, BreathGuideLine × 1
```

**The sky is the single most expensive thing on the screen** — 44 stars × 5
widgets, 44 composited `Opacity` layers, 88 shadow blurs — and it had nothing
to do with which verse was selected.

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

### 3.2 The three GPU fixes, in the order they should be landed

| # | the change | the win | the cost |
| --- | --- | --- | --- |
| 1 | **Count device pixels in the shafts gate** — `LumenTiers.resolve` takes `devicePixelRatio` | the `shafts` shape stops costing 13–15 ms/frame on a phone | **visible** to a reader who explicitly chose "shafts" (they would see "sides"); the default shape is unaffected |
| 2 | **Rate-limit the ambient to 30 Hz** — the aurora's *repaint*, not its state, with the three per-frame eases converted to per-second (`k(dt) = 1 - pow(1 - c, dt*60)`, which is **exactly** `c` at 60 Hz) | the aurora's GPU cost halves, and the two `BackdropFilter`s that blur it re-run at half the rate | none visible: a slow-drifting gradient at 30 Hz is indistinguishable from one at 60 Hz, and the motion's wall-clock trajectory is unchanged |
| 3 | **Fold the light-mode multiply into the shader** — `lumen_background.dart:189-218` wraps the aurora in a `ColorFiltered(ColorFilter.matrix(...))`, a full-screen `saveLayer` plus a full-screen 4×5 matrix pass **per frame** | one fewer full-screen pass in light mode | none visible: the mathematics is identical, and **the goldens are the acceptance test** — if they do not come back byte-identical, the change is dropped |

**And the one that needs a decision:** rendering the aurora at **half
resolution** (`Transform.scale` + a `RepaintBoundary`, with `u_res` adjusted
to the scaled size) would cut the fragment count by **4×**. The band geometry
is normalised by `u_res`, so the aurora's *shape* is unchanged — it is only
resampled. **It is visible as a slightly softer aurora**, and it is listed here
as a decision rather than a fix.

### 3.3 The on-device measurement, which does not exist yet

**A `flutter test` micro-benchmark cannot see the shader's GPU cost** — the
test rasteriser is software. The on-device instrument is
`SchedulerBinding.instance.addTimingsCallback`, which reports
`buildDuration`, `rasterDuration` and `totalSpan` per frame and works in
**release** and profile (the engine batches about once a second in release).

**It is not built yet.** When it is, it is a **profile-mode** run on the
reader's phone, and the numbers land in this file beside the ones above.

---

## 4. The CPU work that is still open

| the change | where | the win | the cost |
| --- | --- | --- | --- |
| **The `TextTheme` is rebuilt per verse** | `eva_typography.dart:138-166` — `_geometry.apply(...)` plus a fourteen-field `copyWith`, about **30 `TextStyle` allocations per call**; `verse_line.dart:357` and `:419` call it **twice per visible verse**, and `eva_theme.dart:59` **already builds the same `TextTheme` once** into the `ThemeData` | ~**15 µs** per call, ~**30 µs** per verse build | none: the theme's `TextTheme` is the Eva one, so reading it is a de-duplication |
| **The breath guide is an extra list row** | `reading_page.dart` — selecting a verse changes the list's item count, and Flutter replaces every element after the insertion point, so a tap rebuilds **two** verses rather than one | moving the guide to be a **decoration** of its anchor verse would take the tap from 55 to ~20 | **visible**: the guide's box moves, and the reading harness measures the verse rects |
| **A `GlobalKey` per verse, cleared during the build** | `reading_page.dart` — `_verseKeys.clear()` runs inside the builder, so the next build mints **new** keys and every visible verse is **deactivated and re-mounted** | a `ValueKey<int>(verse.number)` would make the row an *update* rather than a teardown | none visible |
| **One `AnimationController` per verse line** | `verse_line.dart:455-497` | twenty tickers become one | none visible |
| **`/communion` builds all fifty rows eagerly** | `communion_page.dart:154` — a non-lazy `SingleChildScrollView`, and §13 rule 5 says *"never `Column` + `map` over unbounded data"* | the board stops building fifty rows to show twelve | none visible |

---

## 5. Reproducing everything in this file

```bash
# the rebuild boundary — prints the numbers and asserts the budgets
flutter test test/rebuild_isolation_budget_test.dart

# the whole suite
flutter test

# the gates, including the two Python ones and the Linux build
tool/verify_all.sh --with-build
```

**And the two claims this file makes that are NOT yet measured on a device:**
the aurora's GPU cost (§3.1) is computed from the repository's own recorded
`ns/px` figures and the device's pixel count, and the on-device frame timing
(§3.3) does not exist yet. **Both are marked, and neither is stated as a
measurement.**
