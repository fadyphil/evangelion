import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/settings_harness.dart';

/// The Workshop's own haptics — the ritual's master switch and the one
/// beside it.
///
/// `eva/redesign.html:1482` (the daylight switch) and `:1498` (the haptics
/// switch itself).
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

  /// The switch named [label].
  Finder toggleNamed(String label) => find.bySemanticsLabel(label);

  /// Scrolls the switch named [label] into view and taps it.
  ///
  /// **The scroll is not decoration**: the Workshop's ritual group is the
  /// fifth one, and on the narrow surface its switch is more than two
  /// thousand pixels down — so a tap that did not scroll would land on
  /// nothing and the assertion would be about a control that was never
  /// pressed.
  Future<void> tapToggle(WidgetTester tester, String label) async {
    final Finder target = toggleNamed(label);
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
  }

  group('the haptics switch', () {
    testWidgets('turning it ON answers with the prototype\'s tick', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      // `eva/redesign.html:1498` — `el('setHap').onchange=e=>{ HAPTICS=
      // e.target.checked; if(HAPTICS)haptic(15); }`.
      //
      // **The switch starts ON** — the prototype's own `checked` — so the
      // first tap turns it **off**, and the prototype's `if` says the tick is
      // for the other direction.
      await tapToggle(tester, 'Haptics');
      expect(calls, isEmpty);

      await tapToggle(tester, 'Haptics');
      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
      handle.dispose();
    });

    testWidgets('and the reader\'s own switch is honoured', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, stored: const UserSettings(haptics: false));

      // **With haptics off, the switch that turns them on still answers with
      // one** — because the reader is asking for them at that moment, and the
      // prototype's own `if(HAPTICS)` is the *new* value, not the old one.
      //
      // Hmm — and this is a subtlety worth naming: the prototype's handler
      // sets `HAPTICS` **first** and then asks, so the tick is the answer to
      // the switch being **on**. A client that read the *old* value would stay
      // silent on the very tap that turns haptics on, which is the one moment
      // a reader most wants to know it worked.
      await tapToggle(tester, 'Haptics');
      expect(calls, hasLength(1));
      handle.dispose();
    });
  });

  group('the daylight switch', () {
    testWidgets('it answers with the prototype\'s tick', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      // `eva/redesign.html:1482` — `el('setDaylight').onchange=e=>{ …
      // if(V)V.spike=.4; haptic(15); }`.
      await tapToggle(tester, 'Daylight mode');

      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
      handle.dispose();
    });

    testWidgets('and it is silent when the reader has asked for silence', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, stored: const UserSettings(haptics: false));

      await tapToggle(tester, 'Daylight mode');

      expect(calls, isEmpty);
      handle.dispose();
    });
  });
}
