import 'dart:async';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/load_daily_report.dart';
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart';
import 'package:evangelion/features/servant/presentation/pages/servant_report_page.dart';
import 'package:evangelion/features/servant/presentation/widgets/roster_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../servant_harness.dart';

/// A fake **port**, and not a fake use case.
///
/// `LoadDailyReport` is a `final class`, so the cubit is driven over the real
/// use case and the port is the only thing faked.
final class _Repo implements ServantReportRepository {
  _Repo(this.result);

  /// What the next call answers.
  Result<ServantReport> result;

  /// How many times the port was asked.
  int calls = 0;

  /// What the port was asked, in the port's own words.
  ///
  /// **THE REQUEST IS THE CLAIM.** A count says *that* the port was asked;
  /// this says *what for* — and the report is a read, so the request and the
  /// form on screen have to be the same request.
  final List<DailyReportQuery> asked = <DailyReportQuery>[];

  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) async {
    calls++;
    asked.add(DailyReportQuery(groupId: groupId, date: date));
    return result;
  }
}

/// A port that **holds** the answer open until the test releases it.
///
/// The defect this suite's group is about is a **timing** defect: the answer
/// lands after the form has moved on, and a port that answers at once cannot
/// produce that order at all.
final class _HeldRepo implements ServantReportRepository {
  /// The answer the test releases.
  final Completer<Result<ServantReport>> answer =
      Completer<Result<ServantReport>>();

  /// What the port was asked, in the port's own words.
  final List<DailyReportQuery> asked = <DailyReportQuery>[];

  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) {
    asked.add(DailyReportQuery(groupId: groupId, date: date));
    return answer.future;
  }
}

/// The cubit, with the page's reports counted.
///
/// **A spy, and not a mock**: the question is *which* of the cubit's writers
/// the page called, and a subclass that records the call and then does the
/// real thing answers it without replacing the cubit's behaviour. A mock would
/// have to answer `state` as well, and the state is what the page renders.
final class _SpyCubit extends ServantReportCubit {
  _SpyCubit({required super.loadDailyReport});

  /// Every edit the page reported, in the page's own words.
  final List<String> reported = <String>[];

  @override
  void setGroupId(String text) {
    reported.add('group: $text');
    super.setGroupId(text);
  }

  @override
  void setDate(String text) {
    reported.add('date: $text');
    super.setDate(text);
  }
}

/// One child on the roster.
const RosterStudent student = RosterStudent(
  userId: '11111111-1111-1111-1111-111111111111',
  fullName: 'David Mina',
  preferredLang: 'en',
  totalPoints: 120,
  currentStreak: 4,
  pointsEarnedToday: 10,
  completedToday: true,
  questionsProgress: '3/5',
);

/// The report the server answers with.
const ServantReport report = ServantReport(
  groupId: 3,
  reportDate: '2026-10-21',
  totalStudents: 1,
  completedCount: 1,
  students: <RosterStudent>[student],
);

/// The second child on the roster.
///
/// **A roster of one has no separator**, and the rule between two children is
/// only drawn when there are two of them.
const RosterStudent secondStudent = RosterStudent(
  userId: '22222222-2222-2222-2222-222222222222',
  fullName: 'Peter George',
  preferredLang: 'ar',
  totalPoints: 25,
  currentStreak: 2,
  pointsEarnedToday: 0,
  completedToday: false,
  questionsProgress: '0/0',
);

/// The server's own refusal.
const Failure failure = Failure(
  kind: FailureKind.server,
  message: 'No scheduled reading found for your cohort today',
);

/// The instant the form's date default is read from.
///
/// **A FIXED ONE, AND NOT THE WALL CLOCK.** The form's date is pre-filled with
/// today, so a test that read the real clock would be a test that answers
/// differently every morning — and the golden's own doc says why a picture of
/// the wall clock is a picture nobody keeps.
final DateTime _defaultToday = DateTime(2026, 10, 21);

/// The day the admin chose for the cohort, and not the default.
const String _chosenDate = '2026-10-14';

