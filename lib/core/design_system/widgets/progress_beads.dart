import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// How one dot of a [ProgressBeads] row is drawn.
///
/// `redesign.html:328-332` computes three inline conditions per dot and never
/// names the outcome. Naming it is what makes the arithmetic testable —
/// AGENT_CONTEXT §6 asks for exactly this, and the widget is the only caller of
/// [beadStateAt].
enum ProgressBeadState {
  /// Filled gold at 45%, **no glow and no rim**. `redesign.html:332` —
  /// `.dot.done{background: rgba(232,176,75,.45)}`.
  ///
  /// **No glow**, where `ds.tsx:362,364` drew a filled `ember` with
  /// `0 0 10px rgba(ember,.65)`. This is the clearest PAINT change in the
  /// widget: three lit dots in a row used to be the only thing on the header
  /// emitting light, and now the **current** one is the only thing that does.
  /// That is the point of `:330` — the prototype spends its one glow on the dot
  /// the reader is on.
  done,

  /// A **gold pill** 26 wide, with `0 0 12px` and a 1.6s opacity pulse.
  /// `redesign.html:330` — `.dot.cur{width: 26px; background: var(--gold);
  /// box-shadow: 0 0 12px rgba(232,176,75,.7); animation: dp 1.6s ease-in-out
  /// infinite}`.
  ///
  /// **A different shape, not a bigger dot.** `ds.tsx:363` made the current bead
  /// a 2px ring on the same 10×10 circle as its neighbours, so "which one am I
  /// on" was answered by a rim nobody can see at a glance. `redesign.html:329-330`
  /// answers it with an outline→pill change: every dot is a `border-radius:
  /// 99px` lozenge of the same colour until the current one triples its width.
  /// The row is now wider than it was — see [kProgressBeadWidthAt].
  current,

  /// Filled `ink` at 14%, **no rim**. `redesign.html:329` — `.dot{
  /// background: rgba(255,255,255,.14)}`.
  ///
  /// **No rim**, where `ds.tsx:363` drew a `1.5px solid rgba(ink, 0.2)` outline
  /// and nothing inside it. On a dark page a 10px circle with a 20%-alpha outline
  /// and a transparent middle reads as a *ring*, which is the same signal the
  /// current bead used to carry. Filling it removes the collision: in this
  /// vocabulary a filled lozenge is either "done" or "you are here", and an
  /// outline means nothing.
  upcoming,
}

/// The state of bead [index] in a row of [total].
///
/// The prototype's rule verbatim (`ds.tsx:357-358`):
///
/// ```js
/// const done = i < completed
/// const curr = i === current && !done
/// ```
///
/// ## THE `&& !done` SURVIVES, AND `redesign.html` IS WHY IT IS WORTH SAYING
///
/// `redesign.html:328-332` has only two classes — `.dot.cur` (`:330`) and
/// `.dot.done` (`:332`) — and **no ordering rule at all**. Nothing in the
/// redesign's CSS says that a finished dot stays finished; a literal reading of
/// it is "apply `.done` to anything before the cursor and `.cur` to the cursor",
/// which is the same rule.
///
/// So the clause is kept, and the reason it is now named rather than implied is
/// that the redesign gives it a *second* job. Under the old paint the current
/// bead was an outline and the upcoming ones were outlines too, so mistaking a
/// finished dot for the current one was a low-contrast mistake. Under the new
/// paint the two are a 45%-gold lozenge and a solid gold pill — unmistakably
/// different. The ordering rule is what stops that unmistakable difference from
/// being applied backwards.
///
/// The rule is load-bearing for the same reason it always was: with
/// `completed: 2, current: 1` the prototype shows bead 1 as **done**, because a
/// finished bead never un-finishes. Written as a widget's `index == current ?
/// current : done` ternary that ordering is a detail nobody would notice was
/// load-bearing, and flipping it shows a reader a progress bar that goes
/// backwards.
///
/// An out-of-range [index] resolves to [ProgressBeadState.upcoming] rather than
/// throwing. The widget renders exactly [total] beads and calls this once per
/// index, so the out-of-range case is only reachable from a caller — and a
/// `build` that throws on a corrupt `total` takes the screen down with it.
ProgressBeadState beadStateAt({
  required int index,
  required int total,
  required int completed,
  required int current,
}) {
  if (index < 0 || total <= 0 || index >= total) {
    return ProgressBeadState.upcoming;
  }
  final int done = completed.clamp(0, total);
  if (index < done) return ProgressBeadState.done;
  if (index == current) return ProgressBeadState.current;
  return ProgressBeadState.upcoming;
}

