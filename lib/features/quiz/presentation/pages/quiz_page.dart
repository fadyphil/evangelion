import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/features/quiz/presentation/widgets/result_sheet.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/quiz` — the question flow. `eva/redesign.html:562-574`, minus the old
/// prototype's two-state preview toggle (see below).
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
/// The old prototype's `:56-63` was the whole of it: two chip-shaped buttons whose
/// only behaviour was `setSelected(null); setChecked(false)` and
/// `setSelected('B'); setChecked(true)`. **The second one set the correct answer to
/// `B` and marked it correct without asking the server.** Porting it would put a
/// control on the quiz that grades a question this client has not submitted — which
/// is `is_correct` on the wire with no request behind it, the exact spoiler
/// `AGENT_CONTEXT`'s phase-8 requirement is about, and the reason the exclusion is a
/// design rule rather than a simplification.
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
/// * **show the result anyway** — impossible, and not by policy:
///   `ResultSheet`'s `SubmitResult` is **required**, so there is no sheet without
///   a graded answer to show. A `null` result and an `EmptyState` would be a
///   second kind of result surface for a case where the reader submitted
///   nothing;
/// * **hide the button** — §14's disabled row exists precisely so a control is
///   *absent* rather than missing, and a button that vanishes on one reader's screen
///   and stays on another's is a layout a reader cannot predict;
/// * **submit the already-answered question again** — that is the 409.
///
/// So the button ships inert, labelled `AppLocalizations.quizUnavailableSuffix` — on
/// the caption as well as in the accessible name, since the sighted reader on this
/// screen has no second channel. That is the shape `LoginPage`'s four social buttons
/// and `AppTopBar`'s avatar already use (recorded decisions 18 and 32). **This is
/// visible product debt** and it is one argument at one call site: give the endpoint
/// a "today's result" read and the button has something to open.
///
/// ## THE REDESIGN'S CHROME, AND WHAT THE OLD SCREEN LOST
///
/// The markup is `eva/redesign.html:562-574` and the CSS `:328-368`: an appbar with
/// a `‹` back chevron, the centred `Refraction · <reference>` crumb and the gold
/// `✦ N` score; the `.dots` row re-homed under it; a centred scripture prompt; four
/// tint-tier options; and the `.qnext` ghost pill. The old screen's mono
/// `Question 2 of 5` line and its `FeedbackBanner` have no counterpart in that
/// markup, and both are gone: the progress surface is the bead row, and the verdict
/// lives on the graded card itself — colour, glyph, the shake on wrong, and the
/// live region that used to belong to the banner (§9.5 of the task research).
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

  /// The prompt's size. `eva/redesign.html:334` — `font-size: 25px` — **down from
  /// the old transcription's 26**, which read the superseded prototype's
  /// `ds.tsx`-era display figure.
  static const double promptFontSize = 25;

  /// `eva/redesign.html:334` — `line-height: 1.4`.
  static const double promptLineHeight = 1.4;

  /// `eva/redesign.html:334` — `font-weight: 500` — **down from 600**, same
  /// superseded source.
  static const FontWeight promptWeight = FontWeight.w500;

  /// `eva/redesign.html:335` — `margin: 0 auto 30px`, the gap under the prompt.
  static const double promptBottomGap = 30;

  /// `eva/redesign.html:335` — `max-width: 26ch`, the prompt's measure.
  ///
  /// ## WHY THE CONSTANT IS NOT THE NUMBER, AND THE NUMBER IS NOT INVENTED
  ///
  /// CSS `ch` is the advance of the `0` glyph in the element's own face, and Flutter
  /// has no `ch` unit — the width has to be composed. EB Garamond's figures sit at
  /// ≈ 0.5em (the face's digits are old-style, close to half the em), so the
  /// rendered cap is [promptMaxChars] × [promptFontSize] × 0.5 = 312.5px. The
  /// constraint's *job* — a ~26-character measure — is insensitive to the tenth:
  /// 0.45em gives 281 and 0.55em gives 344, and every reading stays a two-to-three
  /// line centred block on each §14 surface. `quiz_geometry_test.dart` pins the
  /// composed number so the factor cannot drift silently.
  static const double promptChEmFactor = 0.5;

  /// The composed prompt cap, in logical px — see [promptChEmFactor]'s doc.
  static double get promptMaxWidth =>
      promptMaxChars * promptFontSize * promptChEmFactor;

  /// `eva/redesign.html:335` — `max-width: 26ch`, the character count.
  static const double promptMaxChars = 26;

  /// `eva/redesign.html:339` — `margin-bottom: 12` between options.
  static const double optionGap = EvaSpacing.md;

  /// The question body's side padding. `eva/redesign.html:333` — `padding: 0 26px`.
  static const double bodySidePadding = 26;

  /// `.qnext`'s box: `eva/redesign.html:363` — `margin: 6px 26px 30px`.
  static const EdgeInsets ctaMargin = EdgeInsets.fromLTRB(26, 6, 26, 30);

  /// `eva/redesign.html:364` — `padding: 14px` on all sides of the pill.
  static const EdgeInsets ctaPadding = EdgeInsets.symmetric(vertical: 14);

  /// `eva/redesign.html:364` — `font-size: 11px`.
  static const double ctaFontSize = 11;

  /// `eva/redesign.html:364` — `letter-spacing: .18em`, resolved against the
  /// element's own 11px for the recorded CSS-em rule.
  static const double ctaLetterSpacing = 0.18 * ctaFontSize;

  /// `eva/redesign.html:363` — `border: 1px solid rgba(232,176,75,.55)`, with
  /// `emberInk` standing in for the gold, the same substitution as the score.
  static const double ctaBorderAlpha = 0.55;

  /// `eva/redesign.html:368` — `.qnext:hover`'s `background:
  /// rgba(232,176,75,.12)`.
  static const double ctaHoverFillAlpha = 0.12;

  /// `eva/redesign.html:363` — `border-radius: 999px`, the pill.
  static const double ctaRadius = 999;

  /// `eva/redesign.html:573` and `:967` — the terminal label's painted star,
  /// sized by the label's own 11px (`FourPointedStar`'s em-box rule), and the gap
  /// of the space character the prototype puts before it.
  static const double ctaStarSize = ctaFontSize;
  static const double ctaStarGap = 4;

  /// The CTA's disabled face. The redesign has no disabled state (`:347`'s
  /// `cursor: default` is all it says), and this client's dead end needs one: the
  /// old `EvaButton` had its own, and 45% is what `LoginPage`'s four inert
  /// controls use (recorded decision 18).
  static const double ctaDisabledOpacity = 0.45;

  /// The prompt's [TextStyle] for the arm [language].
  ///
  /// **A per-arm function, not one shared number**, for `reading_geometry_test.dart`'s
  /// library doc: the prototype publishes one set of numbers and a screen that needs two
  /// arms gets two answers, each pinned against its own prototype line.
  ///
  /// The **scripture** face on the Latin arm and Amiri on the Arabic one: the
  /// prompt is the server's text, in the server's language, so this is decision
  /// 75's payload arm rather than `arabicAware` — and it is a deliberate divergence
  /// from the prototype's route-level RTL rule (`:134`, which gives the *UI*
  /// Arabic face to every route under RTL), recorded here: the prompt is payload,
  /// not chrome, and the payload arm wins.
  static TextStyle promptStyleFor(
    BuildContext context,
    ReadingLanguage language,
  ) => Theme.of(context).textTheme.headlineMedium!.copyWith(
    fontSize: promptFontSize,
    height: promptLineHeight,
    fontWeight: promptWeight,
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

  /// One option card, and the **only** place a verdict becomes a visual state.
  ///
  /// ## THIS IS THE SPOILER BOUNDARY, IN ONE FUNCTION
  ///
  /// It reads [QuizAnswer.verdict] — the submit response — and never
  /// `QuizAnswer.question.isCorrect`, which the wire also carries and which is
  /// `true` on an already-answered question. It is gated on `isChecked`, so a
  /// question the reader has not checked cannot be `correct` no matter what the
  /// payload says.
  static QuizOptionState optionStateFor(QuizAnswer? answer, String letter) {
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
    // `eva/redesign.html:1426` grades the tapped option against its local key and
    // marks **one** card; the rest stay as they are. This client knows the verdict
    // on exactly one option and must not extrapolate it to the other three — the
    // same discipline as not reading `question.isCorrect` before a check, one level
    // further out.
    //
    // ## THE FIRST VERSION MARKED **EVERY** OPTION CORRECT, AND IT IS THE MOST
    // ## IMPORTANT LINE IN PHASE 8
    //
    // It read `if (current.isCorrect == true) return QuizOptionState.correct`
    // **before** consulting `letter`, so a right answer painted all four cards
    // green and drew **four** celebrations instead of one. `quiz_page_test.dart`
    // caught it by asserting *exactly one* correct card — a count rather than a
    // membership test, which is the difference between "a correct card exists" and
    // "the correct card is the only correct card".
    if (current.selectedLetter != letter) return QuizOptionState.idle;
    return current.isCorrect == true
        ? QuizOptionState.correct
        : QuizOptionState.incorrect;
  }

  /// The verdict word for [letter], or `null` before there is one.
  ///
  /// **The same gate as [optionStateFor] and the same source**, and it is a separate
  /// method rather than a reuse of the state because a `QuizOptionState` does not
  /// say *why* — `correct` could mean "the reader was right" and `incorrect` "the
  /// reader was wrong", which is the second half of the announcement.
  static String? verdictSuffixFor(
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
    // refuses to submit one"*. That holds, and it was measured again here rather
    // than assumed:
    //
    // ```text
    // `_onRetried` (the only rebase) requires `status == failed`.
    // A question becomes `isChecked` only on a submit that SUCCEEDED, which sets
    // `status = ready`.
    // So while the status is `failed`, the current answer was never graded —
    // a graded answer is not `isAnswerable`, so no second submit can fail on it.
    // ```
    //
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
    // it, because it is the *announcement* that would be wrong. And when it does
    // become reachable — Phase 9's language switch re-dispatching `QuizStarted`, or
    // any handler that rebases without requiring `failed` — the verdict is what the
    // reader is looking at, so it is the verdict the name has to say.
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
      return switch (optionStateFor(current, letter)) {
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

  /// The screen for [state]: the question, the options and the CTA.
  Widget _body(
    BuildContext context, {
    required AppLocalizations strings,
    required QuizState state,
  }) => switch (state.status) {
    QuizStatus.loading => const NeuralScaffold(
      variant: NeuralVariant.quiz,
      // `scrollable` is left at its `false` default, which is what the
      // prototype's flexed `.qbody` asks for: the prototype's own scrollable, and
      // the reason `/reading` and this screen agree.
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
    QuizStatus.submitting => _quiz(context, strings: strings, state: state),
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
      // **Zero, and every region owns its own padding.** The redesign's screen is
      // not one padded box: the appbar is `46/18/4` (`:142`), the dots row
      // `8/0/4` (`:328`), the body `0 26px` (`:333`) and the CTA `6/26/30`
      // (`:363`). One root padding would re-flatten four different decisions
      // into a fifth number.
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          QuizHeader(
            crumb: strings.quizCrumb(session.reference),
            score: session.runningScore,
            total: session.questionCount,
            completed: session.answeredCount,
            current: state.currentIndex,
            language: language,
            strings: strings,
            onExit: widget.onExit,
          ),
          // `.qbody` (`eva/redesign.html:333`) is `flex: 1` with
          // `justify-content: center` — centred when short, scrollable when tall.
          // A `SliverFillRemaining(hasScrollBody: false)` is exactly that pair of
          // behaviours, and it is what makes the 320×568 text-scale invariant
          // ("the fourth option is one scroll away, not dropped") hold without a
          // `Column` over unbounded content (§13 rule 5).
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: QuizPage.bodySidePadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: QuizPage.promptMaxWidth,
                            ),
                            child: Text(
                              // **The prompt, and only the prompt.** The options
                              // carry the answers and the answer state is
                              // [answer]'s, which is null until the reader has
                              // committed.
                              answer?.question.prompt ?? '',
                              textAlign: TextAlign.center,
                              style: QuizPage.promptStyleFor(context, language),
                            ),
                          ),
                        ),
                        const SizedBox(height: QuizPage.promptBottomGap),
                        for (final MapEntry<String, String> option
                            in (answer?.question.options ??
                                    const <String, String>{})
                                .entries)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: QuizPage.optionGap,
                            ),
                            child: _optionCard(
                              context,
                              strings: strings,
                              answer: answer,
                              entry: option,
                              language: language,
                              state: state,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Cta(
            strings: strings,
            language: language,
            cta: state.cta,
            // **`graded`, not `cta`.** The prototype's label and its disabled flag
            // are **two different questions** — and the first version of this
            // widget drove the label off `cta`, so a reader with nothing
            // chosen was told "**Try again**", a sentence this client invented for a
            // different state. `quiz_page_test.dart` is what caught it, by looking
            // for `Check answer` before a selection.
            graded: state.currentAnswer?.isChecked ?? false,
            finished: state.isSessionFinished,
            onPressed: () => _onCtaPressed(context, state),
          ),
        ],
      ),
    );
  }

  /// One option card, and the live region the banner left behind.
  ///
  /// ## THE `liveRegion` IS THE BANNER'S HEIR
  ///
  /// The old screen wrapped its verdict in a `Semantics(liveRegion: true)` on the
  /// way out; the redesign has no banner, so the graded card's wrapper carries the
  /// flag instead (`eva/redesign.html:350-359` — the verdict *is* the card now).
  /// `Semantics` here is a container, so what gets announced is the card's own
  /// subtree — the same arrangement the retired banner widget used, and the reason
  /// `quiz_accessibility_test.dart`'s §14 subject survives the banner's retirement.
  Widget _optionCard(
    BuildContext context, {
    required AppLocalizations strings,
    required QuizAnswer? answer,
    required MapEntry<String, String> entry,
    required ReadingLanguage language,
    required QuizState state,
  }) {
    final String letter = entry.key;
    final QuizOptionState optionState = QuizPage.optionStateFor(answer, letter);
    final bool open = answer?.isOpen ?? false;
    final String? suffix = QuizPage.verdictSuffixFor(strings, answer, letter);

    final QuizOptionCard card = QuizOptionCard(
      letter: letter,
      text: entry.value,
      state: optionState,
      language: language,
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
        suffix: suffix,
      ),
    );

    if (!QuizOptionCard.isGraded(optionState)) return card;
    return Semantics(liveRegion: true, child: card);
  }

  /// What the one button does, for the current [state].
  void _onCtaPressed(BuildContext context, QuizState state) {
    final QuizBloc bloc = context.read<QuizBloc>();
    switch (state.cta) {
      case QuizCta.none:
        // Nothing to do, and the button is disabled — see the class doc.
        return;
      case QuizCta.check:
        bloc.add(const QuizAnswerChecked());
      case QuizCta.next:
        bloc.add(const QuizAdvanced());
      case QuizCta.seeResults:
        // `eva/redesign.html:1432` — the last graded question's one click opens
        // the results. **The result is a MODAL over this quiz**, not a route
        // (Phase 6.2), and the response is still a **required** input: there is
        // no endpoint that can produce one, so the guard below is not
        // decoration, it is the compile-enforced constraint stated again at the
        // one call site that can trip it.
        final SubmitResult? result = state.lastResult;
        if (result == null) return;
        unawaited(_presentResult(result));
    }
  }

  /// Shows the result over the quiz, and then does what the reader chose.
  ///
  /// ## THE ORDER IS THE WHOLE OF IT
  ///
  /// The sheet's two CTAs were **page** actions — `replacePath('/quiz')` and
  /// `replacePath('/')` — and inside a dialog the same calls would leave the
  /// reader with a dialog over a replaced route. So the button **closes the
  /// sheet first** (it pops the dialog with the action) and the action is
  /// taken **here**, after the dialog's route is out of the navigator's
  /// history. The reader ends up in exactly one place with no dialog left on
  /// screen, which is what `quiz_result_sheet_test.dart` proves in both
  /// directions.
  ///
  /// ## "REFLECT AGAIN" IS **THE QUIZ THAT IS STILL THERE**
  ///
  /// As a page it was a *new* `/quiz` route. As a modal it is **this** quiz,
  /// restarted in place — which is [QuizStarted], the same event a fresh quiz
  /// page dispatched, and the same session the reader was answering.
  ///
  /// **A dismissed sheet changes nothing.** `null` is the dismissed case and
  /// the quiz is exactly where it was, with the reader free to carry on.
  ///
  /// ## WHY IT TAKES NO `BuildContext`
  ///
  /// It reads [State.context] — this state's own — and the `mounted` check
  /// below is therefore the check that guards it, which is what
  /// `use_build_context_synchronously` asks for. A `BuildContext` handed in as
  /// a parameter would be an *unrelated* context, and the lint is right to
  /// refuse it: the guard would be about this state and the use would be about
  /// something else.
  Future<void> _presentResult(SubmitResult result) async {
    final ResultSheetAction? action = await ResultSheet.show(
      context,
      // **The card is built HERE, and that is load-bearing.**
      //
      // `tool/gates/orphan_widget_check.py` finds a widget by looking for its
      // **constructor call** in a page's file, so a `show` that built the card
      // inside its own file would leave the card — and the `StatTile` and
      // `SunBurst` it draws — unreachable from every page. The gate reported
      // all three as orphans, and the honest repair is to make the placement
      // **visible** rather than to allowlist a widget that is demonstrably on
      // the screen.
      //
      // **The pops go to the ROOT navigator**, which is where
      // `showGeneralDialog` put the dialog: `showGeneralDialog` pushes with
      // `rootNavigator: true`, so the root navigator's top route is the sheet
      // and popping it is closing the sheet.
      card: ResultSheet(
        result: result,
        onReflectAgain: () => Navigator.of(
          context,
          rootNavigator: true,
        ).pop(ResultSheetAction.reflectAgain),
        onBackHome: () => Navigator.of(
          context,
          rootNavigator: true,
        ).pop(ResultSheetAction.backHome),
      ),
    );
    // The page may have gone while the sheet was up — the reader pressed back
    // out of the quiz, say — and a `BuildContext` used after its widget is
    // disposed throws.
    if (!mounted) return;

    switch (action) {
      case ResultSheetAction.reflectAgain:
        context.read<QuizBloc>().add(QuizStarted(_language));
      case ResultSheetAction.backHome:
        unawaited(context.router.replacePath(AppRoutes.home));
      case null:
        // **Dismissed.** The barrier or the system back button, and the quiz is
        // still on screen under it.
        break;
    }
  }
}

