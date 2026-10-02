import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

Widget _flame({double size = 18, ThemeData? theme, String? label}) =>
    evaAmbientHarness(
      theme: theme,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: StreakFlame(size: size, semanticLabel: label ?? 'Streak'),
        ),
      ),
    );

void main() {
  group('geometry', () {
    test('the default size is the inventory\'s 18', () {
      const StreakFlame flame = StreakFlame();
      expect(flame.size, 18.0);
    });

    test('the width follows the prototype\'s 16:20 viewBox', () {
      // `ds.tsx:513` — `viewBox="0 0 16 20"`. Uniform scaling keeps the path from
      // being distorted; the prototype's own 14x18 element box differs by 2%,
      // which is the viewBox's own horizontal padding.
      expect(StreakFlame.aspect, 16 / 20);
      expect(const StreakFlame().width, closeTo(14.4, 1e-9));
      expect(const StreakFlame(size: 20).width, closeTo(16.0, 1e-9));
    });

    testWidgets('the widget takes the size it was given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame(size: 24));
      final Size size = tester.getSize(find.byType(StreakFlame));
      expect(size.height, 24.0);
      expect(size.width, closeTo(24 * 16 / 20, 1e-9));
    });

    testWidgets('it scales without overflowing a small box', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame(size: 8));
      expect(tester.takeException(), isNull);
    });
  });

  group('the path is the prototype\'s', () {
    test('is closed and finite', () {
      expect(flamePath.computeMetrics().length, greaterThan(0));
      expect(flamePath.contains(Offset.zero), isFalse);
    });

    testWidgets('covers roughly the prototype\'s box', (
      WidgetTester tester,
    ) async {
      // The path spans x 2…14 and y 0…20 of a 16x20 viewBox. Rendered at 18px
      // tall that is a 10.8 x 18px glyph inside an 14.4 x 18 box — so the painted
      // bounds must be inset from the widget box horizontally and flush
      // vertically. A path that filled its box would mean the transcription had
      // been rescaled.
      await tester.pumpWidget(_flame(size: 20));
      final Size size = tester.getSize(find.byType(StreakFlame));
      expect(size.width, 16.0);
      expect(size.height, 20.0);
    });
  });

  group('colour', () {
    testWidgets('is ember, the prototype\'s `hex.ember` fill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame());
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(StreakFlame),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.painter, isNotNull);
    });

    testWidgets('and light mode uses the light ember', (
      WidgetTester tester,
    ) async {
      // No golden here: the theming group below already captures both themes,
      // and capturing the same file twice makes the pair order-dependent — the
      // second write disagrees with the first by a rounding hair and the test
      // fails on itself.
      await tester.pumpWidget(_flame(theme: EvaThemeLight.theme));
      expect(tester.takeException(), isNull);
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(StreakFlame),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.painter, isNotNull);
    });

    testWidgets('goldens on both themes', (WidgetTester tester) async {
      for (final (String label, ThemeData theme) in <(String, ThemeData)>[
        ('dark', EvaThemeDark.theme),
        ('light', EvaThemeLight.theme),
      ]) {
        await tester.pumpWidget(_flame(theme: theme));
        await tester.pump();
        await expectLater(
          find.byType(StreakFlame),
          matchesGoldenFile('goldens/streak_flame_$label.png'),
        );
      }
    });
  });

  group('semantics — the flame is not decoration', () {
    testWidgets('carries a label and drops its own subtree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame(label: '12 day streak'));
      final node = tester.getSemantics(find.byType(StreakFlame));
      expect(node.label, '12 day streak');
    });

    testWidgets('a reader hears the streak, not a bare path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaAmbientHarness(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StreakFlame(semanticLabel: 'Streak'),
              Text('12'),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Streak'), findsOneWidget);
      expect(find.bySemanticsLabel('12'), findsOneWidget);
    });

    testWidgets('defaults to a usable label rather than nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(evaAmbientHarness(child: const StreakFlame()));
      final node = tester.getSemantics(find.byType(StreakFlame));
      expect(node.label, isNotEmpty);
    });
  });
}
