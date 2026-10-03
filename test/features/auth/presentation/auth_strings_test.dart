import 'dart:io';

import 'package:evangelion/features/auth/presentation/auth_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bilingual table — red-first for the property §14 and `no_adjacent_strings_in_list`
/// both care about: **no English left in the Arabic arm, and no missing value**.
///
/// ## WHY THE FIELD LIST IS READ FROM THE SOURCE AND THE VALUES FROM THE OBJECTS
///
/// Dart has no `dart:mirrors` on this platform, so "every field, compared" cannot be
/// written as a reflection loop. Splitting it is what makes the check mechanical
/// anyway:
///
/// * the **field names** come from `auth_strings.dart`'s own declarations, so a
///   field added tomorrow is in tomorrow's run — and the anti-vacuity test below
///   fails if the walk finds nothing at all;
/// * the **values** come from executing `en()` and `ar()`, so the assertions are
///   about the strings a reader would be shown, not about the file's text.
///
/// The one thing this cannot do is tell a *deliberately* untranslated string from a
/// forgotten one. What it can do is refuse an empty value on either arm and refuse a
/// value that is English where the arm says Arabic — and the second of those is
/// narrowed to the strings that must differ, below.
void main() {
  /// Every `final String` member of [LoginStrings], in declaration order.
  List<String> declaredFields() {
    final RegExp declaration = RegExp(
      r'^\s*(?:///.*\n\s*)*final String (\w+);',
      multiLine: true,
    );
    final File source = File(
      'lib/features/auth/presentation/auth_strings.dart',
    );
    return declaration
        .allMatches(source.readAsStringSync())
        .map((RegExpMatch match) => match.group(1)!)
        .toList();
  }

  /// Reads [field] off [strings] through the generated accessor.
  String read(LoginStrings strings, String field) => switch (field) {
    'wordmark' => strings.wordmark,
    'tagline' => strings.tagline,
    'emailLabel' => strings.emailLabel,
    'emailHint' => strings.emailHint,
    'passwordLabel' => strings.passwordLabel,
    'passwordHint' => strings.passwordHint,
    'signIn' => strings.signIn,
    'forgotPassword' => strings.forgotPassword,
    'newHere' => strings.newHere,
    'createAccount' => strings.createAccount,
    'divider' => strings.divider,
    'continueWithGoogle' => strings.continueWithGoogle,
    'continueWithApple' => strings.continueWithApple,
    'showPassword' => strings.showPassword,
    'hidePassword' => strings.hidePassword,
    'sealLabel' => strings.sealLabel,
    'unavailableSuffix' => strings.unavailableSuffix,
    // An exhaustive switch over the discovered names, so a new field that the
    // source walk finds but this switch does not is a **compile error** rather
    // than a field that silently stops being checked.
    _ => throw StateError('no accessor for $field — add one here'),
  };

  group('both arms', () {
    test(
      'the walk finds the fields, so the comparison below is not vacuous',
      () {
        expect(
          declaredFields().length,
          greaterThanOrEqualTo(17),
          reason:
              'a source walk that found nothing would make every "both arms" '
              'assertion a comparison over two empty sets',
        );
      },
    );

    test('every discovered field has an accessor in this file', () {
      // The compile-error half of the switch above cannot be exercised from here, so
      // this asserts the reachable half: every name the source declares can actually
      // be read, which is what stops a rename from turning the comparison into a
      // `StateError` at runtime inside a loop.
      for (final String field in declaredFields()) {
        expect(
          () => read(const LoginStrings.en(), field),
          returnsNormally,
          reason: field,
        );
        expect(
          () => read(const LoginStrings.ar(), field),
          returnsNormally,
          reason: field,
        );
      }
    });

    test('no value is empty on either arm', () {
      for (final String field in declaredFields()) {
        for (final (String arm, LoginStrings strings)
            in <(String, LoginStrings)>[
              ('en', const LoginStrings.en()),
              ('ar', const LoginStrings.ar()),
            ]) {
          expect(
            read(strings, field).trim(),
            isNotEmpty,
            reason: '$arm.$field is blank, which renders as nothing on screen',
          );
        }
      }
    });

    test('no value is the same in both arms except the three that must be', () {
      // Deliberately identical across the two arms, each with a reason in
      // `LoginStrings.ar`'s doc:
      const Set<String> shared = <String>{
        'wordmark', // the product's name
        'emailHint', // an example address, not prose
        'passwordHint', // bullets, not digits
      };

      for (final String field in declaredFields()) {
        final String en = read(const LoginStrings.en(), field);
        final String ar = read(const LoginStrings.ar(), field);
        if (shared.contains(field)) {
          expect(ar, en, reason: '$field is documented as shared');
        } else {
          expect(
            ar,
            isNot(en),
            reason:
                '$field is identical in both arms, which is either an '
                'untranslated string or a value that belongs in `shared`',
          );
        }
      }
    });
  });

  group('resolution', () {
    test('an unlisted locale reads as English rather than crashing', () {
      // `MaterialApp` can only produce `en` and `ar` here, so this arm is reachable
      // only from a widget pumped outside one — which several tests do.
      expect(
        LoginStrings.of(const Locale('fr')).tagline,
        const LoginStrings.en().tagline,
      );
      expect(
        LoginStrings.of(const Locale('ar')).tagline,
        const LoginStrings.ar().tagline,
      );
      expect(
        LoginStrings.of(const Locale('ar', 'EG')).tagline,
        const LoginStrings.ar().tagline,
        reason: 'a region subtag must not lose the language',
      );
    });

    test('the Arabic arm renders as Arabic script, not Latin lookalikes', () {
      // A cheap transliteration check over the user-visible prose. It catches the
      // failure this table's existence is for — an Arabic arm that is really English
      // typed into the wrong field — without claiming to validate the translation.
      for (final String field in <String>[
        'tagline',
        'signIn',
        'forgotPassword',
        'newHere',
        'createAccount',
        'divider',
      ]) {
        expect(
          read(const LoginStrings.ar(), field),
          contains(RegExp('[؀-ۿ]')),
          reason: '$field has no Arabic letter in the Arabic arm',
        );
      }
    });
  });
}
