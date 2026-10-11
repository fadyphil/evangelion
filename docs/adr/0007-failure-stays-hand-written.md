# ADR-0007: Keep `Failure` hand-written and exclude `details` from equality

- **Status:** accepted
- **Date decided:** 2026-10-05 (type introduced 2026-10-02)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2.1 hazard 2, decisions 98 and 131

## Context

`Failure` is the payload on the `Left` arm of every `Result`, and it lives **inside
bloc state**. Two properties of it are deliberate and neither survives a generated
`==`, because code generation offers no per-field exclusion: a generated equality
puts *every* constructor field into the contract, and one of the four is a decoded
server response body.

## Decision

`lib/core/common/failure.dart` stays hand-written, with three properties a generated
`==` cannot give:

1. **`details` is excluded from equality, on purpose.** `==` compares `kind`,
   `message` and `statusCode` by name and ignores `details` entirely.
2. **`toString` deliberately omits `details`.**
3. **`==` guards on `runtimeType`.**

Both contracts are pinned by `test/core/common/failure_equality_test.dart` — six
tests under one `Failure equality` group, including the one named *"[details] does
NOT decide equality, and that is the decision this file exists to pin"* (`:86`).

## Alternatives considered

### Convert `Failure` to `@freezed` for consistency with every other state

- **Why not:** it would put a decoded server body into the equality contract **on
  purpose**. See below.

### Exclude `details` by typing it as `Object?` and relying on deep comparison

- **Why not:** that is exactly what was tried and abandoned. `equatable`
  deep-compares `Map` / `Set` / `Iterable` but falls through to plain `==` for
  everything else, so an untyped field makes two logically identical failures
  unequal — and `Failure` inside bloc state means a spurious emit and a rebuild.

### Leave `Failure` on `Equatable` and drop it later

- **Why not:** already done. See *Neutral / noted*.

## Consequences

### Better

- Two error shapes that mean the same thing produce a `Failure` that compares
  **equal**, so a repository cannot reclassify an error and a bloc cannot emit a
  spurious state change. The dual-shape error mapper depends on this directly: the
  synthetic `{statusCode, code, error, message}` arm is populated into `details`
  precisely so it is *carried without deciding anything*.
- **No server response body ever reaches a log line**, because `toString` renders
  kind, status and message and stops. A response body is not ours to re-publish.
- The `runtimeType` guard survives even though the same guard was lost on `Result`
  (ADR-0006) — the two types could be fixed independently and only one could be.

### Worse

- **A test group can now be structurally vacuous without anyone noticing.** A
  failure differing only in `details` is *equal*, so an assertion that constructs
  two such failures and expects inequality cannot fail. That is the intended
  behaviour, and it is also a shape a future test author will reach for.
- The `runtimeType` clause needed **two wrong answers** before it was seen as
  load-bearing (decision 131). It was first called redundant, because
  `other is Failure` rejects a mismatched subtype; it does, in the *narrowing*
  direction only. Because Dart's generics are covariant, a subclass instance passes
  the type test and the payload agrees, so two such failures compare **equal**.
  The test that catches this had to be rewritten twice: `Failure(int 1)` against
  `Failure('1')` proves nothing, because the payloads differ and `==` rejects the
  pair before the type is consulted.

### Neutral / noted

- **`equatable` is gone entirely — not even a transitive dependency.** Verified
  2026-10-11: `pubspec.lock` contains **zero** occurrences, and the only mention in
  `pubspec.yaml` is the comment at line 37 recording that fact. This **contradicts**
  the earlier claim that it still arrives via `flutter_bloc`, which is what decision
  131 corrects. Nothing in `lib/` imports it; the remaining mentions in `test/` are
  comments explaining why the properties were written out by hand.
- **The one property genuinely given up is unreachable today.** No `Result` in `lib/`
  or `test/` carries a collection, so the lost deep-compare of an `Iterable` was
  never load-bearing — and `Object.hashAll` would not have fixed it, since it
  hashes by identity and would make `==` and `hashCode` disagree on the same pair.

## Traceability

- `AGENT_CONTEXT.md` §2.1 hazard 2 and §2 decision 7's `SUPERSEDED` block
- `AGENT_CONTEXT.md` decision 98 (the type stays hand-written) and decision 131
  (the `props` list is gone; `runtimeType` is load-bearing; `equatable` is gone)
- `AGENT_CONTEXT.md` decision 14 (the dual-shape mapper; `details` populated only
  for the synthetic branch)
- `lib/core/common/failure.dart:135` (`details` and why it rides along),
  `:137-173` (`==` and the excluded field), `:179` (`hashCode`), `:181-191` (`toString`)
- `test/core/common/failure_equality_test.dart`
- `docs/DRIFT.md` §3, the "what adopting `fp_dart` actually cost" table, and
  `AGENT_CONTEXT.md` decision 131 for the `equatable` row the table does not carry
- [`docs/SEAMS.md`](../SEAMS.md) Seam 1, points 3 and 4
