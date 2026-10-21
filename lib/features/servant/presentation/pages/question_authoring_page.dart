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
@RoutePage()
class QuestionAuthoringPage extends StatelessWidget {
  /// The question editor.
  const QuestionAuthoringPage({super.key, this.cubit, this.readingId});

  /// The cubit to render, or `null` to resolve the app's own.
  final QuestionAuthoringCubit? cubit;

  /// The reading the question belongs to, when the route carried one.
  final String? readingId;

  @override
  Widget build(BuildContext context) {
    final QuestionAuthoringCubit? passed = cubit;
    final QuestionAuthoringCubit resolved =
        passed ?? getIt<QuestionAuthoringCubit>();
    return BlocProvider<QuestionAuthoringCubit>.value(
      value: resolved,
      // **The builder is ABOVE the editor**, and that is the whole of the
      // sync mechanism: the editor is a `StatefulWidget` that owns the
      // controllers, and it can only learn that the question on screen changed
      // if its own widget is rebuilt with the new state — which is what
      // `didUpdateWidget` is for. A builder inside the editor would rebuild the
      // editor's own subtree and never the editor, and the fields would never
      // fill.
      child: BlocBuilder<QuestionAuthoringCubit, QuestionAuthoringState>(
        builder: (BuildContext context, QuestionAuthoringState state) =>
            _Editor(state: state, readingId: readingId),
      ),
    );
  }
}

/// The editor itself.
///
/// ## AND THE **CONTROLLERS** ARE THE PAGE'S
///
/// `EvaTextField`'s contract is that the controller is the caller's, and this
/// widget is the caller. The cubit holds the **value** — the question — and the
/// controller holds the text the admin is typing; the two agree because the
/// page reports every keystroke and writes into a controller **only** when the
/// question on screen says something different.
class _Editor extends StatefulWidget {
  const _Editor({required this.state, this.readingId});

  /// The question on screen.
  final QuestionAuthoringState state;

  /// The reading the route carried, if any.
  final String? readingId;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final TextEditingController _readingId = TextEditingController();
  final TextEditingController _promptAr = TextEditingController();
  final TextEditingController _promptEn = TextEditingController();
  final TextEditingController _correctAnswer = TextEditingController();
  final TextEditingController _points = TextEditingController();
  final TextEditingController _sortOrder = TextEditingController();

  /// The listeners added to the six controllers, so [dispose] can remove
  /// exactly those and not whatever is there.
  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Whether the form has been reported to the cubit yet.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _readingId.text = widget.readingId ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final QuestionAuthoringCubit cubit = context.read<QuestionAuthoringCubit>();

    for (final VoidCallback listener in _listeners) {
      for (final TextEditingController controller in _controllers) {
        controller.removeListener(listener);
      }
    }
    _listeners
      ..clear()
      ..add(() => cubit.setReadingId(_readingId.text))
      ..add(() => cubit.setPromptAr(_promptAr.text))
      ..add(() => cubit.setPromptEn(_promptEn.text))
      ..add(() => cubit.setCorrectAnswer(_correctAnswer.text))
      ..add(() => cubit.setPointsText(_points.text))
      ..add(() => cubit.setSortOrderText(_sortOrder.text));
    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].addListener(_listeners[i]);
    }

    if (!_seeded) {
      _seeded = true;
      cubit
        ..setReadingId(_readingId.text)
        ..setPromptAr(_promptAr.text)
        ..setPromptEn(_promptEn.text)
        ..setCorrectAnswer(_correctAnswer.text);
    }
  }

  /// The six controllers, in the order the listeners were added.
  List<TextEditingController> get _controllers => <TextEditingController>[
    _readingId,
    _promptAr,
    _promptEn,
    _correctAnswer,
    _points,
    _sortOrder,
  ];

  @override
  void didUpdateWidget(_Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **The one-sided sync.** A controller is written only when the question
    // on screen says something different, so a rebuild never moves the caret
    // and the server's draft fills the fields without fighting the admin.
    final QuestionAuthoringState state = widget.state;
    _sync(_readingId, state.readingId);
    _sync(_promptAr, state.draft?.promptAr ?? '');
    _sync(_promptEn, state.draft?.promptEn ?? '');
    _sync(_correctAnswer, state.draft?.correctAnswer ?? '');
    _sync(_points, state.pointsText);
    _sync(_sortOrder, state.sortOrderText);
  }

  /// Writes [value] into [controller] when they differ.
  static void _sync(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.text = value;
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

    {
      {
        final QuestionAuthoringState state = widget.state;
        final QuestionAuthoringCubit cubit = context
            .read<QuestionAuthoringCubit>();
        final bool busy = state.status == QuestionAuthoringStatus.working;
        final QuestionDraft? draft = state.draft;

        return NeuralScaffold(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SettingsGroup(
                label: strings.servantQuestionsTitle,
                children: <Widget>[
                  EvaTextField(
                    label: strings.servantQuestionsReadingIdLabel,
                    controller: _readingId,
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
                    selected: draft?.type ?? QuestionType.mcq,
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
                  EvaTextField(
                    label: strings.servantQuestionsPromptArLabel,
                    controller: _promptAr,
                  ),
                  EvaTextField(
                    label: strings.servantQuestionsPromptEnLabel,
                    controller: _promptEn,
                  ),
                  for (final MapEntry<String, QuestionOption> option
                      in (draft?.options ?? const <String, QuestionOption>{})
                          .entries)
                    QuestionOptionEditor(
                      key: ValueKey<String>(option.key),
                      letter: option.key,
                      arabicText: option.value.ar,
                      englishText: option.value.en,
                      onChanged:
                          ({required bool arabic, required String text}) =>
                              cubit.setOptionText(
                                option.key,
                                arabic: arabic,
                                text: text,
                              ),
                      onRemove: () => cubit.removeOption(option.key),
                    ),
                  if (draft == null || draft.type != QuestionType.shortAnswer)
                    EvaButton(
                      label: strings.servantQuestionsAddOption,
                      variant: EvaButtonVariant.ghost,
                      onPressed: () => _addOption(cubit, draft),
                      labelFamily: arabicAwareFamily(
                        direction,
                        EvaTypography.uiFamily,
                      ),
                    ),
                  if (draft == null || draft.type == QuestionType.shortAnswer)
                    Text(
                      strings.servantQuestionsEmptyOptions,
                      style: arabicAware(
                        Theme.of(context).textTheme.bodySmall!,
                        direction,
                      ).copyWith(color: context.colors.ink2),
                    ),
                  EvaTextField(
                    label: strings.servantQuestionsCorrectAnswerLabel,
                    controller: _correctAnswer,
                  ),
                  EvaTextField(
                    label: strings.servantQuestionsPointsLabel,
                    controller: _points,
                    keyboardType: TextInputType.number,
                  ),
                  EvaTextField(
                    label: strings.servantQuestionsOrderLabel,
                    controller: _sortOrder,
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
                  retryFamily: arabicAwareFamily(
                    direction,
                    EvaTypography.uiFamily,
                  ),
                ),
            ],
          ),
        );
      }
    }
  }

  /// Adds one option, under the first letter that is free.
  ///
  /// **The letter is chosen here** because the page owns the option's editor
  /// and its two controllers, and the first free letter is a fact about the
  /// editor rather than about the question. The cubit refuses a letter that is
  /// already in use, so a second tap cannot overwrite an option.
  void _addOption(QuestionAuthoringCubit cubit, QuestionDraft? draft) {
    final Set<String> used = draft?.options.keys.toSet() ?? const <String>{};
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
