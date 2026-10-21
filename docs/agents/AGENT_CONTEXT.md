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

These were decided with the user. Do not re-litigate. Do not expand scope. **There are exactly two exceptions, and both are dated:** decision 1 was deliberately reversed on 2026-10-13, and `docs/adr/0022-full-fidelity-redesign-supersedes-0001.md` is the authority for it — it ships the fiction table that says which of the redesign's surfaces have a measured endpoint behind them and which are stubs. Read that ADR before proposing anything about screens, the library, or the profile. Do not re-litigate it a second time either; it is decided and the plan that implements it is `docs/superpowers/plans/2026-10-13-lumen-redesign.md`. **Decision 5 was reversed on 2026-10-21** — the servant/admin portal ships — and `docs/adr/0026-the-servant-admin-portal.md` is its authority. It is decided too, and the plan that implements it is `docs/superpowers/plans/2026-10-21-servant-admin-portal.md`.

| # | Decision |
| --- | --- |
| 1 | **Seven screens, and the library and the profile are BACK.** `/login`, `/`, `/reading`, `/quiz`, `/journey` (the profile), `/communion` (the board) and `/settings`; the library carousel returns to `/`, and `/result` retires to a modal. **This row SUPERSEDES `docs/adr/0001-six-screens-library-and-profile-cut.md`, which cut the library and the profile on 2026-10-02 and is now `superseded by ADR-0022`.** The reason it is reversed is not a change of taste: `eva/redesign.html:1244` names seven routes, `rJourney:576` is the profile and the carousel `:536` is the library, and the backend inventory re-measured for ADR-0022 found **`GET /leaderboard` and `GET /streak` real** while confirming that a profile, a book catalogue, medals, a cheer, a share and notes have **no** endpoint. ADR-0001's Context named those same missing endpoints and concluded the opposite — ship six. The conclusion was right about the data and wrong about what to do with it: the redesign is now adopted **at full fidelity**, and the invented parts are enumerated, priced and put behind repository ports instead of being avoided by cutting screens. What that costs is recorded in the ADR's fiction table, and it is not free: medals, cheer, the starfield and the book catalogue ship as stubs. |
| 2 | **Live API** against `https://evangelion-backend.vercel.app` for reading / quiz / result / streak. **Amended 2026-10-20 (ADR-0023):** the base URL was `http://localhost:3000` and the deployed host is now the default; the local backend remains a second target behind `--dart-define=API_BASE_URL=http://localhost:3000`. §5's contract is held by **both** and they differ in three places — §5.1 lists them. |
| 3 | **Login and onboarding are UI-only.** A `FakeAuthRepository` returns a seeded session. There is **no auth endpoint on the backend** and no login API call. |
| 4 | **Settings are local only** (`shared_preferences`). No server sync. |
| 5 | **The servant/admin portal ships** (amended 2026-10-21, reversing the original "No servant/admin portal"). The `servant` feature gives the two servant roles their own shell at `/servant`: a `viewer_servant` reads the cohort's daily roster report, an `admin_servant` also schedules readings and authors their questions. A `kid` cannot reach it. The backend's admin, AI and report routes are now client surface. **The role gate is advisory UX, not authorisation** — the backend parses `X-User-Role` at `src/middleware/identity.middleware.ts:24`, assigns it at `:31`, and never reads it again (`rg 'user\??\.role' src/` → no matches; `rg '403' src/` → no matches). ADR-0026. |
| 6 | **Dark glassmorphic design system** per `docs/plans/03-design-system.md`, including the five mandatory performance mitigations in `docs/plans/09-quality-gates.md` §13. **Amended 2026-10-20 (ADR-0024):** §13's rules 1 and 4 are now **enforced** — a state change rebuilds its target and nothing else, and the boundary is a **budget** rather than a paragraph. The measurements are in `docs/PERFORMANCE.md`; the gate is `test/rebuild_isolation_budget_test.dart`; the decisions are 170–174 below. |
| 7 | **Error handling is `Result<T>`, a `typedef` for `fp_dart`'s `Either<Failure, T>`.** Amended again by §2.1's `fp_dart` correction below — the original wording said "NOT fp_dart" and was wrong. |
| 8 | **States and entities use `freezed`; localization is ARB + `gen_l10n`.** Added by amendment — §2.1. |

### 2.1 Dependency amendment — `freezed`, `gen_l10n`, and the `fp_dart` rejection

Decided by the user after Phase 8, on measurement. This subsection exists so the next
agent does not re-propose what was rejected, or re-litigate what was accepted.

| # | Decision | Consequence |
| --- | --- | --- |
| 7 | **`Result<T>` = `Either<Failure, T>`.** `fp_dart` **adopted**; `dartz` still rejected. | `lib/core/common/result.dart` is now a typedef plus two extension accessors. See the `SUPERSEDED` block below for what that costs. |
| 8a | **Adopt `freezed`** for bloc/cubit states, events and domain entities. | **Shipped** on `refactor/freezed-states`: 34 types converted (17 classes, 14 events, 3 sealed event bases) — see "Recorded decisions — the `freezed` migration" below, decisions 96–100. The `equatable ^3.0.0` removal was deferred at that point because `Failure` and `Result<T>` were deliberately kept hand-written (hazard 2, and decision 7). **Now done — decision 131:** both kept hand-written equality and dropped the base class, so `equatable` is **no longer a direct dependency and no longer in `pubspec.lock` at all**. |
| 8b | **Adopt ARB + `gen_l10n`.** | **Shipped** on `refactor/gen-l10n`: the **five** hand-rolled `*Strings` tables are deleted in favour of `lib/l10n/app_en.arb` + `app_ar.arb` (72 keys **then** — the pair now holds **182**). Decisions 101–111 below. Three of §2.1's own claims were corrected **by measurement** during that task and are marked there: the table and field counts, "compile-time key checking" (a missing key is a codegen *warning*, not a build error), and the locale re-dispatch (it is a corpus re-fetch and it **stays**). |
| 8c | **Do not add `bloc`, `json_serializable`, `flutter_svg` or `package:analyzer`** to do any of this. | A source scan over `lib/` is the sanctioned technique. `package:analyzer` especially stays out — it is a far larger dependency than the problem it would solve. |

**SUPERSEDED — `fp_dart` was ADOPTED. The original rejection was partly wrong; corrected
below and in `docs/DRIFT.md`.** `Result<T>` is now
`typedef Result<T> = Either<Failure, T>` over `package:fpdart`.

**What the original rejection claimed, and which parts were false.** It argued that
"`sealed` + exhaustive `switch` is *strictly stronger* than `dartz`'s `Either`". That
comparison was against **dartz**, not against `fp_dart` — and `fp_dart`'s `Either` is
itself `sealed` (`either.dart:39`). The claim was true of dartz and irrelevant to the
package being rejected. The migration measured three things that argument did not:

* **`typedef` preserves the exhaustiveness.** A `switch` over `Result<T>` is still an
  exhaustive switch *expression* with no `default` arm, because a typedef is an alias
  and not a wrapper. Verified in a scratch package *before* the migration was committed,
  because this was the load-bearing risk.
* **The cost was not 3 call sites but 72 files.** The rejection's own table is stale on
  every line — `try` blocks are **6**, in **4** repositories, not 3 in 2; and 40 `lib`
  files plus 59 `test` files import the type, not 26 and 40. The leaderboard and role
  phases landed after the measurement was taken and it was never re-taken.
* **`fp_dart`'s arms compare by payload, not by type parameter, and the covariance
  guard was genuinely lost.** `Right.operator ==` is
  `(other is Right) && other._value == _value` (`either.dart:572`) — the type arguments
  are never mentioned, so `Right<Failure,int>(1) == Right<Failure,num>(1)` is `true`.
  The hand-written type guarded on `runtimeType` for exactly this reason (decision 131)
  and had mutation tests behind it.

**Subclassing `Right`/`Left` to restore the guard DOES NOT WORK**, and this is recorded
because it looks like it should: a subclass does not match the supertype's *object
pattern*, so `switch` over the alias stops being exhaustive — "does not match the pattern
`Right<Failure, T>()`". Restoring equality that way destroys the sealed exhaustiveness,
so the two requirements are in direct conflict.

**What was kept, and what was given up.** Kept: sealed exhaustiveness at every seam, the
hand-written `Failure` with its `==` and its `toString` that omits `details`. Given up:
the type-argument guard in `Result`'s own `==`, now pinned as *observed behaviour* by
`test/core/common/result_test.dart` rather than asserted as a guarantee — if a future
`fp_dart` release adds the check, that test fails. Also given up: nothing gained
`fp_dart` is currently used for. `flatMap`, `traverse` and `Either.Do` are available and
unused, and `==` on a `List` payload is identity in **both** implementations, so
"fp_dart fixes collection equality" is **false** and is asserted false.

**Two more claims in the original table that measurement disproved.** `879` assertions
naming `Result`/`Failure` is not reproducible — 1184 lines in `test/` name them, 97 on
an `expect(` line — so the figure was taken with an unknown method and is not the basis
of any decision now. And the one real gap that justified the rejection, `AsyncEither`,
does not exist in this codebase at all.

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

* ~~69 distinct string fields across the six tables~~ — **five** tables, **73** string
  fields, **67** distinct bare names, **72** ARB keys **then** (**182** now). Three collide and were
  namespaced: `retry` (`home`/`quiz`/`reading`), `unavailableSuffix`
  (`auth`/`home`/`quiz`/`reading`), `wordmark` (`auth`/`home`).
* **ICU plurals**, which the hand-rolled tables do not have. Arabic has
  zero/one/two/few/many/other, and Phase 8 hand-wrote `1 question` /
  `5 questions` / `٠ أسئلة`. That is a correctness gap, not an ergonomic one.
  **Landed**, and it paid off a recorded debt: the old `captionFor(2)` was `٢ أسئلة`
  where correct Arabic is `٢ سؤالان`. Two counts became plurals and four were audited
  and named as not plural-dependent — decision 104.
* ~~**Compile-time key checking.** A typo becomes a build error~~ — **half true, and
  the half that is false matters**: a key missing from a locale file makes
  `flutter gen-l10n` print a hint and **exit 0**, emitting the template's **English**
  value into the Arabic class, and `dart analyze` reports nothing. A structural test
  over the two ARB files is what turns it red — decision 108.
* ~~**The manual locale re-dispatch dies.**~~ **This bullet was wrong and the code was
  left alone.** `HomePage`/`QuizPage`'s `didChangeDependencies` branch is
  `if (_requested != _language) _load()` — a **corpus re-fetch**, not a string
  resolution, and it reads `Localizations` directly. Emptying it fails **56** tests.
  What died is the resolution *pattern* (`X.of(Localizations.localeOf(ctx))` in five
  `build` methods → `context.l10n`), and `didPopNext` is untouched and still gated —
  decision 106.

### The eleven routes, and the shell that holds the tabs

| Route | Screen | Data source |
| --- | --- | --- |
| `/login` | Onboarding + login (email, password, social buttons) | `FakeAuthRepository` |
| `/` | **The dock shell** — the three real tabs live inside it | **API** |
| `/reading` | Reading sanctuary, EN and AR, zero chrome | **API** |
| `/quiz` | Quiz with instant per-question feedback | **API** |
| `/settings` | The Workshop — language, theme, light, sky, ritual, communion | local |
| `/communion` | The cohort's board | **API** |
| `/journey` | The reader's journey — orb, streak, rings, medals, account | **API** (streak) · local (medals stub) |
| `/servant` | The servant portal's hub — the sections this role has | **API** |
| `/servant/report` | The cohort's daily roster completion report | **API** |
| `/servant/schedule` | Scheduling a reading for a cohort (admin servants only) | **API** |
| `/servant/questions` | Authoring and committing a reading's questions (admin servants only) | **API** |

**THE FOUR `/servant*` ROWS ARE THE 2026-10-21 AMENDMENT, AND THEY LAND WITH THE
CODE THAT REGISTERS THEM** — the pending-implementation paragraph below says
which commits. Decision 5 was **reversed** on 2026-10-21 (ADR-0026), so the
backend's admin, AI and report routes are client surface for the first time.
`/servant` is a **hub page**: its body is the list of the sections this role
has, and it is **not** an `AutoTabsRouter`, because a `viewer_servant` has
exactly **one** section — the daily report — and a tab bar holding one tab is
chrome for nothing. Its three sub-routes are therefore **root-level absolute
paths** and not children of the hub. **The eleven rows are TWO SURFACES, not
eleven screens in one**: decision 1's seven screens are the **reader's**
app, and the portal's four are a **second** surface that a `kid` cannot reach.

**`landingRouteFor()` GETS ITS FIRST CALLER WITH THE PORTAL, AND IT IS THE
ROLE'S OWN ROUTE.** `lib/core/navigation/landing_route.dart` is the one place a
`UserRole` turns into a path, and the function was built for this with **no
caller at all**: a `kid` lands on `/` and either servant role lands on
`/servant`.

**THE ROLE GATE IS ADVISORY UX, NOT AUTHORISATION, AND THE MEASUREMENT IS TWO
GREPS.** The backend parses `X-User-Role` at
`src/middleware/identity.middleware.ts:24`, assigns it to `request.user.role` at
`:31`, and **never reads it again**: `rg 'user\??\.role' src/` returns **no
matches** and `rg '403' src/` returns **no matches**, across all **seventeen**
route registrations in `src/`. So the `RoleGuard` refuses a navigation to
prevent an **accident** — a child is not dropped onto a scheduling screen that
makes no sense for them — and it buys nothing an attacker would have to defeat,
because there is nothing on the server to defeat. The header is set by the
client and every endpoint answers whoever asks.

**THE PARAGRAPH THAT SAID "`/servant` IS DECLARED, NOT YET ROUTED" IS REPLACED,
NOT ANNOTATED.** `lib/core/navigation/app_routes.dart`'s
`servant` constant said it in its own words, ending with "the successor that
registers the portal route replaces this paragraph". The probe behind it is
dated: `router.matcher.match('/servant')` yielded `name=HomeRoute`, `path=/`,
**`redirectedFrom=*`** — field-for-field identical to
`router.matcher.match('/not-a-route')`, and **not** to
`router.matcher.match('/')`, whose `redirectedFrom` is `null`. The `*` is the
evidence that the wildcard handled the path rather than any route matching it,
and the same probe is recorded in `core/navigation/landing_route.dart`.

**`/result` IS GONE, AND `/` IS A SHELL.** Phase 6 turned the result into a
**modal** (`eva/redesign.html:718-727`), so it is no longer a route and
`AppRoutes.result` no longer exists; the screen is reached from the quiz and
from nowhere else. And the redesign's navigation is a **five-slot dock**
(`eva/redesign.html:702-708`), so `/` is now the **shell** that hosts the three
real tabs — **home** (`/`), **communion** (`/communion`) and **journey**
(`/journey`) — while **Read** and **Today** are *push actions* that open
`/reading` and `/quiz` over the shell, which is what hides the dock on them
(`eva/redesign.html:1251` — the dock is visible on `home`, `journey` and `board`
only).

**THE THREE TAB PATHS ARE RELATIVE AND DERIVED.** auto_route rejects a child
path that begins with a slash, so the shell's children are `''`, `communion`
and `journey` — and `AppRoutes.homeTab` / `communionTab` / `journeyTab` derive
them from the absolute paths, so the URLs are unchanged and there is one source
of truth for each.

Routes carry **no `:passageId` parameter**. There is no library to browse, so the passage
is always *today's*. The quiz re-fetches to obtain fresh `already_answered` flags, because
the backend has **no `GET /readings/:id`** endpoint.

**Pending implementation.** The table above is what `lib/app/router/app_router.dart`
registers **today** and it is deliberately not written to a future state; a route
named here that is not registered is the failure mode `docs/DRIFT.md` §1 records.
`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md` adds **two** routes
and retires one, and each lands with the code that registers it: `/communion`
arrived in **Phase 5.5** (renamed from `/leaderboard`); **`/journey`** (the
profile) arrived in **Phase 5.6**; **`/result`** retired to the modal in
**Phase 6**. The library carousel returned to `/` in **Phase 5** as a surface
rather than a route. **The four `/servant*` rows are the one exception this
paragraph has to name**, and they follow the same rule: the three
sub-route constants and the router's four `AutoRoute`s land **together, with
the code that registers them**
(`docs/superpowers/plans/2026-10-21-servant-admin-portal.md`, Tasks 2 and 5).
Until each of those commits lands, this table is the truth and the ADR is the
plan.

**`/journey` AND `/communion` ARE TABS NOW, AND THAT IS A RECORDED CHANGE.**
The paragraph below used to say the journey was *pushed* and needed a back
chevron the prototype's journey does not have. **Phase 6 made both of them
tabs**, so the journey's chevron is **gone** (the prototype's journey has a 68px
spacer instead, `eva/redesign.html:578`) and the board's chevron returns to the
**previous tab** (`eva/redesign.html:1282` — `boardEntry==='push' ?
pop('journey') : tab('home')`).

---

## 3. Architecture — clean architecture, strict

Dependency direction is strictly inward:

```Graph
presentation  ──▶  domain  ◀──  data
```

`domain` imports **nothing** from `data` and **nothing** from Flutter.

### Layer responsibilities

```Tree
lib/
  app/                     composition root: DI, router, bootstrap
  core/
    design_system/         tokens, theme, effects, widgets  (imported by everyone)
    common/                Result<T>, Failure, AppConfig, range arithmetic
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

```Text
core/domain/
  entities/
    scripture_verse.dart    Verse, ScriptureText          — home, reading
    question.dart           Question                      — home, quiz
    quiz_session.dart       QuizSession, QuizAnswer       — quiz, result
    streak_summary.dart     StreakSummary, TodayStatus    — home, result
    submit_result.dart      SubmitResult                  — quiz, result
    auth_session.dart       AuthSession                   — auth, app
    user_settings.dart      UserSettings, AppThemeMode    — settings, app
    curtain_shape.dart      CurtainShape                  — settings, design system
    sky_star_shape.dart     SkyStarShape                  — settings, design system
    sky_star_field.dart     SkyStarField                  — settings, design system
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
| --- | --- |
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

* `final` by default; `const` wherever the compiler allows.
* Exhaustive `switch` **expressions** over `sealed` classes / enums. No `if`-chains for
  state branching.
* **No `dynamic`** anywhere. `avoid_dynamic_calls` is enabled.
* Explicit types on every public API.
* Fire-and-forget futures use `unawaited()` from `dart:async` — never a bare expression
  statement that drops a `Future`.
* `debugPrint`, never `print`.
* No `!` unless provably non-null, with an adjacent comment saying why.
* Prefer constructor initialisers and `final` fields over `late`.
* Named parameters for anything with more than two arguments.

### Forbidden APIs — Flutter 3.47.4

| Never use | Use instead |
| --- | --- |
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

Base URL: **`https://evangelion-backend.vercel.app`** (the deployed backend — Vercel
serverless, Neon Postgres, Redis). Prefix: `/api/v1`. CORS is wide open. Auth is
**not** implemented — identity is a header.

