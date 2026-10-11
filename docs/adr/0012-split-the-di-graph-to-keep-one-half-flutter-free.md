# ADR-0012: Split the DI graph across two files so one stays Flutter-free

- **Status:** accepted
- **Date decided:** 2026-10-03 (recorded decision 4: 2026-10-02)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` recorded decisions 4, 11, 17

## Context

The composition root must not import Flutter, and **not merely in the shallow
sense**: recorded decision 4 requires `injection.dart`'s entire transitive
*project-local* import graph to stay Flutter-free, and
`test/app/di/injection_test.dart` walks that graph and fails otherwise. That
constraint is what splits the graph. Nothing else would have.

The constraint was written before the thing that violates it existed, which is
unusual and is why it held: recorded decision 11 predicted the wall three phases
before `AuthBloc` hit it, and recorded decision 17 records it arriving exactly as
predicted.

## Decision

**The graph is two files, and the line between them is a purity gate rather than a
file-map convention.**

| half | registers | where |
| --- | --- | --- |
| generated | **30** — data sources, mappers, repository adapters, use cases, `Dio`, the `apiBaseUrl` instance | `lib/app/di/injection.config.dart:74-139` |
| hand-written | **10** — six `Bloc`/`Cubit` instances, `SettingsHandle`, `AuthStatus`, `ReevaluateListenable`, `AppRouter` | `lib/app/di/navigation_injection.dart:170` (`configureNavigation`) |

**Why ten are hand-written.** `bloc` is a transitive dependency §8.4 will not
promote, and the only importable spelling — `package:flutter_bloc/flutter_bloc.dart`
— **re-exports Flutter's widget layer** alongside the bloc
(`navigation_injection.dart:44-47`). So there is **no spelling of "generate this
registration" that keeps Flutter out of the closure**. `AppRouter` is the same
problem by a different route: `auto_route_generator` names its output after the
router's own file and emits a `.gr.dart` beside it, so relocating the router to
`lib/core/navigation/` makes `verify_purity.sh` report seven violations
(decision 11, measured rather than assumed). Every one of the six blocs and cubits
hit the identical wall; `navigation_injection.dart`'s header narrates it five
times, once per registration.

### The walk is what makes the constraint real

`test/app/di/injection_test.dart` walks `import`, `export` **and** `part`, in both
quote styles (`test/support/project_import_graph.dart:60-63`, one pattern,
`(['"])([^'"]+)\1`, terminated by the closing quote rather than by the semicolon so
a `show`/`hide` combinator cannot hide behind it). Both non-default forms are
there for measured reasons: an `export 'package:flutter/material.dart';` slipped
through this suite while every test stayed green, and a `part` pulls a file into
the library's namespace just as an `import` does — and neither trips a lint.

**And the walk is itself checked.** The production graph uses only single-quoted
`import`s, so it cannot prove the walker sees anything else. `writeDirectiveFixture()`
(`project_import_graph.dart:197`) builds a three-file scratch tree out of nothing
but the forms production code does not use — a double-quoted `export … show Color;`
at the bottom, a single-quoted `part` above it — and the suite asserts all three
files are reachable. **A fixture built out of exactly the non-default forms is what
keeps the walk honest.**

### The consequence that followed

`bootstrapApp`'s "graph first, router second" went from advisory to
**load-bearing**. Recorded decision 17 replaced the Phase-4 test *"neither step
depends on the other having run first"* — **true then, false now** — with one that
requires `configureNavigation` to throw a `StateError` naming an unregistered use
case when the generated graph is missing, asserted **in the failing direction**
(`test/app/di/navigation_injection_test.dart:335-349`, matching
`contains('is not registered inside GetIt')`). A graph that failed quietly here
would have surfaced as a `StateError` inside whichever router test ran first,
several files from the cause.

## Alternatives considered

### Put the router and the blocs in `@module` files and generate them too

- **Why not:** measured, seven violations. `injection.config.dart` imports every
  `@module` in the package, so naming `AuthBloc` there puts `app_router.dart` —
  which names all the `*Route` classes and therefore reaches
  `package:flutter/material.dart` through the generated route files — inside the
  closure.

### Import `package:bloc/bloc.dart` and make the blocs generatable

- **Why not:** `bloc` is transitive and §8.4 will not promote it (ADR-0011). The
  obvious-looking import is unavailable, which is why six `Bloc`/`Cubit`
  registrations are hand-written rather than one being generated and five hacked.

### Import the widget layer in `injection.dart` and narrow the test to `lib/core/domain/`

- **Why not:** two separate prohibitions, and both hold elsewhere. The pure-Dart
  rule for `core/domain/` and `features/*/domain/` is `verify_purity.sh` Gate 1;
  this one is about the composition root, and relaxing it would put the composition
  root inside the domain-purity gate's blast radius for no gain.

## Consequences

### Better

- The rule that is genuinely checkable is the one that is enforced. Five of the ten
  hand-written registrations are blocs that a generated config could not have
  contained, and `injection_test.dart` asserts them **absent** from the generated
  config while `navigation_injection_test.dart` resolves them **present** — so
  neither half can drift.
- The six `@module` files are committed and empty, each naming the phase that fills
  it and the Flutter type its provider will be. An empty `@module` emits no
  registration, and the config is asserted against them in **both** directions, so
  adding a provider without re-running `build_runner` is a failing test rather than
  a silently stale committed file.

### Worse

- **Ten registrations do not appear in a generated diff.** Adding a seventh bloc is
  a hand edit that `build_runner` will not show anyone. That is the price of the
  purity gate, taken knowingly and stated in `navigation_injection.dart`'s own
  header.
- **The split is invisible from `injection.config.dart`.** A reader who opens the
  generated file alone sees a graph that does not resolve on its own.

### Neutral / noted

- **`navigation_injection.dart`'s header says "five registrations are now written
  by hand"** and names five. There are **ten** today — the header was last edited
  before the leaderboard and settings registrations landed. Its own "the fifth
  time" / "sixth time" section headings are correct; only the opening count is
  stale. *Reported rather than repeated.*
- The sign-out listener that clears `/`'s state also lives here
  (`_clearHomeStateOnSignOut`), because `AuthBloc` cannot dispatch `HomeCleared`
  (cross-feature, Gate 2) and the reverse is equally closed — `lib/app/` is the one
  directory allowed to know both. It fires on `status == signedOut`, **not** on
  `!isSignedIn`, because `signingIn` is also `!isSignedIn` and the first version
  blanked `/` in the middle of every successful sign-in.

## Traceability

- `AGENT_CONTEXT.md` recorded decision 4 (the walk, and why the fixture is not
  optional), decision 11 (the measured seven violations), decision 17 (the
  `StateError` in the failing direction)
- `AGENT_CONTEXT.md` §7, "A gate that cannot fail is worse than no gate" — why
  the fixture half of decision 4 exists
- `lib/app/di/navigation_injection.dart:33,44-47,68-69,239-258` and
  `configureNavigation` (`:170`)
- `lib/app/di/injection.config.dart:74-139` (the 30 generated registrations)
- `lib/app/bootstrap.dart:68-80` (the four steps, in order)
- `test/app/di/injection_test.dart:454-481`, `test/app/di/navigation_injection_test.dart:335-349`
- `test/support/project_import_graph.dart:60-63,197`
- [`docs/SEAMS.md`](../SEAMS.md) Seam 2
- ADR-0011 (the dependency rule that causes the split), ADR-0013 (the lifetimes)
