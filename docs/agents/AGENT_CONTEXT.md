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
`setErrorHandler`, no `code` key in any route, and the only `statusCode`
occurrences in `src/` are `res.statusCode` on its own HTTP client. Its test group is
named **`SYNTHETIC — defensive branch, a body this server cannot produce`**, and
`Failure.details` is populated only for it. Both shapes produce a `Failure` that
compares **equal**, because `details` is excluded from `props` — so a repository
cannot reclassify the error, and a bloc cannot emit a spurious state change.

**15. `X-User-Id`'s UUID shape is the CLIENT's obligation, and it is checked in
exactly two places.** The table above says why: the backend validates presence and
nothing else. One implementation, `isValidUserId` in
`core/network/interceptors/identity_headers.dart`, called from (1) `buildApiDio`,
which throws `ArgumentError` naming the value, because a malformed seed is a
programmer error and belongs at composition; and (2) `FakeAuthRepository.signIn`,
which returns `Result.failure`, because a repository never throws across its seam
(§3, LSP). Note the asymmetry with the **group** id, which the server also does not
check but which no client-side check is needed for — group is a small integer and
`3` is the only value that works end to end.

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

Fix the doc or delete the claim — never leave a forward reference that has stopped
being true, because a reader cannot tell it apart from one that still holds. That is
the same rule as §9's "no report without `file:line`", applied to comments.

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