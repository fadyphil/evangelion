import 'package:evangelion/core/design_system/effects/ritual_haptics.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The platform calls the helper made.
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
  });

  /// Records the platform's haptic calls for the duration of one test.
  void recordPlatformCalls(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
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

  testWidgets('a tick reaches the platform as a selection click', (
    WidgetTester tester,
  ) async {
    recordPlatformCalls(tester);

    fireRitualHaptic(RitualHaptic.dockTap, enabled: true);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  testWidgets('a light bump is a light impact', (WidgetTester tester) async {
    recordPlatformCalls(tester);

    fireRitualHaptic(RitualHaptic.selahStarted, enabled: true);
    await tester.pump();

    expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
  });

  testWidgets('a medium bump is a medium impact', (WidgetTester tester) async {
    recordPlatformCalls(tester);

    fireRitualHaptic(RitualHaptic.answerCorrect, enabled: true);
    await tester.pump();

    expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  testWidgets('a three-part rhythm is a heavy impact', (
    WidgetTester tester,
  ) async {
    recordPlatformCalls(tester);

    fireRitualHaptic(RitualHaptic.selahCompleted, enabled: true);
    await tester.pump();

    expect(calls.single.arguments, 'HapticFeedbackType.heavyImpact');
  });

  testWidgets('nothing reaches the platform when haptics are off', (
    WidgetTester tester,
  ) async {
    recordPlatformCalls(tester);

    fireRitualHaptic(RitualHaptic.dockTap, enabled: false);
    fireRitualHaptic(RitualHaptic.selahCompleted, enabled: false);
    await tester.pump();

    expect(calls, isEmpty);
  });
}
