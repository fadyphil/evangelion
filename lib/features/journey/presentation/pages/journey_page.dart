import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/journey/domain/journey_rings.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';
import 'package:evangelion/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:evangelion/features/journey/presentation/journey_l10n.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_account_rows.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_app_bar.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_hero_number.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_identity.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_medals_strip.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_orb.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_rings_row.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_section_labels.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_sky_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/journey` — the reader's own journey.
///
/// The **profile**, which ADR-0001 cut for want of an endpoint and ADR-0022
/// restored; the redesign calls it "Journey" (`eva/redesign.html:933`) and makes
/// it a **dock tab** (`:707`). **Phase 6 built the dock**, so this screen is
/// **the third tab** — reached from the dock's fifth slot, and from the
/// journey's own app-bar controls.
///
/// ## TWO DIVERGENCES THE REVIEW ASKED FOR AND THIS PAGE CARRIES
///
/// **THE APP BAR SCROLLS WITH THE COLUMN, AND THE PROTOTYPE'S DOES NOT.** The
/// prototype's `.appbar` sits **outside** its `.scroll` (`:576-583` is a sibling
/// of `:584`'s scroll wrapper), so its title and its two buttons are pinned
/// while the column moves under them. This page's app bar is **inside** the
/// scroll, because the scaffold owns the scroll and the app bar is a child of
/// the column. **This is a Phase-6 question, not a Phase-5.6 one** — the dock
/// changes what "pinned" means, and a fixed bar above a dock is a different
/// composition — so it is recorded here rather than solved here.
///
/// **AND THE RE-READ SHOWS THE LOADING ARM.** [JourneyCubit.load] emits
/// `loading` before it asks, so a reader coming back from the board sees the
/// spinner for the length of the reads instead of the column they left. The
/// journey's own retry control behaves the same way, so the two agree; and
/// keeping the stale figures on screen while the re-read is in flight would
/// mean the screen shows two answers at once. It is a visible cost of the
/// re-read and it is named here so nobody discovers it as a surprise.
///
/// ## THE COLUMN, IN THE PROTOTYPE'S ORDER
///
/// `eva/redesign.html:584-609`:
///
/// | the prototype's element | the widget that draws it |
/// | --- | --- |
/// | `.jorb` (`:586`) | [JourneyOrb] — the seal at **74** |
/// | `.jname` (`:587`) | [JourneyReaderName] — the reader's own name |
/// | `.jrole` (`:588`) | [JourneyRoleLine] — the transcribed role line |
/// | `.hero-num` (`:589`) + the sub-line (`:590`) | [JourneyHeroNumber] — the real streak and the copy |
/// | `.rings` (`:591-595`) | [JourneyRingsRow] — three derived rings |
/// | the sky line (`:596`) | [JourneySkyLine] — the lit stars and the completed books |
/// | `.car-label` (`:597`) + `.medals` (`:598-603`) | [JourneyMedalsLabel] + [JourneyMedalsStrip] |
/// | `.car-label` (`:604`) | [JourneyAccountLabel] |
/// | the four `.srow`s (`:605-608`) | [JourneyAccountRows] |
///
/// ## AND WHAT IS **REAL** AND WHAT IS THE PROTOTYPE'S
///
/// | the figure | here |
/// | --- | --- |
/// | the name (`:587`) | the reader's own session |
/// | the hero number (`:589`) | `GET /streak/summary`'s `current_streak` |
/// | the rings (`:592-594`) | derived from `GET /streak`'s history |
/// | the lit stars (`:596`) | `SkyRepository.count()` |
/// | the completed books (`:596`) | a **proxy**, derived from the history |
/// | the medals (`:597-603`) | a **stub** behind a port — ADR-0022's fiction |
/// | the role line (`:588`) | transcribed copy, and the "level 7" is a literal |
///
/// ## AND THE COLUMN'S OWN SPACING IS THE PROTOTYPE'S
///
/// `:157` is `.scroll{flex:1;overflow-y:auto;scrollbar-width:none;padding:6px
/// 14px 118px}`, and the three numbers in it are all this page's:
///
/// | the prototype's | where it lands here |
/// | --- | --- |
/// | the scroll's **6px** top padding | [kScrollTopPadding] — the space between the app bar and the orb |
/// | the scroll's **14px** gutter | the column's own horizontal padding, below |
/// | the scroll's **118px** bottom padding | [kBottomClearance], with the medals strip's own 12 |
///
/// The **orb's** own `margin:10px auto 12px` (`:392`) and the **rings row's**
/// own `margin:20px 0 8px` (`:401`) belong to the widgets that draw those
/// elements — `JourneyOrb` and `JourneyRingsRow` — for the reason
/// `JourneyRoleLine`'s doc gives.
@RoutePage()
class JourneyPage extends StatelessWidget {
  /// Creates the journey page.
  ///
  /// [cubit] allows constructor injection for testing without configuring the
  /// locator.
  const JourneyPage({super.key, this.cubit});

