import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The hue swatch — `redesign.html:432`.
///
/// ```css
/// .huesw{width:16px;height:16px;border-radius:50%;display:inline-block;
///   vertical-align:-3px;margin-left:8px;box-shadow:0 0 10px currentColor}
/// ```
///
/// ## THE GLOW IS THE SWATCH'S **OWN** COLOUR, AND THAT IS THE POINT
///
/// `currentColor` is the element's `color`, and the prototype sets **both**
/// `background` and `color` to the same computed `rgb()` — `redesign.html:1456`:
///
/// ```js
/// const c=`rgb(${r},${g},${b})`; sw.style.background=c; sw.style.color=c;
/// ```
///
/// So the halo is the swatch's own hue at full strength, and the swatch is
/// the reader's preview of the band the shader will draw. A glow in a
/// different colour would be decoration; this one is information.
///
/// ## WHAT IS **NOT** TRANSCRIBED, AND WHY
///
/// - **`margin-left: 8px` is the caller's spacing.** The swatch sits *after*
///   the range input (`redesign.html:661` — `<input type="range" id="setHue">
///   <span class="huesw" id="hueSw"></span>`), so the row's trailing is a
///   `Row` of slider and swatch with an 8px gap. The gap belongs to the row
///   that owns both, not to a widget that knows nothing about what is beside
///   it.
/// - **`vertical-align: -3px` is not transcribed.** It is a **baseline nudge in
///   an inline layout** — the swatch is an `inline-block` sitting on the text
///   baseline of the row, and the nudge raises it by 3px so its centre lines
///   up with the neighbouring text. Flutter's row alignment is centre-based,
///   so there is no baseline to nudge against, and a 3px offset would be an
///   arbitrary number in a layout that has no such concept. This is recorded
///   at the widget because a reader comparing `:432` against this file will
///   find the two declarations missing and deserves to know they were
///   deliberate.
///
/// ## IT SAYS NOTHING
///
/// The swatch is a picture of a colour, and a screen reader cannot read a
/// picture of a colour. The **value** is announced by the slider beside it
/// (`EvaRangeSlider`'s `Semantics(slider: true, value: …)`), which is where
/// the number the swatch is showing lives. The swatch therefore publishes no
/// semantics of its own — a second node saying "hue" beside the slider's own
/// "Hue, 312" would be §14's duplicate-name defect wearing a different hat.
class HueSwatch extends StatelessWidget {
  /// A swatch showing the colour of [hue].
  const HueSwatch({required this.hue, super.key});

  /// The hue in degrees, `0…360`.
  final int hue;

  /// The swatch's diameter. `redesign.html:432` — `width:16px;height:16px`.
  static const double diameter = 16;

  /// The glow's radius. `redesign.html:432` — `box-shadow:0 0 10px
  /// currentColor`.
  static const double glowBlur = 10;

  @override
  Widget build(BuildContext context) {
    // `hue.swatchColor` and not `hueSwatchColor(hue)` — see
    // `tokens/eva_hue.dart`'s own doc: the colour gate matches the
    // substring `Color(`, and a call to a function with that name would be
    // reported as an un-tokened colour. The value is the same either way.
    final Color swatch = hue.swatchColor;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: swatch,
        // `border-radius:50%` on a 16×16 box — a circle, and the same shape
        // the prototype's `border-radius:50%` produces.
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          // `0 0 10px currentColor`, and `currentColor` is the swatch's own
          // colour: the prototype sets `background` and `color` to the same
          // computed `rgb()` (`redesign.html:1456`), so the halo is the hue at
          // full strength rather than a tinted copy of it.
          BoxShadow(color: swatch, blurRadius: glowBlur),
        ],
      ),
    );
  }
}
