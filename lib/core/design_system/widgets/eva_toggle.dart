import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The Settings screen's on/off switch.
///
/// ## THE ROLE, AND WHERE ITS NUMBERS COME FROM NOW
///
/// The React prototype declared it as a **local** component — `SettingsScreen.tsx:14-26`
/// defines `Toggle` inside the screen file rather than in `ds.tsx` — so there was no
/// `ds.tsx` line to cite and every number was quoted from the screen. The redesigned
/// reference publishes the same control globally, as `.tgl`, and the whole geometry
/// is four CSS rules:
///
/// ```css
/// .tgl i{width:38px;height:20px;border-radius:99px;background:rgba(255,255,255,.12);position:relative;transition:.25s}          /* :425 */
/// .tgl i::before{…top:2px;left:2px;width:16px;height:16px;border-radius:50%;background:var(--ink-2);transition:.25s var(--e-spring)} /* :426 */
/// .tgl input:checked+i{background:rgba(232,176,75,.3)}                                                                                      /* :427 */
/// .tgl input:checked+i::before{left:20px;background:var(--gold);box-shadow:0 0 10px rgba(232,176,75,.8)}                          /* :428 */
/// ```
///
/// `rgba(232,176,75,…)` is `--gold` (`redesign.html:14`), which this design system
/// spells `ember` — see [EvaColors]'s own table for why the prototype's golds were
/// **not** adopted verbatim in Phase 2, so `ember` at these alphas is the
/// transcription of the prototype's gold and not a second accent. `redesign.html:94`
/// re-points the **off** track at `rgba(20,22,30,.15)` in light mode, which `ink` at
/// the same 12% already is, modulo the three points.
///
/// ## 38×20 IS THE **PAINTED TRACK**. THE TAP TARGET IS STILL 44×24.
///
/// This is the load-bearing structural fact of the restyle, and it is why the widget
/// is two boxes rather than one. `redesign.html:425` draws a 38×20 track, which is
/// **below** the 44px platform tap-target minimum that the previous 44×24 satisfied —
/// and a switch a reader has to aim at is an accessibility regression, not a restyle.
/// So the visible track is the prototype's 38×20 and the tappable box is unchanged
/// at [tapTarget] 44×24: the [EvaInk]'s `InkWell` wraps the outer [SizedBox], so the
/// hit area is exactly what it was before — 3px of slack on each side and 2px above
/// and below the paint. Measured rather than assumed: the §14 row for tap targets is
/// qualitative (`09-quality-gates.md` §14), the 44 comes from
/// `iOSTapTargetGuideline`, and the only numeric claim this widget makes is
/// `controls_test.dart`'s, which now asserts **both** boxes.
///
/// **What this costs, stated rather than discovered later:** the on-state glow
/// (`0 0 10px`) and the off-state track are painted inside a box 2px shorter than
/// the box they sit in, so the switch's silhouette and its target are no longer the
/// same rectangle. That is the prototype's own shape — `.tgl i` is 38×20 inside a
/// `<label>` that adds its own padding — and it is the correct trade: a control that
/// looks 38 wide and answers to 44 is correct, and a control that answers to 38 is
/// not.
///
/// ## THE TARGET IS A **STADIUM**, AND ITS FOUR CORNERS ARE NOT TAPPABLE
///
/// [EvaInk]'s radius is `tapTarget.height / 2` because a switch is a stadium, and
/// the `Material` that carries that radius clips the `InkWell`'s hit test to it.
/// Measured over a 24×44 grid rather than assumed: inside the 44×24 box the hit
/// region follows the stadium's arcs, so the bounding box's four corners —
/// `(1, 1)`, `(42, 1)`, `(1, 22)`, `(42, 22)` — reach nothing.
///
/// **This predates the restyle and is not a regression:** the track *was* 44×24 with
/// the same radius, so the same four corners were already dead. It is written down
/// because "38×20 inside 44×24" reads as "the whole box is tappable" and it is not,
/// and because the shape of the target is now the one thing about this widget that
/// no test could see before. `controls_test.dart` measures the grid's four straight
/// edges — the six columns and four rows the restyle gave up — and pins one corner
/// so the shape cannot be narrowed again silently.
///
/// ## COLOUR-ONLY STATE
///
/// The redesign's off→on difference is a colour plus a `left` plus a shadow, and
/// three things carry the state here instead of the colour alone:
///
/// 1. **the knob moves** — `Alignment.centerLeft` vs `Alignment.centerRight`,
///    which is `redesign.html:426`'s `left:2px` against `:428`'s `left:20px`, and
///    which survives greyscale;
/// 2. `Semantics(toggled: value)`, so a screen reader says on or off;
/// 3. the knob's glow, which is on only when on (`redesign.html:428`).
///
/// ## THE KNOB IS WHITE IN BOTH PALETTES, AND THAT IS A **RECORDED DIVERGENCE**
///
/// `redesign.html:426` writes `background: var(--ink-2)` and `:428` writes
/// `background: var(--gold)` — so in the redesigned reference the knob is a dim
/// neutral when off and the accent when on, and it is never white. This widget
/// keeps the white knob it shipped with, and the divergence is deliberate rather
/// than inherited:
///
/// * a white knob is the **handle** of the control and reads as one on both
///   palettes, where `ink2` on the light palette's `ink`-at-12% track is a grey
///   circle on a grey track;
/// * it is what makes the knob's position legible at the small size the redesign
///   shrank it to (18 → 16), which is the one place the extra contrast earns its
///   keep;
/// * it keeps [EvaToggleKnob]'s single colour literal, which is the whole budget
///   `no_colour_literals_test.dart` grants this file.
///
/// The one-line reversal, if the reviewer wants the prototype's own colours, is at the
/// `color:` above: read `ink2` when off and `ember` when on.
///
/// [labels] is **required** for [FontSizeStepperLabels]'s reason: a default would let
/// the next design-system widget reintroduce the same English, and
/// [FontSizeStepper]'s doc says so in those words — "a default would let the next
/// design-system widget reintroduce the same English, and §14's first row — a control
/// with no name in the reader's own language — is a failure a widget-level default
/// makes invisible."
@immutable
class EvaToggleLabels {
  /// The switch's two position names.
  const EvaToggleLabels({required this.on, required this.off});

