import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The reader's name, centred under the orb — `eva/redesign.html:587`'s
/// `<div class="jname" id="jName">Mariam Hanna</div>`.
///
/// ## THE TWO ARMS, AND WHY THE ARABIC ONE IS **NOT** 22px
///
/// `:396` is `.jname{text-align:center;font-family:var(--scr);font-size:22px;
/// font-weight:600}` and `:397` is `[dir=rtl] .jname{font-family:var(--ui-ar);
/// font-size:19px}`. So the size is **22 on the Latin arm and 19 on the Arabic
/// one** — the prototype's own two-arm rule, and the reason this widget reads
/// the ambient [TextDirection] rather than the locale.
///
/// ## THE FAMILY, AND WHERE IT DEPARTS FROM `:397`
///
/// The prototype's Arabic arm names `--ui-ar` — IBM Plex Sans Arabic. **This
/// widget renders the Arabic arm in Amiri**, which is `arabicAware`'s rule and
/// the bilingual gate's: `test/support/arabic_typography_gate.dart` requires
/// **one** Arabic family for the whole arm, and the house has settled on Amiri
/// (recorded decision 74, and `greeting_block.dart`'s `.hi` line is the same
/// departure for the same reason). A single family for the whole arm is worth
/// more than a per-rule family, and the divergence is recorded here rather than
/// left for a reader to find in a font name.
///
/// ## THE COLOUR
///
/// The prototype's `.jname` sets no colour, so it inherits `--ink-0` from
/// `.screen` — `EvaColors.ink`.
class JourneyReaderName extends StatelessWidget {
  /// The reader's name, as the session has it.
  const JourneyReaderName({required this.name, super.key});

  /// The reader's display name.
  ///
  /// **The session's, and never a literal.** `:587` writes the prototype's own
  /// "Mariam Hanna" and `:992` writes it again from JavaScript; this client's
  /// is the reader's own session, and a profile screen that greets a reader by
  /// a fixture's name is a fixture.
  final String name;

  /// The Latin arm's size — `eva/redesign.html:396`'s `font-size:22px`.
  static const double size = 22;

  /// The Arabic arm's size — `eva/redesign.html:397`'s `font-size:19px`.
  static const double sizeArabic = 19;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: arabicAware(
        EvaTypography.textTheme(colors).headlineSmall!.copyWith(
          fontFamily: EvaTypography.scriptureFamily,
          fontSize: direction == TextDirection.rtl ? sizeArabic : size,
          fontWeight: FontWeight.w600,
          color: colors.ink,
        ),
        direction,
      ),
    );
  }
}

/// The role line under the name — `eva/redesign.html:588`'s
/// `<div class="jrole mono" data-i18n="scribe">scribe · level 7</div>`.
///
/// ## THE COPY IS TRANSCRIBED, AND THE "7" IS DERIVED FROM NOTHING
///
/// The prototype's string is an i18n row (`:933`) with **a level baked into it**
/// — "scribe · level 7" / "كاتبة · المستوى ٧". **There is no levels endpoint**:
/// the backend's fourteen routes carry no level, rank or title, so the whole
/// line is transcribed copy and the "7" is the prototype's own literal.
///
/// The alternative — a real level — would mean a number this client cannot
/// produce, and the honest options are both worse: a stub would be a new
/// fiction, and a bare "scribe" would drop a word the prototype wrote. So the
/// copy is transcribed, and the transcription is recorded here.
///
/// ## THE `.mono` GEOMETRY, AND THE TWO RTL RULES
///
/// `:30` is `.mono{font-family:var(--mono);font-size:10.5px;letter-spacing:.16em;
/// text-transform:uppercase;color:var(--ink-2)}`, and the two RTL rules are
/// `:135` (`letter-spacing:0`) and `:136` (`text-transform:none`).
///
/// **The tracking and the uppercasing are the widget's own, not the style's**,
/// because Flutter has no `text-transform`: `monoCapsText` uppercases the
/// string under LTR and leaves it alone under RTL, and the tracking is dropped
/// on the Arabic arm — a cursive script with `.16em` of tracking has its joined
/// letterforms pulled apart, which is what `:135` is for.
///
/// **The tracking itself is the resolved 1.68 and not the `.16em`** — see
/// [tracking], which says why.
///
/// ## THE VERTICAL GAPS ARE **THE PROTOTYPE'S** AND THEY LIVE HERE
///
/// `:398` is `.jrole{text-align:center;margin:4px 0 14px}` — 4px above the
/// line and 14px below it. Both are this widget's, so the page's composition
/// does not have to know them.
class JourneyRoleLine extends StatelessWidget {
  /// The transcribed role line.
  const JourneyRoleLine({super.key});

  /// The gap above the line — `eva/redesign.html:398`'s `margin:4px 0 14px`.
  static const double gapAbove = 4;

  /// The gap below the line — `eva/redesign.html:398`'s `margin:4px 0 14px`.
  static const double gapBelow = 14;

  /// The mono size — `eva/redesign.html:30`'s `font-size:10.5px`.
  static const double size = 10.5;

  /// The Latin arm's tracking — `eva/redesign.html:30`'s `letter-spacing:.16em`.
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

    return Padding(
      padding: const EdgeInsets.only(top: gapAbove, bottom: gapBelow),
      child: Text(
        monoCapsText(context.l10n.journeyScribe, direction),
        textAlign: TextAlign.center,
        style: arabicAware(
          EvaTypography.monoCaps(colors).copyWith(
            fontSize: size,
            letterSpacing: direction == TextDirection.rtl ? 0 : tracking,
            // `--ink-2` — the `.mono` rule's own ink at `:30`. The house maps the
            // prototype's `--ink-2` onto `ink2`; see `greeting_block.dart`'s
            // `.mono` caption for the same mapping.
            color: colors.ink2,
          ),
          direction,
        ),
      ),
    );
  }
}
