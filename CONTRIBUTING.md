# Contributing to Evangelion

Evangelion is a Flutter client for a bilingual (Arabic Smith & Van Dyck /
English NKJV) Sunday-School daily reading platform. It is a strict
feature-first clean architecture over a live REST backend, and it carries a
heavier verification regime than most client repositories.

Two ideas run through everything below. First, **a claim about a number is a
claim about a specific thing**, and it must carry a `file:line` or a command
you can paste. Second, **a gate that cannot fail is worse than no gate**,
because it is indistinguishable from one. If you take one habit from this
document, take the second.

> [!IMPORTANT]
> [`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md) is the single
> source of truth for scope, architecture, and standards. It **wins over every
> other document in this repository**, including [`AGENTS.md`](AGENTS.md) and
> this file. If something here disagrees with it, that something is wrong.

## Prerequisites

The gates in this repository drive four tools, and `tool/verify_all.sh`
checks that all four are on `PATH` before it runs anything. You need every one
of them.

| Tool | Version | Why you need it |
| --- | --- | --- |
| Flutter | **3.47.4** (stable) | Builds, tests, and generates code. There is no FVM and no melos. |
| Dart | **3.13.3** (stable) | Ships with Flutter above. `pubspec.yaml` declares `sdk: ^3.13.3`. |
| `rg` (ripgrep) | any recent | The architecture gates are ripgrep patterns. Without it every scan returns empty and the gate passes vacuously. |
| Python 3 | 3.x | Two gates under `tool/gates/` are Python. |

You also need the **Linux desktop toolchain** — GTK 3 development libraries,
`clang`, `cmake`, `ninja`, and `pkg-config` — for the one gate that builds the
app rather than reading it. On Debian and Ubuntu that is roughly
`apt install clang cmake ninja-build pkg-config libgtk-3-dev`. Without it, the
build gate cannot tell you anything, and `flutter build linux --release` will
happily report success anyway.

## Getting set up

Install the package dependencies and confirm the toolchain is what you think
it is:

```bash
flutter pub get
flutter --version      # 3.47.4 / Dart 3.13.3
flutter doctor          # the ✓ Linux toolchain line is the one that matters
```

Run the app on the desktop target with `flutter run -d linux`. **It talks to
the deployed backend by default** — `https://evangelion-backend.vercel.app` —
so there is nothing to start. To point it at the local backend instead, pass
the base URL at build time:

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:3000
```

> [!NOTE]
> Use `flutter test`, never `dart test`. The plain Dart VM has no `dart:ui` and
> cannot compile Flutter SDK sources, so `dart test` fails to load *every* test
> file, including the pure-Dart ones, because each imports `flutter_test`.

### The backend

Four of the seven screens read live data. The default target is the
**deployed** backend, and it is already running:

```bash
curl -s https://evangelion-backend.vercel.app/health
```

It is the Fastify 5 application on Vercel serverless, backed by Neon Postgres
and a real Redis. Every route is under `/api/v1`. ADR-0023 has the full
decision.

> [!WARNING]
> **The deployed backend has a reading scheduled for one date only.** Its
> Neon database was seeded once, on 2026-10-19, with
> `scheduled_date = CURRENT_DATE`, and the seed is a CLI rather than a boot
> step — so the schedule does not roll forward. `GET /readings/today` answers
> **404** for every date that is not in the database. That is a property of
> the database's contents, not a client bug, and it is measured in
> [`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md).

### The local backend

If you want the local one, it is a **separate project** in a sibling checkout,
and it is read-only reference material — this repository does not own it and
must never modify it.

```bash
cd <path-to>/EvangelionBackend
NODE_ENV=development PORT=3000 node dist/server.js
```

No Postgres and no Redis are required; both fall back to in-memory. The base
URL is `http://localhost:3000` and every route is under `/api/v1`.

