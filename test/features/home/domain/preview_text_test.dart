import 'package:evangelion/features/home/domain/preview_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/utf16.dart';

/// [previewText] — red-first (AGENT_CONTEXT §6: extracted domain logic, TDD'd).
///
/// ## THE LIVE ENGLISH VERSE IS 71 CHARACTERS, SO THIS ALWAYS RUNS
///
/// `"There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:"` —
/// which makes it a real function rather than a guard, and makes the cut
/// observable: the word after the cut is `Nicodemus,`, and a cut that ran to the
/// space before it would read `…a ruler of the Jews:` for a much shorter prefix.
void main() {
  group('shorter than the budget', () {
    test('is returned unchanged, with no ellipsis', () {
      expect(previewText('There was a man.', maxChars: 56), 'There was a man.');
    });

    test('and exactly at the budget is unchanged too', () {
      final String exact = 'a' * 56;
      expect(previewText(exact, maxChars: 56), exact);
      expect(
        previewText(exact, maxChars: 56),
        isNot(contains(kPreviewEllipsis)),
      );
    });

    test('one character over is cut', () {
      expect(
        previewText('a' * 57, maxChars: 56),
        '${'a' * 56}$kPreviewEllipsis',
      );
    });

    test('an empty string stays empty — no ellipsis on nothing', () {
      expect(previewText(''), '');
    });
  });

  group('longer than the budget', () {
    test('the live English first verse is cut on a word boundary', () {
      const String verse =
          'There was a man of the Pharisees, named Nicodemus, a ruler of the '
          'Jews:';
      expect(
        verse.length,
        greaterThan(kPreviewMaxChars),
        reason:
            'the live first verse must be long enough for this function to '
            'run at all — if the backend shortens it, this group stops testing '
            'anything',
      );

      final String preview = previewText(verse);
      final String body = preview.substring(
        0,
        preview.length - kPreviewEllipsis.length,
      );

      expect(preview, endsWith(kPreviewEllipsis));
      // Two mechanical claims rather than one fuzzy one. "Does not contain a
      // partial word" cannot be written directly — the body legitimately contains
      // `Pharisees,` — so the cut is checked as what it is: a **prefix** of the
      // source whose next character is a space.
      expect(
        verse.startsWith(body),
        isTrue,
        reason: 'the body must be a prefix of the verse, not a re-assembly',
      );
      expect(
        verse[body.length],
        ' ',
        reason:
            'and the character after it must be a space, or a word was cut '
            'in half',
      );
    });

    test('and it is never longer than the budget plus the ellipsis', () {
      // The budget is a *width*, so the ellipsis is allowed past it — one glyph of
      // overflow, not a word of it.
      const String verse =
          'There was a man of the Pharisees, named Nicodemus, a ruler of the '
          'Jews:';
      expect(
        previewText(verse).length,
        lessThanOrEqualTo(kPreviewMaxChars + kPreviewEllipsis.length),
      );
    });

    test('a cut mid-word still stops at the nearest space in range', () {
      expect(
        previewText('alpha bravo charlie delta echo foxtrot', maxChars: 20),
        'alpha bravo charlie$kPreviewEllipsis',
      );
    });

    test('and it is never cut back more than the boundary fraction', () {
      // The failure the fraction exists to prevent: a prefix whose only space is
      // far from the cut must **not** be trimmed back to it. `alpha bravo charlie`
      // is 18 characters and the space after it is at index 18, inside the final
      // four — so it is taken. Without the fraction a text like
      // `alpha bravo charlie deltaecho` (space only at index 11, budget 20) would
      // be cut back to `alpha bravo`, throwing away seven characters to reach a
      // boundary the reader would not have noticed was missing.
      expect(
        previewText('alpha bravo charlie delta echo foxtrot', maxChars: 20),
        'alpha bravo charlie$kPreviewEllipsis',
        reason: 'the space at index 5 is outside the final 4 characters',
      );
    });

    test('with no space anywhere, the cut runs to the budget', () {
      // Arabic and a Hebrew class of text both do this, and the earlier verse is
      // the measured example: `text_clean` has no ASCII spaces in most of its
      // length, so this arm is live rather than defensive.
      final String preview = previewText('أ' * 80, maxChars: 56);

      expect(preview.length, kPreviewMaxChars + kPreviewEllipsis.length);
      expect(preview, '${'أ' * 56}$kPreviewEllipsis');
    });

    test('and with a space exactly at the boundary, it takes it', () {
      // 20 chars, floor at 16, so a space at index 16 is the first accepted one.
      expect(
        previewText('alpha bravo charlie delta echo', maxChars: 20),
        'alpha bravo charlie$kPreviewEllipsis',
      );
    });
  });

  group('an ASTRAL character at the cut, which is a thrown `ArgumentError`', () {
    // `String.substring` indexes **UTF-16 code units**, so a budget that lands
    // between a surrogate pair leaves the **high surrogate alone** in the result.
    // That is not a truncated emoji, it is half a character — and `RenderParagraph`
    // throws `ArgumentError: string is not well-formed UTF-16` out of
    // `_RenderScaledInlineWidget.performLayout`, which takes the panel's own two
    // controls with it.
    //
    // 55 ASCII characters then one emoji is exactly that: the budget of 56 lands on
    // the emoji's first code unit.
    test('the result is well-formed UTF-16', () {
      final String preview = previewText('${'x' * 55}\u{1F600} tail');
      expect(
        isWellFormedUtf16(preview),
        isTrue,
        reason:
            'the preview holds ${unpairedSurrogates(preview)}, so '
            '`RenderParagraph` throws when the panel renders it',
      );
      // The control: the cut this fix makes, without the fix.
      expect(
        isWellFormedUtf16('${'x' * 55}\u{1F600} tail'.substring(0, 56)),
        isFalse,
        reason: 'this is what `substring(0, maxChars)` alone produces',
      );
    });

    test('and no half of an emoji survives into it', () {
      final String preview = previewText('${'x' * 55}\u{1F600} tail');
      expect(
        preview.runes,
        isNot(contains(0xD83D)),
        reason: 'U+D83D on its own is the high surrogate of U+1F600',
      );
      expect(preview, '${'x' * 55}$kPreviewEllipsis');
      expect(isWellFormedUtf16(preview), isTrue);
    });

    test('the whole emoji is kept when the budget allows for both units', () {
      // The other side, so the fix cannot be "drop the last character whatever it
      // is": at a budget of 57 the pair fits and nothing is lost.
      expect(
        previewText('${'x' * 55}\u{1F600} tail', maxChars: 57),
        '${'x' * 55}\u{1F600}$kPreviewEllipsis',
      );
    });

    test('one unit short of the pair also keeps nothing half-formed', () {
      expect(
        previewText('${'x' * 55}\u{1F600} tail', maxChars: 56),
        '${'x' * 55}$kPreviewEllipsis',
      );
    });

    test('and the low surrogate is never what gets kept', () {
      // Every emoji at every offset inside the budget: the low surrogate is never a
      // legal result of a cut, and this is the sweep that says so rather than one
      // measured offset.
      for (int prefix = 0; prefix < 8; prefix++) {
        for (int budget = 1; budget <= 8; budget++) {
          final String preview = previewText(
            '${'x' * prefix}\u{1F600}${'y' * 20}',
            maxChars: budget,
          );
          expect(
            isWellFormedUtf16(preview),
            isTrue,
            reason:
                'prefix $prefix, budget $budget → unpaired '
                '${unpairedSurrogates(preview)}',
          );
        }
      }
    });

    test('a word-boundary back-up cannot rescue one, so the guard is before it', () {
      // The order matters: the boundary search runs on `taken`, and a dangling
      // surrogate is not a space, so a text with spaces either drops it by accident
      // (when a space happens to fall inside the final fifth) or keeps it. The
      // well-formedness guard has to be the first thing that touches the cut.
      final String preview = previewText('${'ab ' * 20}\u{1F600}');
      expect(isWellFormedUtf16(preview), isTrue);
      expect(preview, endsWith(kPreviewEllipsis));
    });
  });

  group('the ellipsis', () {
    test('is U+2026, not three dots', () {
      // Asserted as a codepoint because the failure is invisible in a diff: `...`
      // and `…` are the same three-ish pixels of meaning and different strings, and
      // the prototype's own preview (`HomeScreen.tsx:57`) uses U+2026.
      expect(kPreviewEllipsis.runes, <int>[0x2026]);
      expect(kPreviewEllipsis.length, 1);
    });

    test('and every truncated result ends with exactly one', () {
      for (final String text in <String>[
        'a' * 100,
        'There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:',
        'أ' * 80,
      ]) {
        final String preview = previewText(text);
        expect(
          kPreviewEllipsis.allMatches(preview).length,
          1,
          reason:
              'preview of "${preview.length} chars" held '
              '${kPreviewEllipsis.allMatches(preview).length}',
        );
      }
    });
  });

  group('the constants', () {
    test('the budget is the prototype\'s own preview length', () {
      // `HomeScreen.tsx:57` — "n the beginning God created the heavens and the
      // earth…" is 53 characters of text; add the drop cap's `I` and 56 is the
      // number. Pinned so "why 56" has an answer that is not taste.
      expect(kPreviewMaxChars, 56);
    });

    test('and the boundary fraction is the final fifth', () {
      expect(kPreviewBoundaryFraction, 0.2);
      expect((kPreviewMaxChars * kPreviewBoundaryFraction).floor(), 11);
    });
  });
}
