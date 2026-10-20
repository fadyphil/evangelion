# SEAMS.md — where this codebase turns

Seven seams. Each is a place where the answer to a question changes shape. Knowing
these seven is enough to read anything else in `lib/` — everything else is detail you
can look up.

Dependency direction, always inward:

```Graph
presentation ──▶ domain ◀── data
```

`core/domain/` and every `features/*/domain/` are **pure Dart**. No feature may import
another feature. If two features need the same type, it belongs in `core/domain/`.

---

## Seam 1 — `Result<T>`: the error contract

`lib/core/common/result.dart` (a typedef) · `lib/core/common/failure.dart` (the type)

```dart
typedef Result<T> = Either<Failure, T>;   // fp_dart, and Either is SEALED
```

**What it is.** Two arms: `Right<T>` carries the value, `Left<Failure>` carries a typed
error. A `Failure` is a `FailureKind` (12 members: `network`, `timeout`,
`unauthorized`, `forbidden`, `notFound`, `conflict`, `validation`, `server`,
`serialization`, `cancelled`, `storage`, `unknown`), a verbatim `message`, and an
optional `statusCode`.

**Where it turns.** Every repository boundary. Nothing in `lib/` throws across one.

**Why it exists.** A `FakeReadingRepository` must be substitutable for
`DioReadingRepository` (§3, the LSP row). Both halves of that — never throws, always
returns — are enforced by the type, not by discipline.

**What you must know to read it:**

1. **`Either` is `sealed`**, so `switch` over a `Result` is an exhaustive switch
   *expression* with no `default` arm. A third arm would break the build of every
   file that switches on it. This is the property the whole seam rests on.
2. **`fold` takes its arguments failure first**: `result.fold(onFailure, onSuccess)`.
   The hand-written type it replaced took `fold({onSuccess:, onFailure:})`.
3. **`Failure` is hand-written and must stay so.** Three things fpdart cannot give:
   `details` is excluded from equality (a rebuilt-but-equivalent decoded body must not
   look like a state change in bloc state), `toString` deliberately omits `details` (a
   server body must not reach a log line), and `==` guards on `runtimeType`.
4. **No `value` getter and no `getOrNull`.** Either would turn a `FailureResult` into a
   `null` that surfaces three frames later in a widget build. Read with `fold`, or with
   `valueOrElse` when losing the failure is an explicit decision.
5. **`isRight()` / `isLeft()` are methods, not getters.** fp_dart's spelling.

**The known gap.** `Right.operator ==` never mentions the type parameters
(`either.dart:572`), so `Right<Failure,int>(1) == Right<Failure,num>(1)` is `true`. The
hand-written type guarded this (decision 131). It cannot be restored by subclassing —
a subclass does not match its supertype's object pattern, which would break the
exhaustiveness in point 1. Pinned as observed behaviour in `test/core/common/result_test.dart`.

**What breaks if you move it.** Everything. 40 `lib/` and 59 `test/` files import it, and
the sealed-exhaustiveness property is what lets a compiler error stand in for a
reviewer at every seam.

---

## Seam 2 — the DI split

`lib/app/di/injection.dart` · `lib/app/di/navigation_injection.dart` · `modules/*.dart`

The graph is in **two files on purpose**. `injection.dart`'s entire transitive
project-local import graph must stay **Flutter-free** — a test walks it and fails
otherwise. That constraint is what splits the graph.

| Half | Registers |
| --- | --- |
| `injection.dart` (generated) | **30** — data sources, mappers, repositories, use cases, `Dio` |
| `navigation_injection.dart` (hand-written) | **10** — every Bloc/Cubit, `AppRouter`, `AuthStatus`, `ReevaluateListenable`, `SettingsHandle` |

**Why 10 are hand-written.** `bloc` is a transitive dependency and may not be promoted
(§8.4); the only available spelling, `flutter_bloc`, re-exports Flutter's widget layer.
So there is no spelling of "generate this registration" that keeps Flutter out of the
closure. `AppRouter` is the same problem via its generated `.gr.dart`.

