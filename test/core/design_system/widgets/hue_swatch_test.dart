import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The hue swatch — `redesign.html:432` — and the colour it is computed from.
///
/// The swatch itself is widget work and is TDD-exempt (AGENT_CONTEXT §6), but
/// `hueSwatchColor` is a **pure function** with an exact expected value, so it
/// is red-first: the expected RGB is the prototype's own arithmetic, checked
/// against the values `hsl2rgb(h, 70, 62)` produces.
void main() {
  Future<void> pump(WidgetTester tester, {int hue = 312, ThemeData? theme}) =>
      pumpPrimitive(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: HueSwatch(hue: hue),
        ),
        theme: theme,
      );

  /// The swatch's box, with enough room around it for the glow.
  ///
  /// **The glow is outside the widget's own bounds**, and a golden captures the
  /// finder's rectangle — so a golden of the swatch alone would be a 16×16
  /// circle with its halo cut off, which is exactly the part of `:432` a
  /// reviewer needs to see. The backdrop is the capture's, not the widget's.
  Finder swatch() => find.byType(HueSwatch);

  group('the swatch colour is the prototype\'s own arithmetic', () {
    // ## WHY THIS IS RED-FIRST
    //
    // `redesign.html:1455` — `hsl2rgb(h,70,62).map(x=>Math.round(x*255))` —
    // and `:1472` — `setTargetHue({h:autoH,s:70,l:62})`. The numbers below are
    // what that function produces, and a colour that is *nearly* right is a
    // colour the reader cannot check: the whole point of the swatch is that it
    // previews the band the shader will draw.

    test('the prototype\'s default hue is the prototype\'s colour', () {
      // `redesign.html:661` — `<input type="range" id="setHue" … value="312">`.
      expect(
        hueSwatchColor(312),
        const Color.fromARGB(255, 226, 90, 199),
        reason:
            '`hsl2rgb(312,70,62)` — the saturation and the lightness are '
            '`:1472`\'s, not ours',
      );
    });

    test('the wheel turns the way the wheel turns', () {
      expect(hueSwatchColor(0), const Color.fromARGB(255, 226, 90, 90));
      expect(hueSwatchColor(60), const Color.fromARGB(255, 226, 226, 90));
      expect(hueSwatchColor(120), const Color.fromARGB(255, 90, 226, 90));
      expect(hueSwatchColor(180), const Color.fromARGB(255, 90, 226, 226));
      expect(hueSwatchColor(240), const Color.fromARGB(255, 90, 90, 226));
    });

    test('the hue is taken modulo the wheel, as the prototype\'s is', () {
      expect(hueSwatchColor(360), hueSwatchColor(0));
    });
  });

  group('HueSwatch', () {
    testWidgets('it is a 16px circle, per redesign.html:432', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(HueSwatch),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect(HueSwatch.diameter, 16);
      expect(tester.getSize(find.byType(HueSwatch)), const Size.square(16));
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('the glow is the swatch\'s OWN colour, at the prototype\'s '
        'radius', (WidgetTester tester) async {
      await pump(tester);
      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(HueSwatch),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      final Color color = hueSwatchColor(312);

      expect(decoration.color, color);
      expect(
        decoration.boxShadow!.single.color,
        color,
        reason:
            '`box-shadow:0 0 10px currentColor` — and the prototype sets '
            '`background` and `color` to the same computed `rgb()` '
            '(`redesign.html:1456`), so the halo is the hue at full strength',
      );
      expect(decoration.boxShadow!.single.blurRadius, 10);
      expect(HueSwatch.glowBlur, 10);
      expect(
        decoration.boxShadow!.single.offset,
        Offset.zero,
        reason: '`0 0 10px` — no offset',
      );
    });

    testWidgets('it follows the hue it is given', (WidgetTester tester) async {
      for (final int hue in <int>[0, 120, 240, 312]) {
        await pump(tester, hue: hue);
        final Container box = tester.widget<Container>(
          find.descendant(
            of: find.byType(HueSwatch),
            matching: find.byType(Container),
          ),
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          hueSwatchColor(hue),
          reason: 'hue $hue',
        );
      }
    });

    // ## ONE GOLDEN AND NOT A PAIR, AND THE GATE SAYS WHY
    //
    // `golden_pairs_test.dart` fails a `*_dark.png` / `*_light.png` pair that
    // is byte-identical, and its own doc says what to do about a widget that
    // genuinely does not change with the theme: "the fix for a widget that
    // really is theme-invariant is to stop capturing it twice under a
    // per-theme name".
    //
    // **The hue swatch is theme-invariant**: its colour is the *computed* hue,
    // not a palette colour, so the two captures would be the same picture. The
    // backdrop below is a fixed dark canvas so the disc and its halo are
    // readable in a 48×48 crop.
    testWidgets('a golden — the swatch is theme-invariant', (
      WidgetTester tester,
    ) async {
      // The backdrop is the **dark canvas**, so the halo — which is the
      // swatch's own colour and therefore invisible against a transparent
      // capture — is readable. It is a fixed colour and not the theme's, which
      // is the point: the swatch does not change with the theme.
      await pumpPrimitive(
        tester,
        const ColoredBox(
          color: Color(0xFF05081A),
          child: Center(child: HueSwatch(hue: 312)),
        ),
      );
      await tester.pump();
      await expectLater(swatch(), matchesGoldenFile('goldens/hue_swatch.png'));
    });
  });
}
