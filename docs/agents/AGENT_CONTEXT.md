# AGENT_CONTEXT — injected into every sub-agent dispatch

This file is **pasted verbatim** into every implementer and reviewer prompt. It is the
single source of truth for scope, architecture, and standards. If any other document
(`docs/plans/`, `eva/`, `README.md`) disagrees with this file, **this file wins**.

---

## 1. Mission

Build the Flutter client for **Evangelion**, a bilingual (Arabic Smith & Van Dyck /
English NKJV) Sunday-School daily Bible reading platform. The backend already exists and
is complete; we are building only the client.

Repository: `/home/fady/Projects/evangelion`
Package name: `evangelion`
Toolchain: Flutter **3.47.4** / Dart **3.13.3** (stable). No FVM, no melos.

---

## 2. Locked decisions — NOT up for renegotiation

These were decided with the user. Do not re-litigate. Do not expand scope.

| # | Decision |
|---|---|
| 1 | **Six screens.** Library and Profile are **cut**. There is no passage library, no category system, no reflection history, no user profile. |
| 2 | **Live API** against `http://localhost:3000` for reading / quiz / result / streak. |
| 3 | **Login and onboarding are UI-only.** A `FakeAuthRepository` returns a seeded session. There is **no auth endpoint on the backend** and no login API call. |
| 4 | **Settings are local only** (`shared_preferences`). No server sync. |
| 5 | **No servant/admin portal.** Those backend routes stay untested from the client. |
| 6 | **Dark glassmorphic design system** per `docs/plans/03-design-system.md`, including the five mandatory performance mitigations in `docs/plans/09-quality-gates.md` §13. |
| 7 | **Error handling is the hand-written `sealed Result<T>`, NOT `fp_dart`/`dartz`.** Added by amendment — §2.1. |
| 8 | **States and entities use `freezed`; localization is ARB + `gen_l10n`.** Added by amendment — §2.1. |

### 2.1 Dependency amendment — `freezed`, `gen_l10n`, and the `fp_dart` rejection

Decided by the user after Phase 8, on measurement. This subsection exists so the next
agent does not re-propose what was rejected, or re-litigate what was accepted.

| # | Decision | Consequence |
|---|---|---|
| 7 | **Keep `sealed Result<T>`.** `fp_dart`/`dartz` rejected. | `lib/core/common/result.dart` stays hand-written. |
| 8a | **Adopt `freezed`** for bloc/cubit states, events and domain entities. | **Shipped** on `refactor/freezed-states`: 34 types converted (17 classes, 14 events, 3 sealed event bases) — see "Recorded decisions — the `freezed` migration" below, decisions 96–100. The `equatable ^3.0.0` removal was deferred at that point because `Failure` and `Result<T>` were deliberately kept hand-written (hazard 2, and decision 7). **Now done — decision 131:** both kept hand-written equality and dropped the base class, so `equatable` is **no longer a direct dependency and no longer in `pubspec.lock` at all**. |
| 8b | **Adopt ARB + `gen_l10n`.** | **Shipped** on `refactor/gen-l10n`: the **five** hand-rolled `*Strings` tables are deleted in favour of `lib/l10n/app_en.arb` + `app_ar.arb` (72 keys). Decisions 101–111 below. Three of §2.1's own claims were corrected **by measurement** during that task and are marked there: the table and field counts, "compile-time key checking" (a missing key is a codegen *warning*, not a build error), and the locale re-dispatch (it is a corpus re-fetch and it **stays**). |
| 8c | **Do not add `bloc`, `json_serializable`, `flutter_svg` or `package:analyzer`** to do any of this. | A source scan over `lib/` is the sanctioned technique. `package:analyzer` especially stays out — it is a far larger dependency than the problem it would solve. |

**Why `fp_dart` was rejected, with the numbers, so it is not re-proposed:**

| measurement | value |
|---|---|
| `try` blocks in all of `lib/` | **3** — all three in the two Dio repositories |
| files importing `result.dart` or `failure.dart` | 26 in `lib/`, 40 in `test/` |
| assertions naming `Result` / `Failure` / `FailureKind` | **879** |

`Result<T>` is already the either pattern, and `sealed` + exhaustive `switch`
**expressions with no `default` arm** is strictly stronger than `dartz`'s `Either`:
a third subtype becomes a compile error at every `switch`, which `Either` cannot
express. That exhaustiveness is already load-bearing — `ApiErrorMapper`'s `switch`
over `DioExceptionType.values` is a recorded gate. The one real gap was
`AsyncEither`, and it applies to **3** call sites, which does not justify rewriting
879 assertions and surrendering compile-time exhaustiveness at every seam.

**What `freezed` changes, and the two hazards recorded before adopting it:**

1. **`freezed` generates `toString`.** It skips the member when the class declares
   one, so the fix is available — but nothing in a green suite distinguishes
   "freezed respected my override" from "freezed replaced it". **Five** classes
   override `toString` deliberately and **three** exist to keep a secret out of
   logs: `LoginCredentials`, `AuthState` and `AuthPasswordChanged`. (A sixth
   hand-written `toString` in this repository is `SignInParams`, which holds a
   password, was never an `Equatable`, and is out of the migration — so the count
   of *secret-holding* classes is four and the count of deliberate overrides
   among *converted* classes is five. §2.1's earlier "six" counted
   `ReadingState`, which has never declared one.) The Phase 8 gate
   `test/core/common/secret_masking_test.dart` is **structural** for exactly this
   reason: it scans `lib/` for any class declaring a `final String password`
   and requires a `toString` that does not interpolate it, plus a behavioural
   half against the running classes. A generated one writes the reader's typed
   password into every log line and every failed `expect`.
2. **`freezed` derives `==` from the constructor and offers no per-field
   exclusion.** `Failure` deliberately excludes `details` from equality, for a good
   reason: `equatable` deep-compares `Map`/`Set`/`Iterable` but falls through to
   plain `==` for everything else, so an untyped field makes two logically
   identical failures unequal, and `Failure` lives inside bloc state where that
   costs a spurious emit and a rebuild. **`Failure` therefore keeps hand-written
   `==` and `hashCode`** (the `props` list is gone — see decision 131), and
   `test/core/common/failure_equality_test.dart` pins the contract. Migrating it to
   a generated `==` would put a decoded server body into the equality contract
   **on purpose**.
3. **`freezed` generates `const` constructors**, which adds new
   `const`-canonicalisation surfaces. This project has shipped eight
   canonicalisation bugs already (`same()` on canonicalised `bool`s, `contains`
   accepting `240` for `24`, a `find.textContaining` that could not match a
   `Text.rich`). The migration needs a gate that two structurally-equal states
   still compare equal **and** that no assertion anywhere relies on `identical()`.

**What `gen_l10n` changes, and why it is worth 302 renamed test references.**
*(Written before the migration. Every bullet below was re-measured on
`refactor/gen-l10n`; where the measurement disagreed, the correction is recorded at
decision 111 and marked here.)*

- ~~69 distinct string fields across the six tables~~ — **five** tables, **73** string
  fields, **67** distinct bare names, **72** ARB keys. Three collide and were
  namespaced: `retry` (`home`/`quiz`/`reading`), `unavailableSuffix`
  (`auth`/`home`/`quiz`/`reading`), `wordmark` (`auth`/`home`).
- **ICU plurals**, which the hand-rolled tables do not have. Arabic has
  zero/one/two/few/many/other, and Phase 8 hand-wrote `1 question` /
  `5 questions` / `٠ أسئلة`. That is a correctness gap, not an ergonomic one.
  **Landed**, and it paid off a recorded debt: the old `captionFor(2)` was `٢ أسئلة`
  where correct Arabic is `٢ سؤالان`. Two counts became plurals and four were audited
  and named as not plural-dependent — decision 104.
- ~~**Compile-time key checking.** A typo becomes a build error~~ — **half true, and
  the half that is false matters**: a key missing from a locale file makes
  `flutter gen-l10n` print a hint and **exit 0**, emitting the template's **English**
  value into the Arabic class, and `dart analyze` reports nothing. A structural test
  over the two ARB files is what turns it red — decision 108.
- ~~**The manual locale re-dispatch dies.**~~ **This bullet was wrong and the code was
  left alone.** `HomePage`/`QuizPage`'s `didChangeDependencies` branch is
  `if (_requested != _language) _load()` — a **corpus re-fetch**, not a string
  resolution, and it reads `Localizations` directly. Emptying it fails **56** tests.
  What died is the resolution *pattern* (`X.of(Localizations.localeOf(ctx))` in five
  `build` methods → `context.l10n`), and `didPopNext` is untouched and still gated —
  decision 106.

### The six routes

| Route | Screen | Data source |
|---|---|---|
| `/login` | Onboarding + login (email, password, social buttons) | `FakeAuthRepository` |
| `/` | Home — greeting, streak flame, today's-reading panel | **API** |
| `/reading` | Reading sanctuary, EN and AR, zero chrome | **API** |
| `/quiz` | Quiz with instant per-question feedback | **API** |
| `/result` | Result — score, streak, stat tiles | **API** (submit response) |
| `/settings` | Appearance, reading, about | local |

Routes carry **no `:passageId` parameter**. There is no library to browse, so the passage
is always *today's*. The quiz re-fetches to obtain fresh `already_answered` flags, because
the backend has **no `GET /readings/:id`** endpoint.

---

## 3. Architecture — clean architecture, strict

Dependency direction is strictly inward:

```
presentation  ──▶  domain  ◀──  data
```

`domain` imports **nothing** from `data` and **nothing** from Flutter.

### Layer responsibilities

```
lib/
  app/                     composition root: DI, router, bootstrap
  core/
    design_system/         tokens, theme, effects, widgets  (imported by everyone)
    common/                Result<T>, Failure, AppConfig
    network/               Dio client, interceptors, error mapper
    domain/                SHARED KERNEL — see below. PURE DART.
  features/<f>/
    domain/                PURE DART. this feature's USE CASES only
    data/                  models, data sources, repository implementations
    presentation/          bloc/cubit, pages, widgets
```

### Shared kernel — `core/domain/`

Six screens read the same handful of types. Without a shared kernel, `home`, `reading` and
`quiz` would each need `ReadingRepository`, which forces cross-feature imports and breaks
the purity gate in §7. So entities and ports **consumed by two or more features** live in
`core/domain/`, not inside any one feature.

```
core/domain/
  entities/
    scripture_verse.dart    Verse, ScriptureText          — home, reading
    question.dart           Question                      — home, quiz
    quiz_session.dart       QuizSession, QuizAnswer       — quiz, result
    streak_summary.dart     StreakSummary, TodayStatus    — home, result
    submit_result.dart      SubmitResult                  — quiz, result
    auth_session.dart       AuthSession                   — auth, app
    user_settings.dart      UserSettings, AppThemeMode    — settings, app
  repositories/
    reading_repository.dart  streak_repository.dart
    auth_repository.dart     settings_repository.dart
  usecase/
    usecase.dart            UseCase<In, Out>, NoParamsUseCase<Out>
```

`core/domain/` is **pure Dart** — no Flutter, no Dio. It declares the four ports and the
entities. `features/*/data/` implements the ports. `features/*/domain/` holds only that
feature's own use cases, which depend on the ports from `core/domain`.

**Placement test:** used by exactly one feature → that feature's `domain/`. Used by two or
more → `core/domain/`. Nothing enters `core/domain/` speculatively.

### SOLID — as testable obligations, not slogans

| Principle | Concrete obligation here |
|---|---|
| **SRP** | One reason to change per file. A cubit owns state transitions only. A mapper owns JSON→domain only. A repository owns transport orchestration only. No file that both fetches and builds widgets. |
| **OCP** | A new script language or question type is added by **adding a class and registering it**, never by editing a growing `if (language == …)` ladder. Bilingual-vs-localized payload differences go behind a `ReadingParser` seam. |
| **LSP** | Every `ReadingRepository` implementation honours the whole contract, *including the non-obvious parts*: never throws across the seam, always returns `Result`, treats HTTP 409 as a typed failure and never an exception. A `FakeReadingRepository` must be substitutable for `DioReadingRepository`. |
| **ISP** | Four narrow ports: `ReadingRepository`, `StreakRepository`, `AuthRepository`, `SettingsRepository`. A single fat `EvangelionRepository` is **forbidden**. Clients depend on the smallest interface that satisfies them. |
| **DIP** | `core/domain/` declares the ports. `features/*/data/` implements them. No `domain/` file ever names a concrete implementation, `Dio`, or `SharedPreferences`. |

### Feature independence

**No feature may import another feature — no exceptions.** Shared UI lives in
`core/design_system`; shared domain lives in `core/domain`. If you want
`features/reading/…` from `features/home/…`, the shared type belongs in `core/domain`.

---

## 4. Dart standards

### Effective Dart — mandatory

- `final` by default; `const` wherever the compiler allows.
- Exhaustive `switch` **expressions** over `sealed` classes / enums. No `if`-chains for
  state branching.
- **No `dynamic`** anywhere. `avoid_dynamic_calls` is enabled.
- Explicit types on every public API.
- Fire-and-forget futures use `unawaited()` from `dart:async` — never a bare expression
  statement that drops a `Future`.
- `debugPrint`, never `print`.
- No `!` unless provably non-null, with an adjacent comment saying why.
- Prefer constructor initialisers and `final` fields over `late`.
- Named parameters for anything with more than two arguments.

### Forbidden APIs — Flutter 3.47.4

| Never use | Use instead |
|---|---|
| `ColorScheme.surfaceVariant` | `surfaceContainerHighest` |
| `MaterialStateProperty` / `MaterialState*` | `WidgetStateProperty` / `WidgetState*` |
| `WillPopScope` | `PopScope` |
| `Color.withOpacity()` | `withValues(alpha:)` |
| `color.value` | `toARGB32()` |
| `MediaQuery.of(ctx).size` | `MediaQuery.sizeOf(ctx)` |
| `MediaQuery.of(ctx).padding` | `MediaQuery.paddingOf(ctx)` |
| `textScaleFactor` | `TextScaler` / `MediaQuery.textScalerOf` |
| `describeEnum` | `.name` |
| `ThemeData.backgroundColor` / `onBackground` | `surface` / `onSurface` |

**This list is a seed, not the enforcement.** `dart analyze` reports `deprecated_member_use`
natively and is the real gate. Adding new deprecated usage fails the build.

Remediation: `dart fix --apply --code=deprecated_member_use`

---

## 5. Backend contract — verified facts, not guesses

Base URL: `http://localhost:3000` (in-memory backend, zero infrastructure).
Prefix: `/api/v1`. CORS is wide open. Auth is **not** implemented — identity is a header.

### Identity headers — required on every request

| Header | Rule |
|---|---|
| `X-User-Id` | **Must be a non-empty string.** Absent → **400** (Fastify schema, `headers must have required property 'x-user-id'`). Present but **empty** → **401**. A **non-UUID** value such as `not-a-uuid` is accepted with **200** and echoed back as `user_id`. |
| `X-Group-Id` | Required for reading + leaderboard routes. Integer string. Use **`3`**. |
| `X-User-Role` | Parsed but **never checked**. Send `kid`. Decorative. |

Missing required header returns **400, not 401**. Do not write client logic that
distinguishes "unauthenticated" from "bad request" on a missing header.

### Seeded working data (in-memory fallback)

| Entity | Value |
|---|---|
| Users | `11111111-1111-1111-1111-111111111111` (David Mina), `22222222-…` (Peter George), `33333333-…` (Mark Anton) — **all group 3** |
| Reading | `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` — John 3:1-5 |
| Question | `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb` |

**Group 3 / John 3:1-5 is the only path that works end-to-end.** The in-memory fallback
fabricates non-UUID ids (`question-group-3`) for any other group or date, and
`POST /readings/:id/submit` then rejects them with `400 body/question_id must match format "uuid"`.

### Endpoints this client uses

```
GET  /api/v1/readings/today/en      X-Group-Id, X-User-Id?
GET  /api/v1/readings/today/ar      X-Group-Id, X-User-Id?
GET  /api/v1/streak/summary         X-User-Id
POST /api/v1/readings/:id/submit    X-User-Id, Content-Type: application/json
     body: { "question_id": <uuid>, "answer": "<letter>" }
```

### Response shapes

`GET /readings/today/{en,ar}` returns a **localized** shape:

```jsonc
{
  "reading_id": "uuid", "group_id": 3, "scheduled_date": "2026-10-02",
  "language": "ar",
  "reference": "يوحنا 3: 1-5",
  "translation": "Smith & Van Dyck (فانديك)",
  "verses": [{ "book_number": 43, "chapter": 3, "verse": 1,
               "text": "…", "text_clean": "…" }],   // text_clean is AR-ONLY
  "questions": [{ "id": "uuid", "sort_order": 1, "type": "mcq",
                  "prompt": "…", "options": { "A": "…", "B": "…" },  // FLAT strings
                  "points_value": 10,
                  "already_answered": false, "user_answer": null, "is_correct": null }],
  "is_fully_completed": false, "total_points_earned_today": 0, "current_streak": 4
}
```

`POST /readings/:id/submit` returns:

```jsonc
{ "question_id": "uuid", "is_correct": true, "points_earned": 10,
  "current_total_points": 10, "current_streak": 1, "longest_streak": 1,
  "reading_completed": true }
```

`GET /streak/summary` returns `{ current_streak, longest_streak, today_status,
today_completed, next_milestone, days_to_milestone, … }`.
`today_status` ∈ `completed | pending | off_day | broken`.

### Traps — the client must handle all of these

1. **Two error body shapes — but only one is real.** Every error this backend
   emits is `{"error": ..., "message": ...}` (Fastify's default reply, plus the four
   hand-written 401s in `streak.routes.ts:84,158` and `submissions.routes.ts:61`).
   The second shape, `{statusCode, code, error, message}`, **appears nowhere** — not in
   `src/`, not in `dist/`, not in `tests/api.test.ts`; the only `statusCode` occurrences
   are `res.statusCode` on the backend's own HTTP client, and there is **no
   `setErrorHandler`**. *Verified live against `HEAD=4a1c834`.* An earlier draft of this
   document asserted "some routes" emit it; that was wrong. The mapper must still accept
   both, because it costs one branch and a later backend may add it — but **document it as
   defensive, never as observed**, or the next reader will write a test that asserts a
   response this server cannot produce.
2. **`text_clean` exists only in Arabic.** English localized responses have no `text_clean`
   key at all. Do not assume its presence.
3. **Duplicate submit → `409`.** The quiz must disable questions where
   `already_answered == true` rather than discovering this as an error.
4. **Streak fields only change when `reading_completed == true`.** A single correct answer
   does not advance the streak; finishing the reading does.
5. **`POST` without `Content-Type: application/json` → `415`.**
6. **`?date=` must be exactly `YYYY-MM-DD`.** Anything else is rejected.
7. **`X-User-Role` does nothing.** Never gate UI on it expecting server enforcement.

8. **THE BACKEND DISAGREES WITH ITSELF ABOUT TODAY, AND `/` READS BOTH ANSWERS.**
   Measured live against `HEAD = 4a1c834`, group 3, user
   `11111111-1111-1111-1111-111111111111`, 2026-10-03 — the two responses were read
   in the same minute:

   | field | `GET /readings/today/en` | `GET /streak/summary` |
   | --- | --- | --- |
   | streak | `current_streak: 4` | `current_streak: 0` |
   | is today done | `is_fully_completed: true` | `today_completed: false`, `today_status: 'pending'` |

   **Neither is a transcription slip** and neither endpoint is wrong about *its own*
   job. The resolution this client takes: **each field comes from the endpoint whose
   job it is, and the two are never reconciled.** `/`'s top-bar flame reads
   `StreakSummary.currentStreak`; `/`'s panel status reads
   `TodayReading.isFullyCompleted`. Nothing sums them, prefers one, or cross-checks
   them — so **when the backend fixes the disagreement, no client line changes.**
   Reconciling (max, "completed if either says completed") is the one answer that
   is ruled out: it invents a number the server never sent.

   The gate is `test/features/home/presentation/pages/home_page_test.dart`, which
   builds both fakes with deliberately contradictory numbers and asserts each
   surface shows its own. `next_milestone: 3` and `days_to_milestone: 3` are carried
   on `StreakSummary` for Phase 8's `StreakPill` and read by nothing in Phase 6;
   `home_page_test.dart` asserts neither reaches the screen.

9. **`text_clean` is AR-only, and it is *absent* rather than null.** Repeated here
   beside trap 2 because Phase 6 acted on it: `GET /readings/today/en` has no
   `text_clean` key on its verses at all, and `GET /readings/today/ar` has one on
   every verse. A preview is a *display* string, so the mapper takes `text_clean`
   when the key **exists and carries something** and `text` otherwise. The visible
   consequence is that the Arabic preview is diacritic-stripped and the English one
   is not — which is a difference, not a defect, and `today_reading_panel.dart`
   records it.

10. **NO SUCCESSFUL SUBMIT HAS EVER BEEN OBSERVED, AND THE IDS PROVE WHY.** Phase 8
    is the first phase to write to this backend, and it cannot. Verified live
    against `HEAD = 4a1c834`, group 3, 2026-10-04, by three POSTs to
    `/readings/:reading_id/submit`:

    | `question_id` sent | response |
    | --- | --- |
    | `question-group-3` — **the id the read endpoint hands out** | `400` · `{"error":"Bad Request","message":"body/question_id must match format \"uuid\""}` |
    | `dddddddd-dddd-dddd-dddd-dddddddddddd` | `404` · `{"error":"Not Found","message":"QUESTION_NOT_FOUND: Specified question does not exist."}` |
    | `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb` | `409` · `{"error":"Conflict","message":"This question has already been submitted by this user."}` |

    `GET /readings/today/{lang}` builds its question ids by string interpolation —
    `src/db/memory_db.ts:241` (`question-group-${groupId}`), `:256`, `:304`, `:320` —
    and `submissions.routes.ts:7` declares the submit body against a `uuid` schema.
    **The two halves cannot both be satisfied**, so the seeded data and the route
    are mutually exclusive and no client can submit against the seeded group.

    **Two consequences, and both are client rules rather than workarounds.**

    * **Do not validate `question_id` or `reading_id` as UUIDs.** They are not, on
      this server, for any reading a reader can actually load. A `uuid` check would
      reject every real payload before it left the device and report a malformed
      request for a well-formed response. The ids are echoed, never authored.
    * **Every submit fixture in `test/` is a TRANSCRIPTION, not a capture.** The shape
      comes from `SubmitAnswerResult` in `src/modules/submissions/submissions.service.ts:5-13`
      and the request body from `submissions.routes.ts:6-8`, with `answer` documented
      at `:35`. `test/support/contract_payloads.dart` is where that lives and it says
      so in its own header, because a fixture whose provenance is a declaration must
      not sit in a file that claims to have been recorded. `reading_harness.dart` and
      `quiz_harness.dart` both read it from there rather than each keeping a copy.

    The `409` row is trap 3 seen from the other side, and it is the one row that is
    *reachable*, so the client's answer to it is the one trap 3 already demanded:
    disable what `already_answered == true` says is done, rather than spending the
    request to learn it.

11. **`readings/today` IS THE ONLY READING, AND ITS ID IS DATE-STAMPED.** §2's route
    table gives `/` one reading and `/reading` another, and Phase 8 found the two are
    the **same resource**. `GET /readings/today/{lang}` returns
    `reading_id: "reading-group-3-2026-10-04"`, and that value is what
    `POST /readings/:reading_id/submit` is addressed by. There is no
    `GET /readings/:id`; a passage screen has nothing to fetch that today's reading
    did not already carry.

    The id changes at midnight, so a fixture that hard-codes yesterday's rots
    silently. `ScriptureText.readingId`'s doc records it, and the harness builds
    passages through `englishPassageWith` rather than transcribing the block per
    fixture, so the date lives in exactly one place.

    This is also why `/result` has **no repository, no use case and no endpoint**:
    the submit response is the only artifact it renders, and that response exists
    only as the POST's reply. There is nothing to re-fetch it from, which is what
    makes `QuizBloc.lastResult` the only holder and `ResultPage({required
    SubmitResult})` a required parameter rather than a resolved dependency.

    **A consequence with a cost, recorded so nobody re-derives it:** `/result` is
    therefore **not deep-linkable**. `ResultRoute` requires its `result`, so
    `pushPath('/result')` cannot build the page. `app_router_test.dart` asserts the
    failure deliberately rather than working around it. The only way in is
    `QuizPage`'s terminal `finish` arm.



---

## 6. TDD protocol

### Red-first — required for

domain entities · `Result<T>` / `Failure` · use cases · API models and mappers ·
the **dual-shape error mapper** · the **header interceptor** · `FakeAuthRepository` ·
the settings repository · `evaScalerFor` · token and motion tables · **every cubit**
(using `bloc_test` + `mocktail`).

Procedure per behaviour:
1. Write the failing test.
2. **Run it and confirm it fails for the intended reason.** A test that fails to compile or
   fails on an unrelated assertion is not a valid red.
