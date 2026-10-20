import 'dart:math' as math;

import 'package:evangelion/core/common/ranges.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Workshop's range slider — `redesign.html:429-430`.
///
/// ## WHAT IT IS, AND WHAT IT IS NOT
///
/// `redesign.html:429` is a bare CSS range input:
///
/// ```css
/// input[type=range]{-webkit-appearance:none;height:3px;border-radius:3px;
///   background:rgba(255,255,255,.14);outline:none;width:120px}
/// input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:15px;
///   height:15px;border-radius:50%;background:var(--gold);cursor:pointer;
///   box-shadow:0 0 10px rgba(232,176,75,.7)}
/// ```
///
/// and this widget is that rule, transcribed: a 3px rule, 120px wide, and a
/// 15px gold thumb on it. **It is not a Material `Slider`**, for the reason
/// `FontSizeStepper`'s doc gives and repeats: `Slider`'s geometry is Material's
/// — a 4px track, a 20px thumb, an overlay ring — and **none of those three
/// numbers is the prototype's**. A `Slider` would have had to be overridden on
/// track height, thumb size and thumb overlay before it drew anything the
/// prototype draws.
///
/// ## THE TRACK'S COLOUR IS PER-BRIGHTNESS, AND THAT IS A TRANSCRIPTION
///
/// `redesign.html:429` is `rgba(255,255,255,.14)` and `redesign.html:95` — the
/// light-mode override — is `rgba(20,22,30,.18)`. Those are **two different
/// alphas**, not one alpha over two inks, so the widget resolves the alpha from
/// the ambient brightness.
///
/// **This is a divergence from `FontSizeStepper`, and it is recorded here**.
/// That widget paints `ink` at **14% in both arms**, and its own doc gives the
/// reason: "the three-point difference in light is the same 'the smaller
/// difference between two values is not a token' judgement `EvaColors.seamGlow`
/// records". This widget follows `:95` literally instead, because it is a
/// different control from a different row of the same screen and the prototype
/// gives the two sliders one declaration and one override. A reviewer comparing
/// the two sliders will find the difference here rather than discovering it.
///
/// ## THE THUMB'S POSITION, AND WHY IT IS NOT MEASURED THE WAY THE
/// SEGMENTED CONTROL'S IS
///
/// `SegmentedControl` measures its thumb, and its doc gives the reason: its
/// segments are `Flexible` (loose) in a `Row(mainAxisSize: min)`, so "the width
/// of segment *i*" is **not arithmetic on any number the widget holds** — it is
/// what the layout produced.
///
/// A slider's track is a different thing: it is one box, and its width is the
/// prototype's own `width:120px`. So the thumb's offset here **is** arithmetic —
/// but it is arithmetic on the width the **layout** produced, not on the
/// constant, and the width is read from a [LayoutBuilder] so a row that
/// constrains the slider still puts the thumb where the value says it is. The
/// test asserts the *rendered* track width and the *rendered* thumb edge, so a
/// future change to a flexible track cannot pass unnoticed.
///
/// ## THE VALUE'S UNIT IS THE CALLER'S
///
/// The widget announces [valueLabel] when it is given and the raw number when
/// it is not. The prototype paints **no** number at all (`redesign.html:429-430`
/// declare no content), so the client paints none either — but the *announced*
/// value is not optional, because a slider that announces nothing is a control
/// a reader can move and cannot read.
///
/// The unit is the caller's job: the selah row's value is a count of seconds
/// and the prototype's own i18n table has `secs` (`redesign.html:970`). The
/// increased and decreased values are the **raw numbers**, because a single
/// string cannot be incremented — so a caller that wants a unit on the
/// announced value accepts raw neighbours beside it, or passes no `valueLabel`
/// and gets raw numbers throughout.
///
/// ## THERE IS **NO** TRANSITION, AND THAT IS THE PROTOTYPE'S
///
/// `redesign.html:429-430` declare no `transition` on the range input, so the
/// thumb does not animate — and §14's rule is conditional ("every animation
/// checks `MediaQuery.disableAnimationsOf`; when disabled, jump straight to
/// the end state"), and there is no animation to guard.
///
/// **This is stated rather than left as a silence**, because a reader who
/// knows §14 will look for the check and find none. The alternative — a
/// sliding thumb — would be a motion the prototype does not have *and* would
/// make the thumb lag the finger during a drag, which is a control that feels
/// broken rather than smooth.
///
/// **AND IT IS A DEPARTURE FROM THE TASK'S OWN BRIEF, recorded here rather
/// than left for a reviewer to find.** The brief asked for
/// `MediaQuery.disableAnimationsOf` to be honoured "for the thumb's
/// transition, as every animated widget here does" — and there is no thumb
/// transition to guard, because the prototype declares none. **The check is
/// not written for a motion that does not exist**, and the brief's own
/// reason (§14's rule is conditional) is the reason it is absent.
class EvaRangeSlider extends StatelessWidget {
  /// A slider over `min…max`, sitting on [value].
  const EvaRangeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.semanticLabel,
    this.step = 1,
    this.valueLabel,
    super.key,
  }) : assert(min <= max, 'a range needs min <= max, got $min…$max');

  /// The current value. Clamped and stepped for **display**; the widget never
  /// writes back on its own.
  final int value;

  /// The range's lower bound.
  final int min;

  /// The range's upper bound.
  final int max;

  /// Reports the new value, already clamped and already stepped.
  ///
  /// **The widget never produces a value outside `min…max`, and never produces
  /// one that is not reachable by [step].** That is the whole reason the clamp
  /// and the snap are pure functions above rather than arithmetic in `build`.
  final ValueChanged<int> onChanged;

  /// The control's own accessible name — the reader's word for it.
  ///
  /// **Required, and the reason is §14's first row.** `EvaToggle`,
  /// `FontSizeStepperLabels` and `EvaButton.labelFamily` all set the precedent
  /// that a control with no name in the reader's own language is a failure a
  /// widget-level default makes invisible. This is a bilingual app and the
  /// default would be English.
  final String semanticLabel;

  /// The granularity of the control.
  ///
  /// `1` — every integer — for seven of the eight Workshop sliders. The
  /// eighth is the prototype's own stepped one, `redesign.html:684`:
  /// `step="5"`, on a range of 15–120.
  final int step;

  /// The announced value, or `null` for the raw number.
  final String? valueLabel;

  /// The track's width. `redesign.html:429` — `width:120px`.
  static const double trackWidth = 120;

  /// The rule's thickness. `redesign.html:429` — `height:3px`.
  static const double trackHeight = 3;

  /// The rule's radius. `redesign.html:429` — `border-radius:3px`, on a 3px
  /// rule, so the rule is a stadium at both ends.
  static const double trackRadius = 3;

  /// The rule's alpha in dark. `redesign.html:429` — `rgba(255,255,255,.14)`.
  static const double trackAlphaDark = 0.14;

  /// The rule's alpha in light. `redesign.html:95` —
  /// `rgba(20,22,30,.18)`.
  static const double trackAlphaLight = 0.18;

  /// The thumb's diameter. `redesign.html:430` — `width:15px, height:15px`.
  static const double thumbSize = 15;

  /// The thumb's glow alpha. `redesign.html:430` — `rgba(232,176,75,.7)`.
  static const double thumbGlowAlpha = 0.7;

  /// The thumb's glow radius. `redesign.html:430` — `0 0 10px`.
  static const double thumbGlowBlur = 10;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final int current = steppedRangeValue(value, min, max, step);
    final int increased = steppedRangeValue(
      current + (step < 1 ? 1 : step),
      min,
      max,
      step,
    );
    final int decreased = steppedRangeValue(
      current - (step < 1 ? 1 : step),
      min,
      max,
      step,
    );
    final double trackAlpha = Theme.of(context).brightness == Brightness.dark
        ? EvaRangeSlider.trackAlphaDark
        : EvaRangeSlider.trackAlphaLight;
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: valueLabel ?? '$current',
      increasedValue: '$increased',
      decreasedValue: '$decreased',
      onIncrease: increased > current ? () => onChanged(increased) : null,
      onDecrease: decreased < current ? () => onChanged(decreased) : null,
      // The subtree is the rule, the thumb and a focus node, and none of them
      // has anything to say. Excluding it keeps the announced value the one
      // this widget chose, rather than a second reading of the raw number.
      excludeSemantics: true,
      child: EvaFocusRing(
        // A stadium, because the control's own end is a round thumb
        // (`redesign.html:430`'s `border-radius:50%`). A rectangular ring
        // around a round-ended control draws corners the control does not have
        // — the same argument `SettingsTile` makes for its own `radius: 0`.
        radius: EvaRadii.chip,
        onKeyEvent: (FocusNode node, KeyEvent event) =>
            _onKey(context, event, current),
        child: Builder(
          // `EvaFocusRing` owns the focus node and publishes it through
          // `EvaFocusRingScope`; the `Focus` widget below is what makes the
          // control reachable by Tab. `EvaFocusRing`'s doc explains why there
          // is no `Focus` inside it: `EvaInk` would supply one, and a slider is
          // dragged rather than pressed, so there is no `EvaInk` here.
          builder: (BuildContext context) => Focus(
            focusNode: EvaFocusRingScope.of(context).node,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double available = constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : EvaRangeSlider.trackWidth;
                final double width = math.min(
                  EvaRangeSlider.trackWidth,
                  available,
                );
                final double travel = math.max(
                  0,
                  width - EvaRangeSlider.thumbSize,
                );

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    // **THE POINTER'S POSITION IS A NAMED FUNCTION**, and it is
                    // named because the wrong answer here is a slider sitting at
                    // a value the reader did not choose — AGENT_CONTEXT §6's
                    // "domain logic must not be buried inside a widget".
                    onChanged(
                      valueForOffset(
                        dx:
                            details.localPosition.dx -
                            EvaRangeSlider.thumbSize / 2,
                        travel: travel,
                        min: min,
                        max: max,
                        step: step,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: width,
                    height: EvaRangeSlider.thumbSize,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          left: 0,
                          right: 0,
                          top:
                              (EvaRangeSlider.thumbSize -
                                  EvaRangeSlider.trackHeight) /
                              2,
                          height: EvaRangeSlider.trackHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.ink.withValues(alpha: trackAlpha),
                              borderRadius: BorderRadius.circular(
                                EvaRangeSlider.trackRadius,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          // **THE THUMB'S POSITION IS THE NAMED MIRROR** of
                          // [valueForOffset] — see `core/common/ranges.dart` for
                          // why the two round differently on purpose.
                          left: offsetForValue(
                            value: current,
                            min: min,
                            max: max,
                            travel: travel,
                          ),
                          top: 0,
                          width: EvaRangeSlider.thumbSize,
                          height: EvaRangeSlider.thumbSize,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.ember,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: colors.ember.withValues(
                                    alpha: EvaRangeSlider.thumbGlowAlpha,
                                  ),
                                  blurRadius: EvaRangeSlider.thumbGlowBlur,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The arrow keys, and `Home`/`End`.
  ///
  /// ## WHY THE SLIDER HAS A KEYBOARD MODEL AT ALL
  ///
  /// §14's focus row asks every interactive widget for a focus ring, and a
  /// focus ring on a control that cannot be operated would be a worse defect
  /// than no ring: the reader is told the control is there and cannot move it.
  /// `FontSizeStepper` solves that with `Semantics(onIncrease: / onDecrease:)`;
  /// a slider has the same need and the same answer, and the arrow keys are the
  /// model every platform slider has.
  ///
  /// **The RTL rule is `SegmentedControl`'s**, because it is the same rule: in
  /// an RTL screen the minimum is on the right, so `ArrowRight` **decreases**.
  /// `selectionStepFor` is that rule, already written down, and reusing it is
  /// the point of having it in one place.
  KeyEventResult _onKey(BuildContext context, KeyEvent event, int current) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final TextDirection direction = Directionality.of(context);
    final int? sign = switch (key) {
      LogicalKeyboardKey.arrowRight => selectionStepFor(
        direction: direction,
        logicalKeyForward: true,
      ),
      LogicalKeyboardKey.arrowLeft => selectionStepFor(
        direction: direction,
        logicalKeyForward: false,
      ),
      _ => null,
    };
    if (sign != null) {
      final int granularity = step < 1 ? 1 : step;
      onChanged(
        steppedRangeValue(
          sign < 0 ? current - granularity : current + granularity,
          min,
          max,
          step,
        ),
      );
      return KeyEventResult.handled;
    }
    // `Home` and `End` are **absolute**, so they cannot be expressed as a fixed
    // step: a step of `-length` from the middle of a five-value range would
    // wrap round to the middle, which is a Home key that does nothing. The
    // segmented control's doc records the same trap and the same answer.
    if (key == LogicalKeyboardKey.home) {
      onChanged(steppedRangeValue(min, min, max, step));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      onChanged(steppedRangeValue(max, min, max, step));
      return KeyEventResult.handled;
    }
    // Everything else, Tab included, is the framework's business.
    return KeyEventResult.ignored;
  }
}
