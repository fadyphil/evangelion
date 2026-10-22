import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:evangelion/features/servant/presentation/servant_l10n.dart';
import 'package:evangelion/features/servant/presentation/widgets/servant_hub_card.dart';
import 'package:evangelion/features/servant/presentation/widgets/servant_hub_masthead.dart';
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
/// read `UserRole.grantsFor(role)` directly.** Two answers to one question —
/// the hub's and the gate's — is the "two sources of truth for one value" shape
/// decisions 5 and 68 each removed, and it would have put the portal's hub and
/// the portal's gate on two different answers to *"may this reader be offered
/// this screen?"*. `RoleAccess.allowsRole` exists for exactly this: the caller
/// captures the role **once** and still asks **the seam** for the grant, so
/// there is one answer path.
///
/// ## AND THE ENUM NOW ALSO NAMES **HOW EACH SECTION IS DRAWN**
///
/// The third fact about a section — the treatment it wears on the hub — lives
/// here beside the other two, and **not** in the page's build. The page used to
/// draw every section the same way, and a page whose structure is a column of
/// same-shaped rows is a template rather than a design; the treatments are
/// declared once, next to the sections they belong to, so a new section
/// cannot be added without saying how it looks.
enum ServantHubEntry {
  /// The cohort's roster for one day. **Every servant role.**
  report(
    UserCapability.viewServantReport,
    AppRoutes.servantReport,
    ServantHubCardStyle.hero,
    Icons.groups_outlined,
  ),

  /// Choosing the passage a cohort reads next. **An admin servant.**
  schedule(
    UserCapability.scheduleReading,
    AppRoutes.servantSchedule,
    ServantHubCardStyle.duty,
    Icons.menu_book_outlined,
  ),

  /// Writing or drafting a reading's questions. **An admin servant.**
  questions(
    UserCapability.manageQuestions,
    AppRoutes.servantQuestions,
    ServantHubCardStyle.duty,
    Icons.quiz_outlined,
  ),

  /// The reader's own shell. **Every role**, because a servant is also a
  /// reader — the grant table's first three capabilities are every role's,
  /// and this entry is the admin-can-use-the-kids'-app half of the portal.
  reader(
    UserCapability.readOwnReading,
    AppRoutes.home,
    ServantHubCardStyle.exit,
    Icons.auto_stories_outlined,
  );

  const ServantHubEntry(this.capability, this.route, this.style, this.icon);

  /// The capability a role needs for this entry to be offered.
  final UserCapability capability;

  /// The path this entry opens.
  final String route;

  /// How this entry is drawn on the hub.
  final ServantHubCardStyle style;

  /// The mark that stands for this entry.
  ///
  /// **Material's outlined set, and the same weight throughout** — every glyph
  /// on this screen is an `Icons.*_outlined` at the same size, so the screen
  /// has one icon language rather than a mixture. The alternative — the
  /// filled set — was refused because the app's own surfaces use outlined
  /// glyphs (`Icons.group_off` on the report's empty state,
  /// `Icons.emoji_events_outlined` on the journey's medals), and a screen whose
  /// marks are heavier than the rest of the app's reads as louder than it is.
  final IconData icon;

  /// The entry's name, in the reader's own language.
  String title(AppLocalizations strings) => switch (this) {
    ServantHubEntry.report => strings.servantHubReportTitle,
    ServantHubEntry.schedule => strings.servantHubScheduleTitle,
    ServantHubEntry.questions => strings.servantHubQuestionsTitle,
    ServantHubEntry.reader => strings.servantHubReaderTitle,
  };

