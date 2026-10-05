import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/result/presentation/result_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// `/result` — the screen after a graded answer. `ResultScreen.tsx:33-80`.
///
/// ## IT HAS **NO** REPOSITORY, NO USE CASE AND NO API CALL, AND THAT IS A
/// ## CONSTRAINT RATHER THAN A SIMPLIFICATION
///
/// `08-build-phases.md` §Phase 8: "`/result` reads the submit response held by
/// `QuizBloc` and has no repository, no use case, and no API call of its own."
///
/// **The response is a required constructor parameter**, and the reason it cannot be
/// read out of the bloc is §3's feature independence: `features/result/` importing
/// `features/quiz/presentation/bloc/quiz_bloc.dart` is **Gate 2**, the same wall
/// `HomeCleared` could not cross in the other direction and `navigation_injection.dart`
/// had to route around. So the hand-off is the parameter.
///
/// **Which makes the constraint compile-enforced, and that is the point.** There is
/// no `ResultPage()` without a graded answer, so there is no empty result screen, no
/// "no result yet" empty state to design, and no second shape for this page to have.
/// A reader who submitted nothing has **no `/result` at all** — which is why
/// `QuizState.cta` is `QuizCta.none` in that case rather than `finish`
/// (`QuizState.cta`'s doc has the whole argument).
///
/// **Rejected: a `BlocProvider` over `QuizBloc` inside `features/quiz/`'s router
/// entry.** That is the same forbidden import with a wrapper around it.
/// **Rejected: a `ResultResultHolder` in `core/`.** It would be a second source of
/// truth for a value that already has exactly one, and `core/domain/` is the wrong
/// place for mutable per-process state.
///
/// ## AND EVERY NUMBER ON THIS SCREEN COMES FROM [result] — THE THIRD
/// ## `current_streak`, AND DECISION 22 EXTENDED
///
/// §5 trap 8 measures two copies of `current_streak` disagreeing on the same reader
/// on the same day: `readings/today` says `4`, `streak/summary` says `0`. Recorded
/// decision 22 resolves that pair by **never reconciling them** — each field comes
/// from the endpoint whose job it is.
///
/// `SubmitResult.current_streak` is the **third**, and this screen draws **it**,
/// because it is the response to the action the screen is about. §5 trap 4 is what
/// makes that safe: the streak moves only when `reading_completed == true`, so this
/// number was written *by the submission the reader just made* while `/`'s two were
/// written by a read.
///
/// **This is an extension of decision 22, not a replacement for it.** `/` still reads
/// `StreakSummary.currentStreak` in its top bar and still draws no reconciliation;
/// nothing about that screen changed. `result_page_test.dart` holds the extension in
/// the failing direction: it builds a `SubmitResult` whose streak is a sentinel,
/// asserts **that** number is on screen, and asserts the other two endpoints' values
/// are not.
@RoutePage()
class ResultPage extends StatelessWidget {
  /// The result of one graded answer.
  const ResultPage({required this.result, super.key});

  /// The submit response, which is this screen's **only** input.
  final SubmitResult result;

  /// The root padding. `ResultScreen.tsx:34` — `padding: '52px 24px 36px'`.
  static const EdgeInsets rootPadding = EdgeInsets.fromLTRB(
    EvaSpacing.xxl,
    52,
    EvaSpacing.xxl,
    36,
  );

  /// The burst's size. `ResultScreen.tsx:6` — `width="100" height="100"`.
  ///
  /// **100 and not [SunBurst]'s own default of 96**, for the same reason
  /// `reading_geometry_test.dart` records for the drop cap: `ds.tsx` publishes one
  /// number for one screen, and the widget's default is not a transcription of
  /// anything.
  static const double burstSize = 100;

  /// `ResultScreen.tsx:38` — `marginBottom: 22` under the burst.
  static const double burstGap = 22;

  /// `ResultScreen.tsx:38` — `filter: drop-shadow(0 0 36px rgba(#F5C84C, .55))`.
  ///
  /// **Transcribed, and it belongs to the screen rather than the widget** because
  /// `SunBurst`'s own doc says so: it is the svg, the glow is the container's
  /// `filter`, and putting it inside the widget would invent a shape the prototype
  /// does not have.
  static const double burstGlowBlur = 36;

  /// `ResultScreen.tsx:38` — the glow's alpha.
  static const double burstGlowAlpha = 0.55;

  /// `ResultScreen.tsx:44` — the score's `fontSize: 68`.
  static const double scoreFontSize = 68;

