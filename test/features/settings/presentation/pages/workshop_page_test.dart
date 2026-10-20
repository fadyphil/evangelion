// `CurtainShape` is hidden from the barrel because the design system has one
// too — `NeuralScaffold`'s scrim ramp — and this screen's is the aurora's.
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_restore_toast.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/settings_harness.dart';

/// `/settings` — the Workshop.
///
/// ## WHAT THIS FILE IS, AND WHAT IT IS **NOT**
///
/// It is the **smoke test** for a screen with thirty-three rows, and it answers
/// three questions that a per-widget test cannot:
///
/// 1. does the page **build** — every row's control is a real widget, and a
///    screen this size fails at the first missing API rather than at the first
///    interesting assertion;
/// 2. do the rows **write**, through the cubit, and does the page re-read what
///    they wrote;
/// 3. does the one row with **local state** — the restore toast — behave.
///
/// **It is not the screen's own suite.** The orchestrator's test wave owns the
/// full screen suite — the §14 sweep, the 1.22×/320px matrix, the golden — and
/// this file is deliberately narrow so that the two do not overlap.
void main() {
  final AppLocalizationsEn strings = AppLocalizationsEn();

  group('the Workshop screen', () {
    // ## IT BUILDS, AND IT BUILDS THE **SEVEN** GROUPS
    //
    // `:645`, `:649`, `:651`, `:666`, `:682`, `:690`, `:696` — and the count is
    // seven because `SettingsGroup`'s own doc says "seven of them" and that is
    // now true of this screen.
    testWidgets('it shows the seven group headers', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      for (final String label in <String>[
        strings.settingsWsLang,
        strings.settingsThemeGroup,
        strings.settingsWsLight,
        strings.settingsSkyGroup,
        strings.settingsRitualGroup,
        strings.settingsCommunionGroup,
        strings.settingsAbout,
      ]) {
        expect(
          find.text(label.toUpperCase()),
          findsOneWidget,
          reason: 'the group header "$label"',
        );
      }
    });

    // ## AND THE TITLE
    testWidgets('its title is the Workshop', (WidgetTester tester) async {
      await pumpSettings(tester);

      expect(find.text(strings.settingsTitle), findsOneWidget);
    });

    // ## AND THE PREVIEW LINE, IN THE ARM'S OWN SCRIPT
    //
    // `:696` — the prototype's own two literals.
    testWidgets('the preview line reads the arm\'s scripture', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('The Lord is my shepherd…'), findsOneWidget);
    });
  });

  group('the Daylight toggle', () {
    // ## THE **NARROWING**, AND IT IS THE WHOLE OF THE PRODUCT CONSEQUENCE
    //
    // A stored `system` renders the switch **off** and the stored value is
    // **not** changed until the reader touches it — so the `system` arm of
    // `AppThemeMode` becomes unreachable from the UI.
    testWidgets('a stored `system` renders the switch off', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        stored: const UserSettings(themeMode: AppThemeMode.system),
      );

      final SemanticsData node = _toggleNode(tester);
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isFalse);
    });

    // ## AND THE STORED VALUE IS **NOT** CHANGED BY THE RENDERING
    testWidgets('a stored `system` is left alone until it is touched', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(themeMode: AppThemeMode.system),
      );

      expect(cubit.state.settings.themeMode, AppThemeMode.system);
    });

    // ## AND TOUCHING IT NARROWS THE CHOICE TO **LIGHT**
    testWidgets('turning it on writes `light`', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await tester.tap(find.byType(EvaToggle).first);
      await tester.pump();

      expect(cubit.state.settings.themeMode, AppThemeMode.light);
    });

    // ## AND TO **DARK**
    testWidgets('turning it off writes `dark`', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(themeMode: AppThemeMode.light),
      );

      await tester.tap(find.byType(EvaToggle).first);
      await tester.pump();

      expect(cubit.state.settings.themeMode, AppThemeMode.dark);
    });
  });

  group('the rows write', () {
    // ## THE CURTAIN SHAPE — A SEGMENTED ROW
    testWidgets('the curtain shape segment writes the shape', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await tester.ensureVisible(find.text('SHAFTS'));
      await tester.tap(find.text('SHAFTS'));
      await tester.pump();

      expect(cubit.state.settings.curtainShape, CurtainShape.shafts);
    });

    // ## THE UNTRANSLATED LABELS ARE **PAINTED**
    //
    // `eva/redesign.html:673` and `:678` carry no `data-i18n`, so these are the
    // prototype's own English and they are **widget literals**.
    testWidgets('the untranslated segment labels are painted', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('DOT'), findsOneWidget);
      expect(find.text('GEM'), findsOneWidget);
      expect(find.text('CROWN'), findsOneWidget);
      expect(find.text('FULL'), findsOneWidget);
    });

    // ## THE LANGUAGE SEGMENT WRITES THE LANGUAGE
    //
    // The **English** arm's Arabic option is the word "Arabic" — the client's
    // own-script names, and a divergence from `:647`'s raw `العربية`. The
    // control upper-cases every label (`:183`), so it reads "ARABIC".
    testWidgets('the language segment writes the language', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await tester.tap(find.text('ARABIC'));
      await tester.pump();

      expect(cubit.state.settings.language, ReadingLanguage.arabic);
    });

    // ## AND THE ARABIC-NAMED OPTION IS IN THE **ARABIC FACE**, ON THE ENGLISH
    // ## ARM TOO
    //
    // `:186` — `.segp button[data-l=ar]{font-family:var(--ar);…}` — keys the face
    // on the **option** and not on the direction, and
    // `SegmentedControl.labelFamilyOf`'s own doc says so in as many words: "on the
    // **English** arm the Arabic option is still Amiri, because the selector is
    // `data-l=ar`".
    testWidgets('the Arabic-named option is drawn in Amiri', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(_styleOf(tester, find.text('ARABIC')).fontFamily, 'Amiri');

      // …and the English one is in the mono face, which is the control's own.
      expect(
        _styleOf(tester, find.text('ENGLISH')).fontFamily,
        'JetBrainsMono',
      );
    });
  });

  group('every row writes', () {
    // ## WHY THIS GROUP EXISTS
    //
    // The screen's contract is that **twenty-nine controls write**, and the only
    // way to know that is to write with every one of them. A screen this size
    // fails by having a row that renders and does nothing, and a render is not a
    // contract.
    //
    // The table is **by the row's title**, not by index, so a row that moves in
    // the group order does not silently point this test at the wrong control.

    // ## AND THE **SWITCHES**
    final List<(String, bool Function(UserSettings))> switches =
        <(String, bool Function(UserSettings))>[
          ('Aurora engine', (UserSettings s) => s.shaderEnabled),
          ('Multichrome melt', (UserSettings s) => s.multichromeMelt),
          ('Ray combing', (UserSettings s) => s.rayCombing),
          ('White cores', (UserSettings s) => s.whiteCores),
          ('Dot veil', (UserSettings s) => s.dotVeil),
          ('Stars', (UserSettings s) => s.starsOn),
          ('Constellations', (UserSettings s) => s.constellationsOn),
          ('Twinkle', (UserSettings s) => s.twinkle),
          ('Breath guide', (UserSettings s) => s.breathGuide),
          ('Vespers auto-dim', (UserSettings s) => s.vespersAutoDim),
          ('Reduce motion', (UserSettings s) => s.reducedMotion),
          ('Calm motion', (UserSettings s) => s.calmMotion),
          ('Haptics', (UserSettings s) => s.haptics),
          ('Veil witnesses', (UserSettings s) => s.veilWitnesses),
          ('Show podium', (UserSettings s) => s.showPodium),
        ];

    testWidgets('the fifteen switches all write', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      for (final (String title, bool Function(UserSettings) read) in switches) {
        final bool before = read(cubit.state.settings);
        await _tapSwitch(tester, title);
        expect(
          read(cubit.state.settings),
          isNot(before),
          reason: 'the "$title" switch',
        );
      }
    });

    // ## AND THE **SLIDERS**
    final List<(String, int Function(UserSettings))> sliders =
        <(String, int Function(UserSettings))>[
          ('Reach', (UserSettings s) => s.reach),
          ('Brightness', (UserSettings s) => s.glow),
          ('Touch glow', (UserSettings s) => s.touchGlow),
          ('Hue', (UserSettings s) => s.hue),
          ('Star count', (UserSettings s) => s.starCount),
          ('Star brightness', (UserSettings s) => s.starBrightness),
          ('Focus delay', (UserSettings s) => s.focusDelaySec),
          ('Selah length', (UserSettings s) => s.selahLengthSec),
        ];

    testWidgets('the eight sliders all write', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      for (final (String title, int Function(UserSettings) read) in sliders) {
        final int before = read(cubit.state.settings);
        await _dragSlider(tester, title);
        expect(
          read(cubit.state.settings),
          isNot(before),
          reason: 'the "$title" slider',
        );
      }
    });

    // ## AND THE **SEGMENTS**
    testWidgets('the curtain shape segment writes', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await _tapSegment(tester, 'Curtain shape', 'BOTTOM');
      expect(cubit.state.settings.curtainShape, CurtainShape.bottom);
    });

    testWidgets('the star shape segment writes', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await _tapSegment(tester, 'Star shape', 'CROSS');
      expect(cubit.state.settings.starShape, SkyStarShape.cross);
    });

    testWidgets('the star field segment writes', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await _tapSegment(tester, 'Star field', 'FULL');
      expect(cubit.state.settings.starField, SkyStarField.full);
    });

    // ## AND THE **STEPPER**
    testWidgets('the type size stepper writes', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      await _ensureVisible(tester, find.text('Type size'));
      // The stepper's **increase** button, and not the widget's centre — the
      // centre is the track, and the track is not a control.
      await tester.tap(
        find
            .descendant(
              of: find.byType(FontSizeStepper),
              matching: find.byType(IconActionButton),
            )
            .last,
      );
      await tester.pump();

      expect(cubit.state.settings.fontStep, isNot(3));
    });
  });

  group('the failure notice', () {
    // ## THE NOTICE IS ABOVE THE GROUPS, AND THE GROUPS ARE STILL THERE
    //
    // `_SettingsFailureNotice`'s own doc gives the three measured reasons it is
    // a notice and not an `ErrorView`; this is the assertion that it appears at
    // all, and that the screen it failed to load is still on screen underneath.
    testWidgets('a failed read puts the notice on screen and keeps the groups', (
      WidgetTester tester,
    ) async {
      const Failure failure = Failure(
        kind: FailureKind.storage,
        message: 'the preferences could not be reached',
      );
      final SettingsCubit cubit = SettingsCubit(
        getSettings: const GetSettings(FailingSettingsRepository(failure)),
        updateSettings: const UpdateSettings(
          FailingSettingsRepository(failure),
        ),
      );
      addTearDown(cubit.close);

      await pumpSettings(tester, cubit: cubit);
      await pumpSettingsFrames(tester, 4);

      expect(cubit.state.status, SettingsStatus.failed);
      expect(find.text(strings.settingsPreferencesUnavailable), findsOneWidget);
      // The groups are still there: a failed read does not replace the screen.
      expect(find.text(strings.settingsWsLight.toUpperCase()), findsOneWidget);
    });
  });

  group('the restore action', () {
    // ## IT RESETS THE **LIGHT** PREFERENCES
    testWidgets('it restores the light workshop', (WidgetTester tester) async {
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(shaderEnabled: false, reach: 100),
      );

      await tester.ensureVisible(find.text(strings.settingsRestoreDefaults));
      await tester.tap(find.text(strings.settingsRestoreDefaults));
      await tester.pump();

      expect(cubit.state.settings.shaderEnabled, isTrue);
      expect(cubit.state.settings.reach, 42);
    });

    // ## AND IT RAISES THE **TOAST**
    testWidgets('it raises the confirmation toast', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.byType(WorkshopRestoreToast), findsNothing);

      await tester.ensureVisible(find.text(strings.settingsRestoreDefaults));
      await tester.tap(find.text(strings.settingsRestoreDefaults));
      await tester.pump();

      expect(find.byType(WorkshopRestoreToast), findsOneWidget);
      expect(find.text(strings.settingsRestored), findsOneWidget);
    });

    // ## AND THE TOAST GOES AWAY AFTER **1800ms**
    //
    // `:1393` — `setTimeout(…, 1800)`.
    testWidgets('the toast goes away after 1800ms', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      await tester.ensureVisible(find.text(strings.settingsRestoreDefaults));
      await tester.tap(find.text(strings.settingsRestoreDefaults));
      await tester.pump();
      expect(find.byType(WorkshopRestoreToast), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();

      expect(find.byType(WorkshopRestoreToast), findsNothing);
    });
  });
}

