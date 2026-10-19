import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The reader's streak summary — the number behind `/journey`'s hero.
///
/// ## THE PROTOTYPE'S HERO IS A LITERAL, AND OURS IS NOT
///
/// `eva/redesign.html:589` carries `12` in the markup, and
/// `eva/redesign.html:989` writes it in: `el('heroNum').textContent=N(12)` —
/// the same line that feeds `/`'s streak chip (`el('streakN')`). ADR-0022's
/// fiction table marks the hero number as **real** and names its replacement:
/// "`GET /streak/summary` → `current_streak`"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:46`).
///
/// Ours is `StreakSummary.currentStreak` from that endpoint, and it is real
/// in the sense that matters: it is the server's own number, and it can be
/// **0**. A golden that shows `12` because the prototype says `12` would be a
/// golden of a fiction.
///
/// ## WHY IT IS A SEPARATE USE CASE FROM THE HISTORY ONE
///
/// Two endpoints, two payloads, two failure modes — §3's ISP row, the same
/// reason `StreakRepository` is two methods rather than one wide one. The
/// summary is the endpoint's scalars; the history is thirty rows, and the
/// endpoint charges a subquery per row for them
/// (`streak.service.ts:98-112`). A caller that wants the hero number must not
/// pay for thirty rows, and the server does not offer the two in one payload:
/// `streak.routes.ts:163-172` returns the summary as the same service call
/// **minus** `history` and `today_date`.
///
/// ## AND THE FAILURE IS THE PORT'S
///
/// The use case adds nothing to the answer, so it adds nothing to the failure
/// either: a `Result.failure` crosses this seam unchanged. A second place that
/// decides what a failure means would be a second place to forget.
final class LoadJourneyStreakSummary implements NoParamsUseCase<StreakSummary> {
  /// Loads the streak summary through [repository].
  const LoadJourneyStreakSummary(this._repository);

  final StreakRepository _repository;

  @override
  Future<Result<StreakSummary>> call() => _repository.summary();
}
