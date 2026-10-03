import 'package:injectable/injectable.dart';

/// The `quiz` feature's registrations.
///
/// **THIS MODULE REGISTERS NOTHING TODAY.** That is the honest state, not an
/// oversight: Phase 8 owns `QuizBloc` and the use cases it drives — all of which run through the `reading` feature's `ReadingRepository` port, because `quiz` declares no repository of its own, so until that phase lands there is nothing to
/// put here. The module exists now, empty and named, because a container whose
/// shape appears one feature at a time is one feature at a time.
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
/// Phase Phase 8 will break that, because {@code QuizBloc} is a Flutter type in
/// practice — `flutter_bloc` re-exports the framework's widget layer alongside
/// the bloc, and `bloc` itself is a transitive dependency this project may not
/// promote to a direct one. The fix is the one already taken for the router:
/// register it from `lib/app/di/navigation_injection.dart`, the Flutter-permitted
/// composition root, rather than moving `injection.dart`'s imports. Recorded here
/// now so the next phase rediscovers it as a decision instead of as a puzzle.
@module
abstract class QuizModule {}
