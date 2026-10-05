import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.bottomFade = false,
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
  /// `false` is correct for `/reading` and `/quiz`, whose bodies own their own
  /// scrollables (`ReadingEnScreen.tsx:26` — `overflowY: 'auto'` on the content
  /// div, not the root) so a sticky CTA can overlay it. `true` is correct for
  /// `/login`, `/` and `/settings`, whose root scrolls (`LoginScreen.tsx:11`).
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

  /// Whether to draw the sticky-CTA scrim along the bottom edge.
  ///
  /// `ReadingEnScreen.tsx:80-86` — a `linear-gradient(to bottom, transparent,
  /// canvas 95%)` reaching 40% of its own height, over
  /// `padding: '20px 24px 32px'`. The gradient's own extent is the CTA's height
  /// plus that padding, so it cannot be a constant here; [kNeuralScaffoldFadeHeight]
  /// is the prototype's number at its smallest (`ReadingEnScreen.tsx:26` — the
  /// content's `130px` bottom padding) and the gradient is drawn to the bottom of
  /// the viewport above it.
  final bool bottomFade;

  /// Forces a [NeuralTier] instead of resolving one. `null` resolves from the
  /// viewport and the reader's reduced-motion preference — see [NeuralBackground].
  final NeuralTier? tier;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

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
          builder: (BuildContext context, BoxConstraints constraints) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Behind everything, and full-bleed: the prototype's background
              // container is `position: absolute; inset: 0`
              // (`ds.tsx:162`) and the screens above it rely on that to be
              // immersive. The [SafeArea] is applied to the *content*, not to the
              // stack, so the canvas and the orbs reach under the status bar.
              NeuralBackground(variant: variant, tier: tier),
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
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            // `ReadingEnScreen.tsx:83` —
                            // `linear-gradient(to bottom, transparent,
                            // rgba(#05081A, 0.95) 40%)`.
                            colors.canvas.withValues(alpha: 0),
                            colors.canvas.withValues(alpha: 0.95),
                          ],
                          stops: const <double>[0, 0.40],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
