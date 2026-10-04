import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/quiz/domain/refreshed_questions.dart';

/// Re-reads today's reading so a session can take fresh `already_answered` flags
/// and a fresh `reading_id` off it.
///
/// ## THE REASON THIS EXISTS IS A MISSING ENDPOINT, NOT A NICER ARCHITECTURE
///
/// The backend has **no `GET /readings/:id`**. There is no such route, so there is
/// no request a client could make to learn one question's current state; the only
/// way to refresh is to re-read *today's whole reading* and take what changed.
///
/// **The alternative — trusting the flags already on hand — is the defect this
/// replaces**, and it has a measured consequence. `Question.alreadyAnswered` is
/// mapped leniently (`today_reading_mapper.dart`: a missing or non-`bool` flag reads
/// as "not proven answered"), so it is only ever as fresh as the last fetch. §5 trap
/// 3: submitting an already-answered question is a **409**. A reader who answered on
/// another device, or whose first fetch predates their own earlier submission, would
/// be walked into a conflict the client could have seen coming.
///
/// `quiz_bloc_test.dart` asserts the re-fetch in the falsifying direction: the
/// fixture flips the flag between the two reads and the test asserts the **second**
/// value is what lands in state.
///
/// ## IT RETURNS A NARROWER TYPE THAN IT FETCHES, DELIBERATELY
///
/// `RefreshedQuestions` rather than [ScriptureText]: see its own doc. The two
/// surviving values are the flag and the id, and naming them is what stops a caller
/// going back to the payload for the other half.
final class RefreshSessionQuestions
    implements UseCase<ReadingLanguage, RefreshedQuestions> {
  /// Re-reads through [repository].
  const RefreshSessionQuestions(this._repository);

  final ReadingRepository _repository;

  @override
  Future<Result<RefreshedQuestions>> call(ReadingLanguage params) async {
    final Result<ScriptureText> reading = await _repository.todayScripture(
      language: params,
    );
    return reading.map(
      (ScriptureText scripture) => RefreshedQuestions(
        readingId: scripture.readingId,
        questions: scripture.questions,
      ),
    );
  }
}