/// Every bead's state, in paint order.
///
/// Clamps [completed] and [current] to `0…total` first, so a `completed` that
/// has run past the end of the row shades the beads that exist rather than
/// producing a row whose states cannot be rendered, and a negative value (a
/// freshly created quiz whose counters are still zero) produces an untouched
/// row rather than an exception.
List<ProgressBeadState> beadStates({
  required int total,
  required int completed,
  required int current,
}) {
  final int count = total.clamp(0, 1 << 20);
  // `completed` is clamped into the row because a value past the end has to
  // shade the beads that exist. `current` is **not** clamped, on purpose: the
  // prototype's `i === current` simply never matches an out-of-range `current`,
  // and clamping would invent a "current" bead that the caller never asked for —
  // a quiz with `current: -1` would show bead 0 as in progress.
  final int done = completed.clamp(0, count);
  return <ProgressBeadState>[
    for (int i = 0; i < count; i++)
      beadStateAt(index: i, total: count, completed: done, current: current),
  ];
}

// ── The dot vocabulary — `redesign.html:328-332` ─────────────────────────────

/// A dot's height, and every dot's width except the current one's.
/// `redesign.html:329` — `.dot{width: 8px; height: 8px; border-radius: 99px}`.
///
/// **8, where `ds.tsx:361` wrote 10.** And it is 8 for the *height* of the
/// current pill too — `.dot.cur` overrides `width` and nothing else, so the
/// current dot is an 8-tall pill and not a larger dot.
///
/// The two are **separate constants** because the redesign uses `border-radius:
/// 99px` at 8×8 and `999px` at 26×8, and both render as a lozenge. A single
/// `Radius.circular(999)` on an 8×8 box is clamped to 4 by the layout engine,
/// which is the same circle — so one constant would work. They are split anyway
/// because `99` and `999` are two numbers the prototype wrote on two lines and
/// the difference between them is a reader's decision, not a rounding artefact.
const double kProgressBeadSize = 8;

/// The current dot's width. `redesign.html:330` — `.dot.cur{width: 26px}`.
///
/// **This is the widget's only state-dependent dimension**, and it is why
/// [kProgressBeadSize] can no longer be described as "the bead diameter": it is
/// the *short* edge, and a `current` row is wider than a row with no current dot
/// by exactly [kProgressBeadCurrentWidth] minus [kProgressBeadSize].
const double kProgressBeadCurrentWidth = 26;

/// Dot-to-dot gap. `redesign.html:328` — `.dots{gap: 6px}`.
///
/// **6, where `ds.tsx:355` wrote 8** — and like the dot size it pairs with, it
/// is narrower, so the row is *denser* as well as smaller. The two moves were
/// made together in the redesign for the same reason: `.dots` is
/// `justify-content: center` inside a quiz header, so the row's whole job is to
/// sit quietly between a title and a counter, and 10px dots at 8px gaps made it
/// the second-loudest thing on the screen.
const double kProgressBeadGap = 6;

/// The dot's own rounding. `redesign.html:329` — `border-radius: 99px`.
///
/// [EvaRadii.chip]'s number, for the same reason it is `EvaButton`'s: the
/// redesign writes `99px` and `999px` interchangeably for "rounder than the long
/// side", and §5.3's table publishes one pill value for the whole design system.
/// One 8-tall lozenge and one 26-tall lozenge, one number.
const double kProgressBeadRadius = EvaRadii.chip;

/// The current dot's glow. `redesign.html:330` — `box-shadow: 0 0 12px
/// rgba(232,176,75,.7)`; the alpha is [kProgressBeadCurrentGlowAlpha].
const double kProgressBeadCurrentGlowBlur = 12;

/// `redesign.html:330`'s `.7`.
const double kProgressBeadCurrentGlowAlpha = 0.7;

/// The current dot's pulse period. `redesign.html:330` — `animation: dp 1.6s
/// ease-in-out infinite`, with `:331` as the whole keyframe.
///
/// ## THE `ease-in-out` IS **NOT** APPLIED, AND THIS IS THE FOURTH SUCH TRADE
///
/// `redesign.html:330` writes `dp 1.6s ease-in-out`. [progressBeadPulseOpacityAt]
/// ramps linearly inside each half. The reason is the one `EvaMotion`'s own doc
/// gives for holding curves beside the widget that quotes the prototype for them:
/// a curve here would be a **fifth** named curve in a design system whose motion
/// table currently publishes four, for a 1.6s loop on an 8px dot whose alpha
/// moves between 1 and 0.55. `EvaMotion.fleckCurve` / `orbFloatCurve` are the
/// candidates and neither is the right shape — `ease-in-out` on a triangle is a
/// *triangle-shaped easing*, which is a different curve from the ones the
/// prototype uses for the prototype's own transitions.
///
/// So the ends are transcribed exactly and the ramp is the plainest thing that
/// connects them. The same decision, and the same reasoning, as `EvaButton`'s
/// `.cta::after` ring.
const Duration kProgressBeadPulsePeriod = Duration(milliseconds: 1600);

