import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The eight orb groups of `ORB_CONFIGS` — one per prototype screen.
///
/// ## WHY EIGHT GROUPS AND SEVEN VARIANTS
///
/// `NeuralVariant` has seven values because the Profile screen was cut
/// ([AGENT_CONTEXT] §2, decision 1). `ORB_CONFIGS` still has eight groups. The
/// group is therefore named by the *prototype's* screen, `profile` included, so
/// this table stays a one-to-one transcription and nothing has to be re-derived
/// from an index later. [OrbGroup.profile] is dead weight today and is the only
/// thing that keeps `settings` from landing on the wrong row — see
/// `orbGroupFor` in `neural_background.dart`.
///
/// [AGENT_CONTEXT]: https://example.invalid/agent-context
enum OrbGroup {
  /// `ORB_CONFIGS[0]` — the Login screen. `ds.tsx:69-72`.
  login,

  /// `ORB_CONFIGS[1]` — Home. `ds.tsx:73-77`. The only four-orb group.
  home,

  /// `ORB_CONFIGS[2]` — the English reading screen. `ds.tsx:78-81`.
  readingEn,

  /// `ORB_CONFIGS[3]` — the Arabic reading screen. `ds.tsx:82-85`.
  readingAr,

  /// `ORB_CONFIGS[4]` — Quiz. `ds.tsx:86-90`.
  quiz,

  /// `ORB_CONFIGS[5]` — Result. `ds.tsx:91-95`. The only warm group.
  result,

  /// `ORB_CONFIGS[6]` — Profile. `ds.tsx:96-99`. **Cut**; kept for index
  /// alignment. See the enum doc.
  profile,

  /// `ORB_CONFIGS[7]` — Settings. `ds.tsx:100-103`.
  settings,
}

/// Which of the three float keyframe sets an orb runs.
///
/// `orb-float-a` / `-b` / `-c`, `eva/src/index.css:36-56`. Three *shapes* rather
/// than three *durations*, which is how they survive the collapse to one shared
/// controller (§13.2, mitigation 2) — see [OrbSpec.floatSeconds].
enum OrbFloatPath {
  /// `index.css:37-42` — `30% => (28,-22) 1.07` · `60% => (-18,30) 0.94`.
  a,

  /// `index.css:43-48` — `40% => (-30,18) 1.05` · `75% => (22,-28) 0.92`.
  b,

  /// `index.css:49-54` — `50% => (12,36) 1.1`. The strongest vertical mover.
  c,
}

/// The direction of an orb's hue cycle.
///
/// `hue-cycle` is `hue-rotate(0deg) → hue-rotate(360deg)`; `hue-cycle-rev` is
/// the mirror (`index.css:61-67`). Preserved as a **direction sign**, not as a
/// second animation, because one shared hue controller reversed for half the
/// orbs is a sign on the turns fed to `hueRotateFilter`.
enum OrbHueDirection {
  /// `hue-cycle`.
  forward,

  /// `hue-cycle-rev`.
  reverse,
}

/// One orb, transcribed from one `ORB_CONFIGS` entry.
///
/// ## WHICH FIELDS THE PAINTER READS, AND WHY THE TABLE KEEPS THE REST
///
/// Read: [color] (with a hue filter over it), [size], [x], [y], [floatPath],
/// [hueDirection], [hueDelaySeconds], [parallax].
///
/// Recorded but not driven: [floatSeconds]. §13.2 mandates **three** controllers
/// app-wide and this phase ships exactly three, so a per-orb float *period* has
/// nothing to run on. `floatDur` is 14–28s in the prototype and
/// `EvaMotion.orbFloatFor` can still spread that range, but only across
/// controllers that exist. It is kept here so the transcription is complete and
/// auditable, and so restoring it is a data change rather than an archaeology
/// exercise — see the D3 note in `neural_motion.dart` for what replaced it
/// (per-orb phase, `i / orbCount`, which is §13.2's own prescription).
///
/// [hueSeconds] is *not* in that category: it is the denominator that turns the
/// prototype's `animation-delay` back into a phase fraction, which is what
/// preserves `hueDelay` exactly.
@immutable
class OrbSpec {
  /// Creates one orb. Every field is required rather than defaulted — a default
  /// here would be a value invented outside `ORB_CONFIGS`.
  const OrbSpec({
    required this.color,
    required this.size,
    required this.x,
    required this.y,
    required this.floatPath,
    required this.floatSeconds,
    required this.hueSeconds,
    required this.hueDelaySeconds,
    required this.hueDirection,
    required this.parallax,
  });

