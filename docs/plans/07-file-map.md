# File Map

Every file to be created, and the rule that governs where it lives.

**Contains §7** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Architecture](02-architecture.md) · [Build phases](08-build-phases.md)

---

## 7. File map

```tree
lib/
  main.dart                                   # bootstrap: DI, fonts, runApp
  app/
    app.dart                                  # MaterialApp.router + theme + locale
    router/
      app_router.dart                         # @AutoRouterConfig RootStackRouter
      guards/auth_guard.dart                  # AutoRouteGuard + reevaluateListenable
    di/
      injection.dart                          # @InjectableInit configureDependencies()
      modules/
        core_module.dart
        auth_module.dart
        library_module.dart
        reading_module.dart
        quiz_module.dart
        profile_module.dart

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
        glass_surface.dart
        gold_flecks.dart
        hue_rotate_matrix.dart                # hue matrix for ColorFilter
      widgets/
        neural_scaffold.dart  glass_surface.dart  eva_button.dart
        eva_text_field.dart    eva_chip.dart      progress_beads.dart
        eva_progress_bar.dart  stat_tile.dart     settings_tile.dart
        settings_group.dart    segmented_control.dart  eva_toggle.dart
        font_size_stepper.dart icon_action_button.dart hairline_divider.dart
        text_link.dart         empty_state.dart   error_view.dart
        avatar_badge.dart      streak_flame.dart  sun_burst.dart
        passage_drop_cap.dart  seal_monogram.dart
      barrel.dart                            # single import surface
    common/
      result.dart                             # Result<T>, Failure
      usecase.dart                            # UseCase<In,Out>, NoParamsUseCase<Out>
      failure.dart
      di_annotations.dart
    navigation/
      app_routes.dart                         # route name constants

  features/
    auth/
      domain/
        entities/auth_session.dart
        repositories/auth_repository.dart
        usecases/sign_in.dart  sign_out.dart  get_current_session.dart
      data/
        models/auth_session_model.dart
        datasources/auth_remote_data_source.dart  auth_local_data_source.dart
        repositories/auth_repository_impl.dart
      presentation/
        bloc/auth_bloc.dart  auth_event.dart  auth_state.dart
        pages/login_page.dart
        widgets/social_auth_button.dart  google_mark.dart  apple_mark.dart

    library/
      domain/
        entities/passage.dart  passage_category.dart  reading_progress.dart
        repositories/passage_repository.dart
        usecases/get_passages.dart  get_continue_reading.dart
               filter_passages_by_category.dart
      data/
        models/passage_model.dart
        datasources/passage_local_data_source.dart
        repositories/passage_repository_impl.dart
      presentation/
        bloc/library_bloc.dart  library_event.dart  library_state.dart
        pages/home_page.dart
        widgets/continue_reading_panel.dart  category_filter_bar.dart
               screen_section_header.dart

    reading/
      domain/
        entities/scripture_text.dart  verse.dart  scripture_language.dart
        repositories/scripture_repository.dart
        usecases/get_passage_text.dart  toggle_bookmark.dart
      data/
        models/scripture_text_model.dart
        datasources/scripture_local_data_source.dart   # EN + AR corpora
        repositories/scripture_repository_impl.dart
      presentation/
        cubit/reading_cubit.dart  reading_state.dart
        pages/reading_page.dart                       # ONE page, both languages
        widgets/reading_controls.dart  scripture_block.dart  scripture_verse.dart
               scripture_metadata_row.dart  sticky_cta.dart

    quiz/
      domain/
        entities/question.dart  quiz_session.dart  quiz_answer.dart
                reflection_result.dart
        repositories/quiz_repository.dart
        usecases/start_session.dart  submit_answer.dart
               complete_session.dart  get_reflection_history.dart
      data/
        models/question_model.dart  quiz_session_model.dart
        datasources/question_local_data_source.dart
        repositories/quiz_repository_impl.dart
      presentation/
        bloc/quiz_bloc.dart  quiz_event.dart  quiz_state.dart
        pages/quiz_page.dart  result_page.dart
        widgets/quiz_option_card.dart  quiz_header.dart
               feedback_banner.dart  gold_flecks_overlay.dart
               result_score.dart  streak_pill.dart  stat_row.dart

    profile/
      domain/
        entities/user_profile.dart  reflection_record.dart  user_settings.dart
        repositories/profile_repository.dart  settings_repository.dart
        usecases/get_user_profile.dart  get_user_stats.dart  get_journey.dart
               get_settings.dart  update_settings.dart
      data/
        models/user_profile_model.dart  user_settings_model.dart
        datasources/profile_local_data_source.dart
               settings_local_data_source.dart
        repositories/profile_repository_impl.dart  settings_repository_impl.dart
      presentation/
        cubit/profile_cubit.dart  settings_cubit.dart
        pages/profile_page.dart  settings_page.dart
        widgets/journey_timeline.dart  journey_row.dart

test/
  core/design_system/widgets/    # golden + semantics per primitive
  core/design_system/theme/      # token assertions, both themes
  features/*/domain/usecases/    # fake-repository unit tests
  features/*/presentation/bloc/  # bloc_test
  features/*/presentation/pages/ # per-screen widget tests
  app/router/                    # navigation graph test
```

**Barrel policy:** `core/design_system/barrel.dart` is the only import path for design-system widgets. `core/common/*` never imports `flutter/material.dart`.

---
