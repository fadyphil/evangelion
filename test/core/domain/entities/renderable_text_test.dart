import 'package:evangelion/core/domain/entities/renderable_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('`isRenderableText`', () {
    // The question is named "renderable", not "well formed", because the whole
    // decision it drives is "may this be handed to the engine?" — and an empty
    // string is well formed and *is* renderable, which is exactly the distinction
    // from "is this verse usable?".
    test('an empty string is renderable, and that is the point', () {
      expect(isRenderableText(''), isTrue);
      expect(renderableTextOrNull(''), '');
    });

    test('Latin scripture is renderable', () {
      expect(
        isRenderableText('There was a man of the Pharisees, named Nicodemus,'),
        isTrue,
      );
    });

    test('Arabic scripture with tashkīl is renderable', () {
      expect(
        isRenderableText(
          'كَانَ إِنْسَانٌ مِنَ ٱلْفَرِّيسِيِّينَ ٱسْمُهُ نِيقُودِيمُوسُ، رَئِيسٌ',
        ),
        isTrue,
      );
    });

    test('a **complete** astral character is renderable', () {
      // U+1F600 GRINNING FACE, which `drop_cap_text.dart` exists because
      // `substring(0, 1)` splits.
      expect(isRenderableText('\u{1F600}'), isTrue);
      expect(isRenderableText('Nicodemus \u{1F600} saw'), isTrue);
      expect('Nicodemus \u{1F600} saw'.codeUnits.length, 16);
    });

    // The four malformed shapes, and every one of them reaches
    // `RenderParagraph` as `ArgumentError: string is not well-formed UTF-16`.
    test('a lone HIGH surrogate — `substring(0, 1)` on an emoji — is not', () {
      final String half = '\u{1F600}'.substring(0, 1);
      expect(half.codeUnits, <int>[0xD83D], reason: 'the defect, measured');
      expect(isRenderableText(half), isFalse);
    });

    test('a lone LOW surrogate is not', () {
      expect(isRenderableText('\uDE00'), isFalse);
      expect(isRenderableText('Nicodemus \uDE00'), isFalse);
    });

    test('a high surrogate followed by an ordinary unit is not', () {
      // The pairing is positional: U+D83D is only legal immediately before a low
      // surrogate, and `a` is not one.
      expect(isRenderableText('\uD83Da'), isFalse);
    });

    test('a malformed string with a valid character before it is still not', () {
      // The case that a `startsWith`/prefix check would miss, and the one that
      // matters: a whole verse is valid scripture with one bad unit somewhere in
      // the middle, and "does it start with something renderable" is not the
      // question.
      expect(isRenderableText('Nicodemus \uD83D and more words'), isFalse);
    });

    test('every boundary of the two surrogate ranges', () {
      // The ranges are U+D800–U+DBFF and U+DC00–U+DFFF. Their edges are where a
      // `<=` written as `<` or the wrong pair of bounds would show up, and the
      // values just outside them are ordinary characters.
      expect(isRenderableText('\uD7FF'), isTrue, reason: 'just below high');
      expect(isRenderableText('\uE000'), isTrue, reason: 'just above low');
      expect(isRenderableText('\uD800'), isFalse, reason: 'first high');
      expect(
        isRenderableText('\uDBFF'),
        isFalse,
        reason: 'last high, unpaired',
      );
      expect(isRenderableText('\uDC00'), isFalse, reason: 'first low');
      expect(isRenderableText('\uDFFF'), isFalse, reason: 'last low, orphan');
      // And a legal pair at each edge of the range.
      expect(isRenderableText('\uD800\uDC00'), isTrue);
      expect(isRenderableText('\uDBFF\uDFFF'), isTrue);
      // …and a pair built from mismatched edges, which is the case a bounds typo
      // would produce.
      expect(isRenderableText('\uD800\uDFFF'), isTrue, reason: 'still a pair');
      expect(isRenderableText('\uDBFF\uDC00'), isTrue, reason: 'still a pair');
    });

    test('two high surrogates in a row are not a pair', () {
      expect(isRenderableText('\uD83D\uD83D'), isFalse);
      expect(isRenderableText('\uD83D\uDE00\uD83D'), isFalse);
    });

    test('four units that pair twice are renderable', () {
      expect(isRenderableText('\uD83D\uDE00\uD83D\uDE00'), isTrue);
    });

    test('`renderableTextOrNull` passes a good string through and refuses a bad '
        'one', () {
      expect(renderableTextOrNull('Nicodemus'), 'Nicodemus');
      expect(
        renderableTextOrNull('\u{1F600}'.substring(0, 1)),
        isNull,
        reason:
            'this is the shape a mapper needs: the value to use, or `null` for '
            '"this row cannot be rendered".',
      );
      expect(renderableTextOrNull(''), '', reason: 'empty is usable');
    });

    test(
      '`renderableTextOrEmpty` blanks a bad string and keeps a good one',
      () {
        expect(renderableTextOrEmpty('John 3:1-5'), 'John 3:1-5');
        expect(
          renderableTextOrEmpty('\u{1F600}'.substring(0, 1)),
          isEmpty,
          reason:
              'the LABEL verdict: a blank the server can also send by sending `\'\'`, '
              'which is what keeps one bad citation from costing the whole reading.',
        );
        expect(renderableTextOrEmpty(''), '', reason: 'empty is usable');
      },
    );

    test('the two fallbacks are **not** interchangeable, and that is the point', () {
      // Decision 95 is a claim about which fields get which verdict, so the two
      // one-liners are asserted side by side: a reader who cannot tell
      // `renderableTextOrNull` from `renderableTextOrEmpty` will eventually use the
      // wrong one on the wrong field, and the wrong one on a label costs the reading.
      const String bad = 'Nicodemus \uD83D';
      expect(
        renderableTextOrNull(bad),
        isNull,
        reason: 'a verse refuses the row',
      );
      expect(
        renderableTextOrEmpty(bad),
        isEmpty,
        reason: 'a label blanks itself, and the reading maps',
      );
    });
  });
}
