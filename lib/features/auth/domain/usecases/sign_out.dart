import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// Ends the session.
///
/// A [NoParamsUseCase] and **not** a `UseCase<void, …>`, which cannot exist —
/// AGENT_CONTEXT §6, recorded decision 3 walks both broken spellings and the
/// reason. Calling it is `signOut()`.
///
/// It returns `Result<void>` rather than `Future<void>` because the port says so,
/// and a sign-out that cannot report failure is a sign-out that would swallow one.
final class SignOut implements NoParamsUseCase<void> {
  /// Signs out through [repository].
  const SignOut(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call() => _repository.signOut();
}
