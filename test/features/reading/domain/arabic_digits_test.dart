import 'package:evangelion/features/reading/domain/arabic_digits.dart';
import 'package:flutter_test/flutter_test.dart';

/// `arabicIndicDigits` — red-first (AGENT_CONTEXT §6: domain logic).
///
/// ## WHY THE EXACT CODEPOINTS AND NOT "some Arabic digits"
///
/// The two Unicode blocks are not interchangeable and a test that only checked
/// "the string is not ASCII" would pass for either:
///
/// | block | range | used by |
/// | --- | --- | --- |
/// | Arabic-Indic | U+0660–U+0669 | the prototype, and every Arabic-script keyboard |
/// | Extended Arabic-Indic (Persian) | U+06F0–U+06F9 | Persian and Urdu |
///
/// `ReadingArScreen.tsx:49` writes `١`…`٧` and `:86` writes `٥`, which are the
/// first block. A rewrite to the second block renders correctly in Arabic and
/// would be invisible to a reader who does not check codepoints, so the test below
/// asserts the exact `int` values.
void main() {
  test('maps 0…9 to U+0660…U+0669, and nothing else', () {
    expect(
      arabicIndicDigits(0),
      '٠',
      reason: 'U+0660 — and not U+06F0, which is the Persian set',
    );
    expect(arabicIndicDigits(1), '١');
    expect(arabicIndicDigits(2), '٢');
    expect(arabicIndicDigits(3), '٣');
    expect(arabicIndicDigits(4), '٤');
    expect(arabicIndicDigits(5), '٥');
    expect(arabicIndicDigits(6), '٦');
    expect(arabicIndicDigits(7), '٧');
    expect(arabicIndicDigits(8), '٨');
    expect(arabicIndicDigits(9), '٩');
  });

  test('is a per-digit mapping, so a multi-digit number keeps its places', () {
    expect(arabicIndicDigits(10), '١٠');
    expect(arabicIndicDigits(12), '١٢');
    expect(arabicIndicDigits(35), '٣٥');
    expect(arabicIndicDigits(119), '١١٩');
    // Five verses is the live John 3 count and the number the AR caption shows
    // when the reading carries one question.
    expect(arabicIndicDigits(5), '٥');
  });

  test('is total for negatives and for very large values', () {
    expect(arabicIndicDigits(-1), '-١');
    expect(arabicIndicDigits(-42), '-٤٢');
    expect(arabicIndicDigits(1000000), '١٠٠٠٠٠٠');
  });

  test('produces only Arabic-Indic codepoints and an optional minus', () {
    for (final int value in <int>[
      0,
      1,
      7,
      9,
      10,
      42,
      99,
      100,
      1234,
      -5,
      -100,
      987654321,
    ]) {
      for (final int unit in arabicIndicDigits(value).codeUnits) {
        expect(
          unit,
          anyOf(0x2D, inInclusiveRange(0x0660, 0x0669)),
          reason:
              'U+${unit.toRadixString(16).toUpperCase()} from $value — a '
              'digit outside the block, or outside U+0660…U+0669',
        );
      }
    }
  });
}
