import 'package:evangelion/core/design_system/effects/lumen_canvas.dart';
import 'package:evangelion/core/design_system/effects/lumen_preferences.dart';
import 'package:evangelion/core/design_system/effects/lumen_program.dart';
import 'package:evangelion/core/design_system/effects/lumen_scene.dart';
import 'package:evangelion/core/design_system/effects/lumen_tier.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter/material.dart';

/// The screen's ambient layer: the LUMEN aurora, or the flat canvas.
///
/// ## WHAT IT REPLACES, AND WHY BOTH ARE HERE
///
/// `NeuralScaffold` used to paint `NeuralBackground` — the old design's neural
/// orbs — as its first stack child, and the redesign's plan made this widget
/// stand in that place and decide, per frame of the reader's life, which of the
/// two paints:
///
/// | the reader | the tier | what paints |
/// | --- | --- | --- |
/// | the aurora is on | `full` / `noShafts` | **the aurora** — `shaders/lumen.frag` |
/// | the aurora is on | `off` (or reduced motion) | the **flat canvas** |
/// | the aurora is off | any | the **flat canvas** |
/// | no preferences published | any | the **flat canvas** |
///
/// ## AND THE FALLBACK IS NOW THE **FLAT CANVAS**, WHICH IS THE PROTOTYPE'S OWN
///
/// **The old design's orbs are gone**, and what replaced them is not a
/// smaller version of them: it is the **canvas fill**, because
/// `eva/redesign.html:46` gives every screen **one** canvas. The superseded
/// prototype did the same thing: its screen root was `background: T.canvas`
/// and the layer above it — the orb container — declared no background of
/// its own.
///
/// **The plan asked for the legacy painter, and the reason it gave was the
/// legacy painter's own.** Task 1.5 Step 3 (`plan:799-801`): *"`low` (or
/// reduce-motion) → shader off, static `CustomPainter` aurora — today's
/// `neural_background.dart` behaviour, which is already tier-aware."* The
/// legacy painter is not rewritten to look like the shader; it is the thing
/// that was already there, and it is what a reduced-motion reader sees.
///
/// **The orbs were never part of this redesign**, so "the thing that was
/// already there" was the wrong thing to keep: the orbs were the *old*
/// design's per-screen orb groups, and the redesign replaced them with one
/// canvas for every screen. What survives of the legacy painter is the one
/// thing that was already the prototype's — the fill.
///
/// ## WHY THE TIER IS RESOLVED **HERE** AND NOT IN THE SCOPE
///
/// Because `LumenTiers.resolve` needs the viewport and the reader's motion
/// preference, and this widget is the first thing in the tree that has both.
/// `LumenTiers.resolve` is a pure function of its two arguments, so there is
/// no second source of truth to drift.
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
  /// Paints the ambient background.
  const LumenBackground({this.tier, super.key});

  /// Forces a [LumenShaderTier] instead of resolving one. `null` resolves.
  final LumenShaderTier? tier;

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
    // Reduced motion is the last word, and `LumenTiers.resolve` says so: it
    // returns `off` whatever the size and whatever the override say. The
    // brightness argument is not read here — it is the *theme's*, and the theme
    // is a separate question from the motion preference. It is carried so the
    // call reads as one decision.
    assert(
      brightness == Brightness.light || brightness == Brightness.dark,
      'the theme carries one of two brightnesses',
    );
    return LumenTiers.resolve(
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
      // ## THE FALLBACK IS THE **FLAT CANVAS**, AND IT IS THE PROTOTYPE'S OWN
      //
      // `eva/redesign.html:46` gives every screen **one** canvas. The
      // superseded prototype did the same thing: its screen root was
      // `background: T.canvas`, and the layer above it — the orb container —
      // declared no background of its own. **So the canvas fill IS the
      // design**, and the thing that used to stand in for it — the old
      // design's per-screen orb groups — was never part of this redesign.
      //
      // A `ColoredBox` and not a `CustomPaint`: the old painter did the same
      // fill with a `RepaintBoundary` and a `CustomPainter` around it, and a
      // widget that paints one rectangle does not need either.
      return ColoredBox(color: context.colors.canvas);
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
