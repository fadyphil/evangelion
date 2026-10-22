# DRIFT.md — claims that did not survive verification

Every entry is a claim that existed in this repository, checked against the code,
and found to be **wrong**. Each says where the claim was, what the code says, and
whether it was fixed.

This file exists because "the tests are green" and "the documentation is true" are
different properties, and only one of them is enforced by CI. Every row below is a
row where they disagreed.

---

## 1. `AGENT_CONTEXT.md` §2 — "Six screens" / "The six routes"

| | |
| --- | --- |
| **Claim** | `docs/agents/AGENT_CONTEXT.md:126` — "The six routes", with a 6-row table |
| **Reality** | `lib/app/router/app_router.dart:242-261` declares **7** `AutoRoute`s plus a `RedirectRoute` for `*`. `/leaderboard` is the seventh. `app_routes.dart` declares **9** constants: the 7, plus `/servant` (declared, deliberately not routed) and `*`. |
| **Fixed?** | **Yes — 2026-10-19, Task 5.5.** §2's table gained the `/leaderboard` row and its heading stopped saying "six". The **count** is what the row was about, and it became true again. **And it moved once more in Task 5.6**, which added `/journey` — the eighth row and the eighth heading — so the number this row is about is **still** the number §2's table has to carry, and a reader who trusts the heading over the table will be wrong the next time a screen lands. **And it moved a THIRD time in Phase 6 of the Lumen redesign**: `/result` retired to a modal (so the table lost a row) and `/` became the **dock shell** rather than the home screen (so the table's `/` row now names a shell, and the home is one of its three tabs). §2's heading is "The seven routes, and the shell that holds the tabs" and the table carries the shell's row, the two tabs that are their own paths, and the two push actions the dock offers. |

The table was written before the leaderboard landed. Decisions 143–155 record its
arrival; §2 was never updated. The same shape as decision 21's lesson: a claim about
a number that stops being checked the moment it is written.

**And the fix is a second instance of the lesson.** The heading said "six" while
the table had six rows and the router had seven routes — a claim that was wrong in
the direction that *reads* as right, because six rows look like six screens. The
number in the prose and the number in the table were two numbers that agreed with
each other and not with the code, and nothing was checking either.

---

## 2. `AGENT_CONTEXT.md` §2.1 — the `fp_dart` rejection

**The most consequential entry in this file.**

| | |
| --- | --- |
| **Claim** | §2.1: "`sealed` + exhaustive `switch` expressions with no `default` arm is **strictly stronger** than `dartz`'s `Either`" — presented as the reason to reject `fp_dart`. |
| **Reality** | The comparison was against **dartz**. `fp_dart`'s `Either` is **itself `sealed`** — verified in the pub cache, `fpdart-1.2.0/lib/src/either.dart:39`. The stated reason for the rejection does not hold for the package that was rejected. |
| **Fixed?** | **Yes.** §2.1 now carries a `SUPERSEDED` block stating the claim was wrong, and `fp_dart` has been adopted. |

### 2a. The measurements the rejection rested on were all stale

| Claimed | Actual |
| --- | --- |
| `try` blocks in `lib/`: **3**, in two Dio repositories | **6**, in **4** repositories |
| files importing the type: **26** lib / **40** test | **40** lib / **59** test |
| **879** assertions naming `Result`/`Failure` | not reproducible — 1184 lines name them, 97 on an `expect(` line |

The `try` count was the evidence for "the one real gap applies to 3 call sites". It is
6. Nothing in `lib/` needs `AsyncEither` at all.

### 2b. Two claims that are false and are now asserted false

| Claim | Reality |
| --- | --- |
| `fp_dart` fixes the hand-written type's collection-equality gap | **False.** `==` on a `List` is identity in **both**. Measured: same instance → `true`, equal-but-distinct → `false`. |
| `fp_dart`'s `getOrElse` is unsound (returns inferred `R`) | **False.** `R getOrElse(R Function(L l) orElse)` — `R` is the payload type, not inferred from the fallback. |

Both appear in an untracked `docs/CLIENT.md` and `models.md` (see §5 below).

---

## 3. What adopting `fp_dart` actually cost

Not free, and recorded so it is not rediscovered by surprise:

| Property | Before | After |
| --- | --- | --- |
| sealed exhaustiveness at every `switch` | yes | **yes** — verified before commit |
| `Success<List<int>>` compares by contents | no | **no** — unchanged |
| `==` ignores the generic parameter | **no** — guarded on `runtimeType` | **yes** — `either.dart:572` never mentions it |
| `flatMap` / `traverse` / `Either.Do` | absent | available, **unused** |

The covariance guard was real and had mutation tests behind it (decision 131). It is
now pinned as *observed behaviour* by `test/core/common/result_test.dart` rather than
asserted as a guarantee — so a future fp_dart release that adds the check will fail a
test rather than pass unnoticed.

**Restoring it by subclassing does not work**, which was the non-obvious part:

```dart
final class Success<L, R> extends Right<L, R> { ... }

switch (result) {
  Success<Failure, T>(:final value) => ...,   // compile error
  Left<Failure, T>(:final value) => ...,
}
// 'Result<T>' is not exhaustively matched since it does not match
// the pattern 'Right<Failure, T>()'
```

A subclass does not match its supertype's object pattern. Fixing equality that way
destroys the exhaustiveness the migration was undertaken to obtain.

---

## 4. The backend contract (§5) — verified live, two corrections

`AGENT_CONTEXT.md` §5 is the **backend contract**, and every number in it was measured
against a live server. That server was **started and re-measured on 2026-10-11** — full
results in [`BACKEND-VERIFICATION.md`](BACKEND-VERIFICATION.md).

**§5 held up.** The header table, all four rows. Trap 1 (`statusCode` has zero
occurrences in the backend's `src/`). Traps 2/5/6/8/9/10/11 verbatim, including the
`4`-vs-`0` disagreement between `/readings/today` and `/streak/summary`, and all three
rows of the "no successful submit has ever been observed" table. Decision 143's
leaderboard correction also holds — 3 rows, the seeded reader at rank 2.

**Two corrections:**

1. **§5 trap 11 overstates its own case.** It says `reading_id` is
   `"reading-group-3-2026-10-04"` — true for every date *except today's*, which is the
   seeded UUID `aaaaaaaa-…`. So "ids are never UUIDs here" is false for the one reading
   the app actually loads. The client's two standing rules survive unchanged, and trap
   10's conclusion is confirmed for a sharper reason than the doc gives.
2. **Trap 4 is unverifiable today**, and this is the finding rather than a gap in the
   check: it needs a successful submit, and none exists against any client-reachable
   reading. `SubmitResultMapper` transcribes a shape nothing has ever returned.

---

## 5. Two untracked documents that describe a codebase that does not exist

`docs/CLIENT.md` and `models.md` are **not in git**. Both describe an architecture this
project does not have:

| They describe | Reality |
| --- | --- |
| `Either<Failure,T>` via `fpdart`/`fpdart` | *(now true — they were ahead of the code)* |
| `json_serializable` DTOs in `wire/dto/` | no such package, no such directory; banned by decision 8c |
| 14 DTOs, bilingual + localized wire shapes | the client reads one shape, `GET /readings/today/{en,ar}` |
| "7 screens · 4 endpoints" | 7 routes, 5 endpoints |
| `defaultGroupId = 3` at `identity_headers.dart:125` | verify against the file before trusting the line number |
| unscheduled `?date=` → **404** | **200** — `?date=2026-01-01` returns a fully-formed reading, auto-provisioned by the in-memory fallback. CLIENT.md's own trap 11 says this correctly ("silent in dev (auto-provisions)"); its §8 roadmap table drops the qualifier, and the table is the half a reader acts on. |

`models.md` §0.1 correctly flags its own `json_serializable` models as *a proposal, not
a description of what is built*. `docs/CLIENT.md` does not, and it is the more
confident-sounding of the two.

---

## The pattern

Four of the five entries are the same defect, and it is worth naming because it is not
about carelessness:

> **A claim about a number, written once, never re-checked.**

`try` blocks, importer counts, route counts, assertion counts. Each was correct when
written. Each rotted silently as features landed. Nothing failed, because prose cannot
fail a test.

The one that is genuinely a reasoning error — the `dartz`/`fp_dart` conflation — is
different in kind: it was a true statement about one package used to justify a decision
about another. No amount of re-measuring would have caught it, because the measurement
was never performed against the package being decided about.

That is why §5 of `AGENT_CONTEXT.md` carries the rule that an empty response is a fact
about a process and not a property of a system (decision 143). The same rule applies to
a comparison you did not run.

---

## 6. Whole-state writers are applied where the state is LARGEST

**This entry is a different kind from the five above.** Those are *factual* claims that
failed verification. This one is a **design** claim that fails on its own terms, with
every number in it already correct.

**NOT DECIDED. Recorded so the next change is a decision rather than a drift. Nothing
was reverted.**

### The audit

Six state classes exist. `lib/features/result/` has no bloc at all — `ResultPage` takes
`SubmitResult` as a constructor argument.

| State | Fields | `copyWith` | What it uses instead |
|---|---|---|---|
| `HomeState` | **13** | disabled `@Freezed(copyWith: false)` | 6 named `with*` writers, each restating all 13 fields |
| `AuthState` | **10** | disabled | 2 writers + a **hand-rolled** `copyWith` (`auth_bloc.dart:366`) |
| `QuizState` | **5** | disabled | inline full constructors, 11 sites |
| `LeaderboardState` | 4 | generated — **zero call sites** | inline full constructors, 3 sites |
| `ReadingState` | 4 | generated ✅ | `copyWith` |
| `SettingsState` | 3 | generated ✅ | `copyWith` |

**The correlation is the finding: `copyWith` is disabled on the three largest states and
kept on the three smallest.** A property whose benefit grows with reuse is being
withheld exactly where the state is big enough to hurt — which is backwards.

The repository states the cost itself: *"adding `leaderboardStatus` required **editing
every writer**"* (decision 141).

### Two cost signals that are not argument, only fact

* **`AuthState` hand-rolls a partial `copyWith`** (`auth_bloc.dart:366`) to get back part
  of what disabling it removed.
* **`LeaderboardState` has a generated `copyWith` that no call site reaches** — zero in
  `lib/`, zero in `test/`. The cubit builds all three of its states through the
  constructor. That is the pattern paying for a function nobody calls.

### THE TRADE-OFF IS REAL, AND IT IS NARROWER THAN PREVIOUSLY CLAIMED

**Correcting a claim made during the audit.** It was asserted here that freezed's
`copyWith` "cannot clear a nullable field". **That is false**, and the generated code is
the disproof — `settings_state.freezed.dart:71`:

```dart
call({Object? settings = null, Object? status = null, Object? failure = freezed,})
failure: freezed == failure ? _self.failure : failure
```

freezed gives every **nullable** field a `freezed` sentinel default, so `null` means
*"explicitly clear this"* and the sentinel means *"keep the current value"*. Non-nullable
fields default to `null`, which cannot express clearing because there is nothing to
clear. The mechanism is deliberate and it works.

**What `copyWith` genuinely cannot do is express a cross-field invariant.** One call site
can produce an inconsistent triple:

```dart
state.copyWith(readingStatus: HomeSectionStatus.failed, readingFailure: f)
// reading still holds the OLD value — status says "failed", payload says "ready"
```

`withReading` forces the caller to state all three, so the triple is always consistent:

```dart
state.withReading(status: failed, reading: null, failure: f)
```

So the honest statement is: **`HomeState`'s six writers are justified by an invariant a
generated `copyWith` structurally cannot express** — four independently-failing backend
endpoints, each a `status · payload · failure` triple that must stay mutually consistent.

**And that justification does not reach the other two states.** No cross-field invariant
is recorded for `QuizState` or `AuthState` anywhere in the repository. Decision 141
records the rationale for `HomeState`; there is no equivalent for the other two, and
`AuthState`'s hand-rolled `copyWith` is evidence that whoever wrote it felt the same.

### Why this is not fixed here

Three changes would each be defensible — re-enable `copyWith` on `QuizState` and
`AuthState`, delete `LeaderboardState`'s dead one, drop `AuthState`'s hand-rolled one —
and each needs its own decision and its own tests. Silently reverting a pattern that six
blocs and 2541 tests currently agree on is not a drift fix, it is a refactor.

### The transferable rule

> A rule that grows more expensive as the thing it governs grows should be re-examined
> every time the thing grows. The cost here was paid once, when the state was small,
> and then inherited by every feature that added a field.

This is the same shape as entries 1–5, one level up: a decision made for a
four-field state and never revisited once the state was thirteen fields.

---

## 7. `EvaChip` IS BUILT, GOLDEN-TESTED, AND NEVER PLACED ON A SCREEN

Found by `tool/gates/orphan_widget_check.py`, which is the defect decision 144
records and no gate was looking for:

> "`LeaderboardCard` was written, given a DI seam, a five-surface overflow matrix
> and a 21-test view suite — and **no page instantiated it**. ... Three suites, all
> green, all correct about their own subject, and together they could not tell
> whether the feature shipped."

**`EvaChip` is that, today.**

| | |
|---|---|
| Declared | `lib/core/design_system/widgets/eva_chip.dart` |
| Constructed in `lib/` | **nowhere** — the only match is its own constructor |
| Goldens | **8** (`eva_chip_{filter,static,toggle}_{dark,light}.png`, plus two state) |
| Listed in | `docs/plans/04-widget-inventory.md:29` as collapsing 11 prototype call sites |

The widget inventory says the mono-caps pill has **4 style definitions and 11
rendered** sites in the prototype — the `App.tsx` theme toggle, the per-route
chips, the `QuizScreen` frame toggle, the FAB dock items. None of those
destinations shipped, so the widget that was built to carry them has no caller.

**RESOLVED — DELETED.** Both of the prototype's real call sites were the passage
library, cut by decision 1 — the home screen's category-chip row and the chip inside
the prototype's passage card — and the other three pill styles were marked *"do not
port"* by defect #12 — so the widget had no caller left by construction, not by
oversight. **The redesign draws no chip at all**: its library is a carousel of
`.bcard`s (`redesign.html:275`) and a book's category is a caption on the card
(`redesign.html:1313`), so there was never a chip to port. Removed: the widget (448
lines), its own test suite, 8 goldens, and every reference to it. The design-system
barrel export is gone with it.

The three options were real and all were defensible:

* **place it** — the settings theme row uses `SegmentedControl`
  (`settings_page.dart:203`) rather than chips; that is a design choice, not an
  oversight;
* **delete it** — **taken**, along with the 8 goldens and their test surface;
* **allowlist it** — as a design-system primitive kept for prototype parity.

> **The first bullet's line reference is STALE, and Task 5.7 made it stale
> twice.** The theme row used a three-segment Light/Dark/System picker at
> `settings_page.dart:203`, and the redesign replaces it with the **Daylight
> toggle** (`eva/redesign.html:650`) — a two-state switch against a three-state
> field, with `AppThemeMode.system` becoming unreachable from the UI. The
> Workshop's segmented rows are the three *shape* controls, and they use
> `SegmentedControl(wide: true)`. **The bullet is a record of a counterfactual
> that never shipped, so it is left as it was and annotated rather than
> rewritten**: the history of the decision is the point of this file, and a
> reader who needs today's answer is looking at `settings_page.dart`.

Nothing is lost that any shipped screen could use. The doc comments that *named*
the widget were reworded, not deleted — they explain why a control is announceable
or colour-safe, and that reasoning outlives the class.

What is *not* acceptable is what the repository did for ten phases, which is
nothing: the widget was built, golden-tested, and every §7 gate stayed green.
`tool/gates/orphan_widget_check.py` now passes because the orphan is gone, not
because the check was softened.

### What building the gate found in the gate itself

Three bugs, all the same shape as decision 143's lesson — a check that reports
success while looking at nothing:

1. **A bare name match reports widgets as PLACED that are not.** This repository
   discusses `EvaChip` and `SegmentedControl` constantly in prose — design-system
   docs, `language_sheet.dart`'s "why not a SegmentedControl" reasoning,
   `leaderboard_page.dart` describing a window switcher it does not have. Comments
   are now stripped before matching; without that the gate missed the exact defect
   it was written for.
2. **A widget's own constructor declaration places itself.** `const
   SegmentedControl({...})` matches the name, so every widget placed itself and the
   gate reported zero orphans forever.
3. **`class Foo<T> extends StatefulWidget` matched nothing.** The pattern had no
   type-parameter clause, so every generic widget was silently skipped — which is
   how `SegmentedControl` was first reported as an orphan when it is on
   `/settings` today.
4. **A file that *mentioned* `@RoutePage()` became a root.** Phase 6 widened the
   root set from "files under `/presentation/pages/`" to that **or** "files that
   declare `@RoutePage()`", and the clause only asked whether the file *mentioned*
   the annotation. A plain class carrying it — not a widget, and its route the
   router had never heard of — made its file a root, and a widget merely **named**
   in that file was then reported as **placed**. Measured: a plain class with
   `@RoutePage()` on it, mentioning a widget, made the gate exit **0** with that
   widget on **no screen at all**. The clause now asks two mechanical questions
   instead — is the annotation on a **widget**, and is the route it declares
   **registered** in `lib/app/router/app_router.dart` — and the path heuristic is
   gone, because the root set is now derived rather than guessed.

The third was the dangerous one. A gate that quietly skips a class of declarations
is the same defect as one that cannot fail: both report a clean run over a surface
they never examined. The fourth was the same defect wearing a costume: the gate
reported a clean run over a surface — *is this file really a page?* — it never
examined, and the proof that was written down for it was the fool.

---

## 8. The Lumen plan's Phase 7 SAID THE PHASE WAS NOT DONE, AND IT WAS

`docs/superpowers/plans/2026-10-13-lumen-redesign.md`'s **Phase 7 — Ritual, locale,
close** carried **six unticked checkboxes** and **no recorded decisions** for well
over a week of committed work.

The ritual had shipped in `25a6798` — the selah timer, the focus dim, the vespers
auto-dim, the breath guide and the haptics, 3691 tests, 98.83% coverage, every gate
green including the Linux build. The tree said so. **The plan said the phase had not
started.**

### What was missing, and what it cost

This repository's rule is that a phase records its decisions in the plan — that is
where the Lumen phases keep them, and the plan's own Phase 5 and Phase 6 sections
are the worked example. So the five behaviours, their divergences and one real design
decision existed **only in a chat transcript**:

* the **five behaviours** and where their arithmetic lives — the four pure-Dart
  files (`core/domain/entities/selah_countdown.dart`, `core/domain/entities/vespers.dart`,
  `core/domain/entities/ritual_haptic.dart`, `features/reading/domain/breath_guide.dart`)
  and the one shared triangle (`core/common/cycle_phase.dart`);
* the **amber-darkening defect** — the vespers auto-dim made the ambient's *target*
  a function of the wall clock, which would have made the **sixteen background
  goldens** pass at 09:00 and fail at 22:00. The fix was an **injectable clock**
  (`NeuralMotionScope`'s `now`), and the harness pins it. **That is a design
  decision**, and it is the reason the goldens are comparable at all;
* the **divergences** — the haptics' rhythm lost to `HapticFeedback`'s four named
  impulses, the amen drawn in the card rather than as a toast, the card's gold
  snapping instead of transitioning, the selah's ring restarting its phase, and the
  breath guide resting under reduced motion where the prototype keeps breathing.

**The cost of the silence was not the writing.** It was that the next agent could not
learn any of it from the tree, and would have re-derived it — or, worse, shipped a
change that contradicted a decision nobody could find.

### RESOLVED — the plan's Phase 7 now records all of it

The six checkboxes are ticked against what actually shipped (Steps 3, 5 and 6), the
two that are still open say so, and the phase's decisions are written out with their
citations. `docs/agents/AGENT_CONTEXT.md` carries the three that are **invariants** a
sub-agent must not violate (the pure-Dart split, the injectable clock, the haptics'
mapping) and points at the plan for the rest — because AGENT_CONTEXT is the document
**injected into every sub-agent dispatch**, and a sub-agent that read only it would
have known nothing about the ritual.

### AND THE PLAN'S OWN **STEP 1 ESTIMATE** WAS STALE BY A FACTOR OF THREE

Step 1 says *"Port ~90 `I18N` keys (`eva/redesign.html:924-977`)"*. Measured against
the ARB pair: the prototype's table holds **128 rows** across 54 lines, and **103 of
them are already ported** under the client's own naming convention — `witness` →
`leaderboardWitness`, `cheerSent` → `leaderboardCheerSent`, `bmk` →
`readingBookmarkOn` / `readingBookmarkOff`, `libCount` → composed from
`homeScrolls` / `homeOpenBooks` and `digits()`. **Twenty-five** rows remain.

The estimate was made before Tasks 5.1–5.7 landed, and it was never revised as they
did. **A plan's scope number is a claim like any other**, and this one had quietly
stopped being true — in the direction that makes a plan look like there is four times
more work than there is.

---

## 9. THE ORPHAN GATE COULD NOT SEE A THIRD OF THE DESIGN SYSTEM

`tool/gates/orphan_widget_check.py` is the gate decision 144 built, and its
module doc says what it is for:

> "The question this answers is not 'is this widget tested' — it is **'does any
> page's tree contain it'**, which is the only question none of those suites
> asked."

**And the gate's own inventory meant it could not ask it about a third of the
design system.** The inventory was built like this:

```python
for p in files:
    if "/widgets/" not in p.as_posix():
        continue
```

so a widget under `core/design_system/effects/`, `.../motion/` or
`.../tokens/` was **not in the set the gate reasoned about at all** — not
reported and passed over, but *invisible*. And the design system has three
directories outside `*/widgets/`:

| widget | directory | exported | test suite | call site in `lib/` |
| --- | --- | --- | --- | --- |
| `GoldFlecks` | `core/design_system/effects/` | yes | full | **none** |
| `EvaAnimate` | `core/design_system/motion/` | yes | full | **none** |
| `EvaTypeScale` | `core/design_system/tokens/` | yes | full | **none** |

**That is decision 144's exact shape, and the gate could not see it.** Three
widgets, built, exported, fully tested, and on **no screen at all** — while
every §7 gate stayed green, because the gate that existed for that defect was
looking in the wrong place.

### THE SAME DEFECT, FOR THE SECOND TIME

`docs/DRIFT.md` §7 records `EvaChip`, and §7's fourth bullet records the
`@RoutePage()` fool. This is the third instance of one shape, and the shape is
the repository's own:

> **A gate that quietly skips a class of declarations is the same defect as one
> that cannot fail.**

The failure is *quieter* than a broken pattern, which is what makes it
survive: a pattern that stops matching reports **zero** matches, and zero
matches is the **good** outcome of a scan. A path filter that excludes a
directory reports the same zero, and nobody asks which directory.

### RESOLVED — THE INVENTORY IS ALL OF `lib/`, AND THE GATE'S ROOTS GREW

The inventory is now **every widget class under `lib/`** (generated files still
excluded), and the `DECL` pattern still excludes value classes, painters and
enums. The measurement: **71 → 87 widget classes**.

**Widening the inventory needed a second answer, and that is the part worth
recording.** The roots used to be the registered pages, and the widening
reaches the classes **above** them — `EvangelionApp`, `NeuralMotionScope`,
`SettingsScope` — which **no page constructs** and which would therefore read
as orphans. The answer is structural rather than an exemption: **the app root
is a second root**, derived by content the way the router is derived, and a
root is placed by definition.

**The router's path was a literal, and it is now derived.** auto_route's own
marker for "this is the app's router" is `@AutoRouterConfig()`, so the router
is the unique file under `lib/` that declares it, and a rename cannot break
the clause. **Zero matches and more than one are both FATAL (exit 2)** — never
a silent pass — because "this page is not registered" and "the router moved"
must not be the same answer.

**And a bogus `@RoutePage()` is now a FAILURE.** It used to print `NOT A ROOT`
and **exit 0**, which is a gate that reports a defect and cannot fail. It
exits 1 now, and the diagnostic text is kept, because the text is the receipt.

### AND THE THREE ORPHANS WERE **PLACED**, NOT ALLOWLISTED

The plan's risk table says *"place it or delete it — never allowlist"*, and
that is what happened:

* `GoldFlecks` → the quiz's **correct** option card;
* `EvaAnimate` → the option card's **entrance**;
* `EvaTypeScale` → `MaterialApp.router.builder` — the site its own doc always
  named.

**The allowlist still holds two rows** (`HairlineDivider`, `TextLink`), both
with written reasons, and the gate's own STALE check proves they are still
genuinely unplaced. The risk table's *"has an empty allowlist"* was stale in
its fact and is corrected.

### The other four edges, and the negative controls

The blur budget did not strip `/* */` block comments — so a `/* GlassTier.blur */`
in a comment **spent the budget** — and its count and its direct-spelling check
used **two different definitions of "a site"**, so a hand-built
`ImageFiltered(ImageFilter.blur(10))` was caught by one and invisible to the
other. There is **one** definition now, and both halves read it.

`tool/verify_gates_selftest.sh` now runs **seventeen** negative controls and
reports *"every gate is proven able to fail"* — six for the orphan gate (a
green tree, a bogus page, an unregistered page, a renamed router, a missing
router, and an orphan outside `*/widgets/`) and three for the blur budget
(a block comment, a real site, and the one-definition case). **The blur budget
had none at all before**, which is the same defect in a different place.

---

## 10. THE SIXTEEN BACKGROUND GOLDENS PHOTOGRAPHED A DESIGN THAT DOES NOT SHIP

The ambient's only pixel-level regression net was
`test/core/design_system/effects/goldens/neural_background_*.png` — sixteen
images, eight screens × two themes.

**They were of the OLD design.** The golden group pumped
`NeuralBackground(variant: NeuralVariant.home)` — the old design's neural
orbs — and the file they are named after was `neural_background_test.dart`.
**The LUMEN shader, which is what the app actually paints, had no golden at
all.** `lumen_canvas_test.dart` asserts the shader's *mechanics* — the
uniforms, the slot layout, the allocation, the clock — and never its *pixels*.

### WHY THIS SURVIVED FOR PHASES

Because the goldens were **green**, and because they are a net under a
**fallback**: `NeuralBackground` only paints when the reader switches the
aurora off, when the shader fails to compile, or at the `low` tier. So the
sixteen images were a regression net for a path a reader reaches by flipping
one switch in the Workshop, and the path every reader actually sees — the
aurora — was **unphotographed**.

**That is the same shape as the other two gates' blind spots**, and it is the
one that is hardest to see, because a green golden suite is the *most*
reassuring thing a repository can show. A net under the wrong thing is
indistinguishable from a net.

### RESOLVED — THE ORBS ARE GONE, AND THE HOLE IS **NAMED** RATHER THAN CLOSED

The orbs' retirement removed the sixteen goldens with the thing they
photographed, and the ambient is now left with **no pixel net at all** — which
is not a regression, because it had none for the design that ships.

**The hole is the next thing to close**, and it is a real piece of work: the
shader's own goldens, with the capture harness re-checked against the plan's
recorded risk — `flutter test` ≠ Impeller, because the tests run Skia software
(`flutter_tester_device.dart:113`). The plan's risk table says the harness must
be re-checked whenever the capture path is touched, and this would be touching
it.

**A golden is a claim about a specific frame, and sixteen of them were a claim
about a frame nobody sees.**

---

## 11. §5's HEADER TABLE DESCRIBED A FALLBACK, AND THE DEPLOYED BACKEND IS NOT A FALLBACK

| | |
| --- | --- |
| **Claim** | `docs/agents/AGENT_CONTEXT.md` §5, identity-headers table — *"A **non-UUID** value such as `not-a-uuid` is accepted with **200** and echoed back as `user_id`"*, on the authority of the decision's own footnote: *"Verified live against `HEAD = 4a1c834` on 2026-10-03"*. |
| **Reality** | **Against the deployed backend it is a 500.** `https://evangelion-backend.vercel.app/api/v1/streak/summary` with `X-User-Id: not-a-uuid` answers `500 {"error":"Internal Server Error","message":"Failed to retrieve streak summary"}`. Measured 2026-10-20. |
| **Fixed?** | **Yes — 2026-10-20, in the same change that moved the client's default base URL** (ADR-0023). §5's table now carries the two answers side by side, and §5.1 is a new subsection listing every place the two backends disagree. |

### WHY IT WAS WRONG, AND IT IS NOT A TYPO

The claim was measured against the **local** backend, and it was **true there**.
The local backend's in-memory fallback stores the user id as a string and hands
it back, so a malformed id is accepted and echoed — the table's own words.

The deployed backend has a **Postgres**, where the id column is `uuid`. A
non-UUID is a cast error, so the request **500s**. Nothing about the API
changed; what changed is that the server behind the API has a data store that
enforces a type the fallback did not.

### THE SAME CAUSE, MEASURED THREE TIMES

This is the **third** claim in §5 that is true of the fallback and not of the
deployment, and all three have the same cause — *the deployed backend has a
database and the local one does not*:

| # | Claim | Local | Deployed |
| --- | --- | --- | --- |
| 1 | non-UUID `X-User-Id` | 200, echoed | **500** |
| 2 | a date with no scheduled reading | 200, a fabricated id | **404** |
| 3 | the seeded user's `current_streak` | 4 | **0** |

Number 2 is the one that bites: the local fallback **auto-provisions** a
reading for any date, so `/readings/today` never 404s there. The deployed
backend has one seeded row and 404s every other date — because
`daily_readings.scheduled_date` was written **once**, as `CURRENT_DATE`, on
2026-10-19, and `runSeeds()` is a CLI rather than a boot step. Nineteen
consecutive dates were probed; **2026-10-19 answers 200 and every other one
answers 404.**

### WHAT THE CLIENT DOES WITH IT

**Nothing, and that is the point.** The client's own `isValidUserId` check
rejects a non-UUID at composition time (`buildApiDio`), so the 500 was never
reachable from this client — and the check is now worth *more* than it was,
because it prevents a server fault rather than a mystery.

**But the check's own documentation gave the wrong reason**, and that is what
drifted. `identity_headers.dart` says the server "performs **no format
validation at all**: a malformed user id is not rejected, it is *accepted and
stored*". That sentence is now false of the backend the client actually
talks to. The check stands; the reason under it did not, and the reason is the
kind of thing a future reader copies into a new decision.

### THE LESSON, WHICH IS THE SAME ONE THIS FILE KEEPS REPEATING

**A claim about a backend is a claim about a backend, not about an API.** §5
was titled "verified facts, not guesses" and had been verified — against
*one* server, and the fact was a property of *that server's* fallback rather
than of the contract. Nineteen dates and four header shapes were not enough to
notice, because nothing about the *shape* changed. Only the *storage* did.

The same shape as §1's "six screens" and §10's sixteen goldens: **a green
check over a surface that was never examined.** §5 examined the local backend
thoroughly. It did not examine **the backend**, because at the time there was
one, and it was the fallback.

---

## 12. THE CITATION GATE NEVER CHECKED THE AUTHORITY DOCUMENT — AND THE
## PROTOTYPE IT CHECKED AGAINST WAS A DESIGN THE CLIENT HAD SUPERSEDED

`tool/gates/citation_check.py` resolves every `X.tsx:NNN` and
`redesign.html:NNN` claim in the tree. Its `ROOTS` were `("lib", "test", "tool")` —
**so it never looked at `docs/` at all**, and the authority document, the ADRs,
the plan, the drift catalogue and the seams map — **where the client's claims
actually live** — were checked by nothing.

**And 113 citations sat in those documents, unchecked, for the whole life of the
gate.**

### The other half: the reference it was checking against was **superseded**

`eva/src/` was the React prototype the Lumen redesign **replaces**. The gate
checked 554 citations into it, and **327 of them were live in `lib/`** — in claims
the shipped code makes about what it borrowed from the design it replaced. Those
were not stale: they were **divergence receipts**, and the plan's own Task 4.2
Step 4 says so — *"A citation that still describes a surviving widget is not
wrong; moving it would be churn."*

**But a line number in a file that does not exist is a fiction**, and the
prototype is gone. So the receipts had to be **rewritten by hand** — 237 distinct
targets across 554 sites — and the gate's pattern **still matches `.tsx`** on
purpose, so that a citation into the retired prototype is now a **broken**
citation, named.

### RESOLVED — the prototype is retired, the receipts are rewritten, and the gate
### watches the LIVE documents

`eva/` now holds **two** files: `redesign.html` and `brief.txt`. The gate
resolves against both, and its `ROOTS` now include the live documents.

**AND A GATE THAT WATCHES MORE SURFACES IS A STRONGER GATE, WHICH IS ALSO HOW
THIS REPOSITORY KEEPS BREAKING ITS OWN GATES.** The same shape, for the fourth
time: a gate that cannot fail; an inventory that hid a third of the design
system; a pattern that would have hidden a whole design; and now a scope that
never looked at the documents the claims are written in.

### The one hole this found: the brief's citations were checked by **nothing**

The brief's filename had a **hyphen** in it, and the gate's pattern matches
`[A-Za-z0-9_]+` — so `pasted-attachment.txt:97` **never matched the pattern at
all**, and its **eight line citations** were verified by nothing whatsoever.

**And they are the ones that matter most**: *"the ONLY sacred cues are: gold
flecks, the verse marker, and beautiful typography"* — the rule the gold flecks'
return rests on, and the reason the quiz's correct option has four tiny gold
dots on it today.

Moving the brief to `brief.txt` and matching the **named references** (rather
than a generic `.txt` extension, which turned every `CMakeLists.txt:25` in the
tree into a broken citation) closed the hole. **The brief is now the gate's
second reference, and its lines are checked.**

---

## 13. THE COVERAGE FLOOR WAS A NUMBER NO RUN PRODUCED — AND THE ROADMAP SAID
## THE REPOSITORY HAD NO CI AT ALL

Two claims, both in live documents, both wrong, and both the kind of wrongness
that only shows up when a machine other than the author's checks them.

### The floor: `98.85` was never measured

`tool/baseline/gates.txt` recorded `coverage_pct 98.85`. **No run ever measured
that.** The suite measured `8501/8601` — **98.8373 %** — on the CI runner, and
`8503/8601` — 98.8606 % — locally. The floor sat **between the two**, and it
passed only because gate 7 compared a **ROUNDED** percentage: `98.84` rounded
up to two places is `98.85`, which equals the floor, which passes.

**So a floor that no run produced was enforced by a rounding step that no
document mentioned.** The gate was not measuring the number it claimed to
measure, and the reason it was not wrong is a coincidence of arithmetic.

### And the measurement is a SAMPLE, not a sum

`flutter test --coverage` collects from **one isolate per isolate group**
(`package:coverage` 1.15.1's `coveredIsolateGroups`) — the VM shares program
counters between the isolates of a group, so collecting from all of them would
count every hit twice. **A `const` constructor is not a program counter**:
materialising a canonical constant is a *per-isolate* event, so the line that
records a materialisation is reported as covered or **not** depending on which
isolate the collector happened to sample.

**Measured, on one tree, one line** (`eva_motion.dart:1046`, the
`const EvaShake();` declaration):

| Where | The line's count |
| --- | --- |
| 16-core machine, default concurrency | 4 |
| the same tree, `--concurrency=2` | 2 |
| the CI runner | **0** |

**That single line was the whole of the difference** between the runner's
`8501/8601` and the local `8503/8601`, and it is why the runner measured
98.84 % against a floor of 98.85 % for **three consecutive runs**.

### And the floor WIDENED ITSELF as the code grew

A percentage floor is a function of the denominator. 98.85 % is 99 uncovered
lines out of 8601 and **100** out of 8701 — so adding a hundred *covered* lines
silently admitted one more uncovered line, without anybody deciding to admit
it. A floor that widens itself is not a floor.

### RESOLVED — the floor is a BUDGET OF UNCOVERED LINES, and it is compared exactly

`tool/baseline/gates.txt` now records `uncovered_lines 99` and gate 7 compares
`uncovered <= 99` — an integer, with no rounding, that does not move when the
code grows. The percentage is still recorded, because it is the number a human
reads, and it is still printed; it is a **rendering of the budget at the tree's
current size**, not the budget.

**AND THE REAL GAP WAS CLOSED RATHER THAN TOLERATED.** `EvaShake` — the design
system's own shake curve, used by `/login`'s `.cta.err` and the quiz's
`.opt.wrong` — **had no test of its own**: it was covered only incidentally, by
whichever test happened to build one of those two screens and run the
animation, and nothing asserted a single number about it. AGENT_CONTEXT §6
requires red-first for motion tables. It has a test now, and the tree's
measurement no longer depends on which isolate the collector sampled.

### The other claim: the ROADMAP said there is no CI

`ROADMAP.md` carried a row reading *"Continuous integration | no workflow files
exist"*, and a paragraph under it explaining at length that there is **no**
`.github/workflows/` directory, that no workflow runs any of the gates, and that
"a green state is a property of that person's discipline rather than of the
repository".

**`.github/workflows/ci.yml` landed on 2026-10-12** (`198ff74`, *"ci: run the
seven gates on every push and pull request"*) — **one day after** the ROADMAP
row was written on 2026-10-11 (`b020a72`). So the row was **true when it was
written**, it stopped being true the next day, and nobody re-measured it in the
nine days since. That is the same failure as every other entry in this file: a
claim written down once and then believed, and a claim about a *measurement* is
not a claim about an intention.

It is corrected, and the CI now runs **all eight gates** in three jobs, with
the runner image, the Flutter version and every action **pinned** — because a
coverage floor and a golden PNG are only meaningful against a fixed
toolchain, and `ubuntu-latest` had already begun migrating to Ubuntu 26.

---

## 14. TWO CLAIMS ABOUT THE AMBIENT LAYER WERE WRONG, AND ONE COMMENT
## DESCRIBED A DIM THE BUILD DOES NOT APPLY

Three claims about the app's own code, checked against the source on
2026-10-20 while measuring the rebuild boundary. None of them was a *number*,
which is why none of them was caught: they were claims about **what the code
does**, written in prose, and the code was never executed to check them.

### 14.1 "A keyboard opening triggers a shader repaint"

**The claim**, in the course of the performance work: `LumenBackground`'s
`didChangeDependencies` calls `scene.retarget(...)`, which calls
`notifyListeners()` — so **any** inherited dependency change would repaint the
aurora, and a soft keyboard changes `MediaQuery`.

**The reality.** `MediaQuery` is an `InheritedModel<_MediaQueryAspect>`, and
the code reads `MediaQuery.sizeOf(context)` and
`MediaQuery.disableAnimationsOf(context)` — **aspect-scoped** reads. A
keyboard changes `viewInsets` and `padding`; it does not change `size` or
`disableAnimations`, so `didChangeDependencies` **does not fire**.

And `LumenScene.retarget` (`lumen_scene.dart:352-396`) **early-returns**
when the preferences, the brightness and the shafts allowance are all
unchanged — so even when it *does* fire, it does not notify.

**All twelve `didChangeDependencies` sites in `lib/` are guarded, latched, or
aspect-scoped.** This seam is the best-implemented in the codebase, and the
claim had it backwards. `lumen_background.dart` is left alone.

### 14.2 "One verse's hot glow damages the whole list"

**The claim:** the reading page's verse list has no `RepaintBoundary`, so a
repainting verse's glow would re-record the whole list's display list.

**The reality.** `ListView.builder` defaults `addRepaintBoundaries: true`, and
`SliverChildBuilderDelegate.build` wraps each item in a `RepaintBoundary`. So
**each verse already has its own**, and one verse's glow does not reach its
siblings. The claim was wrong, and no boundary was added — because there was
nothing to add.

**AND THE TRUE COST OF THE LIST WAS ELSEWHERE**: the problem was not a
repaint reaching too far, it was a **rebuild** reaching too far. A tap
rebuilt **211** widgets — the sky, the scaffold, the app bar and every visible
verse. See `docs/PERFORMANCE.md` §2.

### 14.3 "The CTA and the pill carry `chromeDimOpacity` from the same constant"

**The claim**, in `reading_page.dart:676-677`: *"**Only the bars are dimmed
here**, which is faithful to `:176` … and is also the whole of the correction:
the CTA and the pill carry [chromeDimOpacity] from the same constant."*

**The reality.** `chromeDimOpacity` is referenced at **exactly one place** —
`reading_page.dart:687`, the app bar's `AnimatedOpacity`. A search over
`lib/` returns two hits: the constant's own declaration and that one use.

**So the comment describes a dim the build does not apply** — and the sentence
that follows it, "**and `VerseLine`'s three-state enum is what makes 'the
verses are not dimmed' expressible rather than accidental**", attributes the
correction to a mechanism that is not there.

**Not fixed here**, because the code is right and the comment is wrong, and
rewriting a comment that says the code does something it does not is a
**behaviour** question for whoever owns the reader's focus mode. Recorded
here so the next reader does not take the comment's word for the code's.

---

## 9. The servant portal (2026-10-21) — four route counts, and one resume mechanism

**Decision 5 was reversed** — AGENT_CONTEXT §2 now reads "**The servant/admin
portal ships**" (ADR-0026) — and the route table gained four rows. **Four
documents still describe the tree as it was before that**, and one of them is a
count a reader would take at face value.

### 9.1 `docs/SEAMS.md` — "**9 entries in `AppRouter.routes`**" and "**9 constants**"

**The claim**, at `docs/SEAMS.md:206-209`: *"**9 entries in `AppRouter.routes`**:
the guarded dock shell at `/` with its three tab children, `/login`, `/reading`,
`/quiz`, `/settings`, and a `RedirectRoute` for `*`."* and *"**9 constants**
exist in `app_routes.dart` (the seven screens, `/servant`, and the `*`
fallback); `/servant` is declared deliberately unrouted."*

**The reality.** `AppRouter.routes` carries **twelve** routes plus the wildcard.
`tool/route_check.dart` prints "12 route declaration(s), all plain string
literals", and `test/core/navigation/app_routes_test.dart` now asserts twelve
names.

**The second half of the claim is the one that rotted hardest**: *"`/servant` is
declared deliberately unrouted"* described a **placeholder state** that the
2026-10-21 change removed. It was true when written — `app_routes.dart`'s own
paragraph said so, and the same file said the successor that registers the
route "replaces this paragraph". **It has been replaced, and the replacement is
in the file.**

**Fixed — 2026-10-22.** `docs/SEAMS.md` now says **13 entries** in
`AppRouter.routes` (twelve `AutoRoute`s and the `RedirectRoute`) and **12
constants**, names the portal's four, and says they **are** routed.

### 9.2 `docs/ARCHITECTURE.md` — "**declares 9 route constants** … `/servant`, which is deliberately declared but not routed"

**The claim**, at `docs/ARCHITECTURE.md:350-353`: *"`app_routes.dart` declares
**9** route constants — the seven screens, plus `/servant`, which is
deliberately declared but not routed, plus the `*` fallback. Gate 4 verifies
all nine are plain string literals."*

**The reality.** **Twelve** constants, all plain string literals, and
`/servant` **is** routed — with three siblings. The sentence "Gate 4 verifies
all nine" is now "all twelve", and the phrase "deliberately declared but not
routed" is the drift's whole content: it described a deliberate choice that has
been reversed.

**Fixed — 2026-10-22.** `docs/ARCHITECTURE.md` now says **12** route constants,
names the portal's four, and says they are routed.

### 9.3 `README.md` and `CONTRIBUTING.md` — "**Seven screens**"

**The claim**, at `README.md:12`: *"Seven screens, a dark glassmorphic design
system, and a verification regime built around the idea that **a gate which
cannot fail is worse than no gate**."* and, at `CONTRIBUTING.md:67`: *"Four of
the seven screens read live data."*

**The reality.** There are still **seven screens in the reader's app** — that
part did not change, and the phrase is true of the reader. What changed is that
there is now a **second surface** with **four more routes**, and a document
that says "seven screens" without saying *whose* screens will read as a claim
about the whole app.

**Recorded rather than rewritten here**, because these are the two documents a
new reader opens first, and the fix is a wording question about what the
product is called — not a mechanical one. The route table in AGENT_CONTEXT §2
is the authority, and it now carries both surfaces and says so.

### 9.4 `lib/app/router/auth_guard.dart` — "**the resume is carried by the `ReevaluateListenable`**"

**The claim**, at `lib/app/router/auth_guard.dart:158` and again at `:214-220`:
*"The accurate statement is that the resume is carried by the
`ReevaluateListenable` — `navigation_injection.dart` wires it to the bloc's
stream precisely so a sign-out and a sign-in both re-run this guard"* and *"It
is carried by the `ReevaluateListenable`: the bloc emits `signedIn`, the router
re-runs this guard over the stack, and `decide()` now returns `allow`, which
resolves the *pending* navigation. Measured on a cold launch: the stack goes
`[LoginRoute]` → `[]` → `[HomeRoute]`."*

**The reality, measured on 2026-10-21 with two probes over the real router.**
**There are TWO mechanisms, they are not interchangeable, and they land the
reader on DIFFERENT screens.** The file's comment names the second and calls it
"the resume"; the first is the resume of the **interrupted** navigation, and
the two are not the same thing.

Both probes pushed `/reading` while signed out, so the `AuthGuard` redirected
to `/login` and the stack was **`[LoginRoute, LoginRoute]`** — the app's entry
route, and the redirect's, the second carrying the resumable `onResult`.

| probe | what was done | the stack afterwards |
| --- | --- | --- |
| **1** — the listenable **inert** (a `ReevaluateListenable` that never notifies) | `onResult(LoginOutcome.signedIn)` | **`[LoginRoute, ReadingRoute]`** — the **interrupted** navigation was resumed |
| **2** — the listenable **fires** (the status flips to authenticated, the signal notifies) and the `onResult` is **not** called | the listenable alone | **`[LoginRoute, DockShellRoute]`** — the app's **default** route; the interrupted `/reading` was **not** resumed |

**So the two paths are not the same path.** The `onResult` callback resumes the
screen the reader was trying to reach; the re-evaluation lands them on the app's
default route, because the guard's redirect had already consumed the pending
navigation.

**And the comment's own measurement is a cold launch** — `[LoginRoute]` →
`[]` → `[HomeRoute]` — which has **no interrupted navigation to resume** at
all. A cold launch is the case where the two mechanisms agree, which is why the
distinction was not visible from it.

**What this cost, and why it is not only a doc entry.** The portal's landing is
issued from the sign-in listener, and with the `onResult` path still live the
landing was pushed **on top of** the resumed route: measured
`[DockShellRoute, ServantHomeRoute]`, and `[DockShellRoute, DockShellRoute]` for
a kid — **two copies of the reader's own screen**. The landing is therefore
deferred to the end of the next frame, where the removal takes the **guard's**
route: measured `[ServantHomeRoute]`. See AGENT_CONTEXT's recorded decision
185.

**The correction is two sentences in `auth_guard.dart`**, and the file is not
this entry's to rewrite: the **resume of an interrupted navigation** is carried
by the **`onResult` callback**; the `ReevaluateListenable` carries the
**re-evaluation on a session change**, which lands the reader on the app's
default route rather than on the screen they were heading for.

---

## 15. `PERFORMANCE.md` §3 — "the aurora … repaints on **every vsync**"

> **The five entries below (15–19) cite `docs/PERFORMANCE.md` by the line
> numbers it had BEFORE the 2026-10-22 corrections landed.** The corrections are
> what these entries record, so the file has moved since and the cited lines
> now point at the annotated text rather than at the claim.
>
> **AND TWO OF THEM NOW QUOTE `lib/` AND `test/` LINES THAT HAVE ALSO MOVED.**
> The dock's ripple was **changed** after entry 16 was written (§5.1), and the
> budget test was **changed** after entry 17 was written, so
> `lumen_dock.dart`'s `:875`/`:895` and `rebuild_isolation_budget_test.dart`'s
> `:308` no longer say what they said when they were written. **Each of those
> two entries carries its own dated annotation**, and that is the right shape:
> a line number in an entry of this file is a record of a **past state of the
> tree**, and a record of a past state is what an entry here is. **The
> annotations carry the current numbers.**

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md:100-102` — "**None of the above touches the GPU.** The aurora is a full-screen fragment shader that repaints on **every vsync** at **device** resolution, and its cost budget is counted in **logical** pixels." |
| **Reality** | **The aurora does not repaint on every vsync.** `AmbientTickBudget` caps its **paint** at **30 Hz** (`lib/core/design_system/effects/ambient_tick_budget.dart:77`), and `LumenScene` consults that gate **before** it notifies (`lib/core/design_system/effects/lumen_scene.dart:491-493`, the gate built at `:497`). The aurora's painter is repainted by that notifier (`lib/core/design_system/effects/lumen_canvas.dart:108`). So it repaints **thirty** times a second, not sixty or a hundred and twenty |
| **Fixed?** | **Yes — 2026-10-22.** The sentence is **annotated in place** rather than rewritten, and the annotation says what the gate is and where it lives |

**This one is a document that contradicted ITSELF, and that is what made it
worth an entry.** The same file's **§3.2** — twenty lines further down, at
`docs/PERFORMANCE.md:122` before the correction — is headed *"What the tick
budget already did — **LANDED**"* and records the 30 Hz paint cap and the 20 Hz
notification cap as shipped. So the file said the aurora repainted on every
vsync **and** said it repainted thirty times a second, and the only thing that
separated the two was which half of the document a reader happened to be
looking at.

**The claim was written before ADR-0025 landed and was never revisited when it
did.** That is this file's own pattern — the "**The pattern**" section's "a
claim about a number, written once, never re-checked" — except that here the
number was not the stale part. **The sentence had no number in it at all**: it was a claim about
*what the code does*, in prose, and prose cannot fail a test. §14 of this file
records the same shape three times over, in the app's own code.

**AND THE SECOND HALF OF THE SENTENCE IS STILL TRUE.** "…at **device**
resolution, and its cost budget is counted in **logical** pixels" — that half
was never wrong, and it is the subject of §3.1.

---

## 16. `PERFORMANCE.md` §3.2 — "the CTA's bead and its ripple ring", read as the list

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md:132-133` — "The witness sky's **forty-four stars** rebuild **three times less often**, and so do the gold flecks, the CTA's bead and its ripple ring." |
| **Reality** | **The four consumers it names are the right four** — the repository names them itself at `lib/core/design_system/effects/neural_motion.dart:101-106`, and all four do read the **gated** notifier `motion.repaint` (`lib/core/design_system/effects/neural_motion.dart:232`, gated at `:165-166` by the 20 Hz `notifyGate` at `:177`). **But the sentence reads as a complete inventory of ripple rings, and it is not.** Three more rings animate and **never consult the budget**: the dock's orb ripple (`lib/features/dock/presentation/widgets/lumen_dock.dart:875` and `:895` — `super(repaint: clock)` on the **raw** `TickedLumenClock`, whose `_onTick` notifies on every tick at `lib/core/design_system/effects/lumen_clock.dart:302-305`), the selah card's breathing ring (`lib/features/home/presentation/widgets/selah_card.dart:579` and `:595` — the file's own comment at `:536-539` says "**the §13.2 budget is not engaged**"), and the reader's breath guide (`lib/features/reading/presentation/widgets/breath_guide_line.dart:76`) |
| **Fixed?** | **Yes — 2026-10-22.** The bullet is **annotated in place** with the three that were missing, and a **new §5** ("The per-vsync cost the tick budget does not cover") says what each of them costs |

**The shape of the mistake is the same as entry 15's and it is worth naming
separately.** Entry 15 was a claim about a number; this one is a claim about a
**set**, and a set claim that omits three members is indistinguishable from a
set claim that is complete — **unless somebody counts**. Nothing counted. The
sentence was written as a *summary* of what ADR-0025 covered, and it stayed a
summary after three more rings had landed outside the budget.

**The interesting part is that the file itself knew.** `selah_card.dart`'s own
doc comment says the budget "is not engaged" — the code documented its own
exemption, and the document that was supposed to be the index of the budget
never picked it up. **A document that indexes a mechanism has to be re-read
when the mechanism's consumers change**, and there was no re-read.

> **ANNOTATED 2026-10-22 — ONE OF THE THREE HAS SINCE MOVED ONTO THE BUDGET,
> AND ITS LINE NUMBERS HAVE MOVED WITH IT.** The dock's orb ripple was the
> first of the three named here, and the fix that moved it onto the ambient's
> gated notifier has landed: the painter now takes `motion` and does
> `super(repaint: motion.repaint)`
> (`lib/features/dock/presentation/widgets/lumen_dock.dart:976`; the painter
> is built at `:925`), and the ripple carries a `RepaintBoundary` **of its
> own** (`lumen_dock.dart:900`). **The `lumen_dock.dart:875` and `:895` this
> entry quotes are the pre-fix lines** — they held `clock: motion.lumen` and
> `super(repaint: clock)` then, and they hold something else now.
> **§5.1** carries the current state and the measurement; the painter's
> repaint requests fell from **30 in 30 frames** to **10 in 30 frames**.
> **The other two still animate outside the ambient's budget** — the selah
> card's ring (`selah_card.dart:579` and `:595`) and the reader's breath guide
> (`breath_guide_line.dart:76`). **But the ring's *other* defect is closed**:
> a per-tab `TickerMode` now mutes it when its tab is inactive
> (`lib/core/design_system/widgets/eva_tab_ticker_gate.dart:154-157`), and
> **§5.2** carries that. **The breath guide's gate is still open** (§5.4) —
> and §5.4 now says why the ticker census cannot be it.

---

## 17. `PERFORMANCE.md` §4 — "`EvaTypography.textTheme` … two call sites"

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md:173` — "**The `TextTheme` is rebuilt per verse** \| `eva_typography.dart:138-166` — `_geometry.apply(...)` plus a **fourteen-field** `copyWith`, about **30 `TextStyle` allocations per call**; `verse_line.dart:357` and `:419` call it **twice per visible verse**, and `eva_theme.dart:59` **already builds the same `TextTheme` once** into the `ThemeData` \| ~**15 µs** per call, ~**30 µs** per verse build \| none: the theme's `TextTheme` is the Eva one, so reading it is a de-duplication \|" |
| **Reality** | **There are TWELVE feature call sites, not two.** `rg 'EvaTypography\.textTheme' lib` returns **13** hits, one of which is the theme's own (`lib/core/design_system/theme/eva_theme.dart:59`) — so **twelve** in features: `verse_line.dart:357` and `:419`, `reading_app_bar.dart:225` and `:355`, `reading_quiz_cta.dart:165` and `:184`, `reading_pill.dart:341`, `greeting_block.dart:120`, `library_carousel.dart:378`, `streak_chip.dart:169`, `journey_hero_number.dart:113`, `journey_identity.dart:60`. **And the `copyWith` has FIFTEEN fields, not fourteen** (`lib/core/design_system/tokens/eva_typography.dart:148-166` — `displayLarge`…`labelSmall`, one per Material slot). **And the "~15 µs per call" is a number the test PRINTS, not one it asserts**: the only assertion is `expect(perCall, greaterThan(0), reason: 'the measurement must have run.')` (`test/rebuild_isolation_budget_test.dart:308`), which **cannot fail**, because a clock that ran is greater than zero |
| **Fixed?** | **Yes — 2026-10-22.** The row is corrected in place, a **new §6.4** carries the twelve sites in a table with their `file:line`, and the row now says the per-call figure is a **printout** rather than a budget |

**Two failures in one row, and they are different in kind.** The **count** was
wrong because the row was written from the reader's memory of the code rather
than from a scan of it — and the honest fix is mechanical: `rg` answers the
question, and the answer is **twelve**. The **assertion** was weak because it
was written to prove the *instrument* ran rather than to bound the *cost*,
which is the shape §13 of this file has hit repeatedly: a check that reports
success while looking at nothing.

**And the row's own recommendation was already half-built.** It said the fix
is to read the theme's `TextTheme` instead of recomputing it — and the theme
already holds exactly that object (`eva_theme.dart:59`, installed at `:85`).
The fix was correct; **the inventory of what it applies to was ten call sites
short**, and a de-duplication is worth exactly as much as the callsites it
replaces.

> **ANNOTATED 2026-10-22 — THE COUNT IN THIS ENTRY IS ITSELF AN UNDERCOUNT,
> AND ONE OF ITS LINE NUMBERS HAS MOVED.** **Twelve** was right about the
> *qualified* sites and wrong about the total: **three more** call
> `textTheme(colors)` **unqualified**, from inside `EvaTypography` itself
> (`lib/core/design_system/tokens/eva_typography.dart:179`, `:188`, `:198`),
> and each rebuilds a whole `TextTheme`. **The real total is sixteen**, and
> **§21** is the entry that records it. **And** the assertion this entry quotes
> at `test/rebuild_isolation_budget_test.dart:308` is now at **`:328`** — the
> file moved — and it still reads
> `expect(perCall, greaterThan(0), reason: 'the measurement must have run.')`,
> which **cannot fail**. What has changed is that the **count** is now gated at
> all: `test/text_theme_callsite_test.dart` scans `lib/` for every
> `textTheme(` call site, qualified and unqualified, and requires each to be
> on a reviewed allowlist of **sixteen** sites across **eleven** files.

---

## 18. `PERFORMANCE.md` §4 — "`_verseKeys.clear()` … every visible verse is deactivated and re-mounted"

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md:175` — "**A `GlobalKey` per verse, cleared during the build** \| `reading_page.dart` — `_verseKeys.clear()` runs inside the builder, so the next build mints **new** keys and every visible verse is **deactivated and re-mounted** \| a `ValueKey<int>(verse.number)` would make the row an *update* rather than a teardown \| none visible \|" |
| **Reality** | **The claim is REFUTED. The problem does not exist.** The clear is **not** run on every build: it sits inside `if (passage != null && _entranceFor != passage.readingId)` (`lib/features/reading/presentation/pages/reading_page.dart:725`) — it runs **once per passage**, keyed on the reading id, not once per build. A verse's key is minted **once** and cached (`reading_page.dart:987-990`, `_verseKeys.putIfAbsent(verse.number, GlobalKey.new)`), so the keys are **stable across rebuilds** and the rows are **updated**, not remounted. **And the proposed fix would BREAK something**: `_onScroll` needs `entry.value.currentContext` (`reading_page.dart:505-509`) to find a verse's box, and a `ValueKey` has **no `currentContext`** — so the "fix" would have removed the star-recording mechanism the `GlobalKey` exists for |
| **Fixed?** | **Yes — 2026-10-22.** The row is **corrected in place**: the problem is stated as not existing, the actual mechanism (gated on a new passage id) is given with its `file:line`, and the proposed `ValueKey` replacement is recorded as **breaking** star recording rather than as a free win |

**This is the entry that matters most, and it is the one whose "fix" would
have cost more than the bug.** The claim described a teardown-and-remount on
every rebuild; the fix it proposed was to replace a `GlobalKey` with a
`ValueKey`. **Both the claim and the fix were wrong**, and in opposite
directions: there was no teardown to fix, and the "fix" would have removed the
one thing the `GlobalKey` is for.

**The shape is the "**The pattern**" section's, one level down.** A claim
about a number, written once, never re-checked — except that **there was no
number here at all**. It
was a claim about *what a piece of code does*, made without reading the code
around it: the reader saw `_verseKeys.clear()` **inside a `build` method** and
inferred "on every build", and the `if` three lines above the clear — the one
that gates it on a **new passage** — was not read. **A `clear()` is not a
statement about frequency; the guard around it is.** The same file's §14
records three claims about the app's own code that failed for exactly this
reason.

---

## 19. `PERFORMANCE.md` §4 — "`/communion` builds all fifty rows eagerly"

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md:177` — "**`/communion` builds all fifty rows eagerly** \| `communion_page.dart:154` — a non-lazy `SingleChildScrollView`, and §13 rule 5 says *\"never `Column` + `map` over unbounded data\"* \| the board stops building fifty rows to show twelve \| none visible \|" |
| **Reality** | **Every number in it is wrong, and so is the line number.** The eager loop is `lib/features/leaderboard/presentation/pages/communion_page.dart:405-419`; **`:154` is `Widget build(BuildContext context) {`**. The scroll view is `lib/core/design_system/widgets/neural_scaffold.dart:408` — and the page passes `scrollable: true` (`communion_page.dart:172`), which is *why* the scaffold owns the scroll view rather than the page. The cap is **47 rows**, not fifty: the server's limit is 50 (`lib/features/leaderboard/presentation/bloc/leaderboard_cubit.dart:127`) and the board skips the three podium rows (`communion_page.dart:376`, `sorted.skip(3).toList()`). The **deployed cohort is 3** (`docs/BACKEND-VERIFICATION.md:199`). And **"twelve" is a test fixture**, not a product fact: `test/features/leaderboard/presentation/communion_page_test.dart:111` — "twelve rows is nine more than the podium takes" — with `cohortSize: 12` at `:220` |
| **Fixed?** | **Yes — 2026-10-22.** The row is **corrected in place** with the loop's real `file:line`, the real scroll view, the real cap (**47**), the real deployed cohort (**3**) and the fixture's true origin — and a **new §6.2** carries the cost, the per-row entrance (up to **2,450 ms** for the last row) and the fact that the rows carry **no keys** |

**This row had a number in it that was a number about a FIXTURE.** "The board
stops building fifty rows to show twelve" reads as an observation of the
product — fifty rows built, twelve shown — and **twelve is the number of rows
in a test fixture**. The product's cohort is **three** rows
(`docs/BACKEND-VERIFICATION.md:199`), and the board's cap is **47**. The
sentence's shape, "builds N to show M", is exactly the shape a **test's**
expectation takes, and the test's number was reported as the product's.

**And the line number pointed at the wrong line of the right file.** `:154` is
the `build` method — a line that *is* in the page, and that says nothing about
eagerness. The eager loop is 251 lines further down. **A citation that
resolves is not a citation that is right**, which is what
`tool/gates/citation_check.py` says about itself: it checks existence and
range, "**not** that the line still says what the comment claims".

---

## 20. `PERFORMANCE.md` §2.2 — "44 composited `Opacity` layers"

> **This entry cites `docs/PERFORMANCE.md` and
> `test/rebuild_isolation_budget_test.dart` by the line numbers they had
> BEFORE the 2026-10-22 correction landed** — the correction is what this
> entry records, so the files have moved since. Every other `file:line` in it
> is current.

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md:88-90` (before the correction) — "**The sky is the single most expensive thing on the screen** — 44 stars × 5 widgets, 44 composited `Opacity` layers, 88 shadow blurs — and it had nothing to do with which verse was selected." The same sentence was repeated in the gate's own failure message, `test/rebuild_isolation_budget_test.dart:120-121` — "It is 44 stars × 5 widgets plus 44 `Opacity` layers and 88 shadow blurs" — and in `docs/PERFORMANCE.md:346` (§6.1's row) and `docs/PERFORMANCE.md:172-173` (§3.2's bullet) |
| **Reality** | **The 44 is `UserSettings.starCount` — a CAP on how many stars the sky may hold, not a MOUNTED count.** The default literal is at `lib/core/domain/entities/user_settings.dart:164` (the field at `:370`), and it reaches the sky through the cap seam — `lib/app/di/navigation_injection.dart:308` reads `getIt<SettingsHandle>().settings.starCount`. `WitnessSky` draws **one star per LIT entry** (`lib/core/design_system/widgets/witness_sky.dart:981` — `for (final SkyEntry entry in entries) _star(entry)`), and a reader who has just opened the app has lit **none**. **Measured**, by `flutter test test/layer_census_test.dart`: `/reading` mounts **6** `OpacityLayer`s at rest, and lighting **all 44** stars adds **exactly 44** more, for **738.77** logical px² (3,456,994.77 − 3,456,256.0) |
| **Fixed?** | **Yes — 2026-10-22.** §2.2's sentence is **annotated in place** with the cap, the measured figures and the arithmetic; §3.2's bullet and §6.1's row carry the same correction; the gate's `reason:` string now says what the 44 is; and a **new §8** carries the whole census, measured |

**THE NUMBER WAS NEVER WRONG — IT WAS THE WRONG **KIND** OF NUMBER, and that is
the whole shape of this entry.** The source's own statement is correct and
still stands: `lib/core/design_system/effects/neural_motion.dart:104-105` says
the sky's stars carry "**forty-four composited `Opacity` layers** and
**eighty-eight shadow blurs**". The census **confirms the layer half of it** —
a sky with all forty-four lit really does mount forty-four `OpacityLayer`s.
**The shadow-blur half the census does not measure**, and it is left as the
source's own claim. The document took that **cap-conditional** number and
reported it as what a screen **mounts**, and a screen mounts whatever the
reader has lit.

**A widget count and a layer count are different questions, and so are a cap
and a count.** Three things had to be kept apart, and the sentence kept two of
them together:

| the question | the answer |
| --- | --- |
| how many stars **may** the sky hold? | **44** — `UserSettings.starCount` |
| how many stars **are** mounted? | one per **lit** entry — **0** for a fresh reader |
| how many `OpacityLayer`s does the **screen** mount? | **6** at rest, **+44** when all 44 are lit |

**AND THE GATE'S OWN FAILURE MESSAGE WAS THE SAME CLAIM.** That is the part
worth recording, because a `reason:` string is read by whoever the gate fails
— and it is the one place a reader meets the number while they are trying to
decide what to do about a red build. It is now accurate, and **the assertion
is untouched**: the sky must still not rebuild on a verse tap, whichever count
of stars is lit. What the number *means* is not what the gate asserts.

**A SECOND FINDING FROM THE SAME MEASUREMENT — NOT FIXED HERE, AND IT IS NOT
MINE TO FIX.** `test/layer_census_test.dart` says the 738.77 px² is "**0.02 %
of the screen's area**" (`:468-469`, and again in the reason string at
`:487-488`). **It is 0.18 % of the screen's area**: 738.77 ÷ (430 × 932 =
400,760) = **0.184 %**. The **0.02 %** is of the screen's **composited** area —
738.77 ÷ 3,456,256 = **0.021 %** — which is a real and much smaller number,
and the one that makes the point. The file is another lane's, so it is
**reported rather than edited**; `docs/PERFORMANCE.md` §2.2 and §8.2 give both
percentages with the arithmetic shown, so a reader of *this* repository cannot
be misled by it.

**And the pattern is the one this file has catalogued repeatedly: a number
written once, never re-checked.** What made it survive is that the number was
**true** — it was true of a full sky — so no reader comparing it against the
code found anything wrong. A claim can be accurate about the worst case and
still be false about the screen in front of you, and **only a measurement of
the mounted tree tells the two apart.**

---

## 21. `PERFORMANCE.md` §6.4 — "`EvaTypography.textTheme(…)` is called from **twelve** feature sites"

> **This entry is the second half of entry 17.** Entry 17 recorded that the
> count was **two** when it was **twelve**; this one records that §6.4's own
> table — which entry 17's fix introduced — under-counted again, and that the
> shape of the miss is the one a **qualified** scan cannot see.

| | |
| --- | --- |
| **Claim** | `docs/PERFORMANCE.md` §6.4 — "`EvaTypography.textTheme(...)` is called from **twelve** feature sites, not two", with a table of 12 feature sites plus the theme's own one — **thirteen** in all, and the arithmetic spelled out: "2 + 2 + 2 + 1 + 1 + 1 + 1 + 1 + 1 = **12** … Row 10 is the theme's own **thirteenth**" |
| **Reality** | **There are SIXTEEN.** The **thirteen** qualified sites are exactly as documented. **Three more are unqualified derivations inside `EvaTypography` itself** — `scriptureLatin` (`lib/core/design_system/tokens/eva_typography.dart:179`), `scriptureArabic` (`:188`) and `monoCaps` (`:198`) — and **each rebuilds a whole `TextTheme`**, because each is derived from a slot of one (`textTheme(colors).bodyLarge!…`, `textTheme(colors).labelMedium!…`). They call it **unqualified**, from inside the class, so a scan for `EvaTypography.textTheme(` cannot see them. **12 + 3 + 1 = 16** |
| **Fixed?** | **Yes — 2026-10-22.** §6.4's heading, its opening sentence, its table and its arithmetic are corrected in place, and the count is now **gated**: `test/text_theme_callsite_test.dart` scans `lib/` for **every** `textTheme(` call site — **qualified and unqualified** — and requires each to be on a reviewed allowlist of **16** sites across **11** files |

**The miss has a name, and the name is why it survived twice.** A scan for
`EvaTypography.textTheme(` finds the **thirteen** and stops there. The other
**three** are the same call written without the receiver, from inside the class
that defines it — and a reader counting call sites by reading *call sites* is
counting the qualified spelling, because that is what the word "call site"
evokes. **The count was not wrong by three; it was wrong by exactly the number
of sites a qualified scan cannot see**, and it was wrong in the direction that
makes a document look like it has done more work than it has.

**And the fix is a gate that cannot be fooled by the same mistake.** The scan
in `test/text_theme_callsite_test.dart` matches `\btextTheme\s*\(` — the
**unqualified** form included — and it has a **negative control** that plants a
call site, a comment and a declaration and requires the matcher to tell them
apart, because a scanner that counted the **declaration** would report a site in
the one file that defines the thing being scanned for. **A scan that finds
nothing is a failure**, because that means the matcher rotted rather than the
tree becoming clean.

**And there is a second half to the gate that the count alone would not give.**
De-duplicating a call site is only safe if `Theme.of(context).textTheme` is the
**same** `TextTheme` — and that had never been proven. The same file now proves
it, by diffing all **fifteen** slots **field by field** for **dark × light** and
**en × ar**, from both a pumped tree and the installed `ThemeData`, and
requiring the diff to be empty. **A count without that proof is a plan; a count
with it is a change that cannot alter what the reader sees.**

---

## 22. THE DOCK RIPPLE'S APPEARANCE WAS **UNPINNED** — no test would have failed if it had changed

> **This entry is about a MISSING claim, not a wrong one**, and it is in this
> file because the file's own subject is "the tests are green and the
> documentation is true are different properties". Here the documentation said
> nothing false — **and the tests were green about a ring whose geometry could
> have been rewritten and nobody would have known.**

| | |
| --- | --- |
| **Claim** | **There was none — and that is the claim.** The repository carried no test, golden or probe that would have failed if the dock orb's ripple had changed its **radius**, **alpha**, **stroke** or **ink**. `docs/PERFORMANCE.md` §5.1 described the ring's geometry — "stroked inside the orb's 30 px box at up to 1.6×", a 1.2 px stroke, `rgba(232,176,75,.6)` — and **nothing in the tree held any of it** |
| **Reality** | **No golden renders the dock.** The tree's golden files carry no dock image, so the pixel net that catches a changed widget does not exist for this one. And the dock suite's own pixel probe **samples the wrong places**: `test/features/dock/presentation/widgets/lumen_dock_test.dart:520-524` reads three pixels of the orb's layer at **(10,10)**, **(20,22)** and **(23,26)** in a 30-wide buffer — distances of **7.1**, **8.6** and **13.6** logical px from the orb's centre, and the ring's band runs from the disc's own edge at **15** out to **24**. **All three samples are inside the disc**, so they read the **gradient** and never the **ring**: a ring with a different radius, a different alpha, a different stroke width or a different ink would have passed every test in the tree |
| **Fixed?** | **Yes — 2026-10-22.** `test/features/dock/presentation/dock_ripple_paint_test.dart` measures the ring's **painted radius**, **alpha sum** and **ink** against numbers **read out of the prototype's own stylesheet at test time** — `eva/redesign.html:230` (the border) and `:234` (the keyframes) — so the reference cannot rot with a copied table |

**This is §10's shape, one level down, and the shape is worth naming because
it is the *second* time this repository has had it.** §10 recorded sixteen
background goldens that photographed a design the app **does not ship** — a net
under the wrong thing, indistinguishable from a net. Here there was **no net at
all** for the thing that ships, and the suite that touches the widget
**looked** as if it were one: it really does read the orb's pixels, and it
really does assert on them. **What it read was the gradient.** A test that
samples three points and calls that coverage is the shape of the fool this file
keeps cataloguing — a green check over a surface it never examined.

**And the ring is not a decorative detail.** It is the dock's **only
per-frame repaint** — the ring's own file says so
(`lib/features/dock/presentation/widgets/lumen_dock.dart:903-905`) — and it is
the one the ambient's tick budget governs, so the fix that moved it onto the
budget (§5.1) changed **how often** it is redrawn. A change in *when* is
exactly the change a *what* test should protect, and there was none.

**The gate that closes it reads the reference rather than copying it.** The
border's stroke width and alpha are parsed out of `eva/redesign.html:230` at
test time, the keyframes' scale and opacity out of `:234`, and the measured
painted radius is compared with the orb's radius scaled by the prototype's own
eased `scale(1.6)`. **A table of numbers copied out of a stylesheet is a table
that rots** — and this repository's rule about claims is that they are
testable, and a copied table is a claim with nothing testing it.

**And it carries a negative control, because the instrument is the claim.** The
same file measures a painter that rides the **raw** clock with the same
instrument and requires the instrument to report it as **over budget** — an
instrument that cannot tell a gated painter from an ungated one is green about
nothing.

---

## 23. `app.dart` — "The **four** shared ambient controllers"

| | |
| --- | --- |
| **Claim** | `lib/app/app.dart:96` — "The **four** shared ambient controllers live in ONE `TickerProviderStateMixin` host above `MaterialApp`." Two more copies of the same number stood at `lib/core/design_system/effects/neural_motion.dart:470` and `:534`. |
| **Reality** | The scope owns **two** `AnimationController`s: the float clock (`neural_motion.dart:452`) and the LUMEN shader clock (`:462`). The file that owns them **says so itself**, at `neural_motion.dart:12-15`: the prototype's four orbs' clocks "collapsed to **four** `[AnimationController]`s — float, hue, aurora, and the LUMEN shader clock — and the orbs' retirement took it to **two**: the float clock and the shader clock." |
| **Fixed?** | **Yes — 2026-10-22.** All three copies now say "the shared ambient controllers" / "the controllers", and the number is gone rather than replaced, because the number was the claim and the count is what the code says. |

**And this is how it was found, which is the part worth keeping.** The count
was not read off the code — it was **measured on a running app**. The
profile-mode measurement in `docs/PERFORMANCE.md` §9.2 read
`SchedulerBinding.instance.transientCallbackCount` on the live dock, through
the VM service, and it read **two** tickers with the ambient alone. The
profile-mode run also produced the finding that made the number matter:
**the tick budget reduces work per frame, not the number of frames**, because
the two controllers `repeat()` forever and so the ticker is always active. A
code comment that says "four" where there are two is a small thing; a comment
that says "four" where the code has two, in the file that documents the tick
budget, is a reader being sent to look for two controllers that are not there.

**The shape of the mistake is the one this file keeps finding.** A number
copied from an earlier state of the tree, left behind by a change that
collapsed it, and never re-read because nothing was checking it. The
`neural_motion.dart:12` doc is the *same file* telling the truth, six hundred
lines away — which is exactly why the claim is dangerous: it is plausible,
and it is locally confirmed by a sibling paragraph, and it is wrong.