  /// The cubit to render, or null to resolve from DI.
  final JourneyCubit? cubit;

  /// The scroll's own top padding — `eva/redesign.html:157`'s `6px`.
  ///
  /// **The prototype's own space between the app bar and the first thing in
  /// the column.** `:157` is `padding:6px 14px 118px`, and the 6 is the half
  /// of the prototype's 16px of space above the orb that the orb's own
  /// `margin:10px auto 12px` (`:392`) does not account for.
  static const double kScrollTopPadding = 6;

  /// The scroll's own horizontal gutter — `eva/redesign.html:157`'s `14px`.
  static const double kScrollGutter = 14;

  /// What is under the column: the medals strip's own `12px` (`:410`) and the
  /// scroll's `118px` (`:157`), which is the prototype's clearance for its
  /// dock.
  ///
  /// **The dock exists now** — Phase 6 built it, and it is 78px tall
  /// (`eva/redesign.html:208`) — and the clearance is still **118**, because
  /// the prototype's number is the prototype's number: it is the *scroll's
  /// padding*, not the dock's height. The dock is 78 of those 118; the other
  /// 40 is the space the design leaves between the last row and the dock's
  /// top edge. `/` ships the same number for the same reason —
  /// `HomePage.kBottomClearance`.
  static const double kBottomClearance = 130;

  @override
  Widget build(BuildContext context) {
    final JourneyCubit? passed = cubit;
    final JourneyCubit resolved = passed ?? getIt<JourneyCubit>();

    return BlocProvider<JourneyCubit>.value(
      value: resolved,
      child: const _JourneyBody(),
    );
  }
}

class _JourneyBody extends StatefulWidget {
  const _JourneyBody();

  @override
  State<_JourneyBody> createState() => _JourneyBodyState();
}

class _JourneyBodyState extends State<_JourneyBody> implements AutoRouteAware {
  /// Whether the reads have been asked for.
  ///
  /// **`didChangeDependencies` and not `initState`**, for `CommunionPage`'s
  /// reason: the cubit is read from the context, and the context is not
  /// readable from `initState`.
  bool _loaded = false;

  /// The observer this state subscribed to, so [dispose] can unsubscribe and a
  /// replaced observer cannot go on holding a dead `State`.
  ///
  /// **The same field `/` keeps**, for the same reason — see
  /// `home_page.dart`'s `_HomeBodyState`.
  AutoRouteObserver? _observer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToRoute();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  /// Subscribes to the router's [AutoRouteObserver], if this page is under one.
  ///
  /// **The mechanism `/` uses**, copied rather than invented: the lookup is
  /// `findAncestorWidgetOfExactType<RouterScope>()`, which returns `null`
  /// instead of throwing when there is no router — and "no router, no
  /// re-entry" is the right behaviour for a page mounted bare in a widget
  /// test. `home_page.dart`'s doc says why the `AutoRouteAwareStateMixin`
  /// spelling cannot be used here.
  void _subscribeToRoute() {
    final RouterScope? scope = context
        .findAncestorWidgetOfExactType<RouterScope>();
    if (scope == null) {
      return;
    }
    final AutoRouteObserver? observer = scope
        .firstObserverOfType<AutoRouteObserver>();
    if (observer == null || identical(observer, _observer)) {
      return;
    }
    _observer?.unsubscribe(this);
    _observer = observer;
    observer.subscribe(this, _watchedRouteData);
  }

