import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/drop_cap_text.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/features/home/domain/preview_text.dart';
import 'package:evangelion/features/home/domain/question_progress.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Today's reading, in the glass panel that opens the sanctuary.
///
/// `HomeScreen.tsx:38-79`. One `GlassSurface`, an eyebrow, a scripture preview, the
/// reference, a bead row and two controls.
///
/// ## IT IS THE **ONLY** BLUR SITE ON `/`, AND THE PER-SCREEN LINE WAS WRONG
///
/// §13 rule 4's inventory is right — eight prototype sites, of which six survive in
/// `ds.tsx` — and its per-screen line used to say "`/`: `.blur` on the
/// today's-reading panel **and the top bar**". `ds.tsx:499-530` has no
/// `backdropFilter` at all: the prototype's top bar is a transparent `div` over the
/// animated background. The rule contradicted its own inventory, and
/// `GlassSurface`'s doc inherited the error by naming "Home's today's-reading panel
/// and the top bar".
///
/// **One** blur ships, here. `AppTopBar` stays transparent like the prototype.
/// `glass_blur_budget_test.dart` now bounds `lib/features/` at one occurrence, and
/// `home_page_test.dart` asserts the tier on the rendered panel so the budget cannot
/// be spent somewhere else without turning something red.
///
/// ## THE EYEBROW IS DERIVED, THE TWO BUTTON LABELS ARE NOT
///
/// `HomeScreen.tsx:44` writes `CONTINUE READING` as a literal, and the live payload
/// has `is_fully_completed: true`. Shipping it unchanged would tell every reader to
/// continue a reading the server says is finished — the same class of defect as the
/// hard-coded greeting name, and it is why [eyebrow] takes the state.
///
/// The two button labels stay the prototype's, and the reason is the difference
/// between a **status** and an **action**: `Continue` and `Start reflection` name
/// destinations (`/reading`, `/quiz`) and both are available whether or not the
/// reading is finished. Deriving them would be inventing copy for states the
/// prototype never designed.
///
/// ## THE BEADS COUNT **QUESTIONS**, NOT PASSAGES
///
/// `HomeScreen.tsx:65` is `<ProgressBeads total={5} completed={2} current={2} />` —
/// passage progress across the four-card library grid that §2 decision 1 cut. The
/// live reading carries **one** question. `question_progress.dart` has the whole of
/// the substitution; what this widget adds is the reading of the two counts.
///
/// ## AND A `0 / 0` ROW RENDERS A **LINE**, DELIBERATELY
///
/// `ProgressBeads` clamps `total` to `0` and returns `SizedBox.shrink()`. So a
/// reading with no questions would render *nothing* between the reference and the
/// buttons — a gap indistinguishable from a layout failure, next to a button, with
/// nothing saying which it is. The deliberate answer is
/// [AppLocalizations.homeNoQuestionsToday] in the same slot, at the same ink, so the row's
/// absence always has a reason. `home_page_test.dart` asserts it.
///
/// ## THE DROP CAP IS **LATIN-ONLY**, AND THAT IS NOT A TRANSLATION
///
/// `HomeScreen.tsx:55-58` splits a literal `I` off `"n the beginning…"` with a 76px
/// ember `I` and leaves the rest in the scripture face. The Arabic arm's first verse
/// begins `كَانَ`, and enlarging a joined, right-to-left Arabic letter to 76px is a
/// defect rather than a rendering of the design: it breaks the letter's connection
/// to the word it belongs to and puts an ember glyph where the ink should be. Same
/// class as defect #2 ("Arabic never uses the mono family"), which Phase 7 owns in
/// the sanctuary.
///
/// So [PassageDropCap] is used for the **Latin** arm only and the Arabic preview is
/// rendered whole. `PassageDropCap.paragraph` is the right call site and it is called
/// only from here; Phase 7 inherits the rule from this file rather than re-deriving
/// it from the prototype.
///
/// ## …AND THE **BODY** WAS NOT BRANCHED, WHICH IS THE SAME DEFECT #2
///
/// The section above is the reason this widget branches on `reading.language` at
/// all. For its first two versions it branched **only** the drop cap and built one
/// `TextStyle` from `EvaTypography.scriptureLatin` for both arms — so Arabic
/// scripture rendered in a Latin face 200 lines below a paragraph citing the
/// Arabic-face defect. Decision 29 repeated the citation without noticing that the
/// body did not honour it.
///
/// Measured, not reasoned about: on an `ar` screen the families present in the tree
/// were `{CormorantGaramond, SpaceMono, DMSans, EBGaramond}` — **`Amiri` absent** —
/// and `EvaTypography.scriptureArabic` was named by nothing in `lib/` except its own
/// definition and doc. `home_page_test.dart` now reads the **rendered** `Text`'s
/// `fontFamily` in both arms, so swapping the two families unconditionally is red
/// in either direction.
///
/// ## AND AN EMPTY VERSE TEXT MUST NOT TAKE THE PANEL WITH IT
///
/// `previewText('')` is `''`, and the drop cap's `substring(0, 1)` on `''` is a
/// `RangeError` out of `build`. This widget's two controls are its own children, so
/// a single verse with no text removed **`Continue` → `/reading` and
/// `Start reflection` → `/quiz`** — the reading route became unreachable from `/`.
/// `_Preview` is now total over `String`; what an empty verse *means* is decided in
/// `today_reading_mapper.dart`, which deliberately does not decide it.
class TodayReadingPanel extends StatelessWidget {
  /// The panel, in exactly one of three states.
  ///
  /// **One constructor, not three named ones.** The first version had
  /// `TodayReadingPanel(...)`, `.loading(...)` and `.failed(...)`, which put the
  /// state in the *name* and let a caller mix them: `.failed` with a reading, or the
  /// plain one with a failure and no error view. Naming the state makes the misuse
  /// unrepresentable; an [assert] on the pair makes it a crash in debug, and a
  /// crash in debug is what the invariant below should produce.
  ///
  /// **The two named constructors were removed in Phase 6's coverage pass**, after
  /// the measurement said what this doc already claimed: `.loading` had exactly one
  /// caller and it was a *test*, and `.failed` had none at all. A constructor kept
  /// alive only by the test written to reach it is a test shaped like the code, and
  /// a constructor with no caller is a §5 forward reference that has stopped being
  /// true. The loading state is `reading: null, failure: null`, spelled out; nothing
  /// about the three states was lost with the names.
  ///
  /// The invariant is **`reading` and `failure` are never both non-null** — not
  /// "exactly one is non-null". The first attempt asserted the latter and it was
  /// **false for the loading state**, which is *both* null: the very state the
  /// loading constructor used to build. Three states over two nullable fields is
  /// one more state than the pair can hold, and the honest reading of the pair is
  /// "these are alternatives"; the loading state is their shared absence and
  /// `HomeState.readingStatus` is what distinguishes it.
  const TodayReadingPanel({
    required this.reading,
    required this.failure,
    required this.strings,
    required this.onOpenReading,
    required this.onStartReflection,
    required this.onRetry,
    super.key,
  }) : assert(
         reading == null || failure == null,
         'reading and failure are alternatives: a panel cannot be showing a '
         'reading AND an error for the same request. Both null is the loading '
         'state, which is legitimate and is what HomeState.readingStatus '
         'distinguishes it from.',
       );