**The local backend is still `http://localhost:3000`, and it is a second target,
not the first.** The deployed host is what `AppConfig.apiBaseUrl` defaults to
(ADR-0023); the loopback one is reached with
`--dart-define=API_BASE_URL=http://localhost:3000`. Every claim in this section
was re-measured against **both**, on 2026-10-20, and the two disagree in three
places — see [§5.1](#51-the-two-backends-and-where-they-disagree) and
`docs/BACKEND-VERIFICATION.md`.

### Identity headers — required on every request

| Header | Rule |
| --- | --- |
| `X-User-Id` | **Must be a non-empty string.** Absent → **400** (Fastify schema, `headers must have required property 'x-user-id'`). Present but **empty** → **401**. A **non-UUID** value such as `not-a-uuid` is **accepted with 200 and echoed back** by the **local** backend, and is a **500** by the **deployed** one. |
| `X-Group-Id` | Required for reading + leaderboard routes. Integer string. Use **`3`**. |
| `X-User-Role` | Parsed but **never checked**. Send `kid`. Decorative. |

Missing required header returns **400, not 401**. Do not write client logic that
distinguishes "unauthenticated" from "bad request" on a missing header.

**The non-UUID row is the one that changed, and the client is unaffected — but
its documented reason did not survive.** The local backend's in-memory fallback
stores the id as a string and echoes it; the deployed backend is real Postgres,
where the id column is `uuid`, so a non-UUID is a cast error and the request
**500s**. `buildApiDio` therefore still rejects a non-UUID at composition time
(`isValidUserId`) — the check now prevents a **server fault** rather than a
mystery, and it is worth more than it was. What is wrong is the *reason* the
check's own doc gives, which says the server "accepts and stores" the value.
`docs/DRIFT.md` carries the entry.

### Seeded working data

The deployed backend's Neon database was seeded once, on **2026-10-19**, by
`src/db/seeds/001_seed_groups_and_scripture.sql`. The local backend's
in-memory fallback seeds the same three users and the same John 3:1-5 reading,
but computes `scheduled_date` from the clock at module load, so its "today" is
always today. **The deployed one does not** — see below.

| Entity | Value |
| --- | --- |
| Users | `11111111-1111-1111-1111-111111111111` (David Mina), `22222222-…` (Peter George), `33333333-…` (Mark Anton) — **all group 3** |
| Reading | `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` — John 3:1-5 |
| Question | `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb` |

**Group 3 / John 3:1-5 is the only path that works end-to-end.** The local
in-memory fallback fabricates non-UUID ids (`question-group-3`) for any other
group or date, and `POST /readings/:id/submit` then rejects them with
`400 body/question_id must match format "uuid"`. The deployed backend has no
such fabrication: its ids come from Postgres, and the only rows that exist are
the seeded ones.

### Endpoints this client uses

```Api
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

11. **`readings/today` IS THE ONLY READING, AND ITS ID IS DATE-STAMPED — ON THE
    LOCAL BACKEND ONLY.** §2's route
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

    **AND THE DEPLOYED BACKEND DOES NOT FABRICATE AT ALL.** That date-stamped id is
    the **local in-memory fallback** auto-provisioning a reading for a date it has
    no row for. The deployed backend has one row — the seeded one, with the
    **UUID** `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` — and every other date answers
    **404**. `docs/BACKEND-VERIFICATION.md` already corrected this once for the
    local backend ("today's reading is the seeded UUID; anything else is
    auto-provisioned"), and the deployed backend removes the second half of the
    correction entirely: there is no auto-provisioning there, so there is no
    second kind of id at all.

    This is also why the result has **no repository, no use case and no
    endpoint**: the submit response is the only artifact it renders, and that
    response exists only as the POST's reply. There is nothing to re-fetch it
    from, which is what makes `QuizBloc.lastResult` the only holder and
    `ResultSheet({required SubmitResult})` a required parameter rather than a
    resolved dependency.

    **A consequence with a cost, recorded so nobody re-derives it: the result
    is NOT DEEP-LINKABLE — and as of Phase 6 it is not a route at all.** It was
    a route whose `ResultRoute` required its `result`, so `pushPath('/result')`
    could not build the page; recorded decision 81 recorded that cost and
    `app_router_test.dart` asserted the failure deliberately. **Phase 6 retired
    the route**: the result is a **modal** over the quiz
    (`eva/redesign.html:718-727`), presented by `QuizPage`'s terminal `finish`
    arm, and `AppRoutes.result` no longer exists. The invariant the old test
    pinned is **gone because the route is gone**, and the test was **deleted
    rather than weakened** — a test asserting that a path literal fails to
    match would be a test about a typo, not about the app.

12. **A DATE WITH NO SCHEDULED READING IS A 404, AND ON THE DEPLOYED BACKEND
    THAT IS THE COMMON CASE.** `GET /readings/today/{lang}` answers
    `404 {"error":"Not Found","message":"No scheduled reading found for your
    cohort today"}` for a date the database has no row for.

    The local backend never produced a 404 here, because its fallback
    auto-provisioned a reading for any date. The deployed backend does, because
    `daily_readings.scheduled_date` was written **once**, as `CURRENT_DATE`, when
    the Neon database was seeded on **2026-10-19** — and `runSeeds()` is a CLI
    (`npm run migrate`), not a boot step, so the schedule does not roll forward.
    Nineteen consecutive dates were probed on 2026-10-20: **2026-10-19 answers
    200 and every other one answers 404.**

    **The client's answer to it is unchanged and already written**: the 404 maps
    to `FailureKind.notFound` (`api_error_mapper.dart:217`) and the Reading page
    renders it through `ErrorView` with the server's verbatim message and a live
    retry. **A designed empty state is NOT part of this change** — see
    `docs/adr/0023-the-deployed-backend-is-the-vercel-instance.md`'s "What this
    change does not do" — so the reader sees the server's English sentence in an
    Arabic app until someone schedules tomorrow's reading.

### 5.1 The two backends, and where they disagree

`AGENT_CONTEXT` §5 is the contract, and the contract is now held by **two**
servers. They agree on the shape of everything the client depends on, and they
disagree on three things. Measured on 2026-10-20 against both; the raw
transcripts are in `docs/BACKEND-VERIFICATION.md`.

| # | Claim | Local `:3000` | Deployed `.vercel.app` |
| --- | --- | --- | --- |
| 1 | absent `X-User-Id` | 400 | **400** — same |
| 2 | empty `X-User-Id` | 401 | **401** — same |
| 3 | **non-UUID `X-User-Id`** | **200**, echoed back | **500** ← *differs* |
| 4 | EN `text_clean` | absent | **absent** — same |
| 5 | AR `text_clean` | present | **present** — same |
| 6 | `/api/v1` prefix | yes | **yes** — same |
| 7 | **a date with no scheduled reading** | 200, a fabricated id | **404** ← *differs* |
| 8 | `?date=YYYY-MM-DD` | 400 | **400** — same |
| 9 | leaderboard | 3 rows | **3 rows**, and **durable** (real Redis) |
| 10 | `today_status` | `pending` | **`off_day`** (real Postgres) |
| 11 | `current_streak` | 4 | **0** (real Postgres, not the fallback seed) |

Rows 3, 7 and 11 are the same cause seen three times: **the deployed backend has
a database and the local one does not.** The local fallback stores what it is
given; Postgres enforces the types and holds only the rows that exist.

**What this means for the client, concretely:**

* **Nothing in `lib/` changes shape.** Every response the client's mappers
  parse has the same keys on both servers. `today_reading_mapper.dart`,
  `submit_result_mapper.dart`, `streak_summary_mapper.dart` and
  `leaderboard_mapper.dart` are unchanged by this move, and the golden tests
  that hold them are unchanged.
* **The streak the app shows is now 0, not 4.** The fallback seeded
  `current_streak: 4`; the Neon row says `0`. That is the truth of the
  database, and a smaller number on the home screen is not a regression.
* **The leaderboard is now durable.** The deployment has a real Redis, so a
  quiz submission moves the reader up the board and the board survives a cold
  start. `USE_STUB_LEADERBOARD` stays available and stays off by default.

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

* **Transport tuning** — timeouts and base URL want their own reason to change.
* **In-memory-backend seed fixtures** — `seedUserId` / `seedGroupId` / `seedUserRole` are
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

* clamp the display end of the scale when it builds the first screen, **or**
* amend §14 to state the exception.

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
doc comment* (the prototype's `ButtonPrimary` — `borderRadius: 14`, `height: 52` — and
its `44`×`44` settings back button, **neither of which the redesign carries**: its
`.cta` is a pill at `border-radius: 999px` with no declared height
(`redesign.html:381`), and its back control is a bare `.chev` with no size at all
(`redesign.html:149`)) — never against `eva/` itself.
So a systematic transcription error present in **both** the widget and its golden is
invisible to this suite by construction: the golden ratifies the mistake, the token
assertion confirms the mistake was applied consistently, and the doc comment quoting
the prototype is prose rather than a test input. Phase 3's review found one instance
of the adjacent failure — `TextLink`'s chevron inked `ink` where the prototype's own
`ButtonText` writes `color: hex.ember` on its `›` and `EvaButton` inked it `ember`,
one prototype glyph in two colours — by reading the prototype, not by any test
failing. **The redesign has no counterpart for that widget**: it draws one chevron,
`.chev` (`redesign.html:149`), inked `--ink-1`.

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
enforces.** A reviewer reading a `file:line` citation into a design reference should
treat it as an unverified assertion unless a test names it.

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

* **Three of this phase's own citations were wrong.** The prototype's social button's
  height (`50`) and `borderRadius` (`14`) and the row's `gap` (`10`) were each
  attributed to the wrong line, and the line map failed on its first run, three times,
  before the table was corrected. **The prototype's line numbering has no counterpart
  to check it against, so the numbers are what a reader has** — and the redesign draws
  that row in two rules: the row's `gap: 10px` (`redesign.html:387`) and the pill's
  `border-radius: 999px` with no declared height (`redesign.html:388`). A doc comment
  quoting a prototype `file:line` is exactly the unverified assertion
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

* **`lazySingleton`, not a factory.** The plan registers `AppRouter` as "a factory
  that reads the session from the `getIt` instance". A get_it `@factory` guarantees
  the exact hazard the same section warns about: every lookup hands back a new
  router, only one of which is mounted, and any other caller gets an object with
  its own `navigatorKey` and no `Navigator` behind it. `app.dart` reads the locator
  once, in `build`, so the dependency on the lifetime is visible in the shape of
  the statement rather than hidden behind it.
* **`routerConfig(reevaluateListenable:)`, not "in `MaterialApp.router`".**
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
`six`@module` files are committed and empty**; each says which phase fills it and
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

**16a. Decision 16's prediction is now OBSERVABLE, and it was HALF RIGHT — so the
"amended" note is here rather than a rewrite of the decision above.** Decision 16
said: *"A deployment pointed at a real database keeps the first and loses the
second"* — the base URL, and the hard-coded `11111111-…`.

**It kept both.** The deployed backend is a real Postgres, and its Neon
database was seeded by the same `src/db/seeds/001_seed_groups_and_scripture.sql`
that seeds the local fallback's memory, so `11111111-1111-1111-1111-111111111111`
is a row in `users` there — the same David Mina, in the same group 3, with the
same `total_points`. The reason the prediction was wrong is a fact about **how
the seed was written**: it seeds the same three users whether the target is
Postgres or the memory fallback, so "a real database" did not mean "a different
set of users". It would have meant that if the real database had been seeded
differently — or not seeded at all.

**What the split bought, therefore, is not that the seed is gone; it is that the
seed is somewhere the base URL is not.** That is the property the decision
actually wanted, and it survives: `AppConfig` holds transport, the seed lives
beside `FakeAuthRepository`, and `core_module.dart` is the one place they meet.
The deployed backend is now the default target (ADR-0023), and the seed still
works against it — verified live, 2026-10-20: `GET /streak/summary` with
`X-User-Id: 11111111-…` answers 200 for that user and 500 for a non-UUID one.

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

```Text
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

* **Prefer the reading endpoint's streak (`4`).** It agrees with the reading the
  reader is looking at, which is what makes it tempting. It is also a choice made
  *in the client* about a disagreement the *server* owns, and it would silently
  change every number the top bar draws the moment either endpoint is corrected.
* **Prefer the streak endpoint's (`0`).** Same objection, and worse: it is the
  endpoint whose entire job is the streak, so preferring it here means `/` reads the
  summary and ignores the reading it is named for.
* **Reconcile** — take the max, or "completed if either says completed". Strictly
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
DECLARES ITS OWN `GetReaderSession`.** The prototype's home greeted `Miriam` — the
redesign greets `peace, Mariam` (`redesign.html:515`, and `redesign.html:993` sets
it per language) — and the prototype's top bar rendered the monogram `MK` on an
avatar the redesign does not draw at all: its journey carries a `M` orb
(`redesign.html:586`) and the name `Mariam Hanna` (`redesign.html:587`). There is no
user endpoint and the profile screen is cut, so those two literals were the
prototype's only "who is this". `AuthSession` already
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
UNOBSERVABLE — both stated rather than one.** The prototype's bead row was
`<ProgressBeads total={5} completed={2} current={2} />`, which describes *passage*
progress across the four-card library grid §2 decision 1 cut — and **the redesign has
no counterpart for it**: its dot row is the **quiz's** (`.dots`,
`redesign.html:328`, drawn at `redesign.html:568`) and counts quiz questions. The
live reading
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
The prototype split a literal `I` off `"n the beginning…"` with a 76px ember `I`;
the redesign does the same thing with a `::first-letter` rule at **56px** in gold
(`redesign.html:172`) — and applies it **only in the English arm**
(`redesign.html:1360`: `i===0&&lang==='en'?' drop':''`). The Arabic first verse
begins `كَانَ`, and enlarging a joined, right-to-left Arabic letter breaks its
connection to the word it belongs to and puts an accent glyph where ink should be.
That is a defect rather than a rendering of the design, and it is the same class as
defect #2 ("Arabic never uses the mono family"), which Phase 7 owns in the
sanctuary. So `PassageDropCap` is used for the Latin arm only and the Arabic preview
is rendered whole — the rule is recorded next to the use so Phase 7 does not
re-derive it from the prototype.

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

**AMENDED IN TASK 5.6: THE AVATAR THIS DECISION IS ABOUT NO LONGER EXISTS.**
`AppTopBar` — the widget that carried the avatar, and the only reason this
decision's "one argument at one call site" had a call site — was **deleted in
Task 5.2**, when `/` was rebuilt against the redesign: the redesign's home
(`eva/redesign.html:513-538`) has **no app bar and no avatar**, and the greeting
block replaced both. The paragraphs below are therefore a record of a decision
about a widget this client no longer ships, kept because the **rule** they
established still governs anything drawn at a 44px target — and because
decision 155's reasoning was written against the same avatar, and 5.6 amends
that decision with the fact.

**The parameters named below — `streakSemanticLabel`, `avatarSemanticLabel` and
`avatarUnavailableReason` — do not exist in the tree.** A reader who goes
looking for them will not find them, and that is the drift this note is for.

**31. THE AVATAR IS 32 PAINTED INSIDE A 44 BOX, AND THAT IS THE ONE DELIBERATE §14
DIVERGENCE FROM THE PROTOTYPE.** The prototype's avatar button declared `width: 32,
height: 32`. The painted
circle is exactly that; the **tap and focus box** around it is 44, because
`IconActionButton`'s default and `iOSTapTargetGuideline`'s minimum are both 44 and a
32px target is below what a finger reliably hits. The extra 12 pixels are a
transparent box, so the bar draws what the prototype draws — **the cost is that the
bar's row is 44 tall rather than 32**, because a row is as tall as its tallest
child, and that one number is the whole divergence.

**The avatar's gradient is NOT the prototype's, and that is a recorded
substitution.** The prototype's avatar filled it with `rgba('#14B8A6', .5)` →
`rgba('#3B5BDB', .5)` and rimmed it with the same teal. **Neither hue is a token** —
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
WHOLE OF DEFECT #11.** The prototype's top bar hard-coded `Evangelion`, `MK` and
`12` — **the redesign draws no app bar and no avatar at all**, so none of the three
has a counterpart there. Every value is a **required named parameter** — including
the wordmark, which is a
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
The prototype's `TopBar` was a `display: flex` `div` with a `padding` and a
`zIndex` and **no `backdropFilter` in its 32 lines** — and the redesign's own app bar
is the same shape (`.appbar` and `.abrow`, `redesign.html:142-143`: a padded flex row
with no backdrop filter; the redesign's home carries no app bar at all). The prototype
deliberately leaves the bar see-through so the orbs show behind it.

**One** blur ships, on the panel — the client's `24` is the prototype's own
`blur(24px)` on its hero panel, and **the redesign's home card blurs `12`, not
`24`** (`.hcard`, `redesign.html:250`), so the two sides differ and the client is on
the prototype's. `AppTopBar`
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
  a `24`. Measured: the panel is the prototype's own `blur(24px)` and the FAB button
  is its `blur(20px)`. The two are swapped, and **no `20` site survives at
  all** (`PassageCard` and `SealFAB` are both cut with the screens that used them);
* `20` is not the median of its own list. The prototype had **NINE** blur sites, and
  they measure `8, 12, 12, 16, 16, 20, 20, 24, 24` —
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

* **A second port, `ScriptureRepository`.** Two ports for one endpoint means two
  adapters, two sets of fakes, and a question — answered per screen — about which one a
  caller wanted. `core/domain/` exists so a type consumed by two features lives in one
  place; `ScriptureText` is consumed by `/` and `/reading`, so it belongs there, and so
  does its port.
* **Make `today` return the wide type and let the screens ignore the extra.** This is
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

* **Strict on every verse.** One bad row in a 40-verse passage blanks the whole reading.
* **Substitute an empty verse.** The reader sees a numbered gap with nothing in it and no
  way to know it is a gap; the skip is at least visible as a missing number.
* **Throw the whole response away.** Strict-on-first is already that, for the only case
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
`01-source-analysis.md` §2 row 2 said two; the source says **nine** — in the
prototype's Arabic reading screen: the metadata row, the CTA caption and the **seven
`<sup>` verse markers**. The row has been corrected. The two **English-only** sites —
the prototype's input label and its category-chip label, both `Space Mono` — stay in
Space Mono, which is the point of the split; **the redesign writes the same split
itself**, with the verse marker in the mono family (`redesign.html:170`) against the
Arabic arm's Amiri (`redesign.html:140`), and the metadata row the same way
(`redesign.html:146` against `redesign.html:148`). `reading_glyph_test.dart` parses
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
dropping the control (it is in the prototype **and** in the redesign — where the
type-size row is a `16`–`26` px range input (`redesign.html:693`), a **different
model** from the prototype's `1`–`5` stepper, and the client keeps the prototype's).

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
not glass: the prototype's sticky CTA was a plain
`linear-gradient(to bottom, transparent, rgba('#05081A', 0.95) 40%)` over the scrolling
page with **no backdrop filter at all** — a scrim, not a `GlassSurface`. (The prototype
carried no `4px 24px 32px` blur behind that CTA; the gradient was the whole of it, and
it is the value `neural_scaffold.dart`'s `bottomFade` cites.) A `GlassSurface`
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

* **A `ScriptureVerse` widget taking the three styles.** It would be testable in
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

* **A widget taking the `Verse` and the language and deriving the styles itself.** Then
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

* **`text.runes.take(1).map(String.fromCharCode)` inline at each call site.** Two copies of
  the astral fix and the trim rule, which is exactly the shape that let Phase 7 re-create
  Phase 6's defect.
* **`package:characters`.** Already a transitive dependency, so no `pubspec.yaml` change —
  and §8.4 pins that file, so promoting it is a hard stop. It also does not answer the trim
  question, and `String.fromCharCode` on a single rune is the whole of what is needed.
* **Stripping combining marks too.** A shape test; see above.
* **Leaving the second half to `previewText` only.** `previewText` owns the *truncation* and
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
were bare `<button>`s with an inline `<svg>` and **no label at all** — the reader's back
button and its `Aa` and bookmark controls, on both arms — and **the redesign still leaves
two of them glyph-only** (the reader app bar's `‹` and `✦`, `redesign.html:542` and
`redesign.html:544`), so §14's requirement for an
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

* **A `TextTheme` whose Arabic slots resolve to Amiri.** **Not available, and this is a
  framework fact rather than a preference.** `MaterialApp` takes one `theme:` and one
  `darkTheme:` and has **no per-locale theme hook**, so there is nowhere to put a second
  text theme for the engine to choose between. Every design system that appears to do this
  is switching one at runtime in `MaterialApp.builder`; that is a theme swap, and on this
  app it would swap `TextTheme` for the whole screen rather than resolve a run's family.
* **Reading `Localizations.localeOf` inside a Tier-1 primitive.** Decisions 66 and 71 reject
  this and the rejection stands: an English label and an Arabic one would travel the same
  invisible code path. `arabicAware` takes the direction **as a parameter**, so every call
  site names the ambient source in full — `Directionality.of(context)` — and a reviewer can
  see it. It also adds no second decision: decision 61 established that direction comes from
  the locale through `MaterialApp`, so there is nothing new to keep in step, and `lib/` still
  contains **no `Directionality` this client installs** and **no `startsWith('ar')`**.
* **A shape test on each run's own script.** Decision 29 rejects one for this family of
  widget for a measured reason (it breaks on a verse opening with a numeral or a bracket, and
  §5's live payload opens one behind a `‹Verily`), and it would be a per-run scan on every
  frame of a scrolling list.
* **Parameter threading.** Phase 7's reviewer already called it "a screen rewrite wearing a
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
   lead-in `صباح الخير،` — a run that renders in Cormorant Garamond. **A correct render
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

> **AMENDED BY PHASE 6 OF THE LUMEN REDESIGN — the decision HOLDS, the mechanism
> died with the route.** The result is a **modal** now
> (`eva/redesign.html:718-727`), `AppRoutes.result` no longer exists, and
> `features/result/` has moved into `features/quiz/`. So `ResultPage` is
> `ResultSheet`, the required constructor parameter is unchanged, and the
> "`/result` is not deep-linkable" cost is now "the result is **not a route**".
> The reasoning below — the response has to survive the reader leaving `/quiz`,
> and Gate 2 forbids the two directions of the import — is **exactly** why the
> result lives in `features/quiz/` now, and it is why it is presented by the
> quiz rather than fetched. What changed is the delivery, not the constraint.

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

```Text
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
field, and decision 18's rule applied twice. The split is deliberate: the label is
transcribed — the prototype's own `Check answer`, the unchecked arm of its
`{checked ? 'Next question' : 'Check answer'}` switch, which the redesign has no
label for at all (its grader is one-tap, `redesign.html:1423`) — and the reason is
written, and the reader who cannot see the button is the
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

The prototype's result screen had a three-tile row (`14 Read` / `9 Reflected` /
`5/5 Best`) and the plan transcribes three. **The redesign draws no tiles at all** —
its result card is a ring (`.bigring`, `redesign.html:447`) and a recap dot row
(`redesign.html:453`) — so the two tiles this screen ships are the client's own count
and not a transcription. The first draft
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

