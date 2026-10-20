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
    // `eva/redesign.html:392-395` — `.jorb`, the orb this seal is the counterpart
    // of. The superseded prototype's 60px box and its two shadows have **no
    // counterpart in the redesign**, which draws a 74px orb with one shadow.
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

    testWidgets('the wash starts at 35% 30% — redesign.html:393', (
      WidgetTester tester,
    ) async {
      // `circle at 35% 30%`. The `y` moved from the old `35% 35%`: the redesign
      // raises the wash's centre by five points, and that is the whole of the
      // `:393` contribution this widget adopts.
      //
      // CSS measures the centre from the top-left; `Alignment` measures y from the
      // top too, so 35% from the top is `0.35 * 2 - 1 = -0.3` and 30% from the top
      // is `0.30 * 2 - 1 = -0.4`. Two different numbers, which is the point: a
      // test that asserted `-0.3` for both axes would pass against the old value.
      expect(SealMonogram.sealGlowCenter, const Alignment(-0.3, -0.4));
      expect(SealMonogram.sealGlowCenter.x, -0.3);
      expect(SealMonogram.sealGlowCenter.y, -0.4);
    });

    test('and the box stays 60 — the superseded prototype\'s, and NOT :392\'s 74', () {
      // `redesign.html:392` says `width: 74px`. The redesign's `/login`
      // (`:503-511`) draws `.lmark` + `.field` + `.cta` and no orb; the orb is the
      // Journey avatar (`:586`, `<div class="jorb">M</div>`). So 74 is a number
      // belonging to a screen that does not exist in this client, and `login_geometry
      // _test.dart` asserts the painted seal is `60` by literal.
      expect(SealMonogram.defaultSize, 60.0);
      expect(SealMonogram.defaultSize, isNot(74.0));
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
      // Kept from the superseded prototype. `redesign.html:394` writes ONE
      // `0 0 34px rgba(232,176,75,.5)`, and adopting it would mean deleting a
      // glow pair that no harness reads but every golden does.
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

    testWidgets('the glyph is 28px display 600 in onEmber', (
      WidgetTester tester,
    ) async {
      // `redesign.html:394` — `color: #1c1608`. That is not a §5.1 value, and
      // `onEmber` is the role's token: gold fills, `onEmber` writes. The old
      // value was `ember` — the *same* token as the wash underneath it, which on
      // the light palette is `#D4891A` on an ember wash at 2.0:1.
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
      expect(style.color, const EvaColors.dark().onEmber);
    });

    test('and the ink is NOT the wash, in either palette', () {
      // The defect `:394` fixes, asserted as the relationship rather than as a
      // colour: a gold disc with a gold letter on it is the same token twice.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        expect(colors.onEmber, isNot(colors.ember));
      }
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

    test('and the ratio is the prototype\'s 28-on-60, not `:394`\'s', () {
      // `:394` is `font-size: 30px` on a **74px** orb — 0.405. This is
      // the superseded prototype's 28 on a 60px seal. Two marks at two sizes have
      // two
      // ratios, and the 60 is held by `login_geometry_test.dart` by literal.
      expect(SealMonogram.glyphRatio, closeTo(28 / 60, 1e-4));
      expect(SealMonogram.glyphRatio, isNot(closeTo(30 / 74, 1e-4)));
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

    testWidgets('light mode uses the light ink and the light ember', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_seal(theme: EvaThemeLight.theme));
      final Text glyph = tester.widget<Text>(
        find.descendant(
          of: find.byType(SealMonogram),
          matching: find.byType(Text),
        ),
      );
      // The **ink** is `onEmber` (`#3A1E00` in light), not the light `ember`
      // (`#D4891A`). Asserting `ember` here is what the pre-restyle test did, and
      // it is exactly the 2.0:1 pairing `:394`'s `color: #1c1608` exists to fix.
      expect(glyph.style!.color, const EvaColors.light().onEmber);
      final RadialGradient wash =
          _decoration(tester).gradient! as RadialGradient;
      expect(
        wash.colors.first.toARGB32() & 0x00FFFFFF,
        const EvaColors.light().ember.toARGB32() & 0x00FFFFFF,
        reason:
            'the wash is the gold that FILLS; the glyph is the ink that WRITES',
      );
    });
  });
}
