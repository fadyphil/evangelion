import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

/// The login form's rules — red-first (AGENT_CONTEXT §6).
///
/// ## WHERE THE RULES COME FROM, HONESTLY
///
/// **Both rules are the redesign's, stated in its own JavaScript.** The React
/// prototype stated a password error and no rule behind it —
/// `LoginScreen.tsx:52` is a literal with no minimum anywhere in `eva/src` —
/// which is why the first version of `login_credentials.dart` chose eight. The
/// redesign **states the rule**: `eva/redesign.html:1306` is
/// `pw.length>=4?'':tr('pwErr')`, so [kMinPasswordLength] is transcribed (4) and
/// the message it produces is `:976`'s `pwErr` verbatim. The address rule is
/// `:1305`'s `^\S+@\S+\.\S+$` — the same local-part-and-dotted-domain shape the
/// first version derived from `type="email"` — and its one message is `:976`'s
/// `emErr`.
///
/// One message per field is the redesign's own framing: `:1305-1306` collapse
/// blank and malformed into a single sentence each, and the old
/// `kRequiredMessage` is gone with the prototype that framed it. The page
/// renders the localized sentence **by presence** (`state.emailError != null`),
/// never by matching this file's wording — see `authEmailInvalid`'s arb
/// description.
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
        kInvalidEmailMessage,
        reason:
            'the redesign has one message per field — an empty address '
            'fails `:1305`\'s regex just as a malformed one does',
      );
      expect(
        validateLogin(email: '   ', password: 'correct horse').emailError,
        kInvalidEmailMessage,
      );
      expect(
        validateLogin(email: '@evangelion.app', password: 'x' * 12).emailError,
        kInvalidEmailMessage,
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
      // something that was actually typed. The redesign's single message per
      // field (see the file doc) makes the wording a UI concern; the *presence*
      // of an error is what the bloc gates on.
      expect(validateLogin(email: '', password: '').isValid, isFalse);
      expect(validateLogin(email: '', password: '').emailError, isNotNull);
    });
  });

  group('validateLogin — the password rule', () {
    test('uses the redesign\'s own message for a short password', () {
      // `redesign.html:976` — `pwErr`, verbatim. A golden would ratify any
      // rewording and the prototype is the only source for the wording, so this
      // is a transcription claim and the file says so. Five characters is
      // **above** `kMinPasswordLength` (the redesign's rule is 4), so the fixture
      // is three.
      expect(
        validateLogin(
          email: 'david@evangelion.app',
          password: 'abc',
        ).passwordError,
        'password too short',
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
        'password too short',
      );
    });

    test('answers an empty password with the same sentence as a short one', () {
      // `redesign.html:1306` — `pw.length>=4` has no empty-case branch: an empty
      // password is a password shorter than four characters, which is how the
      // prototype treats it and how this file treats it. The old two-message
      // model ("required" vs "too short") is the old prototype's framing and is
      // gone; the page renders by presence, so the one sentence is all it needs.
      final LoginValidation blank = validateLogin(
        email: 'david@evangelion.app',
        password: '',
      );

      expect(blank.passwordError, kShortPasswordMessage);
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
