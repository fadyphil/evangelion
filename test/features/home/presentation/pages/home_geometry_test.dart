/// **Decision 8's harness, for `/`.** AGENT_CONTEXT §9, decision 8 names "the phase
/// that first transcribes a screen" as the owner of a prototype-comparison harness,
/// and says of the other screens: "Phases 6–9 should add each screen's own claims
/// rather than assume this generalises."
///
/// ## THE THREE HALVES, AND WHAT EACH ONE CANNOT SEE
///
/// 1. **A rule map** — every claim names an `eva/redesign.html` **selector**, and
///    the number that selector declares is parsed at test time. A renumbered
///    prototype turns this red instead of leaving it confidently checking a line
///    that moved, and a *renamed class* turns it red at the throw rather than
///    silently parsing nothing.
/// 2. **A symbol map** — a `null` rule map proves nothing about the widget.
///    `login_geometry_test.dart` measured that: changing `LoginPage.kTopSpacer`
///    from 72 to 71 left all 21 of its tests green. So every claim that has a
///    Dart constant names the **symbol**, and the constant is read.
/// 3. **Rendered geometry** — what `RenderBox` reports, compared against the
///    prototype's numbers rather than against the widget's own constants.
///
/// **What it still cannot see, stated here rather than left for Phase 10:** colours,
/// radii-as-tokens and blur sigmas are not geometry. `home_geometry_test.dart` says
/// so for the third half; this file's *first* half reaches colours only through
/// `library_catalogue_local_data_source_test.dart`, which reads the CSS's `--bh`
/// values straight out of `BOOKS`.
///
/// ## AND THE **COLLAPSED MARGINS** ARE THIS FILE'S REASON TO EXIST
///
/// CSS collapses adjacent vertical margins and Flutter has no such rule, so
/// `/`'s four inter-section gaps are **not** in the prototype as four numbers —
/// they are `max()` of six, and the six are. `HomePage`'s doc carries the table;
/// this file recomputes each `max` from the parsed margins and compares it with the
/// constant, which is the only way a reader can tell the table from an intention.
/// A harness that asserted `kCardGap == 14` against nothing would pass on any value
/// someone typed.
///
/// ## THE INLINE STYLES ARE A THIRD KIND OF CLAIM, AND THIS FILE NAMES THEM
///
/// `redesign.html:519` and `:524` write each card's wash as a `style="--bh:…"`
/// **attribute**, and `:528` writes the last-light hint's `margin-top:8px` the same
/// way. No CSS rule declares those numbers, so [inlineDeclarationsFor] reads the
/// attribute and the rows that use it are marked as inline in the table. The first
/// version of this file looked for them in a rule and got a `StateError` naming a
/// selector the prototype has never had — which is the throw doing its job.
library;

import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/greeting_block.dart';
import 'package:evangelion/features/home/presentation/widgets/last_light_card.dart';
import 'package:evangelion/features/home/presentation/widgets/library_carousel.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/home/presentation/widgets/streak_chip.dart';
import 'package:evangelion/features/home/presentation/widgets/verse_of_the_day_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/css_reference.dart';
import '../../../../support/home_harness.dart';

/// The prototype this harness reads. `eva/` is reference material and is never
/// written to (AGENT_CONTEXT §2, §8).
const String prototype = 'eva/redesign.html';

/// The home section's markup, as the file draws it: the section, its five children
/// and the ids that carry state. `eva/redesign.html:513-537`.
const List<String> homeSectionMarkers = <String>[
  'id="rHome"',
  'class="greet"',
  'id="dayMono"',
  'id="hiName"',
  'id="streakChip"',
  'id="flameEl"',
  'id="streakN"',
  'id="votdCard"',
  'id="votdRef"',
  'id="votdText"',
  'id="lastCard"',
  'id="lastRef"',
  'id="lastText"',
  'id="lastHint"',
  'id="selahCard"',
  'id="selahSub"',
  'id="selahBtn"',
  'class="car-label"',
  'id="libCount"',
  'id="carousel"',
];

/// The surface the rendered half uses.
///
/// 430×932 and not §14's 320×568: this file measures geometry the cards' own width
/// depends on, and at 320 the greeting's row and a card's caption wrap, which
/// changes every number being compared. §14's requirement is
/// `home_text_scale_test.dart`'s, and the two disagree on purpose.
const Size kGeometrySurface = Size(430, 932);

/// Every selector this file's claims name, for the anti-vacuity group.
const List<String> claimedSelectors = <String>[
  '.scroll',
  '.greet',
  '.greet .hi',
  '[dir=rtl] .greet .hi',
  '.streak',
  '.streak .sn',
  '.streak .sl',
  '.flame',
  '.hcard',
  '.hcard .tv',
  '.hcard .tv.small',
  '[dir=rtl] .hcard .tv',
  '.selah',
  '.selah .dt',
  '.selah .ds',
  '[dir=rtl] .selah .ds',
  '.breathing',
  '.car-label',
  '.carousel',
  '.bcard',
  '.bcard .bn',
  '.bcard .bc',
  '[dir=rtl] .bcard .bn',
  '[dir=rtl] .bcard .bc',
  '.bcard.sealed',
  '.bcard.sealed .bloom',
  '.bcard.sealed .bn',
  '.bcard.sealed .lock',
];

/// Reads the prototype and returns [selector]'s declarations — `cssRule`, under
/// this suite's shorter name. See `css_reference.dart` for the anchor and for why
/// a miss throws instead of returning `null`.
Map<String, String> rule(String selector) => cssRule(File(prototype), selector);

/// The numeric value of [property] in [declarations] — `cssPx` under this suite's
/// shorter name.
double px(Map<String, String> declarations, String property) =>
    cssPx(declarations, property);

