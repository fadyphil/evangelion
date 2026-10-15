import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The prototype's slider range. `SettingsScreen.tsx:66` —
/// `<input type="range" min={1} max={5}>`.
const int kFontStepMin = 1;

/// The prototype's slider maximum. `SettingsScreen.tsx:66`.
const int kFontStepMax = 5;

/// Clamps [step] into `kFontStepMin…kFontStepMax`.
///
/// Every path that can change the font size goes through here, including the one
/// that starts from storage. `SettingsRepository` will hand back whatever
/// `shared_preferences` holds, and a corrupt or hand-edited value must not be
/// able to reach `evaScalerFor` as something outside the table — where its `_`
/// arm sends it to 1.22× while the stepper shows a knob at a position no step
/// owns. Clamping at the boundary is what keeps the knob and the rendered size
/// telling the same story.
int clampFontStep(int step) => step.clamp(kFontStepMin, kFontStepMax);

/// The step whose `evaScalerFor` scale factor is [scaler]'s.
///
/// The inverse of the `03-design-system.md` §5.2 table, needed because the
/// stepper has to show *where the reader is* on that table, not just that it
/// moved. Two implementations of one mapping would drift, so this reads
/// [evaScalerFor] rather than restating it.
///
/// Matches on the scale factor at 1.0, which is the identity `TextScaler.linear`
/// guarantees. A `TextScaler` that is not linear (the platform's own nonlinear
/// scaler, for instance) therefore reads as the identity step, which is [3] —
/// `evaScalerFor(3)` is 1.00× and step 3 is the default. A scale factor outside
/// the table reads as the largest step, matching `evaScalerFor`'s `_` arm: a
/// corrupted preference reads as "largest", not as "reset".
int fontStepFromScaler(TextScaler scaler) {
  final double scale = scaler.scale(1.0);
  int step = kFontStepMin;
  for (int candidate = kFontStepMin; candidate <= kFontStepMax; candidate++) {
    if (evaScalerFor(candidate).scale(1.0) == scale) return candidate;
    step = candidate;
  }
  return step;
}

/// The three strings [FontSizeStepper] renders.
///
/// ## WHY A VALUE CLASS AND NOT THREE `String` PARAMETERS
///
/// §4 says named parameters for anything past two arguments, and three parameters
/// on a widget that also takes `step` and `onChanged` is five at every call site —
/// so the call sites would be unreadable and, worse, a caller could supply the
/// increase label in the decrease slot with nothing to catch it. `EvaButtonStyle`
/// and `EvaTextFieldStyle` are the precedent for one value object per widget's
/// treatments.
///
/// **No defaults, deliberately.** The strings this class used to hard-code were
/// `'Decrease font size'`, `'Increase font size'` and `'Font size'`, and the reason
/// they are parameters is that the app is bilingual: on the Arabic arm a reader who
/// opened the `Aa` panel was told in English what the two buttons beside them did. A
/// default would let the next design-system widget reintroduce the same English, and
/// §14's first row — a control with no name in the reader's own language — is a
/// failure a widget-level default makes invisible.
@immutable
class FontSizeStepperLabels {
  /// The stepper's three strings.
  const FontSizeStepperLabels({
    required this.decrease,
    required this.increase,
    required this.track,
  });

  /// The decrement button's accessible name and tooltip.
  final String decrease;

  /// The increment button's accessible name and tooltip.
  final String increase;

  /// The track's slider label.
  ///
  /// **The same string the `Aa` disclosure's own tooltip uses**, and deliberately
  /// one value rather than two: they name the same control from two positions, and a
  /// table with `textSize` beside `trackLabel` would be a translation decision that
  /// can disagree with itself.
  final String track;
}

