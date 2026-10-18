import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';

/// §14's 1.22× text scale, on the redesigned `/reading`.
///
/// ## THE THREE FIXED BOXES, AND THE ONE THAT CHANGED NAME
///
/// The old screen's fixed boxes were the header, the controls row and the CTA.
/// The redesign keeps a CTA (`.qcta`, `:202`) and a pill (`.pill`, `:192`), and
/// adds a **title row whose width is capped** (`:144`'s `max-width: 52%`) — the
/// title ellipsises, which is the row's own behaviour rather than the suite's
/// tolerance. The verses scale with the step and wrap; the chrome does not.
///
/// ## AND THE ENTRANCE IS OFF, IN EVERY ROW
///
/// A verse that has not revealed paints at `Opacity(0)` and a `find` still sees
/// it — but its layout is the *final* layout, so the overflow question is answer-
/// able either way. The stagger is switched off anyway, because a suite that
/// races a reveal is asserting on whichever frame the pump landed on.
void main() {
  const double scale = 1.22;

  group('the ready arm', () {
    for (final Size surface in <Size>[kNarrowSurface, kAmbientSurface]) {
      testWidgets(
        'nothing overflows at ${surface.width.toInt()}×${surface.height.toInt()}',
        (WidgetTester tester) async {
          final ReadingHarness h = readingHarness();
          await pumpReading(
            tester,
            cubit: h.cubit,
            size: surface,
            textScale: scale,
            disableAnimations: true,
          );

          // `somethingRendered` is the app bar — present in every arm, so the
          // helper's own check is not vacuous.
          expectNoOverflow(
            tester,
            somethingRendered: () =>
                find.byType(ReadingAppBar).evaluate().isNotEmpty,
            surface: '${surface.width.toInt()}×${surface.height.toInt()}',
          );
        },
      );
    }

    testWidgets('and the two fixed boxes hold their shape at 1.22×', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: kNarrowSurface,
        textScale: scale,
        disableAnimations: true,
      );

      // The CTA is one line under a `maxLines: 1` ellipsis; the pill's three
      // groups fit because the two `flex:1` spacers give them the middle.
      final Rect cta = tester.getRect(find.byType(ReadingQuizCta));
      expect(cta.width, kNarrowSurface.width);
      final Rect pill = tester.getRect(find.byType(ReadingPill));
      expect(pill.width, kNarrowSurface.width);
    });

    testWidgets('the title ellipsises rather than overflowing', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: kNarrowSurface,
        textScale: scale,
        disableAnimations: true,
      );

      // `:144` — `max-width: 52%; overflow: hidden; text-overflow: ellipsis`.
      // The title is bounded by the row's own rule, so a long reference cannot
      // push the row taller: the bar's height is the same at 1.0× and 1.22×.
      final Rect bar = tester.getRect(find.byType(ReadingAppBar));
      expect(
        bar.height,
        lessThan(ReadingAppBar.rowMinHeight * 3),
        reason:
            'a capped, ellipsising title cannot grow the bar; the whole '
            'two-row header is a fixed shape',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the failed arm', () {
    testWidgets('nothing overflows, and the message ellipsises', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Left<Failure, ScriptureText>(readingFailure),
      );
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: kNarrowSurface,
        textScale: scale,
        disableAnimations: true,
      );

      expectNoOverflow(
        tester,
        somethingRendered: () => find.byType(ErrorView).evaluate().isNotEmpty,
        surface: 'failed, 1.22×',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the verses themselves', () {
    testWidgets('wrap rather than overflow, and every line stays inside', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: kNarrowSurface,
        textScale: scale,
        disableAnimations: true,
      );

      final AppLocalizations en = AppLocalizationsEn();
      final List<VerseLine> lines = tester
          .widgetList<VerseLine>(find.byType(VerseLine))
          .toList();
      expect(lines, isNotEmpty);
      for (final VerseLine line in lines) {
        final Rect rect = tester.getRect(find.byWidget(line));
        expect(
          rect.right,
          lessThanOrEqualTo(kNarrowSurface.width),
          reason:
              '`${en.readingVerse} ${line.number}` wraps inside the 26px '
              'insets rather than crossing them',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
