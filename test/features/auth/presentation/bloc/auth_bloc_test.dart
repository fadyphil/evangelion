import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// [AuthBloc] — red-first with `bloc_test` (AGENT_CONTEXT §6: every cubit).
///
/// ## WHAT IS MOCKED, AND WHY IT IS THE PORT
///
/// The three use cases are `final class`es, which is deliberate: they cannot be
/// re-implemented outside their library, so no test can grow a look-alike with
/// one method changed. The seam that is mockable is
/// [AuthRepository] — the port — and the bloc is built over **real** use cases
/// on top of a mocked one. That is the shape production has, and it means this
/// file also exercises the use cases on the way in.
///
/// An earlier draft mocked the use cases and had to fall back to a hand-written
/// `_NeverCompletesSignIn`; that became possible because a `Mock` *can* implement
/// a class that is `implements`-only, and the mock library does not honour
/// `final`. Mocking the port reaches the same state with one class fewer and with
/// the composition the app actually uses.
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  final AuthSession session = AuthSession(
    userId: '11111111-1111-1111-1111-111111111111',
    email: 'david.mina@evangelion.app',
    displayName: 'David Mina',
    initials: 'DM',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  const String email = 'david@evangelion.app';
  const String goodPassword = 'correct horse';
  const String shortPassword = 'short';

  /// The same bloc production builds: real use cases over a mocked port.
  AuthBloc build({Completer<Result<AuthSession>>? pending}) {
    if (pending != null) {
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => pending.future);
    }
    return AuthBloc(
      signIn: SignIn(repository),
      getCurrentSession: GetCurrentSession(repository),
      signOut: SignOut(repository),
    );
  }

  setUp(() {
    repository = MockAuthRepository();
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Result<AuthSession>.success(session));
    when(repository.getCurrentSession).thenAnswer(
      (_) async => const Result<AuthSession>.failure(
        Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
      ),
    );
    when(repository.signOut)
        .thenAnswer((_) async => const Result<void>.success(null));
  });

  group('the cold launch', () {
    blocTest<AuthBloc, AuthState>(
      'starts in unknown, so nothing has claimed a session yet',
      build: build,
      verify: (AuthBloc bloc) {
        expect(bloc.state.status, AuthSessionStatus.unknown);
        expect(bloc.state.isSignedIn, isFalse);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'AuthStarted with no session lands on signedOut',
      // An **emit**, not silence. The first version left `unknown` standing and
      // emitted nothing, which left `signedOut` reachable only by pressing "Sign
      // in" with a bad password or by signing out — so "no session" and "the form
      // is up" were different states depending on how the reader arrived, and
      // `unknown` outlived the only moment it described.
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthStarted()),
      expect: () => <AuthState>[
        const AuthState(status: AuthSessionStatus.signedOut),
      ],
      verify: (AuthBloc bloc) {
        expect(bloc.state.isSignedIn, isFalse);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'AuthStarted with a session goes straight to signed in',
      setUp: () {
        when(repository.getCurrentSession)
            .thenAnswer((_) async => Result<AuthSession>.success(session));
      },
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthStarted()),
      expect: () => <AuthState>[
        AuthState(status: AuthSessionStatus.signedIn, session: session),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'and a restored session leaves the form empty',
      // If the restore put anything into the typed fields, a stale address would
      // sit in a box the reader cannot see, and `canSubmit` would be answering
      // about it.
      setUp: () {
        when(repository.getCurrentSession)
            .thenAnswer((_) async => Result<AuthSession>.success(session));
      },
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthStarted()),
      verify: (AuthBloc bloc) {
        expect(bloc.state.isSignedIn, isTrue);
        expect(bloc.state.email, isEmpty);
        expect(bloc.state.password, isEmpty);
        expect(bloc.state.canSubmit, isFalse);
      },
    );
  });

  group('typing', () {
    blocTest<AuthBloc, AuthState>(
      'an untouched form carries no error at all',
      // A blank field is "required", and "required" on a field nobody has typed in
      // is a criticism of the form rather than of the reader. This is the rule
      // the prototype's literal error broke — it painted
      // "That password's too short" on a field no keystroke had ever reached.
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthStarted()),
      verify: (AuthBloc bloc) {
        expect(bloc.state.emailError, isNull);
        expect(bloc.state.passwordError, isNull);
        expect(bloc.state.formError, isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'and a half-typed address is flagged the moment it stops being one',
      // Live rather than on submit. The prototype's error was a literal, so there
      // was no moment at which it could be *wrong*; here there is one, and the
      // reader sees it while the address is still incomplete.
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthEmailChanged('d')),
      expect: () => <AuthState>[
        const AuthState(
          email: 'd',
          emailTouched: true,
          emailError: 'Enter a valid email address',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'and a half-typed address becomes one as soon as it stops being an address',
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthEmailChanged('david@')),
      expect: () => <AuthState>[
        const AuthState(
          email: 'david@',
          emailTouched: true,
          emailError: 'Enter a valid email address',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'the error clears the moment the address becomes valid',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged('david@'))
        ..add(const AuthEmailChanged(email)),
      expect: () => <AuthState>[
        const AuthState(
          email: 'david@',
          emailTouched: true,
          emailError: 'Enter a valid email address',
        ),
        const AuthState(email: email, emailTouched: true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'a short password surfaces the prototype\'s own message, live',
      // The Phase-5 verification line, and the direct replacement for
      // `LoginScreen.tsx:52`'s hard-coded `error="That password's too short"`.
      build: build,
      act: (AuthBloc bloc) =>
          bloc.add(const AuthPasswordChanged(shortPassword)),
      expect: () => <AuthState>[
        const AuthState(
          password: shortPassword,
          passwordTouched: true,
          passwordError: kShortPasswordMessage,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emptying a field the reader had typed in is an error, not a reset',
      // The counterpart to the untouched case, and the reason `emailTouched` is
      // state rather than a comparison with the empty string: an empty field the
      // reader has just cleared is a field with a problem, and an empty field
      // nobody has reached is not. Only one of the two can be answered by
      // looking at the value.
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthEmailChanged('')),
      expect: () => <AuthState>[
        const AuthState(email: email, emailTouched: true),
        const AuthState(emailTouched: true, emailError: kRequiredMessage),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'typing a valid password clears the password error',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthPasswordChanged(shortPassword))
        ..add(const AuthPasswordChanged(goodPassword)),
      expect: () => <AuthState>[
        const AuthState(
          password: shortPassword,
          passwordTouched: true,
          passwordError: kShortPasswordMessage,
        ),
        const AuthState(password: goodPassword, passwordTouched: true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'the visibility toggle flips and flips back',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthPasswordVisibilityToggled())
        ..add(const AuthPasswordVisibilityToggled()),
      expect: () => <AuthState>[
        const AuthState(isPasswordVisible: true),
        const AuthState(),
      ],
    );
  });

  group('canSubmit', () {
    blocTest<AuthBloc, AuthState>(
      'is true once both fields hold valid values',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(goodPassword)),
      verify: (AuthBloc bloc) => expect(bloc.state.canSubmit, isTrue),
    );

    blocTest<AuthBloc, AuthState>(
      'and false with only one field filled',
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthEmailChanged(email)),
      verify: (AuthBloc bloc) => expect(bloc.state.canSubmit, isFalse),
    );

    blocTest<AuthBloc, AuthState>(
      'and false while a field is in error',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(shortPassword)),
      verify: (AuthBloc bloc) {
        expect(bloc.state.passwordError, kShortPasswordMessage);
        expect(
          bloc.state.canSubmit,
          isFalse,
          reason:
              'a reader with a three-character password cannot press the button, '
              'because the error is already on screen live',
        );
      },
    );

    blocTest<AuthBloc, AuthState>(
      'and false while an attempt is in flight',
      build: () => build(pending: Completer<Result<AuthSession>>()),
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(goodPassword))
        ..add(const AuthSubmitted()),
      verify: (AuthBloc bloc) {
        expect(bloc.state.isBusy, isTrue);
        expect(bloc.state.canSubmit, isFalse);
      },
    );
  });

  group('submitting', () {
    blocTest<AuthBloc, AuthState>(
      'a valid form signs in and carries the session',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(goodPassword))
        ..add(const AuthSubmitted()),
      expect: () => <AuthState>[
        const AuthState(email: email, emailTouched: true),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
        ),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
          status: AuthSessionStatus.signingIn,
        ),
        AuthState(status: AuthSessionStatus.signedIn, session: session),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'and it hands the repository the typed credentials verbatim',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged('  $email  '))
        ..add(const AuthPasswordChanged('  spaces matter  '))
        ..add(const AuthSubmitted()),
      verify: (_) {
        verify(
          () => repository.signIn(
            email: '  $email  ',
            password: '  spaces matter  ',
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'a refused attempt becomes a form error carrying the repository\'s message',
      setUp: () {
        when(
          () => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const Result<AuthSession>.failure(
            Failure(
              kind: FailureKind.validation,
              message: "That password's too short",
            ),
          ),
        );
      },
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(goodPassword))
        // The password satisfies the *form's* rule and the repository still
        // refuses. Both are reachable in this app — the repository judges the
        // same credentials through the same `validateLogin`, and a real adapter
        // would judge them through something else entirely.
        ..add(const AuthSubmitted()),
      expect: () => <AuthState>[
        const AuthState(email: email, emailTouched: true),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
        ),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
          status: AuthSessionStatus.signingIn,
        ),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
          formError: "That password's too short",
        ),
      ],
      verify: (AuthBloc bloc) {
        expect(bloc.state.isSignedIn, isFalse);
        expect(
          bloc.state.status,
          AuthSessionStatus.unknown,
          reason:
              'a refused attempt leaves the session status exactly as it was',
        );
      },
    );

    blocTest<AuthBloc, AuthState>(
      'a later keystroke leaves the last attempt\'s answer in place',
      // The form error is the repository's, not the field's; clearing one must
      // not clear the other, or the reader loses the reason they were refused
      // before they have retyped anything.
      setUp: () {
        when(
          () => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const Result<AuthSession>.failure(
            Failure(kind: FailureKind.validation, message: 'refused'),
          ),
        );
      },
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(goodPassword))
        ..add(const AuthSubmitted())
        ..add(const AuthPasswordChanged('$goodPassword!')),
      verify: (AuthBloc bloc) {
        expect(bloc.state.formError, 'refused');
        expect(bloc.state.passwordError, isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'an invalid form never reaches the repository',
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(shortPassword))
        ..add(const AuthSubmitted()),
      verify: (_) => verifyNever(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ),
    );

    blocTest<AuthBloc, AuthState>(
      'a submit reveals both fields at once, and keeps what was typed',
      // The reader asked to be told what is wrong; answering only the field they
      // were standing in would be less than they asked for.
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged('nope'))
        ..add(const AuthSubmitted()),
      expect: () => <AuthState>[
        const AuthState(
          email: 'nope',
          emailTouched: true,
          emailError: 'Enter a valid email address',
        ),
        const AuthState(
          email: 'nope',
          emailTouched: true,
          passwordTouched: true,
          emailError: 'Enter a valid email address',
          passwordError: kRequiredMessage,
        ),
      ],
      verify: (AuthBloc bloc) {
        expect(
          bloc.state.status,
          AuthSessionStatus.unknown,
          reason:
              'an attempt that never happened says nothing about whether there is '
              'a session',
        );
      },
    );

    blocTest<AuthBloc, AuthState>(
      'a second submit while the first is in flight is dropped',
      // The two-ways-to-fire-one-action hazard from AGENT_CONTEXT §9, decision
      // 12. Reachable only with a sign-in that does not complete — which the
      // fake repository does not, so this needs the held-open completer.
      build: () => build(pending: Completer<Result<AuthSession>>()),
      act: (AuthBloc bloc) => bloc
        ..add(const AuthEmailChanged(email))
        ..add(const AuthPasswordChanged(goodPassword))
        ..add(const AuthSubmitted())
        ..add(const AuthSubmitted()),
      expect: () => <AuthState>[
        const AuthState(email: email, emailTouched: true),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
        ),
        const AuthState(
          email: email,
          password: goodPassword,
          emailTouched: true,
          passwordTouched: true,
          status: AuthSessionStatus.signingIn,
        ),
      ],
      verify: (_) => verify(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).called(1),
    );
  });

  group('signing out', () {
    blocTest<AuthBloc, AuthState>(
      'clears the session and empties the form',
      setUp: () {
        when(repository.getCurrentSession)
            .thenAnswer((_) async => Result<AuthSession>.success(session));
      },
      build: build,
      act: (AuthBloc bloc) => bloc
        ..add(const AuthStarted())
        ..add(const AuthSignedOut()),
      expect: () => <AuthState>[
        AuthState(status: AuthSessionStatus.signedIn, session: session),
        const AuthState(status: AuthSessionStatus.signedOut),
      ],
      verify: (AuthBloc bloc) {
        expect(bloc.state.isSignedIn, isFalse);
        expect(bloc.state.email, isEmpty);
        expect(bloc.state.session, isNull);
        verify(repository.signOut).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'and it reaches the repository even when nothing was signed in',
      build: build,
      act: (AuthBloc bloc) => bloc.add(const AuthSignedOut()),
      verify: (_) => verify(repository.signOut).called(1),
    );
  });

  group('what the state will not do', () {
    test('never puts the password in its toString', () {
      // A bloc state is printed by `bloc_test` on every mismatch and by
      // `flutter_bloc`'s debug transition logging, so Equatable's default would
      // put the reader's secret in a build's console as a matter of course.
      final AuthState state = const AuthState(
        status: AuthSessionStatus.signingIn,
        email: email,
        password: 'hunter2-hunter2',
      );

      expect(state.toString(), isNot(contains('hunter2-hunter2')));
      expect(state.toString(), contains(email));
    });

    test('a typed value is not the same state as a cleared one', () {
      // Equatable over every field, not just the status: a bloc comparing only the
      // status would not rebuild the field when the reader typed.
      expect(const AuthState(email: 'a'), isNot(const AuthState()));
      expect(const AuthState(password: 'a'), isNot(const AuthState()));
      expect(
        const AuthState(isPasswordVisible: true),
        isNot(const AuthState()),
      );
    });
  });
}
