/// The behaviour of `/journey` — the reader's own journey.
///
/// ## WHAT THIS FILE IS, AND WHAT IT IS NOT
///
/// The **widget** suite (`journey_widgets_test.dart`) proves what the nine
/// widget files do; the **geometry** suite (`journey_geometry_test.dart`)
/// measures the numbers this screen owns; the **glyph** suite reads the
/// prototype's codepoints back. None of them can say what a **reader** is
/// shown.
///
/// This file is the one that can. It mounts the real page on the real router
/// and answers three questions:
///
/// 1. **which arm is on screen** — the spinner, the column, or the error view;
/// 2. **what the column says** — and the answer is asserted as *numbers*, not
///    as the presence of a widget, because a suite that only asserted "there is
///    a rings row" would pass with every ring wrong;
/// 3. **what the controls do** — the two live rows go where they say, the two
///    dead ones do not go anywhere and say why, and the journey is a **tab**,
///    so it has no chevron and the board is a tab switch rather than a push.
///
/// ## THE FIXTURE IS CHOSEN, NOT INHERITED
///
/// `journey_harness.dart` carries the arithmetic: four scheduled days, two of
/// them completed, twenty-five questions answered and twenty-one of them
/// right. Every figure below is derived from those four rows, and **every one
/// of them differs from the prototype's own literal** — `83%`, `86`, `92%` and
/// the hero's `12` — because a suite whose expectations are the prototype's
/// numbers cannot tell a derived figure from a transcribed one.
///
/// ## AND THE FINDERS ARE SCOPED
///
/// The journey is a **tab** of the dock shell, and the shell's own chrome — the
/// five-slot dock, with its labels — stands beside it in the tree. So every
/// finder that could also match the shell is scoped to [JourneyPage], or the
/// assertion would be about the screen and the dock at once: the app bar's
/// title and the dock's journey slot are the same word.
library;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
// The generated `*Route` names, reached the same way `app_router.dart` reaches
// them: through the generated library.
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/navigation/dock_tabs.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_account_rows.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_app_bar.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_hero_number.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_medals_strip.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_rings_row.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_section_labels.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_sky_line.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../support/app_harness.dart';
import '../../support/design_system_harness.dart';
import 'journey_harness.dart';

/// Every string the rings row painted, in tree order.
///
/// **The order is the screen's**: the row is a `Row` of three ring boxes, and
/// each box paints its **value** and then its **label** — the value inside the
/// ring (`:407`'s `margin-top:-34px`) and the label under it (`:408`'s
/// `margin-top:16px`). So the list is value, label, value, label, value, label,
/// and asserting the whole list is what pins the *pairing* as well as the
/// numbers: a suite that asserted "50% is on screen" would not notice the
/// label that came with it.
List<String> _ringTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(JourneyRingsRow),
        matching: find.byType(Text),
      ),
    )
    .map((Text text) => text.data ?? '')
    .toList();

/// The journey's own subtree.
///
/// **Scoped on purpose.** The journey is a tab of the dock shell, and the
/// shell's chrome stands beside it — the dock's five labels, and the app bar's
/// title, which is the same word as the dock's journey slot. An unscoped
/// finder would be about the screen and the shell at once.
Finder _onJourney(Finder matching) =>
    find.descendant(of: find.byType(JourneyPage), matching: matching);

/// The dock shell's **active tab**, read from the tree.
///
/// **The index, and not the presence of a page.** The tabs router keeps every
/// tab's page in the tree — the inactive ones inside the `IndexedStack`'s
/// offstage children — so "the board is on screen" is not "a `CommunionPage`
/// exists": the journey's own page is still there after the reader moves to
/// the board. The index is the only thing that says which screen is in front.
///
/// **`skipOffstage: false`, and it is load-bearing.** An inactive tab's page
/// is offstage, and `find.byType` skips offstage widgets by default — so the
/// default finder would find **nothing** exactly when the reader has left the
/// journey, and the helper would throw on the very tab switch it exists to
/// measure.
int _activeTab(WidgetTester tester) => TabsRouterScope.of(
  tester.element(find.byType(JourneyPage, skipOffstage: false)),
)!.controller.activeIndex;

