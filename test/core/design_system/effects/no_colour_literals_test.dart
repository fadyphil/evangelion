import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/project_import_graph.dart';

/// Colour literals under `lib/` are confined to the token tables.
///
/// AGENT_CONTEXT §4 requires every colour to resolve through `EvaColors` or
/// `EvaStickerPalette`, and "no hex literals in production code" is the
/// mechanical form of that. It is also, on its own, unenforceable by review —
/// `0xFF6C3FE8` looks like a colour nobody chose and behaves like a colour nobody
/// chose, in a design system whose whole premise is that the values were.
///
/// So this walks the files rather than trusting a diff.
///
/// ## WHY THE RULE IS "MUST RESOLVE", NOT "MUST NOT LOOK LIKE A LITERAL"
///
/// The first version enumerated the *spellings* it considered a literal —
/// `Color(0x` and `Color.fromARGB`. That is an allowlist of forbidden syntax,
/// and it misses by construction. Five planted literals, one caught:
///
/// | planted | caught? |
/// | --- | --- |
/// | `Color.from(alpha: 1, red: 0, green: 0, blue: 0)` | **no** |
/// | `Colors.deepOrange` | **no** |
/// | `Colors.pinkAccent.withValues(alpha: 0.5)` | **no** |
/// | `Color(int.parse('FF6C3FE8', radix: 16))` | **no** |
/// | `Color.fromARGB(` split over lines | yes — but only because `dart format` collapses it, and §7 runs the format gate |
///
/// So a split `fromARGB` was caught by the formatter, not by the regex, and the
/// other four spellings walked straight through. Every one of them is a colour
/// that never went through `EvaColors`, which is the entire rule.
///
/// **This version therefore inverts the test: it asks whether each colour in
/// `lib/` resolves through a named source, and fails anything that does not.** A
/// resolution looks like `EvaColors.…`, `EvaStickerPalette.of(StickerSlot.…)`,
/// or `context.colors.…`; everything else — every spelling, computed or literal
/// — is an offender. `Colors.transparent` is admitted as a **(value, value)**
/// pair rather than as a substring, so it cannot carry a Material palette colour
/// along on the same line. The token files and the transcribed prototype tables
/// are exempt as a whole, because that is where a colour is *supposed* to be
/// introduced.
///
/// The cost of inverting is that the exemptions are now file-scoped rather than
/// value-scoped, and that is deliberate: "which file is allowed to introduce
/// colour" is a smaller and more stable question than "which spellings count",
/// and the second test below keeps the exemptions honest.
///
/// ## THE FILES THAT ARE ALLOWED TO INTRODUCE COLOUR
///
/// - `tokens/**` — Phase 1's published token table. That is what a token *is*.
///
/// The transcription sites below are the others, and each is exempt for the
/// same reason: **the value is in the prototype and is not in
/// `03-design-system.md`**, and promoting it into `EvaColors` would put a value
/// into a file that claims to be the spec's token table.
///
/// - `widgets/eva_toggle.dart` — `EvaToggleKnob.color`, one literal, `#FFFFFF`,
///   from `SettingsScreen.tsx:24` (`background: '#ffffff'` on the switch knob).
///   §5.1 publishes no white that means "the handle of a control": `surface` is
///   white in light and near-black in dark, and `ink` is the opposite again, so a
///   knob that followed either would stop reading as a handle on one palette.
/// - `features/home/presentation/widgets/card_washes.dart` — the two glass
///   cards' washes (`eva/redesign.html:519`, `:524`, written as inline
///   `--bh` properties, not rules) and the one `Color(int)` the catalogue's
///   packed `bloomArgb` values are built through. §5.1 publishes no per-card
///   wash; `EvaColors.bloom` is the `var(--bh, …)` **fallback**, and the
///   prototype gives the two cards different values.
/// - `features/journey/presentation/journey_colours.dart` — the journey's own
///   table; see the constant's own doc.
///
/// **The orb transcription is GONE.** `effects/neural_orbs.dart` held the
/// `ORB_CONFIGS` table and the aurora band's `rgba()` stops, and the orbs are
/// retired with the old design's ambient. Its exemption went with the file:
/// an exemption for a file that no longer exists is a hole in the walk, and a
/// hole nobody reads is how a colour ends up in `lib/` unchallenged.
///
/// This test is why the bullets above are decisions rather than leaks: move a
/// colour into a painter and this goes red. And the second test below pins what
/// each exemption holds, so one cannot quietly grow a second colour.
///
/// ## FAIL-CLOSED
///
/// `AGENT_CONTEXT` §7, "a gate that cannot fail is worse than no gate":
///
/// - `lib/` missing → **fail**, naming the path.
/// - a file that cannot be read → **fail**, naming the file.
/// - an empty walk → **fail**. A walk that found nothing proves nothing, and a
///   count of zero over nothing is not a pass.
///
/// ## AND NO EXEMPTION MAY NAME A FILE THAT DOES NOT EXIST
///
/// A stale exemption is a hole with no reader: the walk skips a path that is
/// not in the tree, nothing complains, and the "exemption" is invisible. The
/// second test below therefore asserts that every exempted path is a file on
/// disk — which is what would have caught the orb exemption the moment the orbs
/// were retired.
const String _exemptToggleKnob =
    'lib/core/design_system/widgets/eva_toggle.dart';

