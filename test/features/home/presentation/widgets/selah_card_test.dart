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

    testWidgets('and the silence ending leaves no timer behind either', (
      WidgetTester tester,
    ) async {
      // **The card's timer is cancelled the moment the silence ends** — the
      // `_complete` path — so a card that is still on screen when the silence
      // runs out is not still counting. That is a **different** path from the
      // disposal above, and it is the one a reader reaches: they sit on `/`
      // after the silence and the card is still there.
      //
      // **The amen's own clock is the PAGE's** — the home page owns the toast
      // (`:1330`'s `toast(tr('amen'))`, anchored to the screen root), and
      // `home_page_test.dart`'s selah-toast group is where that timer is
      // asserted. The card has no clock of its own to leak.
      await pumpCard(tester, seconds: 1);
      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Five seconds later, nothing on the card has moved.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('60'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('the amen', () {
    // ## THE CARD DOES **NOT** DRAW IT, AND THE PAGE **DOES**
    //
    // The prototype raises the amen as a **toast** (`:1330`'s
    // `toast(tr('amen'))`), anchored to the screen root (`:466`). This card
    // used to draw it **in the count's corner** and record the divergence, on
    // the grounds that "this client has no app-level toast surface: the
    // communion page builds its own, and `/` has none".
    //
    // **That reason has stopped being true**: the toast is a shared
    // design-system widget and the home page owns it. So the card's whole
    // half of the amen is [SelahCard.onCompleted] — the moment the silence ran
    // its course — and the message is the page's.
    testWidgets('the card draws no message of its own', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 1);
      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // **The regression guard on the recorded divergence.** A card that drew
      // the amen again would put the message in a second place, and the second
      // place is where the divergence was recorded before.
      expect(find.text('selah · amen'), findsNothing);
    });

    testWidgets('and it tells the page when the silence runs its course', (
      WidgetTester tester,
    ) async {
      bool completed = false;
      await pumpCard(tester, seconds: 1, onCompleted: () => completed = true);
      await tester.tap(circle());
      await tester.pump();

      expect(completed, isFalse);

      await tester.pump(const Duration(seconds: 1));

      expect(completed, isTrue);
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

  group('the aurora', () {
    // ## THE PROTOTYPE'S **SPIKE** IS PORTED, AND THE **FLARE** IS NOT
    //
    // `:1330` — `if(done){ toast(tr('amen')); addStar(true); if(V)V.spike=.5;
    // haptic([30,40,30]); }`
    //
    // `V.spike=.5` is the aurora's kick, and this client has the mechanism —
    // `LumenScene.raiseSpike` — so the selah raises it, by the prototype's own
    // number.
    //
    // `addStar(true)` is the **flare** into the witness sky, and it is **not**
    // ported: the client's sky is keyed `book:chapter:verse` and a selah lights
    // no verse. `SelahCard`'s class doc carries the whole account.
    testWidgets('the silence ending raises the prototype\'s spike', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, seconds: 1);
      expect(scene!.spike, 0);

      await tester.tap(circle());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(scene!.spike, kSelahCompletionSpike);
      expect(kSelahCompletionSpike, 0.5, reason: '`:1330` — if(V)V.spike=.5;');
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
