import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// `/quiz`'s transcribed numbers, against the stylesheet that states them.
///
/// ## WHY THIS FILE WAS REWRITTEN, NOT RE-POINTED
///
/// Its predecessor pinned the **superseded prototype's** geometry — the fleck pair outside the
/// card, a 44px spacer at the header's far end, and the feedback banner's 8px dot.
/// The LUMEN redesign (`eva/redesign.html:562-574`) draws **none** of those: the
/// options are tint-tier cards with no flecks, the header's far end is the score and
/// not a spacer, and the banner does not exist. Re-pointing the old assertions to
/// redesign line numbers would have cited lines that say something else, which is
/// the failure `docs/DRIFT.md` catalogues. So the claims below are the **new**
/// screen's, and each names the rule it was read from.
///
/// ## HOW IT CHECKS
///
/// The stylesheet is parsed at test time, exactly as `reading_geometry_test.dart`
/// does: a pattern that stops matching throws, and the anti-vacuity group names
/// every rule the rows depend on. The rendered half then measures the boxes
/// `RenderBox` actually reports, because a constant comparison cannot see a widget
/// that ignores its own constant — `login_geometry_test.dart`'s recorded finding.
void main() {
  final String css = File('eva/redesign.html').readAsStringSync();

  /// The first capture group of [pattern], as a `double`.
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

  /// Whether [pattern] matches at all.
  bool states(String pattern) => RegExp(pattern, dotAll: true).hasMatch(css);

  group('the extraction is not vacuous', () {
    test('every rule the claims name is still in the stylesheet', () {
      const List<String> rules = <String>[
        '.appbar{padding:46px 18px 4px}',
        '.abrow{',
        '.abrow .ttl{',
        '.chev{',
        '.dots{',
        '.qbody{',
        '.qtext{',
        '.opt{',
        '.opt .key{',
        '.opt.correct{',
        '.opt.wrong{',
        '.qnext{',
      ];
      for (final String rule in rules) {
        expect(
          css.contains(rule),
          isTrue,
          reason:
              '`$rule` is not in the stylesheet any more, so the rows that cite '
              'it are asserting air',
        );
      }
    });
  });

  group('QuizHeader, against `:142-150` and `:328`', () {
    test('the appbar box, the row floor and the crumb cap', () {
      // `:142` — `padding: 46px 18px 4px`, the three-value CSS shorthand:
      // top | horizontal | bottom.
      expect(
        QuizHeader.appbarPadding,
        EdgeInsets.fromLTRB(
          num(r'\.appbar\{padding:[\d.]+px ([\d.]+)px'),
          num(r'\.appbar\{padding:([\d.]+)px'),
          num(r'\.appbar\{padding:[\d.]+px ([\d.]+)px'),
          num(r'\.appbar\{padding:[\d.]+px [\d.]+px ([\d.]+)px'),
        ),
      );
      // `:143` — `min-height: 34px`.
      expect(
        num(r'\.abrow\{[^}]*min-height:\s*([\d.]+)px'),
        QuizHeader.rowMinHeight,
      );
      // `:144` — `max-width: 52%`.
      expect(
        num(r'\.abrow \.ttl\{[^}]*max-width:\s*([\d.]+)%') / 100,
        QuizHeader.crumbMaxWidthFactor,
      );
      // `:149` — the chevron's own 16px face.
      expect(
        num(r'\.chev\{[^}]*font-size:\s*([\d.]+)px'),
        QuizHeader.chevFontSize,
      );
      // `:564` — the glyph is the prototype's own `‹`, not a Material icon.
      expect(QuizHeader.chevGlyph, '‹');
    });

    test('the dots row keeps its own padding', () {
      // `:328` — `padding: 8px 0 4px`, re-homed under the appbar.
      expect(
        QuizHeader.dotsPadding,
        EdgeInsets.fromLTRB(
          0,
          num(r'\.dots\{[^}]*padding:\s*([\d.]+)px'),
          0,
          num(r'\.dots\{[^}]*padding:\s*[\d.]+px\s+0\s+([\d.]+)px'),
        ),
      );
    });

    testWidgets('the chevron is PANTED at 16 inside a 44 tap box', (
      WidgetTester tester,
    ) async {
      // The recorded divergence: `:149` gives `.chev` only `4px 6px` of padding
      // (~28px), and this app's touch floor is 44 (`iOSTapTargetGuideline`). The
      // **glyph** stays the prototype's size; the box around it is ours. A widget
      // that grew the glyph to 44 would pass a constant comparison and fail here.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: Scaffold(
            body: QuizHeader(
              crumb: 'Refraction · John 3:1-5',
              score: 0,
              total: 3,
              completed: 0,
              current: 0,
              language: ReadingLanguage.english,
              strings: AppLocalizationsEn(),
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final Finder glyph = find.text(QuizHeader.chevGlyph);
      expect(glyph, findsOneWidget);
      expect(
        tester.getSize(glyph).height,
        lessThan(QuizHeader.chevTapSize),
        reason: 'the glyph is painted at `.chev`\'s 16px, not at the tap box',
      );

      final Finder tapBox = find.ancestor(
        of: glyph,
        matching: find.byType(Semantics),
      );
      expect(tapBox, findsWidgets);
      final Iterable<Semantics> nodes = tester.widgetList<Semantics>(tapBox);
      expect(
        nodes.any(
          (Semantics node) =>
              node.properties.label == AppLocalizationsEn().quizExit,
        ),
        isTrue,
        reason: '§14: the bare `‹` button carries its reason in a name',
      );
    });
  });

  group('QuizPage, against `.qbody` and `.qtext` (`:333-335`)', () {
    test('the prompt box, composed from the `ch` measure', () {
      // `:334` — `font-size: 25px`, `line-height: 1.4`, `font-weight: 500`.
      expect(
        num(r'\.qtext\{[^}]*font-size:\s*([\d.]+)px'),
        QuizPage.promptFontSize,
      );
      expect(
        num(r'\.qtext\{[^}]*line-height:\s*([\d.]+)'),
        QuizPage.promptLineHeight,
      );
      expect(
        num(r'\.qtext\{[^}]*font-weight:\s*([\d.]+)'),
        QuizPage.promptWeight.value.toDouble(),
      );
      // `:335` — `max-width: 26ch`, `margin: 0 auto 30px`.
      expect(
        num(r'\.qtext\{[^}]*max-width:\s*([\d.]+)ch'),
        QuizPage.promptMaxChars,
      );
      expect(
        num(r'\.qtext\{[^}]*margin:\s*0 auto ([\d.]+)px'),
        QuizPage.promptBottomGap,
      );
      // `:333` — `padding: 0 26px`.
      expect(
        num(r'\.qbody\{[^}]*padding:\s*0 ([\d.]+)px'),
        QuizPage.bodySidePadding,
      );
      // The composition is stated, not hidden: 26ch × 25px × the face's ~0.5em.
      expect(
        QuizPage.promptMaxWidth,
        QuizPage.promptMaxChars *
            QuizPage.promptFontSize *
            QuizPage.promptChEmFactor,
      );
    });

    testWidgets('and the rendered prompt is capped at the composed number', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              key: const ValueKey<String>('prompt-cap'),
              constraints: BoxConstraints(maxWidth: QuizPage.promptMaxWidth),
              child: const Text('a prompt long enough to fill its measure'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.getSize(find.byKey(const ValueKey<String>('prompt-cap'))).width,
        moreOrLessEquals(QuizPage.promptMaxWidth, epsilon: 0.5),
      );
    });
  });

  group('QuizOptionCard, against `.opt` (`:337-342`) and its verdicts', () {
    test('the resting box, the badge and the verdict alphas', () {
      // `:337`/`:341` — `padding: 16px 18px`, `gap: 14`, `radius: 18`,
      // `margin-bottom: 12`, `font-size: 15`, `font-weight: 500`.
      expect(
        QuizOptionCard.padding,
        EdgeInsets.symmetric(
          horizontal: num(r'\.opt\{[^}]*padding:\s*[\d.]+px ([\d.]+)px'),
          vertical: num(r'\.opt\{[^}]*padding:\s*([\d.]+)px'),
        ),
      );
      expect(num(r'\.opt\{[^}]*gap:\s*([\d.]+)px'), QuizOptionCard.gap);
      expect(
        num(r'\.opt\{[^}]*border-radius:\s*([\d.]+)px'),
        QuizOptionCard.radius,
      );
      expect(
        num(r'\.opt\{[^}]*margin-bottom:\s*([\d.]+)px'),
        QuizPage.optionGap,
      );
      expect(
        num(r'\.opt\{[^}]*font-size:\s*([\d.]+)px'),
        QuizOptionCard.labelFontSize,
      );
      expect(
        num(r'\.opt\{[^}]*font-weight:\s*([\d.]+)'),
        QuizOptionCard.labelWeight.value.toDouble(),
      );
      // `:342` — the key badge is 26×26, mono 10px, 1px rim.
      expect(
        num(r'\.opt \.key\{[^}]*width:\s*([\d.]+)px'),
        QuizOptionCard.badgeSize,
      );
      expect(
        num(r'\.opt \.key\{[^}]*height:\s*([\d.]+)px'),
        QuizOptionCard.badgeSize,
      );
      expect(
        num(r'\.opt \.key\{[^}]*font-size:\s*([\d.]+)px'),
        QuizOptionCard.badgeFontSize,
      );
      // `:350` and `:358` — the two verdict treatments.
      expect(
        num(
          r'\.opt\.correct\{[^}]*border-color:\s*rgba\(232,\s*176,\s*75,\s*([\d.]+)\)',
        ),
        QuizOptionCard.correctBorderAlpha,
      );
      expect(
        num(
          r'\.opt\.correct\{[^}]*background:\s*rgba\(232,\s*176,\s*75,\s*([\d.]+)\)',
        ),
        QuizOptionCard.correctFillAlpha,
      );
      expect(
        num(
          r'\.opt\.wrong\{[^}]*border-color:\s*rgba\(255,\s*90,\s*72,\s*([\d.]+)\)',
        ),
        QuizOptionCard.wrongBorderAlpha,
      );
      expect(
        num(
          r'\.opt\.wrong\{[^}]*background:\s*rgba\(255,\s*90,\s*72,\s*([\d.]+)\)',
        ),
        QuizOptionCard.wrongFillAlpha,
      );
      expect(
        num(r'\.opt\.wrong\{[^}]*opacity:\s*([\d.]+)'),
        QuizOptionCard.wrongOpacity,
      );
      // The message's `min-width: 0; overflow-wrap: anywhere` is what keeps a
      // long option from overflowing at 1.22×; a fixed-width row would.
      expect(states(r'\.opt \.txt\{[^}]*min-width:\s*0'), isTrue);
    });

    testWidgets('the badge measures 26 and the card honors its padding', (
      WidgetTester tester,
    ) async {
      // Constants cannot see a widget ignoring them. `A` is the badge's only text
      // on the resting card, and the card's height must clear the 44 floor from
      // its own content (`:339` gives it no `min-height`).
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: const SizedBox(
            width: 320,
            child: QuizOptionCard(
              letter: 'A',
              text: 'Nicodemus',
              state: QuizOptionState.idle,
              semanticLabel: 'A. Nicodemus',
              language: ReadingLanguage.english,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.getSize(find.text('A')).height,
        lessThan(QuizOptionCard.badgeSize),
        reason: 'the letter sits inside the 26px badge',
      );
      expect(
        tester.getSize(find.byType(QuizOptionCard)).height,
        greaterThanOrEqualTo(44),
        reason: 'the card is a touch target, met by its own content',
      );
    });
  });

  group('the CTA, against `.qnext` (`:363-368`)', () {
    test('the pill\'s box and its mono tracking', () {
      expect(
        QuizPage.ctaMargin,
        EdgeInsets.fromLTRB(
          num(r'\.qnext\{margin:\s*[\d.]+px ([\d.]+)px'),
          num(r'\.qnext\{margin:\s*([\d.]+)px'),
          num(r'\.qnext\{margin:\s*[\d.]+px ([\d.]+)px'),
          num(r'\.qnext\{margin:\s*[\d.]+px [\d.]+px ([\d.]+)px'),
        ),
      );
      expect(
        num(r'\.qnext\{[^}]*padding:\s*([\d.]+)px'),
        QuizPage.ctaPadding.top,
      );
      expect(
        num(r'\.qnext\{[^}]*font-size:\s*([\d.]+)px'),
        QuizPage.ctaFontSize,
      );
      expect(
        num(r'\.qnext\{[^}]*letter-spacing:\s*([\d.]+)em'),
        QuizPage.ctaLetterSpacing / QuizPage.ctaFontSize,
      );
      expect(
        num(r'\.qnext\{[^}]*border-radius:\s*([\d.]+)px'),
        QuizPage.ctaRadius,
      );
      expect(
        num(
          r'\.qnext\{[^}]*border:\s*1px solid rgba\(232,\s*176,\s*75,\s*([\d.]+)\)',
        ),
        QuizPage.ctaBorderAlpha,
      );
      expect(
        num(
          r'\.qnext:hover\{background:\s*rgba\(232,\s*176,\s*75,\s*([\d.]+)\)',
        ),
        QuizPage.ctaHoverFillAlpha,
      );
    });
  });
}
