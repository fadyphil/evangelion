import 'dart:ui' show Tristate;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/settings_harness.dart';

/// §14 for `/settings`: no unlabeled interactive node, a focus ring on everything a
/// keyboard can reach, and no state carried by colour alone.
///
/// ## WHY THIS FILE EXISTS
///
/// `09-quality-gates.md` §14's target is "all 6 pages pass a semantics sweep with no
/// unlabeled interactive node". `login`, `/`, `/reading`, `/quiz` and `/result` each
/// have a `*_accessibility_test.dart` whose first group is that sweep over the page's
/// whole semantics tree. `/settings` had **no** such file after Phase 9 — five of six
/// pages, and the sentence could not be claimed for the app.
///
/// ## AND THIS IS THE PAGE WHERE §14'S ROWS ARE HARDEST, BECAUSE EVERY ROW HAS A
/// ## CONTROL ON IT
///
/// The other five screens have one or two controls this design system owns.
/// `/settings` has **four distinct interactive widgets** from `core/design_system/` —
/// `SegmentedControl`, `FontSizeStepper` (three `IconActionButton`s and a slider
/// track), `EvaToggle` and `SettingsTile`'s own row button — and `focus_ring_gate_test.dart`'s
/// source walk covers `lib/core/design_system/widgets/` only, so it confirms each of
/// those widgets is sound and says nothing about whether `/settings` **composed** them
/// into named, focusable, correctly-labelled controls.
///
/// `login_accessibility_test.dart` states the same argument for `/login`'s two
/// feature-owned controls; this is the same gap with four design-system ones.
///
/// ## AND THE `already_answered`-STYLE ROWS DO NOT APPLY HERE
///
/// Recorded rather than left for a reader to assume: `/settings` has **no disabled
/// control** and **no spoiler**, because it has no state machine a reader can be
/// caught out by — the language row is always live, the theme track always has a
/// selection, the stepper is always in range. The states that *do* exist are
/// `SettingsStatus.loading` (never rendered — the screen shows the defaults, which is
/// the same tree) and `SettingsStatus.failed` (Phase 10's notice, swept below).
void main() {
  final AppLocalizations strings = AppLocalizationsEn();

  group('no unlabeled interactive node', () {
    testWidgets('the ready screen, every control named', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      final List<SemanticsData> tappable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );

      expect(
        tappable,
        isNotEmpty,
        reason:
            'the screen has a back button, a theme track, two stepper buttons, a '
            'motion switch and a language row; an empty list means the walk saw '
            'nothing and everything below would be vacuously true',
      );
      for (final SemanticsData node in tappable) {
        expect(
          node.label.trim(),
          isNotEmpty,
          reason:
              'an interactive node with no accessible name. §14\'s first row. '
              'flags=${node.flagsCollection} actions=${node.actions}',
        );
      }

      handle.dispose();
    });

    testWidgets('and the failed state, whose notice adds a control', (
      WidgetTester tester,
    ) async {
      // Swept as its own test rather than folded into the one above for the reason
      // `home_accessibility_test.dart` records: one looping test names a *state* in
      // prose and a *line* that is the same for all of them, so an empty node list
      // cannot say which state produced it. An error view is also exactly where a
      // label goes missing — Phase 10's notice is a new control and a new label, and
      // this is what holds it.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, cubit: _unreachableStore());

      final List<SemanticsData> tappable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );
      expect(tappable, isNotEmpty);
      for (final SemanticsData node in tappable) {
        expect(
          node.label.trim(),
          isNotEmpty,
          reason:
              'the notice added a button and a sentence, and one of them is a new '
              'control on this screen. §14\'s first row.',
        );
      }

      handle.dispose();
    });

    testWidgets('and the Arabic arm', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, locale: const Locale('ar'));

      for (final SemanticsData node in nodesOffering(
        tester,
        SemanticsAction.tap,
      )) {
        expect(
          node.label.trim(),
          isNotEmpty,
          reason: 'the same sweep on the arm whose script differs',
        );
      }

      handle.dispose();
    });

    testWidgets('the named controls are the ones the screen draws', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      // **Enumerated, not "some of them."** §14's gap is an *unnamed* control, and a
      // label that drifted off the control it names is the same defect one step later
      // — which is what `settingsFontScale` versus `settingsFontSize` is about, two
      // names for two nodes on this very screen.
      expect(find.bySemanticsLabel(strings.settingsBack), findsOneWidget);

      // **Nodes, not widgets.** `find.bySemanticsLabel` returns *widgets*, and one
      // `SemanticsNode` can be contributed to by several — so `findsOneWidget` on it
      // answers "how many widgets carry this label", which is not the question. The
      // sweep's own currency is `SemanticsData`, and the rest of this group uses it.
      //
      // It is not a hypothetical: `settingsTitle` matched **two** widgets for one
      // node, and a draft of this test asserted `findsOneWidget` on all eight labels
      // and failed on the title with `Found 2 widgets with a semantics label
      // matching the pattern` — a failure about `find`, not about the screen.
      int nodesNamed(String label) =>
          semanticsTree(tester)
              .where((SemanticsData node) => node.label.trim() == label)
              .length;

      expect(nodesNamed(strings.settingsTitle), 1);

      // The theme track: three segments, each a button, each named **once**.
      //
      // And the track itself — a fourth activatable node — named for the control
      // rather than for one of its options. Both halves are
      // `SegmentedControl.semanticLabel`'s subject; the second is the assertion that
      // holds it, since a track named "Dark" is a second activatable "Dark" here.
      for (final String mode in <String>[
        strings.settingsThemeLight,
        strings.settingsThemeDark,
        strings.settingsThemeSystem,
      ]) {
        expect(
          nodesNamed(mode),
          1,
          reason:
              'a segment is a control, §14 asks it to be named, and one name must '
              'not describe two activatable nodes — the `readingTextSize` defect',
        );
      }
      expect(
        nodesNamed(strings.settingsTheme),
        1,
        reason:
            'and the track is named for the control. It was named for the SELECTED '
            'VALUE until Phase 10, which put two activatable nodes on this screen '
            'with the label "Dark" — measured, and the reason '
            '`SegmentedControl.semanticLabel` exists.',
      );

      // The stepper: three labels for three nodes — the track is the SLIDER and the
      // two buttons are buttons. One string for all three would be the
      // `readingTextSize` defect, and the ARB deliberately gives the track its own
      // (`settingsFontScale`).
      expect(
        find.bySemanticsLabel(strings.settingsFontScale),
        findsOneWidget,
        reason: 'the slider track is its own node and its own name',
      );
      expect(
        find.bySemanticsLabel(strings.settingsDecreaseFontSize),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(strings.settingsIncreaseFontSize),
        findsOneWidget,
      );

      // The motion switch, on **its own localised label** rather than the English
      // `On`/`Off` that `EvaToggle` used to hard-code for six phases.
      // **The English arm's `settingsMotionOff` is literally `"Off"`**, so asserting
      // `findsNothing` for the string `'Off'` here would be asserting the screen is
      // broken — and it did, with `Found 1 widget with a semantics label named
      // "Off"`. The hard-coded-English regression can only be asked on the Arabic
      // arm, and it is asked there, in the last group. This is the positive claim: the
      // switch is named by the ARB, which on this arm is "Off".
      expect(nodesNamed(strings.settingsMotionOff), 1);

      // The language row. **`contains`, not equality** — and the reason is
      // `SettingsTile`'s own recorded decision: the row keeps `excludeSemantics:
      // false` so a nested control survives, which means the trailing text is
      // announced **inside** the row's name. Measured before Phase 10 and after:
      //
      // ```text
      // lbl="Default language|Default language|English"   <- the title twice
      // lbl="Default language|English"                    <- the title once
      // ```
      //
      // and the first version of this assertion, `findsOneWidget` on
      // `bySemanticsLabel('Default language')`, failed with `Found 0 widgets` —
      // because the label is no longer *equal* to the row title, and
      // `bySemanticsLabel` with a plain String is an equality test.
      expect(
        semanticsTree(tester).where(
          (SemanticsData node) =>
              node.label.trim().startsWith(strings.settingsDefaultLanguage) &&
              node.hasAction(SemanticsAction.tap),
        ),
        hasLength(1),
        reason:
            'exactly one activatable node is named for the language row, and its name '
            'begins with the row\'s own title',
      );

      handle.dispose();
    });
  });

  group('§14 — a choice is announced as a choice', () {
    testWidgets(
      'the theme track carries `selected`, so the answer is knowable',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpSettings(
          tester,
          stored: const UserSettings(themeMode: AppThemeMode.light),
        );

        // **Filtered on the three segment labels, by name.** The earlier filter was
        // `label.contains(settingsTheme)` and it found nothing, for the measured
        // reason `SegmentedControl.semanticLabel` documents: until Phase 10 the
        // track was named after the *selected value*, so no node on this screen
        // carried the word "Theme" except the row's painted title. Naming the three
        // options is exact, and cannot drift as the track's name changes.
        final List<String> optionLabels = <String>[
          strings.settingsThemeLight,
          strings.settingsThemeDark,
          strings.settingsThemeSystem,
        ];
        final Iterable<SemanticsData> segments = semanticsTree(tester).where(
          (SemanticsData node) => optionLabels.contains(node.label.trim()),
        );
        expect(
          segments,
          hasLength(3),
          reason:
              'three segments, so a `selected` filter over them is meaningful. Fewer '
              'would make it vacuous; more would mean a duplicate name.',
        );

        // **A `Tristate` and not a `bool`** — `SemanticsFlags.isSelected` is tri-state
        // in Flutter 3.47, so `isTrue` is an identity check against `Tristate.isTrue`
        // that reads as a boolean assertion and is not one. `settings_page_test.dart`
        // records the same for the language sheet's rows.
        final Iterable<SemanticsData> chosen = segments.where(
          (SemanticsData node) =>
              node.flagsCollection.isSelected == Tristate.isTrue,
        );
        expect(
          chosen,
          hasLength(1),
          reason:
              'exactly one segment is the reader\'s current palette. Three colours in a '
              'row with no `selected` is §14\'s colour-only row applied to a picker, and '
              'it is the same row the language sheet\'s rows answer.',
        );
        expect(chosen.single.label, contains(strings.settingsThemeLight));

        handle.dispose();
      },
    );

    testWidgets('the language row announces the language that is in force', (
      WidgetTester tester,
    ) async {
      // The row is inverted relative to a settings row: `onTap` is on the **row** and
      // the trailing `Text` is a **fact** (which language is current), not a target.
      // §14's requirement is that the reader can tell what the answer is, and a fact
      // announced as a fact is what that needs.
      final SemanticsHandle handle = tester.ensureSemantics();
      // **Pumped in the Arabic arm, and that is the whole point.** The row's trailing
      // text is `languageLabelFor(selectedLanguageOf(context))` — the language the
      // app is *rendering* in, which is the ambient locale, not the stored setting.
      // The first version of this test stored `language: arabic`, pumped `locale: en`
      // and asserted the row said "Arabic"; it failed with
      // `Expected: contains 'Arabic' / Actual: 'Default language\n'` — and the row
      // was **right**, because the app was rendering in English. A stored setting the
      // app has not applied yet is exactly the state the first frame of a launch is
      // in, so the row reporting the ambient arm is the correct behaviour and the test
      // was asking the wrong question.
      await pumpSettings(
        tester,
        stored: const UserSettings(language: ReadingLanguage.arabic),
        locale: const Locale('ar'),
      );

      // **`AppLocalizationsAr()`, not the `strings` this file holds.** The first
      // version looked for `strings.settingsDefaultLanguage` on a page pumped in the
      // Arabic arm and threw `Bad state: No element` — `strings` is the *English* arm,
      // so it was asking an Arabic node to carry an English name. It is the same
      // mistake `arabic_typography_test.dart`'s header warns a reader about in the
      // other direction, and the fix is to read the node's own arm.
      final AppLocalizations ar = AppLocalizationsAr();
      final SemanticsData row = semanticsTree(tester).firstWhere(
        (SemanticsData node) =>
            node.hasAction(SemanticsAction.tap) &&
            node.label.contains(ar.settingsDefaultLanguage),
      );
      expect(row.flagsCollection.isButton, isTrue);
      expect(
        row.label,
        contains(ar.languageLabelFor(ReadingLanguage.arabic)),
        reason:
            'the row\'s name carries the current value as well as the row\'s own '
            'purpose, so a screen-reader user is told what is in force without '
            'opening the sheet. `SettingsPage` inverted this row deliberately — see '
            'its comment — and the inversion is what makes the value belong in the '
            'name.',
      );

      handle.dispose();
    });
  });

  group('reduced motion, and the three controls that animate', () {
    testWidgets('with the flag on, all three animate nothing', (
      WidgetTester tester,
    ) async {
      // `/settings` is the **only** screen that puts three independently-animating
      // controls in one place — `SegmentedControl`'s track, `EvaToggle`'s knob and
      // `EvaButton`'s pressed fill — and all three read
      // `MediaQuery.disableAnimationsOf` themselves. This asserts the flag reaches
      // them through the page rather than trusting three widgets' own suites; the
      // widgets' contracts are `segmented_control_test.dart`'s and `eva_toggle_test.dart`'s.
      await pumpSettings(tester, disableAnimations: true);

      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(SettingsPage)),
        ),
        isTrue,
        reason:
            'the page must sit under the flag it forwards. A harness that dropped '
            'the parameter would render the screen animations are forbidden to run '
            'and every assertion below would be about nothing.',
      );

      final SegmentedControl<AppThemeMode> track = tester.widget(
        find.byType(SegmentedControl<AppThemeMode>),
      );
      expect(
        track.selected,
        AppThemeMode.dark,
        reason: 'sanity: it is on screen',
      );

      // **The durations, not a screenshot.** Each widget collapses its own duration to
      // zero when the flag is set, so the observable difference is that a second pump
      // reaches the same state. Asserting `find.byType(EvaToggle)` and the stepper are
      // on screen is the anti-vacuity half: a screen with no controls has nothing to
      // animate.
      expect(find.byType(EvaToggle), findsOneWidget);
      expect(find.byType(FontSizeStepper), findsOneWidget);
    });
  });

  group('the notice, and §14\'s four properties of an error', () {
    testWidgets('it is not colour alone, and it is announced', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, cubit: _unreachableStore());

      // **The glyph, not `colors.err`.** `ErrorView` draws `Icons.error_outline`
      // precisely because a shape that differs from `EmptyState`'s tells the two
      // states apart without colour, and the notice reuses it. If a future edit drops
      // the `Icon` and leaves only the tinted `GlassSurface`, this goes red.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // And the live region carries the sentence — asserted by label, because a live
      // region carrying nothing is the shape that announces nothing.
      expect(
        semanticsTree(tester)
            .where((SemanticsData node) => node.flagsCollection.isLiveRegion)
            .map((SemanticsData node) => node.label),
        contains(strings.settingsPreferencesUnavailable),
      );

      handle.dispose();
    });

    testWidgets('and the Arabic arm names it in Arabic', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(
        tester,
        cubit: _unreachableStore(),
        locale: const Locale('ar'),
      );

      final AppLocalizations ar = AppLocalizationsAr();
      expect(find.text(ar.settingsPreferencesUnavailable), findsOneWidget);
      expect(find.bySemanticsLabel(ar.settingsRetry), findsOneWidget);
      expect(
        find.text(ar.settingsPreferencesUnavailable),
        findsOneWidget,
        reason:
            'and the node\'s name is the Arabic sentence — the Arabic glyph gate walks '
            'the painted tree and a `Semantics` label is not painted, so this is the '
            'half `arabic_typography_test.dart` cannot see.',
      );

      handle.dispose();
    });
  });
}

/// A cubit over a store that cannot be reached, which is the only route to
/// `SettingsStatus.failed`.
///
/// **Built here rather than shared** because `settings_page_test.dart` has the same
/// shape for its own seven tests, and the two differ in what they need: this one only
/// has to *reach* the state for the sweep, where that file also drives the write arm
/// and the retry. One is a fixture; the other is a flow, and folding them together
/// would make the sweep depend on a `load()` the sweep is not about.
SettingsCubit _unreachableStore() {
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
