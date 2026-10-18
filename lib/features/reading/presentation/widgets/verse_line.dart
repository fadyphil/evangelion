import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/reading/domain/reading_focus.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One verse of `/reading`, painted in one of the prototype's three states.
///
/// `eva/redesign.html:1358-1363` builds the reader's verses, and each is a
/// `<p class="vline">` whose *whole* appearance is three class names:
///
/// ```html
/// // :1360-1362, verbatim
/// p.className='vline'+(i===0&&lang==='en'?' drop':'');
/// p.dataset.i=i; p.dataset.txt=t;
/// p.innerHTML=`<i>${lang==='en'?i+1:['١','٢','٣','٤','٥','٦'][i]}</i> ${t}`;
/// ```
///
/// | enum | CSS | what it is |
/// | --- | --- | --- |
/// | [VersePaint.out] | `.vline` `:162` | `opacity:0`, `translateY(10px)`, `blur(10px)` |
/// | [VersePaint.inView] | `.vline.in` `:164` | `opacity:1`, no transform, no blur |
/// | [VersePaint.hot] | `.vline.hot` `:165` | `--ink-0` at weight 500 with a 26px gold halo |
///
/// ## THE THREE STATES ARE AN **ENUM**, AND THAT IS THE WHOLE POINT
///
/// The redesign's focus mode (`eva/redesign.html:177`) writes
/// `.screen.focus .vline.in{color:#d9dfef}` — a `(0,4,0)` selector that
/// therefore **overrides `.vline.hot`'s colour**, painting a reader's selected
/// verse and a cold one in view the same `#d9dfef`. Measured in the plan that
/// deferred this work: an in-focus distinction of **1.000:1**.
///
/// `plans/2026-10-13-lumen-redesign.md` (Phase 2 Task 2.2 Step 3) records the
/// correction as this task's obligation:
///
/// > focus mode must preserve a ≥3:1 distinction between in-view and
/// > out-of-view verses, never flatten to a single `#d9dfef`
///
/// A widget that took **two booleans** (`hot`, `inView`) could be handed the
/// pair that flattens them and nothing in its signature would object. A widget
/// that takes one value from a three-case enum cannot: there is no value meaning
/// "in view and selected and indistinguishable", because that is a state the
/// prototype reached by an accident of specificity rather than by intent. The
/// switch below is where the obligation is enforced.
///
/// ## THE `blur(10px)` IN `:162` IS **NOT** REPRODUCED, AND THAT IS THE BUDGET
///
/// `:162` gives an unrevealed verse `filter: blur(10px)`. In Flutter that is
/// `ImageFiltered(ImageFilter.blur(10))` — a per-frame `saveLayer` and a
/// read-back **per verse**, six of them, for a 320 ms reveal.
///
/// `glass_blur_budget_test.dart` is the enforcement and it is unambiguous: no
/// `BackdropFilter` and no `ImageFilter.blur` anywhere in `lib/features/`, and
/// the only one in the design system is inside `glass_surface.dart`, "the widget
/// that owns it". §13.4 budgets **one** blurred site in the whole app and `/`
/// spends it on the day's card (`eva/redesign.html:250`).
///
/// So the reveal is **opacity and offset only**. The blur's *reading* — a line
/// arriving out of focus and sharpening — is carried by the opacity ramp from
/// the same rule; what is lost is the soft edge, not the motion.
class VerseLine extends StatelessWidget {
  const VerseLine({
    required this.number,
    required this.text,
    required this.paint,
    this.resume = false,
    super.key,
  });

