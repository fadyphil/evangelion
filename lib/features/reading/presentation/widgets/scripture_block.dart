import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/drop_cap_text.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The passage, every verse, in the reader's language.
///
/// ## ONE WIDGET FOR BOTH ARMS, AND EVERY PER-ARM NUMBER IS NAMED
///
/// `ReadingEnScreen.tsx:45-75` and `ReadingArScreen.tsx:47-74` disagree on **nine**
/// numbers and the file map's single `ScriptureBlock` is right; a shared constant
/// for any of the nine is the defect `home_geometry_test.dart`'s library doc warns
/// about ("a wrong token is invisible to a geometry comparison"). So each is a
/// named member below, and `reading_geometry_test.dart` pins each against its own
/// prototype line, per arm.
///
/// | | EN | AR | |
/// | --- | --- | --- | --- |
/// | family | `scriptureFamily` | `arabicFamily` | [familyFor] |
/// | size | 19 | 23 | [fontSizeFor] |
/// | line height | 1.85 | 2.2 | [heightFor] |
/// | verse marker | 11 | 13 | [markerFontSizeFor] |
/// | marker family | `monoFamily` | **`arabicFamily`** | [markerFamilyFor] |
/// | paragraph gap | 22 | 20 | [paragraphGapFor] |
/// | drop cap | 3 lines | **none** | [_dropCapFor] |
///
/// **The two bolded cells are defect #2 and its third site.** `ReadingArScreen.tsx:49`
/// writes `fontFamily: F.mono` on **every** `<sup>`, and those digits are
/// **Arabic-Indic** (`١`…`٧`) in the prototype — which Space Mono does not carry any
/// more than it carries Arabic letters. (This client's own markers are ASCII, so
/// see [markerFamilyFor]'s doc for what actually ships.) The defect table named
/// `:35` and `:86` and missed this, and `01-source-analysis.md:71` is corrected
/// rather than merely extended — to **nine** sites including the three control
/// tooltips the prototype does not have.
///
/// ## ONE PARAGRAPH PER VERSE, AND THE GROUPING IS **NOT** TRANSCRIBED
///
/// The prototype draws Genesis 1:1–10 as four `<p>`s of 2/3/3/2 verses. The live
/// payload is five **numbered** verses of John 3, and the server sends **no
/// paragraph boundaries at all** — so there is nothing to transcribe. One paragraph
/// per verse is the shape the verse marker implies, and inventing a grouping rule
/// over a string the server already formats is a second parser (see
/// `Verse.bookNumber`'s doc for the same argument about `reference`).
///
/// The consequence is that the prototype's `marginTop` becomes the **inter-verse**
/// gap rather than the inter-paragraph one, which is why [paragraphGapFor] keeps the
/// two arms' numbers apart rather than collapsing them.
///
/// ## AND THE TEXT IS `Verse.text`, NEVER `Verse.displayText`
///
/// Recorded on `Verse.text` and repeated because it is the decision a reader would
/// most notice if it went the other way: `text_clean` is a *preview* string, and the
/// sanctuary is the opposite of a preview. One branch, one field, both arms.
class ScriptureBlock extends StatelessWidget {
  /// The passage [verses], laid out for [language].
  const ScriptureBlock({
    required this.verses,
    required this.language,
    required this.strings,
    this.header,
    this.textScaler,
    super.key,
  });

  /// The verses, in the server's order. Never re-sorted, never renumbered.
  final List<Verse> verses;

  /// Which arm of the corpus this is. **The whole per-arm switch in one place.**
  final ReadingLanguage language;

  /// The bilingual strings, for the block's and each marker's accessible names.
  final AppLocalizations strings;

  /// An optional block rendered **above the first verse, inside the same
  /// scrollable**.
  ///
  /// ## WHY IT IS A PARAMETER AND NOT A SIBLING `Column`
  ///
  /// `ReadingEnScreen.tsx:26-77` puts the metadata, the citation, the rule **and** the
  /// passage inside one `overflowY: 'auto'` div, so all four scroll together. A
  /// `Column` of `[ReadingHeader, ScriptureBlock]` inside an `Expanded` would put the
  /// header outside the scrollable and leave it pinned while the passage moves —
  /// which is a different screen.
  ///
  /// It is a parameter rather than this widget importing `ReadingHeader` because a
  /// design-system-shaped widget naming a feature widget is the coupling §3's
  /// SRP row is about, and because `header` is `null` in every golden that pumps
  /// this block on its own.
  final Widget? header;

