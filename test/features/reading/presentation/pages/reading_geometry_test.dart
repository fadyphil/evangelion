/// **Decision 8's harness, for `/reading`, and the per-arm half of it.**
///
/// AGENT_CONTEXT §9, recorded decision 8 names "the phase that first transcribes a
/// screen" as the owner of a prototype-comparison harness and then says, of the five
/// other screens: "Phases 6–9 should add each screen's own claims rather than assume
/// this generalises." Phase 6 built it for `/` (`home_geometry_test.dart`); this is
/// `/reading`'s.
///
/// ## WHY THIS FILE IS **BIGGER** THAN `/`'s HARNESS
///
/// Because `/reading` is the first screen in this app whose two language arms
/// disagree, and they disagree on **nineteen** numbers. `home_geometry_test.dart`'s
/// library doc names the failure this file exists to prevent: "a wrong token is
/// invisible to a geometry comparison". Worse, a single shared constant for any one
/// of the nineteen is invisible to *that* harness too, because the harness would be
/// comparing the same constant against two different prototype lines and one of them
/// would have to lose.
///
/// So the table below is **[per arm]**, every row names its own prototype file **and
/// line**, and the reverse direction is asserted too: a Dart constant nobody claims is
/// a number with no prototype behind it, which is how `kSocialButtonGap` survived in
/// `login_geometry_test.dart` long enough to be certified while nothing read it.
///
/// ## THE THREE HALVES, AND WHAT EACH ONE CANNOT SEE
///
/// 1. **A line map** — each claim's `pattern` is the prototype's own text on the line
///    the claim names, read at test time. A renumbered prototype turns this red.
/// 2. **A symbol map** — each claim's `key` is read off a Dart constant *per arm*, so
///    a value that is right for English and wrong for Arabic fails.
/// 3. **Rendered geometry** — what `RenderBox` reports and what the rendered
///    `TextStyle` says, against the prototype's numbers rather than against this
///    project's constants.
///
/// **What it still cannot see**, stated rather than left for Phase 10: colours, radii
/// and blur sigmas are tokens, and a *wrong token* is invisible to a geometry
/// comparison. It can tell 19 from 23 but not `padding: 19` from
/// `EdgeInsets.all(19)`. Fonts are `reading_glyph_test.dart`'s, and they are the half
/// that matters most on this screen.
///
/// ## AND THE `em` TRACKING ROWS ARE **CONVERTED, NOT COPIED**
///
/// CSS resolves `letter-spacing` against the element's own font size, so the
/// prototype's `'0.14em'` at `fontSize: 10` is **1.4 logical px**. Copying `0.14`
/// would be a transcription error that is invisible at both ends (it looks like a
/// plausible number and renders as almost no tracking), and the table asserts the
/// **converted** value so the arithmetic is the thing under test.
library;

import 'dart:io';

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_controls.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_header.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reading_harness.dart';

/// The prototype files this harness reads. `eva/` is reference material and is never
/// written to (AGENT_CONTEXT §2, §8); existence is asserted so a moved file is a
/// failure rather than an empty extraction.
const String readingEn = 'eva/src/screens/ReadingEnScreen.tsx';
const String readingAr = 'eva/src/screens/ReadingArScreen.tsx';

/// One transcription claim: a prototype line, the text on it, and the number that
/// text declares once converted to logical px.
typedef PrototypeClaim = ({
  String key,
  String file,
  int line,
  String pattern,
  double expected,
});

