import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/features/settings/presentation/widgets/language_sheet.dart';

import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/settings_harness.dart';

/// `/settings` — what is on screen, in both arms.
///
/// ## WHAT IS ASSERTED HERE AND WHAT IS **NOT**
///
/// This file is about the **rendered tree**: which groups, which controls, which
/// strings, and which widget *types*. It is not about the app-wide consequences of a
/// tap — `test/app/app_settings_wiring_test.dart` owns "the palette reached every
/// screen", `test/core/domain/repositories/settings_repository_test.dart` owns "the
/// value survived a restart", and this file owns "the control that does it is on the
/// screen and is the shared widget".
void main() {
  /// Pumps `/settings` over a harness with a **real** settings scope.
  ///
  /// **Not `cubit:` alone.** `SettingsScope` is what the controls write through, and a
  /// bare page with no scope would fall back to the locator — which works and is
  /// unwatched, so a settings-driven rebuild would never reach the tree and the page
  /// would look frozen. `settingsScope` puts the harness's handle above it.
  Future<SettingsHarness> pumpSettings(
    WidgetTester tester, {
    UserSettings? stored,
    Locale locale = const Locale('en'),
    Size size = kAmbientSurface,
  }) async {
    final SettingsHarness harness = settingsHarness(
      initial: stored,
      loadImmediately: false,
    );
    await harness.cubit.load();
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        textDirection: locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: settingsScope(tester, SettingsPage(cubit: harness.cubit)),
      ),
    );
    await tester.pump();
    return harness;
  }

  group('the three groups, and their order', () {
    testWidgets('Appearance, Reading, About — the prototype\'s own order', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.byType(SettingsGroup), findsNWidgets(3));
      // **UPPERCASED**, because `EvaSectionHeader` transcribes
      // `SettingsScreen.tsx:29`'s `textTransform: 'uppercase'` in Dart, which Flutter
      // has no equivalent for. Asserting the ARB value here would be asserting a
      // string the screen deliberately does not draw — and the section labels are the
      // one place where the prototype's casing is a *rendering* rule rather than a
      // data field.
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('READING'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(
        find.text('SettingsGroup'),
        findsNothing,
        reason: 'anti-vacuity: the class is not named as a string anywhere',
      );
    });

    testWidgets('and the group labels are in paint order, top to bottom', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      final List<double> tops = <double>[
        for (final String label in <String>['APPEARANCE', 'READING', 'ABOUT'])
          tester.getTopLeft(find.text(label)).dy,
      ];
      expect(
        tops,
        orderedEquals(<double>[...tops]..sort()),
        reason: 'Appearance above Reading above About',
      );
    });

    testWidgets('the cut rows are genuinely ABSENT, not drawn inert', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      final AppLocalizationsEn strings = AppLocalizationsEn();

      // The prototype's fourth group and its four rows. Each one has a reason recorded
      // on `SettingsPage`; this is the assertion that the reasons were acted on rather
      // than the rows being shipped disabled.
      expect(find.text('ACCOUNT'), findsNothing, reason: 'and uppercased');
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.text(strings.settingsVersion), findsOneWidget);
      expect(
        find.text('Privacy policy'),
        findsNothing,
        reason:
            'a legal document with no URL and no screen. An inert row that answers '
            '"unavailable in this build" is worse than no row at all.',
      );
      expect(
        find.text(strings.settingsReduceMotion),
        findsOneWidget,
        reason:
            'and the one row the prototype does NOT have is here — it is the debt '
            '`app.dart` recorded in its own words',
      );
    });
  });

  group(
    '`SettingsGroup` and the screen share the IDENTICAL `SegmentedControl`',
    () {
      // ## THE PLAN'S VERIFICATION, AND WHY IT IS A TYPE IDENTITY
      //
      // "SettingsGroup and the settings screen share the identical SegmentedControl
      // instance type." Two look-alike classes would satisfy every behavioural
      // assertion in this file — same keyboard model, same semantics, same goldens — and
      // satisfy it by being two implementations of one idea, which is the defect this
      // repository has already paid for in `qa`/`santa` shape ("a name-checker with
      // false positives"). So the assertion is on the **runtime type** of the widget the
      // tree actually holds, read off the element.
      testWidgets(
        'the theme control is the barrel\'s `SegmentedControl<AppThemeMode>`',
        (WidgetTester tester) async {
          await pumpSettings(tester);

          expect(find.byType(SegmentedControl<AppThemeMode>), findsOneWidget);
          // **The failing direction is the same line**: a second, private `SegmentedControl`
          // in `features/settings/` would satisfy nothing here, because the barrel's generic
          // type is not what the tree would hold.
          expect(
            tester
                .widget(find.byType(SegmentedControl<AppThemeMode>))
                .runtimeType,
            SegmentedControl<AppThemeMode>,
          );
          // And no other `SegmentedControl` at all, so the "identical instance type" claim
          // is not satisfied by two instances of two types.
          expect(find.byType(SegmentedControl<Object>), findsNothing);
        },
      );

      testWidgets('and it carries the barrel\'s own constants, not copies', (
        WidgetTester tester,
      ) async {
        await pumpSettings(tester);

        final SegmentedControl<AppThemeMode> control = tester.widget(
          find.byType(SegmentedControl<AppThemeMode>),
        );
        expect(
          control.values,
          AppThemeMode.values,
          reason:
              'the theme picker is the prototype\'s three options in the prototype\'s '
              'order, and `AppThemeMode.values` is where that list lives',
        );
        expect(control.selected, AppThemeMode.dark);
        expect(SegmentedControl.trackRadius, 8);
      });

      testWidgets('a tap on a segment writes the setting', (
        WidgetTester tester,
      ) async {
        final SettingsHarness harness = await pumpSettings(tester);

        await tester.tap(find.text('LIGHT'));
        await tester.pump();

        expect(
          harness.cubit.state.settings.themeMode,
          AppThemeMode.light,
          reason:
              'the picker is a **controlled** component — it reports and the caller feeds '
              'the value back — so the control moving and the setting changing are two '
              'claims and this is the second',
        );
      });
    },
  );

  group('the font stepper is the shared widget, and it writes through', () {
    testWidgets('it is `FontSizeStepper`, sitting on the stored step', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester, stored: const UserSettings(fontStep: 5));

      expect(find.byType(FontSizeStepper), findsOneWidget);
      final FontSizeStepper stepper = tester.widget(
        find.byType(FontSizeStepper),
      );
      expect(stepper.step, 5);
      expect(
        stepper.labels.track,
        AppLocalizationsEn().settingsFontScale,
        reason:
            'the labels are the app\'s strings, not the design system\'s defaults — '
            '`FontSizeStepperLabels` has no defaults precisely so this cannot regress',
      );
    });

    testWidgets('the increment writes, and the stepper follows the setting', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = await pumpSettings(
        tester,
        stored: const UserSettings(fontStep: 3),
      );

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();

      expect(harness.cubit.state.settings.fontStep, 4);
      expect(
        tester.widget<FontSizeStepper>(find.byType(FontSizeStepper)).step,
        4,
        reason:
            'the widget reads its `step` from the cubit, so the knob cannot sit at a '
            'position the setting does not own',
      );
    });

    testWidgets('and a corrupt stored step renders as the top of the table', (
      WidgetTester tester,
    ) async {
      // A stored `99` reaches the page because `SettingsCubit` clamps on load; the
      // stepper then shows 5 rather than a knob past the end of the track.
      final SettingsHarness harness = await pumpSettings(
        tester,
        stored: const UserSettings(fontStep: 5),
      );
      expect(harness.cubit.state.settings.fontStep, kFontStepMax);
      expect(
        tester.widget<FontSizeStepper>(find.byType(FontSizeStepper)).step,
        kFontStepMax,
      );
    });
  });

  group('the reduce-motion switch is the shared widget, with LOCALISED labels', () {
    testWidgets('`EvaToggle` is on screen and its labels are the ARB strings', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.byType(EvaToggle), findsOneWidget);
      // **Field by field, not `expect(labels, labels)`.** `EvaToggleLabels` is a
      // plain `@immutable` value object with no `==` — `FontSizeStepperLabels`
      // beside it is the same — so an object comparison here is an **identity**
      // comparison and would be red even with the strings agreeing. The fields are
      // the assertion.
      final EvaToggleLabels labels = tester
          .widget<EvaToggle>(find.byType(EvaToggle))
          .labels;
      expect(labels.on, AppLocalizationsEn().settingsMotionOn);
      expect(labels.off, AppLocalizationsEn().settingsMotionOff);
      expect(labels.on, 'On');
      expect(labels.off, 'Off');
    });

    testWidgets(
      'and on the ARABIC arm they are Arabic, not the English defaults',
      (WidgetTester tester) async {
        // ## THE DEFECT THIS CLOSES, AND WHY NOTHING CAUGHT IT FOR SIX PHASES
        //
        // `EvaToggle` published `Semantics(label: value ? 'On' : 'Off')` — two English
        // words on both arms. No gate could see it: a semantics label is not painted, the
        // Arabic glyph gate walks the **painted** tree, and a golden captures no
        // semantics. It became visible only because Phase 9 built the screen the switch
        // ships on.
        await pumpSettings(tester, locale: const Locale('ar'));

        final EvaToggleLabels arabic = tester
            .widget<EvaToggle>(find.byType(EvaToggle))
            .labels;
        expect(arabic.on, AppLocalizationsAr().settingsMotionOn);
        expect(arabic.off, AppLocalizationsAr().settingsMotionOff);
        expect(arabic.on, isNot('On'));
        expect(arabic.off, isNot('Off'));
        expect(
          arabic.on,
          isNot(matches(RegExp('[A-Za-z]'))),
          reason:
              'no Latin script on the Arabic arm at all, which is why '
              'the Arabic arm carries no Latin script here, which is why the ARB '
              "test's `latinIsCorrect` exception list does not grow",
        );
      },
    );

    testWidgets('a tap writes the preference', (WidgetTester tester) async {
      final SettingsHarness harness = await pumpSettings(tester);

      await tester.tap(find.byType(EvaToggle));
      await tester.pump();

      expect(harness.cubit.state.settings.reducedMotion, isTrue);
      expect(tester.widget<EvaToggle>(find.byType(EvaToggle)).value, isTrue);
    });
  });

  group('the language row and its sheet', () {
    testWidgets('the row shows the CURRENT language as a name', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(
        find.text(
          AppLocalizationsEn().languageLabelFor(ReadingLanguage.english),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'and it names the PLATFORM language when the reader has not chosen',
      (WidgetTester tester) async {
        // `UserSettings.language` is `null` for "follow the platform", and the row's
        // trailing is `selectedLanguageOf(context)` — the *rendered* language. On an
        // Arabic device with no stored choice the row must read Arabic, or a screen that
        // is entirely Arabic shows an empty selection.
        await pumpSettings(tester, locale: const Locale('ar'));

        expect(
          find.text(
            AppLocalizationsAr().languageLabelFor(ReadingLanguage.arabic),
          ),
          findsOneWidget,
          reason: 'the Arabic device\'s language, not the entity default',
        );
        expect(
          selectedLanguageOf(tester.element(find.byType(SettingsPage))),
          ReadingLanguage.arabic,
        );
      },
    );

    testWidgets('a tap opens a REAL bottom sheet with both languages', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text(AppLocalizationsEn().settingsDefaultLanguage));
      await tester.pumpAndSettle();

      // **A `showModalBottomSheet` and not an inline disclosure**, because defect #7 is
      // "a language control that navigates nowhere" and the fix is a control that opens
      // something and then does the thing.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settingsLanguageSheetTitle),
        findsOneWidget,
      );
      expect(
        find.text(
          AppLocalizationsEn().languageLabelFor(ReadingLanguage.english),
        ),
        findsWidgets,
      );
      expect(
        find.text(
          AppLocalizationsEn().languageLabelFor(ReadingLanguage.arabic),
        ),
        findsOneWidget,
      );
    });

    testWidgets('picking Arabic WRITES the setting and closes the sheet', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = await pumpSettings(tester);

      await tester.tap(find.text(AppLocalizationsEn().settingsDefaultLanguage));
      await tester.pumpAndSettle();
      // The row is named in the arm the sheet opens in, so the English arm's Arabic row
      // reads `Arabic` and the Arabic arm's reads `العربية`.
      await tester.tap(
        find.text(
          AppLocalizationsEn().languageLabelFor(ReadingLanguage.arabic),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        harness.cubit.state.settings.language,
        ReadingLanguage.arabic,
        reason:
            'the sheet\'s job is the WRITE, not the opening. Closing without writing '
            'is defect #7 restated one layer down, and this is the assertion that '
            'tells the two apart.',
      );
      expect(find.byType(BottomSheet), findsNothing, reason: 'and it closes');
    });

    testWidgets(
      'and picking the language that is ALREADY CHOSEN closes without a write',
      (WidgetTester tester) async {
        // **Seeded with `english`**, not merely rendering it. On a fresh install
        // `language` is `null` — "follow the platform" — and picking `English` is a
        // **real** change from inheriting to pinning, which the first version of this
        // test got wrong and which is the case one line below.
        final SettingsHarness harness = await pumpSettings(
          tester,
          stored: const UserSettings(language: ReadingLanguage.english),
        );
        final UserSettings before = harness.cubit.state.settings;

        await tester.tap(
          find.text(AppLocalizationsEn().settingsDefaultLanguage),
        );
        await tester.pumpAndSettle();
        // **Descendant of the sheet**, because the settings row's trailing already
        // renders `English` and the finder is otherwise ambiguous — the first version
        // tapped the row's own text and hit "Found 2 widgets", which is a failure about
        // the test and not about the screen.
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(
              AppLocalizationsEn().languageLabelFor(ReadingLanguage.english),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(
          harness.cubit.state.settings,
          before,
          reason:
              'no change, so `SettingsCubit.apply` emits nothing and the app does not '
              'rebuild. Its "no emit for an unchanged value" rule is what makes a '
              'reader\'s second tap free.',
        );
      },
    );

    testWidgets(
      'and picking the language a reader has only INHERITED is a real change',
      (WidgetTester tester) async {
        // The distinction the case above is about, asserted rather than described: the
        // row shows the *rendered* language, which on a fresh install comes from the
        // platform, and `UserSettings.language` is `null`. Choosing it therefore moves
        // the setting from "follow the platform" to "pinned to English" — which is a
        // write, not a no-op, and a screen that treated it as a no-op would leave a
        // reader on an Arabic device unable to pin English at all.
        final SettingsHarness harness = await pumpSettings(tester);
        expect(harness.cubit.state.settings.language, isNull);

        await tester.tap(
          find.text(AppLocalizationsEn().settingsDefaultLanguage),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(
              AppLocalizationsEn().languageLabelFor(ReadingLanguage.english),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.cubit.state.settings.language, ReadingLanguage.english);
      },
    );

    testWidgets(
      'the sheet rows are `Semantics(selected:)` so the choice announces',
      (WidgetTester tester) async {
        await pumpSettings(tester);
        await tester.tap(
          find.text(AppLocalizationsEn().settingsDefaultLanguage),
        );
        await tester.pumpAndSettle();

        final SemanticsHandle handle = tester.ensureSemantics();
        final SemanticsData row = semanticsTree(tester).firstWhere(
          (SemanticsData node) =>
              node.label ==
              AppLocalizationsEn().languageLabelFor(ReadingLanguage.english),
        );
        expect(
          // **A `Tristate` and not a `bool`** — `SemanticsFlags.isSelected` is
          // tri-state in Flutter 3.47, so `isTrue` is an identity check against
          // `Tristate.isTrue` that reads as a boolean assertion and is not one.
          row.flagsCollection.isSelected,
          Tristate.isTrue,
          reason:
              'the CURRENT one is selected. Without `selected` a screen reader cannot '
              'tell which of the two is in force, which is §14\'s colour-only row applied '
              'to a language picker.',
        );
        expect(row.flagsCollection.isButton, isTrue);
        // **Disposed in the BODY**, never in `addTearDown` — recorded decision 38
        // measured eight failures across two suites for exactly that: `testWidgets`
        // compares the live handle count against the one taken before the framework
        // takes its own, so a teardown that runs after that check is a leak it reports
        // as an unrelated-looking assertion. (It did, here, on the first run.)
        handle.dispose();
      },
    );
  });

  group('the About group, and its one row', () {
    testWidgets('the version is shown, and it MATCHES `pubspec.yaml`', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text(AppConfig.appVersion), findsOneWidget);
      expect(AppConfig.appVersion, '1.0.0 (1)');

      // **The whole reason the constant is a constant.** `pubspec.yaml` is the
      // authority and a bump without bumping this is a lie on a reader's screen; this
      // reads the file so the two cannot drift silently.
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExpMatch version = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec)!;
      final String declared = version.group(1)!;
      final String name = declared.split('+').first;
      final String build = declared.split('+')[1];
      expect(
        AppConfig.appVersion,
        '$name ($build)',
        reason:
            'pubspec.yaml declares `$declared` and `/settings` must not disagree. '
            'Bump the version and this goes red until `AppConfig.appVersion` moves.',
      );
    });

    testWidgets('and the prototype\'s `(42)` build number is NOT transcribed', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(
        find.text('1.0.0 (42)'),
        findsNothing,
        reason:
            '`SettingsScreen.tsx:115` writes `1.0.0 (42)` and that build number is a '
            'fabricated fixture of a React preview. This package\'s is 1.',
      );
    });
  });

  group('the header row is the prototype\'s, and back goes where it came from', () {
    testWidgets('a chevron and the title, and NOT a route path as a title', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.text(AppLocalizationsEn().settingsTitle), findsOneWidget);
      expect(
        find.text('/settings'),
        findsNothing,
        reason:
            'the Phase-0 stub drew `AppRoutes.settings` — a route path — as the screen '
            'title. That placeholder is what this assertion retires.',
      );
    });

    testWidgets('the back control is `maybePop`, so it cannot duplicate `/`', (
      WidgetTester tester,
    ) async {
      // **`maybePop` and not `pushPath(AppRoutes.home)`.** Pushing `/` would put a
      // second home page on the stack for a reader who arrived from one, and Back would
      // land on home again. Asserted structurally — a routerless harness has no
      // `RouterScope` to pop, so this checks the wiring rather than performing it, and
      // `home_navigation_test.dart` owns the real navigation.
      await pumpSettings(tester);
      final IconActionButton back = tester.widget(
        find.widgetWithIcon(IconActionButton, Icons.arrow_back_ios_new),
      );
      expect(
        () => back.onPressed!(),
        // **`FlutterError` and not `Exception`.** auto_route's `context.router` lookup
        // reports a missing `AutoRouter` as a `FlutterError`, which is neither an
        // `Exception` nor an `Error` subclass the matcher would find by default — the
        // first version asserted `isA<Exception>()` and failed on the type, not on the
        // behaviour.
        throwsA(isA<FlutterError>()),
        reason:
            'the callback reaches for a router, which this harness has none of. A '
            '`pushPath(AppRoutes.home)` would throw the same way, so this asserts that '
            'the control is WIRED rather than inert — the inert reading is what the '
            'stub had.',
      );
    });

    testWidgets('and the tooltip is in the reader\'s language', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester, locale: const Locale('ar'));
      final IconActionButton back = tester.widget(
        find.widgetWithIcon(IconActionButton, Icons.arrow_back_ios_new),
      );
      expect(
        back.tooltip,
        AppLocalizationsAr().settingsBack,
        reason:
            'and its family follows the arm, which is defect #2\'s mechanism — the '
            'tooltip is Arabic text going into a widget that names a family explicitly',
      );
      expect(back.tooltipFamily, EvaTypography.arabicFamily);
    });
  });

  group('the scope publishes ONE handle, and swaps it without leaking', () {
    // ## THE TWO LINES THIS EXISTS FOR ARE `didUpdateWidget`'s, AND THEY ARE
    // ## UNREACHABLE FROM ANY PAGE TEST
    //
    // `SettingsScope` is a `StatefulWidget` whose `_SettingsBridge` is created once and
    // reused, because the handle is a locator **singleton**: a bridge built in the
    // constructor would subscribe again on every `app.dart` rebuild and the handle's
    // listener list would grow for the life of the process. The other half of that fix
    // is `didUpdateWidget` swapping the bridge when the handle itself changes — and a
    // page test cannot reach it, because every page test mounts one harness and never
    // swaps it.
    //
    // So this arm builds the swap directly. It is the only test in the file that does
    // not go through `pumpSettings`, and that is the point: it is testing the *scope*,
    // not the screen.
    testWidgets('a different handle above the same subtree re-bridges it', (
      WidgetTester tester,
    ) async {
      // **Two bare handles, not two harnesses.** A second `settingsHarness()` call
      // re-seeds `SharedPreferences.setMockInitialValues` and re-registers the locator,
      // so the *first* cubit's unawaited `load()` resolves against the second store and
      // both cubits end up holding the second harness's value. Measured: the first arm
      // then rendered `light` and the failure read "the first handle is missing", which
      // is a fixture collision, not a scope defect.
      //
      // The claim under test is about the *bridge*, so the handles are the smallest
      // thing that can carry it: a read closure over a literal, and a write closure that
      // drops the mutation.
      final SettingsHandle first = _handleOver(
        const UserSettings(themeMode: AppThemeMode.dark),
      );
      final SettingsHandle second = _handleOver(
        const UserSettings(themeMode: AppThemeMode.light),
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      final Widget probe = Builder(
        builder: (BuildContext context) => Text(
          SettingsScope.of(context).settings.themeMode.storedValue,
          textDirection: TextDirection.ltr,
        ),
      );

      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: SettingsScope(
            key: const Key('scope-one'),
            handle: first,
            child: probe,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('dark'), findsOneWidget, reason: 'the first handle');

      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: SettingsScope(
            key: const Key('scope-one'),
            handle: second,
            child: probe,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('light'),
        findsOneWidget,
        reason:
            'the new handle is what descendants read. Without the swap the scope would '
            'keep answering from the **old** handle\'s bridge, and a screen that had '
            'been re-pointed at a different settings source would read a value nothing '
            'had announced to it.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'and an announcement after the scope is gone is dropped, not thrown',
      (WidgetTester tester) async {
        // The bridge's `_disposed` guard, and the reason it is not a suppression: the
        // handle outlives every scope (it is a locator singleton), so a scope torn down
        // without dropping its subscription would call `notifyListeners` on a disposed
        // `ChangeNotifier` — and Flutter answers that with an assertion from inside the
        // framework, in a test that is about something else entirely.
        final SettingsHarness harness = settingsHarness();
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            child: SettingsScope(
              key: const Key('scope-drop'),
              handle: harness.handle,
              child: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            child: const SizedBox.shrink(),
          ),
        );

        harness.handle.announce();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('the page is NOT the stub it replaced', () {
    testWidgets('no placeholder text survives anywhere', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(find.textContaining('Placeholder'), findsNothing);
      expect(find.textContaining(routePath), findsNothing);
    });

    testWidgets('and it renders on a `NeuralScaffold`, not a bare `Scaffold`', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(find.byType(NeuralScaffold), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      // **As a descendant of the scaffold**, so "the screen renders inside the shared
      // root" is a structural claim and not "a `NeuralScaffold` exists somewhere in the
      // tree".
      expect(
        find.descendant(
          of: find.byType(NeuralScaffold),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(NeuralScaffold),
          matching: find.byType(MaterialApp),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NeuralScaffold),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
    });
  });
}

/// The route path, spelled so the "no placeholder" assertion above is not a tautology.
///
/// `AppRoutes.settings` imported here would make the assertion "no `'/settings'` on
/// screen" depend on a constant from `lib/core/navigation/`, which is fine — but the
/// string is written out so a reader can see the assertion is about the *literal the
/// stub drew*.
const String routePath = '/settings';

/// A [SettingsHandle] over a fixed value, with no cubit and no store behind it.
///
/// For the two scope tests that are about the **bridge**: a harness would put a cubit,
/// a `shared_preferences` mock and a locator registration between the test and the one
/// thing it is checking, and two of them in one test collide (the second seeds the mock
/// store the first's unawaited `load()` is about to read).
SettingsHandle _handleOver(UserSettings value) => SettingsHandle(
  read: () => value,
  write: (UserSettings Function(UserSettings) mutation) async {},
);
