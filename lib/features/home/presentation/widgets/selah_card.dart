import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Sixty seconds of silence, and the control that starts them.
///
/// `redesign.html:530-533` — `.selah`, its two lines, and the `.breathing` circle.
///
/// ## AND THE BUTTON IS **INERT**, WHICH IS A PHASE BOUNDARY AND NOT AN OMISSION
///
/// `:1330-1342` is the prototype's timer: a 60-second countdown, a live region in
/// the card's corner, `.selah.active` swapping the button to a filled gold, and
/// `focusDim = true` dimming the screen around the reader. **Phase 7 Step 3 owns
/// all of it** ("Ritual. Selah timer · focus mode · vespers auto-dim · breath
/// guide · haptics"), and Task 5.2's range is `:513-538` — the markup and the
/// styling, not the behaviour.
///
/// So the circle renders, it is 44×44 with the prototype's rim and fill, and it is
/// **genuinely inert**: `Semantics(button: true, enabled: false)` with the
/// unavailable sentence appended to its name, no tap and no focus stop, at 45%
/// opacity. That is the same treatment the login's ghost pills and the library's
/// book cards get (`:509`, `:1312-1318`), and it is the arrangement
/// `SocialAuthButton`'s doc argues for: "without it this control is a dead route,
/// and that is what this function fixes" — a control that explains itself.
///
/// ## AND THE COUNT IS NOT THE PROTOTYPE'S LITERAL
///
/// `:531` writes `60 seconds of silence` and `applyLang` rewrites it from
/// `selahDur = 60` with `N()` (`:990`), which is this arm's numerals. So the line is
/// a **composed** string with the duration as a placeholder, and [seconds] is the
/// one number this widget invents a home for. It comes from [defaultSeconds] and
/// not from a setting: `eva.ritual.*` is Task 5.7's key namespace and the reader
/// chooses it there.
class SelahCard extends StatelessWidget {
  /// The card: the word, the duration, and the inert circle.
  const SelahCard({
    required this.seconds,
    required this.unavailableReason,
    super.key,
  });

  /// How long the silence is, in seconds. `redesign.html:1323` — `selahDur = 60`.
  final int seconds;

  /// Appended to the circle's accessible name, never to what is painted.
  ///
  /// A parameter and not a constant here, for `AppTopBar`'s reason: a second copy
  /// of one ARB string inside a widget is a second place to translate one sentence.
  final String unavailableReason;

  /// The silence's length. `redesign.html:1323` — `let selahDur = 60`.
  static const int defaultSeconds = 60;

  /// The card's corner rounding. `redesign.html:261` — `border-radius: 20px`.
  ///
  /// **Not `EvaRadii.card`** (`18`), and the difference is the prototype's: `.selah`
  /// and `.bcard` are both `20` while `.glass-line` cards elsewhere are `18`. A
  /// local constant beside the citation is the honest spelling; moving the token
  /// would silently change every card that uses it.
  static const double radius = 20;

  /// The card's padding. `redesign.html:262` — `padding: 16px 18px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  /// The gap between the word block and the circle. `redesign.html:262` — `gap: 14px`.
  static const double gap = 14;

  /// The word's size. `redesign.html:264` — `.selah .dt{font-size:14.5px}`.
  static const double titleSize = 14.5;

  /// The gap under the word. `redesign.html:265` — `margin-top: 2px`.
  static const double subtitleGap = 2;

  /// The subtitle's size under LTR. `redesign.html:265` — `font-size: 9px`.
  static const double subtitleSize = 9;

  /// The subtitle's size on the Arabic arm. `redesign.html:266` — `10.5px`, and the
  /// same rule drops its tracking and its uppercase.
  static const double subtitleSizeArabic = 10.5;

  /// The subtitle's tracking under LTR. `redesign.html:265` — `.14em`.
  static const double subtitleTracking = 0.14;

  /// The circle's diameter. `redesign.html:267` — `width: 44px; height: 44px`.
  static const double diameter = 44;

  /// The circle's rim width. `redesign.html:267` — `border: 1.5px solid …`.
  static const double rimWidth = 1.5;

  /// The circle's rim alpha. `redesign.html:267` — `rgba(232,176,75,.6)`.
  static const double rimAlpha = 0.6;

  /// The circle's fill alpha. `redesign.html:268` — `rgba(232,176,75,.08)`.
  static const double fillAlpha = 0.08;

  /// The glyph's size. `redesign.html:269` — `font-size: 11px`, in the mono face.
  static const double glyphSize = 11;