  /// The verse's position, **1-based**.
  ///
  /// `eva/redesign.html:1361` writes `i+1` on the Latin arm and a zero-based
  /// literal array (`['١','٢',…]`) on the Arabic one. One value for both arms
  /// here, and [context.l10n.digits] is what renders the arm's numeral — which
  /// is also how the prototype's two spellings collapse into one: `digits(4)` is
  /// `4` on the Latin arm and `٤` on the Arabic one, exactly the two branches
  /// `:1361` writes. It is also *better* past nine verses, where the literal
  /// array runs out and the prototype would render `undefined`.
  ///
  /// One-based because [dropCapAppliesFor] is "the first verse", and a
  /// zero-based first verse is `0`, which reads as "no verse" everywhere that has
  /// to decide something about absence.
  final int number;

  /// The verse's text, verbatim from the server.
  ///
  /// **Not a display form.** `Verse.text` is the wire string, and
  /// `scripture_block.dart` — now deleted — recorded why the wire field is the
  /// one to paint.
  final String text;

  /// Which of the three states this line paints in.
  ///
  /// From `features/reading/domain/reading_focus.dart`'s pure-Dart policy, so the
  /// arithmetic that decides it is TDD'd there and is not re-derived here.
  final VersePaint paint;

  /// Whether this is where the reader left off — `eva/redesign.html:168`.
  ///
  /// `.vline.resume{box-shadow:inset 3px 0 0 var(--gold);padding-left:12px;
  /// border-radius:4px}`, and `:169` mirrors the bar to the right under RTL.
  final bool resume;

  /// The body size under LTR. `eva/redesign.html:161` — `font-size: var(--vsize)`,
  /// whose **default** is `20px` (`:19`).
  ///
  /// **The default, and that is the whole caveat.** `--vsize` is mutable state:
  /// `:1395-1398` keeps a `vs` the pill's `A+`/`A−` step over `[16, 26]`, and
  /// `:1369`'s double-click cycles `[18, 22, 26]`. This constant is the
  /// prototype's baseline; the pill does not write a font size, it moves
  /// `fontStep`, and `MediaApp`'s builder installs `evaScalerFor(step)` above the
  /// whole screen. **The two mechanisms the prototype folds into one CSS
  /// variable are two mechanisms here**, and the layout tests read the composed
  /// result rather than this number.
  static const double verseSize = 20;

  /// The body size under RTL. `eva/redesign.html:140` —
  /// `font-size: calc(var(--vsize) + 3px)`, so **23** at the default 20.
  ///
  /// Transcribed rather than derived: `calc()` is not a constant here, and
  /// re-deriving it at each call site is how the two arms would drift apart
  /// silently — which is the failure the Arabic-arms audit recorded four times.
  static const double verseSizeArabic = 23;

  /// The line box under LTR. `eva/redesign.html:161` — `line-height: 1.7`.
  static const double verseHeight = 1.7;

  /// The line box under RTL. `eva/redesign.html:140` — `line-height: 2.1`.
  ///
  /// **2.1 and not an inherited 1.7, because the prototype says so**: `:140`
  /// writes a *different* line-height for the Arabic arm. Amiri's ascenders and
  /// descenders need it, and the arm that carries the most diacritics is the one
  /// with the least room.
  static const double verseHeightArabic = 2.1;

  /// The gap below a line. `eva/redesign.html:161` — `margin-bottom: 14px`.
  ///
  /// **14, and it is not a spacing token.** `EvaSpacing` publishes
  /// 4/8/12/16/20/24/32/40 and nothing between 12 and 16. Naming this
  /// `EvaSpacing.md + 2` would put an arithmetic expression in a layout call
  /// site and read as a decision where the prototype has a literal.
  static const double verseGap = 14;

  /// The numeral's size. `eva/redesign.html:170` — `font-size: 9.5px` on `.vline i`.
  static const double numeralSize = 9.5;

  /// The numeral's side bearing. `eva/redesign.html:170` — `margin: 0 2px`.
  static const double numeralSpacing = 2;

