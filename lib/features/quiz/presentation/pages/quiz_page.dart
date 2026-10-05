import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.gr.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/feedback_banner.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/quiz` — the question flow. `QuizScreen.tsx:40-130`, minus the prototype's
/// two-state preview toggle (see below).
///
/// ## DEFECT #12: THE ANSWERING/FEEDBACK TOGGLE IS **NOT** HERE, AND IT IS NOT
/// ## MISSING
///
/// **The toggle is referred to by description throughout, never by its prototype
/// label.** Those labels are two strings that appear nowhere in `lib/` and this doc
/// is one of the places that could have put them back. `quiz_page_test.dart`'s
/// source sweep is the gate, and it is a **raw** `lib/` grep rather than one that
/// strips doc comments: a comment is still a place the next reader copies from, and
/// a sweep that had to be sophisticated enough to forgive comments would forgive a
/// comment that quotes the very string it exists to keep out.
///
/// `01-source-analysis.md:81`, on `App.tsx`'s screen switcher and `QuizScreen`'s two
/// preview buttons — the *Answering* one and the *Feedback* one:
///
/// > *"exist only to let the Figma agent preview states … Must not be ported."*
///
/// `QuizScreen.tsx:56-63` is the whole of it, and it is worth being precise about
/// what it is: two `EvaChip`-shaped buttons whose only behaviour is
/// `setSelected(null); setChecked(false)` and `setSelected('B'); setChecked(true)`.
/// **The second one sets the correct answer to `B` and marks it correct without
/// asking the server.** Porting it would put a control on the quiz that grades a
/// question this client has not submitted — which is `is_correct` on the wire with
/// no request behind it, the exact spoiler `AGENT_CONTEXT`'s phase-8 requirement is
/// about, and the reason the exclusion is a design rule rather than a simplification.
///
/// `test/features/quiz/presentation/pages/quiz_page_test.dart` asserts no Frame
/// string reaches the rendered tree, and this phase's grep sweep
/// (`rg -n "Frame [AB]" lib/`) is the check on the source.
///
/// ## THE SPOILER BOUNDARY, AND WHERE IT LIVES
///
/// **This file.** `Question` carries `user_answer` and `is_correct` because the
/// server ships them with the reading (verified live at `HEAD = 4a1c834`), and
/// `reading_page.dart` already refuses to render either. The quiz **may** render
/// `is_correct` — but only after the reader has chosen and checked, because before
/// that the reader has not committed to an answer and telling them is the same leak
/// by another route.
///
/// The mechanism is deliberately small: [QuizPage._optionStateFor] is the **only**
/// function that can produce `QuizOptionState.correct` or `.incorrect`, it takes the
/// answer's `isChecked` as its gate, and it reads **only** `QuizAnswer.verdict` —
/// never `QuizAnswer.question.isCorrect`. The second half is the one a reader is
/// most likely to get wrong: `question.isCorrect` is right there on the entity, it
/// is `true` for the live already-answered question, and using it would produce a
/// correct-looking card that no request ever graded.
///
/// `quiz_page_test.dart` proves the boundary in **both** directions, on the widget
/// tree **and** on the semantics tree — Phase 7 caught a leak that painted nothing
/// and was still in the accessibility tree, so a visual assertion alone is not
/// evidence.
///
/// ## AND THE DEAD CTA IS **SHIPPED, NAMED, AND NOT PATCHED OVER**
///
/// `QuizState.cta` is `QuizCta.none` when there is nothing to submit and no
/// `SubmitResult` in hand — which is the **live payload's own shape**: group 3's
/// question arrives with `already_answered: true` (§5 trap 3), so a reader who has
/// already reflected today lands on a screen whose button cannot do anything.
///
/// The alternatives, all rejected:
///
/// * **navigate to `/result` anyway** — impossible, and not by policy:
///   `ResultPage`'s `SubmitResult` is **required**, so the route cannot even be
///   pushed. A `null` result and an `EmptyState` would be a second kind of result
///   screen for a case where the reader submitted nothing;
/// * **hide the button** — §14's disabled row exists precisely so a control is
///   *absent* rather than missing, and a button that vanishes on one reader's screen
///   and stays on another's is a layout a reader cannot predict;
/// * **submit the already-answered question again** — that is the 409.
///
/// So the button ships inert, labelled `AppLocalizations.quizUnavailableSuffix` — **on the
/// caption as well as in the accessible name**, since decision 91 found that the
/// sighted reader on this screen has no second channel. That is the shape
/// `LoginPage`'s four social buttons and `AppTopBar`'s avatar already use (recorded
/// decisions 18 and 32), and the X control is the way out. **This is visible product
/// debt** and it is one argument at one call site: give the endpoint a "today's
/// result" read and the button has something to open.
@RoutePage()
class QuizPage extends StatelessWidget {
  /// The quiz.
  const QuizPage({super.key, this.bloc});

  /// The bloc to render.
  ///
  /// `null` resolves [QuizBloc] from the locator, which is the production path; the
  /// parameter is `HomePage.bloc`'s and `ReadingPage.bloc`'s arrangement for the same
  /// reason — a widget test cannot configure the whole graph.
  ///
  /// **Substitution, not initialisation.** [_QuizBody] dispatches `QuizStarted`
  /// unconditionally; see its doc.
  final QuizBloc? bloc;

  /// The root padding. `QuizScreen.tsx:41` — `padding: '20px 20px 28px'`.
  static const EdgeInsets rootPadding = EdgeInsets.fromLTRB(
    EvaSpacing.xl,
    EvaSpacing.xl,
    EvaSpacing.xl,
    EvaSpacing.xxl,
  );

  /// The question label's size. `QuizScreen.tsx:66` — `fontSize: 10`.
  static const double questionLabelFontSize = 10;

  /// `QuizScreen.tsx:66` — `letterSpacing: '0.14em'`.
  ///
  /// **Resolved against the label's own 10px**, for `StickyCta`'s recorded reason:
  /// CSS `em` tracking is relative to the element's font size, so this is `1.4`
  /// logical px and **not** `0.14`. `reading_geometry_test.dart` pins the same
  /// arithmetic on the two reading screens.
  static const double questionLabelLetterSpacing = 0.14 * questionLabelFontSize;

  /// `QuizScreen.tsx:66` — `marginBottom: 12`.
  static const double questionGap = EvaSpacing.md;

  /// `QuizScreen.tsx:71` — `marginBottom: 30` under the question text.
  static const double optionsGap = 30;

  /// `QuizScreen.tsx:78` — `gap: 12` between option cards.
  static const double optionGap = EvaSpacing.md;

  /// `QuizScreen.tsx:105` — `marginTop: 14` above the banner.
  static const double bannerTopGap = FeedbackBanner.topGap;

  /// `QuizScreen.tsx:122` — `marginTop: 14` above the CTA.
  static const double ctaTopGap = EvaSpacing.md;

  /// The option cards' rendered width, for the flecks' offsets.
  ///
  /// **`QuizScreen.tsx` has no explicit card width** — `:77` is a `flex: 1` column
  /// and `:431` is `width: '100%'` — so the width is the scaffold's content width
  /// minus this screen's own `rootPadding`, and the answer belongs in one place
  /// rather than being guessed at the flecks' call site.
  static double cardWidthAt(BuildContext context) =>
      MediaQuery.sizeOf(context).width - rootPadding.horizontal;

  /// The question's [TextStyle] for the arm [language].
  ///
  /// **A per-arm function, not one shared number**, for `reading_geometry_test.dart`'s
  /// library doc: `ds.tsx` publishes one set of numbers and a screen that needs two
  /// arms gets two answers, each pinned against its own prototype line.
  static TextStyle questionStyleFor(
    BuildContext context,
    ReadingLanguage language,
  ) => Theme.of(context).textTheme.headlineMedium!.copyWith(
    // `QuizScreen.tsx:71` — `F.display, 26, 600, lineHeight 1.2`.
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.26,
    // The **scripture** face on the Latin arm and Amiri on the Arabic one: the
    // prompt is the server's text, in the server's language, so this is
    // decision 75's payload arm rather than `arabicAware`.
    fontFamily: switch (language) {
      ReadingLanguage.english => EvaTypography.scriptureFamily,
      ReadingLanguage.arabic => EvaTypography.arabicFamily,
    },
    color: context.colors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final QuizBloc? passed = bloc;
    final QuizBloc resolved = passed ?? getIt<QuizBloc>();

    return BlocProvider<QuizBloc>.value(
      value: resolved,
      child: _QuizBody(onExit: () => unawaited(context.router.maybePop())),
    );
  }
}

/// Everything below the provider. A [StatefulWidget] for one reason: the load must
/// fire **once**, on entry.
///
/// ## AND IT FIRES FROM `didChangeDependencies`, NOT `initState`
///
/// `ReadingPage`'s doc gives the whole argument and it applies verbatim:
/// `Localizations.localeOf` is an inherited-widget lookup and Flutter forbids those
/// in `initState`; and `didChangeDependencies` is also the phase that fires on a
/// **locale change**, which is the second trigger this screen has — Phase 9's
/// language switch is a locale change and `/quiz` must then show the *other* arm's
/// questions, not the same text under new chrome.
class _QuizBody extends StatefulWidget {
  const _QuizBody({required this.onExit});

  final VoidCallback onExit;

  @override
  State<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends State<_QuizBody> {
  /// The arm of the corpus this screen has asked for, or `null` before the first
  /// dispatch. A [ReadingLanguage] and not a `bool`, for `HomePage`'s reason.
  ReadingLanguage get _language =>
      ReadingLanguage.forLocale(Localizations.localeOf(context).languageCode);

  ReadingLanguage? _requested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested != _language) _load();
  }

  /// Dispatches `QuizStarted` for the language on screen.
  void _load() {
    final ReadingLanguage language = _language;
    _requested = language;
    context.read<QuizBloc>().add(QuizStarted(language));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return BlocBuilder<QuizBloc, QuizState>(
      builder: (BuildContext context, QuizState state) =>
          _body(context, strings: strings, state: state),
    );
  }

  /// The screen for [state]: the question, the options, the banner and the CTA.
  Widget _body(
    BuildContext context, {
    required AppLocalizations strings,
    required QuizState state,
  }) => switch (state.status) {
    QuizStatus.loading => const NeuralScaffold(
      variant: NeuralVariant.quiz,
      // `QuizScreen.tsx:76` gives the options `flex: 1` in a column, which is the
      // prototype's own scrollable and is why this screen is `scrollable: false`
      // for the same reason `/reading` is: the body owns its own.
      scrollable: false,
      padding: EdgeInsets.zero,
      child: SizedBox.shrink(),
    ),
    QuizStatus.failed => _FailedOrEmpty(
      strings: strings,
      // The failure's own **message**, for `ReadingPage`'s reason: the mapper
      // writes "Could not read today's reading: `verses` is absent …" and inventing a
      // sentence here would hide the field that is actually wrong.
      message: state.failure?.message ?? '',
      onRetry: () => context.read<QuizBloc>().add(QuizRetried(_language)),
    ),
    QuizStatus.ready ||
    QuizStatus.submitting ||
    QuizStatus.complete => _quiz(context, strings: strings, state: state),
  };

  /// The question flow. Nothing else is on this screen.
  Widget _quiz(
    BuildContext context, {
    required AppLocalizations strings,
    required QuizState state,
  }) {
    final QuizSession? session = state.session;
    if (session == null || state.isEmpty) {
      return _FailedOrEmpty(
        strings: strings,
        empty: true,
        onRetry: () => context.read<QuizBloc>().add(QuizRetried(_language)),
      );
    }

    final ReadingLanguage language = _language;
    final QuizAnswer? answer = state.currentAnswer;

    return NeuralScaffold(
      variant: NeuralVariant.quiz,
      scrollable: false,
      padding: QuizPage.rootPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          QuizHeader(
            total: session.questionCount,
            completed: session.answeredCount,
            current: state.currentIndex,
            language: language,
            strings: strings,
            onExit: widget.onExit,
          ),
          // `QuizScreen.tsx:66-72` — the question label and the question itself.
          // **Both are `shrinkWrap` scrolled**, because at 320×568 with 1.22× text
          // a five-verse day's fourth question plus its options does not fit, and
          // §13 rule 5 forbids a `Column` over unbounded content.
          Expanded(
            child: ListView(
              children: <Widget>[
                Text(
                  strings.questionProgress(
                    state.currentIndex + 1,
                    session.questionCount,
                  ),
                  textAlign: TextAlign.center,
                  // `QuizScreen.tsx:66` — `F.mono, 10, 700, 0.14em, ember`. The
                  // **payload** arm, for the same reason `QuizOptionCard` takes one:
                  // this is a sentence about the reader's corpus, and its digits are
                  // Arabic-Indic on the AR arm.
                  style: EvaTypography.monoCaps(context.colors).copyWith(
                    fontSize: QuizPage.questionLabelFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: QuizPage.questionLabelLetterSpacing,
                    fontFamily: switch (language) {
                      ReadingLanguage.english => EvaTypography.monoFamily,
                      ReadingLanguage.arabic => EvaTypography.arabicFamily,
                    },
                    color: context.colors.ember,
                  ),
                ),
                const SizedBox(height: QuizPage.questionGap),
                Text(
                  // **The prompt, and only the prompt.** The options carry the
                  // answers and the answer state is [answer]'s, which is null until
                  // the reader has committed.
                  answer?.question.prompt ?? '',
                  textAlign: TextAlign.center,
                  // `QuizScreen.tsx:71` — `F.display, 26, 600, lineHeight 1.2`.
                  style: QuizPage.questionStyleFor(context, language),
                ),
                const SizedBox(height: QuizPage.optionsGap),
                for (final MapEntry<String, String> option
                    in (answer?.question.options ?? const <String, String>{})
                        .entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: QuizPage.optionGap),
                    child: _optionCard(
                      context,
                      strings: strings,
                      answer: answer,
                      entry: option,
                      language: language,
                      state: state,
                    ),
                  ),
                if (answer != null && answer.isChecked)
                  Padding(
                    padding: const EdgeInsets.only(top: QuizPage.bannerTopGap),
                    child: FeedbackBanner(
                      tone: answer.isCorrect == true
                          ? FeedbackTone.ok
                          : FeedbackTone.err,
                      message: answer.isCorrect == true
                          ? strings.quizVerdictCorrect
                          : strings.quizVerdictIncorrect,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: QuizPage.ctaTopGap),
          _Cta(
            strings: strings,
            language: language,
            cta: state.cta,
            // **`checked`, not `cta`.** The prototype's label and its disabled flag
            // are **two different questions** — `QuizScreen.tsx:124-127` is
            // `disabled={!checked && !selected}` with
            // `{checked ? 'Next question' : 'Check answer'}` — and the first version
            // of this widget drove the label off `cta`, so a reader with nothing
            // chosen was told "**Try again**", a sentence this client invented for a
            // different state. `quiz_page_test.dart` is what caught it, by looking
            // for `Check answer` before a selection.
            // **The status and not `lastQuestion`**, because `complete` is its own
            // CTA arm — see [label]. The last graded question says `nextQuestion`,
            // exactly as the prototype does, and the press is what reaches `complete`.
            status: state.status,
            graded: state.currentAnswer?.isChecked ?? false,
            finished: state.isSessionFinished,
            onPressed: () => _onCtaPressed(context, state),
          ),
        ],
      ),
    );
  }

  /// One option card, and the **only** place a verdict becomes a visual state.
  ///
  /// ## THIS IS THE SPOILER BOUNDARY, IN ONE FUNCTION
  ///
  /// It reads [QuizAnswer.verdict] — the submit response — and never
  /// `QuizAnswer.question.isCorrect`, which the wire also carries and which is
  /// `true` on an already-answered question. It is gated on `isChecked`, so a
  /// question the reader has not checked cannot be `correct` no matter what the
  /// payload says.
  Widget _optionCard(
    BuildContext context, {
    required AppLocalizations strings,
    required QuizAnswer? answer,
    required MapEntry<String, String> entry,
    required ReadingLanguage language,
    required QuizState state,
  }) {
    final String letter = entry.key;
    final QuizOptionState optionState = _optionStateFor(answer, letter);
    final bool open = answer?.isOpen ?? false;

    return Stack(
      // `QuizScreen.tsx:88` — `position: relative` on each option's wrapper, which
      // is what makes the flecks' *negative* offsets land outside the card.
      clipBehavior: Clip.none,
      children: <Widget>[
        QuizOptionCard(
          letter: letter,
          text: entry.value,
          state: optionState,
          language: language,
          // `ds.tsx:437`'s `dimmed` is a **visual** treatment, computed by the
          // screen at `QuizScreen.tsx:85`:
          // `checked && letter !== CORRECT && letter !== selected`.
          dimmed: _isDimmed(answer, letter),
          // `enabled` is this client's own — see `QuizOptionCard`'s doc. It is the
          // half of §5 trap 3 that is visible; `QuizBloc`'s `isAnswerable` guard is
          // the half that holds when the event arrives from elsewhere.
          enabled: open && state.status == QuizStatus.ready,
          onTap: () => context.read<QuizBloc>().add(QuizOptionSelected(letter)),
          // **THE NAME, AND THE SUFFIX IS `null` UNTIL THERE IS A VERDICT.** This is
          // the semantics half of the spoiler boundary, and it is why
          // `QuizStringsPhrases.optionLabel` takes the suffix as a parameter rather than
          // deciding it here: the decision has one home.
          semanticLabel: strings.optionLabel(
            letter: letter,
            text: entry.value,
            suffix: _verdictSuffixFor(strings, answer, letter),
          ),
        ),
        // `QuizScreen.tsx:90-97` — four flecks on the correct option only.
        if (optionState == QuizOptionState.correct)
          Positioned.fill(
            child: GoldFlecks(
              offsets: QuizOptionCard.fleckOffsetsFor(
                MediaQuery.sizeOf(context).width -
                    QuizPage.cardWidthAt(context),
              ),
            ),
          ),
      ],
    );
  }

  /// The visual state of [letter] on [answer].
  ///
  /// ## THE `switch`, AND WHY IT IS AN EXPRESSION
  ///
  /// §4 asks for exhaustive `switch` expressions over enums rather than `if`-chains
  /// for state branching, and this is the phase's only place four states meet.
  /// `QuizScreen.tsx:78-85` is the prototype's rule verbatim; `QuizOptionState`'s
  /// doc is the transcription.
  QuizOptionState _optionStateFor(QuizAnswer? answer, String letter) {
    final QuizAnswer? current = answer;
    if (current == null) return QuizOptionState.idle;

    // ## NOT CHECKED — the only state before a commit
    if (!current.isChecked) {
      return current.selectedLetter == letter
          ? QuizOptionState.selected
          : QuizOptionState.idle;
    }

    // ## CHECKED, AND **ONLY THE SUBMITTED LETTER** IS GRADED
    //
    // `QuizScreen.tsx:79-82` marks `opt.letter === CORRECT` as correct and
    // `opt.letter === selected` (when it is not that one) as incorrect — so the
    // prototype grades **one** option and leaves the rest idle.
    //
    // ## THE FIRST VERSION MARKED **EVERY** OPTION CORRECT, AND IT IS THE MOST
    // ## IMPORTANT LINE IN THIS PHASE
    //
    // It read `if (current.isCorrect == true) return QuizOptionState.correct`
    // **before** consulting `letter`, so a right answer painted all four cards
    // green and drew **four** celebrations instead of one. `quiz_page_test.dart`
    // caught it by asserting *exactly one* correct card — a count rather than a
    // membership test, which is the difference between "a correct card exists" and
    // "the correct card is the only correct card".
    //
    // The reason it is worth writing down: `SubmitResult` says **whether the
    // submitted letter was right**, never **which letter was right**. So the client
    // knows the verdict on exactly one option and must not extrapolate it to the
    // other three — which is the same discipline as not reading
    // `question.isCorrect` before a check, one level further out.
    if (current.selectedLetter != letter) return QuizOptionState.idle;
    return current.isCorrect == true
        ? QuizOptionState.correct
        : QuizOptionState.incorrect;
  }

  /// `QuizScreen.tsx:85` — `checked && letter !== CORRECT && letter !== selected`.
  bool _isDimmed(QuizAnswer? answer, String letter) {
    final QuizAnswer? current = answer;
    if (current == null || !current.isChecked) return false;
    return current.selectedLetter != letter;
  }

  /// The verdict word for [letter], or `null` before there is one.
  ///
  /// **The same gate as [_optionStateFor] and the same source**, and it is a separate
  /// method rather than a reuse of the state because a `QuizOptionState` does not
  /// say *why* — `correct` could mean "the reader was right" and `incorrect` "the
  /// reader was wrong", which is the second half of the announcement.
  String? _verdictSuffixFor(
    AppLocalizations strings,
    QuizAnswer? answer,
    String letter,
  ) {
    final QuizAnswer? current = answer;
    if (current == null) return null;

    // **§5 trap 3's reason, on an already-answered question.** The wire says this
    // question is done, so every option on it is closed and none of them will ever
    // take a `verdict`. The accessible name is the only place a reader can be told
    // *why* pressing one does nothing, and `quiz_page_test.dart` asserts the string
    // is there — and, in the spoiler direction, that it is **not** a verdict word,
    // which is what keeps "no semantics node carries a verdict before a check"
    // from passing for the wrong reason.
    //
    // ## AND IT IS CHECKED **AFTER** THE VERDICT, AND THE REASON IS **STILL** THAT
    // ## IT IS NOT REACHABLE TODAY
    //
    // The order was `alreadyAnswered` first, on the reasoning that *"an
    // already-answered question is never checked in this session, because `QuizBloc`
    // refuses to submit one"*. That holds, and it was measured again here rather than
    // assumed:
    //
    /// ```text
    /// `_onRetried` (the only rebase) requires `status == failed`.
    /// A question becomes `isChecked` only on a submit that SUCCEEDED, which sets
    /// `status = ready`.
    /// So while the status is `failed`, the current answer was never graded —
    /// a graded answer is not `isAnswerable`, so no second submit can fail on it.
    /// ```
    ///
    // Decision 88 came close: carrying the verdict across a refresh means a graded
    // question now **keeps** its verdict while taking the fresh
    // `already_answered: true`, so the two facts coexist in the domain where before
    // they could not. What closes the gap is the status requirement, not the verdict.
    //
    // **So the reorder is hardening, and it is documented as such rather than
    // dressed as a fix.** No test drives it, because there is no state to drive: the
    // assertion that would have to exist cannot be written without inventing a state,
    // and §7 prefers a missing test to a vacuous one. The invariant it protects —
    // *the card's colour and its accessible name come from the same switch* — is
    // asserted in both of its reachable arms: a graded card's name carries the
    // verdict (`quiz_page_test.dart`), and an already-answered card's carries the
    // reason and **not** a verdict word (this file's spoiler group).
    //
    // **A green card named "already answered" is the same contradiction as a red
    // `Semantics(enabled: true)`** — §13's colour-only rule has nothing to say about
    // it, because it is the *announcement* that would be wrong. And when it does become
    // reachable — Phase 9's language switch re-dispatching `QuizStarted`, or any
    // handler that rebases without requiring `failed` — the verdict is what the reader
    // is looking at, so it is the verdict the name has to say.
    //
    // **Rejected: revert the order and keep the doc's claim.** The claim is a proof
    // about the current call graph, and proofs about call graphs are what a Phase 9
    // event silently invalidates; two lines of ordering are cheaper than re-deriving
    // it.
    //
    // **Rejected: suppress the colour instead, so `alreadyAnswered` can stay first.**
    // That un-grades a question the server graded, in front of a reader who just
    // graded it, to make a string agree — the exact trade decision 88 refuses.
    if (current.isChecked) {
      return switch (_optionStateFor(current, letter)) {
        QuizOptionState.correct => strings.quizCorrectSuffix,
        QuizOptionState.incorrect => strings.quizIncorrectSuffix,
        QuizOptionState.idle || QuizOptionState.selected => null,
      };
    }
    if (current.question.alreadyAnswered) {
      return strings.quizAlreadyAnsweredSuffix;
    }
    return null;
  }

  /// What the one button does, for the current [state].
  void _onCtaPressed(BuildContext context, QuizState state) {
    final QuizBloc bloc = context.read<QuizBloc>();
    switch (state.cta) {
      case QuizCta.none:
        // Nothing to do, and the button is disabled — see the class doc. `unawaited`
        // is not needed because there is no future.
        return;
      case QuizCta.check:
        bloc.add(const QuizAnswerChecked());
      case QuizCta.next:
        bloc.add(const QuizAdvanced());
      case QuizCta.finish:
        final SubmitResult? result = state.lastResult;
        if (result == null) return;
        unawaited(context.router.push(ResultRoute(result: result)));
    }
  }
}

