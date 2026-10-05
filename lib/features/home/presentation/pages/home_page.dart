import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/home/presentation/widgets/app_top_bar.dart';
import 'package:evangelion/features/home/presentation/widgets/today_reading_panel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/` — greeting, streak flame, today's-reading panel. `HomeScreen.tsx:11-79`
/// minus the cut library.
///
/// ## THREE THINGS THE PROTOTYPE SHOWS THAT ARE **NOT** DATA, AND WHAT REPLACES THEM
///
/// | prototype | shipped | why |
/// | --- | --- | --- |
/// | `Miriam` at `HomeScreen.tsx:27` | `AuthSession.displayName` through the `AuthRepository` port | there is no user endpoint and the profile screen is cut, so the literal is the only "who is this" the prototype has |
/// | `MK` at `ds.tsx:525` | `AuthSession.initials`, same route | same |
/// | `12` at `ds.tsx:516` | `StreakSummary.currentStreak` | the live value is `0` |
///
/// None of the three may be a constant in this feature, and there are now **two**
/// gates for it rather than one: `home_page_test.dart` asserts the **rendered** tree
/// (`find.text('Miriam')` and `find.text('MK')` are `findsNothing`), and
/// `home_strings_test.dart` walks `lib/features/home/` line by line refusing the two
/// literals in **any** executable line.
///
/// **The second one exists because the first was not enough, and this paragraph
/// used to claim the first was.** It said "none of the three may be a constant in
/// this feature … assert that in the failing direction", which is true of the
/// *rendered* value and silent about the *constant*: adding
/// `const String kUnusedReaderName = 'Miriam';` to this file passed every test in the
/// phase. A **private** unused constant is caught incidentally, by the analyzer's
/// `unused_element`; a **public** one is caught by nothing, and one edit makes it
/// live.
///
/// ## THE VARIANT IS [NeuralVariant.home], UNCONDITIONALLY
///
/// `HomeScreen.tsx:15` is `<NeuralBackground variant={1} />` and there is one
/// `HomeScreen.tsx` in `eva/src`. So the orbs are chosen by the route and the
/// language chooses only text and direction — the same reading
/// `LoginPage`'s doc gives for `/login`, and `NeuralScaffold`'s D2 note warns
/// against re-deriving the variant from anything but the variant.
///
/// ## AND NOTHING HERE NAVIGATES ON ITS OWN ACCOUNT
///
/// The panel's two controls are handed `context.router.pushPath(AppRoutes.reading)`
/// and `AppRoutes.quiz` from [HomePage], and `_HomeBody` supplies nothing else. The
/// reading route is reachable from two controls, exactly as the prototype has two
/// (`HomeScreen.tsx:39`'s panel `onClick` and `:71`'s primary button), and the quiz
/// from one. §2's route table carries **no `:passageId`**, so there is no passage to
/// name and `/reading` is always today's.
@RoutePage()
class HomePage extends StatelessWidget {
  /// The home screen.
  const HomePage({super.key, this.bloc});

  /// The bloc to render.
  ///
  /// `null` means "resolve [HomeBloc] from the locator", which is the production
  /// path — and the reason this page is not a `BlocProvider` of its own: the bloc
  /// holds two repository results a retry has to be able to replace, so a page that
  /// created one per mount would lose them on every rebuild.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach the
  /// locator without configuring the whole graph. Same arrangement as `LoginPage`'s
  /// `bloc`, and for the same reason.
  ///
  /// **Substitution, not initialisation.** A passed-in bloc is loaded exactly as the
  /// locator's is — `_HomeBody` dispatches `HomeStarted` unconditionally — so a test
  /// does not have to remember an event before its first assertion. See `_HomeBody`'s
  /// doc.
  final HomeBloc? bloc;

