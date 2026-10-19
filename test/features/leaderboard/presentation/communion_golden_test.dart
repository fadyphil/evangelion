import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_cheer_toast.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_podium.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_you_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The board's content width on a 390-wide phone: the screen minus the
/// gutter (`EvaSpacing.screenHorizontal`, 20) on each side.
///
/// The board's widgets are laid out at this width in the app — `CommunionPage`
/// puts them in a `Padding` of that gutter — so the golden is drawn at the
/// width they are really drawn at.
const double _boardWidth = 350;

/// The captured region for the podium.
const Key _podiumKey = Key('communion_podium_surface');

/// The captured region for the you-card.
const Key _youCardKey = Key('communion_you_card_surface');

/// The captured region for the toast.
const Key _toastKey = Key('communion_cheer_toast_surface');

/// ## WHY A `RepaintBoundary` AND NOT THE WIDGET ITSELF
///
/// `captureImage` walks **up** from the matched element to the nearest
/// `RepaintBoundary` and rasterises *that* boundary's layer — not the
/// element's own rect — so a golden taken against the widget is a photograph
/// of the whole 390×700 test view with the widget in its top-left corner. The
/// boundary is the region, and the `Align` above it is what keeps the
/// boundary from being stretched to the view: a `RenderRepaintBoundary` sizes
/// itself to its child **only** under loose constraints, and `MaterialApp`'s
/// route hands its `home` a tight box.
///
/// ## AND WHY THE CANVAS IS PAINTED **INSIDE** THE BOUNDARY
///
/// A `RepaintBoundary`'s layer holds only what its own subtree painted. The
/// harness's background is an ancestor's paint, so it is not in that layer —
/// and a widget captured without one would be a widget over *nothing*: the
/// podium's gold wash and the card's gold fill would be read against
/// transparency rather than against the canvas the reader actually sees.
///
/// ## AND WHY THE AMBIENT FACE IS INSTALLED HERE TOO
///
/// `Scaffold` wraps its body in a `Material` (`scaffold.dart`), and `Material`
/// installs the theme's `bodyMedium` as the ambient `DefaultTextStyle`. The
/// monogram in the podium's orb and the monogram in the you-card's orb are
/// `Text`s with **no family of their own**, so they inherit that face — and
/// the harness has no `Scaffold` and no `Material`, so without this they
/// would fall back to the engine's default face: Ahem's filled boxes in a
/// test, and a golden that pins boxes rather than the app's Inter.
Widget _surface({required Key key, required Widget child}) => Align(
  alignment: Alignment.topCenter,
  child: RepaintBoundary(
    key: key,
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

/// The five ranked children of the cohort, in board order.
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
/// fiction and the client scores nothing, so a fixture carrying a scaled
/// number would be inventing the fiction the client refused.
const LeaderboardRow _youssef = LeaderboardRow(
  rank: 1,
  score: 1240,
  initials: 'YA',
  userId: 'youssef',
  fullName: 'Youssef Adel',
  currentStreak: 41,
);

/// The signed-in child's own row.
///
/// The **reader** is the cohort's second-placed child. The prototype's sample
/// reader (`you`) is fourth in its own ranking, which would put no reader
/// column on the podium and no gap line on the you-card; second place covers
/// both, and *which* child is signed in is a property of the session rather
/// than of the design.
const LeaderboardRow _miriam = LeaderboardRow(
  rank: 2,
  score: 1185,
  initials: 'MN',
  userId: 'miriamN',
  fullName: 'Miriam Nour',
  currentStreak: 29,
);

const LeaderboardRow _abbas = LeaderboardRow(
  rank: 3,
  score: 1010,
  initials: 'AK',
  userId: 'abbas',
  fullName: 'Abbas Khalil',
  currentStreak: 63,
);

/// The prototype's own sample reader (`you`), who is fourth in its ranking.
///
/// Used as the **fallback name** of the unranked card below: a reader the
/// payload does not rank has no row, and the card then prints the name the
/// session knows instead.
const LeaderboardRow _mariam = LeaderboardRow(
  rank: 4,
  score: 890,
  initials: 'MH',
  userId: 'mariam',
  fullName: 'Mariam Hanna',
  currentStreak: 12,
);

const LeaderboardRow _theodora = LeaderboardRow(
  rank: 5,
  score: 845,
  initials: 'TS',
  userId: 'theodora',
  fullName: 'Theodora S.',
  currentStreak: 55,
);

/// The board, in display order.
const List<LeaderboardRow> _board = <LeaderboardRow>[
  _youssef,
  _miriam,
  _abbas,
  _mariam,
  _theodora,
];

/// The top three, which are the podium's three columns.
///
/// The prototype's `order` is **2nd, 1st, 3rd** with heights 84 / 112 / 64
/// and orbs 40 / 46 / 36 (`eva/redesign.html:1085`), so the list handed to the
/// podium is in *rank* order and the widget re-orders the columns itself.
const List<LeaderboardRow> _topThree = <LeaderboardRow>[
  _youssef,
  _miriam,
  _abbas,
];

void main() {
  group('the podium golden', () {
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
            // The podium reads `context.l10n` for the witness label, the `· you`
            // suffix and the digits, so the app's delegate list is needed here
            // or the lookup is a null-check failure rather than a golden.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: _surface(
              key: _podiumKey,
              child: const SizedBox(
                width: _boardWidth,
                child: CommunionPodium(
                  topRows: _topThree,
                  metric: LeaderboardMetric.light,
                  isVeiled: false,
                  // The reader is second, so the **2nd column** is the reader's
                  // and carries the `· you` suffix — the branch a podium with
                  // no reader in it would never draw.
                  readerStandingRank: 2,
                ),
              ),
            ),
          ),
        );

        // ## AND WHY THE ENTRANCE IS PUMPED PAST RATHER THAN SKIPPED
        //
        // The podium's bars grow from nothing: each column is a
        // `Transform.scale` on a `CurvedAnimation`, with the columns staggered
        // at 120 / 200 / 280ms (`eva/redesign.html:1097`'s `120 + k*80`) and
        // **each growing for its own 600ms** (`:297`'s `transform .6s`). A
        // golden taken at the default zero-duration `pump()` would capture
        // `scaleY == 0` — three invisible bars — and a golden taken part-way
        // through would be a picture of whatever fraction of a frame the
        // machine stopped on, which is the definition of a flaky golden.
        //
        // So the whole entrance is pumped past. **1000ms, and the number is
        // not round**: the last column starts at 280ms and finishes at
        // 280 + 600 = **880ms**, and the spring **overshoots** on the way —
        // measured on the current render, the third bar stands at ~69.5px
        // against a 64px layout at 700ms. A golden taken at 700ms would pin
        // the overshoot, which is a frame of the animation rather than the
        // podium at rest.
        //
        // 1000ms is past the last column's 880ms with margin, and
        // `AnimationController.value` is a pure function of elapsed time, so
        // the settled frame is the same frame on every machine. At that point
        // each interval has evaluated to exactly 1.0 and the transform is the
        // identity.
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump();

        await expectLater(
          find.byKey(_podiumKey),
          matchesGoldenFile('goldens/communion_podium_$label.png'),
        );
      });
    }
  });

  group('the you-card golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: _surface(
              key: _youCardKey,
              // ## TWO CARDS, BECAUSE THE CARD HAS TWO WORTH-PINNING RENDERINGS
              //
              // The **ranked** card is the one the reader almost always sees:
              // the position, the name, the value beside its painted star, and
              // the gap line to the witness one place above
              // (`eva/redesign.html:1105-1106`).
              //
              // The **unranked** card is the one the payload produces when the
              // reader has no score in the window: no row, so no value to
              // print — printing `0` would be a fabricated number — and
              // "Not ranked yet" where the position goes. The prototype cannot
              // express this case at all, because its `READERS` array always
              // contains the reader (`eva/redesign.html:1059`).
              //
              // Two cards of the same widget in one golden is the house
              // precedent (`surfaces_test.dart`'s `stat_tile` golden shows
              // three), and a golden of the ranked card alone would leave the
              // unranked one unpinned.
              child: const SizedBox(
                width: _boardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CommunionYouCard(
                      readerRow: _miriam,
                      sortedRows: _board,
                      metric: LeaderboardMetric.light,
                      isVeiled: false,
                    ),
                    CommunionYouCard(
                      readerRow: null,
                      sortedRows: _board,
                      metric: LeaderboardMetric.light,
                      isVeiled: false,
                      fallbackName: 'Mariam Hanna',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // The card is static — it holds no controller and no ticker — so one
        // frame is the whole of it.
        await tester.pump();
        await expectLater(
          find.byKey(_youCardKey),
          matchesGoldenFile('goldens/communion_you_card_$label.png'),
        );
      });
    }
  });

  group('the cheer-toast golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: theme,
            child: _surface(
              key: _toastKey,
              // The prototype's toast is centred and bottom-anchored
              // (`eva/redesign.html:466`: `left:50%; bottom:110px`), and the
              // app places it in a `Positioned` 20 from each side
              // (`CommunionPage`). The box here is that placement's width, so
              // the pill is drawn where the reader sees it rather than
              // stretched to fill the golden.
              //
              // The message is the app's own wording — `leaderboardCheerSent`'s
              // "cheer sent to {name}" (`eva/redesign.html:1122`'s
              // `tr('cheerSent')`), with the name of the witness the reader
              // just cheered.
              child: const SizedBox(
                width: _boardWidth,
                height: 100,
                child: CommunionCheerToast(
                  message: 'cheer sent to Miriam Nour',
                ),
              ),
            ),
          ),
        );
        // The toast is static: no controller, no ticker, no transition.
        await tester.pump();
        await expectLater(
          find.byKey(_toastKey),
          matchesGoldenFile('goldens/communion_cheer_toast_$label.png'),
        );
      });
    }
  });
}
