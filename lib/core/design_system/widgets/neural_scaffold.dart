import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ## THE ENUM MOVED TO `core/domain/entities/curtain_shape.dart`
///
/// It was declared here until Task 5.7, with three members, and it was the
/// design system's own. **The prototype has one attribute with four values**
/// — `el('screen').dataset.shape` (`:1463`) — read by two rules: the shader's
/// `u_shape` and the `.scrim` CSS overrides (`:114`, `:115`). So the three
/// members here were a *subset* of the prototype's, and a second type for the
/// same attribute.
///
/// `UserSettings` now holds the fourth member (`eva.shader.shape`), and
/// `core/domain/` is Flutter-free under Gate 1 — so a `core/domain/` entity
/// could not name a type declared beside a Flutter widget, and the two types'
/// names collided in every file that imported both the barrel and the entity.
///
/// **The ramps stayed here**, because they are this widget's own geometry and
/// moving them would have churned a shipped file for no gain. `shafts` paints
/// the `180deg` ramp, which is the prototype's own behaviour: the CSS has
/// overrides for `bottom` and `sides` only, so a `data-shape="shafts"` element
/// falls through to the base `.scrim` rule (`:112-113`).

/// The `180deg` ramp's four stops — `eva/redesign.html:113` and `:114`.
///
/// `0 / .22 / .46 / 1`. `:113` is
/// `linear-gradient(180deg, transparent 0%, rgba(6,7,12,.30) 22%,
/// rgba(6,7,12,.80) 46%, rgba(6,7,12,.92) 100%)` — four stops and **three
/// different alphas**, and a ramp is only as good as its weakest stop: taking the
/// `.80` alone, or carrying the `.92` to `46%`, gives a gradient that is not the
/// one the prototype draws. That the transcription used to be a *two*-stop
/// `[0, 0.40]` is the subject of [kNeuralCurtain]'s doc.
const List<double> curtainStops = <double>[0, 0.22, 0.46, 1];

/// The `180deg` ramp's four alphas, dark — `:113`.
const List<double> curtainAlphasDark = <double>[0, 0.30, 0.80, 0.92];

/// The `180deg` ramp's four alphas, light — `eva/redesign.html:61`.
const List<double> curtainAlphasLight = <double>[0, 0.35, 0.82, 0.94];

/// The `90deg` ramp's stops — `eva/redesign.html:115`.
///
/// The CSS writes `transparent 20% 80%`, which is one colour pinned at **two**
/// positions. Flutter has no double-position stop, so it is two stops with the
/// same colour between them, and the pair is what makes the middle a flat
/// clearing rather than a slow fade through it.
const List<double> curtainSideStops = <double>[0, 0.2, 0.8, 1];

/// The `90deg` ramp's edge alpha, dark — `:115`'s `rgba(6,7,12,.88)`.
const double curtainSideAlphaDark = 0.88;

/// The `90deg` ramp's edge alpha, light — `eva/redesign.html:63`'s `rgba(245,242,234,.9)`.
const double curtainSideAlphaLight = 0.9;

