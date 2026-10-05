import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/reading_harness.dart';

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the CTA reaches the quiz, by a **push**', () {
    testWidgets('tapping it lands on `/quiz`', (WidgetTester tester) async {
      final ({AppRouter router, ReadingHarness harness}) mounted =
          await mountReadingOver(tester);

      await tester.tap(find.byType(StickyCta));
      await pumpUntilFound(tester, find.byType(QuizPage));

      expect(mounted.router.currentPath, AppRoutes.quiz);
      expect(find.byType(QuizPage), findsOneWidget);
    });

    testWidgets('and leaves `/reading` **underneath** rather than over it', (
      WidgetTester tester,
    ) async {
      // The push/replace distinction, asserted as the thing a reader performs:
      // the system back gesture after Begin reflection has to return to the
      // sanctuary. `currentPath` alone cannot see this — a `replacePath` lands on
      // exactly the same path.
      final ({AppRouter router, ReadingHarness harness}) mounted =
          await mountReadingOver(tester);
      final int before = mounted.router.stack.length;

      await tester.tap(find.byType(StickyCta));
      await pumpUntilFound(tester, find.byType(QuizPage));
      expect(mounted.router.stack.length, before + 1);

      mounted.router.pop();
      await pumpUntilFound(tester, find.byType(ReadingPage));
      expect(
        mounted.router.currentPath,
        AppRoutes.reading,
        reason:
            'a `push` leaves the sanctuary on the stack; a `replace` would have '
            'removed it and the reader would be stuck on the quiz',
      );
    });
  });

  group('the back control pops', () {
    testWidgets('tapping it returns to the route below', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, ReadingHarness harness}) mounted =
          await mountReadingOver(tester);
      // Asserted here rather than in each suite: "we really were on `/reading`" is
      // the premise of the tap, and a suite that popped off some other route would
      // still pass every assertion below it.
      expect(mounted.router.currentPath, AppRoutes.reading);
      final int before = mounted.router.stack.length;

      await tester.tap(find.byIcon(Icons.arrow_back));
      await pumpUntilFound(tester, find.byType(HomePage));

      expect(mounted.router.currentPath, AppRoutes.home);
      expect(
        mounted.router.stack.length,
        before - 1,
        reason: '`maybePop` removes one route; it does not replace the stack',
      );
    });

    testWidgets('and the pop is a **pop**, not a jump home', (
      WidgetTester tester,
    ) async {
      // The other direction, and the reason the stack length is asserted above: a
      // back control wired to `pushPath(home)` would leave `/reading` on the stack
      // forever, so the reader could never move forward again. Asserted as the
      // stack, which is the only thing that can tell the two apart.
      final ({AppRouter router, ReadingHarness harness}) mounted =
          await mountReadingOver(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await pumpUntilFound(tester, find.byType(HomePage));

      expect(
        mounted.router.stack.length,
        1,
        reason: '`/` alone, and nothing else',
      );
    });
  });

  group('the Arabic arm navigates under its OWN label', () {
    testWidgets('the localized CTA is the one that reaches `/quiz`', (
      WidgetTester tester,
    ) async {
      // `home_navigation_test.dart` states why the labels are looked up through the
      // string table rather than written out: a hard-coded `find.text('Begin
      // reflection')` finds nothing under `ar`, and the failure reads as "the page
      // did not render" instead of "the string is localized".
      final ({AppRouter router, ReadingHarness harness}) mounted =
          await mountReadingOver(
            tester,
            locale: const Locale('ar'),
            scripture: const Result<ScriptureText>.success(liveArabicPassage),
          );

      await tester.tap(find.text(AppLocalizationsAr().readingBeginReflection));
      await pumpUntilFound(tester, find.byType(QuizPage));

      expect(mounted.router.currentPath, AppRoutes.quiz);
    });
  });
}

/// `/reading`, pushed over `/`, with a **live passage** behind it.
///
/// ## WHY THE CUBIT IS REGISTERED BEFORE [routerHost]
///
/// `routerHost` registers a `ReadingCubit` *only if the locator has none*, and the
/// one it registers answers every request with a `Failure` — `app_harness.dart`
/// says why: no sockets in a router suite. A failed reading renders `ErrorView`,
/// which has **no CTA and no passage**, so both taps would find nothing and every
/// assertion below would be about a screen that was never on screen. This is the
/// seam `registerTestReadingCubit` documents, used from the other side, and it is
/// the same move `home_navigation_test.dart`'s `mountHomeWithAReading` makes for
/// `HomeBloc`.
///
/// ## AND WHY `/` IS THE ROUTE BELOW
///
/// `maybePop` pops to whatever is underneath, so "back is wired" is only a claim
/// when there is something underneath. `/` is where the reader came from — the
/// panel's `Continue` pushes this screen — and it is also the route a **replace**
/// of the CTA would strand the reader away from.
Future<({AppRouter router, ReadingHarness harness})> mountReadingOver(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Result<ScriptureText>? scripture,
}) async {
  final ReadingHarness h = readingHarness(
    scripture:
        scripture ?? const Result<ScriptureText>.success(liveEnglishPassage),
  );
  // **Not** `routerHost`'s `registerTestReadingCubit`, for the reason above. The
  // teardown is registered by `readingHarness` for the cubit itself; this unregisters
  // it from the locator so the next test starts from the state `setUp` expects.
  getIt.registerSingleton<ReadingCubit>(h.cubit);
  addTearDown(() => getIt.unregister<ReadingCubit>());

  final AppRouter router = AppRouter(FakeAuthStatus(), _SilentAuthChanges());
  addTearDown(router.dispose);

  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(routerHost(router, locale: locale));
  await pumpUntilFound(tester, find.byType(HomePage));

  // The same route the panel's `Continue` pushes, so the premise is the real
  // journey rather than a direct deep link.
  //
  // **Not awaited.** `pushPath` returns a `Future` that completes when the route is
  // **popped** — the pushed route's own result — so awaiting it here waits for a
  // reader to leave, which is a three-minute hang rather than a failure. Measured:
  // the `await` cost 195 seconds and the unawaited call costs nothing.
  unawaited(router.pushPath(AppRoutes.reading));
  await pumpUntilFound(tester, find.byType(ReadingPage));
  // …and the passage, because `ReadingPage`'s `load` is asynchronous and the CTA
  // only exists once `state.scripture` is non-null.
  await pumpUntilFound(tester, find.byType(StickyCta));

  expect(router.currentPath, AppRoutes.reading);

  return (router: router, harness: h);
}

/// A [ReevaluateListenable] that never notifies.
///
/// The second declaration of `home_navigation_test.dart`'s private copy, and it is
/// **deliberately** a second one: that file's doc gives the argument — a suite that
/// cannot build its own subject cannot test it.
final class _SilentAuthChanges extends ReevaluateListenable {}