/// Every length [property] declares, in CSS order — `cssPxList` under this suite's
/// shorter name. A shorthand needs this and not [px]: `padding: 22px 20px` reads as
/// `22` under [px], which is the **vertical** pair.
List<double> pxAll(Map<String, String> declarations, String property) =>
    cssPxList(declarations, property);

/// The inline `style="…"` declarations of the element whose id is [id].
///
/// **The third source of numbers, after a CSS rule and a Dart constant.** The two
/// cards declare their wash this way (`--bh`, `:519` and `:524`) and the
/// last-light hint its `margin-top` (`:528`), so no rule-based reader can reach
/// them.
///
/// ## WHY THE TAG IS FOUND FIRST AND THE ATTRIBUTE SECOND
///
/// Because **the attribute order is not fixed in the prototype**, and the first
/// version of this helper assumed it was: `:528` writes
/// `<div class="mono" style="…;margin-top:8px" id="lastHint" …>` — `style`
/// **before** `id` — while `:519` writes `id="votdCard"` **before** its `style`. A
/// single `id="…"[^>]*?style="…"` therefore reads one of the three and throws on the
/// other two, and it threw on `lastHint` during the first run of this suite.
///
/// So the tag is matched first — `<[^>]*id="…"` — and the `style` is read out of
/// *that tag's* text. It is 8 lines of regex rather than an HTML parser, and the
/// assumption it does make — that no tag containing these ids has a `>` inside an
/// attribute value — is true of every element in this file.
Map<String, String> inlineDeclarationsFor(String id) {
  final RegExpMatch? tag = RegExp('<[^>]*id="${RegExp.escape(id)}"[^>]*>')
      .firstMatch(File(prototype).readAsStringSync());
  if (tag == null) {
    throw StateError(
      '$id is not in $prototype any more. A card that lost its wash, or changed '
      'its id, is a change this harness must read.',
    );
  }
  final RegExpMatch? style = RegExp('style="([^"]*)"')
      .firstMatch(tag.group(0)!);
  if (style == null) {
    throw StateError(
      '#$id has no inline style in $prototype any more. A card that moved its '
      'wash into a rule, or lost it, is a change this harness must read — and one '
      'it cannot read through a CSS rule at all.',
    );
  }
  return <String, String>{
    for (final String declaration in style.group(1)!.split(';'))
      if (declaration.contains(':'))
        declaration.split(':').first.trim(): declaration
            .split(':')
            .skip(1)
            .join(':')
            .trim(),
  };
}

/// One transcription claim: what the prototype says, and the Dart constant it
/// became.
///
/// [property] is read from the rule [selector] names, or from the element's inline
/// style when [id] is given. [index] picks a value out of a shorthand — 1 is the
/// **horizontal** pair under CSS's top/right/bottom/left order.
typedef PrototypeClaim = ({
  String label,
  String? selector,
  String? id,
  String property,
  double expected,
  double actual,
});

