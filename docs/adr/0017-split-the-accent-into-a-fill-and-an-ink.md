# ADR-0017: Split the accent into a fill and an ink; diverge `onEmber` from spec for WCAG

- **Status:** superseded by [ADR-0022](0022-full-fidelity-redesign-supersedes-0001.md), 2026-10-13. The LUMEN redesign replaces this decision; `lib/` carries the old values until the plan's Phases 2–6 land it.
- **Date decided:** 2026-10-07 (the original `onEmber` ruling: 2026-10-02)
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` recorded decisions 6 and 153

## Context

One accent value was doing two jobs that pull in opposite directions, and both jobs
are real:

- as a **fill**, `ember` must stay light enough that `onEmber` reads on it — an
  `EvaButton`'s entire label is `onEmber` on `ember`;
- as **text** on a pale surface it must clear 4.5:1, and light `ember` measured
  **2.11:1**.

There is no single value that does both. Darkening `ember` to reach the text floor
gives `#8E5B11`, and `onEmber` (`#3A1E00`) on that is **2.70:1** — the button label
becomes the illegible thing instead. That is not a tuning miss; it is two
contradictory requirements on one token, and it is why "just darken it" was never the
answer.

## Decision

**The accent splits into a fill and an ink, and only the light values differ.**

| token | dark | light | used for |
| --- | --- | --- | --- |
| `ember` | `#E8A33D` | `#D4891A` | fills: buttons, chips, beads, toggles, flame, cursor, glows |
| `emberInk` | `#E8A33D` | **`#845610`** | text, drop caps, verse numbers, meaningful icons |
| `ok` / `okInk` | `#4ECCA3` | `#1A8C6A` / **`#146C52`** | fills / correct-answer text |
| `err` / `errInk` | `#FF6B6B` | `#D63B3B` / **`#B72626`** | fills / error text and icons |

**In dark the pairs are identical *on purpose*.** The accent already clears
**6.97:1** on the worst dark surface, so a second name would be a second way to change
the same value. **The three light goldens are the proof**: switching the ink usages
moved `eva_chip_toggle_light`, `segmented_control_light` and `eva_button_ghost_light`,
and **every dark golden stayed byte-identical**. A token pair that is equal in one
theme and different in the other cannot accidentally change the theme that was
already right.

### Separately: light `onEmber` is `#3A1E00`, not the spec's `#FFF8EE`

Recorded decision 6, and the owner ruled directly: **keep the spec's ember, fix
`onEmber`**. `03-design-system.md:49` gives `#FFF8EE`; measured against WCAG 2.x
relative luminance, `#FFF8EE` on light `ember` `#D4891A` is **2.69:1** — below
AA-large (3:1), let alone AA (4.5:1), so **it fails at every text size** and is not a
large-text-only concession. `#3A1E00` measures:

| against | ratio |
| --- | --- |
| light `ember` `#D4891A` | **5.41:1** |
| light canvas `#F0EEFF` | **13.46:1** |
| dark `ember` (the token's dark value `#0D0A04`) | **9.17:1** |

**The trap for anyone revisiting it.** Darkening the value *while it stays light*
makes it worse, not better: the ratio falls **monotonically** to about **1.05:1** as
the value approaches ember's own luminance (`#D09040`) and only recovers on the far
side. It has to cross over to a dark ink — which is also the role the token already
has in dark mode, so the two palettes agree about what the token *is*.

**This is the only token in the design system that diverges from
`docs/plans/03-design-system.md`, and that document is knowingly out of date on this
one value.** It was not edited: AGENT_CONTEXT §8.6 gives `docs/plans/` a dedicated
owner. If that owner revises `03-design-system.md` §5.1, recorded decision 6 is the
change request.

## Alternatives considered

### One `ember` for both jobs

- **Why not:** the two requirements are in direct conflict, and the measured cost of
  resolving it toward either end is a visible illegibility — the button label or the
  reader's own name.

### Two names in **both** themes

- **Why not:** nothing is being solved in dark. `ember` already clears 6.97:1, so
  `emberInk` there would be a second name for the same value and a second place for
  a future edit to drift. The tokens exist in `EvaColors.dark()`
  (`eva_colors.dart:76`) because the *slot* must exist; its value equals `ember`'s on
  purpose.

### Keep `#FFF8EE` and enlarge the label

- **Why not:** the failure is at **every** text size, so no size makes it pass.

## Consequences

### Better

- **Twenty usages moved to the ink token and forty-four stayed on the fill.** The
  split is by role, not by widget: the flame painter, the toggle knob, the cursor,
  progress beads, chip and pill borders, avatar rims and every glow are still
  `ember`.
- **Contrast is now a gate with a ledger, not a habit.**
  `test/core/design_system/tokens/text_contrast_gate_test.dart` checks the **worst**
  surface rather than the nominal one — `GlassSurface` composites over whatever is
  beneath it, so a token that passes on `canvas` and fails on glass is the common
  failure. Its drift assertion is the part that pays: fixing the gate's own surface
  model moved four ledger entries (`ink3` 2.02→2.08, `ember` 2.05→**2.11**, `ok`
  3.03→3.12, `err` 3.33→3.43) and `no recorded ratio has drifted` failed on every one
  (recorded decision 154). **A ledger is only worth having if it notices when the
  measurement changes underneath it.**

### Worse

- **There are two ember tokens in the light palette and a reader must pick the right
  one.** Nothing in Dart can enforce that; it is a review obligation, which is why
  the ledger and the goldens exist.
- **The light ember/as-text measurement is recorded in two places and one of them is
  stale.** `text_contrast_gate_test.dart:188` carries the corrected **2.11:1** and the
  drift comment at `:175` records the `2.05 → 2.11` move, but two doc comments in
  `eva_colors.dart` (`:123` and `:213`) still say **2.05:1**. The value did not move;
  the measurement underneath it did. *Reported, not silently repeated.*

### Neutral / noted

- **`ink3` was demoted rather than fixed.** Recorded decision 149: it fails contrast
  as text in **both** themes, no gate looked, and it was moved to the two things WCAG
  exempts, with 21 runs moved to `ink2`. That is a second "the token was wrong and
  the role was narrowed instead" decision, in the same file, by the same logic.

## Traceability

- `AGENT_CONTEXT.md` recorded decision 6 (light `onEmber` is `#3A1E00`; the user's
  ruling; the `docs/plans/` divergence), decision 153 (the fill/ink split and the
  golden evidence), decision 149 (`ink3`), decision 154 (the gate measured the wrong
  surface, and the ledger caught it)
- `lib/core/design_system/tokens/eva_colors.dart:71-80,119-130,171-186,207-222`
- `test/core/design_system/tokens/text_contrast_gate_test.dart:109-110,175,188`
- `test/core/design_system/tokens/eva_colors_test.dart:112` (the 2.30:1 snack-bar
  action pairing)
- `docs/plans/03-design-system.md:49` (the spec value that diverges)
- ADR-0016 (the seven sub-AA light pairings this closed one of)
