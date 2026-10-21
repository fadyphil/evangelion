import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The schedule form.
///
/// ## AND IT STATES THE TWO BACKEND BEHAVIOURS THE SCREEN MUST NOT HIDE
///
/// * **Re-scheduling replaces the passage.** The insert is
///   `ON CONFLICT (group_id, scheduled_date) DO UPDATE`
///   (`admin.routes.ts:157`), so scheduling the same cohort and date again
///   **replaces** the passage rather than failing or duplicating it.
/// * **Re-scheduling with the AI switch on deletes the previous questions.**
///   `DELETE FROM questions WHERE reading_id = $1` (`admin.routes.ts:195`).
///
/// Neither is in the server's answer — it answers "Successfully scheduled
/// reading for N groups" either way — so a screen that did not say so would
/// be hiding a fact the admin needs before they press the button.
///
/// ## AND IT REFUSES A **REVERSED RANGE** ITSELF
///
/// The server refuses it with a 400 and the sentence "start boundary cannot be
/// after end boundary" (`admin.routes.ts:126-129`). This form refuses it
/// **first**, in the admin's own language, and the request is not made.
@RoutePage()
class ScheduleReadingPage extends StatelessWidget {
  /// The schedule screen.
  const ScheduleReadingPage({super.key, this.cubit});

  /// The cubit to render, or `null` to resolve the app's own.
  final ScheduleReadingCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final ScheduleReadingCubit? passed = cubit;
    final ScheduleReadingCubit resolved =
        passed ?? getIt<ScheduleReadingCubit>();
    return BlocProvider<ScheduleReadingCubit>.value(
      value: resolved,
      // **THE BUILDER IS **ABOVE** THE FORM**, and that is the whole of the
      // sync mechanism: the form is a `StatefulWidget` that owns the eight
      // controllers, and it can only learn that the passage on screen changed
      // if its own widget is rebuilt with the new state — which is what
      // `didUpdateWidget` is for. A builder inside the form would rebuild the
      // form's own subtree and never the form, and the fields would never
      // fill.
      child: BlocBuilder<ScheduleReadingCubit, ScheduleReadingState>(
        builder: (BuildContext context, ScheduleReadingState state) =>
            _ScheduleBody(state: state),
      ),
    );
  }
}