void main() {
  // The claims, as data. Built at group-construction time rather than inside a
  // test, so a wrong prototype number fails every row rather than one of them.
  final Map<String, String> greet = rule('.greet');
  final Map<String, String> scroll = rule('.scroll');
  final Map<String, String> hcard = rule('.hcard');
  final Map<String, String> hcardTv = rule('.hcard .tv');
  final Map<String, String> hcardSmall = rule('.hcard .tv.small');
  final Map<String, String> hcardTvRtl = rule('[dir=rtl] .hcard .tv');
  final Map<String, String> streak = rule('.streak');
  final Map<String, String> streakSn = rule('.streak .sn');
  final Map<String, String> streakSl = rule('.streak .sl');
  final Map<String, String> flame = rule('.flame');
  final Map<String, String> selah = rule('.selah');
  final Map<String, String> selahDt = rule('.selah .dt');
  final Map<String, String> selahDs = rule('.selah .ds');
  final Map<String, String> selahDsRtl = rule('[dir=rtl] .selah .ds');
  final Map<String, String> breathing = rule('.breathing');
  final Map<String, String> carLabel = rule('.car-label');
  final Map<String, String> carousel = rule('.carousel');
  final Map<String, String> bcard = rule('.bcard');
  final Map<String, String> bn = rule('.bcard .bn');
  final Map<String, String> bc = rule('.bcard .bc');
  final Map<String, String> bnRtl = rule('[dir=rtl] .bcard .bn');
  final Map<String, String> bcRtl = rule('[dir=rtl] .bcard .bc');
  final Map<String, String> sealed = rule('.bcard.sealed');
  final Map<String, String> sealedBloom = rule('.bcard.sealed .bloom');
  final Map<String, String> sealedBn = rule('.bcard.sealed .bn');
  final Map<String, String> sealedLock = rule('.bcard.sealed .lock');

  group('the prototype file, as this harness reads it', () {
    test('exists, and still contains the home section', () {
      final String html = File(prototype).readAsStringSync();
      for (final String marker in homeSectionMarkers) {
        expect(
          html.contains(marker),
          isTrue,
          reason:
              'the home section lost `$marker`. The harness reads the prototype\'s '
              'own markup; a section that changed shape is a failure here before '
              'it is a silent drift in the page.',
        );
      }
    });

    test('every selector the claims name is still a rule', () {
      // The anti-vacuity half, and the rows below re-assert it through
      // [rule]'s throw. This one states it as one failure so a renamed class is
      // reported once rather than per row.
      for (final String selector in claimedSelectors) {
        expect(
          () => rule(selector),
          returnsNormally,
          reason: '$selector is named by a claim below',
        );
      }
    });

    test('the extraction reads more numbers than the claims consume', () {
      // A harness that reads fewer numbers than the prototype declares is
      // under-testing; one that reads more is at least looking at the whole file.
      int declared = 0;
      for (final String selector in claimedSelectors) {
        declared += rule(selector).length;
      }
      expect(
        declared,
        greaterThan(claimedSelectors.length * 2),
        reason:
            '$declared declarations across ${claimedSelectors.length} '
            'rules. The claims below read '
            '${claimedSelectors.length} of them; if this ever approaches the '
            'declared count, the rules hold nothing the harness has not already '
            'accounted for and the mapping is stale.',
      );
    });
  });

  group('the symbol map — the CSS is the number and the constant is the claim', () {
    final List<PrototypeClaim> claims = <PrototypeClaim>[
      // --- `.greet`, `:235` ----------------------------------------------------
      (
        label: "kGreetTop is `.greet`'s padding-top",
        selector: '.greet',
        id: null,
        property: 'padding',
        expected: pxAll(greet, 'padding')[0],
        actual: HomePage.kGreetTop,
      ),
      (
        label: "kGreetGutter is `.greet`'s padding **right**",
        selector: '.greet',
        id: null,
        property: 'padding',
        expected: pxAll(greet, 'padding')[1],
        actual: HomePage.kGreetGutter,
      ),
      (
        label: "kGreetBottom is `.greet`'s padding-bottom",
        selector: '.greet',
        id: null,
        property: 'padding',
        expected: pxAll(greet, 'padding')[2],
        actual: HomePage.kGreetBottom,
      ),
      // --- `.scroll`, `:157` ---------------------------------------------------
      (
        label: 'kScrollTop is `.scroll`\'s padding-top',
        selector: '.scroll',
        id: null,
        property: 'padding',
        expected: pxAll(scroll, 'padding')[0],
        actual: HomePage.kScrollTop,
      ),
      (
        label: "kScrollGutter is `.scroll`'s padding **right**",
        selector: '.scroll',
        id: null,
        property: 'padding',
        expected: pxAll(scroll, 'padding')[1],
        actual: HomePage.kScrollGutter,
      ),
      // --- `.greet .hi`, `:236-237` --------------------------------------------
      (
        label: "nameSize is `.greet .hi`'s font-size",
        selector: '.greet .hi',
        id: null,
        property: 'font-size',
        expected: px(rule('.greet .hi'), 'font-size'),
        actual: GreetingBlock.nameSize,
      ),
      (
        label: "nameSizeArabic is `[dir=rtl] .greet .hi`'s font-size",
        selector: '[dir=rtl] .greet .hi',
        id: null,
        property: 'font-size',
        expected: px(rule('[dir=rtl] .greet .hi'), 'font-size'),
        actual: GreetingBlock.nameSizeArabic,
      ),
      // --- `.streak`, `:238` ---------------------------------------------------
      (
        label: "flameSize is `.flame`'s **height**",
        selector: '.flame',
        id: null,
        property: 'height',
        expected: px(flame, 'height'),
        actual: StreakChip.flameSize,
      ),
      (
        label: "the chip's gap is `.streak`'s gap",
        selector: '.streak',
        id: null,
        property: 'gap',
        expected: px(streak, 'gap'),
        actual: StreakChip.gap,
      ),
      (
        label: "numberSize is `.streak .sn`'s font-size",
        selector: '.streak .sn',
        id: null,
        property: 'font-size',
        expected: px(streakSn, 'font-size'),
        actual: StreakChip.numberSize,
      ),
      (
        label: "unitSize is `.streak .sl`'s font-size",
        selector: '.streak .sl',
        id: null,
        property: 'font-size',
        expected: px(streakSl, 'font-size'),
        actual: StreakChip.unitSize,
      ),
      (
        label: "unitTracking is `.streak .sl`'s letter-spacing, in `em`",
        selector: '.streak .sl',
        id: null,
        property: 'letter-spacing',
        expected: _em(streakSl, 'letter-spacing'),
        actual: StreakChip.unitTracking,
      ),
      // --- `.hcard`, `:249-258` ------------------------------------------------
      (
        label: "the day's card radius is `.hcard`'s border-radius",
        selector: '.hcard',
        id: null,
        property: 'border-radius',
        expected: px(hcard, 'border-radius'),
        actual: VerseOfTheDayCard.radius,
      ),
      (
        label: "and the last-light card's is the same rule",
        selector: '.hcard',
        id: null,
        property: 'border-radius',
        expected: px(hcard, 'border-radius'),
        actual: LastLightCard.radius,
      ),
      (
        label: "the day's card vertical padding is `.hcard`'s padding-top",
        selector: '.hcard',
        id: null,
        property: 'padding',
        expected: pxAll(hcard, 'padding')[0],
        actual: VerseOfTheDayCard.padding.top,
      ),
      (
        label:
            "the day's card horizontal padding is `.hcard`'s padding **right**",
        selector: '.hcard',
        id: null,
        property: 'padding',
        expected: pxAll(hcard, 'padding')[1],
        actual: VerseOfTheDayCard.padding.left,
      ),
      (
        label: "the last-light card's padding is the same rule",
        selector: '.hcard',
        id: null,
        property: 'padding',
        expected: pxAll(hcard, 'padding')[0],
        actual: LastLightCard.padding.top,
      ),
      (
        label: "verseGap is `.hcard .tv`'s margin-top",
        selector: '.hcard .tv',
        id: null,
        property: 'margin',
        expected: px(hcardTv, 'margin'),
        actual: VerseOfTheDayCard.verseGap,
      ),
      (
        label: 'the verse size is `.hcard .tv`\'s font-size',
        selector: '.hcard .tv',
        id: null,
        property: 'font-size',
        expected: px(hcardTv, 'font-size'),
        actual: VerseOfTheDayCard.verseSize,
      ),
      (
        label: "the verse's Arabic size is `[dir=rtl] .hcard .tv`'s",
        selector: '[dir=rtl] .hcard .tv',
        id: null,
        property: 'font-size',
        expected: px(hcardTvRtl, 'font-size'),
        actual: VerseOfTheDayCard.verseSizeArabic,
      ),
      (
        label: "the empty arm's size is `.hcard .tv.small`'s font-size",
        selector: '.hcard .tv.small',
        id: null,
        property: 'font-size',
        expected: px(hcardSmall, 'font-size'),
        actual: LastLightCard.emptySize,
      ),
      // --- the hint's **inline** margin, `:528` --------------------------------
      (
        label: "hintGap is `#lastHint`'s inline margin-top",
        selector: null,
        id: 'lastHint',
        property: 'margin-top',
        expected: _inlinePx('lastHint', 'margin-top'),
        actual: LastLightCard.hintGap,
      ),
      // --- `.selah`, `:261-266` ------------------------------------------------
      (
        label: "the selah card's radius is `.selah`'s border-radius",
        selector: '.selah',
        id: null,
        property: 'border-radius',
        expected: px(selah, 'border-radius'),
        actual: SelahCard.radius,
      ),
      (
        label: "the selah card's vertical padding is `.selah`'s padding-top",
        selector: '.selah',
        id: null,
        property: 'padding',
        expected: pxAll(selah, 'padding')[0],
        actual: SelahCard.padding.top,
      ),
      (
        label: "the selah card's horizontal padding is `.selah`'s padding **right**",
        selector: '.selah',
        id: null,
        property: 'padding',
        expected: pxAll(selah, 'padding')[1],
        actual: SelahCard.padding.left,
      ),
      (
        label: "the selah card's gap is `.selah`'s gap",
        selector: '.selah',
        id: null,
        property: 'gap',
        expected: px(selah, 'gap'),
        actual: SelahCard.gap,
      ),
      (
        label: "titleSize is `.selah .dt`'s font-size",
        selector: '.selah .dt',
        id: null,
        property: 'font-size',
        expected: px(selahDt, 'font-size'),
        actual: SelahCard.titleSize,
      ),
      (
        label: "subtitleGap is `.selah .ds`'s margin-top",
        selector: '.selah .ds',
        id: null,
        property: 'margin-top',
        expected: px(selahDs, 'margin-top'),
        actual: SelahCard.subtitleGap,
      ),
      (
        label: "subtitleSize is `.selah .ds`'s font-size",
        selector: '.selah .ds',
        id: null,
        property: 'font-size',
        expected: px(selahDs, 'font-size'),
        actual: SelahCard.subtitleSize,
      ),
      (
        label: "subtitleTracking is `.selah .ds`'s letter-spacing",
        selector: '.selah .ds',
        id: null,
        property: 'letter-spacing',
        expected: _em(selahDs, 'letter-spacing'),
        actual: SelahCard.subtitleTracking,
      ),
      (
        label: "subtitleSizeArabic is `[dir=rtl] .selah .ds`'s font-size",
        selector: '[dir=rtl] .selah .ds',
        id: null,
        property: 'font-size',
        expected: px(selahDsRtl, 'font-size'),
        actual: SelahCard.subtitleSizeArabic,
      ),
      // --- `.breathing`, `:267-269` --------------------------------------------
      (
        label: "the circle's diameter is `.breathing`'s width",
        selector: '.breathing',
        id: null,
        property: 'width',
        expected: px(breathing, 'width'),
        actual: SelahCard.diameter,
      ),
      (
        label: 'and its height is the same number',
        selector: '.breathing',
        id: null,
        property: 'height',
        expected: px(breathing, 'height'),
        actual: SelahCard.diameter,
      ),
      (
        label: "rimWidth is `.breathing`'s border width",
        selector: '.breathing',
        id: null,
        property: 'border',
        expected: px(breathing, 'border'),
        actual: SelahCard.rimWidth,
      ),
      (
        label: "glyphSize is `.breathing`'s font-size",
        selector: '.breathing',
        id: null,
        property: 'font-size',
        expected: px(breathing, 'font-size'),
        actual: SelahCard.glyphSize,
      ),
      // --- `.car-label` and `.carousel`, `:272-273` ---------------------------
      (
        label: "labelGap is `.car-label`'s margin-top",
        selector: '.car-label',
        id: null,
        property: 'margin',
        expected: pxAll(carLabel, 'margin')[0],
        actual: HomePage.kLabelGap,
      ),
      (
        label: "labelInset is `.car-label`'s margin **right**",
        selector: '.car-label',
        id: null,
        property: 'margin',
        expected: pxAll(carLabel, 'margin')[1],
        actual: LibraryCarousel.labelInset,
      ),
      (
        label: "stripGutter is `.carousel`'s padding **right**",
        selector: '.carousel',
        id: null,
        property: 'padding',
        expected: pxAll(carousel, 'padding')[1],
        actual: LibraryCarousel.stripGutter,
      ),
      (
        label: "cardGap is `.carousel`'s gap",
        selector: '.carousel',
        id: null,
        property: 'gap',
        expected: px(carousel, 'gap'),
        actual: LibraryCarousel.cardGap,
      ),
      (
        label: "cardWidth is `.bcard`'s **third** flex value, the basis",
        selector: '.bcard',
        id: null,
        property: 'flex',
        // `flex: 0 0 168px` — three numbers, and the basis is the **third**. Reading
        // the first with `px` returns `0`, which is the value `cssPxList` is for.
        expected: pxAll(bcard, 'flex')[2],
        actual: LibraryCarousel.cardWidth,
      ),
      (
        label: "cardHeight is `.bcard`'s height",
        selector: '.bcard',
        id: null,
        property: 'height',
        expected: px(bcard, 'height'),
        actual: LibraryCarousel.cardHeight,
      ),
      (
        label: "cardRadius is `.bcard`'s border-radius",
        selector: '.bcard',
        id: null,
        property: 'border-radius',
        expected: px(bcard, 'border-radius'),
        actual: LibraryCarousel.cardRadius,
      ),
      (
        label: "cardPadding is `.bcard`'s padding",
        selector: '.bcard',
        id: null,
        property: 'padding',
        expected: px(bcard, 'padding'),
        actual: LibraryCarousel.cardPadding.top,
      ),
      (
        label: "titleSize is `.bcard .bn`'s font-size",
        selector: '.bcard .bn',
        id: null,
        property: 'font-size',
        expected: px(bn, 'font-size'),
        actual: LibraryCarousel.titleSize,
      ),
      (
        label: "the title's Arabic size is `[dir=rtl] .bcard .bn`'s",
        selector: '[dir=rtl] .bcard .bn',
        id: null,
        property: 'font-size',
        expected: px(bnRtl, 'font-size'),
        actual: LibraryCarousel.titleSizeArabic,
      ),
      (
        label: "captionSize is `.bcard .bc`'s font-size",
        selector: '.bcard .bc',
        id: null,
        property: 'font-size',
        expected: px(bc, 'font-size'),
        actual: LibraryCarousel.captionSize,
      ),
      (
        label: "captionTracking is `.bcard .bc`'s letter-spacing",
        selector: '.bcard .bc',
        id: null,
        property: 'letter-spacing',
        expected: _em(bc, 'letter-spacing'),
        actual: LibraryCarousel.captionTracking,
      ),
      (
        label: "the caption's Arabic size is `[dir=rtl] .bcard .bc`'s",
        selector: '[dir=rtl] .bcard .bc',
        id: null,
        property: 'font-size',
        expected: px(bcRtl, 'font-size'),
        actual: LibraryCarousel.captionSizeArabic,
      ),
      // --- the sealed card, `:284-288` ----------------------------------------
      // `.bcard.sealed .bn{color: var(--ink-2)}` declares no length, so it has no
      // row here; the *ink* is asserted where colours are asserted — the card test's
      // `ink2` claim in `home_page_test.dart` — and `sealedBn` is read below so a
      // rename of that selector is still a failure here.
      (
        label: "sealedWashFactor is `.bcard.sealed .bloom`'s opacity",
        selector: '.bcard.sealed .bloom',
        id: null,
        property: 'opacity',
        expected: px(sealedBloom, 'opacity'),
        actual: LibraryCarousel.sealedWashFactor,
      ),
      (
        label: "the badge's size is `.bcard.sealed .lock`'s font-size",
        selector: '.bcard.sealed .lock',
        id: null,
        property: 'font-size',
        expected: px(sealedLock, 'font-size'),
        actual: LibraryCarousel.sealSize,
      ),
      (
        label: "the badge's tracking is `.bcard.sealed .lock`'s letter-spacing",
        selector: '.bcard.sealed .lock',
        id: null,
        property: 'letter-spacing',
        expected: _em(sealedLock, 'letter-spacing'),
        actual: LibraryCarousel.sealTracking,
      ),
      (
        label: "the badge's horizontal padding is `.bcard.sealed .lock`'s **right**",
        selector: '.bcard.sealed .lock',
        id: null,
        property: 'padding',
        expected: pxAll(sealedLock, 'padding')[1],
        actual: LibraryCarousel.sealPadding.right,
      ),
      (
        label: "the badge's vertical padding is `.bcard.sealed .lock`'s padding-top",
        selector: '.bcard.sealed .lock',
        id: null,
        property: 'padding',
        expected: pxAll(sealedLock, 'padding')[0],
        actual: LibraryCarousel.sealPadding.top,
      ),
    ];

    for (final PrototypeClaim claim in claims) {
      test(claim.label, () {
        expect(
          claim.actual,
          claim.expected,
          reason:
              '${claim.selector ?? 'the inline style of #${claim.id}'}'
              ' declares ${claim.property}, and the constant is the claim.',
        );
      });
    }

    test('the card radius is also `EvaRadii.heroPanel`, and that is 24', () {
      // The join between the CSS and the token §5.3 published "for Home's
      // today's-reading panel **by name**". If either moves, the other stops being
      // a transcription and becomes a coincidence.
      expect(VerseOfTheDayCard.radius, EvaRadii.heroPanel);
      expect(EvaRadii.heroPanel, px(hcard, 'border-radius'));
    });

    test(
      "the pill's radius is `EvaRadii.chip`, and the CSS's 99 means the same",
      () {
        // `redesign.html:238` writes `border-radius: 99px` and §5.3's token is `999`.
        // A pill's radius only has to be at least half its longest side, and the chip
        // is 33 tall, so the two are the same shape — which is why the widget uses the
        // token rather than a local `99`. Asserted from both sides so the token cannot
        // be mistaken for the source.
        expect(_radiusPx(streak, 'border-radius'), 99.0);
        expect(EvaRadii.chip, greaterThanOrEqualTo(99.0));
      },
    );
  });

  group('the four collapsed gaps, recomputed from the prototype', () {
    // CSS collapses adjacent vertical margins and Flutter has no such rule, so the
    // gaps are `max()` of two numbers each and the numbers are in the CSS. Each row
    // below recomputes the `max` from the parsed margins and compares it with the
    // constant — which is the only way a reader can tell `HomePage`'s table from an
    // intention.
    final double hcardMarginTop = pxAll(hcard, 'margin')[0];
    final double hcardMarginBottom = pxAll(hcard, 'margin')[2];
    // `.selah{margin: 8px 14px}` — **two** values, not three: the vertical pair is
    // the first and the horizontal pair the second, so the bottom is index **0**. The
    // first version read index 2 and this suite refused to load with a
    // `RangeError(0..1)`, which is the throw doing its job on a shorthand read the
    // wrong way round.
    final double selahMarginTop = pxAll(selah, 'margin')[0];
    final double selahMarginBottom = pxAll(selah, 'margin')[0];
    final double labelMarginTop = pxAll(carLabel, 'margin')[0];
    final double labelMarginBottom = pxAll(carLabel, 'margin')[2];
    final double carouselPaddingTop = pxAll(carousel, 'padding')[0];
    final double carouselPaddingBottom = pxAll(carousel, 'padding')[2];
    final double scrollPaddingTop = pxAll(scroll, 'padding')[0];
    final double scrollPaddingBottom = pxAll(scroll, 'padding')[2];

    test('the greeting-to-card gap is additive, because a padding blocks a collapse', () {
      // `.greet`'s padding-bottom, `.scroll`'s padding-top and `.hcard`'s
      // margin-top: paddings never collapse, so this one is a **sum**, and the
      // distinction from the four below is the whole content of this group.
      expect(
        HomePage.kGreetToCardGap,
        HomePage.kGreetBottom + scrollPaddingTop + hcardMarginTop,
      );
      expect(HomePage.kGreetToCardGap, greaterThan(hcardMarginTop));
    });

    test('between the two cards it is `max(8, 14)`', () {
      expect(HomePage.kCardGap, greaterThanOrEqualTo(hcardMarginBottom));
      expect(HomePage.kCardGap, greaterThanOrEqualTo(hcardMarginTop));
      expect(
        HomePage.kCardGap,
        hcardMarginBottom > hcardMarginTop ? hcardMarginBottom : hcardMarginTop,
        reason: 'CSS collapses to the LARGER of the two margins',
      );
      // **And not the sum**, which is what a naive port would have written.
      expect(HomePage.kCardGap, isNot(hcardMarginBottom + hcardMarginTop));
    });

    test('the selah card follows the last card by `max(8, 8)`', () {
      expect(
        HomePage.kSelahGap,
        selahMarginTop > hcardMarginBottom ? selahMarginTop : hcardMarginBottom,
      );
    });

    test('the label follows the selah card by `max(8, 20)`', () {
      expect(
        HomePage.kLabelGap,
        labelMarginTop > selahMarginBottom ? labelMarginTop : selahMarginBottom,
      );
      // The label's own top margin is the *winner* here, which is why
      // `LibraryCarousel.labelGap` and `HomePage.kLabelGap` are the same number in
      // two files: the strip's 4px padding-top is inside its own box and loses.
      expect(HomePage.kLabelGap, greaterThan(carouselPaddingTop));
    });

    test('the strip follows the label by `max(10, 4)`', () {
      expect(
        LibraryCarousel.labelBottomGap,
        labelMarginBottom > carouselPaddingTop
            ? labelMarginBottom
            : carouselPaddingTop,
      );
      expect(HomePage.kStripGap, LibraryCarousel.labelBottomGap);
    });

    test(
      'and the bottom clearance is the carousel\'s padding plus the scroll\'s',
      () {
        expect(
          HomePage.kBottomClearance,
          carouselPaddingBottom + scrollPaddingBottom,
        );
      },
    );

    test("the sealed title's rule exists even though it declares no length", () {
      // `:286` — `.bcard.sealed .bn{color: var(--ink-2)}`. Colours are outside this
      // file's subject (its own library doc says so), and a rule that declares none
      // still has to be *reachable*, or a rename would move a widget's ink with
      // nothing here going red.
      expect(sealedBn['color'], 'var(--ink-2)');
    });

    test("the sealed card's own `.8` is NOT applied, and this says why", () {
      // `redesign.html:284` — `.bcard.sealed{opacity:.8}` — and
      // `LibraryCarousel.sealedCardOpacity` is the recorded number the widget
      // deliberately does not use. **This row exists so the constant cannot be
      // deleted as dead code**, which is what a reader would do without it, and
      // so the divergence stays visible in the harness rather than only in a
      // widget's doc comment.
      expect(px(sealed, 'opacity'), LibraryCarousel.sealedCardOpacity);
      expect(LibraryCarousel.sealedCardOpacity, 0.8);
    });
  });

  group('the geometry the rule map cannot reach', () {
    testWidgets('the flame is 17 tall and 13.6 wide, not 13', (
      WidgetTester tester,
    ) async {
      // `:242` declares `width: 13px; height: 17px`. The **height** is adopted
      // (`StreakChip.flameSize`, asserted above from the same rule) and the width
      // is this widget's own viewBox ratio: `streak_flame.dart`'s doc records that
      // the CSS *blob* — `border-radius: 50% 50% 46% 46%/62% 62% 38% 38%` — is not
      // adopted, and reproducing a 13px width would mean an anisotropic stretch of
      // the path.
      //
      // 0.6px is 4.6% of the width, and the assertion is a **range** rather than a
      // float equality because the rendered box comes out of a `CustomPaint` whose
      // size is computed, not measured.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Size painted = tester.getSize(find.byType(StreakFlame));
      expect(painted.height, 17.0, reason: "`.flame`'s height, verbatim");
      expect(painted.width, closeTo(13.6, 0.01), reason: '17 × 16/20');
      expect(
        px(flame, 'width'),
        13.0,
        reason: 'and the CSS says 13, which is the divergence this row records',
      );
    });

    testWidgets(
      "the greeting's row gap is the one number `.greet` does not declare",
      (WidgetTester tester) async {
        // `:235` has `display: flex; justify-content: space-between` and **no `gap`**,
        // so `GreetingBlock.nameToChipGap` is written rather than transcribed — and a
        // written number needs a rendered assertion, which is this row.
        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

        expect(
          greet.containsKey('gap'),
          isFalse,
          reason:
              'if `.greet` grows a `gap`, the constant becomes a transcription and '
              'this row becomes a symbol-map row instead',
        );
        // **A minimum, not an equality — and the first version asserted an equality
        // and read 187.** The name block is `Expanded`, so it takes every pixel the
        // row has left after the pill; the *text* inside it is only as wide as the
        // greeting, and the visible gap between the text's end and the pill is
        // whatever the surface has spare. At 430 wide that is 187, and none of it is
        // `nameToChipGap`.
        //
        // What the constant buys is the **worst** case: a long display name on a 320
        // screen, where the name block is full and the gap is the constant itself.
        // That case is `home_text_scale_test.dart`'s; what is asserted here is that
        // the prototype says nothing, the constant is positive, and the two children
        // never touch.
        final Rect name = tester.getRect(find.text('peace, David'));
        final Rect chip = tester.getRect(find.byType(StreakChip));
        expect(chip.left, greaterThan(name.right));
        expect(GreetingBlock.nameToChipGap, greaterThan(0));
        // And the greeting is **one line** even when the name is long: `maxLines: 1`
        // is what stops it wrapping onto a second line under the chip.
        expect(name.height, lessThan(40));
      },
    );

    testWidgets(
      'and the chip is vertically centred, which is `align-items: center`',
      (WidgetTester tester) async {
        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

        // **Against the row, not against the name.** The first version compared the
        // chip's centre with the *greeting text*'s and read 9.0, which is not a
        // divergence: `align-items: center` centres a child against the row's cross
        // axis, and the row is 48 tall (a 16px caption, a 2px gap, a 30px name) while
        // the name occupies only its own 30 of those 48. The chip lands at
        // 54 + (48 - 33) / 2 = 61.5 and the row's centre is 78.
        final Rect chip = tester.getRect(find.byType(StreakChip));
        final Rect row = tester.getRect(find.byType(GreetingBlock));
        expect(
          (chip.center.dy - row.center.dy).abs(),
          lessThan(0.01),
          reason: '`align-items: center` centres against the row',
        );
        expect(
          row.top,
          54.0,
          reason: "and the row starts at `.greet`'s padding-top",
        );
      },
    );
  });

  group('the rendered geometry', () {
    testWidgets('the greeting sits at 20 and the cards at 28', (
      WidgetTester tester,
    ) async {
      // `.greet`'s gutter is 20 (`:235`) and `.scroll`'s is 14 (`:157`) with each
      // card's own `margin … 14px` (`:249`) inside it, so the visible edges are 20
      // and **28**. The second number is the one a single scaffold padding cannot
      // produce, which is why `NeuralScaffold(padding: EdgeInsets.zero)` and the two
      // per-section paddings.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      expect(tester.getTopLeft(find.text('GOOD MORNING')).dx, 20.0);
      expect(tester.getTopLeft(find.byType(VerseOfTheDayCard)).dx, 28.0);
      expect(tester.getTopLeft(find.byType(LastLightCard)).dx, 28.0);
      expect(tester.getTopLeft(find.byType(SelahCard)).dx, 28.0);
    });

    testWidgets('the greeting\'s top padding is 54', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);
      expect(tester.getTopLeft(find.text('GOOD MORNING')).dy, 54.0);
    });

    testWidgets("the day's card paints at 22 by 20 inside its own box", (
      WidgetTester tester,
    ) async {
      // Measured **relative to the card**, not to the screen, so the assertion holds
      // whatever the scroll offset is.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Rect card = tester.getRect(find.byType(VerseOfTheDayCard));
      final Rect eyebrow = tester.getRect(
        find.textContaining('VERSE OF THE DAY'),
      );
      expect(eyebrow.left - card.left, 20.0);
      expect(eyebrow.top - card.top, 22.0);
    });

    testWidgets('and the last-light card paints at the same inset', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Rect card = tester.getRect(find.byType(LastLightCard));
      final Rect eyebrow = tester.getRect(find.textContaining('LAST LIGHT'));
      expect(eyebrow.left - card.left, 20.0);
      expect(eyebrow.top - card.top, 22.0);
    });

    testWidgets('the chip paints at 11 by 7 around the flame', (
      WidgetTester tester,
    ) async {
      // `.streak`'s padding is `7px 14px 7px 11px` (`:238`) — **top/right/bottom/
      // left**, so the leading pad is 11 and the trailing 14, and a port that read
      // the shorthand as symmetric would paint the flame 3px right of where the
      // prototype puts it.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Offset pill = tester.getTopLeft(find.byType(StreakChip));
      final Offset flame = tester.getTopLeft(find.byType(StreakFlame));
      // **12 and 8, not 11 and 7**, because `.streak`'s `border: 1px solid` is
      // *inside* the pill's box and CSS padding is inside the border too — so the
      // flame sits one pixel further out than the padding alone would put it. The
      // first version of this row asserted 11 and 7 and the tree said 12 and 8,
      // which is the relationship the prototype has and a transcription of the
      // padding alone would have lost.
      expect(flame.dx - pill.dx, StreakChip.padding.left + 1.0);
      expect(flame.dy - pill.dy, StreakChip.padding.top + 1.0);
    });

    testWidgets('the verse sits the prototype\'s 10 below the eyebrow', (
      WidgetTester tester,
    ) async {
      // `.hcard .tv`'s `margin: 10px 0 0` (`:258`), and **line boxes**: the gap is
      // measured from the eyebrow's bottom edge to the verse's top edge, which is
      // the margin plus nothing — a `Text`'s box is its line box and there is no
      // descender space inside it.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Rect eyebrow = tester.getRect(
        find.textContaining('VERSE OF THE DAY'),
      );
      final Rect verse = tester.getRect(find.textContaining('Nicodemus'));
      expect(verse.top - eyebrow.bottom, 10.0);
    });

    testWidgets('the circle is 44 square', (WidgetTester tester) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      // **The `Container`, not the glyph**: reading the circle's size off the
      // glyph asserted that a circle is a glyph. The circle is the 44px box, and
      // the star inside it is PAINTED (`FourPointedStar`, shared with
      // `/reading`'s `:544` bookmark button), not typed — U+2726 is in no bundled
      // family, which `arabic_typography_test.dart` measured before this row was
      // written — so the finder is on the widget, not on a `CustomPaint`.
      //
      // **And the star's own size is read off the rendered box**, where the
      // selector below used to read `w.size == const Size.square(11.0)` off the
      // painter's *declaration*. A predicate that matches a widget's field is a
      // claim about the constructor argument; `getSize` is a claim about what the
      // engine laid out, and only the second one can catch a box that stops
      // being the one the prototype names.
      final Finder star = find
          .descendant(
            of: find.byType(SelahCard),
            matching: find.byType(FourPointedStar),
          )
          .first;
      expect(star, findsOneWidget);
      expect(tester.getSize(star), const Size.square(SelahCard.glyphSize));
      // ## THE **LAYOUT** SIZE, AND NOT THE PAINTED ONE
      //
      // `getSize` reads the render object's `size` — the box the engine laid
      // out — and `getRect` reads `localToGlobal`, which **includes the paint
      // transform**.
      //
      // The difference is the ring: `eva/redesign.html:270`'s `breatheRing`
      // scales the circle between `.92` and `1.06`, and Phase 7 gave the client
      // that animation. The prototype's circle is the same: `:267` gives it
      // `width:44px;height:44px` — the **layout** box — and the keyframes
      // scale the painting of it.
      //
      // So the layout box is 44 and the painted box breathes, and asserting
      // the painted one would be asserting one frame of an animation.
      final Finder circle = find
          .ancestor(of: star, matching: find.byType(Container))
          .first;
      expect(tester.getSize(circle), const Size(44, 44));
      expect(
        tester.getRect(star).height,
        lessThan(44),
        reason: 'the glyph is smaller than the button that draws it',
      );
    });

    testWidgets('a book card is 168 by 132 with a 16 inset', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      expect(tester.getSize(find.text('psalms')), isNotNull);
      final Rect card = tester.getRect(
        find
            .ancestor(
              of: find.text('psalms'),
              matching: find.byType(GlassSurface),
            )
            .first,
      );
      expect(card.size.width, 168.0);
      expect(card.size.height, 132.0);

      final Rect title = tester.getRect(find.text('psalms'));
      expect(title.left - card.left, 16.0);
      // `.bcard` is `flex-direction: column; justify-content: space-between`, so the
      // caption is on the **bottom** inset: 132 − 16 − the caption's own height.
      final Rect caption = tester.getRect(find.text('POETRY · 6 VERSES'));
      expect(card.bottom - caption.bottom, 16.0);
    });

    testWidgets(
      'the strip\'s gap is 12 and the label\'s inset is 18 more than it',
      (WidgetTester tester) async {
        // `.carousel`'s `gap: 12px` (`:273`) and `.car-label`'s `margin: 20px 18px
        // 10px` (`:272`) — the label sits **4px** further in than the cards, because
        // the scroll's own gutter is 14 and the label's is 18.
        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

        // **The card's box, not its title.** The first version compared the label's
        // text with the card's *text* and read 6, which is a difference between two
        // things the prototype never compares: the label sits 18 in from the scroll's
        // gutter and the card 14, so the label is **4** further in than the card's
        // edge — while the card's own 16px padding puts its title 12 further in than
        // the label. Both are true and only one of them is `.car-label`'s margin.
        final Rect label = tester.getRect(find.text('THE LIBRARY'));
        final Rect card = tester.getRect(
          find
              .ancestor(
                of: find.text('psalms'),
                matching: find.byType(GlassSurface),
              )
              .first,
        );
        // The label sits `18` in from the scroll's gutter and a card `14 + 14` in —
        // 18 and 28 from the screen's edge, so the label is **4** further in.
        expect(
          label.left - card.left,
          LibraryCarousel.labelInset - LibraryCarousel.stripGutter,
        );
        expect(label.left - card.left, 4.0);
        expect(card.left, HomePage.kScrollGutter + LibraryCarousel.stripGutter);
      },
    );

    testWidgets(
      'and the whole strip is the card height, with no vertical padding',
      (WidgetTester tester) async {
        // `.carousel`'s `padding: 4px 14px 12px` (`:273`) — the 4px top is the page's
        // own `labelBottomGap` winner (10 > 4) and the 12px bottom is the page's
        // `kBottomClearance`, so the strip itself is exactly one card tall.
        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

        final Size strip = tester.getSize(
          find
              .descendant(
                of: find.byType(LibraryCarousel),
                matching: find.byType(ListView),
              )
              .first,
        );
        expect(strip.height, LibraryCarousel.cardHeight);
      },
    );
  });
}

