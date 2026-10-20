/// The quiz's terminal arm, and the **modal** it opens.
///
/// ## WHY THIS IS A SEPARATE FILE AND NOT A GROUP IN `quiz_page_test.dart`
///
/// `pumpQuiz` mounts `QuizPage` over a bare `MaterialApp` — `evaPrimitiveHarness`
/// has no `Router` in it, so `context.router` inside the page would throw on
/// tap. **The sheet's "Back home" is a route**, so the arm that opens the sheet
/// cannot be asserted over that harness at all: the reader has to be able to
/// press a button that navigates.
///
/// So this file drives the **real router**, the way `home_navigation_test.dart`
/// does for `/`'s exits, and the router is the assertion surface rather than a
/// mock. A `MockStackRouter` would record the call and prove nothing about
/// whether the route name is real.
///
/// ## WHAT IS BEING CLAIMED, AND IT IS FOUR CLAIMS
///
/// 1. **The terminal arm opens the sheet.** `QuizCta.seeResults` is the last
///    graded question's one press (`eva/redesign.html:1431-1432`), and the
///    result is a **card over a veil** rather than a route — Phase 6.2.
/// 2. **The reader can dismiss it and carry on.** The barrier is a control, and
///    dismissing the sheet leaves the quiz **on screen and alive**: same bloc,
///    same session, same question.
/// 3. **Each CTA closes the sheet and then acts**, so the reader ends up in
///    exactly one place with **no dialog left on screen**. This is the part the
///    modal changed: as a page, the CTAs were `replacePath('/quiz')` and
///    `replacePath('/')`, and inside a dialog the same calls would leave a
///    dialog over a replaced route.
/// 4. **"Back home" REPLACES the stack; it does not push a second shell.**
///    `/` is the dock shell and the shell is **already** on the root stack
///    under the quiz, so a `replacePath('/')` removed the quiz and pushed a
///    **fresh match** of `/` — a second shell, a second dock, and a back press
///    that revealed the same home screen again. The stack is the assertion
///    surface, because a path cannot say how many shells are on it.
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/quiz/presentation/widgets/result_sheet.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/quiz_harness.dart';