/// Every number `/reading` publishes, per arm, read off the Dart constants.
///
/// **A [Map] and not a list of rows** because the reverse direction needs an
/// enumeration of what exists, and a hand-written list beside the claims table is a
/// second declaration free to drift — `login_geometry_test.dart`'s symbol map exists
/// for exactly that.
final Map<ReadingLanguage, Map<String, double>>
armValues = <ReadingLanguage, Map<String, double>>{
  ReadingLanguage.english: <String, double>{
    'controlsPaddingTop': ReadingControls.paddingFor(ReadingLanguage.english)
        .top,
    'controlsPaddingHorizontal': ReadingControls.paddingFor(
      ReadingLanguage.english,
    ).left,
    'controlsGap': ReadingControls.gap,
    'metadataFontSize': ReadingHeader.metadataFontSize,
    // `'0.14em'` at 10px = 1.4. See the library doc.
    'metadataLetterSpacing': ReadingHeader.metadataLetterSpacingFor(
      ReadingLanguage.english,
    ),
    'metadataGap': ReadingHeader.metadataGap,
    'titleFontSize': ReadingHeader.titleFontSizeFor(ReadingLanguage.english),
    'titleHeight': ReadingHeader.titleHeightFor(ReadingLanguage.english),
    'titleLetterSpacing': ReadingHeader.titleLetterSpacingFor(
      ReadingLanguage.english,
    ),
    'titleGap': ReadingHeader.titleGap,
    'ruleWidth': ReadingHeader.ruleWidth,
    'ruleGap': ReadingHeader.ruleGapFor(ReadingLanguage.english),
    'scriptureFontSize': ScriptureBlock.fontSizeFor(ReadingLanguage.english),
    'scriptureHeight': ScriptureBlock.heightFor(ReadingLanguage.english),
    'markerFontSize': ScriptureBlock.markerFontSizeFor(ReadingLanguage.english),
    'paragraphGap': ScriptureBlock.paragraphGapFor(ReadingLanguage.english),
    'captionFontSize': StickyCta.captionFontSize,
    'captionLetterSpacing': StickyCta.captionLetterSpacingFor(
      ReadingLanguage.english,
    ),
    'captionGap': StickyCta.captionGap,
    'contentBottomReserve': ReadingPage.contentPadding.bottom,
    'ctaPaddingBottom': StickyCta.padding.bottom,
  },
  ReadingLanguage.arabic: <String, double>{
    'controlsPaddingTop': ReadingControls.paddingFor(ReadingLanguage.arabic)
        .top,
    'controlsPaddingHorizontal': ReadingControls.paddingFor(
      ReadingLanguage.arabic,
    ).left,
    'controlsGap': ReadingControls.gap,
    'metadataFontSize': ReadingHeader.metadataFontSize,
    'metadataLetterSpacing': ReadingHeader.metadataLetterSpacingFor(
      ReadingLanguage.arabic,
    ),
    'metadataGap': ReadingHeader.metadataGap,
    'titleFontSize': ReadingHeader.titleFontSizeFor(ReadingLanguage.arabic),
    'titleHeight': ReadingHeader.titleHeightFor(ReadingLanguage.arabic),
    'titleLetterSpacing': ReadingHeader.titleLetterSpacingFor(
      ReadingLanguage.arabic,
    ),
    'titleGap': ReadingHeader.titleGap,
    'ruleWidth': ReadingHeader.ruleWidth,
    // **30 against English's 30 — no: 32.** The one per-arm value the task's own
    // comparison table omitted, and two logical pixels of visible gap.
    'ruleGap': ReadingHeader.ruleGapFor(ReadingLanguage.arabic),
    'scriptureFontSize': ScriptureBlock.fontSizeFor(ReadingLanguage.arabic),
    'scriptureHeight': ScriptureBlock.heightFor(ReadingLanguage.arabic),
    'markerFontSize': ScriptureBlock.markerFontSizeFor(ReadingLanguage.arabic),
    'paragraphGap': ScriptureBlock.paragraphGapFor(ReadingLanguage.arabic),
    'captionFontSize': StickyCta.captionFontSize,
    'captionLetterSpacing': StickyCta.captionLetterSpacingFor(
      ReadingLanguage.arabic,
    ),
    'captionGap': StickyCta.captionGap,
    'contentBottomReserve': ReadingPage.contentPadding.bottom,
    'ctaPaddingBottom': StickyCta.padding.bottom,
    'bandHeight': ReadingPage.arabicBandHeight,
    'bandDash': ReadingPage.arabicBandDash.toDouble(),
    'bandPitch': ReadingPage.arabicBandPitch.toDouble(),
    'bandAlphaDark': ReadingPage.arabicBandAlpha(Brightness.dark),
    'bandAlphaLight': ReadingPage.arabicBandAlpha(Brightness.light),
  },
};

