import 'package:evangelion/features/settings/presentation/widgets/workshop_app_bar.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_restore_toast.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// The Workshop's two new surfaces, as goldens.
///
/// ## WHAT IS **NOT** HERE, AND WHY
///
/// **Not the whole screen.** The screen's golden belongs to the screen's own
/// suite, and a golden of a 2,000-pixel-tall scrolling page is a picture of the
/// test surface with the screen in it — which is the reason
/// `leaderboard_row_tile_golden_test.dart` takes a `RepaintBoundary` around the
/// piece it means to photograph.
///
/// **What is here is the two pieces this task added**: the redesign's app bar
/// (`:639-643`) and the restore confirmation (`:975`). The rows are the design
/// system's own `SettingsTile`, and a golden of a design-system row would be a
/// second copy of `surfaces_test.dart`'s.
///
/// ## AND EVERY CHANGED GOLDEN IS RE-CHECKED AGAINST ITS `eva/` CITATION
///
/// `CONTRIBUTING.md`'s rule, and decision 152's: a re-recorded golden without a
/// re-check is a review failure. These are **new** goldens rather than
/// re-records, and the citations they are taken against are `:639-643` (the app
/// bar) and `:466-468` (the toast's pill).
const Key _surfaceKey = Key('workshop_golden_surface');

/// The message the restore toast carries. `eva/redesign.html:975`.
const String _message = '↺ nocturne defaults restored';

/// The two pieces, stacked on one canvas.
///
/// ## WHY THE CANVAS IS **PAINTED INSIDE** THE BOUNDARY
///
/// `captureImage` walks **up** from the matched element to the nearest
/// `RepaintBoundary` and rasterises *that* boundary's layer — so the harness's
/// background, which is an ancestor's paint, is not in the layer. A golden taken
/// without one would be gold on transparent, and it would be read against alpha
/// rather than against the canvas a reader actually sees.
Widget _surface() => Align(
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
            child: const SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  WorkshopAppBar(),
                  SizedBox(height: 24),
                  WorkshopRestoreToast(message: _message),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
);

void main() {
  group('the Workshop goldens', () {
    // ## WHY THE THEME LOOP IS **OUTSIDE** `testWidgets`
    //
    // `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
    // `kThemeAnimationDuration`, and the single zero-duration `pump()` after
    // `pumpWidget` does not advance it — so two captures in one body wrote the
    // first palette into the second file. Phase 2 shipped two byte-identical
    // "light" goldens that way, and `golden_pairs_test.dart`'s doc records it.
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: theme,
            // The app bar reads its own title and the back label from
            // `context.l10n`, so the app's delegate list is needed here or the
            // lookup is a null-check failure rather than a golden.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: _surface(),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile('../goldens/workshop_$label.png'),
        );
      });
    }
  });
}
