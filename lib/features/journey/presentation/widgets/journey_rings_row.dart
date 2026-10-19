import 'dart:math' as math;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// One of the journey's three progress rings.
///
/// ## THE FOUR NUMBERS A RING IS, AND WHY THEY ARE **PARAMETERS**
///
/// The prototype's three rings are `eva/redesign.html:592`, `:593` and `:594`,
/// and each is one `<svg width="64" height="64">` with two
/// `<circle cx="32" cy="32" r="26">` and two `div`s under it. The **geometry**
/// is the same for all three and lives in [JourneyRingsRow]; what differs is
/// the **label**, the **value** and the **colour**, and those are the
/// reader's own — the fractions are derived from the streak history, not
/// written by a prototype.
///
/// So this is a value, not a widget: the page hands the row three of them and
/// the row draws the three rings.
class JourneyRing {
  /// A ring labelled [label], showing [value], drawn [fraction] of the way round
  /// in [stroke].
  const JourneyRing({
    required this.label,
    required this.value,
    required this.fraction,
    required this.stroke,
  });

  /// The ring's caption — `eva/redesign.html:407`'s `.rl`.
  ///
  /// **The localized label**: "verses" / "آيات" (`:935`).
  final String label;

  /// The number inside the ring — `eva/redesign.html:407`'s `.rv`.
  ///
  /// **The localized, digit-transformed text**, and the page's to compose:
  /// `journey_l10n.dart`'s `journeyPercent` for the two ratios and
  /// `AppLocalizations.digits` for the bare count. The prototype's ring 2
  /// carries **no** percent sign (`:593`'s `data-v="86"`, where its neighbours
  /// write `83%` and `92%`), and that inconsistency was resolved deliberately
  /// rather than transcribed: a percent sign on a count would be a unit the
  /// number does not have.
  final String value;

  /// How much of the circle is drawn, `0.0`…`1.0`.
  ///
  /// The prototype's `data-p` — `.83`, `.86`, `.92` at `:592-594` — which are
  /// decoration backed by nothing. Ours are derived from the reader's own
  /// streak history.
  final double fraction;

  /// The arc's ink.
  ///
  /// From `journey_colours.dart`: the teal of `:592`, the magenta of `:593`
  /// (which is the `bloom` token at full alpha) and the blue of `:594`.
  final Color stroke;
}

