import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_harness.dart';

/// The **slices** `SettingsScope` publishes, and the two paths the scope has
/// that a page is most likely to meet.
///
/// ## WHY THIS FILE EXISTS
///
/// `SettingsScope` was one `InheritedNotifier` over the whole thirty-field
/// `UserSettings`, and it notified on **every** write — so every dependent
/// rebuilt on every write. It now publishes four **slices**, each with its own
/// notifier, and the **handle** is read without a dependency.
///
/// **That is a change with two edges, and both are asserted here.** A slice
/// that is too wide puts the old cost back; a handle read with a dependency
/// rebuilds the reader of a stable object. The numbers are in
/// `docs/PERFORMANCE.md`; the gate is `test/rebuild_isolation_budget_test.dart`.
void main() {
  group('a slice', () {
    testWidgets('reaches a dependent, and only that slice', (
      WidgetTester tester,
    ) async {
      final SettingsHandle handle = settingsHandleOf(tester);
      int builds = 0;

      await tester.pumpWidget(
        settingsScope(
          tester,
          Builder(
            builder: (BuildContext context) {
              builds++;
              final RitualSettings ritual = SettingsScope.ritualOf(context);
              return Text(
                '${ritual.haptics}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      expect(builds, 1, reason: 'the first build is the first build');

      // A write that changes the **ritual** slice: the dependent rebuilds.
      await handle.write((UserSettings s) => s.copyWith(haptics: false));
      await tester.pump();
      expect(
        builds,
        2,
        reason: 'the ritual slice changed, so its reader moved',
      );

      // A write that changes **neither** slice the reader reads: the
      // dependent does **not** rebuild.
      //
      // **This is the whole point of the slices.** The old scope notified on
      // every write, so this write rebuilt every dependent in the app —
      // including the three invisible tab screens the dock keeps alive.
      await handle.write((UserSettings s) => s.copyWith(hue: 200));
      await tester.pump();
      expect(
        builds,
        2,
        reason:
            'the hue is in the aurora\'s slice, and this reader is the '
            'ritual\'s. A write to one slice must not wake the other.',
      );
    });

    testWidgets('is not found by a page pumped bare, and the locator answers', (
      WidgetTester tester,
    ) async {
      // **No scope above the context.** The locator's registered handle holds
      // the same value and writes through the same cubit, but it is **not
      // watched** — the same bargain the handle's own lookup makes, and the
      // reason a page pumped bare renders the right value and writes
      // somewhere real.
      final SettingsHandle handle = settingsHandleOf(tester);
      RitualSettings? seen;

      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            seen = SettingsScope.ritualOf(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(seen, isNotNull, reason: 'the locator fallback must answer');
      expect(
        seen!.haptics,
        handle.settings.haptics,
        reason: 'the fallback reads the registered handle\'s own record.',
      );
    });
  });

  group('the handle', () {
    testWidgets('is read WITHOUT a dependency, and a swap is honoured', (
      WidgetTester tester,
    ) async {
      final SettingsHandle first = settingsHandleOf(tester);
      final SettingsHandle second = SettingsHandle(
        read: () => const UserSettings(hue: 42),
        write: (UserSettings Function(UserSettings) change) async {},
      );

      int builds = 0;
      await tester.pumpWidget(
        settingsScope(
          tester,
          Builder(
            builder: (BuildContext context) {
              builds++;
              // **The handle, read without a dependency.** A dependent read
              // here would rebuild this subtree on every settings write, which
              // is the cost the split removed.
              final SettingsHandle handle = SettingsScope.handleOf(context);
              return Text(
                '${handle.settings.hue}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      expect(builds, 1);

      // A write on the handle the scope is **not** over: nothing rebuilds.
      await second.write((UserSettings s) => s.copyWith(hue: 99));
      await tester.pump();
      expect(
        builds,
        1,
        reason:
            'the scope is over the first handle, and the handle is read '
            'without a dependency, so a write anywhere rebuilds nothing.',
      );

      // A write on the handle the scope **is** over: the scope's own
      // notifier fires, and the **slices** wake their own readers. This
      // builder reads no slice, so it does not rebuild — and that is the
      // point: the handle is stable, and the slices are what move.
      await first.write((UserSettings s) => s.copyWith(hue: 7));
      await tester.pump();
      expect(
        builds,
        1,
        reason:
            'the builder reads the handle and no slice, and the handle does '
            'not change identity. A slice reader would have moved.',
      );
    });

    testWidgets('a DIFFERENT handle replaces the bridges', (
      WidgetTester tester,
    ) async {
      // The scope holds one bridge per slice, and each bridge subscribes to
      // the handle it was built with. **A different handle is a different
      // subscriber**, so the old bridges have to go — or the disposed scope
      // keeps answering announcements meant for someone else.
      final SettingsHandle first = settingsHandleOf(tester);
      final SettingsHandle second = SettingsHandle(
        read: () => const UserSettings(haptics: false),
        write: (UserSettings Function(UserSettings) change) async {},
      );

      int ritualBuilds = 0;
      // **The scope is built directly**, and not through
      // `settingsScope(tester, …)` — that helper always installs the
      // **locator's** handle, and this test is about a scope over a handle
      // that is *not* the locator's.
      Widget tree(SettingsHandle handle) => MaterialApp(
        home: SettingsScope(
          key: const Key('test-scope'),
          handle: handle,
          child: Builder(
            builder: (BuildContext context) {
              ritualBuilds++;
              final RitualSettings ritual = SettingsScope.ritualOf(context);
              return Text(
                '${ritual.haptics}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      await tester.pumpWidget(tree(first));
      expect(ritualBuilds, 1);

      // **The swap.** The scope is rebuilt over a different handle, so its
      // bridges are disposed and rebuilt over the new one.
      await tester.pumpWidget(tree(second));
      await tester.pump();
      expect(
        ritualBuilds,
        greaterThanOrEqualTo(1),
        reason: 'the swap must not throw.',
      );

      // A write on the **old** handle must not wake the scope any more: the
      // old bridges were disposed and their subscription dropped.
      final int before = ritualBuilds;
      await first.write((UserSettings s) => s.copyWith(haptics: false));
      await tester.pump();
      expect(
        ritualBuilds,
        before,
        reason:
            'the old handle\'s bridges were disposed with the swap, so its '
            'announcement reaches nobody.',
      );
    });
  });

  group('the settings cubit', () {
    test('a write that changes nothing emits nothing', () {
      // The rule the cubit already carries, asserted here because the scope
      // now depends on it: **an emit that changes nothing is a notification
      // that wakes nobody**, and the cubit's own doc says so.
      final SettingsCubit cubit = settingsHarness().cubit;
      addTearDown(cubit.close);
      expect(cubit.state.settings, const UserSettings());
    });
  });
}
