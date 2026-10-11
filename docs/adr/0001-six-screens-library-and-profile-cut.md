# ADR-0001: Ship six screens; cut the library and the profile

- **Status:** accepted
- **Date decided:** 2026-10-02
- **Recorded:** 2026-10-11
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `AGENT_CONTEXT.md` §2 decision 1

## Context

The React prototype in `eva/` designs a passage library with a four-card category
grid and a user profile with a journey timeline. The backend has no endpoint for
either: §5's endpoint inventory is the proof, and the in-memory fallback fabricates
non-UUID ids for any group or date other than the seeded one. Building two screens
against endpoints that do not exist means inventing a shape, then defending it.

## Decision

`/login`, `/`, `/reading`, `/quiz`, `/result` and `/settings` are the product.
There is no passage library, no category system, no reflection history and no user
profile. Three consequences follow, and they are consequences rather than
limitations:

- **Routes carry no `:passageId`.** `readings/today/{en,ar}` is the only reading
  endpoint, so the passage is always *today's*.
- **The progress-bead row counts questions, not passages.**
  `HomeScreen.tsx:65` writes `<ProgressBeads total={5} completed={2} current={2} />`,
  which describes passage progress across the grid that was cut;
  `firstUnansweredQuestionIndex` (`lib/features/home/domain/question_progress.dart:45`)
  is fed `TodayReading.questionCount` / `answeredQuestionCount` instead.
- **The avatar on `/` has no profile destination.**

## Alternatives considered

### Ship the library and the profile against a future endpoint

- **Why not:** no endpoint exists. §5 is the measured contract, and `docs/BACKEND-VERIFICATION.md`
  re-verified it live against a running server on 2026-10-11. The screens would be
  built against a fiction, and `docs/DRIFT.md` §5 records what happens to documents
  that describe a codebase which does not exist.

### Keep the `total={5} completed={2}` bead row from the prototype

- **Why not:** the live reading carries **one** reflection question, so a five-bead
  row is fake data that matches nothing the server sends. Recorded decision 27.

## Consequences

### Better

- Every screen has a measured data source, so no screen has a fabricated failure state.
  Recorded decision 123 records that `/login` and `/result` have no failure surface
  *because* of what §2 and §5 permit, not because the wiring was skipped.
- `lib/` has no `Passage`, `PassageCategory` or `ScriptureCatalog` type to maintain,
  and `docs/plans/10-open-decisions.md` §16 records `ScriptureCatalog` as explicitly
  withdrawn rather than merely unbuilt.

### Worse

- **`/settings` has no competing entry point from `/` other than the avatar**, and
  the avatar was inert for four phases.
- The bead clamp in `firstUnansweredQuestionIndex` is **currently unobservable**:
  `beadStateAt`'s rule is `done = i < completed; curr = i === current && !done`
  (`lib/core/design_system/widgets/progress_beads.dart:44`), so with
  `completed == total` every bead is `done` whichever index arrives as `current`.
  The first version of the source file claimed the clamp keeps a bead reading
  "current" when the reading is finished. **It does not**, and the claim was
  **deleted rather than reworded** (`question_progress.dart:18-27`). The clamp is
  kept on a forward-looking argument that is labelled as one.

### Neutral / noted

- **Decision 32's avatar state has since changed, and this ADR records the change
  rather than the decision's own wording.** Decision 32 recorded
  `AppTopBar.onAvatarTap` as *required and nullable with `HomePage` passing `null`*,
  so the avatar rendered disabled with its reason in its accessible name. That was
  true through Phase 8 and is **false today**: Phase 9 gave it a destination and
  `lib/features/home/presentation/pages/home_page.dart:398` reads
  `onAvatarTap: () => context.router.pushPath(AppRoutes.settings)`. The parameter
  is still `required` and still nullable
  (`lib/features/home/presentation/widgets/app_top_bar.dart:106,177`) — the disabled
  arm is still the right rendering for a control with no destination — but `/`
  passes one. **"Visible product debt" is now closed; the disabled arm remains
  tested.**
- **`AGENT_CONTEXT.md` §2's route table is stale**, and this ADR deliberately does
  not inherit it. Measured today: `lib/app/router/app_router.dart:243-264` declares
  **7** `AutoRoute`s (`/login`, `/`, `/reading`, `/quiz`, `/result`, `/settings`,
  `/leaderboard`) plus a `RedirectRoute` for `*`, and
  `lib/core/navigation/app_routes.dart` declares **9** constants — the 7, plus
  `/servant` (declared, deliberately unrouted) and `*`. This is
  `docs/DRIFT.md` §1, still open. The *cut* is not in doubt; only the count is.

## Traceability

- `AGENT_CONTEXT.md` §2 decision 1 (the cut)
- `AGENT_CONTEXT.md` decision 27 (beads count questions; the clamp is unobservable)
- `AGENT_CONTEXT.md` decision 32 (the avatar) — and
  `lib/features/home/presentation/widgets/app_top_bar.dart:156-177` for its current state
- `AGENT_CONTEXT.md` §5, "Endpoints this client uses" — re-verified in
  [`docs/BACKEND-VERIFICATION.md`](../BACKEND-VERIFICATION.md)
- `docs/plans/10-open-decisions.md` §15 (data source) and §16 (`ScriptureCatalog` withdrawn)
- `docs/DRIFT.md` §1 (the stale six-route table)