  /// How far an unrevealed line sits below its final place.
  /// `eva/redesign.html:162` — `transform: translateY(10px)`.
  ///
  /// **Pixels and not a fraction of the line's height**, because the rule says
  /// `10px`: against `verseSize * verseHeight` = 34 the same offset would be 29 %
  /// of a line under LTR and 20 % of one under RTL, so a fraction would move the
  /// two arms by different distances from one number.
  static const double entranceOffset = 10;

  /// How long a reveal takes. `eva/redesign.html:163` — `opacity .32s`,
  /// `transform .32s`, `filter .32s`, all on `var(--e-light)`.
  ///
  /// **320 ms, and it is not a motion token.** `EvaMotion` publishes 150/200/250
  /// and `:163` states 320. Rounding a transcribed duration to the nearest token
  /// would make the constant a claim about the table rather than about the
  /// prototype.
  static const Duration entranceDuration = Duration(milliseconds: 320);

  /// The reveal's curve. `eva/redesign.html:18` —
  /// `--e-light: cubic-bezier(.16,1,.3,1)`.
  ///
  /// **`EvaMotion.interactiveCurve` (`Curves.easeOutExpo` =
  /// `Cubic(0.19, 1, 0.22, 1)`), and the two are not the same curve.** They are
  /// the same *shape* — a fast start, a long tail — and every easing control on
  /// the screen uses this token, so a reveal on a different curve would move at a
  /// visibly different rate from the `.pill` it appears under. The difference is
  /// 0.03 on two control points of a cubic; the difference between two curves in
  /// one gesture is what a reader sees.
  static const Curve entranceCurve = EvaMotion.interactiveCurve;

  /// The selected line's halo radius. `eva/redesign.html:165` —
  /// `text-shadow: 0 0 26px rgba(232,176,75,.28)`.
  static const double selectedGlowBlur = 26;

  /// The selected line's halo alpha. `eva/redesign.html:165` —
  /// `rgba(232,176,75,.28)`.
  static const double selectedGlowAlpha = 0.28;

  /// The selected line's weight. `eva/redesign.html:165` — `font-weight: 500`,
  /// over `:162`'s `font-weight: 400`.
  static const FontWeight selectedWeight = FontWeight.w500;

  /// The body weight. `eva/redesign.html:162` — `font-weight: 400`.
  static const FontWeight bodyWeight = FontWeight.w400;

  /// The halo's vertical outset. `eva/redesign.html:166` — `inset:-8px -14px`.
  static const double glowInsetVertical = 8;

  /// The halo's horizontal outset. `eva/redesign.html:166` — the `-14px` half.
  ///
  /// **Wider than it is tall, and that asymmetry is the rule's**: the box is a
  /// halo around a line of text, so it reaches further left and right than up
  /// and down, or it reads as a highlight band rather than a light.
  static const double glowInsetHorizontal = 14;

  /// The halo's corner radius. `eva/redesign.html:166` — `border-radius: 14px`.
  static const double glowRadius = 14;

  /// The halo's centre alpha. `eva/redesign.html:167` —
  /// `rgba(232,176,75,.10)`.
  static const double glowAlpha = 0.10;

  /// The halo's falloff. `eva/redesign.html:167` — `transparent 70%`.
  static const double glowFalloff = 0.7;

  /// The resume bar's thickness. `eva/redesign.html:168` —
  /// `box-shadow: inset 3px 0 0 var(--gold)`.
  static const double resumeBarWidth = 3;

  /// The resume bar's indent. `eva/redesign.html:168` — `padding-left: 12px`.
  static const double resumePadding = 12;

  /// The resume marker's corner radius. `eva/redesign.html:168` —
  /// `border-radius: 4px`.
  static const double resumeRadius = 4;

  /// The drop cap's em size. `eva/redesign.html:172` — `font-size: 56px`.
  ///
  /// **Handed to [PassageDropCap] as an explicit size rather than left to its
  /// `lines` ratio**, because no integer line count produces 56 at this screen's
  /// 20px body: one line gives 51.43 and two give 102.86. That widget's `fontSize`
  /// parameter carries the arithmetic and the two prototypes it now serves.
  static const double dropCapSize = 56;

