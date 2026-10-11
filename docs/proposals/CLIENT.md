# CLIENT.md — Flutter client reference

Everything about the client. Terse by design.
Deep dive on models → `models.md` · Backend → `../EvangelionBackend/ARCHITECTURE.md`

---

## 1. Shape

```graph
screen ──▶ Bloc ──▶ UseCase ──▶ Port ──▶ Repo ──▶ DataSource ──▶ Dio
                            (interface)              │
                                                     ▼
                                          Mapper ◀── raw Object?
                                            │
                                  DTO ──────┘  (json_serializable)
                                   │
                                   ▼
                              Entity  (freezed)
```

```Text
presentation → domain → data          one way. data never imports presentation.
```

| Layer | Package | Lives in |
| --- | --- | --- |
| State / entities | `freezed` | `core/domain/entities/` |
| Errors | `Either<Failure,T>` (`fpdart`) | `core/common/` |
| Transport | `dio` | `core/network/` |
| Wire | `json_serializable` | `wire/dto/` |
| DI | `get_it` + `injectable` | `app/di/` |
| Nav | `auto_route` | `app/router/` |

**DTO → domain**: DTOs mirror JSON. Entities are freezed, immutable, null-free.
One mapper per endpoint. Repo returns `Either`, never throws.

---

## 2. Endpoints — 14

Base `/api/v1`. Headers `H` = `X-User-Id` + `X-Group-Id`.

### Kid — 4 wired ✅

| # | Method | Path | Needs | Returns |
| --- | --- | --- | --- | --- |
| 1 | GET | `/readings/today/ar` | `H` +`?date` | `LocalizedReadingDto` |
| 2 | GET | `/readings/today/en` | `H` +`?date` | `LocalizedReadingDto` |
| 3 | GET | `/readings/today` | `H` +`?date` +`?lang` | `Bilingual\|Localized` |
| 7 | POST | `/readings/{id}/submit` | `X-User-Id` | `SubmitAnswerResponseDto` |
| 8 | GET | `/streak` | `X-User-Id` +`?date` | `StreakDetailDto` |
| 9 | GET | `/streak/summary` | `X-User-Id` +`?date` | `StreakSummaryDto` |
| 14 | GET | `/leaderboard` | `H` +`?window` +`?limit` | `LeaderboardDto` |

### Passage — 3 unbuilt (Library cut)

| # | Path | Query | Returns |
| --- | --- | --- | --- |
| 4 | `/bible/verses/ar` | `book_number, start_chapter, start_verse, end_verse` | `PassageDto` |
| 5 | `/bible/verses/en` | ↑ | `PassageDto` |
| 6 | `/bible/verses` | ↑ | `BilingualPassageDto` |

### Admin — 4 → future dashboard

| # | Method | Path | Returns |
| --- | --- | --- | --- |
| 10 | POST | `/admin/readings/schedule` | `201 {message, reading_ids[]}` |
| 11 | POST | `/admin/questions/commit` | `201 {message, question_ids[]}` |
| 12 | POST | `/admin/questions/ai-generate` | `{reading_id, draft_question}` ← **not saved** |
| 13 | GET | `/servant/reports/daily` | roster |

### System

| # | Path | Returns |
| --- | --- | --- |
| 0 | `/health` | `{status, service, timestamp, swagger_docs}` |

---

## 3. The four wire shapes

### Reading — localized (`/ar`, `/en`, `?lang=`)

```jsonc
{
  "reading_id": "uuid", "group_id": 3, "scheduled_date": "2026-10-10",
  "language": "ar",
  "reference": "يوحنا 3: 1-5",              // string  · EN: "John 3:1-5" (no space)
  "translation": "Smith & Van Dyck (فانديك)",
  "verses":    [{ "book_number":43, "chapter":3, "verse":1,
                  "text":"وَ…", "text_clean":"…" }],   // text_clean ABSENT on /en
  "questions": [{ "id":"uuid", "sort_order":1, "type":"mcq",
                  "prompt":"…",                    // prompt_ar/_en when bilingual
                  "options": { "A":"…" },          // FLAT when localized
                  "points_value":10, "already_answered":false,
                  "user_answer": null, "is_correct": null }],
  "is_fully_completed": false, "total_points_earned_today": 0, "current_streak": 4
}
```

### Reading — bilingual (`/today`, no `?lang`)

