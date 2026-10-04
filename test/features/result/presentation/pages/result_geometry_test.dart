/// `/result`'s transcribed geometry — the one claim `result_page.dart` pointed at a
/// file that did not exist.
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
/// `/result` has **one** geometry claim worth a file, and it is here because the
/// alternative was a doc comment pointing at nothing. It is the most fragile
/// transcription in the screen:
///
/// > `ResultScreen.tsx:62-64` is an inline `<svg>` flame **14×18**, which is NOT the
/// > design system's `StreakFlame` — that one is square (`streak_flame.dart`'s
/// > `size` sets width **and** height) and is transcribed from `ds.tsx:522`, a
/// > different site.
///
/// A square icon at 18 is visibly wider than the prototype's. Nothing in a diff says
/// so — `StreakFlame(size: 18)` reads correctly — and everything on screen does.
///
/// **The reverse direction, from `reading_geometry_test.dart`'s doc:** a Dart constant
/// nobody claims is a number with no prototype behind it, which is how
/// `kSocialButtonGap` survived certification while nothing read it. The other twenty
/// `ResultPage` constants are not claimed here; claiming them needs the per-arm line
/// map above, and inventing prototype lines for them would be worse than leaving them.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/design_system/widgets/streak_flame.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/quiz_harness.dart';

void main() {
  group('the streak pill\'s flame is the prototype\'s 14×18, not a square', () {
    test('and the two numbers are a **pair**, not one size', () {
      // The claim is a `width`/`height` **pair**, so asserting one of them proves
      // nothing — which is why the divergence is easy to reintroduce: change
      // `pillFlameWidth` to 18 and every constant-comparison test in the repo still
      // passes.
      expect(ResultPage.pillFlameWidth, 14);
      expect(ResultPage.pillFlameHeight, 18);
      expect(
        ResultPage.pillFlameWidth,
        isNot(ResultPage.pillFlameHeight),
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
      await pumpQuizFrames(tester, 2);

      final Finder sized = find.ancestor(
        of: find.byType(StreakFlame),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is SizedBox &&
              widget.width == ResultPage.pillFlameWidth &&
              widget.height == ResultPage.pillFlameHeight,
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
        lessThanOrEqualTo(ResultPage.pillFlameWidth + 0.5),
        reason:
            'the square `StreakFlame` is fitted down into the 14-wide box. Without the '
            '`SizedBox` the painted flame is 18 wide and the pill is visibly wider '
            'than `ResultScreen.tsx:62-64`',
      );
      expect(
        rect.height,
        moreOrLessEquals(ResultPage.pillFlameHeight, epsilon: 0.5),
      );
    });

    testWidgets('and the pill is laid out with it, not overflowing', (
      WidgetTester tester,
    ) async {
      // The consequence the pair exists to avoid, asserted at §14's own surface.
      // `arabic_typography_test.dart` gates the glyphs and `result_page_test.dart`
      // gates the texts; neither of them can see a 4px-wide layout error.
      tester.view.physicalSize = kGeometrySurface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpResult(tester, result: contractSubmitAnswerFixture);
      await pumpQuizFrames(tester, 2);

      expect(tester.takeException(), isNull);
      expect(find.byType(StreakFlame), findsOneWidget);
    });
  });
}
