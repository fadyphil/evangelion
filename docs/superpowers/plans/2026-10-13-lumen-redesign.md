# LUMEN Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Evangelion client's visual layer with the LUMEN redesign from `eva/redesign.html` — its palette, its WebGL aurora shader with all 14 controls, its witness sky, its five-tab dock, and the two screens §2 decision 1 cut.

**Architecture:** The shader ships as a Flutter runtime-effect `.frag` compiled at build time by the SDK's own `impellerc` — **no new dependency**, because `FragmentProgram.fromAsset` lives in `dart:ui` and `flutter: shaders:` is a pubspec stanza rather than a package. The shader's clock is an injected `Listenable` so widget tests pin `t` and the 240 existing goldens stay byte-stable. Data is hybrid: everything the live API can supply is derived from it, and the remainder sits behind stubbed repository ports.

**Tech Stack:** Flutter 3.47.4 / Dart 3.13.3, auto_route 11 (`AutoTabsRouter`), bloc 9, freezed 4, `shared_preferences`, GLSL ES source (`shaders/lumen.frag`) compiled to SkSL by the SDK's `impellerc`, `dart:ui` `FragmentProgram`.

> **"GLSL ES → SkSL" is not a claim that you author SkSL.** `impellerc` accepts only
> `--source-language=glsl|hlsl` (`impeller/compiler/types.h:44` — the enum is
> `kUnknown, kGLSL, kHLSL`). You write **GLSL ES**, byte-for-byte the WebGL
> prototype's `FRAG` string. SkSL is the engine IR the build emits into the
> `.iplr`, and Impeller re-transpiles it per backend at runtime:
> `GLSL ES → shaderc → SPIR-V → SPIRV-Cross → SkSL → GLSL/SPIR-V/MSL/HLSL`.

**Authority:** `docs/agents/AGENT_CONTEXT.md` §7 gates. This plan **reverses §2 decision 1** and therefore amends that file in Phase 0, in the same change.

---

## What was verified before this plan was written

Every claim below was measured, not assumed. A plan that asserts an unverified
fact is indistinguishable from one that guesses, so the evidence is recorded
here and the implementer should re-run the commands rather than trust it.

| Claim | How it was established |
| --- | --- |
| The shader ships with **zero new dependencies** | `FragmentProgram.fromAsset` is in `dart:ui`; `flutter: shaders:` is a pubspec stanza, not a package. §8.4 is not engaged. |
| The port compiles clean | The SDK's own `impellerc` with the exact `TargetPlatform.linux_x64` flags → **exit 0, no output**. |
| The port is *correct*, not merely compiling | Compared against a float64 CPU oracle of the **original** GLSL on real Impeller/OpenGLES: **max 0.67/255**, mean 0.25/255 per channel over 1120 samples. |
| `FlutterFragCoord()` ≠ `gl_FragCoord` | Measured with an encoding probe: **local logical pixels, top-left origin, +Y down**. Without a Y flip the bottom lantern draws at the top — negative control NC4 fired at **254/255**. |
| …and under `flutter test` it is the **same** convention | `flutter test` runs `--enable-software-rendering --skia-deterministic-rendering` (`flutter_tools/lib/src/test/flutter_tester_device.dart:113-115`), i.e. Skia, not Impeller — and `runtime_effect.glsl` has a second `SKIA_GRAPHICS_BACKEND` branch returning `gl_FragCoord.xy`. An executed probe shader (`R=fc.x/400, G=fc.y/800`, `u_res=(400,800)`) measured `y=0 → G=0`, `y=400 → G=128`, `y=799 → G=255`: **+Y down, top-left, local logical px** — identical to Impeller. **The Y flip in Task 1.1 is therefore correct in both backends, and goldens match device orientation.** |
| Runtime effects **do** work in `flutter test` | `FragmentProgram.fromAsset` loads and a `FragmentShader` paints correctly under the software rasterizer. But the raw `Picture.toImage` capture pattern **deadlocks for the full 10-minute timeout** unless wrapped in `tester.runAsync()`. See Task 1.3. |
| `u_time` does **not** decay on the timescale claimed | float32 simulation of `fbm1`: hash arguments at `t=3600 s` reach **14006** (not ±4245 — off by ~3×), but distinct output values per 4000 cells is **4001 at `t=0` and 4001 at `t=3600 s`**. Posterisation first appears at **≈10 h** (2561 distinct) and ≈100 h (161). The ~8-bit quantisation is a property of `fract(sin(n)*43758.5453)` and is present from frame one; it does not worsen with elapsed time. See Task 1.4. |
| 24 float slots, no `vec3` padding — **but NOT in declaration order** | **RETRACTED — see row 2 of the corrections ledger below.** `--reflection-json` reports SPIR-V ID order, not the runtime order; the runtime order IS declaration order (engine comment `runtime_effect_contents.cc:290-298`, render test 1/255 vs 247/255 on both renderers). Painting the JSON order gives the 247-error frame. The original claim is kept here as history; the ledger is the truth. |
| No NaN anywhere in parameter space | 186,624 shader evaluations over 979,776,000 samples across every slider extreme → **0 non-finite outputs**. |
| Every check can fail | 9/9 negative controls fire (see Task 1.1.3). |
| Hardware cost | 2.98 ns/px for shapes 0–2; **5.04 ns/px** for the shafts shape (5-iteration loop). |
| `eva/` deletion is the *only* reason gate 4 is FATAL | The root `redesign.html` is **md5-identical** (`cd019e56…`) to `eva/redesign.html` at HEAD. |
| Dark redesign palette beats the current one | On **every** role, and passes AA with margin. No changes needed. |
| Light redesign palette has 4 AA failures | Measured. All four are rendered at 8–17px. Repaired in Task 2.2. |
| 240 goldens exist | 60 widget + 16 effect + 164 negative-control failure references; 30 dark/light pairs. |
| 948 citations resolve | `ROADMAP.md` measurement, re-confirmed by Task 0.1. |

**Decisions taken without asking** (flag them if you disagree — they are
reversible):

- **Share and notes are cut.** `share_plus` is forbidden by §8.4, and there is
  no storage layer for notes. Inventing a `MethodChannel` is a larger decision
  than this plan should make silently.
- **Theme mode stays 3-state** (system/light/dark). The prototype has a 2-state
  toggle; respecting the OS preference is strictly better and changes nothing
  the redesign depends on.
- **Hue is book-driven with a user override**, matching `redesign.html:1350`
  (`setTargetHue(b.hsl, .5)`) alongside the Workshop's hue slider.
- **The shader's behaviour is preserved exactly.** Task 1.4 (the `u_time` wrap)
  is **cut** — it was the only behaviour change this plan proposed, its premise
  did not survive re-measurement, and no wrap period can achieve what it
  promised. See Task 1.4 for the measurements.

---

## Corrections applied after review

Re-measuring the plan against the installed toolchain (Flutter 3.47.4, engine
`0e228ec8c8d2`, `impellerc` from `bin/cache/artifacts/engine/linux-x64`) changed
five things. Each is marked in place with the evidence.

| # | Was | Now | Why |
| --- | --- | --- | --- |
| 1 | `u_time` wrapped (Task 1.4) | **cut**; a test asserts it stays unwrapped | Decay onset is ≈10 h not 1 h; no exact loop period exists for any `T` |
| 2 | Slot table = source declaration order | **declaration order, confirmed** — but the *reason* given was wrong | `--reflection-json` reports SPIR-V ID order, not the runtime order; the runtime order is declaration order per the engine's own comment (`runtime_effect_contents.cc:290-298`) and per a render test (1/255 vs 247/255, both renderers). The intermediate revision of this row — "reflected order, generated not hand-written" — was wrong and would have painted garbage with a green suite. See Task 1.2 Step 3. |
| 3 | `Picture.toImage` capture, bare | wrapped in **`tester.runAsync()`** + explicit `dispose()` | Bare capture deadlocks the full 10-min timeout, with or without a shader |
| 4 | Two-`dirname` `impellerc` path | **two `dirname`s + `/bin/cache`** | `<sdk>/cache/…` does not exist; artifacts are at `<sdk>/bin/cache/…` |
| 5 | Tech Stack: "GLSL ES → SkSL" | explicit that you author **GLSL ES** | `impellerc` accepts only `glsl\|hlsl`; SkSL is the IR the build emits |
| 6 | `hslToRgb(258,90,66)` ≈ `(0.545, 0.106, 0.831)` | **`(0.5376, 0.3540, 0.9660)`** `#895AF6` | Running `redesign.html:879-880` verbatim gives `(0.5376, 0.354, 0.966)`, cross-checked against the textbook C/X/m sextant conversion — **identical**. The old green channel was off by **0.248**, not rounding. The old triple is `#8B1BD4` ≈ HSL(276, 77%, 47%), a different colour entirely. |

Two claims were **confirmed and kept**: the Y flip is required (under Impeller
`gl_FragCoord` is silently aliased to the local vertex position), and it is also
correct under `flutter test`'s Skia software renderer — so goldens match device
orientation. The goldens strategy stands.

---

## File map

Every path this plan touches, with its single responsibility.

### **Created**

| Path | Responsibility |
| --- | --- |
| `shaders/lumen.frag` | The aurora shader, ported. Compiled at build time. |
| `lib/core/design_system/effects/lumen_uniforms.dart` | The 16-field uniform value object + the pure settings→uniform functions. **Pure Dart.** |
| `lib/core/design_system/effects/lumen_clock.dart` | The injectable time source. |
| `lib/core/design_system/effects/lumen_program.dart` | Asset load + memoization. |
| `lib/core/design_system/effects/lumen_canvas.dart` | The `CustomPainter`. |
| `lib/core/design_system/widgets/witness_sky.dart` | Stars, constellations, flares. |
| `lib/core/domain/entities/sky_entry.dart` | A `book:chapter:verse` key. **Pure Dart.** |
| `lib/core/domain/repositories/sky_repository.dart` | The sky port. **Pure Dart.** |
| `lib/features/sky/data/datasources/sky_local_data_source.dart` | `shared_preferences` persistence. |
| `lib/features/sky/data/repositories/sky_repository_impl.dart` | The port implementation. |
| `lib/features/sky/presentation/cubit/sky_cubit.dart` | State + events. |
| `lib/features/dock/presentation/widgets/lumen_dock.dart` | The 5-tab dock. |
| `docs/adr/0022-full-fidelity-redesign-supersedes-0001.md` | The reversal, with the fiction table. |

**Modified**

| Path | Change |
| --- | --- |
| `pubspec.yaml` | `flutter: shaders:` stanza. **No new dependency.** |
| `lib/core/design_system/tokens/eva_colors.dart` | The redesign palette. |
| `lib/core/design_system/tokens/eva_motion.dart` | Lumen motion table. |
| `lib/core/design_system/effects/neural_motion.dart` | Own the shader clock. |
| `lib/core/design_system/effects/neural_background.dart` | Shader tier + fallback. |
| `lib/core/design_system/widgets/glass_surface.dart` | `GlassTier.bloom`. |
| `lib/core/design_system/barrel.dart` | Export every new widget. |
| `lib/core/domain/entities/user_settings.dart` | +28 settings fields. |
| `lib/core/domain/repositories/settings_repository.dart` | Widen the port. |
| `lib/features/settings/**` | Data source, repo, cubit, page, l10n. |
| `lib/app/router/app_router.dart` | `AutoTabsRouter`. |
| `lib/core/navigation/app_routes.dart` | `/journey`, `/communion`; drop `/result`. |
| `lib/app/app.dart` | Theme + scope wiring. |
| `lib/l10n/app_en.arb`, `app_ar.arb` | ~90 keys ported. |
| `lib/features/*/presentation/pages/*.dart` | Every screen. |
| `docs/agents/AGENT_CONTEXT.md` | §2 decision 1 + route table. |
| `docs/ROADMAP.md` | The overhaul has landed. |
| `test/**` | Tests, goldens, re-baselined gates. |

---

# Phase 0 — Unblock

**This is not bookkeeping.** `tool/gates/citation_check.py` currently exits
**2**. `CONTRIBUTING.md`: "`2` means nothing was checked." No claim in this
plan — including the table above — can be verified until this phase lands.

> **Task 0.1 is DONE.** Gate restored to `948 found, 948 resolved, 0 broken`,
> `exit=0`. Baseline recorded: **2522 tests** (floor 2507), **98.39% coverage**
> (floor 98.25%), 13 prototype files, `git diff HEAD` empty.
>
> Three steps below were wrong about the world, and a future implementer should
> not be misled by them:
>
> - **Step 6's `sed` was a no-op.** `lib/main.dart` contains no
>   `eva/src/App.tsx:1` citation, so the planted violation changed nothing. The
>   gate was still proved fallible at a *real* citation site instead:
>   `lib/core/design_system/widgets/neural_scaffold.dart:28` → `App.tsx:99999`,
>   which yields `947 resolved, 1 broken`, `exit=1`. All three exit codes (0 / 1 /
>   2) are now demonstrated.
> - **"38 files return" is 36.** HEAD genuinely tracks 36 files under `eva/`.
> - **Step 8's commit was unnecessary.** The deletions were unstaged
>   working-tree-only and were never committed (`git cat-file -t
>   HEAD~1:eva/redesign.html` still resolves to a blob); the root
>   `redesign.html` was untracked. Restoring a dirty tree to HEAD is a zero-diff
>   operation by definition, so there was nothing to commit and no empty commit
>   was manufactured.
>
> **The consequence deserves attention:** this state was never captured by a
> commit, so it is not reproducible from a fresh clone. If a cleanup step could
> re-delete `eva/`, the durable guard belongs in `tool/verify_all.sh` — which
> already FATALs correctly on a missing reference.

## Task 0.1: Restore the design references

**Files:**

- Restore: `eva/` (deleted in the working tree, present at HEAD)
- Delete: `redesign.html` (untracked root duplicate)

- [ ] **Step 1: Confirm the current failure is the one you expect**

```bash
cd /home/fady/Projects/evangelion
python3 tool/gates/citation_check.py; echo "exit=$?"
```

Expected: `FATAL: a required design reference is missing — eva/src, eva/redesign.html.` and `exit=2`.

**If it exits 0, stop.** A green gate here means something changed that this
plan does not know about.

- [ ] **Step 2: Confirm the root file is a duplicate, not a newer design**

```bash
git show HEAD:eva/redesign.html | md5sum
md5sum redesign.html
```

Expected: both `cd019e5631c87573ffa63698e4bd3e9f`.

**If the hashes differ, stop.** A differing root file is a *different* design
and every citation in this plan would resolve against the wrong thing.

- [ ] **Step 3: Restore `eva/`**

```bash
git restore eva/
git status --short eva/
```

Expected: empty output. 38 files return, including `eva/src/App.tsx`,
`eva/src/screens/*.tsx` and `eva/redesign.html`.

- [ ] **Step 4: Remove the duplicate**

```bash
rm redesign.html
```

- [ ] **Step 5: Prove the gate now runs**

```bash
python3 tool/gates/citation_check.py; echo "exit=$?"
```

Expected: `948 found, 948 resolved, 0 broken` and `exit=0`.

**Any other number means the restore was incomplete. Stop here** — a partially
restored `eva/` produces a gate that passes over a smaller surface, which is
precisely the failure ADR-0020 exists to name.

- [ ] **Step 6: Plant a violation and prove the gate fires**

Per ADR-0020, a gate that cannot fail is worse than no gate. In a **scratch
copy outside the repository**, point one citation past end-of-file:

```bash
cp -r /home/fady/Projects/evangelion /tmp/opencode/gate-probe
sed -i 's/eva\/src\/App.tsx:1\b/eva\/src\/App.tsx:99999/' /tmp/opencode/gate-probe/lib/main.dart
cd /tmp/opencode/gate-probe && python3 tool/gates/citation_check.py; echo "exit=$?"
```

Expected: a broken-citation report and `exit=1`. Delete the scratch copy.

- [ ] **Step 7: Run the fast gates and record the baseline**

```bash
tool/verify_all.sh 2>&1 | tail -30
```

Expected: gates 1–7 `ok`. Gate 8 is opt-in. **Record the reported test count
and coverage** — that is the number Phase 7 must not drop.

- [ ] **Step 8: Commit**

```bash
git add -A eva/ redesign.html
git commit -m "chore(ci): restore eva/ and unblock the citation gate"
```

---

## Task 0.2: Record the reversal

§2 decision 1 reads *"Do not re-litigate. Do not expand scope."* This plan does
exactly that, deliberately. The authority document must change in the same
change, per `CONTRIBUTING.md`: *"If so, the authority document was updated in
the same change, with the measurement that establishes it."*

**Files:**

- Create: `docs/adr/0022-full-fidelity-redesign-supersedes-0001.md`
- Modify: `docs/agents/AGENT_CONTEXT.md` §2 (decision 1 and the route table at `:156-169`)
- Modify: `docs/ROADMAP.md` §"Design overhaul"

- [ ] **Step 1: Write ADR-0022** from `docs/adr/template.md`

Required content — the Context section must name the measurement, not the
feeling:

> **Context.** `eva/redesign.html` specifies seven screens: the six in §2 plus a
> Journey screen (profile) and a library carousel on `/`. ADR-0001 cut both.
> The backend has **no** endpoint for a book list, a profile, medals,
> verse-of-the-day, cheer, share, or notes — verified across all 14 routes.
> `GET /leaderboard` and `GET /streak` are real and map onto the redesign's
> Communion and streak surfaces. The choice was full fidelity over a
> visual-layer-only scope.

Required table — **the fiction table**, so a reader can see what is invented:

| Element | Real or stub | Replaced by |
| --- | --- | --- |
| Streak chip, hero number | real | `GET /streak/summary` |
| Communal rows, scope, countdown | real | `GET /leaderboard?window=` |
| Verse of the day | real | deterministic pick from `GET /readings/today` |
| Library book list | real | hardcoded 66; **no endpoint exists** |
| Your own name | **stub** | a real `/me` endpoint |
| Medals | **stub** | an achievements table |
| Cheer | **stub** | a POST endpoint |
| Starfield | **stub (local)** | a stars table |
| Sealed books | **stub** | per-book completion data |

- [ ] **Step 2: Amend AGENT_CONTEXT §2**

Change decision 1 to record the seven screens and cite ADR-0022. Add `/journey`
and `/communion` to the route table at `:156-169`. Remove `/result` from the
table, since Task 6.2 makes it a modal rather than a route.

- [ ] **Step 3: Update ROADMAP.md**