  /// `ResultScreen.tsx:44` — `letterSpacing: '-0.02em'`.
  ///
  /// Resolved against the score's own 68px, for `StickyCta`'s recorded reason: CSS
  /// `em` tracking is relative to the element's font size, so this is `1.36` and not
  /// `0.02`.
  static const double scoreLetterSpacing = -0.02 * scoreFontSize;

  /// `ResultScreen.tsx:45` — the denominator's `fontSize: 42`. **Not used**: there
  /// is no denominator, and the field's doc gives the whole argument.
  static const double denominatorFontSize = 42;

  /// `ResultScreen.tsx:43` — `marginBottom: 14` under the score.
  static const double scoreGap = EvaSpacing.md;

  /// `ResultScreen.tsx:49` — `marginBottom: 24` under the message.
  static const double messageGap = EvaSpacing.xxl;

  /// `ResultScreen.tsx:49` — `maxWidth: 260`, and the message is centred inside it.
  static const double messageMaxWidth = 260;

  /// `ResultScreen.tsx:65` — the pill's `padding: '8px 18px'`.
  static const EdgeInsets pillPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: EvaSpacing.sm,
  );

  /// `ResultScreen.tsx:64` — `gap: 8` between the flame and the label.
  static const double pillGap = EvaSpacing.sm;

  /// `ResultScreen.tsx:56` — the pill's fill is `ember` at `isDark ? .12 : .1`.
  static const double darkPillAlpha = 0.12;
  static const double lightPillAlpha = 0.1;

  /// `ResultScreen.tsx:58` — `border: '1px solid rgba(ember, .28)'`.
  static const double pillBorderAlpha = 0.28;

  /// `ResultScreen.tsx:60` — `boxShadow: '0 0 24px rgba(ember, .22)'`.
  static const double pillGlowBlur = 24;
  static const double pillGlowAlpha = 0.22;

  /// `ResultScreen.tsx:71` — the stat row's `gap: 10`.
  static const double statGap = 10;

  /// `ResultScreen.tsx:71` — `marginBottom: 32` under the stat row.
  static const double statGapBottom = 32;

  /// `ResultScreen.tsx:77` — the button column's `gap: 12`.
  static const double buttonGap = EvaSpacing.md;

  /// `ResultScreen.tsx:62` — the pill flame's `width="14" height="18"`.
  static const double pillFlameWidth = 14;
  static const double pillFlameHeight = 18;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return NeuralScaffold(
      // `QuizScreen.tsx:42` is `<NeuralBackground variant={4} />` and
      // `ResultScreen.tsx:35` is `variant={5}`. `NeuralVariant.quiz` and
      // `NeuralVariant.result` are those two numbers.
      variant: NeuralVariant.result,
      // **`true`**, and the first version omitted it — so the column below was laid
      // out in `NeuralScaffold`'s **non-scrolling** default and overflowed §14's
      // surface by 185px. The class's own doc says `scrollable: false` is "the
      // body owns its own scrollable", and this screen's body is a `Column`.
      scrollable: true,
      padding: rootPadding,
      // `NeuralScaffold`'s own scrollable: `ResultScreen.tsx:34` is a plain
      // `flex: 1` column with no `overflowY`, and at §14's surface
      // (320×568 at 1.22×) this screen's content does not fit, so the scaffold
      // scrolls it rather than a `Column` overflowing — §13 rule 5.
      child: _body(context, strings),
    );
  }

  /// The screen's content, in the prototype's order.
  Widget _body(BuildContext context, AppLocalizations strings) => Column(
    // ## `mainAxisSize.min` AND **NOT** `MainAxisAlignment.center`
    //
    // `ResultScreen.tsx:34` is `minHeight: 844` on a non-scrolling flex column, so
    // the prototype's content is centred because the column is taller than its
    // content. Two of §14's rules forbid reproducing that here — no
    // `minHeight: 844`, and no overflow at 320×568 — so this column **scrolls**, and
    // inside a scroll view the main axis is unbounded: `center` is then not "centred"
    // but an overflow of 174px, measured at 320×568/1.22× on the AR arm.
    //
    // `min` is the honest answer for a scrolling column and it is what every other
    // screen in this repository does (`ScriptureBlock`'s `ListView`, `StickyCta`'s
    // column). The cost is recorded: **the burst is at the top of `/result` rather
    // than optically centred** at §14's surface. Centring it properly needs a bounded
    // height, and a bounded height is the thing that overflows.
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: burstGap),
        child: DecoratedBox(
          // `ResultScreen.tsx:38` — the container's `filter: drop-shadow(...)`.
          // `ImageFilter` rather than `BoxShadow`, because a CSS `drop-shadow` on
          // an element follows the **alpha** of what it is drawn on and a
          // `BoxShadow` is a rectangle; a 96px glow on a transparent svg needs the
          // former.
          decoration: BoxDecoration(
            color: Colors.transparent,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: EvaStickerPalette.of(StickerSlot.sun)
                    .withValues(alpha: burstGlowAlpha),
                blurRadius: burstGlowBlur,
                spreadRadius: burstGlowBlur / 2,
              ),
            ],
          ),
          // `ExcludeSemantics` is inside [SunBurst] (its own doc says the burst is
          // decorative), so this line is the widget and nothing else.
          child: const SunBurst(size: burstSize),
        ),
      ),
      _Score(result: result, strings: strings),
      const SizedBox(height: messageGap),
      Text(
        strings.messageFor(
          isCorrect: result.isCorrect,
          readingCompleted: result.readingCompleted,
        ),
        textAlign: TextAlign.center,
        // `ResultScreen.tsx:49-51` — `F.ui, 16, 400, lineHeight 1.55, T.ink2`,
        // `maxWidth: 260`.
        style: arabicAware(
          Theme.of(context).textTheme.bodyLarge!
              .copyWith(fontSize: 16, height: 1.55, color: context.colors.ink2),
          Directionality.of(context),
        ),
      ),
      const SizedBox(height: statGapBottom),
      _StreakPill(result: result, strings: strings),
      const SizedBox(height: statGapBottom),
      _StatRow(result: result, strings: strings),
      const SizedBox(height: statGapBottom),
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            EvaButton(
              label: strings.resultReflectAgain,
              labelFamily: _ctaFamily(context),
              onPressed: () =>
                  unawaited(context.router.replacePath(AppRoutes.quiz)),
            ),
            const SizedBox(height: buttonGap),
            EvaButton(
              label: strings.resultBackHome,
              labelFamily: _ctaFamily(context),
              variant: EvaButtonVariant.secondary,
              // **To `/`, and not to a library.** §2 decision 1 cut the library, and
              // `resultBackHome`'s description records why the prototype's label is
              // not transcribed: a button reading "Back to library" that goes to `/`
              // would be a lie about where it leads.
              onPressed: () =>
                  unawaited(context.router.replacePath(AppRoutes.home)),
            ),
          ],
        ),
      ),
    ],
  );

  /// The primary button's label family, for the arm on screen.
  ///
  /// **DM Sans, and NOT the payload arm.** Both of this screen's buttons are the
  /// app's own chrome — "Reflect again" and "Back" — and decision 75's table puts
  /// chrome on the **ambient** arm. `ReadingPage` needed `StickyCta.ctaFamilyFor`
  /// because its CTA caption is a count *about the payload*; there is no such thing
  /// here.
  ///
  /// `labelFamily` is required (recorded decision 66), so the value has to be named
  /// at every call site; `arabicAwareFamily` is the ambient answer and it is here
  /// rather than a second `switch` because there is nothing per-arm to switch on.
  static String _ctaFamily(BuildContext context) =>
      arabicAwareFamily(Directionality.of(context), EvaTypography.uiFamily);
}