```jsonc
{
  "reading_id":"uuid", "group_id":3, "scheduled_date":"2026-10-10",
  "reference":   { "ar":"…", "en":"…" },      // OBJECT
  "translation": { "ar":"…", "en":"…" },
  "verses":    [{ "book_number":43,"chapter":3,"verse":1,
                  "text_ar":"…","text_ar_clean":"…","text_en":"…" }],
  "questions": [{ "id":"…","sort_order":1,"type":"mcq",
                  "prompt_ar":"…","prompt_en":"…",
                  "options":{ "A": { "ar":"…", "en":"…" } },   // NESTED
                  "points_value":10,"already_answered":false,
                  "user_answer":null,"is_correct":null }],
  "is_fully_completed":false,"total_points_earned_today":0,"current_streak":4
}
```

### Streak

```jsonc
// /streak/summary
{ "user_id":"uuid","group_id":3,"current_streak":4,"longest_streak":6,
  "last_completed_date":"2026-09-29",            // null if never completed
  "today_status":"pending",                        // completed|pending|off_day|broken
  "today_completed":false,"today_scheduled":true,
  "next_milestone":7,"days_to_milestone":3 }

// /streak  → same + "today_date" + "history":[…max 30]
  "history":[{ "reading_id":"…","scheduled_date":"…","book_number":43,
               "book_name_ar":"يوحنا","book_name_en":"John",
               "reference":{"ar":"…","en":"…"},
               "total_questions":1,"answered_questions":1,"correct_answers":1,
               "points_earned":10,"is_completed":true }]
```

### Leaderboard + submit

```jsonc
// GET /leaderboard
{ "group_id":3,"window":"weekly","total_ranked":0,
  "my_standing": { "rank": null, "score": 0 },     // null obj · null rank inside
  "leaderboard":[ { "userId":"…",        // ← camelCase. only one in whole API
                   "score":50,"rank":1,
                   "full_name":"David Mina (Grade 5)","current_streak":4 } ] }

// POST /readings/{id}/submit → 200
{ "question_id":"uuid","is_correct":true,"points_earned":10,
  "current_total_points":60,"current_streak":5,"longest_streak":7,
  "reading_completed":true }
```

### Errors — 2 shapes

```jsonc
{ "error":"Bad Request", "message":"headers must have required property 'x-group-id'" }
{ "error":"Validation Error", "details":{…} }     // zod only: admin / AI / submit
```

---

## 4. The 14 DTOs

`wire/dto/*.dart` · `fieldRename: snake` · verified 22/22 against recorded payloads.

```dart
// shared
LocalizedTextDto     { String ar, en }

// reading
LocalizedVerseDto    { int bookNumber, chapter, verse; String text; String? textClean }
LocalizedQuestionDto { String id, type, prompt; int sortOrder, pointsValue;
                       Map<String,String> options;        // FLAT
                       bool alreadyAnswered; String? userAnswer; bool? isCorrect }
LocalizedReadingDto  { String readingId, language, reference, translation;
                       int groupId, totalPointsEarnedToday, currentStreak;
                       DateTime scheduledDate; bool isFullyCompleted;
                       List<LocalizedVerseDto> verses;
                       List<LocalizedQuestionDto> questions }

BilingualVerseDto    { int bookNumber, chapter, verse; String textAr, textArClean, textEn }
BilingualQuestionDto { …same, but promptAr/promptEn + Map<String,LocalizedTextDto> options }
BilingualReadingDto  { …same, but reference/translation are LocalizedTextDto }

// passage
PassageVerseDto      { int chapter, verse; String text; String? textClean }
PassageDto           { String language, bookName, reference, translation;
                       int bookNumber, verseCount; List<PassageVerseDto> verses }
BilingualPassageDto  { int bookNumber, verseCount;
                       LocalizedTextDto reference, translation;
                       List<BilingualVerseDto> verses }

// streak
StreakSummaryDto     { String userId, todayStatus; int groupId, currentStreak,
                       longestStreak, nextMilestone, daysToMilestone;
                       bool todayCompleted, todayScheduled;
                       DateTime? lastCompletedDate }
StreakHistoryItemDto { String readingId, bookNameAr, bookNameEn;
                       LocalizedTextDto reference;
                       DateTime scheduledDate; int bookNumber,
                       totalQuestions, answeredQuestions, correctAnswers,
                       pointsEarned; bool isCompleted }
StreakDetailDto      { …StreakSummary + String todayDate; DateTime todayDate;
                       List<StreakHistoryItemDto> history }

// submit
SubmitAnswerRequestDto  { String questionId, answer }
SubmitAnswerResponseDto { String questionId; bool isCorrect, readingCompleted;
                          int pointsEarned, currentTotalPoints, currentStreak,
                              longestStreak }

// leaderboard
LeaderboardEntryDto  { String userId, fullName; int score, rank, currentStreak }
MyStandingDto        { int? rank; int score }
LeaderboardDto       { String window; int groupId, totalRanked;
                       MyStandingDto? myStanding; List<LeaderboardEntryDto> leaderboard }
```