* `app_ar.arb` (72 keys **then** — the pair now holds **182**) and the three generated `app_localizations*.dart` files
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
(`Day 12 — your longest yet` — and **the redesign has no counterpart**: its streak
chip shows the number `12` and the label `days`, `redesign.html:516` and
`redesign.html:248`) to fix nothing. **verse counts** (`readingVerse`) — the marker
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
exact `file:line` they must still name. Proven by mutation: removing one description's
citation — the prototype's streak line, `Your streak is glowing. Keep it alive.` —
fails 1 test by name.

**111. §2.1's COUNTS WERE WRONG, AND THE CORRECTION IS RECORDED RATHER THAN QUIETLY
REUSED.** There were **five** tables, not six — `LoginStrings`, `HomeStrings`,
`QuizStrings`, `ReadingStrings`, `ResultStrings`; the sixth feature, `/settings`, has
never had a table. They carried **73** string fields, of which **67** were distinct
bare names before namespacing (the three collisions account for the other 6), and they
are **72** ARB keys — **at the time** — after `questionSingular`/`questionPlural` merge into one plural and
`resultTotalCaption` becomes one. **The pair holds 182 today**, and the count is a
**gate**: `test/l10n/app_localizations_test.dart` asserts it exactly, so a key cannot
be dropped without the number moving. §2.1's "69 distinct string fields across the six
tables" matches none of those three numbers.

### Recorded decisions — Phase 10 review

Shipped on `feat/phase-10-polish`. **2215 → 2311 tests, coverage 98.17% → 98.21%.**
The phase's own framing was measured before anything was built and **three of the four
scope bullets were already satisfied**; the work that was actually missing is below,
together with the two recorded decisions that are not "what I built".

#### **123. THE FOUR PLAN BULLETS, MEASURED — THREE WERE ALREADY DONE**

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

##### **124. THE GLOBAL ROUTE TRANSITION DID NOT HONOUR REDUCED MOTION**

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
  already scrolls — the prototype's settings root carried `overflowY: 'auto'`, and the
  redesign's own scroll container is `.scroll` (`redesign.html:157`) — so dropping it
  above three groups either nests two scroll views or eats the form.
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

```Text
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
tool/verify_linux_build.sh                                 # the app REALLY builds
python3 tool/gates/citation_check.py                       # every citation resolves
python3 tool/gates/orphan_widget_check.py                  # every widget is placed
```

**THE TWO `python3` GATES BELONG IN THIS LIST, AND THEY WERE MISSING.** They are
gate 4 in `CONTRIBUTING.md`'s table, and §7 is *"the commands that must pass
before you report work done"* — so a list that omits two of the gates is a list
a sub-agent can satisfy while breaking the tree. What they check:

* **`citation_check.py`** — every `redesign.html:NNN` claim in the
  source resolves to a **real line of the design reference**. It checks **existence
  and range only** — *not* that the line still says what the comment claims — so a
  citation that points at the right line for the wrong reason is green, and
  the per-widget re-pointing is on the writer.
* **`orphan_widget_check.py`** — **a widget anywhere under `lib/` is built,
  tested, and no screen's tree contains it.** The inventory is **all of
  `lib/`** — *not* the `*/widgets/` directories, which is what let three
  widgets sit on no screen at all — and the roots are the **registered pages
  PLUS THE APP ROOT** (the widget that installs `MaterialApp.router`, derived
  by content the way the router is derived). The **router is derived** from
  auto_route's own `@AutoRouterConfig()` marker rather than named by path, and
  **zero matches or more than one is FATAL (exit 2)** — because "this page is
  not registered" and "the router moved" must not be the same answer. **A bogus
  `@RoutePage()` is a FAILURE (exit 1), not a diagnostic**: the annotation
  claims "this is a screen the app can navigate to", and if it cannot, either
  the annotation is decoration or the registration was forgotten.

**`flutter build linux --release` WAS A GATE THAT COULD NOT FAIL, AND WAS REPLACED.**
See recorded decision 142. `tool/verify_linux_build.sh` runs `flutter doctor`, clears
the native build state so CMake must regenerate, builds, and asserts the bundle is not
older than the newest `lib/**.dart`. The old line is kept below only as the thing that
was wrong:

```bash
flutter build linux --release                             # DO NOT TRUST THIS ALONE
```

It reported `✓ Built` on 2026-10-07 with a **2026-10-04** `CMakeCache.txt` and
`libgtk-3-dev` not installed, because every native output was already present and CMake
was never asked to regenerate. That false green was reported as a passing gate in three
consecutive commit messages. `flutter doctor` — absent from this list for ten phases —
names the missing package in one line.

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

* **Gate 1 matches `import`, `export`, *and* `part`** against
  `package:(flutter|dio|http)/`. All three make the named library part of the file's own
  surface: an `export` of `package:flutter/material.dart` is exactly as impure as an
  `import` of it, and neither it nor `part` trips any lint. Both were found by negative
  control — the gate printed `ok` while a planted `export` sat in a domain file. Do not
  "simplify" this back to `import`.
* **The match is anchored to a directive keyword, never a bare substring.** A doc comment
  explaining *why* a file is dependency-free mentions the forbidden package by name; a
  substring scan would fail the gate and force that documentation to be watered down.
* **Gate 2 resolves paths, it does not match URIs.** `tool/feature_import_check.dart` (pure
  Dart, `dart:io` only, no dependency, no codegen — run it directly with
  `dart run tool/feature_import_check.dart`) resolves every `import` / `export` / `part`
  target to a path under `lib/`, takes its feature segment, and compares it against the
  importing file's own feature. Same-package imports are legal Dart in **two** forms —
  `package:evangelion/features/quiz/…` and `../../quiz/…` — and a URI-substring check
  catches only the first. It makes one pass, so a `lib/core/` violation is reported once, not
  once per feature.
* **Gate 2 matches both quote styles; Gate 1 matches single quotes only.** `prefer_single_quotes`
  is enabled and `--fatal-infos` makes the other form fatal, so Gate 1 relies on the analyzer
  for that. Gate 2 is a standalone `dart run` and must not.
* **Gate 4 gates the *mechanism*, not the invariants.** `tool/route_check.dart` parses
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

* `rg` missing from `PATH` → `FATAL … exit 2`. `rg` present but unable to match a known
  string piped in on stdin → `FATAL … exit 2`.
* Every scan captures `rg`'s status explicitly: `1` means "no matches" (the good outcome),
  anything `>= 2` is `FATAL … exit 2`. `0` with an empty capture is self-contradictory and
  also `FATAL`.
* **The script deliberately does not use `set -e`.** `rg` exits `1` on zero matches, and `-e`
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

* **Status:** `DONE` | `DONE_WITH_CONCERNS` | `BLOCKED` | `NEEDS_CONTEXT`
* What you implemented
* What you tested, and the actual pass/fail counts
* Files changed
* Self-review findings
* Concerns

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

**133. `flutter_animate` IS PINNED, AND IT CANNOT DELIVER A SPRING.**

Added as `flutter_animate: 4.5.2`, pinned exactly while every other dependency here uses a
caret. Its surface is a set of extension methods that can appear or disappear between
minors, and this app's motion tokens have to keep meaning one thing across an upgrade.

Its complete effect surface was extracted from the 4.5.2 tarball rather than recalled:

```Text
align blur blurX blurXY blurY boxShadow callback color crossfade custom desaturate effect
elevation fade fadeIn fadeOut flip flipH flipV followPath hide listen move moveX moveY
rotate saturate scale scaleX scaleXY scaleY shader shake shakeX shakeY shimmer show slide
slideX slideY swap then tint toggle untint visibility
```

**No `spring*`, no `elastic*`, no `*Staggered`.** It animates with `Curve`s and never with
physics, which means the two mechanisms below cannot be one token and the difference is
mechanical rather than stylistic.

Two costs accepted deliberately. `flutter_shaders` arrives transitively for `.shimmer()`,
which nothing in this app uses — the price of the package, not a request for it. And it was
**last published 2024-11-25**.

**134. "ALL CURVES ARE EASE-OUT" WAS WRONG ABOUT THE PROTOTYPE, AND THE SPRING PATH I FIRST PROPOSED DOES NOT WORK.**

§5.3's *"All curves are ease-out. No bounce, no spring"* was implemented literally and is
now **partly superseded**. "No bounce, no spring" was **true of the superseded
prototype** — and **it is the CLIENT'S OWN rule now**: the tokens this app ships
carry no spring and no bounce, and `EvaMotion.achievementSpring` is a
`SpringDescription` for achievement moments only, which is a different thing from a
spring *curve*. What was wrong is the implication that every curve is a plain
`easeOut`: the prototype's own `QuizOption`, the most-tapped element in the
app, used `all 250ms cubic-bezier(0.16,1,0.3,1)`, which is `Curves.easeOutExpo` —
and **the redesign keeps the same curve as a token**, `--e-light:
cubic-bezier(.16,1,.3,1)` (`redesign.html:18`).

*Rejected: adopting a spring wholesale.* A spring on **every** tap says nothing; a spring
on *your streak went up* says the thing happened. One curve cannot distinguish those, so
the token file now has two families: routine (`interactiveCurve`, monotone) and achievement.

*Rejected: `Curves.elasticOut` for the achievement.* Measured overshoot **27.5%** — a
quarter again over the target reads as a glitch on a flame meant to look like it caught.
`Curves.easeOutBack` measures **8.7%** and is what ships.

*THE CLAIM THAT WAS WRONG, AND IT WAS MINE.* I proposed `Animate(controller: …)` driven by
a `SpringSimulation` as the escape hatch for getting physics through the package. **It does
not work.** `EffectEntry.buildAnimation` wraps whatever controller it is handed in
`Interval(begin / controller.duration, end / controller.duration)`, and a spring's value
leaves `[0,1]` by design — measured, that trips `ParametricCurve`'s `t >= 0.0 && t <= 1.0`
assertion inside `Curves.transform`. A spring routed through `Animate` does not merely lose
its overshoot, it **throws**. `EvaMotion.achievementSpring` is therefore for widgets that
drive their own controller, and `achievementCurve` is for `Animate`-driven effects. The two
are matched on overshoot (~8.3% vs ~8.7%) so they feel like one family, and that pairing is
asserted.

*AND A SECOND ERROR IN THE SAME TOKEN FILE.* The spring's duration was first written as
`achievementSettleHint = 420ms` with a doc claiming it was "roughly how long the spring
takes to look finished". **Measured, a 420ms nominal does not settle until ~796ms** —
`withDurationAndBounce` derives stiffness as `4π²/duration²`, so the nominal is a stiffness
dial wearing a duration's clothes. Renamed to `achievementDuration` and moved to 180ms
(measured settle ~344ms, under the 400ms a complex transition is allowed), with the recorded
measurement split into `achievementSettle` for the curve path — because giving both paths
180ms would make the curve pop finish in half the time and leave `achievementExit` (220ms)
*slower* than the entrance it follows.

**135. `EvaAnimate` EXISTS BECAUSE THE PACKAGE READS NO ACCESSIBILITY FLAG.**

`grep -r disableAnimations` over the whole package returns nothing. §14 requires every
animation to check `MediaQuery.disableAnimationsOf(context)`, and decision 124 was recorded
for a single site that forgot — so using the package directly makes *every* call site a
fresh violation, invisibly.

Its defaults are also values this app already rejected: `Animate.defaultDuration` is a
literal `300ms` and `Animate.defaultCurve` is `Curves.linear`. `installPackageDefaults()`
overwrites both from the composition root, before DI and before any widget exists, so even a
forgotten wrapper degrades to the app's own curve.

Timings come from `MotionMoment`'s factories rather than from parameters on the widget, so a
literal cannot reach an effect even by accident. Reduced motion sets the controller to its
end value rather than returning `child` bare — the same substitution decision 124 reached
with `kAlwaysCompleteAnimation`, and for the same reason: a transitions builder's job is to
wrap the page, and swapping the subtree for a reader who asked for *less* motion rather than
*no* widget is the wrong trade.

*Two bugs this phase's own tests caught, both invisible to reading the code.* `_play()` did
not reset to `0` before `animateTo(1.0)`, so a trigger change replayed **nothing** — the
animation was already at 1.0 and the call completed instantly. And `Animate.initState` ends
in `Future.delayed(Duration.zero)`, which creates a real `Timer`, so every `Animate` left
one pending; a bare `tester.pump()` does not drain it because a zero-length pump does not
advance the fake clock. Both are now covered by assertions that fail on the mutation.

**136. THE COHORT SIZE IS **PROVABLE TODAY**, SO THE `ZCARD` IS A NO-OP AND NOT A
FOLLOW-UP TASK.**

Phase 1's plan was to leave `cohortSize` `null` until the backend grew a `ZCARD`, and to
stub it meanwhile. Both halves were wrong, and measuring the endpoint showed it.

The route sends `total_ranked: enrichedEntries.length` — **rows returned, after `limit`**.
That is not the cohort size: with `limit=50`, a cohort of 60 answers `50` and a cohort
of 3 also answers 3. Reading it as the size is how "3rd of 3" appears on a cohort of
sixty.

But `ZREVRANGE(key, 0, limit - 1)` returns `min(members, limit)` rows, which makes the
true size recoverable **whenever the cap did not bind**:

```dart
if (reportedTotal > rowsReturned) return reportedTotal;   // a true ZCARD
if (rowsReturned < limit)        return rowsReturned;    // cap did not bind
return null;                                             // genuinely unknown
```

* today, `limit=50`, cohort 60 → 50 rows, `50 > 50` false, `50 < 50` false → **`null`**,
  the honest answer;
* after the route switches to `ZCARD`, the same cohort sends `total_ranked: 60` with 50
  rows → `60 > 50` → **`60`**, and **not one line of the mapper changes**;
* a cohort of 3 answers `3` under both versions, which is right under both.

So the backend fix costs one line in a Fastify route, and the value is not stubbed,
not faked, and not gated behind a flag. A version that trusted `total_ranked` would have
had to be *edited* to become correct; a version that only inferred would have silently
begun under-reporting the moment the field became truthful. The rule is written as a
comparison against the rows so that neither is true.

Four mutations against it, all red — including **deleting the `reportedTotal >
rowsReturned` arm**, which is the post-`ZCARD` regression and would be invisible until
the backend shipped.

**137. THE CARD ASKS FOR FIFTY AND DRAWS THREE, AND THAT GAP IS THE FEATURE.**

`kLeaderboardPreviewLimit = 50` (the request) against `kLeaderboardPreviewRows = 3`
(the drawing). The first draft had one constant of `3` on both sides, which made
`cohortSize` **permanently unknowable** on the card: `rowsReturned == limit` is exactly
the ambiguous case. The card would have been silently less informative than the screen
it links to.