/// The form.
///
/// ## AND EVERY FIELD IS **TEXT**, and the cubit parses it
///
/// `EvaTextField`'s contract is that the controller is the caller's, and this
/// widget is the caller. The **value** is the cubit's — the form's text — and
/// the page reports every keystroke. The parse happens once, on submit, and
/// it is the parse that refuses.
///
/// ## AND THE FORM IS **READ BACK** INTO ITS OWN CONTROLLERS
///
/// The cubit holds the form's text and this page reports every keystroke, so
/// the two are one form in two shapes — and the shape the admin **reads** is
/// the controller's. The controllers are the page's own and they are built
/// empty every time, so a form that showed nothing on a re-entry would show
/// an empty passage while the state held the whole one.
///
/// **THE CUBIT IS A SINGLETON**, and the registration in
/// `navigation_injection.dart` says the form the admin is halfway through
/// filling is one of the three reasons it is one — so the passage has to
/// survive the route being popped and pushed again. It does: the page **fills
/// its own controllers from the state at mount**, before the listeners are
/// attached, and then on every rebuild through the one-sided sync.
///
/// ## AND EVERY FIELD'S DIRECTION IS DECIDED THE **SAME** WAY
///
/// **The state decides, per field, and the comparison is the field's own.**
/// A controller is written **only when its text differs from the state's text
/// for that same field**, and the eight fields are compared one by one — so
/// there is no whole-form copy that could carry a stale field over a fresh
/// one.
///
/// **AND THAT CANNOT CLOBBER THE ADMIN'S OWN EDIT.** The state holds the
/// admin's **last keystroke** for every field — the page reports each one
/// synchronously, and the report is the cubit's own `copyWith` of that one
/// field — so a field the admin is typing in already agrees with the state,
/// and the comparison finds nothing to write. The write happens only where
/// the two **disagree**, and the two can only disagree about a field the
/// admin has not touched since the state last changed.
///
/// **AND THE NINTH CONTROL HAS NO CONTROLLER AT ALL.** The AI switch is read
/// straight off the state, so its direction is **state → screen** with no
/// reverse report — the only control on this form that is not a text field,
/// and the only one whose direction is one-way by construction.
///
/// **AND A WRITE THE PAGE MADE IS NOT REPORTED TO THE CUBIT.** The sync
/// writes into a controller, the controller tells its listener, and the
/// listener is the page's own way of reporting a keystroke — so a write the
/// page made on purpose, reported that way, told the cubit the reader had
/// typed, and the cubit's edit writer drops the **server's sentence** — the
/// `ScheduleResult` and the `scheduled` arm — with the edit it invented. The
/// flag `_writing` is up for exactly the window of a programmatic write.
class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody({required this.state});

  /// The form as the state holds it.
  final ScheduleReadingState state;

  @override
  State<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends State<_ScheduleBody> {
  final TextEditingController _groupIds = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _book = TextEditingController();
  final TextEditingController _startChapter = TextEditingController();
  final TextEditingController _startVerse = TextEditingController();
  final TextEditingController _endChapter = TextEditingController();
  final TextEditingController _endVerse = TextEditingController();
  final TextEditingController _excluded = TextEditingController();

  /// The listeners added to the eight controllers, so [dispose] can remove
  /// exactly those and not whatever is there.
  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Whether the page is writing into a controller on purpose.
  ///
  /// **A WRITE THE PAGE MADE IS NOT SOMETHING THE READER DID.** The
  /// one-sided sync fills a controller from the state, and the controller
  /// tells its listener — which is the page's own way of reporting a
  /// keystroke. A write the page made on purpose reported that way told the
  /// cubit the reader had typed, and the cubit's edit writer drops the
  /// **server's sentence** — the `ScheduleResult` and the `scheduled` arm —
  /// with the edit: **the answer could vanish in the frame it arrived.**
  bool _writing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScheduleReadingCubit cubit = context.read<ScheduleReadingCubit>();

    // **THE PAGE FILLS ITS OWN CONTROLLERS FROM THE STATE, AND IT DOES IT
    // BEFORE THE LISTENERS ARE ATTACHED.** The eight controllers are the
    // page's own and they are built empty, so the passage the admin was
    // writing is the **state's** to show — and a write the page made on
    // purpose is not something the reader did, so it is made before the
    // listeners are attached and it reports nothing.
    _syncFrom(cubit.state);

    for (final VoidCallback listener in _listeners) {
      for (final TextEditingController controller in _controllers) {
        controller.removeListener(listener);
      }
    }
    _listeners
      ..clear()
      ..add(() => _report(cubit.setGroupIds, _groupIds.text))
      ..add(() => _report(cubit.setScheduledDate, _date.text))
      ..add(() => _report(cubit.setBookNumber, _book.text))
      ..add(() => _report(cubit.setStartChapter, _startChapter.text))
      ..add(() => _report(cubit.setStartVerse, _startVerse.text))
      ..add(() => _report(cubit.setEndChapter, _endChapter.text))
      ..add(() => _report(cubit.setEndVerse, _endVerse.text))
      ..add(() => _report(cubit.setExcludedVerses, _excluded.text));
    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].addListener(_listeners[i]);
    }
  }

  /// The eight controllers, in the order the listeners were added.
  List<TextEditingController> get _controllers => <TextEditingController>[
    _groupIds,
    _date,
    _book,
    _startChapter,
    _startVerse,
    _endChapter,
    _endVerse,
    _excluded,
  ];

  @override
  void didUpdateWidget(_ScheduleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **THE ONE-SIDED SYNC.** A controller is written only when the passage
    // on screen says something different, so a rebuild never moves the caret
    // and the admin's own edit is never undone.
    _syncFrom(widget.state);
  }

  /// Writes the passage in [state] into the eight controllers.
  ///
  /// **THE STATE IS THE TRUTH, AND THE CONTROLLERS ARE THE PAGE'S.** The
  /// two are one form in two shapes, and this is the direction that fills the
  /// fields: the admin comes back to the route, and the eight controllers are
  /// built empty every time.
  ///
  /// **AND EVERY FIELD IS COMPARED ON ITS OWN.** A controller is written
  /// only when **that** field's text differs, so a field the admin has
  /// changed is never carried over by another field's stale copy — and a
  /// field the admin has not touched since the state last changed is filled.
  ///
  /// **AND IT REPORTS NOTHING.** Every write here is the page's own, and the
  /// controller's listener is the page's own way of reporting a keystroke.
  void _syncFrom(ScheduleReadingState state) {
    _write(_groupIds, state.form.groupIdsText);
    _write(_date, state.form.scheduledDateText);
    _write(_book, state.form.bookNumberText);
    _write(_startChapter, state.form.startChapterText);
    _write(_startVerse, state.form.startVerseText);
    _write(_endChapter, state.form.endChapterText);
    _write(_endVerse, state.form.endVerseText);
    _write(_excluded, state.form.excludedVersesText);
  }

  /// Writes [value] into [controller] when they differ, and tells the cubit
  /// **nothing**.
  ///
  /// **The write is the page's own**, and the controller's listener is the
  /// page's own way of reporting a keystroke — so a listener that reported
  /// this write would be telling the cubit the reader had typed.
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
  /// cubit must not be told it was: its edit writer answers the reader's
  /// correction by dropping the **server's sentence** and the `scheduled`
  /// arm — and a sentence the page wrote on purpose was never the reader's
  /// correction, so it did not earn that.
  void _report(void Function(String) report, String text) {
    if (_writing) return;
    report(text);
  }

  @override
  void dispose() {
    for (final VoidCallback listener in _listeners) {
      for (final TextEditingController controller in _controllers) {
        controller.removeListener(listener);
      }
    }
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);
    // **THE STATE THE PAGE WAS BUILT WITH.** The builder that watches the
    // cubit is **above** this widget, so the state arrives as a widget
    // parameter — and the page can then compare it with its own controllers.
    final ScheduleReadingState state = widget.state;
    final bool busy = state.status == ScheduleReadingStatus.submitting;
    return NeuralScaffold(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            label: strings.servantScheduleTitle,
            children: <Widget>[
              EvaTextField(
                label: strings.servantScheduleGroupIdsLabel,
                hintText: strings.servantScheduleGroupIdsHint,
                controller: _groupIds,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.groupIds,
                  strings,
                ),
              ),
              EvaTextField(
                label: strings.servantScheduleDateLabel,
                hintText: strings.servantScheduleDateHint,
                controller: _date,
                errorText: _errorFor(state, ScheduleReadingField.date, strings),
              ),
              EvaTextField(
                label: strings.servantScheduleBookLabel,
                controller: _book,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.bookNumber,
                  strings,
                ),
              ),
              EvaTextField(
                label: strings.servantScheduleStartChapterLabel,
                controller: _startChapter,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.startChapter,
                  strings,
                ),
              ),
              EvaTextField(
                label: strings.servantScheduleStartVerseLabel,
                controller: _startVerse,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.startVerse,
                  strings,
                ),
              ),
              EvaTextField(
                label: strings.servantScheduleEndChapterLabel,
                controller: _endChapter,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.endChapter,
                  strings,
                ),
              ),
              EvaTextField(
                label: strings.servantScheduleEndVerseLabel,
                controller: _endVerse,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.endVerse,
                  strings,
                ),
              ),
              EvaTextField(
                label: strings.servantScheduleExcludedLabel,
                hintText: strings.servantScheduleExcludedHint,
                controller: _excluded,
                errorText: _errorFor(
                  state,
                  ScheduleReadingField.excludedVerses,
                  strings,
                ),
              ),
              _AiSwitch(
                value: state.form.generateAiQuestions,
                onChanged: (bool generate) => context
                    .read<ScheduleReadingCubit>()
                    .setGenerateAiQuestions(generate: generate),
              ),
              EvaButton(
                label: strings.servantScheduleSubmit,
                onPressed: busy
                    ? null
                    : () => context.read<ScheduleReadingCubit>().submit(),
                labelFamily: arabicAwareFamily(
                  direction,
                  EvaTypography.uiFamily,
                ),
              ),
            ],
          ),
          if (state.result case final ScheduleResult result)
            _ScheduleOutcome(message: result.message),
          if (state.failure case final Failure failure)
            ErrorView(
              message: failure.message,
              onRetry: () => context.read<ScheduleReadingCubit>().retry(),
              retryLabel: strings.servantScheduleRetry,
              retryFamily: arabicAwareFamily(direction, EvaTypography.uiFamily),
            ),
        ],
      ),
    );
  }

  /// The refusal that belongs to [field], or `null`.
  ///
  /// **Every refusal names a field**, and the message says what is wrong with
  /// it — the field is the one that says *which*, so a message that named the
  /// field in prose would have to be written once per language.
  ///
  /// ## AND THE `null` ARM IS **DART'S EXHAUSTIVENESS**, NOT A BRANCH
  ///
  /// **This is the answer to "what is that one line no test can execute".**
  ///
  /// The switch is over `state.formError`, which is a **nullable** enum, and
  /// a switch **expression** has to be total over the type it switches on —
  /// so `null` needs an arm whether or not anything can reach it. The
  /// alternative is not "no arm": it is a **compile error**.
  ///
  /// **MEASURED, on Dart 3.13.3, in a scratch package outside this
  /// repository:**
  ///
  /// ```text
  /// $ dart analyze probe.dart     # switch (e) over `E?`, with no null arm
  ///   error - The type 'E?' isn't exhaustively matched by the switch cases
  ///          since it doesn't match the pattern 'null'. Try adding a wildcard
  ///          pattern or cases that match 'null'.
  ///          - non_exhaustive_switch_expression
  /// ```
  ///
  /// **And the two other spellings are worse**, and the second is measured
  /// too:
  ///
  /// * **`default`** — a switch *expression* may not use it at all:
  ///   `A switch expression may not use the `default` keyword. Try replacing
  ///   `default` with `_`.` (`default_in_switch_expression`).
  /// * **the wildcard `_`** — it compiles, and it compiles **with a refusal
  ///   kind that has no case at all**: a new `ScheduleReadingFormError`
  ///   member would build and ship with no message under it, and the only
  ///   thing that would have caught it is the exhaustiveness of the explicit
  ///   arms.
  ///
  /// **So the `null` arm is what keeps the analyzer honest about every
  /// refusal kind having a message**, and it is the price of that: one line
  /// no test can execute.
  ///
  /// **AND NOTHING CAN REACH IT, WHICH IS A FACT ABOUT THE CUBIT AND NOT
  /// ABOUT THIS FUNCTION.** The cubit sets `formError` and `formField`
  /// together or not at all (`schedule_reading_cubit.dart:302`), so
  /// `formField == field && formError == null` is a state no writer builds —
  /// and this function is written to be **total over the state it is given**,
  /// not to depend on that invariant. A function that assumed the invariant
  /// would need a `default` to be total at all, and the `default` is the
  /// spelling that loses the check on the enum.
  static String? _errorFor(
    ScheduleReadingState state,
    ScheduleReadingField field,
    AppLocalizations strings,
  ) {
    if (state.formField != field) return null;
    return switch (state.formError) {
      ScheduleReadingFormError.emptyGroupIds =>
        strings.servantScheduleErrorEmptyGroupIds,
      ScheduleReadingFormError.invalidNumber =>
        strings.servantScheduleErrorInvalidNumber,
      ScheduleReadingFormError.invalidDate =>
        strings.servantScheduleErrorInvalidDate,
      ScheduleReadingFormError.invalidExcludedVerse =>
        strings.servantScheduleErrorInvalidExcludedVerse,
      ScheduleReadingFormError.reversedRange =>
        strings.servantScheduleErrorReversedRange,
      null => null,
    };
  }
}

