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
/// and the hub asks [UserRole.grantsFor] which of them this role has. An
/// `if (role == UserRole.adminServant)` ladder would be a **second** copy of
/// that policy, free to drift from the first, and the drift would be silent
/// in both directions — a viewer servant offered the scheduling screen, or an
/// admin servant not offered the report.
///
/// The gate reads the same table (`core/navigation/role_access.dart`'s
/// `allows` is `UserRole.grantsFor(role).contains(capability)`), so the screen
/// and the gate cannot disagree.
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
/// ## AND THE ROLE IS READ **ONCE**
///
/// [RoleAccess.role] is a plain read, and `role_access.dart`'s own hazard #2
/// says that a reader that must reason about one reader consistently has to
/// capture the role once: the seam guarantees liveness, not atomicity, and two
/// reads inside one decision can be handed two roles. So the role is captured
/// into a local and the grant table is read from **that**.
@RoutePage()
class ServantHomePage extends StatelessWidget {
  /// The hub.
  const ServantHomePage({super.key, this.roleAccess, this.onOpenRoute});

  /// The role seam, or `null` to resolve the app's own from the locator.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach
  /// the locator without configuring the whole graph, and this page is the one
  /// surface whose **whole content** depends on the role. `LoginPage`'s `bloc`
  /// is the same shape and the same reason.
  final RoleAccess? roleAccess;

  /// Where a tapped entry goes.
  ///
  /// `null` means "push it on the app's router", which is the production path.
  ///
  /// **A callback and not a mock router**, and the reason is that the portal's
  /// own routes are **not registered yet** — `app_router.dart` registers them
  /// with the portal's navigation task, and until then a router built in a
  /// test would answer a path it does not know. The value handed to the
  /// callback is the app's own `AppRoutes` constant, so the assertion is
  /// about a **real** path and not about a name somebody typed.
  final void Function(String route)? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final RoleAccess access = roleAccess ?? getIt<RoleAccess>();
    // **One read.** See the class doc.
    final UserRole role = access.role;
    final Set<UserCapability> grants = UserRole.grantsFor(role);
    final AppLocalizations strings = context.l10n;

    return NeuralScaffold(
      scrollable: true,
      child: SettingsGroup(
        label: strings.servantHubTitle,
        children: <Widget>[
          for (final ServantHubEntry entry in ServantHubEntry.values)
            if (grants.contains(entry.capability))
              SettingsTile(
                title: entry.title(strings),
                trailing: const _Chevron(),
                onTap: () => _open(context, entry.route),
              ),
        ],
      ),
    );
  }

  /// Opens [route], on the app's router or through the callback.
  void _open(BuildContext context, String route) {
    final void Function(String route)? open = onOpenRoute;
    if (open != null) {
      open(route);
      return;
    }
    context.router.pushPath(route);
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