  /// `NeuralScaffold`'s default gutter, restated because this screen is the one
  /// that has to match `ds.tsx:504`'s `padding: '20px 20px 0'` and `HomeScreen.tsx`'s
  /// own `'20px 20px 0'` top bar.
  static const EdgeInsets scaffoldPadding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.screenHorizontal,
  );

  /// The gap between the bar and the greeting. `HomeScreen.tsx:27`'s
  /// `marginBottom: 24` is the **greeting block's** own gap; the prototype's top bar
  /// carries `padding: '20px 20px 0'` and nothing below it, so the gap under it is
  /// this screen's decision and it is the same 24.
  static const double topGap = EvaSpacing.xxl;

  /// The gap between the greeting block and the panel. `HomeScreen.tsx:63` gives the
  /// panel `marginBottom: 28`; nothing states the gap above it, so it is the
  /// scale's own `xxxl + xs` step rather than a transcribed number.
  static const double panelGap = EvaSpacing.xxl + EvaSpacing.xs;

  /// The clearance below the panel.
  ///
  /// `HomeScreen.tsx:83` gives the root `paddingBottom: 100`, which is the
  /// prototype's clearance for its `SealFAB` — and **`SealFAB` is cut** with the
  /// profile screen (§2, decision 1). So 100 is not transcribed; the value is one
  /// `EvaSpacing.huge`, which §5.3 defines as "above a page's first element, and
  /// between major sections", and which is also the amount that keeps the last
  /// control clear of the home indicator on a short screen.
  static const double bottomSpacer = EvaSpacing.huge;

  @override
  Widget build(BuildContext context) {
    // Two sources for one bloc, one provider either way — see [bloc]. A bloc the
    // page owns is loaded by `_HomeBody`; one the caller passed is the caller's,
    // and it is already holding whatever state the caller wants to test.
    final HomeBloc? passed = bloc;
    final HomeBloc resolved = passed ?? getIt<HomeBloc>();

    return NeuralScaffold(
      variant: NeuralVariant.home,
      // `HomeScreen.tsx:14` — `overflowY: 'auto'` on the **root**. The three screens
      // that do not scroll own their own scrollables; this is not one of them.
      scrollable: true,
      padding: scaffoldPadding,
      child: BlocProvider<HomeBloc>.value(
        value: resolved,
        child: const _HomeBody(),
      ),
    );
  }
}

