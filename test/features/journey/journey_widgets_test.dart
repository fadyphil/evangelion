import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_account_rows.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_app_bar.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_hero_number.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_identity.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_medals_strip.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_rings_row.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_section_labels.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_sky_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/design_system_harness.dart';

/// The behaviours that live in `/journey`'s widgets.
///
/// ## WHAT THIS FILE IS
///
/// The geometry suite measures the numbers this screen owns; this one proves
/// what the widgets **do**. The five behaviours the brief names are here, and
/// so is the chevron's mirroring — because `journey_account_rows.dart`'s doc
/// claims that the mirroring is asserted on the painted pixels, and a doc that
/// claims a check the suite does not make is a forward reference that has
/// stopped being true.
void main() {
  group('the rings row', () {
    testWidgets('the arc is empty at rest, and the offset is the prototype\'s', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _rings());

      // `eva/redesign.html:406` — `.fgc{stroke-dasharray:163;
      // stroke-dashoffset:163;…}`, and `:1451` sets that offset before the
      // 200ms delay. So at rest the arc is **empty** and the offset is **163**.
      final JourneyRingPainter painter = _painter(tester, 0);
      expect(painter.fraction, 0);
      expect(painter.dashOffset, 163);
      expect(painter.sweepAngle, 0);
    });

    testWidgets('the arc is drawn to its fraction when the entrance ends', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _rings());
      await tester.pump(const Duration(milliseconds: 1300));

      // `:1451` — `strokeDashoffset = 163*(1-parseFloat(c.dataset.p))`, and the
      // arc's sweep is the fraction of the circle.
      final JourneyRingPainter first = _painter(tester, 0);
      expect(first.dashOffset, closeTo(163 * (1 - 0.83), 0.001));
      expect(first.sweepAngle, closeTo(2 * math.pi * 0.83, 0.001));

      final JourneyRingPainter second = _painter(tester, 1);
      expect(second.dashOffset, closeTo(163 * (1 - 0.86), 0.001));
      expect(second.sweepAngle, closeTo(2 * math.pi * 0.86, 0.001));

      final JourneyRingPainter third = _painter(tester, 2);
      expect(third.dashOffset, closeTo(163 * (1 - 0.92), 0.001));
      expect(third.sweepAngle, closeTo(2 * math.pi * 0.92, 0.001));
    });

    testWidgets('reduced motion draws the rings at their final sweep', (
      WidgetTester tester,
    ) async {
      // §14 — and the prototype's `.rm` (`:49`) does the same.
      await _pump(tester, _rings(), disableAnimations: true);

      // **On the very first frame**, with no pump at all: the rings are at
      // their final sweep and no transition has run.
      final JourneyRingPainter painter = _painter(tester, 0);
      expect(painter.fraction, 0.83);
      expect(painter.sweepAngle, closeTo(2 * math.pi * 0.83, 0.001));
    });

    testWidgets('the entrance does not re-run when the data changes', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _rings());
      await tester.pump(const Duration(milliseconds: 1300));

      // The prototype calls `animateRings()` from `tab(to)` and `jump(to)`
      // (`:1269`, `:1272`) — **once per navigation**, and the redesign's data
      // is static, so there is no re-animation to copy. What the brief asks
      // for is the opposite of a re-run: new data must not replay the draw.
      await tester.pumpWidget(
        _harness(
          JourneyRingsRow(
            rings: <JourneyRing>[
              JourneyRing(
                label: 'verses',
                value: '40%',
                fraction: 0.4,
                stroke: journeyRingTeal,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final JourneyRingPainter painter = _painter(tester, 0);
      expect(
        painter.fraction,
        0.4,
        reason:
            'the new fraction is drawn at once, which is what "the animation '
            'runs on entry and not on data change" looks like',
      );
    });
  });

  group('the labels and the hero', () {
    testWidgets(
      'the hero number is the session\'s streak, in this arm\'s digits',
      (WidgetTester tester) async {
        await _pump(tester, const JourneyHeroNumber(streak: 12));

        // `:589`'s `<div class="hero-num" id="heroNum">12</div>` — the
        // prototype's is a literal, and ours is the reader's own streak.
        expect(find.text('12'), findsOneWidget);

        // `:400` — `font-size:64px`, `font-weight:600`, and `--scr`.
        final Text hero = tester.widget<Text>(find.text('12'));
        expect(hero.style?.fontSize, 64);
        expect(hero.style?.fontWeight, FontWeight.w600);
        expect(hero.style?.fontFamily, EvaTypography.scriptureFamily);
        // `:400` — `line-height:1`.
        expect(hero.style?.height, 1);

        // And the sub-line under it — `:590`.
        expect(find.text('DAY STREAK · KEEP THE FLAME'), findsOneWidget);
      },
    );

    testWidgets('the hero number is Arabic-Indic on the Arabic arm', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JourneyHeroNumber(streak: 12),
        direction: TextDirection.rtl,
      );

      // `:989` — `el('heroNum').textContent = N(12)`, and `N()` (`:981`) is the
      // digit transform.
      expect(find.text('١٢'), findsOneWidget);
      // The sub-line is not uppercased under RTL — `:136`'s
      // `text-transform:none`.
      expect(find.text('أيام متتالية · أبقِ الشعلة'), findsOneWidget);
    });

    testWidgets('the role line is the transcribed copy', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const JourneyRoleLine());

      // `:588` — `data-i18n="scribe"`, and `:30`'s `.mono` uppercases it under
      // LTR.
      expect(find.text('SCRIBE · LEVEL 7'), findsOneWidget);
    });

    testWidgets(
      'the reader\'s name is the session\'s, at the prototype\'s size',
      (WidgetTester tester) async {
        await _pump(tester, const JourneyReaderName(name: 'David Mina'));

        final Text name = tester.widget<Text>(find.text('David Mina'));
        // `:396` — `font-size:22px`.
        expect(name.style?.fontSize, 22);
        expect(name.style?.fontWeight, FontWeight.w600);
        expect(name.style?.fontFamily, EvaTypography.scriptureFamily);

        // `:397` — `[dir=rtl] .jname{font-size:19px}`.
        await _pump(
          tester,
          const JourneyReaderName(name: 'ديفيد مينا'),
          direction: TextDirection.rtl,
        );
        final Text arabic = tester.widget<Text>(find.text('ديفيد مينا'));
        expect(arabic.style?.fontSize, 19);
      },
    );

    testWidgets('the sky line carries both counts', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const JourneySkyLine(stars: 12, constellations: 3));

      // `:596` — "sky · 12 stars lit · 3 constellations", with the two counts
      // in `<b>`.
      expect(
        find.text('SKY · 12 STARS LIT · 3 CONSTELLATIONS'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the medals label carries the count, and the account label does not',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const Column(
            children: <Widget>[
              JourneyMedalsLabel(earned: 4, total: 12),
              JourneyAccountLabel(),
            ],
          ),
        );

        // `:597` — the count is the medals port's, composed rather than
        // transcribed, and the slash is the prototype's own.
        expect(find.text('MEDALS'), findsOneWidget);
        expect(find.text('4 / 12'), findsOneWidget);
        // `:604` — the account label, with no second end.
        expect(find.text('ACCOUNT'), findsOneWidget);
      },
    );
  });

  group('the medal tile', () {
    testWidgets(
      'paints the star for the star, and the fleuron for the fleuron',
      (WidgetTester tester) async {
        await _pump(tester, _medal(MedalEmblem.fourPointedStar));

        expect(find.byType(FourPointedStar), findsOneWidget);
        expect(find.text('❧'), findsNothing);

        await _pump(tester, _medal(MedalEmblem.fleuron));

        expect(find.byType(FourPointedStar), findsNothing);
        expect(find.text('❧'), findsOneWidget);
      },
    );

    testWidgets('the fleuron is drawn in the scripture family, on both arms', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _medal(MedalEmblem.fleuron),
        direction: TextDirection.rtl,
      );

      // **Pinned, and not `arabicAware`.** `❧` is in EB Garamond alone, so the
      // family has to be the scripture one on the Arabic arm too — an
      // `arabicAware` swap would put it in Amiri, which does not carry it.
      final Text fleuron = tester.widget<Text>(find.text('❧'));
      expect(fleuron.style?.fontFamily, EvaTypography.scriptureFamily);
    });

    testWidgets('the two crosses unify on the painted star', (
      WidgetTester tester,
    ) async {
      // **The unification, asserted.** `✠` (`:601`) and `☩` (`:602`) are in no
      // bundled family and no painted ornament is a cross, so both are drawn
      // as the star.
      await _pump(tester, _medal(MedalEmblem.malteseCross));
      expect(find.byType(FourPointedStar), findsOneWidget);

      await _pump(tester, _medal(MedalEmblem.crossOfSaintJohn));
      expect(find.byType(FourPointedStar), findsOneWidget);
    });

    testWidgets('the wash is the prototype\'s own colour', (
      WidgetTester tester,
    ) async {
      // `:599` — `rgba(244,227,178,.5)`, packed: `.5 → 128 = 0x80`.
      await _pump(tester, _medal(MedalEmblem.fourPointedStar));
      expect(_bloomOf(tester)?.toARGB32(), 0x80F4E3B2);

      // `:601` — `rgba(217,142,50,.5)`.
      await _pump(
        tester,
        _medal(MedalEmblem.fourPointedStar, MedalBloom.amber),
      );
      expect(_bloomOf(tester)?.toARGB32(), 0x80D98E32);

      // `:602` — `rgba(79,116,255,.5)`.
      await _pump(tester, _medal(MedalEmblem.fourPointedStar, MedalBloom.blue));
      expect(_bloomOf(tester)?.toARGB32(), 0x804F74FF);

      // `:600` — `rgba(228,87,214,.5)`, which is the **`bloom` token** at the
      // token's own 55% rather than the prototype's 50%. The divergence is
      // recorded in `journey_colours.dart` and in the tile's own doc.
      await _pump(tester, _medal(MedalEmblem.fleuron, MedalBloom.magenta));
      expect(_bloomOf(tester)?.toARGB32(), 0x8CE457D6);
    });
  });

  group('the app bar', () {
    testWidgets('names its three controls', (WidgetTester tester) async {
      await _pump(tester, _appBar());

      // The two buttons carry the **rows'** strings, so a tooltip and its row
      // cannot drift apart.
      expect(find.bySemanticsLabel('The Communion'), findsOneWidget);
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('every control is reachable by keyboard and rings', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _appBar());

      for (final String label in <String>[
        'Back',
        'The Communion',
        'Settings',
      ]) {
        final Finder target = find.bySemanticsLabel(label);
        await tabUntilFocused(tester, target);
        expect(
          renderedBorders(tester, target),
          contains(evaFocusRingBorder(const EvaColors.dark())),
          reason: '§14 — "$label" took focus but painted no ring.',
        );
      }
    });

    testWidgets('the trophy and the gear are the framework\'s glyphs', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _appBar());

      // `:580` is a six-path SVG and `:582` is the `⚙` text glyph — and U+2699
      // is in no bundled family, so the role is kept and the glyph is the
      // framework's.
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('the account rows', () {
    testWidgets(
      'the two live rows are tappable and the two dead ones are not',
      (WidgetTester tester) async {
        await _pump(tester, _rows());

        // §14: a control announced as disabled and answering a tap has told the
        // reader a lie — so the dead rows must carry **no** tap action at all.
        final List<SemanticsData> tappable = nodesOffering(
          tester,
          SemanticsAction.tap,
        );
        final List<String> labels = tappable
            .map((SemanticsData data) => data.label)
            .where((String label) => label.isNotEmpty)
            .toList();

        expect(labels, contains('The Communion'));
        expect(labels, contains('Settings'));
        expect(
          labels.any((String label) => label.startsWith('Share progress')),
          isFalse,
          reason: 'the share row is inert, so it offers no tap',
        );
        expect(
          labels.any((String label) => label.startsWith('Reading plans')),
          isFalse,
          reason: 'and so is the plans row',
        );
      },
    );

    testWidgets('the two dead rows carry their reason in the accessible name', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _rows());

      // §14 — "a reader has to be told **why** a control cannot be pressed,
      // not only that it cannot".
      expect(
        find.bySemanticsLabel('Share progress — unavailable in this build'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Reading plans — unavailable in this build'),
        findsOneWidget,
      );
      // And the painted title is the prototype's own, without the reason.
      expect(find.text('Share progress'), findsOneWidget);
      expect(
        find.text('Share progress — unavailable in this build'),
        findsNothing,
      );
    });

    testWidgets('the chevron mirrors under RTL', (WidgetTester tester) async {
      // `:138` — `[dir=rtl] .srow .ar{… transform:scaleX(-1)}`. U+203A is a
      // `Bidi_Mirrored` character, so the **engine** mirrors it, and the row
      // does not transform it on top of that.
      //
      // **The pixels, and not the ink's position.** The chevron's ink fills its
      // em box under both arms — a mono advance is narrow and the glyph is
      // wide — so "the ink moved" is not a question this font can answer. What
      // the pixels answer is sharper: the RTL chevron is the **left**-pointing
      // quote, which is what "mirrored" means.
      final String ltr = await _chevronArt(tester, TextDirection.ltr, '›');
      final String rtl = await _chevronArt(tester, TextDirection.rtl, '›');
      final String leftQuote = await _chevronArt(
        tester,
        TextDirection.ltr,
        '‹',
      );

      expect(
        rtl,
        leftQuote,
        reason:
            'the RTL chevron is painted as the left-pointing quote, which is '
            'the mirroring U+203A gets from the text engine',
      );
      expect(
        rtl,
        isNot(ltr),
        reason: 'and it is therefore not the LTR chevron',
      );
    });
  });
}