/// The screen root: canvas, ambient background, safe area, status-bar inversion.
///
/// Six copies collapse to one (`04-widget-inventory.md` §3). Each prototype
/// screen writes the same five-line root by hand:
///
/// ```tsx
/// <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection:
///   'column', minHeight: 844, overflowY: 'auto', position: 'relative' }}>
///   <NeuralBackground variant={N} />
/// ```
///
/// — `LoginScreen.tsx:11`, `HomeScreen.tsx:14`, `SettingsScreen.tsx:35`,
/// `QuizScreen.tsx:41`, `ReadingEnScreen.tsx:9`, `ReadingArScreen.tsx:9`,
/// `ResultScreen.tsx:34`. Nine occurrences of `minHeight: 844` across eight
/// screens, which is prototype defect **#9**.
///
/// ## #9, AND WHERE EACH HALF OF THE FIX LIVES
///
/// - **No `minHeight: 844`.** There is no fixed height here at all. The scaffold
///   is a [Scaffold] plus a [SafeArea] plus a [LayoutBuilder], so it fills
///   whatever the viewport is — 568, 844, 932, a foldable's unfolded height — and
///   [scrollable] decides whether the content moves or the page does.
/// - **`AnnotatedRegion<SystemUiOverlayStyle>`.** The prototype is immersive
///   (`App.tsx:99` renders a rounded phone frame with the screen bleeding to its
///   edges), and `main()` calls
///   `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`. Edge-to-edge
///   without an overlay style means the status bar keeps **light** icons on a
///   light canvas and vanishes on a dark one. So the overlay style is resolved
///   from the ambient brightness here, in the one widget that is guaranteed to be
///   on every screen.
///
/// ## D3 — THE SCRIM'S CITATION MOVED, AND THE ROOT'S EIGHT DID NOT
///
/// This widget is **partially frozen**, and the split is the whole of Task 4.2's
/// rule for it: move the citation for what changed, keep it for what survived.
///
/// - **Kept, all eight:** `LoginScreen.tsx:11`, `HomeScreen.tsx:14`,
///   `SettingsScreen.tsx:35`, `QuizScreen.tsx:41`, `ReadingEnScreen.tsx:9`,
///   `ReadingArScreen.tsx:9`, `ResultScreen.tsx:34` and `App.tsx:99` above. They
///   describe the **root role** — the five-line container every prototype screen
///   writes by hand — and not one word of that container changed. Defect **#9** and
///   the overlay-style half of the fix are exactly where they were.
/// - **Moved:** the scrim. `ReadingEnScreen.tsx:83`'s
///   `linear-gradient(to bottom, transparent, rgba(#05081A, 0.95) 40%)` is
///   replaced by `eva/redesign.html:112-115` (and its light-mode twin at `:61-63`).
///   See [kNeuralCurtain] for the ramp and [curtain] for the shape.
///
/// ### THE PROTOTYPE HAS **TWO** SCRIMS AND THIS WIDGET HAS ONE
///
/// `redesign.html:112`'s `.scrim` is `position:absolute; inset:0; z-index:1` with
/// `data-shape` on the **`.screen`** element: a **full-screen** curtain over
/// everything the route draws, re-declared per screen. The other one is
/// `ReadingEnScreen.tsx:80-86`'s, on the sticky CTA, which is what this widget
/// paints.
///
/// **They are different layers with different extents, and only one of them has a
/// name in this design system.** `CurtainShape` describes the ramp `:112-115`
/// gives the full-screen one; the extent here is still
/// [kNeuralScaffoldFadeHeight], which is the CTA block. Adding the full-bleed
/// curtain would be a second layer, a second parameter, and the question of
/// which screens get it — a screen-level decision for Phase 5, not a paint
/// change. Recorded so the two are never confused into one.
///
/// `kNeuralScaffoldFadeHeight`'s own doc still cites `ReadingEnScreen.tsx:79-86`,
/// and that is correct and unchanged: it is the **extent** the prototype's CTA
/// occupies, which the redesign does not restate anywhere.

