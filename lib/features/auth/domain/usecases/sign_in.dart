import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// Signs in with an email address and a password.
///
/// One of the three use cases `docs/plans/05-domain-model.md` §9.4 gives the
/// `auth` feature. PURE DART — `features/auth/domain/` is held to no Flutter, Dio
/// or http by Gate 1 — and it names the port, never an implementation
/// (AGENT_CONTEXT §3, DIP).
///
/// ## WHY IT IS A `UseCase` AND NOT A CALL STRAIGHT TO THE PORT
///
/// `SignInParams` is not a params object for its own sake. It exists so that
/// "signing in" is a **named thing** in the graph: a future feature that wants to
/// sign a reader in — a deep link, a restored session, an onboarding shortcut —
/// depends on the use case rather than reaching for a repository method, and a
/// rule added to signing in is added once.
///
/// ## WHAT IT DOES **NOT** DO
///
/// It does not validate. `features/auth/domain`'s `validateLogin` judges the
/// credentials and `FakeAuthRepository` runs it, so the rule lives in exactly one
/// place and the bloc can call it on every keystroke for live feedback while the
/// repository calls it again for the authoritative verdict. Duplicating it here
/// would give two implementations of one rule that could disagree, and the
/// disagreement would only show up as "the form said it was fine and the sign-in
/// failed".
final class SignIn implements UseCase<SignInParams, AuthSession> {
  /// Signs in through [repository].
  const SignIn(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(SignInParams params) =>
      _repository.signIn(email: params.email, password: params.password);
}

/// What [SignIn] needs.
///
/// Two named fields rather than two positional strings: `(a, b)` at a call site
/// says nothing about which is the address and which is the secret, and
/// transposing them would be a runtime failure that reads as "wrong password".
final class SignInParams {
  /// Signs in with [email] and [password].
  const SignInParams({required this.email, required this.password});

  /// The address, exactly as typed. Not trimmed here — `LoginCredentials.from`
  /// owns that asymmetry, and this type carries what it was given.
  final String email;

  /// The secret, exactly as typed.
  final String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInParams &&
          other.email == email &&
          other.password == password;

  @override
  int get hashCode => Object.hash(email, password);

  /// Not Equatable's default: it would print the password into every failing
  /// assertion. See `LoginCredentials.toString` for the same decision one layer
  /// down.
  @override
  String toString() => 'SignInParams(email: $email, password: ********)';
}
