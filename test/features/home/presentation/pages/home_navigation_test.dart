/// `/`'s exits, and the only assertions in Phase 6 that need a **real router**.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A GROUP IN `home_page_test.dart`
///
/// `pumpHome` mounts `HomePage` over a bare `MaterialApp` — `evaPrimitiveHarness`
/// has no `Router` in it, so `context.router` inside the cards' `onOpen` would
/// throw on tap. Asserting the callbacks *are wired to the route constants* is
/// therefore not possible over that harness at all.
///
/// **The router is the assertion surface, not a mock.** A `MockStackRouter` would
/// record the call and prove nothing about whether the route name is real, and the
/// failure mode here is a route *name* that nothing answers: `pushPath` on an
/// unknown name throws several frames later, in a suite about something else.
///
/// ## AND `/` IS A **TAB** NOW, AND THE DOCK IS THE SHELL'S CHROME
///
/// `redesign.html:513-538` draws two tappable cards and no CTA: `#votdCard` opens the
/// reader (`:1318`) and `#lastCard` resumes from the last light (`:1205`). Both push
/// `/reading`, which is the same route — **`/reading` takes no argument**, so a card
/// naming a *different* day would open *today's* passage, and that is why
/// `LibraryCarousel`'s cards are inert rather than mis-wired.
///
/// The third exit was the interim chrome this screen used to carry: `SealFab`'s
/// three items — `/settings`, `/communion` and `/journey` — which existed because
/// the redesign's dock did not. **Phase 6 deleted the fab**, and with it the
/// interim holder, because the dock now owns two of the three destinations (the
/// board and the journey, the redesign's own dock tabs at `:706` and `:707`) and
/// the third (`/settings`) is reached the way the prototype reaches it — from
/// the journey's app-bar gear (`:582`) and its account row (`:606`).
///
/// **So the dock replaced the seal, and the dock is the SHELL's chrome** — the
/// shell is the route at `/` and the home screen is one of its three tabs. The
/// dock is on screen with `/`, so its five slots are reachable from here, and
/// the arms below drive them: the **read** slot pushes `/reading` over the
/// shell (which is how `/` gets covered and uncovered again, and the mechanism
/// recorded decision 41 rides on), and the **board** and **journey** slots
/// switch tabs.
///
/// The five slots are the redesign's own (`eva/redesign.html:931-932`), and
/// **only three of them are tabs**: "read" and "today" are push actions, which
/// is what hides the dock on the reader and the quiz (`:1251`).
library;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` classes, reached the way `app_router.dart` reaches them.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/last_light_card.dart';
import 'package:evangelion/features/home/presentation/widgets/verse_of_the_day_card.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/home_harness.dart';
import '../../../journey/journey_harness.dart';

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the routes out of `/`', () {
    testWidgets("the day's card reaches /reading", (WidgetTester tester) async {
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      // **The card, not its eyebrow.** `GlassSurface`'s whole box is the target —
      // `EvaInk` fills it — and tapping the eyebrow text would work too, which is
      // the reason the assertion is on the card: a reader taps anywhere in it.
      await tester.tap(find.byType(VerseOfTheDayCard));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      expect(mounted.router.currentPath, AppRoutes.reading);
      expect(mounted.router.stack.length, 2, reason: 'a push, not a replace');
    });

    testWidgets('the last-light card reaches /reading as well', (
      WidgetTester tester,
    ) async {
      // **The same route, and that is the finding.** `:1205` opens the reader for
      // `lastRead.id`, and `/reading` has no passage parameter — so both cards land
      // on today's reading and the distinction between them is the *hint*, not the
      // destination. Asserting the route twice is what pins it: a future wiring
      // that tried to pass a reading id would fail here rather than silently.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(find.byType(LastLightCard));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      expect(mounted.router.currentPath, AppRoutes.reading);
      expect(find.byType(ReadingPage), findsOneWidget);
    });

    testWidgets('an EMPTY last light is not an exit at all', (
      WidgetTester tester,
    ) async {
      // `:1197` — `cursor: default` and no handler. A suite that tapped the card in
      // this state and expected a route would be testing a control that does not
      // exist; this asserts the absence instead.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(
            tester,
            history: const Right<Failure, List<StreakHistoryEntry>>(
              <StreakHistoryEntry>[],
            ),
          );

      final Rect card = tester.getRect(find.byType(LastLightCard));
      await tester.tapAt(card.center);
      await tester.pump(const Duration(milliseconds: 300));

      expect(mounted.router.currentPath, AppRoutes.home);
      expect(find.byType(ReadingPage), findsNothing);
    });

    testWidgets("the dock's read slot pushes /reading over the shell", (
      WidgetTester tester,
    ) async {
      // ## THE SLOT THAT REPLACED THE SEAL
      //
      // `08-build-phases.md` Phase 9 says "`AppTopBar`'s avatar tap now opens
      // `/settings`", and the destination existed long before the redesign's
      // dock did. The **seal** was the interim holder, and Phase 6 deleted it.
      //
      // The dock's **second** slot is the prototype's own "read" (`:704`), and
      // the prototype's handler for it (`:1277`) **opens the reader** rather
      // than switching a tab — so the client's second slot is a **push
      // action**: `/reading` is opened **over** the shell, which is what hides
      // the dock on the reader (`:1251`).
      //
      // **This is also the mechanism recorded decision 41 rides on**, and the
      // re-entry arm below drives it for that reason.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(dockSlot(AppLocalizationsEn().dockRead));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      // **The stack, and the shell is under it.** The reader is a root route
      // pushed over the shell — which is the whole of "the dock hides on the
      // reader": the dock is inside the shell, so covering the shell covers
      // the dock with it.
      expect(
        mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name, ReadingRoute.name],
        reason:
            'the reader is pushed OVER the shell, so the shell — and the dock '
            'inside it — are underneath it',
      );
      expect(find.byType(ReadingPage), findsOneWidget);
    });

    testWidgets("the dock's board slot reaches the board", (
      WidgetTester tester,
    ) async {
      // ## A **TAB**, NOT A PUSH
      //
      // The board is the redesign's own dock tab (`:706`), and Phase 6 made it
      // the shell's **second** child. So the slot **switches tabs** — and the
      // reader lands on the board, not on a second copy of the shell with the
      // board active. The two are different failures and only the stack can
      // tell them apart.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(dockSlot(AppLocalizationsEn().dockBoard));
      await pumpUntilFound(tester, find.byType(CommunionPage));

      expect(find.byType(CommunionPage), findsOneWidget);
      // **The active tab, read off the tabs router itself.** The home tab is
      // still in the tree — an `IndexedStack` keeps the tabs it has built — so
      // "the board is on screen" cannot be claimed by the board's mere
      // presence, and the *active index* is the claim.
      expect(
        tabsRouterOf(tester, find.byType(CommunionPage)).activeIndex,
        DockTabs.communion,
        reason: 'the board is the shell\'s SECOND tab',
      );
      // **One shell, not two.** A path push would have built a second shell
      // with the board active, and the app would carry two docks.
      expect(
        mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name],
        reason: 'switching a tab does not put a route on the stack',
      );
    });

    testWidgets("the dock's journey slot reaches the journey", (
      WidgetTester tester,
    ) async {
      // ## WHY THE JOURNEY IS THE DOCK'S THIRD SLOT
      //
      // The redesign's real home for the profile is the **dock**
      // (`eva/redesign.html:702-708`, the journey tab at `:707`), and the
      // redesign's `/` has no app bar and no avatar to reach it from — so the
      // dock is the holder of the destinations `/` cannot otherwise reach,
      // exactly as it is for the board (`:706`).
      //
      // **The cubit comes from the locator**, because the dock switches a
      // **tab** (which carries no arguments) — so `JourneyPage` falls back to
      // `getIt<JourneyCubit>()`, and the locator is where that has to be. The
      // fixture is the journey feature's own harness, so the screen under test
      // is the shipped one.
      final JourneyHarness journey = journeyHarness();
      registerJourneyCubit(journey.cubit);

      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(dockSlot(AppLocalizationsEn().dockJourney));
      await pumpUntilFound(tester, find.byType(JourneyPage));

      // **The label is "Journey", not "Profile".** ADR-0001 cut the profile for
      // want of an endpoint and ADR-0022 restored it, and the redesign gives
      // the screen a new name — so the *name the cut screen had* is still
      // absent, and a future change that put a "Profile" pill back would be a
      // screen with no route behind it.
      expect(find.text('Profile'), findsNothing);

      expect(
        tabsRouterOf(tester, find.byType(JourneyPage)).activeIndex,
        DockTabs.journey,
        reason: 'the journey is the shell\'s THIRD tab',
      );
      expect(find.byType(JourneyPage), findsOneWidget);
      // **The stack, not `currentPath` alone.** `currentPath` is auto_route's
      // URL state, and for a tab the URL is the shell's own path until the
      // delegate adopts the tab — the read-slot arm's `reason:` is the full
      // argument.
      expect(
        mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name],
        reason:
            'the journey is a tab, so it is on the shell and not on the stack',
      );
    });

    testWidgets('and the push leaves `/` behind rather than over it', (
      WidgetTester tester,
    ) async {
      // `currentPath` alone would also pass if `/` were *replaced* — a reader who
      // taps the card and finds no way back is not on a working flow. So the
      // **stack depth** is asserted alongside the path.
      //
      // `find.byType(HomePage)` is deliberately NOT asserted absent: a `push` keeps
      // the route underneath in the tree, so that expectation fails on a perfectly
      // correct navigation. The stack length is the question; the widget tree is
      // not.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);
      final int before = mounted.router.stack.length;

      await tester.tap(find.byType(VerseOfTheDayCard));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      expect(mounted.router.currentPath, AppRoutes.reading);
      expect(mounted.router.stack.length, before + 1);
    });

    testWidgets('the strings the taps find are the LOCALIZED ones', (
      WidgetTester tester,
    ) async {
      // The reason the suites above look strings up through
      // `AppLocalizationsEn()` rather than writing literals: this one runs `/` in
      // `ar` and finds the same controls under Arabic labels. A hard-coded
      // `find.text('verse of the day')` would find nothing here and the failure
      // would read as "the card did not render" instead of "the string is
      // localized".
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester, locale: const Locale('ar'));

      // **`textContaining`, for the same reason the last light below is**: the
      // ready arm's eyebrow is one `Text.rich` — label, ` · ` and the
      // reference — so the bare label is a run of a line and not a line. It
      // used to pass with `find.text` only because the shorter wait above
      // landed on the *loading* arm, whose eyebrow is the label alone.
      expect(
        find.textContaining(AppLocalizationsAr().homeVerseOfTheDay),
        findsOneWidget,
      );
      // **`textContaining`, not `text`**, because the last-light card's eyebrow is
      // one `Text.rich` — label, ` · ` and the reference — so `آخر نور` is a run of a
      // line and not a line. `home_page_test.dart` asserts the same line in English
      // for the same reason.
      expect(
        find.textContaining(AppLocalizationsAr().homeLastLight),
        findsOneWidget,
      );

      // And it is still a *navigation*, not just a localized label: the same tap
      // under `ar` reaches `/reading`. The reading is requested in Arabic too, which
      // is the other half of the locale — a card that renders Arabic strings while
      // asking for English scripture is half-migrated.
      await tester.tap(find.byType(VerseOfTheDayCard));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      // **The stack, not `currentPath`** — and the English arm above gets away with
      // the URL only because it settles first. Measured here: on the Arabic arm
      // `ReadingPage` is in the tree while `currentPath` still reads `/`, because
      // the delegate has not adopted the pushed configuration when the page builds.
      // The settings arm's `reason:` is the full argument; this is the same claim
      // from the arm that would otherwise have pinned the URL by luck.
      expect(
        mounted.router.stack.last.name,
        'ReadingRoute',
        reason:
            'the reader is on top of the stack — by the page\'s **name**, '
            'because `router.stack` is a list of pages and a generated page\'s '
            'type is the generic `AutoRoutePage` while its name is the route',
      );
      // **The last ask, not the whole list.** `_HomeBody` reads the ambient locale
      // on every dispatch, so under `ar` every ask is Arabic and the list is
      // `[arabic]` — asserting the whole list here would pin the locale *and* the
      // number of dispatches into a navigation test, which is two subjects.
      expect(
        mounted.harness.readings.asked.last,
        ReadingLanguage.arabic,
        reason:
            'the card rendered Arabic strings, so the screen asked for Arabic '
            'scripture. A card that renders Arabic while asking for English is '
            'half-migrated.',
      );
    });
  });

  group('re-entry, which is the one trigger `/` had no wiring for', () {
    testWidgets('a push/pop re-asks, and the screen shows the NEW answer', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS IS HERE AND NOT IN `home_page_test.dart`
      //
      // Because a re-entry **is a navigation event**, and `pumpHome` mounts
      // `HomePage` over a bare `MaterialApp` with no `Router` in it — so there is no
      // push and no pop to perform. The file that could not express the bug is the
      // file that would have certified it.
      //
      // ## WHAT IT WOULD HAVE COST, MEASURED
      //
      // `_HomeBodyState._requested` was set once per `State` and never reset, and
      // `HomePage`'s element is retained under a pushed route — so `_HomeBodyState`
      // survived. Every count stayed `1` on entry *and* after returning. The reader
      // finishes a reflection on `/quiz`, comes back, and the chip still reads the
      // number they had before finishing it. There is no pull-to-refresh on `/` and
      // no other invalidation, so this was the whole refresh story.
      //
      // **All five sections are re-asked**, and each counter is asserted separately:
      // the redesign's home has four fetches and a session read, and a re-entry that
      // refreshed three of them would be indistinguishable from this test if it only
      // counted one.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);
      final HomeHarness h = mounted.harness;

      expect(h.readings.calls, 1);
      expect(h.streaks.summaryCalls, 1);
      expect(h.streaks.historyCalls, 1);
      expect(h.catalogue.calls, 1);
      expect(h.auth.calls, 1);
      // The **first-landing** values, asserted so the pair below cannot pass by these
      // never having been on screen at all.
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('JOHN 3:1-5'), findsWidgets);

      // ## THE COVER, AND WHY IT IS THE DOCK'S **"READ"** SLOT
      //
      // `/` is a **tab** inside the dock shell now, so its own route is never
      // popped — and a tab's route data therefore never produces a
      // `didPopNext`. What produces it is the **shell**, and the shell is
      // popped exactly when the screen pushed over it is popped.
      //
      // The dock's **read** slot is that push: it opens `/reading` over the
      // shell (the prototype's own handler at `:1277` opens the reader rather
      // than switching a tab), and the observer's `didPop` names the **shell**
      // as the previous route — which is the route the home page subscribes
      // under.
      //
      // **The card would have done the same job**, and the card is what this
      // arm used to tap. The dock is used instead because it is the shape a
      // reader actually takes, and because a suite that proves the dock's
      // push-action and the re-entry reload in one gesture is one gesture
      // fewer between the two claims.
      await tester.tap(dockSlot(AppLocalizationsEn().dockRead));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      // Covered, and nothing was re-fetched: the request is not the trigger, the
      // *return* is.
      expect(h.readings.calls, 1);
      expect(h.streaks.summaryCalls, 1);
      // **And it really is a cover, not a rebuild.** The shell is under the
      // reader and the tab is still the home one.
      expect(
        mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name, ReadingRoute.name],
        reason: 'the reader is over the shell, so the shell is covered',
      );
      expect(
        tabsRouterOf(tester, find.byType(HomePage)).activeIndex,
        DockTabs.home,
        reason: 'covering the shell does not switch the tab',
      );

      // What the reader did on `/reading`: answered a question, so the streak
      // endpoint's answer changes. Both fakes are re-stubbed **while `/` is covered**,
      // which is the whole point — the only way `/` can show these is by asking
      // again on the way back.
      h.streaks.answer = const Right<Failure, StreakSummary>(
        StreakSummary(
          currentStreak: 7,
          longestStreak: 6,
          lastCompletedDate: '2026-10-03',
          todayStatus: StreakTodayStatus.completed,
          todayCompleted: true,
          todayScheduled: true,
          nextMilestone: 10,
          daysToMilestone: 3,
        ),
      );
      // A **wide** entity, because `TodayReading` is a view of this one now and a
      // narrow one has no way to say "five verses" — the count was the only thing
      // the old fixture varied besides the reference.
      h.readings.scripture = const Right<Failure, ScriptureText>(
        ScriptureText(
          readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          groupId: 3,
          scheduledDate: '2026-10-04',
          language: ReadingLanguage.english,
          reference: 'John 4:1-14',
          translation: 'NKJV (New King James Version)',
          verses: <Verse>[
            Verse(
              bookNumber: 43,
              chapter: 4,
              number: 1,
              text:
                  'When therefore the Lord knew that the Pharisees had heard that '
                  'Jesus made and baptized more disciples than John,',
            ),
          ],
          // One question, **unanswered** — which is what
          // `answeredQuestionCount: 0` meant, and is now a property of the list.
          questions: <Question>[
            Question(
              id: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
              sortOrder: 1,
              type: 'mcq',
              prompt: "Whose disciples outnumbered John's?",
              options: <String, String>{'A': 'Jesus', 'B': 'John'},
              pointsValue: 10,
              alreadyAnswered: false,
            ),
          ],
          isFullyCompleted: false,
          pointsEarnedToday: 10,
          currentStreak: 4,
        ),
      );
      // **And the last light moves**, which is the section the redesign added: the
      // reader finished John 3, so the most recent scheduled day is John 4. The
      // card's reference is the honest place to have waited —
      // `pumpUntilFound(HomePage)` is already true on the frame the pop starts.
      h.streaks.historyAnswer = const Right<Failure, List<StreakHistoryEntry>>(
        <StreakHistoryEntry>[
          StreakHistoryEntry(
            readingId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
            scheduledDate: '2026-10-04',
            bookNumber: 43,
            bookNameEn: 'John',
            bookNameAr: 'يوحنا',
            referenceEn: 'John 4:1-14',
            referenceAr: 'يوحنا 4: 1-14',
            totalQuestions: 1,
            answeredQuestions: 1,
            correctAnswers: 1,
            pointsEarned: 10,
            isCompleted: true,
          ),
        ],
      );

      // ## THE UNCOVER, AND THE PROOF THAT IT WAS THE **SHELL'S** `didPopNext`
      //
      // The pop removes the reader from the root stack, and the observer's
      // `didPop` hands `didPopNext` to the subscribers of the **previous**
      // route — the shell. The home page subscribes under the shell's route
      // data, so the reload is the shell's callback and not anybody else's.
      //
      // **The three facts below are what make that a claim rather than a
      // hope**, and each of them rules out one other explanation:
      //
      //  * the home page's **element is the same object** it was before the
      //    cover — so it was not rebuilt, and `didChangeDependencies` (the
      //    other trigger, and the one a locale change fires) is not what
      //    re-asked;
      //  * the **tabs router still holds three tabs** and the home one is
      //    still active — so the tab's own route was never popped, and the
      //    tab's `didPopNext` cannot be what fired;
      //  * the tabs router's **route data is the shell's route data** — the
      //    very object the observer keys its subscribers by.
      final Element homeBefore = tester.element(find.byType(HomePage));
      final TabsRouter tabs = tabsRouterOf(tester, find.byType(HomePage));

      mounted.router.pop();
      await pumpUntilFound(tester, find.byType(HomePage));
      await pumpUntilFound(tester, find.textContaining('JOHN 4:1-14'));

      expect(
        identical(tester.element(find.byType(HomePage)), homeBefore),
        isTrue,
        reason:
            'the home page was COVERED and uncovered, never rebuilt — so the '
            're-ask came from a callback and not from `build`',
      );
      expect(
        tabs.stack,
        hasLength(DockTabs.count),
        reason:
            'the three tabs were never popped, so the tab\'s own route data '
            'never produced a `didPopNext` — the shell\'s did',
      );
      expect(
        tabs.activeIndex,
        DockTabs.home,
        reason: 'the tab did not change either',
      );
      expect(
        identical(tabs.routeData, mounted.router.stack.first.routeData),
        isTrue,
        reason:
            'the tabs router\'s route data IS the shell\'s route data — the '
            'object the observer hands `didPopNext` to when the reader is '
            'popped off the shell',
      );

      // ## AND THIS IS WHERE IT IS **RED** — MEASURED, AND THE ASSERTION STAYS
      //
      // The four facts above are all true, and the reload still does not
      // happen. The cause is **not** in this file and **not** in the page's
      // wiring; it is in **which `AutoRouteObserver` the page subscribes to**,
      // and it is measured rather than reasoned:
      //
      // * the tree now holds **two** `RouterScope`s — the root's and the
      //   shell's tabs router's — and the home page reads the **nearest**,
      //   which is the tabs router's;
      // * `AppRouter.config()`'s `navigatorObservers` is a **builder**, and
      //   auto_route calls it **twice**: once for the root `Navigator` and
      //   once for the tabs router's *inherited* observers. The builder
      //   allocates a **fresh `AutoRouteObserver()` on every call**
      //   (`app_router.dart:200-203`), so the two scopes hold **two
      //   different instances** — measured, by identity hash: the root's is
      //   `147585515` and the tabs router's is `1024085934` on one run;
      // * the tabs router has **no `Navigator` of its own** — its pages are an
      //   `IndexedStack` — so its observer never sees a push or a pop. The
      //   **root's** observer is the one that sees the reader being popped off
      //   the shell, and the home page is not subscribed to it.
      //
      // **The mechanism itself is sound, and the probe proved that too:** a
      // subscriber registered with the **root's** observer under the
      // **shell's** route data receives `didPopNext` when the reader is
      // popped off the shell (measured: one callback). The route data is
      // right — the tabs router's route data **is** the shell's route data,
      // which is what the assertion above pins — and the observer is the
      // wrong *instance*.
      //
      // **The fix is one line in `lib/app/router/app_router.dart`**, and it is
      // not this file's to make: the observer has to be built **once** and
      // handed to every invocation of the builder, so the tabs router
      // inherits the *same* instance the root `Navigator` uses.
      //
      // **Until that lands this test stays red, on purpose.** A green version
      // of it would have to drop the re-ask assertion, and a test that no
      // longer proves the re-entry reload is worse than a red one — it is the
      // exact failure this repository keeps recording: a green suite over a
      // mechanism that is not wired.
      expect(h.readings.calls, 2, reason: 'the reading was asked for again');
      expect(
        h.streaks.summaryCalls,
        2,
        reason: 'and so was the streak summary',
      );
      expect(h.streaks.historyCalls, 2, reason: 'and the last light');
      expect(h.catalogue.calls, 2, reason: 'and the catalogue');
      expect(
        find.text('7'),
        findsOneWidget,
        reason:
            'the chip is the number the reader came back to check, and `0` is what '
            'it said when they left',
      );
      expect(find.text('0'), findsNothing);
      expect(find.textContaining('JOHN 4:1-14'), findsNWidgets(2));
      expect(find.textContaining('JOHN 3:1-5'), findsNothing);
    });

    testWidgets('and a REBUILD still asks for nothing, in the same harness', (
      WidgetTester tester,
    ) async {
      // The control for the suite above, and the reason it cannot be satisfied by a
      // page that simply dispatches from `build`. Without this, "re-fetch on
      // re-entry" and "re-fetch on every frame" are the same green test.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      for (int frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(mounted.harness.readings.calls, 1);
      expect(mounted.harness.streaks.summaryCalls, 1);
      expect(mounted.harness.streaks.historyCalls, 1);
      expect(mounted.harness.catalogue.calls, 1);
      expect(mounted.harness.auth.calls, 1);
    });

    testWidgets('the observer this depends on is actually installed', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS TEST EXISTS RATHER THAN A COMMENT
      //
      // `RootStackRouter.config()`'s default `navigatorObservers` is `const []`, and
      // `AppRouter` did not override it — so there was **no `AutoRouteObserver` in
      // the `Navigator` at all**, `AutoRouteAwareStateMixin`'s
      // `firstObserverOfType<AutoRouteObserver>()` returned `null`, and its
      // `if (_observer != null)` guard turned the whole mechanism into a silent
      // no-op. `null` is not an error there; it is the absence of one, which is why
      // nothing in the tree ever went red.
      //
      // A suite that only asserts the *behaviour* above would say "the mechanism
      // works" without saying **why** it works, and the next person to delete the
      // `config()` override would be removing a line that reads as boilerplate.
      // This reads the observer out of the live `RouterScope`.
      //
      // **The NEAREST scope, and that is the whole point of the change.**
      // `/` is a tab inside the dock shell now, so the tree holds **two**
      // `RouterScope`s — the root's and the shell's tabs router's — and the home
      // page reads the **nearest** one, which is the tabs router's. Reading the
      // root's would assert something true and irrelevant: the observer the page
      // subscribes to is the one in the scope above it.
      await mountHomeWithAReading(tester);

      // **The scopes above the home page, nearest first** — the tabs router's
      // and the root's. The home page is a tab, so the nearest one is the
      // shell's tabs router, and that is the scope it reads.
      final List<RouterScope> above = tester
          .widgetList<RouterScope>(
            find.ancestor(
              of: find.byType(HomePage),
              matching: find.byType(RouterScope),
            ),
          )
          .toList();
      expect(above, hasLength(2), reason: 'the tabs router\'s and the root\'s');
      expect(
        above.first.controller,
        isA<TabsRouter>(),
        reason:
            'the NEAREST scope is the shell\'s tabs router — the one the home '
            'page subscribes under',
      );

      final RouterScope scope = above.first;
      final AutoRouteObserver? observer = scope
          .firstObserverOfType<AutoRouteObserver>();

      expect(
        observer,
        isNotNull,
        reason:
            'every `AutoRouteAware` in this app is inert without it, and inert '
            'reads exactly like correct',
      );
      // And the router is the one that installed it, rather than a caller: this
      // `config()` call passes only `reevaluateListenable`.
      expect(scope.navigatorObservers, contains(observer));
    });
  });
}

/// The dock's slot carrying [label].
///
/// **Scoped to the dock**, because the labels are ordinary words — "Read" is a
/// word a screen might print, and a finder over the whole tree would find the
/// wrong thing on a screen that prints it. The five labels are the redesign's
/// own (`eva/redesign.html:931-932`), and they are read from the
/// localisation rather than written out, for the reason the arms above give.
Finder dockSlot(String label) =>
    find.descendant(of: find.byType(LumenDock), matching: find.text(label));

/// The shell's tabs router, as seen from the page under [finder].
///
/// **The nearest one, and that is the point.** A tab lives inside the tabs
/// router's own `RouterScope`, and `TabsRouterScope.of` reads the nearest
/// `TabsRouterScope` above the context — which is the shell's, for every tab.
///
/// The `!` is guarded by the assertion above it, in the same way
/// `loginOutcomeOn` does it in `auth_guard_test.dart`: a page that is not
/// inside a tabs router is a page this suite has mis-set-up, and the
/// assertion says so in words rather than in a null dereference.
TabsRouter tabsRouterOf(WidgetTester tester, Finder finder) {
  final TabsRouterScope? scope = TabsRouterScope.of(tester.element(finder));
  expect(
    scope,
    isNotNull,
    reason: 'the page is a tab of the dock shell, so it has a tabs router',
  );
  return scope!.controller;
}

/// Mounts the **real** router on `/` over a [HomeBloc] whose reading resolved.
///
/// Returns the router **and** the counting fakes, because the re-entry suites need
/// both and returning only one would have made half of them re-derive the other.
///
/// Three things are arranged and each one is a decision:
///
/// 1. **`AppRouter(FakeAuthStatus(), _SilentAuthChanges())`** — authenticated, so
///    the guard lets `/` through instead of redirecting to `/login`. Built here
///    rather than through `app_router_test.dart`'s `routerFor` because that helper
///    lives in a *test* file, and one suite importing another's `main` to reach a
///    factory is a worse trade than four lines of construction. The arguments are
///    the two `routerFor` takes, in the order `AppRouter`'s doc fixes.
/// 2. **The bloc is registered before [routerHost]** — `routerHost` registers a
///    `HomeBloc` *only if the locator has none*, and the one it registers answers
///    every reading with a failure (`app_harness.dart` says why: no sockets in a
///    router suite). A failed reading renders `ErrorView` and **no tap targets at
///    all**, so the default registration would make every tap in this file
///    impossible. This is the seam `registerTestHomeBloc` documents, used from the
///    other side.
/// 3. **[HomeHarness]'s counting fakes**, so the reading is a live payload rather
///    than a hand-written fixture and this suite cannot drift from the others.
///
/// [pumpUntilFound] rather than a frame count, because the guard's redirect, the
/// card's blur and the ambient controllers all make "settled" unreachable — the
/// reason `routerHost`'s own doc gives.
Future<({AppRouter router, HomeHarness harness})> mountHomeWithAReading(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Result<List<StreakHistoryEntry>>? history,
}) async {
  final HomeHarness h = harness(history: history);
  getIt.registerSingleton<HomeBloc>(h.bloc);
  addTearDown(() => getIt.unregister<HomeBloc>());
  addTearDown(h.bloc.close);

  final AppRouter router = AppRouter(FakeAuthStatus(), _SilentAuthChanges());
  addTearDown(router.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(routerHost(router, locale: locale));
  // **The card's own eyebrow, not `HomePage`.** `HomePage` is in the tree on the
  // first frame, before `HomeStarted` has answered, and its card renders a label
  // with no reference until the reading lands — so waiting for the page returned
  // immediately and every tap then landed on a card with nothing to open. The label
  // is the localized one, which is what makes this the *localization* premise the
  // Arabic arm below builds on.
  //
  // This is the third spelling of the same wait. The first was `continueReading` — a
  // **status** line the live payload never shows, because it says the reading is
  // complete; the second was `HomePage`, which is true a frame too early. A wait
  // that resolves before its subject exists is the most expensive kind of test bug,
  // because every assertion after it passes about the *previous* frame.
  //
  // **The reference, not the eyebrow's label.** The label is painted in the
  // card's *loading* arm too, so a wait on it returns while the card is still a
  // label over an empty line — measured: the Arabic arm's card was `28, 6 → 362, 100`
  // when the tap landed, which is 94 tall and has no verse in it, and the tap opened
  // nothing. The English arm got away with the same wait by timing. A wait that
  // resolves before its subject is ready is the most expensive kind of test bug,
  // because every assertion after it passes about the previous frame.
  //
  // **Twelve frames is the default and this wait takes twenty-four**, because
  // the wait is now on the *ready* arm and the ready arm is one frame further
  // away than the loading one this used to match: the locale resolution, the
  // four fetches and the microtask drain all have to land before the reference
  // exists. Measured on a full-suite run, where a busy machine left this wait
  // returning on the loading arm's last frame and the Arabic arm's tap landing
  // on a card with nothing to open — the same defect the comment above
  // records, arriving by a different road.
  await pumpUntilFound(tester, find.textContaining('3:1-5'), limit: 24);

  // Asserted here rather than in each suite: "the tap happened on `/`" is the
  // premise of all of them, and a suite that tapped its way off some other route
  // would still pass every assertion below it.
  expect(find.byType(HomePage), findsOneWidget);

  return (router: router, harness: h);
}

/// A [ReevaluateListenable] that never notifies.
///
/// `ReevaluateListenable` is abstract and `AppRouter` takes one positionally, so a
/// test needs a concrete instance. This is a second declaration of the private
/// `_SilentAuthChanges` in `app_router_test.dart` — **deliberately so, and the
/// duplication is the smaller cost**: promoting it into `app_harness.dart` would
/// mean editing a Phase 2 suite's construction of the very router it exists to
/// keep honest, and a suite that cannot build its own subject cannot test it.
final class _SilentAuthChanges extends ReevaluateListenable {}