/// ## D1 — THERE IS NO ELEVATION TOKEN, AND THE ANSWER IS "STRUCTURALLY 0"
///
/// Phase 1 decision 7 froze every Material elevation at `0` because
/// `03-design-system.md` has no elevation table and the prototype has no z-axis.
/// `eva_elevations.dart` closed with: "`NeuralScaffold` is Phase 2 and has no
/// elevation token of its own; if it needs one it must come from this class or
/// from a spec table that does not exist yet."
///
/// So this file **invents no token**, and — the part worth being precise about —
/// **it could not use one if it wanted to.** `Scaffold` in Flutter 3.47.4 has no
/// `elevation` parameter; `elevation: EvaElevations.none` on a `Scaffold` is a
/// compile error, which is how the claim below was established rather than
/// assumed. A widget that cannot express an elevation cannot accidentally ship
/// one, which is strictly stronger than setting it to `0`.
///
/// The honest account, in descending order of how much it can be trusted:
///
/// 1. **Observable, and asserted by this phase's tests:** the scaffold's
///    `backgroundColor` is `colors.canvas`, and every elevation-bearing
///    `ThemeData` field resolves to `0` in the scaffold's own context — so a
///    `Card`, an `AppBar` or a modal sheet inside a screen built here cannot cast
///    a Material shadow it did not ask for.
/// 2. **Compile-time, and not observable from a test:** that `Scaffold` has no
///    `elevation` parameter. No test asserts this, because the only way to assert
///    it is to write the code and watch it fail to compile. It is stated here
///    with the error name so a reader can reproduce it in one edit.
/// 3. **Explicitly not claimed:** that any particular `0` was written as
///    `EvaElevations.none` rather than as the literal. Both are the same
///    `double`; no test can distinguish them and none pretends to. This is the
///    limitation `eva_elevations.dart` states for its own six tokens.
/// 4. **What actually carries layering:** `line`, the glass triple, and the one
///    ambient shadow — see `eva_elevations.dart`.
///
/// ## D2 — THE LANGUAGE IS NOT A SECOND SOURCE OF TRUTH FOR THE VARIANT
///
/// `NeuralVariant.readingEn` and `NeuralVariant.readingAr` are separate values,
/// not one `reading` plus a direction, because the prototype draws a different
/// orb group per language: English opens blue and has no cyan orb
/// (`ds.tsx:83-86`), Arabic opens violet and pairs it with cyan (`ds.tsx:88-91`).
///
/// The decision this widget makes is: **the language is already in `variant`, and
/// nothing here re-derives it.** The alternative — a `ScriptureLanguage` field,
/// or an [InheritedWidget] to read one from — was rejected for three reasons:
///
/// - **A second source of truth for one fact is the exact hazard Phase 2 already
///   recorded.** `orbGroupFor`'s doc explains why the variant→group mapping is an
///   exhaustive `switch` and not `variant.index`: an off-by-one there hands
///   `/settings` the Profile orbs, and *nothing fails*. Adding `language` beside
///   `variant` creates the same class of bug with the same invisibility.
/// - **Nothing in this phase owns the language.** The app's language is a
///   [UserSettings] value read by Phase 9's cubit. A context read would need an
///   [InheritedWidget] with no producer until Phase 9, and therefore a silent
///   fallback — which is a guess wearing an API.
/// - **The one caller that would want it already switches.** Phase 7's
///   `ReadingPage` renders EN and AR scripture from the same language value, so
///   it has it in hand and passes `NeuralVariant.readingEn` or
///   `NeuralVariant.readingAr` with nothing else to keep in step.
///
/// `neural_scaffold_test.dart` asserts the two reading variants paint different
/// orb groups, so "the language is honoured" is checked rather than asserted in a
/// comment.
class NeuralScaffold extends StatelessWidget {
  /// A screen root for [variant] wrapping [child].
  const NeuralScaffold({
    required this.variant,
    required this.child,
    this.scrollable = false,
    this.padding = const EdgeInsets.symmetric(horizontal: EvaSpacing.lg),
    this.overlay,
    this.bottomFade = false,
    this.curtain = CurtainShape.bottom,
    this.tier,
    super.key,
  });

  /// Which screen's ambient background to paint. **Also** which language the
  /// reading screens are in — see the D2 note above.
  final NeuralVariant variant;

  /// The screen's content.
  final Widget child;

  /// Whether the content scrolls.
  ///
  /// `false` is correct for `/reading`, `/quiz` and the redesigned `/login`,
  /// whose bodies own their own scrollables or centre without one
  /// (`eva/redesign.html:369` — `.login` is `justify-content:center` with no
  /// overflow of its own). `true` is correct for `/` and `/settings`, whose
  /// roots scroll (`HomeScreen.tsx:11`). The redesigned login was the first
  /// screen to move between the two groups, in Phase 5.1.
  final bool scrollable;

