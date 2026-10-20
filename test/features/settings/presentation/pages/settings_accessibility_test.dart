import 'dart:ui' show Tristate;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/settings_harness.dart';

/// §14 for `/settings` — **the Workshop**.
///
/// ## WHY THIS FILE EXISTS, AND WHY IT IS NOT THE OLD ONE
///
/// `09-quality-gates.md` §14's target is "all 6 pages pass a semantics sweep with
/// no unlabeled interactive node", and the redesign's `/settings` is the page
/// where that sweep is **hardest**: twenty-nine interactive controls of four
/// different kinds, and every one of them sits on a row whose title the
/// design system's `SettingsTile` **excludes from the semantics tree**
/// (`settings_tile.dart:268`).
///
/// **That exclusion is the whole reason this screen needed a new shape of
/// sweep.** On the Phase-9 screen the row's title was the control's name; on
/// this one the trailing control is the only node that can name its row, so a
/// row whose control forgot to name itself is a row a screen reader reaches and
/// cannot identify. Every one of the twenty-nine therefore has to carry its
/// row's title as its own accessible name.
///
/// ## WHAT CHANGED FROM THE PHASE-9 SWEEP, AND WHY THE OLD ASSERTIONS ARE GONE
///
/// The Phase-9 screen had a **three-segment** theme picker and a language
/// **sheet**, and this suite asserted:
///
/// * the theme track was named "Theme" — **gone**: the theme group holds one
///   control now, the Daylight toggle (`:650`), and the track does not exist;
/// * the switch was named "Off" / "On" — **gone**: `EvaToggle` publishes
///   `Semantics(label: labels.on / labels.off)`, and a name that changes with
///   the state is a **state** name, not a **control** name. Every switch on
///   this screen is now named by its **row title in both arms**, and the state
///   is carried by `Semantics(toggled:)`.
///
/// **Asserting the old names would be asserting a defect.** A suite that
/// expected "Off" would go red on the fix and green on the regression.
///
/// ## AND THE **DUPLICATE-NAME** DEFECT, WHICH IS THE ONE THIS SCREEN CAN STILL
/// ## FALL INTO
///
/// `settings_tile.dart` measures it: **one string describing two focusable,
/// activatable nodes** is a §14 failure in the one place §14 is unambiguous. On
/// this screen the risk is real — sixteen switches and nine sliders are named
/// by their rows' titles, and a row whose title is also a control's name would
/// put the same string on two activatable nodes.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('every control has an accessible name', () {
    // ## THE SWEEP, AND WHY IT IS **NOT** AN ASSERTION ABOUT FLAGS
    //
    // `SemanticsData.hasAction` against the **data**, never against the
    // presence of a `Semantics` widget — `controls_test.dart`'s own header
    // records the measurement: six of the eleven interactive widgets shipped a
    // node a reader could read and could not press, and every committed test
    // passed because they all used `tester.tap()`, which goes through the
    // pointer path.
    testWidgets('every activatable node on the screen is named', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      final List<SemanticsData> activatable = _activatable(tester);
      expect(
        activatable,
        hasLength(greaterThan(40)),
        reason:
            'the screen has twenty-nine controls and a back button, so a walk that '
            'found fewer than forty activatable nodes has seen less than the screen '
            'has. An empty list would make every assertion below vacuously true.',
      );
      for (final SemanticsData node in activatable) {
        expect(
          node.label.trim(),
          isNotEmpty,
          reason:
              'an activatable node with no accessible name. §14\'s first row. '
              'actions=${node.actions}',
        );
      }

      handle.dispose();
    });

    // ## AND THE **ARABIC** ARM, WHERE THE NAMES ARE THE READER'S OWN
    //
    // **The same sweep, on the arm whose script differs.** The names are the
    // ARB's own strings there, so an English name surviving into the Arabic
    // arm would be a defect a length check would not see.
    testWidgets('and the same on the Arabic arm, in the reader\'s own script', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, locale: const Locale('ar'));

      for (final SemanticsData node in _activatable(tester)) {
        expect(
          node.label.trim(),
          isNotEmpty,
          reason: 'the same sweep, in Arabic',
        );

        // **The seven untranslated labels are the exception, and they are
        // named.** `eva/redesign.html:673` and `:678` carry no `data-i18n`, so
        // the prototype's own English is kept — and the brief's D11 says so
        // explicitly. The exclusion is a **list**, not a blanket waiver: every
        // other name on the Arabic arm is Arabic.
        if (_untranslatedSegmentLabels.contains(node.label.trim())) continue;
        expect(
          node.label,
          isNot(matches(RegExp('[A-Za-z]'))),
          reason:
              'the node "${node.label}" carries Latin script on the Arabic arm. '
              'Only the seven untranslated segment labels may, and they are '
              'listed in this file.',
        );
      }

      handle.dispose();
    });

    // ## AND THE **FAILED** STATE, WHOSE NOTICE ADDS A CONTROL
    //
    // Swept as its own test rather than folded into the one above for the
    // reason `home_accessibility_test.dart` records: one looping test names a
    // *state* in prose and a *line* that is the same for all of them, so an
    // empty node list cannot say which state produced it.
    testWidgets('and in the failed state, whose notice adds a control', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, cubit: _unreachableStore());
      await pumpSettingsFrames(tester, 4);

      final List<SemanticsData> activatable = _activatable(tester);
      expect(activatable, isNotEmpty);
      for (final SemanticsData node in activatable) {
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
  });

  group('no two activatable nodes share a name', () {
    // ## THE DEFECT, AND WHY IT IS **ACTIVATABLE** NODES AND NOT ALL NODES
    //
    // §14's row is "one string describing two **focusable, activatable**
    // nodes" — and the qualifier is the whole of it. A static label is a
    // different thing: §14 has nothing to say about two paragraphs using the
    // same word.
    //
    // **The two duplications this file measured and did NOT count**, named here
    // so that a reader knows the sweep saw them rather than missed them:
    //
    // * the two **"A"** nodes the type-size stepper's buttons paint — they
    //   are the `FontSizeStepper`'s own glyphs, they carry no action, and the
    //   button each sits in is named "Decrease font size" / "Increase font
    //   size". `font_size_stepper.dart` owns them, not this screen;
    // * the Arabic arm's **"اللغة"**, which is both the language group's
    //   header and the language control's own name. The header is a static
    //   label and the control is the activatable one, so §14's rule is not
    //   broken — but the reader does hear the word twice, and that is a
    //   consequence of the single-script group header the brief's A1 records.
    testWidgets('on the English arm, no two carry the same name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      _expectNoDuplicateNames(tester);

      handle.dispose();
    });

    testWidgets('and on the Arabic arm', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, locale: const Locale('ar'));

      _expectNoDuplicateNames(tester);

      handle.dispose();
    });
  });

  group('the switches announce their state', () {
    // ## THE SIXTEEN, EACH NAMED BY ITS ROW **AND** ANNOUNCING ITS POSITION
    //
    // **The state is read from the setting and compared with the node**, so
    // the assertion is "the switch says what it is" rather than "the switch
    // says what the default is" — a table of defaults would be a second copy
    // of `UserSettings`' own.
    //
    // The seeded values are chosen to **disagree with the defaults** for half
    // the switches, so a switch that announced a constant would be caught.
    testWidgets('each is named by its row and announces its position', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(
          shaderEnabled: false,
          multichromeMelt: true,
          rayCombing: false,
          whiteCores: false,
          dotVeil: true,
          starsOn: false,
          constellationsOn: false,
          twinkle: false,
          breathGuide: false,
          vespersAutoDim: false,
          reducedMotion: true,
          calmMotion: true,
          haptics: false,
          veilWitnesses: true,
          showPodium: false,
        ),
      );
      final UserSettings settings = cubit.state.settings;

      final List<(String, bool Function(UserSettings))> switches =
          <(String, bool Function(UserSettings))>[
            (
              en.settingsDaylight,
              (UserSettings s) => s.themeMode == AppThemeMode.light,
            ),
            (en.settingsShaderEngine, (UserSettings s) => s.shaderEnabled),
            (en.settingsMultichromeMelt, (UserSettings s) => s.multichromeMelt),
            (en.settingsRayCombing, (UserSettings s) => s.rayCombing),
            (en.settingsWhiteCores, (UserSettings s) => s.whiteCores),
            (en.settingsDotVeil, (UserSettings s) => s.dotVeil),
            (en.settingsStars, (UserSettings s) => s.starsOn),
            (en.settingsConstellations, (UserSettings s) => s.constellationsOn),
            (en.settingsTwinkle, (UserSettings s) => s.twinkle),
            (en.settingsBreathGuide, (UserSettings s) => s.breathGuide),
            (en.settingsVespersAutoDim, (UserSettings s) => s.vespersAutoDim),
            (en.settingsReduceMotion, (UserSettings s) => s.reducedMotion),
            (en.settingsCalmMotion, (UserSettings s) => s.calmMotion),
            (en.settingsHaptics, (UserSettings s) => s.haptics),
            (en.settingsVeilWitnesses, (UserSettings s) => s.veilWitnesses),
            (en.settingsShowPodium, (UserSettings s) => s.showPodium),
          ];
      expect(
        switches,
        hasLength(16),
        reason: 'the screen has sixteen switches',
      );

      for (final (String title, bool Function(UserSettings) read) in switches) {
        final SemanticsData node = _named(tester, title);
        expect(
          node.label.trim(),
          title,
          reason:
              'a switch is named by its **row title in both arms** — a name that '
              'changes with the state is a state name, not a control name',
        );
        expect(
          node.flagsCollection.isToggled,
          read(settings) ? Tristate.isTrue : Tristate.isFalse,
          reason: 'the "$title" switch announces the position it is in',
        );
        expect(
          node.hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'a switch a reader cannot flip is not a control',
        );
      }

      handle.dispose();
    });

    // ## AND THE **ARABIC** ARM CARRIES THE **ARABIC** TITLE
    //
    // The Phase-9 defect this repository has already paid for once: `EvaToggle`
    // published two English words — "On" and "Off" — on both arms for six
    // phases, and no gate could see it, because a semantics label is not
    // painted and a golden captures no semantics.
    testWidgets('and on the Arabic arm the name is the Arabic title', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, locale: const Locale('ar'));

      for (final SemanticsData node in _activatable(tester)) {
        if (node.flagsCollection.isToggled == Tristate.none) continue;
        expect(
          node.label,
          isNot(matches(RegExp('[A-Za-z]'))),
          reason:
              'the switch "${node.label}" is named in English on the Arabic arm. '
              'The name is the row\'s own title, and the row\'s title is Arabic '
              'there.',
        );
      }

      handle.dispose();
    });
  });

  group('the sliders are named, and announce their value', () {
    // ## THE EIGHT, EACH NAMED BY ITS ROW **AND** CARRYING ITS NUMBER
    //
    // **`Semantics(slider: true, value: …)` is the claim, and the value is the
    // raw number** — the prototype paints no number at all (`:429-430`), so
    // the client paints none either, but a slider a reader can move and cannot
    // read is not a control.
    testWidgets('each is named by its row and announces its value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(
          reach: 60,
          glow: 80,
          touchGlow: 50,
          hue: 200,
          starCount: 30,
          starBrightness: 80,
          focusDelaySec: 8,
          selahLengthSec: 45,
        ),
      );
      final UserSettings settings = cubit.state.settings;

      final List<(String, int Function(UserSettings))> sliders =
          <(String, int Function(UserSettings))>[
            (en.settingsReach, (UserSettings s) => s.reach),
            (en.settingsBrightness, (UserSettings s) => s.glow),
            (en.settingsTouchGlow, (UserSettings s) => s.touchGlow),
            (en.settingsHue, (UserSettings s) => s.hue),
            (en.settingsStarCount, (UserSettings s) => s.starCount),
            (en.settingsStarBrightness, (UserSettings s) => s.starBrightness),
            (en.settingsFocusDelay, (UserSettings s) => s.focusDelaySec),
            (en.settingsSelahLength, (UserSettings s) => s.selahLengthSec),
          ];
      expect(sliders, hasLength(8), reason: 'the screen has eight sliders');

      for (final (String title, int Function(UserSettings) read) in sliders) {
        final SemanticsData node = _named(tester, title);
        expect(
          node.label.trim(),
          title,
          reason: 'the slider is named by its row',
        );
        expect(
          node.flagsCollection.isSlider,
          isTrue,
          reason: 'the "$title" control is announced as a slider',
        );
        expect(
          node.value,
          '${read(settings)}',
          reason:
              'the "$title" slider announces the number it is on, and the number '
              'is the raw value — the prototype paints none, so the client paints '
              'none and the announced value is the raw one',
        );
        expect(
          node.hasAction(SemanticsAction.increase) &&
              node.hasAction(SemanticsAction.decrease),
          isTrue,
          reason:
              'a slider is operated by increasing and decreasing it, not by '
              'pressing it. `controls_test.dart` asserts the same for the widget '
              'alone; this is the screen\'s composition of it.',
        );
      }

      handle.dispose();
    });

    // ## AND A SLIDER AT THE END OF ITS RANGE OFFERS NO ACTION PAST IT
    //
    // **The boundary is the claim, and it is `EvaRangeSlider`'s own rule**:
    // `onIncrease` is `null` when the value cannot go up and `onDecrease` is
    // `null` when it cannot go down. A node that offered a decrease that
    // could not happen would be a reader pressing a button that does nothing.
    testWidgets(
      'and a slider at the end of its range offers no action past it',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        // **The Brightness slider at its minimum** — `eva/redesign.html:659`'s
        // `min="40"`.
        await pumpSettings(tester, stored: const UserSettings(glow: 40));

        final SemanticsData node = _named(tester, en.settingsBrightness);
        expect(node.value, '40');
        expect(
          node.hasAction(SemanticsAction.decrease),
          isFalse,
          reason: 'there is nothing below 40 to go to',
        );
        expect(
          node.hasAction(SemanticsAction.increase),
          isTrue,
          reason: 'and there is plenty above it',
        );

        handle.dispose();
      },
    );

    // ## AND THE STEPPED ONE STEPS BY FIVE
    //
    // `:684` — `step="5"`. The announced neighbours are what a reader hears
    // when they ask for "a bit more", so they have to be reachable values.
    testWidgets('and the stepped one announces multiples of its step', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      final SemanticsData node = _named(tester, en.settingsSelahLength);
      expect(node.value, '60');
      expect(node.increasedValue, '65', reason: '`:684` — `step="5"`');
      expect(node.decreasedValue, '55', reason: '`:684` — `step="5"`');

      handle.dispose();
    });
  });

  group('the language control', () {
    // ## IT IS NAMED, AND IT IS **NOT** NAMED FOR THE GROUP'S HEADER
    //
    // The control's own name is `settingsLanguageLabel` — "Language" — and
    // **not** the group's header. The header is the prototype's own label and
    // on the English arm the two differ only in case; a name that reads
    // "language · language" aloud is not a name.
    testWidgets(
      'it is named, and the language in force is announced as selected',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpSettings(tester);

        final SemanticsData track = _named(tester, en.settingsLanguageLabel);
        expect(
          track.hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'the track is the control\'s single tab stop',
        );

        final SemanticsData english = _named(
          tester,
          en.languageLabelFor(ReadingLanguage.english),
        );
        final SemanticsData arabic = _named(
          tester,
          en.languageLabelFor(ReadingLanguage.arabic),
        );
        expect(
          english.flagsCollection.isSelected,
          Tristate.isTrue,
          reason:
              'the English arm is rendering in English, so the English option is '
              'the one in force. Without `selected` a screen reader cannot tell '
              'which of the two is in force.',
        );
        expect(arabic.flagsCollection.isSelected, Tristate.isFalse);
        expect(english.flagsCollection.isButton, isTrue);
        expect(arabic.flagsCollection.isButton, isTrue);

        handle.dispose();
      },
    );

    // ## AND ON THE **ARABIC** ARM THE OPTIONS ARE THE **OWN-SCRIPT** NAMES
    //
    // `settings_l10n.dart`'s rule: "a language names itself in its own
    // script". Both options are Arabic on the Arabic arm, and the option in
    // force is the one the arm is rendering in.
    testWidgets('and on the Arabic arm both options are in Arabic', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, locale: const Locale('ar'));

      final SemanticsData english = _named(
        tester,
        ar.languageLabelFor(ReadingLanguage.english),
      );
      final SemanticsData arabic = _named(
        tester,
        ar.languageLabelFor(ReadingLanguage.arabic),
      );
      expect(english.label, isNot(matches(RegExp('[A-Za-z]'))));
      expect(arabic.label, isNot(matches(RegExp('[A-Za-z]'))));
      expect(
        arabic.flagsCollection.isSelected,
        Tristate.isTrue,
        reason: 'the Arabic arm is rendering in Arabic',
      );
      expect(english.flagsCollection.isSelected, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('the restore row', () {
    // ## IT IS A **BUTTON**, AND IT IS NAMED BY ITS TITLE
    //
    // `:695` is the one `.srow` without `cursor:default`, and the client's
    // shape for that is `SettingsTile` with an `onTap` — which brings its own
    // `Semantics(button: true)`.
    testWidgets('it is a button, named by its title', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      final SemanticsData row = semanticsTree(tester).firstWhere(
        (SemanticsData node) =>
            node.label.startsWith(en.settingsRestoreDefaults),
      );
      expect(
        row.flagsCollection.isButton,
        isTrue,
        reason: 'the row is the control, so it is announced as one',
      );
      expect(row.hasAction(SemanticsAction.tap), isTrue);
      expect(
        row.label,
        startsWith(en.settingsRestoreDefaults),
        reason: 'the row is named by its title',
      );

      handle.dispose();
    });

    testWidgets('and the arrow it carries is not named on its own', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);

      // The `↺` is the row's **trailing value** and it is merged into the
      // row's own name, so a reader hears "Restore nocturne defaults, ↺" as
      // one thing. A node of its own would be a second announcement of a
      // glyph.
      final Iterable<SemanticsData> arrows = semanticsTree(tester)
          .where((SemanticsData node) => node.label.trim() == '↺');
      expect(
        arrows,
        isEmpty,
        reason:
            'the arrow rides in the row\'s own name. A node of its own would be '
            'a glyph announced by itself, which is §14\'s "a decorative icon '
            'announced alone" shape.',
      );

      handle.dispose();
    });
  });

  group('the notice, and §14\'s four properties of an error', () {
    // ## IT IS **ANNOUNCED**, AND THE RETRY IS A CONTROL **OF ITS OWN**
    //
    // A failure that arrives after the screen has settled has to be announced,
    // or a screen-reader user finds out from the retry button being there.
    testWidgets('it is a live region, and the retry is its own control', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester, cubit: _unreachableStore());
      await pumpSettingsFrames(tester, 4);

      final List<SemanticsData> nodes = semanticsTree(tester);

      expect(
        nodes
            .where((SemanticsData node) => node.flagsCollection.isLiveRegion)
            .map((SemanticsData node) => node.label),
        contains(en.settingsPreferencesUnavailable),
        reason:
            'asserted on the label and not only on the flag, because a live '
            'region carrying nothing announces nothing',
      );

      final Iterable<SemanticsData> retry = nodes.where(
        (SemanticsData node) => node.label == en.settingsRetry,
      );
      expect(
        retry,
        hasLength(1),
        reason:
            'the retry is a control with its OWN name. Fused into the live region '
            'it would have no node of its own, and §14\'s first row is about '
            'controls rather than about announcements.',
      );
      expect(retry.single.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('and on the Arabic arm it is Arabic', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(
        tester,
        cubit: _unreachableStore(),
        locale: const Locale('ar'),
      );
      await pumpSettingsFrames(tester, 4);

      // **The half the Arabic glyph gate cannot see.** That gate walks the
      // **painted** tree, and a `Semantics` label is not painted.
      expect(find.text(ar.settingsPreferencesUnavailable), findsOneWidget);
      expect(find.bySemanticsLabel(ar.settingsRetry), findsOneWidget);
      expect(
        find.bySemanticsLabel(en.settingsRetry),
        findsNothing,
        reason: 'the English sentence must not survive into the Arabic arm',
      );

      handle.dispose();
    });
  });
}

