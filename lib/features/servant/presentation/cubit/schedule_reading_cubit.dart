import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule_reading_cubit.freezed.dart';

/// Where `/servant/schedule` is in its own lifecycle.
///
/// Four values, for `ServantReportStatus`'s reason: "loading" is **not** "no
/// data", and a form that has not been submitted is neither a request in
/// flight nor a request that failed.
enum ScheduleReadingStatus {
  /// Nothing has been asked for yet. The form is on screen and empty.
  idle,

  /// The request is open.
  submitting,

  /// The server answered. [ScheduleReadingState.result] is non-null.
  scheduled,

  /// The request failed. [ScheduleReadingState.failure] is non-null.
  failed,
}

/// Which field of the schedule form an error belongs to.
///
/// **A named field, and not a sentence.** The page draws the message under the
/// field it belongs to, and a message that named the field in prose would have
/// to be repeated in every language — so the field is a **value** and the
/// message is one string per *kind* of error.
enum ScheduleReadingField {
  /// The cohort ids field.
  groupIds,

  /// The date field.
  date,

  /// The book number field.
  bookNumber,

  /// The start chapter field.
  startChapter,

  /// The start verse field.
  startVerse,

  /// The end chapter field.
  endChapter,

  /// The end verse field.
  endVerse,

  /// The excluded verses field.
  excludedVerses,
}

/// Why the schedule form refused to make a request.
///
/// ## AND WHY THE **RANGE** IS ONE OF THEM
///
/// `admin.routes.ts:126-129` refuses a passage whose start boundary is after
/// its end boundary with a **400** and the sentence
/// `"start boundary cannot be after end boundary"`. The check is the server's
/// own:
///
/// ```ts
/// if (start_chapter > end_chapter ||
///     (start_chapter === end_chapter && start_verse > end_verse)) { … }
/// ```
///
/// and it reads the **transformed** `end_chapter` — the schema's own transform
/// is `end_chapter ?? start_chapter` (`admin.routes.ts:31-33`), so a passage
/// that names no end chapter ends in its start chapter.
///
/// This client makes the same refusal **first**, for the same reason the
/// report form refuses a cohort that is not a number: the server's answer
/// would name a field the admin never saw, and the request would have been
/// spent on it.
enum ScheduleReadingFormError {
  /// The cohort field named no cohort. The schema's `group_ids` is
  /// `z.array(…).min(1)` (`admin.routes.ts:9`).
  emptyGroupIds,

  /// A numeric field held something that is not a whole number, or a number
  /// the schema's own minimum refuses.
  invalidNumber,

  /// The date field was not `YYYY-MM-DD`. The schema types it as a regex over
  /// the text (`admin.routes.ts:10`).
  invalidDate,

  /// An excluded verse was not `chapter:verse`. The schema types one as an
  /// **object** (`admin.routes.ts:16-28`), and this form writes the
  /// lower-case spelling of it.
  invalidExcludedVerse,

  /// The start boundary is after the end boundary.
  reversedRange,
}

/// The schedule form's fields, as the admin typed them.
///
/// ## WHY IT IS A **VALUE OBJECT** AND NOT PART OF THE STATE
///
/// Because it has **no invariant of its own** — nine independent fields, none
/// of which can disagree with another — while the state around it has one:
/// `status`, `result` and `failure` must agree, and a partial writer could
/// leave them disagreeing. So the form carries a generated `copyWith` and the
/// state does not; that split is the whole of the argument, and it is
/// `HomeState`'s, generalised.
///
/// ## AND WHY EVERY FIELD IS **TEXT**
///
/// For the reason `ServantReportState` gives: the controller holds a string
/// while the reader is halfway through typing it, and `1` on its way to `12` is
/// a string and not a whole number. The parse happens once, on submit, and it
/// is the parse that refuses.
@freezed
final class ScheduleReadingForm with _$ScheduleReadingForm {
  /// A form with nothing typed into it.
  const ScheduleReadingForm({
    this.groupIdsText = '',
    this.scheduledDateText = '',
    this.bookNumberText = '',
    this.startChapterText = '',
    this.startVerseText = '',
    this.endChapterText = '',
    this.endVerseText = '',
    this.excludedVersesText = '',
    this.generateAiQuestions = false,
  });

