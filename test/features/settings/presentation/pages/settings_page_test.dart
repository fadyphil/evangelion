import 'dart:io';

import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
// `CurtainShape` is hidden from the barrel because the design system has one
// too — `NeuralScaffold`'s scrim ramp — and this screen's is the aurora's.
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_restore_toast.dart';
import 'package:evangelion/features/settings/presentation/workshop_logic.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/settings_harness.dart';

/// `/settings` — **the Workshop** — the screen suite.
///
/// ## WHAT THIS FILE IS, AND WHAT IT IS **NOT**
///
/// It is the screen's **composition** suite: the claims that are about the page
/// as a whole rather than about one control. Four of them are the brief's own:
///
/// 1. the **seven group headers, in the prototype's DOM order**;
/// 2. the **restore row** — that it is tappable, that it resets the prototype's
///    twenty-three fields, and that it leaves the prototype's six alone;
/// 3. the **toast** — that it is raised, that it lasts the prototype's 1800ms,
///    and that it is **not** raised when the write fails;
/// 4. the **version chip** — that it carries the app's real version, and that
///    the constant is pinned to `pubspec.yaml`.
///
/// **It is not the screen's own suite.** `workshop_page_test.dart` holds the
/// smoke test — that the page builds, that every row writes, and that the
/// Daylight toggle narrows — and the four widget suites beside it hold each
/// widget's own contract. This file is deliberately narrow so that the two do
/// not overlap, and every claim here is one the other file cannot see.
///
/// ## AND WHY THE **ORDER** IS A CLAIM AND NOT A FORMATTING DETAIL
///
/// The redesign's DOM order **is** the order, and the order is what a reader
/// reads: the language, then the palette, then the light, then the sky, then
/// the ritual, then the communion, then the about. A screen that kept all seven
/// groups and moved one of them would pass every "the seven headers are there"
/// assertion in the repository — and the screen's own suite has exactly such an
/// assertion, which is why this file adds the one it cannot make.
void main() {
  final AppLocalizationsEn strings = AppLocalizationsEn();

  group('the seven groups, in the prototype\'s DOM order', () {
    // ## THE SEVEN HEADERS, AND THE ORDER THEY ARE IN
    //
    // `eva/redesign.html:645`, `:649`, `:651`, `:666`, `:682`, `:690`, `:696` —
    // and `SettingsGroup`'s own doc says "**seven** of them", which is now true
    // of this screen.
    //
    // **The order is asserted twice, and the two assertions are independent.**
    // The first reads the tree — the seven `SettingsGroup`s in the order the
    // page composed them, which is the claim. The second reads the **geometry**
    // — the seven labels' `dy`, which is what a reader sees, and which is what
    // a `Column` that reordered its children would fail. One of them alone would
    // be enough; both together are what makes a reordering visible rather than
    // merely arguable.
    testWidgets(
      'the seven headers, above one another, in the prototype\'s order',
      (WidgetTester tester) async {
        await pumpSettings(tester);

        final List<String> expected = <String>[
          strings.settingsWsLang,
          strings.settingsThemeGroup,
          strings.settingsWsLight,
          strings.settingsSkyGroup,
          strings.settingsRitualGroup,
          strings.settingsCommunionGroup,
          strings.settingsAbout,
        ];

        expect(find.byType(SettingsGroup), findsNWidgets(7));
        expect(
          tester
              .widgetList<SettingsGroup>(find.byType(SettingsGroup))
              .map((SettingsGroup group) => group.label),
          expected,
          reason:
              'the tree order is the DOM order: `eva/redesign.html:645`, `:649`, '
              '`:651`, `:666`, `:682`, `:690`, `:696`',
        );

        // **The geometry**, and the labels are **uppercased** because
        // `EvaSectionHeader` transcribes `SettingsScreen.tsx:29`'s
        // `textTransform: 'uppercase'` in Dart, which Flutter has no equivalent
        // for.
        final List<double> tops = <double>[
          for (final String label in expected)
            tester.getTopLeft(find.text(label.toUpperCase())).dy,
        ];
        expect(
          tops,
          orderedEquals(<double>[...tops]..sort()),
          reason:
              'each header is above the next one. The order of the groups is the '
              'one claim a "the seven headers are on screen" assertion cannot make.',
        );
      },
    );

    // ## AND THE **TWENTY-NINE** CONTROLS, COUNTED
    //
    // The brief's inventory: 29 interactive controls, one action row, one
    // preview line and two static rows. The screen's own suite proves that the
    // fifteen switches it names write; this counts **all** of them, so a row
    // that stopped being drawn would move the number rather than quietly
    // reduce the screen.
    testWidgets('and twenty-nine interactive controls, of four kinds', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      // The sixteen switches: the Daylight toggle, the ten light-workshop and
      // sky switches, the five ritual switches and the two communion ones.
      expect(find.byType(EvaToggle), findsNWidgets(16));
      // The eight sliders.
      expect(find.byType(EvaRangeSlider), findsNWidgets(8));
      // The four segmented controls — one per generic type, because
      // `find.byType` compares the **runtime** type and a
      // `SegmentedControl<Object>` matches none of them.
      expect(find.byType(SegmentedControl<ReadingLanguage>), findsOneWidget);
      expect(find.byType(SegmentedControl<CurtainShape>), findsOneWidget);
      expect(find.byType(SegmentedControl<SkyStarShape>), findsOneWidget);
      expect(find.byType(SegmentedControl<SkyStarField>), findsOneWidget);
      // The one stepper.
      expect(find.byType(FontSizeStepper), findsOneWidget);
    });
  });

  group('the restore row', () {
    // ## IT IS THE **ONLY** TAPPABLE ROW
    //
    // `eva/redesign.html:695` is a `.srow` **without** `style="cursor:default"`
    // — every other row in the markup carries it, and this one does not. The
    // prototype's own handler is bound to the row (`:1499`), so the row is the
    // control.
    //
    // **The claim is "only", not "tappable".** A screen that made every row
    // tappable would satisfy a test that only looked for one tappable row, and
    // it would be a worse screen: twenty-nine rows that answer a tap with
    // nothing.
    testWidgets('it is the only tappable row on the screen', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      final List<SettingsTile> tappable = <SettingsTile>[
        for (final SettingsTile tile in tester.widgetList<SettingsTile>(
          find.byType(SettingsTile),
        ))
          if (tile.onTap != null) tile,
      ];

      expect(
        tappable,
        hasLength(1),
        reason:
            '`:695` is the one `.srow` without `cursor:default`. Every other row '
            'is inert, and a row that answers a tap with nothing is a control '
            'that lies.',
      );
      expect(tappable.single.title, strings.settingsRestoreDefaults);
    });

    // ## AND IT RESETS THE PROTOTYPE'S **TWENTY-THREE**
    //
    // The brief's D9.1 table, field by field, each with the prototype's own
    // line. **Every one is seeded away from its default**, so the assertion is
    // "the reset happened" and not "the field was already at its default" —
    // which is the failure mode a harness that seeds nothing would have.
    testWidgets('it restores the twenty-three fields the prototype restores', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(
          shaderEnabled: false,
          curtainShape: CurtainShape.shafts,
          reach: 100,
          glow: 40,
          touchGlow: 0,
          hue: 100,
          multichromeMelt: true,
          rayCombing: false,
          whiteCores: false,
          dotVeil: true,
          starsOn: false,
          constellationsOn: false,
          starCount: 10,
          starBrightness: 30,
          starShape: SkyStarShape.diamond,
          starField: SkyStarField.full,
          twinkle: false,
          focusDelaySec: 10,
          selahLengthSec: 20,
          breathGuide: false,
          vespersAutoDim: false,
          veilWitnesses: true,
          showPodium: false,
        ),
      );

      // ## THE SEED **REACHED THE STORE**
      //
      // **Without this the whole test is vacuous.** A harness that seeded
      // nothing would leave every field at its **default**, and the reset's
      // answer is the default — so the assertion below would pass with the
      // restore deleted. Asserting the pre-reset state is the **seeded** value
      // is what makes the reset observable at all.
      expect(
        cubit.state.settings.reach,
        100,
        reason:
            'the harness seeds the store, and the store is what the cubit read. '
            'A seed that did not reach it would leave every field at its default '
            'and make the reset a no-op that looks like a pass.',
      );
      expect(cubit.state.settings.curtainShape, CurtainShape.shafts);
      expect(cubit.state.settings.veilWitnesses, isTrue);

      await _tapRestore(tester);

      final UserSettings after = cubit.state.settings;
      // **A map, not a whole-object comparison.** `freezed` derives `==` from
      // the constructor, so `expect(after, const UserSettings(...))` would
      // answer "some field differs" and name none of them. A map names the
      // field that differs, and the table beside it is the brief's D9.1.
      expect(
        <String, Object>{
          'shaderEnabled': after.shaderEnabled,
          'curtainShape': after.curtainShape,
          'reach': after.reach,
          'glow': after.glow,
          'touchGlow': after.touchGlow,
          'hue': after.hue,
          'multichromeMelt': after.multichromeMelt,
          'rayCombing': after.rayCombing,
          'whiteCores': after.whiteCores,
          'dotVeil': after.dotVeil,
          'starsOn': after.starsOn,
          'constellationsOn': after.constellationsOn,
          'starCount': after.starCount,
          'starBrightness': after.starBrightness,
          'starShape': after.starShape,
          'starField': after.starField,
          'twinkle': after.twinkle,
          'focusDelaySec': after.focusDelaySec,
          'selahLengthSec': after.selahLengthSec,
          'breathGuide': after.breathGuide,
          'vespersAutoDim': after.vespersAutoDim,
          'veilWitnesses': after.veilWitnesses,
          'showPodium': after.showPodium,
        },
        <String, Object>{
          // `:1500` … `:1523`.
          'shaderEnabled': true,
          'curtainShape': CurtainShape.top,
          'reach': 42,
          'glow': 100,
          'touchGlow': 55,
          'hue': 312,
          'multichromeMelt': false,
          'rayCombing': true,
          'whiteCores': true,
          'dotVeil': false,
          'starsOn': true,
          'constellationsOn': true,
          'starCount': 44,
          'starBrightness': 100,
          'starShape': SkyStarShape.dot,
          'starField': SkyStarField.crown,
          'twinkle': true,
          'focusDelaySec': 4,
          'selahLengthSec': 60,
          'breathGuide': true,
          'vespersAutoDim': true,
          'veilWitnesses': false,
          'showPodium': true,
        },
      );
    });

    // ## AND IT LEAVES THE PROTOTYPE'S **SIX**
    //
    // D9.2. The set is **not** empty, and two of its members are **new**
    // fields — `calmMotion` and `haptics` — which the prototype's handler
    // deliberately leaves alone.
    testWidgets('and it leaves the six the prototype leaves alone', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(
        tester,
        stored: const UserSettings(
          language: ReadingLanguage.arabic,
          themeMode: AppThemeMode.light,
          fontStep: 5,
          reducedMotion: true,
          calmMotion: true,
          haptics: false,
        ),
      );

      // ## THE SEED **REACHED THE STORE**
      //
      // The same reason as the reset test above: the "left alone" claim is
      // only a claim if the six fields were **not** already at the values the
      // restore leaves them at.
      expect(cubit.state.settings.language, ReadingLanguage.arabic);
      expect(cubit.state.settings.themeMode, AppThemeMode.light);
      expect(cubit.state.settings.fontStep, 5);
      expect(cubit.state.settings.reducedMotion, isTrue);
      expect(cubit.state.settings.calmMotion, isTrue);
      expect(cubit.state.settings.haptics, isFalse);

      await _tapRestore(tester);

      final UserSettings after = cubit.state.settings;
      expect(
        <String, Object?>{
          'language': after.language,
          'themeMode': after.themeMode,
          'fontStep': after.fontStep,
          'reducedMotion': after.reducedMotion,
          'calmMotion': after.calmMotion,
          'haptics': after.haptics,
        },
        <String, Object?>{
          // `:1499-1525` touches none of them.
          'language': ReadingLanguage.arabic,
          // The prototype DOES reset the daylight (`:1501`) and this client does
          // **not** — the three-state `themeMode` is an existing reader choice.
          'themeMode': AppThemeMode.light,
          'fontStep': 5,
          'reducedMotion': true,
          // `calmMotion` and `haptics` are **new** fields the prototype still
          // leaves alone, because they are comfort choices.
          'calmMotion': true,
          'haptics': false,
        },
      );
    });

    // ## AND IT RAISES THE **TOAST**
    //
    // `:1525` — `toast(tr('restored'))`.
    testWidgets('and it raises the confirmation toast', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.byType(WorkshopRestoreToast), findsNothing);

      await _tapRestore(tester);

      expect(find.byType(WorkshopRestoreToast), findsOneWidget);
      expect(find.text(strings.settingsRestored), findsOneWidget);
    });

    // ## AND THE TOAST LASTS THE PROTOTYPE'S **1800ms**
    //
    // `:1393` — `setTimeout(()=>t.classList.remove('show'),1800)`.
    //
    // **The "still up" half is the one the screen's own suite does not have.**
    // It asserts the toast is there and then that it is gone; a toast that
    // lasted 100ms would pass both. So the clock is read at **1799ms** — one
    // millisecond before the deadline — and the toast has to still be there.
    testWidgets('and the toast is still up one millisecond before 1800ms', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await _tapRestore(tester);
      expect(find.byType(WorkshopRestoreToast), findsOneWidget);

      await tester.pump(
        kRestoreToastDuration - const Duration(milliseconds: 1),
      );
      expect(
        find.byType(WorkshopRestoreToast),
        findsOneWidget,
        reason:
            'the prototype holds the toast for 1800ms (`:1393`), and a toast that '
            'went away early would be a confirmation the reader did not have time '
            'to read.',
      );

      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(WorkshopRestoreToast), findsNothing);
    });
  });

  group('the restore, and a write that fails', () {
    // ## WHY THE TOAST IS **NOT** RAISED
    //
    // The prototype raises it unconditionally (`:1525`), because the
    // prototype's reset is local JavaScript and **cannot fail**. This client's
    // can: `SettingsCubit.apply` rolls back and records the failure.
    //
    // **A toast that said "nocturne defaults restored" over a screen that was
    // simultaneously saying "your preferences could not be saved" would be two
    // sentences about one event, and they would contradict each other.** So the
    // page awaits the confirmed write, reads `cubit.state.status`, and stays
    // silent on `SettingsStatus.failed`.
    //
    // ## AND WHY THE STORED VALUE IS **AWAY FROM THE DEFAULTS**
    //
    // `SettingsCubit.apply` has a rule this test would otherwise trip over: it
    // **does not write a value that did not change** — "an emit that changes
    // nothing is a full rebuild that changes nothing". A store already holding
    // the defaults would therefore make the restore a **no-op**, no write would
    // be attempted, and the failure this test is about would never happen. The
    // first version of this test asserted `SettingsStatus.failed` over a
    // default store and read `Actual: SettingsStatus.ready`, which is the
    // no-op rule working exactly as documented.
    testWidgets(
      'a failed write raises NO toast, and the notice speaks instead',
      (WidgetTester tester) async {
        final SettingsCubit cubit = _cubitThatFailsToWrite();
        addTearDown(cubit.close);

        await pumpSettings(tester, cubit: cubit);
        expect(
          cubit.state.status,
          SettingsStatus.ready,
          reason:
              'sanity: the read succeeded, so the failure below is the write',
        );
        expect(find.byType(WorkshopRestoreToast), findsNothing);

        await _tapRestore(tester);

        expect(cubit.state.status, SettingsStatus.failed);
        expect(
          find.byType(WorkshopRestoreToast),
          findsNothing,
          reason:
              'the write was refused, so nothing was restored and the confirmation '
              'would be a lie.',
        );
        expect(
          find.text(strings.settingsPreferencesUnavailable),
          findsOneWidget,
          reason: 'the failure notice speaks instead — one sentence about one event.',
        );
      },
    );

    // ## AND THE RESTORE **ROLLS BACK**
    //
    // `SettingsCubit.apply` emits optimistically and `_persist` emits again
    // with the store's answer, so the state after the `await` **is** the
    // outcome: the values the reader had before the tap.
    testWidgets('and the settings roll back to what the store confirmed', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = _cubitThatFailsToWrite();
      addTearDown(cubit.close);

      await pumpSettings(tester, cubit: cubit);
      final UserSettings before = cubit.state.settings;
      expect(
        before.reach,
        100,
        reason: 'sanity: the store holds something the reset would change',
      );

      await _tapRestore(tester);

      expect(
        cubit.state.settings,
        before,
        reason:
            'the optimistic emit is undone by the store\'s answer. A screen that '
            'showed restored values over a refused write would show the reader a '
            'state the device does not have.',
      );
    });
  });

  group('the version chip', () {
    // ## IT CARRIES THE APP'S **REAL** VERSION
    //
    // `eva/redesign.html:642` writes the literal `v1.2`, which is the **design
    // system's** version. The client's chip carries `AppConfig.appVersion` — a
    // reader looking at a version chip wants the version of the app they are
    // holding.
    //
    // **And the constant is pinned to `pubspec.yaml`,** which is the half the
    // app-bar widget's own suite does not have: a chip that carries a version
    // nobody maintains is worse than a chip that carries the prototype's.
    testWidgets('it carries the app\'s real version, and `pubspec.yaml` agrees', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text(AppConfig.appVersion), findsOneWidget);
      expect(
        find.text('v1.2'),
        findsNothing,
        reason:
            '`:642` writes `v1.2`, and that is the design system\'s version — the '
            'same string the About group\'s "Tokens" row carries (`:698`).',
      );

      // **The whole reason the constant is a constant.** `pubspec.yaml` is the
      // authority and a bump without bumping this is a lie on a reader's
      // screen; this reads the file so the two cannot drift silently.
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
            'pubspec.yaml declares `$declared` and the chip must not disagree. '
            'Bump the version and this goes red until `AppConfig.appVersion` moves.',
      );
    });
  });

  group('the failure notice', () {
    // ## A FAILED **WRITE** REPORTS IT
    //
    // A failed read happens once, at launch, while the reader is looking at
    // `/`. A failed write happens **because of something the reader just did**,
    // and without the notice that is a control that moves and undoes itself
    // with nothing said.
    testWidgets('a failed write puts the notice on screen', (
      WidgetTester tester,
    ) async {
      final SettingsHarness harness = settingsHarness(loadImmediately: false);
      final SettingsCubit cubit = SettingsCubit(
        getSettings: GetSettings(harness.repository),
        updateSettings: const UpdateSettings(_SaveFailingRepository()),
      );
      addTearDown(cubit.close);

      await pumpSettings(tester, cubit: cubit);
      expect(
        find.text(strings.settingsPreferencesUnavailable),
        findsNothing,
        reason: 'nothing has failed yet, so nothing is claimed',
      );

      // **The Daylight toggle**, the first control on the screen.
      await tester.tap(find.byType(EvaToggle).first);
      await pumpSettingsFrames(tester, 4);

      expect(cubit.state.status, SettingsStatus.failed);
      expect(find.text(strings.settingsPreferencesUnavailable), findsOneWidget);
    });

    // ## AND THE NOTICE IS **NOT** THE REPOSITORY'S MESSAGE
    //
    // `SettingsRepositoryImpl._unreachable` builds
    // `'The preferences could not be reached: $error'` — it interpolates the
    // raw Dart exception, and a real one on a real device is
    // `MissingPluginException(No implementation found for method … on channel …)`.
    // Rendering that would put an exception's `toString()` on a reader's
    // screen.
    testWidgets('and it is not the repository\'s message', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = SettingsCubit(
        getSettings: const GetSettings(
          FailingSettingsRepository(
            Failure(
              kind: FailureKind.storage,
              message: 'the preferences could not be reached',
            ),
          ),
        ),
        updateSettings: const UpdateSettings(
          FailingSettingsRepository(
            Failure(kind: FailureKind.storage, message: 'the store is gone'),
          ),
        ),
      );
      addTearDown(cubit.close);

      await pumpSettings(tester, cubit: cubit);
      await pumpSettingsFrames(tester, 4);

      expect(
        find.textContaining('the preferences could not be reached'),
        findsNothing,
        reason:
            'the repository message is a developer string. Asserted by content and '
            'not by equality so it goes red for ANY exception text, not only the '
            'one this fixture happens to use.',
      );
      expect(find.text(strings.settingsPreferencesUnavailable), findsOneWidget);
    });
  });
}