  /// The scaler the passage renders at.
  ///
  /// `null` is the framework's default, which resolves from the ambient
  /// `MediaQuery`. The page installs [readingTextScalerFor]'s answer on a
  /// `MediaQuery` above itself rather than threading it down here, so **every** run
  /// on the screen moves with the reader's step — including any run a later edit
  /// adds and forgets to pass this.
  final TextScaler? textScaler;

  /// The body's family for [language].
  ///
  /// The two are the design system's own scripture styles, so the *family* is a
  /// token rather than a literal and `reading_glyph_test.dart` asserts the literal
  /// string the engine receives (`Amiri` on the Arabic arm).
  static String familyFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => EvaTypography.scriptureFamily,
    ReadingLanguage.arabic => EvaTypography.arabicFamily,
  };

  /// The body's size. `ReadingEnScreen.tsx:45` — `fontSize: 19`;
  /// `ReadingArScreen.tsx:47` — `fontSize: 23`.
  ///
  /// **Two constants and not a Material slot**, because the two arms genuinely
  /// differ and one slot cannot express a difference. §5.2 fixes no size; the
  /// precedent for publishing a prototype's own size is
  /// `TodayReadingPanel.previewFontSize` (17, from `HomeScreen.tsx:57`), which
  /// `home_geometry_test.dart`'s symbol map pins.
  static double fontSizeFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => 19,
    ReadingLanguage.arabic => 23,
  };

  /// The body's line height. `ReadingEnScreen.tsx:45` — `lineHeight: 1.85`;
  /// `ReadingArScreen.tsx:47` — `lineHeight: 2.2`.
  ///
  /// The Arabic figure is not decoration: Amiri's marks sit **above** the baseline by
  /// a line, so at the Latin 1.85 consecutive Arabic lines would collide.
  static double heightFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => 1.85,
    ReadingLanguage.arabic => 2.2,
  };

  /// The verse marker's size. `ReadingEnScreen.tsx:48` — `fontSize: 11`;
  /// `ReadingArScreen.tsx:49` — `fontSize: 13`.
  static double markerFontSizeFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => 11,
        ReadingLanguage.arabic => 13,
      };

  /// The verse marker's family.
  ///
  /// ## THE FIX, AND IT IS THE THIRD SITE OF DEFECT #2
  ///
  /// `ReadingArScreen.tsx:49,51,56,58,63,68,70` write `fontFamily: F.mono` on
  /// **every** verse marker in the Arabic arm, and every one of those `<sup>`s
  /// carries an **Arabic-Indic** digit — `١`…`٧` — which Space Mono does not carry.
  ///
  /// **The seven lines are the prototype's, and the earlier list of eight was not.**
  /// This doc said `:49,51,56,58,63,**65**,68,70`, and `ReadingArScreen.tsx:65` is
  /// `وَقَالَ اللهُ: «لِيَكُنْ جَلَدٌ فِي وَسَطِ الْمِيهِ»` — a line of Arabic text with no
  /// `<sup>` and no `F.mono` on it. `01-source-analysis.md`'s corrected list,
  /// `35,49,51,56,58,63,68,70,86`, is exact, and this is now the same nine.
  ///
  /// ## AND "DIGITS" HERE DESCRIBES THE **PROTOTYPE**, NOT WHAT THIS CLIENT RENDERS
  ///
  /// The prototype's markers carry U+0661…U+0667. **This client's do not**: the
  /// marker is `TextSpan(text: '${verse.number}')` — an `int`, so U+0031…U+0035 —
  /// and Amiri carries ASCII, so the Arabic arm's markers are **not** tofu. The
  /// family is still `arabicFamily` and it is still the right answer, because the
  /// correct family for a marker in the Arabic arm is the one that renders Arabic,
  /// and today's payload happens to need nothing from it.
  ///
  /// **The one site in this client that really does use Arabic-Indic digits is the
  /// CTA caption**, through `arabicIndicDigits` — and that is site 2, whose
  /// assertion says so. Stated because a doc that describes the prototype's
  /// characters and is read as a claim about this client's is a false claim, and
  /// §9's rule is that a stated number is a claim about something.
  ///
  /// **The English marker keeps `monoFamily`** — Space Mono carries U+0030–U+0039,
  /// so an ASCII digit in it renders, and it is the prototype's own treatment.
  static String markerFamilyFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => EvaTypography.monoFamily,
    ReadingLanguage.arabic => EvaTypography.arabicFamily,
  };

  /// The gap between one verse's paragraph and the next.
  /// `ReadingEnScreen.tsx:54,62,70` — `marginTop: 22`;
  /// `ReadingArScreen.tsx:55,62,67` — `marginTop: 20`.
  static double paragraphGapFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => 22,
    ReadingLanguage.arabic => 20,
  };

  /// The verse marker's weight. `fontWeight: 700` on both arms.
  static const FontWeight markerWeight = FontWeight.w700;

  /// `ReadingEnScreen.tsx:47`'s drop cap — 82px, `lineHeight: 0.78`, a 6px gap on
  /// both sides, `0 0 36px rgba(ember, 0.5)`.
  ///
  /// **Transcribed as `lines: 3`, and the rendered size is NOT 82.** Measured:
  /// `PassageDropCap.fontSizeFor(19)` is `3 × 1.8 × 19 / 0.7` =
  /// **146.57142857142858**, against the prototype's 82. That is not a transcription
  /// error here — `PassageDropCap`'s own D6 doc says it has **no prototype** and
  /// derives its geometry from a cap-height ratio instead, and `04-widget-inventory
  /// .md:32`'s claim that it is "reached through `ScriptureVerse.dropCap`" is false
  /// (no such member exists).
  ///
  /// ## **131.1 IS THE SAME ARITHMETIC AT BODY SIZE 17, NOT AT 19**
  ///
  /// This doc said `3 × 1.8 × 19 / 0.7` = **131.1**, and that is wrong: the
  /// arithmetic at 19 is 146.5714…, and **131.1428…** is the value at **17** —
  /// `TodayReadingPanel.previewFontSize`, `/`'s body size. The code and
  /// `passage_drop_cap_test.dart` (`closeTo(146.57, 0.01)`) both had 146.57 all
  /// along; only the prose was wrong, in four places, and the wrong number was the
  /// **smaller** one, so a reader checking it found a plausible figure rather than an
  /// obvious typo. `/`'s drop cap genuinely is 131.1; this screen's is 146.57.
  ///
  /// The prototype reaches 82 through a CSS `float: left` with `lineHeight: 0.78`,
  /// which has no Flutter equivalent for an inline box. So this client draws the
  /// design system's drop cap at the size the design system derives, and the
  /// divergence is **recorded rather than faked** — a hard-coded 82 would mean
  /// bypassing a shared widget on one screen, which is the "one prototype glyph in
  /// two implementations" defect recorded decision 8 is about.
  ///
  /// **The same measurement is stated, correctly, for `/`** in
  /// `home_geometry_test.dart`'s own comment: at `previewFontSize: 17` the derived
  /// value is 131.1. The Phase-6 comment was not wrong; it was being cited against
  /// the wrong number.
  static const int dropCapLines = 3;

  /// ## AND THE GLOW IS **NOT** REPRODUCED
  ///
  /// `ReadingEnScreen.tsx:47` also writes `textShadow: 0 0 36px rgba(hex.ember,
  /// 0.5)`. `PassageDropCap` has **no shadow parameter** — neither its constructor
  /// nor `capStyle`, which returns a `TextStyle` this file has no way to add a
  /// `shadows` to without re-implementing the widget.
  ///
  /// Adding a shadow to a Phase-2 design-system widget for one call site is a change
  /// this phase does not make, and there is a precedent for declining exactly that:
  /// `StreakFlame` draws a glow because it is a `CustomPainter` and this is not.
  /// Recorded as a divergence rather than left for a reader to find the difference.
  ///
  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    // §13 rule 5: `ListView.builder`, never a `Column` over a list. The count is
    // bounded by one reading's payload, and the block is inside an `Expanded`, so
    // it scrolls rather than overflowing.
    final Widget? headerBlock = header;
    return ListView.builder(
      // The prototype's content div is `overflowY: 'auto'` with no scrollbar
      // (`ReadingEnScreen.tsx:26`) — and `NeuralScaffold`'s doc notes the bouncing
      // physics as the faithful choice for the same reason it uses them for a
      // root-level scroll.
      physics: const BouncingScrollPhysics(),
      itemCount: verses.length + (headerBlock == null ? 0 : 1),
      itemBuilder: (BuildContext context, int index) {
        if (headerBlock != null && index == 0) return headerBlock;
        final int verseIndex = headerBlock == null ? index : index - 1;
        final Verse verse = verses[verseIndex];
        final bool first = verseIndex == 0;
        final PassageDropCap? cap = first ? _dropCapFor(verse, colors) : null;

        final TextStyle bodyStyle = EvaTypography.scriptureLatin(colors)
            .copyWith(
              fontFamily: familyFor(language),
              fontSize: fontSizeFor(language),
              height: heightFor(language),
              color: colors.ink,
            );
        final TextStyle markerStyle = EvaTypography.monoCaps(colors).copyWith(
          fontFamily: markerFamilyFor(language),
          fontSize: markerFontSizeFor(language),
          fontWeight: markerWeight,
          // `ReadingEnScreen.tsx:48` and `ReadingArScreen.tsx:49` both write
          // `color: hex.ember` on the `<sup>`. Inlined rather than reached through a
          // helper, because `no_colour_literals_test.dart` requires the token to be
          // visible **on the line** — which is the right requirement and the reason
          // the helper is gone rather than kept with a suppression.
          color: colors.ember,
        );

        return Padding(
          // `marginTop` on every paragraph after the first. The first has none, and
          // the block's own top padding is the content div's `28px`.
          padding: EdgeInsets.only(top: first ? 0 : paragraphGapFor(language)),
          child: Semantics(
            // §14: a paragraph of scripture is a labelled region, and each verse is
            // named by its number so a reader can say "verse three" rather than
            // counting. `excludeSemantics: false` — the verse text is content, not a
            // duplicate of the label.
            label: '${strings.readingVerse} ${verse.number}',
            child: _verseParagraph(
              context,
              verse: verse,
              bodyStyle: bodyStyle,
              markerStyle: markerStyle,
              cap: cap,
            ),
          ),
        );
      },
    );
  }

  /// One verse as a paragraph, with its marker and an optional drop cap.
  ///
  /// ## A `RichText` AND NOT A `Text`, AND WHY THE DIRECTION IS **NOT** PASSED
  ///
  /// The marker is a `TextSpan` at a different size and family, which is the
  /// prototype's `<sup>` — and a `<sup>` in CSS is `vertical-align: super`, which
  /// **has no `TextSpan` equivalent in Flutter**. The marker therefore sits on the
  /// paragraph's baseline at one step smaller, which is the closest expressible
  /// form.
  ///
  /// **Rejected: nudging it off the baseline.** A `WidgetSpan` child could be
  /// translated upward, and the offset would be a constant while the text scales —
  /// so at §14's 1.22× the "superscript" would sit lower relative to its own line
  /// than it does at 1.0×. A constant that is right at one scale and wrong at
  /// another is worse than an honest approximation, and the approximation is
  /// recorded here rather than hidden.
  ///
  /// `textDirection` is **not** passed: `RichText` falls back to the ambient
  /// `Directionality`, which `MaterialApp` installs from the **locale**. That is
  /// Phase 6's established mechanism, there is no `startsWith('ar')` guess in
  /// `lib/`, and it is what makes the Arabic paragraph right-aligned and its
  /// `WidgetSpan` drop cap hang on the correct side without this file naming a
  /// language for layout at all.
  Widget _verseParagraph(
    BuildContext context, {
    required Verse verse,
    required TextStyle bodyStyle,
    required TextStyle markerStyle,
    required PassageDropCap? cap,
  }) => RichText(
    // `TextAlign.start`, not `TextAlign.left`: the prototype writes no `textAlign`
    // on the English arm and `textAlign: 'right'` on the Arabic one
    // (`ReadingArScreen.tsx:47`), and `start` resolves to exactly those two under
    // the ambient direction. Spelling `right` for Arabic would be a second source
    // of truth for something the direction already decides.
    textAlign: TextAlign.start,
    // `RichText.textScaler` is **non-nullable** in this SDK, so the ambient value is
    // read here rather than inherited — which is the same value a `Text` would have
    // resolved, because the page installs the composed scaler on a `MediaQuery` above
    // this widget. `?? TextScaler.noScaling` would be the identity and would make the
    // parameter an opt-out from the reader's own setting, so it is not used.
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
    text: TextSpan(
      style: bodyStyle,
      children: <InlineSpan>[
        if (cap != null) cap.span(bodyStyle),
        TextSpan(text: '${verse.number}', style: markerStyle),
        // `{' '}` after every marker in the prototype — `:48-49` writes
        // `<sup>1</sup>{' '}n the beginning`, so the marker is separated from the
        // text by a space and not by the marker font's own sidebearing.
        TextSpan(text: ' ', style: bodyStyle),
        // `Verse.text`, NOT `displayText`. See the class doc.
        TextSpan(text: verse.text, style: bodyStyle),
      ],
    ),
  );

  /// The drop cap for [verse], or `null` when this arm has none.
  ///
  /// ## LATIN ONLY, AND THE BRANCH IS ON **LANGUAGE**
  ///
  /// Recorded decision 29, inherited verbatim: `ReadingArScreen.tsx` has **no** drop
  /// cap, and the reason it must not have one is that the Arabic first verse begins
  /// `كَانَ` — enlarging a **joined, right-to-left** Arabic letter to 131px breaks its
  /// connection to the word it belongs to and puts an accent glyph where ink should
  /// be.
  ///
  /// The branch is on [language] and **not** on "does the text look Latin", which is
  /// decision 29's own warning: a shape test breaks on a verse opening with a numeral
  /// or a bracket, and §5's live payload opens one with `Jesus answered` behind a
  /// `‹Verily`.
  ///
  /// **And the cap is never half a character, and never a space.** Two measured
  /// defects, both from the same `substring(0, 1)`, and the first one took the whole
  /// screen.
  ///
  /// **`substring` indexes UTF-16 code units.** A character above U+FFFF is two of
  /// them, so `substring(0, 1)` on a verse opening `'\u{1F600}'` returns the **high
  /// surrogate alone** — measured `codeUnits == [55357]`. `RenderParagraph` then
  /// throws `ArgumentError: string is not well-formed UTF-16` out of
  /// `_RenderScaledInlineWidget.performLayout`, and because the cap is a `WidgetSpan`
  /// **inside the first paragraph**, the throw takes the passage, the metadata row
  /// and **both CTAs** with it. So the letter is `splitDropCap`'s, which cuts on a
  /// rune — and `String.fromCharCode` re-encodes the whole rune, measured
  /// `[55357, 56832]`.
  ///
  /// **A leading space is an invisible 146.6px glyph.** `isEmpty` is false for
  /// `' ‹Verily…'`, so the Phase-6 C3 guard is satisfied and the cap is `' '` — the
  /// largest element on the screen rendering **nothing**, with the paragraph starting
  /// one letter in. `splitDropCap` cuts on the first **non-space** rune and drops the
  /// whitespace with it.
  ///
  /// ## AND IT IS NOT A SHAPE TEST, WHICH DECISION 29 STILL REFUSES
  ///
  /// The branch above is on [language] and nothing here reads the text. Stripping a
  /// leading **combining mark** — `'́Verily'`, which would still make an enlarged
  /// accent the cap — is a shape test, and decision 29 rejects one for this widget
  /// for a measured reason: it breaks on a verse opening with a numeral or a bracket,
  /// and §5's live payload opens one behind a `‹Verily`. Recorded rather than fixed,
  /// because the fix and the decision are the same shape.
  ///
  /// ## AND THE EMPTY VERSE STILL DOES NOT THROW
  ///
  /// `splitDropCap` is total over `String`: `''` and `'   '` both give a letter of
  /// `''`, so an empty first verse renders an empty paragraph, the controls row
  /// survives, and the reader can still reach the reflection. That was the claim
  /// Phase 6's C3 recorded and this one copied — and it was **true and
  /// incomplete**: `isEmpty` is the right question about a string and the wrong
  /// question about a *character*.
  PassageDropCap? _dropCapFor(Verse verse, EvaColors colors) {
    if (language != ReadingLanguage.english) return null;
    final DropCapText cap = splitDropCap(verse.text);
    if (cap.letter.isEmpty) return null;
    return PassageDropCap(
      letter: cap.letter,
      lines: dropCapLines,
      color: colors.ember,
      // The only arm that reaches here is the Latin one, so the direction is LTR
      // and is stated rather than inherited — `PassageDropCap`'s own doc says the
      // parameter is defensive and unobservable for a one-glyph box, and a caller
      // that guesses a direction for a paragraph is the mistake its `paragraph`
      // method exists to prevent.
      direction: TextDirection.ltr,
    );
  }
}