/// `@keyframes dp{50%{opacity:.55}}` (`:331`) — the dip the cycle makes.
///
/// A two-stop keyframe with no `0%` and no `100%`: the animation holds `1` at
/// both ends and dips to `.55` at the half. So the ramp is **down then up**, not
/// up then down, and a symmetric "0 → .55 → 1" reading would put the dip at the
/// wrong half of the loop. [progressBeadPulseOpacityAt] is where that is
/// transcribed.
const double kProgressBeadPulseOpacity = 0.55;

/// How wide one bead of [state] is.
///
/// A pure function rather than a field on [ProgressBeadState], because it is the
/// arithmetic the enum used to hide: under `ds.tsx` every bead was
/// [kProgressBeadSize] and the question did not exist. Under `redesign.html` it
/// has two answers, and `progress_beads_test.dart` is what checks the row's
/// width against `size(n−1) + 26` instead of against `10n`.
double progressBeadWidthAt(ProgressBeadState state) => switch (state) {
  ProgressBeadState.current => kProgressBeadCurrentWidth,
  ProgressBeadState.done || ProgressBeadState.upcoming => kProgressBeadSize,
};

/// The width a whole row of [states] renders at.
///
/// Exported because the arithmetic is the thing most likely to rot: a CSS `gap`
/// is the space **between** items and never after the last one, and the first
/// version of this widget padded every bead — see [ProgressBeads]'s own note on
/// the `8px` of dead space that cost.
double progressBeadsWidth(Iterable<ProgressBeadState> states) {
  final int count = states.length;
  if (count == 0) return 0;
  return states.fold<double>(
        0,
        (double sum, ProgressBeadState state) =>
            sum + progressBeadWidthAt(state),
      ) +
      kProgressBeadGap * (count - 1);
}

/// The current dot's opacity [elapsedSeconds] into one [kProgressBeadPulsePeriod].
///
/// Wraps, because `redesign.html:330` says `infinite`. And the shape is the
/// keyframe's, not a triangle's: `dp` declares only a `50%` stop, so the value
/// falls from `1` to [kProgressBeadPulseOpacity] over the first half of the
/// cycle and climbs back over the second.
///
/// The ramp is **linear inside each half**, which is the honest reading of a
/// two-stop `@keyframes` with no easing function on it. `redesign.html:330`
/// writes `ease-in-out`, and that is not applied — see
/// [kProgressBeadPulsePeriod]'s neighbourhood for why a fifth curve is not
/// added for a 1.6s loop; the same trade `EvaButton`'s ring makes.
double progressBeadPulseOpacityAt(double elapsedSeconds) {
  final double phase =
      (elapsedSeconds * 1000 / kProgressBeadPulsePeriod.inMilliseconds) % 1.0;
  // `0 → 1 → 0` across the cycle. Written as its own name because the sign on
  // this line is the whole function: `1 − (1 − .55) × triangle` is the only way
  // to land on `.55` at the apex, and the version with `(kProgressBeadPulseOpacity
  // − 1)` on the *other* side of the minus reads just as naturally and returns
  // **1.45** — which `Opacity` asserts against (`basic.dart:345`) the first time
  // a screen runs with the shared clocks moving. It survived every design-system
  // test because `pumpPrimitive` installs `NeuralMotionScope(animationsEnabled:
  // false)`, so the phase is always 0 there, and the first suite that pumps a
  // real screen is what found it. Recorded because "the tests were green" and
  // "the formula was right" were both false for a while.
  final double triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return 1 - (1 - kProgressBeadPulseOpacity) * triangle;
}