/// Scrolls [finder] into view and taps it.
Future<void> _tapSwitch(WidgetTester tester, String title) async {
  final Finder row = find.ancestor(
    of: find.text(title),
    matching: find.byType(SettingsTile),
  );
  await _ensureVisible(tester, find.text(title));
  await tester.tap(find.descendant(of: row, matching: find.byType(EvaToggle)));
  await tester.pump();
}

/// Scrolls [finder] into view and drags the slider it is in.
Future<void> _dragSlider(WidgetTester tester, String title) async {
  final Finder row = find.ancestor(
    of: find.text(title),
    matching: find.byType(SettingsTile),
  );
  await _ensureVisible(tester, find.text(title));
  await tester.drag(
    find.descendant(of: row, matching: find.byType(EvaRangeSlider)),
    // 60px, and not 20: `WidgetController.drag`'s own slop is
    // `kDragSlopDefault` (20), and a drag that does not clear it is not a drag
    // the recognizer accepts — so a 20px drag is silently nothing.
    const Offset(60, 0),
  );
  await tester.pump();
}

/// Scrolls [finder] into view and taps the segment labelled [label].
Future<void> _tapSegment(
  WidgetTester tester,
  String title,
  String label,
) async {
  final Finder row = find.ancestor(
    of: find.text(title),
    matching: find.byType(SettingsTile),
  );
  await _ensureVisible(tester, find.text(title));
  await tester.tap(find.descendant(of: row, matching: find.text(label)));
  await tester.pump();
}

/// Scrolls [finder] into view.
Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// The **effective** style of the text at [finder].
///
/// ## WHY IT IS NOT `tester.widget<Text>(…).style`
///
/// `SegmentedControl` puts its style on an `AnimatedDefaultTextStyle` and not on
/// the `Text` — and it does so for a measured reason: an explicit `Text.style`
/// wins over the ambient default, so a style on the `Text` would make the
/// colour snap instead of transitioning. So the style a reader sees is the
/// **ambient** one, and a test that reads `Text.style` reads `null`.
TextStyle _styleOf(WidgetTester tester, Finder finder) {
  final Text text = tester.widget<Text>(finder);
  final BuildContext context = tester.element(finder);
  return DefaultTextStyle.of(context).style.merge(text.style);
}

/// The first switch's semantics node.
///
/// `getSemantics` and not a walk, because the question here is "what does THIS
/// switch announce", and the finder names the switch.
SemanticsData _toggleNode(WidgetTester tester) =>
    tester.getSemantics(find.byType(EvaToggle).first).getSemanticsData();
