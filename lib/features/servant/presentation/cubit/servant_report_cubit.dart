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

  /// The request is open. **There is no roster on screen** — a roster drawn
  /// under a form that is busy asking for another one is a roster about a
  /// different request.
  loading,

  /// An answer is in hand. [ServantReportState.report] is non-null.
  ready,

  /// The request failed. [ServantReportState.failure] is non-null and the
  /// retry control is live.
  failed,
}

/// Why the report form refused to make a request.
///
/// **A client-side refusal, and the reason the server would have refused it
/// anyway — with a 500, not a 400.** `admin.routes.ts:336-342` types the
/// report's querystring as two **strings**, and it declares **no `required`
/// array** at all: the route defaults them at `:373-374` (`group_id || '1'`
/// and `date || today`). So a form that asked for "the cohort" as a word puts
/// a request on the wire that the server hands to `parseInt`, and `parseInt`
/// of a word is **`NaN`** — which Postgres refuses as `22P02 invalid input
/// syntax for type integer: "NaN"`, and the client sees a **500**.
///
/// **So this refusal prevents a server fault, not a client error.** That
/// distinction is why the rule exists here and not only in the schedule form:
/// a 500 is a server's problem wearing the client's request, and the
/// repository's own words at `identity_headers.dart:68` are that a 500 is *"not
/// a thing a reader can be shown"*. The server's own measurement of it is
/// recorded in `docs/BACKEND-VERIFICATION.md`.
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

  /// The date field held something that is not a `YYYY-MM-DD` day.
  ///
  /// ## AND IT IS **NOT** A SECOND SPELLING OF [missingDate]
  ///
  /// An empty field is a field with **no day in it**; a field holding
  /// `2026-10-21&group_id=7` holds a day **and more besides**. The two
  /// refusals are separate because the two things are separate, and the
  /// screen says a different thing about each.
  ///
  /// ## AND THE **SHAPE** IS THE **ROUTE'S OWN**
  ///
  /// `admin.routes.ts:341` declares the querystring's `date` as
  /// `{ type: 'string', description: 'Date in YYYY-MM-DD format' }` — the
  /// route **states** the shape. It does not **check** it: `:373-374` reads
  /// `queryParams.date || today` and hands the text to the database, where the
  /// column's cast is the only enforcement there is.
  ///
  /// **MEASURED, 2026-10-22, on the deployed backend at HEAD `aa1da23`:** a
  /// `?date=not-a-date` answers **500** with
  /// `invalid input syntax for type date: "not-a-date"` — a server fault that
  /// names no field, so the servant is told nothing they can act on. The
  /// measurement is in `docs/BACKEND-VERIFICATION.md`.
  ///
  /// ## AND WHY THE CLIENT REFUSES **FIRST**
  ///
  /// For the reason the schedule form refuses a cohort that is not a number
  /// (`schedule_reading_cubit.dart:81-84`): the server's answer names a field
  /// the servant never saw, and a request spent on it is a request nobody can
  /// learn anything from. A **500 that names nothing** is the worst version
  /// of that answer.
  ///
  /// ## AND THE **SECOND** REASON: A DATE IS **FREE TEXT** IN A **QUERY
  /// STRING**
  ///
  /// `&` is the query string's own separator and `=` separates a name from its
  /// value, so a date that is neither checked nor encoded is not one value —
  /// it is two, and the second one is the server's to believe.
  /// `2026-10-21&group_id=7` is a request about **cohort 7**.
  /// `ReportMapper.pathFor` encodes the value; this is the check that says the
  /// value was never supposed to be a query string.
  ///
  /// ## AND THE **SHAPE** IS **NOT** THE SCHEDULE FORM'S REGEX
  ///
  /// **TWO ROUTES, TWO CONTRACTS, ONE SHAPE — AND THE CLIENT KEEPS THEM
  /// APART.** The schedule route's contract is a **regex the server
  /// enforces** (`admin.routes.ts:10` — `z.string().regex(/^\d{4}-\d{2}-\d{2}$/)`,
  /// and a day that misses it is a **400** that names the field). This
  /// route's contract is a **description the server states and does not
  /// enforce** (`:341`), and a day that misses it is a **500** that names
  /// nothing. Nothing keeps the two routes in step on the server either, so
  /// one shared rule here would tie this form to the other route's schema:
  /// a change to `scheduleSchema` would silently change what the report form
  /// accepts.
  ///
  /// So the two rules are **two contracts that coincide in shape today**, and
  /// each one is written next to the contract it enforces. The house already
  /// keeps two analogous refusals apart and cross-references them in prose —
  /// `schedule_reading_cubit.dart:81-84` is the schedule's **range** refusal
  /// next to the report form's **cohort** refusal, and the two are separate
  /// rules there for the same reason.
  ///
  /// **AND WHAT WOULD CHANGE THE ANSWER:** the backend giving the report
  /// route its own shape check would not make them one rule — each would
  /// still be its own route's rule. What would make them one is the backend
  /// standardising **one** date format across both routes *and* the client
  /// wanting one implementation, and then the shared home would be this
  /// feature's `domain/`, because a fact two writers in one feature need
  /// lives there (`features/settings/domain/settings_clamps.dart` is the
  /// precedent, and it says why).
  invalidDate,
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
///
/// ## AND THE **INVARIANT** IS ONE SENTENCE
///
/// **A roster on screen describes the form on screen, or there is no roster.**
/// The report is a roster of **children**, and the cohort and the day are
/// what the roster is about — the server's own `group_id` and `report_date`
/// (`admin.routes.ts:416-422`), and `ServantReport`'s own doc says the same
/// of `reportDate`: "the report's date is the date the request named".
///
/// **AND IT IS **UNCONDITIONAL**, AND THE WORD THAT CARRIES IT IS "OR".**
/// Not "a roster on screen describes the form **that asked for it**" — a
/// roster that describes the *request* but not the *form* is exactly the
/// wrongness the sentence exists to forbid. So the roster is either **about
/// the form on screen** or **not on screen**, and there is no third case: a
/// roster for cohort 3 under a form that says cohort 7 is one cohort's
/// children under another cohort's name.
///
/// So a status that promises an answer never stands without one, and an
/// **edit** — the only thing a servant can do to this form besides asking —
/// takes the answer away with the form it described.
///
/// ## AND AN **EDIT** IS **ONE RULE**, AND IT IS THE **SIBLINGS'** RULE
///
/// [withGroupId] and [withDate] are the two writers an edit reaches, and
/// they answer the same question the same way:
///
/// * **The roster goes.** It described the form as it **was**, and the form
///   is not that any more.
/// * **The arm that promised the roster goes with it.** `ready` means "an
///   answer is in hand", and the answer is gone.
/// * **The server's failure stays, and the arm that names it.** The failure
///   is the server's answer about the request it answered, and the servant
///   correcting a field is not the server changing its mind.
/// * **A request in flight stays in flight.** The busy state is the status,
///   and the busy state is what disables the button.
/// * **The form's own refusal goes.** The servant is correcting it, and a
///   message that outlives the field it is about is a message about
///   something else.
///
/// `ScheduleReadingCubit._edit` is the same rule, and each part's reason is
/// that file's.
///
/// ## AND THE **COHORT** AND THE **DAY** ARE **ONE RULE**, NOT TWO
///
/// A report is identified by the **pair** — a cohort on a day — so a roster
/// that does not describe the form is a roster about a different request,
/// whichever coordinate moved. The two are not equal in **cost**, and the
/// difference is worth writing down rather than rediscovering:
///
/// * a **cohort** change puts **another cohort's children** on screen — an
///   identity, and the reason the rule exists at all;
/// * a **day** change puts **the same children's other day** on screen — a
///   freshness, and a less alarming version of the same wrongness.
///
/// Both are "a roster that does not describe the form", so both drop it, and
/// **one** rule is cheaper to hold than two that agree by accident.
///
/// ## AND THE COST IS **ACCEPTED**, AND STATED
///
/// A servant who mistypes the cohort loses the loaded roster, and reloads it
/// with one press of the button. That is a cheap price for never showing
/// one cohort's children under another cohort's name.
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

  /// The roster, or `null` while loading, after a failure, and after an
  /// **edit**.
  ///
  /// **AND IT IS NEVER A ROSTER ABOUT ANOTHER REQUEST.** A roster on screen
  /// describes the form on screen — the class doc's invariant.
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
  ///
  /// ## AND THE **ROSTER** GOES WITH IT
  ///
  /// **THE COHORT IS WHAT THE ROSTER IS ABOUT**, so a cohort that changes
  /// under a loaded roster puts **one cohort's children under another
  /// cohort's name** — and the cubit's own refusal already forbids exactly
  /// that shape: "a roster drawn under a form that has been refused is a
  /// roster about a different cohort". A form that is merely *wrong* is the
  /// same shape with a kinder cause.
  ///
  /// The rule, and the cost of it, are the class doc's.
  ServantReportState withGroupId(String text) => ServantReportState(
    status: _statusAfterEdit(),
    groupIdText: text,
    dateText: dateText,
    failure: failure,
  );

  /// The same state with a different date field.
  ///
  /// ## AND THE **DAY** IS **THE SAME RULE**, NOT A SECOND ONE
  ///
  /// The report is a cohort **on a day** — the server's `group_id` and
  /// `report_date` (`admin.routes.ts:416-422`) — so the pair is one thing
  /// and a roster that does not describe the form is a roster about a
  /// different request, whichever coordinate moved. The **cost** differs
  /// (another cohort's children, or the same children's other day), and the
  /// class doc says so.
  ServantReportState withDate(String text) => ServantReportState(
    status: _statusAfterEdit(),
    groupIdText: groupIdText,
    dateText: text,
    failure: failure,
  );

  /// The status an **edit** leaves behind.
  ///
  /// **THE FAILED REQUEST KEEPS ITS ARM, AND THE ANSWER LOSES ITS OWN.**
  ///
  /// The failure is the server's answer about one request, and the status is
  /// what names that request — so an edit that kept the message and dropped
  /// the arm would leave a state that says "something failed" and cannot say
  /// what.
  ///
  /// **AND THE OTHER TWO ARMS ARE ABOUT THE FORM.** A request in flight
  /// stays in flight, and an answer that has gone leaves an idle form —
  /// because the roster it answered described the form as it **was**, and it
  /// went with it.
  ServantReportStatus _statusAfterEdit() => switch (status) {
    // **A request in flight stays in flight** — the busy state is the
    // status, and the busy state is what disables the button.
    ServantReportStatus.loading => ServantReportStatus.loading,
    // **The failed request keeps its arm**, because the failure it names is
    // still on screen.
    ServantReportStatus.failed => ServantReportStatus.failed,
    // **The answer goes**, because the roster it answered described the form
    // as it was — and the arm that promised it goes with it.
    ServantReportStatus.ready => ServantReportStatus.idle,
    ServantReportStatus.idle => ServantReportStatus.idle,
  };
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
///
/// ## AND AN **EDIT** DROPS THE **ROSTER**
///
/// The two writers below are the only things a servant can do to this screen
/// besides asking, and an edit changes what the form describes — so the
/// roster on screen, which described the form as it **was**, goes with it.
/// The rule, and the cost of it, are [ServantReportState]'s.
///
/// ## AND AN ANSWER IS **APPLIED** ONLY IF THE FORM IS **STILL THE FORM**
///
/// **MEASURED, 2026-10-21, over this cubit** — a cohort that changes while
/// the request is open:
///
/// ```text
/// the status while open = loading
/// the status after the edit = loading
/// the form says = 7
/// the status when it lands = ready
/// the form says = 7
/// the report is for = 3
/// ```
///
/// The answer that lands is the one that was **asked for**, and the form has
/// moved on since — so the roster on screen is the roster of the cohort the
/// servant asked about, under a form that names another one. The **edit**
/// rule cannot reach it: the edit happened before the answer existed, and
/// there was no roster to drop.
///
/// **AND SO THE CUBIT **REMEMBERS** THE FORM THE REQUEST WAS MADE WITH.** The
/// request carries the pair the server's own querystring names
/// (`admin.routes.ts:416-422` — `group_id` and `report_date`), and the pair
/// is compared with the pair on screen when the answer lands. **A match
/// applies the answer; a mismatch does not.** The form is remembered **as the
/// request carries it** — the cohort as a whole number and the day trimmed —
/// because the form's **text** is what the servant is halfway through typing,
/// and `03` and `3` are one cohort. [_formStillDescribes] has the rules and
/// the reasons.
///
/// **AND THE **MISMATCH** LEAVES **NO ROSTER, NO FAILURE, AND NO MESSAGE.**
/// The state goes back to the arm it was in before the press, with the form
/// as the servant has it and the button live again — so **the admin presses
/// again**. That is the cost, and it is the **same cost the edit rule
/// already charges**: a press whose answer arrives too late leaves the
/// screen with nothing to show for it.
///
/// **AND THE COST IS **ACCEPTED**, AND IT IS THE PRICE OF THE INVARIANT.** A
/// roster that never contradicts the form is worth a press.
///
/// ## AND **THIS IS A READ**, SO **ITS ANSWER GOES**
///
/// **THE HOUSE'S RULE IS ABOUT **WHAT THE ANSWER IS ABOUT**, AND IT HAS TWO
/// HALVES.** A **read's** answer is a **picture of the form's result** — the
/// roster the server drew for the cohort and the day on the form — so it
/// goes when the form moves on. A **write's** answer **reports a write that
/// happened**, so it stays; `ScheduleReadingCubit`'s doc is the write's half,
/// and the two cubits are **not in conflict** — they are on two sides of one
/// rule. The rule is here and there so that the next reader sees **why they
/// differ** rather than assuming one of them is wrong.
///
/// **AND THE **FAILURE** AND THE **ARM THAT NAMES IT** STAY.** A failure on
/// screen is the server's answer about **one request**, and the servant
/// correcting a field is not the server changing its mind — so the failure
/// and the arm that names it stay, and `retry` still repeats that request.
/// The failure is the one answer the edit rule keeps, and it is kept because
/// it names a request rather than because it describes the form.
///
/// **AND THE COST IS ACCEPTED, AND STATED.** A servant who mistypes the
/// cohort loses the loaded roster, and reloads it with one press of the
/// button. A press whose answer arrives after the form moved on leaves the
/// screen with no roster and no message, and the servant presses again. Both
/// prices are worth paying for a roster that never contradicts the form.
class ServantReportCubit extends Cubit<ServantReportState> {
  /// Drives the report over [loadDailyReport].
  ServantReportCubit({required this.loadDailyReport})
    : super(const ServantReportState(status: ServantReportStatus.idle));