  /// Whether this line carries the drop cap, given the paragraph's direction.
  ///
  /// **`eva/redesign.html:1360` — `i===0 && lang==='en'`** — the first verse of
  /// the Latin arm only, and `:141` is what makes the second half a rule rather
  /// than a preference: `[dir=rtl] .vline.drop::first-letter{all:unset}`, so the
  /// Arabic arm *builds* the same class and then removes every declaration from
  /// it. An Arabic first letter is not smaller; it is unset.
  ///
  /// **Direction and not a language parameter**, because the prototype's
  /// condition is a *script* condition and the screen's direction already carries
  /// it — `verse_of_the_day_card.dart` records the same decision for the same
  /// reason, and a `TextDirection` is one fewer parameter to keep in step.
  bool dropCapAppliesFor(TextDirection textDirection) =>
      number == 1 && textDirection == TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // The ambient direction, which `MaterialApp` installs from the locale.
    // **Read here and nowhere else**: a getter on this widget would have no
    // `context` to read from, and a field would cache the answer across a locale
    // change — the mistake `reading_page.dart`'s `didChangeDependencies` doc
    // already records for the same inherited read.
    final TextDirection textDirection = Directionality.of(context);

    final TextStyle bodyStyle = _bodyStyle(colors, textDirection);
    final bool selected = paint == VersePaint.hot;

