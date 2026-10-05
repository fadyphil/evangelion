import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';
import '../../../../support/settings_harness.dart';

/// §14: "text scales to 1.22× without overflow at 320px width" — for `/reading`.
///
/// ## THE NUMBER IS §14'S AND THE OTHER SUITES ALREADY HAVE IT
///
/// `kNarrowSurface` is `Size(320, 568)` and `kEvaRequiredTextScale` is `1.22`, both
/// declared in `design_system_harness.dart` and both quoted from §14. They are read
/// here rather than repeated, so this file cannot drift from `home_text_scale_test.dart`
/// and `login_text_scale_test.dart`, which assert the same requirement for their
/// screens. §14 is a statement about **every** screen that renders text, so
/// `/reading` — the one screen whose entire purpose is rendering text — is the
/// strictest case of it, and it is asserted in both directions of the mirror.
///
/// ## AND EVERY STATE IS MOUNTED, BECAUSE A LAYOUT IS NOT ONE THING
///
/// `home_text_scale_test.dart` gives the argument: loading, ready, failed, Arabic and
/// the disclosed `Aa` panel all lay out differently, and the states with the most text
/// are the ones that wrap. The revealed disclosure matters most here — it is the only
/// `/reading` state with a `Row` of three controls across the CTA, and §14's narrowest
/// surface is 320 wide.
void main() {
  /// The surface and the scale, named so a failure reads as §14's own words.
  const Size surface = kNarrowSurface;
  const double scale = kEvaRequiredTextScale;

  group('at 320x568 and 1.22x, no state overflows', () {
    testWidgets('ready, English', (WidgetTester tester) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );

      _expectNoOverflow(tester, AppLocalizationsEn());
    });

    testWidgets('ready, Arabic — taller script and a longer caption', (
      WidgetTester tester,
    ) async {
      // Arabic script is *taller* at the same point size, the Arabic caption is
      // longer for the same count, and `WordReference.tsx:16` shows the quotation
      // marks are Arabic `«…»` rather than the English `‹…›` — so the RTL arm is not
      // a mirror of the LTR one and is mounted separately.
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(
        tester,
        cubit: h.cubit,
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      _expectNoOverflow(tester, AppLocalizationsAr());
    });

    testWidgets('the failed state, whose repository message is a sentence', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.failure(readingFailure),
      );
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );

      // The one state with neither a passage **nor** a CTA: there is nothing to
      // reflect on, so both are gone and what must be on screen is the error.
      _expectNoOverflow(tester, AppLocalizationsEn(), withPassage: false);
      expect(find.byType(ErrorView), findsOneWidget);
    });

    testWidgets('the `Aa` panel OPEN — a row of controls over the CTA', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );

      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);

      // The anti-vacuity half: the disclosure has to be **on screen**, or "no
      // overflow" is a statement about the closed panel twice.
      expect(find.byType(FontSizeStepper), findsOneWidget);
      _expectNoOverflow(tester, AppLocalizationsEn());
    });

    testWidgets('and with the step at its smallest, where the CTA is widest', (
      WidgetTester tester,
    ) async {
      // Step 1 is the smallest text in the table, which is the worst case for a
      // `Row` of controls: `FontSizeStepper` is `mainAxisSize: MainAxisSize.min`, so
      // a *smaller* label is also a narrower row and this is a real measurement
      // rather than the interesting one. The interesting direction is step 5, where
      // the track and both buttons sit at their widest — and §14's surface is 320
      // wide, so the panel's bottom edge is where a `RenderFlex` would report.
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );
      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);

      // **The initial step is read from the injected scaler**, which this harness
      // sets to `scale` (1.22) — and 1.22 is §5.2's *fifth* row, so the page opens on
      // step 5 here rather than step 3. That is the single-input world showing through
      // a test seam: the harness's `textScale` is now the app's step, not a second
      // factor, so the loop below runs from wherever the page actually is.
      final int opened = fontStepFromScaler(const TextScaler.linear(scale));
      for (int i = 0; i < opened - kFontStepMin; i++) {
        await tester.tap(find.byIcon(Icons.remove));
        await pumpReadingFrames(tester, 2);
      }
      expect(
        settingsHandleOf(tester).settings.fontStep,
        kFontStepMin,
        reason:
            'four taps from step 5, because the page really did open on step 5',
      );

      _expectNoOverflow(tester, AppLocalizationsEn());
    });
  });

  group('ONE input, and the dead zone Phase 7 recorded is **gone**', () {
    // ## WHAT THIS GROUP REPLACED, AND WHY THE REPLACEMENT IS THE POINT
    //
    // The group it displaces was called "the two scalers compose rather than replace
    // one another", and it had **two** assertions that only a two-input rule can
    // satisfy:
    //
    // * "a raised OS font size survives even the smallest step" — at step 1 with the
    //   platform at 1.22, `body × 0.90 × 1.22`;
    // * "the documented dead zone is REAL at 1.22, not a guess" — steps 3, 4 and 5 all
    //   rendering `hasLength(1)`, i.e. **one** rendered size for three distinct
    //   positions.
    //
    // Both are gone because the composition is. `readingTextScalerFor` is deleted;
    // `MaterialApp.builder` installs `evaScalerFor(step)` and nothing multiplies it by
    // anything. Phase 9's author wrote that the fix "is not another rule: one
    // persisted preference replaces two inputs, so there is one scale and nothing to
    // compose", and this group is that claim's proof in both directions: five
    // positions, five sizes, and **no platform input at all**.
    testWidgets('the platform scale is not an input any more', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      // **1.5 is the interesting number**: above §14's 1.22, above the 1.109 the old
      // rule collapsed above, and a value the old composition would have capped.
      await pumpReading(tester, cubit: h.cubit, size: surface, textScale: 1.5);

      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(ScriptureBlock)))
            .scale(1),
        1.0,
        reason:
            'the harness injects 1.5 through the platform `MediaQuery`, and the '
            'scaler the scripture renders at is step 3 — the table identity. Under '
            'the deleted rule this would have been 1.5.',
      );
      expect(
        // The table, read directly: `SettingsHandle.fontScale` no longer exists because
        // the handle is pure Dart and `evaScalerFor` is not (`settings_handle.dart`
        // records why). The claim is unchanged — the *stored* step and the *rendered*
        // scale are the same number — and it is read from the table rather than through
        // a getter that could agree with itself.
        evaScalerFor(settingsHandleOf(tester).settings.fontStep).scale(1),
        1.0,
        reason:
            'and the persisted preference is the same number from the other side, so '
            'the rendered scale and the stored step cannot disagree',
      );
    });

    testWidgets(
      'all FIVE positions are distinct, and they are the table\'s rows',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit, size: surface);

        final Map<int, double> byStep = <int, double>{};
        for (int step = kFontStepMin; step <= kFontStepMax; step++) {
          await settingsHandleOf(tester).setFontStep(step);
          await pumpReadingFrames(tester, 3);
          byStep[step] = MediaQuery.textScalerOf(
            tester.element(find.byType(ScriptureBlock)),
          ).scale(1);
        }

        expect(
          byStep.values.toSet(),
          hasLength(kFontStepMax),
          reason:
              'five positions, five rendered sizes. THIS is the assertion the old dead '
              'zone failed: at a platform above 1.109 the old rule gave steps 3, 4 and '
              '5 the same number, and a reader who had raised their OS font size found '
              'the control\'s top half inert. The dead zone is gone because there is '
              'no ceiling to collapse into.',
        );
        expect(
          byStep,
          <int, double>{1: 0.90, 2: 0.95, 3: 1.00, 4: 1.10, 5: 1.22},
          reason:
              'and each one is §5.2\'s own row, read through the table rather than '
              'restated — `eva_typography.dart` refuses to have the numbers in prose '
              'because a copy is a copy',
        );
      },
    );

    testWidgets('§14\'s 1.22 is reached THROUGH THE CONTROL, which is what the '
        'requirement now means', (WidgetTester tester) async {
      // §14 asks the app to survive 1.22× without overflow. Under the deleted rule
      // that number could arrive from the OS; now it can only arrive from step 5,
      // which makes the requirement **testable at the control** rather than at a
      // platform setting this client does not own.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, size: surface);

      await settingsHandleOf(tester).setFontStep(kFontStepMax);
      await pumpReadingFrames(tester, 4);

      final double body = ScriptureBlock.fontSizeFor(ReadingLanguage.english);
      expect(
        _effectiveScriptureSize(tester),
        closeTo(body * scale, 0.001),
        reason:
            '§14\'s number, reached by the reader\'s own hand rather than by their '
            'OS, and rendered at the top of the table the app was laid out for',
      );
      _expectNoOverflow(tester, AppLocalizationsEn());
    });

    testWidgets(
      'and the stepper\'s knob and the rendered size cannot disagree',
      (WidgetTester tester) async {
        // The property `fontStepFromScaler` exists for, asserted in the running app:
        // the page reads the step **back out of the installed scaler** rather than
        // holding a second copy, so a mismatch between the knob and the type is
        // unexpressible.
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit, size: surface);
        await tester.tap(find.byIcon(Icons.format_size));
        await pumpReadingFrames(tester, 4);

        for (int step = kFontStepMin; step <= kFontStepMax; step++) {
          await settingsHandleOf(tester).setFontStep(step);
          await pumpReadingFrames(tester, 3);
          final TextScaler installed = MediaQuery.textScalerOf(
            tester.element(find.byType(ScriptureBlock)),
          );
          expect(
            fontStepFromScaler(installed),
            step,
            reason: 'the slider announces the step the tree is actually rendering at',
          );
          expect(
            _sliderValue(tester, AppLocalizationsEn().readingFontSize),
            step.toString(),
            reason: 'and the slider node\'s own value agrees with it',
          );
        }
      },
    );
  });

  group('the geometry that is fixed rather than scaled', () {
    testWidgets('the CTA padding is the prototype value at any scale', (
      WidgetTester tester,
    ) async {
      // §14 scales *text*. Padding is layout, and `ReadingPage` publishes it so a
      // geometry test can read it rather than re-derive it — `home_text_scale_test.dart`
      // does the same for `TodayReadingPanel`.
      expect(
        ReadingPage.contentPadding,
        const EdgeInsets.fromLTRB(24, 28, 24, 130),
      );
      expect(StickyCta.padding, const EdgeInsets.fromLTRB(24, 20, 24, 32));
    });
  });
}

