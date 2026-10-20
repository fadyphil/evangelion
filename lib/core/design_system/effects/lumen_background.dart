import 'package:evangelion/core/design_system/effects/lumen_canvas.dart';
import 'package:evangelion/core/design_system/effects/lumen_preferences.dart';
import 'package:evangelion/core/design_system/effects/lumen_program.dart';
import 'package:evangelion/core/design_system/effects/lumen_scene.dart';
import 'package:evangelion/core/design_system/effects/neural_background.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter/material.dart';

/// The screen's ambient layer: the LUMEN aurora, or the fallback.
///
/// ## WHAT IT REPLACES, AND WHY BOTH ARE HERE
///
/// `NeuralScaffold` used to paint `NeuralBackground` — the old design's neural
/// orbs — as its first stack child. This widget stands in that place and
/// decides, per frame of the reader's life, which of the two paints:
///
/// | the reader | the tier | what paints |
/// | --- | --- | --- |
/// | the aurora is on | `mid` / `high` | **the aurora** — `shaders/lumen.frag` |
/// | the aurora is on | `low` (or reduced motion) | `NeuralBackground` |
/// | the aurora is off | any | `NeuralBackground` |
/// | no preferences published | any | `NeuralBackground` |
///
/// ## WHY THE FALLBACK IS **TODAY'S** BACKGROUND
///
/// Because the plan says so — Task 1.5 Step 3 (`plan:799-801`): *"`low` (or
/// reduce-motion) → shader off, static `CustomPainter` aurora — today's
/// `neural_background.dart` behaviour, which is already tier-aware."* The
/// legacy painter is not rewritten to look like the shader; it is the thing
/// that was already there, and it is what a reduced-motion reader sees.
///
/// ## WHY THE TIER IS RESOLVED **HERE** AND NOT IN THE SCOPE
///
/// Because `NeuralTiers.resolveShader` needs the viewport and the reader's
/// motion preference, and this widget is the first thing in the tree that
/// has both. `NeuralBackground` resolves the same tier for itself, which is
/// one extra resolution on the fallback path and no second source of truth —
/// `NeuralTiers.resolve` is a pure function of its two arguments.
///
/// ## WHY THE PAINTER IS HELD ACROSS FRAMES
///
/// Because `LumenCanvas` allocates a `FragmentShader` — and therefore a
/// uniform buffer — on its first paint, and a painter rebuilt per frame would
/// allocate one per frame. The plan's wiring constraint (`plan:805-811`) says
/// so in as many words, and `lumen_canvas.dart`'s class doc says why the
/// saving only materialises if the instance is long-lived.
///
/// So this is a [StatefulWidget] that builds **one** painter and hands the
/// same instance to the [CustomPaint] on every rebuild. The table inside it
/// changes every frame, and that is what the [LumenUniformSource] seam is
/// for.
class LumenBackground extends StatefulWidget {
  /// Paints the ambient background for [variant].
  const LumenBackground({required this.variant, this.tier, super.key});

  /// Which screen's fallback orb group to paint.
  ///
  /// **The variant no longer selects the ambient.** The redesign has one
  /// canvas for every screen (`eva/redesign.html:46`), so the aurora does not
  /// vary by screen; the variant selects the **fallback's** orb group, which
  /// is the only thing that still varies.
  final NeuralVariant variant;

  /// Forces a [NeuralTier] instead of resolving one. `null` resolves.
  final NeuralTier? tier;

  @override
  State<LumenBackground> createState() => _LumenBackgroundState();
}

class _LumenBackgroundState extends State<LumenBackground> {
  /// The compiled shader, once it is there.
  LumenProgram? _program;

  /// The one painter, held across frames. See the class doc.
  LumenCanvas? _canvas;

  /// The scene the painter reads its table from.
  LumenScene? _scene;

