import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/reading_harness.dart';

/// The routes out of `/reading`, against the redesigned screen.
///
/// ## THE SCREEN HAS TWO WAYS OUT AND ONE WAY THAT IS NOT A ROUTE AT ALL
///
/// `eva/redesign.html:540-560` gives the reader a chevron that pops
/// (`data-back="home"`, `:542`), a CTA that opens the quiz (`:1404`), and a
/// language dial that **does not navigate** — its two `data-l` buttons re-issue
/// the screen's own load (`:1477-1480`) for the other arm. The old screen's panel
/// is gone, so there is no third route and no `Aa` disclosure to test.
///
/// Everything here asserts the **route name on the stack** and not the URL:
/// `router.stack` holds pages whose Dart type is the generic `AutoRoutePage`, and
/// the route's own name is what distinguishes them — the same reason
/// `home_navigation_test.dart` gives, and the same measured failure (`currentPath`
/// lags at the previous route until the transition settles).
void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  testWidgets('the CTA opens the quiz', (WidgetTester tester) async {
    final ({AppRouter router, ReadingHarness harness}) mounted =
        await mountReadingOver(tester);

    await tester.tap(find.byType(ReadingQuizCta));
    await pumpUntilFound(tester, find.byType(QuizPage));

    expect(
      mounted.router.stack.last.name,
      'QuizRoute',
      reason:
          'the quiz is on top of the stack — by the page\'s **name**, because '
          '`router.stack` is a list of pages and a generated page\'s type is the '
          'generic `AutoRoutePage` while its name is the route',
    );
  });

  testWidgets('the chevron pops back to `/`', (WidgetTester tester) async {
    final ({AppRouter router, ReadingHarness harness}) mounted =
        await mountReadingOver(tester);

    // **The chevron is the only `‹` on the screen** — `eva/redesign.html:542`
    // writes the character, and U+2039 is measured present in five bundled
    // families including the Inter face it inherits, so the glyph *is* the
    // finder. Its accessible name is `readingBack`, which
    // `reading_accessibility_test.dart` asserts; here the tap is the claim.
    await tester.tap(find.text('‹'));
    await pumpUntilFound(tester, find.byType(HomePage));

    expect(
      mounted.router.stack.last.name,
      'DockShellRoute',
      reason:
          'the reader is gone and `/` is on top — **and `/` is the dock shell '
          'now**, with the home tab inside it, so the stack names the shell',
    );
  });

  testWidgets('the language dial re-loads the OTHER arm and renders it', (
    WidgetTester tester,
  ) async {
    final ({AppRouter router, ReadingHarness harness}) mounted =
        await mountReadingOver(tester);
    expect(mounted.harness.readings.asked, <ReadingLanguage>[
      ReadingLanguage.english,
    ]);

    await tester.tap(find.text(ReadingPill.languageLabelArabic));
    await pumpUntilFound(tester, find.textContaining('كَانَ'));

    expect(
      mounted.harness.readings.asked,
      <ReadingLanguage>[ReadingLanguage.english, ReadingLanguage.arabic],
      reason:
          'the dial does not navigate — `:1477-1480` re-issues the screen\'s own '
          'load for the other arm, and the request log is the proof',
    );
    expect(
      mounted.router.stack.map((AutoRoutePage<Object?> p) => p.name).toList(),
      contains('ReadingRoute'),
      reason: 'and the screen is still the screen',
    );
  });

  // **The steppers are NOT here, on purpose.** `A+`/`A−` write through
  // `SettingsScope` to the *settings store*, which is a wiring claim and not a
  // navigation one — `app_settings_wiring_test.dart` owns it, with the handle it
  // registers and the subscription `app.dart` installs (its doc records the failed
  // rebuild that proved the subscription was load-bearing). This suite's
  // `routerHost` tree has no scope above the page, so a write here exercises the
  // locator fallback and proves nothing the wiring suite does not already prove
  // better.
  //
  // What IS this suite's: the dial. It re-issues the screen's own load, which is
  // the row above.

  testWidgets('the bookmark toggles and never navigates', (
    WidgetTester tester,
  ) async {
    final ({AppRouter router, ReadingHarness harness}) mounted =
        await mountReadingOver(tester);
    final int callsBefore = mounted.harness.readings.calls;

    // `eva/redesign.html:1394` — the toggle calls `haptic(12)` and a toast and
    // nothing else. There is no bookmark endpoint in §2's route table, so this
    // screen's bookmark is **local state**, and the row is where that gap is
    // recorded rather than papered over.
    //
    // **The star is the finder, and it is scoped to the reader**: `/` sits behind
    // the pushed route and its selah circle paints the same design-system star, so
    // an unscoped finder is ambiguous — measured, `FourPointedStar, FourPointedStar`
    // in this test's own failure. The glyph cannot be the finder anyway: U+2726 is
    // in no bundled family, so the button paints and there is no text to find.
    final Finder star = find
        .descendant(
          of: find.byType(ReadingPage),
          matching: find.byType(FourPointedStar),
        )
        .first;
    await tester.tap(star);
    await pumpReadingFrames(tester, 2);

    expect(
      mounted.harness.readings.calls,
      callsBefore,
      reason: 'toggling the bookmark issues no request',
    );
    expect(
      mounted.router.stack.last.name,
      'ReadingRoute',
      reason: 'and it moves nothing',
    );
  });
}

/// `/reading`, pushed over `/`.
Future<({AppRouter router, ReadingHarness harness})> mountReadingOver(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Result<ScriptureText>? scripture,
}) async {
  final ReadingHarness h = readingHarness(
    scripture:
        scripture ?? const Right<Failure, ScriptureText>(liveEnglishPassage),
  );
  getIt.registerSingleton<ReadingCubit>(h.cubit);
  addTearDown(() => getIt.unregister<ReadingCubit>());

  final AppRouter router = AppRouter(
    FakeAuthStatus(),
    _SilentAuthChanges(),
    testRoleAccess(),
  );
  addTearDown(router.dispose);

  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(routerHost(router, locale: locale));
  await pumpUntilFound(tester, find.byType(HomePage));

  unawaited(router.pushPath(AppRoutes.reading));
  await pumpUntilFound(tester, find.byType(ReadingPage));
  await pumpUntilFound(tester, find.byType(ReadingQuizCta));

  expect(router.currentPath, AppRoutes.reading);

  return (router: router, harness: h);
}

final class _SilentAuthChanges extends ReevaluateListenable {}
