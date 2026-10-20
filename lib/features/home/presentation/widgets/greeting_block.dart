import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// `.greet`: the day's caption, the reader's greeting, and the streak chip.
///
/// `redesign.html:514-517`. Two lines on the left and the chip on the right, in a
/// `display: flex; justify-content: space-between; align-items: center` row
/// (`:235`).
///
/// ## AND WHY IT IS ITS OWN FILE WHEN THE SCREEN HAS SIX SECTIONS
///
/// Because `home_geometry_test.dart` transcribes its two font sizes from
/// `:236-237` and a constant nobody outside the file can name is not a constant a
/// test can read. The greeting was a private `_Greeting` inside `home_page.dart`
/// for Phase 5.2's first hour, and the geometry harness is what made that
/// untenable — the same reason the other home widgets are public, and the reason
/// `SocialAuthButton` and `SealFab` were before the redesign deleted both of
/// them.
///
/// ## THE CAPTION IS **MONO** AND THE GREETING IS **SERIF**
///
/// `:515` writes `<div class="mono" id="dayMono">` above `<div class="hi"
/// id="hiName">`, and the two rules are far apart: `.mono` is `10.5px / .16em /
/// uppercase / --ink-2` (`:30`) while `.greet .hi` is `--scr` at `23px`, weight
/// `500` (`:236`). So the small caption sits above a 23px greeting and the pair
/// reads as one line of type, which is the redesign's whole point for that block.
class GreetingBlock extends StatelessWidget {
  /// The greeting row: the caption, the name, and [chip] on the right.
  const GreetingBlock({
    required this.period,
    required this.name,
    required this.chip,
    super.key,
  });

  /// The time of day, from the bloc's clock.
  final GreetingPeriod period;

  /// The reader's name from the session, or `null` when there is none.
  final String? name;

  /// The streak chip, placed by this row rather than drawn by it.
  final Widget chip;

  /// `.hi`'s size. `redesign.html:236` — `.greet .hi{font-size:23px}`.
  static const double nameSize = 23;

  /// `.hi`'s size on the Arabic arm. `redesign.html:237` —
  /// `[dir=rtl] .greet .hi{font-size:20px}`.
  static const double nameSizeArabic = 20;

  /// The gap between the caption and the greeting. `redesign.html:515` writes them
  /// as two sibling `<div>`s with no margin and no line-height of their own, so the
  /// gap is **the space two line boxes leave between them**, which is why it is a
  /// measured number here and not a transcribed one.
  ///
  /// 2 logical pixels, which is what one 10.5px mono line's descender space and one
  /// 23px serif line's ascender space leave at `EvaTypeScale`'s default step.
  /// `home_geometry_test.dart` asserts the rendered gap rather than the CSS, because
  /// the CSS has no declaration to compare it to.
  static const double captionGap = 2;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Row(
      // `align-items: center` — `:235`. **Not named here, because it is Flutter's
      // default for a `Row`** and a redundant argument is a reviewer's question:
      // the chip is 33 tall and the two text lines are taller, so the row's height
      // is the greeting's and the chip sits centred in it rather than on the
      // caption's line.
      //
      // Asserted in `home_geometry_test.dart` as the chip's vertical centre
      // matching the greeting's, so the fact that it is a default is also a claim.
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // `.mono` — `:515`, `id="dayMono"`, which `applyLang` fills with
              // `tr(hourKey())` (`:988`). 10.5px, `.16em`, uppercase, `--ink-2`.
              Text(
                monoCapsText(strings.greetingWord(period), direction),
                style: arabicAware(
                  EvaTypography.monoCaps(colors).copyWith(
                    letterSpacing: direction == TextDirection.rtl ? 0 : 0.16,
                    color: colors.ink2,
                  ),
                  direction,
                ),
              ),
              const SizedBox(height: captionGap),
              // `.hi` — `:515`, `id="hiName"`. `--scr` (EB Garamond) at 23px,
              // weight 500; `[dir=rtl] .greet .hi` at `:237` is `--ui-ar` at 20px.
              //
              // **`arabicAware`, so the Arabic arm renders in Amiri** — the
              // prototype's `--ui-ar` is IBM Plex Sans Arabic and
              // `arabic_typography_gate.dart` requires one Arabic family for the
              // whole arm (`eva_typography.dart`'s `arabicAware` doc is the
              // authority for the swap).
              //
              // **`maxLines: 1` and an ellipsis, which the CSS does not have.**
              // `.hi` is a 23px greeting in a row that also holds a pill, so a long
              // display name would wrap and push the chip off the row's baseline;
              // the name is one token (`home_l10n.dart`'s `firstNameOf`) and the
              // case that breaks it is a two-word display name on a 320px surface.
              // `home_text_scale_test.dart` is what measured it.
              Text(
                strings.peaceWith(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arabicAware(
                  EvaTypography.textTheme(colors).headlineMedium!.copyWith(
                    fontFamily: EvaTypography.scriptureFamily,
                    fontSize: direction == TextDirection.rtl
                        ? nameSizeArabic
                        : nameSize,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                  direction,
                ),
              ),
            ],
          ),
        ),
        // `.greet`'s only `gap`. `:235` declares no `gap` at all — `space-between`
        // is what separates them — so this is **the one spacing number on this row
        // the prototype does not spell out**, and it is 12 because the alternative
        // is the chip touching an ellipsised name at 320px.
        const SizedBox(width: nameToChipGap),
        chip,
      ],
    );
  }

  /// The gap between the greeting and the chip.
  ///
  /// **Written, not transcribed**, and this is the only spacing number on `.greet`
  /// that is: `:235` declares `display: flex; justify-content: space-between` and
  /// **no `gap`**, so the prototype's distance between the two children is whatever
  /// is left of the row. `space-between` distributes slack rather than reserving
  /// any, and with an `Expanded` child there is no slack left at all — the name
  /// block would run to the chip and the two would touch.
  ///
  /// 12 is the smallest gap that reads as a gap at 320px (one 23px line's
  /// side-bearing plus the pill's 11px leading pad), and
  /// `home_geometry_test.dart` asserts the rendered gap so that a change to either
  /// number is visible rather than silent.
  static const double nameToChipGap = 12;
}
