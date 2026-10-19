import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The reader's last thirty scheduled days — the rows the three rings are
/// derived from.
///
/// ## THE PORT ALREADY NAMES `/journey` AS ONE OF ITS TWO CALLERS
///
/// `StreakRepository.history()`'s own doc says who asks for it: `/`'s
/// last-light card, "and `/journey`'s rings (Task 5.6)"
/// (`core/domain/repositories/streak_repository.dart:68-70`). The port is in
/// the shared kernel for the reason §3 gives — two consumers — and this use
/// case is journey's own way of asking it.
///
/// ADR-0022 adopts the endpoint for exactly this screen: "`GET /streak` is
/// adopted alongside `/streak/summary` … `history[]` is the only measured
/// source for 'last light', the Journey rings, and any per-book completion"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:131-135`).
///
/// ## THE THIRTY DAYS ARE THE SERVER'S, AND THIS USE CASE DOES NOT TOUCH THEM
///
/// `streak.service.ts:87-95` queries the last thirty scheduled readings with
/// `ORDER BY dr.scheduled_date DESC` (`:93`) and `LIMIT 30` (`:94`), and the
/// port's doc is explicit that the order is the server's and that an
/// implementation of the port does not sort, filter or trim
/// (`streak_repository.dart:74-80`). So the rows arrive most-recent-first and
/// this use case hands them on exactly as they came.
///
/// **The thirty-day cap is why the rings' ratios are window ratios and not
/// lifetime ones** — see `journey_rings.dart`.
///
/// ## AND THE FAILURE IS THE PORT'S
///
/// `Result.failure` crosses this seam unchanged, and the port's contract says
/// a row that cannot be read fails the whole array rather than being skipped
/// (`streak_repository.dart:45-48`). Nothing here reclassifies it.
final class LoadJourneyStreakHistory
    implements NoParamsUseCase<List<StreakHistoryEntry>> {
  /// Loads the streak history through [repository].
  const LoadJourneyStreakHistory(this._repository);

  final StreakRepository _repository;

  @override
  Future<Result<List<StreakHistoryEntry>>> call() => _repository.history();
}
