import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// Opens a quiz over today's reading.
///
/// ## IT IS A DIFFERENT USE CASE FROM `LoadScripture`, AND THE DIFFERENCE IS THE
/// ## PROJECTION
///
/// Both call [ReadingRepository.todayScripture] with the same argument. What
/// differs is what comes back: `LoadScripture` hands `/reading` the whole
/// [ScriptureText], and this hands `QuizBloc` a [QuizSession] — the reading's
/// `reading_id` plus one [QuizAnswer] per question, each carrying the reader's
/// progress (nothing, a selection, a verdict).
///
/// **Two use cases over one port method is the ISP answer**, and it is the same
/// decision `LoadScripture`'s own doc records against a single wide use case: a
/// client depends on the smallest interface that satisfies it. Merging them would
/// mean the quiz cast away every verse to use two fields, and `/reading` cast away
/// the session.
///
/// **A consequence worth stating: nothing is re-fetched.** Both use cases hit the
/// same endpoint and neither caches, so a screen wanting both would issue two
/// `GET`s. `/`, `/reading` and `/quiz` are three different routes and only one is
/// ever on screen, so this never happens in the app as built; and the honest fix if
/// it ever did is a cache **in the adapter** (`DioReadingRepository`), which would
/// be one implementation for every caller — not a use case that returns a union.
///
/// ## AND WHY THE SESSION CARRIES NO `already_answered` OF ITS OWN
///
/// It does, transitively: `QuizAnswer.question.alreadyAnswered`, read through
/// [QuizAnswer.isAnswerable]. This class copies the whole [Question] rather than a
/// projection of it, because `QuizAnswer` needs `prompt`, `options` and `id` too,
/// and because §3's DIP row makes a place that re-decides what a question means the
/// thing not to add.
final class StartSession implements UseCase<ReadingLanguage, QuizSession> {
  /// Opens a session through [repository].
  const StartSession(this._repository);

  final ReadingRepository _repository;

  @override
  Future<Result<QuizSession>> call(ReadingLanguage params) async {
    final Result<ScriptureText> reading = await _repository.todayScripture(
      language: params,
    );
    // `Result.map` runs only for a success and leaves a failure byte-for-byte
    // identical, so a 400 / 409 / transport fault propagates as the repository
    // wrote it — §3's DIP row, and the reason there is no `try` here.
    return reading.map(
      (ScriptureText scripture) => QuizSession.fromQuestions(
        readingId: scripture.readingId,
        questions: scripture.questions,
      ),
    );
  }
}
