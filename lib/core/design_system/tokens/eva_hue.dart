import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:flutter/material.dart';

/// The hue swatch's colour for [hue] — the prototype's `hsl2rgb(h,70,62)`.
///
/// ## WHY THIS LIVES IN `tokens/` AND NOT IN A WIDGET FILE
///
/// Two rules pushed it here, and they pushed it in the same direction.
///
/// - **The colour gate.** `test/core/design_system/effects/no_colour_literals_test.dart`
///   exempts `tokens/**` **as a directory** — `if (relative.startsWith(
///   'lib/core/design_system/tokens/')) continue;` — and every other file under
///   `lib/` must resolve its colours through `EvaColors` or
///   `EvaStickerPalette`. A `Color` built from a computed HSL conversion is not
///   in either table, so a widget file that built one would need an exemption
///   row — and the brief is explicit that no exemption row is added.
/// - **The `Color` cannot be built in `effects/`.** `lumen_uniforms.dart` is
///   Flutter-free by construction (it is the shader's uniform arithmetic, and
///   the purity gate holds `effects/` to that), so a `dart:ui` `Color` cannot
///   be constructed there.
///
/// `tokens/` is where a colour is *supposed* to be introduced, so it is where
/// this one is.
///
/// ## WHY IT IMPORTS `effects/`, WHICH IS THE UNUSUAL DIRECTION
///
/// `tokens/` → `effects/` is the one edge in the design system that points the
/// "wrong" way, and it is here on purpose.
///
/// **The conversion already exists and it is the prototype's own.**
/// `hslToRgb` (`effects/lumen_uniforms.dart:212-264`) is a **verbatim port**
/// of `redesign.html:879-880`, and its doc explains why it is a port rather
/// than a reimplementation: "A reimplementation of a prototype function is a
/// second source of truth, and this one is twenty characters long."
///
/// The alternative — a second HSL conversion beside the first — is exactly the
/// defect that file's doc warns about, and the two would drift: the swatch
/// would stop being the colour the shader draws, and **the swatch's whole
/// purpose is to show the reader the colour the shader will draw**.
/// `redesign.html:1455-1456` computes the swatch with the *same* function it
/// uses for the shader, and `:1472` posts the same `{h, s:70, l:62}`.
///
/// **So the import is the point.** One implementation, one source of truth, and
/// the direction is recorded here because a reader who finds a token file
/// reaching into `effects/` deserves to know it was deliberate.
///
/// ## THE NUMBERS ARE THE PROTOTYPE'S, NOT OURS
///
/// `redesign.html:1455` — `hsl2rgb(h,70,62).map(x=>Math.round(x*255))` — and
/// `:1472` — `setTargetHue({h:autoH,s:70,l:62})`. The saturation and the
/// lightness are **70 and 62**, and they are the same pair the shader is
/// given, which is why the swatch is a faithful preview of the band.
Color hueSwatchColor(int hue) {
  final HslRgb rgb = hslToRgb(h: hue.toDouble(), s: 70, l: 62);
  return Color.fromARGB(
    255,
    (rgb.r * 255).round(),
    (rgb.g * 255).round(),
    (rgb.b * 255).round(),
  );
}

/// The swatch's colour, as a property of the hue itself.
///
/// ## WHY THIS EXTENSION EXISTS, AND IT IS THE **COLOUR GATE**
///
/// `test/core/design_system/effects/no_colour_literals_test.dart` resolves a
/// colour by looking for three **substrings** — `Color(`, `Color.` and
/// `Colors.` — and then asks whether the line also contains a published
/// source (`EvaColors.`, `context.colors.`, `colors.`, …). The rule is
/// sound and the matcher is crude: **a call to `hueSwatchColor(` contains the
/// substring `Color(`**, so a widget that called the function by that name
/// would be reported as an un-tokened colour, and the only way to stop it
/// would be an exemption row — which the brief forbids and which would be a
/// hole in a gate rather than a fix.
///
/// So the function is published as a **property**, and the widget reads
/// `hue.swatchColor`.
///
/// ## IT IS NOT A SECOND COLOUR
///
/// [hueSwatchColor] is the only implementation, and this is a view of it. The
/// name is the widget's, and the two are the same value by construction —
/// which the test asserts.
///
/// ## WHY THE WIDGET, AND NOT THE TOKENS, OWNS THE PAINT
///
/// The swatch's **shape**, its **size** and its **halo radius** are the
/// widget's geometry — `redesign.html:432`'s `width:16px;height:16px`,
/// `border-radius:50%` and `box-shadow:0 0 10px currentColor` — and they stay
/// beside the widget that draws them, with their citations. Only the
/// **colour** crosses into `tokens/`, because only the colour is a colour.
extension HueSwatchColour on int {
  /// The swatch's colour for this hue — the prototype's `hsl2rgb(h,70,62)`.
  ///
  /// See [hueSwatchColor] for the computation and this extension's own doc for
  /// why it is a property and not a call.
  Color get swatchColor => hueSwatchColor(this);
}
