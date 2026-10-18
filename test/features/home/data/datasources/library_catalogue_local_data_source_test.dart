import 'dart:io';

import 'package:evangelion/features/home/data/datasources/library_catalogue_local_data_source.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LibraryCatalogueLocalDataSource] — the fiction, held to the prototype's own
/// numbers.
///
/// ## WHY THE WASHES ARE RE-READ OUT OF THE PROTOTYPE AND NOT QUOTED
///
/// The data source packs `bloomArgb` literals (`0x8CE457D6` and friends) with a
/// comment naming the `rgba(...)` each came from, and a comment is not a gate:
/// re-typing the alpha or swapping two cards' colours would pass every review
/// that did not happen to have the CSS open. So this suite reads the prototype's
/// `BOOKS` and `SEALED` literals at test time — the discipline
/// `home_geometry_test.dart` applies to the CSS and `home_l10n_test.dart` to the
/// I18N table — and asks the packed ints to agree with the parsed `rgba` values.
///
/// ## AND THE MATHS IS WRITTEN DOWN HERE, NOT IN THE WIDGET
///
/// `0xAARRGGBB` here is the prototype's `rgba(r,g,b,a)` with `a × 255` rounded —
/// `.55 → 140 = 0x8C`, `.5 → 128 = 0x80`, `.45 → 115 = 0x73`. The three alphas
/// are the only three the prototype uses on the six cards, so the suite asserts
/// the *conversion table* once and then every card against it, which is one
/// arithmetic claim instead of six.
void main() {
  /// The prototype file this suite reads. Read-only — `eva/` is reference
  /// material (AGENT_CONTEXT §2, §8).
  const String prototype = 'eva/redesign.html';

  /// `.55` in a byte: `0.55 × 255 = 140.25`, and the prototype's own rendering
  /// rounds the same way CSS's `alpha × 255` does.
  const int alpha55 = 0x8C;

  /// `.5` in a byte: `0.5 × 255 = 127.5`, and 127.5 rounds to `128 = 0x80` — the
  /// half-even tie that CSS's `round()` shares.
  const int alpha50 = 0x80;

  /// `.45` in a byte: `0.45 × 255 = 114.75`, which rounds to `115 = 0x73`.
  const int alpha45 = 0x73;

  /// The six cards, as the prototype declares them: four in `BOOKS`
  /// (`redesign.html:1018-1031`) with their `css:` washes, two in `SEALED`
  /// (`:1032-1035`) with theirs. Parsed at test time rather than transcribed.
  final Map<String, ({String css, String nameEn, String nameAr, String cat})>
  prototype_ = _books(File(prototype).readAsStringSync());

  final List<LibraryBook> books = const LibraryCatalogueLocalDataSource()
      .books();

  group('the six cards, against the prototype\'s own literals', () {
    test('the prototype really declares six, four open and two sealed', () {
      // The anti-vacuity row: a suite that parsed nothing would pass every
      // comparison below against an empty map, green and about nothing. The
      // counts are the prototype's (`:1018-1031` four books, `:1032-1035` two
      // sealed), and the label says "6 scrolls · 4 open" (`:930`) — which is
      // the same six from the other side.
      expect(prototype_, hasLength(6));
      expect(books, hasLength(6));
      expect(books.where((LibraryBook b) => !b.sealed), hasLength(4));
      expect(books.where((LibraryBook b) => b.sealed), hasLength(2));
    });

    test('every card\'s id, name and category come from the prototype', () {
      // Ordered as the prototype draws them (`:1311-1318` reads `BOOKS` then
      // `SEALED`), because the carousel's order is the prototype's order and a
      // sorted copy would be a second opinion about what the reader meets
      // first.
      final List<String> ids = <String>[
        'psalms',
        'john',
        'genesis',
        'isaiah',
        'acts',
        'revelation',
      ];
      expect(books.map((LibraryBook b) => b.id).toList(), ids);
      for (final LibraryBook book in books) {
        final ({String css, String nameEn, String nameAr, String cat}) card =
            prototype_[book.id]!;
        expect(book.nameEn, card.nameEn, reason: '${book.id}.nameEn');
        expect(book.nameAr, card.nameAr, reason: '${book.id}.nameAr');
        expect(
          book.category.name,
          card.cat,
          reason: '${book.id}.cat — the `CATS` key, not a re-spelling',
        );
      }
    });

    test('every card\'s wash is the prototype\'s rgba, packed', () {
      // The conversion table first, once — three alphas, because those are the
      // only three the prototype uses on these six cards. Asserted against the
      // *parsed* alphas rather than against the constants above, so the
      // constants are a restatement of the maths and the maths is checked.
      final Map<String, int> alphaOf = <String, int>{
        for (final ({String css, String nameEn, String nameAr, String cat}) card
            in prototype_.values)
          card.css: _alphaByte(card.css),
      };
      expect(alphaOf.values.toSet(), <int>[alpha55, alpha50, alpha45]);

      for (final LibraryBook book in books) {
        final String css = prototype_[book.id]!.css;
        final (int r, int g, int b) = _rgb(css);
        expect(
          book.bloomArgb,
          (alphaOf[css]! << 24) | (r << 16) | (g << 8) | b,
          reason:
              '${book.id}\'s wash is `$css`, packed `0xAARRGGBB` — the data '
              'source\'s comment names this line and this row is what keeps the '
              'comment honest',
        );
      }
    });

    test('the two sealed cards are the prototype\'s two, and carry no count', () {
      // `SEALED` (`:1032-1035`) holds no verse array — that is the prototype's
      // own distinction, not a gap — and `:1317` writes the category alone for
      // a sealed card because of it. A `verseCount` on a sealed card would be
      // the client inventing a number the prototype does not have, which is
      // exactly what this file's doc says the six excerpt counts already are.
      final Set<String> sealed = books
          .where((LibraryBook b) => b.sealed)
          .map((LibraryBook b) => b.id)
          .toSet();
      expect(sealed, <String>{'acts', 'revelation'});
      for (final LibraryBook book in books.where((LibraryBook b) => b.sealed)) {
        expect(book.verseCount, isNull, reason: '${book.id} is sealed');
      }
      // And the four open books carry the prototype's **excerpt lengths** —
      // `b.en.length` (`:1313`), which are 6, 5, 5 and 4 lines of a demo
      // corpus. Wrong about the Bible (Psalms has 2461 verses in the backend's
      // `bible_verses`), right about the surface being transcribed; the data
      // source's doc records the whole argument.
      final Map<String, int> counts = <String, int>{
        for (final LibraryBook book in books.where(
          (LibraryBook b) => !b.sealed,
        ))
          book.id: book.verseCount!,
      };
      expect(counts, <String, int>{
        'psalms': 6,
        'john': 5,
        'genesis': 5,
        'isaiah': 4,
      });
    });

    test('and the seal dimmer `.35` is NOT here, because it is caller state', () {
      // `eva/redesign.html:285` — `.bcard.sealed .bloom{opacity:.35}` — is the
      // *rendered* state of a sealed card, which `LibraryCarousel` applies
      // (`sealedWashFactor`); the data source holds the card's **own** wash.
      // Conflating them would bake one widget's presentation into the data
      // every future consumer inherits.
      //
      // **A loop and not `everyElement`, and the reason is a measured one: the
      // nested matcher form overflowed the stack inside `matcher`'s own mismatch
      // description before it could report anything.** A plain loop fails with
      // the offending card's id, which is the message a reader needs anyway.
      final int dimmer = _alphaByteOf('.35');
      for (final LibraryBook book in books) {
        expect(
          (book.bloomArgb >> 24) & 0xFF,
          isNot(dimmer),
          reason: '${book.id} is stored at the seal dimmer\'s alpha',
        );
      }
    });
  });
}

