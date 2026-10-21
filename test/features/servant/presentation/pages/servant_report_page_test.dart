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

  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) async {
    calls++;
    return result;
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

void main() {
  /// Fills the cohort field and asks for the roster.
  Future<void> askForTheRoster(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '3');
    await tester.tap(find.text('Show the roster'));
    await tester.pump();
  }

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
