# Quality Gates

Test strategy, the performance budget for the animated background, and the accessibility sweep.

**Contains §11 §13 §14** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Build phases](08-build-phases.md)

---

## 11. Test strategy

| Layer | Tool | What it proves |
| --- | --- | --- |
| Domain usecases | plain `test` + hand-written fakes | pure logic, no Flutter |
| Blocs/Cubits | `bloc_test 10.0.0` | every state transition |
| Repositories | `mocktail 1.0.5` | datasource error propagation into `Result.failure` |
| Primitives | `matchesGoldenFile` | dark + light × every state |
| `NeuralBackground` | rebuild-count assertion | **no per-frame `setState`** (fixes #3) |
| Glyph coverage | widget tree walk | no Arabic text bound to a Latin-only family (fixes #2) |
| Filtering | widget test | category filter actually filters (fixes #1) |
| Navigation | router test | guard redirects and resumes |
| Semantics | `matchesSemantics` | every icon button labelled, chips announce selection |

**Font loading in goldens:** `google_fonts` fetches over HTTP at runtime, which makes goldens non-deterministic. Bundle the `.ttf` files as assets and load via `FontLoader` in `flutter_test_config.dart`. Without this, every golden is flaky on a cold cache.

---

## 13. Performance

The prototype's `NeuralBackground` is a 60fps-re-rendering React subtree. Three mitigations, all mandatory.

**1. No `setState` per frame.**

```dart
// Reads the motion bundle from NeuralMotionScope — it is NOT a parameter,
// so no call site ever has to thread a controller through.
class NeuralBackground extends StatelessWidget {
  const NeuralBackground({required this.variant, super.key});
  final NeuralVariant variant;

  @override
  Widget build(BuildContext context) {
    final motion = _NeuralMotionScope.of(context);
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: motion,
        builder: (context, _) => CustomPaint(
          painter: _NeuralPainter(
            variant: variant,
            motion: motion,
            colors: context.colors,
            stickers: context.stickers,
          ),
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}
```

`ListenableBuilder` + `RepaintBoundary` confines the repaint to the background layer; the page above never rebuilds.

**2. Shared controllers, not per-orb.** The prototype declares 3–4 orbs per screen each with independent `floatDur` / `hueDur`. In Flutter, run **3** controllers app-wide (float, hue, aurora) and derive per-orb phase from `i / orbCount`. Eight screens × 4 orbs × 2 animations = 64 animations becomes 3.

The three controllers need a `TickerProviderStateMixin` host. They live in a single `StatefulWidget` mounted above `MaterialApp.router` and are published through an inherited scope — **not** recreated per screen, and **not** looked up from `BuildContext` inside each `NeuralBackground`.

```dart
// lib/core/design_system/effects/neural_motion.dart
class EvaNeuralMotion extends ChangeNotifier {
  EvaNeuralMotion({
    required this.float,   // AnimationController
    required this.hue,     // AnimationController
    required this.aurora,  // AnimationController
  });
  final AnimationController float, hue, aurora;

  /// [count]-th orb's float phase, offset so orbs never pulse in lockstep.
  double floatPhaseFor(int index, int count) => (index / count) % 1.0;
}

class NeuralMotionScope extends StatefulWidget {
  const NeuralMotionScope({required this.child, super.key});
  final Widget child;
  @override
  State<NeuralMotionScope> createState() => _NeuralMotionScopeState();
}

class _NeuralMotionScopeState extends State<NeuralMotionScope>
    with TickerProviderStateMixin {
  late final EvaNeuralMotion _motion = _build();

  EvaNeuralMotion _build() {
    final f = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    final h = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    final a = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);
    return EvaNeuralMotion(float: f, hue: h, aurora: a);
  }

  @override
  void dispose() {
    _motion.float.dispose();
    _motion.hue.dispose();
    _motion.aurora.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _NeuralMotionScope(motion: _motion, child: widget.child);
}

/// Publishes [EvaNeuralMotion] to descendants. Deliberately a plain
/// [InheritedWidget] and not an [InheritedNotifier]: `NeuralBackground`
/// already rebuilds itself through a `ListenableBuilder`, so notifying
/// the whole subtree would defeat the repaint confinement this design
/// exists to get.
class _NeuralMotionScope extends InheritedWidget {
  const _NeuralMotionScope({required this.motion, required super.child});

  final EvaNeuralMotion motion;

  /// [maybeOf] never returns null, so the ! here is a programming-error
  /// assertion rather than a runtime path callers must handle.
  static EvaNeuralMotion of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_NeuralMotionScope>();
    assert(scope != null, 'NeuralMotionScope is missing above this widget');
    return scope!.motion;
  }

  @override
  bool updateShouldNotify(_NeuralMotionScope oldWidget) =>
      !identical(motion, oldWidget.motion);
}
```

`NeuralScaffold` reads the scope rather than taking `tier` or `motion` as parameters — that keeps its interface at 4 fields (`variant`, `child`, `scrollable`, `bottomFade`) and means no caller ever wires a controller.

**3. `hue-rotate` without `ImageFilter`.** `ImageFilter.hueRotation` is not available cross-platform, and a 72px blur per orb is ruinous. Use a colour-matrix `ColorFilter` on the orb's solid fill:

```dart
ColorFilter hueRotateFilter(double turns) {
  final hue = turns * 2 * math.pi;
  final c = math.cos(hue), s = math.sin(hue);
  return ColorFilter.matrix(<double>[
    0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0,
    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
```

The prototype's `blur(72px)` is achieved by a soft radial gradient with a wide transparent stop — visually equivalent, effectively free.

**4. `BackdropFilter` budget.** Each `.blur` surface is a `saveLayer`. Home stacks 6 (hero, 4 cards, top bar). Rules:

- Reading and Quiz screens: `.tint` — the content is dense and the blur is barely perceptible.
- Home: `.blur` on the hero panel only; `.tint` on the 4 passage cards.
- Wrap static groups (stats row, journey list) in `RepaintBoundary`.
- A `NeuralTier` derived from `MediaQuery` size and platform frame budget drops to `low` on low-end devices: no orbs, aurora only, at 30% cost.

**5. Lists.** `GridView.builder` for the passage grid, `ListView.builder` for the journey timeline. Never `Column` + `map` over unbounded data.

---

## 14. Accessibility

The prototype has no semantics at all — every interactive element is a `div onClick` or a bare `<button>` with no label. Mandatory fixes:

| Gap | Fix |
| --- | --- |
| Icon-only buttons (back, close, bookmark, `Aa`) have no accessible name | `IconActionButton.tooltip` feeds both the `Tooltip` and `Semantics(label:)` |
| Category chips are non-focusable `div`s | `Semantics(button: true, selected: isSelected, label: label)` + `InkWell` |
| The Home hero panel is a `div onClick` | `GlassSurface(onTap:)` → `InkWell` inside `Material`; keyboard-activatable |
| The text field has no programmatic label | `EvaTextField` supplies `Semantics(label: label)` to the field |
| No focus indicators | `Focus` + a 2px `ember` ring at 40% alpha on every interactive widget |
| Animations ignore reduced-motion | every animation checks `MediaQuery.disableAnimationsOf(context)`; when disabled, jump straight to the end state |
| Colour-only state (quiz correct/incorrect) | pair the colour with an icon and a semantics label — `correct` announces "Correct", `incorrect` announces "Incorrect answer" |

Target: all 7 pages pass a semantics sweep with no unlabeled interactive node, and text scales to 1.22× without overflow at 320px width.

> **Correction (post-review).** An earlier draft of this plan named a `SemanticsTester` class as the acceptance gate. **No such class exists** in `flutter_test`. The real API is `WidgetTester.ensureSemantics()`, which returns a `SemanticsHandle` (`flutter_test/src/controller.dart:2369`) and must be disposed to avoid leaking across tests. The working pattern per page:
>
> ```dart
> testWidgets('HomePage exposes no unlabeled interactive node',
>     (tester) async {
>   final handle = tester.ensureSemantics();
>   addTearDown(handle.dispose);
>   await tester.pumpWidget(harness);
>   expect(find.bySemanticsLabel('Continue reading'), findsOneWidget);
>   expect(
>     () => unawaited(tester.getSemantics(find.byType(IconActionButton))),
>     returnsNormally,
>   );
> });
> ```
>
> The §11 test table's `matchesSemantics` matcher is correct and unchanged.

---
