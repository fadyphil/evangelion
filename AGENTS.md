# AGENTS.md

Fastify + TypeScript (ESM) backend for a bilingual (Arabic Smith & Van Dyck / English NKJV) Sunday-School daily Bible reading platform. Postgres + Redis with an **active in-memory fallback**, so it runs with zero infrastructure.

## Commands

```bash
npm ci                     # install (node_modules is not committed)
npm run dev                # tsx watch, http://localhost:3000, Swagger at /docs
npm run build              # tsc -> dist/   (the ONLY typecheck; covers src/ only)
npm test                   # vitest run (26 tests)
npx vitest run tests/api.test.ts          # single file
npx vitest                 # watch mode
npm run migrate            # SQL migrations + seeds  — REQUIRES real Postgres
npm run import-bible       # rebuilds src/db/bible_data.json (+ optional PG insert)
npm run tunnel             # Cloudflare quick tunnel for $PORT (untun); run `npm run dev` alongside
```

There is **no lint, no formatter, and no `vitest.config`**. Nothing to run but `npm run build && npm test`.

## Critical: the in-memory fallback is not optional

`npm run dev` and `npm test` succeed with no Postgres and no Redis. `src/db/pool.ts` catches `ECONNREFUSED` and routes to `src/db/memory_db.ts`; `src/redis/client.ts` does the same with `InMemoryRedisFallback`. The warnings `⚠️ [DB Fallback]` / `⚠️ [Redis Fallback]` in normal output are expected — do not "fix" them.

Consequences when editing data access:

- `memoryDb.executeQuery()` dispatches on **`t.includes(...)` substring matches against the raw SQL text** and unpacks params **positionally** by index. A new query, or a reworded one, silently returns `{ rows: [], rowCount: 0 }` — no throw, no log. Every new or changed SQL statement needs a new branch in `memory_db.ts`, and the substring must keep matching.
- Only `zincrby`, `zrevrange`, `zrevrank`, `zscore`, and `pipeline()` are emulated in Redis. Anything else needs adding to `InMemoryRedisFallback`.
- `BEGIN`/`COMMIT`/`ROLLBACK` are no-ops. Multi-statement transactions are **not** atomic in fallback mode — don't rely on rollback when testing locally.
- `memory_db.ts` auto-provisions users (`group_id: 3`, role `kid`) and a John 3:1-5 reading + MCQ for any group/date, so unknown IDs and unscheduled cohorts return 200 instead of 404. That masks "reading not scheduled" bugs during local testing.
- `npm run migrate` and `import_bible`'s DB insert use the raw `pool` (not the fallback `query()`), so they hard-fail with `ECONNREFUSED` when Postgres is down. `import-bible` still writes `bible_data.json` before attempting the insert.

## Modules & routing

`src/app.ts:133` registers every module under the single `/api/v1` prefix. Module files export `xxxRoutes(fastify)` and declare paths *relative to that prefix* while including their own sub-path (`/readings/today/ar`, `/admin/readings/schedule`, `/streak/summary`). Add new routes in the module file; don't add the prefix twice.

Layout: `src/modules/<domain>/<domain>.routes.ts` + optional `<domain>.service.ts`, singleton service instance exported at the bottom of the service file (`export const readingsService = new ReadingsService()`).

## Auth is fake — do not assume authorization exists

`src/middleware/identity.middleware.ts` runs on every request and populates `request.user` **only if `X-User-Id` is present**, from `X-User-Id` / `X-User-Role` / `X-Group-Id`. `X-User-Role` is parsed into `request.user.role` but is **never checked by any route** — `/api/v1/admin/*` and `/api/v1/servant/*` are unauthenticated. Real auth is explicitly deferred (`system_design_specification.md` §2). Routes often re-read raw headers instead of `request.user`.

## Conventions

- **ESM / NodeNext.** Every relative import needs an explicit `.js` extension, including in `tests/` (`import { buildApp } from '../src/app.js'`). There is no `__dirname`; use `fileURLToPath(import.meta.url)`.
- **Error contract:** services throw `new Error('CODE: message')` and routes string-match with `err.message?.includes('ALREADY_SUBMITTED')` / `.includes('NOT_FOUND')` → 409 / 404. Tests assert on exact message substrings (`'x-group-id'`, `'start boundary cannot be after end boundary'`) — don't reword messages that tests or the frontend depend on.
- **Validation is inconsistent by module:** zod `safeParse` + `parseResult.error.flatten()` in `admin`, `ai`, `submissions`; inline manual checks + JSON-schema response docs in `readings`, `streak`, `leaderboard`. Match the file you're editing.
- Response docs use `example:` in JSON schemas, which is why `app.ts` registers the custom ajv `example` keyword. Removing that breaks startup.
- Column names are asymmetric: DB columns are `text_en_nkjv` / `text_ar_vandyk`, always aliased to `text_en` / `text_ar` in SQL; the in-memory and JSON shapes use `text_en` / `text_ar` / `text_ar_clean`. Preserve the aliases.

## Testing

`npm test` runs the whole suite against the in-memory engine — no services, no network, no `GEMINI_API_KEY` needed (`AiQuestionService` falls back to a local generator). `tests/api.test.ts` and `tests/streak.test.ts` use `app.inject()`; `leaderboard.test.ts` asserts Redis key formats only.

`tsconfig.json` **excludes `tests/`**, and vitest does not typecheck — so type errors in tests are invisible to both `npm run build` and `npm test`. Be careful editing test files.

## Generated / large assets — do not hand-edit

- `src/db/bible_data.json` — ~20 MB single-line JSON, the compiled bilingual dataset consumed by the in-memory fallback. Never pretty-print or hand-edit; regenerate with `npm run import-bible`.
- `kjv.txt` (4 MB) and `arb-vd_readaloud/` (1192 chapter `.txt` files) are the committed source corpora for that build.

## Deploy

- `docker compose up -d` starts api + postgres + redis, but the **api container never runs migrations**. Run `npm run migrate` then `npm run import-bible` separately. The Dockerfile copies `bible_data.json` into both `dist/db/` and `src/db/` because `memory_db.ts` probes both locations.
- `render.yaml` targets Render (web + Postgres + Redis), `buildCommand: npm install && npm run build`.

## Docs drift — trust the code

`README.md` is stale in places: it documents `POST /api/v1/ai/generate-questions` (actual: `POST /api/v1/admin/questions/ai-generate`), and its `DATABASE_URL` / `GEMINI_MODEL` disagree with `.env.example` and `src/config/env.ts`. `.env.example` matches the code defaults. Client-side contracts (TS models, error-code table, RTL/diacritics rules) live in `FRONTEND_INTEGRATION_GUIDE.md`; the intended design is in `system_design_specification.md`.

Also useful: `postman_collection.json` + `postman_environment.json` cover all route modules end-to-end and auto-capture `readingId` / `questionId` for submission flows.