/// Asserts that nothing in the tree reported an overflow, and that the screen
/// actually drew something.
///
/// **[WidgetTester.takeException] is null, and that is the mechanism.** A `RenderFlex`
/// overflow raises a `FlutterError` through `FlutterError.onError`, which
/// `flutter_test` records and hands back from `takeException()`; there is no "did it
/// overflow" property on the render objects, so this is the only way a reader can ask
/// the question. `home_text_scale_test.dart` carries the negative control that proves
/// it — a column built to overflow at this scale returns a non-null exception.
void _expectNoOverflow(
  WidgetTester tester,
  AppLocalizations strings, {
  bool withPassage = true,
}) {
  expect(tester.takeException(), isNull);
  // The anti-vacuity half: a screen that rendered nothing cannot overflow. So the
  // passage **and** the CTA are both required to be on screen — and the failure state
  // is the one place `withPassage` is false, because it has neither, which is the
  // whole point of it: there is nothing to reflect on.
  if (withPassage) {
    expect(
      find.byType(ScriptureBlock),
      findsOneWidget,
      reason: 'the passage did not render, so "no overflow" is vacuous here',
    );
    expect(
      find.byType(StickyCta),
      findsOneWidget,
      reason: 'and neither did the CTA, which is the other half of the screen',
    );
    expect(find.text(strings.readingBeginReflection), findsOneWidget);
  } else {
    expect(find.byType(ScriptureBlock), findsNothing);
    expect(find.byType(StickyCta), findsNothing);
  }
}

