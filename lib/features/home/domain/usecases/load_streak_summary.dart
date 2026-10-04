import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The reader's streak summary.
///
/// A [NoParamsUseCase] rather than a `UseCase<void, StreakSummary>`, and
/// AGENT_CONTEXT §6 recorded decision 3 says exactly why: the `extends` clause is
/// illegal Dart (a `void` parameter is still required positionally at the call
/// site), so the two-member shape is a standalone interface and `usecase()` is the
/// only spelling that compiles.
///
/// ## WHY IT IS NOT "TODAY'S READING'S STREAK"
///
/// Because it is a **different endpoint with a different set of headers**
/// requirements** — `streak/summary` requires `X-User-Id` and `readings/today`
/// does not — and, more to the point, because the two disagree: the summary says
/// `current_streak: 0` and `today_completed: false` while the reading says `4` and
/// `is_fully_completed: true`. Reading it from the reading endpoint would be a
/// reconciliation, and `StreakSummary`'s doc records that a reconciliation is the
/// one answer this client does not give.
final class LoadStreakSummary implements NoParamsUseCase<StreakSummary> {
  /// Loads the streak summary through [repository].
  const LoadStreakSummary(this._repository);

  final StreakRepository _repository;

  @override
  Future<Result<StreakSummary>> call() => _repository.summary();
}