/// Every claim, per arm.
///
/// **Every record carries its own `key`**, and that is not tidiness — it is the fix
/// for a bug this file had. The first version paired this table with `armValues` by
/// **list position**, and `dart format` reordering one of the two silently re-paired
/// every row after the change: "Expected 20, Actual 21" out of two entirely correct
/// tables. A record that names its own key cannot drift that way, and the reverse
/// direction ("is every constant claimed?") becomes a set comparison rather than an
/// index count.
final Map<ReadingLanguage, List<PrototypeClaim>>
claims = <ReadingLanguage, List<PrototypeClaim>>{
  ReadingLanguage.english: <PrototypeClaim>[
    (
      key: 'controlsPaddingTop',
      file: readingEn,
      line: 13,
      pattern: "'20px 20px 0'",
      expected: 20,
    ),
    (
      key: 'controlsPaddingHorizontal',
      file: readingEn,
      line: 13,
      pattern: "'20px 20px 0'",
      expected: 20,
    ),
    (
      key: 'controlsGap',
      file: readingEn,
      line: 17,
      pattern: 'gap: 16',
      expected: 16,
    ),
    (
      key: 'metadataFontSize',
      file: readingEn,
      line: 30,
      pattern: 'fontSize: 10',
      expected: 10,
    ),
    // `'0.14em'` at 10px is **1.4 logical px**, not `0.14`. See the library doc.
    (
      key: 'metadataLetterSpacing',
      file: readingEn,
      line: 30,
      pattern: "'0.14em'",
      expected: 1.4,
    ),
    (
      key: 'metadataGap',
      file: readingEn,
      line: 28,
      pattern: 'marginBottom: 18',
      expected: 18,
    ),
    (
      key: 'titleFontSize',
      file: readingEn,
      line: 37,
      pattern: 'fontSize: 34',
      expected: 34,
    ),
    (
      key: 'titleHeight',
      file: readingEn,
      line: 37,
      pattern: 'lineHeight: 1.05',
      expected: 1.05,
    ),
    (
      key: 'titleLetterSpacing',
      file: readingEn,
      line: 37,
      pattern: "'-0.01em'",
      expected: -0.34,
    ),
    (
      key: 'titleGap',
      file: readingEn,
      line: 37,
      pattern: 'marginBottom: 18',
      expected: 18,
    ),
    (
      key: 'ruleWidth',
      file: readingEn,
      line: 42,
      pattern: 'width: 36',
      expected: 36,
    ),
    (
      key: 'ruleGap',
      file: readingEn,
      line: 42,
      pattern: "'0 auto 30px'",
      expected: 30,
    ),
    (
      key: 'scriptureFontSize',
      file: readingEn,
      line: 45,
      pattern: 'fontSize: 19',
      expected: 19,
    ),
    (
      key: 'scriptureHeight',
      file: readingEn,
      line: 45,
      pattern: 'lineHeight: 1.85',
      expected: 1.85,
    ),
    (
      key: 'markerFontSize',
      file: readingEn,
      line: 48,
      pattern: 'fontSize: 11',
      expected: 11,
    ),
    (
      key: 'paragraphGap',
      file: readingEn,
      line: 54,
      pattern: 'marginTop: 22',
      expected: 22,
    ),
    (
      key: 'contentBottomReserve',
      file: readingEn,
      line: 26,
      pattern: "'28px 24px 130px'",
      expected: 130,
    ),
    (
      key: 'ctaPaddingBottom',
      file: readingEn,
      line: 81,
      pattern: "'20px 24px 32px'",
      expected: 32,
    ),
    (
      key: 'captionFontSize',
      file: readingEn,
      line: 88,
      pattern: 'fontSize: 9',
      expected: 9,
    ),
    (
      key: 'captionLetterSpacing',
      file: readingEn,
      line: 88,
      pattern: "'0.12em'",
      expected: 1.08,
    ),
    (
      key: 'captionGap',
      file: readingEn,
      line: 88,
      pattern: 'marginTop: 8',
      expected: 8,
    ),
  ],
  ReadingLanguage.arabic: <PrototypeClaim>[
    (
      key: 'controlsPaddingTop',
      file: readingAr,
      line: 19,
      pattern: "'16px 20px 0'",
      expected: 16,
    ),
    (
      key: 'controlsPaddingHorizontal',
      file: readingAr,
      line: 19,
      pattern: "'16px 20px 0'",
      expected: 20,
    ),
    (
      key: 'controlsGap',
      file: readingAr,
      line: 20,
      pattern: 'gap: 16',
      expected: 16,
    ),
    (
      key: 'metadataFontSize',
      file: readingAr,
      line: 35,
      pattern: 'fontSize: 10',
      expected: 10,
    ),
    (
      key: 'metadataLetterSpacing',
      file: readingAr,
      line: 35,
      pattern: "'0.1em'",
      expected: 1.0,
    ),
    (
      key: 'metadataGap',
      file: readingAr,
      line: 33,
      pattern: 'marginBottom: 18',
      expected: 18,
    ),
    (
      key: 'titleFontSize',
      file: readingAr,
      line: 41,
      pattern: 'fontSize: 32',
      expected: 32,
    ),
    (
      key: 'titleHeight',
      file: readingAr,
      line: 41,
      pattern: 'lineHeight: 1.15',
      expected: 1.15,
    ),
    // The Arabic citation carries **no** `letterSpacing`, so the claim cites the
    // line it does have and expects `0` — a number the prototype states by
    // omission, and the only honest way to pin an absence is a value beside it.
    (
      key: 'titleLetterSpacing',
      file: readingAr,
      line: 41,
      pattern: 'fontSize: 32',
      expected: 0,
    ),
    (
      key: 'titleGap',
      file: readingAr,
      line: 41,
      pattern: 'marginBottom: 18',
      expected: 18,
    ),
    (
      key: 'ruleWidth',
      file: readingAr,
      line: 45,
      pattern: 'width: 36',
      expected: 36,
    ),
    // **The one per-arm value the task's own comparison table omitted.** Two
    // logical pixels of visible gap, and the reason this harness reads both files
    // rather than transcribing the English one and assuming symmetry.
    (
      key: 'ruleGap',
      file: readingAr,
      line: 45,
      pattern: "'0 auto 32px'",
      expected: 32,
    ),
    (
      key: 'scriptureFontSize',
      file: readingAr,
      line: 47,
      pattern: 'fontSize: 23',
      expected: 23,
    ),
    (
      key: 'scriptureHeight',
      file: readingAr,
      line: 47,
      pattern: 'lineHeight: 2.2',
      expected: 2.2,
    ),
    (
      key: 'markerFontSize',
      file: readingAr,
      line: 49,
      pattern: 'fontSize: 13',
      expected: 13,
    ),
    (
      key: 'paragraphGap',
      file: readingAr,
      line: 55,
      pattern: 'marginTop: 20',
      expected: 20,
    ),
    (
      key: 'contentBottomReserve',
      file: readingAr,
      line: 32,
      pattern: "'28px 24px 130px'",
      expected: 130,
    ),
    (
      key: 'ctaPaddingBottom',
      file: readingAr,
      line: 79,
      pattern: "'20px 24px 32px'",
      expected: 32,
    ),
    (
      key: 'captionFontSize',
      file: readingAr,
      line: 86,
      pattern: 'fontSize: 9',
      expected: 9,
    ),
    (
      key: 'captionLetterSpacing',
      file: readingAr,
      line: 86,
      pattern: "'0.10em'",
      expected: 0.9,
    ),
    (
      key: 'captionGap',
      file: readingAr,
      line: 86,
      pattern: 'marginTop: 8',
      expected: 8,
    ),
    (
      key: 'bandHeight',
      file: readingAr,
      line: 14,
      pattern: 'height: 5',
      expected: 5,
    ),
    // **Leading space, and it is the whole point.** The pattern was `'2px,'`, and
    // `contains` accepts a substring anywhere — so rewriting the prototype's dash
    // from `2px` to `12px` still matched `'2px,'` inside `'12px,'`, while
    // `armValues` separately asserted `arabicBandDash == 2`. **Both halves stayed
    // green with a wrong transcription**, which is the one thing a prototype harness
    // exists to prevent. A leading space is a non-digit boundary: `' 12px,'` has a
    // `1` where the space has to be.
    // ## THIS PATTERN, AND IT IS THE ONE THE WHOLE ANCHORING IS FOR
    //
    // It was `'2px,'`. `contains` matches a substring anywhere, and this line has
    // **two** `2px,` — the dash and the transparent stop beside it — so the pattern
    // identified neither. Measured: rewriting the prototype's dash from `2px` to
    // `12px` left the **whole suite green**, while `armValues` separately asserted
    // `arabicBandDash == 2`. Both halves green, transcription wrong.
    //
    // A leading space is **not** enough, and that is measured too: `' 2px,'` still
    // matched the *surviving* `transparent 2px,`. So the pattern quotes from the
    // **closing brace of the `rgba()` call** — the one thing that marks *which*
    // `2px` is the dash — through the transparent stop that follows it. The line
    // carries `')} 2px, transparent'` verbatim, so a `12px` dash breaks it and a
    // change to the *transparent* stop does not, which is right: this claim is
    // about the dash.
    (
      key: 'bandDash',
      file: readingAr,
      line: 15,
      pattern: ')} 2px, transparent',
      expected: 2,
    ),
    // Anchored for the same reason as `bandDash`, in the same direction: the pitch is
    // the **last** number on the line, so a longer one is caught by [declaresAt]'s
    // numeric right edge — but `transparent 18px)` also says *which* `18px` this is,
    // and the line's other `px` figures are `0px` and `2px`.
    (
      key: 'bandPitch',
      file: readingAr,
      line: 15,
      pattern: 'transparent 18px)',
      expected: 18,
    ),
    // The band's two alphas, both on `:15` — `rgba('#B79CF0', isDark ? 0.3 :
    // 0.2)`. The **hue** is not transcribed: `#B79CF0` is not a token, and
    // `ReadingPage`'s doc gives the substitution and the reason.
    (
      key: 'bandAlphaDark',
      file: readingAr,
      line: 15,
      pattern: '0.3',
      expected: 0.3,
    ),
    (
      key: 'bandAlphaLight',
      file: readingAr,
      line: 15,
      pattern: '0.2',
      expected: 0.2,
    ),
  ],
};

