import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart';
import 'package:evangelion/features/servant/presentation/widgets/roster_row.dart';
import 'package:evangelion/features/servant/presentation/widgets/servant_app_bar.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The cohort's daily roster report.
///
/// ## AND IT TAKES ITS **CUBIT** AS A PARAMETER
///
/// `null` means "resolve the app's own from the locator", and the cubit is
/// hand-registered in `lib/app/di/navigation_injection.dart` because
/// `flutter_bloc` re-exports the widget layer and the composition root's
/// import graph has to stay Flutter-free. `CommunionPage` is the same shape
/// and the same reason.
///
/// ## AND IT IS **STATEFUL**, AND THE ONE THING ITS STATE DOES IS **GIVE THE
/// DATE'S DEFAULT TO THE CUBIT, ONCE**
///
/// The page used to be a `StatelessWidget` and the seed lived in the form's
/// `didChangeDependencies` — and that is a **frame too late** for a controlled
/// field, because the field's value is the **state's** value: a seed that lands
/// after the first build puts the day on the screen one frame later, and the
/// screen and the state disagree for that frame.
///
/// So the seed is in the page's `initState`, which runs **before** the
/// `BlocBuilder` reads the cubit — and the day is on the screen from the
/// **first frame**, which is what the golden is a picture of.
@RoutePage()
class ServantReportPage extends StatefulWidget {
  /// The report screen.
  const ServantReportPage({super.key, this.cubit, this.today});

  /// The cubit to render, or `null` to resolve the app's own.
  final ServantReportCubit? cubit;

  /// The wall clock the form's date default is read from, or `null` for the
  /// real one.
  ///
  /// ## WHY A PAGE THAT HAS NO CLOCK DEPENDENCY **NEEDS** A CLOCK
  ///
  /// The form's date field is **pre-filled with today**, so the screen's own
  /// rendering depends on the day it is rendered on. That was fine while the
  /// screen had no golden — a widget test asserts the *shape* of what is on
  /// screen, and today's date is a shape.
  ///
  /// **A golden is not a shape: it is a picture.** A picture of
  /// `2026-10-21` is a picture that fails on `2026-10-22`, and a golden that
  /// fails every morning is a golden nobody keeps.
  ///
  /// So the clock is a **seam**, exactly as `CommunionCountdownLine`'s `now` is
  /// — the same shape, the same reason, and the same precedent in this
  /// repository: *"the widget owns the seam that fixes it: the `now` parameter
  /// exists 'for deterministic testing' and the page does not pass it"*.
  ///
  /// **AND THE REAL ONE IS STILL THE DEFAULT.** `null` means `DateTime.now`, so
  /// production is unchanged, and the golden passes a fixed instant.
  final DateTime Function()? today;

  @override
  State<ServantReportPage> createState() => _ServantReportPageState();
}

class _ServantReportPageState extends State<ServantReportPage> {
  @override
  void initState() {
    super.initState();
    // **THE SEED IS THE DATE'S DEFAULT, AND ONLY WHEN THE STATE HAS NONE.**
    //
    // **THE SEED USED TO REPORT THE TWO CONTROLLERS' CONTENTS**, and the
    // controllers start empty — so the seed told the cubit "the servant
    // cleared the cohort", and a servant who left `/servant/report` and came
    // back found their cohort gone and their day reset to today. That is the
    // **one thing the cubit's singleton exists to prevent**: the registration
    // in `navigation_injection.dart` says so in its own words.
    //
    // So the seed reports **the day and nothing else** — and only when the
    // state holds no day at all, because the day on screen is the **state's**
    // to show once the state holds one. A state that holds the day the
    // servant chose keeps it, and a state that holds none gets the default.
    final ServantReportCubit cubit =
        widget.cubit ?? getIt<ServantReportCubit>();
    if (cubit.state.dateText.isEmpty) cubit.setDate(_today());
  }