void main() {
  /// Fills the cohort field and asks for the roster.
  Future<void> askForTheRoster(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '3');
    await tester.tap(find.text('Show the roster'));
    await tester.pump();
  }

  /// The text the field at [index] holds.
  ///
  /// **THE FIELD, AND NOT THE STATE.** The defect this suite's re-entry group
  /// is about was invisible for one reason: the state held the cohort and the
  /// date the whole time, and only the **field** was empty. So the claim has to
  /// be a claim about the field the servant reads — and reading the controller
  /// is reading the field's own text, not the cubit's copy of it.
  String textIn(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byType(TextField).at(index))
      .controller!
      .text;

  group('the roster', () {
    testWidgets('renders the child, and the server\'s own progress token', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.text('David Mina'), findsOneWidget);
      // **The progress string is verbatim** — the server's own `3/5`, and not
      // a re-formatting of it.
      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(repo.calls, 1);
      // **And there is no rule between one child and the next**, because there
      // is no next — the separator is the roster's, and a roster of one has
      // nothing to separate.
      expect(find.byType(HairlineDivider), findsNothing);
    });

    testWidgets('and the two totals are the server\'s own', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.byType(StatTile), findsNWidgets(2));
      expect(find.byType(RosterRow), findsOneWidget);
    });

    testWidgets('and a rule between two children', (WidgetTester tester) async {
      // **The rule is the separator**, and a separator is only built when
      // there is something to separate — so the claim is made with **two**
      // children, and the one-child roster above is the failing direction.
      const ServantReport two = ServantReport(
        groupId: 3,
        reportDate: '2026-10-21',
        totalStudents: 2,
        completedCount: 1,
        students: <RosterStudent>[student, secondStudent],
      );
      final _Repo repo = _Repo(Result<ServantReport>.of(two));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.byType(RosterRow), findsNWidgets(2));
      expect(find.byType(HairlineDivider), findsOneWidget);
    });
  });

  group('the empty roster', () {
    testWidgets('renders the empty state and not an error', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(
        Result<ServantReport>.of(
          const ServantReport(
            groupId: 3,
            reportDate: '2026-10-21',
            totalStudents: 0,
            completedCount: 0,
            students: <RosterStudent>[],
          ),
        ),
      );
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No roster'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
    });
  });

  group('the failure', () {
    testWidgets('renders the server\'s own message, with a retry', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(const Left<Failure, ServantReport>(failure));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('No scheduled reading found for your cohort today'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit),
        locale: otherArmFor(const Locale('en')),
      );
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('No scheduled reading found for your cohort today'),
        findsOneWidget,
      );
      // **And the retry is named in the reader's own language.**
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
    });

    testWidgets('and the retry asks again', (WidgetTester tester) async {
      final _Repo repo = _Repo(const Left<Failure, ServantReport>(failure));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(repo.calls, 2);
    });
  });

  group('the form', () {
    testWidgets('refuses a cohort that is not a number, and asks nothing', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await tester.enterText(find.byType(TextField).first, 'three');
      await tester.tap(find.text('Show the roster'));
      await tester.pump();

      expect(find.text('The cohort must be a whole number.'), findsOneWidget);
      expect(repo.calls, 0);
    });

    testWidgets('and says so in the reader\'s own language too', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await tester.enterText(find.byType(TextField).first, 'three');
      await tester.tap(find.text('Show the roster'));
      await tester.pump();

      expect(find.text('The cohort must be a whole number.'), findsOneWidget);

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit),
        locale: otherArmFor(const Locale('en')),
      );
      await tester.pump();

      expect(find.text('يجب أن تكون المجموعة عددًا صحيحًا.'), findsOneWidget);
    });

    testWidgets('refuses an empty date, and asks nothing', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      // **The date is pre-filled with today**, so the refusal is about the
      // admin clearing it — and the server would have defaulted it, so this
      // is this client's own gap rather than a server rule.
      await tester.enterText(find.byType(TextField).first, '3');
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.text('Show the roster'));
      await tester.pump();

      expect(find.text('The date is required.'), findsOneWidget);
      expect(repo.calls, 0);

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit),
        locale: otherArmFor(const Locale('en')),
      );
      await tester.pump();

      expect(find.text('التاريخ مطلوب.'), findsOneWidget);
    });
  });

  // ## THE ROUTE BEING **OPENED AGAIN**
  //
  // The cubit is a **singleton** — `navigation_injection.dart` says so and
  // gives the reason: "a reader who left `/servant/questions` and came back
  // would find their edits gone". So the cohort and the day the servant chose
  // have to survive the route being popped and pushed again over that one
  // cubit.
  //
  // **AND THE POP IS A REAL DISMOUNT.** The page is a `StatefulWidget` with
  // two controllers of its own, so the pop disposes them and the push builds
  // new ones — which is what makes the form on screen the state's job rather
  // than the controllers'.
  group('the route being opened again', () {
    testWidgets(
      'shows the cohort and the day the state holds, and asks for that roster',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ServantReport>.of(report));
        final ServantReportCubit cubit = ServantReportCubit(
          loadDailyReport: LoadDailyReport(repo),
        );
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          ServantReportPage(cubit: cubit, today: () => _defaultToday),
        );

        // **THE SERVANT FILLS THE FORM** — the cohort, and a day that is not
        // the default, so the claim below cannot be satisfied by the default
        // and by the servant's own choice at the same time.
        await tester.enterText(find.byType(TextField).at(0), '3');
        await tester.enterText(find.byType(TextField).at(1), _chosenDate);
        await tester.tap(find.text('Show the roster'));
        await tester.pump();

        expect(find.byType(RosterRow), findsOneWidget);

        // **THE ROUTE IS POPPED AND PUSHED AGAIN**, over the same singleton
        // cubit — the hub pushes the route, and the cubit is one for the
        // process.
        await pumpServant(tester, const SizedBox.shrink());
        await pumpServant(
          tester,
          ServantReportPage(cubit: cubit, today: () => _defaultToday),
        );
        await tester.pump();

        // **AND IT IS ON SCREEN** — the two fields, and not the state. The
        // controllers are the page's own, and the page's own are built empty
        // every time, so a form that shows the cohort and the day is a form the
        // **state** filled.
        expect(textIn(tester, 0), '3', reason: 'the cohort');
        expect(textIn(tester, 1), _chosenDate, reason: 'the day');

        // **AND THE ROSTER ON SCREEN DESCRIBES THE FORM ON SCREEN** — the
        // roster the servant loaded is still there, and it is the roster of the
        // cohort and the day the form now says.
        expect(find.byType(RosterRow), findsOneWidget);

        // **AND THE REQUEST CARRIES THE FORM THE SCREEN SHOWS.** The form is
        // the request, so a request built from a form the servant cannot see
        // would be a request about a different cohort.
        await tester.tap(find.text('Show the roster'));
        await tester.pump();

        expect(repo.asked, hasLength(2));
        expect(repo.asked.last.groupId, 3);
        expect(repo.asked.last.date, _chosenDate);
      },
    );

    // ## THE **DEFAULT** THE DATE CARRIES
    //
    // The date field is pre-filled with today, and today is a **seam**
    // (`ServantReportPage.today`) — a golden is a picture, and a picture of
    // the wall clock fails every morning. So the default is a *shape* here,
    // and the claim below is about the shape and not about the day.
    testWidgets(
      'and the date is pre-filled with today, and the state says so',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ServantReport>.of(report));
        final ServantReportCubit cubit = ServantReportCubit(
          loadDailyReport: LoadDailyReport(repo),
        );
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          ServantReportPage(cubit: cubit, today: () => _defaultToday),
        );
        await tester.pump();

        // **THE DEFAULT IS ON SCREEN** — the servant is not asked to type the
        // day, and the server would have defaulted it anyway.
        expect(textIn(tester, 1), '2026-10-21');

        // **AND THE STATE SAYS THE SAME**, so the screen and the state agree
        // from the first frame — which is what lets the readback be the one
        // path that fills the field.
        expect(cubit.state.dateText, '2026-10-21');
      },
    );

    testWidgets('and the page\'s own writes are not reported as edits', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final _SpyCubit cubit = _SpyCubit(loadDailyReport: LoadDailyReport(repo));
      addTearDown(cubit.close);

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit, today: () => _defaultToday),
      );
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.pump();

      // **Only the servant's own keystrokes so far.** The list is cleared so
      // the claim below is about the **re-entry's** writes and not about the
      // typing above.
      cubit.reported.clear();

      await pumpServant(tester, const SizedBox.shrink());
      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit, today: () => _defaultToday),
      );
      await tester.pump();

      // **A WRITE THE PAGE MADE IS NOT SOMETHING THE READER DID.** The two
      // controllers are the page's own, and the page's own are built empty —
      // so filling them from the state is the page's own write, and the
      // controller's listener is the page's own way of reporting a keystroke.
      expect(cubit.reported, isEmpty);
    });

    // ## THE WRITE THAT HAPPENS **WHILE THE FORM IS OPEN**
    //
    // The re-entry above is the page's own write at **mount**, and the mount
    // reads the state **before** the listeners are attached — so the write
    // cannot reach the cubit at all, and the `_writing` flag is not what
    // stops it. The flag is what stops the write that happens **later**,
    // when the listeners are attached and the page's own write would be
    // reported as the reader's own keystroke.
    //
    // **AND THE DIVERGENCE IS PLANTED, BECAUSE THE APP'S OWN WRITERS CANNOT
    // PRODUCE IT.** Every writer of this cubit's form is the page's own, and
    // the page reports each field as the servant types it — so the state and
    // the screen agree about every field, and the sync has nothing to write.
    // A writer **outside** the page is what makes the two disagree, and the
    // cubit's own writer is the way to say that.
    testWidgets(
      'and a write the page makes while the form is open is not an edit',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ServantReport>.of(report));
        final _SpyCubit cubit = _SpyCubit(
          loadDailyReport: LoadDailyReport(repo),
        );
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          ServantReportPage(cubit: cubit, today: () => _defaultToday),
        );
        await tester.enterText(find.byType(TextField).at(0), '3');
        await tester.pump();

        // **THE STATE SAYS SOMETHING THE SCREEN DOES NOT.** The cubit is the
        // state and the page is the screen, and a writer outside the page is
        // what makes the two disagree.
        cubit.setGroupId('7');
        // **The call above is the test's own, not the page's** — so the list is
        // cleared after it and before the page's own write.
        cubit.reported.clear();
        await tester.pump();

        // **AND THE SCREEN IS IN STEP** — and this half is what keeps the claim
        // below from being vacuous: a page that wrote nothing would report
        // nothing, and the assertion would be about nothing.
        expect(textIn(tester, 0), '7');

        // **AND THE PAGE'S OWN WRITE WAS NOT REPORTED AS THE READER'S EDIT.**
        // The listener is the page's own way of reporting a keystroke, and the
        // page did not read a keystroke.
        expect(cubit.reported, isEmpty);
      },
    );
  });

  // ## THE **ROSTER** AND THE **FORM**
  //
  // The report is a roster of **children**, and the cohort and the day are
  // what the roster is about — the server's own `group_id` and `report_date`
  // (`admin.routes.ts:416-422`). So a roster on screen has to describe the
  // form on screen, and an **edit** is the only thing a servant can do to the
  // form besides asking.
  //
  // **AND THE CLAIM BELOW IS ABOUT **THE ROSTER ON SCREEN**, NOT ABOUT THE
  // STATE.** The state held the whole time, and holding the old roster is
  // exactly what made the defect invisible: a reader of the state alone
  // could not tell a roster about cohort 3 from a roster about cohort 7,
  // because the state said "3" about the roster and "7" about the form.
  group('the roster and the form', () {
    testWidgets(
      'the cohort changes, and the roster about the old cohort goes',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ServantReport>.of(report));
        final ServantReportCubit cubit = ServantReportCubit(
          loadDailyReport: LoadDailyReport(repo),
        );
        addTearDown(cubit.close);

        await pumpServant(tester, ServantReportPage(cubit: cubit));
        await askForTheRoster(tester);

        expect(find.byType(RosterRow), findsOneWidget);

        // **THE SERVANT CORRECTS THE COHORT.**
        await tester.enterText(find.byType(TextField).first, '7');
        await tester.pump();

        // **AND THE ROSTER IS GONE** — a roster of cohort 3's children under a
        // form that says cohort 7 is one cohort's children under another
        // cohort's name.
        expect(find.byType(RosterRow), findsNothing);
        // **AND SO ARE THE TWO TOTALS**, because they count the roster's rows.
        expect(find.byType(StatTile), findsNothing);

        // **AND THE FORM SAYS WHAT THE SERVANT TYPED**, so the claim above is
        // not vacuous: a form that did not change would not have dropped
        // anything.
        expect(textIn(tester, 0), '7');

        // **AND ONE PRESS BRINGS THE ROSTER BACK** — the cost of the rule,
        // measured. A servant who mistypes the cohort loses the roster and
        // reloads it with one press of the button.
        //
        // **THE FAKE ANSWERS THE SAME ROSTER FOR EVERY COHORT**, so the claim
        // here is about **the request** — it carries the cohort on the form —
        // and about **a roster being on screen again**. The payload the fake
        // answers with is the fake's, and not the client's.
        await tester.tap(find.text('Show the roster'));
        await tester.pump();

        expect(repo.asked.last.groupId, 7);
        expect(find.byType(RosterRow), findsOneWidget);
      },
    );

    testWidgets('the day changes, and the roster about the old day goes', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      // **THE DATE IS FIXED**, so the claim is about a day and not about the
      // wall clock — and the day the servant chooses is not the default.
      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit, today: () => _defaultToday),
      );
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.tap(find.text('Show the roster'));
      await tester.pump();

      expect(find.byType(RosterRow), findsOneWidget);

      // **THE SERVANT CHOOSES ANOTHER DAY.**
      await tester.enterText(find.byType(TextField).at(1), _chosenDate);
      await tester.pump();

      // **AND THE ROSTER IS GONE** — the same children, another day's
      // answers, under a form that names the other day.
      expect(find.byType(RosterRow), findsNothing);
      expect(find.byType(StatTile), findsNothing);

      // **AND THE FORM SAYS THE DAY THE SERVANT CHOSE.**
      expect(textIn(tester, 1), _chosenDate);
    });
  });

  // ## THE ANSWER THAT **LANDS AFTER THE FORM MOVED ON**
  //
  // The group above is about the roster **on screen** and the form **on
  // screen**. This is the moment that claim could not reach: the form
  // changes **before** the answer exists, so there is no roster to drop — and
  // the answer that lands is the one that was **asked for**.
  //
  // **AND THE CLAIM BELOW IS ABOUT **THE SCREEN**, NOT ABOUT THE STATE.**
  // The state held the whole time, and a reader of the state alone could not
  // tell a roster about cohort 3 from a roster about cohort 7 — the state
  // said "3" about the roster and "7" about the form.
  group('the answer that lands after the form moved on', () {
    testWidgets(
      'the cohort changes while the request is open, and the roster that lands is not on screen',
      (WidgetTester tester) async {
        final _HeldRepo repo = _HeldRepo();
        final ServantReportCubit cubit = ServantReportCubit(
          loadDailyReport: LoadDailyReport(repo),
        );
        addTearDown(cubit.close);

        await pumpServant(
          tester,
          ServantReportPage(cubit: cubit, today: () => _defaultToday),
        );
        await tester.enterText(find.byType(TextField).at(0), '3');
        await tester.tap(find.text('Show the roster'));
        await tester.pump();

        // **THE REQUEST IS OPEN** — and the field is not disabled while it
        // is, so the servant can correct the cohort in the meantime.
        expect(cubit.state.status, ServantReportStatus.loading);

        await tester.enterText(find.byType(TextField).at(0), '7');
        await tester.pump();

        // **AND THE ANSWER ARRIVES** — the roster of cohort 3.
        repo.answer.complete(Result<ServantReport>.of(report));
        await tester.pump();
        await tester.pump();

        // **AND THE ROSTER IS NOT ON SCREEN** — one cohort's children under
        // another cohort's name, which is the wrongness the whole rule
        // exists to forbid.
        expect(find.byType(RosterRow), findsNothing);
        // **AND SO ARE THE TWO TOTALS**, because they count the roster's
        // rows.
        expect(find.byType(StatTile), findsNothing);

        // **AND THE FORM SAYS WHAT THE SERVANT TYPED**, so the claim above is
        // not vacuous: a form that did not change would not have dropped
        // anything.
        expect(textIn(tester, 0), '7');

        // **AND ONE PRESS BRINGS THE ROSTER BACK** — the cost of the rule,
        // measured. The press is repeated with the form as it now reads, and
        // this time the answer describes it.
        await tester.tap(find.text('Show the roster'));
        await tester.pump();

        expect(repo.asked.last.groupId, 7);
        expect(find.byType(RosterRow), findsOneWidget);
      },
    );
  });

  group('the reader\'s own language', () {
    testWidgets('and says its two totals in the reader\'s own language too', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ServantReport>.of(report));
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.text('CHILDREN'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit),
        locale: otherArmFor(const Locale('en')),
      );
      await tester.pump();

      expect(find.text('الأطفال'), findsOneWidget);
      expect(find.text('أكملوا'), findsOneWidget);
    });

    testWidgets('and the empty roster says so in both languages', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(
        Result<ServantReport>.of(
          const ServantReport(
            groupId: 3,
            reportDate: '2026-10-21',
            totalStudents: 0,
            completedCount: 0,
            students: <RosterStudent>[],
          ),
        ),
      );
      final ServantReportCubit cubit = ServantReportCubit(
        loadDailyReport: LoadDailyReport(repo),
      );
      addTearDown(cubit.close);

      await pumpServant(tester, ServantReportPage(cubit: cubit));
      await askForTheRoster(tester);

      expect(find.text('No roster'), findsOneWidget);
      expect(
        find.text('This cohort has no children for that day.'),
        findsOneWidget,
      );

      await pumpServant(
        tester,
        ServantReportPage(cubit: cubit),
        locale: otherArmFor(const Locale('en')),
      );
      await tester.pump();

      expect(find.text('لا قائمة'), findsOneWidget);
      expect(
        find.text('لا يوجد أطفال في هذه المجموعة في ذلك اليوم.'),
        findsOneWidget,
      );
    });
  });
}
