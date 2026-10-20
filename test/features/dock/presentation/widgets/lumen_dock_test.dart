import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/css_reference.dart';
import '../../../../support/design_system_harness.dart';
import '../../../../support/project_import_graph.dart';

/// The redesign's five-slot dock, against the stylesheet that states it.
///
/// ## WHY THE PROTOTYPE IS READ AT TEST TIME
///
/// The numbers this dock ships are the prototype's, and a table of numbers
/// copied out of a stylesheet is a table that rots. So every claim below is
/// read out of `eva/redesign.html` **at test time** and compared with the
/// constant the widget ships — the same instrument
/// `test/features/reading/presentation/pages/reading_geometry_test.dart` uses,
/// and the same reason: a doc comment quoting a line is an assertion nobody
/// checks.
///
/// ## AND THE EXTRACTION IS NEGATIVE-CONTROLLED
///
/// A stylesheet-scanning suite that matched nothing would be green about
/// nothing, so the last group of this file plants a violation — a scratch copy
/// of the stylesheet with the dock's height changed — and proves the
/// extraction sees it.
void main() {
  /// The prototype, read once. `eva/` is read-only reference material.
  final File prototype = File.fromUri(
    packageRoot.uri.resolve('eva/redesign.html'),
  );

  group('the dock, against `:208-234`', () {
    test('the height, the corner radius and the padding', () {
      final Map<String, String> dock = cssRule(prototype, '.dock');
      expect(cssPx(dock, 'height'), LumenDock.height);
      // `:208` — `border-radius:26px 26px 0 0`. **All four values**, because
      // the last two are the dock's square bottom edge and a harness that
      // read only the first would not notice them changing.
      expect(cssPxList(dock, 'border-radius'), <double>[26, 26, 0, 0]);
      expect(cssPxList(dock, 'border-radius').first, LumenDock.topRadius);
      // `:211` — `padding:10px 6px 16px`.
      expect(cssPxList(dock, 'padding'), <double>[10, 6, 16]);
      expect(cssPxList(dock, 'padding')[0], LumenDock.paddingTop);
      expect(cssPxList(dock, 'padding')[1], LumenDock.paddingHorizontal);
      expect(cssPxList(dock, 'padding')[2], LumenDock.paddingBottom);
    });

    test('the slot gap, the glyph zone and the icon', () {
      final Map<String, String> tab = cssRule(prototype, '.dtab');
      expect(cssPx(tab, 'gap'), LumenDock.slotGap);
      final Map<String, String> zone = cssRule(prototype, '.dtab .zone');
      expect(cssPx(zone, 'height'), LumenDock.zoneHeight);
      final Map<String, String> icon = cssRule(prototype, '.dic');
      expect(cssPx(icon, 'width'), LumenDock.iconSize);
      expect(cssPx(icon, 'height'), LumenDock.iconSize);
    });

    test('the label', () {
      final Map<String, String> label = cssRule(prototype, '.dlab');
      expect(cssPx(label, 'font-size'), LumenDock.labelSize);
      // `:220`'s tracking is in **em**, and `cssPx` refuses it on purpose —
      // "not a pixel length this parser reads". So the declaration is
      // compared as the string the prototype wrote.
      expect(label['letter-spacing'], '.02em');
      expect(
        double.parse(label['letter-spacing']!.replaceAll('em', '')),
        LumenDock.labelTrackingEm,
      );
      // `:226` — the active weight, which the prototype states on its own
      // rule and which this dock applies instantly.
      final Map<String, String> active = cssRule(prototype, '.dtab.on .dlab');
      expect(active['font-weight'], '600');
    });

    test('the beam', () {
      final Map<String, String> beam = cssRule(prototype, '.beam');
      expect(cssPx(beam, 'width'), LumenDock.beamWidth);
      // `:225` — `.dtab.on .beam{height:14px;opacity:1}`.
      final Map<String, String> active = cssRule(prototype, '.dtab.on .beam');
      expect(cssPx(active, 'height'), LumenDock.beamHeight);
    });

    test('the hairline and the backdrop blur', () {
      final Map<String, String> hairline = cssRule(prototype, '.dock::before');
      expect(cssPx(hairline, 'height'), LumenDock.hairlineHeight);
      // The insets are **percentages**, and `cssPx` refuses a percentage for
      // the same reason it refuses `em`: the conversion is the claim.
      expect(hairline['left'], '12%');
      expect(hairline['right'], '12%');
      expect(
        double.parse(hairline['left']!.replaceAll('%', '')) / 100,
        LumenDock.hairlineInset,
      );
      // `:210` — `backdrop-filter:blur(22px)`.
      expect(
        cssPx(cssRule(prototype, '.dock'), 'backdrop-filter'),
        LumenDock.blurSigma,
      );
    });

    test('the orb, and the ripple\'s period', () {
      final Map<String, String> orb = cssRule(prototype, '.orbmini');
      expect(cssPx(orb, 'width'), LumenOrb.diameter);
      expect(cssPx(orb, 'height'), LumenOrb.diameter);
      // `:230` — `animation:ripple 2.6s var(--e-out) infinite`.
      //
      // **The period is read by its own pattern, not by `cssPx`.** The
      // declaration carries three numbers (`2.6`, and the `0`, `0` and `.2` of
      // the `var(--e-out)` it resolves to), and a pixel-length parser reading
      // it would answer "2" — the integer half of "2.6" — without a word of
      // complaint. The pattern names the `ripple` keyword, so it cannot read
      // the wrong thing.
      final Map<String, String> after = cssRule(prototype, '.orbmini::after');
      final RegExpMatch? ripple = RegExp(r'ripple\s+([\d.]+)s')
          .firstMatch(after['animation']!);
      expect(ripple, isNotNull, reason: 'the `animation` declaration is gone');
      expect(
        double.parse(ripple!.group(1)!),
        LumenOrb.ripplePeriodSeconds,
        reason:
            'the period the widget spends is the period the prototype states',
      );
      expect(LumenOrb.ripplePeriodSeconds, 2.6);
      // And the motion token it is derived from.
      expect(EvaMotion.dockRipple.inMilliseconds, 2600);
    });

    test('the two backgrounds, and the alpha each one uses', () {
      // `:209` — `background:rgba(8,10,18,.86)`.
      final Map<String, String> dock = cssRule(prototype, '.dock');
      expect(dock['background'], contains('.86'));
      // `:64` — `.screen[data-mode=light] .pill,.screen[data-mode=light]
      // .dock{background:rgba(255,255,255,.74)}`.
      final Map<String, String> light = cssRule(
        prototype,
        '.screen[data-mode=light] .pill,.screen[data-mode=light] .dock',
      );
      expect(light['background'], contains('.74'));
      expect(LumenDock.backgroundAlphaDark, 0.86);
      expect(LumenDock.backgroundAlphaLight, 0.74);
    });
  });

  group('the extraction is not vacuous', () {
    test('every rule the claims name is still in the stylesheet', () {
      // `cssRule` throws when a selector is gone, so this group fails loudly
      // rather than comparing against air. The assertion is that each rule
      // still **declares** what the claim above reads out of it.
      for (final String selector in const <String>[
        '.dock',
        '.dock::before',
        '.dtab',
        '.dtab .zone',
        '.dtab.on .beam',
        '.dtab.on .dlab',
        '.dic',
        '.dlab',
        '.beam',
        '.orbmini',
        '.orbmini::after',
      ]) {
        expect(
          cssRule(prototype, selector),
          isNotEmpty,
          reason: '`$selector` is in the stylesheet but declares nothing',
        );
      }
    });

    test(
      'and a stylesheet whose dock height changed is SEEN to have changed',
      () {
        // The negative control. A harness that reads its numbers from a table
        // would still be green after the prototype moved, and this is the only
        // assertion in the file that says otherwise.
        final Directory scratch = Directory.systemTemp.createTempSync(
          'eva_lumen_dock_geometry',
        );
        addTearDown(() => scratch.deleteSync(recursive: true));
        final File mutated = File.fromUri(scratch.uri.resolve('redesign.html'))
          ..writeAsStringSync(
            prototype.readAsStringSync().replaceFirst(
              'height:78px',
              'height:79px',
            ),
          );

        final Map<String, String> dock = cssRule(mutated, '.dock');
        expect(
          cssPx(dock, 'height'),
          79,
          reason: 'the scratch copy really did move the dock\'s height',
        );
        expect(
          cssPx(dock, 'height'),
          isNot(LumenDock.height),
          reason:
              'the widget still ships the prototype\'s 78, so a prototype that '
              'moved must make this suite red — which is the whole point of '
              'reading the file instead of a table',
        );
      },
    );
  });

  group('the dock, rendered', () {
    testWidgets('the five slots render in the order they were given', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(tester, _dock());
      final List<Text> labels = tester
          .widgetList<Text>(find.byType(Text))
          .toList();
      expect(labels.map((Text label) => label.data).toList(), <String>[
        'Home',
        'Read',
        'Today',
        'Communion',
        'Journey',
      ]);
      // The order is a **position**, not a list: the words could be in the
      // tree in that order and still be drawn in another.
      double previous = -1;
      for (final Text label in labels) {
        final double left = tester.getTopLeft(find.text(label.data!)).dx;
        expect(left, greaterThan(previous));
        previous = left;
      }
    });

    testWidgets('the dock is 78 tall and its slots are 32', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(tester, _dock());
      expect(tester.getSize(find.byType(LumenDock)).height, LumenDock.height);
      // The zone is the 32px box the glyph sits in, and the five slots are
      // the only places one appears. **The count is of distinct rectangles**,
      // because a `SizedBox` and the `Center` inside it are two render
      // objects at the same place, and counting boxes would say ten.
      expect(_rectsOfHeight(tester, LumenDock.zoneHeight).length, 5);
    });

    testWidgets('the active slot is marked, and the others are not', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(tester, _dock(activeIndex: 2));
      final List<Rect> beams = _beams(tester);
      expect(beams.length, 5, reason: 'one beam per slot');
      final List<Rect> tall = beams
          .where((Rect beam) => beam.height == LumenDock.beamHeight)
          .toList();
      expect(tall.length, 1, reason: 'exactly one slot is active');
      expect(
        beams.where((Rect beam) => beam.height == 0).length,
        4,
        reason: 'the other four beams are collapsed',
      );
      // The tall one is the **third** slot's — the one the dock was told is
      // active — and the beams are in slot order from the left.
      final List<Rect> ordered = beams.toList()
        ..sort((Rect a, Rect b) => a.left.compareTo(b.left));
      expect(ordered[2].height, LumenDock.beamHeight);
      expect(ordered[0].height, 0);

      // The label's weight is the second half of the marker, and it is
      // asserted on the **rendered** style rather than on a flag.
      final List<Text> labels = tester
          .widgetList<Text>(find.byType(Text))
          .toList();
      expect(labels[2].style?.fontWeight, FontWeight.w600);
      expect(labels[0].style?.fontWeight, FontWeight.w500);
      expect(labels[4].style?.fontWeight, FontWeight.w500);
      // And the label's own size, which the prototype states at `:220`.
      expect(labels[0].style?.fontSize, LumenDock.labelSize);
    });

    testWidgets('the active slot\'s ink is the gold and the others are not', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(tester, _dock(activeIndex: 2));
      final EvaColors colors = _colorsOf(tester, find.byType(LumenDock));
      final List<Text> labels = tester
          .widgetList<Text>(find.byType(Text))
          .toList();
      expect(labels[2].style?.color, colors.ember);
      expect(labels[0].style?.color, colors.ink2);
    });

    testWidgets('tapping a slot reports that slot\'s index', (
      WidgetTester tester,
    ) async {
      final List<int> selected = <int>[];
      await pumpPrimitive(tester, _dock(onSelect: selected.add));
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(selected, <int>[1]);
      await tester.tap(find.text('Journey'));
      await tester.pumpAndSettle();
      expect(selected, <int>[1, 4]);
    });

    testWidgets('a semanticLabel overrides the label in the accessible name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrimitive(
        tester,
        LumenDock(
          activeIndex: -1,
          onSelect: (int _) {},
          items: const <LumenDockItem>[
            LumenDockItem(
              label: 'Home',
              glyph: Icon(Icons.home),
              semanticLabel: 'Go to the home screen',
            ),
            LumenDockItem(label: 'Read', glyph: Icon(Icons.menu_book)),
          ],
        ),
      );

      final List<SemanticsData> nodes = semanticsTree(tester);
      final Iterable<SemanticsData> named = nodes.where(
        (SemanticsData node) => node.label == 'Go to the home screen',
      );
      expect(named.length, 1, reason: 'the override names the slot');
      expect(
        named.first.hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'and the slot is still operable',
      );
      // The **visible** label is unchanged, and the override does not become a
      // second thing on screen.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Go to the home screen'), findsNothing);
      handle.dispose();
    });

    testWidgets('and the slots are announced as buttons', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrimitive(tester, _dock(activeIndex: 1));
      final List<SemanticsData> nodes = semanticsTree(tester);
      final Iterable<SemanticsData> buttons = nodes.where(
        (SemanticsData node) => node.flagsCollection.isButton,
      );
      expect(buttons.length, 5, reason: 'one button per slot');
      expect(
        nodes
            .where(
              (SemanticsData node) =>
                  node.flagsCollection.isSelected.toBoolOrNull() == true,
            )
            .length,
        1,
        reason: 'and exactly one of them is the active slot',
      );
      handle.dispose();
    });

    testWidgets('a pressed slot shrinks, and springs back', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(tester, _dock());
      final Finder transforms = find.descendant(
        of: find.byType(LumenDock),
        matching: find.byType(Transform),
      );
      expect(_scales(tester, transforms), <double>[1, 1, 1, 1, 1]);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Read')),
      );
      await tester.pump();
      // **One** slot is scaled, and it is scaled to `:227`'s `.94`.
      expect(
        _scales(tester, transforms).where((double s) => s != 1.0).toList(),
        <double>[0.94],
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scales(tester, transforms), <double>[1, 1, 1, 1, 1]);
    });

    testWidgets('the light dock is more transparent than the dark one', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(tester, _dock());
      final Color dark = _tintOf(tester);
      await pumpPrimitive(tester, _dock(), theme: EvaThemeLight.theme);
      // **The theme change is animated**, and `MaterialApp`'s `AnimatedTheme`
      // does not advance on the frame `pumpWidget` pumps — so the tree is
      // still on the dark palette until this settles it. The harness's own
      // doc records the same trap.
      await tester.pumpAndSettle();
      final Color light = _tintOf(tester);

      const EvaColors darkColors = EvaColors.dark();
      const EvaColors lightColors = EvaColors.light();
      expect(dark, darkColors.canvas.withValues(alpha: 0.86));
      expect(light, lightColors.canvas.withValues(alpha: 0.74));
    });
  });

  group('the orb', () {
    testWidgets('is 30 by 30', (WidgetTester tester) async {
      // **In a loose parent**, for the reason the dock's own fixture records:
      // a tight parent keeps its own size, and the orb's 30 is a request.
      await pumpPrimitive(tester, const Center(child: LumenOrb()));
      expect(tester.getSize(find.byType(LumenOrb)).width, LumenOrb.diameter);
      expect(tester.getSize(find.byType(LumenOrb)).height, LumenOrb.diameter);
    });

    testWidgets('paints the ember gradient', (WidgetTester tester) async {
      await pumpPrimitive(
        tester,
        Center(
          child: RepaintBoundary(key: _orbKey, child: const LumenOrb()),
        ),
      );

      // ## THE TOKENS THE GRADIENT IS BUILT FROM
      //
      // Read off the **rendered** decoration, so the claim is about what the
      // widget built rather than about what it was told to build.
      final DecoratedBox body = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(LumenOrb),
              matching: find.byType(DecoratedBox),
            ),
          )
          .first;
      final BoxDecoration decoration = body.decoration as BoxDecoration;
      final RadialGradient gradient = decoration.gradient! as RadialGradient;
      final EvaColors colors = _colorsOf(tester, find.byType(LumenOrb));
      expect(gradient.colors, <Color>[
        colors.emberSheen,
        colors.ember,
        colors.emberDeep,
      ]);
      expect(gradient.stops, <double>[0, 0.5, 0.9]);

      // ## AND THE PIXELS
      //
      // Three samples across the gradient, read off the painted layer: the
      // sheen at the gradient's centre, the gold past the halfway stop, and
      // the deep gold near the rim.
      final Uint8List pixels = await _pixelsOf(tester, find.byKey(_orbKey));
      final int side = LumenOrb.diameter.toInt();
      final Color sheen = _pixelAt(pixels, side, 10, 10);
      final Color gold = _pixelAt(pixels, side, 20, 22);
      final Color deep = _pixelAt(pixels, side, 23, 26);

      // A gradient and not a flat fill.
      expect(sheen, isNot(gold));
      expect(gold, isNot(deep));
      // The gold and the deep gold are the **ember ramp**: more red than
      // green, more green than blue. A grey orb or a blue one fails here.
      expect(gold.r, greaterThan(gold.g));
      expect(gold.g, greaterThan(gold.b));
      expect(deep.r, greaterThan(deep.g));
      expect(deep.g, greaterThan(deep.b));
      // And the ramp runs *down* towards the deep stop.
      expect(
        deep.computeLuminance(),
        lessThan(gold.computeLuminance()),
        reason: '`:229`\'s `#a97a1e` stop is darker than the gold',
      );
      // The centre is the **sheen** and not the gold: a neutral, translucent
      // highlight over the dock rather than a saturated fill.
      expect(
        _saturation(sheen),
        lessThan(_saturation(gold)),
        reason: 'the highlight is white at 28% and the gold is not',
      );
    });

    test('the ripple phase is the prototype\'s period', () {
      expect(LumenOrb.ripplePeriodSeconds, 2.6);
      // Half a period is half a cycle, and a whole period is back at the
      // start — the same restart the CSS animation makes.
      expect(LumenOrb.ripplePhase(0), 0);
      expect(LumenOrb.ripplePhase(1.3), closeTo(0.5, 1e-9));
      expect(LumenOrb.ripplePhase(2.6), closeTo(0.0, 1e-9));
      expect(LumenOrb.ripplePhase(3.9), closeTo(0.5, 1e-9));
    });
  });
}

