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