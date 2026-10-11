import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// Widget behaviour, semantics and goldens for [ProgressBeads] and
/// [EvaTextField] — the two whose TDD-able logic already has its own group in
/// `progress_beads_test.dart` / `eva_text_field_test.dart`.
///
/// The filename keeps "chip" from when this file also covered [EvaChip]. That
/// widget was deleted: its only two call sites in the prototype were the passage
/// library, cut by AGENT_CONTEXT section 2 decision 1, and the other three pill
/// styles were marked "do not port" by defect #12. The name is left alone rather
/// than renamed, because the remaining content is unchanged.
void main() {
  Finder findBeads() => find.byType(ProgressBeads);
  Finder findField() => find.byType(EvaTextField);

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    double textScale = 1.0,
    bool disableAnimations = false,
  }) => pumpPrimitive(
    tester,
    Align(alignment: Alignment.topCenter, child: child),
    theme: theme,
    textScale: textScale,
    disableAnimations: disableAnimations,
  );

  group('ProgressBeads — behaviour', () {
    testWidgets('it renders one bead per total, in a row', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 1, current: 1),
      );
      expect(findBeads(), findsOneWidget);
      // Each bead is a Container; the row's own padding Containers would inflate
      // the count, so the assertion is on the beads' shared size instead.
      expect(kProgressBeadSize, 10);
      expect(kProgressBeadGap, 8);
    });

    testWidgets('a filled bead, a ringed current bead and an empty one', (
      WidgetTester tester,
    ) async {
      Future<Border> borderAt(int index) async {
        final Container bead = tester.widget<Container>(
          find
              .descendant(of: findBeads(), matching: find.byType(Container))
              .at(index),
        );
        return (bead.decoration! as BoxDecoration).border! as Border;
      }

      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 1, current: 1),
      );
      const EvaColors colors = EvaColors.dark();
      // ds.tsx:362-363 — done is a filled ember with no rim; current is a 2px
      // ember ring; upcoming is a 1.5px ink-at-20% ring.
      expect((await borderAt(0)).top.color, colors.ember);
      expect((await borderAt(1)).top.width, 2);
      expect((await borderAt(4)).top.width, 1.5);
      expect((await borderAt(4)).top.color, colors.ink.withValues(alpha: 0.20));
    });

    testWidgets('a total of zero renders nothing at all', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const ProgressBeads(total: 0, completed: 0, current: 0),
      );
      expect(findBeads(), findsOneWidget);
      expect(
        find.descendant(of: findBeads(), matching: find.byType(Container)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('§14 — the row announces its count, not just its colours', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 2, current: 2),
      );
      handle.dispose();

      final node = semanticsOf(tester, findBeads());
      expect(node.label, 'Progress: 2 of 5 complete');
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const ProgressBeads(total: 5, completed: 2, current: 2),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findBeads(),
          matchesGoldenFile('goldens/progress_beads_$theme.png'),
        );
      });
    }

    testWidgets('state golden — all done', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 5, current: 5),
      );
      await tester.pump();
      await expectLater(
        findBeads(),
        matchesGoldenFile('goldens/progress_beads_state_done.png'),
      );
    });

    testWidgets('state golden — none started', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 0, current: 0),
      );
      await tester.pump();
      await expectLater(
        findBeads(),
        matchesGoldenFile('goldens/progress_beads_state_idle.png'),
      );
    });
  });

  group('EvaTextField — behaviour', () {
    /// A field needs a `Material` ancestor; a real screen gets one from
    /// `Scaffold`, and this harness has none.
    Widget field({String? error, bool obscure = false}) => Material(
      type: MaterialType.transparency,
      child: EvaTextField(
        label: 'Password',
        controller: TextEditingController(),
        errorText: error,
        obscureText: obscure,
      ),
    );

    testWidgets('defect #8 — it is a real, editable field', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      await pumpAt(
        tester,
        Material(
          type: MaterialType.transparency,
          child: EvaTextField(label: 'Email', controller: controller),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        controller,
      );

      await tester.enterText(find.byType(TextField), 'you@example.com');
      await tester.pump();
      expect(controller.text, 'you@example.com');
      expect(find.text('you@example.com'), findsOneWidget);
    });

    testWidgets('the widget does not own or dispose the controller', (
      WidgetTester tester,
    ) async {
      // A design-system widget that disposed the caller's controller would make
      // every caller keep a second reference just to survive a rebuild.
      final controller = TextEditingController();
      await pumpAt(
        tester,
        Material(
          type: MaterialType.transparency,
          child: EvaTextField(label: 'Email', controller: controller),
        ),
      );
      await pumpAt(tester, const SizedBox.shrink());
      expect(() => controller.text = 'still alive', returnsNormally);
      controller.dispose();
    });

    testWidgets('§14 — the field carries its label as an accessible name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, field());
      handle.dispose();

      expect(find.bySemanticsLabel('Password'), findsWidgets);
      expect(find.text('PASSWORD'), findsOneWidget);
    });

    testWidgets('defect #10 — focus is state, not a literal', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, field());
      Border border() {
        final BoxDecoration decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: findField(),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        return decoration.border! as Border;
      }

      final Border idle = border();
      expect(idle.top.width, 1.5, reason: 'ds.tsx:307 unfocused');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(border(), evaFocusRingBorder(const EvaColors.dark()));
    });

    testWidgets('defect #10 — an error is state, and it is not colour-only', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, field(error: "That password's too short"));
      handle.dispose();

      expect(find.text("That password's too short"), findsOneWidget);
      // §14 — the icon and the live region, because the rim alone is colour.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        tester
            .widgetList<Semantics>(
              find.descendant(
                of: findField(),
                matching: find.byType(Semantics),
              ),
            )
            .any((Semantics s) => s.properties.liveRegion ?? false),
        isTrue,
      );
    });

    testWidgets('an errored rim is `err` while the field is idle', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, field(error: 'Nope'));
      final BoxDecoration decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: findField(),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        const EvaColors.dark().err,
      );
    });

    testWidgets('no error means no helper text and no icon', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, field());
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('a blank error string is not an error', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, field(error: '   '));
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('the trailing control is rendered inside the right inset', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        Material(
          type: MaterialType.transparency,
          child: EvaTextField(
            label: 'Password',
            controller: TextEditingController(),
            trailing: const IconActionButton(
              tooltipFamily: EvaTypography.uiFamily,

              icon: Icons.visibility,
              tooltip: 'Show password',
              onPressed: _noopVoid,
              size: 24,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(kEvaTextFieldPadding.right, 44.0);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(tester, field(), theme: data);
        await tester.pump();
        await expectLater(
          findField(),
          matchesGoldenFile('goldens/eva_text_field_$theme.png'),
        );
      });
    }

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await pumpAt(tester, field());
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await expectLater(
        findField(),
        matchesGoldenFile('goldens/eva_text_field_state_focused.png'),
      );
    });

    testWidgets('state golden — error', (WidgetTester tester) async {
      await pumpAt(tester, field(error: "That password's too short"));
      await tester.pump();
      await expectLater(
        findField(),
        matchesGoldenFile('goldens/eva_text_field_state_error.png'),
      );
    });
  });
}

void _noopVoid() {}
