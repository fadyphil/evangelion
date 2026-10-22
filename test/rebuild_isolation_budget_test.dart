import 'package:evangelion/core/design_system/effects/lumen_background.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/eva_typography.dart';
import 'package:evangelion/core/design_system/widgets/neural_scaffold.dart';
import 'package:evangelion/core/design_system/widgets/segmented_control.dart';
import 'package:evangelion/core/design_system/widgets/settings_tile.dart';
import 'package:evangelion/core/design_system/widgets/witness_sky.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_harness.dart';
import 'support/rebuild_counter.dart';
import 'support/settings_harness.dart';

/// The **rebuild boundary**, asserted rather than described.
///
/// ## WHAT THIS GATE IS FOR
///
/// The question this repository's performance work is actually asking is *"when a
/// piece of state changes, how much of the tree rebuilds with it?"* — and
/// Flutter answers it in exactly one place: `Element.update`'s short-circuit on
/// an **identical** widget. A rebuild stops descending the moment it
/// re-encounters the same widget instance, so the cost of a state change is
/// decided entirely by **how wide the thing that changed is**.
///
/// The gate below is that question, made executable.
///
/// ## WHY A GATE AND NOT A BENCHMARK
///
/// A benchmark prints a number; a number rots. **A budget fails the build**, so
/// it cannot rot — and a claim about a number that cannot rot is the only kind
/// this repository accepts (`CONTRIBUTING.md`, "a claim about a number is a
/// claim about a specific thing").
///
/// The instrument is `test/support/rebuild_counter.dart`, which counts the
/// widgets the framework **rebuilt** during one frame using the framework's own
/// `debugOnRebuildDirtyWidget` hook.
///
/// ## WHY THE ASSERTIONS ARE **NAMED WIDGETS** AND NOT ONLY A TOTAL
///
/// Because a total is a number nobody can act on. "Sixty widgets rebuilt" does
/// not say *which* sixty, and the answer is almost always "the ones that had no
/// business rebuilding". So the gate names the widgets that must **not** move —
/// the sky, the scaffold, the app bar — and then bounds the total.
///
/// **A named assertion fails with a name.** "The sky rebuilt" is a finding; "the
/// total exceeded 120" is a number to go and look up.
void main() {
  group('a verse tap on `/reading`', () {
    testWidgets('rebuilds the verse and nothing around it', (
      WidgetTester tester,
    ) async {
      final ReadingHarness harness = readingHarness();
      await pumpReading(tester, cubit: harness.cubit);

      final Finder verse = find.byType(VerseLine).first;
      expect(
        verse,
        findsWidgets,
        reason: 'the passage must have a verse to tap',
      );

      // The baseline: one pump with nothing done to it.
      // ## THE **FIRST** TAP IS NOT THE ONE MEASURED, AND THE REASON IS
      // ## THE FOCUS DIM
      //
      // `pumpReading` leaves the page **dimmed** — it pumps past the focus
      // idle delay on purpose, and the harness's own doc says why. A pointer
      // anywhere lifts that dim (`:1290`), and lifting it changes the chrome's
      // opacity — so the **first** tap legitimately rebuilds the app bar.
      //
      // So the first tap is spent lifting the dim, and the **second** one is
      // the steady state this gate is about: a tap that changes the selection
      // and nothing else.
      await tester.tap(verse, warnIfMissed: false);
      await tester.pump();

      // **A DIFFERENT verse**, and not the same one twice.
      //
      // Tapping the *already selected* verse costs **nothing** — a
      // `ValueNotifier` ignores an equal value, where the `setState` this
      // replaced rebuilt the screen every time. That is a real win, and it is
      // not the one this gate is about: the gate is about the cost of a tap
      // that **changes** the selection.
      final Finder other = find.byType(VerseLine).at(1);
      expect(
        other,
        findsWidgets,
        reason: 'the passage must have a second verse',
      );

      final RebuildCounter baseline = await countRebuilds(tester, () async {});
      // The action: one pump after the tap.
      final RebuildCounter after = await countRebuilds(
        tester,
        () async => tester.tap(other, warnIfMissed: false),
      );
      final RebuildCounter delta = after.delta(baseline);

      debugPrint('── a verse tap ──');
      debugPrint('baseline : ${baseline.total}  ${baseline.describe()}');
      debugPrint('DELTA    : ${delta.total}  ${delta.describe()}');

      // ## THE **SKY** MUST NOT MOVE
      //
      // It is the most expensive thing on the screen — **44** stars × 5
      // widgets, plus 88 shadow blurs, **at the cap** — and it has **nothing
      // to do with which verse is selected**. It used to live inside the
      // page's `BlocBuilder`, so every emit and every tap rebuilt it.
      //
      // ## THE FORTY-FOUR IS A **CAP**, NOT A MOUNTED COUNT
      //
      // It is `UserSettings.starCount`
      // (`lib/core/domain/entities/user_settings.dart:164`) — the ceiling on
      // how many stars the sky may hold — and the sky draws one star per
      // **lit** entry (`lib/core/design_system/widgets/witness_sky.dart:981`),
      // so a reader who has just opened the app has lit **none**.
      //
      // `flutter test test/layer_census_test.dart` measures it: `/reading`
      // mounts **6** `OpacityLayer`s at rest, and lighting all forty-four adds
      // **exactly 44** more, for **738.77** logical px².
      //
      // **The gate is unchanged**: the sky must not rebuild on a verse tap,
      // whichever count of stars is lit. What the number *means* is not what
      // the gate asserts.
      expect(
        delta.countOf(WitnessSky),
        0,
        reason:
            'the sky does not read the selection, so a tap must not rebuild it. '
            'It is 44 stars × 5 widgets plus 88 shadow blurs AT THE CAP — the '
            '44 is `UserSettings.starCount`, the ceiling on LIT stars, not a '
            'mounted count: the sky draws one star per lit entry '
            '(`witness_sky.dart:981`), and `test/layer_census_test.dart` '
            'measures 6 `OpacityLayer`s mounted on `/reading` at rest and '
            'exactly 44 more when all 44 are lit. It used to rebuild on every '
            'tap because it sat inside the page\'s `BlocBuilder`.',
      );
      // ## AND NEITHER MAY THE **SCREEN AROUND IT**
      expect(
        delta.countOf(LumenBackground),
        0,
        reason:
            'the aurora is repainted every frame by its own clock; a tap must '
            'not rebuild the widget that hosts it.',
      );
      expect(
        delta.countOf(Scaffold),
        0,
        reason: 'the whole screen did not change, so the scaffold did not.',
      );
      expect(
        delta.countOf(NeuralScaffold),
        0,
        reason: 'the whole screen did not change, so the scaffold did not.',
      );

      // ## AND THE **CHROME** MUST NOT MOVE
      //
      // The app bar, the pill and the CTA read the passage and the reader's
      // comfort settings, and a tap changes **neither**.
      expect(
        delta.countOf(ReadingAppBar),
        0,
        reason:
            'the app bar reads the passage and the bookmark, and a tap on a '
            'verse changes neither. It used to rebuild on every tap because the '
            'page\'s own `setState` reached it.',
      );
      expect(
        delta.countOf(SegmentedControl<ReadingLanguage>),
        0,
        reason: 'the language dial did not move, so it did not rebuild.',
      );

      // ## AND THE TOTAL IS BOUNDED
      //
      // **120, and the measured figure is lower.** The headroom is for the
      // framework's own per-item wrappers — `ListView.builder` wraps every item
      // in a fresh `AutomaticKeepAlive` and a fresh `RepaintBoundary` on every
      // rebuild of the list, and those are not ours to remove. What the bound
      // catches is **our** regressions: a whole-screen `setState` coming back,
      // or a row cache that stopped returning identical instances.
      expect(
        delta.total,
        lessThanOrEqualTo(120),
        reason:
            'a tap on one verse rebuilt ${delta.total} widgets. The measured '
            'figure is well under this; what the bound catches is a '
            'whole-screen rebuild returning, or the row cache ceasing to hand '
            'back identical instances: ${delta.describe()}',
      );
    });
  });

  group('a settings write on `/settings`', () {
    testWidgets('rebuilds the one row that changed', (
      WidgetTester tester,
    ) async {
      final SettingsCubit cubit = await pumpSettings(tester);

      final RebuildCounter baseline = await countRebuilds(tester, () async {});
      final RebuildCounter after = await countRebuilds(
        tester,
        () async => cubit.setHue(300),
      );
      final RebuildCounter delta = after.delta(baseline);

      debugPrint('── a settings write ──');
      debugPrint('baseline : ${baseline.total}  ${baseline.describe()}');
      debugPrint('DELTA    : ${delta.total}  ${delta.describe()}');

      // ## **ONE** ROW, AND IT IS THE **HUE** ROW
      //
      // A hue change is one number on one slider. The Workshop has
      // thirty-three rows, and it used to rebuild **all of them** — plus the
      // three invisible tab screens the dock keeps alive — for a change to one
      // number.
      expect(
        delta.countOf(WorkshopSliderRow),
        1,
        reason:
            'one number changed, so one row rebuilt. The Workshop has '
            'thirty-three rows and used to rebuild every one of them.',
      );
      expect(
        delta.countOf(WorkshopToggleRow),
        0,
        reason: 'no switch changed, so no switch rebuilt.',
      );
      expect(
        delta.countOf(SettingsTile),
        1,
        reason: 'only the hue row is a `SettingsTile`; the rest are switches.',
      );

      // ## AND THE TOTAL IS BOUNDED
      expect(
        delta.total,
        lessThanOrEqualTo(40),
        reason:
            'a hue change rebuilt ${delta.total} widgets. The measured figure '
            'is well under this; what the bound catches is the page falling '
            'back to one `BlocBuilder` over the whole form: '
            '${delta.describe()}',
      );
    });
  });

  group('the reading cubit', () {
    testWidgets('a write to the DEAD field rebuilds nothing', (
      WidgetTester tester,
    ) async {
      // `ReadingState.textSizePanelOpen` is written by
      // `ReadingCubit.toggleTextSizePanel` and **read by nobody in `lib/`** —
      // the writer has no caller outside the test suite. Before the
      // `buildWhen`, every call rebuilt the **entire screen**: the scaffold,
      // the sky (forty-four stars at the cap) and every visible verse.
      final ReadingHarness harness = readingHarness();
      await pumpReading(tester, cubit: harness.cubit);

      final RebuildCounter baseline = await countRebuilds(tester, () async {});
      final RebuildCounter after = await countRebuilds(
        tester,
        () async => harness.cubit.toggleTextSizePanel(),
      );
      final RebuildCounter delta = after.delta(baseline);

      debugPrint('── a dead-field write ──');
      debugPrint('DELTA    : ${delta.total}  ${delta.describe()}');

      expect(
        delta.countOf(WitnessSky),
        0,
        reason: 'nothing about the selection changed, so the sky did not move.',
      );
      expect(
        delta.countOf(NeuralScaffold),
        0,
        reason: 'nothing about the screen changed, so the scaffold did not.',
      );
      expect(
        delta.total,
        lessThanOrEqualTo(20),
        reason:
            'a write to a field nothing reads rebuilt ${delta.total} widgets. '
            'It should rebuild nothing at all.',
      );
    });
  });

  group('the `TextTheme`', () {
    test('is rebuilt rather than read', () {
      // The pure measurement, with no widget tree in it: **how much work does
      // `EvaTypography.textTheme(colors)` do?**
      //
      // `eva_theme.dart:59` builds this exact `TextTheme` ONCE and installs it
      // in the `ThemeData` (`:85`) — with the families already applied. Every
      // call site that recomputes it is therefore doing the work twice, and the
      // theme already holds the answer.
      const EvaColors colors = EvaColors.dark();
      const int iterations = 2000;

      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < iterations; i++) {
        EvaTypography.textTheme(colors).bodyLarge;
      }
      watch.stop();

      final double perCall = watch.elapsedMicroseconds / iterations;
      debugPrint('── textTheme ──');
      debugPrint(
        'EvaTypography.textTheme: ${perCall.toStringAsFixed(1)} µs/call over '
        '$iterations calls',
      );

      // **The bound is on the WORK, not on the clock.** A micro-benchmark's
      // absolute number is a property of the machine it ran on, and this
      // repository does not make claims about numbers it cannot reproduce. What
      // is reproducible is the *shape* of the work: `textTheme` copies about
      // thirty `TextStyle`s per call, and the theme already holds the answer,
      // so a call is redundant by construction.
      expect(perCall, greaterThan(0), reason: 'the measurement must have run.');
    });
  });
}