/// The three progress rings — `eva/redesign.html:591-595`'s `<div class="rings">`.
///
/// ## THE GEOMETRY, MEASURED
///
/// | what | number | where |
/// | --- | --- | --- |
/// | the row's gap | 26 | `:401` — `gap:26px` |
/// | the row's own margins | 20 over, 8 under | `:401` — `margin:20px 0 8px` |
/// | the ring's box | 64×64 | `:592` — `<svg width="64" height="64">` |
/// | the ring's radius | 26 | `:592` — `<circle cx="32" cy="32" r="26">` |
/// | the stroke's width | 6 | `:404` — `stroke-width:6` |
/// | the cap | round | `:404` — `stroke-linecap:round` |
/// | the dash array | 163 | `:406` — `stroke-dasharray:163` |
/// | the value's pull | 34 | `:407` — `margin-top:-34px` |
/// | the label's gap | 16 | `:408` — `margin-top:16px` |
/// | the label's tracking | 1.19 | `:408` — `letter-spacing:.14em` at 8.5px |
///
/// **163 is 2π·26 = 163.36, rounded.** The prototype's dash array is the whole
/// circumference, so `stroke-dashoffset: 163·(1−p)` draws exactly the fraction
/// `p` of the circle. This implementation draws the same fraction — see
/// [JourneyRingPainter.sweepAngle] for the 0.36px the rounding costs.
///
/// ## THE ARC STARTS AT **TWELVE O'CLOCK**
///
/// `:403` is `.ringbox svg{transform:rotate(-90deg)}` — the whole `<svg>` is
/// turned, so the arc's zero is at the top rather than at the right. The
/// painter's [JourneyRingPainter.startAngle] is that rotation, and it is
/// asserted rather than assumed.
///
/// ## THE ANIMATION: ONE SHOT, 200ms, THEN 1.1s
///
/// `:1450-1451`'s `animateRings()` sets every `.fgc`'s `stroke-dashoffset` to
/// 163, then **after 200ms** sets it to `163·(1−p)`, and `:406`'s
/// `transition:stroke-dashoffset 1.1s var(--e-light)` does the drawing.
///
/// * **It runs on entry, not on scroll.** The prototype calls `animateRings()`
///   from `tab(to)` and `jump(to)` when the route is `journey` (`:1269`,
///   `:1272`), so it is **one shot when the screen appears** and **not**
///   re-run when the data changes. The controller here is started once and
///   never restarted, so a rebuild with new fractions keeps the arcs at their
///   final sweep.
/// * **Reduced motion kills it — and the prototype's does not.**
///   `MediaQuery.disableAnimationsOf(context)` draws the rings at their final
///   sweep with no transition. **This is §14's rule and not the prototype's.**
///   The prototype's `.rm` (`:48-50`) sets `animation:none!important` on a
///   list that does **not** include `.fgc`, and the ring's draw is a
///   **`transition`** on `stroke-dashoffset` (`:406`) — so the prototype's
///   reduced motion does **not** kill the ring transition. The two
///   reduced-motion rules that do touch a transition are `:52` (`.vline`) and
///   `:53` (`.brow`, `.podbar`), and the ring is in neither. §14's rule
///   (`docs/plans/09-quality-gates.md:187` — "when disabled, jump straight to
///   the end state") is why this client does it anyway.
/// * **The 1.1s has no `EvaMotion` token** — the table tops out at `screen`
///   250ms and `fleck` 2s — so it is a constant **here**, in the feature that
///   owns the citation, rather than a change to the design system's table.
/// * **The curve is the prototype's own bezier, and it is a feature-local
///   constant.** `--e-light` is `cubic-bezier(.16,1,.3,1)` (`:18`), and
///   `EvaMotion.interactiveCurve` is **not** that curve — it is
///   `Curves.easeOutExpo`, which is `Cubic(0.19, 1.0, 0.22, 1.0)`. The token
///   is an **approximation** of the prototype's bezier, and the
///   approximation is close: measured over the interval this widget drives
///   (`200/1300 … 1`), the two differ by at most **1.79%** of the draw's
///   progress, and by **2.53%** over the whole curve. The prototype's own
///   bezier is transcribed here, and `EvaMotion` is not changed by this
///   screen. See [drawCurve].
///
/// ## THE TRACK'S INK
///
/// `:405` is `.ringbox .bgc{stroke:rgba(255,255,255,.08)}` in dark, and `:79`
/// overrides it to `rgba(20,22,30,.1)` in light. This widget uses
/// [EvaColors.glassBorder], which is 8% white in dark and 8% black in light —
/// the sanctioned "glass line" token and the research's own recommendation. The
/// light arm is therefore **8% black where the prototype says 10%**; the
/// difference is two points of a hairline, and it is recorded rather than
/// papered over with a second token.
class JourneyRingsRow extends StatefulWidget {
  /// The three rings, in the prototype's order: verses, quizzes, accuracy.
  const JourneyRingsRow({required this.rings, super.key});

  /// The rings to draw.
  final List<JourneyRing> rings;

  /// The row's gap — `eva/redesign.html:401`'s `gap:26px`.
  static const double gap = 26;

  /// The row's own top margin — `eva/redesign.html:401`'s
  /// `margin:20px 0 8px`.
  ///
  /// **The prototype's own margin on the `.rings` element**, and not the
  /// column's: the row brings its own vertical space, so the page's
  /// composition does not have to know it.
  static const double gapAbove = 20;

  /// The row's own bottom margin — `eva/redesign.html:401`'s
  /// `margin:20px 0 8px`.
  static const double gapBelow = 8;

  /// The ring's box — `eva/redesign.html:592`'s `<svg width="64" height="64">`.
  static const double ringSize = 64;

  /// The ring's radius — `eva/redesign.html:592`'s `<circle r="26">`.
  static const double ringRadius = 26;

  /// The stroke's width — `eva/redesign.html:404`'s `stroke-width:6`.
  static const double strokeWidth = 6;