/// The lines of [file], or a loud failure.
///
/// Existence is asserted rather than assumed: a harness that cannot read the
/// prototype does not pass, it *reports*, and `home_geometry_test.dart`'s
/// `declaredValues` says the same in its own words.
List<String> linesOf(String file) {
  final File source = File(file);
  expect(
    source.existsSync(),
    isTrue,
    reason:
        '$file is missing. This harness cannot read the prototype, so it does not '
        'pass — a missing reference is reported, never assumed unchanged.',
  );
  return source.readAsLinesSync();
}

/// Whether [line] declares [pattern] — and **not** merely contains it.
///
/// ## WHY NOT `contains`, MEASURED
///
/// `String.contains` matches a substring anywhere, and every pattern in this file
/// ends in a **number**. So `'fontSize: 19'` is satisfied by `fontSize: 190`,
/// `'marginTop: 8'` by `marginTop: 80`, `'height: 5'` by `height: 50` — and the
/// symbol map, which asserts the **Dart** constant against the claim's `expected`,
/// cannot see any of it, because `expected` is the number the table says rather
/// than the number the prototype says. Both halves green, transcription wrong.
///
/// The first measured instance in this project was `contains` accepting `240` for
/// `24`; the second was this file's `bandDash`, whose pattern was the bare `'2px,'`
/// while the line could say `12px,`. **Live, end-to-end**: rewriting the prototype's
/// dash from `2px` to `12px` left the whole suite green.
///
/// ## THE TWO ENDS, AND WHY ONLY ONE IS ANCHORED HERE
///
/// The **right** end is the general rule and lives in this function: the match must
/// not be followed by a digit or a decimal point, so a longer number cannot satisfy
/// a shorter claim. `(?![0-9.])` and not `(?![0-9A-Za-z])`, because the tracking
/// claims end in `em` and a letter after a matched `'0.10em'` is the closing quote.
///
/// The **left** end cannot be generalised — a pattern's first character is whatever
/// it is — so a claim whose false match is on the left carries the boundary itself,
/// which is why `bandDash`'s pattern begins with a space. See its row.
bool declaresAt(String line, String pattern) =>
    RegExp('${RegExp.escape(pattern)}(?![0-9.])').hasMatch(line);

