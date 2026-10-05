import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/settings_harness.dart';

/// §14: *"text scales to 1.22× without overflow at 320px width"* — for `/settings`.
///
/// ## WHY THIS SUITE EXISTS AND IT IS A **GAP**, NOT A DUPLICATE
///
/// §14's sentence is about **every** screen that renders text, and five of the six had
/// a `*_text_scale_test.dart` before Phase 10: `login`, `/` (`home`), `/reading`,
/// `/quiz` and `/result`. `/settings` had **none**, which is the worst possible screen
/// to be the exception — it is the one with **four** text-bearing controls in one place
/// (`SegmentedControl`'s three uppercase labels, `FontSizeStepper`'s two `A` buttons and
/// its track, `EvaToggle`'s state name and `SettingsTile`'s five row titles), it is the
/// only screen whose root **scrolls** (`SettingsScreen.tsx:36`'s `overflowY: 'auto'`,
/// and `NeuralScaffold`'s doc names it as one of the three screens whose root scrolls),
/// and it is the screen the reader opens specifically to change text size.
///
/// The numbers are §14's and are read from `design_system_harness.dart` rather than
/// restated, so this file cannot drift from the five that already assert the same
/// requirement — which is `home_text_scale_test.dart`'s stated reason for reading
/// `kNarrowSurface` and `kEvaRequiredTextScale` instead of writing them.
///
/// ## EVERY STATE IS MOUNTED, AND THE **SHEET** IS ONE OF THEM
///
/// `reading_text_scale_test.dart` gives the argument: loading, ready, failed, Arabic and
/// a disclosed control all lay out differently, and the states with the most text are
/// the ones that wrap. `/settings` has three — ready, the Phase-10 failure notice, and
/// the Arabic arm — plus one that is not a state at all and is the most likely of all to
/// overflow: **the language bottom sheet**, which is a `ModalBottomSheet` over the
/// screen at 1.22×, holding two rows and a heading, and which nothing else in the suite
/// opens at 320.
///
/// ## AND THE **SCROLL** IS NOT AN OVERFLOW
///
/// `/settings` is a scrolling screen, so at 320×568 with 1.22× the content is taller
/// than the viewport and that is correct — `result_text_scale_test.dart` has the test
/// that says so ("the column SCROLLS, because 844 does not fit in 568"). The requirement
/// is that nothing overflows *horizontally*, or vertically inside a box that does not
/// scroll. `expectNoOverflow` asks the framework, which knows the difference, and the
/// `find.byType(Scrollable)` assertion below is what stops "it scrolled" being read as
/// "it fit".
void main() {
  /// The surface and the scale, named so a failure reads as §14's own words.
  const Size surface = kNarrowSurface;
  const double scale = kEvaRequiredTextScale;

  group('at 320x568 and 1.22x, no state overflows', () {
    testWidgets('ready', (WidgetTester tester) async {
      await pumpSettings(tester, size: surface, textScale: scale);

      // The anti-vacuity half: the screen must be **on screen**, or "no overflow" is a
      // statement about an empty tree. Three controls, because three of the four kinds
      // of text on this screen are on it.
      expect(find.byType(SegmentedControl<AppThemeMode>), findsOneWidget);
      expect(find.byType(FontSizeStepper), findsOneWidget);
      expect(find.byType(EvaToggle), findsOneWidget);
      expect(
        find.byType(SettingsGroup),
        findsNWidgets(3),
        reason:
            'all three groups, because a group that failed to lay out would take '
            'its children with it',
      );
      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / ready / 320x568 @ 1.22x',
      );
    });

    testWidgets('the failure notice, whose sentence wraps to two lines', (
      WidgetTester tester,
    ) async {
      // **The state Phase 10 added**, and the one whose whole reason for existing is
      // that it is an inline `Row` holding a sentence beside an icon and a button. A
      // `Row` of three children at 1.22× on a 320px screen is the most overflow-prone
      // thing this screen has — and it **did** overflow by 94 pixels during
      // development, which is what `viewport_matrix_test.dart`'s mutation reproduces.
      await pumpSettings(
        tester,
        cubit: unreachableStore(),
        size: surface,
        textScale: scale,
      );

      expect(
        find.text(AppLocalizationsEn().settingsPreferencesUnavailable),
        findsOneWidget,
        reason:
            'the notice has to be on screen, or this state is the ready state '
            'with extra steps',
      );
      expect(find.byType(EvaButton), findsOneWidget);
      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / the failure notice / 320x568 @ 1.22x',
      );
    });

    testWidgets('the Arabic arm — longer words and a taller script', (
      WidgetTester tester,
    ) async {
      // The same argument `reading_text_scale_test.dart` makes for its Arabic arm:
      // Arabic is *taller* at the same point size, and this screen's own strings are
      // longer in Arabic than in English for the same fact. `settingsLanguageSheetTitle`
      // is the worst of them — an instruction, in the sheet's heading.
      await pumpSettings(
        tester,
        size: surface,
        textScale: scale,
        locale: const Locale('ar'),
      );

      // **The row reports the AMBIENT arm, not the stored one.** The trailing text is
      // `languageLabelFor(selectedLanguageOf(context))`, and `selectedLanguageOf` reads
      // the locale the app is *rendering* in — so on the Arabic arm the row correctly
      // says `العربية` even though nothing was ever stored. The first version of this
      // test asserted `الإنجليزية` and failed with `Found 0 widgets with text
      // "الإنجليزية"`, and the row was right: an app rendering in Arabic has Arabic in
      // force.
      expect(
        find.text(
          AppLocalizationsAr().languageLabelFor(ReadingLanguage.arabic),
        ),
        findsOneWidget,
        reason: 'the language row\'s current value is on screen in Arabic',
      );
      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / the Arabic arm / 320x568 @ 1.22x',
      );
    });

    testWidgets('and the LANGUAGE SHEET open over it', (
      WidgetTester tester,
    ) async {
      // The one that is not a state, and the most likely of all to overflow: a modal
      // sheet at 320 wide, at 1.22×, holding a heading and two rows of a label and a
      // name. Nothing else in the suite opens it at 320.
      await pumpSettings(tester, size: surface, textScale: scale);

      await tester.tap(find.text(AppLocalizationsEn().settingsDefaultLanguage));
      await tester.pumpAndSettle();

      // Anti-vacuity: the sheet is up. Asserting "no overflow" with the sheet closed
      // would be a statement about the screen underneath it.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settingsLanguageSheetTitle),
        findsOneWidget,
      );
      // **Scoped to the sheet, and that is the fix rather than a loosening.** The
      // language row on the page *behind* the sheet renders the same two names — it is
      // a fact about the current value, and the sheet repeats them as its two choices
      // — so an unscoped `find.text('English')` found **two** widgets and
      // `findsOneWidget` failed, while saying nothing about the sheet this test is
      // about. `findsAtLeastNWidgets(1)` would have gone green and answered nothing.
      for (final ReadingLanguage language in ReadingLanguage.values) {
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(
              AppLocalizationsEn().languageLabelFor(language),
            ),
          ),
          findsOneWidget,
          reason:
              'both rows are on screen — a sheet that silently dropped one would '
              'still pass "no overflow"',
        );
      }

      expectNoOverflow(
        tester,
        somethingRendered: () => find.byType(BottomSheet).evaluate().isNotEmpty,
        surface: '/settings / the language sheet open / 320x568 @ 1.22x',
      );
    });

    testWidgets('and the sheet open on the Arabic arm', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        size: surface,
        textScale: scale,
        locale: const Locale('ar'),
      );

      await tester.tap(find.text(AppLocalizationsAr().settingsDefaultLanguage));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text(AppLocalizationsAr().settingsLanguageSheetTitle),
        findsOneWidget,
      );
      // **Both arms, both rows.** `settingsLanguageEnglish` is the value whose
      // transliteration this repository argues about in three places — see its ARB
      // description — and it is the longest string in this sheet.
      for (final ReadingLanguage language in ReadingLanguage.values) {
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(
              AppLocalizationsAr().languageLabelFor(language),
            ),
          ),
          findsOneWidget,
          reason: 'scoped to the sheet, for the reason the English arm gives',
        );
      }

      expectNoOverflow(
        tester,
        somethingRendered: () => find.byType(BottomSheet).evaluate().isNotEmpty,
        surface: '/settings / the language sheet, Arabic / 320x568 @ 1.22x',
      );
    });
  });

  group('the screen SCROLLS rather than fitting, and that is not an overflow', () {
    testWidgets(
      'at 1.22x on 568 tall, the content is taller than the viewport',
      (WidgetTester tester) async {
        // ## WHY THIS IS ASSERTED AND NOT LEFT IMPLICIT
        //
        // §14 requires no **overflow**, and a scrolling screen meets that requirement by
        // scrolling. Without this assertion, "the page fits" and "the page scrolls" are
        // the same green tick, and a future edit that removed the scroll would turn this
        // file into a statement that 1.22× fits in 568 — which `result_text_scale_test
        // .dart`'s sibling test shows it does not.
        await pumpSettings(tester, size: surface, textScale: scale);

        expect(
          find.byType(Scrollable),
          findsWidgets,
          reason:
              '`SettingsScreen.tsx:36` puts `overflowY: auto` on the ROOT, and '
              '`NeuralScaffold`\'s doc names `/settings` as one of the three screens '
              'whose root scrolls. A screen that stopped scrolling would be able to hold '
              '1.22x in 568 only by not showing all three groups.',
        );
        expect(find.byType(SettingsGroup), findsNWidgets(3));
        expectNoOverflow(
          tester,
          somethingRendered: () =>
              find.byType(SettingsPage).evaluate().isNotEmpty,
          surface: '/settings / scrolling, not overflowing / 320x568 @ 1.22x',
        );
      },
    );
  });
}

/// A cubit over a store that cannot be reached, for the failure-notice state.
///
/// **A copy of the one in `settings_page_test.dart` and the one in
/// `settings_accessibility_test.dart`, and that is a deliberate cost stated here
/// rather than an oversight.** Two files already needed it; this is the third, and
/// hoisting it into `settings_harness.dart` would give a shared failure a *shared*
/// name — `FailingSettingsRepository` is already there — but the three uses differ in
/// what they assert afterwards: the page suite drives the write arm and the retry, the
/// accessibility suite sweeps the tree, and this one only needs the notice rendered at
/// 1.22×. A three-line factory over an already-shared fake is cheaper than one factory
/// whose contract is "and also do the other thing".
SettingsCubit unreachableStore() {
  const Failure failure = Failure(
    kind: FailureKind.storage,
    message:
        'the preferences could not be reached: '
        'MissingPluginException(No implementation found)',
  );
  final SettingsCubit cubit = SettingsCubit(
    getSettings: const GetSettings(FailingSettingsRepository(failure)),
    updateSettings: const UpdateSettings(FailingSettingsRepository(failure)),
  );
  addTearDown(cubit.close);
  return cubit;
}
