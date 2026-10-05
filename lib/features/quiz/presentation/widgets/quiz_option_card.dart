import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:flutter/material.dart';

/// How one quiz option is drawn. `ds.tsx:416` — `QuizState`.
enum QuizOptionState {
  /// `default` — `ds.tsx:424`'s `accent = null`.
  ///
  /// **No accent means no border colour from the accent ramp**, so the card takes
  /// the resting rim: `rgba(#fff | #000, 0.1)` in `ds.tsx:426`.
  idle,

  /// `selected` — ember. `ds.tsx:424` — `state === 'selected' ? hex.ember`.
  selected,

  /// `correct` — `hex.ok`. `ds.tsx:424`.
  correct,

  /// `incorrect` — `hex.err`. `ds.tsx:424`.
  incorrect,
}

/// One answer option. `ds.tsx:418-457`, the `QuizOption` component.
///
/// ## THE FOUR STATES AND WHO DECIDES THEM
///
/// `QuizScreen.tsx:78-85` computes the state in the **screen**, not the component:
///
/// ```js
/// let state = 'default'
/// if (checked) {
///   if (opt.letter === CORRECT) state = 'correct'
///   else if (opt.letter === selected && selected !== CORRECT) state = 'incorrect'
/// } else if (selected === opt.letter) state = 'selected'
/// const dimmed = checked && opt.letter !== CORRECT && opt.letter !== selected
/// ```
///
/// So the widget takes a state and the page derives it. That split is the whole of
/// the spoiler boundary's structure: **the page can only produce `correct` or
/// `incorrect` when `checked` is true**, and `quiz_page_test.dart` plants a leak
/// that renders `is_correct` before the check to prove the boundary holds.
///
/// ## AND `enabled` IS A **SEPARATE FLAG** FROM `dimmed`
///
/// `dimmed` is the prototype's `checked && …` — visual only, a 48% opacity on an
/// option the reader no longer has to choose.
///
/// `enabled` is this client's own, and it is §5 trap 3: a question whose wire
/// `already_answered` is `true` must be **disabled**, so the reader is never walked
/// into a `409`. The prototype has no such state — its question is hard-coded and
/// unanswered — so this flag has no prototype line and is recorded here as written.
///
/// *Rejected: expressing "disabled" as `onTap: null` alone.* That is a *behaviour*
/// and not a *statement*: §14's disabled row wants `Semantics(enabled: false)` with
/// the tap action genuinely absent **and the reason in the accessible name**, and
/// `SocialAuthButton`'s doc is the precedent for all three at once.
class QuizOptionCard extends StatelessWidget {
  /// An option showing [letter] and [text] in [state].
  const QuizOptionCard({
    required this.letter,
    required this.text,
    required this.state,
    required this.semanticLabel,
    required this.language,
    this.onTap,
    this.enabled = true,
    this.dimmed = false,
    super.key,
  });

  /// The option's key in `Question.options` — `A`…`D` on the live payload.
  ///
  /// `ds.tsx:451` renders it in `F.mono, 12, 700`. §5 trap 10 records that the ids
  /// in this payload are fabricated, and the letters come from the same JSON, so the
  /// badge is drawn **verbatim** — no substitution to a canonical alphabet.
  final String letter;

  /// The option's label. `ds.tsx:454-456` — `F.ui, 15, 400, lineHeight 1.4`.
  final String text;

  /// Which of the four treatments to draw.
  final QuizOptionState state;

  /// The accessible name, including any verdict.
  ///
  /// ## REQUIRED, AND IT IS THE CALLER'S STRING
  ///
  /// §14: an interactive node needs a name, and a card whose name says "correct"
  /// before the reader has checked **is the spoiler leak in its purest form** — it
  /// would be in the semantics tree with nothing painted at all, which is exactly
  /// the class of defect Phase 7 caught by looking at semantics separately from
  /// pixels.
  ///
  /// So the name is built by `QuizStringsPhrases.optionLabel`, which takes the verdict as a
  /// `null`-able suffix, and `quiz_page_test.dart` asserts that **no** node carries
  /// one before a check. It is a required parameter rather than a default so that a
  /// card cannot be added without someone deciding what it says.
  final String semanticLabel;