/// The text of [file]'s line [line], one-based.
String lineAt(String file, int line) {
  final List<String> lines = linesOf(file);
  expect(
    line,
    inInclusiveRange(1, lines.length),
    reason: '$file has ${lines.length} lines and the claim names $line',
  );
  return lines[line - 1];
}

void main() {
  group('the prototype still says what each claim says', () {
    test("every claim's line still declares the text it quotes", () {
      for (final ReadingLanguage arm in ReadingLanguage.values) {
        final List<PrototypeClaim> armClaims = claims[arm]!;
        expect(armClaims, isNotEmpty, reason: '$arm has no claims at all');
        for (final PrototypeClaim claim in armClaims) {
          expect(
            declaresAt(lineAt(claim.file, claim.line), claim.pattern),
            isTrue,
            reason:
                '${claim.file}:${claim.line} no longer declares `${claim.pattern}`, '
                'so a claim citing it is now citing something else',
          );
        }
      }
    });

    test('and the check is not a bare `contains`, which admits a false match', () {
      // **The third instance of `contains` accepting `240` for `24`**, and the first
      // one measured end-to-end rather than reasoned about: the Arabic band's claim
      // was the bare string `'2px,'`, so `… 12px, …` satisfied it.
      //
      // `contains` is unanchored on **both** sides, and both sides have bitten:
      // `fontSize: 190` contains `fontSize: 19`, and `12px,` contains `2px,`. So the
      // check is a regular expression that refuses to end on a **digit or a decimal
      // point**, and the one claim whose false match is on the *left* — the band's
      // dash — carries a leading space in its own pattern instead.
      //
      // Asserted as its own test, against the mechanism, because the defect is in
      // the *comparator*: a harness whose line map quietly accepts a wrong prototype
      // is worse than one with no line map, because it certifies.
      expect(declaresAt('fontSize: 19', 'fontSize: 19'), isTrue);
      expect(declaresAt('fontSize: 190', 'fontSize: 19'), isFalse);
      expect(declaresAt('fontSize: 1.85', 'fontSize: 1.8'), isFalse);
      // The band's own two claims, on the line's real text — the measured false
      // match, and the one a leading space alone did **not** fix.
      // **The line's real tail**, from `ReadingArScreen.tsx:15`:
      // `… isDark ? 0.3 : 0.2)} 2px, transparent 2px, transparent 18px)`. The `)` is
      // the `rgba()` call's and the `}` closes the template's first argument — which
      // is the pair that marks *which* `2px` is the dash.
      const String band = '0.2)} 2px, transparent 2px, transparent 18px)';
      expect(declaresAt(band, ')} 2px, transparent'), isTrue);
      expect(
        declaresAt(
          band.replaceFirst('} 2px,', '} 12px,'),
          ')} 2px, transparent',
        ),
        isFalse,
        reason:
            'the dash moved, and a leading space alone would not have seen it',
      );
      expect(declaresAt(band, 'transparent 18px)'), isTrue);
      expect(
        declaresAt(band.replaceFirst('18px)', '118px)'), 'transparent 18px)'),
        isFalse,
      );
      // …and the trailing edge still admits a real match, or the check is vacuous.
      expect(declaresAt("'0.10em'", "'0.10em'"), isTrue);
      expect(declaresAt("letterSpacing: '0.10em'", "'0.10em'"), isTrue);
    });

    test(
      'and every claim resolved a DISTINCT line, so the table is not one row',
      () {
        // The second half of the same claim. A table where every row resolved to one
        // line would satisfy the test above and mean nothing.
        for (final ReadingLanguage arm in ReadingLanguage.values) {
          final Set<int> distinct = <int>{
            for (final PrototypeClaim claim in claims[arm]!) claim.line,
          };
          expect(
            distinct.length,
            greaterThanOrEqualTo(12),
            reason: '$arm cites only ${distinct.length} distinct lines',
          );
        }
      },
    );

    test('and the two arms cite DIFFERENT prototype files', () {
      expect(
        claims[ReadingLanguage.english]!
            .map((PrototypeClaim c) => c.file)
            .toSet(),
        <String>{readingEn},
      );
      expect(
        claims[ReadingLanguage.arabic]!
            .map((PrototypeClaim c) => c.file)
            .toSet(),
        <String>{readingAr},
      );
    });
  });

  group('the symbol map — per arm, because the arms disagree', () {
    test('every Dart constant equals the number its own arm transcribes', () {
      // **Keyed, and that is the point.** The first version paired this table with
      // `armValues` by list position and `dart format` reordering one of the two
      // silently re-paired every row after the change — "Expected 20, Actual 21" out
      // of two entirely correct tables. A record that names its own key cannot drift
      // that way.
      for (final ReadingLanguage arm in ReadingLanguage.values) {
        final Map<String, double> values = armValues[arm]!;
        for (final PrototypeClaim claim in claims[arm]!) {
          expect(
            values[claim.key],
            closeTo(claim.expected, 1e-9),
            reason: '$arm / ${claim.key} (${claim.file}:${claim.line})',
          );
        }
      }
    });

    test('every published constant is claimed exactly once', () {
      // The other direction, and `home_geometry_test.dart`'s reason for it: a constant
      // nobody claims is a number with no prototype behind it — which is how
      // `kSocialButtonGap` survived in `login_geometry_test.dart` long enough to be
      // certified while nothing read it.
      for (final ReadingLanguage arm in ReadingLanguage.values) {
        final List<String> claimed = <String>[
          for (final PrototypeClaim claim in claims[arm]!) claim.key,
        ];
        expect(
          claimed.toSet().length,
          claimed.length,
          reason:
              '$arm claims a key twice, so one of the two rows is not being read',
        );
        expect(
          claimed.toSet(),
          armValues[arm]!.keys.toSet(),
          reason: '$arm: a key on one side and not the other',
        );
      }
    });

    test(
      'and a key both arms claim with the SAME number has the same value',
      () {
        // The corollary that makes the differing keys meaningful. The set is built from
        // the **claims**, not from the values: "both arms claim this key and they agree"
        // is a claim about the prototype, and "the two values happen to be equal" is a
        // coincidence that would hide a wrong transcription on one arm.
        final Map<String, double> byKey = <String, double>{
          for (final PrototypeClaim claim in claims[ReadingLanguage.english]!)
            claim.key: claim.expected,
        };
        int agreed = 0;
        for (final PrototypeClaim ar in claims[ReadingLanguage.arabic]!) {
          final double? enClaim = byKey[ar.key];
          if (enClaim == null || enClaim != ar.expected) continue;
          agreed++;
          final double enValue = armValues[ReadingLanguage.english]![ar.key]!;
          final double arValue = armValues[ReadingLanguage.arabic]![ar.key]!;
          expect(
            enValue,
            closeTo(arValue, 1e-9),
            reason:
                '`${ar.key}` — the prototype agrees at '
                '${ar.file}:${ar.line}, so the two arms must too',
          );
        }
        expect(
          agreed,
          greaterThanOrEqualTo(10),
          reason:
              'and the set is not empty, so this is a real check rather than a '
              'loop over nothing',
        );
      },
    );

    test(
      'and the keys the two arms claim DIFFERENT numbers for are exactly the '
      'eleven the prototype disagrees on',
      () {
        // This is the assertion the whole file exists for. It is a **set equality**, so
        // flipping any single per-arm value to the other arm's moves it out of the set
        // and the failure names it.
        final Map<String, double> byKey = <String, double>{
          for (final PrototypeClaim claim in claims[ReadingLanguage.english]!)
            claim.key: claim.expected,
        };
        // **Only keys BOTH arms claim.** The Arabic arm has five the English one has
        // no row for at all — the geometric band, which `ReadingEnScreen.tsx` simply
        // does not have — and "the arms disagree about a key one of them has never
        // heard of" is not a disagreement.
        final Set<String> claimedAsDifferent = <String>{
          for (final PrototypeClaim ar in claims[ReadingLanguage.arabic]!)
            if (byKey.containsKey(ar.key) && byKey[ar.key] != ar.expected)
              ar.key,
        };
        // …and the converse, so an Arabic-only key cannot be smuggled in.
        expect(
          armValues[ReadingLanguage.arabic]!.keys.toSet().difference(
            armValues[ReadingLanguage.english]!.keys.toSet(),
          ),
          <String>{
            'bandHeight',
            'bandDash',
            'bandPitch',
            'bandAlphaDark',
            'bandAlphaLight',
          },
          reason:
              'the band is the only thing on this screen one arm has '
              'and the other does not, and `ReadingEnScreen.tsx` has no '
              'such element',
        );
        expect(
          claimedAsDifferent,
          <String>{
            'controlsPaddingTop',
            'metadataLetterSpacing',
            'titleFontSize',
            'titleHeight',
            'titleLetterSpacing',
            'ruleGap',
            'scriptureFontSize',
            'scriptureHeight',
            'markerFontSize',
            'paragraphGap',
            'captionLetterSpacing',
          },
          reason:
              'eleven per-arm numbers, and `ruleGap` is the one the task own '
              'comparison table missed',
        );

        // …and the values really do differ, so the claim above is not satisfied by two
        // tables that happen to agree.
        final Set<String> actuallyDifferent = <String>{
          for (final String key in claimedAsDifferent)
            if (armValues[ReadingLanguage.english]![key] !=
                armValues[ReadingLanguage.arabic]![key])
              key,
        };
        expect(actuallyDifferent, claimedAsDifferent);
      },
    );
  });

  group('the rendered geometry', () {
    // The third half: the prototype's numbers again, read off what the tree reports.
    // A constant that is right and a widget that ignores it are otherwise the same
    // test.

    for (final (ReadingLanguage arm, Locale locale)
        in <(ReadingLanguage, Locale)>[
          (ReadingLanguage.english, const Locale('en')),
          (ReadingLanguage.arabic, const Locale('ar')),
        ]) {
      testWidgets('${arm.name}: the scripture style is the prototype number', (
        WidgetTester tester,
      ) async {
        final ReadingHarness h = readingHarness(
          scripture: Result.success(
            arm == ReadingLanguage.english
                ? liveEnglishPassage
                : liveArabicPassage,
          ),
        );
        await pumpReading(
          tester,
          cubit: h.cubit,
          locale: locale,
          size: kGeometrySurface,
        );

        final TextStyle body = _bodyStyleOf(scriptureElements(tester)[0]);
        expect(body.fontSize, ScriptureBlock.fontSizeFor(arm));
        expect(body.height, ScriptureBlock.heightFor(arm));
        expect(
          body.fontSize,
          isNot(
            ScriptureBlock.fontSizeFor(
              ReadingLanguage.english == arm
                  ? ReadingLanguage.arabic
                  : ReadingLanguage.english,
            ),
          ),
        );
      });

      testWidgets('${arm.name}: the verse marker is the prototype number', (
        WidgetTester tester,
      ) async {
        final ReadingHarness h = readingHarness(
          scripture: Result.success(
            arm == ReadingLanguage.english
                ? liveEnglishPassage
                : liveArabicPassage,
          ),
        );
        await pumpReading(tester, cubit: h.cubit, locale: locale);

        final TextStyle marker = _markerStyleOf(scriptureElements(tester)[1]);
        expect(marker.fontSize, ScriptureBlock.markerFontSizeFor(arm));
        expect(marker.fontWeight, ScriptureBlock.markerWeight);
      });

      testWidgets('${arm.name}: the inter-verse gap is the prototype number', (
        WidgetTester tester,
      ) async {
        final ReadingHarness h = readingHarness(
          scripture: Result.success(
            arm == ReadingLanguage.english
                ? liveEnglishPassage
                : liveArabicPassage,
          ),
        );
        // Tall enough for three consecutive verses, which is all the gap needs.
        await pumpReading(
          tester,
          cubit: h.cubit,
          locale: locale,
          size: const Size(430, 2400),
        );

        final List<Element> verses = scriptureElements(tester);
        final double gap = _verseTop(verses[1]) - _verseBottom(verses[0]);
        expect(
          gap,
          closeTo(ScriptureBlock.paragraphGapFor(arm), 0.5),
          reason: "measured between verse 1's last line and verse 2's first",
        );
      });

      testWidgets(
        '${arm.name}: the controls row starts at the prototype padding',
        (WidgetTester tester) async {
          final ReadingHarness h = readingHarness(
            scripture: Result.success(
              arm == ReadingLanguage.english
                  ? liveEnglishPassage
                  : liveArabicPassage,
            ),
          );
          await pumpReading(tester, cubit: h.cubit, locale: locale);

          // The back button is the first thing in the row and the row is the first thing
          // below the safe area, so its top offset **is** the row's top padding. At
          // `kGeometrySurface` with no system inset the safe area contributes zero.
          expect(
            // The **button**, not the icon inside it: `IconActionButton` centres a
            // 20px glyph in its 44px box, so the icon's top sits 12px lower and
            // measuring it reads 32 for a padding of 20 — which is what the first
            // version of this assertion did, and it failed on both arms for the same
            // reason.
            tester.getTopLeft(find.byType(IconActionButton).first).dy,
            closeTo(
              ReadingControls.paddingFor(arm).top +
                  (arm == ReadingLanguage.arabic
                      ? ReadingPage.arabicBandHeight
                      : 0),
              0.5,
            ),
            reason:
                'plus the ARABIC arm\'s 5px geometric band, which '
                '`ReadingArScreen.tsx:13-16` puts above the controls row and the '
                'English arm does not have',
          );
        },
      );
    }

    testWidgets('the ARABIC band is 5 tall and 2-in-18, and ENGLISH has none', (
      WidgetTester tester,
    ) async {
      final ReadingHarness en = readingHarness();
      await pumpReading(tester, cubit: en.cubit);
      expect(
        bandDecoratedBox(tester),
        isNull,
        reason:
            'ReadingEnScreen.tsx has no such element at all — a structural '
            'difference, not a colour one',
      );

      final ReadingHarness ar = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));
      final DecoratedBox? bandBox = bandDecoratedBox(tester);
      expect(bandBox, isNotNull);
      final LinearGradient band =
          (bandBox!.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(band.tileMode, TileMode.repeated, reason: 'a 90deg repeat');
      expect(band.stops, <double>[
        0,
        2 / 18,
        2 / 18,
        1,
      ], reason: '2px of dash in an 18px pitch');
      expect(
        tester.getSize(find.byWidget(bandBox)).height,
        ReadingPage.arabicBandHeight,
      );
    });

    testWidgets("and the CTA's block padding is the prototype's", (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(StickyCta),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(24, 20, 24, 32));
    });
  });

  group('the per-arm RTL arrangement', () {
    testWidgets(
      'the back control MIRRORS, and the prototype child order is NOT reproduced',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit);

        final double backCentre = tester
            .getCenter(find.byIcon(Icons.arrow_back))
            .dx;
        final double aaCentre = tester
            .getCenter(find.byIcon(Icons.format_size))
            .dx;
        expect(
          backCentre,
          lessThan(aaCentre),
          reason: 'LTR: back on the left, the pair on the right',
        );

        final ReadingHarness ar = readingHarness(
          scripture: const Result<ScriptureText>.success(liveArabicPassage),
        );
        await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));
        final double arBack = tester
            .getCenter(find.byIcon(Icons.arrow_back))
            .dx;
        final double arAa = tester.getCenter(find.byIcon(Icons.format_size)).dx;
        expect(
          arBack,
          greaterThan(arAa),
          reason:
              'RTL: a TRUE mirror — back on the right. '
              '`ReadingArScreen.tsx:19-29` writes its children `[group, back]` under '
              '`direction: rtl`, which puts back on the LEFT while `:27` mirrors the '
              'chevron to point right. `ReadingControls` records the divergence.',
        );
      },
    );

    testWidgets('and the chevron flips with it', (WidgetTester tester) async {
      // `Icons.arrow_back` is `matchTextDirection: true`, so the ambient RTL mirrors
      // it and no second icon has to be chosen. The prototype draws two `<polyline>`s
      // for the same reason (`ReadingEnScreen.tsx:15` against `ReadingArScreen.tsx:27`).
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_back)).textDirection,
        isNull,
        reason: 'null means "follow the ambient direction", which is the whole point',
      );
    });
  });
}

