import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';
import '../../../../support/settings_harness.dart';

/// `/reading`'s own haptics — the bookmark and the `Aa` stepper.
///
/// `eva/redesign.html:1394` (the bookmark) and `:1396-1397` (the `Aa` buttons).
void main() {
  /// The platform's haptic calls.
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
  });

  /// Records the platform's haptic calls for the duration of one test.
  void recordPlatformCalls(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        // **Only the haptics.** The platform channel also carries the app's
        // own `SystemChrome` calls, and a recorder that kept those would be
        // counting the framework's housekeeping rather than the ritual's.
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
  }

  /// Mounts the sanctuary over the reader's own preferences.
  Future<void> pumpSanctuary(
    WidgetTester tester, {
    UserSettings? settings,
  }) async {
    settingsHarness(initial: settings);
    final ReadingHarness harness = readingHarness();
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        child: settingsScope(tester, ReadingPage(cubit: harness.cubit)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  /// The bookmark control.
  Finder bookmark() => find.bySemanticsLabel('Bookmark');

  group('the bookmark', () {
    testWidgets('it answers with the prototype\'s tick', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSanctuary(tester);

      await tester.tap(bookmark());
      await tester.pump();

      // `eva/redesign.html:1394` — `haptic(12)`, which is a **tick** and not
      // a bump.
      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
      handle.dispose();
    });

    testWidgets('and it is silent when the reader has asked for silence', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSanctuary(tester, settings: const UserSettings(haptics: false));

      await tester.tap(bookmark());
      await tester.pump();

      expect(calls, isEmpty);
      handle.dispose();
    });
  });

  group('the Aa stepper', () {
    testWidgets('it answers with the prototype\'s tick', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSanctuary(tester);

      // `eva/redesign.html:1396` — `el('fPlus').onclick=()=>{…;haptic(10)}`.
      await tester.tap(find.bySemanticsLabel('Increase font size'));
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
      handle.dispose();
    });
  });
}