/// The Phase-5.2 addition: `/`'s card washes, and the catalogue's through it.
///
/// `eva/redesign.html` writes each glass card's wash as an **inline** custom
/// property, not a rule — `:519` is `style="--bh:rgba(228,87,214,.55)"` on
/// `#votdCard` and `:524` is `style="--bh:rgba(232,176,75,.35)"` — so the
/// values are per-card identity that no token table carries, which is the same
/// shape of fact the card washes' table holds. The file holds the two packed
/// ints and **one** colour construction (`homeCardWash(int)`) that the
/// carousel routes the catalogue's per-book washes through, so the whole screen
/// has one line where a colour is built from a transcription. The second test
/// below pins that count.
const String _exemptCardWashes =
    'lib/features/home/presentation/widgets/card_washes.dart';

/// The Task-5.6 addition: `/journey`'s own colour table.
///
/// `eva/redesign.html` writes the three ring strokes and the four medal washes as
/// **inline** colours on the elements themselves — `:592`'s `stroke:#3EC9B0`,
/// `:594`'s `stroke:#4F74FF`, and `:599-602`'s four `--bh:rgba(…, .5)` — so the
/// values are per-element identity that no token table carries, which is the same
/// shape of fact the card washes' table holds.
///
/// **The one colour that IS a token is not here.** The prototype's magenta
/// (`#E457D6`, `:593` and `:600`) is `EvaColors.bloom`'s exact hue, and the
/// journey's table resolves those two lines through the token rather than
/// transcribing them — so the transcription is four lines, not six, and the
/// alpha difference (the token's 55% against the prototype's 50%) is recorded
/// there.
///
/// The file holds the packed ints and **one** colour construction, so the whole
/// screen has one line where a colour is built from a transcription. The second
/// test below pins that count.
const String _exemptJourneyColours =
    'lib/features/journey/presentation/journey_colours.dart';

/// The files exempt from the rule.
const Set<String> _colourExemptions = <String>{
  _exemptToggleKnob,
  _exemptCardWashes,
  _exemptJourneyColours,
};

/// Where a colour value can *come from*, as syntax.
///
/// This is the trigger, not the rule — it says "this line produces a colour", and
/// the rule below asks whether it came from a token. Keeping the two apart is the
/// whole point of inverting the test: this list is short and stable because
/// Flutter has three colour constructors and one palette namespace, whereas
/// enumerating *literal spellings* was open-ended and missed four of five planted
/// violations.
const List<String> _colourValueMarkers = <String>[
  'Color(', // Color(0xFF6C3FE8), Color(int.parse('FF6C3FE8', radix: 16))
  'Color.', // Color.fromARGB, Color.from, Color.lerp, Color.alphaBlend
  'Colors.', // the Material palette: Colors.deepOrange, Colors.pinkAccent
];