> [!WARNING]
> `NODE_ENV=development` is **not optional**. The in-memory Redis fallback's
> constructor pre-seeds the leaderboard ZSETs only when `NODE_ENV` is not
> `test`, so a server started under `NODE_ENV=test` answers with an empty
> leaderboard. An empty response is a fact about *that process*, not a property
> of the backend — a claim about a system needs a second observation from a
> restarted server, and the restart condition has to be stated.

If you background the server, use `setsid … & disown`:

```bash
setsid env NODE_ENV=development PORT=3000 node dist/server.js > /tmp/eva.log 2>&1 < /dev/null &
disown
```

A plain `&` is killed when the calling shell exits, and then every request
returns `000`, which reads exactly like a server fault and costs you an
afternoon. What the running server actually does is measured in
[`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md).

## The seven gates

`docs/agents/AGENT_CONTEXT.md` §7 lists the commands that must pass before
you report work done. `tool/verify_all.sh` runs them in cost order, so the
cheapest failures surface first and a formatting error takes seconds to find
rather than the minute the suite takes. The numbering below is the script's.

One gate is not in §7: gate 4, the two Python checks, was added later from
recorded decisions about prototype citations and widget reachability. The
other seven are §7's, and gate 8 is §7's seventh line made opt-in.

| # | Gate | Exact command | A failure means |
| --- | --- | --- | --- |
| 1 | Format | `dart format --output=none --set-exit-if-changed lib test tool` | The tree is not `dart format`-clean. Run `dart format lib test tool`. Nothing else is meaningful until this passes. |
| 2 | Analyze | `dart analyze --fatal-infos --fatal-warnings` | A type error, a lint, or a deprecated API. This single command is the enforcement for types, lints, **and** `deprecated_member_use` alike. |
| 3 | Architecture | `tool/verify_purity.sh` | A pure-Dart directory reached Flutter, Dio or HTTP; a feature imported another feature; a generated file lost its `ignore_for_file` header; a route constant stopped being a plain literal. |
| 4 | Citations and reachability | `python3 tool/gates/citation_check.py` and `python3 tool/gates/orphan_widget_check.py` | A `*.tsx:NNN` claim points at a prototype line that no longer says what it said, or **a widget anywhere under `lib/`** is built and tested but no screen's tree contains it. The orphan gate's inventory is **all of `lib/`** — not the `*/widgets/` directories — so a widget in `effects/`, `motion/` or `tokens/` is in scope like any other; its roots are the **registered pages plus the app root**; and it exits **2** (FATAL) when it cannot find the app's router, because "no page is registered" and "the router moved" must not be the same answer. |
| 5 | Fixable APIs | `dart fix --dry-run` | Deprecated or lint-fixable usage remains. This command **exits `0` even when it has work to do**, so its output is the check, not its exit code. |
| 6 | Test suite | `flutter test` | A behaviour changed, or a test is flaky. |
| 7 | Coverage and the recorded floor | `flutter test --coverage` | Line coverage or test count fell below `tool/baseline/gates.txt`. |
| 8 | Linux build (opt-in) | `tool/verify_linux_build.sh` | The app does not really build. See below. |

Gate 8 is numbered separately because `tool/verify_all.sh` runs it only when
you pass `--with-build`. It is the slowest gate, and it **wipes
`build/linux/x64/{debug,release}`** before rebuilding, so it is the only gate
that mutates the tree rather than reading it.

### One command for all of them

```bash
tool/verify_all.sh                    # the seven fast gates
tool/verify_all.sh --with-build       # + the Linux build gate
tool/verify_all.sh --update-baseline  # re-record the coverage floor
```

The script distinguishes three outcomes, and the third is the point:

| Outcome | Meaning | Exit |
| --- | --- | --- |
| `ok` | The gate ran and passed. | — |
| `FAIL` | The gate ran and found something. | `1` |
| `FATAL` | The gate **could not run** — a missing tool, a broken `rg`, an unreadable baseline. | `2` |

A missing tool or an empty capture is `FATAL`, never a pass. That distinction
is the whole reason the script is shaped the way it is, and it is why reading
the exit code alone is not enough: `2` means nothing was checked.

> [!NOTE]
> Gate 7 compares against the **recorded floor** in
> [`tool/baseline/gates.txt`](tool/baseline/gates.txt), not against your last
> run, so one bad run cannot permanently lower the bar. That file is written
> **only** by `--update-baseline`, which prints the old and new values so the
> change is visible in the commit diff. Re-recording the floor is a deliberate,
> reviewed decision — it is never a way to make a red run green.

## A gate that cannot fail is worse than no gate

This repository has recorded several gates that reported a clean run over a
surface they never examined, including one that shipped three false greens in
a row and then, once fixed, shipped an unreachable assertion of its own. The
causes are mundane and worth guarding against directly:

- A ripgrep pattern that fails to **compile** exits `0` with every line
  "passing". Ripgrep has no backreferences, so a pattern using one is a gate
  that cannot fail.
- A script that reads only stdout turns a missing or broken `rg` into empty
  output, a hit count of `0`, and a cheerful `PASSED`.
- A check that runs **after** the step it is meant to audit can never observe
  the condition it names.

**When you change a gate, plant a violation and prove it fires before you
report the gate as fixed.** Put the violation in a scratch copy outside the
repository, confirm the correct non-zero exit and the correct message, then
remove it. `tool/verify_gates_selftest.sh` does this for the existing gates if
you want a worked example rather than a description.

Every gate in this repository is negative-controlled, which is a property you
can check rather than a claim you have to trust.
[`docs/DRIFT.md`](docs/DRIFT.md) lists the claims that rotted instead, and it
is worth reading once before you contribute: most of them were true when
written.

## Test-driven development

`docs/agents/AGENT_CONTEXT.md` §6 defines when a test comes first and when it
does not. The division is deliberate.

### Red-first is required

Write the failing test before the implementation for domain entities,
`Result<T>` and `Failure`, use cases, API models and mappers, the dual-shape
error mapper, the header interceptor, `FakeAuthRepository`, the settings
repository, `evaScalerFor`, the token and motion tables, and **every cubit**
using `bloc_test` and `mocktail`.

The procedure per behaviour is short: write the failing test, run it,
implement the minimum that passes, refactor with the test green.

**A valid red means it fails for the intended reason.** A test that fails to
compile, or that fails on an unrelated assertion, is not a red. It proves the
toolchain works and nothing else. Run it and read the failure message before
you write the implementation.

### Widget and screen work is exempt

Widgets and screens get behaviour tests, widget tests, and golden tests
written alongside the widget rather than in a test-first ceremony.

The exemption has one hard edge: **domain logic must not be buried inside a
widget**. If a widget needs a conditional or a calculation, extract it to a
cubit or a pure function and TDD that instead. A widget that computes a
streak or a completion ratio inline is untested logic wearing a `build`
method, and no gate here can see it.

## Conventions that are enforced, not optional

These are not style preferences. Each one has a gate or a review that will
catch its absence.

| Rule | Where it is enforced |
| --- | --- |
| Commit message is `<type>(<scope>): <subject>` | Review |
| One branch per unit of work, named `<scope>/<name>` — `feat/`, `build/` or `docs/`, matching the commit-message scope | Review |
| Do not merge to `main` without review | [`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md) §8 |
| `dart analyze` runs with `--fatal-infos --fatal-warnings` | Gate 2 |
| No deprecated APIs | Gate 2 reports `deprecated_member_use` natively; the forbidden-API table in §4 is a seed, the analyzer is the enforcement. Fix with `dart fix --apply --code=deprecated_member_use`. |
| No `// ignore:` in hand-written code | Review |
| No `print`; use `debugPrint` | `avoid_print` in [`analysis_options.yaml`](analysis_options.yaml) |
| No `dynamic` | `avoid_dynamic_calls` in [`analysis_options.yaml`](analysis_options.yaml) |

