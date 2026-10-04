import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:flutter/material.dart';

/// The metadata row, the citation, and the rule between them.
///
/// `ReadingEnScreen.tsx:27-45` and `ReadingArScreen.tsx:33-45`. Four blocks in the
/// prototype, three of which change shape between the arms:
///
/// | | EN | AR | |
/// | --- | --- | --- | --- |
/// | metadata family | `monoFamily` | **`arabicFamily`** | [metadataFamilyFor] |
/// | metadata tracking | `0.14em` | `0.10em` | [metadataLetterSpacingFor] |
/// | metadata case | uppercased | as sent | [metadataTextFor] |
/// | citation family | `displayFamily` | **`arabicFamily`** | [titleFamilyFor] |
/// | citation size | 34 | 32 | [titleFontSizeFor] |
/// | citation line height | 1.05 | 1.15 | [titleHeightFor] |
/// | citation tracking | `-0.01em` | none | [titleLetterSpacingFor] |
/// | rule's bottom gap | 30 | **32** | [ruleGapFor] |
///
/// ## THE THREE BOLDED FAMILIES ARE DEFECT #2, AND TWO OF THEM ARE **NOT** IN
/// ## THE DEFECT TABLE
///
/// `01-source-analysis.md`'s row names `ReadingArScreen.tsx:35` and `:86`. Reading
/// the file finds two more on the same screen:
///
/// * **`:41` — the citation.** `fontFamily: F.display`, i.e. **Cormorant Garamond**,
///   over the Arabic text `البداية`. §5.2 and `reading_glyph_test.dart`'s coverage
///   check both establish that Cormorant Garamond carries **no Arabic block at
///   all** — 974 glyphs, none of them U+0600–U+06FF. So the prototype's Arabic
///   heading is tofu.
/// * **`:49`… — the verse markers**, which `ScriptureBlock` owns and `01`'s table
///   does not mention. See `ScriptureBlock.markerFamilyFor`.
///
/// ## AND WHAT THE METADATA ROW SAYS IS **`translation`**, WITH NO DURATION
///
/// The prototype's row reads `Genesis · Chapter 1 · 4 min` (`ReadingEnScreen.tsx:31`)
/// and `التكوين · الإصحاح ١ · ٤ دقائق` (`ReadingArScreen.tsx:36`). Two of those three
/// fragments are **fake data**:
///
/// * `Genesis · Chapter 1` is a *reference*, and the API returns one — so it is the
///   row's content now, and the **citation** below it is the same string. That is a
///   visible duplication and it is deliberate: §7 of `reading_strings.dart` records
///   that no passage-name field exists, so the citation has to show `reference`, and
///   a metadata row repeating it verbatim would be a design change.
/// * **`4 min` has no source.** There is no duration field anywhere in
///   `GET /readings/today/{lang}` — verified live against `HEAD = 4a1c834` — and
///   deriving one from a word count is inventing a measurement. So the row shows the
///   payload's `translation`: `NKJV (New King James Version)` /
///   `Smith & Van Dyck (فانديك)`, which is real, per-language, and is the one thing a
///   reader choosing a reading wants to know.
///
/// ## AND THE FLANKING `✦` MARKS ARE **DROPPED**, WITH THE MEASUREMENT
///
/// `ReadingEnScreen.tsx:29,33` draws `✦` (U+2726) either side of the row at 7px.
/// **That codepoint is in none of the five bundled families** — `font_coverage_test
/// .dart` parses every `.ttf` cmap and finds U+2726 absent from Amiri, Cormorant
/// Garamond, DM Sans, EB Garamond and Space Mono alike. Shipping it as `Text` would
/// render **two tofu boxes per reading screen in both languages**: the same defect as
/// #2, in Latin too, and invisible to a gate that only inspects the Arabic arm.
///
/// The alternative was a drawn mark, and it was declined: `StreakFlame` draws a flame
/// because it is a `CustomPainter`, a four-pointed star would need one for a 7px
/// ornament, and a 45°-rotated square is a **diamond** — a different shape from the
/// one the design drew. **Dropped rather than invented**, and the row keeps its
/// centring, its tracking and its bottom gap.
class ReadingHeader extends StatelessWidget {
  /// The metadata row, [reference] as the citation, and the rule.
  const ReadingHeader({
    required this.language,
    required this.reference,
    required this.translation,
    super.key,
  });