  /// The cohorts, comma separated.
  final String groupIdsText;

  /// The date, `YYYY-MM-DD`.
  final String scheduledDateText;

  /// The book, 1 to 66.
  final String bookNumberText;

  /// The first chapter of the passage.
  final String startChapterText;

  /// The first verse of the passage.
  final String startVerseText;

  /// The last chapter, or empty for a passage that stays in one chapter.
  final String endChapterText;

  /// The last verse of the passage.
  final String endVerseText;

  /// The verses to leave out, `chapter:verse` and comma separated.
  final String excludedVersesText;

  /// Whether the server should generate and attach the reading's question.
  ///
  /// **The server deletes the previous questions when this is on**
  /// (`admin.routes.ts:195`), and the screen says so in a label beside the
  /// switch. The flag is here so the screen can say it.
  final bool generateAiQuestions;
}

/// What `/servant/schedule` is showing.
///
/// ## AND WHY THE `copyWith` IS **OFF**
///
/// For `AuthState`'s reason: a `String? = null` parameter cannot express
/// "clear it", so a nullable field that must be cleared is written by a
/// method that cannot get it wrong. `ScheduleReadingState.result` and
/// `.failure` are exactly such fields — a refused form must not keep the
/// last schedule's result, and a failed request must not keep the last
/// success — and a generated `copyWith` could not clear either of them.
///
/// **And every writer below is inline and whole.** `QuizState` is the
/// precedent for a state this shape: five fields and eleven inline full
/// constructors, no `with*` methods at all. The cubit below builds the whole
/// state at every `emit`, and there is no second spelling of that sentence
/// for a writer to disagree with.
///
/// **And the invariant is two sentences.** A `failed` status carries the
/// failure, and a `scheduled` status carries the result — so the status
/// always names the request that failed, and a status that promises an
/// answer never stands without one. An **edit** keeps the failure and the
/// arm that names it, and drops the result and the arm that promised it,
/// and [_edit] says why.
@Freezed(copyWith: false)
final class ScheduleReadingState with _$ScheduleReadingState {
  /// A state on the given arm.
  ///
  /// **`status` is required and not defaulted**, and that is the whole of the
  /// reason: a defaulted status would let a writer leave it out, and a writer
  /// that leaves the status out is a writer that did not say which arm of the
  /// lifecycle it is on. Every construction below names it.
  const ScheduleReadingState({
    required this.status,
    this.form = const ScheduleReadingForm(),
    this.result,
    this.failure,
    this.formError,
    this.formField,
  });

  /// Which lifecycle arm this is.
  final ScheduleReadingStatus status;

  /// The form's fields.
  final ScheduleReadingForm form;

  /// What the server answered, or `null`.
  final ScheduleResult? result;

  /// Why the request failed, or `null`.
  final Failure? failure;

  /// Why the form refused to ask, or `null`.
  final ScheduleReadingFormError? formError;

  /// Which field the refusal belongs to, or `null` for a general one.
  final ScheduleReadingField? formField;
}

/// Drives `/servant/schedule` through [submit] and [retry].
///
/// ## AND IT TAKES ITS **USE CASE**, NEVER ITS REPOSITORY
///
/// §3's DIP row, and its mirror: no presentation file names a repository. The
/// cubit depends on [ScheduleReading], so a test drives the real use case over
/// a fake port.
///
/// ## AND AN **EDIT** CHANGES THE FORM AND NOTHING ELSE
///
/// Every writer below that answers something the reader did is an **edit**,
/// and an edit keeps the server's **failure** and the **arm** that names the
/// request it names — because the reader correcting a field is not the server
/// changing its mind. The form's own refusal goes, and the server's answer
/// goes, because both are about the form as it **was**. The rules are spelled
/// out on [_edit], and they are the question cubit's rules verbatim.
class ScheduleReadingCubit extends Cubit<ScheduleReadingState> {
  /// Drives the form over [scheduleReading].
  ScheduleReadingCubit({required this.scheduleReading})
    : super(const ScheduleReadingState(status: ScheduleReadingStatus.idle));

