import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The session the app is currently signed in with, so `/journey` can name the
/// reader and draw their monogram.
///
/// ## WHY THIS EXISTS WHEN `features/auth` ALREADY HAS ONE
///
/// Because **`journey` may not import `features/auth`.** §3 forbids a feature
/// importing another with no exceptions and `tool/verify_purity.sh` Gate 2
/// fails on the line, and `features/auth/domain/usecases/get_current_session.dart`
/// is inside `auth`. So the call is declared again here, over the same port.
///
/// ## THIS IS THE **THIRD** SUCH DECLARATION, AND THE THIRD IS THE ARGUMENT
///
/// The pattern has been made twice before, and the second time is what makes
/// the third ordinary rather than a surprise:
///
/// | # | file | which screen it is for |
/// | --- | --- | --- |
/// | 1 | `features/home/domain/usecases/get_reader_session.dart` | `/`'s greeting — AGENT_CONTEXT §6, recorded decision 25 |
/// | 2 | `features/leaderboard/domain/usecases/get_board_reader_session.dart` | `/communion`'s you-card — Task 5.5 |
/// | 3 | this file | `/journey`'s name and orb — Task 5.6 |
///
/// **The second one carries the lesson the third has to honour.** `GetBoardReaderSession`
/// and `GetReaderSession` were *different types* — different libraries — so
/// nothing broke when both were registered in the same injector graph, but
/// the DI's own inventory test could not say which registration was which: it
/// renders a registration as `lifetime<type> member`, and both were
/// `lazySingleton<GetReaderSession> getReaderSession`. A list that cannot say
/// which entry is which is a list that cannot be checked.
///
/// So the third is named **`GetJourneyReaderSession`**, and not
/// `GetReaderSession`: a third identically-named registration in the same
/// graph would repeat exactly the ambiguity the second instance was renamed to
/// remove. The name says which feature the use case belongs to, which is the
/// fact a reader of the graph is trying to establish.
///
/// ## WHY THE DUPLICATION IS THE ACCEPTED PRICE, AND NOT AN OVERSIGHT
///
/// The alternative — promoting `GetCurrentSession` to `core/domain/usecase/` —
/// was weighed in Phase 4 and not taken, because §3 says
/// `features/<f>/domain/` holds *this feature's own use cases* and applies the
/// same placement test that put the **port** in the shared kernel: what
/// belongs in the kernel is what two features ask of the outside world, and
/// `AuthRepository.getCurrentSession` is already there. The port is shared;
/// the use case is not.
///
/// ## WHAT `/journey` READS OUT OF IT
///
/// The prototype's name is a **literal**: `jName` is `Mariam Hanna`
/// (`eva/redesign.html:587`), written by JavaScript at `:992`, and the orb's
/// letter is a literal `M` (`:586`). ADR-0022's fiction table marks the name
/// as a **stub** — "a real `/me` endpoint"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:56`) — and there
/// is no `/me`: "**The reader's own name is a stub, with one partial
/// exception.** There is no `/me`" (`:106`).
///
/// Ours is the reader's **own** session: `AuthSession.displayName` for the
/// name and `AuthSession.initials` for the monogram. The values already exist
/// — the seeded session carries them — and this use case is the legal way for
/// a feature that may not import `auth` to reach them.
///
/// ## AND THE FAILURE ARM IS THE PORT'S
///
/// `AuthRepository.getCurrentSession` answers `Failure` for "no session" **or**
/// for "the check failed", and the port's doc says the caller must not tell
/// the two apart. `/journey` draws a name and a monogram out of this, so both
/// arms render the screen without one — and the failure is passed through
/// unchanged rather than reclassified, because a second place that decides
/// what a failure means is a second place to forget.
final class GetJourneyReaderSession implements NoParamsUseCase<AuthSession> {
  /// Reads the current session through [repository].
  const GetJourneyReaderSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call() => _repository.getCurrentSession();
}
