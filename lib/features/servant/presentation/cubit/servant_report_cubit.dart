import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/usecases/load_daily_report.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'servant_report_cubit.freezed.dart';

/// Where `/servant/report` is in its own lifecycle.
///
/// Four values, and `LeaderboardStatus`'s doc gives the argument that applies here
/// verbatim: "loading" is **not** "no data", and a two-value enum would have to
/// encode it as one — a servant would be told the cohort is empty while the
/// request is still open.
///
/// The fourth is [idle], and it is the one the two others do not have: a form
/// that has not been submitted is not a request that failed and not a request
/// that is in flight, and folding it into either would paint a state the
/// server never answered.
enum ServantReportStatus {
  /// Nothing has been asked for yet. The form is on screen and empty.
  idle,

  /// The request is open. The roster on screen is the previous one.
  loading,

  /// An answer is in hand. [ServantReportState.report] is non-null.
  ready,

  /// The request failed. [ServantReportState.failure] is non-null and the
  /// retry control is live.
  failed,
}

/// Why the report form refused to make a request.
///
/// **A client-side refusal, and the reason the server would have refused
/// anyway.** `admin.routes.ts:340-364` types the report's querystring as two
/// required fields, and the cohort id is a number — so a form that asked for
/// "the cohort" as a word would put a request on the wire that the server
/// answers with a 400 the client could have predicted.
///
/// The refusal is a **named outcome** and not a message, because the page has
/// to draw it in the reader's own language and the ARB is the only place that
/// language lives. The cubit holds no strings.
enum ServantReportFormError {
  /// The cohort field held something that is not a whole number above zero.
  invalidGroupId,

  /// The date field was empty.
  ///
  /// The server defaults the date to its own today when the querystring
  /// omits it (`admin.routes.ts:374`), and this client always sends one — so
  /// an empty date is this client's own gap, not a server rule.
  missingDate,
}

/// What `/servant/report` is showing.
///
/// ## WHY THE FIELDS ARE **TEXT** AND NOT NUMBERS
///
/// The cohort and the date are two `String`s here, and the numbers they will
/// become are parsed on submit. The reason is the one `EvaTextField`'s own doc
/// records: "the controller is the caller's; a caller adds a listener" — so the
/// controller holds a *string* while the reader is halfway through typing it,
/// and a cubit that held an `int` would have to be told what to hold for the
/// half-typed state. `1` is a whole number; `1` on its way to `12` is a
/// string, and the string is the only thing that can be both.
///
/// The parse therefore happens **once**, in [ServantReportCubit.load], and it
/// is the parse that refuses — never the field.
@Freezed(copyWith: false)
final class ServantReportState with _$ServantReportState {
  /// A state on the given arm.
  ///
  /// **`status` is required and not defaulted**, and that is the whole of the
  /// reason: a defaulted status would let a writer leave it out, and a writer
  /// that leaves the status out is a writer that did not say which arm of the
  /// lifecycle it is on. Every construction below names it.
  const ServantReportState({
    required this.status,
    this.groupIdText = '',
    this.dateText = '',
    this.report,
    this.failure,
    this.formError,
  });

  /// Which lifecycle arm this is.
  final ServantReportStatus status;

  /// The cohort field, verbatim.
  final String groupIdText;

  /// The date field, verbatim.
  final String dateText;

  /// The roster, or `null` while loading and after a failure.
  final ServantReport? report;

  /// Why the request failed, or `null`.
  final Failure? failure;

  /// Why the form refused to ask, or `null`.
  final ServantReportFormError? formError;

  /// The same state with a different cohort field.
  ///
  /// **A whole-state writer, and one of two.** `@Freezed(copyWith: false)`
  /// is what makes this necessary: freezed's generated `copyWith` is a
  /// *partial* writer, and a partial writer is a second spelling of these two
  /// methods that nobody would remember to keep in step. `HomeState`'s six
  /// writers are the precedent, and its doc gives the reason.
  ServantReportState withGroupId(String text) => ServantReportState(
    status: status,
    groupIdText: text,
    dateText: dateText,
    report: report,
    failure: failure,
    formError: formError,
  );

