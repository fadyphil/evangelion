/// The `/journey` screen's goldens — **one per widget, in both themes**.
///
/// ## WHAT THESE GOLDENS ARE FOR, AND WHY IT IS NOT "THE SCREEN LOOKS NICE"
///
/// Task 5.5's `/communion` goldens pin the podium, the you-card and the cheer
/// toast. This file pins the eleven widgets `/journey` is made of, and the
/// reason it exists is narrower than "the screen looks nice": **two things
/// about this screen cannot be checked by reading the code, and both are
/// colour**.
///
/// 1. **The four medal washes** (`:599-602`). The prototype's four medals are
///    cream, magenta, amber and blue, and this client paints them through
///    `GlassSurface(tier: GlassTier.bloom, bloomColor: …)` — a radial wash
///    whose alpha is multiplied by the palette's `bloomOpacity`, which is
///    **1.0 in dark and 0.55 in light**. So the same four washes are four
///    different washes in the two themes, and a golden that showed only one
///    of them would be showing a quarter of the claim.
/// 2. **The three ring strokes** (`:592-594`) and the three **tracks** under
///    them. The magenta is `EvaColors.bloom` at full alpha — the one stroke
///    that resolves through a **token** rather than the feature's own
///    transcription table, and `EvaColors.bloom` carries the same value in
///    both palettes, so the magenta is the one stroke that does **not** change
///    with the theme. The teal and the blue are the transcription table's, and
///    the track under all three is `EvaColors.glassBorder` — 8% white in dark
///    and 8% black in light.
///
/// **A reader who cannot see the difference between the third and the fourth
/// medal is looking at a defect, and the golden is where that shows.** The
/// third medal's wash is the amber and the fourth's is the blue; the third
/// medal's emblem and the fourth's are **the same painted star**, because the
/// prototype's `✠` (U+2720) and `☩` (U+2629) are in no bundled family and no
/// painted cross exists — see `journey_medals_strip.dart`'s class doc, which
/// records the unification. So the strip's golden has to show four washes and
/// **two** emblems, and it does.
///
/// ## THE NUMBERS ARE THE **PROTOTYPE'S OWN**, NOT FIXTURES
///
/// The rings' values are `83%`, `86` and `92%` — `eva/redesign.html:592-594`'s
/// own `data-v` values, reached through the app's own `journeyPercent` and
/// `AppLocalizations.digits`. The medals' count is `4 / 12` — `:597`'s own
/// `medalsCount` row, reached through the port's `earned` and `total`. The
/// labels are the app's own ARB strings, so a golden can never pin a copy of
/// the copy: if the ARB changes, the golden goes red, which is the point.
///
/// ## THE THEME LOOP IS **OUTSIDE** `testWidgets`
///
/// `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
/// `kThemeAnimationDuration`, and the single zero-duration `pump()` after
/// `pumpWidget` does not advance it — so two captures in one body wrote the
/// first palette into the second file. `golden_pairs_test.dart`'s doc records
/// that mechanism, and `kEvaThemes` is the house's answer: one body per theme.
library;

import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:evangelion/features/journey/presentation/journey_l10n.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_account_rows.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_app_bar.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_hero_number.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_identity.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_medals_strip.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_orb.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_rings_row.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_section_labels.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_sky_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/design_system_harness.dart';
import '../../support/project_import_graph.dart';

/// The prototype's phone width — `eva/redesign.html:43`'s `.device{width:390px}`.
const double _screenWidth = 390;

/// The scroll's own horizontal gutter — `eva/redesign.html:157`'s
/// `padding:6px 14px 118px`.
const double _scrollGutter = 14;

/// The width the screen's content is drawn at — the screen minus the scroll's
/// gutter on each side.
///
/// **362, and it is the prototype's own arithmetic**: 390 − 14 − 14.
const double _contentWidth = _screenWidth - 2 * _scrollGutter;

/// The width the medals strip is captured at.
///
/// **The strip's own content width**, and the reason it is not the screen's:
///
/// | part | number | where |
/// | --- | --- | --- |
/// | four medals | 4 × 104 = 416 | `:412`'s `flex:0 0 104px` |
/// | three gaps | 3 × 12 = 36 | `:410`'s `gap:12px` |
/// | the strip's padding | 2 × 18 = 36 | `:410`'s `padding:4px 18px 12px` |
///
/// 416 + 36 + 36 = **488**. The strip **scrolls** (`:410`'s `overflow-x:auto`),
/// and at 390 four medals do not fit — which is the prototype's own behaviour.
/// The golden widens the viewport to the strip's content width so that **all
/// four washes are in the frame**: a golden that showed three of them would
/// pin the wrong thing, and the fourth is the blue one that the third (amber)
/// has to be distinguishable from.
const double _medalsStripWidth =
    4 * JourneyMedalsStrip.medalSize +
    3 * JourneyMedalsStrip.gap +
    2 * JourneyMedalsStrip.paddingHorizontal;