**Two lifetime traps, both learned the hard way:**

- **`registerSingleton`, never a factory**, for anything with a stream. A factory that
  re-ran would hand out a *second* bloc with its own state. `QuizState.lastResult` is
  the only holder of the submit response, so a second `QuizBloc` would leave `/result`
  permanently unbuildable.
- **`AppRouter` is a `lazySingleton`** — a factory guarantees a second router with its
  own `navigatorKey` and no `Navigator` behind it.

**Where it turns.** `bootstrapApp` (`lib/app/bootstrap.dart`) — 5 steps, order
load-bearing. `WidgetsFlutterBinding.ensureInitialized()` first (a platform channel with
no binding under it throws). `installPackageDefaults()` second, before DI and before any
widget, because it rewrites mutable statics. `configureDependencies()` third —
`Future<void>` and awaited, and the `await` is deliberate. `configureNavigation()`
fourth, **because** `AppRouter`'s provider reads `AuthStatus` out of the locator as it
constructs.

**Also lives here:** the sign-out listener that clears `/`'s state. `AuthBloc` cannot
dispatch `HomeCleared` (different feature — Gate 2), and the reverse is closed too, so
`lib/app/` is the only place allowed to know both. It fires on
`status == AuthSessionStatus.signedOut`, **not** on `!isSignedIn` — which is also true
of `signingIn`, so the first version blanked `/` in the middle of every successful
sign-in.

---

## Seam 3 — the data path

`port → repository → data source → Dio → raw JSON → mapper → freezed entity → bloc state → widget`

```Tree
TodayReadingPanel
  └─ Bloc ─┬─ LoadTodayReading (use case)
  │        └─ ReadingRepository   ← PORT, declared in core/domain
  │            └─ DioReadingRepository   ← ADAPTER, in features/*/data
  │                └─ ReadingRemoteDataSource  → Dio.get → Object?
  │                    └─ TodayReadingMapper   → Result<TodayReading>
  └─ HomeState (freezed) → rebuild
```

**Where it turns.** At the port. `core/domain/repositories/` declares the four ports;
`features/*/data/` implements them. Every adapter is registered **against its port**,
never the concrete class, so no bloc or page ever names `DioReadingRepository`.

**What you must know to read it:**

- **Mappers are hand-written and return `Result<T>`.** No `json_serializable` (decision
  8c). `leaderboard_mapper.dart` reads keys as literals rather than case-folding,
  deliberately.
- **`text_clean` exists only in Arabic.** English localized responses have **no such
  key at all** — absent, not null. The mapper takes it when present and `text` otherwise.
- **The backend's ids are not all UUIDs, and today's IS one.** Measured
  2026-10-11: today's `reading_id` is the seeded `aaaaaaaa-…`; any `?date=` is
  auto-provisioned and gets `reading-group-3-<date>`. So **do not validate them as
  UUIDs** — a validator would be right today and wrong tomorrow. They are echoed,
  never authored. See `docs/BACKEND-VERIFICATION.md`.
- **Two error body shapes.** `{"error","message"}` is the only one this server emits;
  `{statusCode, code, error, message}` **appears nowhere in it**. The mapper accepts both
  — it costs one branch and a later backend may add it — but the test group for the
  second is named `SYNTHIC — defensive branch, a body this server cannot produce`.
- **`Failure.details` is populated only for that synthetic branch.**

**What breaks if you move it.** The mapper is the only place that knows the wire shape.
Moving JSON knowledge into an entity leaks transport into the domain and fails Gate 1.

---

## Seam 4 — Bloc / Cubit state and `freezed`

`features/*/presentation/bloc/`

States and events are `@freezed`. Three states disable its generated `copyWith`
(`@Freezed(copyWith: false)`) and write **whole-state writers** instead
(`withReading`, `withStreak`, `withReader`) — so adding a field means editing every
writer, each of which restates all 13 fields of `HomeState`.