  /// The orb's declared fill, `rgba(…)`-free because the prototype's orbs are
  /// opaque and the opacity is applied to the whole orb by
  /// [EvaColors.orbOpacity] (`ds.tsx:160`: `const orbOpacity = isDark ? 0.55 :
  /// 0.16`).
  final Color color;

  /// Diameter in logical px. The prototype's orbs are 200–500px.
  final double size;

  /// Absolute left offset from the background's top-left, in logical px.
  ///
  /// Absolute rather than proportional, faithfully: `ds.tsx:196` positions each
  /// orb with `left`/`top` in px against a `position: absolute` container, so
  /// an orb at `y: 640` is off the bottom of a 600px-tall window and on a
  /// 844px phone, which is where the prototype puts it.
  final double x;

  /// Absolute top offset from the background's top-left, in logical px.
  final double y;

  /// Which float keyframe set drives this orb's translation and scale.
  final OrbFloatPath floatPath;

  /// The prototype's `floatDur`, in seconds. **Recorded, not driven** — see the
  /// class doc and §13.2.
  final double floatSeconds;

  /// The prototype's `hueDur`, in seconds. Drives [hueDelayPhase]'s denominator.
  final double hueSeconds;

  /// The prototype's `hueDelay`, in seconds. CSS animation delays are negative
  /// here (`0`, `-3`, `-5`, …), which on an infinite positive-duration animation
  /// is a *phase advance*, so it is preserved as one.
  final double hueDelaySeconds;

  /// `hue-cycle` or `hue-cycle-rev`.
  final OrbHueDirection hueDirection;

  /// Mouse-response amplitude, 3–14. `ds.tsx:196` scales the pointer offset by
  /// `orb.parallax / 14`; the 14 is [kMaxParallax] and the division is
  /// [parallaxScale].
  final double parallax;

  /// A parallax-free orb, for the arithmetic that has to survive one.
  ///
  /// `ORB_CONFIGS` declares no `parallax: 0`, so this constructor exists only
  /// so `parallaxScale`'s zero case is reachable at all — a getter whose zero
  /// input is unreachable cannot have its zero case asserted, which is how a
  /// division by [kMaxParallax] survives a future orb opting out of parallax.
  const OrbSpec.flat()
    : color = const Color(0x00000000),
      size = 0,
      x = 0,
      y = 0,
      floatPath = OrbFloatPath.a,
      floatSeconds = 0,
      hueSeconds = 1,
      hueDelaySeconds = 0,
      hueDirection = OrbHueDirection.forward,
      parallax = 0;

  /// This orb's share of the pointer offset, `parallax / kMaxParallax`.
  ///
  /// The prototype's own formula, kept as its own getter so "the division by 14"
  /// exists once. The strongest orb in `ORB_CONFIGS` — Login's first, `parallax:
  /// 14` — therefore tracks the pointer exactly, and Login's third moves 43% as
  /// far.
  double get parallaxScale => parallax / kMaxParallax;
}

/// The largest `parallax` any orb declares — Login's first, `ds.tsx:69`.
///
/// The prototype divides by the literal `14` (`ds.tsx:203`), so this constant is
/// that literal, named.
const double kMaxParallax = 14;

/// The pointer's horizontal reach, `ds.tsx:129` — `(x / width - 0.5) * 32`.
const double kPointerSpanX = 32;

/// The pointer's vertical reach, `ds.tsx:130` — `(y / height - 0.5) * 24`.
const double kPointerSpanY = 24;

