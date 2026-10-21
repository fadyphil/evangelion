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
      child: const _ScheduleBody(),
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
class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody();

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScheduleReadingCubit cubit = context.read<ScheduleReadingCubit>();

    for (final VoidCallback listener in _listeners) {
      for (final TextEditingController controller in _controllers) {
        controller.removeListener(listener);
      }
    }
    _listeners
      ..clear()
      ..add(() => cubit.setGroupIds(_groupIds.text))
      ..add(() => cubit.setScheduledDate(_date.text))
      ..add(() => cubit.setBookNumber(_book.text))
      ..add(() => cubit.setStartChapter(_startChapter.text))
      ..add(() => cubit.setStartVerse(_startVerse.text))
      ..add(() => cubit.setEndChapter(_endChapter.text))
      ..add(() => cubit.setEndVerse(_endVerse.text))
      ..add(() => cubit.setExcludedVerses(_excluded.text));
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

    return BlocBuilder<ScheduleReadingCubit, ScheduleReadingState>(
      builder: (BuildContext context, ScheduleReadingState state) {
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
                    errorText: _errorFor(
                      state,
                      ScheduleReadingField.date,
                      strings,
                    ),
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
                  retryFamily: arabicAwareFamily(
                    direction,
                    EvaTypography.uiFamily,
                  ),
                ),
            ],
          ),
        );
      },
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
