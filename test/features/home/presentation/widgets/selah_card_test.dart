import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/selah_countdown.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// The selah card — the minute of silence, and the control that starts it.
///
/// `eva/redesign.html:530-533` (the card), `:1330-1342` (the timer).
void main() {
  /// The scene the card dims, captured during a build.
  ///
  /// **A capture and not a lookup in the test body**, because
  /// `NeuralMotionScope.of` is a *dependent* lookup and Flutter refuses one
  /// outside a build.
  LumenScene? scene;

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

  /// Mounts the card and captures the scene.
  Future<void> pumpCard(
    WidgetTester tester, {
    int seconds = 60,
    bool hapticsEnabled = true,
    bool disableAnimations = false,
    VoidCallback? onCompleted,
  }) async {
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        disableAnimations: disableAnimations,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        child: Builder(
          builder: (BuildContext context) {
            scene = NeuralMotionScope.of(context).lumenScene;
            return SelahCard(
              seconds: seconds,
              beginLabel: 'Begin the selah',
              endLabel: 'End the selah',
              amenLabel: 'selah · amen',
              hapticsEnabled: hapticsEnabled,
              onCompleted: onCompleted,
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  /// The card's control.
  Finder circle() => find.descendant(
    of: find.byType(SelahCard),
    matching: find.byType(FourPointedStar),
  );

  group('the countdown', () {
    testWidgets('the count is not drawn until the silence begins', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      expect(find.text('60'), findsNothing);
    });

    testWidgets('pressing the circle shows the full silence', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);

      await tester.tap(circle());
      await tester.pump();

      // `:532` — the count is painted the moment the silence starts, and it
      // starts at the **whole** duration, not at one less.
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets('and it counts down one second at a time', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(circle());
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('59'), findsOneWidget);
      expect(find.text('60'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('58'), findsOneWidget);
    });

    testWidgets('the reader\'s own length is the one counted', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 30);
      await tester.tap(circle());
      await tester.pump();

      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('a second press ends the silence', (WidgetTester tester) async {
      await pumpCard(tester);
      await tester.tap(circle());
      await tester.pump();
      expect(find.text('60'), findsOneWidget);

      await tester.tap(circle());
      await tester.pump();

      expect(find.text('60'), findsNothing);
      // **And the count stops where it was** — the silence ended, and the
      // card is at rest.
      expect(find.text('59'), findsNothing);
    });
  });

  group('the timer does not leak', () {
    testWidgets('leaving the tree cancels the countdown', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(circle());
      await tester.pump();

      // The card leaves the tree with its countdown running. **A pending timer
      // fails a `flutter_test` case**, so this test is red if `dispose` does
      // not cancel it — and the repo has a recorded instance of a
      // never-completing future hanging a suite.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('and the amen\'s own timer is cancelled too', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 1);
      await tester.tap(circle());
      await tester.pump();
      // One second later the silence ends and the amen's 1800ms timer starts.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('selah · amen'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('the amen', () {
    testWidgets('it is shown when the silence runs its course', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 2);
      await tester.tap(circle());
      await tester.pump();

      await tester.pump(const Duration(seconds: 2));

      expect(find.text('selah · amen'), findsOneWidget);
      // **And the count is gone** — the message took its place.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('it lasts the prototype\'s 1800ms', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 1);
      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('selah · amen'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('selah · amen'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('selah · amen'), findsNothing);
    });

    testWidgets('a silence stopped early says nothing', (
      WidgetTester tester,
    ) async {
      bool completed = false;
      await pumpCard(tester, onCompleted: () => completed = true);
      await tester.tap(circle());
      await tester.pump();

      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('selah · amen'), findsNothing);
      expect(completed, isFalse);
    });
  });

  group('the haptics', () {
    testWidgets('the silence starts with the prototype\'s tick', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      await pumpCard(tester);

      await tester.tap(circle());
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    testWidgets('and it ends with the prototype\'s rhythm', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      await pumpCard(tester, seconds: 1);

      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(calls, hasLength(2));
      expect(calls.last.arguments, 'HapticFeedbackType.heavyImpact');
    });

    testWidgets('nothing reaches the platform when haptics are off', (
      WidgetTester tester,
    ) async {
      recordPlatformCalls(tester);
      await pumpCard(tester, hapticsEnabled: false, seconds: 1);

      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(calls, isEmpty);
    });
  });

  group('the focus dim', () {
    testWidgets('the silence dims the app, and the silence\'s end undims it', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 1);
      expect(scene!.focusDimmed, isFalse);

      await tester.tap(circle());
      await tester.pump();
      expect(scene!.focusDimmed, isTrue);

      // **A second later the silence is over** — and the dim goes with it.
      await tester.pump(const Duration(seconds: 1));
      expect(scene!.focusDimmed, isFalse);
    });

    testWidgets('a silence stopped early undims it too', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(circle());
      await tester.pump();
      expect(scene!.focusDimmed, isTrue);

      await tester.tap(circle());
      await tester.pump();
      expect(scene!.focusDimmed, isFalse);
    });

    testWidgets('and leaving the tree gives the dim back', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(circle());
      await tester.pump();
      expect(scene!.focusDimmed, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(scene!.focusDimmed, isFalse);
    });
  });

  group('the card\'s own numbers', () {
    test('the silence\'s default length is the prototype\'s 60', () {
      expect(SelahCard.defaultSeconds, 60);
      expect(kSelahDefaultSeconds, 60);
    });

    test('the ring breathes on the prototype\'s two periods', () {
      expect(kSelahRingPeriod, const Duration(seconds: 8));
      expect(kSelahActiveRingPeriod, const Duration(seconds: 2));
    });

    test('the count is drawn at the prototype\'s 16px', () {
      expect(kSelahCountSize, 16);
    });
  });
}
