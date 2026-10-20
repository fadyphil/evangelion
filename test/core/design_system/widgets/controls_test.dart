import 'dart:ui';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The five Tier-1 controls that share one shape: a labelled, tappable thing
/// with a §14 focus ring, a `Semantics(button: true)`, and no prototype component
/// of their own beyond a CSS block.
///
/// ## AND THE §14 ROW THAT SAID "ACTIVATABLE" AND MEANT "NAMED"
///
/// The last group in this file is the gate for §14's second row, and it exists
/// because six of the eleven interactive widgets failed it. `Semantics(…,
/// excludeSemantics: true)` is the right way to stop a screen reader saying
/// "Sign in, Sign in" — and it also drops the `InkWell`'s tap **action**, because
/// the `InkWell` is a descendant of the node doing the excluding. The outer node
/// kept `isButton` and the label and offered the reader nothing to do with them.
///
/// Every committed test passed, because every one of them used `tester.tap()`,
/// which goes through the pointer path, and the keyboard path works through
/// `ActivateIntent`. `grep -rn 'SemanticsAction|hasAction|performAction' test/`
/// returned **zero** hits: no test in the suite had ever read a semantics
/// *action*, and §14's row was only ever checked against flags and labels.
///
/// So the gate reads `SemanticsData.hasAction` — against the data, never against
/// the presence of a `Semantics` widget — over the shared
/// [kInteractiveWidgets] inventory, which `focus_ring_gate_test.dart` also uses.
/// One inventory, two §14 rows.
void main() {
  const FontSizeStepperLabels stepperLabels = FontSizeStepperLabels(
    decrease: 'Decrease font size',
    increase: 'Increase font size',
    track: 'Font size',
  );

  Finder findToggle() => find.byType(EvaToggle);
  Finder findStepper() => find.byType(FontSizeStepper);
  Finder findIconButton() => find.byType(IconActionButton);
  Finder findLink() => find.byType(TextLink);
  Finder findDivider() => find.byType(HairlineDivider);

  AnimatedContainer toggleBodyOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(EvaToggle),
          matching: find.byType(AnimatedContainer),
        ),
      );

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    double textScale = 1.0,
    Alignment alignment = Alignment.topCenter,
  }) => pumpPrimitive(
    tester,
    Align(alignment: alignment, child: child),
    theme: theme,
    textScale: textScale,
  );

  group('EvaToggle', () {
    // ## THE RESTYLE SPLIT THIS GROUP'S FIRST TEST IN TWO, AND THE REASON IS
    // ## THE ONLY INTERESTING THING ABOUT THIS WIDGET
    //
    // `redesign.html:425` draws the track at **38×20**, which is below the 44px
    // platform tap-target minimum the old 44×24 track met. So the widget now paints
    // the prototype's 38×20 inside an unchanged 44×24 hit box, and **both numbers
    // have to be asserted** — asserting the track alone would pass on a widget whose
    // hit area had shrunk with it, and asserting the box alone would pass on a
    // widget that had simply not been restyled.
    testWidgets(
      'paints 38×20 inside a 44×24 tap target, per redesign.html:425',
      (WidgetTester tester) async {
        await pumpAt(
          tester,
          EvaToggle(value: true, onChanged: (bool _) {}, labels: toggleLabels),
        );
        expect(EvaToggle.trackSize, const Size(38, 20));
        expect(EvaToggle.tapTarget, const Size(44, 24));
        expect(EvaToggle.knobSize, 16);
        expect(EvaToggle.knobInset, 2);
        // `redesign.html:428`'s `left: 20px`, and the widget's own arithmetic. Stated
        // as two separate claims on purpose — §7's "a gate that re-derives the value it
        // is checking agrees with a wrong widget whenever both are wrong the same way"
        // is exactly what a single `38 - 16 - 2 == 20` assertion would be.
        expect(EvaToggle.knobTravel, 20);
        expect(
          EvaToggle.trackSize.width - EvaToggle.knobSize - EvaToggle.knobInset,
          EvaToggle.knobTravel,
          reason: 'the travel is the leftover slack, not a third number',
        );

        // Rendered, because the whole restyle is a claim about two different boxes.
        expect(
          tester.getSize(findToggle()),
          EvaToggle.tapTarget,
          reason: 'the outer box is the tap target and did not move',
        );
        expect(
          tester.getSize(
            find.descendant(
              of: findToggle(),
              matching: find.byType(AnimatedContainer),
            ),
          ),
          EvaToggle.trackSize,
          reason: 'the painted track is the redesign\'s 38×20',
        );
      },
    );

    testWidgets('the 6px the track gave up is still tappable', (
      WidgetTester tester,
    ) async {
      // ## THE TAP-TARGET FINDING, AS A BEHAVIOUR AND NOT A COMMENT
      //
      // 3px of slack on each side and 2px above and below: 6 columns and 4 rows of
      // the 44×24 box belong to the hit area and not to the paint. A tap one pixel
      // inside the box but outside the track has to reach the switch, and a widget
      // that shrank its hit area with its track fails here and nowhere else.
      //
      // ## AND THE CORNERS HAVE **NEVER** BEEN TAPPABLE, WHICH IS WHY THESE
      // ## FOUR POINTS ARE ON THE STRAIGHT EDGES
      //
      // `EvaInk`'s `borderRadius` is `BorderRadius.circular(tapTarget.height / 2)`
      // — a stadium, because a switch is one — and the `Material` that carries it
      // clips the `InkWell`'s hit test to that shape. Measured over a 24×44 grid: the
      // hit region is the stadium, so `(1, 1)`, `(42, 1)`, `(1, 22)` and `(42, 22)`
      // are outside it.
      //
      // **That is not a regression, and it is worth saying why in this file rather
      // than only here.** The track *was* 44×24 with the same radius before this
      // restyle, so the corners were dead then too — the restyle shrinks the paint
      // and leaves the target's shape alone. A new test would fail either way; what
      // changed is that there are now six rows and columns of slack to lose, and
      // this is the assertion that they are still live.
      for (final (String edge, Offset local) in const <(String, Offset)>[
        ('left', Offset(1, 12)),
        ('right', Offset(42, 12)),
        ('top', Offset(22, 0)),
        ('bottom', Offset(22, 23)),
      ]) {
        final List<bool> seen = <bool>[];
        await pumpAt(
          tester,
          EvaToggle(value: false, onChanged: seen.add, labels: toggleLabels),
        );
        await tester.tapAt(tester.getTopLeft(findToggle()) + local);
        await tester.pump();
        expect(
          seen,
          <bool>[true],
          reason:
              '$edge at ($local) is inside the 44×24 target and outside the 38×20 '
              'track. This is the whole reason the widget has two boxes.',
        );
      }

      // And the shape that costs something, pinned so a later restyle that widens
      // the track back out cannot quietly shrink the target's *shape* as well.
      final List<bool> seen = <bool>[];
      await pumpAt(
        tester,
        EvaToggle(value: false, onChanged: seen.add, labels: toggleLabels),
      );
      await tester.tapAt(tester.getTopLeft(findToggle()) + const Offset(1, 1));
      await tester.pump();
      expect(
        seen,
        isEmpty,
        reason:
            'a switch is a stadium, so the corner of its bounding box is not part '
            'of it. Pre-existing, and unchanged by this restyle.',
      );
    });

    testWidgets('on is a 30% ember tint with a 10px glow, per :427-428', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        EvaToggle(value: true, onChanged: (bool _) {}, labels: toggleLabels),
      );
      final BoxDecoration on = toggleBodyOf(tester).decoration as BoxDecoration;
      expect(on.color, const EvaColors.dark().ember.withValues(alpha: 0.3));
      expect(on.boxShadow, isNotEmpty);
      expect(on.boxShadow!.single.blurRadius, 10);
      expect(
        on.boxShadow!.single.color,
        const EvaColors.dark().ember.withValues(alpha: 0.8),
      );
    });

    testWidgets('off is the same 12% track and no glow at all', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        EvaToggle(value: false, onChanged: (bool _) {}, labels: toggleLabels),
      );
      final BoxDecoration off =
          toggleBodyOf(tester).decoration as BoxDecoration;
      // `redesign.html:425`'s `rgba(255,255,255,.12)`, and the off arm did not move
      // in this restyle — only the on arm did.
      expect(off.color, const EvaColors.dark().ink.withValues(alpha: 0.12));
      expect(off.boxShadow, isEmpty);
    });

    testWidgets('the knob is white in both states and both themes', (
      WidgetTester tester,
    ) async {
      // ## A RECORDED DIVERGENCE FROM `redesign.html:426` AND `:428`, PINNED
      //
      // The prototype's knob is `--ink-2` off and `--gold` on. This widget's is
      // white in all four combinations, and the class doc argues why. Pinning it
      // here means the divergence is a **decision under test** rather than a comment
      // a later phase can quietly reverse by editing a colour — and it is also what
      // keeps `no_colour_literals_test.dart`'s one-literal exemption for this file
      // load-bearing.
      for (final (String theme, ThemeData data) in kEvaThemes) {
        for (final bool on in <bool>[false, true]) {
          await pumpAt(
            tester,
            EvaToggle(value: on, onChanged: (bool _) {}, labels: toggleLabels),
            theme: data,
          );
          final Container knob = tester.widget<Container>(
            find
                .descendant(of: findToggle(), matching: find.byType(Container))
                .last,
          );
          expect(
            (knob.decoration! as BoxDecoration).color,
            EvaToggleKnob.color,
            reason: '$theme, ${on ? "on" : "off"} — see `EvaToggleKnob`',
          );
        }
      }
    });

    testWidgets('is a switch in the semantics tree, not a button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        EvaToggle(value: true, onChanged: (bool _) {}, labels: toggleLabels),
      );
      handle.dispose();

      final node = semanticsOf(tester, findToggle());
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isTrue);
      expect(node.label, 'On');
    });

    testWidgets('says Off when off — the state is not colour-only', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        EvaToggle(value: false, onChanged: (bool _) {}, labels: toggleLabels),
      );
      handle.dispose();

      final node = semanticsOf(tester, findToggle());
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isFalse);
      expect(node.label, 'Off');
    });

    testWidgets('tapping reports the opposite value', (
      WidgetTester tester,
    ) async {
      final List<bool> seen = <bool>[];
      await pumpAt(
        tester,
        EvaToggle(value: true, onChanged: seen.add, labels: toggleLabels),
      );
      await tester.tap(findToggle());
      await tester.pump();
      expect(seen, <bool>[false]);
    });

    testWidgets('the knob moves, so the state survives greyscale', (
      WidgetTester tester,
    ) async {
      Future<Alignment> knobAt({required bool on}) async {
        await pumpAt(
          tester,
          EvaToggle(value: on, onChanged: (bool _) {}, labels: toggleLabels),
        );
        await tester.pump();
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: findToggle(),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .alignment
            as Alignment;
      }

      expect(await knobAt(on: false), Alignment.centerLeft);
      expect(await knobAt(on: true), Alignment.centerRight);
    });

    testWidgets('the knob slides over EvaMotion.screen on a spring', (
      WidgetTester tester,
    ) async {
      // `redesign.html:425`'s `.25s` is [EvaMotion.screen]'s 250ms, and `:426`'s
      // `var(--e-spring)` is the curve — so both halves of the transition are
      // asserted, and the curve is the prototype's own bezier rather than whichever
      // curve was nearest to hand.
      await pumpAt(
        tester,
        EvaToggle(value: false, onChanged: (bool _) {}, labels: toggleLabels),
      );
      expect(toggleBodyOf(tester).duration, EvaMotion.screen);
      expect(EvaMotion.screen, const Duration(milliseconds: 250));
      expect(toggleBodyOf(tester).curve, EvaToggle.knobCurve);
      expect(EvaToggle.knobCurve, const Cubic(0.34, 1.56, 0.64, 1));
    });

    testWidgets('§14 — with animations off the knob lands in one frame', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: _LiveToggle(initial: false),
        ),
        disableAnimations: true,
      );
      // The end state is the knob on the right, so a single `pump()` after the
      // tap must already show it — not after `base`.
      expect(toggleBodyOf(tester).duration, Duration.zero);
      await tester.tap(findToggle());
      await tester.pump();
      expect(toggleBodyOf(tester).alignment, Alignment.centerRight);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          EvaToggle(value: true, onChanged: (bool _) {}, labels: toggleLabels),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findToggle(),
          matchesGoldenFile('goldens/eva_toggle_$theme.png'),
        );
      });
    }

    testWidgets('state golden — off', (WidgetTester tester) async {
      await pumpAt(
        tester,
        EvaToggle(value: false, onChanged: (bool _) {}, labels: toggleLabels),
      );
      await tester.pump();
      await expectLater(
        findToggle(),
        matchesGoldenFile('goldens/eva_toggle_state_off.png'),
      );
    });

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await pumpAt(
        tester,
        EvaToggle(value: true, onChanged: (bool _) {}, labels: toggleLabels),
      );
      await tabUntilFocused(tester, findToggle());
      await tester.pump();
      await expectLater(
        findToggle(),
        matchesGoldenFile('goldens/eva_toggle_state_focused.png'),
      );
    });
  });

  group('FontSizeStepper', () {
    testWidgets('the two buttons carry their own accessible names', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 3, onChanged: (int _) {}),
      );
      handle.dispose();

      expect(find.bySemanticsLabel('Decrease font size'), findsOneWidget);
      expect(find.bySemanticsLabel('Increase font size'), findsOneWidget);
      expect(findIconButton(), findsNWidgets(2));
    });

    testWidgets('the track is announced as a slider with its step', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 4, onChanged: (int _) {}),
      );
      handle.dispose();

      final node = semanticsOf(tester, find.bySemanticsLabel('Font size'));
      expect(node.label, 'Font size');
      expect(node.value, '4');
      expect(node.increasedValue, '5');
      expect(node.decreasedValue, '3');
    });

    testWidgets('the buttons clamp rather than run off the end', (
      WidgetTester tester,
    ) async {
      final List<int> seen = <int>[];
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 1, onChanged: seen.add),
      );
      await tester.tap(find.bySemanticsLabel('Decrease font size'));
      await tester.pump();
      expect(seen, isEmpty, reason: 'step 1 is already the floor');

      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 5, onChanged: seen.add),
      );
      await tester.tap(find.bySemanticsLabel('Increase font size'));
      await tester.pump();
      expect(seen, isEmpty, reason: 'step 5 is already the ceiling');
    });

    testWidgets('a corrupt stored step renders as the nearest real one', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 99, onChanged: (int _) {}),
      );
      expect(
        semanticsOf(tester, find.bySemanticsLabel('Font size')).value,
        '5',
        reason: 'clamped for display, not for storage',
      );
    });

    testWidgets('the track is 80 wide, the prototype\'s own value', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 3, onChanged: (int _) {}),
      );
      expect(FontSizeStepper.trackWidth, 80);
      expect(
        FontSizeStepper.trackWidth,
        lessThan(120),
        reason:
            'kept against `redesign.html:429`\'s `width:120px`, which belongs to '
            'the redesign\'s own 16–26 slider — see the widget doc',
      );
    });

    testWidgets('is NOT a Material Slider — which is why 4px and 20px are gone', (
      WidgetTester tester,
    ) async {
      // The question the restyle had to answer *first*: is this a `Slider` whose
      // track height and thumb radius get overridden, or a hand-built track? The
      // second — and the difference is not cosmetic. `Slider`'s own geometry is a
      // 4px track and a 20px thumb with an overlay ring, and **none** of those three
      // numbers is the redesign's. A widget that had become a `Slider` and been
      // overridden would look identical in a golden and carry three dead overrides.
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 3, onChanged: (int _) {}),
      );
      expect(
        find.byType(Slider),
        findsNothing,
        reason:
            'a `Slider` would bring its own 4px track and 20px thumb, and this '
            "widget's track is the prototype's 3px rule with a 15px thumb",
      );
    });

    testWidgets('the rule is 3px of 14% ink and the thumb a 15px gold disc', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 3, onChanged: (int _) {}),
      );
      final Finder parts = find.descendant(
        of: findStepper(),
        matching: find.byType(Container),
      );
      final List<Container> boxes = tester
          .widgetList<Container>(parts)
          .toList();

      // Exactly two: the rule and the thumb. The third container this widget used to
      // build was the superseded prototype's `accentColor: ember` fill, and
      // `redesign.html:429` has no such element — a CSS range input is one uniform
      // rule with one gold thumb on it. A count and not a `findsOne`, because "the
      // fill is gone" is a claim about how many things get drawn.
      expect(
        boxes,
        hasLength(2),
        reason: 'the rule and the thumb — the ember fill is deliberately gone',
      );

      final BoxDecoration rule = boxes.first.decoration! as BoxDecoration;
      expect(FontSizeStepper.trackHeight, 3);
      expect(
        rule.color,
        const EvaColors.dark().ink.withValues(alpha: 0.14),
        reason: '`redesign.html:429` — `background: rgba(255,255,255,.14)`',
      );

      final BoxDecoration thumb = boxes.last.decoration! as BoxDecoration;
      expect(FontSizeStepper.thumbSize, 15);
      expect(thumb.color, const EvaColors.dark().ember);
      expect(thumb.boxShadow!.single.blurRadius, 10);
      expect(
        thumb.boxShadow!.single.color,
        const EvaColors.dark().ember.withValues(alpha: 0.7),
        reason:
            '`redesign.html:430` — `box-shadow: 0 0 10px rgba(232,176,75,.7)`',
      );
      expect(
        tester.getSize(parts.last),
        const Size.square(15),
        reason: 'the redesign\'s thumb, rendered',
      );
    });

    testWidgets('the range stays 1…5 even though the redesign\'s is 16…26', (
      WidgetTester tester,
    ) async {
      // `redesign.html:693` is `<input type="range" min="16" max="26">` — a
      // *different control*, sized for a 120px rule on a row with no `A` letters and
      // no steppers. This widget's five steps are `evaScalerFor`'s table, so adopting
      // either number would break the mapping the thumb's position reports. Recorded
      // as a divergence in the widget doc; pinned here so it cannot be re-decided by
      // editing either constant.
      expect(kFontStepMin, 1);
      expect(kFontStepMax, 5);
      expect(clampFontStep(16), 5);
      expect(clampFontStep(0), 1);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          FontSizeStepper(
            labels: stepperLabels,
            step: 3,
            onChanged: (int _) {},
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findStepper(),
          matchesGoldenFile('goldens/font_size_stepper_$theme.png'),
        );
      });
    }
  });

  group('IconActionButton', () {
    testWidgets('§14 — the tooltip is the accessible name, not a second one', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,

          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _noop,
        ),
      );
      handle.dispose();

      // Found **by label**, not by type: `IconActionButton` nests its own
      // `Semantics` inside a `Tooltip`, which contributes a node of its own, and
      // resolving the type would read whichever of the two happens to be nearest
      // the element rather than the one the widget annotates.
      final node = semanticsOf(tester, find.bySemanticsLabel('Back'));
      expect(node.label, 'Back');
      expect(find.byTooltip('Back'), findsOneWidget);
      // One string, one source: the doc's reason for a required `tooltip` rather
      // than `tooltip` + `semanticLabel`.
      expect(node.label, tester.widget<Tooltip>(find.byType(Tooltip)).message);
    });

    testWidgets('is a square 44, which is also the iOS tap-target minimum', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,

          icon: Icons.close,
          tooltip: 'Close',
          onPressed: _noop,
        ),
      );
      final Size size = tester.getSize(findIconButton());
      expect(size, const Size.square(44));
    });

    testWidgets('the pill is 30 INSIDE the same 44, per redesign.html:151', (
      WidgetTester tester,
    ) async {
      // ## THE NUMBER TWO HARNESSES READ, AND THE ONE THIS RESTYLE HAD TO NOT MOVE
      //
      // `quiz_geometry_test.dart:146` asserts the rendered width is 44 ±0.5 and
      // `reading_geometry_test.dart:955` reads `.first`'s `getTopLeft().dy`. The
      // redesign's `.iconbtn` is 30px, and resizing to it would satisfy the CSS and
      // break both — so the 30 is a silhouette and the 44 is the control. Asserted
      // here as well as there, because this is the file that owns the widget and the
      // other two are blast radius.
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,
          icon: Icons.bookmark,
          tooltip: 'Bookmark',
          onPressed: _noop,
          pilled: true,
        ),
      );
      expect(
        tester.getSize(findIconButton()),
        const Size.square(44),
        reason: 'the tap target is 44 in both roles',
      );
      expect(IconActionButton.pillSize, 30);
      expect(
        tester.getSize(find.byType(AnimatedContainer)),
        const Size.square(30),
        reason: '`redesign.html:151` — `width: 30px, height: 30px`, centred',
      );
      expect(
        tester.getCenter(find.byType(AnimatedContainer)),
        tester.getCenter(findIconButton()),
        reason:
            'centred, not offset — a 30px pill pinned to a corner reads as a '
            'different control from the one the CSS describes',
      );
    });

    testWidgets('the bare half paints no rim at all — redesign.html:149', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,

          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _noop,
        ),
      );
      // Read off the **rendered** tree rather than off a parameter, because the
      // claim is about paint and §7's rule is that a gate re-deriving the value it
      // checks agrees with a wrong widget whenever both are wrong the same way.
      expect(
        renderedBorders(tester, findIconButton()),
        isEmpty,
        reason:
            '`.chev` is `background: none; border: none`. The pill below is the one '
            'that has a rim, and it is a separate variant on purpose.',
      );
    });

    testWidgets('the pill wears a 1px glass rim, and `lit` turns it gold', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,
          icon: Icons.bookmark,
          tooltip: 'Bookmark',
          onPressed: _noop,
          pilled: true,
        ),
      );
      expect(IconActionButton.pillRimWidth, 1);
      expect(
        renderedBorders(tester, find.byType(AnimatedContainer)),
        contains(Border.all(color: const EvaColors.dark().glassBorder)),
        reason: '`redesign.html:151` — `border: 1px solid var(--glass-line)`',
      );
      expect(_pillIconInk(tester), const EvaColors.dark().ink2);

      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,
          icon: Icons.bookmark,
          tooltip: 'Bookmark',
          onPressed: _noop,
          pilled: true,
          lit: true,
        ),
      );
      // ## `pumpAndSettle` AND NOT `pump`, AND THE REASON IS THE ANIMATION ITSELF
      //
      // The pill is an `AnimatedContainer`, so re-pumping the *same* element with a
      // new decoration does not paint the new one: the first frame after `pumpAt` is
      // still at `t == 0`, i.e. the rim the previous variant had. Without this line
      // the assertion below passes on the idle rim's alpha and fails for a reason
      // that reads like a colour bug.
      await tester.pumpAndSettle();
      expect(
        renderedBorders(tester, find.byType(AnimatedContainer)),
        contains(
          Border.all(
            color: const EvaColors.dark().ember.withValues(alpha: 0.6),
          ),
        ),
        reason: '`redesign.html:154` — `border-color: rgba(232,176,75,.6)`',
      );
      expect(
        _pillIconInk(tester),
        const EvaColors.dark().emberInk,
        reason:
            'an icon is writing, and decision 153\'s rule is that `ember` fills and '
            '`emberInk` writes — light `ember` measures 2.05:1 on a pale row',
      );
      final BoxDecoration lit =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(lit.boxShadow!.single.blurRadius, 12);
      expect(
        lit.boxShadow!.single.color,
        const EvaColors.dark().ember.withValues(alpha: 0.35),
        reason:
            '`redesign.html:154` — `box-shadow: 0 0 12px rgba(232,176,75,.35)`',
      );
      expect(lit.color, isNull, reason: '`.iconbtn` is `background: none`');
    });

    testWidgets('`lit` without `pilled` is refused at the call site', (
      WidgetTester tester,
    ) async {
      // `.chev` has no lit state — `.iconbtn.lit` is one rule on the pill, and a
      // "gold bare glyph with no rim" is a third design the prototype never drew. The
      // constructor's assert says so where a caller will see it.
      expect(
        () => IconActionButton(
          icon: Icons.bookmark,
          tooltip: 'Bookmark',
          tooltipFamily: EvaTypography.uiFamily,
          lit: true,
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'hover turns the pill gold and the bare glyph to ink — :150, :152',
      (WidgetTester tester) async {
        // ## ONE POINTER FOR ALL THREE VARIANTS, MOVED RATHER THAN RE-ADDED
        //
        // The first draft called `mouse.addPointer` three times on one
        // `TestGesture`, which trips a framework assertion
        // (`MouseTracker._shouldMarkStateDirty`: a `PointerAddedEvent` must follow
        // a `PointerRemovedEvent`) — a red that reads like a widget defect and is
        // one test's lifecycle bug instead. A hover test is a *movement*, so the
        // honest arrangement is one pointer parked off the control, the variant
        // pumped, and the pointer moved onto it.
        final TestGesture mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);

        await pumpAt(
          tester,
          const IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,
            icon: Icons.bookmark,
            tooltip: 'Bookmark',
            onPressed: _noop,
            pilled: true,
          ),
        );
        await mouse.moveTo(tester.getCenter(findIconButton()));
        await tester.pumpAndSettle();
        expect(
          renderedBorders(tester, find.byType(AnimatedContainer)),
          contains(
            Border.all(
              color: const EvaColors.dark().ember.withValues(alpha: 0.5),
            ),
          ),
          reason: '`redesign.html:152` — `border-color: rgba(232,176,75,.5)`',
        );
        expect(_pillIconInk(tester), const EvaColors.dark().emberInk);

        // `.iconbtn.lit` (:154) is declared after `.iconbtn:hover` (:152) and both
        // selectors are equally specific, so a hovered lit pill stays lit. That is the
        // CSS cascade, so it is asserted rather than assumed.
        await mouse.moveTo(Offset.zero);
        await pumpAt(
          tester,
          const IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,
            icon: Icons.bookmark,
            tooltip: 'Bookmark',
            onPressed: _noop,
            pilled: true,
            lit: true,
          ),
        );
        await mouse.moveTo(tester.getCenter(findIconButton()));
        await tester.pumpAndSettle();
        expect(
          renderedBorders(
            tester,
            find.byType(AnimatedContainer, skipOffstage: false),
          ),
          contains(
            Border.all(
              color: const EvaColors.dark().ember.withValues(alpha: 0.6),
            ),
          ),
          reason:
              'lit (60%) beats hover (50%), because `:154` is the later rule',
        );

        // And the bare half's own hover rule: `--ink-1` becomes `--ink-0`, with no rim.
        await mouse.moveTo(Offset.zero);
        await pumpAt(
          tester,
          const IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,

            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: _noop,
          ),
        );
        await mouse.moveTo(tester.getCenter(findIconButton()));
        await tester.pumpAndSettle();
        expect(
          _pillIconInk(tester),
          const EvaColors.dark().ink,
          reason: '`redesign.html:150` — `.chev:hover{color: var(--ink-0)}`',
        );
        expect(renderedBorders(tester, findIconButton()), isEmpty);
      },
    );

    testWidgets('a pressed pill scales 0.9 by paint alone — redesign.html:153', (
      WidgetTester tester,
    ) async {
      // `.iconbtn:active{transform: scale(.9)}` is a **paint** transform. If it were
      // a layout change, `quiz_geometry_test.dart`'s 44 ±0.5 would fail on a press and
      // `reading_geometry_test.dart`'s row would jump under a reader's finger. So the
      // two are asserted apart: the pill's laid-out size is 30 whatever the pointer
      // is doing, and its painted corner is 1.5px further in.
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,
          icon: Icons.bookmark,
          tooltip: 'Bookmark',
          onPressed: _noop,
          pilled: true,
        ),
      );
      final Finder pill = find.byType(AnimatedContainer);
      final double restingDx = tester.getTopLeft(pill).dx;
      expect(tester.getSize(pill), const Size.square(30));

      final TestGesture finger = await tester.startGesture(
        tester.getCenter(findIconButton()),
      );
      // `pumpAndSettle` is the first draft and it leaves `scale` at 1.0 here.
      // `pump(200)` once is not enough either, for a different reason: the
      // `Transform.scale` that `AnimatedScale` builds reaches the render tree one
      // frame *after* the widget's own `scale` property reads 0.9, because both
      // happen in the frame the animation ticks in. Measured — `getTopLeft(pill).dx`
      // is unchanged after one 200ms pump and exactly 1.5 further in after a second.
      //
      // So the sequence is: build (arm), run the 200ms, run it again (the frame the
      // tree catches up in). Each pump names which of those it is.
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
        reason: 'the rebuild that arms the animation paints at t = 0',
      );
      await tester.pump(EvaMotion.base);
      await tester.pump(EvaMotion.base);

      expect(IconActionButton.pressedScale, 0.9);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.9,
        reason: '`redesign.html:153` — `.iconbtn:active{transform:scale(.9)}`',
      );

      // **Layout**, asserted on the two boxes the harnesses read. A press must move
      // neither: `quiz_geometry_test.dart:146` reads 44 ±0.5 and
      // `reading_geometry_test.dart:955` reads `.first`'s `getTopLeft().dy`.
      expect(tester.getSize(pill), const Size.square(30), reason: 'the pill');
      expect(
        tester.getSize(findIconButton()),
        const Size.square(44),
        reason: 'and the control two harnesses measure',
      );

      // **Paint** — `getTopLeft` goes through `localToGlobal`, which applies the
      // transform, so the painted corner is (30 × (1 − 0.9)) ÷ 2 further in.
      expect(
        tester.getTopLeft(pill).dx - restingDx,
        moreOrLessEquals(1.5, epsilon: 0.01),
      );

      await finger.up();
      await tester.pump();
      await tester.pump(EvaMotion.base);
      await tester.pump(EvaMotion.base);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
        reason: 'and it returns on release, not on a timer',
      );
      expect(
        tester.getTopLeft(pill).dx,
        moreOrLessEquals(restingDx, epsilon: 0.01),
      );
    });

    testWidgets('§14 — both pill animations answer to reduced motion', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,
            icon: Icons.bookmark,
            tooltip: 'Bookmark',
            onPressed: _noop,
            pilled: true,
          ),
        ),
        disableAnimations: true,
      );
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        Duration.zero,
      );
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
    });

    testWidgets('a disabled one is not enabled and takes no tap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,
          icon: Icons.close,
          tooltip: 'Close',
        ),
      );
      handle.dispose();

      expect(
        semanticsOf(
          tester,
          find.bySemanticsLabel('Close'),
        ).flagsCollection.isEnabled.toBoolOrNull(),
        isFalse,
      );
      await tester.tap(findIconButton());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,

            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: _noop,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findIconButton(),
          matchesGoldenFile('goldens/icon_action_button_$theme.png'),
        );
      });

      // ## TWO MORE PAIRS, BECAUSE THE RESTYLE ADDED TWO ROLES
      //
      // A golden of the bare `.chev` cannot show the pill's rim or the lit glow, and
      // a golden per *variant* rather than per widget is the only way a reviewer sees
      // "is the pill 30, and is the lit rim gold at 60%" without reading the code.
      // Both pairs are also `golden_pairs_test.dart`'s subject: a `_dark`/`_light`
      // pair that is byte-identical cannot detect a theming regression, and these two
      // are the pairs where the *palette* is the whole claim (`glassBorder`,
      // `emberInk`, `ember` all differ between the two palettes).
      testWidgets('pilled golden — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,
            icon: Icons.bookmark,
            tooltip: 'Bookmark',
            onPressed: _noop,
            pilled: true,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findIconButton(),
          matchesGoldenFile('goldens/icon_action_button_pilled_$theme.png'),
        );
      });

      testWidgets('lit golden — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const IconActionButton(
            tooltipFamily: EvaTypography.uiFamily,
            icon: Icons.bookmark,
            tooltip: 'Bookmark',
            onPressed: _noop,
            pilled: true,
            lit: true,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findIconButton(),
          matchesGoldenFile('goldens/icon_action_button_lit_$theme.png'),
        );
      });
    }

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,

          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _noop,
        ),
      );
      await tabUntilFocused(tester, findIconButton());
      await tester.pump();
      await expectLater(
        findIconButton(),
        matchesGoldenFile('goldens/icon_action_button_state_focused.png'),
      );
    });
  });

  group('TextLink', () {
    testWidgets('is a named button, and tapping it reports', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        TextLink(label: 'Create account', onPressed: () => taps++),
      );
      handle.dispose();

      final node = semanticsOf(tester, findLink());
      expect(node.label, 'Create account');
      expect(node.flagsCollection.isButton, isTrue);

      await tester.tap(findLink());
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the chevron is opt-in, as on Login\'s Create account', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const TextLink(label: 'Create account', onPressed: _noop),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await pumpAt(
        tester,
        const TextLink(
          label: 'Forgot password?',
          chevron: true,
          onPressed: _noop,
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets(
      'the chevron is ember, like the prototype\'s and like EvaButton\'s',
      (WidgetTester tester) async {
        // M9. One prototype glyph had two colours in one phase: the superseded
        // prototype writes `color: hex.ember` on the `›` — **the redesign has no
        // counterpart for that glyph** — `EvaButton` transcribes it as
        // `colors.ember`, and `TextLink` was reading `ink` — the link's own colour.
        // It was not among the eight declared divergences, so it was a transcription
        // error rather than a decision, and nothing asserted it: the chevron tests
        // checked `findsOneWidget` / `findsNothing` and never its paint.
        //
        // Both palettes, because a colour that is only right in one is a half-fix.
        for (final (String theme, ThemeData data) in kEvaThemes) {
          await pumpAt(
            tester,
            const TextLink(
              label: 'Forgot password?',
              chevron: true,
              onPressed: _noop,
            ),
            theme: data,
          );
          final ThemeData resolved = Theme.of(tester.element(findLink()));
          expect(
            tester.widget<Icon>(find.byIcon(Icons.chevron_right)).color,
            resolved.extension<EvaColors>()!.ember,
            reason:
                '$theme — the superseded prototype writes `hex.ember` on the `›`, '
                'and the size '
                'is already 16 to match. The link\'s *label* is a separate '
                'question, answered by the `color` parameter.',
          );
        }
      },
    );

    testWidgets('without `color` it inks `ink`, and `ember` on request', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const TextLink(label: 'Forgot password?', onPressed: _noop),
      );
      expect(
        tester.widget<Text>(find.text('Forgot password?')).style!.color,
        const EvaColors.dark().ink,
      );

      await pumpAt(
        tester,
        TextLink(
          label: 'Create account',
          color: const EvaColors.dark().ember,
          onPressed: _noop,
        ),
      );
      expect(
        tester.widget<Text>(find.text('Create account')).style!.color,
        const EvaColors.dark().ember,
      );
    });

    // ## WHY THIS GOLDEN PINS NO COLOUR
    //
    // It used to pass `color: Color(0xFFE8A33D)` — a literal, and `#E8A33D` is the
    // **dark** palette's `ember`. So the light capture was a byte-identical copy of
    // the dark one, and the file's name — "a golden per theme" — claimed a
    // theming check the pair could not possibly make. `Color(0xFFE8A33D)` is not
    // `EvaColors.dark().ember` anyway; it is a colour that bypassed the token
    // table to *imitate* one.
    //
    // With `color` dropped the widget resolves its own default, the superseded
    // prototype's `color: color ?? T.ink`, which is `EvaColors.ink` — `#EAE8F5` in
    // dark and `#120E28` in light. Now the pair differs, and the golden can fail
    // for a theming regression, which is the only thing it was ever able to check.
    //
    // What is *not* lost: the `color` parameter is still pinned, by the test above
    // ("without `color` it inks `ink`, and `ember` on request"), which is a better
    // place for it than a picture — it asserts the resolution rather than the
    // pixel. And `TextLink` ignoring `color` entirely still turns this pair red,
    // because the resolved default would no longer be what the images show.
    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const TextLink(label: 'Create account', onPressed: _noop),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findLink(),
          matchesGoldenFile('goldens/text_link_$theme.png'),
        );
      });
    }
  });

  group('HairlineDivider', () {
    testWidgets('a bare rule is 1px tall', (WidgetTester tester) async {
      await pumpAt(tester, const HairlineDivider());
      expect(tester.getSize(findDivider()).height, HairlineDivider.thickness);
      expect(HairlineDivider.thickness, 1.0);
    });

    testWidgets('a labelled one is a label between two rules', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const HairlineDivider(label: 'or'));
      expect(find.text('OR'), findsOneWidget);
      expect(
        find.descendant(of: findDivider(), matching: find.byType(Container)),
        findsNWidgets(2),
      );
    });

    testWidgets('the rule is the prototype\'s 8% ink, not the `line` token', (
      WidgetTester tester,
    ) async {
      // Recorded in the widget's doc: `line` is `#1C2238` on a `#05081A` canvas,
      // which is far fainter than the prototype's 8% white.
      await pumpAt(tester, const HairlineDivider());
      final Container rule = tester.widget<Container>(
        find
            .descendant(of: findDivider(), matching: find.byType(Container))
            .first,
      );
      expect(rule.color, const EvaColors.dark().ink.withValues(alpha: 0.08));
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(tester, const HairlineDivider(label: 'or'), theme: data);
        await tester.pump();
        await expectLater(
          findDivider(),
          matchesGoldenFile('goldens/hairline_divider_$theme.png'),
        );
      });
    }
  });

  group('§14 — every interactive widget is ACTIVATABLE, not only named', () {
    // ## WHY THIS GROUP IS A SEPARATE GATE
    //
    // `Semantics(…, excludeSemantics: true)` drops the subtree's semantics —
    // including the `InkWell`'s tap action, because the `InkWell` is a descendant
    // of the node doing the excluding. Six widgets wrapped that way: `EvaButton`,
    // `TextLink`, `EvaToggle`, `IconActionButton`, and therefore
    // `ErrorView`'s retry. Each shipped `isButton == true` and a label, and
    // `hasAction(SemanticsAction.tap) == false`: a screen reader could read the
    // control and could not press it. A TalkBack double-tap is `ACTION_CLICK`,
    // which is `SemanticsAction.tap`.
    //
    // Every committed test was green because every one of them called
    // `tester.tap()` — the pointer path, which does not consult the semantics tree
    // — and the keyboard path, which works through `ActivateIntent`. Before this
    // group, `grep -rn 'SemanticsAction|hasAction|performAction' test/` returned
    // nothing at all: no test in the suite had ever read a semantics *action*.

    for (final InteractiveWidget entry in kInteractiveWidgets) {
      testWidgets('${entry.widget} offers ${entry.activation.name}', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, entry.build());
        final List<SemanticsData> actionable = nodesOffering(
          tester,
          entry.activation,
        );

        // Matched per **line**, not as a whole string. `SettingsTile` is the one
        // widget here that deliberately keeps its subtree in the tree
        // (`excludeSemantics: false`, so the trailing control survives), which
        // means its own title `Text` merges into the node's label and the label
        // arrives as "Edit profile\nEdit profile". That duplication is a real
        // §14 first-row wrinkle and it is **not** fixed here: it is outside this
        // task's findings, and changing a shipped widget's semantics to satisfy a
        // new gate is the wrong order of operations. It is recorded rather than
        // worked around silently — and a split is enough either way, because what
        // this gate is about is whether the *action* is there.
        expect(
          actionable.any(
            (SemanticsData d) =>
                d.label.split('\n').contains(entry.tappableLabel),
          ),
          isTrue,
          reason:
              '§14 — ${entry.widget} put no ${entry.activation.name} action on a '
              'node naming "${entry.tappableLabel}". ${entry.name}. A control a '
              "reader can name but not activate is this row's whole defect. "
              'Actionable labels were: '
              '${actionable.map((SemanticsData d) => '"${d.label}"').toList()}',
        );
      });

      testWidgets('${entry.widget} names every node it can activate', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, entry.build());
        final List<SemanticsData> actionable = nodesOffering(
          tester,
          entry.activation,
        );
        expect(actionable, isNotEmpty);
        for (final SemanticsData data in actionable) {
          expect(
            data.label.trim(),
            isNotEmpty,
            reason:
                '§14 — ${entry.widget} contributed a node a reader can activate '
                'and nothing can name. ${entry.name}',
          );
        }
      });
    }

    for (final InteractiveWidget entry in kDisabledWidgets) {
      testWidgets('${entry.widget} disabled offers no action at all', (
        WidgetTester tester,
      ) async {
        // The other half, and it cannot be folded into the loop above: a control
        // announced as disabled and then *responding* is worse than one that never
        // responded, because the reader has been told a lie about the state of the
        // page. `enabled: false` is not enough — the action has to be **absent**,
        // which is why these assert `hasAction` is false rather than checking the
        // flag.
        await pumpAt(tester, entry.build());
        expect(
          nodesOffering(tester, entry.activation),
          isEmpty,
          reason:
              '§14 — ${entry.widget} is inert but still publishes a '
              '${entry.activation.name} action. ${entry.name}',
        );
      });
    }

    group('and the negative control, so this gate is known to bite', () {
      testWidgets('a node with a flag and a label but no action fails it', (
        WidgetTester tester,
      ) async {
        // The exact shape of the six defects, built by hand so the gate is seen
        // failing rather than merely believed to.
        await pumpAt(tester, const _NamelesslyActable());

        expect(
          tester
              .getSemantics(find.byType(_NamelesslyActable))
              .flagsCollection
              .isButton,
          isTrue,
          reason: 'the control does look like a button…',
        );
        expect(
          nodesOffering(tester, SemanticsAction.tap),
          isEmpty,
          reason: '…and offers nothing to press, which is what §14 forbids',
        );
      });

      testWidgets('and a labelled action passes', (WidgetTester tester) async {
        // The control, so "the assertion above failed" is not the same as
        // "the walk found nothing at all".
        await pumpAt(tester, const _ActuallyActable());
        expect(
          nodesOffering(
            tester,
            SemanticsAction.tap,
          ).map((SemanticsData d) => d.label),
          contains('Push me'),
        );
      });
    });
  });
}

