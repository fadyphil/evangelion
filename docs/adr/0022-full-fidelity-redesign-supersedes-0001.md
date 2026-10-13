# ADR-0022: Ship the LUMEN redesign at full fidelity, and supersede ADR-0001

- **Status:** accepted
- **Date decided:** 2026-10-13
- **Recorded:** 2026-10-13
- **Deciders:** the project owner, with AI implementers and reviewers
- **Authority:** `docs/agents/AGENT_CONTEXT.md` §2 decision 1, amended by this record
- **Supersedes:** [ADR-0001](0001-six-screens-library-and-profile-cut.md)

## Context

`eva/redesign.html:1244` names **seven** routes in one object — `login, home,
reader, quiz, journey, settings, board` — and each resolves to a `<section
class="route">`: `rLogin:503`, `rHome:513`, `rReader:540`, `rQuiz:562`,
`rJourney:576`, `rBoard:612`, `rSettings:638`. **ADR-0001 cut the library and
the profile**, and the redesign is where both live: `rJourney` is the profile,
and the library is the carousel (`:536`) under its "6 scrolls · 4 open" label
(`:535`). The board is **not** cut — the client already ships it, as
`/leaderboard` — and `/result` goes the other way: the redesign has no result
*route* at all, only the modal at `:718` that `showResults()` (`:1433`) reveals
over the quiz.

The backend has **no** endpoint for a profile, a book catalogue, medals, a
cheer, a share, or notes. That is measured, not inferred: the sibling checkout
registers **14** routes under `/api/v1` and none of them is one of those six —
`readings.routes.ts` (6), `streak.routes.ts` (2), `leaderboard.routes.ts` (1),
`submissions.routes.ts` (1), `admin.routes.ts` (3), `ai.routes.ts` (1).
**`GET /leaderboard` and `GET /streak` are real**, and they land on the
redesign's Communion and streak surfaces. So the question was never "does the
data exist" but "what ships against data that does not".

The choice made was **full fidelity over a visual-layer-only scope**. That is a
reversal of a locked decision, so what follows is the fiction table: every
surface the redesign specifies, whether a measured endpoint serves it, and what
would have to exist to stop it being a stub.

### The fiction table

`eva/redesign.html` contains **zero** network and storage calls:
`rg -n 'fetch\(|XMLHttpRequest|axios|localStorage|sessionStorage' eva/redesign.html`
returns nothing. It is a pure local artefact, so every number in it is invented
and "real" below is a claim about *our* mapping, not about the prototype's.

| Element | Real or stub | Replaced by |
| --- | --- | --- |
| Streak chip `:516`, hero number `:589` | **real** | `GET /streak/summary` → `current_streak` |
| Communal rows, podium `:627` | **real** | `GET /leaderboard?window=` |
| Scope, week / month / all `:620` | **real** | `window=weekly\|monthly\|all_time` (`leaderboard.routes.ts:17`) |
| Metric switch, light ↔ streaks `:623` | **real** | `score` / `current_streak` per row |
| You-row `:629` | **real, with a gap** | `my_standing` is `{rank, score}` only — the row's *name* needs the reader's own entry in `leaderboard[]` |
| Verse of the day `:519` | **real** | deterministic pick from `GET /readings/today` |
| Last light `:524` | **real** | `GET /streak` → `history[0]`, **unused by the client today** |
| Leaderboard countdown `:618` | **stub** | the response carries no reset time — only the window name |
| Month / all-time scores | **stub** | the prototype scales the weekly number; the server scores each window alone |
| Library book list `:536` | **stub** | hardcoded; **no endpoint enumerates books** — but see the correction below |
| Your own name `:587` | **stub** | a real `/me` endpoint |
| Medals `:597` | **stub** | an achievements table |
| Cheer `:1119` | **stub** | a POST endpoint; the prototype's is a local `Set` (`:1066`) |
| Starfield `:1131` | **stub (local)** | a stars table |
| Sealed books `:1032` | **rule stub, data real** | per-book completion from `GET /streak` `history` |
| Share `:714`, notes `:715` | **cut** | — |

