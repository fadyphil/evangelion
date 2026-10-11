# ADR-0009: Disable `copyWith` on the three largest states and write whole states

- **Status:** accepted
- **Date decided:** 2026-10-05 (audited and confirmed 2026-10-11)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` decisions 97, 141 and 156; `docs/DRIFT.md` §6

## Context

`copyWith` is the ergonomic way to change one field of a state. Whole-state writers
are the way to make it impossible to leave a state internally inconsistent. The
choice was made per-state and then inherited by every feature that added a field.

## Decision

`@Freezed(copyWith: false)` is set on `HomeState` (`home_bloc.dart:418`), `AuthState`
(`auth_bloc.dart:239`) and `QuizState` (`quiz_bloc.dart:213`). Those three write
**whole states** — named `with*` writers, or inline full constructors at every call
site. The three smallest keep the generated `copyWith`.

**And the honest finding goes in the ADR, not just in the drift file: the
correlation is backwards.** `copyWith` is disabled on the three **largest** states
and kept on the three **smallest**. A property whose benefit grows with reuse is
being withheld exactly where the state is big enough to hurt.

| state | fields | `copyWith` | what it uses instead |
| --- | --- | --- | --- |
| `HomeState` | 13 | disabled | 6 named `with*` writers, each restating all 13 |
| `AuthState` | 10 | disabled | 2 writers + a **hand-rolled** `copyWith` (`auth_bloc.dart:366`) |
| `QuizState` | 5 | disabled | inline full constructors, 11 sites |
| `LeaderboardState` | 4 | generated — **zero call sites** | inline full constructors, 3 sites |
| `ReadingState` | 4 | generated | `copyWith` |
| `SettingsState` | 3 | generated | `copyWith` |

**This is recorded, not reversed.** Nothing here changes behaviour and nothing here
says the pattern is wrong. It says it was decided for one shape of state and
inherited by every feature that added a field.

## Alternatives considered

### Keep `copyWith` everywhere

- **Why not:** for `HomeState`, it cannot express the invariant. See below.
  Everywhere else, the justification was inherited rather than re-argued — which is
  the shape `AGENT_CONTEXT.md` records a dozen times elsewhere.

### Hand-write `copyWith` for the three large states

- **Why not:** `AuthState` did exactly this and kept **six** of its ten fields in
  it (`auth_bloc.dart:366`). The result is a partial `copyWith` that looks like the
  full one — which is precisely the hazard the exclusion was supposed to remove, and
  it is the clearest evidence in the repository that the exclusion was felt.

## Consequences

### Better

- **The invariant `HomeState`'s writers actually protect.** Four independently
  failing backend endpoints, each a `status · payload · failure` triple that must
  stay mutually consistent. `withReading` forces the caller to state all three, so
  the triple can never disagree with itself.
- **A new field cannot be silently dropped.** Because a writer that forgets the new
  fields clears them, adding `leaderboardStatus` required editing **every** writer.
  That is the discipline working: a reading update no longer wipes the card.

### Worse

- **`HomeState`'s `toString` is hand-written and a new field is invisible in it.**
  Two frames in `home_bloc_test.dart` were indistinguishable in a failure message
  until the `toString` learned to print `board: ready 3`. It counts rows rather
  than printing the board, because a failure message that renders a twelve-field
  entity stops being readable — so the fix is a convention with no gate.
- **Two of the three carry no recorded justification at all.** No cross-field
  invariant is recorded anywhere for `QuizState` or `AuthState`; decision 141 is
  about `HomeState` and its argument was inherited rather than re-argued.
- **`LeaderboardState` carries a generated `copyWith` that no call site in `lib/`
  or `test/` reaches** — the cubit builds all three of its states through the
  constructor. That is the pattern paying for a function nobody calls.
- Adding one field to `HomeState` means editing six writers. That is the cost, and
  it grows with every field.

### Neutral / noted

- **A claim made during the audit was corrected, and the correction belongs here:
  freezed's `copyWith` *can* clear a nullable field.** It was asserted that it
  "cannot clear a nullable field". That is **false**, and the generated code is the
  disproof — `settings_state.freezed.dart:71` reads
  `call({Object? settings = null, Object? status = null, Object? failure = freezed,})`
  and `:75` reads `failure: freezed == failure ? _self.failure : failure`. freezed
  gives every **nullable** a `freezed` sentinel, so `null` means *explicitly clear
  this* and the sentinel means *keep the current value*. Non-nullable fields default
  to `null`, which cannot express clearing because there is nothing to clear.
- **What `copyWith` genuinely cannot do is express a cross-field invariant.**
  `state.copyWith(readingStatus: failed, readingFailure: f)` leaves `reading`
  holding its old value, so the triple disagrees with itself; `withReading` forces
  all three. **And that justification reaches only `HomeState`.**
- **Three fixes would each be defensible and none was applied**: re-enable
  `copyWith` on `QuizState` and `AuthState`, delete `LeaderboardState`'s dead one,
  drop `AuthState`'s hand-rolled one. Each is a refactor needing its own decision
  and tests. Silently reverting a pattern that six blocs and the whole suite agree
  on is a drift fix, not a refactor — and the suite's floor is **2507 tests** as of
  the latest commit, down from 2541 only because `EvaChip` and its 8 goldens were
  deleted.
- **The transferable rule:** a rule that grows more expensive as the thing it
  governs grows should be re-examined every time the thing grows. The cost here was
  paid once, when the state was small, and then inherited by every feature that
  added a field.

## Traceability

- `AGENT_CONTEXT.md` decision 97 (the annotation, and the `@freezed` ordering trap)
- `AGENT_CONTEXT.md` decision 141 (`HomeState.toString()`; "adding
  `leaderboardStatus` required editing every writer")
- `AGENT_CONTEXT.md` decision 156 (the audit, the correction, and "not fixed here")
- `docs/DRIFT.md` §6, "The correlation is the finding"
- `lib/features/settings/presentation/cubit/settings_state.freezed.dart:71,75`
- `lib/features/auth/presentation/bloc/auth_bloc.dart:366`
- `tool/baseline/gates.txt` (`test_count 2507`)
- [`docs/SEAMS.md`](../SEAMS.md) Seam 4
