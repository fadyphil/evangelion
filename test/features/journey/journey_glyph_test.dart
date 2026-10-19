import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/font_coverage.dart';

/// The glyphs `/journey` draws, and the families that carry them.
///
/// ## WHY THIS FILE EXISTS
///
/// The redesign writes four of the journey's marks as **characters**:
///
/// | the prototype's | codepoint | where |
/// | --- | --- | --- |
/// | `✦` | U+2726 | `:599` — the first-light medal |
/// | `❧` | U+2767 | `:600` — the psalmist medal |
/// | `✠` | U+2720 | `:601` — the streak ×7 medal |
/// | `☩` | U+2629 | `:602` — the john medal |
/// | `⚙` | U+2699 | `:582` — the settings button |
///
/// **A browser draws all five**, because a browser has the whole system font
/// library. **This client does not**: `pubspec.yaml` declares five families and
/// no other may be added, so a character that is in none of them is a tofu box
/// in every arm.
///
/// So the question is not "which of these look right" but "**which of these can
/// this client draw at all**", and that is arithmetic over the bundled fonts'
/// `cmap` tables. `test/support/font_coverage.dart` is the reader — it parses
/// formats 4 and 12 and **refuses rather than returning an empty set**, because
/// a silent empty set makes every coverage assertion vacuously true, which is
/// §7's "a gate that cannot fail is worse than no gate".
///
/// ## THE MEASUREMENT, AND WHAT IT COST
///
/// | glyph | codepoint | in the five families |
/// | --- | --- | --- |
/// | `✦` | U+2726 | **nowhere** |
/// | `❧` | U+2767 | **EB Garamond only** |
/// | `✠` | U+2720 | **nowhere** |
/// | `☩` | U+2629 | **nowhere** |
/// | `⚙` | U+2699 | **nowhere** |
/// | `›` | U+203A | all five |
/// | `·` | U+00B7 | all five |
/// | `×` | U+00D7 | all five |
/// | `٪` | U+066A | Amiri |
///
/// The consequences are the four decisions the widgets record: the star is
/// **painted** (`FourPointedStar`), the fleuron is **text in the scripture
/// family and pinned on both arms**, the two crosses **unify on the painted
/// star**, and the gear is **`Icons.settings`** — the role is kept and the
/// glyph is the framework's.
void main() {
  group('the four marks the prototype draws as characters', () {
    test('U+2726, U+2720, U+2629 and U+2699 are in no bundled family', () {
      for (final int codepoint in <int>[0x2726, 0x2720, 0x2629, 0x2699]) {
        for (final String family in kBundledFontFamilies) {
          expect(
            codepointsForFamily(family).contains(codepoint),
            isFalse,
            reason:
                'U+${codepoint.toRadixString(16).toUpperCase()} is in $family — '
                'so the painted substitutes this screen ships are not the only '
                'way it could have been drawn, and the decision needs '
                're-reading',
          );
        }
      }
    });

    test('U+2767 is in EB Garamond alone', () {
      for (final String family in kBundledFontFamilies) {
        expect(
          codepointsForFamily(family).contains(0x2767),
          family == 'EBGaramond',
          reason:
              'U+2767 is in $family — the fleuron is drawn as text in the '
              'scripture family, and that only holds while EB Garamond is the '
              'one family that carries it',
        );
      }
    });
  });

  group('the punctuation the screen does type', () {
    test('U+203A, U+00B7 and U+00D7 are in all five families', () {
      for (final int codepoint in <int>[0x203A, 0x00B7, 0x00D7]) {
        for (final String family in kBundledFontFamilies) {
          expect(
            codepointsForFamily(family).contains(codepoint),
            isTrue,
            reason:
                'U+${codepoint.toRadixString(16).toUpperCase()} is missing from '
                '$family, so the run that types it would be a tofu box there',
          );
        }
      }
    });

    test('U+066A — the Arabic percent sign — is in Amiri', () {
      // The Arabic arm's percentage ends in `٪` and not in `%`, and the run is
      // painted in Amiri, so the sign has to be in Amiri.
      expect(
        codepointsForFamily('Amiri').contains(0x066A),
        isTrue,
        reason:
            'U+066A is missing from Amiri, so the Arabic arm\'s percentage '
            'would be a tofu box',
      );
    });
  });

  group('the transcribed colours', () {
    test('the four values are the prototype\'s own', () {
      // `eva/redesign.html:592`, `:594`, `:599` and `:601`. Written out as the
      // prototype's hex, so a change to the table's constants cannot be
      // mistaken for a change to the prototype.
      expect(journeyRingTeal.toARGB32(), 0xFF3EC9B0);
      expect(journeyRingBlue.toARGB32(), 0xFF4F74FF);
      expect(journeyBloomCream.toARGB32(), 0x80F4E3B2);
      expect(journeyBloomAmber.toARGB32(), 0x80D98E32);
      expect(journeyBloomBlue.toARGB32(), 0x804F74FF);
    });
  });
}
