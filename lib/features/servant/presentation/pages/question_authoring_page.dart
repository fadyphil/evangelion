import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/presentation/cubit/question_authoring_cubit.dart';
import 'package:evangelion/features/servant/presentation/widgets/question_option_editor.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The question editor: write a question, or draft one and edit it.
///
/// ## AND IT TAKES ITS **CUBIT** AS A PARAMETER
///
/// `null` means "resolve the app's own from the locator", and the cubit is
/// hand-registered in `lib/app/di/navigation_injection.dart` because
/// `flutter_bloc` re-exports the widget layer. `CommunionPage` is the same
/// shape and the same reason.
///
/// ## AND THE READING ID IS **A ROUTE PARAMETER** *AND* A FIELD
///
/// [readingId] is what the route carries — the id the schedule answered with.
/// And the field is there because **the backend has no endpoint that lists a
/// cohort's scheduled readings** (the design spec §6.2), so a reading scheduled
/// in an earlier session can only be reached by an id somebody kept. The
/// screen says so in a note rather than pretending a lookup exists.
///
/// ## AND IT IS **STATEFUL**, AND THE ONE THING ITS STATE DOES IS **GIVE THE
/// ROUTE'S READING ID TO THE CUBIT, ONCE**
///
/// The page used to be a `StatelessWidget` and the seed lived in the editor's
/// `didChangeDependencies` — and that is a **frame too late** for a controlled
/// field, because the field's value is the **state's** value: a seed that lands
/// after the first build puts the route's id on the screen one frame later, and
/// the screen and the state disagree for that frame.
///
/// So the seed is in the page's `initState`, which runs **before** the
/// `BlocBuilder` reads the cubit — and the route's id is on the screen from
/// the **first frame**, which is what the route owning it means.
@RoutePage()
class QuestionAuthoringPage extends StatefulWidget {
  /// The question editor.
  const QuestionAuthoringPage({super.key, this.cubit, this.readingId});

  /// The cubit to render, or `null` to resolve the app's own.
  final QuestionAuthoringCubit? cubit;

  /// The reading the question belongs to, when the route carried one.
  final String? readingId;

  @override
  State<QuestionAuthoringPage> createState() => _QuestionAuthoringPageState();
}

class _QuestionAuthoringPageState extends State<QuestionAuthoringPage> {
  @override
  void initState() {
    super.initState();
    // **THE ROUTE'S READING ID, AND NOTHING ELSE.**
    //
    // **ONCE, AND ONLY ONCE.** The route names the reading the editor is
    // opened for, and the admin may type another one into the field — so
    // applying the route's id again after a dependency change would undo the
    // admin's own correction. `initState` runs once per mount, so the rule is
    // the rule and the flag is not needed.
    //
    // **AND ONLY WHEN THE ROUTE CARRIES ONE.** The hub opens the editor with
    // no reading id at all (`ServantHubEntry.questions` pushes a path), and the
    // id in the field is the **admin's own** — so a route with no id must not
    // wipe it, and a state that already holds one keeps it.
    //
    // **AND THE PAGE REPORTS **NOTHING** ELSE.** The seed used to report the
    // six controllers' contents, and the controllers start empty — so the
    // seed told the cubit "the reader cleared the question", and an admin who
    // left `/servant/questions` and came back found their edits gone. That is
    // the **one thing the cubit's singleton exists to prevent**
    // (`navigation_injection.dart` says so), and the seed defeated it. The
    // five other fields are the **state's** to show, and the state is the only
    // place they live.
    final String routeId = widget.readingId ?? '';
    if (routeId.isEmpty) return;
    final QuestionAuthoringCubit cubit =
        widget.cubit ?? getIt<QuestionAuthoringCubit>();
    cubit.setReadingId(routeId);
  }

  @override
  Widget build(BuildContext context) {
    final QuestionAuthoringCubit? passed = widget.cubit;
    final QuestionAuthoringCubit resolved =
        passed ?? getIt<QuestionAuthoringCubit>();
    return BlocProvider<QuestionAuthoringCubit>.value(
      value: resolved,
      // **THE BUILDER IS **ABOVE** THE EDITOR**, and that is the whole of the
      // sync mechanism: the editor is a widget that reads the question out of
      // the state, and the fields are **controlled** — their value is the
      // state's value, and a write the field makes on purpose is never
      // reported as the reader's.
      child: BlocBuilder<QuestionAuthoringCubit, QuestionAuthoringState>(
        builder: (BuildContext context, QuestionAuthoringState state) =>
            _Editor(state: state),
      ),
    );
  }
}

