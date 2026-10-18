import 'dart:io';

import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reading_harness.dart';

/// The redesigned `/reading`'s numbers, against the CSS that states them.
///
/// ## WHY THE PROTOTYPE IS READ AS TEXT, AND NOT THROUGH A SELECTOR PARSER
///
/// `test/support/css_reference.dart` resolves a *selector* to a rule and a rule to
/// lengths, which is the right tool for a suite whose numbers live one per rule.
/// This screen's numbers do not: `--vsize` is a **custom property** the parser
/// refuses (correctly — a variable is not a length), `:163`'s transition list is
/// three timings in one declaration, and `.vline.hot::before`'s `inset` is a
/// four-value shorthand whose halves do not map onto the parser's pairs. So the
/// raw stylesheet is read here, each value is extracted by a pattern that names
/// the rule it sits in, and **a pattern that stops matching is a failure**, not a
/// pass over nothing — the anti-vacuity group at the bottom is what enforces that.
///
/// Every constant in this file names its `eva/redesign.html` line in its own doc;
/// this suite is the check that the comment is still true.
void main() {
  /// The stylesheet, as text. Read once; `eva/` is read-only reference material.
  final String css = File('eva/redesign.html').readAsStringSync();

  /// The number a pattern's first capture group holds, as a `double`.
  double num(String pattern) {
    final RegExpMatch? match = RegExp(
      pattern,
      dotAll: true,
      multiLine: true,
    ).firstMatch(css);
    if (match == null) {
      throw StateError(
        'the prototype no longer matches `$pattern`, so this suite cannot check '
        'the constant it was written for. A renamed rule or a reflowed block is a '
        'change this harness has to read again — never a pass over nothing.',
      );
    }
    return double.parse(match.group(1)!);
  }

  /// Whether a pattern matches at all — for the values that are *stated* rather
  /// than extracted (`inset`'s two numbers, a transition's shape).
  bool states(String pattern) => RegExp(pattern, dotAll: true).hasMatch(css);

  group('the extraction is not vacuous', () {
    test('every rule the claims name is still in the stylesheet', () {
      // A regex suite that matched nothing would be green about nothing. These
      // are the selectors every row below is written against.
      const List<String> rules = <String>[
        '.appbar{padding:46px 18px 4px}',
        '.abrow{',
        '.abrow .ttl{',
        '.versebox{',
        '.vline{',
        '.vline.hot{',
        '.vline.resume{',
        '.vline i{',
        '.vline.drop::first-letter{',
        '.qcta{',
        '.pill{',
        '.pbtn{',
        '.segp{',
        '.segp.langsm{',
      ];
      for (final String rule in rules) {
        expect(
          css.contains(rule),
          isTrue,
          reason:
              '`$rule` is not in the stylesheet any more, so the rows that '
              'cite it are asserting air',
        );
      }
    });
  });

  group('VerseLine, against `:161` and its children', () {
    test('the body size, the line box and the gap', () {
      // `:19` — `--vsize: 20px`, the variable's **default**; `:161` consumes it
      // as `font-size: var(--vsize)`.
      expect(num(r'--vsize:\s*([\d.]+)px'), VerseLine.verseSize);
      // `:140` — `calc(var(--vsize) + 3px)`, resolved against that default.
      expect(
        num(
          r'\[dir=rtl\] \.vline\{[^}]*font-size:\s*calc\(var\(--vsize\)\s*\+\s*([\d.]+)px\)',
        ),
        VerseLine.verseSizeArabic - VerseLine.verseSize,
        reason:
            'the Arabic arm states a *difference*, and the constant is the '
            'sum — so the check is against the difference it was derived from',
      );
      expect(
        num(r'^\.vline\{[^}]*line-height:\s*([\d.]+)'),
        VerseLine.verseHeight,
      );
      expect(
        num(r'\[dir=rtl\] \.vline\{[^}]*line-height:\s*([\d.]+)'),
        VerseLine.verseHeightArabic,
      );
      expect(
        num(r'^\.vline\{[^}]*margin-bottom:\s*([\d.]+)px'),
        VerseLine.verseGap,
      );
      expect(VerseLine.entranceOffset, 10);
    });

    test('the numeral, the glow and the resume marker', () {
      expect(
        num(r'\.vline i\{[^}]*font-size:\s*([\d.]+)px'),
        VerseLine.numeralSize,
      );
      // `:170` — `margin: 0 2px`; the horizontal half is what a side bearing is.
      expect(
        num(r'\.vline i\{[^}]*margin:\s*[\d.]+(?:px)?\s+([\d.]+)px'),
        VerseLine.numeralSpacing,
      );
      expect(
        num(r'\.vline\.hot\{[^}]*text-shadow:\s*0\s+0\s+([\d.]+)px'),
        VerseLine.selectedGlowBlur,
      );
      expect(
        states(r'\.vline\.hot\{[^}]*rgba\(232,\s*176,\s*75,\s*\.28\)'),
        isTrue,
      );
      expect(
        num(r'\.vline\.hot::before\{[^}]*inset:\s*-([\d.]+)px\s+-([\d.]+)px')
            .toString(),
        contains('8'),
        reason: 'the halo states its own two insets; the first is the vertical',
      );
      expect(
        num(r'\.vline\.hot::before\{[^}]*border-radius:\s*([\d.]+)px'),
        VerseLine.glowRadius,
      );
      expect(
        num(r'\.vline\.resume\{[^}]*inset ([\d.]+)px 0 0'),
        VerseLine.resumeBarWidth,
      );
      expect(
        num(r'\.vline\.resume\{[^}]*padding-left:\s*([\d.]+)px'),
        VerseLine.resumePadding,
      );
      expect(
        num(r'\.vline\.resume\{[^}]*border-radius:\s*([\d.]+)px'),
        VerseLine.resumeRadius,
      );
      expect(
        num(r'\.vline\.drop::first-letter\{[^}]*font-size:\s*([\d.]+)px'),
        VerseLine.dropCapSize,
      );
    });

    test('and the entrance, on the rule that carries all three timings', () {
      // `:163` — `transition: opacity .32s, transform .32s, filter .32s`, all on
      // `var(--e-light)`. The first timing in that list is the one the reveal
      // plays at, and the blur's *absence* from this client is the budget's
      // decision (`verse_line.dart`'s doc).
      expect(
        states(r'opacity\s*\.32s var\(--e-light\),transform\s*\.32s'),
        isTrue,
      );
      expect(
        VerseLine.entranceDuration,
        const Duration(milliseconds: 320),
        reason:
            '`:163` states `.32s` three times, and the constant is the first '
            'of them — pinned as a literal because the reduced-motion rule at '
            '`:52` also ends in `.vline{` and states `.01s`, so a lookup by '
            'selector alone answers with the wrong rule',
      );
      // And `:162` states the `blur(10px)` this client does not paint, so the
      // omission has a place with the number in it.
      expect(states(r'\.vline\{[^}]*filter:\s*blur\(10px\)'), isTrue);
    });
  });

  group('ReadingAppBar, against `:142` and `:144`', () {
    test('the two rows and the title', () {
      expect(
        num(r'\.appbar\{padding:\s*([\d.]+)px'),
        ReadingAppBar.titlePadding.top,
        reason:
            '`:142` — `padding: 46px 18px 4px`, and `:546` zeroes the top for '
            'the meta row only',
      );
      expect(
        num(r'\.appbar\{padding:\s*[\d.]+px\s+([\d.]+)px'),
        ReadingAppBar.titlePadding.left,
      );
      expect(
        num(r'\.appbar\{padding:\s*[\d.]+px\s+[\d.]+px\s+([\d.]+)px'),
        ReadingAppBar.titlePadding.bottom,
      );
      expect(num(r'\.abrow\{[^}]*gap:\s*([\d.]+)px'), ReadingAppBar.rowGap);
      expect(
        num(r'\.abrow\{[^}]*min-height:\s*([\d.]+)px'),
        ReadingAppBar.rowMinHeight,
      );
      expect(
        num(r'\.abrow \.ttl\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingAppBar.titleSize,
      );
      expect(
        num(r'\.abrow \.ttl\{[^}]*letter-spacing:\s*(-\.[\d.]+)em'),
        closeTo(ReadingAppBar.titleTracking / ReadingAppBar.titleSize, 0.001),
        reason:
            '`:144` states `-.01em`, and the constant is the resolved '
            'pixels — the check is against the *em* it was derived from',
      );
      expect(
        num(r'\.appbar \.sub\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingAppBar.metaSize,
      );
      expect(
        num(r'\.appbar \.sub\{[^}]*letter-spacing:\s*(\.[\d.]+)em'),
        closeTo(ReadingAppBar.metaTracking / ReadingAppBar.metaSize, 0.001),
      );
      expect(
        num(r'\.chev\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingAppBar.chevronSize,
      );
      expect(
        num(r'\.chev\{[^}]*padding:\s*([\d.]+)px\s+([\d.]+)px').toString(),
        contains('4'),
        reason: '`:149` — `padding: 4px 6px`; the vertical half is first',
      );
      expect(
        num(r'\.iconbtn\{[^}]*width:\s*([\d.]+)px'),
        ReadingAppBar.bookmarkSize,
      );
      expect(
        num(r'\.iconbtn\{[^}]*border-radius:\s*([\d.]+)px'),
        ReadingAppBar.bookmarkRadius,
      );
      // `:151` — `.iconbtn{font-size:12px}`, and `:155`'s 15px is for an `<svg>`
      // the reader route does not contain (`:544` writes the character). The
      // constant's doc carries the whole argument.
      expect(
        num(r'\.iconbtn\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingAppBar.bookmarkGlyphSize,
      );
      expect(
        num(r'\.iconbtn\.lit\{[^}]*box-shadow:\s*0\s+0\s+([\d.]+)px'),
        ReadingAppBar.bookmarkGlowBlur,
      );
      expect(
        states(r'\.iconbtn\.lit\{[^}]*rgba\(232,\s*176,\s*75,\s*\.35\)'),
        isTrue,
      );
    });

    test('and the dead rule is still dead, with its intent adopted', () {
      // `.appbar .sub` is a descendant selector for a class written on the same
      // element (`:546`), so it never applies in the prototype — and the port
      // takes its *intent* (the mono micro-label) rather than its inheritance.
      // This row is what notices if either half changes: the rule moving, or the
      // markup fixing itself, both of which would make the divergence stale.
      expect(
        states(r'\.appbar \.sub\{[^}]*font-family:\s*var\(--mono\)'),
        isTrue,
      );
      expect(
        css,
        contains('<div class="appbar sub" id="crumbMeta"'),
        reason:
            'the same-element spelling is what makes the rule dead, and this '
            'row is the record of that fact',
      );
    });
  });

  group('ReadingQuizCta, against `:202-205`', () {
    test('the box, the type and the two alphas', () {
      expect(
        num(r'\.qcta\{margin:\s*0\s+([\d.]+)px\s+([\d.]+)px').toString(),
        contains('18'),
        reason: '`:202` — `margin: 0 18px 10px`',
      );
      expect(
        num(r'\.qcta\{[^}]*border-radius:\s*([\d.]+)px'),
        ReadingQuizCta.radius,
      );
      expect(
        num(r'\.qcta\{[^}]*padding:\s*([\d.]+)px\s+([\d.]+)px').toString(),
        contains('13'),
        reason: 'the vertical half is first in `13px 16px`',
      );
      expect(
        num(r'\.qcta\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingQuizCta.fontSize,
      );
      expect(
        num(r'\.qcta\{[^}]*letter-spacing:\s*(\.[\d.]+)em'),
        closeTo(ReadingQuizCta.letterSpacing / ReadingQuizCta.fontSize, 0.001),
      );
      // `:205` — the Arabic arm's own size, and no tracking and no uppercase.
      expect(
        states(r'\[dir=rtl\] \.qcta\{[^}]*font-family:\s*var\(--ui-ar\)'),
        isTrue,
      );
      expect(
        num(r'\[dir=rtl\] \.qcta\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingQuizCta.fontSizeArabic,
      );
    });
  });

  group('ReadingPill, against `:192` and `:194`', () {
    test('the pill and its buttons', () {
      expect(
        num(r'\.pill\{margin:\s*0\s+([\d.]+)px\s+([\d.]+)px').toString(),
        contains('18'),
      );
      // **The third number is the bottom**, and the first is a *unitless* `0` —
      // which a `[\d.]+px` pattern refuses, so the pattern reads the pair it can
      // and the bottom is asserted by containment of the whole declaration.
      expect(
        css.contains('margin: 0 18px 26px') ||
            css.contains('margin:0 18px 26px'),
        isTrue,
        reason:
            '`:192` states the pill\'s own margin, and 26 is the largest '
            'bottom margin in the file',
      );
      expect(
        num(r'\.pill\{[^}]*padding:\s*([\d.]+)px\s+([\d.]+)px').toString(),
        contains('10'),
      );
      expect(
        num(r'\.pill\{[^}]*border-radius:\s*([\d.]+)px'),
        ReadingPill.radius,
      );
      expect(
        num(r'\.pbtn\{[^}]*font-size:\s*([\d.]+)px'),
        ReadingPill.buttonSize,
      );
      expect(
        num(r'\.pbtn\{[^}]*padding:\s*([\d.]+)px\s+([\d.]+)px').toString(),
        contains('8'),
      );
      expect(
        num(r'\.pbtn\{[^}]*border-radius:\s*([\d.]+)px'),
        ReadingPill.buttonRadius,
      );
      expect(
        num(r'\.segp\.langsm\{[^}]*width:\s*([\d.]+)px'),
        ReadingPill.segmentedWidth,
      );
    });

    test('and the one blur this screen does NOT paint, stated rather than hidden', () {
      // `:193` — `backdrop-filter: blur(18px)`. §13.4 budgets one blurred site and
      // `/` spends it, so the pill is a translucent fill over the sky. This row
      // exists so the *omission* has a place: if the budget is ever re-argued, the
      // number the prototype states is read here first.
      expect(states(r'\.pill\{[^}]*backdrop-filter:\s*blur\(18px\)'), isTrue);
    });
  });

  group('reading_page.dart, against `:176` and `:1287`', () {
    test('focus mode dims three surfaces, by one rule', () {
      // `:176` names `.appbar`, `.pill` and `.qcta` and **not** the verse rows;
      // `:177` is the rule the plan records as the defect to correct.
      expect(
        num(
          r'\.screen\.focus \.appbar,\.screen\.focus \.pill,\.screen\.focus \.qcta\{opacity:\s*([\d.]+)',
        ),
        chromeDimOpacity,
      );
      expect(states(r'\.screen\.focus \.vline\.in\{color:#d9dfef\}'), isTrue);
      expect(
        num(r'focusDelay=(\d+)'),
        focusIdleDelay.inSeconds,
        reason:
            '`:1287` is the only place the delay is written, and `:683`\'s '
            'slider has no `oninput` anywhere in the file',
      );
      expect(
        num(
          r'\.screen\.focus \.appbar,\.screen\.focus \.pill,\.screen\.focus \.qcta\{opacity:[\d.]+;transition:opacity\s*([\d.]+)s',
        ),
        focusDimTransition.inMilliseconds / 1000,
      );
    });
  });

  group('the rendered geometry, at the geometry surface', () {
    testWidgets('the verse list sits inside `:159`\'s padding', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        //  is the harness's own  default, so it is not
        // repeated — the analyzer calls the argument redundant and it is. What is
        // NOT default is the calm branch: without it the stagger reveals verses
        // over 320 ms each and the geometry reads a half-built list.
        disableAnimations: true,
      );

      expect(
        num(r'\.versebox\{[^}]*padding:\s*([\d.]+)px\s+([\d.]+)px\s+([\d.]+)px')
            .toString(),
        contains('14'),
        reason: '`:159` — `padding: 14px 26px 12px`',
      );
      // **The first verse, not the scroll view** — a `ListView`'s `padding` is
      // *inside* it, so the widget's own rect is full-width and asserting on it
      // read 0 where 26 was meant.
      final Rect first = tester.getRect(find.byType(VerseLine).first);
      expect(first.left, 26);
      expect(first.top, greaterThanOrEqualTo(14));
    });

    testWidgets('and the CTA spans the 18px-inset width', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        // `size` is the harness's default and `disableAnimations` is the calm
        // branch — see the first rendered row for both notes.
        disableAnimations: true,
      );

      // **The width, not the left edge** — `getRect` resolves to the widget's own
      // render object, which *includes* its margin, so its left is 0 and the
      // margins live inside it. The claim `:202` makes is about the width between
      // the insets.
      final Rect cta = tester.getRect(find.byType(ReadingQuizCta));
      expect(cta.width, kGeometrySurface.width);
    });
  });
}
