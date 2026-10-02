import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The value one step along [values] from [selected], wrapping at both ends.
///
/// The keyboard model Phase 3's gate names — "`SegmentedControl` selects via
/// keyboard" — is this function plus the direction below it. The prototype had
/// no keyboard model at all: its theme picker is three `<button>`s whose state
/// lives in a `useState` (`SettingsScreen.tsx:6,52-61`) and whose only input is
/// a click. A control a keyboard cannot reach is the §14 defect this widget is
/// built to close, so the model is written down and pinned before the widget.
///
/// **Wrapping rather than clamping.** Material's `SegmentedButton` clamps at the
/// ends, so ArrowRight on the last segment does nothing. Wrapping is the
/// behaviour a radio group has everywhere else in every platform, and it is what
/// makes "how many options are there?" answerable by pressing a key twice.
///
/// The four edge cases are deliberate and each one is a real state:
///
/// - an **empty** list returns `null` — nothing to select, and the widget
///   renders nothing;
/// - a **single** value returns itself — a one-option segmented control is a
///   label, and ArrowRight must not be a crash;
/// - a [selected] value **outside** the list snaps to the nearest end. That is
///   reachable when a persisted setting names a value a rebuilt enum no longer
///   has, and returning `null` there would leave the control drawing no
///   selection at all;
/// - any other `T` works. The widget is `SegmentedControl<T>` precisely so
///   `AppThemeMode` and `ScriptureLanguage` share it.
T? nextSelection<T>({
  required List<T> values,
  required T selected,
  required int step,
}) {
  if (values.isEmpty) return null;
  if (values.length == 1) return values.first;
  final int index = values.indexOf(selected);
  final int from = index < 0 ? (step > 0 ? -1 : values.length) : index;
  final int next = (from + step) % values.length;
  return values[(next + values.length) % values.length];
}

/// The list step for an arrow key press.
///
/// [logicalKeyForward] is true for ArrowRight and false for ArrowLeft. In an RTL
/// screen "forward" is leftwards, so the two swap: without this, ArrowRight
/// walks an Arabic reader's options **backwards**, which is the same class of
/// bug as defect #2 (Arabic laid out with Latin assumptions).
int selectionStepFor({
  required TextDirection direction,
  required bool logicalKeyForward,
}) => direction == TextDirection.ltr
    ? (logicalKeyForward ? 1 : -1)
    : (logicalKeyForward ? -1 : 1);

