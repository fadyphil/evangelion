import 'dart:math' as math;

import 'package:evangelion/core/design_system/effects/lumen_canvas.dart';
import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_preferences.dart';
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/vespers.dart';
import 'package:flutter/widgets.dart';

/// The prototype's opening ambient intensity — `eva/redesign.html:884`.
///
/// `let ambI=0.15`. The aurora **fades in** from here toward its target, and
/// that fade is the prototype's opening.
const double kLumenAmbientOpen = 0.15;

/// The prototype's ambient base — `eva/redesign.html:884`.
///
/// `let ambBase=0.9`. The brightness slider multiplies this; it is not itself
/// a uniform.
const double kLumenAmbientBase = 0.9;

/// The factor the ambient is multiplied by while the screen is dimmed —
/// `eva/redesign.html:891`.
///
/// `const base=ambBase*bright*vesp*(focusDim?0.45:1);` — the `0.45` is the
/// focus mode's half, and it is the **focus** dim and not the vespers one
/// (`:890`'s `0.78`).
const double kLumenFocusDimFactor = 0.45;

/// The ambient intensity's ease, per frame — `eva/redesign.html:892`.
///
/// `ambI+=(base-ambI)*0.06`.
const double kLumenAmbientEase = 0.06;

/// The hue's ease, per frame — `eva/redesign.html:895-896`.
///
/// `curH.h=(curH.h+dh*0.045+360)%360`, and the same `0.045` for `s` and `l`.
const double kLumenHueEase = 0.045;

/// The hue's saturation — `eva/redesign.html:1472`.
///
/// `setTargetHue({h:autoH,s:70,l:62})`. **Not** the boot state's `90`
/// (`:881`): the boot state is where the *transition* starts, and this is
/// where it lands.
const double kLumenHueSaturation = 70;

/// The hue's lightness — `eva/redesign.html:1472`. See [kLumenHueSaturation].
const double kLumenHueLightness = 62;

/// The auto-hue's rate, in degrees a second — `eva/redesign.html:893`.
///
/// `autoH=(autoH+dt*8)%360`. The only rate the prototype states in **seconds**
/// rather than in frames.
const double kLumenAutoHueRate = 8;

/// The frame delta's cap, in seconds — `eva/redesign.html:888`.
///
/// `const dt=Math.min((now-last)/1000,.05)`. The prototype's `u_time`
/// accumulator and its auto-hue both use the capped delta.
const double kLumenMaxFrameSeconds = 0.05;

/// The white-hot core's amount — `eva/redesign.html:876`, `:1476`.
///
/// `gl.uniform1f(V.uni.white,.22)`, and the checkbox sends `0.22` or `0`.
const double kLumenWhiteCore = 0.22;

/// The spike a shape change raises — `eva/redesign.html:1463`.
///
/// `if(V)V.spike=.4`.
const double kLumenShapeSpike = 0.4;

/// The spike the aurora switch raises — `eva/redesign.html:1468`.
///
/// `if(shaderOn&&V)V.spike=.4`.
const double kLumenToggleSpike = 0.4;

/// The spike a melt change raises — `eva/redesign.html:1474`.
///
/// `V.spike=.3`. The smallest of the four, and deliberately so.
const double kLumenMeltSpike = 0.3;

/// The spike a daylight change raises — `eva/redesign.html:1482`.
///
/// `if(V)V.spike=.4`.
const double kLumenDaylightSpike = 0.4;

/// The pointer's resting value — `eva/redesign.html:876`, `:921`.
///
/// `gl.uniform2f(V.uni.ptr,-10,-10)`, and `pointerleave` puts it back. Ten
/// screen-widths away, so the glow is nowhere near the band.
///
/// **The client's reset is the touch case** — a finger lifting is an
/// `onPointerUp` — and the prototype's is the pointer leaving the element.
/// Flutter's `Listener` has no `onPointerExit` on this SDK, and the mouse
/// leaving the *window* is not a widget-level event at all. So a **mouse**
/// leaves the glow where it was, until it moves again. Recorded as a
/// divergence rather than papered over.
const Offset kLumenNoPointer = Offset(-10, -10);