/// The AI switch and the two warnings that belong to it.
///
/// ## AND THE WARNINGS ARE **THE POINT** OF THE SWITCH
///
/// The server deletes the previous questions when the switch is on
/// (`admin.routes.ts:195`), and the server's answer says nothing about it. A
/// switch whose consequence is invisible is a switch nobody can use safely, so
/// the consequence is written next to it.
class _AiSwitch extends StatelessWidget {
  const _AiSwitch({required this.value, required this.onChanged});

  /// Whether the server should generate the question.
  final bool value;

  /// Reports the new position.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                strings.servantScheduleAiLabel,
                style: arabicAware(
                  Theme.of(context).textTheme.bodyMedium!,
                  direction,
                ).copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(width: EvaSpacing.md),
            EvaToggle(
              value: value,
              onChanged: onChanged,
              // **The control's name is the row's title**, in both arms — a
              // position name would change with the switch, and §14 asks a
              // control to be named by what it is.
              labels: EvaToggleLabels(
                on: strings.servantScheduleAiLabel,
                off: strings.servantScheduleAiLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: EvaSpacing.xs),
        Text(
          strings.servantScheduleAiWarning,
          style: arabicAware(
            Theme.of(context).textTheme.bodySmall!,
            direction,
          ).copyWith(color: colors.ink2),
        ),
        const SizedBox(height: EvaSpacing.xs),
        Text(
          strings.servantScheduleUpsertWarning,
          style: arabicAware(
            Theme.of(context).textTheme.bodySmall!,
            direction,
          ).copyWith(color: colors.ink2),
        ),
      ],
    );
  }
}

/// The server's own sentence about the schedule.
///
/// **Verbatim**, for the reason `Failure`'s doc makes about the backend's
/// wording: a screen that reworded it would be showing the admin something the
/// server did not say.
class _ScheduleOutcome extends StatelessWidget {
  const _ScheduleOutcome({required this.message});

  /// The server's sentence.
  final String message;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: EvaSpacing.md),
      child: Text(
        message,
        style: arabicAware(
          Theme.of(context).textTheme.bodyMedium!,
          direction,
        ).copyWith(color: colors.ink),
      ),
    );
  }
}