/// Everything below the scaffold: the bar, the greeting, and the panel.
///
/// A [StatefulWidget] rather than a [StatelessWidget] for one reason: `HomeStarted`
/// must fire **once**, on entry. `HomePage.build` runs on every rebuild, and a
/// `getIt<HomeBloc>()..add(HomeStarted(...))` there would re-issue both requests
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
///   which is a suite that can forget. This one did: the first run of
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
/// Measured with the real router — land on `/`, tap Continue → `/reading`, `pop` →
/// back on `/` — nothing re-fetched: `readings=1 streaks=1` on entry *and* after
/// returning. `HomePage`'s element is retained under the pushed route, so
/// `_HomeBodyState` survives the push and comes back unchanged.
///
/// Two consequences, both real:
///
/// * the reader finishes a reflection on `/quiz`, comes back, and the flame and the
///   panel still show first-landing values. There is no pull-to-refresh and no other
///   invalidation on `/`, so this was the whole refresh story;
/// * `_onStarted` opens with `emit(state.withGreetingPeriod(…))`, which copies
///   `readerName`, `readerInitials`, `reading` and `streak` verbatim — so on any
///   second `HomeStarted` the first frames rendered the **previous** session's name
///   and reading while the new request was in flight.
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
/// asked for. `didChangeDependencies` also fires on a **locale** change — Phase 9
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
  /// `didChangeDependencies` may run many times, and re-issuing both requests on
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
    observer.subscribe(this, context.routeData);
  }

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
  // | `didPush` / `didPushNext` | `/` arrived, then was covered | arriving is `didChangeDependencies`' job and covering is not an event this screen reacts to |
  // | `didPop` | *this* route was popped off | the page is going away; [dispose] runs and the subscription is dropped |
  // | `didInitTabRoute` / `didChangeTabRoute` | a tab router changed tab | there is no `AutoTabsRouter` in the six routes |
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

    // §3 keeps `core/domain/` Flutter-free, so the `Locale` → `ReadingLanguage`
    // conversion happens **here**, at the one edge where a `Locale` exists — see
    // `_language` above and `reading_language.dart` for why the enum and not the
    // `Locale`. It rides on the events rather than the bloc, because a bloc
    // registered once for the process would freeze the language at launch.
    final ReadingLanguage language = _language;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (BuildContext context, HomeState state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTopBar(
              wordmark: strings.homeWordmark,
              streakDays: state.streak?.currentStreak,
              streakSemanticLabel: strings.homeStreakLabel,
              streakFailureMessage: state.streakFailure?.message,
              onRetryStreak: () =>
                  context.read<HomeBloc>().add(HomeRetried(language)),
              initials: state.readerInitials ?? '',
              avatarSemanticLabel: state.readerName ?? strings.homeAvatarLabel,
              avatarUnavailableReason: strings.homeUnavailableSuffix,
              // **Live since Phase 9.** It was `null` for four phases, with
              // [AppTopBar.onAvatarTap]'s doc saying "When a profile route exists the
              // fix is one argument here and nothing else changes" — and Phase 9 is
              // what made a destination exist, `/settings`, without re-litigating
              // decision 1's cut of the profile screen.
              //
              // So the avatar is the **only** entry point to `/settings` on `/`, which
              // is why `app_top_bar_test.dart`'s header had to be rewritten: it said
              // "`/` passes `onAvatarTap: null` and so can only ever render the
              // **disabled** avatar", which was true when written and is false now.
              onAvatarTap: () => context.router.pushPath(AppRoutes.settings),
            ),
            const SizedBox(height: HomePage.topGap),
            if (state.greetingPeriod case final GreetingPeriod period)
              _Greeting(
                period: period,
                name: state.readerName,
                strings: strings,
              ),
            _StreakSubtitle(streak: state.streak, strings: strings),
            const SizedBox(height: HomePage.panelGap),
            TodayReadingPanel(
              reading: state.reading,
              failure: state.readingFailure?.message,
              strings: strings,
              onRetry: () =>
                  context.read<HomeBloc>().add(HomeRetried(language)),
              onOpenReading: () => context.router.pushPath(AppRoutes.reading),
              onStartReflection: () => context.router.pushPath(AppRoutes.quiz),
            ),
            const SizedBox(height: HomePage.bottomSpacer),
          ],
        );
      },
    );
  }
}

/// `Good evening, ` + the name in ember, and the streak sentence under it.
///
/// `HomeScreen.tsx:25-31`. The greeting is two spans — `T.ink` for the lead-in and
/// `ember` with a `0 0 24px` glow for the name — so it is one `Text.rich` with two
/// `TextSpan`s rather than two widgets, because two widgets would wrap
/// independently and put the name on its own line at 320px.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.period,
    required this.name,
    required this.strings,
  });

  final GreetingPeriod period;
  final String? name;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final String? reader = name;
    final String lead = strings.greetingLead(period, hasName: reader != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: lead,
                style: TextStyle(color: colors.ink),
              ),
              if (reader != null)
                TextSpan(
                  text: reader,
                  style: TextStyle(
                    color: colors.ember,
                    // `HomeScreen.tsx:27` —
                    // `textShadow: 0 0 24px rgba(ember, 0.5)`.
                    shadows: <Shadow>[
                      Shadow(
                        color: colors.ember.withValues(alpha: 0.5),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // `HomeScreen.tsx:26` — `F.display 30 / 600 / lineHeight 1.1`.
          // `headlineMedium` is 28sp and is what `EmptyState.titleStyle` already
          // chose for this design system against the same requirement; see that
          // method's doc for the 1.22×/320px arithmetic.
          //
          // **Swapped for the ambient arm at the ROOT, not on the two spans.** The
          // lead-in and the name carry `TextStyle(color: …)` and nothing else, so the
          // engine resolves their family by *merging* them over this span's style —
          // wrapping this one line fixes both runs and cannot leave one of them out.
          // Done per span instead it would have been two `arabicAware` calls whose
          // outputs must agree, and the third instance in this repository of two
          // copies of one rule is what recorded decision 69 is about.
          style:
              arabicAware(
                Theme.of(context).textTheme.headlineMedium!,
                Directionality.of(context),
              ).copyWith(
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: -0.01,
              ),
        ),
        const SizedBox(height: EvaSpacing.sm + 2),
      ],
    );
  }
}

