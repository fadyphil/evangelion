import 'package:flutter/widgets.dart';

/// Whether the LUMEN shader paints, and which shapes it may use.
///
/// Resolved by [LumenTiers.resolve] from the viewport size and the reader's
/// animation preference. This is the *decision*; the painter it decides for is
/// `LumenBackground`, which resolves it and paints the shader or the flat
/// canvas.
///
/// ## THE TABLE
///
/// | tier | shader | shafts (shape 3) |
/// | --- | --- | --- |
/// | `full` | on | iff the viewport is at most [kShaftsPixelBudget] |
/// | `noShafts` | on | same gate — one rule, not one per tier |
/// | `off` | off | — |
///
/// ## WHY THERE IS NO `mid`
///
/// **There were three tiers, and two of them meant the same thing to the
/// shader.** The old design's `NeuralTier` was `low` / `mid` / `high`, and it
/// counted **orb layers** — the old background painted one aurora band and a
/// group of orbs, and a cheaper device got fewer of them. `mid` and `high`
/// differed in *how many orbs*, and the shader's decision read neither: both
/// mapped to "the shader is on, and the shafts are governed by the pixel
/// budget".
///
/// So the middle tier died with the orbs, and the tier that survives is the
/// one that was always about the shader: `off`, `noShafts` and `full`. The
/// screen's *cost* is now the pixel count and nothing else, which is what the
/// measured numbers say anyway.
///
/// ## WHY THE SHAFTS GATE IS ONE RULE
///
/// The cost scales with pixels, not with a tier name: a 600×3400 window is
/// 2.04 Mpx and a 1024×1366 tablet is 1.40 Mpx, so a per-tier ban would deny
/// the tablet's cheaper frame while allowing the phone's dearer one. The gate
/// reads the pixel count and nothing else.
enum LumenShaderTier {
  /// The shader stays off, and the flat canvas paints.
  ///
  /// This is the fallback the redesign's own screen root describes — the
  /// canvas fill at `eva/redesign.html:46`, with a transparent background
  /// layer above it. Resolving `off` changes no pixel anywhere except that the
  /// orbs are gone with the old design.
  off,

  /// The shader paints shapes 0–2 (top/bottom/sides); shape 3 (shafts) is
  /// disabled.
  ///
  /// The caller's shape choice is clamped to this set when this resolves: a
  /// stored `shafts` preference paints as `sides` (shape 2) rather than being
  /// forgotten, so toggling back under budget restores it. The clamping lives
  /// with the painter — `LumenScene`'s `_shapeIndex` — not here.
  noShafts,

  /// The shader paints all four shapes, shafts included.
  full,
}

/// The logical-pixel count above which shape 3 (shafts) is disabled.
///
/// Measured cost (`docs/superpowers/plans/2026-10-13-lumen-redesign.md`,
/// "What was verified"): **2.98 ns/px** for shapes 0–2, **5.04 ns/px** for
/// shafts — the 5-iteration loop in the `else` arm of `shaders/lumen.frag`.
/// At 2 Mpx the shafts frame costs ~10 ms for the background alone, against a
/// 16.6 ms 60fps budget; shapes 0–2 cost ~6 ms at the same size. The gate
/// bites where the plan's risk table says it does: a 1080p desktop is 2.07
/// Mpx (gated), a 1024×1366 tablet is 1.40 Mpx (not), a 393×852 phone is 0.33
/// Mpx (not).
///
/// ## LOGICAL PX, NOT DEVICE PX
///
/// `size.width * size.height` where `size` is the viewport's `MediaQuery`
/// size — the same units `u_res` carries. `LumenCanvas` documents that
/// `u_res` is the paint rect's *logical* size (`size`, never
/// `size * devicePixelRatio`), so a gate in device px would need a DPR lookup
/// this layer has no business doing, and would disagree with the number the
/// shader actually divides by.
///
/// ## WHERE THE SIZE COMES FROM
///
/// The `size` handed to [LumenTiers.resolve] — the viewport, not the paint
/// rect. The background fills the screen when mounted, so the two agree in
/// practice; deciding here keeps one decision point and keeps the painter
/// pure. A future caller mounting the shader smaller than the viewport gets
/// the conservative answer (shafts denied where they would have been
/// affordable), never the loose one.
const double kShaftsPixelBudget = 2000000;

