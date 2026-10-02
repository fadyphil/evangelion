import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// Widget behaviour, semantics and goldens for [EvaChip], [ProgressBeads] and
/// [EvaTextField] — the three whose TDD-able logic already has its own group in
/// `eva_chip_test.dart` / `progress_beads_test.dart` / `eva_text_field_test.dart`.
void main() {
  Finder findChip() => find.byType(EvaChip);
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

  group('EvaChip — behaviour', () {
    testWidgets('§14 — it is a button that announces its selection', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        EvaChip(label: 'Dark', selected: true, onSelected: (bool _) {}),
      );
      handle.dispose();

      final node = semanticsOf(tester, findChip());
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(node.label, 'Dark');
    });

    testWidgets('§14 — an InkWell, not a bare Container', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, EvaChip(label: 'Dark', onSelected: (bool _) {}));
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(EvaInk), findsOneWidget);
    });

    testWidgets('tapping reports the opposite selection', (
      WidgetTester tester,
    ) async {
      final List<bool> seen = <bool>[];
      await pumpAt(tester, EvaChip(label: 'Dark', onSelected: seen.add));
      await tester.tap(findChip());
      await tester.pump();
      expect(seen, <bool>[true]);
    });

    testWidgets('an inert chip is not focusable and takes no tap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, const EvaChip(label: 'Dark'));
      handle.dispose();

      // `isNot(true)` rather than `isFalse`: an inert chip must not be reported
      // as enabled, and whether the framework records the explicit `false` or
      // leaves the flag "not applicable" is its business, not the widget's.
      // Asserting `isFalse` here would be asserting the framework.
      expect(
        semanticsOf(
          tester,
          findChip(),
        ).flagsCollection.isEnabled.toBoolOrNull(),
        isNot(true),
      );
      await tester.tap(findChip());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('§14 — the selected state is not colour-only', (
      WidgetTester tester,
    ) async {
      Future<List<Widget>> partsOf({required bool selected}) async {
        await pumpAt(
          tester,
          EvaChip(label: 'Dark', selected: selected, onSelected: (bool _) {}),
        );
        return tester
            .widgetList<Widget>(
              find.descendant(of: findChip(), matching: find.byType(Icon)),
            )
            .toList();
      }

      // A check glyph, plus a dot that changes from a ring to a disc. Either
      // alone would do; both are asserted so neither can be quietly dropped.
      expect(await partsOf(selected: true), hasLength(1));
      expect(await partsOf(selected: false), isEmpty);

      // The dot: a hollow ring when unselected, a solid disc when selected.
      Future<(Color, bool)> dotOf({required bool selected}) async {
        await pumpAt(
          tester,
          EvaChip(label: 'Dark', selected: selected, onSelected: (bool _) {}),
        );
        // Found by **shape**, not by position: `.first` is the pill and `.last`
        // is the check glyph, which only exists when selected — so either
        // positional choice is asymmetric between the two states.
        final Container dot = find
            .descendant(of: findChip(), matching: find.byType(Container))
            .evaluate()
            .map((Element e) => e.widget)
            .whereType<Container>()
            .firstWhere(
              (Container c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration as BoxDecoration).shape == BoxShape.circle,
            );
        final BoxDecoration decoration = dot.decoration! as BoxDecoration;
        return (decoration.color!, decoration.border != null);
      }

      final (Color idleFill, bool idleRim) = await dotOf(selected: false);
      final (Color chosenFill, bool chosenRim) = await dotOf(selected: true);
      expect(idleRim, isTrue, reason: 'unselected dot is a ring, not a disc');
      expect(idleFill.a, 0);
      expect(chosenRim, isFalse, reason: 'selected dot is solid');
      expect(chosenFill.a, 1);
    });

    testWidgets('the label is the prototype\'s mono caps', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, EvaChip(label: 'Dark', onSelected: (bool _) {}));
      final Text label = tester.widget<Text>(find.text('DARK'));
      expect(label.style!.fontFamily, EvaTypography.monoFamily);
      expect(label.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('a sticker colour reaches the unselected filter style', (
      WidgetTester tester,
    ) async {
      // The property the `filter` golden used to carry and now cannot: an
      // unselected `filter` chip with a `color:` reads no `colors.*` at all, so it
      // is genuinely theme-invariant and no golden pair can separate it. Asserted
      // on the **resolved style** instead, which is where a regression would
      // actually be visible — `EvaChip` ignoring `color`, or preferring
      // `colors.ember` over the sticker, is caught here rather than by a picture.
      await pumpAt(
        tester,
        EvaChip(
          label: 'Gospels',
          variant: EvaChipVariant.filter,
          color: EvaStickerPalette.of(StickerSlot.sun),
          onSelected: (bool _) {},
        ),
      );
      final BoxDecoration decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(EvaChip),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      final Color sticker = EvaStickerPalette.of(StickerSlot.sun);
      expect(decoration.color, sticker.withValues(alpha: 0.12));
      expect(
        (decoration.border! as Border).top.color,
        sticker.withValues(alpha: 0.28),
      );
      expect(
        decoration.border! as Border,
        isNot(Border.all(color: const EvaColors.dark().ember)),
      );

      // And the same chip **selected** ignores the sticker and reads `ember` —
      // which is what makes the golden pair theme-derived.
      final EvaChipStyle selected = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: const EvaColors.dark(),
        selected: true,
        sticker: sticker,
      );
      final EvaChipStyle light = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: const EvaColors.light(),
        selected: true,
        sticker: sticker,
      );
      expect(selected.background, isNot(light.background));
      expect(selected.foreground, isNot(light.foreground));
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — toggle $theme', (
        WidgetTester tester,
      ) async {
        await pumpAt(
          tester,
          EvaChip(label: 'Dark', selected: true, onSelected: (bool _) {}),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findChip(),
          matchesGoldenFile('goldens/eva_chip_toggle_$theme.png'),
        );
      });

      testWidgets('a golden per theme — filter $theme', (
        WidgetTester tester,
      ) async {
        // ## WHY `selected: true` AND NO `color`
        //
        // This pair used to be two byte-identical files, and unlike
        // `text_link`'s the cause was legitimate rather than a stray literal: an
        // **unselected** `filter` chip with a sticker colour reads *no*
        // `colors.*` at all. `_filter` resolves `hue` to `sticker`, and every
        // channel — background, border, foreground, dot, glow — is that one hue at
        // a fixed alpha. The sticker palette is a **static** map shared by both
        // palettes (`eva_colors.dart:78,119`), so such a chip is genuinely
        // theme-invariant and no amount of re-pumping would separate the captures.
        //
        // `selected: true` is the form that *is* theme-derived: `hue` becomes
        // `colors.ember`, so background, rim, ink, dot and glow all come from the
        // palette and the two captures differ for a reason.
        //
        // `color` is dropped because in the selected state it is ignored
        // (`hue = selected ? colors.ember : sticker`), and leaving it in would
        // make the golden *look* as though it pinned the sticker colour when it
        // pins nothing of the sort. The sticker path is pinned by the test below
        // instead, on the resolved style, which is legible where a picture is not.
        await pumpAt(
          tester,
          EvaChip(
            label: 'Gospels',
            variant: EvaChipVariant.filter,
            selected: true,
            onSelected: (bool _) {},
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findChip(),
          matchesGoldenFile('goldens/eva_chip_filter_$theme.png'),
        );
      });

      testWidgets('a golden per theme — static $theme', (
        WidgetTester tester,
      ) async {
        await pumpAt(
          tester,
          const EvaChip(
            label: 'Settings',
            variant: EvaChipVariant.static,
            onSelected: _noopBool,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findChip(),
          matchesGoldenFile('goldens/eva_chip_static_$theme.png'),
        );
      });
    }

    testWidgets('state golden — unselected', (WidgetTester tester) async {
      await pumpAt(tester, EvaChip(label: 'Dark', onSelected: (bool _) {}));
      await tester.pump();
      await expectLater(
        findChip(),
        matchesGoldenFile('goldens/eva_chip_state_unselected.png'),
      );
    });

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await pumpAt(tester, EvaChip(label: 'Dark', onSelected: (bool _) {}));
      await tabUntilFocused(tester, findChip());
      await tester.pump();
      await expectLater(
        findChip(),
        matchesGoldenFile('goldens/eva_chip_state_focused.png'),
      );
    });
  });

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

void _noopBool(bool value) {}