3. Implement the minimum to pass.
4. Refactor with the test green.

### Not red-first — widget and screen work

The user explicitly exempted UI from TDD. Widgets and screens get **behaviour tests,
widget tests, and golden tests** written alongside or after the widget, never a
test-first ceremony. Domain logic must **not** be buried inside a widget — if a widget
needs a conditional or calculation, extract it to a cubit or a pure function and TDD that.

### Recorded decisions — Phase 0a review

Two decisions recorded so later phases do not undo them by accident.

**1. The Dio client takes `baseUrl` as a constructor parameter.** It MUST NOT read
`AppConfig.apiBaseUrl` inline inside a DI module. `String.fromEnvironment` is resolved by
the compiler, so the override path cannot be varied at runtime from a unit test. If the
client reaches for the global, the seam needed to test malformed overrides — empty,
trailing slash, scheme-less — disappears, and the override path stays permanently
untestable. `AppConfig` supplies the value at the composition root only.

**2. The `AppConfig` SRP split is deferred to Phase 5.** Do not split it now. It currently
holds exactly two reasons to change, and both are recorded here so the split is not
forgotten rather than rediscovered:

- **Transport tuning** — timeouts and base URL want their own reason to change.
- **In-memory-backend seed fixtures** — `seedUserId` / `seedGroupId` / `seedUserRole` are
  not configuration. They move next to `FakeAuthRepository` when that exists.

### Recorded decisions — Phase 0b review

**3. `NoParamsUseCase` does NOT extend `UseCase<void, Out>`.** The obvious declaration is
illegal Dart, and both plausible repairs are broken too:

```dart
// ILLEGAL — invalid_override: Function() is not a subtype of Function(void),
// because a subtype must accept at least as many positional parameters.
abstract interface class NoParamsUseCase<Out> extends UseCase<void, Out> {
  Future<Result<Out>> call();          // error
}

// ALSO BROKEN — satisfies the override check, but then callers fail:
// "1 positional argument expected by 'call', but 0 found", because a `void`
// parameter is still a required positional at the call site.
abstract interface class NoParamsUseCase<Out> extends UseCase<void, Out> {
  Future<Result<Out>> call([void params]);   // error moves to the call site
}
```

So `NoParamsUseCase<Out>` is declared as a **standalone** interface. The cost, accepted
deliberately: it is not a subtype of `UseCase<void, Out>`, so nothing can hold both shapes
polymorphically. Code needing that must accept a
`Future<Result<Out>> Function()` closure, which both satisfy. See
`lib/core/domain/usecase/usecase.dart` for the documented reasoning.

**4. `configureDependencies()` is `Future<void>`; `getIt.init()` is synchronous today.**
The call site `await configureDependencies()` is therefore stable forever. `unawaited_futures`
will turn this into a compile error the day a module registers an async dependency and
`init()` becomes `Future<GetIt>` — which is the intended behaviour, not a lint to suppress.
The composition root MUST NOT import `package:flutter/`; a test walks the transitive
project-local import graph to prove it. That walk follows `import`, `export`, and `part`
directives in both quote styles — the graph is only Flutter-free if it is followed
completely — and a fixture built out of exactly those non-default forms keeps the walk
honest, because the production graph uses none of them. See §7, "A gate that cannot fail is
worse than no gate", for why that last part is not optional.

This is a **deliberate deferral**, not a rejection. Re-open it at Phase 5.

### Recorded decisions — Phase 1 review

**5. Type sizes are the Material 3 defaults, by decision.** §5.2 specifies no font
size, weight or line height, and the user chose the SDK's `material2021().englishLike`
geometry over an Eva-specific scale. `eva_typography.dart` therefore decides only
*which family renders each slot and in which ink*, and restating the sizes there
would be a second copy of the framework's scale, free to drift from it.

**The consequence, stated rather than discovered later:** `displayLarge` is 57sp
where the prototype's largest type is 34px, and at 1.22× text scaling on a 320px
screen it wraps to four lines — which `09-quality-gates.md` §14 forbids. So Phase 3
owns one of two things and must not skip both:

- clamp the display end of the scale when it builds the first screen, **or**
- amend §14 to state the exception.

**A golden must not be allowed to freeze 57sp silently.** A golden captures the
current behaviour; if the first golden is captured with the display end unclamped,
the four-line wrap becomes the reference image and the §14 violation becomes
permanent and invisible. Clamp before capturing.

**6. Light `onEmber` is `#3A1E00`, deliberately diverged from the spec.**
`03-design-system.md` §5.1 gives `#FFF8EE`. Measured against WCAG 2.x relative
luminance, `#FFF8EE` on the light `ember` `#D4891A` is **2.69:1** — below AA-large
(3:1), let alone AA (4.5:1), so it fails at every text size. The user ruled: keep
the spec's ember, fix `onEmber`.

`#3A1E00` measures **5.41:1** on light `ember` and **13.46:1** as text on the light
canvas. Dark is `#0D0A04` at **9.17:1** on dark `ember`. The token is dark in *both*
palettes because its role is the same in both: ink on the accent. The detail that
matters if anyone revisits this — darkening the value *while it stays light* makes
it worse, not better; the ratio falls monotonically to ~1.05:1 as the value
approaches ember's own luminance (`#D09040`) and only recovers on the far side.

**`docs/plans/03-design-system.md` is now knowingly out of date on this one token.**
It is the *only* token in the design system that diverges from spec, and it was
not edited: AGENT_CONTEXT §8.6 gives `docs/plans/` a dedicated owner. If that owner
revises §5.1, this entry is the change request.

**7. All elevations are `0`, by decision.** `03-design-system.md` has no elevation
table at all, and the React prototype has no z-axis either: every `box-shadow`
there is either a zero-offset ember glow or the single glass ambient that became
`EvaColors.glassShadow`. Layering is carried by `line`, the glass triple, and that
one ambient — so "no Material elevation anywhere" is the faithful reading and the
only value that can be stated without inventing a ramp.

**What "what this suite cannot see" means for elevations.** Every token is `0`, so
`elevation: EvaElevations.card` and `elevation: 0` are the same program. No test can
distinguish reading the token from writing the literal, and a test claiming to is
asserting that two identical programs differ. The suite asserts what *is*
observable — every elevation-bearing `ThemeData` field resolves to `0`, checked over
an enumerated inventory so deleting a line (`null`) or pinning a Material default
is a failure. `EvaElevations.none` is the token for the surfaces §5 names no role
for: drawer, popup menu, bottom bar, navigation bar, and a modal bottom sheet.
`modalElevation` is the one that bites hardest, because a modal sheet resolves it
first and would otherwise sit at Material's 24.

**Known gap, owned elsewhere.** `NeuralScaffold` is Phase 2 and has no elevation
token of its own; if it needs one it must come from this class or from a spec table
that does not exist yet.

**Known sub-AA pairings, recorded so they cannot drift unnoticed.** The light
palette's chromatic tokens were authored against the dark canvas and lose contrast
on near-white. Seven pairings that `eva_theme.dart` wires measure below 4.5:1 in
light; they are enumerated, floored and flagged in `eva_colors_test.dart` rather
than fixed, because the user ruled on `onEmber` only and this phase may not move
another token. One of them — `ember` as the snack-bar *action* colour on `raised`,
at **2.30:1** — is below even AA-large, so it is not "large text only" and Phase 3
owns the fix when it builds the snack bar.

### Recorded decisions — Phase 3 review

**8. Nothing in this suite compares a golden to the React prototype.** This is the
phase's largest structural gap and it is recorded here rather than left to be
discovered in Phase 9.

A golden captures **whatever the widget currently renders**. Every transcription
claim in Phase 3 is therefore checked against the *token* (`EvaColors.ember`,
`kEvaButtonHeight = 52`, `EvaSpacing.sm`) and against the *assertion in the widget's
doc comment* (`ds.tsx:240`, `SettingsScreen.tsx:39`) — never against `eva/` itself.
So a systematic transcription error present in **both** the widget and its golden is
invisible to this suite by construction: the golden ratifies the mistake, the token
assertion confirms the mistake was applied consistently, and the doc comment quoting
the prototype is prose rather than a test input. Phase 3's review found one instance
of the adjacent failure — `TextLink`'s chevron inked `ink` where `ds.tsx:283` writes
`hex.ember` and `EvaButton` inked it `ember`, one prototype glyph in two colours — by
reading the prototype, not by any test failing.

`test/golden_pairs_test.dart` closes the *narrower* half of this: a `*_dark.png` /
`*_light.png` pair that is byte-identical cannot detect a theming regression, which
is the only thing its test name claims, and two of Phase 3's pairs were. It cannot
compare against `eva/`, and it is not a substitute.

**Owner: the phase that first transcribes a screen**, which is **Phase 5**
(`core/network` + the `auth` feature, whose deliverable is `LoginPage`) — *not*
Phase 4, which is routing and DI and writes no screen. A screen is where a wrong
number becomes a user's day. The owner builds a
prototype-comparison harness — a `ds.tsx` line map plus a test that renders the
React component and the Flutter widget over the same inputs and compares geometry
— or records here again why not. Until then, **every transcription claim in this
repository is a claim a human verified by reading `eva/`, not a claim a test
enforces.** A reviewer reading a `ds.tsx:NNN` citation should treat it as an
unverified assertion unless a test names it.

**Phase 5 built the harness, for `LoginPage`, and it found two of its own
citations wrong on its first run.** `test/features/auth/presentation/pages/login_geometry_test.dart`
parses `eva/src/screens/LoginScreen.tsx` and `eva/src/components/ds.tsx` **at test
time** and does three things:

1. a **line map** — every transcription claim names a prototype line, and each line
   is asserted to still declare that number;
2. a **symbol map** — each claim that has a Flutter constant names the symbol, and
   the constant is asserted to equal the prototype's value;
3. a **rendered-geometry** half — the boxes `RenderBox` actually reports are compared
   against the same numbers.

It cannot render the React component: there is no JS runtime in the test process
and `eva/` is read-only reference material (§2, §8). So it does the next mechanical
thing — the prototype's declared numbers are a **test input**, parsed from the file
rather than copied into a table.

Two findings, both of which are the decision-8 failure class:

* **Three of this phase's own citations were wrong.** The social button's height
  and `borderRadius` are on `LoginScreen.tsx:91`, not `:92`, and its `gap` on `:92`,
  not `:93`. The line map failed on its first run, three times, before the table was
  corrected. A doc comment quoting `ds.tsx:NNN` is exactly the unverified assertion
  this decision describes; from this phase forward, on this screen, it is not.
* **A `symbol`-less line map proves nothing about the widget.** The first version
  checked only that the *prototype* still said `72`. Changing
  `LoginPage.kTopSpacer` to `71` — one character — left all 37 tests green. The
  prototype was right, the citation was right, and the screen was wrong. That is
  decision 8's failure mode one layer in from where it was written to apply, and it
  is why the symbol map exists.

**What the harness still cannot see, stated rather than left for Phase 9.** It reads
geometry only: a colour, a radius or a blur alpha is a token, and a *wrong* token is
still invisible to it. It compares what `RenderBox` exposes, so `padding: 24` and
`EdgeInsets.all(24)` are indistinguishable. And it covers `LoginPage` only — the
other five screens are still unverified against `eva/`, so **the "a human verified
this by reading `eva/`" caveat above still stands for them**, and Phases 6–9 should
add each screen's own claims rather than assume this generalises.

### Recorded decisions — Phase 4 review

Phase 4 delivered a seam rather than the thing the plan asked for, so everything
below lives here where a Phase 5 agent will actually read it, and not only in file
doc comments that a following agent may never open.

**9. The auth seam is `AuthStatus`, and Phase 5 inherits four contracts.**

The plan's `AuthGuard` takes `AuthBloc` and redirects to `LoginRoute(onResult:)`.
Neither exists in Phase 4, and the phase's own verification — "pushes `/`
unauthenticated and asserts it redirects to `/login`" — is unwriteable without
something that can be unauthenticated. So the guard depends on `AuthStatus`, one
member, `bool get isAuthenticated`, in `core/navigation/auth_status.dart` (pure
Dart). Phase 5 changes nothing in `app_router.dart`, `auth_guard.dart` or
`app.dart`. The four contracts:

1. **`isAuthenticated` is a pure read.** Side-effect-free, cheap, never a fetch,
   never a validation. The guard calls it on every navigation and again on every
   stack re-evaluation, so a value that had to be awaited turns a redirect into a
   loading state. `AuthBloc.state` satisfies this; an async `isAuthenticated` does
   not.
2. **It MUST NOT throw, and the guard does not catch one.** A throw escapes
   `onNavigation` and the router builds nothing — on a cold launch, a blank first
   frame. `AuthGuard` deliberately does not catch it: `analysis_options.yaml`
   enables `avoid_catching_errors` and `avoid_catches_without_on_clauses`, and
   failing closed *silently* would be indistinguishable from a logout on a guard
   that is explicitly not a security boundary. The error reaching
   `FlutterError.onError` is what makes it diagnosable. Enforced by
   `auth_guard_test.dart`, which asserts both that `decide()` throws and that
   `router.stack` is empty afterwards.
3. **The router's provider reads `AuthStatus` at construction.** Register the
   bloc-backed `AuthStatus` before anything resolves `AppRouter`;
   `bootstrapApp`'s step order already guarantees it. Re-binding it afterwards is
   not a live update, which `navigation_injection_test.dart` asserts in the failing
   direction.
4. **The change signal is replaced, not extended.**
   `ReevaluateListenable.stream(authBloc.stream)`, so a sign-out re-evaluates the
   whole stack. The placeholder is pinned behaviourally — it must announce
   *nothing* — because a placeholder that fires is the wrong shape to copy.

**10. Two deliberate divergences from `06-navigation.md` §8.** The plan is not the
authority; each divergence has a reason that is mechanical, not aesthetic.

- **`lazySingleton`, not a factory.** The plan registers `AppRouter` as "a factory
  that reads the session from the `getIt` instance". A get_it `@factory` guarantees
  the exact hazard the same section warns about: every lookup hands back a new
  router, only one of which is mounted, and any other caller gets an object with
  its own `navigatorKey` and no `Navigator` behind it. `app.dart` reads the locator
  once, in `build`, so the dependency on the lifetime is visible in the shape of
  the statement rather than hidden behind it.
- **`routerConfig(reevaluateListenable:)`, not "in `MaterialApp.router`".**
  `MaterialApp.router` has no such parameter. It belongs on the `RouterConfig`,
  which is what `AppRouter.config(reevaluateListenable:)` builds, and that config
  is what `MaterialApp.router` is handed. The plan's wording describes an intent
  that cannot be expressed as written; the intent is met, the mechanism is the one
  auto_route offers.

**11. Three navigation bindings are registered by hand, and Phase 5 will hit the
same split.** `configureNavigation()` in `lib/app/di/navigation_injection.dart`
registers `AuthStatus`, `ReevaluateListenable` and `AppRouter` by hand, because
`injection.dart`'s whole transitive project-local import graph must stay
Flutter-free (recorded decision 4) and registering the router from a `@module`
would put `app_router.dart` — and through the generated routes, all six feature
pages — inside that closure. Measured, not assumed: relocating the router to
`lib/core/navigation/` makes `verify_purity.sh` report seven violations, because
`auto_route_generator` names its output after the router's own file and emits a
`.gr.dart` beside it.

**Phase 5's `AuthBloc` will hit the identical wall**, and the fix is the one
already taken: `flutter_bloc` re-exports the framework's widget layer alongside the
bloc, and `bloc` itself is a transitive dependency this project may not promote to
a direct one. So `AuthBloc` is registered from `navigation_injection.dart` (or a
sibling file with the same permission), **not** from `auth_module.dart`. The
`six `@module` files are committed and empty**; each says which phase fills it and
that its provider will be a Flutter type. An empty `@module` emits no registration,
and `injection_test.dart` asserts the generated config against them in **both**
directions, so adding a provider without re-running `build_runner` is a failing
test rather than a silently stale committed file.

**12. "Calls `onResult` exactly once" is a mechanism, not a contract.**

`NavigationResolver` completes once — auto_route asserts `!isResolved`
(`auto_route_guard.dart:211`), so a second completion is an unhandled
`AssertionError` in debug and a `StateError: Future already completed` in release.
The obvious trigger is Phase 5's own sign-in control: an `onPressed` plus the
form's `onSubmitted`, or a double tap on a slow device. Nothing made "exactly
once" true — `LoginPage` stated it as a promise to a future author.

**`AuthGuard` therefore latches, inside the method that owns the resolver.** The
latch is a local in `_redirectToLogin`, not a field on the guard: the router
allocates a fresh guard per route per read of `routes`, so an instance field would
be forgotten immediately. `auth_guard_test.dart` calls `onResult` three times and
asserts nothing escapes. Phase 5 does not have to make "exactly once" true at the
call site, though it should try.

**13. `LoginResultCallback` carries a `LoginOutcome` enum, not a `bool`, and the
repository has no `// ignore:`.** `avoid_positional_boolean_parameters` is
enabled, and Phase 4's first draft satisfied it with the repository's only
suppression — justified against `06-navigation.md` §8's `onResult(true)` spelling.
That justification does not hold: the preamble of this file makes it the authority
over `docs/plans/` (AGENTS.md says the same), §4 makes zero analyzer issues the
objective gate, and Dart has no `unnecessary_ignore`, so an ignore nobody needed
could not have been detected either. A named parameter would have satisfied the
lint and kept the boolean, and was rejected because `onResult(didLogin: true)` is
the same hazard as `onResult(true)`. Two callbacks would also have satisfied it
and are strictly worse — "which one resumes?" is a weaker statement than "this one
resumes", and the latch above depends on the second reading. An enum removes the
hazard and the suppression together.

---

### Recorded decisions — Phase 5 review

**14. The dual-shape error mapper's second shape is DEFENSIVE, and the branch stays
anyway.** §5 trap 1 already records the correction, restated from the live checks:
`GET /streak/summary` with `X-User-Id` **absent** gives 400
`headers must have required property 'x-user-id'`; **empty** (sent with an empty
value, not omitted) gives 401 `Missing user identification (X-User-Id header)`; and
a **non-UUID** value gives **200** with `"user_id":"not-a-uuid"` echoed back. The
other observed bodies are `400 body/question_id must match format "uuid"`, `400
querystring/date must match format "date"`, `400 body must be object`, `415
Unsupported Media Type` and `409 This question has already been submitted by this
user.` All eight are in `api_error_mapper_test.dart` under a group named
`observed`.

The `{statusCode, code, error, message}` shape appears nowhere in the backend: no
`setErrorHandler`, no `code` key in any route, and `grep -rn statusCode src/`
returns **nothing at all** — the server's source never writes that key. The 18
occurrences in the repository are all `res.statusCode` in `tests/api.test.ts` and
`tests/streak.test.ts`, which are the *client* asserting on the responses it got.
Re-verified against `HEAD = 4a1c834`. (An earlier draft of this decision said the
only occurrences in `src/` were `res.statusCode` on its own HTTP client; `src/` has
zero, so the citation was wrong about where it looked while the conclusion held —
and held more strongly, since there is now no plausible site for the key to hide.)
Its test group is named
**`SYNTHETIC — defensive branch, a body this server cannot produce`**, and
`Failure.details` is populated only for it. Both shapes produce a `Failure` that
compares **equal**, because `details` is excluded from `props` — so a repository
cannot reclassify the error, and a bloc cannot emit a spurious state change.

**15. `X-User-Id`'s UUID shape is the CLIENT's obligation, and it is checked in
exactly ONE place.** The table above says why: the backend validates presence and
nothing else. One implementation, `isValidUserId` in
`core/network/interceptors/identity_headers.dart`, called from `buildApiDio`, which
throws `ArgumentError` naming the value — a malformed seed is a programmer error and
belongs at composition.

Note the asymmetry with the **group** id, which the server also does not check but
which no client-side check is needed for — group is a small integer and `3` is the
only value that works end to end.

**Corrected after this phase's review: it is one place, not two.** This decision
originally said the check ran in two — `buildApiDio`, and `FakeAuthRepository.signIn`,
which returned a `Result.failure` because a repository never throws across its seam
(§3, LSP). The second was **dead code**: `signIn` seeds from `seedAuthSession`,
which hard-codes `kSeedUserId` with no injection point, so `isValidUserId(existing
.userId)` was tautologically true and deleting the block turned nothing red. The
guard, its `Failure` and the "both are tested" claim are deleted.

That was recorded decision 14's own defect class — a fixture describing a state the
system cannot produce — arriving one decision after 14 was written to forbid it,
which is worth recording as the lesson rather than as a footnote: **"this path has a
branch" is a claim, and the only cheap check is deleting the branch.** The
composition-root check is the one that can fire, and it is tested.

Also recorded, from the same live checks: **`GET /readings/today/{en,ar}` does not
require `X-User-Id` at all** (200 without it), while `/streak/summary` does. The
interceptor sends it unconditionally, which is correct either way and costs nothing.

**16. `AppConfig` was split, as recorded decision 2 required, and the reason is
"reason to change" rather than tidiness.** A base URL and a hard-coded
`11111111-1111-1111-1111-111111111111` are two different kinds of fact: one is
chosen per deployment, the other is a fixture of the backend's in-memory fallback. A
deployment pointed at a real database keeps the first and loses the second, and one
file holding both makes "which of these did this build forget to override?" a
question about a file that cannot answer it. `AppConfig` now holds transport alone;
the seed is `kSeedUserId` / `kSeedGroupId` / `kSeedUserRole` in
`features/auth/data/datasources/auth_local_data_source.dart`. `core_module.dart` is
the one line in the app that touches both, which is the point — it is the single
place the two facts have to agree.

**17. `AuthBloc` is hand-registered, and that made `configureNavigation` DEPEND on
`configureDependencies` for the first time.** Decision 11 predicted the wall exactly:
`flutter_bloc` re-exports Flutter's widget layer, and `bloc` is a transitive
dependency §8.4 will not let this project promote, so there is no spelling of
"generate this registration" that keeps `injection.dart`'s graph Flutter-free.
`AuthBloc` is therefore built in `navigation_injection.dart` from the three
*generated* use cases and registered with `registerSingleton` — a singleton, because
a factory whose body re-ran would hand out a **second** bloc with its own stream,
which is the stale-bloc hazard that function already records for the router.

The consequence is real and is asserted in the failing direction:
`bootstrapApp`'s "graph first, router second" went from advisory to load-bearing,
and `navigation_injection_test.dart` replaced its Phase-4 test *"neither step
depends on the other having run first"* — **that property was true and is now
false** — with one that requires `configureNavigation` to throw a `StateError`
naming an unregistered use case when the graph is missing.

**18. `/login` ships four permanently inert controls, deliberately, and the element
table lives in `LoginPage`.** Email, password, the show/hide toggle and "Sign in" are
live. "Forgot password?", "Create account", and Google and Apple are **rendered and
disabled**: `Semantics(enabled: false)`, no tap action, no focus node, 45% opacity,
and — the part that matters — the accessible name carries the reason
("… — unavailable in this build").

They are rendered rather than dropped because §2's route table says `/login`
includes "social buttons", and a divergence is not this phase's to make silently.
They are *disabled* rather than "live and explains itself" because a fifth control
whose only behaviour is to report its own absence teaches a reader that a button
here sometimes answers with a message about the app rather than about the task. The
cost is stated in `LoginPage` and is real: **four dead controls is visible product
debt**, and the fix is one `onPressed` each once a route or endpoint exists.

Two divergences from `docs/plans/07-file-map.md` §7, which is out of date and is not
edited here (AGENTS.md §8.6): **`google_mark.dart` and `apple_mark.dart` do not
exist.** Reproducing either brand mark faithfully from hand-typed path data means
inventing coordinates — `flutter_svg` is unavailable under §8.4 and Material has no
icon for either — and a four-point polygon that *approximates* Google's mark is a
different logo. The social buttons are text-only. And the file map's §7.1 claim that
the backend "emits **two** error body shapes" is superseded by §5 trap 1.

**19. The password visibility toggle is a feature widget, not `IconActionButton`, and
the `EvaTextField` label had to move.** Two mechanical reasons: `IconActionButton`'s
minimum is `size: 44`, and `EvaTextField` reserves exactly `44` of right inset for
this control — a 44-wide control would need 52 and would overflow the field. And
`IconActionButton.tooltip` is one fixed string, while this control needs "Show
password" / "Hide password".

Building it exposed a **real §14 violation through a Phase-3 widget**. `EditableText`
publishes a semantics node of its own, and an ancestor's `Semantics(label:)` merges
into it only when nothing between them is a semantics boundary — and a `trailing`
control is one. Measured on `/login`'s password field:

```
"Password"                  <- the Semantics around the column, tap=false
  ""          tap=true      <- EditableText's node, UNLABELLED
  "Show password" tap=true  <- the toggle, correctly named
```