/// The headline figure. `ResultScreen.tsx:43-46`.
///
/// ## THERE IS NO **`/5`** HERE, AND THAT IS THE LARGEST DIVERGENCE ON THIS SCREEN
///
/// `ResultScreen.tsx:44-45` is a `4` at 68sp beside a `/5` at 42sp. The `5` is a
/// **hard-coded literal** in a screen with no data layer — there is no endpoint in
/// this backend that returns a question count for a session, and §2's route table
/// gives `/result` no repository, so a client cannot learn it.
///
/// Rendering one would be decision 45's rejected rule in its purest form: a number a
/// reader would read as a fact about their own day, which the server never sent. So
/// the figure is the **running total** and the denominator is **gone**, and
/// [ResultPage.denominatorFontSize] is carried with a doc saying it is not used
/// rather than deleted — a reader comparing against the prototype needs to find the
/// transcription and its replacement, and a silently absent `42` says neither.
class _Score extends StatelessWidget {
  /// The score is [result]'s **running total**.
  const _Score({required this.result, required this.strings});

  final SubmitResult result;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      // `ResultScreen.tsx:43` — `lineHeight: 1`, so the figure's box is its own
      // height and the caption below does not inherit the leading.
      Text(
        // **`currentTotalPoints`, not `pointsEarned`.** This screen reports the
        // reader's standing after the submission; the answer's own score is the
        // first stat tile. `result_page_test.dart` asserts both numbers are on screen
        // and that they are not the same one twice.
        // **The arm's numerals, not `toString()`.** The first draft rendered
        // `result.currentTotalPoints.toString()` — Western digits — beside tiles that
        // `arabic_typography_test.dart` holds to Amiri **with** Arabic-Indic digits, so
        // the Arabic arm showed one Western and two Arabic-Indic numerals on one
        // screen. `result_page_test.dart` found it by looking for `٤٠` and finding
        // nothing.
        //
        // `_StatRow._countIn` is the same rule, called from a different class in the
        // same file — which is the one place two callers is acceptable, because it is
        /// one file and one rule rather than two files and two rules.
        _StatRow._countIn(strings, result.currentTotalPoints),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displayLarge!.copyWith(
          fontSize: ResultPage.scoreFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: ResultPage.scoreLetterSpacing,
          height: 1,
          // The **ambient** arm: the number is the app's own rendering of a server
          // integer, and there is no payload behind it that could say which face.
          fontFamily: arabicAwareFamily(
            Directionality.of(context),
            EvaTypography.displayFamily,
          ),
          color: context.colors.ink,
        ),
      ),
      const SizedBox(height: EvaSpacing.xs),
      Text(
        // ## AND THE CAPTION IS PLURALISED **WITHOUT** THE NUMBER
        //
        // `resultTotalCaption` is an ICU plural that selects the NOUN and carries no
        // `{digits}`, because the score is drawn one line above in `displayLarge` and
        // folding the numeral in here would print it twice. It takes the same integer
        // that line draws, so there is one count and one source for it.
        //
        // This is the half of the migration that is a CORRECTNESS FIX rather than a
        // refactor: the value was `نقطة` — singular — for every score, so `٥ نقطة`
        // rendered where Arabic wants `٥ نقاط`. `test/l10n/` holds the six classes.
        strings.resultTotalCaption(result.currentTotalPoints),
        style: arabicAware(
          Theme.of(context).textTheme.bodySmall!,
          Directionality.of(context),
        ).copyWith(color: context.colors.ink3),
      ),
    ],
  );
}

