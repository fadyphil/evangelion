import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The most recent scheduled day — `/`'s last light.
///
/// A [NoParamsUseCase] like `LoadStreakSummary`, for §6 decision 3's reason: the
/// two-member shape is a standalone interface and `usecase()` is the only spelling
/// that compiles.
///
/// ## WHY A `List` COMES OUT OF THE PORT AND A SINGLE ENTRY GOES IN THE STATE
///
/// `StreakRepository.history()` returns all thirty rows because that is the
/// response and because `/journey` (Task 5.6) needs the whole set for its rings.
/// **This use case is where the card's one row is chosen** — `first`, which is the
/// server's own order (`streak.service.ts:88-96`, `scheduled_date DESC`) rather
/// than a client sort — so that the choice is a named, tested function and not an
/// index a widget reaches for.
///
/// ## AND WHY THE EMPTY CASE IS `null` AND NOT A FABRICATED ROW
///
/// `ADR-0001` cut the last-light card because there was nothing to put in it, and
/// the prototype's own empty state is `redesign.html:1192-1197`: `lastRef` becomes
/// `—`, the body reads `noLight` — "no light received yet — open a book below" —
/// and the tap is removed (`cursor:default`). `history` is empty exactly when the
/// cohort has no scheduled reading on file, which is a real state a new reader is
/// in.
///
/// A `Result` of `null` rather than a sentinel row: a sentinel would have to carry
/// a reference string (`—` is the prototype's, and a fabricated reference is a
/// fabricated fact), and every caller would then have to know which field to
/// ignore.
final class LoadLastLight implements NoParamsUseCase<StreakHistoryEntry?> {
  /// Loads the last scheduled day through [repository].
  const LoadLastLight(this._repository);

  final StreakRepository _repository;

  @override
  Future<Result<StreakHistoryEntry?>> call() async {
    final Result<List<StreakHistoryEntry>> rows = await _repository.history();
    // `map`, not `getOrElse` on the list. **The first version of this used
    // `getOrElse((_) => const [])`, which turned a `Result.left` into a `Result.of`
    // with no entry** — so a failed `GET /streak` reached the bloc as `ready` with
    // an empty pointer, and the card rendered its *empty* state ("no light received
    // yet") for a request that had failed. `home_bloc_test.dart`'s "a failed LAST
    // LIGHT" group found it by asking for `failed` and reading `ready`.
    //
    // `Result.map` carries the left arm through unchanged, which is the whole of
    // what "a repository never throws and always returns a `Result`" means at this
    // seam.
    return rows.map((List<StreakHistoryEntry> history) => history.firstOrNull);
  }
}