A field with no `trailing` merged correctly and read fine, which is why the email
field was never a problem and the password field was, and why `EvaTextField`'s own
`trailing` parameter had never been exercised by a screen. `EvaTextField` now puts
the label on the `TextField` **and removes** the annotation around the column — the
first attempt kept both, and the field's label came out **empty** with
`find.bySemanticsLabel('Password')` matching nothing, which `chip_beads_field_test.dart`
caught on its first run. All 440 design-system tests and the existing goldens are
unchanged.

**20. Two harness facts that cost real time and will cost it again.** Both are in
`test/support/`, and both are the same class: a test that is *not* what it looks
like, and that looks like a broken widget rather than a broken harness.

* **A `Bloc` created in `setUp` does not drive a `testWidgets` tree.** `setUp` runs
  outside the test body's fake-async zone, so the bloc's events are scheduled on a
  microtask queue `tester.pump()` never drains. The state updates and the widget tree
  does not rebuild — measured as `bloc.state` correct and `find.text(…)` returning
  **zero** widgets. Every suite that mounts a bloc builds it **in the test body**,
  with `addTearDown(…close)`.
* **`materialApp(home: Builder(…))` resolves an `ar` locale back to `en_US`.**
  `MaterialApp` matches `locale` against `supportedLocales` (default
  `[Locale('en', 'US')]`) and falls back; `Localizations.localeOf` then reports `en`.
  `evaPrimitiveHarness` also wraps its child in an explicit `Directionality`, which
  sits inside `home` and therefore **overrides** the direction Material installs
  from the locale. Both parameters are now optional on the harness and
  `login_harness.dart`'s `pumpLogin` supplies the app's own pair and derives the
  direction from the locale.

**21. Eight forward-references to "Phase 5" were false the moment Phase 5 closed, and
nobody had noticed for want of a mechanical check.** After the phase's own report was
written, `rg -n "Phase [0-9]" lib/` was swept and every hit audited against the code as
it now stands. Six were wrong, in two flavours:

* **Wrong owner.** `app.dart` (three sites), `bootstrap.dart` and
  `neural_motion.dart` all promised that *this* phase would read a persisted
  `UserSettings` for theme, locale and reduced motion. It did not: this phase
  delivered `core/network` and the `auth` feature, and the settings repository is
  Phase 9. `eva_typography.dart` already said Phase 9, so the file set was internally
  contradictory. `eva_theme_light.dart` went further and claimed "Phase 5 owns the
  `ThemeMode` that chooses between them" — `app.dart` sets `ThemeMode.dark`
  explicitly and still does.
* **Wrong premise, right conclusion.** `eva_section_header.dart` and
  `settings_group.dart` both defer the §3.1 deletion test with the reason "there is no
  feature to demote into until Phase 5". Phase 5 built `features/auth/` and gave
  neither widget a second call site. The **deferral is still correct**; only the
  stated reason rotted. Rewriting a valid decision's justification to match new facts
  would have been as wrong as leaving it — the reasons now cite the call sites, which
  is the thing that was always load-bearing.

The lesson is not "be careful with comments", it is that a phase number in a comment
is a **claim about the future that stops being checked the moment it is written**. It
passed review for two phases because prose cannot fail a test. The cheap defence is
the sweep above, and it should be part of closing any phase:

```bash
rg -n "Phase [0-9]" lib/ --glob '!**/*.gr.dart'   # audit every hit against the code
```

**The recorded command swept `lib/` only, and `test/` had 102 hits with four that
were false the day it was written.** Corrected after Phase 5's own review:

```bash
rg -n "Phase [0-9]" lib test tool --glob '!**/*.gr.dart'   # audit EVERY hit
```

`test/` is where the sweep found the sharpest one, and the shape of it is worth
recording because it is the *same sentence the `lib/` sweep had just corrected*:

* `test/support/design_system_harness.dart` claimed `MaterialApp.builder` "is where
  Phase 5 will install `evaScalerFor`". `eva_theme.dart` says in its own words that
  the builder line "does **not** exist yet" and that `evaScalerFor`'s `step` belongs
  to **Phase 9**. Wrong phase, and wrong about what Phase 5 did.
* `test/app/app_test.dart` claimed the app opens dark "and Phase 5 replaces this with
  the reader's persisted setting". Phase 9, again — and `app.dart` sets
  `ThemeMode.dark` explicitly and still does.
* `test/core/design_system/effects/neural_motion_test.dart` said "Phase 5 replaces the
  default with `UserSettings`". Phase 9.
* `test/core/design_system/widgets/surfaces_test.dart` deferred the §3.1 deletion test
  with the reason "there is no feature to demote into until Phase 5" — the wrong-premise,
  right-conclusion flavour above, in a file the `lib/` sweep had already fixed twice
  over in the same shapes.

And one that is not a phase number at all: `app_test.dart`'s test **name** said
`/login` was "the login stub", in a commit that gave it a real `AuthBloc` and a real
`onResult`. A test name is where a reader looks first, so a stale forward reference
there is worse than one in a comment.

Fix the doc or delete the claim — never leave a forward reference that has stopped
being true, because a reader cannot tell it apart from one that still holds. That is
the same rule as §9's "no report without `file:line`", applied to comments.

### Recorded decisions — Phase 6 review

**22. THE BACKEND'S TWO TRUTHS ABOUT TODAY ARE BOTH SHOWN, AND NEITHER IS
CORRECTED.** §5 trap 8 is the measurement; the decision is what to do with it.
**Each field comes from the endpoint whose job it is, and the two are never
reconciled.** Three alternatives were rejected:

- **Prefer the reading endpoint's streak (`4`).** It agrees with the reading the
  reader is looking at, which is what makes it tempting. It is also a choice made
  *in the client* about a disagreement the *server* owns, and it would silently
  change every number the top bar draws the moment either endpoint is corrected.
- **Prefer the streak endpoint's (`0`).** Same objection, and worse: it is the
  endpoint whose entire job is the streak, so preferring it here means `/` reads the
  summary and ignores the reading it is named for.
- **Reconcile** — take the max, or "completed if either says completed". Strictly
  the worst. It invents a third source of truth that matches neither response, so a
  reader sees a number the server has never sent and the client cannot be debugged
  from the wire.

The property that makes "neither" the right answer is that it is also the
**cheapest**: a backend fix changes the response, not this client. The test that
holds it is a **widget** test with contradictory fakes, not an entity test —
`home_bloc_test.dart` asserts the numbers survived the bloc, and
`home_page_test.dart` asserts each *surface* shows its own. An entity test alone
would only be asserting `props`.

**23. THE TWO DIO ADAPTERS AND THEIR PORTS EXIST NOW, AND PHASE 7 WIDENS THEM
RATHER THAN CREATING A SECOND PAIR.** `07-file-map.md` §7 puts
`DioReadingRepository` and `SettingsRepository` in `reading/data/` and
`FakeAuthRepository` in `auth/data/` — and **names no streak adapter at all**.
`08-build-phases.md` §Phase 6 requires live data through both ports while §Phase 7
claims it owns "the remote data source (`GET /readings/today/{lang}`) and its
mapper". Both cannot be true of the same file.

Resolution: `features/reading/data/` is created **now** with the two data sources,
the two mappers and `DioReadingRepository` + `DioStreakRepository`, projecting the
narrow shape `/` needs; Phase 7 **widens** the same classes. Two ports over one
endpoint — one wide for `/reading`, one narrow for `/` — were rejected: two
repositories, two data sources and two mappers for one request, and the file map's
adapter inventory growing from three to four. A `features/shared/data/` was
rejected because `shared` is not a feature, so Gate 2 has no rule about it, and a
directory whose only content is "the adapters two features share" is the shared
kernel with none of §3's placement test behind it.

**The file map's adapter list is now stale and says so where a reader will look.**
`injection_test.dart`'s registration inventory spells out all eighteen entries, so
the file a reviewer reads to learn what the graph contains is correct even though
`docs/plans/` is not — §8.6 gives `docs/plans/` a dedicated owner and this file
records the correction instead.

**24. `ReadingLanguage` SPLITS ONE LOOKUP INTO TWO, BECAUSE THE SAME FUNCTION IS
NEEDED IN TWO PLACES WITH OPPOSITE REQUIREMENTS.** `fromCode(String)` is the **wire**
direction and returns `null` for anything it does not know, because a mapper that
guessed `english` for an unrecognised `language` would build an entity that claims
to be English scripture and is not. `forLocale(String)` is the **locale** direction
and defaults to English, following `LoginStrings.of`'s existing rule, because
`app.dart` declares exactly two `supportedLocales` and `MaterialApp` resolves an
unlisted one before a screen ever reads it.

The task as dispatched specified a single
`ReadingLanguage.fromCode(Localizations.localeOf(context).languageCode)` for both.
One function cannot do both jobs: a non-nullable `fromCode` forces the mapper to
guess, and the guess is the failure mode the nullable version exists to prevent.
The two names make the two contracts say which is which.

**The locale lives on the EVENT, not on the bloc.** `HomeStarted(language)` and
`HomeRetried(language)` carry it. A constructor parameter cannot work: the bloc is
hand-registered once for the process, so a language fixed at construction would be
the language at *launch* for the rest of the run. A private nullable field with a
`!` at the retry site is the third option, and it trades a read for a field that can
be empty.

**25. THE `home` FEATURE REUSES `AuthRepository` TO GET A NAME, AND THEREFORE
DECLARES ITS OWN `GetReaderSession`.** `HomeScreen.tsx:27` renders `Miriam` and
`ds.tsx:516` renders `MK`; there is no user endpoint and the profile screen is cut,
so those two literals are the prototype's only "who is this". `AuthSession` already
carries `displayName: 'David Mina'` and `initials: 'DM'`, and `/` reads them through
the **port** — which is legal precisely because the port lives in `core/domain/`.

`features/home` may not import `features/auth`, so `GetCurrentSession` is declared
again on this side of the boundary over the same port. That duplication is the
accepted price of §3, not an oversight; promoting the use case to
`core/domain/usecase/` was weighed and not taken, because §3 says
`features/<f>/domain/` holds *this feature's own use cases* and applies the same
placement test that put the port in the shared kernel. `injection_test.dart` asserts
in the failing direction that `lib/features/home/` has **no** import of either
`features/reading/` or `features/auth/`.

**26. THE SESSION HAS NO ERROR SURFACE ON `/`, AND THE BRANCH IS STILL TESTED.**
`AuthRepository.getCurrentSession` answering `Failure` is **unreachable in
production**: `/` is behind `AuthGuard`, which reads `AuthStatus`, which reads
`AuthBloc.state` — the same repository. So the failure arm produces **no name** and
the greeting falls back to the prototype's `…evening.` split. `AuthBloc`'s
`_onSignedOut` takes the same position on the same reasoning.

A test reaches it where production cannot, because a test is one of the two places
an unreachable branch can be reached from — and "no test reaches it" is not the same
claim as "nothing reaches it".

**27. THE PROGRESS BEADS COUNT QUESTIONS, AND THE CLAMP IS CURRENTLY
UNOBSERVABLE — both stated rather than one.** `HomeScreen.tsx:65` is
`<ProgressBeads total={5} completed={2} current={2} />`, which describes *passage*
progress across the four-card library grid §2 decision 1 cut. The live reading
carries **one** reflection question, so the row counts
`TodayReading.questionCount` / `answeredQuestionCount`, and `current` is
`firstUnansweredQuestionIndex(answered, total)`.

The clamp to `total - 1` when everything is answered **changes no rendered state
today**, and that was measured rather than assumed: `beadStateAt`'s rule is
`done = i < completed; curr = i === current && !done`, so with
`completed == total` every bead is `done` whichever index is passed as `current`.
The first version of the doc claimed the clamp keeps a bead reading as "current"
when the reading is finished. **It does not**, and the claim was deleted rather
than reworded. The clamp is kept because `ProgressBeads` *deliberately does not
clamp `current`* — its own doc says so — so an out-of-range value is the one input
that widget lets through, harmless only because `beadStates` compares
`i === current` for an `i` it generated itself. That is a forward-looking argument
and it is labelled as such. `question_progress_test.dart` asserts the equivalence,
so the day it stops being an equivalence the doc is there to be corrected.

**28. A `0 / 0` BEAD ROW RENDERS A LINE, AND THAT IS THE ANSWER, NOT AN ACCIDENT.**
`ProgressBeads` clamps `total` to `0` and returns `SizedBox.shrink()`. A reading with
no questions would therefore render *nothing* between the reference and the two
buttons — a gap indistinguishable from a layout failure, next to a live control,
with nothing saying which it is. `TodayReadingPanel` renders
`HomeStrings.noQuestionsToday` in that slot at the same ink the row's label would
have had, so the row's absence always has a reason. `home_page_test.dart` asserts
it in the failing direction.

**29. THE DROP CAP IS LATIN-ONLY, AND PHASE 7 INHERITS THE RULE.**
`HomeScreen.tsx:55-58` splits a literal `I` off `"n the beginning…"` with a 76px
ember `I`. The Arabic first verse begins `كَانَ`, and enlarging a joined,
right-to-left Arabic letter to 76px breaks its connection to the word it belongs to
and puts an accent glyph where ink should be. That is a defect rather than a
rendering of the design, and it is the same class as defect #2 ("Arabic never uses
the mono family"), which Phase 7 owns in the sanctuary. So `PassageDropCap` is used
for the Latin arm only and the Arabic preview is rendered whole — the rule is
recorded next to the use so Phase 7 does not re-derive it from the prototype.

The branch is on `TodayReading.language` and **not** on "does the text look Latin":
the corpus is the decision (NKJV is Latin, Smith & Van Dyck is Arabic) and the
*language* is the fact the server sent. A shape test would break on a verse opening
with a numeral or a bracket, which §5's live payload does — verse 3 opens
`Jesus answered …`, and a future one could open `‹Verily,`.

