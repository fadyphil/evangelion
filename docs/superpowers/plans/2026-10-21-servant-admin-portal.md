# The Servant/Admin Portal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the servant/admin portal — a second surface in the Evangelion client where a `viewerServant` reads a cohort's daily roster report and an `adminServant` schedules readings and authors their questions, against the backend's existing admin, AI and report routes.

**Architecture:** A new `features/servant/` feature (feature-first, `presentation → domain ← data`, pure-Dart `domain/`) behind **two narrow ports** — `ServantAdminRepository` (schedule / commit / ai-draft) and `ServantReportRepository` (the daily report). Access is enforced client-side by a new `RoleGuard` beside the existing `AuthGuard`, reading the **existing** `RoleAccess` seam over `UserRole.grantsFor`. The role is chosen on `/login` (there is no auth endpoint) and flows into `AuthSession.role`; the `X-User-Role` header becomes a **live reader** over that same session so the client never claims `kid` while the UI says `admin_servant`.

**Tech Stack:** Flutter 3.47.4 / Dart 3.13.3, auto_route 11, bloc 9, freezed 4, dio 5, ARB + `gen_l10n`. **No new dependency** (AGENT_CONTEXT §8.4).

**Authority:** `docs/agents/AGENT_CONTEXT.md` §7 gates. This plan **reverses §2 decision 5**, and that amendment ships in Task 0, in the same change (`docs/adr/0026-the-servant-admin-portal.md`).

**The design this implements:** `docs/superpowers/specs/2026-10-21-servant-admin-portal-design.md`. **Read it before Task 1.** It carries the endpoint contracts, the entity shapes and the honest limits.

---

## Rules for every worker

1. **Read `docs/agents/AGENT_CONTEXT.md` in full before writing code.** It is the authority and it wins over this plan, over `docs/plans/`, and over any comment you remember.
2. **Red-first** for: domain entities, use cases, models and mappers, repositories, every cubit, `RoleGuard`, and every changed port. Write the failing test, **run it, and read the failure message** before you implement. A test that fails to compile is not a red.
3. **Behaviour + widget + golden tests alongside** widgets and screens — not test-first.
4. **No `setState`** in any new file (`test/setstate_budget_test.dart` is a gate). Mutable state lives in a cubit, and a cubit is a whole-state writer.
5. **No `// ignore:`** in `lib/` or `test/`. No `print` (use `debugPrint`). No `dynamic`.
6. **No colour literals** — everything through `EvaColors` via the design-system barrel. **No new `BackdropFilter`** outside `glass_surface.dart` (the `lib/features/` blur budget is **1** today).
7. **The backend is read-only.** Never write to `/home/fady/Projects/EvangelionBackend`.
8. **One agent runs `build_runner` at a time.** Never run it concurrently with another agent. If you need codegen, say so and stop.
9. `dart run build_runner clean` — **not** `--delete-conflicting-outputs` (removed in build_runner 2.16.x; the flag is ignored and still exits 0).
10. **Every gate you touch, you negative-control.** Plant the violation in a scratch copy **outside** the repository, confirm the non-zero exit and the message, remove it.