/// The one button — `.qnext`, `eva/redesign.html:363-368` and `:573`.
///
/// A ghost pill: transparent fill, a 1px gold-tier rim, mono caps, `999px` radius.
/// It replaces `EvaButton`, whose filled treatment the redesign's CTA does not
/// wear.
///
/// ## AND THE LABEL IS THE STATE'S VERBATIM, IN BOTH DIRECTIONS
///
/// The old prototype's label was `{checked ? 'Next question' : 'Check answer'}`
/// with `disabled={!checked && !selected}` — two different questions, and the
/// first version of this widget answered both from one. Under the redesign the
/// graded arms are the I18N row's own pair (`:967`, applied at `:1431`): `next ▸`
/// while a question remains, `see results ✦` on the last. The two written arms are
/// this client's own states, and decision 91's split is what names them:
/// `checkAnswer` for "nothing chosen yet", `unavailableSuffix` for the dead end.
///
/// ## AND THE DISABLED ROW IS THE WHOLE OF DECISION 91, RESTATED
///
/// `Semantics(enabled: false)`, no tap action, and the reason in the accessible
/// name — one channel, the visible label, stated in [labelText]'s switch.
///
/// ## DIVERGENCES FROM THE PROTOTYPE, RECORDED WHERE THEY HAPPEN
///
/// * **The pill is never hidden.** `.qnext` is `opacity: 0` until an answer is
///   picked (`:1421` removes it, `:1430` shows it) because the prototype's grader
///   is one-tap. This client's check is a second press (the grade is a `POST`), so
///   the control that drives the flow is present from the first frame and disabled
///   until it can act — hiding the only control that grades would leave the reader
///   with no visible affordance for the step the prototype does not have.
/// * **The hover lift on options is not ported** (`:345`'s `translateY(-2px)`).
///   The card's press and hover feedback is `EvaInk`'s; a -2px jump with none of
///   the prototype's `.3s` spring behind it reads as a glitch, not a hover.
/// * **The star on the label is painted**, never text — U+2726 is in no bundled
///   family (`FourPointedStar`'s doc carries the measurement) — and **English
///   only**: the prototype's own I18N pair gives `seeRes` no star on the Arabic
///   arm (`:967`).
class _Cta extends StatefulWidget {
  const _Cta({
    required this.strings,
    required this.language,
    required this.cta,
    required this.graded,
    required this.finished,
    required this.onPressed,
  });