**30. THE PREVIEW COMES FROM `firstVerseText` AND IS CUT ON A WORD BOUNDARY.**
`preview_text.dart` is a pure function for §6's reason, and its three decisions are a
budget (56, the prototype's own preview length), a boundary (back up to the last
space in the final fifth) and one character (`…`, U+2026 — the prototype's own glyph,
and §5's payloads contain real ones inside quoted scripture).

**31. THE AVATAR IS 32 PAINTED INSIDE A 44 BOX, AND THAT IS THE ONE DELIBERATE §14
DIVERGENCE FROM THE PROTOTYPE.** `ds.tsx:517` is `width: 32, height: 32`. The painted
circle is exactly that; the **tap and focus box** around it is 44, because
`IconActionButton`'s default and `iOSTapTargetGuideline`'s minimum are both 44 and a
32px target is below what a finger reliably hits. The extra 12 pixels are a
transparent box, so the bar draws what the prototype draws — **the cost is that the
bar's row is 44 tall rather than 32**, because a row is as tall as its tallest
child, and that one number is the whole divergence.

**The avatar's gradient is NOT the prototype's, and that is a recorded
substitution.** `ds.tsx:517-521` fills it with `rgba('#14B8A6', .5)` →
`rgba('#3B5BDB', .5)` and rims it with the same teal. **Neither hue is a token** —
`03-design-system.md` §5.1 publishes fourteen — and `no_colour_literals_test.dart`
refuses every colour in `lib/` that does not resolve through `EvaColors`. So the
badge is the **ink** ramp at two alphas with a `canvas` monogram, which is the
highest-contrast pairing both palettes offer and is what the prototype was reaching
for with a white monogram on a dark badge; the rim is `ember` at 35%, because the
prototype's rim is a hue separating badge from bar and `ember` is §5.1's only
accent.

**32. THE AVATAR IS RENDERED AND DISABLED, WITH THE REASON IN ITS NAME.** The
prototype navigates to `profile` and §2 decision 1 **cut** it, so there is no
destination. `/settings` is the nearest live route and using it would be a product
decision this phase may not make. So `AppTopBar.onAvatarTap` is **required and
nullable** — required so a hard-coded value cannot be reintroduced where one used to
be, nullable because there is nothing to call — and `HomePage` passes `null`. The
accessible name carries `HomeStrings.unavailableSuffix`, for `LoginPage`'s recorded
reason: a reader must be told *why* a control cannot be pressed.

This is **visible product debt** and it is stated as such: `/` ships one permanently
inert control, and the fix is one argument at one call site.

**33. `AppTopBar` HAS NO DEFAULTS AT ALL — AND REQUIREDNESS IS **NOT** THE
WHOLE OF DEFECT #11.** `ds.tsx:508,525,516` hard-code `Evangelion`, `MK` and `12`.
Every value is a **required named parameter** — including the wordmark, which is a
product name, because a hard-coded value and a passed-in value are identical in a
diff and only one of them can be wrong. Three more parameters exist because §14
requires them and a feature widget cannot invent them: `streakSemanticLabel`,
`avatarSemanticLabel` and `avatarUnavailableReason`.

**CORRECTED IN PHASE 6'S REVIEW PASS. This decision previously ended "which is the
whole of defect #11", and that half was false.** `AppTopBar.build` could render
`Text('Evangelion')`, ignore `wordmark` entirely, and pass all 1520 tests — because
the prototype's literal and the shipped value are **the same string**, so every
fixture agreed with the hard-coding. Measured: `app_top_bar_test.dart` passed a
wordmark and never asserted it was rendered, and the only two wordmark assertions in
the phase were `find.text('Evangelion')`, which is tautological between two things
that are supposed to disagree.

**Requiredness guarantees the parameter *exists* at the call site. It guarantees
nothing about whether `build` *reads* it**, and the earlier version of this decision
said so in a subordinate clause while the headline claimed otherwise. The gate is one
assertion: `app_top_bar_test.dart`'s fixture passes `wordmark: 'ZZZ-SENTINEL'` and
asserts `find.text('ZZZ-SENTINEL')`, plus `find.text('Evangelion')` is `findsNothing`.
That is the same discrimination the streak (fixture `4` vs prototype `12`) and the
monogram (fixture `DM` vs prototype `MK`) get for free — applied to the one value
whose two spellings happened to coincide.

`AppTopBar` draws **no glass at all** — see decision 34.

**34. ONE BLUR SITE ON `/`, NOT TWO. §13 RULE 4'S PER-SCREEN LINE WAS WRONG, AND IT
WAS WRONG AGAINST ITS OWN INVENTORY.** The rule counts eight prototype sites and its
per-screen line said "`/`: `.blur` on the today's-reading panel **and the top bar**".
`ds.tsx:499-530` is `TopBar`: a `display: flex` `div` with a `padding` and a
`zIndex` and **no `backdropFilter` in its 32 lines**. The prototype deliberately
leaves the bar see-through so the orbs show behind it.

**One** blur ships, on the panel (`HomeScreen.tsx:39`, `blur(24px)`). `AppTopBar`
stays transparent. A `BackdropFilter` is a `saveLayer` plus a full read-back of
everything behind it, per frame, and adding one to a surface the prototype
deliberately leaves see-through is exactly the "improve the design" this project
forbids.

**`kGlassBlurSigma` IS 24, NOT 20, AND THE `20` WAS NEVER THE MEDIAN.** This decision
previously said the number "stays `20` — with `PassageCard` cut, the one `20` that
survives **is** Home's panel, so the blur that ships is the blur that panel already
had". **All three clauses were wrong**, and the whole of `glass_surface.dart`'s doc
repeated them:

* the radii were misattributed — it named Home's panel as a `20` and the FAB button as
  a `24`. Measured: the panel is `HomeScreen.tsx:39`'s `blur(24px)` and the FAB button
  is `ds.tsx:561`'s `blur(20px)`. The two are swapped, and **no `20` site survives at
  all** (`PassageCard` and `SealFAB` are both cut with the screens that used them);
* `20` is not the median of its own list. The eight are `8, 12, 12, 16, 16, 20, 20,
  24`; sorted, the median is **16**;
* so "the blur that ships is the blur Home's panel had" was false: the sigma was `20`
  against the panel's `24`.

**The number is now `24`, and that is not a new value — it is the prototype's own.**
The only reason to pick a compromise was that eight hand-written CSS radii had to
become one widget, and **only one site blurs**, so there is nothing to compromise.
Rejected: keeping `20` as a "recorded divergence", because the only two arguments
available were the median and the surviving-`20`, and both are false. Rejected: an
upper bound for performance — a `BackdropFilter` costs one `saveLayer` whatever the
sigma, and §13.4's rule is about the *count*. The truth is recorded as the fact it
is: the surviving sites are `8 / 12 / 12 / 16 / 24 / 24`, the shipped sigma is `24`,
and it is Home's panel's own number.

`GlassTier`'s doc named "Home's today's-reading panel and the top bar" and inherited
the error; it is corrected there, at `kGlassBlurSigma`, and in
`glass_blur_budget_test.dart`, whose ceiling for `lib/features/` moved from **2 to
1** so a second site is red. `docs/plans/09-quality-gates.md` §13 rule 4's per-screen
line is corrected in place rather than deleted, so the change is visible; the
*inventory* above it is unchanged and was always right.

**AND THE GATE'S OWN STRINGS WERE HALF-CORRECTED.** The first correction reached the
assertion (`<= 1`) and the first failure message, and missed the test's **name** and
the **second** failure message — both of which still said "two sites" and "Home's top
bar may blur". A gate was tripped deliberately to read the output, and the message a
developer reads when planting a blur in a design-system primitive named a precedent
that does not exist. **A correction to a gate has to reach every string the gate can
print.**

**The previous turn's statement that Home owns two blur sites was wrong, and it was
wrong by repeating the contradiction without checking it.** Phase 5 found the
opposite lesson and recorded it: a claim about a file that is easy to check is a
claim that has to be checked.

**35. `HomePage` LOADS ITSELF, FOR A PASSED-IN BLOC TOO.** `LoginPage` dispatches
`AuthStarted` only on the locator path, which is defensible there —
`AuthStarted` is idempotent against an in-memory fake and the caller owns the bloc.
`HomePage` dispatches `HomeStarted` unconditionally, because the alternative was
measured twice: a widget test has to send the event itself before every assertion
(the first run of `home_page_test.dart` found nothing on screen in **eight** tests
for exactly that reason), and the page then behaves differently depending on where
its bloc came from.

And `HomeStarted` goes out from **`didChangeDependencies`**, not `initState`:
`Localizations.localeOf` is an inherited-widget lookup and Flutter forbids those in
`initState`. The first version dispatched from `initState` and four router suites
went red on landing `/` with
"`dependOnInheritedWidgetOfExactType<_LocalizationsScope>()` … was called before
`_HomeBodyState.initState()` completed". A `_started` flag keeps it to once.

**36. `FakeAuthRepository` MOVED OUT OF `datasources/`, AND IT WAS A PHASE 5
STRUCTURAL DEFECT FOUND IN PHASE 6.** It was at
`lib/features/auth/data/datasources/repositories/` — a repository implementation
nested inside `datasources/`, and a **second** `repositories` directory in a tree
that already has one three levels up. `AGENTS.md`'s layout lists "data sources,
repository impls" as siblings; a repository does not touch a socket, a file or a
store, it orchestrates a data source, and `auth_module.dart` registers it beside the
use cases rather than beside `AuthLocalDataSource`. It is now at
`lib/features/auth/data/repositories/`, and Phase 6 is what found it: adding a
second adapter made "which `repositories`?" a real question with no rule to answer
it.

**37. A NEVER-COMPLETING `Future` IN A `testWidgets` FIXTURE HANGS THE TEST, AND IT
COST FOUR SUITES AT FIVE MINUTES EACH.** `test/support/app_harness.dart`'s first
`HomeBloc` fakes answered by `await Completer<void>().future` — never completed. The
test bodies **finished**; the suite did not. The signature is `test did not
complete` after the full timeout, with `Bad state: Cannot close sink while adding
stream` as the only output, which names neither the fixture nor the cause.

Both fakes now answer a synchronous `Result.failure`, which is the same observable
state with none of it. `login_page_test.dart` records the related and much more
common trap — a bloc built in `setUp` does not deliver its events into the zone
`tester.pump()` drains.

**38. `ensureSemantics` MUST BE DISPOSED IN THE TEST BODY, NOT IN `addTearDown`.**
§14's correction says the handle "must be disposed to avoid leaking across tests",
and it is right — but Flutter 3.47.4's `testWidgets` already holds one of its own
and `_endOfTestVerifications` compares the live handle count against the count
recorded *before* the framework took its own. An `addTearDown` disposal runs after
that comparison, so §14's pattern **verbatim** fails with "A SemanticsHandle was
active at the end of the test". Measured: eight tests, eight failures, on
`home_accessibility_test.dart`'s first run. `login_accessibility_test.dart` records
the same and `focus_ring_gate_test.dart` carries the negative control.

**39. `/` CARRIES FOUR GROUPS OF FIELDS NOBODY READS, AND THE SUITE PROVES NONE OF
THEM IS ALREADY ON SCREEN.** `TodayReading.translation`,
`TodayReading.pointsEarnedToday`, `TodayReading.readingId` / `groupId` and
`StreakSummary.nextMilestone` / `days_to_milestone` are on the payloads and off the
screen.

`nextMilestone` / `days_to_milestone` are recorded in §5 as **Phase 8's `StreakPill`
input** and carried now for the measured reason: the values are recorded, the
payload carries them today, and discarding them would mean a second request to draw
a pill this object could already hold. That is §3's placement rule pushed the other
way, and it is recorded rather than bent quietly. `home_page_test.dart` asserts that
no milestone text, no points figure and no translation name reaches the screen, so a
future phase cannot find them already drawn.

**40. A WIDGET HANDED A `String` MUST NOT THROW ON ANY `String`, AND AN EMPTY VERSE
IS NOT THE MAPPER'S TO REFUSE.** `TodayReadingPanel._Preview` built its drop cap with
`preview.substring(0, 1)`, and `previewText('')` is `''` — so one verse with no text
threw `RangeError (end): Only valid value is 0: 1` **out of
`TodayReadingPanel.build`**. The panel's two controls are that same widget's children,
so the exception took **`Continue` → `/reading` and `Start reflection` → `/quiz`** with
it: the reading route became unreachable from `/`, and nothing caught it because no
fixture had ever had an empty verse.

The false half is the interesting half. `today_reading_mapper.dart` asserted the
opposite in prose — *"neither falls through to `''`, because an empty preview renders
an empty paragraph in the panel"* — and it **did** fall through, and the panel rendered
a thrown exception instead of an empty paragraph. **A doc claim contradicted by the file
it lives in, three directories away, through 1520 green tests.**

The division of labour, which is the part worth keeping: **the mapper says what the
payload means, the widget says it renders whatever it is handed.** Neither guesses for
the other.

*Rejected: refuse `text: ''` in the mapper.* It is the obvious repair and it is wrong.
The verse text is the one field a reader cannot be shown without; everything else in
that payload is a label *over* content. A payload missing its label should cost the
label, not the passage — refusing would turn one cosmetic upstream defect into "the
reader cannot open today's reading at all", which is strictly worse than an empty
paragraph and a reachable `Continue`. *Rejected: a `PreviewText` sentinel.* It would
have made `previewText` total by moving the problem one layer up, and the layer up is
pure domain logic with no rendering to protect.

Witnesses, and **both are needed** — a fix to only one half leaves the other untested,
which is how the two halves drifted apart in the first place:
`today_reading_mapper_test.dart`'s `text: ''` MAPS, deliberately, and
`home_page_test.dart`'s `an empty first verse still renders BOTH controls, because it
cannot throw` — which asserts `Continue` **and** `Start reflection` are still there,
because those two labels are the whole content of the finding.

**41. `/` RE-LOADS ON **RE-ENTRY**, AND THE TRIGGER NEEDED A `NavigatorObserver` THAT
THE ROUTER DID NOT INSTALL.** `_HomeBodyState._started` was a `bool`, set once per
`State` and never reset. Measured with the real router: land on `/`, tap Continue →
`/reading`, `pop` — `readings=1 streaks=1` on entry **and** after returning.
`HomePage`'s element is retained under a pushed route, so `_HomeBodyState` survived.
The reader finishes a reflection on `/quiz`, comes back, and the flame still reads the
number they had before finishing it; there is no pull-to-refresh and no other
invalidation, so this was the whole refresh story.

**The missing wiring was the finding.** `RootStackRouter.config()`'s own default for
`navigatorObservers` is `AutoRouterDelegate.defaultNavigatorObserversBuilder`, which
returns `const []` — so this app installed **no `NavigatorObserver` at all**, and
`AutoRouteAwareStateMixin`'s
`_observer = RouterScope.of(context).firstObserverOfType<AutoRouteObserver>()`
followed by `if (_observer != null)` turned the whole mechanism into a **silent
no-op**. `null` is not an error there; it is the absence of one, which is why nothing
in the tree ever went red. `AppRouter` now overrides `config()` and installs one
`AutoRouteObserver`.

*Rejected: `AutoRouteAwareStateMixin`, which is the obvious spelling.* Its
`didChangeDependencies` calls `RouterScope.of(context)` **unguarded**, and that asserts
— it throws — when the context is not under a `RouterScope`. `pumpHome` mounts
`HomePage` over a bare `MaterialApp`, so the mixin turned every non-router suite in the
feature red on the first pump. `_subscribeToRoute` is the same mechanism with the lookup
as `findAncestorWidgetOfExactType<RouterScope>()`, which returns `null` instead of
throwing — and "no router, no re-entry" is the *correct* behaviour for a page mounted
bare in a widget test. *Rejected: passing `navigatorObservers` at the two `config()`
call sites.* A parameter passed at a call site is one a future call site forgets, and the
whole defect was a default nobody overrode.

**And `_requested` is a `ReadingLanguage`, not a `bool`.** A `bool` cannot say *which*
arm of the corpus was asked for, and `didChangeDependencies` also fires on a **locale**
change — which Phase 9's real switch will cause. With the flag, a locale change left
`/` rendering Arabic strings over English scripture. One field, both triggers.

The re-entry assertion is a **real push and a real pop** in
`home_navigation_test.dart`, and it asserts the **new** answer on screen (`7`,
`John 4:1-14`) after re-stubbing the fakes *while `/` was covered*, with the
first-landing values asserted beforehand so the pair cannot pass by never having been
shown. Its control — `a REBUILD still asks for nothing` — is what stops "re-fetch on
re-entry" and "re-fetch every frame" being the same green test. **The test it
replaced, `'loads once, on entry, and not again on rebuild'`, asserted `calls == 1`
after extra `pump()`s: a rebuild is not a re-entry, the extra pumps did not even rebuild
`_HomeBody`, and the file that could not express the bug was the file that certified
the fix. It was deleted, not fixed.**

**42. A SIGN-OUT CLEARS `/`'S STATE, AND THE SEAM LIVES IN THE COMPOSITION ROOT.**
`HomeBloc` is a `registerSingleton`, so between sign-out and process death it held a
reader's `displayName`, monogram, today's `reading` and their `streak`, and **nothing
took them out**: `AuthBloc._onSignedOut` emits and stops. That is not only hygiene —
`/` is the screen a *second* signed-in reader lands on, and `HomeStarted`'s first emit
(`withGreetingPeriod`, which copies every other field verbatim) carries the previous
reader's name forward.

`AuthBloc` **cannot** dispatch `HomeCleared`: it is in `features/auth` and the event is
in `features/home`, which is Gate 2 — the same wall `navigation_injection.dart`'s
`HomeBloc` section already spent a paragraph on. The reverse is closed too. `lib/app/`
is the one directory Gate 2 exempts (decision 16) and `configureNavigation()` already
holds **both** blocs, so the seam is one listener there.

*Rejected: clear on the page's departure.* It drops the data the screen is about to
re-request, showing a spinner for a frame it created, and it does nothing for a process
that signs out while `/` is **not on screen** — which is the case that actually leaks,
since a route-driven clear only runs while the route is alive.

**The listener fires on `status == AuthSessionStatus.signedOut`, not on `!isSignedIn`,
and the opposite-direction test is why.** `AuthSessionStatus` has four values, so
`!isSignedIn` is *also* true of `signingIn` — which `AuthSubmitted` emits on its way to
`signedIn`. The first version therefore cleared `/` **in the middle of every successful
sign-in**, blanking it three emits before the greeting resolved. The test asserting
`a sign-IN does not` is what caught it, which is the argument for writing both
directions of any new listener.

**43. THE SCRIPTURE **BODY** BRANCHES ON LANGUAGE, AND THE WIDGET THAT CITED THE
DEFECT WAS THE ONE BREAKING IT.** `today_reading_panel.dart` cites defect #2 —
"Arabic never uses the mono family" — as the reason it branches on `reading.language`
at all, and then built **one** `TextStyle` from `EvaTypography.scriptureLatin` for both
arms, 200 lines below that sentence. Only the drop cap branched. Measured on an `ar`
screen: the families in the tree were `{CormorantGaramond, SpaceMono, DMSans,
EBGaramond}` — **`Amiri` absent** — and `EvaTypography.scriptureArabic` was named by
nothing in `lib/` except its own definition and doc. Decision 29 repeated the citation
without noticing the body did not honour it.

Swapping `scriptureLatin` for `scriptureArabic` **unconditionally passed all 1520
tests**, which is the sharper half: neither direction was watched, and grepping the four
`/` suites plus `app_top_bar_test.dart` for `fontFamily` returned zero hits. Branches
that nothing reads are decoration.

`home_page_test.dart` now reads the **rendered** style's `fontFamily` in **both** arms —
the `WidgetSpan`-first paragraph's second `TextSpan` on the Latin arm, and the whole
`Text` on the Arabic arm — and asserts the token **and** the literal family name
(`EBGaramond` / `Amiri`) **and** that the arms are not each other. Asserting
`EvaTypography.scriptureFamily` alone would tie the test to the token rather than to the
rendering, so the literal string is there as the thing the engine actually receives.
*Rejected: a source grep for `scriptureArabic`.* It would watch that the call exists
and not that the right arm calls it.

**44. `withSection`'s INDEPENDENCE IS A DESIGN PROPERTY AND IT HAD **ONE** WITNESS, IN A
TEST NAMED FOR A DIFFERENT PROPERTY.** `home_page_test.dart`'s `'the retry re-fetches
ONLY the streak'` counted `streaks.calls == 2` and `readings.calls == 1` but never
re-asserted that the reading was still **on screen**. Mutating `home_bloc.dart`'s
`withSection` from `reading: nextReading == ready ? reading : null` to `reading: null`
re-issued no request, changed no counter, blanked the panel — and produced exactly
**one** failing test in the whole phase: `home_bloc_test.dart`'s `'withSection() with
both parameters null is the identity'`. **Delete that one test and 1519 pass** with the
reading unconditionally nulled on every retry.

Two assertions now close both directions: `find.text('John 3:1-5')` after the *streak*
retry, and `find.text('0')` after the *reading* retry. The general rule, which is the
transferable part: **a call count is not a rendering.** "`Only` the streak was
re-fetched" is a claim about the network, and the reader-visible consequence is that the
panel is still there — and `HomeState`'s own doc argues that `withSection` rebuilds the
whole state precisely so the untouched section comes through verbatim. A design property
documented in three places and asserted in one is a property with one witness.

**45. THE MAPPER'S SCALAR POLICY: **ONE** REFUSAL, AND IT IS A NEGATIVE NUMBER.**
`reference: ''` and `current_streak: -5` both mapped successfully. `-5` rendered as the
streak in the top bar, beside a sentence saying the streak is glowing or resting.

The line between **refused as impossible** and **passed through as "the server said so"**
is one question: *would this client render the value as something a reader would read as
a fact about their own reading?* Nothing else decides it — not "is it empty", not "is
it big". Refused: a non-list or empty `verses`, a non-object `verses[0]`, an unknown
`language`, and a **negative `current_streak`**. Passed through: `reading_id`,
`group_id`, `scheduled_date`, `translation`, an **empty `reference`**, a large positive
`current_streak`, and a **negative** `pointsEarnedToday`.

*Rejected: refuse every empty string.* Wrong twice over — it refuses `reference: ''` and
makes today's reading unreachable over a missing label (decision 40's argument), and it
makes `current_streak: 0` a failure, which is **exactly the value the live payload
carries on every cold launch**. *Rejected: an upper bound on `current_streak`.* This
client has seen none, and a bound is a claim about a payload it has not seen — the same
argument the class doc makes against *defaults*, applied symmetrically. What makes that
defensible is **layout, and the witness lives in the widget's suite**:
`home_page_test.dart` renders a twelve-digit streak at 320px and asserts no overflow,
because `AppTopBar` puts the wordmark in an `Expanded` with `TextOverflow.ellipsis` and
the number is absorbed by truncating the wordmark. *Rejected: refuse negative points
too.* It is rendered nowhere on `/`, so an impossible value there is inert rather than
loud; the asymmetry is recorded rather than smoothed over, because smoothing it is how
this table began as two unstated habits.

**46. THE STREAK ROW IS **RESERVED**, NOT REMOVED, AND THE RESERVATION IS AN EMPTY
`Text` BECAUSE IT WAS MEASURED.** `home_page.dart` gated the subtitle on
`if (state.streak case …)`, so it vanished while loading and again on a streak failure,
taking `EvaSpacing.xxl` with it and moving the panel up a line mid-screen —
`TodayReadingPanel`'s `_FailedOrLoading.placeholderHeight` exists for exactly that class
of jump, 140 lines away and about a different widget.

Measured, because the whole question is whether an empty paragraph reserves its line:
**`Text('')` at `bodyMedium` is 20.0 tall and 0.0 wide**, the same 20.0 as a non-empty
one. So one `Text` covers both non-ready states and the reserved height cannot drift
from the text's. *Rejected: `SizedBox`.* It satisfies the same measurement and is wrong —
its height would be a second copy of `fontSize × height` that does not move with the
reader's text scale, which §14's 1.22× requirement would then expose. The empty `Text`
moves because it *is* the text, and `and the reserved row grows with the reader's text
scale` is the assertion that rules the `SizedBox` out.

*Rejected: a "streak unavailable" sentence.* Invented copy for a state the prototype
never designed — the same refusal as `_Beads`'s `noQuestionsToday`, which earns its
place by *having* a string. The gap is covered; the silence is not.

**Loading and failure are the same render** — one branch on `streak == null`, one
witness. The loading state is in any case **not reachable from a page-level widget
test**: both fakes answer in a microtask and even a bare `tester.pumpWidget` with no
`pumpFrames` drains enough of the queue for all three emits to have landed. The only
ways to hold the request open are a `Completer` the fake waits on, and decision 37 is
that this **hangs the suite**. Left unwitnessed here and `home_bloc_test.dart`'s to own.

**47. "NO NAME CONSTANT IN `features/home/`" HAD NO GATE, AND THE GATE MECHANISM WAS
ALREADY BUILT ONE FILE OVER.** The rendered value was pinned — `find.text('Miriam')` and
`find.text('MK')` are `findsNothing`, so a *live* hard-coded name is 2 failures. What
nothing pinned was the **constant**: adding
`const String kUnusedReaderName = 'Miriam';` and
`const String kUnusedMonogram = 'MK';` to `home_page.dart` passed all 1520 tests. A
**private** unused constant is caught incidentally, by the analyzer's `unused_element`; a
**public** one is caught by nothing, and one edit makes it live.

What existed instead was two narrower things: `home_strings_test.dart` checked
`HomeStrings` declares no *field* named `name`/`displayName`/`userName`/`greeting`, and
scanned **only `home_strings.dart`**, only for numeric literals.

The scan now walks `lib/features/home/` line by line — **which is `injection_test.dart`'s
loop, in the same shape, built one file over and not reused.** It is not extracted into a
shared helper because it asserts a different thing over a different root and neither
copy is long; what is reused is the *decision* to walk executable lines of a directory
rather than inspect a widget tree, which is the part that was missing. Matching on
**literals** rather than identifiers is what makes it total: a constant, a parameter
default and a `switch` arm all contain `'Miriam'`. Doc comments are skipped, because this
decision and `home_page.dart`'s table *name* the literals in order to forbid them.

**`injection_test.dart`'s own import scan widened with it.** It refused
`features/reading/` and `features/auth/` by name, so `settings/`, `quiz/` and `result/`
would have passed; it is now anchored on the import path and applied to every feature
directory, with an anti-vacuity assertion on the directory set. That is defence in depth
— `verify_purity.sh`'s Gate 2 remains the authority — but a violation caught with the
analyzer running and no shell script is a different failure mode from the gate's.

**48. `HomeEvent.props` IS THE ONE UNCOVERED LINE IN THE PHASE, AND IT IS UNCOVERED
BECAUSE IT IS UNREACHABLE.** It was found by running coverage, and no rationale was
recorded anywhere.

`HomeEvent` is `sealed` and **every subclass overrides `props`** — `HomeStarted` and
`HomeRetried` each return `<Object?>[language]`, and `HomeCleared` returns `const []`
because every clear is the same request. So no instance of the base ever reaches its
getter and it is dead code by construction rather than by omission. `const []` is the
honest answer: it says "no subclass has told me what makes it distinct", which is true,
and returning anything else would be a lie.

Left **without** an `// ignore:` on purpose, because this repository has zero of them by
policy and an ignore would suppress the only signal this line can give — that a fourth
subclass arrived without `props`, which is the classic Equatable mistake where every
event becomes equal and `bloc.add` swallows the duplicate. `home_bloc_test.dart` pins all
three events' equality in the failing direction, so the subclass that drops `props` is
red immediately. *Rejected: making `HomeEvent` abstract and dropping the getter.* It
removes the Equatable contract from the base and leaves each subclass to remember it
alone.

**`HomeCleared.props` IS UNCOVERED FOR THE SAME REASON, AND IT COST A DELETED
ASSERTION TO LEARN SO.** The obvious test — "two `HomeCleared`s are equal" — **cannot be
written without proving nothing**: Dart canonicalises a `const` object, so
`expect(const HomeCleared(), const HomeCleared())` compares one instance with itself,
`Equatable.==` returns on `identical`, and `props` is never read. Building two
**non-const** instances does read it, and `prefer_const_constructors` fires on every
spelling of that because the constructor is `const` and no argument could vary. The
remaining escape is an `// ignore:`, and this repository uses none.

So the assertion was **deleted rather than suppressed**, which is the ninth time that
trade has been made here and the first time the *test itself* was the thing that had to
go. The coverage gap is recorded here instead, which is strictly more than the assertion
was worth: it said `const [] == const []` and this says **why the getter is unreachable
and which subclass to watch for**. The behaviour that would actually matter is asserted
where it is observable — `HomeCleared and it is idempotent, because sign-out can arrive
twice` — because `HomeState`'s equality is what suppresses a duplicate emit, and that
one *is* exercised.

The same shape covers `home_page.dart`'s three remaining uncovered lines:
`didPop`, `didInitTabRoute` and `didChangeTabRoute` are the empty bodies auto_route 11's
`AutoRouteAware` requires. `didInitTabRoute` / `didChangeTabRoute` are **permanently**
unreachable — none of the six routes is a tab route — and `didPop` needs a test that
pops `/` itself, which asserts nothing a reader could observe. Three one-line interface
members, written out rather than left unimplemented (an unimplemented one is a compile
error today and a silent no-op the moment the package gives it a body), recorded here
rather than suppressed.


### Recorded decisions — Phase 7 review

**49. ONE PORT, TWO METHODS, AND THE WIDE ONE IS THE PORT.** `ReadingRepository` gains
`todayScripture` alongside `today`, and the wide one is the *port* rather than a private
detail of the data layer. `07-file-map.md` §7 implies one method; `08-build-phases.md`
§Phase 7 requires `GET /readings/today/{lang}` through it. Two alternatives were
rejected:

- **A second port, `ScriptureRepository`.** Two ports for one endpoint means two
  adapters, two sets of fakes, and a question — answered per screen — about which one a
  caller wanted. `core/domain/` exists so a type consumed by two features lives in one
  place; `ScriptureText` is consumed by `/` and `/reading`, so it belongs there, and so
  does its port.
- **Make `today` return the wide type and let the screens ignore the extra.** This is
  what actually shipped, and the reason it is right is that `TodayReading` stays a
  **projection** rather than being deleted: `/` wants six fields and `/reading` wants
  verses. `ScriptureText.toTodayReading` is the narrowing, it is in the domain layer, and
  `DioReadingRepository.today` delegates to `todayScripture` rather than fetching twice.

**50. THE MAPPER IS WIDE AND NARROWING, WITH A STATED SKIP POLICY, BECAUSE THE LIVE
PAYLOAD IS NEITHER CLEAN NOR UNIFORM.** §5 traps 2 and 3 are the measurement. Verse 0 is
**strict**: a malformed first verse is a `Failure`, because the screen has nothing to show
without it. Verses 1 and up are **skipped**, and malformed questions are **skipped**,
because a passage with four of five verses is still the passage and a screen is not a
validator. Three alternatives were rejected:

- **Strict on every verse.** One bad row in a 40-verse passage blanks the whole reading.
- **Substitute an empty verse.** The reader sees a numbered gap with nothing in it and no
  way to know it is a gap; the skip is at least visible as a missing number.
- **Throw the whole response away.** Strict-on-first is already that, for the only case
  where it is defensible.

`questionCount` counts the questions that **survived**, not the ones the server sent, so
the CTA cannot promise five questions and deliver three.

**51. `Verse` RENDERS `text`, NEVER `displayText`, AND THE FALLBACK IS ONE SHARED RULE.**
`textClean` is absent on every English verse and present on every Arabic one (§5 trap 2), so
both arms have to resolve a string. The rule is `textClean ?? text` — **the same sentence
in both arms**, which is what lets one `RichText` per verse serve them. `verseDisplayText`
exists as the single place that sentence lives.

**52. THE QUESTIONS TRAVEL WITH THE ANSWER AND ARE NOT RENDERED.** The live reading
response already ships `user_answer` and `is_correct` (`reading_harness.dart`'s fixture is
the evidence). `/reading` shows the passage and a CTA; the questions belong to `/quiz`,
which is Phase 8's. The temptation to render them here is declined and recorded, because
"the answer is not on the screen" is a claim that has to be asserted against a payload that
**has** one to hide — which is why the fixture carries it rather than omitting it.

**53. THE REFERENCE IS VERBATIM AND THE TRANSLATION IS A LABEL; THERE IS NO DURATION.** The
Arabic reference keeps the server's space after the colon (`يوحنا 3: 1-5`) because
normalising a citation is the client editing the server's data. The translation row is
`Smith & Van Dyck (فانديك)` **as one string** — the server already merged the Arabic name
into the Latin one, and splitting it would be a guess about where the boundary is. No
reading duration is rendered: the live payload's is `null` and §5 records that, so a
number would be invented.

**54. THE ARABIC ARM IS ALL AMIRI, AT NINE SITES, AND THE DEFECT WAS UNDER-COUNTED.**
`01-source-analysis.md` §2 row 2 said two; the source says **nine** — `ReadingArScreen.tsx:35`
(metadata), `:86` (CTA caption) and `:49,51,56,58,63,68,70` (the seven `<sup>` verse
markers). The row has been corrected. `ds.tsx:298,341` are the two **English-only** sites
and stay in Space Mono, which is the point of the split. `reading_glyph_test.dart` parses
the five bundled TTFs and asserts every character on the screen is carried by the family
that renders it — so a future font swap that drops a codepoint fails here rather than
shipping as tofu.

**55. THE `✦` DROP CAP IS ABSENT FROM ALL FIVE FAMILIES, SO THE GLYPH GATE EXCLUDES IT
RATHER THAN PRETENDING.** Measured: `U+2726` is in none of the bundled TTFs. The prototype
uses it as a passage ornament; the client does not draw it, and `reading_glyph_test.dart`
filters it by name with that measurement in its doc. Substituting another ornament would be
a new design decision, and inventing a codepoint's coverage is worse than recording its
absence.

**56. NO `SettingsRepository`, SO THE FONT STEP IS EPHEMERAL AND SAID TO BE SO.** Nothing
in `lib/` reads a settings port — `07-file-map.md` §7 lists the file, and Phase 9 is what
owns it. There is therefore nowhere durable for the reader's `Aa` choice to be written, so
it lives in `ReadingCubit` for the life of the cubit. `reading_text_scale.dart`'s doc states
in prose that the choice does not survive leaving `/reading`, which is the honest
alternative to silently implying persistence. Two alternatives were rejected: a
`shared_preferences` call now (a dependency added in a phase that does not own it), and
dropping the control (it is in the prototype and `SettingsScreen.tsx:66`).

**57. NO VERSE-NUMBER FLAG.** The `Ss`/`١٢` toggle exists in the prototype. Nothing in the
live payload or the six screens needs it, and it would be a state flag with no consumer.

**58. THE BOOKMARK IS INERT AND SAYS WHY IN ITS OWN NAME.** There is no bookmark endpoint,
so the button is `onPressed: null` with the label `Bookmark — unavailable`. §14's disabled
row is the reason: the action is **absent**, not present-and-flagged, and the name carries
the reason. `reading_accessibility_test.dart` asserts the absence and the name, and the
keyboard group asserts it is not a Tab stop.

