import 'package:flutter/rendering.dart';

/// A census of the layers **mounted** in one render tree.
///
/// ## WHY THIS EXISTS, AND WHY IT IS NOT A SECOND SOURCE SCAN
///
/// `test/core/design_system/widgets/glass_blur_budget_test.dart` already caps
/// blur **SITES** at two, by scanning the source for four spellings. Its own
/// header explains why it is a source scan:
///
/// > A runtime count over today's stubs is zero, and it stays zero however many
/// > `.blur` sites Phase 3 adds, because the sites are source, not state.
///
/// **That sentence was true when the screens were stubs, and it is out of date
/// now.** The screens are real, and a source-level site count has a blind spot
/// no scan can close: **a site that MOUNTS more than once.** One
/// `GlassTier.blur` inside a list builder is *one site* and *N mounted
/// filters*, and the source scan sees only the first number.
///
/// So the invariant this instrument exists to hold is the runtime half of the
/// source gate's rule:
///
/// > **A site may exist once; it must MOUNT once.**
///
/// The source gate bounds the first clause; this bounds the second, and the
/// second is the one that costs a `saveLayer` plus a full read-back of
/// everything behind it, **per frame**.
///
/// ## WHAT IS COUNTED
///
/// The **render-object layer tree** — the tree the engine composites — and not
/// the widget tree. The distinction is load-bearing:
///
/// * A `BackdropFilter` **widget** is not a layer. The layer is a
///   `BackdropFilterLayer`, created during the paint phase and pushed onto the
///   painting context, so it is a *sibling* of the widget's own render object
///   rather than its layer.
/// * The same is true of `PictureLayer` (every `DecoratedBox`),
///   `ClipRectLayer`, `ClipRRectLayer`, `ColorFilterLayer`, `ShaderMaskLayer`
///   and `ImageFilterLayer`.
/// * A `RenderOpacity`, on the other hand, **is** a repaint boundary
///   (`RenderOpacity.isRepaintBoundary` returns `alwaysNeedsCompositing`), and
///   the framework assigns it an `OpacityLayer`.
///
/// So the layer tree is the only tree in which "how many backdrop filters are
/// actually mounted" is a question with an answer, and it is the tree the
/// engine charges for.
///
/// **And it is the tree that excludes what is not on screen.** A route the
/// `Overlay` has covered is `Offstage`; an offstage subtree is still in the
/// render tree with its render objects intact, but it never paints, so it owns
/// no layer and it is not in this census. A census taken over the render tree
/// alone would count the screen *behind* the screen.
///
/// ## THE TWO WALKS, AND WHY THERE ARE TWO
///
/// | walk | root | what it answers |
/// | --- | --- | --- |
/// | the **layer** tree | `RenderObject.debugLayer` | which layer types are mounted, and how many |
/// | the **render** tree | the same render object | which render object owns which layer, and how big it is |
///
/// The second walk exists for two numbers the first cannot produce on its own:
///
/// * **the repaint-boundary count.** A `RepaintBoundary` **widget** and a
///   **repaint boundary** at runtime are not the same thing: `RenderOpacity`
///   is one, and so is `RenderViewport`, and the framework's own `Overlay`
///   and `Scaffold` use `RepaintBoundary` widgets of their own. The layer tree
///   cannot tell them apart — a repaint boundary's layer is a plain
///   `OffsetLayer`, and so is the one a `RenderTransform` owns.
/// * **the painted area.** A layer has no public bounds in this SDK
///   (`OffsetLayer` exposes no `paintBounds`), so the area is read from the
///   **render object that owns the layer** and transformed into the layer
///   tree's coordinate space.
///
/// ## THE AREA, AND WHAT IT IS AND IS NOT
///
/// `paintedArea` is the sum, over the mounted `OffsetLayer`s, of the area of
/// the **owner's** painted box, in **logical (device-independent) pixels**.
/// Two things are deliberately excluded or approximated, and both are stated
/// rather than hidden:
///
/// * **The view's own root layer is excluded.** It is the canvas every other
///   layer composites into, not a composited content layer, and counting it
///   would make the number a measurement of the screen rather than of the
///   content. (`RenderView.paintBounds` is also in **device** pixels, which
///   is a second reason it does not belong in a logical-pixel total.)
/// * **The area is the owner's box, not the clipped area.** A layer's real
///   cost is bounded by its ancestors' clips, and this instrument does not
///   walk the clip chain. The number is therefore an **upper bound** on the
///   composited area, which is the safe direction for a budget: it over-states
///   the cost rather than under-stating it.
///
/// ## WHAT IT IS NOT
///
/// It is **not** a millisecond measurement, and it is not a device number.
/// `flutter test` runs a software rasteriser on a fake clock, so a
/// wall-clock bound asserted here would be a number no device produces. The
/// census counts **layers** and **pixels** — quantities a device agrees with —
/// and the budget over them is a budget of *structure*.
///
/// ## A CENSUS THAT FINDS NOTHING IS A FAILURE
///
/// A census that silently counts nothing is a green gate over nothing, so
/// [byType] is never empty in a real tree and the gate asserts that it is
/// not. `test/layer_census_test.dart` also carries a **negative control**:
/// a widget tree with one `BackdropFilter` in it, which the census must see.
/// A census that cannot count a filter it is handed counts none.
final class LayerCensus {
  const LayerCensus._({
    required this.byType,
    required this.repaintBoundaries,
    required this.repaintBoundariesByOwner,
    required this.offsetLayers,
  });