/// Where a colour is allowed to come from.
///
/// The *resolutions*, not the literal spellings. Each is a prefix or an
/// infix-and-call that can only be reached through a published table.
const List<String> _resolutions = <String>[
  'EvaColors.',
  'EvaStickerPalette.of(StickerSlot.',
  'context.colors.',
  'colors.',
];

/// The one entry in Material's palette this design system admits, as a
/// `(marker, allowed value)` **pair** rather than a substring.
///
/// ## WHY A SUBSTRING WAS NOT ENOUGH
///
/// The first version put `'Colors.transparent'` in [_resolutions] and tested it
/// with `line.contains`. That admits the whole **line**, so any Material palette
/// colour riding along on the same line was legal too — and
/// `Color.alphaBlend(Colors.deepOrange, Colors.transparent)` is not a contrived
/// line, it is *the* idiomatic way to fade one colour into nothing. So the
/// rule is now per-**value**: every `Colors.<name>` on the line must be
/// `Colors.transparent` itself.
///
/// `Colors.` is a marker because the Material palette is where an un-tokenable
/// colour sneaks in (`Colors.deepOrange`, `Colors.pinkAccent`). `transparent`
/// is the one entry in that namespace that is not a palette choice at all: it is
/// the *absence* of a fill, which is what `ds.tsx` writes as the bare string
/// `'transparent'` in eight places — the unselected chip, the secondary button,
/// the current bead. Admitting the prefix would admit the palette with it;
/// admitting this exact token admits nothing else.
const String _onlyTransparent = 'Colors.transparent';

/// Every `Colors.<name>` on [line].
///
/// `Colors.` is the marker that produces a colour without a token table, so it
/// is the one that has to be resolved **per occurrence** rather than per line.
final RegExp _materialPaletteValue = RegExp(r'\bColors\.[A-Za-z0-9_]+');

/// The `Color` **constructors** — as opposed to the `Colors.` palette.
///
/// Deliberately excludes `Colors.`: `Colors.transparent` has an `s` after
/// `Color`, so it contains neither `Color(` nor `Color.`, and the distinction
/// the rule below turns on is exactly that one.
const List<String> _colourConstructors = <String>['Color(', 'Color.'];

/// Whether [line] mentions a colour value at all.
bool _producesAColour(String line) => _colourValueMarkers.any(line.contains);

/// Whether the colour on [line] resolved through a published table.
///
/// Two questions, in order:
///
/// 1. does the line carry a `Colors.<name>` that is **not** `Colors.transparent`?
///    If so it is an offender whatever else the line says — this is the check
///    that replaced the whole-line substring test.
/// 2. failing that, does the line resolve through a token table, or is
///    `Colors.transparent` the *whole* of its colour content (no constructor,
///    no palette entry)?
bool _resolvesToAToken(String line) {
  for (final RegExpMatch match in _materialPaletteValue.allMatches(line)) {
    if (match.group(0) != _onlyTransparent) return false;
  }
  if (_resolutions.any(line.contains)) return true;
  return line.contains(_onlyTransparent) &&
      !_colourConstructors.any(line.contains);
}

/// Strips every comment from [source], newlines preserved.
///
/// **Lives in `test/support/project_import_graph.dart`** — see [withoutDartComments]
/// for why, and for the three inputs that cost a real bug each. It is aliased
/// here so the behavioural tests below read the same as they always did.
String _withoutComments(String source) => withoutDartComments(source);

