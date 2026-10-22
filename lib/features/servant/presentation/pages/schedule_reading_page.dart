import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:evangelion/features/servant/presentation/widgets/servant_app_bar.dart';
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
      // sync mechanism: the form is a widget that reads the passage out of
      // the state, and the eight fields are **controlled** — their value is
      // the state's value, and a write the field makes on purpose is never
      // reported as the reader's.
      child: BlocBuilder<ScheduleReadingCubit, ScheduleReadingState>(
        builder: (BuildContext context, ScheduleReadingState state) =>
            _ScheduleBody(state: state),
      ),
    );
  }
}

/// The form.
///
/// ## AND EVERY FIELD IS A **CONTROLLED FIELD**, AND THE CUBIT PARSES THE TEXT
///
/// The **value** is the cubit's — the form's text — and the page reports every
/// keystroke. The parse happens once, on submit, and it is the parse that
/// refuses.
///
/// ## AND THE FORM IS **READ BACK** INTO THE FIELDS
///
/// The cubit holds the form's text and the page reports every keystroke, so
/// the two are one form in two shapes — and the shape the admin **reads** is
/// the field's. A form that showed nothing on a re-entry would show an empty
/// passage while the state held the whole one, and the **server's insert is
/// `ON CONFLICT (group_id, scheduled_date) DO UPDATE`** (`admin.routes.ts:157`),
/// so that **replaces the cohort's passage**.
///
/// **THE CUBIT IS A SINGLETON**, and the registration in
/// `navigation_injection.dart` says the form the admin is halfway through
/// filling is one of the three reasons it is one — so the passage has to
/// survive the route being popped and pushed again. It does: the fields read
/// the state, and the state is the only place the form lives.
///
/// ## AND EVERY FIELD'S DIRECTION IS DECIDED THE **SAME** WAY
///
/// The state decides, per field, and the comparison is the field's own — the
/// controlled field writes the state's value into its own controller **only
/// when the two differ**, so there is no whole-form copy that could carry a
/// stale field over a fresh one.
///
/// **AND THAT CANNOT CLOBBER THE ADMIN'S OWN EDIT.** The state holds the
/// admin's **last keystroke** for every field — the page reports each one
/// synchronously, and the report is the cubit's own `copyWith` of that one
/// field — so a field the admin is typing in already agrees with the state,
/// and the controlled field finds nothing to write. The write happens only
/// where the two **disagree**, and the two can only disagree about a field the
/// admin has not touched since the state last changed.
///
/// ## AND THE **NINTH CONTROL** HAS NO FIELD AT ALL. The AI switch is read
/// straight off the state, so its direction is **state → screen** with no
/// reverse report — the only control on this form that is not a text field,
/// and the only one whose direction is one-way by construction.
class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({required this.state});

  /// The form as the state holds it.
  final ScheduleReadingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);
    // **THE STATE THE PAGE WAS BUILT WITH.** The builder that watches the
    // cubit is **above** this widget, so the state arrives as a widget
    // parameter — and the form reads the passage out of it.
    final ScheduleReadingState form = state;
    final bool busy = form.status == ScheduleReadingStatus.submitting;
    // **THE CUBIT, ONCE.** The eight fields report the reader's input to it,
    // and a lookup per field would be eight lookups for one object.
    final ScheduleReadingCubit cubit = context.read<ScheduleReadingCubit>();
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
      // See `ServantAppBar`'s doc for the reason — and this form is the case
      // it was written for: **eight fields** is four screens of scrolling at
      // 320×568, and on the Linux desktop build the back control is the only
      // way out.
      overlay: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ServantAppBar(title: strings.servantScheduleTitle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            label: strings.servantCohortAndDayLabel,
            children: <Widget>[
              EvaControlledField(
                label: strings.servantScheduleGroupIdsLabel,
                hintText: strings.servantScheduleGroupIdsHint,
                value: form.form.groupIdsText,
                onChanged: cubit.setGroupIds,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.groupIds,
                  strings,
                ),
              ),
              EvaControlledField(
                label: strings.servantScheduleDateLabel,
                hintText: strings.servantScheduleDateHint,
                value: form.form.scheduledDateText,
                onChanged: cubit.setScheduledDate,
                errorText: _errorFor(form, ScheduleReadingField.date, strings),
              ),
            ],
          ),
          // **THE PASSAGE IS ITS OWN GROUP**, and it is six fields wide.
          // They are the fields that name **which words** the cohort reads,
          // and the group label says so in one line instead of leaving a
          // reader to work it out from six field labels.
          SettingsGroup(
            label: strings.servantPassageLabel,
            children: <Widget>[
              EvaControlledField(
                label: strings.servantScheduleBookLabel,
                value: form.form.bookNumberText,
                onChanged: cubit.setBookNumber,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.bookNumber,
                  strings,
                ),
              ),
              EvaControlledField(
                label: strings.servantScheduleStartChapterLabel,
                value: form.form.startChapterText,
                onChanged: cubit.setStartChapter,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.startChapter,
                  strings,
                ),
              ),
              EvaControlledField(
                label: strings.servantScheduleStartVerseLabel,
                value: form.form.startVerseText,
                onChanged: cubit.setStartVerse,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.startVerse,
                  strings,
                ),
              ),
              EvaControlledField(
                label: strings.servantScheduleEndChapterLabel,
                value: form.form.endChapterText,
                onChanged: cubit.setEndChapter,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.endChapter,
                  strings,
                ),
              ),
              EvaControlledField(
                label: strings.servantScheduleEndVerseLabel,
                value: form.form.endVerseText,
                onChanged: cubit.setEndVerse,
                keyboardType: TextInputType.number,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.endVerse,
                  strings,
                ),
              ),
              EvaControlledField(
                label: strings.servantScheduleExcludedLabel,
                hintText: strings.servantScheduleExcludedHint,
                value: form.form.excludedVersesText,
                onChanged: cubit.setExcludedVerses,
                errorText: _errorFor(
                  form,
                  ScheduleReadingField.excludedVerses,
                  strings,
                ),
              ),
            ],
          ),
          // **THE QUESTION IS ITS OWN GROUP**, and it holds the switch and
          // nothing else. The switch is about the question the server will
          // attach to the reading — and the two warnings under it are the
          // server's own behaviours, which the form has to state.
          SettingsGroup(
            label: strings.servantQuestionLabel,
            children: <Widget>[
              _AiSwitch(
                value: form.form.generateAiQuestions,
                onChanged: (bool generate) =>
                    cubit.setGenerateAiQuestions(generate: generate),
              ),
            ],
          ),
          // **THE ACTION IS **OUTSIDE** EVERY GROUP.** The button is the
          // form's, and a primary action nested inside a labelled group reads
          // as one more thing that group is for.
          const SizedBox(height: EvaSpacing.lg),
          EvaButton(
            label: strings.servantScheduleSubmit,
            onPressed: busy ? null : cubit.submit,
            labelFamily: arabicAwareFamily(direction, EvaTypography.uiFamily),
          ),
          if (form.result case final ScheduleResult result)
            _ScheduleOutcome(message: result.message),
          if (form.failure case final Failure failure)
            ErrorView(
              message: failure.message,
              onRetry: cubit.retry,
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
