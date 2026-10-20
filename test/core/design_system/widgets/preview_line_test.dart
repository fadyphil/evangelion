import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The reading-size preview — `redesign.html:431`.
///
/// Widget work, so TDD-exempt (AGENT_CONTEXT §6) — but the *sizes* it asserts
/// are the ambient scale and the prototype's margin, and both are numbers a
/// reader can check against `eva/redesign.html`.
void main() {
  /// The prototype's own preview text. `redesign.html:694` —
  /// `<div class="prevline" id="prevLine">The Lord is my shepherd…</div>`.
  const String text = 'The Lord is my shepherd…';

  Future<void> pump(
    WidgetTester tester, {
    String line = text,
    ThemeData? theme,
    double textScale = 1.0,
    bool disableAnimations = false,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await pumpPrimitive(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: PreviewLine(text: line),
      ),
      theme: theme,
      textScale: textScale,
      disableAnimations: disableAnimations,
      textDirection: direction,
    );
    // `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
    // `kThemeAnimationDuration`, and the single zero-duration `pump()` after
    // `pumpWidget` does not advance it — so a re-pump with the other palette
    // still resolves the **first** one. The harness's own `kEvaThemes` doc
    // records the trap, and this is the same trap: the light arm read the
    // dark ink until the animation was allowed to finish.
    await tester.pumpAndSettle();
  }

  /// The style the line is drawn with.
  ///
  /// Read off the [AnimatedDefaultTextStyle] and not off the `Text`, because
  /// the `Text` has **no** style of its own: the size is the ambient scale and
  /// the family is the arm's, and both live on the default style the
  /// `AnimatedDefaultTextStyle` publishes. Reading the `Text` would report
  /// `null` and prove nothing.
  TextStyle styleOf(WidgetTester tester) => tester
      .widget<AnimatedDefaultTextStyle>(find.byType(AnimatedDefaultTextStyle))
      .style;

  group('PreviewLine', () {
    testWidgets('it shows the text it is given', (WidgetTester tester) async {
      await pump(tester);
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('it is the scripture face, and the family follows the arm', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      expect(
        styleOf(tester).fontFamily,
        EvaTypography.scriptureFamily,
        reason: '`--scr` — EB Garamond on the Latin arm',
      );

      await pump(tester, direction: TextDirection.rtl);
      expect(
        styleOf(tester).fontFamily,
        EvaTypography.arabicFamily,
        reason:
            'the Arabic arm is Amiri, and `arabicAware` is what decides '
            'it — the widget has no arm of its own',
      );
    });

    testWidgets('it is inked `--ink-1`, which is `ink2` here', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      expect(styleOf(tester).color, const EvaColors.dark().ink2);
      await pump(tester, theme: EvaThemeLight.theme);
      expect(styleOf(tester).color, const EvaColors.light().ink2);
    });

    testWidgets('it carries the prototype\'s margin', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      expect(
        PreviewLine.margin,
        const EdgeInsets.fromLTRB(2, 10, 2, 2),
        reason: '`redesign.html:431` — `margin:10px 2px 2px`',
      );
      final Padding padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(PreviewLine),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, PreviewLine.margin);
    });

    testWidgets('its size is the AMBIENT scale, so it grows with the reader\'s '
        'step', (WidgetTester tester) async {
      await pump(tester);
      expect(
        styleOf(tester).fontSize,
        PreviewLine.baseSize,
        reason: 'at a 1.0 scale the preview is its own base size',
      );

      await pump(tester, textScale: 1.22);
      expect(
        styleOf(tester).fontSize,
        closeTo(PreviewLine.baseSize * 1.22, 0.001),
        reason:
            '§14 names 1.22 as the scale the layout must survive, and the '
            'preview is the reading\'s own size',
      );
    });

    testWidgets('the base size is the scripture slot\'s own size', (
      WidgetTester tester,
    ) async {
      // The constant is written in the widget rather than read off the slot
      // (`TextStyle.fontSize` is a `double?`), so this is the assertion that
      // keeps the two from drifting.
      await pump(tester);
      final ThemeData theme = Theme.of(
        tester.element(find.byType(PreviewLine)),
      );
      expect(PreviewLine.baseSize, theme.textTheme.bodyLarge!.fontSize);
      expect(PreviewLine.baseSize, 16.0);
    });

    testWidgets('the size transition is `EvaMotion.base`, and §14 collapses it '
        'to nothing when animations are off', (WidgetTester tester) async {
      await pump(tester);
      expect(
        tester
            .widget<AnimatedDefaultTextStyle>(
              find.byType(AnimatedDefaultTextStyle),
            )
            .duration,
        EvaMotion.base,
        reason:
            '`redesign.html:431` — `transition:font-size .2s`, and `.2s` '
            'is `EvaMotion.base` exactly',
      );
      expect(EvaMotion.base, const Duration(milliseconds: 200));

      await pump(tester, disableAnimations: true);
      expect(
        tester
            .widget<AnimatedDefaultTextStyle>(
              find.byType(AnimatedDefaultTextStyle),
            )
            .duration,
        Duration.zero,
      );
    });

    testWidgets('the scale is applied once, not twice', (
      WidgetTester tester,
    ) async {
      // The size on the style is already scaled, so the `Text` must not carry
      // the ambient scaler as well — otherwise the preview would render at
      // `base × scale × scale` and the reader would see a preview of a
      // reading that is not the one they get.
      await pump(tester, textScale: 1.22);
      final Text rendered = tester.widget<Text>(find.byType(Text));
      expect(rendered.textScaler, TextScaler.noScaling);
      expect(
        styleOf(tester).fontSize,
        closeTo(PreviewLine.baseSize * 1.22, 0.001),
      );
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pump(tester, theme: data);
        await tester.pump();
        await expectLater(
          find.byType(PreviewLine),
          matchesGoldenFile('goldens/preview_line_$theme.png'),
        );
      });
    }
  });
}
