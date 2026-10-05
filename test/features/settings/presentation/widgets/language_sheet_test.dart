import 'package:evangelion/core/design_system/barrel.dart';
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

/// `language_sheet.dart` — **defect #7**, and the two things the defect was about.
///
/// The defect is `01-source-analysis.md`'s row: "FAB 'Language' item silently does
/// nothing. `screen: null` -> closes the dock, navigates nowhere. Dead-end UI."
///
/// ## THE FAB THIS NAMES **DOES NOT EXIST**, MEASURED
///
/// `rg -i 'sealfab|fabdock' lib test` returns one hit in `lib/` — a doc comment
/// recording that `SealFAB` **is cut** with the profile screen — and four more that are
/// all prose about the cut. `04-widget-inventory.md` section 3 items 27-28 were cut
/// under §2 decision 1. Rebuilding a `SealFab` to host the sheet would re-litigate that
/// decision and put a second blur site on `/`, which `glass_blur_budget_test.dart`
/// holds at one.
///
/// So the dead-end control is gone and the defect's **substance** is what ships: a
/// language control that opens something and then *does the thing*. The two cases below
/// are the substance — a control that opens, and a control that writes.
void main() {
  /// The strings for [locale], so a case can name the row in the reader's own arm.
  ///
  /// A `switch` over the locale rather than a single arm: the two cases that open the
  /// sheet on the Arabic arm have to tap `اللغة الافتراضية`, and tapping the English
  /// spelling there finds nothing.
  AppLocalizations stringsFor(Locale locale) =>
      locale.languageCode == 'ar' ? AppLocalizationsAr() : AppLocalizationsEn();

  /// Pumps `/settings` — the sheet's only call site — over a real settings scope, and
  /// opens the sheet.
  Future<SettingsHarness> pumpAndOpen(
    WidgetTester tester, {
    UserSettings? stored,
    Locale locale = const Locale('en'),
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
    await tester.tap(find.text(stringsFor(locale).settingsDefaultLanguage));
    await tester.pumpAndSettle();
    return harness;
  }

  /// Taps a language **inside the sheet**.
  ///
  /// Scoped to the `BottomSheet` because the settings row's trailing renders the
  /// current language, which on a fresh English install is `English` — the same string
  /// one of the sheet's rows uses. The unscoped finder is ambiguous and the failure
  /// reads as "Found 2 widgets", which says nothing about the screen.
  Future<void> pickInSheet(
    WidgetTester tester,
    ReadingLanguage language,
    Locale locale,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(stringsFor(locale).languageLabelFor(language)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('it is a MODAL BOTTOM SHEET, not an inline disclosure', () {
    testWidgets('the tap opens a `BottomSheet` and changes NOTHING yet', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = await pumpAndOpen(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        harness.cubit.state.settings.language,
        isNull,
        reason:
            'opening persists nothing. A control that fires when a reader only LOOKS at '
            'it is a different defect, and this pins the boundary.',
      );
    });

    testWidgets('and the sheet blurs NOTHING — §13.4 puts `/settings` in tint', (
      WidgetTester tester,
    ) async {
      await pumpAndOpen(tester);

      final List<GlassSurface> surfaces = tester
          .widgetList<GlassSurface>(find.byType(GlassSurface))
          .toList();
      expect(
        surfaces,
        isNotEmpty,
        reason: 'anti-vacuity: there is a surface to be wrong about',
      );
      for (final GlassSurface surface in surfaces) {
        expect(
          surface.tier,
          isNot(GlassTier.blur),
          reason:
              'a `BackdropFilter` is a `saveLayer` plus a full read-back per frame, and '
              '§13.4 permits exactly one in `lib/features/` — which `/` spends',
        );
      }
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('choosing a language WRITES, and that is the whole defect', () {
    testWidgets('picking Arabic writes `ReadingLanguage.arabic`', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = await pumpAndOpen(tester);
      await pickInSheet(tester, ReadingLanguage.arabic, const Locale('en'));

      expect(
        harness.cubit.state.settings.language,
        ReadingLanguage.arabic,
        reason:
            'the WRITE, not the opening. The defect row is "closes the dock, navigates '
            'nowhere", so a sheet that closed without changing anything would be the '
            'same defect one layer down.',
      );
    });

    testWidgets('and it survives a restart, read through the handle', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = await pumpAndOpen(tester);
      await pickInSheet(tester, ReadingLanguage.arabic, const Locale('en'));

      // **Two reads of the same value.** `harness.handle` is a call-through to the
      // cubit, so this is not yet a round trip — it is the second half of the pair, and
      // the disk half is `settings_repository_test.dart`'s four per-field cases. What
      // this file's assertion adds is that the *sheet* is the thing that wrote it: the
      // alternative is a sheet that closes with no write at all.
      expect(harness.handle.settings.language, ReadingLanguage.arabic);
      expect(harness.cubit.state.settings.language, ReadingLanguage.arabic);
    });

    testWidgets('and the sheet is GONE afterwards — a modal, not a page', (
      WidgetTester tester,
    ) async {
      // The harness is pumped and **not** named: this arm is about the sheet being
      // gone, so nothing here reads the store or the cubit. Naming it would be the
      // analyzer's `unused_local_variable`, and silencing that with a leading `_`
      // would hide a real unused fixture in the next arm of this group.
      await pumpAndOpen(tester);
      expect(find.byType(BottomSheet), findsOneWidget);

      await pickInSheet(tester, ReadingLanguage.arabic, const Locale('en'));

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      // **The row still shows `English`, and that is correct in this tree.** Its trailing
      // is `selectedLanguageOf(context)`, which reads the *locale* — and in a bare harness
      // the locale is whatever `evaPrimitiveHarness` was given, because the app-wide
      // `MaterialApp.locale` a write moves lives in `app.dart` and is therefore absent
      // from this tree. Asserting `Arabic` here would assert a wiring that does not
      // exist in the widget under test; `test/app/app_settings_wiring_test.dart` asserts
      // the real propagation against a real `MaterialApp`.
      expect(
        find.text(
          AppLocalizationsEn().languageLabelFor(ReadingLanguage.english),
        ),
        findsOneWidget,
      );
    });
  });

  group('the sheet renders in the READER arm, not the app default', () {
    testWidgets('on the Arabic arm its heading and rows are Arabic', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = await pumpAndOpen(
        tester,
        stored: const UserSettings(language: ReadingLanguage.arabic),
        locale: const Locale('ar'),
      );
      expect(harness.cubit.state.settings.language, ReadingLanguage.arabic);

      expect(
        find.text(AppLocalizationsAr().settingsLanguageSheetTitle),
        findsOneWidget,
        reason: 'the heading is a localised string, not the English one',
      );
      expect(find.text('Choose a language'), findsNothing);
      expect(
        find.text(
          AppLocalizationsAr().languageLabelFor(ReadingLanguage.arabic),
        ),
        findsNWidgets(2),
        reason:
            'twice: the settings row and the sheet row. They must AGREE — a row '
            'showing one language and a picker offering another is the '
            'half-translated screen this app exists not to ship.',
      );
      expect(
        find.text(
          AppLocalizationsAr().languageLabelFor(ReadingLanguage.english),
        ),
        findsOneWidget,
      );
      // **A language names itself in its own script**, so the Arabic arm's English row
      // is `الإنجليزية` and not `English`. `settings_l10n.dart`'s doc states the rule
      // and `app_localizations_test.dart`'s "no English left in the Arabic arm" gate
      // enforces it from the ARB side; this asserts the rendered half.
      expect(find.text('English'), findsNothing);
    });

    testWidgets(
      'and on the English arm the Arabic row is `Arabic`, not `العربية`',
      (WidgetTester tester) async {
        await pumpAndOpen(tester);

        expect(find.text('Arabic'), findsOneWidget);
        expect(
          find.text('العربية'),
          findsNothing,
          reason:
              'the row is named in the arm the sheet opens in. A picker that shows the '
              'other arm spelling would be a sheet that has not been localised at all.',
        );
      },
    );
  });

  group('`selectedLanguageOf`, the answer the row and the sheet share', () {
    testWidgets('it is the RENDERED language, not the stored one', (
      WidgetTester tester,
    ) async {
      // Stored `null` plus an Arabic locale must read as `arabic`, or the row shows an
      // empty selection on a screen that is entirely Arabic.
      // `UserSettings.language`'s doc gives the four-case table.
      final SettingsHarness harness = await pumpAndOpen(
        tester,
        locale: const Locale('ar'),
      );
      expect(harness.cubit.state.settings.language, isNull);
      expect(
        selectedLanguageOf(tester.element(find.byType(SettingsPage))),
        ReadingLanguage.arabic,
      );
    });
  });
}