> [!WARNING]
> **No `// ignore:` directives belong in `lib/` or `test/`.** Today the only
> occurrences are inside generated output (`*.freezed.dart`,
> `lib/l10n/app_localizations_ar.dart`) and inside comments that *cite* the
> policy. There is not one real suppression in a hand-written file. An ignore
> suppresses the only signal a line can give, and Dart has no
> `unnecessary_ignore`, so an ignore nobody needed could not have been
> detected. If you believe you need one, the answer is usually to change the
> declaration rather than to silence the analyzer.

## Hard constraints

These come from §8 of the authority document and they are not yours to relax.

**The backend is read-only.** Never write to the sibling backend checkout. Never
run migrations or `npm install` there. If a task seems to require a backend
change, **stop and escalate** and say so in your report rather than working
around it.

**Do not add a dependency** outside the approved set. The approved set is
[`pubspec.yaml`](pubspec.yaml)'s `dependencies` plus `freezed`,
`freezed_annotation`, and Flutter's own `flutter_localizations`. Anything
else needs approval in the task that uses it. Note that `flutter_animate` is
pinned exactly rather than with a caret, deliberately.

**Do not rewrite `docs/plans/`.** That directory has a dedicated owner. If a
plan document is wrong, report it rather than editing it.

**Prefer editing an existing file to creating a new one.** New files only where
the task names a path.

