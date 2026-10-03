import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The session already in hand, if there is one.
///
/// ## WHY A COLD LAUNCH ASKS THIS INSTEAD OF SHOWING THE FORM
///
/// `AuthBloc` runs this on start-up so a reader who is already signed in goes
/// straight to `/` rather than through the form again. Today that never
/// succeeds — `FakeAuthRepository` holds its session in a field, so a restart
/// starts empty — and the use case is still worth shipping, because
///
/// * it is the third of the three `auth` use cases
///   (`docs/plans/05-domain-model.md` §9.4), and
/// * the moment a real adapter lands, this is the line that changes and nothing
///   else. `AuthBloc` already treats "no session" and "the check failed" alike, so
///   a real adapter that can fail does not need a different `AuthBloc`.
///
/// ## AND WHY "FAILED" IS NOT DISTINGUISHED FROM "NONE"
///
/// `AuthBloc` treats both as "show the form". That is a decision, not a
/// simplification: with no auth endpoint there is no call that can fail, and
/// inventing a distinction would be a branch nothing could reach. The port's doc
/// records that a real adapter must not depend on the two being different.
final class GetCurrentSession implements NoParamsUseCase<AuthSession> {
  /// Reads the current session through [repository].
  const GetCurrentSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call() => _repository.getCurrentSession();
}
