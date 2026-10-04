import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/home/presentation/home_strings.dart';
import 'package:evangelion/features/home/presentation/widgets/today_reading_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/home_harness.dart';

/// §14: "text scales to 1.22× without overflow at 320px width."
///
/// ## BOTH NUMBERS COME FROM THE DOCUMENT AND NEITHER IS NEGOTIABLE
///
/// `kNarrowSurface` is `Size(320, 568)` and `kEvaRequiredTextScale` is `1.22`, both
/// declared in `design_system_harness.dart` and both quoted from §14. They are used
/// rather than repeated so this file cannot drift from the other four suites that
/// assert the same requirement.
///
/// ## AND EVERY STATE IS MOUNTED, BECAUSE A LAYOUT IS NOT ONE THING
///
/// Loading, ready, failed, Arabic and no-session all lay out differently, and the
/// states with the most text — the eyebrow, the reference, the two CTAs, the
/// greeting — are the ones that wrap. A single "the ready screen does not overflow"
/// would leave the error view's long repository message untested at 1.22×, which is
/// precisely where a long string overflows.
void main() {
  /// The surface and the scale, named so a failure reads as §14's own words.
  const Size surface = kNarrowSurface;
  const double scale = kEvaRequiredTextScale;

  group('at 320x568 and 1.22x, no state overflows', () {
    testWidgets('ready, English', (WidgetTester tester) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: surface, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('ready, Arabic — a longer word for the same box', (
      WidgetTester tester,
    ) async {
      // Arabic script is *taller* at the same point size and the reference is a
      // wider string in practice, so the RTL arm is not a mirror of the LTR one.
      final HomeHarness h = harness();
      h.readings.scripture = const Result<ScriptureText>.success(
        liveArabicScripture,
      );
      await pumpHome(
        tester,
        bloc: h.bloc,
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('loading — the panel frame with no reading yet', (
      WidgetTester tester,
    ) async {
      // The loading **panel**, not the loading page: this is the widget whose layout
      // is at stake, and the page around it adds nothing. The loading state is
      // spelled out as `reading: null, failure: null` rather than reached through
      // `TodayReadingPanel.loading`, which was deleted in Phase 6's coverage pass
      // for having no production caller — its only caller was this test.
      //
      // A `Completer` that never completes was the first version's approach to
      // "still loading" and it **hangs the test** — measured, when
      // `test/support/app_harness.dart`'s fakes did that and four router suites
      // timed out at five minutes each with no error at all.
      await pumpPrimitive(
        tester,
        const TodayReadingPanel(
          reading: null,
          failure: null,
          strings: HomeStrings.en(),
          onOpenReading: null,
          onStartReflection: null,
          onRetry: null,
        ),
        size: surface,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('a failed READING, whose message is a long sentence', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result<ScriptureText>.failure(homeReadingFailure),
      );
      await pumpHome(tester, bloc: h.bloc, size: surface, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('a failed STREAK', (WidgetTester tester) async {
      final HomeHarness h = harness(
        streak: const Result<StreakSummary>.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc, size: surface, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('no session — the greeting closes and the avatar has no name', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(signedIn: false);
      await pumpHome(tester, bloc: h.bloc, size: surface, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });
  });

  group('and the panel survives the platform scaler alone, at the largest step', () {
    // `evaScalerFor(5)` is 1.22, the top of §5.2's table and the same number as
    // §14's requirement — so this asserts the two agree rather than stacking them,
    // which would be 1.22 x 1.22 and a requirement nobody has.
    testWidgets('1.22x is the requirement, and the panel renders it', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(
        tester,
        bloc: h.bloc,
        size: surface,
        textScale: evaScalerFor(5).scale(14) / 14,
      );

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });
  });

  group('the geometry that is fixed rather than scaled', () {
    testWidgets('the panel radius and padding are the prototype values', (
      WidgetTester tester,
    ) async {
      // §14 scales *text*. The radius and the padding are layout, and
      // `TodayReadingPanel` publishes them as constants so a golden or a geometry
      // test can read them rather than re-derive them.
      expect(TodayReadingPanel.radius, EvaRadii.heroPanel);
      expect(
        TodayReadingPanel.panelPadding,
        const EdgeInsets.fromLTRB(20, 20, 20, 16),
      );
    });
  });
}

/// Asserts that nothing in the tree reported an overflow.
///
/// **[WidgetTester.takeException] is null, and that is the mechanism.** A
/// `RenderFlex` overflow raises a `FlutterError` through `FlutterError.onError`,
/// which `flutter_test` records and hands back from `takeException()`; there is no
/// "did it overflow" property on the render objects, so this is the only way a
/// reader can ask the question. `login_text_scale_test.dart` says the same and
/// carries the negative control that proves it — a column built to overflow at this
/// scale returns a non-null exception.
///
/// ## AND THE ANTI-VACUITY HALF IS "THE PANEL IS ON SCREEN"
///
/// `takeException()` returning null also covers a screen that rendered nothing at
/// all, which would make every assertion in this file pass for the wrong reason. So
/// the helper additionally insists the panel is present — and **not** that a
/// `RenderFlex` is, because the loading state has none: it is a `SizedBox` around a
/// `CircularProgressIndicator`. The panel is the thing every one of these states
/// shares, and a screen without it is not the screen under test.
void _expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(
    find.byType(GlassSurface),
    findsWidgets,
    reason:
        'the panel did not render, so "no overflow" is vacuous: a screen that '
        'drew nothing cannot overflow',
  );
}