void main() {
  test('every colour under lib/ resolves through a published token table', () {
    final Directory lib = Directory.fromUri(packageRoot.uri.resolve('lib/'));
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'lib/ does not exist — the gate cannot run, so it does not pass.',
    );

    final List<File> files = <File>[];
    try {
      files.addAll(<File>[
        for (final FileSystemEntity entity in lib.listSync(
          recursive: true,
          followLinks: false,
        ))
          if (entity is File && entity.path.endsWith('.dart')) entity,
      ]);
    } on FileSystemException catch (error) {
      fail('lib/ could not be walked: ${error.message}');
    }
    expect(
      files,
      isNotEmpty,
      reason:
          'the walk found no .dart file under lib/. That is not a clean tree.',
    );

    final List<String> offenders = <String>[];
    for (final File file in files) {
      final String relative = packageRelative(file.uri);
      if (relative.startsWith('lib/core/design_system/tokens/')) continue;
      if (_colourExemptions.contains(relative)) continue;

      final String source;
      try {
        source = file.readAsStringSync();
      } on FileSystemException catch (error) {
        fail('$relative could not be read: ${error.message}');
      }

      final List<String> lines = _withoutComments(source).split('\n');
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        final String trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (!_producesAColour(line)) continue;
        if (_resolvesToAToken(line)) continue;
        offenders.add('$relative:${i + 1}: ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'every colour resolves through EvaColors / EvaStickerPalette, or '
          'through one of the transcribed prototype tables this file exempts. '
          'A name this test has never heard of is a colour that never went '
          'through a token table — which is the rule, whichever syntax it '
          'arrives in:\n${offenders.join('\n')}',
    );
  });

  test('and no exemption names a file that is not there', () {
    // A stale exemption is a hole with no reader: the walk skips a path that
    // is not in the tree, nothing complains, and the "exemption" is invisible.
    // The orb exemption outlived `effects/neural_orbs.dart` by exactly the
    // length of the window between the orbs' retirement and this change.
    for (final String path in _colourExemptions) {
      expect(
        File.fromUri(packageRoot.uri.resolve(path)).existsSync(),
        isTrue,
        reason:
            '$path is exempt from the colour rule, so it must exist — an '
            'exemption for a file that is not there is a hole nobody reads',
      );
    }
  });

  test('and the exemptions really do hold the tables they are for', () {
    // Without this the first test could be satisfied by an exemption that grew,
    // or by a file whose tables were moved somewhere the first test does not
    // reach. Both failure modes are the same bug: two homes for one table.
    //
    // The orb table used to be pinned here, and it is gone with the orbs: the
    // file it named is retired, and the exemption that named it went with it.
    //
    // The toggle exemption is a whole *widget file*, which is a much broader
    // licence than a table's — so it is pinned to exactly one colour
    // construction. Without this the exemption would silently become a hole
    // every future widget edit could drop a hex into.
    final String toggle = File.fromUri(
      packageRoot.uri.resolve(_exemptToggleKnob),
    ).readAsStringSync();
    expect(
      _colourValueMarkers
          .expand((String marker) => marker.allMatches(toggle))
          .length,
      1,
      reason:
          'exactly one colour construction in eva_toggle.dart — the knob. A '
          'second one means this file no longer needs its exemption as it is '
          'written, or has grown a colour nobody transcribed.',
    );
    expect(
      'abstract final class EvaToggleKnob'.allMatches(toggle).length,
      1,
      reason: 'the knob colour has one home and one name',
    );

    // The washes' exemption is pinned the same way the knob's is, because it is
    // the same shape of licence: a whole file allowed to construct colour, so
    // the count of constructions has to be exactly the one the doc names.
    final String washes = File.fromUri(
      packageRoot.uri.resolve(_exemptCardWashes),
    ).readAsStringSync();
    expect(
      _colourValueMarkers
          .expand((String marker) => marker.allMatches(washes))
          .length,
      1,
      reason:
          'exactly one colour construction in card_washes.dart — '
          '`homeCardWash(int)`, the one line the catalogue\'s packed washes and '
          'the two cards\' own washes are built through. A second means this '
          'file has grown a colour nobody transcribed.',
    );
    expect(
      'const int homeVotdWashArgb'.allMatches(washes).length,
      1,
      reason: "the day's card's wash, transcribed from `:519`",
    );
    expect(
      'const int homeLastLightWashArgb'.allMatches(washes).length,
      1,
      reason: "the last-light card's wash, transcribed from `:524`",
    );

    // And the journey's, pinned the same way — a whole file allowed to construct
    // colour, so the count of constructions has to be exactly the one the
    // exemption's doc names.
    final String journey = File.fromUri(
      packageRoot.uri.resolve(_exemptJourneyColours),
    ).readAsStringSync();
    // **Stripped first, and the two licences above are not.** Their files
    // happen not to mention a colour construction in prose; this one does — it
    // quotes the prototype's own `stroke:#3EC9B0` and the packed ints it
    // transcribes — and a doc comment that *says* `Color(0x…)` is not a
    // construction. Counting the raw text would count the documentation, and a
    // gate that counts documentation is a gate that fails the moment somebody
    // explains the table properly.
    final String journeyCode = _withoutComments(journey);
    expect(
      _colourValueMarkers
          .expand((String marker) => marker.allMatches(journeyCode))
          .length,
      1,
      reason:
          'exactly one colour construction in journey_colours.dart — '
          '`_journeyColour(int, double)`, the one line the four transcribed '
          'values are built through. A second means this file has grown a colour '
          'nobody transcribed.',
    );
    expect(
      'Color _journeyColour(int argb, double alpha)'
          .allMatches(journeyCode)
          .length,
      1,
      reason: 'the construction has one home and one name',
    );
    // **And the number of TRANSCRIBED COLOURS, which the construction count
    // does not catch.** A fifth colour added as a packed int and a getter
    // through the same `_journeyColour` would leave the construction count at
    // one and the file still exempt — so the count that matters is the number
    // of packed ints, and it is pinned here. The card washes' precedent pins
    // its two ints **by name**; this pins both the count and the names.
    expect(
      'const int journey'.allMatches(journeyCode).length,
      4,
      reason:
          'exactly four transcribed colours in journey_colours.dart — the teal, '
          'the blue, the cream and the amber. The magenta is NOT here: it is '
          '`EvaColors.bloom`, the prototype\'s hue exactly, so it resolves '
          'through the token. A fifth packed int is a colour nobody transcribed.',
    );
    for (final String name in <String>[
      'journeyTealArgb',
      'journeyBlueArgb',
      'journeyCreamArgb',
      'journeyAmberArgb',
    ]) {
      expect(
        'const int $name'.allMatches(journeyCode).length,
        1,
        reason:
            '`$name` is transcribed once, from its own prototype line. A rename '
            'or a removal is caught here rather than by a reader.',
      );
    }
  });

  test('the resolution list itself is not a hole', () {
    // `_resolutions` decides what "resolved" means, so a resolution wide enough
    // to admit anything would silence the gate completely. Each entry has to
    // name a published table, and `colors.` is the one bare identifier here — it
    // is safe only because `EvaColors` publishes a field of that name and every
    // call site writes `colors.` off a `final EvaColors colors = context.colors`.
    expect(_resolutions, contains('EvaColors.'));
    expect(_resolutions, contains('EvaStickerPalette.of(StickerSlot.'));
    // A bare `Color(` construction is never a resolution.
    expect(_resolvesToAToken('final c = Color(0xFF6C3FE8);'), isFalse);
    expect(_resolvesToAToken('final c = Colors.deepOrange;'), isFalse);
    expect(
      _resolvesToAToken('final c = context.somethingElse.deepOrange;'),
      isFalse,
    );
    expect(_resolvesToAToken('final c = EvaColors.dark().ember;'), isTrue);
  });

  group('the transparent exemption is one token, not a prefix', () {
    // The `Colors.transparent` entry above is the whole reason a widget may write
    // a bare `Colors.` value. If it ever widened to `Colors.`, every Material
    // palette colour in `lib/` would become legal and the gate would be inert.
    test('admits `Colors.transparent`', () {
      expect(_resolvesToAToken('final c = Colors.transparent;'), isTrue);
    });

    test('admits nothing else from the Material palette', () {
      for (final String spelling in const <String>[
        'Colors.deepOrange',
        'Colors.pinkAccent',
        'Colors.red',
        'Colors.black',
        'Colors.white',
      ]) {
        expect(
          _resolvesToAToken('final c = $spelling;'),
          isFalse,
          reason: '$spelling is a palette choice, not an absence of one',
        );
      }
    });

    test('and it is not a hall pass for a palette colour on the same line', () {
      // The planted evasion, kept as the negative control for the per-value rule
      // above. `_resolutions` used to be tested with `line.contains`, so a line
      // mentioning `Colors.transparent` anywhere was legal **in full** — and this
      // is the idiomatic way to fade a colour into nothing, so it is a realistic
      // edit rather than a contrived one. `Colors.deepOrange` is the Material
      // palette and resolves through nothing.
      expect(
        _resolvesToAToken(
          'final c = Color.alphaBlend(Colors.deepOrange, Colors.transparent);',
        ),
        isFalse,
      );
      expect(
        _resolvesToAToken('dot: Colors.transparent, glow: Colors.pinkAccent,'),
        isFalse,
        reason: 'the second `Colors.` on the line is what fails it',
      );
      // The control: the same call with both ends legal resolves.
      expect(
        _resolvesToAToken(
          'final c = Color.alphaBlend(colors.ink, Colors.transparent);',
        ),
        isTrue,
        reason: 'the token end is admitted; the palette end is not',
      );
    });
  });

  group('the comment scanner', () {
    // L3. The previous version filtered `///` and `//` per line and nothing
    // else, so a `/* … */` block quoting the prototype's hexes was read as
    // production code — which is precisely what the doc comments above are for.
    test('a block comment is not mistaken for code', () {
      expect(
        _withoutComments('final a = 1;\n/* Color(0xFF6C3FE8) */\nfinal b = 2;'),
        isNot(contains('Color')),
      );
    });

    test('nested block comments are not mistaken for code', () {
      // Dart nests block comments and a regex ends at the inner `*/`, leaving
      // the tail of the comment looking like code.
      expect(
        _withoutComments('/* outer /* nested Color(0xFF00FF00) */ still */'),
        isNot(contains('Color')),
      );
    });

    test('an apostrophe in a doc comment does not swallow the next comment', () {
      // The bug that forced the rewrite, kept as a negative control. A scanner
      // that handled block comments and single-quoted strings but not `//`
      // read `/// … the prototype's hexes` as opening a string literal; the `'` in
      // the *following* comment closed it, so the block comment between them was
      // emitted verbatim and the gate flagged its own documentation.
      const String source = """
/// A doc comment about the prototype's hexes.
/*
  Color(0xFF6C3FE8) is the Login orb's violet.
*/
final Color color = EvaColors.dark().ember;
""";
      final String stripped = _withoutComments(source);
      expect(stripped, isNot(contains('Color(0x')));
      expect(stripped, contains('EvaColors'));
    });

    test('a line comment is stripped without eating the newline', () {
      // Line numbers in a failure message have to match the file on disk.
      const String source = '// Color(0xFF6C3FE8)\nfinal a = 1;\n';
      expect(_withoutComments(source), '\nfinal a = 1;\n');
    });

    test('a string literal is kept, because it is code-adjacent at worst', () {
      expect(
        _withoutComments("final s = 'Color(0xFF6C3FE8)';"),
        contains('Color(0x'),
        reason:
            'a string that names a colour is reported, not silently dropped — '
            'the gate would then say why, which is diagnosable; hiding it is not',
      );
      expect(
        _withoutComments("final s = r'Color(0xFF00FF00)';"),
        contains('Color(0x'),
      );
    });

    test('a triple-quoted string is one string, not three', () {
      // `'''` has to be decided as a three-character delimiter before the scan
      // starts, or it reads as an empty string followed by a stray quote — and
      // then the `//` on the next line is stripped as a comment instead of kept
      // as string content, and the terminator is found early.
      const String source = """
const String doc = '''
Color(0xFF6C3FE8) in prose
// this is string content, not a comment
''';
final Color c = EvaColors.dark().ember;
""";
      final String stripped = _withoutComments(source);
      expect(
        stripped,
        contains('// this is string content, not a comment'),
        reason: 'a `//` inside a triple-quoted string is content',
      );
      expect(
        stripped,
        contains('EvaColors'),
        reason:
            'and the code after the terminator is still scanned, which is the '
            'proof that the three-character delimiter was consumed whole',
      );
    });

    test(
      'an unbalanced scan fails closed instead of reporting a clean tree',
      () {
        expect(
          () => _withoutComments('final a = 1; /* never closed\n'),
          throwsA(isA<StateError>()),
        );
        expect(
          () => _withoutComments("final s = 'never closed;\n"),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('stripping must not eat code outside the comments', () {
      expect(
        _withoutComments('final c = EvaColors.dark().ember;'),
        contains('EvaColors'),
      );
    });
  });
}
