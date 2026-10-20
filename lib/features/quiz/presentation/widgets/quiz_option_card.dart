import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:flutter/material.dart';

/// How one quiz option is drawn. `eva/redesign.html:337-343` — the `.opt` rules.
enum QuizOptionState {
  /// `default` — the resting card: a 1px `--glass-line` rim on a `--glass-fill`
  /// tint. `eva/redesign.html:338-339`.
  idle,

  /// The reader's choice, before it is graded.
  ///
  /// ## WRITTEN, AND THE REDESIGN HAS NO SUCH STATE
  ///
  /// `eva/redesign.html:1423` grades the instant a card is chosen, so the
  /// prototype never shows a picked-but-ungraded card. This client's grade is a
  /// `POST` (§5 trap 10 — no request may be fired on a mis-tap), so choosing and
  /// grading are two presses and the first one needs a face. The treatment is the
  /// app's accent — the same `ember` accent the old prototype's `selected` state
  /// wore — and that is a written state, recorded here rather than smuggled in.
  selected,

  /// `.opt.correct` — `eva/redesign.html:350-352`: a gold-tinted rim and fill,
  /// the key badge filled with the accent and its letter inked dark.
  ///
  /// ## THE HUE IS A SUBSTITUTION, RECORDED
  ///
  /// The prototype's correct treatment is `--gold` (`rgba(232,176,75,…)`) at two
  /// alphas. This design system publishes no gold token, and the orchestrator's
  /// locked decision for this task is that none is created; §5.1's own words
  /// assign `ok`/`err` to "the quiz/feedback semantic pair", so the correct
  /// verdict paints with `ok` and the wrong one with `err`. The alphas below are
  /// the prototype's.
  correct,

  /// `.opt.wrong` — `eva/redesign.html:358-360`: an ember-tinted rim and fill,
  /// the whole card dimmed to 62%, and the shake.
  incorrect,
}

