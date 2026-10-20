import 'dart:async';

import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
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
/// That is a mistake this project has already paid for once, on the top bar
/// `AppTopBar.wordmark` Phase 5.2 deleted: "no test asserted the rendered text was the
/// one passed, so hard-coding `Text('Evangelion')` here and ignoring the argument
/// passed all 1520 tests. **Requiredness guarantees the parameter *exists* at the
/// call site. It says nothing about whether `build` *reads* it.**" The widget is gone
/// and the lesson is not: `themeMode` differing proves the toggle is wired to *a*
/// value; it proves nothing about the palette reaching a screen.
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

  /// The app's own motion bundle — the four shared clocks above `MaterialApp`.
  ///
  /// Read from **below** the scope, because that is the only place the
  /// bundle is reachable: `NeuralMotionScope` publishes it to its descendants
  /// and holds no getter for it. `LoginPage` is the descendant the app always
  /// has, because it is the entry route.
  ///
  /// `dependOnInheritedWidgetOfExactType` from a test body is legal: the
  /// framework's assertion there is that the element is **active**, not that a
  /// build is in progress.
  EvaNeuralMotion appMotion(WidgetTester tester) =>
      NeuralMotionScope.of(tester.element(find.byType(LoginPage)));

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
    // a validation failure instead. Measured: the first version tapped
    // immediately and landed back on `/login`.
    await tester.pump();
    await tester.tap(find.text(AppLocalizationsEn().authEnterTheWord));
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
          find.text(AppLocalizationsEn().authEnterTheWord),
          findsOneWidget,
          reason: 'English is the default install',
        );

        await getIt<SettingsHandle>().setLanguage(ReadingLanguage.arabic);
        await tester.pump();

        expect(
          find.text(AppLocalizationsAr().authEnterTheWord),
          findsOneWidget,
          reason:
              'the ARABIC value of the same key, rendered by the same widget. This is '
              'the half of the language switch that a `MaterialApp.locale` assertion '
              'cannot see — it proves the string reached the screen. The CTA is the '
              'redesign\'s one translated control (`eva/redesign.html:508`).',
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
      'the app\'s tree carries the `EvaTypeScale` WIDGET, not a hand-written '
      '`MediaQuery`',
      (WidgetTester tester) async {
        // ## THE PLACEMENT ASSERTION, WHICH IS A DIFFERENT CLAIM FROM THE
        // ## **SCALE**
        //
        // The tests above are about the **number** a widget renders at. This
        // one is about the **component** that installs it, and it is the shape
        // decision 144 is about: "a component that is built, tested and never
        // placed is invisible to every assertion that does not look for it on
        // the screen." `EvaTypeScale` was built, exported, documented — its
        // own doc names this exact site — and placed on **no screen at all**,
        // while `app.dart` spelled the same `MediaQuery` out by hand.
        //
        // The rendered-scale assertions above stayed green throughout, which is
        // the point: a number can be right while the component that produced
        // it is unused.
        await pumpApp(tester);
        expect(
          find.byType(EvaTypeScale),
          findsOneWidget,
          reason:
              '`EvaTypeScale` is the design system\'s own install of the reader\'s '
              'step, and `MaterialApp.builder` is the only site above every route. '
              'Its own doc names this line.',
        );
      },
    );

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

    testWidgets('and the shader clock is HELD AT ZERO under the reader\'s own '
        'switch', (WidgetTester tester) async {
      // ## WHY THIS IS AN APP TEST AND NOT A SCOPE TEST
      //
      // The freeze is a property of the **clock**, and the clock lives in the
      // scope — but the question that matters is whether the reader's own
      // switch reaches it, and the reader's switch is the app's business.
      // `NeuralMotionScope`'s own suite proves the scope holds the clock when
      // it is *told* to; this proves the app *tells* it.
      //
      // The platform's half of the same question is the next test, and the
      // two together are what "`UserSettings.reducedMotion` is an **additional**
      // off switch" means in practice: both reach the clock, and neither
      // replaces the other.
      await pumpApp(tester);
      final EvaNeuralMotion motion = appMotion(tester);

      await tester.pump(const Duration(seconds: 2));
      expect(
        motion.lumen.seconds,
        greaterThan(0),
        reason: 'the clock runs while the reader has not asked otherwise',
      );

      await getIt<SettingsHandle>().setReducedMotion(reduced: true);
      await pumpThemeChange(tester);

      expect(
        motion.lumen.seconds,
        0,
        reason:
            'the shader\'s `u_time` is held at ZERO under reduced motion — a '
            'freeze at "wherever it had reached" would be a function of how '
            'long the app had been running',
      );
    });

    testWidgets('and the platform\'s own signal holds it at zero as well', (
      WidgetTester tester,
    ) async {
      // The other half of the pair, and the half the reader cannot see: the
      // OS-level "reduce motion" is an **additional** off switch, and it is
      // combined with the app's own rather than replaced by it
      // (`app.dart`'s `_animationsEnabled`, and `UserSettings.reducedMotion`'s
      // own doc). A reader who has asked the OS for less motion gets it
      // whatever `/settings` says.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpApp(tester);

      final EvaNeuralMotion motion = appMotion(tester);
      expect(
        motion.lumen.seconds,
        0,
        reason:
            'the platform signal alone holds the shader clock at zero, because '
            '`app.dart` combines it with the reader\'s preference before the '
            'scope ever sees an answer',
      );
      expect(
        motion.lumen.reducedMotion,
        isTrue,
        reason:
            'and the clock is **held**, which is a different fact from reading '
            'zero. A scope built with the clocks stopped reports zero too — a '
            'ticker that never started reads zero — so the value alone cannot '
            'tell "held at zero" from "never ran", and the difference is the '
            'whole of the freeze',
      );
    });

    testWidgets(
      'and the OS\'s own switch, FLIPPED MID-SESSION, holds it at zero too',
      (WidgetTester tester) async {
        // ## THE THIRD HALF, AND IT IS THE ONE THAT WAS MISSING
        //
        // The two halves above are **at launch**: the reader's own switch is
        // read from the store, and the platform's is read from the dispatcher,
        // and both are combined by `app.dart`'s `_animationsEnabled` before the
        // scope ever sees an answer.
        //
        // **A reader who turns the OS's "reduce motion" on WHILE THE APP IS
        // OPEN is a third case, and the app did not honour it.** The platform's
        // signal reaches the per-widget `MediaQuery.disableAnimationsOf`
        // checks, because the framework updates that `MediaQuery` — but it did
        // **not** reach the **four shared clocks**, because
        // `NeuralMotionScope.didChangeAccessibilityFeatures` acts only
        // `if (widget.animationsEnabled == null)`, and `app.dart` always passes
        // an explicit value. The scope's observer was therefore **dead code**,
        // and `app.dart`'s own class doc — "honoured again if the reader toggles
        // it mid-session (`NeuralMotionScope` registers a
        // `WidgetsBindingObserver`)" — was **false**, and contradicted the
        // helper's own doc three paragraphs below it, which says the opposite.
        //
        // **Two doc comments in one file disagreeing is how this survives.** The
        // fix is in the composition root, because the scope cannot recompute a
        // value that combines the platform's signal with a **stored**
        // preference it does not know: `app.dart` observes the platform and
        // rebuilds, and `NeuralMotionScope.didUpdateWidget` does the rest.
        await pumpApp(tester);
        final EvaNeuralMotion motion = appMotion(tester);

        await tester.pump(const Duration(seconds: 2));
        expect(
          motion.lumen.seconds,
          greaterThan(0),
          reason: 'the clock runs while nothing has asked otherwise',
        );

        // **The platform's switch, flipped while the app is open.** The test
        // dispatcher fires `onAccessibilityFeaturesChanged` on the setter, which
        // is the same notification a real platform sends.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pump();
        await tester.pump(EvaMotion.screen);

        expect(
          motion.lumen.seconds,
          0,
          reason:
              'a reader who asks the OS for less motion mid-session gets the four '
              'shared clocks stopped, and the shader clock held at zero — the same '
              'answer the same setting gets at launch',
        );
        expect(
          motion.lumen.reducedMotion,
          isTrue,
          reason:
              'and the clock is **held**, not merely stopped where it stood',
        );
      },
    );
  });

  group('the seven sky preferences are written by the cubit and read by the handle', () {
    // ## WHY THE WRITER IS THE CUBIT AND THE READER IS THE HANDLE
    //
    // `/reading` draws the witness sky and may not name `features/settings/` —
    // AGENT_CONTEXT §3 forbids a feature importing another with no exceptions —
    // so the READER of these seven is the handle, and `handle.settings.<field>`
    // is the call-through it uses.
    //
    // **THE WRITER IS THE CUBIT, and it was the handle until a review found
    // the difference.** The brief asked the handle to carry seven writers as
    // well, on the premise that "`/reading` needs to write the sky
    // preferences" — and that premise was **wrong**: `/reading` reads the
    // seven and writes none of them, and `/settings`, which may name its own
    // cubit, writes them. So the handle's seven writers would have been seven
    // public methods with **no production caller**, and a test calling a
    // method to prove it works is not a reader.
    //
    // **So the seven writers are the cubit's** — as the other twenty-seven
    // fields' are — and this suite now proves the thing that actually
    // matters about a seam: **what the cubit writes, the handle reads.**
    testWidgets('and the cubit holds exactly what the reader chose', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final SettingsCubit cubit = getIt<SettingsCubit>();

      await cubit.setStarsOn(on: false);
      await cubit.setConstellationsOn(on: false);
      await cubit.setStarCount(12);
      await cubit.setStarBrightness(150);
      await cubit.setStarShape(SkyStarShape.star);
      await cubit.setStarField(SkyStarField.full);
      await cubit.setTwinkle(twinkling: false);

      final UserSettings settings = getIt<SettingsCubit>().state.settings;
      expect(settings.starsOn, isFalse);
      expect(settings.constellationsOn, isFalse);
      expect(
        settings.starCount,
        12,
        reason: 'inside the slider\'s range (0…60) and therefore unchanged',
      );
      expect(settings.starBrightness, 150);
      expect(settings.starShape, SkyStarShape.star);
      expect(settings.starField, SkyStarField.full);
      expect(settings.twinkle, isFalse);
    });

    testWidgets('and the STORE holds them too', (WidgetTester tester) async {
      await pumpApp(tester);
      final SettingsCubit cubit = getIt<SettingsCubit>();

      await cubit.setStarCount(12);
      await cubit.setStarShape(SkyStarShape.star);
      await cubit.setTwinkle(twinkling: false);

      // **A fresh data source over the same store** — the only way to prove the
      // value was persisted rather than held in the cubit. The language arm
      // above is the precedent, and the reason is the same.
      final SettingsLocalDataSource fresh = SettingsLocalDataSource();
      addTearDown(fresh.resetForTest);
      final UserSettings stored = await fresh.read();
      expect(stored.starCount, 12);
      expect(stored.starShape, SkyStarShape.star);
      expect(stored.twinkle, isFalse);
    });

    testWidgets('and the handle READS them back, as a call-through', (
      WidgetTester tester,
    ) async {
      // **The readers are `handle.settings.<field>`** — and the handle's
      // `settings` getter is a call-through to the cubit's state, so there is
      // one copy of the preference in the process and the reader sees the
      // value the writer just wrote.
      await pumpApp(tester);
      final SettingsHandle handle = getIt<SettingsHandle>();
      final SettingsCubit cubit = getIt<SettingsCubit>();

      await cubit.setStarCount(30);
      await cubit.setTwinkle(twinkling: false);

      expect(handle.settings.starCount, 30);
      expect(handle.settings.twinkle, isFalse);
      expect(
        identical(handle.settings, getIt<SettingsCubit>().state.settings),
        isTrue,
        reason:
            'the same object, not an equal one — a cached copy in the handle '
            'would be a second source of truth for one preference, which is '
            'the hazard the handle was written to prevent',
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