/// Where each orb's radial gradient starts, `ds.tsx:200`.
///
/// `radial-gradient(circle at 38% 38%, color, transparent 68%)`. CSS measures
/// the centre from the top-left; Flutter's [Alignment] measures `x` from the
/// left and `y` from the **bottom**, so 38% from the top is `0.38 * 2 - 1 =
/// -0.24`. Both components are therefore negative.
const Alignment kOrbGradientCenter = Alignment(-0.24, -0.24);

/// The centre as a fraction of the orb's own box, `at 38% 38%`.
const double kOrbGradientCentre = 0.38;

/// The outer stop, `transparent 68%`. A fraction of the **farthest-corner ray**,
/// which is what a CSS radial-gradient stop is — see [kOrbGradientRadius].
const double kOrbGradientStop = 0.68;

/// The orb gradient's outer stop, expressed in Flutter's units.
///
/// ## THE TWO RADII ARE NOT THE SAME NUMBER, AND GETTING IT WRONG IS VISIBLE
///
/// `ds.tsx:200` is `radial-gradient(circle at 38% 38%, color, transparent 68%)`.
/// In CSS a radial-gradient's colour stops are a fraction of the gradient **ray**,
/// and with the default `farthest-corner` ending shape that ray runs from the
/// `at 38% 38%` centre to the `(100%, 100%)` corner — `0.62 * sqrt(2) = 0.877`
/// orb-widths for a square orb. So the transparent stop sits at
/// `0.68 * 0.877 = 0.596` orb-widths from the centre.
///
/// Flutter's `RadialGradient.radius` is a fraction of the **shortest side**
/// instead. Passing CSS's `0.68` straight through therefore stops the fade at
/// `0.68` orb-widths, which is *beyond* the ray — the gradient never reaches
/// transparent inside the orb's box, every one of the four corners of the orb
/// rectangle ends up tinted, and the orb renders as a visible hard-edged
/// rectangle instead of a soft blob. That is not a subtle mistake; it is the
/// difference between the identity layer looking like the design and looking
/// like a bug.
///
/// So the constant is the converted value, and the two numbers it comes from are
/// published beside it so the arithmetic can be checked rather than trusted.
const double kOrbGradientRadius =
    kOrbGradientStop * (1 - kOrbGradientCentre) * 1.4142135623730951; // sqrt(2)

