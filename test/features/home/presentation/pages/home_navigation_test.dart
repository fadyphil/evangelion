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
/// ## AND `/` HAS **TWO** EXITS NOW, BOTH TO THE SAME PLACE
///
/// `redesign.html:513-538` draws two tappable cards and no CTA: `#votdCard` opens the
/// reader (`:1318`) and `#lastCard` resumes from the last light (`:1205`). Both push
/// `/reading`, which is the same route — **`/reading` takes no argument**, so a card
/// naming a *different* day would open *today's* passage, and that is why
/// `LibraryCarousel`'s cards are inert rather than mis-wired.
///
/// The third exit is the interim chrome this screen still carries: `SealFab`'s two
/// items, `/settings` and `/leaderboard`, which exist because Phase 6's dock does
/// not yet. Phase 6 deletes the fab and this suite's arms with it.
library;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/last_light_card.dart';
import 'package:evangelion/features/home/presentation/widgets/seal_fab.dart';
import 'package:evangelion/features/home/presentation/widgets/verse_of_the_day_card.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/home_harness.dart';

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

    testWidgets("the seal's settings item reaches /settings", (
      WidgetTester tester,
    ) async {
      // ## THE ROUTE `/`'s DECK NAMED FOR FOUR PHASES AND COULD NOT PUSH
      //
      // `08-build-phases.md` Phase 9 says "`AppTopBar`'s avatar tap now opens
      // `/settings`", so the destination exists. `HomePage` no longer has an avatar
      // — the redesign's greeting block (`:514-517`) is a caption, a name and a
      // streak chip — so the fab is the interim holder, and this arm is what keeps
      // `/settings` reachable while Phase 6's dock does not exist.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      // **The dial, then the pill.** The fab is a shutter: its items are not in the
      // tree until `SealFabTrigger` is pressed — `seal_fab_test.dart`'s group says
      // `findsNothing` for a pill on a shut dial — so tapping the item directly finds
      // nothing and reads as a dead route rather than as a closed menu.
      await tester.tap(find.byType(SealFabTrigger));
      await pumpUntilFound(
        tester,
        find.text(AppLocalizationsEn().sealFabSettings),
      );
      await tester.tap(find.text(AppLocalizationsEn().sealFabSettings));
      await pumpUntilFound(tester, find.byType(SettingsPage));

      expect(
        mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>['HomeRoute', 'SettingsRoute'],
        reason:
            'the **stack**, not `currentPath`. `currentPath` is auto_route\'s URL '
            'state, and for a pushed page over a route whose args are optional the '
            'URL is the *root* path until the delegate adopts the pushed '
            'configuration — measured here, after two settled pumps with '
            '`SettingsRoute` on the stack. The stack is what "the seal navigated" '
            'actually means.',
      );
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets("and the seal's board item reaches /leaderboard", (
      WidgetTester tester,
    ) async {
      // **The route's current name.** Task 5.5 renames it to `/communion`
      // (`redesign.html:612-636`) and this arm moves with it; asserted today so the
      // rename cannot land without a navigation suite noticing.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(find.byType(SealFabTrigger));
      await pumpUntilFound(
        tester,
        find.text(AppLocalizationsEn().sealFabLeaderboard),
      );
      await tester.tap(find.text(AppLocalizationsEn().sealFabLeaderboard));
      await pumpUntilFound(tester, find.byType(LeaderboardPage));

      expect(mounted.router.currentPath, AppRoutes.leaderboard);
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

      await tester.tap(find.byType(VerseOfTheDayCard));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      // Covered, and nothing was re-fetched: the request is not the trigger, the
      // *return* is.
      expect(h.readings.calls, 1);
      expect(h.streaks.summaryCalls, 1);

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

      mounted.router.pop();
      await pumpUntilFound(tester, find.byType(HomePage));
      await pumpUntilFound(tester, find.textContaining('JOHN 4:1-14'));

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
      await mountHomeWithAReading(tester);

      final RouterScope scope = tester
          .widgetList<RouterScope>(find.byType(RouterScope))
          .first;
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