  /// Horizontal inset around [child]. Defaults to `EvaSpacing.lg`.
  ///
  /// `16`, not the prototype's `24` (`ReadingEnScreen.tsx:26`) or `20`
  /// (`QuizScreen.tsx:41`): the inventory specifies `EvaSpacing.lg`, and a screen
  /// gutter is the one number in this design system that Phase 1 already fixed
  /// as a token (`EvaSpacing.screenHorizontal == 20`). The default here is the
  /// inventory's, and a screen that wants `20` passes it. **Recorded as a
  /// divergence from the prototype**, because "the gutter" is the kind of number
  /// nobody notices until two screens disagree.
  final EdgeInsets padding;

  /// A viewport-fixed widget above the content and below [bottomFade]'s scrim.
  ///
  /// ## WHY IT IS HERE AND NOT IN THE CALLER'S COLUMN
  ///
  /// Because the content is inside a [SingleChildScrollView] when [scrollable] is set,
  /// so anything a caller places **in** its column scrolls away with the content. A
  /// floating affordance that scrolls off is not a floating affordance — it is the last
  /// thing on the page until you scroll back. `SealFab` is the reason this exists.
  ///
  /// The `Stack` here is already the prototype's `position: absolute; inset: 0`
  /// container (`ds.tsx:162`), so an overlay is the shape the prototype actually had
  /// rather than a second one introduced for Flutter.
  ///
  /// It is placed **after** the content and **before** [bottomFade]'s scrim, so a
  /// scrolling screen's CTA gradient still covers a bottom-right overlay — which is the
  /// honest result, because a scrim that did not cover the overlay would leave a
  /// floating control sitting on top of a fading-out button.
  ///
  /// `null` on every screen that has none, so the five screens without an overlay are
  /// byte-identical in layout.
  final Widget? overlay;

  /// Whether to draw the sticky-CTA scrim along the bottom edge.
  ///
  /// **The extent** is `ReadingEnScreen.tsx:80-86`'s: the gradient is the sticky
  /// CTA's `background`, and the CTA's own `padding: '20px 24px 32px'`, so the
  /// gradient cannot be a constant — [kNeuralScaffoldFadeHeight] is the prototype's
  /// number at its smallest and the gradient is drawn to the bottom of the
  /// viewport above it.
  ///
  /// **The ramp is `eva/redesign.html:112-115`'s, and it used to be the React
  /// app's.** `ReadingEnScreen.tsx:83` is
  /// `linear-gradient(to bottom, transparent, rgba(#05081A, 0.95) 40%)` — two
  /// stops, reaching `.95` at 40% of the scrim's height. `:113` is four stops,
  /// reaching **.92** at 100% of it, with two intermediate rungs at `.30` and
  /// `.80`. See [curtain] and `kNeuralCurtain` for the whole of it.
  final bool bottomFade;

  /// Puts the pointer where the shader expects it.
  ///
  /// `eva/redesign.html:918-919` — the shader's own normalisation, and not
  /// the orb parallax one. See `lumenPointerFor`.
  void _trackPointer(BuildContext context, Size size, Offset local) {
    NeuralMotionScope.of(context).lumenScene.pointer.value = lumenPointerFor(
      size: size,
      local: local,
    );
  }

  /// Puts the pointer back where the shader expects it when there is none.
  void _resetPointer(BuildContext context) {
    NeuralMotionScope.of(context).lumenScene.pointer.value = kLumenNoPointer;
  }

  /// Which way [bottomFade]'s scrim closes — `eva/redesign.html:112-115`.
  ///
  /// **The shape, never the extent.** [kNeuralScaffoldFadeHeight] still decides
  /// how tall the scrim is, for every shape, because this widget paints the
  /// **CTA's** gradient rather than the full-screen curtain `:112` describes.
  /// Adding a full-bleed curtain would be a second layer with its own
  /// [NeuralScaffold] parameter and its own question about which screens get it.
  ///
  /// Defaults to [CurtainShape.bottom] so the one screen that asks for a scrim
  /// today (`/reading`, whose CTA sits at the foot) keeps the shade it has.
  final CurtainShape curtain;

