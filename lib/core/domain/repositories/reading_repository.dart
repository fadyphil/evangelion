import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
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
/// ## THE PORT HAS **TWO** METHODS OVER ONE ENDPOINT, AND THAT IS RECORDED
/// DECISION 23
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
/// * **HTTP 409 is a typed `Failure`, never an exception.** Not reachable from
///   this method — §5 trap 3's 409 belongs to `POST /readings/:id/submit` — and
///   named here because the contract is the contract for every method of the port
///   a future submit would join.
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
}