### Date handling — exact

```dart
@JsonKey(fromJson: requiredDateOnlyFromJson, toJson: requiredDateOnlyToJson)
final DateTime scheduledDate;          // non-null → needs the REQUIRED pair

@JsonKey(fromJson: dateOnlyFromJson,    toJson: dateOnlyToJson)
final DateTime? lastCompletedDate;     // nullable → needs the NULLABLE pair
```

`json_serializable` rejects a converter whose return type ≠ field type. **Two pairs, not one.**
`DateTime.parse` → local midnight. **Never `.toUtc()`** — wire has no zone; it shifts the day.

---

## 5. Headers

```Text
IdentityHeadersInterceptor  ──▶ every request
X-User-Id    required  presence only. NO format check server-side.
X-Group-Id   required  readings + leaderboard. integer 1–7
X-User-Role  optional  parsed, NEVER enforced. zero 403s in backend.
```

| `X-User-Id` sent | Response |
| --- | --- |
| absent | **400** `headers must have required property 'x-user-id'` |
| empty | 401 |
| `not-a-uuid` | **200**, echoed back |

**Server validates nothing.** Client owns UUID shape → `isValidUserId` in `identity_headers.dart`.
**Missing header = 400, not 401** → AJV validates before the handler. All 401 branches are dead code.

**Why interceptor, not per-call:** a forgotten `X-Group-Id` is a 400 — indistinguishable from a bad
body. No call site gets the choice. `onRequest` **overwrites**, never merges.

**Normally:** `Authorization: Bearer <jwt>`, server-verified. **Not here** — no `/login`, no `/me`,
no signature check. `X-User-Id` is an *assertion, not a credential*. Adding a bearer token today would
mint a string the server never inspects.

**Never gate on `X-User-Role` as authorization.** Stops a child landing on a screen that makes no
sense for them. Stops nothing else.

`Content-Type: application/json` set on the client — a POST without it is **415**.

---

## 6. Traps — all verified

| # | Trap | Where |
| --- | --- | --- |
| 1 | `userId` camelCase; `full_name` snake — same object | `leaderboard.routes.ts:56` |
| 2 | `text_clean` **only** on Arabic | `readings.service.ts:251` |
| 3 | Same URL, 2 shapes: `?lang=` flips every field | `readings.routes.ts:252-256` |
| 4 | `reference` format differs: AR `"3: 1-5"` / EN `"3:1-5"` | `readings.service.ts:202` |
| 5 | `/streak` fires **~64 queries** (30 history × 2). use `/summary` for headers | `streak.service.ts:100` |
| 6 | `total_ranked` = rows **returned**, not cohort size | `leaderboard.routes.ts:119` |
| 7 | `my_standing.rank: null` = unranked ≠ 0 | `leaderboard_mapper.dart:383` |
| 8 | Resubmit → **409** (`uq_user_question`) | `submissions.routes.ts:82` |
| 9 | POST `question_id` non-UUID → **400** before handler | AJV |
| 10 | `?date=` must be `YYYY-MM-DD`; `toIso8601String()` → **400** | verified live |
| 11 | Unscheduled `?date=` → **404**; silent in dev (auto-provisions) | `readings.routes.ts:128` |
| 12 | AI never fails — fallback answer is always `A` | `ai.service.ts:131` |
| 13 | `off_day` unreachable in dev | `memory_db.ts:302` |
| 14 | `/servant/reports/daily` → **500** in memory mode. Postgres-only bug | `memory_db.ts:356` |

---

## 7. Live-backend gap

```Text
BUILT      7 screens · 4 endpoints · full Dio→Either chain · tests green
NOT BUILT  /bible/verses ×3 (Library cut, correct) · /admin ×4 (dashboard)
CEILING    no auth endpoint → EVERY kid = 1111…, group 3, forever
SERVER     servant report 500s in memory mode → real Postgres fixes it
```

### The dev-fallback trap

