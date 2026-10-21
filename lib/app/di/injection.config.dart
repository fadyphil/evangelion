// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../core/domain/repositories/auth_repository.dart' as _i497;
import '../../core/domain/repositories/cheer_repository.dart' as _i344;
import '../../core/domain/repositories/leaderboard_repository.dart' as _i307;
import '../../core/domain/repositories/reading_repository.dart' as _i499;
import '../../core/domain/repositories/settings_repository.dart' as _i896;
import '../../core/domain/repositories/sky_repository.dart' as _i946;
import '../../core/domain/repositories/streak_repository.dart' as _i682;
import '../../core/navigation/role_access.dart' as _i10;
import '../../core/network/api_error_mapper.dart' as _i998;
import '../../features/auth/data/datasources/auth_local_data_source.dart'
    as _i852;
import '../../features/auth/domain/usecases/get_current_session.dart' as _i606;
import '../../features/auth/domain/usecases/sign_in.dart' as _i920;
import '../../features/auth/domain/usecases/sign_out.dart' as _i568;
import '../../features/home/data/datasources/library_catalogue_local_data_source.dart'
    as _i76;
import '../../features/home/domain/library_catalogue_repository.dart' as _i56;
import '../../features/home/domain/usecases/get_reader_session.dart' as _i806;
import '../../features/home/domain/usecases/load_last_light.dart' as _i257;
import '../../features/home/domain/usecases/load_library_catalogue.dart'
    as _i151;
import '../../features/home/domain/usecases/load_streak_summary.dart' as _i605;
import '../../features/home/domain/usecases/load_today_reading.dart' as _i1067;
import '../../features/journey/data/datasources/medal_local_data_source.dart'
    as _i136;
import '../../features/journey/domain/medal_repository.dart' as _i988;
import '../../features/journey/domain/usecases/get_journey_reader_session.dart'
    as _i900;
import '../../features/journey/domain/usecases/load_journey_sky_count.dart'
    as _i592;
import '../../features/journey/domain/usecases/load_journey_streak_history.dart'
    as _i915;
import '../../features/journey/domain/usecases/load_journey_streak_summary.dart'
    as _i702;
import '../../features/leaderboard/data/datasources/cheer_local_data_source.dart'
    as _i875;
import '../../features/leaderboard/domain/usecases/get_board_reader_session.dart'
    as _i453;
import '../../features/leaderboard/domain/usecases/load_leaderboard.dart'
    as _i964;
import '../../features/quiz/domain/usecases/refresh_session_questions.dart'
    as _i788;
import '../../features/quiz/domain/usecases/start_session.dart' as _i521;
import '../../features/quiz/domain/usecases/submit_answer.dart' as _i84;
import '../../features/reading/data/datasources/reading_remote_data_source.dart'
    as _i48;
import '../../features/reading/data/datasources/streak_remote_data_source.dart'
    as _i692;
import '../../features/reading/data/mappers/streak_history_mapper.dart'
    as _i301;
import '../../features/reading/data/mappers/streak_summary_mapper.dart'
    as _i460;
import '../../features/reading/data/mappers/submit_result_mapper.dart' as _i840;
import '../../features/reading/data/mappers/today_reading_mapper.dart' as _i220;
import '../../features/reading/domain/usecases/load_scripture.dart' as _i574;
import '../../features/servant/domain/repositories/servant_admin_repository.dart'
    as _i884;
import '../../features/servant/domain/repositories/servant_report_repository.dart'
    as _i366;
import '../../features/servant/domain/usecases/commit_questions.dart' as _i555;
import '../../features/servant/domain/usecases/generate_ai_draft.dart' as _i867;
import '../../features/servant/domain/usecases/load_daily_report.dart' as _i973;
import '../../features/servant/domain/usecases/schedule_reading.dart' as _i491;
import '../../features/settings/data/datasources/settings_local_data_source.dart'
    as _i599;
