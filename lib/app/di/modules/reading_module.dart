import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:injectable/injectable.dart';

/// The `reading` feature's registrations.
///
/// **THIS MODULE REGISTERS ONE THING: [loadScripture].** Everything else `/reading`
/// needs is either a Phase-6 registration (`ReadingRemoteDataSource`,
/// `TodayReadingMapper`, `DioReadingRepository`) or a hand-registration — see
/// [readingModuleNote] below.
///
/// `DioReadingRepository` and the remote data source are **Phase 6's**, registered
/// by `home_module.dart` because `/` was their first consumer; Phase 7 *widened*
/// those classes rather than registering a second pair, which is recorded decision
/// 23's resolution. Registering them again here would be the "adapter inventory
/// grows from three to four" outcome that decision rejects.
///
/// A `@module` with no providers emits no registration at all, so an empty one
/// costs nothing at runtime. The record of what the graph actually contains is
/// `injection.config.dart`, which is committed on purpose: it names `CoreModule`
/// alone, and a reviewer reading a diff sees this module for the empty shell it is
/// rather than trusting the file name.
///
/// ## WHY IT IS PURE DART, AND WHY THAT IS A CONSTRAINT RATHER THAN A COINCIDENCE
///
/// Everything reachable from `injection.dart` has to stay Flutter-free: the
/// composition root's whole transitive project-local import graph is walked by
/// `injection_test.dart`, and AGENT_CONTEXT §6 recorded decision 4 makes that
/// walk part of the contract. A `@module` here is therefore reachable from that
/// walk, and so is anything it names.
///
/// Phase Phase 7 will break that, because {@code ReadingCubit} is a Flutter type in
/// practice — `flutter_bloc` re-exports the framework's widget layer alongside
/// the bloc, and `bloc` itself is a transitive dependency this project may not
/// promote to a direct one. The fix is the one already taken for the router:
/// register it from `lib/app/di/navigation_injection.dart`, the Flutter-permitted
/// composition root, rather than moving `injection.dart`'s imports. Recorded here
/// now so the next phase rediscovers it as a decision instead of as a puzzle.
@module
abstract class ReadingModule {
  /// Today's passage, in the reader's language.
  ///
  /// Over the **port**, and registered as `@lazySingleton` for the reason
  /// `home_module.dart`'s providers are: it holds no state, so the lifetime buys
  /// nothing, but a `@factory` would build a second request path per lookup and the
  /// identity interceptor's state is per-client.
  @lazySingleton
  LoadScripture get loadScripture => LoadScripture(getIt<ReadingRepository>());
}
