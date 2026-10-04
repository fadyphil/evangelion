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
import '../../core/domain/repositories/reading_repository.dart' as _i499;
import '../../core/domain/repositories/streak_repository.dart' as _i682;
import '../../core/network/api_error_mapper.dart' as _i998;
import '../../features/auth/data/datasources/auth_local_data_source.dart'
    as _i852;
import '../../features/auth/domain/usecases/get_current_session.dart' as _i606;
import '../../features/auth/domain/usecases/sign_in.dart' as _i920;
import '../../features/auth/domain/usecases/sign_out.dart' as _i568;
import '../../features/home/domain/usecases/get_reader_session.dart' as _i806;
import '../../features/home/domain/usecases/load_streak_summary.dart' as _i605;
import '../../features/home/domain/usecases/load_today_reading.dart' as _i1067;
import '../../features/reading/data/datasources/reading_remote_data_source.dart'
    as _i48;
import '../../features/reading/data/datasources/streak_remote_data_source.dart'
    as _i692;
import '../../features/reading/data/mappers/streak_summary_mapper.dart'
    as _i460;
import '../../features/reading/data/mappers/today_reading_mapper.dart' as _i220;
import 'modules/auth_module.dart' as _i4;
import 'modules/core_module.dart' as _i134;
import 'modules/home_module.dart' as _i443;

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
    gh.lazySingleton<_i852.AuthLocalDataSource>(
      () => authModule.authLocalDataSource,
    );
    gh.lazySingleton<_i497.AuthRepository>(() => authModule.authRepository);
    gh.lazySingleton<_i920.SignIn>(() => authModule.signIn);
    gh.lazySingleton<_i606.GetCurrentSession>(
      () => authModule.getCurrentSession,
    );
    gh.lazySingleton<_i568.SignOut>(() => authModule.signOut);
    gh.lazySingleton<_i174.GetIt>(() => coreModule.serviceLocator);
    gh.lazySingleton<_i998.ApiErrorMapper>(() => coreModule.apiErrorMapper);
    gh.lazySingleton<_i220.TodayReadingMapper>(
      () => homeModule.todayReadingMapper,
    );
    gh.lazySingleton<_i460.StreakSummaryMapper>(
      () => homeModule.streakSummaryMapper,
    );
    gh.lazySingleton<_i499.ReadingRepository>(
      () => homeModule.readingRepository,
    );
    gh.lazySingleton<_i682.StreakRepository>(() => homeModule.streakRepository);
    gh.lazySingleton<_i1067.LoadTodayReading>(
      () => homeModule.loadTodayReading,
    );
    gh.lazySingleton<_i605.LoadStreakSummary>(
      () => homeModule.loadStreakSummary,
    );
    gh.lazySingleton<_i806.GetReaderSession>(() => homeModule.getReaderSession);
    gh.lazySingleton<String>(
      () => coreModule.apiBaseUrl,
      instanceName: 'apiBaseUrl',
    );
    gh.lazySingleton<_i361.Dio>(
      () => coreModule.apiClient(gh<String>(instanceName: 'apiBaseUrl')),
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
