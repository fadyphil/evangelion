import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The reader's orb — `eva/redesign.html:586`'s `<div class="jorb">M</div>`.
///
/// ## IT IS [SealMonogram] AT 74, AND **NOT** A NEW WIDGET
///
/// `:392` is `width:74px;height:74px`, and `SealMonogram`'s own doc says the 74
/// is "Phase 5.6's number, not this widget's" — so the widget's own
/// `defaultSize` stays **60** (`login_geometry_test.dart` asserts the painted
/// seal at 60×60 by literal) and **this screen passes 74**. The treatment
/// `:392-395` owns — the wash's centre, the glyph's ink, the rim — is already
/// adopted there, and a second orb widget would be a second copy of it.
///
/// ## THE LETTER IS THE READER'S, NOT THE PROTOTYPE'S `M`
///
/// `:586` writes a literal `M`, the initial of the prototype's literal name
/// "Mariam Hanna" (`:587`, written at `:992`). Ours is the session's own
/// monogram, so the orb is the reader's and not a transcription of a fixture.
///
/// ## THE TWO DIVERGENCES, RECORDED HERE BECAUSE THEY ARE THIS WIDGET'S
///
/// 1. **The glyph's ratio.** `:394` is `font-size: 30px` on a 74px orb — a ratio
///    of **0.405**. [SealMonogram]'s own ratio is **0.4667** (the superseded
///    prototype's 28 on 60), so the letter here is **34.5px** in a 74px orb rather than
///    30px. The widget's doc says why the two ratios differ: they are two
///    different marks at two different sizes, and the login harness holds the
///    seal's box at 60. Changing the ratio here would move the glyph inside a
///    box the design system owns.
/// 2. **The rim's ripple is not drawn.** `:395` is
///    `border:1.5px solid rgba(232,176,75,.5); animation:ripple 3s var(--e-out)
///    infinite` — a `scale(1) → scale(1.6)`, `opacity .8 → 0` loop (`:234`).
///    A Flutter widget has no pseudo-element to hang a keyframe animation on, and
///    `SealMonogram` does not animate. Reduced motion would kill it anyway
///    (`:49`), so what is lost is the *loop*, not the effect: the rim itself is
///    adopted at `:395`'s 1.5px and 50%.
///
/// ## WHY THE ORB NAMES THE READER
///
/// `SealMonogram` publishes a semantics node with a label, and the default label
/// is the app's own wordmark — which would announce "Evangelion" for the
/// reader's own face. So the label is [semanticLabel], and the page passes the
/// session's display name. The visible name is the line below the orb, so the
/// node is the orb's own and not a second copy of that line's.
///
/// ## AND THE ORB'S OWN MARGINS
///
/// `:392` is `.jorb{… margin:10px auto 12px …}` — ten above and twelve below.
/// **They are the orb's, and not the column's**, and they live here for
/// `JourneyRoleLine`'s reason: the widget that draws the prototype's element
/// brings the prototype's own margins with it, so the page's composition does
/// not have to know them. The `auto` between them is the centring, and the
/// column already centres the mark.
class JourneyOrb extends StatelessWidget {
  /// The reader's monogram, drawn in the seal.
  const JourneyOrb({
    required this.monogram,
    required this.semanticLabel,
    super.key,
  });

  /// The glyph in the middle — the session's own initials.
  ///
  /// `:586` writes a literal `M`. Ours is the reader's.
  final String monogram;

  /// The accessible name for the mark.
  ///
  /// The reader's name, not the app's: see the class doc.
  final String semanticLabel;

  /// The orb's diameter — `eva/redesign.html:392`'s `width:74px;height:74px`.
  ///
  /// **A constant of this screen and not of [SealMonogram]**, whose own
  /// `defaultSize` stays 60 for the login harness's reason. See the class doc.
  static const double size = 74;

  /// The orb's own top margin — `eva/redesign.html:392`'s
  /// `margin:10px auto 12px`.
  ///
  /// **The prototype's own margin on the `.jorb` element**, and not the
  /// column's: the orb brings its own vertical space, so the page's
  /// composition does not have to know it.
  static const double gapAbove = 10;

  /// The orb's own bottom margin — `eva/redesign.html:392`'s
  /// `margin:10px auto 12px`.
  static const double gapBelow = 12;

  @override
  Widget build(BuildContext context) => Padding(
    // `:392`'s `margin:10px auto 12px`.
    //
    // **And the `auto` is the centring, which the column already does.**
    // `margin: … auto …` centres the block in its parent, and the column the
    // orb sits in is a stretch column, so the seal's own box spans the column
    // and the mark inside it is centred — the same place `auto` would have
    // put it. Only the two vertical margins need spelling out.
    padding: const EdgeInsets.only(top: gapAbove, bottom: gapBelow),
    child: SealMonogram(
      size: size,
      letter: monogram,
      semanticLabel: semanticLabel,
    ),
  );
}
