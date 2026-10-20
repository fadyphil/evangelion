import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The reading-size preview — `redesign.html:431`.
///
/// ```css
/// .prevline{font-family:var(--scr);color:var(--ink-1);margin:10px 2px 2px;
///   transition:font-size .2s}
/// ```
///
/// ## ITS SIZE IS THE **AMBIENT** SCALE, AND THAT IS A DIFFERENCE OF MODEL
///
/// The prototype's preview is sized by a number of its own: `applySize()`
/// (`redesign.html:1398`) writes one value — `vs` — into `--vsize` **and**
/// into the preview's `font-size`, so the preview and the reading are the same
/// number *by construction*.
///
/// The client has no `vs`. Its reading size is the **installed text scale**,
/// which the font step installs app-wide, and which every `Text` in the app
/// is already scaled by. So the preview renders **at the ambient scale**: it
/// grows and shrinks with the reader's font step because the whole app does,
/// and the two models agree about the one thing that matters — the preview
/// shows the size the reading will be read at.
///
/// This is a difference of **model**, not a divergence from the prototype: the
/// same fact, expressed in the client's terms. The prototype's `vs` is
/// 16–26px (`redesign.html:693`); the client's step is 1–5. Neither number is
/// transcribed, because neither is a size — they are the two ways of saying
/// "how big the reading is".
///
/// ## THE FAMILY FOLLOWS THE ARM
///
/// `--scr` is a single face in the prototype — `'EB Garamond'` for the Latin
/// arm and Amiri for the Arabic one is the client's two-script equivalent, and
/// `EvaTypography`'s scripture slots are exactly that pair. `arabicAware`
/// resolves it from the ambient direction, so the widget has no arm of its own
/// to get wrong.
///
/// ## THE COLOUR IS `--ink-1`, WHICH IS `ink2` HERE
///
/// `redesign.html:431` writes `color:var(--ink-1)`, and this design system
/// has no `ink1`: the prototype's `--ink-1` (`#A9B0C8`) is the secondary ink,
/// which is [EvaColors.ink2] in both palettes. That mapping is the house's,
/// not this widget's — `verse_line.dart` states it in the same words — and it
/// is repeated here so a reader comparing `:431` against this file finds the
/// substitution named.
class PreviewLine extends StatelessWidget {
  /// A preview line showing [text] at the reading size.
  const PreviewLine({required this.text, super.key});

  /// The text to preview.
  final String text;

  /// The margin around the line. `redesign.html:431` — `margin:10px 2px 2px`.
  ///
  /// **Top, sides, bottom** — the CSS order — so it is 10 above and 2 on each
  /// side and below.
  static const EdgeInsets margin = EdgeInsets.fromLTRB(2, 10, 2, 2);

  /// The preview's **base** size — the size it has at a 1.0 text scale.
  ///
  /// The scripture slot's own size: [EvaTypography.scriptureLatin] is
  /// `bodyLarge`, and Material 3's `bodyLarge` is **16sp**.
  ///
  /// **It is written here rather than read off the slot** because the
  /// animation needs a number to scale and `TextStyle.fontSize` is a
  /// `double?`: a nullable read would put a `!` in this file, or a fallback
  /// number that could drift away from the slot's own. The two are asserted
  /// against each other in `preview_line_test.dart`, so a change to the slot's
  /// size turns that test red rather than silently resizing the preview.
  static const double baseSize = 16;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // The ambient scale, read the way a device sets it.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double scaled = scaler.scale(PreviewLine.baseSize);
    // §14: with animations off the size lands on the frame the scale changes.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: PreviewLine.margin,
      // `transition:font-size .2s` — and `.2s` is [EvaMotion.base] exactly, so
      // no rounding was needed.
      //
      // **The style lives here, not on the `Text` below**, for the reason
      // `SegmentedControl` and `SettingsTile` both give: an explicit
      // `Text.style` beats the ambient default, so a size set on the `Text`
      // would snap instead of transitioning and the animation would be
      // painting nothing.
      child: AnimatedDefaultTextStyle(
        duration: animate ? EvaMotion.base : Duration.zero,
        curve: EvaMotion.baseCurve,
        style: arabicAware(
          EvaTypography.scriptureLatin(colors)
              .copyWith(fontSize: scaled, color: colors.ink2),
          Directionality.of(context),
        ),
        // `textScaler: noScaling` because the size above is **already**
        // scaled: the scaler was applied to [baseSize] by hand, and leaving
        // the ambient scaler on the `Text` as well would apply it twice.
        child: Text(text, textScaler: TextScaler.noScaling),
      ),
    );
  }
}
