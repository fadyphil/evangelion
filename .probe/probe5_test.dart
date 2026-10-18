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

void main() {
  for (final (String label, Locale locale, ScriptureText passage)
      in <(String, Locale, ScriptureText)>[
        ('en', Locale('en'), liveEnglishPassage),
        ('ar', Locale('ar'), liveArabicPassage),
      ]) {
    testWidgets('scale probe $label', (WidgetTester tester) async {
      final ReadingHarness h = readingHarness(
        scripture: Result<ScriptureText>.of(passage),
      );
      await pumpReading(
        tester,
        cubit: h.cubit,
        locale: locale,
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
      );
      debugPrint('== $label ==');
      final List<Object> overflows = drainOverflowErrors(tester);
      debugPrint('overflows ${overflows.map((Object o) => o.runtimeType).toList()}');
      if (overflows.isNotEmpty) {
        debugPrint('  first: ${overflows.first}');
      }
      debugPrint('appbar ${tester.getRect(find.byType(ReadingAppBar))}');
      debugPrint('pill ${tester.getRect(find.byType(ReadingPill))}');
      debugPrint('cta ${tester.getRect(find.byType(ReadingQuizCta))}');
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        debugPrint(
          '  TEXT "${t.data}" size ${t.style?.fontSize} maxLines ${t.maxLines} overflow ${t.overflow} rect ${tester.getRect(find.text(t.data!).first).toString()}',
        );
      }
    });
  }
}