/// One answer option — `eva/redesign.html:337-362`, the `.opt` rules.
///
/// ## THE FOUR STATES AND WHO DECIDES THEM
///
/// The page computes the state, not the component: `QuizPage._optionStateFor` is
/// the only function that can produce [QuizOptionState.correct] or
/// `.incorrect`, it takes the answer's `isChecked` as its gate, and it reads
/// **only** `QuizAnswer.verdict` — never `QuizAnswer.question.isCorrect`. That
/// split is the whole of the spoiler boundary's structure, and
/// `quiz_page_test.dart` plants a leak that renders `is_correct` before the check
/// to prove the boundary holds.
///
/// ## AND `enabled` IS A **SEPARATE FLAG** FROM THE VERDICT'S DIMMING
///
/// The redesign dims the wrong card to 62% (`:358`'s `opacity: .62`) — that is
/// [QuizOptionState.incorrect]'s own treatment, driven by the state. `enabled` is
/// this client's own, and it is §5 trap 3: a question whose wire
/// `already_answered` is `true` must be **disabled**, so the reader is never
/// walked into a `409`. The prototype has no such state — its question is
/// hard-coded and unanswered — so this flag has no prototype line and is recorded
/// here as written.
///
/// *Rejected: expressing "disabled" as `onTap: null` alone.* That is a *behaviour*
/// and not a *statement*: §14's disabled row wants `Semantics(enabled: false)` with
/// the tap action genuinely absent **and the reason in the accessible name**, and
/// `SocialAuthButton`'s doc is the precedent for all three at once.
///
/// ## AND IT **ARRIVES**, AND IT CARRIES THE FLECKS
///
/// Two motions the redesign specifies for `.opt` and this client did not
/// perform, both placed here:
///
/// * the **entrance** — `:340`'s `opacity:0; transform:translateY(16px)` and
///   `:341`'s `.opt.in{opacity:1; transform:none}` — built from
///   [MotionMoment.achievement] through [EvaAnimate], and
/// * the **flecks** on the correct card, from the brief's own rule ("tiny gold
///   flecks floating near the correct option — sparse, 3–4 max",
///   `eva/brief.txt:97`) and the superseded prototype's four of them — at
///   `-10/12`, `-15/36`, `356/8` and `362/30`, with delays of
///   0 / 220 / 110 / 340ms.
///
/// **The redesign's `.opt` paints neither**, and this client's suite used to
/// assert the flecks' absence. The brief's rule is the authority for the
/// ornament, and the placement is what AGENT_CONTEXT's decision 144 is about:
/// a component that is built, tested and never placed is invisible to every
/// assertion that does not look for it on the screen. Both are recorded at
/// their call sites — the entrance in [_QuizOptionCardState.build] and the
/// flecks in [goldFleckOffsetsFor].
class QuizOptionCard extends StatefulWidget {
  /// An option showing [letter] and [text] in [state].
  const QuizOptionCard({
    required this.letter,
    required this.text,
    required this.state,
    required this.semanticLabel,
    required this.language,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  /// The option's key in `Question.options` — `A`…`D` on the live payload.
  ///
  /// §5 trap 10 records that the ids in this payload are fabricated, and the
  /// letters come from the same JSON, so the badge is drawn **verbatim** — no
  /// substitution to a canonical alphabet.
  final String letter;

  /// The option's label. `eva/redesign.html:344` renders it in the card's own
  /// 15px/500 with `overflow-wrap: anywhere`.
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
  /// here would render Arabic options in the Latin UI face on the Arabic arm —
  /// which is what `reading_glyph_test.dart` measures on `/reading`, and the reason
  /// a screen that is rebuilt under Phase 9's language switch cannot desynchronise
  /// its scripture from its chrome.
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
  /// See the class doc: this is the §5 trap 3 prevention, and it is **not** the
  /// same thing as a verdict's dimming.
  final bool enabled;

  /// The card's own box: `eva/redesign.html:339` — `padding: 16px 18px`.
  ///
  /// **No `min-height` any more.** The old card carried `minHeight: 64` from the
  /// superseded prototype's `QuizOption`; the redesign's `.opt` has none, and its
  /// height is the padding plus the text's line box — 53px for one line, which is
  /// above the 44px touch floor, so the floor is met by the card's own content.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  /// `eva/redesign.html:339` — `border-radius: 18`. A token: [EvaRadii.card].
  static const double radius = EvaRadii.card;

  /// `eva/redesign.html:338` — `gap: 14`.
  static const double gap = 14;

  /// The letter badge. `eva/redesign.html:342` — 26×26, radius 50%, 1px
  /// `--glass-line` rim.
  static const double badgeSize = 26;

  /// `eva/redesign.html:342` — `border: 1px solid var(--glass-line)` — and the
  /// card's own rim is `1px` on `:338` as well, where the old prototype drew both
  /// at 1.5px.
  static const double borderWidth = 1;

  /// The badge letter's size. `eva/redesign.html:342` — `font-size: 10px`, with no
  /// weight declaration, so the family's regular weight.
  static const double badgeFontSize = 10;

  /// The label's size. `eva/redesign.html:341` — `font-size: 15px`,
  /// `font-weight: 500`.
  static const double labelFontSize = 15;

  /// `eva/redesign.html:341` — `font-weight: 500` — **raised from the old
  /// transcription's 400**, which read the superseded prototype's `QuizOption`
  /// label.
  static const FontWeight labelWeight = FontWeight.w500;

  /// `.opt.wrong`'s dimming. `eva/redesign.html:358` — `opacity: .62`, on the
  /// whole card.
  static const double wrongOpacity = 0.62;

  /// The correct card's alphas. `eva/redesign.html:350` — border
  /// `rgba(232,176,75,.75)`, background `rgba(232,176,75,.10)` — with `ok`
  /// substituted for the gold, per [QuizOptionState.correct]'s doc.
  static const double correctBorderAlpha = 0.75;
  static const double correctFillAlpha = 0.10;

  /// The wrong card's alphas. `eva/redesign.html:358` — border
  /// `rgba(255,90,72,.6)`, background `rgba(255,90,72,.07)` — and these are
  /// `--ember`'s own numbers, which `err` already is.
  static const double wrongBorderAlpha = 0.6;
  static const double wrongFillAlpha = 0.07;

  /// The selected card's fill alpha — the app's own state, carried over from the
  /// old card's `accentFillAlpha` so a selection does not invent a new treatment
  /// decision.
  static const double selectedFillAlpha = 0.09;

  /// The verdict glyph's size.
  ///
  /// `EvaSpacing.xxl` (24) — beside the text, at the row's scale. **No prototype
  /// number**: the prototype's verdict shape is the *key badge* recolouring, and
  /// this glyph is decision 127's — §14's "pair the colour with an icon" row, which
  /// the badge's colour change alone does not satisfy for the two non-verdict
  /// cards beside it. The card's own box is governed by its padding, so the glyph
  /// cannot grow the row beyond the text's line box.
  static const double verdictGlyphSize = EvaSpacing.xxl;

  /// The glyph for a graded verdict, or `null` — see the call site.
  ///
  /// **A method rather than two constants inline**, for `reading_geometry_test.dart`'s
  /// argument: the redesign carries no icon here to transcribe — `:350-360` paint
  /// only the border, the fill, the dimming and the shake — so both glyphs are
  /// **written**, and written as *shapes* rather than as colours for the reason in
  /// the call site's comment. A method also keeps this widget's vocabulary of verdicts in one
  /// exhaustive `switch` over the enum, so a fifth state is a compile error here
  /// rather than a missing glyph at runtime.
  ///
  /// `Icons.cancel_outlined` for the wrong answer rather than `Icons.close`, because a
  /// bare `×` reads as "dismiss this card" and this card dismisses nothing.
  static IconData? verdictGlyphFor(QuizOptionState state) => switch (state) {
    QuizOptionState.correct => Icons.check_circle_outline,
    QuizOptionState.incorrect => Icons.cancel_outlined,
    QuizOptionState.idle || QuizOptionState.selected => null,
  };

  /// The accent for [state], or `null` for [QuizOptionState.idle].
  ///
  /// `eva/redesign.html:350/358` name two accent hues — gold for correct, ember
  /// for wrong — and `ok`/`err` are the tokens this design system publishes for
  /// that pair ([QuizOptionState.correct]'s doc carries the substitution). The
  /// **selected** state has no prototype line at all and keeps the app's accent.
  static Color? accentFor(QuizOptionState state, EvaColors colors) =>
      switch (state) {
        QuizOptionState.idle => null,
        QuizOptionState.selected => colors.ember,
        QuizOptionState.correct => colors.ok,
        QuizOptionState.incorrect => colors.err,
      };

  /// The ink the badge letter is drawn in.
  ///
  /// `eva/redesign.html:342` — `--ink-2` at rest; `:352` — `#1c1608` on the
  /// correct badge's fill; `:359` — `var(--ember)` on the wrong one. `#1c1608` is
  /// not a token this app publishes, and the pairing it names is "a dark ink on
  /// the accent fill", which is [onGradedAccent]'s job — the same pairing the old
  /// card recorded, with the same measured cost.
  static Color letterInkFor(
    QuizOptionState state,
    EvaColors colors,
    Brightness brightness,
  ) => switch (state) {
    QuizOptionState.correct ||
    QuizOptionState.incorrect => onGradedAccent(colors, brightness),
    QuizOptionState.idle || QuizOptionState.selected => colors.ink2,
  };

  /// The letter's ink **on** a graded accent.
  ///
  /// `colors.canvas` on the dark palette and `colors.onEmber` on the light one,
  /// because `#ffffff` is not a token this app publishes on either palette
  /// (`no_colour_literals_test.dart` refuses a literal in `lib/`) and the two
  /// palettes need different answers for it. **`onEmber` rather than `onSurface`**:
  /// the badge sits on `ok` / `err`, not on `surface`, and reusing `onSurface` would
  /// say the contrast was measured against a background it is not on.
  ///
  /// Measured against the shipped palettes: `onEmber` on `ok` is **3.36:1** and on
  /// `err` is **3.49:1** — below AA for 10px text, which is decision 6's shape. The
  /// letter is **decorative**: the option's accessible name already carries the
  /// verdict ([semanticLabel]), and §14's shape row is met by the verdict glyph
  /// beside the text. So the sub-AA pairing is recorded here rather than fixed,
  /// because fixing it would mean a 13th colour token in a phase that does not own
  /// the palette — the same trade `eva_colors_test.dart` records for seven other
  /// pairs.
  static Color onGradedAccent(EvaColors colors, Brightness brightness) =>
      brightness == Brightness.dark ? colors.canvas : colors.onEmber;

  /// Whether [state] is one of the two **graded** states.
  ///
  /// `eva/redesign.html:350-359` — the two treatments the reader can tell apart
  /// from the resting card. Two prototype conditions that are one question here,
  /// which is `switch` expression territory per §4.
  static bool isGraded(QuizOptionState state) =>
      state == QuizOptionState.correct || state == QuizOptionState.incorrect;

  /// ## THE FLECK OFFSETS, AND WHY THEY ARE **DERIVED** RATHER THAN PASTED
  ///
  /// The brief's own rule is "tiny gold flecks floating near the correct option
  /// — sparse, 3–4 max" (`eva/brief.txt:97`, and `:114` for "gold flecks fade
  /// in with 150ms delay"), and the superseded prototype drew them at four
  /// positions:
  ///
  /// ```html
  /// <GoldFleck x={-10} y={12}  delay={0}   />
  /// <GoldFleck x={-15} y={36}  delay={220} />
  /// <GoldFleck x={356} y={8}   delay={110} />
  /// <GoldFleck x={362} y={30}  delay={340} />
  /// ```
  ///
  /// Those `x` values are measured **from the option card's own box** — the
  /// superseded prototype's wrapper was a `<div style={{position:'relative'}}>` —
  /// and two of the four are **screen pixels on a 390px frame** — the
  /// prototype's phone frame was `width: 390`:
  ///
  /// * `-10` and `-15` are already card-relative: they are negative, so they
  ///   sit just **outside** the card's left edge, and they do not move when the
  ///   card's width does;
  /// * `356` and `362` are not. The superseded quiz screen's own padding was
  ///   `20px 20px 28px`, so the card's box is
  ///   `390 - 20 - 20 = 350` wide — and `356` and `362` are therefore **6 and
  ///   12 pixels past the card's right edge**.
  ///
  /// **The card's width is not 350 here.** The redesign's `.opt` is `width:100%`
  /// (`eva/redesign.html:337`) inside a body padded `0 26px` (`:333`), so it is
  /// as wide as the screen allows. Pasting `356` and `362` would put the
  /// right-hand pair in the wrong place on every screen but a 390px one, and
  /// off the edge entirely on a narrower one. So the right-hand pair is
  /// **derived from the card's own width** and the left-hand pair is not.
  ///
  /// **The `y` values are the prototype's own, in pixels from the card's top
  /// edge**, and they are not scaled by the card's height: the superseded
  /// prototype's card is 64 tall (`minHeight: 64`) and the redesign's `.opt`
  /// declares no height at all, so a proportional reading would scatter the
  /// cluster over a tall card instead of keeping it near the top corner where
  /// the prototype put it. All four land inside the card, whose height is at
  /// least the badge's 26 plus the padding's 32.
  ///
  /// The four are in the prototype's **order**, because the order is the
  /// stagger: `GoldFlecks` spreads the phases by index, and the prototype's
  /// own delays (0 / 220 / 110 / 340) are not monotonic in the list.
  static List<Offset> goldFleckOffsetsFor(double cardWidth) => <Offset>[
    const Offset(-10, 12),
    const Offset(-15, 36),
    Offset(cardWidth + 6, 8),
    Offset(cardWidth + 12, 30),
  ];

  /// How far an arriving card starts below its final place.
  ///
  /// `eva/redesign.html:340` — `transform: translateY(16px)`, on the `.opt`
  /// rule that opens with `opacity:0`.
  ///
  /// **Pixels, and not a fraction of the card's height**, for the reason
  /// `VerseLine.entranceOffset` records: the same 16px is a quarter of a
  /// one-line card and a tenth of a five-line one, so a fraction would move
  /// the two by different distances.
  static const double entranceOffset = 16;

  @override
  State<QuizOptionCard> createState() => _QuizOptionCardState();

  /// The option label's [TextStyle] for the arm [language].
  ///
  /// A method on the widget rather than an inline `copyWith`, because
  /// `reading_geometry_test.dart` pins `ScriptureBlock.fontSizeFor` and
  /// `reading_glyph_test.dart` pins its output against the prototype line, and this
  /// is the quiz's equivalent of both — with the **same rule**: a single number in
  /// the prototype belongs to one screen and is never shared.
  static TextStyle optionStyleFor(
    BuildContext context,
    ReadingLanguage language,
  ) {
    final TextStyle base = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: QuizOptionCard.labelFontSize,
      fontWeight: QuizOptionCard.labelWeight,
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

/// The card's state, and the one reason it exists: the shake.
///
/// ## WHY THE SHAKE LIVES HERE AND NOT ON THE PAGE
///
/// `.opt.wrong` runs `shake .45s` (`eva/redesign.html:360`) on the card that was
/// just graded wrong. The transition happens **to this widget's [QuizOptionCard.state]**,
/// so the trigger is `didUpdateWidget` — the same arrangement `/login`'s form uses
/// for its `.cta.err` shake, which is where the curve came from. One controller per
/// card, and three of the four never run it: a ticker with no animation costs
/// nothing.
class _QuizOptionCardState extends State<QuizOptionCard>
    with SingleTickerProviderStateMixin {
  /// The shake's clock, and why it is `late final`.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: EvaShake.duration,
  );

  /// The promoted curve — the design system's own, shared with `/login`'s
  /// `.cta.err`.
  final EvaShake _shakeCurve = const EvaShake();

  @override
  void didUpdateWidget(QuizOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasWrong = oldWidget.state == QuizOptionState.incorrect;
    final bool isWrong = widget.state == QuizOptionState.incorrect;
    if (isWrong && !wasWrong) _playShake();
    if (!isWrong && _shake.isAnimating) _shake.stop();
  }

  /// `.opt.wrong`'s shake, §14-aware.
  ///
  /// "When disabled, jump straight to the end state" — and the end state of a
  /// shake **is** its rest position (`transform(1.0) == 0`), so under reduced
  /// motion the card simply never leaves it. The reset before replay is what makes
  /// a second wrong grade shake again instead of continuing a finished clock.
  void _playShake() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _shake
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color? accent = QuizOptionCard.accentFor(widget.state, colors);
    final bool interactive = widget.enabled && widget.onTap != null;

    // ## THE `Semantics` IS **ABOVE** `EvaFocusRing`, AND IT WAS NOT
    //
    // The first version nested it *inside* — `Semantics(…) > DecoratedBox`, with
    // `EvaFocusRing > EvaInk` wrapping that. Measured on the pumped tree, the result
    // was **two tappable nodes per card**, one of them unnamed:
    //
    // ```text
    // lbl="A. Nicodemus"  acts=[tap]              <- the Semantics
    // lbl=""              acts=[tap, focus]        <- the InkWell, and it has no name
    // ```
    //
    // `excludeSemantics: true` drops a node's **descendants**, never its ancestors, so
    // it could not reach the `InkWell` above it. And `Semantics(button: true)` forms
    // a boundary, so the `InkWell` could not merge the labelled node up into itself
    // either — leaving an unnamed activatable node per option, which is §14's first
    // row verbatim and the thing a screen-reader user meets *before* the one that is
    // named. A sweep over `/quiz`'s tree is what found it; no existing assertion on
    // this widget looked at the whole tree, and `quiz_option_card_test.dart`'s own
    // comment had already recorded that "`EvaFocusRing` and `EvaInk` add nodes of
    // their own" without following it anywhere.
    //
    // Hoisting the `Semantics` above the ring makes `excludeSemantics: true` mean what
    // it says — one node, carrying the name, the `enabled` flag and the tap action —
    // while `EvaInk`'s **focus** node is untouched, because focus and semantics are
    // separate mechanisms and `focus_ring_gate_test.dart` still sees its Tab stop.
    final Widget surface = Opacity(
      // `eva/redesign.html:358` — the wrong card dims to .62. The two
      // non-wrong states render at full opacity: the redesign dims nothing
      // else, and the old card's separate `dimmed` flag died with the
      // prototype that wrote it.
      opacity: widget.state == QuizOptionState.incorrect
          ? QuizOptionCard.wrongOpacity
          : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // `eva/redesign.html:338-350-358` — a `--glass-fill` tint at rest;
          // the accent's own alpha when graded.
          color: switch (widget.state) {
            QuizOptionState.idle => colors.glassFill,
            QuizOptionState.selected => accent!.withValues(
              alpha: QuizOptionCard.selectedFillAlpha,
            ),
            QuizOptionState.correct => accent!.withValues(
              alpha: QuizOptionCard.correctFillAlpha,
            ),
            QuizOptionState.incorrect => accent!.withValues(
              alpha: QuizOptionCard.wrongFillAlpha,
            ),
          },
          borderRadius: BorderRadius.circular(QuizOptionCard.radius),
          border: Border.all(
            // `eva/redesign.html:338` — `--glass-line` at rest; `:350` the
            // accent at .75 when correct; `:358` the accent at .6 when wrong.
            // The selected state keeps the full accent, which is the old
            // card's written treatment for a written state.
            color: switch (widget.state) {
              QuizOptionState.idle => colors.glassBorder,
              QuizOptionState.selected => accent!,
              QuizOptionState.correct => accent!.withValues(
                alpha: QuizOptionCard.correctBorderAlpha,
              ),
              QuizOptionState.incorrect => accent!.withValues(
                alpha: QuizOptionCard.wrongBorderAlpha,
              ),
            },
          ),
        ),
        child: Padding(
          padding: QuizOptionCard.padding,
          child: Row(
            children: <Widget>[
              _Badge(
                letter: widget.letter,
                state: widget.state,
                accent: accent,
                colors: colors,
                brightness: Theme.of(context).brightness,
              ),
              const SizedBox(width: QuizOptionCard.gap),
              Expanded(
                child: Text(
                  widget.text,
                  // `eva/redesign.html:341` — 15px, weight 500, `--ink-0`,
                  // `overflow-wrap: anywhere`.
                  //
                  // **The family is the PAYLOAD arm, not the ambient one.** The
                  // option text is the server's scripture, fetched in the
                  // language the session was opened in, and decision 75's table
                  // says a payload run's arm comes from the payload. So this
                  // takes `widget.language` rather than reading
                  // `Directionality.of(context)`.
                  style: QuizOptionCard.optionStyleFor(
                    context,
                    widget.language,
                  ),
                ),
              ),
              // ## §14'S "PAIR THE COLOUR WITH AN ICON", WHICH DECISION 127 SHIPPED
              //
              // The **semantics label** half lives in the accessible name
              // (`quizCorrectSuffix` / `quizIncorrectSuffix`, composed by
              // `AppLocalizations.optionLabel`), and `quiz_page_test.dart` holds
              // it. The **icon** half is this: derived from [QuizOptionCard.state],
              // which is what makes it spoiler-safe — `state` is this widget's own
              // field and nothing else, so the glyph can appear only where the
              // accent already appears; and `quiz_page_test.dart`'s "the widget
              // tree carries nothing that says which option is right" asserts
              // every card is `idle` from that one field, so a leak would have to
              // change `state` first and would be caught there before it could
              // reach an icon.
              if (QuizOptionCard.verdictGlyphFor(widget.state)
                  case final IconData glyph) ...<Widget>[
                const SizedBox(width: QuizOptionCard.gap),
                Icon(
                  glyph,
                  size: QuizOptionCard.verdictGlyphSize,
                  color: accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // ## THE FLECK OVERLAY, AND WHY IT IS AN **OVERLAY**
    //
    // The prototype's flecks are `position: absolute` inside the relative
    // wrapper around the card, and two of the four sit **outside** the card's
    // left edge. So they cannot be a child in the flow: they are painted over
    // the card and past its edge, and they contribute nothing to its size.
    //
    // `StackFit.passthrough` is what keeps the card's own layout untouched —
    // it hands the non-positioned child the **incoming constraints unchanged**,
    // where the default `StackFit.loose` would loosen them and let a `Row`
    // with an `Expanded` child size itself differently. `Clip.none` is what
    // lets the flecks leave the card's box at all: `Stack`'s default
    // `clipBehavior` is `Clip.hardEdge`, which would cut off the very two
    // flecks the prototype put outside the edge.
    final Widget decorated = widget.state == QuizOptionState.correct
        ? Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: <Widget>[
              surface,
              // `Positioned.fill` gives the overlay the card's own box, and
              // the `LayoutBuilder` inside it reads that box's **width** — the
              // number the two right-hand flecks are derived from. The
              // `LayoutBuilder` is inside the `Positioned` rather than outside
              // it because that is what makes its constraints the card's
              // *exact* size rather than the space the card was offered.
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      GoldFlecks(
                        offsets: QuizOptionCard.goldFleckOffsetsFor(
                          constraints.maxWidth,
                        ),
                      ),
                ),
              ),
            ],
          )
        : surface;

    final Widget shaken = AnimatedBuilder(
      animation: _shake,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        // The curve's value IS an x offset in logical px — see `EvaShake`'s doc.
        offset: Offset(_shakeCurve.transform(_shake.value), 0),
        child: child,
      ),
      child: decorated,
    );

    // ## THE TAP HANDLER IS HERE AND IT WAS **MISSING** ON THE FIRST RUN
    //
    // The first version of this widget ended at `Semantics(onTap: onTap)`, which is
    // an **accessibility** action and not a pointer one: the card announced itself as
    // a button and a screen-reader user could press it, while a finger did nothing at
    // all. `quiz_page_test.dart` found it by tapping an option and finding the bloc's
    // `selectedLetter` still `null`.
    //
    // `EvaInk` inside `EvaFocusRing` for `IconActionButton`'s reason: §14 requires
    // every interactive node to be keyboard-activatable, and `FocusRing`'s idle rim
    // is `null` because this card's **resting** border is already painted by the
    // `DecoratedBox` above — drawing it twice would be the same defect `GlassSurface`
    // records in its own comment.
    final Widget pressable = interactive
        ? EvaFocusRing(
            radius: QuizOptionCard.radius,
            // `enabled` and `idleBorder` are both left at their defaults: `true`
            // and `null`. `null` because this card's **resting** border is already
            // painted by the `DecoratedBox` above.
            child: EvaInk(
              onPressed: widget.onTap,
              borderRadius: BorderRadius.circular(QuizOptionCard.radius),
              child: shaken,
            ),
          )
        : shaken;

    // ## THE CARD'S ENTRANCE, AND WHY IT SITS **INSIDE** THE `Semantics`
    //
    // `eva/redesign.html:340` — `.opt` opens with `opacity:0;
    // transform:translateY(16px)` — and `:341` — `.opt.in{opacity:1;
    // transform:none}`. The prototype adds `.in` to a **rebuilt** options box
    // (`eva/redesign.html:1422`: `[...box.children].forEach((o,i)=>setTimeout(
    // ()=>o.classList.add('in'),(reduceMotion?0:120+i*40)))`), so the cards
    // arrive with the question.
    //
    // **The `Semantics` is ABOVE the animation, and that is the whole of §14
    // here.** `RenderAnimatedOpacity` drops the semantics of a fully
    // transparent subtree (`RenderAnimatedOpacityMixin.visitChildrenForSemantics`
    // skips the child while the alpha is 0), so a fade that enclosed the
    // card's `Semantics` would leave an interactive control with **no
    // accessible name** for the length of the entrance. Above it, the card's
    // own node — its name, its `enabled` flag and its tap action — survives
    // the whole animation, and the subtree below is excluded by
    // `excludeSemantics` anyway.
    //
    // ## THE TRIGGER IS THE OPTION'S **TEXT**, AND THAT IS A LIMITATION
    //
    // The prototype replays the entrance on every question because it rebuilds
    // the DOM. This client's option cards are **reused**: the quiz page lays
    // them out as the unkeyed children of one `Column`
    // (`lib/features/quiz/presentation/pages/quiz_page.dart`), so advancing to
    // the next question hands the same elements new text rather than new
    // elements. The trigger is therefore the option's own text: it changes
    // exactly when the card's content changes, and it does **not** change when
    // the card is graded — the verdict changes the card's `state` and its
    // `semanticLabel`, and an entrance that replayed on grading would throw
    // the reader's own answer away.
    //
    // **The limitation is recorded rather than hidden:** two consecutive
    // questions that share an option's text would leave that one card
    // un-replayed, because the card does not know its question's id and the
    // page that does is not this widget's to change. Every other card in the
    // same question would still arrive.
    final Widget arriving = EvaAnimate(
      // `MotionMoment.achievement` is the only member of the enum on
      // `Curves.easeOutBack`, and `--e-spring` — the curve `.opt`'s own
      // transition names (`eva/redesign.html:340`) — is
      // `cubic-bezier(.34,1.56,.64,1)` (`eva/redesign.html:18`), which is that
      // curve verbatim. The **344ms** is the moment's measured settle against
      // the prototype's **300ms**, and the divergence is the price of the
      // enum's closed set: a caller cannot choose a duration.
      effects: MotionMoment.achievement.entrance(
        const Offset(0, QuizOptionCard.entranceOffset),
      ),
      trigger: widget.text,
      child: pressable,
    );

    return Semantics(
      // §14's disabled row, `SocialAuthButton`'s shape: `enabled` is stated,
      // `onTap` is **absent** rather than present-and-flagged, and the name
      // carries the reason (built by `AppLocalizations.optionLabel`).
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      // The whole point of the hoist: this drops the card's **entire** subtree — the
      // badge, the option text, and the ring's and the ink's own nodes — so the one
      // node that survives is the one with the name on it.
      excludeSemantics: true,
      onTap: interactive ? widget.onTap : null,
      child: arriving,
    );
  }
}

/// The letter badge. `eva/redesign.html:342-343` and its two verdict overrides.
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
    final bool filled = state == QuizOptionState.correct;
    return Container(
      width: QuizOptionCard.badgeSize,
      height: QuizOptionCard.badgeSize,
      decoration: BoxDecoration(
        // `eva/redesign.html:352` — the badge fills **only** on the correct card
        // (`background: var(--gold)`); the wrong card's badge keeps its resting
        // face and takes an accent rim and ink instead (`:359`), and the resting
        // badge declares no background at all (`:342`). `ok` stands in for the
        // gold, per `QuizOptionState.correct`'s doc.
        color: filled ? accent! : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: switch (state) {
            QuizOptionState.idle ||
            QuizOptionState.selected => colors.glassBorder,
            // `:359` — `border-color: var(--ember)` on the wrong badge.
            QuizOptionState.incorrect => accent!,
            // `:352` — `border-color: var(--gold)` on the filled badge.
            QuizOptionState.correct => accent!,
          },
        ),
      ),
      child: Center(
        child: Text(
          letter,
          // `eva/redesign.html:342` — mono, 10px, `--ink-2` at rest.
          style: EvaTypography.monoCaps(colors).copyWith(
            fontSize: QuizOptionCard.badgeFontSize,
            color: QuizOptionCard.letterInkFor(state, colors, brightness),
          ),
        ),
      ),
    );
  }
}
