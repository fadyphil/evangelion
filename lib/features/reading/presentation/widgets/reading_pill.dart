import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The reader's control pill — `eva/redesign.html:549-559`.
///
/// ```html
/// <div class="pill" id="pill">
///   <button class="pbtn" id="fMinus">A−</button>
///   <button class="pbtn" id="fPlus">A+</button>
///   <span style="flex:1"></span>
///   <div class="segp langsm" id="langSeg"><span class="thumb"></span>
///     <button class="on" data-l="en">EN</button><button data-l="ar">ع</button>
///   </div>
///   <span style="flex:1"></span>
///   <span class="wave"><i></i><i></i><i></i><i></i></span>
///   <button class="pbtn" id="listen" data-i18n="listen">listen</button>
/// </div>
/// ```
///
/// ## THE PILL'S `blur(18px)` IS **NOT** REPRODUCED, AND THAT IS THE BUDGET
///
/// `:193` gives `.pill` `backdrop-filter: blur(18px)` — the prototype's **second**
/// blurred surface, after the day's card on `/` (`eva/redesign.html:250`).
///
/// §13.4 budgets **one** of the eight prototype blur sites, and
/// `glass_blur_budget_test.dart` enforces `lib/features/` at **one**
/// `GlassTier.blur`. `/` spends it. So this pill is a translucent fill over the
/// sky with a hairline rim, not a read-back: the *look* of a glass pill survives
/// (`rgba(10,12,22,.72)` over the witness sky is what carries it), and what is
/// given up is the blur of the verse text behind it.
///
/// **Recorded rather than silently dropped**, because a reader comparing the two
/// builds can see it: the pill's edge is sharper here, and the verses behind it
/// are not softened by the frosted band the browser draws. If the budget is ever
/// re-argued, this file is where the second site's numbers already are.
///
/// ## THE TWO BARE `<span style="flex:1">` SPACERS ARE STRUCTURAL
///
/// `:552` and `:556` are inline-styled spacers with no class, so **no CSS
/// selector in the file can see them** — they are the only thing distributing the
/// pill's contents across its 310px content box, and they are what centres the
/// language control between the two groups. They are transcribed as two
/// [Expanded] gaps, because dropping them collapses that control from the middle
/// of the pill to hard against the `A+` button.
///
/// ## THE `.wave` IS **NOT** BUILT, AND THE `listen` BUTTON SHIPS INERT
///
/// `:557`'s four `<i>` bars are `display: none` until an ancestor carries
/// `.playing` (`:201`), and the only thing that toggles that class is `:1399` —
/// `el('listen').onclick = function(){ el('pill').classList.toggle('playing');
/// haptic(10) }`. **There is no audio anywhere in the prototype**: `grep` for
/// `speechSynthesis`, `AudioContext`, `new Audio` and `.play()` over all 1537
/// lines returns nothing. The button starts no sound; it reveals a decorative
/// animation.
///
/// So this client ships the control with its prototype's own word, **inert**, and
/// the accessible name carries the reason (`ReadingStringsPhrases
/// .listeningUnavailable`) — the arrangement `/login`'s ghost pills and `/`'s
/// SealFab items already use. And the wave itself is **not** built: an inert
/// control never reaches `.playing`, so a wave widget would be built, tested and
/// **never reachable from a page**, which is exactly what
/// `tool/gates/orphan_widget_check.py` exists to catch. It arrives with audio.
///
/// `:50` also kills the bars under reduced motion (`.screen.rm .wave i{animation:
/// none!important}`), which would have left a 14px empty box inside the pill — a
/// layout shift for an animation nothing was playing.
class ReadingPill extends StatelessWidget {
  const ReadingPill({
    required this.fontStep,
    required this.onFontStepChanged,
    required this.language,
    required this.onLanguageChanged,
    this.onListen,
    super.key,
  });

  /// The reader's font step, read back out of the installed scaler — see
  /// `reading_page.dart`'s `_fontStep` getter for why it is not held here.
  final int fontStep;

  /// Reports a new step. Goes through `SettingsHandle.setFontStep`, which clamps
  /// and persists it.
  final ValueChanged<int> onFontStepChanged;

  /// Which arm of the corpus is on screen. **The pill's own field and not a
  /// locale read**: the page has already resolved the language it loaded, and the
  /// segmented control's selection *is* that fact. Reading `Localizations` again
  /// would be a second read of something the caller is holding.
  final ReadingLanguage language;

  /// Reports the other arm. The page re-issues its load; the pill does not load.
  final ValueChanged<ReadingLanguage> onLanguageChanged;

  /// What `listen` runs. **`null` in this build**, because there is no audio — see
  /// the class doc.
  final VoidCallback? onListen;

