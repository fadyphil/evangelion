import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The Communion screen's app bar: back chevron, absolutely centred title, and veil toggle
/// (`eva/redesign.html:612-617`, `:142-156`).
///
/// ## THE TWO CONTROLS ARE THE PROTOTYPE'S TWO **DIFFERENT** BUTTONS
///
/// `eva/redesign.html:614` is `<button class="chev" id="boardBack">‹</button>`
/// and `:616` is `<button class="iconbtn" id="veilBtn" title="veil">…</button>`.
/// The prototype draws the back control as a **bare glyph with no box** and the
/// veil as a **30px glass pill with a 1px rim**, and
/// `lib/core/design_system/widgets/icon_action_button.dart` already models both
/// halves — its own doc quotes `:149-155` and says so in as many words:
/// `pilled: false` is `.chev` and `pilled: true` is `.iconbtn`.
///
/// ## THE PRIVATE `_IconHit` THIS FILE USED TO SHIP WAS REJECTED FOR A REASON
/// ## THAT WAS **FALSE**, AND THE REASON MATTERED
///
/// The `_IconHit` this file used to carry justified itself like this: "the
/// prototype's veil button is a 30px circle (`:616`) and the app bar is 44px
/// tall, so the button is **smaller than the touch target** it has to live in —
/// which `IconActionButton` **cannot express**, because it is a 44px pill."
///
/// That is not what `IconActionButton` does. Its own doc says, at
/// `icon_action_button.dart:43-52`:
///
/// > **THE BOX IS 44 AND THE PILL IS 30, AND NEITHER NUMBER IS NEGOTIABLE** …
/// > So the pill is a **30px silhouette inside the existing 44px box** and not a
/// > smaller button
///
/// and `:377-412` builds exactly that — `SizedBox(44,44) > Center >
/// AnimatedContainer(30×30) > icon`. The prototype's `.chev` (`:149`,
/// `padding: 4px 6px` on a 16px glyph) is the same shape: a small target
/// inside a comfortable one.
///
/// **So the false claim was the reason the ring and the name were missing.** A
/// bare `GestureDetector` builds **zero** `FocusableActionDetector`s, so Tab
/// never reached either control and §14's focus ring could never paint on
/// either of them; and a `Tooltip` contributes only a `semanticsTooltip`, never
/// a `label`, so the two controls were announced with **no name** and — because
/// `RenderSemanticsGestureHandler` sets `config.onTap` but not `config.isButton`
/// — they were **not buttons** either.
///
/// On desktop the back chevron is the **only** way out of `/communion` (there
/// is no bottom nav and no system back), so a keyboard-only reader could land
/// on this screen and never leave it. `IconActionButton` carries the focus
/// node, the ring, the name and the tap action, and it is the widget the
/// prototype's two roles were already modelled in.
///
/// ## THE GEOMETRY, IN THE PROTOTYPE'S OWN NUMBERS
///
/// | what | number | where |
/// | --- | --- | --- |
/// | the tap box | 44×44 | `iOSTapTargetGuideline`'s minimum; `IconActionButton`'s `size` |
/// | the chevron's glyph | 16 | `:149` — `font-size: 16px` |
/// | the pill | 30×30 | `:151` — `width: 30px; height: 30px` |
/// | the pill's glyph | 15 | `:155` — `.iconbtn svg { width: 15px; height: 15px }` |
///
/// The app bar's own height is 44 (the `SizedBox` below), so both controls fit
/// their row exactly and the title's absolute centre is untouched.
///
/// ## THE RTL MIRRORING — AND WHAT THE PROTOTYPE ACTUALLY DOES
///
/// `eva/redesign.html:139` is `[dir=rtl] .chev{transform:scaleX(-1)}`, so the
/// prototype **does** mirror the back chevron under RTL. The veil pill is
/// **not** mirrored: there is no `[dir=rtl]` rule that mentions `.iconbtn` at
/// all — `rg 'dir=rtl\].*iconbtn' eva/redesign.html` finds **nothing**.
///
/// The mirror is therefore free and needs no `Transform` here:
/// `Icons.arrow_back_ios_new` is declared `matchTextDirection: true` in the
/// SDK, so the ambient RTL points it rightwards, and `Icons.visibility_outlined`
/// is not a directional glyph at all.
///
/// ## THE VEIL PILL'S PAINT, AND WHAT MOVED WHEN IT BECAME AN
/// ## `IconActionButton`
///
/// The prototype's `.iconbtn` is `background: none` (`:151`) with a 1px rim
/// (`:151`) and, when lit, a gold rim at 60% and a `0 0 12px` gold glow
/// (`:154`). The private `_IconHit` this file used to ship drew a **filled**
/// circle (`ember` at 18%), a **solid** `emberInk` rim and an **8px** blur.
///
/// `IconActionButton` draws the prototype's three — no fill at all, `ember` at
/// 60%, and a 12px blur — so the veil button's look moved **towards** the
/// prototype rather than away from it. The old fill is the only thing this
/// change removed, and `:151`'s `background: none` is what asked for it.
///
/// The lit state is `.iconbtn.lit` (`:154`), and the prototype drives it from
/// the veil setting (`redesign.html:1493`), so `lit: isVeiled` is the whole
/// of the state — the control's own pressed state and its name carry the rest.
class CommunionAppBar extends StatelessWidget {
  /// Creates the app bar for `/communion`.
  const CommunionAppBar({
    required this.title,
    required this.isVeiled,
    required this.onToggleVeil,
    this.onBack,
    super.key,
  });

