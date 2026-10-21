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
  });
}