/// The editor itself.
///
/// ## AND EVERY FIELD IS A **CONTROLLED FIELD**
///
/// The question on screen is the **state's**, and the six fields are
/// `EvaControlledField`s: each one takes the state's value and reports **only
/// the reader's input**.
///
/// **THE PAGE OWNS NO CONTROLLER, AND THAT IS THE POINT.** The hand-rolled
/// mirror had **three** ways to be wrong — the write is reported, the field is
/// seeded instead of read back, the mirror runs in the wrong direction — and
/// **no way to be caught**. `EvaControlledField` is that pattern made
/// expressible, and `test/core/design_system/widgets/mirrored_controller_check_test.dart`
/// is what keeps the hand-rolled version out.
///
/// ## AND THE **READER'S** INPUT IS **THE ONLY** THING THE CUBIT IS TOLD
///
/// The old page wrote the state's own `pointsText` into a controller that had
/// started **empty**, the controller notified, and the cubit was told the
/// **reader** had edited the question — and the cubit's edit writer then
/// dropped the **server's refusal** with it, so **a server's refusal erased
/// itself in one frame**. The controlled field compares instead of being
/// guarded by a flag, so there is no window in which a write the program made
/// can arrive as the reader's.
class _Editor extends StatelessWidget {
  const _Editor({required this.state});

  /// The question on screen.
  final QuestionAuthoringState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);
    final QuestionAuthoringCubit cubit = context.read<QuestionAuthoringCubit>();
    final bool busy = state.status == QuestionAuthoringStatus.working;
    final QuestionDraft? draft = state.draft;
    // **THE TYPE, AND NOT THE DRAFT'S NULLNESS.** A draft that does not
    // exist yet is a question of the type the editor offers — an
    // **MCQ** — and the two sentences below are about the *type*: a
    // short-answer question has no options, and every other kind has
    // some to add. So the sentence is read off the type, and a screen
    // that read it off the draft's nullness would say "a short-answer
    // question has no options" under a question that is not one.
    final QuestionType questionType = draft?.type ?? QuestionType.mcq;
    // **THE OPTIONS, ONCE.** The empty editor has no draft at all — "the
    // first thing the admin writes creates the draft" is the cubit's own
    // doc — and the options are read in two places: the editors the
    // screen draws, and the letters the "add an option" button must not
    // reuse.
    final Map<String, QuestionOption> options =
        draft?.options ?? const <String, QuestionOption>{};

    return NeuralScaffold(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            label: strings.servantQuestionsTitle,
            children: <Widget>[
              EvaControlledField(
                label: strings.servantQuestionsReadingIdLabel,
                // **THE STATE'S READING ID, AND THE ROUTE'S IS IN IT.** The
                // route's id was given to the cubit at mount — see
                // [QuestionAuthoringPage]'s own doc — so the field shows the
                // route's id from the first frame, and the admin's own
                // correction replaces it the moment they type.
                value: state.readingId,
                onChanged: cubit.setReadingId,
              ),
              Text(
                strings.servantQuestionsReadingIdNote,
                style: arabicAware(
                  Theme.of(context).textTheme.bodySmall!,
                  direction,
                ).copyWith(color: context.colors.ink2),
              ),
              SegmentedControl<QuestionType>(
                values: QuestionType.values,
                selected: questionType,
                labelOf: (QuestionType type) => switch (type) {
                  QuestionType.mcq => strings.servantQuestionsTypeMcq,
                  QuestionType.trueFalse =>
                    strings.servantQuestionsTypeTrueFalse,
                  QuestionType.shortAnswer =>
                    strings.servantQuestionsTypeShortAnswer,
                },
                labelFamilyOf: (QuestionType type) =>
                    arabicAwareFamily(direction, EvaTypography.uiFamily),
                semanticLabel: strings.servantQuestionsTypeLabel,
                onChanged: cubit.setType,
                wide: true,
              ),
              EvaControlledField(
                label: strings.servantQuestionsPromptArLabel,
                value: draft?.promptAr ?? '',
                onChanged: cubit.setPromptAr,
              ),
              EvaControlledField(
                label: strings.servantQuestionsPromptEnLabel,
                value: draft?.promptEn ?? '',
                onChanged: cubit.setPromptEn,
              ),
              for (final MapEntry<String, QuestionOption> option
                  in options.entries)
                QuestionOptionEditor(
                  key: ValueKey<String>(option.key),
                  letter: option.key,
                  arabicText: option.value.ar,
                  englishText: option.value.en,
                  onChanged: ({required bool arabic, required String text}) =>
                      cubit.setOptionText(
                        option.key,
                        arabic: arabic,
                        text: text,
                      ),
                  onRemove: () => cubit.removeOption(option.key),
                ),
              if (questionType != QuestionType.shortAnswer)
                EvaButton(
                  label: strings.servantQuestionsAddOption,
                  variant: EvaButtonVariant.ghost,
                  onPressed: () => _addOption(cubit, options),
                  labelFamily: arabicAwareFamily(
                    direction,
                    EvaTypography.uiFamily,
                  ),
                ),
              if (questionType == QuestionType.shortAnswer)
                Text(
                  strings.servantQuestionsEmptyOptions,
                  style: arabicAware(
                    Theme.of(context).textTheme.bodySmall!,
                    direction,
                  ).copyWith(color: context.colors.ink2),
                ),
              EvaControlledField(
                label: strings.servantQuestionsCorrectAnswerLabel,
                value: draft?.correctAnswer ?? '',
                onChanged: cubit.setCorrectAnswer,
              ),
              EvaControlledField(
                label: strings.servantQuestionsPointsLabel,
                value: state.pointsText,
                onChanged: cubit.setPointsText,
                keyboardType: TextInputType.number,
              ),
              EvaControlledField(
                label: strings.servantQuestionsOrderLabel,
                value: state.sortOrderText,
                onChanged: cubit.setSortOrderText,
                keyboardType: TextInputType.number,
              ),
              EvaButton(
                label: strings.servantQuestionsDraftButton,
                variant: EvaButtonVariant.secondary,
                onPressed: busy ? null : cubit.requestDraft,
                labelFamily: arabicAwareFamily(
                  direction,
                  EvaTypography.uiFamily,
                ),
              ),
              EvaButton(
                label: strings.servantQuestionsCommitButton,
                onPressed: busy ? null : cubit.commit,
                labelFamily: arabicAwareFamily(
                  direction,
                  EvaTypography.uiFamily,
                ),
              ),
            ],
          ),
          if (state.formError case final QuestionAuthoringFormError error)
            _FormError(error: error),
          if (state.commitResult case final CommitResult result)
            _Outcome(message: result.message),
          if (state.failure case final Failure failure)
            ErrorView(
              message: failure.message,
              onRetry: cubit.retry,
              retryLabel: strings.servantQuestionsRetry,
              retryFamily: arabicAwareFamily(direction, EvaTypography.uiFamily),
            ),
        ],
      ),
    );
  }

  /// Adds one option, under the first letter that is free.
  ///
  /// **The letter is chosen here** because the page owns the option's editor
  /// and its first free letter is a fact about the editor rather than about
  /// the question. The cubit refuses a letter that is already in use, so a
  /// second tap cannot overwrite an option.
  ///
  /// **AND THE OPTIONS COME IN, NOT THE DRAFT.** The empty editor has no
  /// draft at all — "the first thing the admin writes creates the draft" is
  /// the cubit's own doc — so the caller passes the options it has, and an
  /// editor with none passes none.
  void _addOption(
    QuestionAuthoringCubit cubit,
    Map<String, QuestionOption> options,
  ) {
    final Set<String> used = options.keys.toSet();
    for (final String letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      if (used.contains(letter)) continue;
      cubit.addOption(letter);
      return;
    }
  }
}

