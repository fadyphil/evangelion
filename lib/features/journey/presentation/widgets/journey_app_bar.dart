import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The journey's app bar — `eva/redesign.html:576-583`.
///
/// ```html
/// <div class="appbar"><div class="abrow">
///   <span style="width:68px"></span>
///   <span class="ttl" data-i18n="journey">Journey</span>
///   <span class="abgroup">
///     <button class="iconbtn" id="toBoard" title="communion">…a trophy…</button>
///     <button class="iconbtn" id="toSettings" title="settings">⚙</button>
///   </span>
/// </div></div>
/// ```
///
/// ## THE BACK CHEVRON IS **NOT** IN THE PROTOTYPE, AND NOW NEITHER IS IT HERE
///
/// The prototype's journey has **no** back control: `:578` is a `<span
/// style="width:68px">` — a spacer whose only job is to balance the two 30px
/// `.iconbtn`s and their 8px gap (`:156`) against the empty left of the row.
///
/// **The journey is a dock tab in the prototype** (`.dtab[data-r="journey"]`,
/// `:707`) and so it never needs a way back. **In this client it was pushed**,
/// until Phase 6's dock existed — and a pushed screen on desktop has no system
/// back button, so without a chevron there was **no way out of `/journey` at
/// all** for a keyboard-only reader.
///
/// **Phase 6 made the journey a tab, and the chevron went with the reason.**
/// The spacer is the prototype's own (`:578`), and the divergence this file
/// carried is discharged. `/communion` keeps its chevron, because the
/// prototype's board has one (`:614`) — it is reached from the journey as well
/// as from the dock.
///
/// ## THE TWO BUTTONS ARE THE PROTOTYPE'S TWO **DIFFERENT** GLYPHS
///
/// `:581` is a **six-path SVG chalice** and `:582` is a **text glyph** `⚙`.
/// **Neither can be typed here**: U+2699 is in **no** bundled family (measured
/// — `test/features/journey/journey_glyph_test.dart` asserts it), and the
/// trophy is a drawing, not a character. So both become Material icons, which
/// is recorded decision 31's class — **the role is kept and the glyph is the
/// framework's**:
///
/// | prototype | here | why |
/// | --- | --- | --- |
/// | `:581`'s six-path SVG | `Icons.emoji_events` | a Material trophy |
/// | `:582`'s `⚙` U+2699 | `Icons.settings` | U+2699 is in no bundled family |
///
/// **The trophy keeps the pill's 15px** (`:155`'s `.iconbtn svg{width:15px;
/// height:15px}`) and **the gear is 12px**, because the gear is a *text* glyph
/// and `:151`'s `.iconbtn` sets `font-size:12px` for text content. That
/// difference is the prototype's own, and it survives here.
///
/// ## THE TOOLTIPS' FAMILY IS RESOLVED, AND IT IS TASK 5.5'S LESSON
///
/// `Tooltip` has **no `textStyle` default**: a tooltip with no style of its own
/// resolves to the theme's `bodyMedium`, which is the **Latin** UI face
/// (`Inter`) — and `Inter` carries no Arabic glyph at all. The bilingual gate
/// reported exactly that for `/communion` and `/reading`.
///
/// So the family is resolved the way `communion_app_bar.dart` resolves it —
/// `arabicAwareFamily(direction, EvaTypography.uiFamily)` — and handed to each
/// `IconActionButton` as its **required** `tooltipFamily`.
///
/// ## THE TOOLTIPS ARE THE **ROWS'** STRINGS
///
/// `:581`'s `title="communion"` and `:582`'s `title="settings"` are the same
/// two rows the account section draws (`:605` and `:606`), so the tooltips
/// are `journeyRowBoard` and `journeyRowSettings`. **One string, two places** —
/// a tooltip and its row cannot drift apart, because they are the same
/// constant.
class JourneyAppBar extends StatelessWidget {
  /// Creates the app bar for `/journey`.
  const JourneyAppBar({
    required this.onOpenBoard,
    required this.onOpenSettings,
    super.key,
  });

  /// Invoked when the trophy is pressed — the board.
  final VoidCallback onOpenBoard;

  /// Invoked when the gear is pressed — the settings.
  final VoidCallback onOpenSettings;

  /// The empty left of the app-bar row — `eva/redesign.html:578`.
  ///
  /// `<span style="width:68px"></span>` — a spacer, and its only job is to
  /// balance the two 30px `.iconbtn`s and their 8px gap (`:156`) against the
  /// empty left of the row. **It is where the back chevron used to be**, and the
  /// class doc says why it is gone.
  static const double leadingSpacerWidth = 68;

  /// The gear's size — `eva/redesign.html:151`'s `.iconbtn{font-size:12px}`.
  ///
  /// The gear is a **text** glyph in the prototype, so it takes the rule's own
  /// 12px rather than `:155`'s 15px, which is the size of an **`<svg>`** child.
  static const double gearIconSize = 12;

  /// The title's size — `eva/redesign.html:145`'s `font-size:15px`.
  static const double titleSize = 15;

  /// The title's tracking — `eva/redesign.html:145`'s `letter-spacing:-.01em`.
  ///
  /// **Transcribed as the resolved value and not as `em`**: `TextStyle
  /// .letterSpacing` is in logical pixels and a fraction of the size would
  /// re-derive the same number at every call site, so `-.01em` at [titleSize]
  /// (15px) is **−0.15**. `/reading`'s own app bar title is the same rule at
  /// the same size and carries the same resolved number.
  static const double titleTracking = -0.15;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final TextDirection direction = Directionality.of(context);
    final AppLocalizations strings = context.l10n;

    // §14 and Task 5.5's lesson: a `Tooltip` with no `textStyle` resolves to
    // `bodyMedium`, which carries no Arabic glyph.
    final String tooltipFamily = arabicAwareFamily(
      direction,
      EvaTypography.uiFamily,
    );

    return Padding(
      // `:142`'s `padding:46px 18px 4px`, with the 46 replaced by 12 — the
      // same recorded divergence `communion_app_bar.dart` carries, and for the
      // same reason: the 46 is the phone's own status bar, and this app's
      // scaffold already insets for it.
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // The absolutely centred title — `:144-145`.
            FractionallySizedBox(
              widthFactor: 0.52,
              child: Text(
                strings.journeyTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arabicAware(
                  text.titleMedium!.copyWith(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: titleTracking,
                    color: colors.ink,
                  ),
                  direction,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // **The prototype's 68px spacer** (`:578`), where the back
                // chevron used to be. The journey is a tab, and a tab has no way
                // back — see the class doc.
                const SizedBox(width: JourneyAppBar.leadingSpacerWidth),
                // `.abgroup{display:flex;gap:8px}` — `:156`.
                Row(
                  children: <Widget>[
                    IconActionButton(
                      icon: Icons.emoji_events,
                      // `:155`'s 15px — the prototype's trophy is an `<svg>`.
                      iconSize: IconActionButton.pillIconSize,
                      pilled: true,
                      tooltip: strings.journeyRowBoard,
                      tooltipFamily: tooltipFamily,
                      onPressed: onOpenBoard,
                    ),
                    const SizedBox(width: 8),
                    IconActionButton(
                      icon: Icons.settings,
                      iconSize: JourneyAppBar.gearIconSize,
                      pilled: true,
                      tooltip: strings.journeyRowSettings,
                      tooltipFamily: tooltipFamily,
                      onPressed: onOpenSettings,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