  /// Forces a [NeuralTier] instead of resolving one. `null` resolves from the
  /// viewport and the reader's reduced-motion preference — see [NeuralBackground].
  final NeuralTier? tier;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // Read once, beside [colors], for the scrim's light-mode ramp —
    // `eva/redesign.html:61-63` re-states `.scrim` under
    // `.screen[data-mode=light]`, so a per-brightness ramp is the prototype's own
    // shape and not something this widget invents.
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      // D1 — see the class doc. There is no `elevation:` line here because
      // Flutter 3.47.4's `Scaffold` has no `elevation` parameter at all: writing
      // one is a compile error (`undefined_named_parameter`). A widget that
      // cannot express an elevation cannot accidentally ship one, which is a
      // stronger guarantee than setting it to `0`.
      //
      // `minHeight: 844` is defect #9 and is gone: the Scaffold fills the
      // viewport the framework gives it.
      backgroundColor: colors.canvas,
      // No `appBar`, no `floatingActionButton`, no `drawer`. A `Scaffold` inserts
      // a `DrawerController` and a `FloatingActionButtonTransition` whether or
      // not they are used, and this scaffold's six call sites use none of them.
      // `extendBodyBehindAppBar` is off for the same reason: nothing here has an
      // app bar to be behind.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // `SystemUiOverlayStyle.light` is *light* icons. The prototype's phone
        // frame is dark by default (`App.tsx:91`), and `main.dart` puts the app
        // in `SystemUiMode.edgeToEdge`, so without this the status bar is
        // invisible on the dark canvas and invisible the other way on the light
        // one.
        //
        // `statusBarIconBrightness` is set rather than `statusBarColor`, because
        // an edge-to-edge app must not paint a status-bar background: the canvas
        // is meant to run under it.
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => Listener(
            // ## THE POINTER IS TRACKED **HERE**, AND NOT IN THE BACKGROUND
            //
            // Because the prototype tracks it on `#screen` — the **root**
            // (`eva/redesign.html:916`, `el0('screen').addEventListener('pointermove',…)`)
            // — and a listener in the background layer would only see the
            // moves the content above it does not absorb. The prototype's
            // canvas is behind everything and still follows the pointer
            // across the whole screen; a listener behind the content follows
            // it only over the gaps.
            //
            // `onPointerHover` as well as `onPointerMove`, for the reason
            // `neural_background.dart` records: Flutter routes an un-pressed
            // mouse move to `PointerHoverEvent`, which `onPointerMove` never
            // sees — so a desktop build would have a dead touch glow.
            onPointerHover: (PointerEvent event) => _trackPointer(
              context,
              constraints.biggest,
              event.localPosition,
            ),
            onPointerMove: (PointerEvent event) => _trackPointer(
              context,
              constraints.biggest,
              event.localPosition,
            ),
            // The prototype's `pointerleave` (`eva/redesign.html:921`) puts
            // the pointer back at `(-10, -10)` — ten screen-widths away, so
            // the glow is nowhere near the band. Flutter's route out of a box
            // is `onPointerExit`, which `Listener` does not have; the
            // **touch** case is the one that matters, and a finger lifting is
            // an `onPointerUp`.
            onPointerUp: (PointerEvent event) {
              if (event.kind == PointerDeviceKind.touch) {
                _resetPointer(context);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Behind everything, and full-bleed: the prototype's background
                // container is `position: absolute; inset: 0`
                // (`ds.tsx:162`) and the screens above it rely on that to be
                // immersive. The [SafeArea] is applied to the *content*, not to the
                // stack, so the canvas and the orbs reach under the status bar.
                //
                // `LumenBackground` is the redesign's ambient: the aurora
                // (`eva/redesign.html:46`, `.screen canvas`) when the reader's
                // choices and the tier allow it, and the legacy
                // `NeuralBackground` otherwise. See its doc for the table.
                LumenBackground(variant: variant, tier: tier),
                SafeArea(
                  // Bottom included: the sticky CTA's scrim has to clear the home
                  // indicator, or the button sits under it.
                  child: Padding(
                    padding: padding,
                    child: scrollable
                        ? SingleChildScrollView(
                            // The prototype's `overflowY: 'auto'` is
                            // `ReadingEnScreen.tsx:11`, on the **root** — so a
                            // bouncing scroll is the faithful choice, not the
                            // platform's clamping one.
                            physics: const BouncingScrollPhysics(),
                            child: child,
                          )
                        : child,
                  ),
                ),
                if (overlay case final Widget over)
                  Positioned.fill(child: over),
                if (bottomFade)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    // `LayoutBuilder`'s only job. The scrim is the CTA's height, and
                    // the CTA's height is the content's bottom padding — which is a
                    // function of the viewport, and there is nothing else here that
                    // would read it.
                    height: kNeuralScaffoldFadeHeight(constraints),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // `eva/redesign.html:112-115` — see [kNeuralCurtain], which
                          // is where the ramps live and where the substitution is
                          // named. The three shapes are three different
                          // `background` declarations in the prototype, not one
                          // gradient with three directions.
                          gradient: kNeuralCurtain(curtain, colors, brightness),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The scrim's gradient — `eva/redesign.html:112-115` (dark) and `:61-63` (light).
///
/// ## WHAT `:112-115` REPLACED, AND WHY THE NEW RAMP IS **BETTER**
///
/// `ReadingEnScreen.tsx:83` was `linear-gradient(to bottom, transparent,
/// rgba(#05081A, 0.95) 40%)` — two stops, and the second one is the problem.
///
/// **The old ramp never resolved to anything.** `transparent` at `0` and `canvas`
/// at `.95` at stop `0.40` means the gradient is *still climbing* when it runs out
/// of stops, so the last 60% of the scrim is an unbroken linear ramp from 0 to
/// .95 that reaches `.95` only at the very bottom edge — and CSS/Flutter both hold
/// the final colour across the remainder, so the bottom of the scrim is a flat
/// `.95` plate. `:113` ends at **`.92`**, which is *lighter*, and adds rungs at
/// `.30` and `.80` so the curve is a ramp with a shoulder rather than a ramp that
/// ends in a step. The reader sees less plate and more gradient, and the plate is
/// the part that painted verses over.
///
/// **Measured, because "better" is not a number.** The prototype's own opaque
/// region began `1 - 0.40 = 60%` of the scrim's height above the bottom edge;
/// `:113`'s is `1 - 0.46 = 54%`, and its peak alpha is `.92` rather than `.95`.
/// At 390px wide the scrim is 104px, so the shade now starts its shoulder at
/// 56.2px instead of 62.4px — 6.2px earlier, against a content reserve of 130px.
/// `neural_scaffold_test.dart` asserts the *relationship* (shoulder inside the
/// reserve) rather than either number.
///
/// ## THE COLOUR IS A NAMED SUBSTITUTION, NOT A TRANSCRIPTION
///
/// `:113` shades with `rgba(6,7,12,…)` and `:61` with `rgba(245,242,234,…)`.
///
/// Those are the prototype's **own** floor colours — `#06070C` beside a `#05081A`
/// canvas, `#F5F2EA` beside a `#F0EEFF` one — and neither is a token. They are
/// substituted by [EvaColors.canvas], following `skyStarFill`'s precedent: the
/// ramp's *shape* is the prototype's and the *pigment* is this design system's.
/// A scrim shaded in a colour that is not the surface it covers would be a second
/// canvas, and a screen with two canvases has no canvas.
///
/// The **alphas** are transcribed verbatim in all three tables above, because an
/// alpha is the one part of an `rgba()` that is not a palette decision.
///
/// ## THE THREE RAMPS, AND WHY THE SHAPE IS NOT A DIRECTION
///
/// `eva/redesign.html:112-115` declares `.scrim` **once** and then overrides the
/// whole `background` per `data-shape` on the `.screen` element:
///
/// | line | shape | CSS gradient |
/// | --- | --- | --- |
/// | `:113` | (default — `top` and `shafts`) | `linear-gradient(180deg, transparent 0%, … 22%, … 46%, … 100%)` |
/// | `:114` | `bottom` | `linear-gradient(0deg, transparent 0%, … 22%, … 46%, … 100%)` |
/// | `:115` | `sides` | `linear-gradient(90deg, … .88 0%, transparent 20% 80%, … .88 100%)` |
///
/// So the shape is not a direction on one ramp; it selects **between two
/// different ramps**. `:113`/`:114` are the same four stops running in opposite
/// directions, and `:115` is a different pair of alphas (`.88`, not `.92`) with
/// a flat centre band written as a CSS double-position stop
/// `transparent 20% 80%`.
///
/// **AND `shafts` IS THE DEFAULT, NOT A FOURTH RAMP** — the CSS has overrides
/// for `bottom` and `sides` only, so a `data-shape="shafts"` element falls
/// through to the base rule. That is the prototype's own behaviour and it is
/// why the `shafts` arm below is the `top` arm.
LinearGradient kNeuralCurtain(
  CurtainShape shape,
  EvaColors colors,
  Brightness brightness,
) => switch (shape) {
  // `:113` / `:61` — the `180deg` ramp.
  CurtainShape.top => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: curtainRamp(colors, curtainAlphasFor(brightness)),
    stops: curtainStops,
  ),
  // `:114` / `:62` — the same ramp at `0deg`. The only screen that asks for a
  // scrim today is `/reading`, whose CTA is at the foot of the viewport.
  CurtainShape.bottom => LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: curtainRamp(colors, curtainAlphasFor(brightness)),
    stops: curtainStops,
  ),
  // `:115` / `:63` — the `90deg` ramp. `begin`/`end` are omitted because
  // `LinearGradient`'s own default axis is already `centerLeft → centerRight`,
  // which is what `:115`'s `90deg` means; saying so in a comment is cheaper than
  // saying it in an argument the linter would then call redundant.
  //
  // Its alphas are `[.88, 0, 0, .88]` — the **same** value at both edges and
  // nothing in the middle — which is why it is a second table rather than a
  // shared one with a flag. `:115` writes `transparent 20% 80%`: one colour at
  // two positions, and Flutter has no double-position stop.
  CurtainShape.sides => LinearGradient(
    colors: curtainSideRamp(
      colors,
      brightness == Brightness.dark
          ? curtainSideAlphaDark
          : curtainSideAlphaLight,
    ),
    stops: curtainSideStops,
  ),
  // `:113` again — **THE PROTOTYPE'S OWN FALL-THROUGH, NOT A FOURTH RAMP.** The
  // CSS declares overrides for `data-shape="bottom"` and `data-shape="sides"`
  // only, so a `data-shape="shafts"` screen gets the base `.scrim` rule, which
  // is the `180deg` ramp — the same one `top` gets. Transcribing that as "the
  // shafts fall in the same shade as the top" is the prototype's behaviour, and
  // the fourth shape is a *shader* shape that the scrim has no opinion about.
  CurtainShape.shafts => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: curtainRamp(colors, curtainAlphasFor(brightness)),
    stops: curtainStops,
  ),
};

/// The `90deg` ramp's colours — `.88`, clear, clear, `.88` at [alpha].
///
/// The mirror of [kNeuralCurtain]'s third arm, as a function so the two ends of
/// one declaration sit next to each other.
List<Color> curtainSideRamp(EvaColors colors, double alpha) => <Color>[
  colors.canvas.withValues(alpha: alpha),
  colors.canvas.withValues(alpha: 0),
  colors.canvas.withValues(alpha: 0),
  colors.canvas.withValues(alpha: alpha),
];

/// The `180deg` ramp's alphas for [brightness] — `:113` dark, `:61` light.
List<double> curtainAlphasFor(Brightness brightness) =>
    brightness == Brightness.dark ? curtainAlphasDark : curtainAlphasLight;

/// [alphas] laid onto one colour, in order.
///
/// **One function for the two `180deg` arms**, because `canvas` is the only
/// colour in the scrim and three copies of the same `withValues` ladder is three
/// places for the substitution above to be re-decided in. `sides` is not in here
/// — its alpha table is `[.88, 0, 0, .88]`, which is not a ramp.
List<Color> curtainRamp(EvaColors colors, List<double> alphas) => <Color>[
  for (final double alpha in alphas) colors.canvas.withValues(alpha: alpha),
];

/// How tall the sticky-CTA scrim is for [constraints].
///
/// `ReadingEnScreen.tsx:79-86` sets the sticky CTA's `background` to the gradient,
/// so **the scrim's extent is that CTA** — `20` top padding, the button, the
/// caption's `marginTop: 8`, and `32` bottom padding — which is `20 + 52 + 8 + 10 +
/// 32`, recorded here as `104`. It is **not** the content's `130px` bottom padding
/// from `:26`; that lives on the sibling scroll div and is a *reserve for the
/// reader*, not the height of anything the prototype paints. Summing the two is
/// what made the shade reach opaque over the last line of the passage.
///
/// A constant would be wrong on every other screen, so it scales with the
/// viewport. The prototype's screen is 390 wide and its `ds.tsx` numbers are the
/// only ones that exist, so 390 is the width the transcription is calibrated
/// against and other widths are interpolated from it rather than measured.
///
/// **What must hold at every width**, and is what `neural_scaffold_test.dart` now
/// asserts rather than this function's own arithmetic: because `stops: [0, 0.40]`
/// makes the scrim opaque `60%` of its own height above the bottom edge,
/// `kNeuralScaffoldFadeHeight(w) * 0.60` has to stay **inside** the content's
/// reserve or the last verses are painted over.
double kNeuralScaffoldFadeHeight(BoxConstraints constraints) {
  const double prototypeWidth = 390;
  const double ctaBlock = 104;
  final double scale = constraints.maxWidth > 0
      ? constraints.maxWidth / prototypeWidth
      : 1.0;
  // ## THE CONTENT RESERVE IS **NOT** PART OF THIS SUM, AND ADDING IT WAS A BUG
  //
  // This used to be `(contentReserve * scale) + ctaBlock`, reading its own doc's
  // phrase "the CTA's height plus that padding" as a licence to sum the content's
  // 130px bottom padding into the scrim. Those are two different quantities and
  // the prototype keeps them apart: `ReadingEnScreen.tsx:79-86` puts the gradient
  // in the `background` of the sticky-CTA `<div>` itself, so the gradient's extent
  // is **that div** — `20px` top padding, the button, the caption's `marginTop: 8`,
  // and `32px` bottom padding — and never the content's reserve. The content's
  // `padding: '28px 24px 130px'` lives on the *sibling* scroll div at `:26`.
  //
  // ## WHAT THE OLD SUM ACTUALLY DID TO A READER
  //
  // `stops: [0, 0.40]` means the scrim is **fully opaque 60% of its own height
  // above the bottom edge**, so a taller scrim does not merely fade further up —
  // it reaches opaque *higher*, and it reached opaque higher than the content is
  // reserved. At the prototype's own 390×844 the old answer was 234, so the
  // opaque region began 140px above the bottom while the content stopped at 130:
  // **the last 10px of the passage sat under solid canvas**, and the verse the
  // reader had just reached was the verse that disappeared. At 320 the deficit
  // widens to ~20px, because both terms shrink but the opaque fraction does not.
  //
  // The correct sum is the CTA block alone. At 390 that is 104, opaque from 62px,
  // comfortably inside the 130 the content reserves — which is the relationship
  // the prototype has and this one did not.
  //
  // `neural_scaffold_test.dart` could not catch it: it asserts `wide > narrow` and
  // that the rendered height equals this function's answer. Both hold for the old
  // formula, because a wrong answer asked of itself is always consistent. The gate
  // now pins the *relationship* — opaque start must stay inside the content
  // reserve — rather than this number's provenance.
  return ctaBlock * scale;
}