```Text
memory fallback:  id = "reading-group-1-2026-10-10"   ← NOT a UUID
Postgres:         id = gen_random_uuid()              ← 001:34,67,88,106

group 1 → submit 400    group 3 → submit 200    group 5 → submit 400
```

**Not your bug.** `defaultGroupId = 3` exists only because of this. Real backend → all groups work.

---

## 8. Roadmap

```Text
1  backend up ──────────▶ verify group ≠ 3 submits 200
2  X-Group-Id per-session  defaultGroupId=3 becomes a fallback, not a pin
3  ?date= ───────────────▶ 5 files. NOT toIso8601String()
4  /streak full ─────────▶ new mapper + DS method (task B)
5  golden DTO tests ─────▶ decode models.md §3 payloads
6  error states ─────────▶ 404 · 400 · 409 · offline
```

### 1 — Backend

```bash
cd ../EvangelionBackend
docker compose up -d && npm run migrate && npm run import-bible
curl -H "X-User-Id: 1111…-1111-1111-1111-111111111111" -H "X-Group-Id: 1" \
  localhost:3000/api/v1/readings/today/en | jq '.reading_id,.questions[0].id'
```

Both must be UUIDs → then POST → `200`.

### 2 — Group per session

`identity_headers.dart:125` `defaultGroupId = 3` → mutable, sourced from session.
Interceptor list in `dio_client.dart:86` untouched.

### 3 — `?date=`

```Text
TodayReadingMapper.pathFor(lang) → pathFor(lang, {DateTime? date})
ReadingRemoteDataSource.today(lang) → (lang, {DateTime? date})
ReadingRepository.today/todayScripture → + date
DioReadingRepository → thread through
LoadScripture → carry date
```

```dart
String? isoDate(DateTime? d) => d == null ? null
  : '${d.year.toString().padLeft(4,'0')}-'
    '${d.month.toString().padLeft(2,'0')}-'
    '${d.day.toString().padLeft(2,'0')}';
```

Append `?date=` **only when non-null** — `?date=` empty is a 200 but semantically wrong.

### 4 — `/streak` full (history screen)

```Text
StreakRemoteDataSource.detail()        new — /streak  (NOT /summary)
StreakHistoryMapper                    new — → List<ScheduledDay>
TodayReadingMapper.historyPathFor      new
ReadingRepository.streakHistory()      new
LoadStreakHistory                      new
```

`/streak` costs ~64 queries → paginate or cache; history caps at 30 server-side.

### 5 — Golden tests

Recorded payloads (`models.md` §3) → each DTO. This is what caught the real
`type 'Null' is not a subtype of type 'num'` bug — `PassageDto.verses` reusing
`LocalizedVerseDto` compiled fine and threw at runtime (`/bible/verses` omits `book_number`).

### 6 — Error states

| Case | Trigger | Must not |
| --- | --- | --- |
| 404 | unscheduled `?date=` | render as generic error |
| 400 | malformed `?date=` | retry-loop |
| 409 | resubmit | look like a crash |
| offline | airplane mode | blank screen |

---

## 9. Decisions

### 8c — corrected
>
> *"Do not add `bloc`, `json_serializable`, `flutter_svg` or `package:analyzer`."*

| Package | Original claim | Verified |
| --- | --- | --- |
| `json_serializable` | avoid dependency | scope-rule, not quality. Caught a real bug here |
| `fp_dart` | sealed ≫ `Either` | **void** — compared against `dartz`. fpdart's `Either` **is** `sealed` |

**Still banned:** `bloc` · `flutter_svg` · `package:analyzer`.

### Adopted

```Text
json_serializable  decoding.  generation for parse, hand-written for the contract
fpdart            Either<Failure,T>. getOrElse BANNED → use fold
```

`getOrElse` returns inferred `R` → `Result<Reading>.getOrElse(Widget())` compiles and throws at
runtime. `fold` checks both arms. **Never `getOrElse`.**

`Failure` stays — it is your domain type (kind/message/statusCode), not a generic.

---

## 10. Hard rules

```Text
1  repo never throws                      → Either
2  never .getOrElse                        → fold
3  headers only via interceptor            → never per-call
4  X-User-Role is UX, never authorization
5  text_clean is search/preview only       → render `text`
6  never parse `reference`                 → use book_number
7  today_status: completed|pending|off_day|broken   (closed set)
8  DTOs mirror JSON · entities freezed · one mapper per endpoint
9  keep /api/v1 in paths, not baseUrl      → proxy-safe
```
