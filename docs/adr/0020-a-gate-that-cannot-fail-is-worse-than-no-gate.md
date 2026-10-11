# ADR-0020: Treat a gate that cannot fail as worse than no gate

- **Status:** accepted
- **Date decided:** 2026-10-07
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §7, "A gate that cannot fail is worse than no gate"; recorded decisions 142, 144

## Context

This repository has recorded three gates that reported a clean run over a surface
they never examined. One shipped **three false greens in a row** and, once it was
fixed, shipped an **unreachable assertion of its own** — the worst outcome available,
because a gate that cannot fail is indistinguishable from one that can.

## Decision

### The recorded incident

`flutter build linux --release` printed

```text
Building Linux application...
✓ Built build/linux/x64/release/bundle/evangelion
```

while `build/linux/x64/release/CMakeCache.txt` was dated **2026-10-04** and the
`libgtk-3-dev` package the toolchain needs was **not installed**. Every native output
was already present, so CMake was never asked to regenerate anything, nothing was
compiled, and the command reported success. Deleting the cache produced the real
answer in seconds:

```text
CMake Error at FindPkgConfig.cmake:1093:  - gtk+-3.0
```

**That false green was reported as a passing gate in three consecutive commit
messages**, after ten phases of "release build green" in the authority document.
`flutter doctor` — **absent from §7's gate list for ten phases** — had been saying
`✗ GTK 3.0 development libraries are required` the whole time. Every other line in §7
is about the code; that one is about the *machine*, and it was the only one that could
report a false green for reasons no amount of reading the diff would reveal.

**And once it was fixed, the replacement shipped an unreachable assertion.** The
timestamp check sat *after* the step that deleted `build/linux/x64/*` and rebuilt, so
the bundle was always fresh by the time it ran — proved by a mutation that "failed" to
fail: setting the bundle's mtime to 2020 and running the whole script returned
**PASSED**.

### Three causes, all mundane

- **A ripgrep pattern that fails to *compile* exits `0` with every line "passing."**
  The previous inline cross-feature check used a backreference,
  `rg -v "features/(\w+)/\1"`. Ripgrep has no backreferences, so the pattern failed to
  compile — exit `0`, every line passed, and the failure was silent.
- **A script that reads only stdout** turns a missing or broken `rg` into empty
  output, a hit count of `0`, and a cheerful
  `PASSED — all gates exercised and clean`. A broken toolchain was reported as a
  clean run.
- **A check that runs after the step it is meant to audit** can never observe the
  condition it names.

### Three outcomes, and the third is the point

| outcome | meaning | exit |
| --- | --- | --- |
| `ok` | the gate ran and passed | — |
| `FAIL` | the gate ran and found something | `1` |
| `FATAL` | the gate **could not run** | `2` |

A missing tool or an empty capture is `FATAL`, never a pass.
`tool/verify_all.sh` checks that `dart`, `flutter`, `rg` and `python3` are on `PATH`
**before running anything**, and proves `rg` works by matching a known string piped
in on stdin (`verify_all.sh`'s preflight; `verify_purity.sh:40-54` does the same
with its own probe). `FATAL` is not a flavour of `ok`: anything reading the exit code
alone cannot tell "nothing found" from "nothing looked".

### Two more mechanisms this bought

**The coverage floor is recorded, not observed.**
`flutter test --coverage` is documented as "must not drop"; without a recorded number
that is a wish, so `tool/baseline/gates.txt` holds it and gate 7 compares against
**the recorded floor, not the last run**. Two rules make that a gate rather than a
formality: it is changed **only** by `--update-baseline`, which prints the old and new
values so the change is visible in the commit diff; and **a gate that rewrites its own
expectation cannot fail**. Comparing against the last run would let one bad run
permanently lower the bar.

**`dart fix --dry-run` exits `0` even when it has work to do.** Measured, not assumed:
with a `deprecated_member_use` planted it printed "1 proposed fix in 1 file" and
returned `0`. So gate 5 greps for the literal `Nothing to fix!`, which was measured
to appear exactly once on a clean tree and not at all on a dirty one — **the output is
the check, not the exit code.**

## Alternatives considered