The overhaul section says *"The visual direction has not been decided."* It has.
Move ADR-0016/0017/0019 off `accepted — under review` and point at ADR-0022.

- [ ] **Step 4: Commit**

```bash
git commit -m "docs(adr): 0022 — full-fidelity redesign supersedes ADR-0001"
```

---

# Phase 1 — The aurora engine

> **Status: COMPLETE (commits `bf106ec`, `c3100be`, `fddee1c`, `61d9ab8`,
> `e59cce6`, `ff46582`, `551e807`, `8572aaa`, `f989784`, `2fe5ce6`).**
> Full gate green: **2609 tests** (floor 2507, baseline 2522), **98.46% coverage**
> (floor 98.25%, baseline 98.39%), citations 1001/1001. Full two-stage review per
> task (spec then quality, mutation-verified fixes). Net findings folded back
> into this plan: slot table is declaration order (corrections row 2 rewritten —
> the "reflected order" revision was wrong), `shaderIndex` not `.index` for
> layout assertions, `runAsync` mandatory, `u_time` unwrapped (Task 1.4 cut).
> Mid-phase the full suite caught two things the task-level gates could not: 4
> unregistered `identical()` sites (fixed in `f989784` — new `identical()` in
> `test/` must be added to the audited table in
> `no_identical_on_converted_types_test.dart` in the same commit), and a coverage
> dip to 98.10% from untested `toString`s (fixed in `2fe5ce6` — effects dir now
> 100%). Task 1.5's tier table: shader on for high+mid, off for low; shafts gated
> above 2M logical px (`kShaftsPixelBudget`).

The highest-risk phase, and the one the spike already de-risked. Follow the
spike's lead; do not re-derive it.

## Task 1.1: Commit the shader

**Files:**

- Create: `shaders/lumen.frag`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Write `shaders/lumen.frag`**

Port the `FRAG` template string at `eva/redesign.html:776-855` faithfully. Every
one of the 16 uniforms survives. Exactly **three** lines differ from the
original, each marked `// PORT:` with the original quoted beside it:

| # | Original | Port | Why |
| --- | --- | --- | --- |
| 1 | `#ifdef GL_FRAGMENT_PRECISION_HIGH` guard | `precision highp float;` | SkSL never defines the macro, so the guard always takes the `mediump` branch. |
| 2 | `gl_FragCoord.xy` (3 sites) | `fc` built from `FlutterFragCoord()` with a Y flip | Opposite origin. See below. |
| 3 | `gl_FragColor = …` | `out vec4 fragColor;` + `fragColor = …` | `gl_FragColor` is undeclared in SkSL. |

The coordinate block, which is the one that matters:

```glsl
#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2  u_res;   uniform float u_time;
uniform vec3  u_hue;   uniform vec3  u_hue2;   uniform vec3  u_hue3;
uniform float u_int;   uniform float u_str;    uniform float u_spike;
uniform float u_spread; uniform float u_shape; uniform float u_melt;
uniform float u_dots;  uniform float u_white;  uniform float u_light;
uniform vec2  u_ptr;   uniform float u_ptrI;
out vec4 fragColor;

void main() {
  // WebGL  gl_FragCoord      : device px, origin bottom-left, +Y up
  // Flutter FlutterFragCoord(): local logical px, origin top-left, +Y down
  vec2 fc = vec2(FlutterFragCoord().x, u_res.y - FlutterFragCoord().y);
  // … the rest is byte-identical to the original, re-indented only …
}
```

The `VERT` template string and the fullscreen triangle are **deleted, not
ported** — Flutter supplies the vertex stage, and `canvas.drawRect` replaces
`gl.drawArrays`.

- [ ] **Step 2: Add the pubspec stanza**

Under `flutter:`, after `uses-material-design: true`:

```yaml
  shaders:
    - shaders/lumen.frag
```

**This is not a dependency.** §8.4 is not engaged. `dart analyze` and
`flutter gen-l10n` must both be unaffected — verify, do not assume.

- [ ] **Step 3: Prove it compiles, using the SDK's own compiler**

```bash
FL=$(dirname $(dirname $(readlink -f $(which flutter))))/bin/cache/artifacts/engine/linux-x64
ls -la "$FL/impellerc"   # fail loudly if the path is wrong
"$FL/impellerc" --sksl --runtime-stage-gles --runtime-stage-gles3 \
  --runtime-stage-vulkan --iplr --sl=/tmp/opencode/lumen.iplr \
  --spirv=/tmp/opencode/lumen.iplr.spirv \
  --input=shaders/lumen.frag --input-type=frag \
  --include=shaders --include="$FL/shader_lib"
echo "exit=$?"
```

Expected: **exit 0 and no output at all.** Zero errors, zero warnings.

> **The `bin/` is load-bearing.** `readlink -f $(which flutter)` →
> `<sdk>/bin/flutter`; two `dirname`s stop at `<sdk>`, and the engine artifacts
> live one level deeper, at `<sdk>/bin/cache/artifacts/engine/linux-x64`.
> Both the original `<sdk>/cache/...` and a naive three-`dirname`
> `<sdk-parent>/cache/...` **do not exist**. Verified: only
> `<sdk>/bin/cache/artifacts/engine/linux-x64/impellerc` resolves.

> `--spirv` is **required** even with `--iplr`. Omitting it fails with
> `Spirv file name was empty` and exit 1. The real tool always passes it.

> **Only `gl_FragColor` is a hard compile error.** Compiling the *unmodified*
> prototype `FRAG` against this toolchain fails with exactly one error —
> `'gl_FragColor' : undeclared identifier` — and nothing else. `gl_FragCoord`
> and the `GL_FRAGMENT_PRECISION_HIGH` guard both compile as written. That is
> the evidence that change #1 is pure syntax and changes #2–#3 are
> fidelity *restorations*, not redesigns.

- [ ] **Step 4: Prove the compile check can fail**

Plant the original `gl_FragColor` and re-run. Expected: **exit 1**,
`'gl_FragColor' : undeclared identifier`. Remove the violation.

- [ ] **Step 5: Commit**

```bash
git add shaders/lumen.frag pubspec.yaml
git commit -m "feat(effects): the Lumen aurora shader, ported from the redesign"
```

## Task 1.2: The uniform table — red-first

AGENT_CONTEXT §6 names **"token and motion tables"** as red-first. This is one.

**Files:**

- Create: `lib/core/design_system/effects/lumen_uniforms.dart`
- Test: `test/core/design_system/effects/lumen_uniforms_test.dart`

- [ ] **Step 1: Write the failing test**

`LumenUniforms` is a pure Dart value object. The `setFloat` index is
load-bearing — and it **is** source declaration order (see Step 3). The test
must pin the *declaration* layout, which is what the engine actually uses.

```dart
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LumenUniforms slot order', () {
    test('matches the declaration layout with no vec3 padding', () {
      const u = LumenUniforms.identity();
      expect(u.slot(UniformSlot.uResX), 0);
      expect(u.slot(UniformSlot.uResY), 1);
      expect(u.slot(UniformSlot.uTime), 2);
      expect(u.slot(UniformSlot.uHueX), 3);
      expect(u.slot(UniformSlot.uHueY), 4);
      expect(u.slot(UniformSlot.uHueZ), 5);
      expect(u.slot(UniformSlot.uHue2X), 6);
      expect(u.slot(UniformSlot.uHue2Y), 7);
      expect(u.slot(UniformSlot.uHue2Z), 8);
      expect(u.slot(UniformSlot.uHue3X), 9);
      expect(u.slot(UniformSlot.uHue3Y), 10);
      expect(u.slot(UniformSlot.uHue3Z), 11);
      expect(u.slot(UniformSlot.uInt), 12);
      expect(u.slot(UniformSlot.uStr), 13);
      expect(u.slot(UniformSlot.uSpike), 14);
      expect(u.slot(UniformSlot.uSpread), 15);
      expect(u.slot(UniformSlot.uShape), 16);
      expect(u.slot(UniformSlot.uMelt), 17);
      expect(u.slot(UniformSlot.uDots), 18);
      expect(u.slot(UniformSlot.uWhite), 19);
      expect(u.slot(UniformSlot.uLight), 20);
      expect(u.slot(UniformSlot.uPtrX), 21);
      expect(u.slot(UniformSlot.uPtrY), 22);
      expect(u.slot(UniformSlot.uPtrI), 23);
    });
  });

  group('hslToRgb', () {
    test('matches the redesign prototype at h=258 s=90 l=66', () {
      final rgb = hslToRgb(258, 90, 66);
      expect(rgb.r, closeTo(0.5376, 0.0005));
      expect(rgb.g, closeTo(0.3540, 0.0005));
      expect(rgb.b, closeTo(0.9660, 0.0005));
    });
  });

  group('derived hues', () {
    test('hue2 is +38 degrees, hue3 is -42', () {
      final u = LumenUniforms.identity().withHue(258, 90, 66);
      expect(u.hue2.b, closeTo(hslToRgb(296, 90, 72).b, 0.005));
      expect(u.hue3.b, closeTo(hslToRgb(216, 90, 66).b, 0.005));
    });
  });

  group('slider conversions', () {
    test('reach 42 becomes spread 0.42', () {
      expect(spreadFromReach(42), closeTo(0.42, 1e-9));
    });
    test('touch 55 becomes ptrI 0.33', () {
      expect(ptrIntensityFromTouch(55), closeTo(0.33, 1e-9));
    });
  });

  group('spike decay', () {
    test('decays by 0.92 per frame, per redesign.html:900', () {
      expect(decaySpike(1.0), closeTo(0.92, 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run it and confirm a valid red**

```bash
flutter test test/core/design_system/effects/lumen_uniforms_test.dart
```

Expected: FAIL — `lumen_uniforms.dart` does not exist.

> **A compile failure is not a valid red here.** §6: *"A test that fails to
> compile, or that fails on an unrelated assertion, is not a red."* Create the
> file with the `LumenUniforms` class and the free functions as **stubs
> returning zero**, re-run, and confirm the failures are *assertion* failures
> with real expected values.

- [ ] **Step 3: Implement the minimum that passes**

Declare the 16 uniforms in the `.frag` in the **prototype's order** — that is
what makes the shader source a faithful port. The *Dart-side slot indices*
**are** that same order: `setFloat(n)` writes the n-th float of the runtime
uniform buffer, and the buffer follows declaration order.

**`setFloat` indices come from this table — source declaration order:**

| slot | uniform | slot | uniform | slot | uniform |
| --- | --- | --- | --- | --- | --- |
| 0–1 | `u_res` (vec2) | 8 | `u_hue2.z` | 15 | `u_spread` |
| 2 | `u_time` | 9–11 | `u_hue3` (vec3) | 16 | `u_shape` |
| 3–5 | `u_hue` (vec3) | 12 | `u_int` | 17 | `u_melt` |
| 6–8 | `u_hue2` (vec3) | 13 | `u_str` | 18 | `u_dots` |
| | | 14 | `u_spike` | 19 | `u_white` |
| | | | | 20 | `u_light` |
| | | | | 21–22 | `u_ptr` (vec2) |
| | | | | 23 | `u_ptrI` |

Total **24** floats, no `vec3` padding — `u_hue` occupies 3,4,5 contiguously.

Verified two independent ways, both agreeing:

1. **Render test.** Painting with these indices matches an independently written
   pure-Dart CPU mirror of the shader maths to **≤ 1/255** per channel over
   1,280,000 channels (shapes 0–2, sizes 40×40→400×800, melt/daylight on, five
   `t` values), on **both** `flutter test`'s Skia software path **and** Impeller
   (`--enable-impeller`, verified a real Impeller context via a `MaskFilter.blur`
   probe: centre byte 47 Skia vs 45 Impeller). Painting with the
   `--reflection-json` order instead gives worst error **247/255**. The layout
   is load-bearing and this is the right one.
2. **The engine's own comment.** `impeller/entity/contents/runtime_effect_contents.cc:290-298`:
   *"Uniforms are ordered in the IPLR according to their declaration … Since we
   know that the declarations are already ordered, we can track the uniform
   location ourselves."* `_getUniformFloatInfo` (`lib/ui/painting.dart`)
   likewise walks `_uniformInfo` in order accumulating float offsets.

> **Do NOT use `impellerc --reflection-json` for slot indices.** It reports a
> *different* order (`u_res, u_time, u_shape, u_spread, u_str, u_ptr, u_ptrI,
> u_int, u_spike, u_hue, u_melt, u_hue2, u_hue3, u_white, u_light, u_dots`)
> because it is built from `shader_resources.gl_plain_uniforms` — raw SPIR-V ID
> order (`impeller/compiler/reflector.cc:231-237`) — while the iplr-embedded
> lists go through `SortUniforms` (`reflector.cc:389-432`), whose stated intent
> is declaration order. Painting with the JSON order produces the 247-error
> frame. A previous revision of this plan made exactly that mistake; the render
> test caught it.
>
> **Do NOT use `getUniformFloat(name).index` either.** `.index` is the
> *component* offset within the uniform (0 for `.x`, 1 for `.y` — which is why
> it reads 0 for every single-component lookup). The real setFloat index is the
> `VisibleForTesting` **`shaderIndex`**, and a test should assert it per uniform
> — it is the engine's own bookkeeping, cheaper than rendering 1.28M pixels.

Port `hsl2rgb` from `eva/redesign.html:879-880` verbatim.

- [ ] **Step 4: Run and confirm green**

```bash
flutter test test/core/design_system/effects/lumen_uniforms_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(effects): the 16-uniform Lumen table and its conversions"
```

## Task 1.3: The injectable clock

**This is the decision that makes 240 goldens survive.** Without it every
screen golden becomes non-deterministic, because the frame is captured at an
arbitrary `u_time`.

**Files:**

- Create: `lib/core/design_system/effects/lumen_clock.dart`
- Create: `lib/core/design_system/effects/lumen_program.dart`
- Create: `lib/core/design_system/effects/lumen_canvas.dart`
- Modify: `lib/core/design_system/effects/neural_motion.dart`
- Test: `test/core/design_system/effects/lumen_canvas_test.dart`

- [ ] **Step 1: Write the failing test**

> **`tester.runAsync()` is mandatory, not stylistic.** Verified: the bare
> `Picture.toImage` capture below **deadlocks for the full 10-minute test
> timeout and then fails** with `Bad state: Cannot close sink while adding
> stream.` It is not a shader problem — a `PictureRecorder` → `toImage` →
> `toByteData` round-trip **with no shader at all** hangs identically. Wrapped in
> `runAsync` the same probe passes in under a second. Every capture in this task
> (Steps 1, 4, 5) needs it.

```dart
testWidgets('a pinned clock produces a byte-stable frame', (tester) async {
  Future<ui.Image> captureAt(double t) async {
    final clock = LumenClock.fixed(t);
    // runAsync: Picture.toImage never completes under flutter test's fake async.
    return (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      LumenCanvas(program: program, uniforms: uniforms, clock: clock)
          .paint(canvas, const Size(400, 800));
      return recorder.endRecording().toImage(400, 800);
    }))!;
  }

  final a = await captureAt(3.7);
  final b = await captureAt(3.7);
  expect(await byteIdentical(a, b), isTrue,
      reason: 'a pinned clock must make the frame deterministic');
});
```

> **Dispose the images.** Two 400×800 `ui.Image`s per capture, in a suite that
> captures many, is a real leak. `a.dispose(); b.dispose();` at the end of each
> test.

- [ ] **Step 2: Confirm a valid red** — stub-returns-zero first, per Task 1.2 Step 2.

- [ ] **Step 3: Implement**

`LumenProgram.fromAsset('shaders/lumen.frag')` — **memoize**. The SDK keeps a
static `_shaderRegistry`, so a second call is free; hold one instance anyway.

`LumenClock`:

- production — a repeating ticker inside `NeuralMotionScope`, which already
  owns three shared controllers with `AnimationBehavior.preserve`
- tests — `LumenClock.fixed(t)`

`LumenCanvas` paints `canvas.drawRect(Offset.zero & size, Paint()..shader = shader)`.

> **Two hard rules.**
>
> 1. `u_res` is the **rect's logical size**, not the device size. Impeller's
>    `runtime_effect.vert` passes the *untransformed local* vertex position.
> 2. Reuse **one** `FragmentShader`, mutated per frame. Calling
>    `program.fragmentShader()` inside `paint()` allocates a fresh uniform
>    buffer every frame.

- [ ] **Step 4: Prove the port is numerically correct**

```dart
testWidgets('a frame matches the recorded oracle', (tester) async {
  final image = /* capture at t=3.7, u_str=1, u_shape=0, noise on */;
  expect(maxChannelError(image, oracleFrame), lessThanOrEqualTo(1 / 255));
});
```

This is the anti-regression test for the whole port. Expected: **≤ 1/255**.

**Do not assert on GPU output.** `flutter test` captures the **software**
rasterizer. The 1/255 tolerance is what makes the assertion true on both
backends; a pixel-exact golden would not be.

- [ ] **Step 5: Prove the determinism test can fail**

Use a live clock and confirm the two captures differ. If they are identical, the
test is vacuous and the whole golden strategy is unsound.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(effects): an injectable clock so goldens stay deterministic"
```

## Task 1.3b: Reconcile the two slot tables — one layout, not two

Task 1.3 proved by render test that `setFloat` follows **declaration** order
(≤1/255 vs the CPU mirror; the `--reflection-json` order gives 247/255). But it
landed a `LumenSlotLayout` enum with *two* production layouts and left
`UniformSlot` (Task 1.2) pinned to the JSON order — so the suite is green over
two tables that disagree, and `reflectionOrder` is a public API for painting
garbage. Reconcile now, in one change:

- [ ] **Step 1: `UniformSlot` → declaration order.** Rewrite the enum in
  `lumen_uniforms.dart` so member position *is* the `setFloat` index (the table
  in Task 1.2 Step 3), and update `lumen_uniforms_test.dart` to the Task 1.2
  Step 1 assertions. The enum doc must state the JSON discrepancy: re-running
  `impellerc --reflection-json` reproduces a *different* order (S), which is
  SPIR-V ID order (`reflector.cc:231-237`), not the runtime order — painting
  with it is the 247-error frame, and the test that proves it lives in
  `lumen_canvas_test.dart`, not here.
- [ ] **Step 2: Delete `LumenSlotLayout`.** Production has exactly one layout.
  `LumenProgram.load` takes no layout; `slotFor` goes away and call sites use
  `slot.index` directly. The enum's doc on `LumenProgram`'s "two painters' worth
  of behaviour" goes with it — it was describing a footgun, not a feature.