/// Every `ORB_CONFIGS` group, transcribed from `eva/src/components/ds.tsx:68-112`.
///
/// Unmodifiable. `dart format` will not stop a caller reassigning a `const`
/// map's variable, and this table is read once per frame by the painter; a
/// mutation would change the background of whichever screen happened to be on
/// top. Const-in-variables is the only thing this file has instead of a getter
/// that rebuilds an unmodifiable map per call.
const Map<OrbGroup, List<OrbSpec>> orbGroups = <OrbGroup, List<OrbSpec>>{
  // 0 Login
  OrbGroup.login: <OrbSpec>[
    OrbSpec(
      color: Color(0xFF6C3FE8),
      size: 420,
      x: -100,
      y: -80,
      floatPath: OrbFloatPath.a,
      floatSeconds: 14,
      hueSeconds: 8,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 14,
    ),
    OrbSpec(
      color: Color(0xFF3B5BDB),
      size: 360,
      x: 180,
      y: 260,
      floatPath: OrbFloatPath.b,
      floatSeconds: 18,
      hueSeconds: 11,
      hueDelaySeconds: -3,
      hueDirection: OrbHueDirection.reverse,
      parallax: 9,
    ),
    OrbSpec(
      color: Color(0xFFC026D3),
      size: 280,
      x: 60,
      y: 540,
      floatPath: OrbFloatPath.c,
      floatSeconds: 22,
      hueSeconds: 9,
      hueDelaySeconds: -5,
      hueDirection: OrbHueDirection.forward,
      parallax: 6,
    ),
  ],
  // 1 Home
  OrbGroup.home: <OrbSpec>[
    OrbSpec(
      color: Color(0xFF3B5BDB),
      size: 500,
      x: -160,
      y: -120,
      floatPath: OrbFloatPath.a,
      floatSeconds: 16,
      hueSeconds: 10,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 12,
    ),
    OrbSpec(
      color: Color(0xFF14B8A6),
      size: 320,
      x: 200,
      y: 200,
      floatPath: OrbFloatPath.b,
      floatSeconds: 20,
      hueSeconds: 7,
      hueDelaySeconds: -2,
      hueDirection: OrbHueDirection.reverse,
      parallax: 8,
    ),
    OrbSpec(
      color: Color(0xFF6C3FE8),
      size: 260,
      x: -70,
      y: 520,
      floatPath: OrbFloatPath.c,
      floatSeconds: 25,
      hueSeconds: 12,
      hueDelaySeconds: -4,
      hueDirection: OrbHueDirection.forward,
      parallax: 5,
    ),
    OrbSpec(
      color: Color(0xFFF59E0B),
      size: 200,
      x: 250,
      y: 640,
      floatPath: OrbFloatPath.a,
      floatSeconds: 19,
      hueSeconds: 9,
      hueDelaySeconds: -6,
      hueDirection: OrbHueDirection.reverse,
      parallax: 3,
    ),
  ],
  // 2 Reading EN
  OrbGroup.readingEn: <OrbSpec>[
    OrbSpec(
      color: Color(0xFF3B5BDB),
      size: 380,
      x: -110,
      y: 40,
      floatPath: OrbFloatPath.a,
      floatSeconds: 20,
      hueSeconds: 14,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 10,
    ),
    OrbSpec(
      color: Color(0xFF14B8A6),
      size: 300,
      x: 160,
      y: 380,
      floatPath: OrbFloatPath.b,
      floatSeconds: 26,
      hueSeconds: 10,
      hueDelaySeconds: -4,
      hueDirection: OrbHueDirection.reverse,
      parallax: 6,
    ),
  ],
  // 3 Reading AR
  OrbGroup.readingAr: <OrbSpec>[
    OrbSpec(
      color: Color(0xFF6C3FE8),
      size: 420,
      x: 40,
      y: -90,
      floatPath: OrbFloatPath.b,
      floatSeconds: 18,
      hueSeconds: 9,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 11,
    ),
    OrbSpec(
      color: Color(0xFF06B6D4),
      size: 300,
      x: -80,
      y: 360,
      floatPath: OrbFloatPath.c,
      floatSeconds: 22,
      hueSeconds: 13,
      hueDelaySeconds: -5,
      hueDirection: OrbHueDirection.reverse,
      parallax: 7,
    ),
  ],
  // 4 Quiz
  OrbGroup.quiz: <OrbSpec>[
    OrbSpec(
      color: Color(0xFFC026D3),
      size: 380,
      x: 110,
      y: -130,
      floatPath: OrbFloatPath.a,
      floatSeconds: 15,
      hueSeconds: 7,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 13,
    ),
    OrbSpec(
      color: Color(0xFF3B5BDB),
      size: 320,
      x: -110,
      y: 280,
      floatPath: OrbFloatPath.b,
      floatSeconds: 20,
      hueSeconds: 10,
      hueDelaySeconds: -2,
      hueDirection: OrbHueDirection.reverse,
      parallax: 9,
    ),
    OrbSpec(
      color: Color(0xFF14B8A6),
      size: 220,
      x: 180,
      y: 580,
      floatPath: OrbFloatPath.c,
      floatSeconds: 24,
      hueSeconds: 13,
      hueDelaySeconds: -5,
      hueDirection: OrbHueDirection.forward,
      parallax: 5,
    ),
  ],
  // 5 Result
  OrbGroup.result: <OrbSpec>[
    OrbSpec(
      color: Color(0xFFF59E0B),
      size: 380,
      x: -70,
      y: -90,
      floatPath: OrbFloatPath.a,
      floatSeconds: 17,
      hueSeconds: 8,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 12,
    ),
    OrbSpec(
      color: Color(0xFFF43F5E),
      size: 300,
      x: 150,
      y: 240,
      floatPath: OrbFloatPath.b,
      floatSeconds: 21,
      hueSeconds: 11,
      hueDelaySeconds: -3,
      hueDirection: OrbHueDirection.reverse,
      parallax: 8,
    ),
    OrbSpec(
      color: Color(0xFF6C3FE8),
      size: 250,
      x: -50,
      y: 560,
      floatPath: OrbFloatPath.c,
      floatSeconds: 28,
      hueSeconds: 9,
      hueDelaySeconds: -6,
      hueDirection: OrbHueDirection.forward,
      parallax: 4,
    ),
  ],
  // 6 Profile — CUT (AGENT_CONTEXT §2, decision 1). Kept for index alignment.
  OrbGroup.profile: <OrbSpec>[
    OrbSpec(
      color: Color(0xFF14B8A6),
      size: 440,
      x: -110,
      y: -80,
      floatPath: OrbFloatPath.a,
      floatSeconds: 19,
      hueSeconds: 11,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.reverse,
      parallax: 10,
    ),
    OrbSpec(
      color: Color(0xFF3B5BDB),
      size: 280,
      x: 190,
      y: 380,
      floatPath: OrbFloatPath.b,
      floatSeconds: 23,
      hueSeconds: 8,
      hueDelaySeconds: -4,
      hueDirection: OrbHueDirection.forward,
      parallax: 6,
    ),
  ],
  // 7 Settings
  OrbGroup.settings: <OrbSpec>[
    OrbSpec(
      color: Color(0xFF6C3FE8),
      size: 400,
      x: 70,
      y: -110,
      floatPath: OrbFloatPath.b,
      floatSeconds: 22,
      hueSeconds: 9,
      hueDelaySeconds: 0,
      hueDirection: OrbHueDirection.forward,
      parallax: 11,
    ),
    OrbSpec(
      color: Color(0xFF06B6D4),
      size: 260,
      x: -70,
      y: 440,
      floatPath: OrbFloatPath.a,
      floatSeconds: 18,
      hueSeconds: 12,
      hueDelaySeconds: -3,
      hueDirection: OrbHueDirection.reverse,
      parallax: 6,
    ),
  ],
};

