import 'dart:async';
import 'dart:io';

import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:evangelion/core/design_system/widgets/icon_action_button.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_home_page.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_harness.dart';
import '../servant_harness.dart';

/// The instant the hub's masthead reads its day from.
///
/// **A Wednesday**, so the English arm's assertion below has a word that is
/// not every other weekday — a test that asserted "Thursday" would pass
/// against a format that dropped the weekday entirely.
final DateTime _fixedToday = DateTime(2026, 10, 21);

/// The portal's hub — the sections this role has.
///
/// ## AND WHY THE ROLE IS **SUPPLIED** AND NOT READ FROM THE LOCATOR
///
/// The hub's whole content depends on the role, and a widget test cannot reach
/// the locator without configuring the whole graph. So the page takes its
/// [RoleAccess] as a parameter — `LoginPage`'s `bloc` is the same shape and the
/// same reason.
///
/// ## AND WHY THE NAVIGATION IS PROVED AGAINST THE **REAL** ROUTER
///
/// The hub used to take an `onOpenRoute` callback, and its own doc gave the
/// reason: *"the portal's own routes are **not registered yet**"*. That reason
/// expired with the portal's navigation task, so the callback is **gone** and
/// the production path — `context.router.pushPath` — is the only path there is.
///
/// A recorder would have proved the same thing about a **second** way of
/// navigating, which is the shape this repository keeps removing. So the
/// navigation claims below are executed against the app's own router, and the
/// route that lands is the route the **guard** accepted.
void main() {
  /// The hub, with the role fixed.
  Widget hubFor(UserRole role) =>
      ServantHomePage(roleAccess: LiveRoleAccess(() => role));

  /// The hub, with the role **and** the day fixed.
  ///
  /// The day is a seam for the same reason it is one on the report page: the
  /// masthead names it, so a test that asserts the name has to assert **a**
  /// name rather than today's.
  Widget hubAt(UserRole role) => ServantHomePage(
    roleAccess: LiveRoleAccess(() => role),
    today: () => _fixedToday,
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

  group('the masthead', () {
    testWidgets('names the reader\'s standing', (WidgetTester tester) async {
      await pumpServant(tester, hubAt(UserRole.adminServant));

      expect(find.text('Admin servant'), findsOneWidget);
    });

    testWidgets('and a viewer servant is told a different one', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubAt(UserRole.viewerServant));

      expect(find.text('Servant'), findsOneWidget);
      expect(find.text('Admin servant'), findsNothing);
    });

    testWidgets('and it names the day, in the reader\'s own language', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubAt(UserRole.adminServant));

      // **THE LOCALE'S **OWN** PATTERN**, measured on `intl` 0.20.3: the
      // English arm puts the month first and the Arabic arm puts the day
      // first, and the Arabic separator is '،' rather than ','.
      //
      // **This case is what pins the locale data.** `DateFormat` throws
      // `LocaleDataException` for a locale whose symbols have not been
      // loaded, and the symbols are loaded by Flutter's own
      // `GlobalMaterialLocalizations` — so a harness that stopped installing
      // the Material delegates would turn this line into a crash, and this is
      // the line that says so.
      expect(find.text('Wednesday, October 21'), findsOneWidget);

      await pumpServant(
        tester,
        hubAt(UserRole.adminServant),
        locale: const Locale('ar'),
      );

      expect(find.text('الأربعاء، ٢١ أكتوبر'), findsOneWidget);
    });
  });

  group('the sections', () {
    testWidgets('each carry one line saying what they are for', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubAt(UserRole.adminServant));

      // **A TITLE NAMES A SECTION AND THE LINE SAYS WHAT HAPPENS WHEN IT IS
      // OPENED.** "Author questions" is a fine name and tells a newcomer
      // nothing about whether they are meant to write the questions or have
      // them written.
      expect(find.text('Who has finished today\'s reading.'), findsOneWidget);
      expect(
        find.text('Choose the passage a cohort reads next.'),
        findsOneWidget,
      );
      expect(
        find.text('Write the question a reading is served with.'),
        findsOneWidget,
      );
      expect(
        find.text('Today\'s reading, the cohort board and your journey.'),
        findsOneWidget,
      );
    });

    testWidgets('and a viewer servant is offered only their own', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, hubAt(UserRole.viewerServant));

      expect(find.text('Who has finished today\'s reading.'), findsOneWidget);
      expect(
        find.text('Choose the passage a cohort reads next.'),
        findsNothing,
      );
      expect(
        find.text('Write the question a reading is served with.'),
        findsNothing,
      );
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

    test('and it is consulted in EXACTLY ONE PLACE in the whole app', () {
      // ## THE SHAPE OF THE DEFECT THIS HOLDS
      //
      // The hub used to read `UserRole.grantsFor(role)` **itself**, and the
      // navigation gate read the same table through the `RoleAccess` seam. That
      // is **two answers to one question** — "may this reader be offered this
      // screen?" — and the shape has a name in this repository: the "two
      // sources of truth for one value" defect that decisions 5 and 68 each
      // removed elsewhere, and the drift would have been **silent in both
      // directions**: a viewer servant offered the scheduling screen, or an
      // admin servant not offered the report, with every other test green.
      //
      // ## AND THE SCAN IS OVER **EXECUTABLE LINES** IN **EVERY** FILE
      //
      // * **Every file under `lib/`**, not the seam's own directory — the
      //   defect was never about where the second copy lived.
      // * **`UserRole.grantsFor(`**, the **qualified** call, so the enum's own
      //   *declaration* is not counted as a caller of itself. A scan for the
      //   bare name would report `user_role.dart` and the assertion would be
      //   about the wrong thing.
      // * **Comment lines are skipped**, because a doc comment naming the table
      //   is a reader being told why the seam exists, and `verify_purity.sh`'s
      //   Gate 1 is anchored to the directive keyword for exactly this reason.
      // * **Generated files are skipped**, for the same reason: a `.freezed.dart`
      //   or a `.gr.dart` is not a place a hand-written policy can hide, and
      //   counting them would make the assertion brittle for no gain.
      final List<String> callers = <String>[];

      for (final FileSystemEntity entity in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.freezed.dart')) continue;
        if (entity.path.endsWith('.gr.dart')) continue;
        if (entity.path.endsWith('.config.dart')) continue;

        final List<String> lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!line.contains('UserRole.grantsFor(')) continue;
          callers.add('${entity.path}:${i + 1}');
        }
      }

      expect(
        callers.map((String call) => call.split(':').first).toSet(),
        <String>{'lib/core/navigation/role_access.dart'},
        reason:
            'the grant table is consulted in exactly one place — the seam — and '
            'every other reader asks the seam. A second call site is the '
            '"two sources of truth for one value" shape, and it is silent in '
            'both directions.',
      );
      expect(
        callers.length,
        1,
        reason:
            'and it is consulted **once** there: `LiveRoleAccess.allowsRole`. A '
            'second call in the same file would be the seam holding a second '
            'answer to its own question.',
      );
    });
  });

  group('the navigation', () {
    /// The hub, in the app's **real** router, with the role fixed.
    ///
    /// The role seam is registered **first** and the same instance is handed to
    /// the router, so the guard's answer and the hub's answer come from one
    /// seam — which is the property the whole portal rests on.
    Future<AppRouter> pumpHub(WidgetTester tester, UserRole role) async {
      final RoleAccess access = registerTestRoleAccess(
        LiveRoleAccess(() => role),
      );
      final AppRouter router = AppRouter(
        FakeAuthStatus(),
        ManualAuthChanges(),
        access,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(routerHost(router));
      unawaited(router.pushPath<void>(AppRoutes.servant));
      await pumpUntilFound(tester, find.byType(ServantHomePage));

      return router;
    }

    testWidgets('the report entry opens the report', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpHub(tester, UserRole.viewerServant);

      await tester.tap(find.text('Daily report'));
      await pumpUntilFound(tester, find.text('Cohort'));

      expect(router.currentPath, AppRoutes.servantReport);
    });

    testWidgets('the scheduling entry opens the schedule', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpHub(tester, UserRole.adminServant);

      await tester.tap(find.text('Schedule a reading'));
      await pumpUntilFound(tester, find.text('Cohort ids'));

      expect(router.currentPath, AppRoutes.servantSchedule);
    });

    testWidgets('the questions entry opens the editor', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpHub(tester, UserRole.adminServant);

      await tester.tap(find.text('Author questions'));
      await pumpUntilFound(tester, find.text('Reading id'));

      expect(router.currentPath, AppRoutes.servantQuestions);
    });

    testWidgets('and the reader\'s own shell opens `/`', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpHub(tester, UserRole.adminServant);

      await tester.tap(find.text('Read as a reader'));
      // **A bounded loop on the PATH, not on a finder.** The dock shell is the
      // app's root route, so "the reader's own shell is on screen" is a claim
      // about the **path** — and the hub's own title is still painted while the
      // push animates, so a finder on the hub would match on the first frame
      // and prove nothing.
      for (int frame = 0; frame < 12; frame++) {
        if (router.currentPath == AppRoutes.home) break;
        await tester.pump(EvaMotion.screen);
      }

      expect(router.currentPath, AppRoutes.home);
    });

    testWidgets('and the report\'s back control returns to the portal', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS CASE IS HERE AT ALL
      //
      // Because the portal's three sub-routes are **pushed**, and
      // `NeuralScaffold` has no app bar and no leading control of its own —
      // its own doc says so: *"No `appBar`, no `floatingActionButton`, no
      // `drawer`."* So before the portal's screens grew an app bar, a servant
      // who opened the daily report on the **Linux desktop build** — the only
      // device this app is currently runnable on — had **no visible way back
      // to the portal**.
      //
      // `CommunionAppBar`'s own doc records the same finding for `/communion`
      // and the same reason the control has to exist there.
      final AppRouter router = await pumpHub(tester, UserRole.viewerServant);

      await tester.tap(find.text('Daily report'));
      await pumpUntilFound(tester, find.text('Cohort'));
      expect(router.currentPath, AppRoutes.servantReport);

      await tester.tap(find.byType(IconActionButton));
      for (int frame = 0; frame < 12; frame++) {
        if (router.currentPath == AppRoutes.servant) break;
        await tester.pump(EvaMotion.screen);
      }

      expect(router.currentPath, AppRoutes.servant);
    });
  });
}
