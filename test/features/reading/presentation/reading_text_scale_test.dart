import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/reading/presentation/reading_text_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `readingTextScalerFor` — red-first (AGENT_CONTEXT §6: "domain logic", and this
/// is the composition rule §14's 1.22× requirement rests on).
void main() {
  double factorOf(TextScaler scaler) => scaler.scale(1);

  test(
    'the step alone drives the result on a platform that does not scale',
    () {
      // The default install: `MediaApp`'s platform scaler is the identity.
      for (int step = kFontStepMin; step <= kFontStepMax; step++) {
        expect(
          factorOf(
            readingTextScalerFor(step: step, platform: TextScaler.noScaling),
          ),
          evaScalerFor(step).scale(1),
          reason: 'step $step must render at the table own value',
        );
      }
    },
  );

  test('the two settings COMPOSE, so neither is discarded', () {
    // The product, and the table above in the file's doc lists the three
    // alternatives with the measurement that rules each of them out. The numbers
    // here are the two ends of the control on a default device, which is where
    // `max(platform, step)` collapses steps 1–3 into one position.
    expect(
      factorOf(readingTextScalerFor(step: 1, platform: TextScaler.noScaling)),
      closeTo(0.90, 0.0001),
      reason: 'the smallest step must actually be smaller',
    );
    expect(
      factorOf(readingTextScalerFor(step: 2, platform: TextScaler.noScaling)),
      closeTo(0.95, 0.0001),
    );
  });

  test('and a raised OS setting is ADDED TO, never rounded away', () {
    // The property that rules out `max`: at platform 1.22 and step 1 the reader
    // gets 1.10 — larger than the platform asked for, because they also asked for a
    // step, and the product is the only rule that honours both.
    final TextScaler scaled = readingTextScalerFor(
      step: 1,
      platform: const TextScaler.linear(1.22),
    );
    expect(factorOf(scaled), closeTo(1.22 * 0.90, 0.0001));
    expect(
      factorOf(scaled),
      greaterThan(1.0),
      reason:
          'and it is NOT the platform\'s own 1.22 — `max` would return exactly '
          'that, which is the whole reason `max` was rejected',
    );
    expect(factorOf(scaled), isNot(1.22));
  });

  test(
    'the product is CAPPED at the top of the design system\'s own table',
    () {
      // §14's requirement is stated at 1.22× and that is the only size this app has
      // been laid out for. 1.22 × 1.22 = 1.4884 is not a number any layout here has
      // been checked against, so it is capped — and the cap is the TABLE's top row,
      // not a literal, so a table that moves drags the ceiling with it.
      final TextScaler scaled = readingTextScalerFor(
        step: 5,
        platform: const TextScaler.linear(1.22),
      );
      expect(factorOf(scaled), 1.22);
      expect(factorOf(scaled), isNot(closeTo(1.22 * 1.22, 0.01)));
      expect(kEvaScaleCeiling, 1.22);
      expect(kEvaScaleCeiling, evaScalerFor(kFontStepMax).scale(1));
    },
  );

  test('and nothing this function returns ever exceeds the ceiling', () {
    for (int step = kFontStepMin; step <= kFontStepMax; step++) {
      for (final double platform in <double>[1.0, 1.1, 1.22, 1.5, 2.0]) {
        final double factor = factorOf(
          readingTextScalerFor(
            step: step,
            platform: TextScaler.linear(platform),
          ),
        );
        expect(
          factor,
          lessThanOrEqualTo(kEvaScaleCeiling),
          reason: 'step \$step at platform \$platform',
        );
        expect(factor, greaterThan(0), reason: 'and never zero or negative');
      }
    }
  });

  test('a step outside the table is CLAMPED, not trusted', () {
    // `clampFontStep` is the same boundary the stepper and a persisted setting go
    // through, so a corrupted step cannot reach `evaScalerFor`'s `_` arm as
    // something the knob does not own. §2 of `font_size_stepper.dart` requires it.
    expect(
      factorOf(readingTextScalerFor(step: 0, platform: TextScaler.noScaling)),
      evaScalerFor(kFontStepMin).scale(1),
    );
    expect(
      factorOf(readingTextScalerFor(step: 99, platform: TextScaler.noScaling)),
      evaScalerFor(kFontStepMax).scale(1),
    );
  });

  test('THE DEAD ZONE IS REAL, AND IT IS THE PRICE OF THE CEILING', () {
    // Above a platform scale of 1.109 the top three steps agree, because
    // 1.10 x 1.109 already reaches the ceiling. Asserted rather than left to be
    // discovered by a reader who raised their OS font size and then found the
    // control's top half inert.
    double at(int step, double platform) => factorOf(
      readingTextScalerFor(step: step, platform: TextScaler.linear(platform)),
    );
    expect(at(3, 1.22), 1.22);
    expect(at(4, 1.22), 1.22);
    expect(at(5, 1.22), 1.22);
    // …and below the threshold every position is distinct, which is the ordinary
    // case and the reason the ceiling is at the top of the table rather than lower.
    expect(at(3, 1.0), 1.0);
    expect(at(4, 1.0), 1.10);
    expect(at(5, 1.0), 1.22);
  });

  test('it returns a LINEAR scaler, which is the recorded cost', () {
    // Android's platform scaler is nonlinear and `TextScaler` has no `max` across
    // implementations, so the platform's curve is lost for this subtree. Asserted
    // so the cost is a fact about the code and not only a paragraph in the doc.
    final TextScaler scaled = readingTextScalerFor(
      step: 3,
      platform: TextScaler.noScaling,
    );
    expect(scaled, isA<TextScaler>());
    expect(factorOf(scaled), 1.0);
    // A linear scaler maps every input by the same factor — which is exactly the
    // property a nonlinear one would not have.
    expect(scaled.scale(10), 10 * factorOf(scaled));
    expect(scaled.scale(32), 32 * factorOf(scaled));
  });
}
