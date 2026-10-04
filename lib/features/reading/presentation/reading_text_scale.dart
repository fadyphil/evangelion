import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/widgets.dart';

/// The [TextScaler] the scripture block renders at, for the reader's [step].
///
/// ## WHY IT LIVES HERE AND NOT IN `eva_typography.dart`
///
/// `evaScalerFor` is the design system's table and is not this function's to move;
/// the composition of that table with the **platform's** scaler is a decision about
/// this screen, because §14's requirement is stated about the app's layouts and
/// Phase 10 is what installs `evaScalerFor` app-wide. A design-system function that
/// read `MediaQuery` would be a widget-layer concern in a token file, and the
/// barrel exists so pure-Dart files never reach Flutter through it.
///
/// ## THE RULE IS **THE PRODUCT, CAPPED AT THE TOP OF THE TABLE**
///
/// The `Aa` control is a *preference*; the platform scaler is an *accessibility
/// setting* the reader may have raised deliberately. Neither may be silently
/// discarded, and **two of the four obvious rules discard one of them.** The
/// numbers below are measured, at the two ends of the control:
///
/// | rule | platform 1.0, step 1 | platform 1.0, step 5 | platform 1.22, step 1 |
/// | --- | --- | --- | --- |
/// | **product, capped** | **0.90** | **1.22** | **1.10** |
/// | `max(platform, step)` | **1.00** | 1.22 | 1.22 |
/// | step replaces platform | 0.90 | 1.22 | **0.90** |
/// | platform replaces step | **1.22** | **1.22** | 1.22 |
///
/// **`max` is out on the measurement in the second column.** On a device that does
/// not scale — which is the default install — `max` renders steps 1, 2 and 3 all at
/// `1.00×`. The reader drags toward "smallest" and nothing happens, for three of the
/// five positions. That is not a corner case; it is the ordinary one.
///
/// **Replacement is out on the fourth column, and in a different way.** A reader who
/// raised the OS to 1.22 and then picks Eva's *smallest* would get `0.90×` in the
/// sanctuary and `1.22×` on every other screen — the one screen where reading is
/// hardest is the one screen that ignores their accessibility setting. It is the
/// option `eva_typography.dart` already names and rejects: "wrapping the platform's
/// scaler in a way that ignores it would silently override a user who has raised the
/// OS font size".
///
/// ## AND THE CAP IS NOT A HAND-PICKED NUMBER
///
/// [kEvaScaleCeiling] is `evaScalerFor(kFontStepMax)` — the design system's own top
/// row, read rather than restated. §14's requirement is stated at 1.22× and that is the only size this app has
/// ever been laid out for, so past it there is no requirement to satisfy and no
/// layout to satisfy it with. The cap is therefore the top of the table rather than
/// a number chosen for this screen.
///
/// ## THE COST, AND IT IS A REAL DEAD ZONE
///
/// **At a platform scale above 1.109 the top of the control collapses:** steps 3, 4
/// and 5 all render at the ceiling, because `1.10 × 1.109` already reaches `1.22`.
/// That is a reader who has already raised their OS font size past 1.109 and also
/// wants Eva's larger steps — a real reader, on a real device, getting a control
/// whose top three positions agree.
///
/// It is the price of the ceiling, and the ceiling is the price of §14. The
/// alternatives were `max` (three dead positions on **every** default device) and
/// replacement (the sanctuary ignoring the OS setting whenever the reader chooses
/// small). Neither dead zone is smaller.
///
/// **Phase 9 owns the fix**, and the fix is not another rule: one persisted
/// preference replaces two inputs, so there is one scale and nothing to compose.
/// `SettingsCubit` is where the two stop being independent.
///
/// ## AND THE PLATFORM SCALER IS **NOT** LINEAR, WHICH IS THE COST
///
/// `TextScaler.linear(factor)` cannot represent a nonlinear platform scaler — and
/// Android ships one. So on a device using it, this returns a linear scaler at the
/// larger of the two factors and the platform's own curve is lost **for the
/// scripture block only**; every other screen keeps it, because this function's
/// result is installed on a subtree rather than at `MaterialApp.builder`.
///
/// The alternative — `TextScaler` composition across two implementations of the
/// interface, which has no `max` — would mean evaluating the platform's curve at
/// sample sizes and interpolating, which is a worse approximation of the thing it
/// replaces. Recorded rather than hidden, and **Phase 9 owns the fix**: one
/// persisted preference replaces two inputs, and at that point there is one scaler
/// and no composition.
///
/// **The cost of that deferral, in plain words: a reader's `Aa` choice does not
/// survive leaving `/reading`.** It lives in [ReadingCubit] for the life of the
/// cubit and nowhere else. Nothing in `lib/` reads `SettingsRepository` — it is
/// Phase 9's — so there is nowhere durable for it to be written, and a reader who
/// sets the size, opens the quiz and comes back finds the default. No copy, doc or
/// test in this repository claims otherwise.
TextScaler readingTextScalerFor({
  required int step,
  required TextScaler platform,
}) {
  final double fromStep = evaScalerFor(clampFontStep(step)).scale(1);
  final double fromPlatform = platform.scale(1);
  final double product = fromStep * fromPlatform;
  return TextScaler.linear(
    product > kEvaScaleCeiling ? kEvaScaleCeiling : product,
  );
}

/// The largest scale the scripture block will render at.
///
/// A **getter and not a `const double`**, because `evaScalerFor` is a function and a
/// constant expression cannot call it. That is the reason it reads the table rather
/// than spelling `1.22`: a hand-typed ceiling beside `03-design-system.md` §5.2's
/// table is the second copy of one number that `fontStepFromScaler`'s doc says must
/// not exist, and a `const` would have forced exactly that.
/// `reading_text_scale_test.dart` asserts it is `1.22` **and** that it equals the
/// table's own top row, so a table that moves without the ceiling is red.
double get kEvaScaleCeiling => evaScalerFor(kFontStepMax).scale(1);