/// The streak pill. `ResultScreen.tsx:54-66`.
///
/// ## §3.1's DELETION TEST, RUN — AND IT BECAME A PRIVATE WIDGET HERE
///
/// `04-widget-inventory.md` line 364 names `StreakPill` as a feature-local
/// composite, and line 52's demotion watch list does **not** name it. The test is
/// "two or more call sites, or deleting the widget makes complexity reappear", and:
////
/// * **one** call site — this one;
/// * deleting it reappears as a `Container` with five decoration properties, two
///   alpha functions and a derived label. That **is** complexity, so the bar is met
///   on the second clause;
/// * and it is not shared with any other feature, so promoting it to
///   `core/design_system/` would be §3's "nothing enters the kernel speculatively" on
///   the other side.
///
/// So it is a **private** widget in this file rather than
/// `features/result/presentation/widgets/streak_pill.dart`. The derived label is
/// [ResultStringsPhrases.streakLabelFor], which is a **pure function on the string table**
/// and so is unit-tested without a widget — which is the half of the coverage a
/// separate file would have bought.
///
/// **Rejected: a public `StreakPill` in `core/design_system/`.** It would be a
/// fourth widget in the tree with one caller, and the fifth entry on a demotion list
/// that already has six.
///
/// **Rejected: a separate file.** It is forty lines with one caller, and
/// `HomePage`'s `_Avatar` and `ReadingPage`'s `_ArabicBand` are the precedent for
/// keeping a one-caller composite beside its screen.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.result, required this.strings});

  final SubmitResult result;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Brightness brightness = Theme.of(context).brightness;

    return Container(
      padding: ResultPage.pillPadding,
      decoration: BoxDecoration(
        // `ResultScreen.tsx:56` — `rgba(ember, isDark ? .12 : .1)`.
        color: colors.ember.withValues(
          alpha: brightness == Brightness.dark
              ? ResultPage.darkPillAlpha
              : ResultPage.lightPillAlpha,
        ),
        borderRadius: BorderRadius.circular(999),
        // `ResultScreen.tsx:58`.
        border: Border.all(
          color: colors.ember.withValues(alpha: ResultPage.pillBorderAlpha),
        ),
        // `ResultScreen.tsx:60`.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ember.withValues(alpha: ResultPage.pillGlowAlpha),
            blurRadius: ResultPage.pillGlowBlur,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // `ResultScreen.tsx:62-64` is an inline `<svg>` flame **14×18**, which is
          // NOT the design system's `StreakFlame` — that one is square
          // (`streak_flame.dart`'s `size` sets width **and** height) and is
          // transcribed from `ds.tsx:522`, a different site.
          //
          // So the prototype's own shape is a **width/height pair**, and a square
          // icon at 18 would be visibly wider than the prototype's. It is drawn at
          // 14×18 here. `result_geometry_test.dart` asserts the pair, because the
          // alternative — accepting the square and losing the number — is the kind of
          // divergence that is invisible in a diff and visible on screen.
          SizedBox(
            width: ResultPage.pillFlameWidth,
            height: ResultPage.pillFlameHeight,
            child: FittedBox(
              fit: BoxFit.contain,
              child: StreakFlame(
                size: ResultPage.pillFlameHeight,
                // The pill's label already says the streak; a second node saying
                // "Streak" would be two names for one number.
                semanticLabel: strings.resultDay,
              ),
            ),
          ),
          const SizedBox(width: ResultPage.pillGap),
          Text(
            strings.streakLabelFor(
              current: result.currentStreak,
              longest: result.longestStreak,
            ),
            style: arabicAware(
              Theme.of(context).textTheme.bodyMedium!,
              Directionality.of(context),
            ).copyWith(fontWeight: FontWeight.w600, color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// The three stat tiles. `ResultScreen.tsx:69-73`.
///
/// ## §3.1's DELETION TEST AGAIN, AND IT ALSO BECAME A PRIVATE WIDGET
///
/// Same answer, and it is worth the symmetry: `StatRow` is named in
/// `04-widget-inventory.md` line 364 as a feature-local composite, and the deletion
/// test says a `Row` of `StatTile`s with a `gap` is **not** complexity — it is three
/// lines that reappear as three lines. So it is private, beside its screen, and the
/// numbers it shows are the recorded substitution the class doc of
/// [ResultPage] tabulates.
///
/// ## **TWO** TILES, NOT THREE, AND THE THIRD NUMBER WAS A **DUPLICATE**
///
/// `ds.tsx:469-472` and `ResultScreen.tsx:70-72` both write three. This row has two,
/// and the reason is that a third would have to repeat a number already on screen:
///
/// | where | prototype's value | here |
/// | --- | --- | --- |
/// | the headline | `4` | `currentTotalPoints` |
/// | the pill | `Day 12` | `currentStreak` + the comparison |
/// | tile 1 | `14 Read` | `pointsEarned` |
/// | tile 2 | `9 Reflected` | `longest_streak` |
/// | tile 3 | `5/5 Best` | **gone** |
///
/// `SubmitResult` has exactly seven fields and four of them are the four places above.
/// A third tile could only have been `currentTotalPoints` or `currentStreak`, both of
/// which are already drawn — and `result_page_test.dart` caught the first draft for
/// it, because `find.text('1234')` matched **two** widgets.
///
/// *Rejected: inventing a third figure.* There is nothing else in the response, and a
/// number a reader would read as a fact about their own day must come from the server.
/// *Rejected: `points_value` as a denominator.* §2's route table gives `/result` no
/// repository, so the client never learns how many questions the session had.
///
/// **Rejected: the prototype's three tiles**, `14 Read` / `9 Reflected` / `5/5 Best` —
/// all three are **profile history**, §2 decision 1 cut the profile, and no endpoint
/// in this backend returns days-read or reflections-so-far. Shipping them would mean
/// inventing three numbers a reader would read as facts about their own history.
class _StatRow extends StatelessWidget {
  _StatRow({required this.result, required this.strings})
    : tiles = tilesFor(
        pointsEarned: result.pointsEarned,
        longestStreak: result.longestStreak,
        strings: strings,
      );

  final SubmitResult result;
  final AppLocalizations strings;

  /// The three tiles, built in the **initializer list** so the constructor can stay
  /// `const`.
  ///
  /// **An initializer list and not a `late final` field**, because `late` cannot live
  /// in a class with a `const` generative constructor — and the `const` is worth
  /// having, since this widget is rebuilt with its parent. The two instance members
  /// being read are the ones the parameter list just bound, which is legal in an
  /// initializer list and illegal in a field initializer.
  final List<(String, String)> tiles;

  @override
  Widget build(BuildContext context) => Row(
    // `ResultScreen.tsx:69` — `display: flex, gap: 10, width: '100%'`.
    children: <Widget>[
      // `StatTile` is `flex: 1` in `ds.tsx:465`, so `Expanded` is the transcription
      // and the three tiles share the row evenly. `ResultPage.statGap` is the
      // prototype's `gap: 10` between them, applied as padding on the first two
      // rather than on all three, for the reason `ProgressBeads`' own build records:
      // a CSS `gap` is the space **between** items and there is no trailing one.
      for (int index = 0; index < tiles.length; index++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == tiles.length - 1 ? 0 : ResultPage.statGap,
            ),
            child: StatTile(value: tiles[index].$1, label: tiles[index].$2),
          ),
        ),
    ],
  );

  /// The **two** `(value, label)` pairs, in the prototype's order.
  ///
  /// **A `final` field and not a getter**, because a getter would rebuild two strings
  /// on every frame of a tree that paints once. It is a **static** method rather than
  /// an instance field so the tiles are constructible in a `const` constructor's
  /// initializer list — which is what keeps this widget `const`-able and therefore
  /// cheap enough to rebuild with its parent.
  ///
  /// The labels are the **written** substitutions, and [ResultPage]'s doc tabulates
  /// them against `ResultScreen.tsx:70-72`.
  ///
  /// **A named function and not two inline tuples** so the order lives in one place.
  ///
  /// ## `currentTotalPoints` WAS A PARAMETER HERE, AND REMOVING IT IS THE FIX
  ///
  /// The first version took three fields and returned three tiles, the third being
  /// `currentTotalPoints` under a written label — **and that number is the headline**,
  /// in Arabic-Indic digits, one line above the row. `result_page_test.dart` found it
  /// by asserting `findsOneWidget` on the headline and getting **two**.
  ///
  /// So the parameter is gone rather than defaulted, ignored, or given a third label.
  /// Leaving it in the signature would have been the worse repair: a required
  /// parameter nothing reads is a claim that something does, and the next reader
  /// would either wire it back up or spend an afternoon proving it is dead.
  ///
  /// **A count check would not have caught the reintroduction**, which is why the
  /// suite's companion test compares the *values*: `find.byType(StatTile)` is two
  /// today, and asserting two passes on a screen that merged three into two.
  static List<(String, String)> tilesFor({
    required int pointsEarned,
    required int longestStreak,
    required AppLocalizations strings,
  }) => <(String, String)>[
    (_countIn(strings, pointsEarned), strings.resultThisAnswer),
    (_countIn(strings, longestStreak), strings.resultBestRun),
  ];

  /// [value] in [strings]' numerals.
  ///
  /// **A one-line delegate and not the arm's own `_count`** — decision 77's reason
  /// inverted. The tiles are drawn by [StatTile] in `headlineSmall`, so *this file*
  /// decides what string reaches it, and the rule has to be reachable from here. The
  /// rule itself is [AppLocalizationsArm.digits], shared with `/quiz` and `/reading`
  /// because three features need it and §3 puts that in shared code.
  ///
  /// On the Arabic arm that is the Arabic-Indic form, because Amiri carries Arabic
  /// **and** Latin — so a Western digit would render, but beside an Arabic streak pill
  /// it would be the only Western numeral on the screen.
  ///
  /// `StatTile` resolves both of its runs through `arabicAware` (decision 84), so
  /// the family question is settled at the widget and this method only decides the
  /// **numerals**.
  ///
  /// ## AND THIS IS WHERE `ResultStrings.isArabic` USED TO BE READ
  ///
  /// It was derived by comparing `backHome` against the Arabic arm's `backHome`,
  /// which had a real argument behind it — a stored `bool` would have been a second
  /// source of truth for the same fact as the nouns being Arabic. With ARB that
  /// comparison has no honest form left: it would compare a generated getter against
  /// a second generated instance, which tests the generator rather than the arm and
  /// breaks the moment a translator picks an Arabic value that coincides with the
  /// English one. [AppLocalizationsArm.isArabicArm] reads the locale instead, which
  /// is the fact the question was asking.
  static String _countIn(AppLocalizations strings, int value) =>
      strings.digits(value);
}
