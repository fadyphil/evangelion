import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/eva_elevations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every named elevation in `EvaElevations`, by name.
///
/// ## WHY THIS TABLE IS THE ENUMERATION AND NOT A COMPARISON
///
/// The first version of this file asserted
/// `allElevations.map(…) == ['none', 'card', …]` over a `const List` built *from
/// `EvaElevations` itself*. That is a list compared against a copy of itself: it
/// cannot see a token added to the class, and the review confirmed it — adding
/// `EvaElevations.menu = 0` left it green while its own comment claimed the
/// opposite ("If a Phase-3 widget needs an elevation not named here, it has to be
/// added to this list in the same change — which is the point").
///
/// It cannot be fixed inside a test, because Dart has no reflection: there is no
/// way to enumerate an `abstract final class`'s `static const` members at run
/// time. So this file no longer pretends to hold an enumeration — the assertion it
/// carried was a list compared with a copy of itself, which could not see a new
/// token, and a second draft that spelled the token-to-consumer mapping out as a
/// test-local map had the same defect.
///
/// The mechanical half of the guarantee lives in `eva_theme_test.dart`, which
/// enumerates the *`ThemeData` fields* — seventeen of them, every elevation
/// Material still exposes — and asserts each resolves to `0`. That one has teeth:
/// delete a line and the field is `null`; pin Material's default and it is
/// non-zero. The half that cannot be mechanical is the direction from here to
/// there — that every token below is consumed by a field in that inventory —
/// and it is left as a named duty rather than dressed up as a check.
///
/// What this file *can* prove, and does, is that no token carries a positive
/// elevation.
const List<({String name, double value})> allElevations =
    <({String name, double value})>[
      (name: 'none', value: EvaElevations.none),
      (name: 'card', value: EvaElevations.card),
      (name: 'appBar', value: EvaElevations.appBar),
      (name: 'dialog', value: EvaElevations.dialog),
      (name: 'bottomSheet', value: EvaElevations.bottomSheet),
      (name: 'floatingActionButton', value: EvaElevations.floatingActionButton),
      (name: 'snackBar', value: EvaElevations.snackBar),
    ];

void main() {
  group('EvaElevations is flat, deliberately', () {
    test('every elevation is zero', () {
      // `docs/plans/03-design-system.md` §5 has NO elevation table. The colour
      // system (§5.1) supplies `line` — "the hairline colour" — and `glassShadow`,
      // which §5.4 calls the ambient shadow behind `GlassSurface`. There is no
      // third surface, no shadow ramp, no z-index scale anywhere in the spec or
      // in the React prototype it was extracted from: every `box-shadow` there
      // is either an ember glow or that one glass ambient.
      //
      // So the design system's layering is *hairline + tint*, not *shadow*: a
      // Material elevation of 0 everywhere is the faithful reading, and it is the
      // only value that can be stated without inventing a ramp. This test is
      // therefore a guard on a deliberate decision, and it is written to fail the
      // moment a positive elevation is introduced without a spec table to justify
      // it.
      for (final ({String name, double value}) elevation in allElevations) {
        expect(elevation.value, 0.0, reason: elevation.name);
      }
    });

    test('the inventory this file accounts for, spelled out', () {
      // Honest labelling, because the previous title — "the set covers every
      // surface a ThemeData can be asked to raise" — asserted something this file
      // cannot know. Dart cannot enumerate static consts, so nothing here can
      // detect a token that exists in `EvaElevations` but not in [allElevations].
      // What the assertions do buy is that the *expectation* is explicit: adding a
      // token and updating this list is a visible edit to a spelled-out set, at a
      // point where the editor is showing the reader the seven existing names.
      // That is documentation with a tripwire on the documentation, not a gate,
      // and it is not dressed up as one.
      expect(allElevations.length, 7);
      expect(
        allElevations.map((({String name, double value}) e) => e.name).toSet(),
        <String>{
          'none',
          'card',
          'appBar',
          'dialog',
          'bottomSheet',
          'floatingActionButton',
          'snackBar',
        },
        reason: 'the declared names, spelled out so a rename is a visible diff',
      );
      expect(
        allElevations
            .map((({String name, double value}) e) => e.name)
            .toSet()
            .length,
        allElevations.length,
        reason: 'no duplicate names',
      );
    });

    test('the one shadow in the system is a colour, not an elevation', () {
      // The design system does have a shadow, and it is not free-form: it is
      // `glassShadow`, a per-brightness token on `EvaColors`. Asserting it is
      // reachable and non-opaque here keeps the two files honest about each
      // other — a "flat" system that still had a shadow ramp would contradict
      // this, and one with no shadow at all would leave `glassShadow` orphaned.
      final EvaColors dark = const EvaColors.dark();
      final EvaColors light = const EvaColors.light();

      expect(dark.glassShadow.a, lessThan(1.0));
      expect(light.glassShadow.a, lessThan(1.0));
      expect(dark.glassShadow.a, isNot(light.glassShadow.a));
      expect(dark.glassShadow, isNot(dark.glassBorder));
    });
  });
}