/// The one button. `QuizScreen.tsx:122-128`.
///
/// ## AND THE LABEL IS [QuizState.cta]'s VERBATIM, IN BOTH DIRECTIONS
///
/// `QuizScreen.tsx:127` is `{checked ? 'Next question' : 'Check answer'}` — two of
/// the plan's four arms, and it is transcribed. `finish` and `none` are written,
/// because the prototype has no terminal state and no disabled-with-a-reason state.
///
/// The disabled row is the whole of `LoginPage`'s precedent applied twice
/// (recorded decisions 18 and 32): `Semantics(enabled: false)`, no tap action, and
/// `unavailableSuffix` in the accessible name. `EvaButton(onPressed: null)` renders
/// a disabled button already, so this adds the *reason*.
///
/// ## 87 + 91. THE ANNOUNCED NAME **IS** THE VISIBLE LABEL, AND THE LABEL NAMES A
/// ## **STATE** RATHER THAN A COUNT
///
/// This class used to have **two** channels: `label` for the caption and `reason` for
/// a suffix appended to the accessible name only. Two channels is one too many, and
/// they disagreed.
///
/// ### The first defect: a **payload** predicate on a live button
///
/// `reason` was computed as `session.answeredCount == session.questionCount` — "the
/// reader has answered everything". That predicate is true of **every session that
/// reaches an answer**, so decision 85's split came apart on precisely the frame a
/// reader is working towards:
///
/// ```text
/// after grading the only question:
///   cta=QuizCta.next  status=ready  answered=1/1  enabled=true
///   cta label = "Next question — there is no answer to show"
///
/// after pressing next (terminal state):
///   cta=QuizCta.finish  status=complete  enabled=true
///   cta label = "See results — there is no answer to show"
/// ```
///
/// So the sentence was not merely *absent* for a sighted reader, as decision 85
/// intended — it was **present and false** on the one control that opens the graded
/// answer, and a screen-reader user is told the answer is missing by the button that
/// reveals it, after they gave it. Every completed session, every time. Nothing
/// asserted it: every existing assertion was `label.contains(suffix)` on a **merged**
/// node, and none of them was on a live CTA at all.
///
/// Fixing the predicate to `state.cta == QuizCta.none` closed that hole and left the
/// two channels intact — and the second defect showed that intact was the mistake.
///
/// ### The second defect: the **sighted** reader was told nothing
///
/// Decision 85's reasoning was *"a reader who cannot see the button is the one who
/// needs the reason"*, which holds only where a second channel exists for everyone
/// else. In the dead end there is none: the screen shows the question, four options
/// and a disabled button. No banner, no `EmptyState`, no caption — every other
/// `Text` is scripture the reader already has. And the button read **"Check answer"**,
/// which is `QuizScreen.tsx:127`'s `{checked ? 'Next question' : 'Check answer'}`
/// applied to a state the prototype does not have: the prototype's
/// `disabled={!checked && !selected}` covers *"nothing chosen yet"* and nothing else.
/// This is the live payload (recorded decision 3's capture is one question with
/// `already_answered: true`), so it is the **first frame** a reader who has already
/// reflected today sees.
///
/// ### The resolution: ONE channel
///
/// A control needs one name, and it has to be the same one visually and to a screen
/// reader — a caption a sighted reader can read and an announcement they cannot is
/// two controls' worth of truth. So:
///
/// * [label] is the whole name, and [Semantics] states it verbatim. There is no
///   suffix, so there is no second thing that can disagree about the state.
/// * [label] names the **state**: the prototype's `checkAnswer` while the reader
///   still has a pending action, and [AppLocalizations.quizUnavailableSuffix] once the session
///   is finished — which is decision 91's split, taken by [QuizState.isSessionFinished]
///   because "is the reader done" is a question about the state and not about the page.
///
/// **Rejected: keeping `reason` with a better predicate.** Two channels is §3's "two
/// implementations of one invariant" at the scale of a single widget, and the audit
/// above is what it costs — the first defect was *found* only by reading the two call
/// sites against each other, and it shipped because each looked right alone.
///
/// **Rejected: a caption above the button.** A second element on a screen whose whole
/// claim is that it is the prototype's layout, for a state the prototype does not
/// have, is a larger divergence than a label on the button that is already there.
///
/// **Rejected: `reason` for the *"nothing chosen yet"* arm.** Decision 87's argument,
/// one level up: "there is no answer to show" for a question nobody has attempted is
/// a sentence about a missing **answer** while describing a missing **choice**, and
/// the two have different fixes.
///
/// `quiz_page_test.dart`'s two groups are the two halves: *"the reason is named only
/// by a DEAD cta"* asserts the live and terminal CTAs' accessible names are
/// **exactly** the prototype's labels, and the dead-end group asserts the dead CTA's
/// name **is** the reason. Equality on both sides, because with the suffix gone the
/// question is no longer "is the reason absent?" but "is the name exactly this?".
class _Cta extends StatelessWidget {
  const _Cta({
    required this.strings,
    required this.language,
    required this.cta,
    required this.status,
    required this.graded,
    required this.finished,
    required this.onPressed,
  });

