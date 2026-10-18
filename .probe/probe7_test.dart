import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/common/result.dart' as r2;
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../test/support/design_system_harness.dart';
import '../test/support/reading_harness.dart';

void main() {
  testWidgets('blank opening verse', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness(
      scripture: r2.Result<ScriptureText>.of(
        liveEnglishPassage.copyWith(
          verses: <Verse>[
            liveEnglishPassageVerses.first.copyWith(text: '   '),
            ...liveEnglishPassageVerses.skip(1),
          ],
        ),
      ),
    );
    await pumpReading(tester, cubit: h.cubit);
    debugPrint('exception ${tester.takeException()}');
    debugPrint('dropcap letters ${dropCapLetters(tester).map((String s) => s.codeUnits.toString()).toList()}');

    final ReadingHarness empty = readingHarness(
      scripture: r2.Result<ScriptureText>.of(
        liveEnglishPassage.copyWith(
          verses: <Verse>[
            liveEnglishPassageVerses.first.copyWith(text: ''),
            ...liveEnglishPassageVerses.skip(1),
          ],
        ),
      ),
    );
    await pumpReading(tester, cubit: empty.cubit);
    debugPrint('empty letters ${dropCapLetters(tester).map((String s) => s.codeUnits.toString()).toList()}');
  });

  testWidgets('bookmark and listen', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    await pumpReading(tester, cubit: h.cubit);
    final FourPointedStar before = tester.widget<FourPointedStar>(
      find.byType(FourPointedStar),
    );
    debugPrint('star colour before ${before.color}');
    await tester.tap(find.byType(FourPointedStar));
    await pumpReadingFrames(tester, 4);
    debugPrint(
      'star colour after ${tester.widget<FourPointedStar>(find.byType(FourPointedStar)).color}',
    );
    // Tap the verse: does `hot` reach the paint?
    await tester.tap(find.byType(VerseLine).first);
    await pumpReadingFrames(tester, 4);
    debugPrint(
      'paints ${tester.widgetList<VerseLine>(find.byType(VerseLine)).map((VerseLine v) => v.paint).toList()}',
    );

    // Pill row children.
    final Row pillRow = tester.widget<Row>(
      find.descendant(of: find.byType(ReadingPill), matching: find.byType(Row)).first,
    );
    debugPrint('pill row children ${pillRow.children.length} ${pillRow.children.map((Widget w) => w.runtimeType.toString()).toList()}');
    for (final SemanticsData node in semanticsTree(tester)) {
      debugPrint('SEM ${node.label} hasTap=${node.hasAction(SemanticsAction.tap)}');
    }
    // Tap listen: nothing should happen.
    await tester.tap(find.text('listen'));
    await pumpReadingFrames(tester, 4);
    debugPrint('after listen tap exception ${tester.takeException()}');
  });

  testWidgets('cta gate at zero questions', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness(
      scripture: const Right<Failure, ScriptureText>(liveEnglishPassage),
    );
    await pumpReading(tester, cubit: h.cubit);
    debugPrint('cta count ${find.byType(ReadingQuizCta).evaluate().length}');
    final ReadingHarness zero = readingHarness(
      scripture: r2.Result<ScriptureText>.of(
        liveEnglishPassage.copyWith(questions: const <Question>[]),
      ),
    );
    await pumpReading(tester, cubit: zero.cubit);
    debugPrint('zero cta count ${find.byType(ReadingQuizCta).evaluate().length}');
    debugPrint('zero pill ${find.byType(ReadingPill).evaluate().length}');
  });
}