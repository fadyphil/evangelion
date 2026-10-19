import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The board's content width on a 390-wide phone: the screen minus the
/// gutter (`EvaSpacing.screenHorizontal`, 20) on each side.
///
/// The row is laid out at this width in the app — `CommunionPage` puts the
/// board in a `Padding` of that gutter — so the golden is drawn at the width
/// the row is really drawn at, and not at whatever the test surface happens to
/// be.
const double _boardWidth = 350;

/// The captured region.
///
/// ## WHY A `RepaintBoundary` AND NOT `find.byType(LeaderboardRowTile)`
///
/// `captureImage` walks **up** from the matched element to the nearest
/// `RepaintBoundary` and rasterises *that* boundary's layer — not the
/// element's own rect. A golden taken against the tile itself is therefore a
/// photograph of the whole 390×700 test view with a row in its top-left
/// corner, which is a picture of the harness rather than of the widget. The
/// boundary below is the region, and the harness's own `Align` is what keeps
/// the boundary from being stretched to the view: a `RenderRepaintBoundary`
/// sizes itself to its child **only** under loose constraints, and
/// `MaterialApp`'s route hands its `home` a tight box.
///
/// ## AND WHY THE CANVAS IS PAINTED **INSIDE** THE BOUNDARY
///
/// A `RepaintBoundary`'s layer holds only what its own subtree painted. The
/// harness's background is an ancestor's paint, so it is not in that layer —
/// and a row captured without one would be a row over *nothing*: the reader's
/// gold wash would be gold on transparent, and the golden would be read
/// against alpha rather than against the canvas the reader actually sees.
///
/// ## AND WHY THE AMBIENT FACE IS INSTALLED HERE TOO
///
/// `Scaffold` wraps its body in a `Material` (`scaffold.dart`), and `Material`
/// installs the theme's `bodyMedium` as the ambient `DefaultTextStyle`. The
/// orb's monogram is a `Text` with **no family of its own**, so it inherits
/// that face — and the harness has no `Scaffold` and no `Material`, so
/// without this the monogram would fall back to the engine's default face:
/// Ahem's filled boxes in a test, and a golden that pins boxes rather than
/// the app's Inter.
const Key _surfaceKey = Key('leaderboard_row_tile_surface');

/// The three rows the golden shows, in board order.
///
/// ## WHY THE NAMES ARE LATIN, AND WHY THERE IS NO ARABIC ARM HERE
///
/// The wire sends **one** `full_name` string for both locales — the payload
/// has no Arabic name field, so there is no second spelling to fixture. The
/// prototype's `READERS` array carries an `en` and an `ar` per reader
/// (`eva/redesign.html:1055-1064`), but only the `en` half is reachable from
/// this client, and an Arabic name in a fixture would be a fiction the mapper
/// could never produce.
///
/// The **scores** are the prototype's own `wl` (weekly light) figures. The
/// prototype invents the month and all-time numbers by multiplying that one
/// figure by 4.35 and 38.6 (`eva/redesign.html:1067`); ADR-0022 calls that
/// fiction and the client scores nothing, so a fixture that carried a scaled
/// number would be inventing the same fiction the client refused.
///
/// The **reader** is the cohort's second-placed child. The prototype's sample
/// reader (`you`) is fourth in its own ranking, which would put no reader
/// column on the podium and no gap line on the you-card; second place covers
/// both, and *which* child is signed in is a property of the session rather
/// than of the design.
const LeaderboardRow _youssef = LeaderboardRow(
  rank: 1,
  score: 1240,
  initials: 'YA',
  userId: 'yousef',
  fullName: 'Youssef Adel',
  currentStreak: 41,
);

/// The signed-in child's own row — the reader's row.
const LeaderboardRow _miriam = LeaderboardRow(
  rank: 2,
  score: 1185,
  initials: 'MN',
  userId: 'miriamN',
  fullName: 'Miriam Nour',
  currentStreak: 29,
);

/// The row that carries the veil in this golden.
const LeaderboardRow _abbas = LeaderboardRow(
  rank: 3,
  score: 1010,
  initials: 'AK',
  userId: 'abbas',
  fullName: 'Abbas Khalil',
  currentStreak: 63,
);

/// A cheer target that does nothing.
///
/// A top-level function rather than a closure so the tile can stay `const` —
/// a closure is not a constant expression, and `prefer_const_constructors`
/// would then ask for a `const` the widget cannot take.
void _noop() {}

/// The three renderings of the row, stacked on the canvas.
///
/// ## THE THREE STATES, AND WHY THEY ARE IN ONE PICTURE
///
/// * **plain** — the common row: the position, the monogram orb, the name, the
///   metric sub-line and the value (`eva/redesign.html:314-324`).
/// * **the reader's own row** — the 3px gold rail on the leading edge and the
///   gold wash (`:325`), the `me` class the prototype puts on that row
///   (`:1113`), and the `· you` suffix (`:1116`). The gold **name** is this
///   widget's own addition: the prototype's `.brow.me` shades the row, not the
///   name in it.
/// * **the veiled row** — the name replaced by `witness {position}` and the
///   monogram by the painted hollow star (`:1069-1072`).
///
/// The veil is a **board-wide** toggle in the app (`CommunionPage` reads one
/// `settings.veilWitnesses` for the whole board), so showing it on one row
/// here is a fixture choice rather than a screen state: the point is that the
/// golden covers the third rendering, which a golden of the plain row alone
/// would not.
///
/// `displayPosition` is the board's own position for the row (the app's
/// `leaderboardPositionOf(sorted, row)`), which is what the witness label is
/// built from — the veiled row reads `witness 3`, not `witness Abbas`.
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
              width: _boardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LeaderboardRowTile(
                    row: _youssef,
                    isReader: false,
                    displayPosition: 1,
                    onCheer: _noop,
                  ),
                  LeaderboardRowTile(
                    row: _miriam,
                    isReader: true,
                    displayPosition: 2,
                  ),
                  LeaderboardRowTile(
                    row: _abbas,
                    isReader: false,
                    displayPosition: 3,
                    isVeiled: true,
                    onCheer: _noop,
                  ),
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
  group('the row golden', () {
    // ## WHY THE THEME LOOP IS **OUTSIDE** `testWidgets`
    //
    // `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
    // `kThemeAnimationDuration`, and the single zero-duration `pump()` after
    // `pumpWidget` does not advance it — so two captures in one body wrote the
    // first palette into the second file. Phase 2 shipped two byte-identical
    // "light" goldens that way, and `golden_pairs_test.dart`'s doc records it.
    // The loop was never the problem: it is correctly outside the body.
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: theme,
            // The row reads its own strings (`context.l10n`) for the witness
            // label, the `· you` suffix and the metric names, so the app's
            // delegate list is needed here or the lookup is a null-check
            // failure rather than a golden.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: _surface(),
          ),
        );
        // ## AND WHY NOTHING IS PUMPED PAST A DURATION HERE
        //
        // The row's only animation is the cheer pulse and flare, and it runs
        // **only on the transition** from not-cheered to cheered
        // (`leaderboard_row_tile.dart`'s `didUpdateWidget`). No row in this
        // golden is cheered, so the controller never starts, no frame is ever
        // scheduled, and the row is at rest from the first paint. A duration
        // here would be a promise the widget does not keep.
        await tester.pump();
        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile('goldens/leaderboard_row_tile_$label.png'),
        );
      });
    }
  });
}