  /// The schedule request.
  final ScheduleReading scheduleReading;

  /// The cohort ids changed.
  void setGroupIds(String text) =>
      _edit(state.form.copyWith(groupIdsText: text));

  /// The date changed.
  void setScheduledDate(String text) =>
      _edit(state.form.copyWith(scheduledDateText: text));

  /// The book changed.
  void setBookNumber(String text) =>
      _edit(state.form.copyWith(bookNumberText: text));

  /// The start chapter changed.
  void setStartChapter(String text) =>
      _edit(state.form.copyWith(startChapterText: text));

  /// The start verse changed.
  void setStartVerse(String text) =>
      _edit(state.form.copyWith(startVerseText: text));

  /// The end chapter changed.
  void setEndChapter(String text) =>
      _edit(state.form.copyWith(endChapterText: text));

  /// The end verse changed.
  void setEndVerse(String text) =>
      _edit(state.form.copyWith(endVerseText: text));

  /// The excluded verses changed.
  void setExcludedVerses(String text) =>
      _edit(state.form.copyWith(excludedVersesText: text));

  /// The AI switch moved.
  void setGenerateAiQuestions({required bool generate}) =>
      _edit(state.form.copyWith(generateAiQuestions: generate));

  /// Sends the form and answers with the whole state.
  ///
  /// ## THE REFUSAL COMES **BEFORE** THE REQUEST
  ///
  /// Every rule the server's schema states is checked here first, and the
  /// request is not made when one of them is broken. The server would have
  /// refused it too, with a body that names a field the admin never saw.
  ///
  /// ## AND A SECOND SUBMIT IS **REFUSED** while one is open
  ///
  /// The button is disabled while the request is in flight, and this is the
  /// same rule one layer down: a double-tap on a slow device would schedule
  /// the reading twice, and the second one would **replace** the first —
  /// `ON CONFLICT (group_id, scheduled_date) DO UPDATE`
  /// (`admin.routes.ts:157`).
  Future<void> submit() async {
    if (state.status == ScheduleReadingStatus.submitting) return;

    final _ParsedSchedule parsed = _parse(state.form);
    switch (parsed) {
      case _ParsedScheduleRefused(
        :final ScheduleReadingFormError error,
        :final ScheduleReadingField field,
      ):
        emit(
          ScheduleReadingState(
            status: ScheduleReadingStatus.idle,
            form: state.form,
            formError: error,
            formField: field,
          ),
        );
        return;
      case _ParsedScheduleOk(:final ReadingSchedule schedule):
        emit(
          ScheduleReadingState(
            status: ScheduleReadingStatus.submitting,
            form: state.form,
          ),
        );
        final Result<ScheduleResult> result = await scheduleReading(schedule);
        switch (result) {
          case Right<Failure, ScheduleResult>(:final ScheduleResult value):
            emit(
              ScheduleReadingState(
                status: ScheduleReadingStatus.scheduled,
                form: state.form,
                result: value,
              ),
            );
          case Left<Failure, ScheduleResult>(value: final Failure failure):
            emit(
              ScheduleReadingState(
                status: ScheduleReadingStatus.failed,
                form: state.form,
                failure: failure,
              ),
            );
        }
    }
  }

  /// Sends the form again.
  ///
  /// One line delegating to [submit], because this screen has exactly one
  /// request.
  Future<void> retry() => submit();

