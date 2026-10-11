# ADR-0006: `Result<T>` is a typedef for `Either<Failure, T>` via fpdart

- **Status:** accepted
- **Date decided:** 2026-10-11 (original hand-written type: 2026-10-02)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2 decision 7, §2.1 `SUPERSEDED` block, decisions 98 and 131

## Context

**This ADR exists because the original rejection of `fp_dart` was wrong, and that is
the most important thing in it.** A 297-line hand-written `Result<T>` was kept in
place of the package on the argument that "`sealed` + exhaustive `switch` is
*strictly stronger* than **`dartz`**'s `Either`". That sentence is a true statement
about the wrong package.

## Decision

`lib/core/common/result.dart` is `typedef Result<T> = Either<Failure, T>` over
`package:fpdart`. The load-bearing claim — that the alias preserves sealed
exhaustiveness — was verified in a scratch package **before** the migration was
committed, because it was the one thing that would have made the whole thing fail.

**No `value` getter and no `getOrNull` exist across this app.** Either would let a
caller write `result.value` and silently turn a `Failure` into a `null` that
surfaces three frames later in a widget build. Read a `Result` with `Either.fold`,
or with the `valueOrElse` extension whose name says it discards the failure.

## Alternatives considered

### Keep the hand-written sealed type

- **Why not:** its stated reason was about `dartz`. `fp_dart`'s `Either` is itself
  `sealed` — `either.dart:39` in the pub cache reads
  `sealed class Either<L, R> extends HKT2<_EitherHKT, L, R>` — and a typedef is an
  alias, not a wrapper, so a `switch` over `Result<T>` is still an exhaustive
  switch *expression* with no `default` arm. "A true statement about one package
  used to justify a decision about another. No amount of re-measuring would have
  caught it, because the measurement was never performed against the package being
  decided about" (`docs/DRIFT.md`, *The pattern*).

### Subclass `Right` to restore the `runtimeType` equality guard

- **Why not:** **it does not work, and it looks like it should.** A subclass does
  not match its supertype's *object pattern*, so `switch` over the alias stops
  being exhaustive: a `Success` case yields "'Result<int>' is not exhaustively
  matched since it does not match the pattern 'Right<Failure, int>()'".
  Restoring equality that way **destroys the sealed exhaustiveness** — the exact
  property the migration was undertaken to obtain. The two requirements are in
  direct conflict.

### Add a `fold` extension to shadow fp_dart's own

- **Why not:** it would compile, never be called, and give no warning. An extension
  member of the same name is shadowed by the type's own member
  (`result.dart:96-99`). Note also the arm order: `Either.fold` takes **failure
  first**, where the hand-written type took `fold({onSuccess:, onFailure:})`.

## Consequences

### Better

- The stale measurements behind the rejection are corrected: **`try` blocks are 6
  in 4 repositories, not 3 in 2** (re-measured 2026-10-11: `dio_reading_repository.dart` ×2,
  `settings_repository_impl.dart` ×2, `dio_streak_repository.dart` ×1,
  `dio_leaderboard_repository.dart` ×1), and nothing in `lib/` needs `AsyncEither`.
- Two claims from the original table are now **asserted false in tests**, which is
  the only form of "this is not true" that survives a dependency bump:
  - **`fp_dart` does *not* fix collection equality.** `==` on a `List` is identity
    in **both** implementations. `test/core/common/result_test.dart:594-612` asserts
    it: the same instance is equal, an equal-but-distinct list is not.
  - **`fp_dart`'s `getOrElse` is sound.** `R` is the payload type, not inferred
    from the fallback; the extension added by hand, `valueOrElse(T orElse)`, is the
    one typed deliberately.
- `flatMap`, `traverse`, `sequence`, `rights`, `lefts` and `Either.Do` are available
  and **unused** — measured today, `rg 'flatMap|traverse|Either.Do' lib/` matches
  only the three doc lines in `result.dart` that list them.

### Worse

- **The covariance guard is genuinely lost.** `Right.operator ==` is
  `(other is Right) && other._value == _value` (`either.dart:572`, read in the
  pub cache) — the type arguments are never mentioned, so because Dart's generics
  are covariant,
  `Right<Failure,int>(1) == Right<Failure,num>(1)` is `true`. The hand-written type
  guarded on `runtimeType` for exactly this reason (decision 131) and had mutation
  tests behind it. It is now pinned as **observed behaviour** by
  `test/core/common/result_test.dart`, so a future `fp_dart` release that adds the
  check fails a test rather than passing unnoticed.

### Neutral / noted

- **The "40 lib / 59 test files import it" figure is not reproducible, and this ADR
  does not repeat it.** Measured three ways on 2026-10-11: `rg -l 'core/common/result.dart'`
  gives **36** `lib` and **41** `test`; `rg -l '\bResult<'` gives **38** and **40**;
  `rg -l 'package:fpdart'` gives **11** and **48`. None is 40/59. The original
  rejection's own table is stale on every line, and §2.1 already records that the
  figure was "taken with an unknown method and is not the basis of any decision
  now".`docs/SEAMS.md` Seam 1 still carries the 40/59 pair; **treat the number as
  unmeasured and the mechanism as measured.**
- `Failure` remains hand-written — see ADR-0007. Two of the three properties
  fp_dart cannot give live on that type, not on this one.

## Traceability

- `AGENT_CONTEXT.md` §2 decision 7 and §2.1's `SUPERSEDED` block
- `AGENT_CONTEXT.md` decisions 98 and 131 (`Failure` and `Result` stay hand-written;
  the `runtimeType` clause and why covariance made it load-bearing)
- `docs/DRIFT.md` §2 (the rejection was wrong), §2a (stale measurements), §2b (two
  claims asserted false), §3 (what adopting it cost)
- `docs/plans/10-open-decisions.md` §16 — the two-adapter argument this ADR rests on
- `lib/core/common/result.dart:41-67` (the measured cost), `:84-89` (no `value`),
  `:96-99` (no `fold` extension)
- `fpdart-1.2.0/lib/src/either.dart:39` and `:572` in the pub cache
- `test/core/common/result_test.dart:594-612`
- [`docs/SEAMS.md`](../SEAMS.md) Seam 1