/// The LUMEN aurora's animated state — the prototype's render loop, ported.
///
/// ## WHAT IT IS
///
/// The things `eva/redesign.html:887-912` does every frame that are **not**
/// the shader's own arithmetic — the four below, plus `:888`'s `timeAcc`,
/// which belongs to the clock and not to this class:
///
/// | line | what | how fast |
/// | --- | --- | --- |
/// | `:891-892` | the ambient intensity eases toward its target | 6% a frame |
/// | `:893` | the melt drifts the hue | 8° a second |
/// | `:894-896` | the hue eases toward its target, the short way round | 4.5% a frame |
/// | `:900` | the spike decays | ×0.92 a frame |
///
/// Everything else the shader does — the rays, the shimmer, the melt's three
/// sine weights — is `u_time` arithmetic inside `shaders/lumen.frag` and
/// needs nothing here.
///
/// ## WHY IT EXISTS AT ALL, RATHER THAN A TABLE THE CALLER BUILDS
///
/// Because the eased values are **state**. A hue that eases is a hue that was
/// somewhere else a moment ago, and "somewhere else" cannot be derived from
/// the reader's current choice — it can only be carried forward from the last
/// frame. A caller-built table has no memory, so it cannot ease: it would
/// either snap (and the transition the prototype spends four lines on would
/// be gone) or need a table of its own (and then there would be two sources
/// of truth for the aurora's colour).
///
/// ## WHY IT IS APP-GLOBAL AND NOT PER-SCREEN
///
/// Because the prototype's state lives in one JS closure behind one canvas
/// (`:881-912`), so it **survives a screen change**. Leaving `/settings` and
/// coming back does not restart the aurora's transition.
///
/// And because Phase 6's `AutoTabsRouter` keeps three tab screens alive at
/// once: per-screen state would put the three tabs at three different phases
/// of the same aurora, and the tab swap would visibly jump. One scene, one
/// phase.
///
/// ## WHY IT IS A `LumenUniformSource`
///
/// Because the painter that paints it must be **long-lived** — one
/// `FragmentShader`, one uniform buffer — and the table changes every frame.
/// The source seam (`lumen_canvas.dart`) is what lets a stable painter read a
/// changing table, and the scene is that seam's live end.
///
/// It is also the painter's **repaint** signal, and that is not an
/// afterthought: the scene advances its state and *then* notifies, so the
/// paint triggered by that notification reads the frame it just computed.
final class LumenScene extends ChangeNotifier implements LumenUniformSource {
  /// Creates the scene, ticking from [clock].
  ///
  /// [preferences] is the reader's starting choices. The scene opens at the
  /// hue they chose — **not** at the prototype's boot hue of 258
  /// (`eva/redesign.html:881`), which the prototype reaches only because its
  /// slider starts out of sync with `autoH`. The client's slider and its
  /// aurora agree from the first frame, which is the divergence this task's
  /// plan block records.
  LumenScene({
    required LumenClock clock,
    LumenPreferences preferences = const LumenPreferences(),
    DateTime Function()? now,
  }) : _clock = clock,
       _preferences = preferences,
       _currentHue = preferences.hue.toDouble(),
       _currentSaturation = kLumenHueSaturation,
       _currentLightness = kLumenHueLightness,
       _ambient = kLumenAmbientOpen,
       _autoHue = preferences.hue.toDouble(),
       _lastTickSeconds = clock.seconds,
       _now = now ?? DateTime.now {
    _clock.addListener(_onTick);
    pointer.addListener(_onPointerMoved);
  }

  /// The clock `u_time` is read from, and the frame signal.
  final LumenClock _clock;

  /// The wall clock the vespers test reads.
  ///
  /// ## WHY A SEPARATE CLOCK AND NOT [LumenClock]
  ///
  /// [LumenClock] is the shader's `u_time` — **elapsed seconds since the
  /// scene started**, and deliberately monotonic. The vespers test needs the
  /// **hour of the day**, which is neither: it is a wall-clock reading that
  /// jumps backwards at midnight and repeats every twenty-four hours.
  ///
  /// ## AND WHY IT IS INJECTED
  ///
  /// Because a scene that read `DateTime.now()` directly would make its own
  /// ambient **time-dependent**, and the suite's ambient assertions would
  /// pass at 09:00 and fail at 22:00. A test injects a fixed hour and the
  /// assertion is the same at every hour of the day.
  final DateTime Function() _now;

  /// The wall clock the vespers test reads.
  DateTime Function() get now => _now;

  @override
  LumenClock get clock => _clock;

  /// The reader's current choices.
  LumenPreferences _preferences;