  /// The route data this page subscribes under.
  ///
  /// **The SHELL's, not this tab's** — the same rule `/` uses, and for the same
  /// reason: the journey is a **tab** inside the dock shell, and a tab is never
  /// popped, so its own route data would never produce a `didPopNext`. The
  /// shell is popped when the screen pushed over it is popped, and that is the
  /// re-entry this screen re-reads for.
  ///
  /// A bare tree has no shell, and there this page's own route data is the
  /// right answer.
  RouteData<dynamic> get _watchedRouteData =>
      TabsRouterScope.of(context)?.controller.routeData ?? context.routeData;

  /// Reads everything the screen draws.
  ///
  /// **Fire-and-forget, and `unawaited` says so** — AGENT_CONTEXT §4's rule
  /// against a bare dropped future. The reads are the cubit's own; this page
  /// watches the state and not the future.
  void _load() {
    unawaited(context.read<JourneyCubit>().load());
  }

  /// Switches to the board tab.
  ///
  /// **The tabs router, looked up without throwing.** `TabsRouterScope.of`
  /// returns `null` when there is no tabs router above — a page mounted bare in
  /// a widget test — and `AutoTabsRouter.of` **asserts** in that case, which
  /// would take the whole tree down on a tap. So the nullable lookup is the
  /// one, and "there is no dock, so there is no board tab" is the honest
  /// answer rather than a crash.
  ///
  /// The board is reachable from the dock in the app in any case (slot 3), so
  /// this is a convenience entrance rather than the only one.
  void _openBoard(BuildContext context) {
    TabsRouterScope.of(context)?.controller.setActiveIndex(DockTabs.communion);
  }

  /// The route underneath was popped and this one is showing again.
  ///
  /// ## THE RE-ENTRY TRIGGER, AND WHY THE JOURNEY HAS ONE
  ///
  /// `/` re-reads on re-entry for exactly this reason, and the reason is
  /// written down in `home_page.dart`: "the reader finishes a reflection on
  /// `/quiz`, comes back, and the chip and the cards still show first-landing
  /// values."
  ///
  /// **The journey's own destinations are `/communion` and `/settings`**, and
  /// neither of them changes any of the four figures this screen draws — the
  /// streak, the rings, the lit stars and the medals are the reader's own, and
  /// the board does not move them. **So the journey's own re-entry is
  /// harmless today.** It is re-read anyway, and the reason is that
  /// "harmless today" is a property of two screens that this screen does not
  /// own: the moment either of them can reach a reading, the figures this
  /// screen shows can change while the reader is away, and the reader would
  /// be told the old ones.
  ///
  /// **The mechanism is the house's, and it is not invented.** `AppRouter`
  /// installs an `AutoRouteObserver` (`app_router.dart`'s doc says what
  /// happens without one), and `/` subscribes to it through
  /// [AutoRouteAware]'s [didPopNext]. `/communion` does **not** re-read on
  /// re-entry — it loads once per `State` — and the board is a screen whose
  /// data is the cohort's, which the reader cannot change by looking at it.
  ///
  /// **And the re-read shows the loading arm**, because `JourneyCubit.load`
  /// emits `loading` before it asks — the same thing the retry control does,
  /// and the reader sees the figures arrive rather than silently changing
  /// under their eyes.
  @override
  void didPopNext() {
    _load();
  }

  // --- the rest of `AutoRouteAware`, and why each is empty -------------------
  //
  // auto_route 11 declares these **without** default bodies, so
  // `implements AutoRouteAware` requires all six. Only [didPopNext] means
  // anything to this page:
  //
  // | callback | what it means | why it is empty here |
  // | --- | --- | --- |
  // | `didPush` / `didPushNext` | the journey arrived, then was covered | arriving is [didChangeDependencies]'s job and covering is not an event this screen reacts to |
  // | `didPop` | *this* route was popped off | the page is going away; [dispose] runs and the subscription is dropped |
  // | `didInitTabRoute` / `didChangeTabRoute` | a tab router changed tab | there is no `AutoTabsRouter` in the app's eight screens |
  //
  // Written out rather than left unimplemented, for `home_page.dart`'s reason:
  // an unimplemented one is a compile error today and a silent no-op the
  // moment auto_route gives it a body.