**Which three, and why it matters.** `copyWith` is disabled on the three **largest**
states (`HomeState` 13 fields, `AuthState` 10, `QuizState` 5) and kept on the three
smallest (`LeaderboardState` 4, `ReadingState` 4, `SettingsState` 3). The cost grows
with the field count, which is backwards from what reuse is for.

**What the writers actually buy.** Not safety in general. A generated `copyWith` *can*
clear a nullable field — freezed gives nullables a `freezed` sentinel so `null` means
"clear this" — so that argument is false. What it cannot do is express a **cross-field
invariant**. `state.copyWith(readingStatus: failed, readingFailure: f)` leaves
`reading` holding its old value, so the triple disagrees with itself; `withReading`
forces the caller to state all three.

`HomeState`'s six writers are justified by that — four independently-failing backend
endpoints, each a `status · payload · failure` triple. **No equivalent invariant is
recorded for `QuizState` or `AuthState`**, and `AuthState` hand-rolls a partial
`copyWith` (`auth_bloc.dart:366`) to get part of it back. Audit and evidence in
`DRIFT.md` §6 — recorded, not decided.

**The trap that reads as a feature.** Three classes override `toString` to keep a
secret out of logs: `LoginCredentials`, `AuthState`, `AuthPasswordChanged`. freezed
generates `toString` and *skips* the member when the class declares one — but nothing
in a green suite distinguishes "freezed respected my override" from "freezed replaced
it". A generated one writes a reader's typed password into every log line and every
failed `expect`. `test/core/common/result_test.dart` and
`test/core/common/failure_test.dart`'s sibling
`test/core/common/secret_masking_test.dart` are **structural** for this reason: they
scan `lib/` for any class declaring a `final String password` and require a `toString`
that does not interpolate it.

**Where it turns.** The event, not the constructor. `HomeStarted(language)` carries the
locale — a constructor parameter cannot work, because the bloc is registered once for
the process, so a language fixed at construction would be the language at *launch* for
the rest of the run.

**A bloc created in `setUp` does not drive a `testWidgets` tree.** `setUp` runs outside
the test body's fake-async zone, so events land on a queue `tester.pump()` never drains:
`bloc.state` is correct and `find.text(...)` returns **zero**. Every suite that mounts a
bloc builds it **in the test body**, with `addTearDown(…close)`.

---

## Seam 5 — the router and its guard

`lib/app/router/app_router.dart` · `auth_guard.dart`

**9 entries in `AppRouter.routes`**: the guarded dock shell at `/` with its three tab
children, `/login`, `/reading`, `/quiz`, `/settings`, and a `RedirectRoute` for `*`.
**`/result` is not one of them** — it is a modal over the quiz, not a route.
**9 constants** exist in `app_routes.dart` (the seven screens, `/servant`, and the `*`
fallback); `/servant` is declared deliberately unrouted.

**And the count in a paragraph is a claim that nobody checks, while a count in a
test is a claim that fails.** The two paragraphs above were three tasks out of
date once — `/leaderboard` was renamed `/communion` in Task 5.5 and `/journey` was
added in Task 5.6 — and nothing caught it, which is the drift `docs/DRIFT.md`
catalogues. The **route inventory test** spells its list out instead of counting
for exactly that reason.

**The guard.** `AuthGuard` depends on `AuthStatus` — one member, `bool get
isAuthenticated` — not on `AuthBloc`, which did not exist when it was designed.

Four contracts:

1. **`isAuthenticated` is a pure read.** Cheap, no fetch. The guard calls it on every
   navigation and every stack re-evaluation.
2. **It must not throw, and the guard does not catch one.** A throw escapes
   `onNavigation`, the router builds nothing, and on a cold launch that is a blank first
   frame. Failing closed *silently* would be indistinguishable from a logout on a
   guard that is explicitly **not a security boundary**.
3. **A fresh guard per route per read** — so no two can disagree about the session.
4. **`AuthGuard` latches inside `_redirectToLogin`.** `NavigationResolver` may be
   completed exactly once; a second completion is an `AssertionError` in debug and a
   `StateError` in release — **on every successful sign-in**, because
   `redirectUntil` resolves its own resolver as soon as the redirect lands.