  /// The screen title ("The Communion" / "الشركة").
  final String title;

  /// Whether the witness veil is currently active.
  final bool isVeiled;

  /// Invoked when the veil button is pressed.
  final VoidCallback onToggleVeil;

  /// Invoked when the back chevron is pressed.
  ///
  /// `null` renders the chevron **inert**, and `IconActionButton`'s rule for an
  /// inert control is the design system's, not the prototype's: the glyph goes
  /// to `ink3`, the control stops being a tab stop, and its semantics node
  /// announces `enabled: false` and offers **no** tap action. The prototype has
  /// no disabled chevron to copy, so this is the design system's answer and it
  /// is recorded here rather than left as an unstated difference.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final TextDirection direction = Directionality.of(context);

    // ## THE TOOLTIPS' FAMILY, AND WHY IT IS RESOLVED HERE
    //
    // `Tooltip` has **no `textStyle` default**: a tooltip with no style of its
    // own resolves to the theme's `bodyMedium`, which is the **Latin** UI face
    // (`Inter`). Both of this screen's tooltips are Arabic on the Arabic arm —
    // the veil button's own name, and `MaterialLocalizations`' Arabic
    // `backButtonTooltip` — and the bilingual gate
    // (`test/arabic_typography_test.dart`) reported both as tofu:
    //
    //     `رجوع` renders Arabic in `Inter`, which carries no Arabic glyph at all
    //
    // one box per character, for each of the two.
    //
    // So the family is resolved the way `IconActionButton` resolves its
    // `tooltipFamily` — `arabicAwareFamily(direction, …)` — and handed to the
    // `IconActionButton` as its `tooltipFamily`. **The direction and not the
    // locale**, because the direction is the engine's own answer to "which
    // script is this run in" (`eva_typography.dart`'s `arabicAwareFamily`).
    //
    // `IconActionButton`'s `tooltipFamily` is **required** and is not a second
    // name parameter: the same string is the tooltip's text *and* the
    // `Semantics(label:)`, so a control whose tooltip says one thing and whose
    // name says another is not expressible.
    final String tooltipFamily = arabicAwareFamily(
      direction,
      EvaTypography.uiFamily,
    );

    return Padding(
      // ## THE PADDING IS **NOT** THE PROTOTYPE'S, AND THAT IS A RECORDED
      // ## DIVERGENCE
      //
      // `eva/redesign.html:142` is `.appbar{padding:46px 18px 4px}` — **46px of
      // top padding**, which is the phone's own status bar and the redesign's
      // frame around it. `:143`'s `.abrow` is `min-height:34px`, so the
      // prototype's bar row is 34px tall inside 46px of inset.
      //
      // This app draws its own chrome: `NeuralScaffold` already handles the
      // safe area, and the app bar is the first thing in the page's scroll
      // content, so a 46px top inset would push the title 46px down the screen
      // **inside** a status bar the framework has already inset for. The
      // prototype's number is a phone-frame number, not a widget number, and
      // this widget's row is 44px — the tap-target minimum — so the controls
      // fill it exactly.
      //
      // The horizontal 18px **is** the prototype's, and the 4px bottom is too.
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Absolutely centred title (redesign.html:144-145)
            FractionallySizedBox(
              widthFactor: 0.52,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arabicAware(
                  text.titleMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                  direction,
                ),
              ),
            ),
            // Leading back chevron and trailing veil button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // ## THE CHEVRON: THE BARE-GLYPH ROLE
                //
                // `pilled: false` is the default, and it is `.chev` — no fill and
                // no rim (`:149`'s `background: none; border: none`). The
                // `iconSize` is `:149`'s `font-size: 16px`, and the default
                // would have been `44 × 0.4545` — a 20px glyph, which is the
                // React prototype's proportion and not the redesign's.
                IconActionButton(
                  icon: Icons.arrow_back_ios_new,
                  iconSize: 16,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  tooltipFamily: tooltipFamily,
                  onPressed: onBack,
                ),
                // ## THE VEIL: THE PILL ROLE, AND THE LIT STATE
                //
                // `pilled: true` is `.iconbtn` (`:151`) — a 30px circle with a
                // 1px rim — and `lit` is `.iconbtn.lit` (`:154`), which the
                // prototype drives from the veil setting (`redesign.html:1493`:
                // `el('veilBtn').classList.toggle('lit', veilOn)`).
                //
                // The glyph is `:155`'s 15px, which is
                // `IconActionButton.pillIconSize`. The private `_IconHit` this
                // file used to ship drew it at 16px — the chevron's size, not
                // the pill's own svg's.
                IconActionButton(
                  icon: Icons.visibility_outlined,
                  iconSize: IconActionButton.pillIconSize,
                  pilled: true,
                  lit: isVeiled,
                  tooltip: context.l10n.leaderboardVeil,
                  tooltipFamily: tooltipFamily,
                  onPressed: onToggleVeil,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
