import 'package:evangelion/core/design_system/barrel.dart';
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
      expect(caption.style!.color, const EvaColors.dark().ink3);
    });

    testWidgets('the value is the display serif at the prototype\'s 24', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const StatTile(value: '14', label: 'Read'));
      final Text value = tester.widget<Text>(find.text('14'));
      expect(value.style!.fontFamily, EvaTypography.displayFamily);
      expect(value.style!.fontSize, 24.0);
      expect(value.style!.height, 1.0);
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
    testWidgets('the 56px prototype height is a floor, not a fixed height', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const SettingsTile(title: 'Theme', trailing: _box));
      expect(SettingsTile.minHeight, 56);
      expect(
        tester.getSize(findRow()).height,
        greaterThanOrEqualTo(40),
        reason: 'minHeight minus the vertical padding — see the widget doc',
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
      expect(tester.getSize(findRow()).height, greaterThan(56 - 16));
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
    testWidgets('the section size is the Settings mono-caps label', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const EvaSectionHeader(label: 'Reading'));
      final Text header = tester.widget<Text>(find.text('READING'));
      expect(header.style!.fontFamily, EvaTypography.monoFamily);
      expect(header.style!.color, const EvaColors.dark().ink3);
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
          action: EvaButton(label: 'Start', onPressed: _noop),
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
            action: EvaButton(label: 'Start', onPressed: _noop),
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
            child: ErrorView(message: 'Boom', onRetry: _noop),
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
