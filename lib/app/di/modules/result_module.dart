import 'package:injectable/injectable.dart';

/// The `result` feature's registrations.
///
/// **THIS MODULE REGISTRES NOTHING, AND PHASE 8 IS WHY.**
///
/// The prediction this doc made is now a measurement, and it held: `/result` has no
/// repository, no use case and no API call of its own, so there is nothing to put
/// here. `ResultPage` takes the graded answer as a **required constructor
/// parameter** — `SubmitResult` is a plain immutable value, not a dependency — so
/// `features/result/` contributes no type to the object graph at all.
///
/// ## AND THE PLAN'S PHRASING WAS CORRECTED, BECAUSE IT NAMED THE WRONG MECHANISM
///
/// This file used to say "`/result` reads the last `SubmitResult` **held by
/// `QuizBloc`**", and `QuizBloc` still holds it — `QuizState.lastResult` is the
/// only copy that exists, and `QuizPage` is what reads it. But `ResultPage` does
/// **not** read it from the bloc, and cannot: `features/result/` importing
/// `features/quiz/presentation/bloc/quiz_bloc.dart` is **Gate 2**, the same wall
/// `HomeCleared` could not cross in the other direction.
///
/// So the response travels as an argument from the one screen that has it to the
/// one screen that needs it. That is not a simplification of the plan's shape — it
/// is the only spelling of it that Gate 2 permits, and it has a consequence worth
/// stating: **`/result` cannot be pushed without a graded answer**, because the
/// route's constructor requires one. A reader who has submitted nothing has no
/// result screen, which is why `QuizState.cta` is `QuizCta.none` in that case.
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
/// Phase Phase 8 will break that, because {@code none yet} is a Flutter type in
/// practice — `flutter_bloc` re-exports the framework's widget layer alongside
/// the bloc, and `bloc` itself is a transitive dependency this project may not
/// promote to a direct one. The fix is the one already taken for the router:
/// register it from `lib/app/di/navigation_injection.dart`, the Flutter-permitted
/// composition root, rather than moving `injection.dart`'s imports. Recorded here
/// now so the next phase rediscovers it as a decision instead of as a puzzle.
@module
abstract class ResultModule {}