/// The seven untranslated segment labels — `eva/redesign.html:673` and `:678`.
///
/// **A list and not a blanket waiver.** The Arabic arm may carry Latin script
/// in exactly these seven names, and the brief's D11 says why: the prototype
/// puts no `data-i18n` on them, so they are the prototype's own English and
/// the client's decision keeps them that way. Every **other** name on the
/// Arabic arm is Arabic.
const List<String> _untranslatedSegmentLabels = <String>[
  'dot',
  'star',
  'cross',
  'gem',
  'crown',
  'high',
  'full',
];

/// Every node a reader could **do** something with.
///
/// A tap, an increase or a decrease — and **not** a `focus` action, because a
/// focusable node that nothing can be done to is a stop in the reading order
/// rather than a control.
List<SemanticsData> _activatable(WidgetTester tester) => <SemanticsData>[
  for (final SemanticsData node in semanticsTree(tester))
    if (node.hasAction(SemanticsAction.tap) ||
        node.hasAction(SemanticsAction.increase) ||
        node.hasAction(SemanticsAction.decrease))
      node,
];

/// The one node named [label].
///
/// **A node and not a widget.** `find.bySemanticsLabel` returns *widgets*, and
/// one `SemanticsNode` can be contributed to by several — so `findsOneWidget`
/// on it answers "how many widgets carry this label", which is not the
/// question. The sweep's own currency is `SemanticsData`.
SemanticsData _named(WidgetTester tester, String label) {
  final Iterable<SemanticsData> found = semanticsTree(tester)
      .where((SemanticsData node) => node.label.trim() == label);
  expect(
    found,
    hasLength(1),
    reason:
        'exactly one node is named "$label". More than one is §14\'s duplicate-name '
        'defect, and none is an unnamed control.',
  );
  return found.single;
}

/// Asserts that no two activatable nodes carry the same name.
void _expectNoDuplicateNames(WidgetTester tester) {
  final Map<String, int> counts = <String, int>{};
  for (final SemanticsData node in _activatable(tester)) {
    final String label = node.label.trim();
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final List<String> duplicates = <String>[
    for (final MapEntry<String, int> entry in counts.entries)
      if (entry.value > 1) '${entry.key} (${entry.value} nodes)',
  ];
  expect(
    duplicates,
    isEmpty,
    reason:
        'one string describing two activatable nodes is §14\'s duplicate-name '
        'defect, and the reader cannot tell which control they are on:\n'
        '${duplicates.join('\n')}',
  );
}

/// A cubit over a store that cannot be reached, which is the only route to
/// `SettingsStatus.failed`.
///
/// **Built here rather than shared** because the screen's own suite has the
/// same shape for its own test, and the two differ in what they need: this one
/// only has to *reach* the state for the sweep, where that file also drives
/// the restore and the write arm.
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