/// Scrolls the restore row into view and taps it.
///
/// The row is the last of the communion group's rows and the screen scrolls,
/// so the tap has to be preceded by a scroll — a tap on a row that is not on
/// screen is a tap on nothing, and `tester.tap` would throw rather than fail
/// the claim.
Future<void> _tapRestore(WidgetTester tester) async {
  // **The ARB value and not a literal**, so a translator's change to the row's
  // title does not turn this helper into a finder that matches nothing.
  final Finder title = find.text(AppLocalizationsEn().settingsRestoreDefaults);
  await tester.ensureVisible(title);
  await tester.pump();
  await tester.tap(title);
  // **Two frames**, and the reason is the `await` in `_restore`. The page
  // awaits the confirmed write before it decides whether to raise the toast,
  // so the toast is up one microtask-turn after the write answers — and the
  // write answers inside the store's own `Future`.
  await tester.pump();
  await tester.pump();
}

/// The stored value the failing-write tests read.
///
/// **Away from the defaults on purpose** — see the group's own doc: a store
/// already holding the defaults makes the restore a no-op, and `apply` does
/// not write a value that did not change.
const UserSettings _storedAwayFromTheDefaults = UserSettings(
  reach: 100,
  glow: 40,
  shaderEnabled: false,
  starsOn: false,
);