  /// The new form, in a state that has forgotten the last outcome.
  ///
  /// **AN EDIT CHANGES THE FORM AND NOTHING ELSE**, and it has one rule, in
  /// four parts:
  ///
  /// * **The server's failure stays.** It is the server's answer about the
  ///   request it answered, and the reader correcting a field is not the
  ///   server changing its mind. A refusal that vanished because the reader
  ///   typed would be a refusal the reader never got to read.
  /// * **The arm that names the failed request stays.** The status is what
  ///   names **which** request failed, so a failure that kept its message
  ///   but lost its arm would be about nothing.
  /// * **The form's own refusal goes.** The reader is correcting it, and a
  ///   message that outlives the field it is about is a message about
  ///   something else.
  /// * **The server's answer goes**, and the status that promised it goes
  ///   with it — it answered a form that no longer exists.
  ///
  /// ## AND A REQUEST **IN FLIGHT STAYS IN FLIGHT**
  ///
  /// Because the screen's busy state is the status, and the busy state is
  /// what disables the submit button. An edit that dropped the status would
  /// re-enable the button while the first request was still open — and a
  /// second schedule is not a harmless repeat: the server's own insert is
  /// `ON CONFLICT (group_id, scheduled_date) DO UPDATE`
  /// (`admin.routes.ts:157`), so the second one **replaces** the passage the
  /// first one wrote.
  void _edit(ScheduleReadingForm form) => emit(
    ScheduleReadingState(
      status: _statusAfterEdit(),
      form: form,
      failure: state.failure,
    ),
  );

  /// The status an **edit** leaves behind.
  ///
  /// **THE FAILED REQUEST KEEPS ITS ARM.** The failure is the server's
  /// answer about one request, and the status is what names that request —
  /// so an edit that kept the message and dropped the arm would leave a
  /// state that says "something failed" and cannot say what.
  ///
  /// **AND THE OTHER TWO ARMS ARE ABOUT THE FORM.** A request in flight
  /// stays in flight, and an answer that has gone leaves an idle form.
  ScheduleReadingStatus _statusAfterEdit() => switch (state.status) {
    // **A request in flight stays in flight** — see `_edit`.
    ScheduleReadingStatus.submitting => ScheduleReadingStatus.submitting,
    // **The failed request keeps its arm**, because the failure it names is
    // still on screen.
    ScheduleReadingStatus.failed => ScheduleReadingStatus.failed,
    // **The answer goes**, because it answered a form that no longer
    // exists — and the status that promised it goes with it.
    ScheduleReadingStatus.scheduled => ScheduleReadingStatus.idle,
    ScheduleReadingStatus.idle => ScheduleReadingStatus.idle,
  };
}

/// The form, parsed — or the reason it could not be.
///
/// **Sealed**, because the two answers are the two arms of a decision the
/// cubit has to make and a `null` in a field would make the compiler prove
/// nothing about which arm it is in.
sealed class _ParsedSchedule {
  const _ParsedSchedule();
}

/// The form parsed.
final class _ParsedScheduleOk extends _ParsedSchedule {
  const _ParsedScheduleOk(this.schedule);

  /// The schedule the form describes.
  final ReadingSchedule schedule;
}

/// The form did not parse.
final class _ParsedScheduleRefused extends _ParsedSchedule {
  const _ParsedScheduleRefused(this.error, this.field);

  /// Why.
  final ScheduleReadingFormError error;

  /// Which field the refusal belongs to.
  final ScheduleReadingField field;
}