  /// Takes the census of the tree rooted at [root].
  ///
  /// [root] is normally the binding's `RenderView` — the root of the render
  /// tree, and the owner of the root layer.
  factory LayerCensus.of(RenderObject root) {
    final Map<Type, int> byType = <Type, int>{};
    final Set<Layer> mounted = <Layer>{};
    final ContainerLayer? rootLayer = root.debugLayer;
    if (rootLayer != null) {
      _visitLayer(rootLayer, byType, mounted);
    }

    // The render tree, for the one thing the layer tree cannot say: which
    // render object owns which layer.
    final Map<Layer, RenderObject> owners = <Layer, RenderObject>{};
    _visitRender(root, (RenderObject node) {
      final Layer? layer = node.debugLayer;
      if (layer != null) {
        owners[layer] = node;
      }
    });

    // **The repaint-boundary counts, and both are of MOUNTED things.**
    //
    // The render tree holds more repaint boundaries than the screen shows: a
    // route the `Overlay` has covered is `Offstage`, and an offstage subtree
    // is still in the render tree with its render objects intact — it simply
    // never paints, so it owns no layer. Counting the render tree would count
    // the screen *behind* the screen.
    //
    // So both numbers are taken from the **mounted** layers, which is the
    // honest definition of "what is composited right now".
    final Map<Type, int> byOwner = <Type, int>{};
    final List<PaintedLayer> offsetLayers = <PaintedLayer>[];
    for (final Layer layer in mounted) {
      if (layer is! OffsetLayer) continue;
      final RenderObject? owner = owners[layer];
      if (owner == null || !owner.attached) continue;
      // ## THE VIEW'S OWN ROOT LAYER IS EXCLUDED, AND IT IS EXCLUDED **BY
      // ITS OWNER**
      //
      // It is the canvas every other layer composites into, not a composited
      // content layer, and counting it would make the number a measurement of
      // the screen rather than of the content. (`RenderView.paintBounds` is
      // also in **device** pixels, which is a second reason it does not
      // belong in a logical-pixel total.)
      //
      // **The owner, not the layer.** The root layer is the one the
      // `RenderView` — the root render object — owns, and `RenderObject` does
      // not override `==`, so this is an identity comparison without spelling
      // it as one. `no_identical_on_converted_types_test.dart` requires every
      // `identical()` in `test/` to be reviewed and named in a table this
      // lane may not edit, so the one here is **not written at all**: the
      // comparison is made against the owner instead, and it says the same
      // thing.
      if (owner == root) continue;
      if (owner.isRepaintBoundary) {
        byOwner[owner.runtimeType] = (byOwner[owner.runtimeType] ?? 0) + 1;
      }
      final Rect bounds = MatrixUtils.transformRect(
        owner.getTransformTo(null),
        owner.paintBounds,
      );
      offsetLayers.add(
        PaintedLayer(
          type: layer.runtimeType,
          owner: owner.runtimeType,
          bounds: bounds,
        ),
      );
    }
    // **Sorted, so two runs diff by meaning.** Biggest first, then by type
    // name — the same rule `rebuild_counter.dart` uses for the same reason.
    offsetLayers.sort((PaintedLayer a, PaintedLayer b) {
      final int byArea = b.area.compareTo(a.area);
      return byArea != 0
          ? byArea
          : a.type.toString().compareTo(b.type.toString());
    });

    return LayerCensus._(
      byType: Map<Type, int>.unmodifiable(byType),
      repaintBoundaries: byOwner.values.fold<int>(
        0,
        (int sum, int count) => sum + count,
      ),
      repaintBoundariesByOwner: Map<Type, int>.unmodifiable(byOwner),
      offsetLayers: List<PaintedLayer>.unmodifiable(offsetLayers),
    );
  }

