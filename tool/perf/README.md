# `tool/perf/` — the on-device frame-timing instrument

A runbook for the instrument `docs/PERFORMANCE.md` §3.4 names and says **does
not exist yet** (that section is being annotated in parallel by the lane that
owns `docs/`; the body text still reads "**It is not built yet**"):

> "The on-device measurement, which does not exist yet … the instrument is
> `SchedulerBinding.instance.addTimingsCallback`, which reports `buildDuration`,
> `rasterDuration` and `totalSpan` per frame and works in release and profile …
> **It is not built yet.**"

It is built. It is two files and it is **opt-in**:

| file | what it is | what it imports |
| --- | --- | --- |
| `lib/core/diagnostics/frame_stats.dart` | the statistics — `p50`, `p95`, `worst`, `mean`, `count`, and a one-line summary | **nothing.** Pure Dart — no `package:flutter`, no `dart:ui`. |
| `lib/core/diagnostics/frame_timing_recorder.dart` | the engine adapter — subscribes to the frame channel, converts, summarises | `package:flutter/scheduler.dart` (the engine's `FrameTiming` and `SchedulerBinding`), `package:flutter/foundation.dart` (`debugPrint`), and the statistics above |

The split is not tidiness. `FrameTiming` is a `dart:ui` type, so anything that
speaks in it is a Flutter file — and a statistics type that can only be built
by the engine has nothing a unit test can hand it. The pure half takes plain
`int` microseconds and is unit-tested directly.

The wiring is one line in the composition root (`lib/app/app.dart`), behind a
compile-time flag, so a normal build does not have the instrument at all.

---

## 1. What it measures — and what it does not

### 1.1 What it measures

For every frame the engine rasterises, two numbers, in microseconds:

| series | the engine's field | whose thread |
| --- | --- | --- |
| `build` | `FrameTiming.buildDuration` | the **UI thread** — deciding what the frame looks like |
| `raster` | `FrameTiming.rasterDuration` | the **raster thread** — turning that into pixels |

and, over the whole session, the **median** (`p50`), the **95th percentile**
(`p95`), the **worst** single frame, and the **mean**.

The percentiles are **nearest-rank** — the `p95` is a sample that was actually
measured, not an interpolation between two. The reasoning is in
`frame_stats.dart`'s own doc comment; the short version is that a frame budget
is a question about the slowest five percent of frames, and an interpolated
percentile answers it with a number no frame produced.

**And `package:flutter_test`'s own `FrameTimingSummarizer` uses a different
rule** — the sample at `data[((data.length - 1) * p).round()]`, a rounded
linear index. The two agree for twenty samples and disagree for twelve, so a
number from here and a number from `flutter_test` are not the same statistic.
The rule here is recorded in `frame_stats.dart` rather than matched, because a
reader comparing the two must be able to find the difference.

### 1.2 What it does **not** measure

* **Not a device number.** A `flutter test` micro-benchmark runs a **software
  rasteriser** on a **fake clock**. Every wall-clock figure this repository
  prints from a test is an **upper bound and a relative figure**, never a
  device number — `docs/PERFORMANCE.md`'s header says so, and
  `witness_sky.dart:853-857` says so of the numbers before it. This
  instrument does not change that: a number from a `flutter test` run of this
  instrument is an upper bound, and a number from a **profile build** is a real
  measurement of *that machine*.
* **Not the aurora's GPU cost.** `rasterDuration` is how long the raster
  thread took. The aurora is a full-screen fragment shader, and its cost is
  a **fragment count** question — `docs/PERFORMANCE.md` §3.1 — which this
  instrument does not and cannot answer. §3.1's pixel budget is still
  arithmetic; this instrument is the first *measurement* of the other half.
* **Not the reader's perceived latency.** `FrameTiming.totalSpan` is
  deliberately **not collected**: it runs from the vsync signal to the end of
  raster, so it is dominated by the **vsync wait**, and a number that includes
  a wait is a number about the display's refresh rate as much as about the app.
* **Not the tree's rebuild count.** That is a different instrument, and it
  already exists: `test/rebuild_isolation_budget_test.dart`, wired into
  `docs/PERFORMANCE.md` §1.
* **Not present at all in a normal build.** See §2.

---

## 2. How to run it

```bash
flutter run -d linux --profile --dart-define=PERF_TRACE=true
```

`--profile` matters. The engine batches the timings roughly **once every
100 ms** in debug and profile and roughly **once a second** in release, and
the debug build's own overhead makes its numbers meaningless. **Profile mode
is the mode the numbers are for**; release mode is the mode a shipped app
would use, and it is the right mode for a **release** build of this app.

If the app aborts on launch with

```text
GLib-GIO-ERROR … 'xsettings' does not contain a key named 'antialiasing'
```

that is the environment, not the app — see `AGENTS.md`. The fix is:

```bash
GSETTINGS_SCHEMA_DIR=/usr/share/glib-2.0/schemas \
  flutter run -d linux --profile --dart-define=PERF_TRACE=true
```

### 2.1 What it prints

One line per engine batch, on stdout, in this exact shape:

```text
build count=47 p50=0.6ms p95=0.8ms worst=3.7ms mean=0.7ms | raster count=47 p50=1.2ms p95=2.3ms worst=46.4ms mean=2.2ms
```

* `build` / `raster` — the two series.
* `count` — frames sampled so far. **Cumulative**, so every line is the whole
  session up to that point.
* `p50` / `p95` / `worst` / `mean` — milliseconds, one decimal.
* the ` | ` — the separator between the two series.

### 2.2 The cadence, and how to read it

**Measured on this machine, 2026-10-22, profile mode, Linux desktop:**

```bash
# with the app running and the instrument on:
grep -c "^build count=" perf.log   # …ten seconds later…
```

**86 lines in ten seconds** — about **8.6 batches a second**, each carrying
about **7 frames** (≈60 fps at 60 Hz). So in profile mode the summary prints
**about nine times a second**, and in release mode about once a second.

**The last line is the whole session.** The statistics are cumulative, so
`tail -1` is the session's summary:

```bash
flutter run -d linux --profile --dart-define=PERF_TRACE=true 2>&1 | tee perf.log
# …interact with the app…
tail -1 perf.log
```

Every line is a complete running summary, so any line in the file is the
state of the app at that moment — which is what makes the instrument useful
*while* you interact: watch `p95` and `worst` move as you drag a slider.

### 2.3 A normal build prints **nothing**

**Measured.** The same profile build without the flag:

```bash
flutter run -d linux --profile 2>&1 | tee normal.log
grep -c "^build count=" normal.log
# 0
```

The flag is `const bool.fromEnvironment('PERF_TRACE')`, so it is a
**compile-time constant**: in a build without it the branch in
`lib/app/app.dart` that constructs the recorder is folded away by the
compiler, the recorder is never constructed, and the engine's frame channel
is never subscribed to. **The instrument costs nothing when it is off.**

### 2.4 The instrument's own tests

```bash
flutter test test/core/diagnostics/
# 00:00 +25: All tests passed!
```

25 tests: 14 for the statistics, 11 for the recorder. They cover **both**
arms of the `enabled` flag, and the recorder's test drives the **engine's own
channel** (`PlatformDispatcher.instance.onReportTimings`) rather than calling
the recorder's method directly — so the registration is tested, not just the
conversion.

> **A note on `FrameTiming`.** The brief this lane was given said
> `FrameTiming` "is not constructible from Dart — there is no public
> constructor". **That is not true in Flutter 3.47.4.** The class has a
> public factory constructor, documented as "used for unit test only"
> (`sky_engine/lib/ui/platform_dispatcher.dart:2172`). That is what makes the
> engine channel reachable from a test at all. The statistics do not depend on
> it either way.

---

## 3. The DTD / VM-service route — the engine's own frame timeline

`addTimingsCallback` gives the **Dart-side** view of a frame. The **engine**
also keeps its own timeline, which is the raw material DevTools draws. This
route reads it directly, and it is the route to take when you want to see
*which* part of the frame was expensive rather than only how long it took.

### 3.1 Connect, through the Dart Tooling Daemon

The DTD is the daemon `flutter run` starts. Its WebSocket URI **changes on
every launch**, so it must be looked up, not remembered.

```bash
# 1. find the daemon for THIS workspace
dtd listDtdUris
```

```text
Found 2 Dart Tooling Daemon instance(s):
  WS URI:         ws://127.0.0.1:39767/t6oFKZMc-lM=
  Workspace Root: /home/fady/Projects/evangelion
  Dart Version:   3.13.3 (stable) (Tue Sep 1 07:07:17 2026) on "linux_x64"
  PID:            770106
  Started:        less than a minute ago

  WS URI:         ws://127.0.0.1:33795/nGYLro9mDaE=
  Workspace Root: /home/fady
  IDE:            Visual Studio Code
  …
```

**Pick the one whose `Workspace Root` is this repository.** The other one is
the editor's.

```bash
# 2. connect to it
dtd connect uri=ws://127.0.0.1:39767/t6oFKZMc-lM=
```

```text
Connection succeeded to ws://127.0.0.1:39767/t6oFKZMc-lM=. Connected apps:
- name: Kind: Flutter - Device: Linux - Package: evangelion
  uri: ws://127.0.0.1:42539/IYbuPe_4itk=/ws
```

```bash
# 3. and list what is attached
dtd listConnectedApps
```

```json
{
  "ws://127.0.0.1:39767/t6oFKZMc-lM=": [
    {
      "uri": "ws://127.0.0.1:42539/IYbuPe_4itk=/ws",
      "name": "Kind: Flutter - Device: Linux - Package: evangelion"
    }
  ]
}
```

That `uri` is the **VM-service URI** of the running app, and it is what the
next step wants.

### 3.2 Turn the timeline on, and read it

```bash
vm_service connect appUri=ws://127.0.0.1:42539/IYbuPe_4itk=/ws
```

**What is already recorded** — ask first, so you know what you are changing:

```bash
vm_service callMethod appUri=… method=getVMTimelineFlags
```

```json
{
  "type": "TimelineFlags",
  "recorderName": "Ring",
  "availableStreams": ["API", "Compiler", "CompilerVerbose", "Dart", "Debugger",
                       "Embedder", "GC", "Isolate", "Microtask", "VM"],
  "recordedStreams": ["Dart", "Embedder", "GC", "Microtask"]
}
```

**The `Frame` and `Rasterizer` streams are NOT VM streams.** Asking for them
is an error, and the error is the useful part:

```bash
vm_service callMethod appUri=… method=setVMTimelineFlags \
  arguments={"recordedStreams":["Frame","Rasterizer"]}
```

```text
RPCError when invoking method setVMTimelineFlags: setVMTimelineFlags:
(-32602) Invalid params
setVMTimelineFlags: invalid 'recordedStreams' parameter: [Frame, Rasterizer]
```

`Frame` and `Rasterizer` are **engine** timeline categories, and they arrive
under `Embedder` — which is already on. The working call is:

```bash
vm_service callMethod appUri=… method=setVMTimelineFlags \
  arguments={"recordedStreams":["Dart","Embedder","GC","Microtask","API","Isolate","VM"]}
```

```json
{ "type": "Success" }
```

Then read it:

```bash
vm_service callMethod appUri=… method=getVMTimeline
```

```json
{
  "type": "Timeline",
  "traceEvents": [ … ],
  "timeOriginMicros": 59644948341,
  "timeExtentMicros": 3594601
}
```

**Measured on this machine, 2026-10-22: 32,676 trace events over a 3.59-second
extent**, and the frame-related names in it are:

| name | what it marks |
| --- | --- |
| `Rasterizer::DoDraw` | the raster thread drawing a frame. **Its `args` carry `frame_number`** — `"2698"` and so on. |
| `LayerTree::Paint` | the UI thread painting the layer tree. A `B`/`E` pair, so `ts` on the `E` minus `ts` on the `B` is the duration. |
| `CompositorContext::ScopedFrame::Raster` | the frame's raster scope |
| `GPURasterizer::Draw` | the GPU-side draw |
| `SurfaceFrame::Submit` | the frame handed to the surface |
| `Canvas::saveLayer` | a save-layer — the aurora's `ColorFiltered` costs one of these per frame |
| `PlatformVsync`, `AsyncWaitForVsync` | the display's signal, and the wait for it |

A worked example, as the VM service returned it:

```json
{ "name": "Rasterizer::DoDraw", "cat": "Embedder", "ph": "B",
  "ts": 60376987322, "args": { "frame_number": "2698" } }
```

### 3.3 A paste-able shell route for the same thing

The `dtd`, `vm_service`, `widget_inspector` and `flutter_driver_command` steps
below are **Dart-MCP-server tools**, not shell commands. The VM service itself
is a **WebSocket** JSON-RPC endpoint — an HTTP `POST` to it is answered
`method not allowed` (measured) — so a shell client needs a WebSocket. This
one is enough, and it needs `python3` with the `websockets` module:

```bash
python3 - <<'PY'
import asyncio, json, sys, websockets
URI = "ws://127.0.0.1:33493/xKcQeL_uiRQ=/ws"   # ← from `flutter run`'s output
async def main():
    # **max_size=None**: the timeline reply is megabytes, and websockets
    # refuses a frame over 1 MB by default ("message too big").
    async with websockets.connect(URI, max_size=None) as ws:
        await ws.send(json.dumps({"jsonrpc": "2.0", "id": "1",
                                  "method": "getVMTimelineFlags", "params": {}}))
        print(json.dumps(json.loads(await ws.recv())["result"], indent=2))
asyncio.run(main())
PY
```

```text
{
  "type": "TimelineFlags",
  "recorderName": "Ring",
  "availableStreams": [ "API", "Compiler", "CompilerVerbose", "Dart", "Debugger",
                        "Embedder", "GC", "Isolate", "Microtask", "VM" ],
  "recordedStreams": [ "Dart", "Embedder", "GC", "Microtask" ]
}
```

Swap `getVMTimelineFlags` for `getVMTimeline`, `setVMTimelineFlags` or
`getVM` and it is the same endpoint.

**And you do not need the DTD at all if you read the terminal.**
`flutter run` prints the app's VM-service URI itself:

```text
A Dart VM Service on Linux is available at: http://127.0.0.1:33493/xKcQeL_uiRQ=/
```

That `http://…` form is the same endpoint with the WebSocket scheme; the
WebSocket form is `ws://…/ws`. **The DTD route exists because it finds that
URI for you** — and because the MCP server wants a DTD connection before it
will talk to a VM service at all.

### 3.4 `flutter_driver_command` — **not available in this app, and why**

```bash
flutter_driver_command appUri=… command=set_frame_sync enabled=true
flutter_driver_command appUri=… command=get_health
```

**Both** answer the same thing, and it was measured on a live profile build:

```text
Error: The flutter driver extension is not enabled. You need to import
"package:flutter_driver/driver_extension.dart" and then add a call to
`enableFlutterDriverExtension();` before calling `runApp` to use this tool. It
is recommended that you create a separate entrypoint file like `driver_main.dart`
to do this.
```

**This is a property of the app, not of the tool.** The Flutter Driver
extension is opt-in per app: the app has to call `enableFlutterDriverExtension()`
before `runApp`, normally from a separate `driver_main.dart` entrypoint. **This
app has no such entrypoint**, so the driver channel is not there and
`set_frame_sync` — which is what would give deterministic, frame-synced
interaction for a measurement — cannot be used against the shipping app.

Adding one is **outside this lane's scope** (it is a new entrypoint, a new
file, and a change to `main.dart`), so it is recorded here as the known gap
rather than quietly worked around. If a deterministic frame-synced measurement
is wanted, that entrypoint is the next piece of work, and this runbook's §3.2
route is what to use until then.

