import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_segment_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// `workshop_segment_row.dart` — the one row whose layout differs.
///
/// ## WHY THE **WIDTH** IS THE SUBJECT
///
/// The row is stacked because a four-segment control cannot share a row with a
/// 14.5px label at 320px — the arithmetic is in the widget's own doc. **This file
/// is where that arithmetic is checked against the rendered result**: the control
/// must take the row's full width, or the label it was stacked for is not sharing
/// a row with anything and the whole arrangement is decoration.
void main() {
  group('`WorkshopSegmentRow`', () {
    testWidgets('the control is named the row\'s title', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final Iterable<SemanticsData> named = semanticsTree(tester)
          .where((SemanticsData data) => data.label == 'Curtain shape');
      expect(named, hasLength(1));
    });

    // ## THE LABELS ARE **UPPER-CASED** BY THE CONTROL
    //
    // `eva/redesign.html:183` — `.segp button{…text-transform:uppercase}` — and
    // Flutter has no `textTransform`, so `SegmentedControl` applies it to the
    // string it is about to render.
    testWidgets('the option labels are painted', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.text('TOP'), findsOneWidget);
      expect(find.text('SHAFTS'), findsOneWidget);
    });

    // ## AND THE CONTROL TAKES THE **ROW'S FULL WIDTH**
    //
    // `:188` — `.segp.wide{width:100%}`.
    testWidgets('the control fills the row', (WidgetTester tester) async {
      await _pump(tester);

      final double rowWidth = tester.getSize(find.byType(SettingsTile)).width;
      final double controlWidth = tester
          .getSize(find.byType(SegmentedControl<int>))
          .width;
      // The row's own horizontal padding is 4px on each side
      // (`SettingsTile.padding`, `eva/redesign.html:419`), so the control's
      // available width is the row's width less 8.
      expect(controlWidth, closeTo(rowWidth - 8, 0.5));
    });

    // ## AND THE LABEL IS **ABOVE** THE CONTROL
    //
    // The whole reason the row is stacked. `:653` puts the label beside the
    // control; the client puts it above.
    testWidgets('the label is above the control', (WidgetTester tester) async {
      await _pump(tester);

      final double labelTop = tester.getTopLeft(find.text('Curtain shape')).dy;
      final double controlTop = tester
          .getTopLeft(find.byType(SegmentedControl<int>))
          .dy;
      expect(labelTop, lessThan(controlTop));
    });

    testWidgets('tapping an option reports it', (WidgetTester tester) async {
      int? reported;
      await _pump(tester, onChanged: (int value) => reported = value);

      await tester.tap(find.text('SHAFTS'));
      await tester.pump();

      expect(reported, 3);
    });
  });
}

/// Pumps the row on a **320×568** surface — the viewport the standing matrix
/// uses, and the one the stacking arithmetic is written for.
Future<void> _pump(WidgetTester tester, {ValueChanged<int>? onChanged}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      child: WorkshopSegmentRow<int>(
        title: 'Curtain shape',
        values: const <int>[0, 1, 2, 3],
        selected: 0,
        labelOf: (int value) => switch (value) {
          0 => 'top',
          1 => 'bottom',
          2 => 'sides',
          _ => 'shafts',
        },
        onChanged: onChanged ?? _ignore,
      ),
    ),
  );
  await tester.pump();
}

/// A callback that does nothing.
void _ignore(int value) {}
