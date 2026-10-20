import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// `SettingsTile`'s **stacked** mode — the three segmented rows of the
/// Workshop, where the control goes below the label.
///
/// Widget work, so TDD-exempt (AGENT_CONTEXT §6) — but the numbers it asserts
/// are the ones two other harnesses read (`primitives_text_scale_test.dart`
/// reads `minHeight` and `renderedFloor`), so they are asserted here as well.
void main() {
  Finder row() => find.byType(SettingsTile);

  /// The trailing control, keyed so the finder cannot confuse it with the
  /// row's own 12px gap — which is also a `SizedBox`.
  const Key trailingKey = Key('settings-tile-trailing');

  /// A trailing that wants the row's whole width — the wide segmented
  /// control's shape.
  ///
  /// **The 40px width is the default row's**; in a stacked row the column's
  /// `stretch` hands the child a **tight** width, and a tight width wins over
  /// the `SizedBox`'s own — so the same widget is 40px beside the label and
  /// the row's full width below it.
  ///
  /// The gold fill is so the golden shows **where** the control is; a bare
  /// `SizedBox` paints nothing and the golden would be a label and a rule.
  Widget control() => SizedBox(
    key: trailingKey,
    width: 40,
    height: 20,
    child: DecoratedBox(
      decoration: BoxDecoration(color: const EvaColors.dark().ember),
    ),
  );

  Finder controlFinder() => find.byKey(trailingKey);

  Future<void> pumpAt(
    WidgetTester tester, {
    bool stacked = false,
    Widget? trailing,
    ThemeData? theme,
  }) => pumpPrimitive(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 264,
        child: SettingsTile(
          title: 'Curtain shape',
          trailing: trailing ?? control(),
          stacked: stacked,
        ),
      ),
    ),
    theme: theme,
  );

  group('the stacked mode', () {
    testWidgets('the title is ABOVE the control, not beside it', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, stacked: true);
      final Offset title = tester.getTopLeft(find.text('Curtain shape'));
      final Rect control = tester.getRect(controlFinder());
      expect(
        title.dy,
        lessThan(control.top),
        reason: 'the control is BELOW the label',
      );
    });

    testWidgets('the control is laid out at the row\'s FULL width', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, stacked: true);
      final Rect control = tester.getRect(controlFinder());
      // The row is 264 wide and its own horizontal padding is 4px a side, so
      // the content is 256.
      expect(control.width, 256);
      expect(
        control.left,
        tester.getTopLeft(find.text('Curtain shape')).dx,
        reason:
            'the control starts at the label\'s left edge — the column '
            'stretches',
      );
    });

    testWidgets('the default row still puts the control BESIDE the label', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester);
      final Offset title = tester.getTopLeft(find.text('Curtain shape'));
      final Rect control = tester.getRect(controlFinder());
      expect(
        control.left,
        greaterThan(title.dx),
        reason: 'the default row is unchanged — the stacked mode is opt-in',
      );
      expect(
        control.top,
        moreOrLessEquals(title.dy, epsilon: 24),
        reason: 'and they are on the same line',
      );
    });

    testWidgets('it changes the AXIS and nothing else', (
      WidgetTester tester,
    ) async {
      // ## WHY EVERY ONE OF THESE IS ASSERTED HERE
      //
      // `primitives_text_scale_test.dart` reads `minHeight` and
      // `renderedFloor`, and the hairline is what makes the rendered floor 57
      // rather than 56. A stacked row that quietly changed any of them would
      // move a number two other harnesses depend on, and the only thing
      // standing between that and a silent regression is an assertion.
      expect(SettingsTile.minHeight, 56.0);
      expect(SettingsTile.contentFloor, 26.0);
      expect(SettingsTile.renderedFloor, 57.0);
      expect(SettingsTile.titleSize, 14.5);
      expect(SettingsTile.hairlineAlpha, 0.06);

      await pumpAt(tester, stacked: true);
      // The row's own decoration, read off the `AnimatedContainer` — a
      // `DecoratedBox` finder would also find the trailing's, and the row's
      // is the one that carries the hairline.
      final AnimatedContainer container = tester.widget<AnimatedContainer>(
        find
            .descendant(of: row(), matching: find.byType(AnimatedContainer))
            .first,
      );
      final BoxDecoration box = container.decoration! as BoxDecoration;
      final Border border = box.border! as Border;
      expect(border.bottom.width, 1.0, reason: 'the hairline survives');
      expect(
        border.bottom.color,
        const EvaColors.dark().ink.withValues(
          alpha: SettingsTile.hairlineAlpha,
        ),
      );
      expect(border.top, BorderSide.none);
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
    });

    testWidgets('the title is still the title — 14.5px in the UI face', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, stacked: true);
      final TextStyle style = tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .descendant(
                  of: row(),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(style.fontSize, 14.5);
      expect(style.fontFamily, EvaTypography.uiFamily);
    });

    testWidgets('a stacked row is still at least the rendered floor tall', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, stacked: true);
      expect(
        tester.getSize(row()).height,
        greaterThanOrEqualTo(SettingsTile.renderedFloor),
      );
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(tester, stacked: true, theme: data);
        await tester.pump();
        await expectLater(
          row(),
          matchesGoldenFile('goldens/settings_tile_stacked_$theme.png'),
        );
      });
    }
  });
}