void main() {
  group('the loading arm', () {
    testWidgets('shows a spinner, and none of the figures', (
      WidgetTester tester,
    ) async {
      // The summary **never answers**, so the cubit is held in its loading arm.
      // A repository that answered on the first microtask drain would be past
      // this arm by the time the first `pump()` returned, and the spinner would
      // never be on screen to be asserted on.
      final JourneyHarness harness = journeyHarness(holdSummary: true);
      await pumpJourney(tester, harness);

      expect(
        _onJourney(find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
      expect(_onJourney(find.byType(ErrorView)), findsNothing);

      // **And the figures are not on screen.** A reader who is told their
      // streak is zero while the request is still open has been told a lie —
      // the argument `JourneyStatus`'s own doc gives for three values.
      expect(_onJourney(find.byType(JourneyHeroNumber)), findsNothing);
      expect(_onJourney(find.byType(JourneyRingsRow)), findsNothing);
      expect(_onJourney(find.byType(JourneySkyLine)), findsNothing);
      expect(_onJourney(find.byType(JourneyMedalsStrip)), findsNothing);
      expect(_onJourney(find.text('Ana Silva')), findsNothing);
      expect(_onJourney(find.text('41')), findsNothing);
    });
  });

  group('the ready arm', () {
    testWidgets('the orb carries the reader\'s own monogram', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // `:586` is `<div class="jorb">M</div>` — a literal, the initial of the
      // prototype's own literal name. Ours is the session's, so the assertion
      // is against **the session's** value and not against a constant.
      final SealMonogram orb = tester.widget<SealMonogram>(
        find.byType(SealMonogram),
      );
      expect(orb.letter, 'AS');
      expect(orb.letter, isNot('M'));
      // `:392` — `width:74px;height:74px`.
      expect(orb.size, 74);
    });

    testWidgets('the orb follows the session, and not a constant', (
      WidgetTester tester,
    ) async {
      // A second reader, so "the orb shows the session's initials" is a claim
      // about the wiring rather than about one fixture's value.
      final JourneyHarness harness = journeyHarness(
        session: Result<AuthSession>.of(
          AuthSession(
            userId: '22222222-2222-2222-2222-222222222222',
            displayName: 'David Mina',
            email: 'david@example.com',
            initials: 'DM',
            createdAt: DateTime.utc(2026, 10, 18),
          ),
        ),
      );
      await pumpJourney(tester, harness);

      final SealMonogram orb = tester.widget<SealMonogram>(
        find.byType(SealMonogram),
      );
      expect(orb.letter, 'DM');
      expect(_onJourney(find.text('David Mina')), findsOneWidget);
      expect(_onJourney(find.text('Ana Silva')), findsNothing);
    });

    testWidgets('the name and the role line are on screen', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // `:587` — `jName`, the reader's own session here.
      expect(_onJourney(find.text('Ana Silva')), findsOneWidget);
      // `:588` — `jrole`, the transcribed copy. **The "7" is a literal** and
      // there is no levels endpoint; the whole line is transcribed, and the
      // widget's own doc says so.
      expect(_onJourney(find.text('SCRIBE · LEVEL 7')), findsOneWidget);
    });

    testWidgets('the hero number is the real streak', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // **`41`, and not the prototype's `12`.** `:589` carries `12` in the
      // markup and `:989` writes it in JavaScript
      // (`el('heroNum').textContent = N(12)`), so the prototype's hero is a
      // literal. Ours is `GET /streak/summary`'s `current_streak`.
      expect(_onJourney(find.text('41')), findsOneWidget);
      expect(
        _onJourney(find.text('12')),
        findsNothing,
        reason:
            'the prototype\'s literal is not this client\'s number, and a '
            'fixture that carried it would pass against the fiction',
      );
    });
  });

  group('the figures on screen', () {
    testWidgets('the three rings carry the derived numbers', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // **The whole list, in order**, so the pairing is pinned as well as the
      // numbers:
      //
      // * ring 1 — `50%`, two completed days of four;
      // * ring 2 — `25`, a **bare count**: Σ `answered_questions`, and the
      //   prototype's own second ring writes `86` with no percent sign where
      //   its neighbours write `83%` and `92%` (`:592-594`);
      // * ring 3 — `84%`, twenty-one correct of twenty-five answered.
      expect(_ringTexts(tester), <String>[
        '50%',
        'VERSES',
        '25',
        'QUIZZES',
        '84%',
        'ACCURACY',
      ]);
    });

    testWidgets('the count ring is a count and carries no percent sign', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // **The unit is the point.** A percent sign on a count of answered
      // questions would be a unit the number does not have — and the prototype's
      // own inconsistency (`:593`'s `data-v="86"` beside `:592`'s `83%`) was
      // resolved deliberately rather than transcribed.
      expect(_onJourney(find.text('25')), findsOneWidget);
      expect(_onJourney(find.text('25%')), findsNothing);
    });

    testWidgets('the sky line carries both counts', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // `:596` — "sky · N stars lit · M constellations", with the two counts
      // in `<b>`. **17 stars** is `SkyRepository.count()`; **1 constellation**
      // is the distinct completed **book** — two of the four days are John, and
      // John counts once.
      expect(
        _onJourney(
          find.text(
            'SKY · 17 STARS LIT · 1 CONSTELLATIONS',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the medals label carries the count and the four tiles follow', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // `:597` — the `.car-label` with "4 / 12" on the right. **Four earned of
      // twelve**, and the twelve is ADR-0022's fiction behind the medals port.
      expect(_onJourney(find.byType(JourneyMedalsLabel)), findsOneWidget);
      expect(_onJourney(find.text('MEDALS')), findsOneWidget);
      expect(_onJourney(find.text('4 / 12')), findsOneWidget);

      // `:598-603` — the four tiles, in the prototype's draw order.
      final JourneyMedalsStrip strip = tester.widget<JourneyMedalsStrip>(
        find.byType(JourneyMedalsStrip),
      );
      expect(strip.tiles, hasLength(4));
      expect(_onJourney(find.text('FIRST LIGHT')), findsOneWidget);
      expect(_onJourney(find.text('PSALMIST')), findsOneWidget);
      expect(_onJourney(find.text('STREAK ×7')), findsOneWidget);

      // **And the fourth is off the screen, because the strip scrolls.**
      // `:410` is `overflow-x:auto` and the four medals are 104px each with
      // 12px gaps — 452px of tiles, more than a phone is wide. The prototype
      // scrolls for the same reason, so the fourth tile is *reached* rather
      // than *seen*, and the suite has to scroll to see it.
      await tester.drag(find.byType(JourneyMedalsStrip), const Offset(-300, 0));
      await settleJourney(tester);
      expect(_onJourney(find.text('JOHN')), findsOneWidget);
    });

    testWidgets('the four account rows are on screen', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // `:605-608` — the four `.srow`s.
      expect(_onJourney(find.byType(JourneyAccountRows)), findsOneWidget);
      expect(_onJourney(find.text('The Communion')), findsOneWidget);
      expect(_onJourney(find.text('Settings')), findsOneWidget);
      expect(_onJourney(find.text('Share progress')), findsOneWidget);
      expect(_onJourney(find.text('Reading plans')), findsOneWidget);
      // And the account label above them — `:604`.
      expect(_onJourney(find.text('ACCOUNT')), findsOneWidget);
    });
  });

  group('the Arabic arm', () {
    testWidgets('the rings read Arabic-Indic digits and the Arabic sign', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness(), locale: const Locale('ar'));

      // **U+066A, ARABIC PERCENT SIGN** — the prototype's `N()` (`:981`) maps
      // `%` to `٪` on the Arabic arm, and the digits go through the same
      // transform. A ring that said `%` on this arm would be a translation
      // defect, not a style choice.
      expect(_ringTexts(tester), <String>[
        '٥٠٪',
        'آيات',
        '٢٥',
        'اختبارات',
        '٨٤٪',
        'دقة',
      ]);
      // **And no U+0025 anywhere in the rings.** A percent sign with a Latin
      // codepoint is the defect, and asserting the absence of the *character*
      // catches it wherever the string came from.
      expect(
        _ringTexts(tester).where((String text) => text.contains('%')),
        isEmpty,
      );
    });

    testWidgets('the hero and the sky counts read Arabic-Indic', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness(), locale: const Locale('ar'));

      // `:989` — `N(12)` and the sky's counts go through the same digit
      // transform, so the Arabic arm reads `٤١` and `١٧`.
      expect(_onJourney(find.text('٤١')), findsOneWidget);
      expect(
        _onJourney(
          find.text('سماء · ١٧ نجوم مضاءة · ١ أبراج', findRichText: true),
        ),
        findsOneWidget,
      );
    });
  });

  group('the account rows', () {
    testWidgets('the Communion row switches to the board tab', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpJourney(tester, journeyHarness());

      // `:605` — the row the prototype wires at `:1284`
      // (`el('rowBoard').onclick = () => { boardEntry = 'push'; push('board'); }`).
      //
      // ## AND THE CLIENT **SWITCHES A TAB** INSTEAD OF PUSHING A PATH
      //
      // The board is the shell's **second child**, so a `pushPath('/communion')`
      // would push a **second shell** with the board tab active — and the app
      // would carry two docks. The prototype pushes because its board is a DOM
      // route (`push('board')`); the client has one board and one place to
      // show it, so **both** of the client's entrances — the dock's slot 3 and
      // this row — are the same tab switch. That is a recorded decision, not a
      // weakening of the claim.
      await _tapRow(tester, 'The Communion');
      await pumpUntilFound(tester, find.byType(CommunionPage));

      // **The tab, and not the stack.** A tab switch does not grow the root
      // stack — the shell is still the one route on it — so the stack would
      // say nothing about which screen the reader is on.
      expect(_activeTab(tester), DockTabs.communion);
      expect(find.byType(CommunionPage), findsOneWidget);
      expect(
        router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name],
        reason:
            'one shell, and no second one: the board is a tab of it, not a '
            'pushed route',
      );
    });

    testWidgets('the Settings row reaches /settings', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpJourney(tester, journeyHarness());

      // `:606` — the row the prototype wires at `:1453`
      // (`el('rowSettings').onclick = () => push('settings')`).
      //
      // **A push, and not a tab.** The workshop is a root route pushed **over**
      // the shell, which is what hides the dock on it
      // (`eva/redesign.html:1251`).
      await _tapRow(tester, 'Settings');
      await pumpUntilFound(tester, find.byType(SettingsPage));

      expect(router.stack.last.name, 'SettingsRoute');
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('the two dead rows do not navigate', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpJourney(tester, journeyHarness());
      final int before = router.stack.length;

      // `:607` and `:608` have **no handler in the prototype** — `el('rowShare')`
      // and `el('rowPlans')` appear nowhere in its script — and the backend's
      // fourteen routes include no endpoint for either.
      await _tapRow(tester, 'Share progress');
      await settleJourney(tester);
      expect(router.stack.length, before);
      expect(_activeTab(tester), DockTabs.journey);

      await _tapRow(tester, 'Reading plans');
      await settleJourney(tester);
      expect(router.stack.length, before);
      expect(_activeTab(tester), DockTabs.journey);

      // ## AND THE CONTROL, SO THE TWO ASSERTIONS ABOVE ARE NOT VACUOUS
      //
      // A tap that **missed** its row would leave the stack unchanged too, and
      // "the stack did not change" would then be a statement about a tap that
      // went nowhere. So the same helper, the same scroll and the same screen
      // are used on a row that **does** navigate — and it does.
      //
      // **And the board is a tab, so "it navigates" is a tab switch.** The
      // stack does not grow; the tab index moves. Asserting the index is what
      // makes this a control rather than a second copy of the assertion above.
      await _tapRow(tester, 'The Communion');
      await pumpUntilFound(tester, find.byType(CommunionPage));
      expect(router.stack.length, before, reason: 'a tab switch, not a push');
      expect(_activeTab(tester), DockTabs.communion);
    });

    testWidgets('the two dead rows say why they cannot be pressed', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      // §14 — "a reader has to be told **why** a control cannot be pressed, not
      // only that it cannot". A dead row that is only greyed out and unnamed is
      // a §14 failure, and the reason is in the accessible name.
      expect(
        _onJourney(
          find.bySemanticsLabel('Share progress — unavailable in this build'),
        ),
        findsOneWidget,
      );
      expect(
        _onJourney(
          find.bySemanticsLabel('Reading plans — unavailable in this build'),
        ),
        findsOneWidget,
      );
      // And the painted title is the prototype's own, without the reason.
      expect(_onJourney(find.text('Share progress')), findsOneWidget);
      expect(
        _onJourney(find.text('Share progress — unavailable in this build')),
        findsNothing,
      );
    });

    testWidgets('a dead row offers no tap at all', (WidgetTester tester) async {
      await pumpJourney(tester, journeyHarness());

      // **A control announced as disabled and answering a tap has told the
      // reader a lie** — so the dead rows must carry no tap action, rather
      // than one that is swallowed.
      final List<String> tappable = nodesOffering(tester, SemanticsAction.tap)
          .map((SemanticsData data) => data.label)
          .where((String label) => label.isNotEmpty)
          .toList();

      expect(tappable, contains('The Communion'));
      expect(tappable, contains('Settings'));
      expect(
        tappable.any((String label) => label.startsWith('Share progress')),
        isFalse,
      );
      expect(
        tappable.any((String label) => label.startsWith('Reading plans')),
        isFalse,
      );
    });
  });

  group('the failure arm', () {
    testWidgets('a failed read renders the error view with its message', (
      WidgetTester tester,
    ) async {
      final JourneyHarness harness = journeyHarness(
        summary: const Left<Failure, StreakSummary>(journeyFailure),
      );
      await pumpJourney(tester, harness);

      final ErrorView view = tester.widget<ErrorView>(
        _onJourney(find.byType(ErrorView)),
      );
      expect(view.message, contains('Could not reach the server.'));
      // And the figures are gone: a failure has no numbers to show.
      expect(_onJourney(find.byType(JourneyHeroNumber)), findsNothing);
      expect(_onJourney(find.byType(JourneyRingsRow)), findsNothing);
    });

    testWidgets('the retry control is live and asks for the reads again', (
      WidgetTester tester,
    ) async {
      final JourneyHarness harness = journeyHarness(
        summary: const Left<Failure, StreakSummary>(journeyFailure),
      );
      await pumpJourney(tester, harness);

      expect(harness.streaks.summaryCalls, 1);
      expect(harness.streaks.historyCalls, 1);
      expect(harness.sky.countCalls, 1);
      expect(harness.medals.calls, 1);

      await tester.tap(
        _onJourney(find.text(AppLocalizationsEn().journeyRetry)),
      );
      await settleJourney(tester);

      // **Every read, not only the one that failed.** A retry that fixed three
      // of four would leave a reader with a screen that is partly new and
      // partly stale — the argument `JourneyCubit.retry`'s doc gives.
      expect(harness.streaks.summaryCalls, 2);
      expect(harness.streaks.historyCalls, 2);
      expect(harness.sky.countCalls, 2);
      expect(harness.medals.calls, 2);
      // And the failure is still the failure: the fake still fails.
      expect(_onJourney(find.byType(ErrorView)), findsOneWidget);
    });

    testWidgets('a retry that succeeds leaves the failed arm', (
      WidgetTester tester,
    ) async {
      final JourneyHarness harness = journeyHarness(
        summary: const Left<Failure, StreakSummary>(journeyFailure),
      );
      await pumpJourney(tester, harness);
      expect(_onJourney(find.byType(ErrorView)), findsOneWidget);

      // The server comes back.
      harness.streaks.summaryAnswer = Result<StreakSummary>.of(journeySummary);
      await tester.tap(
        _onJourney(find.text(AppLocalizationsEn().journeyRetry)),
      );
      await settleJourney(tester);

      expect(_onJourney(find.byType(ErrorView)), findsNothing);
      expect(_onJourney(find.text('41')), findsOneWidget);
    });
  });

  group('the leading space', () {
    testWidgets('the journey has no way back, and does not need one', (
      WidgetTester tester,
    ) async {
      final AppRouter router = await pumpJourney(tester, journeyHarness());

      // ## THE CHEVRON IS GONE, AND THE PROTOTYPE NEVER HAD ONE
      //
      // `:576-583` is the prototype's app bar and `:577` is a 68px spacer — the
      // journey is a dock tab there (`:707`) and never needed a way back. This
      // client drew a chevron only while the journey was **pushed**, because a
      // pushed screen on desktop has no system back button. **The journey is a
      // tab now**, so the reason went with the control, and the prototype's
      // spacer (`:578`) is in its place.
      expect(
        find.descendant(
          of: find.byType(JourneyAppBar),
          matching: find.byIcon(Icons.arrow_back_ios_new),
        ),
        findsNothing,
      );

      // **And the reader is on the journey TAB of the one shell** — so the tab
      // they came from is still there, one dock slot away, and the root stack
      // holds the shell rather than a pushed journey route.
      expect(_activeTab(tester), DockTabs.journey);
      expect(
        router.stack.map((AutoRoutePage<Object?> page) => page.name),
        <String>[DockShellRoute.name],
        reason:
            'the journey is a tab of the shell, so the root stack carries the '
            'shell and not a journey route pushed over it',
      );
    });
  });

  group('the app bar', () {
    testWidgets('names its two controls, and there is no back control', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      final Finder bar = find.byType(JourneyAppBar);
      // The trophy (the board) and the gear (settings). **No back control** —
      // the journey is a tab, and the prototype's journey has a 68px spacer
      // where a chevron would be (`eva/redesign.html:578`).
      expect(
        find.descendant(
          of: bar,
          matching: find.bySemanticsLabel('The Communion'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.bySemanticsLabel('Settings')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.bySemanticsLabel('Back')),
        findsNothing,
      );
      // **And the title.** `:578` — the absolutely centred `.ttl`.
      expect(_onJourney(find.text('Journey')), findsOneWidget);
    });

    testWidgets('every control is reachable by keyboard and rings', (
      WidgetTester tester,
    ) async {
      await pumpJourney(tester, journeyHarness());

      for (final String label in <String>['The Communion', 'Settings']) {
        final Finder target = find.descendant(
          of: find.byType(JourneyAppBar),
          matching: find.bySemanticsLabel(label),
        );
        // **A generous tab budget, and the reason is the shell.** The shell's
        // own chrome — the dock's five slots — is in the focus tree ahead of
        // the app bar's controls, so they are not the first ones Tab reaches.
        await tabUntilFocused(tester, target, maxTabs: 40);
        expect(
          renderedBorders(tester, target),
          contains(evaFocusRingBorder(const EvaColors.dark())),
          reason: '§14 — "$label" took focus but painted no ring.',
        );
      }
    });
  });
}

/// Taps the account row titled [title], scrolling it into view first.
///
/// **The scroll, and not a drag.** The rows are at the bottom of a long
/// column, and the scaffold's scroll view uses `BouncingScrollPhysics` — a
/// drag long enough to reach the end of the content **overshoots** it, and the
/// row under test ends up hundreds of pixels above the viewport.
Future<void> _tapRow(WidgetTester tester, String title) async {
  final Finder row = _onJourney(find.text(title));
  await tester.ensureVisible(row);
  await settleJourney(tester);
  await tester.tap(row);
  await settleJourney(tester);
}
