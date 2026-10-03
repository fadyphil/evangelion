import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

/// The login form's rules — red-first (AGENT_CONTEXT §6).
///
/// ## WHERE THE RULES COME FROM, HONESTLY
///
/// The prototype has a password error and no password rule.
/// `LoginScreen.tsx:52` writes `error="That password's too short"` on the
/// password field — a literal, like the rest of defect #10 — and nothing anywhere
/// in `eva/src` states a minimum. There is also no server to state one: there is
/// no auth endpoint at all (AGENT_CONTEXT §2, decision 3), so
/// `FakeAuthRepository` cannot defer to anybody.
///
/// So **[kMinPasswordLength] is chosen here, not transcribed**, and this is the
/// single place it is written down. Eight is the conventional figure and no
/// document in this repository argues for another. The *message* it produces,
/// "That password's too short", **is** the prototype's and is used verbatim.
///
/// Everything else follows from the two facts the prototype does state: the
/// fields are `type="email"` and `type="password"` (`LoginScreen.tsx:49-51`),
/// which is where "must look like an address" and "must not be empty" come from.
void main() {
  group('validateLogin — the email rule', () {
    test('accepts an ordinary address', () {
      for (final String email in <String>[
        'david@evangelion.app',
        'a@b.co',
        'first.last+tag@sub.domain.org',
      ]) {
        expect(
          validateLogin(email: email, password: 'correct horse').emailError,
          isNull,
          reason: 'rejected "$email"',
        );
      }
    });

    test('requires something before the @', () {
      expect(
        validateLogin(email: '', password: 'correct horse').emailError,
        isNotNull,
      );
      expect(
        validateLogin(email: '   ', password: 'correct horse').emailError,
        isNotNull,
      );
      expect(
        validateLogin(email: '@evangelion.app', password: 'x' * 12).emailError,
        isNotNull,
      );
    });

    test('requires a domain with a dot in it', () {
      // The prototype's `type="email"` is what makes this a rule rather than a
      // suggestion, and the dot is what separates `user@localhost` — which every
      // mail library accepts and which no reader can type by accident here — from
      // an address.
      expect(
        validateLogin(
          email: 'david@localhost',
          password: 'correct horse',
        ).emailError,
        isNotNull,
      );
      expect(
        validateLogin(
          email: 'david@evangelion',
          password: 'correct horse',
        ).emailError,
        isNotNull,
      );
    });

    test('rejects anything after the @ that has no host', () {
      expect(
        validateLogin(
          email: 'david@.app',
          password: 'correct horse',
        ).emailError,
        isNotNull,
      );
      expect(
        validateLogin(
          email: 'david@evangelion.',
          password: 'correct horse',
        ).emailError,
        isNotNull,
      );
    });

    test('trims before judging, so a stray space is not an invalid address', () {
      // A paste from another app arrives with a leading space often enough that
      // failing the whole form over it reads as a bug.
      expect(
        validateLogin(
          email: '  david@evangelion.app  ',
          password: 'correct horse',
        ).emailError,
        isNull,
      );
    });

    test('never reports an error for a field the reader has not reached', () {
      // Not a rule of the validator — it validates whatever it is given — but the
      // property `AuthBloc` relies on: an error is only ever attached to
      // something that was actually typed. A blank field's "error" is
      // "required", which is a complaint about a form the reader has not filled
      // in yet.
      expect(validateLogin(email: '', password: '').isValid, isFalse);
      expect(validateLogin(email: '', password: '').emailError, isNotNull);
    });
  });

  group('validateLogin — the password rule', () {
    test('uses the prototype\'s own message for a short password', () {
      // `LoginScreen.tsx:52`, verbatim. A golden would ratify any rewording and
      // the prototype is the only source for the wording, so this is a
      // transcription claim and the file says so.
      expect(
        validateLogin(
          email: 'david@evangelion.app',
          password: 'short',
        ).passwordError,
        "That password's too short",
      );
    });

    test('accepts a password at exactly the minimum', () {
      // Off-by-one: a `<` instead of `<=` would reject the boundary, and the
      // boundary is the only value a reader can tell whether the rule means
      // what it says.
      expect(
        validateLogin(
          email: 'david@evangelion.app',
          password: 'x' * kMinPasswordLength,
        ).passwordError,
        isNull,
      );
      expect(
        validateLogin(
          email: 'david@evangelion.app',
          password: 'x' * (kMinPasswordLength - 1),
        ).passwordError,
        isNotNull,
      );
    });

    test('reports required rather than too short for an empty password', () {
      // Two different complaints, and conflating them is a lie in one direction
      // and uselessness in the other: "too short" on a field nobody has typed in
      // yet is a criticism of a blank box.
      final LoginValidation blank = validateLogin(
        email: 'david@evangelion.app',
        password: '',
      );

      expect(blank.passwordError, isNot(kShortPasswordMessage));
      expect(blank.passwordError, isNotEmpty);
    });

    test('does not trim, because a leading space can be part of a password', () {
      // The mirror of the email rule, and the reason the two rules are not one
      // function. Trimming a password silently changes the secret.
      expect(
        validateLogin(
          email: 'david@evangelion.app',
          password: '   x    ',
        ).passwordError,
        isNull,
        reason: 'a 7-character password with meaningful spaces is 11 long',
      );
    });
  });

  group('LoginValidation', () {
    test('isValid is exactly "no error on either field"', () {
      expect(
        validateLogin(
          email: 'david@evangelion.app',
          password: 'correct horse',
        ).isValid,
        isTrue,
      );
      expect(
        validateLogin(email: '', password: 'correct horse').isValid,
        isFalse,
      );
      expect(validateLogin(email: 'a@b.co', password: '').isValid, isFalse);
      expect(validateLogin(email: '', password: '').isValid, isFalse);
    });

    test(
      'firstError is the email one when both are wrong, so the summary reads '
      'top-down',
      () {
        final LoginValidation both = validateLogin(email: '', password: '');

        expect(both.firstError, both.emailError);
        expect(both.emailError, isNotNull);
        expect(both.passwordError, isNotNull);
      },
    );

    test('and null when nothing is wrong, so a summary widget has nothing to '
        'render', () {
      expect(
        validateLogin(email: 'a@b.co', password: 'correct horse').firstError,
        isNull,
      );
    });

    test('two validations of the same input are equal', () {
      expect(
        validateLogin(email: 'a@b.co', password: 'correct horse'),
        validateLogin(email: 'a@b.co', password: 'correct horse'),
      );
      expect(
        validateLogin(email: 'a@b.co', password: 'short'),
        validateLogin(email: 'a@b.co', password: 'short'),
      );
    });
  });

  group('LoginCredentials', () {
    test('carries the email trimmed and the password exactly as typed', () {
      // The asymmetry is the point and it is stated at the field rather than
      // discovered by a caller: an address is compared after trimming, a secret
      // is not compared after anything.
      final LoginCredentials credentials = LoginCredentials.from(
        email: '  david@evangelion.app ',
        password: ' spaces matter ',
      );

      expect(credentials.email, 'david@evangelion.app');
      expect(credentials.password, ' spaces matter ');
    });

    test('and validates itself', () {
      expect(
        LoginCredentials.from(
          email: 'nope',
          password: 'correct horse',
        ).validation().emailError,
        isNotNull,
      );
      expect(
        LoginCredentials.from(
          email: 'david@evangelion.app',
          password: 'correct horse',
        ).validation().isValid,
        isTrue,
      );
    });
  });
}
