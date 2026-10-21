import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:evangelion/features/servant/presentation/pages/schedule_reading_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../servant_harness.dart';

/// A fake **port**, and not a fake use case.
final class _Repo implements ServantAdminRepository {
  _Repo(this.result);

  /// What the next call answers.
  Result<ScheduleResult> result;

  /// Every schedule the port was asked for.
  final List<ReadingSchedule> asked = <ReadingSchedule>[];

  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async {
    asked.add(schedule);
    return result;
  }

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async => const Left<Failure, CommitResult>(
    Failure(kind: FailureKind.server, message: 'not used'),
  );

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async => const Left<Failure, QuestionDraft>(
    Failure(kind: FailureKind.server, message: 'not used'),
  );
}

/// The server's answer.
const ScheduleResult result = ScheduleResult(
  message: 'Successfully scheduled reading for 1 groups',
  readingIds: <String>['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
);

void main() {
  /// Fills the form with a passage.
  ///
  /// **Every field is a parameter**, because a refusal is a claim about **one**
  /// field — the page draws the message under the field it belongs to, and a
  /// test that could not break a single field could not check that.
  Future<void> fillTheForm(
    WidgetTester tester, {
    String groupIds = '3',
    String date = '2026-10-21',
    String book = '43',
    String startChapter = '3',
    String startVerse = '1',
    String endChapter = '',
    String endVerse = '5',
    String excluded = '',
  }) async {
    final Finder fields = find.byType(TextField);
    // **The form is longer than the surface**, so every field is scrolled to
    // before it is typed into — a tap that misses is a warning, not a failure,
    // and a silent miss would make the test pass for the wrong reason.
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), groupIds);
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), date);
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), book);
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), startChapter);
    await tester.ensureVisible(fields.at(4));
    await tester.enterText(fields.at(4), startVerse);
    await tester.ensureVisible(fields.at(5));
    // **The end chapter is left empty** — a passage that stays in one chapter
    // has no end chapter, and the server's own transform substitutes the start
    // chapter for a missing one.
    await tester.enterText(fields.at(5), endChapter);
    await tester.ensureVisible(fields.at(6));
    await tester.enterText(fields.at(6), endVerse);
    await tester.ensureVisible(fields.at(7));
    await tester.enterText(fields.at(7), excluded);
    await tester.pump();
  }

  /// The schedule form, painted and settled.
  ///
  /// The extra pump is the screen's own settling: the form's listeners are
  /// attached in `didChangeDependencies`, and the state they write is what the
  /// refusal below is about.
  Future<void> pumpForm(
    WidgetTester tester,
    ScheduleReadingCubit cubit, {
    Locale locale = const Locale('en'),
  }) async {
    await pumpServant(
      tester,
      ScheduleReadingPage(cubit: cubit),
      // **A surface the whole form fits on.** The schedule form is the
      // portal's longest — nine fields, a switch, two warnings and a button —
      // and a test that has to scroll to reach the button would be testing
      // the scroll rather than the form.
      locale: locale,
      size: const Size(390, 1500),
    );
    await tester.pump();
  }

  /// The cubit over a fake port, over a form that is never asked.
  ScheduleReadingCubit cubitOver(_Repo repo) {
    final ScheduleReadingCubit cubit = ScheduleReadingCubit(
      scheduleReading: ScheduleReading(repo),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('the two backend behaviours the screen must state', () {
    testWidgets('are on screen, next to the AI switch', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);

      expect(
        find.text(
          'Scheduling the same cohort and date again replaces the passage.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Scheduling the same cohort and date again with this on deletes the '
          'questions already written for that date.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the reversed range', () {
    testWidgets('is refused by the form, and nothing is asked', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester, startVerse: '9');
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(
        find.text('The start of the passage cannot be after its end.'),
        findsOneWidget,
      );
      expect(repo.asked, isEmpty);
    });
  });

  group('a correct form', () {
    testWidgets('is sent, and the server\'s sentence is on screen', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester);
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(repo.asked, hasLength(1));
      expect(repo.asked.single.groupIds, <int>[3]);
      expect(repo.asked.single.scheduledDate, '2026-10-21');
      expect(repo.asked.single.bookNumber, 43);
      expect(
        find.text('Successfully scheduled reading for 1 groups'),
        findsOneWidget,
      );
    });
  });

  group('the AI switch', () {
    testWidgets('reaches the port', (WidgetTester tester) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester);
      await tester.tap(find.byType(EvaToggle));
      await tester.pump();
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(repo.asked.single.generateAiQuestions, isTrue);
    });
  });

  // ## THE STATES THE ADMIN CAN REACH, AND THE TWO ARMS OF EACH
  //
  // A screen that says something is a screen that says it in **two**
  // languages, and a message that exists in only one of them is a message half
  // the readers never see. So every state below is asserted in **both** arms:
  // the English sentence, and then the same state repainted in Arabic.
  //
  // **The repaint is the same widget**, so the state under test is the state
  // the first arm produced — not a second, freshly-mounted screen.
  group('the failure', () {
    testWidgets('is the server\'s own sentence, with a retry', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(
        const Left<Failure, ScheduleResult>(
          Failure(
            kind: FailureKind.server,
            message: 'start boundary cannot be after end boundary',
          ),
        ),
      );
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester);
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      // **The server's own sentence**, verbatim.
      expect(
        find.text('start boundary cannot be after end boundary'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      await pumpForm(tester, cubit, locale: otherArmFor(const Locale('en')));

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('start boundary cannot be after end boundary'),
        findsOneWidget,
      );
      // **And the retry is named in the reader's own language.**
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
    });

    testWidgets('and it is still on screen after the admin edits the form', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(
        const Left<Failure, ScheduleResult>(
          Failure(kind: FailureKind.server, message: 'no such cohort'),
        ),
      );
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester);
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);

      // **The admin corrects the form.** The server's refusal is about the
      // request it answered, and a refusal that vanished because the reader
      // typed would be a refusal the reader never got to read.
      final Finder fields = find.byType(TextField);
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), '4');
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('no such cohort'), findsOneWidget);
      expect(cubit.state.failure, isNotNull);
    });

    testWidgets('and the retry asks again, for the same form', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(
        const Left<Failure, ScheduleResult>(
          Failure(kind: FailureKind.server, message: 'no such cohort'),
        ),
      );
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester);
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();

      // **The same form, asked twice** — the screen has exactly one request,
      // and the retry is that request again rather than a different one.
      expect(repo.asked, hasLength(2));
      expect(repo.asked.last, repo.asked.first);
    });
  });

  group('the refusals', () {
    /// The message under the field at [field], and nothing else.
    ///
    /// **The field is the claim.** A refusal that names a field draws its
    /// message under that field, and a message under the wrong field is a
    /// message about a field the admin is not looking at.
    Finder errorUnder(int field, String message) => find.descendant(
      of: find.byType(EvaTextField).at(field),
      matching: find.text(message),
    );

    /// The field indexes, in the order the form draws them.
    const int groupIds = 0;
    const int date = 1;
    const int bookNumber = 2;
    const int startChapter = 3;
    const int excludedVerses = 7;

    testWidgets('a form with no cohort says so, under the cohort field', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester, groupIds: '');
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(errorUnder(groupIds, 'Name at least one cohort.'), findsOneWidget);
      expect(repo.asked, isEmpty);

      await pumpForm(tester, cubit, locale: otherArmFor(const Locale('en')));

      expect(
        errorUnder(groupIds, 'اذكر مجموعة واحدة على الأقل.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a book number outside the canon says so, under its own field',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
        final ScheduleReadingCubit cubit = cubitOver(repo);

        await pumpForm(tester, cubit);
        await fillTheForm(tester, book: '0');
        await tester.ensureVisible(find.text('Schedule the reading'));
        await tester.tap(find.text('Schedule the reading'));
        await tester.pump();

        expect(
          errorUnder(bookNumber, 'That is not a whole number.'),
          findsOneWidget,
        );
        expect(repo.asked, isEmpty);

        await pumpForm(tester, cubit, locale: otherArmFor(const Locale('en')));

        expect(errorUnder(bookNumber, 'هذا ليس عددًا صحيحًا.'), findsOneWidget);
      },
    );

    testWidgets(
      'a date that is not the server\'s shape says so, under its own field',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
        final ScheduleReadingCubit cubit = cubitOver(repo);

        await pumpForm(tester, cubit);
        await fillTheForm(tester, date: '21/10/2026');
        await tester.ensureVisible(find.text('Schedule the reading'));
        await tester.tap(find.text('Schedule the reading'));
        await tester.pump();

        expect(
          errorUnder(date, 'The date must be written as year, month, day.'),
          findsOneWidget,
        );
        expect(repo.asked, isEmpty);

        await pumpForm(tester, cubit, locale: otherArmFor(const Locale('en')));

        expect(
          errorUnder(date, 'يجب كتابة التاريخ سنة ثم شهر ثم يوم.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an excluded verse that is not a pair says so, under its own field',
      (WidgetTester tester) async {
        final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
        final ScheduleReadingCubit cubit = cubitOver(repo);

        await pumpForm(tester, cubit);
        await fillTheForm(tester, excluded: '3');
        await tester.ensureVisible(find.text('Schedule the reading'));
        await tester.tap(find.text('Schedule the reading'));
        await tester.pump();

        expect(
          errorUnder(
            excludedVerses,
            'An excluded verse is written as a chapter and a verse.',
          ),
          findsOneWidget,
        );
        expect(repo.asked, isEmpty);

        await pumpForm(tester, cubit, locale: otherArmFor(const Locale('en')));

        expect(
          errorUnder(excludedVerses, 'تُكتب الآية المستثناة فصلًا ثم آية.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a reversed passage says so, in both languages', (
      WidgetTester tester,
    ) async {
      final _Repo repo = _Repo(Result<ScheduleResult>.of(result));
      final ScheduleReadingCubit cubit = cubitOver(repo);

      await pumpForm(tester, cubit);
      await fillTheForm(tester, startVerse: '9');
      await tester.ensureVisible(find.text('Schedule the reading'));
      await tester.tap(find.text('Schedule the reading'));
      await tester.pump();

      expect(
        errorUnder(
          startChapter,
          'The start of the passage cannot be after its end.',
        ),
        findsOneWidget,
      );
      expect(repo.asked, isEmpty);

      await pumpForm(tester, cubit, locale: otherArmFor(const Locale('en')));

      expect(
        errorUnder(startChapter, 'لا يمكن أن يبدأ الفصل بعد نهايته.'),
        findsOneWidget,
      );
    });
  });
}