A few kilobytes of leaderboard JSON is not a close call against a card that can never say
how many children there are.

**138. THE STUB REPOSITORY IS A `--dart-define`, NOT A DEBUG FLAG, AND THE PURITY GATE
IS WHY.**

`StubLeaderboardRepository` exists because the leaderboard is empty **and cannot be
otherwise**: scores only enter Redis via `leaderboardService.recordScore`, called from
`submissions.service.ts:105` on a *successful* submission, and submission cannot succeed
against the memory fallback — `POST /submissions` validates `reading_id` and
`question_id` as UUIDs while the fallback mints `reading-group-3-2026-10-004`. Measured:
`{"group_id":3,"window":"weekly","total_ranked":0,"my_standing":null,"leaderboard":[]}`.

Switched on with `--dart-define=USE_STUB_LEADERBOARD=true`, read through
`bool.fromEnvironment` in `leaderboard_module.dart`. **`kDebugMode` was rejected:** it
lives in `package:flutter/foundation.dart`, `leaderboard_module.dart` is reachable from
`injection.dart`, and recorded decision 4 makes that graph's Flutter-freedom a gate. The
framework would have been imported to ask a yes/no question about a stub.

`DioLeaderboardRepository` is the **default** and the stub is unreachable unless a build
names the flag, so the whole pipeline to the real endpoint is what ships.

**139. `LeaderboardRowTile` LIVES IN THE DESIGN SYSTEM, AND THAT IS A REAL COST.**

`injection_test.dart` Gate 2 refused Home's card importing `features/leaderboard/` for
`LeaderboardRowTile` — correctly, and symmetrically, since the page was importing
`features/home/` for the empty state. Two features, one widget.

`core/design_system/widgets/` is the only shared widget home in this repo, so it went
there — which makes a design-system widget name `core/domain/entities/leaderboard_board.dart`,
i.e. a design system that knows about one product type. Recorded rather than hidden; the
alternative was two copies of one row design drifting apart. `EmptyState` was already in
the design system, so the empty state needed no new shared widget at all.

**140. THE RENDER TEST FOUND A CRASH THE BUILD COULD NOT, AND ITS OWN LOOP WAS
VACUOUS FOR TWO RUNS.**

`ErrorView` asserts `onRetry == null || retryFamily != null`. `/leaderboard` and Home's
card both passed `onRetry` with no family. `flutter build` succeeded, `dart analyze` was
clean, and the screen would have thrown **on the failure path only** — which is the path
no successful launch reaches. `leaderboard_overflow_test.dart` renders the failure state
and it fired.

Then the same file's surface loop was wrong for two runs: `evaPrimitiveHarness`'s `size`
parameter is documented as **retained but unused**, the surface being fixed by
`pumpPrimitive`. So all three "surfaces" rendered at the default 800x600 and the overflow
claim was true of a surface nobody ships. `dart analyze`'s *unused local variable* on the
destructured `size` is what exposed it — a lint, not a test. The fix sets
`tester.view.physicalSize`, and the loop now asserts the laid-out width so a harness that
ignores the size again fails here rather than silently.

**141. `HomeState.toString()` IS HAND-WRITTEN, AND A NEW FIELD IS INVISIBLE IN IT UNTIL
SOMEONE ADDS IT.**

`@Freezed(copyWith: false)` plus whole-state writers means adding `leaderboardStatus`
required editing **every** writer — `withReading`, `withStreak`, `withReader` — because a
writer that forgets the new fields silently clears them. That is the cost of the
discipline working, and it is why the card survived: a reading update no longer wipes it.

The `toString()` is the same trap in miniature. Two frames in `home_bloc_test.dart` were
indistinguishable in a failure message until it learned to print `board: ready 3`. It
counts rows rather than printing the board, because a failure message that renders a
twelve-field entity stops being readable.

**142. `flutter build linux --release` REPORTED SUCCESS WITHOUT BUILDING ANYTHING, AND
`flutter doctor` WAS NOT IN §7.**

Measured on 2026-10-07, after ten phases of "release build green" in this file and in
three consecutive commit messages.

The command printed

```Text
Building Linux application...
✓ Built build/linux/x64/release/bundle/evangelion
```

while `build/linux/x64/release/CMakeCache.txt` was dated **2026-10-04** and the
`libgtk-3-dev` package the Linux toolchain needs was **not installed**. Every native
output was already present, so CMake was never asked to regenerate anything, nothing was
compiled, and the command reported success. Deleting the cache produced the real answer
in seconds:

```Text
CMake Error at FindPkgConfig.cmake:1093 (message):  - gtk+-3.0
  flutter/CMakeLists.txt:25 (pkg_check_modules)
```

**A MISSING TOOLCHAIN FAILS LOUDLY; A STALE CACHE DOES NOT.** That asymmetry is what
made it survive: `flutter doctor` had been saying `✗ GTK 3.0 development libraries are
required` the whole time, and §7 never ran it. The list of gates grew four times across
ten phases and nobody added the one command that checks the *build environment* rather
than the *source*. Every other line in §7 is about the code; this one is about the
machine, and it was the only one that could report a false green for reasons no amount
of reading the diff would reveal.

**AND THE FAILURE WAS CACHED, WHICH MADE IT WORSE.** Once `libgtk-3-dev` was installed,
the build still failed:

```Text
Imported target "PkgConfig::GTK" includes non-existent path "/usr/include/webp"
```

`/usr/include/webp` exists in **no current `.pc` file** — `grep -rl webp
/usr/lib/x86_64-linux-gnu/pkgconfig/` returns nothing. The path was baked into the stale
cache's `GTK_CFLAGS` and CMake validates an imported target's include directories at
*generate* time, so a header with no relationship to the code blocked the build.
Deleting `build/linux/x64/{debug,release}` fixed it. The remedy for a missing toolchain
was therefore not one `apt install` but *that* plus a wipe — which is not something a
reader can infer from the error text.

`tool/verify_linux_build.sh` replaces the bare build with four steps: `flutter doctor`,
the four tools `doctor` does not check (`clang`, `cmake`, `ninja`, `pkg-config`), a
wipe of `build/linux/x64/*` so CMake **must** regenerate, and the timestamp assertion.

**AND TWO OF THE SCRIPT'S OWN BUGS ARE THE POINT OF THE TWO ABOVE.**

Its first version matched the doctor's status line with `^\[.\] Linux toolchain`. The
glyph is `✓` — **three bytes of UTF-8** — so `.` matches one *byte* under the C locale
and the pattern never matched. The script then reported `FAIL` on a perfectly healthy
toolchain, which is the safe direction, but it was wrong for a reason invisible in the
pattern. The check now matches `Linux toolchain` and compares the glyph as an explicit
`printf '\xe2\x9c\x93'` / `\xe2\x9c\x97'` byte pair.

**AND STEP 4 WAS UNREACHABLE, PROVED BY A MUTATION THAT "FAILED" TO FAIL.** The
timestamp comparison sits after a step that deletes `build/linux/x64/*` and rebuilds, so
the bundle is always fresh by the time it runs — a check that cannot fail is not a
check. Setting the bundle's mtime to 2020 and running the whole script returned
**PASSED**, because step 3 relinked it first. So the script takes `--check-only`, which
skips the build, and the negative control passes: a 2020 bundle now fails with

```Text
FAIL: the bundle is OLDER than the newest Dart source.
      bundle:     2020-01-01 00:00:00
      newest src: 2026-10-06 20:25:06  lib/features/leaderboard/presentation/pages/leaderboard_page.dart
```

A gate added to stop a false green, itself shipping a false green and an unreachable
assertion, is the strongest argument this file has for mutation-testing the gates.

**143. THE LEADERBOARD IS **NOT** EMPTY IN DEVELOPMENT, AND I SAID IT WAS — TWICE.**

Decisions 136 and 138, and both of my commit messages for Phase 1, rest on this claim:

> "scores only enter Redis via `recordScore`, called on a *successful* submission, and
> submission cannot succeed against the memory fallback … the empty board is currently
> the **only** reachable state"

**It is false.** `InMemoryRedisFallback`'s **constructor** pre-seeds the ZSETs
(`src/redis/client.ts:5-33`):

```ts
constructor(seed: boolean = process.env.NODE_ENV !== 'test') {
  if (!seed) return;
  // Pre-seed sample weekly, monthly, and all-time scores for Group 3 demo
  const seedUsers = [
    { id: '2222…', score: 80 },   // Peter George (Grade 6)
    { id: '1111…', score: 50 },   // David Mina (Grade 5)  ← the seeded identity
    { id: '3333…', score: 30 }    // Mark Anton (Grade 5)
  ];
  … `leaderboard:group:3:{weekly,monthly,all_time}`
}
```

Measured against a `npm run dev` server:

```json
{"group_id":3,"window":"weekly","total_ranked":3,"my_standing":{"rank":2,"score":50},
 "leaderboard":[{"userId":"2222…","score":80,"rank":1,"full_name":"Peter George (Grade 6)","current_streak":7}, …]}
```

Three rows against `limit=50` ⇒ `rowsReturned < limit` ⇒ **`cohortSize` is 3**, and the
card prints `2 / 3` off live data. That is precisely the case decision 136's rule exists
for, and I had written the rule while asserting it could not yet be observed.

**HOW THE FALSE CLAIM GOT IN, WHICH IS THE PART WORTH KEEPING.** The first probe in this
phase returned `{"total_ranked":0,…}`. I took that one response as the endpoint's
behaviour and **never re-probed**, because the argument built on it was already written
and re-reading it would have cost more than one `curl`. A single observation became a
permanent property of the backend in three commits and in this file.

The likely explanation is `NODE_ENV`: the seed is skipped **only** when it is exactly
`test`, so any process started that way — a test harness, a CI shell, an earlier
`NODE_ENV=test npm run dev` — answers empty, and one such process is enough to make
"always empty" look true.

**THE RULE THAT FOLLOWS, AND IT IS NOT SPECIFIC TO LEADERBOARDS:** an empty response is
a **fact about a process**, never a property of a system. Before writing "this endpoint
cannot return X", the claim needs a second observation from a **restarted** server, and
the restart condition has to be stated. Every other live measurement in this file —
`current_streak` 4-vs-0, the mixed key casings, the `window` 400, the missing
`x-group-id` — was taken from source or from a re-probe, and those still hold.

**WHAT SURVIVES UNCHANGED, WHICH I CHECKED RATHER THAN ASSUMED.** The three dropped
fields (`full_name`, `current_streak`, `userId`) were dropped on *structural* grounds and
the payload still carries all three. `total_ranked` is still `enrichedEntries.length`, and
`cohortSizeOf` is still correct on this body: `3 > 3` is false, `3 < 50` is true, so the
answer is `3`. The `ZCARD` no-op claim is unaffected — it is a statement about what
happens when `total_ranked` starts exceeding the row count, and that is still unobserved.

**AND THE STUB IS STILL WORTH HAVING, FOR A REASON I HAD THE WRONG VERSION OF.** The seed
is **group 3 only**, it is **frozen** — no score can move without a working submission
path — and so the reader is permanently rank 2. The states worth reviewing (a rank
*dropping*, a tie, `rank: null` unranked, a cohort larger than `limit`) are all
**unreachable** from the seed. That is the honest justification, and it is a different
one from the one I shipped.

**144. `LeaderboardCard` WAS NEVER RENDERED, AND `5f53eb5` SAID IT WAS.**

`5f53eb5`'s message claims "leaderboard card → Home". It did not. `LeaderboardCard` was
written, given a DI seam, a five-surface overflow matrix and a 21-test view suite — and
**no page instantiated it.** `HomeBloc` fetched `LoadLeaderboardPreview` on every load,
`HomeState.leaderboard` held the answer, and `HomePage` dropped it.

Every §7 gate was green throughout. The reason is worth recording, because it is not a
gap any of the gates was looking for:

* `home_page_test.dart` asserts the greeting, the wordmark, the flame and the panel. It
  never asserted **which sections `/` has**.
* `leaderboard_view_test.dart` proved the card renders — by instantiating it directly.
* `home_bloc_test.dart` proved the bloc fetches it.

A widget no page instantiates is exercised perfectly well by a test that instantiates
it, and a state field nothing reads is written without complaint. **The two halves were
each verified and the join between them was not.** The missing thing is not a gate, it
is one assertion: `leaderboard_on_home_test.dart` says the card is in `/`'s tree, in
order, drawing the rows the bloc fetched. When it was written it failed with
`Found 0 widgets with type "LeaderboardCard"` while the companion assertion on the
*request* (`limit: 50`, `window: weekly`) passed — which located the defect to rendering
alone, with the data path already proven.

**THE LESSON IS ABOUT WHAT A SUITE CANNOT SEE.** Three suites, all green, all correct
about their own subject, and together they could not tell whether the feature shipped.
A "does the screen have this section" assertion is the cheapest test in the package and
the only one that notices a whole component class being orphaned.

**145. THE CARD GOES BELOW TODAY'S READING, AND HOME GETS NO STAT TILES.**

Both are product decisions, taken by the user rather than inferred:

* **Below the reading.** Today's reading is what the reader came to do; a rank is a
  reward glance taken afterwards. Above, the card pushes the reading panel toward the
  fold on 320×568, the smallest supported surface. Reused `HomePage.panelGap` rather
  than inventing a second number for the same visual relationship.
* **No stat tiles on Home.** The prototype puts `StatTile` on `ProfileScreen` and
  `ResultScreen` and **nowhere else** — `HomeScreen.tsx` has none. And `ProfileScreen`
  is a cut screen: the backend has no profile/stats module (`admin, ai, leaderboard,
  readings, streak, submissions`). So "stat tiles on Home" traces back to a screen that
  does not exist, and the figures would have had to be invented. Nothing is missing:
  the streak is in the subtitle and the reader's rank is now in the card directly below.

`StatTile` stays used on `/result` only, which is where the prototype puts it.

**146. PLACING THE CARD EXPOSED ARABIC TOFU ON THE SCREEN EVERY READER LANDS ON.**

`arabic_typography_test.dart` failed the moment the card entered `/`, and its output
named the families rather than the symptom:

```Font
SpaceMono   هذا الأسبوع
DMSans      غير مصنّف بعد
DMSans      لا توجد نتائج بعد
DMSans      عند بدء إجابات المجموعة سيظهر الترتيب هنا.
```

Four strings in Latin-only faces. `monoCaps` is `SpaceMono` and `titleMedium`/`bodyMedium`
/`bodySmall` are `DMSans`; neither carries Arabic, so each was one box per character.
`LeaderboardRowTile` already resolved both its runs through `arabicAware` — decision 84's
argument — but `_Header`, `_EmptyStandIn`, the page's heading and `_StandingFooter` did
not, because **they were never built, only tested**. Testing a widget in English never
renders a glyph the face lacks.

This is the same defect decision 84 records for `StatTile`, found again by the same
mechanism, and it is the strongest argument in this file for the Arabic gate existing at
all: it fires on the **first screen the component reaches**, not on the screen someone
remembered to check. Four runs now resolve through `arabicAware`, and the five new
strings are declared in `expectedArabic` for both the ready and failed Home arms — the
card renders independently of the reading, so its strings are present even when the
reading panel is an `ErrorView`.

**147. `ink3` FAILS CONTRAST AS TEXT, IN BOTH THEMES, AND NO GATE LOOKS.**

Measured, WCAG 2.1 relative luminance against `glassFill` (`#0DFFFFFF`) composited over
each theme's `canvas`:

| run | on dark glass | on light glass |
| --- | --- | --- |
| `ink` `#EAE8F5` / `#120E28` | **14.95:1** | **16.56:1** |
| `ink2` `#8A8FAD` / `#5A5480` | **5.70:1** | **6.15:1** |
| `ink3` `#424669` / `#9B97B8` | **1.99:1** | **2.47:1** |

`ink3` fails even the **3:1 large-text** floor, let alone 4.5:1 for body text, and it is
used as a text colour in **15 runs across 13 files** — the leaderboard card's title, every
row's rank column and "points" label, `StatTile`'s caption, `EvaSectionHeader`,
`EmptyState`, `EvaTextField`'s hint, `StickyCta`, `ReadingHeader`,
`TodayReadingPanel`, `PasswordVisibilityToggle`, `FontSizeStepper`, and the leaderboard
page's unranked line. There is **no contrast gate anywhere in `test/`**.

**This is reported, not fixed, and the reason is that the fix is a redesign.** Every one
of those 15 runs is a transcription of `T.ink3` in `ds.tsx`, so changing them means
restyling the app's entire secondary-text level — which is a different task from placing
a card, and would replace rather than refine. It also needs a decision this repo has no
default for: raise `ink3` toward `ink2` (one token, 15 sites fixed, the prototype's own
`T.ink3` no longer matched) or leave the palette and demote `ink3` to hairlines only,
promoting those 15 runs to `ink2`. The first is a one-line change with a visual
consequence across every screen; the second is a deliberate deviation from `ds.tsx`. Both
belong to the user.

**148. `GlassSurface`'s RIM **AND** SHADOW ARE THE PROTOTYPE'S, NOT A GHOST CARD.**