  /// Which arm of the corpus [text] is in — the arm of the **payload**, from
  /// decision 75's table.
  ///
  /// **Required rather than read from the ambient direction**, and that is the whole
  /// point of decision 75's seam: the option text is the server's scripture, fetched
  /// in the language the session was opened in, so its arm comes from the payload
  /// and **not** from `Directionality.of(context)`. A widget reading the direction
  /// here would render Arabic options in DM Sans on the Arabic arm — which is what
  /// `reading_glyph_test.dart` measures on `/reading`, and the reason a screen that
  /// is rebuilt under Phase 9's language switch cannot desynchronise its scripture
  /// from its chrome.
  ///
  /// It is required for the same reason `EvaButton.labelFamily` and
  /// `IconActionButton.tooltipFamily` are (decisions 66 and 71): a caller that omits
  /// it would get `bodyLarge`'s family, which is EB Garamond and carries no Arabic
  /// at all.
  final ReadingLanguage language;

  /// What to run on activation. `null` disables the card.
  final VoidCallback? onTap;

  /// Whether the reader may still choose this.
  ///
  /// See the class doc: this is the §5 trap 3 prevention, and it is **not** the same
  /// thing as [dimmed].
  final bool enabled;

  /// The prototype's post-check dimming. `ds.tsx:437` — `opacity: dimmed ? .48 : 1`.
  final bool dimmed;

  /// `ds.tsx:434` — `minHeight: 64`.
  static const double minHeight = 64;

