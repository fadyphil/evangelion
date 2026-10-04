# File Map

Every file to be created, and the rule that governs where it lives.

**Contains §7** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Architecture](02-architecture.md) · [Build phases](08-build-phases.md) · [Authority](../agents/AGENT_CONTEXT.md)

---

## 7. File map

> **Scope correction.** Library and Profile were cut — see [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 1. Data is now a **live API** at `http://localhost:3000`, not bundled JSON ([§15](10-open-decisions.md#resolved) decision #1). This map therefore gains a `core/network/` tier and a `core/common/app_config.dart`, and the per-feature `data/` folders hold models, mappers and remote data sources rather than local corpora.
>
> **Six feature folders, six routes.** `auth`, `home`, `reading`, `quiz`, `result`, `settings` — one per shipped screen, matching the six routes in [06-navigation.md](06-navigation.md) §8 and the per-feature use cases in [05-domain-model.md](05-domain-model.md) §9.4.
>
> **Shared kernel.** `home`, `reading` and `quiz` all need `ReadingRepository`, and `quiz` and `result` both need `SubmitResult`. Placing those in any single feature would force cross-feature imports. Entities and ports consumed by **two or more** features therefore live in `core/domain/` — pure Dart, imported by everyone. Each `features/<f>/domain/` then holds only that feature's own use cases. Placement rule and the full type list: [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §3.

```tree
lib/
  main.dart                                   # bootstrap: fonts, DI, edge-to-edge, runApp
  app/
    app.dart                                  # MaterialApp.router + theme + locale
    router/
      app_router.dart                         # @AutoRouterConfig RootStackRouter
      guards/auth_guard.dart                  # AutoRouteGuard + reevaluateListenable
    di/
      injection.dart                          # @InjectableInit configureDependencies()
      modules/
        core_module.dart                      # Result, failure mapper, AppConfig, AppRouter
        auth_module.dart
        home_module.dart
        reading_module.dart
        quiz_module.dart
        result_module.dart
        settings_module.dart

  core/
    design_system/
      tokens/
        eva_colors.dart  eva_typography.dart  eva_spacing.dart
        eva_radii.dart   eva_motion.dart      eva_elevations.dart
        sticker_palette.dart  eva_fonts.dart
      theme/
        eva_theme.dart  eva_theme_dark.dart  eva_theme_light.dart
      effects/
        neural_background.dart
        neural_motion.dart                    # the shared 3-controller bundle
        glass_surface.dart                    # the blur recipe behind widgets/glass_surface.dart
        gold_flecks.dart
        hue_rotate_matrix.dart                # hue matrix for ColorFilter
      widgets/
        neural_scaffold.dart  glass_surface.dart  eva_button.dart
        eva_text_field.dart    eva_chip.dart      progress_beads.dart
        stat_tile.dart         settings_tile.dart settings_group.dart
        eva_section_header.dart  segmented_control.dart  eva_toggle.dart
        font_size_stepper.dart icon_action_button.dart  hairline_divider.dart
        text_link.dart         empty_state.dart   error_view.dart
        avatar_badge.dart      streak_flame.dart  sun_burst.dart
        passage_drop_cap.dart  seal_monogram.dart
        app_top_bar.dart       brand_lockup.dart
        seal_fab.dart          fab_dock_item.dart
      barrel.dart                            # single import surface
    common/
      result.dart                             # Result<T>
      failure.dart                            # Failure + FailureKind
      app_config.dart                         # base URL via --dart-define, timeouts, seeds
      di_annotations.dart
    domain/                                   # SHARED KERNEL — pure Dart, no Flutter/Dio
      usecase/usecase.dart                    # UseCase<In,Out>, NoParamsUseCase<Out>
      repositories/
        reading_repository.dart               # home, reading, quiz
        streak_repository.dart                # home, result
        auth_repository.dart                  # auth, app
        settings_repository.dart              # settings, app
      entities/
        scripture_text.dart  verse.dart       # home, reading
        question.dart  scripture_language.dart  question_type.dart   # home, quiz
        quiz_session.dart  quiz_answer.dart   # quiz, result
        submit_result.dart                    # quiz, result
        streak_summary.dart  today_status.dart # home, result
        auth_session.dart                     # auth, app
        user_settings.dart  app_theme_mode.dart # settings, app
    network/
      dio_client.dart                         # the one Dio: baseUrl, timeouts, interceptor order
      api_error_mapper.dart                   # BOTH body shapes -> Failure (red-first)
      interceptors/
        identity_headers.dart                 # X-User-Id / X-Group-Id / X-User-Role
    navigation/
      app_routes.dart                         # route name constants

  features/
    auth/
      domain/
        usecases/sign_in.dart  sign_out.dart  get_current_session.dart
      data/
        datasources/auth_local_data_source.dart      # persists the seeded session locally
        repositories/fake_auth_repository.dart       # the ONLY adapter today
      presentation/
        bloc/auth_bloc.dart  auth_event.dart  auth_state.dart
        pages/login_page.dart
        widgets/social_auth_button.dart  google_mark.dart  apple_mark.dart

    home/
      domain/
        usecases/get_todays_reading.dart  get_streak_summary.dart
      data/
        # no data/ of its own — Home consumes the ports implemented in reading/
      presentation/
        bloc/home_bloc.dart  home_event.dart  home_state.dart
        pages/home_page.dart
        widgets/todays_reading_panel.dart           # replaces the cut continue-reading hero

    reading/
      domain/
        usecases/get_scripture_text.dart  get_streak_summary.dart  get_settings.dart
      data/
        # There is **no `models/` directory**, and these five names are not files.
        # `ReadingRemoteDataSource` parses the response into `ScriptureText` in one
        # step, so a `ScriptureTextModel`/`VerseModel`/`QuestionModel` trio would be
        # three classes whose only field is a copy of the entity's, and a mapper that
        # then copies them back ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2,
        # decision 68). `streak_summary_mapper.dart` is the sibling that proves the
        # pattern generalises: two features, both mapping straight to domain entities.
        mappers/today_reading_mapper.dart  streak_summary_mapper.dart
                                           # text_clean is AR-only; never asserted
        datasources/reading_remote_data_source.dart  # GET /readings/today/{en,ar}
                     streak_remote_data_source.dart
        repositories/dio_reading_repository.dart     # implements ReadingRepository
                     dio_streak_repository.dart
      presentation/
        bloc/reading_cubit.dart            # ReadingStatus and ReadingState live here too
        pages/reading_page.dart                       # ONE page, both languages
        widgets/reading_controls.dart  scripture_block.dart
               reading_header.dart  sticky_cta.dart
        # Two names here are **not** files. `scripture_verse.dart` is a private method
        # on `ScriptureBlock` (`_verseParagraph`) — the verse needs the block's derived
        # body style, its marker style and the first-verse-only drop cap, so a widget
        # would be four required parameters and no behaviour ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md)
        # §2, decision 67). `scripture_metadata_row.dart` is `ReadingHeader`'s metadata
        # section: the reference, the translation and the caption are one row in the
        # prototype and one widget here, and splitting it would give a widget with one
        # call site.

    quiz/
      domain/
        usecases/start_session.dart  refresh_session_questions.dart  submit_answer.dart
      data/
        models/submit_result_model.dart
        mappers/submit_result_mapper.dart
        # no repository of its own — StartSession / RefreshSessionQuestions /
        # SubmitAnswer all run through reading's ReadingRepository port
      presentation/
        bloc/quiz_bloc.dart  quiz_event.dart  quiz_state.dart
        pages/quiz_page.dart
        widgets/quiz_option_card.dart  quiz_header.dart  feedback_banner.dart
               gold_flecks_overlay.dart

    result/
      presentation/
        bloc/result_cubit.dart  result_state.dart    # wraps QuizBloc's last SubmitResult
        pages/result_page.dart
        widgets/result_score.dart  streak_pill.dart  stat_row.dart
      # no domain/ and no data/ — the submit response is the whole data source

    settings/
      domain/
        usecases/get_settings.dart  update_settings.dart
      data/
        datasources/settings_local_data_source.dart   # shared_preferences; no server sync
        repositories/settings_repository_impl.dart    # implements SettingsRepository
      presentation/
        cubit/settings_cubit.dart  settings_state.dart
        pages/settings_page.dart

test/
  core/design_system/widgets/    # golden + semantics per primitive
  core/design_system/theme/      # token assertions, both themes
  core/network/                  # dual-shape error mapper, header interceptor, AppConfig
  core/domain/                   # entity + port unit tests (pure Dart, no mocks needed)
  features/*/domain/usecases/    # fake-repository unit tests
  features/*/data/               # model + mapper tests, incl. the AR-only text_clean
  features/*/presentation/bloc/  # bloc_test
  features/*/presentation/pages/ # per-screen widget tests
  app/router/                    # navigation graph test
  flutter_test_config.dart       # FontLoader for the bundled families, so goldens are offline
```

> **Cut.** The whole `library/` tree is gone — `domain/entities/passage.dart`, `passage_category.dart`, `reading_progress.dart`, `domain/repositories/passage_repository.dart`, three browse/filter use cases, `data/models/passage_model.dart`, `datasources/passage_local_data_source.dart`, `data/repositories/passage_repository_impl.dart`, `presentation/bloc/library_*.dart`, `widgets/continue_reading_panel.dart`, `widgets/category_filter_bar.dart`, and `widgets/screen_section_header.dart` (its role is now `EvaSectionHeader`, one shared widget). The backend serves no passage list and no category taxonomy ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 1), so there is nothing for the tree to read.

> **Cut.** The whole `profile/` tree is gone — `domain/entities/user_profile.dart`, `reflection_record.dart`, `entities/user_settings.dart`, `repositories/profile_repository.dart`, three profile use cases, `data/models/user_profile_model.dart`, `datasources/profile_local_data_source.dart`, `data/repositories/profile_repository_impl.dart`, `presentation/cubit/profile_cubit.dart`, `pages/profile_page.dart`, `widgets/journey_timeline.dart`, and `widgets/journey_row.dart`. The settings half is **not** cut: it moves to `features/settings/`, where its `SettingsRepository` is now backed by `shared_preferences` rather than a local data source ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 4).

> **Cut.** `core/design_system/widgets/eva_progress_bar.dart` is gone. Its only call site was the `height: 3` bar inside the library grid card, and cutting the card removed the only site ([04-widget-inventory.md](04-widget-inventory.md) §3.1). Its private `_PassageProgress` fallback went with it, since it lived in `passage_card.dart`.

**Barrel policy:** `core/design_system/barrel.dart` is the only import path for design-system widgets. `core/common/*` never imports `flutter/material.dart`.

### 7.1 The four additions that are new since the original plan

| Tier | Files | Why it exists |
| --- | --- | --- |
| `core/common/app_config.dart` | 1 | The base URL is a `--dart-define`, not a literal, so pointing the app at a deployed host is a build flag. It also carries the seeded group id and the request timeout. |
| `core/network/dio_client.dart` | 1 | One `Dio` instance, configured once, so the base URL, timeouts and interceptor order are declared in a single place instead of per repository. |
| `core/network/api_error_mapper.dart` | 1 | The backend emits **two** error body shapes — `{error, message}` and `{statusCode, code, error, message}` — so the mapping lives behind one seam rather than in each repository. Red-first ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §6). |
| `core/network/interceptors/identity_headers.dart` | 1 | Identity is three headers, not a token. Attaching them in an interceptor means no call site can forget one — and forgetting `X-Group-Id` is a `400`, not a `401`. Red-first. |