/// The room the orb's glow is given.
///
/// `SealMonogram` paints two `BoxShadow`s — `ember` at 26.7% with a
/// `blurRadius` of 40, and at 13.3% with a `blurRadius` of 80 — and a
/// `RenderRepaintBoundary`'s layer is the size of the boundary, so a shadow
/// painted outside it is **cut off**.
///
/// **64px of room, and the number is the inner shadow's.** A `BoxShadow`'s
/// `blurRadius` is a Gaussian's σ × 2, so the 40 is a σ of 20 and the glow
/// runs out at about 2σ — 40px — and the room is wider than that. The outer
/// shadow's 80 does run past the boundary and is cut there, which leaves a
/// faint edge on the canvas and not a missing shape.
const double _orbGlowRoom = 64;

/// The room the hero number's glow is given.
///
/// `:400`'s `text-shadow:0 0 40px rgba(232,176,75,.45)` is a **text** shadow
/// (30px in light, `:88`), and a text shadow paints outside the glyph's box —
/// and a `RenderRepaintBoundary`'s layer is the size of the boundary, so what
/// falls outside it is **cut off**.
///
/// **56px of room, which is more than the 40px blur** the dark theme asks for
/// and more than the light one's 30.
const double _heroGlowRoom = 56;

/// The keys the eleven regions are captured under.
const Key _orbKey = Key('journey_orb_surface');
const Key _nameKey = Key('journey_reader_name_surface');
const Key _roleKey = Key('journey_role_line_surface');
const Key _heroKey = Key('journey_hero_number_surface');
const Key _ringsKey = Key('journey_rings_row_surface');
const Key _skyKey = Key('journey_sky_line_surface');
const Key _medalsLabelKey = Key('journey_medals_label_surface');
const Key _medalsStripKey = Key('journey_medals_strip_surface');
const Key _accountLabelKey = Key('journey_account_label_surface');
const Key _accountRowsKey = Key('journey_account_rows_surface');
const Key _appBarKey = Key('journey_app_bar_surface');

/// The eleven subjects, and the file each is recorded under.
///
/// **One list, so the captures and the files cannot drift apart.** The pairs
/// gate in `test/golden_pairs_test.dart` checks that every `*_dark.png` has a
/// `*_light.png` sibling and that the two are **not** byte-identical — but it
/// cannot tell a subject that was never captured from one that was: a missing
/// golden is not a duplicate. So the eleven names are written down here, and
/// the last test in this file checks that every one of them has a pair on
/// disk.
const List<String> _subjects = <String>[
  'journey_orb',
  'journey_reader_name',
  'journey_role_line',
  'journey_hero_number',
  'journey_rings_row',
  'journey_sky_line',
  'journey_medals_label',
  'journey_medals_strip',
  'journey_account_label',
  'journey_account_rows',
  'journey_app_bar',
];

/// The captured region.
///
/// ## WHY A `RepaintBoundary` AND NOT THE WIDGET ITSELF
///
/// `captureImage` walks **up** from the matched element to the nearest
/// `RepaintBoundary` and rasterises *that* boundary's layer — so a golden
/// taken against the widget is a photograph of the whole test view with the
/// widget in its top-left corner. The boundary is the region, and the
/// `Align` above it is what keeps the boundary from being stretched to the
/// view: a `RenderRepaintBoundary` sizes itself to its child **only** under
/// loose constraints, and `MaterialApp`'s route hands its `home` a tight box.
///
/// ## AND WHY THE CANVAS IS PAINTED **INSIDE** THE BOUNDARY
///
/// A `RepaintBoundary`'s layer holds only what its own subtree painted. The
/// harness's background is an ancestor's paint, so it is not in that layer —
/// and a widget captured without one would be a widget over *nothing*: the
/// hero number's gold glow and the rings' tracks would be read against
/// transparency rather than against the canvas the reader actually sees.
///
/// ## AND WHY THE AMBIENT FACE IS INSTALLED HERE TOO
///
/// `Scaffold` wraps its body in a `Material`, and `Material` installs the
/// theme's `bodyMedium` as the ambient `DefaultTextStyle`. The harness has no
/// `Scaffold` and no `Material`, so without this the account rows' titles
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

/// Pumps [child] on a surface [width] wide and captures the region under
/// [key].
///
/// [settle] is the extra time the widget is given to finish an entrance.
/// `null` means one frame, which is the whole of a static widget.
Future<void> _capture(
  WidgetTester tester, {
  required ThemeData theme,
  required Key key,
  required Widget child,
  required String file,
  double width = _screenWidth,
  Duration? settle,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: theme,
      // The widgets read `context.l10n` for their own copy — the role line,
      // the sky line, the medals' names, the rows' titles — so the app's
      // delegate list is needed here or the lookup is a null-check failure
      // rather than a golden.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: _surface(key: key, child: child),
    ),
  );
  if (settle != null) {
    await tester.pump(settle);
    await tester.pump();
  } else {
    await tester.pump();
  }
  await expectLater(find.byKey(key), matchesGoldenFile('goldens/$file'));
}

