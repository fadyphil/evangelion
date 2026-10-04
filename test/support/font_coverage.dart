/// A `.ttf`'s `cmap`, read with `dart:io` and nothing else.
///
/// ## WHY THIS EXISTS, AND WHY IT IS NOT A GOLDEN
///
/// `01-source-analysis.md`'s defect **#2** is "Arabic rendered in Space Mono — Space
/// Mono has no Arabic glyphs". A golden **cannot** catch it: a golden captures
/// whatever the widget currently renders, which is exactly the tofu, and a golden
/// captured with the tofu in it ratifies the defect (recorded decision 8).
///
/// The gate that can catch it is arithmetic: **which bundled family carries which
/// codepoint.** `pubspec.yaml` declares five families from twenty `.ttf` files, each
/// with a `cmap` table mapping Unicode codepoints to glyphs, and "does Space Mono have
/// a glyph for U+0665" is a question that table answers exactly.
///
/// ## WHY A PARSER RATHER THAN A FIXTURE LIST
///
/// The obvious shortcut is a hard-coded list of "families that support Arabic". That
/// list would be a second copy of the truth — the truth being twenty font files — and
/// it would survive a font being replaced with one that has no Arabic at all. Reading
/// the `cmap`s means the answer is a property of the shipped assets, so **replacing a
/// font is what makes the gate red**, which is the event the gate exists for.
///
/// `fontTools` is not available (no `dart:io`-only dependency may be added, §8.4), so
/// this is a hand-rolled reader of the two `cmap` subtable formats a bundled font
/// actually uses: format 4 (segmented, BMP) and format 12 (segmented, full range).
/// Anything else is reported as unreadable rather than as "no glyphs", because a
/// silent empty set would make every coverage assertion vacuously true — §7's "a gate
/// that cannot fail is worse than no gate".
library;

import 'dart:io';
import 'dart:typed_data';

/// Every codepoint [family]'s `.ttf` files declare a glyph for.
///
/// **Union across the family's files.** A family is `Amiri-Regular`,
/// `Amiri-Bold` and `Amiri-Italic`, and a glyph can be in one weight and not another.
/// Unioning means the gate asks "could this family render this character at some
/// weight", which is the question a `fontFamily:` name asks the engine.
Set<int> codepointsForFamily(String family) {
  final Set<int> found = <int>{};
  final List<File> files =
      Directory('assets/fonts')
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.split('/').last.startsWith('$family-'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    throw StateError(
      'assets/fonts holds no file for the family `$family`. The glyph gate cannot '
      'answer "can this family render Arabic" for a family that is not bundled, and '
      'returning an empty set would make every coverage assertion pass vacuously.',
    );
  }

  for (final File file in files) {
    found.addAll(_codepointsIn(file));
  }
  return found;
}

/// The five families `pubspec.yaml` declares, by their `family:` keys.
///
/// **Spelled as the `family:` keys and not as the file-name stems**, because those
/// two differ on four of the five — `DMSans` vs `DMSans`, `CormorantGaramond`,
/// `EBGaramond`, `SpaceMono`, `Amiri` — and the engine matches `TextStyle.fontFamily`
/// against the `family:` string exactly. `eva_typography.dart` says the same in its own
/// words: "a name that merely looks right resolves to the fallback font with no error
/// at all".
const List<String> kBundledFontFamilies = <String>[
  'Amiri',
  'CormorantGaramond',
  'DMSans',
  'EBGaramond',
  'SpaceMono',
];

/// U+0600, the first codepoint of the Arabic block.
const int kArabicBlockStart = 0x0600;

/// U+06FF, the last codepoint of the Arabic block.
const int kArabicBlockEnd = 0x06FF;

/// U+0660, ARABIC-INDIC DIGIT ZERO — the block §5's Arabic payload and this
/// project's `arabicIndicDigits` both use.
const int kArabicIndicDigitStart = 0x0660;

/// U+0669, ARABIC-INDIC DIGIT NINE.
const int kArabicIndicDigitEnd = 0x0669;

/// Whether [family] carries a glyph for **every** codepoint in [codepoints].
///
/// The question the gate asks, stated once so the assertion and the report say the
/// same thing: not "does it cover Arabic" but "can it render **these** characters",
/// which is the only question that matters for a specific string on a specific screen.
bool familyCovers(String family, Iterable<int> codepoints) {
  final Set<int> available = codepointsForFamily(family);
  return codepoints.every(available.contains);
}

