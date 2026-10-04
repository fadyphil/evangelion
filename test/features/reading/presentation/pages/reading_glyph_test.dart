/// **Defect #2's site table for `/reading`, and the shared harness's screen gate
/// over the same tree.**
///
/// ## THIS FILE IS NOW THE **SCREEN-SPECIFIC HALF** OF A SHARED INSTRUMENT
///
/// Everything general — the rendered-tree walk, the tooltip painting, the Arabic
/// block predicate, the family and coverage assertions — is
/// `test/support/arabic_typography_gate.dart`, and every one of the six screens runs
/// it in `test/arabic_typography_test.dart`. Duplicating it here is what let
/// recorded decision 73 happen: the instrument existed and was applied to one screen,
/// and the other two built screens were mostly tofu with a green suite.
///
/// So what is left here is the part that is genuinely about `/reading` and about
/// nothing else:
///
/// * the **nine-site table**, which names each prototype line and what it wraps, and
///   asserts each site by *what it renders* rather than by a family constant;
/// * the **verse-marker walk**, which is reading-specific because the marker is a
///   `TextSpan` inside the paragraph and `find.byType(Text)` cannot see it;
/// * the **English control**, which is the one place `Space Mono` is the right answer
///   and saying so is the point.
///
/// The doc below records defect #2 in full, the under-count that produced it, and
/// the four bugs the walk had. **Those four were all found because a correct fix was
/// reported as wrong**, and the fifth was found in this phase's promotion; each has a
/// plant in `test/support/arabic_typography_gate_test.dart`.
///
/// | # | site | prototype | Arabic text it wraps |
/// | --- | --- | --- | --- |
/// | 1 | metadata row | `ReadingArScreen.tsx:35` | `التكوين · الإصحاح ١ · ٤ دقائق` |
/// | 2 | CTA caption | `ReadingArScreen.tsx:86` | `٥ أسئلة · دقيقة تقريبًا` |
/// | 3 | **every verse marker** | `ReadingArScreen.tsx:49,51,56,58,63,68,70` | `١`…`٧` in the **prototype**; this client renders `'${verse.number}'` — an `int`, so ASCII |
/// | 4 | **the citation** | `ReadingArScreen.tsx:41` | `البداية` |
/// | 5 | **the CTA label** | `ds.tsx:237` — `F.ui`, i.e. **DM Sans** | `ابدأ التأمل` |
/// | 6 | the scripture body | `ReadingArScreen.tsx:47` | — **already correct** (`F.arabic`) |
/// | 7 | **the back tooltip** | **not in the prototype at all** | `رجوع` |
/// | 8 | **the text-size tooltip** | **not in the prototype at all** | `حجم الخط` |
/// | 9 | **the bookmark tooltip** | **not in the prototype at all** | `إشارة مرجعية — غير متاح في هذه النسخة` |
///
/// Sites 3, 4 and 5 are **not** in the table. Site 5 is in a *shared component*, so
/// it would have hit `/quiz`'s Arabic arm too and this phase would never have seen it.
///
/// ## AND THE PROTOTYPE'S NINE WERE THE **FLOOR**, NOT THE CEILING
///
/// Sites 7–9 have **no prototype line**, because the prototype's four top controls
/// are bare `<button>`s with an inline `<svg>` and **no label of any kind**
/// (`ReadingEnScreen.tsx:14-16`, `ReadingArScreen.tsx:21-29`). §14 requires an
/// accessible name on an icon-only button, so this client had to invent three
/// strings — and an invented string inherits the *ambient* `TextTheme`, which is
/// `bodyMedium`, which is **DM Sans**.
///
/// So the correct count was never "`01-source-analysis.md`'s nine". It is
/// **everything the reader can see on the screen**.
///
/// ## FIVE BUGS THE WALK HAD, AND WHERE THEY ARE NOW DOCUMENTED AND PROVED
///
/// All five were found **because a correct fix was reported as wrong**, or because
/// the walk reported a correct render as broken. The three span-resolution ones are
/// documented in `arabic_typography_gate.dart`'s `_paintedRuns`, each with the plant
/// that fires it in `arabic_typography_gate_test.dart`:
///
/// 1. a `Tooltip` paints nothing until a gesture, so the walk is `Future`-returning;
/// 2. a `TextSpan` with no style of its own inherits its parent's;
/// 3. **a `TextSpan` that styles only some fields inherits the rest** — a `merge`,
///    and not a `??`; and the merge's base/other **order** is load-bearing, which the
///    first version of the repair got backwards;
/// 4. a `TextSpan` with children and no text of its own paints nothing, so it
///    contributes no run;
/// 5. the redundant `find.byType(Text)` pass, which double-reported every run with a
///    **worse** family than the `RichText` pass — `monospace` against `DMSans` for the
///    same run.
///
/// The sixth is not a walk bug but the finding that produced it: `MaterialApp`'s own
/// `DefaultTextStyle` is `_errorTextStyle`, whose family is `monospace`, and the probe
/// the old walk used read `textTheme.bodyMedium` instead. Both values are real and
/// they answer different questions; the harness's
/// `materialAppDefaultFamily` doc says which is which, because a reader who has just
/// measured one of them will otherwise "correct" the other.
///
/// ## WHY "NOT SPACE MONO" IS NOT THE ASSERTION, AND WHAT IS
///
/// The brief for this phase names the weaker form and then says why it is wrong:
/// "assert **no** `Text` widget in the AR tree has a `Space Mono` font family … and
/// assert the *specific* family each AR run uses (`EvaTypography.arabic`), because
/// 'not Space Mono' alone passes for `DMSans`, which also has no Arabic glyphs."
///
/// `font_coverage_test.dart` measures that: **Amiri is the only bundled family with
/// any Arabic glyph at all** — 1700 codepoints, 255 of them in U+0600–U+06FF, while
/// Cormorant Garamond, DM Sans, EB Garamond and Space Mono have **zero**. So
/// `not SpaceMono` would be satisfied by three families that render six tofu boxes
/// each. Both halves are asserted, plus a third that is stronger than either: every
/// character on the screen is covered by the family that renders it.
///
/// ## AND IT IS READ OFF THE **RENDERED** TREE, WHICH IS THE WHOLE OF PHASE 6'S
/// C1 LESSON
///
/// `today_reading_panel.dart` cited defect #2 as the reason it branched on language
/// and then built one `TextStyle` for both arms — the Arabic preview rendered in
/// `EBGaramond` and **1520 tests stayed green**, because nothing read a `fontFamily`
/// off the tree.
library;

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_header.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/arabic_typography_gate.dart';
import '../../../../support/reading_harness.dart';