  /// The panel with no answer yet.
  ///
  /// [failure] is the repository's own message, verbatim — `failure.dart` requires
  /// it, and this is the one place on `/` a repository message reaches a player.
  /// Today's reading, or `null` in the loading and failed states.
  final TodayReading? reading;

  /// The failure, in the failed state only.
  ///
  /// The repository's own message, verbatim — `failure.dart` requires it, and this
  /// is the one place on `/` where a repository message reaches a player.
  final String? failure;

  /// The bilingual strings.
  final AppLocalizations strings;

  /// Runs when the reader opens the reading — the whole panel and its primary CTA.
  final VoidCallback? onOpenReading;

  /// Runs when the reader starts the reflection.
  final VoidCallback? onStartReflection;

  /// Runs when the reader asks to try again. The failed state only.
  final VoidCallback? onRetry;

  /// `HomeScreen.tsx:41` — `borderRadius: 24`. [EvaRadii.heroPanel], which §5.3
  /// names for exactly this surface.
  static const double radius = EvaRadii.heroPanel;

  /// `HomeScreen.tsx:41` — `padding: '20px 20px 16px'`.
  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(
    EvaSpacing.xl,
    EvaSpacing.xl,
    EvaSpacing.xl,
    EvaSpacing.lg,
  );

  /// The gap below the eyebrow. `HomeScreen.tsx:44` — `marginBottom: 12`.
  static const double eyebrowGap = EvaSpacing.md;

