import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_home_page.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../servant_harness.dart';

/// The portal's hub — the sections this role has.
///
/// ## AND WHY THE ROLE IS **SUPPLIED** AND NOT READ FROM THE LOCATOR
///
/// The hub's whole content depends on the role, and a widget test cannot reach
/// the locator without configuring the whole graph. So the page takes its
/// [RoleAccess] as a parameter — `LoginPage`'s `bloc` is the same shape and the
/// same reason.
void main() {
  /// The hub, with the role fixed and the routes recorded.
  Widget hubFor(UserRole role, {List<String>? opened}) => ServantHomePage(
    roleAccess: LiveRoleAccess(() => role),
    onOpenRoute: opened?.add,
  );

  group('a viewer servant', () {
    testWidgets('sees the daily report and not the scheduling screen', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubFor(UserRole.viewerServant));

      expect(find.text('Daily report'), findsOneWidget);
      expect(find.text('Schedule a reading'), findsNothing);
      expect(find.text('Author questions'), findsNothing);
    });

    testWidgets('and still sees the reader\'s own shell', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubFor(UserRole.viewerServant));

      expect(find.text('Read as a reader'), findsOneWidget);
    });
  });

  group('an admin servant', () {
    testWidgets('sees all three of the portal\'s own sections', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubFor(UserRole.adminServant));

      expect(find.text('Daily report'), findsOneWidget);
      expect(find.text('Schedule a reading'), findsOneWidget);
      expect(find.text('Author questions'), findsOneWidget);
    });
  });

  group('the reader\'s own shell', () {
    testWidgets('is the entry that opens `/`', (WidgetTester tester) async {
      final List<String> opened = <String>[];
      await pumpServant(tester, hubFor(UserRole.adminServant, opened: opened));

      await tester.tap(find.text('Read as a reader'));
      await tester.pump();

      expect(opened, <String>[AppRoutes.home]);
      expect(AppRoutes.home, '/');
    });

    testWidgets('and the report entry opens the report', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await pumpServant(tester, hubFor(UserRole.adminServant, opened: opened));

      await tester.tap(find.text('Daily report'));
      await tester.pump();

      expect(opened, <String>[AppRoutes.servantReport]);
    });

    testWidgets('and the scheduling entry opens the schedule', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await pumpServant(tester, hubFor(UserRole.adminServant, opened: opened));

      await tester.tap(find.text('Schedule a reading'));
      await tester.pump();

      expect(opened, <String>[AppRoutes.servantSchedule]);
    });

    testWidgets('and the questions entry opens the editor', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await pumpServant(tester, hubFor(UserRole.adminServant, opened: opened));

      await tester.tap(find.text('Author questions'));
      await tester.pump();

      expect(opened, <String>[AppRoutes.servantQuestions]);
    });
  });

  group('the grant table', () {
    testWidgets('is the only thing that decides the entries', (
      WidgetTester tester,
    ) async {
      // **The same table, read twice.** The hub offers an entry when the role
      // grants its capability, and the grant table is `UserRole.grantsFor` —
      // the same one the navigation gate reads.
      for (final UserRole role in UserRole.values) {
        await pumpServant(tester, hubFor(role));
        for (final ServantHubEntry entry in ServantHubEntry.values) {
          final bool granted = UserRole.grantsFor(role)
              .contains(entry.capability);
          expect(
            find.text(entry.title(AppLocalizationsEn())),
            granted ? findsOneWidget : findsNothing,
            reason: '$role and ${entry.name}',
          );
        }
      }
    });
  });
}
