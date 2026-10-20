# ROADMAP

This file records what the Evangelion client ships today, what is planned, and
what is blocked, deferred, or wrong. It is written against measurement rather
than intention, and every figure carries the command or the `file:line` that
produced it.

`docs/DRIFT.md` is the catalogue of claims that were written once and later
found false. A roadmap is the most likely place for a new one to be born,
because it is written once and then stops being checked. So the rule here is
narrow and deliberate: **every number below was measured on 2026-10-11, or is
quoted from a named document with a `file:line`.** Where the two disagree, this
file shows the measurement and names the document it contradicts.

The authority for scope, architecture, and standards is
[`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md), which wins over
this file. Where this file and that one disagree, that one is right and this one
is stale.

## Status

The client is a working Flutter application against a live REST backend, with
all seven of its gates passing at the time of writing. It has never been tagged
or released.

| Property | Value | Source |
| --- | --- | --- |
| Declared version | `1.0.0+1` | `pubspec.yaml:5` |
| Published to pub.dev | no — `publish_to: 'none'` | `pubspec.yaml:3` |
| Git tags | 0 | `git tag` |
| Published releases | none | `gh release list` |
| Changelog entry | `[1.0.0] - 2026-10-11` | `CHANGELOG.md:20` |
| Commit range | 81 commits, 2026-10-02 to 2026-10-11 | `git log` |
| Screens | 7 | `lib/features/*/presentation/pages/` |
| Routes | 7 `AutoRoute`s + 1 wildcard redirect | `lib/app/router/app_router.dart:242` |
| Route constants | 9 | `tool/verify_purity.sh`, gate 4 |
| Repository ports | 5 | `lib/core/domain/repositories/` |
| DI modules | 8, of which 7 carry providers | `lib/app/di/modules/` |
| ARB keys | 111 per locale | `lib/l10n/app_en.arb` |
| Design-system widgets | 23 | `lib/core/design_system/widgets/` |
| Tests | 3639, all passing | `flutter test` |
| Line coverage | 98.86 % (8503/8601) · 98 uncovered | `flutter test --coverage` |
| Analyzer | no issues | `dart analyze --fatal-infos --fatal-warnings` |

The last three rows are what `tool/verify_all.sh` reports. Running it prints a
summary of the same seven gates and exits `0`.

> [!NOTE]
> The recorded floor in
> [`tool/baseline/gates.txt`](tool/baseline/gates.txt) reads `3639` tests and
> `99` uncovered lines. **The floor is a BUDGET OF UNCOVERED LINES, not a
> percentage**, and the percentage beside it — `98.85` — is what that budget
> renders as at the tree's current size, not the budget itself. The reason is
> in the file: a percentage floor widens itself as the code grows (98.85% is 99
> uncovered lines out of 8601 and **100** out of 8701), and the coverage
> measurement is a **sample** — `flutter test --coverage` collects from one
> isolate per isolate group, and a `const` constructor's materialisation is a
> per-isolate event — so the same tree can measure one line differently on two
> machines. The floor is written **only** by
> `tool/verify_all.sh --update-baseline`.

## Design overhaul

**The visual direction is decided, and it is decided against `eva/redesign.html`.**
The LUMEN redesign replaces `eva/src/*.tsx` as the design source of truth, and
[`ADR-0022`](docs/adr/0022-full-fidelity-redesign-supersedes-0001.md) records the
adoption together with the scope reversal it forced: the redesign names seven
routes (`eva/redesign.html:1244`), so §2 decision 1's cut of the library and the
profile is **superseded**, and the ADR ships the **fiction table** — every
surface the redesign specifies, whether a measured endpoint serves it, and what
would have to exist to stop it being a stub. Read that table before assuming a
screen's data is real. It is not a promise about the future; it is the accepted
price of shipping the design faithfully, and it is dated 2026-10-13.

The scope is **no longer visual-only**. That sentence used to be the whole of
this section's caveat and it is now false: the layer model, the repository
ports, the dependency-injection split, the error algebra and the routing shape
all stay where they are, but **two routes are added and one is retired**
(`/journey` and `/communion` in, `/result` out to a modal). See
`docs/agents/AGENT_CONTEXT.md` §2 decision 1 and its **Pending implementation**
note under the route table.

**Three ADRs are superseded by ADR-0022, and one is not.** `superseded` says the
decision was *replaced*; it does not say the code has caught up, and here it has
not — Phases 2 through 6 of
`docs/superpowers/plans/2026-10-13-lumen-redesign.md` carry it across.

| ADR | Now | Why |
| --- | --- | --- |
| [`0016`](docs/adr/0016-dark-glassmorphic-design-system.md) | `superseded by ADR-0022` | the redesign brings its own palette, shader, witness sky and dock, and its five families have already landed on `feat/fonts-ui-families` |
| [`0017`](docs/adr/0017-split-the-accent-into-a-fill-and-an-ink.md) | `superseded by ADR-0022` | the fill/ink split and the `onEmber` divergence existed to make the old dark-glass accent legible; the redesign replaces the accent |
| [`0019`](docs/adr/0019-performance-budget.md) | `superseded by ADR-0022` | "one blur site per screen" is a budget for a design that blurs; the redesign blurs the whole viewport with a shader and a 14-control workshop |
| [`0018`](docs/adr/0018-bilingual-typography-two-arms-two-questions.md) | **still `accepted — under review`** | the redesign is bilingual in the same way and does not touch the two-arms-two-questions resolution, so there is nothing in ADR-0022 to re-examine it against |

### What a prototype swap breaks — and what this one cost

`eva/` is not a folder of reference images. It is load-bearing in the test
suite, and the dependency is measured rather than asserted. Replacing it is a
checklist, not a visual refresh.

**THE SWAP IS DONE**, and the table's "measured today" column is now the
**before** column, with the cost beside it.

| Surface | Before the swap | What the swap cost |
| --- | --- | --- |
| Dart files carrying `X.tsx:NNN` citations | 119 (63 in `lib/`, 56 in `test/`) | **0** — every one rewritten by hand, each either re-pointed at `redesign.html` or turned into a divergence note carrying the value |
| Individual citations | 948, all resolving | **2,450**, all resolving — the count went **up** because the gate now watches the documents, where 113 claims had never been checked by anything |
| Prototype files cited | 12 `.tsx` under `eva/src` | **0** — `eva/src/` is retired, and the gate's pattern still matches `.tsx` so that a citation into it is **reported** rather than ignored |
| Geometry harnesses parsing the prototype at test time | 5 | **0** — the last one, the blur-radii group, was re-pointed at the redesign's own seven blur sites |
| Golden PNGs | 148 | **0 invalidated** — the orbs' sixteen goldens went with the orbs, and four scope goldens were re-recorded because the layer behind them changed |
| Token gates re-baselined | 5 | see below |

Run the citation gate yourself to confirm the table's first four rows:

```bash
python3 tool/gates/citation_check.py
```

It reports the reference file count, the citation count, and how many resolve.
It now reports **2,450 found, 2,450 resolved, 0 broken** against **two**
references — `eva/redesign.html` and `eva/brief.txt`.

**AND THE BRIEF'S LINES ARE CHECKED FOR THE FIRST TIME.** Its filename had a
hyphen in it, and the gate's pattern matched `[A-Za-z0-9_]+`, so
`pasted-attachment.txt:97` **never matched** and its eight line citations were
verified by nothing. The pattern now matches the **named references** rather
than a generic extension — a generic `.txt` arm turned every `CMakeLists.txt:25`
in the tree into a broken citation.

Two properties of that gate matter more than the count, and both cut in
opposite directions.

First, it **will** fail loudly on a line-number shift, because it checks
existence and range. That is the cheap failure. Second, it **will not** tell you
that a citation now points at a line which no longer says what the claim says.
As [`docs/agents/AGENT_CONTEXT.md:660`](docs/agents/AGENT_CONTEXT.md) records,
the harness for `/login` found **two of its own citations wrong on its first
run**. A new prototype will produce more findings of that kind, and the gate
does not distinguish them from the ones that are merely renumbered.

> [!NOTE]
> **That gate cannot see this file, or ADR-0022.** `citation_check.py:59` sets
> `ROOTS = ("lib", "test", "tool")` and walks `*.dart` only, so a
> `redesign.html:NNN` claim in a Markdown file is **unverified by
> construction**. Every `eva/redesign.html:NNN` in ADR-0022 was read by hand
> against the file; this is the note that says so rather than letting a green
> gate imply otherwise.

### The citations now describe a design the goldens no longer show

**Found on 2026-10-12, by re-measuring rather than by reading.** The fonts were
swapped to the redesign's five families and **148 goldens were re-recorded**. Every
one changed and none for a geometry reason — no layout number moved, only the
typeface.

So there is a live inconsistency, and it is worth naming precisely rather than
leaving to be discovered:

- **All 948 citations still resolve** against `eva/src/*.tsx`. The gate is green
  and it is correctly green: every claim it supports is a claim about *geometry* —
  a height, a radius, a padding — and geometry is exactly what did not change.
- **The goldens now depict the redesign's typefaces** while the citations still
  describe the old prototype's. `citation_check` cannot see this. It checks that a
  line exists, not what the line depicts.
- **The coupling is not broken, it is narrowed.** `CONTRIBUTING.md` requires a
  changed golden to be re-checked against its citation. For a typeface change that
  check is a formality, because the citation is about a number the swap did not
  touch.

What closes it: the geometry harnesses being re-pointed at `redesign.html`, which
is the remaining work on `build/redesign-reference`. Until then, a golden is a
record of *this* client's rendering and a citation is a record of *that*
prototype's geometry, and the two are not describing the same artefact.

### The five gates a visual change re-baselines

Token-level gates carry measured numbers that a visual change moves. Each has to
be re-recorded deliberately, or the change is not measurable at all.

| Gate | File | What it pins |
| --- | --- | --- |
| Text contrast | `test/core/design_system/tokens/text_contrast_gate_test.dart` | per-token contrast ratios, light and dark |
| No colour literals | `test/core/design_system/effects/no_colour_literals_test.dart` | every colour resolves through the token ramp |
| Glass blur budget | `test/core/design_system/widgets/glass_blur_budget_test.dart` | the blur-area ceiling |
| Font coverage | `test/support/font_coverage_test.dart` | every rendered run has a bundled face |
| Arabic typography | `test/arabic_typography_test.dart` | declared Amiri runs, over six screens |

The Arabic typography gate deserves a note, because it is the only one of the
five that is designed to resist a silently weakened version of itself. It
compares a **declared list** of Arabic runs for equality in both directions
rather than counting them, so a run that vanishes is red by name instead of
passing vacuously. Seven `vacuousBecause: null` call sites stand behind that
list, and every one of them is currently null — which means the gate is not
vacuous on any screen it covers.

### One screen has no prototype harness at all — and it is the one being deleted

**Seven of the eight screens have a test that reads the prototype at test time**
— `/login`, `/`, `/reading`, `/quiz`, `/settings`, `/communion` and `/journey` —
and **the one that does not is `/result`**, the modal Phase 6 retires.

**The narrow claim this paragraph used to make is gone, and it stopped being true
as the redesign landed.** It said `/settings` and `/leaderboard` had **none**;
the board's golden suite and the settings' own suite now read `eva/redesign.html`
when they run, and the journey's medals test reads the prototype's own i18n
table to check the four medal names it transcribes. What remains of the worry is
smaller: the **geometry harnesses that parse the prototype's stylesheet** are
still fewer than the screens, because a screen whose numbers a human transcribed
can be pinned by those numbers while a screen whose numbers are *derived* from
the stylesheet has to parse it.

A reader skimming a green gate run would reasonably assume every screen is
prototype-checked; on this repository, **one of eight** is not — and it is the
one the redesign is deleting.

## Blocked on the backend

The backend is a **separate project in a sibling checkout**. This repository
does not own it, treats it as read-only reference material, and never writes to
it. If a task appears to need a backend change, escalate it rather than working
around it.

Every claim below is measured in
[`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md), which was
verified against a running server on **2026-10-11**, or is recorded in
[`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md) §5.

| # | Blocked item | Consequence for the client |
| --- | --- | --- |
| 1 | No successful submit has ever been observed | `/quiz` cannot complete against live data |
| 2 | `/readings/today` and `/streak/summary` disagree about today | the two are never reconciled |
| 3 | No auth endpoint exists | `FakeAuthRepository` is the only adapter; login is UI-only |
| 4 | No `GET /readings/:id` exists | `/quiz` re-fetches to get fresh `already_answered` flags |

### No successful submit has ever been observed

All three probe rows were reproduced exactly. The two halves of the contract
cannot both be satisfied: the read endpoint hands out **non-UUID** question ids
for a date-stamped reading, and the submit route declares a `uuid` schema.

| Submit target | Result |
| --- | --- |
| Date-stamped reading, `question-group-3` | `400` — `question_id must match format "uuid"` |
| Today's seeded reading, `bbbbbbbb-…` | `409` already-submitted |

No client can submit against the seeded group. Two standing rules follow, and
both survive untouched: do not validate ids as UUIDs on the read path, because
today's is a UUID while a `?date=` is not; and treat fixtures in `test/` as
transcriptions rather than captures.

### The two endpoints disagree about today

Read in the same minute, the streak endpoint reports `current_streak: 0` and
`today_status: 'pending'`, while the reading endpoint reports
`current_streak: 4` and `is_fully_completed: true`.

Neither is wrong about its own job. The client's answer is to **never
reconcile them**: each field comes from the endpoint whose job it is, nothing
sums them, prefers one, or cross-checks them. The property that earns this is
that when the backend fixes the disagreement, no client line changes.
Reconciling — taking the max, or "completed if either says completed" — is the
one answer ruled out, because it invents a number the server never sent.

### Login is UI-only

There is no auth endpoint. `FakeAuthRepository` is the only class in `lib/`
that implements `AuthRepository`, and it returns a seeded session. Login and
onboarding are therefore presentation-only, which is recorded as
`docs/agents/AGENT_CONTEXT.md` §2 decision 3.

## Deliberate product debt

Every item here is a live control that is inert, or a surface that cannot be
reached. Each was decided, and each is documented where a reader will find it.
None is an oversight.

The four permanently inert controls on `/login` are the clearest case. Each
renders disabled and carries the reason in its accessible name, which is the
policy: a reader must be told *why* a control cannot be pressed, not only that
it cannot.

| Control | Where | Reason recorded |
| --- | --- | --- |
| Forgot password | `lib/features/auth/presentation/pages/login_page.dart:490` | no auth endpoint |
| Create account | `lib/features/auth/presentation/pages/login_page.dart:553` | no auth endpoint |
| Continue with Google | `lib/features/auth/presentation/pages/login_page.dart:498` | no auth endpoint |
| Continue with Apple | `lib/features/auth/presentation/pages/login_page.dart:505` | no auth endpoint |

The remaining items are narrower, and each has its own reason.

| Item | State | Source |
| --- | --- | --- |
| `/reading` bookmark | inert; names its own unavailability | `lib/features/reading/presentation/widgets/reading_controls.dart:201` |
| `/login` validation messages | render in English on the Arabic arm | `lib/features/auth/domain/login_credentials.dart:75` |
| `/result` | not deep-linkable; required constructor parameter | [`ADR-0015`](docs/adr/0015-result-is-not-deep-linkable.md) |
| `/quiz` all-answered | dead end: `QuizCta.none`, no result to show | `lib/features/quiz/presentation/bloc/quiz_bloc.dart:318` |
| `/` avatar | **no longer inert** — pushes `/settings` | `lib/features/home/presentation/pages/home_page.dart:398` |

The validation messages deserve their own sentence, because the cause is
structural rather than an oversight. The strings live in a pure-Dart domain
file, which has no `Locale` parameter and by the project's own purity rules
cannot acquire one. An English-only message on the Arabic arm is the price of
keeping the domain layer free of the framework, not a missing translation.

`/result` cannot be deep-linked because `ResultPage` takes its `SubmitResult` as
a **required constructor parameter**. It cannot read it from `QuizBloc`, because
that would be a cross-feature import. The response travels as an argument from
the one screen that holds it to the one that renders it, and a reader who has
submitted nothing therefore has no result screen.

## Release debt

Three items stand between this repository and a distributable build. None is
hidden, and none is expensive; all three are unfinished.

| Item | State | Source |
| --- | --- | --- |
| Android application id | `com.example.evangelion` | `android/app/build.gradle.kts:19` |
| iOS bundle identifier | `com.example.evangelion` | `ios/Runner.xcodeproj/project.pbxproj:386` |

The two identifiers are still the `flutter create` placeholders. They share a
name across both platforms and must be changed before any real distribution.

> [!NOTE]
> **Continuous integration is no longer on this list, because it is no longer
> missing.** This section used to carry a third row — *"Continuous integration
> | no workflow files exist"* — and the paragraph under it explained at length
> that there is **no** `.github/workflows/` directory and therefore no workflow
> that runs any of the gates, so a green state was a property of one person's
> discipline rather than of the repository.
>
> **That was true when it was written and it stopped being true**, which is
> what `docs/DRIFT.md` is a catalogue of. `.github/workflows/ci.yml` now runs
> **all eight gates** in three jobs: gates 1-7 through `tool/verify_all.sh`
> (the same script a contributor runs, so a gate is never implemented twice),
> gate 8 — the real Linux build — on its own runner, and
> `tool/verify_gates_selftest.sh`, which plants one violation per gate and
> requires each gate to fail. The runner image, the Flutter version and every
> action are pinned, because a coverage floor and a golden PNG are only
> meaningful against a fixed toolchain.

The Linux build gate is a related caution. It is the slowest gate and it
**wipes `build/linux/x64/{debug,release}`** before rebuilding, so
`tool/verify_all.sh` runs it only behind `--with-build`. On a contributor's
machine the build is therefore unverified until someone asks for it — and on
CI it is verified on every push, because a hosted runner's tree is disposable
and the wiping is free there.

> [!WARNING]
> Do not trust `flutter build linux --release` reporting success on its own. It
> reported a clean build for three commits while the Linux toolchain was missing
> entirely. `tool/verify_linux_build.sh` exists because of that, and
> `flutter doctor`'s `Linux toolchain` line is the one command that checks the
> machine rather than the source. Its current defect is described in
> [A live gate defect](#a-live-gate-defect).

## Decided, not yet done

These three are settled questions whose answers have not been implemented, or
whose implementation was deliberately left standing. None is urgent, and none
should be reopened by accident.

| Item | State | Source |
| --- | --- | --- |
| Whole-state writers on the largest states | recorded, deliberately not reversed | [`DRIFT.md` §6](docs/DRIFT.md), decision 156 |
| `core/design_system` as its own pub package | open question, single package is the default | `docs/plans/10-open-decisions.md:17` |
| A stub leaderboard adapter | ships, behind a compile-time flag | `lib/features/leaderboard/data/repositories/stub_leaderboard_repository.dart` |

The whole-state writers are the most interesting of the three, because the
audit behind them is a **design** claim rather than a factual one, and every
number in it is already correct. `copyWith` is disabled on the three largest
states and kept on the three smallest. A property whose benefit grows with
reuse is withheld exactly where the state is big enough to hurt. It was
recorded and not reversed, deliberately.

The stub leaderboard is the only stubbed adapter in `lib/`, and it is inert by
default. It is selected by `--dart-define=USE_STUB_LEADERBOARD=true` alone, read
through `bool.fromEnvironment` with `defaultValue: false`, so it cannot leak
into a build that does not name the flag. It exists because the seeded scores
are frozen: the reader's rank can never move without a working submission path,
so the app can never show the states that matter most.

Note that the plan expects a **notifications** stubbed toggle to ship with the
settings feature, and it does not. `UserSettings` has four fields and none of
them is `notificationsEnabled`, and the screen records the row as cut. The plan
is not the authority here; [`AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md)
§2 is.

## Docs debt: findings from re-measurement

Every row below was found by **re-measuring**, not by reading carefully. That
is the point, and it is stated once here rather than editorialised: prose cannot
fail a test. A gate reports on the code; a document reports on whoever last
wrote it, and nothing tells you the two have parted.

These are reported as findings, not as work someone forgot.

| Document and line | Says | Measures |
| --- | --- | --- |
| `docs/agents/AGENT_CONTEXT.md:27` | ~~six screens~~ — **resolved 2026-10-13** | seven screens, per [`ADR-0022`](docs/adr/0022-full-fidelity-redesign-supersedes-0001.md) |
| `docs/agents/AGENT_CONTEXT.md:225`, `:239` | four repository ports | 5 |
| `docs/agents/AGENT_CONTEXT.md:776` | six `@module` files, committed and empty | 8 files, 7 carrying providers |
| `docs/agents/AGENT_CONTEXT.md:2201` (decision 79) | three of six screens vacuous | none vacuous |
| `docs/agents/AGENT_CONTEXT.md:1204` (decision 32) | avatar has no destination | it pushes `/settings` |
| `docs/agents/AGENT_CONTEXT.md:45`, `:134`, `:2719`, `:2841` | 72 ARB keys | 111 |
| `docs/SEAMS.md:267` (Seam 7) | `lib/app/app.dart` hard-codes `ThemeMode.dark` | it switches over a persisted setting |
| `AGENTS.md:127` | 27 design-system widgets | 23 |
| `lib/app/router/app_router.dart:9`, `:23`, `:214` | six routes, six locked routes, six features | 7 |
| `README.md` — "Four of these are deliberately inert" | four **screens** | none: `/login`, `/`, `/reading` and `/quiz` were rebuilt in Phase 5.1-5.4. What still says "unavailable in this build" is two **controls** — `/`'s library cards and `/reading`'s pill controls — not four screens. The paragraph's other half ("no passage library and no user profile") was true until Task 5.6, which landed the profile as `/journey` and left the passage library cut |
| `lib/app/di/navigation_injection.dart:58` | five hand-written registrations | 10 |
| `lib/core/design_system/tokens/eva_colors.dart:123`, `:213` | light `ember` is 2.05:1 | 2.11:1 |
| `lib/features/home/presentation/pages/home_page.dart:489` | light `ember` is 2.05:1 | 2.11:1 |

Three of these deserve a note, because the correction is *documented inside the
document that is wrong*.

[`ADR-0005`](docs/adr/0005-four-narrow-ports-no-fat-repository.md) is titled
"Declare **four** narrow repository ports" and its body says four, while its own
line 77 records that five exist and explains why. The ADR knows. Its title does
not.

The `ember` contrast rows are the same shape. The contrast gate holds the
corrected figure at
`test/core/design_system/tokens/text_contrast_gate_test.dart:188`, and three
doc comments elsewhere still carry the pre-correction 2.05:1. The gate is right
and the prose is stale, in the same repository, on the same token.

The registration row is a plain undercount. `configureNavigation()` contains ten
`registerSingleton` and `registerLazySingleton` calls; the header above them
says five, and names five of them.

### Two further gaps, of a different kind

[`README.md`](README.md) is still the unmodified `flutter create` template. It
describes a starting point for a Flutter project and nothing about this one.
For a public repository that is the first thing a reader sees.

Machine-specific absolute paths are committed in seven places across three
documents — `AGENTS.md`, `docs/agents/AGENT_CONTEXT.md`, and
`docs/BACKEND-VERIFICATION.md` — naming the author's home directory and the
backend's sibling path. They are correct on the machine that wrote them and
meaningless everywhere else.

### The quarantined proposals directory

[`docs/proposals/`](docs/proposals/README.md) is quarantined, and its own README
says so in its title: "NOT WHAT THIS CODEBASE SHIPS". Two proposals live there,
written against the backend's surface rather than the client's, and they are
kept because the backend contract they describe is real even where the client
implementation is not.

One of them lists its own corrections to the client in a table, and keeps them.
Whether a quarantined proposal is promoted or deleted is an open call, and this
file leaves it open. It is recorded here so that a reader meets the directory
and its status at the same time.

## A live gate defect

[`tool/verify_linux_build.sh`](tool/verify_linux_build.sh) has a header at line
32 saying its step 1 is `flutter doctor`. It never runs it. Line 70 reads
`/tmp/eva_doctor.log`, a fixed path outside the repository, and greps it.

This is not a false pass, and the distinction matters. The script **fails
closed**: with the log absent, it prints `FAIL: flutter doctor did not report a
Linux toolchain line at all.` and exits `1`, which is the behaviour you want
from a gate that cannot find its input.

The defect is that a **stale** log satisfies it. The file is not written by the
script, is not versioned, and has no freshness check. A log left over from a
machine that had a working toolchain makes the gate pass on one that does not,
which is the failure mode the script exists to catch, reproduced inside the
script.

There is a second, quieter problem in the same function, and it is a matter of
consistency rather than of correctness. Lines 92 to 96 search for
`^\[.\] Linux toolchain`, using the byte-anchored pattern that the script's own
header at lines 66 to 69 explains **cannot match** under the C locale, because
`.` matches a single byte and the status glyph is three bytes of UTF-8. That is
accurate, and measured: the same pattern matches under `LANG=en_US.UTF-8` and
does not match under `LC_ALL=C`.

So the branch is not dead, it is **locale-dependent** — it fires on a
UTF-8 machine and silently does nothing on a C-locale one, which is the same
green result either way. The check that actually works regardless is at lines
81 to 90, which compares against the glyphs as byte escapes precisely so it
cannot depend on the locale. Having fixed that for the first check and not the
second is what makes the pair inconsistent.

> [!WARNING]
> This is exactly the class of defect
> [`ADR-0020`](docs/adr/0020-a-gate-that-cannot-fail-is-worse-than-no-gate.md)
> exists to name: a gate that cannot fail. This one fails closed, so it is the
> milder cousin — but a reader who trusts step 1 is trusting a log file nobody
> generated. If you touch this script,
> [`tool/verify_gates_selftest.sh`](tool/verify_gates_selftest.sh) shows the
> negative-control method the repository expects: plant the violation, prove
> the gate fires, remove it.

## How to check the numbers in this file

Every measurement in this file is reproducible. The fastest check is the gate
runner, which prints most of the status table itself:

```bash
tool/verify_all.sh
```

| Claim | Command |
| --- | --- |
| Tests and coverage | `flutter test --coverage` |
| Analyzer | `dart analyze --fatal-infos --fatal-warnings` |
| Prototype citations | `python3 tool/gates/citation_check.py` |
| Widget reachability | `python3 tool/gates/orphan_widget_check.py` |
| Layer and route purity | `tool/verify_purity.sh` |
| Goldens | `find test -name '*.png' \| wc -l` |
| ADR statuses | `rg -n 'Status' docs/adr/` |

When you add a figure to this file, measure it the same way and say which
command produced it. A number here that nobody can reproduce is the defect this
file exists to prevent.
