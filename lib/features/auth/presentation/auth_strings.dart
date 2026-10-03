import 'package:flutter/widgets.dart';

/// The bilingual string table for `/login`.
///
/// ## WHY THIS IS HAND-WRITTEN RATHER THAN GENERATED
///
/// `flutter_localizations` is wired in `app.dart` and `intl` is a dependency, but
/// Flutter's `gen_l10n` needs `flutter: generate: true` in `pubspec.yaml` — and
/// AGENT_CONTEXT §8.4 makes an unlisted change a hard stop, and the task pins
/// `pubspec.yaml` as unchanged. So the table is Dart.
///
/// That is a real cost and it is stated rather than hidden: adding a language means
/// adding a class here, and nothing checks that the two arms agree in length. What
/// *is* enforced is the property that matters to a reader — **no English left in
/// the Arabic arm, and no missing value** — by `login_strings_test.dart`, which
/// compares the two arms field by field through reflection over this class's
/// getters. The moment the project is allowed to touch `pubspec.yaml`, this file
/// becomes ARB input and that test becomes a codegen artefact.
///
/// ## WHY IT IS PER-FEATURE AND NOT IN `core/design_system`
///
/// Placement is by consumer (AGENT_CONTEXT §3): only `LoginPage` reads these, and
/// `core/` importing no feature means the reverse is also true. When `/settings`
/// needs its own strings it gets its own table, and a shared one appears in `core/`
/// when two features have proved they need the same string — the same rule the
/// shared kernel followed.
///
/// ## ARABIC, AND WHERE THE CHOICES CAME FROM
///
/// The prototype is **English only** — `eva/src` has one `LoginScreen.tsx` and no
/// Arabic variant — so every Arabic string here is written rather than
/// transcribed, and none of them is presented as the prototype's. They are the
/// product's own: the same three words the design already carries ("Read.
/// Reflect. Remember." is the tagline, and reading and remembering are the point of
/// a Sunday-school reading app).
final class LoginStrings {
  /// The strings for [locale].
  ///
  /// Falls back to [en] for anything that is not `ar`. The app declares exactly
  /// two supported locales (`app.dart`), so this arm is unreachable through
  /// `MaterialApp.locale` and exists for a widget pumped outside one — which
  /// several tests do.
  static LoginStrings of(Locale locale) => switch (locale.languageCode) {
    'ar' => const LoginStrings.ar(),
    _ => const LoginStrings.en(),
  };

  /// The English arm. Each value is the prototype's, verbatim.
  const LoginStrings.en()
    : wordmark = 'Evangelion',
      tagline = 'Read. Reflect. Remember.',
      emailLabel = 'Email',
      emailHint = 'you@example.com',
      passwordLabel = 'Password',
      passwordHint = '••••••••',
      signIn = 'Sign in',
      forgotPassword = 'Forgot password?',
      newHere = 'New here?',
      createAccount = 'Create account',
      divider = 'or',
      continueWithGoogle = 'Continue with Google',
      continueWithApple = 'Continue with Apple',
      showPassword = 'Show password',
      hidePassword = 'Hide password',
      sealLabel = 'Evangelion',
      unavailableSuffix = 'unavailable in this build';

  /// The Arabic arm.
  ///
  /// Two deliberate choices, both because the design system cannot render what the
  /// prototype would have written:
  ///
  /// * the wordmark stays `Evangelion` — it is the product's name in every
  ///   language, and transliterating a brand mark is a product decision;
  /// * the password hint stays `••••••••`, because Arabic digits and Latin digits
  ///   both differ per locale and a masked placeholder that changed shape would be
  ///   re-measuring the field on every locale switch.
  const LoginStrings.ar()
    : wordmark = 'Evangelion',
      tagline = 'اقرأ. تأمل. تذكّر.',
      emailLabel = 'البريد الإلكتروني',
      emailHint = 'you@example.com',
      passwordLabel = 'كلمة المرور',
      passwordHint = '••••••••',
      signIn = 'تسجيل الدخول',
      forgotPassword = 'نسيت كلمة المرور؟',
      newHere = 'جديد هنا؟',
      createAccount = 'أنشئ حسابًا',
      divider = 'أو',
      continueWithGoogle = 'المتابعة عبر Google',
      continueWithApple = 'المتابعة عبر Apple',
      showPassword = 'إظهار كلمة المرور',
      hidePassword = 'إخفاء كلمة المرور',
      sealLabel = 'إنجيل',
      unavailableSuffix = 'غير متاح في هذه النسخة';

  /// The product's name, above the tagline. `LoginScreen.tsx:29`.
  final String wordmark;

  /// `LoginScreen.tsx:32`.
  final String tagline;

  /// The email field's label, which is also its semantics name.
  /// `LoginScreen.tsx:49`.
  final String emailLabel;

  /// The email field's placeholder. `LoginScreen.tsx:49`.
  final String emailHint;

  /// The password field's label. `LoginScreen.tsx:51`.
  final String passwordLabel;

  /// The password field's placeholder. `LoginScreen.tsx:51`.
  final String passwordHint;

  /// The primary button. `LoginScreen.tsx:64`.
  final String signIn;

  /// The "Forgot password?" control. `LoginScreen.tsx:66`.
  final String forgotPassword;

  /// The half of the sign-up row that is not a control. `LoginScreen.tsx:69`.
  final String newHere;

  /// The "Create account" control. `LoginScreen.tsx:71`.
  final String createAccount;

  /// The label in the divider. `LoginScreen.tsx:78`.
  final String divider;

  /// The Google button. `LoginScreen.tsx:84`.
  final String continueWithGoogle;

  /// The Apple button. `LoginScreen.tsx:85`.
  final String continueWithApple;

  /// The password toggle's name while the password is masked.
  final String showPassword;

  /// The password toggle's name while the password is visible.
  final String hidePassword;

  /// The seal's accessible name. `SealMonogram.semanticLabel`.
  final String sealLabel;

  /// Appended to a permanently-disabled control's name, so a screen reader
  /// announces *why* it cannot be pressed instead of only that it cannot.
  ///
  /// See `LoginPage`'s doc for why four controls on this screen ship disabled.
  final String unavailableSuffix;
}
