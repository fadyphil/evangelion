import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// §14's focus ring, as a value.
///
/// `09-quality-gates.md` §14 lists "No focus indicators" as a **mandatory** fix:
/// "`Focus` + a 2px `ember` ring at 40% alpha on every interactive widget". It
/// gives the numbers and no owner. Nine Tier-1 widgets are interactive, and a
/// per-widget convention is nine chances to forget one — which is the same shape
/// of defect as the documented-but-unenforced `BackdropFilter` budget Phase 2 had
/// to grow a gate for. So the numbers live here, once, and
/// `focus_ring_gate_test.dart` fails if any interactive widget omits them.
@immutable
class EvaFocusRingSpec {
  /// A ring of [width] logical px in [color].
  const EvaFocusRingSpec({required this.width, required this.color});

  /// Border width, in logical px. §14 says `2px`.
  final double width;

  /// Border colour. §14 says `ember` at 40% alpha.
  final Color color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaFocusRingSpec && other.width == width && other.color == color;

  @override
  int get hashCode => Object.hash(width, color);

  @override
  String toString() => 'EvaFocusRingSpec(width: $width, color: $color)';
}

/// The §14 focus ring for [colors].
///
/// The only place `2` and `0.40` appear. `theme/eva_theme.dart` publishes the
/// same pair as `ThemeData.focusColor` for stock Material widgets, and
/// `focus_ring_resolver_test.dart` asserts the two agree — two values for one
/// idea is how a theme ends up with a focus colour nothing else uses.
///
/// 40% is the only alpha anywhere in `03-design-system.md` §5, so there is no
/// closer-named token to defer to.
EvaFocusRingSpec evaFocusRingSpec(EvaColors colors) =>
    EvaFocusRingSpec(width: 2, color: colors.ember.withValues(alpha: 0.40));

/// [evaFocusRingSpec] as the [Border] a [DecoratedBox] can paint.
///
/// Exposed so the gate compares the **rendered** border against the spec rather
/// than re-deriving the value it is checking. A gate that re-derives the number
/// under test agrees with a wrong widget whenever both are wrong the same way.
Border evaFocusRingBorder(EvaColors colors) =>
    Border.all(color: evaFocusRingSpec(colors).color, width: 2);

/// Owns the keyboard focus of one interactive Eva surface, and paints §14's ring
/// around it.
///
/// ## WHY THIS WIDGET EXISTS AT ALL
///
/// §14's focus row had no owner. It now has exactly one, and every interactive
/// widget in the design system goes through it rather than through a
/// hand-written `Focus` + border. Two things follow, and both are the point:
///
/// - the ring is **2px `ember` at 40%** by construction, because the numbers
///   come from [evaFocusRingSpec] and a widget cannot spell them differently;
/// - there is exactly **one tab stop** per surface, because the [FocusNode] lives
///   here and [EvaInk] binds its `InkWell` to it. Wrapping an `InkWell` in a
///   second, independent [Focus] would make every control two tab stops, which
///   is worse than no indicator at all.
///
/// ## WHY THERE IS NO `Focus` WIDGET IN HERE
///
/// Because [EvaInk] already puts one on this node. `InkResponse` builds
/// `Focus(focusNode: widget.focusNode, …)` internally
/// (`material/ink_well.dart:1391-1398`), so a second `Focus` on the same node
/// makes the node a child of itself and the framework throws — confirmed, not
/// reasoned about: `_FocusManager._reparent`'s `assert(child != this, 'Tried to
/// make a child into a parent of itself.')` at
/// `widgets/focus_manager.dart:1053`.
///
/// Everything the `Focus` widget would have provided is available on the node
/// itself: [FocusNode.onKeyEvent] is dispatched by the node
/// (`focus_manager.dart:2283-2284`), and [FocusNode.canRequestFocus] is a
/// constructor argument. So this widget owns the node, configures it, listens to
/// it, and publishes it — and inserts nothing.
///
/// The one thing that is genuinely lost is `autofocus`, which only a `Focus`
/// widget can do. Nothing in this design system auto-focuses, so the parameter is
/// **not** offered rather than offered and unimplemented.
///
/// ## THE RING REPLACES THE IDLE BORDER IN THE SAME BAND, BY DESIGN
///
/// A CSS `outline` paints outside the box. Flutter has no outline, and the
/// alternative — a [Padding] that grows by 2px while focused — shifts layout on
/// exactly the interaction that must not move anything under a reader's finger.
/// So the ring occupies the same inset as the border it covers, and [idleBorder]
/// is what the surface shows the rest of the time.
///
/// The consequence worth stating: a focused [EvaButton.secondary] shows the ring
/// *instead of* its 1.5px `ink`-at-20% rim, not both. `EvaTextField` is the one
/// place that keeps both, because its error rim carries information the ring
/// does not (see there).
///
/// ## NO ANIMATION, DELIBERATELY
///
/// A focus indicator is not decorative motion. It fades in over 150ms while a
/// reader tabs through a form, and it fades in *again* for every field. Someone
/// moving through four fields sees four partial rings and no complete one. So
/// this widget has no [AnimatedContainer] and therefore no
/// `MediaQuery.disableAnimationsOf` check — the ring is present on the frame the
/// focus lands and never absent. The widgets that *do* animate (press, toggle,
/// selection, the field's glow) all check that flag; see [EvaButton].
class EvaFocusRing extends StatefulWidget {
  /// Wraps [child] in a keyboard focus scope that paints §14's ring.
  const EvaFocusRing({
    required this.child,
    this.idleBorder,
    this.radius = EvaRadii.button,
    this.enabled = true,
    this.onKeyEvent,
    super.key,
  });