/// The form's refusal, in the reader's own language.
class _FormError extends StatelessWidget {
  const _FormError({required this.error});

  /// Why the form refused.
  final QuestionAuthoringFormError error;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final String message = switch (error) {
      QuestionAuthoringFormError.missingReadingId =>
        strings.servantQuestionsErrorMissingReadingId,
      QuestionAuthoringFormError.emptyPrompt =>
        strings.servantQuestionsErrorEmptyPrompt,
      QuestionAuthoringFormError.emptyCorrectAnswer =>
        strings.servantQuestionsErrorEmptyCorrectAnswer,
      QuestionAuthoringFormError.invalidNumber =>
        strings.servantQuestionsErrorInvalidNumber,
      QuestionAuthoringFormError.draftForAnotherReading =>
        strings.servantQuestionsErrorDraftForAnotherReading,
    };
    return Padding(
      padding: const EdgeInsets.only(top: EvaSpacing.md),
      child: Text(
        message,
        style: arabicAware(
          Theme.of(context).textTheme.bodyMedium!,
          direction,
        ).copyWith(color: colors.errInk),
      ),
    );
  }
}

/// The server's own sentence about the commit.
///
/// **Verbatim**, for the reason `Failure`'s doc makes about the backend's
/// wording: a screen that reworded it would be showing the admin something the
/// server did not say.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.message});

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
