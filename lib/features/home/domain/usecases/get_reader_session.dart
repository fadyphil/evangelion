import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The session the app is currently signed in with, so `/` can greet the reader.
///
/// ## WHY THIS EXISTS WHEN `features/auth` ALREADY HAS ONE
///
/// Because **`home` may not import `features/auth`.** §3 forbids a feature
/// importing another with no exceptions and `tool/verify_purity.sh` Gate 2 fails
/// on the line, and `features/auth/domain/usecases/get_current_session.dart` is
/// inside `auth`. So the call is declared again here, over the same port.
///
/// This is duplication, and it is the accepted price of the feature rule rather
/// than an oversight. The alternative — promoting `GetCurrentSession` to
/// `core/domain/usecase/` — was weighed and not taken, because §3 says
/// `features/<f>/domain/` holds *this feature's own use cases* and applies the same
/// placement test that put the **port** in the shared kernel: two features asking
/// the same question of the outside world is what belongs in `core/domain`, and
/// `AuthRepository.getCurrentSession` is already there.
///
/// ## WHY `/` NEEDS IT AT ALL
///
/// Because the prototype's greeting and avatar are **hard-coded**:
/// `HomeScreen.tsx:27` renders `Miriam` and `ds.tsx:525` renders `MK`. There is no
/// user endpoint and the profile screen is cut, so those two strings are the only
/// "who is this" the prototype has, and shipping them would be fake data that reads
/// as real — `HomePage`'s Phase-4 stub doc says the same about a hard-coded streak.
///
/// `AuthSession` already carries `displayName: 'David Mina'` and `initials: 'DM'`
/// from `seedAuthSession`, so the real values exist; this use case is the legal way
/// for a feature that may not import `auth` to reach them.
final class GetReaderSession implements NoParamsUseCase<AuthSession> {
  /// Reads the current session through [repository].
  const GetReaderSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call() => _repository.getCurrentSession();
}
