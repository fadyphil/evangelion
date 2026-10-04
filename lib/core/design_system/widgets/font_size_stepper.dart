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
/// The prototype's row (`SettingsScreen.tsx:63-69`) is a small `A`, a native
/// range input `80px` wide with `accentColor: ember`, and a large `A`. The
/// native input is gone in Flutter — it has no themed track and no themed thumb
/// on desktop — so it is rebuilt here out of tokens:
///
/// | prototype | here |
/// | --- | --- |
/// | small `A`, `ui` 12, `ink3` | `labelMedium` + `ink3` |
/// | large `A`, `ui` 17, `ink3` | `titleMedium` + `ink3` |
/// | `accentColor: ember` | the filled portion of the track |
/// | thumb | a 14px `ember` disc |
/// | `min=1 max=5` | [kFontStepMin] / [kFontStepMax] |
///
/// `−` and `+` are added because the native range input supplied its own
/// stepper affordances on every platform and a Flutter widget has to; they are
/// [IconActionButton]s, so they bring their own §14 focus ring.
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
  static const double trackWidth = 80;

  /// The track's thickness, and the thumb's radius. No prototype value: the
  /// native input's own geometry, chosen to read as a 4px line with a 14px
  /// thumb. Named so it is one edit rather than three literals.
  static const double trackHeight = 4;

  /// The thumb's diameter.
  static const double thumbSize = 14;

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
      color: colors.ink3,
    ),
  );
}

/// The track, the fill and the thumb.
///
/// Draggable, because the prototype's row was a slider and a stepper with no
/// drag is a pair of buttons with a decoration between them. The drag reports a
/// clamped step, and `Semantics(slider:)` publishes it as a slider so a screen
/// reader can raise and lower it without hunting for the buttons.
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
                  // `rgba(#fff | #000, 0.1)` — the same neutral the unselected
                  // segmented control uses, so the two controls in the Settings
                  // appearance group read as siblings.
                  color: colors.glassBorder,
                  borderRadius: BorderRadius.circular(EvaRadii.chip),
                ),
              ),
              Container(
                width: travel == 0
                    ? 0
                    : FontSizeStepper.thumbSize / 2 + travel * fraction,
                height: FontSizeStepper.trackHeight,
                decoration: BoxDecoration(
                  color: colors.ember,
                  borderRadius: BorderRadius.circular(EvaRadii.chip),
                ),
              ),
              Positioned(
                left: travel * fraction,
                child: Container(
                  width: FontSizeStepper.thumbSize,
                  height: FontSizeStepper.thumbSize,
                  decoration: BoxDecoration(
                    color: colors.ember,
                    shape: BoxShape.circle,
                    // `PassageCard`'s progress bar carries
                    // `0 0 8px rgba(ember, 0.5)` (`ds.tsx:401`) — the prototype's
                    // one accent glow on a thin ember element, and the closest
                    // thing in `ds.tsx` to what a slider thumb is.
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.ember.withValues(alpha: 0.50),
                        blurRadius: 8,
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