  @override
  void didPush() {}

  @override
  void didPushNext() {}

  @override
  void didPop() {}

  @override
  void didInitTabRoute(TabPageRoute? previousRoute) {}

  @override
  void didChangeTabRoute(TabPageRoute previousRoute) {}

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JourneyCubit, JourneyState>(
      builder: (BuildContext context, JourneyState state) {
        return NeuralScaffold(
          // **The profile's own orbs**, and they were waiting for this screen.
          // `OrbGroup.profile` has sat in the design system since Phase 2 —
          // cut-and-kept-for-index-alignment, because the profile was cut then.
          // The journey IS the profile, and it is the one group whose first orb
          // cycles backwards (ds.tsx:106).
          variant: NeuralVariant.journey,
          scrollable: true,
          // **The prototype's `.scroll` owns the gutter** — `:157` is `6px 14px
          // 118px` — and the scaffold's own padding would be a second one.
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              JourneyAppBar(
                // **The board is a TAB, so this switches tabs — and it must not
                // push a path.** The board is the shell's second child, so a
                // `pushPath('/communion')` would push a **second shell** with
                // the board tab active, and the app would carry two docks.
                //
                // The prototype does the same thing with a different mechanism:
                // `el('rowBoard').onclick = () => { boardEntry = 'push';
                // push('board'); }` (`:1284`) pushes the board over the journey
                // — and its own dock slot does `tab('board')` (`:1280`). The
                // client has one board and one place to show it, so both
                // entrances are the tab switch.
                onOpenBoard: () => _openBoard(context),
                onOpenSettings: () =>
                    context.router.pushPath(AppRoutes.settings),
              ),
              Padding(
                // **The scroll's own padding** — `:157`'s `6px 14px 118px`,
                // with the 118 below as [JourneyPage.kBottomClearance]. The 6
                // is the space between the app bar and the orb, and the 14 is
                // the gutter.
                padding: const EdgeInsets.fromLTRB(
                  JourneyPage.kScrollGutter,
                  JourneyPage.kScrollTopPadding,
                  JourneyPage.kScrollGutter,
                  0,
                ),
                child: _content(context, state),
              ),
              // **The bottom clearance, and it is the dock's.** `:157`'s 118px is
              // the space the redesign's dock occupies, and the dock is here.
              // `/` already ships the same deal — `HomePage.kBottomClearance` —
              // and the divergence is recorded there; this is the same number
              // for the same reason. See [JourneyPage.kBottomClearance].
              const SizedBox(height: JourneyPage.kBottomClearance),
            ],
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    JourneyState state,
  ) => switch (state.status) {
    JourneyStatus.failed => ErrorView(
      message: state.failure?.message ?? '',
      onRetry: () => context.read<JourneyCubit>().retry(),
      // The journey's **own** retry key, and not `/reading`'s: `homeRetry`,
      // `quizRetry`, `readingRetry`, `settingsRetry` and `leaderboardRetry`
      // are five separate keys, and the repository namespaces `retry` per
      // screen on purpose. This screen borrowing the board's copy was the
      // coupling the rule exists to remove, and the journey has a key of its
      // own now.
      retryLabel: context.l10n.journeyRetry,
      // **`isArabicArm` and not `languageCode == 'ar'`.** The repository's
      // canonical arm test is a **prefix** test — `l10n.dart`'s own doc says
      // "so that `ar_EG` … cannot silently fall through to the Latin face" —
      // and this file was spelling the rule a second time, by hand.
      retryFamily: context.l10n.isArabicArm
          ? EvaTypography.arabicFamily
          : EvaTypography.uiFamily,
    ),
    JourneyStatus.loading => const Padding(
      padding: EdgeInsets.all(EvaSpacing.xxl),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ),
    JourneyStatus.ready => _ready(context, state),
  };

  /// The column, when every read has answered.
  Widget _ready(BuildContext context, JourneyState state) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    // **The three `!`s are provably non-null, and the reason is the cubit's
    // one ready emit.** `JourneyCubit.load` reads all five, and the state it
    // emits with `status: JourneyStatus.ready` carries all three of these
    // (`:191-211` of `journey_cubit.dart`): the rings are derived from the
    // history the load answered, the shelf is the medal port's answer, and
    // the summary is `GET /streak/summary`'s answer. The `ready` status is
    // only ever emitted with all three set, and it is only ever emitted
    // after a load that answered — a load that failed emits `failed`
    // instead, and this method is not reached from that arm.
    final JourneyRings rings = state.rings!;
    final MedalShelf shelf = state.shelf!;
    final StreakSummary summary = state.summary!;

    // The three strokes, in the prototype's order: teal, magenta, blue (`:592`,
    // `:593`, `:594`). **The magenta is the token** — `EvaColors.bloom` is the
    // prototype's hue exactly — and the other two are the transcription table's.
    final List<Color> strokes = journeyRingStrokes(colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        JourneyOrb(
          // **The reader's own monogram**, and the mapper's unknown-initials
          // mark when the session could not be read. The prototype's orb holds a
          // literal `M` (`:586`).
          monogram: state.session?.initials ?? '?',
          // The orb's accessible name is the **reader's**, not the app's —
          // `SealMonogram`'s default label is the wordmark, and a face that
          // announces "Evangelion" is worse than no face.
          semanticLabel: state.session?.displayName ?? '',
        ),
        JourneyReaderName(name: state.session?.displayName ?? ''),
        const JourneyRoleLine(),
        JourneyHeroNumber(streak: summary.currentStreak),
        JourneyRingsRow(
          rings: <JourneyRing>[
            // **Ring 1, "verses".** The label is the prototype's and the
            // quantity is a scheduled-day completion ratio — the backend counts
            // questions, not verses. See `journey_rings.dart`.
            JourneyRing(
              label: strings.journeyRingVerses,
              value: journeyPercent(strings, rings.completion),
              fraction: rings.completion,
              stroke: strokes[0],
            ),
            // **Ring 2, "quizzes"** — a bare count, and the one ring whose arc
            // measures something else. The number is the count; the arc is the
            // share of the scheduled questions that were answered, because a
            // count has no denominator of its own. See `journey_rings.dart`.
            JourneyRing(
              label: strings.journeyRingQuizzes,
              value: strings.digits(rings.answered),
              fraction: rings.answeredShare,
              stroke: strokes[1],
            ),
            // **Ring 3, "accuracy".**
            JourneyRing(
              label: strings.journeyRingAccuracy,
              value: journeyPercent(strings, rings.accuracy),
              fraction: rings.accuracy,
              stroke: strokes[2],
            ),
          ],
        ),
        JourneySkyLine(
          stars: state.starsLit,
          constellations: state.constellations,
        ),
        JourneyMedalsLabel(earned: shelf.earned.length, total: shelf.total),
        JourneyMedalsStrip(
          tiles: <JourneyMedalTile>[
            for (final Medal medal in shelf.earned)
              JourneyMedalTile(
                // The name is an **ARB key**, and the emblem and the wash are the
                // domain enum's own fields — so the medal's identity has one
                // home and the copy has another, and neither is a second table.
                label: medal.label(strings),
                emblem: medal.emblem,
                bloom: medal.bloom,
              ),
          ],
        ),
        const JourneyAccountLabel(),
        JourneyAccountRows(
          // **The board is a tab** — see [JourneyAppBar]'s `onOpenBoard` in the
          // app bar above, which is the same switch for the same reason.
          onOpenBoard: () => _openBoard(context),
          onOpenSettings: () => context.router.pushPath(AppRoutes.settings),
        ),
      ],
    );
  }
}