    final Widget paragraph = _HotGlow(
      painted: selected,
      child: RichText(
        // `RichText.textScaler` is **non-nullable** in this SDK, so the ambient
        // value is read here rather than inherited — the same value a `Text` would
        // have resolved, because `EvaTypeScale` installs the reader's step above
        // this widget. `?? TextScaler.noScaling` would be the identity and would
        // make this parameter an opt-out from the reader's own setting.
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(
          style: bodyStyle,
          children: <InlineSpan>[
            if (dropCapAppliesFor(textDirection))
              PassageDropCap(
                letter: text.isEmpty ? '' : text.characters.first,
                color: colors.ember,
                fontSize: dropCapSize,
              ).span(bodyStyle),
            // `:1362` — `<i>${…}</i> ${t}`: the numeral, then **one space**, then
            // the text. The space is the prototype's own separator and not the
            // numeral's sidebearing, so it is a run of its own and
            // [numeralSpacing] is applied as the numeral run's letter spacing.
            TextSpan(
              text: '${context.l10n.digits(number)} ',
              style: _numeralStyle(colors, textDirection),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );

    return _Reveal(
      revealed: paint != VersePaint.out,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: verseGap,
          // `:168`'s `padding-left: 12px`, which `:169` moves to
          // `padding-right` under RTL. **Directional and not a `TextDirection`
          // switch**, because that is what the rule is: the marker indents from
          // the **leading** edge on both arms, and one mechanism for that is
          // better than a switch a second place could contradict.
          start: resume ? resumePadding : 0,
        ),
        child: resume
            ? // The marker, `:168` — as a `Border` rather than a shadow,
              // because `borderRadius` lives on the decoration and an `inset`
              // shadow cannot carry it: 3px inset at radius 4 clips to a sliver
              // at the corners, which is a different mark from the one drawn.
              DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: colors.ember,
                      width: resumeBarWidth,
                    ),
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(resumeRadius),
                  ),
                ),
                child: paragraph,
              )
            : paragraph,
      ),
    );
  }

  /// The paragraph's own style — `:161`, `:162`, `:165`.
  ///
  /// ## THE COLOUR IS A SWITCH AND NOT A BOOLEAN, AND THAT IS THE OBLIGATION
  ///
  /// ```css
  /// .vline    {color:var(--ink-1)}                              /* :161 */
  /// .vline.hot{color:var(--ink-0);font-weight:500;
  ///            text-shadow:0 0 26px rgba(232,176,75,.28)}        /* :165 */
  /// ```
  ///
  /// `--ink-1` is `colors.ink2` and `--ink-0` is `colors.ink`, the mapping
  /// `/`'s cards established when they took `--bh` washes verbatim and every
  /// other colour through a token.
  ///
  /// **The weight is read from [selectedWeight] whenever the line is selected,
  /// not from a second switch arm** — because `:165` sets colour, weight and
  /// shadow together, and splitting them across two switches is how a future
  /// edit ends up with a gold halo around 400-weight text. One `switch` arms all
  /// three or none.
  ///
  /// `:165`'s halo **survives** `:177`'s focus recolour in the prototype — that
  /// rule sets a colour and nothing else — which is the one part of the focus
  /// mode that is worth keeping.
  TextStyle _bodyStyle(EvaColors colors, TextDirection textDirection) {
    final bool selected = paint == VersePaint.hot;

    return EvaTypography.textTheme(colors).bodyLarge!.copyWith(
      fontFamily: textDirection == TextDirection.rtl
          ? EvaTypography.arabicFamily
          : EvaTypography.scriptureFamily,
      fontSize: textDirection == TextDirection.rtl
          ? verseSizeArabic
          : verseSize,
      height: textDirection == TextDirection.rtl
          ? verseHeightArabic
          : verseHeight,
      fontWeight: selected ? selectedWeight : bodyWeight,
      color: selected ? colors.ink : colors.ink2,
      shadows: selected
          ? <Shadow>[
              Shadow(
                color: colors.ember.withValues(alpha: selectedGlowAlpha),
                blurRadius: selectedGlowBlur,
              ),
            ]
          : null,
    );
  }

  /// The numeral's style — `eva/redesign.html:170`.
  ///
  /// ```css
  /// .vline i{font-style:normal;font-family:var(--mono);font-size:9.5px;
  ///           color:var(--ink-2);vertical-align:super;margin:0 2px}
  /// .vline.hot i{color:var(--gold)}
  /// ```
  ///
  /// **`font-style: normal` is load-bearing**: the numeral is rendered from the
  /// same text style as the body, so an inherited italic would have to be
  /// cancelled explicitly, and the rule cancels it.
  ///
  /// ## AND `vertical-align: super` IS **NOT** EXPRESSIBLE, WHICH THE DELETED
  /// ## `scripture_block.dart` ALREADY RECORDED AND THIS INHERITS
  ///
  /// A CSS `super` raises the run off the baseline. A [TextSpan] has no such
  /// property in this SDK, and that file considered the two ways round it and
  /// **rejected both** — a `WidgetSpan` translated upward by a constant sits
  /// lower relative to its line at §14's 1.22× scale than it does at 1.0×, and
  /// "a constant that is right at one scale and wrong at another is worse than
  /// an honest approximation". So the numeral sits **on the baseline one step
  /// smaller**, which is what the previous screen shipped and what its golden
  /// locked.
  ///
  /// [numeralSpacing] is therefore the `<i>`'s two-pixel margin, applied as the
  /// numeral run's letter spacing: a `margin` on an inline box is not expressible
  /// in a [TextSpan], and letter spacing is the only spacing a run has.
  ///
  /// ## AND `arabicAware`, BECAUSE THE NUMERAL IS **ARABIC SCRIPT** ON THAT ARM
  ///
  /// `:1361` writes `['١','٢',…]` on the Arabic arm, and U+0661 is inside the
  /// Arabic block — so a numeral rendered in JetBrains Mono is tofu, measured by
  /// `arabic_typography_test.dart` on the first run of this screen (it rendered
  /// five of them, `١` through `٥`, in the mono face and the gate named every one).
  /// The prototype escapes through the browser's per-character fallback; this
  /// client through `arabicAware`, which is the arrangement `StreakChip` uses for
  /// the same numerals.
  TextStyle _numeralStyle(EvaColors colors, TextDirection textDirection) =>
      arabicAware(
        EvaTypography.textTheme(colors).bodyLarge!.copyWith(
          fontFamily: EvaTypography.monoFamily,
          fontStyle: FontStyle.normal,
          fontSize: numeralSize,
          fontWeight: FontWeight.w400,
          color: paint == VersePaint.hot ? colors.ember : colors.ink3,
          letterSpacing: numeralSpacing,
          height: 1,
        ),
        textDirection,
      );
}