### The commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool   # gate 1
dart analyze --fatal-infos --fatal-warnings                     # gate 2
tool/verify_purity.sh                                            # gate 3
python3 tool/gates/citation_check.py                             # gate 4a
python3 tool/gates/orphan_widget_check.py                        # gate 4b
dart fix --dry-run                                               # gate 5
flutter test                                                     # gate 6
flutter test --coverage                                         # gate 7
tool/verify_all.sh --with-build                                 # gates 1-8
```

**Use `flutter test`, never `dart test`** — the plain Dart VM has no `dart:ui` and cannot load any test file.

---

## Task 0 — The authority change (docs only, no code)

**Files:**
- Create: `docs/adr/0026-the-servant-admin-portal.md`
- Modify: `docs/agents/AGENT_CONTEXT.md` (§2 decision 5; the §2 route table; a recorded decision at the end)
- Modify: `lib/core/navigation/app_routes.dart` (`servant` constant's paragraph)

- [ ] **Step 1: write `docs/adr/0026-the-servant-admin-portal.md`** from `docs/adr/template.md`. Context: the user reversed §2 decision 5 on 2026-10-21; the backend's admin/AI/report routes exist and are unused by the client; the backend enforces **no** role (`rg 'user\??\.role' src/` → no matches, `rg '403' src/` → no matches), so the portal's role gate is advisory UX. Decision: the `servant` feature ships, two admin types, the role is chosen on `/login`. Alternatives: (a) *no portal* — the status quo, rejected because the user asked for it; (b) *a real auth endpoint* — rejected, the backend has none and the backend is read-only; (c) *one admin type* — rejected, the backend's union has three roles and a read-only servant is a real need. Consequences: Better — the client covers the backend's whole admin surface; Worse — the client now holds three screens' worth of forms with no prototype to transcribe, and the role gate is not a boundary; Neutral — `docs/plans/` is out of date and is not edited (§8.6).
- [ ] **Step 2: amend AGENT_CONTEXT §2 decision 5** with the text in the spec §2. Keep the table's shape: one row, the amended text.
- [ ] **Step 3: add the four routes to AGENT_CONTEXT §2's route table** — `/servant`, `/servant/report`, `/servant/schedule`, `/servant/questions` — with their data source (`API`) and their capability.
- [ ] **Step 4: replace `app_routes.dart`'s `servant` paragraph.** The paragraph currently says the path is "declared, not yet routed" and demands "the successor that registers the portal route replaces this paragraph". Replace it with the successor's text: it is routed, it is the hub, and it is the landing route for both servant roles.
- [ ] **Step 5: verify** — `dart format --output=none --set-exit-if-changed lib test tool` and `dart analyze --fatal-infos --fatal-warnings` (the doc edit touches a Dart file).
- [ ] **Step 6: commit** — `git add docs lib/core/navigation/app_routes.dart && git commit -m "docs(adr): the servant portal ships, and the role gate is advisory"`

---

## Task 1 — The role, from the login form to the wire

**Files:**
- Modify: `lib/core/domain/entities/auth_session.dart` (no change needed — `role` already exists)
- Modify: `lib/features/auth/domain/usecases/sign_in.dart` (`SignInParams.role`)
- Modify: `lib/core/domain/repositories/auth_repository.dart` (`signIn(role:)`)
- Modify: `lib/features/auth/data/datasources/auth_local_data_source.dart` (`currentSession`, `seedAuthSession(role:)`)
- Modify: `lib/features/auth/data/repositories/fake_auth_repository.dart`
- Modify: `lib/features/auth/presentation/bloc/auth_bloc.dart` (`AuthState.role`, `AuthRoleChanged`)
- Modify: `lib/core/network/interceptors/identity_headers.dart` (`role` becomes a reader)
- Modify: `lib/app/di/modules/core_module.dart` (the interceptor's role reader)
- Modify: `lib/app/di/modules/auth_module.dart` (the `RoleAccess` registration — **pure** half)
- Create: `lib/features/auth/presentation/widgets/role_picker.dart`
- Test: `test/features/auth/…`, `test/core/network/…`, `test/app/di/…`

**This task changes a port.** `AuthRepository.signIn` gains a **required named** `role` parameter. The port is consumed by the `auth` feature and by `core/domain` readers, so every implementation and every fake in `test/` must be updated — grep for `signIn(` first.

- [ ] **Step 1 — red: `SignInParams` carries a role.** Add `test/features/auth/domain/usecases/auth_usecases_test.dart` case: `SignInParams(email:…, password:…, role: UserRole.adminServant).role == UserRole.adminServant`. Run `flutter test test/features/auth/domain/usecases/auth_usecases_test.dart` → **FAIL** (`role` is not a parameter). Then add `final UserRole role;` to `SignInParams` (required, named) and pass it through `SignIn.call`.
- [ ] **Step 2 — red: the port takes a role.** In `test/features/auth/data/fake_auth_repository_test.dart`, assert that `signIn(email:…, password:…, role: UserRole.adminServant)` yields a session whose `role` is `adminServant`, and that `seedAuthSession` takes the role. Run → **FAIL**. Then change the port (`signIn({required String email, required String password, required UserRole role})`), `FakeAuthRepository` (it builds the seeded session with the requested role), and `seedAuthSession({required DateTime createdAt, UserRole role = UserRole.kid})`. **Update every other caller and fake** — `rg -n "signIn\(" lib test`.
- [ ] **Step 3 — red: the store's synchronous view.** In the same test file, assert `AuthLocalDataSource.currentSession` is `null` before a write and is the written session after one. Run → **FAIL**. Then add `AuthSession? get currentSession => _session;` with a doc comment saying the store is an in-memory field by design and the async `readSession()` remains the port's read.
- [ ] **Step 4 — red: the interceptor's role is a reader.** In `test/core/network/…` (the identity-headers suite), assert that the header value follows the reader: build the interceptor with `role: () => 'admin_servant'`, fire a request, assert `X-User-Role` is `admin_servant`; then change the reader's answer and assert the **next** request carries the new value. Run → **FAIL** (the field is a `String` today). Then change `IdentityHeadersInterceptor.role` to `String Function()` and call it inside `onRequest`. `defaultRole` stays as the seed spelling; the constructor's `role` parameter becomes required (no default) so no call site can forget it — `buildApiDio` passes it through.
- [ ] **Step 5 — red: the `RoleAccess` registration is in the pure half.** In `test/app/di/injection_test.dart` (or `navigation_injection_test.dart` — whichever owns the graph), assert `getIt<RoleAccess>()` resolves and that `getIt<RoleAccess>().role` is `UserRole.kid` before a session exists. Run → **FAIL** (nothing registers it). Then, in `lib/app/di/modules/auth_module.dart` (the **pure** half — it must stay Flutter-free), add:
  ```dart
  @lazySingleton
  RoleAccess get roleAccess => LiveRoleAccess(
    () => getIt<AuthLocalDataSource>().currentSession?.role ?? UserRole.kid,
  );
  ```
  and in `core_module.dart` feed the interceptor from it:
  ```dart
  Dio apiClient(@Named('apiBaseUrl') String baseUrl, RoleAccess roleAccess) => buildApiDio(
    baseUrl: baseUrl,
    identity: IdentityHeadersInterceptor(
      userId: kSeedUserId,
      role: () => roleAccess.role.wireValue,
    ),
    …
  );
  ```
  **The reader must be the session's role, not a mirror of it** — one session, one role, read from two angles.
- [ ] **Step 6 — red: the bloc carries the chosen role.** In `test/features/auth/presentation/bloc/auth_bloc_test.dart`: dispatch `AuthRoleChanged(UserRole.adminServant)`, assert `state.role` is `adminServant`; then `AuthSubmitted` and assert the `SignIn` use case received that role. Run → **FAIL**. Then add `AuthRoleChanged` (a `freezed` event) and `AuthState.role` (default `UserRole.kid`), and pass `state.role` into `SignInParams` in `_onSubmitted`. **Run `dart run build_runner build` — you own the codegen for this slice.**
- [ ] **Step 7 — the role picker widget (tests alongside).** Create `lib/features/auth/presentation/widgets/role_picker.dart`: a `SegmentedControl` over the three `UserRole` values, with an `onChanged` callback, a `selected` value, and a semantic label per option. Write a widget test alongside it: it renders three options, reports the tap, and marks the selected one. **No `setState`** — the parent owns the value.
- [ ] **Step 8 — wire the picker into `LoginPage`.** In `lib/features/auth/presentation/pages/login_page.dart`, render the picker above the CTA; its `onChanged` dispatches `AuthRoleChanged`. The picker is **not** a redesign transcription — `eva/redesign.html` has no role picker — so **do not cite the prototype for it**, and say in the page's doc that the control is **written, not transcribed**, and why (there is no auth endpoint, so the role is a local choice). Extend `login_page_test.dart`: the picker is on the screen, and choosing a role puts it in the state.
- [ ] **Step 9: gates.** `dart format … lib test tool` → `dart analyze --fatal-infos --fatal-warnings` → `flutter test`. All green.
- [ ] **Step 10: commit** — `git add lib test && git commit -m "feat(auth): the role is chosen on the login form and reaches the wire"`

---

## Task 2 — Navigation: the guard and the route constants

**Files:**
- Create: `lib/app/router/role_guard.dart`
- Modify: `lib/core/navigation/app_routes.dart` (three new constants)
- Test: `test/app/router/role_guard_test.dart`, `test/core/navigation/app_routes_test.dart`

> **The routes are registered in Task 5, not here** — the router may not name a
> page that does not exist, and the pages arrive in Task 4. Task 2 builds the
> guard and the constants, both of which are testable on their own.

- [ ] **Step 1 — red: `RoleGuard` refuses.** Create `test/app/router/role_guard_test.dart`: with a `RoleAccess` whose role is `UserRole.kid` and a required capability of `viewServantReport`, the guard **redirects** to the landing route and does **not** allow the navigation; with `adminServant` it allows it. Also assert the guard **never throws** — a throwing seam propagates, exactly as `auth_guard_test.dart` asserts for `AuthStatus`. Run → **FAIL** (no such file). Then write `lib/app/router/role_guard.dart`: an `AutoRouteGuard` taking a `RoleAccess` and a `UserCapability`, answering `onNavigation` with `router.replaceAll([const HomeRoute()])`-style redirection to `landingRouteFor(access.role)`, and **not** catching anything.
- [ ] **Step 2 — red: the route constants.** Extend `test/core/navigation/app_routes_test.dart`: the new constants are plain string literals, unique, slash-prefixed, and derived correctly. Run → **FAIL**. Then add to `app_routes.dart`:
  ```dart
  static const String servantReport = '/servant/report';
  static const String servantSchedule = '/servant/schedule';
  static const String servantQuestions = '/servant/questions';
  ```
  **They are root-level absolute paths, not children of `/servant`** — the hub is a page, not an `AutoTabsRouter`, so it has no children. `tool/route_check.dart` parses this file for plain-literal initialisers; a derived or non-literal value makes the gate exit 1.
- [ ] **Step 3: gates** — format, analyze, `flutter test`.
- [ ] **Step 4: commit** — `git commit -m "feat(nav): a role guard that refuses, and the servant route constants"`

---

## Task 3 — The `servant` feature's domain and data (pure Dart, no Flutter)

**Files:** as listed in the spec §5. Plus `lib/app/di/modules/servant_module.dart`.

- [ ] **Step 1 — red: the entities.** Create `test/features/servant/domain/entities/servant_entities_test.dart`: `ReadingSchedule` carries every field the endpoint expects; `QuestionDraft` round-trips its options; `ScheduleResult.readingIds` is a list of strings; `RosterStudent.questionsProgress` is the server's `"3/5"` string verbatim. Run → **FAIL**. Then write the entities with `freezed` (`@freezed` + `part '…_freezed.dart'`), matching the repo's entity convention. **Run `dart run build_runner build` — you own the codegen for this slice.**
- [ ] **Step 2 — red: the two ports.** Create `test/features/servant/domain/repositories/servant_repositories_test.dart` with hand-written fakes implementing each port, asserting the contract: every method returns a `Result`, none throws. Run → **FAIL**. Then write the two port interfaces exactly as the spec §5.1 states them.
- [ ] **Step 3 — red: the use cases.** One use case per port method, each `implements UseCase<In, Out>` (or `NoParamsUseCase<Out>` where there is no input — **read `lib/core/domain/usecase/usecase.dart` first**: `NoParamsUseCase` does **not** extend `UseCase<void, Out>` and cannot). Run → **FAIL**, then implement.
- [ ] **Step 4 — red: the mappers.** Create `test/features/servant/data/mappers/servant_mappers_test.dart` with **transcribed** payloads (the backend's shapes, from `EvangelionBackend/src/modules/admin/admin.routes.ts` and `ai.routes.ts`) → assert the domain values. Pay attention to: the schedule body uses **snake_case** (`group_ids`, `scheduled_date`, `book_number`, `start_chapter`, `start_verse`, `end_chapter`, `end_verse`, `excluded_verses`, `generate_ai_questions`); the commit body uses `reading_id`, `questions[]` with `prompt_ar` / `prompt_en` / `correct_answer` / `points_value` / `sort_order` / `is_approved`, and `options` is `Map<String, {ar, en}>`; the report's `students[]` uses `user_id`, `full_name`, `preferred_lang`, `total_points`, `current_streak`, `points_earned_today`, `completed_today`, `questions_progress`. Run → **FAIL**, then implement.
- [ ] **Step 5 — red: the data source and the repositories.** Create `test/features/servant/data/repositories/…` with a mocked `Dio` (`dio` + `mocktail`) asserting the **exact** paths and bodies: `POST /api/v1/admin/readings/schedule`, `POST /api/v1/admin/questions/commit`, `POST /api/v1/admin/questions/ai-generate`, `GET /api/v1/servant/reports/daily?group_id=3&date=2026-10-21`. **The `/api/v1` prefix belongs to the endpoint definitions, not the host** (`core/network/dio_client.dart`). Run → **FAIL**, then implement the data source and the two repository implementations. A repository **never throws** across its seam — every fault is a `Result.failure`, and the HTTP errors go through the existing `ApiErrorMapper`.
- [ ] **Step 6 — the DI module.** Create `lib/app/di/modules/servant_module.dart` with the two repository providers (typed as the **ports**) and the four use-case providers, mirroring `auth_module.dart`. **This module is pure Dart** — no `flutter_bloc`, no pages. Run `dart run build_runner build` (you own the codegen).
- [ ] **Step 7: gates** — format, analyze, `tool/verify_purity.sh` (the new `features/servant/domain/` must be pure), `flutter test`.
- [ ] **Step 8: commit** — `git commit -m "feat(servant): the ports, the entities and the adapters for the admin routes"`

---

## Task 4 — The `servant` feature's presentation

**Files:** the three cubits, the four pages, the two widgets, under `lib/features/servant/presentation/`.

- [ ] **Step 1 — red: the three cubits.** `test/features/servant/presentation/cubit/…`: with `bloc_test` + `mocktail`, each cubit's happy path, its failure path, and its busy state. **The cubits are whole-state writers** (ADR-0009): a handler builds the whole state, never patches it. Run → **FAIL**, then implement. **Run `dart run build_runner build` — you own the codegen for this slice.**
- [ ] **Step 2 — the hub page.** `lib/features/servant/presentation/pages/servant_home_page.dart`: a `NeuralScaffold` listing the sections this role has — "daily report" for both servant roles, "schedule a reading" and "author questions" for `adminServant` — plus a **"read as a reader"** entry that pushes `/`. **The entries come from `UserRole.grantsFor`, not from an `if` ladder** — one table, read in one place. Widget test alongside: a `viewerServant` sees the report entry and **not** the schedule entry; an `adminServant` sees all three; the "read as a reader" entry pushes `/`.
- [ ] **Step 3 — the report page.** `servant_report_page.dart`: a group id and a date field, a submit, and the roster — `StatTile`s for the totals and a row per student (`roster_row.dart`). Widget test alongside: the roster renders, the empty case renders `EmptyState`, and a failure renders `ErrorView` with the server's message.
- [ ] **Step 4 — the schedule page.** `schedule_reading_page.dart`: **every parameter the endpoint expects** — group ids, the date, the book number, the start chapter/verse, the end chapter/verse, the excluded verses, and the AI switch. Widget test alongside: the form validates the range (the server rejects `start > end` with `400 "start boundary cannot be after end boundary"`), and the AI switch is labelled with what it does.
- [ ] **Step 5 — the questions page.** `question_authoring_page.dart`: takes a `readingId`; the admin either writes the question by hand (prompt AR, prompt EN, the options, the correct answer, the points, the sort order) or asks for an AI draft and edits it, then commits. Widget test alongside: the draft fills the fields, the fields survive an edit, and the commit sends the edited values.
- [ ] **Step 6: gates** — format, analyze, `flutter test`. **The orphan-widget gate is NOT run yet**: it fails on a page the router does not name, and the router names these pages in Task 5.
- [ ] **Step 7: commit** — `git commit -m "feat(servant): the hub, the report, the schedule form and the question editor"`

---

## Task 5 — Navigation: registering the routes and the landing

**Files:**
- Modify: `lib/app/router/app_router.dart` (register the four routes; add the role guard)
- Modify: `lib/features/auth/presentation/pages/login_page.dart` (land on `landingRouteFor`)
- Test: `test/app/router/app_router_test.dart`, `test/features/auth/presentation/pages/login_page_test.dart`

- [ ] **Step 1 — red: the routes are registered.** Extend `test/app/router/app_router_test.dart`: `router.matcher.match('/servant')` names a servant route (**not** `HomeRoute` with `redirectedFrom='*'` — that wildcard match is the shape a *declared but unrouted* path has today, and it is the failure this step removes); same for the three sub-routes. Run → **FAIL** (the wildcard swallows them). Then register the four routes in `app_router.dart` with the guards:
  ```dart
  AutoRoute(path: AppRoutes.servant, page: ServantRoute.page, guards: [AuthGuard(_authStatus), RoleGuard(_roleAccess, UserCapability.viewServantReport)]),
  AutoRoute(path: AppRoutes.servantReport, page: ServantReportRoute.page, guards: [AuthGuard(_authStatus), RoleGuard(_roleAccess, UserCapability.viewServantReport)]),
  AutoRoute(path: AppRoutes.servantSchedule, page: ScheduleReadingRoute.page, guards: [AuthGuard(_authStatus), RoleGuard(_roleAccess, UserCapability.scheduleReading)]),
  AutoRoute(path: AppRoutes.servantQuestions, page: QuestionAuthoringRoute.page, guards: [AuthGuard(_authStatus), RoleGuard(_roleAccess, UserCapability.manageQuestions)]),
  ```
  **The wildcard `*` stays last** (moving it up turns every path into `/` — measured at 46 tests). **Run `dart run build_runner build` — you own the codegen for this slice.**
- [ ] **Step 2 — red: the landing route has a caller.** Extend the router test: after a sign-in as `adminServant`, the stack's top is `/servant`; as a `kid`, it is `/`. Run → **FAIL**. Then wire it: on `LoginOutcome.signedIn`, the login page's outcome handler replaces the stack with `landingRouteFor(state.session!.role)`. **The landing is the *role's* route, not the interrupted navigation's** — and the `AuthGuard`'s resume path must not fight it. Record the choice in the page's doc.
- [ ] **Step 3 — red: a kid cannot reach the servant shell.** Extend the router test: a push to `/servant` while the session's role is `kid` lands on `/` and never builds the servant page; the same push as `adminServant` lands on `/servant`. Run → **FAIL**, then make it pass. **This is the negative control the whole access rule rests on** — the hub having no admin entry is decoration; the guard refusing is the mechanism.
- [ ] **Step 4: gates** — format, analyze, `flutter test`, `python3 tool/gates/orphan_widget_check.py` (the four new pages are now registered, so the gate's roots include them).
- [ ] **Step 5: commit** — `git commit -m "feat(nav): the servant routes exist, and a kid cannot reach them"`

---

## Task 6 — Strings, DI and the final wiring

- [ ] **Step 1 — the strings.** Add the new keys to `lib/l10n/app_en.arb` **and** `lib/l10n/app_ar.arb` — the app is bilingual and the admin screens are not an exception. The Arabic arm is a real translation, not a transliteration. Then run **`flutter gen-l10n`** (this is **not** `build_runner`) and **`dart format lib/l10n`** — `gen_l10n`'s raw output is not format-clean, and the generated files are committed **formatted**.
- [ ] **Step 2 — the cubits' DI.** The three cubits `extend Cubit`, so they hit the recorded wall (`flutter_bloc` re-exports the widget layer) and are **hand-registered** in `lib/app/di/navigation_injection.dart` with `registerSingleton`, exactly as `AuthBloc` / `HomeBloc` / `QuizBloc` are. **Not** in `servant_module.dart` — a provider there would put `package:flutter/material.dart` inside `injection.dart`'s graph and `injection_test.dart` would fail.
- [ ] **Step 3 — the `RoleAccess` in the router.** The router needs a `RoleAccess` to build the `RoleGuard`s. It is registered in the **pure** half (Task 1, step 5), so the router reads it from the locator: `AppRouter(this._authStatus, this._authChanges, this._roleAccess)`. **Update every construction site of `AppRouter`** — `lib/app/di/navigation_injection.dart` and `test/support/app_harness.dart` — and extend `navigation_injection_test.dart` to assert the router reads the **live** role (change the session's role and assert the guard's answer moved).
- [ ] **Step 4: gates** — format, analyze, `flutter test`, `tool/verify_purity.sh`, both python gates.
- [ ] **Step 5: commit** — `git commit -m "build(servant): the strings, the hand-registered cubits and the router's role seam"`

---

## Task 7 — The gates, the coverage floor and the negative controls

- [ ] **Step 1: `tool/verify_all.sh --with-build`** — all eight. **Paste the summary in the report.** A gate that could not run is `FATAL` (exit 2), not a pass.
- [ ] **Step 2: the coverage floor.** `flutter test --coverage` → compare against `tool/baseline/gates.txt`. The floor is a **budget of uncovered lines**, not a percentage. If the budget is exceeded, **cover the code** — do not re-record the floor. Re-recording is a deliberate, reviewed decision and never a way to make a red run green.
- [ ] **Step 3: negative-control every gate this work touched.** In a scratch copy **outside** the repository (`/tmp/opencode/…`): plant a Flutter import in `features/servant/domain/` (gate 3 must exit 1), a `features/quiz` import in `features/servant/` (gate 3), an unregistered `@RoutePage()` (gate 4b must exit **1**, not 2), a new `setState` (the setState gate), a colour literal (the colour gate), a second blur in `lib/features/` (the blur gate). Record each command, the exit code and the message.
- [ ] **Step 4: the orphan-widget gate's roots.** It derives the router from auto_route's `@AutoRouterConfig()` marker — **zero matches or more than one is FATAL (exit 2)**. The four new pages are registered, so the gate has four more roots; a bogus `@RoutePage()` is a failure.
- [ ] **Step 5: commit** — `git commit -m "test(servant): the gates, the coverage floor and the negative controls"` (if the floor or a gate needed fixing).

---

## Task 8 — The recorded decisions and the review

- [ ] **Step 1: the recorded decisions.** Append to `docs/agents/AGENT_CONTEXT.md` a "Recorded decisions — the servant portal" section stating, with `file:line` evidence: the reversal of decision 5; the hub-not-tab-shell choice; the live `X-User-Role` reader and why the role is one source read twice; the two ports and why they are not one; the three AI doors and why the draft's options shape makes a draft committable; and the two backend behaviours the UI states (upsert, delete-on-AI).
- [ ] **Step 2: `docs/DRIFT.md`.** If any claim in the repository is now false — the §2 route table, the "no admin portal" line, `app_routes.dart`'s "declared, not routed" — record the correction.
- [ ] **Step 3: the review.** Dispatch a code-review agent over the branch (`main..HEAD`) and a security-review agent over the new code. Fix what they find; a finding is not a finding until it is fixed or explicitly declined with a reason.
- [ ] **Step 4: the final gate run** — `tool/verify_all.sh --with-build`, pasted.
- [ ] **Step 5: the report** — the format in AGENT_CONTEXT §9: status, what was implemented, what was tested with **actual** pass/fail counts, the files changed, self-review findings, concerns.

---

## What this plan does **not** do

* No backend change (read-only reference material).
* No new dependency.
* No `docs/plans/` rewrite.
* No real authentication, no server-side role enforcement.
* No "list my scheduled readings" screen — the endpoint does not exist.
* No editing or deleting a committed question — the endpoint does not exist.