  /// The glyph. `redesign.html:531` — `<button class="breathing" …>✦</button>`.
  ///
  /// **Painted, not typed — and that is a measured correction, not a preference.**
  /// The prototype writes the character and a browser falls back per character
  /// to draw it; **no bundled family carries U+2726** (`0x2726` = `10022`), so the
  /// first build typed it and `arabic_typography_test.dart`'s `expectNoTofuInAnyRun`
  /// failed with `Actual: [10022]`. This client has nothing to fall back **to**:
  /// the glyph is in no bundled font at all, so `fontFamilyFallback` would be a
  /// longer list of misses.
  ///
  /// So [FourPointedStar] paints the shape the character denotes at [glyphSize],
  /// the box the CSS's `font-size` names, and the character itself is kept in
  /// [glyph] as the *record* of what the prototype wrote — asserted by
  /// `home_geometry_test.dart` to be absent from the rendered text so the two
  /// cannot silently swap places.
  ///
  /// ## THE MEASUREMENT LIVES WITH THE SHAPE, NOT HERE
  ///
  /// Which fonts were checked, and how, is recorded in full on
  /// `core/design_system/widgets/four_pointed_star.dart` — the file that owns the
  /// decision, and the one a future call site reads. It is deliberately **not**
  /// restated here: two copies of one measurement is one measurement and two
  /// chances to be stale, and this file's copy already was one. It read "the
  /// twenty shipped `.ttf`s" where `assets/fonts/` holds **nineteen**;
  /// `AGENTS.md` and `test/support/font_coverage.dart`'s own header still say
  /// twenty. None of those three is this slice's to edit, so the number is
  /// measured on the shared file and published there rather than propagated.
  static const String glyph = '✦';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return GlassSurface(
      // `tint`, and not `bloom`: `.selah` (`:261-262`) carries no `.bloom` child.
      // It does declare `backdrop-filter: blur(10px)`, which is a second blur site
      // and is refused by §13.4's one-per-app budget — spent, once, on the day's
      // own card. `tint` is also the default, so the line is the comment's — recorded
      // here rather than left for a reader to find in the CSS.
      radius: radius,
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.homeSelah,
                  // `.dt{font-weight:600; font-size:14.5px}` — `:264`, with no
                  // family of its own, so it inherits the route's.
                  //
                  // `arabicAware`, and the word is Arabic on that arm: the I18N
                  // pair at `:970` is `["Selah","سِلاه"]`, tashkeel and all.
                  style: arabicAware(
                    Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                    direction,
                  ),
                ),
                const SizedBox(height: subtitleGap),
                Text(
                  // **Uppercased under LTR**, like every `.mono` run: `.ds` at `:265`
                  // declares `text-transform: uppercase` and `[dir=rtl] .mono` (`:136`)
                  // removes it on the Arabic arm only.
                  monoCapsText(strings.selahSeconds(seconds), direction),
                  // `.ds{font-family: var(--mono); font-size:9px;
                  // letter-spacing:.14em; text-transform:uppercase; color:var(--ink-2)}`
                  // — `:265`, and `[dir=rtl] .selah .ds` at `:266` swaps the
                  // family for `--ui-ar`, the size for 10.5px and drops the
                  // tracking and the uppercase.
                  //
                  // **`arabicAware` reaches Amiri rather than `--ui-ar`'s IBM Plex
                  // Sans Arabic, and that is this app's rule rather than the
                  // prototype's** — `arabic_typography_gate.dart` asserts every
                  // Arabic run renders in `EvaTypography.arabicFamily`, one family
                  // for the whole arm. Both bundled faces carry the block; the gate
                  // is what chooses.
                  style: arabicAware(
                    EvaTypography.monoCaps(colors).copyWith(
                      fontSize: direction == TextDirection.rtl
                          ? subtitleSizeArabic
                          : subtitleSize,
                      letterSpacing: direction == TextDirection.rtl
                          ? 0
                          : subtitleTracking,
                      color: colors.ink2,
                    ),
                    direction,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: gap),
          _BreathingButton(label: strings.homeSelah, reason: unavailableReason),
        ],
      ),
    );
  }
}

/// The 44px circle with the `✦` in it, inert.
///
/// `redesign.html:267-269`. Private, so the only way to draw one is through
/// [SelahCard] — the same arrangement `AppTopBar`'s `_Avatar` used, and the
/// reason this class's inertness cannot be bypassed by a call site that forgets
/// the reason string.
class _BreathingButton extends StatelessWidget {
  const _BreathingButton({required this.label, required this.reason});

  final String label;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    final Widget circle = Container(
      width: SelahCard.diameter,
      height: SelahCard.diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.ember.withValues(alpha: SelahCard.fillAlpha),
        border: Border.all(
          color: colors.ember.withValues(alpha: SelahCard.rimAlpha),
          width: SelahCard.rimWidth,
        ),
      ),
      child: FourPointedStar(
        size: SelahCard.glyphSize,
        // `colors.ember` passed rather than baked into the star: `:267-268`'s
        // `rgba(232,176,75,.6)` rim and `rgba(232,176,75,.08)` fill are the
        // *circle's*, and the glyph inside it is the prototype's `--gold` at
        // full strength — which on this palette is `ember`, not the 60%-alpha rim
        // a reader would otherwise expect from a 44px ring. See
        // `four_pointed_star.dart`'s `color` for why the widget takes it.
        color: colors.ember,
      ),
    );

    // **No `breatheRing` animation.** `redesign.html:269-270` is
    // `animation: breatheRing 8s ease-in-out infinite`, and `:48-50` kills it under
    // `.rm`. Phase 7 Step 3 owns the breath guide ("breath guide" is its own item)
    // and §13.2 collapses the app's ambient motion to four shared clocks, so a
    // second controller here would be spending budget on a decoration whose *active*
    // form — the filled gold circle at 2s — belongs to the timer this card cannot
    // run yet. The resting circle is painted; the pulse is not, and the doc above
    // says which phase owns it.
    return Semantics(
      button: true,
      enabled: false,
      label: '$label — $reason',
      excludeSemantics: true,
      child: Opacity(opacity: 0.45, child: circle),
    );
  }
}