/// The Settings font-size control.
///
/// ## IT IS NOT A MATERIAL `Slider`, AND THAT IS WORTH SAYING BEFORE THE NUMBERS
///
/// The obvious implementation of a font-size stepper is `Slider`, and the obvious
/// question when restyling one is "which of `Slider`'s parts do I override". This
/// widget is **not** a `Slider` and never was: `_Track` is a hand-built `Stack` of a
/// rule and a `Positioned` thumb inside a `GestureDetector`, publishing
/// `Semantics(slider: true, increasedValue:, decreasedValue:)`. That matters because
/// `Slider`'s geometry is Material's — a 4px track and a 20px thumb with an
/// overlay ring — and **none of those three numbers is the prototype's**. The
/// redesign's rule is 3px with a 15px thumb (`redesign.html:429-430`), so a
/// `Slider` would have had to be overridden on track height, thumb radius and thumb
/// overlay radius before it drew anything the prototype draws. Rebuilding the two
/// boxes by hand costs 30 lines and keeps the geometry in this file where the
/// citations are.
///
/// ## WHAT CAME FROM WHERE — THE THREE SOURCES, AND WHY THE MIX IS NOT A MISTAKE
///
/// | prototype | here |
/// | --- | --- |
/// | `redesign.html:429` — `input[type=range]`, `height:3px`, `rgba(#fff,.14)` | [trackHeight] + the rule's own colour |
/// | `redesign.html:430` — `::-webkit-slider-thumb`, 15px, `var(--gold)`, `0 0 10px rgba(232,176,75,.7)` | [thumbSize] + the gold disc and its glow |
/// | `redesign.html:95` — the same track re-pointed at `rgba(20,22,30,.18)` in light mode | `EvaColors.ink` at 14% |
/// | `SettingsScreen.tsx:65`,`:67` — the small `A` at `ui 12` and the large one at `ui 17`, both `ink3` | `_ScaleLetter`, `ui` family, `ink2` |
/// | `SettingsScreen.tsx:66` — `width: 80`, `min={1} max={5}` | [trackWidth], [kFontStepMin], [kFontStepMax] |
/// | `SettingsScreen.tsx:66` — `accentColor: hex.ember` | **nothing** — see the fill below |
///
/// The letters keep `ink2` where the React prototype wrote `T.ink3`: `ink3` is this
/// design system's *disabled* ink, and `#9B97B8` in light is below any text floor on
/// a pale row. It is a recorded divergence, not an oversight, and it predates this
/// restyle.
///
/// ## THE FILLED PORTION OF THE TRACK IS GONE, DELIBERATELY
///
/// `SettingsScreen.tsx:66`'s `accentColor: hex.ember` is what painted the ember
/// bar from the left edge to the thumb, and `redesign.html:429-430` has **no such
/// thing**: a CSS range input is one uniform rule with one gold thumb on it, and
/// that is what this now draws. The thumb's position was already the state carrier
/// (and `Semantics(value:)` publishes the step), so nothing that carries state was
/// lost — and a 3px rule half-filled with ember under a gold thumb is two accents
/// fighting over 3 rows of pixels.
///
/// ## `−` AND `+` HAVE NO REDESIGN ANALOGUE, AND KEEP THEIR OWN CITATION
///
/// `redesign.html:429` is the redesign's type-size row, and it is a bare
/// `input[type=range]` with a `.prevline` preview beside it — no steppers. The two
/// buttons exist because the React native input supplied its own stepper affordances
/// on every platform and a Flutter widget has to; they are [IconActionButton]s, so
/// they bring their own §14 focus ring.
class FontSizeStepper extends StatelessWidget {
  /// A stepper sitting on [step].
  const FontSizeStepper({
    required this.step,
    required this.onChanged,
    required this.labels,
    super.key,
  });

  /// The three strings this control renders. See [FontSizeStepperLabels].
  final FontSizeStepperLabels labels;

  /// The current step. Clamped for display, so a corrupt stored value renders
  /// as the nearest real step instead of a knob past the end of the track.
  final int step;

  /// Reports the new step, already clamped.
  final ValueChanged<int> onChanged;

  /// The prototype's track width. `SettingsScreen.tsx:66` — `width: 80`.
  ///
  /// **Kept at 80 against `redesign.html:429`'s `width:120px`,** and the reason is
  /// the same one keeps the range: the redesign's own slider is a *different
  /// control* — 16–26px, sized for a 120px rule on a settings row that has no `A`
  /// letters and no steppers. Transposing its width onto a five-step scale whose
  /// steps are `0.88×…1.22×` would make step 1 and step 5 two thirds of a row
  /// apart on a control whose meaning is *discrete*. Recorded rather than silently
  /// dropped, because "the width is 120 in the design reference" is the first thing
  /// a reviewer reads in the CSS.
  static const double trackWidth = 80;

  /// The rule's thickness. `redesign.html:429` — `height: 3px`, and the same rule
  /// names `border-radius: 3px`, so it is a stadium at both ends.
  ///
  /// Was 4, chosen for "a 4px line with a 14px thumb" when the thumb was
  /// `SettingsScreen.tsx`'s unspecified native one. The redesign names a 3px rule
  /// and a 15px thumb, and the ratio between them is the thing that reads.
  static const double trackHeight = 3;

  /// The thumb's diameter. `redesign.html:430` — `width: 15px, height: 15px`.
  static const double thumbSize = 15;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final int current = clampFontStep(step);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ScaleLetter(size: EvaSpacing.md, colors: colors),
        const SizedBox(width: EvaSpacing.sm),
        IconActionButton(
          icon: Icons.remove,
          tooltip: labels.decrease,
          // Swapped for the ambient arm, and the English string that used to sit on
          // this line is what made that necessary: `'Decrease font size'` is Latin,
          // so passing it `uiFamily` was correct **for that string** and would have
          // been six tofu boxes the moment the caller passed the Arabic one. The
          // family now follows the direction, and the string comes from
          // [labels] — so this site has no language and no family of its own.
          tooltipFamily: arabicAwareFamily(
            Directionality.of(context),
            EvaTypography.uiFamily,
          ),
          onPressed: current > kFontStepMin
              ? () => onChanged(clampFontStep(current - 1))
              : null,
          size: EvaSpacing.xxxl,
        ),
        const SizedBox(width: EvaSpacing.xs),
        _Track(
          step: current,
          colors: colors,
          onChanged: onChanged,
          labels: labels,
        ),
        const SizedBox(width: EvaSpacing.xs),
        IconActionButton(
          icon: Icons.add,
          tooltip: labels.increase,
          // See the decrement button above.
          tooltipFamily: arabicAwareFamily(
            Directionality.of(context),
            EvaTypography.uiFamily,
          ),
          onPressed: current < kFontStepMax
              ? () => onChanged(clampFontStep(current + 1))
              : null,
          size: EvaSpacing.xxxl,
        ),
        const SizedBox(width: EvaSpacing.sm),
        _ScaleLetter(size: EvaSpacing.lg + EvaSpacing.xs, colors: colors),
      ],
    );
  }
}

