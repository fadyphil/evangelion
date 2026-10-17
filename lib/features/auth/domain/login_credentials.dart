import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_credentials.freezed.dart';

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
///
/// ## `==`, `hashCode` AND `toString` ARE **PARTLY** GENERATED, AND ONE IS NOT
///
/// freezed derives `==` and `hashCode` from the constructor, so [password] is in
/// the equality contract — exactly as `Equatable.props` had it, and for the same
/// reason: two pairs of credentials with different secrets are different
/// credentials. `toString` is **declared here**, and freezed does not generate one
/// for a class that has its own: the generated one would interpolate [password]
/// into every log line and every failed `expect`. The generated part of this class
/// is the equality and nothing else, which is the whole of what
/// `test/core/common/secret_masking_test.dart` exists to keep true.
@freezed
final class LoginCredentials with _$LoginCredentials {
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

  /// Deliberately **not** the generated one, which prints every property and would
  /// put a password into every failing bloc assertion and every log line. The pair
  /// is compared by value through the generated `==` and printed as a shape.
  @override
  String toString() => 'LoginCredentials(email: $email, password: ********)';
}

/// The shortest password this form accepts.
///
/// **Transcribed — superseding the "chosen, not transcribed" note below.** The
/// React prototype stated no minimum anywhere, so the first version of this file
/// chose eight as the conventional figure. The redesign **states the rule**:
/// `eva/redesign.html:1306` — `pw.length>=4?'':tr('pwErr')`. A rule the reader
/// can now discover is transcribed, not chosen, and four it is.
///
/// The message it produces, [kShortPasswordMessage], is the redesign's own
/// wording — see that constant.
const int kMinPasswordLength = 4;

/// The redesign's short-password message. `redesign.html:976` — `pwErr:
/// ["password too short","كلمة المرور قصيرة"]`.
const String kShortPasswordMessage = 'password too short';

/// The redesign's malformed-address message. `redesign.html:976` — `emErr:
/// ["email looks incomplete","البريد غير مكتمل"]`.
///
/// The redesign has **one message per field**, not the old prototype's two
/// (`kRequiredMessage` plus a validity complaint): an empty address and a
/// malformed one are the same failure to `redesign.html:1305`'s single regex
/// test. The old `kRequiredMessage` — a criticism of a blank box worded
/// differently from a criticism of what was typed — is gone with the prototype
/// that framed it, and the page renders the localized sentence by **presence**
/// (`state.emailError != null`), never by matching this text.
const String kInvalidEmailMessage = 'email looks incomplete';

/// The verdict on one pair of credentials: at most one message per field.
///
/// A `Map<String, String>` keyed by field name would carry the same information
/// and cost a lookup at each call site plus a cast at each render; two nullable
/// fields carry it in a shape the compiler checks. There are exactly two fields,
/// which is the whole reason this is not a list.
///
/// ## IT HOLDS **NO SECRET**, AND THAT IS THE POINT OF THE SCAN IN
/// ## `secret_masking_test.dart`
///
/// [passwordError] is a *message about* a password — `"That password's too
/// short"` — never the password, and it is what makes this type exempt from the
/// masking rule: the structural half of that gate scans `lib/` for a field
/// declared `final String password` and finds nothing here, so this class is
/// correctly absent from its offender list. The first version of that scan
/// matched per *file* rather than per class and reported `LoginValidation` as a
/// leak, which the file's own doc records as the failure mode of every regex
/// gate here: right answer, unreachable reason.
@freezed
final class LoginValidation with _$LoginValidation {
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
}

/// Judges [email] and [password].
///
/// Two rules, and the redesign states one of them outright:
///
/// * **the address** must have a local part and a dotted domain, because
///   `redesign.html:1305` tests `^\S+@\S+\.\S+$` — the same shape the first
///   version derived from `LoginScreen.tsx:49`'s `type="email"`, now with the
///   prototype's own regex as the citation;
/// * **the password** must be at least [kMinPasswordLength] characters, which is
///   `redesign.html:1306` verbatim — see that constant for how the rule arrived.
///
/// One message per field, in both cases the redesign's own word: the two
/// complaints the first version carried (blank vs malformed, blank vs short) are
/// the old prototype's framing, and `redesign.html:1305-1306` collapses each
/// field to a single sentence — see [kInvalidEmailMessage].
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
/// `david@evangelion.` while accepting `a@b.co`. `redesign.html:1305`'s
/// `^\S+@\S+\.\S+$` rejects exactly these and accepts exactly `a@b.co` too; the
/// hand-rolled walk is kept over `RegExp` because Dart's `RegExp` would be the
/// first regex in the domain layer for a rule two `if`s already state, and a
/// scan gate would then have to decide whether domain regexes are a pattern it
/// should watch. Empty and malformed share one message — see
/// [kInvalidEmailMessage].
String? _emailError(String email) {
  if (email.isEmpty) {
    return kInvalidEmailMessage;
  }
  final int at = email.lastIndexOf('@');
  if (at <= 0 || at == email.length - 1) {
    return kInvalidEmailMessage;
  }
  final String domain = email.substring(at + 1);
  final int dot = domain.indexOf('.');
  if (dot <= 0 || dot == domain.length - 1) {
    return kInvalidEmailMessage;
  }
  return null;
}

/// The password rule.
///
/// Length only. No character-class rule is invented: the redesign states none,
/// and a rule the reader cannot discover is worse than no rule at all. Empty and
/// short share one message — an empty password is a password shorter than
/// [kMinPasswordLength], which is how `redesign.html:1306` treats it.
String? _passwordError(String password) {
  if (password.length < kMinPasswordLength) {
    return kShortPasswordMessage;
  }
  return null;
}