### 3.5 The widget inspector

```bash
widget_inspector command=get_widget_tree
```

reads the live tree of the running app, which is the tool for answering
"what is actually on screen right now" while a measurement is running.

---

## 4. The honest caveat — **a desktop raster is not a phone's pipeline**

**This is the part that gets quoted out of context, so it is stated plainly.**
A number from this instrument on **Linux desktop** is a number about:

* a **software or GL rasteriser** on an x86 desktop GPU,
* a **desktop refresh rate** (60 Hz here, and the display's, not a phone's),
* a **desktop-sized surface**, and
* a **desktop's memory bandwidth and driver**.

A phone runs a **tile-based GPU**, a **different shader compiler**, a
**different surface format**, and a **different display cadence** (90 Hz, 120
Hz). The aurora — a full-screen fragment shader at device resolution — is
**not** the same cost on either.

So:

* **Desktop numbers are directional.** "The aurora's raster cost went **up**
  when I added the shafts shape" is a real, usable claim on desktop.
* **Desktop numbers are not budgets.** "16.7 ms is the frame budget" is a
  claim about a **60 Hz** display; on a 120 Hz phone the budget is 8.3 ms,
  and on this desktop the display may not be 60 Hz at all.
* **`docs/PERFORMANCE.md` §3.1's table is still arithmetic.** It is computed
  from the repository's own recorded `ns/px` figures and a phone's pixel
  count. This instrument is the first *measurement* of the other half of the
  question, and it is a measurement of a **different machine**.

