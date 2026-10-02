import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// RED-FIRST — §14's "No focus indicators" row has no owner until this passes.
///
/// `09-quality-gates.md` §14: "`Focus` + a 2px `ember` ring at 40% alpha on
/// every interactive widget". Nine Tier-1 widgets are interactive. A per-widget
/// convention with nine chances to forget it is the same defect as the
/// documented-but-unenforced blur budget Phase 2 had to fix, so the numbers live
/// in one resolver and the resolver is pinned here.
///
/// The behavioural half — that each widget actually *draws* what this returns —
/// is `focus_ring_gate_test.dart`. This file pins the numbers, so a change to
/// either the width or the alpha is a red in one place rather than nine.
void main() {
  group('the §14 focus ring spec', () {
    test('is 2px', () {
      expect(evaFocusRingSpec(const EvaColors.dark()).width, 2.0);
      expect(evaFocusRingSpec(const EvaColors.light()).width, 2.0);
    });

    test('is ember at 40% alpha, in both palettes', () {
      const EvaColors dark = EvaColors.dark();
      const EvaColors light = EvaColors.light();

      final Color darkRing = evaFocusRingSpec(dark).color;
      final Color lightRing = evaFocusRingSpec(light).color;

      expect(darkRing.r, moreOrLessEquals(dark.ember.r));
      expect(darkRing.g, moreOrLessEquals(dark.ember.g));
      expect(darkRing.b, moreOrLessEquals(dark.ember.b));
      expect(darkRing.a, moreOrLessEquals(0.40, epsilon: 0.001));

      expect(lightRing.r, moreOrLessEquals(light.ember.r));
      expect(lightRing.g, moreOrLessEquals(light.ember.g));
      expect(lightRing.b, moreOrLessEquals(light.ember.b));
      expect(lightRing.a, moreOrLessEquals(0.40, epsilon: 0.001));
    });

    test('is the same colour ThemeData.focusColor already publishes', () {
      // Phase 1 wired `focusColor: colors.ember.withValues(alpha: 0.40)` with a
      // comment quoting §14. If the two ever disagree, a stock Material
      // `InkWell` hover/focus tint and this ring are two different ideas of the
      // same thing, and only one of them is the spec.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final ThemeData theme = EvaTheme.build(colors);
        expect(
          theme.focusColor,
          evaFocusRingSpec(colors).color,
          reason: 'the theme\'s focusColor and the ring must be one value',
        );
      }
    });

    test('is not transparent in either palette', () {
      // Guards the failure a literal `Colors.transparent` ring would produce:
      // every other assertion in this file would still pass, because a
      // transparent ember still *is* an ember at 40% as far as they look.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        expect(
          evaFocusRingSpec(colors).color.a,
          greaterThan(0),
          reason: 'a focus ring nobody can see is not an indicator',
        );
      }
    });

    test('is a Border that can be compared by value, for the gate', () {
      // The gate compares the rendered `Border` against this. A spec that only
      // exposed width and colour would force the gate to re-derive the
      // `Border`, and a gate that re-derives the value under test is a gate
      // that can agree with a wrong widget.
      final Border border = evaFocusRingBorder(const EvaColors.dark());
      expect(border.top.width, 2.0);
      expect(border.isUniform, isTrue);
      expect(border.top.color, evaFocusRingSpec(const EvaColors.dark()).color);
    });
  });

  group('EvaFocusRingSpec is a value, not a mutable box', () {
    test('two resolutions of the same palette are equal', () {
      expect(
        evaFocusRingSpec(const EvaColors.dark()),
        evaFocusRingSpec(const EvaColors.dark()),
      );
    });

    test('the dark and light rings differ', () {
      expect(
        evaFocusRingSpec(const EvaColors.dark()),
        isNot(evaFocusRingSpec(const EvaColors.light())),
      );
    });
  });
}
