# ADR-0003: Keep three layers with strictly inward dependency direction

- **Status:** accepted
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §3

## Context

Three layers, one direction, and no exceptions. The rule is only worth anything if
something can be false about it — a prose rule is believed by everyone who has not
tried to violate it. The previous attempt at an inline cross-feature check used a
backreference, `rg -v "features/(\w+)/\1"`; ripgrep has no backreferences, so the
pattern failed to *compile*, exited `0`, and reported every line as passing.

## Decision

```graph
presentation  ──▶  domain  ◀──  data
```

`core/domain/` and every `features/*/domain/` import **nothing** from Flutter, Dio
or HTTP. The direction is **mechanically enforced, not reviewed**:
`tool/verify_purity.sh` Gate 1.

## Alternatives considered

### Enforce the layering by review

- **Why not:** the same backreference incident is the worked example. A check that
  reports a clean run over a surface it never examined is indistinguishable from a
  real one, so a review-only rule is a rule that fails silently.

### Match only `import` in Gate 1

- **Why not:** an `export` of `package:flutter/material.dart` is exactly as impure
  as an `import` of it, and **neither it nor `part` trips any lint**. Both forms
  were found by negative control — the gate printed `ok` while a planted `export`
  sat in a domain file. That regression is recorded, not remembered.

## Consequences

### Better

- The compiler is not needed to check it and a reviewer is not trusted to: the gate
  exits `1` on a violation and `2` when it *could not run*, and `tool/verify_purity.sh`
  distinguishes "found nothing" from "could not look" by capturing `rg`'s exit
  status explicitly.
- **No feature may import another feature** (Gate 2, run through
  `tool/feature_import_check.dart`, which resolves every `import` / `export` / `part`
  target to a path under `lib/` rather than matching URIs — same-package imports are
  legal Dart in two forms, `package:evangelion/features/quiz/…` and `../../quiz/…`,
  and a URI-substring check catches only the first).

### Worse

- **The match had to be anchored to a directive keyword.** The pattern is
  `^(import|export|part)\s+'package:(flutter|dio|http)/` (single quotes only, because
  `prefer_single_quotes` plus `--fatal-infos` makes the other form fatal anyway).
  A bare substring scan would fail the gate on any doc comment explaining *why* a
  file is dependency-free — and `result.dart` names `package:flutter/material.dart`
  in prose. A substring version would force that documentation to be watered down,
  which is a real cost paid for a cheaper-looking pattern.

### Neutral / noted

- **`core/common/` and `core/navigation/` joined Gate 1 in Phase 0c**, and they are
  the least obvious part of the list. Both *document* the property in their own
  words — `app_routes.dart` says "staying Flutter-free keeps the constants readable
  from any layer", `app_config.dart` says "no Flutter import, so this can be read
  from `core/domain/`" — and both claims are **load-bearing**: Phase 5 has
  `core/domain/` use cases reading `AppConfig`, and `AppRoutes` is the
  most-imported file in the app. Neither was checked, so a Flutter import in either
  left every gate green. **Do not narrow the list back without re-reading those two
  doc comments.**
- Gate 2's `ok` line names every owner the pass actually reached, because a
  directory *nobody claimed* produces no output at all — which is how `lib/l10n/`
  sat outside the gate until a probe importing `features/quiz` from it exited `0`.

## Traceability

- `AGENT_CONTEXT.md` §3, "Dependency direction is strictly inward" and "Feature independence"
- `AGENT_CONTEXT.md` §7, "Architecture gates" and "What each gate matches — do not narrow these patterns"
- `AGENT_CONTEXT.md` recorded decision 4 (the composition root must stay Flutter-free)
- `tool/verify_purity.sh` Gate 1 (`DIRECTIVE_RE`, line 175) and Gate 2
- `tool/feature_import_check.dart`
- `tool/verify_gates_selftest.sh` — plants a cross-feature import and requires a non-zero exit
- [`docs/SEAMS.md`](../SEAMS.md) Seam 3, for where the direction turns in practice