  /// The gap below the preview row. `HomeScreen.tsx:52` — `marginBottom: 10`.
  static const double previewGap = EvaSpacing.sm + 2;

  /// The gap below the reference. `HomeScreen.tsx:61` — `marginBottom: 14`.
  static const double referenceGap = EvaSpacing.md + 2;

  /// The gap between the two controls. `HomeScreen.tsx:67` — `gap: 10`.
  static const double actionsGap = EvaSpacing.sm + 2;

  /// The gap above the two controls. `HomeScreen.tsx:66` — `marginTop: 16`.
  static const double actionsTopGap = EvaSpacing.lg;

  /// The preview's body size. `HomeScreen.tsx:57` — `fontSize: 17`.
  static const double previewFontSize = 17;

  /// The drop cap's lines. `PassageDropCap`'s own default, restated because this
  /// is the call site that fixes it.
  static const int dropCapLines = 3;

  /// The `Continue` label's family, for [language].
  ///
  /// ## WHY A PER-ARM FAMILY APPEARS ON A PHASE-6 WIDGET IN PHASE 7
  ///
  /// `EvaButton.labelFamily` was optional and nullable, and this call site — one of
  /// four — did not pass it, so `متابعة` went through **DM Sans**, which carries no
  /// Arabic at all. W1's finding is that the parameter's *necessity* was unearned:
  /// it is now **required**, so the compiler asks this site rather than a reviewer,
  /// and a per-arm value is the honest answer because [strings] is per-arm too.
  ///
  /// **The alternative was `EvaTypography.uiFamily`, and that would have written
  /// the tofu down.** The knob exists because the label's script varies; answering
  /// it with the Latin face on the Arabic arm is asserting the defect rather than
  /// fixing it.
  ///
  /// **Not a claim that `/` is whole, and the claim that it was has been deleted.**
  ///
  /// This doc used to carry a measurement of `/`'s broken Arabic arm — "the
  /// subtitle, the reference, the status line and `Start reflection` are all DM Sans
  /// or Space Mono" — and to name the rest "Phase 10's work". It is gone because it
  /// was **both incomplete and out of date**: it missed the greeting's lead-in, the
  /// beads' `0 / 0` line and the failed state's `Failure.message`, and it counted
  /// this widget's own button as sound when the *link* beside it was tofu.
  ///
  /// `test/arabic_typography_test.dart` is the thing that keeps a measurement like
  /// that true, because it re-derives it from the rendered tree on every run and
  /// fails when the count moves. A measurement written down in a doc comment is a
  /// claim; §9's rule is that a claim about a specific thing is only as good as the
  /// test that checks it, and there was none.
  ///
  /// What is here instead is the decision: `continueFamilyFor` is keyed on the
  /// **payload's** arm, which is a fact the caller holds, and every run that renders
  /// the app's own chrome on this panel resolves its family from the ambient
  /// direction through `arabicAware`. Two sources for two different questions, and
  /// neither has to guess.
  static String continueFamilyFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => EvaTypography.uiFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      };

  /// The retry label's family, for [strings]. [ErrorView.retryFamily]'s reason,
  /// applied to this call site: the label is `strings.homeRetry`, so on the Arabic arm
  /// it is Arabic text.
  ///
  /// **The strings and not a `ReadingLanguage`,** and the asymmetry is forced by the
  /// two states: the **content** state has `today.language`, and the
  /// **failed** state has no reading at all — so there is no arm on the payload to
  /// read and the locale is the only thing this widget was handed that knows. Two
  /// spellings of one question in one file would be worse than one spelling that
  /// takes the weaker source.
  ///
  /// ## AND `isArabicArm` IS NOW A STRONGER SOURCE THAN THE STRINGS WERE
  ///
  /// This is the one caller that existed, and the reason `HomeStrings.isArabic` was
  /// derived rather than stored. Its doc called the strings "the weaker source", and
  /// with ARB they would have got weaker still: comparing a generated getter against
  /// a second generated instance tests the generator, and it breaks the moment a
  /// translator picks an Arabic value that coincides with the English one.
  /// [AppLocalizationsArm.isArabicArm] reads the locale, which is the fact the
  /// question actually asks — and it is the same shape as `context.l10n` resolving
  /// the label in the first place, so the label and its family cannot come from two
  /// different notions of "the arm".
  static String retryFamilyFor(AppLocalizations strings) =>
      strings.isArabicArm ? EvaTypography.arabicFamily : EvaTypography.uiFamily;

  @override
  Widget build(BuildContext context) {
    final TodayReading? today = reading;

    return GlassSurface(
      // **The one blur site on `/`.** See the class doc for why the top bar is not
      // the second.
      tier: GlassTier.blur,
      radius: radius,
      padding: panelPadding,
      // §14's row, verbatim: "Home's today panel is a `div onClick` →
      // `GlassSurface(onTap:)` → `InkWell` inside `Material`; keyboard-activatable".
      // `GlassSurface` does the rest: `EvaFocusRing` for the tab stop and the ring,
      // `EvaInk` for the ink, and an assert that an `onTap` has a `semanticLabel`.
      //
      // Null in the loading and failed states, because there is nothing to open —
      // and that is also why the failed panel needs no accessible name: it is not a
      // button.
      onTap: today == null ? null : onOpenReading,
      semanticLabel: today == null ? null : strings.homeTodayReading,
      child: switch (today) {
        null => _FailedOrLoading(
          message: failure,
          retryLabel: strings.homeRetry,
          retryFamily: retryFamilyFor(strings),
          onRetry: onRetry,
        ),
        final TodayReading value => _content(context, value),
      },
    );
  }

  Widget _content(BuildContext context, TodayReading today) {
    final EvaColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          // The **status** line, and the one place `isFullyCompleted` is read. §5
          // records that this field disagrees with `streak/summary.today_completed`,
          // and this widget reads **this** one because this is the reading panel.
          today.isFullyCompleted
              ? strings.homeReadingComplete
              : strings.homeContinueReading,
          // `HomeScreen.tsx:44` — `F.mono 9 / 700 / letterSpacing .14em / ink3`.
          // `EvaTypography.monoCaps` is `labelMedium`'s geometry with the mono
          // family, and §5.2 gives mono no size — see `eva_typography.dart`.
          //
          // Swapped for the ambient arm, and **Space Mono is the worst case in the
          // app**: it carries no Arabic glyph whatsoever, so `متابعة القراءة` and
          // `اكتملت القراءة` were six and fifteen tofu boxes respectively. The
          // geometry is untouched — `monoCaps` is still the style this run is built
          // from, and only its family is resolved for the direction.
          style: arabicAware(
            EvaTypography.monoCaps(colors),
            Directionality.of(context),
          ).copyWith(fontWeight: FontWeight.w700, color: colors.ink3),
        ),
        const SizedBox(height: eyebrowGap),
        _Preview(reading: today, strings: strings),
        const SizedBox(height: previewGap),
        Text(
          today.reference,
          // `HomeScreen.tsx:61` — `F.display 20 / 600 / ink`. `titleLarge` is 22sp
          // in Material 3; `headlineSmall` is 24. Neither is 20, and §5.2 fixes no
          // size — so the prototype's *ratio* to the preview is what is kept and
          // the slot is `titleLarge`, the smallest slot that still reads as a
          // heading. Recorded rather than hidden.
          //
          // Swapped for the ambient arm. `today.reference` is the **server's** string
          // (`Decision 53: rendered verbatim and never parsed`) and on the Arabic arm
          // it is `يوحنا 3: 1-5`, so `titleLarge`'s Cormorant Garamond — which has no
          // Arabic block at all, 974 glyphs and none of them U+0600–U+06FF — rendered
          // the whole citation as tofu. That is not tofu in a *Latin* face on an
          // Arabic screen; it is a citation a reader cannot read at all.
          style: arabicAware(
            Theme.of(context).textTheme.titleLarge!,
            Directionality.of(context),
          ).copyWith(fontWeight: FontWeight.w600, color: colors.ink),
        ),
        const SizedBox(height: referenceGap),
        _Beads(reading: today, strings: strings),
        const SizedBox(height: actionsTopGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: EvaButton(
                label: strings.homeContinueLabel,
                // See [continueFamilyFor]. `reading` is the arm; `strings` is not
                // asked, because the passage already carries the answer and one
                // source for "which arm is this" is the rule `ScriptureText`'s own
                // docs keep making.
                labelFamily: continueFamilyFor(today.language),
                onPressed: onOpenReading,
                expanded: true,
              ),
            ),
            const SizedBox(width: actionsGap),
            Expanded(
              child: Center(
                child: TextLink(
                  label: strings.homeStartReflection,
                  onPressed: onStartReflection,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The scripture preview, with a drop cap on the Latin arm only.
class _Preview extends StatelessWidget {
  const _Preview({required this.reading, required this.strings});

  final TodayReading reading;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    // `ReadingLanguage.english` and not "is the text Latin". The corpus is the
    // decision: NKJV is Latin, Smith & Van Dyck is Arabic, and the *language* is
    // the fact the server sent. A shape test would break on a verse that opens
    // with a numeral or a bracket — which §5's live payload does: verse 3 opens
    // `Jesus answered …`, but a future one could open `‹Verily,`.
    final bool isEnglish = reading.language == ReadingLanguage.english;

    // **Branched, and this is the defect the class doc's own citation predicted.**
    // This widget cites defect #2 — "Arabic never uses the mono family" — as the
    // reason it branches on language at all, and then built **one** `TextStyle`
    // from `scriptureLatin` for both arms 200 lines below that sentence, leaving
    // only the drop cap branched. Measured on an `ar` screen: the families in the
    // tree were `{CormorantGaramond, SpaceMono, DMSans, EBGaramond}` and
    // `EvaTypography.scriptureArabic` was referenced by nothing in `lib/` but its
    // own definition. Swapping `scriptureLatin` for `scriptureArabic`
    // unconditionally passed every one of the 1520 tests, which means the mutation
    // had no witness in either direction.
    //
    // `scriptureArabic` is deliberately identical geometry to `scriptureLatin` (see
    // `eva_typography.dart`), so branching costs one line and changes no size —
    // only the family, which is the whole point.
    final TextStyle body =
        (isEnglish
                ? EvaTypography.scriptureLatin(colors)
                : EvaTypography.scriptureArabic(colors))
            .copyWith(
              fontSize: TodayReadingPanel.previewFontSize,
              color: colors.ink2,
              // `HomeScreen.tsx:57` — `lineHeight: 1.7`.
              height: PassageDropCap.lineHeight,
            );

    final String preview = previewText(reading.firstVerseText);

    // ## TOTAL OVER `String`, WHICH IS THE ONLY RULE A WIDGET GETS HERE
    //
    // The second `if` used to be only the language branch, and the `substring(0, 1)`
    // below it assumed `preview` was non-empty. It is not: `previewText('')` is
    // `''`, so one verse with no text threw `RangeError (end): Only valid value is
    // 0: 1` out of `build` — and because the panel's two `EvaButton`/`TextLink`
    // controls are **this** widget's children, `Continue` → `/reading` and
    // `Start reflection` → `/quiz` both disappeared with it. The exception is not
    // caught anywhere between here and the screen.
    //
    // The mapper's doc asserted the opposite for months — "an empty preview
    // renders an empty paragraph in the panel" — and the panel rendered a thrown
    // exception instead. **A widget handed a `String` must not throw on any
    // `String`**; deciding what an empty verse *means* is the mapper's question and
    // it is answered there (`today_reading_mapper.dart`), not by an index into a
    // string this widget did not check.
    //
    // ## AND `isEmpty` WAS NOT ENOUGH — THE SAME DEFECT, THE OTHER HALF OF IT
    //
    // Phase 7's adversarial review found the identical `substring(0, 1)` **still
    // here**, having been fixed for emptiness in Phase 6 and re-created for
    // **astral characters** in Phase 7's own `/reading` block. Two consequences,
    // both measured:
    //
    // * `substring` indexes UTF-16 code units, so a preview opening with `'\u{1F600}'`
    //   yields the **high surrogate alone** and `RenderParagraph` throws
    //   `ArgumentError: string is not well-formed UTF-16` — taking `Continue` →
    //   `/reading` and `Start reflection` → `/quiz` with it, exactly as the empty
    //   string did.
    // * `' ‹Verily…'` is not empty, so the guard passed, and the cap was `' '`: an
    //   **invisible 131.1px glyph**.
    //
    // `splitDropCap` is the shared answer for both screens, so the two copies of
    // this rule cannot disagree — which is the whole reason it is in `core/domain/`.
    // **[Split] before the `isEnglish` test**, so one well-formed answer covers both
    // arms: the Arabic arm renders `preview` whole, and the split is wasted on it.
    final DropCapText split = splitDropCap(preview);
    if (!isEnglish || split.letter.isEmpty) {
      return Text(preview, style: body);
    }

    final PassageDropCap cap = PassageDropCap(
      letter: split.letter,
      lines: TodayReadingPanel.dropCapLines,
      color: colors.ember,
    );
    return cap.paragraph(
      rest: split.rest,
      bodyStyle: body,
      // §14: the reader's own scaling, composed rather than reset. Passed rather
      // than read so a caller can honour a preference; `PassageDropCap`'s own doc
      // gives the reason and the default is no scaling, which is why it must be
      // handed one.
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

/// The bead row, or the line that says there is nothing to count.
class _Beads extends StatelessWidget {
  const _Beads({required this.reading, required this.strings});

  final TodayReading reading;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    if (reading.questionCount == 0) {
      // The deliberate answer to `0 / 0`. See the class doc.
      return Text(
        strings.homeNoQuestionsToday,
        style: EvaTypography.monoCaps(context.colors)
            .copyWith(color: context.colors.ink3),
      );
    }
    return ProgressBeads(
      total: reading.questionCount,
      completed: reading.answeredQuestionCount,
      current: firstUnansweredQuestionIndex(
        answered: reading.answeredQuestionCount,
        total: reading.questionCount,
      ),
      semanticLabel: strings.homeReflectionProgress,
    );
  }
}

/// The panel's body while there is no reading: a spinner, or an error with a retry.
class _FailedOrLoading extends StatelessWidget {
  const _FailedOrLoading({
    required this.message,
    required this.retryLabel,
    required this.retryFamily,
    required this.onRetry,
  });

  final String? message;
  final String retryLabel;

  /// See [TodayReadingPanel.retryFamilyFor].
  final String retryFamily;
  final VoidCallback? onRetry;

  /// The panel's own height while it has no content, so the bar above it does not
  /// jump when the reading lands.
  ///
  /// **Declared, and it is a number this phase chose.** The prototype has no
  /// loading state to copy; §14's requirement is that the layouts do not move, and
  /// a panel that grows from one line to nine is the layout moving. 120 is the
  /// reference, the eyebrow and one action line at their own sizes, and nothing
  /// pretends to be more.
  static const double placeholderHeight = 120;

  @override
  Widget build(BuildContext context) {
    final String? failure = message;
    if (failure != null) {
      return SizedBox(
        height: placeholderHeight,
        child: ErrorView(
          message: failure,
          onRetry: onRetry,
          retryLabel: retryLabel,
          retryFamily: retryFamily,
        ),
      );
    }
    return const SizedBox(
      height: placeholderHeight,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
