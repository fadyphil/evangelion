import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../test/support/design_system_harness.dart';
import '../test/support/reading_harness.dart';
import '../test/support/settings_harness.dart';

void main() {
  for (final (String label, Locale locale, ScriptureText passage)
      in <(String, Locale, ScriptureText)>[
        ('en', Locale('en'), liveEnglishPassage),
        ('ar', Locale('ar'), liveArabicPassage),
      ]) {
    for (final (String mode, int step) in <(String, int)>[
      ('step3', 3),
      ('step5', 5),
    ]) {
      testWidgets('scale probe $label $mode', (WidgetTester tester) async {
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.of(passage),
        );
        await pumpReading(
          tester,
          cubit: h.cubit,
          locale: locale,
          size: kNarrowSurface,
        );
        await settingsHandleOf(tester).setFontStep(step);
        await pumpReadingFrames(tester, 4);
        debugPrint('== $label $mode ==');
        debugPrint(
          'installed scale ${MediaQuery.textScalerOf(tester.element(find.byType(ReadingPill))).scale(1)}',
        );
        final List<Object> overflows = drainOverflowErrors(tester);
        debugPrint(
          'overflows ${overflows.map((Object o) => '$o'.split('\n').first).toList()}',
        );
        for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
          debugPrint(
            '  "${t.data}" ${tester.getRect(find.text(t.data!).first).toString()}',
          );
        }
        debugPrint('appbar ${tester.getRect(find.byType(ReadingAppBar))}');
      });
    }
  }
}