### 7.2 Counts

As listed above, `lib/` holds **146** Dart files:

| Area | Files |
| --- | --- |
| `main.dart` + `app/` | 12 |
| `core/design_system/` — `tokens` 8 · `theme` 3 · `effects` 5 · `widgets` 27 · `barrel` 1 | 44 |
| `core/common/` | 4 |
| `core/domain/` — `usecase` 1 · `repositories` 4 · `entities` 13 | 18 |
| `core/network/` | 3 |
| `core/navigation/` | 1 |
| `features/auth/` | 11 |
| `features/home/` | 7 |
| `features/reading/` | 17 |
| `features/quiz/` | 13 |
| `features/result/` | 6 |
| `features/settings/` | 10 |

`core/design_system/widgets/` holds the **27** design-system widgets — Tier 1's 18 primitives and Tier 3's shared composites. Tier 2's ambient widgets (`NeuralBackground`, `GoldFlecks`) live in `effects/`; `StreakFlame`, `SunBurst`, `AvatarBadge`, `PassageDropCap`, and `SealMonogram` are here. The remaining Tier 3 composites are feature-local and live under `features/*/presentation/widgets/` — see [04-widget-inventory.md](04-widget-inventory.md) §6.

> **Resolved: the shared kernel.** `home` and `quiz` both compose `ReadingRepository`, and `reading` and `result` both consume `StreakSummary` / `SubmitResult`. A port imported across feature boundaries conflicts with "no feature may import another feature" ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §3), and the purity gate in §7 of that document would match on exactly those lines.
>
> The resolution is a **shared kernel**: all four ports and every entity consumed by two or more features live in `core/domain/`, which is pure Dart and imported by everyone. Each `features/<f>/domain/` then holds only that feature's own use cases. `reading/data/` and `settings/data/` hold the two real implementations (`DioReadingRepository`, `SettingsRepository`); `auth/data/` holds the only other adapter, `FakeAuthRepository`. No feature imports another feature.

---