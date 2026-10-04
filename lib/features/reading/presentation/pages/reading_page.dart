import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:evangelion/features/reading/presentation/reading_text_scale.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_controls.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_header.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/reading` — the sanctuary. `ReadingEnScreen.tsx:8-93` and
/// `ReadingArScreen.tsx:8-91`, one page, two arms.
///
/// ## THE ROOT IS A **STACK**, AND THAT IS THE ONLY WAY THE CTA IS VISIBLE
///
/// `NeuralScaffold`'s `child` sits **below** its `bottomFade` in one `Stack`, and
/// the fade is solid `canvas` at 95% from 40% of its own height down. The prototype
/// puts the CTA at `zIndex: 2` **above** the content at `:1`
/// (`ReadingEnScreen.tsx:85`), and `NeuralScaffold`'s doc says its `bottomFade`
/// exists for "the sticky CTA's scrim" — so the CTA has to paint above it.
///
/// **A `Stack` here rather than a parameter on `NeuralScaffold`.** The obvious fix is
/// an `overlay` slot on the screen root, and it is declined for a reason that is
/// already a test: `neural_scaffold_test.dart` pins the scaffold's constructor
/// parameter set **exactly**, with the reasoning that "a new parameter on it is a
/// decision every screen inherits, not a default". One screen needing one stacking
/// order is not six screens needing a new argument — and
/// `Stack(fit: StackFit.expand, children: [Positioned.fill(scaffold),
/// Positioned(cta)])` says the same thing in the place that owns it.
///
/// ## `scrollable: false`, BECAUSE THE BODY OWNS ITS OWN SCROLLABLE
///
/// `ReadingEnScreen.tsx:26` puts `overflowY: 'auto'` on the **content div**, not on
/// the root — which is what lets the sticky CTA overlay it. `NeuralScaffold`'s own doc
/// records this as the reason `false` is correct for `/reading` and `/quiz`, and
/// `ScriptureBlock`'s `ListView.builder` is that scrollable. §13 rule 5's "no `Column`
/// + `map` over unbounded data" is why it is a `ListView.builder` and not the
/// prototype's `<div>` with five `<p>`s in it, and why the header travels **inside**
/// it rather than above it.
///
/// ## DIRECTION IS THE **LOCALE**'S, AND NOTHING IN THIS FILE DECIDES IT
///
/// `MaterialApp` installs `Directionality` from `locale`, which is Phase 6's
/// mechanism, and there is **no `Directionality` and no `startsWith('ar')` anywhere
/// under `lib/`**. What this file passes down is a [ReadingLanguage], and every
/// layout decision that depends on it is a named per-arm constant in the widget that
/// owns it — `ScriptureBlock.fontSizeFor`, `ReadingHeader.ruleGapFor`,
/// `StickyCta.captionLetterSpacingFor`, `ReadingControls.paddingFor`. A single
/// shared number for any of them is the defect `home_geometry_test.dart`'s library doc
/// names, so none is shared and `reading_geometry_test.dart` pins each against its own
/// prototype line.
///
/// ## AND THE PAGE **RENDERS VERSES ONLY** — THE ANSWER IS NOT ON THIS SCREEN
///
/// **Measured live against `HEAD = 4a1c834`:** `GET /readings/today/{lang}` puts
/// `user_answer: 'A'` and `is_correct: true` **inside the question object**. The
/// server ships today's answer with today's reading, so any client that has read this
/// screen's payload already holds the answer to `/quiz`.
///
/// This is the sanctuary — the one screen where a reader is asked to sit with the text
/// — and drawing `is_correct` here would tell the reader the answer to `QuizPage`
/// before they have chosen one. So [ScriptureText.questions] is carried and unread,
/// exactly as `TodayReading.currentStreak` and `StreakSummary.nextMilestone` are
/// carried and unread in Phase 6, and `reading_page_test.dart` asserts in the failing
/// direction that neither the boolean, nor the letter, nor the option texts, nor the
/// prompt reach the rendered tree — with the live payload, which has all four, behind
/// it.
///
/// **A `ReadingPage` that rendered the reading's questions would be a bug, not a
/// feature.** Phase 8's `QuizPage` is where they belong.
///
/// ## AND NOTHING ON THIS SCREEN **INVENTED** A NUMBER THE SERVER DID NOT SEND
///
/// The prototype's metadata row reads `Genesis · Chapter 1 · 4 min` and its caption
/// reads `5 questions · about a minute`. The live payload carries **one** question,
/// **no** duration field anywhere, and a `reference` rather than a passage name.
/// `ReadingHeader` shows the `translation`, the citation shows the `reference`, and
/// `StickyCta`'s caption is `captionFor(questionCount)` — pluralised, and derived.
/// `reading_page_test.dart` asserts that no `min`, no `about a minute` and no
/// prototype's `Genesis` reaches the screen, in the failing direction.
@RoutePage()
class ReadingPage extends StatelessWidget {
  /// The reading sanctuary.
  const ReadingPage({super.key, this.cubit});

  /// The cubit to render.
  ///
  /// `null` means "resolve [ReadingCubit] from the locator", which is the production
  /// path. A parameter rather than only a lookup because a widget test cannot reach
  /// the locator without configuring the whole graph — the same arrangement as
  /// `HomePage.bloc` and `LoginPage.bloc`, and for the same reason.
  ///
  /// **Substitution, not initialisation.** A passed-in cubit is loaded exactly as the
  /// locator's is: [_ReadingBody] dispatches `load` unconditionally. See its doc.
  final ReadingCubit? cubit;

  /// The content column's padding. `ReadingEnScreen.tsx:26` —
  /// `padding: '28px 24px 130px'`; `ReadingArScreen.tsx:32` — the same three.
  ///
  /// ## The bottom **130** IS NOT A CONVENTION, IT IS THE SCAFFOLD'S OWN NUMBER
  ///
  /// It is the clearance the prototype reserves so the passage is not hidden behind the
  /// sticky CTA, and `kNeuralScaffoldFadeHeight` is built on the **same** `130`
  /// (`contentReserve`), so the scrim and this reserve agree rather than merely being
  /// close. `reading_geometry_test.dart` pins both against `ReadingEnScreen.tsx:26`.
  ///
  /// ## And each row owns its own gutter
  ///
  /// The scaffold's `padding` is a **uniform** gutter — `EvaSpacing.lg` by default —
  /// and this screen's two rows have two different ones (the controls row is 20,
  /// `ReadingControls.paddingFor`; this column is 24), so the scaffold takes
  /// `EdgeInsets.zero` and each row supplies its own. `NeuralScaffold.padding`'s doc
  /// says "a screen that wants 20 passes it"; here a screen wants two different values
  /// and the honest answer is for the rows to carry them.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    EvaSpacing.xxl,
    EvaSpacing.xxl + EvaSpacing.xs,
    EvaSpacing.xxl,
    130,
  );

  /// The Arabic arm's geometric band. `ReadingArScreen.tsx:13-16` —
  /// `height: 5`, `repeating-linear-gradient(90deg, … 0 2px, transparent 2px 18px)`.
  static const double arabicBandHeight = 5;

  /// The band's dash width and pitch, in logical px. `ReadingArScreen.tsx:15`.
  static const double arabicBandDash = 2;
  static const double arabicBandPitch = 18;

  /// The band's alpha. `ReadingArScreen.tsx:15` — `isDark ? 0.3 : 0.2`.
  static double arabicBandAlpha(Brightness brightness) =>
      brightness == Brightness.dark ? 0.3 : 0.2;

  @override
  Widget build(BuildContext context) {
    // Two sources for one cubit, one provider either way — see [cubit].
    final ReadingCubit? passed = cubit;
    final ReadingCubit resolved = passed ?? getIt<ReadingCubit>();

    return BlocProvider<ReadingCubit>.value(
      value: resolved,
      child: _ReadingBody(onBack: () => unawaited(context.router.maybePop())),
    );
  }
}

/// Everything below the scaffold: the controls, the header, the passage, the CTA.
///
/// A [StatefulWidget] for one reason: `load` must fire **once**, on entry. This is
/// `HomePage`'s arrangement exactly, and `HomePage`'s doc gives the reason — a dispatch
/// in `build` re-issues the request on every state change, which here is **every frame
/// of the font stepper's drag**.
///
/// ## AND IT FIRES FROM `didChangeDependencies`, NOT `initState`
///
/// `Localizations.localeOf` is an inherited-widget lookup and Flutter forbids those in
/// `initState`. Phase 6 measured the exact failure text on four router suites, and the
/// fix is the same here: `didChangeDependencies` is the phase the framework names for a
/// lookup, and it is also the phase that **fires on a locale change** — the second
/// trigger this screen needs, because Phase 9's language switch is a locale change and
/// `/reading` must then show the *other* arm's passage, not the same text under new
/// chrome.
///
/// Guarded on [_requested] being a [ReadingLanguage] and not a `bool`, for `HomePage`'s
/// reason: a `bool` cannot say **which** arm was asked for, so a locale change would
/// re-issue no request and leave English chrome over Arabic scripture.
class _ReadingBody extends StatefulWidget {
  const _ReadingBody({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_ReadingBody> createState() => _ReadingBodyState();
}

class _ReadingBodyState extends State<_ReadingBody> {
  /// The arm of the corpus this screen has asked for, or `null` before the first
  /// dispatch. A **getter**, because it reads an inherited widget — caching it in
  /// `initState` is the mistake [didChangeDependencies]'s doc describes.
  ReadingLanguage get _language =>
      ReadingLanguage.forLocale(Localizations.localeOf(context).languageCode);

  ReadingLanguage? _requested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested != _language) _load();
  }

  /// Dispatches `load` for the language on screen.
  void _load() {
    final ReadingLanguage language = _language;
    _requested = language;
    context.read<ReadingCubit>().load(language);
  }

  @override
  Widget build(BuildContext context) {
    final ReadingStrings strings = ReadingStrings.of(
      Localizations.localeOf(context),
    );
    final ReadingLanguage language = _language;

    return BlocBuilder<ReadingCubit, ReadingState>(
      builder: (BuildContext context, ReadingState state) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: _scaffold(context, language: language, state: state),
          ),
          // ## THE CTA IS GATED ON A QUESTION, NOT ON A PASSAGE
          //
          // It used to be `if (state.scripture case …)`, which is the right question
          // about the **failure** state and the wrong one about a **succeeded** one.
          // `questions: []` is reachable: `today_reading_mapper.dart` **skips** an
          // unreadable question rather than refusing the passage (recorded decision
          // 40), so a payload of four unreadable questions reports
          // `questionCount == 0` — and `ReadingStrings.captionFor`'s own doc says so.
          //
          // Measured: the caption rendered `"0 questions"` / `"٠ أسئلة"` and **Begin
          // reflection was still offered**, so a reader with nothing to reflect on
          // was invited through to an empty quiz. The principle was already stated —
          // `reading_page_test.dart` says the CTA is gone "because there is nothing
          // to reflect on" — and was applied only to a failed request.
          //
          // **The passage is untouched.** The sanctuary still renders in full; what
          // goes is the invitation to a quiz that has no questions in it.
          //
          // A `when` guard on the existing `case` rather than a nested `if`, because
          // §4 asks for the state branching to be in one place and this is one more
          // condition on the same question, not a second question.
          if (state.scripture case final ScriptureText passage
              when passage.questionCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // Bottom only: the controls row's own `20px`/`16px` already sits
              // inside the scaffold's `SafeArea`, and this block is outside it.
              child: SafeArea(
                top: false,
                child: StickyCta(
                  language: language,
                  strings: strings,
                  questionCount: passage.questionCount,
                  onPressed: () => context.router.pushPath(AppRoutes.quiz),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The scaffold and everything inside it, at the reader's text scale.
  Widget _scaffold(
    BuildContext context, {
    required ReadingLanguage language,
    required ReadingState state,
  }) {
    final ReadingStrings strings = ReadingStrings.of(
      Localizations.localeOf(context),
    );
    final ReadingCubit cubit = context.read<ReadingCubit>();

    // ## THE COMPOSED SCALER IS INSTALLED ON A **`MediaQuery`**, NOT THREADED
    //
    // `readingTextScalerFor`'s doc is the whole argument: it is the product of the
    // reader's step and their platform setting, capped at the design system's top row.
    // Installing it here — above **everything** on the screen, controls and CTA
    // included — is what makes "Text size" mean *text size* rather than "passage
    // size", and it is why no widget below takes a `textScaler` it could forget to
    // honour. §14's 1.22× requirement is then a single assertion about this line.
    final TextScaler scaler = readingTextScalerFor(
      step: state.fontStep,
      platform: MediaQuery.textScalerOf(context),
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: NeuralScaffold(
        // `NeuralScaffold`'s doc: `variant` is also "which language the reading
        // screens are in", so this is the **only** place the language reaches the
        // background and nothing re-derives it.
        variant: switch (language) {
          ReadingLanguage.english => NeuralVariant.readingEn,
          ReadingLanguage.arabic => NeuralVariant.readingAr,
        },
        // The body owns its own scrollable — see [ReadingPage]'s doc.
        scrollable: false,
        bottomFade: true,
        // Each row owns its own gutter; see [ReadingPage.contentPadding]'s doc.
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (language == ReadingLanguage.arabic) const _ArabicBand(),
            ReadingControls(
              language: language,
              strings: strings,
              onBack: widget.onBack,
              panelOpen: state.textSizePanelOpen,
              onPanelToggled: cubit.toggleTextSizePanel,
              fontStep: state.fontStep,
              onFontStepChanged: cubit.setFontStep,
            ),
            Expanded(
              child: Padding(
                padding: ReadingPage.contentPadding,
                child: _passage(
                  context,
                  language: language,
                  state: state,
                  strings: strings,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The passage, the failure, or nothing yet.
  ///
  /// **A `switch` over the enum and then a pattern over the payload**, and no
  /// `if`-chain: §4 asks for exhaustive `switch` expressions for state branching, and
  /// the enum arm means a fourth `ReadingStatus` is a compile error here rather than a
  /// blank panel.
  Widget _passage(
    BuildContext context, {
    required ReadingLanguage language,
    required ReadingState state,
    required ReadingStrings strings,
  }) => switch (state.status) {
    ReadingStatus.failed => ErrorView(
      // The failure's **message**, not a string from the table. Phase 6's precedent:
      // the mapper writes "Could not read today's reading: `verses` is absent …" and
      // inventing a sentence here would hide the field that is actually wrong.
      message: state.failure?.message ?? '',
      onRetry: () => context.read<ReadingCubit>().retry(_language),
      retryLabel: strings.retry,
      // `ErrorView.retryFamily`: the label above is the string table's, and on the
      // Arabic arm it is Arabic text going into a button whose only family knob
      // this is. **`StickyCta.ctaFamilyFor`**, not a new constant and not
      // `metadataFamilyFor` — it is the same question ("which face renders this
      // arm's primary button label"), already answered once per arm, and reusing it
      // is what keeps a fourth call site from becoming a fourth answer.
      retryFamily: StickyCta.ctaFamilyFor(language),
    ),
    // The other two arms fall through to the passage, which reads
    // `state.scripture` and renders nothing while it is `null` — a `loading` screen
    // and a `ready` screen are the same tree with different contents, and saying so
    // here keeps the enum switch exhaustive without a duplicated arm.
    ReadingStatus.loading || ReadingStatus.ready => switch (state.scripture) {
      final ScriptureText passage => ScriptureBlock(
        verses: passage.verses,
        language: language,
        strings: ReadingStrings.of(Localizations.localeOf(context)),
        // **Inside** the scrollable, so the metadata and citation travel with the
        // passage — `ReadingEnScreen.tsx:26-77` puts all four in one `overflowY:
        // 'auto'` div. A pinned header would be a different screen.
        header: ReadingHeader(
          language: language,
          reference: passage.reference,
          translation: passage.translation,
        ),
      ),
      // Nothing on screen while loading, and **no placeholder either**: there is no
      // height to reserve, because the passage's own height is the content's and the
      // controls row is already above it. Phase 6's `HomePage._StreakSubtitle`
      // reserves a line because its row sits between two other blocks; here nothing
      // is between anything, so a placeholder would be a blank screen with extra
      // steps.
      null => const SizedBox.shrink(),
    },
  };
}

/// The Arabic arm's geometric band. `ReadingArScreen.tsx:13-16`.
///
/// ## AND ITS COLOUR IS **SUBSTITUTED**, WITH THE REASON AND THE NUMBERS KEPT
///
/// The prototype's is `rgba('#B79CF0', .3 dark / .2 light)` and **`#B79CF0` is not a
/// token** — `03-design-system.md` §5.1 publishes fourteen colours and violet is not
/// among them, while `no_colour_literals_test.dart` refuses every colour in `lib/`
/// that does not resolve through `EvaColors`. So the band is drawn in the **`ink` ramp
/// at the prototype's own two alphas**, which is the same substitution `AppTopBar`'s
/// avatar gradient records (recorded decision 31): the hue was never tokenable and the
/// two alphas were, so the alphas are transcribed and the hue is recorded.
///
/// **The band's identity survives elsewhere.** `NeuralVariant.readingAr` paints the
/// violet orb group (`ds.tsx:88-91`), so the Arabic arm is still the violet one and
/// this ornament is not carrying that on its own.
///
/// **The English arm has no band at all**, which `ReadingEnScreen.tsx` confirms by
/// having no such element — a per-arm structural difference rather than a per-arm
/// colour, and the only one of its kind on this screen.
class _ArabicBand extends StatelessWidget {
  const _ArabicBand();

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color ink = colors.ink.withValues(
      alpha: ReadingPage.arabicBandAlpha(Theme.of(context).brightness),
    );

    return SizedBox(
      height: ReadingPage.arabicBandHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[ink, ink, Colors.transparent, Colors.transparent],
            // 2px of dash in an 18px pitch, as fractions of one period.
            stops: const <double>[
              0,
              ReadingPage.arabicBandDash / ReadingPage.arabicBandPitch,
              ReadingPage.arabicBandDash / ReadingPage.arabicBandPitch,
              1,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            // `repeating-linear-gradient(90deg, …)` — a repeat along **x**, which in
            // Flutter is a left-to-right gradient with `TileMode.repeated`.
            tileMode: TileMode.repeated,
          ),
        ),
      ),
    );
  }
}
