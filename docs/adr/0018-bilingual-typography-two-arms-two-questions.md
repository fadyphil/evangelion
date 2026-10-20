# ADR-0018: Resolve the Arabic family with one function plus per-arm switches — two different questions

- **Status:** accepted — under review. The decision is in effect today and testable today. **It is the one record the LUMEN redesign does *not* re-examine**: [`ADR-0022`](0022-full-fidelity-redesign-supersedes-0001.md) supersedes ADR-0016, ADR-0017 and ADR-0019 and leaves this one standing, because the redesign is bilingual in the same way and does not touch the two-arms-two-questions resolution. See [`ROADMAP.md`](../../ROADMAP.md), **Design overhaul**.
- **Date decided:** 2026-10-04
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` recorded decisions 54, 66, 71, 74, 75, 77, 79

## Context

**The defect was under-counted.** `docs/plans/01-source-analysis.md` §2 row 2 said
**two** Arabic sites needed the non-mono family. The source says **nine** (recorded
decision 54): in the prototype's Arabic reading screen, the metadata row, the CTA
caption and **seven `<sup>` verse markers**. The two **English-only** sites — the
prototype's input label and its category-chip label, both `Space Mono` — stay in Space
Mono, which is the point of the split. **The redesign writes the same split itself**:
the verse marker is in the mono family on the English arm (`redesign.html:170`) and
the Arabic arm is Amiri (`redesign.html:140`), and the metadata row is the same way
(`redesign.html:146` against `redesign.html:148`).

**And the nine were the floor, not the ceiling** (recorded decision 71). §14 requires
an accessible name for every icon-only control, and the prototype's four top controls
were bare `<button>`s with **no label at all** — the reader's back button and its `Aa`
and bookmark controls, on both arms. **The redesign still leaves two of them
glyph-only** (the reader app bar's `‹` and `✦`, `redesign.html:542` and
`redesign.html:544`), so §14's requirement for an accessible name forced **three more
Arabic strings** into this client that the prototype never wrote, and they rendered
through `IconActionButton`'s `Tooltip`, whose `Tooltip(message: …)` carried **no
`textStyle`** — Flutter resolved `null` to `bodyMedium`, measured **`DMSans`**, which
carries no Arabic glyph at all. Measured on the shipped `ReadingPage` at `Locale('ar')`
with the long press held: `رجوع` produced **4** tofu boxes, `حجم الخط` **7**, and
`إشارة مرجعية — غير متاح في هذه النسخة` **19** — while every other Arabic run on the
screen was Amiri.

## Decision

**Two mechanisms resolve "which family", because there are two different questions.**

| the run | where its arm comes from | the mechanism |
| --- | --- | --- |
| payload content — the preview, the citation, the CTA label, the caption, the verse marker | `TodayReading.language` / `ReadingLanguage`, **the fact the server sent** | the existing `*FamilyFor` switches, plus `EvaButton.labelFamily` and `IconActionButton.tooltipFamily` |
| the app's own chrome — every label, link, hint, error, tooltip and status line | the ambient locale, because there is no payload | `arabicAware(style, Directionality.of(context))` |

**This is not a duplicate source of truth, and the distinction is load-bearing.**
Zero lines of decision 54, 66 or 71 changed when `arabicAware` was introduced. The two
arms are **different facts**, and they survive each other disagreeing — which matters
if a locale switch and a fetch ever race. Recorded because a reader who sees two
mechanisms for one value will otherwise unify them, and unifying them means deleting
one.

### Why one function beat parameter threading

`TextLink`, `SocialAuthButton`, `HairlineDivider` and `EvaTextField` have **no arm to
pass**. There is no payload behind a chrome label. Decisions 66 and 71 made
`EvaButton.labelFamily` (`eva_button.dart:202`) and `IconActionButton.tooltipFamily`
(`icon_action_button.dart:27`) **required** precisely because their callers *do* hold
the arm — and "requiredness is the whole value" only works where the argument is
answerable. On a `TextLink` it is not: the honest required argument is the locale,
which is the ambient direction. Parameter threading would have added a required
argument to six design-system widgets plus a family expression at every feature run
site, in order to reach a value the design system could have read for itself.

### The dependency this rule rests on, stated because it is one

**RTL implies Arabic because `lib/app/app.dart:255` declares exactly
`supportedLocales: <Locale>[Locale('en'), Locale('ar')]`, and only `ar` is
right-to-left.** A third, non-Arabic RTL locale would make the rule false. The
failure would be **loud**: `arabic_typography_test.dart` asserts every rendered
Arabic run is in Amiri **and** that Amiri carries every character on screen, so a
Hebrew run in Amiri fails the second assertion on the first frame it is painted.

### The deliverable was the gate, and it is a declared set

`test/arabic_typography_test.dart` runs over all six screens.
`expectedArabic` is compared for equality in **both** directions, because **a count
cannot catch the failure that matters most**: a run silently vanishing makes "every
Arabic run is Amiri" **vacuously true**, and §7's "a gate that cannot fail is worse
than no gate" has never had a quieter costume. A declared list of the runs that
*should* be there cannot be satisfied by their absence, and a new run is red by name.

**Every declared list is built from the string tables and the payload fixtures, not
typed.** The first version was Arabic literals and **four of them were wrong on the
first run** — a missing combining mark is invisible in a diff, and the failure then
reads as "the widget rendered the wrong string" rather than "the test typed the wrong
string".

## Alternatives considered

### A `TextTheme` whose Arabic slots resolve to Amiri

- **Why not:** **a framework fact, not a preference.** `MaterialApp` takes one
  `theme:` and one `darkTheme:` and has **no per-locale theme hook** (decision 74), so
  there is nowhere to put a second text theme for the engine to choose between.
  Every design system that appears to do this is switching one at runtime in
  `MaterialApp.builder` — which would swap `TextTheme` for the whole screen.

### Read `Localizations.localeOf` inside a Tier-1 primitive

- **Why not:** an English label and an Arabic one would travel the same invisible code
  path. `arabicAware` takes the direction **as a parameter**, so every call site names
  the ambient source in full, and `lib/` still contains **no `Directionality` this
  client installs** and **no `startsWith('ar')`**.

### Unify the two mechanisms on `arabicAware`

- **Why not:** it would delete decisions 54, 66 and 71, and with them the guarantee
  that a payload's own arm survives the ambient locale disagreeing with it.

### A shape test on each run's own script

- **Why not:** recorded decision 29 rejects one for this widget family for a measured
  reason — it breaks on a verse opening with a numeral or a bracket, and §5's live
  payload opens one behind a `‹Verily`.

## Consequences

### Better

- **`EvaButton` renders its CTA caption in Amiri on the AR arm without a second button
  type** — the knob is on the button, not on a `StickyCta`-local `TextButton` that
  duplicates the focus ring, the disabled state and the hit target.
- **The server's own text now renders.** `Failure.message` is the **server's** text
  (decision 77) — `api_error_mapper.dart` writes `decoded?.message ?? 'HTTP $status'`,
  and every one of the eight observed bodies carries the server's message. Amiri's
  measured coverage includes U+0600–U+06FF, both Arabic Presentation Forms blocks,
  all 95 printable ASCII and all 96 Latin-1 codepoints, so it renders whichever script
  arrives; under LTR it is exactly the Latin face it always was. **The claim was
  deleted rather than repaired, because the reasoning was the defect.**

### Worse

- **The gate's own mechanism had to be fixed five times, and every bug was found
  because it disagreed with the engine.** A `Tooltip` paints nothing until a gesture,
  so the walk is `Future`-returning; a style-less `TextSpan` inherits its parent's; one
  that styles **some** fields inherits the rest; the repair's base/other order in
  `TextStyle.merge` was backwards; and the redundant `find.byType(Text)` pass reported a
  *different* family than the `RichText` pass did. **A correct render reported as tofu
  is worse than no gate**, because it trains its readers to ignore it.

### Neutral / noted

- **The "three of six screens are vacuous" state was real and has been overtaken.**
  When the gate was written, `/quiz`, `/result` and `/settings` rendered
  `Placeholder for …` and each passed a `vacuousBecause` naming why. The mechanism
  survives and is enforced — `vacuousBecause` is **required exactly when the list is
  empty and must be null otherwise**
  (`test/support/arabic_typography_gate.dart:290-341`) — and **all seven lists in
  `arabic_typography_test.dart` are non-empty today** (`vacuousBecause: null` at
  `:311,501,546,631,717,831,895`), because those three screens were written.
- **Forcing `arabicAware` to `return style` turns 8 tests red and correctly does not
  turn `/reading`'s main arm red** — its Arabic families come from decision 54's
  per-arm switches, because `/reading` was never broken. A gate that went red
  everywhere would have been the *less* honest one.

## Traceability

- `AGENT_CONTEXT.md` recorded decision 54 (nine sites, not two), 66 (`labelFamily`
  required), 71 (the three tofu tooltips), 74 (`arabicAware` and the four rejected
  alternatives), 75 (the two-arm table), 77 (`Failure.message` is the server's), 79
  (the gate, the declared set, the built lists)
- `lib/core/design_system/tokens/eva_typography.dart:200-201,246-249`
- `lib/core/design_system/widgets/eva_button.dart:202`,
  `lib/core/design_system/widgets/icon_action_button.dart:27`
- `lib/app/app.dart:255` (`supportedLocales`)
- `test/arabic_typography_test.dart:143-144,311` and
  `test/support/arabic_typography_gate.dart:290-341`
- the prototype's Arabic reading screen — its metadata row, its CTA caption and its
  seven `<sup>` verse markers: **the nine sites**. The redesign's own split is at
  `redesign.html:170` (the verse marker, in the mono family) against
  `redesign.html:140` (the Arabic arm's Amiri)
- ADR-0016 (Amiri is the only bundled family that renders Arabic)