  final AppLocalizations strings;
  final ReadingLanguage language;

  /// What the button **offers** — and therefore whether it is alive.
  final QuizCta cta;

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
  State<_Cta> createState() => _CtaState();
}

class _CtaState extends State<_Cta> {
  /// `.qnext:hover`'s fill (`eva/redesign.html:368`), and why this widget is
  /// stateful: the hover fill is an instant background swap — there is no
  /// controller behind it and none is wanted for a 12%-alpha wash.
  bool _hovered = false;

  /// The button's visible label — [QuizCta] plus the two facts that split `none`.
  ///
  /// ## WHY THE `none` ARM STILL NEEDS `graded` AND `finished`
  ///
  /// `none` is three situations (see [QuizState.isSessionFinished]'s doc), and the
  /// label has to tell them apart: "nothing chosen yet" keeps the check label,
  /// the dead end names what is missing, and the **submitting** frame keeps
  /// whatever the previous frame said — the button goes dead for the round trip
  /// and its label does not lie about a state it is merely waiting through.
  String get labelText => switch (widget.cta) {
    QuizCta.check => widget.strings.quizCheckAnswer,
    QuizCta.next => widget.strings.quizNextQuestion,
    QuizCta.seeResults => widget.strings.quizSeeResults,
    QuizCta.none => switch (widget.graded) {
      // The submitting frame of a graded answer: the label it had a moment ago.
      // `graded` is false while the request is in flight (the verdict arrives
      // with the response), so this arm is "not yet graded" — the check label,
      // which is what the previous frame said too.
      false =>
        widget.finished
            ? widget.strings.quizUnavailableSuffix
            : widget.strings.quizCheckAnswer,
      true => widget.strings.quizNextQuestion,
    },
  };

