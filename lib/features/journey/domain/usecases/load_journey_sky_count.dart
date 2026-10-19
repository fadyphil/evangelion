import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// How many stars are lit — the first number on `/journey`'s sky line.
///
/// ## THE PORT'S OWN DOC ALREADY NAMES `journey` AS THIS CONSUMER
///
/// `core/domain/repositories/sky_repository.dart` states a three-consumer
/// table — `reading` records, `quiz` records a flare, and **`journey` counts**
/// (`:12-14`) — and the [SkyRepository.count] entry says the count is "how
/// many stars are lit, for `journey`'s widget, which draws one number
/// (`jSkyN` at `eva/redesign.html:596`, written by `updateSkyWidget` at
/// `:1186-1187`)" (`:28-32`).
///
/// **So the port was placed in the shared kernel with this consumer already
/// named in it**, and this use case is journey's own way of asking it. That is
/// the whole reason the port is in `core/domain/` and not in one feature: a
/// port inside `reading` or `quiz` would have to be imported by the other two,
/// which §3 forbids with no exceptions and `tool/verify_purity.sh` Gate 2 fails
/// on the line.
///
/// ## WHY A COUNT AND NOT THE LIST OF ENTRIES
///
/// §3's ISP row again: a caller that wants one number depends on the smallest
/// interface that satisfies it, and the port says so itself. The prototype's
/// number is the count of `.star` elements in the sky DOM
/// (`eva/redesign.html:1134`) — the same thing this port counts, and the
/// prototype's sky line writes it into `jSkyN` at `:596`.
///
/// ## THE STARS ARE A STUB, AND THAT IS THE PORT'S BUSINESS, NOT THIS FILE'S
///
/// The starfield is `stub (local)` in ADR-0022's fiction table — "a stars
/// table" (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:59`) — and
/// the port's doc says so: replacing the stub with a real endpoint is a change
/// to one adapter and no change to a screen, because every reader goes through
/// this port. This use case reads the port and adds nothing to it.
///
/// ## AND THE FAILURE IS THE PORT'S
///
/// A sky store that cannot be reached reports `FailureKind.storage`
/// (`sky_repository.dart:96-100`), and that crosses this seam unchanged. This
/// use case does not reclassify it — the second number on the sky line, the
/// constellations, comes from the streak history and not from here.
final class LoadJourneySkyCount implements NoParamsUseCase<int> {
  /// Reads the lit-star count through [repository].
  const LoadJourneySkyCount(this._repository);

  final SkyRepository _repository;

  @override
  Future<Result<int>> call() => _repository.count();
}