/// `letter-spacing: .14em` as a bare multiplier, for the rows that compare it with a
/// Dart `double`.
///
/// **A multiplier and not pixels**, because the CSS's unit is the element's own
/// `font-size` and Flutter's `letterSpacing` is also in logical pixels — so the two
/// agree only as a ratio. `login_geometry_test.dart`'s wordmark row converts `.3em`
/// at its call site for the same reason, and this helper is that conversion's other
/// half: it reads the number and lets the caller decide what it multiplies.
double _em(Map<String, String> declarations, String property) {
  final String raw = declarations[property]!;
  // **A leading dot is a number.** `letter-spacing: .14em` has no digit before the
  // point, so `(-?\d+(?:\.\d+)?)em` matches the `14` alone and every tracking row
  // fails by a factor of 100 — which is what the first run of this suite reported,
  // and why `cssPxList`'s regex has the same alternation.
  final RegExpMatch match = RegExp(r'(-?(?:\d+(?:\.\d+)?|\.\d+))em')
      .firstMatch(raw)!;
  return double.parse(match.group(1)!);
}

/// `border-radius: 99px` as a double, without the `cssPx` name it would shadow.
double _radiusPx(Map<String, String> declarations, String property) =>
    cssPx(declarations, property);

/// One inline declaration, as a double.
double _inlinePx(String id, String property) =>
    cssPx(inlineDeclarationsFor(id), property);
