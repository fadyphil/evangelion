import 'package:evangelion/app/sky_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/design_system_harness.dart';
import '../test/support/reading_harness.dart';
import '../test/support/settings_harness.dart';

void main() {
  testWidgets('focus dim', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    await pumpReading(tester, cubit: h.cubit, frames: 2);
    debugPrint(
      'animatedopacity count ${find.byType(AnimatedOpacity).evaluate().length}',
    );
    for (final AnimatedOpacity o in tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    )) {
      debugPrint('  ${o.opacity} ${o.duration} ${o.curve}');
    }
    await tester.pump(focusIdleDelay + const Duration(milliseconds: 1200));
    for (final AnimatedOpacity o in tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    )) {
      debugPrint('after idle: ${o.opacity}');
    }
    debugPrint('cta present ${find.byType(ReadingQuizCta).evaluate().length}');
    debugPrint('pill present ${find.byType(ReadingPill).evaluate().length}');
    debugPrint('verse paints ${tester.widgetList<VerseLine>(find.byType(VerseLine)).map((VerseLine v) => v.paint).toList()}');
    // A press restores the chrome.
    await tester.tapAt(const Offset(215, 400));
    await tester.pump(const Duration(milliseconds: 100));
    for (final AnimatedOpacity o in tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    )) {
      debugPrint('after press: ${o.opacity}');
    }
  });

  testWidgets('sky', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    final List<SkyEntry> recorded = <SkyEntry>[];
    final SkyHandle sky = SkyHandle(
      entriesReader: () => recorded,
      recordEntry: (SkyEntry e) async => recorded.add(e),
    );
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        child: settingsScope(
          tester,
          SkyScope(handle: sky, child: ReadingPage(cubit: h.cubit)),
        ),
      ),
    );
    await pumpReadingFrames(tester, 6);
    debugPrint('stars before scroll ${recorded.length}');
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await pumpReadingFrames(tester, 4);
    debugPrint('stars after scroll ${recorded.length} -> ${recorded.map((SkyEntry e) => '${e.book}:${e.chapter}:${e.verse}').toList()}');
    debugPrint('crumb ${tester.widgetList<Text>(find.byType(Text)).map((Text t) => t.data).toList()}');
    await tester.pump(focusIdleDelay + const Duration(milliseconds: 100));
  });
}