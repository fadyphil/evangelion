import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/journey/data/datasources/medal_local_data_source.dart';
import 'package:evangelion/features/journey/data/repositories/medal_repository_impl.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';
import 'package:evangelion/features/journey/domain/usecases/get_journey_reader_session.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_sky_count.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_history.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_summary.dart';
import 'package:injectable/injectable.dart';

/// The reader's journey: the streak, the rings, the sky count and the medals.
///
/// ## WHY IT IS A MODULE AND NOT PART OF `CoreModule`
///
/// Because every provider here belongs to **one feature**, and the module-per-
/// feature shape is decision 11's "a named shape that appears one feature at a
/// time". `CoreModule` holds the providers **every** feature needs — the Dio
/// client, the error mapper, the auth port's adapter — and a feature's own
/// module holds its own.
@module
abstract class JourneyModule {
  /// The reader's own session, for the name and the monogram.
  ///
  /// The journey's **own** copy over the shared [AuthRepository], for the reason
  /// `features/home/domain/usecases/get_reader_session.dart` records: a feature
  /// may not import another feature, and the port is the shared kernel's.
  /// `features/leaderboard/` has made the same copy twice now.
  @lazySingleton
  GetJourneyReaderSession get getJourneyReaderSession =>
      GetJourneyReaderSession(getIt<AuthRepository>());

  /// The streak summary, for the hero number.
  ///
  /// The **real** endpoint — `GET /streak/summary` — and ADR-0022's fiction
  /// table marks the hero number real.
  @lazySingleton
  LoadJourneyStreakSummary get loadJourneyStreakSummary =>
      LoadJourneyStreakSummary(getIt<StreakRepository>());

  /// The thirty-day history, for the rings and the constellations.
  ///
  /// The same endpoint's sibling (`GET /streak`), and it is a **separate method**
  /// on the port for §3's ISP row again: a caller that wants one number must not
  /// pay for thirty rows.
  @lazySingleton
  LoadJourneyStreakHistory get loadJourneyStreakHistory =>
      LoadJourneyStreakHistory(getIt<StreakRepository>());

  /// How many stars are lit, for the sky line.
  ///
  /// The shared [SkyRepository]'s `count()` — the port's own doc already names
  /// `journey` as the consumer of it, and the sky is a **local** store, so this
  /// is the reader's own device and not the server's.
  @lazySingleton
  LoadJourneySkyCount get loadJourneySkyCount =>
      LoadJourneySkyCount(getIt<SkyRepository>());

  /// The medals, as ADR-0022 has them: **stubbed**.
  ///
  /// Registered against the **port**, so the cubit names no adapter — the same
  /// rule `leaderboard_module.dart` follows for the cheer. There is no
  /// achievements endpoint today; when there is, this getter changes and nothing
  /// above it does.
  @lazySingleton
  MedalRepository get medalRepository =>
      MedalRepositoryImpl(getIt<MedalLocalDataSource>());

  /// The stub the medals come from.
  ///
  /// A singleton **data source**, because the shelf is the fiction and the
  /// fiction is session-scoped — the same shape `cheer_local_data_source.dart`
  /// has.
  @lazySingleton
  MedalLocalDataSource get medalLocalDataSource => MedalLocalDataSource();
}