  /// Today, in the shape the server's querystring wants.
  ///
  /// **A wall clock by default, and a seam for a golden.** The reading screen's
  /// own rule about injected clocks is about what a *frame* depends on — and a
  /// golden is a frame, so the date the form is pre-filled with is a rendering
  /// input and has to be injectable. `ServantReportPage.today` is the seam;
  /// `null` means the real clock, and a golden passes a fixed instant.
  String _today() {
    final DateTime now = (widget.today ?? DateTime.now)();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ServantReportCubit? passed = widget.cubit;
    final ServantReportCubit resolved = passed ?? getIt<ServantReportCubit>();
    return BlocProvider<ServantReportCubit>.value(
      value: resolved,
      // **THE BUILDER IS **ABOVE** THE FORM**, and that is the whole of the
      // sync mechanism: the form is a widget that reads the cohort and the day
      // out of the state, and the two fields are **controlled** — their value
      // is the state's value, and a write the field makes on purpose is never
      // reported as the reader's.
      child: BlocBuilder<ServantReportCubit, ServantReportState>(
        builder: (BuildContext context, ServantReportState state) =>
            _ReportBody(state: state),
      ),
    );
  }
}

/// The form and the roster.
///
/// ## AND EVERY FIELD IS A **CONTROLLED FIELD**
///
/// The cubit holds the **value** — the form's text — and the field holds the
/// text the servant is typing; the two agree because the field reports the
/// reader's input and the state is what the field shows.
///
/// ## AND THE FORM IS **READ BACK** INTO THE FIELDS
///
/// The cubit is a **singleton** — `navigation_injection.dart` says the screen's
/// own state is one of the reasons it is one, and names this screen's share of
/// it: "a reader who left `/servant/questions` and came back would find their
/// edits gone". So the cohort and the day the servant chose have to survive the
/// route being popped and pushed again, and they do: the fields read the state,
/// and the state is the only place the form lives.
class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.state});

  /// The report's state, as the cubit holds it.
  final ServantReportState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);

    // **THE STATE THE PAGE WAS BUILT WITH.** The builder that watches the
    // cubit is **above** this widget, so the state arrives as a widget
    // parameter — and the form reads the cohort and the day out of it.
    final ServantReportState form = state;
    final bool busy = form.status == ServantReportStatus.loading;
    // **THE CUBIT, ONCE.** The two fields report the reader's input to it, and
    // a lookup per field would be two lookups for one object.
    final ServantReportCubit cubit = context.read<ServantReportCubit>();
    return NeuralScaffold(
      scrollable: true,
      // **THE CONTENT IS PUSHED DOWN BY THE APP BAR'S HEIGHT**, because the
      // bar is viewport-fixed and the content scrolls underneath it.
      // `ServantAppBar.height` is the one constant both halves read.
      padding: const EdgeInsets.fromLTRB(
        EvaSpacing.lg,
        ServantAppBar.height,
        EvaSpacing.lg,
        0,
      ),
      // **THE APP BAR IS **VIEWPORT-FIXED**, and not part of the scroll.**
      // See `ServantAppBar`'s doc for the reason: the report form is long
      // enough that a back control which scrolled off would be the last thing
      // on the page until the reader scrolled back — and on the Linux desktop
      // build it is the **only** way out.
      overlay: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ServantAppBar(title: strings.servantReportTitle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            // **THE GROUP IS NAMED AFTER WHAT IT ASKS FOR**, and the screen's
            // name is the app bar's. The two fields below are the cohort and
            // the day, and the group says so in one line rather than leaving
            // the reader to infer it from two field labels.
            label: strings.servantCohortAndDayLabel,
            children: <Widget>[
              EvaControlledField(
                label: strings.servantReportGroupLabel,
                value: form.groupIdText,
                onChanged: cubit.setGroupId,
                keyboardType: TextInputType.number,
                errorText:
                    form.formError == ServantReportFormError.invalidGroupId
                    ? strings.servantReportInvalidGroup
                    : null,
              ),
              EvaControlledField(
                label: strings.servantReportDateLabel,
                value: form.dateText,
                onChanged: cubit.setDate,
                // **THE SWITCH IS **EXHAUSTIVE**, AND THE OTHER REFUSAL IS
                // NAMED AS THE OTHER FIELD'S.** A refusal that is not spelled
                // out here is a refusal the screen cannot draw, and the
                // `schedule_reading_page.dart` helper is the same shape.
                errorText: switch (form.formError) {
                  ServantReportFormError.missingDate =>
                    strings.servantReportMissingDate,
                  ServantReportFormError.invalidDate =>
                    strings.servantReportInvalidDate,
                  ServantReportFormError.invalidGroupId => null,
                  null => null,
                },
              ),
            ],
          ),
          // **THE ACTION IS **OUTSIDE** THE GROUP.** The button is the form's,
          // not the cohort-and-day group's, and a primary action nested inside
          // a labelled group reads as one more thing that group is for.
          const SizedBox(height: EvaSpacing.lg),
          EvaButton(
            label: strings.servantReportSubmit,
            // **Disabled while the request is open**, which is the
            // busy state the screen shows: a second tap would ask for
            // the same roster twice.
            onPressed: busy ? null : cubit.load,
            labelFamily: arabicAwareFamily(direction, EvaTypography.uiFamily),
          ),
          _RosterArea(state: form),
        ],
      ),
    );
  }
}

