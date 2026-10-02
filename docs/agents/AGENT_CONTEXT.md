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
| `X-User-Id` | **Must be a non-empty, valid UUID string.** Empty string → **401**. Absent → **400**. |
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

1. **Two different error body shapes.** Most routes: `{ "error", "message" }`.
   Some: `{ "statusCode", "code", "error", "message" }`. The error mapper must accept both.
2. **`text_clean` exists only in Arabic.** English localized responses have no `text_clean`
   key at all. Do not assume its presence.
3. **Duplicate submit → `409`.** The quiz must disable questions where
   `already_answered == true` rather than discovering this as an error.
4. **Streak fields only change when `reading_completed == true`.** A single correct answer
   does not advance the streak; finishing the reading does.
5. **`POST` without `Content-Type: application/json` → `415`.**
6. **`?date=` must be exactly `YYYY-MM-DD`.** Anything else is rejected.
7. **`X-User-Role` does nothing.** Never gate UI on it expecting server enforcement.

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

---

## 7. Verification — run before reporting done

```bash
dart format --output=none --set-exit-if-changed lib test tool  # formatting
dart analyze --fatal-infos --fatal-warnings                # types + lint + DEPRECATION
flutter test                                               # full suite
tool/verify_purity.sh                                      # architecture gates
```

### Architecture gates — use the script, not an inline command

`tool/verify_purity.sh` enforces four rules mechanically:

1. **Domain purity** — `core/domain/`, every `features/*/domain/`, `core/common/`
   and `core/navigation/` reach no `package:flutter/`, `package:dio/`, or
   `package:http/`.
2. **Feature independence** — no feature imports another feature, and `lib/core/` imports
   no feature at all.
3. **Generated files stay lint-silent** — every `*.gr.dart` / `*.config.dart` keeps its
   `// ignore_for_file: type=lint` header, so hand-edits are detectable.
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