The only way to turn a directional number into a device number is to run the
instrument **on the device**, with the same `--dart-define=PERF_TRACE=true`,
in a profile build.

---

## 5. Reproducing every command in this file

Every command, in the order it is used, with what it prints. The `dtd`,
`vm_service`, `widget_inspector` and `flutter_driver_command` steps are
**Dart-MCP-server tools**, not shell commands; §3.3 has a **paste-able shell
equivalent** for the VM service, and the DTD's own job — finding the app's
VM-service URI — is also done by reading `flutter run`'s output.

```bash
# 0. the app, with the instrument on, in profile mode
cd /home/fady/Projects/evangelion
flutter run -d linux --profile --dart-define=PERF_TRACE=true 2>&1 | tee perf.log
# → one line per engine batch:
#   build count=47 p50=0.6ms p95=0.8ms worst=3.7ms mean=0.7ms | raster count=47 p50=1.2ms p95=2.3ms worst=46.4ms mean=2.2ms

# 0a. the session's summary
tail -1 perf.log

# 0b. that a normal build says nothing at all
flutter run -d linux --profile 2>&1 | tee normal.log
grep -c "^build count=" normal.log
# → 0

# 1. the instrument's own tests
flutter test test/core/diagnostics/
# → 00:00 +25: All tests passed!

# 2. the daemon
dtd listDtdUris
# → "Found 2 Dart Tooling Daemon instance(s): WS URI: ws://127.0.0.1:<port>/<token>  Workspace Root: /home/fady/Projects/evangelion …"

dtd connect uri=ws://127.0.0.1:<port>/<token>
# → "Connection succeeded to ws://… Connected apps: - name: Kind: Flutter - Device: Linux - Package: evangelion  uri: ws://127.0.0.1:<port>/<token>"

dtd listConnectedApps
# → { "ws://…": [ { "uri": "ws://127.0.0.1:<port>/<token>", "name": "Kind: Flutter - Device: Linux - Package: evangelion" } ] }

# 3. the engine timeline
vm_service connect appUri=ws://127.0.0.1:<port>/<token>
vm_service callMethod appUri=… method=getVMTimelineFlags
# → { "type": "TimelineFlags", "recorderName": "Ring", "availableStreams": […], "recordedStreams": ["Dart","Embedder","GC","Microtask"] }

vm_service callMethod appUri=… method=setVMTimelineFlags \
  arguments={"recordedStreams":["Frame","Rasterizer"]}
# → RPCError … invalid 'recordedStreams' parameter: [Frame, Rasterizer]     (they are ENGINE streams, not VM streams)

vm_service callMethod appUri=… method=setVMTimelineFlags \
  arguments={"recordedStreams":["Dart","Embedder","GC","Microtask","API","Isolate","VM"]}
# → { "type": "Success" }

vm_service callMethod appUri=… method=getVMTimeline
# → { "type": "Timeline", "traceEvents": [ … ], "timeOriginMicros": …, "timeExtentMicros": … }

# 4. the driver channel — measured, and NOT available here
flutter_driver_command appUri=… command=set_frame_sync enabled=true
flutter_driver_command appUri=… command=get_health
# → "Error: The flutter driver extension is not enabled. …"

# 5. the same VM-service calls from a shell (§3.3)
python3 - <<'PY'
import asyncio, json, websockets
URI = "ws://127.0.0.1:<port>/<token>/ws"
async def main():
    async with websockets.connect(URI, max_size=None) as ws:
        await ws.send(json.dumps({"jsonrpc": "2.0", "id": "1",
                                  "method": "getVMTimelineFlags", "params": {}}))
        print(json.dumps(json.loads(await ws.recv())["result"], indent=2))
asyncio.run(main())
PY
# → { "type": "TimelineFlags", "recorderName": "Ring", "availableStreams": […], "recordedStreams": ["Dart","Embedder","GC","Microtask"] }
```

