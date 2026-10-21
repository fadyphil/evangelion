# ADR-0026: The servant portal ships, and the role gate is advisory

- **Status:** accepted
- **Date decided:** 2026-10-21
- **Recorded:** 2026-10-21
- **Deciders:** the user, with AI implementers and reviewers
- **Authority:** `docs/agents/AGENT_CONTEXT.md` §2 decision 5

## Context

The user reversed AGENT_CONTEXT §2 decision 5 on 2026-10-21. That row read
"**No servant/admin portal.** Those backend routes stay untested from the
client", and the reversal makes the backend's admin, AI and report routes client
surface for the first time — `POST /api/v1/admin/readings/schedule`
(`src/modules/admin/admin.routes.ts:54`), `POST /api/v1/admin/questions/commit`
(`admin.routes.ts:235`), `POST /api/v1/admin/questions/ai-generate`
(`src/modules/ai/ai.routes.ts:14`) and `GET /api/v1/servant/reports/daily`
(`admin.routes.ts:331`) were all callable over HTTP, and this client had called
**none** of them.

**The backend enforces no role, and that is what decides what the client's gate
can be.** `src/middleware/identity.middleware.ts:24` parses `X-User-Role` and
`:31` assigns it to `request.user.role`, and **nothing reads it again**:
`rg 'user\??\.role' src/` returns **no matches** and `rg '403' src/` returns
**no matches**, across all **seventeen** route registrations in `src/` —
fourteen `fastify.<verb>(` calls under the `/api/v1` prefix
(`src/app.ts:140`) plus `/json`, `/documentation` and `/health` at
`src/app.ts:94,99,107`. The role union the client mirrors is the backend's own
(`identity.middleware.ts:5`: `'kid' | 'viewer_servant' | 'admin_servant'`).