/// The prototype's `BOOKS` + `SEALED` literals as a map by id.
///
/// **Two regexes, because the prototype declares the two sets differently.** The
/// four open books are `{name:'psalms',arName:…,cat:…}` (`:1018-1031`) and the
/// two sealed ones are `{id:'acts',name:…,arName:…,cat:…,css:…}`
/// (`:1032-1035`), so one pattern cannot read both and two are cheaper than a
/// parser. The `css:` value is read with the same `[^']*` rule the other fields
/// use, which is safe because the CSS colour contains no quote.
Map<String, ({String css, String nameEn, String nameAr, String cat})> _books(
  String html,
) {
  final Map<String, ({String css, String nameEn, String nameAr, String cat})>
  out = <String, ({String css, String nameEn, String nameAr, String cat})>{};
  final RegExp open = RegExp(
    r"\{name:'([^']+)',arName:'([^']+)',cat:'([^']+)',hsl:\{[^}]*\},css:'([^']*)'",
  );
  for (final RegExpMatch m in open.allMatches(html)) {
    out[m.group(1)!] = (
      css: m.group(4)!,
      nameEn: m.group(1)!,
      nameAr: m.group(2)!,
      cat: m.group(3)!,
    );
  }
  final RegExp sealed = RegExp(
    r"\{id:'([^']+)',name:'([^']+)',arName:'([^']+)',cat:'([^']+)',css:'([^']*)'",
  );
  for (final RegExpMatch m in sealed.allMatches(html)) {
    out[m.group(1)!] = (
      css: m.group(5)!,
      nameEn: m.group(2)!,
      nameAr: m.group(3)!,
      cat: m.group(4)!,
    );
  }
  return out;
}