/// The date shape the server's schema demands.
///
/// `admin.routes.ts:10` types `scheduled_date` as a regex over the text, and
/// this client sends the same shape it sends everywhere else.
final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses [form] into a [ReadingSchedule], or refuses it.
///
/// **Every rule here is the server's own**, and the reason each one is checked
/// before the request is the same: the server's refusal names a field the
/// admin never saw, and a request spent on it is a request the admin cannot
/// learn anything from.
///
/// The order is the order the fields are read in, so the first broken field is
/// the one named.
_ParsedSchedule _parse(ScheduleReadingForm form) {
  final List<int> groupIds = <int>[];
  for (final String part in form.groupIdsText.split(',')) {
    final String trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final int? id = int.tryParse(trimmed);
    if (id == null) {
      return const _ParsedScheduleRefused(
        ScheduleReadingFormError.invalidNumber,
        ScheduleReadingField.groupIds,
      );
    }
    groupIds.add(id);
  }
  if (groupIds.isEmpty) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.emptyGroupIds,
      ScheduleReadingField.groupIds,
    );
  }

  final String date = form.scheduledDateText.trim();
  if (!_datePattern.hasMatch(date)) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.invalidDate,
      ScheduleReadingField.date,
    );
  }

  final int? bookNumber = int.tryParse(form.bookNumberText.trim());
  if (bookNumber == null || bookNumber < 1 || bookNumber > 66) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.invalidNumber,
      ScheduleReadingField.bookNumber,
    );
  }

  final int? startChapter = int.tryParse(form.startChapterText.trim());
  if (startChapter == null || startChapter < 1) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.invalidNumber,
      ScheduleReadingField.startChapter,
    );
  }

  final int? startVerse = int.tryParse(form.startVerseText.trim());
  if (startVerse == null || startVerse < 1) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.invalidNumber,
      ScheduleReadingField.startVerse,
    );
  }

  // The end chapter is **optional**: a passage that stays in one chapter has
  // none, and the server's own transform is `end_chapter ?? start_chapter`
  // (`admin.routes.ts:31-33`).
  final String endChapterRaw = form.endChapterText.trim();
  int? endChapter;
  if (endChapterRaw.isNotEmpty) {
    endChapter = int.tryParse(endChapterRaw);
    if (endChapter == null || endChapter < 1) {
      return const _ParsedScheduleRefused(
        ScheduleReadingFormError.invalidNumber,
        ScheduleReadingField.endChapter,
      );
    }
  }

  final int? endVerse = int.tryParse(form.endVerseText.trim());
  if (endVerse == null || endVerse < 1) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.invalidNumber,
      ScheduleReadingField.endVerse,
    );
  }

  final List<ExcludedVerse> excluded = <ExcludedVerse>[];
  for (final String part in form.excludedVersesText.split(',')) {
    final String trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final List<String> pair = trimmed.split(':');
    if (pair.length != 2) {
      return const _ParsedScheduleRefused(
        ScheduleReadingFormError.invalidExcludedVerse,
        ScheduleReadingField.excludedVerses,
      );
    }
    final int? chapter = int.tryParse(pair[0].trim());
    final int? verse = int.tryParse(pair[1].trim());
    if (chapter == null || verse == null) {
      return const _ParsedScheduleRefused(
        ScheduleReadingFormError.invalidExcludedVerse,
        ScheduleReadingField.excludedVerses,
      );
    }
    excluded.add(ExcludedVerse(chapter: chapter, verse: verse));
  }

  // The range rule, and it reads the **transformed** end chapter — the one the
  // server would read, because the server's schema transform has already
  // substituted the start chapter for a missing end chapter.
  final int effectiveEndChapter = endChapter ?? startChapter;
  if (startChapter > effectiveEndChapter ||
      (startChapter == effectiveEndChapter && startVerse > endVerse)) {
    return const _ParsedScheduleRefused(
      ScheduleReadingFormError.reversedRange,
      ScheduleReadingField.startChapter,
    );
  }

  return _ParsedScheduleOk(
    ReadingSchedule(
      groupIds: groupIds,
      scheduledDate: date,
      bookNumber: bookNumber,
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: endChapter,
      endVerse: endVerse,
      excludedVerses: excluded,
      generateAiQuestions: form.generateAiQuestions,
    ),
  );
}
