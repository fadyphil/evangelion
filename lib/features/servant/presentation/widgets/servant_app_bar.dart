import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The app bar the portal's three working screens share: a back chevron and
/// the screen's name.
///
/// ## AND WHY THE SCREEN **NEEDED** ONE
///
/// Because a pushed route on this platform has **no way back**.
///
/// The portal's three sub-routes are pushed with `context.router.pushPath`, and
/// `NeuralScaffold` has no app bar, no drawer and no leading control — its own
/// doc says so: *"No `appBar`, no `floatingActionButton`, no `drawer`."* So
/// before this widget existed, a servant who opened the daily report on the
/// **Linux desktop build** — the only device this app is currently runnable on
/// — had **no visible way back to the portal**, and the only way out was the
/// browser's or the window manager's back gesture.
///
/// `CommunionAppBar`'s own doc records the same finding for `/communion`, and
/// it is why that screen has one: *"On desktop the back chevron is the **only**
/// way out of `/communion` (there is no bottom nav and no system back), so a
/// keyboard-only reader could land on this screen and never leave it."* The
/// portal's three screens were in the same position and had not been given the
/// control.
///
/// ## AND WHY IT IS **VIEWPORT-FIXED** AND NOT PART OF THE SCROLL
///
/// Because the two screens it titles are **long** — the schedule form is eight
/// fields and the editor is eleven controls, which is four screens of scrolling
/// at 320×568 — and a back control that scrolls off is not a back control. It
/// is the last thing on the page until the reader scrolls back, which is
/// `NeuralScaffold`'s own sentence about the `overlay` slot this widget uses:
///
/// > *"A floating affordance that scrolls off is not a floating affordance — it
/// > is the last thing on the page until you scroll back."*
///
/// **And the reading screen already answers it this way**: `/reading` is the
/// app's other long pushed screen, and its `ReadingAppBar` sits in a `Column`
/// above the scrolling body rather than inside it.
///
/// The two app bars that **scroll** — `CommunionAppBar` and `WorkshopAppBar` —
/// are on screens that are **tabs of the dock shell**, so the dock is always
/// on screen and the app bar is not the only chrome. **The portal has no
/// dock**, so its app bar is.
///
/// ## AND WHY IT IS **THE PORTAL'S OWN** AND NOT A SECOND `CommunionAppBar`
///
/// Because the two bars are **not the same bar**. `CommunionAppBar` carries a
/// veil toggle on the trailing side — a control that means something only on
/// the cohort's board — and this one carries nothing at all, because the
/// portal's three screens have no second control to offer.
///
/// And a shared widget with a `Widget? trailing` slot would be a widget whose
/// trailing slot is `null` at every one of its four call sites, which is a
/// parameter with no reader.
///
/// ## AND WHY THE CHEVRON **MIRRORS FOR FREE**
///
/// `eva/redesign.html:139` is `[dir=rtl] .chev{transform:scaleX(-1)}`, and
/// `Icons.arrow_back_ios_new` is declared `matchTextDirection: true` in the
/// SDK — so the ambient RTL points it rightwards, with no `Transform` and no
/// second icon to choose. `CommunionAppBar` records the same observation.
class ServantAppBar extends StatelessWidget {
  /// The bar for a screen named [title].
  const ServantAppBar({required this.title, super.key});

  /// The screen's name, in the reader's own language.
  final String title;

  /// The bar's horizontal inset.
  ///
  /// **16, and not the prototype's 18** (`redesign.html:142` is
  /// `padding:46px 18px 4px`). The bar is **viewport-fixed** here, so it
  /// paints over the whole window, and the content it titles is inset by the
  /// scaffold's own 16px gutter — so the bar's inset has to be the **same**
  /// 16 or the title and the content below it would not share an edge.
  ///
  /// The prototype's 18 is a number from a screen whose own gutter is 18, and
  /// this bar titles content whose gutter is 16.
  static const double horizontalInset = EvaSpacing.lg;

  /// The bar's top inset.
  ///
  /// **Written, not transcribed.** `redesign.html:142`'s 46px is the
  /// **phone's status bar** in a prototype that drew its own device frame; this
  /// app draws no frame and `NeuralScaffold` already applies the safe area to
  /// the content, so a 46px inset here would push the title down inside a
  /// status bar the framework has already accounted for.
  ///
  /// `8` is the air between the safe area and the bar's row, and it is **not**
  /// a number from the prototype: `:142` has 46, 18 and 4, and 8 is none of
  /// them. The **4** below is.
  static const double topInset = 8;

  /// The bar's bottom inset — `redesign.html:142`'s own `4px`.
  static const double bottomInset = 4;

