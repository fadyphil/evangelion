import 'package:equatable/equatable.dart';

/// What the login form knows about one pair of credentials.
///
/// ## WHY THE EMAIL IS TRIMMED AND THE PASSWORD IS NOT
///
/// The asymmetry is deliberate and lives at the field rather than at each call
/// site, because a caller that had to remember it would eventually get one half
/// wrong. An address is compared after trimming — a paste from another app
/// arrives with a leading space often enough that failing the whole form over it
/// reads as a bug — and a password is **not** trimmed, because leading and
/// trailing spaces can be part of a secret and silently changing one is worse
/// than rejecting it.
///
/// [password] is held verbatim and is never logged, compared or normalised. The
/// only thing derived from it anywhere in this app is its length.
final class LoginCredentials extends Equatable {
  /// Wraps an already-normalised email and password.
  const LoginCredentials({required this.email, required this.password});

  /// Builds from raw input, trimming [email] and leaving [password] alone.
  factory LoginCredentials.from({
    required String email,
    required String password,
  }) => LoginCredentials(email: email.trim(), password: password);

  /// The address, trimmed.
  final String email;

  /// The secret, verbatim. See the class doc.
  final String password;

  /// These credentials' verdict.
  ///
  /// Delegates rather than caching, because a caller holds the credentials and
  /// not a validation that could go stale against an edited field.
  LoginValidation validation() =>
      validateLogin(email: email, password: password);

  @override
  List<Object?> get props => <Object?>[email, password];

  /// Deliberately **not** Equatable's default, which prints every prop and would
  /// put a password into every failing bloc assertion and every log line. The
  /// pair is compared by value through [props] and printed as a shape.
  @override
  String toString() => 'LoginCredentials(email: $email, password: ********)';
}

/// The shortest password this form accepts.
///
/// **Chosen, not transcribed.** `eva/src` states no minimum anywhere;
/// `LoginScreen.tsx:52` shows an error string ("That password's too short") with
/// no rule behind it, and there is no server to ask — there is no auth endpoint
/// (AGENT_CONTEXT §2, decision 3). Eight is the conventional figure and no
/// document in this repository argues for another, so it is written down here,
/// once, where a reader looking for the rule will find it.
///
/// The message it produces, [kShortPasswordMessage], **is** the prototype's and
/// is verbatim.
const int kMinPasswordLength = 8;

/// The prototype's own short-password message. `LoginScreen.tsx:52`.
const String kShortPasswordMessage = "That password's too short";

/// "Required" — used when a field is empty, which is a different complaint from
/// [kShortPasswordMessage] and says so: a criticism of a blank box the reader
/// has not typed in yet is not criticism of what they typed.
const String kRequiredMessage = 'This field is required';

/// The verdict on one pair of credentials: at most one message per field.
///
/// A `Map<String, String>` keyed by field name would carry the same information
/// and cost a lookup at each call site plus a cast at each render; two nullable
/// fields carry it in a shape the compiler checks. There are exactly two fields,
/// which is the whole reason this is not a list.
final class LoginValidation extends Equatable {
  /// A verdict. Both `null` means valid.
  const LoginValidation({this.emailError, this.passwordError});

  /// What is wrong with the address, or `null`.
  final String? emailError;

  /// What is wrong with the password, or `null`.
  final String? passwordError;

  /// Whether nothing is wrong.
  bool get isValid => emailError == null && passwordError == null;

  /// The first message in field order, or `null` when nothing is wrong.
  ///
  /// Field order rather than "whichever the reader typed last": the email is
  /// above the password on screen (and in `LoginScreen.tsx:49-63`), so a summary
  /// that read password-first would name the wrong line.
  String? get firstError => emailError ?? passwordError;

  @override
  List<Object?> get props => <Object?>[emailError, passwordError];
}

/// Judges [email] and [password].
///
/// Two rules, from two places, and neither is invented:
///
/// * **the address** must have a local part and a dotted domain, because the
///   prototype types the field `type="email"` (`LoginScreen.tsx:49`);
/// * **the password** must be at least [kMinPasswordLength] characters, which is
///   the one rule this file chose rather than read — see that constant.
LoginValidation validateLogin({
  required String email,
  required String password,
}) => LoginValidation(
  emailError: _emailError(email.trim()),
  passwordError: _passwordError(password),
);

/// The address rule.
///
/// `[local]@domain`, both non-empty, and the domain carrying a dot that is not
/// its first or last character — which is what rejects `david@.app` and
/// `david@evangelion.` while accepting `a@b.co`.
String? _emailError(String email) {
  if (email.isEmpty) {
    return kRequiredMessage;
  }
  final int at = email.lastIndexOf('@');
  if (at <= 0 || at == email.length - 1) {
    return 'Enter a valid email address';
  }
  final String domain = email.substring(at + 1);
  final int dot = domain.indexOf('.');
  if (dot <= 0 || dot == domain.length - 1) {
    return 'Enter a valid email address';
  }
  return null;
}

/// The password rule.
///
/// Length only. No character-class rule is invented: the prototype states none,
/// and a rule the reader cannot discover is worse than no rule at all.
String? _passwordError(String password) {
  if (password.isEmpty) {
    return kRequiredMessage;
  }
  if (password.length < kMinPasswordLength) {
    return kShortPasswordMessage;
  }
  return null;
}
