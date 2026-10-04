/// `splitDropCap` — the one place a passage's first character becomes a drop cap.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A LINE IN EACH WIDGET
///
/// Two screens render a drop cap off a server string — `/`'s preview
/// (`today_reading_panel.dart`) and `/reading`'s first verse (`scripture_block.dart`) —
/// and Phase 6's C3 fix hardened **one** of them, which is how Phase 7 shipped the
/// identical defect in the other. Two call sites of a two-line rule is one rule, and
/// a rule with two copies has one copy wrong before the next reviewer notices.
///
/// ## AND WHY IT IS DOMAIN LOGIC
///
/// AGENT_CONTEXT §6: "if a widget needs a conditional or calculation, extract it to
/// a cubit or a pure function and TDD that." The calculation here is a UTF-16 index
/// into text that came off the wire, and §3 puts a type two features consume in the
/// shared kernel rather than in either of them.
///
/// ## THE THREE THINGS IT GETS RIGHT, AND ALL THREE ARE OBSERVABLE
///
/// 1. **The cut is on a rune, not a code unit.** `String.substring` indexes UTF-16
///    code units, so `substring(0, 1)` on a character above U+FFFF returns a **lone
///    surrogate** — and `RenderParagraph` then throws `ArgumentError: string is not
///    well-formed UTF-16` out of layout, taking the whole screen with it.
/// 2. **The cut is on the first non-space rune.** `' ‹Verily…'` at a 146px cap is an
///    *invisible* glyph: the reader sees a gap where the letter should be.
/// 3. **It is total over `String`.** An empty string is a letter of `''` and a rest
///    of `''`, so no caller has to guard and no caller can forget to.
library;

import 'package:evangelion/core/domain/entities/drop_cap_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/utf16.dart';

void main() {
  group('a Latin verse', () {
    test('splits the first character from the rest', () {
      final DropCapText split = splitDropCap('There was a man');
      expect(split.letter, 'T');
      expect(split.rest, 'here was a man');
    });

    test('and the two halves reassemble into the input', () {
      // The other direction, because a splitter that drops a character satisfies the
      // test above: `letter` is one character and `rest` is "the rest", so
      // `letter + rest == text` is the property that says nothing went missing.
      for (final String text in <String>[
        'There was a man of the Pharisees',
        'In the beginning',
        'a',
      ]) {
        final DropCapText split = splitDropCap(text);
        expect(split.letter + split.rest, text, reason: text);
      }
    });
  });

  group('an ASTRAL first character, which is the defect this exists for', () {
    test('keeps both code units in the letter', () {
      // U+1F600 is two UTF-16 code units. `substring(0, 1)` takes the high
      // surrogate alone, which is not a character and is not renderable.
      final DropCapText split = splitDropCap('\u{1F600} There was a man');
      expect(split.letter.runes, <int>[0x1F600]);
      expect(split.letter.length, 2);
      expect(split.rest, ' There was a man');
    });

    test('and neither half is a lone surrogate', () {
      // The assertion the throw actually comes from, stated as a property of both
      // halves. **Not** `runes.length == length`: `runes` yields an unpaired
      // surrogate as a rune of its own, so the broken string satisfies that — it is
      // the one predicate that cannot see this defect. `support/utf16.dart` walks the
      // code units instead, and the widget suite proves the layout throws without
      // this.
      final DropCapText split = splitDropCap('\u{1F600} There was a man');
      for (final (String label, String value) in <(String, String)>[
        ('letter', split.letter),
        ('rest', split.rest),
      ]) {
        expect(
          isWellFormedUtf16(value),
          isTrue,
          reason: 'the $label is unpaired at ${unpairedSurrogates(value)}',
        );
      }
      // The predicate itself, so a reader who trusts it can see it reject the
      // defect: `substring(0, 1)` on this string is *not* well formed.
      expect(
        isWellFormedUtf16('\u{1F600}'.substring(0, 1)),
        isFalse,
        reason: 'the control — this is what `RenderParagraph` throws on',
      );
    });

    test('a verse that is NOTHING but an emoji still splits', () {
      final DropCapText split = splitDropCap('\u{1F600}');
      expect(split.letter.runes, <int>[0x1F600]);
      expect(split.rest, isEmpty);
    });

    test('and an emoji immediately followed by text loses no code unit', () {
      final DropCapText split = splitDropCap('\u{1F4D6}Gen');
      expect(split.letter.runes, <int>[0x1F4D6]);
      expect(split.rest, 'Gen');
    });
  });

  group('leading whitespace, which is a blank 146px glyph', () {
    test('is skipped rather than enlarged', () {
      // The measured shape: `substring(0, 1)` on `' ‹Verily…'` returns `' '`, so
      // the largest element on the screen renders **nothing** and the reader sees
      // the paragraph start one letter in.
      final DropCapText split = splitDropCap(' \u{2039}Verily, verily');
      expect(split.letter, '\u{2039}');
      expect(split.rest, 'Verily, verily');
    });

    test('and the whitespace is dropped from the rest too', () {
      // Otherwise the paragraph opens with a space the cap has already "moved past",
      // which is a visible indent on the first line of the passage.
      final DropCapText split = splitDropCap('   In the beginning');
      expect(split.letter, 'I');
      expect(split.rest, 'n the beginning');
      expect(split.rest.codeUnits.first, 0x6E);
    });

    test('a tab is skipped as well', () {
      expect(splitDropCap('\t\tThere').letter, 'T');
    });

    test('and trailing whitespace is left alone', () {
      // Only the **leading** whitespace is the cap's business; the tail belongs to
      // the paragraph and dropping it here would be the client editing scripture.
      expect(splitDropCap('There  ').rest, 'here  ');
    });
  });

  group('total over `String`, so no caller has to guard', () {
    test('the empty string is an empty letter and an empty rest', () {
      expect(splitDropCap(''), (letter: '', rest: ''));
    });

    test('and so is a string of nothing but whitespace', () {
      // The case an `isEmpty` guard misses: it is not empty, and its first
      // character is a space, so the cap renders an invisible glyph.
      expect(splitDropCap('   '), (letter: '', rest: ''));
      expect(splitDropCap('\n\t '), (letter: '', rest: ''));
    });

    test('and a letter of `\'\'` is the signal a caller renders nothing', () {
      // The two call sites' existing shape — `preview.isEmpty` and
      // `verse.text.isEmpty` — becomes "the letter is empty", which is the same
      // question asked about the character actually chosen.
      expect(splitDropCap('').letter.isEmpty, isTrue);
      expect(splitDropCap('   ').letter.isEmpty, isTrue);
      expect(splitDropCap('T').letter.isEmpty, isFalse);
    });
  });
}