/// A control that is a button, is named, and cannot be pressed.
///
/// The negative control for §14's activatable row, built to the shape of the six
/// defects it replaced: `Semantics(button: true, label: …, excludeSemantics: true)`
/// over an `InkWell`, which is exactly what drops the tap action.
class _NamelesslyActable extends StatelessWidget {
  const _NamelesslyActable();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: true,
    label: 'Push me',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () {},
      child: const SizedBox(width: 80, height: 44),
    ),
  );
}

/// The same control with the action restored.
class _ActuallyActable extends StatelessWidget {
  const _ActuallyActable();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: true,
    label: 'Push me',
    excludeSemantics: true,
    onTap: () {},
    child: GestureDetector(
      onTap: () {},
      child: const SizedBox(width: 80, height: 44),
    ),
  );
}

void _noop() {}

/// The ink an [IconActionButton]'s glyph is painted in.
///
/// Read off the `Icon` widget rather than off a parameter: `.chev` idle is `ink2`,
/// `.chev` hovered is `ink` (`:150`), `.iconbtn` idle is `ink2` (`:151`) and both
/// hover and lit are gold (`:152`, `:154`), so "which ink" is a four-way question
/// and the only honest way to ask it is from the tree that draws it.
Color _pillIconInk(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon)).color!;

/// An [EvaToggle] whose `value` follows its own `onChanged`.
///
/// `EvaToggle` is a controlled component, so a test that taps it and then asserts
/// the knob moved is asserting that the widget writes to its own input — which it
/// deliberately does not. Phase 9's `SettingsCubit` is the real stand-in.
class _LiveToggle extends StatefulWidget {
  const _LiveToggle({required this.initial});

  final bool initial;

  @override
  State<_LiveToggle> createState() => _LiveToggleState();
}

class _LiveToggleState extends State<_LiveToggle> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) => EvaToggle(
    value: _value,
    onChanged: (bool next) => setState(() => _value = next),
    labels: toggleLabels,
  );
}
