/// The Arabic-Indic (Eastern Arabic) digits, U+0660…U+0669.
///
/// ## WHY THIS IS A DOMAIN FUNCTION AND NOT AN INLINE `switch`
///
/// §6: a widget's conditionals are not where logic lives. The alternative —
/// spelling the ten digits at the two call sites (the AR verse marker and the AR
/// CTA caption) — would put a ten-arm table in the presentation layer twice, and
/// the second copy is the one a translator's change would miss.
///
/// It is in `features/reading/domain/` rather than the design system because
/// **nothing outside this feature renders Arabic numerals**: the settings screen
/// has no numeric input, and `ProgressBeads` draws dots rather than digits. §3's
/// placement test puts a type used by one feature in that feature.
///
/// ## AND WHY THE ARABIC ARM USES THEM AT ALL
///
/// `ReadingArScreen.tsx:49` and `:86` — the prototype writes `١`…`٧` for the verse
/// numbers and `٥` for the question count. Transcribing them is the faithful
/// reading, and it is also the reason the glyph gate is load-bearing rather than
/// ceremonial: **U+0665 is an Arabic-block codepoint**, so a caption rendering `٥`
/// in Space Mono is tofu for exactly the same reason the scripture is. A gate that
/// only checked the passage's body would have passed while the caption beside it
/// was six boxes.
///
/// `font_coverage_test.dart` measures the glyph coverage of all five bundled
/// families against these codepoints, which is what turns "Arabic never uses the
/// mono family" from a style rule into a checkable one.
library;

/// [value] written in Arabic-Indic digits.
///
/// **Total for every `int`, including negative and zero**, because a rendering
/// helper that throws on a number the server sent is the defect decision 40
/// measures: the exception leaves `build` and takes the rest of the row with it.
/// A negative verse number is nonsense, and `-٣` is the least surprising way to
/// show nonsense.
///
/// Zero is `٠` and not `۰` (U+06F0, the **Extended** Arabic-Indic digits): the
/// prototype's `١٢٣٤٥٦٧` and `٥` are U+0661…U+0667 and U+0665 — the Persian-set
/// forms every Arabic-script keyboard produces — and `font_coverage_test.dart`
/// pins that choice against the bundled `Amiri`.
String arabicIndicDigits(int value) {
  final bool negative = value < 0;
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer();
  if (negative) out.write('-');
  for (final int unit in digits.codeUnits) {
    out.writeCharCode(_arabicIndicZero + (unit - _asciiZero));
  }
  return out.toString();
}

/// U+0030, the ASCII digit zero the `int`'s own `toString` produces.
const int _asciiZero = 0x30;

/// U+0660, ARABIC-INDIC DIGIT ZERO.
///
/// A **named constant and not the digit written out**, because the function above
/// reads `_arabicIndicZero + (unit - _asciiZero)` and a bare `٠` there would be an
/// invisible character in the source that only a reader comparing codepoints could
/// check. `arabic_digits_test.dart` asserts the value.
const int _arabicIndicZero = 0x0660;
