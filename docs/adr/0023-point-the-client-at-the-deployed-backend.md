# ADR-0023: Point the client at the deployed backend, and make TLS the release posture

- **Status:** accepted
- **Date decided:** 2026-10-20
- **Recorded:** 2026-10-20
- **Deciders:** the project owner
- **Authority:** `AGENT_CONTEXT.md` §2 decision 2, §5, §5.1

## Context

The backend was deployed to Vercel and is live at
`https://evangelion-backend.vercel.app`. It is the same Fastify 5 application the
local backend runs, behind a catch-all rewrite (`vercel.json`: `/(.*)` → `/api`)
and an `api/index.ts` entrypoint, backed by Neon Postgres and a real Redis.

The client still pointed at `http://localhost:3000`. Two facts made the move
more than a string swap. **The deployed backend is HTTPS and the local one is
not**, so the client's release posture was carrying an Android cleartext
exemption that exists only to reach a plaintext dev host. And **the two backends
are no longer the same server**: the deployed one has a database, and a database
enforces types and holds only the rows that exist, so three of `AGENT_CONTEXT`
§5's documented facts are true of one backend and not the other.

Measured on 2026-10-20 against both, live: `docs/BACKEND-VERIFICATION.md` has
the transcripts and `AGENT_CONTEXT.md` §5.1 has the table.

## Decision

**`AppConfig.apiBaseUrl` defaults to `https://evangelion-backend.vercel.app`.**

The local backend remains a second target, reached with
`--dart-define=API_BASE_URL=http://localhost:3000`. The base URL is still a
build-time override, and it is still the *only* place a host is named —
`dio_client.dart` takes it as a parameter and `core_module.dart` is the single
line that reads it (recorded decision 1 and 16, unchanged).

**The Android release build no longer asks for cleartext.** The
`android:usesCleartextTraffic="true"` attribute moved out of
`android/app/src/main/AndroidManifest.xml` and into
`android/app/src/debug/AndroidManifest.xml` and
`android/app/src/profile/AndroidManifest.xml`. The attribute's own comment said
to do this: *"REMOVE this attribute once the backend is served over TLS — it
must never ship to production."* The backend is served over TLS.

**iOS changes nothing**, because `ios/Runner/Info.plist` has no
`NSAppTransportSecurity` block at all and App Transport Security is already
TLS-only there. The property was already correct; the change made it true of
Android too.

## Alternatives considered

### Keep `http://localhost:3000` as the default and require the flag everywhere

- **Pros:** local development stays zero-configuration, and no build can
  accidentally depend on a remote host being up.
- **Cons:** a release built without `--dart-define=API_BASE_URL=...` ships a
  binary that talks to a loopback address, which answers nothing on a device.
  The failure is a socket error on somebody's phone rather than a mistake
  anybody can see at build time.
- **Why not:** the whole point of the change is that there is now a real
  deployment to point at, and a default that is wrong for a shipped binary is a
  worse default than one that is wrong for a developer. The local backend stays
  one flag away, so the zero-configuration local case costs one flag rather than
  a default.

### Bake the host in as a literal, with no override at all

- **Pros:** one host, one place, nothing to configure.
- **Cons:** no way to develop against the local backend at all, and
  `String.fromEnvironment` is what makes the override path testable at all
  (recorded decision 1: the Dio client takes `baseUrl` as a constructor
  parameter precisely so a malformed override is an ordinary test).
- **Why not:** the override is already there, it is already tested, and it
  costs nothing to keep.

### Keep the cleartext exemption in the release build "just in case"

- **Pros:** a release pointed at a plaintext host would still work.
- **Cons:** the exemption is a blanket permission for all cleartext traffic on
  Android, in a shipped binary, for a backend that is HTTPS.
- **Why not:** the manifest's own comment already answered this, and
  `SECURITY.md`'s "All traffic is plaintext HTTP" section was the standing
  reason the exemption existed. The section is now false and has been rewritten.

### Leave ADR-0002 alone and add a note to it

- **Pros:** one file instead of two.
- **Cons:** ADR-0002 is a record of a decision, and a record of a decision is
  what it says it is. The base URL in its table is now wrong, and editing it
  would make the record claim a decision it did not make.
- **Why not:** this repository's own convention — ADR-0001 was superseded by
  ADR-0022 rather than edited, and the `docs/adr/README.md` status vocabulary
  has a `superseded by ADR-NNNN` row for exactly this.

**But ADR-0002 is NOT superseded, and saying so would be a lie by
omission.** Its decision is *"Read from the live API; auth stays UI-only and
settings stay local"* — and **all three of those still stand**. The live API is
still the live API, `FakeAuthRepository` is still the only `AuthRepository`
adapter, and settings are still `shared_preferences` with no server sync. What
changed is one cell in one row of its table: the host. A record is superseded
when the thing it decided is no longer the thing; this one is **amended**.