/// The scripture [RichText]s, as **elements**, excluding [ReadingHeader]'s.
///
/// `Text` builds a `RichText`, so the header\'s three labels would otherwise be counted
/// as verses — which is what the first version of this helper did, and it returned
/// `NKJV (NEW KING JAMES VERSION)` for "verse one".
///
/// Elements and not widgets because the measurements below need
/// [WidgetTester.renderObject], and a finder built from a widget value can match a
/// *different* element after a rebuild.
List<Element> scriptureElements(WidgetTester tester) {
  final Set<Element> header = headerElements(tester);
  return <Element>[
    for (final Element element
        in find
            .descendant(
              of: find.byType(ScriptureBlock),
              matching: find.byType(RichText),
            )
            .evaluate())
      if (!header.contains(element) && _isVerseParagraph(element)) element,
  ];
}

/// Whether [element]'s `RichText` is a **verse paragraph**.
///
/// The second of the two things in the tree that are `RichText`s but not verses, and
/// it is the one an ancestry check cannot see: `PassageDropCap.span` returns a
/// `WidgetSpan` whose child is a `Text`, and **a `WidgetSpan` has no `Element`** — so
/// the drop cap's own `RichText` (`"T"`, `children == null`) has nothing in its
/// ancestry to distinguish it.
///
/// The distinction is mechanical and exact: a verse paragraph is the only `RichText`
/// on this screen whose span has **children**. The header's two labels are excluded by
/// [headerElements] and the drop cap by this.
bool _isVerseParagraph(Element element) {
  final InlineSpan text = (element.widget as RichText).text;
  return text is TextSpan && text.children != null;
}

