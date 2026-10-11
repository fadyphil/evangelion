# BACKEND-VERIFICATION.md — §5 re-measured live

Every claim in `AGENT_CONTEXT.md` §5, checked against a running backend.
**Measured 2026-10-11.** The backend is read-only reference material; nothing in it
was modified.

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
