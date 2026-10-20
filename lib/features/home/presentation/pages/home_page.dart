import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/widgets/greeting_block.dart';
import 'package:evangelion/features/home/presentation/widgets/last_light_card.dart';
import 'package:evangelion/features/home/presentation/widgets/library_carousel.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/home/presentation/widgets/streak_chip.dart';
import 'package:evangelion/features/home/presentation/widgets/verse_of_the_day_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/`, the sanctuary's threshold: a greeting, the day's verse, the last light, a
/// minute of silence and the scrolls.
///
/// `redesign.html:513-538`. **Task 5.2 rebuilt this screen against that range**, and
/// every number on it is a `redesign.html` line rather than the React prototype's
/// `HomeScreen.tsx` the previous version transcribed.
///
/// ## THE PADDING IS FIVE NUMBERS AND FOUR GAPS, AND CSS'S MARGIN COLLAPSE IS WHY
///
/// The prototype's home is two elements: a `.greet` (`:514-517`) and a `.scroll`
/// (`:518-537`) that owns the rest. Their paddings do not agree — `.greet` is
/// `54px 20px 6px`, `.scroll` is `6px 14px 118px`, and every card inside the scroll
/// carries its own `margin: … 14px …` — so the visible edges are **20** for the
/// greeting and **28** for the cards, which is `14 + 14`.
///
/// The four gaps are the other half. CSS collapses adjacent vertical margins, and
/// Flutter has no such rule, so the collapsed values are written here rather than
/// summed:
///
/// | between | the two margins | collapsed |
/// | --- | --- | --- |
/// | greeting and the day's card | `.greet`'s 6 + `.scroll`'s 6 + `.hcard`'s 14 | **[kGreetToCardGap]** = 26 |
/// | the two cards | `.hcard`'s 8 and the next `.hcard`'s 14 | **[kCardGap]** = 14 |
/// | the last card and the selah card | 8 and 8 | **[kSelahGap]** = 8 |
/// | the selah card and the label | `.selah`'s 8 and `.car-label`'s 20 | **[kLabelGap]** = 20 |
/// | the label and the strip | `.car-label`'s 10 and `.carousel`'s 4 | **[kStripGap]** = 10 |
/// | the strip and the bottom | `.carousel`'s 12 + `.scroll`'s 118 | **[kBottomClearance]** = 130 |
///
/// `home_geometry_test.dart` reads these back off the rendered tree and compares
/// them against the CSS numbers it parses, which is what keeps the table above from
/// being a table of intentions.
///
/// ## AND THE DOCK IS **NOT** HERE, AND THE SEAL IS GONE
///
/// `redesign.html:702-708` is a five-slot dock and it is Phase 6's. This screen's
/// own chrome used to be `SealFab` — the same interim holder `/login`'s footer
/// used in Task 5.1 — and Phase 6 **deleted it**, because the dock now holds two
/// of its three destinations (the board and the journey, which are the
/// redesign's own dock tabs) and the third (`/settings`) is reached the way the
/// prototype reaches it: from the journey's app-bar gear (`redesign.html:582`)
/// and its account row (`:606`).
///
/// **The redesign draws no seal on `/`** — `:513-538` has no floating control at
/// all — so the divergence that was recorded here is discharged rather than
/// carried.
@RoutePage()
class HomePage extends StatelessWidget {
  /// The home screen.
  const HomePage({super.key, this.bloc});

  /// The bloc to render.
  ///
  /// `null` means "resolve [HomeBloc] from the locator", which is the production
  /// path — and the reason this page is not a `BlocProvider` of its own: the bloc
  /// holds five repository results a retry has to be able to replace, so a page
  /// that created one per mount would lose them on every rebuild.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach the
  /// locator without configuring the whole graph. Same arrangement as `LoginPage`'s
  /// `bloc`, and for the same reason.
  ///
  /// **Substitution, not initialisation.** A passed-in bloc is loaded exactly as the
  /// locator's is — `_HomeBody` dispatches `HomeStarted` unconditionally — so a test
  /// does not have to remember an event before its first assertion.
  final HomeBloc? bloc;

  /// `.greet`'s horizontal padding. `redesign.html:235` — `padding: 54px 20px 6px`.
  static const double kGreetGutter = 20;

  /// `.greet`'s top padding. `redesign.html:235` — `54px`, and it is measured from
  /// the top of the screen: the prototype's frame is a bare `.screen` with no
  /// status bar, so `NeuralScaffold`'s `SafeArea` is where a real device's inset
  /// belongs and the 54 sits inside it.
  static const double kGreetTop = 54;