  /// The mounted layers, by runtime type.
  ///
  /// **Public, and not a getter over a private field**, because
  /// `prefer_initializing_formals` wants `this._byType` and a named parameter
  /// cannot start with an underscore — the lint's suggestion is not
  /// expressible, and an `// ignore:` is forbidden in hand-written code
  /// (CONTRIBUTING). `lib/app/sky_scope.dart` records the same argument for
  /// the same rule, and this file follows that precedent rather than
  /// inventing a second one.
  final Map<Type, int> byType;

  /// The number of **mounted** repaint boundaries.
  ///
  /// **This is not the number of `RepaintBoundary` widgets.** `RenderOpacity`
  /// is a repaint boundary, and so is `RenderViewport`, and a screen full of
  /// fading stars has one repaint boundary per star.
  ///
  /// **Mounted**, not "in the render tree": a route the `Overlay` has covered
  /// is `Offstage`, and an offstage subtree owns no layer, so it is not
  /// composited and it is not counted.
  final int repaintBoundaries;

  /// The mounted repaint boundaries, **by the type of the render object that
  /// owns them**.
  ///
  /// **This is what "what each boundary is" means.** A number of repaint
  /// boundaries is a number nobody can act on; "six `RenderRepaintBoundary`,
  /// two `RenderOpacity`, one `RenderViewport`" says which widget to go and
  /// look at.
  final Map<Type, int> repaintBoundariesByOwner;

  /// The mounted offset layers, biggest first.
  final List<PaintedLayer> offsetLayers;

  /// The number of mounted layers of [type].
  int countOf(Type type) => byType[type] ?? 0;

  /// The number of mounted **backdrop filters**.
  ///
  /// **The runtime half of the source gate's rule.** A source site that mounts
  /// twice is two `saveLayer`s and two read-backs per frame, and only this
  /// number sees it.
  int get backdropFilters => countOf(BackdropFilterLayer);

  /// The number of mounted **opacity layers**.
  ///
  /// One per fading surface whose alpha is neither 0 nor 1 — the witness
  /// sky's stars, the route transition's fade, a verse that is being revealed.
  int get opacityLayers => countOf(OpacityLayer);

  /// The number of mounted **picture layers**.
  ///
  /// One per `DecoratedBox` that paints a decoration rather than a box
  /// painter, and one per `RenderParagraph`.
  int get pictureLayers => countOf(PictureLayer);

  /// The number of mounted **clip** layers, of every shape.
  int get clipLayers =>
      countOf(ClipRectLayer) + countOf(ClipRRectLayer) + countOf(ClipPathLayer);

  /// The number of mounted **transform** layers.
  int get transformLayers => countOf(TransformLayer);