/// The roster, the empty state, or the failure.
///
/// **A separate widget** so the roster's three branches — the failure, the
/// empty state and the list — have one owner, and the form's build stays a
/// form.
///
/// **AND IT IS NOT A REBUILD SAVER, AND NEVER WAS.** The comment this one
/// replaced claimed the roster's arrival left the form above it unbuilt, and
/// the builder that watches the cubit has been inside the form all along — so
/// the fields were rebuilt by the roster's arrival then too. The builder is
/// **above** the form now (see `ServantReportPage`), which is what lets the
/// form's own widget be rebuilt with the new state, and the fields are still
/// rebuilt either way. The separation buys the *shape* of the code and
/// nothing else.
class _RosterArea extends StatelessWidget {
  const _RosterArea({required this.state});

  /// The report's state.
  final ServantReportState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final Failure? failure = state.failure;
    if (failure != null) {
      return ErrorView(
        // **The server's own sentence**, verbatim — `ErrorView`'s own rule.
        message: failure.message,
        onRetry: () => context.read<ServantReportCubit>().retry(),
        retryLabel: strings.servantReportRetry,
        retryFamily: arabicAwareFamily(
          Directionality.of(context),
          EvaTypography.uiFamily,
        ),
      );
    }

    final ServantReport? report = state.report;
    if (report == null) return const SizedBox.shrink();
    if (report.students.isEmpty) {
      return EmptyState(
        icon: Icons.group_off,
        title: strings.servantReportEmptyTitle,
        message: strings.servantReportEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                value: strings.digits(report.totalStudents),
                label: strings.servantReportTotalStudents,
              ),
            ),
            const SizedBox(width: EvaSpacing.md),
            Expanded(
              child: StatTile(
                value: strings.digits(report.completedCount),
                label: strings.servantReportCompleted,
              ),
            ),
          ],
        ),
        const SizedBox(height: EvaSpacing.md),
        // **A `ListView` and not a `Column`**, because the roster's length is
        // the server's `total_students` and not a number this client knows.
        // `shrinkWrap` and `NeverScrollableScrollPhysics` put it inside the
        // scaffold's own scroll view without a second one.
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: report.students.length,
          separatorBuilder: (BuildContext context, int index) =>
              const HairlineDivider(),
          itemBuilder: (BuildContext context, int index) =>
              RosterRow(student: report.students[index]),
        ),
      ],
    );
  }
}
