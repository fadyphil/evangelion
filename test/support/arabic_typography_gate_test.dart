/// **The harness's own anti-vacuity suite, and every guard proved by a plant.**
///
/// ## WHY THE GATE NEEDS A GATE
///
/// §7: "A gate has to be able to fail before you may believe it passes." A harness
/// that walks the wrong tree, paints nothing, or recognises no Arabic reports
/// **success** on a screen full of tofu — and that is not a hypothetical. All four
/// guards below exist because this walk shipped broken once and reported a **correct
/// fix as wrong** (a tooltip the app had rendered in Amiri, reported as `DMSans`).
///
/// So every guard is proved here by **planting the defect** and asserting the
/// detection, rather than by asserting that the harness's own output looks right. An
/// assertion about the harness's happy path cannot fail for the reason that matters.
///
/// ## THE FOUR GUARDS, AND WHAT EACH ONE PROVES
///
/// | guard | the plant | the claim it refutes |
/// | --- | --- | --- |
/// | [G1] tooltips are painted | a `Tooltip` with no `textStyle` | "the walk reads the rendered tree", which is true of a tree a `Tooltip` has not built |
/// | [G2] spans resolve the way the engine resolves them | Flutter's exact `Tooltip` span shape, plus a **partially** styled child | "`span.style ?? inherited` is the engine's rule" — it is a **`merge`** |
/// | [G3] Arabic is a **block range** | `رجوع`, which contains none of the four sampled codepoints | "the predicate knows Arabic" |
/// | [G4] the ambient probe is total | a tree with **no `Text` at all** | "the fallback probe cannot throw" |
///
/// ## AND [G5], WHICH IS THE ONE THAT MATTERS MOST
///
/// A screen with **no Arabic runs** makes "every Arabic run is Amiri" vacuously
/// true, and three of the six screens are in exactly that state today. This file
/// proves the harness **detects** a wrong-family Arabic run when one is planted, so
/// the vacuous gates in `test/arabic_typography_test.dart` are gates that would fire
/// rather than gates that merely do not.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/arabic_typography_gate.dart';
import '../support/design_system_harness.dart';
import '../support/font_coverage.dart';

/// `رجوع` — the back control's Arabic label.
///
/// **None of the four codepoints the first version of the predicate sampled**
/// (`0x0628 ب`, `0x0644 ل`, `0x064Eَ`, `0x0665 ٥`), which is why thirty tofu boxes
/// shipped behind a green gate.
const String backLabel = 'رجوع';

