/// The **seven** ranges the Workshop's ranged preferences own, and the clamp each
/// one applies.
///
/// ## AND WHY ONE OF THE EIGHT IS **NOT** HERE
///
/// The eighth — the **star count**'s — is in
/// `core/domain/entities/user_settings.dart`, as `kStarCountMin`,
/// `kStarCountMax` and `clampStarCount`. **That is §3's placement test and not a
/// preference**: the other seven are used by **one** feature (this one), and the
/// star count's range is used by **two** — this feature clamps it on the way in
/// and out, and the **sky** feature clamps the same number where it becomes a
/// cap. A feature may not import another feature (Gate 2) and `core/domain/` may
/// not name a feature, so the only home both may reach is the shared kernel —
/// and the field the range belongs to is there too.
///
/// **Two spellings of `0` and `60` in two features is the "two implementations
/// of one number" drift this repository rejects wherever it finds it.** The
/// asymmetry — seven here, one there — is the rule's answer, and it is stated
/// here so a reader does not read the missing eighth as an oversight.
///
/// ## WHY THEY ARE **PURE FUNCTIONS** IN **PURE DART**
///
/// AGENT_CONTEXT §6: "domain logic must not be buried in a widget". A slider that
/// clamps its own value is a widget computing a table, and a table that lives in a
/// widget file is a table `/reading` cannot reach. So each clamp is a top-level
/// function here, in `features/settings/domain/`, which Gate 1 holds Flutter-free.
///
/// The placement is `features/sky/domain/sky_star_cap.dart`'s, and for its reason:
/// that file holds the sky's cap because **two writers need one number** and the
/// dependency direction is strictly inward, so neither may import it from the other.
/// This file holds the seven ranges for the same reason — the cubit needs them, and
/// so does the design system's `EvaRangeSlider`, which takes a `min` and a `max` and
/// would otherwise restate the range in a widget file. **AGENT_CONTEXT §3's
/// "this feature's own use cases only" is widened here by a recorded precedent, not
/// by a preference.**
///
/// ## AND WHY EACH RANGE'S TWO NUMBERS ARE **NAMED CONSTANTS BESIDE IT**
///
/// `font_size_stepper.dart`'s `clampFontStep` is the precedent, and its own doc is
/// the argument: "a corrupt or hand-edited value must not be able to reach
/// `evaScalerFor` as something outside the table — where its `_` arm sends it to
/// 1.22× while the stepper shows a knob at a position no step owns."
///
/// A range written as two literals inside a `clamp` call is the same table with one
/// fewer name, and the name is what the **slider** needs: a widget that has to
/// restate the range holds a second spelling of it, and two spellings of one number
/// is the drift this repository rejects wherever it finds it.
///
/// ## EVERY RANGE IS THE **PROTOTYPE'S**, CITED
///
/// `eva/redesign.html` is the design source of truth, and every `min`/`max` below is
/// the prototype's own attribute — transcribed, not designed. A range this client
/// invented would be a design decision made by a data file.
///
/// ## AND THE CLAMP IS THE **ONLY** BOUNDARY
///
/// `SettingsCubit._clamp` is the app's single clamp boundary, and it calls these
/// **seven** — plus the star count's, which is in
/// `core/domain/entities/user_settings.dart` because the sky feature clamps the same
/// number and a feature may not import another feature. Nothing else clamps these
/// values, and nothing else may: a second boundary is a second table, and a value
/// could then be legal on one side of it and not the other.
library;

import 'package:evangelion/core/common/ranges.dart';

/// The smallest reach the aurora band may have. `eva/redesign.html:658` —
/// `<input type="range" id="setReach" min="18" max="110" value="42">`.
const int kReachMin = 18;

/// The largest reach the aurora band may have. `eva/redesign.html:658`.
const int kReachMax = 110;

/// Clamps [reach] into `kReachMin…kReachMax`.
///
/// `eva/redesign.html:658` is the prototype's own `min`/`max`.
int clampReach(int reach) => reach.clamp(kReachMin, kReachMax);

/// The smallest brightness the aurora may have. `eva/redesign.html:659` —
/// `<input type="range" id="setGlow" min="40" max="130" value="100">`.
const int kGlowMin = 40;

/// The largest brightness the aurora may have. `eva/redesign.html:659`.
const int kGlowMax = 130;

/// Clamps [glow] into `kGlowMin…kGlowMax`.
///
/// `eva/redesign.html:659` is the prototype's own `min`/`max`.
int clampGlow(int glow) => glow.clamp(kGlowMin, kGlowMax);

/// The smallest touch-glow the aurora may answer with.
/// `eva/redesign.html:660` — `<input type="range" id="setTouch" min="0" max="100"
/// value="55">`.
const int kTouchGlowMin = 0;

/// The largest touch-glow the aurora may answer with. `eva/redesign.html:660`.
const int kTouchGlowMax = 100;