- [ ] **Step 3: Correct the `getUniformFloat` doc.** `.index` is the component
  offset, not the shader index — rewrite the "WHY THIS IS NOT DERIVED" section
  to say so, citing `painting.dart`'s `UniformFloatSlot.index` doc.
- [ ] **Step 4: Assert the layout against the engine, cheaply.** Add a test that
  reads `getUniformFloat(name).shaderIndex` (`VisibleForTesting` — test use is
  its purpose) per uniform and expects the declaration float position. This pins
  the layout without rendering 1.28M pixels.
- [ ] **Step 5: Keep the reflection-order negative control test-only.** The
  "paint with S-order raw indices → garbage" check stays, but as hard-coded raw
  indices inside `lumen_canvas_test.dart` — proving layout-sensitivity without a
  production API for it.
- [ ] **Step 6: Re-run the four verifications** (`flutter test` on the effects
  dir, `dart analyze`, `dart format`, `citation_check.py`) and commit:

```bash
git commit -m "fix(effects): one slot layout — UniformSlot is the setFloat order"
```

## Task 1.4: `u_time` stays unwrapped — **CUT, do not implement**

**This task previously specified a wrap of `u_time`. It is cut. The port keeps
the prototype's unbounded accumulator, bit for bit.**

It was cut because re-measuring the claim showed the premise was wrong on both
counts, and because the fix could not deliver what it promised.

**The decay does not happen on the claimed timescale.** float32 simulation of
`fbm1` → `noise1` → `hash`, measuring distinct output values across 4000 cells:

| `t` | hash argument | distinct / 4000 | std |
| --- | --- | --- | --- |
| 0 s | 42 | **4001** | 0.122 |
| 600 s | 2 369 | 4000 | 0.134 |
| 1800 s | 7 079 | 4000 | 0.121 |
| 3600 s | 14 006 | **4001** | 0.129 |
| 36 000 s (10 h) | 139 685 | 2561 | 0.128 |
| 360 000 s (100 h) | 1 396 855 | 161 | 0.138 |

1. The argument magnitude was understated by ~3× (14 006, not ±4245).
2. **Nothing degrades between `t=0` and `t=3600 s`.** The ~8-bit quantisation
   (~512 levels from `fract(sin(n)·43758.5453)`) is present from the very first
   frame and is a property of the hash itself, not of elapsed time.
3. Posterisation first appears at **≈10 hours** of continuous runtime, and is a
   slow fade — 161 distinct values at ≈100 hours — not the collapse described.

**No exact loop period exists.** The old Step 2 proposed wrapping "at the period
that makes `t·0.9` integral, preserving the visual loop exactly." Measured:

- Smallest such period is `T = 10 s`. At `T = 10`, **none** of the ten
  `sin(t·ω)` terms is periodic — `0.30·10/2π = 0.477`, `2.2·10/2π = 3.501`,
  `0.8·10/2π = 1.273`; not integers.
- The smallest `T` making every `sin` term periodic is **628.32 s** (10.5 min).
- Even then the fbm hash does not loop exactly: `4.31 · 0.9 · T = 2437.2476` is
  not an integer, so the noise field is discontinuous across the wrap.

A wrap therefore cannot "preserve the visual loop exactly" for *any* period. Its
only choice would be between a discontinuity and a 10.5-minute visible repeat —
both worse than the thing it was meant to fix.

**What to do instead:** nothing. Ship the plain accumulator, as the prototype
has it. If a future measurement ever justifies a cap, it ships as an opt-in
setting ("cap shader clock"), separately reviewed, citing the measurement that
justifies it — never as a silent part of the port.

- [ ] **Step 1: Assert the accumulator does *not* wrap** — a regression test that
  `u_time` passed to the shader equals the clock's elapsed value exactly at
  `t = 3600 s`. This pins the deliberate decision, so a future contributor
  cannot reintroduce the wrap without breaking a test that says so.

## Task 1.5: Performance tiers

Measured: 2.98 ns/px for shapes 0–2, **5.04 ns/px** for shafts.

- [ ] **Step 1: Write the failing tests** for the tier table (red-first —
  §6 names motion tables).
- [ ] **Step 2: Extend `NeuralTiers.resolve`** with a shader tier.
- [ ] **Step 3: `low`** (or reduce-motion) → shader off, static
  `CustomPainter` aurora — today's `neural_background.dart` behaviour, which is
  already tier-aware.
- [ ] **Step 4: Gate `shafts`** — it is the one control that must not ship
  unguarded. Disable it above ~2 Mpx and record the measurement in a comment.

> **Wiring constraint for whoever mounts the painter (Phase 5).** `LumenCanvas`
> reuses one `FragmentShader` per *instance* (`_shader ??=`), so the allocation
> saving only materialises if the instance is long-lived. The current
> `ListenableBuilder` pattern in `neural_background.dart:294-310` builds a fresh
> painter per frame — mounting `LumenCanvas` that way would silently reintroduce
> the per-frame uniform-buffer allocation that hard rule 2 removed. Hoist one
> `LumenCanvas` above the rebuild boundary (or key it stable) when wiring it in.

---

# Phase 2 — Palette & tokens

> **Status: COMPLETE (commits `659fa8e`, `cc342ef`, `a712fb0`, `c661245`).**
> Full gate green: **2609 tests** (floor 2507), **98.46% coverage** (floor 98.25%),
> citations 1014/1014. Two parallel research subagents first (contrast
> verification + gate inventory), one implementer, two-stage review per task with
> mutation-checked re-reviews. Net result: **zero hex changes** — the plan's
> repair table did not survive measurement (see Task 2.2). Six Decision-153 ink
> byte-pins added; gaps 0:7, onEmber 9.17/5.41, 5-entry ledger all unchanged;
> four unaffected gates green. Standing rules: Task 2.2's table is the answer to
> future re-proposals; focus ≥3:1 rule lives in Phase 5 Task 5.3.

## Task 2.1: Adopt dark verbatim

No changes. It passes AA everywhere and beats the current palette on every role.

## Task 2.2: Repair exactly four light values — **CUT to docs-only, do not change hexes**

| Token | Prototype | Measured (vs `#F5F2EA`) | Plan said repaired to | Actually measures | `EvaColors.light` today | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `ink2` | `#707684` | 4.069 ✓ repro | `#666C7A` | 4.703 ✓ | `#5A5480` at 6.10 | **already better — no change** |
| gold ink | `#8a6d15` | 4.387 ✓ repro | `#806615` | 4.902 ✓ | `emberInk #845610` at 5.54 | **already better — no change** |
| gold | `#9A7B19` | 3.595 ✓ repro | `#8A6D15` | **4.387 ✗ (<4.5)** | `ember` fills + `emberInk` writes (Decision 153) | **plan repair fails AA — no change** |
| `.cta` label | `#FFFFFF` on `#9A7B19` | **4.022** ✓ repro | fill → `#8A6D15` (5.30) | **4.908 ✗ (not 5.30)** | `ember #D4891A` + `onEmber #3A1E00` at 5.41 | **already better; parenthetical wrong — no change** |

- [ ] **Step 1: DO NOT change any hex in `eva_colors.dart`.** Proven regression (see table). If a future reader re-proposes the table, this table is the answer.
- [ ] **Step 2: Cite the non-repair** — a comment in `eva_colors.dart` (light palette doc) with `redesign.html:56,58,70,71,86,90,100` **and** the measured ratios, stating exactly where and why the app parts ways with the prototype (Decision 153 split beats the converge-repair; current tokens exceed every repaired ratio). A reader must see the prototype value, the repaired value, and why neither was adopted.
- [ ] **Step 3: Fix the focus affordance — DEFERRED to Phase 5.** `redesign.html:177` sets `.screen.focus .vline.in` to `#d9dfef`, flattening every in-view verse including `.hot` to one color (in-focus distinction **1.000:1**, not ~1.5:1; `#d9dfef` vs remembered `#A9B0C8` is 1.62:1; "17.98:1 vs canvas" is hot-verse legibility, max for `#d9dfef` is 15.75:1). **No `vline`/verse widget exists in `lib/`** (grep: only `eva_text_field`/`focus_ring`) — there is no target until Phase 5 builds `/reading`. Record the rule in the plan (Phase 5 Task 5.3): focus mode must preserve a ≥3:1 distinction between in-view and out-of-view verses, never flatten to a single `#d9dfef`.

## Task 2.3: Re-baseline the five token gates