/// The four keyframes of `orb-float-a`, as `(phase, dx, dy, scale)`.
///
/// `index.css:37-42`. Each entry is one line of the `@keyframes` block, in
/// order; [orbFloatOffset] and [orbFloatScale] interpolate between them.
const List<List<double>> _floatA = <List<double>>[
  <double>[0, 0, 0, 1],
  <double>[0.30, 28, -22, 1.07],
  <double>[0.60, -18, 30, 0.94],
  <double>[1, 0, 0, 1],
];

/// The four keyframes of `orb-float-b`. `index.css:43-48`.
const List<List<double>> _floatB = <List<double>>[
  <double>[0, 0, 0, 1],
  <double>[0.40, -30, 18, 1.05],
  <double>[0.75, 22, -28, 0.92],
  <double>[1, 0, 0, 1],
];

/// The three keyframes of `orb-float-c`. `index.css:49-54`.
const List<List<double>> _floatC = <List<double>>[
  <double>[0, 0, 0, 1],
  <double>[0.50, 12, 36, 1.1],
  <double>[1, 0, 0, 1],
];

List<List<double>> _keyframesFor(OrbFloatPath path) => switch (path) {
  OrbFloatPath.a => _floatA,
  OrbFloatPath.b => _floatB,
  OrbFloatPath.c => _floatC,
};