  /// The pill's own margin. `eva/redesign.html:192` — `margin: 0 18px 26px`.
  ///
  /// **26 is the largest bottom margin in the file**, and it is what lifts the
  /// pill clear of the screen's edge on a device with a home indicator — the
  /// prototype's `.device` box is `10px` of padding (`:43`) with nothing below it.
  /// Transcribed as written; the window's own inset is the scaffold's business.
  static const EdgeInsets margin = EdgeInsets.fromLTRB(18, 0, 18, 26);

  /// The pill's padding. `eva/redesign.html:192` — `padding: 10px 12px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  /// The pill's corner radius. `eva/redesign.html:192` — `border-radius: 999px`.
  static const double radius = 999;

  /// The pill's fill alpha. `eva/redesign.html:192` —
  /// `background: rgba(10,12,22,.72)`, which is `colors.canvas` at `.72` and
  /// **not** `colors.glassFill` — `:15` defines `--glass-fill` as
  /// `rgba(255,255,255,.04)`, a different value for a different surface.
  static const double fillAlpha = 0.72;

  /// The gap between the pill's children. `eva/redesign.html:192` — `gap: 8px`.
  static const double gap = EvaSpacing.sm;

  /// The `.pbtn` size. `eva/redesign.html:194` — `font-size: 11px`, mono.
  static const double buttonSize = 11;

  /// The `.pbtn` weight. `eva/redesign.html:194` — `font-weight: 600`.
  static const FontWeight buttonWeight = FontWeight.w600;

  /// The `.pbtn` padding. `eva/redesign.html:194` — `padding: 8px 10px`.
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );

  /// The `.pbtn` corner radius. `eva/redesign.html:194` — `border-radius: 99px`.
  static const double buttonRadius = 99;

  /// The `.pbtn` hovered fill. `eva/redesign.html:195` —
  /// `background: rgba(255,255,255,.06)`.
  ///
  /// **Transcribed and not painted**: `:195`'s hover has no Flutter analogue that
  /// costs nothing, and the control's own hover state is not a claim this screen
  /// makes. It is here so the number has a home if a future task asks for the
  /// hover, rather than being re-derived from `:195` then.
  static const double buttonHoverAlpha = 0.06;

  /// The `.pbtn` pressed scale. `eva/redesign.html:196` —
  /// `transform: scale(.92)`.
  ///
  /// **Also transcribed and not applied**, for the same reason: a pressed state on
  /// a button this size is a 8 % shrink the reader never sees, and applying it
  /// would need an `AnimatedScale` per control to animate something this screen
  /// does not assert.
  static const double buttonPressedScale = 0.92;

  /// The language control's width. `eva/redesign.html:187` —
  /// `.segp.langsm{width:112px}`.
  ///
  /// **A fixed width and not "fit to the labels"**, because `:179`'s thumb is
  /// positioned by JavaScript from `offsetLeft`/`offsetWidth` (`:1234`) and a
  /// content-sized track would give the thumb two different answers depending on
  /// which arm's labels it holds. 112 is the track both arms agree on.
  static const double segmentedWidth = 112;

  /// The Latin dial label. `eva/redesign.html:554` —
  /// `<button data-l="en">EN</button>`.
  static const String languageLabelEnglish = 'EN';

  /// The Arabic dial label. `eva/redesign.html:554` — `<button data-l="ar">ع</button>`.
  ///
  /// **One character, and it is Arabic script** — so the option renders in Amiri in
  /// **both** directions. `:186` writes `.segp button[data-l=ar]{font-family:
  /// var(--ar); font-size:13px; text-transform:none}`, which is keyed on the
  /// **option** and not on the screen, and `:191` keys the Latin option back to the
  /// mono face under RTL.
  ///
  /// That is why this widget passes `labelFamilyOf` to `SegmentedControl` rather
  /// than relying on its `arabicAware`: a direction-keyed rule is the identity on
  /// an LTR screen, so the English arm's dial drew `ع` in **JetBrains Mono**, which
  /// carries no Arabic glyphs. `arabic_typography_test.dart` measured it as
  /// `(family: JetBrainsMono, label: ع)` while the Arabic arm was already correct
  /// — the signature of the wrong rule standing in for this one, and the reason
  /// `SegmentedControl` grew the parameter.
  ///
  /// `:186`'s `font-size:13px` against `:184`'s `10px` is **not** reproduced: the
  /// control renders one size for all its options, and this port keeps the 10px
  /// rather than forking the thumb for three pixels.
  static const String languageLabelArabic = 'ع';

  /// The `A−` label. `eva/redesign.html:550` — `A−` uses **U+2212 MINUS SIGN**,
  /// not a hyphen, and it renders: measured present in five bundled families
  /// including the mono face this button is written in.
  static const String decreaseLabel = 'A−';

  /// The `A+` label. See [decreaseLabel] for the minus sign.
  static const String increaseLabel = 'A+';

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return Padding(
      padding: margin,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          // `:192`'s own fill, **not** `colors.glassFill` — see [fillAlpha].
          color: colors.canvas.withValues(alpha: fillAlpha),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          children: <Widget>[
            _PillButton(
              label: decreaseLabel,
              semanticLabel: context.l10n.readingDecreaseFontSize,
              pressedScale: buttonPressedScale,
              onPressed: () => onFontStepChanged(fontStep - 1),
            ),
            const SizedBox(width: gap),
            _PillButton(
              label: increaseLabel,
              semanticLabel: context.l10n.readingIncreaseFontSize,
              pressedScale: buttonPressedScale,
              onPressed: () => onFontStepChanged(fontStep + 1),
            ),
            // `:552` — `<span style="flex:1">`. See the class doc.
            const Expanded(child: SizedBox.shrink()),
            // `eva/redesign.html:553` — `.segp.langsm`, whose thumb `:179-182`
            // gives and `SegmentedControl` implements.
            SizedBox(
              width: segmentedWidth,
              child: SegmentedControl<ReadingLanguage>(
                values: const <ReadingLanguage>[
                  ReadingLanguage.english,
                  ReadingLanguage.arabic,
                ],
                selected: language,
                labelOf: (ReadingLanguage value) =>
                    value == ReadingLanguage.english
                    ? languageLabelEnglish
                    : languageLabelArabic,
                // `:186` — see [languageLabelArabic] for the whole argument.
                labelFamilyOf: (ReadingLanguage value) =>
                    value == ReadingLanguage.arabic
                    ? EvaTypography.arabicFamily
                    : EvaTypography.monoFamily,
                onChanged: onLanguageChanged,
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
            // `:558` — the `listen` button, inert in this build. **No `.wave`
            // before it**: `:557`'s four bars are `display:none` until an ancestor
            // is `.playing`, and nothing here ever is. See the class doc.
            _PillButton(
              label: context.l10n.readingListen,
              // The name a screen reader announces, and the reason it is not the
              // visible label: `:558`'s `data-i18n="listen"` rewrites the visible
              // text and gives the button no accessible name at all, and §14 wants
              // one. The suffix is how this codebase says "the capability is not in
              // this build" — the same arrangement login's ghost pills use.
              semanticLabel: onListen == null
                  ? context.l10n.listeningUnavailable(
                      context.l10n.readingUnavailableSuffix,
                    )
                  : context.l10n.readingListen,
              pressedScale: buttonPressedScale,
              onPressed: onListen,
            ),
          ],
        ),
      ),
    );
  }
}

