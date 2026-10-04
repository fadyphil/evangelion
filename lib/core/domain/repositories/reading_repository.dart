import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';

/// Today's scheduled reading, as far as this client is concerned.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/reading/`
///
/// Two consumers, which is §3's placement test. `home`'s panel reads a
/// [TodayReading] — a reference, a translation, a verse count, the first verse's
/// text, and how many reflection questions are answered. `reading`'s sanctuary
/// reads the same endpoint and needs the verses and the questions in full.
///
/// §3's alternative — one `ReadingRepository` per feature — is not available:
/// `features/home` importing `features/reading` breaks the rule §3 states with no
/// exceptions, and `tool/verify_purity.sh` Gate 2 fails on the line. The port is
/// in the shared kernel for the same reason `AuthRepository` is: so the question
/// can be asked from either feature without either feature knowing the other.
///
/// ## THE PORT HAD **TWO** METHODS OVER ONE ENDPOINT, AND THAT IS RECORDED
/// DECISION 23
///
/// …and Phase 8 added a **third**, over a different endpoint, for the reason
/// [submitAnswer]'s own doc gives.
///
/// [todayScripture] is the wide read — every verse, every question, the whole
/// passage. [today] is `/`'s narrow read, and it is a **narrowing of the wide
/// entity**, not a second parse of the wire: `DioReadingRepository.today`
/// delegates to `todayScripture` and calls [ScriptureText.toTodayReading].
///
/// The alternatives, all rejected with reasons:
///
/// - **Two ports.** `ReadingRepository` and `ScriptureRepository` over the same
///   `GET /readings/today/{lang}`. Two adapters to register, two data sources, two
///   mappers, one request — and `07-file-map.md`'s adapter inventory grows from
///   three to four for no reader-visible gain. That is the recorded rejection.
///
/// - **One wide method only**, with `/`'s use case narrowing. This was weighed and
///   is the *honest* endpoint, but it rewrites `HomeBloc`'s dependency type and
///   every Phase-6 suite that stubs it, in a phase whose subject is `/reading`.
///   The two-method port keeps the same single request path and the same single
///   mapper, and differs only in where the narrowing call is written — so it buys
///   nothing that costs a reader anything.
///
/// - **One wide entity for both screens.** `/`'s panel draws a reference, three
///   counts and a truncated string. Handing it a `List<Verse>` and a
///   `Map<String, String>` of quiz options makes `home` depend on the whole
///   passage to read three integers, which is §3's "nothing enters the kernel
///   speculatively" run the other way.
///
/// ## AND `TodayReading` IS NOW A **VIEW**, WHICH IS WHAT MAKES THE ABOVE ONE
/// IMPLEMENTATION
///
/// Before Phase 7 the mapper produced a `TodayReading` and the wide shape did not
/// exist. It now produces a [ScriptureText], and `map()` is
/// `mapScripture().map((s) => s.toTodayReading())` — so the scalar table, the
/// `text_clean` rule and every refusal exist in exactly one place and the two
/// screens cannot answer "is this payload readable?" differently.
///
/// `home_page.dart` reads [TodayReading.currentStreak] off the entity and the top
/// bar reads `StreakSummary.currentStreak`, and the doc on that field explains why
/// they disagree — which a widened port does not change.
///
/// ## WHAT AN IMPLEMENTATION OWES (§3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`. An exception crossing
///   this seam reaches `HomeBloc`'s event handler, where
///   `analysis_options.yaml`'s `avoid_catching_errors` guarantees nothing catches
///   it, and the reader sees a screen that never finishes loading.
/// * **Always return a [Result]**, including for success. There is no overload
///   returning a bare value, so "did this handle the error arm?" is answered by
///   the type rather than by review.
/// * **HTTP 409 is a typed `Failure`, never an exception.** Not reachable from the
///   two **reads** — §5 trap 3's 409 belongs to `POST /readings/:id/submit`, which
///   is [submitAnswer] — and named here because it is the contract for that method
///   too, where it *is* reachable. A typed failure and a prevented request are two
///   different things; see [submitAnswer].
/// * **A body that cannot be mapped is `FailureKind.serialization`,** not a
///   throw and not a default. `failure.dart` documents that kind; the mappers in
///   `features/reading/data/mappers/` are where it is produced.
abstract interface class ReadingRepository {
  /// Today's reading, in [language].
  ///
  /// [language] is a named parameter rather than part of a params record because
  /// it is a single enum: `today(language: ReadingLanguage.arabic)` reads as
  /// what it is, and a record whose only field is one enum is a type whose only
  /// job is to name it.
  ///
  /// The path is `GET /api/v1/readings/today/{code}` and nothing else. There is
  /// **no `?date=` parameter** and no reading id: §2's route table fixes the
  /// passage as always today's, and §5 records that `?date=` must be exactly
  /// `YYYY-MM-DD` or it is rejected — a parameter this client has no use for
  /// because the only reading it can render is the current one.
  Future<Result<TodayReading>> today({required ReadingLanguage language});

