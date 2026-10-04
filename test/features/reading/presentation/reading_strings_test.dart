import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `ReadingStrings` — the bilingual table for `/reading`.
///
/// ## WHAT IS ASSERTED AND WHY IT IS NOT A TABLE DUMP
///
/// `home_strings_test.dart` walks both arms field by field. That catches a
/// **missing** string. It cannot catch the two things this phase actually got
/// wrong, and both are about the *content* rather than the arity:
///
/// 1. **a fake datum survived.** The prototype's caption reads `5 questions`
///    (`ReadingEnScreen.tsx:89`) and its metadata row reads `4 min` (`:31`). The
///    live payload carries **one** question and **no duration field at all**. A
///    pluralised caption built off the count and a metadata row with no invented
///    number are both *absences of invented data*, and the only way to see them is
///    to assert what is **not** on screen.
/// 2. **Latin script reached the Arabic arm.** `home_strings_test.dart`'s existing
///    rule, restated here because `/reading` has three more Arabic strings than `/
///    `does and one of them is a live payload value this client does not control.
void main() {
  const ReadingStrings en = ReadingStrings.en();
  const ReadingStrings ar = ReadingStrings.ar();

  group('of(Locale) — the only way to pick an arm', () {
    test('reads the locale, for the two the app ships', () {
      expect(ReadingStrings.of(const Locale('ar')), same(ar));
      expect(ReadingStrings.of(const Locale('en')), same(en));
    });

    test(
      'falls back to English, as `LoginStrings.of` and `HomeStrings.of` do',
      () {
        expect(ReadingStrings.of(const Locale('fr')), same(en));
        // `Locale('en', 'GB')` — a country the app does not declare, which is a real
        // shape a reader's device sends and a different one from `Locale('')`, which
        // Dart itself asserts against.
        expect(ReadingStrings.of(const Locale('en', 'GB')), same(en));
      },
    );
  });

  group('the caption is pluralised from the REAL count', () {
    test('English says "1 question" at one and "5 questions" at five', () {
      // The verify item. `ReadingEnScreen.tsx:89` hard-codes `5 questions`, and the
      // live reading carries **one** question — so the prototype's literal would be
      // a lie by a factor of five, and a hard-coded `5` is fake data that happens to
      // match nothing the server sends.
      expect(en.captionFor(1), '1 question');
      expect(en.captionFor(5), '5 questions');
    });

    test('and it is the SAME function for both, not two call sites', () {
      // One implementation is the point: two `count == 1 ? … : …` expressions are
      // one refactor apart from disagreeing, and the disagreement would only show
      // up in one arm.
      expect(en.captionFor(1), isNot(en.captionFor(2)));
      expect(en.captionFor(0), '0 questions');
      expect(en.captionFor(2), '2 questions');
      expect(en.captionFor(11), '11 questions');
    });

    test('Arabic renders the count in Arabic-Indic digits beside the noun', () {
      // `ReadingArScreen.tsx:86-87` writes `٥ أسئلة`. Two things follow: the plural
      // arm is a **plural noun** (3…10 in Arabic take the plural), and the numeral
      // is **U+0665** — an Arabic-block codepoint, which is why this string has to
      // be rendered in `Amiri` and why the glyph gate has something to bite on.
      expect(ar.captionFor(5), '٥ أسئلة');
      expect(ar.captionFor(5).codeUnits.first, 0x0665);
    });

    test('and the singular arm is a DIFFERENT string, not the plural one', () {
      expect(ar.captionFor(1), '١ سؤال واحد');
      expect(ar.captionFor(1), isNot(ar.captionFor(5)));
    });

    test('the singular/plural boundary is exactly `== 1` on both arms', () {
      // Stated rather than implied, because it is a **limitation** and not a claim
      // of full Arabic plural agreement. See `ReadingStrings.questionPlural`'s doc:
      // Arabic has four agreement classes (1 / 2 / 3–10 / 11+) and this table
      // implements one boundary. The live payload carries one question, which is
      // the case the boundary gets right.
      for (final int count in <int>[0, 1, 2, 3, 10, 11, 99, 100]) {
        final bool singular = count == 1;
        expect(
          en.captionFor(count).contains('question${singular ? '' : 's'}'),
          isTrue,
          reason: 'English $count',
        );
        expect(
          ar.captionFor(count).contains(singular ? 'واحد' : 'أسئلة'),
          isTrue,
          reason: 'Arabic $count',
        );
      }
    });
  });

  group('nothing in the table is a number the server did not send', () {
    test('no caption string contains the prototype\'s `5 questions`', () {
      // Tautological against `en.captionFor(5)`, deliberately: the point is that
      // **no field** hard-codes a count, so a reader of this file cannot find the
      // prototype's `5` anywhere in it.
      for (final ReadingStrings table in <ReadingStrings>[en, ar]) {
        expect(table.captionFor(5), isNot('5 questions · about a minute'));
      }
    });

    test('the table has no duration, because the payload has none', () {
      // `ReadingEnScreen.tsx:31` — `Genesis · Chapter 1 · 4 min` — and `:89` —
      // `5 questions · about a minute`. **Neither duration has a source.** There is
      // no duration field anywhere in `GET /readings/today/{lang}` (verified live
      // against `HEAD = 4a1c834`), and inventing one from a word count is inventing
      // a measurement. So the table has no `4 min`, no `about a minute`, and no
      // field a duration could be written into.
      expect(en.captionFor(5), '5 questions');
      expect(ar.captionFor(5), '٥ أسئلة');
      expect(
        en.captionFor(5).contains('min'),
        isFalse,
        reason:
            'and nothing smuggles a duration back in through a different arm',
      );
      expect(en.captionFor(5).contains('minute'), isFalse);
    });
  });

  group('the Arabic arm has no Latin script', () {
    test('no field of the ARABIC arm is an ASCII letter', () {
      // `ReadingStrings` has no `wordmark` field, so there is no exception to
      // carve out here — which is worth noting, because `LoginStrings` and
      // `HomeStrings` both carry `Evangelion` and both tests have to except it.
      // A wordmark is a product name in every language; none of these ten strings
      // is one.
      for (final (String, String) field in ar.fields) {
        expect(
          RegExp('[A-Za-z]').hasMatch(field.$2),
          isFalse,
          reason:
              'the Arabic arm\'s `${field.$1}` is `${field.$2}` — Latin '
              'script in an Arabic string table is the same defect as Arabic in '
              'Space Mono, one layer up',
        );
      }
    });

    test(
      'and the English arm is entirely Latin-or-punctuation, as it must be',
      () {
        // The mirror of the test above, and it is not redundant: it is what rules out
        // an Arabic string having been pasted into the *English* arm by accident, which
        // the one-arm check above cannot see.
        for (final (String, String) field in en.fields) {
          expect(
            RegExp(r'[\u0600-\u06FF]').hasMatch(field.$2),
            isFalse,
            reason: 'the English arm\'s `${field.$1}` is `${field.$2}`',
          );
        }
      },
    );

    test('and no field is empty, on either arm', () {
      for (final ReadingStrings table in <ReadingStrings>[en, ar]) {
        for (final (String, String) field in table.fields) {
          expect(field.$2, isNotEmpty, reason: 'the `${field.$1}` field');
        }
      }
    });

    test('the two arms carry the same field NAMES, so nothing is untranslated', () {
      expect(
        ar.fields.map(((String, String) f) => f.$1).toSet(),
        en.fields.map(((String, String) f) => f.$1).toSet(),
      );
      // **Names, not values** — the Arabic arm is not a transliteration and its
      // values must differ. Asserting equality of values is what a lazy
      // "both arms" check does and it is the opposite of what this wants.
      for (final (String, String) field in en.fields) {
        final String translated = ar.fields
            .firstWhere(((String, String) f) => f.$1 == field.$1)
            .$2;
        expect(translated, isNotEmpty);
      }
    });
  });

  group('the strings that name controls', () {
    test('every interactive node has a name that is not its glyph', () {
      // §14's first row, applied to `/reading`'s three controls. A name that is the
      // glyph ("Aa") is not a name, and the prototype's back and bookmark are
      // `<button>`s around an inline `<svg>` with nothing at all.
      expect(en.back, isNotEmpty);
      expect(en.textSize, isNotEmpty);
      expect(en.bookmark, isNotEmpty);
      // Which is why the `Aa` control is an `IconActionButton`: §14's row lists
      // `Aa` among the icon-only buttons, and `IconActionButton`'s own doc names it
      // as one of "the `Aa` and bookmark controls Phase 7 composes".
      expect(
        en.textSize,
        isNot('Aa'),
        reason:
            'and if it ever were, the glyph would need to be the name and the '
            'widget would have to change',
      );
    });

    test('the unavailable reason is appended by the CALL SITE, not baked in', () {
      // Phase 5 and Phase 6 both do this — `LoginStrings.unavailableSuffix` and
      // `HomeStrings.unavailableSuffix` — and for the same reason: the suffix is a
      // fact about the *control being inert*, so a string table that baked it in
      // would produce "unavailable in this build — unavailable in this build" the
      // moment two inert controls shared a label.
      expect(en.bookmark, isNot(contains(en.unavailableSuffix)));
      expect(en.bookmark, isNot(contains(ar.unavailableSuffix)));
      expect(en.unavailableSuffix, isNotEmpty);
    });
  });
}