  final AppLocalizations strings;
  final ReadingLanguage language;

  /// What the button **offers** — and therefore whether it is alive.
  final QuizCta cta;

  /// Where the quiz is, which is what the label turns on.
  ///
  /// **Separate from [cta], and the separation is the prototype's.** A reader who has
  /// chosen nothing and a reader who has chosen but not checked both see
  /// `QuizCta.none`; only the second is graded. `QuizScreen.tsx:127` writes
  /// `{checked ? 'Next question' : 'Check answer'}` while `:125` writes
  /// `disabled={!checked && !selected}` — two different questions, and the first
  /// version of this widget answered both from one.
  final QuizStatus status;

  /// Whether the answer **on screen** has been graded.
  ///
  /// **A parameter and not a `bool` field of its own invention**, because it is
  /// [QuizState.currentAnswer]'s own fact and re-deriving it here would be a second
  /// answer to "has this been checked?". `quiz_bloc_test.dart` owns the rule; this
  /// widget reads it.
  final bool graded;

  /// Whether the session is **finished** rather than merely un-answered — see
  /// [QuizState.isSessionFinished] and decision 91, which is where the argument is.
  final bool finished;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = cta != QuizCta.none;
    // `EvaButton`'s own disabled treatment is the visual half; this is the announced
    // half, and **the label is the whole of it** — see this class's decision 91. There
    // is no separate "reason" channel, because a second channel is a second thing
    // that can disagree about the state, and it did: it printed "there is no answer to
    // show" on the live control that opens the graded answer.
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: kEvaButtonHeight,
          child: EvaButton(
            label: label,
            // `labelFamily` is **required** (recorded decision 66) and this is the
            // payload arm: the caption on `/reading` is Amiri on the AR arm for
            // exactly the same reason.
            labelFamily: switch (language) {
              ReadingLanguage.english => EvaTypography.uiFamily,
              ReadingLanguage.arabic => EvaTypography.arabicFamily,
            },
            onPressed: enabled ? onPressed : null,
          ),
        ),
      ),
    );
  }

  /// The button's visible label — [checked] and [lastQuestion], and **not** [cta].
  ///
  /// ## `complete` GETS ITS OWN LABEL, AND WITHOUT IT THE STATE WAS UNREACHABLE
  ///
  /// The prototype's label has **two** arms and no terminal one, because its screen
  /// has one hard-coded question. This client has to answer "what does the button say
  /// once there is nothing left to advance into", and the honest answer is that the
  /// **press** is what finishes the quiz:
  ///
  /// ```
  /// not graded                  → "Check answer"     (dead until a choice)
  /// graded, more to advance to  → "Next question"    (transcribed)
  /// graded, on the last one     → "Next question"    (transcribed — see below)
  /// complete                    → "See results"      (written)
  /// ```
  ///
  /// **The last graded question says `Next question`, not `See results`,** because
  /// that is what `QuizScreen.tsx:127` says for every graded answer and the press is
  /// `onFinish` — the prototype's *same* control finishes the quiz. Labelling it
  /// `See results` immediately would have made [QuizStatus.complete] **unreachable
  /// from the UI**: no button would ever advance off the end, so the state would exist
  /// only in tests. That is this repository's own dead-branch defect twice over
  /// (recorded decisions 15 and 48), and it is why the arm is transcribed rather than
  /// tidied.
  ///
  /// ## WHY IT IS NOT `cta`, AND WHAT THAT COST
  ///
  /// The prototype states it in two halves, and they are different questions:
  /// `QuizScreen.tsx:127` is `{checked ? 'Next question' : 'Check answer'}` while
  /// `:125` is `disabled={!checked && !selected}`. So the **label** turns on
  /// `checked` and the **enabled-ness** turns on `checked || selected`.
  ///
  /// The first version drove the label off `QuizCta` and therefore said
  /// `AppLocalizations.quizRetry` whenever the button was dead — which is the state a reader
  /// is in **before choosing anything**, so the very first thing the quiz said was
  /// "Try again" for a question they had not attempted. `quiz_page_test.dart` found
  /// it by looking for `Check answer` on the first frame.
  ///
  /// **Three labels, not four.** `checkAnswer` is transcribed, `nextQuestion` is
  /// transcribed, `seeResults` is **written** (`app_en.arb` has the argument:
  /// the prototype has no terminal state). `retry` is not a CTA label at all — it is
  /// the `ErrorView`'s label, which is where the dead end's *way out* lives if the
  /// whole screen failed. It is not offered here because the quiz has not failed.
  String get label => cta == QuizCta.none
      // **Decision 91: the two `none` arms, told apart by the STATE.**
      // `checkAnswer` for "nothing chosen yet" — the prototype's
      // `disabled={!checked && !selected}` — and the written reason for "the session
      // is finished and nothing was submitted", where "Check answer" names the one
      // action this screen cannot perform.
      ? finished
            ? strings.quizUnavailableSuffix
            : strings.quizCheckAnswer
      : switch (status) {
          QuizStatus.complete => strings.quizSeeResults,
          QuizStatus.ready || QuizStatus.submitting => switch (graded) {
            true => strings.quizNextQuestion,
            false => strings.quizCheckAnswer,
          },
          QuizStatus.loading || QuizStatus.failed => strings.quizCheckAnswer,
        };
}