### Treat a missing tool as a failure rather than a fatal error

- **Why not:** `FAIL` reads as "the repository is wrong". A missing `rg` is a broken
  *machine*, and conflating the two teaches reviewers to ignore `FAIL`.

### Compare coverage against the previous run instead of a recorded floor

- **Why not:** one bad run permanently lowers the bar, and the lowering is invisible
  because the comparison would be against the failure.

## Consequences

### Better

- **Every gate in the repository is negative-controlled.** `tool/verify_gates_selftest.sh`
  runs each one against a scratch copy under `/tmp/opencode/gates-selftest` with
  exactly one violation planted, and the gate must exit non-zero. **A gate that cannot
  be made to fail is reported as such and the script exits non-zero**, because that is
  the finding rather than a passing run.
- **`tool/verify_linux_build.sh` gained `--check-only`** so step 4's negative control
  can mean anything. Running the full script is the real gate; `--check-only` skips
  the rebuild and is how you demonstrate the assertion *can* fail.

### Worse

- **One of the eight gates wipes `build/linux/x64/{debug,release}` before
  rebuilding**, so it is opt-in behind `--with-build` and runs last. It is the only
  gate that mutates the tree rather than reading it, and the slowest by an order of
  magnitude.
- **The rule costs real time on every gate change**: proving a fix means planting a
  violation and observing the non-zero exit before the change can be reported as
  fixed. That is the price, and it is the whole of the ADR.

### Neutral / noted

- **The rule found itself guilty once, in the script written to enforce it.**
  `verify_linux_build.sh`'s first version matched the doctor's status line with
  `^\[.\] Linux toolchain`. The glyph is `✓` — **three bytes of UTF-8** — so `.`
  matches one *byte* under the C locale and the pattern never matched. The script
  then reported `FAIL` on a perfectly healthy toolchain: the safe direction, but wrong
  for a reason invisible in the pattern. It now matches `Linux toolchain` and compares
  the glyph as an explicit `printf '\xe2\x9c\x93'` / `\xe2\x9c\x97'` byte pair.
- **Two more gates were added after §7, and they are two *instruments* rather than two
  more commands.** `citation_check.py` holds "every `X.tsx:NNN` claim resolves to a real
  prototype line"; `orphan_widget_check.py` holds "every widget is reachable from a
  page" — recorded decision 144's finding that `LeaderboardCard` was built, DI-wired,
  given a five-surface overflow matrix and a 21-test suite, **and no page instantiated
  it**, with every §7 gate green throughout.
- **`verify_linux_build.sh` currently reads `flutter doctor`'s output from
  `/tmp/eva_doctor.log` rather than running `flutter doctor` itself.** It fails closed
  when that file is absent (`toolchain_line` empty → `FAIL`), so it is not the
  zero-count pass of the two causes above — but a **stale** log would satisfy it.
  *Observed on 2026-10-11 and reported here rather than described as a working
  check.*

## Traceability

- `AGENT_CONTEXT.md` §7, "A gate that cannot fail is worse than no gate" (the three
  causes, the `FATAL` rule, and why the script does not use `set -e`)
- `AGENT_CONTEXT.md` recorded decision 142 (the incident, the unreachable assertion,
  the byte-vs-glyph bug), decision 144 (`LeaderboardCard`, and why reachability is its
  own gate)
- `tool/verify_all.sh` — the preflight, the three outcomes, gates 5 and 7
- `tool/verify_purity.sh:23,40-54` — `set -uo pipefail` and the `rg` probe
- `tool/verify_linux_build.sh` — the four steps, `--check-only`, the byte-pair glyph
  comparison at `:70-90`, the `/tmp/eva_doctor.log` dependency at `:70`
- `tool/verify_gates_selftest.sh` — the per-gate negative controls
- `tool/baseline/gates.txt` — the recorded floor
- `tool/gates/citation_check.py`, `tool/gates/orphan_widget_check.py`
- `CONTRIBUTING.md` — the same rule stated as "a gate that cannot fail is worse than
  no gate, because it is indistinguishable from one"
- ADR-0012 (the walk whose fixture keeps it honest), ADR-0016 (an inventory the suite
  cannot overclaim about)