/// One `.pbtn` — `eva/redesign.html:194-196`.
///
/// `border: none; background: transparent; color: var(--ink-1); font-family:
/// var(--mono); font-size: 11px; font-weight: 600; padding: 8px 10px;
/// border-radius: 99px`, with `:195`'s hover (`--ink-0` over
/// `rgba(255,255,255,.06)`) and `:196`'s pressed `scale(.92)` — the last two
/// transcribed in `ReadingPill` and not painted here, for the reasons their
/// constants give.
///
/// **The label is a `Text` in the mono face and not a `ButtonText`**, because
/// `.pbtn` sets `font-size: 11px` where the design system's `ButtonText` is
/// `titleMedium` — 15px — and these three controls are the only place in this app
/// where an 11px mono label is wanted.
///
/// ## AND `arabicAware`, FOR THE ONE LABEL THAT IS NOT LATIN
///
/// `A−` and `A+` are ASCII and the chevron is U+2039, Latin punctuation — on the
/// Latin arm the mono face is right for all of them, and `arabicAware` is the
/// identity there. The pill's **fourth** label is `listen` (`استمع`), which is
/// Arabic script, and `:194` names no family for `.pbtn` at all, so the
/// prototype inherits `--ui` and tofu'd it in the browser too. This client has no
/// per-character fallback, so `arabicAware` moves the Arabic arm's word to Amiri —
/// the arrangement `VerseLine`'s numeral and `StreakChip` use for the same reason,
/// and the tofu gate measured this one on the first run of the screen.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    required this.pressedScale,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double pressedScale;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: ReadingPill.buttonPadding,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(ReadingPill.buttonRadius),
            ),
          ),
          child: Text(
            label,
            style: arabicAware(
              EvaTypography.textTheme(colors).bodyMedium!.copyWith(
                fontFamily: EvaTypography.monoFamily,
                fontSize: ReadingPill.buttonSize,
                fontWeight: ReadingPill.buttonWeight,
                color: onPressed == null ? colors.ink3 : colors.ink2,
              ),
              Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}
