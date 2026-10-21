import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The four sections the portal offers.
///
/// ## WHY IT IS AN **ENUM** AND NOT A LIST OF WIDGETS
///
/// Because the **table** is the grant table and the enum is the only place the
/// two meet: each entry names the capability it needs and the path it opens,
/// and the hub asks **the seam** which of them this role has. An
/// `if (role == UserRole.adminServant)` ladder would be a **second** copy of
/// that policy, free to drift from the first, and the drift would be silent
/// in both directions — a viewer servant offered the scheduling screen, or an
/// admin servant not offered the report.
///
/// ## AND THE GRANT IS ASKED OF THE **SEAM**, NOT OF THE TABLE
///
/// The gate reads the same seam (`core/navigation/role_access.dart`'s
/// `allowsRole` is `UserRole.grantsFor(role).contains(capability)`, and
/// `allows` delegates to it), so the screen and the gate cannot disagree.
///
/// **And that is a deliberate change from the first version of this file, which
/// read `UserRole.grantsFor(role)` directly.** Two answers to one question — the
/// hub's and the gate's — is the "two sources of truth for one value" shape
/// decisions 5 and 68 each removed, and it would have put the portal's hub and
/// the portal's gate on two different answers to *"may this reader be offered
/// this screen?"*. `RoleAccess.allowsRole` exists for exactly this: the caller
/// captures the role **once** and still asks **the seam** for the grant, so
/// there is one answer path.
enum ServantHubEntry {
  /// The cohort's roster for one day. **Every servant role.**
  report(UserCapability.viewServantReport, AppRoutes.servantReport),

  /// Choosing the passage a cohort reads next. **An admin servant.**
  schedule(UserCapability.scheduleReading, AppRoutes.servantSchedule),

  /// Writing or drafting a reading's questions. **An admin servant.**
  questions(UserCapability.manageQuestions, AppRoutes.servantQuestions),

  /// The reader's own shell. **Every role**, because a servant is also a
  /// reader — the grant table's first three capabilities are every role's,
  /// and this entry is the admin-can-use-the-kids'-app half of the portal.
  reader(UserCapability.readOwnReading, AppRoutes.home);

  const ServantHubEntry(this.capability, this.route);

  /// The capability a role needs for this entry to be offered.
  final UserCapability capability;

  /// The path this entry opens.
  final String route;

  /// The entry's name, in the reader's own language.
  String title(AppLocalizations strings) => switch (this) {
    ServantHubEntry.report => strings.servantHubReportTitle,
    ServantHubEntry.schedule => strings.servantHubScheduleTitle,
    ServantHubEntry.questions => strings.servantHubQuestionsTitle,
    ServantHubEntry.reader => strings.servantHubReaderTitle,
  };
}

/// The servant portal's hub: the sections this role has.
///
/// ## AND IT IS A **HUB PAGE**, NOT A TAB SHELL
///
/// A `viewer_servant` has exactly **one** section — the daily report — and a
/// tab bar holding one tab is chrome for nothing. So the body is a list of the
/// entries this role has, and the three sub-routes are root-level absolute
/// paths rather than children of this one (`app_routes.dart` says why).
///
/// ## AND THE ROLE IS READ **ONCE**, AND THE GRANT IS ASKED OF THE **SEAM**
///
/// [RoleAccess.role] is a plain read, and `role_access.dart`'s own hazard #2
/// says that a reader that must reason about one reader consistently has to
/// capture the role once: the seam guarantees liveness, not atomicity, and two
/// reads inside one decision can be handed two roles. So the role is captured
/// into a local — and the grant for **that** role is asked of the **seam**,
/// through [RoleAccess.allowsRole], rather than read out of the grant table.
///
/// **The first version of this file read `UserRole.grantsFor(role)` directly**,
/// which made the hub a **second** holder of the policy beside the gate — the
/// "two sources of truth for one value" shape decisions 5 and 68 each removed,
/// and the drift would have been silent in both directions. The seam's own doc
/// names the same hazard from the other side: *"the caller would hold its own
/// copy of the grant table while the seam holds another, and the two could
/// drift"*. `servant_home_page_test.dart` holds the property by **counting the
/// call sites of the table** in `lib/`.
@RoutePage()
class ServantHomePage extends StatelessWidget {
  /// The hub.
  const ServantHomePage({super.key, this.roleAccess});

  /// The role seam, or `null` to resolve the app's own from the locator.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach
  /// the locator without configuring the whole graph, and this page is the one
  /// surface whose **whole content** depends on the role. `LoginPage`'s `bloc`
  /// is the same shape and the same reason.
  ///
  /// **And it is the SAME registration the navigation gate reads.** The router
  /// is handed `getIt<RoleAccess>()` — the one registration in the **pure** half
  /// (`auth_module.dart`) — and the hub resolves that same instance from the
  /// locator, so the guard's answer and the hub's answer come from one seam.
  final RoleAccess? roleAccess;

  @override
  Widget build(BuildContext context) {
    final RoleAccess access = roleAccess ?? getIt<RoleAccess>();
    // **One read.** See the class doc.
    final UserRole role = access.role;
    final AppLocalizations strings = context.l10n;

    return NeuralScaffold(
      scrollable: true,
      child: SettingsGroup(
        label: strings.servantHubTitle,
        children: <Widget>[
          for (final ServantHubEntry entry in ServantHubEntry.values)
            // **The seam, not the table.** See the enum's doc.
            if (access.allowsRole(role, entry.capability))
              SettingsTile(
                title: entry.title(strings),
                trailing: const _Chevron(),
                onTap: () => _open(context, entry.route),
              ),
        ],
      ),
    );
  }

  /// Opens [route] on the app's router.
  ///
  /// ## WHY THERE IS **NO CALLBACK** HERE ANY MORE
  ///
  /// The first version of this page took a `void Function(String route)?
  /// onOpenRoute` and used it **instead of** the router, and its own doc gave
  /// the reason: *"the portal's own routes are **not registered yet** — a router
  /// built in a test would answer a path it does not know."*
  ///
  /// **That reason expired with the portal's navigation task**, and the four
  /// routes are registered now — `/servant`, `/servant/report`,
  /// `/servant/schedule` and `/servant/questions` are in `app_router.dart`'s
  /// table, and the orphan gate reads the hub as a **root** because of it.
  ///
  /// So the callback was removed rather than re-documented, and the production
  /// path is now the **only** path. A page that can be driven two ways is a
  /// page whose behaviour depends on how it was constructed, and the second way
  /// was a test seam standing in for a router that now exists. The navigation
  /// itself is the router's business, and `servant_home_page_test.dart` proves
  /// it against the **real** router rather than against a recorder.
  void _open(BuildContext context, String route) {
    context.router.pushPath<void>(route);
  }
}

/// The trailing glyph of a row that opens something.
///
/// ## AND IT **FLIPS** on the Arabic arm
///
/// Material's chevrons do not flip by themselves, and a chevron that points the
/// wrong way in a right-to-left screen is the same class of defect as an
/// Arabic run drawn in a Latin face: the layout assumes a direction it does
/// not have. So the glyph is chosen from the ambient direction.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? Icons.chevron_left : Icons.chevron_right,
      size: EvaSpacing.lg,
      color: colors.ink3,
    );
  }
}