import '../../features/settings/domain/usecases/get_settings.dart' as _i558;
import '../../features/settings/domain/usecases/update_settings.dart' as _i986;
import '../../features/sky/data/datasources/sky_local_data_source.dart'
    as _i156;
import 'modules/auth_module.dart' as _i4;
import 'modules/core_module.dart' as _i134;
import 'modules/home_module.dart' as _i443;
import 'modules/journey_module.dart' as _i492;
import 'modules/leaderboard_module.dart' as _i820;
import 'modules/quiz_module.dart' as _i697;
import 'modules/reading_module.dart' as _i768;
import 'modules/servant_module.dart' as _i885;
import 'modules/settings_module.dart' as _i145;
import 'modules/sky_module.dart' as _i696;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final authModule = _$AuthModule();
    final coreModule = _$CoreModule();
    final homeModule = _$HomeModule();
    final journeyModule = _$JourneyModule();
    final leaderboardModule = _$LeaderboardModule();
    final quizModule = _$QuizModule();
    final readingModule = _$ReadingModule();
    final servantModule = _$ServantModule();
    final settingsModule = _$SettingsModule();
    final skyModule = _$SkyModule();
    gh.lazySingleton<_i852.AuthLocalDataSource>(
      () => authModule.authLocalDataSource,
    );
    gh.lazySingleton<_i497.AuthRepository>(() => authModule.authRepository);
    gh.lazySingleton<_i920.SignIn>(() => authModule.signIn);
    gh.lazySingleton<_i606.GetCurrentSession>(
      () => authModule.getCurrentSession,
    );
    gh.lazySingleton<_i568.SignOut>(() => authModule.signOut);
    gh.lazySingleton<_i10.RoleAccess>(() => authModule.roleAccess);
    gh.lazySingleton<_i174.GetIt>(() => coreModule.serviceLocator);
    gh.lazySingleton<_i998.ApiErrorMapper>(() => coreModule.apiErrorMapper);
    gh.lazySingleton<_i220.TodayReadingMapper>(
      () => homeModule.todayReadingMapper,
    );
    gh.lazySingleton<_i460.StreakSummaryMapper>(
      () => homeModule.streakSummaryMapper,
    );
    gh.lazySingleton<_i301.StreakHistoryMapper>(
      () => homeModule.streakHistoryMapper,
    );
    gh.lazySingleton<_i840.SubmitResultMapper>(
      () => homeModule.submitResultMapper,
    );
    gh.lazySingleton<_i499.ReadingRepository>(
      () => homeModule.readingRepository,
    );
    gh.lazySingleton<_i682.StreakRepository>(() => homeModule.streakRepository);
    gh.lazySingleton<_i76.LibraryCatalogueLocalDataSource>(
      () => homeModule.libraryCatalogueLocalDataSource,
    );
    gh.lazySingleton<_i56.LibraryCatalogueRepository>(
      () => homeModule.libraryCatalogueRepository,
    );
    gh.lazySingleton<_i1067.LoadTodayReading>(
      () => homeModule.loadTodayReading,
    );
    gh.lazySingleton<_i605.LoadStreakSummary>(
      () => homeModule.loadStreakSummary,
    );
    gh.lazySingleton<_i257.LoadLastLight>(() => homeModule.loadLastLight);
    gh.lazySingleton<_i151.LoadLibraryCatalogue>(
      () => homeModule.loadLibraryCatalogue,
    );
    gh.lazySingleton<_i806.GetReaderSession>(() => homeModule.getReaderSession);
    gh.lazySingleton<_i900.GetJourneyReaderSession>(
      () => journeyModule.getJourneyReaderSession,
    );
    gh.lazySingleton<_i702.LoadJourneyStreakSummary>(
      () => journeyModule.loadJourneyStreakSummary,
    );
    gh.lazySingleton<_i915.LoadJourneyStreakHistory>(
      () => journeyModule.loadJourneyStreakHistory,
    );
    gh.lazySingleton<_i592.LoadJourneySkyCount>(
      () => journeyModule.loadJourneySkyCount,
    );
    gh.lazySingleton<_i988.MedalRepository>(
      () => journeyModule.medalRepository,
    );
    gh.lazySingleton<_i136.MedalLocalDataSource>(
      () => journeyModule.medalLocalDataSource,
    );
    gh.lazySingleton<_i307.LeaderboardRepository>(
      () => leaderboardModule.leaderboardRepository,
    );
    gh.lazySingleton<_i964.LoadLeaderboard>(
      () => leaderboardModule.loadLeaderboard,
    );
    gh.lazySingleton<_i875.CheerLocalDataSource>(
      () => leaderboardModule.cheerLocalDataSource,
    );
    gh.lazySingleton<_i344.CheerRepository>(
      () => leaderboardModule.cheerRepository,
    );
    gh.lazySingleton<_i453.GetBoardReaderSession>(
      () => leaderboardModule.getBoardReaderSession,
    );
    gh.lazySingleton<_i521.StartSession>(() => quizModule.startSession);
    gh.lazySingleton<_i788.RefreshSessionQuestions>(
      () => quizModule.refreshSessionQuestions,
    );
    gh.lazySingleton<_i84.SubmitAnswer>(() => quizModule.submitAnswer);
    gh.lazySingleton<_i574.LoadScripture>(() => readingModule.loadScripture);
    gh.lazySingleton<_i884.ServantAdminRepository>(
      () => servantModule.servantAdminRepository,
    );
    gh.lazySingleton<_i366.ServantReportRepository>(
      () => servantModule.servantReportRepository,
    );
    gh.lazySingleton<_i491.ScheduleReading>(
      () => servantModule.scheduleReading,
    );
    gh.lazySingleton<_i555.CommitQuestions>(
      () => servantModule.commitQuestions,
    );
    gh.lazySingleton<_i867.GenerateAiDraft>(
      () => servantModule.generateAiDraft,
    );
    gh.lazySingleton<_i973.LoadDailyReport>(
      () => servantModule.loadDailyReport,
    );
    gh.lazySingleton<_i599.SettingsLocalDataSource>(
      () => settingsModule.settingsLocalDataSource,
    );
    gh.lazySingleton<_i896.SettingsRepository>(
      () => settingsModule.settingsRepository,
    );
    gh.lazySingleton<_i558.GetSettings>(() => settingsModule.getSettings);
    gh.lazySingleton<_i986.UpdateSettings>(() => settingsModule.updateSettings);
    gh.lazySingleton<_i156.SkyLocalDataSource>(
      () => skyModule.skyLocalDataSource,
    );
    gh.lazySingleton<_i946.SkyRepository>(() => skyModule.skyRepository);
    gh.lazySingleton<String>(
      () => coreModule.apiBaseUrl,
      instanceName: 'apiBaseUrl',
    );
    gh.lazySingleton<_i361.Dio>(
      () => coreModule.apiClient(
        gh<String>(instanceName: 'apiBaseUrl'),
        gh<_i10.RoleAccess>(),
      ),
    );
    gh.lazySingleton<_i48.ReadingRemoteDataSource>(
      () => homeModule.readingRemoteDataSource(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i692.StreakRemoteDataSource>(
      () => homeModule.streakRemoteDataSource(gh<_i361.Dio>()),
    );
    return this;
  }
}

class _$AuthModule extends _i4.AuthModule {}

class _$CoreModule extends _i134.CoreModule {}

class _$HomeModule extends _i443.HomeModule {}

class _$JourneyModule extends _i492.JourneyModule {}

class _$LeaderboardModule extends _i820.LeaderboardModule {}

class _$QuizModule extends _i697.QuizModule {}

class _$ReadingModule extends _i768.ReadingModule {}

class _$ServantModule extends _i885.ServantModule {}

class _$SettingsModule extends _i145.SettingsModule {}

class _$SkyModule extends _i696.SkyModule {}