  /// `.greet`'s bottom padding. `redesign.html:235` — `6px`. See
  /// [kGreetToCardGap] for what it adds up to.
  static const double kGreetBottom = 6;

  /// `.scroll`'s horizontal padding. `redesign.html:157` — `6px 14px 118px`.
  static const double kScrollGutter = 14;

  /// `.scroll`'s top padding. `redesign.html:157` — `6px`.
  static const double kScrollTop = 6;

  /// The gap between the greeting and the day's card. See the class doc's table.
  static const double kGreetToCardGap = kGreetBottom + kScrollTop + 14;

  /// **The horizontal** half of `.hcard`'s and `.selah`'s own `margin … 14px`.
  ///
  /// A separate constant from [kCardGap] because the same `14` appears twice in the
  /// prototype's CSS and means two different things: vertically it is a margin that
  /// collapses against its neighbour, horizontally it is an inset with nothing to
  /// collapse against. `redesign.html:249` and `:261` both write `14px` in the
  /// horizontal slot, and the visible consequence is that the cards sit at **28**
  /// from the screen edge while the greeting sits at 20.
  ///
  /// **This was missing in the first version of the page**, which put every card at
  /// the scroll's own 14 and made the whole block 14px wider than the prototype.
  /// `home_geometry_test.dart` is the row that caught it: it reads the greeting at
  /// 20 and the card at 28 and one of them was wrong.
  static const double kCardGutter = 14;

  /// The gap between the two cards, and between a card and the selah card's own
  /// `14px` top margin. See the class doc's table.
  static const double kCardGap = 14;

  /// The gap between the last-light card and the selah card. See the class doc.
  static const double kSelahGap = 8;

  /// The gap between the selah card and the carousel's label row. See the class
  /// doc.
  static const double kLabelGap = 20;

  /// The gap between the label row and the strip of cards. See the class doc.
  static const double kStripGap = 10;

  /// What is under the strip: `.carousel`'s own `12px` (`:273`) and `.scroll`'s
  /// `118px` (`:157`), which is the prototype's clearance for its dock.
  ///
  /// **The dock exists now** — Phase 6 built it, and it is 78px tall
  /// (`eva/redesign.html:208`) — and the clearance is still **118**, because
  /// the prototype's number is the prototype's number and it is the *scroll's
  /// padding*, not the dock's height. The dock is 78 of those 118; the other
  /// 40 is the space the design leaves between the last card and the dock's
  /// top edge.
  static const double kBottomClearance = 130;

  @override
  Widget build(BuildContext context) {
    // Two sources for one bloc, one provider either way — see [bloc]. A bloc the
    // page owns is loaded by `_HomeBody`; one the caller passed is the caller's,
    // and it is already holding whatever state the caller wants to test.
    final HomeBloc? passed = bloc;
    final HomeBloc resolved = passed ?? getIt<HomeBloc>();

    return NeuralScaffold(
      variant: NeuralVariant.home,
      // `redesign.html:518` — `.scroll{overflow-y: auto}` on the whole section.
      scrollable: true,
      // **`EdgeInsets.zero`, and this is the load-bearing decision on this screen.**
      // The redesign's home has no single gutter: the greeting is at 20 and the
      // cards at 28 (`:235` against `:157` + `:249`), so a scaffold padding would be
      // a number one of them disagrees with. The two paddings are therefore applied
      // where the prototype writes them — [kGreetGutter] on the greeting and
      // [kScrollGutter] on the column below it.
      padding: EdgeInsets.zero,
      // **No `overlay:` slot, and that is Phase 6's doing.** The slot used to hold
      // the `SealFab`, the interim holder for the destinations the redesign's
      // dock now owns. The redesign draws no float on `/` (`redesign.html:513-538`)
      // and the dock is the prototype's own home for the board and the journey
      // (`:706`, `:707`), so the seal is deleted rather than kept beside a dock
      // that says the same thing twice.
      child: BlocProvider<HomeBloc>.value(
        value: resolved,
        child: const _HomeBody(),
      ),
    );
  }
}