/// The quiz's progress dots.
///
/// One surviving shared call site (`QuizHeader`), and it is the one widget in
/// this tier whose state was **colour-only** in the old prototype: `done` was a
/// fill, `upcoming` was an outline, and a reader who cannot distinguish `ember`
/// from transparent saw five identical circles. §14's colour-only rule applies
/// and it is met differently now — see the enum.
///
/// ## THE ROW IS **WIDER** AT EVERY LENGTH BUT FIVE, AND THE FIVE IS A COINCIDENCE
///
/// The row's arithmetic is now `8·(n − 1) + 26 + 6·(n − 1)` — one current pill,
/// `n − 1` short dots, `n − 1` gaps — where it used to be `10n + 8(n − 1)`. Each
/// dot is 2px smaller and each gap 2px tighter, which pulls in `4n − 4`, and the
/// pill pushes out a flat 18. So:
///
/// | beads | `ds.tsx` | `redesign.html` | delta |
/// | --- | --- | --- | --- |
/// | 1 | 10 | 26 | **+16** |
/// | 2 | 28 | 40 | **+12** |
/// | 3 | 46 | 54 | **+8** |
/// | 5 | 82 | 82 | 0 |
/// | 8 | 138 | 134 | **−4** |
///
/// Five is the crossover, and a reader who compared only the five-bead row would
/// conclude the row did not change width. It did: the dot lost 8px and the pill
/// gave 18 back.
///
/// **That is why `quiz_geometry_test.dart` has to be run, and its assertion is
/// the right shape for it.** It asserts `ProgressBeads.width <
/// QuizHeader.width` — an inequality, not a diameter and not a gap — so a row up
/// to 16px wider is still inside the header, which is 430 at the five-bead case
/// this widget is measured on. `progress_beads_test.dart` is where the exact
/// arithmetic is pinned, against [progressBeadsWidth] rather than against a
/// formula written out a second time in a test.
///
/// [semanticLabel] exists because this widget is otherwise a hard-coded English
/// string in a bilingual app. There is no string table yet (`docs/plans/07-file-map.md`
/// defers it), so the default is a placeholder and Phase 9 wires the real one.
class ProgressBeads extends StatelessWidget {
  /// A row of [total] beads, the first [completed] filled, [current] pill-shaped.
  const ProgressBeads({
    required this.total,
    required this.completed,
    required this.current,
    this.semanticLabel = 'Progress',
    super.key,
  });

  /// How many beads the row has. `0` renders nothing.
  final int total;

  /// How many are done — always a prefix, as in the prototype.
  final int completed;

  /// Which bead is current.
  final int current;

  /// Prefix for the row's single semantics node. The count is appended.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final List<ProgressBeadState> states = beadStates(
      total: total,
      completed: completed,
      current: current,
    );
    if (states.isEmpty) {
      // Nothing to show and nothing to announce. A row of zero beads is what a
      // quiz looks like before its payload arrives; announcing "Progress: 0 of
      // 0" to a screen reader for that is noise.
      return const SizedBox.shrink();
    }

    return Semantics(
      container: true,
      // Clamped, like [beadStates] clamps before it shades. An unclamped label
      // announces the *caller's* number while the beads show the clamped one, so
      // `completed: 99, total: 5` read "Progress: 99 of 5 complete" beside a row
      // of five finished beads — a screen reader contradicting the picture, and
      // on a progress row the one number a reader is most likely to repeat back.
      label: '$semanticLabel: ${completed.clamp(0, total)} of $total complete',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ## THE GAP GOES **BETWEEN** THE BEADS, NOT AFTER EVERY ONE OF THEM
          //
          // `redesign.html:328` is `gap: 6px`, and a CSS `gap` is the space
          // *between* adjacent items — there is no trailing gap after the last
          // child. This is the same argument `ds.tsx:355`'s `gap: 8` got and it
          // has not changed; only the number has. The first version of this
          // widget padded every bead, so a row was `10n + 8n` instead of
          // `10n + 8(n − 1)`: `total: 1` rendered 18 against the prototype's 10,
          // `total: 3` rendered 54 against 46, `total: 5` rendered 90 against 82.
          // Eight pixels of dead space at the end of the row, which is invisible
          // left-aligned and visible the moment the row is centred or sits in a
          // `space-between` `Row` — which is exactly where it is going, in a
          // quiz header between a title and a counter.
          for (int i = 0; i < states.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: kProgressBeadGap),
            _Bead(state: states[i], colors: colors),
          ],
        ],
      ),
    );
  }
}

/// One bead. Private so the only way to draw one is through [ProgressBeads],
/// which means the clamping in [beadStates] cannot be bypassed.
class _Bead extends StatelessWidget {
  const _Bead({required this.state, required this.colors});

  final ProgressBeadState state;
  final EvaColors colors;

