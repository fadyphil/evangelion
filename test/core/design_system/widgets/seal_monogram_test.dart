import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

Widget _seal({ThemeData? theme, double size = 60, String letter = 'E'}) =>
    evaAmbientHarness(
      theme: theme,
      child: SizedBox(
        width: 160,
        height: 160,
        child: Center(
          child: SealMonogram(size: size, letter: letter),
        ),
      ),
    );

BoxDecoration _decoration(WidgetTester tester) {
  final Container container = tester.widget<Container>(
    find.descendant(
      of: find.byType(SealMonogram),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('geometry', () {
    test('the default is the prototype\'s 60px', () {
      const SealMonogram seal = SealMonogram();
      expect(seal.size, SealMonogram.defaultSize);
      expect(SealMonogram.defaultSize, 60.0);
    });

    testWidgets('is square at the size it was given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_seal(size: 48));
      final Size size = tester.getSize(find.byType(SealMonogram));
      expect(size, const Size.square(48));
    });

    testWidgets('honours a custom letter', (WidgetTester tester) async {
      await tester.pumpWidget(_seal(letter: 'V'));
      expect(find.text('V'), findsOneWidget);
    });
  });

  group('the decoration is the prototype\'s', () {
    // LoginScreen.tsx:17-26.
    testWidgets('a circle with a radial ember wash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_seal());
      final BoxDecoration decoration = _decoration(tester);
      expect(decoration.shape, BoxShape.circle);
      final RadialGradient gradient = decoration.gradient! as RadialGradient;
      expect(gradient.center, SealMonogram.sealGlowCenter);
      expect(gradient.radius, SealMonogram.sealGlowStop);
      expect(
        gradient.colors.first.toARGB32() & 0x00FFFFFF,
        const EvaColors.dark().ember.toARGB32() & 0x00FFFFFF,
      );
    });

    testWidgets('the wash starts at 35% 35%', (WidgetTester tester) async {
      // CSS measures the centre from the top-left; `Alignment` measures y from the
      // bottom, so 35% from the top is 0.35 * 2 - 1 = -0.3.
      expect(SealMonogram.sealGlowCenter, const Alignment(-0.3, -0.3));
      expect(SealMonogram.sealGlowCenter.x, -0.3);
      expect(SealMonogram.sealGlowCenter.y, -0.3);
    });

    testWidgets('a 1.5px ember rim at 0x66', (WidgetTester tester) async {
      await tester.pumpWidget(_seal());
      final Border border = _decoration(tester).border! as Border;
      expect(border.top.width, SealMonogram.sealBorderWidth);
      expect(SealMonogram.sealBorderWidth, 1.5);
      expect(
        (border.top.color.toARGB32() >> 24) & 0xFF,
        (SealMonogram.sealBorderAlpha * 255).round(),
        reason: 'the prototype\'s ember66 is 40%',
      );
    });

    testWidgets('two zero-offset ember glows', (WidgetTester tester) async {
      await tester.pumpWidget(_seal());
      final List<BoxShadow> shadows = _decoration(tester).boxShadow!;
      expect(shadows, hasLength(2));
      expect(shadows[0].blurRadius, 40);
      expect(shadows[1].blurRadius, 80);
      for (final BoxShadow shadow in shadows) {
        expect(shadow.offset, Offset.zero);
        expect(shadow.spreadRadius, 0);
      }
    });

    testWidgets('the glyph is 28px display 600 in ember at the default size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_seal());
      final Text glyph = tester.widget<Text>(
        find.descendant(
          of: find.byType(SealMonogram),
          matching: find.byType(Text),
        ),
      );
      final TextStyle style = glyph.style!;
      expect(style.fontFamily, EvaTypography.displayFamily);
      expect(style.fontSize, closeTo(28.0, 0.05));
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, const EvaColors.dark().ember);
    });

    testWidgets('the glyph scales with the seal', (WidgetTester tester) async {
      await tester.pumpWidget(_seal(size: 30));
      final Text glyph = tester.widget<Text>(
        find.descendant(
          of: find.byType(SealMonogram),
          matching: find.byType(Text),
        ),
      );
      expect(glyph.style!.fontSize, closeTo(14.0, 0.05));
    });
  });

  group('the glow is not an elevation', () {
    test('every EvaElevations token is still zero', () {
      // AGENT_CONTEXT §9 decision 7 — the two ember glows here are zero-offset
      // decoration, which is exactly the category §9 allows without an elevation
      // ramp. This is the assertion that says so.
      expect(EvaElevations.card, 0.0);
      expect(EvaElevations.none, 0.0);
    });
  });

  group('semantics — the mark is not decoration', () {
    testWidgets('carries a label', (WidgetTester tester) async {
      await tester.pumpWidget(_seal());
      final node = tester.getSemantics(find.byType(SealMonogram));
      expect(node.label, 'Evangelion');
    });

    testWidgets('defaults to the wordmark', (WidgetTester tester) async {
      await tester.pumpWidget(_seal());
      expect(find.bySemanticsLabel('Evangelion'), findsOneWidget);
    });

    testWidgets('takes a custom label', (WidgetTester tester) async {
      await tester.pumpWidget(
        evaAmbientHarness(
          child: const SealMonogram(semanticLabel: 'Study with us'),
        ),
      );
      expect(find.bySemanticsLabel('Study with us'), findsOneWidget);
    });

    testWidgets('does not read out the bare glyph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_seal());
      expect(find.bySemanticsLabel('E'), findsNothing);
    });
  });

  group('theming', () {
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await tester.pumpWidget(_seal(theme: theme));
        await tester.pump();
        await expectLater(
          find.byType(SealMonogram),
          matchesGoldenFile('goldens/seal_monogram_$label.png'),
        );
      });
    }

    testWidgets('light mode uses the light ember everywhere', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_seal(theme: EvaThemeLight.theme));
      final Text glyph = tester.widget<Text>(
        find.descendant(
          of: find.byType(SealMonogram),
          matching: find.byType(Text),
        ),
      );
      expect(glyph.style!.color, const EvaColors.light().ember);
    });
  });
}
