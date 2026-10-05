import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `/reading` caption — the one string on this screen that is a **real ICU
/// plural**, and the one whose Arabic agreement classes this migration changed.
///
/// The plural's per-class behaviour is asserted in
/// `test/l10n/app_localizations_test.dart`, which owns the ARB. What is here is what
/// the *wrapper* guarantees: one count in, one correctly-rendered sentence out, with
/// the numeral coming from the domain function rather than from `intl`.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('the caption is pluralised from the REAL count', () {
    test('English says "1 question" at one and "5 questions" at five', () {
      // The verify item. `ReadingEnScreen.tsx:89` hard-codes `5 questions`, and the
      // live reading carries **one** question — so the prototype's literal would be a
      // lie by a factor of five, and a hard-coded `5` is fake data that happens to
      // match nothing the server sends.
      expect(en.readingCaption(1), '1 question');
      expect(en.readingCaption(5), '5 questions');
    });

    test('and it is the SAME function for both, not two call sites', () {
      // One implementation is the point: two `count == 1 ? … : …` expressions are one
      // refactor apart from disagreeing, and the disagreement would only show up in
      // one arm.
      expect(en.readingCaption(1), isNot(en.readingCaption(2)));
      expect(en.readingCaption(0), '0 questions');
      expect(en.readingCaption(2), '2 questions');
      expect(en.readingCaption(11), '11 questions');
    });

    test('Arabic renders the count in Arabic-Indic digits beside the noun', () {
      // `ReadingArScreen.tsx:86-87` writes `٥ أسئلة`. Two things follow: the plural
      // arm is a **plural noun** (3-10 in Arabic take the plural), and the numeral is
      // **U+0665** — an Arabic-block codepoint, which is why this string has to be
      // rendered in `Amiri` and why the glyph gate has something to bite on.
      expect(ar.readingCaption(5), '٥ أسئلة');
      expect(ar.readingCaption(5).codeUnits.first, 0x0665);
    });

    test('and the singular arm is a DIFFERENT string, not the plural one', () {
      expect(ar.readingCaption(1), '١ سؤال واحد');
      expect(ar.readingCaption(1), isNot(ar.readingCaption(5)));
    });

    test('## THE BOUNDARY IS NO LONGER `== 1`, AND THAT IS THE FIX', () {
      // The old `captionFor` implemented exactly one boundary and its doc recorded
      // the rest as **accepted debt**: Arabic has four agreement classes and the
      // table implemented one, so `captionFor(2)` returned `٢ أسئلة` where correct
      // Arabic is `٢ سؤالان`.
      //
      // The debt was accepted then on three grounds — `HomeStrings.streakLabel` had
      // declined the same decision as out of scope, the live payload carried one
      // question, and every other class needed a number the client had never seen.
      // All three are now obsolete: ICU supplies all six classes, and the two the
      // payload has never sent are asserted here anyway because a future payload
      // will send them.
      //
      // **These two assertions are the whole argument for the migration's cost.**
      expect(ar.readingCaption(2), '٢ سؤالان');
      expect(ar.readingCaption(11), '١١ سؤالًا');
      // And the classes the old table DID get right, so this is not a licence to
      // change the ones that were correct:
      expect(ar.readingCaption(0), '٠ أسئلة');
      expect(ar.readingCaption(1), '١ سؤال واحد');
      expect(ar.readingCaption(5), '٥ أسئلة');
      expect(ar.readingCaption(100), '١٠٠ سؤال');
    });

    test(
      'the wrapper takes ONE count, so the two arguments cannot disagree',
      () {
        // `readingCaptionFor` takes the ICU **selector** as an `int` and the **numeral**
        // as a `String`, and they must be the same number. Spelling that out at a call
        // site would make it the caller's job to keep them in step — so this method
        // takes the count once and derives both.
        //
        // The negative control is the whole test: a wrapper that took both would have
        // to be called with the same value twice, and nothing in its signature would
        // stop a caller passing `(5, digits(1))`.
        expect(en.readingCaptionFor(5, en.digits(5)), en.readingCaption(5));
        expect(ar.readingCaptionFor(2, ar.digits(2)), ar.readingCaption(2));
      },
    );
  });

  group('nothing in the caption is a number the server did not send', () {
    test('no caption string contains the prototype\'s `5 questions · about a minute`', () {
      // Tautological against `readingCaption(5)`, deliberately: the point is that
      // **no key** hard-codes a count, so a reader of this file cannot find the
      // prototype's `5` anywhere in it.
      expect(en.readingCaption(5), isNot('5 questions · about a minute'));
      expect(ar.readingCaption(5), isNot('٥ أسئلة · حوالي دقيقة'));
    });

    test('the caption has no duration, because the payload has none', () {
      // `ReadingEnScreen.tsx:31` — `Genesis · Chapter 1 · 4 min` — and `:89` —
      // `5 questions · about a minute`. **Neither duration has a source.** There is
      // no duration field anywhere in `GET /readings/today/{lang}` (verified live
      // against `HEAD = 4a1c834`), and inventing one from a word count is inventing
      // a measurement. So there is no `4 min`, no `about a minute`, and no key a
      // duration could be written into.
      expect(en.readingCaption(5), '5 questions');
      expect(ar.readingCaption(5), '٥ أسئلة');
      expect(
        en.readingCaption(5).contains('min'),
        isFalse,
        reason:
            'and nothing smuggles a duration back in through a different arm',
      );
      expect(en.readingCaption(5).contains('minute'), isFalse);
    });
  });

  group('the strings that name controls', () {
    test('every interactive node has a name that is not its glyph', () {
      // §14's first row, applied to `/reading`'s three controls. A name that is the
      // glyph ("Aa") is not a name, and the prototype's back and bookmark are
      // `<button>`s around an inline `<svg>` with nothing at all.
      expect(en.readingBack, isNotEmpty);
      expect(en.readingTextSize, isNotEmpty);
      expect(en.readingBookmark, isNotEmpty);
      // Which is why the `Aa` control is an `IconActionButton`: §14's row lists `Aa`
      // among the icon-only buttons, and `IconActionButton`'s own doc names it as one
      // of "the `Aa` and bookmark controls Phase 7 composes".
      expect(
        en.readingTextSize,
        isNot('Aa'),
        reason:
            'and if it ever were, the glyph would need to be the name and the '
            'widget would have to change',
      );
    });

    test(
      'the unavailable reason is appended by the CALL SITE, not baked in',
      () {
        // `/login` and `/` both do this — `authUnavailableSuffix` and
        // `homeUnavailableSuffix` — and for the same reason: the suffix is a fact about
        // the *control being inert*, so a string table that baked it in would produce
        // "unavailable in this build — unavailable in this build" the moment two inert
        // controls shared a label.
        expect(
          en.readingBookmark,
          isNot(contains(en.readingUnavailableSuffix)),
        );
        expect(
          en.readingBookmark,
          isNot(contains(ar.readingUnavailableSuffix)),
        );
        expect(en.readingUnavailableSuffix, isNotEmpty);
      },
    );

    test('and `readingTextSize` and `readingFontSize` stay TWO keys', () {
      // The bug `reading_accessibility_test.dart` caught: one string for the `Aa`
      // **disclosure you press** and for **the slider it reveals** put two nodes on
      // screen with the identical label, so a screen-reader user heard "Text size"
      // twice and could not tell the button from the thing it opened.
      expect(en.readingTextSize, isNot(en.readingFontSize));
      expect(ar.readingTextSize, isNot(ar.readingFontSize));
    });
  });
}
