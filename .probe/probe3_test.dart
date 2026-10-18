import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/reading_harness.dart';

void main() {
  testWidgets('probe cta box', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    await pumpReading(tester, cubit: h.cubit, size: const Size(430, 932));

    final Finder cta = find.byType(ReadingQuizCta);
    debugPrint('cta rect ${tester.getRect(cta)}');
    for (final Row r in tester.widgetList<Row>(
      find.descendant(of: cta, matching: find.byType(Row)),
    )) {
      debugPrint('row rect ${tester.getRect(find.byWidget(r))} alignment ${r.mainAxisAlignment}');
    }
    for (final Container c in tester.widgetList<Container>(
      find.descendant(of: cta, matching: find.byType(Container)),
    )) {
      debugPrint('container rect ${tester.getRect(find.byWidget(c))} width constraint');
    }
    debugPrint('caption ${tester.getRect(find.text('quiz · 1 questions'))}');
    debugPrint('caret ${tester.getRect(find.text('▸'))}');
    // The page Column's cross axis alignment.
    final Iterable<Column> columns = tester.widgetList<Column>(
      find.descendant(of: find.byType(ReadingPill), matching: find.byType(Column)),
    );
    debugPrint('pill columns ${columns.length}');
    for (final Column c in columns) {
      debugPrint('  cross ${c.crossAxisAlignment} rect ${tester.getRect(find.byWidget(c))}');
    }
  });
}