  /// Today's passage, in full, in [language] — verses and questions as entities.
  ///
  /// **The wide read, and the one `/reading` calls.** Every contract above applies
  /// to it verbatim: never throws, always a [Result], a body that cannot be mapped
  /// is [FailureKind.serialization], and a 409 — not reachable from here, §5 trap
  /// 3's 409 belongs to `POST /readings/:id/submit` — is a typed failure rather
  /// than an exception.
  ///
  /// [today] is defined in terms of this one, and an implementation that
  /// implemented them independently would have two answers for one payload.
  /// `dio_repositories_test.dart` asserts the delegation in the failing direction:
  /// a body the wide mapper refuses produces the **same** [Failure] through both.
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  });

  /// Grades one answer: `POST /api/v1/readings/:id/submit`.
  ///
  /// ## WHY A **THIRD** METHOD ON THIS PORT AND NOT A SECOND PORT
  ///
  /// §3's ISP row asks for the smallest interface that satisfies a client, and the
  /// temptation here is `QuizRepository`: `/quiz` is the only consumer and a new
  /// feature is a new port. That is rejected on the same grounds
  /// `reading_repository.dart`'s own header records for
  /// [todayScripture] — **the endpoint is a reading endpoint.**
  /// `submissions.routes.ts` registers `fastify.post('/readings/:id/submit')`, the
  /// path is under `/readings`, and [readingId] is a field the reading endpoint
  /// produced. A `QuizRepository` would split one resource's writes from its reads
  /// across two files that have to agree about `reading_id` being today's.
  ///
  /// And `quiz`'s half of the argument is stronger: `08-build-phases.md` §Phase 8
  /// says `quiz` "declares no repository and no data source of its own", and the
  /// `POST` call "rides `reading`'s existing remote data source". A new port would
  /// have to be declared *somewhere*, and `core/domain/` is the only place a port
  /// may live (§3), so `QuizRepository` would sit beside `ReadingRepository` and
  /// `DioReadingRepository` would implement both — two interfaces over one class,
  /// which is the fat-port shape §3's ISP row forbids.
  ///
  /// ## AND THE PARAMETERS ARE **NOT VALIDATED HERE**
  ///
  /// `submissions.routes.ts:18` types the path parameter as
  /// `description: 'Reading UUID'` — a description, **not** a schema — while `:7`
  /// validates `question_id: z.string().uuid()`. So the backend validates one of
  /// these three values and not the others, and §5 traps 10 and 11 record that the
  /// `reading_id` it serves is a fabricated, **date-dependent** non-UUID today.
  ///
  /// A client-side UUID check on [readingId] would therefore reject the only reading
  /// this backend serves, and one on [questionId] would turn §5's documented `400`
  /// into a client-side failure that never reaches the wire — which is precisely
  /// the reasoning recorded decision 15 already refused for `X-User-Id`.
  /// **`answer` is passed verbatim for the same reason**, and its contract is
  /// `z.string().min(1)`: `submissions.routes.ts:35` documents it as *"Selected
  /// option (A, B, C, D) or boolean"*, so `'true'` is legal and a client that
  /// checked it against the option letters would refuse a valid request.
  ///
  /// ## AND THE 409 IS **A TYPED FAILURE THE CLIENT MUST PREVENT**
  ///
  /// §5 trap 3: a duplicate submit is `409 This question has already been submitted
  /// by this user.` Mapping it here is necessary and **not sufficient** — the plan's
  /// requirement is that the quiz disable a question whose `already_answered` is
  /// `true` so the reader is never walked into a conflict. That is
  /// `QuizAnswer.isAnswerable`'s job, in the domain layer, and no repository can do
  /// it: by the time a request exists the reader has already pressed the button.
  /// `dio_repositories_test.dart` asserts both halves side by side.
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  });
}
