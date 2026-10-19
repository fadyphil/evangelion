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
| **Fixed?** | **Yes — 2026-10-19, Task 5.5.** §2's table now has seven rows and its heading reads "The seven routes"; the seventh is `/communion`, which is the renamed `/leaderboard`. The **count** is what the row was about, and it is now true. |

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
library, cut by decision 1 (`HomeScreen.tsx:86`, `ds.tsx:389`), and the other three
pill styles were marked *"do not port"* by defect #12 — so the widget had no caller
left by construction, not by oversight. Removed: the widget (448 lines), its own
test suite, 8 goldens, and every reference to it. The design-system barrel export
is gone with it.

The three options were real and all were defensible:

* **place it** — the settings theme row uses `SegmentedControl`
  (`settings_page.dart:203`) rather than chips; that is a design choice, not an
  oversight;
* **delete it** — **taken**, along with the 8 goldens and their test surface;
* **allowlist it** — as a design-system primitive kept for prototype parity.

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

The third was the dangerous one. A gate that quietly skips a class of declarations
is the same defect as one that cannot fail: both report a clean run over a surface
they never examined.
