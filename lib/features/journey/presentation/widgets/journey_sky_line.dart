import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The sky line — `eva/redesign.html:596`.
///
/// ```html
/// <div class="mono" style="text-align:center;margin:4px 0 0;color:var(--ink-1)">
///   <span data-i18n="sky">sky</span> · <b id="jSkyN">0</b> <span data-i18n="stars">stars lit</span> ·
///   <b id="jSkyC">0</b> <span data-i18n="consts">constellations</span>
/// </div>
/// ```
///
/// ## THE TWO COUNTS ARE **BOLD AND GOLD**
///
/// The prototype's `<b>` is not bold-for-its-own-sake: `:31` is
/// `.mono b{color:var(--gold);font-weight:600}`, so the two numbers are the
/// gold accent and everything around them is the dimmer ink. That is the whole
/// reason the line is composed rather than printed: a single string could not
/// carry two inks.
///
/// ## THE `·` SEPARATORS ARE **THIS WIDGET'S**
///
/// They are U+00B7 MIDDLE DOT, which is in **all five** bundled families (the
/// measurement is in `test/features/journey/journey_glyph_test.dart`), and they
/// are the widget's own text rather than a translated string — the prototype
/// writes them as literal `·` between its spans, in its markup, and the i18n
/// table has no row for them.
///
/// ## THE COUNTS GO THROUGH `digits`
///
/// The prototype's `updateSkyWidget` (`:1186-1187`) writes
/// `el('jSkyN').textContent = N(starCount())`, and `N()` (`:981`) maps the
/// digits to Arabic-Indic on the Arabic arm. `digits` is this client's
/// equivalent.
class JourneySkyLine extends StatelessWidget {
  /// The line, with [stars] lit and [constellations] drawn.
  const JourneySkyLine({
    required this.stars,
    required this.constellations,
    super.key,
  });

  /// How many stars the reader has lit.
  final int stars;

  /// How many constellations the reader has drawn.
  final int constellations;

  /// The gap above the line — `eva/redesign.html:596`'s `margin:4px 0 0`.
  static const double gapAbove = 4;

  /// The line's size — `eva/redesign.html:30`'s `font-size:10.5px`, the
  /// `.mono` rule's own size.
  static const double size = 10.5;

  /// The line's Latin tracking — `eva/redesign.html:30`'s
  /// `letter-spacing:.16em`.
  ///
  /// **Transcribed as the resolved value and not as `em`.**
  /// `TextStyle.letterSpacing` is a **logical-pixel advance** and CSS's `em`
  /// is relative to the element's own font size, so `.16em` at [size] (10.5px)
  /// is **1.68**. The house's own twin of this rule — `EvaSectionHeader`'s
  /// section label, which draws the same `.mono` caption — premultiplies the
  /// same `.16em` by the same 10.5px and arrives at the same number.
  static const double tracking = 1.68;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final AppLocalizations strings = context.l10n;

    final TextStyle base = arabicAware(
      EvaTypography.monoCaps(colors).copyWith(
        fontSize: size,
        letterSpacing: direction == TextDirection.rtl ? 0 : tracking,
        // The inline `color:var(--ink-1)` at `:596`, which overrides the
        // `.mono` rule's own `--ink-2` at `:30`.
        color: colors.ink2,
      ),
      direction,
    );

    // `:31` — `.mono b{color:var(--gold);font-weight:600}`.
    final TextStyle bold = base.copyWith(
      color: colors.emberInk,
      fontWeight: FontWeight.w600,
    );

    String caps(String text) => monoCapsText(text, direction);

    return Padding(
      padding: const EdgeInsets.only(top: gapAbove),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: caps(strings.journeySky)),
            const TextSpan(text: ' · '),
            TextSpan(text: strings.digits(stars), style: bold),
            const TextSpan(text: ' '),
            TextSpan(text: caps(strings.journeyStarsLit)),
            const TextSpan(text: ' · '),
            TextSpan(text: strings.digits(constellations), style: bold),
            const TextSpan(text: ' '),
            TextSpan(text: caps(strings.journeyConstellations)),
          ],
        ),
        textAlign: TextAlign.center,
        style: base,
      ),
    );
  }
}
