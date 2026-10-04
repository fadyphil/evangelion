import 'package:dio/dio.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/reading/data/datasources/reading_remote_data_source.dart';
import 'package:evangelion/features/reading/data/mappers/submit_result_mapper.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';

/// The live [ReadingRepository].
///
/// ## WHY IT LIVES IN `features/reading/` AND NOT IN `features/home/`
///
/// Two consumers, so §3 puts the *port* in `core/domain/` — and the *adapter*
/// follows the port's **domain**, not the first screen that needed it. `/reading`
/// is the sanctuary for exactly this payload and Phase 7 widens this very class,
/// so an adapter called `DioReadingRepository` living under `features/home` would
/// be a file whose name says reading and whose location says home.
///
/// That decision is recorded in `AGENT_CONTEXT` §9 as a new one, because
/// `07-file-map.md` and `08-build-phases.md` disagree about it: the file map puts
/// both real adapters in `reading/data/` and names **no** streak adapter at all
/// (an inventory gap — there are three adapters, not the two it lists), while
/// Phase 7 claims it owns "the remote data source (`GET /readings/today/{lang}`)
/// and its mapper". Both cannot be true of the same file, so the data sources,
/// mappers and adapters are created **now** for the narrow projection and Phase 7
/// **widens** them. `07-file-map.md` is not edited — AGENT_CONTEXT §8.6 gives
/// `docs/plans/` a dedicated owner.
///
/// ## THE BODY IS TWO ARMS, AND THAT IS THE WHOLE OF THE CONTRACT
///
/// ```dart
/// try   → Result.failure(errors.fromDioException(e))   // transport, or non-2xx
/// body  → mapper.map(body)                              // 2xx that cannot be read
/// ```
///
/// §3's LSP row: never throws, always returns a `Result`. There is no third arm
/// for "something else went wrong" because there is no third thing, and adding
/// one would be a `catch` that hides the two that exist. `analysis_options.yaml`
/// enables `avoid_catching_errors` and `avoid_catches_without_on_clauses`, so the
/// one `on` clause below is deliberate and narrow.
///
/// ## AND IT IS REGISTERED AGAINST THE PORT
///
/// `home_module.dart` provides `ReadingRepository`, never `DioReadingRepository`.
/// A concrete-typed registration would put this class into the graph as a
/// dependency of every use case, and swapping the adapter would become a change to
/// each of them — the same argument `auth_module.dart` makes for
/// `FakeAuthRepository`.
final class DioReadingRepository implements ReadingRepository {
  /// A repository over [dataSource], projecting with [mapper] and [submits] and
  /// translating faults with [errors].
  ///
  /// All four are named and required, and none of them is resolved from the
  /// locator here: §3's DIP row says no `domain/` file names `Dio`, and a
  /// repository that reached for the global would be untestable over a fixture.
  const DioReadingRepository({
    required this.dataSource,
    required this.mapper,
    required this.submits,
    required this.errors,
  });

  /// Where the request goes. Injected rather than built, so a test can drive this
  /// repository over a fake adapter and so the endpoint path has exactly one home.
  final ReadingRemoteDataSource dataSource;

  /// Reading body → entity. `const`, and shared by every `DioReadingRepository`.
  final TodayReadingMapper mapper;

  /// Submission body → [SubmitResult].
  ///
  /// ## A SEPARATE INJECTED MAPPER, NOT A SECOND BRANCH OF [mapper]
  ///
  /// The two bodies are different shapes, and `TodayReadingMapper` is named for one
  /// of them. A `mapSubmit` method on it would make a **reading** mapper own the
  /// quiz's write path, and every reader of `SubmitResultMapper`'s scalar policy
  /// would have to find it through a class about verses.
  ///
  /// **Injected rather than `const SubmitResultMapper()` in the body**, so the
  /// repository has no hidden dependency: `home_module.dart` provides it, which is
  /// what makes the mapper swappable in one provider — and so a test can drive this
  /// repository over a fixture mapper, which `dio_repositories_test.dart` does not
  /// need today and which would otherwise be impossible without editing this class.
  final SubmitResultMapper submits;

  /// Exception → [Failure]. `const`, and the one place a status becomes a kind.
  final ApiErrorMapper errors;

  /// The wide read. One `get`, one mapper pass — see [todayScripture].
  @override
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  }) async {
    try {
      final Object? body = await dataSource.today(language);
      return mapper.mapScripture(body);
    } on DioException catch (error) {
      // Every transport fault and every non-2xx arrives here. §5 records that a
      // *missing* `X-User-Id` is a **400**, not a 401, so nothing below may
      // distinguish "unauthenticated" from "bad request" — the status decides the
      // kind and the body decides the message, both in `ApiErrorMapper`.
      return Result<ScriptureText>.failure(errors.fromDioException(error));
    }
  }

  /// `/`'s narrow read, and it is a **narrowing of [todayScripture]** rather than
  /// a second request.
  ///
  /// That is the whole of recorded decision 23 as implemented, and it is why the
  /// body above is the *only* `try` in this class. An earlier version had a second
  /// one — identical, calling `mapper.map` — which meant the two projections could
  /// disagree about whether a payload was readable and nothing would say so. A
  /// single `DioException` handler also means a new fault cannot be handled on one
  /// path and missed on the other.
  ///
  /// `Result.map` runs its function only for a success and leaves a failure
  /// byte-for-byte identical, so a 409 or a transport error propagates unchanged
  /// and the `Failure` a reader sees is the one the mapper or the error mapper
  /// wrote.
  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async =>
      (await todayScripture(language: language))
          .map((ScriptureText scripture) => scripture.toTodayReading());

  /// Grades one answer, and it is the port's only **write**.
  ///
  /// ## THE THIRD `try`, AND WHY IT IS NOT "A THIRD COPYING OF THE FIRST TWO"
  ///
  /// The two reads share one `try` because they are one path — [today] narrows
  /// [todayScripture]. This one is genuinely a different request with a different
  /// body and a different mapper, so it needs its own arm; what makes the shape
  /// uniform is that both arms are exactly the same two lines and a *different*
  /// mapper each.
  ///
  /// **Rejected: a shared private `_run(body, mapper)` helper.** It would be three
  /// lines long and would have to be generic over the mapper's output type, so the
  /// two call sites would each carry a type argument and a cast that the compiler
  /// cannot check across the erasure. §7's rule — two implementations of one
  /// invariant are two things to keep in step — cuts the other way here: there is
  /// one invariant ("`DioException` becomes a `Failure`, everything else goes
  /// through a mapper") and it is visible in three two-line arms that a reader can
  /// compare by eye, which is more than a generic wrapper invites.
  ///
  /// ## AND THE 409 IS **MAPPED, NOT PREVENTED**, AND ONLY ONE OF THOSE IS HERE
  ///
  /// §5 trap 3: a duplicate submit is `409 This question has already been submitted
  /// by this user.` This method maps it to `FailureKind.conflict` with the server's
  /// own message — `ApiErrorMapper`'s job, and required by §3's LSP row.
  ///
  /// It cannot **prevent** it, and nothing here pretends to. The prevention is
  /// `QuizAnswer.isAnswerable` in the domain layer, which closes a question whose
  /// wire `already_answered` is `true` before a request can exist. By the time this
  /// method is called the reader has already pressed the button, which is exactly
  /// why the rule belongs upstream.
  @override
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  }) async {
    try {
      final Object? body = await dataSource.submit(
        readingId: readingId,
        questionId: questionId,
        answer: answer,
      );
      return submits.map(body);
    } on DioException catch (error) {
      return Result<SubmitResult>.failure(errors.fromDioException(error));
    }
  }
}
