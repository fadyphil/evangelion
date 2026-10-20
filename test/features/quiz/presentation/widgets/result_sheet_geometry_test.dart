/// The result **card**'s transcribed geometry — the one claim `result_sheet.dart`
/// pointed at a file that did not exist.
///
/// ## WHY THIS FILE IS SMALL, AND WHAT IT IS **NOT**
///
/// `login_geometry_test.dart`, `home_geometry_test.dart` and
/// `reading_geometry_test.dart` each carry a **per-arm line map**: every claim names a
/// prototype file and line, the prototype's own text on that line is read at test
/// time, and a renumbered prototype turns the suite red. `/quiz`'s is
/// `quiz_geometry_test.dart`, which carries three claims and says in its own library
/// doc that it is not that harness either.
///
/// The card has **one** geometry claim worth a file, and it is here because the
/// alternative was a doc comment pointing at nothing. It is the most fragile
/// transcription in the surface:
///
/// > The superseded prototype's result card held an inline `<svg>` flame **14×18**,
/// > which is NOT the design system's `StreakFlame` — that one is square
/// > (`streak_flame.dart`'s `size` sets width **and** height) and is transcribed
/// > from the prototype's own top bar, a different site. The redesign's own
/// > `.flame` is `13×17` (`redesign.html:242`) — a third shape, and a fourth
/// > number the client does not use.
///
/// A square icon at 18 is visibly wider than the prototype's. Nothing in a diff says
/// so — `StreakFlame(size: 18)` reads correctly — and everything on screen does.
///
/// **The reverse direction, from `reading_geometry_test.dart`'s doc:** a Dart constant
/// nobody claims is a number with no prototype behind it, which is how
/// `kSocialButtonGap` survived certification while nothing read it. The other twenty
/// `ResultSheet` constants are not claimed here; claiming them needs the per-arm line
/// map above, and inventing prototype lines for them would be worse than leaving them.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/design_system/widgets/streak_flame.dart';
import 'package:evangelion/features/quiz/presentation/widgets/result_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/quiz_harness.dart';

/// Pumps until the card has **arrived**.
///
/// The card enters at `.9` and grows to `1` over 500ms (`:444-446`), and the
/// measurement below is of the **painted** box — which walks the ancestor
/// transforms, so a measurement taken four frames in is of a card that has not
/// arrived yet.
///
/// **The first version measured at four frames** and read `17.03` where the
/// claim is `18`: the flame was `18 × 0.946`, the scale the entrance was at
/// that moment. The number was not wrong about the flame — it was wrong about
/// *when*, and it would have read `17.03` for a reason no reader could see.
///
/// Forty frames of 16ms is 640ms, which is past the 500ms entrance.
Future<void> pumpTheCardAtRest(WidgetTester tester) =>
    pumpQuizFrames(tester, 40);

void main() {
  group('the streak pill\'s flame is the prototype\'s 14×18, not a square', () {
    test('and the two numbers are a **pair**, not one size', () {
      // The claim is a `width`/`height` **pair**, so asserting one of them proves
      // nothing — which is why the divergence is easy to reintroduce: change
      // `pillFlameWidth` to 18 and every constant-comparison test in the repo still
      // passes.
      expect(ResultSheet.pillFlameWidth, 14);
      expect(ResultSheet.pillFlameHeight, 18);
      expect(
        ResultSheet.pillFlameWidth,
        isNot(ResultSheet.pillFlameHeight),
        reason:
            'if these ever agree, the file has substituted the design system\'s square '
            '`StreakFlame` for the prototype\'s inline `<svg>`, and the doc\'s stated '
            'reason for the `SizedBox` + `FittedBox` pair stops applying',
      );
    });

    testWidgets('and the RENDERED box is 14 wide and 18 tall', (
      WidgetTester tester,
    ) async {
      // Rendered, not constant. `StreakFlame(size: 18)` inside a `SizedBox` and a
      // `FittedBox(fit: BoxFit.contain)` is the mechanism, and the mechanism is what a
      // constant comparison cannot see — the same defect class the other geometry
      // suites name.
      await pumpResult(tester, result: contractSubmitAnswerFixture);
      await pumpTheCardAtRest(tester);

      final Finder sized = find.ancestor(
        of: find.byType(StreakFlame),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is SizedBox &&
              widget.width == ResultSheet.pillFlameWidth &&
              widget.height == ResultSheet.pillFlameHeight,
        ),
      );
      expect(
        sized,
        findsOneWidget,
        reason: 'the box that sets the pair is present',
      );

      final Rect rect = tester.getRect(find.byType(StreakFlame));
      expect(
        rect.width,
        lessThanOrEqualTo(ResultSheet.pillFlameWidth + 0.5),
        reason:
            'the square `StreakFlame` is fitted down into the 14-wide box. Without the '
            '`SizedBox` the painted flame is 18 wide and the pill is visibly wider '
            'than the superseded prototype\'s 14-wide inline flame',
      );
      expect(
        rect.height,
        moreOrLessEquals(ResultSheet.pillFlameHeight, epsilon: 0.5),
      );
    });

    testWidgets('and the pill is laid out with it, not overflowing', (
      WidgetTester tester,
    ) async {
      // The consequence the pair exists to avoid, asserted at §14's own surface.
      // `arabic_typography_test.dart` gates the glyphs and `result_sheet_test.dart`
      // gates the texts; neither of them can see a 4px-wide layout error.
      tester.view.physicalSize = kGeometrySurface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpResult(tester, result: contractSubmitAnswerFixture);
      await pumpTheCardAtRest(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(StreakFlame), findsOneWidget);
    });
  });
}
