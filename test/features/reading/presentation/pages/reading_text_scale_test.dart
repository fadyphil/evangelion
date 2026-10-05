import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/reading_text_scale.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';

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

      for (int i = 0; i < ReadingCubit.defaultFontStep - kFontStepMin; i++) {
        await tester.tap(find.byIcon(Icons.remove));
        await pumpReadingFrames(tester, 2);
      }
      expect(h.cubit.state.fontStep, kFontStepMin);

      _expectNoOverflow(tester, AppLocalizationsEn());
    });
  });

  group('the two scalers compose rather than replace one another', () {
    // ## AND THE NUMBERS COME FROM §5.2's OWN TABLE, WHICH HAS STEP 3 AT **1.00**
    //
    // `evaScalerFor` is 0.90 / 0.95 / **1.00** / 1.10 / 1.22, so the default step
    // changes nothing on its own and every assertion below pairs the default with a
    // step that *does*. That is why the first test reads `closeTo(19 × 1.22)` and
    // looks like it is asserting nothing happened: at the default the composed scaler
    // and the platform scaler agree **exactly**, and a `max` rule would too — so the
    // interesting pairings are 1 and 5.
    testWidgets('at the default step the platform scale passes through', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );

      // The **number**, read from the `MediaQuery` the block is actually inside.
      // `readingTextScale.dart`'s doc says the composed scaler is installed on a
      // `MediaQuery` subtree rather than threaded through constructors, so this is the
      // only probe that reads what a reader's eye meets — `RichText.style.fontSize`
      // would still be the unscaled token and would pass for an unwired subtree.
      expect(evaScalerFor(ReadingCubit.defaultFontStep).scale(1), 1.0);
      expect(
        _effectiveScriptureSize(tester),
        closeTo(
          ScriptureBlock.fontSizeFor(ReadingLanguage.english) * scale,
          0.001,
        ),
        reason:
            '§14 requires 1.22× and step 3 is the table\'s 1.00 row, so the '
            'composed value and the platform value are the same number here',
      );
    });

    testWidgets(
      'and the step multiplies it — on a device that does NOT scale',
      (WidgetTester tester) async {
        // Platform **1.0**, which is the ordinary install, and the only place the two
        // inputs can be told apart: `max` would render all of steps 1, 2 and 3 at 1.00×
        // here and the reader's drag toward "smallest" would do nothing for three of
        // five positions. The product renders 0.90× at step 1.
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit, size: surface);
        final double body = ScriptureBlock.fontSizeFor(ReadingLanguage.english);

        h.cubit.setFontStep(kFontStepMin);
        await pumpReadingFrames(tester, 2);
        expect(_effectiveScriptureSize(tester), closeTo(body * 0.90, 0.001));

        h.cubit.setFontStep(kFontStepMax);
        await pumpReadingFrames(tester, 2);
        expect(
          _effectiveScriptureSize(tester),
          closeTo(body * 1.22, 0.001),
          reason:
              'and 1.22 is §14\'s requirement, reached through the control rather '
              'than through the platform setting',
        );
      },
    );

    testWidgets('the ceiling stops it there', (WidgetTester tester) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, size: surface, textScale: 2.0);

      expect(
        _effectiveScriptureSize(tester),
        closeTo(
          ScriptureBlock.fontSizeFor(ReadingLanguage.english) *
              kEvaScaleCeiling,
          0.001,
        ),
        reason:
            '1.00 × 2.0 is past the only size this app has ever been laid out '
            'for, so the top of §5.2\'s table caps it',
      );
    });

    testWidgets('a raised OS font size survives even the smallest step', (
      WidgetTester tester,
    ) async {
      // The rule `reading_text_scale.dart` rejects, mounted so the rejection is
      // visible. At step 1 with the platform at 1.22, "the step replaces the
      // platform" renders 0.90× and the sanctuary ignores the reader's own
      // accessibility setting; the product renders 1.098×, which is 22% larger.
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );

      h.cubit.setFontStep(kFontStepMin);
      await pumpReadingFrames(tester, 2);

      final double body = ScriptureBlock.fontSizeFor(ReadingLanguage.english);
      expect(
        _effectiveScriptureSize(tester),
        closeTo(body * 0.90 * scale, 0.001),
      );
      expect(
        _effectiveScriptureSize(tester),
        greaterThan(body * 0.90),
        reason:
            'and a replacing rule would put `body × 0.90` here — 22% below what '
            'the reader\'s own OS setting asks for, in the one screen where reading '
            'is hardest',
      );
    });

    testWidgets('and the documented dead zone is REAL at 1.22, not a guess', (
      WidgetTester tester,
    ) async {
      // `reading_text_scale.dart` states the cost of the cap in a table: above a
      // platform scale of 1.109 the top three steps all render at the ceiling,
      // because 1.10 × 1.109 already reaches 1.22. §14's own 1.22 is above 1.109, so
      // this is the requirement's own surface — and the assertion is that the dead
      // zone is **present**, so a change to the table cannot silently remove a cost
      // the file still claims in prose.
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        size: surface,
        textScale: scale,
      );

      final Set<double> sizes = <double>{};
      for (int step = 3; step <= kFontStepMax; step++) {
        h.cubit.setFontStep(step);
        await pumpReadingFrames(tester, 2);
        sizes.add(_effectiveScriptureSize(tester));
      }
      expect(
        sizes,
        hasLength(1),
        reason:
            'three distinct steps, one rendered size — which is the cost §14 '
            'pays, and Phase 9 owns',
      );
      expect(
        sizes.single,
        closeTo(
          ScriptureBlock.fontSizeFor(ReadingLanguage.english) * scale,
          0.001,
        ),
      );
    });
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
double _effectiveScriptureSize(WidgetTester tester) {
  final TextScaler scaler = MediaQuery.textScalerOf(
    tester.element(find.byType(ScriptureBlock)),
  );
  return scaler.scale(ScriptureBlock.fontSizeFor(ReadingLanguage.english));
}
