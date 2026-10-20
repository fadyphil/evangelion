import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_preferences.dart';
import 'package:evangelion/core/design_system/effects/lumen_scene.dart';
import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A clock the test drives by hand.
///
/// ## WHY NOT `LumenClock.fixed`
///
/// Because a fixed clock **never notifies**, and the scene's frame signal *is*
/// the clock's notification — a scene on a fixed clock would never advance and
/// every assertion about the easing would be about a scene that stood still.
///
/// `LumenClock.fixed` is the goldens' seam, not this one's.
final class _ManualClock extends LumenClock {
  double _seconds = 0;

  @override
  double get seconds => _seconds;

  /// One frame's worth of time, and the notification that carries it.
  void advance(double delta) {
    _seconds += delta;
    notifyListeners();
  }
}

/// The prototype's own frame — `eva/redesign.html:888`.
///
/// A 60fps frame is 16.67ms. The prototype's `dt` is the real elapsed time
/// capped at 50ms, so a 16ms frame is under the cap and the two agree.
const double kFrame = 0.016;

/// The LUMEN scene — the prototype's render loop, ported.
///
/// Every number here is the prototype's, and every one of them is a claim
/// about a **specific** thing: `eva/redesign.html:887-912` is the render loop,
/// `:1462-1482` are the Workshop's handlers, and `:658-665` are the sliders.
void main() {
  late _ManualClock clock;
  late LumenScene scene;

  setUp(() {
    clock = _ManualClock();
    // **A fixed wall clock, and it is the point of the injection.** The
    // scene's ambient target now carries the vespers factor, which reads the
    // hour of the day — so a scene built on `DateTime.now()` would assert
    // 0.9 at 09:00 and 0.9 × 0.78 at 22:00, and this suite would fail
    // every night between 21:00 and 05:00.
    //
    // 09:30 is deliberately **outside** the vespers window, so the ambient
    // assertions below read the prototype's plain 0.9 and the vespers rows
    // build their own scene with an hour inside the window.
    scene = LumenScene(clock: clock, now: () => DateTime(2026, 10, 3, 9, 30));
  });

  /// Retargets the scene and returns it, so a test can chain.
  LumenScene retarget({
    LumenPreferences? preferences,
    bool light = false,
    bool shaftsAllowed = true,
  }) {
    scene.retarget(
      preferences: preferences ?? const LumenPreferences(),
      light: light,
      shaftsAllowed: shaftsAllowed,
    );
    return scene;
  }

  group('the opening', () {
    test('the ambient opens at the prototype\'s 0.15', () {
      // `eva/redesign.html:884` — `let ambI=0.15`.
      expect(scene.ambient, 0.15);
    });

    test('the hue opens at the reader\'s choice, not the prototype\'s 258', () {
      // The prototype opens at 258 because its slider starts out of sync with
      // `autoH`; the client's slider and its aurora agree from the first
      // frame. `LumenPreferences.hue` defaults to 312.
      expect(scene.currentHue, 312);
      expect(scene.currentSaturation, kLumenHueSaturation);
      expect(scene.currentLightness, kLumenHueLightness);
    });

    test('there is no spike to begin with', () {
      expect(scene.spike, 0);
    });
  });

  group('the ambient intensity — `redesign.html:891-892`', () {
    test('it eases 6% a frame toward 0.9 * glow/100', () {
      // `ambI+=(base-ambI)*0.06`, `base=ambBase*bright*vesp*(focusDim?0.45:1)`.
      // `ambBase` is 0.9 and `bright` is the glow slider over 100.
      expect(scene.ambientTarget, closeTo(0.9, 1e-12));
      clock.advance(kFrame);
      expect(scene.ambient, closeTo(0.15 + (0.9 - 0.15) * 0.06, 1e-12));
      clock.advance(kFrame);
      expect(
        scene.ambient,
        closeTo(0.15 + (0.9 - 0.15) * (0.06 + 0.94 * 0.06), 1e-12),
      );
    });

    test('the glow slider moves the target, not the current value', () {
      // `bright=e.target.value/100` (`:1470`) is folded into the *target*;
      // the current value still eases toward it. `:892`.
      retarget(preferences: const LumenPreferences(glow: 130));
      expect(scene.ambientTarget, closeTo(0.9 * 1.3, 1e-12));
      // The current value has not moved: it eases, and no frame has passed.
      expect(scene.ambient, 0.15);
    });
  });

  group('the vespers dim — `redesign.html:886` and `:890`', () {
    /// A scene whose wall clock reads [hour].
    LumenScene at(int hour) => LumenScene(
      clock: _ManualClock(),
      now: () => DateTime(2026, 10, 3, hour),
    );

    test('between 21:00 and 05:00 the ambient is 22% down', () {
      // `:890` — `const vesp=vespersOn&&isNight()?0.78:1;`.
      expect(at(22).ambientTarget, closeTo(0.9 * 0.78, 1e-12));
      expect(at(3).ambientTarget, closeTo(0.9 * 0.78, 1e-12));
    });

    test('and outside it the ambient is untouched', () {
      expect(at(12).ambientTarget, closeTo(0.9, 1e-12));
      expect(at(20).ambientTarget, closeTo(0.9, 1e-12));
    });

    test('the reader\'s own switch wins over the hour', () {
      // `:686` — the Vespers auto-dim switch, and a reader who has turned it
      // off gets no dim at three in the morning.
      final LumenScene off = LumenScene(
        clock: _ManualClock(),
        preferences: const LumenPreferences(vespersAutoDim: false),
        now: () => DateTime(2026, 10, 3, 22),
      );
      expect(off.ambientTarget, closeTo(0.9, 1e-12));
    });

    test('and the scene reads the clock it was given', () {
      // The scene's own `now` is the injected wall clock, and the point of
      // injecting it is that a scene built on `DateTime.now()` would be
      // **time-dependent**: the same assertion would pass at 09:00 and fail at
      // 22:00. So the getter has to hand back the injected hour, and this is
      // the assertion that says it does.
      expect(at(22).now(), DateTime(2026, 10, 3, 22));
      expect(at(3).now(), DateTime(2026, 10, 3, 3));
    });
  });

  group('the focus dim — `redesign.html:891`', () {
    test('the ambient is 45% down while the screen is dimmed', () {
      // `:891` — `base=ambBase*bright*vesp*(focusDim?0.45:1)`.
      expect(scene.ambientTarget, closeTo(0.9, 1e-12));
      scene.dimFocus();
      expect(scene.ambientTarget, closeTo(0.9 * 0.45, 1e-12));
      scene.undimFocus();
      expect(scene.ambientTarget, closeTo(0.9, 1e-12));
    });

    test('two holders are two dim requests, and the first release does not '
        'switch it off', () {
      // The selah and `/reading`'s idle timer can both be dimming at once, and
      // the dock keeps three tabs alive, so the flag is a count.
      scene.dimFocus();
      scene.dimFocus();
      expect(scene.focusDimmed, isTrue);
      scene.undimFocus();
      expect(scene.focusDimmed, isTrue);
      scene.undimFocus();
      expect(scene.focusDimmed, isFalse);
    });

    test('releasing a dim nobody asked for is a no-op', () {
      scene.undimFocus();
      scene.undimFocus();
      expect(scene.focusDimmed, isFalse);
      expect(scene.ambientTarget, closeTo(0.9, 1e-12));
    });

    test('the dim and the vespers multiply, as the prototype\'s expression '
        'does', () {
      final LumenScene both = LumenScene(
        clock: _ManualClock(),
        now: () => DateTime(2026, 10, 3, 22),
      );
      both.dimFocus();
      expect(both.ambientTarget, closeTo(0.9 * 0.78 * 0.45, 1e-12));
    });
  });

  group('the hue — `redesign.html:894-896`', () {
    test('it eases 4.5% a frame, the SHORT way round', () {
      // 312 → 12 is +60° the short way, not -300° the long way.
      retarget(preferences: const LumenPreferences(hue: 12));
      clock.advance(kFrame);
      expect(scene.currentHue, closeTo(312 + 60 * 0.045, 1e-9));
    });

    test('and the other way round is -60°, not +300°', () {
      // From 12 to 312 the short arc is -60. A port that added the raw
      // difference would sweep 300° the long way round, which is the whole
      // point of the `+540`/`-180` in `:894`.
      final _ManualClock other = _ManualClock();
      final LumenScene backwards = LumenScene(
        clock: other,
        preferences: const LumenPreferences(hue: 12),
      );
      // 312 is the default hue, so this is the reader sliding it back.
      backwards.retarget(preferences: const LumenPreferences());
      other.advance(kFrame);
      // 12 → 312 the short way is **-60°**, so the hue goes DOWN.
      expect(backwards.currentHue, closeTo(12 - 60 * 0.045, 1e-9));
    });

    test('the saturation and the lightness ease at the same rate', () {
      // `:896` — `curH.s+=(tgtH.s-curH.s)*0.045; curH.l+=(tgtH.l-curH.l)*0.045;`
      // The client's target is the slider's (70, 62) and it opens there, so
      // there is nothing to ease — the assertion is that the rate is the
      // prototype's and the target is the slider's.
      expect(kLumenHueEase, 0.045);
      expect(scene.currentSaturation, 70);
      expect(scene.currentLightness, 62);
    });
  });

  group('the melt — `redesign.html:893` and `:1473-1474`', () {
    test('it drifts the hue at 8 degrees a second', () {
      retarget(preferences: const LumenPreferences(melt: true));
      expect(
        scene.autoHue,
        closeTo(312, 1e-9),
        reason: 'it starts where the aurora is',
      );
      clock.advance(kFrame);
      expect(scene.autoHue, closeTo(312 + kFrame * 8, 1e-9));
    });

    test('and it starts from the hue the aurora is AT, not the slider\'s', () {
      // `:1473` — `if(meltOn)autoH=curH.h;`. The reader had dragged the hue
      // to 100 and the aurora was easing toward it; the melt continues from
      // where the aurora is.
      retarget(preferences: const LumenPreferences(hue: 100));
      clock.advance(kFrame);
      final double at = scene.currentHue;
      retarget(preferences: const LumenPreferences(hue: 100, melt: true));
      expect(scene.autoHue, closeTo(at, 1e-9));
    });

    test('and the hue slider still moves it while the melt is on', () {
      // `:1472` — `autoH=+e.target.value; setTargetHue({h:autoH,s:70,l:62});`.
      // The slider writes `autoH` itself and `:893` then drives
      // `tgtH.h=autoH` every frame, so the slider moves the aurora **while
      // the melt is on** — the melt follows the slider, not the other way
      // round. Without this the slider would be inert for as long as the melt
      // was on.
      retarget(preferences: const LumenPreferences(melt: true));
      clock.advance(kFrame);
      final double before = scene.autoHue;

      retarget(preferences: const LumenPreferences(melt: true, hue: 100));
      expect(
        scene.autoHue,
        closeTo(100, 1e-9),
        reason: 'the slider wrote the drift angle',
      );
      clock.advance(kFrame);
      expect(scene.autoHue, closeTo(100 + kFrame * 8, 1e-9));
      expect(scene.autoHue, isNot(closeTo(before, 1e-6)));
    });

    test('the drift stops when the melt is off', () {
      retarget(preferences: const LumenPreferences(melt: true));
      clock.advance(kFrame);
      final double drifted = scene.autoHue;
      retarget(preferences: const LumenPreferences());
      clock.advance(kFrame);
      expect(scene.autoHue, closeTo(drifted, 1e-9));
    });
  });

  group('the spike — `redesign.html:900` and the four handlers', () {
    test('a shape change raises 0.4', () {
      // `:1463` — `if(V)V.spike=.4;`
      retarget(preferences: const LumenPreferences(shape: CurtainShape.sides));
      expect(scene.spike, 0.4);
    });

    test('the aurora switch raises 0.4 — when it is turned ON', () {
      // `:1468` — `if(shaderOn&&V)V.spike=.4;`. The prototype's guard is
      // `shaderOn`, so the spike is raised when the aurora is turned **on**
      // and not when it is turned off.
      retarget(preferences: const LumenPreferences(enabled: false));
      expect(
        scene.spike,
        0,
        reason: 'turning it off raises nothing — the aurora is not painted',
      );
      retarget(preferences: const LumenPreferences());
      expect(scene.spike, 0.4);
    });

    test('a melt change raises 0.3', () {
      // `:1474` — `V.spike=.3;`. The smallest of the four, and deliberately so.
      retarget(preferences: const LumenPreferences(melt: true));
      expect(scene.spike, 0.3);
    });

    test('a daylight change raises 0.4', () {
      // `:1482` — `if(V)V.spike=.4;`
      retarget(light: true);
      expect(scene.spike, 0.4);
    });

    test('it decays at 0.92 a frame', () {
      retarget(preferences: const LumenPreferences(shape: CurtainShape.sides));
      clock.advance(kFrame);
      expect(scene.spike, closeTo(0.4 * 0.92, 1e-12));
      clock.advance(kFrame);
      expect(scene.spike, closeTo(0.4 * 0.92 * 0.92, 1e-12));
    });

    test('nothing else raises it', () {
      // A hue change is not one of the four handlers: `:1472` sets the target
      // and the swatch and raises nothing.
      retarget(preferences: const LumenPreferences(hue: 100));
      expect(scene.spike, 0);
    });
  });

  group('the table the shader receives', () {
    test('it carries the reader\'s ten choices', () {
      final LumenUniforms table = scene.tableAt(const Size(400, 800));
      // `:658` reach 42 → `spreadFromReach` → 0.42.
      expect(table.spread, closeTo(0.42, 1e-12));
      // `:663` the rays are combed.
      expect(table.rays, 1);
      // `:662` the melt is off.
      expect(table.melt, 0);
      // `:664` the white core is on, at 0.22.
      expect(table.white, closeTo(0.22, 1e-12));
      // `:665` the dot veil is off.
      expect(table.dots, 0);
      // `:660` touch 55 → `ptrIntensityFromTouch` → 0.33.
      expect(table.pointerIntensity, closeTo(0.33, 1e-12));
      // `:654-655` the shape is `top`, which is `u_shape` 0.
      expect(table.shape, 0);
    });

    test(
      'the reach, the touch glow and the rays all move with the sliders',
      () {
        retarget(
          preferences: const LumenPreferences(
            reach: 110,
            touchGlow: 100,
            rayCombing: false,
          ),
        );
        final LumenUniforms table = scene.tableAt(const Size(400, 800));
        expect(table.spread, closeTo(1.1, 1e-12));
        expect(table.pointerIntensity, closeTo(0.6, 1e-12));
        expect(table.rays, 0);
      },
    );

    test('`u_res` is the rect and `u_time` is the clock', () {
      clock.advance(3.7);
      final LumenUniforms table = scene.tableAt(const Size(400, 800));
      expect(table.resX, 400);
      expect(table.resY, 800);
      expect(table.time, closeTo(3.7, 1e-12));
    });

    test('the hue is the reader\'s, and the triple is derived from it', () {
      // `:901-903` — the second hue is +38° with the lightness **lifted by 6
      // and capped at 88**, and the third is -42° at the base lightness. The
      // cap never fires at the slider's own lightness of 62, so a port that
      // dropped it would be indistinguishable until someone raised the
      // lightness — which is why the lifted 68 is asserted here and not 62.
      final LumenUniforms table = scene.tableAt(const Size(400, 800));
      expect(table.hue, hslToRgb(h: 312, s: 70, l: 62));
      expect(table.hue2, hslToRgb(h: 350, s: 70, l: 68));
      expect(table.hue3, hslToRgb(h: 270, s: 70, l: 62));
    });

    test('the pointer rides in the table', () {
      scene.pointer.value = const Offset(0.25, -0.5);
      final LumenUniforms table = scene.tableAt(const Size(400, 800));
      expect(table.pointerX, 0.25);
      expect(table.pointerY, -0.5);
    });

    test('it rests at the prototype\'s (-10, -10)', () {
      // `:876` — `gl.uniform2f(V.uni.ptr,-10,-10)`.
      final LumenUniforms table = scene.tableAt(const Size(400, 800));
      expect(table.pointerX, -10);
      expect(table.pointerY, -10);
    });
  });

  group('the shafts clamp — `LumenShaderTier.noShafts`', () {
    test('shafts paints as sides above the pixel budget', () {
      // The tier's own doc: "a stored `shafts` preference paints as `sides`
      // (shape 2) rather than being forgotten, so toggling back under budget
      // restores it."
      retarget(
        preferences: const LumenPreferences(shape: CurtainShape.shafts),
        shaftsAllowed: false,
      );
      expect(scene.tableAt(const Size(400, 800)).shape, 2);
    });

    test('and the reader\'s stored choice is untouched', () {
      retarget(
        preferences: const LumenPreferences(shape: CurtainShape.shafts),
        shaftsAllowed: false,
      );
      expect(scene.preferences.shape, CurtainShape.shafts);
    });

    test('shafts paints as shafts when the budget allows it', () {
      retarget(preferences: const LumenPreferences(shape: CurtainShape.shafts));
      expect(scene.tableAt(const Size(400, 800)).shape, 3);
    });
  });

  group('the identity of the scene', () {
    test('it exposes the clock it ticks from', () {
      // `LumenUniformSource` requires it — the source is what decides what
      // `u_time` is, and the scene's answer is its clock's seconds.
      expect(scene.clock, clock);
      expect(scene.clock.seconds, 0);
      clock.advance(2.5);
      expect(scene.clock.seconds, 2.5);
    });

    test('and it names its state', () {
      // Failure output: three numbers that a failed `expect` has to print.
      expect(
        scene.toString(),
        'LumenScene(hue: 312.00, ambient: 0.1500, spike: 0.0000)',
      );
    });
  });

  group('the notification', () {
    test('the clock\'s notification is the frame signal', () {
      int fired = 0;
      scene.addListener(() => fired++);
      clock.advance(kFrame);
      expect(fired, 1);
      clock.advance(kFrame);
      expect(fired, 2);
    });

    test(
      'a pointer move is a frame too — the glow has to follow the touch',
      () {
        int fired = 0;
        scene.addListener(() => fired++);
        scene.pointer.value = const Offset(0.1, 0.2);
        expect(fired, 1);
      },
    );

    test('the frame delta is capped at 50ms, as the prototype caps it', () {
      // `:888` — `const dt=Math.min((now-last)/1000,.05)`. A frame that took a
      // second advances the auto-hue by 0.05s worth, not by a second's.
      retarget(preferences: const LumenPreferences(melt: true));
      clock.advance(1.0);
      expect(scene.autoHue, closeTo(312 + 0.05 * 8, 1e-9));
    });
  });

  group('the pointer normalisation — `redesign.html:918-919`', () {
    test('it is centred and normalised by the SHORT side', () {
      // ```js
      // const mn=Math.min(r.width,r.height);
      // ptrX=((e.clientX-r.left)-r.width/2)/mn;
      // ptrY=(r.height/2-(e.clientY-r.top))/mn;
      // ```
      final Offset pointer = lumenPointerFor(
        size: const Size(390, 844),
        local: const Offset(195, 422),
      );
      expect(pointer.dx, closeTo(0, 1e-12));
      expect(pointer.dy, closeTo(0, 1e-12));
    });

    test('the Y is inverted — the shader measures from the bottom', () {
      final Offset atTop = lumenPointerFor(
        size: const Size(390, 844),
        local: const Offset(195, 0),
      );
      expect(atTop.dy, closeTo(844 / 2 / 390, 1e-12));
      final Offset atBottom = lumenPointerFor(
        size: const Size(390, 844),
        local: const Offset(195, 844),
      );
      expect(atBottom.dy, closeTo(-844 / 2 / 390, 1e-12));
    });

    test('the divisor is the SHORT side, not the width', () {
      // ## THE NEGATIVE CONTROL, REWRITTEN
      //
      // The old control compared this normalisation against the **orb
      // parallax** offset — a second number that divides by the width and the
      // height *separately*. The orbs are retired, so that comparison has no
      // subject, and a control against a number that no longer exists proves
      // nothing.
      //
      // What distinguishes this normalisation from a per-axis one is the
      // **divisor**, and that is asserted directly: on a landscape viewport the
      // short side is the height, so the X is divided by 390 and not by 844.
      // A per-axis normalisation would answer `195 / 844`.
      final Offset landscape = lumenPointerFor(
        size: const Size(844, 390),
        local: const Offset(844, 195),
      );
      expect(landscape.dx, closeTo(422 / 390, 1e-12));
      expect(
        landscape.dx,
        isNot(closeTo(422 / 844, 1e-6)),
        reason: 'a per-axis normalisation would have divided by the width',
      );
      expect(landscape.dy, closeTo(0, 1e-12));
    });
  });
}
