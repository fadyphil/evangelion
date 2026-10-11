# ADR-0011: Pin the dependency set; every addition needs approval

- **Status:** accepted
- **Date decided:** 2026-10-05 (§8.4's amendment, §2.1 decision 8c, and recorded decision 133)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §8.4, §2.1 decision 8c, recorded decision 133

## Context

Two amendments changed the shape of this client's dependency surface after Phase 8,
and both arrived with measurements rather than preferences. §2.1 adopted `freezed`
and `gen_l10n`; recorded decision 133 added `flutter_animate`. Each could have
been done with another package, and the reasons they were not are the substance of
this ADR.

The cost of the rule is that it is **also** the reason three things this client
plainly wants are absent: the pure-Dart `bloc` package, generated DTOs, SVG brand
marks, and a real AST. Each was wanted for a measured reason and each was refused
on a rule the owner set in advance.

## Decision

**The approved set is `pubspec.yaml`'s `dependencies`, plus `freezed`,
`freezed_annotation`, and Flutter's own `flutter_localizations` with
`generate: true`** (`pubspec.yaml:22-23,36,106,116`). Anything else needs the
owner's approval, in the task that uses it (§8.4).

**Four named refusals.** `bloc`, `json_serializable`, `flutter_svg` and
`package:analyzer` are named in decision 8c precisely so the next agent does not
re-propose them:

- **`bloc`** — the interesting one, because the project *uses* blocs. `bloc` is a
  transitive dependency of `flutter_bloc` (`pubspec.yaml:28`) and §8.4 will not let
  it be promoted, so the only importable spelling reaches Flutter's widget layer
  (`navigation_injection.dart:44-47`). That one fact splits the DI graph — see
  ADR-0012.
- **`json_serializable`** — the mappers are hand-written and return `Result<T>`
  (`docs/SEAMS.md` Seam 3). Decision 68 records what adding it would mean: the two
  quarantined documents describe a `wire/dto/` layer with fourteen DTOs, and the
  wire contract is **one** shape, `GET /readings/today/{en,ar}`, with no
  bilingual/localized split to model.
- **`flutter_svg`** — there is no icon for Google or Apple in Material, and
  reproducing either brand mark faithfully means inventing path coordinates. The
  social buttons ship text-only rather than approximating a logo (decision 18).
- **`package:analyzer`** — **the largest refusal, and it is the sanctioned
  technique that replaces it.** A source scan over `lib/` is what `verify_purity.sh`,
  `route_check.dart`, `citation_check.py` and `orphan_widget_check.py` already do.
  `package:analyzer` is a far larger dependency than the problem it would solve.

**`flutter_animate` is pinned exactly at `4.5.2`, not `^4.5.2`** (`pubspec.yaml:88`),
while every other dependency in the file uses a caret. Decision 133: the package's
whole surface is a set of extension methods that can appear or disappear between
minors, and this app's motion tokens have to keep meaning one thing across an
upgrade. A caret would let a minor bump silently change which effects exist.

### Two costs accepted deliberately

1. **`flutter_shaders` arrives transitively** (`pubspec.lock:326-327`,
   `dependency: transitive`) for `.shimmer()`. Nothing in this app shimmers. The
   dependency is the price of the package, not a request for it.
2. **The package reads no accessibility flag.** `grep -r disableAnimations` over it
   returns nothing, so §14's "every animation checks
   `MediaQuery.disableAnimationsOf(context)`" is *not* satisfied by using it
   directly, and every direct call site would be a fresh invisible violation.
   `EvaAnimate` closes that gap and is mandatory rather than preferred — ADR-0019.

## Alternatives considered

### Promote `bloc` to a direct dependency to clean up the DI split

- **Why not:** §8.4 pins the approved set, and the cost of the split is already
  paid and recorded (`navigation_injection.dart`'s own header names it five times,
  one per bloc and cubit). Promoting `bloc` would buy tidiness with a dependency
  approval, on a project whose hard constraint is that adding one needs the owner.

### Use `package:characters` — it is *already* in the lock file

- **Why not:** **§8.4 pins `pubspec.yaml` itself, not the lock file.** `characters`
  is transitive today (`pubspec.lock:140-141`) because `flutter_bloc` drags it in
  and because Flutter's own text engine needs it. Promoting it to `dependencies`
  to reach a rune helper would be a direct dependency added without approval, and
  the one-line function it would buy is
  `lib/core/domain/entities/drop_cap_text.dart`'s `runes.first` (ADR-0021).
  *A transitive package is not available; it is merely present.*

### Pin every dependency exactly, for the same reason

- **Why not:** the rule is scoped to the package whose surface is extension methods.
  `dio`, `get_it` and `auto_route` have stable APIs; pinning all of them would make
  every security bump a manual edit and would not buy the property decision 133 is
  after.

### Adopt `google_fonts`, as `docs/plans/03-design-system.md` §5.2 words it

- **Why not:** the plan's actual requirement is the second half of its sentence —
  "bundled at build time so first paint is not blocked on a network fetch." The
  twenty `.ttf` files under `assets/fonts/` already satisfy it
  (`eva_typography.dart`'s header records the plan sentence as superseded by the
  bundling that followed). Adding `google_fonts` on top would reintroduce the HTTP
  fetch `docs/plans/09-quality-gates.md` §11 names as the cause of flaky goldens.

## Consequences

### Better

- Every dependency has a recorded reason, and three of the four refusals are
  refusals of a *named* alternative rather than an unnamed "do it by hand". That is
  what stops the next agent from re-deriving them.
- The scope rule has bitten and been measured: §8.4's rule against promoting `bloc`
  is the entire reason ADR-0012 splits the graph, so the cost of the rule is
  visible in the repository rather than hypothetical.

### Worse

- **Two known absences are permanent rather than pending.** There is no SVG brand
  mark and no pure-Dart bloc import, and neither is a backlog item; both are
  consequences.
- **`flutter_animate` was last published 2024-11-25** (decision 133), and the exact
  pin means every future release is a deliberate edit to `pubspec.yaml:88` with its
  own justification. That is the price, paid knowingly.

### Neutral / noted

- **`equatable` is entirely absent, not merely un-promoted.** Decision 131:
  `pubspec.lock` carried zero occurrences, so `flutter_bloc` does not pull it
  either. That is a fact about the resolved graph, and the `pubspec.yaml:37-48`
  comment records the claim it contradicts.
- **The repository has untracked documents that describe a dependency set this
  project does not have** — `docs/CLIENT.md` and `models.md`, quarantined in
  `docs/proposals/` as of 2026-10-11. `docs/DRIFT.md` §5 tabulates the divergences.
  Their existence is not evidence that the rule was wrong; it is evidence that a
  proposal can exist without being built.

## Traceability

- `AGENT_CONTEXT.md` §8.4 (the amended approved set), §2.1 decision 8c (the four
  named refusals and the source-scan alternative), recorded decision 133
- `AGENT_CONTEXT.md` recorded decision 131 (`equatable` entirely absent)
- `pubspec.yaml:16,22-24,27-28,34,36,49-51,54,88,103-106,116`
- `pubspec.lock:140-141` (`characters`, transitive), `:326-327` (`flutter_shaders`,
  transitive)
- `lib/app/di/navigation_injection.dart:33,44-47,68-69` (why `bloc` may not be
  promoted, and what that costs)
- `lib/core/design_system/tokens/eva_typography.dart` — the `google_fonts` refusal
- `lib/core/design_system/motion/eva_animate.dart` — the accessibility-flag gap
- [`docs/DRIFT.md`](../DRIFT.md) §5 (the two documents describing a codebase that
  does not exist)
- [`docs/SEAMS.md`](../SEAMS.md) Seam 2 (the DI split this rule causes), Seam 3
  (hand-written mappers)
- ADR-0012, ADR-0019, ADR-0021