/// `HomeScreen.tsx:30` — "Your streak is glowing. Keep it alive."
///
/// **Conditional on the streak's *text*, and never conditional on its existence**,
/// and the distinction is the whole of this widget. The condition is the measured
/// one: the live payload has `streak/summary.current_streak == 0`, so the
/// prototype's unconditional literal would tell a reader their streak is glowing
/// while the flame beside it reads `0`. See `AppLocalizations.homeStreakResting` for the
/// alternative that was rejected.
///
/// ## WHY THE ROW IS RESERVED WHEN THERE IS NO STREAK
///
/// The first version gated the whole row on `if (state.streak case …)`, so the
/// subtitle **vanished** while the streak was loading and again when the streak
/// failed — and `EvaSpacing.xxl` of the greeting's own gap went with it, so the
/// panel jumped up by a line mid-screen. That is precisely what
/// `TodayReadingPanel`'s `_FailedOrLoading.placeholderHeight` exists to prevent,
/// declared 140 lines away: "a panel that grows from one line to nine is the layout
/// moving."
///
/// The fix is **an empty [Text] in the same style, not a `SizedBox`**. Measured
/// rather than reasoned about, because the whole question is whether an empty
/// paragraph reserves its line: `Text('')` at `bodyMedium` is **20.0 tall and 0.0
/// wide** — exactly one line — while `Text('Resting')` is also 20.0. So one
/// `Text` covers all three states and the geometry cannot drift from the text's.
///
/// **A `SizedBox` would have been wrong in a way that shows up late**: its height
/// would be a second copy of `fontSize × height`, and it would not move when the
/// reader's text scale did. The empty `Text` moves because it is the text.
///
/// ## NOT A MESSAGE, AND WHY
///
/// The failed arm renders nothing rather than "streak unavailable". A sentence here
/// would be invented copy for a state the prototype never designed — the same
/// refusal as `_Beads`'s `noQuestionsToday` earns by *having* a string, and the
/// same refusal as `StreakFlameRow`'s three arms, where the streak's own failure is
/// an icon control named by `Failure.message` because a sentence does not belong in
/// a top bar. The gap is covered; the silence is not.
class _StreakSubtitle extends StatelessWidget {
  const _StreakSubtitle({required this.streak, required this.strings});

  /// The streak, or `null` while it is loading or failed.
  final StreakSummary? streak;

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final StreakSummary? summary = streak;

    return Padding(
      // The greeting block's own gap is `marginBottom: 24` on the *block*, so the
      // subtitle sits inside it and this row is separated from the panel by
      // `HomePage.panelGap` instead. See `HomePage`'s gap constants.
      padding: const EdgeInsets.only(bottom: EvaSpacing.xxl),
      child: Text(
        // Empty, not absent — see the class doc's measurement.
        summary == null
            ? ''
            : summary.currentStreak > 0
            ? strings.homeStreakGlowing
            : strings.homeStreakResting,
        // `HomeScreen.tsx:30` — `F.ui 14 / 400 / ink2 / marginTop 6`.
        //
        // Swapped for the ambient arm: on the Arabic arm this run is
        // `ابدأ سلسلة اليوم. يكفي قراءة واحدة.` and `bodyMedium` is DM Sans, which
        // carries no Arabic glyph at all.
        style: arabicAware(
          Theme.of(context).textTheme.bodyMedium!,
          Directionality.of(context),
        ).copyWith(color: context.colors.ink2),
      ),
    );
  }
}