  /// The bar's padding.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(
    horizontalInset,
    topInset,
    horizontalInset,
    bottomInset,
  );

  /// The row's height — the tap target's.
  ///
  /// **44, and not the prototype's 34.** `redesign.html:143` is
  /// `.abrow{min-height:34px}`, but the row holds an `IconActionButton`, whose
  /// box is 44×44 because 44 is `iOSTapTargetGuideline`'s minimum and the
  /// prototype's own back buttons are 44 wide. So the floor is never the
  /// binding constraint, and the row is 44. `CommunionAppBar` records the same
  /// arithmetic.
  static const double minHeight = 44;

  /// The bar's **total** height — the insets and the row.
  ///
  /// **And this is the number the content's top inset is.** The bar is
  /// viewport-fixed and the content scrolls *underneath* it, so the content
  /// has to be pushed down by exactly this much or the first field would be
  /// painted behind the bar. One constant, read by both.
  static const double height = topInset + minHeight + bottomInset;

  /// The title's size — `redesign.html:145`'s `font-size:15px`.
  static const double titleSize = 15;

  /// The space the back control's box claims at **each** end of the bar.
  ///
  /// **44 for the button's box and 8 of air beside it.** The title is
  /// **centred on the bar** — the prototype's composition, `:144-145`'s
  /// `position:absolute;left:50%` — and a centred title of width `T` spans
  /// `(W − T) / 2 … (W + T) / 2`. So the control's zone has to be reserved on
  /// **both** sides for the title to be centred without ever landing on the
  /// chevron, and the zone is half the button's 44px box plus 8px of air.
  ///
  /// **And the reserve is SYMMETRIC although the control is not.** The
  /// prototype's title is centred on the bar, and a bar whose title is
  /// off-centre is a different bar; the symmetric reserve is what lets the
  /// title stay centred while never reaching the control. It costs width, and
  /// the width it costs is measured below.
  static const double controlZone = 44 + 8;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return SizedBox(
      // **THE FULL WIDTH, and it has to be said.** This widget is painted
      // through `NeuralScaffold`'s `overlay` slot, which is a `Positioned.fill`
      // — and the `Align` that places the bar hands it **loose** constraints,
      // so a `Stack` sized by its own children would be 44px wide (the
      // back button's box) and the title would be laid out inside that. The
      // full width is what makes the title's box the bar's box.
      width: double.infinity,
      child: Padding(
        padding: ServantAppBar.padding,
        child: SizedBox(
          height: minHeight,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // **THE TITLE'S WIDTH IS **COMPUTED**, and not the prototype's
              // `52%`.**
              //
              // The prototype's `:145` is `max-width:52%` — a number for a
              // **390px** frame with 18px of app-bar padding, so a title box of
              // 184px. This bar's box is the window's width less 32px of
              // inset, and at **320** that is 288px, so the same 52% would be
              // **149.8px** — and "Schedule a reading" at the reader's
              // largest text scale measures **172.4px**. The title would be
              // **truncated**, and a truncated title is §14's "the reader's
              // words deleted".
              //
              // So the cap is **the bar's width less the two control zones**,
              // which at 320 is 288 − 104 = **184px** — the same 184 the
              // prototype's own 390px frame gives, and 34px more than its 52%
              // would give at 320. The title is still centred, the chevron is
              // still clear of it, and the longest of the portal's three titles
              // fits at the narrowest surface and the largest scale.
              //
              // `servant_text_scale_test.dart` is what holds this.
              final double maxTitle = constraints.maxWidth - 2 * controlZone;
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // The title, absolutely centred — `redesign.html:144-145`'s
                  // `position:absolute;left:50%;transform:translate(-50%,-50%)`.
                  // `Positioned.fill` + `Center` is the Flutter spelling of
                  // that, and the three together are what make the title
                  // centred **on the bar** rather than centred on the space
                  // beside the chevron.
                  Positioned.fill(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxTitle > 0 ? maxTitle : 0,
                        ),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: arabicAware(
                            // **The UI sans, and not the display serif**: the
                            // prototype's `.ttl` declares no family, so it
                            // inherits `body`'s `--ui` (`:22`).
                            Theme.of(context).textTheme.titleMedium!.copyWith(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                            ),
                            direction,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The back chevron, at the leading edge.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconActionButton(
                        // **`Icons.arrow_back_ios_new` and not
                        // `Icons.chevron_left`**, for the reason
                        // `WorkshopAppBar` gives: the prototype's is a
                        // *chevron* and Material's `arrow_back` is an arrow.
                        icon: Icons.arrow_back_ios_new,
                        // `redesign.html:149` — `font-size:16px`.
                        iconSize: 16,
                        // **Material's own name for the control**, so it is
                        // translated by the framework and is right in both
                        // arms.
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        // The tooltip is Arabic on the Arabic arm, which is
                        // `IconActionButton.tooltipFamily`'s reason for being
                        // required.
                        tooltipFamily: arabicAwareFamily(
                          direction,
                          EvaTypography.uiFamily,
                        ),
                        // **`maybePop`, resolved inside the callback and not in
                        // `build`.** The router is not in the tree of a screen
                        // that was pumped on its own — the portal's golden
                        // test pumps each page without a router — and
                        // `context.router` in a `build` would reach for a
                        // scope that is not there. Inside the callback it is
                        // only ever read when a reader presses it, and a reader
                        // cannot press it without a router.
                        onPressed: () => unawaited(context.router.maybePop()),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