/// The size a reader's eye meets for the scripture body, in logical pixels.
///
/// **[MediaQuery.textScalerOf] at the block, not `RichText.style.fontSize`.** The
/// composed scaler is installed on a `MediaQuery` subtree and applied inside
/// `RenderParagraph`, so the `TextStyle` a test can read from a widget is the
/// **unscaled token** — asserting on it would pass for `MediaQuery` never having
/// been installed at all, which is the defect this group exists to catch.
/// The slider node's own announced value.
///
/// Read through the **shared** `semanticsTree` walk rather than a private one, for
/// `design_system_harness.dart`'s stated reason: one copy of the fixture, so the
/// copies cannot drift — and this walk has a fail-closed assertion built into it that
/// a hand-rolled one would lose.
String _sliderValue(WidgetTester tester, String trackLabel) {
  for (final SemanticsData node in semanticsTree(tester)) {
    if (node.label == trackLabel && node.flagsCollection.isSlider) {
      return node.value;
    }
  }
  throw StateError(
    'no slider node labelled "$trackLabel" in the tree — the `Aa` disclosure is '
    'closed, so there is no track to announce.',
  );
}

double _effectiveScriptureSize(WidgetTester tester) {
  final TextScaler scaler = MediaQuery.textScalerOf(
    tester.element(find.byType(ScriptureBlock)),
  );
  return scaler.scale(ScriptureBlock.fontSizeFor(ReadingLanguage.english));
}
