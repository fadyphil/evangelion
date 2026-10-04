import 'package:dio/dio.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/reading/data/datasources/reading_remote_data_source.dart';
import 'package:evangelion/features/reading/data/datasources/streak_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';
import 'package:evangelion/features/reading/data/repositories/dio_reading_repository.dart';
import 'package:evangelion/features/reading/data/repositories/dio_streak_repository.dart';
import 'package:injectable/injectable.dart';

/// The `home` feature's registrations, and the two live adapters it is the first
/// consumer of.
///
/// ## WHAT IS HERE, AND WHAT IS **NOT**, AND WHY THE LINE IS WHERE IT IS
///
/// **Here:** both ports, both adapters, both mappers, both data sources, and the
/// three use cases. All eleven are pure Dart, so all eleven are reachable from
/// `injection.dart`'s graph without violating the Flutter-free rule AGENT_CONTEXT
/// §6 recorded decision 4 makes part of the contract.
///
/// **Not here:** [`HomeBloc`]. `flutter_bloc` re-exports the framework's widget layer
/// alongside the bloc, and `bloc` itself is a transitive dependency this project may
/// not promote to a direct one (§8.4), so a provider here would put
/// `package:flutter/material.dart` inside the composition root's closure. It is
/// hand-registered from `lib/app/di/navigation_injection.dart`, beside `AuthBloc` —
/// the fix already taken twice, for the router and for the auth bloc.
///
/// ## AND WHY THE **ADAPTERS** ARE HERE, WHICH LOOKS LIKE THE WRONG FEATURE
///
/// Because `home_module.dart` is where the **graph** lives, and the graph is not
/// organised by which screen reads a dependency. `DioReadingRepository` is in
/// `features/reading/` — see its own doc, which argues the placement at length —
/// and this module is what puts it in the object graph.
///
/// The alternative was a `features/reading/data/` module registering them, with
/// `home_module.dart` empty. It was rejected because §8's "prefer editing an
/// existing file over creating a new one" cuts the other way here, and because the
/// six `@module` files are a **named shape that appears one feature at a time**
/// (recorded decision 11): the module named after the feature that *first needed*
/// the dependency is the one whose doc can explain it, and a `reading` module
/// registering a dependency nothing in `reading` uses would be its own puzzle.
///
/// ## AND EVERY ADAPTER IS REGISTERED **AGAINST ITS PORT**
///
/// [readingRepository] returns `ReadingRepository` and [streakRepository] returns
/// `StreakRepository`. That is the substitution §2's "live API" decision depends
/// on: a future fake or a different transport is a change to one provider body here
/// and **nothing else in the app** — no use case, no bloc, no page names
/// `DioReadingRepository`. `injection_test.dart` asserts the generated text
/// registers the ports and never the concretes, for both, in the failing direction.
@module
abstract class HomeModule {
  /// `GET /api/v1/readings/today/{lang}`.
  ///
  /// `@lazySingleton`: the data source holds no state of its own, so the lifetime
  /// buys nothing — but a `@factory` here would build a second `Dio` request path per
  /// lookup, and the **identity interceptor's** state is per-client
  /// (`core_module.dart` says so for the client itself). One instance, one identity.
  @lazySingleton
  ReadingRemoteDataSource readingRemoteDataSource(Dio client) =>
      ReadingRemoteDataSource(client);

  /// `GET /api/v1/streak/summary`.
  @lazySingleton
  StreakRemoteDataSource streakRemoteDataSource(Dio client) =>
      StreakRemoteDataSource(client);

  /// The reading body → entity projection.
  @lazySingleton
  TodayReadingMapper get todayReadingMapper => const TodayReadingMapper();

  /// The streak body → `StreakSummary` projection.
  @lazySingleton
  StreakSummaryMapper get streakSummaryMapper => const StreakSummaryMapper();

  /// The one [ReadingRepository] that ships.
  @lazySingleton
  ReadingRepository get readingRepository => DioReadingRepository(
    dataSource: getIt<ReadingRemoteDataSource>(),
    mapper: getIt<TodayReadingMapper>(),
    errors: getIt<ApiErrorMapper>(),
  );

  /// The one [StreakRepository] that ships.
  @lazySingleton
  StreakRepository get streakRepository => DioStreakRepository(
    dataSource: getIt<StreakRemoteDataSource>(),
    mapper: getIt<StreakSummaryMapper>(),
    errors: getIt<ApiErrorMapper>(),
  );

  /// Today's reading, in the reader's language.
  ///
  /// **The language is a parameter and not a parameter of this provider**, and
  /// `injection_test.dart`'s inventory pins the signature: the language comes from
  /// `HomeStarted`, because the only place a `Locale` exists is a widget. See that
  /// event's doc.
  @lazySingleton
  LoadTodayReading get loadTodayReading =>
      LoadTodayReading(getIt<ReadingRepository>());

  /// The streak summary.
  @lazySingleton
  LoadStreakSummary get loadStreakSummary =>
      LoadStreakSummary(getIt<StreakRepository>());

  /// The session, for the greeting's name and the avatar's monogram.
  ///
  /// `AuthRepository` rather than the `auth` feature's own `GetCurrentSession` use
  /// case: **`home` may not import `features/auth`** (§3, and Gate 2 fails on the
  /// line), and the port is the shared kernel's. `GetReaderSession`'s doc has the
  /// whole argument for why the duplication of the use case is the accepted price.
  @lazySingleton
  GetReaderSession get getReaderSession =>
      GetReaderSession(getIt<AuthRepository>());
}