  /// The dash array — `eva/redesign.html:406`'s `stroke-dasharray:163`.
  ///
  /// **163 is 2π·26 = 163.3628, rounded to the nearest whole number** — the
  /// prototype's own number, and the number the arc's geometry is read from.
  static const double dashArray = 163;

  /// How far the value is pulled **up** so it sits inside the ring —
  /// `eva/redesign.html:407`'s `margin-top:-34px`.
  static const double valuePull = 34;

  /// The gap between the value and the label —
  /// `eva/redesign.html:408`'s `margin-top:16px`.
  static const double labelGap = 16;

  /// The value's size — `eva/redesign.html:407`'s `font-size:11px`.
  static const double valueSize = 11;

  /// The label's Latin size — `eva/redesign.html:408`'s `font-size:8.5px`.
  static const double labelSize = 8.5;

  /// The label's Arabic size — `eva/redesign.html:409`'s `font-size:10px`.
  static const double labelSizeArabic = 10;

  /// The label's Latin tracking — `eva/redesign.html:408`'s
  /// `letter-spacing:.14em`.
  ///
  /// **Transcribed as the resolved value and not as `em`.**
  /// `TextStyle.letterSpacing` is a **logical-pixel advance** and CSS's `em`
  /// is relative to the element's own font size, so `.14em` at [labelSize]
  /// (8.5px) is **1.19**. The design system's own twin of this rule —
  /// `StatTile`, which draws the same `:408` caption — premultiplies the
  /// same `.14em` by the same 8.5px and arrives at the same number.
  static const double labelTracking = 1.19;

  /// The delay before the draw starts — `eva/redesign.html:1451`'s
  /// `setTimeout(…, 200)`.
  static const Duration entranceDelay = Duration(milliseconds: 200);

  /// The draw's own length — `eva/redesign.html:406`'s
  /// `transition:stroke-dashoffset 1.1s var(--e-light)`.
  ///
  /// **A feature-local constant, and not an `EvaMotion` token**: the motion
  /// table has no 1.1s row, and adding one is a design-system change this
  /// phase does not own. The number and its citation live here, beside the
  /// widget that uses it.
  static const Duration drawDuration = Duration(milliseconds: 1100);

  /// The whole entrance — the delay and then the draw.
  static const Duration entranceDuration = Duration(milliseconds: 200 + 1100);

  /// The draw's curve — `eva/redesign.html:18`'s `--e-light`, transcribed.
  ///
  /// **A feature-local constant, and not `EvaMotion.interactiveCurve`.** The
  /// prototype's `--e-light` is `cubic-bezier(.16,1,.3,1)` (`:18`), and the
  /// design system's token is `Curves.easeOutExpo` — which is
  /// `Cubic(0.19, 1.0, 0.22, 1.0)`, **not** that bezier. The token is an
  /// **approximation** of the prototype's curve, and the approximation is
  /// close: measured over the interval this widget drives (`200/1300 … 1`),
  /// the two curves differ by at most **1.79%** of the draw's progress, and
  /// by **2.53%** over the whole curve (the worst of it at x ≈ 0.054, before
  /// the draw's own delay).
  ///
  /// The prototype's own bezier is therefore transcribed **here**, beside the
  /// citation that owns it, and `EvaMotion` is left alone — the token table
  /// is the design system's, and this phase does not own it.
  static const Curve drawCurve = Cubic(0.16, 1, 0.3, 1);

  @override
  State<JourneyRingsRow> createState() => _JourneyRingsRowState();
}