/// The key of the orb's own repaint boundary, for the pixel probe.
final Key _orbKey = UniqueKey();

/// The five slots, in the prototype's order (`eva/redesign.html:703-707`).
///
/// **Anchored to the bottom of the surface**, which is where the prototype
/// puts it (`:208` — `position:absolute;left:0;right:0;bottom:0`) and which
/// is also what gives the dock the *loose* height constraint it needs: a
/// parent that hands a child a **tight** height keeps it, so the dock's own 78
/// is a request rather than a command. The [Align] is the Flutter spelling of
/// the prototype's `bottom:0`.
Widget _dock({int activeIndex = 0, void Function(int index)? onSelect}) =>
    Align(
      alignment: Alignment.bottomCenter,
      child: LumenDock(
        activeIndex: activeIndex,
        onSelect: onSelect ?? (int _) {},
        items: const <LumenDockItem>[
          LumenDockItem(label: 'Home', glyph: Icon(Icons.home)),
          LumenDockItem(label: 'Read', glyph: Icon(Icons.menu_book)),
          LumenDockItem(label: 'Today', glyph: LumenOrb()),
          LumenDockItem(label: 'Communion', glyph: Icon(Icons.emoji_events)),
          LumenDockItem(label: 'Journey', glyph: Icon(Icons.person)),
        ],
      ),
    );