/// The reveal: `:162`'s hidden state and `:164`'s shown one, on `:163`'s curve.
///
/// ## WHY A PRIVATE WIDGET AND NOT TWO IMPLICIT ANIMATIONS IN `build`
///
/// Both work. This one is separate because the *offset* and the *opacity* have
/// to move together from the same `t`: two implicit animations can land a frame
/// apart when the direction flips during a rebuild, and a verse half-faded at
/// its old offset is precisely the visual the entrance exists to avoid.
///
/// **Born at 1 when the line is already revealed** — the calm and
/// reduced-motion branches (`eva/redesign.html:1382`) add `.in` synchronously, and
/// a controller born at 0 would replay the whole stagger on a screen that asked
/// for none of it.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.revealed, required this.child});

  final bool revealed;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: VerseLine.entranceDuration,
    value: widget.revealed ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Forward-only. `:1382-1383` adds `.in` once and nothing in the file removes
    // it, so `revealed` has exactly one transition; a reverse would be a bug.
    if (widget.revealed && !oldWidget.revealed) _controller.forward();
  }

  @override
  void dispose() {
    // Unconditionally, and **not** from a status listener. The first version
    // disposed itself the instant the reveal completed, and then this method read
    // `_controller.isAnimating` on an already-disposed controller — a
    // use-after-dispose that only fires when a line finishes revealing *and* then
    // leaves the tree, which on a scrolled reader is the common case. A completed
    // controller schedules no frames, so holding it until the State goes away
    // costs nothing.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (BuildContext context, Widget? child) {
      final double t = _controller.value;
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, VerseLine.entranceOffset * (1 - t)),
          child: child,
        ),
      );
    },
  );
}

/// The halo `eva/redesign.html:166-167` draws behind a selected line.
///
/// ```css
/// .vline.hot::before{position:absolute;inset:-8px -14px;border-radius:14px;
///                     z-index:-1;
///                     background:radial-gradient(ellipse at 50% 50%,
///                       rgba(232,176,75,.10),transparent 70%)}
/// ```
///
/// **A [CustomPaint] rather than a `Container` with a gradient**, for two reasons
/// that are both about the numbers. `inset:-8px -14px` is a box *larger* than
/// its content on all four sides, which a `Container` cannot express without a
/// negative margin that fights the parent's layout; and `z-index:-1` puts the
/// pseudo-element **behind the paragraph's own text**, which a `decoration:` on
/// the same box cannot do — a decoration paints under the child too, so the glow
/// would wash over the glyphs at `.10` instead of behind them.
///
/// **Painted only when [painted] is true.** `:167`'s gradient is a per-frame
/// saveLayer over the line's box, for the two thirds of readers with no line
/// selected. This repo does not spend layers on states nobody is in.
class _HotGlow extends StatelessWidget {
  const _HotGlow({required this.painted, required this.child});

  final bool painted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!painted) return child;
    return CustomPaint(
      painter: _GlowPainter(color: context.colors.ember),
      // The negative inset expressed as padding. Inside a [CustomPaint] the
      // child's padding grows the painted area by exactly the four numbers
      // `:166` states, and a `Transform` would scale the text along with it.
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: VerseLine.glowInsetVertical,
          horizontal: VerseLine.glowInsetHorizontal,
        ),
        child: child,
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(VerseLine.glowRadius),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: VerseLine.glowAlpha),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, VerseLine.glowFalloff],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.color != color;
}
