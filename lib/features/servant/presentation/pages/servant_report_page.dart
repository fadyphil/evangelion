import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart';
import 'package:evangelion/features/servant/presentation/widgets/roster_row.dart';
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
@RoutePage()
class ServantReportPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ServantReportCubit? passed = cubit;
    final ServantReportCubit resolved = passed ?? getIt<ServantReportCubit>();
    return BlocProvider<ServantReportCubit>.value(
      value: resolved,
      // **THE BUILDER IS **ABOVE** THE FORM**, and that is the whole of the
      // sync mechanism: the form is a `StatefulWidget` that owns the two
      // controllers, and it can only learn that the cohort on screen changed
      // if its own widget is rebuilt with the new state — which is what
      // `didUpdateWidget` is for. A builder inside the form would rebuild the
      // form's own subtree and never the form, and the fields would never
      // fill.
      child: BlocBuilder<ServantReportCubit, ServantReportState>(
        builder: (BuildContext context, ServantReportState state) =>
            _ReportBody(state: state, today: today),
      ),
    );
  }
}

/// The form and the roster.
///
/// ## AND THE **CONTROLLERS** ARE THE PAGE'S
///
/// `EvaTextField`'s contract is that the controller is the caller's, and this
/// widget is the caller. The cubit holds the **value** — the form's text — and
/// the controller holds the text the servant is typing; the two agree because
/// the page reports every keystroke and never writes into a controller behind
/// the cubit's back.
///
/// ## AND THE FORM IS **READ BACK** INTO ITS OWN CONTROLLERS
///
/// The cubit is a **singleton** — `navigation_injection.dart` says the screen's
/// own state is one of the reasons it is one, and names this screen's share of
/// it: "a reader who left `/servant/questions` and came back would find their
/// edits gone". So the cohort and the day the servant chose have to survive the
/// route being popped and pushed again, and they do: the page **fills its own
/// controllers from the state at mount**, before the listeners are attached,
/// and then on every rebuild through the one-sided sync.
///
/// **THE PAGE USED TO SEED THE CUBIT WITH THE CONTROLLERS' CONTENTS AT MOUNT**,
/// and the controllers start empty — so the seed told the cubit "the servant
/// cleared the cohort", and a servant who left `/servant/report` and came back
/// found an empty form under the roster they had loaded, with the day reset to
/// today. The seed defeated the reason for the singleton, and the refusal it
/// invited (`ServantReportFormError.invalidGroupId`) dropped the roster on top
/// of it.
class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.state, this.today});

  /// The report's state, as the cubit holds it.
  final ServantReportState state;

  /// The wall clock the date default is read from. See [ServantReportPage.today].
  final DateTime Function()? today;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  final TextEditingController _group = TextEditingController();
  final TextEditingController _date = TextEditingController();

  /// The listeners added to the two controllers, so [dispose] can remove
  /// exactly those and not whatever is there.
  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Whether the date's default has been given to the cubit yet.
  ///
  /// **ONCE, AND ONLY ONCE.** The default is the screen's own — today, or the
  /// instant the `today` seam names — and the state is what the screen shows
  /// afterwards, so applying the default again after a dependency change would
  /// undo the day the servant chose.
  bool _seeded = false;

  /// Whether the page is writing into a controller on purpose.
  ///
  /// **A WRITE THE PAGE MADE IS NOT SOMETHING THE READER DID.** The one-sided
  /// sync fills a controller from the state, and the controller tells its
  /// listener — which is the page's own way of reporting a keystroke. A write
  /// the page made on purpose, reported that way, told the cubit the servant
  /// had typed — and the cubit cannot tell the two apart.
  bool _writing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ServantReportCubit cubit = context.read<ServantReportCubit>();

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
    if (!_seeded) {
      _seeded = true;
      if (cubit.state.dateText.isEmpty) cubit.setDate(_today());
    }

    // **THE PAGE FILLS ITS OWN CONTROLLERS FROM THE STATE, AND IT DOES IT
    // BEFORE THE LISTENERS ARE ATTACHED.** The two controllers are the page's
    // own and they are built empty, so the cohort and the day on screen are
    // the **state's** to show — and a write the page made on purpose is not
    // something the servant did, so it is made before the listeners are
    // attached and it reports nothing.
    _syncFrom(cubit.state);

    for (final VoidCallback listener in _listeners) {
      _group.removeListener(listener);
      _date.removeListener(listener);
    }
    _listeners
      ..clear()
      ..add(() => _report(cubit.setGroupId, _group.text))
      ..add(() => _report(cubit.setDate, _date.text));
    _group.addListener(_listeners[0]);
    _date.addListener(_listeners[1]);
  }

  @override
  void didUpdateWidget(_ReportBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **THE ONE-SIDED SYNC.** A controller is written only when the form on
    // screen says something different, so a rebuild never moves the caret and
    // the servant's own edit is never undone.
    _syncFrom(widget.state);
  }

  /// Writes the form in [state] into the two controllers.
  ///
  /// **THE STATE IS THE TRUTH, AND THE CONTROLLERS ARE THE PAGE'S.** The two
  /// are one form in two shapes, and this is the direction that fills the
  /// fields: the servant comes back to the route, and the two controllers are
  /// built empty every time.
  ///
  /// **AND EVERY FIELD'S DIRECTION IS DECIDED THE SAME WAY.** The state
  /// decides, per field, and the comparison is that field's own — so there is
  /// no whole-form copy that could carry a stale field over a fresh one.
  ///
  /// **AND IT REPORTS NOTHING.** Every write here is the page's own, and the
  /// controller's listener is the page's own way of reporting a keystroke.
  void _syncFrom(ServantReportState state) {
    _write(_group, state.groupIdText);
    _write(_date, state.dateText);
  }

  /// Writes [value] into [controller] when they differ, and tells the cubit
  /// **nothing**.
  ///
  /// **The write is the page's own**, and the controller's listener is the
  /// page's own way of reporting a keystroke — so a listener that reported
  /// this write would be telling the cubit the servant had typed.
  ///
  /// The controller notifies its listeners **synchronously**, so [_writing] is
  /// up for the whole write and down before the frame ends, and the
  /// `try`/`finally` puts it down even if the write throws.
  void _write(TextEditingController controller, String value) {
    if (controller.text == value) return;
    _writing = true;
    try {
      controller.text = value;
    } finally {
      _writing = false;
    }
  }

  /// Reports [text] to [report] — unless the page is writing on purpose.
  ///
  /// **A WRITE THE PAGE MADE IS NOT SOMETHING THE READER DID**, and the
  /// cubit must not be told it was: its writers answer a keystroke by
  /// replacing the form's text, and a text the page wrote on purpose was
  /// never the reader's keystroke.
  void _report(void Function(String) report, String text) {
    if (_writing) return;
    report(text);
  }

  @override
  void dispose() {
    for (final VoidCallback listener in _listeners) {
      _group.removeListener(listener);
      _date.removeListener(listener);
    }
    _group.dispose();
    _date.dispose();
    super.dispose();
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
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);

    // **THE STATE THE PAGE WAS BUILT WITH.** The builder that watches the
    // cubit is **above** this widget, so the state arrives as a widget
    // parameter — and the page can then compare it with its own controllers.
    final ServantReportState state = widget.state;
    final bool busy = state.status == ServantReportStatus.loading;
    return NeuralScaffold(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            label: strings.servantReportTitle,
            children: <Widget>[
              EvaTextField(
                label: strings.servantReportGroupLabel,
                controller: _group,
                keyboardType: TextInputType.number,
                errorText:
                    state.formError == ServantReportFormError.invalidGroupId
                    ? strings.servantReportInvalidGroup
                    : null,
              ),
              EvaTextField(
                label: strings.servantReportDateLabel,
                controller: _date,
                errorText: state.formError == ServantReportFormError.missingDate
                    ? strings.servantReportMissingDate
                    : null,
              ),
              EvaButton(
                label: strings.servantReportSubmit,
                // **Disabled while the request is open**, which is the
                // busy state the screen shows: a second tap would ask for
                // the same roster twice.
                onPressed: busy
                    ? null
                    : () => context.read<ServantReportCubit>().load(),
                labelFamily: arabicAwareFamily(
                  direction,
                  EvaTypography.uiFamily,
                ),
              ),
            ],
          ),
          _RosterArea(state: state),
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
