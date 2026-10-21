import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// The schedule form's cubit — red-first (AGENT_CONTEXT §6).
///
/// ## WHY THE MOCK IS OVER THE **PORT**
///
/// `ScheduleReading` is a `final class`, so it cannot be implemented from
/// outside its library — and that is the right constraint. The cubit is
/// therefore driven over the **real** use case, which exercises its
/// pass-through on the way in.
class MockServantAdminRepository extends Mock
    implements ServantAdminRepository {}

/// The server's answer.
const ScheduleResult result = ScheduleResult(
  message: 'Successfully scheduled reading for 1 groups',
  readingIds: <String>['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
);

/// The server's own refusal.
const Failure failure = Failure(
  kind: FailureKind.server,
  message: 'start boundary cannot be after end boundary',
);

/// The schedule a correct form describes.
const ReadingSchedule expectedSchedule = ReadingSchedule(
  groupIds: <int>[3],
  scheduledDate: '2026-10-21',
  bookNumber: 43,
  startChapter: 3,
  startVerse: 1,
  endVerse: 5,
);

/// The form, filled in with a correct passage.
const ScheduleReadingForm filledForm = ScheduleReadingForm(
  groupIdsText: '3',
  scheduledDateText: '2026-10-21',
  bookNumberText: '43',
  startChapterText: '3',
  startVerseText: '1',
  endVerseText: '5',
);

void main() {
  late MockServantAdminRepository repository;

  setUpAll(() {
    // mocktail needs a fallback for the schedule argument, because
    // `captureAny()` is matched loosely against a non-nullable value.
    registerFallbackValue(expectedSchedule);
  });

  setUp(() {
    repository = MockServantAdminRepository();
    when(() => repository.scheduleReading(any()))
        .thenAnswer((_) async => Result<ScheduleResult>.of(result));
  });

  /// The cubit over the **real** use case, with the form already filled in.
  ScheduleReadingCubit cubitWith([ScheduleReadingForm form = filledForm]) =>
      ScheduleReadingCubit(scheduleReading: ScheduleReading(repository));

  /// A cubit whose form has been **typed in**, one setter at a time.
  ///
  /// The plain `test`s drive the form through the cubit's own setters rather
  /// than through a seeded state, because a seeded state is a state the
  /// production code never builds — and the setters are the way the form is
  /// actually filled.
  ScheduleReadingCubit filledCubit() {
    final ScheduleReadingCubit cubit = ScheduleReadingCubit(
      scheduleReading: ScheduleReading(repository),
    );
    cubit
      ..setGroupIds('3')
      ..setScheduledDate('2026-10-21')
      ..setBookNumber('43')
      ..setStartChapter('3')
      ..setStartVerse('1')
      ..setEndVerse('5');
    return cubit;
  }

  /// The schedules the port was asked for.
  ///
  /// `verify(…).captured` is a `List<dynamic>`, and the cast is the only way
  /// to name what it holds — a `dynamic` in a test is a value nothing can be
  /// asked about.
  List<ReadingSchedule> capturedSchedules() =>
      verify(() => repository.scheduleReading(captureAny())).captured
          .cast<ReadingSchedule>();

  group('the happy path', () {
    blocTest<ScheduleReadingCubit, ScheduleReadingState>(
      'the reading is scheduled, and the server\'s answer is on screen',
      build: cubitWith,
      seed: () => const ScheduleReadingState(
        status: ScheduleReadingStatus.idle,
        form: filledForm,
      ),
      act: (ScheduleReadingCubit cubit) => cubit.submit(),
      expect: () => <ScheduleReadingState>[
        const ScheduleReadingState(
          status: ScheduleReadingStatus.submitting,
          form: filledForm,
        ),
        const ScheduleReadingState(
          status: ScheduleReadingStatus.scheduled,
          form: filledForm,
          result: result,
        ),
      ],
    );

    test(
      'and the schedule that reached the port is the one the form describes',
      () async {
        final ScheduleReadingCubit cubit = filledCubit();
        await cubit.submit();

        final List<ReadingSchedule> sent = capturedSchedules();
        expect(sent, hasLength(1));
        expect(sent.single, expectedSchedule);

        await cubit.close();
      },
    );

    test('and the AI switch reaches the port', () async {
      final ScheduleReadingCubit cubit = filledCubit();
      cubit.setGenerateAiQuestions(generate: true);
      await cubit.submit();

      final List<ReadingSchedule> sent = capturedSchedules();
      expect(sent.single.generateAiQuestions, isTrue);
      expect(sent.single.groupIds, <int>[3]);

      await cubit.close();
    });

    test('and several cohorts go as several ids', () async {
      final ScheduleReadingCubit cubit = filledCubit();
      cubit.setGroupIds('3, 4 ,5');
      await cubit.submit();

      final List<ReadingSchedule> sent = capturedSchedules();
      expect(sent.single.groupIds, <int>[3, 4, 5]);

      await cubit.close();
    });

    test(
      'and an end chapter, when one is named, is sent as it was typed',
      () async {
        final ScheduleReadingCubit cubit = filledCubit();
        cubit.setEndChapter('4');
        await cubit.submit();

        final List<ReadingSchedule> sent = capturedSchedules();
        expect(sent.single.endChapter, 4);

        await cubit.close();
      },
    );

    test('and the excluded verses are the ones that were typed', () async {
      final ScheduleReadingCubit cubit = filledCubit();
      cubit.setExcludedVerses('3:2, 3:4');
      await cubit.submit();

      final List<ReadingSchedule> sent = capturedSchedules();
      expect(sent.single.excludedVerses, <ExcludedVerse>[
        const ExcludedVerse(chapter: 3, verse: 2),
        const ExcludedVerse(chapter: 3, verse: 4),
      ]);

      await cubit.close();
    });
  });

  group('the busy state', () {
    blocTest<ScheduleReadingCubit, ScheduleReadingState>(
      'the request is announced before it is answered',
      build: cubitWith,
      seed: () => const ScheduleReadingState(
        status: ScheduleReadingStatus.idle,
        form: filledForm,
      ),
      act: (ScheduleReadingCubit cubit) => cubit.submit(),
      expect: () => <ScheduleReadingState>[
        // **The first arm is the busy one**, and it carries **no result**: a
        // schedule on screen that answers a form that has not been sent yet is
        // a schedule about nothing.
        const ScheduleReadingState(
          status: ScheduleReadingStatus.submitting,
          form: filledForm,
        ),
        const ScheduleReadingState(
          status: ScheduleReadingStatus.scheduled,
          form: filledForm,
          result: result,
        ),
      ],
    );
  });

  group('the failure path', () {
    blocTest<ScheduleReadingCubit, ScheduleReadingState>(
      'the server\'s own failure is on screen',
      setUp: () {
        when(
          () => repository.scheduleReading(any()),
        ).thenAnswer((_) async => const Left<Failure, ScheduleResult>(failure));
      },
      build: cubitWith,
      seed: () => const ScheduleReadingState(
        status: ScheduleReadingStatus.idle,
        form: filledForm,
      ),
      act: (ScheduleReadingCubit cubit) => cubit.submit(),
      expect: () => <ScheduleReadingState>[
        const ScheduleReadingState(
          status: ScheduleReadingStatus.submitting,
          form: filledForm,
        ),
        const ScheduleReadingState(
          status: ScheduleReadingStatus.failed,
          form: filledForm,
          failure: failure,
        ),
      ],
    );

    test('and the retry asks again, for the same form', () async {
      // **The screen has exactly one request**, so the retry is that request
      // again — and the form it sends is the one on screen, not a fresh one.
      when(
        () => repository.scheduleReading(any()),
      ).thenAnswer((_) async => const Left<Failure, ScheduleResult>(failure));
      final ScheduleReadingCubit cubit = filledCubit();
      await cubit.submit();
      expect(cubit.state.status, ScheduleReadingStatus.failed);

      when(() => repository.scheduleReading(any()))
          .thenAnswer((_) async => Result<ScheduleResult>.of(result));
      await cubit.retry();

      expect(cubit.state.status, ScheduleReadingStatus.scheduled);
      expect(cubit.state.result, result);
      // **The same form**, twice — so the second request is not a different
      // reading from the first.
      final List<ReadingSchedule> sent = capturedSchedules();
      expect(sent, hasLength(2));
      expect(sent.last, expectedSchedule);

      await cubit.close();
    });
  });

  group('the refusals, and they come before the request', () {
    /// Every refusal is the same shape: the form is refused, the request is
    /// never made, and the state names **which** field is at fault.
    void refuses({
      required String name,
      required ScheduleReadingForm form,
      required ScheduleReadingFormError error,
      required ScheduleReadingField field,
    }) {
      blocTest<ScheduleReadingCubit, ScheduleReadingState>(
        name,
        build: () => cubitWith(form),
        seed: () => ScheduleReadingState(
          status: ScheduleReadingStatus.idle,
          form: form,
        ),
        act: (ScheduleReadingCubit cubit) => cubit.submit(),
        expect: () => <ScheduleReadingState>[
          ScheduleReadingState(
            status: ScheduleReadingStatus.idle,
            form: form,
            formError: error,
            formField: field,
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.scheduleReading(any()));
        },
      );
    }

    refuses(
      name: 'a passage whose start is after its end is refused',
      form: const ScheduleReadingForm(
        groupIdsText: '3',
        scheduledDateText: '2026-10-21',
        bookNumberText: '43',
        startChapterText: '3',
        startVerseText: '9',
        endChapterText: '3',
        endVerseText: '5',
      ),
      error: ScheduleReadingFormError.reversedRange,
      field: ScheduleReadingField.startChapter,
    );

    refuses(
      name: 'a passage whose start chapter is after its end chapter is refused',
      form: const ScheduleReadingForm(
        groupIdsText: '3',
        scheduledDateText: '2026-10-21',
        bookNumberText: '43',
        startChapterText: '4',
        startVerseText: '1',
        endChapterText: '3',
        endVerseText: '5',
      ),
      error: ScheduleReadingFormError.reversedRange,
      field: ScheduleReadingField.startChapter,
    );

    refuses(
      name: 'a passage that names no cohort is refused',
      form: const ScheduleReadingForm(
        scheduledDateText: '2026-10-21',
        bookNumberText: '43',
        startChapterText: '3',
        startVerseText: '1',
        endVerseText: '5',
      ),
      error: ScheduleReadingFormError.emptyGroupIds,
      field: ScheduleReadingField.groupIds,
    );

    refuses(
      name: 'a cohort that is not a whole number is refused',
      form: const ScheduleReadingForm(
        groupIdsText: 'three',
        scheduledDateText: '2026-10-21',
        bookNumberText: '43',
        startChapterText: '3',
        startVerseText: '1',
        endVerseText: '5',
      ),
      error: ScheduleReadingFormError.invalidNumber,
      field: ScheduleReadingField.groupIds,
    );

    refuses(
      name: 'a date that is not the server\'s shape is refused',
      form: const ScheduleReadingForm(
        groupIdsText: '3',
        scheduledDateText: '21/10/2026',
        bookNumberText: '43',
        startChapterText: '3',
        startVerseText: '1',
        endVerseText: '5',
      ),
      error: ScheduleReadingFormError.invalidDate,
      field: ScheduleReadingField.date,
    );

    refuses(
      name: 'a book number outside the canon is refused',
      form: const ScheduleReadingForm(
        groupIdsText: '3',
        scheduledDateText: '2026-10-21',
        bookNumberText: '67',
        startChapterText: '3',
        startVerseText: '1',
        endVerseText: '5',
      ),
      error: ScheduleReadingFormError.invalidNumber,
      field: ScheduleReadingField.bookNumber,
    );

    refuses(
      name: 'an excluded verse that is not a pair is refused',
      form: const ScheduleReadingForm(
        groupIdsText: '3',
        scheduledDateText: '2026-10-21',
        bookNumberText: '43',
        startChapterText: '3',
        startVerseText: '1',
        endVerseText: '5',
        excludedVersesText: '3',
      ),
      error: ScheduleReadingFormError.invalidExcludedVerse,
      field: ScheduleReadingField.excludedVerses,
    );
  });

  group('the form', () {
    // ## THE **RECEIPT** AND THE **EDIT**
    //
    // **A WRITE'S ANSWER REPORTS A WRITE THAT HAPPENED, AND IT STAYS.**
    //
    // The request carried the form **as it was when the button was pressed**,
    // and the server did that write. A keystroke that came **after** the
    // request does not undo it — so a confirmation that lands under a form that
    // has since moved on is still a **true statement**: *that* write happened.
    //
    // **AND THE RECEIPT IS LOAD-BEARING.** It carries the `reading_ids` the
    // questions flow needs — the ids the schedule answered with are how the
    // admin writes questions against the reading they just scheduled — so
    // dropping it on an edit would take that away.
    test(
      'an edit keeps the receipt, because it reports a write that happened',
      () async {
        final ScheduleReadingCubit cubit = filledCubit();
        await cubit.submit();
        expect(cubit.state.status, ScheduleReadingStatus.scheduled);
        expect(cubit.state.result, result);

        cubit.setBookNumber('44');

        // **THE RECEIPT STAYS**, and the status that promised it stays with
        // it — a status that says "the server answered" with no answer on
        // screen is a status about nothing.
        expect(
          cubit.state.result,
          result,
          reason:
              'the write happened, and a keystroke that came after the request '
              'does not undo it',
        );
        expect(cubit.state.status, ScheduleReadingStatus.scheduled);
        // **AND THE READING IDS ARE STILL THERE** — they are how the admin
        // writes questions against the reading they just scheduled.
        expect(
          cubit.state.result!.readingIds,
          result.readingIds,
          reason: 'the receipt is load-bearing, and it carries the ids',
        );

        await cubit.close();
      },
    );

    test('and the form\'s own refusal still goes', () async {
      final ScheduleReadingCubit cubit = filledCubit();
      await cubit.submit();

      // **THE FORM IS REFUSED BEFORE THE REQUEST IS MADE** — the date is
      // written the way the admin wrote it, and the form refuses it.
      cubit.setScheduledDate('21/10/2026');
      await cubit.submit();
      expect(cubit.state.formError, ScheduleReadingFormError.invalidDate);

      cubit.setScheduledDate('2026-10-21');

      // **THE FORM'S OWN REFUSAL GOES**, because the reader is correcting it
      // — and it is a *different* refusal from the server's, and the two are
      // told apart.
      expect(cubit.state.formError, isNull);
      expect(cubit.state.formField, isNull);
      expect(cubit.state.failure, isNull);

      await cubit.close();
    });

    test('and a new attempt replaces the receipt, because it is a new answer', () async {
      // **THE BOUNDARY, AND IT IS THE HOUSE'S OWN.** The receipt stays
      // through an **edit** — the form moved on, and the write did not
      // change. A **new attempt** is a new answer, and a new answer replaces
      // the last one: the same rule that lets a refusal replace the server's
      // failure, and the same rule that lets a second "Schedule" replace the
      // first receipt.
      final ScheduleReadingCubit cubit = filledCubit();
      await cubit.submit();
      expect(cubit.state.result, result);

      // **A NEW ATTEMPT, AND IT IS REFUSED** — the form's own rule, and the
      // request is never made.
      cubit.setScheduledDate('21/10/2026');
      await cubit.submit();

      expect(cubit.state.formError, ScheduleReadingFormError.invalidDate);
      expect(
        cubit.state.result,
        isNull,
        reason:
            'a new attempt is a new answer, and a new answer replaces the last '
            'one — the receipt stays through an EDIT, and not through a new '
            'attempt',
      );

      await cubit.close();
    });

    test('an edit keeps the server\'s failure, because the reader did not cause it', () async {
      when(
        () => repository.scheduleReading(any()),
      ).thenAnswer((_) async => const Left<Failure, ScheduleResult>(failure));
      final ScheduleReadingCubit cubit = filledCubit();
      await cubit.submit();
      expect(cubit.state.status, ScheduleReadingStatus.failed);
      expect(cubit.state.failure, failure);

      cubit.setBookNumber('44');

      // **The server's answer is still on screen.** The admin corrected a
      // field; the server has not said anything new, and a refusal that
      // vanished because the reader typed would be a refusal the reader
      // never got to read.
      expect(cubit.state.failure, failure);
      // **And the arm that names the request stays.** The status is what
      // the screen reads to know which request failed, so a failure that
      // kept its message but lost its arm would be about nothing.
      expect(cubit.state.status, ScheduleReadingStatus.failed);

      await cubit.close();
    });

    test('and an edit clears the form\'s own refusal', () async {
      final ScheduleReadingCubit cubit = filledCubit();
      // **The form is refused before the request is made** — the date is
      // written the way the admin wrote it, and the form refuses it.
      cubit.setScheduledDate('21/10/2026');
      await cubit.submit();
      expect(cubit.state.formError, ScheduleReadingFormError.invalidDate);
      expect(cubit.state.formField, ScheduleReadingField.date);

      cubit.setScheduledDate('2026-10-21');

      // **The form's own refusal goes**, because the reader is correcting
      // it — and it is a *different* refusal from the server's, and the two
      // are told apart.
      expect(cubit.state.formError, isNull);
      expect(cubit.state.formField, isNull);
      expect(cubit.state.failure, isNull);

      await cubit.close();
    });

    test('a request in flight survives an edit, and a second submit is refused', () async {
      // **A request that has not answered yet.** The busy state is the status,
      // and the busy state is what disables the submit button — so an edit
      // that dropped the status would re-enable it while the first request
      // was still open, and the second schedule would **replace** the passage
      // the first one wrote (`ON CONFLICT … DO UPDATE`).
      final Completer<Result<ScheduleResult>> pending =
          Completer<Result<ScheduleResult>>();
      when(() => repository.scheduleReading(any()))
          .thenAnswer((_) => pending.future);

      final ScheduleReadingCubit cubit = filledCubit();
      final Future<void> first = cubit.submit();
      expect(cubit.state.status, ScheduleReadingStatus.submitting);

      cubit.setBookNumber('44');
      expect(cubit.state.status, ScheduleReadingStatus.submitting);

      await cubit.submit();
      verify(() => repository.scheduleReading(any())).called(1);

      pending.complete(Result<ScheduleResult>.of(result));
      await first;
      await cubit.close();
    });

    test(
      'the end chapter is optional, and an empty one is not an error',
      () async {
        final ScheduleReadingCubit cubit = filledCubit();
        cubit.setEndChapter('');
        await cubit.submit();

        final List<ReadingSchedule> sent = capturedSchedules();
        expect(sent.single.endChapter, isNull);

        await cubit.close();
      },
    );
  });
}