/// The shortest viewport side, in logical px, below which the shader is off.
///
/// 360dp is the narrowest Android phone width still supported.
///
/// ## AND THE RULE'S **REASON** CHANGED WITH THE ORBS
///
/// The old design's `low` tier existed because a viewport that short could
/// not show the orbs whole — the prototype's home group is authored at
/// `y: 640` (`ds.tsx:80`), so a 360dp-tall viewport would show none of them.
/// **That is a rule about ORBS and not about the shader**, and the orbs are
/// gone.
///
/// **The rule survives, and this is the honest account of why.** The shader's
/// own cost at that size is not the binding constraint — a 320×568 window is
/// 0.18 Mpx, about 0.55 ms a frame at the measured rate — so the rule does
/// **not** stand on a cost argument, and nothing here claims it does. It
/// stands on the redesign's own rule, read the other way: `eva/redesign.html:46`
/// gives every screen **one** canvas, and a 360dp-wide screen is a screen.
///
/// **So this is an OPEN QUESTION, not a settled one, and it is recorded as
/// such rather than dressed up.** The tree's behaviour is unchanged: a
/// viewport under [kNarrowViewport] gets the flat canvas, exactly as it does
/// today. What changed is that the *reason* it did is gone, and the rule
/// should be re-argued by whoever owns the ambient — the redesign's own
/// "one canvas for every screen" argues for the aurora everywhere, and the
/// cost measurement argues that it is affordable.
const double kNarrowViewport = 360;

/// Resolves a [LumenShaderTier] from what is knowable synchronously.
///
/// ## WHY A PURE FUNCTION AND NOT A DEVICE-TIER SERVICE
///
/// The prototype's low/mid/high came from a "platform frame budget" — a
/// *measured* frame time. Flutter exposes no synchronous frame-timing API, so a
/// service claiming to know would either be lying or reading a stale budget,
/// and a background that repaints itself when a measurement lands is precisely
/// the per-frame churn §13 exists to remove. The two inputs that *are*
/// synchronous — viewport size and the user's animation preference — are the
/// real ones. A later phase that measures frames passes its verdict in as
/// [resolve]'s `override`; nothing here has to change.
abstract final class LumenTiers {
  /// Resolves the tier for a viewport of [size].
  ///
  /// [override] replaces the *size* decision and nothing else. That is the
  /// injection seam: the goldens and the tier tests pass a tier rather than
  /// arranging a viewport that happens to resolve to the one under test, so a
  /// test never has to reason about device geometry to prove something about
  /// [LumenShaderTier.off].
  ///
  /// ## REDUCED MOTION IS NOT A TIE-BREAK, IT IS THE LAST WORD
  ///
  /// `animationsEnabled` is `!MediaQuery.disableAnimationsOf(context)`. A reader
  /// who has told the platform to reduce motion gets [LumenShaderTier.off]
  /// whatever the size says **and whatever [override] says** — including
  /// [LumenShaderTier.full]. An ambient background that drifts forever is the
  /// loudest possible violation of that request, and there is no control
  /// anywhere in the UI the reader could find to stop it, so the only safe
  /// place to enforce it is here, at the layer that owns every animated layer
  /// at once. AGENT_CONTEXT §14's "every animation checks
  /// `MediaQuery.disableAnimationsOf(context)`", applied once instead of eight
  /// times.
  ///
  /// The asymmetry is deliberate and is why `override` is documented as a *cost*
  /// override: the cost budget belongs to the application, the accessibility
  /// budget belongs to the reader.
  static LumenShaderTier resolve({
    required Size size,
    required bool animationsEnabled,
    LumenShaderTier? override,
  }) {
    if (!animationsEnabled) return LumenShaderTier.off;
    return override ?? _forSize(size);
  }

  /// The tier a viewport of [size] earns on its own.
  ///
  /// The shaft gate reads the pixel count and nothing else, and the narrow
  /// rule is [kNarrowViewport]'s.
  static LumenShaderTier _forSize(Size size) {
    if (size.shortestSide < kNarrowViewport) return LumenShaderTier.off;
    return size.width * size.height <= kShaftsPixelBudget
        ? LumenShaderTier.full
        : LumenShaderTier.noShafts;
  }
}