/// The alpha byte of a `rgba(r,g,b,a)` literal — `a × 255`, rounded.
///
/// The leading dot is a number: `.55` is not `55`. The same rule
/// `css_reference.dart`'s `cssPxList` encodes, and for the same measured reason
/// — the first version of that regex read `opacity: .35` as `35`.
int _alphaByte(String css) {
  // **The alpha is captured whole, and the leading dot must be part of the
  // match.** The first version wrote `\.?([\d.]+)`, which made the dot optional
  // and let `\d+` start at the `5` of `.55` — measuring 14025 where 140 is the
  // truth, a factor of exactly 100 on every card. The alternation reads `.55`
  // and `0.55` and `1` as themselves and nothing else.
  final RegExpMatch? match = RegExp(
    r'rgba\([^)]*,\s*((?:\.\d+)|(?:[01](?:\.\d+)?))\)',
  ).firstMatch(css);
  if (match == null) {
    throw StateError('`$css` carries no rgba alpha, which this suite reads');
  }
  final double alpha = double.parse(match.group(1)!);
  return (alpha * 255).round();
}

/// The alpha byte of a **bare** opacity literal — `.35`, as `:285` writes it.
///
/// [alpha for the `rgba` form. The dimmer appears in the prototype as a bare
/// number (`.bcard.sealed .bloom{opacity:.35}`), and the same leading-dot rule
/// applies: the first version read it through the `rgba` regex and threw, which
/// is the throw doing its job on a value this reader was not shaped for.
int _alphaByteOf(String alpha) {
  final RegExpMatch? match = RegExp(r'^((?:\.\d+)|(?:[01](?:\.\d+)?))$')
      .firstMatch(alpha);
  if (match == null) {
    throw StateError('`$alpha` is not a bare opacity this suite reads');
  }
  return (double.parse(match.group(1)!) * 255).round();
}

/// The r, g and b of a `rgba(r,g,b,a)` literal.
(int, int, int) _rgb(String css) {
  final RegExpMatch? match = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),')
      .firstMatch(css);
  if (match == null) {
    throw StateError('`$css` is not an rgba literal this suite reads');
  }
  return (
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