void main() {
  group('G1 — the walk PAINTS a tooltip, because a tooltip paints nothing until a '
      'gesture', () {
    testWidgets('a `Tooltip` with no `textStyle` is found, painted, and reported '
        'in the engine fallback family', (WidgetTester tester) async {
      // The exact defect `IconActionButton` shipped for three screens: a message and
      // **no `textStyle`**. Flutter builds the content as
      // `TextSpan(style: effective, children: [TextSpan(text: message)])`, so the
      // family comes from the ambient style and the text from the child.
      await _pump(
        tester,
        const Tooltip(
          message: backLabel,
          child: SizedBox(width: 44, height: 44),
        ),
      );

      // Nothing is on screen yet — this is the assertion that makes the walk's
      // `Future` necessary rather than stylistic.
      expect(find.text(backLabel), findsNothing);

      final List<({String message, RenderedRun run})> painted =
          await paintedTooltips(tester);
      expect(painted, hasLength(1));
      expect(painted.single.message, backLabel);
      // **`DMSans`, measured** — and *not* `MaterialApp`'s own `_errorTextStyle`
      // family, which is `monospace`. The tooltip's content is built inside the
      // `Material`, and `Material` installs `bodyMedium`, so `bodyMedium` is the
      // real resolution. Decision 71's documented mechanism is therefore correct and
      // is asserted here so it cannot be "corrected" a second time in the other
      // direction by a reader who has just measured `monospace` from the outermost
      // provider and mistaken it for this.
      expect(
        painted.single.run.family,
        'DMSans',
        reason: 'the value decision 71 measured, and the family the gate exists to catch.',
      );
      expect(
        painted.single.run.family,
        isNot(materialAppDefaultFamily(tester)),
        reason:
            'and it is deliberately NOT `MaterialApp`\'s outermost `DefaultTextStyle` '
            'family, which is a different question with a different answer.',
      );

      // And it is the family the harness would have to reject: not Amiri, and a
      // family with no Arabic glyph at all.
      expect(painted.single.run.family, isNot(EvaTypography.arabicFamily));
      expect(familyCovers(painted.single.run.family, <int>[0x0631]), isFalse);
    });

    testWidgets(
      'and a tooltip that DOES name Amiri is reported in Amiri — which '
      'is the fix this file must not get wrong again',
      (WidgetTester tester) async {
        // **The regression that mattered.** The walk read the child's `fontFamily` as
        // `null`, substituted `bodyMedium`, and reported `DMSans` for a tooltip the
        // app had already rendered in Amiri — a correct fix reported wrong, in the one
        // family the gate exists to catch.
        await _pump(
          tester,
          const Tooltip(
            message: backLabel,
            textStyle: TextStyle(fontFamily: 'Amiri'),
            child: SizedBox(width: 44, height: 44),
          ),
        );

        final List<({String message, RenderedRun run})> painted =
            await paintedTooltips(tester);
        expect(painted, hasLength(1));
        expect(
          painted.single.run.family,
          EvaTypography.arabicFamily,
          reason:
              'the root span carries the family and the child carries the text. A walk '
              'that reads the child reports the fallback here, which is the failure '
              'this file exists to keep fixed.',
        );
      },
    );
  });

  group(
    'G2 — a `TextSpan` resolves by MERGE, exactly as `ParagraphBuilder` does',
    () {
      testWidgets('a child that styles only a colour keeps the parent family', (
        WidgetTester tester,
      ) async {
        // `TextSpan.build` **pushes** the style onto a `ui.ParagraphBuilder` and pops
        // it, so a partially-styled child inherits every field it does not set. A walk
        // that used `span.style ?? inherited` reported `_Greeting`'s Arabic lead-in as
        // the engine fallback when it renders in Cormorant Garamond — a correct run
        // reported as tofu.
        await _pump(
          tester,
          const _Root(<InlineSpan>[
            TextSpan(
              text: 'صباح الخير، ',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
            TextSpan(
              text: 'David Mina',
              style: TextStyle(color: Color(0xFFFF0000)),
            ),
          ]),
        );

        final List<RenderedRun> runs = await renderedRuns(tester);
        expect(
          <String, String>{
            for (final RenderedRun run in runs) run.label: run.family,
          },
          <String, String>{
            // **No `containsArabic` filter here**, which is what the first version of
            // this assertion had — and it silently dropped `David Mina`, so the test
            // passed on half the plant it was written to check. The Arabic one is the
            // interesting case because it is the one the gate would flag; the Latin one
            // is here because a filter that removes a row from an assertion is the
            // shape of bug this suite keeps finding.
            'صباح الخير، ': EvaTypography.displayFamily,
            'David Mina': EvaTypography.displayFamily,
          },
          reason:
              'both spans style only a colour, so both resolve their family from the '
              'root. `??` would have reported the ambient fallback for each.',
        );
      });

      testWidgets('and a child that sets its own family wins over the parent', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          const _Root(<InlineSpan>[
            TextSpan(
              text: 'رجوع',
              style: TextStyle(fontFamily: 'Amiri'),
            ),
          ]),
        );

        final List<RenderedRun> runs = await renderedRuns(tester);
        expect(
          runs.singleWhere((RenderedRun r) => r.label == backLabel).family,
          EvaTypography.arabicFamily,
        );
      });

      testWidgets(
        'a span with children and no text of its own contributes NO run',
        (WidgetTester tester) async {
          // The fourth of the four walk bugs. Counting the parent span added a duplicate
          // run for every verse paragraph and a second `رجوع`.
          await _pump(
            tester,
            const _Root(<InlineSpan>[
              TextSpan(children: <InlineSpan>[TextSpan(text: backLabel)]),
            ]),
          );

          final List<RenderedRun> runs = await renderedRuns(tester);
          expect(
            runs.where((RenderedRun r) => r.label == backLabel),
            hasLength(1),
            reason: 'the root paints nothing; only the child does',
          );
          expect(runs, hasLength(1));
        },
      );
    },
  );

  group('G3 — the Arabic predicate is a block RANGE', () {
    test('and `رجوع` is the string that proves it', () {
      // The four codepoints the first version sampled. `رجوع` is none of them.
      for (final int sampled in <int>[0x0628, 0x0644, 0x064E, 0x0665]) {
        expect(
          backLabel.runes,
          isNot(contains(sampled)),
          reason:
              'U+${sampled.toRadixString(16).toUpperCase()} is one of the four the '
              'first predicate sampled, and this string is the one that made that '
              'predicate useless',
        );
      }
      expect(containsArabic(backLabel), isTrue);
    });

    test('every one of the four blocks, and the boundaries either side', () {
      expect(isArabicRune(0x0600), isTrue);
      expect(isArabicRune(0x06FF), isTrue);
      expect(isArabicRune(0x0750), isTrue);
      expect(isArabicRune(0x077F), isTrue);
      expect(isArabicRune(0xFB50), isTrue);
      expect(isArabicRune(0xFDFF), isTrue);
      expect(isArabicRune(0xFE70), isTrue);
      expect(isArabicRune(0xFEFF), isTrue);
      // Where a `<=` becomes `<`. Each of these is a real gap between the blocks.
      expect(isArabicRune(0x05FF), isFalse);
      expect(isArabicRune(0x0700), isFalse);
      expect(isArabicRune(0x074F), isFalse);
      expect(isArabicRune(0x0780), isFalse);
      expect(isArabicRune(0xFB4F), isFalse);
      expect(isArabicRune(0xFE00), isFalse);
      // **The upper end of Presentation Forms-A is real, and it is not the block's
      // end.** U+FDF0 is Arabic Extended-A, which the Unicode chart assigns inside
      // U+FB50–U+FDFF. An earlier version of this file asserted it was `false`,
      // reading the block's name as its table and finding a plausible boundary to
      // test. `font_coverage.dart` measures Amiri carrying 611 codepoints in this
      // range, so a predicate that stopped at U+FDF0 would be excluding glyphs the
      // app can render.
      expect(isArabicRune(0xFDF0), isTrue);
      // The blocks either side of the Arabic Supplement: Syriac above it, NKo below.
      expect(isArabicRune(0x070F), isFalse);
      expect(isArabicRune(0x07C0), isFalse);
    });

    test('and it is not a "looks like Arabic" test', () {
      expect(containsArabic('John 3:1-5'), isFalse);
      expect(containsArabic('Continue reading'), isFalse);
      expect(containsArabic('٤'), isTrue, reason: 'Arabic-Indic digit four');
      expect(containsArabic('ص'), isTrue);
      expect(containsArabic(''), isFalse);
      expect(containsArabic('   '), isFalse);
    });
  });

  group('G4 — the ambient probe is TOTAL, and names no widget', () {
    testWidgets(
      'a tree with no `Text` in it at all returns a value rather than '
      'throwing',
      (WidgetTester tester) async {
        // The version this replaced read
        // `Theme.of(tester.element(find.byType(ScriptureBlock).first))`, and its own
        // doc records that reading `Theme.of` from inside the walk "throws on a tree
        // with no `Text` in it" — and it named a **reading-screen** widget, which three
        // of the six screens do not contain.
        await _pump(tester, const SizedBox(width: 10, height: 10));
        expect(find.byType(Text), findsNothing);
        expect(materialAppDefaultFamily(tester), isNotEmpty);
      },
    );

    testWidgets('and it is the same probe on two unrelated screens', (
      WidgetTester tester,
    ) async {
      // "Names no widget" is the property. Reading it off a `ScriptureBlock` was not
      // a shortcut, it was a dependency on one screen's contents.
      await _pump(tester, const SizedBox(width: 10, height: 10));
      final String bare = materialAppDefaultFamily(tester);
      await _pump(
        tester,
        const _Root(<InlineSpan>[
          TextSpan(text: 'x'),
        ], family: EvaTypography.monoFamily),
      );
      expect(materialAppDefaultFamily(tester), bare);
    });

    test('and the value is MaterialApp\'s own error style, not bodyMedium', () {
      // **Measured, and the gate it replaces got it wrong.** That walk documented
      // "Flutter resolves a null `TextStyle` to `ThemeData.textTheme.bodyMedium`,
      // measured `DMSans`". It does not: `MaterialApp` installs its own
      // `DefaultTextStyle`, `_errorTextStyle`, whose `debugLabel` is "fallback style;
      // consider putting your text in a Material" and whose family is **`monospace`**
      // — a family `pubspec.yaml` does not declare, so the engine's default font
      // renders it. The claim was never exercised on a real tree, because every run
      // on `/reading` named its own family.
      //
      // Recorded because the two readings are not equally wrong: `bodyMedium` at least
      // names a bundled family, and `monospace` names none at all.
      expect(EvaThemeDark.theme.textTheme.bodyMedium?.fontFamily, 'DMSans');
      expect(const DefaultTextStyle.fallback().style.fontFamily, isNull);
    });
  });

  group('G5 — a WRONG-FAMILY ARABIC RUN IS DETECTED, which is what makes the three '
      'vacuous stub gates gates', () {
    testWidgets('planted on a bare tree with no screen at all', (
      WidgetTester tester,
    ) async {
      // This is the mutation the review runs on each of `/quiz`, `/result` and
      // `/settings`: give the screen its first Arabic run in a family with no Arabic
      // glyphs. Here it is planted on the smallest tree that can hold it, so the
      // detection is attributable to the harness and not to any screen's wiring.
      await _pump(
        tester,
        const Text(backLabel, style: TextStyle(fontFamily: 'DMSans')),
      );

      final List<RenderedRun> arabic = await arabicRuns(tester);
      expect(arabic, hasLength(1), reason: 'the walk sees it');
      expect(arabic.single.family, 'DMSans', reason: 'and reads it honestly');
      // Everything the gate asserts about a run is reachable from this one list, so
      // a gate over it would fail in four places at once.
      expect(familyCovers(arabic.single.family, <int>[0x0631]), isFalse);
      expect(arabic.single.family, isNot(EvaTypography.arabicFamily));
      expect(kBundledFontFamilies, contains(arabic.single.family));
    });

    testWidgets('and the same run in Amiri passes every one of those checks', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Text(backLabel, style: TextStyle(fontFamily: 'Amiri')),
      );

      final List<RenderedRun> arabic = await arabicRuns(tester);
      expect(arabic.single.family, EvaTypography.arabicFamily);
      expect(familyCovers(arabic.single.family, <int>[0x0631]), isTrue);
      final Set<int> covered = codepointsForFamily(arabic.single.family);
      expect(
        backLabel.runes.where((int r) => !covered.contains(r)),
        isEmpty,
        reason: 'the cmap half of the gate, on the same run',
      );
    });
  });

  group(
    '`familyOfText` tells "not on screen" from "on screen with no family"',
    () {
      testWidgets(
        'because the second is a defect and the first is usually a typo in '
        'the test',
        (WidgetTester tester) async {
          await _pump(
            tester,
            const Column(
              children: <Widget>[
                Text('named', style: TextStyle(fontFamily: 'Amiri')),
                Text('unnamed'),
              ],
            ),
          );

          expect(familyOfText(tester, 'named'), 'Amiri');
          expect(
            familyOfText(tester, 'unnamed'),
            '',
            reason:
                'rendered, and it named no family — so the engine falls back. An API '
                'that returned `null` here would report it as "not on screen" and the '
                'run would escape every assertion.',
          );
          expect(
            familyOfText(tester, 'absent entirely'),
            isNull,
            reason: 'the other meaning, and the one a stale finder produces',
          );
        },
      );
    },
  );
}

/// A `RichText` whose root span carries [family] and whose children are [children].
///
/// Built by hand rather than by a `Tooltip` so the **span shape** is under the
/// test's control — Flutter's own shape, which is what G2 is about.
class _Root extends StatelessWidget {
  const _Root(this.children, {this.family});

  final List<InlineSpan> children;
  final String? family;

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: TextStyle(fontFamily: family ?? EvaTypography.displayFamily),
      children: children,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: const Locale('ar'),
      textDirection: TextDirection.rtl,
      child: child,
    ),
  );
  await tester.pump();
}