### Regenerating code

Two generators run, and they are not interchangeable:

```bash
dart run build_runner build
flutter gen-l10n                 # ARB -> lib/l10n/app_localizations*.dart
```

`build_runner` produces the `freezed`, `auto_route`, and `injectable` outputs
and **does not run `gen_l10n`**. The three generated localization files are
committed, formatted, because `gen-l10n`'s raw output is not
`dart format`-clean and gate 1 would otherwise be red on a fresh clone.

Run `dart run build_runner clean` explicitly rather than passing
`--delete-conflicting-outputs`; that flag was removed in `build_runner` 2.16.x
and the command still exits `0` while ignoring it.

## Documentation

[`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md) is the single
source of truth and it wins over every other document in the repository,
including [`README.md`](README.md) and this file.

When you add a claim, make it **testable or say plainly that it is not**. A
reader must be able to tell which claims a gate enforces and which are a
person's assertion. Fix the document or delete the claim; never leave a forward
reference that has stopped being true, because a reader cannot tell it apart
from one that still holds. That single failure mode is what
[`docs/DRIFT.md`](docs/DRIFT.md) is a catalogue of.

Be careful about the difference between what was *observed* and what is
*defensive*. A test group that asserts a response shape the backend cannot
produce is a future reader writing a test against a fiction.

## Pull requests

A reviewer will ask you these questions. Answer them in the description rather
than making the reviewer find them.

| Question | What a good answer looks like |
| --- | --- |
| Which gate proves this change? | Names the gate and the command, and the output. "Tests pass" is not an answer. |
| Did you plant a violation to prove the gate fires? | Yes, with the scratch path and the exit code observed. Required if you touched a gate or a gate's inputs. |
| Are the goldens and the prototype citations a coupled pair? | If goldens changed, every changed golden is re-checked against its `eva/` citation. **Re-recording goldens without re-checking the citations is a review failure.** |
| Did the coverage floor move? | If `tool/baseline/gates.txt` changed, `--update-baseline` was run deliberately and the diff is explained in the description. |
| Does this change a documented invariant? | If so, the authority document was updated in the same change, with the measurement that establishes it. |

Before you open the pull request:

```bash
tool/verify_all.sh --with-build
```

Paste the summary. A reviewer who has to reconstruct your gate run will not.

Contributors are asked to follow the [code of conduct](CODE_OF_CONDUCT.md).
Security issues go through [`SECURITY.md`](SECURITY.md), **not** the issue
tracker. Where to ask anything else is [`SUPPORT.md`](SUPPORT.md). The project
is licensed under the [MIT License](LICENSE).