  /// Whether this scene has been disposed.
  ///
  /// `ChangeNotifier.notifyListeners` asserts on a disposed notifier, and the
  /// scene outlives nothing that could call it — but the guard is the same one
  /// `EvaNeuralMotion` carries, and it is cheaper than a debug-mode crash in
  /// a teardown order nobody wrote.
  bool _disposed = false;

  /// The eased hue, in degrees.
  double _currentHue;

  /// The eased saturation.
  double _currentSaturation;

  /// The eased lightness.
  double _currentLightness;

  /// The eased ambient intensity.
  double _ambient;

  /// The transient kick the shader adds to `u_int`.
  double _spike = 0;

  /// The angle the melt drifts, and the hue the reader chose.
  double _autoHue;

  /// The clock's reading at the last tick — the frame delta's other end.
  double _lastTickSeconds;

  /// Whether the aurora is in daylight.
  bool _light = false;

  /// Whether the `shafts` shape may be painted.
  ///
  /// False above the pixel budget (`kShaftsPixelBudget`), where the shape
  /// costs 5.04 ns/px against the bands' 2.98.
  bool _shaftsAllowed = true;

  /// The pointer, in the shader's own normalisation.
  ///
  /// The **shader's** normalisation and not the orb parallax one:
  /// `pointerOffsetFor` (`neural_orbs.dart:640-643`) divides by the width and
  /// the height separately and scales by the parallax box, which are not the
  /// numbers `u_ptr` is compared against. See [lumenPointerFor].
  final ValueNotifier<Offset> pointer = ValueNotifier<Offset>(kLumenNoPointer);

  /// The eased hue, in degrees. Test-visible: it is the state a test asserts.
  double get currentHue => _currentHue;

  /// The eased saturation. Test-visible.
  double get currentSaturation => _currentSaturation;

  /// The eased lightness. Test-visible.
  double get currentLightness => _currentLightness;

  /// The eased ambient intensity. Test-visible.
  double get ambient => _ambient;

  /// The spike. Test-visible.
  double get spike => _spike;

  /// The angle the melt drifts. Test-visible.
  double get autoHue => _autoHue;

  /// The reader's current choices. Test-visible.
  LumenPreferences get preferences => _preferences;

  /// The ambient intensity's target — `eva/redesign.html:891`.
  ///
  /// `base=ambBase*bright*vesp*(focusDim?0.45:1)`.
  ///
  /// **All four factors are the prototype's, and the two that were missing
  /// are here now.** `vesp` is the vespers auto-dim
  /// (`core/domain/entities/vespers.dart`'s `vespersFactor`, and the
  /// reader's own switch is `LumenPreferences.vespersAutoDim`), and
  /// `focusDim` is the focus mode's half — which is **runtime state and not a
  /// preference**, so it lives on this scene and is written by whoever is
  /// dimming: `/reading`'s idle timer and the selah.
  double get ambientTarget =>
      kLumenAmbientBase *
      brightnessFromGlow(_preferences.glow.toDouble()) *
      vespersFactor(enabled: _preferences.vespersAutoDim, hour: _now().hour) *
      (focusDimmed ? kLumenFocusDimFactor : 1);

  /// How many holders are asking for the screen to be dimmed.
  ///
  /// ## WHY A **COUNT** AND NOT A BOOLEAN
  ///
  /// Because two different things dim the app and they can overlap: `/reading`'s
  /// idle timer and the selah's silence. The prototype has one global
  /// `focusDim` flag (`eva/redesign.html:884`) and sets it from both
  /// (`:1292` and `:1338`), so the prototype's version has the same collision
  /// — but the prototype's reader is on one route at a time, and this client's
  /// dock keeps three tabs alive at once.
  ///
  /// A boolean would let the first holder to leave switch the dim off while
  /// the second is still asking for it. A count cannot: the dim is on while
  /// anybody holds it.
  ///
  /// **And [undimFocus] without a matching [dimFocus] is a no-op**, so a
  /// widget that disposes twice cannot drive the count negative and switch
  /// the dim on for everybody else.
  int _focusDimHolders = 0;

  /// Whether the screen is currently dimmed.
  bool get focusDimmed => _focusDimHolders > 0;

  /// Asks for the screen to be dimmed.
  void dimFocus() {
    _focusDimHolders++;
    notifyListeners();
  }

  /// Releases one request for the dim.
  void undimFocus() {
    if (_focusDimHolders <= 0) return;
    _focusDimHolders--;
    notifyListeners();
  }