  /// The accessible name while the switch is on.
  final String on;

  /// The accessible name while the switch is off.
  final String off;
}

class EvaToggle extends StatelessWidget {
  /// A switch whose current position is [value].
  const EvaToggle({
    required this.value,
    required this.onChanged,
    required this.labels,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Reports the new position.
  final ValueChanged<bool> onChanged;

  /// The switch's two position names, for its semantics node. See [EvaToggleLabels].
  final EvaToggleLabels labels;

  /// The **painted** track. `redesign.html:425` — `width: 38px, height: 20px`.
  static const Size trackSize = Size(38, 20);

  /// The tappable box, which the painted track sits inside.
  ///
  /// 44 wide is `iOSTapTargetGuideline`'s minimum and the number the previous track
  /// used; 24 tall is this widget's own height, unchanged, and the reason is in the
  /// class doc: shrinking the *paint* is a restyle, shrinking the *target* is a
  /// regression.
  static const Size tapTarget = Size(44, 24);

  /// Knob diameter. `redesign.html:426` — `width: 16px, height: 16px`.
  static const double knobSize = 16;

  /// The track's inset. `redesign.html:426` — `top: 2px, left: 2px`.
  static const double knobInset = 2;

  /// How far the knob travels between off and on.
  ///
  /// `redesign.html:428` writes `left: 20px` for the checked state, and it is not a
  /// free number: `trackSize.width − knobSize − knobInset` is `38 − 16 − 2`. Stated
  /// as a constant so the test can compare the prototype's 20 against the widget's
  /// arithmetic rather than against a restatement of itself — `AGENT_CONTEXT` §6's
  /// "a gate that re-derives the value it is checking agrees with a wrong widget
  /// whenever both are wrong the same way".
  static const double knobTravel = 20;

  /// The knob's transition. `redesign.html:426` — `transition: .25s var(--e-spring)`,
  /// and `--e-spring` is `cubic-bezier(.34, 1.56, .64, 1)` (`redesign.html:18`).
  ///
  /// ## WHY THE WHOLE `AnimatedContainer` GETS THE SPRING AND NOT JUST THE KNOB
  ///
  /// Because the prototype animates two properties on two elements — the track's
  /// colour over a plain `.25s` (`:425`) and the knob's `left` over `.25s` with the
  /// spring (`:426`) — and Flutter has **one** implicit animation here, so it has to
  /// pick one curve. The knob's is the one you can see: the overshoot is ~1.3px of
  /// travel at the end of the slide, which the CSS `left` transition overshoots by
  /// exactly the same mechanism and for exactly the same reason. On the track's
  /// colour the same curve is worth about three points of alpha at the peak, which
  /// is invisible — the same "spend the token on the difference a reader can see"
  /// judgement the `seamGlow` token's own doc records for a 14-vs-12 glow radius.
  ///
  /// ## AND WHY IT IS A `Cubic` AND NOT ONE OF THE TWO NAMED FAMILIES
  ///
  /// [EvaMotion.interactiveCurve] is the prototype's *other* curve
  /// (`cubic-bezier(0.16, 1, 0.3, 1)`, monotone) and
  /// [EvaMotion.achievementCurve] is an achievement-family overshoot, which a
  /// switch is not. The prototype names this third one `--e-spring` and uses it on
  /// two rules, so it is transcribed literally rather than mapped onto the nearest
  /// existing token — the same reason this widget's own numbers live here rather
  /// than in `eva_motion.dart`.
  static const Curve knobCurve = Cubic(0.34, 1.56, 0.64, 1);

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // §14 — the slide is the one animation here, and `redesign.html:425`'s `.25s`
    // is `EvaMotion.screen` exactly: the token already names a 250ms transition, so
    // this is a citation rather than a new duration.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      // §14: a switch, not a button. `toggled` is what makes "on" announceable.
      toggled: value,
      label: value ? labels.on : labels.off,
      excludeSemantics: true,
      // Load-bearing, and easy to lose: `excludeSemantics: true` drops the
      // `InkWell`'s tap action with the label, so without it the switch
      // announces "On, switch" and a TalkBack double-tap does nothing.
      // [SemanticsAction.tap] is `ACTION_CLICK`, and on a switch that is how a
      // reader flips it. A toggle has no disabled state, so this is never null.
      onTap: () => onChanged(!value),
      child: EvaFocusRing(
        // A switch is a stadium, so the ring has to be too — and it is the ring on
        // the **tap target** that a keyboard reader sees, which is the outer box.
        radius: tapTarget.height / 2,
        child: EvaInk(
          onPressed: () => onChanged(!value),
          borderRadius: BorderRadius.circular(tapTarget.height / 2),
          child: SizedBox(
            // The hit area. Unchanged from before the restyle, and asserted as such.
            width: tapTarget.width,
            height: tapTarget.height,
            child: Center(
              child: AnimatedContainer(
                duration: animate ? EvaMotion.screen : Duration.zero,
                curve: knobCurve,
                width: trackSize.width,
                height: trackSize.height,
                padding: const EdgeInsets.symmetric(horizontal: knobInset),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  // `redesign.html:427` — `background: on ? rgba(232,176,75,.3)`,
                  // and `:425` for the off arm's `rgba(255,255,255,.12)`. The on
                  // arm used to be solid `ember`, which is the one thing here the
                  // redesign deliberately softened: the switch now *tints* its
                  // track and puts its emphasis on the knob, which is the element
                  // that moved.
                  color: value
                      ? colors.ember.withValues(alpha: 0.3)
                      : colors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(trackSize.height / 2),
                  // `redesign.html:428` — `box-shadow: 0 0 10px
                  // rgba(232,176,75,.8)` when checked, none when not. Was
                  // `0 0 14px rgba(ember, .45)`: shorter, and nearly twice the
                  // alpha, because at 30% track the glow has to read as the *only*
                  // glow rather than as a halo around an opaque accent.
                  boxShadow: value
                      ? <BoxShadow>[
                          BoxShadow(
                            color: colors.ember.withValues(alpha: 0.8),
                            blurRadius: 10,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    // `EvaToggleKnob.color`, whose doc records the divergence from
                    // `redesign.html:426`'s `--ink-2` and `:428`'s `--gold`.
                    //
                    // The white is the one colour in this design system that is not
                    // a token: the knob is the switch's *handle* rather than a
                    // themed surface, and `surface` would be white in light and
                    // near-black in dark, which would invert the control's only
                    // cue. See the class doc.
                    color: EvaToggleKnob.color,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.ink.withValues(alpha: 0.25),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The switch knob's colour.
///
/// Split out so the one non-token colour in the design system has a name, a
/// reason and one place to change. `EvaColors` publishes no white that means
/// "the handle of a control": `surface` is `#FFFFFF` in light but `#0D1224` in
/// dark, and `ink` is the opposite again. A knob that follows either would stop
/// reading as a handle on one of the two palettes.
///
/// ## THE RECORDED DIVERGENCE, AND HOW TO REVERSE IT
///
/// `redesign.html:426` writes `background: var(--ink-2)` for the off knob and
/// `:428` writes `background: var(--gold)` for the checked one. **This is
/// `#FFFFFF` in both states on both palettes**, and that is a deliberate
/// divergence rather than a transcription that survived: the class doc gives the
/// two reasons (handle legibility, and the 16px knob the redesign shrank it to),
/// and the first reason is the one the prototype's own light palette argues for —
/// `--ink-2` is `#707684` (`redesign.html:56`) on a `rgba(20,22,30,.15)` track.
///
/// **The reversal is one line** at the `color:` in `EvaToggle.build`:
///
/// ```dart
/// color: value ? colors.ember : colors.ink2,
/// ```
///
/// which is what `:428`/`:426` say and what an `ink2`-off/`gold`-on knob would
/// look like. It also empties this class, at which point
/// `no_colour_literals_test.dart`'s exemption for this file — one colour
/// construction, one `EvaToggleKnob` — has to be deleted rather than left
/// behind, because a gate that exempts a file which no longer needs the exemption
/// is a hole with a comment on it.
///
/// Declared here rather than inlined so `no_colour_literals_test.dart` — which
/// confines colour literals to `tokens/` — does not have to grow an exemption for
/// a widget, and so the exemption question stays where it belongs: in the token
/// tables.
///
/// ## AND WHY **THIS FILE** MUST NOT NAME A TOKEN WITH A MEMBER ACCESS
///
/// `no_colour_literals_test.dart`'s second test counts the colour markers in this
/// file's **raw** source — `readAsStringSync`, comments included, no stripping — and
/// requires exactly one. Two of those markers are *dotted member accesses* on the
/// colour types and namespaces, so a doc comment that links a token the way the rest
/// of this repository links them spends the exemption on prose. That is not a nit:
/// this file is the only one where the count is load-bearing, and it is what keeps
/// the knob's single literal from becoming a hole.
///
/// So: name the tokens (`ember`, `ink2`, `seamGlow`) or the table on its own, and
/// keep the member accesses in the code, where the gate reads them line by line
/// with the comments stripped. Four of this restyle's doc edits were undone by this
/// rule.
abstract final class EvaToggleKnob {
  /// `#FFFFFF` — the knob, in both states and both palettes. The class doc records
  /// why, and the reversal, and which two prototype lines it departs from.
  static const Color color = Color(0xFFFFFFFF);
}
