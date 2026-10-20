import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/settings_harness.dart';

/// §14: *"text scales to 1.22× without overflow at 320px width"* — for the
/// Workshop.
///
/// ## WHY THIS SUITE EXISTS, AND WHY IT IS **NOT** THE OLD ONE
///
/// The Phase-9 `/settings` had three groups and five controls. **This one has
/// seven groups, twenty-nine interactive controls, one action row, one preview
/// line and two static rows** — and the risk §14 names is a different one now.
///
/// **The old suite's risk was the page being too tall.** It is still that, and
/// that is not a defect: a scrolling screen meets §14 by scrolling, and the
/// assertion that says so is the one that stops "it scrolled" being read as
/// "it fit".
///
/// **The new risk is a HORIZONTAL overflow from the four-segment rows.** The
/// prototype draws `:653-656`, `:671-674` and `:676-679` with the label
/// **beside** the control, and at 320px a four-segment control and a 14.5px
/// label do not fit on one line. The client's answer is the **stacked** row —
/// the label above, the control full width — and **that answer is only
/// correct if the arithmetic holds at 1.22×**, which is what the last group
/// here measures.
///
/// ## AND WHY THERE IS **ONE** `testWidgets` PER (SCREEN, STATE, VIEWPORT)
///
/// §7: "`_reportOverflow` reports **once** per render object and only
/// `reassemble` restores it. Re-pumping the *same* tree at a second size
/// paints the banner — visibly — and reports nothing, so a three-sizes-in-one-
/// test would be blind to every overflow after the first and green."
///
/// So the three states below are three tests and not one loop, and each is
/// pumped once at 320×568.
void main() {
  /// The surface and the scale, named so a failure reads as §14's own words.
  const Size surface = kNarrowSurface;
  const double scale = kEvaRequiredTextScale;

  group('at 320x568 and 1.22x, no state overflows', () {
    // ## THE READY SCREEN
    testWidgets('the ready screen', (WidgetTester tester) async {
      await pumpSettings(tester, size: surface, textScale: scale);

      // The anti-vacuity half: the screen must be **on screen**, or "no
      // overflow" is a statement about an empty tree.
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(
        find.byType(SettingsGroup),
        findsNWidgets(7),
        reason:
            'all seven groups, because a group that failed to lay out would take '
            'its children with it — and the four-segment rows live in three of '
            'them',
      );
      expect(find.byType(EvaToggle), findsNWidgets(16));
      expect(find.byType(EvaRangeSlider), findsNWidgets(8));

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / ready / 320x568 @ 1.22x',
      );
    });

    // ## THE **ARABIC** ARM
    //
    // Arabic is *taller* at the same point size, and this screen's own strings
    // are longer in Arabic than in English for the same fact. The arm that
    // overflowed before is the one that overflowed on the Phase-9 screen too.
    testWidgets('the Arabic arm — longer words and a taller script', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        size: surface,
        textScale: scale,
        locale: const Locale('ar'),
      );

      expect(
        find.text(
          AppLocalizationsAr().languageLabelFor(ReadingLanguage.arabic),
        ),
        findsOneWidget,
        reason: 'the language control\'s current value is on screen in Arabic',
      );
      expect(find.byType(SettingsGroup), findsNWidgets(7));

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / the Arabic arm / 320x568 @ 1.22x',
      );
    });

    // ## THE **FAILURE NOTICE**
    //
    // The state Phase 10 added, and the one whose whole reason for existing is
    // that it is an inline `Row` holding a sentence beside an icon and a
    // button. A `Row` of three children at 1.22× on a 320px screen is the
    // most overflow-prone thing this screen has — and it **did** overflow by 94
    // pixels during development.
    testWidgets('the failure notice, whose sentence wraps to two lines', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        cubit: unreachableStore(),
        size: surface,
        textScale: scale,
      );
      await pumpSettingsFrames(tester, 4);

      expect(
        find.text(AppLocalizationsEn().settingsPreferencesUnavailable),
        findsOneWidget,
        reason:
            'the notice has to be on screen, or this state is the ready state '
            'with extra steps',
      );
      expect(find.byType(EvaButton), findsOneWidget);

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / the failure notice / 320x568 @ 1.22x',
      );
    });
  });

  group('the screen SCROLLS rather than fitting, and that is not an overflow', () {
    // ## AND THE MEASUREMENT IS A **MEASUREMENT**
    //
    // §14 requires no **overflow**, and a scrolling screen meets that
    // requirement by scrolling. Without this assertion, "the page fits" and
    // "the page scrolls" are the same green tick, and a future edit that
    // removed the scroll would turn this file into a statement that 1.22× fits
    // in 568.
    //
    // **The extent, not the presence of a `Scrollable`.** A `Scrollable` that
    // has nothing to scroll is a scroll view over a page that fits, and
    // asserting its presence would say nothing about the height. The extent is
    // the arithmetic: `maxScrollExtent` is the content's height less the
    // viewport's, so a positive extent **is** "the content is taller than
    // 568".
    testWidgets(
      'at 1.22x on 568 tall, the content is taller than the viewport',
      (WidgetTester tester) async {
        await pumpSettings(tester, size: surface, textScale: scale);

        final ScrollableState scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(
          scrollable.position.maxScrollExtent,
          greaterThan(0),
          reason:
              'the Workshop is twenty-nine controls and seven groups. It does not '
              'fit in 568 at 1.22x, and the scroll is what makes that correct '
              'rather than an overflow.',
        );
        expect(
          scrollable.position.maxScrollExtent +
              scrollable.position.viewportDimension,
          greaterThan(surface.height),
          reason: 'the content is taller than the viewport, in pixels',
        );
        expect(find.byType(SettingsGroup), findsNWidgets(7));

        expectNoOverflow(
          tester,
          somethingRendered: () =>
              find.byType(SettingsPage).evaluate().isNotEmpty,
          surface: '/settings / scrolling, not overflowing / 320x568 @ 1.22x',
        );
      },
    );
  });

  group('the three segmented rows fit', () {
    // ## THE ARITHMETIC, CHECKED AGAINST THE **RENDERED** PAGE
    //
    // `eva/redesign.html:653-656`, `:671-674` and `:676-679` are the three
    // four-segment (and one three-segment) controls, and the prototype draws
    // them with the label **beside** the control. At 320px that does not fit,
    // and the client's answer is the **stacked** row.
    //
    // The arithmetic, so a reviewer can check it rather than believe it:
    //
    // * the content column is `320 − 2×24` (`EvaSpacing.xxl`) = **272px**;
    // * the row's own horizontal padding takes 4px a side
    //   (`SettingsTile.padding`, `:419`) → **264px** for the row's content;
    // * the four-segment control's **minimum** is `4 × 44 = 176px` — `:183`'s
    //   `min-width:44px`, the tap-target floor the client does not shrink.
    //
    // So the control takes the row's **full 264px**, and each of the four
    // quarters is **66px** — comfortably above the 44px floor, which is what
    // makes the arrangement possible at all.
    testWidgets('the label is above the control, and the control is full width', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester, size: surface, textScale: scale);

      // **The content column**, read from the tokens rather than restated, so
      // this file cannot drift from the design system's own numbers.
      final double contentColumn = surface.width - 2 * EvaSpacing.xxl;
      expect(
        contentColumn,
        272,
        reason: '`320 − 2×24` — the arithmetic the stacking rests on',
      );
      final double rowContent =
          contentColumn - 2 * SettingsTile.horizontalPadding;
      expect(rowContent, 264, reason: 'and the row\'s own 4px a side');

      final List<(String, Type, int)> rows = <(String, Type, int)>[
        ('Curtain shape', SegmentedControl<CurtainShape>, 4),
        ('Star shape', SegmentedControl<SkyStarShape>, 4),
        ('Star field', SegmentedControl<SkyStarField>, 3),
      ];

      for (final (String title, Type type, int segments) in rows) {
        final Finder label = find.text(title);
        final Finder control = find.byType(type);

        // ## THE LABEL IS **ABOVE** THE CONTROL
        final Rect labelRect = tester.getRect(label);
        final Rect controlRect = tester.getRect(control);
        expect(
          labelRect.bottom,
          lessThanOrEqualTo(controlRect.top),
          reason:
              'the "$title" label is on its own line, above the control. The '
              'prototype draws it beside the control, and that is the divergence '
              'this arrangement exists to pay for.',
        );
        expect(
          labelRect.left,
          closeTo(controlRect.left, 0.5),
          reason:
              'and the two share a left edge, because a label stacked above a '
              'control that starts somewhere else is two columns, not one stack',
        );

        // ## AND THE CONTROL IS THE ROW'S **FULL WIDTH**
        expect(
          controlRect.width,
          closeTo(rowContent, 0.5),
          reason:
              'the "$title" control takes the row\'s whole content width. A '
              'control narrower than the row would be the prototype\'s side-by-'
              'side arrangement with the label moved, and the four segments '
              'would not fit.',
        );

        // ## AND THE SEGMENTS KEEP THE **TAP-TARGET FLOOR**
        expect(
          controlRect.width,
          greaterThanOrEqualTo(
            SegmentedControl.wideTrackMinimumWidth(segments),
          ),
          reason:
              '`:183` gives every button `min-width:44px`, so the track\'s '
              'minimum is 44 × the number of segments. A control narrower than '
              'that would shrink a segment below the floor the prototype sets.',
        );
      }

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.byType(SettingsPage).evaluate().isNotEmpty,
        surface: '/settings / the three segmented rows / 320x568 @ 1.22x',
      );
    });
  });
}

/// A cubit over a store that cannot be reached, for the failure-notice state.
///
/// **A copy of the one in `settings_accessibility_test.dart` and the one in
/// `settings_page_test.dart`, and that is a deliberate cost stated here rather
/// than an oversight.** Two files already needed it; this is the third, and
/// hoisting it into `settings_harness.dart` would give a shared failure a
/// *shared* name — `FailingSettingsRepository` is already there — but the
/// three uses differ in what they assert afterwards: the page suite drives the
/// write arm and the restore, the accessibility suite sweeps the tree, and this
/// one only needs the notice rendered at 1.22×. A three-line factory over an
/// already-shared fake is cheaper than one factory whose contract is "and also
/// do the other thing".
SettingsCubit unreachableStore() {
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
