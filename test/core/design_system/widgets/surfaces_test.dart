import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The Tier-1 widgets that render text in a constrained box and nothing else —
/// [StatTile], [SettingsTile], [SettingsGroup], [EvaSectionHeader], [EmptyState],
/// [ErrorView]. §14's text-scale risk lives here, and the golden-per-theme and
/// semantics work lives here.
void main() {
  Finder findTile() => find.byType(StatTile);
  Finder findRow() => find.byType(SettingsTile);
  Finder findGroup() => find.byType(SettingsGroup);
  Finder findHeader() => find.byType(EvaSectionHeader);
  Finder findEmpty() => find.byType(EmptyState);
  Finder findError() => find.byType(ErrorView);

  /// The style a [SettingsTile]'s title renders with.
  ///
  /// On the `AnimatedDefaultTextStyle` and not the `Text`, since Phase 4.2: the
  /// hover colour has to transition (`redesign.html:419`'s `transition:.2s`),
  /// and an explicit `Text.style` beats the ambient default — so reading
  /// `Text.style` would report `null` and, if it did not, would report the
  /// resting colour forever.
  TextStyle rowStyleOf(WidgetTester tester) => tester
      .widget<AnimatedDefaultTextStyle>(
        find
            .descendant(
              of: findRow(),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      )
      .style;

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    double textScale = 1.0,
  }) => pumpPrimitive(
    tester,
    Align(alignment: Alignment.topCenter, child: child),
    theme: theme,
    textScale: textScale,
  );

  group('StatTile', () {
    testWidgets('is the prototype\'s 16 radius and 14/10 padding', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Row(
          children: <Widget>[
            Expanded(
              child: StatTile(value: '14', label: 'Read'),
            ),
            Expanded(
              child: StatTile(value: '9', label: 'Reflected'),
            ),
            Expanded(
              child: StatTile(value: '5/5', label: 'Best'),
            ),
          ],
        ),
      );
      expect(StatTile.radius, 16);
      expect(
        StatTile.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      );
      expect(StatTile.stackGap, EvaSpacing.xs);
    });

    testWidgets('the caption is the prototype\'s mono caps', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const StatTile(value: '14', label: 'Read'));
      final Text caption = tester.widget<Text>(find.text('READ'));
      expect(caption.style!.fontFamily, EvaTypography.monoFamily);
      // `redesign.html:408` — `font-size:8.5px;letter-spacing:.14em`, no weight.
      expect(StatTile.labelSize, 8.5);
      expect(caption.style!.fontSize, 8.5);
      // `.14em` **premultiplied**: Flutter's `letterSpacing` is a logical-pixel
      // advance and CSS's `em` is relative to the element's own font, so
      // 8.5 × 0.14 = 1.19.
      expect(caption.style!.letterSpacing, closeTo(1.19, 1e-9));
      expect(caption.style!.fontWeight, FontWeight.w400);

      // **The ink does NOT move to `--ink-1`.** `redesign.html:408` ends
      // `color:var(--ink-1)` and `EvaColors` has no `ink1`: it publishes `ink`,
      // `ink2` and an `ink3` with no prototype counterpart, so the middle ink of
      // the prototype's three cannot be named. Decision 149 already moved this
      // run off `ink3` (1.65:1 on dark glass) onto `ink2` (4.73:1) and that
      // argument is untouched by the redesign.
      expect(caption.style!.color, const EvaColors.dark().ink2);
    });

    testWidgets('the value is the redesign\'s mono 11, not the 24pt serif', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const StatTile(value: '14', label: 'Read'));
      final Text value = tester.widget<Text>(find.text('14'));
      // `redesign.html:407` — `font-family:var(--mono);font-size:11px`, no
      // `font-weight`. Was `ds.tsx:474`'s `F.display, 24, 600`.
      expect(value.style!.fontFamily, EvaTypography.monoFamily);
      expect(value.style!.fontFamily, isNot(EvaTypography.displayFamily));
      expect(value.style!.fontSize, 11.0);
      expect(StatTile.valueSize, 11.0);
      expect(value.style!.fontWeight, FontWeight.w400);
      // `:407` ends `color:var(--ink-0)`, which is this palette's `ink`.
      expect(value.style!.color, const EvaColors.dark().ink);
      // `:407` declares no `letter-spacing`, so it is none — and that is a
      // change, because `monoCaps` inherits `labelMedium`'s 0.5.
      expect(value.style!.letterSpacing, 0.0);
    });

    testWidgets('the panel is still `ds.tsx`\'s — radius 16, padding 14/10', (
      WidgetTester tester,
    ) async {
      // The other half of the split, asserted so it cannot move by accident: the
      // redesign *replaces* this tile with `.ringbox`'s ring (`redesign.html:
      // 403-409`, a `CustomPaint`), which has no panel to copy, so the panel
      // stayed on `ds.tsx:462-478` and only the type was re-pointed.
      await pumpAt(tester, const StatTile(value: '14', label: 'Read'));
      expect(StatTile.radius, 16);
      expect(
        StatTile.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      );
      expect(
        find.descendant(of: findTile(), matching: find.byType(GlassSurface)),
        findsOneWidget,
        reason: 'the `ds.tsx` panel survives until Phase 6.2 builds the ring',
      );
    });

    testWidgets('it is a tint, not a blur — §13.4\'s budget', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const StatTile(value: '14', label: 'Read'));
      expect(
        find.descendant(of: findTile(), matching: find.byType(BackdropFilter)),
        findsNothing,
        reason:
            'ds.tsx:469 blurs this tile; §13.4 permits a blur on Home\'s panel '
            'and top bar only, and `/result` is "everything else"',
      );
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const Row(
            children: <Widget>[
              Expanded(
                child: StatTile(value: '14', label: 'Read'),
              ),
              Expanded(
                child: StatTile(value: '9', label: 'Reflected'),
              ),
              Expanded(
                child: StatTile(value: '5/5', label: 'Best'),
              ),
            ],
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          find.byType(Row),
          matchesGoldenFile('goldens/stat_tile_$theme.png'),
        );
      });
    }
  });

  group('SettingsTile', () {
    testWidgets('the row is flat — no glass, no radius, one hairline', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const SettingsTile(title: 'Theme', trailing: _box));

      // `redesign.html:419` — `background:none`, `border-radius:0`, no
      // left/right/top border. **The largest visual change in Phase 4.2** and the
      // redesign's own language (R3 is flat by design), not a regression.
      expect(
        find.descendant(of: findRow(), matching: find.byType(GlassSurface)),
        findsNothing,
        reason: '`.srow` has no fill, so there is no panel to be tinted',
      );

      // The bottom hairline, and only that edge.
      final DecoratedBox row = tester.widget<DecoratedBox>(
        find.descendant(of: findRow(), matching: find.byType(DecoratedBox)),
      );
      final BoxDecoration d = row.decoration as BoxDecoration;
      expect(d.color, isNull, reason: '`background:none`');
      expect(d.borderRadius, isNull, reason: '`border-radius:0`');
      // `BorderSide` rather than `BoxBorder`: only `Border` has four sides, and
      // this is the assertion that there is exactly **one** of them.
      final Border b = d.border! as Border;
      expect(b.top, BorderSide.none, reason: '`border-top:none`');
      expect(b.left, BorderSide.none, reason: '`border-left:none`');
      expect(b.right, BorderSide.none, reason: '`border-right:none`');
      expect(b.bottom.width, 1.0, reason: '`border-bottom:1px solid`');
      expect(
        b.bottom.color,
        const EvaColors.dark().ink.withValues(
          alpha: SettingsTile.hairlineAlpha,
        ),
      );
      expect(SettingsTile.hairlineAlpha, 0.06);

      // `padding: 15px 4px`, replacing `ds.tsx:488`'s `'0 16px'`.
      expect(
        SettingsTile.padding,
        const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
      );
    });

    testWidgets('the title is 14.5px at the face\'s own weight', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const SettingsTile(title: 'Theme', trailing: _box));
      // On the `AnimatedDefaultTextStyle`, not on the `Text` — see `rowStyleOf`.
      final TextStyle style = rowStyleOf(tester);
      // `redesign.html:419` — `font-size:14.5px` and no `font-weight`.
      expect(style.fontFamily, EvaTypography.uiFamily);
      expect(style.fontSize, 14.5);
      expect(SettingsTile.titleSize, 14.5);
      expect(style.fontWeight, FontWeight.w400);
      // `color:var(--ink-0)` at rest, and `:420`'s `var(--gold)` on hover.
      expect(style.color, const EvaColors.dark().ink);
    });

    testWidgets('hovering turns the title gold and slides the row 4px', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const SettingsTile(title: 'Theme', trailing: _box));
      await tester.pumpAndSettle();

      final Rect atRest = tester.getRect(findRow());
      expect(rowStyleOf(tester).color, isNot(const EvaColors.dark().emberInk));
      // The row's **painted** box, not `find.byType(SettingsTile)` and not
      // `find.byType(AnimatedContainer)`. Both of those resolve to a box that
      // sits **outside** the transform — `AnimatedContainer` is its own first
      // RenderObject, and `getTopLeft` does not include an object's own paint
      // transform — so both report a 0px slide while the row has plainly moved.
      // The `DecoratedBox` is inside the `Transform`, so its global position is
      // the painted one.
      final Finder painted = find.descendant(
        of: findRow(),
        matching: find.byType(DecoratedBox),
      );
      // Captured **before** the hover. Reading it afterwards and then comparing
      // it to itself would have compared the hovered position to itself, and the
      // first version of this test did exactly that and asserted a 8px slide
      // against an actual 4px.
      final double atRestLeft = tester.getTopLeft(painted).dx;

      final TestGesture hover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      // `addPointer` alone registers the device; a `MouseRegion` only sees a
      // **hover**, so the pointer has to actually move onto the row.
      await hover.addPointer(location: Offset.zero);
      await hover.moveTo(atRest.center);
      await tester.pumpAndSettle();

      // `:420` — `.srow:hover{color:var(--gold);transform:translateX(4px)}`.
      expect(SettingsTile.hoverShift, 4.0);
      expect(rowStyleOf(tester).color, const EvaColors.dark().emberInk);
      expect(
        tester.getTopLeft(painted).dx,
        closeTo(atRestLeft + SettingsTile.hoverShift, 0.01),
        reason: 'the whole row translates, hairline included — as CSS does',
      );
      expect(
        tester.getTopLeft(findRow()).dx,
        closeTo(atRestLeft, 0.01),
        reason: '…but the hover region stays where the pointer is',
      );

      await hover.removePointer();
      await tester.pumpAndSettle();
      expect(rowStyleOf(tester).color, const EvaColors.dark().ink);
      expect(tester.getTopLeft(painted).dx, closeTo(atRestLeft, 0.01));
    });

    testWidgets('the 56px floor is kept, and is the row\'s TOTAL', (
      WidgetTester tester,
    ) async {
      // `redesign.html:419` has no height at all — the row is `content + 30`.
      // The floor is **kept** anyway, and re-composed against the new padding so
      // the total is still 56 and not 56 + 30. See `SettingsTile.minHeight`'s doc
      // for why it could not simply be deleted: two harnesses read it.
      expect(SettingsTile.minHeight, 56);
      expect(SettingsTile.contentFloor, 26);
      expect(SettingsTile.contentFloor + 2 * 15, SettingsTile.minHeight);

      // **Both halves of the arithmetic, separately.** A trailing control shorter
      // than the floor leaves the floor binding; a taller one wins and the row is
      // `content + 30`. Asserting only the constant would have passed with
      // `contentFloor` off by one whole padding — which is exactly the bug this
      // test was written after.
      //
      // The floor case measures **57, not 56**: `BoxDecoration.padding` is the
      // border's dimensions, so the 1px hairline occupies a pixel of its own. A
      // border that took no space would paint outside the box and be clipped.
      await pumpAt(
        tester,
        const SettingsTile(
          title: 'T',
          trailing: SizedBox(width: 10, height: 10),
        ),
      );
      expect(tester.getSize(findRow()).height, SettingsTile.minHeight + 1);

      await pumpAt(
        tester,
        const SettingsTile(
          title: 'T',
          trailing: SizedBox(width: 10, height: 40),
        ),
      );
      expect(
        tester.getSize(findRow()).height,
        40 + 2 * SettingsTile.verticalPadding + 1,
        reason: 'content + 30 + the hairline — the prototype\'s row, no floor',
      );
    });

    testWidgets('it grows rather than clipping a large control', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const SizedBox(
          width: 320,
          child: SettingsTile(title: 'Default language', trailing: _tallBox),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(findRow()).height,
        greaterThan(SettingsTile.minHeight),
        reason: 'a tall trailing control pushes the row past its floor',
      );
    });

    testWidgets('an inert row adds no semantics node of its own', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, const SettingsTile(title: 'Theme', trailing: _box));
      handle.dispose();
      expect(find.byType(EvaFocusRing), findsNothing);
      expect(find.byType(EvaInk), findsNothing);
    });

    testWidgets('a tappable row is a named button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const SettingsTile(title: 'Edit profile', trailing: _box, onTap: _noop),
      );
      handle.dispose();
      expect(
        find.bySemanticsLabel(RegExp('Edit profile')),
        findsOneWidget,
        reason:
            'the row\'s own label, with the trailing control merged into the '
            'same node — hence a RegExp rather than an exact match',
      );
    });

    testWidgets('tapping the row reports', (WidgetTester tester) async {
      int taps = 0;
      await pumpAt(
        tester,
        SettingsTile(
          title: 'Edit profile',
          trailing: _box,
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.byType(EvaInk));
      await tester.pump();
      expect(taps, 1);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const SettingsTile(title: 'Notifications', trailing: _toggleBox),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findRow(),
          matchesGoldenFile('goldens/settings_tile_$theme.png'),
        );
      });
    }
  });

  group('SettingsGroup', () {
    testWidgets('it is a header plus its children, 10px apart', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const SettingsGroup(
          label: 'Appearance',
          children: <Widget>[
            SettingsTile(title: 'Theme', trailing: _box),
            SettingsTile(title: 'Font size', trailing: _box),
          ],
        ),
      );
      expect(findGroup(), findsOneWidget);
      expect(findHeader(), findsOneWidget);
      expect(find.byType(SettingsTile), findsNWidgets(2));
      expect(SettingsGroup.rowGap, 10);
    });

    testWidgets('the group opens with 20px above its label, `:422`', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const SettingsGroup(
          label: 'Appearance',
          children: <Widget>[
            SettingsTile(title: 'Theme', trailing: _box),
            SettingsTile(title: 'Font size', trailing: _box),
          ],
        ),
      );
      // `redesign.html:422` — `.sgroup{margin:20px 0 6px}`. The **20** is applied
      // as `topGap`.
      expect(SettingsGroup.topGap, 20.0);
      final Rect group = tester.getRect(findGroup());
      final Rect label = tester.getRect(findHeader());
      expect(label.top - group.top, SettingsGroup.topGap);

      // **The 6 is not applied**, and that is the point. `:422`'s bottom margin
      // is the space under a *label*, which in the redesign a `.srow`'s own
      // `padding:15px 4px` supplies; adding 6 here would open the group with a
      // narrower gap than the 10 it keeps internally.
      expect(SettingsGroup.rowGap, 10, reason: 'kept from SettingsScreen.tsx');
    });

    testWidgets('an empty group is a bare label and no gap', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const SettingsGroup(label: 'About', children: <Widget>[]),
      );
      expect(tester.takeException(), isNull);
      expect(findHeader(), findsOneWidget);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const SettingsGroup(
            label: 'Appearance',
            children: <Widget>[
              SettingsTile(title: 'Theme', trailing: _box),
              SettingsTile(title: 'Font size', trailing: _box),
            ],
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findGroup(),
          matchesGoldenFile('goldens/settings_group_$theme.png'),
        );
      });
    }
  });

  group('EvaSectionHeader', () {
    testWidgets('the section size is `.mono`, and gold', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const EvaSectionHeader(label: 'Reading'));
      final Text header = tester.widget<Text>(find.text('READING'));
      expect(header.style!.fontFamily, EvaTypography.monoFamily);
      // `redesign.html:30` — `.mono{font-size:10.5px;letter-spacing:.16em}`.
      //
      // **Not 10px / `.2em`.** The prototype's `.sgroup` (`:422`) is
      // `margin:20px 0 6px` and types nothing; the eight `.sgroup` elements
      // (`:645`-`:696`) carry `class="sgroup mono"`, and `.mono` at `:30` is
      // where the size and the tracking live. Citing `:422` for a size would be
      // a reference a reader cannot follow.
      expect(header.style!.fontSize, 10.5);
      expect(EvaSectionHeader.sectionSize, 10.5);
      // `.16em` **premultiplied** by the size — Flutter's `letterSpacing` is a
      // logical-pixel advance, CSS's `em` is relative to the element's own font.
      expect(header.style!.letterSpacing, closeTo(10.5 * 0.16, 1e-9));
      expect(EvaSectionHeader.sectionTracking, 0.16);
      // `:30` declares no weight and `:31` (`.mono b`) declares `600` only for a
      // `<b>` this label does not have, so the label is normal.
      expect(header.style!.fontWeight, FontWeight.w400);

      // `redesign.html:31` — `.mono b{color:var(--gold)}`, applied to the label.
      //
      // **This is `emberInk`, not `ink2`** (decision 149) and not `ink3`
      // (`:422` era). In dark the two "gold" words are the same colour; in light
      // they differ, and `emberInk` is the one that clears AA as a label.
      expect(header.style!.color, const EvaColors.dark().emberInk);
      expect(header.style!.color, const EvaColors.dark().ember);
      expect(
        const EvaColors.light().emberInk,
        isNot(const EvaColors.light().ember),
        reason: 'and this is where the two spellings part company',
      );
    });

    testWidgets('the title size is the bold UI form', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const EvaSectionHeader(
          label: 'Journey',
          size: EvaSectionHeaderSize.title,
        ),
      );
      final Text header = tester.widget<Text>(find.text('Journey'));
      expect(header.style!.fontFamily, EvaTypography.uiFamily);
      expect(header.style!.fontSize, 16.0, reason: 'titleMedium, per §5.1');
      expect(header.style!.fontWeight, FontWeight.w700);
      expect(header.style!.color, const EvaColors.dark().ink);
    });

    testWidgets('a trailing control sits on the right', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const EvaSectionHeader(label: 'Reading', trailing: Text('See all')),
      );
      expect(find.text('See all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the header sits 10px above its content', (
      WidgetTester tester,
    ) async {
      expect(EvaSectionHeader.bottomGap, EvaSpacing.md + EvaSpacing.xs);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const Column(
            children: <Widget>[
              EvaSectionHeader(label: 'Appearance'),
              EvaSectionHeader(
                label: 'Journey',
                size: EvaSectionHeaderSize.title,
              ),
            ],
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          find.byType(Column),
          matchesGoldenFile('goldens/eva_section_header_$theme.png'),
        );
      });
    }
  });

  group('EmptyState — the prototype has neither state view', () {
    testWidgets('it renders icon, title, message and an optional action', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing yet',
          message: 'Your reflections will appear here.',
          action: EvaButton(
            labelFamily: EvaTypography.uiFamily,
            label: 'Start',
            onPressed: _noop,
          ),
        ),
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Your reflections will appear here.'), findsOneWidget);
      expect(find.byType(EvaButton), findsOneWidget);
    });

    testWidgets('the action is optional', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing yet',
          message: 'No reflections yet.',
        ),
      );
      expect(find.byType(EvaButton), findsNothing);
    });

    testWidgets('its title is 28sp, not displayLarge\'s 57', (
      WidgetTester tester,
    ) async {
      // The Phase-1 decision-5 hazard, named in the widget's doc: at 1.22× on a
      // 320px screen, `displayLarge` wraps to four lines and overflows.
      await pumpAt(
        tester,
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing yet',
          message: 'No reflections yet.',
        ),
      );
      final TextStyle style = tester
          .widget<Text>(find.text('Nothing yet'))
          .style!;
      expect(style.fontSize, 28.0);
      expect(style.fontSize, lessThan(emptyStatePrototypeMax / 1.22 + 1));
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing yet',
            message: 'Your reflections will appear here.',
            action: EvaButton(
              labelFamily: EvaTypography.uiFamily,
              label: 'Start',
              onPressed: _noop,
            ),
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findEmpty(),
          matchesGoldenFile('goldens/empty_state_$theme.png'),
        );
      });
    }
  });

  group('ErrorView', () {
    testWidgets('it renders the message and a retry', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await pumpAt(
        tester,
        ErrorView(
          message: 'Could not reach the server.',
          onRetry: () => retries++,
          retryLabel: 'Retry',
          retryFamily: EvaTypography.uiFamily,
        ),
      );
      expect(find.text('Could not reach the server.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byType(EvaButton));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('without a retry there is no button, and no assertion', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const ErrorView(message: 'That response could not be read.'),
      );
      expect(find.byType(EvaButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a retry with no label is a programming error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const Align(
            alignment: Alignment.topCenter,
            // **`retryLabel` and `retryFamily` both absent on purpose**: the pair of
            // asserts below fires on the missing label, which is this test's subject.
            // The family half has its own test underneath, so neither one silently
            // stops being about what it names.
            child: ErrorView(message: 'Boom', onRetry: _noop),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('and so is a retry with a label but no FAMILY', (
      WidgetTester tester,
    ) async {
      // `EvaButton.labelFamily` became **required** in Phase 7, and the label a
      // retry renders is the app's own localized string — `حاول مرة أخرى` on the
      // Arabic arm. A label with no family falls back to `titleMedium`'s, which is
      // **DM Sans** and carries no Arabic at all, so this is a second tofu on the
      // one screen where something has already gone wrong.
      //
      // Asserted rather than assumed because `retryFamily` is nullable-and-asserted
      // like `retryLabel`: Dart cannot express "required only when `onRetry` is
      // set", and a debug crash is the honest substitute.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const Align(
            alignment: Alignment.topCenter,
            child: ErrorView(
              message: 'Boom',
              onRetry: _noop,
              retryLabel: 'Retry',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('it is a live region, so a failure that arrives is announced', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const ErrorView(message: 'Could not reach the server.'),
      );
      handle.dispose();
      expect(find.byType(Semantics), findsWidgets);
      expect(
        tester
            .widgetList<Semantics>(
              find.descendant(
                of: findError(),
                matching: find.byType(Semantics),
              ),
            )
            .any((Semantics s) => s.properties.liveRegion ?? false),
        isTrue,
      );
    });

    testWidgets('the icon is a warning, not the empty state\'s neutral glyph', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const ErrorView(message: 'Boom'));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await pumpAt(
        tester,
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing yet',
          message: 'No reflections yet.',
        ),
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(findEmpty(), findsOneWidget);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const ErrorView(
            message: 'Could not reach the server.',
            onRetry: _noop,
            retryLabel: 'Retry',
            retryFamily: EvaTypography.uiFamily,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findError(),
          matchesGoldenFile('goldens/error_view_$theme.png'),
        );
      });
    }
  });

  group('the §3.1 deletion test is deferred, not passed', () {
    test('the four watch-list widgets built here say so', () {
      // `04-widget-inventory.md` §3.1 requires a re-run of the deletion test on
      // six widgets. Phase 1 did not re-run it and this phase cannot: Phase 5 built
      // `features/auth/`, but the six widgets below still have exactly one call
      // site each, and the re-run needs a second feature to demote them **into**.
      // The deferral is recorded in each widget's doc, and this test is the single
      // place a reader has to look to find that the test was NOT re-run.
      //
      // (The reason used to read "there is no feature to demote into until Phase 5",
      // which is the same wrong-premise/right-conclusion shape decision 21 records
      // for two `lib/` sites: Phase 5 arrived and the deferral was still correct,
      // so only the stated reason rotted. It now cites the call sites, which is the
      // thing that was always load-bearing.)
      for (final Type widget in <Type>[
        ProgressBeads,
        SettingsGroup,
        EvaSectionHeader,
        TextLink,
      ]) {
        expect(
          widget.toString(),
          isNotEmpty,
          reason: '$widget is on the §3.1 watch list and is built public',
        );
      }
    });
  });
}

void _noop() {}

/// The prototype's largest type, `ReadingEnScreen.tsx:37` — `fontSize: 34`.
///
/// The ceiling an `EmptyState` title has to stay under is 34 ÷ 1.22 ≈ 27.9, i.e.
/// the largest display slot that still survives §14's 1.22× requirement, which is
/// `headlineMedium` (28) and what [EmptyState.titleStyle] uses.
const double emptyStatePrototypeMax = 34;

/// A fixed control box, so a row's height is decided by the widget under test
/// rather than by whatever a switch happened to measure.
const Widget _box = SizedBox(width: 60, height: 24);

/// A control taller than the prototype's 56px row, to prove the row grows.
const Widget _tallBox = SizedBox(width: 60, height: 48);

/// A stand-in for `EvaToggle` inside a golden. Real, so the golden shows a real
/// control — [EvaToggle] itself is covered in `controls_test.dart`.
const Widget _toggleBox = SizedBox(width: 44, height: 24);