**59. THE COMPOSED SCALER IS THE PRODUCT, CAPPED AT THE TABLE'S TOP ROW, AND THE DEAD ZONE
IS ASSERTED RATHER THAN ONLY DESCRIBED.** `reading_text_scale.dart` carries the four-rule
table and the measurements. `reading_text_scale_test.dart` mounts all four: step 1 at
platform 1.0 (which a `max` rule renders as 1.00, so the reader's drag toward "smallest"
does nothing), step 1 at platform 1.22 (which a *replacing* rule renders as 0.90, losing
the reader's OS setting in the one screen where reading is hardest), the ceiling, and the
**collapse at 1.22** — §14's own surface is above the 1.109 the file names, so the dead
zone is present and the test says so. If a future table change removes the dead zone, that
test is red, which is the correct direction: the cost is a promise.

**60. ONE PARAGRAPH PER VERSE.** `ScriptureBlock` emits one `TextSpan` per verse, each
labelled `Verse <n>` in its own `Semantics`, so a reader navigating by node can be told
which verse they are on. One label for the whole passage would be more useful to a screen
reader in one sense and useless in the one that matters. The header has **no** label of its
own, and `reading_accessibility_test.dart` asserts it has none.

**61. RTL IS A TRUE MIRROR, AND THE PROTOTYPE'S INCONSISTENT CHILD ORDER IS NOT REPRODUCED.**
`ReadingArScreen.tsx` sets `textAlign: 'right'` where the English screen sets none, and
`textAlign: 'start'` resolves to exactly those two under the ambient direction — so this
client writes `TextAlign.start` and neither arm names a direction. The metadata row and the
citation are `'center'` on **both** arms and are therefore not mirrored; `MaterialApp`
supplies the direction and there is no `Directionality` anywhere under `lib/`.

**62. THE CTA IS A BARE `Container` INSIDE A `Stack`, NOT GLASS, AND THE `Stack` PUTS IT
ABOVE THE `Scaffold`.** `04-widget-inventory.md` line 54 already says the prototype's CTA is
not glass; `ReadingEnScreen.tsx:88-92` draws `rgba(15,17,26,0.96)` at `4px 24px 32px` blur
`20px` over the scrolling page, which is a scrim, not a `GlassSurface`. A `GlassSurface`
there would be a second backdrop on screen and `reading_geometry_test.dart` measures the
padding and the radius against the prototype. The `Stack` ordering is asserted by
`reading_geometry_test.dart`: the CTA is a sibling **after** `Scaffold` and the bottom fade,
because a `Column` would let `Scaffold`'s own background paint over it.

**63. THE ARABIC BAND'S HUE IS SUBSTITUTED, AND THE SUBSTITUTION IS NAMED.** The
prototype's `#B79CF0` is not in `EvaColors`, and `no_colour_literals_test.dart` forbids a
literal in `lib/`. `colors.ink` at `0.3` / `0.2` alpha is the substitute, chosen because it
is a token that exists on both themes. Recorded as a divergence rather than added as a
13th colour token, which would be a design-system change in a phase that does not own it.

**64. THE DROP CAP DIVERGES FROM THE PROTOTYPE'S LITERAL 76 — AT 146.57, NOT 131.1.**
`ScriptureBlock._dropCapFor` derives the size from the body size and a cap-height ratio:
`3 × 1.8 × 19 / 0.7` = **146.57142857142858**, against the prototype's 82 on this screen
and 76 on `/`. `01-source-analysis.md` and the Phase 6 comment that called it a
"transcription" have been corrected. The `76` and `82` are `fontSize` literals with no
`Symbol` to certify, and the geometry suite now says so instead of leaving the impression
that nothing was checked.

**This decision previously said 131.1 and was wrong about the value it was attached to.**
131.1 is the *same arithmetic at body size 17* — `TodayReadingPanel.previewFontSize`, `/`'s
size — so the number was not invented, it was correct for the other screen and quoted for
this one. The code and `passage_drop_cap_test.dart` (`closeTo(146.57, 0.01)`) agreed with
the arithmetic all along; only the prose was wrong, in four places, and it was wrong
*downward*, so a reader checking it found a plausible number rather than an obvious typo.
The largest element on `/reading` is **146.57**.

**The lesson is the one §9's rule already states, applied to itself:** a number in a doc
is a claim about a specific thing, and "which thing" is part of the claim. Three places
now say `fontSizeFor(19)` or `fontSizeFor(17)` by name instead of saying "the drop cap".

**65. THE ARABIC PLURAL BOUNDARY IS `== 1`, AND THE LIMITATION IS DOCUMENTED IN
`ReadingStrings`.** English has two forms and Arabic has six. `captionFor` special-cases
`1` on both arms and renders the **real count** for everything else, which is **wrong for
2, 3 and 11** in Arabic. The chosen rule is the one that is right for the common case and
never *wrong-looking*, and `ReadingStrings`'s doc says plainly which counts are
mistranslated and that the six-form table is Phase 8's — because the alternative (six
hand-written forms in a phase whose scope is the passage) is a bigger unreviewed guess.

**This decision previously said `captionFor` "renders `5` for everything else". That is
false and was never true.** It renders the count it is given; hard-coding `5` fails four
tests. The prototype's `٥ أسئلة` was a hard-coded number, and the whole point of the
change was to stop transcribing it.

**And "§5 records that the server counts questions in Western digits" does not contradict
`reading_strings.dart`.** They are two different facts: §5 is about the **`question_count`
field the server sends**, and the caption's numerals are a **client-chosen** rendering of
it — `arabicIndicDigits` converts, so the Arabic arm draws `١` from a Western `1`. As
written the sentence described code that does not exist, because it implied the two were
about the same string.

**66. `EvaButton` GAINS A **REQUIRED** `labelFamily`, BECAUSE A LABEL THAT NEEDS A FACE THE
BUTTON CANNOT SET IS A NEW WIDGET.** The CTA renders its caption in Amiri on the AR arm
without a second button type. The alternative was a `StickyCta`-local `TextButton`, which
duplicates focus ring, disabled state and hit target. The glyph test is what forced it:
the CTA label is one of the AR sites.

**Two claims this decision made about itself were false and are corrected here.** It said
"All eight existing call sites are untouched" — there are **four** `EvaButton(` sites in
`lib/`, not eight — and it said "the parameter is required and every one passes it" —
it shipped **optional and nullable**, and **one** site in four passed it. A nullable knob
means the compiler is silent at every site that forgets it, and the value it falls back
to is `titleMedium`'s, which is **DM Sans**, which carries no Arabic glyph at all; so
Phase 8's quiz CTA and Phase 9's settings CTA would have shipped tofu in Arabic with the
compiler silent. It is now `required`, all four sites pass a **per-arm** family, and
`ErrorView` — which builds a button — grew a `retryFamily` for the same reason. See
decision 69.

**67. THERE IS NO `ScriptureVerse` WIDGET; THE VERSE IS A PRIVATE METHOD ON
`ScriptureBlock`.** `07-file-map.md` line 125 lists `scripture_verse.dart`. The verse
needs four things from its parent — the `TextStyle` the block derived for the language,
the `TextStyle` for the marker, and the `PassageDropCap` that only the **first** verse
may have — so a separate widget would take three of them as required parameters and a
fourth as a nullable. That is the shape of a parameter object with no behaviour of its
own. The method that exists (`ScriptureBlock._verseParagraph`) builds the same
`RichText` with the same four inputs, so nothing is lost and the block's
`ListView.builder` remains the single place an item is built.

Two alternatives were rejected:

- **A `ScriptureVerse` widget taking the three styles.** It would be testable in
  isolation, and it would need a test that passes all three styles to construct it — a
fixture that re-derives the production derivation, which is the coverage that reads as
coverage and asserts nothing.

**68. THERE IS NO `models/` LAYER IN `reading/data/`, AND THAT IS A PHASE 6 DECISION THIS
PHASE INHERITED.** `07-file-map.md` listed `scripture_text_model.dart`, `verse_model.dart`
and `question_model.dart`. Phase 6 shipped `streak_summary_mapper.dart` mapping **straight
to the domain entity**, with no model class, and the reading data source parses into
`ScriptureText` in one step. A model trio would be three classes whose every field is a
copy of an entity's, plus a mapper that copies them back — the "dual source of truth for
one value" shape that defect 5 already removed from the design system, in the data layer
instead. Three alternatives were rejected: keep the models for symmetry (symmetry with a
file that does not exist), keep them "in case the wire shape changes" (a `Map<String,
dynamic>` parse is where a wire change is absorbed anyway, and a model class would have to
change too), and make the models `freezed` (a generator for a shape already represented by
a hand-written immutable entity with `==`).

The naming that did survive is `DioReadingRepository` and `DioStreakRepository` — two
`Dio`-prefixed adapters for two ports, which is what decision 23 already settled. The
file-map lines have been corrected rather than left to be read as omissions.
- **A widget taking the `Verse` and the language and deriving the styles itself.** Then
  the drop cap has to be threaded in too, and `first` becomes a positional boolean at a
  call site that reads `child: ScriptureVerse(verse, language, cap: null)`.

`reading_geometry_test.dart` asserts the *paragraph* geometry, which is what a reader
meets, so the missing widget costs no measurable coverage — the file-map line has been
annotated rather than left to be read as an omission.

**69. THE FIRST CHARACTER OF A PASSAGE IS SPLIT BY ONE SHARED PURE FUNCTION, ON A **RUNE**,
AND THE CUT IS **NEVER** BETWEEN THE TWO HALVES OF AN ASTRAL CHARACTER.**
`core/domain/entities/drop_cap_text.dart`'s `splitDropCap` answers "what is the drop cap's
letter, and what is the rest of the paragraph" for **both** screens — `/`'s preview
(`today_reading_panel.dart`) and `/reading`'s first verse (`scripture_block.dart`).

**The defect it fixes, measured twice.** `String.substring` indexes **UTF-16 code units**,
so `substring(0, 1)` on a character above U+FFFF returns the **high surrogate alone** —
measured `codeUnits == [55357]`. `RenderParagraph` then throws `ArgumentError: string is
not well-formed UTF-16` out of `_RenderScaledInlineWidget.performLayout`; and because the
cap is a `WidgetSpan` **inside the first paragraph**, the throw takes the passage, the
metadata row **and both CTAs**. `/` is the wider of the two surfaces: its bug is the
*truncation*, so an emoji anywhere in the first 56 code units of verse one is enough, not
only at index 0.

**Why one function and not two fixes.** Phase 6 fixed the *empty* string at `/` and Phase 7
re-created the identical `substring(0, 1)` at `/reading`, in a new call site, with the same
`isEmpty`-only guard — so the C3 fix was incomplete and this phase reproduced the failure
it was written to prevent. Two call sites of a two-line rule is one rule, and a rule with
two copies has one copy wrong before the next reviewer notices.

**Why it is in `core/domain/`.** §3: two features consume it, so it is the shared kernel.
§6: it is a conditional plus a calculation, which is the definition of logic a widget must
not contain. Gate 1 holds the file Flutter-free, and `runes` / `fromCharCode` are pure Dart.

**Why the cut skips leading whitespace.** `isEmpty` is the right question about a string and
the wrong question about a *character*: `' ‹Verily…'` is not empty, its first character is
a space, and a space enlarged to 146.6 logical px is an **invisible glyph** — the largest
element on the screen rendering nothing, with the paragraph starting one letter in. A tab is
the same. Only **leading** whitespace is the cap's business; the tail belongs to the
paragraph and dropping it would be the client editing scripture.

**And it is NOT a shape test, which recorded decision 29 still refuses.** A verse opening
with a bare combining mark (`'\u0301Verily'`) would still make an enlarged accent the cap.
Stripping marks is a shape test, and decision 29 rejects one for this widget for a measured
reason: it breaks on a verse opening with a numeral or a bracket, and §5's live payload
opens one behind a `‹Verily`. Recorded as a non-fix rather than fixed, because the fix and
the decision are the same shape.

Alternatives rejected:

- **`text.runes.take(1).map(String.fromCharCode)` inline at each call site.** Two copies of
  the astral fix and the trim rule, which is exactly the shape that let Phase 7 re-create
  Phase 6's defect.
- **`package:characters`.** Already a transitive dependency, so no `pubspec.yaml` change —
  and §8.4 pins that file, so promoting it is a hard stop. It also does not answer the trim
  question, and `String.fromCharCode` on a single rune is the whole of what is needed.
- **Stripping combining marks too.** A shape test; see above.
- **Leaving the second half to `previewText` only.** `previewText` owns the *truncation* and
  cannot own the *first-rune* split, and fixing only the truncation leaves
  `preview.substring(0, 1)` returning a lone surrogate for a preview that opens with one.

**70. THE CTA IS GATED ON A QUESTION, NOT ON A PASSAGE.** `ReadingPage` renders
`StickyCta` when `state.scripture != null`. That is the right question about the **failure**
state and the wrong one about a **succeeded** one: `questions: []` is reachable, because the
mapper **skips** an unreadable question rather than refusing the passage (recorded decision
40), so a payload of four unreadable questions reports `questionCount == 0`. Measured: the
caption rendered `"0 questions"` / `"٠ أسئلة"` and **Begin reflection was still offered**, so
a reader with nothing to reflect on was invited through to an empty quiz. The gate is now
`when passage.questionCount > 0`, and the passage itself is untouched — the sanctuary still
renders in full; what goes is the invitation.

Rejected: hiding the CTA on `status != ready`. It reads as if the passage were not loaded
either, and the failure state is already covered by its own test — the same test that
states the principle ("the CTA is gone, because there is nothing to reflect on") this one
now applies to the second payload shape.

**71. THE GLYPH GATE PAINTS ITS TOOLTIPS, AND ITS ARABIC PREDICATE IS THE **BLOCK**, NOT
FOUR SAMPLED CODEPOINTS.** `01-source-analysis.md`'s defect #2 and `08-build-phases.md`'s
Phase-7 note both said the gate asserts "**every character on the screen**". It did not, and
the difference was **thirty tofu boxes**.

The prototype's nine Arabic sites were the **floor, not the ceiling**. Its four top controls
are bare `<button>`s with an inline `<svg>` and **no label at all**
(`ReadingEnScreen.tsx:14-16`, `ReadingArScreen.tsx:21-29`), so §14's requirement for an
accessible name forced three Arabic strings into this client that the prototype never
wrote — and they render through `IconActionButton`'s `Tooltip`, whose
`Tooltip(message: …)` carried **no `textStyle`**, so Flutter resolved `null` to
`ThemeData.textTheme.bodyMedium`, measured **`DMSans`** on **both** themes. Measured on the
shipped `ReadingPage` at `Locale('ar')` with the long press held: `TOOLTIP "رجوع"` (4
tofu), `"حجم الخط"` (7), `"إشارة مرجعية — غير متاح في هذه النسخة"` (**19** codepoints). Every
other Arabic run on the screen was Amiri.

**Two independent reasons the gate was blind to all three, and both had to be fixed.**

1. `renderedRuns()` walked the **already-painted** tree, and a `Tooltip` paints nothing
   until a gesture. The probe found **zero** tooltip `Text` widgets. So the walk is now
   `Future`-returning: everything painted now, then each `Tooltip` held open past
   `kLongPressTimeout` and everything painted then, deduplicated.
2. `_isArabic` sampled `[0x0628 ب, 0x0644 ل, 0x064Eَ, 0x0665 ٥]`. `رجوع` is
   `U+0631,062C,0648,0639` — **none of the four**. So even painted, two of the three would
   have been skipped by tests 1 and 2. It is now a **range** over the four Unicode blocks
   Arabic script occupies, which is the question a reader can check.

**And the walk itself had a third bug, found by the fix and worth recording.** It added a
run for *every* `TextSpan`, using the whole span's plain text as the label and
`bodyMedium` as the family when the span carried no style. Flutter's `Tooltip` builds its
content as `TextSpan(style: effective, children: [TextSpan(text: message)])` — the **root**
carries the family, the **child** carries the text — so the walk read the child's
`fontFamily` as `null` and substituted `bodyMedium`: it reported **`DMSans`** for a tooltip
the app had already rendered in **`Amiri`**. A correct fix looked wrong, in the one family
the file exists to catch. The walk now threads the effective style down the way
`TextSpan.build` does, and a `TextSpan` with children and no text of its own contributes no
run at all — it paints nothing.

The gate's table is now **nine** rows of which **eight** were tofu. `IconActionButton`
gained a **required** `tooltipFamily` for the same reason `EvaButton.labelFamily` is
required (decision 66): the knob does not affect the button at all, it affects a `Text` the
design system builds, and a caller that omits it gets `bodyMedium` silently.

**72. THE PROTOTYPE LINE MAP IS **ANCHORED ON BOTH ENDS**, AND `contains` WAS ADMITTING A
FALSE MATCH.** `reading_geometry_test.dart` compared each claim's `pattern` with
`String.contains`, and every pattern ends in a **number**. So `fontSize: 19` is satisfied by
`fontSize: 190`, `marginTop: 8` by `marginTop: 80`, `height: 5` by `height: 50` — and the
symbol map cannot see it, because `expected` is the number the *table* says rather than the
number the *prototype* says. **Live, end-to-end**: the Arabic band's claim was the bare
string `'2px,'`; the line has **two** `2px,` (the dash and the transparent stop beside it);
rewriting the prototype's dash from `2px` to `12px` left the **whole suite green** while
`arabicBandDash == 2` was separately asserted. **Third instance** of `contains` accepting
`240` for `24`.

The check is now `declaresAt(line, pattern)`: a regular expression with `(?![0-9.])`, so a
match may not end on a digit or a decimal point. `(?![0-9A-Za-z])` and not that, because the
tracking claims end in `em` and the letter after a matched `'0.10em'` is its closing quote.
The **left** end cannot be generalised, so the one claim whose false match is on the left
carries the boundary in its own pattern: `bandDash` quotes `')} 2px, transparent'`, which
marks *which* `2px` is the dash. A leading space was tried first and **does not work** — the
line's surviving `transparent 2px,` still matched it; that is measured and named here so it
is not tried again.

**73. `home_page_test.dart`'s ARABIC ARM WAS AND IS **MOSTLY TOFU**, AND THIS PHASE DID NOT
FIX IT — THE MEASUREMENT IS RECORDED INSTEAD.** With `EvaButton.labelFamily` now required,
`/login` and `/` render their Arabic button labels in Amiri; measured on the shipped
screens at `ar`, the families in the tree are still `{CormorantGaramond, SpaceMono, DMSans,
EBGaramond}` — **`Amiri` present only because of `_Preview`**. `/`'s subtitle, reference,
status line and `Start reflection` are DM Sans or Space Mono; `/login`'s tagline, field
labels, hint, links and both social buttons are the same. Ten-plus runs per screen.

This is Phase 10's work and it is **not** this phase's: fixing it means giving every run on
two shipped screens a per-arm family, which is a screen rewrite wearing a parameter's
clothes. What is decided here is only that the two button labels this phase had to touch
are no longer among them, and that the measurement is written down at the two call sites so
the next reader is not told those screens are whole.

**CORRECTED AND DONE BY THE NEXT PHASE — SEE DECISIONS 74–80 BELOW.** The deferral was
reasonable and the *diagnosis* was wrong twice over, which is the more useful part:

* the claim that fixing it means a per-arm family on every run is **false**, and it is
  false for a measured reason — `TextLink(label: strings.createAccount)` has **no arm to
  pass**. There is no payload behind a link's label, so the required constructor argument
  that decisions 66 and 71 built for `EvaButton` and `IconActionButton` is *unanswerable*
  on a `TextLink`. The rewrite was avoided by a function, not deferred;
* the **measurement itself was incomplete**. Re-measured off the rendered tree with a walk
  that resolves spans the way the engine does, `/` had **five** wrong Arabic runs of seven
  — not three — and `/login` had **nine** of ten, not six. The four `/login` runs it missed
  were `كلمة المرور`, `جديد هنا؟`, `أنشئ حسابًا` and `أو`; the `/` run it missed entirely was
  the greeting's lead-in, which the old walk could not see at all (decision 76).

So the lesson is decision 73's own, one level up: **a measurement written in a doc comment
is a claim, and §9's rule is that a claim is only as good as the test that checks it.** There
was none. There is now — `test/arabic_typography_test.dart`, over all six screens.


### Recorded decisions — bilingual typography (decision 73's follow-up)

**74. THE ARABIC ARM'S FAMILY IS RESOLVED BY **ONE FUNCTION**, AND THE AMBIENT
**`TextDirection`** IS ITS INPUT.** `arabicAware(style, direction)` and
`arabicAwareFamily(direction, latin)` in `core/design_system/tokens/eva_typography.dart`,
applied as `arabicAware(theme.bodyMedium!, Directionality.of(context))` — one expression
per run, and **no constructor anywhere in the app gained an argument.**

**Why this is cheaper than threading a family, which is what Phase 7 refused and why
Phase 7 was right to.** The measurement that settles it is not a line count, it is this:
`TextLink(label: strings.createAccount)`, `SocialAuthButton(label: strings.continueWithGoogle)`,
`HairlineDivider(label: strings.divider)` and `EvaTextField(label: strings.emailLabel)` have
**no arm to pass**. There is no payload behind a chrome label. Decisions 66 and 71 made
`EvaButton.labelFamily` and `IconActionButton.tooltipFamily` **required** precisely because
their callers hold the arm — `TodayReading.language`, `ReadingLanguage` — and the
"requiredness is the whole value" argument only works where the argument is answerable. On a
`TextLink` it is not: the honest required argument is the locale, which is the ambient
direction, which is what `arabicAware` takes. Parameter threading would have added a
required argument to **six** design-system widgets plus a family expression at every feature
run site, in order to reach a value the design system could have read for itself.

Four alternatives, all rejected:

- **A `TextTheme` whose Arabic slots resolve to Amiri.** **Not available, and this is a
  framework fact rather than a preference.** `MaterialApp` takes one `theme:` and one
  `darkTheme:` and has **no per-locale theme hook**, so there is nowhere to put a second
  text theme for the engine to choose between. Every design system that appears to do this
  is switching one at runtime in `MaterialApp.builder`; that is a theme swap, and on this
  app it would swap `TextTheme` for the whole screen rather than resolve a run's family.
- **Reading `Localizations.localeOf` inside a Tier-1 primitive.** Decisions 66 and 71 reject
  this and the rejection stands: an English label and an Arabic one would travel the same
  invisible code path. `arabicAware` takes the direction **as a parameter**, so every call
  site names the ambient source in full — `Directionality.of(context)` — and a reviewer can
  see it. It also adds no second decision: decision 61 established that direction comes from
  the locale through `MaterialApp`, so there is nothing new to keep in step, and `lib/` still
  contains **no `Directionality` this client installs** and **no `startsWith('ar')`**.