/// The reader's own monogram, in the orb.
///
/// `:586` writes a literal `M` — the initial of the prototype's literal name
/// "Mariam Hanna" (`:587`). Ours is the session's, and the golden's is the
/// prototype's own letter so that the orb is comparable with the prototype's.
const String _monogram = 'M';

/// The reader's name, as the session has it.
///
/// The prototype's is "Mariam Hanna" (`:587`), and the golden uses the same
/// string so that the two are comparable — the widget takes the name as a
/// parameter and the golden is about the **face and the size**, not about
/// whose name it is.
const String _readerName = 'Mariam Hanna';

/// A callback that does nothing.
///
/// **A top-level function and not a closure**, because a tear-off of a
/// top-level function is a constant expression and a closure is not — so this
/// is what lets the app bar's capture be `const`.
void _noop() {}

void main() {
  group('the orb golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _orbKey,
          // **Centred, and the region hugs the mark.** `:392`'s `.jorb` carries
          // `margin:10px auto 12px`, so the prototype centres the orb — and
          // the `Align` with both factors set is the widget that *hugs* its
          // child, where a `Center` would expand to the whole test surface and
          // leave the golden 90% empty canvas. The room around it is the
          // glow's, and the reason it is there at all is in [_orbGlowRoom].
          child: const Padding(
            padding: EdgeInsets.all(_orbGlowRoom),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: JourneyOrb(
                monogram: _monogram,
                semanticLabel: _readerName,
              ),
            ),
          ),
          file: 'journey_orb_$label.png',
        );
      });
    }
  });

  group('the reader-name golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _nameKey,
          child: const SizedBox(
            width: _contentWidth,
            child: JourneyReaderName(name: _readerName),
          ),
          file: 'journey_reader_name_$label.png',
        );
      });
    }
  });

  group('the role-line golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _roleKey,
          child: const SizedBox(width: _contentWidth, child: JourneyRoleLine()),
          file: 'journey_role_line_$label.png',
        );
      });
    }
  });

  group('the hero-number golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _heroKey,
          // The room is **vertical only**: the number's glow reaches 40px up
          // and down, and the number itself is narrow enough that its glow is
          // inside the content width on both sides. The width is the content
          // width, so the number and the sub-line are centred in the same 362
          // the screen gives them.
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: _heroGlowRoom),
            child: SizedBox(
              width: _contentWidth,
              child: JourneyHeroNumber(streak: 12),
            ),
          ),
          file: 'journey_hero_number_$label.png',
        );
      });
    }
  });

  group('the rings-row golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _ringsKey,
          // **The prototype's own three rings.** `:592`, `:593` and `:594`:
          // 83% / 86 / 92%, the teal, the magenta and the blue, with the
          // labels "verses", "quizzes" and "accuracy". The values are reached
          // through the app's own `journeyPercent` and `digits`, so the golden
          // pins the composed string and not a copy of it.
          child: Builder(
            builder: (BuildContext context) {
              final EvaColors colors = context.colors;
              final AppLocalizations strings = context.l10n;
              final List<Color> strokes = journeyRingStrokes(colors);
              return SizedBox(
                width: _contentWidth,
                child: JourneyRingsRow(
                  rings: <JourneyRing>[
                    JourneyRing(
                      label: strings.journeyRingVerses,
                      value: journeyPercent(strings, 0.83),
                      fraction: 0.83,
                      stroke: strokes[0],
                    ),
                    JourneyRing(
                      label: strings.journeyRingQuizzes,
                      value: strings.digits(86),
                      fraction: 0.86,
                      stroke: strokes[1],
                    ),
                    JourneyRing(
                      label: strings.journeyRingAccuracy,
                      value: journeyPercent(strings, 0.92),
                      fraction: 0.92,
                      stroke: strokes[2],
                    ),
                  ],
                ),
              );
            },
          ),
          // **The entrance is pumped past, not skipped.** `:1450-1451`'s
          // `animateRings()` waits 200ms and then draws over 1.1s, and this
          // widget's own controller runs for `200 + 1100 = 1300ms`. A golden
          // taken at the default zero-duration `pump()` would capture three
          // **empty** rings — the track and nothing else — and a golden taken
          // part-way through would be a picture of whatever fraction of the
          // draw the machine stopped on, which is the definition of a flaky
          // golden. 1400ms is past the end, and the controller's value is a
          // pure function of elapsed time, so the settled frame is the same
          // frame on every machine.
          settle: const Duration(milliseconds: 1400),
          file: 'journey_rings_row_$label.png',
        );
      });
    }
  });

  group('the sky-line golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _skyKey,
          // **Two different numbers on purpose.** The two counts are the gold
          // `<b>` spans (`:31`'s `.mono b{color:var(--gold);font-weight:600}`)
          // and the words around them are the dimmer ink, so a golden whose
          // two counts were equal could not say which span is which.
          child: const SizedBox(
            width: _contentWidth,
            child: JourneySkyLine(stars: 27, constellations: 4),
          ),
          file: 'journey_sky_line_$label.png',
        );
      });
    }
  });

  group('the medals-label golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _medalsLabelKey,
          // **The prototype's own "4 / 12"** — `:597`'s `medalsCount` row,
          // reached through the port's `earned` and `total` and the app's own
          // `digits`, so the golden pins the composed count and not a copy.
          child: const SizedBox(
            width: _contentWidth,
            child: JourneyMedalsLabel(earned: 4, total: 12),
          ),
          file: 'journey_medals_label_$label.png',
        );
      });
    }
  });

  group('the medals-strip golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _medalsStripKey,
          // **The four medals of `:599-602`, in the prototype's order**, with
          // the emblem and the wash read off the domain's own `Medal` — so the
          // golden shows the four washes as four washes and the two unified
          // emblems as the same mark.
          child: Builder(
            builder: (BuildContext context) {
              final AppLocalizations strings = context.l10n;
              return SizedBox(
                width: _medalsStripWidth,
                child: JourneyMedalsStrip(
                  tiles: <JourneyMedalTile>[
                    for (final Medal medal in Medal.values)
                      JourneyMedalTile(
                        label: medal.label(strings),
                        emblem: medal.emblem,
                        bloom: medal.bloom,
                      ),
                  ],
                ),
              );
            },
          ),
          // The surface is as wide as the strip's own content, so all four
          // medals are in the frame. At the screen's 390 the fourth would be
          // scrolled out of it, and a golden that pinned three of the four
          // washes would pin the wrong thing.
          width: _medalsStripWidth,
          file: 'journey_medals_strip_$label.png',
        );
      });
    }
  });

  group('the account-label golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _accountLabelKey,
          child: const SizedBox(
            width: _contentWidth,
            child: JourneyAccountLabel(),
          ),
          file: 'journey_account_label_$label.png',
        );
      });
    }
  });

  group('the account-rows golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _accountRowsKey,
          // **All four rows, in the prototype's order** — `:605`, `:606`,
          // `:607` and `:608` — so the golden shows the two live rows at full
          // ink and the two dead ones at the house's disabled opacity of
          // 0.45.
          child: SizedBox(
            width: _contentWidth,
            child: JourneyAccountRows(
              onOpenBoard: () {},
              onOpenSettings: () {},
            ),
          ),
          file: 'journey_account_rows_$label.png',
        );
      });
    }
  });

  group('the app-bar golden', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await _capture(
          tester,
          theme: theme,
          key: _appBarKey,
          // **The screen's own width**, because the app bar is the one row the
          // scroll's gutter does not apply to: `:142`'s `.appbar{padding:46px
          // 18px 4px}` insets it by 18 of its own.
          //
          // **No back control.** The journey is a dock tab, and the prototype's
          // journey app bar carries a 68px spacer where a chevron would be
          // (`:578`) — so the app bar has **two** controls, and the leading
          // space is a spacer rather than a way out.
          child: const SizedBox(
            width: _screenWidth,
            child: JourneyAppBar(onOpenBoard: _noop, onOpenSettings: _noop),
          ),
          file: 'journey_app_bar_$label.png',
        );
      });
    }
  });

  group('the golden files themselves', () {
    test('every subject has a dark and a light pair on disk', () {
      final Directory dir = Directory.fromUri(
        packageRoot.uri.resolve('test/features/journey/goldens'),
      );
      expect(
        dir.existsSync(),
        isTrue,
        reason:
            'the goldens directory does not exist, so the walk below would find '
            'nothing and "every subject has a pair" would be vacuously true.',
      );

      final List<String> missing = <String>[];
      for (final String subject in _subjects) {
        for (final String theme in <String>['dark', 'light']) {
          final File file = File.fromUri(
            dir.uri.resolve('${subject}_$theme.png'),
          );
          if (!file.existsSync()) {
            missing.add('${file.path} is missing');
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'a subject with no pair is a subject nothing pins. The pairs gate in '
            '`test/golden_pairs_test.dart` checks that a `_dark.png` has a '
            '`_light.png` sibling, but it cannot see a subject that was never '
            'captured at all.\n${missing.join('\n')}',
      );
    });
  });
}
