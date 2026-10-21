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
  const ServantReportPage({super.key, this.cubit});

  /// The cubit to render, or `null` to resolve the app's own.
  final ServantReportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final ServantReportCubit? passed = cubit;
    final ServantReportCubit resolved = passed ?? getIt<ServantReportCubit>();
    return BlocProvider<ServantReportCubit>.value(
      value: resolved,
      child: const _ReportBody(),
    );
  }
}

/// The form and the roster.
///
/// ## AND THE **CONTROLLERS** ARE THE PAGE'S
///
/// `EvaTextField`'s contract is that the controller is the caller's, and this
/// widget is the caller. The cubit holds the **value** — the form's text — and
/// the controller holds the text the admin is typing; the two agree because
/// the page reports every keystroke and never writes into a controller behind
/// the cubit's back.
class _ReportBody extends StatefulWidget {
  const _ReportBody();

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  final TextEditingController _group = TextEditingController();
  final TextEditingController _date = TextEditingController();

  /// The listeners added to the two controllers, so [dispose] can remove
  /// exactly those and not whatever is there.
  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Whether the form has been reported to the cubit yet.
  ///
  /// **The page's form is the truth on mount**, and the cubit is told what it
  /// says — the date in particular, which the page fills with today so the
  /// servant is not asked to type it.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _date.text = _today();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ServantReportCubit cubit = context.read<ServantReportCubit>();

    for (final VoidCallback listener in _listeners) {
      _group.removeListener(listener);
      _date.removeListener(listener);
    }
    _listeners
      ..clear()
      ..add(() => cubit.setGroupId(_group.text))
      ..add(() => cubit.setDate(_date.text));
    _group.addListener(_listeners[0]);
    _date.addListener(_listeners[1]);

    if (!_seeded) {
      _seeded = true;
      cubit
        ..setGroupId(_group.text)
        ..setDate(_date.text);
    }
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
  /// **A wall clock, and it is a form default rather than a decoration** — the
  /// reading screen's own rule about injected clocks is about what a *frame*
  /// depends on, and a form's default date is not a frame.
  static String _today() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);

    return BlocBuilder<ServantReportCubit, ServantReportState>(
      builder: (BuildContext context, ServantReportState state) {
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
                    errorText:
                        state.formError == ServantReportFormError.missingDate
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
      },
    );
  }
}

/// The roster, the empty state, or the failure.
///
/// **A separate widget** so the form above it is not rebuilt by every state
/// change of the roster below — the same reason `HomePage` splits its body.
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
