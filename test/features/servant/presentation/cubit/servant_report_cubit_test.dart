import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/load_daily_report.dart';
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// The daily report's cubit — red-first (AGENT_CONTEXT §6).
///
/// ## WHY THE MOCK IS OVER THE **PORT**
///
/// `LoadDailyReport` is a `final class`, so it cannot be implemented from
/// outside its library — and that is the right constraint. The cubit is
/// therefore driven over the **real** use case, which exercises its pass-through
/// on the way in: a use case that reclassified a failure would fail here rather
/// than being stubbed away.
///
/// The mocks are over the **port**, not over the fake repository, so nothing
/// here knows that the Dio adapter exists — the substitution the whole
/// architecture turns on.
class MockServantReportRepository extends Mock
    implements ServantReportRepository {}

/// A roster, with the two facts the screen draws.
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
  late MockServantReportRepository repository;

  setUp(() {
    repository = MockServantReportRepository();
    when(
      () => repository.loadDailyReport(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => Result<ServantReport>.of(report));
  });

  /// The cubit over the **real** use case, with the form already filled in.
  ServantReportCubit cubitWith({
    required String groupId,
    required String date,
  }) => ServantReportCubit(loadDailyReport: LoadDailyReport(repository));

  group('the happy path', () {
    blocTest<ServantReportCubit, ServantReportState>(
      'the roster arrives, and the answer is on screen',
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.idle,
        groupIdText: '3',
        dateText: '2026-10-21',
      ),
      act: (ServantReportCubit cubit) => cubit.load(),
      expect: () => <ServantReportState>[
        const ServantReportState(
          status: ServantReportStatus.loading,
          groupIdText: '3',
          dateText: '2026-10-21',
        ),
        const ServantReportState(
          status: ServantReportStatus.ready,
          groupIdText: '3',
          dateText: '2026-10-21',
          report: report,
        ),
      ],
      verify: (_) {
        verify(() => repository.loadDailyReport(groupId: 3, date: '2026-10-21'))
            .called(1);
      },
    );
  });

  group('the busy state', () {
    blocTest<ServantReportCubit, ServantReportState>(
      'the request is announced before it is answered, and the form is kept',
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.idle,
        groupIdText: '3',
        dateText: '2026-10-21',
      ),
      act: (ServantReportCubit cubit) => cubit.load(),
      expect: () => <ServantReportState>[
        // **The first arm is the busy one**, and it is asserted by being first
        // in the list rather than by a separate test: a state that is never
        // published is a state the screen cannot draw a spinner from. It also
        // carries **no report** — "loading" is not "no data", and a roster
        // drawn under a busy form would be a roster about a different cohort.
        const ServantReportState(
          status: ServantReportStatus.loading,
          groupIdText: '3',
          dateText: '2026-10-21',
        ),
        const ServantReportState(
          status: ServantReportStatus.ready,
          groupIdText: '3',
          dateText: '2026-10-21',
          report: report,
        ),
      ],
    );
  });

  group('the failure path', () {
    blocTest<ServantReportCubit, ServantReportState>(
      'the server\'s own failure is on screen, with no report',
      setUp: () {
        when(
          () => repository.loadDailyReport(
            groupId: any(named: 'groupId'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Left<Failure, ServantReport>(failure));
      },
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.idle,
        groupIdText: '3',
        dateText: '2026-10-21',
      ),
      act: (ServantReportCubit cubit) => cubit.load(),
      expect: () => <ServantReportState>[
        const ServantReportState(
          status: ServantReportStatus.loading,
          groupIdText: '3',
          dateText: '2026-10-21',
        ),
        const ServantReportState(
          status: ServantReportStatus.failed,
          groupIdText: '3',
          dateText: '2026-10-21',
          failure: failure,
        ),
      ],
    );

    blocTest<ServantReportCubit, ServantReportState>(
      'and the retry asks again, for the same cohort and date',
      setUp: () {
        when(
          () => repository.loadDailyReport(
            groupId: any(named: 'groupId'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Left<Failure, ServantReport>(failure));
      },
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.failed,
        groupIdText: '3',
        dateText: '2026-10-21',
        failure: failure,
      ),
      act: (ServantReportCubit cubit) => cubit.retry(),
      expect: () => <ServantReportState>[
        const ServantReportState(
          status: ServantReportStatus.loading,
          groupIdText: '3',
          dateText: '2026-10-21',
        ),
        const ServantReportState(
          status: ServantReportStatus.failed,
          groupIdText: '3',
          dateText: '2026-10-21',
          failure: failure,
        ),
      ],
      verify: (_) {
        verify(() => repository.loadDailyReport(groupId: 3, date: '2026-10-21'))
            .called(1);
      },
    );
  });

  group('the refusals, and they come before the request', () {
    blocTest<ServantReportCubit, ServantReportState>(
      'a cohort that is not a whole number is refused, and nothing is asked',
      build: () => cubitWith(groupId: 'three', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.idle,
        groupIdText: 'three',
        dateText: '2026-10-21',
      ),
      act: (ServantReportCubit cubit) => cubit.load(),
      expect: () => <ServantReportState>[
        const ServantReportState(
          status: ServantReportStatus.idle,
          groupIdText: 'three',
          dateText: '2026-10-21',
          formError: ServantReportFormError.invalidGroupId,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.loadDailyReport(
            groupId: any(named: 'groupId'),
            date: any(named: 'date'),
          ),
        );
      },
    );

    blocTest<ServantReportCubit, ServantReportState>(
      'an empty date is refused, and nothing is asked',
      build: () => cubitWith(groupId: '3', date: ''),
      seed: () => const ServantReportState(
        status: ServantReportStatus.idle,
        groupIdText: '3',
      ),
      act: (ServantReportCubit cubit) => cubit.load(),
      expect: () => <ServantReportState>[
        const ServantReportState(
          status: ServantReportStatus.idle,
          groupIdText: '3',
          formError: ServantReportFormError.missingDate,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.loadDailyReport(
            groupId: any(named: 'groupId'),
            date: any(named: 'date'),
          ),
        );
      },
    );
  });

  group('the form', () {
    test('a request in flight is not asked twice', () async {
      // **A request that has not answered yet.** The busy state is the status,
      // and the busy state is what disables the submit button — so a caller
      // that asked again would get a second roster for a question that has
      // already been answered.
      final Completer<Result<ServantReport>> pending =
          Completer<Result<ServantReport>>();
      when(
        () => repository.loadDailyReport(
          groupId: any(named: 'groupId'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) => pending.future);

      final ServantReportCubit cubit = cubitWith(
        groupId: '3',
        date: '2026-10-21',
      );
      cubit
        ..setGroupId('3')
        ..setDate('2026-10-21');
      final Future<void> first = cubit.load();
      expect(cubit.state.status, ServantReportStatus.loading);

      await cubit.load();
      verify(
        () => repository.loadDailyReport(
          groupId: any(named: 'groupId'),
          date: any(named: 'date'),
        ),
      ).called(1);

      pending.complete(Result<ServantReport>.of(report));
      await first;
      await cubit.close();
    });

    test(
      'the cohort and the date are the state\'s, and the state is whole',
      () async {
        final ServantReportCubit cubit = cubitWith(groupId: '3', date: '');

        cubit.setGroupId('4');
        expect(cubit.state.groupIdText, '4');
        expect(cubit.state.dateText, '');

        cubit.setDate('2026-10-22');
        expect(cubit.state.groupIdText, '4');
        expect(cubit.state.dateText, '2026-10-22');

        await cubit.close();
      },
    );
  });

  // ## THE **EDIT**
  //
  // The report is a roster of **children**, and the cohort and the day are
  // what the roster is about — the server's own `group_id` and `report_date`
  // (`admin.routes.ts:416-422`). So a roster on screen has to describe the
  // form on screen, and an **edit** is the only thing a servant can do to the
  // form besides asking.
  //
  // **THE CUBIT'S WRITERS DECIDE WHAT THE EDIT INVALIDATES**, and the rule is
  // the sibling cubits' rule: the answer on screen is about the form as it
  // **was**, so it goes; the server's **failure** is about the request that
  // failed, so it stays.
  group('the edit', () {
    blocTest<ServantReportCubit, ServantReportState>(
      'the cohort changed, and the roster about the old cohort goes',
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.ready,
        groupIdText: '3',
        dateText: '2026-10-21',
        report: report,
      ),
      act: (ServantReportCubit cubit) => cubit.setGroupId('7'),
      expect: () => <ServantReportState>[
        // **NO ROSTER, AND NO `ready`** — the roster is gone and so is the
        // arm that promised it, because an arm that promises an answer must
        // never stand without one.
        const ServantReportState(
          status: ServantReportStatus.idle,
          groupIdText: '7',
          dateText: '2026-10-21',
        ),
      ],
    );

    blocTest<ServantReportCubit, ServantReportState>(
      'the day changed, and the roster about the old day goes',
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.ready,
        groupIdText: '3',
        dateText: '2026-10-21',
        report: report,
      ),
      act: (ServantReportCubit cubit) => cubit.setDate('2026-10-14'),
      expect: () => <ServantReportState>[
        // **THE SAME RULE, AND NOT A SECOND ONE** — a report is identified by
        // the pair, a cohort on a day, so a roster that does not describe the
        // form is a roster about a different request whichever coordinate
        // moved. The costs differ and the rule does not.
        const ServantReportState(
          status: ServantReportStatus.idle,
          groupIdText: '3',
          dateText: '2026-10-14',
        ),
      ],
    );

    blocTest<ServantReportCubit, ServantReportState>(
      'and the server\'s failure stays, with the arm that names it',
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.failed,
        groupIdText: '3',
        dateText: '2026-10-21',
        failure: failure,
      ),
      act: (ServantReportCubit cubit) => cubit.setGroupId('7'),
      expect: () => <ServantReportState>[
        // **THE FAILURE IS ABOUT THE REQUEST THAT FAILED**, and the reader
        // correcting a field is not the server changing its mind — so it
        // stays, and the arm that names it stays with it, so `retry` still
        // repeats that request.
        const ServantReportState(
          status: ServantReportStatus.failed,
          groupIdText: '7',
          dateText: '2026-10-21',
          failure: failure,
        ),
      ],
    );

    blocTest<ServantReportCubit, ServantReportState>(
      'and the form\'s own refusal goes, because the reader is correcting it',
      build: () => cubitWith(groupId: 'three', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.idle,
        groupIdText: 'three',
        dateText: '2026-10-21',
        formError: ServantReportFormError.invalidGroupId,
      ),
      act: (ServantReportCubit cubit) => cubit.setGroupId('3'),
      expect: () => <ServantReportState>[
        // **A MESSAGE THAT OUTLIVES THE FIELD IT IS ABOUT IS A MESSAGE ABOUT
        // SOMETHING ELSE** — and the reader is correcting it.
        const ServantReportState(
          status: ServantReportStatus.idle,
          groupIdText: '3',
          dateText: '2026-10-21',
        ),
      ],
    );

    blocTest<ServantReportCubit, ServantReportState>(
      'and a request in flight stays in flight',
      build: () => cubitWith(groupId: '3', date: '2026-10-21'),
      seed: () => const ServantReportState(
        status: ServantReportStatus.loading,
        groupIdText: '3',
        dateText: '2026-10-21',
      ),
      act: (ServantReportCubit cubit) => cubit.setGroupId('7'),
      expect: () => <ServantReportState>[
        // **THE BUSY STATE IS THE STATUS, AND THE BUSY STATE IS WHAT DISABLES
        // THE BUTTON** — so an edit that dropped it would re-enable the
        // button while the request was still open.
        const ServantReportState(
          status: ServantReportStatus.loading,
          groupIdText: '7',
          dateText: '2026-10-21',
        ),
      ],
    );
  });
}
