import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Installs the Eva type scale for a font-size [step] on everything below.
///
/// ## WHAT IT REPLACED, AND WHY THE REPLACEMENT IS A **WIDGET**
///
/// `features/reading/presentation/reading_text_scale.dart` was a hundred lines whose
/// subject was `readingTextScalerFor` — the product of the reader's step and the
/// platform's own scaler, capped at `evaScalerFor(kFontStepMax)`. It is deleted.
///
/// Its replacement has to live in **three** places to be honest, and all three want
/// the same three lines:
///
/// * `MaterialApp.builder` in `lib/app/app.dart`, so the scale is app-wide;
/// * `/reading`'s §14 overflow suite, so the requirement is tested through the
///   **real** install rather than through a hand-injected `MediaQuery`;
/// * `/settings`' stepper, so the control's position and the rendered size cannot
///   disagree.
///
/// A bare `MediaQuery` spelled three times is three rules, and this repository's
/// recorded opinion on that shape is `barrel.dart`'s: "the practical cost of the
/// rename is one edit here and the practical cost of a deep import appearing is two
/// import styles coexisting forever." So it is **one widget**, and the table it reads
/// (`evaScalerFor`) is the design system's own — which `eva_typography.dart`'s header
/// has claimed since Phase 1: "the scripture styles Material has no slot for **and the
/// Settings font-size scaler**".
///
/// ## IT REPLACES THE SCALER RATHER THAN **COMPOSING** WITH IT, AND THE TRADE IS
/// ## RECORDED HERE BECAUSE THIS IS THE FILE THAT MAKES IT
///
/// [evaScalerFor]'s doc is the long version. The short one: two inputs multiplied into
/// a bounded range always collapse somewhere — `max(platform, step)` collapses steps
/// 1–3 to one position on **every** default device, and the product collapses steps
/// 3–5 once the platform passes 1.109 — and a rule with no ceiling cannot be the one
/// §14 verified. So there is one input.
///
/// **What a reader loses is stated rather than smoothed over:** a reader who has raised
/// their **OS** font size above 1.22× has no control for it in this app, because the
/// app's own step is the only input. That is a real accessibility cost, it is the cost
/// `eva_typography.dart` rejected for a *subtree* ("silently override a user who has
/// raised the OS font size"), and the rejection is scoped differently here because
/// its reason was scoped differently: it said the *sanctuary* would ignore the
/// accessibility setting "on every other screen", and with one app-wide install there
/// is no other screen.
///
/// **And the app now offers a control for the property the OS setting was reaching
/// for**: `/settings` → Appearance → Font size, in the reader's own language, on every
/// screen. §14's requirement (survive 1.22× at 320px) is what bounds the table, and it
/// is what `evaScalerFor` publishes.
class EvaTypeScale extends StatelessWidget {
  /// Wraps [child] in a [MediaQuery] rendering at [step].
  const EvaTypeScale({required this.step, required this.child, super.key});

  /// The reader's font-size step, `kFontStepMin`…`kFontStepMax`.
  ///
  /// **Clamped** through `clampFontStep`, and not by trusting the caller: this widget
  /// is the last thing between a persisted integer and the engine, and
  /// `font_size_stepper.dart`'s doc states the requirement exactly — a value outside
  /// the table would reach `evaScalerFor`'s `_` arm as `1.22×` while the stepper's knob
  /// sat at a position no step owns. `SettingsCubit` is the authoritative boundary and
  /// clamps too; this is the belt to its braces, and both are asserted.
  final int step;

  /// The subtree rendered at [step].
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: evaScalerFor(clampFontStep(step))),
    child: child,
  );
}