/// The elements of [ReadingHeader]'s own `RichText`s.
///
/// ## AND WHY AN **ANCESTRY** CHECK CANNOT WORK HERE
///
/// `ScriptureBlock` takes the header as its item 0, so the header and the verses are
/// **siblings** inside one `ListView` — a verse's ancestors contain `ScriptureBlock`
/// and the `ListView` and nothing else. The first version of this helper asked
/// "is a `ReadingHeader` above me?", which is false for every verse **and** for every
/// header label, so it excluded nothing and "verse one" came back as
/// `NKJV (NEW KING JAMES VERSION)`.
///
/// So the header's elements are collected first and the verses are what is left.
/// `Text` builds a `RichText`, which is the only reason the two are ever mixed.
Set<Element> headerElements(WidgetTester tester) => <Element>{
  ...find
      .descendant(
        of: find.byType(ReadingHeader),
        matching: find.byType(RichText),
      )
      .evaluate(),
};

/// The body style of scripture paragraph [number].
TextStyle _bodyStyleOf(Element element) {
  final TextSpan span = (element.widget as RichText).text as TextSpan;
  return (span.children!.last as TextSpan).style!;
}

/// The verse marker's style on scripture paragraph [number].
///
/// **Index one, not zero, on the drop-cap paragraph.** The cap is a `WidgetSpan`
/// placed before the marker, so the first child of the Latin first paragraph is a
/// box and the second is the marker.
TextStyle _markerStyleOf(Element element) {
  final TextSpan span = (element.widget as RichText).text as TextSpan;
  final List<InlineSpan> children = span.children!;
  final InlineSpan marker = children.first is WidgetSpan
      ? children[1]
      : children.first;
  return (marker as TextSpan).style!;
}

/// The top of scripture paragraph [number], in global logical px.
double _verseTop(Element element) =>
    (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;

/// The bottom of scripture paragraph [number], in global logical px.
double _verseBottom(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset(0, box.size.height)).dy;
}

/// The Arabic band's own `DecoratedBox`, or `null`.
///
/// **Matched on [TileMode.repeated] and not on "has a gradient".** The first version
/// returned the *scrim* — `NeuralScaffold`'s `bottomFade` gradient is also a
/// `LinearGradient`, and it exists on both arms, so the "English has no band"
/// assertion found one and failed for a reason that had nothing to do with the band.
/// The band's is the only *tiled* gradient in the tree, which is also the one thing
/// that distinguishes `repeating-linear-gradient` from a plain one.
DecoratedBox? bandDecoratedBox(WidgetTester tester) {
  for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  )) {
    final Decoration decoration = box.decoration;
    if (decoration is! BoxDecoration) continue;
    final Gradient? gradient = decoration.gradient;
    if (gradient is LinearGradient && gradient.tileMode == TileMode.repeated) {
      return box;
    }
  }
  return null;
}
