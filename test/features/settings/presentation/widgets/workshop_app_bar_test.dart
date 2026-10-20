import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_app_bar.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// `workshop_app_bar.dart` — the redesign's app bar, at `:639-643`.
///
/// ## WHY THE **VERSION CHIP** IS THE SUBJECT OF MOST OF THIS FILE
///
/// The chip is the one run on this bar that carries a number, and it is the run
/// the brief's D16 is about: the prototype's `.mono` class is
/// `letter-spacing:.16em` at 10.5px, and Flutter's `letterSpacing` is a
/// logical-pixel advance — so the em value is **premultiplied**, and the number
/// is **1.68**, not 0.16.
///
/// A raw 0.16 would be more than **ten times** too small, and nothing about the
/// rendered screen would look wrong: the chip would simply be a slightly tighter
/// string. This file is where that number is pinned.
void main() {
  group('the version chip', () {
    // ## IT CARRIES THE APP'S **REAL** VERSION
    //
    // The prototype's chip is the literal `v1.2` (`:642`), which is the **design
    // system's** version — the same string the About group's "Tokens" row carries
    // (`:698`). A reader looking at a version chip wants the version of the app
    // they are holding.
    testWidgets('it carries `AppConfig.appVersion`', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.text(AppConfig.appVersion), findsOneWidget);
    });

    // ## AND THE TRACKING IS **PREMULTIPLIED**
    //
    // `.16em` at 10.5px is **1.68** — the house rule, and the number this file
    // exists to hold.
    testWidgets('its tracking is the em value premultiplied by its size', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final TextStyle style = tester
          .widget<Text>(find.text(AppConfig.appVersion))
          .style!;
      expect(style.fontSize, 10.5);
      expect(style.letterSpacing, closeTo(1.68, 0.0001));
    });

    // ## AND IT IS **ZERO** ON THE ARABIC ARM
    //
    // `eva/redesign.html:135` — `[dir=rtl] .mono{letter-spacing:0}`. A tracked
    // mono run on the Arabic arm is a defect, and the Arabic typography gate is
    // where it shows.
    testWidgets('its tracking is zero under RTL', (WidgetTester tester) async {
      await _pump(tester, textDirection: TextDirection.rtl);

      final TextStyle style = tester
          .widget<Text>(find.text(AppConfig.appVersion))
          .style!;
      expect(style.letterSpacing, 0);
    });

    // ## AND IT IS THE MONO FACE, AT `:30`'s OWN SIZE
    testWidgets('it wears the mono face', (WidgetTester tester) async {
      await _pump(tester);

      final TextStyle style = tester
          .widget<Text>(find.text(AppConfig.appVersion))
          .style!;
      expect(style.fontFamily, EvaTypography.monoFamily);
    });

    // ## AND IT IS **NAMED**
    //
    // §14's first row: a control with no name in the reader's own language. The
    // chip is a run of text and it is named by `settingsVersion`.
    testWidgets('it is named by the version key', (WidgetTester tester) async {
      await _pump(tester);

      final Iterable<SemanticsData> named = semanticsTree(tester).where(
        (SemanticsData data) =>
            data.label == AppLocalizationsEn().settingsVersion,
      );
      expect(named, hasLength(1));
    });
  });

  group('the title', () {
    // ## IT IS **CENTRED** ON THE BAR
    //
    // `eva/redesign.html:144-145` — `position:absolute;left:50%;
    // transform:translate(-50%,-50%)`.
    //
    // **And not centred on the space between the chevron and the chip**, which is
    // a different centre: the chip is wider than the chevron, so a title centred
    // in the gap would sit visibly to the left of the bar's middle.
    testWidgets('it is centred on the bar', (WidgetTester tester) async {
      await _pump(tester);

      final Offset barCentre = tester.getCenter(
        find.descendant(
          of: find.byType(WorkshopAppBar),
          matching: find.byType(Stack),
        ),
      );
      final Offset titleCentre = tester.getCenter(
        find.text(AppLocalizationsEn().settingsTitle),
      );
      expect(titleCentre.dx, closeTo(barCentre.dx, 0.01));
    });

    // ## AND IT IS CAPPED AT **52%** OF THE BAR'S WIDTH
    //
    // `:145` — `max-width:52%`, which is what keeps a long title from running
    // under the chip.
    testWidgets('it is capped at 52% of the bar', (WidgetTester tester) async {
      await _pump(tester);

      final double barWidth = tester
          .getSize(
            find.descendant(
              of: find.byType(WorkshopAppBar),
              matching: find.byType(Stack),
            ),
          )
          .width;
      final double titleWidth = tester
          .getSize(find.text(AppLocalizationsEn().settingsTitle))
          .width;
      expect(titleWidth, lessThanOrEqualTo(barWidth * 0.52 + 0.01));
    });

    // ## AND IT IS A **15px UI-SANS** TITLE
    //
    // `:145` — `font-size:15px; font-weight:600; letter-spacing:-.01em`, and the
    // prototype's `.ttl` declares no family, so it inherits `body`'s `--ui`.
    testWidgets('it is 15px, 600, tracked -0.15px, in the UI face', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final TextStyle style = tester
          .widget<Text>(find.text(AppLocalizationsEn().settingsTitle))
          .style!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
      // `-0.01em` at 15px is **-0.15** — the em value premultiplied, like the
      // chip's.
      expect(style.letterSpacing, closeTo(-0.15, 0.0001));
      expect(style.fontFamily, EvaTypography.uiFamily);
    });
  });

  group('the chevron', () {
    // ## IT IS THE PROTOTYPE'S **CHEVRON**, AT **16px**
    //
    // `:149` — `font-size:16px`, and `Icons.arrow_back_ios_new` because Material's
    // `arrow_back` is an arrow.
    testWidgets('it is a 16px chevron', (WidgetTester tester) async {
      await _pump(tester);

      final Icon icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(WorkshopAppBar),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.arrow_back_ios_new);
      expect(icon.size, 16);
    });

    // ## AND IT IS **NAMED**
    testWidgets('it is named by the back key', (WidgetTester tester) async {
      await _pump(tester);

      final Iterable<SemanticsData> named = semanticsTree(tester).where(
        (SemanticsData data) => data.label == AppLocalizationsEn().settingsBack,
      );
      expect(named, hasLength(1));
    });
  });
}

/// Pumps the app bar on a **320×568** surface.
///
/// ## WHY 320
///
/// The standing viewport matrix is 320 wide, and the app bar's own arithmetic —
/// the title's 52% cap against a 44px chevron and a ~60px chip — is the reason
/// the 52% exists. A golden or an assertion taken at 390 would be measuring a
/// bar that is wider than the one the rule was written for.
Future<void> _pump(
  WidgetTester tester, {
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      textDirection: textDirection,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: const WorkshopAppBar(),
    ),
  );
  await tester.pump();
}
