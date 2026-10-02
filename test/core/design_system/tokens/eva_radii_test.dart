import 'package:evangelion/core/design_system/tokens/eva_radii.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the radius tokens', () {
    test('carry the seven spec values', () {
      // §5.3: "buttons 14 · inputs 14 · cards 18 · quiz options 18 · chips 999 ·
      // hero panel 24 · glass form 28". Two of the seven values are shared by
      // two roles; every other assertion here treats them independently, because
      // they are independently spec'd and one of them can move without the
      // other.
      expect(EvaRadii.button, 14.0);
      expect(EvaRadii.input, 14.0);
      expect(EvaRadii.card, 18.0);
      expect(EvaRadii.quizOption, 18.0);
      expect(EvaRadii.chip, 999.0);
      expect(EvaRadii.heroPanel, 24.0);
      expect(EvaRadii.glassForm, 28.0);
    });

    test('chips are a pill, every other corner is a small rounding', () {
      // 999 is not "very round", it is "rounder than the longest side", which is
      // how `BorderRadius.circular` is asked to mean a pill. Asserting it as an
      // inequality rather than as `> 1000` keeps the intent — it must exceed
      // any real widget's shortest side, and no sane screen is 999px wide.
      expect(EvaRadii.chip, greaterThan(EvaRadii.heroPanel));
      expect(
        EvaRadii.chip,
        greaterThan(EvaRadii.glassForm),
        reason: 'the pill must exceed every non-pill radius by a wide margin',
      );

      // The other five are corner roundings on 14–28px surfaces.
      for (final MapEntry<String, double> entry in <String, double>{
        'button': EvaRadii.button,
        'input': EvaRadii.input,
        'card': EvaRadii.card,
        'quizOption': EvaRadii.quizOption,
        'heroPanel': EvaRadii.heroPanel,
        'glassForm': EvaRadii.glassForm,
      }.entries) {
        expect(entry.value, greaterThan(0.0), reason: entry.key);
        expect(
          entry.value,
          lessThan(EvaRadii.chip),
          reason: '${entry.key} must not be a pill',
        );
      }
    });

    test('rounding grows with the surface it wraps', () {
      // The glass form (28) is the outermost container on a screen and the quiz
      // option (18) is nested inside it. An inner surface rounder than its
      // container reads as a mistake, and this is the cheapest place to catch it.
      expect(EvaRadii.glassForm, greaterThan(EvaRadii.heroPanel));
      expect(EvaRadii.heroPanel, greaterThan(EvaRadii.card));
      expect(EvaRadii.card, greaterThanOrEqualTo(EvaRadii.button));
    });

    test('produce usable BorderRadius values', () {
      // The tokens are bare doubles; a widget wraps them in
      // `BorderRadius.circular`. Assert the wrap actually happens, so the
      // contract is "a number that goes into `BorderRadius.circular`" and not
      // "a radius, or a radius for some values".
      final BorderRadius wrapped = BorderRadius.circular(EvaRadii.card);
      expect(wrapped.topLeft.x, 18.0);
      expect(wrapped.topLeft.y, 18.0);
      expect(wrapped.bottomRight.x, 18.0);

      expect(
        BorderRadius.circular(EvaRadii.chip).topLeft.x,
        999.0,
        reason: 'the chip is Radius.circular(999) per the spec',
      );
    });
  });
}
