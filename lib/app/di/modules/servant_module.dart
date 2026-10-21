import 'package:dio/dio.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/servant/data/datasources/servant_remote_data_source.dart';
import 'package:evangelion/features/servant/data/mappers/question_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/report_mapper.dart';
import 'package:evangelion/features/servant/data/mappers/schedule_mapper.dart';
import 'package:evangelion/features/servant/data/repositories/dio_servant_admin_repository.dart';
import 'package:evangelion/features/servant/data/repositories/dio_servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/commit_questions.dart';
import 'package:evangelion/features/servant/domain/usecases/generate_ai_draft.dart';
import 'package:evangelion/features/servant/domain/usecases/load_daily_report.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:injectable/injectable.dart';

/// The `servant` feature's registrations.
///
/// ## WHAT IS HERE, AND WHAT IS **NOT**, AND WHY THE LINE IS WHERE IT IS
///
/// **Here:** the two ports' adapters and the four use cases. All six are pure
/// Dart, so all six are reachable from `injection.dart`'s graph without
/// violating the Flutter-free rule AGENT_CONTEXT §6 recorded decision 4 makes
/// part of the contract — `injection_test.dart` walks that whole transitive
/// project-local graph and fails on any Flutter import it reaches.
///
/// **Not here:** the three cubits. `flutter_bloc` re-exports the framework's
/// widget layer alongside the bloc, and `bloc` itself is a transitive dependency
/// this project may not promote to a direct one — so a provider here would put
/// `package:flutter/material.dart` inside the composition root's closure. They
/// are registered by hand from `lib/app/di/navigation_injection.dart`, the
/// Flutter-permitted half of the graph, which is the fix already taken for the
/// router, `AuthBloc`, `HomeBloc`, `QuizBloc`, `ReadingCubit`, `SettingsCubit`
/// and `SkyCubit`.
///
/// ## AND EVERY ADAPTER IS REGISTERED **AGAINST ITS PORT**
///
/// [servantAdminRepository] returns `ServantAdminRepository` and
/// [servantReportRepository] returns `ServantReportRepository` — never the
/// `Dio…` classes. That is the substitution the whole graph rests on: a
/// different transport is a change to one provider body here and nothing else,
/// because no use case, no cubit and no page names a concrete adapter.
///
/// ## AND THE THREE **ADAPTER-LEVEL** PIECES ARE BUILT INLINE
///
/// The data source and the three mappers are **not** registered separately,
/// and that is the `leaderboard_module.dart` shape rather than the
/// `home_module.dart` one: `leaderboard_module.dart` builds
/// `LeaderboardRemoteDataSource(getIt<Dio>())` and `const LeaderboardMapper()`
/// inside its repository provider, and this module does the same.
///
/// The reason is that **nothing else reads them.** A registration is a claim
/// that something in the graph depends on the thing registered; the mappers and
/// the data source are dependencies of the two adapters and of nothing else, so
/// registering them would add four names to the locator that four call sites
/// never look up. The `Dio` they are built over **is** registered, by
/// `core_module.dart`.
///
/// **AND THE TWO ADAPTERS SHARE ONE `Dio`, WHICH IS THE PART THAT MATTERS.**
/// `ServantRemoteDataSource` holds no state of its own — it is a URL and a
/// call — so each adapter having its own instance over the same client is the
/// same arrangement `leaderboard_module.dart` uses. What must be one is the
/// **transport**, because the identity interceptor is per-client: two clients
/// would mean two identities the app could disagree about.
@module
abstract class ServantModule {
  /// The one [ServantAdminRepository] that ships.
  @lazySingleton
  ServantAdminRepository get servantAdminRepository =>
      DioServantAdminRepository(
        dataSource: ServantRemoteDataSource(getIt<Dio>()),
        scheduleMapper: const ScheduleMapper(),
        questionMapper: const QuestionMapper(),
        errors: const ApiErrorMapper(),
      );

  /// The one [ServantReportRepository] that ships.
  @lazySingleton
  ServantReportRepository get servantReportRepository =>
      DioServantReportRepository(
        dataSource: ServantRemoteDataSource(getIt<Dio>()),
        mapper: const ReportMapper(),
        errors: const ApiErrorMapper(),
      );

  /// Schedules a reading.
  @lazySingleton
  ScheduleReading get scheduleReading =>
      ScheduleReading(getIt<ServantAdminRepository>());

  /// Commits questions.
  @lazySingleton
  CommitQuestions get commitQuestions =>
      CommitQuestions(getIt<ServantAdminRepository>());

  /// Asks for an AI draft.
  @lazySingleton
  GenerateAiDraft get generateAiDraft =>
      GenerateAiDraft(getIt<ServantAdminRepository>());

  /// Loads the cohort's daily report.
  @lazySingleton
  LoadDailyReport get loadDailyReport =>
      LoadDailyReport(getIt<ServantReportRepository>());
}