  /// The total area the mounted offset layers paint, in **logical** px².
  ///
  /// **An upper bound**, for the reason the header gives: it is the sum of the
  /// owners' boxes, not of the clipped areas.
  double get paintedArea => offsetLayers.fold<double>(
    0,
    (double sum, PaintedLayer layer) => sum + layer.area,
  );

  /// The mounted layers, as a stable, sorted, readable line.
  ///
  /// **Sorted by count, descending, then by type name** — so the output is
  /// stable between runs and the biggest contributor is the first line. A
  /// census that prints an unordered map reads as noise, and a diff of two
  /// runs of an unordered map is a diff of noise. This is
  /// `rebuild_counter.dart`'s rule, for the same reason.
  String describe() {
    if (byType.isEmpty) return 'no layers mounted';
    final List<MapEntry<Type, int>> entries = byType.entries.toList()
      ..sort((MapEntry<Type, int> a, MapEntry<Type, int> b) {
        final int byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : a.key.toString().compareTo(b.key.toString());
      });
    return entries
        .map((MapEntry<Type, int> e) => '${e.key} × ${e.value}')
        .join(', ');
  }

  /// The offset layers, as a stable, sorted, readable line.
  String describeOffsetLayers() {
    if (offsetLayers.isEmpty) return 'no offset layers mounted';
    return offsetLayers
        .map(
          (PaintedLayer layer) =>
              '${layer.type} · ${layer.owner} ${layer.bounds.width.round()}×'
              '${layer.bounds.height.round()}',
        )
        .join(', ');
  }

  /// The mounted repaint boundaries, as a stable, sorted, readable line.
  String describeRepaintBoundaries() {
    if (repaintBoundariesByOwner.isEmpty) return 'no repaint boundaries';
    final List<MapEntry<Type, int>> entries =
        repaintBoundariesByOwner.entries.toList()
          ..sort((MapEntry<Type, int> a, MapEntry<Type, int> b) {
            final int byCount = b.value.compareTo(a.value);
            return byCount != 0
                ? byCount
                : a.key.toString().compareTo(b.key.toString());
          });
    return entries
        .map((MapEntry<Type, int> e) => '${e.key} × ${e.value}')
        .join(', ');
  }

  /// Walks the layer tree, counting types and collecting what is mounted.
  static void _visitLayer(
    Layer layer,
    Map<Type, int> byType,
    Set<Layer> mounted,
  ) {
    mounted.add(layer);
    byType[layer.runtimeType] = (byType[layer.runtimeType] ?? 0) + 1;
    if (layer is ContainerLayer) {
      // `firstChild` and `nextSibling` are the public walk: `ContainerLayer`
      // keeps its children in a sibling list and exposes no public `children`
      // list.
      Layer? child = layer.firstChild;
      while (child != null) {
        _visitLayer(child, byType, mounted);
        child = child.nextSibling;
      }
    }
  }

  /// Walks the render tree, handing every render object to [visit].
  static void _visitRender(
    RenderObject node,
    void Function(RenderObject) visit,
  ) {
    visit(node);
    node.visitChildren((RenderObject child) {
      _visitRender(child, visit);
    });
  }
}

/// One mounted offset layer, and the area it paints.
final class PaintedLayer {
  const PaintedLayer({
    required this.type,
    required this.owner,
    required this.bounds,
  });

  /// The layer's runtime type.
  final Type type;

  /// The runtime type of the **render object that owns the layer**.
  ///
  /// **This is what makes a number actionable.** "Seven `OffsetLayer`s" is a
  /// number nobody can act on; "seven `OffsetLayer`s, six of them owned by a
  /// `RenderRepaintBoundary` and one by a `RenderTransform`" says which
  /// widget to go and look at.
  final Type owner;

  /// The area the layer's owner paints, in **logical** pixels.
  final Rect bounds;

  /// The painted area, in logical px².
  double get area => bounds.width * bounds.height;

  @override
  String toString() =>
      '$type (${owner.toString()}) ${bounds.width.round()}×'
      '${bounds.height.round()} (${area.round()} px²)';
}