An external craft floor asks that elevation be declared once, calling a 1px border under
a wide soft shadow a "ghost card". `GlassSurface` does both, and that is not the defect
the phrase describes — the prototype's passage card wrote the rim (`1px solid rgba(…,
0.08)`) **and** the shadow (`0 4px 24px rgba(0,0,0,0.35)`) **and** `backdropFilter:
blur(20px)` on the same element. In a glass idiom the rim is what makes the surface
legible against a busy
background and the shadow is what lifts it off the canvas; they are not two competing
elevations. A committed world overrides a category default, so this stays.

**149. `ink3` IS DEMOTED TO THE TWO THINGS WCAG EXEMPTS, AND 21 RUNS MOVED TO `ink2`.**

Decision 147 reported `ink3` at **1.65:1 on dark glass / 2.02:1 on light glass** — below
even the 3:1 large-text floor — colouring 21 text and icon runs. The chosen fix was the
conservative one: **leave the token alone, move the runs.** `ink3` keeps its value; its
documented role narrows to the two cases WCAG 1.4.3 exempts **by name** — inactive
components and pure decoration.

**AND THE REPO HAD ALREADY DECIDED THIS, WHICH IS WHY IT WAS CHEAP.** `eva_colors_test.dart`
carries a test called *"the WCAG-exempt pairings are exempt by name, not by
convenience"*, which declares `ink3` the **disabled ink** (it is `ThemeData.disabledColor`)
and asserts it must stay **sub-AA** — "if it clears AA, that exemption is no longer the
reason it passes." So `ink3`-as-disabled-ink was the recorded position all along; 21 runs
were using a disabled-ink token for live content. Nothing about the palette changed.

Promoted to `ink2` (worst surface: **4.73:1 dark, 5.02:1 light** — clears 4.5:1 in both):

| widget | what moved |
| --- | --- |
| `leaderboard_row_tile` | rank column, "points" label |
| `stat_tile` | caption |
| `eva_section_header` | the header label |
| `segmented_control` | unselected segment label |
| `eva_chip` | unselected chip label |
| `font_size_stepper` | the "A" preview |
| `eva_text_field` | helper text, and the reveal-icon `IconThemeData` |
| `empty_state` | the state icon (WCAG 1.4.11, 3:1 for meaningful icons) |
| `leaderboard_card` | title, empty-state body |
| `today_reading_panel` | status eyebrow, "no questions today" |
| `app_top_bar` | the wordmark's gradient end-stop |
| `reading_header`, `sticky_cta`, `result_page`, `settings_page` | metadata and captions |
| `password_visibility_toggle` | the eye icon |

Left on `ink3`, each with its exemption named:

* `eva_text_field`'s `foreground: enabled ? ink : ink3` — inactive control, 1.4.3.
* `icon_action_button` and `eva_theme.disabledColor` — inactive controls.
* `hairline_divider` — a separator carrying no information.
* `eva_chip`'s `dot` — decoration.
* `eva_theme`'s `outline` — a border that conveys no state.

**150. CONTRAST IS NOW A GATE, AND THE LEDGER IS MEASURED, NOT TYPED.**

`test/core/design_system/tokens/text_contrast_gate_test.dart`. Two halves, and they
**bracket the palette against `eva_colors_test.dart`'s existing one**:

* that test asserts `ink3` and `line` stay **sub-AA** — the exemption premise;
* this one asserts `approvedForText` (`ink`, `ink2`) clears **4.5:1 on every surface in
  both themes** — and requires the *worst* surface, not the nominal one.

That last requirement is the whole gate. Checking each token against `canvas` reports
`ink2` at 6.26:1, which reads like a pass; `GlassSurface` composites `#0DFFFFFF` over
whatever is beneath, so a run on a card sits on a **lighter** surface and the real number
is 4.73:1. A token that passes on `canvas` and fails on glass is the common failure,
because glass always moves a dark theme lighter.

**AND THE FIRST VERSION OF THE LEDGER WAS WRONG IN EVERY ENTRY.** I computed it by hand
against `canvas` and `glass/canvas`; the gate disagreed with all of them. The worst
surface is `glass/raised` in **both** themes, and in light `glass/raised` is *lighter*
than plain `raised`, so it wins by more than rounding — `ember` in light came out 2.30 by
hand and **2.05** by measurement. A contrast number nobody re-derives from the token
table is a number that drifts, and the tokens are what changed, not the arithmetic. The
ledger now carries a comment saying so, and every value in it was read out of the gate.

`knownSubstandard` cannot **grow** (a new illegible pair fails) and no recorded ratio can
**change** (quietly darkening `ember` to "improve" it fails too). A gate with an unbounded
allowlist is a gate with no allowlist. Four mutations confirm each assertion bites:
darkening `ink2`; making `composite()` ignore alpha; deleting a ledger entry; and
promoting `ink3` into `approvedForText` without fixing it.

Anchored against WCAG's own examples so a bug in `_luminance` cannot make the file pass
for the wrong reason: black/white is 21:1, white/white is 1:1, and `#767676` on white is
4.54:1. Compositing is done in **8-bit with the compositor's rounding**, because measuring
in float would report 12.75 for a pixel that is 13.

**AND A HEX-SHAPED LITERAL READS AS A FRACTION ONLY TO THE AUTHOR.** The rounding test
first read `composite(0xFFFFFFFF, 0xFF000000, 0x05)` — `0x05` is the **integer five**, so
alpha arrived as 5.0, every channel clamped, and the helper returned opaque white. The
comment in the file now names the trap.

**151. `ember`, `ok` AND `err` AS TEXT ARE UNRESOLVED, AND `ember` IS THE READER'S OWN NAME.**

The gate's ledger is what surfaced these, and they are worse than `ink3` was:

| token | worst surface (light) | used as text for |
| --- | --- | --- |
| `ember` | **2.05:1** | the reader's name in the greeting on `/`, `leaderboardYourRank`, the reader's row |
| `ok` | 3.03:1 | correct answers |
| `err` | 3.33:1 | incorrect answers |

`ember` in the light theme is the **greeting**: `Good morning, <name>` with the name in
ember, at 2.05:1. That is the app's warmest moment and it is illegible in one of its two
themes. `ok` and `err` sit between 3:1 and 4.5:1, which is why nothing caught them by eye
— they read as "dimmed" rather than "broken".

All three pass in **dark** (6.97 / 7.50 / 5.41), so this is a light-theme problem and the
fix is not "make ember darker" — that would break the dark arm, where it is comfortable.
The candidates are a **light-only accent token**, promoting text uses to `ink`/`ink2` and
keeping `ember` for fills and glyphs, or accepting it as a documented theme asymmetry.

**Not taken here.** All three are in the ledger, so none of it can regress unnoticed and
none of it can be quietly edited. `ember` is the brand accent and changing it is a
different decision from changing a disabled ink — it is the user's, and it should be made
with the light theme on screen.

**152. FIFTEEN GOLDENS CHANGED, AND EVERY ONE IS A TEXT OR ICON BAND.**

The `ink2` promotion broke 18 tests: 4 that assert a token **by name** and 14 goldens.
The by-name assertions were *correct to break* — `StatTile`'s caption, `EvaSectionHeader`'s
label and the chip's foreground were pinned to `ink3` deliberately — and their names and
reasons were rewritten rather than their values silently swapped.

The goldens were regenerated, and because "regenerate the goldens" is exactly the move that
can hide an unintended change, the result was verified rather than trusted:

* **15** files changed, **0** new files. All 15 belong to the 7 widgets the promotion
  touched (`settings_group` transitively, because it embeds an `EvaSectionHeader`).
* Pixel diffs against `HEAD`: **0.12%–0.42%** of each frame, each inside an 8px-tall text
  band or a 34×33 icon box. **No bounding box moved and no image changed size**, so the
  change is colour-only and nothing reflowed.

A colour-token change should produce exactly this signature: tiny, bounded, and confined
to the runs that were recoloured. A golden diff that moved a layout edge would have meant
something else had changed, and would have been caught here rather than merged.

**153. THE ACCENT SPLITS INTO A FILL AND AN INK, AND ONLY THE LIGHT VALUES DIFFER.**

The answer to "can dark and light have different values?" is that they **already did** —
`EvaColors.dark()` and `EvaColors.light()` are two independent sets, and light `ember` was
already `#D4891A` against dark's `#E8A33D`. The problem was never a shared value. It is
that **the light value itself is wrong for the job it was doing**, and one value cannot do
two jobs that pull opposite ways:

* as a **fill**, `ember` must stay light enough that `onEmber` reads on it — an
  `EvaButton`'s entire label is `onEmber` on `ember`;
* as **text** on a pale surface it must be dark enough to clear 4.5:1, and light `ember`
  measured **2.11:1**.

There is no single value that does both. Darkening `ember` to reach the text floor gives
`#8E5B11`, and `onEmber` (`#3A1E00`) on that is **2.70:1** — the button label becomes the
illegible thing instead. That is not a tuning miss; it is two contradictory requirements
on one token, and it is why "just darken it" was never the answer.

So the accent gets two names per role, and **only the light values differ**:

| token | dark | light | used for |
| --- | --- | --- | --- |
| `ember` | `#E8A33D` | `#D4891A` | fills: buttons, chips, beads, toggles, flame, cursor, glows |
| `emberInk` | `#E8A33D` | **`#845610`** | text, drop caps, verse numbers, meaningful icons |
| `ok` / `okInk` | `#4ECCA3` | `#1A8C6A` / **`#146C52`** | fills / correct-answer text |
| `err` / `errInk` | `#FF6B6B` | `#D63B3B` / **`#B72626`** | fills / error text and icons |

**In dark the pairs are identical on purpose.** The accent already clears 6.97:1 there and
nothing is being solved, so a second name would be a second way to change the same thing.
The **three light goldens are the proof**: switching the ink usages moved `eva_chip_toggle_light`,
`segmented_control_light` and `eva_button_ghost_light`, and **every dark golden stayed
byte-identical**. A token pair that is equal in one theme and different in the other
cannot accidentally change the theme that was already right.

20 usages moved: the greeting's reader name on `/`, `TextLink`, the selected segment and
language pill, the selected chip label, both drop caps, the verse-number `<sup>`, the
quiz question label, the leaderboard row's rank / initials / score and the "You" label,
the ghost button's chevron, the error copy on `/login`, `/settings` and every text field's
error arm, `ErrorView`'s icon, and the quiz option accent. **44 fill usages were left on
the fill token** — the flame painter, the toggle knob, the cursor, progress beads, chip and
pill borders, avatar rims and every glow. The split is by role, not by widget.

**154. MY CONTRAST GATE MEASURED THE DARK THEME'S GLASS IN THE LIGHT THEME.**

Two bugs, both mine, and the second one is the interesting kind.

The gate composited `glassFill` over each surface to model `GlassSurface`. It hardcoded the
alpha as `0x0D / 255` — which is the **dark** theme's fill, a 5% **white** overlay. Light's
is `Color(0x0A000000)`, a 4% **black** overlay. So the two themes disagree about the
**direction** glass moves a surface, not merely the amount: compositing white at 5%
*lightens* `#E8E4FF`, while composposing black at 4% *darkens* it to `#DFDBF5`.

**That made the gate clear values the screen never renders.** With the wrong alpha, light
`glass/raised` measured lighter than any real light surface, so the gate reported
`emberInk` at **4.69:1** where the real surface measures **4.18:1** — and the ink values I
had just computed from a spreadsheet passed a gate that was measuring the wrong pixels.

The fix reads the alpha off `colors.glassFill` rather than assuming it. Three rounds of
"compute by hand, be contradicted by the gate" produced values I was confident about and
which were wrong, and the third round was wrong **because the gate itself was wrong** —
which is the point at which the spreadsheet stopped being evidence.

**AND THE DRIFT ASSERTION CAUGHT THE CORRECTION.** Fixing the alpha moved four ledger
entries — `ink3` 2.02→**2.08**, `ember` 2.05→**2.11**, `ok` 3.03→**3.12**, `err`
3.33→**3.43** — and `no recorded ratio has drifted` failed on every one. A ledger is only
worth having if it notices when the *measurement* changes underneath it, and that is
precisely what happened: no token moved, the surface model did.

Four new mutations confirm the added assertions bite: reverting light `emberInk` to the
fill value; hardcoding the dark alpha again; making **dark** `emberInk` diverge from dark
`ember` (15 failures — the dark arm is now covered too); and promoting a fill token into
`approvedForText`. Three light goldens updated, diffs **0.06%–0.14%** each, bounded to the
accent run — the chip label, the segment label, and a 13×12 chevron.

**AND A THIRD OF THE GATE'S FAILURES WERE FOUND BY THE GATE.** `ink3` was reported
(147) by reading the palette by hand. `ember`, `ok` and `err` were found by the ledger
asserting that no sub-AA pair had gone unrecorded. The hand-read found the first defect;
the mechanical check found the next three.

**155. `SealFab` COMES BACK TO `/` — TWO ITEMS, THEN THREE, AND FOUR GATES ARGUED
ABOUT IT.**

The prototype's `SealFAB` defined a 56×56 glass circle carrying the display-serif `E`,
outlined in ember, expanding into pill destinations, and placed it `bottom: 28,
right: 20` on the home screen and **nowhere else**. It was cut, and the reason was sound: its menu
was Profile, Settings and Language, and by then Profile had no endpoint, Settings was
already the avatar's job on `/`, and Language was already a row inside `/settings`.

**AMENDED IN TASK 5.6: THE DIAL HAS THREE ITEMS, AND THIS DECISION NAMED THE WAY.**
This decision names two ways to get a third item back — further down: "promote
`language_sheet.dart` into the shared kernel … or give `/` another live route" — and
says neither is taken, so **the second one was taken**. Task 5.6 gives `/` another live
route: `/journey`, the profile ADR-0001 cut and ADR-0022 restored. The redesign makes
that screen a **dock tab** (`eva/redesign.html:707`), and the dock is Phase 6's, so the
dial is the interim holder of the destinations Home cannot otherwise reach — which is
what the dial already was, and it already held the **board**, the prototype's other
dock tab (`:706`).

**The label is "Journey", not "Profile".** The redesign renamed the screen
(`eva/redesign.html:933`), so the dial offers the journey and the "Profile stays
absent" assertion in `seal_fab_test.dart` still holds: the *name* the cut screen had
is still absent, and the screen itself is here under the name the redesign gives it.
The assertion was **updated, not deleted**, and it now also asserts that the journey
item is present and navigates.

**LANGUAGE IS STILL ABSENT, and the first of the two ways was not taken.**
`showLanguageSheet` is still in `features/settings/`, and there is still deliberately
no `sealFabLanguage` key — a getter with no call site is a string in the bilingual
surface no reader can reach.

**AND THE PREMISE THIS DECISION WAS WRITTEN ON HAS ROTTED, WHICH IS WHY THE AMENDMENT
IS HERE AND NOT A QUIET EDIT.** The paragraph above says "Settings was already the
avatar's job on `/`" — and the avatar **no longer exists**: Phase 5.2 rebuilt `/`
against the redesign, and the redesign's `/` (`eva/redesign.html:513-538`) has **no
app bar and no avatar** at all. The `AppTopBar` this decision's reasoning was written
against is gone from `lib/`, and the dial is now the only way Home reaches Settings
and the board. A decision that names a screen's chrome has to be re-read when that
screen's chrome is rebuilt, and this one had not been.

**TWO ITEMS, NOT THREE, AND GATE 2 IS WHY.** The third destination would be Language, and
`showLanguageSheet` lives in `features/settings/` — so the import was written, and
`injection_test.dart` Gate 2 named it: *"a feature depends on the PORTS only, and
`lib/app/di/` is where an adapter is chosen."* It was removed rather than suppressed, and
**there is deliberately no `sealFabLanguage` key**: a getter with no call site is a string
in the bilingual surface no reader can reach. Leaderboard took Profile's slot, because it
is the one prototype destination with **no other entry point on `/`**.

The two ways to get a third item back are both larger than placing a dial, so neither is
taken: promote `language_sheet.dart` into the shared kernel — it is app chrome rather than
settings, and this FAB was its **original** entry point before it was cut — or give `/`
another live route. Both are the user's.

**`NeuralScaffold` GAINS `overlay`, AND THE GATE THAT FORCED IT IS THE REASON IT IS
SAFE.** The content is inside a `SingleChildScrollView` on five of six screens, so a
caller placing a floating control in its own column produces one that **scrolls away** —
which is not a floating control. The `Stack` this widget already owns is the prototype's
`position: absolute; inset: 0` container — and the redesign's own canvas layer has
exactly that shape (`redesign.html:46`) — so the overlay is the shape the
prototype had rather than a mechanism invented for Flutter. It sits **after** the content
and **before** `bottomFade`'s scrim, so a scrolling screen's CTA gradient still covers a
bottom-right overlay. `null` on the five screens that have none.

**§13.4's BLUR BUDGET IS ONE SITE PER SCREEN, AND `/` HAS SPENT IT.** The prototype blurs
the dial at `blur(20px)` and the pill at `blur(16px)`. Both are dropped, and the gate
refused twice: first for two raw `BackdropFilter`s, then for two *accounted*
`GlassTier.blur` ones. A `BackdropFilter` is a save layer, two more on the screen a reader
spends the most time on is a real price on low-end hardware, and §13.4 is a decision with
a number in it rather than a preference. The dial reads as glass from what remains — a
translucent fill, the prototype's hairline rim, the ember bloom — and costs no save layer.
**Raising the budget to three was available and not taken:** a floating affordance is a
poor reason to spend it on.

**THE PROTOTYPE'S 40ms STAGGER IS NOT REPRODUCED.** The prototype's dial wrote
`screen-in 200ms ease-out ${i * 40}ms both`. Reproducing it needs a **delay**, and
`EvaAnimate` has none by design — its doc says timings are the enum's job and "there is no
`duration` or `curve` argument anywhere below, so a literal cannot reach an effect even by
accident." A per-index delay is `40ms * i` at a call site. So the pills run
`MotionMoment.screen` together: one authored moment, and three pills at once reads as one
control opening where three 40ms apart read as a sequence.

**AND THE SEMANTICS STORY HAD THREE FALSE STARTS, ALL RECORDED IN THE CODE.**

* *The label.* The prototype gives the trigger **no** accessible name — its content is the
  letter `E` — which is the defect `SegmentedControl`'s track shipped with. Declared.
* *`container: true`.* Added while chasing the next fault, which turned out to be
  something else entirely. **Deleting it leaves every test green**, so the comment now
  says so and gives the honest defensive reason instead of claiming a test caught it.
* *The real fault.* `EvaAnimate` sets its controller to `0.0` and calls `_play()` from a
  **post-frame callback**, so the frame that creates a pill draws it at **opacity 0** — and
  `RenderOpacity` **drops semantics for a fully transparent subtree**. A hand-counted
  three-pump sequence found nothing and a four-pump one found everything, because each
  `pump(duration)` lands on the controller's *first* tick rather than advancing past it.
  The same widget needed four pumps under a bare `SealFab` and **five** under `/`. The
  test now uses a bounded loop that states the claim ("the animation finishes") instead of
  a magic count that passes for the wrong reason on a different frame budget.
  `pumpAndSettle` is **not** the answer here: `/`'s orbs animate forever, so it times out
  with a message about the background rather than the dial.

**AND TWO OF MY OWN MUTATIONS SURVIVED THE FIRST VERSION OF THIS TEST.** `semanticsOf(…)`
resolves to whatever node the tree merged the trigger into, so it reported a non-empty
label even with the label deleted; the assertion now reads `Semantics.properties` off the
widget. And the "pill's label deleted" mutation needed the **text kept and the label
removed** to be the interesting case — a pill that still reads "Settings" on screen and
is anonymous to a screen reader is precisely the defect §14 is about.

`seal_fab_test.dart`'s first assertion is deliberately `find.byType(SealFab)` on `/`. That
is not boilerplate: `5f53eb5`'s "leaderboard card → Home" was claimed and the card was
never rendered, and **a component that is built, tested and never placed is invisible to
every assertion that does not look for it on the screen.**

### Recorded decisions — the whole-state writers audit

**156. THE `@Freezed(copyWith: false)` DECISION IS APPLIED WHERE THE STATE IS
LARGEST, AND IT IS NOT RE-EXAMINED AS THE STATE GROWS.**

Recorded, **not reversed**. Nothing here changes behaviour, and nothing here says the
pattern is wrong — it says it was decided for one shape of state and inherited by every
feature that added a field.

**The audit.** Six state classes exist (`lib/features/result/` has no bloc —
`ResultPage` takes `SubmitResult` as a constructor argument). `copyWith` is disabled on
the three largest and kept on the three smallest:

| state | fields | `copyWith` | alternative in use |
| --- | --- | --- | --- |
| `HomeState` | **13** | disabled `home_bloc.dart:418` | 6 named `with*` writers, each restating all 13 |
| `AuthState` | **10** | disabled `auth_bloc.dart:239` | 2 writers + a **hand-rolled** `copyWith` `auth_bloc.dart:366` |
| `QuizState` | **5** | disabled `quiz_bloc.dart:213` | inline full constructors, 11 sites |
| `LeaderboardState` | 4 | generated — **zero call sites** | inline full constructors, 3 sites |
| `ReadingState` | 4 | generated ✅ | `copyWith` |
| `SettingsState` | 3 | generated ✅ | `copyWith` |

Two facts that are not argument, only observation: `AuthState` hand-rolls a partial
`copyWith` to get part of what disabling it removed, and `LeaderboardState` carries a
generated `copyWith` that **no call site in `lib/` or `test/` reaches** — the cubit
builds all three of its states through the constructor.

**THE JUSTIFICATION IS REAL AND IT IS NARROW.** Decision 141 records it for `HomeState`:
four independently-failing backend endpoints, each a `status · payload · failure` triple
that must stay mutually consistent. A generated `copyWith` **can** clear a nullable
field — freezed gives every nullable a `freezed` sentinel default, so `null` means
"clear this" and the sentinel means "keep current" (`settings_state.freezed.dart:71`) —
but it **cannot** express the invariant. `state.copyWith(readingStatus: failed,
readingFailure: f)` leaves `reading` holding its old value, so the triple disagrees with
itself; `withReading` forces the caller to state all three.

**That justification does not reach the other two states.** No cross-field invariant is
recorded for `QuizState` or `AuthState` anywhere. Decision 141 is about `HomeState`,
and its argument was inherited rather than re-argued — which is the shape this file
records a dozen times elsewhere.

**THE RULE THAT FOLLOWS.** A rule that grows more expensive as the thing it governs
grows should be re-examined whenever the thing grows. The cost here was accepted when
`HomeState` was small, and then carried by every feature that added a field.

**NOT FIXED HERE.** Re-enabling `copyWith` on `QuizState`/`AuthState`, deleting
`LeaderboardState`'s dead one, and dropping `AuthState`'s hand-rolled one are each
defensible, and each is a refactor needing its own decision and tests — not a drift fix
applied silently to a pattern 2541 tests currently agree on. See `docs/DRIFT.md` §6.

---

### Recorded decisions — the Lumen redesign, Phase 7 (the ritual)

Shipped on `feat/navigation-dock`. **3691 tests, 98.83% coverage.** The phase's full
decision log lives in `docs/superpowers/plans/2026-10-13-lumen-redesign.md`'s Phase 7 —
that plan is where the Lumen phases record theirs, and this file carries only the
**invariants** a sub-agent must not violate. Read the plan section before touching the
ritual, the ambient or the witness sky.

**157. THE RITUAL'S ARITHMETIC IS PURE DART, AND THE FIVE FILES THAT HOLD IT ARE
NAMED.**

AGENT_CONTEXT §6 splits a decoration's **arithmetic** (domain) from its **clock**
(widget). Phase 7 is the first phase to have five decorations at once, and the split is
load-bearing rather than tidy — a widget that computed a countdown inline would be
untested logic wearing a `build` method, which is exactly what §6 names.

| behaviour | the arithmetic | the clock |
| --- | --- | --- |
| the selah countdown | `core/domain/entities/selah_countdown.dart` | the card's own `Timer` — `features/home/presentation/widgets/selah_card.dart:191`, **cancelled on dispose** |
| the vespers auto-dim | `core/domain/entities/vespers.dart` | the **injected** wall clock — see 158 |
| the breath guide | `features/reading/domain/breath_guide.dart` | the line's own controller |
| the haptics | `core/domain/entities/ritual_haptic.dart` | `core/design_system/effects/ritual_haptics.dart` — the only file that calls the platform |
| the shared breath triangle | `core/common/cycle_phase.dart` | the two callers' own controllers |

**The triangle is ONE number, and the curve is not in it.** The selah's ring
(`eva/redesign.html:269-270`) and the breath guide (`:174-175`) declare the same keyframes
at 0%, 50% and 100%, so they breathe on the same shape — `core/common/cycle_phase.dart`
owns the arithmetic, because two spellings of one number is what this repository refuses.
The **curve** stays with the widgets: Flutter's `Curves.easeInOut` **is** CSS's
`ease-in-out` (`Cubic(0.42, 0.0, 0.58, 1.0)`), so applying it is a presentation concern
and the file is Flutter-free by construction.

**The timer is the card's, and a leaked timer is a hung suite.** This repository has one
of those recorded. A `Timer` in a `StatefulWidget` is cancelled in `dispose`, always.

**158. THE AMBIENT READS AN **INJECTABLE** CLOCK, AND A RULE THAT READS THE WALL CLOCK
IS A RULE WHOSE OUTPUT DEPENDS ON WHEN IT WAS ASKED.**

The vespers auto-dim made the ambient's **target** a function of the wall clock, and the
**sixteen background goldens** (eight screens × two themes) would have **passed at 09:00
and failed at 22:00**. Sixteen goldens whose result depends on the hour the suite ran in
are sixteen goldens that cannot be compared across two commits, which is the only reason
a golden exists.

So `NeuralMotionScope` takes a `now`
(`core/design_system/effects/neural_motion.dart:314`, `:376`), `LumenScene` takes one too
(`core/design_system/effects/lumen_scene.dart:163`, `:195`), and the harnesses pin it —
`test/support/design_system_harness.dart:72` and `:346`,
`test/support/home_harness.dart:648`, both at `DateTime(2026, 10, 3, 9, 30)`. The two
vespers tests that need the night ask for it explicitly
(`test/core/design_system/effects/lumen_scene_test.dart:143`, `:183`).

**The rule for the next reader: a golden's subject must not be a function of the hour.**
The same discipline killed the focus dim's unwired 4-second literal in favour of the
reader's own `UserSettings.focusDelaySec`. If a new feature reads the wall clock, it must
read it through an injected seam, and the harness must pin it.

**159. THE HAPTICS' **RHYTHM** IS LOST, AND THE **PEAK** DECIDES.**

The prototype's `haptic(p)` is `navigator.vibrate(p)` (`eva/redesign.html:914`) — a
duration, or a list of durations. Flutter's `HapticFeedback` has **no pattern API**: four
*named* impulses and a `vibrate()` that asks the platform for its *default* vibration. So
a duration must become a name, and the rule is **magnitude** — 10–12 ms is a click,
15–25 ms a bump, 30 ms a firm bump, 40 ms and above a buzz. The prototype's two rhythms
(`[30,40,30]`, `[40,60,40]`) both peak above 30 ms and both become **one heavy impact**.

**The strength survives; the rhythm does not**, because §8.4 forbids the dependency that
would carry it. **A per-call-site table is forbidden**: it would be a second table of the
same thirteen moments, and the two would drift. `RitualHaptic` is the vocabulary and
`hapticImpactFor` is the single mapping — a new haptic is an **enum member**, never a
literal at a call site.

**160. THE ORPHAN GATE'S INVENTORY IS **ALL OF `lib/`**, AND THE REASON IS A GATE THAT
COULD NOT SEE A THIRD OF THE DESIGN SYSTEM.**

`tool/gates/orphan_widget_check.py` built its inventory from the files under
`*/widgets/` only:

```python
if "/widgets/" not in p.as_posix():
    continue
```

so a widget under `core/design_system/effects/`, `.../motion/` or `.../tokens/`
was **not in the set the gate reasoned about at all** — not reported and passed over,
but *invisible*. Three widgets were built, exported, fully tested and placed on
**nothing**: `GoldFlecks`, `EvaAnimate` and `EvaTypeScale`. Decision 144's exact
shape, with every §7 gate green throughout.

**A gate that quietly skips a class of declarations is the same defect as one that
cannot fail** — `docs/DRIFT.md` §7 records `EvaChip`, and §7's fourth bullet is the
same shape again. The inventory is now **all of `lib/`** (generated files still
excluded), and the gate's notion of "placed" had to grow a meaning for the classes
that come with it: the **pages** are roots and therefore placed by definition, and
the non-widget helper classes are excluded by the `DECL` pattern, which only matches
`StatelessWidget` and `StatefulWidget`.

**The rule for the next reader: a gate's inventory is a CLAIM about where the
subject can live, and it must be checked against the tree.** The design system's
three directories — `effects/`, `motion/` and `tokens/` — are all outside
`*/widgets/`, and the gate's own doc never said so.

**161. THE GOLD FLECKS CAME BACK, AND THE REASON IS THE **ORIGINAL PLAN'S VERIFY
LINE** — NOT A PREFERENCE FOR AN ORNAMENT.**

The redesign's `.opt` paints border, fill and badge and nothing else
(`eva/redesign.html:337-341`), and the client's suite used to assert the flecks'
**absence**: *"the flecks died with the prototype that drew them, and the sweep above
is what keeps them from coming back."* That was a **drift and not a decision**:

* **`docs/plans/08-build-phases.md:112`** — the original build plan's Phase 8 verify
  line reads *"a widget test that `QuizOptionCard` shows `correct` + `GoldFlecks`
  after checking"*. The flecks were **required**, and the Lumen redesign dropped them
  without recording that it was dropping them.
* the brief's own rule — "the ONLY sacred cues are: gold flecks (tiny, sparse,
  decorative)" (`eva/brief.txt:51`).

They are now on the quiz's correct option, as a `Positioned.fill` overlay inside a
`Stack(clipBehavior: Clip.none, fit: StackFit.passthrough)` — `Clip.none` because two
of the four sit **outside** the card's left edge, and `StackFit.passthrough` because
the card's own layout must not change. **The offsets are derived**: the prototype's
right-hand pair (`356`, `362`) are screen pixels on a 390px frame, so they are
**6 and 12 pixels past the card's right edge** and the client's pair is
`cardWidth + 6` / `cardWidth + 12`. The left-hand pair (`-10`, `-15`) is already
card-relative and does not move.

**The test was rewritten, not deleted.** A reversal that leaves no trace is a
reversal nobody can audit.

**162. THE TYPE SCALE IS INSTALLED BY THE **WIDGET**, AND THE CLAMP IS DEFENCE IN
DEPTH — NOT A NEW RULE.**

`MaterialApp.router.builder` used to spell the install out by hand as a `MediaQuery`
with a `copyWith(textScaler: evaScalerFor(settings.fontStep))`. That was the **third**
spelling of the same rule — `/reading`'s §14 overflow suite and `/settings`'s
stepper were the other two — and "a bare `MediaQuery` spelled three times is three
rules" is `barrel.dart`'s own argument for one import surface. It is now
`EvaTypeScale(step: settings.fontStep, child: …)`, **at the site its own doc always
named**.

**The widget clamps and the hand-written install did not**, and the clamp changes
**nothing a reader can reach**: `clampFontStep` is the identity on every step in
`kFontStepMin`…`kFontStepMax` (1…5), and `SettingsCubit` is the authoritative
boundary — it clamps on `load` and on every write. The two agree, so the rendered
scale is byte-identical for every persistable step, and the only input the clamp
changes is the one neither the stepper nor the cubit can produce.

**163. THE TOAST IS **ONE** WIDGET IN THE DESIGN SYSTEM, AND THE **PAGE** OWNS THE
CLOCK.**

The prototype's `.toast` is **one** CSS rule (`eva/redesign.html:466-468`), and
this client had **three** implementations of it: a feature-local copy in
`features/leaderboard/`, a feature-local copy in `features/settings/`, and the
amen, which had no toast at all. AGENT_CONTEXT §3's rule that **no feature may
import another feature** is what made the shared copy the only possible home
rather than a preference — and the shared copy is
`core/design_system/widgets/eva_toast.dart`.

**The PAGE owns the clock, not the widget.** The prototype's `toast(m)` (`:1393`)
shows the message for 1800 ms and then removes it, and that is a `setTimeout` at
the **screen root**: the screen knows when the event happened and when the
screen is disposed, and a widget that owned its own timer would have to be
told to stop. **The page raises it, times it, and takes it away; the widget
draws.**

**And the label is announced ONCE.** A `Semantics(label: message)` over a
`Text(message)` announces the message **twice**. The shared toast's own test
*pinned the doubling* and said it was not fixed there, because the two
implementations it replaced had that announcement as their behaviour — a
constraint that **expired** when those implementations became this widget. The
fix is `excludeSemantics: true`, and the **appearance is untouched** because
semantics are not painted.

**164. THE QUIZ'S ANSWER HAPTICS FIRE ON THE **EDGE**, AND `null` MEANS "NO
VERDICT".**

`eva/redesign.html:1428`'s `haptic(30)` and `:1429`'s `haptic([40,60,40])` are
the prototype's firm bump and buzz. The mapping is a **pure domain function**
(`features/quiz/domain/answer_haptic.dart`) because "domain logic must not be
buried inside a widget" (AGENT_CONTEXT §6), and it returns `null` for an
answer that is not graded.

