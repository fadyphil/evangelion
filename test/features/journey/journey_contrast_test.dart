import 'dart:math' as math;

import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The measured contrast of `/journey`'s three ring strokes — **a finding, not
/// a thing to fix**.
///
/// ## WHY THIS FILE IS A TEST AND NOT A NOTE
///
/// The ring strokes are **non-text UI components**: WCAG 1.4.11 wants 3:1
/// against the surface they sit on. The repository's mechanism for a measured
/// exception is `knownSubstandard` in `text_contrast_gate_test.dart` — and
/// **that list is for text**. So a non-text exception has no home there, and
/// this file is the home: the numbers are measured, asserted, and written down
/// where a reader will find them.
///
/// ## THE MEASUREMENT
///
/// WCAG 2.1's relative luminance and contrast ratio, against **this client's
/// own palettes** — `EvaColors.dark().canvas` `#05081A`,
/// `EvaColors.dark().surface` `#0D1224`, `EvaColors.light().canvas` `#F0EEFF`
/// and `EvaColors.light().surface` `#FFFFFF`.
///
/// | stroke | dark / canvas | dark / surface | light / canvas | light / surface |
/// | --- | --- | --- | --- | --- |
/// | teal `#3EC9B0` | 9.65 | 9.02 | **1.80** | **2.06** |
/// | magenta `#E457D6` | 6.28 | 5.87 | **2.77** | 3.17 |
/// | blue `#4F74FF` | 4.99 | 4.67 | 3.48 | 3.98 |
///
/// ## THE FINDING
///
/// **The light theme's teal and magenta fail 3:1, and so does the prototype.**
/// The redesign has **no light-mode override for the strokes** — `:79`
/// overrides only the *track* — so the prototype's own light arm has the same
/// two failing strokes.
///
/// **And substitution does not fix it.** Every candidate token fails as well:
///
/// | candidate | light / canvas |
/// | --- | --- |
/// | sticker teal `#4EC9BD` | 1.76 |
/// | sticker sky `#7CC4F0` | 1.67 |
/// | sticker lavender `#B79CF0` | 2.04 |
/// | sticker pink `#F58FC4` | 1.91 |
///
/// So **the hue is not changed to make a number pass** — a darker teal would
/// be a different colour from the prototype's, and the ring would no longer
/// be the redesign's. The transcription is both more faithful and no worse.
///
/// ## AND THE INFORMATION IS **NOT COLOUR-ONLY**
///
/// The ring's **value** is painted in `ink` and its **label** in `ink2`, and
/// both are text. The last group below measures those two and holds them to
/// the **4.5:1 text floor**, so the number and the unit are legible whatever
/// the stroke's own contrast is.
void main() {
  group('the ring strokes, measured', () {
    test('the dark theme clears 3:1 on both surfaces', () {
      for (final (String name, Color stroke) in _strokes) {
        expect(
          _ratio(stroke, const EvaColors.dark().canvas),
          greaterThanOrEqualTo(3),
          reason: '$name on the dark canvas',
        );
        expect(
          _ratio(stroke, const EvaColors.dark().surface),
          greaterThanOrEqualTo(3),
          reason: '$name on the dark surface',
        );
      }
    });

    test('the light theme fails 3:1 on the teal and the magenta', () {
      // **Asserted, not skipped.** A test that only checked the passing arm
      // would let the hue drift without anybody noticing, and the numbers
      // below are the receipt for the divergence recorded in
      // `journey_colours.dart`.
      expect(
        _ratio(journeyRingTeal, const EvaColors.light().canvas),
        closeTo(1.80, 0.01),
      );
      expect(
        _ratio(journeyRingTeal, const EvaColors.light().surface),
        closeTo(2.06, 0.01),
      );
      expect(
        _ratio(const Color(0xFFE457D6), const EvaColors.light().canvas),
        closeTo(2.77, 0.01),
      );
      expect(
        _ratio(const Color(0xFFE457D6), const EvaColors.light().surface),
        closeTo(3.17, 0.01),
      );
    });

    test('the light theme clears 3:1 on the blue', () {
      expect(
        _ratio(journeyRingBlue, const EvaColors.light().canvas),
        closeTo(3.48, 0.01),
      );
      expect(
        _ratio(journeyRingBlue, const EvaColors.light().surface),
        closeTo(3.98, 0.01),
      );
    });

    test('and no candidate token clears it either', () {
      // **The measurement that closes the substitution question.** If one of
      // these cleared 3:1, "use a token instead" would be a real answer and
      // the transcription would have to be re-argued.
      for (final (String name, Color candidate) in <(String, Color)>[
        ('sticker teal', const Color(0xFF4EC9BD)),
        ('sticker sky', const Color(0xFF7CC4F0)),
        ('sticker lavender', const Color(0xFFB79CF0)),
        ('sticker pink', const Color(0xFFF58FC4)),
      ]) {
        expect(
          _ratio(candidate, const EvaColors.light().canvas),
          lessThan(3),
          reason:
              '$name clears 3:1 on the light canvas — so a substitution would '
              'have been possible, and the divergence needs re-reading',
        );
      }
    });
  });

  group('the information is not colour-only', () {
    test('the ring\'s value and label clear the 4.5:1 text floor', () {
      // The ring's **value** is `ink` and its **label** is `ink2` — and both
      // are text, so the number and the unit are legible whatever the stroke
      // measures.
      for (final (String name, Color ink) in <(String, Color)>[
        ('ink', const EvaColors.dark().ink),
        ('ink2', const EvaColors.dark().ink2),
      ]) {
        expect(
          _ratio(ink, const EvaColors.dark().canvas),
          greaterThanOrEqualTo(4.5),
          reason: '$name on the dark canvas',
        );
      }
      for (final (String name, Color ink) in <(String, Color)>[
        ('ink', const EvaColors.light().ink),
        ('ink2', const EvaColors.light().ink2),
      ]) {
        expect(
          _ratio(ink, const EvaColors.light().canvas),
          greaterThanOrEqualTo(4.5),
          reason: '$name on the light canvas',
        );
      }
    });
  });
}

/// The three strokes, as the prototype's hexes.
final List<(String, Color)> _strokes = <(String, Color)>[
  ('teal #3EC9B0', journeyRingTeal),
  ('magenta #E457D6', const Color(0xFFE457D6)),
  ('blue #4F74FF', journeyRingBlue),
];

/// The relative luminance of [colour], in WCAG 2.1's units.
double _luminance(Color colour) {
  double channel(double value) {
    final double c = value;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  final double r = channel(colour.r);
  final double g = channel(colour.g);
  final double b = channel(colour.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// The contrast ratio of [a] against [b], in WCAG 2.1's units.
double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
