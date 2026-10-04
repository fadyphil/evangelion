/// Today's reading's preview, cut to a length a panel can show.
///
/// ## WHY THIS IS DOMAIN LOGIC AND NOT A `substring` IN THE WIDGET
///
/// AGENT_CONTEXT §6: "if a widget needs a conditional or calculation, extract it
/// to a cubit or a pure function and TDD that." A truncation with an ellipsis and
/// a word boundary is three decisions, and the only one that could be wrong is the
/// one a widget cannot show you: **cutting a word in half and appending `…`**.
///
/// ## WHY THE CUT LANDS ON A SPACE
///
/// Because `There was a man of the Pharisees, named` is a phrase and
/// `There was a man of the Pharise` is a typo. The live first verse is 71
/// characters, so this function does run on every English preview.
///
/// **It said 79, and 79 was wrong.** Measured: the payload's
/// `verses[0].text_clean` is
/// `There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:` —
/// **71** code units, and `home_page_test.dart` has had the right number all along.
/// The cost was not cosmetic: at 79 the "so this always runs" claim still held, but
/// a reader checking the arithmetic found a verse eight characters longer than the
/// one they could see, and §9's rule is that a stated number is a claim about
/// something, not an illustration of the idea.
///
/// The rule is: take at most [maxChars] code units, then **back up to the last
/// space** if there is one in the final fifth of what was taken. That fifth is the
/// interesting part — without it, a passage whose 56th character happens to sit
/// mid-clause would be cut back 20 characters to reach a space, and a passage with
/// no space at all in its last 11 characters would be cut back to the beginning.
/// The cost is that the result can be shorter than [maxChars]; a preview that is a
/// little short is fine and a preview that ends mid-word is not.
///
/// ## THE ELLIPSIS IS ONE CHARACTER AND IT IS **THE** ELLIPSIS
///
/// `…` (U+2026 HORIZONTAL ELLIPSIS), not `...`. The prototype's own preview ends
/// in a literal `…` (`HomeScreen.tsx:57`) and §5's payloads contain real `…` inside
/// quoted scripture, so the app already renders this glyph. Appending three dots
/// would be a second, invisible-to-the-eye ellipsis in the same app.
const String kPreviewEllipsis = '…';

/// How much of the first verse a panel shows before cutting.
///
/// `HomeScreen.tsx:57`'s preview is
/// `"n the beginning God created the heavens and the earth…"` — 53 characters of
/// text plus the ellipsis, and 54 with the drop cap's `I` split off. So 56 is the
/// prototype's own budget with room for the smallest possible difference, and it
/// is a declared constant rather than a literal at the call site because a reader's
/// screen width is not a number this function should be guessing.
const int kPreviewMaxChars = 56;

/// How far back from the cut a space is acceptable, as a fraction of [maxChars].
///
/// The final fifth — 11 characters at the default 56. Named because "why 20%" is
/// the question the first version's hard-coded `20` could not answer.
const double kPreviewBoundaryFraction = 0.2;

/// [text] cut to [maxChars] and suffixed with [kPreviewEllipsis].
///
/// ## WHAT COUNTS AS A CHARACTER HERE, AND WHY IT IS A CODE UNIT
///
/// `String.length`, so a code unit. The full stop on the **Arabic** arm would
/// therefore count as two — and it does, deliberately: the preview's job is to fit
/// a panel, and a code point that occupies two cells occupies two cells on screen.
/// The alternative (`characters`, from `package:characters`) is already a
/// transitive dependency of `flutter`, and promoting it would be an unlisted
/// dependency change under §8.4.
///
/// The consequence is stated rather than left to be discovered: an Arabic preview
/// can end a few code units short of [maxChars], and one can be cut at a combining
/// mark. Neither is visible at 17px, and Phase 7 — which renders whole paragraphs
/// rather than a preview — is the phase that would care.
///
/// ## AND THE CUT IS **NEVER** BETWEEN THE TWO HALVES OF AN ASTRAL CHARACTER
///
/// Being a code-unit budget is fine; being **half a character** is not. `substring(0,
/// maxChars)` on `'x' * 55 + '\u{1F600}'` at the default 56 leaves U+D83D — the
/// emoji's **high surrogate** — as the last unit, and that is not a truncated emoji,
/// it is not a character, and `RenderParagraph` throws `ArgumentError: string is not
/// well-formed UTF-16` on it out of
/// `_RenderScaledInlineWidget.performLayout`. Because the panel's two controls are
/// the `_Preview`'s own children, `Continue` → `/reading` and `Start reflection` →
/// `/quiz` both disappear with it.
///
/// **The surface is wider than the drop cap's.** `splitDropCap`'s identical bug is
/// reachable only at index 0 of a verse; this one is reachable at **any** offset
/// inside the first 56 code units of verse one, so an emoji anywhere in the opening
/// of today's reading — not only at its start — is what puts a lone surrogate into
/// `/`'s preview.
///
/// So the budget is spent in whole characters: if the last unit taken is a high
/// surrogate, it is given back and the preview is one code unit shorter. The cost is
/// stated because it is real and invisible: **55 characters and a half** is not a
/// preview length, and §9's rule is that a number in a doc is a claim about
/// something. The alternative — spending *more* than the budget to keep the pair —
/// is worse: a preview that overflows its panel is visible, and one that is short is
/// not.
///
/// **And the guard runs before the word-boundary back-up**, because that is the
/// order that makes the fix total: the boundary search runs on [taken], and a
/// dangling surrogate is not a space, so a text with spaces either loses it by
/// accident or keeps it. Guarding afterwards would be a fix that works on some
/// inputs.
String previewText(String text, {int maxChars = kPreviewMaxChars}) {
  if (text.length <= maxChars) {
    return text;
  }
  String taken = text.substring(0, maxChars);
  // A high surrogate (U+D800–U+DBFF) is legal in `taken` only when the **next**
  // unit is a low surrogate (U+DC00–U+DFFF). The next unit is beyond the cut, so a
  // high surrogate in the last position is always the first half of a pair this
  // function just cut in half.
  if (isHighSurrogate(taken.codeUnits.last)) {
    taken = taken.substring(0, taken.length - 1);
  }
  final int floor = maxChars - (maxChars * kPreviewBoundaryFraction).floor();
  final int lastSpace = taken.lastIndexOf(' ');
  final String body = lastSpace >= floor
      ? taken.substring(0, lastSpace)
      : taken;
  return '$body$kPreviewEllipsis';
}

/// Whether [codeUnit] is a UTF-16 **high** surrogate — U+D800 through U+DBFF.
///
/// A named predicate rather than a literal comparison at the one call site, because
/// "the first half of a surrogate pair" is the concept and `0xD800` is not, and
/// because a reader who has to re-derive the range will get it wrong.
bool isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
