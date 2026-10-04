import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
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
/// ## THE PORT IS **NARROW**, AND THAT IS NOT A SHORTCUT
///
/// [today] returns the thirteen fields `/`'s panel draws and **not** the verses
/// or the questions. That is not a stub to be filled in — it is the projection
/// those fields imply, and the wide shape has its own trap that Home must not
/// inherit: AGENT_CONTEXT §5 trap 2, `text_clean` is **AR-only** and the English
/// payload has no such key at all. A wide port would put a nullable
/// scripture-text field in front of a screen that shows a truncated preview and
/// does not care.
///
/// ## WHAT PHASE 7 DOES WITH THIS FILE
///
/// Phase 7 **widens** it rather than adding a second adapter. Two ports over one
/// endpoint — one wide for `/reading`, one narrow for `/` — would be two
/// repositories, two data sources and two mappers for one request, and
/// `07-file-map.md`'s adapter inventory would have to grow from three to four.
/// So the resolution is recorded in `AGENT_CONTEXT` §9 as a new decision rather
/// than decided here: **one port, widened**, with the narrow projection becoming
/// the reading screen's own narrower read of the wide payload. `home_page.dart`
/// reads [TodayReading.currentStreak] off the entity and the top bar reads
/// `StreakSummary.currentStreak` — and the doc on that field explains why they
/// disagree, which is a thing a widened port does not change.
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
}
