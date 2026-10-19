import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The session the app is currently signed in with, so `/communion` can name
/// the reader on the you-card.
///
/// ## WHY IT IS NAMED `GetBoardReaderSession` AND NOT `GetReaderSession`
///
/// Because `features/home/domain/usecases/get_reader_session.dart` already
/// answers the same question under the name **`GetReaderSession`**, and the two
/// were both registered in the same injector graph. They are **different
/// types** — different libraries — so nothing broke; but the DI's own
/// inventory test could not say which registration was which, because it
/// renders a registration as `lifetime<type> member` and both were
/// `lazySingleton<GetReaderSession> getReaderSession`.
///
/// A list that cannot say which entry is which is a list that cannot be
/// checked, and the alternative — teaching the test to carry the module
/// qualifier — would have made a gate about the *graph* into a gate about the
/// *test's* rendering. The name is the smaller change and the more honest one:
/// it says which feature the use case belongs to, which is the fact a reader
/// of the graph is trying to establish.
///
/// The home copy keeps its name: it is home's, and it was there first.
///
/// ## WHY THIS EXISTS WHEN `features/auth` ALREADY HAS ONE
///
/// Because **`leaderboard` may not import `features/auth`.** §3 forbids a feature
/// importing another with no exceptions and `tool/verify_purity.sh` Gate 2 fails on
/// the line, and `features/auth/domain/usecases/get_current_session.dart` is inside
/// `auth`. So the call is declared again here, over the same port — exactly the shape
/// `features/home/domain/usecases/get_reader_session.dart` records for `/`.
///
/// This is duplication, and it is the accepted price of the feature rule rather than
/// an oversight. The alternative — promoting `GetCurrentSession` to
/// `core/domain/usecase/` — was weighed in Phase 4 and not taken, because §3 says
/// `features/<f>/domain/` holds *this feature's own use cases* and applies the same
/// placement test that put the **port** in the shared kernel: what belongs in the
/// kernel is what two features ask of the outside world, and
/// `AuthRepository.getCurrentSession` is already there.
///
/// ## WHY `/communion` NEEDS IT
///
/// The reworked you-card (`eva/redesign.html:629`) shows the reader's own name. The
/// prototype hard-codes `Mariam Hanna` (`:1055-1064`), and ADR-0022's fiction table
/// names that as a stub replaced by a future `/me`
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:113-117`). There is no
/// `/me` today, but `AuthSession` already carries `displayName` from the seeded
/// session, so the real value exists and this is the legal way for a feature that
/// may not import `auth` to reach it. A ranked reader's **row** carries `full_name`
/// and is preferred; this is the fallback for a reader the payload does not rank.
final class GetBoardReaderSession implements NoParamsUseCase<AuthSession> {
  /// Reads the current session through [repository].
  const GetBoardReaderSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call() => _repository.getCurrentSession();
}