/// One of the two `A`s.
class _ScaleLetter extends StatelessWidget {
  const _ScaleLetter({required this.size, required this.colors});

  final double size;
  final EvaColors colors;

  @override
  Widget build(BuildContext context) => Text(
    'A',
    style: TextStyle(
      fontFamily: EvaTypography.uiFamily,
      fontSize: size,
      color: colors.ink2,
    ),
  );
}

/// The rule and the thumb.
///
/// Draggable, because the prototype's row was a slider and a stepper with no
/// drag is a pair of buttons with a decoration between them. The drag reports a
/// clamped step, and `Semantics(slider:)` publishes it as a slider so a screen
/// reader can raise and lower it without hunting for the buttons.
///
/// The `Stack` here is **not** the one `glass_surface.dart` warns about. That one
/// was *inserted* into a chain whose consumers relied on the constraints arriving
/// unchanged and took them away with `StackFit.loose`; this one has always been
/// here, its children are positioned or shrink-wrapping by construction, and
/// `controls_test.dart` measures the rule rather than the `Stack`.
class _Track extends StatelessWidget {
  const _Track({
    required this.step,
    required this.colors,
    required this.onChanged,
    required this.labels,
  });

  /// The stepper's strings, for the slider node's own label. See
  /// [FontSizeStepperLabels.track].
  final FontSizeStepperLabels labels;

  final int step;
  final EvaColors colors;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int span = kFontStepMax - kFontStepMin;
    final double fraction = span == 0 ? 0 : (step - kFontStepMin) / span;
    // The thumb travels between two centres rather than across the full width,
    // so the first and last steps are not drawn half off the track.
    final double travel =
        FontSizeStepper.trackWidth - FontSizeStepper.thumbSize;

    return Semantics(
      slider: true,
      // `Semantics` has no `value` slot for a slider, so the step is announced
      // through the increase/decrease actions' own labels plus the thumb's
      // position as a `label`.
      label: labels.track,
      value: '$step',
      increasedValue: '${clampFontStep(step + 1)}',
      decreasedValue: '${clampFontStep(step - 1)}',
      onIncrease: step < kFontStepMax
          ? () => onChanged(clampFontStep(step + 1))
          : null,
      onDecrease: step > kFontStepMin
          ? () => onChanged(clampFontStep(step - 1))
          : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          final double dx =
              details.localPosition.dx - FontSizeStepper.thumbSize / 2;
          final double travelled = travel == 0 ? 0 : dx / travel;
          onChanged(
            clampFontStep(
              kFontStepMin + (travelled.clamp(0.0, 1.0) * span).round(),
            ),
          );
        },
        child: SizedBox(
          width: FontSizeStepper.trackWidth,
          height: FontSizeStepper.thumbSize,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Container(
                height: FontSizeStepper.trackHeight,
                decoration: BoxDecoration(
                  // `redesign.html:429` — `background: rgba(255,255,255,.14)`,
                  // re-pointed at `rgba(20,22,30,.18)` for light mode at `:95`.
                  // `EvaColors.ink` is near-white in dark and near-black in light,
                  // so one token covers both arms and the 14% is the dark value; the
                  // three-point difference in light is the same "the smaller
                  // difference between two values is not a token" judgement
                  // `EvaColors.seamGlow` records for a 14-vs-12 glow radius.
                  //
                  // It was `glassBorder` — `rgba(#fff | #000, .08)` — because the
                  // React control had no themed track and this borrowed the
                  // segmented control's neutral so the two appearance controls read
                  // as siblings. The redesign names its own 14%, and that is the
                  // citation now.
                  color: colors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(EvaRadii.chip),
                ),
              ),
              Positioned(
                left: travel * fraction,
                child: Container(
                  width: FontSizeStepper.thumbSize,
                  height: FontSizeStepper.thumbSize,
                  decoration: BoxDecoration(
                    // `redesign.html:430` — `background: var(--gold)`, which is
                    // [EvaColors.ember] here. The fill this knob used to sit at the
                    // end of is gone; see the class doc.
                    color: colors.ember,
                    shape: BoxShape.circle,
                    // The same line: `box-shadow: 0 0 10px rgba(232,176,75,.7)`.
                    // It replaces the `0 0 8px rgba(ember, .5)` this borrowed from
                    // `ds.tsx:401`'s passage progress bar — a longer radius and a
                    // higher alpha, because on a 3px rule the thumb is the only
                    // accent on the control and a 50% glow around a 14px disc read
                    // as a smudge.
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.ember.withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
