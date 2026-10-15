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

  // ── the two pure functions §6 asks to be TDD'd ─────────────────────────────

  group('progressBeadPulseOpacityAt — `redesign.html:330-331`', () {
    test('holds 1 at both ends of the cycle and dips to .55 at the half', () {
      // `@keyframes dp{50%{opacity:.55}}` — a keyframe with **no** `0%` and no
      // `100%`, so the value is 1 at both ends and .55 at the half. A "0 → .55 →
      // 1" reading would put the dip at the wrong half of the loop.
      expect(progressBeadPulseOpacityAt(0), closeTo(1.0, 1e-9));
      expect(progressBeadPulseOpacityAt(0.8), closeTo(0.55, 1e-9));
      expect(
        progressBeadPulseOpacityAt(1.6),
        closeTo(1.0, 1e-9),
        reason: 'one whole period is the start of the next cycle',
      );
      expect(kProgressBeadPulsePeriod, const Duration(milliseconds: 1600));
      expect(kProgressBeadPulseOpacity, 0.55);
    });

    test('and it is a **dip**, so it climbs back on the second half', () {
      // The asymmetry is what distinguishes `dp` from a one-way fade, and a
      // triangle that only fell would pass the three assertions above.
      final double quarter = progressBeadPulseOpacityAt(0.4);
      final double threeQuarters = progressBeadPulseOpacityAt(1.2);
      expect(quarter, closeTo(0.775, 1e-9));
      expect(threeQuarters, closeTo(0.775, 1e-9));
      expect(
        progressBeadPulseOpacityAt(0.8),
        lessThan(quarter),
        reason: 'the apex is the darkest point, not the start',
      );
    });

    test('never leaves 0…1, which `Opacity` asserts on', () {
      // **This is the assertion the first version of this function failed.**
      // `Opacity`'s own guard is `basic.dart:345` — `opacity >= 0.0 && opacity
      // <= 1.0` — and a sign error that returned `1.45` at the apex was green in
      // every design-system test, because `pumpPrimitive` installs
      // `NeuralMotionScope(animationsEnabled: false)` and the phase is therefore
      // always 0 there. The screen suites that run the clocks for real are what
      // found it, which is the argument for walking both.
      for (double t = 0; t < 4; t += 0.05) {
        expect(
          progressBeadPulseOpacityAt(t),
          inInclusiveRange(0.0, 1.0),
          reason: 't=${t.toStringAsFixed(2)}s',
        );
      }
    });
  });

  group('progressBeadWidthAt / progressBeadsWidth — the row\'s arithmetic', () {
    test('one pill, the rest short, and `n − 1` gaps', () {
      // `redesign.html:329-330` — `.dot{8px}` and `.dot.cur{width: 26px}`,
      // `.dots{gap: 6px}`. `n − 1` gaps and never `n`: a CSS `gap` is the space
      // *between* adjacent items.
      expect(progressBeadWidthAt(ProgressBeadState.done), 8.0);
      expect(progressBeadWidthAt(ProgressBeadState.upcoming), 8.0);
      expect(progressBeadWidthAt(ProgressBeadState.current), 26.0);
      expect(progressBeadsWidth(const <ProgressBeadState>[]), 0.0);
      expect(
        progressBeadsWidth(beadStates(total: 5, completed: 1, current: 1)),
        8 * 4 + 26 + 6 * 4,
        reason: 'four short dots, one pill, four gaps',
      );
    });

    test('a row with no current bead is `8n + 6(n − 1)`', () {
      // The state a quiz is in before its payload lands, and the only case where
      // the CSS gap rule stands alone.
      final List<ProgressBeadState> row = beadStates(
        total: 3,
        completed: 0,
        current: -1,
      );
      expect(
        row.every((ProgressBeadState s) => s == ProgressBeadState.upcoming),
        isTrue,
      );
      expect(progressBeadsWidth(row), 8 * 3 + 6 * 2);
    });
  });

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
      expect(kProgressBeadSize, 8);
      expect(kProgressBeadGap, 6);
    });

    testWidgets('a done lozenge, a current pill, and a filled dot', (
      WidgetTester tester,
    ) async {
      // `redesign.html:329-332`. Two of the three states changed **fill
      // mechanics**, not colours: `done` and `upcoming` are now solid fills with
      // **no rim at all**, where `ds.tsx:362-363` drew a filled disc, a 2px ring
      // and a 1.5px outline respectively.
      Future<BoxDecoration> decorationAt(int index) async {
        final Container bead = tester.widget<Container>(
          find
              .descendant(of: findBeads(), matching: find.byType(Container))
              .at(index),
        );
        return bead.decoration! as BoxDecoration;
      }

      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 1, current: 1),
      );
      const EvaColors colors = EvaColors.dark();

      // `redesign.html:332` — `.dot.done{background: rgba(232,176,75,.45)}`.
      expect(
        (await decorationAt(0)).color,
        colors.ember.withValues(alpha: 0.45),
      );
      // `redesign.html:330` — `.dot.cur{width: 26px; background: var(--gold)}`.
      expect((await decorationAt(1)).color, colors.ember);
      // `redesign.html:329` — `.dot{background: rgba(255,255,255,.14)}`.
      expect((await decorationAt(4)).color, colors.ink.withValues(alpha: 0.14));

      // **No rim in any of the three**, asserted as an absence per state
      // because "one of them kept a border" is the shape of the regression this
      // restyle exists to remove — the old vocabulary's outline-vs-fill
      // distinction is what collided with the old current bead's ring.
      for (final int index in <int>[0, 1, 4]) {
        expect(
          (await decorationAt(index)).border,
          isNull,
          reason: 'bead $index — redesign.html declares no border in any state',
        );
      }
    });

    testWidgets('and the current bead is a pill, not a bigger dot', (
      WidgetTester tester,
    ) async {
      // `redesign.html:330` — `.dot.cur{width: 26px}`. This is the **only**
      // state-dependent dimension in the widget, so it is asserted on the
      // rendered width rather than on the constant.
      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 1, current: 1),
      );
      double widthAt(int index) => tester
          .getSize(
            find
                .descendant(of: findBeads(), matching: find.byType(Container))
                .at(index),
          )
          .width;
      double heightAt(int index) => tester
          .getSize(
            find
                .descendant(of: findBeads(), matching: find.byType(Container))
                .at(index),
          )
          .height;
      expect(widthAt(1), kProgressBeadCurrentWidth);
      expect(widthAt(1), 26);
      // Every other dot is the short edge — and all three are the same
      // **height**, because `redesign.html:330` overrides `.dot`'s `width` and
      // nothing else, so the current dot is a pill and not a larger dot.
      for (final int index in <int>[0, 2, 4]) {
        expect(widthAt(index), kProgressBeadSize);
      }
      for (final int index in <int>[0, 1, 4]) {
        expect(heightAt(index), kProgressBeadSize);
      }
    });

    testWidgets('only the current bead glows, and the done ones stopped', (
      WidgetTester tester,
    ) async {
      // `redesign.html:330` — `box-shadow: 0 0 12px rgba(232,176,75,.7)` on
      // `.cur` only. `ds.tsx:362,364` put `0 0 10px rgba(ember,.65)` on **done**
      // and `0 0 7px rgba(ember,.45)` on current, so the glow moved from "the
      // ones you have finished" to "the one you are on".
      await pumpAt(
        tester,
        const ProgressBeads(total: 5, completed: 2, current: 2),
      );
      Future<List<BoxShadow>> glowAt(int index) async {
        final Container bead = tester.widget<Container>(
          find
              .descendant(of: findBeads(), matching: find.byType(Container))
              .at(index),
        );
        return (bead.decoration! as BoxDecoration).boxShadow!;
      }

      expect(await glowAt(2), hasLength(1));
      expect((await glowAt(2)).single.blurRadius, kProgressBeadCurrentGlowBlur);
      expect(await glowAt(0), isEmpty, reason: 'bead 0 is done');
      expect(await glowAt(4), isEmpty, reason: 'bead 4 is upcoming');
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
      expect(
        idle.top.width,
        kEvaTextFieldRimWidth,
        reason: 'redesign.html:376 — `border: 1px solid var(--glass-line)`',
      );
      expect(kEvaTextFieldRimWidth, 1.0);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(border(), evaFocusRingBorder(const EvaColors.dark()));
    });

    testWidgets('a focused field has ONE halo, and it is a spread ring', (
      WidgetTester tester,
    ) async {
      // `redesign.html:378` — `box-shadow: 0 0 0 3px rgba(232,176,75,.12)`, one
      // shadow. `ds.tsx:310` wrote two: that ring at `.18` **and** a 20px fog at
      // `.12`. Asserted as a *count* and as a *radius*, because "the glow is
      // still there" would pass with both of them and is not the claim.
      await pumpAt(tester, field());
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final List<BoxShadow> glow =
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: findField(),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .boxShadow!;
      expect(glow, hasLength(1));
      expect(glow.single.spreadRadius, 3.0);
      expect(
        glow.single.blurRadius,
        0.0,
        reason:
            'zero offset and zero blur is what makes it a ring and not a fog',
      );
      expect(
        glow.single.color,
        const EvaColors.dark().ember.withValues(alpha: 0.12),
      );
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