  @override
  Widget build(BuildContext context) {
    final (Color fill, List<BoxShadow> glow) = switch (state) {
      // `redesign.html:332` — `background: rgba(232,176,75,.45)`. `ember` and
      // not `emberInk`: this is a **fill**, and Decision 153's rule is that
      // `ember` fills. (In dark the two are the same value anyway.)
      ProgressBeadState.done => (
        colors.ember.withValues(alpha: 0.45),
        // **No glow.** `ds.tsx:364`'s `0 0 10px rgba(ember, 0.65)` is gone; see
        // [ProgressBeadState.done] for why that is the point rather than a loss.
        const <BoxShadow>[],
      ),
      // `redesign.html:330` — `background: var(--gold)`.
      ProgressBeadState.current => (
        colors.ember,
        <BoxShadow>[
          BoxShadow(
            color: colors.ember.withValues(
              alpha: kProgressBeadCurrentGlowAlpha,
            ),
            blurRadius: kProgressBeadCurrentGlowBlur,
          ),
        ],
      ),
      // `redesign.html:329` — `background: rgba(255,255,255,.14)`.
      //
      // `ink` at 14%, and `ink` is the token `font_size_stepper` already chose
      // for the same literal at `redesign.html:429` (`rgba(255,255,255,.14)`),
      // which is the precedent rather than a second reading of the same value.
      // `glassBorder` is **not** it: that token is `rgba(255,255,255,.08)`, which
      // is `--glass-line`, and `.dot` is not `--glass-line`.
      ProgressBeadState.upcoming => (
        colors.ink.withValues(alpha: 0.14),
        const <BoxShadow>[],
      ),
    };

    // The pulse is a second element over a `SizedBox` rather than an `Opacity`
    // around it, for the reason `EvaButton`'s ring is: a `ListenableBuilder` that
    // wrapped the whole bead would rebuild its `BoxDecoration` every frame to
    // change one alpha.
    final Widget face = Container(
      width: progressBeadWidthAt(state),
      height: kProgressBeadSize,
      decoration: BoxDecoration(
        color: fill,
        // `redesign.html:329` — `border-radius: 99px`, and `:330` leaves it
        // alone, so the 26-wide current dot is a pill rather than a circle. That
        // is what makes the shape carry the state: under `ds.tsx` every bead was
        // `borderRadius: 50%` and the current one was distinguished only by a
        // rim.
        borderRadius: const BorderRadius.all(
          Radius.circular(kProgressBeadRadius),
        ),
        // **No `border:` field at all.** Both `redesign.html:329` and `:332`
        // declare none, and `ds.tsx:363`'s `1.5px` rim is gone from all three
        // states — see [ProgressBeadState.upcoming]. A `BoxDecoration.border`
        // left at `null` is also what keeps these beads out of
        // `renderedBorders`, so nothing here can be mistaken for §14's ring.
        boxShadow: glow,
      ),
    );

    if (state != ProgressBeadState.current) return face;

    // `redesign.html:330` — `animation: dp 1.6s ease-in-out infinite`, and
    // `:331` is `50%{opacity:.55}` in full.
    //
    // ## WHY THE CLOCK IS BORROWED AND THE REDUCED-MOTION ANSWER IS "NO DOT"
    //
    // Same trade as `EvaButton`'s `.cta::after`, and the reasons are the same
    // two: §13.2 collapsed sixty-four animations to four shared controllers so
    // that a screen does not create one per element, and an infinitely-repeating
    // `AnimationController` makes `pumpAndSettle` time out. So the pulse reads
    // `NeuralMotionScope`'s monotonic `lumen` clock and divides it by
    // [kProgressBeadPulsePeriod] through [progressBeadPulseOpacityAt].
    //
    // And like the ring, it is **not painted at all** under reduced motion rather
    // than painted frozen. An infinite loop has no end state for §14's "jump
    // straight to the end" to land on, and a 1.6s opacity breathing on the one
    // element a reader is waiting on is the strongest candidate for "no" on the
    // whole screen. `NeuralMotionScope` stops the clock independently, so the
    // two mechanisms agree.
    if (MediaQuery.disableAnimationsOf(context)) return face;
    final Listenable repaint = NeuralMotionScope.of(context).repaint;
    return ListenableBuilder(
      listenable: repaint,
      builder: (BuildContext context, Widget? inner) => Opacity(
        opacity: progressBeadPulseOpacityAt(
          NeuralMotionScope.of(context).lumen.seconds,
        ),
        child: inner!,
      ),
      child: face,
    );
  }
}