**Four rows are narrower than a first pass claims, and each narrowing is a
measurement.**

* **The countdown is not served, and re-deriving it is not a free choice.**
  `GET /leaderboard` returns exactly five keys — `group_id`, `window`,
  `total_ranked`, `my_standing`, `leaderboard`
  (`leaderboard.routes.ts:116-122`) — and none is a reset instant. The
  prototype's `resetLeft()` (`:1073-1076`) computes the next **local** Monday
  00:00. The server's weekly bucket is an **ISO 8601 week number**
  (`redis/leaderboard.service.ts:20-26`: shift to the week's Thursday, then
  `ceil((daysSinceYearStart + 1) / 7)` over a `Date.UTC` year start), and
  `getKey` (`:29-36`) builds one ZSET per bucket. ISO weeks start on a Monday,
  so the two agree most of the year and diverge twice: at a year boundary, where
  ISO week 1 is the week holding the first Thursday, and across a UTC/local
  offset. A countdown the client computes is therefore a re-implementation of a
  private server function that can be off by days in those windows — which is
  the "observed vs defensive" line `CONTRIBUTING.md` draws, crossed. **Stub, and
  the cheapest honest rendering of a stub here is a local week boundary stated as
  approximate, not a number presented as the server's.**
* **The library's *catalogue* is the fiction, not its text.** The prototype
  hardcodes four books in `BOOKS` (`:1004-1031`) and two in `SEALED`
  (`:1032-1035`), and the plan hardcodes the Bible's 66. But
  `GET /bible/verses/{ar,en}` (`readings.routes.ts:260,300`) is a real
  per-book passage endpoint, and in the documented dev run the in-memory
  fallback loads **31,104 verses across exactly 66 books** from
  `src/db/bible_data.json` (`memory_db.ts:151-166`). So passage text is real
  per book; what is invented is the *catalogue* — order, names, chapter
  counts, and completion.
* **Sealed books have real data and an invented rule.** `GET /streak` returns
  `history[]` with `book_number`, `reference`, and `is_completed` per reading
  (`streak.service.ts:88-145`). The *unlock* rule — "finish Isaiah to unseal
  Acts" (`:1033`, `:733`) — is invented, and the history is bounded to the last
  **30** scheduled readings, so it covers the scheduled subset of books and
  nothing else.
* **The window's other two scores are invented, and the prototype says so in one
  line.** `lightOf(p)` (`:1067`) returns `p.wl` for the week and *multiplies* it
  by `4.35` for the month and `38.6` for all time. The server keeps three
  independent ZSETs — `all_time`, `monthly:{YYYY-MM}`, `weekly:{ISO-week}`
  (`redis/leaderboard.service.ts:29-36`) — and scores each from real submissions,
  so the prototype's month figure is a number no Redis key ever held. The
  `?window=` parameter is real; the *values behind two of its three options* are
  not.

**The reader's own name is a stub, with one partial exception.** There is no
`/me`. The client's own source is the constant
`kSeedDisplayName = 'David Mina'`
(`lib/features/auth/data/datasources/auth_local_data_source.dart:104`), and the
redesign's `Mariam Hanna` (`:587`) is a literal. `GET /leaderboard` **does**
return `full_name` per ranked row (`leaderboard.routes.ts:59`), which the client
already maps (`leaderboard_mapper.dart:280`) — so a ranked reader is nameable,
and a reader who is not ranked is not.

## Decision

The client ships the LUMEN redesign as `eva/redesign.html` specifies it, and
the fiction table above is the accepted price. Seven routes, and the arithmetic
is worth stating because it is not "two new screens": **six** are already
shipped — `/login`, `/`, `/reading`, `/quiz`, `/settings`, and the board, which
the client calls `/leaderboard` and the redesign calls `/communion`. `/journey`
(the profile `rJourney`) is the seventh. `/result` leaves the route table and
becomes the modal the redesign already drew at `:718`. The library carousel
returns to `/`.

Every stub sits behind a repository port, so replacing invented data with a
real endpoint is a change to one adapter and no change to a screen. **No screen
may render a hard-coded reader, medal, cheer or star**; the fiction lives in data
sources, which is where §2 decision 3 already put the seeded session.

