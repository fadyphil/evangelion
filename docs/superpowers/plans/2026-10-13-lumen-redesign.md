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
| 24 float slots, no `vec3` padding — **but NOT in declaration order** | Decoded with the SDK's own `impellerc --reflection-json` and from the GLSL Impeller itself emits into the `.iplr`. Impeller **re-sorts** uniforms by SPIR-V `DecorationLocation` (`impeller/compiler/uniform_sorter.cc`), so source declaration order is wrong. See Task 1.2. |
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
| 2 | Slot table = source declaration order | **reflected** order, generated not hand-written | Impeller re-sorts by SPIR-V location; every index in the old table was wrong |
| 3 | `Picture.toImage` capture, bare | wrapped in **`tester.runAsync()`** + explicit `dispose()` | Bare capture deadlocks the full 10-min timeout, with or without a shader |
| 4 | Two-`dirname` `impellerc` path | **three** `dirname`s | The two-`dirname` path does not exist |
| 5 | Tech Stack: "GLSL ES → SkSL" | explicit that you author **GLSL ES** | `impellerc` accepts only `glsl\|hlsl`; SkSL is the IR the build emits |

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
FL=$(dirname $(dirname $(dirname $(readlink -f $(which flutter)))))/cache/artifacts/engine/linux-x64
ls -la "$FL/impellerc"   # fail loudly if the path is wrong
"$FL/impellerc" --sksl --runtime-stage-gles --runtime-stage-gles3 \
  --runtime-stage-vulkan --iplr --sl=/tmp/opencode/lumen.iplr \
  --spirv=/tmp/opencode/lumen.iplr.spirv \
  --input=shaders/lumen.frag --input-type=frag \
  --include=shaders --include="$FL/shader_lib"
