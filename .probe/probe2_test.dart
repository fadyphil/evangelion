import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/reading_harness.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';

void main() {
  testWidgets('probe internals', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    await pumpReading(tester, cubit: h.cubit);

    final Finder appBar = find.byType(ReadingAppBar);
    final List<Widget> stackChildren = <Widget>[];
    for (final Text t in tester.widgetList<Text>(
      find.descendant(of: appBar, matching: find.byType(Text)),
    )) {
      stackChildren.add(t);
    }
    debugPrint('appbar texts ${stackChildren.map((Widget w) => (w as Text).data).toList()}');
    debugPrint('title rect ${tester.getRect(find.text('John 3:1-5'))}');
    debugPrint('chev rect ${tester.getRect(find.text('‹'))}');
    debugPrint('meta rect ${tester.getRect(find.text('43 · 5 verses · sky 0'))}');
    debugPrint('stack rect ${tester.getRect(find.descendant(of: appBar, matching: find.byType(Stack)))}');
    debugPrint('constrained rects');
    for (final ConstrainedBox c in tester.widgetList<ConstrainedBox>(
      find.descendant(of: appBar, matching: find.byType(ConstrainedBox)),
    )) {
      debugPrint('  ${c.constraints}  rect ${tester.getRect(find.byWidget(c))}');
    }
    debugPrint('--- pill ---');
    final Finder pill = find.byType(ReadingPill);
    debugPrint('minus rect ${tester.getRect(find.text('A−'))}');
    debugPrint('plus rect ${tester.getRect(find.text('A+'))}');
    debugPrint('listen rect ${tester.getRect(find.text('listen'))}');
    debugPrint('EN rect ${tester.getRect(find.text('EN'))}');
    for (final SegmentedControl<Object?> s in tester.widgetList<SegmentedControl<Object?>>(find.byType(SegmentedControl<Object?>))) {
      debugPrint('seg rect ${tester.getRect(find.byWidget(s))}');
    }
    debugPrint('segp count ${find.byType(SegmentedControl<ReadingLanguage>).evaluate().length}');
    for (final Container c in tester.widgetList<Container>(
      find.descendant(of: pill, matching: find.byType(Container)),
    )) {
      final BoxDecoration? d = c.decoration as BoxDecoration?;
      debugPrint(
        '  container rect ${tester.getRect(find.byWidget(c))} pad ${c.padding} radius ${d?.borderRadius} colour ${d?.color}',
      );
    }
    debugPrint('--- cta ---');
    final Finder cta = find.byType(ReadingQuizCta);
    for (final Container c in tester.widgetList<Container>(
      find.descendant(of: cta, matching: find.byType(Container)),
    )) {
      final BoxDecoration? d = c.decoration as BoxDecoration?;
      debugPrint(
        '  cta container rect ${tester.getRect(find.byWidget(c))} pad ${c.padding} radius ${d?.borderRadius} colour ${d?.color} border ${d?.border}',
      );
    }
    debugPrint('caption rect ${tester.getRect(find.text('quiz · 1 questions'))}');
    debugPrint('caret rect ${tester.getRect(find.text('▸'))}');
    debugPrint('--- stars ---');
    debugPrint('FourPointedStar count ${find.byType(FourPointedStar).evaluate().length}');
    for (final FourPointedStar s in tester.widgetList<FourPointedStar>(find.byType(FourPointedStar))) {
      debugPrint('  star size ${s.size} rect ${tester.getRect(find.byWidget(s))}');
    }
    debugPrint('--- verse text runs ---');
    final Iterable<RichText> rich = tester.widgetList<RichText>(
      find.descendant(of: find.byType(RichText), matching: find.byType(RichText)),
    );
    debugPrint('rich count ${rich.length}');
  });
}