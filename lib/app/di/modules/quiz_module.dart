import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/features/quiz/domain/usecases/refresh_session_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:injectable/injectable.dart';

/// The `quiz` feature's registrations.
///
/// **THIS MODULE REGISTERS THREE THINGS, AND THE ONE IT DELIBERATELY DOES NOT IS
/// `QuizBloc`.** `08-build-phases.md` §Phase 8: "`quiz` declares no repository and
/// no data source of its own" — and every provider below is a use case over
/// `ReadingRepository`, the **port**, which `home_module.dart` has registered
/// against `DioReadingRepository` since Phase 6.
///
/// ## WHY ALL THREE ARE **PURE DART**, AND WHY THAT IS THE WHOLE TRICK
///
/// `StartSession`, `RefreshSessionQuestions` and `SubmitAnswer` are callable objects
/// over an interface. `injection.dart`'s transitive project-local import graph is
/// walked by `injection_test.dart` and must stay Flutter-free (AGENT_CONTEXT §6,
/// recorded decision 4), and this file is inside that graph — so everything it names
/// is inside it too.
///
/// That is exactly why the module can be filled in at all: the three use cases import
/// `core/domain/` and `core/common/` and nothing else. Had any of them needed a
/// widget, there would have been nothing to register here.
///
/// ## WHY `SubmitAnswer` IS REGISTERED HERE AND NOT IN `home_module.dart`
///
/// Its **port method** is registered there, on `ReadingRepository`, and the endpoint
/// is `POST /readings/:id/submit`. But a use case is the *quiz's* application
/// behaviour, not the reading repository's — `SubmitAnswerParams` is a type only
/// `features/quiz/` names, and §3's placement rule is about which feature **owns** a
/// thing. The line is: the port and the adapter follow the **resource**, and a use
/// case follows the **feature that drives it**.
///
/// `reading_module.dart` registered `LoadScripture` on the same reasoning, one phase
/// earlier.
///
/// ## AND THE `submitResultMapper` PROVIDER IS **NOT** HERE
///
/// `home_module.dart` holds it, beside `todayReadingMapper` and the two repositories
/// it belongs to. One mapper per adapter, and recorded decision 23's "adapter
/// inventory grows from three to four" is the outcome this avoids: registering
/// `SubmitResultMapper` here would put a `/readings/` mapper in a feature that
/// declares no data layer.
@module
abstract class QuizModule {
  /// Today's questions, as a session.
  @lazySingleton
  StartSession get startSession => StartSession(getIt<ReadingRepository>());

  /// A **re-read** of today's reading, for fresh `already_answered` flags.
  ///
  /// **`@lazySingleton`, not `@factory`,** for the reason every provider here is:
  /// it holds no state, so the lifetime buys nothing — but a `@factory` would build
  /// a second request path per lookup, and the **identity interceptor's** state is
  /// per-client (`core_module.dart` says so for the client itself).
  @lazySingleton
  RefreshSessionQuestions get refreshSessionQuestions =>
      RefreshSessionQuestions(getIt<ReadingRepository>());

  /// Grades one answer.
  @lazySingleton
  SubmitAnswer get submitAnswer => SubmitAnswer(getIt<ReadingRepository>());
}
