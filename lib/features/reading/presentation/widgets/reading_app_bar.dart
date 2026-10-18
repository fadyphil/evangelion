import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The reader's two bars: the title row and the meta row.
///
/// `eva/redesign.html:541-546`:
///
/// ```html
/// <div class="appbar"><div class="abrow">
///   <button class="chev" data-back="home">‹</button>
///   <span class="ttl" id="crumbTitle">Psalms · 1</span>
///   <button class="iconbtn" id="bmBtn" title="bookmark">✦</button>
/// </div></div>
/// <div class="appbar sub" id="crumbMeta" style="padding-top:0">poetry · 6 verses · en</div>
/// ```
///
/// ## THE TITLE IS **ABSOLUTELY** CENTRED, AND THAT IS NOT A DETAIL
///
/// `:144` places `.abrow .ttl` at `position:absolute; left:50%; top:50%;
/// transform:translate(-50%,-50%)` with `max-width:52%` — it is **not** a flex
/// child, so the two buttons cannot push it off centre. The two are not the same
/// width: `.chev` is a 16px glyph in `padding: 4px 6px` (`:149`) and `.iconbtn`
/// is a fixed `30px` box (`:151`), so a `Row` with spacers would centre the
/// title against a pair whose halves differ by about four pixels, and the title
/// would sit off-centre by two — on every screen, at every width, where the
/// prototype's title is exactly centred.
///
/// So the row is a [Stack]: the title centred by the stack's own alignment, the
/// two buttons in a [Row] over it. `max-width: 52%` is a fraction of the
/// **`.abrow` content box**, which is this widget's own width.
///
/// ## THE META ROW TAKES ITS INTENT, NOT ITS INHERITANCE — AND THE DIFFERENCE
/// ## IS DOCUMENTED BECAUSE THE PROTOTYPE'S RULE IS DEAD CSS
///
/// `:146-147` styles `.appbar .sub`, and `:546` writes
/// `class="appbar sub"` on **one element**. A descendant combinator does not
/// match the element carrying both classes, so those two rules — mono,
/// `9.5px`, `.14em`, uppercase, `--ink-1`, `padding: 2px 22px 8px`,
/// `text-align: center` — and `:148`'s Arabic override **never apply to
/// anything in the document**. `grep -n '\.sub'` finds those two rules and the two
/// elements, and no bare `.sub` rule.
///
/// What the browser therefore paints for `#crumbMeta` is inherited: `--ui`
/// (Inter) at `15px`, `line-height:1.6` from `:22`, no tracking, no uppercase,
/// `--ink-0`, and `.appbar`'s `46px 18px 4px` with the inline `padding-top:0`
/// overriding the top.
///
/// **This port takes the intent.** The author wrote a rule for the sub bar, put
/// the class on the element, and the comma was missing; the micro-label in the
/// mono caps the rest of the screen uses is plainly what it was for, and
/// `home_page.dart`'s `monoCapsText` exists for exactly this sentence shape. The
/// inherited 15px Inter is what a reader would see in the prototype and is the
/// thing being corrected, so the divergence is stated here rather than left for
/// a reader to find by comparing the two builds.
///
/// **The inline `padding-top: 0` is honoured**, and it is honoured *against
/// `:142`*, so this row's padding is `0 18px 4px` and not the title row's `46px`
/// — a bare transcription of `.appbar` onto both rows would put 46px of dead
/// space above the meta line.
class ReadingAppBar extends StatelessWidget {
  const ReadingAppBar({
    required this.title,
    required this.meta,
    this.onBack,
    this.onBookmarkToggled,
    this.bookmarked = false,
    super.key,
  });

  /// The crumb title — `eva/redesign.html:1345` writes `bookTitle(b)`.
  final String title;

  /// The meta line, already composed by
  /// `ReadingStringsPhrases.crumbMeta` in `reading_l10n.dart`.
  final String meta;

  /// What the chevron runs. `null` renders it inert, which is the only shape a
  /// screen with no route behind it can honestly offer.
  final VoidCallback? onBack;

  /// What the bookmark button runs. `null` renders it inert.
  final VoidCallback? onBookmarkToggled;

  /// Whether the bookmark is lit — `eva/redesign.html:154`, `.iconbtn.lit`.
  final bool bookmarked;

  /// The title row's padding. `eva/redesign.html:142` — `padding: 46px 18px 4px`.
  ///
  /// **46 is the prototype's safe area** — it clears the phone's status bar and
  /// notch, and this client has no inset to consume because `NeuralScaffold` does
  /// not draw one behind the status bar either. The number is transcribed so the
  /// bar's proportions match; a device with a taller inset gets it from the
  /// window's padding, which `NeuralScaffold` owns.
  static const EdgeInsets titlePadding = EdgeInsets.fromLTRB(18, 46, 18, 4);

  /// The meta row's padding. `:142` with `:546`'s inline `padding-top: 0`.
  static const EdgeInsets metaPadding = EdgeInsets.fromLTRB(18, 0, 18, 4);