/// The codepoints in [file]'s `cmap`, across every subtable.
///
/// **All subtables are unioned**, not just the "best" one. The convention is to
/// prefer a `(3, 10)` Unicode full-repertoire subtable, but a font may legitimately
/// split coverage across `(3, 1)` and `(1, 0)` — and a gate that silently read only
/// one of them would report a *missing* glyph that the engine would have found.
Set<int> _codepointsIn(File file) {
  final Uint8List bytes = file.readAsBytesSync();
  final ByteData data = ByteData.sublistView(bytes);

  // `'ttcf'` — a TrueType **collection**, whose first table directory is at an
  // offset in the header. Every bundled asset is a plain sfnt, and a collection is
  // handled because the alternative is a silent misread of a file someone drops in.
  // `_fourCc` builds the int **little-endian** from four bytes, so `'ttcf'` is
  // `0x66637474` and the two plain-sfnt versions are `0x00000100` (`1.0`) and
  // `'true'` (`0x65757274`).
  final int sfnt = switch (_fourCc(data, 0)) {
    0x66637474 => data.getUint32(12),
    _ => 0,
  };
  final int tableCount = data.getUint16(sfnt + 4);
  int? cmapOffset;
  for (int i = 0; i < tableCount; i++) {
    final int record = sfnt + 12 + 16 * i;
    // `'cmap'` little-endian: `0x63 | 0x6D << 8 | 0x61 << 16 | 0x70 << 24`.
    if (_fourCc(data, record) == 0x70616D63) {
      cmapOffset = data.getUint32(record + 8);
      break;
    }
  }
  if (cmapOffset == null) {
    throw StateError(
      '${file.path} has no `cmap` table, so it cannot be asked '
      'whether it carries a glyph. Refusing rather than returning nothing.',
    );
  }

  final int subtableCount = data.getUint16(cmapOffset + 2);
  final Set<int> found = <int>{};
  bool readAny = false;
  for (int i = 0; i < subtableCount; i++) {
    final int record = cmapOffset + 4 + 8 * i;
    final int offset = cmapOffset + data.getUint32(record + 4);
    final int format = data.getUint16(offset);
    if (format == 4) {
      _readFormat4(data, offset, found);
      readAny = true;
    } else if (format == 12) {
      _readFormat12(data, offset, found);
      readAny = true;
    }
  }
  if (!readAny) {
    throw StateError(
      '${file.path} declares no `cmap` subtable in format 4 or 12, which are the '
      'only two this reader understands. Adding a third format means adding a reader '
      'here — returning an empty set instead would make every coverage assertion pass '
      'vacuously.',
    );
  }
  return found;
}

/// `cmap` format 4 — segmented mapping, BMP only.
void _readFormat4(ByteData data, int offset, Set<int> into) {
  final int segCountX2 = data.getUint16(offset + 6);
  final int segCount = segCountX2 ~/ 2;
  final int endBase = offset + 14;
  final int startBase = endBase + segCountX2 + 2;
  for (int i = 0; i < segCount; i++) {
    final int end = data.getUint16(endBase + 2 * i);
    final int start = data.getUint16(startBase + 2 * i);
    // `0xFFFF` is the required final sentinel segment and is not a range.
    if (end == 0xFFFF) continue;
    for (int cp = start; cp <= end; cp++) {
      into.add(cp);
    }
  }
}

/// `cmap` format 12 — segmented mapping, full Unicode range.
void _readFormat12(ByteData data, int offset, Set<int> into) {
  final int groupCount = data.getUint32(offset + 12);
  for (int i = 0; i < groupCount; i++) {
    final int group = offset + 16 + 12 * i;
    final int start = data.getUint32(group);
    final int end = data.getUint32(group + 4);
    for (int cp = start; cp <= end; cp++) {
      into.add(cp);
    }
  }
}

/// The four ASCII bytes at [offset], packed **little-endian**.
///
/// So `'cmap'` is `0x70616D63` and `'true'` is `0x65757274` — the *byte-reversed*
/// spellings, which is the easiest place in this file to be wrong by hand and the
/// reason the constants carry their ASCII next to them.
int _fourCc(ByteData data, int offset) =>
    data.getUint8(offset) |
    (data.getUint8(offset + 1) << 8) |
    (data.getUint8(offset + 2) << 16) |
    (data.getUint8(offset + 3) << 24);
