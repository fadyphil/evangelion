/// One passage's first character, and everything after it.
///
/// The pair `PassageDropCap` is handed: the `letter` it enlarges and hangs from the
/// first baseline, and the `rest` the paragraph wraps around it.
typedef DropCapText = ({String letter, String rest});

/// [text] split at its first **rune**: the drop cap's [DropCapText.letter] and the
/// [DropCapText.rest].
///
/// ## WHY THIS IS DOMAIN LOGIC AND NOT A `substring` IN A WIDGET
///
/// AGENT_CONTEXT §6: "if a widget needs a conditional or calculation, extract it to
/// a cubit or a pure function and TDD that." This is a UTF-16 index into text that
/// came off the wire, which is precisely the thing §6 means, and it has bitten
/// **twice** — once per screen.
///
/// ## THE DEFECT, MEASURED
///
/// `String.substring` indexes **UTF-16 code units**, not characters. A character
/// above U+FFFF is two of them, so `substring(0, 1)` on `'\u{1F600}'` returns the
/// **high surrogate alone** — measured `codeUnits == [55357]`. That is not a
/// truncated emoji; it is not a character at all. `RenderParagraph` then throws
/// `ArgumentError: string is not well-formed UTF-16` out of
/// `_RenderScaledInlineWidget.performLayout`, and because the drop cap is a
/// `WidgetSpan` **inside the first paragraph**, the throw takes the passage, the
/// header, the metadata row and both CTAs with it.
///
/// **And the second half of the same bug was a truncation, not an index.** `previewText`
/// cuts at a budget too, so an emoji anywhere in the first 56 code units of verse one
/// put a lone surrogate into `/`'s preview — a wider surface than `/reading`'s, which
/// only fails at index 0. That half is fixed where the cut is
/// (`features/home/domain/preview_text.dart`); this is the first-rune half.
///
/// ## AND `isEmpty` WAS NOT ENOUGH, IN EITHER DIRECTION
///
/// Phase 6's C3 fix guarded `text.isEmpty` and its doc asserted the reader "can
/// still reach the reflection". True, and incomplete: `' ‹Verily…'` is not empty,
/// its first character is a space, and a space enlarged to 146.6 logical px is an
/// **invisible glyph** — the largest element on the screen rendering nothing. A
/// leading tab is the same. So the cut is on the first **non-space** rune, and the
/// whitespace goes with it: the paragraph must not open with an indent the cap has
/// already moved past.
///
/// **Only leading whitespace.** The tail belongs to the paragraph, and dropping it
/// here would be the client editing scripture.
///
/// ## AND NOT ON A LEADING COMBINING MARK, WHICH IS A **RECORDED** NON-FIX
///
/// `'́Verily'` — a bare U+0301 before the word — would still make an enlarged accent
/// the cap. Stripping marks is a **shape test**, and recorded decision 29 rejects one
/// for this exact widget for a measured reason: it breaks on a verse opening with a
/// numeral or a bracket, and §5's live payload opens one behind a `‹Verily`. The
/// branch here is on [language], not on the text, and this function does not
/// introduce a second rule that contradicts it. A leading mark is not whitespace and
/// this client does not guess which of the two it is looking at.
///
/// ## AND IT IS **TOTAL**, WHICH IS THE PART NO CALLER CAN FORGET
///
/// `''` and `'   '` both give `(letter: '', rest: '')`. A caller that checks
/// `letter.isEmpty` is asking the right question — "did we choose a character?" —
/// rather than the wrong one, and there is no input for which this throws.
///
/// **The one thing it cannot repair** is a `String` that arrived **already**
/// malformed: `runes` yields an unpaired surrogate, `String.fromCharCode` re-emits
/// it, and the glyph is still unpaired. Dart's own JSON decoder is what produces
/// well-formed strings, so that is a payload this client has to be handed rather
/// than one it can read, and the honest claim is "total over the strings a
/// [ScriptureText] can carry" rather than "total over every `String` that exists".
DropCapText splitDropCap(String text) {
  // `trimLeft` and not `trim`: see the doc's "only leading whitespace".
  final String trimmed = text.trimLeft();
  if (trimmed.isEmpty) return (letter: '', rest: '');

  // **`runes.first` and not `substring(0, 1)`.** An astral rune is two code units
  // and `String.fromCharCode` re-encodes the whole rune, so this is the character.
  // The measured `fromCharCode(0x1F600).codeUnits` is `[55357, 56832]` — length 2,
  // which is also why the `substring` below uses the letter's **length** rather
  // than a hard-coded 1.
  final String letter = String.fromCharCode(trimmed.runes.first);
  return (letter: letter, rest: trimmed.substring(letter.length));
}
