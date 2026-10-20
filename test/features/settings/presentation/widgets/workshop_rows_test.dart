import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// `workshop_rows.dart` — the four shapes a Workshop row takes.
///
/// ## WHY THE **ACCESSIBLE NAME** IS THE SUBJECT OF MOST OF THIS FILE
///
/// `SettingsTile` wraps its title in `ExcludeSemantics` (`settings_tile.dart:284`)
/// so that the trailing control's node does not repeat it. The effect is that a
/// row's title reaches **no** semantics node at all, so **the trailing control is
/// the only thing that can name the row** — and if it does not, the row is
/// anonymous to a screen reader.
///
/// The Phase-9 screen got this wrong in the shape the repository already knows:
/// its reduce-motion switch was named "On" and "Off", and a reader reaching it
/// heard "On, switch" and learned nothing about what the switch was for.
void main() {
  group('`WorkshopToggleRow`', () {
    // ## THE NAME IS THE **ROW'S TITLE** IN BOTH ARMS
    //
    // A name that changes with the switch's position is a **state** name, not a
    // **control** name, and the state is already published: `EvaToggle` sets
    // `toggled`.
    testWidgets('the switch is named the row\'s title while it is on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopToggleRow(
            title: 'Reduce motion',
            value: true,
            onChanged: _ignore,
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(tester, 'Reduce motion');
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isTrue);
    });

    testWidgets('the switch is named the row\'s title while it is off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopToggleRow(
            title: 'Reduce motion',
            value: false,
            onChanged: _ignore,
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(tester, 'Reduce motion');
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isFalse);
    });

    // ## AND THE **STATE** IS NOT LOST
    testWidgets('the node announces the state as well as the control', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopToggleRow(
            title: 'Daylight mode',
            value: true,
            onChanged: _ignore,
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(tester, 'Daylight mode');
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isTrue);
    });

    // ## AND THE ROW'S TITLE REACHES **NO OTHER NODE**
    //
    // The duplicate-name defect `settings_tile.dart:261-283` measures: a name said
    // twice, by two activatable nodes, is §14's failure. One node here.
    testWidgets('the title is named once, on the switch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopToggleRow(
            title: 'Reduce motion',
            value: true,
            onChanged: _ignore,
          ),
        ),
      );

      final List<SemanticsData> named = semanticsTree(tester)
          .where((SemanticsData data) => data.label == 'Reduce motion')
          .toList();
      expect(named, hasLength(1));
    });

    testWidgets('tapping the switch reports the other position', (
      WidgetTester tester,
    ) async {
      bool? reported;
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: WorkshopToggleRow(
            title: 'Reduce motion',
            value: true,
            onChanged: (bool value) => reported = value,
          ),
        ),
      );

      await tester.tap(find.byType(EvaToggle));
      await tester.pump();

      expect(reported, isFalse);
    });
  });

  group('`WorkshopSliderRow`', () {
    testWidgets('the slider is named the row\'s title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopSliderRow(
            title: 'Reach',
            value: 42,
            min: 18,
            max: 110,
            onChanged: _ignoreInt,
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(tester, 'Reach');
      expect(node.flagsCollection.isSlider, isTrue);
    });

    // ## THE ANNOUNCED VALUE IS THE **RAW NUMBER**
    //
    // The prototype paints no number at all (`eva/redesign.html:429-430`), so the
    // client paints none either — and the *announced* value is the raw number,
    // because the unit is the caller's and the prototype's own `secs` (`:970`) is
    // a phrase rather than a unit.
    testWidgets('the announced value is the raw number, with no unit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopSliderRow(
            title: 'Reach',
            value: 42,
            min: 18,
            max: 110,
            onChanged: _ignoreInt,
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(tester, 'Reach');
      expect(node.value, '42');
    });

    // ## AND THE **STEP** IS HONOURED
    //
    // `eva/redesign.html:684` is the prototype's only stepped slider: `step="5"`
    // on a range of 15–120. A control that offered 63 would be offering a value
    // the reader could not keep.
    testWidgets('a stepped slider only offers multiples of its step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopSliderRow(
            title: 'Selah length',
            value: 60,
            min: 15,
            max: 120,
            step: 5,
            onChanged: _ignoreInt,
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(tester, 'Selah length');
      expect(node.increasedValue, '65');
      expect(node.decreasedValue, '55');
    });

    // ## AND THE `after` WIDGET SITS **AFTER** THE SLIDER
    //
    // `eva/redesign.html:661` puts the hue swatch after the range input, and
    // `:432` gives the swatch `margin-left:8px`.
    testWidgets('the trailing widget sits after the slider, 8px away', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopSliderRow(
            title: 'Hue',
            value: 312,
            min: 0,
            max: 360,
            onChanged: _ignoreInt,
            after: SizedBox(key: Key('swatch'), width: 16, height: 16),
          ),
        ),
      );

      final Offset sliderRight = tester.getTopRight(
        find.byType(EvaRangeSlider),
      );
      final Offset swatchLeft = tester.getTopLeft(
        find.byKey(const Key('swatch')),
      );
      expect(swatchLeft.dx - sliderRight.dx, 8);
    });
  });

  group('`WorkshopValueRow`', () {
    // ## THE ROW IS **NAMED**
    //
    // The About rows have no trailing *control* to carry the name, so without a
    // name of their own they would announce "aurora.frag v8" and nothing else.
    testWidgets('the value is named by the row it belongs to', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopValueRow(
            title: 'Shaders',
            value: 'aurora.frag v8',
          ),
        ),
      );

      final SemanticsData node = _nodeLabelled(
        tester,
        'Shaders: aurora.frag v8',
      );
      expect(node.label, 'Shaders: aurora.frag v8');
    });

    testWidgets('the value is painted', (WidgetTester tester) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopValueRow(title: 'Tokens', value: 'lumen v1.2'),
        ),
      );

      expect(find.text('lumen v1.2'), findsOneWidget);
    });

    // ## AND IT IS PAINTED IN THE `.ar` STYLE
    //
    // `eva/redesign.html:421` — `color:var(--ink-1);font-family:var(--mono);
    // font-size:11px`, and **no** tracking.
    testWidgets('the value wears the `.ar` style', (WidgetTester tester) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopValueRow(title: 'Tokens', value: 'lumen v1.2'),
        ),
      );

      final TextStyle style = tester
          .widget<Text>(find.text('lumen v1.2'))
          .style!;
      expect(style.fontSize, 11);
      expect(style.letterSpacing, 0);
      expect(style.fontFamily, EvaTypography.monoFamily);
    });
  });

  group('`WorkshopRestoreRow`', () {
    // ## THE ROW IS **TAPPABLE**
    //
    // Every other `.srow` in the prototype's markup carries `cursor:default` and
    // this one does not — it is the control.
    testWidgets('the row is a button named by its title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopRestoreRow(
            title: 'Restore nocturne defaults',
            onTap: _ignoreVoid,
          ),
        ),
      );

      // The node carries the row's title **and** the arrow, on two lines — the
      // prototype's own row reads "Restore nocturne defaults ↺" (`:695`), and
      // `SettingsTile` merges the trailing into the row's node rather than
      // dropping it.
      final SemanticsData node = _nodeContaining(
        tester,
        'Restore nocturne defaults',
      );
      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('tapping the row runs the action', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: WorkshopRestoreRow(
            title: 'Restore nocturne defaults',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Restore nocturne defaults'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    // ## AND THE `↺` IS PAINTED, **NOT** DRAWN AS AN ICON
    //
    // The glyph is in no bundled mono or scripture face, and it is in `Inter` — so
    // it is painted with a `fontFamilyFallback` and the mono face draws the
    // letters around it.
    testWidgets('the arrow is painted as a glyph, with an Inter fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopRestoreRow(
            title: 'Restore nocturne defaults',
            onTap: _ignoreVoid,
          ),
        ),
      );

      final TextStyle style = tester.widget<Text>(find.text('↺')).style!;
      expect(style.fontFamily, EvaTypography.monoFamily);
      expect(style.fontFamilyFallback, contains(EvaTypography.uiFamily));
    });

    // ## AND IT IS **MIRRORED** UNDER RTL
    //
    // `eva/redesign.html:138` — `[dir=rtl] .srow .ar{…transform:scaleX(-1)}`.
    // U+21BA has no `Bidi_Mirrored` property, so no text engine mirrors it by
    // itself and the transform has to be explicit.
    testWidgets('the arrow is not mirrored under LTR', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const WorkshopRestoreRow(
            title: 'Restore nocturne defaults',
            onTap: _ignoreVoid,
          ),
        ),
      );

      expect(_arrowMirrors(tester), isEmpty);
    });

    testWidgets('the arrow is mirrored under RTL', (WidgetTester tester) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          textDirection: TextDirection.rtl,
          child: const WorkshopRestoreRow(
            title: 'Restore nocturne defaults',
            onTap: _ignoreVoid,
          ),
        ),
      );

      final List<Matrix4> mirrors = _arrowMirrors(tester);
      expect(mirrors, hasLength(1));
      expect(mirrors.single.entry(0, 0), -1.0);
      expect(mirrors.single.entry(1, 1), 1.0);
      // A mirror and nothing else: the row's own hover transform is a
      // translation, and a mirrored arrow that also slid would be a different
      // glyph.
      expect(mirrors.single.entry(3, 0), 0.0);
    });
  });
}