There is also **no authentication endpoint** (§2 decision 3 — "Login and
onboarding are UI-only"), so a role is a **local choice on the login screen**
rather than a fact the server has sent.

## Decision

**The `servant` feature ships, with two admin types, and the role gate is
advisory UX rather than authorisation.**

* **`viewer_servant`** — reads the cohort's **daily roster report**. Read-only.
* **`admin_servant`** — the same report, and **schedules readings** and
  **authors their questions**.

The role is chosen on `/login`, because there is no auth endpoint to choose it
from, and it flows into `AuthSession.role` — the one source the client reads the
role from. The client must not claim `kid` on the wire while the UI says
`admin_servant`, so `X-User-Role` becomes a **live reader** over that session
rather than a frozen literal.

**Four routes**, all named by AGENT_CONTEXT §2's route table:

| Route | Screen |
| --- | --- |
| `/servant` | the portal's **hub** — the sections this role has |
| `/servant/report` | the cohort's daily roster completion report |
| `/servant/schedule` | scheduling a reading for a cohort |
| `/servant/questions` | authoring and committing a reading's questions |

**A `RoleGuard` refuses a navigation whose capability the role does not grant**,
and it refuses by redirecting rather than by throwing — `AuthGuard`'s recorded
reason, stated in `core/navigation/auth_status.dart`'s own words. The grant
table it answers from is `UserRole.grantsFor`, and the hub's entries are read
from that same table, so the screen and the gate cannot disagree.

## Alternatives considered

### No portal — the status quo

- **Pros:** nothing to build and nothing to maintain; the client stays the seven
  reader screens §2 fixes, and the backend's admin surface stays unobserved by
  it.
- **Cons:** the backend's admin, AI and report routes keep answering anyone who
  calls them while this client never calls them at all, so the client's own
  coverage of the API stays partial.
- **Why not:** the user reversed decision 5 to have it, and the reversal is
  recorded in §2's table. "Those backend routes stay untested from the client"
  was a statement about **the client**, not about the server.

### A real authentication endpoint

- **Pros:** the role would become a fact the server sent rather than a button
  someone pressed, and the role gate could one day be a real boundary.
- **Cons:** it is a **backend** change, and the backend is read-only reference
  material — AGENT_CONTEXT §8.2: "**Never** modify
  `/home/fady/Projects/EvangelionBackend` in any way." It would also be a new
  endpoint, which §2 decision 3's "Login and onboarding are UI-only" forbids
  inventing.
- **Why not:** the backend has no auth endpoint to call, and this client may not
  add one. The role stays a local choice, and the client says so on the screen
  that makes it rather than implying the server confirmed it.

### One admin type

- **Pros:** one grant table, one landing route, one capability set to reason
  about.
- **Cons:** a single type must either grant the scheduling and authoring
  controls to a reader who only wants the report, or deny them to an admin who
  needs them.
- **Why not:** the backend's own union has **three** roles
  (`identity.middleware.ts:5`), and a **read-only servant is a real need** — the
  daily roster report is a screen a cohort leader reads and nobody edits.

### A tab shell for `/servant`

- **Pros:** it would match `/`'s shape, and the dock shell is the shape this
  app already knows how to build.
- **Cons:** a tab bar whose tab count depends on the reader's role is a bar
  that is one item wide for one of the two servant roles.
- **Why not:** a `viewer_servant` has **exactly one** section, and a tab bar
  holding one tab is chrome for nothing. `/servant` is therefore a **hub page**
  whose body is a list of the sections this role has, and its three sub-routes
  are **root-level absolute paths** rather than children of an
  `AutoTabsRouter`.

### Gating the admin routes on the server

- **Pros:** it would be the only version of this gate that is worth anything to
  an attacker, because the header is set by the client and the client is the
  attacker's own device.
- **Cons:** it needs a server-side guard that does not exist, and it needs a
  backend change to add one.
- **Why not:** the measurement is two greps. `rg 'user\??\.role' src/` returns
  **no matches** and `rg '403' src/` returns **no matches** across all
  **seventeen** route registrations in `src/`. Every endpoint is callable by
  anyone who sends a user id, so the client's `RoleGuard` prevents **accidents**
  and nothing more.

## Consequences

### Better

- **The client covers the backend's whole admin surface for the first time** —
  the four routes above, with the upsert and the delete-on-AI behaviours of the
  schedule endpoint stated on screen rather than discovered by losing work.
- **The role model stops being a mechanism with no consumer.**
  `UserRole.fromWire` has **no caller in `lib/`** at all, and
  `UserRole.grantsFor`'s only one is `LiveRoleAccess.allows`
  (`lib/core/navigation/role_access.dart:289`) — a seam that nothing in `lib/`
  reads yet. The portal is what both of them were waiting for.
- **`landingRouteFor()` gets its first caller.** The function in
  `lib/core/navigation/landing_route.dart` was built for exactly this and had
  none; a `kid` lands on `/` and either servant role lands on `/servant`.
- **The hub is a page, so a `viewer_servant` is not shown a tab bar with one
  tab in it.**

### Worse

- **Three form-heavy screens with no counterpart in `eva/redesign.html`.** They
  are **written, not transcribed**: the citation gate gets no new prototype
  citation to resolve, and the pages must not cite the prototype as if it
  described them.
- **The role gate is not a boundary.** It prevents an accident — a child is not
  dropped onto a scheduling screen that makes no sense for them — and it buys
  no property an attacker would have to defeat, because there is nothing on the
  server to defeat.
- **The schedule endpoint has two behaviours the UI has to say out loud.**
  `POST /admin/readings/schedule` **upserts** on `(group_id, scheduled_date)`
  (`admin.routes.ts:157`), so scheduling the same group and date again
  **replaces** the passage; and with `generate_ai_questions` on it **deletes the
  previous questions** for that reading (`admin.routes.ts:195`). A servant who
  learns either of those by losing work has been told the truth too late.
- **The questions screen needs a typed `reading_id`**, because the backend has
  no "list my scheduled readings" endpoint — a reading scheduled in an earlier
  session cannot be looked up, and the screen says where the id came from
  rather than pretending a lookup exists.

### Neutral / noted

- **`docs/plans/` is out of date and is not edited** — §8.6 gives that
  directory a dedicated owner.
- **Both servant roles keep `readOwnReading`, `submitQuiz` and
  `viewCohortLeaderboard`** in `UserRole.grantsFor`, so a servant is still a
  reader and the dock shell is unchanged.
- **The `X-User-Role` header stays decorative to the server**, and the client
  still must not lie about it: the header becomes a live reader over
  `AuthSession.role`, and the role is read from one place twice rather than
  mirrored.
- **The dock shell gains no admin entry**, and the missing entry is
  **decoration** — the `RoleGuard` refusing the navigation is the mechanism,
  and the test that matters is the one that asserts the refusal.

## Traceability

- `docs/agents/AGENT_CONTEXT.md` §2 decision 5 — amended 2026-10-21, and
  §2's route table's four `/servant*` rows
- `docs/superpowers/specs/2026-10-21-servant-admin-portal-design.md` — the
  design this records
- `docs/superpowers/plans/2026-10-21-servant-admin-portal.md` — the plan that
  implements it
- `lib/core/domain/entities/user_role.dart` — the roles, the grant table, and
  the two zero-match greps in full
- `lib/core/navigation/role_access.dart` — the seam the guard reads, and the
  same answer in the seam's own words
- `lib/core/navigation/landing_route.dart` — the one place a role becomes a
  path
- `lib/core/navigation/app_routes.dart` — the path itself