  /// The report request.
  final LoadDailyReport loadDailyReport;

  /// The cohort field changed.
  ///
  /// **AND THE ROSTER GOES WITH IT** — see [ServantReportState].
  void setGroupId(String text) => emit(state.withGroupId(text));

  /// The date field changed.
  ///
  /// **AND THE ROSTER GOES WITH IT** — see [ServantReportState].
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
  /// ## AND A REFUSAL **KEEPS THE FORM** and drops the report
  ///
  /// The form is the servant's and the refusal is about the form, so the
  /// form stays — and the roster goes, because a roster drawn under a form
  /// that has been refused is a roster about a different cohort. That is the
  /// same rule the **edit** writers follow, and [_emitRefused] says why.
  ///
  /// ## AND AN ANSWER THAT **DOES NOT DESCRIBE THE FORM** IS **NOT APPLIED**
  ///
  /// The request carries the form, and the form is compared with the request
  /// when the answer lands — so a roster for a cohort the form no longer
  /// names is not drawn, and the press is repeated instead. The class doc
  /// has the measurement, the rule and the cost.
  Future<void> load() async {
    // **A second request while one is open is refused.** The screen's busy
    // state is the status, and the busy state is what disables the submit
    // button; a caller that asked anyway would get a second roster for a
    // question that has already been answered.
    if (state.status == ServantReportStatus.loading) return;
    final int? groupId = _cohortIn(state.groupIdText);
    if (groupId == null) {
      _emitRefused(ServantReportFormError.invalidGroupId);
      return;
    }
    final String date = state.dateText.trim();
    if (date.isEmpty) {
      _emitRefused(ServantReportFormError.missingDate);
      return;
    }
    // **AND A DAY THAT IS NOT A DAY IS REFUSED TOO**, for the reason
    // [ServantReportFormError.invalidDate] gives: the route states the shape
    // and does not check it, so a day that misses it is a **500** that names
    // nothing — and, unchecked, a date is free text in a query string, where
    // `&` is a separator and not a character.
    if (!_datePattern.hasMatch(date)) {
      _emitRefused(ServantReportFormError.invalidDate);
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

    // **THE ANSWER IS APPLIED **ONLY IF THE FORM IS **STILL THE FORM**.**
    // The request carried the pair the server's own querystring names, and
    // the pair is compared with the pair on screen before the answer is
    // applied — see [_formStillDescribes] and the class doc.
    if (!_formStillDescribes(groupId, date)) {
      _emitDropped();
      return;
    }

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

  /// Whether the form on screen still describes the request that was made.
  ///
  /// ## THE FORM IS COMPARED **AS THE REQUEST CARRIES IT**
  ///
  /// The request carries a **whole number** for the cohort and a **trimmed**
  /// day, and the pair is what the roster is about — so the pair is what is
  /// compared. The form's **text** is what the servant is halfway through
  /// typing, and `03` and `3` are one cohort, so a text that spells the same
  /// cohort is the same form.
  ///
  /// **AND A FORM THAT NAMES NO COHORT IS A MISMATCH.** `three` is not a
  /// cohort, and a roster under a form that cannot be asked for describes
  /// nothing.
  ///
  /// ## AND THE COMPARISON IS **NOT** A COUNTER
  ///
  /// A **generation** — the guard `LeaderboardCubit` and `JourneyCubit` use —
  /// would throw away an answer whose form moved on and came **back**, and
  /// the answer describes the form on screen in that case. So the pair is
  /// compared, and a form that comes back takes its answer.
  bool _formStillDescribes(int groupId, String date) {
    final int? cohort = _cohortIn(state.groupIdText);
    if (cohort == null) return false;
    if (cohort != groupId) return false;
    return state.dateText.trim() == date;
  }

  /// The cohort the form names, or `null` when it names none.
  ///
  /// **ONE PARSE, AND IT IS THE SAME ONE IN BOTH PLACES.** The refusal in
  /// [load] and the comparison in [_formStillDescribes] ask the same
  /// question — "what cohort does this form name?" — and two spellings of
  /// one question are two answers that can disagree.
  static int? _cohortIn(String text) {
    final int? parsed = int.tryParse(text.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// The answer that was not applied, and nothing else.
  ///
  /// **NO ROSTER, NO FAILURE, AND NOTHING CLAIMING THE PRESS DID
  /// SOMETHING.** The state goes back to the arm it was in before the press,
  /// with the form as the servant has it — so the button is live again and
  /// **the admin presses again**. That is the cost, and the class doc says so
  /// in the same breath as the rule.
  void _emitDropped() => emit(
    ServantReportState(
      status: ServantReportStatus.idle,
      groupIdText: state.groupIdText,
      dateText: state.dateText,
    ),
  );

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

/// The date shape **the report route** names.
///
/// `admin.routes.ts:341` declares the querystring's `date` as
/// `{ type: 'string', description: 'Date in YYYY-MM-DD format' }` — the route
/// states the shape, and does not check it.
///
/// ## AND IT IS **NOT** THE SCHEDULE FORM'S REGEX, AND THE REASON IS **TWO
/// CONTRACTS**
///
/// The schedule route's contract is a **regex the server enforces**
/// (`admin.routes.ts:10` — `z.string().regex(/^\d{4}-\d{2}-\d{2}$/)`), and a
/// day that misses it is a **400** that names the field. This route's
/// contract is a **description the server states and does not enforce**
/// (`:341`), and a day that misses it is a **500** that names nothing
/// (`invalid input syntax for type date`, measured 2026-10-22 at HEAD
/// `aa1da23`).
///
/// **Nothing keeps the two routes in step on the server either**, so one
/// shared rule here would tie this form to the *other* route's schema: a
/// change to `scheduleSchema` would silently change what the report form
/// accepts, and the report form would then refuse days the report route
/// answers. They are two contracts that coincide in shape today, and each
/// rule is written next to the contract it enforces.
///
/// **AND THE SHAPE IS **NOT** A CALENDAR RULE.** `2026-02-31` is in this
/// shape and is not a day — and the *server* is what refuses it, with a 500
/// from the database's cast. A client rule the reader cannot discover is
/// worse than no rule at all, so the rule here is the route's own shape and
/// nothing more.
final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
