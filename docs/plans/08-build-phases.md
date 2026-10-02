# Build Phases

Ten ordered phases, each ending in `flutter analyze` clean and its tests green.

**Contains §10** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [File map](07-file-map.md) · [Quality gates](09-quality-gates.md)

---

## 10. Build phases

Each phase: implement → `flutter analyze` clean → tests green → commit. Do not start phase *N+1* until phase *N* is green.

### Phase 0 — Scaffolding

`pubspec.yaml` dependencies and fonts · `main.dart` bootstrap with `configureDependencies()` · `analysis_options.yaml` tightening · `build.yaml` restricting `generate_for` to `lib/**/*_page.dart` and `lib/app/router/**` · baseline `flutter test`.

**Stub pages are mandatory here, not optional.** Phase 4 declares routes for all 7 pages, but those pages are not written until Phases 5–9. Without stubs, `app_router.dart` references 7 undefined `*Route` symbols and `build_runner` fails — the plan deadlocks at Phase 4. Create all 7 as one-line placeholders and replace them in place as features land:

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

Same for `home_page.dart`, `reading_page.dart`, `quiz_page.dart`, `result_page.dart`, `profile_page.dart`, `settings_page.dart` — each in its own feature's `presentation/pages/`, matching the [[07-file-map.md](07-file-map.md) §7 file map](07-file-map.md#7-file-map). Later phases edit the file in place; they never add a new route.

**Verify:** `flutter analyze` clean; `flutter test` green; `dart run build_runner build` produces all 7 `*Route` classes.

### Phase 1 — Tokens & theme

All files under `tokens/` + `theme/`. Both themes complete with all 12 tokens (defects #4, #5, #6). `google_fonts` wiring. Domain-purity CI grep in place.

**Verify:** a test asserting every `EvaColors` field is non-null and dark ≠ light for all 12 tokens; a test asserting `StickerPalette` has 7 entries and every `PassageCategory` maps to a distinct colour.

### Phase 2 — Effects (`NeuralBackground`, `GlassSurface`)

`hue_rotate_matrix.dart` · `neural_motion.dart` (`EvaNeuralMotion` + `NeuralMotionScope` — see [09-quality-gates.md](09-quality-gates.md) [09-quality-gates.md](09-quality-gates.md) §13.2 for the `TickerProviderStateMixin` host) · `neural_background.dart` (`CustomPaint`, `RepaintBoundary`, no per-frame `setState`) · `glass_surface.dart` (`.tint` + `.blur`) · `gold_flecks.dart`.

**Verify:** golden tests per `NeuralVariant` × theme; a test asserting no `setState` occurs during an animation frame; a test that `NeuralTier.low` renders zero orb layers.

### Phase 3 — Tier-1 primitives

All primitive widgets. Every one: a golden per theme, a per-state golden for interactive states, and a semantics test.

**Verify:** `GlassSurface.blur` vs `.tint` goldens differ; `SegmentedControl` selects via keyboard.

### Phase 4 — Routing + DI

`app_router.dart` · `auth_guard.dart` · `injection.dart` + modules · `app.dart` · global fade-slide transition.

**Verify:** a router test that pushes `/` unauthenticated and asserts it redirects to `/login` and resumes on `onResult(true)`.

### Phase 5 — `auth` feature

Domain → data → `AuthBloc` → `LoginPage`. Real `TextField`s, real validation, real error states (fixes #8, #10). Portrait and landscape layouts (fixes #9).

**Verify:** `bloc_test` for sign-in success/failure; a widget test that typing a short password surfaces the error helper text.

### Phase 6 — `library` feature

`Passage` entities + local datasource · `LibraryBloc` · `HomePage` with `NeuralScaffold`, `AppTopBar` (fixes #11), `ContinueReadingPanel`, `CategoryFilterBar`, `PassageCard` grid.

**Fixes #1 here** — the filter must actually filter. Test: select "Poetry" and assert only poetry cards render.

### Phase 7 — `reading` feature

One `ReadingPage` for both languages · `ScriptureBlock`/`ScriptureVerse` with `WidgetSpan` drop cap · `ReadingControls` direction-aware · `StickyCta` · `ReadingCubit` (bookmark, font scale, verse numbers).

**Fixes #2 here** — Arabic never uses the mono family. Test: assert no `Text` widget in the AR tree has a `Space Mono` font family.

### Phase 8 — `quiz` feature

`Question`/`QuizSession` entities · `QuizBloc` · `QuizPage` (real 5-question flow, **no** Frame A/B toggle — defect #12) · `ResultPage` with `SunBurst`, `StatRow`, `StreakPill`.

**Verify:** `bloc_test` for select → check → next → complete; a widget test that `QuizOptionCard` shows `correct` + `GoldFlecks` after checking.

### Phase 9 — `profile` + `settings`

Shared `SettingsGroup`/`SegmentedControl`/`EvaToggle`/`FontSizeStepper` used by **both** pages (dedupe the prototype's duplication) · `JourneyTimeline` · `SettingsCubit` persists via the settings repository.

**Fixes #7 here** — the FAB Language item opens a real language sheet.

**Verify:** changing the theme in Settings rebuilds the whole app; Profile and Settings share the identical `SegmentedControl` instance type.

### Phase 10 — Polish

`EmptyState`/`ErrorView` wired into every async page · `TextScaler` from the font step · reduced-motion honours `MediaQuery.disableAnimationsOf` · semantics pass over all 7 pages.

**Verify:** the semantics suite passes; the app renders correctly at 320×568, 390×844, and 430×932.

---