void main() {
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  final AppLocalizationsEn en = AppLocalizationsEn();

  group('the terminal arm opens the sheet, and the sheet is a MODAL', () {
    testWidgets('the sheet appears over the quiz, not as a new route', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, QuizBloc bloc}) mounted = await mountAQuiz(
        tester,
      );

      // **The precondition, stated as an assertion.** The terminal arm is
      // `seeResults`, and it is only reachable with a graded answer in hand —
      // so a sheet that did not open would be indistinguishable from a quiz
      // that never reached the arm.
      expect(mounted.bloc.state.cta, QuizCta.seeResults);

      await tester.tap(find.text(en.quizSeeResults));
      await pumpUntilFound(tester, find.byType(ResultSheet));

      expect(find.byType(ResultSheet), findsOneWidget);
      // **The quiz is still there, underneath.** The result is a card over the
      // quiz, not a replacement of it — and this is the first half of claim 2.
      expect(find.byType(QuizPage), findsOneWidget);
      // **And it is not a route.** The stack did not grow: the sheet is a
      // dialog on the navigator, and the router's own stack is untouched.
      expect(
        mounted.router.currentPath,
        AppRoutes.quiz,
        reason: 'the result is a modal, and a modal is not a route',
      );
    });

    testWidgets('and the barrier is a NAMED control, so a screen reader can '
        'dismiss it', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await mountAQuiz(tester);

      await tester.tap(find.text(en.quizSeeResults));
      await pumpUntilFound(tester, find.byType(ResultSheet));

      // **The scrim is a control**, and §14's first row is a control with no
      // accessible name. The barrier's name is Material's own word for it, and
      // `showGeneralDialog` was handed exactly that word — so the dismissal
      // route is announced rather than being an unlabelled region a screen
      // reader walks past.
      //
      // **The word is read off the localizations and not spelled out here**,
      // because a hard-coded "Dismiss" would be a second copy of a string the
      // framework owns and a test that fails when the framework's wording
      // changes.
      final BuildContext context = tester.element(find.byType(ResultSheet));
      expect(
        find.bySemanticsLabel(
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
        ),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('and dismissing it leaves the quiz alive', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, QuizBloc bloc}) mounted = await mountAQuiz(
        tester,
      );

      await tester.tap(find.text(en.quizSeeResults));
      await pumpUntilFound(tester, find.byType(ResultSheet));
      expect(find.byType(ResultSheet), findsOneWidget);

      // **The barrier, not a button.** The sheet is dismissible the way a modal
      // is: the scrim is a control, and a reader who does not want the card
      // taps outside it. The top-left corner is outside the card — the card is
      // 82% wide and centred (`:444`), so the corner is the veil.
      await tester.tapAt(const Offset(4, 4));
      await pumpUntilGone(tester, find.byType(ResultSheet));

      expect(find.byType(ResultSheet), findsNothing);
      // **The quiz is still on screen**, and still the same one.
      expect(find.byType(QuizPage), findsOneWidget);
      expect(
        mounted.bloc.state.cta,
        QuizCta.seeResults,
        reason:
            'the session is untouched: dismissing a card is not an answer and '
            'not an advance, so the reader can carry on from where they were',
      );
      expect(mounted.router.currentPath, AppRoutes.quiz);
    });
  });

  group('each CTA CLOSES the sheet and then acts', () {
    testWidgets('"Reflect again" restarts the quiz and leaves no dialog', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, QuizBloc bloc}) mounted = await mountAQuiz(
        tester,
      );

      await tester.tap(find.text(en.quizSeeResults));
      await pumpUntilFound(tester, find.byType(ResultSheet));

      await tapTheSheetCta(tester, en.resultReflectAgain);
      await pumpUntilGone(tester, find.byType(ResultSheet));

      // **No dialog left on screen.** The order is the whole of it: the button
      // pops the sheet with the action and the page acts afterwards, so a
      // `replacePath` inside a dialog would have left the dialog over the
      // replaced route.
      expect(find.byType(ResultSheet), findsNothing);
      // **And the quiz is still the screen** — "reflect again" is *this* quiz,
      // restarted, not a new route.
      expect(find.byType(QuizPage), findsOneWidget);
      expect(mounted.router.currentPath, AppRoutes.quiz);
      // **Restarted, and not merely dismissed.** The session is rebuilt from
      // the fresh read, so the cursor is back at the first question.
      expect(mounted.bloc.state.currentIndex, 0);
    });

    testWidgets('"Back home" goes home and leaves no dialog', (
      WidgetTester tester,
    ) async {
      final ({AppRouter router, QuizBloc bloc}) mounted = await mountAQuiz(
        tester,
      );

      await tester.tap(find.text(en.quizSeeResults));
      await pumpUntilFound(tester, find.byType(ResultSheet));

      await tapTheSheetCta(tester, en.resultBackHome);
      await pumpUntilGone(tester, find.byType(ResultSheet));

      // **The one place the reader ends up.**
      expect(find.byType(ResultSheet), findsNothing);
      expect(mounted.router.currentPath, AppRoutes.home);
      // **And the quiz is gone with it** — the reader left the quiz, and a
      // dialog left over on top of the home screen would be the failure this
      // asserts the absence of. The quiz's own page leaves on a transition, so
      // the wait is for the **page** to be gone rather than for the route.
      await pumpUntilGone(tester, find.byType(QuizPage));
      expect(find.byType(QuizPage), findsNothing);
    });
  });

  group('"Back home" REPLACES the stack, it does not push a second shell', () {
    testWidgets(
      'the reader lands on ONE shell, on the home tab, and a back press does '
      'not bring the same screen back',
      (WidgetTester tester) async {
        final ({AppRouter router, QuizBloc bloc}) mounted = await mountAQuiz(
          tester,
        );

        await tester.tap(find.text(en.quizSeeResults));
        await pumpUntilFound(tester, find.byType(ResultSheet));

        await tapTheSheetCta(tester, en.resultBackHome);
        await pumpUntilGone(tester, find.byType(ResultSheet));
        await pumpUntilFound(tester, find.byType(LumenDock));

        // ## **ONE ROUTE ON THE ROOT STACK, AND IT IS THE SHELL.**
        //
        // `/` is the **dock shell**, and the shell was **already** on the root
        // stack — under the quiz. So the CTA has to *replace* the stack, not
        // push a fresh match of `/` on top of it.
        //
        // The old code did the latter, and the stack became
        // `[DockShellRoute, DockShellRoute]`: **two shells**, and a back press
        // that popped the top one and left the reader looking at **the same
        // home screen again**, with the path still `/`.
        expect(
          mounted.router.stack.map((AutoRoutePage<Object?> page) => page.name),
          <String>[DockShellRoute.name],
          reason:
              'the shell was already on the stack under the quiz, so "back '
              'home" has to leave ONE shell — a second one is a second dock, '
              'and a back press away from showing the same home screen twice',
        );

        // ## **AND ONE DOCK ON SCREEN.**
        //
        // The reader-visible half of the claim above. **The stack is where two
        // shells show up**, because the `Navigator` only builds the topmost
        // opaque page — so the dock count is one either way, and it is the
        // stack that says there was a second shell underneath.
        expect(find.byType(LumenDock), findsOneWidget);

        // ## **AND THE READER IS ON THE HOME TAB.**
        //
        // The label says "back home", so the tab index has to be the home one
        // — and it is read off the **tabs router**, because a tab is not a
        // route and the root stack cannot say which tab is in front.
        expect(_activeTab(tester), DockTabs.home);

        // ## **AND A BACK PRESS DOES NOT REVEAL THE SAME SCREEN AGAIN.**
        //
        // The old symptom, measured: the stack was
        // `[DockShellRoute, DockShellRoute]`, so the back press popped the top
        // one and left the reader looking at **the same home screen again** —
        // the path was still `/` and the screen had not changed.
        //
        // So the claim is that a back press from here pops **nothing**: there
        // is one shell, and the home tab is the floor.
        final int before = mounted.router.stack.length;
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          mounted.router.stack.length,
          before,
          reason:
              'a back press popped a route, so what it revealed was the SAME '
              'home screen again — the old defect. One shell on the home tab '
              'is the floor, and a back press from the floor pops nothing.',
        );
        // **And the reader is still on the one home screen**, with the path
        // still `/` — the same screen, not a second copy of it.
        expect(find.byType(HomePage), findsOneWidget);
        expect(mounted.router.currentPath, AppRoutes.home);
      },
    );
  });
}

