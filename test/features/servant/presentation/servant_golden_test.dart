import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:evangelion/features/servant/presentation/pages/question_authoring_page.dart';
import 'package:evangelion/features/servant/presentation/pages/schedule_reading_page.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_home_page.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';
import 'servant_harness.dart';

/// The four screens of the servant portal, as goldens.
///
/// ## WHY THE PORTAL HAS GOLDENS **NOW**
///
/// AGENT_CONTEXT §6 asks every screen for behaviour tests, widget tests **and**
/// golden tests, and the portal's four screens had the first two. The third was
/// impossible: the orphan gate reaches a screen through the **registered
/// router**, and the portal's routes did not exist — so the screens were
/// built, tested and **on no screen at all**.
///
/// **The routes exist now**, and the goldens are here.
///
/// ## AND WHY A **PAGE** IS CAPTURED RATHER THAN ONE OF ITS WIDGETS
///
/// The journey's goldens are widget-level — the orb, the rings, the medals
/// strip — because those are the parts a reader looks at. The portal's four
/// screens have no such parts: each is a **form** or a **list**, and the form
/// *is* the screen. So each golden is the screen itself, in its initial state.
///
/// ## AND WHY THE `RepaintBoundary` AND NOT THE WIDGET
///
/// `captureImage` walks **up** from the matched element to the nearest
/// `RepaintBoundary` and rasterises *that* boundary's layer — not the
/// element's own rect — so a golden taken against the widget is a photograph
/// of the whole 390×844 test view with the widget in its top-left corner. The
/// boundary is the region, and the `Align` above it is what keeps the
/// boundary from being stretched to the view: a `RenderRepaintBoundary` sizes
/// itself to its child **only** under loose constraints, and `MaterialApp`'s
/// route hands its `home` a tight box.
///
/// ## AND WHY THE CANVAS IS PAINTED **INSIDE** THE BOUNDARY
///
/// A `RepaintBoundary`'s layer holds only what its own subtree painted. The
/// harness's background is an ancestor's paint, so it is not in that layer —
/// and a widget captured without one would be a widget over *nothing*. The
/// screen paints its own canvas (`NeuralScaffold`), so the surface below is
/// what the reader sees behind the content.
///
/// ## AND WHY THE THEME LOOP IS **OUTSIDE** `testWidgets`
///
/// `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
/// `kThemeAnimationDuration`, and the single zero-duration `pump()` after
/// `pumpWidget` does not advance it — so two captures in one body wrote the
/// first palette into the second file. Phase 2 shipped two byte-identical
/// "light" goldens that way, and `golden_pairs_test.dart`'s doc records it.
///
/// ## AND WHY THE REPORT'S DATE IS **FIXED**
///
/// The report's form is pre-filled with **today**, so a golden of it would
/// fail every morning. `ServantReportPage.today` is the seam that fixes it —
/// the same shape as `CommunionCountdownLine`'s `now` — and the golden passes
/// a fixed instant.
const Key _surfaceKey = Key('servant_golden_surface');

/// The captured region for a portal screen.
Widget _surface({required Widget child}) => Align(
  alignment: Alignment.topCenter,
  child: RepaintBoundary(
    key: _surfaceKey,
    child: Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!,
            child: child,
          ),
        );
      },
    ),
  ),
);

/// The instant the report's date default is read from.
final DateTime _fixedToday = DateTime(2026, 10, 21);

void main() {
  for (final (String label, ThemeData theme) in kEvaThemes) {
    group('the portal\'s goldens on $label', () {
      testWidgets('the hub, with the admin\'s four sections', (
        WidgetTester tester,
      ) async {
        await pumpServant(
          tester,
          _surface(
            child: ServantHomePage(
              roleAccess: LiveRoleAccess(() => UserRole.adminServant),
            ),
          ),
          theme: theme,
        );
        await tester.pump();

        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile('goldens/servant_hub_$label.png'),
        );
      });

      testWidgets('the report, before anybody asked for a roster', (
        WidgetTester tester,
      ) async {
        final cubit = stubServantReportCubit();
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          _surface(
            child: ServantReportPage(cubit: cubit, today: () => _fixedToday),
          ),
          theme: theme,
        );
        await tester.pump();

        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile('goldens/servant_report_$label.png'),
        );
      });

      testWidgets('the schedule form, before it was filled in', (
        WidgetTester tester,
      ) async {
        final cubit = stubScheduleReadingCubit();
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          _surface(child: ScheduleReadingPage(cubit: cubit)),
          theme: theme,
        );
        await tester.pump();

        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile('goldens/servant_schedule_$label.png'),
        );
      });

      testWidgets('the question editor, before anything was written', (
        WidgetTester tester,
      ) async {
        final cubit = stubQuestionAuthoringCubit();
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          _surface(child: QuestionAuthoringPage(cubit: cubit)),
          theme: theme,
        );
        await tester.pump();

        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile('goldens/servant_questions_$label.png'),
        );
      });
    });
  }
}