/// The palette the tree under [finder] was pumped with.
EvaColors _colorsOf(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).extension<EvaColors>()!;

/// The scale of each of the [transforms], in tree order.
///
/// **The x scale, and not `getMaxScaleOnAxis()`** — the latter is the largest
/// singular value of the whole 3×3, and a flat scale of `.94` leaves the z
/// axis at 1.0, so it would report 1.0 for a scale that is plainly there.
List<double> _scales(WidgetTester tester, Finder transforms) => <double>[
  for (final Transform transform in tester.widgetList<Transform>(transforms))
    transform.transform.entry(0, 0),
];

/// The dock's own tint — the box that carries the background and the border.
Color _tintOf(WidgetTester tester) {
  final DecoratedBox tint = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .firstWhere(
        (DecoratedBox box) =>
            (box.decoration as BoxDecoration?)?.border != null,
      );
  return (tint.decoration as BoxDecoration).color!;
}

/// Every distinct box the tree laid out.
///
/// **Deduplicated by identity**, because `Element.renderObject` hands back the
/// *nearest descendant* render object — so a `StatelessWidget` element and
/// the render object below it report the same box, and counting them twice
/// would make every count in this file a different number from the one a
/// reader expects.
List<RenderBox> _boxes(WidgetTester tester) {
  final Set<RenderBox> boxes = <RenderBox>{};
  for (final Element element in tester.allElements) {
    final RenderObject? object = element.renderObject;
    if (object is RenderBox) boxes.add(object);
  }
  return boxes.toList();
}

