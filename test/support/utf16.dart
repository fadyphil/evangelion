/// Well-formedness of a `String` as UTF-16, and the code units responsible.
///
/// ## WHY A HELPER AND NOT `runes.length == length`
///
/// The first version of these assertions used `value.runes.length == value.length`
/// as the well-formedness test, and it is **wrong in the exact case it was written
/// for**: `runes` yields an unpaired surrogate as a rune of its own, so a string
/// holding half an emoji satisfies it. Measured: `'\u{1F600}'.substring(0, 1)` has
/// `runes.length == 1` and `length == 1`, and is not renderable — `RenderParagraph`
/// throws `ArgumentError: string is not well-formed UTF-16` on it.
///
/// So this is the real check: walk the **code units**, and a high surrogate is only
/// legal when the unit after it is a low surrogate.
library;

/// Whether [text] is well-formed UTF-16: every surrogate is part of a pair.
///
/// The question `RenderParagraph` asks, asked here so a test can ask it before the
/// framework does.
bool isWellFormedUtf16(String text) {
  final List<int> units = text.codeUnits;
  for (int i = 0; i < units.length; i++) {
    final int unit = units[i];
    if (_isHighSurrogate(unit)) {
      // A high surrogate must be followed by a low one, and there must be one.
      if (i + 1 >= units.length) return false;
      final int next = units[i + 1];
      if (!_isLowSurrogate(next)) return false;
      i++;
    } else if (_isLowSurrogate(unit)) {
      // A low surrogate with nothing above it is an orphan.
      return false;
    }
  }
  return true;
}

/// Every unpaired surrogate code unit in [text], as `U+XXXX`, for a failure reason.
///
/// Named rather than inlined because a failure that says only "not well-formed"
/// makes the reader go and find which of the four candidates it was — and in every
/// case measured in this phase the answer was a lone U+D83D, which is the high half
/// of one specific emoji.
List<String> unpairedSurrogates(String text) {
  final List<int> units = text.codeUnits;
  final List<String> orphans = <String>[];
  for (int i = 0; i < units.length; i++) {
    final int unit = units[i];
    if (_isHighSurrogate(unit)) {
      if (i + 1 < units.length && _isLowSurrogate(units[i + 1])) {
        i++;
        continue;
      }
      orphans.add(_hex(unit));
    } else if (_isLowSurrogate(unit)) {
      orphans.add(_hex(unit));
    }
  }
  return orphans;
}

/// Whether [codeUnit] is a UTF-16 **high** surrogate, U+D800–U+DBFF.
bool isHighSurrogate(int codeUnit) => _isHighSurrogate(codeUnit);

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

String _hex(int unit) =>
    'U+${unit.toRadixString(16).toUpperCase().padLeft(4, '0')}';
