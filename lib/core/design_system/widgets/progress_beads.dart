import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// How one bead of a [ProgressBeads] row is drawn.
///
/// `eva/src/components/ds.tsx:355-366` computes three inline conditions per
/// bead and never names the outcome. Naming it is what makes the arithmetic
/// testable — AGENT_CONTEXT §6 asks for exactly this, and the widget is the only
/// caller of [beadStateAt].
enum ProgressBeadState {
  /// Filled `ember` with a glow. `ds.tsx:362,364` — `background: ember`,
  /// `border: 'none'`, `0 0 10px rgba(ember, .65)`.
  done,

  /// Transparent with a 2px `ember` rim and a weaker glow. `ds.tsx:363-364` —
  /// `2px solid ember`, `0 0 7px rgba(ember, .45)`.
  current,

  /// Transparent with a 1.5px `ink`-at-20% rim and no glow. `ds.tsx:363` —
  /// `1.5px solid rgba(ink, 0.2)`.
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
/// The `&& !done` is load-bearing and is the whole reason this is a named
/// function: with `completed: 2, current: 1` the prototype shows bead 1 as
/// **done**, because a finished bead never un-finishes. Written as a widget's
/// `index == current ? current : done` ternary that ordering is a detail nobody
/// would notice was load-bearing, and flipping it shows a reader a progress bar
/// that goes backwards.
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

/// Bead diameter. `ds.tsx:361` — `width: 10, height: 10`.
const double kProgressBeadSize = 10;

/// Bead-to-bead gap. `ds.tsx:355` — `gap: 8`.
const double kProgressBeadGap = 8;

/// The quiz's progress dots.
///
/// One surviving shared call site (`QuizHeader`), and it is the one widget in
/// this tier whose state is **colour-only** in the prototype: `done` is a fill,
/// `upcoming` is an outline, and a reader who cannot distinguish `ember` from
/// transparent sees three identical circles. §14's colour-only rule applies, and
/// it is met twice over — the beads differ in **fill** (solid disc vs ring), not
/// only in hue, and the row carries one [Semantics] node stating the count.
///
/// [semanticLabel] exists because this widget is otherwise a hard-coded English
/// string in a bilingual app. There is no string table yet (`docs/plans/07-file-map.md`
/// defers it), so the default is a placeholder and Phase 9 wires the real one.
class ProgressBeads extends StatelessWidget {
  /// A row of [total] beads, the first [completed] filled, [current] outlined.
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
      label: '$semanticLabel: $completed of $total complete',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ProgressBeadState state in states)
            Padding(
              padding: const EdgeInsets.only(right: kProgressBeadGap),
              child: _Bead(state: state, colors: colors),
            ),
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
    final (Color fill, Border border, List<BoxShadow> glow) = switch (state) {
      ProgressBeadState.done => (
        colors.ember,
        Border.all(color: colors.ember, width: 0),
        <BoxShadow>[
          // `ds.tsx:364` — `0 0 10px rgba(ember, 0.65)`.
          BoxShadow(
            color: colors.ember.withValues(alpha: 0.65),
            blurRadius: 10,
          ),
        ],
      ),
      ProgressBeadState.current => (
        Colors.transparent,
        Border.all(color: colors.ember, width: 2),
        <BoxShadow>[
          // `ds.tsx:364` — `0 0 7px rgba(ember, 0.45)`.
          BoxShadow(color: colors.ember.withValues(alpha: 0.45), blurRadius: 7),
        ],
      ),
      ProgressBeadState.upcoming => (
        Colors.transparent,
        Border.all(color: colors.ink.withValues(alpha: 0.20), width: 1.5),
        const <BoxShadow>[],
      ),
    };

    return Container(
      width: kProgressBeadSize,
      height: kProgressBeadSize,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        // A circle's `Border.all` is drawn on the inside, which is what the
        // prototype's `borderRadius: 50%` + `border` also does.
        border: border,
        boxShadow: glow,
      ),
    );
  }
}
