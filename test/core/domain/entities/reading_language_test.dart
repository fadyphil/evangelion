import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ReadingLanguage] — red-first (AGENT_CONTEXT §6: domain entities).
///
/// ## WHAT IS ACTUALLY BEING PINNED
///
/// Two directions that are not symmetric, and the asymmetry is the design:
///
/// * [ReadingLanguage.fromCode] is the **wire** direction — the `language` field
///   of a response and the `{lang}` path segment. It returns `null` for anything
///   it does not know, because a mapper that guessed `en` for an unrecognised
///   payload would render one language's scripture as another's with nothing
///   wrong anywhere.
/// * [ReadingLanguage.forLocale] is the **locale** direction — what a screen asks
///   when it reads `Localizations.localeOf(context).languageCode`. It defaults to
///   English, following `LoginStrings.of`, because the app declares exactly two
///   `supportedLocales` and an unlisted one is a configuration mistake rather
///   than a payload claim.
void main() {
  group('the wire code', () {
    test('is the exact path segment and response value', () {
      // `GET /readings/today/{en,ar}` and the response's own `"language"` field.
      // Asserted against literals rather than against a copy, because the
      // literal is the contract — `AGENT_CONTEXT` §5 lists both endpoint paths.
      expect(ReadingLanguage.english.code, 'en');
      expect(ReadingLanguage.arabic.code, 'ar');
    });

    test('round-trips through fromCode', () {
      for (final ReadingLanguage language in ReadingLanguage.values) {
        expect(ReadingLanguage.fromCode(language.code), same(language));
      }
    });
  });

  group('fromCode — the wire direction', () {
    test('reads the two values the backend emits', () {
      expect(ReadingLanguage.fromCode('en'), ReadingLanguage.english);
      expect(ReadingLanguage.fromCode('ar'), ReadingLanguage.arabic);
    });

    test('returns null rather than guessing for anything else', () {
      // The whole reason this returns nullable. A mapper that defaulted an
      // unrecognised `language` to `english` would produce an entity that claims
      // to be English scripture and is not — and the failure would surface as a
      // reader looking at the wrong language, which is the worst bug a bilingual
      // app has.
      expect(ReadingLanguage.fromCode('fr'), isNull);
      expect(ReadingLanguage.fromCode(''), isNull);
      expect(ReadingLanguage.fromCode('EN'), isNull, reason: 'case-sensitive');
      expect(ReadingLanguage.fromCode('AR'), isNull, reason: 'case-sensitive');
      expect(ReadingLanguage.fromCode('en-US'), isNull);
    });
  });

  group('forLocale — the locale direction', () {
    test('agrees with fromCode for the two shipped locales', () {
      expect(ReadingLanguage.forLocale('en'), ReadingLanguage.english);
      expect(ReadingLanguage.forLocale('ar'), ReadingLanguage.arabic);
    });

    test('falls back to English, as LoginStrings.of does', () {
      // `LoginStrings.of` falls back to `en` for anything that is not `ar`, and
      // its doc says the arm exists for "a widget pumped outside a
      // MaterialApp" — which several suites do. The same reasoning, the same
      // answer, so the two tables cannot disagree about what an unlisted locale
      // means.
      expect(ReadingLanguage.forLocale('fr'), ReadingLanguage.english);
      expect(ReadingLanguage.forLocale(''), ReadingLanguage.english);
    });
  });

  group('the enum itself', () {
    test('has exactly two members, and no third can be added silently', () {
      // `values` is the closed set a `switch` over this enum is exhaustive
      // against. A third member — a third translation, say — is a compile error
      // in every exhaustive `switch` in the tree, which is the point of the
      // enum rather than a `String`.
      expect(ReadingLanguage.values, <ReadingLanguage>[
        ReadingLanguage.english,
        ReadingLanguage.arabic,
      ]);
    });
  });
}