void main() {
  group('the ARABIC arm', () {
    testWidgets('the NINE sites are each named by what they render', (
      WidgetTester tester,
    ) async {
      // The eight that were tofu, one assertion each, so a regression says **which
      // element** lost its family rather than "something did".
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      const ReadingStrings strings = ReadingStrings.ar();
      // Site 1 — the metadata row.
      expect(
        familyOfText(tester, liveArabicPassage.translation),
        EvaTypography.arabicFamily,
        reason: 'defect #2 site 1 — `ReadingArScreen.tsx:35`',
      );
      // Site 2 — the CTA caption, with Arabic-Indic digits in it.
      expect(
        familyOfText(
          tester,
          '${arabicIndicDigits(1)} ${strings.questionSingular}',
        ),
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 2 — `ReadingArScreen.tsx:86`, and the numeral is '
            'U+0661, which Space Mono does not carry either',
      );
      // Site 3 — a verse marker, read off the *span*, because the marker is inside the
      // paragraph and `find.byType(Text)` cannot see it.
      final InlineSpan marker = _verseMarkerSpan(tester, 1);
      expect(
        (marker as TextSpan).style!.fontFamily,
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 3 — `ReadingArScreen.tsx:49`. **The reason string used '
            'to say the digits are U+0661…U+0667 and that Space Mono carries neither, '
            'which described the PROTOTYPE and not this client**: the marker is '
            'a TextSpan over `verse.number`, an `int`, so what is on screen is '
            'ASCII. The family is still Amiri — the correct family for a marker in the '
            'Arabic arm is the one that renders Arabic — and the assertion is worth '
            'making; the justification was simply about a string that does not ship.',
      );
      // …and the marker really is ASCII digits, asserted so the reason string above
      // cannot rot back into describing the prototype. The one Arabic-Indic run in
      // this client is site 2's caption, through `arabicIndicDigits`.
      expect(
        scriptureMarkerTexts(tester),
        <String>['1', '2', '3', '4', '5'],
        reason: '`Verse.number` is an int; nothing renders U+0661…U+0667 here',
      );
      // Site 4 — the citation.
      expect(
        familyOfText(tester, liveArabicPassage.reference),
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 4 — `ReadingArScreen.tsx:41`, and NOT in the defect '
            'table: `F.display` is Cormorant Garamond, which has no Arabic block',
      );
      // Site 5 — the CTA label, through a *shared* component.
      expect(
        familyOfText(tester, strings.beginReflection),
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 5 — `ds.tsx:237` sets `F.ui` on every '
            '`ButtonPrimary`, and DM Sans has no Arabic glyphs. NOT in the defect '
            'table, and it is in `ds.tsx` rather than in a screen.',
      );
      // Sites 7, 8 and 9 — **the three control tooltips**, which have no prototype
      // line at all. Each is asserted against what it *paints*, so this is the
      // rendered family rather than the value a caller passed: `IconActionButton`'s
      // own `Tooltip(message: tooltip)` carried **no** `textStyle`, and Flutter
      // resolves a null one to `ThemeData.textTheme.bodyMedium` — measured `DMSans`
      // on **both** themes, which carries no Arabic glyph at all.
      //
      // The strings are looked up through the table rather than written out, and
      // each one is asserted to be **Arabic by the block test** — because
      // `رجوع` contains none of the four codepoints the first version of `_isArabic`
      // sampled, and a gate that cannot see the string cannot gate it.
      final Map<String, RenderedRun> painted = <String, RenderedRun>{
        for (final ({String message, RenderedRun run}) tooltip
            in await paintedTooltips(tester))
          tooltip.message: tooltip.run,
      };
      expect(
        painted,
        hasLength(3),
        reason:
            'three icon-only controls, so three tooltips; the prototype has none, '
            'and §14 requires a name on each',
      );
      for (final (String site, String message) in <(String, String)>[
        ('7 — the back control', strings.back),
        ('8 — the `Aa` control', strings.textSize),
        (
          '9 — the bookmark control',
          '${strings.bookmark} — ${strings.unavailableSuffix}',
        ),
      ]) {
        expect(
          containsArabic(message),
          isTrue,
          reason:
              'site $site: `"$message"` is what this gate has to recognise as '
              'Arabic, and the first version of the predicate sampled four '
              'codepoints this string contains none of',
        );
        expect(
          painted[message]?.family,
          EvaTypography.arabicFamily,
          reason:
              'defect #2 site $site — no prototype line, so `IconActionButton` '
              'inherited `bodyMedium`, which is DM Sans',
        );
      }
      // Site 6 — the scripture body, which the prototype already had right and which
      // is asserted so the eight fixes cannot have been made by breaking this one.
      expect(
        ScriptureBlock.familyFor(ReadingLanguage.arabic),
        EvaTypography.arabicFamily,
      );
    });
  });

  group('the ENGLISH arm, which is the control', () {
    testWidgets(
      'uses Space Mono for the marker and the caption, and nothing Arabic',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit);

        // The English marker KEEPS `monoFamily` — Space Mono carries U+0030…U+0039, so
        // an ASCII digit renders, and it is the prototype's own treatment
        // (`ReadingEnScreen.tsx:48`). The defect is not "mono is wrong", it is "mono
        // cannot draw these particular characters".
        expect(
          ScriptureBlock.markerFamilyFor(ReadingLanguage.english),
          EvaTypography.monoFamily,
        );
        expect(
          StickyCta.captionFamilyFor(ReadingLanguage.english),
          EvaTypography.monoFamily,
        );
        expect(
          ReadingHeader.metadataFamilyFor(ReadingLanguage.english),
          EvaTypography.monoFamily,
        );
        // …and the English citation keeps the display serif.
        expect(
          ReadingHeader.titleFamilyFor(ReadingLanguage.english),
          EvaTypography.displayFamily,
        );
        for (final RenderedRun run in await renderedRuns(tester)) {
          expect(
            containsArabic(run.label),
            isFalse,
            reason: 'the EN arm has no Arabic',
          );
        }
      },
    );

    test('and the per-arm families really are per-arm', () {
      // The reverse direction: every one of the five is a `switch`, and a `switch` with
      // one arm would pass every test above.
      expect(ReadingLanguage.english, isNot(ReadingLanguage.arabic));
      for (final (String label, String en, String ar)
          in <(String, String, String)>[
            (
              'the marker',
              ScriptureBlock.markerFamilyFor(ReadingLanguage.english),
              ScriptureBlock.markerFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the caption',
              StickyCta.captionFamilyFor(ReadingLanguage.english),
              StickyCta.captionFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the metadata row',
              ReadingHeader.metadataFamilyFor(ReadingLanguage.english),
              ReadingHeader.metadataFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the citation',
              ReadingHeader.titleFamilyFor(ReadingLanguage.english),
              ReadingHeader.titleFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the CTA label',
              StickyCta.ctaFamilyFor(ReadingLanguage.english),
              StickyCta.ctaFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the scripture body',
              ScriptureBlock.familyFor(ReadingLanguage.english),
              ScriptureBlock.familyFor(ReadingLanguage.arabic),
            ),
          ]) {
        expect(en, isNot(ar), reason: '$label is one family for both arms');
      }
    });
  });
}