  /// The gap between the three title-row children. `eva/redesign.html:143` —
  /// `gap: 10px`.
  static const double rowGap = 10;

  /// The title row's minimum height. `eva/redesign.html:143` — `min-height: 34px`.
  ///
  /// **34 is larger than either child needs** — the 16px chevron's box and the
  /// 30px bookmark both fit inside it — so it is doing the job of a row height
  /// rather than a minimum, and it is what keeps the centred title's position
  /// stable when the two buttons are of different heights.
  static const double rowMinHeight = 34;

  /// The title's size. `eva/redesign.html:144` — `font-size: 15px`, with no
  /// `font-family`, so it inherits `--ui` (Inter).
  static const double titleSize = 15;

  /// The title's weight. `eva/redesign.html:144` — `font-weight: 600`.
  static const FontWeight titleWeight = FontWeight.w600;

  /// The title's tracking. `eva/redesign.html:144` — `letter-spacing: -.01em`,
  /// which is **−0.15px** at [titleSize]. Transcribed as the resolved value and
  /// not as `em`: `TextStyle.letterSpacing` is in logical pixels and a fraction
  /// of the size would re-derive the same number at every call site.
  static const double titleTracking = -0.15;

  /// The title's maximum width, as a fraction of the row.
  /// `eva/redesign.html:144` — `max-width: 52%`.
  static const double titleMaxWidthFraction = 0.52;

  /// The meta line's size. `eva/redesign.html:146` — `font-size: 9.5px`.
  ///
  /// See the class doc for why this rule never applies in the prototype and why
  /// this port applies it anyway.
  static const double metaSize = 9.5;

  /// The meta line's tracking. `eva/redesign.html:146` — `letter-spacing: .14em`,
  /// **1.33px** at [metaSize].
  static const double metaTracking = 1.33;

  /// The chevron's size. `eva/redesign.html:149` — `font-size: 16px`.
  static const double chevronSize = 16;