  /// Raises the transient kick the shader adds to `u_int`.
  ///
  /// `eva/redesign.html:1330` — `if(V)V.spike=.5;`, the selah's end.
  /// `eva/redesign.html:1428` — `if(V)V.spike=1.0;`, a correct answer.
  ///
  /// **The prototype ASSIGNS the spike, and so does this** — a caller that
  /// raises the spike while another is decaying it replaces it rather than
  /// adding to it, which is the prototype's own arithmetic (`:900`'s
  /// `V.spike*=0.92` decays whatever is there).
  void raiseSpike(double value) {
    if (_disposed) return;
    _spike = value;
    notifyListeners();
  }

  /// Sets the reader's choices, and raises the spikes the prototype raises.
  ///
  /// The spikes are the prototype's, one per handler:
  /// `:1463` `.4` on a shape change, `:1468` `.4` on the aurora switch, `:1474`
  /// `.3` on the melt, `:1482` `.4` on daylight.
  ///
  /// They are applied in that order — the prototype's own order in the file —
  /// and the last one applied wins, because the prototype's handlers each
  /// **assign** `V.spike` rather than adding to it. In practice a reader
  /// changes one thing at a time, so the order is only reachable by a
  /// settings reset, which restores every field at once.
  void retarget({
    required LumenPreferences preferences,
    bool light = false,
    bool shaftsAllowed = true,
  }) {
    final LumenPreferences previous = _preferences;
    final bool wasLight = _light;
    if (preferences == previous &&
        light == wasLight &&
        shaftsAllowed == _shaftsAllowed) {
      return;
    }
    if (_disposed) return;
    _preferences = preferences;
    _light = light;
    _shaftsAllowed = shaftsAllowed;

    if (preferences.shape != previous.shape) {
      _spike = kLumenShapeSpike;
    }
    // `:1468` — `if(shaderOn&&V)V.spike=.4;`. The spike is raised when the
    // aurora is turned **on**, not when it is turned off, and the prototype's
    // guard is `shaderOn` — so the assignment is one-directional.
    if (preferences.enabled && !previous.enabled) {
      _spike = kLumenToggleSpike;
    }
    if (preferences.melt != previous.melt) {
      // `:1473` — the melt continues from the hue the aurora is at, so the
      // drift starts where the reader left it rather than jumping.
      if (preferences.melt) _autoHue = _currentHue;
      _spike = kLumenMeltSpike;
    }
    // `:1472` — `autoH=+e.target.value; setTargetHue({h:autoH,s:70,l:62});`.
    // The slider writes `autoH` itself, and `:893` then drives `tgtH.h=autoH`
    // every frame — **so the slider still moves the aurora while the melt is
    // on**, because the melt follows the slider and not the other way round.
    // Without this the slider would be inert for as long as the melt was on.
    if (preferences.hue != previous.hue) {
      _autoHue = preferences.hue.toDouble();
    }
    if (light != wasLight) {
      _spike = kLumenDaylightSpike;
    }
    notifyListeners();
  }

  /// The table a rect of [size] paints.
  ///
  /// The `u_res` and `u_time` are the rect's and the clock's, exactly as
  /// `LumenCanvas` would have supplied them; everything else is the scene's.
  @override
  LumenUniforms tableAt(Size size) => const LumenUniforms.identity()
      .withHue(h: _currentHue, s: _currentSaturation, l: _currentLightness)
      .copyWith(
        resX: size.width,
        resY: size.height,
        time: _clock.seconds,
        shape: _shapeIndex,
        spread: spreadFromReach(_preferences.reach.toDouble()),
        rays: _preferences.rayCombing ? 1 : 0,
        pointerX: pointer.value.dx,
        pointerY: pointer.value.dy,
        pointerIntensity: ptrIntensityFromTouch(
          _preferences.touchGlow.toDouble(),
        ),
        intensity: _ambient,
        spike: _spike,
        melt: _preferences.melt ? 1 : 0,
        white: _preferences.whiteCores ? kLumenWhiteCore : 0,
        light: _light ? 1 : 0,
        dots: _preferences.dotVeil ? 1 : 0,
      );

  /// The shape the shader draws.
  ///
  /// **`shafts` paints as `sides` when the budget denies it** — the clamp
  /// `LumenShaderTier.noShafts`'s own doc assigns to whoever mounts the
  /// shader. The reader's stored choice is untouched, so restoring the budget
  /// restores their shape.
  int get _shapeIndex {
    if (_preferences.shape == CurtainShape.shafts && !_shaftsAllowed) {
      return CurtainShape.sides.shaderIndex;
    }
    return _preferences.shape.shaderIndex;
  }