- [ ] **Step 1: `eva_colors_test.dart`** — **30** byte-pinned hexes (15 dark + 15 light `expect()` calls; the plan's "34" miscounted — 23 match single-line `expect\(_hex` grep, 9 more are split-line), the
  `expect(gaps.length, dark ? 0 : 7)` sub-AA count (**unchanged** — no token moves, so the seven `_KnownGap` entries stay), and
  `closeTo(9.17 / 5.41, 0.05)` on the `onEmber` pairings (**unchanged**). Assert
  the count **explicitly** (correct 34→30 with the counting method in the comment). Do **not** relax to `greaterThanOrEqualTo` —
  that assertion is what makes the inventory exhaustive. **Coverage gap to close:** neither spec test pins `emberInk`/`okInk`/`errInk` (Decision 153 tokens) — add byte-pins for the three light + three dark ink values so a future ink edit fails here, not just in the contrast gate.
- [ ] **Step 2: `text_contrast_gate_test.dart`** — `knownSubstandard` **must not
  grow** (5 entries, unchanged — no token moves). The plan's "should *shrink*" assumed four repairs that were cut; with no hex changes there is nothing to delete. **If it grows or drifts (`closeTo(ratio, 0.005)`), the docs-only change leaked behaviour — STOP.**
- [ ] **Step 3: Verify the gates that should be unaffected actually are:**
  `no_colour_literals_test` (new hexes go in `tokens/`, which is exempt — and this task adds none),
  `glass_blur_budget_test` (purely structural), `font_coverage_test` (the
  redesign uses the **same five** families), `arabic_typography_gate`.

---

# Phase 3 — The witness sky

> **Status: COMPLETE (commits `91db0bc`, `4805480`, `05bc3f7`, `0e93427`,
> `526da03`, `28cfb76`, `7d89f37`, `67af41a`, `d10a2b0`).** Full gate green:
> **2741 tests** (floor 2507), **98.49% coverage** (floor 98.25%), citations
> 1107/1107. Three tasks, two-stage review each, mutation-verified fixes.
>
> **What the process caught (four findings that reading would have missed):**
>
> 1. **Cold-start bug on the only runnable device.** `raw is List<String>` reads
>    the persisted sky as EMPTY on every launch on Linux — the platform
>    re-casts the outer map but leaves arrays `List<dynamic>`. `setMockInitialValues`
>    is *more* faithful than the device, so the suite was blind. Element-wise
>    narrowing + a `jsonDecode(jsonEncode(...))` regression fixture.
> 2. **Three of four star shapes rendered as solid squares.** `ClipPath` sat
>    *inside* `DecoratedBox`, so it clipped nothing — star/cross/diamond were
>    byte-identical buffers while ~200 lines of pure-geometry code and green
>    tests described silhouettes no pixel showed. Found by capturing alpha
>    grids per shape, not by reading. Fixed by moving the clip outside, and the
>    CSS question it surfaced is recorded in-code: an outer `box-shadow` is
>    clipped inside the border-box, so the prototype's polygon stars have **no
>    glow** while `border-radius:50%` (the dot) keeps its halo.
> 3. **The constellation never drew.** The draw-on armed once in `initState`;
>    `/reading` lights verses on scroll, so mount has one star and the line is
>    never started. Every test mounted with ≥2 entries. Fixed to arm on the
>    not-drawable→drawable transition; a third star extends, never replays.
> 4. **Non-atomic `record()`** lost a star when two scrolled into view together.
>    Serialized with a per-repository `Future` chain (`@lazySingleton` is load
>    bearing: two adapters means two chains).
>
> **Deferred, on the record:** per-frame cost at the 44-star cap is **2214 µs**
> (debug JIT, fake async — an upper bound, not device numbers); two thirds is
> repaint, not rebuild. The fix is one `CustomPainter` on `repaint:` — the
> `GoldFlecks` precedent — and it is Phase 5's call, because it would delete the
> only assertions that can currently see a star. Measured numbers and both
> rejected micro-fixes are in `witness_sky.dart:842-892`.
>
> **Phase 5 obligations recorded here (from this phase, do not lose them):**
>
> - **Where does the cubit live?** `WitnessSky` takes `List<SkyEntry>` because
>   `core/design_system` cannot import `features/sky` (Gate 2, verified by
>   planting the import → exit 1). Three features need the sky; `AuthStatus`
>   (`core/navigation/auth_status.dart`) is the precedent for a port three
>   features share.
> - **The reader's scroll observer.** `redesign.html:1208-1221` lights a verse
>   at `threshold .6`, once, via `dataset.star` + `unobserve`. Build it as a
>   `ScrollController` offset check in `/reading` (Task 5.3).
> - **`orphan_widget_check`'s ALLOWLIST is no longer empty** — one entry,
>   `WitnessSky`, with a written reason. The gate reports it STALE and exits 1
>   the moment a page constructs it, so it cannot outlive its reason. Placing
>   the widget is Task 5.3's job.
> - **Flare sources to wire:** cheer `:1123`, selah `:1330`, quiz correct `:1428`.
> - **`redesign.html:1145` gates lighting on `starsOn`**; Stars-off stops
>   lighting *and* clears (`:1483`). The consumer must check the setting or a
>   scrolled verse re-lights on the next pass.

## Task 3.1: The domain port — red-first

Read by **three** features (reading lights, quiz fires flares, journey counts),
so the placement test puts it in `core/domain/`. **Pure Dart.**

- [ ] **Step 1: Failing tests** for `SkyEntry` — `book:chapter:verse` key
  formatting, equality, and that two readings of the same verse produce one
  entry.
- [ ] **Step 2: Implement `SkyEntry`** with the entity's `freezed` boilerplate.
- [ ] **Step 3: Failing tests** for `SkyRepository` behaviour against a fake.
- [ ] **Step 4: Implement the port.**
- [ ] **Step 5: Run `tool/verify_purity.sh`** — expect PASSED. A `package:flutter`
  import here fails Gate 1.

## Task 3.2: Persistence + cubit

- [ ] **Step 1: `SkyLocalDataSource`** — `shared_preferences`, same store as
  settings. Typed getters are deliberately **not** used: a wrong-typed value
  throws and takes the store down, so raw `get` plus an `is` check.
- [ ] **Step 2: `SkyCubit`** — §6 names **every cubit** red-first, with
  `bloc_test` + `mocktail`. Optimistic-then-rollback, matching `SettingsCubit`.
- [ ] **Step 3: Verify** `dart analyze --fatal-infos --fatal-warnings` is clean.

## Task 3.3: `WitnessSky`

- [ ] Stars in 4 shapes — `clip-path` polygons → `ClipPath`
- [ ] 3 fields (crown/high/full), twinkle, brightness
- [ ] Constellation polylines in **the order the stars were lit**
- [ ] The prototype's `IntersectionObserver(threshold: .6)` becomes a
  `ScrollController` offset check in the reader

---

# Phase 4 — Design system restyle

> **Status: research DONE (two parallel subagents). The plan below is CORRECTED
> against what they measured — four of the seven steps were not executable as
> written.** Read the corrections before dispatching anything.
>
> - **There are 24 widgets, not 23** (`witness_sky.dart` landed in Phase 3).
>   Only **one** — `witness_sky.dart` — cites `redesign.html` today; the other
>   23 cite `eva/src/*.tsx`.
> - **Step 5's premise is vacuous in this phase.** All five harnessed screens are
>   rebuilt in **Phase 5** (and `/result` dies in Phase 6 Step 6.2), so *no*
>   screen changes in Phase 4. Re-pointing harnesses here would leave them
>   guarding to-be-deleted screens against to-be-deleted `eva/src` numbers. Step
>   5 becomes a **liveness proof** (plant → confirm red → revert); re-pointing
>   moves to Tasks 5.1–5.4.
> - **Step 6's allowlist is not empty and cannot be emptied here.** Phase 3
>   added one entry (`WitnessSky`, with a written reason). Its only consumers
>   are Phase 5.3/5.4/5.6. Deleting the entry now ⇒ `ORPHAN WitnessSky` ⇒ exit 1.
>   The gate's own message is *"place it, delete it, or allowlist it WITH a
>   written reason — never suppress the failure."* Emptied in **Phase 5.3**.
> - **The `ImageFilter` citation was wrong.** `ADR-0020` has no §13 and zero
>   `ImageFilter` mentions; the rule is `docs/plans/09-quality-gates.md:146`
>   (§13 mitigation 3), whose line **:161** is the direct authority for this
>   phase — *"The prototype's `blur(72px)` is achieved by a soft radial gradient
>   with a wide transparent stop — visually equivalent, effectively free."*
>
> **Two traps in the blur-budget gate, measured by the researcher — read these
> before editing `glass_surface.dart`:**
>
> 1. `glass_surface.dart:244` is the **only** non-comment line in
>    `lib/core/design_system/widgets/` containing the literal `GlassTier.blur`,
>    and the ceiling is **1** (`glass_blur_budget_test.dart:216-224`). A tier
>    dispatch must keep that literal on **exactly one** non-comment line. The
>    scanner skips only *leading* `//`/`///` (`:186`) — a **trailing** comment
>    after code on the same line **counts**.
> 2. No line containing `BackdropFilter` or `ImageFilter.blur` may appear
>    anywhere in `lib/core/design_system/widgets/` **outside
>    `glass_surface.dart`** (`:294-303`). Gradients are clean; `MaskFilter.blur`
>    is clean of those markers but is a paint filter — do not use it here.
>
> `glass_surface_test.dart:68-70` asserts `GlassTier.values == [tint, blur]` and
> will fail on the new member: update the assertion **and** its test name
> together (`:111-127`), and re-record its goldens (`:246-253`).

## Task 4.1: `GlassTier.bloom` + the `.hor` seam

The `.bloom` radial wash and the `.hor` light seam are the redesign's signature
and have no current equivalent. Measured geometry (researcher, every line
printed):

| | `.hcard` | `.bcard` | `.medal` | `.podbar` |
| --- | --- | --- | --- | --- |
| inset l/r | 8% | 6% | 0 | 10% |
| `bottom` | −46% | −52% | −60% | −55% |
| height | 80% | 88% | 90% | 90% |
| fade stop | 68% | 68% | 70% | 70% |
| CSS `filter:blur` | 18px | 16px | 14px | 14px |

All four are `radial-gradient(ellipse at 50% 100%, var(--bh), transparent 68%)`
— bottom-anchored, centre on the bottom edge, fading at 68–70% of the radius.
`.hor` exists on `.hcard` **only** (`redesign.html:256-257`, light `:72`):
`linear-gradient(90deg,transparent,rgba(255,255,255,.85),transparent)`, l/r 14%,
h 2px, r 2px, bottom 20%, glow `0 0 14px rgba(255,255,255,.6)`.

- [ ] **Step 1: Failing tests first** for the new tier (§6: token and motion
  tables are red-first; the tier enum's existing test is already red-first).
- [ ] **Step 2: Tokens.** `--bh` has no existing token and **must not** reuse
  `ember` — Phase 2 measured and rejected converging on prototype gold, and the
  14 prototype `--bh` values match none of the seven `StickerSlot` colours.
  Add to `EvaColors` (constructor + dark + light + fields + **`copyWith`** +
  `lerp**` — omitting either makes the token silently always-dark): `seam`
  (`0xD9FFFFFF` / `0xCC9A7B19`), `seamGlow` (`0x99FFFFFF` / `0x809A7B19`), and
  `bloom` (the `--bh` default `0x8CE457D6`, `redesign.html:254`).
- [ ] **Step 3: `--bh` per card is a constructor parameter, not a token** — in
  CSS it is *always* set inline per host element (24 occurrences, no global
  definition). `GlassSurface({this.bloom, this.bloomColor})`.
- [ ] **Step 4: The bloom is a gradient inside the existing `ClipRRect`**
  (`glass_surface.dart:222`) — the prototype relies on `overflow:hidden` for
  exactly this. A `BoxShadow` is a paint, not a `saveLayer`, so the seam's
  `0 0 14px` glow costs nothing against the budget.
- [ ] **Step 5: Dimmers are caller state, not tier** — light mode `opacity:.55`
  (`redesign.html:73`) and `.bcard.sealed` `opacity:.35` (`:285`) are the same
  mechanism as today's sealed dimmer. Do **not** make them tier members.
- [ ] **Step 6: Correct the `ImageFilter` citation** to
  `docs/plans/09-quality-gates.md:146` and quote `:161` as the authority for
  dropping all four `filter:blur(Npx)`.
- [ ] **Step 7: Update `glass_surface_test.dart`** — the enum assertion and its
  name together; **zero** new `GlassTier.blur` lines; re-record
  `glass_surface_tint/_blur.png` per Step 7.

> **Status: Task 4.1 COMPLETE (commits `143dc56`, `a673769`, `47c0410`).** Full
> gate green: **2763 tests** (floor 2507), **98.50% coverage** (floor 98.25%),
> citations 1164/1164. Three blocking defects, all found by measurement and none
> by reading:
>
> 1. **A `Stack` replaced the content chain and shrink-wrapped every consumer.**
>    `StackFit.loose` loosened the constraints `StatTile`'s content used to
>    receive; its three tiles went `106.7 / 89.3 / 54.3` wide. The tint fixture's
>    `SizedBox` is *additional* constraints, so `enforce` collapsed it back and
>    the golden stayed byte-identical **by luck**. `StackFit.passthrough` restores
>    it exactly; the test that should have caught it asserted the **outer** box,
>    which `RenderStack` sizes to `constraints.biggest` regardless of fit.
> 2. **The seam rendered at top 20%, not bottom 20%.** `bottom:20%` was
>    converted with `-1 + 2 × 0.20` into an `Alignment` whose origin is
>    **inverted** (`y = -1` is top). The exact mirror of correct.
> 3. **The wash sat at 72% of the width, not 50%.** `FractionalOffset(0.5,1.0)`
>    is `Alignment(0,1)` — `FractionalOffset` *extends* `Alignment` **converting**
>    via `super(dx*2−1, dy*2−1)` (`fractional_offset.dart:54-56`), and `x` is
>    centre-origin too. Measured centroid 201.1 of 280.
>
> **Three conventions, three origins — the lesson worth keeping:** CSS `bottom`
> counts up from the bottom, `FractionalOffset.dy = 0` is the top, and
> `Alignment.y = -1` is the top. A percentage that names an edge must never be
> fed through another convention's arithmetic. Both original tests re-derived
> the bug from the HTML and compared it to itself, which is why neither could
> fail; they are now rendered-geometry assertions (seam rect vs bottom edge,
> wash centroid vs centre line).
>
> **On re-recording goldens:** both bloom goldens were a regression lock on the
> bug and had to be re-recorded — *after* the constants and tests were correct,
> with the two files failing alone as the evidence. `stat_tile_*` and
> `glass_surface_tint_*` were **not** touched, and that is the check that the
> fix restored behaviour rather than re-baselined it.

## Task 4.2: Restyle the widgets (24) + re-point their citations

> **Status: COMPLETE (batches `f849415` A-controls · `cb51c21` C-actions/fields
> · `c1abb62` B-surfaces · `fe46efb` D-marks/scrim · review fixes + lint sweep
> `b21e144`).** Full gate green: **2860 tests** (floor 2507), **98.53%
> coverage** (floor 98.25%), citations 1556/1556, orphan gate green, analyzer 0
> under the adopted strict config. Seven widgets left alone as planned
> (`empty_state`, `error_view`, `focus_ring`, `witness_sky`, `text_link`,
> `hairline_divider`, `sun_burst`). Bloom seam parameters shipped instead of a
> fifth tier (`seamAlignment`/`seamWidthFactor`/`seamTint`); `bloomOpacity`
> token per decision 4 (`cbfb402`). Two blocking review findings fixed and now
> test-guarded: SegmentedControl thumb paints **under** the selected label (a
> rendered-pixel contrast assertion holds ≥ 4.5:1 — the defect measured
> 1.12:1), and SettingsTile's hover duration order (`animate ?
> hoverDuration : Duration.zero`) plus `EvaFocusRing radius: 0` on the flat
> row. Deferred with reasons in-file: `StreakFlame` 13×17 blob → 5.2,
> `PassageDropCap` 56px/.82 → 5.3. The research status below is retained for
> the harness landmine inventory, which Phase 5 must respect.
>
> **The blast radius is 8 design-system widgets, not 13.** The plan's "13" summed
> per-screen lists that mix design-system and feature widgets. The eight a
> harness actually measures a *design-system* property on: `GlassSurface`,
> `SealMonogram`, `EvaTextField`, `EvaButton` (weakly — sits in `Expanded`, so
> the assertion reads the parent), `StreakFlame`, `TextLink` (weakly),
> `IconActionButton`, `ProgressBeads` (loosely — an inequality only).
>
> **4 of the 5 harnesses are paint-safe. `/login` is not:** it asserts
> `expect(form.tier, GlassTier.tint)` (`login_geometry_test.dart:726`), so
> switching `/login`'s form to `GlassTier.bloom` is a *paint* change that turns
> it red. **Do not switch `/login`'s form tier in this phase** — the bloom's
> hosts are the `/` cards (Task 5.2).
>
> **Four structural landmines, all measured:**
> `login_geometry_test.dart:720`, `home_geometry_test.dart:521`,
> `result_geometry_test.dart:85,115` and `quiz_geometry_test.dart:146,153` use
> **bare `find.byType`** — a second instance on the screen throws "too many
> elements", which reads as a harness bug, not a restyle. `reading_geometry_test.dart:955`
> takes `.first` in document order, so reordering `ReadingControls`' children
> moves which button is measured.
>
> **The redesign deletes more glass than it adds.** Roles R3 (settings rows),
> R4 (metric cell), R9 (list row), R11 (dock item) and R17 (progress dots) are
> **flat** — hairline only, no fill, no radius. That is the single most
> under-appreciated fact in the prototype and it drives decisions 2 and 3.

### Decisions taken (recorded, not silently delegated)

1. **`EvaButtonVariant.secondary` → the gold-rim role** (`redesign.html:363-368`
   `.qnext`): transparent fill, 1px gold rim, gold ink, pill, mono-caps. The
   redesign has exactly three action roles — filled gold (`:381-386`), gold-rim
   (`:363-368`), glass-rim ghost (`:388-390`) — and `secondary` maps to the
   second. This is a **role mapping**, recorded as such in the widget doc.
2. **`SettingsTile` loses its tile.** `.srow` is `background:none`,
   `border-radius:0`, `border-left/right/top:none`, a 1px `rgba(255,255,255,.06)`
   bottom hairline, `padding:15px 4px`, `font-size:14.5px`, hover
   `color:var(--gold); transform:translateX(4px)` (`:419-421`). 28 rows on
   `/settings` go from r14 glass panels to flat rules. **This is the largest
   visual change in the phase and it is the redesign's language, not a
   regression** — R3 is flat by design. The blur-budget question evaporates:
   there is no fill to budget.
3. **`GlassTier.bloom`'s seam takes parameters, not a fifth tier member.** R18
   (`.opt::after`, `:348-349`) is a seam at `bottom:0`, 72% wide, **gold**;
   `.hor` is at `bottom:20%`, 72% wide, **white**. A quiz option cannot use
   `.hor` unchanged, and a fifth `GlassTier` member would break
   `glass_blur_budget_test`'s counting model. Add `seamAlignment`,
   `seamWidthFactor`, `seamTint`, defaulted to the `.hor` values.
4. **The light-mode wash dimmer becomes a token.** `redesign.html:73` dims all
   four washes to `opacity:.55` in light and never re-hues `--bh` — which is
   why `bloom` is correctly identical in both palettes. But a caller-state
   opacity that **no caller sets** leaves the card family light-mode-wrong by
   0.55× the moment it ships. Add a per-brightness `bloomOpacity`
   (1.0 dark / 0.55 light). `orbOpacity` and `auroraOpacity` are the precedent —
   both are per-brightness floats lerped per brightness, which also **retires**
   the false "this design system has no convention for it" premise currently
   sitting in `seamGlow`'s doc.
5. **Deferred to the screen phases, with the reason recorded in-file:**
   - `PassageDropCap` at 56px / `line-height:.82` and RTL-off (`:141`) — that is
     a ratio tuned against a screen that does not exist. Phase 5.3.
   - `StreakFlame`'s 13×17 CSS blob (`:242-243`) — two harnesses read its
     rendered `14×18`. Phase 5.2.

- [ ] **Step 3: Restyle the 24 widgets** to the redesign's glass/gold/bloom
  language, **by role, not by file** (the `4b53500` precedent: "the split is by
  role, not by widget"). Scope is the widget-level language — glass tiers,
  seams, bloom, accent use — **not** the base palette, which Phase 2 settled.
  **Seven widgets are left alone** — `empty_state` and `error_view` have no
  prototype, `focus_ring` is a §14 invention with no prototype line at all
  (fabricating one would be the worst outcome of this task), `witness_sky` is
  already built against `redesign.html`, `text_link` has no inline-link role in
  the redesign, `hairline_divider`'s call sites still describe it, and
  `sun_burst` is superseded by `.bigring` (`:447-452`) only when `/result`
  becomes a modal in **Phase 6.2**.
- [ ] **Step 4: Re-point citations per widget.** Move `eva/src/X.tsx:NNN` →
  `redesign.html:NNN` **only for widgets that actually changed**. A citation
  that still describes a surviving widget is not wrong; moving it would be
  churn. **Eight widgets are partially frozen** — change the redesign-backed
  half, keep the rest: `eva_section_header` (re-point `section` to `:422`, keep
  `ProfileScreen.tsx:53` for `title`), `eva_text_field` (field box → `:376-379`,
  keep `ds.tsx:297-300` for the label — `.field` is bare),
  `font_size_stepper` (track/thumb → `:429-430`, keep `SettingsScreen.tsx:66`
  for the range — the redesign's own slider is 16–26, a different model),
  `settings_group` (label → `:422`, keep the `rowGap = 10` citation),
  `stat_tile` (type → `:407-408`, keep `ds.tsx:462-478` for the panel),
  `seal_monogram` (treatment → `:392-395`, keep `LoginScreen.tsx:19` for
  `defaultSize = 60`), `neural_scaffold` (scrim → `:112-115`, keep all eight
  `*.tsx` root citations), `eva_button` (radius/ripple → `:381-390`, keep the
  height citation — `login_geometry_test` reads `kEvaButtonHeight == 52`).
  **Never** let a restyle edit a number a harness asserts: `kEvaTextFieldHeight`
  52, `EvaRadii.input` 14, `EvaSpacing.lg` 16, `kEvaButtonHeight` 52,
  `SealMonogram` 60, `StreakFlame` 14×18, `IconActionButton` 44.

## Task 4.3: Prove the gates still fire, then re-record

> **Status: COMPLETE (`b21e144`, goldens re-recorded in the batch commits).**
> Step 5 liveness proof: all five harnesses go **red on plant** (a violation
> planted in each turns it red) and **green on revert** — re-pointing moves to
> Phase 5.1–5.4 as planned. Step 6: barrel exports 24/24; `orphan_widget_check`
> green with the single allowlisted `WitnessSky` entry; the STALE mechanism was
> itself verified (constructing it from a page is reported and exits 1). Step 7:
> goldens re-recorded after citations moved, per-file scoped. Citations
> 1556/1556 after the sweep.

- [x] **Step 5: Liveness proof for all 5 harnesses** — plant a violation in
  each, confirm it goes red, **revert**. A harness that passes vacuously is
  worse than no harness. Re-pointing moves to Phase 5.1–5.4.
- [x] **Step 6: Export every new widget from `barrel.dart`** and run
  `orphan_widget_check.py`. All 24 are already exported. The allowlist carries
  **one** entry (`WitnessSky`) whose reason names Phase 5; the gate reports it
  STALE and exits 1 the moment a page constructs it, so it cannot outlive its
  reason. Emptied in Phase 5.3. **Never suppress the failure.**
- [x] **Step 7: Re-record goldens AFTER the citations are re-pointed.** Never
  the reverse — `CONTRIBUTING.md` names "re-recording goldens without
  re-checking the citations" a review failure. Command is plain
  `flutter test --update-goldens` (no custom script); scope it per test file —
  two agents running it concurrently over the same directory would clobber each
  other, which is why the restyle batches are sequential within a directory.
  80 committed PNGs, `390×844` at `dpr 1.0` (`kAmbientSurface`).

---

# Phase 5 — Screens

> **Status: Tasks 5.1–5.2 COMPLETE** (full gate green: **2868 tests**, **98.53%
> coverage** (floor 98.25%), citations 1713/1713, orphan gate green with
> `WitnessSky` (5.3), `SealMonogram` (5.6) and `TextLink` (5.5) allowlisted by
> named consumer, purity green, analyzer 0). **5.1** (`13a8696`): the screen
> rebuilt against `eva/redesign.html:503-511` — glowing wordmark with the
> ten-letter entrance, mono tagline, two bare fields (`EvaTextField
> showLabel: false` — the caption hidden, the §14 name kept), the
> always-tappable CTA with the `.cta.err` shake, two inert ghost pills
> (`EvaButton.semanticLabel` carries the unavailable suffix), and the
> alpha-omega footer through `NeuralScaffold.overlay`. Three defects the gates
> caught, not reading: the footer's overlay stretched to the viewport and ate
> the CTA's tap (`Positioned.fill` hands tight constraints down; `Align` fixes
> it), the tagline/footer took `arabicAware`'s Amiri on the Arabic arm and
> tofu'd the Greek letters (brand lines stay mono in both directions), and the
> wordmark overflowed 320px at 1.22x (a brand mark scales — `FittedBox
> scaleDown` — it does not wrap). Two numbers moved with the prototype:
> `kMinPasswordLength` 8->4 (`:1306` states the rule the React prototype never
> did) and one message per field (`:976`), the old `kRequiredMessage` gone with
> it; the page renders the localized sentence **by presence**, never by
> matching domain text. The harness re-pointed to `eva/redesign.html` —
> selector-keyed CSS extraction, anchored to line starts because the light-mode
> override nests the login selectors — and the field's message line is now
> reserved (`min-height:13`, `:379`) so an error arriving moves nothing.
>
> **5.2** (`3e89373`): `/` rebuilt against `:513-538` with ADR-0022 superseding
> the plan's fiction table — the last light is **real** (`GET /streak`,
> `history[0]`), the chip is `/streak/summary`, the verse of the day is
> `TodayReading.firstVerseText + reference`, and the library is the prototype's
> own six scrolls behind a repository port (order, names, counts and completion
> are the fiction; per-book passage text is real). Four sections in `HomeBloc`
> (`streakStatus`, `lastLightStatus`, `catalogueStatus`, reading), and
> `withSection` derives all four so a retry can no longer wipe the board-era
> leftovers. Twelve keys died with the elements they named, twenty-one arrived
> as the redesign's rows (102 -> 111); the composed sentences live in
> `home_l10n.dart` because an ARB placeholder would fail the Latin gate.
> **Five defects the gates caught, not reading:** `LoadLastLight` swallowed its
> failure (`getOrElse` -> `Result.map` — a failed `/streak` reached the card as
> its *empty* state); the carousel's strip padding was `EvaSpacing.md` (12)
> where `.carousel` says 14, which is not a token; the streak chip's
> Arabic-Indic numerals rendered in EB Garamond (zero Arabic glyphs — the
> prototype escapes through browser font fallback, this client through
> `arabicAware`); the selah `✦` (U+2726) is in **no** bundled family and is now
> a painted `_FourPointedStar`; and the shared CSS parser's first regex read
> `opacity: .35` as `35` and `letter-spacing: .16em` as nothing — both fixed in
> `cssPxList` with the measured reason. `GlassTier.blur` now paints the wash and
> the seam beside its read-back (`:250` gives the budgeted site all three),
> which moved the blur-budget gate from "count 1" to "the owner is exempt and
> every other primitive is at 0", re-recorded `glass_surface_blur.png`, and the
> collapsed margins are recomputed from the parsed CSS (`max()` where CSS
> collapses, `+` where a padding blocks the collapse) rather than typed.

> **5.3** (`9664312`): `/reading` rebuilt against `:540-560`, and the research
> pass before it changed the shape of the work: `.vline.in` is **not**
> scroll-driven — it is a timed stagger, `80 + 25n` ms (`:1383`), and the
> `IntersectionObserver` at threshold `.6` governs **star emission and
> last-read bookkeeping only** (`:1211-1219`). So the reveal is schedule-
> driven and the sky is *observer*-driven, and the two live in
> `reading_focus.dart`, a pure-Dart policy with 37 TDD'd tests. The
> prototype's `:177` focus flattening is made **inexpressible** by a
> three-state `VersePaint` enum rather than by a check. The sky is placed
> (`WitnessSky`'s allowlist entry removed by the gate itself) through
> `SkyHandle`/`SkyScope`, the two-closure seam `settings_handle.dart`
> established. **Seven defects the gates caught, not reading:** the
> sanctuary rendered `displayText` and stripped every verse's diacritics
> (decision 51); five tofu sites on the Arabic arm — the title and crumb in
> Inter/mono, the pill's `listen`, the verse numerals, and the dial's `ع`
> on the *English* arm, which is what made `SegmentedControl` grow
> `labelFamilyOf` (`:186` keys that face on the option); the ARB's seven new
> citations were one line high, pinned by a test before the fix; `#crumbMeta`'s
> styling rule is dead CSS (a descendant selector for a same-element class),
> so the port adopts the intent and says so; and `ErrorView`'s retry assert
> caught the rebuilt failure arm shipping unlabelled.

> **5.4** (`840d37a`): `/quiz` rebuilt against `:562-574` — the bare `‹`, the
> centred `Refraction · <reference>` crumb and the gold `✦ N` score, the bead
> row re-homed under the appbar, a centred scripture prompt, four tint-tier
> options and the `.qnext` ghost pill. The score is `QuizSession.runningScore`,
> a domain getter: the payload's `total_points_earned_today` seed plus each
> **correct** submit's `points_earned`, never the client's own guess at a
> verdict — and the star is painted (`FourPointedStar`) because U+2726 is in no
> bundled family. The prototype's `.reveal` is deliberately absent: the wire
> has no correct-letter field, so the client grades only the option the reader
> submitted and never reveals an unpicked one. `FeedbackBanner` and the mono
> `Question N of M` line died with the old chrome; the verdict lives on the
> graded card (colour, glyph, `EvaShake` on wrong, and the `liveRegion` the
> banner used to own). The terminal rule is the prototype's (`:1431-1432`): the
> last graded question's one press is `see results ✦` -> `/result`, so
> `QuizStatus.complete` and `QuizCta.finish` — reachable only by a direct event
> dispatch — are deleted rather than kept as dead branches.
>
> The body is a `SliverFillRemaining(hasScrollBody: false)`, the prototype's
> centred-when-short/scrollable-when-tall pair: at 320×568 the fourth option is
> one scroll away, not dropped. `EvaShake` moved out of `/login` into the
> design system because `.opt.wrong` shares `:360`'s keyframes and `.45s`, and
> a second private copy is the alternative the move removes. `ReadingPage`'s
> lost `@RoutePage()` was restored so the next codegen cannot delete
> `ReadingRoute`. Keys 116 -> 114: `quizRefraction` arrived,
> `quizOfWord`/`quizVerdictCorrect`/`quizVerdictIncorrect` died with their
> elements, and `quizExit`/`quizProgress`/`quizNextQuestion`/`quizSeeResults`
> took the redesign's own copy.
>
> **Five defects the gates caught, not reading:** removing `complete` from the
> CTA guard mechanically let `submitting` through while the answer is still
> `isAnswerable`, leaving an **enabled** Check button whose handler returns
> immediately — a one-frame dead control, now held by a negative-controlled
> bloc test; the first `_Cta` drove its label off `cta` rather than `graded`,
> so a reader with nothing chosen was told a sentence invented for another
> state (`quiz_page_test` caught it); `quiz_geometry_test` parsed the
> three-value `.appbar` shorthand as four and dropped the leading dot from the
> `.75`/`.18` alphas; `quiz_text_scale_test` asserted the fourth option and
> graded card were offstage when they are built, and now scrolls to and hits
> each; and `quiz_accessibility_test` found the back chevron and CTA exposed no
> activatable semantics action because `excludeSemantics: true` drops the inner
> ink's — both now carry `onTap` on the `Semantics` node. Gate run: 2883 tests,
> 98.30% coverage (6083/6188).

> **5.5** (`d8b8484`): `/communion` rebuilt against `:612-636` — and **renamed from
> `/leaderboard`**: the route, the constant, the page class and the generated route all
> moved, because the board is "The Communion" / "الشركة" (`eva/redesign.html:615`'s
> `data-i18n="boardT"`) and ADR-0022 `:121` names the rename. The seventh screen, and
> AGENT_CONTEXT §2's table grew a row with it.
>
> The chrome is the prototype's: a centred app-bar title with a back chevron and a
> **veil** toggle (`:612-617`), an approximate reset countdown (`:618`), the scope and
> metric segmented controls (`:620-625`), the **podium** in its 2nd/1st/3rd order with
> 84/112/64px bars and 40/46/36px orbs (`:1085`), the **you-card** (`:629-633`), and
> the list — which is `sorted.slice(3)` (`:1110`), **always**, whether or not the podium
> is drawn. That last is the prototype's own oddity and it is recorded rather than
> repaired: hiding the podium leaves the top three off the list, because the prototype
> slices by position and never consults the toggle.
>
> The ranking is a **pure function** over the payload, in
> `features/leaderboard/domain/leaderboard_ranking.dart`: under `light` the wire order
> is the server's order and is not re-sorted, and under `streaks` — which the server
> never ranked — the sort is the client's, with the server's `rank` as the tie-break so
> the same payload cannot render two different boards. The window switch is a request;
> the **metric** switch is not, because both numbers are already on every row. The
> prototype's invented month and all-time figures (`×4.35`, `×38.6`, `:1067`) are not
> ported: ADR-0022 `:97-104` names that as fiction, and nothing here scales.
>
> The veil is a **rendering choice over rows that already arrived** — `full_name` is on
> the wire (`leaderboard.routes.ts:59`) — so it needs no endpoint. A veiled witness
> becomes `witness {n}` with a painted hollow star (`:1070`, `:1072`); the reader is
> never veiled, because the prototype checks `p.id==='you'` **before** the veil
> (`:1069`), and the accessible name follows the rendered one, so a voice-over user
> cannot hear what the screen is forbidden to show.
>
> The cheer is a **port with no route** (`core/domain/repositories/cheer_repository.dart`)
> over a session-scoped `Set` (`:1066`), so a witness is cheered once per session. Its
> three effects are the prototype's — the orb pulse (`@keyframes rp`, `:362`), a star
> flare, and a toast (`:947`, 1800ms) — with two divergences recorded at their sites:
> the **flare is row-local and transient** rather than a sky entry, because `SkyEntry`
> is verse-keyed and a board has no verse; and there is **no haptic** and no aurora
> spike, because this app ships none. The toast is anchored to the **screen root** and
> is `pointer-events: none` (`:466`), so it is a notice and never a control.
>
> Keys 114 -> 121, and then 121 -> 126 in the review pass: three died with the old
> layout (`leaderboardScoreLabel`, `leaderboardOpenFull`, `leaderboardYourRank`) and
> ten arrived as the redesign's own table rows (`:941-948`); the review added the
> board's own `leaderboardRetry`, the two controls' accessible names, and the
> prototype's own `dU` / `hU` unit letters. The **Arabic plural arms changed** too,
> which is not a movement but a fix: `leaderboardRowSemantics`'s Arabic arms never
> interpolated `{digits}`, so the Arabic arm announced "نقاط" — "points" — with no
> number in it.
>
> **Twenty-one defects the gates and the reviews caught, not reading.** The gates found
> eleven: the cheer toast was anchored to the **scrolling content**, so it swallowed
> the last row's taps — a reader could not cheer the last witness at all — and could
> sit below the fold entirely; the cheer flare **stuck** on a row rebuilt
> already-cheered, because the board empties on a window change while the marks
> survive it, and the effect was gated on the state rather than on the transition;
> `EmptyState` painted Arabic in EBGaramond and Inter, **tofu for the whole empty
> screen**; the app bar's two tooltips had no family, so the Arabic back label and the
> veil name were tofu; the row's `Semantics` node said "button" with **no action**, so
> a screen-reader user could not cheer at all; the route inventory still said
> `leaderboard`; **two same-named `GetReaderSession` types** sat in one injector graph,
> which the DI inventory could not tell apart; the countdown counted down to the
> *requested* window rather than the response's, which is the one mismatch
> `LeaderboardBoard.window` exists to catch; the toast re-announced a cheer that
> **never happened** on a second tap; the rank numerals were Latin on the Arabic arm
> and every mono run could tofu, because JetBrainsMono carries no Arabic and no
> Arabic-Indic digits; and the podium hid itself below three rows, where the prototype
> skips a missing position instead (`:1087`).
>
> **And the review found ten more that no gate could see:** the app bar's two controls
> had **no accessible name, no `button` flag, and were not keyboard-reachable** — on
> desktop the back chevron is the only way out of `/communion`, so a keyboard-only
> reader could land on the screen and never leave it — and the file justified its own
> bespoke hit-target on a **false** reading of `IconActionButton`, which was the reason
> the ring and the name were missing; the **Arabic row announcement dropped the score
> entirely**, so a screen-reader user was told a witness had "points" and not how many;
> the **cubit had no request-generation guard**, so two window switches in flight could
> land the older response under the newer heading; the **overflow matrix was measuring
> an empty list**, because a three-row board with `slice(3)` lays out no rows at all;
> the **metric control was named "light"**, the same word as its own first option; the
> **you-card said "Not ranked yet"** about a reader the server had ranked 51st; the
> **English dock word was still "Leaderboard"** while its Arabic arm had already
> moved, so the two arms of one key named two different things; the **podium's bloom
> was one wash behind the columns** where the prototype's is per bar, and its three
> bars grew for 480/400/**320**ms where the prototype's grow for 600 each; the **row
> had no entrance at all**, where the prototype fades and rises each row on an
> `80 + k·45` ms stagger; and the **you-card's monogram rule disagreed with the
> mapper's** while its own doc claimed it did not.
>
> Every one of them is **pinned**, and the two that could pass vacuously are
> **negative-controlled**: the toast's placement — the defect that made the last row
> uncheerable — was planted back and watched go red, and the cubit's generation guard
> was removed and watched go red. Gate run: 2988 tests, 98.63% coverage (6713/6806).

> **5.6** (`8034e5b`): `/journey` rebuilt against `:575-610` — **the profile ADR-0001 cut
> and ADR-0022 restored**, which the redesign names "Journey" (`:933`) and makes its
> **third dock tab** (`:707`). The eighth route, and AGENT_CONTEXT §2's table grew a
> row with it.
>
> The screen is a **column of figures**, and the question each figure answers decides
> where it comes from. The **hero number** is `GET /streak/summary`'s `current_streak`
> (the prototype's `12` is a literal written by JavaScript at `:989`); the **name** is
> the reader's own session (`:587`'s "Mariam Hanna" is a literal too); the **lit stars**
> are `SkyRepository.count()` — the port whose own doc already named `journey` as the
> consumer of `count()` before this screen existed; the **three rings** are derived
> from `GET /streak`'s thirty-day history; and the **medals** are ADR-0022's fiction
> behind a **feature-local** port, because §3's placement test is two or more consumers
> and this has one — the same argument `library_catalogue_repository.dart` makes for
> the book catalogue.
>
> The **rings** are a pure function, `features/journey/domain/journey_rings.dart`, and
> each of the three carries a divergence that is recorded at the derivation. Ring 1
> wears the prototype's label — "verses" — over a **scheduled-day completion ratio**,
> because the backend counts *questions* and has no verse count at all
> (`streak.service.ts:5-17`); the same shape as recorded decision 27's "beads count
> questions", and the number is honest while the label is the prototype's. Ring 2 is a
> **bare count**, which resolves the prototype's own inconsistency deliberately rather
> than transcribing it: `:593` writes `data-v="86"` with no percent sign where its
> neighbours write `83%` and `92%`, and a percent sign on a count is a unit the number
> does not have. Ring 3 is correct over answered. **And the count ring's arc measures
> something the count does not**: a ring is an arc and an arc is a fraction, and a bare
> count has no denominator of its own — so the arc is the **share of the scheduled
> questions that were answered**, a ratio the payload does contain, and the difference
> between the number and the arc is recorded where they are drawn. **That fourth
> quantity is the one the brief's fixed API contract did not have**, and the contract
> moved for it: the arcs of two rings that agree on every other field now differ, which
> is exactly what the first version of the class's `==` did not notice.
>
> The **constellations** count is a **proxy**, and says so: the prototype counts books
> whose *final verse* was lit (`constDone`, `:1132`), and this client has no
> book-completion record — the sky keeps keys, a flare flag and a stamp, and the
> 44-star cap evicts. So the count is the distinct books among the **completed**
> scheduled days, and the derivation says exactly what that gives up.
>
> **The colours were the hardest decision, and it was made by measurement rather than
> by taste.** Decision 63's policy is "substitute with a token that exists on both
> themes and record the divergence" — and **there is no token** for the prototype's
> teal `#3EC9B0`, its blue `#4F74FF`, its cream `#F4E3B2` or its amber `#D98E32`. The
> nearest vocabulary, the sticker palette, is not close enough to be a transcription.
> Worse, the **contrast is measured and it fails in the light theme**: the prototype's
> teal is 1.80:1 and its magenta 2.77:1 against the light canvas, and the prototype
> has no light override for the strokes (only the track, at `:79`) — **and every
> candidate token fails too** (sticker teal 1.76, sky 1.67, lavender 2.04, pink 1.91),
> so substitution does not fix it and a cited transcription of the real colour is both
> more faithful *and* no worse. The one colour that **is** a token is the magenta:
> `EvaColors.bloom` is `0x8CE457D6`, so `withValues(alpha: 1)` is `#E457D6` exactly.
> The four transcribed values live in one feature-local table with a cite per line, and
> the colour gate's exemption for it **pins the number of colour constructions in that
> file** — a second one means the table has grown a colour nobody transcribed.
>
> **The glyphs were measured, not typed.** U+2726 (`✦`), U+2720 (`✠`), U+2629 (`☩`)
> and U+2699 (`⚙`) are in **none** of the five bundled families, so none of them is
> ever typed: the star is **painted**, the gear is `Icons.settings`, the trophy is
> `Icons.emoji_events`, and the two crosses **unify on the painted star** because no
> painted cross exists — and the unification is recorded at the site. U+2767 (`❧`) is
> in **EBGaramond only**, so it is drawn as text in the scripture family, **pinned on
> both arms**, because it is not Arabic content and the Arabic face has no `❧`. And
> the percent sign: the prototype's `N()` (`:981`) maps `%` to `٪`,
> `AppLocalizations.digits` is an int helper with no place for a sign, and a
> percentage with a Latin sign on an Arabic arm is a translation defect — so the
> journey has a **feature-local** percent transform and the digits come from the
> shared one.
>
> **The entry point is a correction, and the correction is recorded.** The research
> said to wire `AppTopBar.onAvatarTap` — and **`AppTopBar` no longer exists**: Phase
> 5.2 rebuilt `/` against the redesign, and the redesign's `/` (`:513-538`) has no app
> bar and no avatar at all. Decision 32's "the fix is one argument at one call site"
> had no call site left. So the **dial** takes the journey — the interim holder of the
> destinations Home cannot otherwise reach, which already held the **board**, the
> prototype's other dock tab — and the label is **"Journey"**, the redesign's own word,
> so `seal_fab_test.dart`'s "Profile stays absent" assertion still holds and was
> **updated, not deleted**. Decision 155 named two ways to get a third item back and
> said neither was taken; **the second one was taken**, and the decision is amended
> rather than quietly contradicted.
>
> And because the journey is **pushed** — the redesign's dock is Phase 6's — it carries
> a **back chevron the prototype's journey does not have**, because a pushed screen on
> desktop has no system back button. The prototype's own board is also a dock tab and
> it **does** have a chevron (`:614`), for the same reason.
>
> **The orbs were waiting for this screen.** `OrbGroup.profile` has sat in the design
> system since Phase 2 — cut-and-kept-for-index-alignment, because the profile was cut
> then — and the journey **is** the profile, so `NeuralVariant.journey` takes the
> profile's own group. It is the **one group whose first orb cycles backwards**
> (`ds.tsx:106`), so the orb test's "every variant opens forward" became an exception
> with a named reason rather than a rule that quietly stopped being true.
>
> Keys 126 -> 146, and then **146 -> 147 in the review pass**: the journey's **own**
> `journeyRetry`, because the screen was borrowing the **board's** retry string, and
> the repository namespaces `retry` per screen on purpose — `homeRetry`, `quizRetry`,
> `readingRetry`, `settingsRetry` and `leaderboardRetry` are five separate keys with
> the same value, and a sixth screen taking another screen's copy is the coupling the
> rule exists to remove. The medals' *names* are copy and live in the ARB; the medals'
> *existence* and their "4 / 12" are the fiction and live in the stub — the same split
> `LibraryBook` draws between a book's name and a book's catalogue. And the
> `*UnavailableSuffix` family is now **five** keys, four of which say the same thing,
> and the test asserts that shape rather than "all five differ" — a test that would be
> satisfied by a translator harmonising them, and would be *wrong*.
>
> **Twenty new keys, and one of them was wrong on arrival.** The ARB's Arabic medal
> name read "بوحنا" where the prototype's `m4` row writes "يوحنا" (`:937`) — a ب for a
> ي. The medals agent caught it by reading the prototype's own i18n table back out of
> `eva/redesign.html` at test time, which is why the stub's test reads the prototype
> rather than a fixture.
>
> **And the review found the defects the gates could not.** The **letter-tracking** was
> the big one: every tracking value on the screen was the prototype's `em` number
> written straight into Flutter's **logical-pixel** field, so it was 8×–12× too small
> — and the design system already states the rule and applies it, **including to the
> very same prototype declaration** (`:408`'s `.14em` is `1.19px` in `StatTile` and
> `0.14px` on `/journey`). The same prototype rule was being rendered two ways in one
> app, and the widget's doc claimed a fidelity the code did not deliver. Seven sites,
> each now carrying the **resolved** value and saying so — the house's wording is
> "transcribed as the resolved value and not as `em`". The review also caught the
> draw **curve**: the widget asserted that `--e-light` **is**
> `EvaMotion.interactiveCurve`, and it is not — the prototype's is
> `cubic-bezier(.16,1,.3,1)` (`:18`) and the token is `Curves.easeOutExpo` — so the
> curve is now the prototype's own `Cubic(0.16, 1, 0.3, 1)`, cited, with the token's
> 1.7%-of-progress difference recorded, and the design system's own doc — which made
> the same false identity — corrected to say it is an approximation. And it caught the
> **equality**: `JourneyRings`' `==` and `hashCode` omitted the new `answeredShare`,
> so two rings whose arcs differed compared **equal** — a defect that could only be
> found by reading, because neither the freezed suite nor the derivation's own tests
> varied the field.
>
> **The goldens are the coupling, and they were re-recorded and re-checked.** Twenty-two
> new files — eleven subjects in two themes — and the pairs gate now **walks** the
> journey's golden directory, because a directory nobody walks is a directory nobody
> gates. The medals strip is captured at its own content width (488), not at 390,
> because at 390 the fourth medal is scrolled out and the golden would have pinned
> three of the four washes and not the blue-versus-amber distinction the prototype
> draws. And the strip's golden is what shows the **unification** honestly: four
> washes, and two emblems.
>
> **Twenty-nine defects the gates, the reviews and the agents caught, not
> reading.** **The gates found eight**, and every one of them was an inventory that
> names a number: the DI's registration list stopped at thirty-nine when the
> journey added six; the router's route list and its wildcard-last list were both
> a screen behind; the landing route's "the declared set is COMPLETE" mirror was
> missing `/journey`; the route inventory was nine names for ten constants; the
> freezed suite's converted-type set grew by `JourneyState` and the type needed an
> equality case of its own; **the orphan gate's `SealMonogram` allowlist row went
> stale** the moment the page placed the seal — a false green, and the gate said
> so; the colour gate's exemption **pinned the wrong thing**, counting colour
> *construction sites* while its own failure message claimed it bounded colour
> *count* — so a fifth transcribed colour could have been added with the gate
> still green; and the router's `anyOf` matcher takes **seven** positional
> arguments, so the eighth screen did not fit and the file would not compile.
>
> **The reviews found fourteen**, and three of them are the kind of defect a
> reader would have taken on faith. The **letter-tracking** was the prototype's
> `em` number written straight into Flutter's **logical-pixel** field — 8×–12×
> too small at seven sites, while the design system already resolved the **very
> same** prototype rule correctly in `StatTile` (1.19px against 0.14px), so one
> declaration was being rendered two ways in one app and the widget's doc claimed
> a fidelity it did not deliver. The **draw curve**: the widget asserted that
> `--e-light` **is** `EvaMotion.interactiveCurve`, and it is not — the prototype's
> is `cubic-bezier(.16,1,.3,1)` and the token is `Curves.easeOutExpo` — so the
> curve is now the prototype's own, cited, with the measured divergence (at most
> 1.79% of the draw's progress) recorded, and the design system's own doc — which
> made the same false identity — corrected to say it is an approximation. And
> **`JourneyRings` compared by value but omitted one of its four numbers**, so a
> count ring whose arc had moved compared **equal** to the old one and the cubit
> never rebuilt. The rest: three vertical-spacing declarations transcribed
> nowhere and recorded nowhere; a bare `130` where `/` has a named constant; the
> failure arm borrowing **another screen's** retry string against the rule that
> namespaces `retry` per screen; three `!`s with no adjacent "provably non-null
> because…" comment; **nine prototype citations** pointing at lines that say
> something else; three stale route counts; a decision attributed with the
> **opposite** of what it says; the medal port's own port count; the ARB's
> `*UnavailableSuffix` family described as four when it was five; the
> reduced-motion behaviour presented as a transcription when the prototype's `.rm`
> does not touch a `transition` at all; and a **two-file import cycle** with a
> generated third consumer, which made one of the DI file's imports dead in
> exactly the way nothing can see.
>
> **And the agents found seven in each other's work**, which is the argument for
> running them in parallel and reading each other's output: the **Arabic medal
> name** read "بوحنا" where the prototype's own i18n table writes "يوحنا" — caught
> by a test that reads `eva/redesign.html` at test time rather than a fixture; the
> medals strip's content width given as 460px when it is 452, and a "320"
> requirement attributed to a CSS-variables line that does not mention it; an
> `animateRings()` range two lines wide; a misspelled heading; the screen suite
> making the same 460px mistake; the shared **tooltip probe** releasing its
> gesture before the long press could win the arena, so a screen whose tooltip
> repeats a string painted elsewhere had the **button's own tap fire** — a
> navigation inside a typography probe — and the re-entry reload, which the
> screen suite caught as a failure and the Arabic gate caught independently.
>
> **And one review finding was wrong, and checking it was worth as much as the
> fixes.** The code-quality review reported the profile orb group's two hue
> directions transposed against `ds.tsx:104-107` and recommended swapping them.
> The code does hold `[reverse, forward]` — and so does the prototype:
> `ds.tsx:106` is the profile's **first** orb and its `hueDir` is
> `hue-cycle-rev`. The review had read the values and miscounted the lines.
> Applying the recommendation would have introduced a real bug, and the doc would
> then have said the opposite of the truth. **A finding is a claim, and this
> repository's rule is that a claim about a specific thing is checked against the
> specific thing** — which cuts both ways: it is why fourteen findings were real
> and why the fifteenth was not.
>
> Gate run: 3148 tests, 98.60% coverage (7271/7374).

> **5.7**: `/settings` rebuilt against `:638-700` — **the Workshop**, the
> redesign's name for the screen, and the seventh group of this phase's screens
> to be transcribed rather than stubbed. **Thirty-three rows in seven groups**,
> and the plan's own number for it was the first thing to be wrong.
>
> The plan's task table says "28 new controls" (`:1296`) and its step list says
> "wires **28 fields**" (`:1305-1310`), and **neither number is wrong — they are
> two different counts, and the step list's word is the imprecise one.** The
> prototype's `#rSettings` carries **twenty-nine interactive controls**, one
> action row, one preview line and two static about rows; the twenty-eight is
> that count less the language segment, which is not new because
> `UserSettings.language` already exists. **Of those twenty-eight, five bind to
> fields that already exist** — the Daylight toggle to `themeMode`, Reduce
> motion to `reducedMotion`, the two communion toggles to `veilWitnesses` and
> `showPodium` (Task 5.5's), and the Type-size row to `fontStep` — **so the
> number of NEW fields is twenty-three, and the research report's twenty-five
> is stale by two**: it was written before Task 5.5 landed the communion
> fields, and counted them as new.
>
> **The key prefixes are four, and the plan names three.** The plan's are
> `eva.shader.*`, `eva.sky.*` and `eva.ritual.*`; the sky's are
> `eva.sky.pref.*` — **not** a bare `eva.sky.*`, because `eva.sky.order` and
> `eva.sky.entries` are the **star-record store's** keys
> (`sky_local_data_source.dart:266,269`) and a collision with the store's
> namespace is the kind of thing that is invisible until a reader's preference
> overwrites their lit verses — and the communion's are `eva.communion.*`, which
> the plan did not name because Task 5.5 wrote the two keys before this task
> did. **Neither discrepancy is bent: the plan's own step list says three
> prefixes, and this block is where the correction is recorded.**
>
> **The three enums had to move, and two of them had to move OUT of the design
> system.** `UserSettings` holds `CurtainShape`, `SkyStarShape` and
> `SkyStarField`, and `core/domain/` is Flutter-free under Gate 1 — so a
> `core/domain/` entity **cannot name a type declared beside a Flutter
> widget**, and `SkyStarShape` and `SkyStarField` were declared inside
> `witness_sky.dart` until this task. **`CurtainShape` was a collision**: the
> design system already had one, for the scrim's ramp, and the prototype has
> **one** attribute with **four** values — `el('screen').dataset.shape`
> (`:1463`) — read by two rules, the shader's `u_shape` and the `.scrim`
> overrides (`:114`, `:115`). Two types for one attribute, and a name that
> collided in every file that imported both the barrel and the entity: the two
> are now **one**, in `core/domain/entities/curtain_shape.dart`, and the scrim
> gained a `shafts` arm that paints the base ramp — which is the prototype's
> own behaviour, because the CSS overrides `bottom` and `sides` only and a
> `data-shape="shafts"` element falls through to the base rule (`:112-113`).
>
> **The shader is DEFERRED, and the ten controls that target it are neither
> disabled nor hidden.** `LumenProgram`, `UniformSlot`, `LumenUniforms` and the
> clock are complete and tested, and `LumenCanvas` is mounted **nowhere** in
> production — the plan deferred exactly this ("**Wiring constraint for whoever
> mounts the painter (Phase 5)**", `:805-811`). The ten `eva.shader.*`
> preferences persist real choices, the conversions exist
> (`spreadFromReach`, `brightnessFromGlow`, `ptrIntensityFromTouch`,
> `hslToRgb`), and **the screen does not claim the shader is running**: the
> deferral is recorded at the group and in the group's own ARB description,
> which is where a promise to a reader is made. The consumer task is named.
>
> **The Daylight toggle is TWO states against a THREE-state field, and the
> consequence is a product regression that is recorded rather than buried.**
> On means the light palette, off means the dark one, and a stored `system`
> renders the switch off and is not changed until the reader touches it
> (`:650`, `:1478-1482`). **The Light/Dark/System picker is gone, so
> `AppThemeMode.system` — a shipped capability since Phase 0 — becomes
> unreachable from the UI.** A reader who stored `system` keeps it until they
> touch the control, and can never select it again. **And `cubit.setThemeMode`
> lost its last production caller with the picker** — the only way to write
> `system` is now a method nothing calls.
>
> **The restore is the prototype's reset, field for field, and the scope is
> NARROWER than "every new field".** The prototype's handler (`:1499-1525`)
> resets twenty-three values and **touches none** of the language, the type
> size, the reduce motion, the calm motion or the haptics — and the calm motion
> and the haptics are **new fields**, so "reset every new field" would have
> been a *superset* of the prototype's behaviour rather than its behaviour. The
> client's rule is therefore **"reset exactly what the prototype's
> `resetLight` resets, to the prototype's literals"** — a twenty-three-row
> table and a six-row table, each row citing its prototype line, which is
> checkable field by field. **Three deliberate departures:** the prototype DOES
> reset the daylight to dark (`:1501`) and this client does not, because
> `themeMode` is a three-state enum the decision protects; and the calm motion
> and the haptics are left alone because the prototype leaves them alone.
> **And the hue is the declared default 312, not the current book's** (`:1523`) —
> the client has no per-book hue, and the substitution is recorded at the field
> and at the reset.
>
> **The toast fires only when the write is CONFIRMED**, which is a departure
> from the prototype's shape and a consequence of the client's shape: the
> prototype's reset is synchronous JavaScript and cannot fail (`:1525`), and
> this client's can. A toast that said "nocturne defaults restored" over a
> screen that was simultaneously saying "your preferences could not be saved"
> would be two sentences about one event, and they would contradict each other.
>
> **Four departures from the prototype's own DOM, each recorded at its site:**
> the **language sheet is replaced by the prototype's 2-segment control**
> (`:646-648`) — and `SegmentedControl` already carried a `labelFamilyOf`
> parameter whose own doc names `:186` as the reason it exists, with **no
> caller**; it was a parameter built for a control that had not landed yet. The
> **three segmented rows put the label above the control**, because the
> four-segment control's `4 × 44px` floor (`:183`) cannot share a 264px row with
> a 14.5px label at 320px, and the standing 320×568 viewport matrix is a gate.
> The **version chip carries the app's real version** rather than the design
> system's `v1.2` (`:642`). And **Stars-off hides the sky and does not delete
> the reader's stored verses** (`:1483`) — the prototype's stars are DOM
> elements and this client's sky is a reader's own record of what they have
> read.
>
> **The group header is SINGLE-SCRIPT per arm, and that is a divergence from
> the prototype's own bilingual label.** `:949` writes `wsLang:["language ·
> اللغة","اللغة · language"]` — each arm naming the thing in the reader's script
> and then in the other one. **That cannot be one ARB value**: the English-arm
> half of the bilingual contract is absolute ("the English arm holds no Arabic
> script at all", no exemption list), and a bilingual value breaks it in both
> directions at once. Each arm keeps the prototype's first half — `language` and
> `اللغة` — and the pairing is recorded at the group header. **The seven
> untranslated segment labels are the OTHER side of the same rule**: they are
> the prototype's own untranslated English (`:673`, `:678`), and they are
> **widget literals, not ARB keys**, because putting them in the ARB would have
> forced them into `mustBeIdentical` — the set that catches an untranslated
> string. Their correctness on the Arabic arm is asserted where they are
> painted.
>
> **The `↺` (U+21BA) is in NO bundled mono or scripture face** — measured
> against all twenty shipped `.ttf` files, it is absent from `JetBrainsMono`,
> `EBGaramond` and `Amiri` and present in `Inter` and `IBMPlexSansArabic` — so
> it is rendered with a **`fontFamilyFallback`**, which falls back PER GLYPH:
> the mono face draws the letters and Inter draws the arrow. **And it cannot be
> mirrored by `matchTextDirection`**, because that is an `IconData` property and
> U+21BA has no `Bidi_Mirrored` property, so the prototype's `:138` mirror is
> an explicit transform. **The shared Arabic gate was taught the fallback**,
> because a correctly-rendered glyph is not tofu and the gate was reporting it
> as tofu.
>
> **Three new design-system widgets, and the orphan gate satisfied by
> PLACEMENT**: a **range slider** (`:429-430` — 3px rule, 120px track, a 15px
> ember thumb with the prototype's `0 0 10px` glow), a **hue swatch** (`:432` —
> a 16px circle whose glow is `currentColor`, so the swatch's OWN colour), and
> a **preview line** (`:431`). Two existing widgets grew a mode: the segmented
> control gained the prototype's `.segp.wide` (`:188-189`) and the settings tile
> gained a stacked axis. **The default mode's tree is byte-identical** and no
> existing golden moved.
>
> **AND THE TWO REVIEWS FOUND THIRTY-ONE DISTINCT DEFECTS, MOST OF THEM CLAIMS
> THAT WERE NOT TRUE** — and the agents found nine more the reviews did not
> reach, and the gates caught two of this task's own. The `em` letter-spacing rule — the single most likely
> defect in the task, and the one 5.6 shipped seven times — **held on every one
> of the four tracked runs**. What the reviews found instead: **four wrong
> prototype citations** (the preview line's element at `:694` and not `:696`; the
> constellation's refusal at `:1168` and not `:1172`; `veilOn=false` at `:1065`
> and not `:1057`; and the `×1000` at `:1292` and not `:1287`), and **the last
> two of those were in files this task had already rewritten**. **Four wrong
> numbers**: "twenty switch rows" where the prototype has **sixteen** and the
> cited list had fifteen; `EvaSpacing.huge` as 48 when it is 40; "four of the
> seven" ritual controls unread when it is **six**; and the ARB's claim that
> the prototype's `I18N` table and its markup disagree about the Brightness
> row — **they do not**: the table's KEY is `glow` and its VALUE is
> `Brightness`. **And two plan citations that had gone stale** — the Phase 7
> ritual step had moved to `:1685-1686` — **in the brief as well as the code**,
> so the implementer copied them faithfully.
>
> **THE TWO GATES THIS TASK CHANGED BOTH HAD DEFECTS IN THEMSELVES, and the
> finding worth keeping is that the instruments were wrong rather than the
> code.** The **converted-types audit** matched a test declaration **per line**,
> so a `testWidgets(` whose name is on the next line was never a boundary — and
> a missed boundary is not a missing site, it is a site attributed to the
> *previous* test. It also counted the word `identical(` inside a **string
> literal** — a test's own NAME — as an identity call, so the table carried a
> row for a test that has never held an identity assertion, with a reason that
> described something else entirely. **Both are fixed, four rows are re-pointed,
> and the row that was counting a test's name is GONE rather than re-pointed.**
> `tool/nct_selftest.sh` discharges the rule with three plants, the third of
> which runs the **old** scan against the same file to show the string-literal
> rule is what changed the outcome.
>
> **AND THE AGENTS FOUND THE REST.** The **`CurtainShape` collision** — two
> enums, one name, and the fix was to MERGE them rather than rename one,
> because the prototype has one attribute. The **seven `SettingsHandle` sky
> writers with no production caller**: the brief asked for them on the premise
> that "`/reading` needs to write the sky preferences", and that premise was
> **wrong** — `/reading` *reads* the seven and writes none of them — so the
> brief's two halves contradicted each other and the seven are gone, with the
> screen writing them through the cubit like every other field it owns. The
> **step rule written twice** — the design system's copy in a Flutter-importing
> file that a pure-Dart settings domain may not import, which is *why* the
> second copy existed; it is now one pure function in `core/common/ranges.dart`
> that both reach. The **pointer→value arithmetic inside a `build` closure**,
> which the same task had extracted elsewhere in the same commit. The **two
> published constants with no reader** on the app bar, which the build now
> uses. The **`↺`'s and the toast's numbers written as literals** while the
> same screen borrowed 10.5 from a token — so the app has one spelling of it
> now. And the **two `Text('A')` glyphs** the size stepper announced as "A"
> twice, which are now excluded from the semantics tree.
>
> **AND ONE REVIEW FINDING WAS WRONG IN A WAY THAT WOULD HAVE COST SOMETHING.**
> The code-quality review reported the segmented control's wide mode as
> **tracking and upper-casing its labels under RTL**, against `:190` — and it
> was right. But the Arabic gate, in the same pass, had **recorded the same
> divergence and deliberately not "fixed" it**, because the fix belonged to the
> widget rather than to the gate. **Both were right about the same fact, and
> the fix landed in the widget** — so the Arabic arm now reads `dot` where the
> prototype writes `dot`, and not `DOT`.
>
> Gate run: **3478 tests, 98.62% coverage (7853/7963)**, against the recorded
> floor of 2507 tests and 98.25% — **and the Linux build gate, which is the
> first task in this phase whose plan block can say so.** `tool/verify_linux_build.sh`
> had read a `flutter doctor` log **it never wrote**, so it could not pass on a
> clean machine; the step now runs the doctor, and the gate reports
> "PASSED — the Linux bundle is a real build of the current sources".

### Task 5.8: The aurora, mounted

> **The shader has been built and tested since Phase 1 and mounted nowhere.**
> `lumen.frag`, `LumenUniforms`, `UniformSlot`, `LumenClock`, `LumenProgram`
> and `LumenCanvas` are all complete — and `LumenCanvas` had **no production
> call site**, so the ten `eva.shader.*` preferences Task 5.7 landed were
> real, persisted and clamped, and **read by nothing**. The plan deferred
> exactly this to "whoever mounts the painter (Phase 5)" (`:805-811`), and
> Task 5.7 recorded the deferral at the group and in the group's own ARB
> description. **This task discharges it.**
>
> **WHERE IT IS MOUNTED, AND WHY THAT IS NOT A CHOICE.** `eva/redesign.html:46`
> is `.screen canvas{position:absolute;inset:0;…;z-index:0}` — the canvas is
> a **child of `.screen`**, and `.screen` is the prototype's screen root
> (`:45`). There is **one** canvas, and it is the screen's own background
> layer: not a decoration, and not one per screen-variant. The client's
> screen root is `NeuralScaffold`, whose stack already carried the ambient as
> its first child, so **the mount is that layer** and the legacy
> `NeuralBackground` becomes the **fallback** rather than the ambient.
>
> **THE REDESIGN HAS ONE AMBIENT AND THE CLIENT HAD EIGHT, and that is
> recorded rather than hidden.** `NeuralVariant` has eight values and eight
> orb groups; the redesign has one canvas for every screen. So
> **`NeuralVariant` no longer selects the ambient — it selects the
> *fallback's* orb group**, which is the only thing that still varies by
> screen. It is not deleted, because the plan never retired it and the
> fallback is a thing the design has.
>
> **THE SCENE IS THE PROTOTYPE'S RENDER LOOP, AND IT IS APP-GLOBAL.** The
> prototype's eased state — the hue, the ambient intensity, the spike — lives
> in one JS closure behind one canvas (`:881-912`), and it **survives a screen
> change**. So the *state* is app-global (in `EvaNeuralMotion`, beside the
> four clocks it already owns) and the *painter* is per mounted screen,
> because a `CustomPainter` belongs to the widget that paints it. **And
> because Phase 6's `AutoTabsRouter` keeps three tab screens alive at once**:
> per-screen state would put the three tabs at three phases of one aurora and
> the tab swap would visibly jump. One scene, one phase.
>
> **THE FOUR STEPS OF `:887-912` THAT ARE NOT THE SHADER'S OWN ARITHMETIC**,
> each with the prototype's number:
>
> | line | what | how fast |
> | --- | --- | --- |
> | `:891-892` | the ambient intensity eases toward its target | 6% a frame |
> | `:893` | the melt drifts the hue | 8° a second |
> | `:894-896` | the hue eases toward its target, **the short way round** | 4.5% a frame |
> | `:900` | the spike decays | ×0.92 a frame |
>
> **AND THE MELT IS NOT ONLY A FLAG.** `:893` cycles `autoH` at 8° a second
> while the melt is on, and the Workshop's slider follows it (`:1457`
> `syncHueUI`) — so the melt is a second animation, and the client's swatch
> does **not** follow the drift. That is a divergence, recorded here.
>
> **THE TEN CONTROLS ARE THE AURORA'S INPUTS, ONE FOR ONE**, and the
> prototype's own conversions were transcribed rather than re-derived:
> `reach`→`u_spread` (`:1469`), `touchGlow`→`u_ptrI` (`:1471`),
> `hue`→`u_hue`/`u_hue2`/`u_hue3` (`:1472`), `multichromeMelt`→`u_melt`
> (`:1473-1474`), `rayCombing`→`u_str` (`:1475`), `whiteCores`→`u_white`
> (`:1476`), `dotVeil`→`u_dots` (`:1477`), `curtainShape`→`u_shape`
> (`:1462-1463`), `glow`→**not a uniform** (`:1470` folds it into the
> ambient target, `:891`), and `shaderEnabled`→**the canvas is hidden**
> (`:1468`).
>
> **THE HUE'S SATURATION AND LIGHTNESS ARE `70` AND `62`, NOT THE BOOT
> STATE'S `90` AND `66`.** `:1472` posts `{h:autoH,s:70,l:62}`; `curH` starts
> at `{h:258,s:90,l:66}` (`:881`) and *eases* to the target. A port that took
> the target's s/l from the boot state would be a different colour at the end
> of the transition and the same colour at the start.
>
> **AND THE CLIENT'S HUE OPENS AT THE READER'S CHOICE, NOT AT 258.** The
> prototype opens at 258 because its slider starts out of sync with `autoH`;
> the client's slider and its aurora agree from the first frame, which is the
> divergence Task 5.7 already recorded for the swatch. The **ambient
> intensity still opens at the prototype's `0.15`** (`:884`) and fades in.
>
> **`u_light` IS THE APP'S THEME, NOT A WORKSHOP CONTROL.** The prototype's
> daylight toggle (`:1478-1482`) writes **two** things: `dataset.mode='light'`
> (the whole app's palette) and `uniform1f(V.uni.light,…)` (the shader). So
> the client's `u_light` is read from `Theme.of(context).brightness`, and the
> prototype's `.4` spike on a daylight change rides on it.
>
> **THE HARDEST PART WAS HARD RULE 2, AND IT IS WHY `LumenCanvas` CHANGED.**
> The plan's rule is one `FragmentShader`, mutated per frame — and the
> prototype's uniforms change **every frame** (the hue, the ambient, the
> spike). A table held in a constructor field cannot do that: the painter
> would be **rebuilt** every frame, and a rebuilt painter is a new instance,
> and a new instance allocates a new `FragmentShader` — the per-frame uniform
> buffer the rule exists to remove, back through the front door. So
> **`LumenCanvas` gained a `LumenUniformSource`**: a source that is both the
> table and the **repaint signal**, read at paint time. The ordinary
> constructor is kept and behaves **exactly** as it did — a fixed table, the
> clock as the repaint — so every one of Task 1.3's frame tests stayed green
> and the change is **additive**.
>
> **AND THE SOURCE IS THE SIGNAL RATHER THAN THE CLOCK, and that is not an
> afterthought.** The source advances its table and *then* notifies; a paint
> triggered by that notification reads the frame it just computed. If the
> clock were the signal, the paint would race the advance and the winner
> would depend on the order the listeners happened to be registered in.
>
> **THE FALLBACK IS TODAY'S BACKGROUND, AND THE TIER DECIDES.**
> `NeuralTiers.resolveShader` already decided `off`/`noShafts`/`full` and
> already treated reduced motion as the last word; its own doc said *"wiring a
> painter to it belongs to whoever mounts the shader (Phase 5), not to this
> file. Nothing here is mounted anywhere."* — **this task is that wiring, and
> the decision layer is not changed, only connected.** `noShafts` clamps a
> stored `shafts` to `sides` (shape 2) rather than forgetting it, exactly as
> that enum's doc assigns to the mounter.
>
> **THE PREFERENCES REACH THE DESIGN SYSTEM THROUGH A SCOPE THE APP ROOT
> PUBLISHES**, because `lib/core/` may not reach into a feature and the
> ambient lives in `lib/core/design_system/`. `LumenPreferences` is a **narrow**
> type — ten of `UserSettings`' thirty fields — because the scope sits above
> every screen and a notification rebuilds all of them, so the reader changing
> their **font size** must not rebuild one. A subtree with no scope paints the
> fallback: an ambient with no choices published has no choices to paint
> with.
>
> **THE PROGRAM IS LOADED BEFORE THE FIRST FRAME.** `LumenProgram.load()` is
> async, and a background that must await before it can paint shows the
> fallback for a frame or two and then swaps — a visible flash of the old
> design at every launch. `bootstrapApp` loads it, `LumenProgram.loaded()`
> reads the same memo synchronously, and **a failure does not stop the
> launch**: the ambient has a fallback, so a missing asset costs the reader
> the aurora and not the app.
>
> **THE POINTER IS TRACKED ON THE **SCREEN ROOT**, AND THAT IS A CHANGE OF
> PLACE.** The prototype listens on `#screen` — the **root**
> (`:916`, `el0('screen').addEventListener('pointermove',…)`) — so its canvas
> follows the pointer across the whole screen. A listener in the background
> layer would only see the moves the content above it does not absorb, and
> the "Touch glow" control would be largely inert. So the listener is on
> `NeuralScaffold`, and the background reads the pointer from the scene.
> The prototype's `pointerleave` (`:921`) is a `PointerExitEvent`, which
> `Listener` does not have on this SDK; the **touch** case — a finger
> lifting — is an `onPointerUp`, and that is what the client resets on. A
> **mouse** leaving the *window* leaves the glow where it was.
>
> **AND THE DAYLIGHT MODE MULTIPLIES, AND WITHOUT IT THE LIGHT SCREEN IS A
> WHITE SHEET.** `eva/redesign.html:60` is
> `.screen[data-mode=light] canvas{mix-blend-mode:multiply}` — and it has to
> be: the shader's daylight arm is
> `col=mix(emit, vec3(1.0)-0.55*em, u_light)` (`shaders/lumen.frag:116`),
> and with `u_light=1` and no band (`emit=0`) that is **`vec3(1.0)`** —
> white, at alpha 1. Painted over the canvas it erases it, and every
> light-mode card that distinguishes `canvas` from `surface` loses the
> ground it stands on. **The client's aurora is multiplied by the canvas
> colour**, which is what the prototype's `multiply` amounts to — the
> backdrop under an opaque canvas is the canvas. **And it is a
> `ColorFilter`, not a `BlendMode`**: a blend mode would multiply against
> the *destination*, and the destination inside the `RepaintBoundary` is
> transparent, which would paint the ambient **black**. The filter
> multiplies the aurora's own pixels, so the boundary cannot break it.
> **Measured:** the bottom of the light screen read **255** (opaque white)
> before the fix and reads the canvas's **240** after it.
>
> **FIVE DIVERGENCES, RECORDED RATHER THAN BURIED.** (1) `u_time` is the
> clock's real elapsed seconds, where the prototype's is a `dt`-capped
> accumulator (`:888`) — the two agree at any frame rate at or above 20fps
> and diverge below it, and a second accumulator inside the scene would be a
> second source of truth for time, which `lumen_clock.dart` exists to
> prevent. (2) `vesp` and `focusDim` are `1` and `false` — they are the
> vespers auto-dim and the focus-mode dimming, and they are **Phase 7's**.
> (3) The reduced-motion `0.15` scale on `u_time` (`:888`) is Phase 7's
> ("a shader clock frozen at `t = 0`"); the client freezes the clock
> instead, which is a different answer to the same question and is recorded
> here rather than claimed as the port. (4) The prototype's loop **stops**
> while the aurora is hidden (`:889` returns before `:891-896`), so its state
> freezes; the client's scene keeps easing, so the aurora is **converged**
> when it comes back rather than mid-transition. (5) The **"Curtain shape"
> control drives one of the prototype's two rules**: `:1463` sets
> `u_shape` **and** `dataset.shape` — the full-screen `.scrim` — and the
> client has no full-screen scrim (`NeuralScaffold.curtain` is the CTA's
> bottom fade). The shader's half is wired; the scrim's half is Phase 6's
> or nobody's, and it is named here so it is not lost.
>
> **AND THE PAINTER IS PER MOUNT, SO THE UNIFORM BUFFER IS TOO.** The plan's
> hard rule 2 is one `FragmentShader` per painter and not one per frame —
> which holds, and the suite pins it. But a painter is per **mounted
> screen**, so a route change builds a new one and Phase 6's three live tabs
> would hold three. Identical pixels, three uniform buffers, and a new one
> per navigation. Recorded rather than hidden.
>
> **AND THE REVIEW FOUND FOUR THINGS THIS BLOCK WOULD OTHERWISE HAVE
> SHIPPED.** (1) **The daylight mode painted an opaque white sheet** — the
> prototype's `mix-blend-mode:multiply` (`:60`) was not ported, and the
> shader's daylight arm is white where there is no band. **Measured** before
> and after: the bottom of the light screen read **255** and reads the
> canvas's **240**. (2) **The pointer was tracked in the background layer**,
> where the content above it absorbs the moves — the prototype tracks it on
> `#screen` (`:916`), and the "Touch glow" control was largely inert. (3)
> **The hue slider did nothing while the melt was on**, because the prototype's
> slider writes `autoH` (`:1472`) and the melt follows it (`:893`) — the melt
> follows the slider, not the other way round. (4) **The aurora switch's
> spike was raised in both directions** and the prototype raises it only when
> the aurora is turned **on** (`:1468`'s guard is `shaderOn`). And **five
> stale claims** — "the shader is not mounted", in `curtain_shape.dart`,
> `neural_background.dart`, `workshop_logic.dart` and twice in
> `settings_page.dart` — were false the moment the mount landed, and are now
> true statements about what is mounted.
>
> Gate run: **3544 tests, 98.69% coverage (8109/8217)**, against the recorded
> floor of 2507 tests and 98.25% — **and the Linux build gate**, which
> reports "PASSED — the Linux bundle is a real build of the current sources".
> The coverage is **up** on Task 5.7's 98.62%, and the test count is up by
> sixty-six.

| Task | Screen | Prototype | Source of its data |
| --- | --- | --- | --- |
| 5.1 | `/login` | `:503-511` | `FakeAuthRepository` (unchanged) |
| 5.2 | `/` | `:513-538` | streak real · VOTD real · last-light local · library hardcoded list |
| 5.3 | `/reading` | `:540-560` | real, + the sky from Phase 3 — focus mode must preserve a ≥3:1 distinction between in-view and out-of-view verses, never flatten to a single `#d9dfef` (`redesign.html:177` flattening is 1.000:1 in-focus; see Phase 2 Task 2.2 Step 3) |
| 5.4 | `/quiz` | `:562-574` | real |
| 5.5 | `/communion` | `:612-636` | `GET /leaderboard?window=` |
| 5.6 | `/journey` | `:576-610` | streak real · rings derived · medals **stubbed** |
| 5.7 | `/settings` | `:638-700` | local · 28 new controls |
| 5.8 | — (the ambient) | `:46`, `:881-912` | the reader's ten `eva.shader.*` preferences |

- [ ] **Step 5.5 details.** `window=weekly|monthly|all_time` maps exactly onto
  the redesign's week/month/all. Rows already carry `full_name` and
  `current_streak`.
- [ ] **`total_ranked` is the page length, not the cohort.** `?limit=2` returns
  `"total_ranked": 2`. **Never render it as "N students."**
- [ ] **Ties break by UUID string order**, which is meaningless. Do not imply a
  tiebreak rule the backend does not have.
- [ ] **5.7** wires 28 fields through the existing chain:
  `SettingsPage → SettingsCubit.apply → UserSettings → SettingsRepository →
  SettingsLocalDataSource → SharedPreferences`. Keys: `eva.shader.*`, `eva.sky.*`,
  `eva.ritual.*`. `restoreLight` resets every one to the prototype's literal.
- [ ] **Widget and screen work is TDD-exempt** (§6). Behaviour tests, widget
  tests and goldens are written *alongside* the widget.
  **But domain logic must not be buried in a widget** — a widget that computes
  the gap or the verse count inline is untested logic wearing a `build` method.
  Extract it to a cubit or a pure function and TDD that.

---

# Phase 6 — Navigation

- [x] **Step 6.1: `AutoTabsRouter`.** Home / Communion / Journey are real tabs;
  Read / Today are push actions. The dock hides on reader/quiz/workshop.
- [x] **Step 6.2: `/result` stops being a route.** It becomes a modal
  (`:718-727`). `app_router_test.dart`'s assertion that `pushPath('/result')`
  **fails** (decision 81) **must be deleted, not weakened** — the invariant it
  pinned is gone because the route is gone.
- [x] **Step 6.3: `AppRoutes.fallback` (`*`) stays last.** Moving it first turns
  **46 tests** red.
- [x] **Step 6.4: Replace the single `fadeSlide`** with the redesign's
  `gone-left` / `gone-right` / tab-swap transitions via
  `RouteType.custom`.

> ### THE DOCK IS A **FEATURE**, AND THE SHELL IS THE **COMPOSITION ROOT'S** — and
> the two are different directories for a reason that is not tidiness.
>
> The plan's file map names one new file,
> `lib/features/dock/presentation/widgets/lumen_dock.dart`, and that is exactly
> what landed: the dock is **presentational** — five slots, an active index and
> a tap callback — and it knows nothing about routing, features or the locator.
>
> **The shell is a different thing and it does not live in the feature.** It
> hosts the three tabs, so it must name all three of their routes, and
> `HomeRoute` / `CommunionRoute` / `JourneyRoute` are three different features'
> routes. AGENT_CONTEXT §3 forbids a feature importing another feature **with no
> exceptions**, so a shell inside `features/dock/` would have made the dock
> feature depend on the home, the board and the journey.
>
> The alternative considered and rejected: `AutoTabsRouter(routes: null)`, which
> derives the children from the router's route collection
> (`routing_controller.dart:837` — `routeCollection.routes.map((e) =>
> PageRouteInfo(e.name))`). It works, and it is **not** used, because the
> derived list is built from *names* in *declaration order* with no way to say
> which route is which, and the tab order is load-bearing: it is the order the
> dock's three real slots switch in. An explicit list says it, and
> `app_router_test.dart` reads the live `routes` getter and pins it.
>
> `lib/app/` is the one directory Gate 2 exempts, because reaching into
> features to wire them up is the composition root's whole job. The shell is
> composition.

> ### THREE TABS, FIVE SLOTS, AND THE TWO NUMBERING SCHEMES ARE **NOT** THE SAME.
>
> The prototype's dock has **five** slots (`eva/redesign.html:702-708`) and its
> `TABMAP` (`:1248`) maps them onto screens. **Read that map**: `home→'home'`,
> `reader→'read'`, `quiz→'today'`, `journey→'journey'`, `board→'board'` — and
> the click handler (`:1277-1279`) shows that `read` and `today` are **push
> actions**: they open the reader and the quiz rather than switching a tab.
>
> So the client has **three** tabs and **two** push actions, and the dock
> carries all five slots. **The active marker therefore maps a tab index onto a
> slot index** — the board is **tab 1** and **slot 3** — and that mapping is
> written down in the shell rather than left to arithmetic. The prototype's own
> `TABMAP` is the evidence that the two schemes differ; a reader who assumed
> they were the same would light the wrong slot.
>
> **AND THE DOCK HIDES ON THE READER, THE QUIZ AND THE WORKSHOP BY GEOMETRY,
> NOT BY A RULE.** The prototype does it with a class (`:1251` — the dock is
> visible on `home`, `journey` and `board` only) and slides the dock away
> (`.dock.hide`, `:215`). The client's dock lives inside the shell, and the
> reader, the quiz and the workshop are **root routes pushed over the shell** —
> so pushing one covers the shell, and the dock with it. The same observable
> outcome, a different mechanism, and the divergence is recorded here rather
> than left for a reader to find by looking for a slide that is not there.

> ### THE THREE TAB PATHS ARE **RELATIVE**, AND THEY ARE **DERIVED**.
>
> auto_route rejects a child path that begins with a slash
> (`RouteCollection.fromList` — `Sub-paths can not start with a "/"`), so the
> shell's children are `''`, `communion` and `journey` while the URLs they
> produce are `/`, `/communion` and `/journey`. **Nothing a reader can type has
> changed.**
>
> The relative path is **derived from the absolute one**
> (`AppRoutes.communionTab => communion.substring(1)`) rather than written a
> second time. A second literal would be two sources of truth for one value, and
> this repository has removed three of those on purpose (AGENT_CONTEXT decision
> 5, decision 68). They are **getters** rather than `static const String`
> declarations on purpose: `tool/route_check.dart` enumerates the declared
> constants of `app_routes.dart`, and the inventory it produces is a list of
> **absolute URLs** — a relative child path is not one of them, and it is
> covered because the constant it derives from is.

> ### A TAB SWITCH IS `setActiveIndex`, AND A PATH PUSH WOULD HAVE PUSHED A
> **SECOND SHELL**.
>
> The journey's "open the board" control used to be
> `context.router.pushPath(AppRoutes.communion)`. With the board as the shell's
> **second child**, that path matches the shell **and** the child, so pushing
> it would put a **second shell** on the root stack with the board's tab
> active — two docks, two sets of tab state, and a `currentPath` that says
> `/communion` while the stack says otherwise.
>
> So the control switches tabs: `TabsRouterScope.of(context)?.controller
> .setActiveIndex(DockTabs.communion)`. **The nullable lookup is the one**, and
> the reason is mechanical: `AutoTabsRouter.of` **asserts** when there is no
> tabs router above, which would take the tree down on a tap in a widget test
> that mounts the page bare, while `TabsRouterScope.of` returns `null`.
>
> **The same applies to the board's chevron**, which used to `maybePop()`: the
> board is a tab, so there is nothing to pop, and the chevron now returns to the
> **previous tab** — the one-branch form of the prototype's own two branches
> (`:1282` — `boardEntry==='push' ? pop('journey') : tab('home')`), because the
> reader's previous tab *is* the journey when they came from the journey.

> ### THE RE-ENTRY TRIGGER MOVED TO THE **SHELL'S** ROUTE DATA, AND THAT IS A
> **CORRECTNESS** FIX, NOT A REFACTOR.
>
> Recorded decision 41 fixed "`/` re-loads on re-entry" by subscribing to the
> route's `didPopNext`. **A tab is never popped**, so the home's own route data
> would never produce a `didPopNext` again and the reload would have died
> silently — the reader would have come back from a reflection and seen the
> streak they had **before** it.
>
> The shell **is** popped, and it is popped exactly when the screen pushed over
> it — the reader, the quiz, the workshop — is popped and the tab underneath is
> showing again. And auto_route's observer hands `didPopNext` to the
> **previous** route's subscribers (`auto_route_observer.dart:168`), so the
> **shell's** route data is the one to subscribe under. The home and the
> journey now subscribe to `TabsRouterScope.of(context)?.controller.routeData`,
> with the page's own route data as the **bare-tree** fallback — a page mounted
> over a bare `MaterialApp` has no shell, and there the old behaviour is right.

> ### `/result` IS A MODAL, AND THE **FEATURE** MOVED INTO `features/quiz/`.
>
> Step 6.2 says the result "becomes a modal". The screen's **presentation**
> became the prototype's — a centred card over a veil, 82% wide, radius 28,
> padding 34 × 28, a 24px backdrop blur, and the card's scale .9 → 1 over
> 500ms (`:442-446`, `:433-434`).
>
> **The content did not, and the reason is the backend.** The prototype's
> modal draws a ring with `score/qEff` in the middle (`:721`), and
> **the submit response carries no question count** — AGENT_CONTEXT decision 93
> records exactly this, and it is why the client's `/result` had no denominator
> either. So the ring is **not** ported; the client keeps its score, its
> message, its streak pill and its two stat tiles. A ring with an invented
> denominator would be a number the server never sent.
>
> **And the feature is gone, because Gate 2 forbids the alternative.** The
> result had no `domain/` and no `data/` — it was presentation-only, and
> `result_module.dart` registered nothing. But the quiz has to *show* it, and
> `features/quiz/` importing `features/result/` is a feature importing a
> feature. The alternatives were a port (the port's method cannot take a
> `BuildContext` in a pure-Dart directory, so the seam would have had to be a
> `Widget`-returning factory, which is not pure Dart either), a locator read
> (a feature reaching into the composition root), and a design-system screen
> (a whole product surface in the primitives). **The move into
> `features/quiz/` is the cheap one**: the result is the quiz's outcome, shown
> over the quiz, and the two are one feature.
>
> The ARB keys keep the `result` prefix, and that is a **recorded divergence**:
> the prefix names the *surface*, and decision 101's stated purpose — every key
> being findable, and no two keys colliding — is served either way.

> ### THE `SealFab` IS DELETED, AND THE DOCK IS WHAT REPLACED IT.
>
> `/`'s speed dial was, in its own doc, "the interim holder of the destinations
> Home cannot otherwise reach **until Phase 6's dock**". The dock now holds two
> of its three destinations — the board and the journey, which are the
> redesign's own dock tabs (`:706`, `:707`) — and the third, the workshop, is
> reached the way the prototype reaches it: from the journey's app-bar gear
> (`:582`) and its account row (`:606`).
>
> **And the redesign's home draws no float at all** (`:513-538`), so keeping
> the dial would have put a control on the screen that the design does not have
> and that says the same thing as two of the dock's five slots.

> ### THE JOURNEY'S BACK CHEVRON IS GONE, AND THE REASON WENT WITH IT.
>
> The chevron was there because the journey was **pushed**: a pushed screen on
> desktop has no system back button, so the chevron was the way out. The
> prototype's journey is only ever a tab (`:576-583` — no chevron, a 68px
> spacer instead) and never needed one. **The journey is a tab now, and the
> spacer is the prototype's own** (`:578`).

> ### ONE TRANSITIONS BUILDER, TWO POSES, AND BOTH DIRECTIONS.
>
> The prototype has **two** route poses — `gone-left` (`:129` —
> `translateX(-28%) scale(.96)`) and `gone-right` (`:130` —
> `translateX(38%) scale(.98)`) — and uses the first for the route a push
> covers and the second for the route a pop covers.
>
> **A single builder reproduces both**, because the two poses are the same two
> poses used in opposite directions: the *enter* pose is `gone-right` and the
> *exit* pose is `gone-left`, and a pop runs the same animations backwards. The
> builder applies the enter pose to `animation` and the exit pose to
> `secondaryAnimation`, and **the two must be combined into one transform** —
> two stacked `SlideTransition`s would each write the transform and the last one
> would win.
>
> The duration and the curve are the prototype's: 400ms (`:128`'s `.4s`) and
> `--e-light` = `cubic-bezier(.16,1,.3,1)` = `Curves.easeOutExpo`, which the
> repository already had as `EvaMotion.interactiveCurve` (decision 134 measured
> it).
>
> **AND THE FRACTION IS OF THE ROUTE'S WIDTH, NOT OF THE PAGE'S.** The
> prototype's `translateX(-28%)` is a percentage of the route, and a page that
> does not fill its route would be measured against its own width by mistake.
> The builder reads `constraints.maxWidth` through a `LayoutBuilder`, and the
> test discriminates the two readings with a 100px page inside a 400px route —
> 38% of the route is 152px of travel and 38% of the page is 38px, four times
> apart.

> ### TWO GATES LEARNED SOMETHING — AND ONE OF THE TWO PROOFS WAS NOT A PROOF
>
> **The blur budget moved from one site to two, and it learned a second
> spelling.** The redesign's own dock blurs (`:210` —
> `backdrop-filter:blur(22px)`), so `lib/features/` now spends **two**: Home's
> card and the dock, and the dock is **one** `BackdropFilter` for three tabs
> rather than three. The gate counted `GlassTier.blur` only, so a **hand-built
> `BackdropFilter`** — which is what a full-width bar over the page has to be,
> because `GlassSurface` paints a *panel* — was **invisible to it**.
>
> **And the count became a count of SITES rather than of lines**, because the
> dock spells its one site over two lines (`BackdropFilter(` on one,
> `ImageFilter.blur(` on the next) and a line count would have charged the
> budget for a blur that does not exist. The dock's site is charged to the
> budget like any other — the exception is about the **shape**, not about
> escaping the count.
>
> **AND THE WALK WAS TWO DIRECTORIES, WHICH WAS THE SAME BLIND SPOT ONE
> DIRECTORY OVER.** The gate walked `lib/features/` and
> `lib/core/design_system/widgets/`, and `lib/` has more directories than that:
> `lib/core/design_system/effects/` and `lib/app/` were **never walked at all**,
> and `lib/app/` is exactly where this phase put the navigation chrome. A real
> `BackdropFilter` planted in either left the gate **green**. So the walk is
> now **`lib/` as a whole**, and the **only** exclusion is `glass_surface.dart`
> — one root, one exclusion, and the rule the file's own doc already stated.
> Proved in a scratch copy, in both directions: a planted `BackdropFilter` in
> `lib/core/design_system/effects/` and in `lib/app/router/` is **red** now, a
> planted one under `lib/features/` is still red, and the clean tree is still
> **green** — with the dock still counting as **one** site, because the count
> is of sites and widening the walk did not change that.
>
> **The orphan gate's root set learned `@RoutePage()`.** Its root set was
> "files under `/presentation/pages/`", which is a *proxy* for "is a page", and
> the shell is a page that is deliberately **not** under one — it belongs to
> the composition root. The gate now takes a file as a root when it **declares**
> `@RoutePage()`, matched against the **comment-stripped** text, so a doc
> comment that merely mentions the annotation does not make a file a root.
>
> **AND THE PROOF THAT WAS RECORDED HERE WAS THE FOOL, PRESENTED AS THE
> EVIDENCE.** It read: "Both halves were proved in a scratch copy: a file that
> only *mentions* the annotation leaves its widget an **orphan** (exit 1), and
> the same file with a real annotation places it (exit 0)." The first half was
> true — the comment-stripping half of the clause worked, and still does. The
> second half was **false**, and false in the direction that matters: a file
> that mentions the annotation in a **doc comment** is not a root, but a file
> that carries a **real annotation on a plain class** **was** a root, because
> nothing checked that the annotation was on a widget at all, and nothing
> checked that the route it declared was registered anywhere. Measured: a plain
> class with `@RoutePage()` on it, mentioning a widget, made the gate exit
> **0** with that widget on **no screen at all**.
>
> **So the clause is now two mechanical halves.** A file is a root only when it
> declares `@RoutePage()` **on a class that extends `StatelessWidget` or
> `StatefulWidget`**, **and** the route that declaration generates is
> **registered in `lib/app/router/app_router.dart`'s route table** — the
> generated route class's name appears there as `page: <Name>Route.page`. The
> path heuristic is gone: the root set is *derived* rather than guessed, and it
> is the **same eight files** the proxy found, so the report did not change.
> The difference is that a page which stops being registered now stops being a
> root, which is the correct answer and the old proxy could not give it.
>
> **Proved in a scratch copy, in both directions, and this time the fool is
> red.** A plain class carrying the annotation is **red** (exit 1 — the widget
> it named is an orphan again, and the gate says which class and why); the
> annotation only in a doc comment is still **red**; a **real** page — the
> annotation on a widget the router registers — is **green** and places its
> widget; and the same real page with its route **removed from the router** is
> **red**, which is what makes the second half load-bearing rather than
> decorative.

> ### THE FINDING: **ONE OBSERVER, NOT ONE PER NAVIGATOR** — and it killed
> recorded decision 41 in silence.
>
> `AppRouter.config()`'s `navigatorObservers` is a **builder**, and auto_route
> calls it **more than once**: the root `Navigator` asks for its observers, and
> the dock shell's `AutoTabsRouter` asks for the list it **inherits**. The
> builder that used to answer `AutoRouteObserver()` built a **new observer each
> time**, so the observer watching the root navigator was **not** the observer
> the pages inside the shell subscribed to.
>
> **And a tab is never popped, so the pages' own route data would not have
> helped either** — the home and the journey had to move to the **shell's**
> route data (the shell is the route that is popped), which is the right
> mechanism, and it still did not fire, because the **instance** was wrong.
>
> Two independent suites found it, each with the same measurement and each
> leaving the test **red on purpose** rather than weakening the assertion:
> `home_navigation_test.dart` (the home's re-read, decision 41) and
> `journey_reentry_test.dart` (the journey's). The fix is **one line** — the
> observer is one object, built once, and every call to the builder hands back
> that object.
>
> **The lesson is decision 41's own, one level up.** Decision 41 fixed a
> trigger that was **not wired**; this phase wired it and broke it again with a
> different kind of not-wired. Nothing was red for the two phases the re-read
> was broken, because the test that proves it had been rewritten to assert the
> trigger's *presence* rather than its *effect*.

---

# Phase 7 — Ritual, locale, close

- [ ] **Step 1: Port ~90 `I18N` keys** (`eva/redesign.html:924-977`) into
  `lib/l10n/app_*.arb`, including the Arabic-Indic digit transform at `:981`.
- [ ] **Step 2: `flutter gen-l10n`, then hand-format.** Raw output is **not**
  `dart format`-clean and the three committed files are hand-formatted.
  Re-running the generator re-breaks gate 1.
- [ ] **Step 3: Ritual.** Selah timer · focus mode (idle → dim) · vespers
  auto-dim (21:00–05:00) · breath guide · haptics via `HapticFeedback`
  (`services` — no new dependency).
- [ ] **Step 4: Reduce motion.** The prototype's `.rm` class kills 11 selectors
  at once (`:48-54`). The Flutter equivalent is `NeuralMotionScope` +
  `EvaAnimate` + a shader clock frozen at `t = 0`.
- [ ] **Step 5: Re-run every gate**, including the two `python3` checks:

```bash
tool/verify_all.sh --with-build
```

- [ ] **Step 6: Compare against the Phase 0 baseline.** Test count and coverage
  must not drop. If they do, `--update-baseline` is a deliberate reviewed
  decision with the diff explained — never a way to turn a red run green.

---

## Risks

| Risk | Evidence | Mitigation |
| --- | --- | --- |
| Shader too slow at 4K | shafts **5.04 ns/px** vs 2.98 | shape 3 disabled above ~2 Mpx; `NeuralTier.low` → static fallback |
| `u_time` posterisation | measured onset **≈10 h**, not 1 h; 161 distinct values at ≈100 h | **accepted, no code.** Task 1.4 cut. Same as the prototype. A regression test asserts the clock is unwrapped so the decision stays visible. |
| 240 goldens churn | palette + shader invalidate all of them | Task 1.3's injectable clock keeps them byte-stable |
| Citations rot silently | `citation_check.py` checks **existence and range only** — *not* that line NNN says what the comment claims | per-widget re-pointing; plant a violation in every harness |
| Fabricated data reads as real | no medals / profile / cheer endpoints | the ADR-0022 fiction table; stub ports swappable later |
| `orphan_widget_check.py` has an **empty** allowlist | every new widget must be reachable | place it or delete it — never allowlist |
| Uniform slot layout silently moves on an engine bump | it is compiler output, ordered by SPIR-V location, not by hand | generate from `--reflection-json`; gate fails on change and names the commit |
| `flutter test` ≠ Impeller | tests run Skia software (`flutter_tester_device.dart:113`) | **measured equivalent** for `FlutterFragCoord` — but re-check whenever the capture harness is touched |
| `verify_purity.sh` Gate 1 does **not** scan `lib/core/design_system/` | it covers only `core/domain`, `core/common`, `core/navigation`, `features/*/domain` (`tool/verify_purity.sh:178`) | `lumen_uniforms.dart`'s Flutter-freedom is by construction (`dart:math` only) and review, **not** by instrument. Extending Gate 1 to the design system is a separate change. |
| `getUniformFloat(name).index` reads 0 for every uniform | `.index` is the *component* offset (0 for `.x`), not the shader index (`painting.dart`: `UniformFloatSlot.index` — "1 for `.y`, 2 for `.b`") | use the `VisibleForTesting` **`shaderIndex`** for layout assertions in tests; never `.index`. A doc comment shipped this misread once — verified by probe, all 16 uniforms read 0 while `u_nope` throws and `u_res[2]` throws "less than 2". |

## Suggested issue split

`gh` is authenticated, the repo has **no open issues**, and this is far too
large for one pull request. Branch per phase, matching the commit scope.

1. `chore(ci)` — restore `eva/`, unblock the citation gate — **Phase 0.1**
2. `docs(adr)` — 0022 supersedes 0001 — **Phase 0.2**
3. `feat(effects)` — the Lumen shader and its 14 controls — **Phase 1**
4. `feat(design)` — the redesign palette, four measured light repairs — **Phase 2**
5. `feat(sky)` — the witness sky and its persistence — **Phase 3**
6. `feat(design)` — restyle the 23 design-system widgets — **Phase 4**
7. `feat(home)` — library, selah, verse-of-the-day, last-light — **Phase 5.1–5.4**
8. `feat(communion)` — podium, you-card, veil, cheer — **Phase 5.5**
9. `feat(journey)` — the profile screen §2 decision 1 cut — **Phase 5.6**
10. `feat(settings)` — the Workshop's 28 controls — **Phase 5.7**
11. `feat(nav)` — the `AutoTabsRouter` dock — **Phase 6**
12. `feat(ritual)` — selah, focus, vespers, the Arabic port — **Phase 7**

---

## Self-review

**Spec coverage.** Every screen of `eva/redesign.html` maps to a task:
login 5.1, home 5.2, reader 5.3, quiz 5.4, journey 5.6, communion 5.5,
workshop 5.7, dock Phase 6, result-modal 6.2. Every shader uniform maps to
Task 1.2; every Workshop control maps to Task 5.7; the starfield maps to
Phase 3. The two *excluded* items (share, notes) are named and justified at the
top rather than silently dropped.

**Placeholder scan.** No `TBD`, no "add appropriate error handling", no "similar
to Task N". Where a measurement replaces a literal — the oracle frame, the
citation line numbers, the uniform slots — the plan says to derive it rather
than invent it, and says how.

**Type consistency.** `LumenUniforms` field names match the `.frag` uniform
names throughout; `UniformSlot` ordering matches the decoded reflection layout;
`SkyEntry` is named identically in the entity, the port, the data source, the
repository and the cubit.

**Known gaps, stated rather than hidden.** Task 5.6's rings and Task 5.5's
"≈ N verses to pass" need a derivation the backend does not provide (15 light
per verse is a prototype constant at `eva/redesign.html:755`). Each gets its own
red-first test as a pure function, and the constant is cited rather than
smuggled in.
