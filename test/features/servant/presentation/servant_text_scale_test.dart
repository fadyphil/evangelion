import 'package:evangelion/core/design_system/widgets/icon_action_button.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:evangelion/features/servant/presentation/cubit/question_authoring_cubit.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart';
import 'package:evangelion/features/servant/presentation/pages/question_authoring_page.dart';
import 'package:evangelion/features/servant/presentation/pages/schedule_reading_page.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_home_page.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';
import 'servant_harness.dart';

/// The portal at the reader's **largest text scale**, on the **narrowest**
/// surface.
///
/// ## WHY THE PORTAL NEEDS ITS OWN
///
/// §14 asks every screen to survive 1.22× at 320px, and seven screens have a
/// harness for it: `login_text_scale_test.dart`, `reading_text_scale_test.dart`,
/// `quiz_text_scale_test.dart`, `settings_text_scale_test.dart`, `home_text_scale_test.dart`
/// and the rest. **The portal had none**, and the viewport matrix
/// deliberately does not sweep the scale — so before this file, the portal's
/// four screens were the app's only screens with **neither** a scale harness
/// **nor** a scale sweep.
///
/// **And the gap was not theoretical.** The app bar's title was measured at
/// **172.4px** for "Schedule a reading" at 1.22×, against a box of
/// **149.8px** — the prototype's `max-width:52%` (`redesign.html:145`) applied
/// to this app's narrower bar. The title was **truncated**, and a truncated
/// title is §14's "the reader's words deleted".
///
/// The fix was to compute the title's box from the bar's own width rather than
/// take a percentage of it, and **this file is what holds that**: it renders
/// the bar at the narrowest surface and the largest scale and reads the
/// paragraph's own overflow flag.
///
/// ## AND WHY THE OVERFLOW CHECK IS **THE SHARED HELPER**
///
/// `expectNoOverflow` is `design_system_harness.dart`'s, and it is the
/// instrument the viewport matrix's negative control proves can fail. A
/// private copy of it here would be the second implementation of one invariant,
/// which §7's rule is about.
void main() {
  /// The narrowest surface the app supports.
  const Size surface = Size(320, 568);

  /// The reader's largest text scale — `EvaTypeScale`'s top step.
  const double scale = 1.22;

  group('the portal at 320 and 1.22', () {
    testWidgets('the hub, in English, does not overflow', (
      WidgetTester tester,
    ) async {
      await pumpServant(
        tester,
        ServantHomePage(
          roleAccess: LiveRoleAccess(() => UserRole.adminServant),
          today: () => DateTime(2026, 10, 21),
        ),
        size: surface,
        textScale: scale,
      );

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.text('Daily report').evaluate().isNotEmpty,
        surface: '/servant / en / 320 / 1.22',
      );
    });

    testWidgets('the hub, in Arabic, does not overflow', (
      WidgetTester tester,
    ) async {
      await pumpServant(
        tester,
        ServantHomePage(
          roleAccess: LiveRoleAccess(() => UserRole.adminServant),
          today: () => DateTime(2026, 10, 21),
        ),
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      expectNoOverflow(
        tester,
        // **THE ARABIC ARM'S OWN TITLE.** The card's title is the ARB value,
        // so the landmark has to be the Arabic string — the English one is
        // not on this screen at all.
        somethingRendered: () =>
            find.text('التقرير اليومي').evaluate().isNotEmpty,
        surface: '/servant / ar / 320 / 1.22',
      );
    });

    testWidgets('the report form does not overflow', (
      WidgetTester tester,
    ) async {
      final ServantReportCubit cubit = stubServantReportCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit),
        size: surface,
        textScale: scale,
      );

      expectNoOverflow(
        tester,
        // **THE APP BAR'S TITLE**, and not a field label: the field labels
        // are drawn in **upper case** by the design system, so `find.text`
        // does not match them.
        somethingRendered: () =>
            find.text('Daily report').evaluate().isNotEmpty,
        surface: '/servant/report / 320 / 1.22',
      );
    });

    testWidgets('the schedule form does not overflow', (
      WidgetTester tester,
    ) async {
      final ScheduleReadingCubit cubit = stubScheduleReadingCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        size: surface,
        textScale: scale,
      );

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.text('Schedule a reading').evaluate().isNotEmpty,
        surface: '/servant/schedule / 320 / 1.22',
      );
    });

    testWidgets('the question editor does not overflow', (
      WidgetTester tester,
    ) async {
      final QuestionAuthoringCubit cubit = stubQuestionAuthoringCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: cubit),
        size: surface,
        textScale: scale,
      );

      expectNoOverflow(
        tester,
        somethingRendered: () =>
            find.text('Author questions').evaluate().isNotEmpty,
        surface: '/servant/questions / 320 / 1.22',
      );
    });
  });

  group('the app bar\'s title', () {
    /// The title of the screen named [title], read off the real paragraph.
    ///
    /// **`RenderParagraph.didExceedMaxLines` is the flag**, and it is the
    /// framework's own: `TextPainter`'s doc says it reports *"whether there
    /// was a line that overflowed the `maxWidth` argument passed to `layout`"*,
    /// and `RenderParagraph` exposes it verbatim. A truncated title sets it; a
    /// title that fits does not.
    bool truncated(WidgetTester tester, String title) {
      final RenderParagraph paragraph =
          tester.renderObject(find.text(title)) as RenderParagraph;
      return paragraph.didExceedMaxLines;
    }

    testWidgets('is not truncated at 320 and 1.22 — the long one', (
      WidgetTester tester,
    ) async {
      final ScheduleReadingCubit cubit = stubScheduleReadingCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        size: surface,
        textScale: scale,
      );

      expect(
        truncated(tester, 'Schedule a reading'),
        isFalse,
        reason:
            'the title is truncated at the narrowest surface and the reader\'s '
            'largest text scale. A truncated title is §14\'s "the reader\'s '
            'words deleted", and the title is the only thing that says which '
            'screen this is.',
      );
    });

    testWidgets('is not truncated at 320 and 1.22 — the other long one', (
      WidgetTester tester,
    ) async {
      final QuestionAuthoringCubit cubit = stubQuestionAuthoringCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        QuestionAuthoringPage(cubit: cubit),
        size: surface,
        textScale: scale,
      );

      expect(truncated(tester, 'Author questions'), isFalse);
    });

    testWidgets('is not truncated in Arabic either', (
      WidgetTester tester,
    ) async {
      final ScheduleReadingCubit cubit = stubScheduleReadingCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      expect(truncated(tester, 'جدولة قراءة'), isFalse);
    });
  });

  group('the app bar', () {
    testWidgets('stays where it is when the form scrolls', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS CASE IS HERE
      //
      // The bar is **viewport-fixed** — it is painted through
      // `NeuralScaffold`'s `overlay` slot — because the schedule form is
      // eight fields, which is several screens of scrolling at 320×568, and a
      // back control that scrolls off is not a back control. On the Linux
      // desktop build it is the **only** way out of the screen.
      //
      // **And the bar's position is the claim.** A bar that is in the scroll
      // content would start at the top and end at the top; a bar that is
      // fixed starts at the top and *stays* at the top. The difference is
      // exactly one measurement, and it is the measurement that says which of
      // the two this is.
      final ScheduleReadingCubit cubit = stubScheduleReadingCubit();
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ScheduleReadingPage(cubit: cubit),
        size: surface,
        textScale: scale,
      );

      final Offset before = tester.getTopLeft(find.byType(IconActionButton));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byType(IconActionButton)),
        before,
        reason:
            'the back control moved with the form, so it is part of the scroll '
            'rather than fixed to the viewport. A reader who has scrolled to the '
            'bottom of an eight-field form would have no way back to the portal.',
      );
    });
  });
}