  /// One frame.
  void _onTick() {
    if (_disposed) return;
    final double now = _clock.seconds;
    final double delta = math.min(
      math.max(now - _lastTickSeconds, 0.0),
      kLumenMaxFrameSeconds,
    );
    _lastTickSeconds = now;
    _advance(delta);
    notifyListeners();
  }

  /// The prototype's four steps, in its order.
  ///
  /// [delta] is the **capped** frame delta — `eva/redesign.html:888` caps it
  /// at 0.05 s and the auto-hue uses the capped value.
  void _advance(double delta) {
    // `:891-892` — the ambient intensity eases at 6% a frame.
    _ambient += (ambientTarget - _ambient) * kLumenAmbientEase;

    // `:893` — the melt drifts the hue at 8° a second.
    if (_preferences.melt) {
      _autoHue = (_autoHue + delta * kLumenAutoHueRate) % 360;
    }

    // `:894-896` — the hue eases at 4.5% a frame, the short way round.
    final double target = _preferences.melt
        ? _autoHue
        : _preferences.hue.toDouble();
    final double arc = _shortestArc(target, _currentHue);
    _currentHue = (_currentHue + arc * kLumenHueEase + 360) % 360;
    _currentSaturation +=
        (kLumenHueSaturation - _currentSaturation) * kLumenHueEase;
    _currentLightness +=
        (kLumenHueLightness - _currentLightness) * kLumenHueEase;

    // `:900` — the spike decays.
    _spike = decaySpike(_spike);
  }

  /// The signed shortest arc from [from] to [to], in degrees.
  ///
  /// `eva/redesign.html:894` — `dh=((tgtH.h-curH.h+540)%360)-180`. The
  /// `+540` and the `-180` put the result in `(-180, 180]`, so a change
  /// across 0° does not sweep the long way round.
  double _shortestArc(double to, double from) =>
      ((to - from + 540) % 360) - 180;

  void _onPointerMoved() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // The subscription first, for the reason `EvaNeuralMotion.dispose` gives:
    // disposing a controller clears its listeners, and clearing this one first
    // stops a notification reaching a half-disposed notifier.
    _clock.removeListener(_onTick);
    pointer.removeListener(_onPointerMoved);
    pointer.dispose();
    super.dispose();
  }

  @override
  String toString() =>
      'LumenScene(hue: ${_currentHue.toStringAsFixed(2)}, '
      'ambient: ${_ambient.toStringAsFixed(4)}, spike: ${_spike.toStringAsFixed(4)})';
}

/// The pointer in the shader's own normalisation — `eva/redesign.html:918-919`.
///
/// ```js
/// const mn=Math.min(r.width,r.height);
/// ptrX=((e.clientX-r.left)-r.width/2)/mn;
/// ptrY=(r.height/2-(e.clientY-r.top))/mn;
/// ```
///
/// ## WHY THIS IS **NOT** `pointerOffsetFor`
///
/// `pointerOffsetFor` (`neural_orbs.dart:640-643`) is the **orb parallax**
/// offset: it divides by the width and the height *separately* and scales by
/// `kPointerSpanX`/`kPointerSpanY`. `u_ptr` is compared against the shader's
/// `uv`, which is `(_fc - 0.5*u_res)/min(u_res.x,u_res.y)` — centred,
/// normalised by the **short side**, and +Y up. The two are different numbers
/// that look alike, and reusing the parallax one would have put the glow
/// somewhere the reader did not touch.
///
/// The Y is **inverted** for the same reason the prototype's is: the shader's
/// `uv` has +Y up, and a touch at the top of the screen has to be *above*
/// the band.
Offset lumenPointerFor({required Size size, required Offset local}) {
  final double shortest = size.shortestSide;
  // A zero or infinite short side would divide to a NaN or an infinity, and
  // `u_ptr` is compared against `uv` inside `exp(-(pd*pd)/0.07)` — so a NaN
  // there takes the whole fragment with it, silently. The same guard the
  // legacy painter makes for the orb offset ("dividing by a zero width would
  // put a NaN into the pointer offset").
  if (shortest <= 0 || !shortest.isFinite) return kLumenNoPointer;
  return Offset(
    (local.dx - size.width / 2) / shortest,
    (size.height / 2 - local.dy) / shortest,
  );
}