/// The three rings, at the prototype's fractions.
Widget _rings() => JourneyRingsRow(
  rings: <JourneyRing>[
    JourneyRing(
      label: 'verses',
      value: '83%',
      fraction: 0.83,
      stroke: journeyRingTeal,
    ),
    JourneyRing(
      label: 'quizzes',
      value: '86',
      fraction: 0.86,
      stroke: const EvaColors.dark().bloom,
    ),
    JourneyRing(
      label: 'accuracy',
      value: '92%',
      fraction: 0.92,
      stroke: journeyRingBlue,
    ),
  ],
);

/// One medal tile, with the given emblem and bloom.
Widget _medal(MedalEmblem emblem, [MedalBloom bloom = MedalBloom.cream]) =>
    JourneyMedalTile(label: 'first light', emblem: emblem, bloom: bloom);

/// The app bar, with every control live.
Widget _appBar() => const JourneyAppBar(
  onBack: _noop,
  onOpenBoard: _noop,
  onOpenSettings: _noop,
);

/// The four account rows.
Widget _rows() =>
    const JourneyAccountRows(onOpenBoard: _noop, onOpenSettings: _noop);

void _noop() {}

/// The harness the widgets are pumped in.
Widget _harness(Widget child) => evaPrimitiveHarness(
  theme: EvaThemeDark.theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
  child: Center(child: child),
);