- **A shape test on each run's own script.** Decision 29 rejects one for this family of
  widget for a measured reason (it breaks on a verse opening with a numeral or a bracket, and
  §5's live payload opens one behind a `‹Verily`), and it would be a per-run scan on every
  frame of a scrolling list.
- **Parameter threading.** Phase 7's reviewer already called it "a screen rewrite wearing a
  parameter's clothes"; this is that rewrite with a constructor on each end of it.

**And the one thing this rule depends on, stated because it is a dependency.** RTL implies
Arabic **because `app.dart` declares exactly `supportedLocales: [Locale('en'), Locale('ar')]`
** and only `ar` is right-to-left. A third, non-Arabic RTL locale would make it false. The
failure would be **loud**: `arabic_typography_test.dart` asserts every rendered Arabic run is
in Amiri **and** that Amiri carries every character on screen, so a Hebrew run in Amiri fails
the second assertion on the first frame it is painted. A gate that reports the wrong family
is worth more here than a font swap that looks correct.

**75. THE PER-ARM `*FamilyFor` SWITCHES AND THE TWO REQUIRED FAMILY PARAMETERS **STAY**,
AND THE SEAM IS TWO DIFFERENT QUESTIONS, NOT A DUPLICATE SOURCE OF TRUTH.**

| the run | where its arm comes from | the mechanism |
| --- | --- | --- |
| payload content — the preview, the citation, the CTA label, the caption, the marker | `TodayReading.language` / `ReadingLanguage`, **the fact the server sent** | the existing `*FamilyFor` switches and `EvaButton.labelFamily` / `IconActionButton.tooltipFamily` |
| the app's own chrome — every label, link, hint, error, tooltip and status line | the ambient locale, because there is no payload | `arabicAware` |

Zero lines of decision 54, 66 or 71 were changed. The seam looks like the "dual source of
truth for one value" shape that decisions 5 and 68 removed, and it is not: the payload arm
and the ambient arm are different facts, and they survive each other disagreeing — which is
the property that matters if a locale switch and a fetch ever race. Recorded because a reader
who sees two mechanisms for "which family" will otherwise unify them, and unifying them means
deleting one.

**76. THE WALK RESOLVED `TextSpan`s WITH `??` WHERE THE ENGINE USES A **MERGE** — AND THE
MERGE'S BASE/OTHER ORDER IS LOAD-BEARING. THE FIXED WALK REPORTED A **CORRECT** RENDER AS
TOFU, IN BOTH DIRECTIONS.**

The promoted walk is `test/support/arabic_typography_gate.dart`. Promoting it to all six
screens found five bugs in it, and **every one was found because it disagreed with the
engine**:

1. a `Tooltip` paints nothing until a gesture, so the walk is `Future`-returning (decision
   71's fix, kept);
2. a `TextSpan` with **no** style of its own inherits its parent's — decision 71's second
   fix, kept;
3. **a `TextSpan` that styles only *some* fields inherits the rest.** `TextSpan.build`
   **pushes** styles onto a `ui.ParagraphBuilder` and pops them, so a child carrying only a
   colour **keeps its parent's family**. `??` read that child's family as `null` and
   substituted the ambient fallback, reporting **`monospace`** for `_Greeting`'s Arabic
   lead-in `صباح الخير، ` — a run that renders in Cormorant Garamond. **A correct render
   reported as tofu**, which is worse than no gate: it trains its readers to ignore it.
4. and the repair's **base/other order was backwards.** `TextStyle.merge` reads "a copy of
   **this** where the non-null fields in **other** have replaced the corresponding null
   fields in **this**" — so the **parent is the base**. Written the other way, the parent
   wins every field. Bug 3's plant cannot see this (a child carrying only a colour gets the
   parent's family either way); it took a **second** plant — a child naming its *own* family
   under a parent naming a different one — to see it, and that plant reported Cormorant for a
   run that renders in Amiri.
5. the redundant `find.byType(Text)` pass is **deleted**. `Text` always builds a `RichText`
   and `Text.build` puts the **merged** ambient style on a root span with the widget's own
   span as a **child**, so the `RichText` pass already reports every `Text`'s family as the
   engine resolves it — and the second pass reported it differently and worse: measured,
   `monospace` against `DMSans` for the same run on the stub screens.

**And a measurement both this file and the walk it replaces got wrong, in the same place.**
`MaterialApp` installs its own `DefaultTextStyle`, `_errorTextStyle` — `debugLabel`:
*"fallback style; consider putting your text in a Material"*, `fontFamily: 'monospace'` — so
the **outermost** provider's family is **`monospace`**, which `pubspec.yaml` does not
declare, so the engine's default font renders it. That is **not** what a style-less run
renders in: a `Tooltip` with no `textStyle` — decision 71's defect — resolves to **`DMSans`**,
because its content is built inside the `Material` and `Material` installs `bodyMedium`.
**Decision 71's documented mechanism is correct and measured**, and it is re-asserted in
`arabic_typography_gate_test.dart` so the next reader who measures `monospace` does not
"correct" it in the other direction. `materialAppDefaultFamily` names the narrow question it
answers, and it is public because `expectNoTofuInAnyRun` now treats an **undeclared** family
as a **finding** rather than skipping it — which is how the `monospace` misreporting was
found in the first place, since the old walk skipped every undeclared family and so passed
the runs it had got wrong.

**77. A `Failure.message` IS THE **SERVER'S** TEXT, AND **THREE** SITES RENDER IT — TWO OF
WHICH REASONED ABOUT IT IN PROSE.**

`streak_flame_row.dart` carried a ten-line comment arguing that `ApiErrorMapper` and
`TodayReadingMapper` "write **English ASCII literals** naming the key that was wrong — there
is no Arabic in the vocabulary", and used that claim as the load-bearing justification for a
Latin family on a string this client does not control. `api_error_mapper.dart` says
`message: decoded?.message ?? 'HTTP $status'` — so when the server sends a message, which is
**the normal case** and is every one of the eight observed bodies in
`api_error_mapper_test.dart`, `Failure.message` carries **the server's own text**. The
premise was contradicted by the code two files away.

**The claim is deleted rather than repaired, because the reasoning was the defect.** It
reasoned about what the server might send, which is not a fact this client has. The answer is
not a better guess but a face that needs none: measured over the bundled `cmap`s, Amiri
carries U+0600–U+06FF (255 codepoints), U+0750–U+077F, both Arabic Presentation Forms blocks
(611 and 140), **all 95 printable ASCII codepoints and all 96 Latin-1 ones**. So under RTL it
renders the server's message correctly whichever script arrives, and under LTR it is exactly
the Latin face it always was.

**The other two sites, and they did not even have a comment.**
`ErrorView`'s `message` was `titleMedium` — DM Sans, no Arabic at all — on the one screen
where something has already gone wrong. `TodayReadingPanel`'s failed state reaches it with
`state.readingFailure?.message`, so **two** of the three are on `/` and the third is wherever
`ErrorView` is next used. All three now resolve from the ambient arm. `ErrorView`'s
`retryFamily`/`retryLabel` pair is the precedent that makes this cheap, and it is worth
naming that its own doc had already rejected the thing this decision needed: "a second
English string invented in the design system would be a second thing to translate", and
hard-coding a **family** was the same mistake one layer down.

**78. `FontSizeStepper`'s THREE STRINGS ARE THE CALLER'S, VIA `FontSizeStepperLabels` — AND
THE TRACK'S LABEL MUST **DIFFER** FROM THE `Aa` BUTTON'S, WHICH AN EXISTING TEST PROVED.**

They were `'Decrease font size'`, `'Increase font size'` and `'Font size'`, hard-coded in
`core/`, so a reader who opened the `Aa` panel on the Arabic arm was told **in English** what
the two buttons beside them did. `ErrorView.retryLabel` is the precedent: a design-system
widget that renders a caller's script takes the caller's string, because "a hard-coded English
string in `core/` is the half-translated UI this app exists not to ship".

One value class rather than three `String` parameters, because §4's named-parameters rule
makes three parameters on a widget that also takes `step` and `onChanged` five at every call
site, and a caller can put the increase label in the decrease slot with nothing to catch it —
`EvaButtonStyle` and `EvaTextFieldStyle` are the precedent for one value object per widget's
treatments. **No defaults**, so the next design-system widget cannot reintroduce the same
English by omission.

**And the track's label is a DIFFERENT STRING from the `Aa` tooltip's, which
`reading_accessibility_test.dart` caught in the failing direction.** The first version reused
`ReadingStrings.textSize` for both, on the reasoning that "they name the same control from two
positions". They do not: one names the **button you press** and the other the **slider it
reveals**, and one string put **two nodes on the screen with the identical label** — a §14
failure in the one place §14 is unambiguous. `_nodeLabelled` then returned the *button's* node
and `isSlider` was `false`. So `ReadingStrings` gained `fontSize` (`'Font size'` /
`'مقياس حجم الخط'`) beside `textSize` (`'Text size'` / `'حجم الخط'`).

**79. THE GATE IS THE DELIVERABLE, IT IS ON **ALL SIX** SCREENS, AND THREE OF THEM REPORT
THEMSELVES **VACUOUS**. `test/arabic_typography_test.dart` over
`test/support/arabic_typography_gate.dart`; the harness's own anti-vacuity suite is
`test/support/arabic_typography_gate_test.dart`.

**The declared set, not a count.** `expectedArabic` is compared for equality in **both**
directions, because a count cannot catch the failure that matters most: a run silently
vanishing makes "every Arabic run is Amiri" **vacuously true**, and §7's "a gate that cannot
fail is worse than no gate" has never had a quieter costume. A declared list of the runs that
*should* be there cannot be satisfied by their absence, and a new run is red by name.

**Every declared list is built from the string tables and the payload fixtures, not typed.**
The first version was Arabic literals and **four of them were wrong on the first run** — a
missing combining mark is invisible in a diff, and the failure then reads as "the widget
rendered the wrong string" rather than "the test typed the wrong string". A hand-typed
Arabic list in a test is a second copy of the corpus; this one is not.

**Three of the six screens are stubs, and their gates are installed anyway.** `/quiz`,
`/result` and **`/settings`** — the brief named two, §2's route table names three — render
`Placeholder for /quiz` and nothing else, so their Arabic lists are empty and each one passes
a `vacuousBecause` saying why and which phase writes the screen. That is §7's rule applied
literally: "report that honestly rather than calling it a pass". Each is proved capable rather
than assumed capable: a per-screen mutation gives each one its **first** Arabic run in DM Sans
and each fails naming the string. §8's rule — "**A gate whose target directory does not exist
yet**" — is about a missing directory; a screen with no Arabic is the same shape, and the
honest word is *vacuous*, not *pass*.

**Per-screen mutations, run one screen at a time.** Forcing one Arabic run to DM Sans:

| screen | planted at | tests red, attributed to that screen |
| --- | --- | --- |
| `/` | `_StreakSubtitle`'s style | **3** |
| `/login` | `SocialAuthButton`'s label | **2** |
| `/reading` | `FontSizeStepper`'s decrement tooltip | **1** |
| `/quiz` | the stub body's first Arabic run | **1** |
| `/result` | the stub body's first Arabic run | **1** |
| `/settings` | the stub body's first Arabic run | **1** |

Nine attributed failures from six one-line edits. A single screen with a gate is a gate with
one screen in it.

**And the mechanism's own two degenerate states, which are **not** per screen and are
reported as such.** Forcing `arabicAware` to `return style;` and `arabicAwareFamily` to
`return latin;` turns **8** red: three on `/`, two on `/login`, one on `/reading`'s `Aa`
disclosure, and the two `arabicAware` unit tests. **`/reading`'s main arm does not go red,
and that is correct**: its Arabic families come from decision 54's per-arm switches, which
this phase did not touch, because `/reading` was never broken. The three stubs do not go red
either, and that is also correct — a mutation to a helper cannot affect a screen with no call
site for it, which is why their capability is proved by the per-screen plant above rather
than by this one. **The brief's expectation that "every gate goes red" is wrong for `/reading`
and for the stubs, and the reason is structural rather than a gap.**

`/reading`'s nine-site table stays in `reading_glyph_test.dart`, because it is reading-specific:
it names each prototype line, asserts each site by what it *renders*, and walks the verse
markers, which are `TextSpan`s inside a paragraph that `find.byType(Text)` cannot see. What
was promoted is the general half, and `reading_glyph_test.dart` now imports it.

**80. TWO THINGS THIS PHASE FOUND AND **DID NOT** FIX, WITH WHAT THE NEXT PHASE INHERITS.**

**The `/login` validator's two messages are English literals, and the fix is a domain
change.** `kRequiredMessage = 'This field is required'` and
`kShortPasswordMessage = "That password's too short"` live in
`features/auth/domain/login_credentials.dart` — a **pure-Dart** file, which by Gate 1 has no
`Locale` and therefore *cannot* pick an arm. On the Arabic arm of `/login` two English
sentences render in the right family. The fix is a validation-**code** enum on
`LoginValidation` plus a message in `LoginStrings`, which changes `AuthState`'s public shape
and is a domain decision a typography gate does not own. **This phase fixed the family** — the
error text is wrapped in `arabicAware`, so the moment the message is Arabic it renders — and
`arabic_typography_test.dart` **pins the English wording**, so the day someone localises it
that test goes red and points at this decision. A recorded gap that is pinned is a gap that is
tracked; the same wording in a doc comment is the thing decision 73 was about.

**The two recorded limits I was asked to rule on: I AGREE WITH BOTH, and one of them has a
consequence worth writing down.**

*Phase 7's `splitDropCap` repairs the surrogates it **introduces** and cannot repair a string
that arrived malformed.* Correct, and the honest place for the repair is a **mapper** rule,
not a string function. `RenderParagraph` throws `ArgumentError: string is not well-formed
UTF-16`, and nothing between `features/reading/data/` and the engine catches it — so a single
malformed verse takes the whole panel, which is the same "an exception crossing the seam"
hazard §3's LSP row forbids at the repository boundary. "Is this verse usable?" is the same
question as "is this verse empty?", which `today_reading_mapper.dart` **deliberately does not
answer**, and it should be answered **once**, in one place, for both. That is Phase 8's, when
`text_clean` is read. Recorded, not fixed: the alternative is validation in a string helper,
which is a shape test and would make the decision about a *corpus* rather than about a
*function*.

*Phase 7 did **not** strip a leading combining mark before the drop cap, on the grounds that
stripping marks is a shape test and decision 29 rejects one for this widget.* Agree, and the
exposure is smaller than the decision implies: the split is only reached for the **Latin**
arm (decision 29 makes the drop cap Latin-only), so the string at risk is an NKJV verse opening
with a bare `\u0301`, which the corpus does not produce. The refusal also has the right
*shape* of reason — the fix and the decision are the same shape, and a fix that is the same
shape as the thing it would override is not a fix.


### Recorded decisions — Phase 8 review

**81. `/result` TAKES ITS SUBMIT RESPONSE AS A **REQUIRED CONSTRUCTOR PARAMETER**, AND
THE PRICE IS THAT THE ROUTE IS **NOT DEEP-LINKABLE**.

`08-build-phases.md` Phase 8: "`/result` reads the submit response held by `QuizBloc`
and has no repository, no use case, and no API call of its own." The response therefore has to
survive the reader leaving `/quiz`, and there are exactly two places it can live: inside
`features/quiz/`, or passed across the boundary.

**It is passed across.** `features/result/` importing `features/quiz/` is Gate 2, the same wall
`HomeCleared` could not cross in the other direction, and the alternative — reading
`getIt<QuizBloc>()` from a result page — is a **locator dependency on a feature this page must
not know about**, which is the same violation wearing an injection. So `ResultPage`'s
parameter is required, and the constraint becomes compile-enforced rather than documented.

**The cost, stated rather than discovered:** `ResultRoute` takes a `result`, so
`pushPath('/result')` **cannot build the page**. `app_router_test.dart` asserts that failure —
`Expected: true / Actual: false`, with the router left on `/` — instead of working around it,
because a workaround would have meant either an optional parameter (so the screen could render
with nothing in it, which is the defect the requirement exists to prevent) or a second route
for the empty case (a seventh screen, which §2 forbids). The only way in is `QuizPage`'s
terminal `finish` arm, and `quiz_page_test.dart` drives it with a real `QuizBloc`.

The dead end that falls out of this is **real, reachable, and rendered**: a reader whose every
question is already answered reaches the last question with nothing to submit, so there is no
`SubmitResult`, so there is no result screen. See decision 85.

**82. `arabic_digits.dart` MOVES TO `core/domain/entities/`, AND GATE 2 IS THE ONLY
REASON IT MOVES NOW.**

Phase 7 wrote it in `features/reading/domain/` because `/reading` was the only screen with
Arabic-Indic numerals on it. Phase 8 put them in two more places — `/quiz`'s
`questionProgress`, `/result`'s headline and stat values — and the two obvious answers were
both refusals. `features/quiz/` importing `features/reading/` for a **string helper** is Gate 2
again. And *duplicating* the function would leave two implementations that agree today and drift
when the zero-width handling is ever questioned.

So the kernel took it, which is what `core/domain/` is for: §3's rule is that an entity or
helper consumed by two or more features belongs there, and this one is now consumed by three.
`renderable_text.dart` moved for the same reason in the same commit.

The gate is `test/core/domain/entities/arabic_digits_test.dart`, which moved with the file, plus
`test/arabic_typography_test.dart`'s `/result` list — which **declares the three bare numerals
(`٤٠`, `١٠`, `٦`) individually** and so fails if a future `/result` starts printing a Western
`4` where `arabicIndicDigits` used to be.

**83. DECISION 80's FIRST HALF IS DISCHARGED AS A **MAPPER** RULE, AND THE DISTINCTION
IS EMPTY-VERSUS-MALFORMED.**

Decision 80 recorded that Phase 7's `splitDropCap` repairs the surrogates it introduces and
cannot repair a string that arrived malformed, and that `RenderParagraph` throws
`ArgumentError: string is not well-formed UTF-16` with nothing between
`features/reading/data/` and the engine to catch it — so one bad verse takes the whole panel.

The fix is `core/domain/entities/renderable_text.dart`: `isRenderableText` answers "is this
usable in the engine?", and it is **empty, not broken**. An empty string maps, because a missing
verse is a fact the panel already handles; a malformed one does not, because there is nothing
downstream that can. That distinction is the whole content of the helper — a predicate named
`isNonEmpty` would have been the wrong function and would have failed on exactly the case it
was written for.

It is applied in `today_reading_mapper.dart` to **six** painted fields. Four are **refused** —
verse `text`, verse `text_clean`, question `prompt`, and question option text — and each is a
separate case; the last two are Phase 8's, and they are the same hazard on a different screen,
since an option card renders its text through `Text`. The other two, `reference` and
`translation`, are painted too and are **blanked rather than refused**: see decision 95, which
also corrects the one claim in this decision's own first paragraph — the throw is real *and* it is
caught by the painting library, so it costs a tofu box and a per-layout `ArgumentError` rather
than the screen.

**This is a mapper rule and not a widget guard, and that placement is the point.** A widget
guard would leave three callers each holding their own copy of the decision, and the fourth
surface added later would not have it. The gate is `today_reading_mapper_test.dart`'s malformed
cases, one per field.

**84. `StatTile` GAINED `arabicAware` ON BOTH RUNS, AND THIS IS A PHASE-3 WIDGET PHASE 8
HAD TO FIX.**

The bilingual gate reported, in its first run against a built `/result`:

```
`١٠` renders Arabic in `CormorantGaramond`, which carries no Arabic glyph at all
`هذه الإجابة` renders Arabic in `SpaceMono`, which carries no Arabic glyph at all
```

Both are tofu — one box per character — and **neither is a wrong constant**. `StatTile` resolved
`Theme.of(context).textTheme.headlineSmall` and `EvaTypography.monoCaps`, both Latin families,
and neither has an opinion about the ambient arm. The widget had no Arabic arm because the only
screen that used it was the `/result` stub.

`arabicAware` rather than an `if (isArabic)` branch, because both strings are the **app's own
chrome** — a caption from `ResultStrings.ar()` and a number `arabicIndicDigits` produced — and
the ambient direction is the only arm there is. That is precisely the case the helper's doc
names, and it is decision 74's rule applied to a widget that predates it.

**Nothing changes under LTR**, so the Phase-3 goldens are unaffected: `arabicAware` is the
identity there. The gate is `test/arabic_typography_test.dart`'s `/result` list, which is no
longer `vacuousBecause: null` — decision 79's mechanism finally has a screen to bite on.

**85. `QuizCta.none` IS A REAL ARM, AND THE DEAD END IS RENDERED **DISABLED WITH ITS REASON**,
NOT HIDED.**

A reader who has done today's quiz arrives on `/quiz`, finds every question closed, and has
nothing to submit — so there is no `SubmitResult`, so per decision 81 there is no result screen.
The alternatives were: hide the button (a reader cannot tell a missing feature from a missing
control), leave it enabled and let the tap do nothing (§14's forbidden state), or label it with
something that is not true.

It is a **disabled `EvaButton` whose visible label is still the prototype's** and whose
*accessible* name carries the reason as a suffix — the same shape as `LoginPage`'s disabled
field, and decision 18's rule applied twice. The split is deliberate: the label is transcribed
(`QuizScreen.tsx:127`) and the reason is written, and the reader who cannot see the button is the
one who needs the reason.

**What this cost, and it is worth stating because the test found it rather than the code.** The
draft suite drove the transition with a press — press `next` on a one-question payload, expect
`none`. That is unreachable: with one closed question the state is `none` **from the first
frame**, so there is no `next` to press. `QuizCta`'s rows `closed, on the last, not yet
finished → next` and `closed, on the last, and nothing was submitted → none` differ by **nothing
in the payload**; they are separated by whether a question *follows*. So the `next` arm is
reachable only from a multi-question payload, which is what `mixedQuizPassage` exists for. A test
that assumed a press where the state machine has an edge would have asserted a transition the
app does not have.

**86. A CLOSED QUESTION DISABLES **EVERY** CARD, AND THE REASON IS IN EACH ACCESSIBLE NAME.**

Trap 3's client-side half. `already_answered == true` means no option on that question will ever
take a verdict, so `QuizOptionCard.enabled` is false for all four and the bloc's `isAnswerable`
guard is what holds if the event arrives from somewhere else.

§14's disabled row is `Semantics(enabled: false)` **and** the reason in the name, and both halves
are asserted — a `SemanticsFlag` check alone would pass on a control that says "dimmed" and
leaves the reader to guess. The reason is `alreadyAnsweredSuffix`, and it is per-card rather than
per-screen because the screen has one question and a reader navigating by element hears each
option's own state.

**87. ONLY THE SUBMITTED LETTER IS GRADED, BECAUSE `SubmitResult` SAYS **WHETHER** AND NEVER
**WHICH**.**

`_optionStateFor`'s first version read `if (current.isCorrect == true) return correct` before
consulting `letter`, so a right answer painted **all four** cards green and drew four
celebrations. `quiz_page_test.dart` caught it by asserting *exactly one* correct card — a count,
not a membership test. That is the difference between "a correct card exists" and "the correct
card is the only correct card", and the second is the one the wire can support.

This is decision 83's discipline one level further out: the client knows the verdict on exactly
one option and must not extrapolate it. The other three cards are `idle`, not `dimmed`, before a
check — `_isDimmed` is `checked && letter !== selected`, so nothing is dimmed on a question
nobody has attempted.

**88. THE VERDICT ON SCREEN IS THE **SUBMIT RESPONSE**'S, AND NEVER THE PAYLOAD'S
`is_correct`.**

Two different objects, and conflating them is the mistake this decision exists to prevent.
`SubmitResult.isCorrect` arrives over HTTP and describes the answer the reader just submitted.
`Question.isCorrect` is in the payload the reader was handed **before** answering, and is a
spoiler (§5 trap 3).

`quiz_page_test.dart`'s graded-arm group asserts both: that the banner matches
`bloc.state.lastResult?.isCorrect`, **and** that the marked card is the letter the *reader
tapped*. A screen that trusted the payload would mark a card correct before the press, and the
"before the reader commits" groups are what catch that.

The fixture makes the two distinguishable on purpose: `verdictCarryingQuestion` is an **open**
question that nevertheless carries `user_answer: 'A'` and `is_correct: true`, so the payload has
an answer key and `liveEnglishQuestion` — the live capture — does not. Testing the boundary
against the capture would pass on **any** screen, because there is nothing on that fixture to
leak.

**89. `/quiz` HAS NO DATA LAYER, AND THAT IS WHY `ReadingRepository` HAS **THREE** METHODS
RATHER THAN A SECOND PORT.**

The plan's own cut: the quiz reads today's reading, which is the same `GET /readings/today/{lang}`
the home screen already reads, and submits one answer. A `QuizRepository` would be a port whose
only other method is the home screen's method, so it would be two ports over one endpoint and
one place for the `reading_id` to be read differently on each screen — and the submit would have
to echo a `reading_id` the second port also had to fetch.

So `ReadingRepository` gained `submitAnswer`, `DioReadingRepository` gained the POST, and
`SubmitResultMapper` was registered beside the other two mappers. The gate is
`injection_test.dart`'s inventory, which is now **twenty-three** registrations and names each of
the four new ones — and the comment beside the list records that the *order* is the generator's,
not ours, so nobody encodes it.

**90. THE PROTOTYPE'S NOT-PORTED TOGGLE IS DESCRIBED **BY BEHAVIOUR**, AND THE SWEEP IS A
**RAW** `lib/` GREP.**

`01-source-analysis.md` defect #12: `App.tsx`'s screen switcher and `QuizScreen`'s two preview
buttons "must not be ported". The second preview button sets the correct answer to `B` and marks
it correct **without asking the server**, so porting it would put a grade on the quiz that the
backend never produced.

Phase 8's first sweep stripped doc comments before matching, on the reasoning that a provenance
note ought to be allowed to quote what it documents. **That reasoning was wrong**, and the
requirement settled it: the labels must not reach `lib/` **at all**. Two files documented the
toggle and both quoted its labels verbatim — `quiz_page.dart` and `eva_chip.dart` — so the sweep
had to be the sophisticated kind to let them through, and *a sweep that has to be sophisticated
enough to forgive comments will also forgive a comment quoting the very string it exists to keep
out*. Both docs now describe the toggle by behaviour, and `rg 'Frame A|Frame B' lib/` is empty.

The gate is `quiz_page_test.dart`'s source sweep, and it took **three planted mutations** to make
it honest, each recorded at the mutation site because each was a way the gate looked fine:

| planted | first version | now |
| --- | --- | --- |
| `const String _leak = 'Frame A';` | **passed** — equality against the whole line | fails |
| `/// Do not port Frame B.` | **passed** — comment markers stripped first | fails |
| `// … this screen was rebuilt from the prototype …` | **passed** | fails |

The first two are the general shape of a green gate: both were code that looked like a check and
checked nothing, and only a mutation distinguished them from one.

**91. THE HARNESS BUILDS PASSAGES WITH A **FUNCTION**, NOT A FOURTH `const` TRANSCRIPTION.**

`ScriptureText` carries ten fields, eight of them irrelevant to every quiz suite, and three of
those eight are date-stamped (trap 11). Copying the block per fixture is how a fixture and its
passage drift apart silently, because nothing compares them. `englishPassageWith` and
`arabicPassageWith` take the questions and supply everything else from the one transcription, so
the date lives in exactly one place and a fixture can only vary in the one thing it is about.

**92. `/result` HAS **TWO** STAT TILES, NOT THREE, AND THE HEADLINE IS THE SCORE.**

`ResultScreen.tsx:69-73` is a three-tile row, and the plan transcribes three. The first draft
built three, and the third duplicated `currentTotalPoints` — which is already the headline, in
Arabic-Indic digits, one line above. Two tiles is the honest count: *this answer* and *your
longest run*. There is no `/N` anywhere either, because the submit response carries no total
question count (decision 93).

The gate is `result_page_test.dart`, which asserts the two tile labels and asserts the
**absence** of a third tile whose value equals the headline's — a duplication check rather than a
count check, because a count check passes on a screen that duplicated by some other route.

**93. THE STREAK IS `SubmitResult.currentStreak`, PER DECISION 22'S EXTENSION, AND THE
FIXTURE MAKES THE ALTERNATIVES FAIL LOUDLY.**

`/readings/today` says `current_streak: 4` and `streak/summary` says `0` (trap 8), and the only
two numbers available to `/result` are the submit response's and today's reading's. The submit
response's is right: it is the value **at the moment the answer was graded**, and it is the one
that agrees with the points shown beside it. `streak/summary`'s `0` would render a reader's
current run as zero on the screen whose whole job is to report it.

Decision 22's extension test uses a **sentinel** — `current_streak: 77` — and asserts the live
alternatives `4` and `0` are both **absent** from the screen. A test asserting `find.text('77')`
alone would pass on a screen that also printed a `4` somewhere; this one cannot, because the
alternatives are named and refused.

`longest_streak: 6` is deliberately **above** `current_streak`, so `/result`'s "your longest yet"
sentence is its *false* arm — a fixture where the two agree tests the interesting branch nowhere.

**94. REFRESH RE-FETCHES `reading_id` AND `already_answered`, AND **KEEPS** THE READER'S
SELECTION.**

`RefreshSessionQuestions` re-reads `GET /readings/today/{lang}` rather than re-using the session's
cached questions, because a flag that has gone stale is the one thing §5 trap 3 exists to catch,
and a reader who pressed "try again" after a failed submit has told us the flag may be wrong.

The selection survives, which is the half the first version lost: `_onRetried` emitted `loading`
and then read `state` to find out what the reader had chosen — **after** the emit, so it read the
state it had just replaced. The payload is captured before the emit, and
`quiz_bloc_test.dart` asserts the selection is still on screen after a successful refresh.

A failed **read** clears the session to `null` rather than keeping the last good one, for
`ReadingCubit`'s reason: a reader looking at a stale `already_answered` under an error message
would be shown exactly the flags this feature exists to distrust. A failed **submit** leaves the
session alone, because the flags are not in question — the reader's own selection is.

**95. THE MALFORMED-STRING THROW IS **REAL**, IT IS **CAUGHT**, AND DECISION 83's GATE
EXTENDS TO THE TWO LABELS — BLANKED, NOT REFUSED.**

Three halves, and the first is a retraction of this phase's own work.

**The retraction.** A draft of `renderable_text.dart`, `utf16.dart`,
`today_reading_mapper.dart` and `today_reading_mapper_test.dart` stated that
`RenderParagraph` **does not** throw on a lone surrogate on `Flutter 3.47.4`, and built a cost
argument on it. That was false, and it contradicted decision 83 and three earlier statements in
this file (`:1757`, `:2156`, `:2226`). The probe that "refuted" the throw printed its own
`no throw` label beside `tester.takeException()`'s value and the conclusion read the label.
Measured, per `Text` / `SelectableText` / `Text.rich`:

```text
takeException == null   : false
takeException runtime   : ArgumentError
takeException toString  : Invalid argument(s): string is not well-formed UTF-16
#0  _NativeParagraphBuilder.addText  (dart:ui/text.dart:3724)
#1  TextSpan.build                    (painting/text_span.dart:298)
#3  TextPainter.layout                (painting/text_painter.dart:1264)
#4  RenderParagraph._layoutTextWithConstraints
#5  RenderParagraph.performLayout     (rendering/paragraph.dart:966)
```

**And it is caught**, which is why the draft's probe misled it: the painting library catches a
layout exception, records it and completes the frame, so *"a frame appeared"* is not *"nothing
threw"*. An exception left untaken also **fails the test** — `AutomatedTestWidgetsFlutterBinding`
rethrows at teardown — so `takeException() == null` is the only negative test available. The cost
of a malformed painted string is therefore **two** things: a tofu box, **and** a caught
`ArgumentError` on every layout of that paragraph. Not an outage — decision 83's *"takes the whole
panel"* overstates it — but not the silent nothing the draft claimed either.

**The extension.** The gate reaches **six** painted fields, not four, and the two labels get a
**different verdict**. Decision 83's reasoning for a mapper rule is unchanged; only the field list
grew. `reference` and `translation` are painted (`reading_header.dart` puts one in the title and
one in the metadata row), so:

| field | role | malformed, **blanked** (kept) | malformed, **refused** (rejected) |
| --- | --- | --- | --- |
| `text`, `text_clean`, `prompt`, `options` | content | not applicable — refused | the verse or question is skipped; the screen works |
| `reference`, `translation` | labels over the content | a blank citation/edition row | **the whole reading fails to map** |

The real trade, both directions. What the reader loses when a label is malformed and we blank it:
the citation, or the edition name — **the same thing they already see** when the server sends
`''`, which this mapper has always passed through on purpose. What they lose instead of that: a
tofu box plus a caught `ArgumentError` on every layout of the heading. What they lose if the gate
**refuses** a malformed label: the entire reading, on both screens, with both controls dead. One
bad label must not cost the passage; that is decision 40's `text: ''` argument exactly.

So: `renderableTextOrNull` for content, `renderableTextOrEmpty` for labels, and the empty label is
**proved renderable** rather than assumed — `reading_page_test.dart`'s *"a BLANK LABEL RENDERS"*
pair mounts `/reading` with `reference: ''` and `translation: ''` on both arms and asserts
`takeException()` is `null` with the header and the passage still on screen. Before that test,
"the server can send `''`" was a claim about a payload, not a measurement of a screen.

**The test that pinned the wrong behaviour was inverted, and that is the record.**
`today_reading_mapper_test.dart` asserted *"a malformed `$field` is PASSED THROUGH, and the passage
survives"*. It rested on the false cost argument, so it pinned the defect: a test whose reason
turns out to be false blocks the repair. Both halves moved — the label is blanked, the passage is
still whole, and the *other* label is asserted untouched so a blunt "blank both" fails.

**The lesson, recorded because it is the third instance in two phases:** a probe whose output can
carry a verdict must print the verdict **as the asserted value**, never as a label beside a value
that has to be read separately. Phase 7's `find.textContaining` miss, Phase 8's `excludeSemantics`
miss, and this.



### Recorded decisions — the `freezed` migration (decision 8a)

Shipped on `refactor/freezed-states`. **34 types** converted: 17 classes with
fields of their own, 14 bloc events, and 3 sealed event bases. `pubspec.yaml`
gained `freezed_annotation` ^3.1.0 and `freezed` ^4.0.1 (dev); `build.yaml`
gained the `freezed:freezed` builder key scoped to `lib/**`, because the same
"unknown builder key is silently ignored" rule that bit `injectable_generator`
applies here. `equatable` **stayed** at this point — see decisions 99 and 131.

**96. THE DATA-CLASS FORM IS `final class X with _$X` WITH A DIRECT
CONSTRUCTOR, NOT THE `factory` FORM.** freezed supports
`const factory X({required T a}) = _X;`, and it is the shape most of its
documentation uses. It is **wrong for this repository**: the factory form
requires every field to be declared as an abstract getter (`String get a;`),
because the generated impl `implements X` rather than extending it — declaring
`final String a;` beside it is a `final_not_initialized` compile error, measured.
The direct-constructor form keeps the field declarations **in the annotated
file**, which is what keeps `secret_masking_test.dart`'s structural scan
working unchanged. *Rejected:* "use the documented form" — it costs the structural
secret gate its subject list, because the generated part would own the fields and
the scan would then be reading generated code.

**97. `@Freezed(copyWith: false)` ON `AuthState`, `HomeState` AND `QuizState` —
AND `@Freezed(...)` REPLACES `@freezed` RATHER THAN ACCOMPANYING IT.** Three
states document that every writer builds the **whole** state, because a
`String? = null` parameter cannot express "clear it". freezed's generated
`copyWith` is exactly the sentinel-based partial writer those docs name as
rejected, and it is *wider*: it takes all ten fields and its sentinel defaults
make `copyWith(emailError: null)` **clear** the error. `AuthState` keeps its
hand-written six-field `copyWith` — the exclusion is the value, and the twelve
lines it costs are cheaper than a convention every future caller has to
remember. *Rejected:* adopting it everywhere (the six fields are not the point —
the exclusion is). *Rejected:* hand-writing the base's `==` too (nothing needs
it; `==` is where freezed is strongest).
**The annotation-ordering trap, measured:** `@freezed` is `const freezed =
Freezed()`, so writing **both** makes `firstAnnotationOf` read whichever comes
first — and with `@freezed` on top, `copyWith: false` is silently ignored and a
generated `copyWith` collides with the hand-written method
(`conflicting_method_and_field`). `@Freezed(copyWith: false)` alone is the
documented and only working spelling.

**98. `Failure` AND `Result<T>` STAY HAND-WRITTEN, AND `equatable` STAYS IN
`pubspec.yaml`.** *(Superseded on the dependency half by decision 131: the two
types stayed hand-written exactly as decided here, and the hand-written `==`
they were waiting for is now written, so the dependency is gone. The reasoning
below stands.)* §2.1 hazard 2 explains `Failure`: `details` is excluded from
equality because `equatable` falls through to plain `==` for an untyped field,
and freezed offers **no** per-field exclusion, so a generated `==` would put a
decoded server body into the equality contract on purpose.
`test/core/common/failure_equality_test.dart` pins that and is unchanged.
`Result<T>` is sealed by hand with hand-written arms (§2.1 decision 7), so its
`Success<T>`/`FailureResult<T>` keep `props` too. **Consequence, stated rather
than buried: `equatable`'s last use is not gone, so §2.1 decision 8a's "removed
in the same task" is deferred to whichever task removes the last `Equatable`.**
**CORRECTED BY MEASUREMENT, decision 131:** this decision's closing claim that
"two hand-written `==`s in `lib/` depend on it" was **wrong**. `SignInParams`
(`features/auth/domain/usecases/sign_in.dart`) hand-writes its `==` and never
imported `equatable` — it predates the dependency's last use, and its comment
about "not Equatable's default" refers to a choice it declined rather than one
it made. Only `Failure` and `Result<T>` were ever users.

**99. TWO NEW GATES, AND ONE EXISTING GATE FIXED.**
`test/core/common/freezed_structural_equality_test.dart` (21 tests) asserts
two equal-but-distinct instances compare equal **and that changing every single
declared field makes them unequal**, with the field count asserted against the
list length — the first version sampled two of `SubmitResult`'s seven fields and
a deleted `readingCompleted` sailed through it.
`test/core/common/no_identical_on_converted_types_test.dart` (9 tests) audits
every `identical(` / `same(` site in `test/` against a 57-row table and fails on
an unreviewed site, a stale row, a changed count, a drifted `converted:` flag or
an unreasoned row. **And `secret_masking_test.dart` had a blind spot**: its own
per-line comment stripper treated a `/*` **inside a doc comment** as a block
comment start, so `home_bloc.dart`, `streak_summary.dart` and
`submit_result.dart` were scanned only up to their first glob-shaped path
(`readings/today/*`) — **five converted types invisible to the gate**. It now uses
the shared `withoutDartComments` and carries a planted negative control.

**100. THE GENERATED PARTS STAY PURE DART, AND GATE 1 IS WHAT PROVES IT.**
Ten `.freezed.dart` files land inside `lib/core/domain/` and
`lib/features/*/domain/`, the directories Gate 1 holds to pure Dart. A part file
has no imports of its own, so its surface is the host library's — and the hosts
import exactly one package, `freezed_annotation`, whose own dependencies are
`collection`, `json_annotation` and `meta`, none of which reaches Flutter.
Verified by scan and by negative control (an `import 'package:flutter/material.dart'`
planted in a `core/domain` part makes Gate 1 exit 1).


### Recorded decisions — ARB + `gen_l10n` (decision 8b)

Shipped on `refactor/gen-l10n`. Five `*Strings` tables deleted; `lib/l10n/app_en.arb`
+ `app_ar.arb` (72 keys) and the three generated `app_localizations*.dart` files
replace them. No new dependency — `flutter_localizations` and `intl` were already
present — and `pubspec.yaml` changed by exactly one line, `generate: true`.

**101. ONE ARB, AND EVERY KEY IS PREFIXED BY ITS FEATURE.** Not only the three
colliding names; **all 72**. Rejected: prefixing only `retry` / `unavailableSuffix` /
`wordmark`, which is the cheaper rename and leaves 66 keys that look unowned beside 6
that do not. The next collision would then be resolved by whoever hits it, under time,
with no rule in the file to follow. Uniform prefixing makes the ARB self-documenting
(`homeRetry` is home's, `homeStreakLabel` is home's) and makes §3's feature ownership
visible in the one file a translator reads. Collisions resolved as §2.1 asked:
`homeRetry`/`quizRetry`/`readingRetry`,
`authUnavailableSuffix`/`homeUnavailableSuffix`/`quizUnavailableSuffix`/`readingUnavailableSuffix`,
`authWordmark`/`homeWordmark`.

**102. THE NON-STRING LOGIC WENT WHERE ITS ONLY CALLERS ARE.** Each table held three
kinds of thing and only the first was a string. Derived strings — `greetingWord`,
`greetingLead`, `questionProgress`, `optionLabel`, `messageFor`, `streakLabelFor` —
are composition, not translation, and each lives in
`features/<f>/presentation/<f>_l10n.dart` as an extension on `AppLocalizations`.
Rejected: one `lib/l10n/derived.dart`. `greetingWord` needs `GreetingPeriod`, which §3
puts in `features/home/domain/`, so a shared file would make the shared kernel
feature-dependent. Gate 2 would **not** have caught it (`tool/feature_import_check.dart`
skips a path whose owner is neither `features/*` nor `core`) — it is §3 that forbids
it, and that is worth knowing about the gate. What is in `lib/l10n/` itself
(`l10n.dart`) is only `BuildContext.l10n`, `isArabicArm` and `digits`, and it imports
nothing from a feature.

**103. THE PLURAL TAKES TWO PLACEHOLDERS, AND THAT IS MEASURED, NOT AESTHETIC.**
`readingCaptionFor` declares `count` (int, the ICU selector) **and** `digits` (String,
the rendered numeral). Reason: `gen_l10n` compiles `{count, plural, …}` by
interpolating the raw Dart `int` — the generated Arabic arm literally reads
`'$count أسئلة'` — so a single-placeholder ARB renders **Latin digits on the Arabic
arm**, silently undoing `arabicIndicDigits` (pinned by `arabic_digits_test.dart` and
`font_coverage_test.dart`) and leaving every Arabic screen showing `5 questions` beside
`٥`. The division is the honest one: agreement is a property of the WORDING and belongs
in the ARB; the numeral system is a property of the ARM and belongs in `l10n.dart`.
Rejected: `NumberFormat` from `intl` — the obvious spelling, and it would have made a
translatable key carry a locale's digits with no single function the tests could pin.

**104. THE PLURAL AUDIT — TWO COUNTS BECAME PLURALS, AND EVERY OTHER ONE WAS CHECKED
AND NAMED.** Genuinely plural-dependent: the **question count**
(`readingCaptionFor`) and the **score caption** (`resultTotalCaption`). Genuinely not,
with the reason each: **streak days** (`resultDay`, and `homeStreakLabel`) — a *label
form*, `Day 12` / `اليوم ١٢`, correct for every count in both arms; a plural would
render `Days 12` in English, altering a transcribed prototype string
(`ResultScreen.tsx:65`) to fix nothing. **verse counts** (`readingVerse`) — the marker
names an index, it does not count a set; a plural there would select an `other` branch
identical to its `one` branch, a test that cannot fail. **quiz progress**
(`questionProgress`) — no noun agrees with either number; `of` / `من` is invariant.
**`days_to_milestone`** — **not rendered anywhere**; `StreakSummary` carries it and no
widget draws it, so there is no string to convert and the scope ends at the UI.
Also recorded and NOT fixed, being out of scope: `progress_beads.dart:146` composes
`': N of M complete'` in English inside `core/`, so that semantics label reaches a
screen reader in English on the Arabic arm.

**105. `isArabic` IS NOW THE LOCALE.** `AppLocalizationsArm.isArabicArm` reads
`localeName`. The old derivation — compare one of the table's own strings against the
Arabic arm's — was sound and has **no honest form left**: `AppLocalizationsAr` is
generated, so the comparison would be a generated getter against a second generated
instance, i.e. a test of the generator; and it breaks the moment a translator picks an
Arabic value that coincides with the English one. Proven by mutation: pasting `'Streak'`
into `app_ar.arb`'s `homeStreakLabel` fails 3 tests including `isArabicArm`'s. Rejected:
`arabicAware` — that is the rule for **families**, it reads ambient direction, and
`eva_typography.dart` §4 is explicit that the per-arm `*FamilyFor` switches stay beside
it. This is a numeral/arm rule keyed on the locale, deliberately.

**106. THE LOCALE RE-DISPATCH **STAYS**, AND §2.1's CLAIM THAT IT DIES WAS WRONG.**
§2.1 said the `didChangeDependencies` re-dispatch in `HomePage` and `QuizPage` exists
"because the tables resolve through `static X of(Locale)` and bypass `Localizations`".
Measurement says otherwise: that branch is `if (_requested != _language) _load()`,
where `_language` is `ReadingLanguage.forLocale(Localizations.localeOf(context))`. It
is a **corpus re-fetch** trigger — a locale change must re-ask the API for the other
arm's scripture and questions. It never re-resolved strings; `build` did that, on every
rebuild. Removing it is a regression, and a measured one: emptying the branch fails
**56** tests, including three of the six-screen Arabic gate's `/` runs. What died is the
**resolution pattern** — `X.of(Localizations.localeOf(context))` in five `build`
methods, now `context.l10n` — and `didPopNext`, the Phase 6 re-entry trigger, is
untouched and still load-bearing: emptying it fails 1 test,
`home_navigation_test.dart`'s "a push/pop re-asks, and the screen shows the NEW answer",
with its control "a REBUILD still asks for nothing" still green beside it.

**107. THE GENERATED `*.dart` FILES ARE COMMITTED, FORMATTED, AND `build_runner` DOES
NOT PRODUCE THEM.** `gen_l10n`'s raw output is **not** `dart format`-clean (3 of 3
files change), so the committed copies are the formatted ones or the §7 formatting gate
is red on a fresh clone. Two corrections to the task's verify list: `dart run
build_runner build` does **not** run `gen_l10n` (removing a generated file and running
it leaves the file absent), and neither does `flutter test` — only `flutter gen-l10n`,
`flutter pub get` and `flutter build` do. That is the same reason Gate 3 tracks
`*.gr.dart` and `*.config.dart`: "so `dart analyze` is meaningful on a fresh clone".

**108. A MISSING KEY IS A **WARNING**, NOT A BUILD ERROR — SO A TEST IS THE GATE.**
§2.1 claimed "a typo becomes a build error; today it is a missing sentence on a
shipped screen." Measured: deleting a key from `app_ar.arb` makes `flutter gen-l10n`
print a long hint and **exit 0**, emitting the **template's English value** into the
Arabic class. `dart analyze --fatal-infos --fatal-warnings` reports nothing. What
catches it is `test/l10n/app_localizations_test.dart`'s "both arms carry exactly the
same keys" — **2 failures**. The compile-time claim is half true: it moves the failure
from a shipped screen to codegen's stderr, and a test is what makes it red.

**109. `resultTotalCaption` IS A PLURAL WITH NO `{digits}`.** Selection only, because
`result_page.dart` draws the score in `displayLarge` one line above and folding the
numeral in would print it twice. What must agree with the number is the **noun** — and
the old value was `نقطة`, singular, for every score, so `٥ نقطة` rendered where Arabic
wants `٥ نقاط`. A real correctness bug, fixed by the same mechanism as 103. English
output is unchanged: every score in this app's fixtures is greater than one, so `other`
('points') was already what rendered and `one`('point') was the branch that was missing.

**110. EVERY KEY MUST CARRY ITS REASONING, AND THE CITATIONS WITH IT.** The five tables
carried, per string, the prototype's `file:line` where one existed, the reason it was
written where none did, and the alternatives rejected. `gen_l10n` discards
`@key` descriptions after using them for tooling, so the descriptions are not
documentation — they are the record, and ARB is the only place it can live. Two gates
hold it: every key needs a description over 40 characters, and 17 keys are pinned to the
exact `file:line` they must still name. Proven by mutation: removing `HomeScreen.tsx:30`
from one description fails 1 test by name.

**111. §2.1's COUNTS WERE WRONG, AND THE CORRECTION IS RECORDED RATHER THAN QUIETLY
REUSED.** There were **five** tables, not six — `LoginStrings`, `HomeStrings`,
`QuizStrings`, `ReadingStrings`, `ResultStrings`; the sixth feature, `/settings`, has
never had a table. They carried **73** string fields, of which **67** were distinct
bare names before namespacing (the three collisions account for the other 6), and they
are **72** ARB keys after `questionSingular`/`questionPlural` merge into one plural and
`resultTotalCaption` becomes one. §2.1's "69 distinct string fields across the six
tables" matches none of those three numbers.


### Recorded decisions — Phase 10 review

Shipped on `feat/phase-10-polish`. **2215 → 2311 tests, coverage 98.17% → 98.21%.**
The phase's own framing was measured before anything was built and **three of the four
scope bullets were already satisfied**; the work that was actually missing is below,
together with the two recorded decisions that are not "what I built".

**123. THE FOUR PLAN BULLETS, MEASURED — THREE WERE ALREADY DONE**

| `08-build-phases.md` Phase 10 scope line | measured state on entry |
| --- | --- |
| `TextScaler` from the font step | **done in Phase 9.** `app.dart:320-327` installs `evaScalerFor(settings.fontStep)` at `MaterialApp.builder`; `app_settings_wiring_test.dart:322-384` holds it (five steps → five rendered sizes, no dead zone). Verified, not rebuilt. |
| reduced-motion honours `MediaQuery.disableAnimationsOf` | **6 of 7 animation sites honoured it. One did not** — decision 124. |
| `EmptyState`/`ErrorView` wired into every async page | **`/`, `/reading`, `/quiz` wired. `/login` and `/result` have no failure state to wire (measured, below). `/settings` HAD one and drew nothing** — decision 125. |
| semantics pass over all 6 pages | **3 of 6.** `login`, `/`, `/reading` had `*_accessibility_test.dart`. `/quiz`, `/result`, `/settings` had none — three new suites, and four §14 defects they found (decisions 126–129). |

Two exclusions are measurements, not omissions, and are recorded so a later reader does
not "fix" them:

* **`/login` has no failure status.** `AuthSessionStatus` is
  `unknown | signedOut | signingIn | signedIn` and `AuthBloc` maps a failed session
  check to `signedOut` on purpose (`auth_bloc.dart:492-508`). Auth is a header, not an
  endpoint (§2 decision 3), so there is no server failure for `ErrorView` to render.
  Field-level `errorText` is the whole of `/login`'s error vocabulary and it is drawn.
* **`/result` cannot be empty and cannot fail.** `SubmitResult` is a **required**
  constructor parameter, so the screen does not exist without a result — compile-enforced,
  which `result_page.dart:26-31` states. There is no empty state to design and no second
  shape for the page to have.
* **`EmptyState` is N/A on `/` and `/reading`.** `HomeSectionStatus` and `ReadingStatus`
  have no `empty` arm. `EmptyState` ships and is wired on `/quiz`, whose
  `questions: []` really is reachable (recorded decision 70).

**THE VERIFY LINE WAS THE REAL GAP.** *"the app renders correctly at 320×568, 390×844,
and 430×932."* A grep found **one** viewport mention in the whole suite before Phase 10 —
`Size(430, 2400)` in `reading_geometry_test.dart` — and all three numbers **already
existed** as house constants (`kNarrowSurface`, `kAmbientSurface`, `kGeometrySurface`).
The gap was never a missing constant; it was three separate answers to three separate
questions and no matrix. `/result` had never been rendered at 320, and `/settings` had
never been rendered at 320 at any text scale. `test/viewport_matrix_test.dart` is 48
render tests (6 screens × their states × 3 viewports) plus a three-test negative control
on the detector. It also found that `/settings` had **no** `*_text_scale_test.dart` at
all, so §14's "1.22× at 320px" was unverified for the one screen a reader opens to change
their text size — closed by `settings_text_scale_test.dart`.

**124. THE GLOBAL ROUTE TRANSITION DID NOT HONOUR REDUCED MOTION**

Seven animation sites; six already read the flag. The seventh is
`EvaMotion.fadeSlide` (`eva_motion.dart:144`), installed **app-wide** by
`AppRouter.defaultRouteType`, so every one of the six screens arrived with a 250ms fade
and an 8px slide whether or not the reader had asked for reduced motion. §14's row is
"every animation checks `MediaQuery.disableAnimationsOf(context)`; when disabled, jump
straight to the end state", and this file's doc read *"nothing here reads from it"* — the
violation written down as though it were a design note.

*Measured reachability, not assumed.* A route transition is built inside the route's
`ModalScope`, a descendant of the `Overlay`, of the `Navigator`, and therefore of what
`MaterialApp.builder` returned — so the flag **is** readable, which the old doc never
checked. Contrast `neural_motion.dart:259-268`, whose scope sits **above** `MaterialApp`
and genuinely has no `MediaQuery`: that one verified its reason first and corrected its
own earlier comment when it found the reason was wrong.

*Rejected: `return child` when animations are off.* One line shorter and it satisfies
§14's end state, but a transitions builder's job is to *wrap* the page, and it changes
the route's subtree for a reader who did not ask for reduced motion at all — they asked
for less of it. `kAlwaysCompleteAnimation` is substituted for `animation` instead, so
`FadeTransition` / `SlideTransition` / `FractionalTranslation` are all still built and
the existing shape assertions still hold.

*`AppRouter.defaultRouteType` is unchanged*, so `app_router_test.dart:294`'s
`same(EvaMotion.fadeSlide)` still passes; the signature is the framework's and the tear-off
is the same object.

**125. `/settings` HAD A FAILURE STATE AND NO SURFACE FOR IT**

`SettingsStatus.failed` is reachable on **both** a read and a write, `SettingsState.failure`
is non-null, and `_SettingsFailureNotice` is what the screen now draws above its three
groups. `settings_state.dart:50-52` had already **named the cost** — "a reader whose store
is unreachable sees the app in its default palette and is never told" — and cross-referenced
"see its page for why". `settings_page.dart` contained no such reason: a dangling
cross-reference, which is worse than an admitted gap because it reads as settled.

**The write arm is the one that matters, and it is why this is a notice and not an
`ErrorView`.** A failed read happens once at launch while the reader is on `/`. A failed
write happens *because of something the reader just did*: they tap the theme switch,
`_persist` answers a `FailureResult`, `settings_cubit.dart:188-194` emits
`status: failed, settings: _confirmed`, and the control visibly springs back with nothing
said — the exact failure `login_page.dart`'s doc records for its four inert social
buttons. Replacing the form with an `ErrorView` would erase the control the reader just
used at the moment it springs back, so the screen would stop making sense without saying
why.

Three further reasons, all recorded in `_SettingsFailureNotice`'s doc:

* `ErrorView` **fills** its box (`Center` → `SingleChildScrollView`) and `/settings`' root
  already scrolls (`SettingsScreen.tsx:36`'s `overflowY: 'auto'`), so dropping it above
  three groups either nests two scroll views or eats the form.
* `ErrorView.message` is required and its contract is `ApiErrorMapper`'s — true of `/`,
  `/reading` and `/quiz`. `/settings` is the first **non-network** failure surface, and
  `SettingsRepositoryImpl._unreachable` builds
  `'The preferences could not be reached: $error'`, interpolating the raw Dart exception.
  A real one on a real device is
  `MissingPluginException(No implementation found for method … on channel …)`. So the
  notice renders **`settingsPreferencesUnavailable`**, the app's own localised sentence,
  and deliberately not `failure.message`. `error_view.dart`'s claim that "the failure
  messages this app shows come from `ApiErrorMapper`" is now true of three of four call
  sites and its doc says so.
* The retry runs `SettingsCubit.load()` — the one operation that clears the status without
  asking the reader to change something else first. `_persist`'s success path also clears
  it, but reaching that means asking someone whose settings just failed to save to change a
  setting.

**Rejected: a new design-system widget.** AGENT_CONTEXT §8.7 — a new file only where the
task specifies a path. The notice is assembled in the page from tokens that already exist:
`GlassTier.tint` (§13.4 puts `/settings` in tint, so no `saveLayer` and
`glass_blur_budget_test.dart`'s `lib/features/` ceiling of 1 is untouched), `EvaButton`,
`ErrorView.iconSize`, and `context.colors.err`.

**126. `/quiz` PUBLISHED TWO TAPPABLE NODES PER OPTION CARD, ONE OF THEM UNNAMED**

`QuizOptionCard` nested `Semantics(…, excludeSemantics: true)` *inside* `EvaFocusRing` →
`EvaInk`. `excludeSemantics` drops a node's **descendants**, never its ancestors, and
`Semantics(button: true)` forms a boundary so the `InkWell` could not merge the labelled
node up into itself either. Measured on the pumped tree:

```
lbl="A. Nicodemus"  acts=[tap]         <- the Semantics
lbl=""              acts=[tap, focus]   <- the InkWell, and it has no name
```

Four such nodes per screen — §14's first row verbatim, met *before* the one that was
named. The `Semantics` is now the outermost widget; `EvaInk`'s focus node is untouched,
because focus and semantics are separate mechanisms and `focus_ring_gate_test.dart` still
sees its Tab stop. `quiz_option_card_test.dart`'s comment had already recorded that
"`EvaFocusRing` and `EvaInk` add nodes of their own" without following it anywhere; a sweep
over `/quiz`'s whole tree is what followed it.

**127. `/quiz`'s CORRECT/INCORRECT VERDICT PAIRED A COLOUR AND A LABEL BUT NOT AN ICON**

§14's last row: *"Colour-only state (quiz correct/incorrect) — pair the colour with an
icon and a semantics label."* The **label** half shipped in Phase 7
(`quizCorrectSuffix` / `quizIncorrectSuffix`) and `quiz_option_card_test.dart` holds it.
The **icon** half did not exist: the card drew the accent border, the accent fill and the
accent glow and nothing with a shape, so a reader who cannot separate `ok` from `err` was
told nothing. `QuizOptionCard.verdictGlyphFor` is an exhaustive `switch` over
`QuizOptionState` — so a fifth state is a compile error there rather than a missing glyph
at runtime — and the glyph is derived from `state` alone, which is what makes it
spoiler-safe: `quiz_page_test.dart`'s "the widget tree carries nothing that says which
option is right" asserts every card is `idle` from that one field, so a leak would have to
change `state` first and would be caught there before it reached an icon.

`Icons.cancel_outlined`, not `Icons.close`: a bare `×` reads as "dismiss this card", and
this card dismisses nothing.

**128. `/quiz`'s VERDICT BANNER WAS NOT A LIVE REGION**

`FeedbackBanner` ended at `if (semanticLabel == null) return banner;` — and
`semanticLabel` is `null` in **every** call site, so the flag below it existed in a widget
that never rendered. `/quiz` is the one screen whose verdict arrives **after** the reader
has pressed something: the screen is settled, focus is on the CTA, and nothing announced
that the answer had been graded. `ErrorView`'s own comment is the reason and the
precedent — *"A failure that arrives after the screen has settled has to be announced."* A
wrong answer arriving silently is the same defect as a failure arriving silently. The
`Semantics` is now unconditional and is a **container**, so what is announced is the
banner's subtree.

**129. TWO PLACES NAMED THE SAME ACTIVATABLE NODE — BOTH ON `/settings`**

Both are §14's failure in the one form this repository has already had once: one string
describing two focusable, activatable nodes. `reading_accessibility_test.dart` caught that
once, when `readingTextSize` named both the `Aa` disclosure and the slider it reveals, and
`app_localizations_test.dart` then forced two keys apart.

* **`SettingsTile` announced its own title twice.** The row's `Semantics` keeps
  `excludeSemantics: false` on purpose — the comment there is right, a tappable row
  *contains* a control — and the title `Text` then contributed `title` a second time.
  Measured: `lbl="Default language|Default language|English"`, where the language row was
  the **only** node carrying the reader's current language. Fixed by excluding **only** the
  title `Text`, so `trailing`'s node survives. Now `lbl="Default language|English"`.
* **`SegmentedControl`'s track was named after the SELECTED VALUE**, so on `/settings`
  there were two activatable nodes labelled `Dark` — the track and the selected segment.
  The track's node **cannot** be dropped: `EvaFocusRing` inserts no `Focus` and
  `EvaInk` is the only thing binding its `FocusNode` into the focus tree, so a track with
  no `onPressed` is a control Tab cannot reach. **Rejected: dropping the tap**, for that
  measured reason. So the fix is a **distinct string**: `SegmentedControl.semanticLabel`,
  a caller-supplied name for the track, which `/settings` fills with the row title it
  already draws. The track is now "Theme" and the segments "Light" / "Dark" / "System";
  the row's painted title repeats "Theme" once, and that node is **not** activatable,
  which is the distinction `home_accessibility_test.dart`'s "the streak is ONE node, not
  two" turns on.

  `semanticLabel` is **optional** rather than required, unlike `EvaButton.labelFamily`
  (decision 66) and `FontSizeStepperLabels`. Requiring it would make every caller name the
  control *and* its options when `labelOf` already covers the options. A caller with a noun
  gets the correct shape; a caller without one still gets a **named** track — a duplicate,
  which is what shipped for nine phases, rather than an unnamed control.

**130. `lib/l10n/` WAS NOT COVERED BY GATE 2, AND PHASE 9 KNEW IT**

`feature_import_check.dart`'s `_ownerOf` returned `null` for every path whose second
segment was neither `features` nor `core`, and a `null` owner means `main` `continue`s —
so **any** file under `lib/l10n/` could import **any** feature and the check exited `0`.
Negative-controlled on the tool itself, before the fix:

```text
# a probe at lib/l10n/_phase10_probe.dart importing features/quiz and features/reading
$ dart run tool/feature_import_check.dart      # exit 0   <- the hole
# the IDENTICAL probe at lib/core/_probe/_probe.dart
$ dart run tool/feature_import_check.dart      # exit 1, both lines reported
```

After: exit `1`, both lines, and `export` at three segments is caught too.

**Phase 9 had recorded the gap and worked around it rather than closing it** —
`settings_l10n.dart` cites "a structural blind spot in the purity gate rather than a
checked one" as the reason its derivation lives in the feature. That was the right call
for a phase that was not the one to close it, and it is the reason the gap survived nine
phases. That paragraph is now rewritten: the placement is unchanged and the reason it was
ever reconsiderable has gone, which is a materially different statement.

Gate 2's `ok` line now **names the owners it examined**, because a directory nobody claimed
produces no output at all and is therefore indistinguishable from a clean tree until
someone notices the missing name. It is deliberately **not** an exit-code failure — §7
draws the line there, and `lib/app/` is excluded on purpose because reaching into features
from the composition root is its job.

#### Two test bugs this phase found in itself, recorded because both were instructive

* `find.bySemanticsLabel` returns **widgets**, and one `SemanticsNode` can be contributed
  to by several. `findsOneWidget` on it answers "how many widgets carry this label".
  `settingsTitle` matched two widgets for one node. Counting `SemanticsData` from
  `semanticsTree` is the instrument; every new sweep here counts nodes.
* `/settings`' language row reports the **ambient** arm (`selectedLanguageOf(context)`),
  not the stored setting — so a test that stored `language: arabic`, pumped `locale: en`
  and asserted the row said "Arabic" was asking the wrong question, and the row was right.
  An app rendering in English has English in force.

## 7. Verification — run before reporting done

```bash
dart format --output=none --set-exit-if-changed lib test tool  # formatting
dart analyze --fatal-infos --fatal-warnings                # types + lint + DEPRECATION
flutter test                                               # full suite
tool/verify_purity.sh                                      # architecture gates
dart fix --dry-run                                         # Nothing to fix!
flutter test --coverage                                    # must not drop
flutter build linux --release                             # the app still builds
```

**Two gates Phase 10 added that are really two *instruments*, not two commands.**
`test/support/design_system_harness.dart`'s `expectNoOverflow(tester, …)` and
`drainOverflowErrors(tester)` are how a render test claims "nothing overflowed", and
`viewport_matrix_test.dart`'s negative-control group is what makes that claim mean
something:

* **`testWidgets` does not fail on overflow.** `RenderFlex` paints the banner and
  *reports* it — `paintOverflowIndicator` → `_reportOverflow` →
  `FlutterError.reportError`, inside an `assert`, so debug builds only, which is what
  `flutter test` is. The diagnostic becomes a **pending exception** on the `WidgetTester`.
  A render test that renders and asserts nothing about it is green about nothing, and
  this repository has four recorded cases of that shape.
* **Drain in a loop.** `takeException()` removes one pending exception per call, so one
  call can hide the second overflow on a page that has two.
* **The landmark check runs first.** A screen that rendered nothing cannot overflow, so
  `somethingRendered` is a required parameter and is evaluated before the drain. That is
  the other half of vacuous, and a render test hits it by accident when a landmark is
  renamed.
* **The negative control is pinned from both sides**: a planted 480px row at 320 **must**
  be reported, and a planted 320px row at 390 **must not**. The first pins that the
  detector fires; the second pins that it is not simply firing on everything, which would
  make every assertion in the matrix pass for the wrong reason.
* **One `testWidgets` per (screen, state, viewport), never a loop over viewports in one
  test.** `_reportOverflow` reports **once** per render object and only
  `reassemble` restores it. Re-pumping the *same* tree at a second size paints the
  banner — visibly — and reports nothing, so a three-sizes-in-one-test would be blind to
  every overflow after the first and green.

**Two codegen commands, and they are not interchangeable.** `dart run build_runner
build` produces the freezed / auto_route / injectable outputs and **does not run
`gen_l10n`**; only `flutter gen-l10n`, `flutter pub get` and `flutter build` produce
`lib/l10n/app_localizations*.dart`, and **not `flutter test`**. That is why the three
generated files are committed — the same reason Gate 3 tracks `*.gr.dart` and
`*.config.dart` — and why they are committed **formatted**, because `gen_l10n`'s raw
output is not `dart format`-clean and the first gate above would otherwise be red on a
fresh clone. Decision 107.

### Architecture gates — use the script, not an inline command

`tool/verify_purity.sh` enforces four rules mechanically:

1. **Domain purity** — `core/domain/`, every `features/*/domain/`, `core/common/`
   and `core/navigation/` reach no `package:flutter/`, `package:dio/`, or
   `package:http/`.
2. **Feature independence** — no feature imports another feature, and `lib/core/`
   **and `lib/l10n/`** import no feature at all. `verify_purity.sh` Gate 2's `ok`
   line names every owner the pass actually reached, because a directory *nobody
   claimed* produces no output at all — which is how `lib/l10n/` sat outside the
   gate through Phase 9 while a probe importing `features/quiz` and
   `features/reading` from it exited `0`. Fixed in Phase 10 (decision 123); the
   excluded `lib/app/` and `lib/main.dart` are the composition root, named in
   `tool/feature_import_check.dart`'s `_ownerOf` rather than falling out of a test
   that never mentioned them.
3. **Generated files stay lint-silent** — every `*.gr.dart` / `*.config.dart` keeps its
   `// ignore_for_file: type=lint` header, so hand-edits are detectable.
   **The `.freezed.dart` parts are deliberately NOT in this list**, and the reason is
   that freezed emits its own `ignore_for_file` header (`type=lint, type=warning,
   unused_element, …`), which a naive `grep` for `ignore_for_file: type=lint` would
   match on a substring. What replaces the header check for these files is
   `dart analyze --fatal-infos --fatal-warnings` over the whole package, which
   already fails on a hand-edit to a generated file that freezed's blanket ignore
   does not cover — and the idempotence check, which fails on any hand-edit at all.
   Gate 1 (§7) is what covers them where it matters: ten of them live inside the
   pure-Dart directories.
4. **Route inventory is readable** — every `static const String` in
   `core/navigation/app_routes.dart` has a plain-literal initialiser, so the route
   invariants can see it.

Exit `0` clean, `1` violations found, `2` a gate could not run. A gate whose target
directory does not exist yet reports **vacuous** and says so — report that honestly rather
than calling it a pass.

`core/common/` and `core/navigation/` joined Gate 1 in Phase 0c because both files
*document* the property — `app_routes.dart` says "staying Flutter-free keeps the
constants readable from any layer", `app_config.dart` says "no Flutter import, so this
can be read from `core/domain/`" — and both claims are load-bearing (Phase 5 has
`core/domain/` use cases reading `AppConfig`; Phase 4 makes `AppRoutes` the most-imported
file in the app). Neither was checked, so a Flutter import in either left every gate
green. Do not narrow the list back without re-reading those two doc comments.

#### What each gate matches — do not narrow these patterns

- **Gate 1 matches `import`, `export`, *and* `part`** against
  `package:(flutter|dio|http)/`. All three make the named library part of the file's own
  surface: an `export` of `package:flutter/material.dart` is exactly as impure as an
  `import` of it, and neither it nor `part` trips any lint. Both were found by negative
  control — the gate printed `ok` while a planted `export` sat in a domain file. Do not
  "simplify" this back to `import`.
- **The match is anchored to a directive keyword, never a bare substring.** A doc comment
  explaining *why* a file is dependency-free mentions the forbidden package by name; a
  substring scan would fail the gate and force that documentation to be watered down.
- **Gate 2 resolves paths, it does not match URIs.** `tool/feature_import_check.dart` (pure
  Dart, `dart:io` only, no dependency, no codegen — run it directly with
  `dart run tool/feature_import_check.dart`) resolves every `import` / `export` / `part`
  target to a path under `lib/`, takes its feature segment, and compares it against the
  importing file's own feature. Same-package imports are legal Dart in **two** forms —
  `package:evangelion/features/quiz/…` and `../../quiz/…` — and a URI-substring check
  catches only the first. It makes one pass, so a `lib/core/` violation is reported once, not
  once per feature.
- **Gate 2 matches both quote styles; Gate 1 matches single quotes only.** `prefer_single_quotes`
  is enabled and `--fatal-infos` makes the other form fatal, so Gate 1 relies on the analyzer
  for that. Gate 2 is a standalone `dart run` and must not.
- **Gate 4 gates the *mechanism*, not the invariants.** `tool/route_check.dart` parses
  `app_routes.dart`, because Dart has no reflection and the route invariants in
  `app_routes_test.dart` need an enumeration. It exits `1` when a declaration exists whose
  initialiser is not a plain string literal — that route is then invisible to the
  invariants, and the gate says so instead of skipping it — and `2` when the file is missing
  or holds no declarations. It deliberately does **not** re-implement the collision,
  whitespace, case or slash checks; the test owns those. Do not copy them in here: two
  implementations of one invariant is two things to keep in step.

#### A gate that cannot fail is worse than no gate

The previous inline cross-feature check used a backreference,
`rg -v "features/(\w+)/\1"`. Ripgrep has no backreferences, so the pattern failed to
*compile* — and the failure was silent: exit `0`, every line "passed".

The same class of bug lived inside the script itself: it discarded `rg`'s stderr and read
only stdout, so a broken or missing `rg` produced empty output, the hit counter stayed `0`,
and it printed `PASSED — all gates exercised and clean`. A broken toolchain was reported as a
clean run. **A gate has to be able to fail before you may believe it passes.** Concretely:

- `rg` missing from `PATH` → `FATAL … exit 2`. `rg` present but unable to match a known
  string piped in on stdin → `FATAL … exit 2`.
- Every scan captures `rg`'s status explicitly: `1` means "no matches" (the good outcome),
  anything `>= 2` is `FATAL … exit 2`. `0` with an empty capture is self-contradictory and
  also `FATAL`.
- **The script deliberately does not use `set -e`.** `rg` exits `1` on zero matches, and `-e`
  would abort the script at exactly the moment the clean result is available to be read.

Every gate above is negative-controlled: the violation is planted in a scratch copy under
`/tmp/opencode/purity/`, and the correct non-zero exit and message are confirmed. **When you
change a gate, plant a violation and prove it fires before reporting the gate as fixed.**

**Backend must not be modified.** It is read-only reference material at
`/home/fady/Projects/EvangelionBackend`. Never write there. Never run migrations or
`npm install` there. If a task seems to require a backend change, **stop and escalate**.

---

## 8. Hard constraints

1. **Never** write outside `/home/fady/Projects/evangelion`.
2. **Never** modify `/home/fady/Projects/EvangelionBackend` in any way.
3. **Never** commit secrets, `.env` contents, or API keys.
4. **Never** add a dependency that is not listed as approved in the current task.
   **Amended:** the approved set is `pubspec.yaml`'s `dependencies` plus §2.1's
   `freezed` + `freezed_annotation` + Flutter's own `flutter_localizations`
   (`generate: true`). Anything else still needs the user's approval, in the task
   that uses it. See §2.1 for the measurements behind the current set.
5. Work on the branch you were dispatched on. Do not merge to `main`.
6. Do not rewrite `docs/plans/` — a dedicated task owns that.
7. Prefer editing an existing file over creating a new one. New files only where the
   task specifies a path.

---

## 9. Reporting

End every report with:

- **Status:** `DONE` | `DONE_WITH_CONCERNS` | `BLOCKED` | `NEEDS_CONTEXT`
- What you implemented
- What you tested, and the actual pass/fail counts
- Files changed
- Self-review findings
- Concerns

### When to escalate — do not guess

Report `NEEDS_CONTEXT` if requirements, approach, or dependencies are unclear.
Report `BLOCKED` if the task needs an architectural decision with several valid answers,
if you cannot make progress reading the code, or if you are unsure the approach is correct.

**Bad work is worse than no work. You will not be penalised for escalating.**
### Recorded decisions — dropping `equatable` (decision 8a, closing out §2.1)

**131. `equatable` IS GONE. NOT TRANSITIVE — ENTIRELY ABSENT.**

`pubspec.yaml` no longer declares it and `pubspec.lock` contains **zero** occurrences, so
`flutter_bloc` does not pull it either. Nothing in `lib/` or `test/` imports it.

`Failure` and `Result<T>` keep the decision 98/99 reason to stay hand-written, and now
hand-write the `==` they were waiting for. §2.1 decision 8a said removal happens "in
whichever task removes those last two uses" — that is this task.

Two behavioural properties were given up, deliberately, and neither is reachable today:

* **`Success<List<int>>(x) != Success<List<int>>(x)` for distinct equal lists.** `equatable`
  deep-compared `Iterable` props; plain `==` on a `List` is identity. No `Result` in `lib/`
  or `test/` carries a collection — the arms hold entities, strings and ints — but `T` is a
  type parameter, so this is a property of the portable contract rather than of the present
  call sites. It is stated in `result.dart` beside the `==` rather than left to be
  discovered. `Object.hashAll` would not have fixed it: it hashes by identity, so `==` and
  `hashCode` would disagree on the same pair.
* **`Failure`'s props list is gone.** The three fields that decided equality
  (`kind`, `message`, `statusCode`) are compared by name instead, and `details` is still
  excluded. `equatable`'s `Iterable` deep-compare was never reachable here: the only
  collection in the class was the props list *itself*, which `equatable` iterates rather
  than compares. So this half is not a loss. `failure_equality_test.dart` is unchanged and
  still pins it.

**THE `runtimeType` CLAUSE IS LOAD-BEARING, AND IT TOOK TWO WRONG ANSWERS TO SEE THAT.**

I first claimed the clause was redundant, because `other is Success<T>` rejects a mismatched
generic parameter. It does — in the **narrowing** direction. **Dart's generic parameters are
covariant**, so `Success<int> is Success<num>` is `true`, and since `1 == 1.0` is also
`true`, dropping `runtimeType` makes those two Results compare **equal**. Both facts were
measured rather than recalled:

```text
Success<int>  is Success<num>      -> true      # so the type test passes
Success<num>  is Success<int>      -> false     # which is why it only bites one way
1 == 1.0                            -> true      # so the payload agrees too
```

`FailureResult` is worse, because both arms then carry the *identical* `Failure` and the
payload comparison agrees unconditionally.

**AND THE TEST THAT CATCHES IT HAD TO BE REWRITTEN TWICE.** The natural pairing,
`Success<int>(1)` against `Success<String>('1')`, proves nothing — the payloads differ, so
`value == other.value` rejects the pair and the type check is never consulted. Verified:
rewriting `Success`'s `==` to drop the type-argument check entirely left that test **fully
green**. Only a pair whose payloads `==` cannot distinguish — `Success<int>(1)` versus
`Success<num>(1)` — forces the question out to the type. Both `hashCode` implementations
are now held by assertions that fail if either becomes a constant, because "equal values
share a hash" is satisfied by `hashCode => 0` while collapsing every `Result` into one
bucket; the assertions are *disagreements*, not equalities.

This is the repo's sixth recorded vacuous-gate case, and the first one caused by a correct
reading of the type system rather than by sloppiness.

**132. THE DEAD `freezed` MIXINS ARE NOT DEAD, AND THAT CLAIM WAS NEVER MEASURED.**

`mixin _$QuizEvent`, `_$HomeEvent`, `_$QuizEvent` and their siblings looked like the
`freezed` artifact of mixing a mixin into a `sealed` base that nothing references. They are
load-bearing. `lib/features/quiz/presentation/bloc/quiz_bloc.dart:89` reads
`sealed class QuizEvent with _$QuizEvent` — freezed's sealed-union pattern *requires* the
mixin, and it is what gives the union its `==`, `hashCode` and `toString`. Deleting them is
not possible by hand and would not compile. No change was made.

**A NOTE ON WHAT THIS SAYS ABOUT MY OWN REPORTS.** Two claims in a single summary were wrong
and measurement caught both: the mixins (never checked whether anything mixed them in) and
the `runtimeType` clause (a plausible reading of `is` that covariance invalidates). The
useful half of this entry is not the fixes; it is that **three of the four mutations tried
against these `==` implementations initially survived**, and the surviving ones were only
found by asking what the suite was failing to assert rather than by reading it.