  /// One line saying what the entry is for.
  ///
  /// **The line a reader needs and the title does not carry.** A title names a
  /// section; the line says what happens when it is opened, which is the one
  /// thing a first-time servant cannot guess from a name — "Author questions"
  /// is a fine name and tells a newcomer nothing about whether they are meant
  /// to write them or have them written.
  ///
  /// The alternative — a line that repeats the title in other words — was
  /// refused as the shape of a placeholder.
  String blurb(AppLocalizations strings) => switch (this) {
    ServantHubEntry.report => strings.servantHubReportBlurb,
    ServantHubEntry.schedule => strings.servantHubScheduleBlurb,
    ServantHubEntry.questions => strings.servantHubQuestionsBlurb,
    ServantHubEntry.reader => strings.servantHubReaderBlurb,
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
///
/// ## AND THE BODY IS **COMPOSED**, NOT LISTED
///
/// The first version of this page was four `SettingsTile`s inside a
/// `SettingsGroup` — which is to say, **the Settings screen's own components**,
/// in the Settings screen's own arrangement. It was a list of settings rows
/// wearing a portal's clothes: no identity, no hierarchy, and nothing that
/// said which role was looking at it or which day it was.
///
/// The body is now composed of three things, in the order a servant's day
/// runs:
///
/// 1. the **masthead** — where the reader is, who they are, and which day it
///    is;
/// 2. the **hero** — the day's report, the one section every servant has and
///    the one they open every day;
/// 3. the **duties** — the two sections an admin alone is offered, under a
///    heading that says whose they are;
/// 4. the **exit** — the reader's own app, which is not a section of this
///    portal at all and is therefore drawn as a flat row rather than a panel.
@RoutePage()
class ServantHomePage extends StatelessWidget {
  /// The hub.
  const ServantHomePage({super.key, this.roleAccess, this.today});

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

  /// The wall clock the masthead's day is read from, or `null` for the real
  /// one.
  ///
  /// ## WHY A PAGE THAT HAS NO CLOCK DEPENDENCY **NEEDS** A CLOCK
  ///
  /// The masthead names the day, so the screen's own rendering depends on the
  /// day it is rendered on. That was fine while the screen had no golden — a
  /// widget test asserts the *shape* of what is on screen, and today's date is
  /// a shape.
  ///
  /// **A golden is not a shape: it is a picture.** A picture of
  /// `2026-10-22` is a picture that fails on `2026-10-23`, and a golden that
  /// fails every morning is a golden nobody keeps.
  ///
  /// So the clock is a **seam**, exactly as `ServantReportPage.today` is —
  /// the same shape, the same reason, and the same precedent in this
  /// repository.
  ///
  /// **AND THE REAL ONE IS STILL THE DEFAULT.** `null` means `DateTime.now`, so
  /// production is unchanged, and the golden passes a fixed instant.
  final DateTime Function()? today;

  /// The gap above each of the hub's three groups.
  ///
  /// **One number for all three, and that is the point**: the groups on this
  /// screen are peers, and a screen whose groups are spaced unevenly reads as
  /// though the tight ones matter less. The gap *inside* a group is smaller —
  /// 12 — and that difference is what tells a reader which things belong
  /// together.
  ///
  /// **Written, not transcribed**: `eva/redesign.html` draws no servant portal
  /// and therefore has no hub to measure. `24` is [EvaSpacing.xxl], the
  /// design system's "between sibling cards", and the masthead and the hero
  /// are two blocks of a screen rather than two cards.
  static const double groupGap = EvaSpacing.xxl;

  /// The gap between two duties.
  static const double dutyGap = EvaSpacing.md;

  /// The air under the last thing on the screen.
  static const double bottomGap = EvaSpacing.xxl;

  @override
  Widget build(BuildContext context) {
    final RoleAccess access = roleAccess ?? getIt<RoleAccess>();
    // **One read.** See the class doc.
    final UserRole role = access.role;
    final AppLocalizations strings = context.l10n;

    // **The entries this role has, in the enum's own order.** The order is the
    // declaration order, and the declaration order *is* the order a servant's
    // day runs: the report first, the two admin duties next, the reader's own
    // app last.
    final List<ServantHubEntry> granted = <ServantHubEntry>[
      for (final ServantHubEntry entry in ServantHubEntry.values)
        // **The seam, not the table.** See the enum's doc.
        if (access.allowsRole(role, entry.capability)) entry,
    ];

    return NeuralScaffold(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // **THE AIR ABOVE THE MASTHEAD.** `NeuralScaffold` applies the safe
          // area to the content, so on a device with a status bar the
          // masthead already starts below it; on a surface with no bar — a
          // desktop window, a golden — it would start flush against the
          // window's edge, and a heading that touches the top of a screen
          // reads as cropped rather than as a heading.
          const SizedBox(height: EvaSpacing.md),
          ServantHubMasthead(
            title: strings.servantHubTitle,
            roleLabel: switch (role) {
              UserRole.adminServant => strings.servantHubRoleAdmin,
              UserRole.viewerServant => strings.servantHubRoleViewer,
              // **A `kid` cannot reach this screen** — the route's `RoleGuard`
              // refuses it — so this arm is a state the widget can be built in
              // and the app can never reach. It is named rather than left to a
              // default, because a default would be a second reader of the
              // role table, and this file's whole argument is that the role is
              // read once and asked about through the seam.
              UserRole.kid => strings.servantHubRoleReader,
            },
            dayLabel: servantDayLabel(context, (today ?? DateTime.now)()),
          ),
          // **THE COMPOSITION IS DRIVEN BY THE **STYLE ENUM** — and that is
          // the whole of how a treatment cannot be forgotten.
          //
          // `ServantHubCardStyle.values` is the hub's order (hero, duties,
          // exit) and its members are the hub's three groups, so a **new
          // treatment cannot be added without this loop placing it**, and a
          // new group cannot be added without the enum saying how it is
          // drawn.
          //
          // The earlier version of this page filtered the granted entries
          // three times — once per group — and rendered the three lists. That
          // was a **fourth** place the composition lived, and a fourth
          // treatment would have been added to the enum, drawn by the card's
          // own exhaustive switch, and **silently dropped from the page**.
          for (final ServantHubCardStyle style in ServantHubCardStyle.values)
            ..._group(context, style, granted, strings),
          const SizedBox(height: bottomGap),
        ],
      ),
    );
  }