/// Pumps [child] on the ambient surface.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: direction == TextDirection.rtl
          ? const Locale('ar')
          : const Locale('en'),
      textDirection: direction,
      disableAnimations: disableAnimations,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: Center(child: child),
    ),
  );
  await tester.pump();
}

/// The painter of the ring at [index].
JourneyRingPainter _painter(WidgetTester tester, int index) {
  final List<CustomPaint> rings = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .toList();
  return rings[index].painter! as JourneyRingPainter;
}

/// The wash the medal tile paints.
Color? _bloomOf(WidgetTester tester) =>
    tester.widget<GlassSurface>(find.byType(GlassSurface)).bloomColor;

/// The chevron's pixels, as text.
///
/// The glyph is rendered **alone** — a `Text` in the mono face — because the
/// question is which way the engine points it, and a row's chrome would only
/// make the box harder to read. Every pixel becomes a character, so two
/// captures can be compared with `==`.
Future<String> _chevronArt(
  WidgetTester tester,
  TextDirection direction,
  String glyph,
) async {
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      textDirection: direction,
      child: Center(
        child: RepaintBoundary(
          key: _chevronKey,
          child: Text(
            glyph,
            style: const TextStyle(
              fontFamily: EvaTypography.monoFamily,
              fontSize: 11,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_chevronKey));
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = boundary.toImageSync();
    final ByteData? data = await image.toByteData();
    image.dispose();
    if (data == null) throw StateError('the chevron produced no pixels');
    return data.buffer.asUint8List();
  });
  if (bytes == null) throw StateError('runAsync returned no pixels');

  final int width = boundary.size.width.ceil();
  final int height = boundary.size.height.ceil();
  final StringBuffer out = StringBuffer();
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int alpha = bytes[(((y * width) + x) * 4) + 3];
      out.write(alpha > 200 ? '#' : (alpha > 40 ? '+' : '.'));
    }
    out.writeln();
  }
  return out.toString();
}

/// The key for the chevron's capture.
const Key _chevronKey = ValueKey<String>('journey-chevron');