  /// The tappable surface. Should be an [EvaInk], so the ring's focus node and
  /// the ink's are the same node and the control is one tab stop.
  final Widget child;

  /// The border painted while this surface does **not** hold focus.
  ///
  /// `null` — the default — means no border at all, which is what
  /// [EvaButton.primary] wants: it is a filled shape and a rim would only
  /// obscure the fill.
  final Border? idleBorder;

  /// Corner rounding for both [idleBorder] and the ring.
  final double radius;

  /// Whether the surface can take focus at all.
  ///
  /// `false` for a disabled control, so Tab skips it and the ring cannot appear.
  /// A disabled button that still takes focus is a focus trap with a dead end,
  /// which is why this is separate from "is there an `onTap`". It must agree with
  /// what [EvaInk] is told — [EvaInk] asserts it.
  final bool enabled;

  /// Key handling while this surface has focus.
  ///
  /// Used by [SegmentedControl] to turn arrow keys into selection changes. The
  /// handler runs **before** the default [Intent] actions, which is what lets
  /// `HorizontalTraversalIntent` be handled here instead of moving focus out of
  /// a control that is meant to change value rather than leave.
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  State<EvaFocusRing> createState() => _EvaFocusRingState();
}

class _EvaFocusRingState extends State<EvaFocusRing> {
  late final FocusNode _node = FocusNode(
    debugLabel: 'EvaFocusRing',
    canRequestFocus: widget.enabled,
  );

  @override
  void didUpdateWidget(EvaFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _node.canRequestFocus = widget.enabled;
    }
    if (oldWidget.onKeyEvent != widget.onKeyEvent) {
      _node.onKeyEvent = widget.onKeyEvent;
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(widget.radius);
    // Set in `initState` rather than `build` because the node is the one thing
    // here that outlives a rebuild; writing it in `build` would reset the handler
    // on every frame for no reason. `didUpdateWidget` above owns the changes.
    _node.onKeyEvent = widget.onKeyEvent;
    return ListenableBuilder(
      listenable: _node,
      builder: (BuildContext context, Widget? child) => DecoratedBox(
        // `hasFocus` rather than `hasPrimaryFocus`: the node here is a plain
        // focus node, not a scope, so the two agree — and `hasFocus` is the one
        // that also covers the descendant case if a caller nests a scope.
        decoration: BoxDecoration(
          borderRadius: radius,
          border: _node.hasFocus
              ? evaFocusRingBorder(context.colors)
              : widget.idleBorder,
        ),
        child: child,
      ),
      // The scope is inside the `ListenableBuilder` so a consumer that rebuilds on
      // focus is rebuilt from the same node the ring reads.
      child: EvaFocusRingScope(
        node: _node,
        enabled: widget.enabled,
        child: widget.child,
      ),
    );
  }
}

/// Publishes the [FocusNode] an [EvaFocusRing] owns.
///
/// Exists because [EvaInk] has to bind its `InkWell` to the *same* node, and the
/// node is created inside the ring's `State`. A caller must not construct its
/// own and pass it in: two nodes means two tab stops for one control, which is
/// the failure this whole file is arranged to prevent.
class EvaFocusRingScope extends InheritedWidget {
  /// Makes [node] reachable by [EvaInk] below.
  const EvaFocusRingScope({
    required this.node,
    required this.enabled,
    required super.child,
    super.key,
  });