  /// Whether the label carries the painted star — the English arm's `seeRes` only.
  bool get hasStar =>
      widget.cta == QuizCta.seeResults &&
      widget.language == ReadingLanguage.english;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.cta != QuizCta.none;
    final Color ink = context.colors.emberInk;
    final TextStyle style = ctaStyle(context);

    final Widget label = hasStar
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  labelText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(width: QuizPage.ctaStarGap),
              FourPointedStar(size: QuizPage.ctaStarSize, color: ink),
            ],
          )
        : Text(
            labelText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );

    // `EvaButton`'s own disabled treatment is gone with the filled style; the ghost
    // pill's disabled face is the recorded 45%, and this is the announced half —
    // **the label is the whole of it**, so there is no second thing that can
    // disagree about the state.
    return Semantics(
      button: true,
      enabled: enabled,
      label: labelText,
      // The same arrangement as the option card: `excludeSemantics: true` drops the
      // ink's anonymous tap node, so this node must carry the action itself or the
      // button is announced and unpressed. `quiz_accessibility_test.dart`'s graded
      // sweep found the missing half — after a check every option is disabled, and
      // the screen had no activatable node at all.
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : QuizPage.ctaDisabledOpacity,
        child: Padding(
          padding: QuizPage.ctaMargin,
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
            onExit: enabled ? (_) => setState(() => _hovered = false) : null,
            child: ExcludeSemantics(
              child: EvaFocusRing(
                enabled: enabled,
                radius: QuizPage.ctaRadius,
                child: EvaInk(
                  // §14's disabled row: the action is genuinely absent, not
                  // present-and-flagged.
                  onPressed: enabled ? widget.onPressed : null,
                  borderRadius: BorderRadius.circular(QuizPage.ctaRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // `eva/redesign.html:363` — `background: transparent`,
                      // with `:368`'s hover wash on top.
                      color: _hovered
                          ? ink.withValues(alpha: QuizPage.ctaHoverFillAlpha)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(QuizPage.ctaRadius),
                      border: Border.all(
                        color: ink.withValues(alpha: QuizPage.ctaBorderAlpha),
                      ),
                    ),
                    child: Padding(
                      padding: QuizPage.ctaPadding,
                      child: Center(child: label),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The CTA label's [TextStyle].
  ///
  /// `eva/redesign.html:364` — mono, 11px, `.18em` tracking. Under RTL the
  /// prototype swaps the family and drops the tracking (`:366`); the tracking
  /// resolves to zero there, which is the same rule without a second family
  /// switch.
  ///
  /// ## AND THE `text-transform: uppercase` IS **NOT** APPLIED
  ///
  /// `:364` uppercases the label in CSS. This client renders the string table's
  /// value verbatim — the same choice the old screen made for its mono line, and
  /// the reason is in `monoCapsText`'s doc: `text-transform` is a rendering
  /// transform in CSS and a content transform here, and the accessible name is
  /// the human phrase, not its letter case. The tracked mono face carries the
  /// look; the value stays what `app_en.arb` wrote.
  TextStyle ctaStyle(BuildContext context) {
    final TextStyle base = Theme.of(context).textTheme.labelMedium!.copyWith(
      fontSize: QuizPage.ctaFontSize,
      letterSpacing: Directionality.of(context) == TextDirection.rtl
          ? 0
          : QuizPage.ctaLetterSpacing,
      fontFamily: switch (widget.language) {
        ReadingLanguage.english => EvaTypography.monoFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      },
      color: context.colors.emberInk,
    );
    return base;
  }
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
    padding: EdgeInsets.zero,
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