**`GET /streak` is adopted alongside `/streak/summary`.** The client reads
`/streak/summary` and nothing else
(`lib/features/reading/data/datasources/streak_remote_data_source.dart:4`),
and `/streak`'s `history[]` is the only measured source for "last light", the
Journey rings, and any per-book completion. It costs one more response shape.

## Alternatives considered

### Keep six screens and restyle only

- **Pros:** ADR-0001 stands, `docs/DRIFT.md` §1's open item about the route
  table never opens, and every screen keeps a measured data source — so no
  screen acquires a fabricated failure state.
- **Cons:** it is not the design. `rJourney` (`:576`) and the carousel (`:536`)
  are the two screens the redesign is built around; the dock (`:702-708`) has a
  five-tab bar whose Journey and Communion tabs point at them. Restyling the
  remaining five leaves a screen that navigates to nowhere.
- **Why not:** the brief is fidelity. A visual-layer-only scope was the
  default because the data was assumed to be missing; the measurement above
  shows most of it is present, and the part that is not is now enumerated,
  priced and ported rather than avoided.

### Build the missing backend endpoints first

- **Pros:** every row above becomes real, and the fiction table collapses to
  nothing. The client never ships a surface backed by invented data.
- **Cons:** the backend is a separate project, read-only by
  `CONTRIBUTING.md` **Hard constraints** and by AGENT_CONTEXT §8, and six new
  endpoints is a backend project of its own — a `/me`, an achievements table, a
  cheer POST, a notes store, a book catalogue, a stars table.
- **Why not:** the hard constraint is explicit: "If a task seems to require a
  backend change, **stop and escalate**." Escalating the whole redesign to a
  change in a repository this one does not own would make the client's
  delivery hostage to work nobody here can do.

### Ship the two new screens as clearly-labelled prototypes

- **Pros:** nothing invents itself as real. A "sample data" banner is honest
  about every stub, and the six measured screens ship first.
- **Cons:** it ships a second client. A prototype with fake data and a real
  client with the same screens is two things to keep in step, and the one
  whose data is invented is the one a reader mistakes for the product.
- **Why not:** the fiction table achieves the honesty at lower cost. It is
  one page a reviewer reads, it names the endpoint each stub waits for, and it
  does not fork the app. **Rejected in favour of ports, not banners** — a
  stub behind `SkyRepository` is replaced by an adapter; a stub behind a banner
  is replaced by a release.

### Ship the visual layer now and the two screens in a later phase

- **Pros:** the palette, shader, dock and typography land on the screens that
  already exist, so the font and token work is reviewable in isolation.
- **Cons:** it is the rejected first option with a delay attached, and it
  leaves the two records with **two** statuses: `superseded` for the palette
  and `accepted` for the screens, which is a distinction a reader has to
  reconstruct.
- **Why not:** the phases already sequence the work. The plan's Phase 2 through
  Phase 6 are ordered, so a separate "visual first" decision adds a status to
  track and removes nothing.

## Consequences

### Better

- **§2 decision 1 no longer says "Six screens."** It now names the seven and
  cites this record, which retires the `AGENT_CONTEXT.md:27` row in
  `ROADMAP.md`'s docs-debt table — the one that said the authority document
  under-counted while the code did not. **DRIFT §1 is *not* closed by this
  record**: its claim is the route *table*, which is deliberately not written to
  a future state, so the seven-`AutoRoute` count stands until Phase 5.
- The five-tab dock (`:702-708`) becomes implementable, and `/communion` is
  already a shipped screen, so the tab bar is five real destinations rather
  than five aspirations.
- `GET /streak`'s `history[]` replaces a fabricated "last light" card and gives
  the Journey rings a measured denominator. Recorded decision 27's "beads count
  questions" stays true; the *reason* is now visible on the screen.
- `medals`, `cheer`, `stars` and `notes` are named, ported and swappable. A
  reader of `lib/` can see which rows of the fiction table are still open
  without opening this ADR.