/// Everything below the scaffold: the greeting and the four sections of the scroll.
///
/// A [StatefulWidget] rather than a [StatelessWidget] for one reason: `HomeStarted`
/// must fire **once**, on entry. `HomePage.build` runs on every rebuild, and a
/// `getIt<HomeBloc>()..add(HomeStarted(...))` there would re-issue all five requests
/// each time the state changed, which is to say on every answer.
///
/// ## AND IT FIRES FOR A **PASSED-IN** BLOC TOO
///
/// The first version dispatched only when the page had resolved the bloc itself,
/// mirroring `LoginPage`'s `bloc ?? (getIt<AuthBloc>()..add(const AuthStarted()))`.
/// That is defensible there, because `AuthStarted` is idempotent against an
/// in-memory fake and the caller owns the bloc. It is wrong here for two measured
/// reasons:
///
/// * a widget test then has to dispatch the event itself before every assertion,
///   which is a suite that can forget — and this one did: the first run of
///   `home_page_test.dart` found nothing on screen in **eight** tests, because
///   `pumpHome` passed a bloc and no event was ever sent;
/// * the page then behaves **differently** depending on where its bloc came from,
///   which is the kind of difference nothing records and every reader re-derives.
///
/// So the page loads itself either way, and [HomePage.bloc]'s doc says the
/// parameter is for substitution, not for initialisation.
///
/// ## AND IT RE-LOADS ON **RE-ENTRY**, WHICH IS NOT A REBUILD
///
/// The first version carried `bool _started`, set once per `State` and never reset.
/// Measured with the real router — land on `/`, open a reading → `/reading`, `pop` →
/// back on `/` — nothing re-fetched: the readings were fetched once on entry *and*
/// once after returning. `HomePage`'s element is retained under the pushed route, so
/// `_HomeBodyState` survives the push and comes back unchanged.
///
/// Two consequences, both real:
///
/// * the reader finishes a reflection on `/quiz`, comes back, and the chip and the
///   cards still show first-landing values. There is no pull-to-refresh and no other
///   invalidation on `/`, so this was the whole refresh story;
/// * `_onStarted` opens with `emit(state.withGreetingPeriod(…))`, which copies
///   every section verbatim — so on any second `HomeStarted` the first frames
///   rendered the **previous** session's name and the previous day's reading while
///   the new request was in flight.
///
/// The trigger is [AutoRouteAware]'s [didPopNext], and the wiring it needed was
/// **missing from the router**: `RootStackRouter.config()`'s default
/// `navigatorObservers` is `const []`, so no `AutoRouteObserver` was installed and
/// `didPopNext` could never fire. See `AppRouter.config`'s doc.
///
/// ### WHY THE MIXIN IS NOT USED, MEASURED
///
/// `AutoRouteAwareStateMixin` is the obvious spelling and it **cannot** go here.
/// Its `didChangeDependencies` calls `RouterScope.of(context)` unguarded, and
/// `RouterScope.of` **asserts** — it throws — when the context is not under a
/// `RouterScope`. `pumpHome` mounts `HomePage` over a bare `MaterialApp`, so the
/// mixin turned **every** non-router suite in this feature red on the first pump.
///
/// [_subscribeToRoute] is the same mechanism with the lookup written as
/// `findAncestorWidgetOfExactType<RouterScope>()`, which returns `null` instead of
/// throwing. That is not defensive decoration: "no router, no re-entry" is the right
/// behaviour for a page mounted bare in a widget test, and it is what keeps this file
/// testable without a real `AppRouter`.
///
/// ### AND `_requested`, NOT `_started`
///
/// The flag was a `bool`, and a `bool` cannot say *which* arm of the corpus was
/// asked for. `didChangeDependencies` also fires on a **locale** change — Phase 7
/// owns the real switch, and with a `bool` a locale change would leave `/` showing
/// the other arm's scripture with nothing re-fetched. Comparing the language rather
/// than a boolean fixes the second trigger in the same place, and
/// `home_page_test.dart` drives both.
class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> implements AutoRouteAware {
  /// The arm of the corpus this screen asks for.
  ///
  /// **A getter and not a field**, because it reads an inherited widget: caching it
  /// in `initState` is the mistake [didChangeDependencies]'s doc describes, and
  /// caching it at all is what the assertion there is guarding. Two dispatches below
  /// each ask for it, which is two cheap reads of one `Localizations`.
  ReadingLanguage get _language =>
      ReadingLanguage.forLocale(Localizations.localeOf(context).languageCode);

  /// The language the last dispatch asked for, or `null` before the first.
  ///
  /// **A [ReadingLanguage] and not a `bool`**, so one field answers both "has this
  /// loaded?" and "is what is on screen the arm this screen asked for?".
  ReadingLanguage? _requested;

  /// The observer this state subscribed to, so [dispose] can unsubscribe and a
  /// replaced observer cannot go on holding a dead `State`.
  AutoRouteObserver? _observer;