/// The `component`-th of each keyframe, interpolated at [phase].
///
/// `component` is `1` for dx, `2` for dy, `3` for scale. The phase is taken
/// modulo 1 first, which is what makes the loop close: the prototype's
/// keyframes start and end on the same transform, so `phase 1.0` and
/// `phase 0.0` must agree and a shared clock that runs past 1.0 must not send
/// the interpolation off the end of the list.
double _floatComponent(OrbFloatPath path, double phase, int component) {
  final List<List<double>> keys = _keyframesFor(path);
  final double t = phase - phase.floorToDouble();
  for (int i = 0; i < keys.length - 1; i++) {
    final List<double> from = keys[i];
    final List<double> to = keys[i + 1];
    if (t <= to[0] || i == keys.length - 2) {
      final double span = to[0] - from[0];
      final double local = span == 0 ? 0.0 : (t - from[0]) / span;
      return from[component] + (to[component] - from[component]) * local;
    }
  }
  // Unreachable: the loop above always returns on its last iteration. Kept as a
  // value rather than a `throw` so a future keyframe set cannot take the
  // background down at paint time.
  return keys.first[component];
}

/// The translation of a [path] at [phase], in logical px.
///
/// CSS `ease-in-out` per orb float is a *timing* curve on the shared clock, not
/// a different shape: §13.2 collapses the per-orb clocks, so what survives is
/// the path's shape interpolated **linearly** and the whole cycle shaped by the
/// shared controller's own curve. That is a deliberate, documented difference
/// from the prototype — see the D3 note in `neural_motion.dart`.
Offset orbFloatOffset(OrbFloatPath path, double phase) =>
    Offset(_floatComponent(path, phase, 1), _floatComponent(path, phase, 2));

/// The uniform scale of a [path] at [phase]. The prototype's
/// `transform: translate(…) scale(…)` is applied about the orb's centre, which
/// is what `Canvas.scale` about the centre does.
double orbFloatScale(OrbFloatPath path, double phase) =>
    _floatComponent(path, phase, 3);

/// `+1` for [OrbHueDirection.forward], `-1` for
/// [OrbHueDirection.reverse].
int hueDirectionSign(OrbHueDirection direction) => switch (direction) {
  OrbHueDirection.forward => 1,
  OrbHueDirection.reverse => -1,
};

/// The prototype's `animation-delay`, expressed as a fraction of one hue cycle.
///
/// A negative `animation-delay` on an infinite animation is exactly a phase
/// advance, so `-3s` on an `8s` cycle is `+3/8` of a turn — not a delay at all.
/// Preserving `hueDelay` means preserving *this*, because a delay applied as a
/// delay would need per-orb timers, which is what §13.2 forbids.
double hueDelayPhase(double hueDelaySeconds, double hueSeconds) =>
    -hueDelaySeconds / hueSeconds;

/// The hue cycle phase in `[0, 1)` for a shared [clock] at [phaseOffset].
///
/// The modulo is what lets one `0→1` controller drive orbs that all start
/// somewhere else on the wheel, and what makes the loop seam-free.
double huePhaseFor({required double clock, required double phaseOffset}) =>
    (clock + phaseOffset) % 1.0;

/// Where a pointer at [local] maps to, inside a [size] background.
///
/// `ds.tsx:128-133`: `targetRef.current = { x: (clientX / innerWidth - 0.5) *
/// 32, y: (clientY / innerHeight - 0.5) * 24 }`. Preserved verbatim, including
/// the 32/24 asymmetry — the prototype's orbs drift further horizontally than
/// vertically, and rounding that to a square would be a change nobody asked for.
///
/// The returned value is already the *scaled* pointer offset; each orb applies
/// its own [OrbSpec.parallaxScale] to it.
Offset pointerOffsetFor({required Size size, required Offset local}) => Offset(
  (local.dx / size.width - 0.5) * kPointerSpanX,
  (local.dy / size.height - 0.5) * kPointerSpanY,
);

