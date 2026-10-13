# ADR-0016: One dark glassmorphic design system with five bundled families and zero elevation

- **Status:** superseded by [ADR-0022](0022-full-fidelity-redesign-supersedes-0001.md), 2026-10-13. The LUMEN redesign replaces this decision; `lib/` carries the old values until the plan's Phases 2–6 land it.
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2 decisions 6 and 7, recorded decisions 5 and 7

## Context

§2 decision 6 commits the client to a dark glassmorphic design system per
`docs/plans/03-design-system.md`, including the five mandatory performance
mitigations in `docs/plans/09-quality-gates.md` §13. Phase 1 built the token layer
and the theme; three sub-decisions inside it are worth stating separately because
each one had a wrong answer that was available and argued for.

## Decision

**Five font families, bundled as static TTFs.** Cormorant Garamond, EB Garamond,
DM Sans, Amiri and Space Mono — **twenty** `.ttf` files under `assets/fonts/`,
declared in `pubspec.yaml:119-176`. Two properties are deliberate:

- **Instanced to the exact weights the design system uses**, so Flutter never
  resorts to synthetic bolding. `pubspec.yaml` declares real faces at 400/500/600/700
  (plus 800 for DM Sans, plus italics where the design system asks for them).
- **Bundled, not fetched.** §5.2's actual requirement is that first paint is not
  blocked on a network fetch, and the bundling meets it — `docs/plans/09-quality-gates.md`
  §11 names an HTTP font fetch as the cause of flaky goldens.

**Amiri is the only bundled family that renders Arabic** — which is the load-bearing
fact behind ADR-0018.

**Type sizes are the Material 3 defaults, by decision (recorded decision 5).**
§5.2 specifies no size, weight or line height, so
`eva_typography.dart:89` reads the geometry from
`Typography.material2021().englishLike` — the same source `ThemeData` reads when it
localises a theme. The file's job is exactly the decision §5.2 *does* make: **which
family renders each slot, and in which ink.** A token table that also restated the
sizes would be a second copy of the framework's scale, free to drift from it.

**All elevations are `0`, by decision (recorded decision 7).** `03-design-system.md`
has **no elevation table at all**, and the React prototype has no z-axis either:
every `box-shadow` there is either a zero-offset ember glow or the single glass
ambient that became `EvaColors.glassShadow`. So "no Material elevation anywhere" is
the faithful reading, and it is the only value that can be stated **without inventing
a ramp**. Layering is carried by `line`, the glass triple, and that one ambient.

## What the suite can and cannot see about elevations

This is worth stating precisely because a doc comment here once overclaimed it.

Every token is `0` (`eva_elevations.dart:77-106`: `none`, `card`, `appBar`, `dialog`,
`bottomSheet`, `floatingActionButton`, `snackBar`). So `elevation:
EvaElevations.card` and `elevation: 0` compile to the **same program**. **No test can
distinguish reading the token from writing the literal**, and a test claiming to is
asserting that two identical programs differ.

What the suite *does* assert has real teeth: **every elevation-bearing `ThemeData`
field resolves to `0`**, checked over an **enumerated inventory**
(`test/core/design_system/theme/eva_theme_test.dart:155-241`, seventeen fields with
`expect(elevations.length, 17)` at `:241`). That catches the two failures that can
actually happen — deleting a line, which lets `null` through, and pinning Material's
own default, which passes it straight through — and catches a new themed surface
that forgets the class.

**`modalElevation` is the one that bites hardest** (`eva_theme_test.dart:181-182`),
because a modal sheet resolves it first and would otherwise sit at Material's **24**.
`EvaElevations.none` is the token for the five surfaces §5 names no role for: drawer,
popup menu, bottom bar, navigation bar, and a modal bottom sheet.

## Alternatives considered

### Invent a five-step elevation ramp to match the prototype's shadows

- **Why not:** there is no ramp to transcribe. Every shadow in `eva/src` is a glow
  or the glass ambient, and inventing values would create a token table with no
  source — the failure `docs/DRIFT.md` §5 catalogues.

### Restate Material 3's type scale in `eva_typography.dart`

- **Why not:** a second copy of the framework's scale, free to drift from the one
  `ThemeData` reads at runtime. Recorded decision 5.

### Wire `google_fonts`, as `docs/plans/03-design-system.md` §5.2 words it

- **Why not:** the bundling already meets the plan's stated requirement, and
  `google_fonts` would reintroduce the fetch — and a dependency (ADR-0011).

### Synthesise bold rather than instancing a real weight

- **Why not:** synthetic bolding changes advance widths and can shift a golden; the
  twenty faces are the cheap half of the decision and the stable half.

## Consequences

### Better

- **Goldens resolve offline and identically on every machine**, because the bytes
  that render them are in the repository.
- **The elevation decision has a named, testable inventory** rather than a
  convention, and Material's stock shadows — 1 on a `Card`, 8 on a
  `PopupMenuButton`, 24 on a modal sheet — are all explicitly zeroed.

### Worse

- **Recorded decision 5 names a consequence this decision accepted and never
  resolved:** `displayLarge` is **57sp** where the prototype's largest type is 34px,
  and at 1.22× text scaling on a 320px screen it wraps to four lines, which
  `09-quality-gates.md` §14 forbids. The decision required Phase 3 to own one of two
  things — clamp the display end, or amend §14 to state the exception — and the
  suite has `viewport_matrix_test.dart` covering the surface. *Carried forward, not
  silently closed.*
- **Seven light-palette pairings `eva_theme.dart` wires measure below 4.5:1.** They
  are enumerated, floored and flagged in `eva_colors_test.dart` rather than fixed,
  because the owner ruled on `onEmber` only and that phase could not move another
  token. One of them — `ember` as the snack-bar **action** colour on `raised`, at
  **2.30:1** — is below even AA-large. ADR-0017 closed the `onEmber` half.

### Neutral / noted

- **`NeuralScaffold` has no elevation token of its own** — recorded decision 7 calls
  this a gap owned elsewhere: if it needs one, the value must come from this class or
  from a spec table that does not exist yet.

## Traceability

- `AGENT_CONTEXT.md` §2 decision 6 (the system), §2 decision 7 (`Result<T>`),
  §3 (shared kernel)
- `AGENT_CONTEXT.md` recorded decision 5 (Material 3 sizes), decision 7 (all
  elevations zero, the seven sub-AA light pairings, the 57sp consequence)
- `pubspec.yaml:119-176`, `assets/fonts/` (twenty `.ttf` files)
- `lib/core/design_system/tokens/eva_typography.dart:1-17,71-89`
- `lib/core/design_system/tokens/eva_elevations.dart:77-106` and its header
- `test/core/design_system/theme/eva_theme_test.dart:155-241`
- `docs/plans/03-design-system.md` §5.1–§5.3, `docs/plans/09-quality-gates.md` §13
- ADR-0011 (the `google_fonts` refusal), ADR-0017 (the one token that diverges from
  spec), ADR-0018 (why Amiri matters), ADR-0019 (the five mitigations)
