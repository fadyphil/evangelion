import 'package:dio/dio.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/home/data/datasources/library_catalogue_local_data_source.dart';
import 'package:evangelion/features/home/data/repositories/library_catalogue_repository_impl.dart';
import 'package:evangelion/features/home/domain/library_catalogue_repository.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_last_light.dart';
import 'package:evangelion/features/home/domain/usecases/load_library_catalogue.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/reading/data/datasources/reading_remote_data_source.dart';
import 'package:evangelion/features/reading/data/datasources/streak_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/streak_history_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/streak_summary_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/submit_result_mapper.dart';
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
/// use cases. All are pure Dart, so all are reachable from `injection.dart`'s
/// graph without violating the Flutter-free rule AGENT_CONTEXT §6 recorded
/// decision 4 makes part of the contract.
///
/// **Phase 5.2's counts:** three ports (a new one, `LibraryCatalogueRepository`,
/// whose fiction `ADR-0022` puts behind a port), three adapters, four mappers (the
/// streak's `history[]` is a second response and gets a second mapper), three data
/// sources, and six use cases (`LoadLeaderboardPreview` went with the redesign's
/// home, which has no board card — the board is its own screen from Task 5.5).
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
/// [readingRepository] returns `ReadingRepository`, [streakRepository] returns
/// `StreakRepository`, and [libraryCatalogueRepository] returns
/// `LibraryCatalogueRepository`. That is the substitution §2's "live API" decision
/// depends on: a future fake or a different transport is a change to one provider
/// body here and **nothing else in the app** — no use case, no bloc, no page names
/// `DioReadingRepository` or `LibraryCatalogueRepositoryImpl`.
/// `injection_test.dart` asserts the generated text registers the ports and never
/// the concretes, for each, in the failing direction.
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

  /// `GET /api/v1/streak`'s `history[]` → `List<StreakHistoryEntry>`.
  ///
  /// **Phase 5.2's second streak mapper, and the first registration in this file
  /// that exists for a screen section rather than a whole feature.** `streak.routes.ts`
  /// has two routes and `/`'s last-light card is the reason the second one is now
  /// read at all (ADR-0022's fiction table: "`GET /streak` → `history[0]`, unused
  /// by the client today").
  @lazySingleton
  StreakHistoryMapper get streakHistoryMapper => const StreakHistoryMapper();

  /// The submission body → `SubmitResult` projection.
  ///
  /// **Phase 8's twenty-first registration**, and the reason it lives here rather
  /// than in `quiz_module.dart` is [quiz_module.dart]'s own subject: the endpoint is
  /// `POST /readings/:id/submit`, the port is `ReadingRepository`, and the adapter is
  /// this class. A `quiz` module providing a mapper for a `/readings/` route would
  /// be the mirror image of the puzzle recorded decision 23 rejects.
  @lazySingleton
  SubmitResultMapper get submitResultMapper => const SubmitResultMapper();

  /// The one [ReadingRepository] that ships.
  @lazySingleton
  ReadingRepository get readingRepository => DioReadingRepository(
    dataSource: getIt<ReadingRemoteDataSource>(),
    mapper: getIt<TodayReadingMapper>(),
    submits: getIt<SubmitResultMapper>(),
    errors: getIt<ApiErrorMapper>(),
  );

  /// The one [StreakRepository] that ships.
  @lazySingleton
  StreakRepository get streakRepository => DioStreakRepository(
    dataSource: getIt<StreakRemoteDataSource>(),
    mapper: getIt<StreakSummaryMapper>(),
    historyMapper: getIt<StreakHistoryMapper>(),
    errors: getIt<ApiErrorMapper>(),
  );

  /// The book catalogue `/`'s carousel draws.
  ///
  /// **The first `features/home/data/` directory in the app, and it exists for the
  /// one ADR-0022 fiction this feature ships**: `LibraryCatalogueLocalDataSource`'s
  /// doc says what it is and why it is the only file that knows. `@lazySingleton`
  /// because the data source is `const` and stateless, and the lifetime is a
  /// uniform answer rather than a claim — the **books** are per-instance values and
  /// would still be `const` under a factory.
  @lazySingleton
  LibraryCatalogueLocalDataSource get libraryCatalogueLocalDataSource =>
      const LibraryCatalogueLocalDataSource();

  /// The one [LibraryCatalogueRepository] that ships. Typed as the port; see the
  /// class doc for why the fiction sits behind one.
  @lazySingleton
  LibraryCatalogueRepository get libraryCatalogueRepository =>
      LibraryCatalogueRepositoryImpl(getIt<LibraryCatalogueLocalDataSource>());

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

  /// The most recent scheduled day — `/`'s last light.
  ///
  /// **Phase 5.2's.** `GET /streak` rather than `GET /streak/summary`, and the
  /// port's doc gives why the two are not merged: the summary is nine scalars and
  /// the history costs a subquery per row.
  @lazySingleton
  LoadLastLight get loadLastLight => LoadLastLight(getIt<StreakRepository>());

  /// The carousel's books.
  @lazySingleton
  LoadLibraryCatalogue get loadLibraryCatalogue =>
      LoadLibraryCatalogue(getIt<LibraryCatalogueRepository>());

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