  /// Which arm of the corpus this is. Selects six of the numbers above.
  final ReadingLanguage language;

  /// `ScriptureText.reference` — `John 3:1-5` / `يوحنا 3: 1-5`.
  ///
  /// **Rendered verbatim and never parsed.** See `Verse.bookNumber`'s doc: the
  /// string is display-formatted per language by the backend, `book_number` is the
  /// server's own answer to the same question, and a hand-rolled parser for a string
  /// the backend already formats is a new failure surface.
  final String reference;

  /// `ScriptureText.translation`, shown in the metadata row.
  final String translation;

  /// The metadata row's family. `ReadingEnScreen.tsx:30` — `F.mono`;
  /// `ReadingArScreen.tsx:35` — `F.mono` **and Arabic text**.
  ///
  /// The Arabic cell is defect #2's first named site, and the fix is `Amiri`
  /// because Space Mono carries no Arabic glyphs at all.
  static String metadataFamilyFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => EvaTypography.monoFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      };

  /// The metadata row's tracking. `ReadingEnScreen.tsx:30` — `letterSpacing:
  /// '0.14em'`; `ReadingArScreen.tsx:35` — `'0.1em'`.
  ///
  /// ## THE UNITS ARE THE PROTOTYPE'S, AND THAT IS A **RECORDED** DIVERGENCE
  ///
  /// CSS `em` tracking is resolved against the element's own font size — so the
  /// prototype's `0.14em` at `fontSize: 10` is **1.4 logical px**, not 0.14 and not
  /// 1.4sp. Both numbers are converted here for the same reason, so the two arms
  /// stay comparable: `0.14 × 10 = 1.4` and `0.10 × 10 = 1.0`.
  ///
  /// **`0.10em` is NOT transcribed as `0.1`** even though it looks like a literal —
  /// same reasoning as `eva_typography.dart`'s deleted prose-table: a test pinned
  /// the two copies against each other with a regex and caught `0.10` → `0.9` while
  /// missing every sixth arm. The conversion is arithmetic and the arithmetic is
  /// asserted.
  static double metadataLetterSpacingFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => _em(0.14),
        ReadingLanguage.arabic => _em(0.10),
      };

  /// The metadata row's size. `fontSize: 10` on both arms.
  static const double metadataFontSize = 10;

  /// The metadata row's weight. `fontWeight: 700` on both arms.
  static const FontWeight metadataWeight = FontWeight.w700;

  /// The gap between the metadata row and the citation. `marginBottom: 18` on the
  /// row — `ReadingEnScreen.tsx:28`, `ReadingArScreen.tsx:33`.
  static const double metadataGap = 18;

  /// The citation's family. `ReadingEnScreen.tsx:37` — `F.display`;
  /// `ReadingArScreen.tsx:41` — `F.display` **over Arabic text**.
  ///
  /// Cormorant Garamond has no Arabic glyphs, so the Arabic citation renders in
  /// `Amiri`. This is the defect-#2 site the table does not name.
  static String titleFamilyFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => EvaTypography.displayFamily,
    ReadingLanguage.arabic => EvaTypography.arabicFamily,
  };

  /// The citation's size. `ReadingEnScreen.tsx:37` — `fontSize: 34`;
  /// `ReadingArScreen.tsx:41` — `fontSize: 32`.
  ///
  /// Two constants and not a Material slot, for `ScriptureBlock.fontSizeFor`'s
  /// reason: the arms differ and one slot cannot express a difference.
  static double titleFontSizeFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => 34,
        ReadingLanguage.arabic => 32,
      };

  /// The citation's line height. `ReadingEnScreen.tsx:37` — `lineHeight: 1.05`;
  /// `ReadingArScreen.tsx:41` — `lineHeight: 1.15`.
  static double titleHeightFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => 1.05,
    ReadingLanguage.arabic => 1.15,
  };

  /// The citation's tracking. `ReadingEnScreen.tsx:37` — `letterSpacing:
  /// '-0.01em'`; `ReadingArScreen.tsx:41` writes **none**.
  ///
  /// `-0.01em` at 34px is `-0.34` logical px. The Arabic cell is `0.0`, stated as a
  /// number rather than as `null` so the two arms have one comparable field.
  static double titleLetterSpacingFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => _em(
          -0.01,
          at: titleFontSizeFor(ReadingLanguage.english),
        ),
        ReadingLanguage.arabic => 0,
      };

  /// The gap below the citation. `marginBottom: 18` on both arms.
  static const double titleGap = 18;

  /// The rule's width. `width: 36` on both arms.
  static const double ruleWidth = 36;

  /// The rule's colour alpha. `isDark ? 'rgba(255,255,255,0.12)' :
  /// 'rgba(0,0,0,0.12)'` — `ReadingEnScreen.tsx:42`, `ReadingArScreen.tsx:45`.
  ///
  /// Passed explicitly because `HairlineDivider`'s own default is `ink` at **8%**,
  /// which is Login's rule; its doc says the two prototypes' alphas differ by four
  /// points and that picking one would quietly change a shipped screen.
  static const double ruleAlpha = 0.12;

  /// The gap below the rule. `margin: '0 auto 30px'` — `ReadingEnScreen.tsx:42`;
  /// `'0 auto 32px'` — `ReadingArScreen.tsx:45`.
  ///
  /// **The one per-arm number the task's own table missed**, and it is two logical
  /// pixels of a visible gap between the citation and the passage. Found by reading
  /// both files rather than by transcribing the English one and assuming symmetry —
  /// which is what `home_geometry_test.dart`'s library doc calls the failure this
  /// harness exists to prevent.
  static double ruleGapFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => 30,
    ReadingLanguage.arabic => 32,
  };

  /// [em] thousandths of an em at [fontSize] logical px — i.e. `em × fontSize`.
  static double _em(double em, {double? at}) => em * (at ?? metadataFontSize);

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // `justifyContent: 'center'` on the row — `:28` and `:33`. With the `✦`
        // marks dropped the row is a single centred run.
        Text(
          metadataTextFor(language),
          textAlign: TextAlign.center,
          style: EvaTypography.monoCaps(colors).copyWith(
            fontFamily: metadataFamilyFor(language),
            fontSize: metadataFontSize,
            fontWeight: metadataWeight,
            letterSpacing: metadataLetterSpacingFor(language),
            // `T.ink3` on both arms — `ReadingEnScreen.tsx:30`,
            // `ReadingArScreen.tsx:35`.
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: metadataGap),
        Text(
          reference,
          // `textAlign: 'center'` on both arms — `:37`, `:41`.
          textAlign: TextAlign.center,
          style: EvaTypography.textTheme(colors).displaySmall!.copyWith(
            fontFamily: titleFamilyFor(language),
            fontSize: titleFontSizeFor(language),
            fontWeight: FontWeight.w600,
            height: titleHeightFor(language),
            letterSpacing: titleLetterSpacingFor(language),
            color: colors.ink,
          ),
        ),
        const SizedBox(height: titleGap),
        Center(
          // `margin: '0 auto'` centres it — `:42`, `:45`.
          child: HairlineDivider(
            width: ruleWidth,
            color: colors.ink.withValues(alpha: ruleAlpha),
          ),
        ),
        SizedBox(height: ruleGapFor(language)),
      ],
    );
  }

  /// The metadata row's string for [language].
  ///
  /// **Uppercased on the English arm and not on the Arabic one**, because that is
  /// what the prototype writes: `ReadingEnScreen.tsx:30` carries
  /// `textTransform: 'uppercase'` and `ReadingArScreen.tsx:35` does not. Flutter has
  /// no `textTransform`, so the English arm uppercases the string —
  /// `HairlineDivider`'s own label does the same, so there is a precedent in the
  /// design system rather than a new trick.
  ///
  /// Uppercasing does **not** reach the parenthetical in a way that loses
  /// information: `NKJV (New King James Version)` becomes
  /// `NKJV (NEW KING JAMES VERSION)`, which is the mono-caps label treatment the
  /// prototype applies to its own reference. The Arabic arm has no case and the
  /// transformation would be a no-op anyway.
  String metadataTextFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => translation.toUpperCase(),
    ReadingLanguage.arabic => translation,
  };
}