echo "exit=$?"
```

Expected: **exit 0 and no output at all.** Zero errors, zero warnings.

> **Three `dirname`s, not two.** `readlink -f $(which flutter)` →
> `<sdk>/bin/flutter`; two `dirname`s stop at `<sdk>`, which has no `cache/`.
> The artifacts live at `<sdk>/bin/cache/artifacts/engine/linux-x64`. Verified:
> the two-`dirname` form yields `…/flutter/cache/artifacts/engine/linux-x64`,
> which does not exist.

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
load-bearing — but it is **not** source declaration order (see Step 3). The test
must pin the *reflected* layout, which is what the engine actually uses.

```dart
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LumenUniforms slot order', () {
    test('matches the reflected layout with no vec3 padding', () {
      const u = LumenUniforms.identity();
      expect(u.slot(UniformSlot.uShape), 3);
      expect(u.slot(UniformSlot.uSpread), 4);
      expect(u.slot(UniformSlot.uStr), 5);
      expect(u.slot(UniformSlot.uPtrX), 6);
      expect(u.slot(UniformSlot.uPtrY), 7);
      expect(u.slot(UniformSlot.uPtrI), 8);
      expect(u.slot(UniformSlot.uInt), 9);
      expect(u.slot(UniformSlot.uSpike), 10);
      expect(u.slot(UniformSlot.uHueX), 11);
      expect(u.slot(UniformSlot.uHueY), 12);
      expect(u.slot(UniformSlot.uHueZ), 13);
      expect(u.slot(UniformSlot.uMelt), 14);
      expect(u.slot(UniformSlot.uHue2X), 15);
      expect(u.slot(UniformSlot.uHue2Y), 16);
      expect(u.slot(UniformSlot.uHue2Z), 17);
      expect(u.slot(UniformSlot.uHue3X), 18);
      expect(u.slot(UniformSlot.uHue3Y), 19);
      expect(u.slot(UniformSlot.uHue3Z), 20);
      expect(u.slot(UniformSlot.uWhite), 21);
      expect(u.slot(UniformSlot.uLight), 22);
      expect(u.slot(UniformSlot.uDots), 23);
    });
  });

  group('hslToRgb', () {
    test('matches the redesign prototype at h=258 s=90 l=66', () {
      final rgb = hslToRgb(258, 90, 66);
      expect(rgb.r, closeTo(0.545, 0.005));
      expect(rgb.g, closeTo(0.106, 0.005));
      expect(rgb.b, closeTo(0.831, 0.005));
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
what makes the shader source a faithful port. But the *Dart-side slot indices*
are **not** the declaration order, because Impeller re-sorts uniforms by SPIR-V
`DecorationLocation` (`impeller/compiler/uniform_sorter.cc`).

**`setFloat` indices come from this table, not from declaration order:**

| slot | uniform | slot | uniform | slot | uniform |
| --- | --- | --- | --- | --- | --- |
| 0–1 | `u_res` (vec2) | 8 | `u_ptrI` | 15–17 | `u_hue2` (vec3) |
| 2 | `u_time` | 9 | `u_int` | 18–20 | `u_hue3` (vec3) |
| 3 | `u_shape` | 10 | `u_spike` | 21 | `u_white` |
| 4 | `u_spread` | 11–13 | `u_hue` (vec3) | 22 | `u_light` |
| 5 | `u_str` | 14 | `u_melt` | 23 | `u_dots` |
| 6–7 | `u_ptr` (vec2) | | | | |

Total **24** floats, no `vec3` padding — `u_hue` occupies 11,12,13 contiguously.

Verified three ways, all agreeing: the SDK's `impellerc --reflection-json`; the
GLSL Impeller itself emits into the `.iplr` (`uniform highp vec2 u_res; uniform
highp float u_time; uniform highp float u_shape; …`); and three consecutive
compiles producing byte-identical order.

> **Do not hand-maintain this table.** It is compiler output, and it will move
> when the engine bumps. Generate `UniformSlot` from `--reflection-json` at
> build time and add a gate that fails when the reflected layout changes,
> pointing at the commit that changed it. The unit test below then asserts
> *stability*, which is the property that actually matters — not the constants.

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

---

# Phase 2 — Palette & tokens

## Task 2.1: Adopt dark verbatim

No changes. It passes AA everywhere and beats the current palette on every role.

## Task 2.2: Repair exactly four light values

| Token | Prototype | Measured | Repaired to | Rendered at |
| --- | --- | --- | --- | --- |
| `ink2` | `#707684` | 4.069 | `#666C7A` | 8–17px |
| gold ink | `#8a6d15` | 4.387 | `#806615` | `.mono b`, `.qnext`, 10–11px |
| gold | `#9A7B19` | 3.595 | `#8A6D15` | `.rail h4`, 10px |
| `.cta` label | `#FFFFFF` on `#9A7B19` | **4.022** | fill → `#8A6D15` (5.30) | 11px bold |

- [ ] **Step 1: Make the changes in `eva_colors.dart`**
- [ ] **Step 2: Cite each repair** — a comment with `redesign.html:NNN` **and**
  the measured ratio, so a reader sees exactly where and why the app parts ways
  with the prototype.
- [ ] **Step 3: Fix the focus affordance.** `redesign.html:177` sets
  `.screen.focus .vline.in` to `#d9dfef`, which destroys the focus signal —
  focused and unfocused verse differ by ~1.5:1. Not a contrast bug (17.98:1 vs
  canvas); an **affordance** bug.

## Task 2.3: Re-baseline the five token gates

- [ ] **Step 1: `eva_colors_test.dart`** — 34 byte-pinned hexes, the
  `expect(gaps.length, dark ? 0 : 7)` sub-AA count, and
  `closeTo(9.17 / 5.41, 0.05)` on the `onEmber` pairings. Recompute and assert
  the new count **explicitly**. Do **not** relax to `greaterThanOrEqualTo` —
  that assertion is what makes the inventory exhaustive.
- [ ] **Step 2: `text_contrast_gate_test.dart`** — `knownSubstandard` **must not
  grow**. With four repairs it should *shrink*. **If it grows, a repair was
  wrong.** The ledger's own words: *"add it deliberately, or fix the token."*
- [ ] **Step 3: Verify the gates that should be unaffected actually are:**
  `no_colour_literals_test` (new hexes go in `tokens/`, which is exempt),
  `glass_blur_budget_test` (purely structural), `font_coverage_test` (the
  redesign uses the **same five** families), `arabic_typography_gate`.

---

# Phase 3 — The witness sky

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

- [ ] **Step 1: Add `GlassTier.bloom`** — the `.bloom` radial wash (`--bh`
  per-card) and the `.hor` light seam. These are the redesign's signature and
  have no current equivalent.
- [ ] **Step 2: Add no new blur.** The budget is **1** `BackdropFilter` in
  `lib/features/`, already spent, and ADR-0020 §13 forbids `ImageFilter`.
  `.bloom` and `.hor` are gradients — verify
  `glass_blur_budget_test.dart` still passes.
- [ ] **Step 3: Restyle the 23 widgets** to the redesign's glass/gold/bloom
  language.
- [ ] **Step 4: Re-point citations per widget.** Move
  `eva/src/X.tsx:NNN` → `redesign.html:NNN` **only for widgets that actually
  changed**. A citation that still describes a surviving widget is not wrong;
  moving it would be churn.
- [ ] **Step 5: Re-point the 5 geometry harnesses** — only those whose screen
  changed — and **plant a violation in each** to prove it still fires. A harness
  that passes vacuously is worse than no harness.
- [ ] **Step 6: Export every new widget from `barrel.dart`** and run
  `orphan_widget_check.py`. Its allowlist is **empty** (`ALLOWLIST = {}`):
  place the widget, delete it, or allowlist it with a written reason.
  **Never suppress the failure.**
- [ ] **Step 7: Re-record goldens AFTER the citations are re-pointed.** Never
  the reverse — `CONTRIBUTING.md` names "re-recording goldens without
  re-checking the citations" a review failure.

---

# Phase 5 — Screens

| Task | Screen | Prototype | Source of its data |
| --- | --- | --- | --- |
| 5.1 | `/login` | `:503-511` | `FakeAuthRepository` (unchanged) |
| 5.2 | `/` | `:513-538` | streak real · VOTD real · last-light local · library hardcoded list |
| 5.3 | `/reading` | `:540-560` | real, + the sky from Phase 3 |
| 5.4 | `/quiz` | `:562-574` | real |
| 5.5 | `/communion` | `:612-636` | `GET /leaderboard?window=` |
| 5.6 | `/journey` | `:576-610` | streak real · rings derived · medals **stubbed** |
| 5.7 | `/settings` | `:638-700` | local · 28 new controls |

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

- [ ] **Step 6.1: `AutoTabsRouter`.** Home / Communion / Journey are real tabs;
  Read / Today are push actions. The dock hides on reader/quiz/workshop.
- [ ] **Step 6.2: `/result` stops being a route.** It becomes a modal
  (`:718-727`). `app_router_test.dart`'s assertion that `pushPath('/result')`
  **fails** (decision 81) **must be deleted, not weakened** — the invariant it
  pinned is gone because the route is gone.
- [ ] **Step 6.3: `AppRoutes.fallback` (`*`) stays last.** Moving it first turns
  **46 tests** red.
- [ ] **Step 6.4: Replace the single `fadeSlide`** with the redesign's
  `gone-left` / `gone-right` / tab-swap transitions via
  `RouteType.custom`.

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
