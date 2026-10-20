import 'package:evangelion/app/sky_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';
import '../../../../support/settings_harness.dart';

/// The seven `eva.sky.pref.*` preferences, as `/reading` consumes them.
///
/// ## WHY THE PURE RULES ARE TESTED **HERE** AND NOT IN A WIDGET
///
/// `eva/redesign.html:1488` writes the brightness as `--starB = value/100` and
/// `:1489` combines the Twinkle switch with reduce motion. Both are rules, and
/// AGENT_CONTEXT §6 says a rule that lives inside a `build` method is untested
/// logic wearing a costume — so they are named functions
/// (`reading_page.dart`'s `skyBrightnessFor` and `skyTwinklesFor`) and they are
/// tested here, on their own, against the prototype's own numbers.
///
/// ## AND WHY THE WIDGET ASSERTIONS READ THE **WIDGET'S** PROPERTIES
///
/// `WitnessSky` takes the sky's knobs as parameters, so a reader's choice is
/// visible on the widget the page built. Reading them off the widget is what
/// makes the claim "the preference reached the sky" rather than "the
/// preference was stored" — the store is the settings' business, and
/// `settings_cubit_test.dart` owns it.
void main() {
  group('the brightness conversion', () {
    test('30…150 maps to 0.3…1.5', () {
      // `eva/redesign.html:670` — the slider is 30…150 — and `:1488` writes
      // `--starB` as `value/100`, which is the range `WitnessSky.brightness`
      // takes.
      expect(skyBrightnessFor(30), 0.3);
      expect(skyBrightnessFor(100), 1.0);
      expect(skyBrightnessFor(150), 1.5);
    });
  });

  group('the twinkle rule', () {
    test('the switch alone decides', () {
      expect(skyTwinklesFor(twinkle: true, reducedMotion: false), isTrue);
      expect(skyTwinklesFor(twinkle: false, reducedMotion: false), isFalse);
    });

    test('and reduce motion stills the sky on its own', () {
      // `eva/redesign.html:1489` — `notwinkle` when the switch is off **or**
      // reduce motion is on — and `:1491` says the same from the other side.
      expect(skyTwinklesFor(twinkle: true, reducedMotion: true), isFalse);
      expect(skyTwinklesFor(twinkle: false, reducedMotion: true), isFalse);
    });
  });

  group('the sky the reader configured', () {
    testWidgets('every knob reaches the widget', (WidgetTester tester) async {
      // ## THE HARNESS ORDER MATTERS
      //
      // `settingsHarness()` registers the cubit and the handle in the locator,
      // and `pumpReading` installs the scope over the page with **that** handle
      // — so the write below is the same write `/settings` makes, and the page
      // rebuilds through the scope's announcement.
      //
      // **AND IT IS THE CUBIT'S WRITE, NOT THE HANDLE'S.** The handle carries
      // no sky writers: `/reading` *reads* the seven and writes none of them,
      // and `/settings` — which may name its own cubit — writes them. The
      // handle's job here is to be the reader.
      final SettingsHarness harness = settingsHarness();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      await harness.cubit.setStarShape(SkyStarShape.star);
      await harness.cubit.setStarField(SkyStarField.full);
      await harness.cubit.setStarBrightness(150);
      await harness.cubit.setConstellationsOn(on: false);
      await tester.pump();

      final WitnessSky sky = tester.widget<WitnessSky>(find.byType(WitnessSky));
      expect(
        sky.shape,
        SkyStarShape.star,
        reason: 'the shape the reader chose',
      );
      expect(sky.field, SkyStarField.full, reason: 'the band the reader chose');
      expect(
        sky.brightness,
        1.5,
        reason:
            '150/100 — the prototype writes `--starB` as `value/100` '
            '(`eva/redesign.html:1488`)',
      );
      expect(
        sky.showConstellation,
        isFalse,
        reason:
            'the Constellations switch, which removes the svg (`:1484-1485`)',
      );
      expect(
        sky.twinkle,
        isTrue,
        reason: 'the Twinkle switch is on and reduce motion is off',
      );
    });

    testWidgets('and reduce motion stills it', (WidgetTester tester) async {
      final SettingsHarness harness = settingsHarness();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      await harness.handle.setReducedMotion(reduced: true);
      await tester.pump();

      expect(
        tester.widget<WitnessSky>(find.byType(WitnessSky)).twinkle,
        isFalse,
        reason:
            'the Twinkle switch is still on — it is the READER\'S reduce-motion '
            'preference that stills the sky, and the two are combined (never '
            'substituted): `eva/redesign.html:1489`',
      );
    });
  });

  group('the Stars-off gate', () {
    testWidgets('the sky is not drawn at all', (WidgetTester tester) async {
      final SettingsHarness harness = settingsHarness();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      expect(find.byType(WitnessSky), findsOneWidget);

      await harness.cubit.setStarsOn(on: false);
      await tester.pump();

      expect(
        find.byType(WitnessSky),
        findsNothing,
        reason:
            'Stars-off HIDES the sky. The prototype stops drawing it '
            '(`addStar` returns early at `eva/redesign.html:1144` and '
            '`drawConstellation` refuses at `:1172`), and this client does not '
            'mount the widget at all',
      );
    });

    testWidgets('and no verse is lit while it is off', (
      WidgetTester tester,
    ) async {
      // ## THE GATE, AND WHY IT IS THE **CALLER'S**
      //
      // `SkyCubit.record`'s doc says the cubit does not check the switch, so
      // the caller must skip the record — and this is that caller. **The
      // prototype's Stars-off also CLEARS the sky** (`:1483`), and this client
      // deliberately does not: the sky is a persisted record of what the reader
      // has read, and a decoration switch must not delete it.
      final List<SkyEntry> recorded = <SkyEntry>[];
      final SkyHandle sky = SkyHandle(
        entriesReader: () => const <SkyEntry>[],
        recordEntry: (SkyEntry entry) async {
          recorded.add(entry);
        },
      );
      final SettingsHarness harness = settingsHarness();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      await tester.pumpWidget(
        SkyScope(
          handle: sky,
          child: evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: settingsScope(tester, ReadingPage(cubit: h.cubit)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await pumpReadingFrames(tester, 2);

      await harness.cubit.setStarsOn(on: false);
      await tester.pump();

      // Scroll to the bottom, which drags every verse across the 60 % threshold.
      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpReadingFrames(tester, 3);

      expect(
        recorded,
        isEmpty,
        reason:
            'the gate skips the record while Stars is off — otherwise the next '
            'scroll pass re-lights what the switch just stopped, which is '
            'exactly what `SkyCubit.record`\'s doc warns about',
      );
    });

    testWidgets('and while it is on, a verse IS lit', (
      WidgetTester tester,
    ) async {
      // **The control for the gate above**: a gate that is always closed would
      // pass it, so the same arrangement with Stars on must light a star.
      final List<SkyEntry> recorded = <SkyEntry>[];
      final SkyHandle sky = SkyHandle(
        entriesReader: () => const <SkyEntry>[],
        recordEntry: (SkyEntry entry) async {
          recorded.add(entry);
        },
      );
      // **The handle is registered and not used**: the scope above the page
      // needs one, and the default install's preferences are the ones under
      // test — Stars is on.
      settingsHarness();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      await tester.pumpWidget(
        SkyScope(
          handle: sky,
          child: evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: settingsScope(tester, ReadingPage(cubit: h.cubit)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await pumpReadingFrames(tester, 2);

      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpReadingFrames(tester, 3);

      expect(
        recorded,
        isNotEmpty,
        reason:
            'Stars is on, so the observer lights a verse. The gate above is a '
            'gate and not a disconnection',
      );
    });
  });
}