  /// `ds.tsx:434` — `padding: '0 16px'`.
  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 16);

  /// `ds.tsx:433` — `borderRadius: 18`. A token: [EvaRadii.card].
  static const double radius = EvaRadii.card;

  /// `ds.tsx:434` — `gap: 14`.
  static const double gap = 14;

  /// The letter badge. `ds.tsx:444` — `width: 30, height: 30, borderRadius: '50%'`.
  static const double badgeSize = 30;

  /// `ds.tsx:445` — `border: '1.5px solid …'`.
  static const double badgeBorderWidth = 1.5;

  /// `ds.tsx:435` — `border: '1.5px solid …'`.
  static const double rimBorderWidth = 1.5;

  /// The letter's size. `ds.tsx:450` — `fontSize: 12`.
  static const double letterFontSize = 12;

  /// The label's size. `ds.tsx:455` — `fontSize: 15`.
  static const double labelFontSize = 15;

  /// `ds.tsx:455` — `lineHeight: 1.4`.
  static const double labelLineHeight = 1.4;

  /// `ds.tsx:438` — `transition: 'all 250ms cubic-bezier(0.16,1,0.3,1)'`.
  ///
  /// **Carried as a constant and not used.** The design system's §13.2 rule is that
  /// the ambient clock drives every animation, and a per-widget `AnimatedContainer`
  /// would be a fourth controller — the exact thing `GoldFlecks`'s doc refuses. So
  /// the state change is instant here, and the only motion on a correct answer is
  /// the flecks'. Recorded rather than deleted, because "the prototype transitions"
  /// is a claim a reader will otherwise make and find false.
  static const int transitionMillis = 250;

  /// `ds.tsx:437` — `opacity: 0.48` when dimmed.
  static const double dimmedOpacity = 0.48;

  /// `ds.tsx:425` — the accent fill is the accent at **0.09**.
  static const double accentFillAlpha = 0.09;

  /// `ds.tsx:426` — the resting border is `#fff | #000` at **0.1**, which is
  /// [EvaColors.glassBorder] on both palettes (`#14FFFFFF` dark, and light's is
  /// measured off `glassBorder` too — `eva_colors.dart` is the authority and this
  /// is not a new token).
  ///
  /// ## AND `ds.tsx:428`'s BADGE BORDER IS **0.18**, WHICH IS **NOT** A TOKEN
  ///
  /// Named here because a reader comparing against `ds.tsx` will look for a
  /// `glassBorder * 1.8` and there is none: the two alphas are separate decisions
  /// in the prototype and this client keeps them separate.
  static const double badgeBorderAlpha = 0.18;

  /// `ds.tsx:440` — `0 0 22px rgba(accent, .22)`.
  static const double accentGlowBlur = 22;
  static const double accentGlowAlpha = 0.22;

  /// `ds.tsx:440` — the inset highlight, `rgba(#ffffff, .06)` with an accent and
  /// `rgba(#ffffff, .04)` without.
  static const double insetHighlightAlpha = 0.06;
  static const double restingInsetHighlightAlpha = 0.04;

  /// `ds.tsx:450` — the letter goes `#ffffff` in the two graded states and
  /// `T.ink` otherwise. `#ffffff` is `EvaColors.canvas` on the dark palette and
  /// **not** on the light one, so the graded letter is [onAccent] rather than a
  /// literal.
  static const double gradedLetterAlpha = 1;

  /// The four flecks' offsets, in logical px from the card's **top-left**.
  ///
  /// ## WHY THIS IS A FUNCTION OF THE WIDTH, AND THE HONEST PART OF THAT
  ///
  /// `QuizScreen.tsx:92-95` writes them as absolute px against one viewport:
  /// `(-10, 12)`, `(-15, 36)`, `(356, 8)`, `(362, 30)`. The left pair is relative to
  /// the card's left edge and transcribes as it stands. **The right pair is not**:
  /// 356 is only "just outside the right edge" at the width the prototype was drawn
  /// at, so copying it puts both flecks in the middle of the card at 430px and off
  /// the end of it at 320px — which is §14's own surface.
  ///
  /// So the right pair is expressed as [width] minus the prototype's own overhang
  /// (`6` for the inner one, `12` for the outer). The **relationship** is
  /// transcribed; the literal is not, and this is the same "a number is a claim
  /// about a specific thing" correction `reading_geometry_test.dart` makes about the
  /// drop cap.
  ///
  /// A pure function rather than four fields, so `quiz_geometry_test.dart` can
  /// assert the right pair sits outside the card at **both** 320 and 430 without
  /// pumping a widget.
  static List<Offset> fleckOffsetsFor(double width) => <Offset>[
    const Offset(-10, 12),
    const Offset(-15, 36),
    // `width + 6` and `width + 12`, **not** `width - 6`. The doc above this method
    // says the right pair hangs *outside* the card — `QuizScreen.tsx:94-95` puts two
    // "just outside the right edge" — and the first draft wrote `width - 6` for the
    // inner one, which put it *inside*.
    //
    // `quiz_option_card_test.dart`'s `the right pair sits outside the card at both
    // §14 and the prototype width` is the assertion that caught it, and it is written
    // as `>= width` rather than `== width` so a future `width - 6` cannot come back.
    Offset(width + 6, 8),
    Offset(width + 12, 30),
  ];

  /// The accent for [state], or `null` for [QuizOptionState.idle]. `ds.tsx:424`.
  static Color? accentFor(QuizOptionState state, EvaColors colors) =>
      switch (state) {
        QuizOptionState.idle => null,
        QuizOptionState.selected => colors.ember,
        QuizOptionState.correct => colors.ok,
        QuizOptionState.incorrect => colors.err,
      };

  /// The ink the letter is drawn in. `ds.tsx:450`.
  static Color letterInkFor(
    QuizOptionState state,
    EvaColors colors,
    Brightness brightness,
  ) => accentFor(state, colors) == null
      ? colors.ink
      : onGradedAccent(colors, brightness);

  /// The letter's ink **on** an accent — `ds.tsx:450`'s `#ffffff`.
  ///
  /// `colors.canvas` on the dark palette and `colors.onEmber` on the light one,
  /// because `#ffffff` is not a token this app publishes on either palette
  /// (`no_colour_literals_test.dart` refuses a literal in `lib/`) and the two
  /// palettes need different answers for it. **`onEmber` rather than `onSurface`**:
  /// the badge sits on `ok` / `err`, not on `surface`, and reusing `onSurface` would
  /// say the contrast was measured against a background it is not on.
  ///
  /// Measured against the shipped palettes: `onEmber` on `ok` is **3.36:1** and on
  /// `err` is **3.49:1** — below AA for 12px text, which is decision 6's shape. The
  /// letter is **decorative**: the option's accessible name already carries the
  /// verdict ([semanticLabel]), and `GoldFlecks` is `ExcludeSemantics`d. So the
  /// sub-AA pairing is recorded here rather than fixed, because fixing it would
  /// mean a 13th colour token in a phase that does not own the palette — the same
  /// trade `eva_colors_test.dart` records for seven other pairs, and the same
  /// reason the answer is not "make the letter bigger".
  static Color onGradedAccent(EvaColors colors, Brightness brightness) =>
      brightness == Brightness.dark ? colors.canvas : colors.onEmber;

  /// Whether [state] is one of the two **graded** states.
  ///
  /// `ds.tsx:427` — `badgeFill = (state === 'correct' || state === 'incorrect')
  /// ? accent : 'transparent'`, and `:450` puts the letter's ink on the same
  /// condition. Two prototype conditions that are one question here, which is
  /// `switch` expression territory per §4.
  static bool isGraded(QuizOptionState state) =>
      state == QuizOptionState.correct || state == QuizOptionState.incorrect;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color? accent = accentFor(state, colors);
    final bool interactive = enabled && onTap != null;

    final Widget surface = Opacity(
      // `ds.tsx:437` — the dimming is on the whole card, including its badge.
      opacity: dimmed ? dimmedOpacity : 1,
      child: Semantics(
        // §14's disabled row, `SocialAuthButton`'s shape: `enabled` is stated,
        // `onTap` is **absent** rather than present-and-flagged, and the name
        // carries the reason (built by `QuizStringsPhrases.optionLabel`).
        button: true,
        enabled: enabled,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: interactive ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // `ds.tsx:425` — accent at 0.09, else the resting tint.
            color: accent == null
                ? colors.glassFill
                : accent.withValues(alpha: accentFillAlpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              // `ds.tsx:426` — the accent, else the resting rim.
              color: accent ?? colors.glassBorder,
              width: rimBorderWidth,
            ),
            boxShadow: <BoxShadow>[
              // `ds.tsx:440` — the accent glow plus an inset highlight. The
              // resting card has the weaker inset only, so the two are the same
              // expression with a different second term rather than two branches.
              if (accent != null)
                BoxShadow(
                  color: accent.withValues(alpha: accentGlowAlpha),
                  blurRadius: accentGlowBlur,
                ),
              BoxShadow(
                color: colors.canvas.withValues(
                  alpha: accent == null
                      ? restingInsetHighlightAlpha
                      : insetHighlightAlpha,
                ),
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              // `ds.tsx:434` — `minHeight: 64`. A constraint and not a `SizedBox`,
              // so a two-line Arabic label at 1.22× grows the card instead of
              // overflowing it — §14's requirement, and the reason this is not
              // transcribed as a fixed height.
              constraints: const BoxConstraints(minHeight: minHeight),
              child: Row(
                children: <Widget>[
                  _Badge(
                    letter: letter,
                    state: state,
                    accent: accent,
                    colors: colors,
                    brightness: Theme.of(context).brightness,
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: Text(
                      text,
                      // `ds.tsx:455` — `F.ui, 15, 400, lineHeight 1.4`.
                      //
                      // **The family is the PAYLOAD arm, not the ambient one.** The
                      // option text is the server's scripture, fetched in the
                      // language the session was opened in, and decision 75's table
                      // says a payload run's arm comes from the payload. So this
                      // takes [language] rather than reading
                      // `Directionality.of(context)` — which is what
                      // `SocialAuthButton`'s `arabicAware` does, correctly, for a
                      // chrome label with no payload behind it.
                      style: optionStyleFor(context, language),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // ## THE TAP HANDLER IS HERE AND IT WAS **MISSING** ON THE FIRST RUN
    //
    // The first version of this widget ended at `Semantics(onTap: onTap)`, which is
    // an **accessibility** action and not a pointer one: the card announced itself as
    // a button and a screen-reader user could press it, while a finger did nothing at
    // all. `quiz_page_test.dart` found it by tapping an option and finding the bloc's
    // `selectedLetter` still `null`.
    //
    // `SocialAuthButton` has the same shape and gets away with it because its
    // `onPressed` is `null` in **every** shipping call site — it ships inert, so no
    // test ever pressed it. That is the interesting half: a widget can be correct
    // about semantics and wrong about touch for a whole phase, because the two are
    // separate mechanisms and only one of them was ever exercised.
    //
    // `EvaInk` inside `EvaFocusRing` for `IconActionButton`'s reason: §14 requires
    // every interactive node to be keyboard-activatable, and `FocusRing`'s idle rim
    // is `null` because this card's **resting** border is already painted by the
    // `DecoratedBox` above — drawing it twice would be the same defect `GlassSurface`
    // records in its own comment.
    if (!interactive) return surface;
    return EvaFocusRing(
      enabled: true,
      idleBorder: null,
      radius: radius,
      child: EvaInk(
        onPressed: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      ),
    );
  }

  /// The option label's [TextStyle] for the arm [language].
  ///
  /// A method on the widget rather than an inline `copyWith`, because
  /// `reading_geometry_test.dart` pins `ScriptureBlock.fontSizeFor` and
  /// `reading_glyph_test.dart` pins its output against the prototype line, and this
  /// is the quiz's equivalent of both — with the **same rule**: a single number in
  /// `ds.tsx` belongs to one screen and is never shared.
  static TextStyle optionStyleFor(
    BuildContext context,
    ReadingLanguage language,
  ) {
    final TextStyle base = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: labelFontSize,
      height: labelLineHeight,
      fontWeight: FontWeight.w400,
      color: context.colors.ink,
    );
    return base.copyWith(
      fontFamily: switch (language) {
        ReadingLanguage.english => EvaTypography.uiFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      },
    );
  }
}

/// The letter badge. `ds.tsx:443-453`.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.letter,
    required this.state,
    required this.accent,
    required this.colors,
    required this.brightness,
  });

  final String letter;
  final QuizOptionState state;
  final Color? accent;
  final EvaColors colors;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final bool graded = QuizOptionCard.isGraded(state);
    return Container(
      width: QuizOptionCard.badgeSize,
      height: QuizOptionCard.badgeSize,
      decoration: BoxDecoration(
        // `ds.tsx:427` — the badge fills only in the two graded states.
        color: graded ? accent : Colors.transparent,
        shape: BoxShape.circle,
        // `ds.tsx:428` — the accent, else `#fff | #000` at 0.18. A **named
        // constant** rather than `glassBorder * 1.8`: the two alphas are separate
        // decisions in `ds.tsx` and this client keeps them separate.
        border: Border.all(
          color:
              accent ??
              colors.ink.withValues(alpha: QuizOptionCard.badgeBorderAlpha),
          width: QuizOptionCard.badgeBorderWidth,
        ),
        // `ds.tsx:447` — `0 0 12px rgba(accent, .55)`, and **only** in the graded
        // states, which is the whole of the condition on that line.
        boxShadow: graded
            ? <BoxShadow>[
                BoxShadow(
                  color: accent!.withValues(alpha: 0.55),
                  blurRadius: 12,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Center(
        child: Text(
          letter,
          // `ds.tsx:450` — `F.mono, 12, 700`.
          style: EvaTypography.monoCaps(colors).copyWith(
            fontSize: QuizOptionCard.letterFontSize,
            fontWeight: FontWeight.w700,
            color: QuizOptionCard.letterInkFor(state, colors, brightness),
          ),
        ),
      ),
    );
  }
}