**The haptic fires on the EDGE — ungraded → graded — and not from `build`.** A
`build`-time call fires per rebuild, and **a rebuild is not a check**. The
prototype grades on the tap (`:1423`'s `pick`); this client grades on a *second*
press, because the grade is a `POST`, so the event is "the verdict arrived" and
only a listener can see that edge.

**`null` is the "say nothing" answer**: a chosen-but-unchecked answer and a
failed submit both land there, and a haptic there would announce a verdict the
server never sent (AGENT_CONTEXT §5's traps).

**165. THE SHADER CLOCK IS **HELD AT ZERO** UNDER REDUCED MOTION — NOT AT
"WHEREVER IT HAD REACHED".**

`core/design_system/effects/lumen_clock.dart` holds `u_time` at **zero** when
the reader has asked for reduced motion, and
`core/design_system/effects/neural_motion.dart` drives it. The prototype's
answer is different and is a **divergence, not a port**: `eva/redesign.html:888`
**scales** the accumulator (`timeAcc += dt*(reduceMotion?0.15:1)`), so its
aurora keeps drifting, slowly.

**Why zero and not the value it had.** A freeze at the value it had is a
function of **how long the app had been running** and of **when the reader
toggled the setting** — so two readers with the same settings would see two
different auroras, and a reduced-motion golden would be a fact about the
session that captured it. **At zero it is a function of the setting alone.**
That is the same discipline the vespers' injectable hour came from, one level
up.

**The hold is a REPORTING rule, not a destruction of history.** The accumulator
keeps the elapsed time, so turning reduced motion **off** restores the aurora
to the phase it had reached. The visible cost is stated rather than smoothed
over: the shader's phase snaps back in one frame. **The other three clocks
(float, hue, aurora) are untouched and still stop wherever they stood.**

**166. THE OS'S OWN REDUCE-MOTION SWITCH IS HONOURED **MID-SESSION**, AND THE
COMPOSITION ROOT IS THE OBSERVER.**

`lib/app/app.dart` observes `didChangeAccessibilityFeatures` and rebuilds, so
the **combined** answer — the platform's signal *and* the reader's stored
preference — is recomputed and handed to `NeuralMotionScope`, whose
`didUpdateWidget` already had the mechanism to stop or restart the clocks.

**It was not honoured before, and the reason is a dead branch.**
`NeuralMotionScope.didChangeAccessibilityFeatures` acts only
`if (widget.animationsEnabled == null)`, and `app.dart` **always** passes an
explicit value. So the scope's observer was dead code, and a reader who turned
the OS's switch on while the app was open got it for the per-widget
`MediaQuery.disableAnimationsOf` checks but **not** for the four shared clocks.

**And the file argued with itself about it**: the class doc said the signal was
"honoured again if the reader toggles it mid-session" and the helper's own doc,
three paragraphs below, said the opposite. **Both were in the same file.** A
file that documents the same mechanism twice is a file with two claims, and only
one of them is checked.

**167. THE PROTOTYPE'S I18N TABLE IS **MEASURED**, AND A ROW THE CLIENT DOES NOT
DRAW GETS **NO KEY**.**

`eva/redesign.html:924-977` holds **128 rows**. Measured against the ARB pair
**by English value** — parsing the prototype's own `I18N` literal rather than
quoting it — **103** are carried verbatim, **13** are carried under another
name or as a live composition, and **12** are excluded with a reason each.
**Zero keys were added**, and that is the correct outcome: a row the client does
not draw gets **no key**, because a key nobody reads is a key a translator will
translate for a screen that does not exist.

**And the measurement is a GATE.** `test/l10n/app_localizations_test.dart` holds
a map of the prototype's 128 rows to their fate, and asserts that the map is
**exactly** the tail, that no row is missing, that no entry is stale, and that
the verbatim count is 103. **A row cannot be silently dropped from the
prototype's table.**

**168. THE OLD DESIGN'S ORBS ARE RETIRED, THE FALLBACK IS THE **FLAT CANVAS**, AND
`NeuralVariant` AND `NeuralTier` ARE GONE WITH THEM.**

`NeuralBackground` was the redesign's **fallback** — the plan's Task 1.5 Step 3
kept the legacy painter because it was *"the thing that was already there"* —
and what was already there was the **old design's per-screen orb groups**, which
this redesign replaced with **one canvas for every screen**
(`eva/redesign.html:46`). The prototype's own answer for "no aurora" is the
canvas fill: the screen root is `background: T.canvas` with a transparent
background layer above it — and the redesign's own canvas layer is exactly that
shape, `position: absolute; inset: 0` over the screen root (`redesign.html:46`).

**So the fallback is now a `ColoredBox(color: colors.canvas)`**, and the rules a
reader needs:

* **`NeuralScaffold` takes no `variant:`, and `LumenBackground` takes none
  either.** `NeuralVariant`'s only job was to select an orb group, and there
  are no orb groups. Eight pages stopped passing one.
* **`NeuralTier` and `NeuralTiers` are gone.** The tier counted **orb layers**;
  `mid` and `high` meant the same thing to the shader, so the three tiers
  collapse into the **`LumenShaderTier`** that already existed
  (`core/design_system/effects/lumen_tier.dart`): `off` / `noShafts` / `full`.
  `NeuralTier.low` became `LumenShaderTier.off`; `mid` and `high` both became
  `full`, because the shader's decision never read the difference and the
  **pixel budget** still gates the shafts.
* **The bundle has TWO clocks, not four.** The `hue` and `aurora` controllers
  and the `pointer` notifier were read only by the old painter — **two
  `AnimationController`s were ticking every frame for nothing.**

**AND THE FLOAT CLOCK OUTLIVED THE ORBS, WHICH IS THE PART WORTH KEEPING.** It
was the old design's *orb* float, and the orbs are gone, but `GoldFlecks` and
the witness sky's twinkle both read it — so the clock stayed and the orbs went.
**The honest test of a retirement is "who reads it now", not "what was it
for".**

**AND THE TWELVE DEAD `EvaMotion` MEMBERS ARE THE SAME DEFECT ONE LEVEL DOWN.**
Twelve members had **no live use in `lib/` at all** — their own test suites
assert them and nothing else does: **ten** are the old design's
(`auroraCurve` / `aurora` / `orbFloatCurve` / `orbHueCurve` / `orbFloatMin` /
`orbFloatMax` / `orbHueMin` / `orbHueMax` and the two spreaders `orbFloatFor`
/ `orbHueFor` that used them), **one** is `fleckAlternates` — a flag whose own
test says *"for Phase 2 to act on"*, and Phase 2 came and went — and their
**private helper** `_spread` went with the spreaders.

**A token is not a widget, so the orphan gate could not see any of it.** That is
the same shape as decision 144 and decision 160, and the same blind spot: a
gate that walks one kind of declaration cannot see a defect in another kind.

**AND THE MEASUREMENT THAT FOUND THEM FELL INTO THE TRAP FOUR TIMES, WHICH IS
WORTH RECORDING BECAUSE THE TRAP IS EASY.** A search for a member's name
**outside** the file that declares it reports it dead — and that is wrong for
every member used by **another member of the same file**. A first pass reported
**nineteen**, and they split four ways: **nine** were live
(`achievementSpring` → `achievementBounce`, `fadeSlide` → `screenCurve`,
`goneSlide` → the four `gone*` numbers, `tabSwap` → the two `tabPre*` ones,
`screenSlideBeginFor` → `screenSlidePixels`); **two** were **legitimate**
(`tabOutOffset` / `tabOutScale` record the prototype's tab-out pose so the
divergence has values, and the suite asserts the builder never applies them);
**one** had a **documented call site that was never made** (`tabTransition` —
the dock passed the `transitionBuilder` and not the duration, so the tab swap
ran auto_route's 300 ms default where the prototype says 400 ms, and the fix
was to make the call); and **five** more were dead and the first pass **missed**
them. **The number was settled by deleting the candidates and letting the
compiler answer**, which is the only measurement that cannot be wrong about
that — and it is also why there is **no dead-token gate**: a regex cannot decide
it, and a gate that reports a live member as dead is turned off within a week,
and a turned-off gate is worse than a missing one.

**AND ONE OF THE NINETEEN WAS NOT DEAD AT ALL — IT HAD A CALL SITE THAT WAS
NEVER MADE.** `EvaMotion.tabTransition` is 400 ms, the prototype's tab swap is
400 ms (`eva/redesign.html:128`), and the app's own **route** transition is 400 ms
(`app_router.dart`'s `duration: EvaMotion.routeTransition`). **The dock passed
the `transitionBuilder` and not the duration**, so the tab swap ran auto_route's
own default of **300 ms** (`auto_tabs_router.dart:249`) — 100 ms faster than the
design, with the tab-out poses at half the prototype's.

**The token's own doc showed the call site:**

```dart
AutoTabsRouter(
  duration: EvaMotion.tabTransition,
  transitionBuilder: EvaMotion.tabSwap,
)
```

**And the fix was to MAKE THE CALL, not to delete the token.** That is the
general rule this whole retirement turns on: **a token with no caller is a
question, not a verdict.** Sometimes the answer is "dead"; sometimes it is "the
call site was never made"; and sometimes — as with `tabOutOffset` and
`tabOutScale`, which record the prototype's tab-out pose so the divergence has
values and whose test asserts the builder never applies them — it is "it is a
recorded divergence, and the receipt is the point".

**AND THE SIXTEEN GOLDENS PHOTOGRAPHED A DESIGN THAT DOES NOT SHIP.** The
ambient's only pixel-level net was
`test/core/design_system/effects/goldens/neural_background_*.png` — sixteen
images of the **old design's orbs**. **The LUMEN shader, which is what the app
paints, had no golden at all.** The goldens went with the orbs they
photographed, and **the ambient now has no pixel net** — which is not a
regression, because it had none for the design that ships. It is a **hole that
was always there**, and it is the next thing to close: the shader's own
goldens, with the capture harness re-checked against the plan's recorded risk
(`flutter test` ≠ Impeller — the tests run Skia software).

**169. THE REACT PROTOTYPE IS **RETIRED**, AND EVERY CITATION INTO IT WAS
REWRITTEN **BY HAND**.**

`eva/src/` — the React prototype this redesign replaces — is gone, and so is the
Figma Make scaffolding around it. **What remains in `eva/` is the two things the
design is transcribed from**: `redesign.html` (the design source of truth) and
`brief.txt` (the original brief, and the source of the design *language*).

**THE PROTOTYPE WAS NOT DEAD — IT WAS A 554-CITATION RECEIPT, AND 327 OF THOSE
CITATIONS WERE LIVE, IN `lib/`, IN CLAIMS THE SHIPPED CODE MAKES.** They said
*"the redesign's `.opt` has no counterpart, and the superseded prototype's
option card had one"*. **And a line number in a file that does not exist is a
fiction**, so every one of them was rewritten: **237 distinct targets across 554
sites**, each re-pointed at `redesign.html` where the redesign has the same thing,
rewritten as a **divergence note carrying the value and the fact** where it does
not, or dropped where the citation was decoration.

**AND THE GATE IS WHAT ENFORCES IT.** `tool/gates/citation_check.py`'s pattern
**still matches `.tsx`**, on purpose: a `.tsx` citation is now a **broken**
citation, named by the gate. A pattern that stopped matching would report a clean
run over a surface it no longer examines — the ADR-0020 shape, and the third time
this repository has met it. **The retirement is enforced by the gate, not by a
convention**, and `tool/verify_gates_selftest.sh` plants a `.tsx` citation and
requires the failure.

**AND THE GATE NOW SCANS THE LIVE DOCUMENTS.** The authority document, the ADRs,
the plan, the drift catalogue and the seams map are where the client's claims
live, and **113 of them had never been checked by anything**. `docs/plans/` is
the one exception, and it is deliberate: it is a historical record of analyses
made against the prototype, it is owned by somebody else (AGENTS.md: "Do not
rewrite `docs/plans/`"), and about fifty of its citations point at a prototype
that has since been retired. **A document that records a past analysis is allowed
to point at the past.**

**AND THE BRIEF'S LINES ARE NOW CHECKED, WHICH THEY WERE NOT.** Its filename had
a **hyphen** in it and the pattern matched `[A-Za-z0-9_]+`, so
`pasted-attachment.txt:97` **never matched** and its eight line citations were
**verified by nothing at all** — and they are the ones that say *"the ONLY sacred
cues are: gold flecks, the verse marker, and beautiful typography"*, the rule the
gold flecks' return rests on. Moving it to `brief.txt` closed that hole, and the
brief is now the gate's **second named reference**.

**THE RULE THAT DECIDED EVERY CASE IS THE PLAN'S OWN.** The Lumen plan's Task
4.2 Step 4: *"Re-point citations per widget … **only for widgets that actually
changed**. A citation that still describes a surviving widget is not wrong;
moving it would be churn."* So the surviving `ds.tsx` citations were
**deliberate** — they are where the redesign has no counterpart and the old
number is the receipt of the difference — and what they needed was not a new
line but a **sentence that stands on its own**.

---

**170. A STATE CHANGE REBUILDS ITS TARGET AND NOTHING ELSE, AND THE BOUNDARY IS
A GATE.**

§13 rule 1 says *"No `setState` per frame"*, and ADR-0019 says *"No `setState`
per frame"* — and **neither was ever enforced against anything**. ADR-0019 is
marked *superseded by ADR-0022*, with the note that *"`lib/` carries the old
values until the plan's Phases 2–6 land it."* Those phases landed. **The values
were never checked.**

**AND THE MEASUREMENT IS NOT A GUESS.** A Hue slider drag rebuilt **1,236
widgets** — every one of `/settings`'s thirty-three rows, for a change to one
number. A verse tap rebuilt **211** — the whole screen, the **forty-four-star
sky** included. Both figures are now **budgets** in
`test/rebuild_isolation_budget_test.dart`, and the budgets are **27** and
**55**. The instrument is `test/support/rebuild_counter.dart`, which counts the
framework's own `debugOnRebuildDirtyWidget` hook.

**THE MECHANISM IS FLUTTER'S AND IT IS ONE LINE.** `Element.update`
short-circuits when the new widget is **identical** to the old, so a rebuild
stops descending at the first unchanged subtree. The cost of a state change is
therefore decided by **how wide the thing that changed is** — and it was the
whole screen. ADR-0024 records the decision; `docs/PERFORMANCE.md` records the
measurements and the commands that reproduce them.

**171. THE SELECTORS AND THE SCOPE ARE **ONE** CHANGE, AND THE ORDER WAS
MEASURED, NOT ASSUMED.**

The per-row `BlocSelector` split on `/settings` was landed **first**, and the
number got **worse**: 1,236 → **1,358**. Each of the twenty-eight selectors
added its own rebuild, because `BlocSelector.build` calls its builder
**unconditionally** — so a selector whose **parent** rebuilt rebuilds its child
anyway.

**So narrowing the scope is the selectors' PRECONDITION, not their
refinement.** `SettingsScope` was one `InheritedNotifier` over the whole
thirty-field `UserSettings` and notified on every write, and every dependent
rebuilt on every write — including the three invisible tab screens the dock
keeps alive. It now publishes four **slices**, each with its own notifier and
each a **distinct runtime type**, because `InheritedWidget`'s dependency
granularity is per type. **And the handle is read WITHOUT a dependency**,
because its identity never changes.

**172. THE COMPOSITION ROOT REBUILDS ONLY FOR WHAT `MaterialApp` READS.**

`app.dart` rebuilt the **entire application** on every settings write,
including the ones `MaterialApp` does not read at all. It now compares the
**four** settings that reach the shell — `themeMode`, `locale`, `fontStep` and
**`reducedMotion`** — against the last built values, and a write that touches
none of them does not rebuild the shell.

**`reducedMotion` WAS MISSING FROM THE GUARD THE FIRST TIME**, and
`app_settings_wiring_test.dart` said so. It reaches `NeuralMotionScope`, which
is **above** `MaterialApp` — so it is a shell-level setting even though it is
not a `MaterialApp` property. **A guard that watches three of the four fields
is a guard that breaks the fourth**, which is the whole argument for the test
existing.

**173. A PAGE'S OWN STATE LIVES IN NOTIFIERS, NOT IN `setState`.**

`/reading` called `setState` five times, and every one of them rebuilt the
**whole screen** — the scaffold, the sky, every visible verse — because the
page's `build` carries them. The selected verse, the reveal frontier, the
focus dim, the bookmark and the language arm are now five `ValueNotifier`s,
each with a `ValueListenableBuilder` around its **one** consumer.
**`/reading` no longer calls `setState` at all.**

**AND TWO OF THE FIVE ARE FREE.** Tapping the **already selected** verse costs
**nothing**: a `ValueNotifier` ignores an equal value, where the `setState` it
replaced rebuilt the screen every time. And the reveal frontier no longer
rebuilds the screen **once per verse** — a thirty-verse chapter used to rebuild
it thirty times in its first second.

**174. THE AURORA'S PIXEL BUDGET IS COUNTED IN **LOGICAL** PIXELS, AND THE
COST IS IN **DEVICE** PIXELS.**

`lumen_tier.dart:89`'s `kShaftsPixelBudget` is compared against
`MediaQuery.sizeOf(context)` — **logical** pixels — while the cost it protects
is GPU fragments, which are **device** pixels. On a 1080×2400 phone at dpr
2.75 that is **0.343 Mpx** against **2.592 Mpx**: the gate under-counts by
**dpr²**, about **7.6×**. At the file's own recorded rates (2.98 ns/px for
shapes 0–2) the default band costs **7.7 ms** of a 60 Hz frame — and **93 %**
of a 90 Hz one.

**AND THE AURORA REPAINTS ON EVERY VSYNC, WITH NO CAP** — no
`devicePixelRatio` read anywhere in `lib/`, no `TickerMode`, no
`setFrameRate`, no resolution scaling. §13 rule 4 asked for exactly this
("a tier that drops to `low` on low-end devices … at **30 % cost**") and
`LumenTiers` has no such member.

**Both are OPEN, and both are GPU problems rather than rebuild problems** — so
they are recorded in `docs/PERFORMANCE.md` §3 with the fixes, the order and
their costs, and **not** decided here. The one that needs a decision is
rendering the aurora at half resolution: **4× fewer fragments**, the shape
unchanged, and **visible as a slightly softer aurora**.

**175. THE AMBIENT PAINTS AT THIRTY TIMES A SECOND AND NOTIFIES AT TWENTY, AND
BOTH ARE COUNTED IN **TICKS** RATHER THAN IN TIME.**

The ambient is the app's most expensive layer and it had **no budget at all**.
The **aurora** is a full-screen fragment shader re-rasterised at **device**
resolution — **2.6 M fragments a frame** on a 1080×2400 phone, which at the
tree's own measured rate is **7.7 ms**, or **93 % of a 90 Hz frame** — and the
**notification** rebuilds the witness sky's **forty-four stars** on every vsync.

§13 rule 4 asked for exactly this — *"a `NeuralTier` … drops to `low` on
low-end devices: no orbs, aurora only, at **30 % cost**"* — and `LumenTiers`
never grew one. **The ambient's cost is not a pixel cost; it is a frame-rate
cost, and nothing in the tree counted frames.**

**AND THE BUDGET GATES THE **PAINT** AND THE **NOTIFICATION**, NEVER THE
**STATE**.** The eased ambient, the eased hue and the decaying spike still
advance on every tick, with the prototype's per-frame constants untouched — so
the aurora's trajectory is **exactly** what it was, and only the painting is
rarer. **Converting the per-frame eases to per-second would have been a
divergence from the prototype** (`redesign.html:891-892`'s `0.06` is a
per-frame constant, and the prototype's own `dt` is used for the *auto hue* and
the *time accumulator*, never for the eases), and
`lumen_scene_test.dart`'s twelve-decimal-place assertions on one frame's ease
are **right**.

**AND IT COUNTS TICKS RATHER THAN TIME, BECAUSE EVERY CLOCK HERE IS WRONG.**
A wall clock can go backwards; a `Stopwatch` makes the goldens
non-deterministic; `SchedulerBinding.currentFrameTimeStamp` asserts that a
frame is in progress (and the ambient's notification can arrive **outside**
one); and the shader clock's own elapsed time is **one frame behind** the
float clock's, because the two tickers tick in sequence and the float ticks
first. **All four were tried.** The tick count is exact, reproducible, and the
unit the thing being budgeted is **already counted in**.

**A GOLDEN MUST ASK FOR AN UN-BUDGETED SCOPE.** The budget decides *which tick*
a frame is captured on, and a golden captures a **design** — so
`evaAmbientHarness` takes a `budget` and the witness sky's goldens pass
`kNoAmbientBudget`. **A golden that captured a budgeted frame would move every
time the budget did.**

See ADR-0025.

**176. THE `setState` POLICY IS A **GATE**, AND THE SIXTEEN THAT REMAIN ARE
THE ONES WHOSE `build` OUTPUT *IS* THE STATE.**

§13 rule 1 says **"No `setState` per frame"**, and it has said it since the
first phase. **It was never enforced against anything**, so the tree grew to
**twenty-nine** of them, and several of those rebuilt a **whole screen** to
change one boolean.

**A RULE THAT CANNOT FAIL IS WORSE THAN NO RULE**, and this repository has met
that three times (ADR-0020, decision 142). So the rule is now a gate:
`test/setstate_budget_test.dart`.

**THE KEY IS A FILE PLUS THE MULTISET OF ITS NORMALISED STATEMENTS, AND NOT
A `file:line`.** A line key is brittle in the worst way: any edit above a
site moves it, and the gate would cry wolf on a change that changed nothing.
The multiset catches all three things a gate must — a **new** statement, a
**removed** one, and an **edited** one — and a *set* would collapse the four
identical `setState`s in `selah_card.dart` into one and let a fifth slip
through.

**AND THE GATE FAILS ON THREE THINGS.** A `setState` outside the allowlist; a
**stale** allowlist row, because a row whose site has gone is a row that still
permits a `setState` nobody has looked at; and **zero matches**, because a
scan that finds nothing is a scan whose matcher has rotted — and a gate that
reports a pass over a surface it no longer examines is the ADR-0020 shape.
`tool/verify_gates_selftest.sh` plants each of the three and requires the
gate to fire.

**THE SIXTEEN THAT REMAIN ARE ALL THE SAME ANSWER.** Each one's `State.build`
output *is* the state: a button's press highlight, a row's hover wash, the
dial's measured thumb, the dock slot's scale, the selah card's own countdown
(the one `setState` in the tree that fires on a **timer**), the quiz CTA's
hover, the aurora's backing widget (three widgets, once at startup), and the
composition root's **two** — the first **guarded** on the four settings that
reach the shell, the second on the platform's accessibility signal.

**And the six toasts became notifiers** in the same change: a toast is one
widget in the overlay slot, and a `setState` rebuilt the whole screen to
show it and to take it away again.

---

### Recorded decisions — the servant portal (2026-10-21)

The portal is `docs/adr/0026-the-servant-admin-portal.md`; the design is
`docs/superpowers/specs/2026-10-21-servant-admin-portal-design.md`; the plan is
`docs/superpowers/plans/2026-10-21-servant-admin-portal.md`. **Decision 5 was
reversed** — see §2 — and these are the decisions the build took inside it.

**177. THE PORTAL'S SHELL IS A **HUB**, NOT A TAB SHELL, AND THE REASON IS THE
ROLE LADDER'S BOTTOM RUNG.**

`/servant` is a page that lists the sections this role has. It is **not** an
`AutoTabsRouter`, and the alternative was measured rather than assumed: a
`viewerServant` holds exactly **one** capability beyond the reader's three
(`UserRole.grantsFor` — `viewServantReport`), so a tab shell would have
rendered a tab bar holding a single tab, which is chrome for nothing. A hub
degrades to one entry and a tab shell does not.

*Rejected: one tab shell with a hidden tab for the viewer.* The hidden tab is
the tab bar again, and the reader's app keeps its five-slot dock — the portal
is a **second surface**, not a fourth slot in the first.

**178. THE ROLE IS **ONE FACT READ FROM TWO ANGLES**, AND THE WIRE READS IT
TOO.**

`AuthSession.role` is the source of truth. `RoleAccess` is a **reader** over it
(`LiveRoleAccess`, `lib/core/navigation/role_access.dart`), and two things ask
that reader: the **navigation guard** and the **`X-User-Role` header**.

The header was a frozen `kid` string baked into `IdentityHeadersInterceptor` at
composition, so a client that believed it was an `admin_servant` sent `kid` on
every request. It is now a **reader called per request**
(`role: () => roleAccess.role.wireValue`), so the wire carries what the client
believes. **The backend does not care** — it parses the header at
`src/middleware/identity.middleware.ts:24`, assigns it at `:31`, and never reads
it again — and the client should not lie about it anyway.

**There is exactly one place the session is held**, and it is the
`AuthLocalDataSource`'s in-memory field. The `RoleAccess` is registered in the
**pure** DI half (`lib/app/di/modules/auth_module.dart`) so `injection.dart`'s
Flutter-free import-graph gate still holds; the guard and the wire read that
one registration. **One session, one role, two readers** — never a mirror.

**179. THE SEAM ANSWERS FOR A **GIVEN** ROLE, AND THE GUARD READS THE ROLE
**ONCE**.**

`RoleAccess` gained **`allowsRole(UserRole role, UserCapability capability)`**,
and `allows(capability)` answers through it. The member exists because a seam
built on a reader guarantees **liveness, not atomicity**: `role_access.dart`'s
own hazard #2 says two reads "can be handed two different roles, because the
bloc emitted in between".

**The guard's decision and its destination are therefore one snapshot.** It
captures the role once, asks `allowsRole` for the grant, and refuses to
`landingRouteFor` of **that same role**. The reads of the seam's `role` per
navigation went from **2** to **1** — and the "before" number is measured, not
asserted: it is the `Actual: <2>` a planted two-read guard produced against the
new test.

*Rejected: the guard calling `UserRole.grantsFor` itself, which the old hazard
#2 text prescribed.* That would make the caller a **second holder of the grant
table** — the shape decisions 5 and 68 each removed — and it would put the
guard and the hub on **two answers to one question**. The seam answers; the
table is consulted in exactly one place.

**180. THE GRANT TABLE HAS **EXACTLY ONE CALL SITE**, AND A GATE HOLDS IT.**

`UserRole.grantsFor(` is called from exactly one file in `lib/`:
`lib/core/navigation/role_access.dart`. The hub originally read the table
directly — the same table, so the two answers agreed, which is precisely what
made the duplication invisible — and it now asks the **seam** instead.

**The gate is structural, not a count in a paragraph**: a test walks every
`.dart` file under `lib/`, skips comment lines, matches the **qualified**
`UserRole.grantsFor(` (so the enum's own declaration is not counted as a caller
of itself), and asserts the call sites are exactly
`lib/core/navigation/role_access.dart`. Planting the table back into the hub
turns it red.

**181. TWO PORTS, NOT ONE, AND THE PORT IS **WIDER THAN ITS ADAPTER** ON ONE
METHOD.**

`ServantAdminRepository` (schedule / commit / ai-draft) and
`ServantReportRepository` (the daily roster) are **two narrow ports** in
`features/servant/domain/repositories/`, not one fat one (§3's ISP). They live
in the feature's `domain/` and **not** in `core/domain/`, because each has
exactly **one** consumer — §3's placement test.

**The AI-draft port is wider than its adapter, and that is recorded rather than
hidden.** `QuestionType` has three members (`mcq`, `true_false`,
`short_answer`) because the **commit** route accepts all three
(`admin.routes.ts:38`), while the **ai-generate** route accepts only two
(`ai.routes.ts:10`). The refusal for `short_answer` therefore lives in the
**mapper**, as a `validation` failure, rather than narrowing the port: the
domain type stays as wide as the union it names, and the port's doc says so.

**182. THE AI QUESTION HAS **THREE DOORS**, AND A DRAFT IS COMMITTABLE
BECAUSE THE TWO BODIES SHARE A SHAPE.**

1. **AI at schedule time** — `generate_ai_questions: true` makes the server
   generate and attach the question inside the schedule transaction. One call.
2. **Hand-written** — `generate_ai_questions: false`, and the admin writes the
   question and the answers on `/servant/questions`, which receives the
   `reading_id` from the schedule response.
3. **AI draft, then edit, then commit** — schedule without AI, ask
   `ai-generate` for a draft, edit it, commit it.

**Door 3 works because the draft's `options` has the same shape as the commit
body's**: `Record<string, {ar, en}>` — `ai.service.ts:9` and its
`responseSchema` — so a draft needs no conversion before it is committed.

**And there is no fourth door, because there is no endpoint for one.** The
backend has **no "list my scheduled readings" route**, so the questions screen
accepts a **typed** `reading_id` for a reading scheduled in an earlier session,
and says where it came from rather than pretending a lookup exists.

**183. THE SCHEDULE ENDPOINT **UPSERTS**, AND WITH AI ON IT **DELETES THE
QUESTIONS** — SO THE UI STATES BOTH.**

The insert is `ON CONFLICT (group_id, scheduled_date) DO UPDATE`
(`admin.routes.ts:157`), so scheduling the same cohort and date again
**replaces** the passage. And with `generate_ai_questions` on, the route runs
`DELETE FROM questions WHERE reading_id = $1` (`admin.routes.ts:195`) — so
re-scheduling with AI on **removes the previous questions** for that reading.

Both are **stated on the schedule screen**, not hidden: a screen that silently
replaces a passage and silently deletes its questions is the kind of screen
that loses a week of preparation. The wording is **written, not transcribed** —
`eva/redesign.html` draws no portal.

**184. THE GOLDEN'S "TODAY" IS A **SEAM**, NOT A CLOCK.**

`ServantReportPage` pre-fills the report's date with today. A golden is a
**picture**, not a shape, so a golden of a screen that reads the wall clock
fails **every morning** — a flaky test nobody can debug. The date is therefore
a parameter of the page, `null` meaning the real clock, following
`CommunionCountdownLine`'s `now` precedent. The form default is still today's
date, because a screen that asked an adult to type it by hand would be a worse
product.

**185. THE LANDING IS **DEFERRED ONE FRAME**, AND THE REASON IS MEASURED.**

`landingRouteFor` had **no caller** since it was written, and its own doc said
the two call sites would arrive separately so they could not drift. The login
result handler is now the first.

**But issuing the landing straight from the sign-in listener produced TWO
copies of the reader's own screen.** `replacePath` removes the last route
**synchronously** and pushes **asynchronously**, so the removal took the
*login* route and the guard's resume then pushed the interrupted route **on
top**: measured `[DockShellRoute, ServantHomeRoute]`, and
`[DockShellRoute, DockShellRoute]` for a kid. **The landing is therefore
deferred to the end of the next frame**, where the removal takes the **guard's**
route: measured `[ServantHomeRoute]` — one route, and it is the landing.

**186. THE ROLE LABELS ARE **SHORT**, AND THE MEASUREMENT IS WHY.**

"Kid", "Servant" and "Admin", not "Viewer servant" and "Admin servant". At
320px and 1.22× — §14's own numbers — the two-word labels do not fit the
default `SegmentedControl` geometry: the content column is
`320 − 2×34 = 252px`, the track takes 8, three segments share 244 → **81.3px**
each, and the default's `segmentPadding` leaves **57.3px** of text where
"SERVANT" wants **64.9px**. The default mode **ellipsises** it, and a clipped
label is §14's "the reader's words deleted". The wide mode's numbers fix it
(**62.5px against 81.3px**), and `login_text_scale_test.dart` asserts each
label's rendered width against the width it wants, in **both** arms.

**The two servant roles are told apart in a church by what they do** — one reads
the report, one administers — not by the word "servant".

**187. THE THREE CUBITS WERE **NOT WRITTEN TEST-FIRST**, AND THAT IS RECORDED
HERE RATHER THAN CLAIMED ELSEWHERE.**

AGENT_CONTEXT §6 requires red-first for **every cubit**. The three portal
cubits (`ServantReportCubit`, `ScheduleReadingCubit`, `QuestionAuthoringCubit`)
were implemented before their tests were written.

**The recovery is a mutation run, and it is a weaker instrument than a genuine
red**: it proves the tests **bite**, not that they **drove** the design. Five
tests went red with the intended messages. A reviewer should read this slice's
record as *"the tests were written after the cubits and were shown to fail when
the cubits were broken"*, never as a §6 red-first record.

**The honest remedy was not taken and is not hidden**: re-deriving the cubits
from their tests would have been a rewrite of working code for a process
record, and the tests' bite was demonstrated instead. A future cubit in this
repository gets the red-first the protocol asks for — **this one did not, and
this paragraph is where that fact lives.**

**188. A SCREEN AND THE STATE IT MIRRORS MUST AGREE, AND THE **REQUEST** IS THE
ONE THAT WRITES.**

**Six defects of one class** were found in this repository's servant-portal work,
and **every one of them was found by an agent reading the code — not by a gate.**
The class is:

> **A screen and the state it mirrors can stop agreeing — and the request is the
> one that writes.**

**THE ROOT CAUSE IS THAT THE CORRECT PATTERN WAS NOT EXPRESSIBLE.** A page that
mirrors a cubit-held value into a `TextEditingController` has to hand-roll it,
and hand-rolling has **three** ways to be wrong — **the write is reported**, the
field is **seeded instead of read back**, the mirror runs in the **wrong
direction** — and **no way to be caught**. `LoginPage` gets away with it only
because its state is cleared on every path that unmounts the page, and **that is
a coincidence, not a design.**

**THE SIX, BY SCREEN, SO THAT THE NEXT ONE CAN BE RECOGNISED.**

| # | screen | what it got wrong |
| --- | --- | --- |
| 1 | `/servant/questions` | **A programmatic write reported as a user edit.** The editor wrote the state's `pointsText` into a controller that had started **empty**, the controller notified, and the cubit was told the **reader** had edited the question. The cubit's edit writer then dropped the **server's failure** with it — **a server's refusal erased itself in one frame.** |
| 2 | `/servant/questions` | **A seed that reported the controllers' contents at mount.** The controllers start empty, so the seed told the cubit *"the reader cleared the question"* — and the admin's in-progress question was wiped on re-entry, over the **singleton** cubit whose one purpose is to survive the route. |
| 3 | `/servant/schedule` | **The same seed, on the schedule form.** The form was never read back, so the admin saw an **empty form** while the state held a passage, and the button sent the passage the admin could no longer see. The server's insert is `ON CONFLICT (group_id, scheduled_date) DO UPDATE` (`admin.routes.ts:157`), so that **replaces the cohort's scheduled passage**. |
| 4 | `/servant/report` | **The same seed, on the report page.** The servant's cohort and date were wiped, and the roster they had loaded was dropped with them. |
| 5 | `/servant/questions` | **An edit dropping the server's failure.** The server's answer vanished the moment the admin corrected the field it was about: the cubit's edit writer answers a keystroke by replacing the form's text, and the answer went with it. |
| 6 | `/servant/report` | **An in-flight answer landing under a form that had moved on.** The report cubit's answer for **cohort 3** landed under a form that said **7**. |

**AND THEY REDUCE TO TWO MISTAKES**, which are the two the mechanism is built to
remove:

1. **A write the program made, reported as a write the reader made.** Instances
   **1** and **5** are that mistake seen twice: the page wrote the state's value
   into a controller, the controller told its listener, and the listener was the
   page's own way of reporting a keystroke.
2. **A controller seeded from the program instead of read back from the state.**
   Instances **2**, **3** and **4** are that mistake three times: the page
   *seeded* the cubit with the controllers' contents at mount, and the
   controllers start empty.

**INSTANCE 6 IS THE CLASS'S THIRD SHAPE, AND IT LIVES IN THE CUBIT.** A request
that answers a form that has moved on is the request writing over a state the
reader has already changed, and **no field can see it** — the fix there is a
staleness rule in the cubit, not a mirror. It is named here so that nobody
mistakes the mechanism for a fix for it.

**THE RULE THAT STOPS THE CLASS.**

> **A value that is mirrored into a control is mirrored by the **one** controlled
> field, in **one** direction, and a programmatic write is never reported as the
> reader's.**

**THE MECHANISM IS `lib/core/design_system/widgets/eva_controlled_field.dart`** —
a controlled field that takes the value, reports **only the reader's input**, and
owns its `TextEditingController` so that the page does not have to.

**AND HOW IT TELLS THE READER'S INPUT FROM ITS OWN WRITE IS **THREE
COMPARISONS**, NOT A FLAG.** The servant pages use a `_writing` boolean, and it
works — but a boolean has to be set and cleared around **every** write, and the
failure mode of a boolean that is not set is exactly defect **1**. The
controlled field compares instead:

| question | answer | what it buys |
| --- | --- | --- |
| *is the controller's new text the controlled value?* | then it is **the widget's own write** — or an echo of a value the state already holds — and **nothing is reported** | the server's draft arrives, the field fills, and the cubit is **not** told the admin typed it |
| *is the controlled value the last text the widget reported?* | then the state has **caught up with the reader**, and **nothing is mirrored back** | the mirror's trigger stays unambiguous: **the state moving somewhere the reader did not put it** |
| *did the controlled value move at all?* | if it did not, **nothing is mirrored** | a rebuild that does not change the value does not take the character the reader has just typed off the screen and put it back on the next one |

**The first comparison is the crux, and it works because the widget only ever
writes the controlled value into its controller.** There is no other write, so
"the controller's text is the controlled value" is not a coincidence to be
detected — it is the only thing that can have happened. **And the comparison is
against the controlled value and not only against the last reported text**,
because the state can move for a reason the reader had nothing to do with — the
server's draft arrives, the cubit resets the form — and a comparison against the
last reported value alone would read those as *the reader typing* and report
them, which is defect **1** again.

**THE GATE IS `test/core/design_system/widgets/mirrored_controller_check_test.dart`,
and the command is**

```bash
flutter test test/core/design_system/widgets/mirrored_controller_check_test.dart
```

**IT SCANS ALL OF `lib/`** — not the widget directories, which is the structural
mistake `orphan_widget_check.py` was built to fix, and here the filter would have
found **none** of the six sites, because every one of them is a page. The rule is
that a `TextEditingController` may only be **created** in the controlled field or
in the login page; the allowlist is a **file plus the normalised text of each
declaration**, and **a stale row is a failure** — the same rule
`test/setstate_budget_test.dart` applies to its `setState` rows — so the
servant rows are **live** and the portal's migration cannot land without the row
it retires being re-read.

**THE LOGIN PAGE IS THE ONE DELIBERATE EXCEPTION, AND ITS RECEIPT IS CHECKED
RATHER THAN ASSERTED.** It is allowed to own controllers because its form is
**one-way**: the reader types, the page reports, the bloc records, and **nothing
ever flows back** — the gate asserts that the page **never assigns to a
controller's text**, so the bloc's state is never mirrored into the field and
there is no mirror here to get wrong. And the state is cleared on every path
that unmounts the page: `LoginPage.build` dispatches `AuthStarted` on every
build, `AuthBloc._onStarted` emits a **fresh** `AuthState` in both of its arms,
and a fresh `AuthState` holds an empty email and an empty password — while the
page's two controllers are created empty. The screen and the state therefore
start every mount in agreement, and only the reader's own keystroke moves either
of them afterwards.

**AND THE COST, STATED RATHER THAN HIDDEN.** The controlled field is **one more
abstraction over `EvaTextField`**, and a reader who knows `EvaTextField` now has
to know this too. The price is paid in exchange for the gate: the gate can say
*one file may create a `TextEditingController`*, because the pattern is in one
place instead of in every page that mirrors a value — and **a page that needs a
controller for something other than a mirrored value has to say why it is not
mirroring one**, which is the question the gate asks. The mechanism also does
**not** fix the cubit half of instances **5** and **6**: whether a keystroke
clears a failure, and whether a stale answer may land on a form that has moved
on, are rules in the cubit, and no field can see either.

**189. THE PORTAL'S MIGRATION LANDED, AND IT BROUGHT A **SEVENTH** DEFECT WITH
IT.**

**THE EIGHTEEN HAND-ROLLED MIRRORS ARE GONE.** The three pages and the option
editor held **eighteen** `TextEditingController`s between them, and every one of
them was the shape decision 188 forbids. They are on `EvaControlledField` now,
so the mirrored-controller gate's allowlist went from **twenty-one** reviewed
sites to **three** — the mechanism's one and the login page's two — and the
number is **pinned at three**, so a row that comes back has to be re-read to
bring it. The orphan gate's entry for the mechanism was deleted in the same
change, with the receipt left in its place, and the gate said so:
`STALE ALLOWLIST  EvaControlledField  is allowlisted but IS placed`.

**AND THE PORTAL'S **SEVENTH** DEFECT IS THE **SAME CLASS**, AND IT IS THE
**FIRST ONE THE MIGRATION'S OWN MECHANISM DID NOT CATCH.** A draft is a
question the **AI** wrote about **one** reading's passage, and the reading id
is a field the admin may correct — so a draft for reading A can be on screen
while the form names reading B, and the commit would then store **B's id with
A's question**. MEASURED over `QuestionAuthoringCubit`:

```text
the request asked for = [aaaaaaaa-…aaa]
the form says = bbbbbbbb-…bbb
the draft on screen = A question about the FIRST reading
the commit went to reading = bbbbbbbb-…  the committed prompt = A question about the FIRST reading
```

**`requestDraft` IS A **READ** — THE `ai-generate` ROUTE WRITES NOTHING.** It
selects the reading, extracts the verses, calls the AI and returns the draft
(`ai.routes.ts:47-110`), so its answer is a **picture of the form's result** and
it goes when the form moves on. And **the reading id and the question type are
BOTH part of the request** and both are editable mid-flight — the reading id is
a field and the type is a control, and neither is disabled while the request is
open.

**SO THE TWO HALVES ARE THE HOUSE'S RULE, APPLIED TO A SECOND CUBIT.**

* **THE READ'S HALF — the draft is applied only if the form still describes
  the request.** The request's identity is **two** facts — the **reading** and
  the **type** — and both are remembered and both are compared when the answer
  lands. A comparison that forgot the type would be incomplete, and the defect
  it would leave is the same one. The shape is `ServantReportCubit`'s, and the
  cost is its cost: **a press whose answer arrives too late leaves the screen
  with nothing to show for it, and the admin presses again.**
* **THE WRITE'S HALF — a commit refuses a draft that belongs to another
  reading.** Even with the read fixed, an admin can have a draft for reading A
  on screen, change the reading id to B, and commit. **The draft remembers the
  reading it was asked for** — `QuestionAuthoringState.draftReadingId` — and
  the commit refuses to send it against a different one. **A refusal is better
  than a wrong write**, and it is **visible**: the admin is told why, and the
  way out is in the sentence.

**AND THE REFUSAL IS ABOUT A **DRAFT**, AND NOT A BAN.** `draftReadingId` is
`null` for a question the **admin** wrote, and a question the admin wrote is
the admin's — so the counter is in the suite, and the counter is what makes the
rule a rule and not a prohibition.

**AND THE READING ID IS **NOT** LOCKED WHILE THE REQUEST IS IN FLIGHT, AND
THAT IS A PRODUCT DECISION.** Disabling the field would close the window at
the source, and it was **not** done: the two rules above make the window
**harmless** — a stale read is dropped and a wrong write is refused — while
locking it would take away the admin's ability to **correct** a reading id
they mistyped while a request was open, which the screen explicitly supports
("the one the schedule answered with **or one you typed**"). A field that
cannot be corrected while a request is open is a field that strands the admin
with a request they cannot stop and an id they cannot fix.