/// The aurora band's gradient stops, per brightness.
///
/// Two layers, transcribed from `ds.tsx:170-190`.
///
/// ## WHY THESE LIVE HERE AND NOT IN `EvaColors`
///
/// `03-design-system.md` §5.1 publishes fourteen colour tokens per brightness
/// and not one of them is an aurora stop; the prototype's bands are `rgba()`
/// triples over five of the seven orb accents at alphas no token covers. Growing
/// `EvaColors` to hold them would mean a Phase-1 token file acquiring fields the
/// spec does not describe — the exact thing Phase 1 was careful not to do. These
/// are effect-layer constants for the one widget that paints them, at the
/// prototype's own alphas, not invented ones.
abstract final class NeuralAurora {
  /// The two vertical gradients of the dark palette, top to bottom.
  ///
  /// `ds.tsx:171-181`. Layer 1 stops at 0/20/40/65/100%, layer 2 at
  /// 0/50/100%.
  static const List<List<Color>> dark = <List<Color>>[
    <Color>[
      Color.fromARGB(0x38, 0x6C, 0x3F, 0xE8), // rgba(108,63,232,0.22) 0%
      Color.fromARGB(0x24, 0x06, 0xB6, 0xD4), // rgba(6,182,212,0.14) 20%
      Color.fromARGB(0x1A, 0x14, 0xB8, 0xA6), // rgba(20,184,166,0.10) 40%
      Color.fromARGB(0x1F, 0xF3, 0x43, 0x5E), // rgba(243,67,94,0.12) 65%
      Color.fromARGB(0x33, 0x3B, 0x5B, 0xDB), // rgba(59,91,219,0.20) 100%
    ],
    <Color>[
      Color.fromARGB(0x1A, 0xC4, 0x26, 0xD3), // rgba(196,38,211,0.10) 0%
      Color.fromARGB(0x15, 0x3B, 0x5B, 0xDB), // rgba(59,91,219,0.08) 50%
      Color.fromARGB(0x1F, 0x14, 0xB8, 0xA6), // rgba(20,184,166,0.12) 100%
    ],
  ];

  /// The same two layers in the light palette. `ds.tsx:182-190`.
  static const List<List<Color>> light = <List<Color>>[
    <Color>[
      Color.fromARGB(0x1A, 0x6C, 0x3F, 0xE8), // rgba(108,63,232,0.10) 0%
      Color.fromARGB(0x0F, 0x06, 0xB6, 0xD4), // rgba(6,182,212,0.06) 25%
      Color.fromARGB(0x0D, 0x14, 0xB8, 0xA6), // rgba(20,184,166,0.05) 50%
      Color.fromARGB(0x0F, 0xF3, 0x43, 0x5E), // rgba(243,67,94,0.06) 75%
      Color.fromARGB(0x1A, 0x3B, 0x5B, 0xDB), // rgba(59,91,219,0.10) 100%
    ],
    <Color>[
      Color.fromARGB(0x0A, 0xC4, 0x26, 0xD3), // rgba(196,38,211,0.04) 0%
      Color.fromARGB(0x0A, 0x3B, 0x5B, 0xDB), // rgba(59,91,219,0.04) 50%
      Color.fromARGB(0x0D, 0x14, 0xB8, 0xA6), // rgba(20,184,166,0.05) 100%
    ],
  ];

  /// Layer 1's stop positions in dark: 0 / 20% / 40% / 65% / 100%.
  ///
  /// Its own constant because the light band is stretched differently — 0 / 25%
  /// / 50% / 75% / 100%, [stopsLight] — and one shared list would silently
  /// flatten that difference. Layer 2 is 0 / 50 / 100% in both palettes, which
  /// is why it needs no constant of its own.
  static const List<double> stopsDark = <double>[0, 0.20, 0.40, 0.65, 1];

  /// Layer 1's stop positions in light: 0 / 25% / 50% / 75% / 100%.
  static const List<double> stopsLight = <double>[0, 0.25, 0.50, 0.75, 1];

  /// How much brighter the band gets at the midpoint of its cycle.
  ///
  /// `index.css:80` — `opacity: calc(var(--aurora-opacity) * 1.6)`. Multiplied
  /// into the stops' own alphas, because CSS `opacity` on the element multiplies
  /// the gradients it contains.
  static const double peakPulse = 1.6;
}
