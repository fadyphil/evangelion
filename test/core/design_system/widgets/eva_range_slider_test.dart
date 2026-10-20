import 'package:evangelion/core/common/ranges.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The Workshop's range slider — `redesign.html:429-430`.
///
/// The widget is TDD-exempt (AGENT_CONTEXT §6 — widget work is exempt), but the
/// **two pure functions it is built on are not**: a clamp and a step are
/// arithmetic, and AGENT_CONTEXT §6's "domain logic must not be buried inside
/// a widget" is exactly the rule that puts them here. So the first group is
/// red-first, and the rest is the widget wiring them to a tree.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    int value = 42,
    int min = 18,
    int max = 110,
    int step = 1,
    String semanticLabel = 'Reach',
    String? valueLabel,
    ValueChanged<int>? onChanged,
    ThemeData? theme,
    bool disableAnimations = false,
    TextDirection direction = TextDirection.ltr,
  }) => pumpPrimitive(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: _Live(
        value: value,
        min: min,
        max: max,
        step: step,
        semanticLabel: semanticLabel,
        valueLabel: valueLabel,
        onChanged: onChanged,
      ),
    ),
    theme: theme,
    disableAnimations: disableAnimations,
    textDirection: direction,
  );

  Finder slider() => find.byType(EvaRangeSlider);

  /// The rule and the thumb, in paint order.
  List<Container> parts(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(of: slider(), matching: find.byType(Container)),
      )
      .toList();

  /// The thumb's own box — the second container, after the rule.
  Finder thumb() =>
      find.descendant(of: slider(), matching: find.byType(Container)).last;

  group('the clamp and the step are pure functions', () {
    // ## WHY THIS GROUP IS RED-FIRST AND THE WIDGET GROUP IS NOT
    //
    // AGENT_CONTEXT §6: "domain logic must not be buried inside a widget — if
    // a widget needs a conditional or a calculation, extract it to a cubit or a
    // pure function and TDD that instead." A clamp and a step are the two
    // calculations this widget would otherwise do inside `build`, so they are
    // pure functions and they are tested without a widget tree at all.
    //
    // The prototype's only stepped slider is `redesign.html:684`:
    // `<input type="range" id="setSelahDur" min="15" max="120" step="5">`.

    test('a value below the minimum is raised to it', () {
      expect(clampRangeValue(5, 10, 20), 10);
    });

    test('a value above the maximum is lowered to it', () {
      expect(clampRangeValue(50, 10, 20), 20);
    });

    test('a value inside the range is left alone', () {
      expect(clampRangeValue(15, 10, 20), 15);
    });

    test('the step is measured from the minimum, as a CSS range input is', () {
      // `min="15" max="120" step="5"` — the stops are 15, 20, 25 … 120.
      expect(steppedRangeValue(17, 15, 120, 5), 15);
      expect(steppedRangeValue(18, 15, 120, 5), 20);
      expect(steppedRangeValue(60, 15, 120, 5), 60);
      expect(steppedRangeValue(120, 15, 120, 5), 120);
    });

    test('a step of one is the identity after the clamp', () {
      expect(steppedRangeValue(17, 15, 120, 1), 17);
      expect(steppedRangeValue(5, 15, 120, 1), 15);
      expect(steppedRangeValue(500, 15, 120, 1), 120);
    });

    test('every reachable value of the prototype\'s stepped slider is a '
        'multiple of five', () {
      // The brief's own wording: "A `step` of 5 must only ever produce
      // multiples of 5." The range is the prototype's, so the claim is about
      // real values rather than about an artificial one.
      for (int raw = 0; raw <= 130; raw++) {
        final int stepped = steppedRangeValue(raw, 15, 120, 5);
        expect(stepped % 5, 0, reason: '$raw landed on $stepped');
        expect(stepped, inInclusiveRange(15, 120), reason: '$raw → $stepped');
      }
    });

    test('the minimum stays reachable, which the global-multiple reading '
        'would lose', () {
      // A range whose minimum is not a step multiple is the one case where
      // "multiples of `step`" and "the CSS rule" disagree, and the CSS rule
      // wins: `min + n·step` keeps `min` reachable.
      expect(steppedRangeValue(15, 15, 120, 5), 15);
      expect(steppedRangeValue(3, 3, 20, 2), 3);
    });

    test('a value outside the range is clamped before it is snapped', () {
      // Snapping first would put `min`'s neighbour within reach and the
      // maximum's neighbour too, and both are outside the range.
      expect(steppedRangeValue(0, 15, 120, 5), 15);
      expect(steppedRangeValue(999, 15, 120, 5), 120);
    });
  });

  group('the pointer\'s position and the value are each a pure function', () {
    // AGENT_CONTEXT §6: "domain logic must not be buried inside a widget". The
    // pointer→value mapping is the calculation whose wrong answer is a slider
    // sitting at a value the reader did not choose, so it is a named function
    // and it is here.
    test('the value for a pointer is the fraction of the travel it names', () {
      expect(valueForOffset(dx: 0, travel: 100, min: 0, max: 100, step: 1), 0);
      expect(
        valueForOffset(dx: 50, travel: 100, min: 0, max: 100, step: 1),
        50,
      );
      expect(
        valueForOffset(dx: 100, travel: 100, min: 0, max: 100, step: 1),
        100,
      );
    });

    test('a pointer past either end selects that end', () {
      expect(
        valueForOffset(dx: -40, travel: 100, min: 0, max: 100, step: 1),
        0,
      );
      expect(
        valueForOffset(dx: 400, travel: 100, min: 0, max: 100, step: 1),
        100,
      );
    });

    test(
      'a travel of zero selects the minimum rather than dividing by zero',
      () {
        expect(
          valueForOffset(dx: 12, travel: 0, min: 18, max: 110, step: 1),
          18,
        );
      },
    );

    test('the value it selects is SNAPPED to the step', () {
      expect(
        valueForOffset(dx: 49, travel: 100, min: 0, max: 100, step: 5),
        50,
        reason: 'the nearest multiple of five to 49 is 50',
      );
    });

    test("and the thumb's position is the mirror", () {
      expect(offsetForValue(value: 0, min: 0, max: 100, travel: 100), 0);
      expect(offsetForValue(value: 50, min: 0, max: 100, travel: 100), 50);
      expect(offsetForValue(value: 100, min: 0, max: 100, travel: 100), 100);
    });

    test('a range with no span puts the thumb at the start', () {
      expect(offsetForValue(value: 7, min: 7, max: 7, travel: 100), 0);
    });

    test('and the two are inverses of each other over a whole range', () {
      for (int value = 0; value <= 100; value++) {
        final double offset = offsetForValue(
          value: value,
          min: 0,
          max: 100,
          travel: 100,
        );
        expect(
          valueForOffset(dx: offset, travel: 100, min: 0, max: 100, step: 1),
          value,
          reason:
              'the pointer at the thumb\'s position selects the thumb\'s value',
        );
      }
    });
  });

  group('EvaRangeSlider', () {
    testWidgets('the rule is 3px of 14% ink on a 120px track', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final List<Container> boxes = parts(tester);
      expect(boxes, hasLength(2), reason: 'the rule and the thumb');

      final BoxDecoration rule = boxes.first.decoration! as BoxDecoration;
      expect(EvaRangeSlider.trackHeight, 3);
      expect(EvaRangeSlider.trackWidth, 120);
      expect(
        rule.color,
        const EvaColors.dark().ink.withValues(alpha: 0.14),
        reason: '`redesign.html:429` — `background: rgba(255,255,255,.14)`',
      );
      expect(
        rule.borderRadius,
        BorderRadius.circular(3),
        reason: '`redesign.html:429` — `border-radius: 3px`',
      );
      expect(
        tester.getSize(slider()),
        const Size(120, 15),
        reason: 'the track is 120 wide and the thumb is 15 tall',
      );
    });

    testWidgets('the light arm is the prototype\'s own 18%', (
      WidgetTester tester,
    ) async {
      await pump(tester, theme: EvaThemeLight.theme);
      final BoxDecoration rule =
          parts(tester).first.decoration! as BoxDecoration;
      expect(
        rule.color,
        const EvaColors.light().ink.withValues(alpha: 0.18),
        reason: '`redesign.html:95` — `rgba(20,22,30,.18)`',
      );
      expect(EvaRangeSlider.trackAlphaDark, 0.14);
      expect(EvaRangeSlider.trackAlphaLight, 0.18);
    });

    testWidgets('the thumb is a 15px gold disc with the prototype\'s glow', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final BoxDecoration thumb =
          parts(tester).last.decoration! as BoxDecoration;
      expect(EvaRangeSlider.thumbSize, 15);
      expect(thumb.color, const EvaColors.dark().ember);
      expect(thumb.shape, BoxShape.circle);
      expect(thumb.boxShadow!.single.blurRadius, 10);
      expect(
        thumb.boxShadow!.single.color,
        const EvaColors.dark().ember.withValues(alpha: 0.7),
        reason: '`redesign.html:430` — `0 0 10px rgba(232,176,75,.7)`',
      );
    });

    testWidgets('the thumb is drawn where the value says, not where the '
        'arithmetic guesses', (WidgetTester tester) async {
      for (final (int value, double expected) in <(int, double)>[
        (18, 0),
        (64, 52.5),
        (110, 105),
      ]) {
        await pump(tester, value: value);
        final double dx =
            tester.getTopLeft(thumb()).dx - tester.getTopLeft(slider()).dx;
        expect(
          dx,
          moreOrLessEquals(expected, epsilon: 0.01),
          reason:
              'value $value of 18…110 — the thumb travels between two '
              'centres, so it never hangs off the end of the rule',
        );
      }
    });

    testWidgets('it announces itself as a slider, with its own name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester);
      handle.dispose();

      final node = semanticsOf(tester, slider());
      expect(node.label, 'Reach');
      expect(node.value, '42');
      expect(node.flagsCollection.isSlider, isTrue);
    });

    testWidgets('the announced value is the caller\'s string when it has one', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, valueLabel: '42 s');
      handle.dispose();

      expect(
        semanticsOf(tester, slider()).value,
        '42 s',
        reason:
            'the unit is the caller\'s — the prototype paints no number '
            'at all, so the client paints none either',
      );
    });

    testWidgets('a screen reader can raise and lower it', (
      WidgetTester tester,
    ) async {
      final List<int> seen = <int>[];
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, onChanged: seen.add);

      final node = semanticsOf(tester, slider());
      expect(node.increasedValue, '43');
      expect(node.decreasedValue, '41');

      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(seen, <int>[43]);

      node.owner!.performAction(node.id, SemanticsAction.decrease);
      await tester.pump();
      expect(
        seen,
        <int>[43, 42],
        reason:
            'the decrease is taken from the value the control now holds — '
            '43 — so it lands on 42 and not on the 41 the first reading '
            'suggested',
      );
      // Disposed in the BODY — recorded decision 38.
      handle.dispose();
    });

    testWidgets('a drag lands on the nearest reachable value', (
      WidgetTester tester,
    ) async {
      final List<int> seen = <int>[];
      await pump(tester, value: 0, min: 0, max: 100, onChanged: seen.add);

      final TestGesture gesture = await tester.startGesture(
        tester.getTopLeft(slider()) + const Offset(10, 7),
      );
      await gesture.moveBy(const Offset(50, 0));
      await gesture.up();
      await tester.pump();

      expect(seen, isNotEmpty);
      expect(seen.last, 50, reason: 'the middle of a 0…100 track');
    });

    testWidgets('a drag on a stepped slider only ever reports multiples of '
        'five', (WidgetTester tester) async {
      final List<int> seen = <int>[];
      await pump(
        tester,
        value: 15,
        min: 15,
        max: 120,
        step: 5,
        onChanged: seen.add,
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getTopLeft(slider()) + const Offset(4, 7),
      );
      await gesture.moveBy(const Offset(37, 0));
      await gesture.up();
      await tester.pump();

      expect(seen, isNotEmpty);
      for (final int value in seen) {
        expect(value % 5, 0, reason: '$value');
      }
    });

    testWidgets('the arrow keys move it, and Home and End reach the ends', (
      WidgetTester tester,
    ) async {
      final List<int> seen = <int>[];
      await pump(tester, onChanged: seen.add);
      await tabUntilFocused(tester, slider());

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <int>[43]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seen, <int>[43, 42]);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(seen.last, 18);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(seen.last, 110);
    });

    testWidgets('under RTL the arrow keys reverse, because the minimum is on '
        'the right', (WidgetTester tester) async {
      final List<int> seen = <int>[];
      await pump(tester, onChanged: seen.add, direction: TextDirection.rtl);
      await tabUntilFocused(tester, slider());

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        seen,
        <int>[41],
        reason:
            '`selectionStepFor`\'s rule — the same one the segmented '
            'control uses, and for the same reason',
      );
    });

    testWidgets('a stepped slider steps by its step, not by one', (
      WidgetTester tester,
    ) async {
      final List<int> seen = <int>[];
      await pump(
        tester,
        value: 60,
        min: 15,
        max: 120,
        step: 5,
        onChanged: seen.add,
      );
      await tabUntilFocused(tester, slider());

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <int>[65]);
    });

    testWidgets('it takes a focus ring, because §14 asks every interactive '
        'widget for one', (WidgetTester tester) async {
      await pump(tester);
      await tabUntilFocused(tester, slider());
      expect(
        renderedBorders(tester, slider()),
        contains(evaFocusRingBorder(const EvaColors.dark())),
      );
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pump(tester, theme: data);
        await tester.pump();
        await expectLater(
          slider(),
          matchesGoldenFile('goldens/eva_range_slider_$theme.png'),
        );
      });
    }
  });
}

/// A slider whose value **follows** [onChanged].
///
/// `EvaRangeSlider` is a controlled component: it reports and the caller feeds
/// the value back. A test that pumps a fixed value and then drags is testing a
/// control that never moves — the same reason `segmented_control_test.dart`'s
/// `_Live` exists.
class _Live extends StatefulWidget {
  const _Live({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.semanticLabel,
    required this.valueLabel,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String semanticLabel;
  final String? valueLabel;
  final ValueChanged<int>? onChanged;

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  late int _value = widget.value;

  @override
  void didUpdateWidget(_Live oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new value from the parent **replaces** the one this widget is holding.
    // Without this the state survives a re-pump with a different `value` and
    // every assertion about the thumb's position reads the FIRST value — which
    // is how the first run of this file reported a thumb at 0.0 for a value of
    // 64.
    if (widget.value != oldWidget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => EvaRangeSlider(
    value: _value,
    min: widget.min,
    max: widget.max,
    step: widget.step,
    semanticLabel: widget.semanticLabel,
    valueLabel: widget.valueLabel,
    onChanged: (int value) {
      setState(() => _value = value);
      widget.onChanged?.call(value);
    },
  );
}