### Worse

- **This is a visible lie to a user until the backend catches up.** A reader
  sees `4 / 12` medals (`:597`) and a starfield (`:1131`) that no server has
  heard of. The fiction table is how *we* know; it is not in the product.
- **`/result` is retired**, and
  [`ADR-0015`](0015-result-is-not-deep-linkable.md) — "accept that `/result`
  cannot be deep-linked" — records a decision about a route that stops
  existing. The modal is the redesign's own arrangement (`:718`), so the ADR is
  superseded in substance, and `ResultRoute` goes with it.
- **`GET /streak` adds a response shape to transcribe, and every stub adds a
  fixture this backend cannot produce.** A mapper for medals or cheer is a
  contract the server has never honoured, which is the exact class AGENT_CONTEXT
  §5 trap 1 warns about. Those fixtures must be labelled as transcriptions, as
  `test/support/contract_payloads.dart` already is for
  `POST /readings/:id/submit`.
- **A stub behind a port is still stubbed.** The port makes it swappable and
  does not make it correct, and a clean gate run will say nothing about whether
  the medals are real.

### Neutral / noted

- **ADR-0016, ADR-0017 and ADR-0019 are superseded by this record**, because
  the redesign replaces the palette, the accent split and the per-screen blur
  budget. **ADR-0018 is not**: the redesign is bilingual in the same way, and
  the two-arms-two-questions font resolution is untouched by it. Superseded
  means replaced, not yet implemented — Phases 2 through 6 carry the code
  across, so `lib/` holds the old values until then.
- **`GET /leaderboard` is already wired, with an opt-in stub.**
  `DioLeaderboardRepository` is the default and the stub needs
  `--dart-define=USE_STUB_LEADERBOARD=true`
  (`lib/app/di/modules/leaderboard_module.dart:73`), so the board is the one
  redesigned screen whose data is real on **both** sides — and the prototype's
  `veil` toggle (`:1070`), which anonymises other readers, needs no endpoint
  because it is a rendering choice over rows that already arrived.
- **§2's route table is not amended to a future state here.** It lists what
  `lib/app/router/app_router.dart:243-261` registers today. `/journey` and
  `/communion` arrive with the code that registers them, and the table changes
  in that change, with the measurement that establishes it.

## Traceability

- `docs/agents/AGENT_CONTEXT.md` §2 decision 1, amended by this record — the
  cut is reversed and this ADR is the authority for it
- `docs/agents/AGENT_CONTEXT.md` §2 decision 3, "Login and onboarding are
  UI-only" — the reason a reader's name is a constant and not a response
- [`ADR-0001`](0001-six-screens-library-and-profile-cut.md) — superseded; its
  Context named the same missing endpoints and drew the opposite conclusion
  from the same measurement
- [`ADR-0015`](0015-result-is-not-deep-linkable.md) — its subject route is
  retired
- [`docs/BACKEND-VERIFICATION.md`](../BACKEND-VERIFICATION.md) — §5 re-measured
  live on 2026-10-11; the endpoint inventory above is the same checkout at
  `HEAD=4a1c834`
- `eva/redesign.html:1244` (the seven routes) · `:503`, `:513`, `:540`, `:562`,
  `:576`, `:612`, `:638` (the seven sections) · `:516`, `:589` (streak) ·
  `:519` (verse of the day) · `:524` (last light) · `:535`, `:536` (library) ·
  `:587` (own name) · `:597` (medals) · `:605` (Communion row) · `:618`
  (countdown) · `:620`, `:623` (scope and metric) · `:627`, `:629` (podium,
  you-row) · `:702-708` (the five-tab dock) · `:714`, `:715` (share, notes) ·
  `:718` (the result modal) · `:1032` (sealed books) · `:1066` (the cheer
  `Set`) · `:1067` (the window scaling) · `:1073` (the local countdown) ·
  `:1119` (cheer) · `:1131` (the sky) · `:1433` (`showResults`)
- `docs/superpowers/plans/2026-10-13-lumen-redesign.md` Task 0.2 — the draft
  fiction table this one corrects against the backend
