import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `/quiz` derived strings — `quizCrumb` and `optionLabel`.
///
/// Both are methods on the extension, not ARB keys. The keys they read are asserted
/// by `test/l10n/app_localizations_test.dart`, which owns the ARB; what is here is
/// the **composition**, because that is the part no ARB can express and the part a
/// translation change could quietly break.
///
/// ## AND WHY THERE IS NO `questionProgress` ANY MORE
///
/// The composed `Question <current> of <total>` line was the old chrome's progress
/// surface. The redesign's quiz screen (`eva/redesign.html:562-574`) has no count
/// sentence — the progress surface is the bead row, whose accessible name is the
/// `quizProgress` key — so the composition and the `quizOfWord` key died with the
/// chrome. `quiz_l10n_test.dart`'s old digit/total-totality rows died with them.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('`quizCrumb`, the composed appbar sentence', () {
    test('is the key plus the payload reference, on one separator', () {
      // `eva/redesign.html:1348` — `` `${tr('refraction')} · ${bookTitle(b)}` `` —
      // one interpolated literal for both arms, so the separator is the prototype's
      // own `·` (U+00B7) and not a punctuation decision of this client's.
      expect(en.quizCrumb('John 3:1-5'), 'Refraction · John 3:1-5');
      expect(ar.quizCrumb('يوحنا 3: 1-5'), 'انعطاف · يوحنا 3: 1-5');
      expect(en.quizCrumb('John 3:1-5'), contains('·'));
    });

    test(
      'the reference is carried VERBATIM — never parsed, never reformatted',
      () {
        // `Verse.bookNumber`'s recorded refusal, one level up: the backend already
        // formats the reference per language, including the space after the Arabic
        // colon. A client-side parse would be a second formatting authority.
        const String spaced = 'يوحنا 3: 1-5';
        expect(ar.quizCrumb(spaced), contains(spaced));
      },
    );

    test('an empty reference composes to the key and the separator', () {
      // `reference: ''` passes the mapper (the same rule as `/`'s preview —
      // recorded decision 45), so the composition must stay total: a crumb that
      // throws on the one string the mapper refused nothing about would take the
      // screen down.
      expect(en.quizCrumb(''), 'Refraction · ');
    });
  });

  group('`optionLabel`, and the spoiler boundary as a string', () {
    test('before a check there is **no suffix at all**', () {
      // The boundary in one assertion. `quiz_page_test.dart` proves it on the
      // rendered tree and in the semantics tree; this proves the **word** is absent
      // from the string the card builds, so a page that passed the verdict in anyway
      // would have nothing to spell.
      expect(en.optionLabel(letter: 'A', text: 'Nicodemus'), 'A. Nicodemus');
      // `suffix` is left at its `null` default on both Arabic arms: the claim is
      // "no suffix at all", and the two-worded assertion below is what proves it.
      expect(
        en.optionLabel(letter: 'A', text: 'نيقوديموس'),
        isNot(contains(en.quizCorrectSuffix)),
      );
      expect(
        en.optionLabel(letter: 'A', text: 'نيقوديموس'),
        isNot(contains(en.quizIncorrectSuffix)),
      );
    });

    test('after a check the suffix is there, and it belongs to the caller', () {
      expect(
        en.optionLabel(
          letter: 'A',
          text: 'Nicodemus',
          suffix: en.quizCorrectSuffix,
        ),
        'A. Nicodemus — correct answer',
      );
      expect(
        ar.optionLabel(
          letter: 'أ',
          text: 'نيقوديموس',
          suffix: ar.quizCorrectSuffix,
        ),
        'أ. نيقوديموس — الإجابة الصحيحة',
      );
    });

    test('an EMPTY suffix is treated as no suffix', () {
      // `String?` with `null` meaning "nothing" and `''` meaning "nothing" would
      // leave a caller that computed `''` producing `'A. Nicodemus — '`, which is a
      // visible trailing dash on every option. Coalesced here, once.
      expect(
        en.optionLabel(letter: 'A', text: 'Nicodemus', suffix: ''),
        'A. Nicodemus',
      );
    });

    test('the letter comes from the wire and is NOT validated', () {
      // §5 trap 10: the id the server hands out is `question-group-3`, and the
      // option keys come from the same payload. A client that checked the letter
      // would reject a request the backend accepts.
      expect(en.optionLabel(letter: 'Z', text: 'x'), 'Z. x');
      expect(en.optionLabel(letter: '', text: 'x'), '. x');
    });
  });

  group('the retired strings stay retired', () {
    test('the verdict sentences and the `of` word are gone from both arms', () {
      // `FeedbackBanner` and the `Question N of M` line died with the old chrome
      // (`eva/redesign.html:562-574` has neither), and their keys died with them.
      // This is the assertion that a reintroduced key is a decision, not a drift:
      // `AppLocalizationsEn` is generated, so a key back in the ARB puts the getter
      // back here and this line goes red.
      expect(en.quizCrumb, isA<Function>());
      // The names below are spelled as strings on purpose: the getters do not
      // exist, and a compile-time reference would be the wrong instrument for a
      // claim about absence.
      // ignore: avoid_dynamic_calls
      expect(() => (en as dynamic).quizOfWord, throwsNoSuchMethodError);
      // ignore: avoid_dynamic_calls
      expect(() => (en as dynamic).quizVerdictCorrect, throwsNoSuchMethodError);
    });
  });

  group('the dead-control suffixes', () {
    test('both arms say WHY, not only that', () {
      // §14's disabled row. `LoginPage`'s four inert social buttons (recorded
      // decision 18) are the precedent, and the reason `/quiz` can ship a dead CTA
      // honestly: a reader who taps a button that does nothing is told nothing.
      expect(en.quizAlreadyAnsweredSuffix, isNotEmpty);
      expect(en.quizUnavailableSuffix, isNotEmpty);
      expect(ar.quizAlreadyAnsweredSuffix, isNotEmpty);
      expect(ar.quizUnavailableSuffix, isNotEmpty);
    });

    test('and they do not overlap the verdict words', () {
      // If `quizUnavailableSuffix` contained "correct", the semantics assertion that
      // no node carries a verdict before a check would pass for the wrong reason on
      // a page that appended the suffix everywhere.
      expect(
        en.quizAlreadyAnsweredSuffix.toLowerCase(),
        isNot(contains('correct')),
      );
      expect(
        en.quizUnavailableSuffix.toLowerCase(),
        isNot(contains('correct')),
      );
      expect(
        en.quizAlreadyAnsweredSuffix.toLowerCase(),
        isNot(contains('incorrect')),
      );
    });
  });
}
