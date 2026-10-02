import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The "E" seal — the wordmark mark beside the Login wordmark and on the FAB.
///
/// `eva/src/screens/LoginScreen.tsx:17-26`, transcribed to a token-resolved
/// `BoxDecoration`:
///
/// | prototype | here |
/// | --- | --- |
/// | `width/height: 60`, `borderRadius: '50%'` | [defaultSize], `CircleBorder` |
/// | `radial-gradient(circle at 35% 35%, ${ember}33, transparent 70%)` | [sealGlowAlpha] over [EvaColors.ember] |
/// | `border: 1.5px solid ${ember}66` | [sealBorderAlpha], 1.5px |
/// | `boxShadow: 0 0 40px ${ember}44, 0 0 80px ${ember}22` | the two `BoxShadow`s |
/// | `E` in `F.display` 28 / 600 / ember | [letter], [EvaTypography.displayFamily], 28, `w600` |
///
/// ## THE GLOW IS NOT AN ELEVATION
///
/// [AGENT_CONTEXT] §9 decision 7: the prototype has no z-axis, and every
/// `box-shadow` in it is either a zero-offset ember glow or the single glass
/// ambient. These are the first kind — a zero-offset glow with no spread and no
/// direction — and they are why `EvaElevations` can still be all zeros. Every
/// elevation-bearing `ThemeData` field stays `0`.
///
/// ## SEMANTICS
///
/// Not decoration: it is the app's mark and it stands where a logo would. It gets
/// [semanticLabel] and drops its own subtree, so the "E" glyph is read as the
/// mark rather than as the letter E on its own.
class SealMonogram extends StatelessWidget {
  /// A seal of [size] logical px, optionally with a different [letter].
  const SealMonogram({
    this.size = defaultSize,
    this.letter = 'E',
    this.semanticLabel = 'Evangelion',
    super.key,
  });

  /// `LoginScreen.tsx:20` — `width: 60, height: 60`.
  static const double defaultSize = 60;

  /// Diameter in logical px.
  final double size;

  /// The glyph in the middle. The prototype's is `E`.
  final String letter;

  /// The accessible name for the mark.
  final String semanticLabel;

  /// The radial wash's peak alpha — the prototype's `${ember}33`.
  static const double sealGlowAlpha = 0.2;

  /// Where the wash starts, `circle at 35% 35%`.
  ///
  /// 35% from the left and 35% from the top, and Flutter's `Alignment` measures
  /// y from the bottom, so both components are `0.35 * 2 - 1 = -0.3`.
  static const Alignment sealGlowCenter = Alignment(-0.3, -0.3);

  /// Where the wash ends, `transparent 70%`.
  static const double sealGlowStop = 0.7;

  /// The rim's alpha — the prototype's `${ember}66`.
  static const double sealBorderAlpha = 0.4;

  /// The rim's width, `1.5px solid`.
  static const double sealBorderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color ember = colors.ember;

    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: sealGlowCenter,
            radius: sealGlowStop,
            colors: <Color>[
              ember.withValues(alpha: sealGlowAlpha),
              ember.withValues(alpha: 0),
            ],
          ),
          border: Border.all(
            color: ember.withValues(alpha: sealBorderAlpha),
            width: sealBorderWidth,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: ember.withValues(alpha: 0.267), blurRadius: 40),
            BoxShadow(color: ember.withValues(alpha: 0.133), blurRadius: 80),
          ],
        ),
        alignment: Alignment.center,
        // The prototype's `fontSize: 28` is absolute while the seal is
        // `size`-parameterised here, so the glyph scales with the seal: 28 at the
        // default 60px, which is the 0.4667 ratio `LoginScreen.tsx:23` declares.
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: EvaTypography.displayFamily,
            fontSize: size * 0.4667,
            fontWeight: FontWeight.w600,
            color: ember,
          ),
        ),
      ),
    );
  }
}