  /// The chevron's padding. `eva/redesign.html:149` — `padding: 4px 6px`.
  static const EdgeInsets chevronPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 4,
  );

  /// The chevron's pressed scale. `eva/redesign.html:153` — `.iconbtn:active
  /// {transform:scale(.9)}`; `.chev` has its own `:150` hover but inherits the
  /// prototype's shared active rule for icon buttons.
  static const double pressedScale = 0.9;

  /// The bookmark button's box. `eva/redesign.html:151` — `width: 30px;
  /// height: 30px`.
  static const double bookmarkSize = 30;

  /// The bookmark button's corner radius. `eva/redesign.html:151` —
  /// `border-radius: 99px`, which on a 30px box is a circle.
  static const double bookmarkRadius = 99;

  /// The bookmark button's rim. `eva/redesign.html:151` —
  /// `border: 1px solid var(--glass-line)`, and `var(--glass-line)` is
  /// `rgba(255,255,255,.10)` (`:15`), which is `colors.glassBorder`.
  static const double bookmarkBorderWidth = 1;

  /// The bookmark star's size. `eva/redesign.html:151` gives `.iconbtn`
  /// `font-size: 12px`, and `:155`'s `15px` is for an `<svg>` — which the
  /// reader's markup does not contain, because `:544` writes the character `✦`.
  ///
  /// **12 and not 15, and that is the transcription.** The `15px` rule is dead on
  /// this route: there is no `<svg>` inside `.iconbtn` anywhere in `:540-560`.
  /// The glyph the prototype drew was 12px of mono, and it was also **tofu** —
  /// U+2726 is in no bundled family — so the shape is painted at the size the
  /// rule states for the thing that was there.
  static const double bookmarkGlyphSize = 12;

  /// The lit bookmark's glow radius. `eva/redesign.html:154` —
  /// `box-shadow: 0 0 12px rgba(232,176,75,.35)`.
  static const double bookmarkGlowBlur = 12;

  /// The lit bookmark's glow alpha. `eva/redesign.html:154` —
  /// `rgba(232,176,75,.35)`.
  static const double bookmarkGlowAlpha = 0.35;

  /// The lit bookmark's rim alpha. `eva/redesign.html:154` —
  /// `border-color: rgba(232,176,75,.6)`.
  static const double bookmarkLitBorderAlpha = 0.6;

  /// The bookmark's hovered rim alpha. `eva/redesign.html:152` —
  /// `rgba(232,176,75,.5)`.
  static const double bookmarkHoverBorderAlpha = 0.5;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: titlePadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: rowMinHeight),
            // The stack, for the reason the class doc gives: `.ttl` is
            // `position:absolute` at `left:50%`, so it is centred against the
            // **row's** box and not against the two buttons.
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                _Title(text: title),
                Row(
                  children: <Widget>[
                    _IconHit(
                      onPressed: onBack,
                      semanticLabel: context.l10n.readingBack,
                      child: Padding(
                        padding: chevronPadding,
                        child: Text(
                          // U+2039 SINGLE LEFT-POINTING ANGLE QUOTATION MARK,
                          // `eva/redesign.html:542`'s `‹`. **Measured present in
                          // five of the bundled families** including `Inter`, which
                          // is the face this glyph inherits — unlike the reader's
                          // other characters, this one renders.
                          '‹',
                          style: EvaTypography.textTheme(colors).bodyLarge!
                              .copyWith(
                                fontFamily: EvaTypography.uiFamily,
                                fontSize: chevronSize,
                                color: colors.ink2,
                              ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _IconHit(
                      onPressed: onBookmarkToggled,
                      semanticLabel: context.l10n.readingBookmark,
                      child: SizedBox.square(
                        dimension: bookmarkSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: bookmarked
                                  ? colors.ember.withValues(
                                      alpha: bookmarkLitBorderAlpha,
                                    )
                                  : colors.glassBorder,
                              // **No `width`.** `:151` says `1px`, which is
                              // `Border.all`'s default — and the lint that says so
                              // is right that the number is worth keeping somewhere,
                              // so it lives in [bookmarkBorderWidth] with the other
                              // transcribed numbers and the decoration takes the
                              // default it is equal to. A reader comparing the two
                              // numbers finds them the same, which is the point of
                              // the constant.
                            ),
                            // `:154` — `box-shadow: 0 0 12px rgba(232,176,75,.35)`,
                            // and only while lit. A shadow on a decoration cannot
                            // paint *outside* a clip, so this is on the `Container`
                            // rather than on the `BoxDecoration`: the circle's own
                            // shape would clip the glow to the inside.
                            boxShadow: bookmarked
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: colors.ember.withValues(
                                        alpha: bookmarkGlowAlpha,
                                      ),
                                      blurRadius: bookmarkGlowBlur,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: FourPointedStar(
                              size: bookmarkGlyphSize,
                              color: bookmarked ? colors.ember : colors.ink2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: metaPadding,
          child: Text(
            meta,
            // **The ambient direction, and not a `TextAlign`** — `:147` writes
            // `text-align: center` and `:148` writes nothing that would change
            // it, so `TextAlign.center` is the whole of the rule and it is the
            // same on both arms.
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // **`arabicAware`, for the same measured reason as the title** — and
            // `:148` says the same thing in the prototype, in a rule that never
            // applies: `[dir=rtl] .appbar .sub{font-family:var(--ui-ar);
            // letter-spacing:0; text-transform:none; font-size:11px}`. The dead
            // selector is the class doc's subject; the *intent* is unambiguous, and
            // the Arabic arm's crumb is Arabic text in a mono face.
            style: arabicAware(
              EvaTypography.monoCaps(colors).copyWith(
                fontSize: metaSize,
                letterSpacing: metaTracking,
                color: colors.ink2,
              ),
              Directionality.of(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// The title run — `eva/redesign.html:144`, the whole rule.
class _Title extends StatelessWidget {
  const _Title({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(
        // `:144` — `max-width: 52%`, against this row's width. A `Flexible` in a
        // `Row` would measure against the *remaining* space after the buttons,
        // which is a different denominator and a smaller number.
        maxWidth:
            ReadingAppBar.titleMaxWidthFraction *
            MediaQuery.sizeOf(context).width,
      ),
      child: Text(
        text,
        // `:144` — `white-space: nowrap; overflow: hidden;
        // text-overflow: ellipsis; text-align: center`. The ellipsis is what
        // makes the title's box bounded enough for the ellipsis to mean
        // anything: an unbounded title would simply overflow the stack.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        // **`arabicAware`, and the gate measured the tofu.** `:144` names no family
        // for the title, so the prototype inherits `--ui` (Inter) — which carries no
        // Arabic script at all, so its own crumb title (`يوحنا 3: 1-5`) renders as
        // tofu in the browser too, rescued only by that browser's per-character
        // fallback. This client has no fallback, so the Arabic arm reads the title
        // in the Arabic face.
        style: arabicAware(
          EvaTypography.textTheme(colors).bodyLarge!.copyWith(
            fontFamily: EvaTypography.uiFamily,
            fontSize: ReadingAppBar.titleSize,
            fontWeight: ReadingAppBar.titleWeight,
            letterSpacing: ReadingAppBar.titleTracking,
            color: colors.ink,
          ),
          Directionality.of(context),
        ),
      ),
    );
  }
}

/// A tappable box around an icon-shaped child, with the accessible name the
/// control would otherwise lack.
///
/// **A plain [Semantics] and not a button widget**, because the prototype's two
/// are `<button>`s with no label — `:544`'s is `title="bookmark"`, which is a
/// tooltip in a browser and nothing at all to a screen reader. §14 requires a
/// name for every control, so the name comes from the ARB and the tap target
/// comes from the child. The `onTap` is `null` when the control is inert, which
/// is how "inert" is expressed in one place rather than by an `IgnorePointer`
/// that leaves a focusable, activatable node behind.
class _IconHit extends StatelessWidget {
  const _IconHit({
    required this.child,
    required this.semanticLabel,
    required this.onPressed,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    enabled: onPressed != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: child,
    ),
  );
}