/// The boxes [height] tall, as the distinct rectangles they occupy.
List<Rect> _rectsOfHeight(WidgetTester tester, double height) => <Rect>{
  for (final RenderBox box in _boxes(tester))
    if (box.size.height == height) box.localToGlobal(Offset.zero) & box.size,
}.toList();

/// The five beams, as the rectangles they occupy.
///
/// **Located by their width**, which is the prototype's own number (`:221` —
/// `width:2px`), rather than by the widget that drew them: the claim under
/// test is the beam's geometry, so the finder asks the geometry.
List<Rect> _beams(WidgetTester tester) => <Rect>{
  for (final RenderBox box in _boxes(tester))
    if (box.size.width == LumenDock.beamWidth)
      box.localToGlobal(Offset.zero) & box.size,
}.toList();

/// The RGBA bytes of the layer under [finder].
///
/// **The same instrument as `design_system_harness.dart`'s
/// `backgroundPixels`, pointed at a different target.** `toImageSync` and not
/// `toImage`, because `toImage` waits for the next frame and the test body
/// runs inside a fake-async zone where that frame never arrives; and
/// `runAsync` around `toByteData`, because that half crosses into the engine.
Future<Uint8List> _pixelsOf(WidgetTester tester, Finder finder) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(finder);
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = boundary.toImageSync();
    final ByteData? data = await image.toByteData();
    image.dispose();
    if (data == null) {
      throw StateError('the orb\'s layer produced no pixels');
    }
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('runAsync returned no pixels');
  }
  return bytes;
}

/// The pixel at ([x], [y]) of a [side]-wide RGBA buffer.
Color _pixelAt(Uint8List pixels, int side, int x, int y) {
  final int offset = (y * side + x) * 4;
  return Color.fromARGB(
    pixels[offset + 3],
    pixels[offset],
    pixels[offset + 1],
    pixels[offset + 2],
  );
}

/// How saturated a colour is — the spread between its channels over its
/// largest one.
///
/// **On the 0..1 scale**, because `Color.r` and its siblings are doubles in
/// this SDK and an `int` list would not hold them.
double _saturation(Color color) {
  final List<double> channels = <double>[color.r, color.g, color.b];
  final double largest = channels.reduce((double a, double b) => a > b ? a : b);
  final double smallest = channels.reduce(
    (double a, double b) => a < b ? a : b,
  );
  if (largest == 0) return 0;
  return (largest - smallest) / largest;
}