---

## 6. What a **better** result looks like

The instrument reports a number. A number is only worth something next to
another number measured the **same way**. The protocol:

1. **Same scene.** The same screen, the same state, the same data. A reading
   taken on `/` is not comparable with one taken on `/reading`.
2. **Same number of frames.** The `count` field says how many frames were
   sampled, and a five-second reading is not comparable with a five-minute
   one — the `mean` moves as the session ages, and the `p95` moves with it.
   Compare readings of **similar length**, or compare `p95` and `worst`, which
   are far more stable than the mean.
3. **Same machine, same build flags, same mode.** `--profile` against
   `--profile`. A profile number against a debug number is not a comparison.
4. **Repeat it.** Run it **at least three times** and compare the **worst** of
   the three, not the best. A single reading of a shared machine is a
   measurement of the machine as much as of the app.
5. **The thing that moved must be named.** "p95 went from 1.4 ms to 2.1 ms"
   is a result. "It feels smoother" is not.

**What "better" means, in the order the fields should be read:**

| read | for | because |
| --- | --- | --- |
| `p95` | **whether the frame budget was met** | the tail is what a reader notices; the median hides it |
| `worst` | **whether there is a pathological frame** | one 46 ms frame is a stutter even if the median is 1 ms |
| `mean` | **whether the work got cheaper overall** | the most stable number and the least interesting |
| `p50` | **whether the typical frame moved** | useful only when the typical frame *is* the problem |

**And the comparison that matters is a comparison, not a threshold.** There is
no absolute budget in this file, because there is no device budget in this
file (§4). "The `raster` `p95` rose from 1.5 ms to 2.3 ms when the shafts
shape was selected" is a complete, useful, honest claim. "2.3 ms is too slow"
is not, on this machine.

---

## 7. Where the numbers come from, and where they do not

| the number | its home | what it is |
| --- | --- | --- |
| the frame statistics | this instrument, `lib/core/diagnostics/` | a **measurement**, on the machine that produced it |
| the widget-rebuild counts | `test/rebuild_isolation_budget_test.dart` | an **exact count**, and a **budget that fails the build** |
| the aurora's per-pixel cost | `docs/PERFORMANCE.md` §3.1, from the figures recorded in `lumen_tier.dart` | **arithmetic** from recorded `ns/px` figures and a phone's pixel count — explicitly *not* a measurement |
| the shader's correctness | `test/support/lumen_cpu_mirror.dart` | a **second, independent Dart implementation** of the shader's maths, used as a **correctness oracle** — not a timing measurement at all |

`docs/PERFORMANCE.md` §3.4's "**It is not built yet**" is now **stale**: this
instrument is it. That document has a dedicated owner and was not edited
here.
