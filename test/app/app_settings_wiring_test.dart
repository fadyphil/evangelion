import 'dart:async';

import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/design_system_harness.dart';

/// ## WHY THIS FILE AND NOT A `SettingsPage` WIDGET TEST
///
/// The plan's verification line is "**changing the theme in Settings rebuilds the
/// whole app**". Two clauses of that are about `/settings` (does the tap change the
/// setting) and one is about the **app** (does the app rebuild). A widget test over the
/// page cannot answer the third clause at all: `evaPrimitiveHarness` is a bare
/// `MaterialApp` with no `builder`, no `SettingsScope` and no router, so a toggle there
/// proves exactly nothing about the root.
///
/// So this file mounts `EvangelionApp` — the real composition root, the real
/// `SettingsCubit`, the real `shared_preferences` — and reads the result **from a
/// widget below `MaterialApp`**, which is the only place the answer exists.
///
/// ## AND IT ASSERTS THE RENDERED THEME, NOT `MaterialApp.themeMode`
///
/// The naive version of this test reads `MaterialApp.themeMode` and checks it flipped.
/// That is the mistake `AppTopBar.wordmark`'s doc records at length: "no test asserted
/// the rendered text was the one passed, so hard-coding `Text('Evangelion')` here and
/// ignoring the argument passed all 1520 tests. **Requiredness guarantees the parameter
/// *exists* at the call site. It says nothing about whether `build` *reads* it.**"
/// `themeMode` differing proves the toggle is wired to *a* value; it proves nothing
/// about the palette reaching a screen.
///
/// So every assertion here reads `Theme.of(element)!.extension<EvaColors>()` — the
/// palette **a widget actually resolved** — from inside the tree `LoginPage` is
/// painted in.
void main() {
  setUp(() {
    // **The store has to exist before `configureNavigation()` builds the graph.**
    // `pumpApp` registers the real `SettingsRepositoryImpl`, and `app.dart`'s
    // `initState` reads through it; without a mock the read goes to a
    // `MethodChannel` no test handler answers. `setMockInitialValues` installs an
    // `InMemorySharedPreferencesStore`, so this is the app's **real** store over an
    // in-memory one — the same shape a device has.
    //
    // Per-test, not once: `reading_harness`'s doc records that a store memoised by one
    // data source is invisible to the next, and this is the same hazard at the
    // locator's level.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    resetServiceLocator();
  });
  tearDown(resetServiceLocator);

  /// Pumps far enough for `AnimatedTheme` to finish.
  ///
  /// ## WHY A BOUNDED PUMP AND NOT `pumpAndSettle`
  ///
  /// `NeuralMotionScope` hosts three `repeat()`ing controllers above `MaterialApp`,
  /// so "settled" never arrives and `pumpAndSettle` times out — the same measurement
  /// `app_harness.dart`'s `pumpUntilFound` exists for. And a single `tester.pump()`
  /// is not enough either: `MaterialApp` changes the palette through an
  /// **`AnimatedTheme`**, and `EvaColors` is a `ThemeExtension`, so it is *lerped*.
  /// Mid-animation `Theme.of(context).extension<EvaColors>()!.canvas` is a blend of
  /// the two palettes and is neither.
  ///
  /// Two `EvaMotion.screen` steps is 500ms, well past Material's
  /// `kThemeAnimationDuration` (200ms), and it is a **number** rather than a settle so
  /// the ambient clocks cannot make it flaky.
  Future<void> pumpThemeChange(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(EvaMotion.screen);
    await tester.pump(EvaMotion.screen);
  }

  /// Signs in for real and lands on `/`, so the guarded routes are reachable.
  ///
  /// **`pushPath` unawaited and then pumped**, and the reason is the same shape as the
  /// bounded pump: `pushPath`'s future completes when the push *animation* finishes,
  /// so awaiting it inside a `testWidgets` body with no pump in between never
  /// completes. Measured: the first version of the stack test hung for the full
  /// harness timeout on exactly this `await`.
  Future<void> pumpSignedInHome(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).at(0), 'reader@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'sun-school-2026');
    // **A pump between the fields and the press.** `EvaTextField` reports its change
    // through a controller listener, so the cubit has not seen the second value until
    // a frame runs — and pressing sign in with the password still empty submits the
    // `kRequiredMessage` validation instead. Measured: the first version tapped
    // immediately and landed back on `/login`.
    await tester.pump();
    await tester.tap(find.text(AppLocalizationsEn().authSignIn));
    await pumpUntilFound(tester, find.byType(HomePage));
    expect(
      getIt<AppRouter>().currentPath,
      AppRoutes.home,
      reason: 'signed in, so the guard lets the next push through',
    );
  }

  /// The palette a real widget under `MaterialApp` resolved.
  ///
  /// [element] is the element to read **from**, and the assertion is on `Theme.of`
  /// rather than on `MaterialApp.themeMode` — see the file doc.
  EvaColors renderedPaletteAt(WidgetTester tester, Finder finder) {
    final BuildContext context = tester.element(finder);
    return Theme.of(context).extension<EvaColors>()!;
  }

  /// The text scale a real widget under `MaterialApp` resolved.
  double renderedScaleAt(WidgetTester tester, Finder finder) =>
      MediaQuery.textScalerOf(tester.element(finder)).scale(1);

  group('the theme flip reaches the WHOLE app', () {
    // ## THE ASSERTION, AND WHY IT IS NOT ABOUT `themeMode`
    //
    // `renderedPaletteAt` reads `EvaColors` off the **live theme of a live widget**.
    // For that to go red when the plumbing breaks, the read has to be below
    // `MaterialApp` — a `themeMode` that changed while `builder`/`theme` stayed put
    // would still leave every screen rendering the old palette, and only a rendered
    // read can see that.
    testWidgets('a fresh install renders the DARK palette, in a live widget', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(
        renderedPaletteAt(tester, find.byType(LoginPage)).canvas,
        const EvaColors.dark().canvas,
        reason:
            'the default install. Read off `Theme.of` inside the painted page, not '
            'off `MaterialApp.theme` — which `app_test.dart` asserts by identity and '
            'which says nothing about what a screen resolved.',
      );
    });

    testWidgets(
      'flipping to light repaints the live page in the LIGHT palette',
      (WidgetTester tester) async {
        await pumpApp(tester);
        expect(
          renderedPaletteAt(tester, find.byType(LoginPage)).canvas,
          const EvaColors.dark().canvas,
        );

        await getIt<SettingsHandle>().setThemeMode(AppThemeMode.light);
        await pumpThemeChange(tester);

        expect(
          renderedPaletteAt(tester, find.byType(LoginPage)).canvas,
          const EvaColors.light().canvas,
          reason:
              'THE load-bearing assertion. The widget under test is the same element '
              'as before, so a pass means the palette reached it — not that a value '
              'changed. Replacing `themeMode: switch (settings.themeMode) …` with a '
              'hard-coded `ThemeMode.dark` leaves this red.',
        );
        // And the OTHER direction, because a one-way flip is a switch wired to one leg.
        await getIt<SettingsHandle>().setThemeMode(AppThemeMode.dark);
        await pumpThemeChange(tester);
        expect(
          renderedPaletteAt(tester, find.byType(LoginPage)).canvas,
          const EvaColors.dark().canvas,
        );
      },
    );

    testWidgets('and `system` follows the platform brightness', (
      WidgetTester tester,
    ) async {
      // `AppThemeMode.system` is the third value and it is **not** the default, so
      // nothing else in the suite reaches it. The platform here is
      // `TargetPlatform.android` with `platformBrightness: light`, so `System` must
      // render the LIGHT palette — the same answer `light` gives, by a different
      // route, which is what makes it worth a test of its own.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(tester);
      await getIt<SettingsHandle>().setThemeMode(AppThemeMode.system);
      await pumpThemeChange(tester);

      expect(
        renderedPaletteAt(tester, find.byType(LoginPage)).canvas,
        const EvaColors.light().canvas,
        reason: '`system` must ask the platform, not fall back to `dark`',
      );
    });
  });

  group('the palette flip does not LOSE the navigation stack', () {
    // ## THE MEASUREMENT THIS EXISTS FOR, AND IT IS A `MaterialApp` BUG RATHER THAN
    // ## A SETTINGS ONE
    //
    // `Router.withConfig`'s body destructures `routerConfig` into
    // `routeInformationProvider` / `routeInformationParser` / `routerDelegate`, and
    // `_RouterState.didUpdateWidget` unsubscribes the old delegate whenever
    // `widget.routerDelegate` differs (`packages/flutter/lib/src/widgets/router.dart:753`).
    // `AppRouter.config()` builds a **new** `RouterConfig` — and therefore a **new**
    // `RootStackRouter` — on every call, so `router.config(…)` written inline in
    // `build` meant any rebuild of `MaterialApp.router` handed `Router` a different
    // delegate and the whole stack was rebuilt from the initial route.
    //
    // A reader changing their theme on `/reading` would be thrown back to `/`. The fix
    // is `app.dart`'s memoised `_configFor`, and this is the assertion that knows it —
    // in **both** directions, because a memoisation that is dropped on a rebuild is a
    // stack reset and one that never memoises is the same bug.
    testWidgets('the route on top survives a palette change', (
      WidgetTester tester,
    ) async {
      await pumpSignedInHome(tester);

      // `unawaited` + `pumpUntilFound`, not `await pushPath` — see the helper's doc.
      unawaited(getIt<AppRouter>().pushPath(AppRoutes.settings));
      await pumpUntilFound(tester, find.byType(SettingsPage));
      expect(getIt<AppRouter>().currentPath, AppRoutes.settings);

      await getIt<SettingsHandle>().setThemeMode(AppThemeMode.light);
      await pumpThemeChange(tester);

      expect(
        getIt<AppRouter>().currentPath,
        AppRoutes.settings,
        reason:
            'the reader is still where they were. A `routerConfig` built inside '
            '`build` hands `Router` a fresh delegate on every rebuild and the stack '
            'resets to the initial route — which for a reader who opened /settings '
            'from / is /login.',
      );
      expect(find.byType(SettingsPage), findsOneWidget);

      // …and back again, so it is a flip and not a one-way trip.
      await getIt<SettingsHandle>().setThemeMode(AppThemeMode.dark);
      await pumpThemeChange(tester);
      expect(getIt<AppRouter>().currentPath, AppRoutes.settings);
    });

    testWidgets('and so does the language change', (WidgetTester tester) async {
      // Same mechanism, different trigger, and it is worth a separate case: the
      // language switch rebuilds `MaterialApp` for the **locale** and therefore takes
      // exactly the same code path.
      await pumpSignedInHome(tester);
      unawaited(getIt<AppRouter>().pushPath(AppRoutes.settings));
      await pumpUntilFound(tester, find.byType(SettingsPage));

      await getIt<SettingsHandle>().setLanguage(ReadingLanguage.arabic);
      await pumpThemeChange(tester);

      expect(
        getIt<AppRouter>().currentPath,
        AppRoutes.settings,
        reason: 'a locale change must not be a navigation',
      );
    });
  });

  group('the language switch changes the app locale, and the corpus follows', () {
    testWidgets(
      'the Arabic arm reaches a live widget\'s strings and direction',
      (WidgetTester tester) async {
        await pumpApp(tester);

        expect(
          find.text(AppLocalizationsEn().authSignIn),
          findsOneWidget,
          reason: 'English is the default install',
        );

        await getIt<SettingsHandle>().setLanguage(ReadingLanguage.arabic);
        await tester.pump();

        expect(
          find.text('تسجيل الدخول'),
          findsOneWidget,
          reason:
              'the ARABIC value of the same key, rendered by the same widget. This is '
              'the half of the language switch that a `MaterialApp.locale` assertion '
              'cannot see — it proves the string reached the screen.',
        );
        expect(
          Directionality.of(tester.element(find.byType(LoginPage))),
          TextDirection.rtl,
          reason:
              'and the direction follows, because `MaterialApp` derives it from the '
              'locale. Defect #2 in its most basic form: Arabic laid out LTR.',
        );
      },
    );

    testWidgets('and it is persisted, so a fresh app root honours it', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await getIt<SettingsHandle>().setLanguage(ReadingLanguage.arabic);
      await pumpThemeChange(tester);

      // Read it back through a **second** store instance, which is the only way to
      // prove it was written to `shared_preferences` rather than held in the cubit.
      final SettingsLocalDataSource fresh = SettingsLocalDataSource();
      addTearDown(fresh.resetForTest);
      expect(
        (await fresh.read()).language,
        ReadingLanguage.arabic,
        reason: 'a fresh `SettingsLocalDataSource` over the same store',
      );
    });
  });

  group('the font step is installed app-wide, and it is ONE input', () {
    testWidgets('the store\'s step is the scale a live widget renders at', (
      WidgetTester tester,
    ) async {
      // ## THE WHOLE OF §14 IN ONE ASSERTION, AND IT IS AN ASSERTION ABOUT A
      // ## **RENDERED** NUMBER
      //
      // Phase 7 could only test 1.22× by injecting it as a platform scale, because the
      // platform was half of the composition. With one input the requirement is
      // reachable by the reader's own hand: seed the store with step 5, launch, and
      // read the scale off a live widget.
      // Re-seeded with the step the reader chose. `setMockInitialValues` nullifies the
      // package's singleton completer, so this replaces the empty store the `setUp`
      // installed rather than merging with it.
      SharedPreferences.setMockInitialValues(<String, Object>{
        kFontStepKey: kFontStepMax,
      });
      await pumpApp(tester);

      expect(
        renderedScaleAt(tester, find.byType(LoginPage)),
        closeTo(kEvaRequiredTextScale, 0.0001),
        reason:
            '§14\'s number, reached through `UserSettings.fontStep` and installed '
            'by `EvaTypeScale` at `MaterialApp.builder`. A widget test over '
            '`SettingsPage` cannot assert this: `evaPrimitiveHarness` has no '
            '`builder`, so the install does not exist there.',
      );
    });

    testWidgets(
      'the five positions are five rendered sizes, with no dead zone',
      (WidgetTester tester) async {
        await pumpApp(tester);

        final Set<double> seen = <double>{};
        for (int step = kFontStepMin; step <= kFontStepMax; step++) {
          await getIt<SettingsHandle>().setFontStep(step);
          await tester.pump();
          seen.add(renderedScaleAt(tester, find.byType(LoginPage)));
        }
        expect(
          seen,
          hasLength(kFontStepMax),
          reason:
              'THIS is the assertion the deleted `readingTextScalerFor` could not pass. '
              'Its doc recorded that "at a platform scale above 1.109 the top of the '
              'control collapses: steps 3, 4 and 5 all render at the ceiling", and a '
              'page-level test asserted that dead zone was REAL. One input, one scale, '
              'and five positions.',
        );
        expect(
          seen,
          <double>{
            for (int step = kFontStepMin; step <= kFontStepMax; step++)
              evaScalerFor(step).scale(1),
          },
          reason:
              'and the five numbers are §5.2\'s own rows, read off the table rather '
              'than restated',
        );
      },
    );

    testWidgets('the knob and the rendered size are the same number', (
      WidgetTester tester,
    ) async {
      // The invariant `reading_page_test.dart` could only assert on the **setting**
      // because a bare pump has no install. Here both halves exist.
      await pumpApp(tester);

      for (int step = kFontStepMin; step <= kFontStepMax; step++) {
        await getIt<SettingsHandle>().setFontStep(step);
        await pumpThemeChange(tester);
        expect(
          renderedScaleAt(tester, find.byType(LoginPage)),
          closeTo(evaScalerFor(step).scale(1), 0.0001),
          reason: 'step $step must render at its own row',
        );
        expect(
          fontStepFromScaler(
            MediaQuery.textScalerOf(tester.element(find.byType(LoginPage))),
          ),
          step,
          reason:
              'and reading the step back out of the installed scaler gives the same '
              'step — which is what makes a knob/size mismatch unexpressible',
        );
      }
    });

    testWidgets(
      'a step outside the table is CLAMPED before it reaches the engine',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          // A hand-edited or version-skewed preference. `SettingsCubit` clamps it.
          kFontStepKey: 99,
        });
        await pumpApp(tester);

        expect(
          renderedScaleAt(tester, find.byType(LoginPage)),
          closeTo(evaScalerFor(kFontStepMax).scale(1), 0.0001),
          reason:
              '`99` is the top of the table, not "1.22 by accident". The alternative — '
              'an unclamped value — renders the same number here, so the discriminating '
              'assertion is the one below.',
        );
        expect(
          getIt<SettingsCubit>().state.settings.fontStep,
          kFontStepMax,
          reason:
              'and the CUBIT clamped it, which is the boundary `clampFontStep`\'s doc '
              'names: a value outside the table would put the stepper\'s knob at a '
              'position no step owns',
        );
      },
    );
  });

  group('the settings scope is where the app-wide values come from', () {
    testWidgets('`SettingsScope.of` resolves the app\'s own handle', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      final SettingsHandle fromPage = SettingsScope.of(
        tester.element(find.byType(LoginPage)),
      );
      expect(
        identical(fromPage, getIt<SettingsHandle>()),
        isTrue,
        reason:
            'the scope above `MaterialApp` publishes the same object the locator '
            'holds, so a screen reading the scope and a test reading the locator see '
            'one set of preferences rather than two',
      );
    });

    testWidgets('and the reduce-motion preference reaches the ambient scope', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final NeuralMotionScope scope = tester.widget<NeuralMotionScope>(
        find.byType(NeuralMotionScope),
      );
      expect(
        scope.animationsEnabled,
        isTrue,
        reason: 'the default is "animations on" — `UserSettings.reducedMotion` is false',
      );

      await getIt<SettingsHandle>().setReducedMotion(reduced: true);
      await pumpThemeChange(tester);

      expect(
        tester
            .widget<NeuralMotionScope>(find.byType(NeuralMotionScope))
            .animationsEnabled,
        isFalse,
        reason:
            'Phase 9 pays the debt `app.dart` recorded in its own words ("A later '
            'phase replaces that default with the persisted `UserSettings` value"). '
            'The scope is ABOVE `MaterialApp`, so this cannot be a `MediaQuery` read.',
      );
    });
  });

  group(
    'the app opens dark on a fresh install, which the default still is',
    () {
      testWidgets(
        'and `MaterialApp` still declares both palettes by identity',
        (WidgetTester tester) async {
          // `app_test.dart`'s group asserts the *declaration*; this asserts the
          // *decision*, and the two are different: a `themeMode` hard-coded to `dark`
          // passes the first and fails `renderedPaletteAt` above only if the widget read
          // stops happening. Both live here so a reader can see the pair.
          await pumpApp(tester);

          final MaterialApp app = tester.widget<MaterialApp>(
            find.byType(MaterialApp),
          );
          expect(app.theme, same(EvaThemeLight.theme));
          expect(app.darkTheme, same(EvaThemeDark.theme));
          expect(app.themeMode, ThemeMode.dark);
          expect(AppConfig.appVersion, '1.0.0 (1)');
        },
      );
    },
  );
}