/// The plain text of every verse marker on screen, in order.
///
/// A separate walk because the marker is a `TextSpan` inside the paragraph and
/// `find.text` cannot see it — the same reason `_verseMarkerSpan` exists.
List<String> scriptureMarkerTexts(WidgetTester tester) => <String>[
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  ))
    if (rich.text is TextSpan)
      for (final InlineSpan child
          in (rich.text as TextSpan).children ?? const <InlineSpan>[])
        if (child is TextSpan &&
            child.children == null &&
            (child.style?.fontWeight ?? FontWeight.normal) ==
                ScriptureBlock.markerWeight)
          child.text ?? '',
];

/// The verse-number span of scripture paragraph [number].
InlineSpan _verseMarkerSpan(WidgetTester tester, int number) {
  final InlineSpan body = _scriptureRichTexts(tester)[number - 1].text;
  final List<InlineSpan> children = (body as TextSpan).children!;
  return children.first is WidgetSpan ? children[1] : children.first;
}

/// Whether [element] is a verse paragraph rather than a header label or the drop cap's
/// own `Text`.
///
/// The header is excluded by identity above; the drop cap by this, because a
/// `WidgetSpan` has **no `Element`** so nothing in the drop-cap `Text`'s ancestry
/// distinguishes it, and a verse paragraph is the only `RichText` on this screen whose
/// span has children.
bool _isVerseParagraph(Element element) {
  final Widget widget = element.widget;
  if (widget is! RichText) return false;
  final InlineSpan text = widget.text;
  return text is TextSpan && text.children != null;
}

/// The scripture paragraphs, excluding the header's.
///
/// See `reading_page_test.dart`'s copy of this walk for why a `RichText` whose span
/// has **no children** is the drop cap's own `Text` and not a verse.
List<RichText> _scriptureRichTexts(WidgetTester tester) {
  final Set<Element> header = <Element>{
    ...find
        .descendant(
          of: find.byType(ReadingHeader),
          matching: find.byType(RichText),
        )
        .evaluate(),
  };
  return <RichText>[
    for (final Element element
        in find
            .descendant(
              of: find.byType(ScriptureBlock),
              matching: find.byType(RichText),
            )
            .evaluate())
      if (!header.contains(element) && _isVerseParagraph(element))
        element.widget as RichText,
  ];
}