/// A toggle callback that does nothing.
void _ignore(bool value) {}

/// A slider callback that does nothing.
void _ignoreInt(int value) {}

/// A void callback that does nothing.
void _ignoreVoid() {}

/// The matrices of the arrow's ancestors that **mirror** the x axis.
///
/// ## WHY THEY ARE SCOPED AND WHY THEY ARE FILTERED
///
/// `SettingsTile` paints its hover with an `AnimatedContainer` and a
/// `transform: Matrix4.translationValues(...)`, and that is a [Transform] too —
/// so an unscoped `find.byType(Transform)` finds the **row's** transform and the
/// arrow's, and "the arrow is not mirrored" cannot be told from "the row is not
/// mirrored".
///
/// **And they are filtered by the sign of the x scale**, because the row's own
/// transform is a pure translation (`entry(0, 0) == 1`) and the mirror's is a
/// negative x scale. A test that counted the transforms would be counting the
/// row's hover along with the arrow's mirror; a test that reads the **scale**
/// is reading the property the prototype's rule is about.
List<Matrix4> _arrowMirrors(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.ancestor(of: find.text('\u21ba'), matching: find.byType(Transform)),
    )
    .where((Transform transform) => transform.transform.entry(0, 0) < 0)
    .map((Transform transform) => transform.transform)
    .toList();