**`AppRouter` overrides `config()`** to append an `AutoRouteObserver`. `RootStackRouter`'s
default is `const []`, and `AutoRouteAwareStateMixin` guards on `if (_observer != null)` —
so the whole re-entry mechanism was a **silent no-op** and `/` never re-loaded on
return. Overridden rather than passed at the two call sites, "because the whole defect
was a default nobody overrode."

**The result is not in this table, because it is not a route.** `/result` retired to
a modal over the quiz (`eva/redesign.html:718-727`) in Phase 6.2, so `AppRoutes.result`
does not exist, `ResultRoute` is not generated, and the result is presented with
`showGeneralDialog` from `QuizPage` — the submit response is the only artifact the
card renders, there is nothing to re-fetch it from, and a modal is not a destination.

---

## Seam 6 — `NeuralBackground` and the performance budget

`core/design_system/effects/` · `docs/plans/09-quality-gates.md` §13

Five mandatory mitigations. The two that bite hardest:

- **No `setState` per frame.** `ListenableBuilder` + `RepaintBoundary` confines the
  repaint to the background layer.
- **Three controllers app-wide** (float, hue, aurora), published through a scope —
  **not** per screen and **not** looked up per orb. 8 screens × 4 orbs × 2 animations
  becomes 3.

**§13.4's blur budget: one site per screen, and `/` has spent it.** A `BackdropFilter`
is a `saveLayer` per frame. `kGlassBlurSigma` is **24** — the superseded prototype's own
number for Home's hero panel (`blur(24px)`), because only one site blurs and there is
nothing to compromise between eight hand-written radii. **The redesign draws a
counterpart and its number is `12`, not `24`**: the home card's
`backdrop-filter:blur(12px)` (`redesign.html:250`). The client keeps the prototype's
`24`, so the two sides differ, and the difference is stated here rather than left for
a reader to discover against a line that says something else.

**Every animation must check `MediaQuery.disableAnimationsOf(context)`.** This is why
`EvaAnimate` exists rather than using `flutter_animate` directly: the package reads no
accessibility flag, so every direct call site is a fresh violation, invisibly.

---

## Seam 7 — theme, locale and font scale

`core/design_system/theme/` · `lib/app/app.dart` · `features/settings/`

Settings are **local only** (`shared_preferences`, no server sync). `app.dart` sets
`ThemeMode.dark` **explicitly and still does** — any comment promising otherwise is stale.

**The accent splits into a fill and an ink**, and only the light values differ:

| token | dark | light | used for |
| --- | --- | --- | --- |
| `ember` | `#E8A33D` | `#D4891A` | fills: buttons, chips, beads, flame |
| `emberInk` | `#E8A33D` | **`#845610`** | text, drop caps, verse numbers |

One value cannot do both jobs: as a **fill** it must stay light enough that `onEmber`
reads on it; as **text** on a pale surface it must clear 4.5:1, and light `ember`
measured **2.11:1**. In dark the pairs are identical **on purpose** — the accent already
clears 6.97:1 there, so a second name would be a second way to change the same thing.

`test/core/design_system/tokens/text_contrast_gate_test.dart` checks the **worst**
surface, not the nominal one. `GlassSurface` composites over whatever is beneath, so a
token that passes on `canvas` and fails on glass is the common failure.

**Arabic typography.** `Amiri` is the only bundled family that renders Arabic.
`arabicAware()` is identity under LTR and a family swap under RTL. Four strings reached
`/` in a Latin-only face and every glyph rendered as tofu — found by the gate the moment
the component was **placed on a screen**, not when it was tested in English.

---

## The one thing that ties all seven together

**Every one of these has a gate, and every gate has been caught reporting a false green
at least once.** That history is the reason `tool/verify_purity.sh` treats a gate that
*could not run* differently from a gate that *found nothing*, and why the timestamp
check in `tool/verify_linux_build.sh` has a `--check-only` mode: an unreachable
assertion inside a gate added to stop a false green is the worst outcome available.

If you add a gate, plant a violation and prove it fires before you believe it passes.