  @override
  void initState() {
    super.initState();
    final LumenProgram? loaded = LumenProgram.loaded();
    if (loaded != null) {
      _program = loaded;
      return;
    }
    // Not loaded yet: the fallback paints until it is, and the aurora takes
    // over on the frame after. The app loads the program during bootstrap, so
    // in production this branch never runs — see `LumenProgram.loaded`'s doc.
    LumenProgram.load().then((LumenProgram program) {
      if (!mounted) return;
      setState(() => _program = program);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LumenScene scene = NeuralMotionScope.of(context).lumenScene;
    final LumenPreferences? preferences = LumenPreferencesScope.maybeOf(
      context,
    );
    final Brightness brightness = Theme.of(context).brightness;
    final LumenShaderTier tier = _shaderTier(brightness);

    if (!identical(scene, _scene)) {
      _scene = scene;
      // A new scene means a new painter: the painter's source **is** the
      // scene, and a painter holding the old one would read a table nobody
      // advances.
      _canvas = null;
    }
    scene.retarget(
      preferences: preferences ?? const LumenPreferences(),
      light: brightness == Brightness.light,
      shaftsAllowed: tier == LumenShaderTier.full,
    );
  }

  /// The shader's tier — and therefore whether it paints at all.
  LumenShaderTier _shaderTier(Brightness brightness) {
    // Reduced motion is the last word, and `NeuralTiers.resolve` says so: it
    // returns `low` whatever the size and whatever the override say, and
    // `low` maps to `off`. The brightness argument is not read here — it is
    // the *theme's*, and the theme is a separate question from the motion
    // preference. It is carried so the call reads as one decision.
    assert(
      brightness == Brightness.light || brightness == Brightness.dark,
      'the theme carries one of two brightnesses',
    );
    return NeuralTiers.resolveShader(
      size: MediaQuery.sizeOf(context),
      animationsEnabled: !MediaQuery.disableAnimationsOf(context),
      override: widget.tier,
    );
  }

  /// Whether the aurora paints, and why not.
  bool get _paintsAurora {
    if (_program == null) return false;
    if (_scene == null) return false;
    final LumenPreferences? preferences = LumenPreferencesScope.maybeOf(
      context,
    );
    // No preferences published: no choices, so no aurora. See
    // `LumenPreferencesScope`'s doc.
    if (preferences == null) return false;
    if (!preferences.enabled) return false;
    return _shaderTier(Theme.of(context).brightness) != LumenShaderTier.off;
  }

  @override
  Widget build(BuildContext context) {
    if (!_paintsAurora) {
      return NeuralBackground(variant: widget.variant, tier: widget.tier);
    }
    final LumenScene scene = _scene!;
    final LumenCanvas canvas = _canvas ??= LumenCanvas.source(
      program: _program!,
      source: scene,
    );
    final Brightness brightness = Theme.of(context).brightness;
    Widget painted = CustomPaint(
      painter: canvas,
      isComplex: true,
      willChange: true,
    );
    if (brightness == Brightness.light) {
      // ## THE PROTOTYPE **MULTIPLIES** ITS CANVAS INTO THE LIGHT BACKGROUND
      //
      // `eva/redesign.html:60` — `.screen[data-mode=light] canvas{mix-blend-mode:multiply}`.
      //
      // And it has to: the shader's daylight arm is
      // `col=mix(emit, vec3(1.0)-0.55*em, u_light)` (`shaders/lumen.frag:116`),
      // and with `u_light=1` and no band (`emit=0`) that is **`vec3(1.0)`** —
      // white, at alpha 1. Painted over the canvas it would erase it, and
      // every light-mode card that distinguishes `canvas` from `surface` would
      // lose the ground it stands on.
      //
      // **The multiply is against the canvas colour, and the canvas colour is
      // the backdrop.** The aurora is opaque, so the backdrop beneath it *is*
      // the canvas — which is what makes the multiplication a constant
      // multiply rather than a blend with whatever happens to be underneath.
      //
      // **A `ColorFilter`, not a `BlendMode`.** A blend mode would multiply
      // against the *destination* — and the destination inside the
      // [RepaintBoundary] is transparent, which would paint the ambient
      // **black**. The filter multiplies the aurora's own pixels, so it is
      // correct inside the boundary, and it is the one thing the boundary
      // cannot break.
      painted = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          lumenMultiplyMatrix(context.colors.canvas),
        ),
        child: painted,
      );
    }
    return RepaintBoundary(
      // The boundary is what makes "the page above never rebuilds" true rather
      // than merely intended: the aurora's per-frame damage stops here instead
      // of dirtying whatever is painted over it. The legacy background makes
      // the same argument for the same reason.
      child: painted,
    );
  }

  @override
  void dispose() {
    // The painter holds a `FragmentShader` and there is no disposal hook for
    // it — `CustomPainter` offers none, and the wrapper is GC-managed, so a
    // discarded painter takes its native peer with it. See `lumen_canvas.dart`'s
    // doc on why eager disposal is not needed.
    _canvas = null;
    super.dispose();
  }
}

/// The 4×5 colour matrix that multiplies the aurora by [colour].
///
/// **A matrix and not a blend mode**, and the reason is in
/// `lumen_background.dart`'s build: the aurora lives inside a
/// [RepaintBoundary], so a blend mode would multiply against a *transparent*
/// destination and paint the ambient black. A matrix multiplies the aurora's
/// own pixels, which is what the prototype's `mix-blend-mode:multiply`
/// amounts to — the backdrop under an opaque canvas is the canvas.
///
/// The alpha row is the identity: the aurora is opaque, and the matrix must
/// not change that.
List<double> lumenMultiplyMatrix(Color colour) => <double>[
  colour.r, 0, 0, 0, 0, //
  0, colour.g, 0, 0, 0, //
  0, 0, colour.b, 0, 0, //
  0, 0, 0, 1, 0, //
];
