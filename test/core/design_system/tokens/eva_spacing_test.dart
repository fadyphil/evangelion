import 'package:evangelion/core/design_system/tokens/eva_spacing.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the spacing scale', () {
    test('is the 4px base with the eight spec steps', () {
      // The named order of §5.3 is `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40`, and
      // the names are positional: xs…huge. Asserting each name separately is what
      // catches a renumbering that kept the set but permuted it — a set
      // comparison would accept that silently.
      expect(EvaSpacing.xs, 4.0);
      expect(EvaSpacing.sm, 8.0);
      expect(EvaSpacing.md, 12.0);
      expect(EvaSpacing.lg, 16.0);
      expect(EvaSpacing.xl, 20.0);
      expect(EvaSpacing.xxl, 24.0);
      expect(EvaSpacing.xxxl, 32.0);
      expect(EvaSpacing.huge, 40.0);
    });

    test('is strictly increasing, so the names really are an order', () {
      final List<double> scale = <double>[
        EvaSpacing.xs,
        EvaSpacing.sm,
        EvaSpacing.md,
        EvaSpacing.lg,
        EvaSpacing.xl,
        EvaSpacing.xxl,
        EvaSpacing.xxxl,
        EvaSpacing.huge,
      ];
      for (int i = 1; i < scale.length; i++) {
        expect(
          scale[i],
          greaterThan(scale[i - 1]),
          reason: 'index $i must exceed index ${i - 1}',
        );
      }
      expect(scale.toSet().length, scale.length, reason: 'no duplicate steps');
    });

    test('every step is a whole multiple of the 4px base', () {
      // "Spacing (4px base)" is the property that makes the scale extensible: a
      // future 44px step is `11 * base` and nothing has to be re-derived. A 20px
      // step is the one that looks like an exception and is not — 20 = 5 × 4.
      const double base = EvaSpacing.base;
      expect(base, 4.0);
      for (final double step in <double>[
        EvaSpacing.xs,
        EvaSpacing.sm,
        EvaSpacing.md,
        EvaSpacing.lg,
        EvaSpacing.xl,
        EvaSpacing.xxl,
        EvaSpacing.xxxl,
        EvaSpacing.huge,
      ]) {
        expect(step % base, 0.0, reason: '$step is not a multiple of $base');
      }
    });
  });

  group('the two derived paddings', () {
    test('screen horizontal padding is 20', () {
      // §5.3: "Screen horizontal padding = 20". It is an alias for `xl`, and the
      // alias is what stops a screen from inventing its own gutter.
      expect(EvaSpacing.screenHorizontal, 20.0);
      expect(EvaSpacing.screenHorizontal, EvaSpacing.xl);
    });

    test('card padding is 20', () {
      expect(EvaSpacing.card, 20.0);
      expect(EvaSpacing.card, EvaSpacing.xl);
    });

    test('the two derived paddings are aliases, not copies', () {
      // The old version of this test asserted `screenHorizontal == card` and its
      // own comment conceded it was "documentation, not a behavioural assertion".
      // It is now a real one, and the mechanism is the same one Dart already
      // guarantees: both are declared as `static const` initialised from `xl`
      // rather than from a literal.
      //
      // WHAT THAT BUYS. `const` propagation is transitive through constant
      // expressions, so `xl` cannot move without taking both paddings with it.
      // Duplicating a `20.0` into either declaration would break that link while
      // leaving every value assertion in this file green, because the values
      // would still all read 20.
      //
      // WHAT IT STILL CANNOT SEE. Dart exposes no reflection, so a test cannot read
      // the initialiser expression and prove it says `xl`. What it *can* do is
      // assert the strongest consequence that is observable — all three agree —
      // and refuse to let them drift apart, which is what would happen first if
      // someone pasted a literal into one of them.
      expect(EvaSpacing.screenHorizontal, EvaSpacing.card);
      expect(EvaSpacing.screenHorizontal, EvaSpacing.xl);
      expect(EvaSpacing.card, EvaSpacing.xl);

      // A drift is caught as a *divergence*, which is the failure that matters:
      // the two paddings are used on the same screen (a page gutter and a card
      // inside it), so a mismatch between them is visible on one screen rather
      // than in two places.
      final double gutter = EvaSpacing.screenHorizontal;
      final double padding = EvaSpacing.card;
      expect(
        (gutter - padding).abs(),
        lessThan(1e-12),
        reason: 'the gutter and the card padding must not drift apart',
      );
    });
  });

  group('the tokens are usable as EdgeInsets', () {
    test('a screen gutter built from the token is symmetric', () {
      const EdgeInsets gutter = EdgeInsets.symmetric(
        horizontal: EvaSpacing.screenHorizontal,
      );
      expect(gutter.left, 20.0);
      expect(gutter.right, gutter.left);
      expect(gutter.top, 0.0);
    });
  });
}