  /// The hub's group for [style], and the entries that wear it.
  ///
  /// **The switch is EXHAUSTIVE, and that is the point.** A new
  /// [ServantHubCardStyle] is a compile error here until the page says what
  /// chrome the new group gets — which is the answer to "where does a new
  /// treatment go", asked of the one file that places things.
  List<Widget> _group(
    BuildContext context,
    ServantHubCardStyle style,
    List<ServantHubEntry> granted,
    AppLocalizations strings,
  ) {
    final List<ServantHubEntry> entries = <ServantHubEntry>[
      for (final ServantHubEntry entry in granted)
        if (entry.style == style) entry,
    ];
    if (entries.isEmpty) return const <Widget>[];

    return switch (style) {
      ServantHubCardStyle.hero => <Widget>[
        const SizedBox(height: groupGap),
        for (final ServantHubEntry entry in entries)
          _card(context, entry, strings),
      ],
      ServantHubCardStyle.duty => <Widget>[
        const SizedBox(height: groupGap),
        // **THE HEADING THAT SAYS WHOSE THE DUTIES ARE.** A viewer servant
        // sees one section and an admin servant sees three, and the two
        // screens would otherwise differ only in *how many cards there are* —
        // which a reader cannot tell from the absence of a card. The heading
        // says it.
        EvaSectionHeader(label: strings.servantHubDutiesLabel),
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: dutyGap),
          _card(context, entries[i], strings),
        ],
      ],
      ServantHubCardStyle.exit => <Widget>[
        const SizedBox(height: groupGap),
        // **A RULE, AND NOT A CARD.** The exit leaves the portal; it is not
        // one of the portal's sections, and drawing it like one would say it
        // is.
        const HairlineDivider(),
        for (final ServantHubEntry entry in entries)
          _card(context, entry, strings),
      ],
    };
  }

  /// The card for [entry].
  Widget _card(
    BuildContext context,
    ServantHubEntry entry,
    AppLocalizations strings,
  ) => ServantHubCard(
    style: entry.style,
    title: entry.title(strings),
    description: entry.blurb(strings),
    icon: entry.icon,
    onTap: () => _open(context, entry.route),
  );

  /// Opens [route] on the app's router.
  ///
  /// ## WHY THERE IS **NO CALLBACK** HERE ANYMORE
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