So ADR-0002 keeps the status `accepted`, its file is untouched, and its index
row names the amendment. `docs/adr/README.md`'s status vocabulary has no
`amended by` row, and one was not added for a single case — the index row
carries the note instead, which is where a reader looks for it.

## Consequences

### Better

- **A shipped binary has a working host without a build flag.** The default
  resolves to a real deployment.
- **The release build is TLS-only on Android.** The cleartext exemption is
  gone from the manifest that reaches a store, and `SECURITY.md` no longer
  claims the app's traffic is plaintext.
- **The leaderboard is durable.** The deployment has a real Redis, so a quiz
  submission moves the reader up the board and the board survives a cold
  start. `USE_STUB_LEADERBOARD` stays available and stays off by default.
- **The contract is now measured against a server that has a database.** §5's
  traps were written against an in-memory fallback, and the deployed backend
  proves which of them were properties of the *fallback* rather than of the
  API.

### Worse

- **The app depends on a remote host being up.** The local backend was a
  thing you started; the deployment is a thing that can be down, rate-limited
  or cold. The client has no retry interceptor — `dio_client.dart` says a
  second interceptor "belongs in this list, in a stated order, and nowhere
  else", and it is not in the list — so a cold-start failure is a failed
  screen, not a retried one.
- **Three of §5's facts are no longer true of both backends.** The non-UUID
  header now 500s, a date with no scheduled reading now 404s, and the seeded
  streak is 0 rather than 4. The client is correct against both; the
  *document* had to split, which is what §5.1 is.
- **`daily_readings` does not roll forward.** The Neon database was seeded
  once, on 2026-10-19, with `scheduled_date = CURRENT_DATE`, and
  `runSeeds()` is a CLI rather than a boot step. Every date after the seed
  answers 404 on `/readings/today`.

### Neutral / noted

- **Nothing in `lib/` changed shape.** Every response the client's mappers
  parse has the same keys on both servers, so
  `today_reading_mapper.dart`, `submit_result_mapper.dart`,
  `streak_summary_mapper.dart` and `leaderboard_mapper.dart` are untouched and
  their golden tests still hold. This is the strongest single fact about the
  move: **the client was written against a contract the deployment already
  honoured.**
- **The timeouts were not re-tuned.** `connectTimeout` is 10 s and
  `receiveTimeout` is 15 s, which are the loopback backend's values. A warm
  request to the deployment measured **0.48–0.54 s** on 2026-10-20; **a cold
  start was not measured**, because a Vercel function has to be left idle long
  enough to expire and that was not done. The pair is left alone rather than
  re-tuned against a number nobody has, and `app_config.dart` says so.
- **`docs/plans/` was not edited.** It has a dedicated owner. Five files there
  still say `http://localhost:3000` and are reported to the owner rather than
  changed.

### What this change does NOT do

- **No designed empty state for "no reading scheduled today".** A 404 from
  `/readings/today` still renders through `ErrorView` with the server's
  verbatim English message and a live retry. The backend's own
  `FRONTEND_INTEGRATION_GUIDE.md` §6 asks for a friendly empty state, and the
  design system has an `EmptyState` widget that would suit it — but wiring it
  means a `FailureKind` reaching the home card's widget, a new l10n key pair,
  and a `Failure` rather than a `String` in the card's API. That is its own
  change, and it was explicitly deferred.
- **No daily scheduling.** The reading schedule is still a manual
  `POST /api/v1/admin/readings/schedule`, and it will 404 tomorrow for the
  same reason it 404s today. No cron was added: the backend is read-only for
  this repository (`AGENT_CONTEXT.md` §8 constraint 2), and a cron there is a
  backend change.

## Traceability

- `docs/agents/AGENT_CONTEXT.md` §2 decision 2 (amended), §5, §5.1, and
  recorded decision 16a
- `docs/BACKEND-VERIFICATION.md` — the live measurements, both backends
- `docs/DRIFT.md` — the §5 claim that did not survive the move
- `lib/core/common/app_config.dart:34` — the default
- `android/app/src/main/AndroidManifest.xml`, `.../debug/AndroidManifest.xml`,
  `.../profile/AndroidManifest.xml` — the cleartext posture
- `SECURITY.md` — "All traffic is plaintext HTTP", rewritten
- [`docs/adr/0002-live-api-is-the-only-data-source.md`](0002-live-api-is-the-only-data-source.md)
  — **amended**, not superseded: its decision stands, and only its base-URL row
  is overtaken by this record
