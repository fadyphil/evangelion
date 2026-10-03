import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The three `auth` use cases — red-first (AGENT_CONTEXT §6).
///
/// They are three lines each, so what is worth testing is the **seam**: that each
/// one reaches its port with the arguments it was given and hands the result
/// straight back. A use case that swallowed a `Failure` and returned a fresh
/// success would compile, look right, and destroy the error a player has to read;
/// that is the failure this file exists to catch.
///
/// The mocks are over the **port**, not over the fake repository, so nothing here
/// knows that `FakeAuthRepository` exists — the substitution the whole
/// architecture turns on.
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  /// A real session rather than a mock: [AuthSession] is `final`, so it cannot
  /// be implemented from here, and a real one carries no mocking machinery into
  /// what is otherwise a test about argument pass-through.
  final AuthSession session = AuthSession(
    userId: '11111111-1111-1111-1111-111111111111',
    email: 'david@evangelion.app',
    displayName: 'David Mina',
    initials: 'DM',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  const String email = 'david@evangelion.app';
  const String password = 'correct horse';
  const Failure failure = Failure(
    kind: FailureKind.validation,
    message: 'nope',
  );

  setUpAll(() {
    registerFallbackValue(const SignInParams(email: '', password: ''));
  });

  setUp(() {
    repository = MockAuthRepository();
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Result<AuthSession>.success(session));
    when(repository.getCurrentSession)
        .thenAnswer((_) async => Result<AuthSession>.success(session));
    when(repository.signOut)
        .thenAnswer((_) async => const Result<void>.success(null));
  });

  group('SignIn', () {
    test('passes the credentials through, unmodified', () async {
      await SignIn(repository)(
        const SignInParams(email: email, password: password),
      );

      verify(() => repository.signIn(email: email, password: password))
          .called(1);
    });

    test('passes a password with its spaces intact', () async {
      // The trimming asymmetry lives in `LoginCredentials`, not here. A use case
      // that trimmed would silently change the secret the repository judges.
      const String spaced = '  spaces  matter  ';

      await SignIn(repository)(
        const SignInParams(email: email, password: spaced),
      );

      verify(() => repository.signIn(email: email, password: spaced)).called(1);
    });

    test('returns the repository\'s success untouched', () async {
      final Result<AuthSession> result = await SignIn(repository)(
        const SignInParams(email: email, password: password),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrElse(session), same(session));
    });

    test('returns the repository\'s failure untouched', () async {
      // The one behaviour worth pinning. A use case that rebuilt the Failure
      // would produce an equal-but-different object, and a bloc comparing with
      // `identical` would see a change where there was none; one that turned a
      // failure into a success would take an error away from the player.
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Result<AuthSession>.failure(failure));

      final Result<AuthSession> result = await SignIn(repository)(
        const SignInParams(email: email, password: password),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrElse(failure), same(failure));
    });

    test('SignInParams compares by value and hides the password', () {
      expect(
        const SignInParams(email: email, password: password),
        const SignInParams(email: email, password: password),
      );
      expect(
        const SignInParams(email: email, password: password),
        isNot(
          const SignInParams(email: 'other@evangelion.app', password: password),
        ),
      );
      expect(
        const SignInParams(email: email, password: password).toString(),
        isNot(contains(password)),
      );
    });
  });

  group('SignOut', () {
    test('calls the port and returns its result', () async {
      final Result<void> result = await SignOut(repository)();

      verify(repository.signOut).called(1);
      expect(result.isSuccess, isTrue);
    });

    test('and surfaces a failure rather than dropping it', () async {
      when(repository.signOut)
          .thenAnswer((_) async => const Result<void>.failure(failure));

      final Result<void> result = await SignOut(repository)();

      expect(result.failureOrElse(failure), same(failure));
    });
  });

  group('GetCurrentSession', () {
    test('returns the session the port reports', () async {
      final Result<AuthSession> result = await GetCurrentSession(repository)();

      verify(repository.getCurrentSession).called(1);
      expect(result.valueOrElse(session), same(session));
    });

    test('and passes a failure straight through', () async {
      when(repository.getCurrentSession)
          .thenAnswer((_) async => const Result<AuthSession>.failure(failure));

      expect(
        (await GetCurrentSession(repository)()).failureOrElse(failure),
        same(failure),
      );
    });
  });

  group('the two no-parameter use cases', () {
    // AGENT_CONTEXT §6, recorded decision 3: `NoParamsUseCase` is a standalone
    // interface, not a subtype of `UseCase<void, Out>`, because Dart's function
    // subtyping rejects both repairs. What matters is therefore the **call site**
    // — `usecase()` with no argument — so this test assigns each to the interface
    // type and then invokes it bare.
    //
    // An earlier version of this asserted `expect(SignOut, isA<NoParamsUseCase<void>>())`,
    // which is false: `SignOut` there is a `Type` object, and a `Type` is not an
    // instance of the interface it declares. It read like a shape check and
    // checked nothing.
    test(
      'are assignable to NoParamsUseCase and callable with no argument',
      () async {
        final NoParamsUseCase<void> signOut = SignOut(repository);
        final NoParamsUseCase<AuthSession> current = GetCurrentSession(
          repository,
        );

        await signOut();
        await current();

        verify(repository.signOut).called(1);
        verify(repository.getCurrentSession).called(1);
      },
    );
  });
}