  /// NOT `initState`, and that is a framework rule rather than a preference.
  ///
  /// `Localizations.localeOf` is an inherited-widget lookup, and Flutter forbids
  /// those in `initState` — `dependOnInheritedElement` throws
  /// "`dependOnInheritedElementOfExactType<_LocalizationsScope>()` … was called
  /// before `_HomeBodyState.initState()` completed". Measured, not reasoned about:
  /// the first version dispatched from `initState` and four router suites went red
  /// on landing `/`.
  ///
  /// [didChangeDependencies] is the phase the framework names for exactly this, and
  /// [context]'s own doc on it says so. It is also the phase that fires on a
  /// **locale** change, which is the second trigger this file needs — so first entry
  /// and a language change are one branch, and an uncovered route is the other.
  ///
  /// Guarded on [_requested] and not on a `bool` for the reason its own doc gives:
  /// `didChangeDependencies` may run many times, and re-issuing all five requests on
  /// every `MediaQuery` change would be the same defect as dispatching from `build`.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToRoute();
    if (_requested != _language) {
      _load();
    }
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  /// Subscribes to the router's [AutoRouteObserver], if this page is under one.
  ///
  /// Re-entrant on purpose: [didChangeDependencies] runs on every `Localizations` or
  /// `MediaQuery` change. Re-subscribing is idempotent in `AutoRouteObserver` —
  /// `subscribers.add` returns `false` for a member it already has — and the
  /// `identical` check is what stops a *replaced* observer from going on holding a
  /// disposed `State`.
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
    // **No shell, no re-entry trigger to wire.** See [_watchedRouteData].
    final RouteData<dynamic>? watched = _watchedRouteData;
    if (watched == null) {
      return;
    }
    observer.subscribe(this, watched);
  }

  /// The route data this page subscribes under — the **SHELL's**, not this
  /// tab's.
  ///
  /// ## IT IS THE **SHELL'S**, NOT THIS TAB'S, AND THAT IS THE WHOLE POINT
  ///
  /// `/` is a **tab** now, inside the dock shell's tabs router, and a tab is
  /// never popped — so this page's own route data would never produce a
  /// `didPopNext`, and the re-entry reload (recorded decision 41) would die
  /// silently. The shell **is** popped, and it is popped exactly when the
  /// screen pushed over it — the reader, the quiz, the workshop — is popped
  /// and `/` is showing again. That is the event this page re-loads for, and
  /// the shell's route data is the one the observer's `didPop` hands
  /// `didPopNext` to (`auto_route_observer.dart:168` — the **previous**
  /// route's subscribers).
  ///
  /// **`null` when there is no shell above this page** — a page mounted bare in
  /// a widget test, or under a router that is not the dock shell. And that is
  /// the honest answer rather than a fallback: `context.routeData` **throws**
  /// without a `RouteDataScope`, and a tree with no shell has no re-entry
  /// trigger to wire anyway.
  RouteData<dynamic>? get _watchedRouteData =>
      TabsRouterScope.of(context)?.controller.routeData;

  /// Dispatches `HomeStarted` for the language on screen.
  ///
  /// Deliberately **not** conditional on anything else. It is called from the two
  /// triggers that are conditions — first entry and a language change from
  /// [didChangeDependencies], and an uncovered route from [didPopNext] — and the
  /// first version's guard was the bug, not the redundancy.
  void _load() {
    final ReadingLanguage language = _language;
    _requested = language;
    context.read<HomeBloc>().add(HomeStarted(language));
  }

  /// The route underneath was popped and this one is showing again.
  ///
  /// **The re-entry trigger.** Two things happen between the last `push` and this
  /// callback: the reader may have finished a reflection on `/quiz` and seen a new
  /// streak, and the singleton `HomeBloc` (`navigation_injection.dart`) is still
  /// holding whatever the last request answered.
  @override
  void didPopNext() {
    _load();
  }

  // --- the rest of `AutoRouteAware`, and why each is empty -------------------
  //
  // auto_route 11 declares these **without** default bodies (unlike Flutter's own
  // `RouteAware`, which is all-defaults), so `implements AutoRouteAware` requires
  // all six. Only `didPopNext` means anything to this page:
  //
  // | callback | what it means | why it is empty here |
  // | --- | --- | --- |
  // | `didPush` / `didPushNext` | `/` arrived, then was covered | arriving is `didChangeDependencies`'s job and covering is not an event this screen reacts to |
  // | `didPop` | *this* route was popped off | the page is going away; [dispose] runs and the subscription is dropped |
  // | `didInitTabRoute` / `didChangeTabRoute` | the tab router changed tab | the subscription is under the **shell's** route data now, so these fire for the shell's lifecycle; a tab change is not an event this screen reacts to — the shell's `didPopNext` is |
  //
  // Written out rather than left unimplemented, because an unimplemented one is a
  // compile error today and a silent no-op the moment auto_route gives it a body —
  // which is the exact shape of the `if (_observer != null)` guard in
  // `AutoRouteAwareStateMixin` that made the first version of this inert.

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
    final AppLocalizations strings = context.l10n;
    // ## THE READER'S RITUAL PREFERENCES, READ **ONCE** AND WATCHED
    //
    // `SettingsScope.of` is a **dependent** lookup, so this registers the
    // page's dependency on the settings scope: when the reader changes the
    // selah's length in the Workshop, the scope announces, this page rebuilds,
    // and the card counts the silence they asked for.
    //
    // **A page pumped bare would not rebuild** — `SettingsScope.of`'s locator
    // fallback is not watched — so the home harness installs the scope. See
    // `home_harness.dart`'s `pumpHome`.
    final UserSettings settings = SettingsScope.of(context).settings;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (BuildContext context, HomeState state) {
        final HomeBloc bloc = context.read<HomeBloc>();
        final ReadingLanguage language = _language;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (state.greetingPeriod case final GreetingPeriod period)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HomePage.kGreetGutter,
                  HomePage.kGreetTop,
                  HomePage.kGreetGutter,
                  HomePage.kGreetBottom,
                ),
                child: GreetingBlock(
                  period: period,
                  name: state.readerName,
                  chip: StreakChip(
                    days: state.streak?.currentStreak,
                    semanticLabel: strings.homeStreakLabel,
                    daysLabel: strings.homeDays,
                    failureMessage: state.streakFailure?.message,
                    onRetry: () => bloc.add(HomeRetried(language)),
                  ),
                ),
              ),
            // `.scroll` — `:518`. Its own top padding, and its own horizontal
            // gutter, which is 14 rather than the greeting's 20.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HomePage.kScrollGutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: HomePage.kScrollTop),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HomePage.kCardGutter,
                    ),
                    child: VerseOfTheDayCard(
                      reading: state.reading,
                      failureMessage: state.readingFailure?.message,
                      retryLabel: strings.homeRetry,
                      onRetry: () => bloc.add(HomeRetried(language)),
                      onOpen: () => context.router.pushPath(AppRoutes.reading),
                    ),
                  ),
                  const SizedBox(height: HomePage.kCardGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HomePage.kCardGutter,
                    ),
                    child: LastLightCard(
                      entry: state.lastLight,
                      failureMessage: state.lastLightFailure?.message,
                      retryLabel: strings.homeRetry,
                      onRetry: () => bloc.add(HomeRetried(language)),
                      onOpen: () => context.router.pushPath(AppRoutes.reading),
                    ),
                  ),
                  const SizedBox(height: HomePage.kSelahGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HomePage.kCardGutter,
                    ),
                    child: SelahCard(
                      // ## THE READER'S **OWN** CHOICES, AND NOT CONSTANTS
                      //
                      // The silence's length is the Workshop's
                      // `selahLengthSec` (`:684` — a 15…120 second range,
                      // stepped by 5) and the haptics are the Workshop's own
                      // switch (`:689`). **A card that carried a literal would
                      // ignore both**, and the Workshop's ritual group would be
                      // six switches that do nothing.
                      seconds: settings.selahLengthSec,
                      hapticsEnabled: settings.haptics,
                      beginLabel: strings.homeSelahBegin,
                      endLabel: strings.homeSelahEnd,
                      amenLabel: strings.homeSelahAmen,
                    ),
                  ),
                  const SizedBox(height: HomePage.kLabelGap),
                  // The label row carries `.car-label`'s own `10px` bottom margin
                  // inside it (`LibraryCarousel.labelBottomGap`), so the strip
                  // follows it directly and [kStripGap] is the strip's own `4px`
                  // plus that 10 — collapsed, per the class doc's table.
                  LibraryCarousel(
                    books: state.catalogue ?? const <LibraryBook>[],
                    unavailableReason: strings.homeUnavailableSuffix,
                    failureMessage: state.catalogueFailure?.message,
                    retryLabel: strings.homeRetry,
                    onRetry: () => bloc.add(HomeRetried(language)),
                  ),
                  const SizedBox(height: HomePage.kBottomClearance),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