/// A segmented picker over any enum or value type.
///
/// `04-widget-inventory.md` §3 collapses two prototype controls into this one:
/// the Settings **theme** picker (`SettingsScreen.tsx:51-62`) and the **language**
/// pills (`:77-90`). They disagree on shape — the theme picker is one joined
/// track, the language pills are two separate pills — and this widget transcribes
/// the **joined track**, which is the one with a track to press, because a
/// segmented control with no track is two buttons.
///
/// ## THE KEYBOARD MODEL, WHICH THE PROTOTYPE HAS NONE OF
///
/// One tab stop for the whole control, and arrow keys move *within* it. That is
/// the roving-focus pattern, and it is the correct one: three separately
/// focusable segments means Tab visits all three before leaving the control, so
/// a reader tabbing past a settings group stops three times for one answer.
///
/// - `ArrowRight` / `ArrowLeft` — change the selection through
///   [nextSelection] / [selectionStepFor], and **do not** let the default
///   `HorizontalTraversalIntent` move focus out. Handling it here is why
///   [EvaFocusRing.onKeyEvent] exists.
/// - `Home` / `End` — first and last, the convention for every list and slider.
/// - `Tab` — leaves. One press, one exit.
///
/// ## WHAT IS NOT INVENTED
///
/// There is no hover-only affordance, no animated sliding thumb, and no
/// `selectedIcon`. The prototype's selection is a fill plus a colour change and
/// that is what this draws — see [EvaChip] for why the §14 colour-only ban does
/// not bite here.
class SegmentedControl<T> extends StatefulWidget {
  /// A picker over [values], showing [selected].
  const SegmentedControl({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  /// Every option, in paint order.
  final List<T> values;

  /// The chosen option. Must be one of [values].
  final T selected;

  /// The label for an option. A function rather than a `labelBuilder` callback
  /// taking an index, so a caller cannot read the wrong element of [values].
  final String Function(T) labelOf;

  /// Reports the new selection, already resolved through [nextSelection].
  final ValueChanged<T> onChanged;

  /// The prototype's track radius. `SettingsScreen.tsx:51` — `borderRadius: 8`.
  static const double trackRadius = 8;

  /// Horizontal padding per segment. `SettingsScreen.tsx:58` — `padding: 5px 10px`.
  static const EdgeInsets segmentPadding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.md,
    vertical: EvaSpacing.xs,
  );

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  /// The prototype transitions `all 200ms` (`SettingsScreen.tsx:59`). That is
  /// `EvaMotion.base` exactly, so unlike the button's 180ms this one needed no
  /// rounding to a token.
  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  /// Moves the selection by [step] list positions.
  ///
  /// Wrapped in [AnimatedContainer] per segment rather than one animated track,
  /// because the prototype animates each button's own background and ink
  /// separately (`SettingsScreen.tsx:56,59`) — there is no moving thumb in the
  /// prototype to animate.
  void _move(int step) {
    final T? next = nextSelection<T>(
      values: widget.values,
      selected: widget.selected,
      step: step,
    );
    // `null` only when `values` is empty, and then the widget draws nothing, so
    // there is nothing to report.
    if (next == null) return;
    widget.onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final int? step = switch (key) {
      LogicalKeyboardKey.arrowRight => selectionStepFor(
        direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        logicalKeyForward: true,
      ),
      LogicalKeyboardKey.arrowLeft => selectionStepFor(
        direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        logicalKeyForward: false,
      ),
      _ => null,
    };
    if (step != null) {
      _move(step);
      return KeyEventResult.handled;
    }
    // Home/End are **absolute**, so they cannot be expressed as a fixed step:
    // `-values.length` from the middle of a three-item list wraps back to the
    // middle, which is a Home key that does nothing. Confirmed by the test that
    // failed before this was fixed.
    if (key == LogicalKeyboardKey.home && widget.values.isNotEmpty) {
      widget.onChanged(widget.values.first);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end && widget.values.isNotEmpty) {
      widget.onChanged(widget.values.last);
      return KeyEventResult.handled;
    }
    // Everything else, Tab included, is the framework's business. Returning
    // `ignored` here is what lets Tab leave in one press.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const SizedBox.shrink();
    }
    final EvaColors colors = context.colors;

    final Widget track = Container(
      // `SettingsScreen.tsx:51` —
      // `background: rgba(#fff | #000, 0.06)`, `borderRadius: 8`,
      // `overflow: hidden`.
      padding: const EdgeInsets.all(EvaSpacing.xs),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final T value in widget.values)
            Flexible(
              child: _Segment<T>(
                label: widget.labelOf(value),
                selected: value == widget.selected,
                colors: colors,
                animate: _animate,
                // Taps are per segment, so the segments are individual
                // `InkWell`s — but they take **no** focus node, because the
                // control's single tab stop is the ring's node above them.
                onTap: () => widget.onChanged(value),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      child: EvaFocusRing(
        // No `idleBorder`: the prototype's track has none, and a rim around the
        // whole control would double the track's own edge.
        radius: SegmentedControl.trackRadius,
        onKeyEvent: _onKey,
        child: EvaInk(
          // The ring's node is the control's tab stop; the `InkWell` here only
          // supplies the ink for a tap that lands on the track's padding.
          onPressed: () => _move(1),
          borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
          child: track,
        ),
      ),
    );
  }
}

/// One segment.
///
/// Private so the only way to draw one is through [SegmentedControl], which
/// means the clamping and the keyboard model cannot be bypassed.
class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.colors,
    required this.animate,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final EvaColors colors;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = Semantics(
      // §14's prescription for a selectable chip, and the reason the segments
      // need their own nodes: without `selected`, a screen-reader user cannot
      // tell which of the three options is chosen.
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: animate ? EvaMotion.base : Duration.zero,
        curve: EvaMotion.baseCurve,
        // §14 — when animations are off the duration is zero, so the fill lands
        // on the frame the selection changes: the end state, immediately.
        padding: SegmentedControl.segmentPadding,
        decoration: BoxDecoration(
          // `SettingsScreen.tsx:56` —
          // `background: theme === opt ? rgba(#fff | #000, 0.1) : 'transparent'`.
          color: selected ? colors.glassBorder : Colors.transparent,
          borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          // `SettingsScreen.tsx:55` — `textTransform: 'uppercase'`, which Flutter
          // has no equivalent for.
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          // `SettingsScreen.tsx:54-55` — `F.mono, 9, 700, letterSpacing 0.08em,
          // textTransform: uppercase, color: theme === opt ? hex.ember : T.ink3`.
          style: EvaTypography.monoCaps(colors).copyWith(
            color: selected ? colors.ember : colors.ink3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
      child: InkWell(
        onTap: onTap,
        // No `focusNode`, and `canRequestFocus: false`: the control is one tab
        // stop and the arrow keys move the selection. See the class doc.
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
        child: body,
      ),
    );
  }
}
