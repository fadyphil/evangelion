import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The Phase 3 keyboard gate: `SegmentedControl` **selects via keyboard**, not
/// just via taps. `08-build-phases.md` §Phase 3 names it as the phase's verify
/// line and the prototype cannot pass it — `SettingsScreen.tsx:6,52-61` is three
/// `<button>`s over a `useState`, so a keyboard reaches them one at a time and
/// arrow keys do nothing at all.
///
/// The model itself ([nextSelection], [selectionStepFor]) is pinned in
/// `selection_model_test.dart`; this file is the widget wiring it to keys.
void main() {
  final Finder controlFinder = find.byType(SegmentedControl<String>);

  Future<void> pump(
    WidgetTester tester, {
    String selected = 'Dark',
    ValueChanged<String>? onPicked,
    ThemeData? theme,
    bool disableAnimations = false,
    TextDirection direction = TextDirection.ltr,
  }) => pumpPrimitive(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: _Live(initial: selected, onPicked: onPicked),
    ),
    theme: theme,
    disableAnimations: disableAnimations,
    textDirection: direction,
  );

  /// The sliding thumb — `redesign.html:179-182` — or `null` while it is not yet
  /// measured.
  ///
  /// `null` for exactly one frame after the first layout, because the thumb's
  /// width is the **selected segment's** width and that is only knowable once the
  /// tree has laid out. See the widget's `_measureThumb` doc for why no
  /// `LayoutBuilder` can answer it, and why nothing else measures differently in
  /// its absence.
  AnimatedPositioned? thumb(WidgetTester tester) {
    final Finder f = find.descendant(
      of: controlFinder,
      matching: find.byType(AnimatedPositioned),
    );
    return f.evaluate().isEmpty ? null : tester.widget<AnimatedPositioned>(f);
  }

  /// The thumb's painted rectangle, or `null` while it is not painted.
  Rect? thumbRect(WidgetTester tester) {
    final Finder f = find.descendant(
      of: controlFinder,
      matching: find.byType(AnimatedPositioned),
    );
    return f.evaluate().isEmpty ? null : tester.getRect(f);
  }

  /// Every segment's rendered rect, in `values` order — `Light`, `Dark`,
  /// `System`.
  ///
  /// Read off the segments' own `InkWell`s and **scoped to the `Row`**, because
  /// `EvaInk` builds an `InkWell` too: a bare
  /// `find.byType(InkWell)` inside the control matches the track's as well, and
  /// the track is first in document order.
  ///
  /// The `InkWell` rather than the `Text`, because the thumb's `width` is the
  /// **segment's** width — `redesign.html:179` sizes it to the button, not to
  /// the label — and a label is narrower than its button by `segmentPadding` on
  /// each side.
  List<Rect> segmentRects(WidgetTester tester) {
    final Finder wells = find.descendant(
      of: find.descendant(of: controlFinder, matching: find.byType(Row)),
      matching: find.byType(InkWell),
    );
    return <Rect>[
      for (int i = 0; i < wells.evaluate().length; i++)
        tester.getRect(wells.at(i)),
    ];
  }

  /// The style a segment's label renders with — which since Phase 4.2 is the
  /// `AnimatedDefaultTextStyle`'s, not the `Text`'s.
  ///
  /// Scoped to the segment's own `InkWell` because `Material`, `EvaInk` and the
  /// harness all put `AnimatedDefaultTextStyle`s in the tree, and a bare
  /// descendant finder resolves to whichever came first in document order rather
  /// than to the one painting this label.
  TextStyle segmentStyleOf(WidgetTester tester, String label) => tester
      .widget<AnimatedDefaultTextStyle>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text(label.toUpperCase()),
                matching: find.byType(InkWell),
              ),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      )
      .style;

  group('Phase 3 gate — selects via keyboard', () {
    testWidgets('Tab reaches the control, and it is one stop', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tabUntilFocused(tester, controlFinder);
      await tester.pump();
      expect(thumb(tester), isNotNull, reason: 'the thumb settled onto Dark');
    });

    testWidgets('one Tab leaves the control, so it is not three stops', (
      WidgetTester tester,
    ) async {
      // A sibling control **after** the segmented control. Without a second
      // focusable in the tree, Tab has nowhere to go and stays put, which would
      // make "Tab left" untestable rather than false.
      await pumpPrimitive(
        tester,
        const Column(
          children: <Widget>[
            _Live(initial: 'Dark'),
            EvaButton(
              labelFamily: EvaTypography.uiFamily,
              label: 'After',
              onPressed: _noop,
            ),
          ],
        ),
      );
      await tabUntilFocused(tester, controlFinder);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Three separately focusable segments would need three more presses before
      // focus reached the button; one means the control is a single stop.
      expect(semanticsOf(tester, find.text('After')).label, 'After');
      expect(
        tester
            .widget<Focus>(
              find
                  .descendant(
                    of: find.byType(EvaButton),
                    matching: find.byType(Focus),
                  )
                  .first,
            )
            .focusNode
            ?.hasFocus,
        isTrue,
        reason: 'focus arrived at the next control in one press',
      );
    });

    testWidgets('ArrowRight steps forward and wraps', (
      WidgetTester tester,
    ) async {
      final List<String> seen = <String>[];
      await pump(tester, onPicked: seen.add);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <String>['System']);
      expect(find.text('LIGHT'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <String>['System', 'Light']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen.last, 'Dark', reason: 'three options, three steps, wrapped');
    });

    testWidgets('ArrowLeft steps back and wraps', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      await pump(tester, onPicked: seen.add);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seen, <String>['Light']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seen.last, 'System');
    });

    testWidgets('the thumb follows the selection, not just the callback', (
      WidgetTester tester,
    ) async {
      // The load-bearing half of "selects via keyboard": a control that reports a
      // new value but does not *move its selection* has not selected anything.
      //
      // Rewritten in Phase 4.2. It used to compare each segment's fill colour,
      // which is the half the redesign deleted: `redesign.html:183` gives
      // `button` `background:none` and the selection is now drawn by one thumb
      // behind the labels (`:179`). Comparing pixels of a fill that no longer
      // exists would have kept passing while asserting nothing.
      await pump(tester);
      // The arrow key is handled by `EvaFocusRing`'s `onKeyEvent`, so the control
      // must hold focus first — the Phase 3 model is "one tab stop, arrows move
      // within it", and without the Tab the key goes nowhere and the thumb
      // correctly does not move.
      await tabUntilFocused(tester, controlFinder);
      await tester.pump();

      final List<Rect> before = segmentRects(tester);
      expect(before, hasLength(3));
      final Rect? onDark = thumbRect(tester);
      expect(onDark, isNotNull);
      // The thumb is on the *middle* segment — `Dark` is the initial selection.
      expect(onDark!.left, closeTo(before[1].left, 0.01));
      expect(onDark.width, closeTo(before[1].width, 0.01));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      final List<Rect> after = segmentRects(tester);
      final Rect? onLight = thumbRect(tester);
      expect(onLight!.left, closeTo(after[0].left, 0.01));
      expect(onLight.width, closeTo(after[0].width, 0.01));
      // **Not** "the widths differ". Measured on the harness's 320-wide surface
      // the three segments come out at 104 each — `redesign.html:183`'s `flex:1`
      // *is* honoured, because `RenderFlex` shares `maxMainSize` between flex
      // children whenever the incoming width is finite — so the thumb's `width`
      // is constant on this fixture and only `left` moves. The width assertion
      // that matters is the one above, that it is the segment's width and not a
      // fraction of the track; the `the thumb spans the segment` test below is
      // what rules out the guess. On a narrower fixture, or with labels of very
      // different lengths, the two would differ and both assertions still hold.
      expect(
        onLight.left,
        isNot(closeTo(onDark.left, 0.01)),
        reason: 'the thumb actually moved — that is the whole claim',
      );
    });

    testWidgets('the thumb spans the segment, not the label inside it', (
      WidgetTester tester,
    ) async {
      // The one assertion that keeps `widthFactor`-style guessing out: if the
      // thumb were the label's width it would be narrower than its segment by
      // `segmentPadding` on each side.
      await pump(tester);
      await tester.pump();
      final List<Rect> segments = segmentRects(tester);
      final Rect t = thumbRect(tester)!;
      expect(t.width, greaterThan(segments[1].width - 0.01));
      expect(t.width, closeTo(segments[1].width, 0.01));

      // And it spans the segment **vertically** — `top:0;bottom:0`, which is
      // `redesign.html:179`'s `top:3px;bottom:3px` expressed inside a padding box
      // that is already inset by the track's own 3. `:179` is a `position:
      // absolute` rule with two offsets, so under a stretched `.segp` the thumb
      // stretches with the buttons, and that is what CSS draws.
      //
      // **Why this is asserted at all, given the golden already shows it.** In
      // this harness the control fills its parent: `pumpPrimitive` hands the
      // subtree loose constraints, but the `Material` + `InkWell` + `Align`
      // chain takes them as bounded and fills — a factorless `Align` sizes to
      // `constraints.biggest`, measured rather than assumed — so the three
      // segments are **560px** tall inside a 568px surface. That is
      // **pre-existing**: the committed `segmented_control_dark.png` is a 320×568
      // frame and `icon_action_button_dark.png` is too. So the tall gold pill in
      // the re-recorded golden is the fixture, not a defect the thumb introduced,
      // and stating it here means the next reader who opens the PNG finds the
      // explanation in a test rather than concluding the widget draws a
      // viewport-tall pill in the app.
      expect(t.height, closeTo(segments[1].height, 0.01));
      expect(
        t.top,
        closeTo(segments[1].top, 0.01),
        reason: 'the thumb is inset by the track padding, not by anything else',
      );
      expect(t.bottom, closeTo(segments[1].bottom, 0.01));
    });

    testWidgets('focus does not leave the control while arrowing', (
      WidgetTester tester,
    ) async {
      // The reason [EvaFocusRing] forwards key events instead of letting the
      // default `HorizontalTraversalIntent` run: if focus moved, a reader arrowing
      // through a setting would land in the next control instead of the next value.
      await pump(tester);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        tester
            .widget<Focus>(
              find
                  .descendant(of: controlFinder, matching: find.byType(Focus))
                  .first,
            )
            .focusNode
            ?.hasFocus,
        isTrue,
      );
    });

    testWidgets('ArrowRight walks backwards in an RTL screen', (
      WidgetTester tester,
    ) async {
      // §14 and prototype defect #2 in the same place: a control whose "forward"
      // ignores `Directionality` is the same bug as Arabic laid out LTR.
      final List<String> seen = <String>[];
      await pump(tester, onPicked: seen.add, direction: TextDirection.rtl);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <String>['Light'], reason: 'RTL flips what "forward" means');
    });

    testWidgets('Home and End jump to the ends', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      await pump(tester, onPicked: seen.add);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(seen.last, 'System');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(seen.last, 'Light');
    });

    testWidgets('a tap still works — the keyboard is additive', (
      WidgetTester tester,
    ) async {
      final List<String> seen = <String>[];
      await pump(tester, onPicked: seen.add);
      await tester.tap(find.text('LIGHT'));
      await tester.pump();
      expect(seen, <String>['Light']);
    });

    testWidgets('with animations off the thumb lands at once', (
      WidgetTester tester,
    ) async {
      await pump(tester, disableAnimations: true);
      await tester.pump();
      expect(thumb(tester)!.duration, Duration.zero);
      final List<Rect> segments = segmentRects(tester);
      expect(
        thumbRect(tester)!.left,
        closeTo(segments[1].left, 0.01),
        reason: 'no in-between frame, so it is already on Dark',
      );
    });
  });

  group('Semantics', () {
    testWidgets('each segment is a button that reports itself selected', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester);
      handle.dispose();

      final chosen = semanticsOf(tester, find.text('DARK'));
      expect(chosen.flagsCollection.isButton, isTrue);
      expect(chosen.flagsCollection.isSelected.toBoolOrNull(), isTrue);

      final idle = semanticsOf(tester, find.text('LIGHT'));
      expect(idle.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    });

    testWidgets('every node the reader can activate is also nameable', (
      WidgetTester tester,
    ) async {
      // The defect this covers: the **track** is a button. `EvaInk` publishes a
      // tap action on the node above the three segments, and the node carried no
      // label at all — so `/settings`, which renders this control twice (the
      // theme picker and the language pills), shipped two buttons a screen reader
      // could land on and could not name. That is §14's first row applied to a
      // widget the row does not name.
      //
      // Asserted over the whole tree and filtered on the **action**, because the
      // question is about what a reader can press; the harness's own nodes come
      // back with no actions at all, so nothing else is in the list.
      await pump(tester);
      final List<SemanticsData> actionable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );

      expect(
        actionable,
        isNotEmpty,
        reason: 'the control is tappable — nothing else would make this a test',
      );
      for (final SemanticsData data in actionable) {
        expect(
          data.label.trim(),
          isNotEmpty,
          reason:
              'a node a reader can activate with nothing to name it. The track '
              'is one of these, and so are the three segments.',
        );
      }
      // And specifically: the track is named after the **selected** option, which
      // is the one fact about the control that is true at every moment and the
      // fact the arrow keys are about to replace.
      expect(
        actionable.expand((SemanticsData d) => d.label.split('\n')),
        contains('Dark'),
      );
    });

    testWidgets('the track contributes one of the four, and it is named', (
      WidgetTester tester,
    ) async {
      // Why the track keeps its tap action at all, asserted rather than argued:
      // `EvaFocusRing` owns the control's single `FocusNode` but inserts no
      // `Focus` (a second one would make the node its own parent — see that
      // widget's doc), and the `EvaInk` is the only thing binding that node into
      // the focus tree. A track with no `onPressed` would therefore be a control
      // **Tab cannot reach at all**, which is a worse §14 defect than an unnamed
      // one. Reachability itself is `focus_ring_gate_test.dart`'s assertion; this
      // is the naming half.
      await pump(tester);
      final List<SemanticsData> actionable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );

      expect(
        actionable.map((SemanticsData d) => d.label),
        <String>['Dark', 'Light', 'Dark', 'System'],
        reason:
            'the track plus the three segments, in paint order — the track is '
            'named after the selected option because that is the one fact about '
            'the control that is true at every moment',
      );
    });

    testWidgets('an out-of-list `selected` still names the control', (
      WidgetTester tester,
    ) async {
      // `nextSelection`'s doc records that a persisted setting naming a value a
      // rebuilt enum no longer has is reachable. The track's label is built by the
      // caller's `labelOf`, which is a function over `values` — so calling it with
      // a value the list does not contain would be a crash in `build`, taking the
      // screen down. Guarded, and the guard is observable here.
      await pumpPrimitive(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: SegmentedControl<String>(
            values: <String>['Light', 'Dark', 'System'],
            selected: 'Sepia',
            labelOf: _identity,
            onChanged: _ignore,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        nodesOffering(
          tester,
          SemanticsAction.tap,
        ).map((SemanticsData d) => d.label),
        contains('Light'),
        reason: 'the first option, which is also where a forward step snaps to',
      );
    });
  });

  group('shape', () {
    testWidgets('an empty value list renders no text and does not throw', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        SegmentedControl<String>(
          values: const <String>[],
          selected: '',
          labelOf: (String value) => value,
          onChanged: (String _) {},
        ),
      );
      expect(controlFinder, findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the track is the prototype\'s one filled container', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      // `redesign.html:178` — one `border-radius:999px` wrapper with a fill and
      // a 1px rim, not three separate pills. **Was** `SettingsScreen.tsx:51`'s
      // `borderRadius: 8` with no `border` at all; `:178` is the redesign's own.
      final Container track = tester.widget<Container>(
        find
            .descendant(of: controlFinder, matching: find.byType(Container))
            .first,
      );
      final BoxDecoration d = track.decoration! as BoxDecoration;
      expect(
        d.borderRadius,
        BorderRadius.circular(SegmentedControl.trackRadius),
      );
      expect(SegmentedControl.trackRadius, EvaRadii.chip);
      expect(SegmentedControl.trackRadius, 999.0);
      expect(
        d.border,
        isNotNull,
        reason: '`border:1px solid var(--glass-line)`',
      );
      expect(d.border!.top.color, const EvaColors.dark().glassBorder);
      // `:178` — `padding:3px`, which is also the thumb's `top/bottom/left`
      // inset (`:179`). Same number, so it is named once.
      expect(SegmentedControl.trackPadding, 3);
      expect(track.padding, const EdgeInsets.all(3));
    });

    testWidgets('the thumb is the prototype\'s gold pill, glowing and sheened', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tester.pump();
      // `redesign.html:180-181`. Two shadows, and both matter: the outer glow is
      // what makes the thumb read as lit, the inset is what makes it read as
      // *gold* rather than as a flat orange rectangle.
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AnimatedPositioned),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration d = box.decoration as BoxDecoration;

      final LinearGradient fill = d.gradient! as LinearGradient;
      expect(fill.begin, Alignment.topCenter, reason: '`180deg`');
      expect(fill.end, Alignment.bottomCenter);
      expect(fill.colors, <Color>[
        const EvaColors.dark().ember.withValues(
          alpha: SegmentedControl.thumbFillTop,
        ),
        const EvaColors.dark().ember.withValues(
          alpha: SegmentedControl.thumbFillBottom,
        ),
      ]);
      expect(SegmentedControl.thumbFillTop, 0.95);
      expect(SegmentedControl.thumbFillBottom, 0.72);

      expect(d.boxShadow, hasLength(2));
      expect(
        d.boxShadow!.first.color,
        const EvaColors.dark().ember.withValues(
          alpha: SegmentedControl.thumbGlowAlpha,
        ),
      );
      expect(d.boxShadow!.first.blurRadius, 14);
      expect(d.boxShadow!.last.color, const EvaColors.dark().emberSheen);
      expect(d.boxShadow!.last.blurRadius, 10);

      // `:182` — `transition:left .35s`, and 350ms is not a token, which is why
      // the widget names it rather than rounding to `EvaMotion.screen`.
      expect(thumb(tester)!.duration, SegmentedControl.thumbDuration);
      expect(SegmentedControl.thumbDuration, const Duration(milliseconds: 350));
    });

    testWidgets('the selected label is `onEmber` — in dark that is not gold', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tester.pump();
      // `redesign.html:185` — `.segp button.on{color:#1c1608}`.
      //
      // The regression this pins: the label used to be `emberInk`, which in dark
      // **is** `ember` — the thumb's own fill. Gold on gold is the defect the
      // redesign's `.on` rule exists to fix, and `onEmber` is this palette's name
      // for the fix.
      expect(thumbRect(tester), isNotNull, reason: 'the thumb is behind it');
      expect(
        tester.widget<Text>(find.text('DARK')).style?.color,
        isNull,
        reason:
            'the colour is on the `AnimatedDefaultTextStyle`, not the `Text`',
      );
      final AnimatedDefaultTextStyle selected = tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .descendant(
                  of: find.ancestor(
                    of: find.text('DARK'),
                    matching: find.byType(InkWell),
                  ),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          );
      expect(selected.style.color, const EvaColors.dark().onEmber);
      expect(selected.style.color, isNot(const EvaColors.dark().ember));
      expect(selected.style.color, isNot(const EvaColors.dark().emberInk));
      // The unselected arms, for contrast: `:184`'s button is `--ink-2`.
      expect(
        segmentStyleOf(tester, 'Light').color,
        const EvaColors.dark().ink2,
      );
      expect(
        segmentStyleOf(tester, 'Light').color,
        isNot(const EvaColors.dark().onEmber),
      );
    });

    testWidgets('the labels are the prototype\'s mono caps', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      expect(find.text('DARK'), findsOneWidget);
      expect(
        find.text('Dark'),
        findsNothing,
        reason: 'uppercased — Flutter has no CSS-style `text-transform`',
      );
      // **From Phase 4.2: on the `AnimatedDefaultTextStyle`, not on the `Text`.**
      // The colour has to transition (`:183`'s `transition:color .3s`), and an
      // explicit `Text.style` wins over the ambient default — so the style moved
      // up and this assertion moved with it. Reading `Text.style` would have
      // thrown on a null, which is the only reason this line changed shape.
      final Text label = tester.widget<Text>(find.text('DARK'));
      expect(label.style, isNull, reason: 'it inherits the animated default');
      expect(
        segmentStyleOf(tester, 'Dark').fontFamily,
        EvaTypography.monoFamily,
      );
    });
  });

  for (final (String theme, ThemeData data) in kEvaThemes) {
    testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
      await pump(tester, theme: data);
      await tester.pump();
      // **The golden must contain the thumb.** It is measured one frame after
      // the first layout, and a golden re-recorded on the frame before it
      // settled would be a picture of the control *without* its defining
      // feature — which every later reader would take as the design. Asserting
      // it here makes "the thumb is missing" a red instead of a PNG nobody
      // re-examines.
      expect(thumb(tester), isNotNull);
      await expectLater(
        controlFinder,
        matchesGoldenFile('goldens/segmented_control_$theme.png'),
      );
    });
  }

  testWidgets('state golden — focused', (WidgetTester tester) async {
    await pump(tester);
    await tabUntilFocused(tester, controlFinder);
    await tester.pump();
    expect(thumb(tester), isNotNull);
    await expectLater(
      controlFinder,
      matchesGoldenFile('goldens/segmented_control_state_focused.png'),
    );
  });
}

/// A control whose `selected` **follows** `onChanged`.
///
/// [SegmentedControl] is a controlled component: `onChanged` reports and the
/// caller feeds the value back. A test that pumps a fixed `selected` and then
/// presses an arrow key twice is testing a control that never moves — and the
/// assertion it fails is about the test, not the widget. This is the smallest
/// honest stand-in for the Settings cubit that Phase 9 will supply.
void _noop() {}

class _Live extends StatefulWidget {
  const _Live({required this.initial, this.onPicked});

  final String initial;
  final ValueChanged<String>? onPicked;

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  late String _selected = widget.initial;

  @override
  Widget build(BuildContext context) => SegmentedControl<String>(
    values: const <String>['Light', 'Dark', 'System'],
    selected: _selected,
    labelOf: (String value) => value,
    onChanged: (String value) {
      setState(() => _selected = value);
      widget.onPicked?.call(value);
    },
  );
}

String _identity(String value) => value;

void _ignore(String value) {}