/// The failure state, and the empty state.
///
/// **One widget for both**, and the reason is `HomePage`'s `withSection`: they have
/// the same shape and the same retry control, and a reader who has seen one has seen
/// the other. The **message differs** — a failure shows the mapper's own words, an
/// empty session shows the string table's.
class _FailedOrEmpty extends StatelessWidget {
  const _FailedOrEmpty({
    required this.strings,
    required this.onRetry,
    this.message,
    this.empty = false,
  });

  final AppLocalizations strings;
  final VoidCallback onRetry;

  /// The failure's message, or `null` for the empty state.
  final String? message;

  /// Whether this is the empty session rather than a failure.
  final bool empty;

  @override
  Widget build(BuildContext context) => NeuralScaffold(
    variant: NeuralVariant.quiz,
    scrollable: false,
    padding: QuizPage.rootPadding,
    child: Center(
      child: empty
          ? EmptyState(
              icon: Icons.help_outline,
              title: strings.quizNoQuestionsTitle,
              message: strings.quizNoQuestionsMessage,
            )
          : ErrorView(
              message: message ?? '',
              onRetry: onRetry,
              retryLabel: strings.quizRetry,
              // `ErrorView`'s **ambient** arm, for decision 77's reason: the
              // message is the server's own text, which may be any script, and
              // Amiri carries Latin as well as Arabic.
              retryFamily: arabicAwareFamily(
                Directionality.of(context),
                EvaTypography.uiFamily,
              ),
            ),
    ),
  );
}