  /// The focus node this surface owns.
  final FocusNode node;

  /// Whether the surface can take focus. Mirrors the ring's `enabled`, so
  /// [EvaInk] can assert the two agree rather than drift.
  final bool enabled;

  /// The nearest enclosing scope.
  ///
  /// Asserts rather than returning null: the only way to reach this is inside an
  /// [EvaFocusRing], and an [EvaInk] without one is a wiring bug with a stack
  /// trace attached — which is a far better failure than a tappable control that
  /// silently has no keyboard focus.
  static EvaFocusRingScope of(BuildContext context) {
    final EvaFocusRingScope? scope = context
        .dependOnInheritedWidgetOfExactType<EvaFocusRingScope>();
    assert(
      scope != null,
      'EvaInk must be a descendant of EvaFocusRing — without it this control has '
      'no focus node, so it is unreachable by keyboard and gets no §14 ring.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(EvaFocusRingScope oldWidget) =>
      node != oldWidget.node || enabled != oldWidget.enabled;
}

/// The one tappable surface in the Eva design system.
///
/// A [Material] + [InkWell], not a [GestureDetector], for the reason
/// `09-quality-gates.md` §14 gives for chips: a `div onClick` has no keyboard
/// path and no ink. This adds the third thing §14 wants — the focus node is the
/// enclosing [EvaFocusRing]'s, so activating the control by keyboard and by tap
/// are the same code path and the same single tab stop.
///
/// ## WHY IT IS A PUBLIC WIDGET AND NOT A PRIVATE HELPER
///
/// Nine primitives plus Phase 2's [GlassSurface] need exactly this, and
/// `GlassSurface` was already reviewed and merged with its own inline
/// `Material` + `InkWell`. Duplicating that block ten times is how the ink
/// response and the focus behaviour drift apart between a button and a chip. One
/// name means a widget cannot pair `InkWell`'s ink with someone else's focus
/// node — which is the one combination that would produce **two** tab stops for
/// one control, the failure this file exists to make impossible.
///
/// WHAT THE GATE DOES *NOT* CHECK, precisely: `focus_ring_gate_test.dart`'s
/// source scan asks whether a file mentions `EvaFocusRing` or
/// `evaFocusRingSpec`, not whether every `InkWell` inside it binds the ring's
/// node. A file could use [EvaFocusRing] for one control and a bare `InkWell`
/// with its own node for another and still pass. The behavioural half of the gate
/// is what closes that: it pumps each widget, tabs to it, and reads the rendered
/// border, so a second focus stop inside a widget would show up as a control the
/// loop cannot tab past. Stated because the first draft of this comment implied
/// the source scan was enough, and it is not.
class EvaInk extends StatelessWidget {
  /// A tappable region bound to the nearest [EvaFocusRing]'s focus node.
  const EvaInk({
    required this.onPressed,
    required this.child,
    this.borderRadius,
    this.onHighlightChanged,
    super.key,
  });

  /// What to run on activation. `null` disables the control: no ink, no focus,
  /// no semantics tap action.
  final VoidCallback? onPressed;

  /// The control's visual body.
  final Widget child;

  /// Rounding for both the [Material] and the [InkWell], so the ink splash is
  /// clipped to the shape the widget drew rather than to a rectangle.
  final BorderRadius? borderRadius;

  /// Reports the ink highlight, i.e. "a pointer is down on this".
  ///
  /// Separate from [onPressed] because the prototype's pressed *fill* and its
  /// pressed *glow* are a second, independent state: `ButtonPrimary` changes
  /// both (`ds.tsx:239,244`) and `InkWell` only ever changes the ink. A widget
  /// that wants a pressed fill listens here rather than inferring one from a
  /// delayed callback.
  final ValueChanged<bool>? onHighlightChanged;

  @override
  Widget build(BuildContext context) {
    final EvaFocusRingScope scope = EvaFocusRingScope.of(context);
    assert(
      onPressed != null || !scope.enabled,
      'EvaInk is disabled (onPressed == null) but its EvaFocusRing is enabled. '
      'Pass enabled: onPressed != null to the ring so a disabled control is '
      'skipped by Tab and never draws a ring.',
    );
    return Material(
      type: MaterialType.transparency,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onPressed,
        onHighlightChanged: onHighlightChanged,
        // The ring's node, not a new one. See [EvaFocusRingScope].
        focusNode: scope.node,
        canRequestFocus: scope.enabled,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}