/// A cubit that **reads** a fixed value and **refuses every write**.
SettingsCubit _cubitThatFailsToWrite() => SettingsCubit(
  getSettings: const GetSettings(
    _FixedSettingsRepository(_storedAwayFromTheDefaults),
  ),
  updateSettings: const UpdateSettings(_SaveFailingRepository()),
);

/// A repository that answers [load] with a fixed value and refuses every write.
///
/// **The refusal is the point, and the load is a fixture.** The read has to
/// succeed — the failure this file is about is the **write**'s, and a read
/// that failed too would put the screen in its failed state before the reader
/// had touched anything, which is a different scenario with the same symptom.
final class _FixedSettingsRepository implements SettingsRepository {
  const _FixedSettingsRepository(this.settings);

  /// What the read answers with.
  final UserSettings settings;

  @override
  Future<Result<UserSettings>> load() async =>
      Result<UserSettings>.right(settings);

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async =>
      Result<UserSettings>.left(_SaveFailingRepository.failure);
}

/// A repository whose **write** always fails.
///
/// The read is never asked of it — the cubit's `GetSettings` points at
/// [_FixedSettingsRepository] — so the failure it produces is unambiguously the
/// **write**'s, which is the arm that matters: a failed read happens once at
/// launch, while a failed write happens because of something the reader just
/// did.
final class _SaveFailingRepository implements SettingsRepository {
  const _SaveFailingRepository();

  /// The failure every write answers with.
  static const Failure failure = Failure(
    kind: FailureKind.storage,
    message: 'the store refused the write',
  );

  @override
  Future<Result<UserSettings>> load() async =>
      Result<UserSettings>.left(failure);

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async =>
      Result<UserSettings>.left(failure);
}
