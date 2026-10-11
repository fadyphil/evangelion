# ADR-0008: Use freezed for bloc states, events and domain entities

- **Status:** accepted
- **Date decided:** 2026-10-05
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2.1 decision 8a, decisions 96, 97, 100

## Context

Before `freezed`, hand-written states cost `List<Object?> get props`,
`int get hashCode`, `==`, `copyWith` and `toString` on every one. Three hazards
were written down **before** the package was adopted, each because it would be
invisible in a green suite. They are recorded here because each now has a standing
gate.

## Decision

**The data-class form: `final class X with _$X` with a direct constructor.** Not
the `const factory X({…}) = _X;` form that most of the package's documentation
uses. The factory form requires every field to be declared as an abstract getter,
because the generated implementation `implements X` rather than extending it —
declaring `final String a;` beside it is a `final_not_initialized` compile error,
measured. The direct-constructor form keeps the field declarations **in the
annotated file**, which is what keeps the secret gate below scanning real code
rather than generated output.

At the migration, 34 types were converted: 17 classes, 14 events and 3 sealed event
bases. As of 2026-10-11 `lib/` carries **39** `@freezed` annotations and **19**
generated parts — the leaderboard feature added types after the migration, and the
counts are given here so a reader is not misled by the original figures.

## Alternatives considered

### Use the documented `factory` form

- **Why not:** it costs `secret_masking_test.dart` its subject list. The generated
  part would own the fields and the structural scan would be reading generated
  code.

### Use `@freezed` together with `@Freezed(copyWith: false)` where both apply

- **Why not:** `@freezed` is `const freezed = Freezed()`, so writing both makes
  `firstAnnotationOf` read whichever comes first — and with `@freezed` on top,
  `copyWith: false` is silently ignored and a generated `copyWith` collides with
  the hand-written method (`conflicting_method_and_field`). `@Freezed(copyWith: false)`
  alone is the only working spelling.

### Hand-write the base class `==` on `AuthState`

- **Why not:** nothing needs it. `==` is where freezed is strongest. (Its
  `copyWith` is the part worth disabling — see ADR-0009.)

### Delete the `_$…Event` mixins that look like dead generated artifacts

- **Why not:** they are load-bearing. freezed's sealed-union pattern *requires* the
  mixin, and `quiz_bloc.dart:90` reads `sealed class QuizEvent with _$QuizEvent`.
  Deleting them by hand does not compile.

## Consequences

### Better

- **`toString` overrides survive — and a gate exists because nothing else proves
  it.** freezed generates `toString` and skips the member when the class declares
  one, but **nothing in a green suite distinguishes "freezed respected my override"
  from "freezed replaced it"**. A generated one writes a reader's typed password
  into every log line and every failed `expect`. Three classes override it to keep
  a secret out of logs — `login_credentials.dart:58`, `auth_bloc.dart:172`
  (`AuthPasswordChanged`) and `auth_bloc.dart:395` (`AuthState`) — and
  `test/core/common/secret_masking_test.dart` is **structural** for exactly this
  reason: it scans `lib/` for any class declaring a `final String password` and
  requires a `toString` that does not interpolate it, plus a behavioural half
  against the running classes.
- **`copyWith` correctness is asserted on its own terms.**
  `test/core/common/freezed_structural_equality_test.dart` asserts that two
  equal-but-distinct instances compare equal *and* that changing **every single
  declared field** makes them unequal, with the field count asserted against the
  list length — the first version sampled two of `SubmitResult`'s seven fields and
  a deleted `readingCompleted` sailed through it. Decision 99 records 21 tests
  there; it carries 30 today.
- **The generated parts are proved pure Dart, not asserted to be.** Eleven
  `.freezed.dart` files live inside the pure-Dart directories and Gate 1 scans
  them. Verified by scan and by negative control: a planted
  `import 'package:flutter/material.dart'` in a `core/domain` part makes Gate 1
  exit `1`.

### Worse

- **`const` constructors arrive with every converted type**, adding
  `const`-canonicalisation surfaces. This project has shipped **eight** already:
  `same()` on canonicalised `bool`s, a `contains` that accepted `240` for `24`, a
  `find.textContaining` that could not match a `Text.rich`. Two standing gates
  answer this: the structural-equality suite above, and
  `test/core/common/no_identical_on_converted_types_test.dart`, which audits every
  `identical(` / `same(` site in `test/` against a reviewed table and fails on an
  unreviewed site, a stale row, a changed count or a drifted `converted:` flag.
  Decision 99 recorded 9 tests over a 57-row table; the suite carries 11 tests
  today and the table is now "~40 rows" with a `greaterThanOrEqualTo(40)` floor,
  because a window heuristic for "which sites are about a converted type" is a
  false-negative machine.
- **`freezed` derives `==` from the constructor and offers no per-field exclusion**,
  which is the direct reason `Failure` could not be converted (ADR-0007).

### Neutral / noted

- **The gate that found five invisible types is itself the caution.** An earlier
  `secret_masking_test.dart` treated a `/*` **inside a doc comment** as a block
  comment start, so three files were scanned only up to their first glob-shaped
  path (`readings/today/*`) and **five converted types never reached the gate**. It
  now uses the shared `withoutDartComments` and carries a planted negative control.
- **`.freezed.dart` parts are deliberately NOT in the generated-header gate**
  (`*.gr.dart` / `*.config.dart` are), because freezed emits its own
  `ignore_for_file` header and a naive grep for `type=lint` matches on a substring.
  `dart analyze --fatal-infos --fatal-warnings` and the idempotence check cover them
  instead.

## Traceability

- `AGENT_CONTEXT.md` §2.1 decision 8a and hazard 1 (the `toString` trap)
- `AGENT_CONTEXT.md` decisions 96, 97, 99, 100, 132
- `AGENT_CONTEXT.md` decision 4 — the "unknown builder key is silently ignored"
  rule applies to the `freezed:freezed` key in `build.yaml` as well
- `lib/features/auth/domain/login_credentials.dart:58`,
  `lib/features/auth/presentation/bloc/auth_bloc.dart:172,395`
- `test/core/common/secret_masking_test.dart`,
  `test/core/common/freezed_structural_equality_test.dart`,
  `test/core/common/no_identical_on_converted_types_test.dart`
- `docs/DRIFT.md` §7, "What building the gate found in the gate itself" — the same
  failure shape three times over, applied to gates rather than widgets
- [`docs/SEAMS.md`](../SEAMS.md) Seam 4