class _JourneyRingsRowState extends State<JourneyRingsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The draw's progress, `0`…`1`.
  ///
  /// **Driven through a `CurveTween` and not a `CurvedAnimation`**, for
  /// `communion_podium.dart`'s reason: a `CurvedAnimation` adds a status
  /// listener to its parent on every construction, and this one is built once
  /// and kept.
  late final Animation<double> _progress;

  /// Whether the entrance has been started.
  ///
  /// A flag rather than a bare `forward()`, because `didChangeDependencies`
  /// runs again when the ambient `MediaQuery` changes and the entrance is
  /// **one shot**.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: JourneyRingsRow.entranceDuration,
    );
    _progress = _controller.drive(
      CurveTween(
        curve: const Interval(
          200 / 1300,
          1,
          // `:18`'s `--e-light` — the prototype's own bezier. See [drawCurve]
          // for why this is not `EvaMotion.interactiveCurve`.
          curve: JourneyRingsRow.drawCurve,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // §14: reduced motion draws the rings at their final sweep, with no
    // transition. The prototype's `.rm` does the same (`:49`).
    if (!MediaQuery.disableAnimationsOf(context)) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    // **The `AnimatedBuilder` is load-bearing.** An `AnimationController`
    // notifies its listeners, and a widget that only *reads* its value does
    // not rebuild when it changes — so without this the arcs would be painted
    // once, at fraction zero, and would stay that way for the whole entrance.
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double progress = animate ? _progress.value : 1;

        return Padding(
          // `:401`'s `margin:20px 0 8px` — the row's own vertical margins, on
          // the row.
          padding: const EdgeInsets.only(
            top: JourneyRingsRow.gapAbove,
            bottom: JourneyRingsRow.gapBelow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (
                int index = 0;
                index < widget.rings.length;
                index++
              ) ...<Widget>[
                if (index > 0) const SizedBox(width: JourneyRingsRow.gap),
                _RingBox(ring: widget.rings[index], progress: progress),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One ring and its two captions.
///
/// ## WHY THE LAYOUT IS A **STACK** AND NOT A COLUMN
///
/// The prototype's `.rv` is pulled **up** by 34px (`:407`'s `margin-top:-34px`)
/// so the number sits **inside** the ring, and `.rl` is 16px below it
/// (`:408`). A negative margin has no Flutter spelling, and a `Transform`
/// alone would move the paint but not the layout — so the label would sit 34px
/// lower than the prototype's and the ring box would be 34px taller.
///
/// A `Stack` says exactly what the CSS says: the value and the label are one
/// block that starts 30px down (64 − 34), and the ring is painted **behind**
/// them. The first child of a `Stack` paints **on top** (the SDK paints the
/// children in reverse), so the captions come first and the ring second.
class _RingBox extends StatelessWidget {
  const _RingBox({required this.ring, required this.progress});

  final JourneyRing ring;

  /// The entrance's progress, `0`…`1`.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return ConstrainedBox(
      // The ring is 64 wide and the captions are narrower, so the box has to be
      // **at least** the ring's width — the prototype's `.ringbox` is as wide as
      // its widest child and the `<svg>` is 64 of them, so the ring is centred
      // in a box that is never narrower than itself.
      constraints: const BoxConstraints(minWidth: JourneyRingsRow.ringSize),
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          // The value and the label — the stack's sizing child, painted on top.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: JourneyRingsRow.ringSize - JourneyRingsRow.valuePull,
              ),
              // `.rv` — mono 11px, `--ink-0`.
              //
              // **The Arabic arm renders the digit in Amiri**, because the value is
              // an Arabic-Indic numeral on that arm and JetBrains Mono carries no
              // Arabic glyph at all. The prototype has no RTL rule for `.rv` and
              // would tofu; `arabicAware` is the house's answer to that.
              //
              // **And the value carries no tracking, written out.** `:407`
              // declares no `letter-spacing` — `.rv` is not `.mono`, so it
              // inherits none from `:30` either — and the prototype's value is
              // therefore `normal`. `EvaTypography.monoCaps` carries
              // `labelMedium`'s **0.5**, so the zero is spelled out rather
              // than left inherited, for `StatTile`'s reason: the design
              // system's own twin of `:407` writes the same zero.
              Text(
                ring.value,
                textAlign: TextAlign.center,
                style: arabicAware(
                  EvaTypography.monoCaps(colors).copyWith(
                    fontSize: JourneyRingsRow.valueSize,
                    letterSpacing: 0,
                    color: colors.ink,
                  ),
                  direction,
                ),
              ),
              const SizedBox(height: JourneyRingsRow.labelGap),
              // `.rl` — mono 8.5px, `.14em`, uppercase, `--ink-1`.
              //
              // **The tracking is the resolved 1.19 and not the `.14em`** —
              // see [labelTracking], which says why.
              //
              // `:409` is the RTL arm: `--ui-ar` at 10px, no tracking and no
              // uppercasing. The family is the house's Amiri rather than the
              // prototype's `--ui-ar`, for the reason `JourneyReaderName`'s doc
              // gives — the bilingual gate requires one Arabic family for the
              // whole arm.
              Text(
                monoCapsText(ring.label, direction),
                textAlign: TextAlign.center,
                style: arabicAware(
                  EvaTypography.monoCaps(colors).copyWith(
                    fontSize: direction == TextDirection.rtl
                        ? JourneyRingsRow.labelSizeArabic
                        : JourneyRingsRow.labelSize,
                    letterSpacing: direction == TextDirection.rtl
                        ? 0
                        : JourneyRingsRow.labelTracking,
                    color: colors.ink2,
                  ),
                  direction,
                ),
              ),
            ],
          ),
          // The ring — painted behind, and centred the way `:402`'s
          // `text-align:center` centres the prototype's inline `<svg>`.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: JourneyRingsRow.ringSize,
            child: Center(
              child: SizedBox.square(
                dimension: JourneyRingsRow.ringSize,
                child: CustomPaint(
                  painter: JourneyRingPainter(
                    fraction: ring.fraction * progress,
                    stroke: ring.stroke,
                    track: colors.glassBorder,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints one ring: the track, and the arc that grows over it.
///
/// ## WHY THE ARC IS **DRAWN** AND NOT DASHED
///
/// `eva/redesign.html:406` is
/// `stroke-dasharray:163;stroke-dashoffset:163;transition:stroke-dashoffset
/// 1.1s var(--e-light)`, and Flutter's [Paint] has **no dash pattern** — there
/// is no `strokeDashArray` to set and no `strokeDashOffset` to animate. So the
/// arc is a `drawArc` over the same circle, and the animation drives the
/// **fraction** rather than the offset, which is the same number: the
/// prototype's `stroke-dashoffset` is `163·(1−p)` (`:1451`), and the fraction
/// this painter draws is `p`.
///
/// ## THE SWEEP IS `2π·p`, AND THE 163.36 IS RECORDED
///
/// The prototype's dash array is **163**, and the circle's circumference is
/// **2π·26 = 163.3628**. The prototype's own arithmetic therefore leaves
/// 0.36px of the circle undrawn at `p = 1` — which the 3px round cap covers,
/// invisibly. This painter draws the exact `2π·p`, so the arc is **0.22%
/// longer** than the prototype's at any `p` and closes the gap the rounding
/// left. The difference is recorded here rather than reproduced, because
/// reproducing it would mean shipping a 0.36px hole in a ring that is supposed
/// to be full.
class JourneyRingPainter extends CustomPainter {
  /// Paints a ring showing [fraction] of its circumference in [stroke], over a
  /// [track].
  const JourneyRingPainter({
    required this.fraction,
    required this.stroke,
    required this.track,
  });

  /// How much of the circle is drawn, `0.0`…`1.0`.
  final double fraction;

  /// The arc's ink.
  final Color stroke;

  /// The track's ink.
  final Color track;

  /// Where the arc starts — **twelve o'clock**.
  ///
  /// `eva/redesign.html:403`'s `.ringbox svg{transform:rotate(-90deg)}` turns
  /// the whole `<svg>`, so the arc's zero is at the top and not at the right.
  double get startAngle => -math.pi / 2;

  /// The arc's sweep, in radians — `2π·fraction`.
  double get sweepAngle => 2 * math.pi * fraction;

  /// The prototype's `stroke-dashoffset` for this fraction.
  ///
  /// `eva/redesign.html:1451`'s `163·(1−p)`. **The prototype's own number**,
  /// and the one the draw is derived from.
  double get dashOffset => JourneyRingsRow.dashArray * (1 - fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = JourneyRingsRow.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, JourneyRingsRow.ringRadius, trackPaint);

    if (sweepAngle <= 0) return;
    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = JourneyRingsRow.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: JourneyRingsRow.ringRadius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(JourneyRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.stroke != stroke ||
      oldDelegate.track != track;
}