  /// The same state with a different date field.
  ServantReportState withDate(String text) => ServantReportState(
    status: status,
    groupIdText: groupIdText,
    dateText: text,
    report: report,
    failure: failure,
    formError: formError,
  );
}

/// Drives `/servant/report` through [load] and [retry].
///
/// ## AND IT IS A **`Cubit`, NOT A `Bloc`**
///
/// `ReadingCubit`'s doc gives the argument that applies here: `HomeBloc` is a
/// `Bloc` because it has four event types whose equality its tests assert.
/// This has **no events** — every operation is a method parameter, `bloc.add`
/// is not reachable, and there is no event stream to lose on a route pop.
///
/// ## AND IT TAKES ITS **USE CASE**, NEVER ITS REPOSITORY
///
/// §3's DIP row: "no `domain/` file ever names a concrete implementation", and
/// the mirror of it — no presentation file names a repository either. The
/// cubit depends on [LoadDailyReport], so a test drives the real use case over
/// a fake port, and the port is the only thing that has to be faked.
class ServantReportCubit extends Cubit<ServantReportState> {
  /// Drives the report over [loadDailyReport].
  ServantReportCubit({required this.loadDailyReport})
    : super(const ServantReportState(status: ServantReportStatus.idle));

  /// The report request.
  final LoadDailyReport loadDailyReport;

  /// The cohort field changed.
  void setGroupId(String text) => emit(state.withGroupId(text));

  /// The date field changed.
  void setDate(String text) => emit(state.withDate(text));

  /// Asks for the roster on the form and answers with the whole state.
  ///
  /// ## THE REFUSAL COMES **BEFORE** THE REQUEST
  ///
  /// A cohort that is not a whole number, or a date that is empty, is refused
  /// here — and the request is never made. The server would have refused it
  /// too, with a 400 whose body names a field the servant never saw; a client
  /// that asks first has said the same thing in the servant's own language and
  /// has not spent a request on it.
  ///
  /// ## AND A REFUSAL **KEEPS THE FORM** and the last report
  Future<void> load() async {
    // **A second request while one is open is refused.** The screen's busy
    // state is the status, and the busy state is what disables the submit
    // button; a caller that asked anyway would get a second roster for a
    // question that has already been answered.
    if (state.status == ServantReportStatus.loading) return;
    final String groupIdRaw = state.groupIdText.trim();
    final int? groupId = int.tryParse(groupIdRaw);
    if (groupId == null || groupId <= 0) {
      _emitRefused(ServantReportFormError.invalidGroupId);
      return;
    }
    final String date = state.dateText.trim();
    if (date.isEmpty) {
      _emitRefused(ServantReportFormError.missingDate);
      return;
    }

    emit(
      ServantReportState(
        status: ServantReportStatus.loading,
        groupIdText: state.groupIdText,
        dateText: state.dateText,
      ),
    );

    final Result<ServantReport> result = await loadDailyReport(
      DailyReportQuery(groupId: groupId, date: date),
    );
    switch (result) {
      case Right<Failure, ServantReport>(:final ServantReport value):
        emit(
          ServantReportState(
            status: ServantReportStatus.ready,
            groupIdText: state.groupIdText,
            dateText: state.dateText,
            report: value,
          ),
        );
      case Left<Failure, ServantReport>(value: final Failure failure):
        emit(
          ServantReportState(
            status: ServantReportStatus.failed,
            groupIdText: state.groupIdText,
            dateText: state.dateText,
            failure: failure,
          ),
        );
    }
  }

  /// Asks again, for the cohort and the date on the form.
  ///
  /// One line delegating to [load], because this screen has exactly one
  /// request — a second spelling of `load` with nothing to distinguish the
  /// calls would be a method that exists only to be read as "retry" at the
  /// call site.
  Future<void> retry() => load();

  /// The refusal, and nothing else.
  ///
  /// **The report is dropped.** A refusal means the request on screen is not
  /// the request the form describes, and a roster drawn under a form that has
  /// been refused is a roster about a different cohort.
  void _emitRefused(ServantReportFormError error) => emit(
    ServantReportState(
      status: ServantReportStatus.idle,
      groupIdText: state.groupIdText,
      dateText: state.dateText,
      formError: error,
    ),
  );
}