/// The semantics node whose label **contains** [fragment].
///
/// For a row whose trailing control is a *text* rather than a control: the
/// trailing merges into the row's node, so the node's label is the title and the
/// trailing on two lines — which is what the prototype's own row reads.
SemanticsData _nodeContaining(WidgetTester tester, String fragment) {
  final List<SemanticsData> matches = semanticsTree(tester)
      .where((SemanticsData data) => data.label.contains(fragment))
      .toList();
  expect(
    matches,
    hasLength(1),
    reason: 'expected exactly one node whose label contains "$fragment"',
  );
  return matches.single;
}

/// The semantics node whose label is exactly [label].
///
/// ## WHY A WALK AND NOT `tester.getSemantics(find.byType(…))`
///
/// `getSemantics` returns the node nearest the finder, walking **up** to the
/// closest semantics boundary — and for `EvaToggle` and `EvaRangeSlider` that
/// boundary is the widget's own `Semantics`, so the call would work. The walk is
/// used anyway because it is the only way to assert that a label appears
/// **once**: `getSemantics` cannot answer "how many nodes carry this name", and
/// the duplicate-name defect is exactly that question.
SemanticsData _nodeLabelled(WidgetTester tester, String label) {
  final List<SemanticsData> matches = semanticsTree(tester)
      .where((SemanticsData data) => data.label == label)
      .toList();
  expect(
    matches,
    hasLength(1),
    reason: 'expected exactly one node labelled "$label"',
  );
  return matches.single;
}