/// The dock shell's **active tab**, read from the tree.
///
/// **The index, and not the presence of a page.** The tabs router keeps every
/// tab's page in the tree — the inactive ones inside the `IndexedStack`'s
/// offstage children — so "the home screen is there" is not "the reader is on
/// the home tab".
///
/// **`skipOffstage: false`, and it is load-bearing.** An inactive tab's page is
/// offstage, and `find.byType` skips offstage widgets by default — so the
/// default finder would find **nothing** exactly when the reader has left the
/// home tab, and the helper would throw on the very tab switch it exists to
/// measure. The home tab is the one the shell is built on, and it stays in the
/// tree after the reader leaves it.
int _activeTab(WidgetTester tester) => TabsRouterScope.of(
  tester.element(find.byType(HomePage, skipOffstage: false)),
)!.controller.activeIndex;

/// Taps the sheet's CTA, **scrolling the card to it first**.
///
/// ## WHY THE SCROLL IS PART OF THE TAP
///
/// The card's content is the client's own — a 100px burst, a 68px score, a
/// sentence, a streak pill, two stat tiles and two buttons — and on a short
/// surface that is **more than the card's height**, so the card scrolls and
/// the CTAs are below the fold. A reader scrolls to the control; so does this.
///
/// **The first version tapped the label where it was**, and the tap landed on
/// the card's own padding: Flutter reported "an Offset that would not hit test
/// on the specified widget", the press did nothing, and the sheet stayed open.
/// A test that presses a control the reader cannot reach is not a test of the
/// control.
Future<void> tapTheSheetCta(WidgetTester tester, String label) async {
  final Finder cta = find.text(label);
  await tester.ensureVisible(cta);
  await tester.pump();
  await tester.tap(cta);
}

/// Mounts the real router with a quiz on it, graded and ready to show its
/// result.
///
/// **The grading is done here, not in each test**, because it is four presses
/// and a submission, and every test in this file needs the same terminal arm.
/// The `QuizBloc` comes back so a caller can assert on the state the presses
/// produced.
Future<({AppRouter router, QuizBloc bloc})> mountAQuiz(
  WidgetTester tester,
) async {
  final QuizBloc bloc = quizBloc(
    const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
    submission: defaultSubmission,
  );

  final AppRouter router = AppRouter(FakeAuthStatus(), ManualAuthChanges());
  addTearDown(router.dispose);

  await tester.pumpWidget(routerHost(router));

  unawaited(router.push<void>(QuizRoute(bloc: bloc)));
  await pumpUntilFound(tester, find.byType(QuizPage));

  // **The question, not the page.** `QuizPage` is on screen before its session
  // has loaded, so waiting for it returns a frame too early and the tap lands
  // on nothing. The option's own text is the thing that has to be there.
  await pumpUntilFound(tester, find.text(liveEnglishQuestion.options['A']!));

  // **Choose an answer.** The live question's own option text, so the tap
  // lands on the card rather than on a letter.
  await tester.tap(find.text(liveEnglishQuestion.options['A']!));
  await pumpQuizFrames(tester, 2);

  // **And grade it.** The fake answers synchronously with the contract
  // fixture, so the response is in hand one frame later and the terminal arm
  // is live.
  await tester.tap(find.text(AppLocalizationsEn().quizCheckAnswer));
  await pumpQuizFrames(tester, 6);

  return (router: router, bloc: bloc);
}
