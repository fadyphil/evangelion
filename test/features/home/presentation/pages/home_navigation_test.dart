/// `/`'s two exits, and the only assertions in Phase 6 that need a **real router**.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A GROUP IN `home_page_test.dart`
///
/// `pumpHome` mounts `HomePage` over a bare `MaterialApp` — `evaPrimitiveHarness`
/// has no `Router` in it, so `context.router` inside the panel's two callbacks
/// would throw on tap. Asserting the callbacks *are wired to the route constants*
/// is therefore not possible over that harness at all.
///
/// **The router is the assertion surface, not a mock.** A `MockStackRouter` would
/// record the call and prove nothing about whether the route name is real, and the
/// failure mode here is a route *name* that nothing answers: `pushPath` on an
/// unknown name throws several frames later, in a suite about something else.
library;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/app_top_bar.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/home_harness.dart';

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the two routes out of `/`', () {
    testWidgets('the panel\'s primary control reaches /reading', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(find.text(AppLocalizationsEn().homeContinueLabel));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      expect(mounted.router.currentPath, AppRoutes.reading);
    });

    testWidgets(
      'the avatar reaches /settings — the third route, added in Phase 9',
      (WidgetTester tester) async {
        // ## THE ROUTE `/`'s DECK NAMED FOR FOUR PHASES AND COULD NOT PUSH
        //
        // `08-build-phases.md` Phase 9 says "`AppTopBar`'s avatar tap now opens
        // `/settings`", so the destination exists and the call site was `null` until now.
        // Nothing about the avatar is special here — the point is that a control whose
        // accessibility test says **live** has a route, because
        // `home_accessibility_test.dart` proves the node offers `SemanticsAction.tap`
        // and this proves the tap goes somewhere. Either claim alone is satisfiable by a
        // control that navigates nowhere.
        final ({AppRouter router, HomeHarness harness}) mounted =
            await mountHomeWithAReading(tester);

        // **The avatar's own control, not the bar.** `AppTopBar` is a full-width `Row`,
        // so tapping *it* lands in the middle of the bar — nowhere near the 44x44 avatar
        // box — and the failure reads "nothing happened", which is indistinguishable from
        // "the route does not exist".
        //
        // **`EvaInk` and not `IconActionButton`,** because the avatar is not one: it is a
        // private `_Avatar` wrapping its badge in `EvaFocusRing` + `EvaInk`, and the bar
        // holds exactly one `EvaInk`. The first attempt looked for `IconActionButton`
        // because the disabled-avatar arms in `app_top_bar_test.dart` name that type — the
        // *accessible* avatar is one, the *visible* one is this.
        final Finder avatar = find.descendant(
          of: find.byType(AppTopBar),
          matching: find.byType(EvaInk),
        );
        expect(
          avatar,
          findsOneWidget,
          reason: 'the bar holds exactly one control',
        );

        await tester.tap(avatar);
        await pumpUntilFound(tester, find.byType(SettingsPage));

        expect(
          mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
          <String>['HomeRoute', 'SettingsRoute'],
          reason:
              'the **stack**, not `currentPath`. `currentPath` is auto_route\'s URL '
              'state, and for a pushed page over a route whose args are optional the URL '
              'is the *root* path until the delegate adopts the pushed configuration — '
              'measured here, after two settled pumps with `SettingsRoute` on the stack. '
              'The stack is what "the avatar navigated" actually means, and the two '
              '`/reading` and `/quiz` arms above are the ones that pinned the URL.',
        );
        expect(find.byType(SettingsPage), findsOneWidget);
      },
    );

    testWidgets('the secondary control reaches /quiz', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);

      await tester.tap(find.text(AppLocalizationsEn().homeStartReflection));
      await pumpUntilFound(tester, find.byType(QuizPage));

      expect(mounted.router.currentPath, AppRoutes.quiz);
    });

    testWidgets('and the push leaves `/` behind rather than over it', (
      WidgetTester tester,
    ) async {
      // `currentPath` alone would also pass if `/` were *replaced* — a reader who
      // taps Start reflection and finds no way back is not on a working flow. So
      // the **stack depth** is asserted alongside the path.
      //
      // `find.byType(HomePage)` is deliberately NOT asserted absent: a `push` keeps
      // the route underneath in the tree, so that expectation fails on a perfectly
      // correct navigation. The stack length is the question; the widget tree is
      // not.
      //
      // `/quiz` is the destination that matters: Phase 5 replaced it with a
      // placeholder, and a push that lands on a placeholder is the most likely way
      // for this suite to rot.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);
      final int before = mounted.router.stack.length;

      await tester.tap(find.text(AppLocalizationsEn().homeStartReflection));
      await pumpUntilFound(tester, find.byType(QuizPage));

      expect(mounted.router.currentPath, AppRoutes.quiz);
      expect(mounted.router.stack.length, before + 1);
      expect(find.byType(QuizPage), findsOneWidget);
    });

    testWidgets('the labels the taps find are the LOCALIZED ones', (
      WidgetTester tester,
    ) async {
      // The reason the three suites above look the labels up through
      // `AppLocalizationsEn()` rather than writing literals: this one runs `/` in `ar`
      // and finds the same two controls under Arabic labels. A hard-coded
      // `find.text('Start reflection')` would find nothing here and the failure
      // would read as "the panel did not render" instead of "the string is
      // localized".
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester, locale: const Locale('ar'));

      expect(find.text(AppLocalizationsAr().homeContinueLabel), findsOneWidget);
      expect(
        find.text(AppLocalizationsAr().homeStartReflection),
        findsOneWidget,
      );

      // And it is still a *navigation*, not just a localized label: the same tap
      // under `ar` reaches `/quiz`. The reading is requested in Arabic too, which
      // is the other half of the locale — a panel that renders Arabic strings
      // while asking for English scripture is half-migrated.
      await tester.tap(find.text(AppLocalizationsAr().homeStartReflection));
      await pumpUntilFound(tester, find.byType(QuizPage));

      expect(mounted.router.currentPath, AppRoutes.quiz);
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
      // push and no pop to perform. `home_page_test.dart`'s replacement for the old
      // `loads once, on entry, and not again on rebuild` test kept only the half that
      // is expressible without a router (extra `pump()`s) and **certified the wrong
      // half**: a rebuild is not a re-entry, and the extra pumps did not even rebuild
      // `_HomeBody`. So the file that could not express the bug was the file that
      // asserted the fix.
      //
      // ## WHAT IT WOULD HAVE COST, MEASURED
      //
      // `_HomeBodyState._started` was set once per `State` and never reset, and
      // `HomePage`'s element is retained under a pushed route — so `_HomeBodyState`
      // survived. `readings=1 streaks=1` on entry *and* after returning. The reader
      // finishes a reflection on `/quiz`, comes back, and the flame still reads the
      // number they had before finishing it. There is no pull-to-refresh on `/` and
      // no other invalidation, so this was the whole refresh story.
      final ({AppRouter router, HomeHarness harness}) mounted =
          await mountHomeWithAReading(tester);
      final HomeHarness h = mounted.harness;

      expect(mounted.harness.readings.calls, 1);
      expect(mounted.harness.streaks.calls, 1);
      // The **first-landing** values, asserted so the pair below cannot pass by
      // these never having been on screen at all.
      expect(find.text('0'), findsOneWidget);
      expect(find.text('John 3:1-5'), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().homeContinueLabel));
      await pumpUntilFound(tester, find.byType(ReadingPage));

      // Covered, and nothing was re-fetched: the request is not the trigger, the
      // *return* is.
      expect(h.readings.calls, 1);
      expect(h.streaks.calls, 1);

      // What the reader did on `/reading`: answered a question, so the streak
      // endpoint's answer changes. Both fakes are re-stubbed **while `/` is covered**,
      // which is the whole point — the only way `/` can show these is by asking
      // again on the way back.
      h.streaks.answer = const Result<StreakSummary>.success(
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
      h.readings.scripture = const Result<ScriptureText>.success(
        ScriptureText(
          readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          groupId: 3,
          scheduledDate: '2026-10-03',
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

      mounted.router.pop();
      await pumpUntilFound(tester, find.byType(HomePage));
      // The panel's own reference, which is the last thing the re-fetch writes and
      // therefore the honest place to have waited: `pumpUntilFound(HomePage)` is
      // already true on the frame the pop starts.
      await pumpUntilFound(tester, find.text('John 4:1-14'));

      expect(h.readings.calls, 2, reason: 'the reading was asked for again');
      expect(h.streaks.calls, 2, reason: 'and so was the streak');
      expect(
        find.text('7'),
        findsOneWidget,
        reason:
            'the flame is the number the reader came back to check, and `0` is what '
            'it said when they left',
      );
      expect(find.text('0'), findsNothing);
      expect(find.text('John 4:1-14'), findsOneWidget);
      expect(find.text('John 3:1-5'), findsNothing);
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
      expect(mounted.harness.streaks.calls, 1);
      expect(mounted.harness.auth.calls, 1);
    });

    testWidgets('the observer this depends on is actually installed', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS TEST EXISTS RATHER THAN A COMMENT
      //
      // `RootStackRouter.config()`'s default `navigatorObservers` is `const []`, and
      // `AppRouter` did not override it — so there was **no `AutoRouteObserver` in the
      // `Navigator` at all**, `AutoRouteAwareStateMixin`'s
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
///    router suite). A failed reading renders `ErrorView` and **no controls at
///    all**, so the default registration would make both taps impossible. This is
///    the seam `registerTestHomeBloc` documents, used from the other side.
/// 3. **[HomeHarness]'s counting fakes**, so the reading is a live payload rather
///    than a hand-written fixture and this suite cannot drift from the others.
///
/// [pumpUntilFound] rather than a frame count, because the guard's redirect, the
/// panel's blur and the ambient controllers all make "settled" unreachable — the
/// reason `routerHost`'s own doc gives.
Future<({AppRouter router, HomeHarness harness})> mountHomeWithAReading(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final HomeHarness h = harness();
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
  // **The panel's own control, not `HomePage`.** `HomePage` is in the tree on the
  // first frame, before `HomeStarted` has answered, and its panel renders nothing
  // but the frame until the reading lands — so waiting for the page returned
  // immediately and every tap then failed to find its label. `pumpUntilFound` on the
  // control waits for the state this suite is about.
  //
  // `continueLabel` and not `continueReading`: the latter is the panel's **status**
  // line, and it is only shown when the reading is *not* complete. The live payload
  // says `is_fully_completed: true`, so the status line reads `readingComplete` and
  // a wait on `continueReading` is a wait for a string this screen never renders.
  // That is the first version, and it is why the first two suites failed with
  // "could not find any matching widgets" while the harness reported success.
  await pumpUntilFound(
    tester,
    find.text(lookupAppLocalizations(locale).homeContinueLabel),
  );

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
