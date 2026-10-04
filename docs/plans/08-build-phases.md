# Build Phases

Eleven ordered phases, each ending in `flutter analyze` clean and its tests green.

**Contains §10** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [File map](07-file-map.md) · [Quality gates](09-quality-gates.md) · [Authority](../agents/AGENT_CONTEXT.md)

---

## 10. Build phases

Each phase: implement → `flutter analyze` clean → tests green → commit. Do not start phase *N+1* until phase *N* is green.

> **Scope correction.** Two feature phases lost half their scope. Library and Profile were cut ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 1), and the data layer is now a **live API** rather than bundled JSON ([§15](10-open-decisions.md#resolved) decision #1). Phase 5 therefore builds the Dio client, the identity-header interceptor, the dual-shape error mapper and the **fake** auth repository; Phases 6–8 build remote data sources and mappers instead of local JSON.
>
> **Phase numbers are pre-cut and deliberately not renumbered**, so the "Phase" column in [01-source-analysis.md](01-source-analysis.md) §2 and every `Phase N` reference in the defect table keep resolving. Phase 6 is now the `home` phase and Phase 9 the `settings` phase; the library half and the profile half are marked **Cut** below. The six screens in [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2 are the authority on what ships, not the phase numbers.

### Phase 0 — Scaffolding

**Dependencies.** `flutter_bloc 9.1.1` · `equatable 3.0.0` · `auto_route 11.2.0` + `auto_route_generator 10.6.0` · `build_runner 2.16.1` · `get_it 9.3.0` + `injectable 3.0.0` · `dio 5.11.1` · `google_fonts 9.0.0` · `mocktail 1.0.5` · `bloc_test 10.0.0`. One addition over that list: **`shared_preferences`**, without which the settings feature has nowhere to persist ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 4). Nothing else may be added — §8.4 of that document makes an unlisted dependency a hard stop.

**Fonts.** The five families are already committed under `assets/fonts/` — Cormorant Garamond, EB Garamond, DM Sans, Amiri, Space Mono, instanced to the exact weights the design system uses so Flutter never resorts to synthetic bolding. Declare them in `pubspec.yaml` under `flutter: fonts:`. They are bundled rather than fetched so goldens resolve offline; wire `google_fonts` only as a documented fallback, never as the load path. `test/flutter_test_config.dart` loads them with `FontLoader` before the suite ([09-quality-gates.md](09-quality-gates.md) §11).

**`AppConfig`.** `lib/core/common/app_config.dart` — base URL from `--dart-define=API_BASE_URL` defaulting to `http://localhost:3000`, request timeout, and the seeded group id `3` ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §5). Never hardcode the URL at a call site.

**DI bootstrap.** `configureDependencies()` in `lib/app/di/injection.dart`, wired from `main()`, with `core_module.dart` registering `Result`/`AppConfig`/the error mapper and `AppRouter` as a **factory**.

**Android `INTERNET` permission.** The debug and profile manifests already carry it; the **release** manifest does not, and a real device hitting `http://localhost:3000` fails silently without it. Add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`.

**Stub pages are mandatory here, not optional.** Phase 4 declares routes for all six screens, but those pages are not written until Phases 5–9. Without stubs, `app_router.dart` references six undefined `*Route` symbols and `build_runner` fails — the plan deadlocks at Phase 4. Create all six as one-line placeholders and replace them in place as features land:

```dart
// lib/features/auth/presentation/pages/login_page.dart
@RoutePage()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Login')));
}
```

Same for `home_page.dart`, `reading_page.dart`, `quiz_page.dart`, `result_page.dart`, `settings_page.dart` — each in its own feature's `presentation/pages/`, matching the [[07-file-map.md](07-file-map.md) §7 file map](07-file-map.md#7-file-map). Later phases edit the file in place; they never add a new route.

Also in this phase: `analysis_options.yaml` tightening (`avoid_dynamic_calls`, and `--fatal-infos` discipline from [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §4) · `build.yaml` restricting `generate_for` to `lib/**/*_page.dart` and `lib/app/router/**` · `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` in `main()` · baseline `flutter test`.

**Verify:** `flutter analyze` clean; `flutter test` green; `dart run build_runner build` produces all 6 `*Route` classes; `flutter build apk --debug` succeeds with the INTERNET permission present.

### Phase 1 — Tokens & theme

All files under `tokens/` + `theme/`. Both themes complete with all 12 tokens (defects #4, #5, #6). Font families declared. Domain-purity CI grep in place.

**Verify:** a test asserting every `EvaColors` field is non-null and dark ≠ light for all 12 tokens; a test asserting `StickerPalette` has 7 entries and that every `StickerSlot` maps to a distinct colour.

> `StickerSlot` is decorative only — it is no longer keyed to any domain type, because the category enum it was keyed to was cut ([04-widget-inventory.md](04-widget-inventory.md) Tier 0). The "every entry maps to a distinct colour" assertion is the whole test; do not add a category round-trip.

### Phase 2 — Effects (`NeuralBackground`, `GlassSurface`)

`hue_rotate_matrix.dart` · `neural_motion.dart` (`EvaNeuralMotion` + `NeuralMotionScope` — see [[09-quality-gates.md](09-quality-gates.md) §13.2](09-quality-gates.md#13-performance) for the `TickerProviderStateMixin` host) · `neural_background.dart` (`CustomPaint`, `RepaintBoundary`, no per-frame `setState`) · `glass_surface.dart` (`.tint` + `.blur`) · `gold_flecks.dart`.

**Verify:** golden tests per `NeuralVariant` × theme; a test asserting no `setState` occurs during an animation frame; a test that `NeuralTier.low` renders zero orb layers.

### Phase 3 — Tier-1 primitives

All primitive widgets. Every one: a golden per theme, a per-state golden for interactive states, and a semantics test.

**Verify:** `GlassSurface.blur` vs `.tint` goldens differ; `SegmentedControl` selects via keyboard.

### Phase 4 — Routing + DI

`app_router.dart` · `auth_guard.dart` · `injection.dart` + the seven modules · `app.dart` · global fade-slide transition.

**Verify:** a router test that pushes `/` unauthenticated and asserts it redirects to `/login` and resumes on `onResult(true)`; a router test that a cold push of `/result` renders `EmptyState` rather than calling the API.

### Phase 5 — `core/network` + `auth` feature

**Red-first, all of it** ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §6): the **dual-shape error mapper** (`{error, message}` *and* `{statusCode, code, error, message}`) · the **identity-header interceptor** (`X-User-Id` a valid UUID, `X-Group-Id` `3`, `X-User-Role` `kid`) · the `Dio` client · `FakeAuthRepository` · the auth session model.

Then `AuthBloc` → `LoginPage`. Real `TextField`s, real validation, real error states (fixes #8, #10). Portrait and landscape layouts (fixes #9).

> **There is no auth endpoint.** The backend performs no validation of any kind — identity is three headers — so `FakeAuthRepository` returns the seeded session and is the **only** `AuthRepository` adapter that ships ([10-open-decisions.md](10-open-decisions.md#resolved)). Do not write a Dio auth adapter, a token store, or a refresh flow. The port is still declared in `domain` and still honoured in full, so a `DioAuthRepository` can replace it later without touching `domain` or `presentation`.

**Verify:** `bloc_test` for sign-in success/failure; a widget test that typing a short password surfaces the error helper text; an error-mapper test asserting **both** body shapes map to the same `Failure`; an interceptor test asserting the three headers are present on every request.

### Phase 6 — `home` feature

`HomePage` with `NeuralScaffold`, `AppTopBar` (fixes #11), the **today's-reading panel**, and the streak flame — all fed by the API via `ReadingRepository` + `StreakRepository`. The panel's data comes from `GET /readings/today/{lang}` and `GET /streak/summary`.

> **Cut.** The library half of this phase is gone: `Passage` entities, a local datasource, `LibraryBloc`, `CategoryFilterBar`, and the `PassageCard` grid. **Defect #1 is therefore resolved by cut** — there is no filter to make work ([01-source-analysis.md](01-source-analysis.md) §2). `ContinueReadingPanel` is gone too; the today's-reading panel replaces it and stays feature-local.

**Verify:** `bloc_test` covering loading / success / error; a widget test that a failed reading fetch renders `ErrorView` with a working retry, not a blank panel.

### Phase 7 — `reading` feature

`ScriptureText`/`Verse`/`Question` entities · the **remote data source** (`GET /readings/today/{en,ar}`) and its **mapper** · one `ReadingPage` for both languages · `ScriptureBlock`/`ScriptureVerse` with `WidgetSpan` drop cap · `ReadingControls` direction-aware · `StickyCta` · `ReadingCubit` (the font step; **no** verse-number flag and **no** `SettingsRepository` — see decisions 56 and 57).

**Fixes #2 here** — Arabic never uses the mono family, at **nine** sites and not two ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 54), and the prototype's nine turned out to be the **floor**: three more Arabic sites exist only in this client because §14 gave four unlabelled prototype buttons accessible names. Test: `reading_glyph_test.dart` parses the five bundled TTFs and asserts every character it walks is carried by the family that renders it — strictly stronger than "no `Text` has a Space Mono family", which passes for a screen that rendered nothing. **It used to say "every character on the screen" and that was false by thirty tofu boxes**, because a `Tooltip` paints nothing until a gesture: the walk is now `Future`-returning and holds each tooltip open past `kLongPressTimeout` before it reads the tree.

**Verify:** a mapper test asserting `text_clean` maps to `null` for the English payload, where the key is **absent** rather than empty ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §5, trap 2).

> **The `409` clause is Phase 8's, not this phase's.** `POST /readings/:id/submit` is the quiz feature's call, and no submit request is made from `/reading`. The mapping itself is already covered — `api_error_mapper_test.dart` asserts a `409` becomes a typed `Failure` rather than a thrown exception — so nothing is deferred; the endpoint simply does not exist yet to be called.

### Phase 8 — `quiz` + `result` features

`QuizSession`/`QuizAnswer`/`SubmitResult` entities · the `SubmitResult` model and its mapper · `QuizBloc` · `QuizPage` (real question flow, **no** Frame A/B toggle — defect #12) · `ResultPage` with `SunBurst`, `StatRow`, `StreakPill`, fed by the last `SubmitResult`.

`StartSession`, `RefreshSessionQuestions`, and `SubmitAnswer` all run through the `ReadingRepository` port — `quiz` declares no repository and no data source of its own, and the `POST /readings/:id/submit` call rides `reading`'s remote data source. `RefreshSessionQuestions` exists because the backend has **no `GET /readings/:id`**; it re-fetches today's reading rather than trusting cached `already_answered` flags.

> **Cut.** Reflection history is gone with the library: there is no `get_reflection_history.dart` and no `complete_session.dart`. `/result` reads the submit response held by `QuizBloc` and has no repository, no use case, and no API call of its own.

**Verify:** `bloc_test` for select → check → next → complete; a widget test that `QuizOptionCard` shows `correct` + `GoldFlecks` after checking; a test that a question with `already_answered == true` renders disabled rather than discovering the `409` at submit time.

### Phase 9 — `settings` feature

Shared `SettingsGroup`/`SegmentedControl`/`EvaToggle`/`FontSizeStepper` · `SettingsCubit` · `SettingsRepository` backed by `shared_preferences`. Appearance, reading, and about.

> **Cut.** The profile half of this phase is gone: no `ProfileCubit`, no `UserProfile`, no `JourneyTimeline`, no `ProfilePage`. `AppTopBar`'s avatar tap now opens `/settings`, and settings' back target is `/`.

**Fixes #7 here** — the FAB Language item opens a real language sheet.

**Verify:** changing the theme in Settings rebuilds the whole app; `SettingsGroup` and the settings screen share the identical `SegmentedControl` instance type; a test that a written setting survives a repository re-read.

### Phase 10 — Polish

`EmptyState`/`ErrorView` wired into every async page · `TextScaler` from the font step · reduced-motion honours `MediaQuery.disableAnimationsOf` · semantics pass over all 6 pages.

**Verify:** the semantics suite passes; the app renders correctly at 320×568, 390×844, and 430×932.

---