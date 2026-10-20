# BACKEND-VERIFICATION.md — §5 re-measured live

Every claim in `AGENT_CONTEXT.md` §5, checked against a running backend.
**Measured 2026-10-11** against the **local** backend, and **re-measured
2026-10-20** against the **deployed** one. The backend is read-only reference
material; nothing in it was modified.

**There are two sections below and they are not redundant.** The first
(2026-10-11) measured the local in-memory backend. The second
([§ The deployed backend](#the-deployed-backend-2026-10-20), 2026-10-20)
measured `https://evangelion-backend.vercel.app` — the backend the client now
talks to by default (ADR-0023). **They disagree in three places, and the
disagreements are the interesting part**: all three have the same cause, which
is that the deployed backend has a database and the local one does not.
`AGENT_CONTEXT.md` §5.1 carries the table.

## How it was run, so you can repeat it

No Postgres or Redis needed — `src/db/pool.ts` falls back to an in-memory DB and
`node_modules/` + `dist/` were already present, so nothing had to be installed.

```bash
cd /home/fady/Projects/EvangelionBackend
NODE_ENV=development PORT=3000 node dist/server.js
```

**Two things that will waste your time otherwise:**

1. **`NODE_ENV` must not be `test`.** `InMemoryRedisFallback`'s constructor pre-seeds
   the leaderboard ZSETs *only* when `NODE_ENV !== 'test'` (decision 143 records the
   empty-response mistake this caused). A harness-started server answers empty and
   makes the endpoint look broken.
2. **Background it with `setsid … & disown`.** A plain `&` is killed when the calling
   shell exits, and every request then returns `000` — which reads like a server bug.

---

## Summary

| # | Claim | Verdict |
| --- | --- | --- |
| §5 header table | absent 400 · empty 401 · non-uuid 200 | ✅ **all four exact** |
| §5 header table | readings/today does not need `X-User-Id` | ✅ 200 with group only |
| Trap 1 | only `{error,message}` is real; `statusCode` appears nowhere | ✅ **zero occurrences in `src/`** |
| Trap 2 / 9 | `text_clean` is AR-only and **absent**, not null | ✅ absent on `en` |
| Trap 3 / 10 | duplicate submit → 409 | ✅ 409 verbatim |
| Trap 5 | POST without `Content-Type` → 415 | ✅ verbatim |
| Trap 6 | `?date=` must be `YYYY-MM-DD` | ✅ 400 verbatim |
| Trap 4 | streak fields change only on `reading_completed` | not exercised — **no successful submit exists** |
| Trap 8 | the two endpoints disagree about today | ✅ **live: `4` vs `0`** |
| Trap 10 | no successful submit has ever been observed | ✅ **all three rows reproduced exactly** |
| Trap 11 | `reading_id` is date-stamped | ✅ **with a correction — see below** |
| Decision 143 | the leaderboard is *not* empty in dev | ✅ 3 rows, reader rank 2 |
| Decision 14 | 8 observed error bodies | ✅ 5 sampled, all verbatim |
| CLIENT.md trap 1 | `userId` camel beside `full_name` snake, one object | ✅ confirmed |

---

## The one correction: trap 11's id shape

§5 trap 11 says `GET /readings/today/{lang}` returns
`reading_id: "reading-group-3-2026-10-04"`. **That is true for every date except
today's**, and the exception is the only one that matters:

```Text
<today>            -> aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa   <- a real UUID
?date=2026-10-11   -> aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa   <- same
?date=2026-10-04   -> reading-group-3-2026-10-04             <- the fallback
?date=2026-01-01   -> reading-group-3-2026-01-01             <- the fallback
?date=2026-10-12   -> reading-group-3-2026-10-12             <- the fallback
```

So the accurate statement is: **today's reading is the seeded UUID; anything else is
auto-provisioned by the in-memory fallback and gets a non-UUID id.** The doc states the
general case without the exception, which inverts the conclusion a reader would draw
("ids are never UUIDs here" — false for the one reading the app actually loads).

### And trap 10 therefore still holds, for a sharper reason

Submitted against the auto-provisioned reading:

```json
reading_id: reading-group-3-2026-01-01
question id: question-group-3
-> {"error":"Bad Request","message":"body/question_id must match format \"uuid\""}  400
```

Against today's seeded reading the question is `bbbbbbbb-…`, which returns **409
already-submitted**. So the two halves are still mutually exclusive, and the client's
two standing rules both survive untouched:

* **Do not validate `reading_id` / `question_id` as UUIDs** on the read path — today's
  is a UUID but a `?date=` is not, so a validator would be right today and wrong
  tomorrow.
* **Fixtures in `test/` are transcriptions, not captures** —
  `test/support/contract_payloads.dart` says so and remains correct.

---

## Two claims in the untracked docs that measurement disproved

Both are in `docs/proposals/`, and both are now also recorded in `DRIFT.md`.

| Claim | Reality |
| --- | --- |
| CLIENT.md: unscheduled `?date=` → **404** | **200.** `?date=2026-01-01` returns a fully-formed reading, auto-provisioned. The `404` only happens against a real database. |
| CLIENT.md: `fp_dart`'s `getOrElse` is unsound | **False.** `R getOrElse(R Function(L l) orElse)` — `R` is the payload type, not inferred from the fallback argument. |

CLIENT.md's own trap 11 lists this correctly (*"Unscheduled `?date=` → **404**; silent in
dev (auto-provisions)"*) while its §8 roadmap table drops the qualifier. The doc
contradicts itself, and the half that is wrong is the half a reader acts on.

### THE FIRST ROW IS NOW **TRUE AGAINST THE BACKEND THE CLIENT USES** — 2026-10-20

The row's own caveat was *"The `404` only happens against a real database"*, and
**there is now a real database in the picture**: the deployment's Neon Postgres
(ADR-0023). Measured against `https://evangelion-backend.vercel.app` on
2026-10-20, `?date=2026-10-18` and `?date=2026-10-20` both answer **404**, and
the only date that answers 200 is **2026-10-19** — the date the database was
seeded. See [The deployed backend](#the-deployed-backend-2026-10-20).

So the claim is **not disproved any more — it was disproved for the wrong
reasons.** It said "404" and the local backend said 200, so the row called it
false; the row was in fact describing the deployed backend correctly and
describing the local one wrongly. The contradiction inside CLIENT.md is
unresolved and is now **more** confusing than it was, because the doc's right
half is right about a different server than the one its examples use.


---

## What could not be verified

**Trap 4** — *streak fields only change when `reading_completed == true`* — is
**unverifiable today**, and not because of a limitation in the check. It requires a
successful `POST /readings/:id/submit`, and **no successful submit exists against any
reading reachable by a client** (trap 10). The client's `SubmitResultMapper` is
therefore transcribing a shape nothing has ever returned.

That is not a gap in this verification. It is the same finding trap 10 records, and it
is why `models.md`'s "NOT BUILT" line is doing real work: the only way to observe trap 4
is to stand up Postgres and import the Bible, which is a backend task and outside the
read-only boundary.

---

## The deployed backend (2026-10-20)

The client now points at **`https://evangelion-backend.vercel.app`** by default
(ADR-0023). This section is the measurement behind that decision, and behind
`AGENT_CONTEXT.md` §5.1's table.

### How it was measured, so you can repeat it

The deployment is a Vercel serverless function running the same Fastify 5
application as the local backend, behind a catch-all rewrite
(`vercel.json`: `/(.*)` → `/api`) and an `api/index.ts` entrypoint. It is
**Neon Postgres** and a **real Redis** — not the in-memory fallbacks.

Nothing was installed and nothing was started: `curl` against the live host.

```bash
B=https://evangelion-backend.vercel.app

curl -s "$B/health"
# {"status":"ok","service":"Evangelion Bilingual Bible Platform Backend",…}

curl -s -H "X-Group-Id: 3" \
         -H "X-User-Id: 11111111-1111-1111-1111-111111111111" \
         "$B/api/v1/readings/today/en?date=2026-10-19"

curl -s -H "X-User-Id: not-a-uuid" "$B/api/v1/streak/summary"
```

**The deployed code is `YoussefOS2510/EvangelionBackend` @ `aa1da23`**, five
commits ahead of the local checkout at `4a1c834`. The commits in between are
the deployment itself: `8ac9206` (free cloud hosting, auto-migrations, SSL),
`ad65a6c` (Neon Postgres), `364a302` (the Vercel entrypoint and routing),
`4d10253` (the production URL in the integration guide) and `aa1da23` (the
TypeScript entrypoint).

### The table

| # | Probe | Local `:3000` | Deployed `.vercel.app` | |
| --- | --- | --- | --- | --- |
| 1 | `GET /health` | 200 | **200** | same |
| 2 | `GET /api/v1/readings/today/en` (today, no `?date=`) | 200 | **404** | ← |
| 3 | `GET /api/v1/readings/today/en?date=2026-10-19` | 200 | **200** | same |
| 4 | `GET /api/v1/readings/today/ar?date=2026-10-19` | 200 | **200** | same |
| 5 | `GET /api/v1/streak/summary` (seeded user) | 200 | **200** | same |
| 6 | `GET /api/v1/streak` (history) | 200 | **200** | same |
| 7 | `GET /api/v1/leaderboard?window=weekly` | 200, 3 rows | **200, 3 rows** | same |
| 8 | `GET /api/v1/leaderboard?window=monthly` | 200 | **200** | same |
| 9 | absent `X-User-Id` | 400 | **400** | same |
| 10 | empty `X-User-Id` | 401 | **401** | same |
| 11 | **non-UUID `X-User-Id`** | **200**, echoed | **500** | ← |
| 12 | `?date=20-10-2026` | 400 | **400** | same |
| 13 | `GET /docs/json` | 200 | **200** | same |
| 14 | `OPTIONS` preflight | 204 | **204** | same |
| 15 | EN `text_clean` | absent | **absent** | same |
| 16 | AR `text_clean` | present | **present** | same |

**The three that differ are rows 2, 7 and 11 — and row 7 does not differ in
shape, only in truth.**

### Row 2 — the 404, and the finding under it

`GET /api/v1/readings/today/en` **with no `?date=`** answers:

```json
{"error":"Not Found","message":"No scheduled reading found for your cohort today"}
```

**Nineteen consecutive dates were probed, and exactly one answers 200:**

```text
2026-10-19 -> 200  reading_id=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
2026-10-20 -> 404  No scheduled reading found for your cohort today
2026-10-01 … 2026-10-18  -> 404  (all fifteen)
```

**The cause is in the seed, and it is not a bug in the client.**
`src/db/seeds/001_seed_groups_and_scripture.sql` inserts `daily_readings` with
`scheduled_date = CURRENT_DATE` — evaluated **once**, when the Neon database was
seeded on **2026-10-19**. `runSeeds()` is a CLI (`npm run migrate`), not a boot
step (`api/index.ts` does not call it), so the schedule does not roll forward.
The local backend never showed this, because its in-memory fallback computes
`scheduled_date` from the clock at module load.

**What the client does with it: nothing new, and that is correct.** The 404
maps to `FailureKind.notFound` (`api_error_mapper.dart:217`) and the Reading
page renders it through `ErrorView` with the server's verbatim message and a
live retry. A *designed* empty state is **not** part of this change — see
ADR-0023's "What this change does NOT do".

### Row 11 — the non-UUID that used to be an echo

```text
local:      200  {"user_id":"not-a-uuid", …}
deployed:   500  {"error":"Internal Server Error","message":"Failed to retrieve streak summary"}
```

**Same cause as row 2, seen from the other side: a database.** The local
fallback stores the id as a string. The deployed backend is real Postgres,
where the column is `uuid`, so a non-UUID is a cast error and the request
faults.

**The client is unaffected** — `buildApiDio` rejects a non-UUID at composition
time — **but the check's documented reason was wrong** and is now fixed in
`identity_headers.dart` and `dio_client.dart`. `docs/DRIFT.md` §11 carries the
entry.

### Row 7 — the leaderboard is the same shape and a different truth

Both answer 3 rows with the reader at rank 2 and score 50. **The values are
identical and the reason is a coincidence, not a shared store**: the local
in-memory Redis fallback seeds 80/50/30, and the Neon `users.total_points` seed
carries the same 80/50/30. What differs is what happens next — the deployment
has a **real Redis**, so a submission moves the reader up the board and the
board survives a cold start, where the local fallback's board is re-seeded per
process.

### The response shapes are identical, and that is the strongest fact here

`GET /readings/today/en?date=2026-10-19` against the deployment:

```jsonc
{ "reading_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "group_id": 3,
  "scheduled_date": "2026-10-19", "language": "en",
  "reference": "John 3:1-5", "translation": "NKJV (New King James Version)",
  "verses": [{ "book_number": 43, "chapter": 3, "verse": 1, "text": "…" }],
  "questions": [{ "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "sort_order": 1,
                  "type": "mcq", "prompt": "…",
                  "options": { "A": "Nicodemus", "B": "Paul", "C": "Peter", "D": "Lazarus" },
                  "points_value": 10, "already_answered": false,
                  "user_answer": null, "is_correct": null }],
  "is_fully_completed": false, "total_points_earned_today": 0, "current_streak": 4 }
```

Every key the client's mappers read is present, with the same types and the
same names. The Arabic arm adds `text_clean` to each verse and the English arm
has no such key at all — **the same asymmetry the local backend has**, so trap 2
still holds exactly as written.

**This is why no mapper changed.** The client was written against a contract the
deployment already honoured; the move changed which server answers, not what it
answers.

### What was NOT verified, and why

**No `POST /readings/:id/submit` was fired against the deployment.** It would
have been the only way to observe a successful submit — trap 4, the finding
this document opened with — but a submit is a **write**, and it writes to a
real database that other people read. The seeded question `bbbbbbbb-…` is a
valid UUID, so the submit would very likely have succeeded; "very likely" is
not a measurement, so the trap stays unverified against the deployment too.

**A cold start was not measured.** Every request above hit a warm function
(0.48–0.54 s). A Vercel function has to be left idle long enough to expire
before its next invocation pays the cold start, and that was not done. The
client's `connectTimeout` (10 s) and `receiveTimeout` (15 s) are the loopback
backend's values and were left alone rather than re-tuned against a number
nobody has.