/// Clamps [touchGlow] into `kTouchGlowMin…kTouchGlowMax`.
///
/// `eva/redesign.html:660` is the prototype's own `min`/`max`.
int clampTouchGlow(int touchGlow) =>
    touchGlow.clamp(kTouchGlowMin, kTouchGlowMax);

/// The smallest hue the aurora may take. `eva/redesign.html:661` —
/// `<input type="range" id="setHue" min="0" max="360" value="312">`.
const int kHueMin = 0;

/// The largest hue the aurora may take. `eva/redesign.html:661`.
const int kHueMax = 360;

/// Clamps [hue] into `kHueMin…kHueMax`.
///
/// `eva/redesign.html:661` is the prototype's own `min`/`max`.
int clampHue(int hue) => hue.clamp(kHueMin, kHueMax);

// **THE STAR COUNT'S RANGE IS NOT HERE.** `kStarCountMin`, `kStarCountMax` and
// `clampStarCount` live in `core/domain/entities/user_settings.dart`, because
// the range is used by two features and §3's placement test puts a
// two-consumer fact in the shared kernel. See the file's doc.

/// The dimmest the stars may be. `eva/redesign.html:670` —
/// `<input type="range" id="setStarBright" min="30" max="150" value="100">`.
const int kStarBrightnessMin = 30;

/// The brightest the stars may be. `eva/redesign.html:670`.
const int kStarBrightnessMax = 150;

/// Clamps [brightness] into `kStarBrightnessMin…kStarBrightnessMax`.
///
/// `eva/redesign.html:670` is the prototype's own `min`/`max`.
int clampStarBrightness(int brightness) =>
    brightness.clamp(kStarBrightnessMin, kStarBrightnessMax);

/// The shortest focus delay, in seconds. `eva/redesign.html:683` —
/// `<input type="range" id="setFocusDelay" min="2" max="15" value="4">`.
const int kFocusDelaySecMin = 2;

/// The longest focus delay, in seconds. `eva/redesign.html:683`.
const int kFocusDelaySecMax = 15;

/// Clamps [seconds] into `kFocusDelaySecMin…kFocusDelaySecMax`.
///
/// `eva/redesign.html:683` is the prototype's own `min`/`max`.
int clampFocusDelaySec(int seconds) =>
    seconds.clamp(kFocusDelaySecMin, kFocusDelaySecMax);

/// The shortest selah, in seconds. `eva/redesign.html:684` —
/// `<input type="range" id="setSelahDur" min="15" max="120" step="5" value="60">`.
const int kSelahLengthSecMin = 15;

/// The longest selah, in seconds. `eva/redesign.html:684`.
const int kSelahLengthSecMax = 120;

/// How far apart the selah's reachable values sit, in seconds.
///
/// `eva/redesign.html:684` — `step="5"`, and the prototype's **only** stepped
/// slider. Every other range in this file steps by 1.
const int kSelahLengthSecStep = 5;

/// Clamps [seconds] into `kSelahLengthSecMin…kSelahLengthSecMax` **and** onto the
/// step.
///
/// ## WHY THIS ONE IS **STEPPED** AND THE OTHER SEVEN ARE NOT
///
/// `eva/redesign.html:684` declares `step="5"`, so the prototype's slider can only
/// ever hold `15, 20, … 120`. A client that stored `63` would hold a value the
/// control cannot show, and the reader would drag the knob back to a position
/// before their own choice — the same "a knob at a position no step owns" failure
/// `clampFontStep`'s doc names.
///
/// So the clamp snaps to the **nearest** multiple of [kSelahLengthSecStep], measured
/// from [kSelahLengthSecMin] (which is itself a multiple of the step, so the two
/// anchors agree), and then re-clamps into the range so the snap can never leave
/// it. A remainder of exactly half a step cannot occur — the step is odd — so the
/// rounding has no tie to break and the function is total and deterministic.
///
/// **AND IT IS THE **SHARED** STEP RULE, NOT A SECOND COPY OF IT.** The
/// design system's `EvaRangeSlider` implements the same rule — clamp into the
/// range, then snap to the nearest multiple of the step measured from the
/// minimum — and its copy used to live in a **Flutter-importing** file, which
/// this pure-Dart domain may not import (Gate 1). So the rule was written
/// twice, and the two agreed only because nobody had changed either.
///
/// The one implementation is `steppedRangeValue` in `core/common/ranges.dart`,
/// which is pure Dart and is therefore reachable from **both**: the design
/// system and a feature's domain. `clampRangeValue` and `steppedRangeValue` are
/// the *mechanism*; the two numbers and the step are this file's *facts*.
int clampSelahLengthSec(int seconds) => steppedRangeValue(
  seconds,
  kSelahLengthSecMin,
  kSelahLengthSecMax,
  kSelahLengthSecStep,
);
